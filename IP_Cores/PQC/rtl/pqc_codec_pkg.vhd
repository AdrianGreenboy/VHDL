-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 2
-- pqc_codec_pkg: bit-level packing and unpacking codecs.
--   ML-KEM  ByteEncode_d / ByteDecode_d      FIPS 203 Algorithms 5, 6
--   ML-DSA  SimpleBitPack / SimpleBitUnpack  FIPS 204 Algorithms 16, 18
--   ML-DSA  BitPack / BitUnpack              FIPS 204 Algorithms 17, 19
--   ML-DSA  HintBitPack / HintBitUnpack      FIPS 204 Algorithms 20, 21
-- VHDL-2008. ASCII-only. MIT license.
--
-- Every codec is the same little-endian bit stream: fields of G_BITS bits are
-- emitted least significant bit first, packed contiguously across byte
-- boundaries. One parameterised implementation therefore covers all widths
-- (1, 4, 10, 12, 13, 20), which keeps the mutation surface small and means a
-- packing bug cannot hide in one width while the others pass.
--
-- BitPack additionally maps a signed coefficient x into the unsigned field
-- b - x before packing, where the pair (a, b) bounds the coefficient range.
-- Flipping that subtraction is a pre-registered mutation.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pqc_codec_pkg is

  constant C_QK    : integer := 3329;
  constant C_QD    : integer := 8380417;
  constant C_OMEGA : integer := 55;
  constant C_KK    : integer := 6;

  type t_poly  is array (0 to 255) of integer;
  type t_bytes is array (0 to 703) of integer;      -- max 640 bytes used
  type t_hints is array (0 to 6 * 256 - 1) of integer;
  type t_hbuf  is array (0 to C_OMEGA + C_KK - 1) of integer;

  -- Pack 256 coefficients of `bits` bits each into a little-endian bit stream.
  procedure bit_pack (p     : in  t_poly;
                      bits  : in  integer;
                      b     : out t_bytes;
                      nbyte : out integer);

  -- Inverse of bit_pack.
  procedure bit_unpack (b     : in  t_bytes;
                        bits  : in  integer;
                        p     : out t_poly);

  -- BitPack with the b - x mapping (FIPS 204 Algorithm 17).
  procedure bit_pack_signed (p     : in  t_poly;
                             a     : in  integer;
                             bb    : in  integer;
                             q     : in  integer;
                             bits  : in  integer;
                             b     : out t_bytes;
                             nbyte : out integer);

  -- Inverse of bit_pack_signed (FIPS 204 Algorithm 19).
  procedure bit_unpack_signed (b    : in  t_bytes;
                               a    : in  integer;
                               bb   : in  integer;
                               q    : in  integer;
                               bits : in  integer;
                               p    : out t_poly);

  -- HintBitPack (FIPS 204 Algorithm 20).
  procedure hint_pack (h : in t_hints; y : out t_hbuf);

  -- HintBitUnpack (FIPS 204 Algorithm 21).
  -- ok is false when the encoding is malformed, which a verifier must treat
  -- as an invalid signature rather than as a recoverable condition.
  procedure hint_unpack (y  : in  t_hbuf;
                         h  : out t_hints;
                         ok : out boolean);

end package pqc_codec_pkg;

