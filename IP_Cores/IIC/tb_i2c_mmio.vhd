-- ============================================================================
--  tb_i2c_mmio.vhd — Capa 2: regfile MMIO con BFM dmem
--
--  BFM del bus dmem (contrato: req dura exactamente 1 ciclo, rdata
--  registrado válido al ciclo siguiente). FIFO_LOG2=4 (16 bytes) para casos
--  de borde rápidos, como el tb_usart_mmio. Todo el tráfico I2C corre en
--  LOOP_INT: los dos motores por el wired-AND interno del propio mmio, con
--  los pads liberados — exactamente el self-test de silicio.
--
--  M1:  defaults tras reset (SCLDIV=249, stickies 0, causa STX_WM viva)
--  M2:  configuración + escritura loop maestro->esclavo, SRX pop-on-read
--  M3:  lectura loop con STX precargado, MRD y consumo FWFT
--  M4:  NACK sticky (dirección ajena) + cierre NOBYTE
--  M5:  CMD_DROP (segundo CMD con el maestro ocupado)
--  M6:  IRQ por nivel: causa MDONE (set y clear por STAT) y causa SRX_WM
--  M7:  overflow SRX extremo a extremo: 17 bytes contra FIFO de 16
--       (NACK + SRX_OVF en el mismo done) + drenado completo verificado
--  M8:  pads liberados durante una transacción en LOOP_INT
--  M9:  ganchos DMA: push por dma_stx, pop por dma_srx (espejo FWFT)
--  M10: overflow STX por CPU: drop-newest + sticky, nivel intacto
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_i2c_mmio is
end entity;

architecture sim of tb_i2c_mmio is

  constant TCLK : time := 10 ns;                    -- 100 MHz

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal sel, req : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0)  := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq   : std_logic;

  signal dma_srx_ren   : std_logic := '0';
  signal dma_srx_data  : std_logic_vector(7 downto 0);
  signal dma_srx_empty : std_logic;
  signal dma_stx_wen   : std_logic := '0';
  signal dma_stx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal dma_stx_full  : std_logic;

  signal scl_t, sda_t : std_logic;

  -- offsets
  constant A_CTRL   : std_logic_vector(7 downto 0) := x"00";
  constant A_STAT   : std_logic_vector(7 downto 0) := x"04";
  constant A_SCLDIV : std_logic_vector(7 downto 0) := x"08";
  constant A_CMD    : std_logic_vector(7 downto 0) := x"0C";
  constant A_MRD    : std_logic_vector(7 downto 0) := x"10";
  constant A_SADDR  : std_logic_vector(7 downto 0) := x"14";
  constant A_STX    : std_logic_vector(7 downto 0) := x"18";
  constant A_SRX    : std_logic_vector(7 downto 0) := x"1C";
  constant A_LVL    : std_logic_vector(7 downto 0) := x"20";
  constant A_IRQEN  : std_logic_vector(7 downto 0) := x"24";
  constant A_IRQST  : std_logic_vector(7 downto 0) := x"28";
  constant A_WM     : std_logic_vector(7 downto 0) := x"2C";

  -- bits de CMD
  constant C_START : std_logic_vector(31 downto 0) := x"00000100";
  constant C_STOP  : std_logic_vector(31 downto 0) := x"00000200";
  constant C_READ  : std_logic_vector(31 downto 0) := x"00000400";
  constant C_ACKN  : std_logic_vector(31 downto 0) := x"00000800";
  constant C_NOB   : std_logic_vector(31 downto 0) := x"00001000";

