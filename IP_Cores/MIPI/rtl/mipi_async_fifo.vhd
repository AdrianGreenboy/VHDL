-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- mipi_async_fifo (AUDIT 2026-11): dual-clock FIFO, D-PHY byte clock -> aclk.
--
-- Classic Cummings style:
--  * binary + Gray pointers of AW+1 bits in each domain;
--  * the opposite Gray pointer crosses through a 2-flop synchronizer
--    (attribute ASYNC_REG for FPGA; on ASIC use the library sync cell);
--  * full  = next write Gray == {~rq2(MSB..MSB-1), rq2(MSB-2..0)}
--    empty = read Gray == synchronized write Gray;
--  * memory: 1 write port (wclk) + 1 registered read port (rclk) -> maps to a
--    dual-clock SRAM macro / BRAM.
--  * a write while full is dropped and reported: a toggle in wclk crosses a
--    3-flop synchronizer and becomes the single-cycle 'ovf_pulse' in rclk.
-- Read interface: assert rd_en while 'empty'='0'; rd_data/rd_valid one cycle
-- later. Each side has its own synchronous active-high reset (asserted
-- together at the top; both must be released with their clocks running).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mipi_async_fifo is
  generic (
    DW : integer := 37;
    AW : integer := 6            -- depth = 2**AW
  );
  port (
    -- write side
    wclk     : in  std_logic;
    wrst     : in  std_logic;
    wr_en    : in  std_logic;
    wr_data  : in  std_logic_vector(DW-1 downto 0);
    wr_full  : out std_logic;
    -- read side
    rclk     : in  std_logic;
    rrst     : in  std_logic;
    rd_en    : in  std_logic;
    rd_data  : out std_logic_vector(DW-1 downto 0);
    rd_valid : out std_logic;
    rd_empty : out std_logic;
    ovf_pulse: out std_logic          -- rclk domain: a write was dropped
  );
end entity;

architecture rtl of mipi_async_fifo is
  type mem_t is array (0 to 2**AW-1) of std_logic_vector(DW-1 downto 0);
  signal mem : mem_t;

  function bin2gray(b : unsigned) return unsigned is
  begin
    return b xor shift_right(b, 1);
  end function;

  signal wbin, wgray : unsigned(AW downto 0) := (others => '0');
  signal rbin, rgray : unsigned(AW downto 0) := (others => '0');
  signal rq1, rq2 : unsigned(AW downto 0) := (others => '0');   -- rgray in wclk
  signal wq1, wq2 : unsigned(AW downto 0) := (others => '0');   -- wgray in rclk
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of rq1, rq2, wq1, wq2 : signal is "TRUE";

  signal full_i, empty_i : std_logic;
  signal wgray_nxt : unsigned(AW downto 0);
  signal rdata_r : std_logic_vector(DW-1 downto 0) := (others => '0');
  signal rvalid_r : std_logic := '0';

  signal ovf_tgl : std_logic := '0';
  signal ot1, ot2, ot3 : std_logic := '0';
  attribute ASYNC_REG of ot1, ot2 : signal is "TRUE";
begin
  ---------------------------------------------------------------- write side
  wgray_nxt <= bin2gray(wbin + 1);
  full_i <= '1' when bin2gray(wbin) = ((not rq2(AW downto AW-1)) & rq2(AW-2 downto 0))
            else '0';
  wr_full <= full_i;

  process(wclk)
  begin
    if rising_edge(wclk) then
      rq1 <= rgray; rq2 <= rq1;
      if wrst = '1' then
        wbin <= (others => '0'); wgray <= (others => '0');
        rq1 <= (others => '0'); rq2 <= (others => '0');
      elsif wr_en = '1' then
        if full_i = '0' then
          mem(to_integer(wbin(AW-1 downto 0))) <= wr_data;
          wbin  <= wbin + 1;
          wgray <= wgray_nxt;
        else
          ovf_tgl <= not ovf_tgl;
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------- read side
  empty_i  <= '1' when rgray = wq2 else '0';
  rd_empty <= empty_i;

  process(rclk)
  begin
    if rising_edge(rclk) then
      wq1 <= wgray; wq2 <= wq1;
      ot1 <= ovf_tgl; ot2 <= ot1; ot3 <= ot2;
      rvalid_r <= '0';
      if rrst = '1' then
        rbin <= (others => '0'); rgray <= (others => '0');
        wq1 <= (others => '0'); wq2 <= (others => '0');
        ot3 <= ot2;
      elsif rd_en = '1' and empty_i = '0' then
        rdata_r  <= mem(to_integer(rbin(AW-1 downto 0)));
        rvalid_r <= '1';
        rbin  <= rbin + 1;
        rgray <= bin2gray(rbin + 1);
      end if;
    end if;
  end process;

  rd_data   <= rdata_r;
  rd_valid  <= rvalid_r;
  ovf_pulse <= ot2 xor ot3;
end architecture;
