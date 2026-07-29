-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- ntt_d_unit: 256-point NTT and inverse NTT over q = 8380417, plus the
-- coefficient-wise product used by ML-DSA.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Structurally this is ntt_unit with every width doubled, but three things
-- differ from the Kyber datapath and each one is a place to get it wrong:
--
--  1. The pointwise product is COEFFICIENT-WISE, not a paired basemul. Kyber
--     needs basemul because x^256+1 factors into 128 quadratics over its q,
--     so coefficients pair up and carry a zeta twist. The Dilithium modulus
--     supports a full 256-point NTT, so the product is simply a[i]*b[i] with
--     no pairing and no zeta. This unit therefore serves all three operations.
--
--  2. Montgomery reduction uses the SUBTRACTIVE convention, r = (a - t*q)>>32
--     with t = (a*C_QINVD) truncated to signed 32. The additive convention
--     needs -q^-1 instead, and swapping the two produces plausible-looking
--     garbage rather than an obvious failure.
--
--  3. Zetas are stored already in the Montgomery domain, so a butterfly is
--     one multiply and one reduction. Nothing is lifted inside this unit.
--
-- Coefficients are signed 32-bit throughout. Growth without intermediate
-- reduction peaks at 28015249 forward and 99120476 inverse, both comfortably
-- inside the range, so no reduction is inserted between layers.
--
-- Memory interface mirrors ntt_unit: the unit owns a read port and a write
-- port into a 32-bit-wide polynomial memory and runs to completion.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;

entity ntt_d_unit is
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;

    start   : in  std_logic;
    -- "00" forward NTT, "01" inverse NTT, "10" coefficient-wise product
    op      : in  std_logic_vector(1 downto 0);
    done    : out std_logic;
    busy    : out std_logic;

    -- operand A, also the destination
    a_raddr : out std_logic_vector(7 downto 0);
    a_rdata : in  std_logic_vector(C_CW - 1 downto 0);
    a_waddr : out std_logic_vector(7 downto 0);
    a_wdata : out std_logic_vector(C_CW - 1 downto 0);
    a_we    : out std_logic;

    -- operand B, read only, used by the pointwise product
    b_raddr : out std_logic_vector(7 downto 0);
    b_rdata : in  std_logic_vector(C_CW - 1 downto 0));
end entity ntt_d_unit;

