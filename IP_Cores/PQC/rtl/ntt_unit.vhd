-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1
-- ntt_unit: iterative NTT / INTT over a 256-coefficient polynomial.
-- Instantiated twice, dedicated and serialized (frozen scope decision 3):
--   NTT-K : q = 3329,    R = 2^16, 7 layers (butterfly length 128 down to 2)
--   NTT-D : q = 8380417, R = 2^32, 8 layers (butterfly length 128 down to 1)
-- VHDL-2008. ASCII-only. MIT license.
--
-- Arithmetic policy (frozen scope section 3): the VHDL `mod` operator never
-- appears in the datapath. Modular reduction is signed Montgomery
-- (one multiply, one mask, one multiply, one subtract, one arithmetic shift)
-- and range reduction is a conditional add/sub of 2q, which synthesises to a
-- comparator plus an adder rather than a divider.
--
-- Coefficients are held in signed range (-q, q) at every layer boundary, so
-- the datapath width has 256x headroom for NTT-D and never overflows.
--
-- Handshake: pulse start with mem pre-loaded; done pulses when the transform
-- is complete and the result is back in the same memory.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity ntt_unit is
  generic (
    G_Q       : integer;              -- modulus
    G_QINV    : integer;              -- q^-1 mod R (positive form)
    G_RBITS   : integer;              -- log2(R): 16 for Kyber, 32 for Dilithium
    G_WIDTH   : integer;              -- coefficient datapath width
    G_LAYERS  : integer;              -- 7 for Kyber, 8 for Dilithium
    G_SCALE   : integer);             -- final INTT scaling, Montgomery domain
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;
    inverse   : in  std_logic;        -- '0' = forward NTT, '1' = inverse
    -- coefficient memory port (simple dual port, external)
    rd_addr   : out std_logic_vector(7 downto 0);
    rd_data   : in  std_logic_vector(G_WIDTH - 1 downto 0);
    wr_addr   : out std_logic_vector(7 downto 0);
    wr_data   : out std_logic_vector(G_WIDTH - 1 downto 0);
    wr_en     : out std_logic;
    busy      : out std_logic;
    done      : out std_logic);
end entity ntt_unit;

