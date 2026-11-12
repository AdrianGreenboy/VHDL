-------------------------------------------------------------------------------
-- SERDES_256G - asynchronous FIFO (gray pointers, distributed RAM,
-- first-word fall-through). One per lane: recovered clock -> rx_clk.
--
-- dout is the RAM read asynchronously at the read pointer. It is stable when
-- 'empty' is low: the entry was written at least two rclk edges before the
-- write pointer is seen by the read side. Constrain the RAM-to-rclk paths and
-- the gray pointers with set_max_delay -datapath_only (vivado/serdes256g_cdc.xdc).
--
-- A write while full is dropped (the writer checks 'full' itself).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity serdes256g_afifo is
  generic (
    G_AW : positive := 6;      -- depth = 2**G_AW (>= 4)
    G_DW : positive := 133
  );
  port (
    wclk  : in  std_logic;
    wrst  : in  std_logic;
    wr    : in  std_logic;
    din   : in  std_logic_vector(G_DW-1 downto 0);
    full  : out std_logic;
    rclk  : in  std_logic;
    rrst  : in  std_logic;
    rd    : in  std_logic;
    dout  : out std_logic_vector(G_DW-1 downto 0);
    empty : out std_logic
  );
end entity serdes256g_afifo;

architecture rtl of serdes256g_afifo is
  type t_mem is array (0 to 2**G_AW-1) of std_logic_vector(G_DW-1 downto 0);
  signal mem : t_mem := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of mem : signal is "distributed";

  signal wbin, wgray : unsigned(G_AW downto 0) := (others => '0');
  signal rbin, rgray : unsigned(G_AW downto 0) := (others => '0');
  signal rg_w1, rg_w2 : unsigned(G_AW downto 0) := (others => '0');  -- in wclk
  signal wg_r1, wg_r2 : unsigned(G_AW downto 0) := (others => '0');  -- in rclk
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of rg_w1, rg_w2, wg_r1, wg_r2 : signal is "TRUE";

  signal full_i, empty_i : std_logic;
begin

  full_i  <= '1' when wgray = ((not rg_w2(G_AW downto G_AW-1)) &
                               rg_w2(G_AW-2 downto 0)) else '0';
  empty_i <= '1' when rgray = wg_r2 else '0';
  full    <= full_i;
  empty   <= empty_i;

  -- write side
  process(wclk)
    variable nb : unsigned(G_AW downto 0);
  begin
    if rising_edge(wclk) then
      rg_w1 <= rgray;
      rg_w2 <= rg_w1;
      if wrst = '1' then
        wbin  <= (others => '0');
        wgray <= (others => '0');
      elsif wr = '1' and full_i = '0' then
        mem(to_integer(wbin(G_AW-1 downto 0))) <= din;
        nb    := wbin + 1;
        wbin  <= nb;
        wgray <= nb xor shift_right(nb, 1);
      end if;
    end if;
  end process;

  -- read side
  process(rclk)
    variable nb : unsigned(G_AW downto 0);
  begin
    if rising_edge(rclk) then
      wg_r1 <= wgray;
      wg_r2 <= wg_r1;
      if rrst = '1' then
        rbin  <= (others => '0');
        rgray <= (others => '0');
      elsif rd = '1' and empty_i = '0' then
        nb    := rbin + 1;
        rbin  <= nb;
        rgray <= nb xor shift_right(nb, 1);
      end if;
    end if;
  end process;

  dout <= mem(to_integer(rbin(G_AW-1 downto 0)));

end architecture rtl;
