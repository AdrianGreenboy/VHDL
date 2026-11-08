-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- tb_mac_flow: audit 2026-11 tests of the frame FIFOs and IEEE 802.3x PAUSE.
--
-- TEST = "bubble"  AXIS source with random tvalid bubbles INSIDE frames
--   (AXIS-legal) -> [mac25g_axis_fifo if USE_FIFO] -> mac25g_tx -> PCS66 ->
--   PCS66 RX -> mac25g_rx. Every frame must arrive byte-exact, no underrun.
--   USE_FIFO = false reproduces the pre-audit MAC: it must FAIL (underruns).
--
-- TEST = "pause"   mac25g_datapath in loopback (the MAC hears its own PAUSE
--   frames), continuous 1514-byte traffic, PAUSE honour + auto:
--   A  consumer stalled (rx_tready = 0) for 60k cycles: XOFF is sent and
--      honoured, data frames stop, the RX FIFO never drops a frame
--   B  consumer released: XON, traffic resumes, the checker sees every
--      frame in sequence (no loss, no corruption)
--   C  software PAUSE of 0x40 quanta (auto off): the pause timer runs for
--      0x40 * 8 = 512 slots
--   D  honour off + stalled consumer: PAUSE frames are sent but ignored and
--      the RX FIFO must drop frames (proves that A was flow control)
-- Prints TB_MAC_FLOW_<TEST>_PASS / _FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;

entity tb_mac_flow is
  generic (
    TEST     : string  := "bubble";
    USE_FIFO : boolean := true;
    NFR      : natural := 40
  );
end entity;

architecture sim of tb_mac_flow is
  constant OWN : std_logic_vector(47 downto 0) := x"2032434D4102";
  constant SRC : std_logic_vector(47 downto 0) := x"204E45474E02";
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;

  function flen(i : natural) return natural is
  begin
    return 60 + (i * 97) mod 1455;            -- 60 .. 1514 bytes (no FCS)
  end function;
  function fbyte(i, b : natural) return std_logic_vector is
  begin
    if b < 6 then return OWN(8*b+7 downto 8*b); end if;      -- DA = own MAC
    return std_logic_vector(to_unsigned((i * 7 + b * 13 + b / 256) mod 256, 8));
  end function;

  -- bubble test
  signal s_d  : std_logic_vector(63 downto 0) := (others => '0');
  signal s_k  : std_logic_vector(7 downto 0) := (others => '0');
  signal s_l, s_v, s_r : std_logic := '0';
  signal m_d  : std_logic_vector(63 downto 0);
  signal m_k  : std_logic_vector(7 downto 0);
  signal m_l, m_v, m_r : std_logic;
  signal b_v, b_isd, ev_f, ev_u, ev_k : std_logic;
  signal b_pl : std_logic_vector(63 downto 0);
  signal ev_b : unsigned(15 downto 0);
  signal c_v, c_isd : std_logic;
  signal c_blk : std_logic_vector(65 downto 0);
  signal p_v, p_isd : std_logic;
  signal p_pl : std_logic_vector(63 downto 0);
  signal r_d : std_logic_vector(63 downto 0);
  signal r_k : std_logic_vector(7 downto 0);
  signal r_l, r_u, r_v : std_logic;
  signal n_und : natural := 0;

  -- pause test
  signal gstart, gstop, rxr, honor, auto, swreq : std_logic := '0';
  signal swq : std_logic_vector(15 downto 0) := x"0040";
  signal cnt  : std_logic_vector(16*32-1 downto 0);
  signal cnt2 : std_logic_vector(8*32-1 downto 0);
  signal paused, xoff, lnk : std_logic;
