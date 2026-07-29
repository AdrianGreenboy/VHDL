-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1
-- sampler_ntt_k: SampleNTT, FIPS 203 Algorithm 7.
-- Consumes SHAKE128 through the incremental squeeze interface and produces
-- 256 coefficients in [0, q) with q = 3329.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Each group of 3 squeezed bytes yields two 12-bit candidates:
--   d1 = b0 + 256 * (b1 mod 16)
--   d2 = floor(b1 / 16) + 16 * b2
-- A candidate is accepted only if it is strictly less than q. Rejection makes
-- byte consumption data-dependent by design; this is a public property of the
-- algorithm and not a side channel, since the seed is public in ExpandA.
--
-- The sponge is driven by the parent block. This unit only asks for bytes.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity sampler_ntt_k is
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    start      : in  std_logic;
    -- sponge squeeze interface
    sq_data    : in  std_logic_vector(7 downto 0);
    sq_valid   : in  std_logic;
    sq_re      : out std_logic;
    -- coefficient output
    co_addr    : out std_logic_vector(7 downto 0);
    co_data    : out std_logic_vector(15 downto 0);
    co_we      : out std_logic;
    busy       : out std_logic;
    done       : out std_logic);
end entity sampler_ntt_k;

architecture rtl of sampler_ntt_k is

  type t_fsm is (S_IDLE, S_B0, S_W0, S_B1, S_W1, S_B2, S_W2,
                 S_EMIT1, S_EMIT2, S_DONE);

  signal fsm    : t_fsm := S_IDLE;
  signal b0     : unsigned(7 downto 0) := (others => '0');
  signal b1     : unsigned(7 downto 0) := (others => '0');
  signal b2     : unsigned(7 downto 0) := (others => '0');
  signal cnt    : integer range 0 to 256 := 0;
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  constant C_Q : unsigned(11 downto 0) := to_unsigned(C_QK, 12);

begin

  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable d1 : unsigned(11 downto 0);
    variable d2 : unsigned(11 downto 0);
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

          -- Every fetch is followed by a settle state. The sponge registers
          -- its output on the same edge that consumes sq_re, so sampling the
          -- next byte one cycle later is mandatory, not optional.
          when S_B0 =>
            if sq_valid = '1' then
              b0    <= unsigned(sq_data);
              sq_re <= '1';
              fsm   <= S_W0;
            end if;

          when S_W0 =>
            fsm <= S_B1;

          when S_B1 =>
            if sq_valid = '1' then
              b1    <= unsigned(sq_data);
              sq_re <= '1';
              fsm   <= S_W1;
            end if;

          when S_W1 =>
            fsm <= S_B2;

          when S_B2 =>
            if sq_valid = '1' then
              b2    <= unsigned(sq_data);
              sq_re <= '1';
              fsm   <= S_W2;
            end if;

          when S_W2 =>
            fsm <= S_EMIT1;

          -- Both emit states share one termination rule: the polynomial is
          -- complete as soon as 256 coefficients have been written, whichever
          -- candidate of the pair produced the last one. Handling termination
          -- only in the second emit state would drop a full byte triple when
          -- the 256th coefficient came from the first candidate.
          when S_EMIT1 =>
            d1 := b1(3 downto 0) & b0;
            if d1 < C_Q then
              co_addr <= std_logic_vector(to_unsigned(cnt, 8));
              co_data <= std_logic_vector(resize(d1, 16));
              co_we   <= '1';
              if cnt = 255 then
                cnt <= 256;
                fsm <= S_DONE;
              else
                cnt <= cnt + 1;
                fsm <= S_EMIT2;
              end if;
            else
              fsm <= S_EMIT2;
            end if;

          when S_EMIT2 =>
            d2 := b2 & b1(7 downto 4);
            if d2 < C_Q then
              co_addr <= std_logic_vector(to_unsigned(cnt, 8));
              co_data <= std_logic_vector(resize(d2, 16));
              co_we   <= '1';
              if cnt = 255 then
                cnt <= 256;
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
