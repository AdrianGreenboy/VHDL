-- tb_muldiv: Capa 1, unidad M iterativa contra el ISS (esquinas + aleatorios).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.rv64_pkg.all;

entity tb_muldiv is
  generic (VECTORS : string := "muldiv_vectors.txt");
end entity;

architecture sim of tb_muldiv is
  signal clk : std_logic := '0';
  signal rst, start, kill, ack, is_w, busy, done : std_logic := '0';
  signal f3 : std_logic_vector(2 downto 0);
  signal a, b, result : xword;
  signal fin : boolean := false;
begin
  clk <= not clk after 5 ns when not fin;
  dut : entity work.rv64_muldiv port map (clk, rst, start, kill, ack, f3, is_w, a, b, busy, done, result);

  process
    file f : text open read_mode is VECTORS;
    variable l : line;
    variable vf3, vw : integer;
    variable va, vb, exp : xword;
    variable n, errs : integer := 0;
  begin
    rst <= '1'; wait until rising_edge(clk); rst <= '0';
    while not endfile(f) loop
      readline(f, l);
      read(l, vf3); read(l, vw); hread(l, va); hread(l, vb); hread(l, exp);
      f3 <= std_logic_vector(to_unsigned(vf3, 3));
      is_w <= '1' when vw = 1 else '0';
      a <= va; b <= vb; start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait until rising_edge(clk) and done = '1';
      if result /= exp then
        errs := errs + 1;
        if errs < 10 then
          report "MISMATCH f3=" & integer'image(vf3) & " w=" & integer'image(vw) & " a=" & to_hstring(va)
               & " b=" & to_hstring(vb) & " esperado=" & to_hstring(exp) & " obtenido=" & to_hstring(result);
        end if;
      end if;
      ack <= '1'; wait until rising_edge(clk); ack <= '0';
      n := n + 1;
    end loop;
    if errs = 0 then report "tb_muldiv PASS casos=" & integer'image(n);
    else report "tb_muldiv FAIL errores=" & integer'image(errs) severity failure; end if;
    fin <= true;
    wait;
  end process;
end architecture;
