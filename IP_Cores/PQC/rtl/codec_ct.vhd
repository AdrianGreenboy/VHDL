-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- codec_ct: ciphertext compression codec for ML-KEM-768.
--
-- Streams Compress_d followed by ByteEncode_d, and the inverse, for the two
-- widths the ciphertext uses:
--
--   d = 10  the u vector, 320 bytes per polynomial, c1
--   d =  4  the v polynomial, 128 bytes, c2
--
-- Both widths pack whole coefficients into bytes without a remainder over a
-- short group, so the encoder walks a small group at a time:
--
--   d = 10: 4 coefficients (40 bits) -> 5 bytes, 64 groups per polynomial
--   d =  4: 2 coefficients  (8 bits) -> 1 byte, 128 groups per polynomial
--
-- Compression constants come from pqc_round_pkg and were verified
-- exhaustively over the full coefficient range at Layer 2, so this block is
-- responsible only for the streaming and the bit packing.
--
-- VHDL-2008. ASCII-only. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ntt_tables_pkg.all;
use work.pqc_round_pkg.all;

entity codec_ct is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;
    decode    : in  std_logic;                      -- '0' encode, '1' decode
    dsel      : in  std_logic_vector(1 downto 0);   -- 00 d=10, 01 d=4, 10 d=1
    base      : in  std_logic_vector(12 downto 0);  -- byte base address

    -- polynomial memory
    p_raddr   : out std_logic_vector(7 downto 0);
    p_rdata   : in  std_logic_vector(15 downto 0);
    p_waddr   : out std_logic_vector(7 downto 0);
    p_wdata   : out std_logic_vector(15 downto 0);
    p_we      : out std_logic;

    -- byte memory
    b_addr    : out std_logic_vector(12 downto 0);
    b_rdata   : in  std_logic_vector(7 downto 0);
    b_wdata   : out std_logic_vector(7 downto 0);
    b_we      : out std_logic;

    busy      : out std_logic;
    done      : out std_logic);
end entity codec_ct;

