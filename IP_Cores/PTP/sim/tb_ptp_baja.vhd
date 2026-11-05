-- tb_ptp_baja.vhd - audit 2026-11 low-severity fixes of the PTP core
-- ---------------------------------------------------------------------------
-- Self-checking.
--   L1 ptp_tstamp: latency correction at sec = 0 with ns < lat clamps to 0.0
--      (v1 borrowed: sec wrapped to 2^48-1, ns = 1e9 - (lat - ns)).
--   L2 ptp_clock: clr_servo in the same cycle as a PI update wins: rate_adj
--      and the integrator are cleared, offset_applied re-armed (v1: the PI
--      branch overwrote the clear).
--   L3 ptp_regs: NOW_SECHI (0x5C) returns sec[47:32], frozen by the NOW_SEC
--      read (v1: no access to the upper 16 bits of the 48-bit seconds).
--   L4 ptp_regs: STATUS bits 4..10 are W1C per bit, IRQEN masks them.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.ptp_pkg.all;

entity tb_ptp_baja is
end entity;

architecture sim of tb_ptp_baja is
  constant TCK : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  -- L1
  signal t_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal t_ns  : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal t_sfd : std_logic := '0';
  signal ts_sec : std_logic_vector(SEC_W-1 downto 0);
  signal ts_ns  : std_logic_vector(NS_W-1 downto 0);
  signal ts_v   : std_logic;
  -- L2
  signal clr, ov : std_logic := '0';
  signal err : std_logic_vector(ERR_W-1 downto 0) := (others => '0');
  signal rate : std_logic_vector(RATE_W-1 downto 0);
  signal applied : std_logic;
  -- L3/L4
  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(5 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal irq : std_logic;
  signal r_sec : std_logic_vector(SEC_W-1 downto 0) := x"123456789ABC";
  signal ev_tmo : std_logic := '0';
begin
  clk <= not clk after TCK / 2;

  u_ts : entity work.ptp_tstamp
    port map (clk => clk, rst => rst, now_sec => t_sec, now_ns => t_ns,
              lat_ns => x"0014", sfd_pulse => t_sfd, rd_ack => '0',
              ts_sec => ts_sec, ts_ns => ts_ns, ts_valid => ts_v, ts_overrun => open);

  u_clk : entity work.ptp_clock
    port map (clk => clk, rst => rst, role_slave => '1', clr_servo => clr,
              kp => x"0100", ki => x"0100", offset_err => err, offset_valid => ov,
              now_sec => open, now_ns => open, rate_adj_o => rate, offset_applied_o => applied);

  u_regs : entity work.ptp_regs
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
              wdata => wdata, rdata => rdata, irq => irq,
              role_slave => open, loopback => open, enable => open, kp => open, ki => open,
              tx_lat => open, rx_lat => open, clock_id => open, port_num => open,
              src_mac => open, send_sync => open, start_pdelay => open,
              tmo_cycles => open, allowed_lost => open, chk_resp => open,
              now_sec => r_sec, now_ns => x"00000123", mpd_ns => (others => '0'),
              mpd_valid => '0', offset_ns => (others => '0'), offset_valid => '0',
              rate_adj => (others => '0'), rx_sync_ev => '0', rx_resp_ev => '0',
              ev_pd_timeout => ev_tmo,
              dbg_state => (others => '0'), dbg_rxdst => (others => '0'),
              dbg_rxinfo => (others => '0'), dbg_fptr => (others => '0'),
              dbg_ftx => (others => '0'));

  stim : process
    variable v : std_logic_vector(31 downto 0);
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure wr(a : integer; d : std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a / 4, 6)); wdata <= d; sel <= '1'; we <= '1';
      step; sel <= '0'; we <= '0';
    end procedure;
    procedure rd(a : integer; o : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a / 4, 6)); sel <= '1'; we <= '0';
      wait for 1 ns; o := rdata;
      step; sel <= '0';
    end procedure;
    procedure ovp(e : integer) is
    begin
      err <= std_logic_vector(to_signed(e, ERR_W)); ov <= '1'; step; ov <= '0'; step; step;
    end procedure;
  begin
    rst <= '1'; step; step; rst <= '0'; step;

    -- L1
    t_sec <= (others => '0'); t_ns <= std_logic_vector(to_unsigned(5, NS_W));
    t_sfd <= '1'; step; t_sfd <= '0'; step;
    assert ts_v = '1' report "L1: no timestamp" severity failure;
    assert unsigned(ts_sec) = 0 and unsigned(ts_ns) = 0
      report "L1: sec=0 borrow wrapped (sec=" & to_hstring(ts_sec) & " ns=" &
             to_hstring(ts_ns) & ")" severity failure;

    -- L2: first offset = jump; second = PI step (rate /= 0)
    ovp(1000);
    assert applied = '1' report "L2: jump not applied" severity failure;
    ovp(5000);
    assert signed(rate) /= 0 report "L2: PI did not run" severity failure;
    -- clear and PI edge in the SAME cycle
    err <= std_logic_vector(to_signed(5000, ERR_W)); ov <= '1'; clr <= '1';
    step; ov <= '0'; clr <= '0'; step; step;
    assert signed(rate) = 0 report "L2: clr_servo lost against a same-cycle PI update"
      severity failure;
    assert applied = '0' report "L2: offset_applied not re-armed" severity failure;

    -- L3
    rd(16#28#, v);
    assert v = x"56789ABC" report "L3: NOW_SEC low word" severity failure;
    r_sec <= x"FFFF00000000";                         -- changes after the snapshot
    step;
    rd(16#5C#, v);
    assert v = x"00001234"
      report "L3: NOW_SECHI = " & to_hstring(v) & " (expected frozen 0x1234)" severity failure;

    -- L4: STATUS[4] pd_timeout sticky, W1C per bit, IRQ masking
    wr(16#40#, x"00000010");                          -- IRQEN bit 4
    ev_tmo <= '1'; step; ev_tmo <= '0'; step;
    rd(16#24#, v);
    assert v(4) = '1' report "L4: pd_timeout sticky not set" severity failure;
    assert irq = '1' report "L4: IRQ not raised by STATUS[4]" severity failure;
    wr(16#24#, x"00000001");                          -- clear another bit only
    rd(16#24#, v);
    assert v(4) = '1' report "L4: W1C of bit 0 cleared bit 4" severity failure;
    wr(16#24#, x"00000010");
    rd(16#24#, v);
    assert v(4) = '0' and irq = '0' report "L4: W1C of bit 4 failed" severity failure;

    report "TB_PTP_BAJA PASS (tstamp clamp, clr_servo priority, NOW_SECHI, W1C)";
    finish;
  end process;
end architecture;
