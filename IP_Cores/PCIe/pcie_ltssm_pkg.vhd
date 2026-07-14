-- ============================================================================
-- pcie_ltssm_pkg.vhd -- PCIE IP v1
-- Tipos y constantes del LTSSM y del deframer RX. Subconjunto de estados v1:
--   DETECT -> POLLING -> CONFIG -> L0, con RECOVERY, HOT_RESET, LOOPBACK,
--   DISABLED. x1, Gen1 (2.5 GT/s logico). BMCA no incluido (rol por registro).
--
-- Formato TS1/TS2 (16 simbolos, verificado contra PCIe Base Spec):
--   sym0 = COM
--   sym1 = Link Number  (PAD si no configurado)
--   sym2 = Lane Number  (PAD si no configurado)
--   sym3 = N_FTS
--   sym4 = Data Rate ID  (0x02 = 2.5 Gbps)
--   sym5 = Training Control (bit0 HotReset, bit1 DisableLink, bit2 Loopback,
--                            bit3 DisableScrambling)
--   sym6..15 = TS ID: 0x4A (D10.2) para TS1, 0x45 (D5.2) para TS2
--
-- Decision de diseño v1 (documentada): los simbolos 1..15 de los TS se envian
-- SIN scrambling (tx_bypass='1') pero el LFSR avanza igual. Es autoconsistente
-- en loopback (ambos extremos comparten convencion) y simplifica el deframe de
-- los campos de training sin perder ninguna funcion del LTSSM.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pcie_ltssm_pkg is

  subtype byte_t is std_logic_vector(7 downto 0);

  type ltssm_t is (LT_DETECT, LT_POLLING, LT_CONFIG, LT_L0,
                   LT_RECOVERY, LT_HOTRESET, LT_LOOPBACK, LT_DISABLED);

  -- Codificacion de estado para el registro STATUS (4 bits)
  function ltssm_code(s : ltssm_t) return std_logic_vector;

  constant TS_LEN     : integer := 16;
  constant TS1_ID     : byte_t := x"4A";   -- D10.2
  constant TS2_ID     : byte_t := x"45";   -- D5.2
  constant RATE_2G5   : byte_t := x"02";   -- D2.0
  constant PAD_BYTE   : byte_t := x"F7";   -- K23.7 (mismo valor que K_PAD)

  -- Bits de Training Control
  constant TC_HOTRESET : integer := 0;
  constant TC_DISLINK  : integer := 1;
  constant TC_LOOPBACK : integer := 2;
  constant TC_DISSCRAM : integer := 3;

  -- Umbrales de entrenamiento (reducidos vs spec real de 8/16, pero misma
  -- logica; parametrizables). Conteos pequenos aceleran la sim de loopback.
  constant N_TS_POLL   : integer := 8;   -- TS1 consecutivos para salir Polling
  constant N_TS_CFG    : integer := 8;   -- TS2 consecutivos para salir Config

  -- Tipo de token que entrega el deframer RX hacia las capas superiores.
  type rx_kind_t is (RK_NONE, RK_TLP_START, RK_TLP_DATA, RK_TLP_END,
                     RK_TLP_ABORT, RK_DLLP_START, RK_DLLP_DATA, RK_DLLP_END,
                     RK_TS1, RK_TS2, RK_SKP, RK_IDLE, RK_EIOS, RK_ERR);

end package;

package body pcie_ltssm_pkg is
  function ltssm_code(s : ltssm_t) return std_logic_vector is
  begin
    case s is
      when LT_DETECT   => return x"0";
      when LT_POLLING  => return x"1";
      when LT_CONFIG   => return x"2";
      when LT_L0       => return x"3";
      when LT_RECOVERY => return x"4";
      when LT_HOTRESET => return x"5";
      when LT_LOOPBACK => return x"6";
      when LT_DISABLED => return x"7";
    end case;
  end function;
end package body;