architecture rtl of ntt_unit is

  subtype t_coef is signed(G_WIDTH - 1 downto 0);

  type t_fsm is (S_IDLE, S_RD0, S_RD1, S_WAIT, S_CALC, S_WR0, S_WR1,
                 S_NEXT, S_SCALE_RD, S_SCALE_WAIT, S_SCALE_WR, S_DONE);

  signal fsm     : t_fsm := S_IDLE;

  signal layer   : integer range 0 to 8 := 0;
  signal ln      : integer range 0 to 128 := 128;
  signal blk     : integer range 0 to 255 := 0;
  signal jj      : integer range 0 to 255 := 0;
  signal tw_idx  : integer range 0 to 256 := 0;
  signal sc_idx  : integer range 0 to 255 := 0;

  signal a_val   : t_coef := (others => '0');
  signal res_a   : t_coef := (others => '0');
  signal res_b   : t_coef := (others => '0');

  signal busy_r  : std_logic := '0';
  signal done_r  : std_logic := '0';
  signal inv_r   : std_logic := '0';

  -- Signed Montgomery reduction: returns a * R^-1 mod q, |result| < q.
  function mont_reduce (a : signed) return t_coef is
    variable lo   : signed(G_RBITS downto 0);
    variable t    : signed(G_RBITS downto 0);
    variable prod : signed(a'length + G_RBITS + 1 downto 0);
    variable num  : signed(a'length + G_RBITS + 1 downto 0);
  begin
    -- low R bits of a, interpreted as a signed R-bit number
    lo   := resize(signed(a(G_RBITS - 1 downto 0)), G_RBITS + 1);
    t    := resize(lo * to_signed(G_QINV, G_RBITS + 2), G_RBITS + 1);
    -- keep only the low R bits of t, signed
    t    := resize(signed(t(G_RBITS - 1 downto 0)), G_RBITS + 1);
    prod := resize(t * to_signed(G_Q, G_RBITS + 2), prod'length);
    num  := resize(a, num'length) - prod;
    return resize(shift_right(num, G_RBITS), G_WIDTH);
  end function mont_reduce;

  -- Range reduction into (-q, q) by conditional add/sub of 2q.
  function range_reduce (x : t_coef) return t_coef is
    variable v : t_coef;
  begin
    v := x;
    if v >= to_signed(G_Q, G_WIDTH) then
      v := v - to_signed(2 * G_Q, G_WIDTH);
    elsif v < -to_signed(G_Q, G_WIDTH) then
      v := v + to_signed(2 * G_Q, G_WIDTH);
    end if;
    return v;
  end function range_reduce;

  function get_zeta (idx : integer) return integer is
  begin
    if G_LAYERS = 7 then
      return C_ZETA_K(idx mod 128);
    else
      return C_ZETA_D(idx mod 256);
    end if;
  end function get_zeta;

begin

  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable zeta   : t_coef;
    variable prod   : signed(2 * G_WIDTH - 1 downto 0);
    variable tval   : t_coef;
    variable last_ln : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        busy_r  <= '0';
        done_r  <= '0';
        wr_en   <= '0';
        -- Address ports are driven from reset: an undriven port would make the
        -- memory model convert 'U' every cycle, flooding the log with
        -- metavalue warnings that would mask real ones.
        rd_addr <= (others => '0');
        wr_addr <= (others => '0');
        wr_data <= (others => '0');
        layer   <= 0;
        ln      <= 128;
        blk     <= 0;
        jj      <= 0;
        tw_idx  <= 0;
        sc_idx  <= 0;
      else
        done_r <= '0';
        wr_en  <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r <= '1';
              inv_r  <= inverse;
              layer  <= 0;
              blk    <= 0;
              jj     <= 0;
              if inverse = '0' then
                ln     <= 128;
                tw_idx <= 1;
              else
                if G_LAYERS = 7 then
                  ln     <= 2;
                  tw_idx <= 127;
                else
                  ln     <= 1;
                  tw_idx <= 255;
                end if;
              end if;
              fsm <= S_RD0;
            end if;

          when S_RD0 =>
            rd_addr <= std_logic_vector(to_unsigned(blk + jj, 8));
            fsm     <= S_RD1;

          when S_RD1 =>
            -- rd_data for address blk+jj is available next cycle
            rd_addr <= std_logic_vector(to_unsigned(blk + jj + ln, 8));
            fsm     <= S_WAIT;

          when S_WAIT =>
            a_val <= signed(rd_data);
            fsm   <= S_CALC;

          when S_CALC =>
            if inv_r = '0' then
              -- Cooley-Tukey: t = mont(zeta * b); b = a - t; a = a + t
              zeta := to_signed(get_zeta(tw_idx), G_WIDTH);
              prod := zeta * signed(rd_data);
              tval := mont_reduce(prod);
              res_a <= range_reduce(a_val + tval);
              res_b <= range_reduce(a_val - tval);
            else
              -- Gentleman-Sande: t = a; a = t + b; b = mont(zeta * (b - t))
              zeta := to_signed(get_zeta(tw_idx), G_WIDTH);
              res_a <= range_reduce(a_val + signed(rd_data));
              prod  := zeta * range_reduce(signed(rd_data) - a_val);
              res_b <= mont_reduce(prod);
            end if;
            fsm <= S_WR0;

          when S_WR0 =>
            wr_addr <= std_logic_vector(to_unsigned(blk + jj, 8));
            wr_data <= std_logic_vector(res_a);
            wr_en   <= '1';
            fsm     <= S_WR1;

          when S_WR1 =>
            wr_addr <= std_logic_vector(to_unsigned(blk + jj + ln, 8));
            wr_data <= std_logic_vector(res_b);
            wr_en   <= '1';
            fsm     <= S_NEXT;

          when S_NEXT =>
            -- The twiddle index advances exactly once per butterfly block and
            -- runs monotonically across the whole transform. It must not be
            -- bumped again at a layer boundary, since the boundary itself is
            -- just the end of the last block of that layer.
            if jj + 1 < ln then
              jj  <= jj + 1;
              fsm <= S_RD0;
            else
              jj <= 0;
              if blk + 2 * ln < 256 then
                blk <= blk + 2 * ln;
                if inv_r = '0' then
                  tw_idx <= tw_idx + 1;
                else
                  tw_idx <= tw_idx - 1;
                end if;
                fsm <= S_RD0;
              else
                blk <= 0;
                if inv_r = '0' then
                  if G_LAYERS = 7 then
                    last_ln := 2;
                  else
                    last_ln := 1;
                  end if;
                  if ln = last_ln then
                    fsm <= S_DONE;
                  else
                    ln     <= ln / 2;
                    tw_idx <= tw_idx + 1;
                    fsm    <= S_RD0;
                  end if;
                else
                  if ln = 128 then
                    sc_idx <= 0;
                    fsm    <= S_SCALE_RD;
                  else
                    ln     <= ln * 2;
                    tw_idx <= tw_idx - 1;
                    fsm    <= S_RD0;
                  end if;
                end if;
              end if;
            end if;

          when S_SCALE_RD =>
            rd_addr <= std_logic_vector(to_unsigned(sc_idx, 8));
            fsm     <= S_SCALE_WAIT;

          when S_SCALE_WAIT =>
            fsm <= S_SCALE_WR;

          when S_SCALE_WR =>
            prod    := to_signed(G_SCALE, G_WIDTH) * signed(rd_data);
            wr_addr <= std_logic_vector(to_unsigned(sc_idx, 8));
            wr_data <= std_logic_vector(mont_reduce(prod));
            wr_en   <= '1';
            if sc_idx = 255 then
              fsm <= S_DONE;
            else
              sc_idx <= sc_idx + 1;
              fsm    <= S_SCALE_RD;
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
