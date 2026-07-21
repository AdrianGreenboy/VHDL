-- HERCOSSNUX NPU - MAC int8 x int8 -> acumulador int32
-- 1 etapa de registro. clr carga el bias en lugar de acumular.
-- Mutaciones soportadas via generic G_MUT (0 = correcto).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity npu_mac is
  generic (
    G_ACC_W : natural := C_ACC_W;
    G_MUT   : natural := 0
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    en      : in  std_logic;                       -- habilita operacion
    clr     : in  std_logic;                       -- carga bias_in
    a_in    : in  signed(C_DATA_W-1 downto 0);     -- activacion
    w_in    : in  signed(C_DATA_W-1 downto 0);     -- peso
    bias_in : in  signed(G_ACC_W-1 downto 0);
    acc_out : out signed(G_ACC_W-1 downto 0)
  );
end entity npu_mac;

architecture rtl of npu_mac is
  signal acc_r : signed(G_ACC_W-1 downto 0);
begin

  process(clk)
    variable prod : signed(2*C_DATA_W-1 downto 0);
    variable sum  : signed(G_ACC_W downto 0);   -- 1 bit extra: deteccion de overflow
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        acc_r <= (others => '0');
      elsif en = '1' then
        if clr = '1' then
          if G_MUT = 3 then
            acc_r <= (others => '0');   -- MUT 3: bias descartado
          else
            acc_r <= bias_in;
          end if;
        else
          if G_MUT = 1 then
            -- MUT 1: el peso se interpreta sin signo (extension con cero)
            prod := resize(a_in * signed('0' & w_in), prod'length);
          else
            prod := a_in * w_in;
          end if;

          if G_MUT = 2 then
            -- MUT 2: resta en lugar de suma
            sum := resize(acc_r, G_ACC_W+1) - resize(prod, G_ACC_W+1);
          else
            sum := resize(acc_r, G_ACC_W+1) + resize(prod, G_ACC_W+1);
          end if;

          -- El acumulador nunca debe desbordar con la red congelada.
          assert sum(G_ACC_W) = sum(G_ACC_W-1)
            report "npu_mac: overflow del acumulador int32" severity failure;

          acc_r <= sum(G_ACC_W-1 downto 0);
        end if;
      end if;
    end if;
  end process;

  acc_out <= acc_r;

end architecture rtl;
