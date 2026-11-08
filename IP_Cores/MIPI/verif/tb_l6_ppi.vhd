-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- tb_l6_ppi (AUDIT 2026-11): external D-PHY PPI path, end to end.
--
-- DUT: csi2_selftest with cfg_src_ext='1' (csi2_lane_rx -> mipi_async_fifo ->
--      serializer -> csi2_dual_rx), aclk = 10 ns, PPI byte clock = TBYTE_PS
--      (asynchronous to aclk).
-- Stimulus: an INDEPENDENT behavioural CSI-2 transmitter (this file only, no
--   RTL shared) reading l6_bursts.hex (one packet per HS burst, produced by
--   gen_vectors.py from csi2_oracle.py):
--     * lane distribution: byte n of the burst on lane n mod NLANES (lane 0 =
--       first byte);
--     * HWSYNC=0 (raw deserializer): per lane a serial bitstream LSB first =
--       HS-zero leader (16 + random 0..7 bits => random bit offset of the
--       sync byte relative to the RX byte boundary) + 0xB8 + data + trailer
--       (inverse of the last data bit, >= 16 bits), cut into RX bytes;
--     * HWSYNC=1 (aligned PHY): data bytes only, random RxValidHS gaps common
--       to all lanes (a per-lane independent gap pattern makes the relative
--       skew unbounded; the RTL then reports lane_err, as it must);
--     * random per-lane skew of 0..3 byte periods, random LP gap between bursts.
-- Check: FB0/FB1 committed byte counts and contents byte-exact against
--   l6_fb0.hex / l6_fb1.hex (oracle rx_parse_bursts), and the pkt_err /
--   fb_ovf / frame event counts against l6_expect.txt; no rx_ovf, no lane
--   error. Pass: "L6 PPI PASS". assert severity failure on any mismatch.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_l6_ppi is
  generic (
    SEED   : integer := 4242;
    NLANES : integer := 4;
    HWSYNC : integer := 0;
    TBYTE_PS : integer := 13000;     -- PPI byte clock period (ps)
    GAP    : integer := 160;        -- minimum LP gap (byte clocks)
    -- OVF_TEST=1: run with LP gaps too short for aclk to drain -> the async
    -- FIFO must overflow, report rx_ovf events, and the receiver must recover
    -- (later frames still produce FE events); contents are not compared.
    OVF_TEST : integer := 0
  );
end entity;

architecture sim of tb_l6_ppi is
  constant NL : integer := 4;
  constant FB_AWID : integer := 15;
  function b2sl(c : boolean) return std_logic is
  begin
    if c then return '1'; else return '0'; end if;
  end function;
  constant HWS : std_logic := b2sl(HWSYNC = 1);
  signal clk, bclk : std_logic := '0';
  signal rst : std_logic := '1';
  signal fin, tx_done : boolean := false;

  signal ppi_byte   : std_logic_vector(8*NL-1 downto 0) := (others => '0');
  signal ppi_valid, ppi_active, ppi_sync : std_logic_vector(NL-1 downto 0) := (others => '0');

  signal fb0_re, fb1_re : std_logic := '0';
  signal fb0_raddr, fb1_raddr : std_logic_vector(FB_AWID-1 downto 0) := (others => '0');
  signal fb0_rdata, fb1_rdata : std_logic_vector(7 downto 0);
  signal fb0_count, fb1_count : std_logic_vector(FB_AWID-1 downto 0);
  signal hdr2, ev_frame, ev_rx_ovf, ev_pkt_err, ev_fb_ovf, ev_lane_err, done : std_logic;
  signal n_frame, n_rx_ovf, n_pkt_err, n_fb_ovf, n_lane_err : integer := 0;
