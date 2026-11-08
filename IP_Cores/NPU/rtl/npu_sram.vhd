-- HERCOSSNUX NPU - memoria de trabajo 1R1W con lectura SINCRONA (audit 2026-11).
--
-- Unico punto de mapeo tecnologico de las memorias de trabajo del NPU:
--   * un puerto de escritura sincrono (we/waddr/wdata)
--   * un puerto de lectura sincrono y REGISTRADO (re/raddr -> rdata al ciclo
--     siguiente; rdata se mantiene mientras re='0')
-- Es exactamente la forma de una SRAM de dos puertos (1R1W) de un compilador
-- de memorias ASIC (IHP SG13G2 / sky130) o de una BRAM SDP de FPGA. Cada
-- instancia recibe como maximo UN acceso de cada tipo por ciclo; donde el
-- algoritmo necesitaba varios accesos por ciclo, la memoria se ha partido en
-- bancos (uno por canal).
-- Lectura y escritura a la misma direccion en el mismo ciclo: devuelve el
-- dato ANTIGUO (read-first); los secuenciadores nunca dependen de ese caso.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity npu_sram_1r1w is
  generic (
    G_DEPTH : positive := 64;
    G_WIDTH : positive := 8
  );
  port (
    clk   : in  std_logic;
    we    : in  std_logic;
    waddr : in  natural range 0 to G_DEPTH-1;
    wdata : in  std_logic_vector(G_WIDTH-1 downto 0);
    re    : in  std_logic;
    raddr : in  natural range 0 to G_DEPTH-1;
    rdata : out std_logic_vector(G_WIDTH-1 downto 0)
  );
end entity npu_sram_1r1w;

architecture rtl of npu_sram_1r1w is
  type t_mem is array (0 to G_DEPTH-1) of std_logic_vector(G_WIDTH-1 downto 0);
  signal mem : t_mem := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of mem : signal is "block";
  signal q : std_logic_vector(G_WIDTH-1 downto 0) := (others => '0');
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        mem(waddr) <= wdata;
      end if;
      if re = '1' then
        q <= mem(raddr);
      end if;
    end if;
  end process;
  rdata <= q;
end architecture rtl;
