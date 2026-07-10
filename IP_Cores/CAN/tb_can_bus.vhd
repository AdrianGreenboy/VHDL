-- ============================================================================
-- tb_can_bus.vhd : capa 1c - RTL contra RTL en bus resuelto ('H' recesivo).
-- Dos instancias identicas de can_engine (A y B) en AND cableado. Cobertura:
--   C1/C2: trafico en ambos sentidos (base y extendida) con ACK cruzado real
--   C3: trama remota
--   C4: arbitraje simultaneo entre nucleos (mismo grid tras el reset), el
--       perdedor recibe la trama ganadora, la asiente y reintenta
--   C5: inyeccion externa de un bit dominante en DATA -> error de bit en el
--       transmisor (TEC+8) y error de stuffing en el receptor (REC+1) con
--       superposicion de flags; reintento y decremento de ambos contadores
--   C6: ping-pong rapido en ambos sentidos
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_can_bus is
end entity;

architecture sim of tb_can_bus is

  constant C_CLK : time := 10 ns;
  constant C_BIT : time := 2 us;

  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';

  signal busw : std_logic := 'H';
  signal a_tx, b_tx, rx_i : std_logic;

  -- peticiones nodo A
  signal a_req  : std_logic := '0';
  signal a_id   : std_logic_vector(28 downto 0) := (others => '0');
  signal a_ide, a_rtr : std_logic := '0';
  signal a_dlc  : std_logic_vector(3 downto 0) := (others => '0');
  signal a_data : std_logic_vector(63 downto 0) := (others => '0');
  -- peticiones nodo B
  signal b_req  : std_logic := '0';
  signal b_id   : std_logic_vector(28 downto 0) := (others => '0');
  signal b_ide, b_rtr : std_logic := '0';
  signal b_dlc  : std_logic_vector(3 downto 0) := (others => '0');
  signal b_data : std_logic_vector(63 downto 0) := (others => '0');

  signal a_done, a_arb, a_txe, a_rxv, a_errp, a_busy : std_logic;
  signal b_done, b_arb, b_txe, b_rxv, b_errp, b_busy : std_logic;
  signal a_rid, b_rid : std_logic_vector(28 downto 0);
  signal a_ride, a_rrtr, b_ride, b_rrtr : std_logic;
  signal a_rdlc, b_rdlc : std_logic_vector(3 downto 0);
  signal a_rdat, b_rdat : std_logic_vector(63 downto 0);
  signal a_tec, b_tec : std_logic_vector(8 downto 0);
  signal a_rec, b_rec : std_logic_vector(7 downto 0);
  signal a_est, b_est : std_logic_vector(1 downto 0);

  signal na_done, na_rxv, na_arb, na_err : integer := 0;
  signal nb_done, nb_rxv, nb_arb, nb_err : integer := 0;

