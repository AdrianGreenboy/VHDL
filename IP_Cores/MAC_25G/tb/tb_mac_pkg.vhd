-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 1A: funciones y constantes de mac25g_pkg contra el oraculo.
--   * crc_nbytes(estado, dato, n) para n = 1..8 (400 vectores, estados
--     aleatorios y CRC_INIT), anclado a zlib a traves del oraculo
--   * xorshift64 y seed_of
--   * bloques S, I, E y tipos T0..T7
-- Criterio: LAYER1A_PASS FNV32=<firma del oraculo>.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.mac25g_pkg.all;

entity tb_mac_pkg is
end entity;

architecture sim of tb_mac_pkg is
begin
  process
    file f : text;
    variable l : line;
    variable nv, n, errs : integer := 0;
    variable st, c_e, c : std_logic_vector(31 downto 0);
    variable d, x_e, s_e, x, k : std_logic_vector(63 downto 0);
    variable h : unsigned(31 downto 0) := x"811C9DC5";
    procedure fnv32(w : std_logic_vector(31 downto 0)) is
    begin
      for i in 0 to 3 loop
        h := h xor resize(unsigned(w(8*i+7 downto 8*i)), 32);
        h := resize(h * to_unsigned(16777619, 32), 32);
      end loop;
    end procedure;
  begin
    file_open(f, "l1_pkg.txt", read_mode);
    readline(f, l); read(l, nv);
    for i in 1 to nv loop
      readline(f, l);
      hread(l, st); hread(l, d); read(l, n); hread(l, c_e); hread(l, x_e); hread(l, s_e);
      c := crc_nbytes(st, d, to_unsigned(n, 4));
      if d = x"0000000000000000" then x := x"0000000000000001";
      else x := xorshift64(d); end if;
      if c /= c_e or x /= x_e or seed_of(st) /= s_e then
        errs := errs + 1;
        if errs < 5 then
          report "MISMATCH vector " & integer'image(i) & " crc=" & to_hstring(c) &
            "/" & to_hstring(c_e) & " xs=" & to_hstring(x) & "/" & to_hstring(x_e)
            severity error;
        end if;
      end if;
      fnv32(c); fnv32(x(31 downto 0)); fnv32(x(63 downto 32));
    end loop;
    file_close(f);

    file_open(f, "l1_const.txt", read_mode);
    readline(f, l); hread(l, k);
    if k /= START_BLOCK then errs := errs + 1; report "FAIL START_BLOCK" severity error; end if;
    readline(f, l); hread(l, k);
    if k /= IDLE_BLOCK then errs := errs + 1; report "FAIL IDLE_BLOCK" severity error; end if;
    readline(f, l); hread(l, k);
    if k /= ERROR_BLOCK then errs := errs + 1; report "FAIL ERROR_BLOCK" severity error; end if;
    for t in 0 to 7 loop
      readline(f, l); hread(l, k);
      if k(7 downto 0) /= term_type(t) then
        errs := errs + 1;
        report "FAIL term_type(" & integer'image(t) & ")" severity error;
      end if;
    end loop;
    file_close(f);

    if errs = 0 then
      report "LAYER1A_PASS FNV32=0x" & to_hstring(std_logic_vector(h)) &
        " vectores=" & integer'image(nv);
    else
      report "LAYER1A_FAIL errores=" & integer'image(errs) severity error;
    end if;
    wait;
  end process;
end architecture;
