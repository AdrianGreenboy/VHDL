-- eth_mac.vhd — MAC Ethernet 10/100 completo (familia TSN v1)
--
-- Integra el motor TX MII, el motor RX MII, el generador de mii_ce (divisor
-- /4 desde los 100 MHz del core -> tasa de nibble de 25 MHz) y el mux
-- LOOP_INT (patron del 1553):
--   loopback='1' -> las lineas MII del TX se realimentan al RX dentro del PL,
--                   sin salir por los pines. El reloj de 25 MHz es el mismo
--                   mii_ce interno para ambos motores.
--   loopback='0' -> PHY externo (roadmap v1.1): TX a los pads, RX de los pads.
--
-- El divisor /4 es de habilitacion (clock-enable), NO un reloj derivado: todo
-- corre a 100 MHz y los motores solo avanzan en el pulso mii_ce. Sin CDC.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_mac is
  port (
    clk       : in  std_logic;                     -- 100 MHz del core
    rst       : in  std_logic;                      -- sincrono activo-alto
    loopback  : in  std_logic;                      -- '1' LOOP_INT, '0' PHY ext
    -- configuracion RX
    macaddr   : in  std_logic_vector(47 downto 0);
    promisc   : in  std_logic;
    -- flujo TX (bytes de trama)
    tx_data   : in  std_logic_vector(7 downto 0);
    tx_valid  : in  std_logic;
    tx_last   : in  std_logic;
    tx_ready  : out std_logic;
    tx_busy   : out std_logic;
    tx_underrun : out std_logic;
    -- flujo RX (bytes de trama aceptada)
    rx_data   : out std_logic_vector(7 downto 0);
    rx_valid  : out std_logic;
    rx_last   : out std_logic;
    rx_ev_ok  : out std_logic;
    rx_ev_crc : out std_logic;
    rx_ev_runt: out std_logic;
    rx_ev_drop: out std_logic;
    rx_dbg_dst: out std_logic_vector(47 downto 0);
    rx_dbg_nb : out std_logic_vector(11 downto 0);
    -- pines MII (PHY externo; inertes en LOOP_INT v1 pero presentes)
    mii_txd   : out std_logic_vector(3 downto 0);
    mii_tx_en : out std_logic;
    mii_rxd   : in  std_logic_vector(3 downto 0);
    mii_rx_dv : in  std_logic;
    -- ganchos PTP (propagados desde los motores MII):
    tx_sfd_pulse : out std_logic;                   -- SFD emitido (para TS TX)
    rx_sfd_pulse : out std_logic;                   -- SFD detectado (para TS RX)
    -- override 1-step del TX (parcheo de originTimestamp/correctionField)
    ovr_en    : in  std_logic := '0';
    ovr_off   : in  std_logic_vector(10 downto 0) := (others => '0');
    ovr_len   : in  std_logic_vector(3 downto 0)  := (others => '0');
    ovr_data  : in  std_logic_vector(79 downto 0) := (others => '0')
  );
end entity eth_mac;

architecture rtl of eth_mac is

  signal mii_ce  : std_logic := '0';
  signal cediv   : unsigned(1 downto 0) := (others => '0');

  -- lineas internas del TX
  signal txd_i   : std_logic_vector(3 downto 0);
  signal txen_i  : std_logic;
  -- lineas que entran al RX (tras el mux LOOP_INT)
  signal rxd_i   : std_logic_vector(3 downto 0);
  signal rxdv_i  : std_logic;

begin

  -- generador de mii_ce: pulso 1 de cada 4 ciclos (25 MHz)
  process(clk)
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

  -- mux LOOP_INT: realimenta TX->RX en el PL, o toma el PHY externo
  rxd_i  <= txd_i  when loopback = '1' else mii_rxd;
  rxdv_i <= txen_i when loopback = '1' else mii_rx_dv;

  -- los pads TX siempre reflejan el motor (en LOOP_INT quedan inertes aguas abajo)
  mii_txd   <= txd_i;
  mii_tx_en <= txen_i;

  u_tx : entity work.eth_tx_mii
    port map (
      clk => clk, rst => rst, mii_ce => mii_ce,
      tx_data => tx_data, tx_valid => tx_valid, tx_last => tx_last,
      tx_ready => tx_ready, tx_busy => tx_busy, underrun => tx_underrun,
      txd => txd_i, tx_en => txen_i, tx_sfd_pulse => tx_sfd_pulse,
      ovr_en => ovr_en, ovr_off => ovr_off, ovr_len => ovr_len, ovr_data => ovr_data);

  u_rx : entity work.eth_rx_mii
    generic map (G_MAXLEN => 1518)
    port map (
      clk => clk, rst => rst, mii_ce => mii_ce,
      macaddr => macaddr, promisc => promisc,
      rxd => rxd_i, rx_dv => rxdv_i,
      rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
      ev_ok => rx_ev_ok, ev_crc => rx_ev_crc, ev_runt => rx_ev_runt, ev_drop => rx_ev_drop,
      dbg_dst => rx_dbg_dst, dbg_nb => rx_dbg_nb,
      rx_sfd_pulse => rx_sfd_pulse);

end architecture rtl;
