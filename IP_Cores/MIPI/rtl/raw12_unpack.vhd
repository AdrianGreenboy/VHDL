-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L1: RAW12 de-packer (isolated, no PHY, no packets)
--
-- Consumes a packed RAW12 byte stream (3 bytes -> 2 pixels) and emits 12-bit
-- pixels. RAW12 layout (must match Python oracle byte-for-byte):
--     b0 = P0[11:4]
--     b1 = P1[11:4]
--     b2 = (P1[3:0] << 4) | P0[3:0]
--
-- Interface: byte-in handshake (byte_valid), pixel-out handshake (pix_valid).
-- Every 3 input bytes produce 2 output pixels (P0 first, then P1).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity raw12_unpack is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;               -- synchronous, active high
    -- byte input
    byte_in    : in  std_logic_vector(7 downto 0);
    byte_valid : in  std_logic;
    -- pixel output
    pix_out    : out std_logic_vector(11 downto 0);
    pix_valid  : out std_logic
  );
end entity;

architecture rtl of raw12_unpack is
  -- byte phase within a 3-byte group: 0 -> b0, 1 -> b1, 2 -> b2
  signal phase : unsigned(1 downto 0) := (others => '0');
  signal b0_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal b1_r  : std_logic_vector(7 downto 0) := (others => '0');

  -- output pipeline: on b2 we emit two pixels back-to-back. We stage P1 to
  -- the following cycle so the interface stays one-pixel-per-cycle.
  signal p1_pending : std_logic := '0';
  signal p1_r       : std_logic_vector(11 downto 0) := (others => '0');

  signal pix_out_i   : std_logic_vector(11 downto 0);
  signal pix_valid_i : std_logic;
begin

  process(clk)
    variable p0 : std_logic_vector(11 downto 0);
    variable p1 : std_logic_vector(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        phase       <= (others => '0');
        p1_pending  <= '0';
        pix_valid_i <= '0';
        pix_out_i   <= (others => '0');
      else
        -- default: no output this cycle
        pix_valid_i <= '0';

        -- emit the staged P1 if one is pending (takes priority so the two
        -- pixels of a group appear on consecutive cycles)
        if p1_pending = '1' then
          pix_out_i   <= p1_r;
          pix_valid_i <= '1';
          p1_pending  <= '0';
        elsif byte_valid = '1' then
          case to_integer(phase) is
            when 0 =>
              b0_r  <= byte_in;
              phase <= "01";
            when 1 =>
              b1_r  <= byte_in;
              phase <= "10";
            when others =>  -- phase = 2, byte_in = b2
              -- reconstruct both pixels
              p0 := b0_r & byte_in(3 downto 0);
              p1 := b1_r & byte_in(7 downto 4);
              -- emit P0 now, stage P1 for next cycle
              pix_out_i   <= p0;
              pix_valid_i <= '1';
              p1_r        <= p1;
              p1_pending  <= '1';
              phase       <= "00";
          end case;
        end if;
      end if;
    end if;
  end process;

  pix_out   <= pix_out_i;
  pix_valid <= pix_valid_i;

end architecture;
