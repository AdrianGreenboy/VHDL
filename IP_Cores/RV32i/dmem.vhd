-- =============================================================================
--  dmem.vhd  -  Memoria de datos para el datapath single-cycle
--  Licencia: MIT
--
--  Organizada por palabras con habilitacion por byte (wstrb), lo que permite
--  SB/SH/SW. Escritura sincrona, lectura asincrona (la palabra alineada aparece
--  de forma combinacional). El alineamiento y la extension de sub-palabra los
--  maneja el datapath; aqui solo se escriben los bytes indicados por wstrb.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.riscv_pkg.all;

entity dmem is
  generic (
    DEPTH : natural := 256               -- numero de palabras
  );
  port (
    clk   : in  std_logic;
    addr  : in  word_t;                  -- direccion de byte (se usa [.. :2])
    wdata : in  word_t;                  -- dato a escribir (ya alineado)
    wstrb : in  std_logic_vector(3 downto 0);  -- byte enables
    rdata : out word_t                   -- palabra alineada leida
  );
end entity dmem;

architecture rtl of dmem is
  type mem_t is array (0 to DEPTH-1) of word_t;
  signal mem : mem_t := (others => (others => '0'));

  constant IDX_HI : natural := 1 + integer(ceil(log2(real(DEPTH))));
  signal widx : natural range 0 to DEPTH-1;
begin
  widx <= to_integer(unsigned(addr(IDX_HI downto 2)));

  process(clk)
  begin
    if rising_edge(clk) then
      for byte in 0 to 3 loop
        if wstrb(byte) = '1' then
          mem(widx)(byte*8+7 downto byte*8) <= wdata(byte*8+7 downto byte*8);
        end if;
      end loop;
    end if;
  end process;

  rdata <= mem(widx);
end architecture rtl;
