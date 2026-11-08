-- ============================================================================
-- tb_can_engine_rx.vhd : capa 1b - motor CAN (receptor) contra modelo
-- transmisor bit-bang procedural. El modelo construye cada trama (stuffing y
-- CRC-15 propios), la conduce por tiempos absolutos y puede corromperla:
--   corrupt = 0 : trama limpia (verifica el ACK del motor y el EOF)
--   corrupt = 1 : error de stuffing (sexto bit igual) en la primera ocasion
--   corrupt = 2 : CRC invalido (bit bajo invertido) -> sin ACK, flag tras
--                 el delimitador de ACK
--   corrupt = 3 : delimitador de CRC dominante (error de forma)
--   corrupt = 4 : trama limpia + dominante en el primer bit de intermision
--                 (el motor responde con trama de overload)
-- Tras cada error el modelo verifica el flag del motor (activo: 6 dominantes
-- + delimitador; pasivo: bus recesivo).
-- Temporizacion identica a la capa 1a: 500 kbit/s, muestreo al 70 %.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_can_engine_rx is
end entity;

architecture sim of tb_can_engine_rx is

  constant C_CLK  : time := 10 ns;
  constant C_BIT  : time := 2 us;
  constant C_SAMP : time := 1400 ns;

  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';
  signal rst  : std_logic;

  signal busw : std_logic := 'H';
  signal eng_tx, eng_rx : std_logic;

  signal g_busy, g_done, g_arb, g_txe, g_rxv, g_errp : std_logic;
  signal g_rid  : std_logic_vector(28 downto 0);
  signal g_ride, g_rrtr : std_logic;
  signal g_rdlc : std_logic_vector(3 downto 0);
  signal g_rdat : std_logic_vector(63 downto 0);
  signal g_tec  : std_logic_vector(8 downto 0);
  signal g_rec  : std_logic_vector(7 downto 0);
  signal g_est  : std_logic_vector(1 downto 0);

  signal n_rxv, n_err : integer := 0;

  function mcrc(bits : std_logic_vector; n : integer) return std_logic_vector is
    variable c   : std_logic_vector(14 downto 0) := (others => '0');
    variable inv : std_logic;
  begin
    for i in 0 to n - 1 loop
      inv := bits(i) xor c(14);
      c := c(13 downto 0) & '0';
      if inv = '1' then
        c := c xor "100010110011001";
      end if;
    end loop;
    return c;
  end function;

