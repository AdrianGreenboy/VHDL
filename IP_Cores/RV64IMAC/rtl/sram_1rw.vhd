-- sram_1rw.vhd - SRAM de un puerto, lectura sincrona, escritura con mascara de bits.
-- Modelo comportamental. En el flujo ASIC (IHP SG13G2) se sustituye por la macro
-- equivalente (p. ej. 1024x64 con bitmask) con la misma interfaz y latencia 1.
-- Durante una escritura la salida q no esta definida (el core nunca la usa).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sram_1rw is
  generic (
    ABITS : positive := 10;
    WIDTH : positive := 64
  );
  port (
    clk   : in  std_logic;
    en    : in  std_logic;
    we    : in  std_logic;
    addr  : in  std_logic_vector(ABITS - 1 downto 0);
    wdata : in  std_logic_vector(WIDTH - 1 downto 0);
    wmask : in  std_logic_vector(WIDTH - 1 downto 0);
    q     : out std_logic_vector(WIDTH - 1 downto 0)
  );
end entity;

architecture behav of sram_1rw is
  type mem_t is array (0 to 2 ** ABITS - 1) of std_logic_vector(WIDTH - 1 downto 0);
  signal mem : mem_t;
begin
  process (clk)
    variable a : natural;
  begin
    if rising_edge(clk) then
      if en = '1' then
        a := to_integer(unsigned(addr));
        if we = '1' then
          mem(a) <= (mem(a) and not wmask) or (wdata and wmask);
          q <= (others => 'X');
        else
          q <= mem(a);
        end if;
      end if;
    end if;
  end process;
end architecture;
