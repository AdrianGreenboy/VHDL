-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- dsa_verify: ML-DSA-65 Verify, FIPS 204 Algorithm 8.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Verify is deterministic and single-pass: there is no rejection loop, so
-- unlike Sign the runtime is fixed for any input that gets past the early
-- checks. What it does have is FIVE distinct outcomes, and the design point
-- of this block is that the caller can tell them apart.
--
-- REASON CODES. A bare pass/fail bit cannot separate "rejected" from
-- "rejected for the right reason": under that output every rejection branch
-- is interchangeable, and a mutation that swaps one for another survives.
-- The reason code is exposed alongside the result and goes into the
-- end-of-run signature, exactly as kappa does in Sign.
--
--   0  accepted
--   1  wrong signature length
--   2  hint decode rejected the encoding
--   3  ||z||inf at or above GAMMA1 - BETA
--   4  recomputed c_tilde does not match
--
-- Branch coverage of the 20 ACVP vectors is 4 accept, 11 c_tilde mismatch,
-- 5 hint decode, and ZERO for the length and z-bound branches. Those two are
-- live but unvisited, the same shape as the sampler z == q case and the
-- Decaps early exit, so two cases were constructed before this RTL was
-- written rather than after a mutation survived: a signature one byte short,
-- and one whose z has a coefficient exactly on GAMMA1 - BETA, which is the
-- only value at which >= and > differ.
--
-- THE MESSAGE IS NOT STORED, consistent with Sign: mu is a 64-byte input.
-- tr = SHAKE256(pk, 64) is bounded, but mu = SHAKE256(tr || mprime) is not.
--
-- Byte map (14-bit space):
--   pk       @    0  1952 bytes, caller supplied
--   mu       @ 2048  64 bytes, caller supplied
--   sig      @ 2176  3309 bytes, caller supplied
--   c_tilde' @ 5632  48 bytes, recomputed
--   w1_enc   @ 5760  768 bytes
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;
use work.poly_mem_d_pkg.all;

entity dsa_verify is
  generic (
    G_K       : integer := 6;
    G_L       : integer := 5;
    G_ADDR_PK : integer := 0;
    G_ADDR_MU : integer := 2048;
    G_ADDR_SG : integer := 2176;
    G_ADDR_CT : integer := 5632;
    G_ADDR_W1 : integer := 5760;
    G_SIGLEN  : integer := 3309;
    -- 0 run to completion, 1..4 stop after a named checkpoint
    G_STOP_AT : integer := 0);
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    start      : in  std_logic;
    -- length of the signature presented, so the length branch is testable
    siglen     : in  std_logic_vector(15 downto 0);
    done       : out std_logic;
    busy       : out std_logic;
    result     : out std_logic;
    reason     : out std_logic_vector(2 downto 0);

    slot_a     : out integer range 0 to C_SLOTS_D - 1;
    slot_b     : out integer range 0 to C_SLOTS_D - 1;
    p_raddr    : out std_logic_vector(7 downto 0);
    p_rdata    : in  std_logic_vector(C_CW - 1 downto 0);
    p_braddr   : out std_logic_vector(7 downto 0);
    p_brdata   : in  std_logic_vector(C_CW - 1 downto 0);
    p_waddr    : out std_logic_vector(7 downto 0);
    p_wdata    : out std_logic_vector(C_CW - 1 downto 0);
    p_we       : out std_logic;

    ntt_start  : out std_logic;
    ntt_op     : out std_logic_vector(1 downto 0);
    ntt_done   : in  std_logic;

    smp_start  : out std_logic;
    smp_mode   : out std_logic_vector(1 downto 0);
    smp_done   : in  std_logic;

    cod_start  : out std_logic;
    cod_mode   : out std_logic_vector(3 downto 0);
    cod_base   : out std_logic_vector(13 downto 0);
    cod_done   : in  std_logic;
    cod_valid  : in  std_logic;

    sp_mode    : out std_logic_vector(1 downto 0);
    sp_init    : out std_logic;
    sp_din     : out std_logic_vector(7 downto 0);
    sp_we      : out std_logic;
    sp_adone   : out std_logic;
    sp_dout    : in  std_logic_vector(7 downto 0);
    sp_re      : out std_logic;
    sp_dvalid  : in  std_logic;
    sp_ready   : in  std_logic;

    by_addr    : out std_logic_vector(13 downto 0);
    by_din     : out std_logic_vector(7 downto 0);
    by_we      : out std_logic;
    by_dout    : in  std_logic_vector(7 downto 0));
