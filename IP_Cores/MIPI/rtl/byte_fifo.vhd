-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- mipi_byte_fifo: elastic byte FIFO between the self-test generator and the
-- CSI-2 packet layer (single clock domain).
--
-- AUDIT 2026-11:
--  * Entity renamed byte_fifo -> mipi_byte_fifo (core prefix: avoids library
--    collisions with other cores' FIFOs). The file keeps its historical name
--    byte_fifo.vhd; renaming the file is left to the repository owner.
--  * The read-side pacing (1 byte then 2 bubble cycles) is REMOVED: the packet
--    layer now consumes one byte per cycle, so the FIFO drains at line rate.
--  * Overflow is no longer silent: a write while full is dropped and raises
--    the sticky 'ovf' output (cleared by ovf_clr / rst). 'full' is an
--    almost-full flag (DEPTH-4) so a 1-cycle-late stall cannot overflow.
--  * Memory: 1 synchronous write port + 1 synchronous read port (SRAM mold).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mipi_byte_fifo is
  generic (
    DEPTH : integer := 512;
    AWID  : integer := 9
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    -- write side
    wr_byte   : in  std_logic_vector(7 downto 0);
    wr_valid  : in  std_logic;
    wr_sot    : in  std_logic := '0';     -- side-band flag stored with the byte
    full      : out std_logic;            -- almost full (DEPTH-4)
    -- read side: one byte per cycle while not empty
    rd_byte   : out std_logic_vector(7 downto 0);
    rd_valid  : out std_logic;
    rd_sot    : out std_logic;
    empty     : out std_logic;
    -- sticky overflow
    ovf       : out std_logic;
    ovf_clr   : in  std_logic := '0'
  );
end entity;

architecture rtl of mipi_byte_fifo is
  type mem_t is array(0 to DEPTH-1) of std_logic_vector(8 downto 0);
  signal mem : mem_t;
  signal wptr, rptr : unsigned(AWID-1 downto 0) := (others=>'0');
  signal count : unsigned(AWID downto 0) := (others=>'0');
  signal rd_valid_i : std_logic := '0';
  signal rd_word_i  : std_logic_vector(8 downto 0) := (others=>'0');
  signal ovf_i   : std_logic := '0';
  signal empty_i : std_logic;
  signal do_wr, do_rd : boolean;
begin
  empty_i <= '1' when count = 0 else '0';
  empty   <= empty_i;
  full    <= '1' when count >= DEPTH-4 else '0';

  do_wr <= wr_valid = '1' and count < DEPTH;
  do_rd <= empty_i = '0';

  process(clk)
  begin
    if rising_edge(clk) then
      rd_valid_i <= '0';
      if rst='1' then
        wptr <= (others=>'0'); rptr <= (others=>'0');
        count <= (others=>'0'); ovf_i <= '0';
      else
        if do_wr then
          mem(to_integer(wptr)) <= wr_sot & wr_byte;
          wptr <= wptr + 1;
        end if;
        if wr_valid = '1' and count >= DEPTH then
          ovf_i <= '1';                      -- byte lost: sticky
        elsif ovf_clr = '1' then
          ovf_i <= '0';
        end if;
        if do_rd then
          rd_word_i  <= mem(to_integer(rptr));
          rd_valid_i <= '1';
          rptr <= rptr + 1;
        end if;
        if do_wr and not do_rd then
          count <= count + 1;
        elsif do_rd and not do_wr then
          count <= count - 1;
        end if;
      end if;
    end if;
  end process;

  rd_byte  <= rd_word_i(7 downto 0);
  rd_sot   <= rd_word_i(8);
  rd_valid <= rd_valid_i;
  ovf      <= ovf_i;
end architecture;
