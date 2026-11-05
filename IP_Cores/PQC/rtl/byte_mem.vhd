-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- byte_mem: 4 KB byte-domain memory for seeds, keys and ciphertexts.
-- codec_12 : streaming ByteEncode_12 / ByteDecode_12 between a polynomial
--            slot and a byte range.
-- VHDL-2008. ASCII-only. MIT license.
--
-- ByteEncode_12 packs two 12-bit coefficients into three bytes:
--   b0 = c0(7 downto 0)
--   b1 = c1(3 downto 0) & c0(11 downto 8)
--   b2 = c1(11 downto 4)
-- This is the same little-endian bit stream the Layer 2 codec package
-- describes; here it is expressed as a streaming state machine because the
-- FSM moves 384 bytes at a time and cannot afford a combinational unroll.
--
-- Coefficients enter and leave in canonical [0, q) form. The polynomial
-- memory holds signed values, so conversion happens at this boundary and
-- nowhere else, which keeps a single representation rule in force upstream.
-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- byte_mem: 8 KB (G_SIZE bytes, 13-bit address) byte-domain memory for
--           seeds, keys and ciphertexts of the ML-KEM core.
-- codec_12 : streaming ByteEncode_12 / ByteDecode_12 between a polynomial
--            slot and a byte range.
-- VHDL-2008. ASCII-only. MIT license.
--
-- byte_mem PHYSICAL ORGANISATION (audit 2026-11).
-- Every user of this memory drives the A and B addresses from identical
-- muxes, so the memory is a single-address 1RW SRAM. It is organised as
-- G_SIZE/G_LANES words of G_LANES bytes with a per-byte write mask (one 1RW
-- macro with byte mask, or one FPGA BRAM with byte enables); byte a lives in
-- word a / G_LANES, lane a mod G_LANES. A normal access touches one lane. The
-- zeroizer writes a whole word per cycle, so a wipe runs at G_LANES bytes per
-- cycle.
-- 1RW semantics: a cycle is either a read or a write. On a write cycle the
-- output register HOLDS its previous value (no read is performed); no
-- sequencer consumes read data in the cycle after a write it issued at the
-- same port (proved by the full KAT suite running on this model).
-- Storage has no initial value: ASIC SRAM powers up random. A simulation
-- assertion checks that the A and B addresses agree.
--
-- ByteEncode_12 packs two 12-bit coefficients into three bytes:
--   b0 = c0(7 downto 0)
--   b1 = c1(3 downto 0) & c0(11 downto 8)
--   b2 = c1(11 downto 4)
-- This is the same little-endian bit stream the Layer 2 codec package
-- describes; here it is expressed as a streaming state machine because the
-- FSM moves 384 bytes at a time and cannot afford a combinational unroll.
--
-- Coefficients enter and leave in canonical [0, q) form. The polynomial
-- memory holds signed values, so conversion happens at this boundary and
-- nowhere else, which keeps a single representation rule in force upstream.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

package byte_mem_pkg is
  -- storage type (unconstrained so that testbenches can inspect the array
  -- through VHDL-2008 external names)
  type t_bm_arr is array (natural range <>) of std_logic_vector;
end package byte_mem_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.byte_mem_pkg.all;

entity byte_mem is
  generic (
    G_SIZE  : integer := 8192;
    G_LANES : integer := 8);
  port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    -- port A: FSM access
    a_addr : in  std_logic_vector(12 downto 0);
    a_din  : in  std_logic_vector(7 downto 0);
    a_we   : in  std_logic;
    a_dout : out std_logic_vector(7 downto 0);
    -- port B: read data of the same access (address must equal a_addr)
    b_addr : in  std_logic_vector(12 downto 0);
    b_dout : out std_logic_vector(7 downto 0);
    -- zeroization: a one-cycle z_start pulse wipes words z_lo .. z_hi
    -- (inclusive, word = G_LANES bytes); client accesses are ignored while
    -- z_busy is high.
    z_start : in  std_logic := '0';
    z_lo    : in  integer range 0 to G_SIZE / G_LANES - 1 := 0;
    z_hi    : in  integer range 0 to G_SIZE / G_LANES - 1 := 0;
    z_busy  : out std_logic);
end entity byte_mem;

