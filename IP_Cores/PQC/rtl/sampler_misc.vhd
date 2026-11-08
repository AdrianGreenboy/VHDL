-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1
-- sampler_misc: SamplePolyCBD for ML-KEM.
--   sampler_cbd_k    SamplePolyCBD eta=2   FIPS 203 Algorithm 8
-- VHDL-2008. ASCII-only. MIT license.
--
-- The four Layer 1 ML-DSA sampler prototypes that used to live here
-- (sampler_rej_d, sampler_bnd_d, sampler_ball_d, sampler_mask_d) are not
-- instantiated by any production core: the ML-DSA datapath uses the unified
-- sampler_d.vhd. They were moved to legacy/sampler_misc_l1_d.vhd by the
-- 2026-11 audit and are compiled only for the Layer 1 tb_sampler.
--
-- The sampler consumes the sponge through the incremental squeeze interface.
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
