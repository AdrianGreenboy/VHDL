-- =============================================================================
--  soc_top_pcs.vhd  -  HERCOSSNUX Core 19 SoC top.
--  RV32 pipeline core + local RAM/DMA subsystem + AXI-Lite control/IMEM slave
--  + PCS 64B/66B @ 25G peripheral (pcs_stats_top via puente MMIO->AXI-Lite).
--
--  Based on soc_top_mipi.vhd (Core 18). El PCS cuelga del bus dmem del core,
--  decodificado en 0xD000_0000 (addr[31:28]="1101"), a traves de
--  pcs_mmio_bridge (el banco del PCS es AXI4-Lite; el dmem es MMIO simple con
--  estancamiento del CPU via dmem_ready durante la transaccion AXI).
--
--  A diferencia del Core 18, el PCS no tiene maestro AXI propio: un solo
--  maestro va al NoC (m_axi, DMA del core DDR<->local). Doorbell identico:
--  el firmware acumula resultados en RAM local, DMA a DDR, y escribe el
--  DONE_WORD -> done_pulse -> irq_out al PS.
--
--  Dominios de reloj: aclk (AXI/CPU/banco PCS) y clk_dp (data plane del PCS,
--  390.625 MHz del clocking wizard). rst_dp se genera aqui: sincronizacion
--  2FF de (aresetn AND dp_locked) a clk_dp, con ASYNC_REG.
--
--  Licencia: MIT
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity soc_top_pcs is
  generic (
    ADDR_W    : natural := 16;
    DEPTH     : natural := 256;
    IMEM_INIT : string  := "";
    DONE_WORD : natural := 127;
    AXI_AW    : natural := 40
  );
  port (
    aclk      : in std_logic;
    aresetn   : in std_logic;
    clk_dp    : in std_logic;
    dp_locked : in std_logic;

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

    irq_out : out std_logic
  );
end entity soc_top_pcs;

architecture rtl of soc_top_pcs is
  signal cpu_rst        : std_logic;
  signal cpu_hold_reset : std_logic;
  signal axi_owns       : std_logic;
  signal dbg_pc         : word_t;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  signal mem_rdata : word_t;
  signal mem_ready : std_logic;

  -- ventana dmem del PCS (0xD000_0000)
  signal is_pcs     : std_logic;
  signal pcs_sel    : std_logic;
  signal pcs_rdata  : std_logic_vector(31 downto 0);
  signal pcs_ready  : std_logic;

  signal imem_axi_addr, imem_axi_wdata, imem_axi_rdata : word_t;
  signal imem_axi_wstrb : std_logic_vector(3 downto 0);
  signal dmem_axi_addr, dmem_axi_wdata : word_t;
  signal dmem_axi_wstrb : std_logic_vector(3 downto 0);

  signal done_pulse : std_logic;
  signal ddr_base   : std_logic_vector(AXI_AW-1 downto 0);

  -- reset del dominio dp: dos sincronizadores 2FF separados (ASYNC_REG)
  signal rstn_meta, rstn_sync     : std_logic := '0';
  signal locked_meta, locked_sync : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of rstn_meta, rstn_sync     : signal is "TRUE";
  attribute ASYNC_REG of locked_meta, locked_sync : signal is "TRUE";
  signal rst_dp : std_logic;

  -- puente MMIO <-> AXI-Lite del PCS
  signal p_awaddr, p_araddr : std_logic_vector(7 downto 0);
  signal p_awvalid, p_awready, p_wvalid, p_wready : std_logic;
  signal p_bvalid, p_bready, p_arvalid, p_arready : std_logic;
  signal p_rvalid, p_rready : std_logic;
  signal p_wdata, p_rdata : std_logic_vector(31 downto 0);
  signal p_wstrb : std_logic_vector(3 downto 0);
  signal p_bresp, p_rresp : std_logic_vector(1 downto 0);
