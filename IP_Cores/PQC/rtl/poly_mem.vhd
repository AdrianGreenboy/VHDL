-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- poly_mem: shared coefficient memory for ML-KEM-768, with a port arbiter.
-- VHDL-2008. ASCII-only. MIT license.
--
-- 27 polynomial slots of 256 coefficients, 16 bit signed, addressed as
-- {slot, index}. Slot allocation is fixed by the FSM:
--
--   0        A_ij     one matrix entry at a time, regenerated per use
--   1  ..  3 s_hat    secret vector, plain NTT domain
--   4  ..  6 e_hat    error vector, plain NTT domain
--   7  ..  9 t_hat    public vector, plain NTT domain
--   10 .. 12 y_hat    encapsulation randomness, plain NTT domain
--   13 .. 15 u        ciphertext part 1, coefficient domain
--   16       v        ciphertext part 2, coefficient domain
--   17 .. 18 tmp      accumulator and scratch
--   19 .. 26 Encaps/Decaps-only slots, see poly_mem_pkg
--
-- PHYSICAL ORGANISATION (audit 2026-11, SRAM mappability).
-- The client interface needs up to two reads and one write per cycle
-- (basemul reads A and B operands; the NTT reads while it writes). A single
-- array with three read ports cannot be mapped onto any SRAM macro. The
-- storage is therefore built from two identical COPIES, each a plain 1R1W
-- memory (one synchronous read port, one synchronous write port):
--
--   copy A : read port serves ra (NTT, FSM, basemul operand A) and, when the
--            basemul flags a destination read with bm_dre, the basemul
--            read-modify-write address. basemul never consumes operand A in
--            the cycle its destination read is issued, so there is no clash.
--   copy B : read port serves rb (basemul operand B, otherwise = ra).
--   Both copies receive every write, so they are always identical.
--
-- Each copy is one word-organised array of C_ROWS words of G_ZB lanes x 16
-- bits with a per-lane write mask, i.e. one 1R1W SRAM macro (or one FPGA
-- simple-dual-port BRAM with byte enables). Coefficient {slot, idx} lives in
-- row (slot*256 + idx) / G_ZB, lane idx mod G_ZB. A normal write updates one
-- lane; the zeroizer writes all lanes of a row per cycle, so a full wipe takes
-- C_ROWS = 27*256/G_ZB cycles (432 with the default G_ZB = 16) instead of
-- 6912.
--
-- Read-during-write on the same address returns the OLD word (read-first),
-- exactly as the previous model did. Storage carries no initial value: an
-- ASIC SRAM powers up random, and every slot the sequencers read is written
-- first (checked by the 'U'-propagation runs documented in AUDIT_FIXES.md).
--
-- Arbitration is strictly by grant, not by priority: the FSM enables exactly
-- one client at a time because the compute blocks are serialized by design
-- (frozen scope decision 3).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package poly_mem_pkg is
  -- Slots 0 to 18 are the KeyGen map and keep their indices, so the KeyGen
  -- signatures stay valid. Encaps adds dedicated slots above them rather than
  -- reusing KeyGen storage: t_hat and y_hat must coexist with u and v, and
  -- the lifted y_hat must coexist with the unlifted t_hat it multiplies.
  constant C_SLOTS  : integer := 27;
  constant C_SLOT_A : integer := 0;
  constant C_SLOT_S : integer := 1;
  constant C_SLOT_E : integer := 4;
  constant C_SLOT_T : integer := 7;
  constant C_SLOT_Y : integer := 10;
  constant C_SLOT_U : integer := 13;
  constant C_SLOT_V : integer := 16;
  constant C_SLOT_TMP : integer := 17;

  -- Encaps-only slots.
  --   E1  the first error vector, K polynomials
  --   E2  the scalar error polynomial, one
  --   YH  y_hat after the forward NTT and the R^2 lift, K polynomials
  --   MU  Decompress_1(m), one
  constant C_SLOT_E1 : integer := 19;
  constant C_SLOT_E2 : integer := 22;
  constant C_SLOT_YH : integer := 23;
  constant C_SLOT_MU : integer := 26;

  -- client identifiers for the arbiter
  constant C_CLI_NONE : integer := 0;
  constant C_CLI_NTT  : integer := 1;
  constant C_CLI_BMUL : integer := 2;
  constant C_CLI_SAMP : integer := 3;
  constant C_CLI_FSM  : integer := 4;

  -- storage type of the physical copies (unconstrained so that testbenches
  -- can inspect the arrays through VHDL-2008 external names)
  type t_pm_arr is array (natural range <>) of std_logic_vector;
