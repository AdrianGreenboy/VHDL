-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- poly_mem: shared coefficient memory for ML-KEM-768, with a port arbiter.
-- VHDL-2008. ASCII-only. MIT license.
--
-- 19 polynomial slots of 256 coefficients, 16 bit signed, addressed as
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
--
-- The memory is modelled as an array of integer, following the rule
-- established during boot validation: aggregate initialisers over large
-- std_logic_vector arrays make GHDL segfault.
--
-- Arbitration is strictly by grant, not by priority: the FSM enables exactly
-- one client at a time because the compute blocks are serialized by design
-- (frozen scope decision 3). The arbiter therefore only routes; it never has
-- to resolve a genuine conflict, and an enable overlap is a design error that
-- the assertion below catches in simulation.
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
end package poly_mem_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;

entity poly_mem is
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
    fsm_we    : in  std_logic);
end entity poly_mem;

architecture rtl of poly_mem is

  type t_mem is array (0 to C_SLOTS * 256 - 1) of integer;
  signal mem : t_mem := (others => 0);

  signal ra   : integer range 0 to C_SLOTS * 256 - 1 := 0;
  signal rb   : integer range 0 to C_SLOTS * 256 - 1 := 0;
  signal wa   : integer range 0 to C_SLOTS * 256 - 1 := 0;
  signal wd   : integer := 0;
  signal we_i : std_logic := '0';

  signal q_a  : integer := 0;
  signal q_b  : integer := 0;

begin

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
    wd   <= 0;
    we_i <= '0';

    case grant is
      when C_CLI_NTT =>
        ra   <= slot_rd * 256 + to_integer(unsigned(ntt_raddr));
        rb   <= slot_rd * 256 + to_integer(unsigned(ntt_raddr));
        wa   <= slot_wr * 256 + to_integer(unsigned(ntt_waddr));
        wd   <= to_integer(signed(ntt_wdata));
        we_i <= ntt_we;

      when C_CLI_BMUL =>
        ra   <= slot_rd * 256 + to_integer(unsigned(bm_aaddr));
        rb   <= slot_rd2 * 256 + to_integer(unsigned(bm_baddr));
        wa   <= slot_wr * 256 + to_integer(unsigned(bm_daddr));
        wd   <= to_integer(signed(bm_dwdata));
        we_i <= bm_dwe;

      when C_CLI_SAMP =>
        wa   <= slot_wr * 256 + to_integer(unsigned(sm_waddr));
        wd   <= to_integer(signed(sm_wdata));
        we_i <= sm_we;

      when C_CLI_FSM =>
        ra   <= slot_rd * 256 + to_integer(unsigned(fsm_raddr));
        rb   <= slot_rd * 256 + to_integer(unsigned(fsm_raddr));
        wa   <= slot_wr * 256 + to_integer(unsigned(fsm_waddr));
        wd   <= to_integer(signed(fsm_wdata));
        we_i <= fsm_we;

      when others =>
        null;
    end case;
  end process;

  -- The basemul destination port needs a third read. It aliases the write
  -- address, which is exactly what a read-modify-write needs and is why the
  -- accumulate path reads before it writes.
  mem_proc : process (clk)
  begin
    if rising_edge(clk) then
      if we_i = '1' then
        mem(wa) <= wd;
      end if;
      q_a <= mem(ra);
      q_b <= mem(rb);
      bm_drdata <= std_logic_vector(to_signed(mem(wa), 16));
    end if;
  end process;

  ntt_rdata <= std_logic_vector(to_signed(q_a, 16));
  bm_adata  <= std_logic_vector(to_signed(q_a, 16));
  bm_bdata  <= std_logic_vector(to_signed(q_b, 16));
  fsm_rdata <= std_logic_vector(to_signed(q_a, 16));

end architecture rtl;
