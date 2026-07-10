-- ============================================================================
--  tb_can_mmio.vhd - Capa 2: banco de registros CAN contra un BFM dmem.
--
--  El BFM reproduce el contrato dmem del RV32i: req de 1 ciclo, rdata
--  COMBINACIONAL capturado en el flanco del req (el BFM muestrea en el
--  flanco de bajada intermedio y consuma en la subida). Si rdata fuese
--  registrado, todos los pops y readbacks de este banco fallarian: el
--  contrato queda vigilado desde la capa 2 (leccion del IIC).
--
--  Todo el trafico corre en LOOP_INT (nodos A y B en AND cableado interno),
--  exactamente el self-test que ira en silicio.
--
--  Tests:
--    M1  Readback de configuracion (CTRL, BTR, TXID/TXDLC/TXDH/TXDL)
--    M2  Self-test A->B: GO, stickies TXDONE/RXV, registro de 13 bytes con
--        pop-on-read y VALID, drenaje completo
--    M3  B->A extendida remota
--    M4  Arbitraje A/B simultaneo por registros (ARB_B, ambos sentidos)
--    M5  Sin interlocutor: reintentos con TEC creciente, ABORT, y SELFACK
--        (no conforme) completando sin segundo nodo
--    M6  Overflow del FIFO B (drop-newest por trama + sticky) y drenaje
--    M7  IRQ por nivel: TXDONE_A y watermark de B
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_can_mmio is
end entity;

architecture sim of tb_can_mmio is

  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal sel, we : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq   : std_logic;

  signal can_tx_o, can_tx_t : std_logic;
  signal can_rx_iw : std_logic;