end package poly_mem_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;

entity poly_mem is
  generic (
    -- lanes per physical word (power of two, divides 256); sets the
    -- zeroization rate in coefficients per cycle
    G_ZB : integer := 16);
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;

    -- which client owns the memory this cycle
    grant    : in  integer range 0 to 4;

    -- slot selection, driven by the FSM for each client
    slot_rd  : in  integer range 0 to C_SLOTS - 1;
    slot_rd2 : in  integer range 0 to C_SLOTS - 1;
    slot_wr  : in  integer range 0 to C_SLOTS - 1;

    -- NTT client (single read port, single write port)
    ntt_raddr : in  std_logic_vector(7 downto 0);
    ntt_rdata : out std_logic_vector(15 downto 0);
    ntt_waddr : in  std_logic_vector(7 downto 0);
    ntt_wdata : in  std_logic_vector(15 downto 0);
    ntt_we    : in  std_logic;

    -- basemul client (two read ports plus a read-modify-write port)
    bm_aaddr  : in  std_logic_vector(7 downto 0);
    bm_adata  : out std_logic_vector(15 downto 0);
    bm_baddr  : in  std_logic_vector(7 downto 0);
    bm_bdata  : out std_logic_vector(15 downto 0);
    bm_daddr  : in  std_logic_vector(7 downto 0);
    -- '1' in the cycle the destination read is issued (basemul d_re)
    bm_dre    : in  std_logic := '0';
    bm_drdata : out std_logic_vector(15 downto 0);
    bm_dwdata : in  std_logic_vector(15 downto 0);
    bm_dwe    : in  std_logic;

    -- sampler client (write only)
    sm_waddr  : in  std_logic_vector(7 downto 0);
    sm_wdata  : in  std_logic_vector(15 downto 0);
    sm_we     : in  std_logic;

    -- FSM client (direct access for load, store and pointwise passes)
    fsm_raddr : in  std_logic_vector(7 downto 0);
    fsm_rdata : out std_logic_vector(15 downto 0);
    fsm_waddr : in  std_logic_vector(7 downto 0);
    fsm_wdata : in  std_logic_vector(15 downto 0);
    fsm_we    : in  std_logic;

    -- zeroization: a one-cycle pulse wipes every word of both copies;
    -- z_busy is high until the last row is written. Client writes are
    -- ignored while z_busy is high.
    z_start   : in  std_logic := '0';
    z_busy    : out std_logic);
end entity poly_mem;

architecture rtl of poly_mem is

  constant C_DEPTH : integer := C_SLOTS * 256;
  constant C_ROWS  : integer := C_DEPTH / G_ZB;
  constant C_WW    : integer := 16 * G_ZB;

  subtype t_word is std_logic_vector(C_WW - 1 downto 0);

  -- the two physical 1R1W copies; no initial value (ASIC SRAM semantics)
  signal mem_a : t_pm_arr(0 to C_ROWS - 1)(C_WW - 1 downto 0);
  signal mem_b : t_pm_arr(0 to C_ROWS - 1)(C_WW - 1 downto 0);

  signal ra   : integer range 0 to C_DEPTH - 1 := 0;
  signal rb   : integer range 0 to C_DEPTH - 1 := 0;
  signal wa   : integer range 0 to C_DEPTH - 1 := 0;
  signal wd   : std_logic_vector(15 downto 0) := (others => '0');
  signal we_i : std_logic := '0';
  signal ra_eff : integer range 0 to C_DEPTH - 1 := 0;

  -- physical write port, shared by the clients and the zeroizer
  signal p_wrow  : integer range 0 to C_ROWS - 1 := 0;
  signal p_wmask : std_logic_vector(G_ZB - 1 downto 0) := (others => '0');
  signal p_wword : t_word := (others => '0');

  signal q_a, q_b   : t_word;
  signal lane_a, lane_b : integer range 0 to G_ZB - 1 := 0;

  signal z_run  : std_logic := '0';
  signal z_ptr  : integer range 0 to C_ROWS - 1 := 0;