architecture rtl of byte_mem is
  constant C_WORDS : integer := G_SIZE / G_LANES;
  subtype t_word is std_logic_vector(8 * G_LANES - 1 downto 0);
  signal mem    : t_bm_arr(0 to C_WORDS - 1)(8 * G_LANES - 1 downto 0);
  signal q      : t_word;
  signal lane_q : integer range 0 to G_LANES - 1 := 0;
  signal z_run  : std_logic := '0';
  signal z_ptr  : integer range 0 to C_WORDS - 1 := 0;
  signal z_end  : integer range 0 to C_WORDS - 1 := 0;
begin

  process (clk)
    variable ai : integer range 0 to G_SIZE - 1;
  begin
    if rising_edge(clk) then
      ai := to_integer(unsigned(a_addr));
      if z_run = '1' then
        mem(z_ptr) <= (others => '0');
      elsif a_we = '1' then
        mem(ai / G_LANES)(8 * (ai mod G_LANES) + 7 downto
                          8 * (ai mod G_LANES)) <= a_din;
      else
        q      <= mem(ai / G_LANES);
        lane_q <= ai mod G_LANES;
      end if;
    end if;
  end process;

  a_dout <= q(8 * lane_q + 7 downto 8 * lane_q);
  b_dout <= q(8 * lane_q + 7 downto 8 * lane_q);

  zero_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        z_run <= '0';
        z_ptr <= 0;
        z_end <= 0;
      elsif z_run = '1' then
        if z_ptr = z_end then
          z_run <= '0';
        else
          z_ptr <= z_ptr + 1;
        end if;
      elsif z_start = '1' then
        z_run <= '1';
        z_ptr <= z_lo;
        z_end <= z_hi;
      end if;
    end if;
  end process;
  z_busy <= z_run;

  -- pragma translate_off
  chk : process (clk)
  begin
    if rising_edge(clk) then
      assert rst_n = '0' or a_addr = b_addr or is_x(a_addr) or is_x(b_addr)
        report "byte_mem: A and B addresses differ; the memory is 1RW"
        severity failure;
    end if;
  end process;
  -- pragma translate_on
end architecture rtl;

-- -----------------------------------------------------------------------------
-- Streaming ByteEncode_12 / ByteDecode_12.
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;

entity codec_12 is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;
    decode    : in  std_logic;                      -- '0' encode, '1' decode
    base      : in  std_logic_vector(12 downto 0);  -- byte base address

    -- polynomial side
    p_raddr   : out std_logic_vector(7 downto 0);
    p_rdata   : in  std_logic_vector(15 downto 0);
    p_waddr   : out std_logic_vector(7 downto 0);
    p_wdata   : out std_logic_vector(15 downto 0);
    p_we      : out std_logic;

    -- byte side
    b_addr    : out std_logic_vector(12 downto 0);
    b_rdata   : in  std_logic_vector(7 downto 0);
    b_wdata   : out std_logic_vector(7 downto 0);
    b_we      : out std_logic;

    busy      : out std_logic;
    done      : out std_logic);
end entity codec_12;

architecture rtl of codec_12 is

  type t_fsm is (S_IDLE,
                 S_E_RD0, S_E_RD0W, S_E_RD1, S_E_RD1W,
                 S_E_B0, S_E_B1, S_E_B2, S_E_NEXT,
                 S_D_RD0, S_D_RD0W, S_D_RD1, S_D_RD1W, S_D_RD2, S_D_RD2W,
                 S_D_W0, S_D_W1, S_D_NEXT,
                 S_DONE);

  signal fsm    : t_fsm := S_IDLE;
  signal pair   : integer range 0 to 128 := 0;
  signal c0     : unsigned(11 downto 0) := (others => '0');
  signal c1     : unsigned(11 downto 0) := (others => '0');
  signal by0    : unsigned(7 downto 0) := (others => '0');
  signal by1    : unsigned(7 downto 0) := (others => '0');
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  -- signed polynomial value to canonical [0, q)
  function canon (x : signed(15 downto 0)) return unsigned is
    variable v : integer;
  begin
    v := to_integer(x);
    if v < 0 then
      v := v + C_QK;
    end if;
    return to_unsigned(v, 12);
  end function canon;

