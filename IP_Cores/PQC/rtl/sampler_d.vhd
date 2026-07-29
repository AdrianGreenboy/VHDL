-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- sampler_d: the four ML-DSA samplers over the shared Keccak sponge.
-- VHDL-2008. ASCII-only. MIT license.
--
--   mode "00"  RejNTTPoly    (ExpandA)     SHAKE128, 3 bytes per candidate
--   mode "01"  RejBoundedPoly(ExpandS)     SHAKE256, 2 nibbles per byte
--   mode "10"  ExpandMask                  SHAKE256, no rejection at all
--   mode "11"  SampleInBall                SHAKE256, rejection on index
--
-- CONTINUOUS SQUEEZE. The reference model, when it runs short of stream,
-- squeezes a LONGER output and re-parses from the beginning. That reads like
-- a restart but is not one: SHAKE is an extendable output function, so a
-- longer squeeze is a prefix-extension of the shorter one and the accepted
-- coefficients are identical. This was verified against the oracle over 200
-- seeds before any RTL was written. The sequencer therefore pulls bytes on
-- demand from one continuous stream and never restarts the sponge, which
-- removes the restart bookkeeping entirely.
--
-- Measured worst-case consumption over those seeds:
--   RejNTTPoly     774 bytes   (acceptance rate q/2^23 = 0.9990)
--   RejBoundedPoly 250 bytes   (acceptance rate 9/16   = 0.5625)
--   ExpandMask     640 bytes   (fixed, 32 * 20 bits)
--   SampleInBall   264 bytes   (8 sign bytes then one per swap, with retries)
--
-- No byte budget is hardcoded: every mode reads until it has 256 accepted
-- coefficients, so an unlucky seed simply consumes more stream.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;

entity sampler_d is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    start     : in  std_logic;
    mode      : in  std_logic_vector(1 downto 0);
    done      : out std_logic;
    busy      : out std_logic;

    -- sponge squeeze interface
    sp_dout   : in  std_logic_vector(7 downto 0);
    sp_re     : out std_logic;
    sp_dvalid : in  std_logic;

    -- destination polynomial
    p_waddr   : out std_logic_vector(7 downto 0);
    p_wdata   : out std_logic_vector(C_CW - 1 downto 0);
    p_we      : out std_logic;
    -- SampleInBall needs to read back what it already wrote, because the
    -- Fisher-Yates step copies c[j] into c[i] before overwriting c[j].
    p_raddr   : out std_logic_vector(7 downto 0);
    p_rdata   : in  std_logic_vector(C_CW - 1 downto 0));
end entity sampler_d;

