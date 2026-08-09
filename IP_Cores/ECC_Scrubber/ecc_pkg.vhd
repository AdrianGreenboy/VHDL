-- ecc_pkg.vhd - Constantes del ECC SECDED (39,32) de HERCOSSNUX Core 20.
-- Codigo Hamming extendido: 32 dato + 6 paridad Hamming + 1 overall = 39 bits.
-- Posiciones Hamming 1-indexadas 1..38; paridad en potencias de 2 {1,2,4,8,16,32}.
-- Empaquetado: ecc_word(37 downto 0) = posiciones Hamming 1..38 (bit0=pos1),
--              ecc_word(38)          = paridad global (overall).
library ieee;
use ieee.std_logic_1164.all;

package ecc_pkg is
  constant DATA_W : natural := 32;   -- bits de dato
  constant POS_N  : natural := 38;   -- posiciones Hamming 1..38
  constant ECC_W  : natural := 39;   -- palabra ECC total (38 + overall)

  subtype data_t is std_logic_vector(DATA_W-1 downto 0);
  subtype ecc_t  is std_logic_vector(ECC_W-1  downto 0);

  -- posiciones de paridad Hamming (1-indexadas)
  type int_array is array (natural range <>) of natural;
  constant PARITY_POS : int_array(0 to 5) := (1, 2, 4, 8, 16, 32);

  -- funcion: devuelve las 32 posiciones Hamming de dato (las no-potencia-de-2)
  -- en orden ascendente. data_pos(i) = posicion Hamming del bit de dato i.
  function make_data_pos return int_array;
  constant DATA_POS : int_array(0 to DATA_W-1);
end package;

package body ecc_pkg is
  function is_power_of_two(n : natural) return boolean is
  begin
    for i in 0 to 5 loop
      if n = PARITY_POS(i) then
        return true;
      end if;
    end loop;
    return false;
  end function;

  function make_data_pos return int_array is
    variable r   : int_array(0 to DATA_W-1);
    variable idx : natural := 0;
  begin
    for p in 1 to POS_N loop
      if not is_power_of_two(p) then
        r(idx) := p;
        idx := idx + 1;
      end if;
    end loop;
    return r;
  end function;

  constant DATA_POS : int_array(0 to DATA_W-1) := make_data_pos;
end package body;