begin
  clk <= not clk after 1280 ps when not done;

  ---------------------------------------------------------------------------
  g_bub: if TEST = "bubble" generate
    g_f: if USE_FIFO generate
      u_q: entity work.mac25g_axis_fifo
        generic map (AW => 9, STORE_FW => true, NO_BP => false)
        port map (clk=>clk, rst=>rst, s_tdata=>s_d, s_tkeep=>s_k, s_tlast=>s_l,
                  s_tuser=>'0', s_tdrop=>'0', s_tvalid=>s_v, s_tready=>s_r,
                  m_tdata=>m_d, m_tkeep=>m_k, m_tlast=>m_l, m_tuser=>open,
                  m_tvalid=>m_v, m_tready=>m_r, level=>open, ev_ovf=>open, ev_drop=>open);
    end generate;
    g_nf: if not USE_FIFO generate
      m_d <= s_d; m_k <= s_k; m_l <= s_l; m_v <= s_v; s_r <= m_r;
    end generate;

    u_tx: entity work.mac25g_tx
      port map (clk=>clk, rst=>rst, ce=>'1', s_tdata=>m_d, s_tkeep=>m_k, s_tlast=>m_l,
                s_tvalid=>m_v, s_tready=>m_r, inj=>'0',
                blk_valid=>b_v, blk_payload=>b_pl, blk_is_data=>b_isd,
                ev_frame=>ev_f, ev_bytes=>ev_b, ev_underrun=>ev_u, ev_keep_err=>ev_k);
    u_ptx: entity work.mac25g_pcs66_tx
      port map (clk=>clk, rst=>rst, in_valid=>b_v, in_payload=>b_pl, in_is_data=>b_isd,
                out_valid=>c_v, out_block=>c_blk);
    u_prx: entity work.mac25g_pcs66_rx
      port map (clk=>clk, rst=>rst, in_valid=>c_v, in_block=>c_blk,
                out_valid=>p_v, out_payload=>p_pl, out_is_data=>p_isd, out_hdr_ok=>open);
    u_rx: entity work.mac25g_rx
      port map (clk=>clk, rst=>rst, in_valid=>p_v, in_payload=>p_pl, in_is_data=>p_isd,
                own_mac=>OWN, promisc=>'0',
                m_tdata=>r_d, m_tkeep=>r_k, m_tlast=>r_l, m_tuser=>r_u, m_tvalid=>r_v,
                ev_ok=>open, ev_bytes=>open, ev_crc=>open, ev_runt=>open, ev_runt0=>open,
                ev_over=>open, ev_abort=>open, ev_abort0=>open, ev_filt=>open,
                ev_proto=>open, link_up=>open);

    process(clk)
    begin
      if rising_edge(clk) then
        if ev_u = '1' then n_und <= n_und + 1; end if;
      end if;
    end process;

    -- source: AXIS-legal, data stable while tvalid = 1 and tready = 0
    p_src: process
      variable seed : unsigned(31 downto 0) := x"1234ABCD";
      variable w : std_logic_vector(63 downto 0);
      variable L, nw : natural;
      procedure rnd is
      begin
        seed := seed(30 downto 0) & (seed(31) xor seed(21) xor seed(1) xor seed(0));
      end procedure;
    begin
      rst <= '1';
      for i in 1 to 8 loop wait until rising_edge(clk); end loop;
      rst <= '0';
      for i in 1 to 100 loop wait until rising_edge(clk); end loop;   -- link up
      for f in 0 to NFR - 1 loop
        L := flen(f); nw := (L + 7) / 8;
        for k in 0 to nw - 1 loop
          -- random bubble before the beat (about 1 in 3 beats)
          rnd;
          while seed(1 downto 0) = "00" loop
            s_v <= '0'; wait until rising_edge(clk); rnd;
          end loop;
          for b in 0 to 7 loop
            if 8*k + b < L then w(8*b+7 downto 8*b) := fbyte(f, 8*k + b);
            else w(8*b+7 downto 8*b) := x"00"; end if;
          end loop;
          s_d <= w; s_v <= '1';
          if k = nw - 1 then
            s_l <= '1'; s_k <= n_to_keep(to_unsigned(L - 8*k, 4));
          else
            s_l <= '0'; s_k <= x"FF";
          end if;
          loop
            wait until rising_edge(clk);
            exit when s_r = '1';
          end loop;
        end loop;
        s_v <= '0'; s_l <= '0';
      end loop;
      wait;
    end process;

    sink: process
      variable f, b, errs : natural := 0;
      variable t : natural := 0;
    begin
      loop
        wait until rising_edge(clk);
        t := t + 1;
        if r_v = '1' then
          for i in 0 to 7 loop
            if r_k(i) = '1' then
              if b >= flen(f) or r_d(8*i+7 downto 8*i) /= fbyte(f, b) then
                if errs < 5 then
                  report "frame " & integer'image(f) & " byte " & integer'image(b) &
                         " mismatch" severity error;
                end if;
                errs := errs + 1;
              end if;
              b := b + 1;
            end if;
          end loop;
          if r_l = '1' then
            if r_u = '1' or b /= flen(f) then
              if errs < 5 then
                report "frame " & integer'image(f) & " len " & integer'image(b) & " exp " &
                       integer'image(flen(f)) & " tuser=" & std_logic'image(r_u) severity error;
              end if;
              errs := errs + 1;
            end if;
            f := f + 1; b := 0;
          end if;
        end if;
        exit when f = NFR or t > 400000;
      end loop;
      if errs = 0 and f = NFR and n_und = 0 then
        report "TB_MAC_FLOW_BUBBLE_PASS frames=" & integer'image(f) & " underruns=0" severity note;
      else
        report "TB_MAC_FLOW_BUBBLE_FAIL frames=" & integer'image(f) & " errors=" &
               integer'image(errs) & " underruns=" & integer'image(n_und) severity note;
      end if;
      done <= true;
      wait;
    end process;
  end generate;

  ---------------------------------------------------------------------------
  g_pause: if TEST = "pause" generate
    dut: entity work.mac25g_datapath
      generic map (GEARBOX => false)
      port map (clk_dp=>clk, rst_dp=>rst, mac_en=>'1', loopback=>'1', promisc=>'0',
                gen_cont=>'1', own_mac=>OWN, src_mac=>SRC,
                len_min=>to_unsigned(1514, 11), len_max=>to_unsigned(1514, 11),
                len_step=>to_unsigned(0, 11), gen_count=>to_unsigned(0, 32),
                gen_start=>gstart, gen_stop=>gstop, cnt_clear=>'0', inj=>'0',
                st_link=>lnk, st_busy=>open, st_done=>open, st_rx_act=>open, st_tx_act=>open,
                ev_done=>open, ev_crc=>open, ev_chkerr=>open, ev_lnk_lo=>open,
                cnt_flat=>cnt,
                pause_honor=>honor, pause_auto=>auto, pause_quanta=>x"0100",
                rx_hi_wm=>to_unsigned(200, 16), rx_lo_wm=>to_unsigned(64, 16),
                pause_sw_req=>swreq, pause_sw_quanta=>swq, rx_tready=>rxr,
                st_paused=>paused, st_xoff=>xoff, cnt2_flat=>cnt2);

    stim: process
      variable ok : boolean := true;
      variable txd0, txd1, cok0, cok1, t0, n : natural;
      function c(v : std_logic_vector; i : natural) return natural is
      begin
        return to_integer(unsigned(v(32*i+31 downto 32*i)));
      end function;
      procedure fail(m : string) is
      begin
        report "TB_MAC_FLOW_PAUSE_FAIL " & m severity error; ok := false;
      end procedure;
      procedure cycles(k : natural) is
      begin
        for i in 1 to k loop wait until rising_edge(clk); end loop;
      end procedure;
    begin
      rst <= '1'; cycles(8); rst <= '0';
      honor <= '1'; auto <= '1'; rxr <= '1';
      cycles(200);
      gstart <= '1'; cycles(1); gstart <= '0';
      cycles(20000);                                -- free running traffic
      if c(cnt, 10) < 10 then fail("no traffic before the test"); end if;

      -- A: consumer stalled
      rxr <= '0';
      cycles(20000);                                -- XOFF reaches the TX
      txd0 := c(cnt, 0) - c(cnt2, 1);               -- data frames sent so far
      cycles(60000);
      txd1 := c(cnt, 0) - c(cnt2, 1);
      if c(cnt2, 1) = 0 then fail("A: no PAUSE frame sent"); end if;
      if c(cnt2, 0) = 0 then fail("A: no PAUSE frame honoured"); end if;
      if txd1 /= txd0 then fail("A: data frames sent while paused: " & integer'image(txd1 - txd0)); end if;
      if c(cnt2, 3) /= 0 then fail("A: RX FIFO dropped frames with flow control"); end if;
      if paused /= '1' then fail("A: not paused"); end if;
      report "A: TX_PAUSE=" & integer'image(c(cnt2, 1)) & " RX_PAUSE=" &
             integer'image(c(cnt2, 0)) & " RX_FIFO_MAX=" & integer'image(c(cnt2, 7)) &
             " words" severity note;

      -- B: consumer released
      cok0 := c(cnt, 10);
      rxr <= '1';
      cycles(40000);
      cok1 := c(cnt, 10);
      if paused /= '0' then fail("B: still paused after XON"); end if;
      if cok1 - cok0 < 30 then fail("B: traffic did not resume (" & integer'image(cok1 - cok0) & ")"); end if;
      if c(cnt, 11) /= 0 or c(cnt, 12) /= 0 or c(cnt, 13) /= 0 then
        fail("B: checker bad=" & integer'image(c(cnt, 11)) & " seq=" &
             integer'image(c(cnt, 12)) & " rxerr=" & integer'image(c(cnt, 13)));
      end if;
      if c(cnt2, 3) /= 0 then fail("B: RX FIFO drops"); end if;
      if c(cnt, 15) /= 0 then fail("B: TX underrun"); end if;

      -- C: software PAUSE, 0x40 quanta -> 512 slots
      auto <= '0'; cycles(10);
      swreq <= '1'; cycles(1); swreq <= '0';
      n := 0;
      for i in 1 to 6000 loop
        wait until rising_edge(clk);
        if paused = '1' then n := n + 1; end if;
      end loop;
      if n < 500 or n > 520 then fail("C: paused for " & integer'image(n) & " slots, expected 512"); end if;

      -- D: honour off, consumer stalled -> PAUSE ignored, drops expected
      honor <= '0'; auto <= '1'; cycles(10);
      rxr <= '0';
      cycles(40000);
      if c(cnt2, 3) = 0 then fail("D: no RX FIFO drop without flow control"); end if;
      rxr <= '1';

      if ok then report "TB_MAC_FLOW_PAUSE_PASS" severity note;
      else report "TB_MAC_FLOW_PAUSE_FAIL" severity note; end if;
      done <= true;
      wait;
    end process;
  end generate;
end architecture sim;