package body pqc_codec_pkg is

  procedure bit_pack (p     : in  t_poly;
                      bits  : in  integer;
                      b     : out t_bytes;
                      nbyte : out integer) is
    variable acc  : unsigned(63 downto 0) := (others => '0');
    variable navl : integer := 0;
    variable idx  : integer := 0;
  begin
    b := (others => 0);
    for i in 0 to 255 loop
      acc  := acc or shift_left(to_unsigned(p(i), 64), navl);
      navl := navl + bits;
      while navl >= 8 loop
        b(idx) := to_integer(acc(7 downto 0));
        idx    := idx + 1;
        acc    := shift_right(acc, 8);
        navl   := navl - 8;
      end loop;
    end loop;
    -- 256 * bits is always a multiple of 8 for every width used here, so no
    -- partial byte can remain; asserting that keeps a bad width visible.
    assert navl = 0
      report "PQC CODEC bit_pack left a partial byte" severity failure;
    nbyte := idx;
  end procedure bit_pack;

  procedure bit_unpack (b    : in  t_bytes;
                        bits : in  integer;
                        p    : out t_poly) is
    variable acc  : unsigned(63 downto 0) := (others => '0');
    variable navl : integer := 0;
    variable idx  : integer := 0;
    variable mask : unsigned(63 downto 0);
  begin
    mask := shift_right(unsigned'(x"FFFFFFFFFFFFFFFF"), 64 - bits);
    for i in 0 to 255 loop
      while navl < bits loop
        acc  := acc or shift_left(to_unsigned(b(idx), 64), navl);
        idx  := idx + 1;
        navl := navl + 8;
      end loop;
      p(i) := to_integer(acc and mask);
      acc  := shift_right(acc, bits);
      navl := navl - bits;
    end loop;
  end procedure bit_unpack;

  procedure bit_pack_signed (p     : in  t_poly;
                             a     : in  integer;
                             bb    : in  integer;
                             q     : in  integer;
                             bits  : in  integer;
                             b     : out t_bytes;
                             nbyte : out integer) is
    variable t : t_poly;
    variable c : integer;
  begin
    for i in 0 to 255 loop
      -- centre the coefficient, then store b - x as an unsigned field
      c := p(i);
      if c > q / 2 then
        c := c - q;
      end if;
      t(i) := bb - c;
    end loop;
    bit_pack(t, bits, b, nbyte);
  end procedure bit_pack_signed;

  procedure bit_unpack_signed (b    : in  t_bytes;
                               a    : in  integer;
                               bb   : in  integer;
                               q    : in  integer;
                               bits : in  integer;
                               p    : out t_poly) is
    variable t : t_poly;
    variable c : integer;
  begin
    bit_unpack(b, bits, t);
    for i in 0 to 255 loop
      c := bb - t(i);
      if c < 0 then
        c := c + q;
      end if;
      p(i) := c;
    end loop;
  end procedure bit_unpack_signed;

  procedure hint_pack (h : in t_hints; y : out t_hbuf) is
    variable idx : integer := 0;
  begin
    y := (others => 0);
    for i in 0 to C_KK - 1 loop
      for j in 0 to 255 loop
        if h(256 * i + j) /= 0 then
          y(idx) := j;
          idx    := idx + 1;
        end if;
      end loop;
      y(C_OMEGA + i) := idx;
    end loop;
  end procedure hint_pack;

  procedure hint_unpack (y  : in  t_hbuf;
                         h  : out t_hints;
                         ok : out boolean) is
    variable idx   : integer := 0;
    variable first : integer := 0;
    variable yi    : integer;
    variable good  : boolean := true;
  begin
    h := (others => 0);
    for i in 0 to C_KK - 1 loop
      yi := y(C_OMEGA + i);
      -- the running index must not go backwards and must stay within omega
      if yi < idx or yi > C_OMEGA then
        good := false;
      end if;
      if good then
        first := idx;
        while idx < yi loop
          -- indices within one polynomial must be strictly increasing;
          -- dropping this check is a pre-registered mutation, since it would
          -- let a forged signature re-use positions
          if idx > first then
            if y(idx) <= y(idx - 1) then
              good := false;
            end if;
          end if;
          if good then
            h(256 * i + y(idx)) := 1;
          end if;
          idx := idx + 1;
        end loop;
      end if;
    end loop;
    -- every unused slot below omega must be zero padding
    if good then
      for j in 0 to C_OMEGA - 1 loop
        if j >= idx then
          if y(j) /= 0 then
            good := false;
          end if;
        end if;
      end loop;
    end if;
    ok := good;
  end procedure hint_unpack;

end package body pqc_codec_pkg;
