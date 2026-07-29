-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 2
-- pqc_round_pkg: rounding, compression and hint arithmetic.
--   ML-KEM  (FIPS 203): Compress_d / Decompress_d, section 4.2.1
--   ML-DSA  (FIPS 204): Power2Round (Alg 35), Decompose (Alg 36),
--                       HighBits (Alg 37), LowBits (Alg 38),
--                       MakeHint (Alg 39), UseHint (Alg 40)
-- VHDL-2008. ASCII-only. MIT license.
--
-- Arithmetic policy (frozen scope section 3): no `mod` and no division in the
-- datapath. Every division by a constant is replaced by a multiply-and-shift
-- whose multiplier and shift were verified exhaustively over the entire input
-- domain by verif/gen_l2.py: 3329 inputs per Compress width, and all 8380417
-- residues for Decompose. Reduction to a range uses conditional add/sub.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pqc_round_pkg is

  constant C_QK     : integer := 3329;
  constant C_QD     : integer := 8380417;
  constant C_D      : integer := 13;               -- Power2Round parameter
  constant C_GAMMA2 : integer := 261888;           -- (q-1)/32
  constant C_OMEGA  : integer := 55;
  constant C_KK     : integer := 6;                -- ML-DSA-65 rows

  -- Multiply-and-shift constants replacing division by q (ML-KEM Compress).
  -- Indexed by d in {1, 4, 10, 12}; unused entries are zero.
  type t_cconst is array (0 to 12) of integer;
  constant C_CMUL : t_cconst := (
    0, 5040, 0, 0, 20159, 0, 0, 0, 0, 0, 2580335, 0, 2580335);
  constant C_CSHF : t_cconst := (
    0, 24, 0, 0, 26, 0, 0, 0, 0, 0, 33, 0, 33);

  -- Multiply-and-shift constants replacing division by 2*gamma2 (Decompose).
  constant C_DMUL : integer := 8396809;
  constant C_DSHF : integer := 42;

  function compress_k   (d : integer; x : integer) return integer;
  function decompress_k (d : integer; y : integer) return integer;

  function power2round_hi (r : integer) return integer;
  function power2round_lo (r : integer) return integer;

  function decompose_hi (r : integer) return integer;
  function decompose_lo (r : integer) return integer;

  function make_hint (z : integer; r : integer) return integer;
  function use_hint  (h : integer; r : integer) return integer;

end package pqc_round_pkg;

package body pqc_round_pkg is

  -- Compress_d(x) = round(2^d / q * x) mod 2^d, FIPS 203 section 4.2.1.
  -- Rounding is to nearest with ties going up, which is why q/2 is added
  -- before the division. Using a floor here instead would bias every
  -- ciphertext coefficient and is a pre-registered mutation.
  function compress_k (d : integer; x : integer) return integer is
    variable n : signed(47 downto 0);
    variable p : signed(95 downto 0);
    variable r : integer;
  begin
    -- q/2 = 1664 for q = 3329, folded as a constant.
    -- Widths are deliberate: x is 12 bits, x<<12 is 24, and multiplying by a
    -- 22-bit constant needs 46, so a 32-bit intermediate would truncate.
    n := shift_left(to_signed(x, 48), d) + to_signed(1664, 48);
    p := n * to_signed(C_CMUL(d), 48);
    r := to_integer(shift_right(p, C_CSHF(d))(31 downto 0));
    -- reduce modulo 2^d by masking, never by the mod operator
    return to_integer(unsigned(std_logic_vector(
             to_unsigned(r, 32)(d - 1 downto 0))));
  end function compress_k;

  -- Decompress_d(y) = round(q / 2^d * y), FIPS 203 section 4.2.1.
  function decompress_k (d : integer; y : integer) return integer is
  begin
    return to_integer(shift_right(
             to_signed(y * C_QK + to_integer(
               shift_left(to_signed(1, 32), d - 1)), 64), d));
  end function decompress_k;

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

end package body pqc_round_pkg;
