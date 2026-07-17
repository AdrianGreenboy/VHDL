-- rf_fir.vhd - FIR de canal 16 taps Q1.15, forma directa paralela
-- Coeficientes cargables por puerto (coef_we/addr/data); el MMIO los mapea
-- en el paso 5 (FIR_COEF_ADDR/FIR_COEF_DATA). Acumulador 36 bits,
-- y = sat16(acc >> 15) con shift aritmetico. Historia sin limpieza.
-- Salida registrada 1 ciclo. Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_fir is
  port (
    clk_i       : in  std_logic;
    aresetn_i   : in  std_logic;
    valid_i     : in  std_logic;
    i_i         : in  std_logic_vector(15 downto 0);
    q_i         : in  std_logic_vector(15 downto 0);
    coef_we_i   : in  std_logic;
    coef_addr_i : in  std_logic_vector(3 downto 0);
    coef_data_i : in  std_logic_vector(15 downto 0);
    i_o         : out std_logic_vector(15 downto 0);
    q_o         : out std_logic_vector(15 downto 0);
    valid_o     : out std_logic
  );
end entity rf_fir;

architecture rtl of rf_fir is
  type t_c16 is array (0 to 15) of signed(15 downto 0);
  signal coef_r : t_c16 := (others => (others => '0'));
  signal si_r   : t_c16 := (others => (others => '0'));
  signal sq_r   : t_c16 := (others => (others => '0'));

  function sat16 (v : signed(20 downto 0)) return std_logic_vector is
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

  proc_fir : process (clk_i, aresetn_i)
    variable x_i_v, x_q_v : signed(15 downto 0);
    variable acc_i, acc_q : signed(35 downto 0);
  begin
    if aresetn_i = '0' then
      si_r    <= (others => (others => '0'));
      sq_r    <= (others => (others => '0'));
      i_o     <= (others => '0');
      q_o     <= (others => '0');
      valid_o <= '0';
    elsif rising_edge(clk_i) then
      valid_o <= '0';
      if coef_we_i = '1' then
        coef_r(to_integer(unsigned(coef_addr_i))) <= signed(coef_data_i);
      end if;
      if valid_i = '1' then
        x_i_v := signed(i_i);
        x_q_v := signed(q_i);
        acc_i := resize(coef_r(0) * x_i_v, 36);
        acc_q := resize(coef_r(0) * x_q_v, 36);
        for k in 1 to 15 loop
          acc_i := acc_i + resize(coef_r(k) * si_r(k - 1), 36);
          acc_q := acc_q + resize(coef_r(k) * sq_r(k - 1), 36);
        end loop;
        for k in 15 downto 1 loop
          si_r(k) <= si_r(k - 1);
          sq_r(k) <= sq_r(k - 1);
        end loop;
        si_r(0) <= x_i_v;
        sq_r(0) <= x_q_v;
        i_o     <= sat16(resize(shift_right(acc_i, 15), 21));
        q_o     <= sat16(resize(shift_right(acc_q, 15), 21));
        valid_o <= '1';
      end if;
    end if;
  end process proc_fir;

end architecture rtl;