begin

  clk <= not clk after TCLK / 2;
  can_rx_iw <= '1'; -- pads sin uso en loop interno

  dut : entity work.can_mmio
    port map (
      clk => clk, rst => rst,
      sel => sel, we => we, addr => addr, wdata => wdata, rdata => rdata,
      irq => irq,
      can_tx_o => can_tx_o, can_tx_t => can_tx_t, can_rx_i => can_rx_iw
    );

  estimulo : process
    variable d, d2 : std_logic_vector(31 downto 0);
    variable teca  : integer;
    variable frv   : std_logic_vector(103 downto 0);

    procedure tick1 is
    begin
      wait until rising_edge(clk);
    end procedure;

    procedure mwr(a : std_logic_vector(7 downto 0);
                  v : std_logic_vector(31 downto 0)) is
    begin
      sel <= '1'; we <= '1'; addr <= a; wdata <= v;
      tick1;
      sel <= '0'; we <= '0';
    end procedure;

    -- lectura con captura de rdata COMBINACIONAL en el ciclo del req
    procedure mrd(a : std_logic_vector(7 downto 0);
                  v : out std_logic_vector(31 downto 0)) is
    begin
      sel <= '1'; we <= '0'; addr <= a;
      wait until falling_edge(clk);
      v := rdata;
      wait until rising_edge(clk);
      sel <= '0';
    end procedure;

    -- esperar hasta que STAT tenga los bits de mask a uno
    procedure poll_stat(mask : std_logic_vector(31 downto 0);
                        v : out std_logic_vector(31 downto 0);
                        msg : string) is
      variable t : integer := 0;
      variable s : std_logic_vector(31 downto 0);
    begin
      loop
        mrd(x"04", s);
        exit when (s and mask) = mask;
        t := t + 1;
        assert t < 200000
          report "FALLO: timeout esperando STAT en " & msg severity failure;
      end loop;
      v := s;
    end procedure;

    -- leer un registro de trama completo (13 bytes) del FIFO indicado
    procedure rd_frame(a : std_logic_vector(7 downto 0);
                       fr : out std_logic_vector(103 downto 0);
                       msg : string) is
      variable b : std_logic_vector(31 downto 0);
    begin
      for i in 0 to 12 loop
        mrd(a, b);
        assert b(8) = '1'
          report "FALLO: VALID=0 en el byte " & integer'image(i)
                 & " de " & msg
          severity failure;
        fr(103 - 8 * i downto 96 - 8 * i) := b(7 downto 0);
      end loop;
    end procedure;

  begin
    rst <= '1';
    wait for 100 ns;
    tick1;
    rst <= '0';
    tick1;

    -- ------------------------------------------------------------------
    -- M1: readback de configuracion
    -- ------------------------------------------------------------------
    report "M1: readback de configuracion";
    mrd(x"00", d);
    assert d = x"00000000"
      report "FALLO: M1 CTRL por defecto no nulo" severity failure;
    mrd(x"08", d);
    assert d = x"00015C09"
      report "FALLO: M1 BTR por defecto incorrecto" severity failure;
    mwr(x"08", x"00015C00"); -- brp=0: 200 ns/bit para acelerar la capa 2
    mrd(x"08", d);
    assert d = x"00015C00"
      report "FALLO: M1 BTR no acepta escritura" severity failure;
    mwr(x"10", x"40000123");
    mrd(x"10", d);
    assert d = x"40000123"
      report "FALLO: M1 TXID_A readback incorrecto" severity failure;
    mwr(x"10", x"00000123");
    mwr(x"14", x"00000008");
    mwr(x"18", x"01234567");
    mwr(x"1C", x"89ABCDEF");
    mrd(x"18", d);
    mrd(x"1C", d2);
    assert d = x"01234567" and d2 = x"89ABCDEF"
      report "FALLO: M1 TXDH/TXDL readback incorrecto" severity failure;
    mrd(x"24", d);
    assert d(8) = '0'
      report "FALLO: M1 RXFIFO_A vacio con VALID=1" severity failure;

    -- ------------------------------------------------------------------
    -- M2: self-test A -> B en LOOP_INT
    -- ------------------------------------------------------------------
    report "M2: self-test A hacia B";
    mwr(x"00", x"00000083"); -- EN_A | EN_B | LOOP_INT
    mwr(x"20", x"00000001"); -- GO_A
    poll_stat(x"02010000", d, "M2 TXDONE_A y RXV_B");
    assert d(7) = '1'
      report "FALLO: M2 RXNE_B no activo" severity failure;
    assert d(0) = '0'
      report "FALLO: M2 BUSY_A tras el done" severity failure;
    mwr(x"04", x"00000000"); -- limpiar stickies
    mrd(x"50", d);
    assert d(15 downto 8) = x"0D"
      report "FALLO: M2 nivel del FIFO B distinto de 13" severity failure;
      rd_frame(x"44", frv, "M2");
      assert frv(103 downto 96) = x"00" and frv(95 downto 88) = x"00"
        report "FALLO: M2 byte de flags/ID alto incorrecto" severity failure;
      assert frv(87 downto 80) = x"01" and frv(79 downto 72) = x"23"
        report "FALLO: M2 ID bajo incorrecto" severity failure;
      assert frv(71 downto 64) = x"08"
        report "FALLO: M2 DLC incorrecto" severity failure;
      assert frv(63 downto 0) = x"0123456789ABCDEF"
        report "FALLO: M2 datos incorrectos" severity failure;
    mrd(x"44", d);
    assert d(8) = '0'
      report "FALLO: M2 VALID=1 con FIFO drenado" severity failure;
    mrd(x"50", d);
    assert d = x"00000000"
      report "FALLO: M2 niveles no nulos tras drenar" severity failure;

    -- ------------------------------------------------------------------
    -- M3: B -> A extendida remota
    -- ------------------------------------------------------------------
    report "M3: B hacia A extendida remota";
    mwr(x"30", x"75A5A5A5"); -- IDE | RTR | id 0x15A5A5A5
    mwr(x"34", x"00000005");
    mwr(x"40", x"00000001"); -- GO_B
    poll_stat(x"01020000", d, "M3 TXDONE_B y RXV_A");
    mwr(x"04", x"00000000");
      rd_frame(x"24", frv, "M3");
      assert frv(103 downto 96) = x"75"
        report "FALLO: M3 flags/ID alto incorrectos" severity failure;
      assert frv(95 downto 72) = x"A5A5A5"
        report "FALLO: M3 ID bajo incorrecto" severity failure;
      assert frv(71 downto 64) = x"05"
        report "FALLO: M3 DLC incorrecto" severity failure;
      assert frv(63 downto 0) = x"0000000000000000"
        report "FALLO: M3 trama remota con datos" severity failure;

    -- ------------------------------------------------------------------
    -- M4: arbitraje A/B simultaneo
    -- ------------------------------------------------------------------
    report "M4: arbitraje simultaneo por registros";
    mwr(x"10", x"000000F0"); -- A gana (ID menor)
    mwr(x"14", x"00000001");
    mwr(x"18", x"AA000000");
    mwr(x"1C", x"00000000");
    mwr(x"30", x"00000123"); -- B pierde y reintenta
    mwr(x"34", x"00000001");
    mwr(x"38", x"BB000000");
    mwr(x"3C", x"00000000");
    mwr(x"40", x"00000001"); -- GO_B
    mwr(x"20", x"00000001"); -- GO_A (mismo bit: grids alineados)
    poll_stat(x"03030000", d, "M4 dobles TXDONE y RXV");
    assert d(19) = '1'
      report "FALLO: M4 ARB_B no marcado" severity failure;
    assert d(18) = '0'
      report "FALLO: M4 ARB_A marcado indebidamente" severity failure;
    mwr(x"04", x"00000000");
      rd_frame(x"44", frv, "M4 trama de A en B");
      assert frv(79 downto 72) = x"F0" and frv(63 downto 56) = x"AA"
        report "FALLO: M4 trama ganadora incorrecta" severity failure;
      rd_frame(x"24", frv, "M4 trama de B en A");
      assert frv(79 downto 72) = x"23" and frv(63 downto 56) = x"BB"
        report "FALLO: M4 trama de reintento incorrecta" severity failure;

    -- ------------------------------------------------------------------
    -- M5: sin interlocutor -> ABORT -> SELFACK
    -- ------------------------------------------------------------------
    report "M5: sin interlocutor, ABORT y SELFACK";
    mwr(x"00", x"00000081"); -- solo EN_A en loop (B en reset)
    mwr(x"10", x"00000155");
    mwr(x"14", x"00000001");
    mwr(x"18", x"CC000000");
    mwr(x"20", x"00000001"); -- GO_A: nadie asiente
    wait for 60 us;          -- varios reintentos con error de ACK
    mrd(x"28", d);
    teca := to_integer(unsigned(d(8 downto 0)));
    assert teca >= 8
      report "FALLO: M5 TEC de A no crecio sin interlocutor"
      severity failure;
    mrd(x"04", d);
    assert d(20) = '1' and d(22) = '1'
      report "FALLO: M5 stickies TXERR_A/ERR_A no marcados"
      severity failure;
    mwr(x"20", x"00000002"); -- ABORT_A
    wait for 30 us;
    mrd(x"04", d);
    assert d(0) = '0'
      report "FALLO: M5 BUSY_A tras el abort" severity failure;
    mrd(x"28", d);
    teca := to_integer(unsigned(d(8 downto 0)));
    mwr(x"04", x"00000000");
    -- SELFACK: completar sin segundo nodo (documentado NO conforme)
    mwr(x"00", x"00000181"); -- EN_A | LOOP | SELFACK_A
    mwr(x"20", x"00000001"); -- GO_A
    poll_stat(x"00010000", d, "M5 TXDONE_A con selfack");
    mwr(x"04", x"00000000");
    mrd(x"28", d);
    assert to_integer(unsigned(d(8 downto 0))) = teca - 1
      report "FALLO: M5 TEC no decremento con selfack" severity failure;
    mrd(x"50", d);
    assert d(7 downto 0) = x"00"
      report "FALLO: M5 el nodo A recibio su propia trama" severity failure;

    -- ------------------------------------------------------------------
    -- M6: overflow del FIFO B (drop-newest por trama)
    -- ------------------------------------------------------------------
    report "M6: overflow del FIFO B";
    mwr(x"00", x"00000083"); -- EN_A | EN_B | LOOP
    mwr(x"10", x"00000100");
    mwr(x"14", x"00000002");
    mwr(x"1C", x"00000000");
    for i in 1 to 10 loop
      mwr(x"04", x"00000000"); -- limpiar antes del GO: el RXOVF de la
                               -- trama descartada llega antes del TXDONE
      mwr(x"18", std_logic_vector(to_unsigned(i, 8)) & x"110000");
      mwr(x"20", x"00000001");
      poll_stat(x"00010000", d, "M6 trama " & integer'image(i));
    end loop;
    mrd(x"50", d);
    assert d(15 downto 8) = x"75"
      report "FALLO: M6 nivel del FIFO B distinto de 117" severity failure;
    mrd(x"04", d);
    assert d(27) = '1'
      report "FALLO: M6 sticky RXOVF_B no marcado" severity failure;
    mwr(x"04", x"00000000");
      for i in 1 to 9 loop
        rd_frame(x"44", frv, "M6 drenaje " & integer'image(i));
        assert frv(63 downto 56) = std_logic_vector(to_unsigned(i, 8))
          report "FALLO: M6 orden de tramas incorrecto en la "
                 & integer'image(i)
          severity failure;
      end loop;
    mrd(x"44", d);
    assert d(8) = '0'
      report "FALLO: M6 VALID=1 tras drenar las 9 tramas" severity failure;

    -- ------------------------------------------------------------------
    -- M7: IRQ por nivel (TXDONE_A y watermark de B)
    -- ------------------------------------------------------------------
    report "M7: IRQ por nivel";
    assert irq = '0'
      report "FALLO: M7 IRQ activa sin enables" severity failure;
    mwr(x"54", x"00000001"); -- habilitar TXDONE_A
    mwr(x"10", x"00000100");
    mwr(x"14", x"00000000");
    mwr(x"20", x"00000001");
    poll_stat(x"00010000", d, "M7 TXDONE_A");
    wait for 1 ns;
    assert irq = '1'
      report "FALLO: M7 IRQ no subio con TXDONE_A" severity failure;
    mwr(x"04", x"00000000");
    tick1;
    wait for 1 ns;
    assert irq = '0'
      report "FALLO: M7 IRQ no bajo al limpiar stickies" severity failure;
    -- watermark del FIFO B
    mwr(x"54", x"00008000"); -- habilitar WMHIT_B
    mwr(x"5C", x"00000D00"); -- WM_B = 13
    mwr(x"20", x"00000001");
    poll_stat(x"00010000", d, "M7 trama para watermark");
    mwr(x"04", x"00000000");
    wait for 1 ns;
    assert irq = '1'
      report "FALLO: M7 IRQ no subio con el watermark de B" severity failure;
      rd_frame(x"44", frv, "M7 drenaje");
      rd_frame(x"44", frv, "M7 drenaje 2");
    wait for 1 ns;
    assert irq = '0'
      report "FALLO: M7 IRQ no bajo al drenar el FIFO B" severity failure;

    report "CAPA 2 OK: can_mmio contra BFM dmem";
    finish;
  end process;

  wd_p : process
  begin
    wait for 20 ms;
    assert false
      report "FALLO: timeout global del testbench"
      severity failure;
  end process;

end architecture;
