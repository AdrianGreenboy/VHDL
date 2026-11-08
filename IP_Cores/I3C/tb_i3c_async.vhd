-- ============================================================================
--  tb_i3c_async.vhd - Controller RTL <-> target RTL on DIFFERENT, DRIFTING
--  clocks (audit 2026-11).
--
--  The controller runs on clk_c (100 MHz, 10 ns). The target runs on clk_t,
--  whose period drifts sinusoidally by +/-DRIFT_PM/10 % around TT_PS and has a
--  small pseudo-random jitter, so every phase relation between the two
--  clock domains is swept during the run (the realistic case of an external
--  target with its own oscillator).
--
--  Bus: resolved SCL/SDA with pull-up/keeper ('H'). A contention monitor
--  measures the time during which BOTH ends drive SDA with OPPOSITE levels
--  (push-pull fight). Any contention fails the test; any 'X' on the bus as
--  well.
--
--  The full SDR protocol suite is executed for every (div_pp, div_od) of
--  the sweep table:
--    A1 RSTDAA (broadcast)                      A6 private read, T=0 end
--    A2 SETDASA SA -> DA 0x30 (directed CCC)    A7 GETPID / GETBCR / GETDCR
--    A3 RSTDAA + ENTDAA -> DA 0x31              A8 IBI with mandatory byte
--    A4 private write with T parity             A9 GETSTATUS
--    A5 private read with controller seize (Sr during T=1) + STOP
--  Minimum supported div_pp for a target on an independent clock is
--  MIN_DIV_PP_ASYNC (see README / AUDIT_FIXES.md); the sweep starts there.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

entity tb_i3c_async is
  generic (
    TT_PS    : natural := 9700;        -- target clock nominal period [ps]
    DRIFT_PM : natural := 40           -- +/- period drift [per mille]
  );
end entity;

architecture sim of tb_i3c_async is

  constant TT_NOM    : real := real(TT_PS) / 1000.0;   -- [ns]
  constant DRIFT_PCT : real := real(DRIFT_PM) / 10.0;  -- [%]

  constant TCLK : time := 10 ns;

  signal clk_c : std_logic := '0';
  signal clk_t : std_logic := '0';
  signal rst   : std_logic := '1';
  signal en    : std_logic := '0';
  signal div_pp : std_logic_vector(15 downto 0) := x"0002";
  signal div_od : std_logic_vector(15 downto 0) := x"0009";

  signal cmd_valid, cmd_start, cmd_stop, cmd_read, cmd_rlast : std_logic := '0';
  signal cmd_nobyte, cmd_daa, cmd_daadr, cmd_ibiack, cmd_ibinak : std_logic := '0';
  signal cmd_wdata : std_logic_vector(7 downto 0) := (others => '0');
  signal busy, done, rvalid, ack_in, t_bit, arb_lost : std_logic;
  signal rdata, ibi_addr : std_logic_vector(7 downto 0);
  signal ibi_req, ibi_avalid, xact_open : std_logic;
  signal c_scl_o, c_scl_t, c_sda_o, c_sda_t : std_logic;

  constant TGT_SA  : std_logic_vector(6 downto 0) := "1010010";  -- 0x52
  constant TGT_PID : std_logic_vector(47 downto 0) := x"045967ABCDEF";
  constant TGT_BCR : std_logic_vector(7 downto 0)  := x"46";
  constant TGT_DCR : std_logic_vector(7 downto 0)  := x"C6";
  constant TGT_STS : std_logic_vector(15 downto 0) := x"1234";
  constant TGT_MDB : std_logic_vector(7 downto 0)  := x"9C";
  constant PAY : std_logic_vector(63 downto 0) := TGT_PID & TGT_BCR & TGT_DCR;

  signal t_ibi_go : std_logic := '0';
  signal tx_data : std_logic_vector(7 downto 0);
  signal tx_valid, tx_ren : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);
  signal rx_valid, rx_perr : std_logic;
  signal t_da : std_logic_vector(6 downto 0);
  signal t_da_valid, t_ibi_en, t_hj_en : std_logic;
  signal t_mwl, t_mrl : std_logic_vector(15 downto 0);
  signal t_ibi_pend, t_hj_pend : std_logic;
  signal t_ibi_done, t_ibi_nakd, t_hj_done : std_logic;
  signal t_ev_daset, t_ev_rstdaa, t_in_frame : std_logic;
  signal t_sda_o, t_sda_t : std_logic;

  signal scl_b, sda_b : std_logic;
  signal scl_iw, sda_iw : std_logic;

  type slv8_arr is array (natural range <>) of std_logic_vector(7 downto 0);

  -- target-side FIFO model and monitors (clk_t domain)
  signal ftx     : slv8_arr(0 to 7) := (others => (others => '0'));
  signal ftx_n   : integer := 0;
  signal ftx_i   : integer := 0;
  signal ftx_rst : std_logic := '0';
  signal rxc : slv8_arr(0 to 7) := (others => (others => '0'));
  signal rxn : integer := 0;
  signal perr_c, ibid_c, tren_c : integer := 0;
  signal mon_rst : std_logic := '0';

  -- contention / bus integrity monitor
  signal fight_time : time := 0 ns;
  signal x_seen     : boolean := false;
  signal sim_done   : boolean := false;

  type cfg_t is record
    pp, od : natural;
  end record;
  type cfg_arr is array (natural range <>) of cfg_t;
  constant SWEEP : cfg_arr := ((2, 9), (2, 5), (3, 6), (5, 9), (9, 19));

