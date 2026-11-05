-- ============================================================================
--  can_byte_fifo.vhd - FWFT byte FIFO of the CAN IP (registered-read RAM)
--
--  Replaces the former byte_fifo entity (renamed: the name collided with
--  the SPI/other cores' byte_fifo in a shared library).
--
--  * Storage is a RAM with a REGISTERED (synchronous) read port, so it maps
--    to an SRAM macro / BRAM on ASIC and FPGA flows; no combinational read
--    from the array reaches the outputs.
--  * FWFT semantics are kept with a 1-deep prefetch: the RAM read register
--    itself is the output stage. Whenever the output stage is empty (or is
--    being consumed this cycle) and the RAM holds data, the next word is
--    read into it. rd_data always shows the head while empty = '0';
--    rd_en = '1' consumes it, and the next head is valid on the next cycle
--    (back-to-back pops every cycle are supported).
--  * Latency: a word written into an empty FIFO is visible (empty = '0')
--    two cycles after the write cycle.
--  * level counts every stored word (RAM + output stage); full when
--    level = 2**LOG2_DEPTH. Writes when full and reads when empty are
--    ignored.
--  * rst: synchronous, active high (unified reset style).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity can_byte_fifo is
  generic (
    LOG2_DEPTH : natural := 7
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(7 downto 0);
    full    : out std_logic;
    rd_en   : in  std_logic;
    rd_data : out std_logic_vector(7 downto 0);
    empty   : out std_logic;
    level   : out unsigned(LOG2_DEPTH downto 0)
  );
end entity can_byte_fifo;

architecture rtl of can_byte_fifo is
  constant DEPTH : natural := 2 ** LOG2_DEPTH;
  type ram_t is array (0 to DEPTH - 1) of std_logic_vector(7 downto 0);
  signal ram  : ram_t;
  signal wp, rp : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal cnt  : unsigned(LOG2_DEPTH downto 0) := (others => '0'); -- total words
  signal ov   : std_logic := '0';                                 -- output valid
  signal q_r  : std_logic_vector(7 downto 0) := (others => '0');  -- RAM read reg
  signal do_wr, do_pop, do_load : std_logic;
  signal ram_words : unsigned(LOG2_DEPTH downto 0);
begin

  level   <= cnt;
  empty   <= not ov;
  full    <= '1' when cnt = DEPTH else '0';
  rd_data <= q_r;

  ram_words <= cnt - 1 when ov = '1' else cnt;
  do_wr   <= '1' when wr_en = '1' and cnt /= DEPTH else '0';
  do_pop  <= rd_en and ov;
  -- prefetch into the output stage (words written this cycle are not yet
  -- readable: ram_words excludes them)
  do_load <= '1' when ram_words /= 0 and (ov = '0' or do_pop = '1') else '0';

  -- RAM: write port + registered read port (no reset on the array)
  ram_p : process(clk)
  begin
    if rising_edge(clk) then
      if do_wr = '1' then
        ram(to_integer(wp)) <= wr_data;
      end if;
      if do_load = '1' then
        q_r <= ram(to_integer(rp));
      end if;
    end if;
  end process;

  ctl_p : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
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
