-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1
-- sampler_misc: the five remaining samplers of the frozen scope.
--   sampler_cbd_k    SamplePolyCBD eta=2   FIPS 203 Algorithm 8
--   sampler_rej_d    RejNTTPoly            FIPS 204 Algorithm 30
--   sampler_bnd_d    RejBoundedPoly eta=4  FIPS 204 Algorithm 31
--   sampler_ball_d   SampleInBall tau=49   FIPS 204 Algorithm 29
--   sampler_mask_d   ExpandMask gamma1=2^19 FIPS 204 Algorithm 34
-- VHDL-2008. ASCII-only. MIT license.
--
-- All five consume the sponge through the same incremental squeeze interface.
-- Coefficients leave in canonical range [0, q) so downstream blocks see one
-- consistent representation.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

-- -----------------------------------------------------------------------------
-- S2: SamplePolyCBD, eta = 2, q = 3329.
-- Consumes 128 bytes. Each byte carries two coefficients: bits [1:0] and [3:2]
-- form the first pair, bits [5:4] and [7:6] the second. There is no rejection,
-- so consumption is fixed at 128 bytes for 256 coefficients.
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity sampler_cbd_k is
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    start    : in  std_logic;
    sq_data  : in  std_logic_vector(7 downto 0);
    sq_valid : in  std_logic;
    sq_re    : out std_logic;
    co_addr  : out std_logic_vector(7 downto 0);
    co_data  : out std_logic_vector(15 downto 0);
    co_we    : out std_logic;
    busy     : out std_logic;
    done     : out std_logic);
end entity sampler_cbd_k;

architecture rtl of sampler_cbd_k is
  -- Every fetch is followed by a settle state: the sponge registers its
  -- output on the same edge that consumes sq_re.
  type t_fsm is (S_IDLE, S_FETCH, S_WAIT, S_LOW, S_HIGH, S_DONE);
  signal fsm    : t_fsm := S_IDLE;
  signal byt    : unsigned(7 downto 0) := (others => '0');
  signal cnt    : integer range 0 to 256 := 0;
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  -- x - y with x, y in {0,1,2}: result in {-2..2}, mapped into [0, q).
  function cbd_pair (x : unsigned(1 downto 0); y : unsigned(1 downto 0))
    return unsigned is
    variable a : integer;
    variable b : integer;
    variable d : integer;
  begin
    a := to_integer(x(0 downto 0)) + to_integer(x(1 downto 1));
    b := to_integer(y(0 downto 0)) + to_integer(y(1 downto 1));
    d := a - b;
    if d < 0 then
      d := d + C_QK;
    end if;
    return to_unsigned(d, 16);
  end function cbd_pair;

begin
  busy <= busy_r;
  done <= done_r;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        cnt     <= 0;
        busy_r  <= '0';
        done_r  <= '0';
        sq_re   <= '0';
        co_we   <= '0';
        co_addr <= (others => '0');
        co_data <= (others => '0');
      else
        done_r <= '0';
        co_we  <= '0';
        sq_re  <= '0';

        case fsm is
          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              cnt    <= 0;
              busy_r <= '1';
              fsm    <= S_FETCH;
            end if;

          when S_FETCH =>
            if sq_valid = '1' then
              byt   <= unsigned(sq_data);
              sq_re <= '1';
              fsm   <= S_WAIT;
            end if;

          when S_WAIT =>
            fsm <= S_LOW;

          when S_LOW =>
            co_addr <= std_logic_vector(to_unsigned(cnt, 8));
            co_data <= std_logic_vector(cbd_pair(byt(1 downto 0),
                                                 byt(3 downto 2)));
            co_we   <= '1';
            cnt     <= cnt + 1;
            fsm     <= S_HIGH;

          when S_HIGH =>
            co_addr <= std_logic_vector(to_unsigned(cnt, 8));
            co_data <= std_logic_vector(cbd_pair(byt(5 downto 4),
                                                 byt(7 downto 6)));
            co_we   <= '1';
            if cnt = 255 then
              fsm <= S_DONE;
            else
              cnt <= cnt + 1;
              fsm <= S_FETCH;
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

-- -----------------------------------------------------------------------------
-- S3: RejNTTPoly, q = 8380417.
-- Each group of 3 bytes forms one 23-bit candidate; the top bit of the third
-- byte is masked off. Accepted only if strictly less than q.
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity sampler_rej_d is
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    start    : in  std_logic;
    sq_data  : in  std_logic_vector(7 downto 0);
    sq_valid : in  std_logic;
    sq_re    : out std_logic;
    co_addr  : out std_logic_vector(7 downto 0);
    co_data  : out std_logic_vector(31 downto 0);
    co_we    : out std_logic;
    busy     : out std_logic;
    done     : out std_logic);
