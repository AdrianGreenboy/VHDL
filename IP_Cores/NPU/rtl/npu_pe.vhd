-- HERCOSSNUX NPU - PE del array sistolico output-stationary.
-- Cada PE(r,k) acumula productos de un canal de entrada r contra un canal
-- de salida k. Activaciones fluyen hacia la derecha, pesos hacia abajo,
-- ambos con un registro de por medio (skew triangular).
--
-- clr  : reinicia el acumulador al empezar una ventana
-- en   : habilita acumulacion
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity npu_pe is
  generic (
    G_ACC_W : natural := C_ACC_W;
    G_MUT   : natural := 0
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    en      : in  std_logic;
    clr     : in  std_logic;
    a_in    : in  signed(C_DATA_W-1 downto 0);   -- activacion desde la izquierda
    w_in    : in  signed(C_DATA_W-1 downto 0);   -- peso desde arriba
    a_out   : out signed(C_DATA_W-1 downto 0);   -- activacion hacia la derecha
    w_out   : out signed(C_DATA_W-1 downto 0);   -- peso hacia abajo
    acc_out : out signed(G_ACC_W-1 downto 0)
  );
end entity npu_pe;

architecture rtl of npu_pe is
  signal acc_r : signed(G_ACC_W-1 downto 0);
  signal a_r   : signed(C_DATA_W-1 downto 0);
  signal w_r   : signed(C_DATA_W-1 downto 0);
begin

  process(clk)
    variable prod : signed(2*C_DATA_W-1 downto 0);
    variable sum  : signed(G_ACC_W downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        acc_r <= (others => '0');
        a_r   <= (others => '0');
        w_r   <= (others => '0');
      else
        -- Propagacion sistolica: siempre avanza, independiente de 'en'.
        if G_MUT = 1 then
          -- MUT 1: la activacion no se propaga (columna derecha se queda sin dato)
          a_r <= (others => '0');
        else
          a_r <= a_in;
        end if;

        if G_MUT = 2 then
          -- MUT 2: el peso se propaga sin registro efectivo (rompe el skew)
          w_r <= w_in + 1;
        else
          w_r <= w_in;
        end if;

        -- Acumulacion
        if clr = '1' then
          if G_MUT = 3 then
            null;                       -- MUT 3: no se limpia entre ventanas
          else
            acc_r <= (others => '0');
          end if;
        elsif en = '1' then
          prod := a_in * w_in;
          sum  := resize(acc_r, G_ACC_W+1) + resize(prod, G_ACC_W+1);
          assert sum(G_ACC_W) = sum(G_ACC_W-1)
            report "npu_pe: overflow del acumulador int32" severity failure;
          acc_r <= sum(G_ACC_W-1 downto 0);
        end if;
      end if;
    end if;
  end process;

  a_out   <= a_r;
  w_out   <= w_r;
  acc_out <= acc_r;

end architecture rtl;