architecture rtl of ntt_d_unit is

  type t_fsm is (
    S_IDLE,
    -- forward: read pair, settle, butterfly, write both
    S_F_RD1, S_F_RD1W, S_F_RD2, S_F_RD2W, S_F_WR1, S_F_WR2, S_F_NEXT,
    -- inverse: same shape, different butterfly
    S_I_RD1, S_I_RD1W, S_I_RD2, S_I_RD2W, S_I_WR1, S_I_WR2, S_I_NEXT,
    -- inverse final scale by 256^-1
    S_I_SC_RD, S_I_SC_RDW, S_I_SC_WR, S_I_SC_NEXT,
    -- pointwise product
    S_P_RD, S_P_RDW, S_P_RDW2, S_P_WR, S_P_NEXT,
    S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  -- butterfly bookkeeping
  signal len   : integer range 0 to 128 := 128;
  signal st    : integer range 0 to 255 := 0;
  signal jj    : integer range 0 to 255 := 0;
  signal midx  : integer range 0 to 256 := 0;
  signal cnt   : integer range 0 to 255 := 0;

  signal op_r  : std_logic_vector(1 downto 0) := "00";
  signal zeta  : signed(23 downto 0) := (others => '0');
  signal opa   : signed(C_CW - 1 downto 0) := (others => '0');

  -- Montgomery reduction, subtractive convention.
  --   t = (a * C_QINVD) truncated to signed 32
  --   r = (a - t * q) >> 32
  -- The truncation is what makes the constant sign-specific: taking the low
  -- 32 bits of the product and reinterpreting them as signed is exactly what
  -- the reference implementation does.
  function mont_d (a : signed) return signed is
    -- Only the low 32 bits of a*C_QINVD matter, so the full product is never
    -- formed: multiplying the low 32 bits of a by the constant and keeping
    -- the low 32 bits of that is arithmetically identical and keeps every
    -- intermediate inside a declared width.
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
    variable pr : signed(55 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        busy_r  <= '0';
        done_r  <= '0';
        a_raddr <= (others => '0');
        a_waddr <= (others => '0');
        a_wdata <= (others => '0');
        a_we    <= '0';
        b_raddr <= (others => '0');
        len     <= 128;
        st      <= 0;
        jj      <= 0;
        midx    <= 0;
        cnt     <= 0;
        op_r    <= "00";
        zeta    <= (others => '0');
        opa     <= (others => '0');
      else
        done_r <= '0';
        a_we   <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r <= '1';
              op_r   <= op;
              cnt    <= 0;
              case op is
                when "00" =>
                  len  <= 128;
                  st   <= 0;
                  jj   <= 0;
                  midx <= 0;
                  fsm  <= S_F_RD1;
                when "01" =>
                  len  <= 1;
                  st   <= 0;
                  jj   <= 0;
                  midx <= 256;
                  fsm  <= S_I_RD1;
                when others =>
                  fsm  <= S_P_RD;
              end case;
            end if;

          ----------------------------------------------------------------
          -- Forward butterfly:
          --   t        = mont(zeta * w[j+len])
          --   w[j+len] = w[j] - t
          --   w[j]     = w[j] + t
          ----------------------------------------------------------------
          when S_F_RD1 =>
            -- midx counts BLOCKS, and the oracle increments it at the top of
            -- every start-loop iteration, so it advances at a len boundary
            -- too. Advancing it only within a len silently reuses the
            -- previous root for the first block of each new layer.
            zeta    <= C_ZETAS_D(midx + 1);
            a_raddr <= std_logic_vector(to_unsigned(jj, 8));
            fsm     <= S_F_RD1W;

          when S_F_RD1W =>
            fsm <= S_F_RD2;

          when S_F_RD2 =>
            opa     <= signed(a_rdata);
            a_raddr <= std_logic_vector(to_unsigned(jj + len, 8));
            fsm     <= S_F_RD2W;

          when S_F_RD2W =>
            fsm <= S_F_WR1;

          when S_F_WR1 =>
            -- Both halves of the butterfly are computed from the SAME pr in
            -- this one state. opa is assigned exactly once, holding w[j] - t
            -- for the next state; assigning it twice here would silently keep
            -- only the last write, which is the defect that accounted for
            -- most of the KeyGen bring-up bugs.
            pr      := resize(zeta * signed(a_rdata), 56);
            a_waddr <= std_logic_vector(to_unsigned(jj, 8));
            a_wdata <= std_logic_vector(opa + mont_d(pr));
            a_we    <= '1';
            opa     <= opa - mont_d(pr);
            fsm     <= S_F_WR2;

          when S_F_WR2 =>
            a_waddr <= std_logic_vector(to_unsigned(jj + len, 8));
            a_wdata <= std_logic_vector(opa);
            a_we    <= '1';
            fsm     <= S_F_NEXT;

          when S_F_NEXT =>
            if jj = st + len - 1 then
              midx <= midx + 1;
              if st + 2 * len >= 256 then
                if len = 1 then
                  fsm <= S_DONE;
                else
                  len <= len / 2;
                  st  <= 0;
                  jj  <= 0;
                  fsm <= S_F_RD1;
                end if;
              else
                st  <= st + 2 * len;
                jj  <= st + 2 * len;
                fsm <= S_F_RD1;
              end if;
            else
              jj  <= jj + 1;
              fsm <= S_F_RD1;
            end if;

          ----------------------------------------------------------------
          -- Inverse butterfly:
          --   t        = w[j]
          --   w[j]     = t + w[j+len]
          --   w[j+len] = mont(zeta * (w[j+len] - t))
          ----------------------------------------------------------------
          when S_I_RD1 =>
            zeta    <= C_ZETAS_D(midx - 1);
            a_raddr <= std_logic_vector(to_unsigned(jj, 8));
            fsm     <= S_I_RD1W;

          when S_I_RD1W =>
            fsm <= S_I_RD2;

          when S_I_RD2 =>
            opa     <= signed(a_rdata);
            a_raddr <= std_logic_vector(to_unsigned(jj + len, 8));
            fsm     <= S_I_RD2W;

          when S_I_RD2W =>
            fsm <= S_I_WR1;

          when S_I_WR1 =>
            a_waddr <= std_logic_vector(to_unsigned(jj, 8));
            a_wdata <= std_logic_vector(opa + signed(a_rdata));
            a_we    <= '1';
            pr      := resize(zeta * (signed(a_rdata) - opa), 56);
            opa     <= mont_d(pr);
            fsm     <= S_I_WR2;

          when S_I_WR2 =>
            a_waddr <= std_logic_vector(to_unsigned(jj + len, 8));
            a_wdata <= std_logic_vector(opa);
            a_we    <= '1';
            fsm     <= S_I_NEXT;

          when S_I_NEXT =>
            if jj = st + len - 1 then
              midx <= midx - 1;
              if st + 2 * len >= 256 then
                if len = 128 then
                  cnt <= 0;
                  fsm <= S_I_SC_RD;
                else
                  len <= len * 2;
                  st  <= 0;
                  jj  <= 0;
                  fsm <= S_I_RD1;
                end if;
              else
                st  <= st + 2 * len;
                jj  <= st + 2 * len;
                fsm <= S_I_RD1;
              end if;
            else
              jj  <= jj + 1;
              fsm <= S_I_RD1;
            end if;

          -- final scale by 256^-1, already in the Montgomery domain
          when S_I_SC_RD =>
            a_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_I_SC_RDW;

          when S_I_SC_RDW =>
            fsm <= S_I_SC_WR;

          when S_I_SC_WR =>
            pr      := resize(signed(a_rdata) * to_signed(C_SD, 24), 56);
            a_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            a_wdata <= std_logic_vector(mont_d(pr));
            a_we    <= '1';
            fsm     <= S_I_SC_NEXT;

          when S_I_SC_NEXT =>
            if cnt = 255 then
              fsm <= S_DONE;
            else
              cnt <= cnt + 1;
              fsm <= S_I_SC_RD;
            end if;

          ----------------------------------------------------------------
          -- Coefficient-wise product. No pairing and no zeta: the Dilithium
          -- modulus admits a full 256-point transform, unlike Kyber.
          -- One operand must arrive already lifted by R^2; that bookkeeping
          -- belongs to the caller, not to this unit.
          ----------------------------------------------------------------
          when S_P_RD =>
            a_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            b_raddr <= std_logic_vector(to_unsigned(cnt, 8));
            fsm     <= S_P_RDW;

          when S_P_RDW =>
            fsm <= S_P_RDW2;

          when S_P_RDW2 =>
            opa <= signed(a_rdata);
            fsm <= S_P_WR;

          when S_P_WR =>
            pr      := resize(opa * signed(b_rdata), 56);
            a_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            a_wdata <= std_logic_vector(mont_d(pr));
            a_we    <= '1';
            fsm     <= S_P_NEXT;

          when S_P_NEXT =>
            if cnt = 255 then
              fsm <= S_DONE;
            else
              cnt <= cnt + 1;
              fsm <= S_P_RD;
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
