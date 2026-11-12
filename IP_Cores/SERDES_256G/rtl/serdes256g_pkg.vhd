-------------------------------------------------------------------------------
-- SERDES_256G - multi-lane 64B/66B link layer, 8 x 32 Gb/s (256 Gb/s raw)
-- Package: constants, block formats and helper functions.
--
-- Block convention (same as Core 19 / Core 20 after the 2026-11 audit):
--   block(65 downto 0) = payload(63 downto 0) & sync(1 downto 0)
--   block(0) is the FIRST bit on the wire.
--   data    : sync = "10"  (block(0)='0', block(1)='1')
--   control : sync = "01"
--
-- Every lane carries TWO 66-bit blocks per clock (a 132-bit "lane word"), so
-- the fabric runs at line_rate/132 (242.4 MHz at 32 Gb/s) instead of the
-- 484.8 MHz a one-block-per-clock datapath would need.
--   lane word(65 downto 0)    = block 0 (first on the wire)
--   lane word(131 downto 66)  = block 1
--
-- Control block types (payload byte 0):
--   0x1E IDLE   payload bytes 1..7 = 0
--   0xE1 EOF    payload byte 1 = (not nb) & nb, nb = valid bytes (1..8) of
--               the data block that precedes the EOF block
--   alignment markers AM_A / AM_B are control blocks too and are sent
--   UNSCRAMBLED, on all lanes in the same lane word, every G_AM_PERIOD words.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package serdes256g_pkg is

  constant C_BLK_W  : natural := 66;
  constant C_WORD_W : natural := 132;   -- two blocks per lane per clock
  constant C_GT_W   : natural := 128;   -- GT user data width (raw mode)

  constant C_SYNC_DATA : std_logic_vector(1 downto 0) := "10";
  constant C_SYNC_CTRL : std_logic_vector(1 downto 0) := "01";

  constant C_BT_IDLE : std_logic_vector(7 downto 0) := x"1E";
  constant C_BT_EOF  : std_logic_vector(7 downto 0) := x"E1";

  -- alignment marker A: M0 M1 (2|lane) BIP8 ~M0 ~M1 ~(2|lane) ~BIP8
  constant C_AMA_M0 : std_logic_vector(7 downto 0) := x"C1";
  constant C_AMA_M1 : std_logic_vector(7 downto 0) := x"68";
  -- alignment marker B: N0 N1 N2 STATUS ~N0 ~N1 ~N2 ~STATUS
  constant C_AMB_N0 : std_logic_vector(7 downto 0) := x"9D";
  constant C_AMB_N1 : std_logic_vector(7 downto 0) := x"71";
  constant C_AMB_N2 : std_logic_vector(7 downto 0) := x"8E";

  type t_boolv is array (natural range <>) of boolean;

  function f_idle_block return std_logic_vector;
  function f_eof_block (nb : unsigned(3 downto 0)) return std_logic_vector;
  function f_am_a (lane : natural; bip : std_logic_vector(7 downto 0))
    return std_logic_vector;
  function f_am_b (status : std_logic_vector(7 downto 0))
    return std_logic_vector;
  function f_is_am_a (b : std_logic_vector(65 downto 0)) return boolean;
  function f_is_am_b (b : std_logic_vector(65 downto 0)) return boolean;
  -- BIP-8 over one 132-bit lane word: bip(i) = xor of word bits n, n mod 8 = i
  function f_bip8 (w : std_logic_vector(131 downto 0)) return std_logic_vector;
  -- number of valid bytes of a (contiguous, LSB first) 8-bit keep, min 1
  function f_nbytes (k : std_logic_vector(7 downto 0)) return unsigned;
  -- thermometer keep for nb valid bytes (nb = 1..8)
  function f_thermo8 (nb : unsigned(3 downto 0)) return std_logic_vector;

end package serdes256g_pkg;

