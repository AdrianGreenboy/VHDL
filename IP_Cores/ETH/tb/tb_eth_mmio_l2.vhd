-- tb_eth_mmio_l2.vhd — capa 2: banco MMIO del MAC contra un BFM del bus dmem.
-- El BFM emula el contrato del dmem del RV32: sel de 1 ciclo, rdata
-- combinacional capturado en el flanco, pop-on-read. En LOOP_INT, el firmware
-- escribe una trama byte a byte en TXD (EOF en el ultimo), la trama da la
-- vuelta por el MAC y aparece en la FIFO RX; el firmware la lee de RXD y se
-- comprueba bit a bit contra lo enviado.
--
-- Verifica ademas el contrato COMBINACIONAL del rdata: una lectura devuelve el
-- valor del MISMO ciclo del sel, no el anterior (un rdata registrado fallaria
-- la comprobacion de pop-on-read consecutivo).
--
-- G_MUT (DEBEN fallar):
--   0 = sin mutacion (PASS)
--   1 = el oraculo espera un byte de trama distinto -> lectura RXD no coincide
--   2 = el oraculo NO limpia stickies y espera STAT.RX_OK=0 -> pero esta a 1
--   3 = el oraculo espera VALID=1 tras vaciar la FIFO RX -> esta a 0
--   4 = se omite poner EN=1 y el oraculo espera recibir la trama -> no llega
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_eth_mmio_l2 is
  generic (G_MUT : integer := 0);
end entity tb_eth_mmio_l2;

