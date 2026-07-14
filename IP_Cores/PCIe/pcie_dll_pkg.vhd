-- ============================================================================
-- pcie_dll_pkg.vhd -- PCIE IP v1
-- Data Link Layer: funciones de CRC y tipos.
--
-- LCRC-32 (TLP): polinomio 0x04C11DB7 (CRC-32 de Ethernet), seed 0xFFFFFFFF.
--   Se alimenta: 4 bits reservados + 12 bits de seq (16b) como primeros dos
--   bytes, seguidos de los bytes del TLP. El resultado se COMPLEMENTA y se
--   BIT-REVIERTE por byte (bit0<->bit7). (PCIe Base Spec, seccion DLL.)
-- CRC-16 (DLLP): polinomio 0x100B, seed 0xFFFF, mismas reglas de complemento
--   y bit-reverse por byte.
--
-- Ambas se implementan bit a bit (f_crc32_byte / f_crc16_byte) para claridad y
-- verificabilidad; el rendimiento a 100 MHz sobra (un byte/ciclo).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pcie_dll_pkg is

  subtype byte_t  is std_logic_vector(7 downto 0);
  subtype crc32_t is std_logic_vector(31 downto 0);
  subtype crc16_t is std_logic_vector(15 downto 0);
  subtype seq_t   is unsigned(11 downto 0);          -- 12 bits

  constant LCRC_POLY : crc32_t := x"04C11DB7";
  constant LCRC_SEED : crc32_t := x"FFFFFFFF";
  constant DCRC_POLY : crc16_t := x"100B";
  constant DCRC_SEED : crc16_t := x"FFFF";

  -- Actualiza el CRC-32 con un byte (MSB primero).
  function f_crc32_byte(crc : crc32_t; d : byte_t) return crc32_t;
  -- Actualiza el CRC-16 con un byte (MSB primero).
  function f_crc16_byte(crc : crc16_t; d : byte_t) return crc16_t;
  -- Invierte los bits de un byte (bit0<->bit7).
  function f_bitrev8(d : byte_t) return byte_t;
  -- Finaliza LCRC: complementa y bit-reversa por byte -> 4 bytes en orden de
  -- transmision (byte 0 primero).
  function f_lcrc_final(crc : crc32_t) return crc32_t;
  function f_dcrc_final(crc : crc16_t) return crc16_t;

  -- Tipos de DLLP soportados en v1.
  type dllp_kind_t is (DL_ACK, DL_NAK, DL_INITFC1, DL_INITFC2, DL_UPDATEFC,
                       DL_UNKNOWN);

  -- Codificacion del primer byte del DLLP (subset PCIe).
  constant DB_ACK      : byte_t := x"00";
  constant DB_NAK      : byte_t := x"10";
  constant DB_INITFC1P : byte_t := x"40";   -- InitFC1-P (posted)
  constant DB_INITFC2P : byte_t := x"C0";   -- InitFC2-P
  constant DB_UPDATEFCP: byte_t := x"80";   -- UpdateFC-P

  -- Creditos de flow control (v1: solo categoria P/posted, hdr+data).
  constant FC_HDR_INIT  : integer := 16;    -- creditos de cabecera iniciales
  constant FC_DATA_INIT : integer := 64;    -- creditos de datos iniciales

end package;

package body pcie_dll_pkg is

  function f_bitrev8(d : byte_t) return byte_t is
    variable r : byte_t;
  begin
    for i in 0 to 7 loop r(i) := d(7 - i); end loop;
    return r;
  end function;

  function f_crc32_byte(crc : crc32_t; d : byte_t) return crc32_t is
    variable c : crc32_t := crc;
    variable fb : std_logic;
  begin
    -- MSB del byte primero; CRC estandar (feed en el bit alto)
    for i in 7 downto 0 loop
      fb := c(31) xor d(i);
      c := c(30 downto 0) & '0';
      if fb = '1' then
        c := c xor LCRC_POLY;
      end if;
    end loop;
    return c;
  end function;

  function f_crc16_byte(crc : crc16_t; d : byte_t) return crc16_t is
    variable c : crc16_t := crc;
    variable fb : std_logic;
  begin
    for i in 7 downto 0 loop
      fb := c(15) xor d(i);
      c := c(14 downto 0) & '0';
      if fb = '1' then
        c := c xor DCRC_POLY;
      end if;
    end loop;
    return c;
  end function;

  function f_lcrc_final(crc : crc32_t) return crc32_t is
    variable inv : crc32_t;
    variable r   : crc32_t;
  begin
    inv := not crc;
    -- bit-reverse por byte; byte de transmision 0 = inv(7..0) reversado
    r(7  downto 0)  := f_bitrev8(inv(7  downto 0));
    r(15 downto 8)  := f_bitrev8(inv(15 downto 8));
    r(23 downto 16) := f_bitrev8(inv(23 downto 16));
    r(31 downto 24) := f_bitrev8(inv(31 downto 24));
    return r;
  end function;

  function f_dcrc_final(crc : crc16_t) return crc16_t is
    variable inv : crc16_t;
    variable r   : crc16_t;
  begin
    inv := not crc;
    r(7  downto 0) := f_bitrev8(inv(7  downto 0));
    r(15 downto 8) := f_bitrev8(inv(15 downto 8));
    return r;
  end function;

end package body;
