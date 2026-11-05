-- ============================================================================
-- spw_fifo.vhd -- FIFO FWFT de WIDTH bits (patron byte_fifo, ampliado a 9)
-- ============================================================================
-- First-Word-Fall-Through: rdata muestra la cabeza combinacionalmente.
-- generic LOG2_DEPTH; level de LOG2_DEPTH+1 bits; rst SINCRONO activo alto (audit 2026-11; antes aresetn asincrono activo
-- bajo; clr sincrono (para los flush del CMD y el reset por EN).
-- ============================================================================
-- Audit 2026-11 (ASIC): RAM with a REGISTERED read port; FWFT kept with a
-- 1-deep prefetch (the RAM read register is the output stage, reloaded when
-- empty or consumed). A word written into an empty FIFO is visible two
-- cycles later (was one); a pop per cycle is still supported. level counts
-- RAM + output stage. Reset is synchronous active high (rst).
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
    rst     : in  std_logic;  -- synchronous, active high
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
  signal mem  : mem_t;
  signal wptr : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal rptr : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal cnt  : unsigned(LOG2_DEPTH downto 0)     := (others => '0');
  signal ov   : std_logic := '0';
  signal q_r  : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
  signal ram_words : unsigned(LOG2_DEPTH downto 0);
  signal do_wr, do_pop, do_load : std_logic;
begin

  empty <= not ov;
  full  <= '1' when cnt = DEPTH else '0';
  level <= std_logic_vector(cnt);
  rdata <= q_r;

  ram_words <= cnt - 1 when ov = '1' else cnt;
  do_wr   <= '1' when wr_en = '1' and cnt /= DEPTH and clr = '0' else '0';
  do_pop  <= rd_en and ov;
  do_load <= '1' when ram_words /= 0 and (ov = '0' or do_pop = '1')
                      and clr = '0' else '0';

  ram_p : process (clk)
  begin
    if rising_edge(clk) then
      if do_wr = '1' then
        mem(to_integer(wptr)) <= wdata;
      end if;
      if do_load = '1' then
        q_r <= mem(to_integer(rptr));
      end if;
    end if;
  end process ram_p;

  main : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clr = '1' then
        wptr <= (others => '0');
        rptr <= (others => '0');
        cnt  <= (others => '0');
        ov   <= '0';
      else
        if do_wr = '1' then
          wptr <= wptr + 1;
        end if;
        if do_load = '1' then
          rptr <= rptr + 1;
          ov   <= '1';
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
  end process main;

end architecture rtl;
