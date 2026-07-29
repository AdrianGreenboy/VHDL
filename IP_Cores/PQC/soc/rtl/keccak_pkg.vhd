-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1
-- keccak_pkg: Keccak-f[1600] state type, round constants, single-round function
-- VHDL-2008. ASCII-only. MIT license.
--
-- State is a flat array of 25 64-bit lanes. Lane index i maps to the (x,y)
-- coordinates of FIPS 202 as x = i mod 5, y = i / 5.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package keccak_pkg is

  subtype t_lane is std_logic_vector(63 downto 0);
  type t_state is array (0 to 24) of t_lane;

  type t_rc_array is array (0 to 23) of t_lane;

  constant C_RC : t_rc_array := (
    x"0000000000000001", x"0000000000008082", x"800000000000808A",
    x"8000000080008000", x"000000000000808B", x"0000000080000001",
    x"8000000080008081", x"8000000000008009", x"000000000000008A",
    x"0000000000000088", x"0000000080008009", x"000000008000000A",
    x"000000008000808B", x"800000000000008B", x"8000000000008089",
    x"8000000000008003", x"8000000000008002", x"8000000000000080",
    x"000000000000800A", x"800000008000000A", x"8000000080008081",
    x"8000000000008080", x"0000000080000001", x"8000000080008008");

  -- Rotation offsets, indexed [x][y] as in FIPS 202 Table 2.
  type t_rot_row is array (0 to 4) of integer range 0 to 63;
  type t_rot is array (0 to 4) of t_rot_row;

  constant C_ROT : t_rot := (
    (0, 36,  3, 41, 18),
    (1, 44, 10, 45,  2),
    (62, 6, 43, 15, 61),
    (28, 55, 25, 21, 56),
    (27, 20, 39,  8, 14));

  function rotl (x : t_lane; n : integer) return t_lane;
  function keccak_round (s : t_state; rc : t_lane) return t_state;

end package keccak_pkg;

package body keccak_pkg is

  function rotl (x : t_lane; n : integer) return t_lane is
    variable m : integer;
  begin
    m := n mod 64;
    if m = 0 then
      return x;
    end if;
    return x(63 - m downto 0) & x(63 downto 64 - m);
  end function rotl;

  -- One full Keccak round: theta, rho, pi, chi, iota.
  function keccak_round (s : t_state; rc : t_lane) return t_state is
    variable c   : t_state;
    variable d   : t_state;
    variable a   : t_state;
    variable b   : t_state;
    variable r   : t_state;
    variable idx : integer;
  begin
    -- theta
    for x in 0 to 4 loop
      c(x) := s(x) xor s(x + 5) xor s(x + 10) xor s(x + 15) xor s(x + 20);
    end loop;
    for x in 0 to 4 loop
      d(x) := c((x + 4) mod 5) xor rotl(c((x + 1) mod 5), 1);
    end loop;
    for x in 0 to 4 loop
      for y in 0 to 4 loop
        a(x + 5 * y) := s(x + 5 * y) xor d(x);
      end loop;
    end loop;

    -- rho and pi combined: B[y][(2x+3y) mod 5] = rot(A[x][y], r[x][y])
    for x in 0 to 4 loop
      for y in 0 to 4 loop
        idx := y + 5 * ((2 * x + 3 * y) mod 5);
        b(idx) := rotl(a(x + 5 * y), C_ROT(x)(y));
      end loop;
    end loop;

    -- chi
    for x in 0 to 4 loop
      for y in 0 to 4 loop
        r(x + 5 * y) := b(x + 5 * y) xor
                        ((not b(((x + 1) mod 5) + 5 * y)) and
                         b(((x + 2) mod 5) + 5 * y));
      end loop;
    end loop;

    -- iota
    r(0) := r(0) xor rc;

    return r;
  end function keccak_round;

end package body keccak_pkg;
