-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- codec_d: ML-DSA bit packing and the hint codec.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Modes:
--   "0000"  pack   at 10 bits   (t1, simple_bitpack)
--   "0001"  pack   at  4 bits   (w1, simple_bitpack)
--   "0010"  pack   s   4 bits   (eta=4, field = 4 - x)
--   "0011"  pack   t0 13 bits   (field = 4096 - x)
--   "0100"  pack   z  20 bits   (field = GAMMA1 - x)
--   "0101"  unpack z  20 bits   (x = GAMMA1 - field)
--   "0110"  hint encode
--   "0111"  hint decode, with validation
--   "1000"  unpack s   4 bits   (x = 4 - field)
--   "1001"  unpack t0 13 bits   (x = 4096 - field)
--   "1010"  unpack t1 10 bits   (unsigned, no offset)
--
-- The signed packings all store b - x in bitlen(a+b) bits. For s with eta = 4
-- that field ranges over [0, 8], which needs nine values in four bits: it
-- fits exactly, with no headroom. A coefficient outside [-eta, eta] would
-- overflow into the neighbouring field rather than raising anything, so the
-- sampler that produces s is what guarantees the range, not this codec.
--
-- THE HINT CODEC IS THE ONLY ONE THAT VALIDATES. Encoding cannot fail;
-- decoding must reject malformed signatures on three separate rules:
--
--   1. y[OMEGA+i] holds the RUNNING TOTAL after row i, not that row's count,
--      so it must be non-decreasing and never exceed OMEGA.
--   2. Positions within a row must be strictly increasing.
--   3. Every byte beyond the last index must be zero.
--
-- All three are exercised by dedicated malformed vectors; a decoder that
-- accepts any of them would pass a test built only from well-formed hints.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;

entity codec_d is
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;

    start   : in  std_logic;
    mode    : in  std_logic_vector(3 downto 0);
    base    : in  std_logic_vector(13 downto 0);
    done    : out std_logic;
    busy    : out std_logic;
    -- hint decode only: low when the input was malformed
    valid   : out std_logic;

    -- polynomial side
    p_raddr : out std_logic_vector(7 downto 0);
    p_rdata : in  std_logic_vector(C_CW - 1 downto 0);
    p_waddr : out std_logic_vector(7 downto 0);
    p_wdata : out std_logic_vector(C_CW - 1 downto 0);
    p_we    : out std_logic;
    -- which polynomial row the hint codec is working on
    p_row   : out integer range 0 to 5;

    -- byte side
    b_addr  : out std_logic_vector(13 downto 0);
    b_rdata : in  std_logic_vector(7 downto 0);
    b_wdata : out std_logic_vector(7 downto 0);
    b_we    : out std_logic);
end entity codec_d;

architecture rtl of codec_d is

  type t_fsm is (
    S_IDLE,
    -- generic bit packer: read coefficient, shift into accumulator, emit
    S_P_RD, S_P_RDW, S_P_ACC, S_P_EMIT, S_P_NEXT, S_P_FLUSH,
    -- generic bit unpacker
    S_U_RD, S_U_RDW, S_U_ACC, S_U_EMIT, S_U_NEXT,
    -- hint encode: walk rows, emit set positions, then the running totals
    S_HE_CLR, S_HE_RD, S_HE_RDW, S_HE_TEST, S_HE_WR, S_HE_NEXT,
    S_HE_ROW, S_HE_CNT, S_HE_CNTW,
    -- hint decode: clear, read counts, walk positions with validation
    S_HD_CLR, S_HD_CNT, S_HD_CNTW, S_HD_CHK, S_HD_POS, S_HD_POSW,
    S_HD_MONO, S_HD_SET, S_HD_NEXT, S_HD_ROW, S_HD_TAIL, S_HD_TAILW,
    S_HD_TNEXT,
    S_DONE, S_FAIL);

  signal fsm : t_fsm := S_IDLE;

  signal busy_r  : std_logic := '0';
  signal done_r  : std_logic := '0';
  signal valid_r : std_logic := '1';

  signal cnt  : integer range 0 to 4095 := 0;
  signal nacc : integer range 0 to 256 := 0;
  signal acc  : unsigned(31 downto 0) := (others => '0');
  signal nbit : integer range 0 to 63 := 0;
  signal fw   : integer range 0 to 20 := 10;   -- field width for this mode

  -- hint codec state
  signal row   : integer range 0 to 6 := 0;
  signal idx   : integer range 0 to 63 := 0;
  signal first : integer range 0 to 63 := 0;
  signal yi    : integer range 0 to 255 := 0;
  signal prev  : integer range 0 to 255 := 0;

  constant C_KK_D : integer := 6;

