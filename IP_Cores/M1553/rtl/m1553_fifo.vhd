-- ============================================================================
-- m1553_fifo.vhd - FWFT FIFO of the MIL-STD-1553 IP (registered-read RAM)
-- ============================================================================
-- Own m1553_-prefixed FIFO (audit 2026-11): the IP no longer borrows
-- spw_fifo from the SpaceWire core (shared-library name coupling).
--
--  * Storage: RAM with a REGISTERED read port (SRAM macro / BRAM friendly).
--  * FWFT kept with a 1-deep prefetch: the RAM read register is the output
--    stage; it is reloaded whenever it is empty or consumed this cycle.
--    rdata shows the head while empty = '0'; rd_en consumes it; the next
--    head is valid on the following cycle (a pop per cycle is supported).
--  * A word written into an empty FIFO is visible two cycles later.
--  * level = all stored words (RAM + output stage); full at 2**LOG2_DEPTH.
--    Writes when full / reads when empty are ignored.
--  * rst: synchronous active high; clr: synchronous flush (same effect).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m1553_fifo is
  generic (
    LOG2_DEPTH : natural := 6;
    WIDTH      : natural := 16
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    clr   : in  std_logic;
    wr_en : in  std_logic;
    wdata : in  std_logic_vector(WIDTH-1 downto 0);
    rd_en : in  std_logic;
    rdata : out std_logic_vector(WIDTH-1 downto 0);
    empty : out std_logic;
    full  : out std_logic;
    level : out std_logic_vector(LOG2_DEPTH downto 0)
  );
end entity m1553_fifo;

architecture rtl of m1553_fifo is
  constant DEPTH : natural := 2 ** LOG2_DEPTH;
  type ram_t is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
  signal ram    : ram_t;
  signal wp, rp : unsigned(LOG2_DEPTH-1 downto 0) := (others => '0');
  signal cnt    : unsigned(LOG2_DEPTH downto 0) := (others => '0');
  signal ov     : std_logic := '0';
  signal q_r    : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
  signal ram_words : unsigned(LOG2_DEPTH downto 0);
  signal do_wr, do_pop, do_load : std_logic;
begin

  level <= std_logic_vector(cnt);
  empty <= not ov;
  full  <= '1' when cnt = DEPTH else '0';
  rdata <= q_r;

  ram_words <= cnt - 1 when ov = '1' else cnt;
  do_wr   <= '1' when wr_en = '1' and cnt /= DEPTH and clr = '0' else '0';
  do_pop  <= rd_en and ov;
  do_load <= '1' when ram_words /= 0 and (ov = '0' or do_pop = '1')
                      and clr = '0' else '0';

  ram_p : process(clk)
  begin
    if rising_edge(clk) then
      if do_wr = '1' then
        ram(to_integer(wp)) <= wdata;
      end if;
      if do_load = '1' then
        q_r <= ram(to_integer(rp));
      end if;
    end if;
  end process;

  ctl_p : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clr = '1' then
        wp  <= (others => '0');
        rp  <= (others => '0');
        cnt <= (others => '0');
        ov  <= '0';
      else
        if do_wr = '1' then
          wp <= wp + 1;
        end if;
        if do_load = '1' then
          rp <= rp + 1;
          ov <= '1';
        elsif do_pop = '1' then
          ov <= '0';
        end if;
        if do_wr = '1' and do_pop = '0' then
          cnt <= cnt + 1;
        elsif do_wr = '0' and do_pop = '1' then
          cnt <= cnt - 1;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
