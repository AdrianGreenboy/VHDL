-- ============================================================================
-- adc_pdmgen.vhd : Generador PDM de prueba para el ADC delta-sigma soft IP v1
-- Acumulador de fase 32 bits + LUT senoidal 1024x16 (ROM sincrona, molde BRAM)
-- + modulador delta-sigma digital de 2o orden (CIFB) con cuantizador de 1 bit.
-- Amplitud LUT = 0.6 FS (estabilidad del modulador de 2o orden).
-- VHDL-2008. Reset asincrono activo bajo (convencion de la familia).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adc_sin_lut_pkg.all;

entity adc_pdmgen is
  port (
    clk         : in  std_logic;
    aresetn     : in  std_logic;
    en_i        : in  std_logic;
    finc_i      : in  std_logic_vector(31 downto 0);
    pdm_o       : out std_logic;
    pdm_valid_o : out std_logic
  );
end entity adc_pdmgen;

architecture rtl of adc_pdmgen is
  signal phase : unsigned(31 downto 0);
  signal x     : signed(15 downto 0);
  signal i1    : signed(23 downto 0);
  signal i2    : signed(23 downto 0);
  signal y     : std_logic;
  signal wcnt  : unsigned(1 downto 0);
  signal valid : std_logic;
begin

  proc_pdm : process (clk, aresetn)
    variable v_fb : signed(23 downto 0);
    variable v_i1 : signed(23 downto 0);
    variable v_i2 : signed(23 downto 0);
  begin
    if aresetn = '0' then
      phase <= (others => '0');
      x     <= (others => '0');
      i1    <= (others => '0');
      i2    <= (others => '0');
      y     <= '0';
      wcnt  <= (others => '0');
      valid <= '0';
    elsif rising_edge(clk) then
      if en_i = '1' then
        -- acumulador de fase (fase vieja indexa la LUT)
        phase <= phase + unsigned(finc_i);
        -- lectura sincrona de ROM (inferible como BRAM)
        x <= to_signed(C_SIN_LUT(to_integer(phase(31 downto 22))), 16);
        -- modulador CIFB de 2o orden, realimentacion +/-FS
        if y = '1' then
          v_fb := to_signed(32768, 24);
        else
          v_fb := to_signed(-32768, 24);
        end if;
        v_i1 := i1 + resize(x, 24) - v_fb;
        v_i2 := i2 + v_i1 - v_fb - v_fb;
        if v_i2 >= 0 then
          y <= '1';
        else
          y <= '0';
        end if;
        i1 <= v_i1;
        i2 <= v_i2;
        -- calentamiento del pipeline: fase -> x -> y (2 ciclos)
        if wcnt /= "11" then
          wcnt <= wcnt + 1;
        end if;
        if wcnt >= 2 then
          valid <= '1';
        end if;
      end if;
    end if;
  end process proc_pdm;

  pdm_o       <= y;
  pdm_valid_o <= valid;

end architecture rtl;
