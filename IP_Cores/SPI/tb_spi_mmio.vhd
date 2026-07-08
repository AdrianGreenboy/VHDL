-- =============================================================================
--  tb_spi_mmio.vhd  -  Valida registros + FIFOs + motor en modo PIO
--  Licencia: MIT
--
--  Emula los accesos del core (estilo dmem: sel/req/addr/wdata/wstrb de 1
--  ciclo) con MISO en loopback. FIFO_LOG2 = 4 (16 bytes) para poder probar
--  full/overflow rapido. Pruebas:
--    T1: eco PIO de 8 bytes back-to-back, niveles y flags
--    T2: cs_force mantiene CS_n abajo entre bytes lentos
--    T3: FIFO TX lleno con en=0, push extra descartado (tx_ovf), drenado
--    T4: overflow de RX (byte 17 con FIFO de 16 lleno), sticky y limpieza
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_spi_mmio is
end entity tb_spi_mmio;

architecture sim of tb_spi_mmio is
  constant TCK  : time    := 10 ns;      -- 100 MHz
  constant FLOG : natural := 4;          -- FIFOs de 16 bytes en el TB

  -- offsets de registros
  constant A_CTRL   : std_logic_vector(7 downto 0) := x"00";
  constant A_STATUS : std_logic_vector(7 downto 0) := x"04";
  constant A_CLKDIV : std_logic_vector(7 downto 0) := x"08";
  constant A_TXDATA : std_logic_vector(7 downto 0) := x"0C";
  constant A_RXDATA : std_logic_vector(7 downto 0) := x"10";
  constant A_TXLVL  : std_logic_vector(7 downto 0) := x"14";
  constant A_RXLVL  : std_logic_vector(7 downto 0) := x"18";

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal sel, req : std_logic := '0';
  signal addr  : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0)  := (others => '0');
  signal rdata : std_logic_vector(31 downto 0);

  signal sclk, mosi, cs_n : std_logic;
  signal miso : std_logic;
