-- ============================================================================
-- ptp_fifo.vhd -- synchronous-read FWFT FIFO of the PTP core
-- ============================================================================
-- Renamed from the PTP-local copy of spw_fifo (audit 2026-11): the SPW core
-- owns an entity of the same name with a different port list, so both could
-- not live in one library. Also rewritten (ALTA/ASIC):
--   * storage = single-write / single-SYNCHRONOUS-read array (SRAM/BRAM
--     friendly; v1 read the memory asynchronously);
--   * FWFT recreated with a 1-entry prefetch output register (pattern of
--     TSN/tsn_fifo.vhd): rdata/empty describe the output register, rd_en
--     consumes it and the next entry is fetched in the same cycle (1 read per
--     clock sustained). Write -> visible latency: 2 clocks (v1: 1).
--   * reset 'rst' synchronous active-high (v1: asynchronous aresetn, driven
--     with 'not rst' by ptp_mac); clr = synchronous flush.
--   * level = entries not yet consumed (prefetched one included);
--     full = DEPTH entries in the array (the output register is extra).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ptp_fifo is
  generic (
    LOG2_DEPTH : integer := 6;
    WIDTH      : integer := 9
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    clr      : in  std_logic;
    wr_en    : in  std_logic;
    wdata    : in  std_logic_vector(WIDTH - 1 downto 0);
    rd_en    : in  std_logic;
    rdata    : out std_logic_vector(WIDTH - 1 downto 0);
    empty    : out std_logic;
    full     : out std_logic;
    level    : out std_logic_vector(LOG2_DEPTH downto 0);
    dbg_wptr : out std_logic_vector(LOG2_DEPTH - 1 downto 0);
    dbg_rptr : out std_logic_vector(LOG2_DEPTH - 1 downto 0)
  );
end entity ptp_fifo;

architecture rtl of ptp_fifo is
  constant DEPTH : integer := 2 ** LOG2_DEPTH;
  type mem_t is array (0 to DEPTH - 1) of std_logic_vector(WIDTH - 1 downto 0);
  signal mem : mem_t;
  attribute ram_style : string;
  attribute ram_style of mem : signal is "block";

  subtype ptr_t is unsigned(LOG2_DEPTH downto 0);
  signal wptr, rptr : ptr_t := (others => '0');
  signal out_reg    : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
  signal out_valid  : std_logic := '0';
  signal full_i, fetch : std_logic;
begin
  full_i <= '1' when (wptr - rptr) = to_unsigned(DEPTH, LOG2_DEPTH + 1) else '0';
  full   <= full_i;
  fetch  <= '1' when (out_valid = '0' or rd_en = '1') and wptr /= rptr else '0';

  rdata  <= out_reg;
  empty  <= not out_valid;
  level  <= std_logic_vector(wptr - rptr + 1) when out_valid = '1'
            else std_logic_vector(wptr - rptr);
  dbg_wptr <= std_logic_vector(wptr(LOG2_DEPTH - 1 downto 0));
  dbg_rptr <= std_logic_vector(rptr(LOG2_DEPTH - 1 downto 0));

  p_wr : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clr = '1' then
        wptr <= (others => '0');
      elsif wr_en = '1' and full_i = '0' then
        mem(to_integer(wptr(LOG2_DEPTH - 1 downto 0))) <= wdata;
        wptr <= wptr + 1;
      end if;
    end if;
  end process p_wr;

  p_rd : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clr = '1' then
        rptr      <= (others => '0');
        out_valid <= '0';
      elsif fetch = '1' then
        out_reg   <= mem(to_integer(rptr(LOG2_DEPTH - 1 downto 0)));   -- sync read
        rptr      <= rptr + 1;
        out_valid <= '1';
      elsif rd_en = '1' and out_valid = '1' then
        out_valid <= '0';
      end if;
    end if;
  end process p_rd;
end architecture rtl;
