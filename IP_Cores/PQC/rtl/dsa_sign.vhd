-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- dsa_sign: ML-DSA-65 Sign, FIPS 204 Algorithm 7 (deterministic variant).
-- VHDL-2008. ASCII-only. MIT license.
--
-- THE MESSAGE IS NOT STORED. mu is a 64-byte input and the sequencer never
-- sees the message, which may be arbitrarily long: the ACVP vectors alone
-- reach 7583 bytes. A fixed message buffer would be a limitation invented by
-- the implementation rather than required by the algorithm. The host computes
-- mu = SHAKE256(tr || mprime, 64) with the same sponge, already validated in
-- silicon from the ML-KEM phase. Verified against the model that mu is the
-- only message-derived input any later step needs.
--
-- LIFT BOOKKEEPING. Exactly one operand of every pointwise product carries
-- the R^2 lift. Here it is y_hat, and the choice is a cost decision rather
-- than a constraint: either operand is admissible, but A is regenerated
-- K*L = 30 times per iteration while y is produced L = 5 times, so lifting y
-- is six times cheaper. A is never re-transformed, because SampleNTT output
-- is already in the NTT domain; y comes out of ExpandMask as a plain
-- polynomial and must be transformed.
--
-- THE REJECTION LOOP. Unlike everything in ML-KEM, the iteration count is
-- data-dependent: measured between 1 and 12 over the ACVP vectors. kappa
-- advances by L per iteration and is exposed as an output, because it is the
-- only observable that distinguishes "the loop ran the right number of times"
-- from "the loop happened to produce the right bytes". It is a deterministic
-- function of the inputs, not a timing measurement.
--
-- Byte map (14-bit space):
--   sk       @    0  4032 bytes, caller supplied
--   mu       @ 4096  64 bytes, caller supplied
--   rhop2    @ 4160  64 bytes
--   c_tilde  @ 4224  48 bytes
--   w1_enc   @ 4352  768 bytes
--   sig      @ 8192  3309 bytes out
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;
use work.poly_mem_d_pkg.all;

entity dsa_sign is
  generic (
    G_K       : integer := 6;
    G_L       : integer := 5;
    G_ADDR_SK : integer := 0;
    G_ADDR_MU : integer := 4096;
    G_ADDR_RP : integer := 4160;
    G_ADDR_CT : integer := 4224;
    G_ADDR_W1 : integer := 4352;
    G_ADDR_SG : integer := 8192;
    -- Halt after a named checkpoint, for inspection:
    --   0 run to completion
    --   1 after y[0] of the FIRST iteration
    --   2 after w1[0] of the first iteration
    --   3 after c_tilde of the first iteration
    --   4 after z[0] of the first iteration, EVEN IF THAT ITERATION REJECTS
    G_STOP_AT : integer := 0);
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    start      : in  std_logic;
    done       : out std_logic;
    busy       : out std_logic;
    -- final kappa, part of the end-of-run signature
    kappa_out  : out std_logic_vector(15 downto 0);

    -- polynomial memory, two read ports and one write port
    slot_a     : out integer range 0 to C_SLOTS_D - 1;
    slot_b     : out integer range 0 to C_SLOTS_D - 1;
    p_raddr    : out std_logic_vector(7 downto 0);
    p_rdata    : in  std_logic_vector(C_CW - 1 downto 0);
    p_braddr   : out std_logic_vector(7 downto 0);
    p_brdata   : in  std_logic_vector(C_CW - 1 downto 0);
    p_waddr    : out std_logic_vector(7 downto 0);
    p_wdata    : out std_logic_vector(C_CW - 1 downto 0);
    p_we       : out std_logic;

    -- NTT-D datapath
    ntt_start  : out std_logic;
    ntt_op     : out std_logic_vector(1 downto 0);
    ntt_done   : in  std_logic;

    -- sampler
    smp_start  : out std_logic;
    smp_mode   : out std_logic_vector(1 downto 0);
    smp_done   : in  std_logic;

    -- codec
    cod_start  : out std_logic;
    cod_mode   : out std_logic_vector(3 downto 0);
    cod_base   : out std_logic_vector(13 downto 0);
    cod_done   : in  std_logic;

    -- sponge
    sp_mode    : out std_logic_vector(1 downto 0);
    sp_init    : out std_logic;
    sp_din     : out std_logic_vector(7 downto 0);
    sp_we      : out std_logic;
    sp_adone   : out std_logic;
    sp_dout    : in  std_logic_vector(7 downto 0);
    sp_re      : out std_logic;
    sp_dvalid  : in  std_logic;
    sp_ready   : in  std_logic;

    -- byte memory
    by_addr    : out std_logic_vector(13 downto 0);
    by_din     : out std_logic_vector(7 downto 0);
    by_we      : out std_logic;
    by_dout    : in  std_logic_vector(7 downto 0));
end entity dsa_sign;