begin
  clk  <= '0' when fin else not clk after 5 ns;
  bclk <= '0' when fin else not bclk after (TBYTE_PS * 1 ps) / 2;

  dut : entity work.csi2_selftest
    generic map (W => 128, H => 96, FB_DEPTH => 18432, FB_AWID => FB_AWID, NL => NL)
    port map (clk => clk, rst => rst, start => '0', done => done,
              fb0_re => fb0_re, fb0_raddr => fb0_raddr, fb0_rdata => fb0_rdata, fb0_count => fb0_count,
              fb1_re => fb1_re, fb1_raddr => fb1_raddr, fb1_rdata => fb1_rdata, fb1_count => fb1_count,
              hdr_2bit => hdr2,
              cfg_src_ext => '1',
              cfg_nlanes => std_logic_vector(to_unsigned(NLANES, 3)),
              cfg_hw_sync => HWS,
              cfg_multi_pkt => '0',
              ppi_clk => bclk, ppi_byte => ppi_byte, ppi_valid => ppi_valid,
              ppi_active => ppi_active, ppi_sync => ppi_sync,
              ev_frame => ev_frame, ev_rx_ovf => ev_rx_ovf, ev_pkt_err => ev_pkt_err,
              ev_fb_ovf => ev_fb_ovf, ev_lane_err => ev_lane_err);

  -- event counters (aclk)
  process(clk)
  begin
    if rising_edge(clk) then
      if ev_frame = '1'    then n_frame    <= n_frame + 1; end if;
      if ev_rx_ovf = '1'   then n_rx_ovf   <= n_rx_ovf + 1; end if;
      if ev_pkt_err = '1'  then n_pkt_err  <= n_pkt_err + 1; end if;
      if ev_fb_ovf = '1'   then n_fb_ovf   <= n_fb_ovf + 1; end if;
      if ev_lane_err = '1' then n_lane_err <= n_lane_err + 1; end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- independent CSI-2 D-PHY transmitter model (byte clock domain)
  ---------------------------------------------------------------------------
  tx : process
    file fh : text;
    variable st : file_open_status;
    variable ln : line;
    variable nb, blen : integer;
    variable bv : std_logic_vector(7 downto 0);
    type bytes_t is array (0 to 4095) of std_logic_vector(7 downto 0);
    variable burst : bytes_t;
    type lane_raw_t is array (0 to 1023) of std_logic_vector(7 downto 0);
    type raw_t is array (0 to NL-1) of lane_raw_t;
    variable raw : raw_t;
    type ivec is array (0 to NL-1) of integer;
    variable rlen, ridx, skew : ivec;
    type bits_t is array (0 to 8191) of std_logic;
    variable bits : bits_t;
    variable nbits, nd, off, c : integer;
    variable lastbit : std_logic;
    variable busy, gapc : boolean;
    variable lfsr : unsigned(31 downto 0) := to_unsigned(SEED, 32);
    impure function rnd(m : integer) return integer is
    begin
      for i in 1 to 7 loop
        lfsr := lfsr(30 downto 0) & (lfsr(31) xor lfsr(21) xor lfsr(1) xor lfsr(0));
      end loop;
      return to_integer(lfsr(15 downto 0)) mod m;
    end function;
    procedure put_bits(b : std_logic_vector(7 downto 0)) is
    begin
      for j in 0 to 7 loop                 -- D-PHY: LSB first on the wire
        bits(nbits) := b(j); nbits := nbits + 1;
      end loop;
    end procedure;
  begin
    ppi_active <= (others => '0'); ppi_valid <= (others => '0'); ppi_sync <= (others => '0');
    wait until rst = '0';
    for i in 1 to 50 loop wait until rising_edge(bclk); end loop;
    file_open(st, fh, "l6_bursts.hex", read_mode);
    assert st = open_ok report "no l6_bursts.hex" severity failure;
    readline(fh, ln); read(ln, nb);
    for bi in 0 to nb-1 loop
      readline(fh, ln); read(ln, blen);
      for k in 0 to blen-1 loop hread(ln, bv); burst(k) := bv; end loop;
      -- lane distribution + per-lane line coding
      for i in 0 to NL-1 loop
        rlen(i) := 0; ridx(i) := 0; skew(i) := 0;
        if i < NLANES then
          nd := 0;
          for k in 0 to blen-1 loop
            if k mod NLANES = i then nd := nd + 1; end if;
          end loop;
          skew(i) := rnd(4);
          if HWSYNC = 1 then
            for m in 0 to nd-1 loop raw(i)(m) := burst(i + m*NLANES); end loop;
            rlen(i) := nd;
          else
            nbits := 0;
            off := rnd(8);
            for j in 1 to 16 + off loop bits(nbits) := '0'; nbits := nbits + 1; end loop;
            put_bits(x"B8");
            lastbit := '0';
            for m in 0 to nd-1 loop
              put_bits(burst(i + m*NLANES)); lastbit := burst(i + m*NLANES)(7);
            end loop;
            for j in 1 to 16 + rnd(8) loop bits(nbits) := not lastbit; nbits := nbits + 1; end loop;
            while nbits mod 8 /= 0 loop bits(nbits) := not lastbit; nbits := nbits + 1; end loop;
            rlen(i) := nbits / 8;
            for m in 0 to rlen(i)-1 loop
              for j in 0 to 7 loop raw(i)(m)(j) := bits(8*m + j); end loop;
            end loop;
          end if;
        end if;
      end loop;
      -- drive the PPI, cycle by cycle
      c := 0;
      busy := true;
      while busy loop
        busy := false;
        -- HWSYNC: RxValidHS gaps are common to all lanes (one PHY, one byte
        -- clock / gearbox); the lane-to-lane skew stays the static 0..3.
        gapc := (HWSYNC = 1 and rnd(8) = 0);
        for i in 0 to NL-1 loop
          ppi_valid(i) <= '0'; ppi_sync(i) <= '0';
          if i < NLANES and c >= skew(i) and ridx(i) < rlen(i) then
            busy := true;
            ppi_active(i) <= '1';
            if not gapc then
              ppi_byte(8*i+7 downto 8*i) <= raw(i)(ridx(i));
              ppi_valid(i) <= '1';
              if HWSYNC = 1 and ridx(i) = 0 then ppi_sync(i) <= '1'; end if;
              ridx(i) := ridx(i) + 1;
            end if;
          else
            ppi_active(i) <= '0';
            if i < NLANES and c < skew(i) then busy := true; end if;
          end if;
        end loop;
        wait until rising_edge(bclk);
        c := c + 1;
      end loop;
      ppi_active <= (others => '0'); ppi_valid <= (others => '0');
      for g in 1 to GAP + rnd(32) loop wait until rising_edge(bclk); end loop;
    end loop;
    file_close(fh);
    tx_done <= true;
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- checker (aclk)
  ---------------------------------------------------------------------------
  chk : process
    file fh : text;
    variable st : file_open_status;
    variable ln : line;
    variable n, e_perr, e_fbovf, e_frame, errs : integer := 0;
    variable bv : std_logic_vector(7 downto 0);
    procedure fail(m : string) is
    begin
      errs := errs + 1;
      if errs < 10 or (m(1 to 4) = "lane" or m(1 to 4) = "rx_o") then report "L6 MISMATCH: " & m severity error; end if;
    end procedure;
  begin
    rst <= '1';
    for i in 1 to 20 loop wait until rising_edge(clk); end loop;
    rst <= '0';
    wait until tx_done;
    for i in 1 to 5000 loop wait until rising_edge(clk); end loop;   -- drain
    if OVF_TEST = 1 then
      report "L6 OVF events rx_ovf=" & integer'image(n_rx_ovf) & " frames=" & integer'image(n_frame);
      assert n_rx_ovf > 0 report "L6 OVF FAIL: no rx_ovf reported" severity failure;
      assert n_frame > 0 report "L6 OVF FAIL: receiver did not recover" severity failure;
      report "L6 PPI OVF PASS";
      fin <= true;
      wait;
    end if;
    for vc in 0 to 1 loop
      if vc = 0 then file_open(st, fh, "l6_fb0.hex", read_mode);
      else file_open(st, fh, "l6_fb1.hex", read_mode); end if;
      assert st = open_ok report "no l6_fb*.hex" severity failure;
      readline(fh, ln); read(ln, n);
      if vc = 0 then
        if to_integer(unsigned(fb0_count)) /= n then
          fail("FB0 count " & integer'image(to_integer(unsigned(fb0_count))) & " exp " & integer'image(n));
        end if;
      else
        if to_integer(unsigned(fb1_count)) /= n then
          fail("FB1 count " & integer'image(to_integer(unsigned(fb1_count))) & " exp " & integer'image(n));
        end if;
      end if;
      for a in 0 to n-1 loop
        readline(fh, ln); hread(ln, bv);
        if vc = 0 then
          fb0_raddr <= std_logic_vector(to_unsigned(a, FB_AWID)); fb0_re <= '1';
        else
          fb1_raddr <= std_logic_vector(to_unsigned(a, FB_AWID)); fb1_re <= '1';
        end if;
        wait until rising_edge(clk); wait for 1 ns;
        if vc = 0 and fb0_rdata /= bv then
          fail("FB0[" & integer'image(a) & "]=" & to_hstring(fb0_rdata) & " exp " & to_hstring(bv));
        elsif vc = 1 and fb1_rdata /= bv then
          fail("FB1[" & integer'image(a) & "]=" & to_hstring(fb1_rdata) & " exp " & to_hstring(bv));
        end if;
      end loop;
      fb0_re <= '0'; fb1_re <= '0';
      file_close(fh);
    end loop;
    file_open(st, fh, "l6_expect.txt", read_mode);
    readline(fh, ln); read(ln, e_perr); read(ln, e_fbovf); read(ln, e_frame);
    file_close(fh);
    if n_pkt_err /= e_perr then fail("pkt_err " & integer'image(n_pkt_err) & " exp " & integer'image(e_perr)); end if;
    if n_fb_ovf /= e_fbovf then fail("fb_ovf " & integer'image(n_fb_ovf) & " exp " & integer'image(e_fbovf)); end if;
    if n_frame /= e_frame then fail("frame " & integer'image(n_frame) & " exp " & integer'image(e_frame)); end if;
    if n_rx_ovf /= 0 then fail("rx_ovf " & integer'image(n_rx_ovf)); end if;
    if n_lane_err /= 0 then fail("lane_err " & integer'image(n_lane_err)); end if;
    report "L6 errors=" & integer'image(errs) & " pkt_err=" & integer'image(n_pkt_err) &
           " fb_ovf=" & integer'image(n_fb_ovf) & " frames=" & integer'image(n_frame);
    assert errs = 0 report "L6 PPI FAIL" severity failure;
    report "L6 PPI PASS (NLANES=" & integer'image(NLANES) & " HWSYNC=" & integer'image(HWSYNC) &
           " SEED=" & integer'image(SEED) & ")";
    fin <= true;
    wait;
  end process;
end architecture;
