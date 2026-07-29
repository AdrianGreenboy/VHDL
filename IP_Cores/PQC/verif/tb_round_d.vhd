-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- tb_round_d: verifies the ML-DSA rounding primitives against oracle vectors.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Two layers of checking:
--
--  1. The vector file covers the boundary residues that matter, 0, 1,
--     GAMMA2, GAMMA2+1, 2*GAMMA2, q-1, q-2, 2^(D-1) and 2^(D-1)+1, plus
--     random ones. Those boundaries are where a comparison written as >=
--     instead of > silently flips a whole class of inputs.
--
--  2. An in-testbench sweep re-derives power2round and decompose across the
--     modulus in steps and checks the two agree with each other, so a
--     mutation that breaks only the far end of the range cannot hide behind
--     a vector list that happens to sample the near end.
--
-- The multiply-shift replacing the division by 2*GAMMA2 was separately
-- verified against Python over ALL 8380417 residues before the RTL was
-- written; that check is recorded in the notes rather than repeated here,
-- because a full sweep in simulation would take far longer than it is worth.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;

entity tb_round_d is
end entity tb_round_d;

architecture sim of tb_round_d is

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

  process
    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 3);
    variable n   : integer := 0;
    variable sweep : integer := 0;
    variable sig : unsigned(63 downto 0) := x"cbf29ce484222325";

    variable r, p1, p0, d1, d0, u0, u1 : integer;
    variable gp1, gp0, gd1, gd0, gu0, gu1 : integer;

    procedure fnv (variable s : inout unsigned(63 downto 0);
                   constant x : in integer) is
      variable u : unsigned(31 downto 0);
      variable b : unsigned(63 downto 0);
    begin
      u := unsigned(to_signed(x, 32));
      for k in 0 to 3 loop
        b := resize(u((k * 8 + 7) downto (k * 8)), 64);
        s := s xor b;
        s := resize(s * x"00000100000001b3", 64);
      end loop;
    end procedure;

  begin
    file_open(fh, "dsa_round_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length < 3 then
        next;
      end if;
      read(ln, tag);
      if tag(1) = '#' then
        next;
      end if;
      if tag /= "RND" then
        next;
      end if;

      read(ln, r);
      read(ln, p1);
      read(ln, p0);
      read(ln, d1);
      read(ln, d0);
      read(ln, u0);
      read(ln, u1);

      gp1 := to_integer(p2r_hi(to_unsigned(r, C_CW)));
      gp0 := to_integer(p2r_lo(to_unsigned(r, C_CW)));
      gd1 := to_integer(dec_hi(to_unsigned(r, C_CW)));
      gd0 := to_integer(dec_lo(to_unsigned(r, C_CW)));
      gu0 := to_integer(use_hint_d('0', to_unsigned(r, C_CW)));
      gu1 := to_integer(use_hint_d('1', to_unsigned(r, C_CW)));

      assert gp1 = p1 and gp0 = p0
        report "TB FAIL power2round r=" & integer'image(r) &
               " got (" & integer'image(gp1) & "," & integer'image(gp0) &
               ") exp (" & integer'image(p1) & "," & integer'image(p0) & ")"
        severity failure;
      assert gd1 = d1 and gd0 = d0
        report "TB FAIL decompose r=" & integer'image(r) &
               " got (" & integer'image(gd1) & "," & integer'image(gd0) &
               ") exp (" & integer'image(d1) & "," & integer'image(d0) & ")"
        severity failure;
      assert gu0 = u0 and gu1 = u1
        report "TB FAIL use_hint r=" & integer'image(r) &
               " got (" & integer'image(gu0) & "," & integer'image(gu1) &
               ") exp (" & integer'image(u0) & "," & integer'image(u1) & ")"
        severity failure;

      fnv(sig, gp1); fnv(sig, gp0);
      fnv(sig, gd1); fnv(sig, gd0);
      fnv(sig, gu0); fnv(sig, gu1);
      n := n + 1;
    end loop;
    file_close(fh);

    -- Sweep the modulus and check the identities that define the two
    -- decompositions. This catches a mutation that only misbehaves far from
    -- the sampled vectors.
    for k in 0 to 4095 loop
      r  := (k * 2047) mod C_QD;
      gp1 := to_integer(p2r_hi(to_unsigned(r, C_CW)));
      gp0 := to_integer(p2r_lo(to_unsigned(r, C_CW)));
      assert gp1 * 8192 + gp0 = r
        report "TB FAIL power2round identity at r=" & integer'image(r) &
               " r1*2^D + r0 = " & integer'image(gp1 * 8192 + gp0)
        severity failure;

      gd1 := to_integer(dec_hi(to_unsigned(r, C_CW)));
      gd0 := to_integer(dec_lo(to_unsigned(r, C_CW)));
      -- The identity r = r1*2*GAMMA2 + r0 holds except at the wraparound,
      -- where the high part would have been q-1 and is forced to zero while
      -- the low part absorbs an extra -1. There r1*2g2 + r0 = r - q, not
      -- r - q + 1: the first version of this assertion was off by one and
      -- flagged CORRECT rtl at r = 8120449, where the oracle also returns
      -- (0, -259968).
      assert gd1 * 523776 + gd0 = r or gd1 * 523776 + gd0 = r - C_QD
        report "TB FAIL decompose identity at r=" & integer'image(r) &
               " r1*2g2 + r0 = " & integer'image(gd1 * 523776 + gd0)
        severity failure;
      assert gd1 >= 0 and gd1 <= 15
        report "TB FAIL decompose high part out of [0,15] at r=" &
               integer'image(r) & " got " & integer'image(gd1)
        severity failure;
      fnv(sig, gd1);
      sweep := sweep + 1;
    end loop;

    assert n >= 40
      report "TB FAIL expected at least 40 rounding vectors, got " &
             integer'image(n)
      severity failure;

    report "PQC L3B ROUNDD PASS vectors=" & integer'image(n) &
           " sweep=" & integer'image(sweep) &
           " sig=" & to_hex(sig)
      severity note;
    wait;
  end process;

end architecture sim;
