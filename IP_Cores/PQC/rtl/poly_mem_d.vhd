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

  -- storage type of the physical copies (unconstrained so that testbenches
  -- can inspect the arrays through VHDL-2008 external names)
  type t_pmd_arr is array (natural range <>) of std_logic_vector;
end package poly_mem_d_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.poly_mem_d_pkg.all;

entity poly_mem_d is
  generic (
    -- lanes per physical word (power of two, divides 256); sets the
    -- zeroization rate in coefficients per cycle
    G_ZB : integer := 8);
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic := '1';

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
    b_rdata  : out std_logic_vector(C_CW - 1 downto 0);

    -- zeroization: a one-cycle pulse wipes every word of both copies;
    -- z_busy is high until the last row is written. Client writes are
    -- ignored while z_busy is high.
    z_start  : in  std_logic := '0';
    z_busy   : out std_logic);
end entity poly_mem_d;

architecture rtl of poly_mem_d is
  -- PHYSICAL ORGANISATION (audit 2026-11, SRAM mappability).
  -- Two reads (port A, port B) and one write per cycle cannot be served by a
  -- single SRAM macro. The storage is two identical COPIES, each a plain
  -- 1R1W memory: copy A serves the port-A read, copy B the port-B read, and
  -- both receive every write. Each copy is one array of C_ROWS words of G_ZB
  -- lanes x C_CW bits with a per-lane write mask (one 1R1W macro with bit
  -- mask, or one FPGA SDP BRAM with byte enables); coefficient {slot, idx}
  -- lives in row (slot*256+idx)/G_ZB, lane idx mod G_ZB. The zeroizer writes
  -- whole rows. Read-during-write returns the old word (read-first), as the
  -- previous model did. No initial value: ASIC SRAM powers up random.
  constant C_DEPTH : integer := C_SLOTS_D * 256;
  constant C_ROWS  : integer := C_DEPTH / G_ZB;
  constant C_WW    : integer := C_CW * G_ZB;
  subtype t_word is std_logic_vector(C_WW - 1 downto 0);
  signal mem_a, mem_b : t_pmd_arr(0 to C_ROWS - 1)(C_WW - 1 downto 0);

  signal p_wrow  : integer range 0 to C_ROWS - 1 := 0;
  signal p_wmask : std_logic_vector(G_ZB - 1 downto 0) := (others => '0');
  signal p_wword : t_word := (others => '0');
  signal ra, rb  : integer range 0 to C_DEPTH - 1 := 0;
  signal q_a, q_b : t_word;
  signal lane_a, lane_b : integer range 0 to G_ZB - 1 := 0;
  signal z_run   : std_logic := '0';
  signal z_ptr   : integer range 0 to C_ROWS - 1 := 0;
begin

  assert 256 mod G_ZB = 0
    report "poly_mem_d: G_ZB must divide 256" severity failure;

  ra <= a_slot * 256 + to_integer(unsigned(a_raddr));
  rb <= b_slot * 256 + to_integer(unsigned(b_raddr));

  process (z_run, z_ptr, a_we, a_slot, a_waddr, a_wdata)
    variable wa : integer range 0 to C_DEPTH - 1;
  begin
    p_wmask <= (others => '0');
    p_wword <= (others => '0');
    wa := a_slot * 256 + to_integer(unsigned(a_waddr));
    if z_run = '1' then
      p_wrow  <= z_ptr;
      p_wmask <= (others => '1');
    else
      p_wrow <= wa / G_ZB;
      for l in 0 to G_ZB - 1 loop
        p_wword(C_CW * l + C_CW - 1 downto C_CW * l) <= a_wdata;
      end loop;
      if a_we = '1' then
        p_wmask(wa mod G_ZB) <= '1';
      end if;
    end if;
  end process;

  copy_a : process (clk)
  begin
    if rising_edge(clk) then
      for l in 0 to G_ZB - 1 loop
        if p_wmask(l) = '1' then
          mem_a(p_wrow)(C_CW * l + C_CW - 1 downto C_CW * l) <=
            p_wword(C_CW * l + C_CW - 1 downto C_CW * l);
        end if;
      end loop;
      q_a    <= mem_a(ra / G_ZB);
      lane_a <= ra mod G_ZB;
    end if;
  end process;

  copy_b : process (clk)
  begin
    if rising_edge(clk) then
      for l in 0 to G_ZB - 1 loop
        if p_wmask(l) = '1' then
          mem_b(p_wrow)(C_CW * l + C_CW - 1 downto C_CW * l) <=
            p_wword(C_CW * l + C_CW - 1 downto C_CW * l);
        end if;
      end loop;
      q_b    <= mem_b(rb / G_ZB);
      lane_b <= rb mod G_ZB;
    end if;
  end process;

  zero_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        z_run <= '0';
        z_ptr <= 0;
      elsif z_run = '1' then
        if z_ptr = C_ROWS - 1 then
          z_run <= '0';
          z_ptr <= 0;
        else
          z_ptr <= z_ptr + 1;
        end if;
      elsif z_start = '1' then
        z_run <= '1';
        z_ptr <= 0;
      end if;
    end if;
  end process;

  z_busy  <= z_run;
  a_rdata <= q_a(C_CW * lane_a + C_CW - 1 downto C_CW * lane_a);
  b_rdata <= q_b(C_CW * lane_b + C_CW - 1 downto C_CW * lane_b);

end architecture rtl;