package body serdes256g_pkg is

  function f_idle_block return std_logic_vector is
    variable p : std_logic_vector(63 downto 0) := (others => '0');
  begin
    p(7 downto 0) := C_BT_IDLE;
    return p & C_SYNC_CTRL;
  end function;

  function f_eof_block (nb : unsigned(3 downto 0)) return std_logic_vector is
    variable p : std_logic_vector(63 downto 0) := (others => '0');
  begin
    p(7 downto 0)   := C_BT_EOF;
    p(11 downto 8)  := std_logic_vector(nb);
    p(15 downto 12) := not std_logic_vector(nb);
    return p & C_SYNC_CTRL;
  end function;

  function f_am_a (lane : natural; bip : std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable p  : std_logic_vector(63 downto 0);
    variable m2 : std_logic_vector(7 downto 0);
  begin
    m2 := x"2" & std_logic_vector(to_unsigned(lane, 4));
    p(7 downto 0)   := C_AMA_M0;
    p(15 downto 8)  := C_AMA_M1;
    p(23 downto 16) := m2;
    p(31 downto 24) := bip;
    p(39 downto 32) := not C_AMA_M0;
    p(47 downto 40) := not C_AMA_M1;
    p(55 downto 48) := not m2;
    p(63 downto 56) := not bip;
    return p & C_SYNC_CTRL;
  end function;

  function f_am_b (status : std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable p : std_logic_vector(63 downto 0);
  begin
    p(7 downto 0)   := C_AMB_N0;
    p(15 downto 8)  := C_AMB_N1;
    p(23 downto 16) := C_AMB_N2;
    p(31 downto 24) := status;
    p(39 downto 32) := not C_AMB_N0;
    p(47 downto 40) := not C_AMB_N1;
    p(55 downto 48) := not C_AMB_N2;
    p(63 downto 56) := not status;
    return p & C_SYNC_CTRL;
  end function;

  -- The BIP field (payload bytes 3 and 7) is NOT part of the match, so a
  -- corrupted BIP is reported as a BIP error and not as a missing marker.
  function f_is_am_a (b : std_logic_vector(65 downto 0)) return boolean is
    variable p : std_logic_vector(63 downto 0);
  begin
    p := b(65 downto 2);
    return b(1 downto 0) = C_SYNC_CTRL
       and p(7 downto 0)   = C_AMA_M0
       and p(15 downto 8)  = C_AMA_M1
       and p(23 downto 20) = x"2"
       and p(39 downto 32) = (not C_AMA_M0)
       and p(47 downto 40) = (not C_AMA_M1)
       and p(55 downto 48) = (not p(23 downto 16));
  end function;

  function f_is_am_b (b : std_logic_vector(65 downto 0)) return boolean is
    variable p : std_logic_vector(63 downto 0);
  begin
    p := b(65 downto 2);
    return b(1 downto 0) = C_SYNC_CTRL
       and p(7 downto 0)   = C_AMB_N0
       and p(15 downto 8)  = C_AMB_N1
       and p(23 downto 16) = C_AMB_N2
       and p(39 downto 32) = (not C_AMB_N0)
       and p(47 downto 40) = (not C_AMB_N1)
       and p(55 downto 48) = (not C_AMB_N2);
  end function;

  function f_bip8 (w : std_logic_vector(131 downto 0)) return std_logic_vector is
    variable r : std_logic_vector(7 downto 0) := (others => '0');
  begin
    for i in 0 to 131 loop
      r(i mod 8) := r(i mod 8) xor w(i);
    end loop;
    return r;
  end function;

  function f_nbytes (k : std_logic_vector(7 downto 0)) return unsigned is
    variable n : unsigned(3 downto 0) := (others => '0');
  begin
    for i in 0 to 7 loop
      if k(i) = '1' then
        n := n + 1;
      end if;
    end loop;
    if n = 0 then
      n := to_unsigned(1, 4);
    end if;
    return n;
  end function;

  function f_thermo8 (nb : unsigned(3 downto 0)) return std_logic_vector is
    variable k : std_logic_vector(7 downto 0);
  begin
    for j in 0 to 7 loop
      if j < to_integer(nb) then
        k(j) := '1';
      else
        k(j) := '0';
      end if;
    end loop;
    return k;
  end function;

end package body serdes256g_pkg;
