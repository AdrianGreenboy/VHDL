-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- PCS de 66 bits sin gearbox: un bloque de 66 bits por ciclo, la interfaz que
-- presenta un GT en modo 64B/66B con gearbox interno (TXDATA 64 + TXHEADER 2
-- a 390.625 MHz = 25.78125 Gb/s, la tasa de linea real de 25GBASE-R).
--
-- En un sistema real el gearbox 66->64 lo hace el GT; el gearbox de fabric
-- del Core 19 solo hace falta para un loopback de palabras de 64 bits. Ademas
-- era el segundo camino critico del Core 20 a 390.625 MHz (insercion en
-- posicion variable de un buffer de 130 bits, 7 niveles de LUT).
--
--   mac25g_pcs66_tx: scrambler (Core 19) + sync header -> bloque de 66 bits
--   mac25g_pcs66_rx: bloque de 66 bits -> descrambler (Core 19) + is_data
-- Mismo scrambler, mismo orden de bits y misma convencion de sync header que
-- pcs_tx_datapath / pcs_rx_datapath del Core 19 (ver README, seccion 3).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity mac25g_pcs66_tx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    in_valid   : in  std_logic;
    in_payload : in  std_logic_vector(63 downto 0);
    in_is_data : in  std_logic;
    out_valid  : out std_logic;
    out_block  : out std_logic_vector(65 downto 0)   -- payload(65:2) & sync(1:0)
  );
end entity mac25g_pcs66_tx;

architecture rtl of mac25g_pcs66_tx is
  signal scr_dout  : std_logic_vector(63 downto 0);
  signal scr_valid : std_logic;
  signal sync_d1   : std_logic_vector(1 downto 0) := (others => '0');
begin
  u_scr: entity work.pcs_scrambler
    port map (clk=>clk, rst=>rst, en=>in_valid, mode=>'0',
              din=>in_payload, dout=>scr_dout, dvalid=>scr_valid);

  process(clk)
  begin
    if rising_edge(clk) then
      if in_valid = '1' then
        if in_is_data = '1' then sync_d1 <= "01"; else sync_d1 <= "10"; end if;
      end if;
    end if;
  end process;

  out_valid <= scr_valid;
  out_block <= scr_dout & sync_d1;
end architecture rtl;


library ieee;
use ieee.std_logic_1164.all;

entity mac25g_pcs66_rx is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    in_valid    : in  std_logic;
    in_block    : in  std_logic_vector(65 downto 0);
    out_valid   : out std_logic;
    out_payload : out std_logic_vector(63 downto 0);
    out_is_data : out std_logic
  );
end entity mac25g_pcs66_rx;

architecture rtl of mac25g_pcs66_rx is
  signal des_dout  : std_logic_vector(63 downto 0);
  signal des_valid : std_logic;
  signal sync_d1   : std_logic_vector(1 downto 0) := (others => '0');
begin
  u_des: entity work.pcs_scrambler
    port map (clk=>clk, rst=>rst, en=>in_valid, mode=>'1',
              din=>in_block(65 downto 2), dout=>des_dout, dvalid=>des_valid);

  process(clk)
  begin
    if rising_edge(clk) then
      if in_valid = '1' then sync_d1 <= in_block(1 downto 0); end if;
    end if;
  end process;

  out_valid   <= des_valid;
  out_payload <= des_dout;
  out_is_data <= '1' when sync_d1 = "01" else '0';
end architecture rtl;
