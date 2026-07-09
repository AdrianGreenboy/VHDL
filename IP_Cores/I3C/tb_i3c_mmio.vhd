-- ============================================================================
--  tb_i3c_mmio.vhd - Capa 2: banco de registros contra un BFM dmem.
--
--  El BFM reproduce el contrato dmem del RV32i: req de 1 ciclo, rdata
--  COMBINACIONAL capturado en el flanco del req (el BFM muestrea en el
--  flanco de bajada intermedio y consuma en la subida). Si rdata fuese
--  registrado, todos los pops y readbacks de este banco fallarian: el
--  contrato queda vigilado desde la capa 2, que fue la leccion del IIC.
--
--  Todo el trafico I3C corre en LOOP_INT (controller y target internos
--  cableados), que es exactamente el self-test que ira en silicio.
--
--  Tests:
--    W1  Readback de configuracion (SCLDIV, TCFG, PID, BCR/DCR/MDB, TSTATW)
--    W2  ENTDAA completo por registros: CMD/STAT/RX/TDA, ronda NACK, STOP
--    W3  Escritura privada -> FIFO TRX con pop-on-read y VALID
--    W4  Lectura privada: TTX -> CMD READ/RLAST -> RX, t_bit en STAT
--    W5  IBI por TREQ: IRQ por nivel, IBIADDR, ibiack, MDB, sticky T_IBIDONE
--    W6  Watermark de TRX como IRQ y overflow de TTX (drop-newest + sticky)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i3c_mmio is
end entity;

architecture sim of tb_i3c_mmio is

  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal sel, we : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq   : std_logic;

  signal scl_o, scl_t, sda_o, sda_t : std_logic;
  signal scl_iw, sda_iw : std_logic;

  constant TGT_PID : std_logic_vector(47 downto 0) := x"045967ABCDEF";
  constant TGT_BCR : std_logic_vector(7 downto 0)  := x"46";
  constant TGT_DCR : std_logic_vector(7 downto 0)  := x"C6";
  constant TGT_MDB : std_logic_vector(7 downto 0)  := x"9C";
  constant PAY : std_logic_vector(63 downto 0) := TGT_PID & TGT_BCR & TGT_DCR;