end entity sampler_rej_d;

architecture rtl of sampler_rej_d is
  -- Fetch states alternate with settle states (sponge output timing).
  type t_fsm is (S_IDLE, S_B0, S_W0, S_B1, S_W1, S_B2, S_W2, S_EMIT, S_DONE);
  signal fsm    : t_fsm := S_IDLE;
  signal b0     : unsigned(7 downto 0) := (others => '0');
  signal b1     : unsigned(7 downto 0) := (others => '0');
  signal b2     : unsigned(7 downto 0) := (others => '0');
  signal cnt    : integer range 0 to 256 := 0;
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';
begin
  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable z : unsigned(22 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        cnt     <= 0;
        busy_r  <= '0';
        done_r  <= '0';
        sq_re   <= '0';
        co_we   <= '0';
        co_addr <= (others => '0');
        co_data <= (others => '0');
      else
        done_r <= '0';
        co_we  <= '0';
        sq_re  <= '0';

        case fsm is
          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              cnt    <= 0;
              busy_r <= '1';
              fsm    <= S_B0;
            end if;

          when S_B0 =>
            if sq_valid = '1' then
              b0 <= unsigned(sq_data); sq_re <= '1'; fsm <= S_W0;
            end if;

          when S_W0 =>
            fsm <= S_B1;

          when S_B1 =>
            if sq_valid = '1' then
              b1 <= unsigned(sq_data); sq_re <= '1'; fsm <= S_W1;
            end if;

          when S_W1 =>
            fsm <= S_B2;

          when S_B2 =>
            if sq_valid = '1' then
              b2 <= unsigned(sq_data); sq_re <= '1'; fsm <= S_W2;
            end if;

          when S_W2 =>
            fsm <= S_EMIT;

          when S_EMIT =>
            -- 23-bit candidate: top bit of b2 masked off
            z := b2(6 downto 0) & b1 & b0;
            if z < to_unsigned(C_QD, 23) then
              co_addr <= std_logic_vector(to_unsigned(cnt, 8));
              co_data <= std_logic_vector(resize(z, 32));
              co_we   <= '1';
              if cnt = 255 then
                fsm <= S_DONE;
              else
                cnt <= cnt + 1;
                fsm <= S_B0;
              end if;
            else
              fsm <= S_B0;
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

-- -----------------------------------------------------------------------------
-- S4: RejBoundedPoly, eta = 4.
-- Each byte gives two nibbles. A nibble is accepted if it is less than 9, and
-- the coefficient is eta - nibble, mapped into [0, q).
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity sampler_bnd_d is
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    start    : in  std_logic;
    sq_data  : in  std_logic_vector(7 downto 0);
    sq_valid : in  std_logic;
    sq_re    : out std_logic;
    co_addr  : out std_logic_vector(7 downto 0);
    co_data  : out std_logic_vector(31 downto 0);
    co_we    : out std_logic;
    busy     : out std_logic;
    done     : out std_logic);
end entity sampler_bnd_d;

architecture rtl of sampler_bnd_d is
  -- Fetch is followed by a settle state (sponge output timing).
  type t_fsm is (S_IDLE, S_FETCH, S_WAIT, S_LOW, S_HIGH, S_DONE);
  signal fsm    : t_fsm := S_IDLE;
  signal byt    : unsigned(7 downto 0) := (others => '0');
  signal cnt    : integer range 0 to 256 := 0;
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';
  constant C_ETA : integer := 4;

  function bnd_coef (nib : unsigned(3 downto 0)) return unsigned is
    variable d : integer;
  begin
    d := C_ETA - to_integer(nib);
    if d < 0 then
      d := d + C_QD;
    end if;
    return to_unsigned(d, 32);
  end function bnd_coef;
