-- ============================================================================
-- pcie_byte_fifo.vhd -- PCIE IP (audit 2026-11)
-- Byte FIFO, first-word-fall-through, built on a 1W/1R memory with a
-- SYNCHRONOUS (registered) read port, so it maps onto BRAM / SRAM macros.
--
-- Renamed from 'byte_fifo' (the family-wide name clashed with other cores that
-- compile into the same library with different port contracts).
--
-- FWFT with prefetch: the memory read register IS the output register 'dout'.
-- Whenever the output register is empty (or being consumed) and the memory
-- holds data, the next word is fetched into it. Write-to-visible latency is
-- 2 cycles; read throughput is 1 word/cycle.
--
-- Guards (audit): a write while full is DROPPED and sets the sticky 'ovf'
-- flag (cleared by reset); a read while empty is ignored.
-- Capacity = 2**LOG2_DEPTH (memory) + 1 (output register).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_byte_fifo is
  generic (
    LOG2_DEPTH : integer := 9;   -- 512 bytes
    WIDTH      : integer := 8
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(WIDTH-1 downto 0);
    full    : out std_logic;
    rd_en   : in  std_logic;
    rd_data : out std_logic_vector(WIDTH-1 downto 0);
    empty   : out std_logic;
    level   : out unsigned(LOG2_DEPTH downto 0);   -- saturates at 2**LOG2_DEPTH
    ovf     : out std_logic
  );
end entity;

architecture rtl of pcie_byte_fifo is
  constant DEPTH : integer := 2**LOG2_DEPTH;
  type mem_t is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
  signal mem : mem_t;
  attribute ram_style : string;
  attribute ram_style of mem : signal is "block";

  signal wptr, rptr : unsigned(LOG2_DEPTH downto 0) := (others=>'0');
  signal dout   : std_logic_vector(WIDTH-1 downto 0) := (others=>'0');
  signal dout_v : std_logic := '0';
  signal ovf_r  : std_logic := '0';
  signal ram_cnt : unsigned(LOG2_DEPTH downto 0);
  signal full_i, fetch, do_wr, do_rd : std_logic;
begin
  ram_cnt <= wptr - rptr;
  full_i  <= '1' when ram_cnt = to_unsigned(DEPTH, LOG2_DEPTH+1) else '0';
  do_wr   <= wr_en and not full_i;
  do_rd   <= rd_en and dout_v;
  fetch   <= '1' when ram_cnt /= 0 and (dout_v = '0' or do_rd = '1') else '0';

  full    <= full_i;
  empty   <= not dout_v;
  rd_data <= dout;
  ovf     <= ovf_r;
  level   <= ram_cnt     when full_i = '1' or dout_v = '0' else
             ram_cnt + 1;

  -- memory: synchronous write, synchronous (registered, enabled) read
  mem_p : process(clk)
  begin
    if rising_edge(clk) then
      if do_wr = '1' then
        mem(to_integer(wptr(LOG2_DEPTH-1 downto 0))) <= wr_data;
      end if;
      if fetch = '1' then
        dout <= mem(to_integer(rptr(LOG2_DEPTH-1 downto 0)));
      end if;
    end if;
  end process;

  ctl_p : process(clk, aresetn)
  begin
    if aresetn = '0' then
      wptr <= (others=>'0'); rptr <= (others=>'0');
      dout_v <= '0'; ovf_r <= '0';
    elsif rising_edge(clk) then
      if do_wr = '1' then wptr <= wptr + 1; end if;
      if wr_en = '1' and full_i = '1' then ovf_r <= '1'; end if;
      if fetch = '1' then
        rptr   <= rptr + 1;
        dout_v <= '1';
      elsif do_rd = '1' then
        dout_v <= '0';
      end if;
    end if;
  end process;
end architecture;
