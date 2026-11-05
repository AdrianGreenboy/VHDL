-- =============================================================================
--  spi_byte_fifo.vhd  -  Synchronous byte FIFO with FWFT read port, private to the
--                 SPI core (entity name is unique per core so that the
--                 four serial cores never collide in one work library).
--  License: MIT
--
--  Audit 2026-11 (ALTA): replaces the shared/duplicated `byte_fifo` whose
--  copies had the same entity name but divergent reset semantics (async
--  aresetn driven from logic in IIC/I3C, synchronous in SPI/USART).
--
--  Reset : `rst` is SYNCHRONOUS and ACTIVE-HIGH. No asynchronous pins.
--  clr   : synchronous flush (pointers/count to zero), same effect as rst on
--          the FIFO state. Tie to '0' if unused.
--
--  Storage / FWFT:
--    The array `mem` is only ever accessed through ONE synchronous write
--    port and ONE synchronous (registered) read port whose address is the
--    NEXT read pointer, so it maps onto a simple-dual-port SRAM macro
--    (IHP SG13G2 / sky130 OpenRAM) or FPGA BRAM/LUTRAM with registered
--    output. A 1-deep prefetch register `head` holds mem(rp) at all times:
--      * normal case : head <= mem(rp_next)            (registered read)
--      * bypass case : a push into the slot that becomes the head in the
--                      same cycle (FIFO empty after this cycle's pop)
--                      loads wr_data directly into head (write-through).
--    Result: rd_data/empty/full/level are cycle-for-cycle identical to the
--    former combinational-read FWFT FIFO (rd_data valid in the cycle after
--    the push, pop takes effect on the clock edge), but no asynchronous
--    array read exists anymore.
--    When the FIFO is (or becomes) empty, head is loaded with x"00" so the
--    value seen by a read of an empty FIFO is deterministic (no reliance on
--    SRAM power-up contents).
--
--  Overflow/underflow policy: a push while full and a pop while empty are
--  ignored (the instantiating regfile raises its own sticky flags).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_byte_fifo is
  generic (
    LOG2_DEPTH : natural := 8            -- 2**8 = 256 bytes
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;             -- synchronous, active high
    clr     : in  std_logic := '0';      -- synchronous flush

    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(7 downto 0);
    full    : out std_logic;

    rd_en   : in  std_logic;
    rd_data : out std_logic_vector(7 downto 0);
    empty   : out std_logic;

    level   : out unsigned(LOG2_DEPTH downto 0)
  );
end entity spi_byte_fifo;

architecture rtl of spi_byte_fifo is
  constant DEPTH : natural := 2**LOG2_DEPTH;
  type mem_t is array (0 to DEPTH-1) of std_logic_vector(7 downto 0);
  -- No initial value / no reset on the array: it is SRAM-mappable.
  signal mem  : mem_t;

  signal wp, rp : unsigned(LOG2_DEPTH-1 downto 0) := (others => '0');
  signal cnt    : unsigned(LOG2_DEPTH downto 0)   := (others => '0');
  signal head   : std_logic_vector(7 downto 0)    := (others => '0');

  signal do_push, do_pop : std_logic;
  signal rp_nxt          : unsigned(LOG2_DEPTH-1 downto 0);
  signal cnt_nxt         : unsigned(LOG2_DEPTH downto 0);
  signal head_bypass     : std_logic;
begin

  full    <= '1' when cnt = DEPTH else '0';
  empty   <= '1' when cnt = 0     else '0';
  level   <= cnt;
  rd_data <= head;

  do_push <= '1' when wr_en = '1' and cnt /= DEPTH else '0';
  do_pop  <= '1' when rd_en = '1' and cnt /= 0     else '0';
  rp_nxt  <= rp + 1 when do_pop = '1' else rp;
  cnt_nxt <= cnt + 1 when (do_push = '1' and do_pop = '0') else
             cnt - 1 when (do_push = '0' and do_pop = '1') else
             cnt;
  -- the pushed byte becomes the head right away when the FIFO holds no
  -- other byte after this cycle's pop
  head_bypass <= '1' when do_push = '1' and
                          (cnt = 0 or (cnt = 1 and do_pop = '1')) else '0';

  -- Storage: one synchronous write port + one registered read port.
  p_mem : process(clk)
  begin
    if rising_edge(clk) then
      if do_push = '1' and rst = '0' and clr = '0' then
        mem(to_integer(wp)) <= wr_data;
      end if;
      -- registered read of the next head (read-before-write semantics)
      head <= mem(to_integer(rp_nxt));
      -- write-through bypass / deterministic empty value
      if cnt_nxt = 0 then
        head <= (others => '0');
      elsif head_bypass = '1' then
        head <= wr_data;
      end if;
      if rst = '1' or clr = '1' then
        head <= (others => '0');
      end if;
    end if;
  end process;

  -- Pointers / count (synchronous reset and flush).
  p_ptr : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clr = '1' then
        wp  <= (others => '0');
        rp  <= (others => '0');
        cnt <= (others => '0');
      else
        if do_push = '1' then
          wp <= wp + 1;
        end if;
        rp  <= rp_nxt;
        cnt <= cnt_nxt;
      end if;
    end if;
  end process;

end architecture rtl;
