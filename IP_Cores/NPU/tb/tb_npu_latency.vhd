-- HERCOSSNUX NPU - verificacion de latencia del requantize.
-- Inyecta un unico pulso de valid_in y mide los ciclos hasta valid_out.
-- Criterio congelado: exactamente 3 ciclos.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity tb_npu_latency is
  generic (G_MUT : natural := 0);
end entity tb_npu_latency;

architecture sim of tb_npu_latency is
  constant CP       : time    := 10 ns;
  constant C_EXP_LAT : natural := 3;

  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal valid_in  : std_logic := '0';
  signal relu_en   : std_logic := '0';
  signal acc_in    : signed(C_ACC_W-1 downto 0)  := (others => '0');
  signal mult_in   : signed(C_MULT_W-1 downto 0) := (others => '0');
  signal valid_out : std_logic;
  signal data_out  : signed(C_DATA_W-1 downto 0);
  signal done      : boolean := false;
begin

  clk <= not clk after CP/2 when not done else '0';

  dut : entity work.npu_requant
    generic map (G_ACC_W => C_ACC_W, G_SHIFT => C_SHIFT, G_MUT => G_MUT)
    port map (clk => clk, rst_n => rst_n, valid_in => valid_in, relu_en => relu_en,
              acc_in => acc_in, mult_in => mult_in,
              valid_out => valid_out, data_out => data_out);

  stim : process
    variable lat   : natural := 0;
    variable pulses : natural := 0;
  begin
    rst_n <= '0';
    wait for 4*CP;
    rst_n <= '1';
    wait until rising_edge(clk);

    -- Pulso unico. El flanco que sigue a esta asignacion es el que captura
    -- en la etapa 1; el conteo de latencia arranca justo despues de el.
    valid_in <= '1';
    relu_en  <= '1';
    acc_in   <= to_signed(1000000, C_ACC_W);
    mult_in  <= to_signed(5064654, C_MULT_W);
    wait until rising_edge(clk);   -- flanco de captura en E1
    valid_in <= '0';

    -- contar ciclos hasta valid_out
    -- Muestreo justo despues de cada flanco. El flanco de captura ya ocurrio,
    -- por lo que la primera muestra corresponde a la latencia 1.
    lat := 0;
    for i in 1 to 20 loop
      wait for CP/4;
      if valid_out = '1' then
        pulses := pulses + 1;
        if pulses = 1 then
          lat := i;
        end if;
      end if;
      wait until rising_edge(clk);
    end loop;

    if lat = C_EXP_LAT and pulses = 1 then
      report "TB_LATENCY PASS latencia=" & integer'image(lat)
           & " pulsos=" & integer'image(pulses) severity note;
    else
      report "TB_LATENCY FAIL latencia=" & integer'image(lat)
           & " esperada=" & integer'image(C_EXP_LAT)
           & " pulsos=" & integer'image(pulses) severity note;
    end if;

    done <= true;
    wait;
  end process;

end architecture sim;
