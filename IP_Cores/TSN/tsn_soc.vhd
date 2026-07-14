-- tsn_soc.vhd - Envoltura de SoC del switch TSN para el RV32IM.
-- Presenta el switch como un esclavo dmem de 1 ciclo (mismo contrato que los
-- registros DMA del core): sel/we/addr/wdata sincronos, rdata COMBINACIONAL.
-- Genera mii_ce internamente (divisor /4 => 25 MHz desde clk de 100 MHz),
-- patron identico a eth_mac. Fija rx_src="10" (inyector) para bring-up en
-- silicio sin PHY ni trafico externo. Los pines MII TX salen para observabilidad
-- opcional; los RX externos quedan sin usar (el inyector alimenta el RX interno).
--
-- Mapa MMIO (offset de byte, addr de 9 bits): ver tsn_regs.vhd.
-- El core accede en 0x6000_0000; el decode superior toma addr(8:0).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tsn_pkg.all;

entity tsn_soc is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;                     -- sincrono, activo alto
    -- bus dmem del core (esclavo de 1 ciclo)
    sel       : in  std_logic;
    we        : in  std_logic;
    addr      : in  std_logic_vector(8 downto 0);
    wdata     : in  std_logic_vector(31 downto 0);
    rdata     : out std_logic_vector(31 downto 0); -- COMBINACIONAL
    ready     : out std_logic;                     -- siempre '1' (1 ciclo)
    irq       : out std_logic;
    -- pines MII (observabilidad; inertes para el bring-up con inyector)
    mii_txd   : out byte_arr4;
    mii_tx_en : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of tsn_soc is
  signal mii_ce : std_logic := '0';
  signal cediv  : unsigned(1 downto 0) := (others => '0');
  signal rxd_ext : byte_arr4 := (others => (others => '0'));
  signal rxdv_ext : std_logic_vector(3 downto 0) := (others => '0');
begin
  -- generador de mii_ce: pulso 1 de cada 4 ciclos (25 MHz), patron eth_mac
  p_ce : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cediv  <= (others => '0');
        mii_ce <= '0';
      elsif cediv = 3 then
        cediv  <= (others => '0');
        mii_ce <= '1';
      else
        cediv  <= cediv + 1;
        mii_ce <= '0';
      end if;
    end if;
  end process;

  ready <= '1';   -- esclavo de 1 ciclo (rdata combinacional)

  u_top : entity work.tsn_top
    port map (
      clk => clk, rst => rst, mii_ce => mii_ce,
      sel => sel, we => we, addr => addr, wdata => wdata, rdata => rdata,
      irq => irq,
      rx_src => "10",                     -- inyector alimenta el RX interno
      mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => rxd_ext, mii_rx_dv => rxdv_ext);
end architecture;
