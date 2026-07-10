-- ============================================================================
-- tb_spw_2.vhd -- Capa 2: banco de registros MMIO contra BFM del bus dmem
-- ============================================================================
-- El BFM impone el contrato del RV32: req de exactamente 1 ciclo, rdata
-- muestreado COMBINACIONALMENTE dentro del ciclo de req, pop-on-read.
-- Fases:
--   A: valores de reset          B: escritura/lectura de registros RW
--   C: contabilidad del FIFO TX y TX_FLUSH con el enlace parado
--   D: bring-up en LOOP_INT hasta Run, sticky RUNOK y limpieza de stickies
--   E: datos + EOP + EEP en loopback, pop-on-read con VALID
--   F: aislamiento del pop (leer otros registros no consume RX)
--   G: time-codes: valor, contador, sticky TICK y limpieza
--   H: RX_FLUSH con datos presentes
--   I: IRQ por nivel con mascara sobre STAT (RX_AVAIL y TICK)
--   J: parcheo de DIV a 50 Mbit/s y re-arranque
--   K: avalancha TX: sticky TXOVF, backpressure por creditos a traves del
--      MMIO y verificacion de prefijo integro y ordenado
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_spw_2 is
end entity tb_spw_2;

architecture tb of tb_spw_2 is

  constant A_CTRL  : std_logic_vector(7 downto 0) := x"00";
  constant A_DIV   : std_logic_vector(7 downto 0) := x"04";
  constant A_CMD   : std_logic_vector(7 downto 0) := x"08";
  constant A_TIME  : std_logic_vector(7 downto 0) := x"0C";
  constant A_STAT  : std_logic_vector(7 downto 0) := x"10";
  constant A_TXD   : std_logic_vector(7 downto 0) := x"14";
  constant A_RXD   : std_logic_vector(7 downto 0) := x"18";
  constant A_IRQEN : std_logic_vector(7 downto 0) := x"1C";

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal sel   : std_logic := '0';
  signal we    : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq   : std_logic;
  signal din, sin, dout, sout : std_logic;

  signal done : boolean := false;

