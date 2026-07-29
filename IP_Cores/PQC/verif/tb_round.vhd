-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 2 testbench
-- tb_round: validates pqc_round_pkg against reference vectors derived from
-- the ACVP-validated Phase 0 oracles.
--
-- Covers Compress/Decompress (FIPS 203 section 4.2.1) and Power2Round,
-- Decompose, MakeHint, UseHint (FIPS 204 Algorithms 35, 36, 39, 40).
-- Boundary cases are directed, not random: every multiple of 2*gamma2 and its
-- immediate neighbours are exercised, which is what makes the Decompose
-- wrap-around mutation detectable.
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.pqc_round_pkg.all;

entity tb_round is
  generic (
    G_VFILE : string := "l2_vectors.txt");
end entity tb_round;

architecture sim of tb_round is

  function to_hex (v : unsigned(63 downto 0)) return string is
    constant D : string(1 to 16) := "0123456789abcdef";
    variable r : string(1 to 16);
  begin
    for i in 0 to 15 loop
      r(16 - i) := D(to_integer(v(4 * i + 3 downto 4 * i)) + 1);
    end loop;
    return r;
  end function to_hex;

begin

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable tag    : string(1 to 3);
    variable c      : character;
    variable a, b, e : integer;
    variable got    : integer;
    variable n      : integer := 0;
    variable ncmp, ndcp, np2r, ndec, nmkh, nush : integer := 0;

    procedure sig_update (variable s : inout unsigned(63 downto 0);
                          x : in integer) is
      variable u : unsigned(63 downto 0);
      variable w : unsigned(31 downto 0);
    begin
      if x < 0 then
        w := to_unsigned(x + 2147483647 + 1, 32);
      else
        w := to_unsigned(x, 32);
      end if;
      for i in 0 to 3 loop
        u := s xor resize(w(8 * i + 7 downto 8 * i), 64);
        u := u + shift_left(u, 1) + shift_left(u, 4) + shift_left(u, 5) +
             shift_left(u, 7) + shift_left(u, 8) + shift_left(u, 40);
        s := u;
      end loop;
    end procedure sig_update;

  begin
    file_open(status, fp, G_VFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open Layer 2 vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      read(ln, tag(1));
      read(ln, tag(2));
      read(ln, tag(3));

      if tag = "CMP" then
        read(ln, a);          -- d
        read(ln, b);          -- x
        read(ln, e);          -- expected
        got := compress_k(a, b);
        assert got = e
          report "TB FAIL compress d=" & integer'image(a) &
                 " x=" & integer'image(b) &
                 " got=" & integer'image(got) &
                 " exp=" & integer'image(e)
          severity failure;
        ncmp := ncmp + 1;

      elsif tag = "DCP" then
        read(ln, a);
        read(ln, b);
        read(ln, e);
        got := decompress_k(a, b);
        assert got = e
          report "TB FAIL decompress d=" & integer'image(a) &
                 " y=" & integer'image(b) &
                 " got=" & integer'image(got) &
                 " exp=" & integer'image(e)
          severity failure;
        ndcp := ndcp + 1;

      elsif tag = "P2R" then
        read(ln, a);          -- r
        read(ln, b);          -- expected r1
        read(ln, e);          -- expected r0
        got := power2round_hi(a);
        assert got = b
          report "TB FAIL power2round hi r=" & integer'image(a) &
                 " got=" & integer'image(got) &
                 " exp=" & integer'image(b)
          severity failure;
        got := power2round_lo(a);
        assert got = e
          report "TB FAIL power2round lo r=" & integer'image(a) &
                 " got=" & integer'image(got) &
                 " exp=" & integer'image(e)
          severity failure;
        sig_update(sig, b);
        np2r := np2r + 1;

      elsif tag = "DEC" then
        read(ln, a);          -- r
        read(ln, b);          -- expected r1
        read(ln, e);          -- expected r0
        got := decompose_hi(a);
        assert got = b
          report "TB FAIL decompose hi r=" & integer'image(a) &
                 " got=" & integer'image(got) &
                 " exp=" & integer'image(b)
          severity failure;
        got := decompose_lo(a);
        assert got = e
          report "TB FAIL decompose lo r=" & integer'image(a) &
                 " got=" & integer'image(got) &
                 " exp=" & integer'image(e)
          severity failure;
        sig_update(sig, b);
        sig_update(sig, e);
        ndec := ndec + 1;

      elsif tag = "MKH" then
        read(ln, a);          -- z
        read(ln, b);          -- r
        read(ln, e);          -- expected hint
        got := make_hint(a, b);
        assert got = e
          report "TB FAIL make_hint z=" & integer'image(a) &
                 " r=" & integer'image(b) &
                 " got=" & integer'image(got) &
                 " exp=" & integer'image(e)
          severity failure;
        sig_update(sig, got);
        nmkh := nmkh + 1;

      elsif tag = "USH" then
        read(ln, a);          -- h
        read(ln, b);          -- r
        read(ln, e);          -- expected
        got := use_hint(a, b);
        assert got = e
          report "TB FAIL use_hint h=" & integer'image(a) &
                 " r=" & integer'image(b) &
                 " got=" & integer'image(got) &
                 " exp=" & integer'image(e)
          severity failure;
        sig_update(sig, got);
        nush := nush + 1;
      end if;

      if tag = "CMP" or tag = "DCP" then
        sig_update(sig, e);
      end if;
      n := n + 1;
    end loop;
    file_close(fp);

    report "PQC L2 ROUND PASS cmp=" & integer'image(ncmp) &
           " dcp=" & integer'image(ndcp) &
           " p2r=" & integer'image(np2r) &
           " dec=" & integer'image(ndec) &
           " mkh=" & integer'image(nmkh) &
           " ush=" & integer'image(nush) &
           " sig=" & to_hex(sig)
      severity note;

    wait;
  end process main;

end architecture sim;
