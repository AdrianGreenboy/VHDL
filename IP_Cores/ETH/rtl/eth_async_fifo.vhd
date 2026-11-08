-- eth_async_fifo.vhd - small dual-clock FIFO with Gray-coded pointers
-- ---------------------------------------------------------------------------
-- Classic Cummings "style 1" asynchronous FIFO:
--   * binary + Gray pointers with one extra MSB (full/empty disambiguation)
--   * each Gray pointer crosses into the other domain through a 2-FF
--     synchronizer (ASYNC_REG); only ONE bit of a Gray pointer changes per
--     increment, so a sample taken mid-transition is either the old or the
--     new pointer, never a corrupt one.
--   * full is computed in the write domain against the synchronized read
--     pointer (pessimistic), empty in the read domain against the
--     synchronized write pointer (pessimistic) -> never overflows/underflows.
--   * storage is a small FLIP-FLOP register file (2**LOG2_DEPTH entries, used
--     with LOG2_DEPTH = 3 for MII nibbles). The head is read through a mux in
--     the read domain; an entry is only visible to the reader >= 2 read clocks
--     after it was written, so the mux input is stable when sampled. This is a
--     register file, not an SRAM macro, so the "no asynchronous-read RAM" ASIC
--     rule does not apply (it is ~8 x 6 flops).
--
-- Resets: one synchronous active-high reset per domain (wrst in wclk domain,
-- rrst in rclk domain), each produced by an eth_rst_sync cell by the user.
-- The user must keep the reader in reset until the writer has left reset
-- (eth_mii_cdc does this) so the reader never observes an unreset pointer.
--
-- STA: the paths wgray->rgs1 / rgray->wgs1 and mem->rdata are asynchronous;
-- constrain with set_max_delay -datapath_only <= min(Twclk,Trclk) and
-- set_bus_skew (see AUDIT_FIXES.md).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_async_fifo is
  generic (
    WIDTH      : positive := 6;
    LOG2_DEPTH : positive := 3          -- >= 2
  );
  port (
    -- write domain
    wclk   : in  std_logic;
    wrst   : in  std_logic;
    wen    : in  std_logic;
    wdata  : in  std_logic_vector(WIDTH-1 downto 0);
    wfull  : out std_logic;
    wlevel : out unsigned(LOG2_DEPTH downto 0);   -- pessimistic fill level
    -- read domain
    rclk   : in  std_logic;
    rrst   : in  std_logic;
    ren    : in  std_logic;
    rdata  : out std_logic_vector(WIDTH-1 downto 0);  -- head (FWFT)
    rempty : out std_logic
  );
end entity eth_async_fifo;

architecture rtl of eth_async_fifo is
  constant L     : natural := LOG2_DEPTH;
  constant DEPTH : natural := 2**L;

  type mem_t is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
  signal mem : mem_t := (others => (others => '0'));

  subtype ptr_t is unsigned(L downto 0);
  signal wbin, wgray : ptr_t := (others => '0');
  signal rbin, rgray : ptr_t := (others => '0');
  signal rgs1, rgs2  : ptr_t := (others => '0');   -- rgray synced to wclk
  signal wgs1, wgs2  : ptr_t := (others => '0');   -- wgray synced to rclk
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of rgs1 : signal is "TRUE";
  attribute ASYNC_REG of rgs2 : signal is "TRUE";
  attribute ASYNC_REG of wgs1 : signal is "TRUE";
  attribute ASYNC_REG of wgs2 : signal is "TRUE";

  signal full_i, empty_i : std_logic;

  function bin2gray(b : ptr_t) return ptr_t is
  begin
    return b xor shift_right(b, 1);
  end function;

  function gray2bin(g : ptr_t) return ptr_t is
    variable b : ptr_t;
  begin
    b(L) := g(L);
    for i in L-1 downto 0 loop
      b(i) := b(i+1) xor g(i);
    end loop;
    return b;
  end function;
begin
  assert LOG2_DEPTH >= 2
    report "eth_async_fifo: LOG2_DEPTH must be >= 2" severity failure;

  -- ---------------- write domain ----------------
  full_i <= '1' when wgray = ((not rgs2(L downto L-1)) & rgs2(L-2 downto 0)) else '0';
  wfull  <= full_i;
  wlevel <= wbin - gray2bin(rgs2);

  p_w : process(wclk)
    variable nb : ptr_t;
  begin
    if rising_edge(wclk) then
      if wrst = '1' then
        wbin <= (others => '0');
        wgray <= (others => '0');
        rgs1 <= (others => '0');
        rgs2 <= (others => '0');
      else
        rgs1 <= rgray;
        rgs2 <= rgs1;
        if wen = '1' and full_i = '0' then
          mem(to_integer(wbin(L-1 downto 0))) <= wdata;
          nb    := wbin + 1;
          wbin  <= nb;
          wgray <= bin2gray(nb);
        end if;
      end if;
    end if;
  end process;

  -- ---------------- read domain -----------------
  empty_i <= '1' when rgray = wgs2 else '0';
  rempty  <= empty_i;
  rdata   <= mem(to_integer(rbin(L-1 downto 0)));

  p_r : process(rclk)
    variable nb : ptr_t;
  begin
    if rising_edge(rclk) then
      if rrst = '1' then
        rbin <= (others => '0');
        rgray <= (others => '0');
        wgs1 <= (others => '0');
        wgs2 <= (others => '0');
      else
        wgs1 <= wgray;
        wgs2 <= wgs1;
        if ren = '1' and empty_i = '0' then
          nb    := rbin + 1;
          rbin  <= nb;
          rgray <= bin2gray(nb);
        end if;
      end if;
    end if;
  end process;
end architecture rtl;