begin

  busy  <= busy_r;
  done  <= done_r;
  valid <= valid_r;
  p_row <= row when row < C_KK_D else 0;

  process (clk)
    variable fld : unsigned(19 downto 0);
    variable xv  : signed(C_CW - 1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        busy_r  <= '0';
        done_r  <= '0';
        valid_r <= '1';
        p_raddr <= (others => '0');
        p_waddr <= (others => '0');
        p_wdata <= (others => '0');
        p_we    <= '0';
        b_addr  <= (others => '0');
        b_wdata <= (others => '0');
        b_we    <= '0';
        cnt     <= 0;
        nacc    <= 0;
        acc     <= (others => '0');
        nbit    <= 0;
        fw      <= 10;
        row     <= 0;
        idx     <= 0;
        first   <= 0;
        yi      <= 0;
        prev    <= 0;
      else
        done_r <= '0';
        p_we   <= '0';
        b_we   <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r  <= '1';
              valid_r <= '1';
              cnt     <= 0;
              nacc    <= 0;
              acc     <= (others => '0');
              nbit    <= 0;
              row     <= 0;
              idx     <= 0;
              first   <= 0;
              prev    <= 0;
              case mode is
                when "0000" => fw <= 10; fsm <= S_P_RD;
                when "0001" => fw <= 4;  fsm <= S_P_RD;
                when "0010" => fw <= 4;  fsm <= S_P_RD;
                when "0011" => fw <= 13; fsm <= S_P_RD;
                when "0100" => fw <= 20; fsm <= S_P_RD;
                when "0101" => fw <= 20; fsm <= S_U_RD;
                when "0110" => fsm <= S_HE_CLR;
                when "0111" => fsm <= S_HD_CLR;
                when "1000" => fw <= 4;  fsm <= S_U_RD;
                when "1001" => fw <= 13; fsm <= S_U_RD;
                when others => fw <= 10; fsm <= S_U_RD;
              end case;
            end if;

          ----------------------------------------------------------------
          -- Bit packer. One coefficient in, fw bits into the accumulator,
          -- whole bytes out as they complete.
          ----------------------------------------------------------------
          when S_P_RD =>
            p_raddr <= std_logic_vector(to_unsigned(nacc, 8));
            fsm     <= S_P_RDW;

          when S_P_RDW =>
            fsm <= S_P_ACC;

          when S_P_ACC =>
            xv := signed(p_rdata);
            -- Map the coefficient into its unsigned field. The unsigned
            -- packings take the value directly; the signed ones store b - x
            -- with x taken as a centred representative.
            case mode is
              when "0000" | "0001" =>
                fld := resize(unsigned(xv(19 downto 0)), 20);
              when "0010" =>
                fld := resize(unsigned(
                         to_signed(C_ETA_DD, C_CW) - xv), 20);
              when "0011" =>
                fld := resize(unsigned(
                         to_signed(2 ** (C_D_D - 1), C_CW) - xv), 20);
              when others =>
                fld := resize(unsigned(
                         to_signed(C_GAMMA1_DD, C_CW) - xv), 20);
            end case;
            acc  <= acc or shift_left(resize(fld, 32), nbit);
            nbit <= nbit + fw;
            fsm  <= S_P_EMIT;

          when S_P_EMIT =>
            if nbit >= 8 then
              b_addr  <= std_logic_vector(
                           unsigned(base) + to_unsigned(cnt, 14));
              b_wdata <= std_logic_vector(acc(7 downto 0));
              b_we    <= '1';
              acc     <= shift_right(acc, 8);
              nbit    <= nbit - 8;
              cnt     <= cnt + 1;
            else
              fsm <= S_P_NEXT;
            end if;

          when S_P_NEXT =>
            if nacc = 255 then
              fsm <= S_P_FLUSH;
            else
              nacc <= nacc + 1;
              fsm  <= S_P_RD;
            end if;

          when S_P_FLUSH =>
            -- every width used here divides 256*fw into whole bytes, so the
            -- accumulator is empty; the state exists to make that explicit
            if nbit >= 8 then
              b_addr  <= std_logic_vector(
                           unsigned(base) + to_unsigned(cnt, 14));
              b_wdata <= std_logic_vector(acc(7 downto 0));
              b_we    <= '1';
              acc     <= shift_right(acc, 8);
              nbit    <= nbit - 8;
              cnt     <= cnt + 1;
            else
              fsm <= S_DONE;
            end if;

          ----------------------------------------------------------------
          -- Bit unpacker, currently used for z only.
          ----------------------------------------------------------------
          when S_U_RD =>
            b_addr <= std_logic_vector(
                        unsigned(base) + to_unsigned(cnt, 14));
            fsm    <= S_U_RDW;

          when S_U_RDW =>
            fsm <= S_U_ACC;

          when S_U_ACC =>
            acc  <= acc or shift_left(resize(unsigned(b_rdata), 32), nbit);
            nbit <= nbit + 8;
            cnt  <= cnt + 1;
            fsm  <= S_U_EMIT;

          when S_U_EMIT =>
            -- The offset differs per mode: z stores GAMMA1 - x, s stores
            -- eta - x and t0 stores 2^(D-1) - x. The shift must match the
            -- field width, not a fixed 20 bits.
            if nbit >= fw then
              p_waddr <= std_logic_vector(to_unsigned(nacc, 8));
              case mode is
                when "1000" =>
                  p_wdata <= std_logic_vector(
                               to_signed(C_ETA_DD, C_CW) -
                               signed(resize(acc(3 downto 0), C_CW)));
                when "1001" =>
                  p_wdata <= std_logic_vector(
                               to_signed(2 ** (C_D_D - 1), C_CW) -
                               signed(resize(acc(12 downto 0), C_CW)));
                when "1010" =>
                  -- t1 is unsigned and stored as-is; there is no offset,
                  -- unlike every other unpack mode.
                  p_wdata <= std_logic_vector(
                               signed(resize(acc(9 downto 0), C_CW)));
                when others =>
                  p_wdata <= std_logic_vector(
                               to_signed(C_GAMMA1_DD, C_CW) -
                               signed(resize(acc(19 downto 0), C_CW)));
              end case;
              p_we <= '1';
              acc  <= shift_right(acc, fw);
              nbit <= nbit - fw;
              fsm  <= S_U_NEXT;
            else
              fsm <= S_U_RD;
            end if;

          when S_U_NEXT =>
            if nacc = 255 then
              fsm <= S_DONE;
            else
              nacc <= nacc + 1;
              fsm  <= S_U_EMIT;
            end if;

          ----------------------------------------------------------------
          -- Hint encode. Walk each row in order, write the position of every
          -- set coefficient, then record the RUNNING TOTAL for that row.
          ----------------------------------------------------------------
          when S_HE_CLR =>
            b_addr  <= std_logic_vector(
                         unsigned(base) + to_unsigned(cnt, 14));
            b_wdata <= (others => '0');
            b_we    <= '1';
            if cnt = C_OMEGA_D + C_KK_D - 1 then
              cnt  <= 0;
              nacc <= 0;
              idx  <= 0;
              row  <= 0;
              fsm  <= S_HE_RD;
            else
              cnt <= cnt + 1;
            end if;

          when S_HE_RD =>
            p_raddr <= std_logic_vector(to_unsigned(nacc, 8));
            fsm     <= S_HE_RDW;

          when S_HE_RDW =>
            fsm <= S_HE_TEST;

          when S_HE_TEST =>
            if signed(p_rdata) /= 0 then
              fsm <= S_HE_WR;
            else
              fsm <= S_HE_NEXT;
            end if;

          when S_HE_WR =>
            b_addr  <= std_logic_vector(
                         unsigned(base) + to_unsigned(idx, 14));
            b_wdata <= std_logic_vector(to_unsigned(nacc, 8));
            b_we    <= '1';
            idx     <= idx + 1;
            fsm     <= S_HE_NEXT;

          when S_HE_NEXT =>
            if nacc = 255 then
              nacc <= 0;
              fsm  <= S_HE_CNT;
            else
              nacc <= nacc + 1;
              fsm  <= S_HE_RD;
            end if;

          when S_HE_CNT =>
            b_addr  <= std_logic_vector(
                         unsigned(base) +
                         to_unsigned(C_OMEGA_D + row, 13));
            b_wdata <= std_logic_vector(to_unsigned(idx, 8));
            b_we    <= '1';
            fsm     <= S_HE_CNTW;

          when S_HE_CNTW =>
            if row = C_KK_D - 1 then
              fsm <= S_DONE;
            else
              row <= row + 1;
              fsm <= S_HE_RD;
            end if;

          when S_HE_ROW =>
            fsm <= S_HE_RD;

          ----------------------------------------------------------------
          -- Hint decode with validation.
          ----------------------------------------------------------------
          when S_HD_CLR =>
            p_waddr <= std_logic_vector(to_unsigned(nacc, 8));
            p_wdata <= (others => '0');
            p_we    <= '1';
            if nacc = 255 then
              nacc <= 0;
              if row = C_KK_D - 1 then
                row <= 0;
                idx <= 0;
                fsm <= S_HD_CNT;
              else
                row <= row + 1;
              end if;
            else
              nacc <= nacc + 1;
            end if;

          when S_HD_CNT =>
            b_addr <= std_logic_vector(
                        unsigned(base) + to_unsigned(C_OMEGA_D + row, 14));
            fsm    <= S_HD_CNTW;

          when S_HD_CNTW =>
            fsm <= S_HD_CHK;

          when S_HD_CHK =>
            yi <= to_integer(unsigned(b_rdata));
            -- rule 1: the running total must not go backwards or exceed OMEGA
            if to_integer(unsigned(b_rdata)) < idx or
               to_integer(unsigned(b_rdata)) > C_OMEGA_D then
              fsm <= S_FAIL;
            else
              first <= idx;
              -- yi is assigned here and is visible in S_HD_POS, which runs
              -- on the following cycle. No settle state is needed: a signal
              -- assigned in one state IS readable in the next.
              fsm   <= S_HD_POS;
            end if;

          when S_HD_POS =>
            if idx >= yi then
              fsm <= S_HD_ROW;
            else
              b_addr <= std_logic_vector(
                          unsigned(base) + to_unsigned(idx, 14));
              fsm    <= S_HD_POSW;
            end if;

          when S_HD_POSW =>
            fsm <= S_HD_MONO;

          when S_HD_MONO =>
            -- rule 2: positions within a row must strictly increase
            if idx > first and to_integer(unsigned(b_rdata)) <= prev then
              fsm <= S_FAIL;
            else
              prev <= to_integer(unsigned(b_rdata));
              fsm  <= S_HD_SET;
            end if;

          when S_HD_SET =>
            -- prev was assigned in S_HD_MONO, which ran on the previous
            -- cycle, so it already holds the current position. Writing
            -- b_rdata here would be equivalent; prev is used because it is
            -- the value the monotonicity test just accepted.
            p_waddr <= std_logic_vector(to_unsigned(prev, 8));
            p_wdata <= std_logic_vector(to_signed(1, C_CW));
            p_we    <= '1';
            idx     <= idx + 1;
            fsm     <= S_HD_POS;

          when S_HD_NEXT =>
            fsm <= S_HD_POS;

          when S_HD_ROW =>
            -- prev is per-row: the monotonicity rule applies within a row,
            -- not across the boundary, and first marks where the row began.
            prev <= 0;
            if row = C_KK_D - 1 then
              cnt <= idx;
              fsm <= S_HD_TAIL;
            else
              row <= row + 1;
              fsm <= S_HD_CNT;
            end if;

          when S_HD_TAIL =>
            -- rule 3: every byte past the last index must be zero
            if cnt >= C_OMEGA_D then
              fsm <= S_DONE;
            else
              b_addr <= std_logic_vector(
                          unsigned(base) + to_unsigned(cnt, 14));
              fsm    <= S_HD_TAILW;
            end if;

          when S_HD_TAILW =>
            fsm <= S_HD_TNEXT;

          when S_HD_TNEXT =>
            if unsigned(b_rdata) /= 0 then
              fsm <= S_FAIL;
            else
              cnt <= cnt + 1;
              fsm <= S_HD_TAIL;
            end if;

          when S_FAIL =>
            valid_r <= '0';
            busy_r  <= '0';
            done_r  <= '1';
            fsm     <= S_IDLE;

          when S_DONE =>
            busy_r <= '0';
            done_r <= '1';
            fsm    <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
