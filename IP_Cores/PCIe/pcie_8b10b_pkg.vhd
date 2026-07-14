-- ============================================================================
-- pcie_8b10b_pkg.vhd -- PCIE IP v1 (SoC RV32IM, familia VHDL-2008)
-- Paquete base del codec 8b/10b: tablas explicitas 5b/6b y 3b/4b para RD- y
-- RD+ (sin reglas de derivacion: ambas columnas literales, menos propenso a
-- error), funcion de codificacion pura f_enc y constantes de simbolos K de
-- PCIe Gen1/Gen2.
--
-- Orden de bits del simbolo de 10 bits: code(9)='a' (primero en el cable) ...
-- code(0)='j' (ultimo). La serializacion es MSB-first sobre este vector.
-- RD ('0' = RD-, '1' = RD+). Reset: RD-.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pcie_8b10b_pkg is

  subtype sym10_t is std_logic_vector(9 downto 0);
  subtype byte_t  is std_logic_vector(7 downto 0);

  type enc_res_t is record
    code : sym10_t;     -- simbolo codificado
    rd   : std_logic;   -- running disparity resultante
    err  : std_logic;   -- '1' si (d,k) no es un codigo valido (K ilegal)
  end record;

  -- Codificacion pura: byte + flag K + RD de entrada -> simbolo + RD salida
  function f_enc(d : byte_t; k : std_logic; rd : std_logic) return enc_res_t;

  -- Cuenta de unos (para chequeos de disparidad en tb y decoder)
  function f_ones(v : std_logic_vector) return natural;

  -- Simbolos K usados por PCIe (byte con K='1')
  constant K_COM : byte_t := x"BC";  -- K28.5 comma
  constant K_STP : byte_t := x"FB";  -- K27.7 inicio TLP
  constant K_SDP : byte_t := x"5C";  -- K28.2 inicio DLLP
  constant K_END : byte_t := x"FD";  -- K29.7 fin correcto
  constant K_EDB : byte_t := x"FE";  -- K30.7 fin abortado (nullified)
  constant K_PAD : byte_t := x"F7";  -- K23.7 relleno
  constant K_SKP : byte_t := x"1C";  -- K28.0 skip
  constant K_FTS : byte_t := x"3C";  -- K28.1 fast training sequence
  constant K_IDL : byte_t := x"7C";  -- K28.3 electrical idle ordered set

end package pcie_8b10b_pkg;

