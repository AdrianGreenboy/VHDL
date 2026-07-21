-- HERCOSSNUX NPU - tipos y constantes AXI4.
-- Subconjunto congelado:
--   S_AXI (slave) : INCR y FIXED reales, WRAP tratada como INCR, IDs
--                   propagados, WSTRB respetado, SLVERR fuera de rango,
--                   AWLOCK ignorado
--   M_AXI (master): solo INCR, ARLEN <= 15 para no cruzar la frontera de
--                   4 KB, ID fijo en 0, RRESP/BRESP comprobados
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package npu_axi_pkg is

  -- Anchos
  constant C_AXI_ADDR_W : natural := 32;
  constant C_AXI_DATA_W : natural := 32;
  constant C_AXI_STRB_W : natural := C_AXI_DATA_W/8;

  -- Respuestas AXI
  constant C_RESP_OKAY   : std_logic_vector(1 downto 0) := "00";
  constant C_RESP_EXOKAY : std_logic_vector(1 downto 0) := "01";
  constant C_RESP_SLVERR : std_logic_vector(1 downto 0) := "10";
  constant C_RESP_DECERR : std_logic_vector(1 downto 0) := "11";

  -- Tipos de rafaga
  constant C_BURST_FIXED : std_logic_vector(1 downto 0) := "00";
  constant C_BURST_INCR  : std_logic_vector(1 downto 0) := "01";
  constant C_BURST_WRAP  : std_logic_vector(1 downto 0) := "10";

  -- Mapa de registros del slave (offsets dentro de la ventana de 64K)
  constant C_REG_CTRL   : natural := 16#00#;
  constant C_REG_STATUS : natural := 16#04#;
  constant C_REG_ID     : natural := 16#08#;
  constant C_REG_BASE   : natural := 16#0C#;
  constant C_REG_ERRCODE: natural := 16#10#;

  constant C_ID_VALUE   : std_logic_vector(31 downto 0) := x"4E505531"; -- "NPU1"

  -- Mapa del buffer en DDR, offsets desde BASE_ADDR
  constant C_OFF_W1  : natural := 16#000000#;
  constant C_OFF_B1  : natural := 16#000100#;
  constant C_OFF_W2  : natural := 16#001000#;
  constant C_OFF_B2  : natural := 16#001800#;
  constant C_OFF_W3  : natural := 16#002000#;
  constant C_OFF_B3  : natural := 16#002C00#;
  constant C_OFF_IMG : natural := 16#010000#;
  constant C_OFF_RES : natural := 16#020000#;

  -- Cuentas de elementos
  constant C_N_W1  : natural := 72;
  constant C_N_B1  : natural := 8;
  constant C_N_W2  : natural := 1152;
  constant C_N_B2  : natural := 16;
  constant C_N_W3  : natural := 2560;
  constant C_N_B3  : natural := 10;
  constant C_N_IMG : natural := 256;

  -- Longitud maxima de rafaga del master: 16 transferencias de 4 bytes = 64 B,
  -- muy por debajo de la frontera de 4 KB de AXI.
  constant C_MAX_BURST : natural := 16;

end package npu_axi_pkg;