architecture rtl of codec_ct is

  type t_fsm is (
    S_IDLE,
    -- encode d=10: read 4 coefficients, emit 5 bytes
    S_E10_RD, S_E10_RDW, S_E10_LAT, S_E10_B0, S_E10_B1, S_E10_B2, S_E10_B3,
    S_E10_B4, S_E10_NEXT,
    -- encode d=4: read 2 coefficients, emit 1 byte
    S_E4_RD, S_E4_RDW, S_E4_LAT, S_E4_B0, S_E4_NEXT,
    -- decode d=10: read 5 bytes, emit 4 coefficients
    S_D10_RD, S_D10_RDW, S_D10_LAT, S_D10_W3, S_D10_NEXT,
    -- decode d=4: read 1 byte, emit 2 coefficients
    S_D4_RD, S_D4_RDW, S_D4_LAT, S_D4_W0, S_D4_W1, S_D4_NEXT,
    S_E1_RD, S_E1_RDW, S_E1_LAT, S_E1_B0, S_E1_NEXT,
    S_D1_RD, S_D1_RDW, S_D1_LAT, S_D1_W, S_D1_NEXT,
    S_DONE);

  signal fsm : t_fsm := S_IDLE;

  signal grp    : integer range 0 to 127 := 0;   -- group index
  signal sub    : integer range 0 to 7 := 0;     -- index within group
  -- one packed byte, used by the d=1 paths
  signal bbyte  : unsigned(7 downto 0) := (others => '0');
  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  -- four compressed coefficients, widest case d=10
  type t_c is array (0 to 3) of unsigned(9 downto 0);
  signal c : t_c := (others => (others => '0'));

  -- Bring a signed representative into 0 .. q-1 before compressing, since
  -- Compress_d is defined on the canonical residue.
  function canon (x : signed(15 downto 0)) return integer is
    variable v : integer;
  begin
    v := to_integer(x);
    if v < 0 then
      v := v + work.ntt_tables_pkg.C_QK;
    end if;
    return v;
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
        busy_r  <= '0';
        done_r  <= '0';
        p_we    <= '0';
        b_we    <= '0';
        p_raddr <= (others => '0');
        p_waddr <= (others => '0');
        p_wdata <= (others => '0');
        b_addr  <= (others => '0');
        b_wdata <= (others => '0');
        grp     <= 0;
        sub     <= 0;
      else
        p_we   <= '0';
        b_we   <= '0';
        done_r <= '0';

        case fsm is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r <= '1';
              grp    <= 0;
              sub    <= 0;
              if decode = '0' then
                case dsel is
                  when "00"   => fsm <= S_E10_RD;
                  when "01"   => fsm <= S_E4_RD;
                  when others => fsm <= S_E1_RD;
                end case;
              else
                case dsel is
                  when "00"   => fsm <= S_D10_RD;
                  when "01"   => fsm <= S_D4_RD;
                  when others => fsm <= S_D1_RD;
                end case;
              end if;
            end if;

          ----------------------------------------------------------------
          -- encode, d = 10: c[0..3] pack into five bytes
          ----------------------------------------------------------------
          when S_E10_RD =>
            p_raddr <= std_logic_vector(to_unsigned(4 * grp + sub, 8));
            fsm     <= S_E10_RDW;

          -- settle: the polynomial memory is synchronous
          when S_E10_RDW =>
            fsm <= S_E10_LAT;

          when S_E10_LAT =>
            c(sub) <= to_unsigned(compress_k(10, canon(signed(p_rdata))), 10);
            if sub = 3 then
              sub <= 0;
              fsm <= S_E10_B0;
            else
              sub <= sub + 1;
              fsm <= S_E10_RD;
            end if;

          when S_E10_B0 =>
            bidx    := to_integer(unsigned(base)) + 5 * grp;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c(0)(7 downto 0));
            b_we    <= '1';
            fsm     <= S_E10_B1;

          when S_E10_B1 =>
            bidx    := to_integer(unsigned(base)) + 5 * grp + 1;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c(1)(5 downto 0)) &
                       std_logic_vector(c(0)(9 downto 8));
            b_we    <= '1';
            fsm     <= S_E10_B2;

          when S_E10_B2 =>
            bidx    := to_integer(unsigned(base)) + 5 * grp + 2;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c(2)(3 downto 0)) &
                       std_logic_vector(c(1)(9 downto 6));
            b_we    <= '1';
            fsm     <= S_E10_B3;

          when S_E10_B3 =>
            bidx    := to_integer(unsigned(base)) + 5 * grp + 3;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c(3)(1 downto 0)) &
                       std_logic_vector(c(2)(9 downto 4));
            b_we    <= '1';
            fsm     <= S_E10_B4;

          when S_E10_B4 =>
            bidx    := to_integer(unsigned(base)) + 5 * grp + 4;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c(3)(9 downto 2));
            b_we    <= '1';
            fsm     <= S_E10_NEXT;

          when S_E10_NEXT =>
            if grp = 63 then
              fsm <= S_DONE;
            else
              grp <= grp + 1;
              fsm <= S_E10_RD;
            end if;

          ----------------------------------------------------------------
          -- encode, d = 4: two coefficients pack into one byte
          ----------------------------------------------------------------
          when S_E4_RD =>
            p_raddr <= std_logic_vector(to_unsigned(2 * grp + sub, 8));
            fsm     <= S_E4_RDW;

          when S_E4_RDW =>
            fsm <= S_E4_LAT;

          when S_E4_LAT =>
            c(sub) <= resize(
                        to_unsigned(compress_k(4, canon(signed(p_rdata))), 4),
                        10);
            if sub = 1 then
              sub <= 0;
              fsm <= S_E4_B0;
            else
              sub <= sub + 1;
              fsm <= S_E4_RD;
            end if;

          when S_E4_B0 =>
            bidx    := to_integer(unsigned(base)) + grp;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(c(1)(3 downto 0)) &
                       std_logic_vector(c(0)(3 downto 0));
            b_we    <= '1';
            fsm     <= S_E4_NEXT;

          when S_E4_NEXT =>
            if grp = 127 then
              fsm <= S_DONE;
            else
              grp <= grp + 1;
              fsm <= S_E4_RD;
            end if;

          ----------------------------------------------------------------
          -- decode, d = 10: five bytes unpack into four coefficients
          ----------------------------------------------------------------
          when S_D10_RD =>
            -- Read the five bytes of the group in a straight line, sub = 0..4.
            -- Folding the fifth byte into a separate branch is what made the
            -- first version overlap its own reads.
            bidx   := to_integer(unsigned(base)) + 5 * grp + sub;
            b_addr <= std_logic_vector(to_unsigned(bidx, 13));
            fsm    <= S_D10_RDW;

          when S_D10_RDW =>
            fsm <= S_D10_LAT;

          when S_D10_LAT =>
            case sub is
              when 0 => c(0)(7 downto 0) <= unsigned(b_rdata);
              when 1 => c(0)(9 downto 8) <= unsigned(b_rdata(1 downto 0));
                        c(1)(5 downto 0) <= unsigned(b_rdata(7 downto 2));
              when 2 => c(1)(9 downto 6) <= unsigned(b_rdata(3 downto 0));
                        c(2)(3 downto 0) <= unsigned(b_rdata(7 downto 4));
              when 3 => c(2)(9 downto 4) <= unsigned(b_rdata(5 downto 0));
                        c(3)(1 downto 0) <= unsigned(b_rdata(7 downto 6));
              when others =>
                        c(3)(9 downto 2) <= unsigned(b_rdata);
            end case;
            if sub = 4 then
              sub <= 0;
              fsm <= S_D10_W3;
            else
              sub <= sub + 1;
              fsm <= S_D10_RD;
            end if;

          when S_D10_W3 =>
            -- write the four decompressed coefficients back, one per cycle
            p_waddr <= std_logic_vector(to_unsigned(4 * grp + sub, 8));
            p_wdata <= std_logic_vector(to_signed(
                         decompress_k(10, to_integer(c(sub))), 16));
            p_we    <= '1';
            if sub = 3 then
              sub <= 0;
              fsm <= S_D10_NEXT;
            else
              sub <= sub + 1;
            end if;

          when S_D10_NEXT =>
            if grp = 63 then
              fsm <= S_DONE;
            else
              grp <= grp + 1;
              fsm <= S_D10_RD;
            end if;

          ----------------------------------------------------------------
          -- decode, d = 4: one byte unpacks into two coefficients
          ----------------------------------------------------------------
          when S_D4_RD =>
            bidx   := to_integer(unsigned(base)) + grp;
            b_addr <= std_logic_vector(to_unsigned(bidx, 13));
            fsm    <= S_D4_RDW;

          when S_D4_RDW =>
            fsm <= S_D4_LAT;

          when S_D4_LAT =>
            c(0) <= resize(unsigned(b_rdata(3 downto 0)), 10);
            c(1) <= resize(unsigned(b_rdata(7 downto 4)), 10);
            fsm  <= S_D4_W0;

          when S_D4_W0 =>
            p_waddr <= std_logic_vector(to_unsigned(2 * grp, 8));
            p_wdata <= std_logic_vector(to_signed(
                         decompress_k(4, to_integer(c(0))), 16));
            p_we    <= '1';
            fsm     <= S_D4_W1;

          when S_D4_W1 =>
            p_waddr <= std_logic_vector(to_unsigned(2 * grp + 1, 8));
            p_wdata <= std_logic_vector(to_signed(
                         decompress_k(4, to_integer(c(1))), 16));
            p_we    <= '1';
            fsm     <= S_D4_NEXT;

          when S_D4_NEXT =>
            if grp = 127 then
              fsm <= S_DONE;
            else
              grp <= grp + 1;
              fsm <= S_D4_RD;
            end if;

          ----------------------------------------------------------------
          -- encode, d = 1: eight coefficients pack into one byte, LSB first
          ----------------------------------------------------------------
          when S_E1_RD =>
            p_raddr <= std_logic_vector(to_unsigned(8 * grp + sub, 8));
            fsm     <= S_E1_RDW;

          when S_E1_RDW =>
            fsm <= S_E1_LAT;

          when S_E1_LAT =>
            bbyte(sub) <= to_unsigned(
                            compress_k(1, canon(signed(p_rdata))), 1)(0);
            if sub = 7 then
              sub <= 0;
              fsm <= S_E1_B0;
            else
              sub <= sub + 1;
              fsm <= S_E1_RD;
            end if;

          when S_E1_B0 =>
            bidx    := to_integer(unsigned(base)) + grp;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 13));
            b_wdata <= std_logic_vector(bbyte);
            b_we    <= '1';
            fsm     <= S_E1_NEXT;

          when S_E1_NEXT =>
            if grp = 31 then
              fsm <= S_DONE;
            else
              grp <= grp + 1;
              fsm <= S_E1_RD;
            end if;

          ----------------------------------------------------------------
          -- decode, d = 1: one byte expands into eight coefficients
          ----------------------------------------------------------------
          when S_D1_RD =>
            bidx   := to_integer(unsigned(base)) + grp;
            b_addr <= std_logic_vector(to_unsigned(bidx, 13));
            fsm    <= S_D1_RDW;

          when S_D1_RDW =>
            fsm <= S_D1_LAT;

          when S_D1_LAT =>
            bbyte <= unsigned(b_rdata);
            fsm   <= S_D1_W;

          when S_D1_W =>
            p_waddr <= std_logic_vector(to_unsigned(8 * grp + sub, 8));
            if bbyte(sub) = '1' then
              p_wdata <= std_logic_vector(
                           to_signed(decompress_k(1, 1), 16));
            else
              p_wdata <= (others => '0');
            end if;
            p_we <= '1';
            if sub = 7 then
              sub <= 0;
              fsm <= S_D1_NEXT;
            else
              sub <= sub + 1;
            end if;

          when S_D1_NEXT =>
            if grp = 31 then
              fsm <= S_DONE;
            else
              grp <= grp + 1;
              fsm <= S_D1_RD;
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
