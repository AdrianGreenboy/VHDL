-- =============================================================================
--  soc_top_mipi.vhd  -  HERCOSSNUX Core 18 SoC top.
--  RV32 pipeline core + local RAM/DMA subsystem + AXI-Lite control/IMEM slave
--  + MIPI CSI-2 RX peripheral (own AXI4 master to the NoC).
--
--  Based on soc_top_master.vhd. The MIPI peripheral is hung off the core's dmem
--  bus, decoded at 0xD000_0000 (addr[31:28]="1101"). Two AXI4 masters go to the
--  NoC: m_axi (core DMA, DDR<->local) and mipi_m_axi (MIPI framebuffer->DDR).
--
--  Doorbell: the core folds FNV over the framebuffers (via the MIPI dmem window)
--  and writes the DONE_WORD of local RAM -> done_pulse -> irq_out to the PS.
--
--  Licencia: MIT
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity soc_top_mipi is
  generic (
    ADDR_W    : natural := 16;
    DEPTH     : natural := 256;
    IMEM_INIT : string  := "";
    DONE_WORD : natural := 127;
    AXI_AW    : natural := 40
  );
  port (
    aclk    : in std_logic;
    aresetn : in std_logic;

    -- ---- esclavo AXI4-Lite (control + IMEM) ----
    s_axi_awaddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    -- ---- maestro AXI4 del core (DMA local<->DDR) ----
    m_axi_awaddr  : out std_logic_vector(AXI_AW-1 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic;
    m_axi_araddr  : out std_logic_vector(AXI_AW-1 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic;

    -- ---- maestro AXI4 del MIPI (framebuffer -> DDR) ----
    mipi_awaddr  : out std_logic_vector(AXI_AW-1 downto 0);
    mipi_awlen   : out std_logic_vector(7 downto 0);
    mipi_awsize  : out std_logic_vector(2 downto 0);
    mipi_awburst : out std_logic_vector(1 downto 0);
    mipi_awvalid : out std_logic;
    mipi_awready : in  std_logic;
    mipi_wdata   : out std_logic_vector(31 downto 0);
    mipi_wstrb   : out std_logic_vector(3 downto 0);
    mipi_wlast   : out std_logic;
    mipi_wvalid  : out std_logic;
    mipi_wready  : in  std_logic;
    mipi_bresp   : in  std_logic_vector(1 downto 0);
    mipi_bvalid  : in  std_logic;
    mipi_bready  : out std_logic;

    irq_out : out std_logic
  );
end entity soc_top_mipi;

architecture rtl of soc_top_mipi is
  signal cpu_rst        : std_logic;
  signal cpu_hold_reset : std_logic;
  signal axi_owns       : std_logic;
  signal dbg_pc         : word_t;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  -- dmem routed to mem_subsys (everything except the MIPI region)
  signal mem_rdata : word_t;
  signal mem_ready : std_logic;

  -- MIPI dmem window (0xD000_0000)
  signal is_mipi     : std_logic;
  signal mipi_sel    : std_logic;
  signal mipi_we     : std_logic;
  signal mipi_rdata  : std_logic_vector(31 downto 0);

  signal imem_axi_addr, imem_axi_wdata, imem_axi_rdata : word_t;
  signal imem_axi_wstrb : std_logic_vector(3 downto 0);
  signal dmem_axi_addr, dmem_axi_wdata : word_t;
  signal dmem_axi_wstrb : std_logic_vector(3 downto 0);

  signal done_pulse : std_logic;
  signal ddr_base   : std_logic_vector(AXI_AW-1 downto 0);

  signal sync_rst : std_logic;   -- active-high reset for MIPI (from aresetn)
begin

  cpu_rst  <= '1' when (aresetn = '0' or cpu_hold_reset = '1') else '0';
  sync_rst <= '1' when aresetn = '0' else '0';

  -- MIPI region decode: addr[31:28] = "1101" -> 0xD000_0000
  is_mipi  <= '1' when dmem_addr(31 downto 28) = "1101" else '0';
  mipi_sel <= '1' when (is_mipi = '1' and dmem_req = '1') else '0';
  mipi_we  <= '1' when (is_mipi = '1' and dmem_wstrb /= "0000") else '0';

  -- doorbell unchanged from soc_top_master
  done_pulse <= '1' when (dmem_wstrb /= "0000" and dmem_addr(31 downto 30) = "00" and
                 unsigned(dmem_addr(ADDR_W-1 downto 2)) = to_unsigned(DONE_WORD, ADDR_W-2))
                else '0';

  u_cpu : entity work.cpu_pipeline
    port map (
      clk => aclk, rst => cpu_rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dmem_req => dmem_req, dmem_ready => dmem_ready,
      irq_timer => '0', irq_soft => '0', irq_ext => '0',
      dbg_reg_addr => "00000", dbg_reg_data => open, dbg_pc => dbg_pc
    );

  u_imem : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => IMEM_INIT)
    port map (
      clk => aclk,
      cpu_addr => imem_addr, cpu_wdata => ZERO_WORD, cpu_wstrb => "0000",
      cpu_rdata => imem_instr,
      axi_addr => imem_axi_addr, axi_wdata => imem_axi_wdata,
      axi_wstrb => imem_axi_wstrb, axi_rdata => imem_axi_rdata,
      axi_owns => axi_owns
    );

  -- memory subsystem sees the dmem but not the MIPI region (write strobes to
  -- MIPI are masked so local RAM / DMA regs are untouched by MIPI accesses)
  u_mem : entity work.mem_subsys_dma
    generic map (DEPTH => DEPTH, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => aclk, aresetn => aresetn, ddr_base => ddr_base,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => (dmem_wstrb and (3 downto 0 => not is_mipi)),
      dmem_req => dmem_req, dmem_rdata => mem_rdata, dmem_ready => mem_ready,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen, m_axi_awsize => m_axi_awsize,
      m_axi_awburst => m_axi_awburst, m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb, m_axi_wlast => m_axi_wlast,
      m_axi_wvalid => m_axi_wvalid, m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid, m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen, m_axi_arsize => m_axi_arsize,
      m_axi_arburst => m_axi_arburst, m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp, m_axi_rlast => m_axi_rlast,
      m_axi_rvalid => m_axi_rvalid, m_axi_rready => m_axi_rready
    );

  u_mipi : entity work.mipi_soc_top
    generic map (W => 128, H => 96, FB_DEPTH => 18432, FB_AWID => 15, AXI_AW => AXI_AW)
    port map (
      clk => aclk, rst => sync_rst,
      mmio_sel => mipi_sel, mmio_we => mipi_we,
      mmio_addr => dmem_addr(15 downto 0), mmio_wdata => dmem_wdata, mmio_rdata => mipi_rdata,
      m_awaddr => mipi_awaddr, m_awlen => mipi_awlen, m_awsize => mipi_awsize,
      m_awburst => mipi_awburst, m_awvalid => mipi_awvalid, m_awready => mipi_awready,
      m_wdata => mipi_wdata, m_wstrb => mipi_wstrb, m_wlast => mipi_wlast,
      m_wvalid => mipi_wvalid, m_wready => mipi_wready,
      m_bresp => mipi_bresp, m_bvalid => mipi_bvalid, m_bready => mipi_bready
    );

  -- dmem read/ready mux: MIPI region vs memory subsystem
  dmem_rdata <= mipi_rdata when is_mipi = '1' else mem_rdata;
  dmem_ready <= '1'        when is_mipi = '1' else mem_ready;

  u_axil : entity work.axil_soc
    generic map (ADDR_W => ADDR_W)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_axi_awaddr => s_axi_awaddr, s_axi_awvalid => s_axi_awvalid, s_axi_awready => s_axi_awready,
      s_axi_wdata => s_axi_wdata, s_axi_wstrb => s_axi_wstrb, s_axi_wvalid => s_axi_wvalid, s_axi_wready => s_axi_wready,
      s_axi_bresp => s_axi_bresp, s_axi_bvalid => s_axi_bvalid, s_axi_bready => s_axi_bready,
      s_axi_araddr => s_axi_araddr, s_axi_arvalid => s_axi_arvalid, s_axi_arready => s_axi_arready,
      s_axi_rdata => s_axi_rdata, s_axi_rresp => s_axi_rresp, s_axi_rvalid => s_axi_rvalid, s_axi_rready => s_axi_rready,
      cpu_hold_reset => cpu_hold_reset, axi_owns_mem => axi_owns, dbg_pc => dbg_pc,
      imem_axi_addr => imem_axi_addr, imem_axi_wdata => imem_axi_wdata,
      imem_axi_wstrb => imem_axi_wstrb, imem_axi_rdata => imem_axi_rdata,
      dmem_axi_addr => dmem_axi_addr, dmem_axi_wdata => dmem_axi_wdata,
      dmem_axi_wstrb => dmem_axi_wstrb, dmem_axi_rdata => ZERO_WORD,
      done_pulse => done_pulse, irq_out => irq_out,
      ddr_base_o => ddr_base
    );

end architecture rtl;