end entity dsa_verify;

architecture rtl of dsa_verify is

  type t_fsm is (
    S_IDLE, S_LENCHK,
    -- decode: hints first because it can reject, then z, then t1
    S_HD_RUN, S_HD_WAIT,
    S_ZU_RUN, S_ZU_WAIT, S_ZU_NEXT,
    S_ZC_RD, S_ZC_RDW, S_ZC_TEST, S_ZC_NEXT, S_ZC_SNEXT,
    S_T1_RUN, S_T1_WAIT, S_T1_NEXT,
    -- t1 * 2^D then NTT, z NTT
    S_TS_RD, S_TS_RDW, S_TS_WR, S_TS_NEXT, S_TS_NTT, S_TS_NTTW, S_TS_RNEXT,
    S_ZN_NTT, S_ZN_NTTW, S_ZL_RD, S_ZL_RDW, S_ZL_WR, S_ZL_NEXT,
    S_ZN_NEXT,
    -- c_hat = NTT(SampleInBall(c_tilde from the signature))
    S_CB_MODE, S_CB_INIT, S_CB_INITP, S_CB_WAIT, S_CB_ABS, S_CB_ABSW,
    S_CB_FIN, S_CB_RUN, S_CB_NTT, S_CB_NTTW,
    -- w = INTT(sum A o z_hat  -  c_hat o t1_hat)
    S_W_ZERO, S_W_AMODE, S_W_AINIT, S_W_AINITP, S_W_AWAIT, S_W_AABS,
    S_W_AABSW, S_W_AIDX1, S_W_AIDX2, S_W_AFIN, S_W_ARUN,
    S_W_MUL, S_W_MULW, S_W_ACC_RD, S_W_ACC_RDW, S_W_ACC_WR, S_W_ACC_NEXT,
    S_W_SNEXT,
    S_CT_CP_RD, S_CT_CP_RDW, S_CT_CP_WR, S_CT_CP_NEXT,
    S_CT_MUL, S_CT_MULW, S_CT_SUB_RD, S_CT_SUB_RDW, S_CT_SUB_WR,
    S_CT_SUB_NEXT,
    S_W_INTT, S_W_INTTS, S_W_INTTW,
    -- w1 = UseHint(h, w)
    S_UH_RD, S_UH_RDW, S_UH_WR, S_UH_NEXT, S_W_RNEXT,
    -- encode and hash
    S_HE_RUN, S_HE_WAIT, S_HE_NEXT,
    S_C_MODE, S_C_INIT, S_C_INITP, S_C_MWAIT, S_C_MABS, S_C_MABSW,
    S_C_WWAIT, S_C_WABS, S_C_WABSW, S_C_FIN, S_C_SQ, S_C_SQW, S_C_SQ2,
    -- compare against the c_tilde carried in the signature
    S_CMP_A, S_CMP_AW, S_CMP_B, S_CMP_BW, S_CMP_T, S_CMP_NEXT,
    S_ACCEPT, S_REJECT, S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal busy_r   : std_logic := '0';
  signal done_r   : std_logic := '0';
  signal result_r : std_logic := '0';
  signal reason_r : std_logic_vector(2 downto 0) := "000";

  signal ii  : integer range 0 to 31 := 0;
  signal jj  : integer range 0 to 15 := 0;
  signal cnt : integer range 0 to 8191 := 0;
  signal ctb : unsigned(7 downto 0) := (others => '0');

  constant SL_A   : integer := 0;
  constant SL_Z   : integer := 1;    -- z[0..L-1], then z_hat in place
  constant SL_T1  : integer := 6;    -- t1[0..K-1], then t1_hat in place
  constant SL_H   : integer := 12;   -- hints[0..K-1], then w1 in place
  constant SL_W   : integer := 18;   -- w[0..K-1]
  constant SL_CH  : integer := 24;   -- c_hat
  constant SL_TMP : integer := 25;
  constant SL_TM2 : integer := 26;

  constant C_D_SHIFT : integer := 13;

  function mont_d (a : signed) return signed is
    variable alo  : signed(32 downto 0);
    variable lo   : signed(65 downto 0);
    variable t    : signed(31 downto 0);
    variable prod : signed(a'length + 33 downto 0);
    variable num  : signed(a'length + 33 downto 0);
  begin
    alo  := resize(signed(a(31 downto 0)), 33);
    lo   := alo * to_signed(C_QINVD, 33);
    t    := signed(lo(31 downto 0));
    prod := resize(t * to_signed(C_QD, 32), prod'length);
    num  := resize(a, num'length) - prod;
    return resize(shift_right(num, 32), C_CW);
  end function mont_d;

  function absv (x : signed) return signed is
  begin
    if x < 0 then
      return -x;
    end if;
    return x;
  end function absv;

begin

  busy   <= busy_r;
  done   <= done_r;
  result <= result_r;
  reason <= reason_r;

  process (clk)
    variable p : signed(63 downto 0);
    variable cv : signed(C_CW - 1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm      <= S_IDLE;
        busy_r   <= '0';
        done_r   <= '0';
        result_r <= '0';
        reason_r <= "000";
        slot_a   <= 0;
        slot_b   <= 0;
        p_raddr  <= (others => '0');
        p_braddr <= (others => '0');
        p_waddr  <= (others => '0');
        p_wdata  <= (others => '0');
        p_we     <= '0';
        ntt_start <= '0';
        ntt_op   <= "00";
        smp_start <= '0';
        smp_mode <= "00";
        cod_start <= '0';
        cod_mode <= "0000";
        cod_base <= (others => '0');
        sp_mode  <= "01";
        sp_init  <= '0';
        sp_din   <= (others => '0');
        sp_we    <= '0';
        sp_adone <= '0';
        sp_re    <= '0';
        by_addr  <= (others => '0');
        by_din   <= (others => '0');
        by_we    <= '0';
        ii       <= 0;
        jj       <= 0;
        cnt      <= 0;
      else
        done_r    <= '0';
        p_we      <= '0';
        ntt_start <= '0';
        smp_start <= '0';
        cod_start <= '0';
        sp_init   <= '0';
        sp_we     <= '0';
        sp_adone  <= '0';
        sp_re     <= '0';
        by_we     <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r   <= '1';
              result_r <= '0';
              reason_r <= "000";
              cnt      <= 0;
              ii       <= 0;
              jj       <= 0;
              fsm      <= S_LENCHK;
            end if;

          -- Reason 1. Checked first and before any decoding, because a short
          -- signature makes every later offset meaningless.
          when S_LENCHK =>
            if unsigned(siglen) /= to_unsigned(G_SIGLEN, 16) then
              reason_r <= "001";
              fsm      <= S_REJECT;
            else
              cnt <= 0;
              ii  <= 0;
              fsm <= S_HD_RUN;
            end if;

          ----------------------------------------------------------------
          -- Reason 2. Hint decode, which enforces the three encoding rules
          -- already verified in the codec block.
          ----------------------------------------------------------------
          when S_HD_RUN =>
            slot_a    <= SL_H;
            cod_mode  <= "0111";
            cod_base  <= std_logic_vector(
                           to_unsigned(G_ADDR_SG + 48 + 640 * G_L, 14));
            cod_start <= '1';
            fsm       <= S_HD_WAIT;

          when S_HD_WAIT =>
            if cod_done = '1' then
              if cod_valid = '0' then
                reason_r <= "010";
                fsm      <= S_REJECT;
              else
                jj  <= 0;
                fsm <= S_ZU_RUN;
              end if;
            end if;

          ----------------------------------------------------------------
          -- Unpack z, then check its bound. Reason 3.
          ----------------------------------------------------------------
          when S_ZU_RUN =>
            slot_a    <= SL_Z + jj;
            cod_mode  <= "0101";
            cod_base  <= std_logic_vector(
                           to_unsigned(G_ADDR_SG + 48 + 640 * jj, 14));
            cod_start <= '1';
            fsm       <= S_ZU_WAIT;

          when S_ZU_WAIT =>
            if cod_done = '1' then
              fsm <= S_ZU_NEXT;
            end if;

          when S_ZU_NEXT =>
            if jj = G_L - 1 then
              jj  <= 0;
              cnt <= 0;
              if G_STOP_AT = 1 then
                fsm <= S_DONE;
              else
                fsm <= S_ZC_RD;
              end if;
            else
              jj  <= jj + 1;
              fsm <= S_ZU_RUN;
            end if;

          when S_ZC_RD =>
            slot_a  <= SL_Z + jj;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_ZC_RDW;

          when S_ZC_RDW =>
            fsm <= S_ZC_TEST;

          -- The bound is inclusive on the reject side: a coefficient exactly
          -- equal to GAMMA1 - BETA must be rejected, which is the only value
          -- at which this differs from a strict comparison.
          when S_ZC_TEST =>
            cv := signed(p_rdata);
            if absv(cv) >= to_signed(C_GAMMA1_DD - 196, C_CW) then
              reason_r <= "011";
              fsm      <= S_REJECT;
            else
              fsm <= S_ZC_NEXT;
            end if;

          when S_ZC_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_ZC_SNEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_ZC_RD;
            end if;

          when S_ZC_SNEXT =>
            if jj = G_L - 1 then
              jj  <= 0;
              ii  <= 0;
              fsm <= S_T1_RUN;
            else
              jj  <= jj + 1;
              fsm <= S_ZC_RD;
            end if;

          ----------------------------------------------------------------
          -- Unpack t1 from pk at 10 bits, then scale by 2^D and transform.
          ----------------------------------------------------------------
          when S_T1_RUN =>
            slot_a    <= SL_T1 + ii;
            cod_mode  <= "1010";
            cod_base  <= std_logic_vector(
                           to_unsigned(G_ADDR_PK + 32 + 320 * ii, 14));
            cod_start <= '1';
            fsm       <= S_T1_WAIT;

          when S_T1_WAIT =>
            if cod_done = '1' then
              fsm <= S_T1_NEXT;
            end if;

          when S_T1_NEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              cnt <= 0;
              fsm <= S_TS_RD;
            else
              ii  <= ii + 1;
              fsm <= S_T1_RUN;
            end if;

          when S_TS_RD =>
            slot_a  <= SL_T1 + ii;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_TS_RDW;

          when S_TS_RDW =>
            fsm <= S_TS_WR;

          when S_TS_WR =>
            slot_a  <= SL_T1 + ii;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(
                         shift_left(signed(p_rdata), C_D_SHIFT));
            p_we    <= '1';
            fsm     <= S_TS_NEXT;

          when S_TS_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_TS_NTT;
            else
              cnt <= cnt + 1;
              fsm <= S_TS_RD;
            end if;

          when S_TS_NTT =>
            slot_a    <= SL_T1 + ii;
            ntt_op    <= "00";
            ntt_start <= '1';
            fsm       <= S_TS_NTTW;

          when S_TS_NTTW =>
            if ntt_done = '1' then
              fsm <= S_TS_RNEXT;
            end if;

          when S_TS_RNEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              jj  <= 0;
              fsm <= S_ZN_NTT;
            else
              ii  <= ii + 1;
              cnt <= 0;
              fsm <= S_TS_RD;
            end if;

          ----------------------------------------------------------------
          -- z_hat, with the R^2 lift: exactly one operand of each product
          -- carries it, and A comes out of SampleNTT already lifted-free.
          ----------------------------------------------------------------
          when S_ZN_NTT =>
            slot_a    <= SL_Z + jj;
            ntt_op    <= "00";
            ntt_start <= '1';
            fsm       <= S_ZN_NTTW;

          when S_ZN_NTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_ZL_RD;
            end if;

          -- EVERY pointwise product needs exactly one lifted operand, and
          -- there are two different products here: A o z_hat and c_hat o
          -- t1_hat. c_hat carries the lift for the second, so z_hat must
          -- carry it for the first. Omitting it leaves the A o z_hat term
          -- short by one factor of R while the c_hat term is correct, which
          -- is visible at the very first coefficient of w and nowhere
          -- earlier: VP1 passes and VP2 does not.
          when S_ZL_RD =>
            slot_a  <= SL_Z + jj;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_ZL_RDW;

          when S_ZL_RDW =>
            fsm <= S_ZL_WR;

          when S_ZL_WR =>
            p       := resize(signed(p_rdata) * to_signed(C_RD2, 24), 64);
            slot_a  <= SL_Z + jj;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(mont_d(p));
            p_we    <= '1';
            fsm     <= S_ZL_NEXT;

          when S_ZL_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_ZN_NEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_ZL_RD;
            end if;

          when S_ZN_NEXT =>
            if jj = G_L - 1 then
              jj  <= 0;
              fsm <= S_CB_MODE;
            else
              jj  <= jj + 1;
              fsm <= S_ZN_NTT;
            end if;

          ----------------------------------------------------------------
          -- c_hat from the c_tilde carried in the signature.
          ----------------------------------------------------------------
          when S_CB_MODE =>
            sp_mode  <= "01";
            smp_mode <= "11";
            fsm      <= S_CB_INIT;

          when S_CB_INIT =>
            sp_init <= '1';
            fsm     <= S_CB_INITP;

          when S_CB_INITP =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SG, 14));
              fsm     <= S_CB_WAIT;
            end if;

          when S_CB_WAIT =>
            fsm <= S_CB_ABS;

          when S_CB_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_CB_ABSW;
            end if;

          when S_CB_ABSW =>
            if cnt = 47 then
              fsm <= S_CB_FIN;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_SG + cnt + 1, 14));
              fsm     <= S_CB_WAIT;
            end if;

          when S_CB_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_CB_RUN;
            end if;

          when S_CB_RUN =>
            if sp_dvalid = '1' then
              slot_a    <= SL_CH;
              smp_mode  <= "11";
              smp_start <= '1';
              fsm       <= S_CB_NTT;
            end if;

          when S_CB_NTT =>
            if smp_done = '1' then
              slot_a    <= SL_CH;
              ntt_op    <= "00";
              ntt_start <= '1';
              fsm       <= S_CB_NTTW;
            end if;

          when S_CB_NTTW =>
            if ntt_done = '1' then
              ii  <= 0;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_W_ZERO;
            end if;

          ----------------------------------------------------------------
          -- w[r] = INTT( sum_s A[r][s] o z_hat[s]  -  c_hat o t1_hat[r] )
          ----------------------------------------------------------------
          when S_W_ZERO =>
            slot_a  <= SL_TMP;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= (others => '0');
            p_we    <= '1';
            if cnt = 255 then
              cnt <= 0;
              jj  <= 0;
              fsm <= S_W_AMODE;
            else
              cnt <= cnt + 1;
            end if;

          when S_W_AMODE =>
            sp_mode  <= "00";
            smp_mode <= "00";
            fsm      <= S_W_AINIT;

          when S_W_AINIT =>
            sp_init <= '1';
            fsm     <= S_W_AINITP;

          when S_W_AINITP =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_PK, 14));
              fsm     <= S_W_AWAIT;
            end if;

          when S_W_AWAIT =>
            fsm <= S_W_AABS;

          when S_W_AABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_W_AABSW;
            end if;

          when S_W_AABSW =>
            if cnt = 31 then
              fsm <= S_W_AIDX1;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_PK + cnt + 1, 14));
              fsm     <= S_W_AWAIT;
            end if;

          when S_W_AIDX1 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(jj, 8));
              sp_we  <= '1';
              fsm    <= S_W_AIDX2;
            end if;

          when S_W_AIDX2 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(ii, 8));
              sp_we  <= '1';
              fsm    <= S_W_AFIN;
            end if;

          when S_W_AFIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_W_ARUN;
            end if;

          when S_W_ARUN =>
            if sp_dvalid = '1' then
              slot_a    <= SL_A;
              smp_mode  <= "00";
              smp_start <= '1';
              fsm       <= S_W_MUL;
            end if;

          when S_W_MUL =>
            if smp_done = '1' then
              slot_a    <= SL_A;
              slot_b    <= SL_Z + jj;
              ntt_op    <= "10";
              ntt_start <= '1';
              fsm       <= S_W_MULW;
            end if;

          when S_W_MULW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_W_ACC_RD;
            end if;

          when S_W_ACC_RD =>
            slot_a   <= SL_A;
            p_raddr  <= std_logic_vector(to_unsigned(cnt, 8));
            slot_b   <= SL_TMP;
            p_braddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm      <= S_W_ACC_RDW;

          when S_W_ACC_RDW =>
            fsm <= S_W_ACC_WR;

          when S_W_ACC_WR =>
            slot_a  <= SL_TMP;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(signed(p_rdata) + signed(p_brdata));
            p_we    <= '1';
            fsm     <= S_W_ACC_NEXT;

          when S_W_ACC_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_W_SNEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_W_ACC_RD;
            end if;

          when S_W_SNEXT =>
            if jj = G_L - 1 then
              cnt <= 0;
              fsm <= S_CT_CP_RD;
            else
              jj  <= jj + 1;
              fsm <= S_W_AMODE;
            end if;

          -- c_hat is needed for all K rows, so it is copied WITH THE LIFT
          -- into scratch rather than consumed in place.
          when S_CT_CP_RD =>
            slot_a  <= SL_CH;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_CT_CP_RDW;

          when S_CT_CP_RDW =>
            fsm <= S_CT_CP_WR;

          when S_CT_CP_WR =>
            p       := resize(signed(p_rdata) * to_signed(C_RD2, 24), 64);
            slot_a  <= SL_TM2;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(mont_d(p));
            p_we    <= '1';
            fsm     <= S_CT_CP_NEXT;

          when S_CT_CP_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_CT_MUL;
            else
              cnt <= cnt + 1;
              fsm <= S_CT_CP_RD;
            end if;

          when S_CT_MUL =>
            slot_a    <= SL_TM2;
            slot_b    <= SL_T1 + ii;
            ntt_op    <= "10";
            ntt_start <= '1';
            fsm       <= S_CT_MULW;

          when S_CT_MULW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_CT_SUB_RD;
            end if;

          when S_CT_SUB_RD =>
            slot_a   <= SL_TMP;
            p_raddr  <= std_logic_vector(to_unsigned(cnt, 8));
            slot_b   <= SL_TM2;
            p_braddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm      <= S_CT_SUB_RDW;

          when S_CT_SUB_RDW =>
            fsm <= S_CT_SUB_WR;

          when S_CT_SUB_WR =>
            slot_a  <= SL_TMP;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(signed(p_rdata) - signed(p_brdata));
            p_we    <= '1';
            fsm     <= S_CT_SUB_NEXT;

          when S_CT_SUB_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_W_INTT;
            else
              cnt <= cnt + 1;
              fsm <= S_CT_SUB_RD;
            end if;

          when S_W_INTT =>
            fsm <= S_W_INTTS;

          when S_W_INTTS =>
            slot_a    <= SL_TMP;
            ntt_op    <= "01";
            ntt_start <= '1';
            fsm       <= S_W_INTTW;

          when S_W_INTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              if G_STOP_AT = 2 and ii = 0 then
                fsm <= S_DONE;
              else
                fsm <= S_UH_RD;
              end if;
            end if;

          ----------------------------------------------------------------
          -- w1[r] = UseHint(h[r], w[r]), written over the hint slot.
          ----------------------------------------------------------------
          when S_UH_RD =>
            slot_a   <= SL_TMP;
            p_raddr  <= std_logic_vector(to_unsigned(cnt, 8));
            slot_b   <= SL_H + ii;
            p_braddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm      <= S_UH_RDW;

          when S_UH_RDW =>
            fsm <= S_UH_WR;

          when S_UH_WR =>
            slot_a  <= SL_H + ii;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            if signed(p_brdata) /= 0 then
              p_wdata <= std_logic_vector(resize(signed('0' &
                           use_hint_d('1', canon_d(signed(p_rdata)))), C_CW));
            else
              p_wdata <= std_logic_vector(resize(signed('0' &
                           use_hint_d('0', canon_d(signed(p_rdata)))), C_CW));
            end if;
            p_we <= '1';
            fsm  <= S_UH_NEXT;

          when S_UH_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_W_RNEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_UH_RD;
            end if;

          when S_W_RNEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              if G_STOP_AT = 3 then
                fsm <= S_DONE;
              else
                fsm <= S_HE_RUN;
              end if;
            else
              ii  <= ii + 1;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_W_ZERO;
            end if;

          ----------------------------------------------------------------
          -- w1_encode then c_tilde' = SHAKE256(mu || w1_enc, 48)
          ----------------------------------------------------------------
          when S_HE_RUN =>
            slot_a    <= SL_H + ii;
            cod_mode  <= "0001";
            cod_base  <= std_logic_vector(
                           to_unsigned(G_ADDR_W1 + 128 * ii, 14));
            cod_start <= '1';
            fsm       <= S_HE_WAIT;

          when S_HE_WAIT =>
            if cod_done = '1' then
              fsm <= S_HE_NEXT;
            end if;

          when S_HE_NEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              fsm <= S_C_MODE;
            else
              ii  <= ii + 1;
              fsm <= S_HE_RUN;
            end if;

          when S_C_MODE =>
            sp_mode <= "01";
            fsm     <= S_C_INIT;

          when S_C_INIT =>
            sp_init <= '1';
            fsm     <= S_C_INITP;

          when S_C_INITP =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_MU, 14));
              fsm     <= S_C_MWAIT;
            end if;

          when S_C_MWAIT =>
            fsm <= S_C_MABS;

          when S_C_MABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_C_MABSW;
            end if;

          when S_C_MABSW =>
            if cnt = 63 then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_W1, 14));
              fsm     <= S_C_WWAIT;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_MU + cnt + 1, 14));
              fsm     <= S_C_MWAIT;
            end if;

          when S_C_WWAIT =>
            fsm <= S_C_WABS;

          when S_C_WABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_C_WABSW;
            end if;

          when S_C_WABSW =>
            if cnt = 128 * G_K - 1 then
              fsm <= S_C_FIN;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_W1 + cnt + 1, 14));
              fsm     <= S_C_WWAIT;
            end if;

          when S_C_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_C_SQ;
            end if;

          when S_C_SQ =>
            if sp_dvalid = '1' then
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_CT + cnt, 14));
              by_din  <= sp_dout;
              by_we   <= '1';
              sp_re   <= '1';
              fsm     <= S_C_SQW;
            end if;

          when S_C_SQW =>
            fsm <= S_C_SQ2;

          when S_C_SQ2 =>
            if cnt = 47 then
              cnt <= 0;
              if G_STOP_AT = 4 then
                fsm <= S_DONE;
              else
                fsm <= S_CMP_A;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_C_SQ;
            end if;

          ----------------------------------------------------------------
          -- Reason 4. Compare the recomputed c_tilde against the one the
          -- signature carries. Not constant time, and it does not need to
          -- be: everything compared here is public.
          ----------------------------------------------------------------
          when S_CMP_A =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_CT + cnt, 14));
            fsm     <= S_CMP_AW;

          when S_CMP_AW =>
            fsm <= S_CMP_B;

          when S_CMP_B =>
            ctb     <= unsigned(by_dout);
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_SG + cnt, 14));
            fsm     <= S_CMP_BW;

          when S_CMP_BW =>
            fsm <= S_CMP_T;

          when S_CMP_T =>
            if ctb /= unsigned(by_dout) then
              reason_r <= "100";
              fsm      <= S_REJECT;
            else
              fsm <= S_CMP_NEXT;
            end if;

          when S_CMP_NEXT =>
            if cnt = 47 then
              fsm <= S_ACCEPT;
            else
              cnt <= cnt + 1;
              fsm <= S_CMP_A;
            end if;

          when S_ACCEPT =>
            result_r <= '1';
            reason_r <= "000";
            fsm      <= S_DONE;

          when S_REJECT =>
            result_r <= '0';
            fsm      <= S_DONE;

          when S_DONE =>
            busy_r <= '0';
            done_r <= '1';
            fsm    <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
