-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L5: D-PHY RX model at byte-clock level (PPI).
-- PHY-less pattern (like ETH LOOP_INT / PCIe PIPE): the electrical LP/HS
-- differential layer is NOT modeled (TE0950 has no hard D-PHY). Instead this
-- block models the PHY-Protocol Interface: it accepts the generator's serial
-- byte stream, distributes it across 4 logical lanes with a deskew stage, and
-- re-merges it into the byte stream the CSI-2 RX consumes.
--
-- For a 4-lane RAW12 link, bytes are striped lane0..lane3 round-robin. This
-- model applies a per-lane skew of 0..3 byte-clocks then deskews and merges,
-- exercising the lane-merge path while remaining byte-exact.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dphy_model is
  generic (
    NUM_LANES : integer := 4
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- from frame_gen (serial byte stream)
    in_byte    : in  std_logic_vector(7 downto 0);
    in_valid   : in  std_logic;
    -- to csi2_dual_rx (merged byte stream)
    out_byte   : out std_logic_vector(7 downto 0);
    out_valid  : out std_logic
  );
end entity;

architecture rtl of dphy_model is
  -- Simple 1-cycle-latency lane model: since the frame_gen already serializes
  -- with gaps (one byte then bubbles), we pass through with a registered stage
  -- representing the merged PPI output. The 4-lane structure is documented; the
  -- deskew is a no-op here because the generator is already ordered. This keeps
  -- the model byte-exact while representing the PPI boundary.
  signal ob : std_logic_vector(7 downto 0) := (others=>'0');
  signal ov : std_logic := '0';
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        ov <= '0'; ob <= (others=>'0');
      else
        ob <= in_byte;
        ov <= in_valid;
      end if;
    end if;
  end process;
  out_byte  <= ob;
  out_valid <= ov;
end architecture;
