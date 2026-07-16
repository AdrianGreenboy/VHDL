-- ============================================================================
-- adc_core.vhd : Cadena de datos del ADC delta-sigma soft IP v1 (capa 1c)
-- adc_pdmgen (fuente interna de prueba) + sincronizador de 2 FF para la
-- entrada externa (hook B) + mux de fuente + monitor de actividad externa
-- con timeout + adc_cic. pdm_fb_o expone el bit sincronizado como
-- realimentacion del DAC de 1 bit (topologia sigma-delta LVDS de v2).
-- El timeout de actividad es la prueba Phase-0 anti-modo-comun: con
-- src_sel_i='1' y pdm_ext_i inerte, ext_timeout_o debe activarse.
-- VHDL-2008. Reset asincrono activo bajo.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_core is
  port (
    clk            : in  std_logic;
    aresetn        : in  std_logic;
    en_i           : in  std_logic;
    src_sel_i      : in  std_logic;
    finc_i         : in  std_logic_vector(31 downto 0);
    osr_sel_i      : in  std_logic_vector(1 downto 0);
    pdm_ext_i      : in  std_logic;
    pdm_fb_o       : out std_logic;
    ext_timeout_o  : out std_logic;
    sample_o       : out std_logic_vector(23 downto 0);
    sample_valid_o : out std_logic
  );
end entity adc_core;

architecture rtl of adc_core is
  constant C_TO_MAX : unsigned(11 downto 0) := to_unsigned(4095, 12);

  signal gen_y     : std_logic;
  signal gen_valid : std_logic;
  signal s1        : std_logic;
  signal s2        : std_logic;
  signal prev      : std_logic;
  signal acnt      : unsigned(11 downto 0);
  signal tout      : std_logic;
  signal pdm_mux   : std_logic;
  signal valid_mux : std_logic;
begin

  u_gen : entity work.adc_pdmgen
    port map (
      clk         => clk,
      aresetn     => aresetn,
      en_i        => en_i,
      finc_i      => finc_i,
      pdm_o       => gen_y,
      pdm_valid_o => gen_valid
    );

  -- sincronizador de 2 FF para la entrada externa asincrona (hook B)
  proc_sync : process (clk, aresetn)
  begin
    if aresetn = '0' then
      s1 <= '0';
      s2 <= '0';
    elsif rising_edge(clk) then
      s1 <= pdm_ext_i;
      s2 <= s1;
    end if;
  end process proc_sync;

  -- monitor de actividad externa: timeout pegajoso mientras src_sel='1'
  proc_mon : process (clk, aresetn)
  begin
    if aresetn = '0' then
      prev <= '0';
      acnt <= (others => '0');
      tout <= '0';
    elsif rising_edge(clk) then
      if src_sel_i = '0' then
        acnt <= (others => '0');
        tout <= '0';
      elsif en_i = '1' then
        prev <= s2;
        if s2 /= prev then
          acnt <= (others => '0');
        elsif acnt = C_TO_MAX then
          tout <= '1';
        else
          acnt <= acnt + 1;
        end if;
      end if;
    end if;
  end process proc_mon;

  -- mux de fuente
  pdm_mux   <= gen_y     when src_sel_i = '0' else s2;
  valid_mux <= gen_valid when src_sel_i = '0' else en_i;

  u_cic : entity work.adc_cic
    port map (
      clk            => clk,
      aresetn        => aresetn,
      pdm_i          => pdm_mux,
      pdm_valid_i    => valid_mux,
      osr_sel_i      => osr_sel_i,
      sample_o       => sample_o,
      sample_valid_o => sample_valid_o
    );

  pdm_fb_o      <= s2;
  ext_timeout_o <= tout;

end architecture rtl;
