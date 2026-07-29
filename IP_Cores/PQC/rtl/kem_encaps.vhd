-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- kem_encaps: ML-KEM-768 Encaps, FIPS 203 Algorithms 14 and 17.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Byte map (13-bit space):
--   m      @   0  32 bytes, caller supplied
--   Kbar   @  32  32 bytes, shared secret out
--   r      @  64  32 bytes, PRF seed, second half of G
--   H(ek)  @  96  32 bytes
--   ek     @ 512  1184 bytes, caller supplied; rho lives at ek+1152
--   ct     @2048  1088 bytes out: c1 (u, d=10) then c2 (v, d=4) at 3008
--
-- Domain rules, per doc/DOMAIN_RULES.md, and all three are load bearing:
--
--  1. Exactly one basemul operand carries the R^2 lift, and here it is y_hat.
--     t_hat arrives from ByteDecode in the plain NTT domain and must NOT be
--     lifted. Lifting both leaves u CORRECT and corrupts only v, so the first
--     960 bytes of the ciphertext still match and only the last 128 differ.
--     Checkpoints EP4 and EP5 separate the two paths for exactly this reason.
--
--  2. A^T[i][j] uses seed bytes (i, j), the transpose of KeyGen's (j, i).
--     The loop indices are swapped at the sponge, not in the slot addressing.
--
--  3. SampleNTT output is already in the NTT domain and is never transformed.
--
-- Sequencing patterns carried over from KeyGen, where they accounted for most
-- of the bugs: the sponge mode is established one state before the init pulse;
-- every init is an unconditional single-cycle pulse followed by a separate
-- wait; every byte-memory read has an explicit settle state before the data is
-- sampled; and sp_re is driven through one explicit mux, never by two sources.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;
use work.ntt_tables_pkg.all;
use work.pqc_round_pkg.all;

entity kem_encaps is
  generic (
    G_K        : integer := 3;
    G_ADDR_M   : integer := 0;
    G_ADDR_KB  : integer := 32;
    G_ADDR_R   : integer := 64;
    G_ADDR_H   : integer := 96;
    G_ADDR_EK  : integer := 512;
    G_ADDR_CT  : integer := 2048;
    -- Halt after a named stage, for checkpoint inspection:
    --   0 run to completion
    --   1 after r is stored        2 after y_hat[0] is lifted
    --   3 after A^T[0][0]          4 after u[0] is complete
    --   5 after v is complete
    G_STOP_AT  : integer := 0);
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    start      : in  std_logic;
    done       : out std_logic;
    busy       : out std_logic;

    grant      : out integer range 0 to 4;
    slot_rd    : out integer range 0 to C_SLOTS - 1;
    slot_rd2   : out integer range 0 to C_SLOTS - 1;
    slot_wr    : out integer range 0 to C_SLOTS - 1;
    fsm_raddr  : out std_logic_vector(7 downto 0);
    fsm_rdata  : in  std_logic_vector(15 downto 0);
    fsm_waddr  : out std_logic_vector(7 downto 0);
    fsm_wdata  : out std_logic_vector(15 downto 0);
    fsm_we     : out std_logic;

    sp_mode    : out std_logic_vector(1 downto 0);
    sp_init    : out std_logic;
    sp_din     : out std_logic_vector(7 downto 0);
    sp_we      : out std_logic;
    sp_adone   : out std_logic;
    sp_dout    : in  std_logic_vector(7 downto 0);
    sp_re      : out std_logic;
    sp_dvalid  : in  std_logic;
    sp_ready   : in  std_logic;

    s1_start   : out std_logic;    -- SampleNTT
    s1_done    : in  std_logic;
    s2_start   : out std_logic;    -- SamplePolyCBD
    s2_done    : in  std_logic;
    samp_sel   : out std_logic;
    samp_run   : out std_logic;

    ntt_start  : out std_logic;
    ntt_inv    : out std_logic;
    ntt_done   : in  std_logic;

    bm_start   : out std_logic;
    bm_accum   : out std_logic;
    bm_done    : in  std_logic;

    -- codec_12 for ByteDecode of t_hat
    c12_start  : out std_logic;
    c12_decode : out std_logic;
    c12_base   : out std_logic_vector(12 downto 0);
    c12_done   : in  std_logic;

    -- codec_ct for the compressed ciphertext
    cct_start  : out std_logic;
    cct_decode : out std_logic;
    cct_dsel   : out std_logic_vector(1 downto 0);
    cct_base   : out std_logic_vector(12 downto 0);
    cct_done   : in  std_logic;

    by_addr    : out std_logic_vector(12 downto 0);
    by_din     : out std_logic_vector(7 downto 0);
    by_we      : out std_logic;
    by_dout    : in  std_logic_vector(7 downto 0));
