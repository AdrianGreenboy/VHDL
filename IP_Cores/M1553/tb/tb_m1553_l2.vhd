-- tb_m1553_l2.vhd
-- Capa 2: banco de registros del IP 1553 contra un BFM del bus dmem del RV32.
-- Verifica: rdata COMBINACIONAL (lectura en el mismo ciclo del sel), pop-on-
-- read del FIFO RX, stickies con limpieza por escritura a STAT y sets del
-- mismo ciclo GANANDO, IRQ por nivel con mascara, y el flujo funcional de los
-- cinco formatos en LOOP_INT (precargar TXD, escribir MSG, pulsar GO, esperar
-- DONE por polling de STAT, leer RESULT y drenar RXD).
-- Mensajes de FALLO sin tildes.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_m1553_l2 is
end entity tb_m1553_l2;

architecture sim of tb_m1553_l2 is

  constant T_CLK : time := 10 ns;

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal sel   : std_logic := '0';
  signal we    : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0) := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq   : std_logic;
  signal bus_rx : std_logic := '0';
  signal bus_tx, bus_txen : std_logic;

  -- offsets
  constant A_CTRL   : std_logic_vector(7 downto 0) := x"00";
  constant A_RTAD   : std_logic_vector(7 downto 0) := x"04";
  constant A_CMD    : std_logic_vector(7 downto 0) := x"08";
  constant A_MSG    : std_logic_vector(7 downto 0) := x"0C";
  constant A_STAT   : std_logic_vector(7 downto 0) := x"10";
  constant A_TXD    : std_logic_vector(7 downto 0) := x"14";
  constant A_RXD    : std_logic_vector(7 downto 0) := x"18";
  constant A_IRQEN  : std_logic_vector(7 downto 0) := x"1C";
  constant A_RESULT : std_logic_vector(7 downto 0) := x"20";

