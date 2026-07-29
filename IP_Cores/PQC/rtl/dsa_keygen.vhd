-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- dsa_keygen: ML-DSA-65 KeyGen, FIPS 204 Algorithm 6.
-- VHDL-2008. ASCII-only. MIT license.
--
-- The simplest of the three ML-DSA operations: single pass, no rejection
-- loop and no failure outcome, so the runtime is fixed and there is nothing
-- to expose beyond the key pair itself. No reason code is needed here, unlike
-- Verify, and no kappa, unlike Sign.
--
-- Every primitive it needs already exists and is verified:
--   ExpandA and ExpandS   sampler modes "00" and "01"
--   NTT and pointwise     ntt_d_unit
--   Power2Round           pqc_round_d_pkg
--   pack t1 / s / t0      codec modes "0000", "0010", "0011"
--
-- The one structural point worth stating: A is regenerated per (r,s) pair
-- from rho rather than stored, exactly as in Sign, because K*L = 30
-- polynomials would otherwise be live at once for a value used once each.
--
-- tr is squeezed directly into sk+64 rather than staged and copied, so the
-- secret key assembly only has to place rho, key and the three packed
-- vectors around it.
--
-- Byte map (14-bit space):
--   xi     @    0  32 bytes, caller supplied
--   seed   @   64  128 bytes, SHAKE256(xi || K || L)
--   pk     @  256  1952 bytes out
--   sk     @ 2304  4032 bytes out
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;
use work.poly_mem_d_pkg.all;

entity dsa_keygen is
  generic (
    G_K       : integer := 6;
    G_L       : integer := 5;
    G_ADDR_XI : integer := 0;
    G_ADDR_SD : integer := 64;
    G_ADDR_PK : integer := 256;
    G_ADDR_SK : integer := 2304;
    -- 0 run to completion, 1..4 stop after a named checkpoint
    G_STOP_AT : integer := 0);
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;
    done      : out std_logic;
    busy      : out std_logic;

    slot_a    : out integer range 0 to C_SLOTS_D - 1;
    slot_b    : out integer range 0 to C_SLOTS_D - 1;
    p_raddr   : out std_logic_vector(7 downto 0);
    p_rdata   : in  std_logic_vector(C_CW - 1 downto 0);
    p_braddr  : out std_logic_vector(7 downto 0);
    p_brdata  : in  std_logic_vector(C_CW - 1 downto 0);
    p_waddr   : out std_logic_vector(7 downto 0);
    p_wdata   : out std_logic_vector(C_CW - 1 downto 0);
    p_we      : out std_logic;

    ntt_start : out std_logic;
    ntt_op    : out std_logic_vector(1 downto 0);
    ntt_done  : in  std_logic;

    smp_start : out std_logic;
    smp_mode  : out std_logic_vector(1 downto 0);
    smp_done  : in  std_logic;

    cod_start : out std_logic;
    cod_mode  : out std_logic_vector(3 downto 0);
    cod_base  : out std_logic_vector(13 downto 0);
    cod_done  : in  std_logic;
    cod_valid : in  std_logic;

    sp_mode   : out std_logic_vector(1 downto 0);
    sp_init   : out std_logic;
    sp_din    : out std_logic_vector(7 downto 0);
    sp_we     : out std_logic;
    sp_adone  : out std_logic;
    sp_dout   : in  std_logic_vector(7 downto 0);
    sp_re     : out std_logic;
    sp_dvalid : in  std_logic;
    sp_ready  : in  std_logic;

    by_addr   : out std_logic_vector(13 downto 0);
    by_din    : out std_logic_vector(7 downto 0);
    by_we     : out std_logic;
    by_dout   : in  std_logic_vector(7 downto 0));
end entity dsa_keygen;

