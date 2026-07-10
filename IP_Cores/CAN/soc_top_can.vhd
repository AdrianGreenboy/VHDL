-- =============================================================================
--  soc_top_can.vhd  -  SoC v3 del TE0950 + IP CAN (can_mmio)
--  Licencia: MIT
--
--  Es el soc_top_i3c con el subsistema mem_subsys_can y el IP CAN colgado en
--  0xA000_0000 (bits 31:28 = "1010"). Como el I3C, el CAN v1 NO lleva DMA
--  propio: hay UN solo maestro AXI (el dma_burst del SoC). Puertos al PS/NoC:
--    s_axi     (AXI4-Lite esclavo) -> control del core + ventana IMEM
--    m_axi     (AXI4 maestro)      -> dma_burst del SoC hacia la LPDDR4
--    irq_out                       -> doorbell del core (PL-PS IRQ)
--    can_irq_out                   -> IRQ del CAN (PL-PS IRQ opcional)
--
--  Pads CAN (CRUVI LS1, banco 302, LVCMOS33): a diferencia del I3C (dos
--  lineas scl/sda), el CAN usa UN solo par diferencial-logico can_tx/can_rx
--  que en la placa va a un transceptor (p. ej. SN65HVD230). El wrapper
--  expone un unico IOBUF con I/T dinamicos:
--    can_tx_t = '1' libera el pad (LOOP_INT: pads liberados, trafico interno)
--    can_tx_t = '0' conduce can_tx_o (dominante = '0', recesivo = '1')
--  can_rx_i entra del receptor del transceptor (o del pad en modo directo).
--
--  La IRQ del CAN tambien entra al irq_ext del propio core, asi el firmware
--  RV32 puede usar interrupciones en vez de polling si habilita IRQ_EN.
--
--  Adaptacion de interfaz: can_mmio usa sel (req calificado de 1 ciclo) +
--  we (wstrb colapsado); aqui se generan desde can_sel (decode de region del
--  subsistema), dmem_req y dmem_wstrb.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity soc_top_can is
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

    -- ---- maestro AXI4 del dma_burst del SoC ----
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

    irq_out     : out std_logic;
    can_irq_out : out std_logic;

    -- ---- pads CAN (IOBUF con I/T dinamicos en el wrapper) ----
    can_rx_i : in  std_logic;
    can_tx_o : out std_logic;
    can_tx_t : out std_logic
  );
end entity soc_top_can;

architecture rtl of soc_top_can is
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

  -- puerto CAN del subsistema
  signal can_sel   : std_logic;
  signal can_addr  : std_logic_vector(7 downto 0);
  signal can_rdata : word_t;
  signal can_irq   : std_logic;

  -- adaptacion sel/we hacia can_mmio
  signal can_sel_req : std_logic;
  signal can_we      : std_logic;
begin

  cpu_rst <= '1' when (aresetn = '0' or cpu_hold_reset = '1') else '0';

  done_pulse <= '1' when (dmem_wstrb /= "0000" and dmem_addr(31 downto 30) = "00" and
                 unsigned(dmem_addr(ADDR_W-1 downto 2)) = to_unsigned(DONE_WORD, ADDR_W-2))
                else '0';

  can_irq_out <= can_irq;

  can_sel_req <= can_sel and dmem_req;
  can_we      <= '1' when dmem_wstrb /= "0000" else '0';

  u_cpu : entity work.cpu_pipeline
    port map (
      clk => aclk, rst => cpu_rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dmem_req => dmem_req, dmem_ready => dmem_ready,
      irq_timer => '0', irq_soft => '0', irq_ext => can_irq,
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

  u_mem : entity work.mem_subsys_can
    generic map (DEPTH => DEPTH, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => aclk, aresetn => aresetn, ddr_base => ddr_base,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      can_sel => can_sel, can_addr => can_addr, can_rdata => can_rdata,
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

  u_can : entity work.can_mmio
    port map (
      clk => aclk, rst => cpu_rst,
      sel => can_sel_req, we => can_we, addr => can_addr,
      wdata => dmem_wdata, rdata => can_rdata,
      irq => can_irq,
      can_tx_o => can_tx_o, can_tx_t => can_tx_t, can_rx_i => can_rx_i
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
