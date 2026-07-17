-- rf_nco.vhd - NCO con acumulador de fase 32 bits y LUT dual sen/cos Q1.15
-- La fase VIEJA indexa la LUT; la salida esta registrada (latencia 1 ciclo).
-- cos = LUT con offset 256 (90 grados). Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rf_sincos_pkg.all;

entity rf_nco is
  port (
    clk_i     : in  std_logic;
    aresetn_i : in  std_logic;
    en_i      : in  std_logic;
    ftw_i     : in  std_logic_vector(31 downto 0);
    sin_o     : out std_logic_vector(15 downto 0);
    cos_o     : out std_logic_vector(15 downto 0);
    valid_o   : out std_logic
  );
end entity rf_nco;

architecture rtl of rf_nco is
  signal fase_r : unsigned(31 downto 0) := (others => '0');
begin

  proc_nco : process (clk_i, aresetn_i)
    variable idx_v : integer range 0 to 1023;
  begin
    if aresetn_i = '0' then
      fase_r  <= (others => '0');
      sin_o   <= (others => '0');
      cos_o   <= (others => '0');
      valid_o <= '0';
    elsif rising_edge(clk_i) then
      valid_o <= '0';
      if en_i = '1' then
        idx_v   := to_integer(fase_r(31 downto 22));
        sin_o   <= std_logic_vector(to_signed(LUT_SEN(idx_v), 16));
        cos_o   <= std_logic_vector(to_signed(LUT_SEN((idx_v + 256) mod 1024), 16));
        fase_r  <= fase_r + unsigned(ftw_i);
        valid_o <= '1';
      end if;
    end if;
  end process proc_nco;

end architecture rtl;
