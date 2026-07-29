-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- kem_decaps: ML-KEM-768 Decaps, FIPS 203 Algorithms 15 and 18.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Decaps is decrypt, then re-encrypt, then a constant-time select:
--
--   A  m2 = KPKE.Decrypt(dk_pke, c)
--   B  (K2, r2) = G(m2 || h),  c2 = KPKE.Encrypt(ek_pke, m2, r2)
--   C  Kbar = J(z || c);  output K2 if c2 = c, else Kbar
--
-- Byte map (13-bit space):
--   c      @   0  1088 bytes, caller supplied
--   m2     @1152  32 bytes, recovered message
--   K2     @1184  32 bytes, candidate shared secret
--   r2     @1216  32 bytes, re-encryption PRF seed
--   Kbar   @1248  32 bytes, implicit rejection secret
--   Kout   @1280  32 bytes, selected output
--   dk     @2048  2400 bytes: dk_pke, then ek_pke at +1152, h at +2336,
--                 z at +2368
--   c2     @4608  1088 bytes, re-encrypted ciphertext
--
-- Constant-time requirements, and both are load bearing:
--
--  1. The comparison accumulates the OR of per-byte differences across all
--     1088 bytes with no early exit, so the running time carries no
--     information about where or whether the ciphertexts differ.
--
--  2. The final selection is a bitwise mask, not a branch. Both candidate
--     secrets are computed unconditionally and one is masked out, so the
--     rejection path and the acceptance path execute the same instructions.
--
-- The lift rule: exactly one basemul operand carries R^2. Here it is s_hat,
-- matching KeyGen. Unlike Encaps, where only y_hat is admissible because
-- t_hat arrives in the plain domain, in the decrypt product either operand
-- would serve, so the choice follows the existing convention.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;
use work.ntt_tables_pkg.all;
use work.pqc_round_pkg.all;

entity kem_decaps is
  generic (
    G_K        : integer := 3;
    G_ADDR_C   : integer := 0;
    G_ADDR_M2  : integer := 1152;
    G_ADDR_K2  : integer := 1184;
    G_ADDR_R2  : integer := 1216;
    G_ADDR_KB  : integer := 1248;
    G_ADDR_KO  : integer := 1280;
    G_ADDR_DK  : integer := 2048;
    G_ADDR_C2  : integer := 4608;
    -- Halt after a named stage, for checkpoint inspection:
    --   0 run to completion     1 after u[0] is decompressed
    --   2 after v is decompressed
    --   3 after w = v - INTT(s o u)
    --   4 after m2 is written
    G_STOP_AT  : integer := 0);
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    start      : in  std_logic;
    done       : out std_logic;
    busy       : out std_logic;
    rejected   : out std_logic;   -- observability only, not a control path

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

    s1_start   : out std_logic;
    s1_done    : in  std_logic;
    s2_start   : out std_logic;
    s2_done    : in  std_logic;
    samp_sel   : out std_logic;
    samp_run   : out std_logic;

    ntt_start  : out std_logic;
    ntt_inv    : out std_logic;
    ntt_done   : in  std_logic;

    bm_start   : out std_logic;
    bm_accum   : out std_logic;
    bm_done    : in  std_logic;

    c12_start  : out std_logic;
    c12_decode : out std_logic;
    c12_base   : out std_logic_vector(12 downto 0);
    c12_done   : in  std_logic;

    cct_start  : out std_logic;
    cct_decode : out std_logic;
    cct_dsel   : out std_logic_vector(1 downto 0);
    cct_base   : out std_logic_vector(12 downto 0);
    cct_done   : in  std_logic;

    by_addr    : out std_logic_vector(12 downto 0);
    by_din     : out std_logic_vector(7 downto 0);
    by_we      : out std_logic;
    by_dout    : in  std_logic_vector(7 downto 0));
end entity kem_decaps;

