-- tsn_pkg.vhd - Tipos compartidos del switch TSN 4x4
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tsn_pkg is
  type byte_arr4 is array (0 to 3) of std_logic_vector(7 downto 0);
  type mac_arr4  is array (0 to 3) of std_logic_vector(47 downto 0);
  type len_arr4  is array (0 to 3) of unsigned(10 downto 0);
end package;
