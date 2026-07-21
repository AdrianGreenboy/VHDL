-- HERCOSSNUX NPU - maxpool 2x2 sobre int8, 1 etapa de registro.
-- Recibe las 4 muestras de la ventana en paralelo.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity npu_pool is
  generic (
    G_MUT : natural := 0
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    valid_in  : in  std_logic;
    d00       : in  signed(C_DATA_W-1 downto 0);
    d01       : in  signed(C_DATA_W-1 downto 0);
    d10       : in  signed(C_DATA_W-1 downto 0);
    d11       : in  signed(C_DATA_W-1 downto 0);
    valid_out : out std_logic;
    data_out  : out signed(C_DATA_W-1 downto 0)
  );
end entity npu_pool;

architecture rtl of npu_pool is
  signal vr : std_logic;
  signal dr : signed(C_DATA_W-1 downto 0);
begin

  process(clk)
    variable m  : signed(C_DATA_W-1 downto 0);
    variable s4 : signed(C_DATA_W+1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        vr <= '0'; dr <= (others => '0');
      else
        vr <= valid_in;

        if G_MUT = 1 then
          -- MUT 1: promedio en lugar de maximo
          s4 := resize(d00, s4'length) + resize(d01, s4'length)
              + resize(d10, s4'length) + resize(d11, s4'length);
          dr <= resize(shift_right(s4, 2), C_DATA_W);
        elsif G_MUT = 2 then
          -- MUT 2: comparacion sin signo
          m := d00;
          if unsigned(std_logic_vector(d01)) > unsigned(std_logic_vector(m)) then m := d01; end if;
          if unsigned(std_logic_vector(d10)) > unsigned(std_logic_vector(m)) then m := d10; end if;
          if unsigned(std_logic_vector(d11)) > unsigned(std_logic_vector(m)) then m := d11; end if;
          dr <= m;
        elsif G_MUT = 3 then
          -- MUT 3: ignora la ultima muestra de la ventana
          m := d00;
          if d01 > m then m := d01; end if;
          if d10 > m then m := d10; end if;
          dr <= m;
        elsif G_MUT = 4 then
          -- MUT 4: minimo en lugar de maximo
          m := d00;
          if d01 < m then m := d01; end if;
          if d10 < m then m := d10; end if;
          if d11 < m then m := d11; end if;
          dr <= m;
        else
          m := d00;
          if d01 > m then m := d01; end if;
          if d10 > m then m := d10; end if;
          if d11 > m then m := d11; end if;
          dr <= m;
        end if;
      end if;
    end if;
  end process;

  valid_out <= vr;
  data_out  <= dr;

end architecture rtl;