end entity kem_encaps;

architecture rtl of kem_encaps is

  type t_fsm is (
    S_IDLE,
    -- H(ek)
    S_H_MODE, S_H_INIT, S_H_INIT_P, S_H_WAIT, S_H_ABS, S_H_ABSW, S_H_FIN,
    S_H_SQ, S_H_SQW, S_H_SQ2,
    -- G(m || H(ek))
    S_G_MODE, S_G_INIT, S_G_INIT_P, S_G_MWAIT, S_G_MABS, S_G_MABSW,
    S_G_HWAIT, S_G_HABS, S_G_HABSW, S_G_FIN, S_G_SQ, S_G_SQW, S_G_SQ2,
    -- t_hat = ByteDecode12(ek)
    S_TD_RUN, S_TD_WAIT, S_TD_NEXT,
    -- y, then NTT, then lift into YH
    S_Y_MODE, S_Y_INIT, S_Y_INIT_P, S_Y_WAIT, S_Y_ABS, S_Y_ABSW, S_Y_NONCE,
    S_Y_FIN, S_Y_RUN, S_Y_NTT, S_Y_NTTW,
    S_YL_RD, S_YL_RDW, S_YL_WR, S_YL_NEXT, S_Y_NEXT,
    -- e1 and e2
    S_E_MODE, S_E_INIT, S_E_INIT_P, S_E_WAIT, S_E_ABS, S_E_ABSW, S_E_NONCE,
    S_E_FIN, S_E_RUN, S_E_DONE1, S_E_NEXT,
    -- u = INTT(A^T o y_hat) + e1
    S_U_ZERO, S_U_AMODE, S_U_AINIT, S_U_AINIT_P, S_U_AWAIT, S_U_AABS,
    S_U_AABSW, S_U_AIDX1, S_U_AIDX2, S_U_AFIN, S_U_ARUN, S_U_BMUL,
    S_U_BMULW, S_U_JNEXT, S_U_INTT, S_U_INTTW,
    S_U_ADD_RD, S_U_ADD_RDW, S_U_ADD_RD2, S_U_ADD_RD2W, S_U_ADD_WR,
    S_U_ADD_NEXT, S_U_INEXT,
    -- v = INTT(t_hat o y_hat) + e2 + Decompress1(m)
    S_V_ZERO, S_V_BMUL, S_V_BMULW, S_V_JNEXT, S_V_INTT, S_V_INTTW,
    S_V_MRD, S_V_MRDW, S_V_ADD_RD, S_V_ADD_RDW, S_V_ADD_RD2, S_V_ADD_RD2W,
    S_V_ADD_WR, S_V_ADD_NEXT,
    -- ciphertext
    S_C1_RUN, S_C1_WAIT, S_C1_NEXT, S_C2_RUN, S_C2_WAIT,
    S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal ii    : integer range 0 to 8 := 0;
  signal jj    : integer range 0 to 8 := 0;
  signal cnt   : integer range 0 to 4095 := 0;
  signal nonce : integer range 0 to 15 := 0;

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  signal acc_val : signed(15 downto 0) := (others => '0');
  -- one byte of the message, held while its eight bits are expanded
  signal mbyte   : unsigned(7 downto 0) := (others => '0');

  constant C_R2 : integer := 1353;

  function mont16 (a : signed) return signed is
    variable lo   : signed(16 downto 0);
    variable t    : signed(16 downto 0);
    variable prod : signed(a'length + 17 downto 0);
    variable num  : signed(a'length + 17 downto 0);
  begin
    lo   := resize(signed(a(15 downto 0)), 17);
    t    := resize(lo * to_signed(C_QINVK, 18), 17);
    t    := resize(signed(t(15 downto 0)), 17);
    prod := resize(t * to_signed(work.ntt_tables_pkg.C_QK, 18), prod'length);
    num  := resize(a, num'length) - prod;
    return resize(shift_right(num, 16), 16);
  end function mont16;

  function range_reduce (x : signed(15 downto 0)) return signed is
    variable v : signed(15 downto 0);
  begin
    v := x;
    if v >= to_signed(work.ntt_tables_pkg.C_QK, 16) then
      v := v - to_signed(2 * work.ntt_tables_pkg.C_QK, 16);
    elsif v < -to_signed(work.ntt_tables_pkg.C_QK, 16) then
      v := v + to_signed(2 * work.ntt_tables_pkg.C_QK, 16);
    end if;
    return v;
  end function range_reduce;

begin

  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable p    : signed(31 downto 0);
    variable bitv : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm        <= S_IDLE;
        busy_r     <= '0';
        done_r     <= '0';
        grant      <= C_CLI_NONE;
        slot_rd    <= 0;
        slot_rd2   <= 0;
        slot_wr    <= 0;
        fsm_we     <= '0';
        fsm_raddr  <= (others => '0');
        fsm_waddr  <= (others => '0');
        fsm_wdata  <= (others => '0');
        sp_init    <= '0';
        sp_we      <= '0';
        sp_adone   <= '0';
        sp_re      <= '0';
        sp_din     <= (others => '0');
        sp_mode    <= "00";
        s1_start   <= '0';
        s2_start   <= '0';
        samp_sel   <= '0';
        samp_run   <= '0';
        ntt_start  <= '0';
        ntt_inv    <= '0';
        bm_start   <= '0';
        bm_accum   <= '0';
        c12_start  <= '0';
        c12_decode <= '0';
        c12_base   <= (others => '0');
        cct_start  <= '0';
        cct_decode <= '0';
        cct_dsel   <= "00";
        cct_base   <= (others => '0');
        by_addr    <= (others => '0');
        by_din     <= (others => '0');
        by_we      <= '0';
        ii         <= 0;
        jj         <= 0;
        cnt        <= 0;
        nonce      <= 0;
      else
        done_r    <= '0';
        fsm_we    <= '0';
        sp_init   <= '0';
        sp_we     <= '0';
        sp_adone  <= '0';
        sp_re     <= '0';
        s1_start  <= '0';
        s2_start  <= '0';
        ntt_start <= '0';
        bm_start  <= '0';
        c12_start <= '0';
        cct_start <= '0';
        by_we     <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r <= '1';
              cnt    <= 0;
              ii     <= 0;
              jj     <= 0;
              nonce  <= 0;
              fsm    <= S_H_MODE;
            end if;

          ----------------------------------------------------------------
          -- H(ek), stored at G_ADDR_H
          ----------------------------------------------------------------
          when S_H_MODE =>
            sp_mode <= "10";                 -- SHA3-256
            fsm     <= S_H_INIT;

          when S_H_INIT =>
            sp_init <= '1';
            fsm     <= S_H_INIT_P;

          when S_H_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_EK, 13));
              fsm     <= S_H_WAIT;
            end if;

          when S_H_WAIT =>
            fsm <= S_H_ABS;

          when S_H_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_H_ABSW;
            end if;

          when S_H_ABSW =>
            if cnt = 384 * G_K + 32 - 1 then
              fsm <= S_H_FIN;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_EK + cnt + 1, 13));
              fsm     <= S_H_WAIT;
            end if;

          when S_H_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_H_SQ;
            end if;

          when S_H_SQ =>
            if sp_dvalid = '1' then
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_H + cnt, 13));
              by_din  <= sp_dout;
              by_we   <= '1';
              sp_re   <= '1';
              fsm     <= S_H_SQW;
            end if;

          when S_H_SQW =>
            fsm <= S_H_SQ2;

          when S_H_SQ2 =>
            if cnt = 31 then
              cnt <= 0;
              fsm <= S_G_MODE;
            else
              cnt <= cnt + 1;
              fsm <= S_H_SQ;
            end if;

          ----------------------------------------------------------------
          -- G(m || H(ek)) -> Kbar || r
          -- m and H are not adjacent in memory, so this is two address runs.
          ----------------------------------------------------------------
          when S_G_MODE =>
            sp_mode <= "11";                 -- SHA3-512
            fsm     <= S_G_INIT;

          when S_G_INIT =>
            sp_init <= '1';
            fsm     <= S_G_INIT_P;

          when S_G_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_M, 13));
              fsm     <= S_G_MWAIT;
            end if;

          when S_G_MWAIT =>
            fsm <= S_G_MABS;

          when S_G_MABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_G_MABSW;
            end if;

          when S_G_MABSW =>
            if cnt = 31 then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_H, 13));
              fsm     <= S_G_HWAIT;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_M + cnt + 1, 13));
              fsm     <= S_G_MWAIT;
            end if;

          when S_G_HWAIT =>
            fsm <= S_G_HABS;

          when S_G_HABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_G_HABSW;
            end if;

          when S_G_HABSW =>
            if cnt = 31 then
              fsm <= S_G_FIN;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_H + cnt + 1, 13));
              fsm     <= S_G_HWAIT;
            end if;

          when S_G_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_G_SQ;
            end if;

          -- first 32 squeezed bytes are Kbar, next 32 are r
          when S_G_SQ =>
            if sp_dvalid = '1' then
              if cnt < 32 then
                by_addr <= std_logic_vector(
                             to_unsigned(G_ADDR_KB + cnt, 13));
              else
                by_addr <= std_logic_vector(
                             to_unsigned(G_ADDR_R + cnt - 32, 13));
              end if;
              by_din <= sp_dout;
              by_we  <= '1';
              sp_re  <= '1';
              fsm    <= S_G_SQW;
            end if;

          when S_G_SQW =>
            fsm <= S_G_SQ2;

          when S_G_SQ2 =>
            if cnt = 63 then
              cnt <= 0;
              ii  <= 0;
              if G_STOP_AT = 1 then
                fsm <= S_DONE;
              else
                fsm <= S_TD_RUN;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_G_SQ;
            end if;

          ----------------------------------------------------------------
          -- t_hat[i] = ByteDecode12(ek + 384*i), plain NTT domain
          ----------------------------------------------------------------
          when S_TD_RUN =>
            grant      <= C_CLI_FSM;
            slot_wr    <= C_SLOT_T + ii;
            c12_decode <= '1';
            c12_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_EK + 384 * ii, 13));
            c12_start  <= '1';
            fsm        <= S_TD_WAIT;

          when S_TD_WAIT =>
            if c12_done = '1' then
              fsm <= S_TD_NEXT;
            end if;

          when S_TD_NEXT =>
            if ii = G_K - 1 then
              ii    <= 0;
              nonce <= 0;
              fsm   <= S_Y_MODE;
            else
              ii  <= ii + 1;
              fsm <= S_TD_RUN;
            end if;

          ----------------------------------------------------------------
          -- y[n] = CBD(PRF(r, n)), NTT, then lift by R^2 into YH
          ----------------------------------------------------------------
          when S_Y_MODE =>
            sp_mode  <= "01";                -- SHAKE256
            samp_sel <= '1';                 -- CBD
            fsm      <= S_Y_INIT;

          when S_Y_INIT =>
            sp_init <= '1';
            fsm     <= S_Y_INIT_P;

          when S_Y_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_R, 13));
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
            if cnt = 31 then
              fsm <= S_Y_NONCE;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_R + cnt + 1, 13));
              fsm     <= S_Y_WAIT;
            end if;

          when S_Y_NONCE =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(nonce, 8));
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
              grant    <= C_CLI_SAMP;
              slot_wr  <= C_SLOT_Y + nonce;
              samp_run <= '1';
              s2_start <= '1';
              fsm      <= S_Y_NTT;
            end if;

          when S_Y_NTT =>
            if s2_done = '1' then
              samp_run  <= '0';
              grant     <= C_CLI_NTT;
              slot_rd   <= C_SLOT_Y + nonce;
              slot_wr   <= C_SLOT_Y + nonce;
              ntt_inv   <= '0';
              ntt_start <= '1';
              fsm       <= S_Y_NTTW;
            end if;

          when S_Y_NTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_YL_RD;
            end if;

          -- lift into YH, leaving Y itself untouched
          when S_YL_RD =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_Y + nonce;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_YL_RDW;

          when S_YL_RDW =>
            fsm <= S_YL_WR;

          when S_YL_WR =>
            p         := signed(fsm_rdata) * to_signed(C_R2, 16);
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_YH + nonce;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= std_logic_vector(mont16(p));
            fsm_we    <= '1';
            fsm       <= S_YL_NEXT;

          when S_YL_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_Y_NEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_YL_RD;
            end if;

          when S_Y_NEXT =>
            if nonce = G_K - 1 then
              nonce <= G_K;
              if G_STOP_AT = 2 then
                fsm <= S_DONE;
              else
                fsm <= S_E_MODE;
              end if;
            else
              nonce <= nonce + 1;
              fsm   <= S_Y_MODE;
            end if;

          ----------------------------------------------------------------
          -- e1[0..K-1] and e2, nonces K .. 2K
          ----------------------------------------------------------------
          when S_E_MODE =>
            sp_mode  <= "01";
            samp_sel <= '1';
            fsm      <= S_E_INIT;

          when S_E_INIT =>
            sp_init <= '1';
            fsm     <= S_E_INIT_P;

          when S_E_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_R, 13));
              fsm     <= S_E_WAIT;
            end if;

          when S_E_WAIT =>
            fsm <= S_E_ABS;

          when S_E_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_E_ABSW;
            end if;

          when S_E_ABSW =>
            if cnt = 31 then
              fsm <= S_E_NONCE;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_R + cnt + 1, 13));
              fsm     <= S_E_WAIT;
            end if;

          when S_E_NONCE =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(nonce, 8));
              sp_we  <= '1';
              fsm    <= S_E_FIN;
            end if;

          when S_E_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_E_RUN;
            end if;

          when S_E_RUN =>
            if sp_dvalid = '1' then
              grant    <= C_CLI_SAMP;
              if nonce < 2 * G_K then
                slot_wr <= C_SLOT_E1 + (nonce - G_K);
              else
                slot_wr <= C_SLOT_E2;
              end if;
              samp_run <= '1';
              s2_start <= '1';
              fsm      <= S_E_DONE1;
            end if;

          when S_E_DONE1 =>
            if s2_done = '1' then
              samp_run <= '0';
              fsm      <= S_E_NEXT;
            end if;

          when S_E_NEXT =>
            if nonce = 2 * G_K then
              ii  <= 0;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_U_ZERO;
            else
              nonce <= nonce + 1;
              fsm   <= S_E_MODE;
            end if;

          ----------------------------------------------------------------
          -- u[i] = INTT(sum_j A^T[i][j] o y_hat[j]) + e1[i]
          ----------------------------------------------------------------
          when S_U_ZERO =>
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_TMP;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= (others => '0');
            fsm_we    <= '1';
            if cnt = 255 then
              cnt <= 0;
              jj  <= 0;
              fsm <= S_U_AMODE;
            else
              cnt <= cnt + 1;
            end if;

          when S_U_AMODE =>
            sp_mode  <= "00";                -- SHAKE128
            samp_sel <= '0';                 -- SampleNTT
            fsm      <= S_U_AINIT;

          when S_U_AINIT =>
            sp_init <= '1';
            fsm     <= S_U_AINIT_P;

          when S_U_AINIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              -- rho lives inside ek, at offset 384*K
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_EK + 384 * G_K, 13));
              fsm     <= S_U_AWAIT;
            end if;

          when S_U_AWAIT =>
            fsm <= S_U_AABS;

          when S_U_AABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_U_AABSW;
            end if;

          when S_U_AABSW =>
            if cnt = 31 then
              fsm <= S_U_AIDX1;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_EK + 384 * G_K + cnt + 1, 13));
              fsm     <= S_U_AWAIT;
            end if;

          -- transposed: A^T[i][j] uses seed bytes (i, j)
          when S_U_AIDX1 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(ii, 8));
              sp_we  <= '1';
              fsm    <= S_U_AIDX2;
            end if;

          when S_U_AIDX2 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(jj, 8));
              sp_we  <= '1';
              fsm    <= S_U_AFIN;
            end if;

          when S_U_AFIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_U_ARUN;
            end if;

          when S_U_ARUN =>
            if sp_dvalid = '1' then
              grant    <= C_CLI_SAMP;
              slot_wr  <= C_SLOT_A;
              samp_run <= '1';
              s1_start <= '1';
              fsm      <= S_U_BMUL;
            end if;

          when S_U_BMUL =>
            if s1_done = '1' then
              samp_run <= '0';
              if G_STOP_AT = 3 and ii = 0 and jj = 0 then
                fsm <= S_DONE;
              else
                grant    <= C_CLI_BMUL;
                slot_rd  <= C_SLOT_A;
                slot_rd2 <= C_SLOT_YH + jj;   -- lifted y_hat
                slot_wr  <= C_SLOT_TMP;
                bm_accum <= '1';
                bm_start <= '1';
                fsm      <= S_U_BMULW;
              end if;
            end if;

          when S_U_BMULW =>
            if bm_done = '1' then
              fsm <= S_U_JNEXT;
            end if;

          when S_U_JNEXT =>
            if jj = G_K - 1 then
              fsm <= S_U_INTT;
            else
              jj  <= jj + 1;
              fsm <= S_U_AMODE;
            end if;

          when S_U_INTT =>
            grant     <= C_CLI_NTT;
            slot_rd   <= C_SLOT_TMP;
            slot_wr   <= C_SLOT_TMP;
            ntt_inv   <= '1';
            ntt_start <= '1';
            fsm       <= S_U_INTTW;

          when S_U_INTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_U_ADD_RD;
            end if;

          when S_U_ADD_RD =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_TMP;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_U_ADD_RDW;

          when S_U_ADD_RDW =>
            fsm <= S_U_ADD_RD2;

          when S_U_ADD_RD2 =>
            acc_val   <= signed(fsm_rdata);
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_E1 + ii;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_U_ADD_RD2W;

          when S_U_ADD_RD2W =>
            fsm <= S_U_ADD_WR;

          when S_U_ADD_WR =>
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_U + ii;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= std_logic_vector(
                           range_reduce(acc_val + signed(fsm_rdata)));
            fsm_we    <= '1';
            fsm       <= S_U_ADD_NEXT;

          when S_U_ADD_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_U_INEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_U_ADD_RD;
            end if;

          when S_U_INEXT =>
            if ii = G_K - 1 then
              if G_STOP_AT = 4 then
                fsm <= S_DONE;
              else
                ii  <= 0;
                jj  <= 0;
                cnt <= 0;
                fsm <= S_V_ZERO;
              end if;
            elsif G_STOP_AT = 4 and ii = 0 then
              -- halt with u[0] complete, before it is overwritten
              fsm <= S_DONE;
            else
              ii  <= ii + 1;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_U_ZERO;
            end if;

          ----------------------------------------------------------------
          -- v = INTT(sum_j t_hat[j] o y_hat[j]) + e2 + Decompress1(m)
          -- t_hat is NOT lifted here: y_hat already carries the R factor.
          ----------------------------------------------------------------
          when S_V_ZERO =>
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_TMP;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= (others => '0');
            fsm_we    <= '1';
            if cnt = 255 then
              cnt <= 0;
              jj  <= 0;
              fsm <= S_V_BMUL;
            else
              cnt <= cnt + 1;
            end if;

          when S_V_BMUL =>
            grant    <= C_CLI_BMUL;
            slot_rd  <= C_SLOT_T + jj;      -- plain domain, no lift
            slot_rd2 <= C_SLOT_YH + jj;     -- lifted
            slot_wr  <= C_SLOT_TMP;
            bm_accum <= '1';
            bm_start <= '1';
            fsm      <= S_V_BMULW;

          when S_V_BMULW =>
            if bm_done = '1' then
              fsm <= S_V_JNEXT;
            end if;

          when S_V_JNEXT =>
            if jj = G_K - 1 then
              fsm <= S_V_INTT;
            else
              jj  <= jj + 1;
              fsm <= S_V_BMUL;
            end if;

          when S_V_INTT =>
            grant     <= C_CLI_NTT;
            slot_rd   <= C_SLOT_TMP;
            slot_wr   <= C_SLOT_TMP;
            ntt_inv   <= '1';
            ntt_start <= '1';
            fsm       <= S_V_INTTW;

          when S_V_INTTW =>
            if ntt_done = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_M, 13));
              fsm     <= S_V_MRD;
            end if;

          -- Decompress_1 of the message bit, folded into the accumulate loop:
          -- one message byte covers eight coefficients.
          when S_V_MRD =>
            fsm <= S_V_MRDW;

          when S_V_MRDW =>
            mbyte <= unsigned(by_dout);
            fsm   <= S_V_ADD_RD;

          when S_V_ADD_RD =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_TMP;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_V_ADD_RDW;

          when S_V_ADD_RDW =>
            fsm <= S_V_ADD_RD2;

          when S_V_ADD_RD2 =>
            acc_val   <= signed(fsm_rdata);
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_E2;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_V_ADD_RD2W;

          when S_V_ADD_RD2W =>
            fsm <= S_V_ADD_WR;

          when S_V_ADD_WR =>
            -- Decompress_1 of one message bit: indexing an unsigned yields a
            -- single bit, so test it rather than converting it.
            if mbyte(cnt mod 8) = '1' then
              bitv := 1;
            else
              bitv := 0;
            end if;
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_V;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= std_logic_vector(
                           range_reduce(acc_val + signed(fsm_rdata) +
                             to_signed(decompress_k(1, bitv), 16)));
            fsm_we    <= '1';
            fsm       <= S_V_ADD_NEXT;

          when S_V_ADD_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              ii  <= 0;
              if G_STOP_AT = 5 then
                fsm <= S_DONE;
              else
                fsm <= S_C1_RUN;
              end if;
            else
              cnt <= cnt + 1;
              if (cnt + 1) mod 8 = 0 then
                -- next message byte
                by_addr <= std_logic_vector(
                             to_unsigned(G_ADDR_M + (cnt + 1) / 8, 13));
                fsm     <= S_V_MRD;
              else
                fsm <= S_V_ADD_RD;
              end if;
            end if;

          ----------------------------------------------------------------
          -- ciphertext: c1 = Compress10(u), c2 = Compress4(v)
          ----------------------------------------------------------------
          when S_C1_RUN =>
            grant      <= C_CLI_FSM;
            slot_rd    <= C_SLOT_U + ii;
            cct_decode <= '0';
            cct_dsel   <= "00";               -- d = 10
            cct_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_CT + 320 * ii, 13));
            cct_start  <= '1';
            fsm        <= S_C1_WAIT;

          when S_C1_WAIT =>
            if cct_done = '1' then
              fsm <= S_C1_NEXT;
            end if;

          when S_C1_NEXT =>
            if ii = G_K - 1 then
              fsm <= S_C2_RUN;
            else
              ii  <= ii + 1;
              fsm <= S_C1_RUN;
            end if;

          when S_C2_RUN =>
            grant      <= C_CLI_FSM;
            slot_rd    <= C_SLOT_V;
            cct_decode <= '0';
            cct_dsel   <= "01";              -- d = 4
            cct_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_CT + 320 * G_K, 13));
            cct_start  <= '1';
            fsm        <= S_C2_WAIT;

          when S_C2_WAIT =>
            if cct_done = '1' then
              fsm <= S_DONE;
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
