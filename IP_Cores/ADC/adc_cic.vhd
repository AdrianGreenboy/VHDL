-- ============================================================================
-- adc_cic.vhd : Decimador CIC sinc3 del ADC delta-sigma soft IP v1
-- 3 integradores a tasa PDM + 3 combs a tasa decimada, M=1.
-- OSR configurable {32,64,128,256} por osr_sel_i; cambio en caliente
-- reinicia limpio el datapath (integradores, combs, contador, warmup).
-- Acumuladores de 26 bits con aritmetica modular (Hogenauer:
-- Bmax = 3*log2(256) + 2 bits de entrada con signo +/-1).
-- Normalizacion por barrel shift a Q1.23 con saturacion simetrica.
-- VHDL-2008. Reset asincrono activo bajo.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_cic is
  port (
    clk            : in  std_logic;
    aresetn        : in  std_logic;
    pdm_i          : in  std_logic;
    pdm_valid_i    : in  std_logic;
    osr_sel_i      : in  std_logic_vector(1 downto 0);
    sample_o       : out std_logic_vector(23 downto 0);
    sample_valid_o : out std_logic
  );
end entity adc_cic;

architecture rtl of adc_cic is
  constant C_ACCW : integer := 26;

  signal osr_r  : std_logic_vector(1 downto 0);
  signal i1     : signed(C_ACCW - 1 downto 0);
  signal i2     : signed(C_ACCW - 1 downto 0);
  signal i3     : signed(C_ACCW - 1 downto 0);
  signal c1d    : signed(C_ACCW - 1 downto 0);
  signal c2d    : signed(C_ACCW - 1 downto 0);
  signal c3d    : signed(C_ACCW - 1 downto 0);
  signal cnt    : unsigned(7 downto 0);
  signal warm   : unsigned(1 downto 0);
  signal sample : signed(23 downto 0);
  signal svalid : std_logic;

  function f_rmax (osr : std_logic_vector(1 downto 0)) return unsigned is
  begin
    case osr is
      when "00"   => return to_unsigned(31, 8);
      when "01"   => return to_unsigned(63, 8);
      when "10"   => return to_unsigned(127, 8);
      when others => return to_unsigned(255, 8);
    end case;
  end function f_rmax;

begin

  proc_cic : process (clk, aresetn)
    variable v_in   : signed(C_ACCW - 1 downto 0);
    variable v_i1   : signed(C_ACCW - 1 downto 0);
    variable v_i2   : signed(C_ACCW - 1 downto 0);
    variable v_i3   : signed(C_ACCW - 1 downto 0);
    variable v_d0   : signed(C_ACCW - 1 downto 0);
    variable v_y1   : signed(C_ACCW - 1 downto 0);
    variable v_y2   : signed(C_ACCW - 1 downto 0);
    variable v_y3   : signed(C_ACCW - 1 downto 0);
    variable v_norm : signed(33 downto 0);
  begin
    if aresetn = '0' then
      osr_r  <= "11";
      i1     <= (others => '0');
      i2     <= (others => '0');
      i3     <= (others => '0');
      c1d    <= (others => '0');
      c2d    <= (others => '0');
      c3d    <= (others => '0');
      cnt    <= (others => '0');
      warm   <= (others => '0');
      sample <= (others => '0');
      svalid <= '0';
    elsif rising_edge(clk) then
      svalid <= '0';
      if osr_sel_i /= osr_r then
        -- cambio de OSR en caliente: reinicio limpio del datapath
        osr_r <= osr_sel_i;
        i1    <= (others => '0');
        i2    <= (others => '0');
        i3    <= (others => '0');
        c1d   <= (others => '0');
        c2d   <= (others => '0');
        c3d   <= (others => '0');
        cnt   <= (others => '0');
        warm  <= (others => '0');
      elsif pdm_valid_i = '1' then
        if pdm_i = '1' then
          v_in := to_signed(1, C_ACCW);
        else
          v_in := to_signed(-1, C_ACCW);
        end if;
        -- seccion integradora (tasa PDM, wrap modular)
        v_i1 := i1 + v_in;
        v_i2 := i2 + v_i1;
        v_i3 := i3 + v_i2;
        i1   <= v_i1;
        i2   <= v_i2;
        i3   <= v_i3;
        if cnt = f_rmax(osr_r) then
          cnt <= (others => '0');
          -- seccion comb (tasa decimada, M=1)
          v_d0 := v_i3;
          v_y1 := v_d0 - c1d;
          v_y2 := v_y1 - c2d;
          v_y3 := v_y2 - c3d;
          c1d  <= v_d0;
          c2d  <= v_y1;
          c3d  <= v_y2;
          if warm /= "11" then
            warm <= warm + 1;
          else
            -- normalizacion a Q1.23 y saturacion simetrica
            case osr_r is
              when "00"   => v_norm := shift_left(resize(v_y3, 34), 8);
              when "01"   => v_norm := shift_left(resize(v_y3, 34), 5);
              when "10"   => v_norm := shift_left(resize(v_y3, 34), 2);
              when others => v_norm := shift_right(resize(v_y3, 34), 1);
            end case;
            if v_norm > to_signed(8388607, 34) then
              sample <= to_signed(8388607, 24);
            elsif v_norm < to_signed(-8388608, 34) then
              sample <= to_signed(-8388608, 24);
            else
              sample <= resize(v_norm, 24);
            end if;
            svalid <= '1';
          end if;
        else
          cnt <= cnt + 1;
        end if;
      end if;
    end if;
  end process proc_cic;

  sample_o       <= std_logic_vector(sample);
  sample_valid_o <= svalid;

end architecture rtl;
