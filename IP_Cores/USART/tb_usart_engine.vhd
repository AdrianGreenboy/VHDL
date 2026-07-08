--------------------------------------------------------------------------------
-- tb_usart_engine.vhd -- Layer-1 self-checking testbench for usart_engine.
--
-- The behavioral model is deliberately an INDEPENDENT implementation: pure
-- time-based (wait for bit_period), no NCO, no oversampling, so a systematic
-- bug in the DUT cannot be mirrored by the checker.
--
-- Test list
--   T1  8N1 TX, 4 bytes back-to-back + total-time check (no inter-char gaps)
--   T2  8N1 RX, 4 bytes from the model
--   T3  formats: 8E1, 8O2 (2 stops on TX checked), 7N1 -- both directions
--   T4  RX baud mismatch tolerance: model at -2% and +2% bit period
--   T5  glitch on RXD (100 ns) -> no character, no errors (false-start reject)
--   T6  parity error injection  -> par_err pulse, data still pushed
--   T7  framing error injection -> frame_err pulse, data still pushed
--   T8  break (line low 13 bit times) -> single break_det, NO push, recovery
--   T9  CTS gating: held before start; raised mid-frame -> char completes,
--       next char held until CTS_n released
--   T10 FLOW_EN=0 -> CTS_n completely ignored
--   T11 LOOP_INT: 3 bytes TX->RX internally, full duplex
--   T12 HALF_DUP: (a) TX drives shared line + echo suppressed
--                 (b) TX defers to ongoing remote RX + turnaround respected
--
-- Sim clock 100 MHz, baud 2 Mbaud (bit = 500 ns) to keep runtime short.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_usart_engine is
end entity;

architecture sim of tb_usart_engine is

  constant CLK_P : time := 10 ns;                       -- 100 MHz
  constant BAUD  : real := 2000000.0;
  constant BITP  : time := 500 ns;                      -- 1/BAUD
  constant K_NAT : natural := natural(BAUD * 16.0 / 100.0e6 * 2.0**32);

  -- DUT I/O
  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal en       : std_logic := '0';
  signal tx_en    : std_logic := '1';
  signal rx_en    : std_logic := '1';
  signal par_en   : std_logic := '0';
  signal par_odd  : std_logic := '0';
  signal stop2    : std_logic := '0';
  signal data7    : std_logic := '0';
  signal flow_en  : std_logic := '0';
  signal half_dup : std_logic := '0';
  signal loop_int : std_logic := '0';
  signal baud_k   : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(K_NAT, 32));

  signal tx_valid : std_logic := '0';
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_ready : std_logic;
  signal rx_valid : std_logic;
  signal rx_data  : std_logic_vector(7 downto 0);
  signal frame_err, par_err, break_det : std_logic;
  signal tx_busy, rx_busy, bit_tick    : std_logic;
  signal rxd_i, txd_line_i             : std_logic := '1';
  signal txd_o, txd_t, tx_active       : std_logic;
  signal cts_n_i                       : std_logic := '0';

  -- TB plumbing
  signal tb_rxd  : std_logic := '1';                    -- full-duplex RXD driver
  signal tb_cts  : std_logic := '0';
  signal tb_hd   : std_logic := 'Z';                    -- half-duplex remote driver
  signal line_hd : std_logic;                           -- shared line (resolved)
  signal line_clean : std_logic;

  -- engine-TX feeder queue (FWFT emulation)
  type t_barr is array (0 to 127) of std_logic_vector(7 downto 0);
  signal txq     : t_barr := (others => (others => '0'));
  signal txq_wr  : integer range 0 to 127 := 0;
  signal txq_rd  : integer range 0 to 127 := 0;

  -- RX capture + event counters
  signal rxq     : t_barr := (others => (others => '0'));
  signal rxq_wr  : integer range 0 to 127 := 0;
  signal n_ferr, n_perr, n_brk : integer := 0;

  -- half-duplex remote sender handshake
  signal hd_go   : std_logic := '0';
  signal hd_byte : std_logic_vector(7 downto 0) := x"A5";

  ------------------------------------------------------------------------------
  -- Independent behavioral UART: transmitter (drives a line, time-based)
  ------------------------------------------------------------------------------
  procedure uart_tx_beh(signal   l          : out std_logic;
                        constant d          : in  std_logic_vector(7 downto 0);
                        constant bp         : in  time;
                        constant nb         : in  integer := 8;
                        constant paren      : in  boolean := false;
                        constant parodd     : in  boolean := false;
                        constant force_perr : in  boolean := false;
                        constant force_ferr : in  boolean := false) is
    variable p : std_logic := '0';
  begin
    l <= '0';  wait for bp;                             -- start
    for i in 0 to nb - 1 loop
      l <= d(i);
      p := p xor d(i);
      wait for bp;
    end loop;
    if paren then
      if parodd     then p := not p; end if;
      if force_perr then p := not p; end if;
      l <= p;  wait for bp;
    end if;
    if force_ferr then
      l <= '0';  wait for bp;                           -- corrupted stop
      l <= '1';  wait for bp;                           -- line recovery
    else
      l <= '1';  wait for bp;                           -- stop
    end if;
  end procedure;

  ------------------------------------------------------------------------------
  -- Independent behavioral UART: receiver/checker (mid-bit time sampling)
  ------------------------------------------------------------------------------
  procedure uart_rx_beh(signal   l           : in std_logic;
                        constant exp         : in std_logic_vector(7 downto 0);
                        constant bp          : in time;
                        constant tag         : in string;
                        constant nb          : in integer := 8;
                        constant paren       : in boolean := false;
                        constant parodd      : in boolean := false;
                        constant check_stop2 : in boolean := false) is
    variable d : std_logic_vector(7 downto 0) := (others => '0');
    variable p : std_logic := '0';
  begin
    if l /= '0' then
      wait until l = '0';                               -- start edge
    end if;
    wait for bp / 2;
    assert l = '0'
      report tag & ": start bit not low at mid-cell" severity failure;
    for i in 0 to nb - 1 loop
      wait for bp;
      d(i) := l;
      p := p xor l;
    end loop;
    if paren then
      wait for bp;
      if parodd then p := not p; end if;
      assert l = p
        report tag & ": TX parity bit wrong" severity failure;
    end if;
    wait for bp;
    assert l = '1'
      report tag & ": stop bit 1 not high" severity failure;
    if check_stop2 then
      wait for bp;
      assert l = '1'
        report tag & ": stop bit 2 not high" severity failure;
    end if;
    assert d = exp
      report tag & ": data mismatch, got 0x" & to_hstring(d) &
             " expected 0x" & to_hstring(exp) severity failure;
  end procedure;

