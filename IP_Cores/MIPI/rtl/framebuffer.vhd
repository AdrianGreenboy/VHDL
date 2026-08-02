-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- Framebuffer: simple dual-port RAM (canonical SDP mold for Versal BRAM).
-- One synchronous write port, one synchronous read port. ram_style=block so
-- synthesis maps to RAMB18E5_INT rather than distributed FFs.
--
-- Stores PACKED RAW12 payload bytes (8-bit words). Depth = W*H*3/2 for the
-- test frame; parameterizable via generic.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity framebuffer is
  generic (
    DEPTH : integer := 18432;      -- bytes
    AWID  : integer := 15          -- ceil(log2(18432)) = 15
  );
  port (
    clk    : in  std_logic;
    -- write port
    we     : in  std_logic;
    waddr  : in  std_logic_vector(AWID-1 downto 0);
    wdata  : in  std_logic_vector(7 downto 0);
    -- read port
    re     : in  std_logic;
    raddr  : in  std_logic_vector(AWID-1 downto 0);
    rdata  : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of framebuffer is
  type ram_t is array(0 to DEPTH-1) of std_logic_vector(7 downto 0);
  signal ram : ram_t;
  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";
  signal rdata_r : std_logic_vector(7 downto 0) := (others => '0');
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        ram(to_integer(unsigned(waddr))) <= wdata;
      end if;
      if re = '1' then
        if to_integer(unsigned(raddr)) < DEPTH then
          rdata_r <= ram(to_integer(unsigned(raddr)));
        else
          rdata_r <= (others => '0');
        end if;
      end if;
    end if;
  end process;
  rdata <= rdata_r;
end architecture;