begin

  clk <= not clk after C_CLK / 2;

  busw <= 'H';
  busw <= '0' when a_tx = '0' else 'Z';
  busw <= '0' when b_tx = '0' else 'Z';
  rx_i <= to_x01(busw);

  nodo_a : entity work.can_engine
    port map (
      clk => clk, rstn => rstn,
      brp => x"09", tseg1 => "1100", tseg2 => "101", sjw => "01",
      tx_req => a_req, tx_abort => '0',
      tx_id => a_id, tx_ide => a_ide, tx_rtr => a_rtr,
      tx_dlc => a_dlc, tx_data => a_data,
      tx_busy => a_busy, tx_done => a_done, tx_arb_lost => a_arb,
      tx_err => a_txe,
      rx_valid => a_rxv, rx_id => a_rid, rx_ide => a_ride,
      rx_rtr => a_rrtr, rx_dlc => a_rdlc, rx_data => a_rdat,
      tec => a_tec, rec => a_rec, err_state => a_est, err_pulse => a_errp,
      can_rx => rx_i, can_tx => a_tx );

  nodo_b : entity work.can_engine
    port map (
      clk => clk, rstn => rstn,
      brp => x"09", tseg1 => "1100", tseg2 => "101", sjw => "01",
      tx_req => b_req, tx_abort => '0',
      tx_id => b_id, tx_ide => b_ide, tx_rtr => b_rtr,
      tx_dlc => b_dlc, tx_data => b_data,
      tx_busy => b_busy, tx_done => b_done, tx_arb_lost => b_arb,
      tx_err => b_txe,
      rx_valid => b_rxv, rx_id => b_rid, rx_ide => b_ride,
      rx_rtr => b_rrtr, rx_dlc => b_rdlc, rx_data => b_rdat,
      tec => b_tec, rec => b_rec, err_state => b_est, err_pulse => b_errp,
      can_rx => rx_i, can_tx => b_tx );

  mon_p : process(clk)
  begin
    if rising_edge(clk) then
      if a_done = '1' then na_done <= na_done + 1; end if;
      if a_rxv  = '1' then na_rxv  <= na_rxv  + 1; end if;
      if a_arb  = '1' then na_arb  <= na_arb  + 1; end if;
      if a_errp = '1' then na_err  <= na_err  + 1; end if;
      if b_done = '1' then nb_done <= nb_done + 1; end if;
      if b_rxv  = '1' then nb_rxv  <= nb_rxv  + 1; end if;
      if b_arb  = '1' then nb_arb  <= nb_arb  + 1; end if;
      if b_errp = '1' then nb_err  <= nb_err  + 1; end if;
    end if;
  end process;

  stim_p : process
    variable exp_ad, exp_bd, exp_ar, exp_br : integer := 0;
    variable t0 : time;

    procedure a_send(id : std_logic_vector(28 downto 0); ide, rtr : std_logic;
                     dlc : std_logic_vector(3 downto 0);
                     dat : std_logic_vector(63 downto 0)) is
    begin
      a_id <= id; a_ide <= ide; a_rtr <= rtr; a_dlc <= dlc; a_data <= dat;
      wait until rising_edge(clk);
      a_req <= '1';
      wait until rising_edge(clk);
      a_req <= '0';
    end procedure;

    procedure b_send(id : std_logic_vector(28 downto 0); ide, rtr : std_logic;
                     dlc : std_logic_vector(3 downto 0);
                     dat : std_logic_vector(63 downto 0)) is
    begin
      b_id <= id; b_ide <= ide; b_rtr <= rtr; b_dlc <= dlc; b_data <= dat;
      wait until rising_edge(clk);
      b_req <= '1';
      wait until rising_edge(clk);
      b_req <= '0';
    end procedure;

    procedure w_adone(msg : string) is
    begin
      exp_ad := exp_ad + 1;
      if na_done /= exp_ad then
        wait until na_done = exp_ad for 2 ms;
      end if;
      assert na_done = exp_ad
        report "FALLO: timeout esperando tx_done de A en " & msg
        severity failure;
    end procedure;

    procedure w_bdone(msg : string) is
    begin
      exp_bd := exp_bd + 1;
      if nb_done /= exp_bd then
        wait until nb_done = exp_bd for 2 ms;
      end if;
      assert nb_done = exp_bd
        report "FALLO: timeout esperando tx_done de B en " & msg
        severity failure;
    end procedure;

    procedure w_arxv(msg : string) is
    begin
      exp_ar := exp_ar + 1;
      if na_rxv /= exp_ar then
        wait until na_rxv = exp_ar for 2 ms;
      end if;
      assert na_rxv = exp_ar
        report "FALLO: timeout esperando rx_valid de A en " & msg
        severity failure;
      wait for 1 ns;
    end procedure;

    procedure w_brxv(msg : string) is
    begin
      exp_br := exp_br + 1;
      if nb_rxv /= exp_br then
        wait until nb_rxv = exp_br for 2 ms;
      end if;
      assert nb_rxv = exp_br
        report "FALLO: timeout esperando rx_valid de B en " & msg
        severity failure;
      wait for 1 ns;
    end procedure;

    procedure chk_cnt(sig : integer; v : integer; msg : string) is
    begin
      assert sig = v
        report "FALLO: contador " & integer'image(sig) & " esperado "
               & integer'image(v) & " en " & msg
        severity failure;
    end procedure;

  begin
    rstn <= '0';
    wait for 200 ns;
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 20 us;

    -- ------------------------------------------------------------------
    -- C1: A transmite, B recibe y asiente
    -- ------------------------------------------------------------------
    report "C1: A hacia B, trama base DLC=4";
    a_send("000000000000000000" & "00100100011", '0', '0', x"4",
           x"CAFE12AB00000000");
    w_adone("C1");
    w_brxv("C1");
    assert b_rid(10 downto 0) = "00100100011" and b_ride = '0'
           and b_rrtr = '0' and b_rdlc = x"4"
      report "FALLO: C1 campos de B incorrectos" severity failure;
    assert b_rdat = x"CAFE12AB00000000"
      report "FALLO: C1 datos de B incorrectos" severity failure;
    assert to_integer(unsigned(a_tec)) = 0
      report "FALLO: C1 TEC de A alterado" severity failure;

    -- ------------------------------------------------------------------
    -- C2: B transmite extendida, A recibe
    -- ------------------------------------------------------------------
    report "C2: B hacia A, trama extendida DLC=8";
    b_send("10010110100101101001011010010", '1', '0', x"8",
           x"0011223344556677");
    w_bdone("C2");
    w_arxv("C2");
    assert a_rid = "10010110100101101001011010010" and a_ride = '1'
      report "FALLO: C2 identificador de A incorrecto" severity failure;
    assert a_rdlc = x"8" and a_rdat = x"0011223344556677"
      report "FALLO: C2 datos de A incorrectos" severity failure;

    -- ------------------------------------------------------------------
    -- C3: trama remota de A
    -- ------------------------------------------------------------------
    report "C3: trama remota de A";
    a_send("000000000000000000" & "01111000011", '0', '1', x"6",
           (others => '0'));
    w_adone("C3");
    w_brxv("C3");
    assert b_rrtr = '1' and b_rdlc = x"6"
      report "FALLO: C3 campos remotos incorrectos" severity failure;

    -- ------------------------------------------------------------------
    -- C4: arbitraje simultaneo entre los dos nucleos
    -- ------------------------------------------------------------------
    report "C4: arbitraje simultaneo A/B";
    -- ambos nucleos comparten grid tras el reset: peticiones en el mismo bit
    b_id <= "000000000000000000" & "00100100011"; -- B pierde (ID mayor)
    b_ide <= '0'; b_rtr <= '0'; b_dlc <= x"1";
    b_data <= x"BB00000000000000";
    a_id <= "000000000000000000" & "00011110000"; -- A gana (ID menor)
    a_ide <= '0'; a_rtr <= '0'; a_dlc <= x"1";
    a_data <= x"AA00000000000000";
    wait until rising_edge(clk);
    a_req <= '1'; b_req <= '1';
    wait until rising_edge(clk);
    a_req <= '0'; b_req <= '0';
    -- A gana: B recibe la trama de A y la asiente
    w_adone("C4 ganador");
    w_brxv("C4 perdedor recibe");
    assert nb_arb = 1
      report "FALLO: C4 B no registro la perdida de arbitraje"
      severity failure;
    assert na_arb = 0
      report "FALLO: C4 A perdio arbitraje indebidamente" severity failure;
    assert b_rid(10 downto 0) = "00011110000"
           and b_rdat = x"AA00000000000000"
      report "FALLO: C4 trama ganadora incorrecta en B" severity failure;
    -- reintento automatico de B: A la recibe
    w_bdone("C4 reintento");
    w_arxv("C4 reintento");
    assert a_rid(10 downto 0) = "00100100011"
           and a_rdat = x"BB00000000000000"
      report "FALLO: C4 trama de reintento incorrecta en A" severity failure;
    assert to_integer(unsigned(a_tec)) = 0
           and to_integer(unsigned(b_tec)) = 0
      report "FALLO: C4 TEC alterado" severity failure;

    -- ------------------------------------------------------------------
    -- C5: inyeccion externa de dominante en DATA (bit crudo 20)
    -- ------------------------------------------------------------------
    report "C5: error inyectado con superposicion de flags";
    a_send("000000000000000000" & "01010101010", '0', '0', x"1",
           x"AA00000000000000");
    -- esperar el SOF de A e inyectar en el primer bit de datos
    if to_x01(busw) /= '0' then
      wait until to_x01(busw) = '0';
    end if;
    t0 := now;
    wait for (t0 + 20 * C_BIT + 50 ns) - now;
    busw <= '0';
    wait for C_BIT - 100 ns;
    busw <= 'Z';
    -- A: error de bit (TEC+8) al muestrear; B: error de stuffing (REC+1)
    -- al sexto dominante del flag de A (unos 10 us despues)
    wait for 12 us;
    assert to_integer(unsigned(a_tec)) = 8
      report "FALLO: C5 TEC de A distinto de 8 tras la inyeccion"
      severity failure;
    assert to_integer(unsigned(b_rec)) = 1
      report "FALLO: C5 REC de B distinto de 1 tras la inyeccion"
      severity failure;
    -- reintento automatico de A: B recibe y ambos contadores decrementan
    w_adone("C5 reintento");
    w_brxv("C5 reintento");
    assert b_rdat = x"AA00000000000000"
      report "FALLO: C5 datos del reintento incorrectos" severity failure;
    assert to_integer(unsigned(a_tec)) = 7
      report "FALLO: C5 TEC de A no decremento" severity failure;
    assert to_integer(unsigned(b_rec)) = 0
      report "FALLO: C5 REC de B no decremento" severity failure;

    -- ------------------------------------------------------------------
    -- C6: ping-pong rapido en ambos sentidos
    -- ------------------------------------------------------------------
    report "C6: ping-pong A/B";
    for i in 1 to 3 loop
      a_send("000000000000000000" & "00000001111", '0', '0', x"2",
             x"A00B000000000000");
      w_adone("C6 A " & integer'image(i));
      w_brxv("C6 A " & integer'image(i));
      b_send("000000000000000000" & "00000010001", '0', '0', x"2",
             x"B00A000000000000");
      w_bdone("C6 B " & integer'image(i));
      w_arxv("C6 B " & integer'image(i));
    end loop;
    assert a_rdat = x"B00A000000000000" and b_rdat = x"A00B000000000000"
      report "FALLO: C6 datos finales incorrectos" severity failure;
    assert to_integer(unsigned(a_tec)) = 4
      report "FALLO: C6 TEC de A no llego a 4" severity failure;
    assert to_integer(unsigned(b_tec)) = 0
      report "FALLO: C6 TEC de B alterado" severity failure;
    assert a_est = "00" and b_est = "00"
      report "FALLO: C6 estados de error no activos" severity failure;

    report "CAPA 1c OK: RTL contra RTL en bus resuelto";
    finish;
  end process;

  wd_p : process
  begin
    wait for 40 ms;
    assert false
      report "FALLO: timeout global del testbench"
      severity failure;
  end process;

end architecture;