begin

  busy <= busy_r;
  done <= done_r;

  process (clk)
    variable bidx : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        fsm     <= S_IDLE;
        pair    <= 0;
        busy_r  <= '0';
        done_r  <= '0';
        p_we    <= '0';
        b_we    <= '0';
        p_raddr <= (others => '0');
        p_waddr <= (others => '0');
        p_wdata <= (others => '0');
        b_addr  <= (others => '0');
        b_wdata <= (others => '0');
      else
        done_r <= '0';
        p_we   <= '0';
        b_we   <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              pair   <= 0;
              busy_r <= '1';
              if decode = '1' then
                fsm <= S_D_RD0;
              else
                fsm <= S_E_RD0;
              end if;
            end if;

          ----------------------------------------------------------------
          -- encode: two coefficients out, three bytes in
          ----------------------------------------------------------------
          when S_E_RD0 =>
            p_raddr <= std_logic_vector(to_unsigned(2 * pair, 8));
            fsm     <= S_E_RD0W;

          when S_E_RD0W =>
            fsm <= S_E_RD1;

          when S_E_RD1 =>
            c0      <= canon(signed(p_rdata));
            p_raddr <= std_logic_vector(to_unsigned(2 * pair + 1, 8));
            fsm     <= S_E_RD1W;

          when S_E_RD1W =>
            fsm <= S_E_B0;

          when S_E_B0 =>
            c1      <= canon(signed(p_rdata));
            bidx    := to_integer(unsigned(base)) + 3 * pair;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c0(7 downto 0));
            b_we    <= '1';
            fsm     <= S_E_B1;

          when S_E_B1 =>
            bidx    := to_integer(unsigned(base)) + 3 * pair + 1;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c1(3 downto 0) & c0(11 downto 8));
            b_we    <= '1';
            fsm     <= S_E_B2;

          when S_E_B2 =>
            bidx    := to_integer(unsigned(base)) + 3 * pair + 2;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c1(11 downto 4));
            b_we    <= '1';
            fsm     <= S_E_NEXT;

          when S_E_NEXT =>
            if pair = 127 then
              fsm <= S_DONE;
            else
              pair <= pair + 1;
              fsm  <= S_E_RD0;
            end if;

          ----------------------------------------------------------------
          -- decode: three bytes in, two coefficients out
          ----------------------------------------------------------------
          when S_D_RD0 =>
            bidx   := to_integer(unsigned(base)) + 3 * pair;
            b_addr <= std_logic_vector(to_unsigned(bidx, 13));
            fsm    <= S_D_RD0W;

          when S_D_RD0W =>
            fsm <= S_D_RD1;

          when S_D_RD1 =>
            by0    <= unsigned(b_rdata);
            bidx   := to_integer(unsigned(base)) + 3 * pair + 1;
            b_addr <= std_logic_vector(to_unsigned(bidx, 13));
            fsm    <= S_D_RD1W;

          when S_D_RD1W =>
            fsm <= S_D_RD2;

          when S_D_RD2 =>
            by1    <= unsigned(b_rdata);
            bidx   := to_integer(unsigned(base)) + 3 * pair + 2;
            b_addr <= std_logic_vector(to_unsigned(bidx, 13));
            fsm    <= S_D_RD2W;

          when S_D_RD2W =>
            fsm <= S_D_W0;

          when S_D_W0 =>
            -- c0 = b1(3:0) & b0, c1 = b2 & b1(7:4)
            p_waddr <= std_logic_vector(to_unsigned(2 * pair, 8));
            p_wdata <= std_logic_vector(
                         resize(signed('0' & by1(3 downto 0) & by0), 16));
            p_we    <= '1';
            c1      <= unsigned(b_rdata) & by1(7 downto 4);
            fsm     <= S_D_W1;

          when S_D_W1 =>
            p_waddr <= std_logic_vector(to_unsigned(2 * pair + 1, 8));
            p_wdata <= std_logic_vector(resize(signed('0' & c1), 16));
            p_we    <= '1';
            fsm     <= S_D_NEXT;

          when S_D_NEXT =>
            if pair = 127 then
              fsm <= S_DONE;
            else
              pair <= pair + 1;
              fsm  <= S_D_RD0;
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