architecture rtl of sampler_d is

  type t_fsm is (
    S_IDLE,
    -- RejNTTPoly: three bytes little-endian, top bit cleared, accept if < q
    S_A_B0, S_A_B0W, S_A_B1, S_A_B1W, S_A_B2, S_A_B2W, S_A_TEST,
    -- RejBoundedPoly: two nibbles per byte, accept if < 9
    S_B_RD, S_B_RDW, S_B_LO, S_B_HI,
    -- ExpandMask: 20-bit fields, five bytes carry two coefficients
    S_M_RD, S_M_RDW, S_M_ACC, S_M_EMIT,
    -- SampleInBall: clear, take 8 sign bytes, then Fisher-Yates
    S_C_CLR, S_C_SGN, S_C_SGNW, S_C_J, S_C_JW, S_C_TEST,
    S_C_RD, S_C_RDW, S_C_WI, S_C_WJ, S_C_NEXT,
    S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  signal nacc : integer range 0 to 256 := 0;   -- coefficients accepted
  signal cnt  : integer range 0 to 511 := 0;

  signal b0, b1, b2 : unsigned(7 downto 0) := (others => '0');
  signal acc  : unsigned(39 downto 0) := (others => '0');
  signal nbit : integer range 0 to 63 := 0;

  -- SampleInBall state
  signal sgn  : unsigned(63 downto 0) := (others => '0');
  signal ii   : integer range 0 to 256 := 0;
  signal jj   : integer range 0 to 255 := 0;
  signal cj   : signed(C_CW - 1 downto 0) := (others => '0');

  constant C_TAU_D    : integer := 49;
  constant C_ETA_D    : integer := 4;
  constant C_GAMMA1_D : integer := 524288;

begin

  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable z : unsigned(22 downto 0);
    variable h : unsigned(3 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        busy_r  <= '0';
        done_r  <= '0';
        sp_re   <= '0';
        p_we    <= '0';
        p_waddr <= (others => '0');
        p_wdata <= (others => '0');
        p_raddr <= (others => '0');
        nacc    <= 0;
        cnt     <= 0;
        acc     <= (others => '0');
        nbit    <= 0;
        sgn     <= (others => '0');
        ii      <= 0;
        jj      <= 0;
      else
        done_r <= '0';
        sp_re  <= '0';
        p_we   <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r <= '1';
              nacc   <= 0;
              cnt    <= 0;
              acc    <= (others => '0');
              nbit   <= 0;
              ii     <= 256 - C_TAU_D;
              -- sgn MUST be cleared per invocation, not only on reset: the
              -- sign bytes are OR-ed in, so a second SampleInBall would
              -- accumulate the previous call's bits and flip a handful of
              -- signs in c. The effect is invisible on the first call and
              -- corrupts every later one, which is precisely what a
              -- testbench that resets between vectors cannot see.
              sgn    <= (others => '0');
              case mode is
                when "00"   => fsm <= S_A_B0;
                when "01"   => fsm <= S_B_RD;
                when "10"   => fsm <= S_M_RD;
                when others => fsm <= S_C_CLR;
              end case;
            end if;

          ----------------------------------------------------------------
          -- RejNTTPoly: z = b0 + 256*b1 + 65536*(b2 and 0x7F), accept z < q
          ----------------------------------------------------------------
          when S_A_B0 =>
            if sp_dvalid = '1' then
              b0    <= unsigned(sp_dout);
              sp_re <= '1';
              fsm   <= S_A_B0W;
            end if;

          when S_A_B0W =>
            fsm <= S_A_B1;

          when S_A_B1 =>
            if sp_dvalid = '1' then
              b1    <= unsigned(sp_dout);
              sp_re <= '1';
              fsm   <= S_A_B1W;
            end if;

          when S_A_B1W =>
            fsm <= S_A_B2;

          when S_A_B2 =>
            if sp_dvalid = '1' then
              b2    <= unsigned(sp_dout);
              sp_re <= '1';
              fsm   <= S_A_B2W;
            end if;

          when S_A_B2W =>
            fsm <= S_A_TEST;

          when S_A_TEST =>
            -- the top bit of the third byte is discarded, giving 23 bits
            z := b2(6 downto 0) & b1 & b0;
            if z < to_unsigned(C_QD, 23) then
              p_waddr <= std_logic_vector(to_unsigned(nacc, 8));
              p_wdata <= std_logic_vector(resize(signed('0' & z), C_CW));
              p_we    <= '1';
              if nacc = 255 then
                fsm <= S_DONE;
              else
                nacc <= nacc + 1;
                fsm  <= S_A_B0;
              end if;
            else
              -- rejected: consume three more bytes, write nothing
              fsm <= S_A_B0;
            end if;

          ----------------------------------------------------------------
          -- RejBoundedPoly: each byte yields two nibbles, low first.
          -- A nibble under 9 maps to ETA - nibble.
          ----------------------------------------------------------------
          when S_B_RD =>
            if sp_dvalid = '1' then
              b0    <= unsigned(sp_dout);
              sp_re <= '1';
              fsm   <= S_B_RDW;
            end if;

          when S_B_RDW =>
            fsm <= S_B_LO;

          when S_B_LO =>
            h := b0(3 downto 0);
            if h < 9 then
              p_waddr <= std_logic_vector(to_unsigned(nacc, 8));
              p_wdata <= std_logic_vector(
                           to_signed(C_ETA_D, C_CW) -
                           resize(signed('0' & h), C_CW));
              p_we    <= '1';
              if nacc = 255 then
                fsm <= S_DONE;
              else
                nacc <= nacc + 1;
                fsm  <= S_B_HI;
              end if;
            else
              fsm <= S_B_HI;
            end if;

          when S_B_HI =>
            h := b0(7 downto 4);
            if h < 9 then
              p_waddr <= std_logic_vector(to_unsigned(nacc, 8));
              p_wdata <= std_logic_vector(
                           to_signed(C_ETA_D, C_CW) -
                           resize(signed('0' & h), C_CW));
              p_we    <= '1';
              if nacc = 255 then
                fsm <= S_DONE;
              else
                nacc <= nacc + 1;
                fsm  <= S_B_RD;
              end if;
            else
              fsm <= S_B_RD;
            end if;

          ----------------------------------------------------------------
          -- ExpandMask: 20-bit little-endian fields, then y = GAMMA1 - field.
          -- No rejection: every field is used.
          ----------------------------------------------------------------
          when S_M_RD =>
            if sp_dvalid = '1' then
              acc   <= acc or shift_left(
                         resize(unsigned(sp_dout), 40), nbit);
              nbit  <= nbit + 8;
              sp_re <= '1';
              fsm   <= S_M_RDW;
            end if;

          when S_M_RDW =>
            fsm <= S_M_ACC;

          when S_M_ACC =>
            if nbit >= 20 then
              fsm <= S_M_EMIT;
            else
              fsm <= S_M_RD;
            end if;

          when S_M_EMIT =>
            p_waddr <= std_logic_vector(to_unsigned(nacc, 8));
            p_wdata <= std_logic_vector(
                         to_signed(C_GAMMA1_D, C_CW) -
                         resize(signed('0' & acc(19 downto 0)), C_CW));
            p_we    <= '1';
            acc     <= shift_right(acc, 20);
            nbit    <= nbit - 20;
            if nacc = 255 then
              fsm <= S_DONE;
            else
              nacc <= nacc + 1;
              fsm  <= S_M_ACC;
            end if;

          ----------------------------------------------------------------
          -- SampleInBall. Clear the polynomial, take 8 bytes of sign bits,
          -- then run Fisher-Yates over the last TAU positions:
          --   pick j <= i by rejection, c[i] = c[j], c[j] = +-1
          ----------------------------------------------------------------
          when S_C_CLR =>
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= (others => '0');
            p_we    <= '1';
            if cnt = 255 then
              cnt <= 0;
              fsm <= S_C_SGN;
            else
              cnt <= cnt + 1;
            end if;

          when S_C_SGN =>
            if sp_dvalid = '1' then
              -- little-endian: first byte occupies the lowest bits
              sgn   <= sgn or shift_left(
                         resize(unsigned(sp_dout), 64), 8 * cnt);
              sp_re <= '1';
              fsm   <= S_C_SGNW;
            end if;

          when S_C_SGNW =>
            if cnt = 7 then
              cnt <= 0;
              fsm <= S_C_J;
            else
              cnt <= cnt + 1;
              fsm <= S_C_SGN;
            end if;

          when S_C_J =>
            if sp_dvalid = '1' then
              b0    <= unsigned(sp_dout);
              sp_re <= '1';
              fsm   <= S_C_JW;
            end if;

          when S_C_JW =>
            fsm <= S_C_TEST;

          when S_C_TEST =>
            -- reject until j <= i
            if to_integer(b0) <= ii then
              jj      <= to_integer(b0);
              p_raddr <= std_logic_vector(b0);
              fsm     <= S_C_RD;
            else
              fsm <= S_C_J;
            end if;

          when S_C_RD =>
            fsm <= S_C_RDW;

          when S_C_RDW =>
            cj  <= signed(p_rdata);
            fsm <= S_C_WI;

          when S_C_WI =>
            p_waddr <= std_logic_vector(to_unsigned(ii, 8));
            p_wdata <= std_logic_vector(cj);
            p_we    <= '1';
            fsm     <= S_C_WJ;

          when S_C_WJ =>
            p_waddr <= std_logic_vector(to_unsigned(jj, 8));
            if sgn(ii + C_TAU_D - 256) = '1' then
              p_wdata <= std_logic_vector(to_signed(C_QD - 1, C_CW));
            else
              p_wdata <= std_logic_vector(to_signed(1, C_CW));
            end if;
            p_we <= '1';
            fsm  <= S_C_NEXT;

          when S_C_NEXT =>
            if ii = 255 then
              fsm <= S_DONE;
            else
              ii  <= ii + 1;
              fsm <= S_C_J;
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