begin

  clk <= not clk after CLK_P / 2;

  ------------------------------------------------------------------------------
  -- DUT
  ------------------------------------------------------------------------------
  dut : entity work.usart_engine
    port map (
      clk => clk, rst_n => rst_n,
      en => en, tx_en => tx_en, rx_en => rx_en,
      par_en => par_en, par_odd => par_odd, stop2 => stop2, data7 => data7,
      flow_en => flow_en, half_dup => half_dup, loop_int => loop_int,
      baud_k => baud_k,
      tx_valid => tx_valid, tx_data => tx_data, tx_ready => tx_ready,
      rx_valid => rx_valid, rx_data => rx_data,
      frame_err => frame_err, par_err => par_err, break_det => break_det,
      tx_busy => tx_busy, rx_busy => rx_busy, bit_tick => bit_tick,
      rxd_i => rxd_i, txd_line_i => txd_line_i,
      txd_o => txd_o, txd_t => txd_t,
      cts_n_i => cts_n_i, tx_active => tx_active
    );

  rxd_i   <= tb_rxd;
  cts_n_i <= tb_cts;

  -- half-duplex shared line: weak pull-up + engine tristate driver + remote
  line_hd    <= 'H';
  line_hd    <= txd_o when txd_t = '0' else 'Z';
  line_hd    <= tb_hd;
  line_clean <= to_x01(line_hd);
  txd_line_i <= line_clean;

  ------------------------------------------------------------------------------
  -- FWFT feeder: presents txq bytes on tx_valid/tx_data, advances on tx_ready
  ------------------------------------------------------------------------------
  feeder : process(clk)
  begin
    if rising_edge(clk) then
      if txq_rd < txq_wr then
        tx_valid <= '1';
        tx_data  <= txq(txq_rd);
        if tx_ready = '1' then
          txq_rd <= txq_rd + 1;
        end if;
      else
        tx_valid <= '0';
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- RX capture + event counters
  ------------------------------------------------------------------------------
  capture : process(clk)
  begin
    if rising_edge(clk) then
      if rx_valid = '1' then
        rxq(rxq_wr) <= rx_data;
        rxq_wr      <= rxq_wr + 1;
      end if;
      if frame_err = '1' then n_ferr <= n_ferr + 1; end if;
      if par_err   = '1' then n_perr <= n_perr + 1; end if;
      if break_det = '1' then n_brk  <= n_brk  + 1; end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Half-duplex remote sender (one byte per hd_go pulse)
  ------------------------------------------------------------------------------
  hd_sender : process
  begin
    tb_hd <= 'Z';
    wait until hd_go = '1';
    uart_tx_beh(tb_hd, hd_byte, BITP);
    tb_hd <= 'Z';
    wait until hd_go = '0';
  end process;

  ------------------------------------------------------------------------------
  -- Watchdog
  ------------------------------------------------------------------------------
  watchdog : process
  begin
    wait for 5 ms;
    report "TIMEOUT: testbench hung" severity failure;
  end process;

  ------------------------------------------------------------------------------
  -- Stimulus / checker
  ------------------------------------------------------------------------------
  stim : process
    variable qi   : integer := 0;                       -- txq write mirror
    variable base : integer;
    variable f0, p0, b0 : integer;
    variable t0   : time;
    variable dt   : time;

    procedure queue_tx(constant d : in std_logic_vector(7 downto 0)) is
    begin
      txq(qi) <= d;
      qi      := qi + 1;
      txq_wr  <= qi;
    end procedure;

    procedure cfg_default is
    begin
      wait for 2 * BITP;                                -- let TX/RX finish stops
      par_en <= '0'; par_odd <= '0'; stop2 <= '0'; data7 <= '0';
      flow_en <= '0'; half_dup <= '0'; loop_int <= '0';
      tb_cts <= '0'; tb_rxd <= '1'; hd_go <= '0';
      wait for 2 * BITP;                                -- settle with new config
    end procedure;

  begin
    ----------------------------------------------------------------------------
    -- reset
    ----------------------------------------------------------------------------
    rst_n <= '0';
    wait for 200 ns;
    rst_n <= '1';
    en    <= '1';
    wait for 200 ns;

    ----------------------------------------------------------------------------
    report "[T1] 8N1 TX back-to-back";
    cfg_default;
    t0 := now;
    queue_tx(x"11"); queue_tx(x"22"); queue_tx(x"33"); queue_tx(x"44");
    uart_rx_beh(txd_o, x"11", BITP, "T1.0");
    uart_rx_beh(txd_o, x"22", BITP, "T1.1");
    uart_rx_beh(txd_o, x"33", BITP, "T1.2");
    uart_rx_beh(txd_o, x"44", BITP, "T1.3");
    dt := now - t0;
    assert dt < 41 * BITP + BITP / 2
      report "T1: inter-char gaps detected, 4 chars took " & time'image(dt)
      severity failure;
    report "[T1] PASS (4 chars in " & time'image(dt) & ")";

    ----------------------------------------------------------------------------
    report "[T2] 8N1 RX from behavioral model";
    cfg_default;
    base := rxq_wr;
    uart_tx_beh(tb_rxd, x"C5", BITP);
    uart_tx_beh(tb_rxd, x"01", BITP);
    uart_tx_beh(tb_rxd, x"FE", BITP);
    uart_tx_beh(tb_rxd, x"80", BITP);
    wait for 2 * BITP;
    assert rxq_wr = base + 4
      report "T2: expected 4 bytes, got " & integer'image(rxq_wr - base)
      severity failure;
    assert rxq(base) = x"C5" and rxq(base + 1) = x"01" and
           rxq(base + 2) = x"FE" and rxq(base + 3) = x"80"
      report "T2: RX data mismatch" severity failure;
    report "[T2] PASS";

    ----------------------------------------------------------------------------
    report "[T3] formats: 8E1 / 8O2 / 7N1, both directions";
    -- 8E1
    cfg_default;
    par_en <= '1';
    wait for BITP;
    base := rxq_wr;
    queue_tx(x"AA");
    uart_rx_beh(txd_o, x"AA", BITP, "T3-8E1-TX", paren => true);
    uart_tx_beh(tb_rxd, x"55", BITP, paren => true);
    wait for 2 * BITP;
    assert rxq_wr = base + 1 and rxq(base) = x"55"
      report "T3-8E1-RX: data/count mismatch" severity failure;
    -- 8O2
    cfg_default;
    par_en <= '1'; par_odd <= '1'; stop2 <= '1';
    wait for BITP;
    base := rxq_wr;
    queue_tx(x"0F");
    uart_rx_beh(txd_o, x"0F", BITP, "T3-8O2-TX",
                paren => true, parodd => true, check_stop2 => true);
    uart_tx_beh(tb_rxd, x"F0", BITP, paren => true, parodd => true);
    wait for 2 * BITP;
    assert rxq_wr = base + 1 and rxq(base) = x"F0"
      report "T3-8O2-RX: data/count mismatch" severity failure;
    -- 7N1
    cfg_default;
    data7 <= '1';
    wait for BITP;
    base := rxq_wr;
    queue_tx(x"7B");
    uart_rx_beh(txd_o, x"7B", BITP, "T3-7N1-TX", nb => 7);
    uart_tx_beh(tb_rxd, x"2E", BITP, nb => 7);
    wait for 2 * BITP;
    assert rxq_wr = base + 1 and rxq(base) = x"2E"
      report "T3-7N1-RX: data/count mismatch" severity failure;
    report "[T3] PASS";

    ----------------------------------------------------------------------------
    report "[T4] RX baud mismatch tolerance (+/-2%)";
    cfg_default;
    base := rxq_wr;
    uart_tx_beh(tb_rxd, x"96", 490 ns);                 -- model 2% fast
    wait for 2 * BITP;
    uart_tx_beh(tb_rxd, x"69", 510 ns);                 -- model 2% slow
    wait for 2 * BITP;
    assert rxq_wr = base + 2 and rxq(base) = x"96" and rxq(base + 1) = x"69"
      report "T4: mismatch tolerance failed" severity failure;
    report "[T4] PASS";

    ----------------------------------------------------------------------------
    report "[T5] glitch rejection (100 ns low pulse)";
    cfg_default;
    base := rxq_wr; f0 := n_ferr; b0 := n_brk;
    tb_rxd <= '0';
    wait for 100 ns;
    tb_rxd <= '1';
    wait for 3 * BITP;
    assert rxq_wr = base and n_ferr = f0 and n_brk = b0
      report "T5: glitch produced a character or an error" severity failure;
    report "[T5] PASS";

    ----------------------------------------------------------------------------
    report "[T6] parity error injection (8E1)";
    cfg_default;
    par_en <= '1';
    wait for BITP;
    base := rxq_wr; p0 := n_perr;
    uart_tx_beh(tb_rxd, x"3A", BITP, paren => true, force_perr => true);
    wait for 2 * BITP;
    assert n_perr = p0 + 1
      report "T6: par_err pulse missing" severity failure;
    assert rxq_wr = base + 1 and rxq(base) = x"3A"
      report "T6: data must be pushed on parity error" severity failure;
    report "[T6] PASS";

    ----------------------------------------------------------------------------
    report "[T7] framing error injection (bad stop, data non-zero)";
    cfg_default;
    base := rxq_wr; f0 := n_ferr;
    uart_tx_beh(tb_rxd, x"55", BITP, force_ferr => true);
    wait for 2 * BITP;
    assert n_ferr = f0 + 1
      report "T7: frame_err pulse missing" severity failure;
    assert rxq_wr = base + 1 and rxq(base) = x"55"
      report "T7: data must be pushed on framing error" severity failure;
    report "[T7] PASS";

    ----------------------------------------------------------------------------
    report "[T8] break detection + single event + recovery";
    cfg_default;
    base := rxq_wr; b0 := n_brk; f0 := n_ferr;
    tb_rxd <= '0';
    wait for 13 * BITP;                                 -- > full frame low
    tb_rxd <= '1';
    wait for 3 * BITP;
    assert n_brk = b0 + 1
      report "T8: expected exactly one break_det, got " &
             integer'image(n_brk - b0) severity failure;
    assert rxq_wr = base
      report "T8: break must not push data" severity failure;
    assert n_ferr = f0
      report "T8: break misclassified as framing error" severity failure;
    uart_tx_beh(tb_rxd, x"C3", BITP);                   -- recovery after break
    wait for 2 * BITP;
    assert rxq_wr = base + 1 and rxq(base) = x"C3"
      report "T8: RX did not recover after break" severity failure;
    report "[T8] PASS";

    ----------------------------------------------------------------------------
    report "[T9] CTS gating at character boundary (FLOW_EN=1)";
    cfg_default;
    flow_en <= '1';
    tb_cts  <= '1';                                     -- not clear to send
    wait for BITP;
    queue_tx(x"5A");
    wait for 6 * BITP;
    assert tx_busy = '0' and txd_o = '1'
      report "T9a: TX started while CTS_n=1" severity failure;
    tb_cts <= '0';
    uart_rx_beh(txd_o, x"5A", BITP, "T9a");
    -- mid-stream: raise CTS during char 1, char must complete, char 2 held
    wait for 2 * BITP;
    queue_tx(x"00"); queue_tx(x"F0");
    wait until txd_o = '0';                             -- start of char 1
    tb_cts <= '1';
    wait for 8.5 * BITP;                                -- mid of last data bit
    assert txd_o = '0'
      report "T9b: char 1 (0x00) aborted mid-frame" severity failure;
    wait for BITP;                                      -- mid stop bit
    assert txd_o = '1'
      report "T9b: char 1 stop bit corrupted" severity failure;
    wait for 3 * BITP;
    assert tx_busy = '0' and txd_o = '1'
      report "T9b: char 2 started while CTS_n=1" severity failure;
    tb_cts <= '0';
    uart_rx_beh(txd_o, x"F0", BITP, "T9b");
    report "[T9] PASS";

    ----------------------------------------------------------------------------
    report "[T10] FLOW_EN=0 ignores CTS_n";
    cfg_default;
    tb_cts <= '1';
    wait for BITP;
    queue_tx(x"77");
    uart_rx_beh(txd_o, x"77", BITP, "T10");             -- watchdog guards a hang
    tb_cts <= '0';
    report "[T10] PASS";

    ----------------------------------------------------------------------------
    report "[T11] LOOP_INT (full duplex, no pads)";
    cfg_default;
    loop_int <= '1';
    wait for BITP;
    base := rxq_wr;
    queue_tx(x"DE"); queue_tx(x"AD"); queue_tx(x"BE");
    wait for 35 * BITP;
    assert rxq_wr = base + 3 and rxq(base) = x"DE" and
           rxq(base + 1) = x"AD" and rxq(base + 2) = x"BE"
      report "T11: internal loopback data mismatch" severity failure;
    report "[T11] PASS";

    ----------------------------------------------------------------------------
    report "[T12a] half duplex: shared-line TX + echo suppression";
    cfg_default;
    half_dup <= '1';
    wait for 2 * BITP;
    base := rxq_wr;
    queue_tx(x"C3"); queue_tx(x"81");
    uart_rx_beh(line_clean, x"C3", BITP, "T12a.0");
    uart_rx_beh(line_clean, x"81", BITP, "T12a.1");
    wait for 3 * BITP;
    assert rxq_wr = base
      report "T12a: echo not suppressed (" &
             integer'image(rxq_wr - base) & " bytes leaked into RX)"
      severity failure;
    report "[T12a] PASS";

    ----------------------------------------------------------------------------
    report "[T12b] half duplex: TX defers to remote RX + turnaround";
    base := rxq_wr;
    hd_byte <= x"A5";
    hd_go   <= '1';                                     -- remote starts sending
    wait for 0.75 * BITP;
    queue_tx(x"3C");                                    -- our TX now pending
    for k in 1 to 8 loop                                -- sample inside remote frame
      wait for BITP;
      assert tx_busy = '0'
        report "T12b: TX drove the line during a remote frame (bit " &
               integer'image(k) & ")" severity failure;
    end loop;
    wait for 1.5 * BITP;                                -- remote stop finished
    assert tx_busy = '0'
      report "T12b: TX started before the turnaround expired" severity failure;
    t0 := now;
    wait until line_clean = '0';                        -- our start bit
    dt := now - t0;
    assert dt >= 0.15 * BITP
      report "T12b: turnaround too short (" & time'image(dt) & ")"
      severity failure;
    uart_rx_beh(line_clean, x"3C", BITP, "T12b-TX");
    hd_go <= '0';
    wait for 2 * BITP;
    assert rxq_wr = base + 1 and rxq(base) = x"A5"
      report "T12b: remote byte 0xA5 not received" severity failure;
    report "[T12b] PASS";

    ----------------------------------------------------------------------------
    report "==================================================";
    report "tb_usart_engine: ALL TESTS PASSED";
    report "==================================================";
    std.env.finish;
  end process;

end architecture sim;
