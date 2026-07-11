-- tb_ptp_top.vhd — IP completo controlado por MMIO (capa 2 + 1c).
-- El "firmware" (BFM) configura el IP por registros, dispara send_sync por CMD
-- en LOOP_INT, y verifica que el datapath responde: el Sync vuelve, arma el
-- sticky rx_sync en STATUS, y el reloj avanza (NOW_NS != 0).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity tb_ptp_top is
end entity;

architecture sim of tb_ptp_top is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(5 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal irq : std_logic;
  signal mii_txd : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;

  constant A_CTRL:integer:=0; constant A_SERVO:integer:=1; constant A_CMD:integer:=3;
  constant A_CLKIDH:integer:=4; constant A_CLKIDL:integer:=5; constant A_PORT:integer:=6;
  constant A_SMACH:integer:=7; constant A_SMACL:integer:=8; constant A_STATUS:integer:=9;
  constant A_NOWSEC:integer:=10; constant A_NOWNS:integer:=11; constant A_IRQEN:integer:=16;
begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_top
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
              wdata => wdata, rdata => rdata, irq => irq,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => (others => '0'), mii_rx_dv => '0');

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure wr(a : integer; d : std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a,6)); wdata <= d; sel<='1'; we<='1';
      step; sel<='0'; we<='0'; wait for 1 ns;
    end procedure;
    procedure rd(a : integer; result : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a,6)); sel<='1'; we<='0';
      wait for 1 ns; result := rdata; step; sel<='0';
    end procedure;
    variable v : std_logic_vector(31 downto 0);
  begin
    rst <= '1'; step; step; rst <= '0';

    -- ===== "firmware": configurar el IP =====
    wr(A_CTRL,  x"00000006");   -- loopback=1, enable=1, role=maestro
    wr(A_SERVO, x"00400010");   -- KP=0x40, KI=0x10
    wr(A_CLKIDH,x"00112233"); wr(A_CLKIDL,x"44556677");
    wr(A_PORT,  x"00000001");
    wr(A_SMACH, x"000002DE"); wr(A_SMACL, x"CAFBADED");
    wr(A_IRQEN, x"00000001");   -- irq en rx_sync
    report "OK firmware configuro el IP por MMIO";

    -- limpiar STATUS
    wr(A_STATUS, x"0000000F");

    -- ===== disparar un Sync por CMD =====
    wr(A_CMD, x"00000001");     -- send_sync

    -- esperar a que el Sync vuelva por loopback y arme rx_sync
    for i in 1 to 4000 loop step; end loop;

    rd(A_STATUS, v);
    assert v(0) = '1'
      report "FALLO: el Sync no armo el sticky rx_sync (lazo no cerro por MMIO)" severity failure;
    report "OK Sync disparado por MMIO volvio y armo rx_sync (STATUS=" &
           integer'image(to_integer(unsigned(v))) & ")";

    -- irq debe estar activo (rx_sync armado + IRQEN bit0)
    assert irq = '1' report "FALLO: irq no se activo" severity failure;
    report "OK irq activo tras rx_sync";

    -- el reloj debe estar avanzando
    rd(A_NOWSEC, v);
    rd(A_NOWNS, v);
    assert unsigned(v) > 0 report "FALLO: el reloj no avanza" severity failure;
    report "OK reloj avanzando (NOW_NS=" & integer'image(to_integer(unsigned(v))) & ")";

    -- limpiar el sticky por W1C -> irq baja
    wr(A_STATUS, x"00000001");
    wait for 1 ns;
    assert irq = '0' report "FALLO: irq no bajo tras W1C" severity failure;
    report "OK W1C bajo la irq";

    report "=== PTP_TOP (IP completo por MMIO) PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