begin

  clk <= not clk after T_CLK/2;

  dut : entity work.m1553_mmio
    port map (
      clk => clk, rst => rst,
      sel => sel, we => we, addr => addr, wdata => wdata, rdata => rdata,
      irq => irq,
      bus_rx_i => bus_rx, bus_tx_o => bus_tx, bus_txen_o => bus_txen);

  stim : process
    -- BFM
    procedure wr(a : std_logic_vector(7 downto 0);
                 d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '1'; addr <= a; wdata <= d;
      wait until rising_edge(clk);
      sel <= '0'; we <= '0';
    end procedure;

    procedure rd(a : std_logic_vector(7 downto 0);
                 res : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '0'; addr <= a;
      wait for 1 ns;                     -- rdata combinacional en el mismo ciclo
      res := rdata;
      wait until rising_edge(clk);
      sel <= '0';
    end procedure;

    -- construye el campo MSG
    function msgw(rtrt, tr : std_logic;
                  rt, sa, wc, rt2, sa2 : std_logic_vector(4 downto 0))
      return std_logic_vector is
      variable v : std_logic_vector(31 downto 0) := (others => '0');
    begin
      v(0) := rtrt; v(1) := tr;
      v(6 downto 2)   := rt;
      v(11 downto 7)  := sa;
      v(16 downto 12) := wc;
      v(21 downto 17) := rt2;
      v(26 downto 22) := sa2;
      return v;
    end function;

    variable r : std_logic_vector(31 downto 0);

    procedure run_msg(caso : string) is
      variable guard : integer := 0;
    begin
      wr(A_CMD, x"00000004");            -- GO
      loop
        rd(A_STAT, r);
        exit when r(16) = '1';           -- DONE sticky
        guard := guard + 1;
        assert guard < 20000
          report "FALLO caso " & caso & ": DONE no llego" severity failure;
      end loop;
    end procedure;

  begin
    rst <= '1';
    wait for 200 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 1 us;

    ---------------------------------------------------------------- registros
    -- valores por defecto de RTADDR
    rd(A_RTAD, r);
    assert r(4 downto 0) = "00101" and r(12 downto 8) = "01001"
      report "FALLO: RTADDR por defecto incorrecto" severity failure;

    -- CTRL R/W
    wr(A_CTRL, x"00000003");
    rd(A_CTRL, r);
    assert r(1 downto 0) = "11"
      report "FALLO: CTRL no retuvo EN/LOOP_INT" severity failure;

    -- MSG R/W
    wr(A_MSG, msgw('0','0',"00011","00010","00100","00000","00000"));
    rd(A_MSG, r);
    assert r(26 downto 0) = msgw('0','0',"00011","00010","00100","00000","00000")(26 downto 0)
      report "FALLO: MSG no retuvo los campos" severity failure;

    -- habilitar en LOOP_INT (ya hecho con CTRL=3), esperar a que arranquen
    wait for 2 us;

    ------------------------------------------------ formato BC->RT0, wc=4
    wr(A_TXD, x"0000B100");
    wr(A_TXD, x"0000B101");
    wr(A_TXD, x"0000B102");
    wr(A_TXD, x"0000B103");
    rd(A_TXD, r);
    assert r(6 downto 0) = "0000100"
      report "FALLO: nivel del FIFO TX tras 4 escrituras" severity failure;
    wr(A_MSG, msgw('0','0',"00101","00011","00100","00000","00000"));
    run_msg("BC->RT");
    rd(A_STAT, r);
    assert r(17) = '1' and r(18) = '0'
      report "FALLO BC->RT: OK/TOUT" severity failure;
    rd(A_RESULT, r);
    assert r(15 downto 0) = x"2800"
      report "FALLO BC->RT: stat1 en RESULT" severity failure;
    -- drenar RXD: 4 datos de fuente RT0 (01)
    for i in 0 to 3 loop
      rd(A_RXD, r);
      assert r(31) = '1'
        report "FALLO BC->RT: RXD sin VALID" severity failure;
      assert r(17 downto 16) = "01"
        report "FALLO BC->RT: fuente RXD no es RT0" severity failure;
    end loop;
    rd(A_RXD, r);
    assert r(31) = '0'
      report "FALLO BC->RT: RXD deberia estar vacio" severity failure;
    -- limpiar stickies
    wr(A_STAT, x"FFFFFFFF");
    rd(A_STAT, r);
    assert r(27 downto 16) = x"000"
      report "FALLO: los stickies no se limpiaron" severity failure;
    wait for 20 us;

    ------------------------------------------------ formato RT0->BC, wc=3
    -- RT0 transmite: precargar sus datos en el FIFO comun
    wr(A_TXD, x"0000E200");
    wr(A_TXD, x"0000E201");
    wr(A_TXD, x"0000E202");
    wr(A_MSG, msgw('0','1',"00101","00010","00011","00000","00000"));
    run_msg("RT->BC");
    rd(A_STAT, r);
    assert r(17) = '1'
      report "FALLO RT->BC: no OK" severity failure;
    -- drenar RXD: 3 datos de fuente BC (00)
    for i in 0 to 2 loop
      rd(A_RXD, r);
      assert r(31) = '1' and r(17 downto 16) = "00"
        report "FALLO RT->BC: RXD fuente/valid" severity failure;
      assert r(15 downto 0) = std_logic_vector(to_unsigned(16#E200# + i, 16))
        report "FALLO RT->BC: dato RXD incorrecto" severity failure;
    end loop;
    wr(A_STAT, x"FFFFFFFF");
    wait for 20 us;

    ------------------------------------------------ RT0->RT1, wc=2
    wr(A_TXD, x"0000F300");             -- los transmite RT1
    wr(A_TXD, x"0000F301");
    wr(A_MSG, msgw('1','0',"00101","00100","00010","01001","00100"));
    run_msg("RT->RT");
    rd(A_RESULT, r);
    assert r(15 downto 0) = x"4800" and r(31 downto 16) = x"2800"
      report "FALLO RT->RT: statuses en RESULT" severity failure;
    -- RT0 recibio 2 datos de fuente RT0 (01)
    for i in 0 to 1 loop
      rd(A_RXD, r);
      assert r(31) = '1' and r(17 downto 16) = "01"
        report "FALLO RT->RT: RXD fuente/valid" severity failure;
    end loop;
    wr(A_STAT, x"FFFFFFFF");
    wait for 20 us;

    ------------------------------------------------ broadcast wc=2 -> BCR
    wr(A_TXD, x"0000B4B4");
    wr(A_TXD, x"0000B5B5");
    wr(A_MSG, msgw('0','0',"11111","00110","00010","00000","00000"));
    run_msg("BCAST");
    wait for 5 us;
    rd(A_STAT, r);
    assert r(26) = '1' and r(27) = '1'
      report "FALLO broadcast: BCR de RT0/RT1 no puesto" severity failure;
    -- ambos RTs recibieron: 4 palabras en RXD
    for i in 0 to 3 loop
      rd(A_RXD, r);
      assert r(31) = '1' and r(23) = '1'
        report "FALLO broadcast: RXD sin bit bcast" severity failure;
    end loop;
    wr(A_STAT, x"FFFFFFFF");
    wait for 20 us;

    ------------------------------------------------ timeout (RT ausente)
    wr(A_MSG, msgw('0','1',"01100","00010","00010","00000","00000"));
    run_msg("TOUT");
    rd(A_STAT, r);
    assert r(18) = '1' and r(17) = '0'
      report "FALLO timeout: TOUT/OK" severity failure;
    wr(A_STAT, x"FFFFFFFF");
    wait for 10 us;

    ------------------------------------------------ IRQ por nivel + set-wins
    -- habilitar IRQ en DONE (b16)
    wr(A_IRQEN, x"00010000");
    assert irq = '0'
      report "FALLO IRQ: activa antes de tiempo" severity failure;
    wr(A_MSG, msgw('0','1',"00101","00000","00010","00000","00000")); -- TxStatus RT0
    wr(A_CMD, x"00000004");            -- GO (sin polling)
    -- esperar a que DONE se ponga -> irq debe subir por nivel
    wait for 60 us;
    assert irq = '1'
      report "FALLO IRQ: no subio con DONE enmascarado" severity failure;
    -- set-wins: escribir STAT en el mismo flujo no debe dejar IRQ pegada si
    -- ya no hay evento; limpiar y comprobar caida
    wr(A_STAT, x"FFFFFFFF");
    wait for 100 ns;
    assert irq = '0'
      report "FALLO IRQ: no cayo tras limpiar DONE" severity failure;
    wr(A_IRQEN, x"00000000");
    wait for 5 us;

    report "M1553 CAPA 2 PASS";
    finish;
  end process;

end architecture sim;
