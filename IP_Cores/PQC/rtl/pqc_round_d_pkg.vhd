-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- pqc_round_d_pkg: ML-DSA rounding and bit-packing primitives.
-- VHDL-2008. ASCII-only. MIT license.
--
-- These are pure functions, verified EXHAUSTIVELY against mldsa65.py over all
-- 8380417 residues rather than by sampling. A one-bit error in a boundary
-- condition here shows up on a handful of inputs out of eight million, so
-- spot checks are not enough: power2round_d and decompose_d were each run
-- over the entire modulus with zero mismatches before this file was written.
--
-- Two divisions are avoided, because both would synthesise real dividers:
--
--  1. decompose divides by 2*GAMMA2 = 523776 and also needs r mod 2*GAMMA2.
--     Both come from one multiply-shift, mul 8396809 then shift right 42:
--     the quotient directly, and the remainder as r - quotient*2*GAMMA2.
--     Verified over all 8380417 residues, not derived on paper. A `mod`
--     operator here would synthesise a real divider, and a 16-deep subtract
--     chain would be no better.
--
--  2. use_hint computes (r1 +- 1) mod m with m = (q-1)/(2*GAMMA2) = 16.
--     Sixteen is a power of two, so this is a 4-bit wraparound. That
--     equivalence holds only because r1 is already confined to [0, 15], which
--     was checked rather than assumed.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;

package pqc_round_d_pkg is

  constant C_D_D      : integer := 13;
  constant C_ETA_DD   : integer := 4;
  constant C_GAMMA1_DD : integer := 524288;
  constant C_GAMMA2_DD : integer := 261888;
  constant C_TWOG2    : integer := 523776;      -- 2 * GAMMA2
  constant C_MHINT    : integer := 16;          -- (q-1) / (2*GAMMA2)
  constant C_OMEGA_D  : integer := 55;
  constant C_TAU_DD   : integer := 49;

  -- multiply-shift replacing the division by 2*GAMMA2
  constant C_DIVMUL   : integer := 8396809;
  constant C_DIVSH    : integer := 42;

  function canon_d (x : signed) return unsigned;
  function p2r_hi  (r : unsigned) return unsigned;
  function p2r_lo  (r : unsigned) return signed;
  function dec_lo  (r : unsigned) return signed;
  function dec_hi  (r : unsigned) return unsigned;
  function use_hint_d (h : std_logic; r : unsigned) return unsigned;

end package pqc_round_d_pkg;

