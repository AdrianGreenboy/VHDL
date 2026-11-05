-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L5 (silicon): MMIO peripheral wrapper for the RV32IM soft core.
-- Address decode: addr[31:28]="1101" -> 0xD0000000 aperture.
--
-- Register map (word addresses within the aperture):
--   0x000 CTRL   W  bit0 start_selftest, bit1 start_dma
--   0x004 STATUS R/W1C  (sticky; write 1 to clear)
--                bit0 selftest_done, bit1 dma_done, bit2 hdr_2bit (ECC abort)
--                bit3 rx_ovf   bytes lost before the packet layer (FIFO full)
--                bit4 fb_ovf   packet dropped, framebuffer full
--                bit5 pkt_err  packet aborted (ECC 2-bit, SoT/EoT truncation)
--                bit6 lane_err D-PHY deskew timeout / lane FIFO overflow
--                bit7 frame    Frame End received (any VC)
--   0x008 FB0_COUNT R
--   0x00C FB1_COUNT R
--   0x010 DMA_SRC  W  bit0 selects FB (0=FB0,1=FB1)
--   0x014 DMA_DST  W  DDR destination address (4-byte aligned)
--   0x018 DMA_LEN  W  byte count (any value; 0 = no transfer)
--   0x01C FBSEL    W  bit0 selects FB, resets the stream pointer and
--                     PREFETCHES byte 0 (AUDIT 2026-11)
--   0x020 FBDATA   R  byte at the stream pointer, then pointer+1 (prefetch of
--                     the next byte). No priming read is needed any more.
--                     A MIPI DMA uses the same FB read port: write FBSEL again
--                     after a DMA before streaming.
--   0x024 CFG      RW bit0 src_ext (0 self-test, 1 external D-PHY PPI)
--                     bits[3:1] active lanes 1..4 (reset 4)
--                     bit4 hw_sync (PHY delivers aligned bytes, no 0xB8 hunt)
--                     bit5 multi_pkt (several packets per HS burst; only
--                          with a PHY that strips the D-PHY trailer)
--                     change CFG only while the link is idle.
--   0x028 IRQ_EN   RW one enable per STATUS bit; irq = OR(STATUS & IRQ_EN)
--
-- DMA uses the standard doorbell contract: firmware writes SRC/DST/LEN then
-- pulses CTRL.start_dma; dma_burst runs and asserts dma_done.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csi2_mmio is
  generic (
    FB_DEPTH : integer := 18432;
    FB_AWID  : integer := 15
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- RV32 MMIO bus (simple synchronous, valid/ready-less; combinational rdata)
    mmio_sel   : in  std_logic;                       -- addr[31:28]="1101"
    mmio_we    : in  std_logic;
    mmio_addr  : in  std_logic_vector(15 downto 0);   -- offset within aperture
    mmio_wdata : in  std_logic_vector(31 downto 0);
    mmio_rdata : out std_logic_vector(31 downto 0);
    -- to dma_burst (doorbell)
    dma_start  : out std_logic;
    dma_src    : out std_logic_vector(31 downto 0);
    dma_dst    : out std_logic_vector(31 downto 0);
    dma_len    : out std_logic_vector(31 downto 0);
    dma_done   : in  std_logic;
    -- framebuffer read ports into csi2_selftest
    fb0_re     : out std_logic;
    fb0_raddr  : out std_logic_vector(FB_AWID-1 downto 0);
    fb0_rdata  : in  std_logic_vector(7 downto 0);
    fb0_count  : in  std_logic_vector(FB_AWID-1 downto 0);
    fb1_re     : out std_logic;
    fb1_raddr  : out std_logic_vector(FB_AWID-1 downto 0);
    fb1_rdata  : in  std_logic_vector(7 downto 0);
    fb1_count  : in  std_logic_vector(FB_AWID-1 downto 0);
    -- selftest control
    st_start   : out std_logic;
    st_done    : in  std_logic;
    hdr_2bit   : in  std_logic;
    -- AUDIT 2026-11: receiver events (pulses), configuration, interrupt
    ev_rx_ovf  : in  std_logic := '0';
    ev_fb_ovf  : in  std_logic := '0';
    ev_pkt_err : in  std_logic := '0';
    ev_lane_err: in  std_logic := '0';
    ev_frame   : in  std_logic := '0';
    cfg_src_ext   : out std_logic;
    cfg_nlanes    : out std_logic_vector(2 downto 0);
    cfg_hw_sync   : out std_logic;
    cfg_multi_pkt : out std_logic;
    irq        : out std_logic
  );