begin
  busy <= busy_r;
  done <= done_r;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        cnt     <= 0;
        busy_r  <= '0';
        done_r  <= '0';
        sq_re   <= '0';
        co_we   <= '0';
        co_addr <= (others => '0');
        co_data <= (others => '0');
      else
        done_r <= '0';
        co_we  <= '0';
        sq_re  <= '0';

        case fsm is
          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              cnt    <= 0;
              busy_r <= '1';
              fsm    <= S_FETCH;
            end if;

          when S_FETCH =>
            if sq_valid = '1' then
              byt   <= unsigned(sq_data);
              sq_re <= '1';
              fsm   <= S_WAIT;
            end if;

          when S_WAIT =>
            fsm <= S_LOW;

          when S_LOW =>
            if byt(3 downto 0) < 9 then
              co_addr <= std_logic_vector(to_unsigned(cnt, 8));
              co_data <= std_logic_vector(bnd_coef(byt(3 downto 0)));
              co_we   <= '1';
              if cnt = 255 then
                fsm <= S_DONE;
              else
                cnt <= cnt + 1;
                fsm <= S_HIGH;
              end if;
            else
              fsm <= S_HIGH;
            end if;

          when S_HIGH =>
            if byt(7 downto 4) < 9 then
              co_addr <= std_logic_vector(to_unsigned(cnt, 8));
              co_data <= std_logic_vector(bnd_coef(byt(7 downto 4)));
              co_we   <= '1';
              if cnt = 255 then
                fsm <= S_DONE;
              else
                cnt <= cnt + 1;
                fsm <= S_FETCH;
              end if;
            else
              fsm <= S_FETCH;
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

-- -----------------------------------------------------------------------------
-- S5: SampleInBall, tau = 49.
-- The first 8 squeezed bytes supply the sign bits. Then, for i from 256-tau to
-- 255, bytes are drawn until one is at most i; that position is swapped with i
-- and given a sign. The polynomial is zeroed first, so exactly tau entries end
-- up non-zero.
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity sampler_ball_d is
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    start    : in  std_logic;
    sq_data  : in  std_logic_vector(7 downto 0);
    sq_valid : in  std_logic;
    sq_re    : out std_logic;
    co_addr  : out std_logic_vector(7 downto 0);
    co_data  : out std_logic_vector(31 downto 0);
    co_we    : out std_logic;
    -- read-back port, needed for the swap
    rb_addr  : out std_logic_vector(7 downto 0);
    rb_data  : in  std_logic_vector(31 downto 0);
    busy     : out std_logic;
    done     : out std_logic);
end entity sampler_ball_d;

architecture rtl of sampler_ball_d is
  -- Sign and draw fetches each need a settle state (sponge output timing).
  type t_fsm is (S_IDLE, S_ZERO, S_SIGN, S_SIGN_W, S_DRAW, S_DRAW_W, S_TEST,
                 S_RD, S_RD_WAIT, S_WR_J, S_WR_I, S_DONE);
  signal fsm    : t_fsm := S_IDLE;
  signal signs  : unsigned(63 downto 0) := (others => '0');
  signal nsign  : integer range 0 to 8 := 0;
  signal i_idx  : integer range 0 to 256 := 0;
  signal j_idx  : integer range 0 to 255 := 0;
  signal sbit   : integer range 0 to 63 := 0;
  signal cval   : unsigned(31 downto 0) := (others => '0');
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';
  constant C_TAU : integer := 49;
