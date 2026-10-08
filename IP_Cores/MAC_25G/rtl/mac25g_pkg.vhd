-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Paquete comun: constantes de bloque cl.49, CRC-32 Ethernet y xorshift64.
--
-- El CRC usa las ecuaciones XOR explicitas y balanceadas de mac25g_crc_pkg
-- (generadas desde el oraculo): la forma recursiva bit a bit comparte nodos
-- entre bits y Vivado la implemento con 10-11 niveles de LUT a 390.625 MHz.
-- Deliberadamente NO hay tablas/constantes indexadas por senal (leccion de
-- Vivado 2025.2.1 en esta familia: las busquedas indexadas en constantes se
-- sintetizaron mal en silicio). Los tipos de bloque Tn se eligen con 'case'.
--
-- Convencion de bits (identica al Core 19 y al oraculo):
--   payload de 64 bits, byte i en (8i+7 downto 8i), el bit 0 sale primero.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_crc_pkg.all;

package mac25g_pkg is

  -- ---- bloques 64B/66B (IEEE 802.3 cl.49, Figura 49-7) ----
  constant BT_IDLE   : std_logic_vector(7 downto 0) := x"1E";
  constant BT_START0 : std_logic_vector(7 downto 0) := x"78";
  constant BT_START4 : std_logic_vector(7 downto 0) := x"33";
  constant BT_OSST4  : std_logic_vector(7 downto 0) := x"66";
  constant BT_OS0    : std_logic_vector(7 downto 0) := x"4B";
  constant BT_OSOS   : std_logic_vector(7 downto 0) := x"55";
  constant BT_OS4    : std_logic_vector(7 downto 0) := x"2D";

  -- /S/ en carril 0 + 6x preambulo 0x55 + SFD 0xD5
  constant START_BLOCK : std_logic_vector(63 downto 0) := x"D555555555555578";
  -- tipo 0x1E con los 8 caracteres de control a /I/ (0x00)
  constant IDLE_BLOCK  : std_logic_vector(63 downto 0) := x"000000000000001E";
  -- tipo 0x1E con los 8 caracteres de control a /E/ (0x1E, 7 bits cada uno)
  constant ERROR_BLOCK : std_logic_vector(63 downto 0) := x"3C78F1E3C78F1E1E";

  -- ---- CRC-32 Ethernet, forma reflejada ----
  constant CRC_POLY_R  : std_logic_vector(31 downto 0) := x"EDB88320";
  constant CRC_INIT    : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  constant CRC_RESIDUE : std_logic_vector(31 downto 0) := x"DEBB20E3";

  -- ---- tramas ----
  constant ETHERTYPE_GEN : std_logic_vector(15 downto 0) := x"88B5";
  constant MIN_FRAME     : natural := 64;     -- incluye FCS
  constant MAX_FRAME     : natural := 1522;   -- incluye FCS (admite VLAN)
  constant GEN_MIN_LEN   : natural := 20;     -- cabecera del generador

  -- tipo de bloque de terminacion T0..T7 (case, no tabla indexada)
  function term_type(n : natural range 0 to 7) return std_logic_vector;

  -- CRC sobre los 'nbits' bits bajos de d (bit 0 primero). nbits constante.
  function crc_upd(crc : std_logic_vector(31 downto 0);
                   d   : std_logic_vector(63 downto 0);
                   nbits : natural) return std_logic_vector;

  -- las 8 variantes (1..8 bytes) en paralelo, para registrarlas y elegir
  -- despues (el CRC parcial de la ultima palabra va en dos etapas)
  type crc_var_t is array (1 to 8) of std_logic_vector(31 downto 0);
  function crc_variants(crc : std_logic_vector(31 downto 0);
                        d   : std_logic_vector(63 downto 0)) return crc_var_t;

  -- CRC sobre los n bytes bajos de d, n = 1..8 (referencia, una etapa).
  function crc_nbytes(crc : std_logic_vector(31 downto 0);
                      d   : std_logic_vector(63 downto 0);
                      n   : unsigned(3 downto 0)) return std_logic_vector;

  -- xorshift64 (13, 7, 17)
  function xorshift64(x : std_logic_vector(63 downto 0)) return std_logic_vector;

  -- semilla del patron de payload a partir del numero de secuencia
  function seed_of(seq : std_logic_vector(31 downto 0)) return std_logic_vector;

  -- mascara de bytes validos: bytes con indice < n a '1'
  function byte_mask(n : unsigned(3 downto 0)) return std_logic_vector;

  -- tkeep contiguo (LSB primero) -> numero de bytes 1..8
  function keep_to_n(k : std_logic_vector(7 downto 0)) return unsigned;

  -- numero de bytes 1..8 -> tkeep contiguo
  function n_to_keep(n : unsigned(3 downto 0)) return std_logic_vector;

