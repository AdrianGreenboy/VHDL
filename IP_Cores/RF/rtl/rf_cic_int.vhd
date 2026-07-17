-- rf_cic_int.vhd - Interpolador CIC sinc3 complejo (I,Q en paralelo)
-- R = {4,8,16,32} por int_sel(1:0): 0->4, 1->8, 2->16, 3->32.
-- Estructura interpolador: 3 combs M=1 a tasa baja (al llegar valid_i) ->
-- zero-stuffing (inserta R-1 ceros) -> 3 integradores 32b wrap a tasa alta.
-- Ganancia DC del interpolador sinc3 = R^2 -> normalizacion >> 2*log2(R) =
-- >> 2*(sel+2), con saturacion Q1.15.
-- Produce R salidas por cada push (una por ciclo). Semantica: integradores
-- toman valores viejos; se emite i3 VIEJO. La 1a de las R inyecta el comb,
-- las R-1 restantes inyectan cero.
-- Cambio de int_sel: limpieza sincrona total. Reset async activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_cic_int is
  port (
    clk_i     : in  std_logic;
    aresetn_i : in  std_logic;
    valid_i   : in  std_logic;
    i_i       : in  std_logic_vector(15 downto 0);
    q_i       : in  std_logic_vector(15 downto 0);
    int_sel_i : in  std_logic_vector(2 downto 0);
    i_o       : out std_logic_vector(15 downto 0);
    q_o       : out std_logic_vector(15 downto 0);
    valid_o   : out std_logic
  );
end entity rf_cic_int;

architecture rtl of rf_cic_int is
  signal i1_i_r, i2_i_r, i3_i_r : signed(31 downto 0) := (others => '0');
  signal i1_q_r, i2_q_r, i3_q_r : signed(31 downto 0) := (others => '0');
  signal d1_i_r, d2_i_r, d3_i_r : signed(31 downto 0) := (others => '0');
  signal d1_q_r, d2_q_r, d3_q_r : signed(31 downto 0) := (others => '0');
  signal u_i_r, u_q_r : signed(31 downto 0) := (others => '0');
  signal run_r  : unsigned(5 downto 0) := (others => '0');
  signal sel_r  : std_logic_vector(1 downto 0) := "00";

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

  proc_int : process (clk_i, aresetn_i)
    variable sh_v : natural range 4 to 10;
    variable xi_v, xq_v : signed(31 downto 0);
    variable c1_v, c2_v, c3_v : signed(31 downto 0);
    variable ui_v, uq_v : signed(31 downto 0);
  begin
    if aresetn_i = '0' then
      i1_i_r <= (others => '0'); i2_i_r <= (others => '0'); i3_i_r <= (others => '0');
      i1_q_r <= (others => '0'); i2_q_r <= (others => '0'); i3_q_r <= (others => '0');
      d1_i_r <= (others => '0'); d2_i_r <= (others => '0'); d3_i_r <= (others => '0');
      d1_q_r <= (others => '0'); d2_q_r <= (others => '0'); d3_q_r <= (others => '0');
      u_i_r  <= (others => '0'); u_q_r  <= (others => '0');
      run_r  <= (others => '0');
      sel_r  <= "00";
      i_o     <= (others => '0');
      q_o     <= (others => '0');
      valid_o <= '0';
    elsif rising_edge(clk_i) then
      valid_o <= '0';
      if int_sel_i(1 downto 0) /= sel_r then
        sel_r <= int_sel_i(1 downto 0);
        i1_i_r <= (others => '0'); i2_i_r <= (others => '0'); i3_i_r <= (others => '0');
        i1_q_r <= (others => '0'); i2_q_r <= (others => '0'); i3_q_r <= (others => '0');
        d1_i_r <= (others => '0'); d2_i_r <= (others => '0'); d3_i_r <= (others => '0');
        d1_q_r <= (others => '0'); d2_q_r <= (others => '0'); d3_q_r <= (others => '0');
        u_i_r  <= (others => '0'); u_q_r  <= (others => '0');
        run_r  <= (others => '0');
      else
        sh_v := 2 * (to_integer(unsigned(sel_r)) + 2);
        -- muestra a inyectar este ciclo: comb si arranca push, si no cero.
        if valid_i = '1' then
          xi_v := resize(signed(i_i), 32);
          c1_v := xi_v - d1_i_r; c2_v := c1_v - d2_i_r; c3_v := c2_v - d3_i_r;
          d1_i_r <= xi_v; d2_i_r <= c1_v; d3_i_r <= c2_v;
          ui_v := c3_v;
          xq_v := resize(signed(q_i), 32);
          c1_v := xq_v - d1_q_r; c2_v := c1_v - d2_q_r; c3_v := c2_v - d3_q_r;
          d1_q_r <= xq_v; d2_q_r <= c1_v; d3_q_r <= c2_v;
          uq_v := c3_v;
          run_r <= to_unsigned(4 * (2 ** to_integer(unsigned(sel_r))), 6) - 1;
        else
          ui_v := (others => '0');
          uq_v := (others => '0');
          if run_r > 0 then
            run_r <= run_r - 1;
          end if;
        end if;

        if valid_i = '1' or run_r > 0 then
          i_o     <= sat16(shift_right(i3_i_r, sh_v));
          q_o     <= sat16(shift_right(i3_q_r, sh_v));
          valid_o <= '1';
          i3_i_r <= i3_i_r + i2_i_r;
          i2_i_r <= i2_i_r + i1_i_r;
          i1_i_r <= i1_i_r + ui_v;
          i3_q_r <= i3_q_r + i2_q_r;
          i2_q_r <= i2_q_r + i1_q_r;
          i1_q_r <= i1_q_r + uq_v;
        end if;
      end if;
    end if;
  end process proc_int;

end architecture rtl;
