-- SONDA 3: filas ociosas. Se ejecuta una ventana con los 8 canales activos
-- (dejando residuo en los acumuladores) y a continuacion una ventana con
-- SOLO el canal 0 activo. El resultado debe depender unicamente del canal 0.
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
library work; use work.npu_pkg.all;
entity tb_l3_ocio is end entity;
architecture s of tb_l3_ocio is
  constant CP : time := 10 ns;
  signal clk : std_logic := '0'; signal rst_n : std_logic := '0';
  signal win_start, en, win_end : std_logic := '0';
  signal a_col : t_data_arr(0 to 7) := (others => (others => '0'));
  signal w_mat : t_data_arr(0 to 63) := (others => (others => '0'));
  signal bias_in : t_acc_arr(0 to 7) := (others => (others => '0'));
  signal av : std_logic; signal acc : t_acc_arr(0 to 7);
  signal done : boolean := false;
begin
  clk <= not clk after CP/2 when not done else '0';
  dut : entity work.npu_array generic map (8, C_ACC_W, 0)
    port map (clk, rst_n, win_start, en, win_end, a_col, w_mat, bias_in, av, acc);
  process
    variable r1, r2 : integer;
  begin
    rst_n <= '0'; wait for 4*CP; rst_n <= '1';
    wait until rising_edge(clk);
    -- todos los pesos = 2
    for i in 0 to 63 loop w_mat(i) <= to_signed(2, C_DATA_W); end loop;

    -- VENTANA A: los 8 canales con valor 10 -> deja residuo grande
    win_start <= '1'; wait until rising_edge(clk); win_start <= '0';
    for p in 0 to 8 loop
      for r in 0 to 7 loop a_col(r) <= to_signed(10, C_DATA_W); end loop;
      en <= '1'; wait until rising_edge(clk);
    end loop;
    en <= '0';
    win_end <= '1'; wait until rising_edge(clk); win_end <= '0';
    for w in 0 to 3 loop wait until rising_edge(clk); end loop;
    wait for CP/4;
    r1 := to_integer(acc(0));
    report "ventana A (8 canales): acc0 = " & integer'image(r1) & " (esperado 1440)";
    wait until rising_edge(clk);

    -- VENTANA B: SOLO canal 0 con valor 10, resto en cero
    win_start <= '1'; wait until rising_edge(clk); win_start <= '0';
    for p in 0 to 8 loop
      a_col(0) <= to_signed(10, C_DATA_W);
      for r in 1 to 7 loop a_col(r) <= (others => '0'); end loop;
      en <= '1'; wait until rising_edge(clk);
    end loop;
    en <= '0';
    win_end <= '1'; wait until rising_edge(clk); win_end <= '0';
    for w in 0 to 3 loop wait until rising_edge(clk); end loop;
    wait for CP/4;
    r2 := to_integer(acc(0));
    report "ventana B (1 canal):  acc0 = " & integer'image(r2) & " (esperado 180)";
    if r2 = 180 then
      report "SONDA_OCIO PASS filas ociosas limpias" severity note;
    else
      report "SONDA_OCIO FAIL residuo en filas ociosas" severity note;
    end if;
    done <= true; wait;
  end process;
end architecture;
