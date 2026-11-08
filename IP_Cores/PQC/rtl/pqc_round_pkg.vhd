-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 2
-- pqc_round_pkg: ML-KEM rounding and compression (RTL).
--   ML-KEM  (FIPS 203): Compress_d / Decompress_d, section 4.2.1
--
-- The Layer 2 integer models of the ML-DSA rounding functions (Power2Round,
-- Decompose, MakeHint, UseHint) used to live here as well. No RTL uses them
-- (the ML-DSA datapath uses the fixed-width pqc_round_d_pkg), and MakeHint
-- contained data-dependent while loops, which do not belong in a synthesis
-- package. The 2026-11 audit moved them to verif/pqc_round_ref_pkg.vhd.
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
  constant C_OMEGA  : integer := 55;
  constant C_KK     : integer := 6;                -- ML-DSA-65 rows

  -- Multiply-and-shift constants replacing division by q (ML-KEM Compress).
  -- Indexed by d in {1, 4, 10, 12}; unused entries are zero.
  type t_cconst is array (0 to 12) of integer;
  constant C_CMUL : t_cconst := (
    0, 5040, 0, 0, 20159, 0, 0, 0, 0, 0, 2580335, 0, 2580335);
  constant C_CSHF : t_cconst := (
    0, 24, 0, 0, 26, 0, 0, 0, 0, 0, 33, 0, 33);


  function compress_k   (d : integer; x : integer) return integer;
  function decompress_k (d : integer; y : integer) return integer;


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

end package body pqc_round_pkg;
