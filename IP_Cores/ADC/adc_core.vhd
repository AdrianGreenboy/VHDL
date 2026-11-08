-- ============================================================================
-- adc_core.vhd : Cadena de datos del ADC delta-sigma soft IP v1 (capa 1c)
-- adc_pdmgen (fuente interna de prueba) + sincronizador de 2 FF para la
-- entrada externa (hook B) + mux de fuente + monitor de actividad externa
-- con timeout + adc_cic. pdm_fb_o expone el bit sincronizado como
-- realimentacion del DAC de 1 bit (topologia sigma-delta LVDS de v2).
-- El timeout de actividad es la prueba Phase-0 anti-modo-comun: con
-- src_sel_i='1' y pdm_ext_i inerte, ext_timeout_o debe activarse.
-- VHDL-2008. Reset asincrono activo bajo.
--
-- AUDIT 2026-11 -- external modulator clock (ext_clk_i='1', src_sel_i='1'):
-- the legacy external path assumes one modulator bit per aclk (bit rate =
-- aclk, bit sampled by a 2-FF synchronizer). A real delta-sigma modulator
-- runs on its own clock. pdm_clk_i is that clock: pdm_ext_i is captured on
-- its rising edge into a 4-entry ring register, written in turn, and a
-- 3-bit Gray counter of written bits crosses into aclk through a 2-FF
-- synchronizer. aclk reads entry (rd_cnt mod 4) whenever the synchronized
-- counter is ahead of rd_cnt (at most one bit per aclk), and issues one CIC
-- valid per modulator bit. An entry is rewritten 4 modulator periods after it
-- was written; a read with lag <= 2 happens before that, so the capture is
-- exact for any f_pdm < f_aclk. If the reader lags by >= 3 bits (modulator
-- faster than aclk) ext_ovr_o pulses (sticky in adc_regs IRQ_STAT bit3) --
-- never silent.
-- pdm_fb_o follows the pdm_clk-domain bit in this mode (1-bit DAC feedback
-- must be in the modulator clock domain). ext_clk_i='0' keeps the legacy
-- path bit-for-bit (paso 3 vectors unchanged).
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
    pdm_clk_i      : in  std_logic := '0';   -- AUDIT: modulator bit clock
    ext_clk_i      : in  std_logic := '0';   -- AUDIT: 1 = capture on pdm_clk_i
    ext_ovr_o      : out std_logic;          -- AUDIT: pulse, modulator overrun
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
  -- AUDIT 2026-11: modulator-clock capture
  signal pc_pp     : std_logic_vector(3 downto 0) := "0000";  -- pdm_clk domain
  signal pc_bin    : unsigned(2 downto 0) := "000";
  signal pc_gray   : std_logic_vector(2 downto 0) := "000";
  signal pc_last   : std_logic := '0';
  signal g1, g2    : std_logic_vector(2 downto 0) := "000";   -- aclk domain
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of g1, g2 : signal is "TRUE";
  signal rd_cnt    : unsigned(2 downto 0) := "000";
  signal ext_bit   : std_logic := '0';
  signal ext_v     : std_logic := '0';
  signal ext_ovr   : std_logic := '0';
  signal pdm_cic   : std_logic;
  signal valid_cic : std_logic;
  signal use_pclk  : std_logic;
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

  -- AUDIT 2026-11: capture in the modulator clock domain
  proc_pclk : process (pdm_clk_i, aresetn)
  begin
    if aresetn = '0' then
      pc_bin <= "000"; pc_gray <= "000"; pc_pp <= "0000"; pc_last <= '0';
    elsif rising_edge(pdm_clk_i) then
      pc_pp(to_integer(pc_bin(1 downto 0))) <= pdm_ext_i;
      pc_last <= pdm_ext_i;
      pc_bin  <= pc_bin + 1;
      pc_gray <= std_logic_vector((pc_bin + 1) xor shift_right(pc_bin + 1, 1));  -- Gray
    end if;
  end process proc_pclk;

  -- aclk side: synchronize the Gray count, read one bit per advance
  proc_pread : process (clk, aresetn)
    variable wb : unsigned(2 downto 0);
    variable d  : unsigned(2 downto 0);
  begin
    if aresetn = '0' then
      g1 <= "000"; g2 <= "000"; rd_cnt <= "000"; ext_v <= '0'; ext_ovr <= '0'; ext_bit <= '0';
    elsif rising_edge(clk) then
      g1 <= pc_gray; g2 <= g1;
      ext_v <= '0'; ext_ovr <= '0';
      wb(2) := g2(2);                                  -- Gray -> binary
      wb(1) := g2(2) xor g2(1);
      wb(0) := g2(2) xor g2(1) xor g2(0);
      d  := wb - rd_cnt;
      if d /= 0 then
        ext_bit <= pc_pp(to_integer(rd_cnt(1 downto 0)));
        ext_v   <= '1';
        rd_cnt  <= rd_cnt + 1;
        if d >= 3 then ext_ovr <= '1'; end if;         -- reader fell behind
      end if;
    end if;
  end process proc_pread;

  -- mux de fuente
  pdm_mux   <= gen_y     when src_sel_i = '0' else s2;
  valid_mux <= gen_valid when src_sel_i = '0' else en_i;
  use_pclk  <= src_sel_i and ext_clk_i;
  pdm_cic   <= ext_bit when use_pclk = '1' else pdm_mux;
  valid_cic <= (ext_v and en_i) when use_pclk = '1' else valid_mux;

  u_cic : entity work.adc_cic
    port map (
      clk            => clk,
      aresetn        => aresetn,
      pdm_i          => pdm_cic,
      pdm_valid_i    => valid_cic,
      osr_sel_i      => osr_sel_i,
      sample_o       => sample_o,
      sample_valid_o => sample_valid_o
    );

  pdm_fb_o      <= pc_last when use_pclk = '1' else s2;
  ext_ovr_o     <= ext_ovr and use_pclk;
  ext_timeout_o <= tout;

end architecture rtl;
