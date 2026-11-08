-- tb_m1553_1d.vhd
-- Layer 1d (audit 2026-11): dual-redundant bus and message-validation
-- behaviour of the BC/RT cores. One BC and two RTs (addr 5 and 9) on TWO
-- buses A/B, each resolved by tx_en, plus an independent bit-bang
-- transmitter per bus (procedural Manchester encoder with its own parity:
-- zero code shared with the RTL) to inject commands, extra words, bad
-- statuses and garbage. A collision checker per bus fails on two drivers.
--
--   D1  BC on bus B -> RT0: RT0 answers on B only
--   D2  BC on bus A, RT1 -> BC: RT1 answers on A only
--   D3  superseding command: RT0 transmitting 32 words on A (commanded by
--       the TB); the BC sends Transmit Status on B -> RT0 cuts A at once and
--       answers on B
--   D4  word count high: extra data word during the response gap -> no
--       response, ME set
--   D5  illegal broadcast (broadcast + transmit) superposed during S_RXD:
--       back to idle, no ev_cmd, later data word not stored
--   D6  RT TX underflow: partial (status + 1 word, then silence) and empty
--       (no status at all); ME, ev_uflow
--   D7  BC TX underflow: partial (cmd + 1 word) and empty (nothing sent)
--   D8  status flags Busy/SSF/TF in the status word; Busy suppresses data
--   D9  status word with parity error -> BC SERR (not timeout)
--   D10 continuous garbage holding the receiver busy -> BC still times out
-- Failure messages without accents (GHDL asserts).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_m1553_1d is
end entity tb_m1553_1d;

architecture sim of tb_m1553_1d is

  constant T_CLK  : time := 10 ns;
  constant T_HALF : time := 500 ns;

  constant AR0 : std_logic_vector(4 downto 0) := "00101";  -- 5
  constant AR1 : std_logic_vector(4 downto 0) := "01001";  -- 9

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal en  : std_logic := '0';

  -- BC
  signal bc_go, bc_rtrt, bc_ftr, bc_fbus : std_logic := '0';
  signal bc_frt, bc_fsa, bc_fwc : std_logic_vector(4 downto 0) := (others => '0');
  signal bc_busy, bc_done, bc_ok, bc_tout, bc_serr, bc_me, bc_uf, bc_mbus, bc_fs : std_logic;
  signal bc_s1, bc_s2 : std_logic_vector(15 downto 0);
  signal bc_txrd, bc_rxwe, bc_tx, bc_txen_a, bc_txen_b : std_logic;
  signal bc_rxdat : std_logic_vector(15 downto 0);

  -- RTs
  signal r0_busy, r0_ssf, r0_tf : std_logic := '0';
  signal r0_txrd, r0_rxwe, r0_evc, r0_evok, r0_everr, r0_uf : std_logic;
  signal r0_rxdat : std_logic_vector(15 downto 0);
  signal r0_rxsa : std_logic_vector(4 downto 0);
  signal r0_rxbc, r0_me, r0_bcr, r0_bus, r0_fs : std_logic;
  signal r0_tx, r0_txen_a, r0_txen_b : std_logic;

  signal r1_txrd, r1_rxwe, r1_evc, r1_evok, r1_everr, r1_uf : std_logic;
  signal r1_rxdat : std_logic_vector(15 downto 0);
  signal r1_rxsa : std_logic_vector(4 downto 0);
  signal r1_rxbc, r1_me, r1_bcr, r1_bus, r1_fs : std_logic;
  signal r1_tx, r1_txen_a, r1_txen_b : std_logic;

  -- TB bit-bang drivers
  signal tba, tbb, tba_en, tbb_en : std_logic := '0';

  -- buses
  signal bus_a, bus_b : std_logic;

  -- TX sources (FWFT models with an empty flag)
  type t_words is array (0 to 63) of std_logic_vector(15 downto 0);
  signal bc_src, r0_src, r1_src : t_words := (others => (others => '0'));
  signal bc_n, r0_n, r1_n : integer := 0;     -- words loaded
  signal bc_i, r0_i, r1_i : integer := 0;     -- words consumed
  signal bc_wd, r0_wd, r1_wd : std_logic_vector(15 downto 0);
  signal bc_emp, r0_emp, r1_emp : std_logic;

  -- monitors
  signal n_r0we, n_r1we, n_bcwe, n_r0cmd, n_r1cmd : integer := 0;
  signal n_r0uf, n_r1uf, n_r0err, n_done : integer := 0;
  signal n_r0a, n_r0b, n_r1a, n_r1b, n_bca, n_bcb : integer := 0; -- txen rises
  signal last_r0 : std_logic_vector(15 downto 0) := (others => '0');
  signal last_r0sa : std_logic_vector(4 downto 0) := (others => '0');
  signal last_r0bc : std_logic := '0';

  -- time stamps for D3
  signal t_r0a_fall, t_bcb_fall : time := 0 ns;

