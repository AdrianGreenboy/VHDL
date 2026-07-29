-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- poly_mem_d: polynomial storage for the ML-DSA datapath.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Same arbitration shape as poly_mem, with two differences that follow from
-- the algorithm rather than from taste:
--
--  1. Words are 32 bits, not 16. Dilithium coefficients need 23 bits and the
--     transform lets them grow past 26 before reduction.
--
--  2. There are two read ports rather than one. The coefficient-wise product
--     reads both operands in the same cycle; the Kyber basemul could get away
--     with a single port because it processed a pair at a time from one slot.
--
-- Slot map for ML-DSA-65, K = 6 and L = 5:
--   0..5    W        accumulator per row of A, and w
--   6..10   Y        the masking vector y
--   11..15  YH       y lifted, or s1 lifted, depending on phase
--   16..21  S2       s2 and its NTT
--   22..27  T0       t0
--   28      A        the current matrix entry from ExpandA
--   29..30  TMP      scratch
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;

package poly_mem_d_pkg is
  -- 47 slots: the Sign sequencer needs A, y, y_hat lifted, s1_hat, s2_hat,
  -- t0_hat, w, c_hat, scratch, z and the hints all live at once. See the
  -- slot map in dsa_sign.vhd.
  constant C_SLOTS_D  : integer := 47;

  constant C_SLOT_W   : integer := 0;
  constant C_SLOT_Y   : integer := 6;
  constant C_SLOT_YH  : integer := 11;
  constant C_SLOT_S2  : integer := 16;
  constant C_SLOT_T0  : integer := 22;
  constant C_SLOT_AD  : integer := 28;
  constant C_SLOT_TMPD : integer := 29;

  -- arbitration clients
  constant C_CLID_NONE : integer := 0;
  constant C_CLID_NTT  : integer := 1;
  constant C_CLID_FSM  : integer := 2;
  constant C_CLID_SAMP : integer := 3;
end package poly_mem_d_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.poly_mem_d_pkg.all;

entity poly_mem_d is
  port (
    clk      : in  std_logic;

    -- port A: read and write, used by whichever client holds the grant
    a_slot   : in  integer range 0 to C_SLOTS_D - 1;
    a_raddr  : in  std_logic_vector(7 downto 0);
    a_rdata  : out std_logic_vector(C_CW - 1 downto 0);
    a_waddr  : in  std_logic_vector(7 downto 0);
    a_wdata  : in  std_logic_vector(C_CW - 1 downto 0);
    a_we     : in  std_logic;

    -- port B: read only, the second operand of the pointwise product
    b_slot   : in  integer range 0 to C_SLOTS_D - 1;
    b_raddr  : in  std_logic_vector(7 downto 0);
    b_rdata  : out std_logic_vector(C_CW - 1 downto 0));
end entity poly_mem_d;

architecture rtl of poly_mem_d is
  -- Modelled as an array of integer. Large std_logic_vector arrays and
  -- aggregate initialisers over them both segfault GHDL at this size, a
  -- lesson carried over from the RV32 core's RAM model.
  type t_mem is array (0 to C_SLOTS_D * 256 - 1) of integer;
  signal mem : t_mem := (others => 0);
begin

  process (clk)
    variable ra, rb, wa : integer;
  begin
    if rising_edge(clk) then
      ra := a_slot * 256 + to_integer(unsigned(a_raddr));
      rb := b_slot * 256 + to_integer(unsigned(b_raddr));
      a_rdata <= std_logic_vector(to_signed(mem(ra), C_CW));
      b_rdata <= std_logic_vector(to_signed(mem(rb), C_CW));
      if a_we = '1' then
        wa := a_slot * 256 + to_integer(unsigned(a_waddr));
        mem(wa) <= to_integer(signed(a_wdata));
      end if;
    end if;
  end process;

end architecture rtl;
