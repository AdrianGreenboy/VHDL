-- =============================================================================
-- HERCOSSNUX PQC IP Core - verification only
-- pqc_round_ref_pkg: integer reference models of the ML-DSA rounding
-- functions, FIPS 204 Power2Round (Alg 35), Decompose (Alg 36),
-- MakeHint (Alg 39), UseHint (Alg 40).
-- VHDL-2008. ASCII-only. MIT license.
--
-- Moved out of rtl/pqc_round_pkg.vhd by the 2026-11 audit. These are the
-- Layer 2 models exercised by verif/tb_round.vhd; the synthesised ML-DSA
-- datapath uses rtl/pqc_round_d_pkg.vhd. make_hint keeps its normalisation
-- loops here because it accepts any integer z in the Layer 2 vectors; it is
-- not synthesis code.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pqc_round_pkg.all;

package pqc_round_ref_pkg is

  constant C_D      : integer := 13;               -- Power2Round parameter
  constant C_GAMMA2 : integer := 261888;           -- (q-1)/32

  -- Multiply-and-shift constants replacing division by 2*gamma2 (Decompose).
  constant C_DMUL : integer := 8396809;
  constant C_DSHF : integer := 42;

  function power2round_hi (r : integer) return integer;
  function power2round_lo (r : integer) return integer;

  function decompose_hi (r : integer) return integer;
  function decompose_lo (r : integer) return integer;

  function make_hint (z : integer; r : integer) return integer;
  function use_hint  (h : integer; r : integer) return integer;

end package pqc_round_ref_pkg;

package body pqc_round_ref_pkg is

  -- Power2Round(r) = (r1, r0) with r = r1 * 2^d + r0 and r0 centred.
  function power2round_lo (r : integer) return integer is
    variable rp : integer;
    variable r0 : integer;
  begin
    rp := r;
    r0 := to_integer(unsigned(std_logic_vector(
            to_unsigned(rp, 32)(C_D - 1 downto 0))));
    if r0 > (2 ** (C_D - 1)) then
      r0 := r0 - (2 ** C_D);
    end if;
    return r0;
  end function power2round_lo;

  function power2round_hi (r : integer) return integer is
  begin
    return to_integer(shift_right(
             to_signed(r - power2round_lo(r), 32), C_D));
  end function power2round_hi;

  -- Decompose(r) = (r1, r0), FIPS 204 Algorithm 36.
  function decompose_lo (r : integer) return integer is
    variable rp : integer;
    variable r0 : integer;
  begin
    rp := r;
    r0 := rp - (to_integer(shift_right(to_signed(rp, 64) *
                                       to_signed(C_DMUL, 64), C_DSHF)) *
                (2 * C_GAMMA2));
    if r0 > C_GAMMA2 then
      r0 := r0 - 2 * C_GAMMA2;
    end if;
    -- Boundary case: when r - r0 wraps to q-1 the high part must be forced to
    -- zero and the low part decremented. Dropping this is a pre-registered
    -- mutation; without it one residue class in 2^23 is silently wrong.
    if rp - r0 = C_QD - 1 then
      r0 := r0 - 1;
    end if;
    return r0;
  end function decompose_lo;

  function decompose_hi (r : integer) return integer is
    variable rp : integer;
    variable q  : integer;
    variable r0 : integer;
  begin
    rp := r;
    -- q = floor(r / (2*gamma2)) by multiply and shift
    q  := to_integer(shift_right(to_signed(rp, 64) *
                                 to_signed(C_DMUL, 64), C_DSHF));
    r0 := rp - q * (2 * C_GAMMA2);
    if r0 > C_GAMMA2 then
      r0 := r0 - 2 * C_GAMMA2;
      q  := q + 1;
    end if;
    -- Boundary case: r1 wraps to zero when r - r0 reaches q-1.
    if rp - r0 = C_QD - 1 then
      return 0;
    end if;
    return q;
  end function decompose_hi;

  -- MakeHint(z, r) = 1 iff adding z changes the high bits of r.
  function make_hint (z : integer; r : integer) return integer is
    variable rz : integer;
  begin
    rz := r + z;
    while rz < 0 loop
      rz := rz + C_QD;
    end loop;
    while rz >= C_QD loop
      rz := rz - C_QD;
    end loop;
    if decompose_hi(r) /= decompose_hi(rz) then
      return 1;
    end if;
    return 0;
  end function make_hint;

  -- UseHint(h, r), FIPS 204 Algorithm 40. m = (q-1)/(2*gamma2) = 16.
  function use_hint (h : integer; r : integer) return integer is
    constant M  : integer := 16;
    variable r1 : integer;
    variable r0 : integer;
  begin
    r1 := decompose_hi(r);
    r0 := decompose_lo(r);
    if h = 1 then
      if r0 > 0 then
        if r1 + 1 = M then
          return 0;
        end if;
        return r1 + 1;
      else
        if r1 = 0 then
          return M - 1;
        end if;
        return r1 - 1;
      end if;
    end if;
    return r1;
  end function use_hint;

end package body pqc_round_ref_pkg;
