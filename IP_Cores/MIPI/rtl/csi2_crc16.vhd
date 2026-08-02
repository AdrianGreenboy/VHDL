-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- Packet Footer CRC-16 (MIPI CSI-2 variant).
--   poly 0x1021, reflected -> 0x8408 ; init 0xFFFF ; LSB-first per byte.
-- Must match the Python oracle crc16_csi2 byte-for-byte.
--
-- Combinational per-byte update: crc_next = f(crc_cur, byte).
-- The parser clocks a new byte in each cycle and accumulates.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_crc16 is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;        -- sync, active high: reloads init value
    init    : in  std_logic;        -- pulse to reload 0xFFFF (start of payload)
    data_in : in  std_logic_vector(7 downto 0);
    valid   : in  std_logic;        -- process data_in this cycle
    crc     : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of csi2_crc16 is
  constant POLY : unsigned(15 downto 0) := x"8408";
  signal crc_r  : unsigned(15 downto 0) := x"FFFF";

  function crc_update(c : unsigned(15 downto 0); b : std_logic_vector(7 downto 0))
    return unsigned is
    variable cc : unsigned(15 downto 0);
  begin
    cc := c xor resize(unsigned(b), 16);
    for i in 0 to 7 loop
      if cc(0) = '1' then
        cc := ('0' & cc(15 downto 1)) xor POLY;
      else
        cc := '0' & cc(15 downto 1);
      end if;
    end loop;
    return cc;
  end function;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or init = '1' then
        crc_r <= x"FFFF";
      elsif valid = '1' then
        crc_r <= crc_update(crc_r, data_in);
      end if;
    end if;
  end process;

  crc <= std_logic_vector(crc_r);
end architecture;
