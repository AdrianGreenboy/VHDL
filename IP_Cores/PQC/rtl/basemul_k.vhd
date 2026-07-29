-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3 support block
-- basemul_k: MultiplyNTTs / BaseCaseMultiply, FIPS 203 Algorithms 11 and 12.
-- VHDL-2008. ASCII-only. MIT license.
--
-- The Kyber NTT stops one layer short of full diagonalisation, so the
-- pointwise product is not element by element: coefficients pair up and each
-- pair is multiplied in the quotient ring Z_q[X]/(X^2 - gamma_i), giving
--   c(2i)   = a(2i)*b(2i) + a(2i+1)*b(2i+1)*gamma_i
--   c(2i+1) = a(2i)*b(2i+1) + a(2i+1)*b(2i)
-- with gamma_i taken from the precomputed table in Montgomery domain.
--
-- Every product is reduced with the same signed Montgomery reduction used by
-- the NTT unit, so no `mod` appears in the datapath. An optional accumulate
-- mode adds into the destination, which is what the matrix-vector products of
-- KeyGen and Encaps need.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity basemul_k is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;
    accum     : in  std_logic;                       -- '1' adds into dst
    -- operand A port
    a_addr    : out std_logic_vector(7 downto 0);
    a_data    : in  std_logic_vector(15 downto 0);
    -- operand B port
    b_addr    : out std_logic_vector(7 downto 0);
    b_data    : in  std_logic_vector(15 downto 0);
    -- destination port (read for accumulate, then write)
    d_addr    : out std_logic_vector(7 downto 0);
    d_rdata   : in  std_logic_vector(15 downto 0);
    d_wdata   : out std_logic_vector(15 downto 0);
    d_we      : out std_logic;
    busy      : out std_logic;
    done      : out std_logic);
end entity basemul_k;

architecture rtl of basemul_k is

  type t_fsm is (S_IDLE, S_RD0, S_RD1, S_RD2, S_CALC,
                 S_ACC0, S_ACC0D, S_ACC0W, S_WR0,
                 S_ACC1, S_ACC1D, S_ACC1W, S_WR1, S_NEXT,
                 S_DONE);

  signal fsm    : t_fsm := S_IDLE;
  signal pair   : integer range 0 to 128 := 0;
  signal a0     : signed(15 downto 0) := (others => '0');
  signal a1     : signed(15 downto 0) := (others => '0');
  signal b0     : signed(15 downto 0) := (others => '0');
  signal b1     : signed(15 downto 0) := (others => '0');
  signal c0     : signed(15 downto 0) := (others => '0');
  signal c1     : signed(15 downto 0) := (others => '0');
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';
  signal acc_r  : std_logic := '0';

  -- Signed Montgomery reduction, R = 2^16, identical to the NTT unit.
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

begin

  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable p    : signed(31 downto 0);
    variable t0   : signed(15 downto 0);
    variable t1   : signed(15 downto 0);
    variable gam  : signed(15 downto 0);
    variable av1  : signed(15 downto 0);
    variable bv1  : signed(15 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        pair    <= 0;
        busy_r  <= '0';
        done_r  <= '0';
        d_we    <= '0';
        a_addr  <= (others => '0');
        b_addr  <= (others => '0');
        d_addr  <= (others => '0');
        d_wdata <= (others => '0');
      else
        done_r <= '0';
        d_we   <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              pair   <= 0;
              acc_r  <= accum;
              busy_r <= '1';
              fsm    <= S_RD0;
            end if;

          when S_RD0 =>
            a_addr <= std_logic_vector(to_unsigned(2 * pair, 8));
            b_addr <= std_logic_vector(to_unsigned(2 * pair, 8));
            fsm    <= S_RD1;

          when S_RD1 =>
            -- even coefficients arrive next cycle; request the odd ones now
            a_addr <= std_logic_vector(to_unsigned(2 * pair + 1, 8));
            b_addr <= std_logic_vector(to_unsigned(2 * pair + 1, 8));
            fsm    <= S_RD2;

          when S_RD2 =>
            a0  <= signed(a_data);
            b0  <= signed(b_data);
            fsm <= S_CALC;

          when S_CALC =>
            -- The odd coefficients are on the memory buses this cycle. They
            -- must be read from a_data / b_data directly: assigning them to
            -- a1 / b1 here would not take effect until the next cycle, so
            -- using the signals would silently multiply the previous pair.
            av1 := signed(a_data);
            bv1 := signed(b_data);
            a1  <= av1;
            b1  <= bv1;
            -- c0 = a0*b0 + mont(a1*b1)*gamma, c1 = a0*b1 + a1*b0
            gam := to_signed(C_GAMMA_K(pair), 16);
            p   := av1 * bv1;
            t1  := mont16(p);
            p   := t1 * gam;
            t1  := mont16(p);
            p   := a0 * b0;
            t0  := mont16(p);
            c0  <= range_reduce(t0 + t1);
            p   := a0 * bv1;
            t0  := mont16(p);
            p   := av1 * b0;
            t1  := mont16(p);
            c1  <= range_reduce(t0 + t1);
            if acc_r = '1' then
              fsm <= S_ACC0;
            else
              fsm <= S_WR0;
            end if;

          when S_ACC0 =>
            d_addr <= std_logic_vector(to_unsigned(2 * pair, 8));
            fsm    <= S_ACC0D;

          -- One settle state: the destination memory is synchronous, so data
          -- for the address issued above is only valid on the cycle after the
          -- address register updates.
          when S_ACC0D =>
            fsm <= S_ACC0W;

          when S_ACC0W =>
            c0  <= range_reduce(c0 + signed(d_rdata));
            fsm <= S_WR0;

          when S_WR0 =>
            d_addr  <= std_logic_vector(to_unsigned(2 * pair, 8));
            d_wdata <= std_logic_vector(c0);
            d_we    <= '1';
            if acc_r = '1' then
              fsm <= S_ACC1;
            else
              fsm <= S_WR1;
            end if;

          when S_ACC1 =>
            d_addr <= std_logic_vector(to_unsigned(2 * pair + 1, 8));
            fsm    <= S_ACC1D;

          when S_ACC1D =>
            fsm <= S_ACC1W;

          when S_ACC1W =>
            c1  <= range_reduce(c1 + signed(d_rdata));
            fsm <= S_WR1;

          when S_WR1 =>
            d_addr  <= std_logic_vector(to_unsigned(2 * pair + 1, 8));
            d_wdata <= std_logic_vector(c1);
            d_we    <= '1';
            fsm     <= S_NEXT;

          when S_NEXT =>
            if pair = 127 then
              fsm <= S_DONE;
            else
              pair <= pair + 1;
              fsm  <= S_RD0;
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
