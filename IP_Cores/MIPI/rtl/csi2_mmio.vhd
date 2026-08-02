-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- L5 (silicon): MMIO peripheral wrapper for the RV32IM soft core.
-- Address decode: addr[31:28]="1101" -> 0xD0000000 aperture.
--
-- Register map (word addresses within the aperture):
--   0x000 CTRL   W  bit0 start_selftest, bit1 start_dma
--   0x004 STATUS R  bit0 selftest_done, bit1 dma_done, bit2 hdr_2bit
--   0x008 FB0_COUNT R
--   0x00C FB1_COUNT R
--   0x010 DMA_SRC  W  bit0 selects FB (0=FB0,1=FB1); byte offset in bits[31:1]
--   0x014 DMA_DST  W  DDR destination address
--   0x018 DMA_LEN  W  byte count
--   0x1000.. FB0 read window (packed bytes, one byte per word, zero-extended)
--   0x2000.. FB1 read window
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
    hdr_2bit   : in  std_logic
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
      else
        -- latch sticky status
        if dma_done='1' then dma_done_l <= '1'; end if;
        if st_done='1'  then st_done_l  <= '1'; end if;
        if hdr_2bit='1'  then hdr2_l     <= '1'; end if;

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
    if mmio_sel='1' then
      if mmio_addr = A_STATUS then
        mmio_rdata <= (0=>st_done_l, 1=>dma_done_l, 2=>hdr2_l, others=>'0');
      elsif mmio_addr = A_FB0CNT then
        mmio_rdata(FB_AWID-1 downto 0) <= fb0_count;
      elsif mmio_addr = A_FB1CNT then
        mmio_rdata(FB_AWID-1 downto 0) <= fb1_count;
      elsif mmio_addr = A_FBDATA then
        -- streaming read port: returns byte at current stream pointer of the
        -- selected FB. Auto-increment happens in the clocked process on read.
        if fb_sel = '0' then
          fb0_re_i <= '1';
          fb0_ra <= std_logic_vector(fb_stream_ptr);
          mmio_rdata(7 downto 0) <= fb0_rdata;
        else
          fb1_re_i <= '1';
          fb1_ra <= std_logic_vector(fb_stream_ptr);
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

end architecture;
