-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L5: self-test top. Integrates the synthetic camera (frame_gen), the byte-
-- clock D-PHY model, and the dual-VC CSI-2 receiver. The two framebuffers are
-- exposed via read ports for the RV32 firmware to fold FNV and DMA to DDR.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_selftest is
  generic (
    W : integer := 128;
    H : integer := 96;
    FB_DEPTH : integer := 18432;
    FB_AWID  : integer := 15
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    start      : in  std_logic;
    done       : out std_logic;       -- both frames received
    -- framebuffer read ports (to firmware / DMA)
    fb0_re     : in  std_logic;
    fb0_raddr  : in  std_logic_vector(FB_AWID-1 downto 0);
    fb0_rdata  : out std_logic_vector(7 downto 0);
    fb0_count  : out std_logic_vector(FB_AWID-1 downto 0);
    fb1_re     : in  std_logic;
    fb1_raddr  : in  std_logic_vector(FB_AWID-1 downto 0);
    fb1_rdata  : out std_logic_vector(7 downto 0);
    fb1_count  : out std_logic_vector(FB_AWID-1 downto 0);
    hdr_2bit   : out std_logic
  );
end entity;

architecture rtl of csi2_selftest is
  signal gen_byte  : std_logic_vector(7 downto 0);
  signal gen_valid : std_logic;
  signal gen_busy, gen_done : std_logic;
  signal phy_byte  : std_logic_vector(7 downto 0);
  signal phy_valid : std_logic;
  signal fifo_byte : std_logic_vector(7 downto 0);
  signal fifo_valid : std_logic;
  signal fifo_full, fifo_empty : std_logic;
  signal frame_done : std_logic;
  signal fe_count : unsigned(1 downto 0) := (others=>'0');  -- count FE pulses
  signal gen_started : std_logic := '0';
  signal done_i : std_logic := '0';
begin

  gen : entity work.frame_gen
    generic map (W=>W, H=>H, BAR_W=>16)
    port map (clk=>clk, rst=>rst, start=>start, stall=>fifo_full,
              byte_out=>gen_byte, byte_valid=>gen_valid,
              busy=>gen_busy, done=>gen_done);

  phy : entity work.dphy_model
    generic map (NUM_LANES=>4)
    port map (clk=>clk, rst=>rst,
              in_byte=>gen_byte, in_valid=>gen_valid,
              out_byte=>phy_byte, out_valid=>phy_valid);

  fifo : entity work.byte_fifo
    generic map (DEPTH=>512, AWID=>9)
    port map (clk=>clk, rst=>rst,
              wr_byte=>phy_byte, wr_valid=>phy_valid, full=>fifo_full,
              rd_byte=>fifo_byte, rd_valid=>fifo_valid, empty=>fifo_empty);

  rx : entity work.csi2_dual_rx
    generic map (FB_DEPTH=>FB_DEPTH, FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst,
              byte_in=>fifo_byte, byte_valid=>fifo_valid,
              frame_done=>frame_done,
              fb0_re=>fb0_re, fb0_raddr=>fb0_raddr, fb0_rdata=>fb0_rdata, fb0_count=>fb0_count,
              fb1_re=>fb1_re, fb1_raddr=>fb1_raddr, fb1_rdata=>fb1_rdata, fb1_count=>fb1_count,
              hdr_2bit=>hdr_2bit);

  -- done when both frame-end packets have been received (2 VCs).
  -- Gated by gen_started so a spurious frame_done during reset/startup (before
  -- any real data) cannot latch done early.
  process(clk)
  begin
    if rising_edge(clk) then
      done_i <= '0';
      if rst='1' then
        fe_count <= (others=>'0');
        gen_started <= '0';
      else
        if gen_busy='1' then
          gen_started <= '1';
        end if;
        if frame_done='1' and gen_started='1' then
          if fe_count = 1 then
            done_i <= '1';
            fe_count <= (others=>'0');
          else
            fe_count <= fe_count + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  done <= done_i;
end architecture;
