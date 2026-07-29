-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- byte_mem_d: byte-addressed scratch for the ML-DSA sequencer.
-- VHDL-2008. ASCII-only. MIT license.
--
-- 16 KB, 14-bit addresses. The map in dsa_sign.vhd tops out at 11500 for the
-- signature, so this leaves room without another widening: the ML-KEM phase
-- lost time to a 12-to-13 bit address change that also caught two unrelated
-- 12-bit data fields, and the fix there was to size generously once.
--
-- Modelled as an array of integer rather than std_logic_vector, because
-- aggregate initialisers over large vector arrays segfault GHDL at this size.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity byte_mem_d is
  port (
    clk  : in  std_logic;
    addr : in  std_logic_vector(13 downto 0);
    din  : in  std_logic_vector(7 downto 0);
    we   : in  std_logic;
    dout : out std_logic_vector(7 downto 0));
end entity byte_mem_d;

architecture rtl of byte_mem_d is
  type t_mem is array (0 to 16383) of integer;
  signal mem : t_mem := (others => 0);
begin
  process (clk)
    variable a : integer;
  begin
    if rising_edge(clk) then
      a := to_integer(unsigned(addr));
      dout <= std_logic_vector(to_unsigned(mem(a), 8));
      if we = '1' then
        mem(a) <= to_integer(unsigned(din));
      end if;
    end if;
  end process;
end architecture rtl;