begin

  clk <= not clk after T_CLK / 2;

  bc_wd  <= bc_src(bc_i mod 64);
  r0_wd  <= r0_src(r0_i mod 64);
  r1_wd  <= r1_src(r1_i mod 64);
  bc_emp <= '1' when bc_i >= bc_n else '0';
  r0_emp <= '1' when r0_i >= r0_n else '0';
  r1_emp <= '1' when r1_i >= r1_n else '0';

  u_bc : entity work.m1553_bc_core
    port map (
      clk => clk, rst => rst, en => en,
      go => bc_go, rtrt => bc_rtrt,
      f_rt => bc_frt, f_tr => bc_ftr, f_sa => bc_fsa, f_wc => bc_fwc,
      f2_rt => "00000", f2_sa => "00000", f_bus => bc_fbus,
      busy => bc_busy, done => bc_done,
      r_ok => bc_ok, r_tout => bc_tout, r_serr => bc_serr, r_me => bc_me,
      r_uflow => bc_uf, m_bus_o => bc_mbus, fs_fault => bc_fs,
      stat1 => bc_s1, stat2 => bc_s2,
      tx_rd => bc_txrd, tx_wdat => bc_wd, tx_empty => bc_emp,
      rx_we => bc_rxwe, rx_wdat => bc_rxdat,
      bus_rx_a => bus_a, bus_rx_b => bus_b, bus_tx => bc_tx,
      bus_txen_a => bc_txen_a, bus_txen_b => bc_txen_b);

  u_rt0 : entity work.m1553_rt_core
    port map (
      clk => clk, rst => rst, en => en, rt_addr => AR0,
      st_busy => r0_busy, st_ssf => r0_ssf, st_tf => r0_tf,
      tx_rd => r0_txrd, tx_wdat => r0_wd, tx_empty => r0_emp,
      rx_we => r0_rxwe, rx_wdat => r0_rxdat, rx_sa => r0_rxsa, rx_bcast => r0_rxbc,
      ev_cmd => r0_evc, ev_ok => r0_evok, ev_err => r0_everr, ev_uflow => r0_uf,
      dbg_me => r0_me, dbg_bcr => r0_bcr, cur_bus => r0_bus, fs_fault => r0_fs,
      bus_rx_a => bus_a, bus_rx_b => bus_b, bus_tx => r0_tx,
      bus_txen_a => r0_txen_a, bus_txen_b => r0_txen_b);

  u_rt1 : entity work.m1553_rt_core
    port map (
      clk => clk, rst => rst, en => en, rt_addr => AR1,
      tx_rd => r1_txrd, tx_wdat => r1_wd, tx_empty => r1_emp,
      rx_we => r1_rxwe, rx_wdat => r1_rxdat, rx_sa => r1_rxsa, rx_bcast => r1_rxbc,
      ev_cmd => r1_evc, ev_ok => r1_evok, ev_err => r1_everr, ev_uflow => r1_uf,
      dbg_me => r1_me, dbg_bcr => r1_bcr, cur_bus => r1_bus, fs_fault => r1_fs,
      bus_rx_a => bus_a, bus_rx_b => bus_b, bus_tx => r1_tx,
      bus_txen_a => r1_txen_a, bus_txen_b => r1_txen_b);

  -- bus resolution by tx_en (idle low)
  bus_a <= bc_tx when bc_txen_a = '1' else r0_tx when r0_txen_a = '1' else
           r1_tx when r1_txen_a = '1' else tba when tba_en = '1' else '0';
  bus_b <= bc_tx when bc_txen_b = '1' else r0_tx when r0_txen_b = '1' else
           r1_tx when r1_txen_b = '1' else tbb when tbb_en = '1' else '0';

  -- collision checker + monitors
  mon : process(clk)
    function n1(a, b, c, d : std_logic) return integer is
      variable n : integer := 0;
    begin
      if a = '1' then n := n + 1; end if;
      if b = '1' then n := n + 1; end if;
      if c = '1' then n := n + 1; end if;
      if d = '1' then n := n + 1; end if;
      return n;
    end function;
    variable p_r0a, p_r0b, p_r1a, p_r1b, p_bca, p_bcb : std_logic := '0';
  begin
    if rising_edge(clk) then
      assert n1(bc_txen_a, r0_txen_a, r1_txen_a, tba_en) <= 1
        report "FALLO: colision en el bus A" severity failure;
      assert n1(bc_txen_b, r0_txen_b, r1_txen_b, tbb_en) <= 1
        report "FALLO: colision en el bus B" severity failure;
      if bc_txrd = '1' then bc_i <= bc_i + 1; end if;
      if r0_txrd = '1' then r0_i <= r0_i + 1; end if;
      if r1_txrd = '1' then r1_i <= r1_i + 1; end if;
      if r0_rxwe = '1' then
        n_r0we <= n_r0we + 1; last_r0 <= r0_rxdat;
        last_r0sa <= r0_rxsa; last_r0bc <= r0_rxbc;
      end if;
      if r1_rxwe = '1' then n_r1we <= n_r1we + 1; end if;
      if bc_rxwe = '1' then n_bcwe <= n_bcwe + 1; end if;
      if r0_evc = '1' then n_r0cmd <= n_r0cmd + 1; end if;
      if r1_evc = '1' then n_r1cmd <= n_r1cmd + 1; end if;
      if r0_uf = '1' then n_r0uf <= n_r0uf + 1; end if;
      if r1_uf = '1' then n_r1uf <= n_r1uf + 1; end if;
      if r0_everr = '1' then n_r0err <= n_r0err + 1; end if;
      if bc_done = '1' then n_done <= n_done + 1; end if;
      if r0_txen_a = '1' and p_r0a = '0' then n_r0a <= n_r0a + 1; end if;
      if r0_txen_b = '1' and p_r0b = '0' then n_r0b <= n_r0b + 1; end if;
      if r1_txen_a = '1' and p_r1a = '0' then n_r1a <= n_r1a + 1; end if;
      if r1_txen_b = '1' and p_r1b = '0' then n_r1b <= n_r1b + 1; end if;
      if bc_txen_a = '1' and p_bca = '0' then n_bca <= n_bca + 1; end if;
      if bc_txen_b = '1' and p_bcb = '0' then n_bcb <= n_bcb + 1; end if;
      if r0_txen_a = '0' and p_r0a = '1' then t_r0a_fall <= now; end if;
      if bc_txen_b = '0' and p_bcb = '1' then t_bcb_fall <= now; end if;
      p_r0a := r0_txen_a; p_r0b := r0_txen_b; p_r1a := r1_txen_a;
      p_r1b := r1_txen_b; p_bca := bc_txen_a; p_bcb := bc_txen_b;
    end if;
  end process;

  stim : process
    variable e_done : integer := 0;

    -- independent Manchester encoder on bus A ('0') or B ('1')
    procedure bb_word(b : std_logic; wt : std_logic;
                      d : std_logic_vector(15 downto 0);
                      bad_par : boolean := false) is
      variable p : std_logic := '1';
      variable v : std_logic_vector(16 downto 0);
      procedure drv(l : std_logic) is
      begin
        if b = '0' then tba <= l; else tbb <= l; end if;
      end procedure;
    begin
      for i in 0 to 15 loop p := p xor d(i); end loop;
      if bad_par then p := not p; end if;
      v := d & p;
      if b = '0' then tba_en <= '1'; else tbb_en <= '1'; end if;
      drv(wt);     wait for 3 * T_HALF;
      drv(not wt); wait for 3 * T_HALF;
      for k in 0 to 16 loop
        drv(v(16 - k));     wait for T_HALF;
        drv(not v(16 - k)); wait for T_HALF;
      end loop;
      drv('0');
      if b = '0' then tba_en <= '0'; else tbb_en <= '0'; end if;
    end procedure;

    function cmdw(rt : std_logic_vector(4 downto 0); tr : std_logic;
                  sa, wc : std_logic_vector(4 downto 0))
      return std_logic_vector is
    begin
      return rt & tr & sa & wc;
    end function;

    procedure go(b, tr : std_logic; rt, sa, wc : std_logic_vector(4 downto 0)) is
    begin
      wait until rising_edge(clk);
      bc_fbus <= b; bc_ftr <= tr; bc_frt <= rt; bc_fsa <= sa; bc_fwc <= wc;
      bc_go <= '1';
      wait until rising_edge(clk);
      bc_go <= '0';
    end procedure;

    procedure wdone(msg : string) is
    begin
      e_done := e_done + 1;
      if n_done /= e_done then
        wait until n_done = e_done for 2 ms;
      end if;
      assert n_done = e_done
        report "FALLO " & msg & ": el BC no termino" severity failure;
      wait for 1 ns;
    end procedure;

    variable c0, c1, c2, c3 : integer;
    variable t0 : time;
  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    en  <= '1';
    wait for 10 us;

    ------------------------------------------------------------ D1
    report "D1: BC en bus B -> RT0";
    bc_src(bc_i mod 64) <= x"D100"; bc_src((bc_i + 1) mod 64) <= x"D101";
    bc_n <= bc_i + 2;
    c0 := n_r0we; c1 := n_r0a;
    go('1', '0', AR0, "00011", "00010");
    wdone("D1");
    assert bc_ok = '1' and bc_s1 = AR0 & "00000000000"
      report "FALLO D1: resultado/status del BC" severity failure;
    assert n_r0we = c0 + 2 and last_r0 = x"D101"
      report "FALLO D1: datos no recibidos por RT0" severity failure;
    assert n_r0b = 1 and n_r0a = c1 and n_bca = 0
      report "FALLO D1: RT0 no respondio solo por el bus B" severity failure;
    assert r0_bus = '1' and bc_mbus = '1'
      report "FALLO D1: bus actual incorrecto" severity failure;
    wait for 20 us;

    ------------------------------------------------------------ D2
    report "D2: BC en bus A, RT1 -> BC";
    r1_src(r1_i mod 64) <= x"E100"; r1_src((r1_i + 1) mod 64) <= x"E101";
    r1_n <= r1_i + 2;
    c0 := n_bcwe;
    go('0', '1', AR1, "00100", "00010");
    wdone("D2");
    assert bc_ok = '1' and n_bcwe = c0 + 2
      report "FALLO D2: RT->BC por el bus A" severity failure;
    assert n_r1a = 1 and n_r1b = 0
      report "FALLO D2: RT1 no respondio solo por el bus A" severity failure;
    wait for 20 us;

    ------------------------------------------------------------ D3
    report "D3: comando que reemplaza en el otro bus";
    for i in 0 to 31 loop
      r0_src((r0_i + i) mod 64) <= std_logic_vector(to_unsigned(16#3000# + i, 16));
    end loop;
    r0_n <= r0_i + 32;
    c1 := n_r0a; c2 := n_r0b;
    -- TB commands RT0 to transmit 32 words on bus A (660 us response)
    bb_word('0', '1', cmdw(AR0, '1', "00001", "00000"));
    wait until r0_txen_a = '1' for 20 us;
    assert r0_txen_a = '1'
      report "FALLO D3: RT0 no empezo a responder en A" severity failure;
    t0 := now;
    wait for 100 us;
    -- BC on bus B: Transmit Status Word (mode code 00010) to RT0
    go('1', '1', AR0, "00000", "00010");
    wdone("D3");
    assert t_r0a_fall > t0 and t_r0a_fall - t_bcb_fall < 200 ns
           and t_r0a_fall >= t_bcb_fall - 1 us
      report "FALLO D3: RT0 no corto la respuesta en A al llegar el comando en B"
      severity failure;
    assert t_r0a_fall - t0 < 300 us
      report "FALLO D3: la respuesta en A no se corto" severity failure;
    assert bc_ok = '1' and bc_s1(15 downto 11) = AR0 and n_r0b = c2 + 1
      report "FALLO D3: RT0 no respondio al comando nuevo por el bus B"
      severity failure;
    assert r0_txen_a = '0'
      report "FALLO D3: RT0 sigue emitiendo en A" severity failure;
    wait for 1 ns;
    r0_n <= r0_i;                             -- discard the unsent words
    wait for 30 us;

    ------------------------------------------------------------ D4
    report "D4: palabra de datos de mas (word count high)";
    c1 := n_r0a; c2 := n_r0b;
    bb_word('0', '1', cmdw(AR0, '0', "00010", "00001"));
    bb_word('0', '0', x"4401");
    bb_word('0', '0', x"4402");               -- extra word, contiguous
    wait for 60 us;
    assert n_r0a = c1 and n_r0b = c2
      report "FALLO D4: RT0 respondio a un mensaje con palabras de mas"
      severity failure;
    assert r0_me = '1'
      report "FALLO D4: ME no activado" severity failure;
    wait for 10 us;

    ------------------------------------------------------------ D5
    report "D5: broadcast ilegal superpuesto durante la recepcion";
    c0 := n_r0we; c1 := n_r0cmd; c2 := n_r0a;
    bb_word('0', '1', cmdw(AR0, '0', "00011", "00010"));   -- rx wc=2 sa=3
    bb_word('0', '0', x"5501");
    bb_word('0', '1', cmdw("11111", '1', "00111", "00010")); -- bcast + transmit
    bb_word('0', '0', x"5502");
    wait for 60 us;
    assert n_r0we = c0 + 1 and last_r0 = x"5501" and last_r0sa = "00011"
           and last_r0bc = '0'
      report "FALLO D5: el broadcast ilegal altero el mensaje en curso"
      severity failure;
    assert n_r0cmd = c1 + 1
      report "FALLO D5: ev_cmd por un comando no atendido" severity failure;
    assert n_r0a = c2
      report "FALLO D5: RT0 respondio" severity failure;
    wait for 10 us;

    ------------------------------------------------------------ D6
    report "D6: underflow del FIFO TX del RT";
    r1_src(r1_i mod 64) <= x"6100"; r1_n <= r1_i + 1;
    c0 := n_bcwe; c1 := n_r1uf;
    go('0', '1', AR1, "00101", "00011");      -- wants 3, has 1
    wdone("D6a");
    assert bc_ok = '0' and n_bcwe = c0 + 1
      report "FALLO D6a: el BC no detecto el mensaje incompleto" severity failure;
    assert n_r1uf = c1 + 1 and r1_me = '1'
      report "FALLO D6a: underflow/ME del RT1" severity failure;
    wait for 20 us;
    r1_n <= r1_i;
    c2 := n_r1a;
    go('0', '1', AR1, "00101", "00010");      -- wants 2, has 0
    wdone("D6b");
    assert bc_tout = '1' and n_r1a = c2
      report "FALLO D6b: RT1 transmitio sin datos (debia callar)" severity failure;
    assert n_r1uf = c1 + 2
      report "FALLO D6b: underflow no senalado" severity failure;
    wait for 20 us;

    ------------------------------------------------------------ D7
    report "D7: underflow del FIFO TX del BC";
    bc_src(bc_i mod 64) <= x"7100"; bc_n <= bc_i + 1;
    c3 := bc_i;
    c0 := n_r0we;
    go('0', '0', AR0, "00110", "00011");      -- needs 3 words, has 1
    wdone("D7a");
    assert bc_uf = '1' and bc_ok = '0'
      report "FALLO D7a: underflow del BC no senalado" severity failure;
    assert bc_i = c3 + 1
      report "FALLO D7a: el BC no emitio la palabra disponible" severity failure;
    wait for 60 us;
    assert r0_me = '1'
      report "FALLO D7a: RT0 no invalido el mensaje corto" severity failure;
    bc_n <= bc_i;
    c1 := n_bca;
    go('0', '0', AR0, "00110", "00001");      -- needs 1 word, has 0
    wdone("D7b");
    assert bc_uf = '1' and n_bca = c1
      report "FALLO D7b: el BC transmitio sin datos" severity failure;
    wait for 20 us;

    ------------------------------------------------------------ D8
    report "D8: bits Busy/SSF/TF del status";
    r0_busy <= '1'; r0_ssf <= '1'; r0_tf <= '1';
    r0_src(r0_i mod 64) <= x"8800"; r0_src((r0_i + 1) mod 64) <= x"8801";
    r0_n <= r0_i + 2;
    c3 := r0_i;
    go('0', '1', AR0, "00111", "00010");      -- transmit while Busy
    wdone("D8a");
    assert bc_s1 = AR0 & "00000001101"
      report "FALLO D8a: bits Busy/SSF/TF del status incorrectos" severity failure;
    assert r0_i = c3
      report "FALLO D8a: RT0 envio datos estando Busy" severity failure;
    wait for 20 us;
    bc_src(bc_i mod 64) <= x"8A00"; bc_n <= bc_i + 1;
    c0 := n_r0we;
    go('0', '0', AR0, "01000", "00001");      -- receive while Busy
    wdone("D8b");
    assert bc_ok = '1' and bc_s1 = AR0 & "00000001101"
      report "FALLO D8b: status con Busy en recepcion" severity failure;
    assert n_r0we = c0
      report "FALLO D8b: RT0 almaceno datos estando Busy" severity failure;
    r0_busy <= '0'; r0_ssf <= '0'; r0_tf <= '0';
    r0_n <= r0_i;
    wait for 20 us;

    ------------------------------------------------------------ D9
    report "D9: status con paridad rota -> SERR";
    go('0', '1', "01100", "00010", "00001");  -- RT 12 does not exist
    wait until bc_txen_a = '1';
    wait until bc_txen_a = '0';
    wait for 5 us;
    bb_word('0', '1', "01100" & "00000000000", bad_par => true);
    wdone("D9");
    assert bc_serr = '1' and bc_tout = '0'
      report "FALLO D9: error de palabra en el status no tratado como SERR"
      severity failure;
    wait for 20 us;

    ------------------------------------------------------------ D10
    report "D10: basura continua no bloquea el timeout";
    go('0', '1', "01100", "00010", "00001");
    wait until bc_txen_a = '1';
    wait until bc_txen_a = '0';
    t0 := now;
    -- 4 us half-period square wave: every edge starts a (silent) tentative
    -- sync, so the receiver is busy most of the time and reports no error
    tba_en <= '1';
    for i in 0 to 30 loop
      tba <= '1'; wait for 4 us;
      tba <= '0'; wait for 4 us;
      exit when n_done = e_done + 1;
    end loop;
    tba_en <= '0';
    wdone("D10");
    assert bc_tout = '1' and bc_serr = '0'
      report "FALLO D10: resultado incorrecto con basura en el bus"
      severity failure;
    assert now - t0 < 50 us
      report "FALLO D10: timeout bloqueado por la basura" severity failure;

    report "M1553 CAPA 1D PASS";
    finish;
  end process;

  wd : process
  begin
    wait for 5 ms;
    assert false report "FALLO: timeout global de la capa 1d" severity failure;
  end process;

end architecture sim;
