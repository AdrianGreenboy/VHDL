-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- kem_keygen: ML-KEM-768 KeyGen sequencer, FIPS 203 Algorithms 13 and 16.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Orchestrates the verified blocks over the shared memories:
--   sponge (SHA3-512, SHA3-256, SHAKE256, SHAKE128)
--   sampler_ntt_k (SampleNTT), sampler_cbd_k (SamplePolyCBD)
--   ntt_unit (forward NTT), basemul_k (pointwise, accumulating)
--   codec_12 (ByteEncode_12)
--
-- Domain rules enforced here, per doc/DOMAIN_RULES.md:
--
--  1. SampleNTT output is ALREADY in NTT domain. It is fed straight to
--     basemul with no transform.
--
--  2. Exactly one basemul operand is lifted by R^2. Here it is s_hat, and the
--     lift goes into a scratch slot rather than in place, because dk must
--     encode the UNLIFTED s_hat. Lifting in place would produce a correct ek
--     and a silently wrong dk, which only surfaces when decapsulation fails.
--
--  3. A[i][j] uses seed bytes (j, i) in that order.
--
-- Interface: pulse start with d and z already staged in byte memory; done
-- pulses when ek and dk are complete.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.poly_mem_pkg.all;
use work.ntt_tables_pkg.all;

entity kem_keygen is
  generic (
    G_K       : integer := 3;
    G_ADDR_D  : integer := 0;      -- byte address of the 32-byte seed d
    G_ADDR_Z  : integer := 32;     -- byte address of the 32-byte seed z
    G_ADDR_RHO : integer := 64;    -- scratch: rho
    G_ADDR_SIG : integer := 96;    -- scratch: sigma
    G_ADDR_EK : integer := 512;    -- ek base (1184 bytes)
    G_ADDR_DK : integer := 2048;   -- dk base (2400 bytes)
    -- Halt after a named stage, for checkpoint inspection:
    --   0 run to completion
    --   1 after s[0] CBD          2 after s_hat[0] NTT
    --   3 after the R^2 lift      4 after A[0][0] SampleNTT
    --   5 after the K basemuls of row 0
    G_STOP_AT : integer := 0);
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    start      : in  std_logic;
    done       : out std_logic;
    busy       : out std_logic;

    -- polynomial memory arbitration
    grant      : out integer range 0 to 4;
    slot_rd    : out integer range 0 to C_SLOTS - 1;
    slot_rd2   : out integer range 0 to C_SLOTS - 1;
    slot_wr    : out integer range 0 to C_SLOTS - 1;
    fsm_raddr  : out std_logic_vector(7 downto 0);
    fsm_rdata  : in  std_logic_vector(15 downto 0);
    fsm_waddr  : out std_logic_vector(7 downto 0);
    fsm_wdata  : out std_logic_vector(15 downto 0);
    fsm_we     : out std_logic;

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

    -- samplers
    s1_start   : out std_logic;    -- SampleNTT
    s1_done    : in  std_logic;
    s2_start   : out std_logic;    -- SamplePolyCBD
    s2_done    : in  std_logic;
    samp_sel   : out std_logic;    -- '0' SampleNTT, '1' CBD
    samp_run   : out std_logic;    -- '1' while a sampler owns the squeeze port

    -- NTT
    ntt_start  : out std_logic;
    ntt_inv    : out std_logic;
    ntt_done   : in  std_logic;

    -- basemul
    bm_start   : out std_logic;
    bm_accum   : out std_logic;
    bm_done    : in  std_logic;

    -- codec_12
    cd_start   : out std_logic;
    cd_decode  : out std_logic;
    cd_base    : out std_logic_vector(12 downto 0);
    cd_done    : in  std_logic;

    -- byte memory port A
    by_addr    : out std_logic_vector(12 downto 0);
    by_din     : out std_logic_vector(7 downto 0);
    by_we      : out std_logic;
    by_dout    : in  std_logic_vector(7 downto 0));
end entity kem_keygen;

