-- ============================================================================
--  tb_i2c_master_audit.vhd - Self-checking test of the i2c_master escape
--  paths added by the audit 2026-11 (English).
--
--  Bus: wired-AND of the DUT drivers and TB "devices" (ext_scl / ext_sda,
--  '1' = released). scl_div = 4 -> one quarter = 5 clk = 50 ns.
--
--  R1  bus_busy = '1' after reset; the first START is only generated after
--      BUS_FREE_Q quarters of SCL = SDA = '1' have been observed.
--  R2  Clock-stretch timeout: a device holds SCL low forever during the
--      first data bit -> `timeout` after ~tout_q quarters, both lines
--      released, engine idle (busy = 0) and usable again.
--  R3  Stuck bus: SDA held low after a foreign START (bus_busy = '1', no SCL
--      activity) -> WAITFREE gives up with `timeout`.
--  R4  tBUF after a foreign STOP: our START (SDA fall with SCL high) comes
--      >= 4 quarters after the foreign STOP.
--  R5  STOP in ST_HELD with en = '0': the bus is released with a real STOP.
--  R6  Bus clear: a device holds SDA low and lets go after 5 SCL pulses;
--      cmd_clear produces exactly 9 SCL pulses + STOP, done pulses and the
--      bus is free afterwards.
--  R7  Bus clear with SCL stuck low -> timeout (no hang).
--  R8  tout_q = 0 keeps the legacy behaviour (no timeout while stretched).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i2c_master_audit is
end entity;

architecture sim of tb_i2c_master_audit is
  constant TCLK : time := 10 ns;
  constant Q    : time := 50 ns;                  -- quarter (scl_div = 4)

  signal clk, rst : std_logic := '0';
  signal en       : std_logic := '0';
  signal cmd_valid, cmd_start, cmd_stop, cmd_read, cmd_ackout : std_logic := '0';
  signal cmd_nobyte, cmd_clear : std_logic := '0';
  signal cmd_wdata : std_logic_vector(7 downto 0) := x"00";
  signal tout_q    : std_logic_vector(15 downto 0) := x"0000";
  signal busy, done, ack_in, arb_lost, bus_busy, xact_open, timeout : std_logic;
  signal line_scl, line_sda : std_logic;
  signal rdata : std_logic_vector(7 downto 0);
  signal m_scl_t, m_sda_t : std_logic;
  signal ext_scl, ext_sda : std_logic := '1';
  signal scl, sda : std_logic;

  -- monitors
  signal n_tout, n_done, n_scl_fall : natural := 0;
  signal t_last_stop, t_last_start : time := 0 ns;
  signal n_stop, n_start : natural := 0;
