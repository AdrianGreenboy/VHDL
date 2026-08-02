-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L3: single-VC frame receiver datapath.
-- Wires csi2_packet_rx -> framebuffer (stores PACKED RAW12 bytes) with
-- per-line CRC commit: payload bytes are written speculatively to the current
-- line region; on pl_commit the base write pointer advances, on pl_drop the
-- line is abandoned (rewritten by the retransmit / next packet).
--
-- In parallel, raw12_unpack consumes the same payload bytes as a side-check
-- datapath (its pixel output is exposed for the TB to sign independently).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_frame_rx is
  generic (
    FB_DEPTH : integer := 18432;
    FB_AWID  : integer := 15
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    byte_in    : in  std_logic_vector(7 downto 0);
    byte_valid : in  std_logic;
    -- frame status
    frame_done : out std_logic;    -- pulse on Frame End short packet
    -- framebuffer read port (for TB / DMA)
    fb_re      : in  std_logic;
    fb_raddr   : in  std_logic_vector(FB_AWID-1 downto 0);
    fb_rdata   : out std_logic_vector(7 downto 0);
    fb_wcount  : out std_logic_vector(FB_AWID-1 downto 0);  -- committed byte count
    -- side-check pixel output (from raw12_unpack)
    px_out     : out std_logic_vector(11 downto 0);
    px_valid   : out std_logic
  );
end entity;

architecture rtl of csi2_frame_rx is
  -- packet layer signals
  signal pl_byte   : std_logic_vector(7 downto 0);
  signal pl_valid  : std_logic;
  signal pl_commit : std_logic;
  signal pl_drop   : std_logic;
  signal sop       : std_logic;
  signal is_long   : std_logic;
  signal vc_out    : std_logic_vector(1 downto 0);
  signal dt_out    : std_logic_vector(5 downto 0);
  signal hdr_2bit  : std_logic;

  -- framebuffer write pointers
  signal base_ptr  : unsigned(FB_AWID-1 downto 0) := (others => '0'); -- committed
  signal spec_ptr  : unsigned(FB_AWID-1 downto 0) := (others => '0'); -- speculative
  signal fb_we     : std_logic;
  signal fb_waddr  : std_logic_vector(FB_AWID-1 downto 0);
  signal fb_wdata  : std_logic_vector(7 downto 0);

  signal frame_done_i : std_logic := '0';
begin

  -- packet parser (L2)
  pkt : entity work.csi2_packet_rx
    port map (clk=>clk, rst=>rst, byte_in=>byte_in, byte_valid=>byte_valid,
              pl_byte=>pl_byte, pl_valid=>pl_valid, pl_commit=>pl_commit,
              pl_drop=>pl_drop, sop=>sop, is_long=>is_long,
              vc_out=>vc_out, dt_out=>dt_out, hdr_2bit=>hdr_2bit);

  -- unpacker (L1) side-check: fed with the same validated payload bytes
  unp : entity work.raw12_unpack
    port map (clk=>clk, rst=>rst,
              byte_in=>pl_byte, byte_valid=>pl_valid,
              pix_out=>px_out, pix_valid=>px_valid);

  -- framebuffer (packed store)
  fb : entity work.framebuffer
    generic map (DEPTH=>FB_DEPTH, AWID=>FB_AWID)
    port map (clk=>clk, we=>fb_we, waddr=>fb_waddr, wdata=>fb_wdata,
              re=>fb_re, raddr=>fb_raddr, rdata=>fb_rdata);

  fb_we    <= pl_valid;
  fb_waddr <= std_logic_vector(spec_ptr);
  fb_wdata <= pl_byte;

  process(clk)
  begin
    if rising_edge(clk) then
      frame_done_i <= '0';
      if rst = '1' then
        base_ptr <= (others => '0');
        spec_ptr <= (others => '0');
      else
        -- speculative pointer advances with each payload byte written
        if pl_valid = '1' then
          spec_ptr <= spec_ptr + 1;
        end if;
        -- commit: line CRC good -> base advances to speculative
        if pl_commit = '1' then
          base_ptr <= spec_ptr;
        end if;
        -- drop: line CRC bad -> rewind speculative to last committed base
        if pl_drop = '1' then
          spec_ptr <= base_ptr;
        end if;
        -- frame end short packet (dt = 0x01) with is_long=0
        if sop = '1' and is_long = '0' and dt_out = "000001" then
          frame_done_i <= '1';
        end if;
      end if;
    end if;
  end process;

  frame_done <= frame_done_i;
  fb_wcount  <= std_logic_vector(base_ptr);

end architecture;
