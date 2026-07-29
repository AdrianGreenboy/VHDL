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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity byte_mem is
  generic (
    G_SIZE : integer := 8192);
  port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    -- port A: FSM access
    a_addr : in  std_logic_vector(12 downto 0);
    a_din  : in  std_logic_vector(7 downto 0);
    a_we   : in  std_logic;
    a_dout : out std_logic_vector(7 downto 0);
    -- port B: read-only stream port for the sponge and codecs
    b_addr : in  std_logic_vector(12 downto 0);
    b_dout : out std_logic_vector(7 downto 0));
end entity byte_mem;

architecture rtl of byte_mem is
  type t_mem is array (0 to G_SIZE - 1) of integer range 0 to 255;
  signal mem : t_mem := (others => 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if a_we = '1' then
        mem(to_integer(unsigned(a_addr))) <= to_integer(unsigned(a_din));
      end if;
      a_dout <= std_logic_vector(
                  to_unsigned(mem(to_integer(unsigned(a_addr))), 8));
      b_dout <= std_logic_vector(
                  to_unsigned(mem(to_integer(unsigned(b_addr))), 8));
    end if;
  end process;
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