architecture sim of tb_eth_mmio_l2 is

  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal sel   : std_logic := '0';
  signal we    : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0) := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq   : std_logic;

  -- offsets de palabra (addr = offset)
  constant A_CTRL  : std_logic_vector(7 downto 0) := x"00";
  constant A_MACLO : std_logic_vector(7 downto 0) := x"04";
  constant A_MACHI : std_logic_vector(7 downto 0) := x"08";
  constant A_CMD   : std_logic_vector(7 downto 0) := x"0C";
  constant A_STAT  : std_logic_vector(7 downto 0) := x"10";
  constant A_TXD   : std_logic_vector(7 downto 0) := x"14";
  constant A_RXD   : std_logic_vector(7 downto 0) := x"18";
  constant A_IRQEN : std_logic_vector(7 downto 0) := x"1C";

  type nat_arr is array (natural range <>) of natural;

  function tbyte(f : natural; i : natural) return std_logic_vector is
    constant MINE  : nat_arr(0 to 5) := (16#02#, 16#AA#, 16#BB#, 16#CC#, 16#DD#, 16#EE#);
    constant SRC_B : nat_arr(0 to 5) := (16#0A#, 16#0B#, 16#0C#, 16#0D#, 16#0E#, 16#0F#);
    variable b : natural;
  begin
    if i < 6 then b := MINE(i);
    elsif i < 12 then b := SRC_B(i - 6);
    elsif i = 12 then b := 16#08#;
    elsif i = 13 then b := 16#00#;
    else b := (f * 13 + (i - 14) * 5 + 9) mod 256;
    end if;
    return std_logic_vector(to_unsigned(b, 8));
  end function;

begin

  clk <= not clk after TCLK / 2;

  dut : entity work.eth_mmio
    port map (
      clk => clk, rst => rst, sel => sel, we => we,
      addr => addr, wdata => wdata, rdata => rdata, irq => irq,
      mii_txd => open, mii_tx_en => open,
      mii_rxd => "0000", mii_rx_dv => '0');

  process
    variable rd : std_logic_vector(31 downto 0);

    -- escritura de 1 ciclo (contrato dmem)
    procedure wr32(a : std_logic_vector(7 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '1'; addr <= a; wdata <= d;
      wait until rising_edge(clk);
      sel <= '0'; we <= '0';
    end procedure;

    -- lectura combinacional: sel alto, capturar rdata en el flanco
    procedure rd32(a : std_logic_vector(7 downto 0); res : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '0'; addr <= a;
      wait for 1 ns;                         -- dejar asentar el mux combinacional
      res := rdata;
      wait until rising_edge(clk);
      sel <= '0';
    end procedure;

    variable plen : integer := 100;
    variable len  : integer;
    variable eof  : std_logic;
    variable exp  : std_logic_vector(7 downto 0);
    variable got  : integer := 0;
    variable guard: integer;
  begin
    -- reset
    rst <= '1';
    wait for 20 * TCLK;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 4 * TCLK;

    -- configurar MAC propia. MAC destino de tbyte = 02:AA:BB:CC:DD:EE,
    -- con byte i en bits [i*8+7:i*8]:
    --   maclo = CC BB AA 02 = 0xCCBBAA02 ; machi = 00 00 EE DD = 0x0000EEDD
    wr32(A_MACLO, x"CCBBAA02");
    wr32(A_MACHI, x"0000EEDD");
    wr32(A_IRQEN, x"00010000");                 -- IRQ en RX_OK (b16)

    -- habilitar: EN=1, LOOP_INT=1, PROMISC=0  (salvo MUT4: no habilitar)
    if G_MUT /= 4 then
      wr32(A_CTRL, x"00000003");                -- b0 EN, b1 LOOP
    else
      wr32(A_CTRL, x"00000002");                -- solo LOOP, sin EN
    end if;
    wait for 4 * TCLK;

    -- escribir la trama byte a byte en TXD (EOF en el ultimo)
    len := 14 + plen;
    for i in 0 to len - 1 loop
      if i = len - 1 then eof := '1'; else eof := '0'; end if;
      wr32(A_TXD, (31 downto 9 => '0') & eof & tbyte(0, i));
    end loop;

    -- esperar a que la trama de la vuelta y aparezca en la FIFO RX
    guard := 0;
    loop
      rd32(A_STAT, rd);
      exit when rd(16) = '1';                   -- RX_OK sticky
      guard := guard + 1;
      if guard > 4000 then
        assert G_MUT = 4
          report "L2: la trama no volvio (RX_OK nunca)" severity failure;
        exit;
      end if;
    end loop;

    if G_MUT = 4 then
      -- sin EN, no debe haberse recibido nada: el oraculo esperaba RX_OK
      assert rd(16) = '1'
        report "L2: sin EN el MAC no recibio la trama (RX_OK=0)" severity failure;
    end if;

    -- leer la trama de RXD byte a byte hasta EOF, comparar
    got := 0;
    loop
      rd32(A_RXD, rd);
      exit when rd(31) = '0';                   -- VALID=0: FIFO vacia
      exp := tbyte(0, got);
      if G_MUT = 1 and got = 40 then exp := exp xor x"01"; end if;
      assert rd(7 downto 0) = exp
        report "L2: byte " & integer'image(got) & " de RXD no coincide" severity failure;
      if rd(8) = '1' then                        -- EOF
        assert got = len - 1
          report "L2: EOF en byte " & integer'image(got) &
                 " (esperado " & integer'image(len - 1) & ")" severity failure;
      end if;
      got := got + 1;
      if got > 2000 then
        assert false report "L2: RXD no termino (sin EOF)" severity failure;
      end if;
    end loop;
    assert got = len
      report "L2: recibidos " & integer'image(got) & " bytes (esperados " &
             integer'image(len) & ")" severity failure;

    -- MUT3: el oraculo espera VALID=1 tras vaciar (esta a 0)
    if G_MUT = 3 then
      rd32(A_RXD, rd);
      assert rd(31) = '1'
        report "L2: VALID esperado 1 tras vaciar la FIFO RX" severity failure;
    end if;

    -- comprobar IRQ por nivel: RX_OK y IRQEN(16)=1 -> irq=1
    assert irq = '1'
      report "L2: irq deberia estar alto (RX_OK y IRQEN)" severity failure;

    -- limpiar stickies escribiendo a STAT
    wr32(A_STAT, x"00000000");
    wait for 4 * TCLK;
    rd32(A_STAT, rd);
    if G_MUT = 2 then
      -- el oraculo "no limpio" y espera RX_OK=0; comprobamos que SI se limpio
      assert rd(16) = '1'
        report "L2: RX_OK deberia haberse limpiado (mut2)" severity failure;
    else
      assert rd(16) = '0'
        report "L2: RX_OK no se limpio tras escribir STAT" severity failure;
    end if;

    report "L2 MMIO PASS: trama " & integer'image(len) &
           " bytes ida y vuelta por MMIO, stickies e IRQ OK";
    finish;
  end process;

  process
  begin
    wait for 5 ms;
    assert false report "L2: timeout" severity failure;
    wait;
  end process;

end architecture sim;