begin

  clk_c <= not clk_c after TCLK / 2 when not sim_done;

  -- drifting + jittered target clock
  p_tclk : process
    variable ph, per : real;
    variable s1, s2 : positive := 3;
    variable r : real;
  begin
    while not sim_done loop
      ph  := 2.0 * MATH_PI * real(now / 1 ns) / 37000.0;     -- 37 us period
      uniform(s1, s2, r);
      per := TT_NOM * (1.0 + DRIFT_PCT / 100.0 * sin(ph)) + (r - 0.5) * 0.4;
      clk_t <= '1';
      wait for (per / 2.0) * 1 ns;
      clk_t <= '0';
      wait for (per / 2.0) * 1 ns;
    end loop;
    wait;
  end process;

  scl_b <= 'H';
  sda_b <= 'H';
  scl_b <= c_scl_o when c_scl_t = '0' else 'Z';
  sda_b <= c_sda_o when c_sda_t = '0' else 'Z';
  sda_b <= t_sda_o when t_sda_t = '0' else 'Z';
  scl_iw <= to_x01(scl_b);
  sda_iw <= to_x01(sda_b);

  fight : process
    variable t0 : time;
  begin
    wait until c_sda_t = '0' and t_sda_t = '0' and c_sda_o /= t_sda_o;
    t0 := now;
    wait until not (c_sda_t = '0' and t_sda_t = '0' and c_sda_o /= t_sda_o);
    fight_time <= fight_time + (now - t0);
    report "SDA CONTENTION for " & time'image(now - t0) & " at " &
           time'image(t0) severity error;
  end process;

  xmon : process(sda_iw, scl_iw)
  begin
    if now > 0 ns and (sda_iw = 'X' or scl_iw = 'X') then
      x_seen <= true;
    end if;
  end process;

  u_ctrl : entity work.i3c_controller
    port map (
      clk => clk_c, rst => rst, en => en,
      div_pp => div_pp, div_od => div_od,
      cmd_valid => cmd_valid, cmd_start => cmd_start, cmd_stop => cmd_stop,
      cmd_read => cmd_read, cmd_rlast => cmd_rlast, cmd_nobyte => cmd_nobyte,
      cmd_daa => cmd_daa, cmd_daadr => cmd_daadr,
      cmd_ibiack => cmd_ibiack, cmd_ibinak => cmd_ibinak,
      cmd_wdata => cmd_wdata,
      busy => busy, done => done, rdata => rdata, rvalid => rvalid,
      ack_in => ack_in, t_bit => t_bit, arb_lost => arb_lost,
      ibi_req => ibi_req, ibi_addr => ibi_addr, ibi_avalid => ibi_avalid,
      xact_open => xact_open,
      scl_o => c_scl_o, scl_t => c_scl_t, scl_i => scl_iw,
      sda_o => c_sda_o, sda_t => c_sda_t, sda_i => sda_iw
    );

  u_tgt : entity work.i3c_target
    port map (
      clk => clk_t, rst => rst, en => en,
      sa => TGT_SA, pid => TGT_PID, bcr => TGT_BCR, dcr => TGT_DCR,
      status_in => TGT_STS, mdb => TGT_MDB,
      ibi_go => t_ibi_go, hj_go => '0',
      tx_data => tx_data, tx_valid => tx_valid, tx_ren => tx_ren,
      rx_data => rx_data, rx_valid => rx_valid, rx_perr => rx_perr,
      da => t_da, da_valid => t_da_valid, ibi_en => t_ibi_en, hj_en => t_hj_en,
      mwl => t_mwl, mrl => t_mrl,
      ibi_pend => t_ibi_pend, hj_pend => t_hj_pend,
      ibi_done => t_ibi_done, ibi_nakd => t_ibi_nakd, hj_done => t_hj_done,
      ev_daset => t_ev_daset, ev_rstdaa => t_ev_rstdaa, in_frame => t_in_frame,
      scl_i => scl_iw, sda_i => sda_iw, sda_o => t_sda_o, sda_t => t_sda_t
    );

  tx_data  <= ftx(ftx_i) when ftx_i < 8 else x"00";
  tx_valid <= '1' when ftx_i < ftx_n else '0';
  fifo : process(clk_t)
  begin
    if rising_edge(clk_t) then
      if ftx_rst = '1' then
        ftx_i <= 0;
      elsif tx_ren = '1' and ftx_i < ftx_n then
        ftx_i <= ftx_i + 1;
      end if;
    end if;
  end process;

  mon : process(clk_t)
  begin
    if rising_edge(clk_t) then
      if mon_rst = '1' then
        rxn <= 0; perr_c <= 0; ibid_c <= 0; tren_c <= 0;
      else
        if rx_valid = '1' then
          if rxn < 8 then rxc(rxn) <= rx_data; end if;
          rxn <= rxn + 1;
        end if;
        if rx_perr    = '1' then perr_c <= perr_c + 1; end if;
        if t_ibi_done = '1' then ibid_c <= ibid_c + 1; end if;
        if tx_ren     = '1' then tren_c <= tren_c + 1; end if;
      end if;
    end if;
  end process;

  estimulo : process
    variable db  : slv8_arr(0 to 7);
    variable okv : boolean;

    procedure tick1 is
    begin
      wait until rising_edge(clk_c);
    end procedure;

    -- pulses held long enough to be seen by the other clock domain
    procedure tpulse(signal s : out std_logic) is
    begin
      s <= '1';
      wait until rising_edge(clk_t); wait until rising_edge(clk_t);
      s <= '0';
    end procedure;

    procedure icmd(s, p, r, rl, nb, dda, ddr, ia, ink : std_logic;
                   d : std_logic_vector(7 downto 0)) is
    begin
      cmd_start  <= s;  cmd_stop  <= p;  cmd_read   <= r;
      cmd_rlast  <= rl; cmd_nobyte <= nb;
      cmd_daa    <= dda; cmd_daadr <= ddr;
      cmd_ibiack <= ia; cmd_ibinak <= ink;
      cmd_wdata  <= d;
      cmd_valid  <= '1';
      tick1;
      cmd_valid  <= '0';
      cmd_start  <= '0'; cmd_stop <= '0'; cmd_read <= '0'; cmd_rlast <= '0';
      cmd_nobyte <= '0'; cmd_daa <= '0'; cmd_daadr <= '0';
      cmd_ibiack <= '0'; cmd_ibinak <= '0';
    end procedure;

    procedure wdone(msg : string) is
      variable t : integer := 0;
    begin
      loop
        tick1;
        exit when done = '1';
        t := t + 1;
        assert t < 400000 report "TIMEOUT waiting for done: " & msg
          severity failure;
      end loop;
    end procedure;

    procedure hdr(d : std_logic_vector(7 downto 0); sp : std_logic; msg : string) is
    begin
      icmd('1', sp, '0', '0', '0', '0', '0', '0', '0', d);
      wdone(msg);
    end procedure;
    procedure wrb(d : std_logic_vector(7 downto 0); sp : std_logic; msg : string) is
    begin
      icmd('0', sp, '0', '0', '0', '0', '0', '0', '0', d);
      wdone(msg);
    end procedure;
    procedure rdb(rl, sp : std_logic; msg : string) is
    begin
      icmd('0', sp, '1', rl, '0', '0', '0', '0', '0', x"00");
      wdone(msg);
    end procedure;
    procedure stopc(msg : string) is
    begin
      icmd('0', '1', '0', '0', '1', '0', '0', '0', '0', x"00");
      wdone(msg);
    end procedure;
    procedure daadr(d : std_logic_vector(7 downto 0); msg : string) is
    begin
      icmd('0', '0', '0', '0', '0', '0', '1', '0', '0', d);
      wdone(msg);
    end procedure;
    procedure daa_round(ok : out boolean; bytes : out slv8_arr(0 to 7);
                        msg : string) is
      variable n : integer := 0;
      variable t : integer := 0;
    begin
      icmd('0', '0', '0', '0', '0', '1', '0', '0', '0', x"00");
      loop
        tick1;
        if rvalid = '1' and n < 8 then
          bytes(n) := rdata;
          n := n + 1;
        end if;
        exit when done = '1';
        t := t + 1;
        assert t < 400000 report "TIMEOUT in ENTDAA round: " & msg
          severity failure;
      end loop;
      ok := (ack_in = '0');
    end procedure;
    procedure wibi(msg : string) is
      variable t : integer := 0;
    begin
      loop
        tick1;
        exit when ibi_req = '1';
        t := t + 1;
        assert t < 400000 report "TIMEOUT waiting for IBI: " & msg
          severity failure;
      end loop;
    end procedure;
    procedure settle is
    begin
      wait for 2 us;
    end procedure;
    procedure mon_clear is
    begin
      mon_rst <= '1';
      wait until rising_edge(clk_t); wait until rising_edge(clk_t);
      mon_rst <= '0';
      wait until rising_edge(clk_t);
    end procedure;
    procedure fifo_load(a, b, c, d : std_logic_vector(7 downto 0); n : natural) is
    begin
      ftx(0) <= a; ftx(1) <= b; ftx(2) <= c; ftx(3) <= d;
      ftx_n <= n;
      ftx_rst <= '1';
      wait until rising_edge(clk_t); wait until rising_edge(clk_t);
      ftx_rst <= '0';
      wait until rising_edge(clk_t);
    end procedure;

    procedure suite(tag : string) is
    begin
      -- A1 RSTDAA
      hdr(x"FC", '0', tag & " A1 7E/W");
      assert ack_in = '0' report "FAIL " & tag & " A1: 7E/W NACK" severity failure;
      wrb(x"06", '1', tag & " A1 RSTDAA+STOP");
      settle;
      assert t_da_valid = '0' report "FAIL " & tag & " A1: DA not cleared"
        severity failure;

      -- A2 SETDASA SA 0x52 -> DA 0x30
      hdr(x"FC", '0', tag & " A2 7E/W");
      wrb(x"87", '0', tag & " A2 CCC SETDASA");
      hdr(TGT_SA & '0', '0', tag & " A2 Sr SA/W");
      assert ack_in = '0' report "FAIL " & tag & " A2: SA/W NACK" severity failure;
      wrb(x"60", '1', tag & " A2 DA<<1 + STOP");
      settle;
      assert t_da_valid = '1' and t_da = "0110000"
        report "FAIL " & tag & " A2: SETDASA did not assign 0x30" severity failure;

      -- A3 RSTDAA + ENTDAA -> 0x31
      hdr(x"FC", '0', tag & " A3 7E/W");
      wrb(x"06", '0', tag & " A3 RSTDAA");
      hdr(x"FC", '0', tag & " A3 Sr 7E/W");
      wrb(x"07", '0', tag & " A3 ENTDAA");
      daa_round(okv, db, tag & " A3 round 1");
      assert okv report "FAIL " & tag & " A3: ENTDAA NACK" severity failure;
      for i in 0 to 7 loop
        assert db(i) = PAY(63 - 8*i downto 56 - 8*i)
          report "FAIL " & tag & " A3: ENTDAA payload byte " & integer'image(i)
          severity failure;
      end loop;
      daadr(x"62", tag & " A3 DA 0x31");
      assert ack_in = '0' report "FAIL " & tag & " A3: DA NACK" severity failure;
      daa_round(okv, db, tag & " A3 round 2");
      assert not okv report "FAIL " & tag & " A3: second round must NACK"
        severity failure;
      stopc(tag & " A3 STOP");
      settle;
      assert t_da_valid = '1' and t_da = "0110001"
        report "FAIL " & tag & " A3: DA 0x31 not registered" severity failure;

      -- A4 private write
      mon_clear;
      hdr(x"FC", '0', tag & " A4 7E/W");
      hdr(x"62", '0', tag & " A4 Sr DA/W");
      assert ack_in = '0' report "FAIL " & tag & " A4: DA/W NACK" severity failure;
      wrb(x"A5", '0', tag & " A4 d0");
      wrb(x"3C", '0', tag & " A4 d1");
      wrb(x"FF", '0', tag & " A4 d2");
      wrb(x"00", '1', tag & " A4 d3+STOP");
      settle;
      assert rxn = 4 and rxc(0) = x"A5" and rxc(1) = x"3C" and
             rxc(2) = x"FF" and rxc(3) = x"00" and perr_c = 0
        report "FAIL " & tag & " A4: private write corrupted (n=" &
               integer'image(rxn) & ", perr=" & integer'image(perr_c) & ")"
        severity failure;

      -- A5 private read, controller seize during T=1
      fifo_load(x"11", x"22", x"33", x"44", 4);
      mon_clear;
      hdr(x"FC", '0', tag & " A5 7E/W");
      hdr(x"63", '0', tag & " A5 Sr DA/R");
      assert ack_in = '0' report "FAIL " & tag & " A5: DA/R NACK" severity failure;
      rdb('0', '0', tag & " A5 b0");
      assert rdata = x"11" and t_bit = '1' report "FAIL " & tag & " A5 b0" severity failure;
      rdb('0', '0', tag & " A5 b1");
      assert rdata = x"22" and t_bit = '1' report "FAIL " & tag & " A5 b1" severity failure;
      rdb('1', '1', tag & " A5 b2 rlast+STOP");
      assert rdata = x"33" and t_bit = '1' report "FAIL " & tag & " A5 b2/seize" severity failure;
      settle;
      assert tren_c = 3 and t_in_frame = '0'
        report "FAIL " & tag & " A5: FIFO pops / frame state" severity failure;

      -- A6 private read ended by the target (T=0)
      fifo_load(x"55", x"66", x"00", x"00", 2);
      hdr(x"FC", '0', tag & " A6 7E/W");
      hdr(x"63", '0', tag & " A6 Sr DA/R");
      rdb('0', '0', tag & " A6 b0");
      assert rdata = x"55" and t_bit = '1' report "FAIL " & tag & " A6 b0" severity failure;
      rdb('0', '0', tag & " A6 b1");
      assert rdata = x"66" and t_bit = '0' report "FAIL " & tag & " A6 T=0" severity failure;
      stopc(tag & " A6 STOP");
      settle;

      -- A7 GETPID / GETBCR / GETDCR
      hdr(x"FC", '0', tag & " A7 7E/W");
      wrb(x"8D", '0', tag & " A7 GETPID");
      hdr(x"63", '0', tag & " A7 Sr DA/R");
      assert ack_in = '0' report "FAIL " & tag & " A7: GETPID NACK" severity failure;
      for i in 0 to 5 loop
        rdb('0', '0', tag & " A7 PID" & integer'image(i));
        assert rdata = TGT_PID(47 - 8*i downto 40 - 8*i)
          report "FAIL " & tag & " A7: PID byte " & integer'image(i) severity failure;
        if i < 5 then
          assert t_bit = '1' report "FAIL " & tag & " A7: PID T" severity failure;
        else
          assert t_bit = '0' report "FAIL " & tag & " A7: PID last T" severity failure;
        end if;
      end loop;
      hdr(x"FC", '0', tag & " A7 Sr 7E/W");
      wrb(x"8E", '0', tag & " A7 GETBCR");
      hdr(x"63", '0', tag & " A7 Sr DA/R");
      rdb('0', '0', tag & " A7 BCR");
      assert rdata = TGT_BCR and t_bit = '0' report "FAIL " & tag & " A7 BCR" severity failure;
      hdr(x"FC", '0', tag & " A7 Sr 7E/W");
      wrb(x"8F", '0', tag & " A7 GETDCR");
      hdr(x"63", '0', tag & " A7 Sr DA/R");
      rdb('0', '0', tag & " A7 DCR");
      assert rdata = TGT_DCR and t_bit = '0' report "FAIL " & tag & " A7 DCR" severity failure;
      stopc(tag & " A7 STOP");
      settle;

      -- A8 IBI with mandatory byte
      mon_clear;
      tpulse(t_ibi_go);
      wibi(tag & " A8");
      assert ibi_addr = x"63" report "FAIL " & tag & " A8: IBI address" severity failure;
      icmd('0', '0', '0', '0', '0', '0', '0', '1', '0', x"00");
      wdone(tag & " A8 ibiack");
      rdb('0', '0', tag & " A8 MDB");
      assert rdata = TGT_MDB and t_bit = '0' report "FAIL " & tag & " A8 MDB" severity failure;
      stopc(tag & " A8 STOP");
      settle;
      assert ibid_c = 1 and t_ibi_pend = '0'
        report "FAIL " & tag & " A8: ibi_done/pend" severity failure;

      -- A9 GETSTATUS
      hdr(x"FC", '0', tag & " A9 7E/W");
      wrb(x"90", '0', tag & " A9 GETSTATUS");
      hdr(x"63", '0', tag & " A9 Sr DA/R");
      rdb('0', '0', tag & " A9 st0");
      assert rdata = TGT_STS(15 downto 8) and t_bit = '1'
        report "FAIL " & tag & " A9 st0" severity failure;
      rdb('0', '0', tag & " A9 st1");
      assert rdata = TGT_STS(7 downto 0) and t_bit = '0'
        report "FAIL " & tag & " A9 st1" severity failure;
      stopc(tag & " A9 STOP");
      settle;

      assert fight_time = 0 ns
        report "FAIL " & tag & ": SDA push-pull contention " &
               time'image(fight_time) severity failure;
      assert not x_seen report "FAIL " & tag & ": X on the bus" severity failure;
    end procedure;

  begin
    rst <= '1';
    en  <= '0';
    wait for 300 ns;
    tick1;
    rst <= '0';
    en  <= '1';
    wait for 500 ns;

    for k in SWEEP'range loop
      div_pp <= std_logic_vector(to_unsigned(SWEEP(k).pp, 16));
      div_od <= std_logic_vector(to_unsigned(SWEEP(k).od, 16));
      wait for 500 ns;
      report "sweep: div_pp=" & integer'image(SWEEP(k).pp) &
             " div_od=" & integer'image(SWEEP(k).od) &
             " (target clock " & real'image(TT_NOM) & " ns +/-" &
             real'image(DRIFT_PCT) & "%)";
      suite("pp" & integer'image(SWEEP(k).pp) & "/od" & integer'image(SWEEP(k).od));
    end loop;

    report "tb_i3c_async: ALL TESTS PASSED (no contention, all frames OK)";
    sim_done <= true;
    wait for 100 ns;
    finish;
  end process estimulo;

  vigilante : process
  begin
    wait for 50 ms;
    assert false report "GLOBAL TIMEOUT" severity failure;
  end process;

end architecture sim;