package body pqc_round_d_pkg is

  -- Reduce a signed representative into [0, q).
  --
  -- Callers pass values already within one multiple of q of the range, which
  -- is what the datapath produces, so a single conditional add and a single
  -- conditional subtract suffice. An unbounded loop would be correct in
  -- simulation and unsynthesisable in hardware.
  function canon_d (x : signed) return unsigned is
    variable v : signed(C_CW downto 0);
  begin
    v := resize(x, C_CW + 1);
    if v < 0 then
      v := v + to_signed(C_QD, C_CW + 1);
    end if;
    if v >= to_signed(C_QD, C_CW + 1) then
      v := v - to_signed(C_QD, C_CW + 1);
    end if;
    return resize(unsigned(v), C_CW);
  end function canon_d;

  -- r / 2*GAMMA2 and r mod 2*GAMMA2 from one multiply-shift.
  --
  -- The product width is the SUM of the operand widths, not the width of the
  -- destination. r needs 23 bits and C_DIVMUL needs 24, so the product is 47
  -- and the shift by 42 leaves 5. Sizing the operands explicitly keeps every
  -- intermediate inside a declared width; the same defect bit mont_d in
  -- ntt_d_unit, where a 96-bit product was assigned to a 64-bit variable.
  function twog2_quot (r : unsigned) return unsigned is
    variable ra : unsigned(23 downto 0);
    variable pr : unsigned(47 downto 0);
  begin
    ra := resize(r, 24);
    pr := ra * to_unsigned(C_DIVMUL, 24);
    return resize(shift_right(pr, C_DIVSH), C_CW);
  end function twog2_quot;

  function twog2_rem (r : unsigned) return unsigned is
    variable q  : unsigned(4 downto 0);
    variable pr : unsigned(24 downto 0);
  begin
    -- the quotient never exceeds 16, so five bits hold it
    q  := resize(twog2_quot(r), 5);
    pr := q * to_unsigned(C_TWOG2, 20);
    return r - resize(pr, C_CW);
  end function twog2_rem;

  -- Power2Round low part: the low D bits taken as a signed value centred on
  -- zero. The boundary is STRICTLY greater than 2^(D-1), so r0 = 2^(D-1)
  -- stays positive; using >= here would flip a whole class of inputs.
  function p2r_lo (r : unsigned) return signed is
    variable lo : signed(C_D_D + 1 downto 0);
  begin
    lo := resize(signed('0' & r(C_D_D - 1 downto 0)), C_D_D + 2);
    if lo > to_signed(2 ** (C_D_D - 1), C_D_D + 2) then
      lo := lo - to_signed(2 ** C_D_D, C_D_D + 2);
    end if;
    return resize(lo, C_CW);
  end function p2r_lo;

  function p2r_hi (r : unsigned) return unsigned is
    variable lo  : signed(C_CW downto 0);
    variable num : signed(C_CW downto 0);
  begin
    lo  := resize(p2r_lo(r), C_CW + 1);
    num := signed('0' & r) - lo;
    return resize(unsigned(shift_right(num, C_D_D)), C_CW);
  end function p2r_hi;

  -- Decompose low part, same centring rule against GAMMA2.
  function dec_lo (r : unsigned) return signed is
    variable lo : signed(C_CW downto 0);
    variable hi : signed(C_CW downto 0);
  begin
    lo := signed('0' & twog2_rem(r));
    if lo > to_signed(C_GAMMA2_DD, C_CW + 1) then
      lo := lo - to_signed(C_TWOG2, C_CW + 1);
    end if;
    -- the wraparound case: when the high part would be q-1 it is forced to
    -- zero and the low part absorbs the difference
    hi := signed('0' & r) - lo;
    if hi = to_signed(C_QD - 1, C_CW + 1) then
      lo := lo - to_signed(1, C_CW + 1);
    end if;
    return resize(lo, C_CW);
  end function dec_lo;

  function dec_hi (r : unsigned) return unsigned is
    variable lo  : signed(C_CW downto 0);
    variable hi  : signed(C_CW downto 0);
  begin
    lo := signed('0' & twog2_rem(r));
    if lo > to_signed(C_GAMMA2_DD, C_CW + 1) then
      lo := lo - to_signed(C_TWOG2, C_CW + 1);
    end if;
    hi := signed('0' & r) - lo;
    if hi = to_signed(C_QD - 1, C_CW + 1) then
      return to_unsigned(0, C_CW);
    end if;
    return twog2_quot(unsigned(hi(C_CW - 1 downto 0)));
  end function dec_hi;

  -- UseHint. The modulo is a 4-bit mask because m = 16, and r1 never leaves
  -- [0, 15]; both facts were checked against the oracle.
  function use_hint_d (h : std_logic; r : unsigned) return unsigned is
    variable r1 : unsigned(C_CW - 1 downto 0);
    variable r0 : signed(C_CW - 1 downto 0);
    variable v  : unsigned(3 downto 0);
  begin
    r1 := dec_hi(r);
    r0 := dec_lo(r);
    if h = '1' then
      if r0 > 0 then
        v := r1(3 downto 0) + 1;
      else
        v := r1(3 downto 0) - 1;
      end if;
      return resize(v, C_CW);
    end if;
    return r1;
  end function use_hint_d;

end package body pqc_round_d_pkg;
