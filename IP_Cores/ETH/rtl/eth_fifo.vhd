-- eth_fifo.vhd - synchronous-read FWFT FIFO with optional commit/rewind
-- ---------------------------------------------------------------------------
-- Replaces spw_fifo inside eth_mmio (audit 2026-11, ALTA/ASIC: spw_fifo read
-- its memory asynchronously, which maps to no SRAM macro on IHP SG13G2 /
-- sky130 and to LUTRAM on FPGA). Storage is now a single-write-port,
-- single-SYNCHRONOUS-read-port array (SRAM / BRAM friendly); FWFT behaviour
-- is recreated with a 1-entry prefetch output register (pattern of
-- TSN/tsn_fifo.vhd):
--   * rdata/empty describe the output register; rd_en consumes it; the next
--     committed entry is fetched in the same cycle, so back-to-back reads at
--     one per clock are supported.
--   * latency write -> visible is 2 clocks (spw_fifo: 1 clock).
-- Speculative mode (G_SPEC = true, used for the RX path):
--   * written entries are invisible to the reader until wr_commit;
--   * wr_commit / wr_rewind may coincide with wr_en and then INCLUDE that
--     cycle's entry (commit-with-last-byte / discard-with-last-byte);
--   * full accounts for speculative entries (they reserve space).
-- G_SPEC = false: every write is committed immediately.
-- Reset: rst synchronous active-high (clr: synchronous flush).
-- level = committed entries not yet consumed (prefetched one included).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_fifo is
  generic (
    LOG2_DEPTH : positive := 11;
    WIDTH      : positive := 9;
    G_SPEC     : boolean  := false
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    clr       : in  std_logic;
    wr_en     : in  std_logic;
    wdata     : in  std_logic_vector(WIDTH-1 downto 0);
    wr_commit : in  std_logic := '0';
    wr_rewind : in  std_logic := '0';
    full      : out std_logic;
    rd_en     : in  std_logic;
    rdata     : out std_logic_vector(WIDTH-1 downto 0);
    empty     : out std_logic;
    level     : out std_logic_vector(LOG2_DEPTH downto 0)
  );
end entity eth_fifo;

architecture rtl of eth_fifo is
  constant DEPTH : natural := 2**LOG2_DEPTH;
  type ram_t is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
  signal ram : ram_t;
  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";

  subtype ptr_t is unsigned(LOG2_DEPTH downto 0);
  signal wr_ptr, cm_ptr, rd_ptr : ptr_t := (others => '0');
  signal out_reg   : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
  signal out_valid : std_logic := '0';
  signal full_i    : std_logic;
  signal fetch     : std_logic;
  signal do_wr     : std_logic;
begin
  full_i <= '1' when (wr_ptr - rd_ptr) = to_unsigned(DEPTH, LOG2_DEPTH+1) else '0';
  full   <= full_i;
  do_wr  <= wr_en and not full_i;
  fetch  <= '1' when (out_valid = '0' or rd_en = '1') and cm_ptr /= rd_ptr else '0';

  rdata <= out_reg;
  empty <= not out_valid;
  level <= std_logic_vector(cm_ptr - rd_ptr + 1) when out_valid = '1'
           else std_logic_vector(cm_ptr - rd_ptr);

  p_wr : process(clk)
    variable nw : ptr_t;
  begin
    if rising_edge(clk) then
      if rst = '1' or clr = '1' then
        wr_ptr <= (others => '0');
        cm_ptr <= (others => '0');
      else
        nw := wr_ptr;
        if do_wr = '1' then
          ram(to_integer(wr_ptr(LOG2_DEPTH-1 downto 0))) <= wdata;
          nw := wr_ptr + 1;
        end if;
        if not G_SPEC then
          wr_ptr <= nw;
          cm_ptr <= nw;
        else
          assert not (wr_commit = '1' and wr_rewind = '1')
            report "eth_fifo: commit and rewind in the same cycle" severity failure;
          if wr_rewind = '1' then
            wr_ptr <= cm_ptr;                     -- discard (incl. this cycle's write)
          else
            wr_ptr <= nw;
            if wr_commit = '1' then
              cm_ptr <= nw;                       -- commit (incl. this cycle's write)
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  p_rd : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clr = '1' then
        rd_ptr    <= (others => '0');
        out_valid <= '0';
      elsif fetch = '1' then
        out_reg   <= ram(to_integer(rd_ptr(LOG2_DEPTH-1 downto 0)));   -- sync read
        rd_ptr    <= rd_ptr + 1;
        out_valid <= '1';
      elsif rd_en = '1' and out_valid = '1' then
        out_valid <= '0';
      end if;
    end if;
  end process;
end architecture rtl;