architecture rtl of kem_keygen is

  type t_fsm is (
    S_IDLE,
    -- G(d || K)
    S_G_INIT, S_G_INIT_P, S_G_WAIT, S_G_ABS, S_G_ABSW, S_G_ABSK, S_G_FIN,
    S_G_SQ, S_G_SQW, S_G_SQ2, S_G_STORE,
    -- s and e via PRF + CBD, then NTT
    S_SE_MODE, S_SE_INIT, S_SE_INIT_P, S_SE_WAIT, S_SE_ABS, S_SE_ABSW, S_SE_NONCE, S_SE_FIN,
    S_SE_RUN, S_SE_NTT,
    S_SE_NTTW, S_SE_NEXT,
    -- lift s_hat into the scratch slot
    S_LIFT_RD, S_LIFT_RDW, S_LIFT_WR, S_LIFT_NEXT,
    -- matrix product
    S_MM_ZERO, S_MM_AMODE, S_MM_AINIT, S_MM_AINIT_P, S_MM_AWAIT, S_MM_AABS, S_MM_AABSW,
    S_MM_AIDX1, S_MM_AIDX2, S_MM_AFIN,
    S_MM_ARUN, S_MM_BMUL, S_MM_BMULW, S_MM_JNEXT,
    S_MM_ADD_RD, S_MM_ADD_RDW, S_MM_ADD_RD2, S_MM_ADD_RD2W, S_MM_ADD_WR,
    S_MM_ADD_NEXT, S_MM_INEXT,
    -- encode ek, hash it, encode dk
    S_EK_ENC, S_EK_ENCW, S_EK_NEXT, S_EK_RHO, S_EK_RHOS, S_EK_RHOW,
    S_H_MODE, S_H_INIT, S_H_INIT_P, S_H_WAIT, S_H_ABS, S_H_ABSW, S_H_FIN, S_H_SQ, S_H_SQW, S_H_SQ2,
    S_H_STORE,
    S_DK_ENC, S_DK_ENCW, S_DK_NEXT,
    S_DK_COPYEK, S_DK_COPYEKS, S_DK_COPYEKW, S_DK_COPYH, S_DK_COPYHW,
    S_DK_COPYZ, S_DK_COPYZS, S_DK_COPYZW,
    S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal ii    : integer range 0 to 8 := 0;      -- outer index
  signal jj    : integer range 0 to 8 := 0;      -- inner index
  signal cnt   : integer range 0 to 4095 := 0;   -- byte or coefficient counter
  signal nonce : integer range 0 to 15 := 0;

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  -- Lift constant R^2 mod q in Montgomery domain, and the reduction used to
  -- apply it. This is the only place the FSM does arithmetic itself.
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
    prod := resize(t * to_signed(C_QK, 18), prod'length);
    num  := resize(a, num'length) - prod;
    return resize(shift_right(num, 16), 16);
  end function mont16;

  function range_reduce (x : signed(15 downto 0)) return signed is
    variable v : signed(15 downto 0);
  begin
    v := x;
    if v >= to_signed(C_QK, 16) then
      v := v - to_signed(2 * C_QK, 16);
    elsif v < -to_signed(C_QK, 16) then
      v := v + to_signed(2 * C_QK, 16);
    end if;
    return v;
  end function range_reduce;

  signal acc_val : signed(15 downto 0) := (others => '0');

begin

  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable p : signed(31 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm       <= S_IDLE;
        busy_r    <= '0';
        done_r    <= '0';
        grant     <= C_CLI_NONE;
        slot_rd   <= 0;
        slot_rd2  <= 0;
        slot_wr   <= 0;
        fsm_we    <= '0';
        fsm_raddr <= (others => '0');
        fsm_waddr <= (others => '0');
        fsm_wdata <= (others => '0');
        sp_init   <= '0';
        sp_we     <= '0';
        sp_adone  <= '0';
        sp_re     <= '0';
        sp_din    <= (others => '0');
        sp_mode   <= "00";
        s1_start  <= '0';
        s2_start  <= '0';
        samp_sel  <= '0';
        samp_run  <= '0';
        ntt_start <= '0';
        ntt_inv   <= '0';
        bm_start  <= '0';
        bm_accum  <= '0';
        cd_start  <= '0';
        cd_decode <= '0';
        cd_base   <= (others => '0');
        by_addr   <= (others => '0');
        by_din    <= (others => '0');
        by_we     <= '0';
        ii        <= 0;
        jj        <= 0;
        cnt       <= 0;
        nonce     <= 0;
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
        cd_start  <= '0';
        by_we     <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r  <= '1';
              cnt     <= 0;
              ii      <= 0;
              jj      <= 0;
              sp_mode <= "11";               -- SHA3-512
              fsm     <= S_G_INIT;
            end if;

          ----------------------------------------------------------------
          -- G(d || K) -> rho || sigma
          ----------------------------------------------------------------
          when S_G_INIT =>
            sp_init <= '1';
            fsm     <= S_G_INIT_P;

          when S_G_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_D, 13));
              fsm     <= S_G_WAIT;
            end if;

          -- One cycle for the byte memory to present the addressed byte.
          when S_G_WAIT =>
            fsm <= S_G_ABS;

          when S_G_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_G_ABSW;
            end if;

          -- One settle cycle after din_we, then issue the next address.
          when S_G_ABSW =>
            if cnt = 31 then
              fsm <= S_G_ABSK;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_D + cnt + 1, 13));
              fsm     <= S_G_WAIT;
            end if;

          when S_G_ABSK =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(G_K, 8));
              sp_we  <= '1';
              fsm    <= S_G_FIN;
            end if;

          when S_G_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              cnt      <= 0;
              fsm      <= S_G_SQ;
            end if;

          when S_G_SQ =>
            if sp_dvalid = '1' then
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_RHO + cnt, 13));
              by_din  <= sp_dout;
              by_we   <= '1';
              sp_re   <= '1';
              fsm     <= S_G_SQW;
            end if;

          when S_G_SQW =>
            -- One settle cycle: the sponge registers its output on the same
            -- edge that consumes sp_re, so sampling sp_dout again without
            -- waiting would store the previous byte a second time.
            fsm <= S_G_SQ2;

          when S_G_SQ2 =>
            if cnt = 63 then
              cnt   <= 0;
              nonce <= 0;
              ii    <= 0;
              fsm   <= S_SE_MODE;
            else
              cnt <= cnt + 1;
              fsm <= S_G_SQ;
            end if;

          when S_G_STORE =>
            fsm <= S_SE_MODE;

          ----------------------------------------------------------------
          -- s[0..K-1] then e[0..K-1]: PRF(sigma, nonce) -> CBD -> NTT
          ----------------------------------------------------------------
          -- The mode must be established one cycle before init is sampled:
          -- both are signals, so asserting them together makes the sponge
          -- initialise with the previous mode.
          when S_SE_MODE =>
            sp_mode  <= "01";                -- SHAKE256
            samp_sel <= '1';                 -- CBD
            fsm      <= S_SE_INIT;

          when S_SE_INIT =>
            -- Unconditional single-cycle pulse. Asserting and clearing in one
            -- state would collapse to the clear, and the sponge would never
            -- see the init.
            sp_init <= '1';
            fsm     <= S_SE_INIT_P;

          when S_SE_INIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SIG, 13));
              fsm     <= S_SE_WAIT;
            end if;

          when S_SE_WAIT =>
            fsm <= S_SE_ABS;

          when S_SE_ABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_SE_ABSW;
            end if;

          when S_SE_ABSW =>
            if cnt = 31 then
              fsm <= S_SE_NONCE;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_SIG + cnt + 1, 13));
              fsm     <= S_SE_WAIT;
            end if;

          when S_SE_NONCE =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(nonce, 8));
              sp_we  <= '1';
              fsm    <= S_SE_FIN;
            end if;

          when S_SE_FIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_SE_RUN;
            end if;

          when S_SE_RUN =>
            if sp_dvalid = '1' then
              grant   <= C_CLI_SAMP;
              if nonce < G_K then
                slot_wr <= C_SLOT_S + nonce;
              else
                slot_wr <= C_SLOT_E + (nonce - G_K);
              end if;
              samp_run <= '1';
              s2_start <= '1';
              fsm      <= S_SE_NTT;
            end if;

          when S_SE_NTT =>
            if s2_done = '1' then
              samp_run <= '0';
              if G_STOP_AT = 1 and nonce = 0 then
                -- halt before the NTT so the slot still holds the CBD output
                fsm <= S_DONE;
              else
                grant     <= C_CLI_NTT;
                if nonce < G_K then
                  slot_rd <= C_SLOT_S + nonce;
                  slot_wr <= C_SLOT_S + nonce;
                else
                  slot_rd <= C_SLOT_E + (nonce - G_K);
                  slot_wr <= C_SLOT_E + (nonce - G_K);
                end if;
                ntt_inv   <= '0';
                ntt_start <= '1';
                fsm       <= S_SE_NTTW;
              end if;
            end if;

          when S_SE_NTTW =>
            if ntt_done = '1' then
              if G_STOP_AT = 2 and nonce = 0 then
                fsm <= S_DONE;
              else
                fsm <= S_SE_NEXT;
              end if;
            end if;

          when S_SE_NEXT =>
            if nonce = 2 * G_K - 1 then
              ii  <= 0;
              cnt <= 0;
              fsm <= S_LIFT_RD;
            else
              nonce <= nonce + 1;
              fsm   <= S_SE_MODE;
            end if;

          ----------------------------------------------------------------
          -- Lift s_hat by R^2 into the scratch slot.
          -- dk must encode the unlifted s_hat, so this never writes back
          -- into the s_hat slots.
          ----------------------------------------------------------------
          when S_LIFT_RD =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_S + ii;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_LIFT_RDW;

          when S_LIFT_RDW =>
            fsm <= S_LIFT_WR;

          when S_LIFT_WR =>
            p         := signed(fsm_rdata) * to_signed(C_R2, 16);
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_Y + ii;      -- y slots reused as lifted s_hat
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= std_logic_vector(mont16(p));
            fsm_we    <= '1';
            fsm       <= S_LIFT_NEXT;

          when S_LIFT_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              if ii = G_K - 1 then
                ii  <= 0;
                jj  <= 0;
                if G_STOP_AT = 3 then
                  fsm <= S_DONE;
                else
                  fsm <= S_MM_ZERO;
                end if;
              else
                ii  <= ii + 1;
                fsm <= S_LIFT_RD;
              end if;
            else
              cnt <= cnt + 1;
              fsm <= S_LIFT_RD;
            end if;

          ----------------------------------------------------------------
          -- t_hat[i] = sum_j A[i][j] o s_hat[j] + e_hat[i]
          ----------------------------------------------------------------
          when S_MM_ZERO =>
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_TMP;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= (others => '0');
            fsm_we    <= '1';
            if cnt = 255 then
              cnt <= 0;
              jj  <= 0;
              fsm <= S_MM_AMODE;
            else
              cnt <= cnt + 1;
            end if;

          when S_MM_AMODE =>
            sp_mode  <= "00";                -- SHAKE128
            samp_sel <= '0';                 -- SampleNTT
            fsm      <= S_MM_AINIT;

          when S_MM_AINIT =>
            -- Unconditional single-cycle pulse. Asserting and clearing in one
            -- state would collapse to the clear, and the sponge would never
            -- see the init.
            sp_init <= '1';
            fsm     <= S_MM_AINIT_P;

          when S_MM_AINIT_P =>
            if sp_ready = '1' then
              cnt     <= 0;
              by_addr <= std_logic_vector(to_unsigned(G_ADDR_RHO, 13));
              fsm     <= S_MM_AWAIT;
            end if;

          when S_MM_AWAIT =>
            fsm <= S_MM_AABS;

          when S_MM_AABS =>
            if sp_ready = '1' then
              sp_din <= by_dout;
              sp_we  <= '1';
              fsm    <= S_MM_AABSW;
            end if;

          when S_MM_AABSW =>
            if cnt = 31 then
              fsm <= S_MM_AIDX1;
            else
              cnt     <= cnt + 1;
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_RHO + cnt + 1, 13));
              fsm     <= S_MM_AWAIT;
            end if;

          when S_MM_AIDX1 =>
            -- A[i][j] uses seed bytes (j, i) in that order
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(jj, 8));
              sp_we  <= '1';
              fsm    <= S_MM_AIDX2;
            end if;

          when S_MM_AIDX2 =>
            if sp_ready = '1' then
              sp_din <= std_logic_vector(to_unsigned(ii, 8));
              sp_we  <= '1';
              fsm    <= S_MM_AFIN;
            end if;

          when S_MM_AFIN =>
            if sp_ready = '1' then
              sp_adone <= '1';
              fsm      <= S_MM_ARUN;
            end if;

          when S_MM_ARUN =>
            if sp_dvalid = '1' then
              grant    <= C_CLI_SAMP;
              slot_wr  <= C_SLOT_A;
              samp_run <= '1';
              s1_start <= '1';
              fsm      <= S_MM_BMUL;
            end if;

          when S_MM_BMUL =>
            if s1_done = '1' then
              samp_run <= '0';
              if G_STOP_AT = 4 and ii = 0 and jj = 0 then
                -- halt with A[0][0] still in its slot, before it is consumed
                fsm <= S_DONE;
              else
                -- SampleNTT output is already in NTT domain: no transform here
                grant    <= C_CLI_BMUL;
                slot_rd  <= C_SLOT_A;
                slot_rd2 <= C_SLOT_Y + jj;   -- lifted s_hat
                slot_wr  <= C_SLOT_TMP;
                bm_accum <= '1';
                bm_start <= '1';
                fsm      <= S_MM_BMULW;
              end if;
            end if;

          when S_MM_BMULW =>
            if bm_done = '1' then
              fsm <= S_MM_JNEXT;
            end if;

          when S_MM_JNEXT =>
            if jj = G_K - 1 then
              cnt <= 0;
              if G_STOP_AT = 5 and ii = 0 then
                fsm <= S_DONE;
              else
                fsm <= S_MM_ADD_RD;
              end if;
            else
              jj  <= jj + 1;
              fsm <= S_MM_AMODE;
            end if;

          when S_MM_ADD_RD =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_TMP;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_MM_ADD_RDW;

          when S_MM_ADD_RDW =>
            fsm <= S_MM_ADD_RD2;

          when S_MM_ADD_RD2 =>
            acc_val   <= signed(fsm_rdata);
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_E + ii;
            fsm_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm       <= S_MM_ADD_RD2W;

          when S_MM_ADD_RD2W =>
            fsm <= S_MM_ADD_WR;

          when S_MM_ADD_WR =>
            grant     <= C_CLI_FSM;
            slot_wr   <= C_SLOT_T + ii;
            fsm_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm_wdata <= std_logic_vector(
                           range_reduce(acc_val + signed(fsm_rdata)));
            fsm_we    <= '1';
            fsm       <= S_MM_ADD_NEXT;

          when S_MM_ADD_NEXT =>
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_MM_INEXT;
            else
              cnt <= cnt + 1;
              fsm <= S_MM_ADD_RD;
            end if;

          when S_MM_INEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              fsm <= S_EK_ENC;
            else
              ii  <= ii + 1;
              jj  <= 0;
              cnt <= 0;
              fsm <= S_MM_ZERO;
            end if;

          ----------------------------------------------------------------
          -- ek = ByteEncode12(t_hat) || rho
          ----------------------------------------------------------------
          when S_EK_ENC =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_T + ii;
            cd_decode <= '0';
            cd_base   <= std_logic_vector(
                           to_unsigned(G_ADDR_EK + 384 * ii, 13));
            cd_start  <= '1';
            fsm       <= S_EK_ENCW;

          when S_EK_ENCW =>
            if cd_done = '1' then
              fsm <= S_EK_NEXT;
            end if;

          when S_EK_NEXT =>
            if ii = G_K - 1 then
              ii  <= 0;
              cnt <= 0;
              fsm <= S_EK_RHO;
            else
              ii  <= ii + 1;
              fsm <= S_EK_ENC;
            end if;

          when S_EK_RHO =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_RHO + cnt, 13));
            fsm     <= S_EK_RHOS;

          when S_EK_RHOS =>
            fsm <= S_EK_RHOW;

          when S_EK_RHOW =>
            by_addr <= std_logic_vector(
                         to_unsigned(G_ADDR_EK + 384 * G_K + cnt, 13));
            by_din  <= by_dout;
            by_we   <= '1';
            if cnt = 31 then
              cnt <= 0;
              fsm <= S_H_MODE;
            else
              cnt <= cnt + 1;
              fsm <= S_EK_RHO;
            end if;

          ----------------------------------------------------------------
          -- H(ek)
          ----------------------------------------------------------------
          when S_H_MODE =>
            sp_mode <= "10";                 -- SHA3-256
            fsm     <= S_H_INIT;

          when S_H_INIT =>
            -- Unconditional single-cycle pulse. Asserting and clearing in one
            -- state would collapse to the clear, and the sponge would never
            -- see the init.
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
              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 384 * G_K +
                                       (384 * G_K + 32) + cnt, 13));
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
              ii  <= 0;
              fsm <= S_DK_ENC;
            else
              cnt <= cnt + 1;
              fsm <= S_H_SQ;
            end if;

          when S_H_STORE =>
            fsm <= S_DK_ENC;

          ----------------------------------------------------------------
          -- dk = ByteEncode12(s_hat) || ek || H(ek) || z
          -- s_hat here is the UNLIFTED copy in the S slots.
          ----------------------------------------------------------------
          when S_DK_ENC =>
            grant     <= C_CLI_FSM;
            slot_rd   <= C_SLOT_S + ii;
            cd_decode <= '0';
            cd_base   <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 384 * ii, 13));
            cd_start  <= '1';
            fsm       <= S_DK_ENCW;

          when S_DK_ENCW =>
            if cd_done = '1' then
              fsm <= S_DK_NEXT;
            end if;

          when S_DK_NEXT =>
            if ii = G_K - 1 then
              cnt <= 0;
              fsm <= S_DK_COPYEK;
            else
              ii  <= ii + 1;
              fsm <= S_DK_ENC;
            end if;

          when S_DK_COPYEK =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_EK + cnt, 13));
            fsm     <= S_DK_COPYEKS;

          when S_DK_COPYEKS =>
            fsm <= S_DK_COPYEKW;

          when S_DK_COPYEKW =>
            by_addr <= std_logic_vector(
                         to_unsigned(G_ADDR_DK + 384 * G_K + cnt, 13));
            by_din  <= by_dout;
            by_we   <= '1';
            if cnt = 384 * G_K + 32 - 1 then
              cnt <= 0;
              fsm <= S_DK_COPYZ;
            else
              cnt <= cnt + 1;
              fsm <= S_DK_COPYEK;
            end if;

          when S_DK_COPYH =>
            fsm <= S_DK_COPYZ;

          when S_DK_COPYHW =>
            fsm <= S_DK_COPYZ;

          when S_DK_COPYZ =>
            by_addr <= std_logic_vector(to_unsigned(G_ADDR_Z + cnt, 13));
            fsm     <= S_DK_COPYZS;

          when S_DK_COPYZS =>
            fsm <= S_DK_COPYZW;

          when S_DK_COPYZW =>
            by_addr <= std_logic_vector(
                         to_unsigned(G_ADDR_DK + 384 * G_K +
                                     (384 * G_K + 32) + 32 + cnt, 13));
            by_din  <= by_dout;
            by_we   <= '1';
            if cnt = 31 then
              fsm <= S_DONE;
            else
              cnt <= cnt + 1;
              fsm <= S_DK_COPYZ;
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