begin

  assert 256 mod G_ZB = 0
    report "poly_mem: G_ZB must divide 256" severity failure;

  -- Address and data routing. Combinational: the registered behaviour lives
  -- in the memory process below, so every client sees the same one-cycle
  -- read latency it was verified against at unit level.
  process (grant, slot_rd, slot_rd2, slot_wr,
           ntt_raddr, ntt_waddr, ntt_wdata, ntt_we,
           bm_aaddr, bm_baddr, bm_daddr, bm_dwdata, bm_dwe,
           sm_waddr, sm_wdata, sm_we,
           fsm_raddr, fsm_waddr, fsm_wdata, fsm_we)
  begin
    ra   <= 0;
    rb   <= 0;
    wa   <= 0;
    wd   <= (others => '0');
    we_i <= '0';

    case grant is
      when C_CLI_NTT =>
        ra   <= slot_rd * 256 + to_integer(unsigned(ntt_raddr));
        rb   <= slot_rd * 256 + to_integer(unsigned(ntt_raddr));
        wa   <= slot_wr * 256 + to_integer(unsigned(ntt_waddr));
        wd   <= ntt_wdata;
        we_i <= ntt_we;

      when C_CLI_BMUL =>
        ra   <= slot_rd * 256 + to_integer(unsigned(bm_aaddr));
        rb   <= slot_rd2 * 256 + to_integer(unsigned(bm_baddr));
        wa   <= slot_wr * 256 + to_integer(unsigned(bm_daddr));
        wd   <= bm_dwdata;
        we_i <= bm_dwe;

      when C_CLI_SAMP =>
        wa   <= slot_wr * 256 + to_integer(unsigned(sm_waddr));
        wd   <= sm_wdata;
        we_i <= sm_we;

      when C_CLI_FSM =>
        ra   <= slot_rd * 256 + to_integer(unsigned(fsm_raddr));
        rb   <= slot_rd * 256 + to_integer(unsigned(fsm_raddr));
        wa   <= slot_wr * 256 + to_integer(unsigned(fsm_waddr));
        wd   <= fsm_wdata;
        we_i <= fsm_we;

      when others =>
        null;
    end case;
  end process;

  -- The basemul destination read replaces the copy-A read address for one
  -- cycle. It aliases the write address, which is exactly what the
  -- accumulate read-modify-write needs.
  ra_eff <= wa when (grant = C_CLI_BMUL and bm_dre = '1') else ra;

  -- Physical write port: zeroizer has priority, then the selected client.
  process (z_run, z_ptr, we_i, wa, wd)
  begin
    p_wmask <= (others => '0');
    p_wword <= (others => '0');
    if z_run = '1' then
      p_wrow  <= z_ptr;
      p_wmask <= (others => '1');
    else
      p_wrow <= wa / G_ZB;
      for l in 0 to G_ZB - 1 loop
        p_wword(16 * l + 15 downto 16 * l) <= wd;
      end loop;
      if we_i = '1' then
        p_wmask(wa mod G_ZB) <= '1';
      end if;
    end if;
  end process;

  -- Copy A: 1R1W, read-first.
  copy_a : process (clk)
  begin
    if rising_edge(clk) then
      for l in 0 to G_ZB - 1 loop
        if p_wmask(l) = '1' then
          mem_a(p_wrow)(16 * l + 15 downto 16 * l) <=
            p_wword(16 * l + 15 downto 16 * l);
        end if;
      end loop;
      q_a    <= mem_a(ra_eff / G_ZB);
      lane_a <= ra_eff mod G_ZB;
    end if;
  end process;

  -- Copy B: 1R1W, read-first, written with exactly the same port values.
  copy_b : process (clk)
  begin
    if rising_edge(clk) then
      for l in 0 to G_ZB - 1 loop
        if p_wmask(l) = '1' then
          mem_b(p_wrow)(16 * l + 15 downto 16 * l) <=
            p_wword(16 * l + 15 downto 16 * l);
        end if;
      end loop;
      q_b    <= mem_b(rb / G_ZB);
      lane_b <= rb mod G_ZB;
    end if;
  end process;

  -- Zeroizer: one full row per cycle on both copies.
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

  z_busy <= z_run;

  ntt_rdata <= q_a(16 * lane_a + 15 downto 16 * lane_a);
  bm_adata  <= q_a(16 * lane_a + 15 downto 16 * lane_a);
  bm_drdata <= q_a(16 * lane_a + 15 downto 16 * lane_a);
  fsm_rdata <= q_a(16 * lane_a + 15 downto 16 * lane_a);
  bm_bdata  <= q_b(16 * lane_b + 15 downto 16 * lane_b);

end architecture rtl;