architecture rtl of dsa_keygen is

  type t_fsm is (
    S_IDLE,
    -- seed = SHAKE256(xi || K || L, 128)
    S_SD_MODE, S_SD_INIT, S_SD_INITP, S_SD_WAIT, S_SD_ABS, S_SD_ABSW,
    S_SD_KB, S_SD_LB, S_SD_FIN, S_SD_SQ, S_SD_SQW, S_SD_SQ2,
    -- s1, s2 = ExpandS(rhop)
    S_ES_MODE, S_ES_INIT, S_ES_INITP, S_ES_WAIT, S_ES_ABS, S_ES_ABSW,
    S_ES_N0, S_ES_N1, S_ES_FIN, S_ES_RUN, S_ES_NEXT,
    -- s1_hat, with the lift
    S_SH_NTT, S_SH_NTTW, S_SL_RD, S_SL_RDW, S_SL_WR, S_SL_NEXT,
    S_LF_RD, S_LF_RDS, S_LF_RDW, S_LF_NEXT, S_SH_NEXT,
    -- t[r] = INTT(sum A[r][s] o s1_hat[s]) + s2[r]
    S_W_ZERO, S_W_AMODE, S_W_AINIT, S_W_AINITP, S_W_AWAIT, S_W_AABS,
    S_W_AABSW, S_W_AIDX1, S_W_AIDX2, S_W_AFIN, S_W_ARUN,
    S_W_MUL, S_W_MULW, S_W_ACC_RD, S_W_ACC_RDW, S_W_ACC_WR, S_W_ACC_NEXT,
    S_W_SNEXT, S_W_INTT, S_W_INTTS, S_W_INTTW,
    S_TA_RD, S_TA_RDW, S_TA_WR, S_TA_NEXT,
    -- (t1, t0) = Power2Round(t)
    S_P2_RD, S_P2_RDS, S_P2_RDW, S_P2_WR1, S_P2_WR0, S_P2_NEXT,
    S_W_RNEXT,
    -- pk = rho || pack(t1), then tr = SHAKE256(pk, 64)
    S_PK_RHO, S_PK_RHOW, S_PK_RHO2, S_PK_T1, S_PK_T1W, S_PK_T1NEXT,
    S_TR_MODE, S_TR_INIT, S_TR_INITP, S_TR_WAIT, S_TR_ABS, S_TR_ABSW,
    S_TR_FIN, S_TR_SQ, S_TR_SQW, S_TR_SQ2,
    -- sk = rho || key || tr || pack(s1) || pack(s2) || pack(t0)
    S_SK_RHO, S_SK_RHOW, S_SK_RHO2, S_SK_KEY, S_SK_KEYW, S_SK_KEY2,
    S_SK_PK, S_SK_PKW, S_SK_PKNEXT,
    S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  signal ii  : integer range 0 to 31 := 0;
  signal jj  : integer range 0 to 15 := 0;
  signal cnt : integer range 0 to 8191 := 0;
  signal acc_v : signed(C_CW - 1 downto 0) := (others => '0');

  constant SL_A   : integer := 0;
  constant SL_S1  : integer := 1;    -- s1[0..L-1], then s1_hat in place
  constant SL_S2  : integer := 6;    -- s2[0..K-1]
  constant SL_T1  : integer := 12;   -- t1[0..K-1]
  constant SL_T0  : integer := 18;   -- t0[0..K-1]
  constant SL_T   : integer := 24;   -- t[0..K-1] reuses one scratch per row
  constant SL_TMP : integer := 25;
  -- s1_hat lives in its OWN slots: sk carries the plain s1, and transforming
  -- in place would destroy it. This is the third time in this core that an
  -- in-place transform ate a value needed later, after Sign's y and the
  -- c_hat product, so the copy is explicit rather than clever.
  constant SL_S1H : integer := 26;   -- s1_hat[0..L-1]

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

begin

  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable p : signed(63 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm       <= S_IDLE;
        busy_r    <= '0';
        done_r    <= '0';
        slot_a    <= 0;
        slot_b    <= 0;
        p_raddr   <= (others => '0');
        p_braddr  <= (others => '0');
        p_waddr   <= (others => '0');
        p_wdata   <= (others => '0');
        p_we      <= '0';
        ntt_start <= '0';
        ntt_op    <= "00";
        smp_start <= '0';
        smp_mode  <= "00";
        cod_start <= '0';
        cod_mode  <= "0000";
        cod_base  <= (others => '0');
        sp_mode   <= "01";
        sp_init   <= '0';
        sp_din    <= (others => '0');
        sp_we     <= '0';
        sp_adone  <= '0';
        sp_re     <= '0';
        by_addr   <= (others => '0');
        by_din    <= (others => '0');
        by_we     <= '0';
        ii        <= 0;
        jj        <= 0;
        cnt       <= 0;
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
              busy_r <= '1';
              cnt    <= 0;
              ii     <= 0;
              jj     <= 0;
              fsm    <= S_SD_MODE;
            end if;

          ----------------------------------------------------------------
          -- seed = SHAKE256(xi || K || L, 128) -> rho(32) rhop(64) key(32)
          ----------------------------------------------------------------
          when S_SD_MODE =>
            sp_mode <= "01";
            fsm     <= S_SD_INIT;

          when S_SD_INIT =>
            sp_init <= '1';
            fsm     <= S_SD_INITP;

          when S_SD_INITP =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_XI, 14));
              fsm     <= S_SD_WAIT;
            end if;

          when S_SD_WAIT =>
            fsm <= S_SD_ABS;

          when S_SD_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_SD_ABSW;
            end if;

          when S_SD_ABSW =>
            if cnt = 31 then
              fsm <= S_SD_KB;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_XI + cnt + 1, 14));
              fsm     <= S_SD_WAIT;
            end if;

          when S_SD_KB =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(G_K, 8));
              sp_we  <= '1';
              fsm    <= S_SD_LB;
            end if;

          when S_SD_LB =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(G_L, 8));
              sp_we  <= '1';
              fsm    <= S_SD_FIN;
            end if;

          when S_SD_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_SD_SQ;
            end if;

          when S_SD_SQ =>
            if sp_dvalid = '1' then
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SD + cnt, 14));
              by_din  <= sp_dout;
              by_we   <= '1';
              sp_re   <= '1';
              fsm     <= S_SD_SQW;
            end if;

          when S_SD_SQW =>
            fsm <= S_SD_SQ2;

          when S_SD_SQ2 =>
            if cnt = 127 then
              cnt <= 0;
              ii  <= 0;
              fsm <= S_ES_MODE;
            else
              cnt <= cnt + 1;
              fsm <= S_SD_SQ;
            end if;

          ----------------------------------------------------------------
          -- s1[0..L-1] and s2[0..K-1] = ExpandS(rhop). The counter is the
          -- polynomial index across BOTH vectors, so s2[r] uses index L+r.
          ----------------------------------------------------------------
          when S_ES_MODE =>
            sp_mode  <= "01";
            smp_mode <= "01";
            fsm      <= S_ES_INIT;

          when S_ES_INIT =>
            sp_init <= '1';
            fsm     <= S_ES_INITP;

          when S_ES_INITP =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SD + 32, 14));
              fsm     <= S_ES_WAIT;
            end if;

          when S_ES_WAIT =>
            fsm <= S_ES_ABS;

          when S_ES_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_ES_ABSW;
            end if;

          when S_ES_ABSW =>
            if cnt = 63 then
              fsm <= S_ES_N0;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_SD + 32 + cnt + 1, 14));
              fsm     <= S_ES_WAIT;
            end if;

          when S_ES_N0 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(ii mod 256, 8));
              sp_we  <= '1';
              fsm    <= S_ES_N1;
            end if;

          when S_ES_N1 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(ii / 256, 8));
              sp_we  <= '1';
              fsm    <= S_ES_FIN;
            end if;

          when S_ES_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_ES_RUN;
            end if;

          when S_ES_RUN =>
            if sp_dvalid = '1' then
              if ii < G_L then
                slot_a <= SL_S1 + ii;
              else
                slot_a <= SL_S2 + (ii - G_L);
              end if;
              smp_mode  <= "01";
              smp_start <= '1';
              fsm       <= S_ES_NEXT;
            end if;

          when S_ES_NEXT =>
            if smp_done = '1' then
              if ii = G_L + G_K - 1 then
                ii  <= 0;
                jj  <= 0;
                -- cnt MUST be reset here: it is left at 63 by the ExpandS
                -- absorb loop, and the copy that follows uses it as the
                -- coefficient index, so without this the first 63
                -- coefficients of s1_hat are never written.
                cnt <= 0;
                if G_STOP_AT = 1 then
                  fsm <= S_DONE;
                else
                  fsm <= S_SH_NTT;
                end if;
              else
                ii  <= ii + 1;
                fsm <= S_ES_MODE;
              end if;
            end if;

          ----------------------------------------------------------------
          -- s1_hat = NTT(s1), lifted. Exactly one operand of A o s1_hat
          -- carries R^2 and A comes straight from SampleNTT, so it is s1.
          ----------------------------------------------------------------
          -- Copy s1 into its own slot, then transform and lift there.
          -- sk carries the plain s1, so the forward NTT must not run over it:
          -- that is the third time in this core an in-place transform ate a
          -- value needed later, after Sign's y and the c_hat product.
          when S_SH_NTT =>
            slot_a  <= SL_S1 + jj;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_SH_NTTW;

          when S_SH_NTTW =>
            fsm <= S_SL_RD;

          when S_SL_RD =>
            slot_a  <= SL_S1H + jj;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= p_rdata;
            p_we    <= '1';
            fsm     <= S_SL_RDW;

          when S_SL_RDW =>
            if cnt = 255 then
              cnt       <= 0;
              if G_STOP_AT = 5 and jj = 0 then
                fsm <= S_DONE;
              else
              slot_a    <= SL_S1H + jj;
              ntt_op    <= "00";
              ntt_start <= '1';
              fsm       <= S_SL_WR;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_SH_NTT;
            end if;

          when S_SL_WR =>
            fsm <= S_SL_NEXT;

          when S_SL_NEXT =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_LF_RD;
            end if;

          when S_LF_RD =>
            slot_a  <= SL_S1H + jj;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_LF_RDS;

          when S_LF_RDS =>
            fsm <= S_LF_RDW;

          when S_LF_RDW =>
            p       := resize(signed(p_rdata) * to_signed(C_RD2, 24), 64);
            slot_a  <= SL_S1H + jj;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(mont_d(p));
            p_we    <= '1';
            fsm     <= S_LF_NEXT;

          when S_LF_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_SH_NEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_LF_RD;
            end if;

          when S_SH_NEXT =>
            cnt <= 0;
            if jj = G_L - 1 then
              jj  <= 0;
              ii  <= 0;
              cnt <= 0;
              fsm <= S_W_ZERO;
            else
              jj  <= jj + 1;
              fsm <= S_SH_NTT;
            end if;

          ----------------------------------------------------------------
          -- t[r] = INTT(sum_s A[r][s] o s1_hat[s]) + s2[r]
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
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SD, 14));
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
                           to_unsigned(G_ADDR_SD + cnt + 1, 14));
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
              slot_b    <= SL_S1H + jj;
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
              fsm <= S_W_INTT;
            else
              jj  <= jj + 1;
              fsm <= S_W_AMODE;
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
              fsm <= S_TA_RD;
            end if;

          -- t[r] = that INTT plus s2[r]
          when S_TA_RD =>
            slot_a   <= SL_TMP;
            p_raddr  <= std_logic_vector(to_unsigned(cnt, 8));
            slot_b   <= SL_S2 + ii;
            p_braddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm      <= S_TA_RDW;

          when S_TA_RDW =>
            fsm <= S_TA_WR;

          when S_TA_WR =>
            slot_a  <= SL_T;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(signed(p_rdata) + signed(p_brdata));
            p_we    <= '1';
            fsm     <= S_TA_NEXT;

          when S_TA_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              if G_STOP_AT = 2 and ii = 0 then
                fsm <= S_DONE;
              else
                fsm <= S_P2_RD;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_TA_RD;
            end if;

          ----------------------------------------------------------------
          -- (t1, t0) = Power2Round(t), coefficient by coefficient
          ----------------------------------------------------------------
          when S_P2_RD =>
            slot_a  <= SL_T;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_P2_RDS;

          -- The address assigned above does not take effect until the next
          -- cycle, and the memory presents its data the cycle after that, so
          -- the capture needs a settle state in between. S_TA_RD/RDW/WR has
          -- three states for the same reason and is correct, which is why
          -- KP2 passed and KP3 did not.
          when S_P2_RDS =>
            fsm <= S_P2_RDW;

          when S_P2_RDW =>
            acc_v <= signed(p_rdata);
            fsm   <= S_P2_WR1;

          when S_P2_WR1 =>
            slot_a  <= SL_T1 + ii;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(
                         resize(signed('0' & p2r_hi(canon_d(acc_v))), C_CW));
            p_we    <= '1';
            fsm     <= S_P2_WR0;

          when S_P2_WR0 =>
            slot_a  <= SL_T0 + ii;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(p2r_lo(canon_d(acc_v)));
            p_we    <= '1';
            fsm     <= S_P2_NEXT;

          when S_P2_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              if G_STOP_AT = 3 and ii = 0 then
                fsm <= S_DONE;
              else
                fsm <= S_W_RNEXT;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_P2_RD;
            end if;

          when S_W_RNEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              cnt <= 0;
              fsm <= S_PK_RHO;
            else
              ii  <= ii + 1;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_W_ZERO;
            end if;

          ----------------------------------------------------------------
          -- pk = rho || pack(t1 at 10 bits)
          ----------------------------------------------------------------
          when S_PK_RHO =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_SD + cnt, 14));
            fsm     <= S_PK_RHOW;

          when S_PK_RHOW =>
            fsm <= S_PK_RHO2;

          when S_PK_RHO2 =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_PK + cnt, 14));
            by_din  <= by_dout;
            by_we   <= '1';
            if cnt = 31 then
              cnt <= 0;
              ii  <= 0;
              fsm <= S_PK_T1;
            else
              cnt <= cnt + 1;
              fsm <= S_PK_RHO;
            end if;

          when S_PK_T1 =>
            slot_a    <= SL_T1 + ii;
            cod_mode  <= "0000";
            cod_base  <= std_logic_vector(
                           to_unsigned(G_ADDR_PK + 32 + 320 * ii, 14));
            cod_start <= '1';
            fsm       <= S_PK_T1W;

          when S_PK_T1W =>
            if cod_done = '1' then
              fsm <= S_PK_T1NEXT;
            end if;

          when S_PK_T1NEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              fsm <= S_TR_MODE;
            else
              ii  <= ii + 1;
              fsm <= S_PK_T1;
            end if;

          ----------------------------------------------------------------
          -- tr = SHAKE256(pk, 64)
          ----------------------------------------------------------------
          when S_TR_MODE =>
            sp_mode <= "01";
            fsm     <= S_TR_INIT;

          when S_TR_INIT =>
            sp_init <= '1';
            fsm     <= S_TR_INITP;

          when S_TR_INITP =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_PK, 14));
              fsm     <= S_TR_WAIT;
            end if;

          when S_TR_WAIT =>
            fsm <= S_TR_ABS;

          when S_TR_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_TR_ABSW;
            end if;

          when S_TR_ABSW =>
            if cnt = 32 + 320 * G_K - 1 then
              fsm <= S_TR_FIN;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_PK + cnt + 1, 14));
              fsm     <= S_TR_WAIT;
            end if;

          when S_TR_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_TR_SQ;
            end if;

          when S_TR_SQ =>
            if sp_dvalid = '1' then
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_SK + 64 + cnt, 14));
              by_din  <= sp_dout;
              by_we   <= '1';
              sp_re   <= '1';
              fsm     <= S_TR_SQW;
            end if;

          when S_TR_SQW =>
            fsm <= S_TR_SQ2;

          when S_TR_SQ2 =>
            if cnt = 63 then
              cnt <= 0;
              if G_STOP_AT = 4 then
                fsm <= S_DONE;
              else
                fsm <= S_SK_RHO;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_TR_SQ;
            end if;

          ----------------------------------------------------------------
          -- sk = rho || key || tr || pack(s1) || pack(s2) || pack(t0)
          -- tr is already in place at sk+64.
          ----------------------------------------------------------------
          when S_SK_RHO =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_SD + cnt, 14));
            fsm     <= S_SK_RHOW;

          when S_SK_RHOW =>
            fsm <= S_SK_RHO2;

          when S_SK_RHO2 =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_SK + cnt, 14));
            by_din  <= by_dout;
            by_we   <= '1';
            if cnt = 31 then
              cnt <= 0;
              fsm <= S_SK_KEY;
            else
              cnt <= cnt + 1;
              fsm <= S_SK_RHO;
            end if;

          when S_SK_KEY =>
            by_addr <= std_logic_vector(
                         to_unsigned(G_ADDR_SD + 96 + cnt, 14));
            fsm     <= S_SK_KEYW;

          when S_SK_KEYW =>
            fsm <= S_SK_KEY2;

          when S_SK_KEY2 =>
            by_addr <= std_logic_vector(
                         to_unsigned(G_ADDR_SK + 32 + cnt, 14));
            by_din  <= by_dout;
            by_we   <= '1';
            if cnt = 31 then
              cnt <= 0;
              ii  <= 0;
              fsm <= S_SK_PK;
            else
              cnt <= cnt + 1;
              fsm <= S_SK_KEY;
            end if;

          -- s1 at 4 bits, then s2 at 4 bits, then t0 at 13 bits
          when S_SK_PK =>
            if ii < G_L then
              slot_a   <= SL_S1 + ii;
              cod_mode <= "0010";
              cod_base <= std_logic_vector(
                            to_unsigned(G_ADDR_SK + 128 + 128 * ii, 14));
            elsif ii < G_L + G_K then
              slot_a   <= SL_S2 + (ii - G_L);
              cod_mode <= "0010";
              cod_base <= std_logic_vector(
                            to_unsigned(G_ADDR_SK + 128 + 128 * ii, 14));
            else
              slot_a   <= SL_T0 + (ii - G_L - G_K);
              cod_mode <= "0011";
              cod_base <= std_logic_vector(
                            to_unsigned(G_ADDR_SK + 128 +
                                        128 * (G_L + G_K) +
                                        416 * (ii - G_L - G_K), 14));
            end if;
            cod_start <= '1';
            fsm       <= S_SK_PKW;

          when S_SK_PKW =>
            if cod_done = '1' then
              fsm <= S_SK_PKNEXT;
            end if;

          when S_SK_PKNEXT =>
            if ii = G_L + 2 * G_K - 1 then
              fsm <= S_DONE;
            else
              ii  <= ii + 1;
              fsm <= S_SK_PK;
            end if;

          when S_DONE =>
            busy_r <= '0';
            done_r <= '1';
            fsm    <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
