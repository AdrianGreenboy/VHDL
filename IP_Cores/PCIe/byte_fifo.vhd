-- ============================================================================
-- byte_fifo.vhd -- FIFO de bytes canonica de la familia (mold SDP)
-- Contrato de puertos identico al de ~/spi_ip/byte_fifo.vhd:
--   clk, aresetn (async activo-bajo), wr_en, wr_data(7:0), full,
--   rd_en, rd_data(7:0), empty, level : unsigned(LOG2_DEPTH downto 0)
-- Inferible como BRAM SDP (una escritura sincrona, una lectura sincrona).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity byte_fifo is
  generic (
    LOG2_DEPTH : integer := 9   -- 512 bytes
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(7 downto 0);
    full    : out std_logic;
    rd_en   : in  std_logic;
    rd_data : out std_logic_vector(7 downto 0);
    empty   : out std_logic;
    level   : out unsigned(LOG2_DEPTH downto 0)
  );
end entity;

architecture rtl of byte_fifo is
  constant DEPTH : integer := 2**LOG2_DEPTH;
  type mem_t is array (0 to DEPTH-1) of std_logic_vector(7 downto 0);
  signal mem : mem_t;
  attribute ram_style : string;
  attribute ram_style of mem : signal is "block";

  signal wptr, rptr : unsigned(LOG2_DEPTH downto 0) := (others=>'0');
  signal rdata_r : std_logic_vector(7 downto 0) := (others=>'0');
begin
  -- FWFT: rd_data muestra combinacionalmente el frente de la cola. rd_en solo
  -- avanza el puntero (consume). Asi no hay latencia de lectura.
  level <= wptr - rptr;
  empty <= '1' when wptr = rptr else '0';
  full  <= '1' when (wptr(LOG2_DEPTH) /= rptr(LOG2_DEPTH)) and
                    (wptr(LOG2_DEPTH-1 downto 0) = rptr(LOG2_DEPTH-1 downto 0))
           else '0';
  rd_data <= mem(to_integer(rptr(LOG2_DEPTH-1 downto 0)));

  process(clk, aresetn)
  begin
    if aresetn = '0' then
      wptr <= (others=>'0'); rptr <= (others=>'0');
    elsif rising_edge(clk) then
      if wr_en = '1' then
        mem(to_integer(wptr(LOG2_DEPTH-1 downto 0))) <= wr_data;
        wptr <= wptr + 1;
      end if;
      if rd_en = '1' then
        rptr <= rptr + 1;
      end if;
    end if;
  end process;

end architecture;