end entity;

architecture rtl of csi2_mmio is
  signal ctrl_start_st  : std_logic := '0';
  signal ctrl_start_dma : std_logic := '0';
  signal dma_src_r : std_logic_vector(31 downto 0) := (others=>'0');
  signal dma_dst_r : std_logic_vector(31 downto 0) := (others=>'0');
  signal dma_len_r : std_logic_vector(31 downto 0) := (others=>'0');
  signal dma_done_l : std_logic := '0';   -- latched done
  signal st_done_l  : std_logic := '0';
  signal hdr2_l     : std_logic := '0';
  signal rxovf_l, fbovf_l, perr_l, lerr_l, frame_l : std_logic := '0';
  signal cfg_r      : std_logic_vector(5 downto 0) := "001000";   -- 4 lanes
  signal irqen_r    : std_logic_vector(7 downto 0) := (others=>'0');
  signal status_v   : std_logic_vector(7 downto 0);

  signal fb0_re_i, fb1_re_i : std_logic := '0';
  signal fb0_ra, fb1_ra : std_logic_vector(FB_AWID-1 downto 0) := (others=>'0');

  -- address regions
  constant A_CTRL   : std_logic_vector(15 downto 0) := x"0000";
  constant A_STATUS : std_logic_vector(15 downto 0) := x"0004";
  constant A_FB0CNT : std_logic_vector(15 downto 0) := x"0008";
  constant A_FB1CNT : std_logic_vector(15 downto 0) := x"000C";
  constant A_DMASRC : std_logic_vector(15 downto 0) := x"0010";
  constant A_DMADST : std_logic_vector(15 downto 0) := x"0014";
  constant A_DMALEN : std_logic_vector(15 downto 0) := x"0018";
  constant A_FBSEL  : std_logic_vector(15 downto 0) := x"001C";  -- W: bit0 selects FB, write resets stream ptr
  constant A_FBDATA : std_logic_vector(15 downto 0) := x"0020";  -- R: current byte, auto-increments
  constant A_CFG    : std_logic_vector(15 downto 0) := x"0024";
  constant A_IRQEN  : std_logic_vector(15 downto 0) := x"0028";

  signal fb_sel        : std_logic := '0';
  signal fb_stream_ptr : unsigned(FB_AWID-1 downto 0) := (others=>'0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      ctrl_start_st  <= '0';   -- single-cycle pulses
      ctrl_start_dma <= '0';
      if rst='1' then
        dma_src_r <= (others=>'0'); dma_dst_r <= (others=>'0'); dma_len_r <= (others=>'0');
        dma_done_l <= '0'; st_done_l <= '0'; hdr2_l <= '0';
        rxovf_l <= '0'; fbovf_l <= '0'; perr_l <= '0'; lerr_l <= '0'; frame_l <= '0';
        cfg_r <= "001000"; irqen_r <= (others=>'0');
        fb_sel <= '0'; fb_stream_ptr <= (others=>'0');
      else
        -- W1C on STATUS (applied before the set terms: an event in the same
        -- cycle as the clear is not lost)
        if mmio_sel='1' and mmio_we='1' and mmio_addr = A_STATUS then
          if mmio_wdata(0)='1' then st_done_l  <= '0'; end if;
          if mmio_wdata(1)='1' then dma_done_l <= '0'; end if;
          if mmio_wdata(2)='1' then hdr2_l     <= '0'; end if;
          if mmio_wdata(3)='1' then rxovf_l    <= '0'; end if;
          if mmio_wdata(4)='1' then fbovf_l    <= '0'; end if;
          if mmio_wdata(5)='1' then perr_l     <= '0'; end if;
          if mmio_wdata(6)='1' then lerr_l     <= '0'; end if;
          if mmio_wdata(7)='1' then frame_l    <= '0'; end if;
        end if;
        -- latch sticky status
        if dma_done='1' then dma_done_l <= '1'; end if;
        if st_done='1'  then st_done_l  <= '1'; end if;
        if hdr_2bit='1'  then hdr2_l     <= '1'; end if;
        if ev_rx_ovf='1'   then rxovf_l <= '1'; end if;
        if ev_fb_ovf='1'   then fbovf_l <= '1'; end if;
        if ev_pkt_err='1'  then perr_l  <= '1'; end if;
        if ev_lane_err='1' then lerr_l  <= '1'; end if;
        if ev_frame='1'    then frame_l <= '1'; end if;

        if mmio_sel='1' and mmio_we='1' then
          case mmio_addr is
            when A_CTRL =>
              ctrl_start_st  <= mmio_wdata(0);
              ctrl_start_dma <= mmio_wdata(1);
              -- writing start clears the corresponding sticky done
              if mmio_wdata(0)='1' then st_done_l <= '0'; hdr2_l <= '0'; end if;
              if mmio_wdata(1)='1' then dma_done_l <= '0'; end if;
            when A_DMASRC => dma_src_r <= mmio_wdata;
            when A_DMADST => dma_dst_r <= mmio_wdata;
            when A_DMALEN => dma_len_r <= mmio_wdata;
            when A_FBSEL  =>
              fb_sel <= mmio_wdata(0);
              fb_stream_ptr <= (others=>'0');   -- reset stream on select
            when A_CFG    => cfg_r   <= mmio_wdata(5 downto 0);
            when A_IRQEN  => irqen_r <= mmio_wdata(7 downto 0);
            when others => null;
          end case;
        end if;

        -- auto-increment stream pointer on each FBDATA read
        if mmio_sel='1' and mmio_we='0' and mmio_addr=A_FBDATA then
          fb_stream_ptr <= fb_stream_ptr + 1;
        end if;
      end if;
    end if;
  end process;

  -- combinational read data + FB window read address
  process(all)
  begin
    mmio_rdata <= (others=>'0');
    fb0_re_i <= '0'; fb1_re_i <= '0';
    fb0_ra <= (others=>'0'); fb1_ra <= (others=>'0');
    if mmio_sel='1' and mmio_we='1' and mmio_addr = A_FBSEL then
      -- prefetch byte 0 of the newly selected framebuffer
      if mmio_wdata(0) = '0' then
        fb0_re_i <= '1'; fb0_ra <= (others=>'0');
      else
        fb1_re_i <= '1'; fb1_ra <= (others=>'0');
      end if;
    elsif mmio_sel='1' then
      if mmio_addr = A_STATUS then
        mmio_rdata(7 downto 0) <= status_v;
      elsif mmio_addr = A_CFG then
        mmio_rdata(5 downto 0) <= cfg_r;
      elsif mmio_addr = A_IRQEN then
        mmio_rdata(7 downto 0) <= irqen_r;
      elsif mmio_addr = A_FB0CNT then
        mmio_rdata(FB_AWID-1 downto 0) <= fb0_count;
      elsif mmio_addr = A_FB1CNT then
        mmio_rdata(FB_AWID-1 downto 0) <= fb1_count;
      elsif mmio_addr = A_FBDATA then
        -- streaming read port: the FB read register already holds the byte
        -- at the stream pointer (prefetched by FBSEL or by the previous
        -- FBDATA read); return it and prefetch pointer+1. The pointer
        -- increments in the clocked process.
        if fb_sel = '0' then
          fb0_re_i <= '1';
          fb0_ra <= std_logic_vector(fb_stream_ptr + 1);
          mmio_rdata(7 downto 0) <= fb0_rdata;
        else
          fb1_re_i <= '1';
          fb1_ra <= std_logic_vector(fb_stream_ptr + 1);
          mmio_rdata(7 downto 0) <= fb1_rdata;
        end if;
      end if;
    end if;
  end process;

  fb0_re    <= fb0_re_i;
  fb0_raddr <= fb0_ra;
  fb1_re    <= fb1_re_i;
  fb1_raddr <= fb1_ra;

  dma_start <= ctrl_start_dma;
  dma_src   <= dma_src_r;
  dma_dst   <= dma_dst_r;
  dma_len   <= dma_len_r;
  st_start  <= ctrl_start_st;

  status_v  <= frame_l & lerr_l & perr_l & fbovf_l & rxovf_l & hdr2_l & dma_done_l & st_done_l;
  irq       <= '1' when (status_v and irqen_r) /= x"00" else '0';
  cfg_src_ext   <= cfg_r(0);
  cfg_nlanes    <= cfg_r(3 downto 1);
  cfg_hw_sync   <= cfg_r(4);
  cfg_multi_pkt <= cfg_r(5);

end architecture;