architecture rtl of dsa_sign is

  type t_fsm is (
    S_IDLE,
    -- setup: unpack s1, s2, t0 from sk and transform them once
    S_U_RUN, S_U_WAIT, S_U_NEXT, S_U_NTT, S_U_NTTW, S_U_TNEXT,
    -- setup: rhop2 = SHAKE256(key || rnd || mu)
    S_R_MODE, S_R_INIT, S_R_INIT_P, S_R_KWAIT, S_R_KABS, S_R_KABSW,
    S_R_ZABS, S_R_ZABSW, S_R_MWAIT, S_R_MABS, S_R_MABSW, S_R_FIN,
    S_R_SQ, S_R_SQW, S_R_SQ2,
    -- per iteration: y = ExpandMask
    S_Y_MODE, S_Y_INIT, S_Y_INIT_P, S_Y_WAIT, S_Y_ABS, S_Y_ABSW,
    S_Y_N0, S_Y_N1, S_Y_FIN, S_Y_RUN, S_Y_NTT,
    S_YC_RD, S_YC_RDW, S_YC_WR, S_YC_NEXT, S_Y_NTTW,
    S_YL_RD, S_YL_RDW, S_YL_WR, S_YL_NEXT, S_Y_NEXT,
    -- w = INTT(sum A o y_hat)
    S_W_ZERO, S_W_AMODE, S_W_AINIT, S_W_AINIT_P, S_W_AWAIT, S_W_AABS,
    S_W_AABSW, S_W_AIDX1, S_W_AIDX2, S_W_AFIN, S_W_ARUN,
    S_W_MUL, S_W_MULW, S_W_ACC_RD, S_W_ACC_RDW, S_W_ACC_WR, S_W_ACC_NEXT,
    S_W_SNEXT, S_W_INTT, S_W_INTTW, S_W_RNEXT,
    -- w1 = HighBits(w), then encode
    S_H_RD, S_H_RDW, S_H_WR, S_H_W1, S_H_NEXT, S_H_ROW,
    S_HE_RUN, S_HE_WAIT, S_HE_NEXT,
    -- c_tilde = SHAKE256(mu || w1_enc)
    S_C_MODE, S_C_INIT, S_C_INIT_P, S_C_MWAIT, S_C_MABS, S_C_MABSW,
    S_C_WWAIT, S_C_WABS, S_C_WABSW, S_C_FIN, S_C_SQ, S_C_SQW, S_C_SQ2,
    -- c_hat = NTT(SampleInBall)
    S_B_MODE, S_B_INIT, S_B_INIT_P, S_B_WAIT, S_B_ABS, S_B_ABSW, S_B_FIN,
    S_B_RUN, S_B_NTT, S_B_NTTW,
    -- z = y + INTT(c_hat o s1_hat)
    S_CP_RD, S_CP_RDW, S_CP_WR, S_CP_NEXT,
    S_Z_MUL, S_Z_MULW, S_Z_INTT, S_Z_INTTW,
    S_Z_RD, S_Z_RDW, S_Z_WR, S_Z_NEXT, S_Z_SNEXT,
    -- rejection 1
    S_ZC_RD, S_ZC_RDW, S_ZC_TEST, S_ZC_NEXT, S_ZC_SNEXT,
    -- wcs2 = w - INTT(c_hat o s2_hat), rejection 2
    S_V_MUL, S_V_MULW, S_V_INTT, S_V_INTTW,
    S_V_RD, S_V_RDW, S_V_WR, S_V_NEXT, S_V_RNEXT,
    S_VC_RD, S_VC_RDW, S_VC_TEST, S_VC_NEXT, S_VC_RNEXT,
    -- ct0, rejection 3, hints, rejection 4
    S_T_MUL, S_T_MULW, S_T_INTT, S_T_INTTW,
    S_TC_RD, S_TC_RDW, S_TC_TEST, S_TC_NEXT, S_TC_RNEXT,
    S_HH_RD, S_HH_RDW, S_HH_WR, S_HH_NEXT, S_HH_RNEXT,
    S_HW_CHK,
    -- signature assembly
    S_SG_CT, S_SG_CTS, S_SG_CTW, S_SG_Z, S_SG_ZW, S_SG_ZNEXT,
    S_SG_H, S_SG_HW,
    S_REJECT, S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  -- ii doubles as the setup index, which runs to L + 2K - 1 = 16, so the
  -- range must cover that and not just the K rows of the main loop.
  signal ii    : integer range 0 to 31 := 0;   -- row index r, setup index
  signal jj    : integer range 0 to 15 := 0;   -- column index s
  signal cnt   : integer range 0 to 8191 := 0;
  signal kappa : integer range 0 to 4095 := 0;
  signal iter  : integer range 0 to 255 := 0;

  signal acc_val : signed(C_CW - 1 downto 0) := (others => '0');
  -- Where S_CP_NEXT returns to. The c_hat copy is shared by the three
  -- products that consume it (z, wcs2, ct0), so the caller records its
  -- continuation rather than the copy being duplicated three times.
  --   0 -> S_Z_MUL   1 -> S_V_MUL   2 -> S_T_MUL
  signal cp_ret  : integer range 0 to 2 := 0;
  signal hw_cnt  : integer range 0 to 2047 := 0;

  -- slot map, laid out so no live value is overwritten within an iteration
  constant SL_A   : integer := 0;                 -- current A[r][s]
  constant SL_Y   : integer := 1;                 -- y[0..L-1]
  constant SL_YH  : integer := 6;                 -- lifted y_hat[0..L-1]
  constant SL_S1  : integer := 11;                -- s1_hat[0..L-1]
  constant SL_S2  : integer := 16;                -- s2_hat[0..K-1]
  constant SL_T0  : integer := 22;                -- t0_hat[0..K-1]
  constant SL_W   : integer := 28;                -- w[0..K-1], later wcs2
  constant SL_CH  : integer := 34;                -- c_hat
  constant SL_TMP : integer := 35;                -- accumulator / scratch
  constant SL_Z   : integer := 36;                -- z[0..L-1]
  constant SL_H   : integer := 41;                -- hints, and ct0 scratch

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

  -- infinity norm test against a bound, on a centred representative
  function absv (x : signed) return signed is
  begin
    if x < 0 then
      return -x;
    end if;
    return x;
  end function absv;

begin

  busy      <= busy_r;
  done      <= done_r;
  kappa_out <= std_logic_vector(to_unsigned(kappa, 16));

  process (clk)
    variable p  : signed(63 downto 0);
    variable cv : signed(C_CW - 1 downto 0);
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
        kappa     <= 0;
        iter      <= 0;
        hw_cnt    <= 0;
        cp_ret    <= 0;
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
              kappa  <= 0;
              iter   <= 0;
              cnt    <= 0;
              ii     <= 0;
              jj     <= 0;
              hw_cnt <= 0;
              fsm    <= S_U_RUN;
            end if;

          ----------------------------------------------------------------
          -- Setup, run once: unpack s1[L] and s2[K] at 4 bits and t0[K] at
          -- 13 bits from sk, then forward-transform all of them. These stay
          -- live for every iteration of the rejection loop.
          --
          -- sk layout: rho(32) key(32) tr(64) s1[L] s2[K] t0[K]
          ----------------------------------------------------------------
          when S_U_RUN =>
            if ii < G_L then
              slot_a   <= SL_S1 + ii;
              cod_mode <= "1000";
              cod_base <= std_logic_vector(
                            to_unsigned(G_ADDR_SK + 128 + 128 * ii, 14));
            elsif ii < G_L + G_K then
              slot_a   <= SL_S2 + (ii - G_L);
              cod_mode <= "1000";
              cod_base <= std_logic_vector(
                            to_unsigned(G_ADDR_SK + 128 + 128 * ii, 14));
            else
              slot_a   <= SL_T0 + (ii - G_L - G_K);
              cod_mode <= "1001";
              cod_base <= std_logic_vector(
                            to_unsigned(G_ADDR_SK + 128 +
                                        128 * (G_L + G_K) +
                                        416 * (ii - G_L - G_K), 14));
            end if;
            cod_start <= '1';
            fsm       <= S_U_WAIT;

          when S_U_WAIT =>
            if cod_done = '1' then
              fsm <= S_U_NEXT;
            end if;

          when S_U_NEXT =>
            if ii = G_L + 2 * G_K - 1 then
              ii  <= 0;
              fsm <= S_U_NTT;
            else
              ii  <= ii + 1;
              fsm <= S_U_RUN;
            end if;

          when S_U_NTT =>
            if ii < G_L then
              slot_a <= SL_S1 + ii;
            elsif ii < G_L + G_K then
              slot_a <= SL_S2 + (ii - G_L);
            else
              slot_a <= SL_T0 + (ii - G_L - G_K);
            end if;
            ntt_op    <= "00";
            ntt_start <= '1';
            fsm       <= S_U_NTTW;

          when S_U_NTTW =>
            if ntt_done = '1' then
              fsm <= S_U_TNEXT;
            end if;

          when S_U_TNEXT =>
            if ii = G_L + 2 * G_K - 1 then
              ii  <= 0;
              fsm <= S_R_MODE;
            else
              ii  <= ii + 1;
              fsm <= S_U_NTT;
            end if;

          ----------------------------------------------------------------
          -- rhop2 = SHAKE256(key || rnd || mu), rnd = 32 zero bytes for the
          -- deterministic variant.
          ----------------------------------------------------------------
          when S_R_MODE =>
            sp_mode <= "01";
            fsm     <= S_R_INIT;

          when S_R_INIT =>
            sp_init <= '1';
            fsm     <= S_R_INIT_P;

          when S_R_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SK + 32, 14));
              fsm     <= S_R_KWAIT;
            end if;

          when S_R_KWAIT =>
            fsm <= S_R_KABS;

          when S_R_KABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_R_KABSW;
            end if;

          when S_R_KABSW =>
            if cnt = 31 then
              cnt <= 0;
              fsm <= S_R_ZABS;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_SK + 32 + cnt + 1, 14));
              fsm     <= S_R_KWAIT;
            end if;

          -- rnd: 32 zero bytes, absorbed directly rather than fetched
          when S_R_ZABS =>
            if sp_ready = '1' then
              sp_din <= (others => '0');
              sp_we  <= '1';
              fsm    <= S_R_ZABSW;
            end if;

          when S_R_ZABSW =>
            if cnt = 31 then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_MU, 14));
              fsm     <= S_R_MWAIT;
            else
              cnt <= cnt + 1;
              fsm <= S_R_ZABS;
            end if;

          when S_R_MWAIT =>
            fsm <= S_R_MABS;

          when S_R_MABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_R_MABSW;
            end if;

          when S_R_MABSW =>
            if cnt = 63 then
              fsm <= S_R_FIN;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_MU + cnt + 1, 14));
              fsm     <= S_R_MWAIT;
            end if;

          when S_R_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_R_SQ;
            end if;

          when S_R_SQ =>
            if sp_dvalid = '1' then
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_RP + cnt, 14));
              by_din  <= sp_dout;
              by_we   <= '1';
              sp_re   <= '1';
              fsm     <= S_R_SQW;
            end if;

          when S_R_SQW =>
            fsm <= S_R_SQ2;

          when S_R_SQ2 =>
            if cnt = 63 then
              cnt <= 0;
              jj  <= 0;
              fsm <= S_Y_MODE;
            else
              cnt <= cnt + 1;
              fsm <= S_R_SQ;
            end if;

          ----------------------------------------------------------------
          -- y[s] = ExpandMask(rhop2, kappa + s). The counter is absorbed as
          -- two little-endian bytes after the 64-byte seed.
          ----------------------------------------------------------------
          when S_Y_MODE =>
            sp_mode  <= "01";
            smp_mode <= "10";
            fsm      <= S_Y_INIT;

          when S_Y_INIT =>
            sp_init <= '1';
            fsm     <= S_Y_INIT_P;

          when S_Y_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_RP, 14));
              fsm     <= S_Y_WAIT;
            end if;

          when S_Y_WAIT =>
            fsm <= S_Y_ABS;

          when S_Y_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_Y_ABSW;
            end if;

          when S_Y_ABSW =>
            if cnt = 63 then
              fsm <= S_Y_N0;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_RP + cnt + 1, 14));
              fsm     <= S_Y_WAIT;
            end if;

          when S_Y_N0 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(
                          to_unsigned((kappa + jj) mod 256, 8));
              sp_we  <= '1';
              fsm    <= S_Y_N1;
            end if;

          when S_Y_N1 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(
                          to_unsigned((kappa + jj) / 256, 8));
              sp_we  <= '1';
              fsm    <= S_Y_FIN;
            end if;

          when S_Y_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_Y_RUN;
            end if;

          when S_Y_RUN =>
            if sp_dvalid = '1' then
              slot_a    <= SL_Y + jj;
              smp_mode  <= "10";
              smp_start <= '1';
              fsm       <= S_Y_NTT;
            end if;

          when S_Y_NTT =>
            if smp_done = '1' then
              if G_STOP_AT = 1 and iter = 0 and jj = 0 then
                fsm <= S_DONE;
              else
                cnt <= 0;
                fsm <= S_YC_RD;
              end if;
            end if;

          -- y is needed TWICE per iteration and in two domains: plain for
          -- z = y + INTT(c o s1_hat), transformed and lifted for the matrix
          -- products. The forward NTT operates in place, so transforming
          -- SL_Y directly destroys the plain copy and z silently picks up
          -- y_hat instead: that is exactly the SP4 failure, invisible to
          -- SP1 (which stops before the NTT) and to SP2/SP3 (which only
          -- consume the transformed domain). The copy below preserves SL_Y
          -- and the NTT and lift both operate on SL_YH.
          when S_YC_RD =>
            slot_a  <= SL_Y + jj;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_YC_RDW;

          when S_YC_RDW =>
            fsm <= S_YC_WR;

          when S_YC_WR =>
            slot_a  <= SL_YH + jj;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= p_rdata;
            p_we    <= '1';
            fsm     <= S_YC_NEXT;

          when S_YC_NEXT =>
            if cnt = 255 then
              cnt       <= 0;
              slot_a    <= SL_YH + jj;
              ntt_op    <= "00";
              ntt_start <= '1';
              fsm       <= S_Y_NTTW;
            else
              cnt <= cnt + 1;
              fsm <= S_YC_RD;
            end if;

          when S_Y_NTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_YL_RD;
            end if;

          -- lift y_hat into YH: exactly one basemul operand carries R^2, and
          -- y is the cheaper choice because A is regenerated K*L times per
          -- iteration while y is produced only L times.
          when S_YL_RD =>
            slot_a  <= SL_YH + jj;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_YL_RDW;

          when S_YL_RDW =>
            fsm <= S_YL_WR;

          when S_YL_WR =>
            -- The product width is the SUM of the operand widths, not the
            -- width of the destination: a 32-bit coefficient times a 24-bit
            -- constant is 56 bits. This is the fourth place in this core
            -- where an under-sized product variable caused a runtime bound
            -- failure, after mont_d, twog2_quot and the FNV accumulator.
            p       := resize(signed(p_rdata) * to_signed(C_RD2, 24), 64);
            slot_a  <= SL_YH + jj;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(mont_d(p));
            p_we    <= '1';
            fsm     <= S_YL_NEXT;

          when S_YL_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_Y_NEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_YL_RD;
            end if;

          when S_Y_NEXT =>
            if jj = G_L - 1 then
              jj  <= 0;
              ii  <= 0;
              cnt <= 0;
              fsm <= S_W_ZERO;
            else
              jj  <= jj + 1;
              fsm <= S_Y_MODE;
            end if;

          ----------------------------------------------------------------
          -- w[r] = INTT(sum_s A[r][s] o YH[s])
          -- A is regenerated per (r,s) from rho rather than stored: K*L = 30
          -- polynomials would otherwise be live at once.
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
            fsm     <= S_W_AINIT_P;

          when S_W_AINIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SK, 14));
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
                           to_unsigned(G_ADDR_SK + cnt + 1, 14));
              fsm     <= S_W_AWAIT;
            end if;

          -- A[r][s] uses seed bytes (s, r), column first
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
              slot_b    <= SL_YH + jj;
              ntt_op    <= "10";
              ntt_start <= '1';
              fsm       <= S_W_MULW;
            end if;

          when S_W_MULW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_W_ACC_RD;
            end if;

          -- accumulate the product into TMP
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
            p_wdata <= std_logic_vector(
                         signed(p_rdata) + signed(p_brdata));
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
            slot_a    <= SL_TMP;
            ntt_op    <= "01";
            ntt_start <= '1';
            fsm       <= S_W_INTTW;

          when S_W_INTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_W_RNEXT;
            end if;

          -- copy TMP into w[r]
          when S_W_RNEXT =>
            slot_a   <= SL_TMP;
            p_raddr  <= std_logic_vector(to_unsigned(cnt, 8));
            fsm      <= S_H_RD;

          ----------------------------------------------------------------
          -- w1[r] = HighBits(w[r]), computed as the copy is made
          ----------------------------------------------------------------
          when S_H_RD =>
            fsm <= S_H_RDW;

          when S_H_RDW =>
            acc_val <= signed(p_rdata);
            fsm     <= S_H_WR;

          -- w and w1 are DIFFERENT polynomials and both are needed: w for
          -- the wcs2 subtraction later in this iteration, w1 for the encode
          -- that feeds c_tilde. They are written to separate slots rather
          -- than one overwriting the other.
          when S_H_WR =>
            slot_a  <= SL_W + ii;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(acc_val);
            p_we    <= '1';
            fsm     <= S_H_W1;

          when S_H_W1 =>
            slot_a  <= SL_H + ii;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(
                         resize(signed('0' & dec_hi(canon_d(acc_val))),
                                C_CW));
            p_we    <= '1';
            fsm     <= S_H_NEXT;

          when S_H_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_H_ROW;
            else
              cnt      <= cnt + 1;
              slot_a   <= SL_TMP;
              p_raddr  <= std_logic_vector(to_unsigned(cnt + 1, 8));
              fsm      <= S_H_RD;
            end if;

          when S_H_ROW =>
            if ii = G_K - 1 then
              ii  <= 0;
              cnt <= 0;
              fsm <= S_HE_RUN;
            else
              ii  <= ii + 1;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_W_ZERO;
            end if;

          ----------------------------------------------------------------
          -- w1_encode: HighBits then pack at 4 bits, one row at a time
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
              ii <= 0;
              if G_STOP_AT = 2 then
                fsm <= S_DONE;
              else
                fsm <= S_C_MODE;
              end if;
            else
              ii  <= ii + 1;
              fsm <= S_HE_RUN;
            end if;

          ----------------------------------------------------------------
          -- c_tilde = SHAKE256(mu || w1_enc, 48)
          ----------------------------------------------------------------
          when S_C_MODE =>
            sp_mode <= "01";
            fsm     <= S_C_INIT;

          when S_C_INIT =>
            sp_init <= '1';
            fsm     <= S_C_INIT_P;

          when S_C_INIT_P =>
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
              if G_STOP_AT = 3 then
                fsm <= S_DONE;
              else
                fsm <= S_B_MODE;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_C_SQ;
            end if;

          ----------------------------------------------------------------
          -- c_hat = NTT(SampleInBall(c_tilde))
          ----------------------------------------------------------------
          when S_B_MODE =>
            sp_mode  <= "01";
            smp_mode <= "11";
            fsm      <= S_B_INIT;

          when S_B_INIT =>
            sp_init <= '1';
            fsm     <= S_B_INIT_P;

          when S_B_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_CT, 14));
              fsm     <= S_B_WAIT;
            end if;

          when S_B_WAIT =>
            fsm <= S_B_ABS;

          when S_B_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_B_ABSW;
            end if;

          when S_B_ABSW =>
            if cnt = 47 then
              fsm <= S_B_FIN;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_CT + cnt + 1, 14));
              fsm     <= S_B_WAIT;
            end if;

          when S_B_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_B_RUN;
            end if;

          when S_B_RUN =>
            if sp_dvalid = '1' then
              slot_a    <= SL_CH;
              smp_mode  <= "11";
              smp_start <= '1';
              fsm       <= S_B_NTT;
            end if;

          when S_B_NTT =>
            if smp_done = '1' then
              slot_a    <= SL_CH;
              ntt_op    <= "00";
              ntt_start <= '1';
              fsm       <= S_B_NTTW;
            end if;

          when S_B_NTTW =>
            if ntt_done = '1' then
              jj     <= 0;
              cnt    <= 0;
              cp_ret <= 0;
              fsm    <= S_CP_RD;
            end if;

          ----------------------------------------------------------------
          -- c_hat -> TMP, WITH THE R^2 LIFT APPLIED.
          --
          -- Two things happen in this copy and both are necessary. The
          -- pointwise product writes back over port A, so multiplying c_hat
          -- in place would destroy it after the first of the L + 2K products
          -- that need it. And exactly one operand of every product must
          -- carry the lift: s1_hat, s2_hat and t0_hat all come from
          -- ByteDecode and stay in the plain domain, so c_hat is the operand
          -- that carries it. Lifting here rather than in three separate
          -- places also means the lift is applied once per iteration instead
          -- of L + 2K times.
          ----------------------------------------------------------------
          when S_CP_RD =>
            slot_a  <= SL_CH;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_CP_RDW;

          when S_CP_RDW =>
            fsm <= S_CP_WR;

          when S_CP_WR =>
            p       := resize(signed(p_rdata) * to_signed(C_RD2, 24), 64);
            slot_a  <= SL_TMP;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(mont_d(p));
            p_we    <= '1';
            fsm     <= S_CP_NEXT;

          when S_CP_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              case cp_ret is
                when 0      => fsm <= S_Z_MUL;
                when 1      => fsm <= S_V_MUL;
                when others => fsm <= S_T_MUL;
              end case;
            else
              cnt <= cnt + 1;
              fsm <= S_CP_RD;
            end if;

          ----------------------------------------------------------------
          -- z[s] = y[s] + INTT(c_hat o s1_hat[s])
          ----------------------------------------------------------------
          -- The product operates in place on port A, so c_hat is copied
          -- into TMP first; SL_CH must survive for the next s and the next
          -- rejection check.
          when S_Z_MUL =>
            slot_a    <= SL_TMP;
            slot_b    <= SL_S1 + jj;
            ntt_op    <= "10";
            ntt_start <= '1';
            fsm       <= S_Z_MULW;

          when S_Z_MULW =>
            -- Observe done here and START THE INVERSE IN THE NEXT STATE.
            -- Issuing the start in this same state leaves ntt_done still
            -- asserted when the wait state is entered, so the wait falls
            -- through and the transform never runs: the product result is
            -- read back unchanged and every downstream value is silently
            -- wrong. The setup path had this right from the start.
            if ntt_done = '1' then
              fsm <= S_Z_INTT;
            end if;

          when S_Z_INTT =>
            slot_a    <= SL_TMP;
            ntt_op    <= "01";
            ntt_start <= '1';
            fsm       <= S_Z_INTTW;

          when S_Z_INTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_Z_RD;
            end if;

          when S_Z_RD =>
            slot_a   <= SL_Y + jj;
            p_raddr  <= std_logic_vector(to_unsigned(cnt, 8));
            slot_b   <= SL_TMP;
            p_braddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm      <= S_Z_RDW;

          when S_Z_RDW =>
            fsm <= S_Z_WR;

          when S_Z_WR =>
            slot_a  <= SL_Z + jj;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(
                         signed(p_rdata) + signed(p_brdata));
            p_we    <= '1';
            fsm     <= S_Z_NEXT;

          when S_Z_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_Z_SNEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_Z_RD;
            end if;

          when S_Z_SNEXT =>
            if jj = G_L - 1 then
              if G_STOP_AT = 4 then
                fsm <= S_DONE;
              else
                jj  <= 0;
                cnt <= 0;
                fsm <= S_ZC_RD;
              end if;
            else
              jj     <= jj + 1;
              cnt    <= 0;
              cp_ret <= 0;
              fsm    <= S_CP_RD;
            end if;

          ----------------------------------------------------------------
          -- rejection 1: ||z||inf >= GAMMA1 - BETA
          ----------------------------------------------------------------
          when S_ZC_RD =>
            slot_a  <= SL_Z + jj;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_ZC_RDW;

          when S_ZC_RDW =>
            fsm <= S_ZC_TEST;

          when S_ZC_TEST =>
            cv := signed(p_rdata);
            if absv(cv) >= to_signed(C_GAMMA1_DD - 196, C_CW) then
              fsm <= S_REJECT;
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
              ii     <= 0;
              cnt    <= 0;
              cp_ret <= 1;
              fsm    <= S_CP_RD;
            else
              jj  <= jj + 1;
              fsm <= S_ZC_RD;
            end if;

          ----------------------------------------------------------------
          -- wcs2[r] = w[r] - INTT(c_hat o s2_hat[r]), rejection 2
          ----------------------------------------------------------------
          when S_V_MUL =>
            slot_a    <= SL_TMP;
            slot_b    <= SL_S2 + ii;
            ntt_op    <= "10";
            ntt_start <= '1';
            fsm       <= S_V_MULW;

          when S_V_MULW =>
            -- Observe done here and START THE INVERSE IN THE NEXT STATE.
            -- Issuing the start in this same state leaves ntt_done still
            -- asserted when the wait state is entered, so the wait falls
            -- through and the transform never runs: the product result is
            -- read back unchanged and every downstream value is silently
            -- wrong. The setup path had this right from the start.
            if ntt_done = '1' then
              fsm <= S_V_INTT;
            end if;

          when S_V_INTT =>
            slot_a    <= SL_TMP;
            ntt_op    <= "01";
            ntt_start <= '1';
            fsm       <= S_V_INTTW;

          when S_V_INTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_V_RD;
            end if;

          when S_V_RD =>
            slot_a   <= SL_W + ii;
            p_raddr  <= std_logic_vector(to_unsigned(cnt, 8));
            slot_b   <= SL_TMP;
            p_braddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm      <= S_V_RDW;

          when S_V_RDW =>
            fsm <= S_V_WR;

          when S_V_WR =>
            slot_a  <= SL_W + ii;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(
                         signed(p_rdata) - signed(p_brdata));
            p_we    <= '1';
            fsm     <= S_V_NEXT;

          when S_V_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_V_RNEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_V_RD;
            end if;

          when S_V_RNEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              cnt <= 0;
              fsm <= S_VC_RD;
            else
              ii     <= ii + 1;
              cnt    <= 0;
              cp_ret <= 1;
              fsm    <= S_CP_RD;
            end if;

          when S_VC_RD =>
            slot_a  <= SL_W + ii;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_VC_RDW;

          when S_VC_RDW =>
            fsm <= S_VC_TEST;

          when S_VC_TEST =>
            cv := resize(dec_lo(canon_d(signed(p_rdata))), C_CW);
            if absv(cv) >= to_signed(C_GAMMA2_DD - 196, C_CW) then
              fsm <= S_REJECT;
            else
              fsm <= S_VC_NEXT;
            end if;

          when S_VC_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_VC_RNEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_VC_RD;
            end if;

          when S_VC_RNEXT =>
            if ii = G_K - 1 then
              ii     <= 0;
              cnt    <= 0;
              cp_ret <= 2;
              fsm    <= S_CP_RD;
            else
              ii  <= ii + 1;
              fsm <= S_VC_RD;
            end if;

          ----------------------------------------------------------------
          -- ct0[r] = INTT(c_hat o t0_hat[r]), rejection 3
          --
          -- This rejection is UNREACHABLE for any well-formed key:
          --   ||c*t0||inf <= TAU * 2^(D-1) = 49 * 4096 = 200704 < GAMMA2
          -- It is kept because it states the invariant and costs little, but
          -- no input exercises it and no mutation on it can be killed.
          ----------------------------------------------------------------
          when S_T_MUL =>
            slot_a    <= SL_TMP;
            slot_b    <= SL_T0 + ii;
            ntt_op    <= "10";
            ntt_start <= '1';
            fsm       <= S_T_MULW;

          when S_T_MULW =>
            -- Observe done here and START THE INVERSE IN THE NEXT STATE.
            -- Issuing the start in this same state leaves ntt_done still
            -- asserted when the wait state is entered, so the wait falls
            -- through and the transform never runs: the product result is
            -- read back unchanged and every downstream value is silently
            -- wrong. The setup path had this right from the start.
            if ntt_done = '1' then
              fsm <= S_T_INTT;
            end if;

          when S_T_INTT =>
            slot_a    <= SL_TMP;
            ntt_op    <= "01";
            ntt_start <= '1';
            fsm       <= S_T_INTTW;

          when S_T_INTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_TC_RD;
            end if;

          when S_TC_RD =>
            slot_a  <= SL_TMP;
            p_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_TC_RDW;

          when S_TC_RDW =>
            fsm <= S_TC_TEST;

          when S_TC_TEST =>
            cv := signed(p_rdata);
            if absv(cv) >= to_signed(C_GAMMA2_DD, C_CW) then
              fsm <= S_REJECT;
            else
              fsm <= S_TC_NEXT;
            end if;

          when S_TC_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_HH_RD;
            else
              cnt <= cnt + 1;
              fsm <= S_TC_RD;
            end if;

          when S_TC_RNEXT =>
            fsm <= S_HH_RD;

          ----------------------------------------------------------------
          -- hints and rejection 4
          ----------------------------------------------------------------
          when S_HH_RD =>
            slot_a   <= SL_TMP;
            p_raddr  <= std_logic_vector(to_unsigned(cnt, 8));
            slot_b   <= SL_W + ii;
            p_braddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm      <= S_HH_RDW;

          when S_HH_RDW =>
            fsm <= S_HH_WR;

          when S_HH_WR =>
            slot_a  <= SL_H + ii;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            if dec_hi(canon_d(signed(p_brdata))) /=
               dec_hi(canon_d(signed(p_brdata) + signed(p_rdata))) then
              p_wdata <= std_logic_vector(to_signed(1, C_CW));
              hw_cnt  <= hw_cnt + 1;
            else
              p_wdata <= (others => '0');
            end if;
            p_we <= '1';
            fsm  <= S_HH_NEXT;

          when S_HH_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_HH_RNEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_HH_RD;
            end if;

          when S_HH_RNEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              fsm <= S_HW_CHK;
            else
              ii     <= ii + 1;
              cnt    <= 0;
              cp_ret <= 2;
              fsm    <= S_CP_RD;
            end if;

          when S_HW_CHK =>
            if hw_cnt > C_OMEGA_D then
              fsm <= S_REJECT;
            else
              -- kappa advances on EVERY iteration, including the accepting
              -- one: the model consumes the base then adds L, so the final
              -- exposed value is n_iters * L. Incrementing only on reject
              -- reports (n_iters - 1) * L and fails the frozen vectors.
              kappa <= kappa + G_L;
              cnt   <= 0;
              fsm   <= S_SG_CT;
            end if;

          ----------------------------------------------------------------
          -- signature assembly
          ----------------------------------------------------------------
          when S_SG_CT =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_CT + cnt, 14));
            fsm     <= S_SG_CTS;

          -- The byte memory registers its output, so the datum for the
          -- address set in S_SG_CT is not stable until the following cycle.
          -- Reading it a cycle early copied the previous address's byte.
          when S_SG_CTS =>
            fsm <= S_SG_CTW;

          when S_SG_CTW =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_SG + cnt, 14));
            by_din  <= by_dout;
            by_we   <= '1';
            if cnt = 47 then
              cnt <= 0;
              jj  <= 0;
              fsm <= S_SG_Z;
            else
              cnt <= cnt + 1;
              fsm <= S_SG_CT;
            end if;

          when S_SG_Z =>
            slot_a    <= SL_Z + jj;
            cod_mode  <= "0100";
            cod_base  <= std_logic_vector(
                           to_unsigned(G_ADDR_SG + 48 + 640 * jj, 14));
            cod_start <= '1';
            fsm       <= S_SG_ZW;

          when S_SG_ZW =>
            if cod_done = '1' then
              fsm <= S_SG_ZNEXT;
            end if;

          when S_SG_ZNEXT =>
            if jj = G_L - 1 then
              fsm <= S_SG_H;
            else
              jj  <= jj + 1;
              fsm <= S_SG_Z;
            end if;

          when S_SG_H =>
            slot_a    <= SL_H;
            cod_mode  <= "0110";
            cod_base  <= std_logic_vector(
                           to_unsigned(G_ADDR_SG + 48 + 640 * G_L, 14));
            cod_start <= '1';
            fsm       <= S_SG_HW;

          when S_SG_HW =>
            if cod_done = '1' then
              fsm <= S_DONE;
            end if;

          ----------------------------------------------------------------
          -- rejection: advance kappa and start over. The iteration count is
          -- data-dependent by design, so there is no bound to enforce here.
          ----------------------------------------------------------------
          when S_REJECT =>
            kappa  <= kappa + G_L;
            iter   <= iter + 1;
            hw_cnt <= 0;
            jj     <= 0;
            ii     <= 0;
            cnt    <= 0;
            fsm    <= S_Y_MODE;

          when S_DONE =>
            busy_r <= '0';
            done_r <= '1';
            fsm    <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
