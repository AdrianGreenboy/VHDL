-- ============================================================================
-- pcie_mmio_pkg.vhd -- PCIE IP v1
-- Mapa de registros MMIO del periferico PCIe, accesible por el RV32 via la
-- interfaz dmem (AXI-Lite en silicio, base 0x80000000). Offsets en bytes.
--
-- CONTRATO CRITICO (bug documentado en la familia): el rdata del banco debe ser
-- COMBINACIONAL (mux directo del registro seleccionado), nunca registrado. Un
-- rdata registrado pasa la verificacion de Layer 2 (banco aislado) pero falla en
-- Layer 4 (SoC real) porque cada 'lw' devuelve el dato de la lectura anterior.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;

package pcie_mmio_pkg is

  -- offsets (byte address, alineados a 4)
  constant REG_CONTROL   : integer := 16#00#;
  constant REG_STATUS    : integer := 16#04#;
  constant REG_IRQ_STAT  : integer := 16#08#;
  constant REG_IRQ_EN    : integer := 16#0C#;
  constant REG_TX_DATA   : integer := 16#10#;
  constant REG_TX_CTRL   : integer := 16#14#;
  constant REG_RX_DATA   : integer := 16#18#;
  constant REG_RX_CTRL   : integer := 16#1C#;
  constant REG_BAR0_LAST : integer := 16#20#;
  constant REG_MWR_CNT   : integer := 16#24#;
  constant REG_MRD_CNT   : integer := 16#28#;
  constant REG_GOOD_RX   : integer := 16#2C#;
  constant REG_MSI_ADDR  : integer := 16#30#;
  constant REG_MSI_DATA  : integer := 16#34#;
  constant REG_FC_STAT   : integer := 16#38#;   -- creditos de flow control
  constant REG_DBG_STATE : integer := 16#44#;   -- patron DBG_STATE de la familia

  -- CONTROL bits
  constant C_START   : integer := 0;
  constant C_HOTRST  : integer := 1;
  constant C_MSITRIG : integer := 2;
  constant C_ISRC    : integer := 3;

  -- STATUS bits
  constant S_LINKUP  : integer := 0;   -- bit 0
  -- bits [7:4] = ltssm_state ; bit 8 = tx_busy

  -- IRQ bits (sticky, W1C)
  constant I_TLP_RX  : integer := 0;
  constant I_CPL_RX  : integer := 1;
  constant I_MSI_TX  : integer := 2;
  constant I_REPLAY  : integer := 3;

  -- TX_CTRL bits
  constant T_PUSHLAST : integer := 0;  -- escribir '1' marca el ultimo byte

  -- RX_CTRL bits
  constant R_EMPTY : integer := 0;

end package;