begin

  clk <= not clk after 5 ns when not done else '0';

  -- pads externos sin actividad (el auto-test usa LOOP_INT)
  din <= '0';
  sin <= '0';

  dut : entity work.spw_mmio
    port map (
      clk => clk, rst => rst,
      sel => sel, we => we, addr => addr, wdata => wdata, rdata => rdata,
      irq => irq,
      din => din, sin => sin, dout => dout, sout => sout
    );

  watchdog : process
  begin
    wait for 5 ms;
    assert false report "FALLO: timeout global del testbench" severity failure;
  end process watchdog;

  stim : process
    variable d  : std_logic_vector(31 downto 0);
    variable n    : integer;
    variable last : integer;
    variable ok : boolean;

    -- BFM: escritura de 1 ciclo
    procedure bus_write (constant a : in std_logic_vector(7 downto 0);
                         constant v : in std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      addr  <= a;
      wdata <= v;
      we    <= '1';
      sel   <= '1';
      wait until rising_edge(clk);
      sel <= '0';
      we  <= '0';
    end procedure;

    -- BFM: lectura con rdata combinacional dentro del ciclo de req
    procedure bus_read (constant a : in std_logic_vector(7 downto 0);
                        variable v : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      addr <= a;
      we   <= '0';
      sel  <= '1';
      wait for 1 ns;                     -- asentamiento combinacional
      v := rdata;
      wait until rising_edge(clk);
      sel <= '0';
    end procedure;

    -- sondear STAT hasta que un bit valga lo esperado (con limite)
    procedure poll_stat (constant bitidx : in integer;
                         constant val    : in std_logic;
                         constant lim    : in integer) is
      variable s : std_logic_vector(31 downto 0);
    begin
      for i in 1 to lim loop
        bus_read(A_STAT, s);
        exit when s(bitidx) = val;
      end loop;
      bus_read(A_STAT, s);
      assert s(bitidx) = val
        report "FALLO: timeout esperando bit de STAT" severity failure;
    end procedure;

  begin
    rst <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- FASE A: valores de reset
    bus_read(A_CTRL, d);
    assert d = x"00000000" report "FALLO: CTRL de reset" severity failure;
    bus_read(A_DIV, d);
    assert d = x"0000000A" report "FALLO: DIV de reset" severity failure;
    bus_read(A_IRQEN, d);
    assert d = x"00000000" report "FALLO: IRQEN de reset" severity failure;
    bus_read(A_STAT, d);
    assert d(2 downto 0) = "000" and d(24 downto 16) = "000000000"
      report "FALLO: STAT de reset" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '0' report "FALLO: VALID en RXD vacio" severity failure;
    report "FASE A OK: valores de reset";

    -- FASE B: registros RW
    bus_write(A_CTRL, x"0000001E");     -- todo menos EN
    bus_read(A_CTRL, d);
    assert d = x"0000001E" report "FALLO: CTRL RW" severity failure;
    bus_write(A_CTRL, x"00000000");
    bus_write(A_DIV, x"00000022");
    bus_read(A_DIV, d);
    assert d = x"00000022" report "FALLO: DIV RW" severity failure;
    bus_write(A_DIV, x"0000000A");      -- campo unico: parche con un solo addi
    bus_write(A_IRQEN, x"AAAA5555");
    bus_read(A_IRQEN, d);
    assert d = x"AAAA5555" report "FALLO: IRQEN RW" severity failure;
    bus_write(A_IRQEN, x"00000000");
    report "FASE B OK: registros RW";

    -- FASE C: FIFO TX y TX_FLUSH con el enlace parado (EN=1 sin START)
    bus_write(A_CTRL, x"00000001");
    wait for 200 ns;                    -- soltar la limpieza por EN
    bus_write(A_TXD, x"00000011");
    bus_write(A_TXD, x"00000022");
    bus_write(A_TXD, x"00000033");
    bus_read(A_TXD, d);
    assert d(6 downto 0) = "0000011" report "FALLO: tx_level" severity failure;
    bus_write(A_CMD, x"00000001");      -- TX_FLUSH
    bus_read(A_TXD, d);
    assert d(6 downto 0) = "0000000" report "FALLO: TX_FLUSH" severity failure;
    bus_write(A_CTRL, x"00000000");
    report "FASE C OK: contabilidad TX y TX_FLUSH";

    -- FASE D: bring-up en LOOP_INT hasta Run
    bus_write(A_CTRL, x"00000013");     -- EN | START | LOOP_INT
    poll_stat(3, '1', 5000);            -- RUN vivo
    bus_read(A_STAT, d);
    assert d(22) = '1' report "FALLO: sticky RUNOK" severity failure;
    bus_write(A_STAT, x"00000000");     -- limpiar stickies
    bus_read(A_STAT, d);
    assert d(24 downto 16) = "000000000"
      report "FALLO: limpieza de stickies" severity failure;
    assert d(3) = '1' report "FALLO: RUN vivo tras limpiar" severity failure;
    report "FASE D OK: bring-up LOOP_INT y stickies";

    -- FASE E: datos + EOP + EEP en loopback con pop-on-read
    bus_write(A_TXD, x"000000A5");
    bus_write(A_TXD, x"0000005A");
    bus_write(A_TXD, x"000000C3");
    bus_write(A_TXD, x"00000100");      -- EOP
    bus_write(A_TXD, x"00000101");      -- EEP
    poll_stat(5, '1', 5000);            -- RX_AVAIL
    wait for 6 us;                      -- llegan los 5 caracteres
    bus_read(A_STAT, d);
    assert d(14 downto 8) = "0000101" report "FALLO: rx_level=5" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '1' and d(8 downto 0) = "010100101"
      report "FALLO: dato 1" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '1' and d(8 downto 0) = "001011010"
      report "FALLO: dato 2" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '1' and d(8 downto 0) = "011000011"
      report "FALLO: dato 3" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '1' and d(8 downto 0) = "100000000"
      report "FALLO: EOP" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '1' and d(8 downto 0) = "100000001"
      report "FALLO: EEP" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '0' report "FALLO: VALID tras vaciar" severity failure;
    report "FASE E OK: loopback de datos, EOP y EEP con pop-on-read";

    -- FASE F: leer otros registros no consume RX
    bus_write(A_TXD, x"00000077");
    poll_stat(5, '1', 5000);
    for i in 1 to 10 loop
      bus_read(A_STAT, d);
      bus_read(A_CTRL, d);
      bus_read(A_TXD, d);
    end loop;
    bus_read(A_STAT, d);
    assert d(14 downto 8) = "0000001"
      report "FALLO: el pop no esta aislado" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '1' and d(7 downto 0) = x"77"
      report "FALLO: dato tras aislamiento" severity failure;
    report "FASE F OK: pop-on-read aislado en RXD";

    -- FASE G: time-codes
    bus_write(A_TIME, x"0000005A");
    poll_stat(20, '1', 5000);           -- sticky TICK
    bus_read(A_TIME, d);
    assert d(7 downto 0) = x"5A" report "FALLO: time_last" severity failure;
    assert d(15 downto 8) = x"01" report "FALLO: tick_cnt" severity failure;
    bus_write(A_STAT, x"00000000");
    bus_read(A_STAT, d);
    assert d(20) = '0' report "FALLO: limpieza de TICK" severity failure;
    bus_write(A_TIME, x"0000003B");
    poll_stat(20, '1', 5000);
    bus_read(A_TIME, d);
    assert d(7 downto 0) = x"3B" and d(15 downto 8) = x"02"
      report "FALLO: segundo tick" severity failure;
    bus_write(A_STAT, x"00000000");
    report "FASE G OK: time-codes con valor, contador y sticky";

    -- FASE H: RX_FLUSH
    bus_write(A_TXD, x"00000010");
    bus_write(A_TXD, x"00000020");
    poll_stat(5, '1', 5000);
    wait for 3 us;
    bus_write(A_CMD, x"00000002");      -- RX_FLUSH
    bus_read(A_STAT, d);
    assert d(5) = '0' report "FALLO: RX_FLUSH" severity failure;
    bus_read(A_RXD, d);
    assert d(31) = '0' report "FALLO: VALID tras RX_FLUSH" severity failure;
    report "FASE H OK: RX_FLUSH";

    -- FASE I: IRQ por nivel con mascara sobre STAT
    assert irq = '0' report "FALLO: irq en reposo" severity failure;
    bus_write(A_IRQEN, x"00000020");    -- b5 RX_AVAIL
    bus_write(A_TXD, x"000000EE");
    poll_stat(5, '1', 5000);
    wait for 100 ns;
    assert irq = '1' report "FALLO: irq por RX_AVAIL" severity failure;
    bus_read(A_RXD, d);
    assert d(7 downto 0) = x"EE" report "FALLO: dato de IRQ" severity failure;
    wait for 100 ns;
    assert irq = '0' report "FALLO: irq no baja al vaciar" severity failure;
    bus_write(A_IRQEN, x"00100000");    -- b20 TICK
    bus_write(A_TIME, x"00000007");
    poll_stat(20, '1', 5000);
    wait for 100 ns;
    assert irq = '1' report "FALLO: irq por TICK" severity failure;
    bus_write(A_STAT, x"00000000");
    wait for 100 ns;
    assert irq = '0' report "FALLO: irq no baja al limpiar" severity failure;
    bus_write(A_IRQEN, x"00000000");
    report "FASE I OK: IRQ por nivel";

    -- FASE J: parcheo de DIV y re-arranque a 50 Mbit/s
    bus_write(A_CTRL, x"00000000");     -- enlace abajo
    wait for 1 us;
    bus_write(A_DIV, x"00000002");
    bus_write(A_CTRL, x"00000013");
    poll_stat(3, '1', 5000);
    bus_write(A_STAT, x"00000000");
    bus_write(A_TXD, x"000000D4");
    poll_stat(5, '1', 5000);
    bus_read(A_RXD, d);
    assert d(31) = '1' and d(7 downto 0) = x"D4"
      report "FALLO: dato a 50 Mbit/s" severity failure;
    report "FASE J OK: DIV parcheado y enlace a 50 Mbit/s";

    -- FASE K: avalancha TX -> TXOVF, backpressure por creditos y prefijo
    for i in 0 to 89 loop
      bus_write(A_TXD, std_logic_vector(to_unsigned(i, 32)));
    end loop;
    bus_read(A_STAT, d);
    assert d(23) = '1' report "FALLO: sticky TXOVF" severity failure;
    -- los descartes se intercalan cuando el drenaje abre huecos: lo invariante
    -- es una subsecuencia ESTRICTAMENTE CRECIENTE de los valores escritos
    n    := 0;
    last := -1;
    ok   := false;
    while not ok loop
      bus_read(A_RXD, d);
      if d(31) = '1' then
        assert to_integer(unsigned(d(7 downto 0))) > last
          report "FALLO: orden roto en avalancha" severity failure;
        last := to_integer(unsigned(d(7 downto 0)));
        n    := n + 1;
      else
        bus_read(A_STAT, d);
        if d(6) = '1' then              -- TX vacio: dejar aterrizar el vuelo
          wait for 3 us;
          bus_read(A_RXD, d);
          if d(31) = '1' then
            assert to_integer(unsigned(d(7 downto 0))) > last
              report "FALLO: orden roto al final" severity failure;
            last := to_integer(unsigned(d(7 downto 0)));
            n    := n + 1;
          else
            ok := true;
          end if;
        end if;
      end if;
    end loop;
    assert n >= 64 and n < 90
      report "FALLO: conteo de avalancha fuera de rango" severity failure;
    assert last <= 89
      report "FALLO: valor imposible en avalancha" severity failure;
    report "FASE K OK: TXOVF, backpressure y subsecuencia ordenada";

    report "CAPA 2 PASS";
    done <= true;
    wait for 1 ns;
    finish;
  end process stim;

end architecture tb;
