-- ============================================================================
-- fp32_fma.vhd — FMA fp32 con pipeline de latencia fija (IP ADCS).
--   result = a*b + c   (IEEE-754 binary32, RNE, fusionada, FTZ)
--
-- Arquitectura behav: calcula con fma_fp32 (fp32_pkg) en la etapa 0 y retarda
-- LAT_FMA ciclos, replicando la latencia del Floating-Point Operator. Es la
-- arquitectura de capas 1-4 (GHDL). En el proyecto Vivado este archivo se
-- sustituye por fp32_fma_xil.vhd, que instancia el FPO (canal operation=0
-- SIEMPRE conectado — leccion de silicio nro. 3 de la tesis).
--
-- Sin backpressure interno: el datapath garantiza no solapar colisiones,
-- identico al diseno original.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp32_pkg.all;

entity fp32_fma is
  generic (
    LAT_FMA : natural := 8;
    MUT     : natural := 0            -- solo verificacion; 0 en uso normal
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    in_valid  : in  std_logic;
    a         : in  std_logic_vector(31 downto 0);
    b         : in  std_logic_vector(31 downto 0);
    c         : in  std_logic_vector(31 downto 0);
    out_valid : out std_logic;
    result    : out std_logic_vector(31 downto 0)
  );
end entity fp32_fma;

architecture behav of fp32_fma is
  type pipe_t is array (0 to LAT_FMA-1) of std_logic_vector(31 downto 0);
  signal pd : pipe_t;
  signal pv : std_logic_vector(LAT_FMA-1 downto 0);
begin

  process (clk, rst_n)
  begin
    if rst_n = '0' then
      pv <= (others => '0');
      pd <= (others => (others => '0'));
    elsif rising_edge(clk) then
      -- calculo solo con in_valid (rendimiento de simulacion; la validez la
      -- gobierna pv, el contenido de pd con pv=0 nunca se observa)
      if in_valid = '1' then
        pd(0) <= fma_fp32(a, b, c, MUT);
      end if;
      pv(0) <= in_valid;
      for i in 1 to LAT_FMA-1 loop
        pd(i) <= pd(i-1);
        pv(i) <= pv(i-1);
      end loop;
    end if;
  end process;

  result    <= pd(LAT_FMA-1);
  out_valid <= pv(LAT_FMA-1);

end architecture behav;