begin

  clk <= not clk after TCLK / 2;

  -- pads sin uso en loop interno: entradas en reposo alto
  scl_iw <= '1';
  sda_iw <= '1';

  dut : entity work.i3c_mmio
    port map (
      clk => clk, rst => rst,
      sel => sel, we => we, addr => addr, wdata => wdata, rdata => rdata,
      irq => irq,
      scl_o => scl_o, scl_t => scl_t, scl_i => scl_iw,
      sda_o => sda_o, sda_t => sda_t, sda_i => sda_iw
    );

  estimulo : process
    variable d : std_logic_vector(31 downto 0);

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

    procedure cmdw(v : std_logic_vector(31 downto 0)) is
    begin
      mwr(x"0C", v);
    end procedure;

    procedure poll_done(v : out std_logic_vector(31 downto 0);
                        msg : string) is
      variable t : integer := 0;
      variable s : std_logic_vector(31 downto 0);
    begin
      loop
        mrd(x"04", s);
        exit when s(16) = '1';
        t := t + 1;
        assert t < 200000
          report "TIMEOUT esperando DONE: " & msg severity failure;
      end loop;
      mwr(x"04", x"00000000");                       -- limpiar stickies
      v := s;
    end procedure;

    -- variante sin limpieza: para inspeccionar stickies que llegan unos
    -- ciclos despues del DONE (el 2FF del otro extremo va por detras)
    procedure poll_done_nc(msg : string) is
      variable t : integer := 0;
      variable s : std_logic_vector(31 downto 0);
    begin
      loop
        mrd(x"04", s);
        exit when s(16) = '1';
        t := t + 1;
        assert t < 200000
          report "TIMEOUT esperando DONE: " & msg severity failure;
      end loop;
    end procedure;

  begin
    rst <= '1';
    wait for 200 ns;
    tick1;
    rst <= '0';
    wait for 100 ns;

    -- ------------------------------------------------------------ W1
    report "W1: readback de configuracion";
    mwr(x"08", x"000A0005");
    mrd(x"08", d);
    assert d = x"000A0005"
      report "FALLO W1: readback de SCLDIV incorrecto" severity failure;
    mwr(x"08", x"00090004");
    mwr(x"18", x"00000052");
    mrd(x"18", d);
    assert d(6 downto 0) = "1010010"
      report "FALLO W1: readback de TCFG incorrecto" severity failure;
    mwr(x"1C", x"67ABCDEF");
    mwr(x"20", x"00000459");
    mrd(x"1C", d);
    assert d = x"67ABCDEF"
      report "FALLO W1: readback de TPIDL incorrecto" severity failure;
    mrd(x"20", d);
    assert d = x"00000459"
      report "FALLO W1: readback de TPIDH incorrecto" severity failure;
    mwr(x"24", x"009CC646");
    mrd(x"24", d);
    assert d = x"009CC646"
      report "FALLO W1: readback de TBDCR incorrecto" severity failure;
    mwr(x"28", x"00001234");
    mrd(x"28", d);
    assert d = x"00001234"
      report "FALLO W1: readback de TSTATW incorrecto" severity failure;

    -- ------------------------------------------------------------ W2
    report "W2: ENTDAA completo por registros (LOOP_INT)";
    mwr(x"00", x"00000083");                         -- EN | TEN | LOOP_INT
    cmdw(x"000001FC");                               -- START + 0x7E/W
    poll_done(d, "W2 header 0x7E/W");
    assert d(3) = '0'
      report "FALLO W2: el broadcast 0x7E/W no recibio ACK" severity failure;
    cmdw(x"00000007");                               -- CCC ENTDAA
    poll_done(d, "W2 CCC ENTDAA");
    cmdw(x"00002000");                               -- DAA
    poll_done(d, "W2 ronda ENTDAA");
    assert d(3) = '0'
      report "FALLO W2: la ronda ENTDAA no recibio ACK" severity failure;
    mrd(x"40", d);
    assert d(5 downto 0) = "001000"
      report "FALLO W2: la FIFO RX no tiene 8 bytes" severity failure;
    for i in 0 to 7 loop
      mrd(x"10", d);
      assert d(8) = '1'
        report "FALLO W2: pop " & integer'image(i) & " sin VALID"
        severity failure;
      assert d(7 downto 0) = PAY(63 - 8*i downto 56 - 8*i)
        report "FALLO W2: byte " & integer'image(i) &
               " del payload no coincide" severity failure;
    end loop;
    mrd(x"10", d);
    assert d(8) = '0'
      report "FALLO W2: la FIFO RX debia quedar vacia" severity failure;
    cmdw(x"00004060");                               -- DAADR con DA 0x30
    poll_done_nc("W2 asignacion de DA");
    wait for 200 ns;
    mrd(x"04", d);
    assert d(3) = '0'
      report "FALLO W2: la DA asignada no recibio ACK" severity failure;
    assert d(19) = '1'
      report "FALLO W2: no se registro el sticky T_EVDA" severity failure;
    mwr(x"04", x"00000000");
    mrd(x"2C", d);
    assert d(8) = '1' and d(6 downto 0) = "0110000"
      report "FALLO W2: TDA no refleja la DA 0x30" severity failure;
    cmdw(x"00002000");
    poll_done(d, "W2 segunda ronda");
    assert d(3) = '1'
      report "FALLO W2: la segunda ronda debia terminar en NACK"
      severity failure;
    cmdw(x"00001200");                               -- STOP sin byte
    poll_done(d, "W2 STOP");

    -- ------------------------------------------------------------ W3
    report "W3: escritura privada hacia la FIFO TRX";
    cmdw(x"000001FC");
    poll_done(d, "W3 header 0x7E/W");
    cmdw(x"00000160");                               -- Sr + DA 0x30/W
    poll_done(d, "W3 Sr DA/W");
    assert d(3) = '0'
      report "FALLO W3: DA/W sin ACK" severity failure;
    cmdw(x"000000A5");
    poll_done(d, "W3 dato 1");
    cmdw(x"0000023C");                               -- dato 2 + STOP
    poll_done(d, "W3 dato 2 + STOP");
    mrd(x"40", d);
    assert d(21 downto 16) = "000010"
      report "FALLO W3: la FIFO TRX no tiene 2 bytes" severity failure;
    mrd(x"3C", d);
    assert d(8) = '1' and d(7 downto 0) = x"A5"
      report "FALLO W3: primer byte de TRX incorrecto" severity failure;
    mrd(x"3C", d);
    assert d(8) = '1' and d(7 downto 0) = x"3C"
      report "FALLO W3: segundo byte de TRX incorrecto" severity failure;
    mrd(x"3C", d);
    assert d(8) = '0'
      report "FALLO W3: TRX debia quedar vacia" severity failure;

    -- ------------------------------------------------------------ W4
    report "W4: lectura privada via TTX y RX";
    mwr(x"38", x"00000011");
    mwr(x"38", x"00000022");
    mwr(x"38", x"00000033");
    mwr(x"38", x"00000044");                         -- 4to byte: el seize ve T=1
    mrd(x"40", d);
    assert d(13 downto 8) = "000100"
      report "FALLO W4: la FIFO TTX no tiene 4 bytes" severity failure;
    cmdw(x"000001FC");
    poll_done(d, "W4 header 0x7E/W");
    cmdw(x"00000161");                               -- Sr + DA 0x30/R
    poll_done(d, "W4 Sr DA/R");
    assert d(3) = '0'
      report "FALLO W4: DA/R sin ACK" severity failure;
    cmdw(x"00000400");                               -- READ
    poll_done(d, "W4 byte 0");
    assert d(4) = '1'
      report "FALLO W4: T del byte 0 deberia ser 1" severity failure;
    mrd(x"10", d);
    assert d(8) = '1' and d(7 downto 0) = x"11"
      report "FALLO W4: byte 0 incorrecto" severity failure;
    cmdw(x"00000400");
    poll_done(d, "W4 byte 1");
    mrd(x"10", d);
    assert d(8) = '1' and d(7 downto 0) = x"22"
      report "FALLO W4: byte 1 incorrecto" severity failure;
    cmdw(x"00000E00");                               -- READ | RLAST | STOP
    poll_done(d, "W4 byte 2 con rlast+stop");
    assert d(4) = '1'
      report "FALLO W4: T del byte 2 deberia ser 1 (seize)" severity failure;
    mrd(x"10", d);
    assert d(8) = '1' and d(7 downto 0) = x"33"
      report "FALLO W4: byte 2 incorrecto" severity failure;

    -- ------------------------------------------------------------ W5
    report "W5: IBI por TREQ con IRQ por nivel";
    mwr(x"44", x"00000004");                         -- IRQ_EN: IBI_REQ (nivel)
    mwr(x"34", x"00000001");                         -- TREQ: IBI_GO
    d := (others => '0');
    for i in 0 to 200000 loop
      mrd(x"04", d);
      exit when d(2) = '1';
      assert i < 199999
        report "TIMEOUT esperando IBI_REQ en STAT" severity failure;
    end loop;
    assert irq = '1'
      report "FALLO W5: la IRQ por nivel no se levanto con IBI_REQ"
      severity failure;
    mrd(x"14", d);
    assert d(7 downto 0) = x"61"
      report "FALLO W5: IBIADDR no es DA/R" severity failure;
    cmdw(x"00008000");                               -- IBIACK
    poll_done(d, "W5 ibiack");
    wait for 500 ns;
    assert irq = '0'
      report "FALLO W5: la IRQ no cayo tras el ibiack" severity failure;
    cmdw(x"00000400");                               -- READ del MDB
    poll_done(d, "W5 mandatory byte");
    assert d(4) = '0'
      report "FALLO W5: el MDB debia terminar con T=0" severity failure;
    assert d(22) = '1'
      report "FALLO W5: no se registro el sticky T_IBIDONE" severity failure;
    mrd(x"10", d);
    assert d(8) = '1' and d(7 downto 0) = TGT_MDB
      report "FALLO W5: mandatory byte incorrecto" severity failure;
    cmdw(x"00001200");                               -- STOP
    poll_done(d, "W5 STOP");
    mrd(x"04", d);
    assert d(22) = '0'
      report "FALLO W5: el sticky T_IBIDONE no quedo limpio" severity failure;

    -- ------------------------------------------------------------ W6
    report "W6: watermark de TRX y overflow de TTX";
    mwr(x"4C", x"00000200");                         -- WM: TRX >= 2
    mwr(x"44", x"00000020");                         -- IRQ_EN: TRX watermark
    cmdw(x"000001FC");
    poll_done(d, "W6 header 0x7E/W");
    cmdw(x"00000160");
    poll_done(d, "W6 Sr DA/W");
    cmdw(x"00000055");
    poll_done(d, "W6 dato 1");
    cmdw(x"000002AA");
    poll_done(d, "W6 dato 2 + STOP");
    wait for 200 ns;
    assert irq = '1'
      report "FALLO W6: la IRQ de watermark TRX no se levanto"
      severity failure;
    mrd(x"3C", d);
    mrd(x"3C", d);
    wait for 100 ns;
    assert irq = '0'
      report "FALLO W6: la IRQ de watermark no cayo tras vaciar TRX"
      severity failure;
    for i in 0 to 32 loop
      mwr(x"38", std_logic_vector(to_unsigned(i, 32)));
    end loop;
    mrd(x"40", d);
    assert d(13 downto 8) = "100000"
      report "FALLO W6: TTX debia saturar en 32" severity failure;
    mrd(x"04", d);
    assert d(26) = '1'
      report "FALLO W6: el overflow de TTX no dejo sticky" severity failure;
    mwr(x"04", x"00000000");
    mrd(x"04", d);
    assert d(26) = '0'
      report "FALLO W6: el sticky de overflow no quedo limpio"
      severity failure;

    report "CAPA 2 COMPLETA: TODOS LOS TESTS DEL MMIO I3C PASARON";
    finish;
  end process estimulo;

  vigilante : process
  begin
    wait for 20 ms;
    assert false
      report "TIMEOUT GLOBAL: la simulacion no termino" severity failure;
  end process;

end architecture sim;
