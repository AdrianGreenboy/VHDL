-- ============================================================================
--  byte_fifo.vhd — FALLBACK LOCAL del FIFO FWFT de bytes
--
--  El ORIGINAL vive en ~/spi_ip/byte_fifo.vhd y tiene PRIORIDAD en
--  run_mmio.sh (fuentes compartidas se referencian desde su origen, no se
--  duplican). Este fallback replica la entidad exacta para que el proyecto
--  compile en entornos sin ~/spi_ip (p. ej. CI o esta validación GHDL).
--
--  FWFT: rd_data presenta la cabeza de la cola SIN pulsar rd_en; rd_en
--  consume. aresetn ASÍNCRONO activo bajo (como el original del SPI).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity byte_fifo is
  generic (
    LOG2_DEPTH : natural := 8            -- 2**8 = 256 bytes
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
end entity byte_fifo;

architecture rtl of byte_fifo is
  constant DEPTH : natural := 2 ** LOG2_DEPTH;
  type ram_t is array (0 to DEPTH - 1) of std_logic_vector(7 downto 0);
  signal ram : ram_t := (others => (others => '0'));
  signal wp, rp : unsigned(LOG2_DEPTH downto 0) := (others => '0');
  signal lvl : unsigned(LOG2_DEPTH downto 0);
begin

  lvl     <= wp - rp;
  level   <= lvl;
  empty   <= '1' when lvl = 0 else '0';
  full    <= '1' when lvl = DEPTH else '0';
  rd_data <= ram(to_integer(rp(LOG2_DEPTH - 1 downto 0)));   -- FWFT

  process(clk, aresetn)
  begin
    if aresetn = '0' then
      wp <= (others => '0');
      rp <= (others => '0');
    elsif rising_edge(clk) then
      if wr_en = '1' and lvl /= DEPTH then
        ram(to_integer(wp(LOG2_DEPTH - 1 downto 0))) <= wr_data;
        wp <= wp + 1;
      end if;
      if rd_en = '1' and lvl /= 0 then
        rp <= rp + 1;
      end if;
    end if;
  end process;

end architecture rtl;