begin

  clk <= not clk after C_CLK / 2;

  busw <= 'H';
  busw <= '0' when eng_tx = '0' else 'Z';
  eng_rx <= to_x01(busw);
  rst <= not rstn;

  dut : entity work.can_engine
    port map (
      clk => clk, rst => rst,
      brp => x"09", tseg1 => "1100", tseg2 => "101", sjw => "01",
      tx_req => '0', tx_abort => '0',
      tx_id => (others => '0'), tx_ide => '0', tx_rtr => '0',
      tx_dlc => (others => '0'), tx_data => (others => '0'),
      tx_busy => g_busy, tx_done => g_done, tx_arb_lost => g_arb,
      tx_err => g_txe,
      rx_valid => g_rxv, rx_id => g_rid, rx_ide => g_ride,
      rx_rtr => g_rrtr, rx_dlc => g_rdlc, rx_data => g_rdat,
      tec => g_tec, rec => g_rec, err_state => g_est, err_pulse => g_errp,
      can_rx => eng_rx, can_tx => eng_tx );

  mon_p : process(clk)
  begin
    if rising_edge(clk) then
      if g_rxv  = '1' then n_rxv <= n_rxv + 1; end if;
      if g_errp = '1' then n_err <= n_err + 1; end if;
    end if;
  end process;

  -- --------------------------------------------------------------------
  -- modelo transmisor + estimulos
  -- --------------------------------------------------------------------
  stim_p : process
    variable t0   : time;
    variable k    : integer;
    variable exp_rxv : integer := 0;

    -- muestrear el bit crudo j (grid del modelo)
    procedure graw(j : in integer; bo : out std_logic) is
      variable tgt : time;
    begin
      tgt := t0 + j * C_BIT + C_SAMP;
      if tgt > now then
        wait for tgt - now;
      end if;
      bo := to_x01(busw);
    end procedure;

    -- conducir el bit crudo k y verificar el bus (salvo en ACK)
    procedure putraw(bv : in std_logic; isack : in boolean) is
      variable tgt : time;
      variable r   : std_logic;
    begin
      tgt := t0 + k * C_BIT;
      if tgt > now then
        wait for tgt - now;
      end if;
      if bv = '0' and not isack then
        busw <= '0';
      else
        busw <= 'Z';
      end if;
      wait for C_SAMP;
      r := to_x01(busw);
      if isack then
        assert r = '0'
          report "FALLO: el motor no dio ACK en el bit crudo "
                 & integer'image(k)
          severity failure;
      else
        assert r = bv
          report "FALLO: el bus no refleja el bit del modelo en el indice "
                 & integer'image(k)
          severity failure;
      end if;
      k := k + 1;
    end procedure;

    -- verificar flag de error del motor a partir del bit crudo ke+1
    procedure chk_flag(ke : in integer; active : in boolean) is
      variable r   : std_logic;
      variable tgt : time;
    begin
      -- sostener el bit ofensivo hasta su final (el motor muestrea con el
      -- retardo del sincronizador de entrada) y liberar despues
      tgt := t0 + (ke + 1) * C_BIT;
      if tgt > now then
        wait for tgt - now;
      end if;
      busw <= 'Z';
      if active then
        for i in 1 to 6 loop
          graw(ke + i, r);
          assert r = '0'
            report "FALLO: flag activo del receptor incompleto en bit "
                   & integer'image(i)
            severity failure;
        end loop;
        graw(ke + 7, r);
        assert r = '1'
          report "FALLO: falta delimitador tras el flag activo del receptor"
          severity failure;
      else
        for i in 1 to 6 loop
          graw(ke + i, r);
          assert r = '1'
            report "FALLO: se esperaba flag pasivo del receptor en bit "
                   & integer'image(i)
            severity failure;
        end loop;
      end if;
    end procedure;

    -- transmitir una trama; cont=true encadena con intermision exacta de 3 bits
    procedure send(id : std_logic_vector(28 downto 0); ide, rtr : std_logic;
                   dlc : std_logic_vector(3 downto 0);
                   dat : std_logic_vector(63 downto 0);
                   corrupt : integer; cont : boolean;
                   active_flag : boolean) is
      variable seq : std_logic_vector(0 to 127);
      variable sl  : integer;
      variable c15 : std_logic_vector(14 downto 0);
      variable idx : integer;
      variable rn  : integer;
      variable lb  : std_logic;
      variable sb  : std_logic;
      variable r   : std_logic;
      variable nbt : integer;
      variable ke  : integer;
    begin
      -- secuencia sin stuffing SOF..CRC
      sl := 0;
      seq(sl) := '0'; sl := sl + 1;
      if ide = '1' then
        for i in 10 downto 0 loop
          seq(sl) := id(18 + i); sl := sl + 1;
        end loop;
        seq(sl) := '1'; sl := sl + 1;      -- SRR
        seq(sl) := '1'; sl := sl + 1;      -- IDE
        for i in 17 downto 0 loop
          seq(sl) := id(i); sl := sl + 1;
        end loop;
        seq(sl) := rtr; sl := sl + 1;
        seq(sl) := '0'; sl := sl + 1;      -- r1
      else
        for i in 10 downto 0 loop
          seq(sl) := id(i); sl := sl + 1;
        end loop;
        seq(sl) := rtr; sl := sl + 1;
        seq(sl) := '0'; sl := sl + 1;      -- IDE
      end if;
      seq(sl) := '0'; sl := sl + 1;        -- r0
      for i in 3 downto 0 loop
        seq(sl) := dlc(i); sl := sl + 1;
      end loop;
      nbt := to_integer(unsigned(dlc));
      if nbt > 8 then nbt := 8; end if;
      if rtr = '1' then nbt := 0; end if;
      nbt := nbt * 8;
      for i in 0 to nbt - 1 loop
        seq(sl) := dat(63 - i); sl := sl + 1;
      end loop;
      c15 := mcrc(seq, sl);
      if corrupt = 2 then
        c15(0) := not c15(0);
      end if;
      for i in 14 downto 0 loop
        seq(sl) := c15(i); sl := sl + 1;
      end loop;

      if cont then
        k := k + 3; -- intermision exacta de 3 bits sobre el mismo grid
      else
        t0 := now + 4 * C_BIT;
        k := 0;
      end if;

      -- transmision con stuffing (corrupt=1: sexto bit igual)
      idx := 0;
      rn := 0; lb := '1';
      while idx < sl loop
        if rn = 5 then
          if corrupt = 1 then
            ke := k;
            putraw(lb, false); -- violacion de stuffing
            chk_flag(ke, active_flag);
            return;
          end if;
          sb := not lb;
          putraw(sb, false);
          rn := 1; lb := sb;
        else
          sb := seq(idx);
          putraw(sb, false);
          if rn = 0 then
            rn := 1; lb := sb;
          elsif sb = lb then
            rn := rn + 1;
          else
            rn := 1; lb := sb;
          end if;
          idx := idx + 1;
        end if;
      end loop;
      -- ISO 11898-1: stuffing covers the CRC sequence inclusive; a run of 5
      -- ending at the last CRC bit gets a stuff bit before the delimiter
      if rn = 5 then
        sb := not lb;
        putraw(sb, false);
      end if;

      -- delimitador de CRC
      if corrupt = 3 then
        ke := k;
        putraw('0', false);
        chk_flag(ke, active_flag);
        return;
      end if;
      putraw('1', false);

      -- ranura de ACK
      if corrupt = 2 then
        ke := k;
        putraw('1', false);      -- el motor no debe dar ACK
        ke := k;
        putraw('1', false);      -- delimitador de ACK
        chk_flag(ke, active_flag); -- flag tras el delimitador de ACK
        return;
      end if;
      putraw('1', true);

      -- delimitador de ACK + EOF
      putraw('1', false);
      for i in 1 to 7 loop
        putraw('1', false);
      end loop;

      -- overload: dominante en el primer bit de intermision
      if corrupt = 4 then
        ke := k;
        putraw('0', false);
        chk_flag(ke, true); -- el overload siempre es un flag dominante
      end if;
      busw <= 'Z';
    end procedure;

    -- local error seen only by the engine: SOF + 5 dominant bits (the 6th
    -- dominant is a stuff violation detected at raw bit 5). The engine
    -- sends its active flag on raw 6..11. Then:
    --   hold > 0 : the model keeps the bus dominant for 'hold' more bits
    --              (raw 12 ..), i.e. the 1st bit after the flag is dominant
    --   dpos > 0 : dominant bit at error-delimiter bit 'dpos' (bit 1 = raw 12)
    procedure lerr(hold : integer; dpos : integer) is
      variable r : std_logic;
    begin
      t0 := now + 4 * C_BIT;
      k := 0;
      for i in 0 to 5 loop
        putraw('0', false);
      end loop;
      wait for t0 + 6 * C_BIT - now;
      busw <= 'Z';
      for i in 6 to 11 loop
        graw(i, r);
        assert r = '0'
          report "FALLO: flag activo del receptor incompleto (lerr)"
          severity failure;
      end loop;
      if hold > 0 then
        wait for t0 + 12 * C_BIT - now;
        busw <= '0';
        wait for hold * C_BIT;
        busw <= 'Z';
      end if;
      if dpos > 0 then
        wait for t0 + (11 + dpos) * C_BIT - now;
        busw <= '0';
        wait for C_BIT;
        busw <= 'Z';
      end if;
      wait for 40 * C_BIT;  -- flags, delimiter and intermission settle
    end procedure;

    procedure wrxv(msg : string) is
    begin
      exp_rxv := exp_rxv + 1;
      if n_rxv /= exp_rxv then
        wait until n_rxv = exp_rxv for 1 ms;
      end if;
      assert n_rxv = exp_rxv
        report "FALLO: timeout esperando rx_valid en " & msg
        severity failure;
      wait for 1 ns;
    end procedure;

    procedure chk_rec(v : integer; msg : string) is
    begin
      wait for 1 ns;
      assert to_integer(unsigned(g_rec)) = v
        report "FALLO: REC=" & integer'image(to_integer(unsigned(g_rec)))
               & " esperado " & integer'image(v) & " en " & msg
        severity failure;
    end procedure;

  begin
    rstn <= '0';
    wait for 200 ns;
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 20 us;

    -- ------------------------------------------------------------------
    -- R1: trama base DLC=0
    -- ------------------------------------------------------------------
    report "R1: trama base DLC=0";
    send("000000000000000000" & "00100100011", '0', '0', x"0",
         (others => '0'), 0, false, true);
    wrxv("R1");
    assert g_rid(10 downto 0) = "00100100011" and g_ride = '0'
           and g_rrtr = '0' and g_rdlc = x"0"
      report "FALLO: R1 campos incorrectos" severity failure;
    assert g_rdat = x"0000000000000000"
      report "FALLO: R1 datos no nulos" severity failure;
    chk_rec(0, "R1");

    -- ------------------------------------------------------------------
    -- R2: trama base DLC=8
    -- ------------------------------------------------------------------
    report "R2: trama base DLC=8";
    send("000000000000000000" & "10110100101", '0', '0', x"8",
         x"DEADBEEF01234567", 0, false, true);
    wrxv("R2");
    assert g_rid(10 downto 0) = "10110100101" and g_rdlc = x"8"
      report "FALLO: R2 campos incorrectos" severity failure;
    assert g_rdat = x"DEADBEEF01234567"
      report "FALLO: R2 datos incorrectos" severity failure;

    -- ------------------------------------------------------------------
    -- R3: trama extendida DLC=5
    -- ------------------------------------------------------------------
    report "R3: trama extendida DLC=5";
    send("01011010010110100101101001011", '1', '0', x"5",
         x"1122334455000000", 0, false, true);
    wrxv("R3");
    assert g_rid = "01011010010110100101101001011" and g_ride = '1'
      report "FALLO: R3 identificador incorrecto" severity failure;
    assert g_rdlc = x"5" and g_rdat = x"1122334455000000"
      report "FALLO: R3 datos incorrectos" severity failure;

    -- ------------------------------------------------------------------
    -- R4: trama remota extendida DLC=7
    -- ------------------------------------------------------------------
    report "R4: trama remota extendida DLC=7";
    send("11111111111000000000011111111", '1', '1', x"7",
         (others => '0'), 0, false, true);
    wrxv("R4");
    assert g_ride = '1' and g_rrtr = '1' and g_rdlc = x"7"
      report "FALLO: R4 campos incorrectos" severity failure;
    assert g_rdat = x"0000000000000000"
      report "FALLO: R4 datos no nulos" severity failure;

    -- ------------------------------------------------------------------
    -- R5: DLC=15 (el motor limita los datos a 8 bytes)
    -- ------------------------------------------------------------------
    report "R5: DLC=15 con 8 bytes";
    send("000000000000000000" & "01010101010", '0', '0', x"F",
         x"A5A5A5A5A5A5A5A5", 0, false, true);
    wrxv("R5");
    assert g_rdlc = x"F" and g_rdat = x"A5A5A5A5A5A5A5A5"
      report "FALLO: R5 campos incorrectos" severity failure;

    -- ------------------------------------------------------------------
    -- R6: dos tramas espalda con espalda (intermision exacta de 3 bits)
    -- ------------------------------------------------------------------
    report "R6: tramas espalda con espalda";
    send("000000000000000000" & "00000000001", '0', '0', x"1",
         x"1100000000000000", 0, false, true);
    wrxv("R6 primera");
    assert g_rdat = x"1100000000000000"
      report "FALLO: R6 primera trama incorrecta" severity failure;
    send("000000000000000000" & "00000000010", '0', '0', x"1",
         x"2200000000000000", 0, true, true);
    wrxv("R6 segunda");
    assert g_rid(10 downto 0) = "00000000010"
           and g_rdat = x"2200000000000000"
      report "FALLO: R6 segunda trama incorrecta" severity failure;
    chk_rec(0, "R6");

    -- ------------------------------------------------------------------
    -- R7: error de stuffing -> flag activo, REC+1; luego trama limpia
    -- ------------------------------------------------------------------
    report "R7: error de stuffing";
    send((others => '0'), '0', '0', x"1", x"0000000000000000",
         1, false, true);
    chk_rec(1, "R7 tras el error");
    wait for 30 us;
    send("000000000000000000" & "00100100011", '0', '0', x"1",
         x"3300000000000000", 0, false, true);
    wrxv("R7 limpia");
    chk_rec(0, "R7 tras la trama limpia");

    -- ------------------------------------------------------------------
    -- R8: CRC invalido -> sin ACK, flag tras el delimitador de ACK, REC+1
    -- ------------------------------------------------------------------
    report "R8: CRC invalido";
    send("000000000000000000" & "01100110011", '0', '0', x"2",
         x"4455000000000000", 2, false, true);
    chk_rec(1, "R8 tras el error");
    wait for 30 us;
    send("000000000000000000" & "01100110011", '0', '0', x"2",
         x"4455000000000000", 0, false, true);
    wrxv("R8 limpia");
    chk_rec(0, "R8 tras la trama limpia");

    -- ------------------------------------------------------------------
    -- R9: delimitador de CRC dominante -> error de forma, REC+1
    -- ------------------------------------------------------------------
    report "R9: error de forma en el delimitador de CRC";
    send("000000000000000000" & "01110001110", '0', '0', x"1",
         x"6600000000000000", 3, false, true);
    chk_rec(1, "R9 tras el error");
    wait for 30 us;
    send("000000000000000000" & "01110001110", '0', '0', x"1",
         x"6600000000000000", 0, false, true);
    wrxv("R9 limpia");
    chk_rec(0, "R9 tras la trama limpia");

    -- ------------------------------------------------------------------
    -- R10: overload tras una trama valida
    -- ------------------------------------------------------------------
    report "R10: overload en la intermision";
    send("000000000000000000" & "00011100011", '0', '0', x"1",
         x"7700000000000000", 4, false, true);
    wrxv("R10");
    assert g_rdat = x"7700000000000000"
      report "FALLO: R10 trama incorrecta" severity failure;
    chk_rec(0, "R10 (el overload no altera REC)");
    wait for 40 us;

    -- ------------------------------------------------------------------
    -- R11: escalada del receptor a error pasivo y retorno a activo
    -- ------------------------------------------------------------------
    report "R11: escalada del receptor a pasivo";
    for i in 1 to 127 loop
      send((others => '0'), '0', '0', x"1", (others => '0'),
           1, false, true);
      chk_rec(i, "R11 error " & integer'image(i));
      wait for 30 us;
    end loop;
    wait for 1 ns;
    assert g_est = "00"
      report "FALLO: R11 pasivo prematuro con REC=127" severity failure;
    -- error 128: cruza a pasivo (el REC incrementa antes de elegir el flag,
    -- por lo que el flag del cruce ya es pasivo)
    send((others => '0'), '0', '0', x"1", (others => '0'),
         1, false, false);
    chk_rec(128, "R11 cruce a pasivo");
    assert g_est = "01"
      report "FALLO: R11 no se alcanzo el estado pasivo" severity failure;
    wait for 30 us;
    -- error 129: el receptor pasivo emite flag pasivo (bus recesivo)
    send((others => '0'), '0', '0', x"1", (others => '0'),
         1, false, false);
    chk_rec(129, "R11 error en pasivo");
    wait for 40 us;
    -- una recepcion valida devuelve REC a 119 y el estado a activo
    send("000000000000000000" & "00100100011", '0', '0', x"1",
         x"8800000000000000", 0, false, true);
    wrxv("R11 limpia");
    chk_rec(119, "R11 tras la trama limpia");
    assert g_est = "00"
      report "FALLO: R11 no se recupero el estado activo" severity failure;

    -- ------------------------------------------------------------------
    -- R12: trama final y TEC intacto
    -- ------------------------------------------------------------------
    report "R12: trama final";
    send("000000000000000000" & "11100011100", '0', '0', x"3",
         x"99AABB0000000000", 0, false, true);
    wrxv("R12");
    assert g_rdat = x"99AABB0000000000"
      report "FALLO: R12 datos incorrectos" severity failure;
    wait for 1 ns;
    assert to_integer(unsigned(g_tec)) = 0
      report "FALLO: R12 TEC alterado sin transmisiones" severity failure;

    -- ------------------------------------------------------------------
    -- R13: CRC sequence ending in a run of 5 -> stuff bit before the CRC
    -- delimiter (ISO 11898-1). id 0x100 / 0x118, data 0x22 (independent
    -- search: CRC 0x5EDF ends in five 1s, 0x46E0 in five 0s)
    -- ------------------------------------------------------------------
    report "R13: bit de stuff tras la secuencia CRC";
    rstn <= '0';
    wait for 100 ns;
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 20 us;
    send("000000000000000000" & "00100000000", '0', '0', x"1",
         x"2200000000000000", 0, false, true);
    wrxv("R13a");
    assert g_rid(10 downto 0) = "00100000000" and g_rdat = x"2200000000000000"
      report "FALLO: R13a trama incorrecta" severity failure;
    send("000000000000000000" & "00100011000", '0', '0', x"1",
         x"2200000000000000", 0, false, true);
    wrxv("R13b");
    assert g_rid(10 downto 0) = "00100011000" and g_rdat = x"2200000000000000"
      report "FALLO: R13b trama incorrecta" severity failure;
    chk_rec(0, "R13");

    -- ------------------------------------------------------------------
    -- R14: receiver detects a dominant 1st bit after its error flag:
    -- REC = +1 (stuff error) +8 (ISO 11898-1 rule 2) = 9
    -- ------------------------------------------------------------------
    report "R14: dominante tras el flag de error del receptor";
    lerr(1, 0);
    chk_rec(9, "R14");

    -- ------------------------------------------------------------------
    -- R15: 8 dominant bits after the flag (14th dominant after an active
    -- flag): REC = +1 +8 (1st bit) +8 (8 consecutive) = 17
    -- ------------------------------------------------------------------
    report "R15: 14 dominantes consecutivos";
    rstn <= '0';
    wait for 100 ns;
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 20 us;
    lerr(8, 0);
    chk_rec(17, "R15");
    -- the engine must still receive normally afterwards (REC - 1)
    send("000000000000000000" & "00100100011", '0', '0', x"1",
         x"5A00000000000000", 0, false, true);
    wrxv("R15 limpia");
    chk_rec(16, "R15 tras la trama limpia");

    -- ------------------------------------------------------------------
    -- R16: dominant bit in the error delimiter (bit 3): form error,
    -- REC +1 and a new error flag
    -- ------------------------------------------------------------------
    report "R16: error de forma en el delimitador de error";
    rstn <= '0';
    wait for 100 ns;
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 20 us;
    lerr(0, 3);
    chk_rec(2, "R16");
    send("000000000000000000" & "00100100011", '0', '0', x"1",
         x"5B00000000000000", 0, false, true);
    wrxv("R16 limpia");
    chk_rec(1, "R16 tras la trama limpia");

    report "CAPA 1b OK: motor CAN receptor contra modelo transmisor bit-bang";
    finish;
  end process;

  wd_p : process
  begin
    wait for 80 ms;
    assert false
      report "FALLO: timeout global del testbench"
      severity failure;
  end process;

end architecture;