end package mac25g_pkg;

package body mac25g_pkg is

  function term_type(n : natural range 0 to 7) return std_logic_vector is
    variable t : std_logic_vector(7 downto 0);
  begin
    case n is
      when 0 => t := x"87";
      when 1 => t := x"99";
      when 2 => t := x"AA";
      when 3 => t := x"B4";
      when 4 => t := x"CC";
      when 5 => t := x"D2";
      when 6 => t := x"E1";
      when others => t := x"FF";
    end case;
    return t;
  end function;

  function crc_upd(crc : std_logic_vector(31 downto 0);
                   d   : std_logic_vector(63 downto 0);
                   nbits : natural) return std_logic_vector is
    variable r : std_logic_vector(31 downto 0);
  begin
    case nbits is
      when 8      => r := crc_d8(crc, d);
      when 16     => r := crc_d16(crc, d);
      when 24     => r := crc_d24(crc, d);
      when 32     => r := crc_d32(crc, d);
      when 40     => r := crc_d40(crc, d);
      when 48     => r := crc_d48(crc, d);
      when 56     => r := crc_d56(crc, d);
      when others => r := crc_d64(crc, d);
    end case;
    return r;
  end function;

  function crc_variants(crc : std_logic_vector(31 downto 0);
                        d   : std_logic_vector(63 downto 0)) return crc_var_t is
    variable v : crc_var_t;
  begin
    v(1) := crc_d8(crc, d);  v(2) := crc_d16(crc, d);
    v(3) := crc_d24(crc, d); v(4) := crc_d32(crc, d);
    v(5) := crc_d40(crc, d); v(6) := crc_d48(crc, d);
    v(7) := crc_d56(crc, d); v(8) := crc_d64(crc, d);
    return v;
  end function;

  function crc_nbytes(crc : std_logic_vector(31 downto 0);
                      d   : std_logic_vector(63 downto 0);
                      n   : unsigned(3 downto 0)) return std_logic_vector is
    variable r : std_logic_vector(31 downto 0);
  begin
    case to_integer(n) is
      when 1      => r := crc_upd(crc, d, 8);
      when 2      => r := crc_upd(crc, d, 16);
      when 3      => r := crc_upd(crc, d, 24);
      when 4      => r := crc_upd(crc, d, 32);
      when 5      => r := crc_upd(crc, d, 40);
      when 6      => r := crc_upd(crc, d, 48);
      when 7      => r := crc_upd(crc, d, 56);
      when others => r := crc_upd(crc, d, 64);
    end case;
    return r;
  end function;

  function xorshift64(x : std_logic_vector(63 downto 0)) return std_logic_vector is
    variable v : unsigned(63 downto 0) := unsigned(x);
  begin
    v := v xor shift_left(v, 13);
    v := v xor shift_right(v, 7);
    v := v xor shift_left(v, 17);
    return std_logic_vector(v);
  end function;

  function seed_of(seq : std_logic_vector(31 downto 0)) return std_logic_vector is
  begin
    return x"9E3779B97F4A7C15" xor (x"00000000" & seq);
  end function;

  function byte_mask(n : unsigned(3 downto 0)) return std_logic_vector is
    variable m : std_logic_vector(63 downto 0) := (others => '0');
  begin
    for b in 0 to 7 loop
      if to_unsigned(b, 4) < n then
        m(8*b+7 downto 8*b) := (others => '1');
      end if;
    end loop;
    return m;
  end function;

  function keep_to_n(k : std_logic_vector(7 downto 0)) return unsigned is
    variable n : unsigned(3 downto 0);
  begin
    case k is
      when "00000001" => n := to_unsigned(1, 4);
      when "00000011" => n := to_unsigned(2, 4);
      when "00000111" => n := to_unsigned(3, 4);
      when "00001111" => n := to_unsigned(4, 4);
      when "00011111" => n := to_unsigned(5, 4);
      when "00111111" => n := to_unsigned(6, 4);
      when "01111111" => n := to_unsigned(7, 4);
      when others     => n := to_unsigned(8, 4);
    end case;
    return n;
  end function;

  function n_to_keep(n : unsigned(3 downto 0)) return std_logic_vector is
    variable k : std_logic_vector(7 downto 0) := (others => '0');
  begin
    for b in 0 to 7 loop
      if to_unsigned(b, 4) < n then
        k(b) := '1';
      end if;
    end loop;
    return k;
  end function;

end package body mac25g_pkg;
