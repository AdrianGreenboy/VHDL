-- tb_m1553_1c.vhd
-- Capa 1c: RTL contra RTL. Un BC y DOS RTs (addr 5 y 9) sobre el bus interno
-- resuelto por tx_en (un solo transmisor; colision de tx_en = FALLO del
-- vigilante). Incluye:
--   FASE 0 anti-modo-comun: RT solo -> jamas transmite; BC solo -> timeout.
--   Vigilante de cable INDEPENDIENTE: sin colisiones, transiciones en rejilla
--   de 500 ns por rafaga, duracion de rafaga multiplo de palabra, decodifica
--   cada palabra por muestreo absoluto (sync valido, Manchester, paridad
--   impar) y exige huecos de bus >= 2 us entre rafagas (equivale a >= 4 us
--   mid-parity -> mid-sync).
--   Escalera de formatos: BC->RT, RT->BC, RT->RT, mode codes (TxStatus,
--   Synchronize sin/con dato, no soportado -> ME), broadcast (BCR en ambos
--   RTs, sin respuesta), ciclo de vida de ME y BCR, timeout con RT ausente,
--   y hueco intermensaje impuesto por el BC con gos consecutivos.
-- Mensajes de FALLO sin tildes.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_m1553_1c is
end entity tb_m1553_1c;

architecture sim of tb_m1553_1c is

  constant T_CLK  : time := 10 ns;
  constant T_HALF : time := 500 ns;
  constant T_WORD : time := 20 us;

  constant AR0 : std_logic_vector(4 downto 0) := "00101";  -- RT0 = 5
  constant AR1 : std_logic_vector(4 downto 0) := "01001";  -- RT1 = 9

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal bc_en, rt0_en, rt1_en : std_logic := '0';

  -- BC
  signal bc_go, bc_rtrt : std_logic := '0';
  signal bc_frt, bc_fsa, bc_fwc, bc_f2rt, bc_f2sa :
         std_logic_vector(4 downto 0) := (others => '0');
  signal bc_ftr : std_logic := '0';
  signal bc_busy, bc_done, bc_ok, bc_tout, bc_serr, bc_me : std_logic;
  signal bc_stat1, bc_stat2 : std_logic_vector(15 downto 0);
  signal bc_txrd, bc_rxwe : std_logic;
  signal bc_txdat, bc_rxdat : std_logic_vector(15 downto 0);
  signal bc_tx, bc_txen : std_logic;

  -- RTs
  signal rt0_txrd, rt0_rxwe, rt0_evc, rt0_evok, rt0_everr : std_logic;
  signal rt0_txdat, rt0_rxdat : std_logic_vector(15 downto 0);
  signal rt0_rxsa : std_logic_vector(4 downto 0);
  signal rt0_rxbc, rt0_me, rt0_bcr : std_logic;
  signal rt0_tx, rt0_txen : std_logic;

  signal rt1_txrd, rt1_rxwe, rt1_evc, rt1_evok, rt1_everr : std_logic;
  signal rt1_txdat, rt1_rxdat : std_logic_vector(15 downto 0);
  signal rt1_rxsa : std_logic_vector(4 downto 0);
  signal rt1_rxbc, rt1_me, rt1_bcr : std_logic;
  signal rt1_tx, rt1_txen : std_logic;

  -- bus resuelto
  signal bus_v, busany : std_logic;

  -- vigilante
  signal n_bursts : integer := 0;

  -- monitores de flujo
  signal rt0_n, rt1_n, bc_n : integer := 0;

  type t_words is array (natural range <>) of std_logic_vector(15 downto 0);

  -- datos que emite el BC (en orden de consumo)
  constant BC_TXW : t_words(0 to 10) := (
    x"B100", x"B101", x"B102", x"B103",   -- P1  BC->RT0 wc=4
    x"D001",                              -- P6  Sync con dato a RT0
    x"B104", x"B105",                     -- P7  broadcast wc=2
    x"B106",                              -- P10 BC->RT0 wc=1
    x"B107", x"B108",                     -- P16 BC->RT12 wc=2 (nadie)
    x"0000");                             -- centinela

  -- datos que emite RT1 (en orden de consumo)
  constant RT1_TXW : t_words(0 to 5) := (
    x"E100", x"E101", x"E102",            -- P2  RT->BC wc=3
    x"E103", x"E104",                     -- P3  RT->RT wc=2
    x"0000");                             -- centinela

  constant RT0_TXW : t_words(0 to 0) := (others => x"0000");

  -- flujos esperados
  constant EXP_RT0 : t_words(0 to 9) := (
    x"B100", x"B101", x"B102", x"B103",   -- P1
    x"E103", x"E104",                     -- P3 (RT->RT, lado receptor)
    x"D001",                              -- P6
    x"B104", x"B105",                     -- P7 broadcast
    x"B106");                             -- P10
  constant EXP_RT1 : t_words(0 to 1) := (
    x"B104", x"B105");                    -- P7 broadcast
  constant EXP_BC : t_words(0 to 4) := (
    x"E100", x"E101", x"E102",            -- P2
    x"E103", x"E104");                    -- P3 (monitorizado por el BC)

  signal bc_ti, rt0_ti, rt1_ti : integer := 0;

