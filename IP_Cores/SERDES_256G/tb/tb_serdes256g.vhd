-------------------------------------------------------------------------------
-- SERDES_256G - self-checking link testbench (GHDL, --std=08)
--
-- TX and RX of one serdes256g_top are connected through a channel model:
--   * every lane is delayed by a different number of BITS (lane skew and an
--     arbitrary 128-bit word alignment at the receiver)
--   * the lanes are permuted (physical RX lane /= TX lane)
--   * every RX lane clock has its own phase
--
-- Phases
--   1  link-up, lane map check, 36 frames (1 .. 1000 bytes, incl. exact
--      multiples of the 128-byte beat), byte-exact scoreboard
--   2  single bit error on one lane while idle: an error counter must move
--      and the link must stay up
--   3  one lane is cut: the link must drop; lane restored: the link must come
--      back and 24 more frames must arrive intact
--
-- Prints SERDES256G_TB_PASS or fails with severity failure.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_serdes256g is
end entity tb_serdes256g;

architecture sim of tb_serdes256g is
  constant L      : positive := 8;
  constant AMP    : positive := 64;      -- short marker period for simulation
  constant TCLK   : time := 4 ns;
  constant PIPEW  : natural := 1152;

  type t_nat is array (0 to L-1) of natural;
  constant SKEW : t_nat := (0, 131, 517, 64, 800, 333, 7, 650);   -- bits
  constant PERM : t_nat := (2, 0, 3, 1, 7, 6, 4, 5);              -- tx lane -> rx lane

  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';

  signal s_tdata  : std_logic_vector(L*128-1 downto 0) := (others => '0');
  signal s_tkeep  : std_logic_vector(L*16-1 downto 0) := (others => '0');
  signal s_tlast  : std_logic := '0';
  signal s_tvalid : std_logic := '0';
  signal s_tready : std_logic;

  signal gt_tx : std_logic_vector(L*128-1 downto 0);
  signal gt_rx : std_logic_vector(L*128-1 downto 0) := (others => '0');
  signal rxclk : std_logic_vector(L-1 downto 0) := (others => '0');

  signal m_tdata  : std_logic_vector(L*128-1 downto 0);
  signal m_tkeep  : std_logic_vector(L*16-1 downto 0);
  signal m_tlast, m_tuser, m_tvalid : std_logic;

  signal blk_lock, am_lock : std_logic_vector(L-1 downto 0);
  signal aligned, rem_al   : std_logic;
  signal lane_map : std_logic_vector(L*4-1 downto 0);
  signal cnt_clr  : std_logic := '0';
  signal bip_cnt  : std_logic_vector(L*16-1 downto 0);
  signal am_err, hdr_err : std_logic_vector(L-1 downto 0);
  signal map_err  : std_logic;

  signal errinj : std_logic := '0';
  signal kill   : std_logic := '0';

  signal rx_frames : natural := 0;
  signal rx_errs   : natural := 0;
  signal err_seen  : std_logic := '0';   -- sticky am_err / hdr_err
  signal err_clr   : std_logic := '0';

  function f_byte (f, i : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned((f*37 + i*11 + (i/251)*5 + 3) mod 256, 8));
  end function;

  function f_len (f : natural) return natural is
  begin
    case f mod 12 is
      when 0  => return 1;
      when 1  => return 7;
      when 2  => return 8;
      when 3  => return 9;
      when 4  => return 127;
      when 5  => return 128;
      when 6  => return 129;
      when 7  => return 256;
      when 8  => return 257;
      when 9  => return 1000;
      when 10 => return 64;
      when others => return 384 + f;
    end case;
  end function;