begin

  clk  <= not clk after TCK/2;
  miso <= mosi;                          -- loopback

  dut : entity work.spi_mmio
    generic map (DIV_W => 16, FIFO_LOG2 => FLOG)
    port map (
      clk => clk, aresetn => aresetn,
      sel => sel, req => req, addr => addr,
      wdata => wdata, wstrb => wstrb, rdata => rdata,
      sclk_o => sclk, mosi_o => mosi, miso_i => miso, cs_n_o => cs_n
    );

  stim : process
    variable d : std_logic_vector(31 downto 0);

    procedure wr32(a : std_logic_vector(7 downto 0);
                   v : std_logic_vector(31 downto 0)) is
    begin
      addr <= a; wdata <= v; wstrb <= "1111"; sel <= '1'; req <= '1';
      wait until rising_edge(clk);
      sel <= '0'; req <= '0'; wstrb <= (others => '0');
    end procedure;

    procedure rd32(a : std_logic_vector(7 downto 0);
                   variable v : out std_logic_vector(31 downto 0)) is
    begin
      addr <= a; wstrb <= (others => '0'); sel <= '1'; req <= '1';
      wait until falling_edge(clk);      -- rdata estable a mitad del ciclo
      v := rdata;
      wait until rising_edge(clk);       -- aqui ocurre el pop (si es RXDATA)
      sel <= '0'; req <= '0';
    end procedure;

    -- espera a que el motor termine y el FIFO TX quede vacio
    procedure wait_idle is
      variable s : std_logic_vector(31 downto 0);
    begin
      loop
        rd32(A_STATUS, s);
        exit when s(0) = '0' and s(1) = '1';
      end loop;
      for i in 1 to 4 loop wait until rising_edge(clk); end loop;
    end procedure;

    procedure chk(cond : boolean; msg : string) is
    begin
      assert cond report msg severity failure;
      report msg & " OK";
    end procedure;
  begin
    aresetn <= '0';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;
    aresetn <= '1';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    -- configuracion comun: div=1 (SCLK 50 MHz), modo 0, MSB primero
    wr32(A_CLKDIV, x"00000001");
    wr32(A_CTRL,   x"00000001");         -- en=1

    ---------------------------------------------------------------------------
    -- T1: eco PIO de 8 bytes back-to-back
    ---------------------------------------------------------------------------
    for k in 0 to 7 loop
      wr32(A_TXDATA, x"000000" & std_logic_vector(to_unsigned(16#A0# + k, 8)));
    end loop;
    wait_idle;
    rd32(A_RXLVL, d);
    chk(to_integer(unsigned(d)) = 8, "T1 rxlvl=8");
    for k in 0 to 7 loop
      rd32(A_RXDATA, d);
      assert d(7 downto 0) = std_logic_vector(to_unsigned(16#A0# + k, 8))
        report "T1 byte " & integer'image(k) & " leido " & to_hstring(d(7 downto 0))
        severity failure;
    end loop;
    rd32(A_STATUS, d);
    chk(d(3) = '1', "T1 rx_empty tras drenar");
    chk(cs_n = '1', "T1 CS de vuelta en idle");

    ---------------------------------------------------------------------------
    -- T2: cs_force mantiene CS_n abajo entre bytes lentos
    ---------------------------------------------------------------------------
    wr32(A_CTRL, x"00000021");           -- en=1, cs_force=1
    wr32(A_TXDATA, x"000000AA");
    wait_idle;
    chk(cs_n = '0', "T2 CS forzado abajo con motor idle");
    wr32(A_TXDATA, x"00000055");
    wait_idle;
    chk(cs_n = '0', "T2 CS sigue abajo tras segundo byte");
    wr32(A_CTRL, x"00000001");           -- suelta cs_force
    for i in 1 to 4 loop wait until rising_edge(clk); end loop;
    chk(cs_n = '1', "T2 CS liberado");
    rd32(A_RXLVL, d);
    chk(to_integer(unsigned(d)) = 2, "T2 rxlvl=2");
    rd32(A_RXDATA, d);
    chk(d(7 downto 0) = x"AA", "T2 byte0=AA");
    rd32(A_RXDATA, d);
    chk(d(7 downto 0) = x"55", "T2 byte1=55");

    ---------------------------------------------------------------------------
    -- T3: FIFO TX lleno con en=0, push extra descartado, drenado completo
    ---------------------------------------------------------------------------
    wr32(A_CTRL, x"00000000");           -- en=0: el motor no drena
    for k in 0 to 15 loop
      wr32(A_TXDATA, x"000000" & std_logic_vector(to_unsigned(k, 8)));
    end loop;
    rd32(A_STATUS, d);
    chk(d(2) = '1', "T3 tx_full con 16 bytes");
    rd32(A_TXLVL, d);
    chk(to_integer(unsigned(d)) = 16, "T3 txlvl=16");
    wr32(A_TXDATA, x"000000EE");         -- se descarta
    rd32(A_TXLVL, d);
    chk(to_integer(unsigned(d)) = 16, "T3 txlvl sigue en 16");
    rd32(A_STATUS, d);
    chk(d(6) = '1', "T3 tx_ovf sticky");
    wr32(A_CTRL, x"00000001");           -- en=1: drena los 16
    wait_idle;
    rd32(A_RXLVL, d);
    chk(to_integer(unsigned(d)) = 16, "T3 rxlvl=16 (RX justo lleno)");
    for k in 0 to 15 loop
      rd32(A_RXDATA, d);
      assert d(7 downto 0) = std_logic_vector(to_unsigned(k, 8))
        report "T3 byte " & integer'image(k) & " leido " & to_hstring(d(7 downto 0))
        severity failure;
    end loop;
    wr32(A_STATUS, x"00000000");         -- limpia stickies
    rd32(A_STATUS, d);
    chk(d(6) = '0', "T3 tx_ovf limpio");

    ---------------------------------------------------------------------------
    -- T4: overflow de RX (byte 17 llega con el FIFO de 16 lleno)
    ---------------------------------------------------------------------------
    for k in 0 to 15 loop
      wr32(A_TXDATA, x"000000" & std_logic_vector(to_unsigned(16#40# + k, 8)));
    end loop;
    wait_idle;                           -- RX queda exactamente lleno
    wr32(A_TXDATA, x"00000077");         -- el motor lo manda, RX lo descarta
    wait_idle;
    rd32(A_STATUS, d);
    chk(d(4) = '1', "T4 rx_full");
    chk(d(5) = '1', "T4 rx_ovf sticky");
    rd32(A_RXLVL, d);
    chk(to_integer(unsigned(d)) = 16, "T4 rxlvl sigue en 16");
    for k in 0 to 15 loop
      rd32(A_RXDATA, d);
      assert d(7 downto 0) = std_logic_vector(to_unsigned(16#40# + k, 8))
        report "T4 byte " & integer'image(k) & " leido " & to_hstring(d(7 downto 0))
        severity failure;
    end loop;
    rd32(A_STATUS, d);
    chk(d(3) = '1', "T4 rx_empty tras drenar (el 0x77 se perdio)");
    wr32(A_STATUS, x"00000000");
    rd32(A_STATUS, d);
    chk(d(5) = '0', "T4 rx_ovf limpio");

    report "TEST PASSED" severity note;
    std.env.finish;
  end process;

end architecture sim;