begin

  cpu_rst  <= '1' when (aresetn = '0' or cpu_hold_reset = '1') else '0';

  -- reset del dominio dp: aresetn y dp_locked se sincronizan POR SEPARADO
  -- (2FF ASYNC_REG cada uno, sin logica combinacional antes del primer FF ->
  -- CDC-10 limpio) y se combinan DESPUES en el dominio destino.
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      rstn_meta   <= aresetn;
      rstn_sync   <= rstn_meta;
      locked_meta <= dp_locked;
      locked_sync <= locked_meta;
    end if;
  end process;
  rst_dp <= not (rstn_sync and locked_sync);

  -- decodificacion de la region PCS: addr[31:28] = "1101" -> 0xD000_0000
  is_pcs  <= '1' when dmem_addr(31 downto 28) = "1101" else '0';
  pcs_sel <= '1' when (is_pcs = '1' and dmem_req = '1') else '0';

  -- doorbell sin cambios respecto a soc_top_master
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

  -- el subsistema de memoria ve el dmem pero no la region PCS (strobes a la
  -- region PCS enmascarados para no tocar RAM local / registros DMA)
  u_mem : entity work.mem_subsys_dma
    generic map (DEPTH => DEPTH, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => aclk, aresetn => aresetn, ddr_base => ddr_base,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => (dmem_wstrb and (3 downto 0 => not is_pcs)),
      dmem_req => dmem_req, dmem_rdata => mem_rdata, dmem_ready => mem_ready,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen, m_axi_awsize => m_axi_awsize,
      m_axi_awburst => m_axi_awburst, m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb, m_axi_wlast => m_axi_wlast,
      m_axi_wvalid => m_axi_wvalid, m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid, m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen, m_axi_arsize => m_axi_arsize,
      m_axi_arburst => m_axi_arburst, m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp, m_axi_rlast => m_axi_rlast,
      m_axi_rvalid => m_axi_rvalid, m_axi_rready => m_axi_rready,
      -- maestro AXI-Lite del PTP integrado: sin uso en este SoC (el firmware
      -- del PCS no toca esa ventana; nunca se emite transaccion) -> inerte
      p_awaddr => open, p_awvalid => open, p_awready => '0',
      p_wdata => open, p_wstrb => open, p_wvalid => open, p_wready => '0',
      p_bresp => "00", p_bvalid => '0', p_bready => open,
      p_araddr => open, p_arvalid => open, p_arready => '0',
      p_rdata => (others => '0'), p_rresp => "00", p_rvalid => '0', p_rready => open
    );

  -- puente MMIO -> AXI-Lite (dominio aclk); el CPU se estanca via dmem_ready
  u_bridge : entity work.pcs_mmio_bridge
    port map (
      clk => aclk, aresetn => aresetn,
      sel => pcs_sel, wstrb => dmem_wstrb, addr => dmem_addr(7 downto 0),
      wdata => dmem_wdata, rdata => pcs_rdata, ready => pcs_ready,
      m_awaddr => p_awaddr, m_awvalid => p_awvalid, m_awready => p_awready,
      m_wdata => p_wdata, m_wstrb => p_wstrb, m_wvalid => p_wvalid, m_wready => p_wready,
      m_bresp => p_bresp, m_bvalid => p_bvalid, m_bready => p_bready,
      m_araddr => p_araddr, m_arvalid => p_arvalid, m_arready => p_arready,
      m_rdata => p_rdata, m_rresp => p_rresp, m_rvalid => p_rvalid, m_rready => p_rready
    );

  -- el PCS: banco AXI en aclk, data plane en clk_dp. irq propio sin rutear
  -- (el firmware sondea registros). DMA glue del banco sin uso en el SoC
  -- (el DMA de resultados es el de mem_subsys, dirigido por el firmware).
  u_pcs : entity work.pcs_stats_top
    port map (
      s_axi_aclk => aclk, s_axi_aresetn => aresetn,
      s_axi_awaddr => p_awaddr, s_axi_awvalid => p_awvalid, s_axi_awready => p_awready,
      s_axi_wdata => p_wdata, s_axi_wstrb => p_wstrb, s_axi_wvalid => p_wvalid,
      s_axi_wready => p_wready, s_axi_bresp => p_bresp, s_axi_bvalid => p_bvalid,
      s_axi_bready => p_bready, s_axi_araddr => p_araddr, s_axi_arvalid => p_arvalid,
      s_axi_arready => p_arready, s_axi_rdata => p_rdata, s_axi_rresp => p_rresp,
      s_axi_rvalid => p_rvalid, s_axi_rready => p_rready,
      irq_out => open,
      clk_dp => clk_dp, rst_dp => rst_dp,
      dma_addr => open, dma_doorbell => open,
      dma_busy => '0', dma_done_pulse => '0'
    );

  -- mux de lectura/ready del dmem: region PCS (multi-ciclo) vs subsistema
  dmem_rdata <= pcs_rdata when is_pcs = '1' else mem_rdata;
  dmem_ready <= pcs_ready when is_pcs = '1' else mem_ready;

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
