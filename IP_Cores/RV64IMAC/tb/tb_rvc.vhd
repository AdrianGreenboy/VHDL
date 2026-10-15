-- tb_rvc: Capa 1, decompresor RVC exhaustivo contra el ISS (49152 casos).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.rv64_pkg.all;

entity tb_rvc is
  generic (VECTORS : string := "rvc_vectors.txt");
end entity;

architecture sim of tb_rvc is
begin
  process
    file f        : text open read_mode is VECTORS;
    variable l    : line;
    variable c    : std_logic_vector(15 downto 0);
    variable bad  : integer;
    variable exp  : std_logic_vector(31 downto 0);
    variable got  : std_logic_vector(32 downto 0);
    variable n, errs : integer := 0;
  begin
    while not endfile(f) loop
      readline(f, l);
      hread(l, c); read(l, bad); hread(l, exp);
      got := expand_c(c);
      if (got(32) = '1') /= (bad = 1) or (bad = 0 and got(31 downto 0) /= exp) then
        errs := errs + 1;
        if errs < 10 then
          report "MISMATCH c=" & to_hstring(c) & " esperado " & to_hstring(exp) & " bad=" & integer'image(bad)
               & " obtenido " & to_hstring(got(31 downto 0)) & " bad=" & std_logic'image(got(32));
        end if;
      end if;
      n := n + 1;
    end loop;
    if errs = 0 then
      report "tb_rvc PASS casos=" & integer'image(n);
    else
      report "tb_rvc FAIL errores=" & integer'image(errs) severity failure;
    end if;
    wait;
  end process;
end architecture;