begin

  clk <= not clk after TCLK/2;

  g_ck : for i in 0 to L-1 generate
    rxclk(i) <= transport clk after (i * 0.4 ns);
  end generate;

  dut : entity work.serdes256g_top
    generic map (G_LANES => L, G_AM_PERIOD => AMP, G_FIFO_AW => 5)
    port map (
      tx_clk => clk, tx_rst => rst,
      s_axis_tx_tdata => s_tdata, s_axis_tx_tkeep => s_tkeep,
      s_axis_tx_tlast => s_tlast, s_axis_tx_tvalid => s_tvalid,
      s_axis_tx_tready => s_tready,
      gt_txdata => gt_tx,
      gt_rxusrclk => rxclk, gt_rxdata => gt_rx,
      rx_clk => clk, rx_rst => rst,
      m_axis_rx_tdata => m_tdata, m_axis_rx_tkeep => m_tkeep,
      m_axis_rx_tlast => m_tlast, m_axis_rx_tuser => m_tuser,
      m_axis_rx_tvalid => m_tvalid,
      rx_block_lock => blk_lock, rx_am_lock => am_lock,
      rx_aligned => aligned, rx_lane_map => lane_map,
      remote_aligned => rem_al, cnt_clr => cnt_clr,
      bip_err_cnt => bip_cnt, am_err => am_err, hdr_err => hdr_err,
      map_err => map_err);

  -----------------------------------------------------------------------------
  -- channel: per-lane bit delay, lane permutation, error injection, lane cut
  -----------------------------------------------------------------------------
  p_chan : process(clk)
    type t_pipe is array (0 to L-1) of std_logic_vector(PIPEW-1 downto 0);
    variable pipe : t_pipe := (others => (others => '0'));
    variable v    : std_logic_vector(127 downto 0);
  begin
    if rising_edge(clk) then
      for i in 0 to L-1 loop
        -- newest bits enter at the top, the oldest leave at bit 0
        pipe(i) := gt_tx(128*i+127 downto 128*i) & pipe(i)(PIPEW-1 downto 128);
        v := pipe(i)(SKEW(i)+127 downto SKEW(i));
        if errinj = '1' and i = 3 then
          v(17) := not v(17);
        end if;
        if kill = '1' and i = 5 then
          v := (others => '0');
        end if;
        gt_rx(128*PERM(i)+127 downto 128*PERM(i)) <= v;
      end loop;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- scoreboard
  -----------------------------------------------------------------------------
  p_chk : process(clk)
    variable f    : natural := 0;
    variable off  : natural := 0;
    variable cnt  : natural;
    variable bad  : natural;
    variable gap  : boolean;
  begin
    if rising_edge(clk) then
      if err_clr = '1' then
        err_seen <= '0';
      elsif am_err /= (am_err'range => '0') or hdr_err /= (hdr_err'range => '0') then
        err_seen <= '1';
      end if;

      if m_tvalid = '1' then
        cnt := 0; bad := 0; gap := false;
        for j in 0 to L*16-1 loop
          if m_tkeep(j) = '1' then
            if gap then
              bad := bad + 1;                      -- keep not contiguous
            end if;
            if m_tdata(8*j+7 downto 8*j) /= f_byte(f, off + j) then
              bad := bad + 1;
            end if;
            cnt := cnt + 1;
          else
            gap := true;
          end if;
        end loop;
        if m_tlast = '1' then
          if off + cnt /= f_len(f) or m_tuser = '1' then
            bad := bad + 1;
            report "frame " & integer'image(f) & ": length " &
                   integer'image(off + cnt) & " expected " &
                   integer'image(f_len(f)) severity error;
          end if;
          f   := f + 1;
          off := 0;
          rx_frames <= f;
        else
          if cnt /= L*16 then
            bad := bad + 1;
          end if;
          off := off + L*16;
        end if;
        if bad /= 0 then
          report "data mismatch near frame " & integer'image(f) severity error;
          rx_errs <= rx_errs + bad;
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- stimulus
  -----------------------------------------------------------------------------
  p_main : process
    variable bipsum : natural;

    procedure clks (n : natural) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure wait_aligned (v : std_logic) is
    begin
      for i in 1 to 400000 loop
        exit when aligned = v;
        wait until rising_edge(clk);
      end loop;
      assert aligned = v
        report "timeout waiting for rx_aligned = " & std_logic'image(v)
        severity failure;
    end procedure;

    procedure wait_frames (n : natural) is
    begin
      for i in 1 to 400000 loop
        exit when rx_frames = n;
        wait until rising_edge(clk);
      end loop;
      assert rx_frames = n
        report "timeout: received " & integer'image(rx_frames) &
               " frames, expected " & integer'image(n)
        severity failure;
    end procedure;

    procedure send (f : natural) is
      variable n   : natural := f_len(f);
      variable off : natural := 0;
      variable d   : std_logic_vector(L*128-1 downto 0);
      variable k   : std_logic_vector(L*16-1 downto 0);
    begin
      while off < n loop
        d := (others => '0');
        k := (others => '0');
        for j in 0 to L*16-1 loop
          if off + j < n then
            d(8*j+7 downto 8*j) := f_byte(f, off + j);
            k(j) := '1';
          end if;
        end loop;
        s_tdata  <= d;
        s_tkeep  <= k;
        if off + L*16 >= n then
          s_tlast <= '1';
        else
          s_tlast <= '0';
        end if;
        s_tvalid <= '1';
        wait until rising_edge(clk) and s_tready = '1';
        s_tvalid <= '0';
        off := off + L*16;
        -- source gaps, also in the middle of a frame
        if (f + off/128) mod 5 = 0 then
          clks(2);
        end if;
      end loop;
    end procedure;
  begin
    clks(20);
    rst <= '0';

    -- phase 1 ----------------------------------------------------------------
    wait_aligned('1');
    clks(50);
    for i in 0 to L-1 loop
      assert to_integer(unsigned(lane_map(4*PERM(i)+3 downto 4*PERM(i)))) = i
        report "lane map wrong on physical lane " & integer'image(PERM(i))
        severity failure;
    end loop;
    for f in 0 to 35 loop
      send(f);
    end loop;
    wait_frames(36);
    clks(4*AMP);
    assert rx_errs = 0 report "phase 1: data errors" severity failure;
    assert unsigned(bip_cnt) = 0 report "phase 1: BIP errors on a clean link"
      severity failure;
    assert err_seen = '0' report "phase 1: marker/header errors on a clean link"
      severity failure;
    assert rem_al = '1' report "phase 1: remote_aligned not set" severity failure;
    report "phase 1 OK: 36 frames";

    -- phase 2 ----------------------------------------------------------------
    errinj <= '1';
    clks(1);
    errinj <= '0';
    clks(6*AMP);
    bipsum := 0;
    for i in 0 to L-1 loop
      bipsum := bipsum + to_integer(unsigned(bip_cnt(16*i+15 downto 16*i)));
    end loop;
    assert bipsum /= 0 or err_seen = '1'
      report "phase 2: injected bit error was not detected" severity failure;
    assert aligned = '1' report "phase 2: link dropped on a single bit error"
      severity failure;
    report "phase 2 OK: bit error detected, BIP count = " & integer'image(bipsum);

    -- phase 3 ----------------------------------------------------------------
    kill <= '1';
    wait_aligned('0');
    clks(500);
    kill <= '0';
    wait_aligned('1');
    clks(50);
    cnt_clr <= '1'; err_clr <= '1';
    clks(1);
    cnt_clr <= '0'; err_clr <= '0';
    for f in 36 to 59 loop
      send(f);
    end loop;
    wait_frames(60);
    clks(4*AMP);
    assert rx_errs = 0 report "phase 3: data errors" severity failure;
    assert unsigned(bip_cnt) = 0 report "phase 3: BIP errors after re-lock"
      severity failure;
    report "phase 3 OK: link recovered, 24 frames";

    report "SERDES256G_TB_PASS";
    finish;
  end process;

end architecture sim;
