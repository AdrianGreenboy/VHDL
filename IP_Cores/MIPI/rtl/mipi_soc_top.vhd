-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- SoC integration wrapper: MIPI peripheral hung off the RV32 dmem bus, with its
-- own AXI4 master to the NoC (second master alongside the core's DMA).
--
-- dmem-side interface (decoded at 0xD0000000 by soc_top_mipi):
--   mmio_sel/we/addr/wdata/rdata - the RV32 controls the self-test and reads
--   the framebuffers via the streaming FBDATA port, exactly as validated in L5.
-- AXI master side: the MIPI DMA (mipi_dma_burst) copies framebuffers to DDR
--   through a dedicated 40-bit AXI4 master (independent of the core's DMA).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mipi_soc_top is
  generic (
    W : integer := 128;
    H : integer := 96;
    FB_DEPTH : integer := 18432;
    FB_AWID  : integer := 15;
    AXI_AW   : integer := 40
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                      -- sync, active high
    -- dmem-side MMIO (decoded to 0xD0000000 upstream)
    mmio_sel   : in  std_logic;
    mmio_we    : in  std_logic;
    mmio_addr  : in  std_logic_vector(15 downto 0);
    mmio_wdata : in  std_logic_vector(31 downto 0);
    mmio_rdata : out std_logic_vector(31 downto 0);
    -- dedicated AXI4 master to the NoC/DDR (40-bit address)
    m_awaddr  : out std_logic_vector(AXI_AW-1 downto 0);
    m_awlen   : out std_logic_vector(7 downto 0);
    m_awsize  : out std_logic_vector(2 downto 0);
    m_awburst : out std_logic_vector(1 downto 0);
    m_awvalid : out std_logic;
    m_awready : in  std_logic;
    m_wdata   : out std_logic_vector(31 downto 0);
    m_wstrb   : out std_logic_vector(3 downto 0);
    m_wlast   : out std_logic;
    m_wvalid  : out std_logic;
    m_wready  : in  std_logic;
    m_bresp   : in  std_logic_vector(1 downto 0);
    m_bvalid  : in  std_logic;
    m_bready  : out std_logic
  );
end entity;

architecture rtl of mipi_soc_top is
  signal st_start, st_done, hdr2 : std_logic;
  signal fb0_re, fb1_re : std_logic;
  signal fb0_raddr, fb1_raddr : std_logic_vector(FB_AWID-1 downto 0);
  signal fb0_rdata, fb1_rdata : std_logic_vector(7 downto 0);
  signal fb0_count, fb1_count : std_logic_vector(FB_AWID-1 downto 0);

  signal mm_fb0_re, mm_fb1_re : std_logic;
  signal mm_fb0_ra, mm_fb1_ra : std_logic_vector(FB_AWID-1 downto 0);

  signal dma_start_i : std_logic;
  signal dma_src_i, dma_dst_i, dma_len_i : std_logic_vector(31 downto 0);
  signal dma_done_i  : std_logic;
  signal dma_fb_sel, dma_fb_re : std_logic;
  signal dma_fb_addr : std_logic_vector(FB_AWID-1 downto 0);
  signal dma_fb_data : std_logic_vector(7 downto 0);
  signal dma_running : std_logic;

  -- 32-bit AXI addr from the MIPI DMA, zero-extended to AXI_AW for the NoC
  signal awaddr32 : std_logic_vector(31 downto 0);
begin

  selftest : entity work.csi2_selftest
    generic map (W=>W, H=>H, FB_DEPTH=>FB_DEPTH, FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst, start=>st_start, done=>st_done,
              fb0_re=>fb0_re, fb0_raddr=>fb0_raddr, fb0_rdata=>fb0_rdata, fb0_count=>fb0_count,
              fb1_re=>fb1_re, fb1_raddr=>fb1_raddr, fb1_rdata=>fb1_rdata, fb1_count=>fb1_count,
              hdr_2bit=>hdr2);

  mmio : entity work.csi2_mmio
    generic map (FB_DEPTH=>FB_DEPTH, FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst,
              mmio_sel=>mmio_sel, mmio_we=>mmio_we, mmio_addr=>mmio_addr,
              mmio_wdata=>mmio_wdata, mmio_rdata=>mmio_rdata,
              dma_start=>dma_start_i, dma_src=>dma_src_i, dma_dst=>dma_dst_i,
              dma_len=>dma_len_i, dma_done=>dma_done_i,
              fb0_re=>mm_fb0_re, fb0_raddr=>mm_fb0_ra, fb0_rdata=>fb0_rdata, fb0_count=>fb0_count,
              fb1_re=>mm_fb1_re, fb1_raddr=>mm_fb1_ra, fb1_rdata=>fb1_rdata, fb1_count=>fb1_count,
              st_start=>st_start, st_done=>st_done, hdr_2bit=>hdr2);

  dma : entity work.mipi_dma_burst
    generic map (FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst,
              start=>dma_start_i, src_sel=>dma_src_i(0), dst_addr=>dma_dst_i, length=>dma_len_i,
              done=>dma_done_i,
              fb_sel=>dma_fb_sel, fb_re=>dma_fb_re, fb_addr=>dma_fb_addr, fb_data=>dma_fb_data,
              m_awaddr=>awaddr32, m_awlen=>m_awlen, m_awsize=>m_awsize, m_awburst=>m_awburst,
              m_awvalid=>m_awvalid, m_awready=>m_awready,
              m_wdata=>m_wdata, m_wstrb=>m_wstrb, m_wlast=>m_wlast, m_wvalid=>m_wvalid, m_wready=>m_wready,
              m_bresp=>m_bresp, m_bvalid=>m_bvalid, m_bready=>m_bready);

  -- zero-extend 32-bit DMA address to the NoC's 40-bit master address
  m_awaddr <= std_logic_vector(resize(unsigned(awaddr32), AXI_AW));

  dma_running <= dma_fb_re;
  fb0_re    <= dma_fb_re   when (dma_running='1' and dma_fb_sel='0') else mm_fb0_re;
  fb0_raddr <= dma_fb_addr when (dma_running='1' and dma_fb_sel='0') else mm_fb0_ra;
  fb1_re    <= dma_fb_re   when (dma_running='1' and dma_fb_sel='1') else mm_fb1_re;
  fb1_raddr <= dma_fb_addr when (dma_running='1' and dma_fb_sel='1') else mm_fb1_ra;
  dma_fb_data <= fb0_rdata when dma_fb_sel='0' else fb1_rdata;

end architecture;
