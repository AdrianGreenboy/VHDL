-- ============================================================================
-- pcie_tl_pkg.vhd -- PCIE IP v1
-- Transaction Layer: tipos de TLP, codificacion Fmt/Type, y helpers de
-- construccion/parseo de los DW de cabecera (formato big-endian PCIe: byte 0
-- es el MSB del DW0).
--
-- DW0 (comun):
--   byte0[2:0]=Fmt, byte0[7:3]=Type ; byte1: TC/attr (0 en v1) ;
--   byte2[7]=TD(ECRC), byte3+byte2[1:0] = Length[9:0]
-- Codificacion (verificada contra parser TLP publico):
--   MRd  3DW : Fmt=000 Type=00000 -> DW0 byte0 = 0x00
--   MWr  3DW : Fmt=010 Type=00000 -> byte0 = 0x40
--   MRd  4DW : Fmt=001 -> byte0 = 0x20 ; MWr 4DW: Fmt=011 -> byte0 = 0x60
--   Cpl      : Fmt=000 Type=01010 -> byte0 = 0x0A
--   CplD     : Fmt=010 Type=01010 -> byte0 = 0x4A
--   CfgRd0   : Fmt=000 Type=00100 -> byte0 = 0x04
--   CfgWr0   : Fmt=010 Type=00100 -> byte0 = 0x44
--   MsgD     : Fmt=011 Type=10rrr (rrr=routing) ; v1 solo INTx/PM basicos
-- DW1: ReqID[31:16], Tag[15:8], LastBE[7:4], FirstBE[3:0]
-- DW2 (3DW): Addr[31:2] & "00"
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pcie_tl_pkg is

  subtype byte_t is std_logic_vector(7 downto 0);
  subtype dw_t   is std_logic_vector(31 downto 0);

  type tlp_kind_t is (TK_MRD3, TK_MWR3, TK_MRD4, TK_MWR4,
                      TK_CPL, TK_CPLD, TK_CFGRD0, TK_CFGWR0, TK_MSGD,
                      TK_UNKNOWN);

  -- byte0 (Fmt+Type) por tipo
  constant B0_MRD3   : byte_t := x"00";
  constant B0_MWR3   : byte_t := x"40";
  constant B0_MRD4   : byte_t := x"20";
  constant B0_MWR4   : byte_t := x"60";
  constant B0_CPL    : byte_t := x"0A";
  constant B0_CPLD   : byte_t := x"4A";
  constant B0_CFGRD0 : byte_t := x"04";
  constant B0_CFGWR0 : byte_t := x"44";
  constant B0_MSGD   : byte_t := x"73";   -- Fmt=011, Type=10011 (broadcast)

  -- clasifica el byte0 en un tipo
  function f_kind(b0 : byte_t) return tlp_kind_t;
  -- construye DW0 dado byte0 y length (10 bits)
  function f_dw0(b0 : byte_t; len : integer) return dw_t;
  -- extrae length de un DW0
  function f_len(dw0 : dw_t) return integer;
  -- construye DW1 (reqid, tag, be)
  function f_dw1(reqid : std_logic_vector(15 downto 0); tag : byte_t;
                 lastbe, firstbe : std_logic_vector(3 downto 0)) return dw_t;

  -- Config space Type 0 (offsets DW). v1 minimo.
  constant CFG_VENDOR_ID : std_logic_vector(15 downto 0) := x"1AF4"; -- Red Hat/QEMU-like
  constant CFG_DEVICE_ID : std_logic_vector(15 downto 0) := x"5043"; -- 'PC'
  constant CFG_CLASS     : dw_t := x"05800000";  -- memory controller, rev 0
  -- BAR0: 32-bit, non-prefetchable, mapea una ventana de memoria en el EP.

  -- MSI capability (v1): registro de direccion + dato.
end package;

package body pcie_tl_pkg is

  function f_kind(b0 : byte_t) return tlp_kind_t is
  begin
    case b0 is
      when B0_MRD3   => return TK_MRD3;
      when B0_MWR3   => return TK_MWR3;
      when B0_MRD4   => return TK_MRD4;
      when B0_MWR4   => return TK_MWR4;
      when B0_CPL    => return TK_CPL;
      when B0_CPLD   => return TK_CPLD;
      when B0_CFGRD0 => return TK_CFGRD0;
      when B0_CFGWR0 => return TK_CFGWR0;
      when B0_MSGD   => return TK_MSGD;
      when others    => return TK_UNKNOWN;
    end case;
  end function;

  function f_dw0(b0 : byte_t; len : integer) return dw_t is
    variable r : dw_t;
    variable l : std_logic_vector(9 downto 0);
  begin
    l := std_logic_vector(to_unsigned(len, 10));
    -- byte0 = b0 ; byte1 = 0x00 ; byte2[1:0]=len[9:8] ; byte3=len[7:0]
    r(31 downto 24) := b0;
    r(23 downto 16) := x"00";
    r(15 downto 10) := "000000";
    r(9 downto 0)   := l;
    return r;
  end function;

  function f_len(dw0 : dw_t) return integer is
  begin
    return to_integer(unsigned(dw0(9 downto 0)));
  end function;

  function f_dw1(reqid : std_logic_vector(15 downto 0); tag : byte_t;
                 lastbe, firstbe : std_logic_vector(3 downto 0)) return dw_t is
    variable r : dw_t;
  begin
    r(31 downto 16) := reqid;
    r(15 downto 8)  := tag;
    r(7 downto 4)   := lastbe;
    r(3 downto 0)   := firstbe;
    return r;
  end function;

end package body;