begin
  clk <= not clk after TCLK / 2;

  scl <= m_scl_t and ext_scl;
  sda <= m_sda_t and ext_sda;

  dut : entity work.i2c_master
    generic map (BUS_FREE_Q => 8)
    port map (
      clk => clk, rst => rst, en => en, scl_div => x"0004",
      cmd_valid => cmd_valid, cmd_start => cmd_start, cmd_stop => cmd_stop,
      cmd_read => cmd_read, cmd_ackout => cmd_ackout, cmd_nobyte => cmd_nobyte,
      cmd_wdata => cmd_wdata, cmd_clear => cmd_clear, tout_q => tout_q,
      busy => busy, done => done, rdata => rdata, ack_in => ack_in,
      arb_lost => arb_lost, bus_busy => bus_busy, xact_open => xact_open,
      timeout => timeout, line_scl => line_scl, line_sda => line_sda,
      scl_i => scl, scl_t => m_scl_t, sda_i => sda, sda_t => m_sda_t);

  mon : process(clk)
  begin
    if rising_edge(clk) then
      if timeout = '1' then n_tout <= n_tout + 1; end if;
      if done = '1' then n_done <= n_done + 1; end if;
    end if;
  end process;

  linemon : process
  begin
    wait on scl, sda;
    if scl'event and scl = '0' then n_scl_fall <= n_scl_fall + 1; end if;
    if sda'event and scl = '1' and sda = '1' then
      n_stop <= n_stop + 1; t_last_stop <= now;
    end if;
    if sda'event and scl = '1' and sda = '0' then
      n_start <= n_start + 1; t_last_start <= now;
    end if;
  end process;

  stim : process
    procedure tick(n : natural := 1) is
    begin
      for i in 1 to n loop wait until rising_edge(clk); end loop;
    end procedure;
    procedure cmd(s, p, r, nb, cl : std_logic; d : std_logic_vector(7 downto 0)) is
    begin
      cmd_start <= s; cmd_stop <= p; cmd_read <= r; cmd_nobyte <= nb;
      cmd_clear <= cl; cmd_wdata <= d; cmd_valid <= '1';
      tick;
      cmd_valid <= '0'; cmd_start <= '0'; cmd_stop <= '0'; cmd_read <= '0';
      cmd_nobyte <= '0'; cmd_clear <= '0';
    end procedure;
    procedure wait_idle(tmax : time; tag : string) is
      variable t0 : time := now;
    begin
      tick;
      while busy = '1' loop
        tick;
        assert now - t0 < tmax report tag & ": engine never left busy"
          severity failure;
      end loop;
      tick(2);                                    -- let the monitors settle
    end procedure;
    variable t0 : time;
    variable n0, d0 : natural;
  begin
    rst <= '1'; tick(5);
    rst <= '0'; en <= '1';
    tick;

    ------------------------------------------------------------------ R1
    report "R1: bus_busy after reset, START only after idle observation";
    assert bus_busy = '1' report "R1: bus_busy not set after reset" severity failure;
    t0 := now;
    n0 := n_start;
    cmd('1', '1', '0', '0', '0', x"A0");          -- write + STOP (NACKed)
    wait until n_start > n0 for 5 us;
    assert n_start > n0 report "R1: START never generated" severity failure;
    assert t_last_start - t0 >= 8 * Q
      report "R1: START issued before the bus-free observation window"
      severity failure;
    wait_idle(20 us, "R1");
    assert bus_busy = '0' report "R1: bus_busy after own STOP" severity failure;
    report "R1 PASS";

    ------------------------------------------------------------------ R2
    report "R2: clock-stretch timeout";
    tout_q <= x"0028";                            -- 40 quarters = 2 us
    tick(20);
    n0 := n_tout; d0 := n_done;
    cmd('1', '0', '0', '0', '0', x"A0");
    wait until n_scl_fall >= 2 for 10 us;         -- START fall + first bit
    wait until scl = '0' for 1 us;
    ext_scl <= '0';                               -- device stretches forever
    t0 := now;
    wait until n_tout > n0 for 10 us;
    assert n_tout = n0 + 1 report "R2: no timeout pulse" severity failure;
    assert now - t0 >= 40 * Q and now - t0 < 50 * Q
      report "R2: timeout not ~tout_q quarters: " & time'image(now - t0)
      severity failure;
    tick(2);
    assert busy = '0' and xact_open = '0' and m_scl_t = '1' and m_sda_t = '1'
      report "R2: engine did not release after timeout" severity failure;
    assert n_done = d0 report "R2: done pulsed on timeout" severity failure;
    ext_scl <= '1';
    tick(200);
    report "R2 PASS";

    ------------------------------------------------------------------ R3
    report "R3: stuck bus in WAITFREE";
    ext_sda <= '0';                               -- foreign START, then hang
    tick(20);
    assert bus_busy = '1' report "R3: foreign START not seen" severity failure;
    n0 := n_tout;
    cmd('1', '1', '0', '0', '0', x"A0");
    wait until n_tout > n0 for 10 us;
    assert n_tout = n0 + 1 report "R3: WAITFREE never timed out" severity failure;
    tick(2);
    assert busy = '0' report "R3: still busy" severity failure;
    report "R3 PASS";

    ------------------------------------------------------------------ R4
    report "R4: tBUF after a foreign STOP";
    -- foreign master is mid-transaction (SDA low from R3); issue our command
    cmd('1', '1', '0', '0', '0', x"A0");
    tick(30);
    assert busy = '1' and m_sda_t = '1' report "R4: DUT must wait" severity failure;
    n0 := n_start;
    ext_sda <= '1';                               -- foreign STOP (SCL high)
    wait until n_start > n0 for 5 us;
    assert n_start > n0 report "R4: our START never came" severity failure;
    assert t_last_start - t_last_stop >= 4 * Q
      report "R4: tBUF violated: " & time'image(t_last_start - t_last_stop)
      severity failure;
    wait_idle(20 us, "R4");
    report "R4 PASS";

    ------------------------------------------------------------------ R5
    report "R5: STOP in ST_HELD with en = 0";
    tick(50);
    cmd('1', '0', '0', '0', '0', x"A0");          -- byte without STOP -> HELD
    wait_idle(20 us, "R5 byte");
    assert xact_open = '1' and m_scl_t = '0' report "R5: not held" severity failure;
    en <= '0';
    tick(5);
    n0 := n_stop; d0 := n_done;
    cmd('0', '1', '0', '1', '0', x"00");          -- NOBYTE | STOP
    wait_idle(20 us, "R5 stop");
    assert n_stop > n0 report "R5: no STOP on the bus" severity failure;
    assert n_done = d0 + 1 report "R5: done count " & integer'image(n_done - d0) severity failure;
    assert xact_open = '0' and m_scl_t = '1' and m_sda_t = '1'
      report "R5: bus not released" severity failure;
    en <= '1';
    report "R5 PASS";

    ------------------------------------------------------------------ R6
    report "R6: bus clear (9 SCL pulses + STOP)";
    tick(50);
    ext_sda <= '0';                               -- stuck slave holds SDA
    tick(10);
    n0 := n_scl_fall; d0 := n_done;
    cmd('0', '0', '0', '0', '1', x"00");
    -- slave releases SDA after 5 SCL pulses
    wait until n_scl_fall >= n0 + 5 for 20 us;
    ext_sda <= '1';
    wait_idle(30 us, "R6");
    assert n_scl_fall - n0 = 10                   -- 9 clear pulses + STOP's low
      report "R6: wrong number of SCL falls: " & integer'image(n_scl_fall - n0)
      severity failure;
    assert n_done = d0 + 1 report "R6: no done" severity failure;
    assert m_scl_t = '1' and m_sda_t = '1' and scl = '1' and sda = '1'
      report "R6: lines not released after clear" severity failure;
    tick(100);
    assert bus_busy = '0' report "R6: bus not free after clear" severity failure;
    report "R6 PASS";

    ------------------------------------------------------------------ R7
    report "R7: bus clear with SCL stuck low -> timeout";
    ext_scl <= '0';
    n0 := n_tout;
    cmd('0', '0', '0', '0', '1', x"00");
    wait until n_tout > n0 for 10 us;
    assert n_tout = n0 + 1 report "R7: no timeout" severity failure;
    tick(2);
    assert busy = '0' report "R7: still busy" severity failure;
    ext_scl <= '1';
    report "R7 PASS";

    ------------------------------------------------------------------ R8
    report "R8: tout_q = 0 keeps legacy behaviour (no timeout)";
    tout_q <= x"0000";
    tick(200);
    n0 := n_tout; d0 := n_scl_fall;
    cmd('1', '1', '0', '0', '0', x"A0");
    wait until n_scl_fall >= d0 + 2 for 10 us;
    wait until scl = '0' for 1 us;
    ext_scl <= '0';
    wait for 10 us;
    assert n_tout = n0 and busy = '1'
      report "R8: timeout fired although disabled" severity failure;
    ext_scl <= '1';
    wait_idle(30 us, "R8");
    report "R8 PASS";

    report "tb_i2c_master_audit: ALL TESTS PASSED";
    finish;
  end process;

  watchdog : process
  begin
    wait for 2 ms;
    report "TIMEOUT: testbench hung" severity failure;
  end process;
end architecture sim;
