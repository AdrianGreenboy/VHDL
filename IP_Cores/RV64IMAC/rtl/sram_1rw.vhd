-- sram_1rw.vhd - SRAM de un puerto, lectura sincrona, escritura por bytes.
-- Modelo comportamental. En el flujo ASIC (IHP SG13G2) se sustituye por la macro
-- equivalente (p. ej. 1024x64 con byte-enable) con la misma interfaz y latencia 1.
-- La mascara se interpreta por bytes: wmask(8*b) habilita el byte b (todas las
-- escrituras del core son por bytes). Si WIDTH no es multiplo de 8 (etiquetas), la
-- escritura es de palabra completa con wmask(0).
-- Plantilla de byte-write "no change" (q se conserva durante una escritura): Vivado
-- la infiere como BRAM/URAM con byte-enable. La version anterior hacia
-- lectura-modificacion-escritura con mascara de bits y acababa en LUTRAM.
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
  constant BYTES : boolean := WIDTH mod 8 = 0;
begin
  process (clk)
    variable a : natural range 0 to 2 ** ABITS - 1;
  begin
    if rising_edge(clk) then
      if en = '1' then
        a := to_integer(unsigned(addr));
        if we = '1' then
          if BYTES then
            for b in 0 to WIDTH / 8 - 1 loop
              if wmask(8 * b) = '1' then
                mem(a)(8 * b + 7 downto 8 * b) <= wdata(8 * b + 7 downto 8 * b);
              end if;
            end loop;
          elsif wmask(0) = '1' then
            mem(a) <= wdata;
          end if;
        else
          q <= mem(a);
        end if;
      end if;
    end if;
  end process;
end architecture;
