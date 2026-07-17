-- rf_cic_dec.vhd - Decimador CIC sinc3 complejo (I,Q en paralelo)
-- R = {4,8,16,32} por dec_sel(1:0): 0->4, 1->8, 2->16, 3->32.
-- Acumuladores 32 bits wrap (crecimiento max 16 + 3*log2(32) = 31 bits;
-- la regla 3*log2(R)+2 del ADC aplica a entrada +/-1, NO a Q1.15).
-- Semantica registrada: integradores usan valores viejos; al decimar se toma
-- i3 VIEJO cuando cnt==R-1; combs M=1 en cadena combinacional, salida registrada.
-- Normalizacion: shift aritmetico 3*(dec_sel+2), saturacion a Q1.15.
-- Cambio de dec_sel: limpieza sincrona total del estado (la muestra de ese ciclo
-- se descarta). Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_cic_dec is
  port (
    clk_i     : in  std_logic;
    aresetn_i : in  std_logic;
    valid_i   : in  std_logic;
    i_i       : in  std_logic_vector(15 downto 0);
    q_i       : in  std_logic_vector(15 downto 0);
    dec_sel_i : in  std_logic_vector(2 downto 0);
    i_o       : out std_logic_vector(15 downto 0);
    q_o       : out std_logic_vector(15 downto 0);
    valid_o   : out std_logic
  );
end entity rf_cic_dec;

architecture rtl of rf_cic_dec is
  signal i1_i_r, i2_i_r, i3_i_r : signed(31 downto 0) := (others => '0');
  signal i1_q_r, i2_q_r, i3_q_r : signed(31 downto 0) := (others => '0');
  signal d1_i_r, d2_i_r, d3_i_r : signed(31 downto 0) := (others => '0');
  signal d1_q_r, d2_q_r, d3_q_r : signed(31 downto 0) := (others => '0');
  signal cnt_r     : unsigned(4 downto 0) := (others => '0');
  signal dec_sel_r : std_logic_vector(1 downto 0) := "00";

  function sat16 (v : signed(31 downto 0)) return std_logic_vector is
  begin
    if v > 32767 then
      return std_logic_vector(to_signed(32767, 16));
    elsif v < -32768 then
      return std_logic_vector(to_signed(-32768, 16));
    else
      return std_logic_vector(v(15 downto 0));
    end if;
  end function sat16;
begin

  proc_cic : process (clk_i, aresetn_i)
    variable r_fin_v : unsigned(4 downto 0);
    variable sh_v    : natural range 6 to 15;
    variable v_i, c1_i, c2_i, c3_i : signed(31 downto 0);
    variable v_q, c1_q, c2_q, c3_q : signed(31 downto 0);
  begin
    if aresetn_i = '0' then
      i1_i_r <= (others => '0'); i2_i_r <= (others => '0'); i3_i_r <= (others => '0');
      i1_q_r <= (others => '0'); i2_q_r <= (others => '0'); i3_q_r <= (others => '0');
      d1_i_r <= (others => '0'); d2_i_r <= (others => '0'); d3_i_r <= (others => '0');
      d1_q_r <= (others => '0'); d2_q_r <= (others => '0'); d3_q_r <= (others => '0');
      cnt_r     <= (others => '0');
      dec_sel_r <= "00";
      i_o       <= (others => '0');
      q_o       <= (others => '0');
      valid_o   <= '0';
    elsif rising_edge(clk_i) then
      valid_o <= '0';
      if dec_sel_i(1 downto 0) /= dec_sel_r then
        -- cambio de R en caliente: limpieza sincrona total
        dec_sel_r <= dec_sel_i(1 downto 0);
        i1_i_r <= (others => '0'); i2_i_r <= (others => '0'); i3_i_r <= (others => '0');
        i1_q_r <= (others => '0'); i2_q_r <= (others => '0'); i3_q_r <= (others => '0');
        d1_i_r <= (others => '0'); d2_i_r <= (others => '0'); d3_i_r <= (others => '0');
        d1_q_r <= (others => '0'); d2_q_r <= (others => '0'); d3_q_r <= (others => '0');
        cnt_r <= (others => '0');
      elsif valid_i = '1' then
        r_fin_v := to_unsigned((4 * (2 ** to_integer(unsigned(dec_sel_r)))) - 1, 5);
        sh_v    := 3 * (to_integer(unsigned(dec_sel_r)) + 2);
        if cnt_r = r_fin_v then
          v_i  := i3_i_r;                       -- valor VIEJO registrado
          c1_i := v_i - d1_i_r;
          c2_i := c1_i - d2_i_r;
          c3_i := c2_i - d3_i_r;
          d1_i_r <= v_i; d2_i_r <= c1_i; d3_i_r <= c2_i;
          v_q  := i3_q_r;
          c1_q := v_q - d1_q_r;
          c2_q := c1_q - d2_q_r;
          c3_q := c2_q - d3_q_r;
          d1_q_r <= v_q; d2_q_r <= c1_q; d3_q_r <= c2_q;
          i_o     <= sat16(shift_right(c3_i, sh_v));
          q_o     <= sat16(shift_right(c3_q, sh_v));
          valid_o <= '1';
          cnt_r   <= (others => '0');
        else
          cnt_r <= cnt_r + 1;
        end if;
        -- integradores: asignaciones de senal usan valores viejos por naturaleza
        i3_i_r <= i3_i_r + i2_i_r;
        i2_i_r <= i2_i_r + i1_i_r;
        i1_i_r <= i1_i_r + resize(signed(i_i), 32);
        i3_q_r <= i3_q_r + i2_q_r;
        i2_q_r <= i2_q_r + i1_q_r;
        i1_q_r <= i1_q_r + resize(signed(q_i), 32);
      end if;
    end if;
  end process proc_cic;

end architecture rtl;
