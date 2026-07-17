-- rf_soc_top_master.vhd - Top del SoC RF para silicio (Paso 7). Variante del
-- soc_top_master de la familia con el dominio RF integrado y DOS maestros AXI4:
--   * m_axi_*  : DMA de la familia (a S06_AXI del NoC)
--   * rf_*     : segundo maestro del RF (a S07_AXI del NoC)
-- Esclavo AXI4-Lite (control + carga de IMEM) en M_AXI_LPD (0x8000_0000/64K).
-- Core cpu_pipeline canonico. Datapath RF + banco en 0x6000_0000 (via
-- mem_subsys_rf). Doorbell del core por DONE_WORD -> irq_out (al PS). El IRQ del
-- RF (nivel de RX FIFO) sale por rf_irq_out (segunda linea al PS).
-- VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity rf_soc_top_master is
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

    -- ---- maestro AXI4 del DMA de la familia (S06_AXI) ----
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

    -- ---- segundo maestro AXI4 del RF (S07_AXI) ----
    rf_axi_awaddr  : out std_logic_vector(AXI_AW-1 downto 0);
    rf_axi_awlen   : out std_logic_vector(7 downto 0);
    rf_axi_awsize  : out std_logic_vector(2 downto 0);
    rf_axi_awburst : out std_logic_vector(1 downto 0);
    rf_axi_awvalid : out std_logic;
    rf_axi_awready : in  std_logic;
    rf_axi_wdata   : out std_logic_vector(31 downto 0);
    rf_axi_wstrb   : out std_logic_vector(3 downto 0);
    rf_axi_wlast   : out std_logic;
    rf_axi_wvalid  : out std_logic;
    rf_axi_wready  : in  std_logic;
    rf_axi_bresp   : in  std_logic_vector(1 downto 0);
    rf_axi_bvalid  : in  std_logic;
    rf_axi_bready  : out std_logic;
    rf_axi_araddr  : out std_logic_vector(AXI_AW-1 downto 0);
    rf_axi_arlen   : out std_logic_vector(7 downto 0);
    rf_axi_arsize  : out std_logic_vector(2 downto 0);
    rf_axi_arburst : out std_logic_vector(1 downto 0);
    rf_axi_arvalid : out std_logic;
    rf_axi_arready : in  std_logic;
    rf_axi_rdata   : in  std_logic_vector(31 downto 0);
    rf_axi_rresp   : in  std_logic_vector(1 downto 0);
    rf_axi_rlast   : in  std_logic;
    rf_axi_rvalid  : in  std_logic;
    rf_axi_rready  : out std_logic;

    irq_out    : out std_logic;    -- doorbell del core
    rf_irq_out : out std_logic     -- IRQ del RF (nivel RX FIFO)
  );
end entity rf_soc_top_master;

architecture rtl of rf_soc_top_master is
  signal cpu_rst        : std_logic;
  signal cpu_hold_reset : std_logic;
  signal axi_owns       : std_logic;
  signal dbg_pc         : word_t;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  signal imem_axi_addr, imem_axi_wdata, imem_axi_rdata : word_t;
  signal imem_axi_wstrb : std_logic_vector(3 downto 0);
  signal dmem_axi_addr, dmem_axi_wdata : word_t;
  signal dmem_axi_wstrb : std_logic_vector(3 downto 0);

  signal done_pulse : std_logic;
  signal ddr_base   : std_logic_vector(AXI_AW-1 downto 0);
begin

  cpu_rst <= '1' when (aresetn = '0' or cpu_hold_reset = '1') else '0';

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

  u_mem : entity work.mem_subsys_rf
    generic map (DEPTH => DEPTH, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => aclk, aresetn => aresetn, ddr_base => ddr_base,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      rf_irq_o => rf_irq_out,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen, m_axi_awsize => m_axi_awsize,
      m_axi_awburst => m_axi_awburst, m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb, m_axi_wlast => m_axi_wlast,
      m_axi_wvalid => m_axi_wvalid, m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid, m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen, m_axi_arsize => m_axi_arsize,
      m_axi_arburst => m_axi_arburst, m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp, m_axi_rlast => m_axi_rlast,
      m_axi_rvalid => m_axi_rvalid, m_axi_rready => m_axi_rready,
      rf_awaddr => rf_axi_awaddr, rf_awlen => rf_axi_awlen, rf_awsize => rf_axi_awsize,
      rf_awburst => rf_axi_awburst, rf_awvalid => rf_axi_awvalid, rf_awready => rf_axi_awready,
      rf_wdata => rf_axi_wdata, rf_wstrb => rf_axi_wstrb, rf_wlast => rf_axi_wlast,
      rf_wvalid => rf_axi_wvalid, rf_wready => rf_axi_wready,
      rf_bresp => rf_axi_bresp, rf_bvalid => rf_axi_bvalid, rf_bready => rf_axi_bready,
      rf_araddr => rf_axi_araddr, rf_arlen => rf_axi_arlen, rf_arsize => rf_axi_arsize,
      rf_arburst => rf_axi_arburst, rf_arvalid => rf_axi_arvalid, rf_arready => rf_axi_arready,
      rf_rdata => rf_axi_rdata, rf_rresp => rf_axi_rresp, rf_rlast => rf_axi_rlast,
      rf_rvalid => rf_axi_rvalid, rf_rready => rf_axi_rready
    );

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