architecture rtl of kem_decaps is

  type t_fsm is (
    S_IDLE,
    -- phase A: decrypt
    S_DU_RUN, S_DU_WAIT, S_DU_NEXT,
    S_DV_RUN, S_DV_WAIT,
    S_DS_RUN, S_DS_WAIT, S_DS_NEXT,
    S_SL_RD, S_SL_RDW, S_SL_WR, S_SL_NEXT,
    S_UN_START, S_UN_WAIT, S_UN_NEXT,
    S_AZERO, S_ABMUL, S_ABMULW, S_AJNEXT, S_AINTT, S_AINTTW,
    S_W_RD, S_W_RDW, S_W_RD2, S_W_RD2W, S_W_WR, S_W_NEXT,
    S_M2_RUN, S_M2_WAIT,
    -- phase B: re-encrypt, mirroring Encaps
    S_G_MODE, S_G_INIT, S_G_INIT_P, S_G_MWAIT, S_G_MABS, S_G_MABSW,
    S_G_HWAIT, S_G_HABS, S_G_HABSW, S_G_FIN, S_G_SQ, S_G_SQW, S_G_SQ2,
    S_TD_RUN, S_TD_WAIT, S_TD_NEXT,
    S_Y_MODE, S_Y_INIT, S_Y_INIT_P, S_Y_WAIT, S_Y_ABS, S_Y_ABSW, S_Y_NONCE,
    S_Y_FIN, S_Y_RUN, S_Y_NTT, S_Y_NTTW,
    S_YL_RD, S_YL_RDW, S_YL_WR, S_YL_NEXT, S_Y_NEXT,
    S_E_MODE, S_E_INIT, S_E_INIT_P, S_E_WAIT, S_E_ABS, S_E_ABSW, S_E_NONCE,
    S_E_FIN, S_E_RUN, S_E_DONE1, S_E_NEXT,
    S_U_ZERO, S_U_AMODE, S_U_AINIT, S_U_AINIT_P, S_U_AWAIT, S_U_AABS,
    S_U_AABSW, S_U_AIDX1, S_U_AIDX2, S_U_AFIN, S_U_ARUN, S_U_BMUL,
    S_U_BMULW, S_U_JNEXT, S_U_INTT, S_U_INTTW,
    S_U_ADD_RD, S_U_ADD_RDW, S_U_ADD_RD2, S_U_ADD_RD2W, S_U_ADD_WR,
    S_U_ADD_NEXT, S_U_INEXT,
    S_V_ZERO, S_V_BMUL, S_V_BMULW, S_V_JNEXT, S_V_INTT, S_V_INTTW,
    S_V_MRD, S_V_MRDW, S_V_ADD_RD, S_V_ADD_RDW, S_V_ADD_RD2, S_V_ADD_RD2W,
    S_V_ADD_WR, S_V_ADD_NEXT,
    S_C1_RUN, S_C1_WAIT, S_C1_NEXT, S_C2_RUN, S_C2_WAIT,
    -- phase C: Kbar, constant-time compare, masked select
    S_KB_MODE, S_KB_INIT, S_KB_INIT_P, S_KB_ZWAIT, S_KB_ZABS, S_KB_ZABSW,
    S_KB_CWAIT, S_KB_CABS, S_KB_CABSW, S_KB_FIN, S_KB_SQ, S_KB_SQW, S_KB_SQ2,
    S_CMP_A, S_CMP_AW, S_CMP_B, S_CMP_BW, S_CMP_NEXT,
    S_SEL_RD, S_SEL_RDW, S_SEL_RD2, S_SEL_RD2W, S_SEL_WR, S_SEL_NEXT,
    S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal ii    : integer range 0 to 8 := 0;
  signal jj    : integer range 0 to 8 := 0;
  signal cnt   : integer range 0 to 4095 := 0;
  signal nonce : integer range 0 to 15 := 0;

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  signal acc_val : signed(15 downto 0) := (others => '0');
  signal mbyte   : unsigned(7 downto 0) := (others => '0');
  signal tmp_b   : unsigned(7 downto 0) := (others => '0');

  -- Accumulated difference between c and c2. Every byte pair contributes,
  -- with no early exit, so the loop length is independent of the data.
  signal diff_acc : unsigned(7 downto 0) := (others => '0');
  -- All ones when the ciphertexts matched, all zeros otherwise. Used as a
  -- bitwise mask so the selection is branchless.
  signal keep_msk : unsigned(7 downto 0) := (others => '0');

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
        rejected   <= '0';
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
        diff_acc   <= (others => '0');
        keep_msk   <= (others => '0');
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
              busy_r   <= '1';
              cnt      <= 0;
              ii       <= 0;
              jj       <= 0;
              nonce    <= 0;
              diff_acc <= (others => '0');
              fsm      <= S_DU_RUN;
            end if;

          ----------------------------------------------------------------
          -- A1: u[i] = Decompress10(ByteDecode10(c1))
          ----------------------------------------------------------------
          when S_DU_RUN =>
            grant      <= C_CLI_FSM;
            slot_wr    <= C_SLOT_U + ii;
            cct_decode <= '1';
            cct_dsel   <= "00";
            cct_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_C + 320 * ii, 13));
            cct_start  <= '1';
            fsm        <= S_DU_WAIT;

          when S_DU_WAIT =>
            if cct_done = '1' then
              fsm <= S_DU_NEXT;
            end if;

          when S_DU_NEXT =>
            if ii = G_K - 1 then
              ii <= 0;
              if G_STOP_AT = 1 then
                fsm <= S_DONE;
              else
                fsm <= S_DV_RUN;
              end if;
            elsif G_STOP_AT = 1 and ii = 0 then
              fsm <= S_DONE;
            else
              ii  <= ii + 1;
              fsm <= S_DU_RUN;
            end if;

          ----------------------------------------------------------------
          -- A2: v = Decompress4(ByteDecode4(c2))
          ----------------------------------------------------------------
          when S_DV_RUN =>
            grant      <= C_CLI_FSM;
            slot_wr    <= C_SLOT_V;
            cct_decode <= '1';
            cct_dsel   <= "01";
            cct_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_C + 320 * G_K, 13));
            cct_start  <= '1';
            fsm        <= S_DV_WAIT;

          when S_DV_WAIT =>
            if cct_done = '1' then
              if G_STOP_AT = 2 then
                fsm <= S_DONE;
              else
                ii  <= 0;
                fsm <= S_DS_RUN;
              end if;
            end if;

          ----------------------------------------------------------------
          -- A3: s_hat[i] = ByteDecode12(dk_pke)
          ----------------------------------------------------------------
          when S_DS_RUN =>
            grant      <= C_CLI_FSM;
            slot_wr    <= C_SLOT_S + ii;
            c12_decode <= '1';
            c12_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_DK + 384 * ii, 13));
            c12_start  <= '1';
            fsm        <= S_DS_WAIT;

          when S_DS_WAIT =>
            if c12_done = '1' then
              fsm <= S_DS_NEXT;
            end if;

          when S_DS_NEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              cnt <= 0;
              fsm <= S_SL_RD;
            else
              ii  <= ii + 1;
              fsm <= S_DS_RUN;
            end if;

          -- lift s_hat into YH; s_hat itself is not needed unlifted here,
          -- but keeping the lift out of place matches the KeyGen convention
          when S_SL_RD =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_S + ii;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_SL_RDW;

          when S_SL_RDW =>
            fsm <= S_SL_WR;

          when S_SL_WR =>
            p         := signed(fsm_rdata) * to_signed(C_R2, 16);
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_YH + ii;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= std_logic_vector(mont16(p));
            fsm_we    <= '1';
            fsm       <= S_SL_NEXT;

          when S_SL_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              if ii = G_K - 1 then
                ii  <= 0;
                fsm <= S_UN_START;
              else
                ii  <= ii + 1;
                fsm <= S_SL_RD;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_SL_RD;
            end if;

          ----------------------------------------------------------------
          -- A4: forward NTT of each u[i]
          ----------------------------------------------------------------
          when S_UN_START =>
            grant     <= C_CLI_NTT;
            slot_rd   <= C_SLOT_U + ii;
            slot_wr   <= C_SLOT_U + ii;
            ntt_inv   <= '0';
            ntt_start <= '1';
            fsm       <= S_UN_WAIT;

          when S_UN_WAIT =>
            if ntt_done = '1' then
              fsm <= S_UN_NEXT;
            end if;

          when S_UN_NEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_AZERO;
            else
              ii  <= ii + 1;
              fsm <= S_UN_START;
            end if;

          ----------------------------------------------------------------
          -- A5: acc = sum_j s_hat_lifted[j] o NTT(u)[j]
          ----------------------------------------------------------------
          when S_AZERO =>
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_TMP;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= (others => '0');
            fsm_we    <= '1';
            if cnt = 255 then
              cnt <= 0;
              jj  <= 0;
              fsm <= S_ABMUL;
            else
              cnt <= cnt + 1;
            end if;

          when S_ABMUL =>
            grant    <= C_CLI_BMUL;
            slot_rd  <= C_SLOT_YH + jj;    -- lifted s_hat
            slot_rd2 <= C_SLOT_U + jj;     -- NTT(u), plain domain
            slot_wr  <= C_SLOT_TMP;
            bm_accum <= '1';
            bm_start <= '1';
            fsm      <= S_ABMULW;

          when S_ABMULW =>
            if bm_done = '1' then
              fsm <= S_AJNEXT;
            end if;

          when S_AJNEXT =>
            if jj = G_K - 1 then
              fsm <= S_AINTT;
            else
              jj  <= jj + 1;
              fsm <= S_ABMUL;
            end if;

          when S_AINTT =>
            grant     <= C_CLI_NTT;
            slot_rd   <= C_SLOT_TMP;
            slot_wr   <= C_SLOT_TMP;
            ntt_inv   <= '1';
            ntt_start <= '1';
            fsm       <= S_AINTTW;

          when S_AINTTW =>
            if ntt_done = '1' then
              cnt <= 0;
              fsm <= S_W_RD;
            end if;

          ----------------------------------------------------------------
          -- A6: w = v - INTT(acc), written over the V slot
          ----------------------------------------------------------------
          when S_W_RD =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_V;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_W_RDW;

          when S_W_RDW =>
            fsm <= S_W_RD2;

          when S_W_RD2 =>
            acc_val   <= signed(fsm_rdata);
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_TMP;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_W_RD2W;

          when S_W_RD2W =>
            fsm <= S_W_WR;

          when S_W_WR =>
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_MU;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= std_logic_vector(
                           range_reduce(acc_val - signed(fsm_rdata)));
            fsm_we    <= '1';
            fsm       <= S_W_NEXT;

          when S_W_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              if G_STOP_AT = 3 then
                fsm <= S_DONE;
              else
                fsm <= S_M2_RUN;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_W_RD;
            end if;

          ----------------------------------------------------------------
          -- A7: m2 = ByteEncode1(Compress1(w))
          ----------------------------------------------------------------
          when S_M2_RUN =>
            grant      <= C_CLI_FSM;
            slot_rd    <= C_SLOT_MU;
            cct_decode <= '0';
            cct_dsel   <= "10";              -- d = 1
            cct_base   <= std_logic_vector(to_unsigned(G_ADDR_M2, 13));
            cct_start  <= '1';
            fsm        <= S_M2_WAIT;

          when S_M2_WAIT =>
            if cct_done = '1' then
              if G_STOP_AT = 4 then
                fsm <= S_DONE;
              else
                fsm <= S_G_MODE;
              end if;
            end if;

          ----------------------------------------------------------------
          -- B: re-encrypt. G(m2 || h) where h sits inside dk.
          ----------------------------------------------------------------
          when S_G_MODE =>
            sp_mode <= "11";
            fsm     <= S_G_INIT;

          when S_G_INIT =>
            sp_init <= '1';
            fsm     <= S_G_INIT_P;

          when S_G_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_M2, 13));
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
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 768 * G_K + 32, 13));
              fsm     <= S_G_HWAIT;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_M2 + cnt + 1, 13));
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
                           to_unsigned(G_ADDR_DK + 768 * G_K + 32 + cnt + 1,
                                       13));
              fsm     <= S_G_HWAIT;
            end if;

          when S_G_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_G_SQ;
            end if;

          when S_G_SQ =>
            if sp_dvalid = '1' then
              if cnt < 32 then
                by_addr <= std_logic_vector(
                             to_unsigned(G_ADDR_K2 + cnt, 13));
              else
                by_addr <= std_logic_vector(
                             to_unsigned(G_ADDR_R2 + cnt - 32, 13));
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
              fsm <= S_TD_RUN;
            else
              cnt <= cnt + 1;
              fsm <= S_G_SQ;
            end if;

          -- t_hat from ek_pke, which lives inside dk at offset 384*K
          when S_TD_RUN =>
            grant      <= C_CLI_FSM;
            slot_wr    <= C_SLOT_T + ii;
            c12_decode <= '1';
            c12_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_DK + 384 * G_K + 384 * ii, 13));
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

          when S_Y_MODE =>
            sp_mode  <= "01";
            samp_sel <= '1';
            fsm      <= S_Y_INIT;

          when S_Y_INIT =>
            sp_init <= '1';
            fsm     <= S_Y_INIT_P;

          when S_Y_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_R2, 13));
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
                           to_unsigned(G_ADDR_R2 + cnt + 1, 13));
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
              fsm   <= S_E_MODE;
            else
              nonce <= nonce + 1;
              fsm   <= S_Y_MODE;
            end if;

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
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_R2, 13));
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
                           to_unsigned(G_ADDR_R2 + cnt + 1, 13));
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
              grant   <= C_CLI_SAMP;
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
            sp_mode  <= "00";
            samp_sel <= '0';
            fsm      <= S_U_AINIT;

          when S_U_AINIT =>
            sp_init <= '1';
            fsm     <= S_U_AINIT_P;

          when S_U_AINIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              -- rho sits at the end of ek_pke, inside dk
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 384 * G_K + 384 * G_K, 13));
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
                           to_unsigned(G_ADDR_DK + 768 * G_K + cnt + 1, 13));
              fsm     <= S_U_AWAIT;
            end if;

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
              grant    <= C_CLI_BMUL;
              slot_rd  <= C_SLOT_A;
              slot_rd2 <= C_SLOT_YH + jj;
              slot_wr  <= C_SLOT_TMP;
              bm_accum <= '1';
              bm_start <= '1';
              fsm      <= S_U_BMULW;
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
              ii  <= 0;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_V_ZERO;
            else
              ii  <= ii + 1;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_U_ZERO;
            end if;

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
            slot_rd  <= C_SLOT_T + jj;
            slot_rd2 <= C_SLOT_YH + jj;
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
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_M2, 13));
              fsm     <= S_V_MRD;
            end if;

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
              fsm <= S_C1_RUN;
            else
              cnt <= cnt + 1;
              if (cnt + 1) mod 8 = 0 then
                by_addr <= std_logic_vector(
                             to_unsigned(G_ADDR_M2 + (cnt + 1) / 8, 13));
                fsm     <= S_V_MRD;
              else
                fsm <= S_V_ADD_RD;
              end if;
            end if;

          when S_C1_RUN =>
            grant      <= C_CLI_FSM;
            slot_rd    <= C_SLOT_U + ii;
            cct_decode <= '0';
            cct_dsel   <= "00";
            cct_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_C2 + 320 * ii, 13));
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
            cct_dsel   <= "01";
            cct_base   <= std_logic_vector(
                            to_unsigned(G_ADDR_C2 + 320 * G_K, 13));
            cct_start  <= '1';
            fsm        <= S_C2_WAIT;

          when S_C2_WAIT =>
            if cct_done = '1' then
              cnt <= 0;
              fsm <= S_KB_MODE;
            end if;

          ----------------------------------------------------------------
          -- C1: Kbar = J(z || c), computed unconditionally
          ----------------------------------------------------------------
          when S_KB_MODE =>
            sp_mode <= "01";                 -- SHAKE256
            fsm     <= S_KB_INIT;

          when S_KB_INIT =>
            sp_init <= '1';
            fsm     <= S_KB_INIT_P;

          when S_KB_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 768 * G_K + 64, 13));
              fsm     <= S_KB_ZWAIT;
            end if;

          when S_KB_ZWAIT =>
            fsm <= S_KB_ZABS;

          when S_KB_ZABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_KB_ZABSW;
            end if;

          when S_KB_ZABSW =>
            if cnt = 31 then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_C, 13));
              fsm     <= S_KB_CWAIT;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 768 * G_K + 64 + cnt + 1,
                                       13));
              fsm     <= S_KB_ZWAIT;
            end if;

          when S_KB_CWAIT =>
            fsm <= S_KB_CABS;

          when S_KB_CABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_KB_CABSW;
            end if;

          when S_KB_CABSW =>
            if cnt = 320 * G_K + 128 - 1 then
              fsm <= S_KB_FIN;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_C + cnt + 1, 13));
              fsm     <= S_KB_CWAIT;
            end if;

          when S_KB_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_KB_SQ;
            end if;

          when S_KB_SQ =>
            if sp_dvalid = '1' then
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_KB + cnt, 13));
              by_din  <= sp_dout;
              by_we   <= '1';
              sp_re   <= '1';
              fsm     <= S_KB_SQW;
            end if;

          when S_KB_SQW =>
            fsm <= S_KB_SQ2;

          when S_KB_SQ2 =>
            if cnt = 31 then
              cnt      <= 0;
              diff_acc <= (others => '0');
              fsm      <= S_CMP_A;
            else
              cnt <= cnt + 1;
              fsm <= S_KB_SQ;
            end if;

          ----------------------------------------------------------------
          -- C2: constant-time comparison of c against c2.
          -- Every one of the 1088 byte pairs is visited and its difference
          -- is OR-accumulated. There is no early exit, so the loop length
          -- reveals nothing about the data.
          ----------------------------------------------------------------
          when S_CMP_A =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_C + cnt, 13));
            fsm     <= S_CMP_AW;

          when S_CMP_AW =>
            fsm <= S_CMP_B;

          when S_CMP_B =>
            tmp_b   <= unsigned(by_dout);
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_C2 + cnt, 13));
            fsm     <= S_CMP_BW;

          when S_CMP_BW =>
            fsm <= S_CMP_NEXT;

          when S_CMP_NEXT =>
            diff_acc <= diff_acc or (tmp_b xor unsigned(by_dout));
            if cnt = 320 * G_K + 128 - 1 then
              cnt <= 0;
              fsm <= S_SEL_RD;
            else
              cnt <= cnt + 1;
              fsm <= S_CMP_A;
            end if;

          ----------------------------------------------------------------
          -- C3: branchless selection.
          -- keep_msk is all ones when the ciphertexts matched. Each output
          -- byte is (K2 and mask) or (Kbar and not mask), so both candidates
          -- are read for every byte and neither path is shorter.
          ----------------------------------------------------------------
          when S_SEL_RD =>
            if diff_acc = 0 then
              keep_msk <= (others => '1');
              rejected <= '0';
            else
              keep_msk <= (others => '0');
              rejected <= '1';
            end if;
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_K2 + cnt, 13));
            fsm     <= S_SEL_RDW;

          when S_SEL_RDW =>
            fsm <= S_SEL_RD2;

          when S_SEL_RD2 =>
            tmp_b   <= unsigned(by_dout);
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_KB + cnt, 13));
            fsm     <= S_SEL_RD2W;

          when S_SEL_RD2W =>
            fsm <= S_SEL_WR;

          when S_SEL_WR =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_KO + cnt, 13));
            by_din  <= std_logic_vector(
                         (tmp_b and keep_msk) or
                         (unsigned(by_dout) and not keep_msk));
            by_we   <= '1';
            fsm     <= S_SEL_NEXT;

          when S_SEL_NEXT =>
            if cnt = 31 then
              fsm <= S_DONE;
            else
              cnt <= cnt + 1;
              fsm <= S_SEL_RD;
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
