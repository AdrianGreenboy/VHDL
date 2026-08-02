-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L5: elastic byte FIFO decoupling the continuous byte-clock D-PHY stream from
-- the CSI-2 parser. The frame_gen / D-PHY produce one byte per cycle
-- continuously; the parser needs idle cycles for its header-decode and
-- CRC-check states. This FIFO buffers the burst and drains it to the parser
-- at a pace the parser tolerates (one byte, then two bubble cycles).
--
-- Depth sized to hold one full line's worth of over-run (256 bytes) which is
-- ample: the generator stalls naturally between packets, so the FIFO never
-- fills in the 128x96 self-test. Depth is a generic for larger frames.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity byte_fifo is
  generic (
    DEPTH : integer := 512;
    AWID  : integer := 9
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    -- write side (from D-PHY)
    wr_byte   : in  std_logic_vector(7 downto 0);
    wr_valid  : in  std_logic;
    full      : out std_logic;
    -- read side (to parser) with pacing
    rd_byte   : out std_logic_vector(7 downto 0);
    rd_valid  : out std_logic;
    empty     : out std_logic
  );
end entity;

architecture rtl of byte_fifo is
  type mem_t is array(0 to DEPTH-1) of std_logic_vector(7 downto 0);
  signal mem : mem_t;
  signal wptr, rptr : unsigned(AWID-1 downto 0) := (others=>'0');
  signal count : unsigned(AWID downto 0) := (others=>'0');

  -- pacing: after presenting a byte, insert 2 bubble cycles
  signal pace : unsigned(1 downto 0) := (others=>'0');
  signal rd_valid_i : std_logic := '0';
  signal rd_byte_i  : std_logic_vector(7 downto 0) := (others=>'0');

  signal empty_i : std_logic;
begin
  empty_i <= '1' when count = 0 else '0';
  empty   <= empty_i;
  -- assert 'full' early (almost-full) so the generator stalls with margin to
  -- absorb the 1-cycle stall-detection latency without dropping a byte.
  full    <= '1' when count >= DEPTH-4 else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      rd_valid_i <= '0';
      if rst='1' then
        wptr <= (others=>'0'); rptr <= (others=>'0');
        count <= (others=>'0'); pace <= (others=>'0');
      else
        -- write
        if wr_valid='1' and count < DEPTH then
          mem(to_integer(wptr)) <= wr_byte;
          wptr <= wptr + 1;
          -- net count update handled below with simultaneous read
        end if;

        -- read with pacing
        if pace = 0 then
          if empty_i = '0' then
            rd_byte_i  <= mem(to_integer(rptr));
            rd_valid_i <= '1';
            rptr <= rptr + 1;
            pace <= "10";  -- 2 bubble cycles follow
          end if;
        else
          pace <= pace - 1;
        end if;

        -- count bookkeeping (write +1, read -1)
        if (wr_valid='1' and count<DEPTH) and (pace=0 and empty_i='0') then
          count <= count;              -- +1 -1
        elsif (wr_valid='1' and count<DEPTH) then
          count <= count + 1;
        elsif (pace=0 and empty_i='0') then
          count <= count - 1;
        end if;
      end if;
    end if;
  end process;

  rd_byte  <= rd_byte_i;
  rd_valid <= rd_valid_i;
end architecture;