begin

  clk <= not clk after T_CLK/2;

  ------------------------------------------------------------------
  -- DUTs
  ------------------------------------------------------------------
  u_bc : entity work.m1553_bc_core
    port map (
      clk => clk, rst => rst, en => bc_en,
      go => bc_go, rtrt => bc_rtrt,
      f_rt => bc_frt, f_tr => bc_ftr, f_sa => bc_fsa, f_wc => bc_fwc,
      f2_rt => bc_f2rt, f2_sa => bc_f2sa,
      busy => bc_busy, done => bc_done,
      r_ok => bc_ok, r_tout => bc_tout, r_serr => bc_serr, r_me => bc_me,
      stat1 => bc_stat1, stat2 => bc_stat2,
      tx_rd => bc_txrd, tx_wdat => bc_txdat,
      rx_we => bc_rxwe, rx_wdat => bc_rxdat,
      bus_rx => bus_v, bus_tx => bc_tx, bus_txen => bc_txen);

  u_rt0 : entity work.m1553_rt_core
    port map (
      clk => clk, rst => rst, en => rt0_en, rt_addr => AR0,
      tx_rd => rt0_txrd, tx_wdat => rt0_txdat,
      rx_we => rt0_rxwe, rx_wdat => rt0_rxdat,
      rx_sa => rt0_rxsa, rx_bcast => rt0_rxbc,
      ev_cmd => rt0_evc, ev_ok => rt0_evok, ev_err => rt0_everr,
      dbg_me => rt0_me, dbg_bcr => rt0_bcr,
      bus_rx => bus_v, bus_tx => rt0_tx, bus_txen => rt0_txen);

  u_rt1 : entity work.m1553_rt_core
    port map (
      clk => clk, rst => rst, en => rt1_en, rt_addr => AR1,
      tx_rd => rt1_txrd, tx_wdat => rt1_txdat,
      rx_we => rt1_rxwe, rx_wdat => rt1_rxdat,
      rx_sa => rt1_rxsa, rx_bcast => rt1_rxbc,
      ev_cmd => rt1_evc, ev_ok => rt1_evok, ev_err => rt1_everr,
      dbg_me => rt1_me, dbg_bcr => rt1_bcr,
      bus_rx => bus_v, bus_tx => rt1_tx, bus_txen => rt1_txen);

  ------------------------------------------------------------------
  -- bus resuelto por tx_en (un solo transmisor a la vez)
  ------------------------------------------------------------------
  bus_v <= bc_tx  when bc_txen  = '1' else
           rt0_tx when rt0_txen = '1' else
           rt1_tx when rt1_txen = '1' else
           '0';
  busany <= bc_txen or rt0_txen or rt1_txen;

  ------------------------------------------------------------------
  -- fuentes de datos FWFT (combinacionales, avanzan con tx_rd)
  ------------------------------------------------------------------
  bc_txdat  <= BC_TXW(bc_ti);
  rt0_txdat <= RT0_TXW(rt0_ti);
  rt1_txdat <= RT1_TXW(rt1_ti);

  srcs : process(clk)
  begin
    if rising_edge(clk) then
      if bc_txrd = '1' and bc_ti < BC_TXW'high then
        bc_ti <= bc_ti + 1;
      end if;
      if rt0_txrd = '1' and rt0_ti < RT0_TXW'high then
        rt0_ti <= rt0_ti + 1;
      end if;
      if rt1_txrd = '1' and rt1_ti < RT1_TXW'high then
        rt1_ti <= rt1_ti + 1;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------
  -- monitores de flujo contra tablas esperadas
  ------------------------------------------------------------------
  mon_rt0 : process(clk)
  begin
    if rising_edge(clk) then
      if rt0_rxwe = '1' then
        assert rt0_n <= EXP_RT0'high
          report "FALLO: RT0 recibio palabra de mas" severity failure;
        assert rt0_rxdat = EXP_RT0(rt0_n)
          report "FALLO: dato inesperado en RT0, indice "
                 & integer'image(rt0_n) severity failure;
        rt0_n <= rt0_n + 1;
      end if;
    end if;
  end process;

  mon_rt1 : process(clk)
  begin
    if rising_edge(clk) then
      if rt1_rxwe = '1' then
        assert rt1_n <= EXP_RT1'high
          report "FALLO: RT1 recibio palabra de mas" severity failure;
        assert rt1_rxdat = EXP_RT1(rt1_n)
          report "FALLO: dato inesperado en RT1, indice "
                 & integer'image(rt1_n) severity failure;
        rt1_n <= rt1_n + 1;
      end if;
    end if;
  end process;

  mon_bc : process(clk)
  begin
    if rising_edge(clk) then
      if bc_rxwe = '1' then
        assert bc_n <= EXP_BC'high
          report "FALLO: BC recibio palabra de mas" severity failure;
        assert bc_rxdat = EXP_BC(bc_n)
          report "FALLO: dato inesperado en BC, indice "
                 & integer'image(bc_n) severity failure;
        bc_n <= bc_n + 1;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------
  -- vigilante de cable independiente
  ------------------------------------------------------------------
  -- colision: jamas dos tx_en a la vez
  wd_col : process(clk)
  begin
    if rising_edge(clk) then
      assert (bc_txen and rt0_txen) = '0' and
             (bc_txen and rt1_txen) = '0' and
             (rt0_txen and rt1_txen) = '0'
        report "FALLO: colision de tx_en en el bus" severity failure;
    end if;
  end process;

  -- rejilla de 500 ns y duracion de rafaga multiplo de palabra
  wd_grid : process
    variable base : time;
  begin
    wait until busany = '1';
    base := now;
    loop
      wait on bus_v, busany;
      if busany = '0' then
        assert ((now - base) mod T_WORD) = 0 fs and (now - base) > 0 fs
          report "FALLO: rafaga no es multiplo de palabra" severity failure;
        exit;
      else
        assert ((now - base) mod T_HALF) = 0 fs
          report "FALLO: transicion Manchester fuera de rejilla"
          severity failure;
      end if;
    end loop;
  end process;

  -- bus en reposo a '0'
  wd_idle : process(bus_v, busany)
  begin
    if busany = '0' then
      assert bus_v = '0'
        report "FALLO: bus activo sin transmisor" severity failure;
    end if;
  end process;

  -- decodificador independiente por muestreo absoluto: cada palabra de cada
  -- rafaga debe tener sync valido, Manchester valido y paridad impar
  wd_words : process
    procedure wait_abs(t : time) is
    begin
      if t > now then
        wait for t - now;
      end if;
    end procedure;
    variable base : time;
    variable k    : integer;
    variable smp  : std_logic_vector(0 to 39);
    variable acc  : std_logic;
  begin
    wait until busany = '1';
    base := now;
    n_bursts <= n_bursts + 1;
    k := 0;
    loop
      for h in 0 to 39 loop
        wait_abs(base + k*T_WORD + h*T_HALF + T_HALF/2);
        smp(h) := bus_v;
      end loop;
      assert smp(0 to 5) = "111000" or smp(0 to 5) = "000111"
        report "FALLO vigilante: sync invalido en el bus" severity failure;
      acc := '0';
      for b in 0 to 16 loop
        assert smp(6 + 2*b) /= smp(7 + 2*b)
          report "FALLO vigilante: celda sin transicion en el bus"
          severity failure;
        acc := acc xor smp(6 + 2*b);
      end loop;
      assert acc = '1'
        report "FALLO vigilante: paridad no impar en el bus" severity failure;
      wait_abs(base + (k+1)*T_WORD + 100 ns);
      exit when busany = '0';
      k := k + 1;
    end loop;
  end process;

  -- huecos entre rafagas >= 2 us (mid-parity -> mid-sync >= 4 us)
  wd_gap : process
    variable t_fall : time;
    variable first  : boolean := true;
  begin
    loop
      wait until busany = '1';
      if not first then
        assert (now - t_fall) >= 2 us
          report "FALLO: hueco de bus menor del minimo" severity failure;
      end if;
      first := false;
      wait until busany = '0';
      t_fall := now;
    end loop;
  end process;

  ------------------------------------------------------------------
  -- estimulo
  ------------------------------------------------------------------
  stim : process
    procedure msg(rt : std_logic_vector(4 downto 0); tr : std_logic;
                  sa : std_logic_vector(4 downto 0);
                  wc : std_logic_vector(4 downto 0);
                  rr : std_logic := '0';
                  rt2 : std_logic_vector(4 downto 0) := "00000";
                  sa2 : std_logic_vector(4 downto 0) := "00000") is
    begin
      wait until rising_edge(clk);
      bc_frt <= rt; bc_ftr <= tr; bc_fsa <= sa; bc_fwc <= wc;
      bc_rtrt <= rr; bc_f2rt <= rt2; bc_f2sa <= sa2;
      bc_go <= '1';
      wait until rising_edge(clk);
      bc_go <= '0';
      wait until bc_done = '1' for 2 ms;
      assert bc_done = '1'
        report "FALLO: el BC no termino el mensaje" severity failure;
    end procedure;

    procedure exp(caso : string; ok, tout, serr, me : std_logic) is
    begin
      assert bc_ok = ok and bc_tout = tout and bc_serr = serr and bc_me = me
        report "FALLO fase " & caso & ": flags de resultado del BC"
        severity failure;
    end procedure;

  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 2 us;

    ------------------------------------------------ FASE 0a: RT solo
    rt0_en <= '1';
    wait for 100 us;
    assert n_bursts = 0
      report "FALLO fase 0a: el RT transmitio espontaneamente"
      severity failure;
    rt0_en <= '0';
    wait for 5 us;

    ------------------------------------------------ FASE 0b: BC solo
    bc_en <= '1';
    wait for 5 us;
    msg(AR0, '1', "00010", "00001");      -- RT->BC a RT0 (ausente) wc=1
    exp("0b", '0', '1', '0', '0');
    assert n_bursts = 1
      report "FALLO fase 0b: numero de rafagas" severity failure;

    ------------------------------------------------ habilitar los dos RTs
    rt0_en <= '1';
    rt1_en <= '1';
    wait for 10 us;

    -- P1: BC->RT0, sa=3, wc=4
    msg(AR0, '0', "00011", "00100");
    exp("1", '1', '0', '0', '0');
    assert bc_stat1 = x"2800"
      report "FALLO fase 1: status de RT0" severity failure;
    assert rt0_n = 4
      report "FALLO fase 1: cuenta RX de RT0" severity failure;
    wait for 30 us;

    -- P2: RT->BC desde RT1, sa=2, wc=3
    msg(AR1, '1', "00010", "00011");
    exp("2", '1', '0', '0', '0');
    assert bc_stat1 = x"4800"
      report "FALLO fase 2: status de RT1" severity failure;
    assert bc_n = 3
      report "FALLO fase 2: cuenta RX del BC" severity failure;
    wait for 30 us;

    -- P3: RT->RT (RT0 recibe, RT1 transmite), sa=4, wc=2
    msg(AR0, '0', "00100", "00010", '1', AR1, "00100");
    exp("3", '1', '0', '0', '0');
    assert bc_stat1 = x"4800" and bc_stat2 = x"2800"
      report "FALLO fase 3: statuses RT->RT" severity failure;
    assert rt0_n = 6 and bc_n = 5
      report "FALLO fase 3: cuentas RX" severity failure;
    wait for 30 us;

    -- P4: mode Transmit Status Word a RT0
    msg(AR0, '1', "00000", "00010");
    exp("4", '1', '0', '0', '0');
    assert bc_stat1 = x"2800"
      report "FALLO fase 4: status TxStatus RT0" severity failure;
    wait for 30 us;

    -- P5: mode Synchronize (sin dato) a RT1
    msg(AR1, '1', "00000", "00001");
    exp("5", '1', '0', '0', '0');
    assert bc_stat1 = x"4800"
      report "FALLO fase 5: status Sync RT1" severity failure;
    wait for 30 us;

    -- P6: mode Synchronize con dato a RT0
    msg(AR0, '0', "00000", "10001");
    exp("6", '1', '0', '0', '0');
    assert bc_stat1 = x"2800"
      report "FALLO fase 6: status SyncData RT0" severity failure;
    assert rt0_n = 7
      report "FALLO fase 6: cuenta RX de RT0" severity failure;
    wait for 30 us;

    -- P7: broadcast BC->RT31, sa=6, wc=2 (sin status, BCR en ambos)
    msg("11111", '0', "00110", "00010");
    exp("7", '1', '0', '0', '0');
    wait for 10 us;
    assert rt0_n = 9 and rt1_n = 2
      report "FALLO fase 7: cuentas RX del broadcast" severity failure;
    assert rt0_bcr = '1' and rt1_bcr = '1'
      report "FALLO fase 7: BCR no puesto" severity failure;
    wait for 20 us;

    -- P8/P9: TxStatus muestra BCR=1 en ambos (y lo preserva)
    msg(AR0, '1', "00000", "00010");
    exp("8", '1', '0', '0', '0');
    assert bc_stat1 = x"2810"
      report "FALLO fase 8: BCR no visible en status RT0" severity failure;
    wait for 20 us;
    msg(AR1, '1', "00000", "00010");
    exp("9", '1', '0', '0', '0');
    assert bc_stat1 = x"4810"
      report "FALLO fase 9: BCR no visible en status RT1" severity failure;
    wait for 20 us;

    -- P10: command valido normal a RT0 limpia su BCR
    msg(AR0, '0', "00011", "00001");
    exp("10", '1', '0', '0', '0');
    assert rt0_n = 10
      report "FALLO fase 10: cuenta RX de RT0" severity failure;
    wait for 20 us;

    -- P11: TxStatus RT0 -> BCR limpio
    msg(AR0, '1', "00000", "00010");
    exp("11", '1', '0', '0', '0');
    assert bc_stat1 = x"2800"
      report "FALLO fase 11: BCR de RT0 no se limpio" severity failure;
    wait for 20 us;

    -- P12: mode code NO soportado (tr=1, 00101) a RT1 -> status con ME
    msg(AR1, '1', "00000", "00101");
    exp("12", '1', '0', '0', '1');
    assert bc_stat1 = x"4C00"
      report "FALLO fase 12: ME no puesto por command ilegal" severity failure;
    wait for 20 us;

    -- P13: TxStatus RT1 preserva ME
    msg(AR1, '1', "00000", "00010");
    exp("13", '1', '0', '0', '1');
    assert bc_stat1 = x"4C00"
      report "FALLO fase 13: ME no preservado por TxStatus" severity failure;
    wait for 20 us;

    -- P14: Sync valido a RT1 limpia ME
    msg(AR1, '1', "00000", "00001");
    exp("14", '1', '0', '0', '0');
    assert bc_stat1 = x"4800"
      report "FALLO fase 14: ME no limpiado por command valido"
      severity failure;
    wait for 20 us;

    -- P15: TxStatus RT1 confirma ME limpio
    msg(AR1, '1', "00000", "00010");
    exp("15", '1', '0', '0', '0');
    assert bc_stat1 = x"4800"
      report "FALLO fase 15: status final de RT1" severity failure;
    wait for 20 us;

    -- P16: BC->RT a direccion 12 (nadie) -> timeout, RTs callados
    msg("01100", '0', "00011", "00010");
    exp("16", '0', '1', '0', '0');
    assert rt0_n = 10 and rt1_n = 2
      report "FALLO fase 16: un RT hablo sin ser llamado" severity failure;
    wait for 20 us;

    -- P17: recuperacion
    msg(AR0, '1', "00000", "00010");
    exp("17", '1', '0', '0', '0');

    -- P17b: go inmediato: el hueco intermensaje lo impone el BC
    msg(AR0, '1', "00000", "00010");
    exp("17b", '1', '0', '0', '0');
    wait for 30 us;

    ------------------------------------------------ cierre
    assert rt0_n = 10 and rt1_n = 2 and bc_n = 5
      report "FALLO: cuentas finales de flujo" severity failure;
    assert n_bursts = 36
      report "FALLO: numero total de rafagas (" & integer'image(n_bursts)
             & ")" severity failure;
    assert busany = '0'
      report "FALLO: el bus no quedo en reposo" severity failure;
    report "M1553 CAPA 1C PASS";
    finish;
  end process;

end architecture sim;