package body pcie_8b10b_pkg is

  function f_ones(v : std_logic_vector) return natural is
    variable n : natural := 0;
  begin
    for i in v'range loop
      if v(i) = '1' then n := n + 1; end if;
    end loop;
    return n;
  end function;

  -- Actualizacion de RD tras un sub-bloque: mas unos que ceros -> RD+,
  -- menos -> RD-, igual -> sin cambio.
  function f_rd_upd(rd : std_logic; v : std_logic_vector) return std_logic is
    variable n : natural;
  begin
    n := f_ones(v);
    if 2*n > v'length then return '1';
    elsif 2*n < v'length then return '0';
    else return rd;
    end if;
  end function;

  -- ------------------------------------------------------------------
  -- Tabla 5b/6b: indice x = EDCBA = d(4 downto 0). Literales "abcdei".
  -- ------------------------------------------------------------------
  type t6_t is array (0 to 31) of std_logic_vector(5 downto 0);

  constant D6N : t6_t := (   -- entrada con RD-
    0  => "100111", 1  => "011101", 2  => "101101", 3  => "110001",
    4  => "110101", 5  => "101001", 6  => "011001", 7  => "111000",
    8  => "111001", 9  => "100101", 10 => "010101", 11 => "110100",
    12 => "001101", 13 => "101100", 14 => "011100", 15 => "010111",
    16 => "011011", 17 => "100011", 18 => "010011", 19 => "110010",
    20 => "001011", 21 => "101010", 22 => "011010", 23 => "111010",
    24 => "110011", 25 => "100110", 26 => "010110", 27 => "110110",
    28 => "001110", 29 => "101110", 30 => "011110", 31 => "101011");

  constant D6P : t6_t := (   -- entrada con RD+
    0  => "011000", 1  => "100010", 2  => "010010", 3  => "110001",
    4  => "001010", 5  => "101001", 6  => "011001", 7  => "000111",
    8  => "000110", 9  => "100101", 10 => "010101", 11 => "110100",
    12 => "001101", 13 => "101100", 14 => "011100", 15 => "101000",
    16 => "100100", 17 => "100011", 18 => "010011", 19 => "110010",
    20 => "001011", 21 => "101010", 22 => "011010", 23 => "000101",
    24 => "001100", 25 => "100110", 26 => "010110", 27 => "001001",
    28 => "001110", 29 => "010001", 30 => "100001", 31 => "010100");

  -- K28 es el unico 5b/6b especial; K23/K27/K29/K30 reutilizan D6x.
  constant K28_6N : std_logic_vector(5 downto 0) := "001111";
  constant K28_6P : std_logic_vector(5 downto 0) := "110000";

  -- ------------------------------------------------------------------
  -- Tabla 3b/4b: indice y = HGF = d(7 downto 5). Literales "fghj".
  -- y=7 se maneja aparte (P7/A7).
  -- ------------------------------------------------------------------
  type t4_t is array (0 to 6) of std_logic_vector(3 downto 0);

  constant D4N : t4_t := (0 => "1011", 1 => "1001", 2 => "0101",
                          3 => "1100", 4 => "1101", 5 => "1010",
                          6 => "0110");
  constant D4P : t4_t := (0 => "0100", 1 => "1001", 2 => "0101",
                          3 => "0011", 4 => "0010", 5 => "1010",
                          6 => "0110");

  constant P7N : std_logic_vector(3 downto 0) := "1110";
  constant P7P : std_logic_vector(3 downto 0) := "0001";
  constant A7N : std_logic_vector(3 downto 0) := "0111";
  constant A7P : std_logic_vector(3 downto 0) := "1000";

  -- Tabla 3b/4b para simbolos K (y=0..7): x.1, x.2, x.5, x.6 complementadas
  -- respecto a D para evitar falsas commas; x.7 siempre A7.
  type t4k_t is array (0 to 7) of std_logic_vector(3 downto 0);

  constant K4N : t4k_t := (0 => "1011", 1 => "0110", 2 => "1010",
                           3 => "1100", 4 => "1101", 5 => "0101",
                           6 => "1001", 7 => "0111");
  constant K4P : t4k_t := (0 => "0100", 1 => "1001", 2 => "0101",
                           3 => "0011", 4 => "0010", 5 => "1010",
                           6 => "0110", 7 => "1000");

  function f_enc(d : byte_t; k : std_logic; rd : std_logic) return enc_res_t is
    variable x    : natural range 0 to 31;
    variable y    : natural range 0 to 7;
    variable six  : std_logic_vector(5 downto 0);
    variable four : std_logic_vector(3 downto 0);
    variable rd1  : std_logic;
    variable r    : enc_res_t;
    variable a7   : boolean;
  begin
    x := to_integer(unsigned(d(4 downto 0)));
    y := to_integer(unsigned(d(7 downto 5)));
    r.err := '0';

    if k = '1' then
      -- K validos: K28.0..K28.7, K23.7, K27.7, K29.7, K30.7
      if x = 28 then
        if rd = '0' then six := K28_6N; else six := K28_6P; end if;
      elsif (x = 23 or x = 27 or x = 29 or x = 30) and y = 7 then
        if rd = '0' then six := D6N(x); else six := D6P(x); end if;
      else
        r.err  := '1';
        r.code := (others => '0');
        r.rd   := rd;
        return r;
      end if;
      rd1 := f_rd_upd(rd, six);
      if rd1 = '0' then four := K4N(y); else four := K4P(y); end if;
    else
      if rd = '0' then six := D6N(x); else six := D6P(x); end if;
      rd1 := f_rd_upd(rd, six);
      if y = 7 then
        -- Regla A7: evita run de 5 y falsas commas en la frontera 6b/4b
        a7 := (rd1 = '0' and (x = 17 or x = 18 or x = 20)) or
              (rd1 = '1' and (x = 11 or x = 13 or x = 14));
        if a7 then
          if rd1 = '0' then four := A7N; else four := A7P; end if;
        else
          if rd1 = '0' then four := P7N; else four := P7P; end if;
        end if;
      else
        if rd1 = '0' then four := D4N(y); else four := D4P(y); end if;
      end if;
    end if;

    r.code := six & four;
    r.rd   := f_rd_upd(rd1, four);
    return r;
  end function;

end package body pcie_8b10b_pkg;
