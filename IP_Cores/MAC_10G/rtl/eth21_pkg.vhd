-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT (MAC 10G/25G sobre GTYP real)
-- Paquete comun: constantes IPv4/UDP del generador y utilidades.
--
-- Formato de trama del generador (bytes en orden de cable, sin FCS):
--    0.. 5  MAC destino (PEER_MAC)        6..11  MAC origen (OWN_MAC)
--   12..13  0x0800 (IPv4)
--   14..33  cabecera IPv4: 45 00 | tot_len | id=seq[15:0] | 40 00 (DF) |
--           TTL 64 | proto 17 | checksum | OWN_IP | PEER_IP
--   34..41  UDP: src_port | dst_port | udp_len | checksum 0x0000
--   42..    payload (L bytes, 18 <= L <= 1472):
--             P0 = (~seq & seq) en little endian (bytes 0..3 seq, 4..7 ~seq)
--             P1 = seed_of(seq), Pk+1 = xorshift64(Pk)   (8 bytes LE cada uno)
-- Las MAC de 48 bits llevan el byte 0 del cable en bits 7:0 (como Core 20).
-- Las IP se dan en valor numerico (192.168.21.2 = 0xC0A81502) y salen en
-- big endian.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package eth21_pkg is

  constant UDP_HDR_BYTES : natural := 42;    -- Eth 14 + IPv4 20 + UDP 8
  constant PAY_MIN       : natural := 18;    -- 42 + 18 = 60 (trama minima sin FCS)
  constant PAY_MAX       : natural := 1472;  -- 42 + 1472 = 1514

  -- suma constante de la cabecera IPv4 (sin tot_len, id ni checksum):
  -- 0x4500 + 0x4000 + 0x4011 = 0xC511, mas las dos IP en palabras de 16 bits
  function ip_const_sum(sip, dip : std_logic_vector(31 downto 0)) return unsigned;

  -- invierte el orden de los bits de un vector
  function bitrev(v : std_logic_vector) return std_logic_vector;

  -- bytes de un valor de 16 bits en big endian dentro de una palabra LE:
  -- devuelve (byte bajo del cable en 7:0) = v(15:8), (siguiente) = v(7:0)
  function be16(v : std_logic_vector(15 downto 0)) return std_logic_vector;

end package eth21_pkg;

package body eth21_pkg is

  function ip_const_sum(sip, dip : std_logic_vector(31 downto 0)) return unsigned is
    variable s : unsigned(19 downto 0);
  begin
    s := to_unsigned(16#C511#, 20)
         + resize(unsigned(sip(31 downto 16)), 20) + resize(unsigned(sip(15 downto 0)), 20)
         + resize(unsigned(dip(31 downto 16)), 20) + resize(unsigned(dip(15 downto 0)), 20);
    return s;
  end function;

  function bitrev(v : std_logic_vector) return std_logic_vector is
    variable r : std_logic_vector(v'range);
  begin
    for i in v'low to v'high loop
      r(v'high - (i - v'low)) := v(i);
    end loop;
    return r;
  end function;

  function be16(v : std_logic_vector(15 downto 0)) return std_logic_vector is
  begin
    return v(7 downto 0) & v(15 downto 8);
  end function;

end package body eth21_pkg;