begin

  clk <= not clk after TCLK / 2;

  dut : entity work.i2c_mmio
    generic map ( FIFO_LOG2 => 4 )                  -- 16 bytes: bordes rápidos
    port map (
      clk => clk, rst => rst,
      sel => sel, req => req, addr => addr,
      wdata => wdata, wstrb => wstrb, rdata => rdata,
      irq => irq,
      dma_srx_ren => dma_srx_ren, dma_srx_data => dma_srx_data,
      dma_srx_empty => dma_srx_empty,
      dma_stx_wen => dma_stx_wen, dma_stx_data => dma_stx_data,
      dma_stx_full => dma_stx_full,
      scl_i => '1', scl_t => scl_t,
      sda_i => '1', sda_t => sda_t
    );

  watchdog : process
  begin
    wait for 10 ms;
    assert false
      report "WATCHDOG: la simulacion no termino a tiempo (cuelgue probable)"
      severity failure;
  end process;

  stim : process
    variable d, s : std_logic_vector(31 downto 0);
    variable w    : std_logic_vector(31 downto 0);

    procedure reg_wr(constant a : in std_logic_vector(7 downto 0);
                     constant v : in std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel   <= '1';
      req   <= '1';
      addr  <= a;
      wdata <= v;
      wstrb <= "1111";
      wait until rising_edge(clk);
      sel   <= '0';
      req   <= '0';
      wstrb <= "0000";
    end procedure;

    procedure reg_rd(constant a : in std_logic_vector(7 downto 0);
                     variable v : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel   <= '1';
      req   <= '1';
      addr  <= a;
      wstrb <= "0000";
      wait until rising_edge(clk);       -- el DUT muestrea req en este flanco
      v := rdata;                        -- captura PRE-pop, igual que el core
      sel   <= '0';
      req   <= '0';
    end procedure;

    -- comando al maestro: dispara, espera MDONE, devuelve STAT y limpia
    procedure mcmd(constant v : in std_logic_vector(31 downto 0);
                   variable stat_out : out std_logic_vector(31 downto 0)) is
      variable t : std_logic_vector(31 downto 0);
    begin
      reg_wr(A_CMD, v);
      loop
        reg_rd(A_STAT, t);
        exit when t(16) = '1';           -- MDONE
        wait for 200 ns;
      end loop;
      stat_out := t;
      reg_wr(A_STAT, (others => '0'));   -- limpia stickies
    end procedure;

  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 100 ns;

    ------------------------------------------------------------------ M1
    report "M1: defaults tras reset";
    reg_rd(A_CTRL, d);
    assert d = x"00000000"
      report "M1: CTRL no arranca en 0" severity failure;
    reg_rd(A_SCLDIV, d);
    assert d = x"000000F9"
      report "M1: SCLDIV default no es 249 (100 kHz)" severity failure;
    reg_rd(A_LVL, d);
    assert d = x"00000000"
      report "M1: niveles de FIFO no arrancan en 0" severity failure;
    reg_rd(A_STAT, d);
    assert (d and x"01FF0000") = x"00000000"
      report "M1: hay stickies encendidos tras reset" severity failure;
    assert d(5) = '1' and d(7) = '1' and d(6) = '0' and d(8) = '0'
      report "M1: vivos de FIFO incorrectos (deben estar vacios)" severity failure;
    reg_rd(A_IRQST, d);
    assert d(7) = '1'
      report "M1: causa STX_WM debe estar viva con FIFO vacio y WM=0"
      severity failure;
    assert d(6 downto 0) = "0000000"
      report "M1: causas 0-6 deben estar apagadas tras reset" severity failure;
    assert irq = '0'
      report "M1: irq debe ser 0 con IRQ_EN=0" severity failure;

    ------------------------------------------------------------------ M2
    report "M2: configuracion + escritura loop maestro->esclavo";
    reg_wr(A_CTRL,   x"00000087");       -- EN|SEN|STRETCH|LOOP_INT
    reg_wr(A_SCLDIV, x"00000018");       -- 24 -> 1 MHz (sim rapida)
    reg_wr(A_SADDR,  x"0000002A");
    reg_rd(A_CTRL, d);
    assert d = x"00000087"
      report "M2: readback de CTRL incorrecto" severity failure;
    reg_rd(A_SADDR, d);
    assert d = x"0000002A"
      report "M2: readback de SADDR incorrecto" severity failure;

    mcmd(C_START or x"00000054", s);     -- START + addr 0x2A/W
    assert s(18) = '0'
      report "M2: la direccion propia recibio NACK en loop" severity failure;
    assert s(21) = '1'
      report "M2: START_DET no quedo pegajoso" severity failure;
    mcmd(x"00000011", s);
    mcmd(C_STOP or x"00000022", s);
    assert s(22) = '1'
      report "M2: STOP_DET no quedo pegajoso" severity failure;

    reg_rd(A_LVL, d);
    assert unsigned(d(8 downto 0)) = 2
      report "M2: el FIFO SRX no tiene exactamente 2 bytes" severity failure;
    reg_rd(A_SRX, d);
    assert d(8) = '1' and d(7 downto 0) = x"11"
      report "M2: primer pop de SRX incorrecto" severity failure;
    reg_rd(A_SRX, d);
    assert d(8) = '1' and d(7 downto 0) = x"22"
      report "M2: segundo pop de SRX incorrecto" severity failure;
    reg_rd(A_SRX, d);
    assert d(8) = '0'
      report "M2: SRX vacio debe leer VALID=0" severity failure;

    ------------------------------------------------------------------ M3
    report "M3: lectura loop con STX precargado";
    reg_wr(A_STX, x"000000DE");
    reg_wr(A_STX, x"000000AD");
    reg_rd(A_LVL, d);
    assert unsigned(d(24 downto 16)) = 2
      report "M3: el FIFO STX no tiene exactamente 2 bytes" severity failure;
    mcmd(C_START or x"00000055", s);     -- START + addr 0x2A/R
    assert s(18) = '0'
      report "M3: la direccion de lectura recibio NACK" severity failure;
    mcmd(C_READ, s);                     -- leer con ACK
    reg_rd(A_MRD, d);
    assert d(7 downto 0) = x"DE"
      report "M3: MRD del primer byte no es 0xDE" severity failure;
    mcmd(C_READ or C_ACKN or C_STOP, s); -- leer con NACK + STOP
    reg_rd(A_MRD, d);
    assert d(7 downto 0) = x"AD"
      report "M3: MRD del segundo byte no es 0xAD" severity failure;
    reg_rd(A_LVL, d);
    assert unsigned(d(24 downto 16)) = 0
      report "M3: el FIFO STX no quedo vacio (consumo FWFT)" severity failure;

    ------------------------------------------------------------------ M4
    report "M4: NACK sticky con direccion ajena + cierre NOBYTE";
    mcmd(C_START or x"00000066", s);     -- addr 0x33/W: nadie en casa
    assert s(18) = '1'
      report "M4: NACK sticky no se armo" severity failure;
    mcmd(C_NOB or C_STOP, s);
    reg_rd(A_STAT, d);
    assert d(2) = '0' and d(1) = '0'
      report "M4: el bus no quedo libre tras el STOP puro" severity failure;

    ------------------------------------------------------------------ M5
    report "M5: CMD_DROP con el maestro ocupado";
    reg_wr(A_CMD, C_START or x"00000054");
    reg_wr(A_CMD, x"00000011");          -- cae: maestro ocupado
    loop
      reg_rd(A_STAT, d);
      exit when d(16) = '1';
      wait for 200 ns;
    end loop;
    assert d(23) = '1'
      report "M5: CMD_DROP no quedo pegajoso" severity failure;
    reg_wr(A_STAT, (others => '0'));
    mcmd(C_STOP or x"00000033", s);      -- cerrar la transaccion abierta
    reg_rd(A_SRX, d);
    assert d(8) = '1' and d(7 downto 0) = x"33"
      report "M5: el byte tras el drop no llego al esclavo" severity failure;

    ------------------------------------------------------------------ M6
    report "M6: IRQ por nivel: MDONE y SRX_WM";
    reg_wr(A_IRQEN, x"00000001");        -- causa MDONE
    reg_wr(A_CMD, C_NOB);                -- NOBYTE desde IDLE: done inmediato
    wait for 300 ns;
    assert irq = '1'
      report "M6: irq no subio con MDONE habilitado" severity failure;
    reg_rd(A_IRQST, d);
    assert d(0) = '1'
      report "M6: IRQ_STAT no refleja la causa MDONE" severity failure;
    reg_wr(A_STAT, (others => '0'));
    wait for 100 ns;
    assert irq = '0'
      report "M6: irq no bajo tras limpiar stickies (es por nivel)"
      severity failure;
    reg_wr(A_IRQEN, x"00000040");        -- causa SRX_WM (WM default = 1)
    wait for 100 ns;
    assert irq = '0'
      report "M6: irq debe estar en 0 con SRX vacio" severity failure;
    mcmd(C_START or x"00000054", s);
    mcmd(C_STOP or x"00000044", s);
    wait for 100 ns;
    assert irq = '1'
      report "M6: irq no subio con SRX en el watermark" severity failure;
    reg_rd(A_SRX, d);
    assert d(7 downto 0) = x"44"
      report "M6: el byte del watermark no es 0x44" severity failure;
    wait for 100 ns;
    assert irq = '0'
      report "M6: irq no bajo tras vaciar SRX (es por nivel)" severity failure;
    reg_wr(A_IRQEN, x"00000000");

    ------------------------------------------------------------------ M7
    report "M7: overflow SRX extremo a extremo (17 bytes contra 16)";
    mcmd(C_START or x"00000054", s);
    for i in 0 to 16 loop
      w := (others => '0');
      w(7 downto 0) := std_logic_vector(to_unsigned(16#E0# + i, 8));
      mcmd(w, s);
    end loop;
    -- el byte 17 (0xF0) debio recibir NACK del esclavo por FIFO lleno
    assert s(18) = '1'
      report "M7: el byte 17 no recibio NACK" severity failure;
    assert s(19) = '1'
      report "M7: SRX_OVF no quedo pegajoso" severity failure;
    mcmd(C_NOB or C_STOP, s);
    reg_rd(A_LVL, d);
    assert unsigned(d(8 downto 0)) = 16
      report "M7: el FIFO SRX no quedo exactamente lleno (16)" severity failure;
    reg_rd(A_STAT, d);
    assert d(6) = '1'
      report "M7: STAT.SRX_FULL no esta vivo" severity failure;
    for i in 0 to 15 loop
      reg_rd(A_SRX, d);
      assert d(8) = '1' and
             d(7 downto 0) = std_logic_vector(to_unsigned(16#E0# + i, 8))
        report "M7: byte drenado numero " & integer'image(i) & " incorrecto"
        severity failure;
    end loop;
    reg_rd(A_SRX, d);
    assert d(8) = '0'
      report "M7: el drenado 17 debe leer VALID=0" severity failure;

    ------------------------------------------------------------------ M8
    report "M8: pads liberados durante una transaccion en LOOP_INT";
    reg_wr(A_CMD, C_START or x"00000054");
    wait for 3 us;                       -- a media transaccion
    assert scl_t = '1' and sda_t = '1'
      report "M8: los pads no estan liberados en LOOP_INT" severity failure;
    loop
      reg_rd(A_STAT, d);
      exit when d(16) = '1';
      wait for 200 ns;
    end loop;
    reg_wr(A_STAT, (others => '0'));
    mcmd(C_STOP or x"00000055", s);
    reg_rd(A_SRX, d);
    assert d(8) = '1' and d(7 downto 0) = x"55"
      report "M8: el byte de la transaccion M8 no llego" severity failure;

    ------------------------------------------------------------------ M9
    report "M9: ganchos DMA (push STX, pop SRX espejo FWFT)";
    wait until rising_edge(clk);
    dma_stx_data <= x"77";
    dma_stx_wen  <= '1';
    wait until rising_edge(clk);
    dma_stx_wen  <= '0';
    reg_rd(A_LVL, d);
    assert unsigned(d(24 downto 16)) = 1
      report "M9: el push DMA no entro al FIFO STX" severity failure;
    mcmd(C_START or x"00000055", s);     -- addr 0x2A/R
    mcmd(C_READ or C_ACKN or C_STOP, s);
    reg_rd(A_MRD, d);
    assert d(7 downto 0) = x"77"
      report "M9: el maestro no leyo el byte del push DMA" severity failure;
    mcmd(C_START or x"00000054", s);
    mcmd(C_STOP or x"00000088", s);
    wait for 1 us;
    assert dma_srx_empty = '0'
      report "M9: dma_srx_empty deberia estar en 0 con un byte" severity failure;
    assert dma_srx_data = x"88"
      report "M9: dma_srx_data no espeja la cabeza FWFT (0x88)" severity failure;
    wait until rising_edge(clk);
    dma_srx_ren <= '1';
    wait until rising_edge(clk);
    dma_srx_ren <= '0';
    wait for 1 ns;
    assert dma_srx_empty = '1'
      report "M9: el pop DMA no vacio el FIFO SRX" severity failure;

    ------------------------------------------------------------------ M10
    report "M10: overflow STX por CPU (drop-newest + sticky)";
    for i in 0 to 15 loop
      w := (others => '0');
      w(7 downto 0) := std_logic_vector(to_unsigned(16#A0# + i, 8));
      reg_wr(A_STX, w);
    end loop;
    reg_rd(A_LVL, d);
    assert unsigned(d(24 downto 16)) = 16
      report "M10: el FIFO STX no quedo lleno con 16 bytes" severity failure;
    reg_rd(A_STAT, d);
    assert d(8) = '1'
      report "M10: STAT.STX_FULL no esta vivo" severity failure;
    reg_wr(A_STX, x"000000FF");          -- 17: drop-newest
    reg_rd(A_STAT, d);
    assert d(24) = '1'
      report "M10: STX_OVF no quedo pegajoso" severity failure;
    reg_rd(A_LVL, d);
    assert unsigned(d(24 downto 16)) = 16
      report "M10: el drop-newest altero el nivel del FIFO" severity failure;

    report "== TODOS LOS TESTS PASARON (M1-M10) ==";
    finish;
  end process;

end architecture sim;
