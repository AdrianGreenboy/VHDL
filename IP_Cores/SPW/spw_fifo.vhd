-- ============================================================================
-- spw_fifo.vhd -- FIFO FWFT de WIDTH bits (patron byte_fifo, ampliado a 9)
-- ============================================================================
-- First-Word-Fall-Through: rdata muestra la cabeza combinacionalmente.
-- generic LOG2_DEPTH; level de LOG2_DEPTH+1 bits; aresetn asincrono activo
-- bajo; clr sincrono (para los flush del CMD y el reset por EN).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spw_fifo is
  generic (
    LOG2_DEPTH : integer := 6;
    WIDTH      : integer := 9
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    clr     : in  std_logic;
    wr_en   : in  std_logic;
    wdata   : in  std_logic_vector(WIDTH - 1 downto 0);
    rd_en   : in  std_logic;
    rdata   : out std_logic_vector(WIDTH - 1 downto 0);
    empty   : out std_logic;
    full    : out std_logic;
    level   : out std_logic_vector(LOG2_DEPTH downto 0)
  );
end entity spw_fifo;

architecture rtl of spw_fifo is

  constant DEPTH : integer := 2 ** LOG2_DEPTH;

  type mem_t is array (0 to DEPTH - 1) of std_logic_vector(WIDTH - 1 downto 0);
  signal mem : mem_t := (others => (others => '0'));

  signal wptr : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal rptr : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal cnt  : unsigned(LOG2_DEPTH downto 0)     := (others => '0');

  signal empty_i : std_logic;
  signal full_i  : std_logic;

begin

  empty_i <= '1' when cnt = 0 else '0';
  full_i  <= '1' when cnt = DEPTH else '0';

  empty <= empty_i;
  full  <= full_i;
  level <= std_logic_vector(cnt);

  -- FWFT: la cabeza siempre visible
  rdata <= mem(to_integer(rptr));

  main : process (clk, aresetn)
    variable do_wr, do_rd : boolean;
  begin
    if aresetn = '0' then
      wptr <= (others => '0');
      rptr <= (others => '0');
      cnt  <= (others => '0');
    elsif rising_edge(clk) then
      if clr = '1' then
        wptr <= (others => '0');
        rptr <= (others => '0');
        cnt  <= (others => '0');
      else
        do_wr := (wr_en = '1') and (full_i = '0');
        do_rd := (rd_en = '1') and (empty_i = '0');
        if do_wr then
          mem(to_integer(wptr)) <= wdata;
          wptr                  <= wptr + 1;
        end if;
        if do_rd then
          rptr <= rptr + 1;
        end if;
        if do_wr and not do_rd then
          cnt <= cnt + 1;
        elsif do_rd and not do_wr then
          cnt <= cnt - 1;
        end if;
      end if;
    end if;
  end process main;

end architecture rtl;
