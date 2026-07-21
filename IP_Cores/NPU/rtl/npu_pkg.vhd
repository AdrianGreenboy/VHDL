-- HERCOSSNUX NPU - paquete comun (spec HXQ8)
-- VHDL-2008. Mensajes de assert ASCII puro.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package npu_pkg is

  -- Anchos congelados por la spec HXQ8
  constant C_DATA_W  : natural := 8;   -- activaciones y pesos int8
  constant C_ACC_W   : natural := 32;  -- acumulador int32
  constant C_MULT_W  : natural := 32;  -- multiplicador de requantize int32
  constant C_SHIFT   : natural := 31;  -- shift fijo de requantize

  subtype t_data is signed(C_DATA_W-1 downto 0);
  subtype t_acc  is signed(C_ACC_W-1 downto 0);

  type t_data_arr is array (natural range <>) of t_data;
  type t_acc_arr  is array (natural range <>) of t_acc;

  -- Firma FNV-1a de 32 bits sobre el byte bajo de cada valor.
  constant C_SIG_INIT  : unsigned(31 downto 0) := x"811C9DC5";
  constant C_SIG_PRIME : unsigned(31 downto 0) := x"01000193";

  function sig_update (sig : unsigned(31 downto 0); v : signed) return unsigned;

end package npu_pkg;

package body npu_pkg is

  -- 'v' puede llegar como slice con indices arbitrarios (p.ej. 15 downto 8);
  -- el alias 'va' lo renormaliza a un rango descendente basado en cero.
  function sig_update (sig : unsigned(31 downto 0); v : signed) return unsigned is
    alias    va   : signed(v'length-1 downto 0) is v;
    variable prod : unsigned(63 downto 0);
    variable low  : unsigned(31 downto 0);
    variable byte : unsigned(31 downto 0);
    variable sum  : unsigned(32 downto 0);
  begin
    prod := sig * C_SIG_PRIME;                 -- 64 bits
    low  := prod(31 downto 0);                 -- mod 2^32
    byte := (others => '0');
    byte(7 downto 0) := unsigned(va(7 downto 0));
    sum  := ('0' & low) + ('0' & byte);        -- 33 bits: absorbe el acarreo
    return sum(31 downto 0);                   -- mod 2^32
  end function;

end package body npu_pkg;