begin
  busy <= busy_r;
  done <= done_r;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        busy_r  <= '0';
        done_r  <= '0';
        sq_re   <= '0';
        co_we   <= '0';
        co_addr <= (others => '0');
        co_data <= (others => '0');
        rb_addr <= (others => '0');
        i_idx   <= 0;
        nsign   <= 0;
        sbit    <= 0;
      else
        done_r <= '0';
        co_we  <= '0';
        sq_re  <= '0';

        case fsm is
          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r <= '1';
              i_idx  <= 0;
              nsign  <= 0;
              sbit   <= 0;
              signs  <= (others => '0');
              fsm    <= S_ZERO;
            end if;

          when S_ZERO =>
            co_addr <= std_logic_vector(to_unsigned(i_idx, 8));
            co_data <= (others => '0');
            co_we   <= '1';
            if i_idx = 255 then
              i_idx <= 0;
              fsm   <= S_SIGN;
            else
              i_idx <= i_idx + 1;
            end if;

          when S_SIGN =>
            if sq_valid = '1' then
              -- sign bits arrive little-endian across 8 bytes
              signs(8 * nsign + 7 downto 8 * nsign) <= unsigned(sq_data);
              sq_re <= '1';
              fsm   <= S_SIGN_W;
            end if;

          when S_SIGN_W =>
            if nsign = 7 then
              i_idx <= 256 - C_TAU;
              fsm   <= S_DRAW;
            else
              nsign <= nsign + 1;
              fsm   <= S_SIGN;
            end if;

          when S_DRAW =>
            if sq_valid = '1' then
              j_idx <= to_integer(unsigned(sq_data));
              sq_re <= '1';
              fsm   <= S_DRAW_W;
            end if;

          when S_DRAW_W =>
            fsm <= S_TEST;

          when S_TEST =>
            -- reject the drawn position if it exceeds the current index
            if j_idx <= i_idx then
              fsm <= S_RD;
            else
              fsm <= S_DRAW;
            end if;

          when S_RD =>
            rb_addr <= std_logic_vector(to_unsigned(j_idx, 8));
            fsm     <= S_RD_WAIT;

          when S_RD_WAIT =>
            fsm <= S_WR_J;

          when S_WR_J =>
            -- c[i] = c[j]
            cval    <= unsigned(rb_data);
            co_addr <= std_logic_vector(to_unsigned(i_idx, 8));
            co_data <= rb_data;
            co_we   <= '1';
            fsm     <= S_WR_I;

          when S_WR_I =>
            -- c[j] = +1 or q-1 according to the next sign bit
            co_addr <= std_logic_vector(to_unsigned(j_idx, 8));
            if signs(sbit) = '1' then
              co_data <= std_logic_vector(to_unsigned(C_QD - 1, 32));
            else
              co_data <= std_logic_vector(to_unsigned(1, 32));
            end if;
            co_we <= '1';
            sbit  <= sbit + 1;
            if i_idx = 255 then
              fsm <= S_DONE;
            else
              i_idx <= i_idx + 1;
              fsm   <= S_DRAW;
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

-- -----------------------------------------------------------------------------
-- S6: ExpandMask, gamma1 = 2^19.
-- Unpacks 20-bit fields little-endian from the squeezed stream and returns
-- gamma1 - z, mapped into [0, q). Consumption is fixed: 640 bytes per
-- polynomial, no rejection.
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity sampler_mask_d is
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    start    : in  std_logic;
    sq_data  : in  std_logic_vector(7 downto 0);
    sq_valid : in  std_logic;
    sq_re    : out std_logic;
    co_addr  : out std_logic_vector(7 downto 0);
    co_data  : out std_logic_vector(31 downto 0);
    co_we    : out std_logic;
    busy     : out std_logic;
    done     : out std_logic);
end entity sampler_mask_d;

architecture rtl of sampler_mask_d is
  -- Fetch is followed by a settle state (sponge output timing).
  type t_fsm is (S_IDLE, S_FETCH, S_WAIT, S_EMIT, S_DONE);
  signal fsm    : t_fsm := S_IDLE;
  signal acc    : unsigned(31 downto 0) := (others => '0');
  signal nbits  : integer range 0 to 31 := 0;
  signal cnt    : integer range 0 to 256 := 0;
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';
  constant C_GAMMA1 : integer := 524288;   -- 2^19
begin
  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable z : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        cnt     <= 0;
        nbits   <= 0;
        acc     <= (others => '0');
        busy_r  <= '0';
        done_r  <= '0';
        sq_re   <= '0';
        co_we   <= '0';
        co_addr <= (others => '0');
        co_data <= (others => '0');
      else
        done_r <= '0';
        co_we  <= '0';
        sq_re  <= '0';

        case fsm is
          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              cnt    <= 0;
              nbits  <= 0;
              acc    <= (others => '0');
              busy_r <= '1';
              fsm    <= S_FETCH;
            end if;

          when S_FETCH =>
            if sq_valid = '1' then
              -- append the new byte above the bits already held
              acc(nbits + 7 downto nbits) <= unsigned(sq_data);
              nbits <= nbits + 8;
              sq_re <= '1';
              fsm   <= S_WAIT;
            end if;

          when S_WAIT =>
            if nbits >= 20 then
              fsm <= S_EMIT;
            else
              fsm <= S_FETCH;
            end if;

          when S_EMIT =>
            z := C_GAMMA1 - to_integer(acc(19 downto 0));
            if z < 0 then
              z := z + C_QD;
            end if;
            co_addr <= std_logic_vector(to_unsigned(cnt, 8));
            co_data <= std_logic_vector(to_unsigned(z, 32));
            co_we   <= '1';
            acc     <= shift_right(acc, 20);
            nbits   <= nbits - 20;
            if cnt = 255 then
              fsm <= S_DONE;
            else
              cnt <= cnt + 1;
              fsm <= S_FETCH;
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
