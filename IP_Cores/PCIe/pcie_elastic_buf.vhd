-- ============================================================================
-- pcie_elastic_buf.vhd -- PCIE IP (audit 2026-11)
-- RX elastic buffer for a PHY with a RECOVERED receive clock.
--
-- The single-clock LOOP_INT model of this IP runs TX and RX on one clock, so
-- pcie_node bypasses this block by default (generic USE_EB = false). A real
-- SerDes delivers symbols on a recovered clock that drifts (+-300 ppm each
-- side in PCIe) against the local clock; this FIFO crosses the two domains
-- and compensates the drift by adding or removing SKP symbols inside SKP
-- ordered sets (COM + n x SKP), which the transmitter inserts every
-- SKP_INTERVAL symbols (pcie_tlp_frame).
--
--   write side (wclk): drops one SKP of an ordered set when the buffer is
--     above HI_MARK (local clock slower); always keeps >= 1 SKP per set.
--   read side (rclk):  repeats one SKP of an ordered set when the buffer is
--     below LO_MARK (local clock faster); at most one insertion per set.
--   Pointers cross domains in Gray code through 2-FF synchronizers.
--   ovf/udf flag a buffer that over/underflowed anyway (SKP spacing too
--   large for the clock offset): the receiver must treat that as a receiver
--   error (link retrain).
-- Symbols are 9 bits: k & byte.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;

entity pcie_elastic_buf is
  generic (
    LOG2_DEPTH : integer := 4;     -- 16 symbols
    HI_MARK    : integer := 10;    -- level above which a SKP is dropped
    LO_MARK    : integer := 6      -- level below which a SKP is repeated
  );
  port (
    -- recovered-clock domain
    wclk   : in  std_logic;
    wrst   : in  std_logic;
    w_sym  : in  byte_t;
    w_k    : in  std_logic;
    w_en   : in  std_logic := '1';
    -- local-clock domain
    rclk   : in  std_logic;
    rrst   : in  std_logic;
    r_sym  : out byte_t;
    r_k    : out std_logic;
    r_en   : out std_logic;        -- '1' when r_sym/r_k carry a symbol
    ovf    : out std_logic;        -- sticky (wclk domain)
    udf    : out std_logic;        -- sticky (rclk domain)
    skp_added   : out std_logic;   -- pulse (rclk)
    skp_dropped : out std_logic    -- pulse (wclk)
  );
end entity;

architecture rtl of pcie_elastic_buf is
  constant DEPTH : integer := 2**LOG2_DEPTH;
  subtype ptr_t is unsigned(LOG2_DEPTH downto 0);
  type mem_t is array (0 to DEPTH-1) of std_logic_vector(8 downto 0);
  signal mem : mem_t := (others => (others => '0'));

  function bin2gray(b : ptr_t) return ptr_t is
  begin return b xor ('0' & b(LOG2_DEPTH downto 1)); end function;
  function gray2bin(g : ptr_t) return ptr_t is
    variable b : ptr_t;
  begin
    b(LOG2_DEPTH) := g(LOG2_DEPTH);
    for i in LOG2_DEPTH-1 downto 0 loop b(i) := b(i+1) xor g(i); end loop;
    return b;
  end function;

  -- write domain
  signal wptr, wgray : ptr_t := (others => '0');
  signal rgray_w1, rgray_w2 : ptr_t := (others => '0');
  signal w_in_os, w_kept : std_logic := '0';
  signal ovf_r : std_logic := '0';
  -- read domain
  signal rptr, rgray : ptr_t := (others => '0');
  signal wgray_r1, wgray_r2 : ptr_t := (others => '0');
  signal r_in_os, r_added : std_logic := '0';
  signal udf_r, started : std_logic := '0';

  attribute async_reg : string;
  attribute async_reg of rgray_w1, rgray_w2, wgray_r1, wgray_r2 : signal is "true";
begin
  ovf <= ovf_r;
  udf <= udf_r;

  -- ---------------- write side ----------------
  wr_p : process(wclk)
    variable lvl : ptr_t;
    variable is_skp, is_com, drop : boolean;
  begin
    if rising_edge(wclk) then
      skp_dropped <= '0';
      if wrst = '1' then
        wptr <= (others => '0'); wgray <= (others => '0');
        rgray_w1 <= (others => '0'); rgray_w2 <= (others => '0');
        w_in_os <= '0'; w_kept <= '0'; ovf_r <= '0';
      else
        rgray_w1 <= rgray; rgray_w2 <= rgray_w1;
        if w_en = '1' then
          lvl    := wptr - gray2bin(rgray_w2);
          is_skp := w_k = '1' and w_sym = K_SKP;
          is_com := w_k = '1' and w_sym = K_COM;
          drop   := is_skp and w_in_os = '1' and w_kept = '1' and lvl > HI_MARK;
          if is_com then w_in_os <= '1'; w_kept <= '0';
          elsif not is_skp then w_in_os <= '0'; end if;
          if drop then
            skp_dropped <= '1';
          elsif lvl >= DEPTH then
            ovf_r <= '1';                       -- no room: symbol lost
          else
            if is_skp then w_kept <= '1'; end if;
            mem(to_integer(wptr(LOG2_DEPTH-1 downto 0))) <= w_k & w_sym;
            wptr  <= wptr + 1;
            wgray <= bin2gray(wptr + 1);
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ---------------- read side ----------------
  rd_p : process(rclk)
    variable lvl : ptr_t;
    variable q   : std_logic_vector(8 downto 0);
    variable is_skp, is_com : boolean;
  begin
    if rising_edge(rclk) then
      skp_added <= '0';
      r_en <= '0';
      if rrst = '1' then
        rptr <= (others => '0'); rgray <= (others => '0');
        wgray_r1 <= (others => '0'); wgray_r2 <= (others => '0');
        r_in_os <= '0'; r_added <= '0'; udf_r <= '0'; started <= '0';
        r_sym <= (others => '0'); r_k <= '0';
      else
        wgray_r1 <= wgray; wgray_r2 <= wgray_r1;
        lvl := gray2bin(wgray_r2) - rptr;
        if started = '0' then
          -- wait until half full before draining (centres the buffer)
          if lvl >= DEPTH/2 then started <= '1'; end if;
        elsif lvl = 0 then
          udf_r <= '1';                        -- nothing to read
        else
          q := mem(to_integer(rptr(LOG2_DEPTH-1 downto 0)));
          is_skp := q(8) = '1' and q(7 downto 0) = K_SKP;
          is_com := q(8) = '1' and q(7 downto 0) = K_COM;
          r_sym <= q(7 downto 0); r_k <= q(8); r_en <= '1';
          if is_com then r_in_os <= '1'; r_added <= '0';
          elsif not is_skp then r_in_os <= '0'; end if;
          if is_skp and r_in_os = '1' and r_added = '0' and lvl < LO_MARK then
            r_added <= '1'; skp_added <= '1';   -- emit this SKP twice
          else
            rptr  <= rptr + 1;
            rgray <= bin2gray(rptr + 1);
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
