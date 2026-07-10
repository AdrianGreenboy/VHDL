-- eth_pkg.vhd — familia TSN Ethernet, MAC 10/100 v1
-- CRC-32 Ethernet: polinomio 0x04C11DB7 reflejado (0xEDB88320),
-- init 0xFFFFFFFF, complemento final. Procesado por NIBBLE, LSB primero,
-- que es exactamente el orden del datapath MII (nibble bajo primero).
library ieee;
use ieee.std_logic_1164.all;

package eth_pkg is

  constant CRC32_INIT : std_logic_vector(31 downto 0) := x"FFFFFFFF";

  -- Actualiza el CRC con un nibble (bit 0 del nibble primero).
  function crc32_nibble(crc : std_logic_vector(31 downto 0);
                        nib : std_logic_vector(3 downto 0))
    return std_logic_vector;

end package eth_pkg;

package body eth_pkg is

  function crc32_nibble(crc : std_logic_vector(31 downto 0);
                        nib : std_logic_vector(3 downto 0))
    return std_logic_vector is
    variable c : std_logic_vector(31 downto 0) := crc;
  begin
    for i in 0 to 3 loop
      if (c(0) xor nib(i)) = '1' then
        c := ('0' & c(31 downto 1)) xor x"EDB88320";
      else
        c := '0' & c(31 downto 1);
      end if;
    end loop;
    return c;
  end function;

end package body eth_pkg;
