
`timescale 1ns/1ps

module pspmc_v1_4_7_pspmc #(
  parameter C_SUBCORE_NAME = "gt_quad_base",
  parameter C_VIP_SUBCORE_NAME = "versal_cips_ps_vip",
  parameter C_PS_USE_STARTUP = 0,
  parameter C_PS_USE_CAPTURE = 0,
  parameter C_PS_USE_RPU_INTERRUPT = 1'b0,
  parameter C_CORE_NAME = "pspmc_0",
  parameter C_SIM_DEVICE = "VERSAL_AI_CORE",
  parameter C_SD0_DATA_WIDTH = 8,
  parameter C_SD1_DATA_WIDTH = 8,
  parameter C_M_AXI_GP0_DATA_WIDTH = 128,
  parameter C_M_AXI_GP2_DATA_WIDTH = 128,
  parameter C_S_AXI_GP0_DATA_WIDTH = 128,
  parameter C_S_AXI_GP2_DATA_WIDTH = 128,
  parameter C_S_AXI_GP4_DATA_WIDTH = 128,
  parameter C_S_AXI_ACP_DATA_WIDTH = 128,
  parameter C_S_AXI_ACE_DATA_WIDTH = 128,
  parameter C_PS_NOC_CCI_DATA_WIDTH = 128,
  parameter C_PS_NOC_NCI_DATA_WIDTH = 128,
  parameter C_NOC_PS_CCI_DATA_WIDTH = 128,
  parameter C_PS_NOC_PCI_DATA_WIDTH = 128,
  parameter C_NOC_PS_PCI_DATA_WIDTH = 128,
  parameter C_PS_NOC_PMC_DATA_WIDTH = 128,
  parameter C_NOC_PS_PMC_DATA_WIDTH = 128,
  parameter C_PS_NOC_RPU_DATA_WIDTH = 128,
  parameter C_DIFF_RW_CLK_S_AXI_GP0 = 0,
  parameter C_DIFF_RW_CLK_S_AXI_GP2 = 0,
  parameter C_DIFF_RW_CLK_S_AXI_GP4 = 0,
  parameter C_PL_SEM_GPO_ENABLE = 0,
  parameter C_PMC_GPO_WIDTH = 32,
  parameter C_PMC_GPI_WIDTH = 32,
  parameter C_LPD_GPIO_EMIO_ENABLE = 0,
  parameter C_PMC_GPIO_EMIO_ENABLE = 0,
  parameter C_PMC_I2CPMC_PERIPHERAL = 0,
  parameter C_PS_I2C0_PERIPHERAL_ENABLE = 0,
  parameter C_PS_I2C1_PERIPHERAL_ENABLE = 0,
  parameter C_PS_EMIO_GPIO_WIDTH = 32,
  parameter C_PMC_EMIO_GPIO_WIDTH = 64,
  parameter C_PMC_NOC_ADDR_WIDTH = 64,
  parameter C_PMC_NOC_DATA_WIDTH = 128,
  parameter C_NOC_PMC_ADDR_WIDTH = 64,
  parameter C_NOC_PMC_DATA_WIDTH = 128,
  parameter C_NUM_F2P0_INTR_INPUTS = 1,
  parameter C_NUM_F2P1_INTR_INPUTS = 1,
  parameter C_ACE_LITE = 0,
  parameter C_PS_USE_S_AXI_GP2 = 0,
  parameter C_AXI4_EXT_USER_BITS = 0,
  parameter C_CPM_USE_MODES = 0,
  parameter C_CPM_PCIE0_MODES = "PCIE",
  parameter C_CPM_PCIE1_MODES = "PCIE",
  parameter C_CPM_PCIE1_LINK_SPEED_FOR_POWER = "GEN1",
  parameter C_CPM_PCIE0_LINK_SPEED_FOR_POWER = "GEN1",
  parameter C_CPM_PCIE1_MODE_FOR_POWER = "NONE",
  parameter C_CPM_PCIE0_MODE_FOR_POWER = "NONE",
  parameter C_CPM_PCIE_CHANNELS_FOR_POWER = 0,
  parameter C_CPM_PCIE1_LINK_WIDTH_FOR_POWER = 0,
  parameter C_CPM_PCIE0_LINK_WIDTH_FOR_POWER = 0,
  parameter C_PS_TRACE_WIDTH = 32,
  parameter C_PS_TRACE_PERIPHERAL = 0,

  parameter C_CPM_PCIE0_USER_CLK_FREQ = "250_MHz",
  parameter C_CPM_PCIE1_USER_CLK_FREQ = "500_MHz",
  parameter C_CPM_PCIE0_AXISTEN_IF_WIDTH = 512,
  parameter C_CPM_PCIE1_AXISTEN_IF_WIDTH = 256,
  parameter C_CPM_PCIE0_PF0_MSI_ENABLED = 0,
  parameter C_CPM_PCIE1_PF0_MSI_ENABLED = 0,
  parameter C_CPM_PCIE0_TL_PF_ENABLE_REG = 0,
  parameter C_CPM_PCIE0_PF0_SRIOV_CAP_TOTAL_VF = 0,
  parameter C_CPM_PCIE0_PF1_SRIOV_CAP_TOTAL_VF = 0,
  parameter C_CPM_PCIE0_PF2_SRIOV_CAP_TOTAL_VF = 0,
  parameter C_CPM_PCIE0_PF3_SRIOV_CAP_TOTAL_VF = 0,
  parameter C_CPM_PCIE0_PF0_SRIOV_FIRST_VF_OFFSET = 4,
  parameter C_CPM_PCIE0_PF1_SRIOV_FIRST_VF_OFFSET = 4,
  parameter C_CPM_PCIE0_PF2_SRIOV_FIRST_VF_OFFSET = 4,
  parameter C_CPM_PCIE0_PF3_SRIOV_FIRST_VF_OFFSET = 4,
  parameter C_CPM_PCIE0_SRIOV_CAP_ENABLE = 0,
  parameter C_CPM_PCIE1_SRIOV_CAP_ENABLE = 0,
  parameter C_CPM_PCIE0_ARI_CAP_ENABLE = 0,
  parameter C_CPM_PCIE1_ARI_CAP_ENABLE = 0,
  parameter C_CPM_PCIE0_PF0_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE0_PF1_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE0_PF2_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE0_PF3_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE0_PF0_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE0_PF1_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE0_PF2_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE0_PF3_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE0_VFG0_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE0_VFG1_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE0_VFG2_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE0_VFG3_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE0_VFG0_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE0_VFG1_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE0_VFG2_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE0_VFG3_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE0_PF0_PASID_CAP_ON = 0,
  parameter C_CPM_PCIE0_PL_UPSTREAM_FACING = 1,
  parameter C_CPM_PCIE0_NUM_USR_IRQ = 1,
  parameter C_CPM_PCIE1_TL_PF_ENABLE_REG = 0,
  parameter C_CPM_PCIE1_PF0_SRIOV_CAP_TOTAL_VF = 0,
  parameter C_CPM_PCIE1_PF1_SRIOV_CAP_TOTAL_VF = 0,
  parameter C_CPM_PCIE1_PF2_SRIOV_CAP_TOTAL_VF = 0,
  parameter C_CPM_PCIE1_PF3_SRIOV_CAP_TOTAL_VF = 0,
  parameter C_CPM_PCIE1_PF0_SRIOV_FIRST_VF_OFFSET = 4,
  parameter C_CPM_PCIE1_PF1_SRIOV_FIRST_VF_OFFSET = 4,
  parameter C_CPM_PCIE1_PF2_SRIOV_FIRST_VF_OFFSET = 4,
  parameter C_CPM_PCIE1_PF3_SRIOV_FIRST_VF_OFFSET = 4,

  parameter C_CPM_PCIE1_PF0_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE1_PF1_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE1_PF2_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE1_PF3_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE1_PF0_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE1_PF1_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE1_PF2_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE1_PF3_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE1_VFG0_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE1_VFG1_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE1_VFG2_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE1_VFG3_ATS_CAP_ON = 0,
  parameter C_CPM_PCIE1_PF0_PASID_CAP_ON = 0,
  parameter C_CPM_PCIE1_VFG0_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE1_VFG1_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE1_VFG2_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE1_VFG3_PRI_CAP_ON = 0,
  parameter C_CPM_PCIE1_PL_UPSTREAM_FACING = 1,

  parameter C_CPM_PCIE0_FUNCTIONAL_MODE = "DMA",
  parameter C_XDEVICE = "everest1",
  parameter C_SPP_PSPMC_TO_CORE_WIDTH = 20000,
  parameter C_SPP_PSPMC_FROM_CORE_WIDTH = 20000,

  parameter C_CPM_PERIPHERAL_EN = 0,
  parameter C_CPM_PCIE0_CONTROLLER_ENABLE = 0,
  parameter C_CPM_PCIE1_CONTROLLER_ENABLE = 0,
  parameter C_PS_ENABLE_HSDP = 0,
  parameter C_PS_HSDP_MODE = "NONE",

  parameter C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH = 8,
  parameter C_CPM_PCIE1_PL_LINK_CAP_MAX_LINK_WIDTH = 8,
  
  parameter [31:0] C_XPIPE_0_CLKDLY_CFG = 32'h00000000,
  parameter [31:0] C_XPIPE_0_CLK_CFG = 32'h00000000,
  parameter [0:0]  C_XPIPE_0_INSTANTIATED = 1'b1,
  parameter        C_XPIPE_0_LINK0_CFG = "DISABLE",
  parameter        C_XPIPE_0_LINK1_CFG = "DISABLE",
  parameter        C_XPIPE_0_LOC = "QUAD0",
  parameter [1:0]  C_XPIPE_0_MODE = 2'b00,
  parameter [15:0] C_XPIPE_0_REG_CFG = 16'h0000,
  parameter [31:0] C_XPIPE_0_RSVD = 32'h00000000,
  parameter [31:0] C_XPIPE_1_CLKDLY_CFG = 32'h00000000,
  parameter [31:0] C_XPIPE_1_CLK_CFG = 32'h00000000,
  parameter [0:0]  C_XPIPE_1_INSTANTIATED = 1'b1,
  parameter        C_XPIPE_1_LINK0_CFG = "DISABLE",
  parameter        C_XPIPE_1_LINK1_CFG = "DISABLE",
  parameter        C_XPIPE_1_LOC = "QUAD0",
  parameter [1:0]  C_XPIPE_1_MODE = 2'b00,
  parameter [15:0] C_XPIPE_1_REG_CFG = 16'h0000,
  parameter [31:0] C_XPIPE_1_RSVD = 32'h00000000,

  parameter [31:0] C_XPIPE_2_CLKDLY_CFG = 32'h00000000,
  parameter [31:0] C_XPIPE_2_CLK_CFG = 32'h00000000,
  parameter [0:0]  C_XPIPE_2_INSTANTIATED = 1'b1,
  parameter        C_XPIPE_2_LINK0_CFG = "DISABLE",
  parameter        C_XPIPE_2_LINK1_CFG = "DISABLE",
  parameter        C_XPIPE_2_LOC = "QUAD0",
  parameter [1:0]  C_XPIPE_2_MODE = 2'b00,
  parameter [15:0] C_XPIPE_2_REG_CFG = 16'h0000,
  parameter [31:0] C_XPIPE_2_RSVD = 32'h00000000,

  parameter [31:0] C_XPIPE_3_CLKDLY_CFG = 32'h00000000,
  parameter [31:0] C_XPIPE_3_CLK_CFG = 32'h00000000,
  parameter [0:0]  C_XPIPE_3_INSTANTIATED = 1'b1,
  parameter        C_XPIPE_3_LINK0_CFG = "DISABLE",
  parameter        C_XPIPE_3_LINK1_CFG = "DISABLE",
  parameter        C_XPIPE_3_LOC = "QUAD0",
  parameter [1:0]  C_XPIPE_3_MODE = 2'b00,
  parameter [15:0] C_XPIPE_3_REG_CFG = 16'h0000,
  parameter [31:0] C_XPIPE_3_RSVD = 32'h00000000,
  parameter        C_PMCPL_IRO_CLK_BUF = "true",
  parameter        C_PMCPL_CLK0_BUF = "true",
  parameter        C_PMCPL_CLK1_BUF = "true",
  parameter        C_PMCPL_CLK2_BUF = "true",
  parameter        C_PMCPL_CLK3_BUF = "true",
  parameter C_PS_PCIE_EP_RESET1_IO = "{PS_MIO 18}",
  parameter C_PS_PCIE_EP_RESET2_IO = "{PS_MIO 19}",
  parameter C_PS_TIE_MJTAG_TCK_TO_GND = 1,

  parameter C_SLR1_PS_USE_CAPTURE = 1'b0,
  parameter C_SLR2_PS_USE_CAPTURE = 1'b0,
  parameter C_SLR3_PS_USE_CAPTURE = 1'b0,

  parameter C_PMC_USE_PL_ERR0 = 0,
  parameter C_PMC_USE_PL_ERR1 = 0,
  parameter C_PMC_USE_PL_ERR2 = 0,
  parameter C_PMC_USE_PL_ERR3 = 0,
  parameter C_PS_PMU_PERIPHERAL_ENABLE = 0,
  parameter C_GEM_TSU_ENABLE = 1,
  parameter [1:0] C_GEM0_TSU_INC_CTRL = 2'b11

  
//#
)
(
//  output mio_pl_18,
//  output mio_pl_19,
//  output mio_pl_24,
//  output mio_pl_25,
//  output mio_pl_38,
//  output mio_pl_39,

  output pl_pcie0_resetn,
  output pl_pcie1_resetn,

  output lpd_dma0_cack,
  output lpd_dma1_cack,
  output lpd_dma2_cack,
  output lpd_dma3_cack,
  output lpd_dma4_cack,
  output lpd_dma5_cack,
  output lpd_dma6_cack,
  output lpd_dma7_cack,

  output lpd_dma0_tvld,
  output lpd_dma1_tvld,
  output lpd_dma2_tvld,
  output lpd_dma3_tvld,
  output lpd_dma4_tvld,
  output lpd_dma5_tvld,
  output lpd_dma6_tvld,
  output lpd_dma7_tvld,

//output dp_audio_ref_clk,
//output dp_video_ref_clk,
  output  canfd0_phy_tx,
  output  canfd1_phy_tx,
  output [1:0] gem0_dma_bus_width,
  output  gem0_fifo_dma_tx_end_tog,
  output [93:0] gem0_tsu_timer_cnt,
  output [7:0] gem0_gmii_tx_d,
  output  gem0_gmii_tx_en,
  output  gem0_gmii_tx_err,
  output  gem0_mdio_mdc,
  output  gem0_mdio_o,
  output  gem0_mdio_t_n,
  output [7:0] gem0_fifo_rx_w_data,
  output  gem0_fifo_rx_w_eop,
  output  gem0_fifo_rx_w_err,
  output  gem0_fifo_rx_w_flush,
  output  gem0_fifo_rx_w_sop,
  output [44:0] gem0_fifo_rx_w_status,
  output  gem0_fifo_rx_w_wr,
  output [3:0] emio_enet0_speed_mode,
  output [1:0]gem0_fifo_tx_r_rd,
  output [3:0] gem0_fifo_tx_r_status,
  output [1:0] emio_enet1_dma_bus_width,
  output  gem1_fifo_dma_tx_end_tog,
  output [7:0] gem1_gmii_tx_d,
  output  gem1_gmii_tx_en,
  output  gem1_gmii_tx_err,
  output  gem1_mdio_mdc,
  output  gem1_mdio_o,
  output  gem1_mdio_t_n,
  output [7:0] gem1_fifo_rx_w_data,
  output  gem1_fifo_rx_w_eop,
  output  gem1_fifo_rx_w_err,
  output  gem1_fifo_rx_w_flush,
  output  gem1_fifo_rx_w_sop,
  output [44:0] gem1_fifo_rx_w_status,
  output  gem1_fifo_rx_w_wr,
  output [3:0] emio_enet1_speed_mode,
  output [1:0] gem1_fifo_tx_r_rd,
  output [3:0] gem1_fifo_tx_r_status,
  output  gem0_ptp_delay_req_rx,
  output  gem0_ptp_delay_req_tx,
  output  gem0_ptp_pdelay_req_rx,
  output  gem0_ptp_pdelay_req_tx,
  output  gem0_ptp_pdelay_resp_rx,
  output  gem0_ptp_pdelay_resp_tx,
  output  gem0_ptp_rx_sof,
  output  gem0_ptp_sync_frame_rx,
  output  gem0_ptp_sync_frame_tx,
  output  gem0_tsu_timer_cmp_val,
  output  emio_gem0_tx_r_fixed_lat,
  output  gem0_ptp_tx_sof,
  output  gem1_ptp_delay_req_rx,
  output  gem1_ptp_delay_req_tx,
  output  gem1_ptp_pdelay_req_rx,
  output  gem1_ptp_pdelay_req_tx,
  output  gem1_ptp_pdelay_resp_rx,
  output  gem1_ptp_pdelay_resp_tx,
  output  gem1_ptp_rx_sof,
  output  gem1_ptp_sync_frame_rx,
  output  gem1_ptp_sync_frame_tx,
  output  gem1_tsu_timer_cmp_val,
  output  emio_gem1_tx_r_fixed_lat,
  output  gem1_ptp_tx_sof,
  output  i2c0_scl_o,
  output  i2c0_scl_t,
  output  i2c0_scl_tn,
  output  i2c0_sda_o,
  output  i2c0_sda_t,
  output  i2c0_sda_tn,
  output  i2c1_scl_o,
  output  i2c1_scl_t,
  output  i2c1_scl_tn,
  output  i2c1_sda_o,
  output  i2c1_sda_t,
  output  i2c1_sda_tn,
  output  pmc_i2c_scl_oen,
  output  pmc_i2c_sc1_oen_tn,
  output  pmc_i2c_scl_out,
  output  pmc_i2c_sda_oen,
  output  pmc_i2c_sda_oen_tn,
  output  pmc_i2c_sda_out,

  input   pmc_i2c_scl_in,
  input   pmc_i2c_sda_in,
  output  spi0_m_o,
  output  spi0_m_o_t_n,
  output  spi0_sclk_o,
  output  spi0_sclk_t_n,
  output  spi0_s_o,
  output  spi0_ss_n_t_n,
  output  spi0_ss_o_n,
  output  spi0_ss1_o_n,
  output  spi0_ss2_o_n,
  output  spi0_s_t_n,
  output  spi1_m_o,
  output  spi1_m_o_t_n,
  output  spi1_sclk_o,
  output  spi1_sclk_t_n,
  output  spi1_s_o,
  output  spi1_ss_n_t_n,
  output  spi1_ss_o_n,
  output  spi1_ss1_o_n,
  output  spi1_ss2_o_n,
  output  spi1_s_t_n,
  output [2:0] ttc0_waveo,
  output [2:0] ttc1_waveo,
  output [2:0] ttc2_waveo,
  output [2:0] ttc3_waveo,
  output emio_u2dsport_vbus_ctrl_usb3_0,
//output emio_u2dsport_vbus_ctrl_usb3_1,
//output emio_u3dsport_vbus_ctrl_usb3_0,
//output emio_u3dsport_vbus_ctrl_usb3_1,
  output uart0_sir_outn,
  output uart0_dtrn,
  output uart0_out1n,
  output uart0_out2n,
  output uart0_rtsn,
  output uart0_txd,

  input uart0_ctsn,
  input uart0_dcdn,
  input uart0_dsrn,
  input uart0_rin,
  input uart0_rxd,
  input fmio_uart0_sir_in,

  output uart1_sir_outn,
  output uart1_dtrn,
  output uart1_out1n,
  output uart1_out2n,
  output uart1_rtsn,
  output uart1_txd,

  input uart1_ctsn,
  input uart1_dcdn,
  input uart1_dsrn,
  input uart1_rin,
  input uart1_rxd,
  input fmio_uart1_sir_in,

  output emio_wdt0rsto,
  output emio_wdt1rsto,

  output [C_PMC_GPO_WIDTH-1:0] pmc_pl_gpo,
  input  [C_PMC_GPI_WIDTH-1:0] pmc_pl_gpi,

  output [(C_PS_EMIO_GPIO_WIDTH-1):0] lpd_gpio_o,
  output [(C_PS_EMIO_GPIO_WIDTH-1):0] lpd_gpio_t,
  output [(C_PS_EMIO_GPIO_WIDTH-1):0] lpd_gpio_tn,
  input  [(C_PS_EMIO_GPIO_WIDTH-1):0] lpd_gpio_i,

  output [(C_PMC_EMIO_GPIO_WIDTH-1):0] pmc_gpio_oe,
  output [(C_PMC_EMIO_GPIO_WIDTH-1):0] pmc_gpio_oen,
  output [(C_PMC_EMIO_GPIO_WIDTH-1):0] pmc_gpio_out,
  input  [(C_PMC_EMIO_GPIO_WIDTH-1):0] pmc_gpio_in,

  output pl0_sem,
  output pl1_sem,
  output pl2_sem,
  output pl3_sem,

  output      sd0_buspwr,
  output [2:0] sd0_busvolt_sel,
  output      sd0_dll_test_clk0,
  output      sd0_dll_test_clk_rx,
  output      sd0_dll_test_clk_tx,
  output [7:0] sd0_dll_test_out,
  output      sd0_led_ctrl,
  output      sd0_clk,
  output      sd0_cmd_oe,
  output      sd0_cmd_out,
  output [C_SD0_DATA_WIDTH-1:0 ] sd0_data_oe,
  output [C_SD0_DATA_WIDTH-1:0]  sd0_data_out,
  input   [3:0] sd0_dll_test_in,
  input      sd0_cd_n,
  input      sd0_cmd_in,
  input  [C_SD0_DATA_WIDTH-1:0]   sd0_data_in,
  input      sd0_wp,

  output      sd1_bus_pwr,
  output [2:0] sd1_busvolt_sel,
  output      sd1_dll_test_clk0,
  output      sd1_dll_test_clk_rx,
  output      sd1_dll_test_clk_tx,
  output [7:0] sd1_dll_test_out,
  output      sd1_led_ctrl,
  output      sd1_clk,
  output      sd1_cmd_oe,
  output      sd1_cmd_out,
  output [C_SD1_DATA_WIDTH-1:0] sd1_data_oe,
  output [C_SD1_DATA_WIDTH-1:0] sd1_data_out,
  input  [3:0] sd1_dll_test_in,
  input      sd1_cd_n,
  input      sd1_cmd_in,
  input  [C_SD1_DATA_WIDTH-1:0] sd1_data_in,
  input      sd1_wp,
  
  input  [31:0]  ps_ocm2_apb_prdata,
  input          ps_ocm2_apb_pready,
  input          ps_ocm2_apb_pslverr,
  output [31:0]  ps_ocm2_apb_paddr,
  output         ps_ocm2_apb_penable,
  output [2:0]   ps_ocm2_apb_pprot,
  output         ps_ocm2_apb_psel,
  output [3:0]   ps_ocm2_apb_pstrb,
  output [31:0]  ps_ocm2_apb_pwdata,
  output         ps_ocm2_apb_pwrite,
  input          ps_ocm2_axi_arready,
  input          ps_ocm2_axi_awready,
  input  [15:0]  ps_ocm2_axi_bid,
  input  [1:0]   ps_ocm2_axi_bresp,
  input  [0:0]   ps_ocm2_axi_buser,
  input          ps_ocm2_axi_bvalid,
  input  [127:0] ps_ocm2_axi_rdata,
  input  [15:0]  ps_ocm2_axi_rid,
  input  [0:0]   ps_ocm2_axi_rlast,
  input  [1:0]   ps_ocm2_axi_rresp,
  input  [17:0]  ps_ocm2_axi_ruser,
  input          ps_ocm2_axi_rvalid,
  input          ps_ocm2_axi_wready,
  output [63:0]  ps_ocm2_axi_araddr,
  output [1:0]   ps_ocm2_axi_arburst,
  output [3:0]   ps_ocm2_axi_arcache,
  output [15:0]  ps_ocm2_axi_arid,
  output [7:0]   ps_ocm2_axi_arlen,
  output [0:0]   ps_ocm2_axi_arlock,
  output [2:0]   ps_ocm2_axi_arprot,
  output [3:0]   ps_ocm2_axi_arqos,
  output [3:0]   ps_ocm2_axi_arregion,
  output [2:0]   ps_ocm2_axi_arsize,
  output [15:0]  ps_ocm2_axi_aruser,
  output         ps_ocm2_axi_arvalid,
  output [63:0]  ps_ocm2_axi_awaddr,
  output [1:0]   ps_ocm2_axi_awburst,
  output [3:0]   ps_ocm2_axi_awcache,
  output [15:0]  ps_ocm2_axi_awid,
  output [7:0]   ps_ocm2_axi_awlen,
  output [0:0]   ps_ocm2_axi_awlock,
  output [2:0]   ps_ocm2_axi_awprot,
  output [3:0]   ps_ocm2_axi_awqos,
  output [3:0]   ps_ocm2_axi_awregion,
  output [2:0]   ps_ocm2_axi_awsize,
  output [15:0]  ps_ocm2_axi_awuser,
  output         ps_ocm2_axi_awvalid,
  output         ps_ocm2_axi_bready,
  output         ps_ocm2_axi_rready,
  output [127:0] ps_ocm2_axi_wdata,
  output [15:0]  ps_ocm2_axi_wid,
  output [0:0]   ps_ocm2_axi_wlast,
  output [15:0]  ps_ocm2_axi_wstrb,
  output [17:0]  ps_ocm2_axi_wuser,
  output         ps_ocm2_axi_wvalid,
  output         s_axi_xram3_aclk,
  output         lpd_lsbus_clk,
  

  output  noc_fpd_cci_axi0_arready,
  output  noc_fpd_cci_axi0_awready,
  output [1:0] noc_fpd_cci_axi0_bresp,
  output [15:0] noc_fpd_cci_axi0_buser,
  output  noc_fpd_cci_axi0_bvalid,
  output [127:0] noc_fpd_cci_axi0_rdata,
  output  noc_fpd_cci_axi0_rlast,
  output [1:0] noc_fpd_cci_axi0_rresp,
  output [16:0] noc_fpd_cci_axi0_ruser,
  output  noc_fpd_cci_axi0_rvalid,
  output  noc_fpd_cci_axi0_wready,
  output [1:0] noc_fpd_cci_axi0_bid,
  output [1:0] noc_fpd_cci_axi0_rid,
  output  noc_fpd_cci_axi1_arready,
  output  noc_fpd_cci_axi1_awready,
  output [1:0] noc_fpd_cci_axi1_bresp,
  output [15:0] noc_fpd_cci_axi1_buser,
  output  noc_fpd_cci_axi1_bvalid,
  output [127:0] noc_fpd_cci_axi1_rdata,
  output  noc_fpd_cci_axi1_rlast,
  output [1:0] noc_fpd_cci_axi1_rresp,
  output [16:0] noc_fpd_cci_axi1_ruser,
  output  noc_fpd_cci_axi1_rvalid,
  output  noc_fpd_cci_axi1_wready,
  output [1:0] noc_fpd_cci_axi1_bid,
  output [1:0] noc_fpd_cci_axi1_rid,
  output  noc_fpd_axi_axi0_arready,
  output  noc_fpd_axi_axi0_awready,
  output [1:0] noc_fpd_axi_axi0_bid,
  output [1:0] noc_fpd_axi_axi0_bresp,
  output [15:0] noc_fpd_axi_axi0_buser,
  output  noc_fpd_axi_axi0_bvalid,
  output [127:0] noc_fpd_axi_axi0_rdata,
  output [1:0] noc_fpd_axi_axi0_rid,
  output  noc_fpd_axi_axi0_rlast,
  output [1:0] noc_fpd_axi_axi0_rresp,
  output [16:0] noc_fpd_axi_axi0_ruser,
  output  noc_fpd_axi_axi0_rvalid,
  output  noc_fpd_axi_axi0_wready,
  output  noc_fpd_axi_axi1_arready,
  output  noc_fpd_axi_axi1_awready,
  output [1:0] noc_fpd_axi_axi1_bid,
  output [1:0] noc_fpd_axi_axi1_bresp,
  output [15:0] noc_fpd_axi_axi1_buser,
  output  noc_fpd_axi_axi1_bvalid,
  output [127:0] noc_fpd_axi_axi1_rdata,
  output [1:0] noc_fpd_axi_axi1_rid,
  output  noc_fpd_axi_axi1_rlast,
  output [1:0] noc_fpd_axi_axi1_rresp,
  output [16:0] noc_fpd_axi_axi1_ruser,
  output  noc_fpd_axi_axi1_rvalid,
  output  noc_fpd_axi_axi1_wready,
  output  noc_cpm_pcie_axi0_arready,
  output  noc_cpm_pcie_axi0_awready,
  output [1:0] noc_cpm_pcie_axi0_bresp,
  output [15:0] noc_cpm_pcie_axi0_buser,
  output  noc_cpm_pcie_axi0_bvalid,
  output [127:0] noc_cpm_pcie_axi0_rdata,
  output  noc_cpm_pcie_axi0_rlast,
  output [1:0] noc_cpm_pcie_axi0_rresp,
  output [16:0] noc_cpm_pcie_axi0_ruser,
  output  noc_cpm_pcie_axi0_rvalid,
  output  noc_cpm_pcie_axi0_wready,
  output  debug_seu_crcerror,
  output  debug_seu_eccerror,
  output  debug_seu_endofcalib,
  output  debug_seu_halted,
  output  debug_seu_heartbeat,
  output [1:0] noc_cpm_pcie_axi0_bid,
  output [1:0] noc_cpm_pcie_axi0_rid,
  output [63:0] fpd_cci_noc_axi0_araddr,
  output [1:0] fpd_cci_noc_axi0_arburst,
  output [3:0] fpd_cci_noc_axi0_arcache,
  output [15:0] fpd_cci_noc_axi0_arid,
  output [7:0] fpd_cci_noc_axi0_arlen,
  output  fpd_cci_noc_axi0_arlock,
  output [2:0] fpd_cci_noc_axi0_arprot,
  output [3:0] fpd_cci_noc_axi0_arqos,
  output [3:0] if_ps_noc_cci_axi0_arregion,
  output [2:0] fpd_cci_noc_axi0_arsize,
  output [17:0] fpd_cci_noc_axi0_aruser,
  output  fpd_cci_noc_axi0_arvalid,
  output [63:0] fpd_cci_noc_axi0_awaddr,
  output [1:0] fpd_cci_noc_axi0_awburst,
  output [3:0] fpd_cci_noc_axi0_awcache,
  output [15:0] fpd_cci_noc_axi0_awid,
  output [7:0] fpd_cci_noc_axi0_awlen,
  output  fpd_cci_noc_axi0_awlock,
  output [2:0] fpd_cci_noc_axi0_awprot,
  output [3:0] fpd_cci_noc_axi0_awqos,
  output [3:0] if_ps_noc_cci_axi0_awregion,
  output [2:0] fpd_cci_noc_axi0_awsize,
  output [17:0] fpd_cci_noc_axi0_awuser,
  output  fpd_cci_noc_axi0_awvalid,
  output  fpd_cci_noc_axi0_bready,
  output  fpd_cci_noc_axi0_rready,
  output [127:0] fpd_cci_noc_axi0_wdata,
  output [15:0] if_ps_noc_cci_axi0_wid,
  output  fpd_cci_noc_axi0_wlast,
  output [15:0] fpd_cci_noc_axi0_wstrb,
  output [16:0] fpd_cci_noc_axi0_wuser,
  output  fpd_cci_noc_axi0_wvalid,
  output [63:0] fpd_cci_noc_axi1_araddr,
  output [1:0] fpd_cci_noc_axi1_arburst,
  output [3:0] fpd_cci_noc_axi1_arcache,
  output [15:0] fpd_cci_noc_axi1_arid,
  output [7:0] fpd_cci_noc_axi1_arlen,
  output  fpd_cci_noc_axi1_arlock,
  output [2:0] fpd_cci_noc_axi1_arprot,
  output [3:0] fpd_cci_noc_axi1_arqos,
  output [3:0] if_ps_noc_cci_axi1_arregion,
  output [2:0] fpd_cci_noc_axi1_arsize,
  output [17:0] fpd_cci_noc_axi1_aruser,
  output  fpd_cci_noc_axi1_arvalid,
  output [63:0] fpd_cci_noc_axi1_awaddr,
  output [1:0] fpd_cci_noc_axi1_awburst,
  output [3:0] fpd_cci_noc_axi1_awcache,
  output [15:0] fpd_cci_noc_axi1_awid,
  output [7:0] fpd_cci_noc_axi1_awlen,
  output  fpd_cci_noc_axi1_awlock,
  output [2:0] fpd_cci_noc_axi1_awprot,
  output [3:0] fpd_cci_noc_axi1_awqos,
  output [3:0] if_ps_noc_cci_axi1_awregion,
  output [2:0] fpd_cci_noc_axi1_awsize,
  output [17:0] fpd_cci_noc_axi1_awuser,
  output  fpd_cci_noc_axi1_awvalid,
  output  fpd_cci_noc_axi1_bready,
  output  fpd_cci_noc_axi1_rready,
  output [127:0] fpd_cci_noc_axi1_wdata,
  output [15:0] if_ps_noc_cci_axi1_wid,
  output  fpd_cci_noc_axi1_wlast,
  output [15:0] fpd_cci_noc_axi1_wstrb,
  output [16:0] fpd_cci_noc_axi1_wuser,
  output  fpd_cci_noc_axi1_wvalid,
  output [63:0] fpd_cci_noc_axi2_araddr,
  output [1:0] fpd_cci_noc_axi2_arburst,
  output [3:0] fpd_cci_noc_axi2_arcache,
  output [15:0] fpd_cci_noc_axi2_arid,
  output [7:0] fpd_cci_noc_axi2_arlen,
  output  fpd_cci_noc_axi2_arlock,
  output [2:0] fpd_cci_noc_axi2_arprot,
  output [3:0] fpd_cci_noc_axi2_arqos,
  output [3:0] if_ps_noc_cci_axi2_arregion,
  output [2:0] fpd_cci_noc_axi2_arsize,
  output [17:0] fpd_cci_noc_axi2_aruser,
  output  fpd_cci_noc_axi2_arvalid,
  output [63:0] fpd_cci_noc_axi2_awaddr,
  output [1:0] fpd_cci_noc_axi2_awburst,
  output [3:0] fpd_cci_noc_axi2_awcache,
  output [15:0] fpd_cci_noc_axi2_awid,
  output [7:0] fpd_cci_noc_axi2_awlen,
  output  fpd_cci_noc_axi2_awlock,
  output [2:0] fpd_cci_noc_axi2_awprot,
  output [3:0] fpd_cci_noc_axi2_awqos,
  output [3:0] if_ps_noc_cci_axi2_awregion,
  output [2:0] fpd_cci_noc_axi2_awsize,
  output [17:0] fpd_cci_noc_axi2_awuser,
  output  fpd_cci_noc_axi2_awvalid,
  output  fpd_cci_noc_axi2_bready,
  output  fpd_cci_noc_axi2_rready,
  output [127:0] fpd_cci_noc_axi2_wdata,
  output [15:0] if_ps_noc_cci_axi2_wid,
  output  fpd_cci_noc_axi2_wlast,
  output [15:0] fpd_cci_noc_axi2_wstrb,
  output [16:0] fpd_cci_noc_axi2_wuser,
  output  fpd_cci_noc_axi2_wvalid,
  output [63:0] fpd_cci_noc_axi3_araddr,
  output [1:0] fpd_cci_noc_axi3_arburst,
  output [3:0] fpd_cci_noc_axi3_arcache,
  output [15:0] fpd_cci_noc_axi3_arid,
  output [7:0] fpd_cci_noc_axi3_arlen,
  output  fpd_cci_noc_axi3_arlock,
  output [2:0] fpd_cci_noc_axi3_arprot,
  output [3:0] fpd_cci_noc_axi3_arqos,
  output [3:0] if_ps_noc_cci_axi3_arregion,
  output [2:0] fpd_cci_noc_axi3_arsize,
  output [17:0] fpd_cci_noc_axi3_aruser,
  output  fpd_cci_noc_axi3_arvalid,
  output [63:0] fpd_cci_noc_axi3_awaddr,
  output [1:0] fpd_cci_noc_axi3_awburst,
  output [3:0] fpd_cci_noc_axi3_awcache,
  output [15:0] fpd_cci_noc_axi3_awid,
  output [7:0] fpd_cci_noc_axi3_awlen,
  output  fpd_cci_noc_axi3_awlock,
  output [2:0] fpd_cci_noc_axi3_awprot,
  output [3:0] fpd_cci_noc_axi3_awqos,
  output [3:0] if_ps_noc_cci_axi3_awregion,
  output [2:0] fpd_cci_noc_axi3_awsize,
  output [17:0] fpd_cci_noc_axi3_awuser,
  output  fpd_cci_noc_axi3_awvalid,
  output  fpd_cci_noc_axi3_bready,
  output  fpd_cci_noc_axi3_rready,
  output [127:0] fpd_cci_noc_axi3_wdata,
  output [15:0] if_ps_noc_cci_axi3_wid,
  output  fpd_cci_noc_axi3_wlast,
  output [15:0] fpd_cci_noc_axi3_wstrb,
  output [16:0] fpd_cci_noc_axi3_wuser,
  output  fpd_cci_noc_axi3_wvalid,
  output [63:0] fpd_axi_noc_axi0_araddr,
  output [1:0] fpd_axi_noc_axi0_arburst,
  output [3:0] fpd_axi_noc_axi0_arcache,
  output [15:0] fpd_axi_noc_axi0_arid,
  output [7:0] fpd_axi_noc_axi0_arlen,
  output  fpd_axi_noc_axi0_arlock,
  output [2:0] fpd_axi_noc_axi0_arprot,
  output [3:0] fpd_axi_noc_axi0_arqos,
  output [3:0] if_ps_noc_nci_axi0_arregion,
  output [2:0] fpd_axi_noc_axi0_arsize,
  output [17:0] fpd_axi_noc_axi0_aruser,
  output  fpd_axi_noc_axi0_arvalid,
  output [63:0] fpd_axi_noc_axi0_awaddr,
  output [1:0] fpd_axi_noc_axi0_awburst,
  output [3:0] fpd_axi_noc_axi0_awcache,
  output [15:0] fpd_axi_noc_axi0_awid,
  output [7:0] fpd_axi_noc_axi0_awlen,
  output  fpd_axi_noc_axi0_awlock,
  output [2:0] fpd_axi_noc_axi0_awprot,
  output [3:0] fpd_axi_noc_axi0_awqos,
  output [3:0] if_ps_noc_nci_axi0_awregion,
  output [2:0] fpd_axi_noc_axi0_awsize,
  output [17:0] fpd_axi_noc_axi0_awuser,
  output  fpd_axi_noc_axi0_awvalid,
  output  fpd_axi_noc_axi0_bready,
  output  fpd_axi_noc_axi0_rready,
  output [127:0] fpd_axi_noc_axi0_wdata,
  output [15:0] if_ps_noc_nci_axi0_wid,
  output  fpd_axi_noc_axi0_wlast,
  output [15:0] fpd_axi_noc_axi0_wstrb,
  output [16:0] if_ps_noc_nci_axi0_wuser,
  output  fpd_axi_noc_axi0_wvalid,
  output [63:0] fpd_axi_noc_axi1_araddr,
  output [1:0] fpd_axi_noc_axi1_arburst,
  output [3:0] fpd_axi_noc_axi1_arcache,
  output [15:0] fpd_axi_noc_axi1_arid,
  output [7:0] fpd_axi_noc_axi1_arlen,
  output  fpd_axi_noc_axi1_arlock,
  output [2:0] fpd_axi_noc_axi1_arprot,
  output [3:0] fpd_axi_noc_axi1_arqos,
  output [3:0] if_ps_noc_nci_axi1_arregion,
  output [2:0] fpd_axi_noc_axi1_arsize,
  output [17:0] fpd_axi_noc_axi1_aruser,
  output  fpd_axi_noc_axi1_arvalid,
  output [63:0] fpd_axi_noc_axi1_awaddr,
  output [1:0] fpd_axi_noc_axi1_awburst,
  output [3:0] fpd_axi_noc_axi1_awcache,
  output [15:0] fpd_axi_noc_axi1_awid,
  output [7:0] fpd_axi_noc_axi1_awlen,
  output  fpd_axi_noc_axi1_awlock,
  output [2:0] fpd_axi_noc_axi1_awprot,
  output [3:0] fpd_axi_noc_axi1_awqos,
  output [3:0] if_ps_noc_nci_axi1_awregion,
  output [2:0] fpd_axi_noc_axi1_awsize,
  output [17:0] fpd_axi_noc_axi1_awuser,
  output  fpd_axi_noc_axi1_awvalid,
  output  fpd_axi_noc_axi1_bready,
  output  fpd_axi_noc_axi1_rready,
  output [127:0] fpd_axi_noc_axi1_wdata,
  output [15:0] if_ps_noc_nci_axi1_wid,
  output  fpd_axi_noc_axi1_wlast,
  output [15:0] fpd_axi_noc_axi1_wstrb,
  output [16:0] if_ps_noc_nci_axi1_wuser,
  output  fpd_axi_noc_axi1_wvalid,
  output [63:0] cpm_pcie_noc_axi0_araddr,
  output [1:0] cpm_pcie_noc_axi0_arburst,
  output [3:0] cpm_pcie_noc_axi0_arcache,
  output [15:0] cpm_pcie_noc_axi0_arid,
  output [7:0] cpm_pcie_noc_axi0_arlen,
  output  cpm_pcie_noc_axi0_arlock,
  output [2:0] cpm_pcie_noc_axi0_arprot,
  output [3:0] cpm_pcie_noc_axi0_arqos,
  output [3:0] if_ps_noc_pci_axi0_arregion,
  output [2:0] cpm_pcie_noc_axi0_arsize,
  output [17:0] cpm_pcie_noc_axi0_aruser,
  output  cpm_pcie_noc_axi0_arvalid,
  output [63:0] cpm_pcie_noc_axi0_awaddr,
  output [1:0] cpm_pcie_noc_axi0_awburst,
  output [3:0] cpm_pcie_noc_axi0_awcache,
  output [15:0] cpm_pcie_noc_axi0_awid,
  output [7:0] cpm_pcie_noc_axi0_awlen,
  output  cpm_pcie_noc_axi0_awlock,
  output [2:0] cpm_pcie_noc_axi0_awprot,
  output [3:0] cpm_pcie_noc_axi0_awqos,
  output [3:0] if_ps_noc_pci_axi0_awregion,
  output [2:0] cpm_pcie_noc_axi0_awsize,
  output [17:0] cpm_pcie_noc_axi0_awuser,
  output  cpm_pcie_noc_axi0_awvalid,
  output  cpm_pcie_noc_axi0_bready,
  output  cpm_pcie_noc_axi0_rready,
  output [127:0] cpm_pcie_noc_axi0_wdata,
  output [15:0] if_ps_noc_pci_axi0_wid,
  output  cpm_pcie_noc_axi0_wlast,
  output [15:0] cpm_pcie_noc_axi0_wstrb,
  output [16:0] if_ps_noc_pci_axi0_wuser,
  output  cpm_pcie_noc_axi0_wvalid,
  output [63:0] cpm_pcie_noc_axi1_araddr,
  output [1:0] cpm_pcie_noc_axi1_arburst,
  output [3:0] cpm_pcie_noc_axi1_arcache,
  output [15:0] cpm_pcie_noc_axi1_arid,
  output [7:0] cpm_pcie_noc_axi1_arlen,
  output  cpm_pcie_noc_axi1_arlock,
  output [2:0] cpm_pcie_noc_axi1_arprot,
  output [3:0] cpm_pcie_noc_axi1_arqos,
  output [3:0] if_ps_noc_pci_axi1_arregion,
  output [2:0] cpm_pcie_noc_axi1_arsize,
  output [17:0] cpm_pcie_noc_axi1_aruser,
  output  cpm_pcie_noc_axi1_arvalid,
  output [63:0] cpm_pcie_noc_axi1_awaddr,
  output [1:0] cpm_pcie_noc_axi1_awburst,
  output [3:0] cpm_pcie_noc_axi1_awcache,
  output [15:0] cpm_pcie_noc_axi1_awid,
  output [7:0] cpm_pcie_noc_axi1_awlen,
  output  cpm_pcie_noc_axi1_awlock,
  output [2:0] cpm_pcie_noc_axi1_awprot,
  output [3:0] cpm_pcie_noc_axi1_awqos,
  output [3:0] if_ps_noc_pci_axi1_awregion,
  output [2:0] cpm_pcie_noc_axi1_awsize,
  output [17:0] cpm_pcie_noc_axi1_awuser,
  output  cpm_pcie_noc_axi1_awvalid,
  output  cpm_pcie_noc_axi1_bready,
  output  cpm_pcie_noc_axi1_rready,
  output [127:0] cpm_pcie_noc_axi1_wdata,
  output [15:0] if_ps_noc_pci_axi1_wid,
  output  cpm_pcie_noc_axi1_wlast,
  output [15:0] cpm_pcie_noc_axi1_wstrb,
  output [16:0] if_ps_noc_pci_axi1_wuser,
  output  cpm_pcie_noc_axi1_wvalid,
  output [63:0] lpd_axi_noc_axi0_araddr,
  output [1:0] lpd_axi_noc_axi0_arburst,
  output [3:0] lpd_axi_noc_axi0_arcache,
  output [15:0] lpd_axi_noc_axi0_arid,
  output [7:0] lpd_axi_noc_axi0_arlen,
  output  lpd_axi_noc_axi0_arlock,
  output [2:0] lpd_axi_noc_axi0_arprot,
  output [3:0] lpd_axi_noc_axi0_arqos,
  output [3:0] if_ps_noc_rpu_axi0_arregion,
  output [2:0] lpd_axi_noc_axi0_arsize,
  output [17:0] lpd_axi_noc_axi0_aruser,
  output  lpd_axi_noc_axi0_arvalid,
  output [63:0] lpd_axi_noc_axi0_awaddr,
  output [1:0] lpd_axi_noc_axi0_awburst,
  output [3:0] lpd_axi_noc_axi0_awcache,
  output [15:0] lpd_axi_noc_axi0_awid,
  output [7:0] lpd_axi_noc_axi0_awlen,
  output  lpd_axi_noc_axi0_awlock,
  output [2:0] lpd_axi_noc_axi0_awprot,
  output [3:0] lpd_axi_noc_axi0_awqos,
  output [3:0] if_ps_noc_rpu_axi0_awregion,
  output [2:0] lpd_axi_noc_axi0_awsize,
  output [17:0] lpd_axi_noc_axi0_awuser,
  output  lpd_axi_noc_axi0_awvalid,
  output  lpd_axi_noc_axi0_bready,
  output  lpd_axi_noc_axi0_rready,
  output [127:0] lpd_axi_noc_axi0_wdata,
  output [15:0] if_ps_noc_rpu_axi0_wid,
  output  lpd_axi_noc_axi0_wlast,
  output [15:0] lpd_axi_noc_axi0_wstrb,
  output [16:0] if_ps_noc_rpu_axi0_wuser,
  output  lpd_axi_noc_axi0_wvalid,
  output [43:0] m_axi_fpd_araddr,
  output [1:0] m_axi_fpd_arburst,
  output [3:0] m_axi_fpd_arcache,
  output [15:0] m_axi_fpd_arid,
  output [7:0] m_axi_fpd_arlen,
  output  m_axi_fpd_arlock,
  output [2:0] m_axi_fpd_arprot,
  output [3:0] m_axi_fpd_arqos,
  output [2:0] m_axi_fpd_arsize,
  output [15:0] m_axi_fpd_aruser,
  output  m_axi_fpd_arvalid,
  output [43:0] m_axi_fpd_awaddr,
  output [1:0] m_axi_fpd_awburst,
  output [3:0] m_axi_fpd_awcache,
  output [15:0] m_axi_fpd_awid,
  output [7:0] m_axi_fpd_awlen,
  output  m_axi_fpd_awlock,
  output [2:0] m_axi_fpd_awprot,
  output [3:0] m_axi_fpd_awqos,
  output [2:0] m_axi_fpd_awsize,
  output [15:0] m_axi_fpd_awuser,
  output  m_axi_fpd_awvalid,
  output  m_axi_fpd_bready,
  output  m_axi_fpd_rready,
  output [C_M_AXI_GP0_DATA_WIDTH-1:0] m_axi_fpd_wdata,
  output  m_axi_fpd_wlast,
  output [((C_M_AXI_GP0_DATA_WIDTH/8)-1):0] m_axi_fpd_wstrb,
  output  m_axi_fpd_wvalid,
  output [43:0] m_axi_lpd_araddr,
  output [1:0] m_axi_lpd_arburst,
  output [3:0] m_axi_lpd_arcache,
  output [15:0] m_axi_lpd_arid,
  output [7:0] m_axi_lpd_arlen,
  output  m_axi_lpd_arlock,
  output [2:0] m_axi_lpd_arprot,
  output [3:0] m_axi_lpd_arqos,
  output [2:0] m_axi_lpd_arsize,
  output [15:0] m_axi_lpd_aruser,
  output  m_axi_lpd_arvalid,
  output [43:0] m_axi_lpd_awaddr,
  output [1:0] m_axi_lpd_awburst,
  output [3:0] m_axi_lpd_awcache,
  output [15:0] m_axi_lpd_awid,
  output [7:0] m_axi_lpd_awlen,
  output  m_axi_lpd_awlock,
  output [2:0] m_axi_lpd_awprot,
  output [3:0] m_axi_lpd_awqos,
  output [2:0] m_axi_lpd_awsize,
  output [15:0] m_axi_lpd_awuser,
  output  m_axi_lpd_awvalid,
  output  m_axi_lpd_bready,
  output  m_axi_lpd_rready,
  output [C_M_AXI_GP2_DATA_WIDTH-1:0] m_axi_lpd_wdata,
  output  m_axi_lpd_wlast,
  output [((C_M_AXI_GP2_DATA_WIDTH/8)-1):0] m_axi_lpd_wstrb,
  output  m_axi_lpd_wvalid,
//output  noc_clk,
//output  noc_rstn,
//output  npi_clk,
//output  npi_rstn,
  output  rtc_clk,
  output  pl0_ref_clk,
  output  pl1_ref_clk,
  output  pl2_ref_clk,
  output  pl3_ref_clk,
  output  pmc_iro_clk,

  output  pmu_aib_afi_fm_fpd_req,
  output  pmu_aib_afi_fm_lpd_req,
  output [46:0] pmu_error_to_pl,
  output  noc_fpd_cci_axi0_clk,
  output  noc_fpd_cci_axi1_clk,
  output  noc_fpd_axi_axi0_clk,
  output  noc_fpd_axi_axi1_clk,
  output  noc_cpm_pcie_axi0_clk,

  input  atb_clk,
  input  [1:0]  atbtbytes,
  input  [31:0] pl_ps_atdata,
  input  [6:0]  pl_ps_atid,
  input  pl_ps_atvalid,
  output pspl_atready,
  output [3:0] user_mux,
  output apu_event_o,
//output [31:0] ps_pl_irq_fpd,
//output [99:0] ps_pl_irq_lpd,
//output [63:0] ps_pl_irq_pmc,

//PS PL Interrupts below
  output ps_pl_irq_perfmonirq0_rpu_pl,
  output ps_pl_irq_perfmonirq1_rpu_pl,
  output ps_pl_irq_lpd_ocm_isr_lpd,
  output ps_pl_irq_lpd_rpu0_critical_err,
  output ps_pl_irq_lpd_rpu1_critical_err,
  output ps_pl_irq_lpd_gpio_lpd,
  output ps_pl_irq_lpd_i2c0,
  output ps_pl_irq_lpd_i2c1,
  output ps_pl_irq_lpd_spi0,
  output ps_pl_irq_lpd_spi1,
  output ps_pl_irq_lpd_uart0,
  output ps_pl_irq_lpd_uart1,
  output ps_pl_irq_lpd_can0,
  output ps_pl_irq_lpd_can1,
  output [3:0] ps_pl_irq_lpd_usb2_interrupt,
  output ps_pl_irq_lpd_usb2_otg_interrupt,
  output ps_pl_irq_lpd_ipi_pmc,
  output ps_pl_irq_lpd_ipi_pmc_nobuf,
  output ps_pl_irq_lpd_ipi_psm,
  output ps_pl_irq_lpd_ipi_ipi0,
  output ps_pl_irq_lpd_ipi_ipi1,
  output ps_pl_irq_lpd_ipi_ipi2,
  output ps_pl_irq_lpd_ipi_ipi3,
  output ps_pl_irq_lpd_ipi_ipi4,
  output ps_pl_irq_lpd_ipi_ipi5,
  output ps_pl_irq_lpd_ipi_ipi6,
  output [2:0] ps_pl_irq_lpd_ttc0,
  output [2:0] ps_pl_irq_lpd_ttc1,
  output [2:0] ps_pl_irq_lpd_ttc2,
  output [2:0] ps_pl_irq_lpd_ttc3,
  output ps_pl_irq_lpd_wwdt,
  output ps_pl_irq_lpd_psm_mb,
  output ps_pl_irq_lpd_xppu_err_interrupt,
  output ps_pl_irq_lpd_int_ir_status,
  output ps_pl_irq_lpd_ams_isr,
  output ps_pl_irq_lpd_gem1,
  output ps_pl_irq_lpd_gem0_wol,
  output ps_pl_irq_lpd_gem2,
  output ps_pl_irq_lpd_gem1_wol,
  output [7:0] ps_pl_irq_lpd_dma,
  output ps_pl_irq_lpd_xmpu_err_interrupt,
  output ps_pl_irq_lpd_wwdt_reset_pending,
  output ps_pl_irq_lpd_gwdt_ws0,
  output ps_pl_irq_lpd_gwdt_ws1,
  output ps_pl_irq_lpd_cpm_ps_isr_misc,
  output ps_pl_irq_lpd_cpm_ps_isr_corr,
  output ps_pl_irq_lpd_usb2_core_pme_generation,
  output ps_pl_irq_lpd_cpm_ps_isr_uncorr,
  output ps_pl_irq_lpd_ocm2_lpd,
  output ps_pl_irq_lpd_ocm2_lpd_uncor_err,
//output [7:0] pl_ps0,

  //FPD
//output [7:0] pl_ps1,
  output ps_pl_irq_fpd_wd,
  output ps_pl_irq_fpd_ams_isr_fpd,
  output ps_pl_irq_fpd_fpd_psm_tz_err,
  output ps_pl_irq_fpd_apu_gic_l2err,
  output ps_pl_irq_fpd_apu_gic_exterr,
  output ps_pl_irq_fpd_apu_gic_regs,
  output ps_pl_irq_fpd_cci_isr,
  output ps_pl_irq_fpd_smmu_isr,
  output ps_pl_irq_fpd_gwdt_ws1,
  output ps_pl_irq_fpd_wwdt_reset_pending,
  output ps_pl_irq_fpd_gwdt_ws2,
  
  //PMC
  output ps_pl_irq_pmc_cfu_interrupt,
  output ps_pl_irq_pmc_cframe_seu_interrupt,
  output ps_pl_irq_pmc_gpio_pmc,
  output ps_pl_irq_pmc_i2c,
  output ps_pl_irq_pmc_ospi,
  output ps_pl_irq_pmc_qspi,
  output ps_pl_irq_pmc_sd0_axi,
  output ps_pl_irq_pmc_sd0_axi_wkup,
  output ps_pl_irq_pmc_sd1_axi,
  output ps_pl_irq_pmc_sd1_axi_wkup,
  output ps_pl_irq_pmc_debug,
  output ps_pl_irq_pmc_dma0,
  output ps_pl_irq_pmc_dma1,
  output ps_pl_irq_pmc_int_ir_status,
  output ps_pl_irq_pmc_xppu,
  output ps_pl_irq_pmc_xmpu,
  output ps_pl_irq_pmc_sbi,
  output ps_pl_irq_pmc_aes,
  output ps_pl_irq_pmc_ecdsa_rsa,
  output ps_pl_irq_pmc_efuse_isr,
  output ps_pl_irq_pmc_sha,
  output ps_pl_irq_pmc_trng,
  output ps_pl_irq_pmc_rtc_alarm_int,
  output ps_pl_irq_pmc_rtc_seconds_int,
  output [1:0] ps_pl_irq_pmc_sysmon_interrupt,
  output [11:0] ps_pl_irq_pmc_npi_interrupt_out,
  output ps_pl_irq_pmc_ocm_isr,
  output ps_pl_irq_pmc_vccint_glitch_detect,
  //PS PL interrupts above

  output [1:0] apu_event_standby_wfe,
  output [1:0] apu_event_standby_wfi,

  output reg trace_ctrl,
  output reg [C_PS_TRACE_WIDTH-1:0] trace_data,
  output reg trace_clk,


  output [3:0] ps_pl_trigack,
  output [3:0] ps_pl_trigger,
  output  fpd_cci_noc_axi0_clk,
  output  fpd_cci_noc_axi1_clk,
  output  fpd_cci_noc_axi2_clk,
  output  fpd_cci_noc_axi3_clk,
  output  fpd_axi_noc_axi0_clk,
  output  fpd_axi_noc_axi1_clk,
  output  ps_ps_noc_nci_axi2_clk,
  output  cpm_pcie_noc_axi0_clk,
  output  cpm_pcie_noc_axi1_clk,
  output  lpd_axi_noc_clk,
  output  lpd_rpu_event_o0,
  output  lpd_rpu_event_o1,
  output [43:0] s_ace_fpd_acaddr,
  output [2:0] s_ace_fpd_acprot,
  output [3:0] s_ace_fpd_acsnoop,
  output  s_ace_fpd_acvalid,
  output  s_ace_fpd_arready,
  output  s_ace_fpd_awready,
  output [5:0] s_ace_fpd_bid,
  output [1:0] s_ace_fpd_bresp,
  output  s_ace_fpd_buser,
  output  s_ace_fpd_bvalid,
  output  s_ace_fpd_cdready,
  output  s_ace_fpd_crready,
  output [C_S_AXI_ACE_DATA_WIDTH-1:0] s_ace_fpd_rdata,
  output [5:0] s_ace_fpd_rid,
  output  s_ace_fpd_rlast,
  output [3:0] s_ace_fpd_rresp,
  output  s_ace_fpd_ruser,
  output  s_ace_fpd_rvalid,
  output  s_ace_fpd_wready,
  output  s_acp_fpd_arready,
  output  s_acp_fpd_awready,
  output [4:0] s_acp_fpd_bid,
  output [1:0] s_acp_fpd_bresp,
  output  s_acp_fpd_bvalid,
  output [C_S_AXI_ACP_DATA_WIDTH-1:0] s_acp_fpd_rdata,
  output [4:0] s_acp_fpd_rid,
  output  s_acp_fpd_rlast,
  output [1:0] s_acp_fpd_rresp,
  output  s_acp_fpd_rvalid,
  output  s_acp_fpd_wready,
  output  s_axi_fpd_arready,
  output  s_axi_fpd_awready,
  output [5:0] s_axi_fpd_bid,
  output [1:0] s_axi_fpd_bresp,
  output  s_axi_fpd_bvalid,
  output [3:0] s_axi_fpd_racount,
  output [7:0] s_axi_fpd_rcount,
  output [C_S_AXI_GP0_DATA_WIDTH-1:0] s_axi_fpd_rdata,
  output [5:0] s_axi_fpd_rid,
  output  s_axi_fpd_rlast,
  output [1:0] s_axi_fpd_rresp,
  output  s_axi_fpd_rvalid,
  output [3:0] s_axi_fpd_wacount,
  output [7:0] s_axi_fpd_wcount,
  output  s_axi_fpd_wready,

  output  s_axi_gp2_arready,
  output  s_axi_gp2_awready,
  output [5:0] s_axi_gp2_bid,
  output [1:0] s_axi_gp2_bresp,
  output  s_axi_gp2_bvalid,
  output [3:0] s_axi_gp2_racount,
  output [7:0] s_axi_gp2_rcount,
  output [C_S_AXI_GP2_DATA_WIDTH-1:0] s_axi_gp2_rdata,
  output [5:0] s_axi_gp2_rid,
  output  s_axi_gp2_rlast,
  output [1:0] s_axi_gp2_rresp,
  output  s_axi_gp2_rvalid,
  output [3:0] s_axi_gp2_wacount,
  output [7:0] s_axi_gp2_wcount,
  output  s_axi_gp2_wready,
  output  s_axi_lpd_arready,
  output  s_axi_lpd_awready,
  output [5:0] s_axi_lpd_bid,
  output [1:0] s_axi_lpd_bresp,
  output  s_axi_lpd_bvalid,
  output [3:0] s_axi_lpd_racount,
  output [7:0] s_axi_lpd_rcount,
  output [C_S_AXI_GP4_DATA_WIDTH-1:0] s_axi_lpd_rdata,
  output [5:0] s_axi_lpd_rid,
  output  s_axi_lpd_rlast,
  output [1:0] s_axi_lpd_rresp,
  output  s_axi_lpd_rvalid,
  output [3:0] s_axi_lpd_wacount,
  output [7:0] s_axi_lpd_wcount,
  output  s_axi_lpd_wready,
  inout  [25:0] pss_pad_lpdmio,
//input  [7:0] adma_fci_clk,
  input  lpd_dma_clk0,
  input  lpd_dma_clk1,
  input  lpd_dma_clk2,
  input  lpd_dma_clk3,
  input  lpd_dma_clk4,
  input  lpd_dma_clk5,
  input  lpd_dma_clk6,
  input  lpd_dma_clk7,
  input  aib_pmu_afi_fm_fpd_ack,
  input  aib_pmu_afi_fm_lpd_ack,
  input  canfd0_phy_rx,
  input  canfd1_phy_rx,
  input  gem0_fifo_dma_tx_status_tog,
  input  gem0_ext_int_in,
  input  gem0_gmii_col,
  input  gem0_gmii_crs,
  input  gem0_gmii_rx_clk,
  input  [7:0] gem0_gmii_rx_d,
  input  gem0_gmii_rx_dv,
  input  gem0_gmii_rx_err,
  input  gem0_gmii_tx_clk,
  input  gem0_mdio_i,
  input  gem0_fifo_rx_w_overflow,
  input  gem0_fifo_tx_r_control,
  input  [7:0] gem0_fifo_tx_r_data,
  input  [1:0]gem0_fifo_tx_r_data_rdy,
  input  gem0_fifo_tx_r_eop,
  input  gem0_fifo_tx_r_err,
  input  gem0_fifo_tx_r_flushed,
  input  gem0_fifo_tx_r_sop,
  input  gem0_fifo_tx_r_underflow,
  input  gem0_fifo_tx_r_valid,
  input  gem1_fifo_dma_tx_status_tog,
  input  emio_enet1_ext_int_in,
  input  gem1_gmii_col,
  input  gem1_gmii_crs,
  input  gem1_gmii_rx_clk,
  input  [7:0] gem1_gmii_rx_d,
  input  gem1_gmii_rx_dv,
  input  gem1_gmii_rx_err,
  input  gem1_gmii_tx_clk,
  input  gem1_mdio_i,
  input  gem1_fifo_rx_w_overflow,
  input  gem1_fifo_tx_r_control,
  input  [7:0] gem1_fifo_tx_r_data,
  input  [1:0] gem1_fifo_tx_r_data_rdy,
  input  gem1_fifo_tx_r_eop,
  input  gem1_fifo_tx_r_err,
  input  gem1_fifo_tx_r_flushed,
  input  gem1_fifo_tx_r_sop,
  input  gem1_fifo_tx_r_underflow,
  input  gem1_fifo_tx_r_valid,
  input  emio_enet_tsu_clk,
  input  [1:0] gem0_tsu_inc_ctrl,
  input  [1:0] gem1_tsu_inc_ctrl,
  input  emio_hub_port_overcrnt_usb2_0,
//input  emio_hub_port_overcrnt_usb2_1,
//input  emio_hub_port_overcrnt_usb3_0,
//input  emio_hub_port_overcrnt_usb3_1,
  input  i2c0_scl_i,
  input  i2c0_sda_i,
  input  i2c1_scl_i,
  input  i2c1_sda_i,
  input  spi0_m_i,
  input  spi0_sclk_i,
  input  spi0_s_i,
  input  spi0_ss_i_n,
  input  spi1_m_i,
  input  spi1_sclk_i,
  input  spi1_s_i,
  input  spi1_ss_i_n,
  input  [2:0] ttc0_clk,
  input  [2:0] ttc1_clk,
  input  [2:0] ttc2_clk,
  input  [2:0] ttc3_clk,

  input  emio_wdt0_clk_i,
  input  emio_wdt1_clk_i,
  input  fmio_gem0_fifo_rx_clk_from_pl,
  input  fmio_gem0_fifo_tx_clk_from_pl,
  input  fmio_gem0_signal_detect,
  input  fmio_gem1_fifo_rx_clk_from_pl,
  input  fmio_gem1_fifo_tx_clk_from_pl,
  input  fmio_gem_tsu_clk_from_pl,
  input  fmio_gem1_signal_detect,
  input  fmio_gemtsuclkfrompl,

  output fmio_gem_tsu_clk_to_pl,
  output gem1_fifo_rx_clk_to_pl,
  output gem1_fifo_tx_clk_to_pl,
  output gem0_fifo_rx_clk_to_pl,
  output gem0_fifo_tx_clk_to_pl,

//input  [63:0] fmio_gpio_in,
  input  fmioi2csclin,
  input  fmioi2csdain,

  input  sd0_rx_clk,
  input  sd1_rx_clk,
//  input  [31:0] ftm_gpi,

  input  [63:0] noc_fpd_cci_axi0_araddr,
  input  [1:0] noc_fpd_cci_axi0_arburst,
  input  [3:0] noc_fpd_cci_axi0_arcache,
  input  [7:0] noc_fpd_cci_axi0_arlen,
  input  noc_fpd_cci_axi0_arlock,
  input  [2:0] noc_fpd_cci_axi0_arprot,
  input  [3:0] noc_fpd_cci_axi0_arqos,
  input  [3:0] noc_fpd_cci_axi0_arregion,
  input  [2:0] noc_fpd_cci_axi0_arsize,
  input  [17:0] noc_fpd_cci_axi0_aruser,
  input  noc_fpd_cci_axi0_arvalid,
  input  [63:0] noc_fpd_cci_axi0_awaddr,
  input  [1:0] noc_fpd_cci_axi0_awburst,
  input  [3:0] noc_fpd_cci_axi0_awcache,
  input  [7:0] noc_fpd_cci_axi0_awlen,
  input  noc_fpd_cci_axi0_awlock,
  input  [2:0] noc_fpd_cci_axi0_awprot,
  input  [3:0] noc_fpd_cci_axi0_awqos,
  input  [3:0] noc_fpd_cci_axi0_awregion,
  input  [2:0] noc_fpd_cci_axi0_awsize,
  input  [17:0] noc_fpd_cci_axi0_awuser,
  input  noc_fpd_cci_axi0_awvalid,
  input  noc_fpd_cci_axi0_bready,
  input  noc_fpd_cci_axi0_rready,
  input  [127:0] noc_fpd_cci_axi0_wdata,
  input  noc_fpd_cci_axi0_wlast,
  input  [15:0] noc_fpd_cci_axi0_wstrb,
  input  [16:0] noc_fpd_cci_axi0_wuser,
  input  noc_fpd_cci_axi0_wvalid,
  input  [1:0] noc_fpd_cci_axi0_arid,
  input  [1:0] noc_fpd_cci_axi0_awid,
  input  [3:0] noc_fpd_cci_axi0_wid,
  input  [1:0] noc_fpd_cci_axi1_arid,
  input  [1:0] noc_fpd_cci_axi1_awid,
  input  [3:0] noc_fpd_cci_axi1_wid,

  input  [63:0] noc_fpd_cci_axi1_araddr,
  input  [1:0] noc_fpd_cci_axi1_arburst,
  input  [3:0] noc_fpd_cci_axi1_arcache,
  input  [7:0] noc_fpd_cci_axi1_arlen,
  input  noc_fpd_cci_axi1_arlock,
  input  [2:0] noc_fpd_cci_axi1_arprot,
  input  [3:0] noc_fpd_cci_axi1_arqos,
  input  [3:0] noc_fpd_cci_axi1_arregion,
  input  [2:0] noc_fpd_cci_axi1_arsize,
  input  [17:0] noc_fpd_cci_axi1_aruser,
  input  noc_fpd_cci_axi1_arvalid,
  input  [63:0] noc_fpd_cci_axi1_awaddr,
  input  [1:0] noc_fpd_cci_axi1_awburst,
  input  [3:0] noc_fpd_cci_axi1_awcache,
  input  [7:0] noc_fpd_cci_axi1_awlen,
  input  noc_fpd_cci_axi1_awlock,
  input  [2:0] noc_fpd_cci_axi1_awprot,
  input  [3:0] noc_fpd_cci_axi1_awqos,
  input  [3:0] noc_fpd_cci_axi1_awregion,
  input  [2:0] noc_fpd_cci_axi1_awsize,
  input  [17:0] noc_fpd_cci_axi1_awuser,
  input  noc_fpd_cci_axi1_awvalid,
  input  noc_fpd_cci_axi1_bready,
  input  noc_fpd_cci_axi1_rready,
  input  [127:0] noc_fpd_cci_axi1_wdata,
  input  noc_fpd_cci_axi1_wlast,
  input  [15:0] noc_fpd_cci_axi1_wstrb,
  input  [16:0] noc_fpd_cci_axi1_wuser,
  input  noc_fpd_cci_axi1_wvalid,
  input  [63:0] noc_fpd_axi_axi0_araddr,
  input  [1:0] noc_fpd_axi_axi0_arburst,
  input  [3:0] noc_fpd_axi_axi0_arcache,
  input  [1:0] noc_fpd_axi_axi0_arid,
  input  [7:0] noc_fpd_axi_axi0_arlen,
  input  noc_fpd_axi_axi0_arlock,
  input  [2:0] noc_fpd_axi_axi0_arprot,
  input  [3:0] noc_fpd_axi_axi0_arqos,
  input  [3:0] noc_fpd_axi_axi0_arregion,
  input  [2:0] noc_fpd_axi_axi0_arsize,
  input  [17:0] noc_fpd_axi_axi0_aruser,
  input  noc_fpd_axi_axi0_arvalid,
  input  [63:0] noc_fpd_axi_axi0_awaddr,
  input  [1:0] noc_fpd_axi_axi0_awburst,
  input  [3:0] noc_fpd_axi_axi0_awcache,
  input  [1:0] noc_fpd_axi_axi0_awid,
  input  [7:0] noc_fpd_axi_axi0_awlen,
  input  noc_fpd_axi_axi0_awlock,
  input  [2:0] noc_fpd_axi_axi0_awprot,
  input  [3:0] noc_fpd_axi_axi0_awqos,
  input  [3:0] noc_fpd_axi_axi0_awregion,
  input  [2:0] noc_fpd_axi_axi0_awsize,
  input  [17:0] noc_fpd_axi_axi0_awuser,
  input  noc_fpd_axi_axi0_awvalid,
  input  noc_fpd_axi_axi0_bready,
  input  noc_fpd_axi_axi0_rready,
  input  [127:0] noc_fpd_axi_axi0_wdata,
  input  [3:0] noc_fpd_axi_axi0_wid,
  input  noc_fpd_axi_axi0_wlast,
  input  [15:0] noc_fpd_axi_axi0_wstrb,
  input  [16:0] noc_fpd_axi_axi0_wuser,
  input  noc_fpd_axi_axi0_wvalid,
  input  [63:0] noc_fpd_axi_axi1_araddr,
  input  [1:0] noc_fpd_axi_axi1_arburst,
  input  [3:0] noc_fpd_axi_axi1_arcache,
  input  [1:0] noc_fpd_axi_axi1_arid,
  input  [7:0] noc_fpd_axi_axi1_arlen,
  input  noc_fpd_axi_axi1_arlock,
  input  [2:0] noc_fpd_axi_axi1_arprot,
  input  [3:0] noc_fpd_axi_axi1_arqos,
  input  [3:0] noc_fpd_axi_axi1_arregion,
  input  [2:0] noc_fpd_axi_axi1_arsize,
  input  [17:0] noc_fpd_axi_axi1_aruser,
  input  noc_fpd_axi_axi1_arvalid,
  input  [63:0] noc_fpd_axi_axi1_awaddr,
  input  [1:0] noc_fpd_axi_axi1_awburst,
  input  [3:0] noc_fpd_axi_axi1_awcache,
  input  [1:0] noc_fpd_axi_axi1_awid,
  input  [7:0] noc_fpd_axi_axi1_awlen,
  input  noc_fpd_axi_axi1_awlock,
  input  [2:0] noc_fpd_axi_axi1_awprot,
  input  [3:0] noc_fpd_axi_axi1_awqos,
  input  [3:0] noc_fpd_axi_axi1_awregion,
  input  [2:0] noc_fpd_axi_axi1_awsize,
  input  [17:0] noc_fpd_axi_axi1_awuser,
  input  noc_fpd_axi_axi1_awvalid,
  input  noc_fpd_axi_axi1_bready,
  input  noc_fpd_axi_axi1_rready,
  input  [127:0] noc_fpd_axi_axi1_wdata,
  input  noc_fpd_axi_axi1_wlast,
  input  [15:0] noc_fpd_axi_axi1_wstrb,
  input  [16:0] noc_fpd_axi_axi1_wuser,
  input  [3:0] noc_fpd_axi_axi1_wid,
  input  noc_fpd_axi_axi1_wvalid,
  input  [63:0] noc_cpm_pcie_axi0_araddr,
  input  [1:0] noc_cpm_pcie_axi0_arburst,
  input  [3:0] noc_cpm_pcie_axi0_arcache,
  input  [1:0] noc_cpm_pcie_axi0_arid,
  input  [7:0] noc_cpm_pcie_axi0_arlen,
  input  noc_cpm_pcie_axi0_arlock,
  input  [2:0] noc_cpm_pcie_axi0_arprot,
  input  [3:0] noc_cpm_pcie_axi0_arqos,
  input  [3:0] noc_cpm_pcie_axi0_arregion,
  input  [2:0] noc_cpm_pcie_axi0_arsize,
  input  [17:0] noc_cpm_pcie_axi0_aruser,
  input  noc_cpm_pcie_axi0_arvalid,
  input  [63:0] noc_cpm_pcie_axi0_awaddr,
  input  [1:0] noc_cpm_pcie_axi0_awburst,
  input  [3:0] noc_cpm_pcie_axi0_awcache,
  input  [1:0] noc_cpm_pcie_axi0_awid,
  input  [7:0] noc_cpm_pcie_axi0_awlen,
  input  noc_cpm_pcie_axi0_awlock,
  input  [2:0] noc_cpm_pcie_axi0_awprot,
  input  [3:0] noc_cpm_pcie_axi0_awqos,
  input  [3:0] noc_cpm_pcie_axi0_awregion,
  input  [2:0] noc_cpm_pcie_axi0_awsize,
  input  [17:0] noc_cpm_pcie_axi0_awuser,
  input  noc_cpm_pcie_axi0_awvalid,
  input  noc_cpm_pcie_axi0_bready,
  input  noc_cpm_pcie_axi0_rready,
  input  [127:0] noc_cpm_pcie_axi0_wdata,
  input  [3:0] noc_cpm_pcie_axi0_wid,
  input  noc_cpm_pcie_axi0_wlast,
  input  [15:0] noc_cpm_pcie_axi0_wstrb,
  input  [16:0] if_noc_ps_pci_axi0_wuser,
  input  noc_cpm_pcie_axi0_wvalid,
  input  fpd_cci_noc_axi0_arready,
  input  fpd_cci_noc_axi0_awready,
  input  [15:0] fpd_cci_noc_axi0_bid,
  input  [1:0] fpd_cci_noc_axi0_bresp,
  input  [15:0] if_ps_noc_cci_axi0_buser,
  input  fpd_cci_noc_axi0_bvalid,
  input  [127:0] fpd_cci_noc_axi0_rdata,
  input  [15:0] fpd_cci_noc_axi0_rid,
  input  fpd_cci_noc_axi0_rlast,
  input  [1:0] fpd_cci_noc_axi0_rresp,
  input  [16:0] if_ps_noc_cci_axi0_ruser,
  input  fpd_cci_noc_axi0_rvalid,
  input  fpd_cci_noc_axi0_wready,
  input  fpd_cci_noc_axi1_arready,
  input  fpd_cci_noc_axi1_awready,
  input  [15:0] fpd_cci_noc_axi1_bid,
  input  [1:0] fpd_cci_noc_axi1_bresp,
  input  [15:0] if_ps_noc_cci_axi1_buser,
  input  fpd_cci_noc_axi1_bvalid,
  input  [127:0] fpd_cci_noc_axi1_rdata,
  input  [15:0] fpd_cci_noc_axi1_rid,
  input  fpd_cci_noc_axi1_rlast,
  input  [1:0] fpd_cci_noc_axi1_rresp,
  input  [16:0] if_ps_noc_cci_axi1_ruser,
  input  fpd_cci_noc_axi1_rvalid,
  input  fpd_cci_noc_axi1_wready,
  input  fpd_cci_noc_axi2_arready,
  input  fpd_cci_noc_axi2_awready,
  input  [15:0] fpd_cci_noc_axi2_bid,
  input  [1:0] fpd_cci_noc_axi2_bresp,
  input  [15:0] if_ps_noc_cci_axi2_buser,
  input  fpd_cci_noc_axi2_bvalid,
  input  [127:0] fpd_cci_noc_axi2_rdata,
  input  [15:0] fpd_cci_noc_axi2_rid,
  input  fpd_cci_noc_axi2_rlast,
  input  [1:0] fpd_cci_noc_axi2_rresp,
  input  [16:0] if_ps_noc_cci_axi2_ruser,
  input  fpd_cci_noc_axi2_rvalid,
  input  fpd_cci_noc_axi2_wready,
  input  fpd_cci_noc_axi3_arready,
  input  fpd_cci_noc_axi3_awready,
  input  [15:0] fpd_cci_noc_axi3_bid,
  input  [1:0] fpd_cci_noc_axi3_bresp,
  input  [15:0] if_ps_noc_cci_axi3_buser,
  input  fpd_cci_noc_axi3_bvalid,
  input  [127:0] fpd_cci_noc_axi3_rdata,
  input  [15:0] fpd_cci_noc_axi3_rid,
  input  fpd_cci_noc_axi3_rlast,
  input  [1:0] fpd_cci_noc_axi3_rresp,
  input  [16:0] if_ps_noc_cci_axi3_ruser,
  input  fpd_cci_noc_axi3_rvalid,
  input  fpd_cci_noc_axi3_wready,
  input  fpd_axi_noc_axi0_arready,
  input  fpd_axi_noc_axi0_awready,
  input  [15:0] fpd_axi_noc_axi0_bid,
  input  [1:0] fpd_axi_noc_axi0_bresp,
  input  [15:0] if_ps_noc_nci_axi0_buser,
  input  fpd_axi_noc_axi0_bvalid,
  input  [127:0] fpd_axi_noc_axi0_rdata,
  input  [15:0] fpd_axi_noc_axi0_rid,
  input  fpd_axi_noc_axi0_rlast,
  input  [1:0] fpd_axi_noc_axi0_rresp,
  input  [16:0] if_ps_noc_nci_axi0_ruser,
  input  fpd_axi_noc_axi0_rvalid,
  input  fpd_axi_noc_axi0_wready,
  input  fpd_axi_noc_axi1_arready,
  input  fpd_axi_noc_axi1_awready,
  input  [15:0] fpd_axi_noc_axi1_bid,
  input  [1:0] fpd_axi_noc_axi1_bresp,
  input  [15:0] if_ps_noc_nci_axi1_buser,
  input  fpd_axi_noc_axi1_bvalid,
  input  [127:0] fpd_axi_noc_axi1_rdata,
  input  [15:0] fpd_axi_noc_axi1_rid,
  input  fpd_axi_noc_axi1_rlast,
  input  [1:0] fpd_axi_noc_axi1_rresp,
  input  [16:0] if_ps_noc_nci_axi1_ruser,
  input  fpd_axi_noc_axi1_rvalid,
  input  fpd_axi_noc_axi1_wready,
  input  cpm_pcie_noc_axi0_arready,
  input  cpm_pcie_noc_axi0_awready,
  input  [15:0] cpm_pcie_noc_axi0_bid,
  input  [1:0] cpm_pcie_noc_axi0_bresp,
  input  [15:0] if_ps_noc_pci_axi0_buser,
  input  cpm_pcie_noc_axi0_bvalid,
  input  [127:0] cpm_pcie_noc_axi0_rdata,
  input  [15:0] cpm_pcie_noc_axi0_rid,
  input  cpm_pcie_noc_axi0_rlast,
  input  [1:0] cpm_pcie_noc_axi0_rresp,
  input  [16:0] if_ps_noc_pci_axi0_ruser,
  input  cpm_pcie_noc_axi0_rvalid,
  input  cpm_pcie_noc_axi0_wready,
  input  cpm_pcie_noc_axi1_arready,
  input  cpm_pcie_noc_axi1_awready,
  input  [15:0] cpm_pcie_noc_axi1_bid,
  input  [1:0] cpm_pcie_noc_axi1_bresp,
  input  [15:0] if_ps_noc_pci_axi1_buser,
  input  cpm_pcie_noc_axi1_bvalid,
  input  [127:0] cpm_pcie_noc_axi1_rdata,
  input  [15:0] cpm_pcie_noc_axi1_rid,
  input  cpm_pcie_noc_axi1_rlast,
  input  [1:0] cpm_pcie_noc_axi1_rresp,
  input  [16:0] if_ps_noc_pci_axi1_ruser,
  input  cpm_pcie_noc_axi1_rvalid,
  input  cpm_pcie_noc_axi1_wready,
  input  lpd_axi_noc_axi0_arready,
  input  lpd_axi_noc_axi0_awready,
  input  [15:0] lpd_axi_noc_axi0_bid,
  input  [1:0] lpd_axi_noc_axi0_bresp,
  input  [15:0] if_ps_noc_rpu_axi0_buser,
  input  lpd_axi_noc_axi0_bvalid,
  input  [127:0] lpd_axi_noc_axi0_rdata,
  input  [15:0] lpd_axi_noc_axi0_rid,
  input  lpd_axi_noc_axi0_rlast,
  input  [1:0] lpd_axi_noc_axi0_rresp,
  input  [16:0] if_ps_noc_rpu_axi0_ruser,
  input  lpd_axi_noc_axi0_rvalid,
  input  lpd_axi_noc_axi0_wready,
  input  m_axi_fpd_aclk,
  input  m_axi_fpd_arready,
  input  m_axi_fpd_awready,
  input  [15:0] m_axi_fpd_bid,
  input  [1:0] m_axi_fpd_bresp,
  input  m_axi_fpd_bvalid,
  input  [C_M_AXI_GP0_DATA_WIDTH-1:0] m_axi_fpd_rdata,
  input  [15:0] m_axi_fpd_rid,
  input  m_axi_fpd_rlast,
  input  [1:0] m_axi_fpd_rresp,
  input  m_axi_fpd_rvalid,
  input  m_axi_fpd_wready,
  input  m_axi_lpd_aclk,
  input  m_axi_lpd_arready,
  input  m_axi_lpd_awready,
  input  [15:0] m_axi_lpd_bid,
  input  [1:0] m_axi_lpd_bresp,
  input  m_axi_lpd_bvalid,
  input  [C_M_AXI_GP2_DATA_WIDTH-1:0] m_axi_lpd_rdata,
  input  [15:0] m_axi_lpd_rid,
  input  m_axi_lpd_rlast,
  input  [1:0] m_axi_lpd_rresp,
  input  m_axi_lpd_rvalid,
  input  m_axi_lpd_wready,
  input  lpd_rpu_fiq0n,
  input  lpd_rpu_fiq1n,
  input  lpd_rpu_irq0n,
  input  lpd_rpu_irq1n,
//input  [7:0] pl_2_adma_cvld,
//input  [7:0] pl_2_adma_tack,
  input  lpd_dma0_cvld,
  input  lpd_dma1_cvld,
  input  lpd_dma2_cvld,
  input  lpd_dma3_cvld,
  input  lpd_dma4_cvld,
  input  lpd_dma5_cvld,
  input  lpd_dma6_cvld,
  input  lpd_dma7_cvld,

  input  lpd_dma0_tack,
  input  lpd_dma1_tack,
  input  lpd_dma2_tack,
  input  lpd_dma3_tack,
  input  lpd_dma4_tack,
  input  lpd_dma5_tack,
  input  lpd_dma6_tack,
  input  lpd_dma7_tack,
  input  s_ace_fpd_aclk,
  input  s_acp_fpd_inact,
  input  pl_config_done,
  input  [3:0] pl_fpga_stop,
  input  pl_fpd_aux_ref_clk,
  input  pl_lpd_aux_ref_clk,
  input  pl_pmc_aux_ref_clk,
  input  [1:0] pl_ps_apu_gic_fiq,
  input  [1:0] pl_ps_apu_gic_irq,
  input  apu_event_i,
  input  pl_ps_irq0,
  input  pl_ps_irq1,
  input  pl_ps_irq2,
  input  pl_ps_irq3,
  input  pl_ps_irq4,
  input  pl_ps_irq5,
  input  pl_ps_irq6,
  input  pl_ps_irq7,
  input  pl_ps_irq8,
  input  pl_ps_irq9,
  input  pl_ps_irq10,
  input  pl_ps_irq11,
  input  pl_ps_irq12,
  input  pl_ps_irq13,
  input  pl_ps_irq14,
  input  pl_ps_irq15,
  input  trace_ref_clk,

  input ps_pl_trig0_ack,
  input ps_pl_trig1_ack,
  input ps_pl_trig2_ack,
  input ps_pl_trig3_ack,

  input pl_ps_trig0_req,
  input pl_ps_trig1_req,
  input pl_ps_trig2_req,
  input pl_ps_trig3_req,

  output pl_ps_trig0_ack,
  output pl_ps_trig1_ack,
  output pl_ps_trig2_ack,
  output pl_ps_trig3_ack,

  output ps_pl_trig0_req,
  output ps_pl_trig1_req,
  output ps_pl_trig2_req,
  output ps_pl_trig3_req,

  input  [3:0] pl_ps_trigack,
  input  [3:0] pl_ps_trigger,
  input  [3:0] pmu_error_from_pl,
  input  lpd_rpu_event_i0,
  input  lpd_rpu_event_i1,
  input  s_ace_fpd_acready,
  input  [43:0] s_ace_fpd_araddr,
  input  [1:0] s_ace_fpd_arbar,
  input  [1:0] s_ace_fpd_arburst,
  input  [3:0] s_ace_fpd_arcache,
  input  [1:0] s_ace_fpd_ardomain,
  input  [5:0] s_ace_fpd_arid,
  input  [7:0] s_ace_fpd_arlen,
  input  s_ace_fpd_arlock,
  input  [2:0] s_ace_fpd_arprot,
  input  [3:0] s_ace_fpd_arqos,
  input  [3:0] s_ace_fpd_arregion,
  input  [2:0] s_ace_fpd_arsize,
  input  [3:0] s_ace_fpd_arsnoop,
  input  [15:0] s_ace_fpd_aruser,
  input  s_ace_fpd_arvalid,
  input  [43:0] s_ace_fpd_awaddr,
  input  [1:0] s_ace_fpd_awbar,
  input  [1:0] s_ace_fpd_awburst,
  input  [3:0] s_ace_fpd_awcache,
  input  [1:0] s_ace_fpd_awdomain,
  input  [5:0] s_ace_fpd_awid,
  input  [7:0] s_ace_fpd_awlen,
  input  s_ace_fpd_awlock,
  input  [2:0] s_ace_fpd_awprot,
  input  [3:0] s_ace_fpd_awqos,
  input  [3:0] s_ace_fpd_awregion,
  input  [2:0] s_ace_fpd_awsize,
  input  [2:0] s_ace_fpd_awsnoop,
  input  [15:0] s_ace_fpd_awuser,
  input  s_ace_fpd_awvalid,
  input  s_ace_fpd_bready,
  input  [127:0] s_ace_fpd_cddata,
  input  s_ace_fpd_cdlast,
  input  s_ace_fpd_cdvalid,
  input  [4:0] s_ace_fpd_crresp,
  input  s_ace_fpd_crvalid,
  input  s_ace_fpd_rack,
  input  s_ace_fpd_rready,
  input  s_ace_fpd_wack,
  input  [C_S_AXI_ACE_DATA_WIDTH-1:0] s_ace_fpd_wdata,
  input  s_ace_fpd_wlast,
  input  [((C_S_AXI_ACE_DATA_WIDTH/8)-1):0] s_ace_fpd_wstrb,
  input  s_ace_fpd_wuser,
  input  s_ace_fpd_wvalid,
  input  s_acp_fpd_aclk,
  input  [43:0] s_acp_fpd_araddr,
//input  [1:0] s_axi_acp_arburst,
  input  [3:0] s_acp_fpd_arcache,
  input  [4:0] s_acp_fpd_arid,
  input  [7:0] s_acp_fpd_arlen,
//input  s_axi_acp_arlock,
  input  [2:0] s_acp_fpd_arprot,
//input  [3:0] s_axi_acp_arqos,
//input  [2:0] s_axi_acp_arsize,
  input  [1:0] s_acp_fpd_aruser,
  input  s_acp_fpd_arvalid,
  input  [43:0] s_acp_fpd_awaddr,
//input  [1:0] s_axi_acp_awburst,
  input  [3:0] s_acp_fpd_awcache,
  input  [4:0] s_acp_fpd_awid,
  input  [7:0] s_acp_fpd_awlen,
//input  s_axi_acp_awlock,
  input  [2:0] s_acp_fpd_awprot,
//input  [3:0] s_axi_acp_awqos,
//input  [2:0] s_axi_acp_awsize,
  input  [1:0] s_acp_fpd_awuser,
  input  s_acp_fpd_awvalid,
  input  s_acp_fpd_bready,
  input  s_acp_fpd_rready,
  input  [C_S_AXI_ACP_DATA_WIDTH-1:0] s_acp_fpd_wdata,
  input  s_acp_fpd_wlast,
  input  [((C_S_AXI_ACP_DATA_WIDTH/8)-1):0] s_acp_fpd_wstrb,
  input  s_acp_fpd_wvalid,

  input  [48:0] s_axi_fpd_araddr,
  input  [1:0] s_axi_fpd_arburst,
  input  [3:0] s_axi_fpd_arcache,
  input  [5:0] s_axi_fpd_arid,
  input  [7:0] s_axi_fpd_arlen,
  input  s_axi_fpd_arlock,
  input  [2:0] s_axi_fpd_arprot,
  input  [3:0] s_axi_fpd_arqos,
  input  [2:0] s_axi_fpd_arsize,
  input  [9:0] s_axi_fpd_aruser,
  input  s_axi_fpd_arvalid,
  input  [48:0] s_axi_fpd_awaddr,
  input  [1:0] s_axi_fpd_awburst,
  input  [3:0] s_axi_fpd_awcache,
  input  [5:0] s_axi_fpd_awid,
  input  [7:0] s_axi_fpd_awlen,
  input  s_axi_fpd_awlock,
  input  [2:0] s_axi_fpd_awprot,
  input  [3:0] s_axi_fpd_awqos,
  input  [2:0] s_axi_fpd_awsize,
  input  [9:0] s_axi_fpd_awuser,
  input  s_axi_fpd_awvalid,
  input  s_axi_fpd_bready,
  input  s_axi_fpd_rclk,
  input  s_axi_fpd_rready,
  input  s_axi_fpd_wclk,
  input  [C_S_AXI_GP0_DATA_WIDTH-1:0] s_axi_fpd_wdata,
  input  s_axi_fpd_wlast,
  input  [((C_S_AXI_GP0_DATA_WIDTH/8)-1):0] s_axi_fpd_wstrb,
  input  s_axi_fpd_wvalid,
  input  s_axi_fpd_aclk,

  input  [48:0] s_axi_gp2_araddr,
  input  [1:0] s_axi_gp2_arburst,
  input  [3:0] s_axi_gp2_arcache,
  input  [5:0] s_axi_gp2_arid,
  input  [7:0] s_axi_gp2_arlen,
  input  s_axi_gp2_arlock,
  input  [2:0] s_axi_gp2_arprot,
  input  [3:0] s_axi_gp2_arqos,
  input  [2:0] s_axi_gp2_arsize,
  input  [17:0] s_axi_gp2_aruser,
  input  s_axi_gp2_arvalid,
  input  [48:0] s_axi_gp2_awaddr,
  input  [1:0] s_axi_gp2_awburst,
  input  [3:0] s_axi_gp2_awcache,
  input  [5:0] s_axi_gp2_awid,
  input  [7:0] s_axi_gp2_awlen,
  input  s_axi_gp2_awlock,
  input  [2:0] s_axi_gp2_awprot,
  input  [3:0] s_axi_gp2_awqos,
  input  [2:0] s_axi_gp2_awsize,
  input  [17:0] s_axi_gp2_awuser,
  input  s_axi_gp2_awvalid,
  input  s_axi_gp2_bready,
  input  s_axi_gp2_rclk,
  input  s_axi_gp2_rready,
  input  s_axi_gp2_wclk,
  input  [C_S_AXI_GP2_DATA_WIDTH-1:0] s_axi_gp2_wdata,
  input  s_axi_gp2_wlast,
  input  [((C_S_AXI_GP2_DATA_WIDTH/8)-1):0] s_axi_gp2_wstrb,
  input  s_axi_gp2_wvalid,
  input  s_axi_gp2_aclk,

  output  s_cci_fpd_arready,
  output  s_cci_fpd_awready,
  output [5:0] s_cci_fpd_bid,
  output [1:0] s_cci_fpd_bresp,
  output  s_cci_fpd_bvalid,
  output [3:0] s_cci_fpd_racount,
  output [7:0] s_cci_fpd_rcount,
  output [C_S_AXI_GP2_DATA_WIDTH-1:0] s_cci_fpd_rdata,
  output [5:0] s_cci_fpd_rid,
  output  s_cci_fpd_rlast,
  output [1:0] s_cci_fpd_rresp,
  output  s_cci_fpd_rvalid,
  output [3:0] s_cci_fpd_wacount,
  output [7:0] s_cci_fpd_wcount,
  output  s_cci_fpd_wready,

  input  [48:0] s_cci_fpd_araddr,
  input  [1:0] s_cci_fpd_arburst,
  input  [3:0] s_cci_fpd_arcache,
  input  [5:0] s_cci_fpd_arid,
  input  [7:0] s_cci_fpd_arlen,
  input  s_cci_fpd_arlock,
  input  [2:0] s_cci_fpd_arprot,
  input  [3:0] s_cci_fpd_arqos,
  input  [2:0] s_cci_fpd_arsize,
  input  [9:0]   s_cci_fpd_aruser,
  input  s_cci_fpd_arvalid,
  input  [48:0] s_cci_fpd_awaddr,
  input  [1:0] s_cci_fpd_awburst,
  input  [3:0] s_cci_fpd_awcache,
  input  [5:0] s_cci_fpd_awid,
  input  [7:0] s_cci_fpd_awlen,
  input  s_cci_fpd_awlock,
  input  [2:0] s_cci_fpd_awprot,
  input  [3:0] s_cci_fpd_awqos,
  input  [2:0] s_cci_fpd_awsize,
  input  [9:0]   s_cci_fpd_awuser,
  input  s_cci_fpd_awvalid,
  input  s_cci_fpd_bready,
  input  s_cci_fpd_rclk,
  input  s_cci_fpd_rready,
  input  s_cci_fpd_wclk,
  input  [C_S_AXI_GP2_DATA_WIDTH-1:0] s_cci_fpd_wdata,
  input  s_cci_fpd_wlast,
  input  [((C_S_AXI_GP2_DATA_WIDTH/8)-1):0] s_cci_fpd_wstrb,
  input  s_cci_fpd_wvalid,
  input  s_cci_fpd_aclk,
  input  [1:0] s_cci_fpd_ardomain,
  input  [3:0] s_cci_fpd_arsnoop,
  input  [9:0] s_cci_fpd_smid,
  input  [1:0] s_cci_fpd_awdomain,
  input  [2:0 ] s_cci_fpd_awsnoop,
  input  [48:0] s_axi_lpd_araddr,
  input  [1:0] s_axi_lpd_arburst,
  input  [3:0] s_axi_lpd_arcache,
  input  [5:0] s_axi_lpd_arid,
  input  [7:0] s_axi_lpd_arlen,
  input  s_axi_lpd_arlock,
  input  [2:0] s_axi_lpd_arprot,
  input  [3:0] s_axi_lpd_arqos,
  input  [2:0] s_axi_lpd_arsize,
  input  [9:0]   s_axi_lpd_aruser,
  input  s_axi_lpd_arvalid,
  input  [48:0] s_axi_lpd_awaddr,
  input  [1:0] s_axi_lpd_awburst,
  input  [3:0] s_axi_lpd_awcache,
  input  [5:0] s_axi_lpd_awid,
  input  [7:0] s_axi_lpd_awlen,
  input  s_axi_lpd_awlock,
  input  [2:0] s_axi_lpd_awprot,
  input  [3:0] s_axi_lpd_awqos,
  input  [2:0] s_axi_lpd_awsize,
  input  [9:0]   s_axi_lpd_awuser,
  input  s_axi_lpd_awvalid,
  input  s_axi_lpd_bready,
  input  s_axi_lpd_rclk,
  input  s_axi_lpd_rready,
  input  s_axi_lpd_wclk,
  input  [C_S_AXI_GP4_DATA_WIDTH-1:0] s_axi_lpd_wdata,
  input  s_axi_lpd_wlast,
  input  [((C_S_AXI_GP4_DATA_WIDTH/8)-1):0] s_axi_lpd_wstrb,
  input  s_axi_lpd_wvalid,
  input  s_axi_lpd_aclk,
  //PMC_NOC ports below

  output [63:0] pmc_noc_axi0_araddr,
  output [1:0] pmc_noc_axi0_arburst,
  output [3:0] pmc_noc_axi0_arcache,
  output [15:0] pmc_noc_axi0_arid,
  output [7:0] pmc_noc_axi0_arlen,
  output [0:0] pmc_noc_axi0_arlock,
  output [2:0] pmc_noc_axi0_arprot,
  output [3:0] pmc_noc_axi0_arqos,
  output [3:0] pmc_noc_axi0_arregion,
  output [2:0] pmc_noc_axi0_arsize,
  output [17:0] pmc_noc_axi0_aruser,
  output pmc_noc_axi0_arvalid,
  output [63:0] pmc_noc_axi0_awaddr,
  output [1:0] pmc_noc_axi0_awburst,
  output [3:0] pmc_noc_axi0_awcache,
  output [15:0] pmc_noc_axi0_awid,
  output [7:0] pmc_noc_axi0_awlen,
  output [0:0] pmc_noc_axi0_awlock,
  output [2:0] pmc_noc_axi0_awprot,
  output [3:0] pmc_noc_axi0_awqos,
  output [3:0] pmc_noc_axi0_awregion,
  output [2:0] pmc_noc_axi0_awsize,
  output [17:0] pmc_noc_axi0_awuser,
  output pmc_noc_axi0_awvalid,
  output pmc_noc_axi0_bready,
  output pmc_noc_axi0_rready,
  output [127:0] pmc_noc_axi0_wdata,
  output [15:0] pmc_noc_axi0_wid,
  output pmc_noc_axi0_wlast,
  output [15:0] pmc_noc_axi0_wstrb,
  output [16:0] pmc_noc_axi0_wuser,
  output pmc_noc_axi0_wvalid,
  output pmc_axi_noc_axi0_clk,
  input pmc_noc_axi0_arready,
  input pmc_noc_axi0_awready,
  input  [15:0] pmc_noc_axi0_bid,
  input  [1:0] pmc_noc_axi0_bresp,
  input  [15:0] pmc_noc_axi0_buser,
  input pmc_noc_axi0_bvalid,
  input  [127:0] pmc_noc_axi0_rdata,
  input  [15:0] pmc_noc_axi0_rid,
  input  [0:0] pmc_noc_axi0_rlast,
  input  [1:0] pmc_noc_axi0_rresp,
  input  [16:0] pmc_noc_axi0_ruser,
  input pmc_noc_axi0_rvalid,
  input pmc_noc_axi0_wready,
  // PMC_NOC ports above
  
  // NOC_pmc ports below
  output        noc_pmc_axi0_arready,
  output        noc_pmc_axi0_awready,
  output [1:0]  noc_pmc_axi0_bid,
  output [1:0]  noc_pmc_axi0_bresp,
  output [15:0] noc_pmc_axi0_buser,
  output        noc_pmc_axi0_bvalid,
  output [127:0] noc_pmc_axi0_rdata,
  output [1:0] noc_pmc_axi0_rid,
  output [0:0] noc_pmc_axi0_rlast,
  output [1:0] noc_pmc_axi0_rresp,
  output [16:0] noc_pmc_axi0_ruser,
  output noc_pmc_axi0_rvalid,
  output noc_pmc_axi0_wready,
  output noc_pmc_axi_axi0_clk,
  input  [63:0] noc_pmc_axi0_araddr,
  input  [1:0] noc_pmc_axi0_arburst,
  input  [3:0] noc_pmc_axi0_arcache,
  input  [1:0] noc_pmc_axi0_arid,
  input  [7:0] noc_pmc_axi0_arlen,
  input  [0:0] noc_pmc_axi0_arlock,
  input  [2:0] noc_pmc_axi0_arprot,
  input  [3:0] noc_pmc_axi0_arqos,
  input  [3:0] noc_pmc_axi0_arregion,
  input  [2:0] noc_pmc_axi0_arsize,
  input  [17:0] noc_pmc_axi0_aruser,
  input noc_pmc_axi0_arvalid,
  input  [63:0] noc_pmc_axi0_awaddr,
  input  [1:0] noc_pmc_axi0_awburst,
  input  [3:0] noc_pmc_axi0_awcache,
  input  [1:0] noc_pmc_axi0_awid,
  input  [7:0] noc_pmc_axi0_awlen,
  input  [0:0] noc_pmc_axi0_awlock,
  input  [2:0] noc_pmc_axi0_awprot,
  input  [3:0] noc_pmc_axi0_awqos,
  input  [3:0] noc_pmc_axi0_awregion,
  input  [2:0] noc_pmc_axi0_awsize,
  input  [17:0] noc_pmc_axi0_awuser,
  input noc_pmc_axi0_awvalid,
  input noc_pmc_axi0_bready,
  input noc_pmc_axi0_rready,
  input  [127:0] noc_pmc_axi0_wdata,
  input  [3:0] noc_pmc_axi0_wid,
  input noc_pmc_axi0_wlast,
  input  [15:0] noc_pmc_axi0_wstrb,
  input  [16:0] noc_pmc_axi0_wuser,
  input noc_pmc_axi0_wvalid,
  //NOC_PMC ports above


  input  [59:0] stm_event,

  //BSCAN0 ports
  output  bscan_user1_usr_capture,
  output  bscan_user1_usr_drck,
  output  bscan_user1_usr_reset,
  output  bscan_user1_usr_runtest,
  output  bscan_user1_usr_sel,
  output  bscan_user1_usr_shift,
  output  bscan_user1_usr_tck,
  output  bscan_user1_usr_tdi,
  output  bscan_user1_usr_tms,
  output  bscan_user1_usr_update,
  input   bscan_user1_usr_tdo,

  //BSCAN1 ports
  output  bscan_user2_usr_capture,
  output  bscan_user2_usr_drck,
  output  bscan_user2_usr_reset,
  output  bscan_user2_usr_runtest,
  output  bscan_user2_usr_sel,
  output  bscan_user2_usr_shift,
  output  bscan_user2_usr_tck,
  output  bscan_user2_usr_tdi,
  output  bscan_user2_usr_tms,
  output  bscan_user2_usr_update,
  input   bscan_user2_usr_tdo,

  //BSCAN2 ports
  output  bscan_user3_usr_capture,
  output  bscan_user3_usr_drck,
  output  bscan_user3_usr_reset,
  output  bscan_user3_usr_runtest,
  output  bscan_user3_usr_sel,
  output  bscan_user3_usr_shift,
  output  bscan_user3_usr_tck,
  output  bscan_user3_usr_tdi,
  output  bscan_user3_usr_tms,
  output  bscan_user3_usr_update,
  input   bscan_user3_usr_tdo,

  //BSCAN3 ports
  output  bscan_user4_usr_capture,
  output  bscan_user4_usr_drck,
  output  bscan_user4_usr_reset,
  output  bscan_user4_usr_runtest,
  output  bscan_user4_usr_sel,
  output  bscan_user4_usr_shift,
  output  bscan_user4_usr_tck,
  output  bscan_user4_usr_tdi,
  output  bscan_user4_usr_tms,
  output  bscan_user4_usr_update,
  input   bscan_user4_usr_tdo,

  output [63:0] s_axis_hsdp_egress_tdata,
  output [7:0]  s_axis_hsdp_egress_tkeep,
  output        s_axis_hsdp_egress_tlast,
  output [11:0] s_axis_hsdp_egress_tuser,
  output        s_axis_hsdp_egress_tvalid,
  output        s_axis_hsdp_ingress_tready,

  input hsdp_ref_clk,

  input         s_axis_hsdp_egress_tready,
  input  [63:0] s_axis_hsdp_ingress_tdata,
  input  [7:0]  s_axis_hsdp_ingress_tkeep,
  input         s_axis_hsdp_ingress_tlast,
  input         s_axis_hsdp_ingress_tvalid,

  output pl0_resetn,
  output pl1_resetn,
  output pl2_resetn,
  output pl3_resetn,

  input  [C_SPP_PSPMC_FROM_CORE_WIDTH-1:0] ps_pmc_from_core,
  output [C_SPP_PSPMC_TO_CORE_WIDTH-1:0]   ps_pmc_to_core,

  output [127:0] dbg0,
  output [15:0]  dbg0_ext,
  output [127:0] dbg1,
  output [15:0]  dbg1_ext,
  output [127:0] dbg2,
  output [15:0]  dbg2_ext,
  output [127:0] dbg3,
  output [15:0]  dbg3_ext,
  output [127:0] dbg4,
  output [15:0]  dbg4_ext,
  input  [31:0]  dbg_sel,

  // Start up and Capture ports
  output   eos,
  input    usrgsrb,
  input    usrgtsb,
  input    captureb,
  input    captureclk,

  //SMMU ports
  input         m_smmu_arready,
  input         m_smmu_awready,
  input         m_smmu_bready,
  input         m_smmu_rready,
  output [47:0] m_smmu_araddr,
  output [3:0]  m_smmu_arcache,
  output [7:0]  m_smmu_arid,
  output        m_smmu_arvalid,
  output [47:0] m_smmu_awaddr,
  output [3:0]  m_smmu_awcache,
  output [7:0]  m_smmu_awid,
  output        m_smmu_awvalid,
  output [7:0]  m_smmu_bid,
  output [1:0]  m_smmu_bresp,
  output        m_smmu_bvalid,
  output        m_smmu_rerr,
  output [7:0]  m_smmu_rid,
  output        m_smmu_rns,
  output [1:0]  m_smmu_rresp,
  output        m_smmu_rvalid,
  output        m_smmu_werr,
  output        m_smmu_wns,

  output pl_ref_clk_mux_monitor,

  output        s_smmu_arready,
  output        s_smmu_awready,
  output        s_smmu_comprdready,
  output        s_smmu_compwrready,
  input  [48:0] s_smmu_araddr,
  input  [3:0]  s_smmu_arcache,
  input  [7:0]  s_smmu_arid,
  input         s_smmu_arvalid,
  input  [48:0] s_smmu_awaddr,
  input  [3:0]  s_smmu_awcache,
  input  [7:0]  s_smmu_awid,
  input         s_smmu_awvalid,
  input         smmu_ref_clk,
  input  [7:0]  s_smmu_comprdid,
  input         s_smmu_comprdval,
  input  [7:0]  s_smmu_compwrid,
  input         s_smmu_compwrval,
  input         s_smmu_rns,
  input  [9:0]  s_smmu_rsmid,
  input         s_smmu_wns,
  input  [9:0]  s_smmu_wsmid,

//  output mjtag_tdo,
//  input  mjtag_tck,
//  input  mjtag_tdi,
//  input  mjtag_tms,

  //SYSMON ports
  output pmc_pl_sysmon_i2c_scl_trib,
  output pmc_pl_sysmon_i2c_sda_trib,
  output pmc_pl_sysmon_i2c_smb_alert_trib,
  input  pmc_pl_sysmon_i2c_scl_input,
  input  pmc_pl_sysmon_i2c_sda_input,

  output [9:0] pmc_pl_sysmon_root_alarm,
  output [3:0] pmc_pl_sysmon_root_new_data,

  // CPM ports
  output cpmdpllpcie0userclk,
  output cpmdpllpcie1userclk,

  output        ifextplpcie0cfghpocfgccixedrdataratechangereq,
  output [1:0]  ifextplpcie0cfghpocfgcurrentspeed,
  output        ifextplpcie0cfghpocfgedrenable,
  output        ifextplpcie0cfghpocfgerrcorout,
  output        ifextplpcie0cfghpocfgerrfatalout,
  output        ifextplpcie0cfghpocfgerrnonfatalout,
  output [7:0]  ifextplpcie0cfghpocfgextfunctionnumber,
  output        ifextplpcie0cfghpocfgextreadreceived,
  output [9:0]  ifextplpcie0cfghpocfgextregisternumber,
  output [3:0]  ifextplpcie0cfghpocfgextwritebyteenable,
  output [31:0] ifextplpcie0cfghpocfgextwritedata,
  output        ifextplpcie0cfghpocfgextwritereceived,
  output [11:0] ifextplpcie0cfghpocfgfcnpd,
  output [1:0]  ifextplpcie0cfghpocfgfcnpdscale,
  output [7:0]  ifextplpcie0cfghpocfgfcnph,
  output [1:0]  ifextplpcie0cfghpocfgfcnphscale,
  output [11:0] ifextplpcie0cfghpocfgfcpd,
  output [1:0]  ifextplpcie0cfghpocfgfcpdscale,
  output [7:0]  ifextplpcie0cfghpocfgfcph,
  output [1:0]  ifextplpcie0cfghpocfgfcphscale,
  output        ifextplpcie0cfghpocfghotresetout,
  output        ifextplpcie0cfghpocfginterruptsent,
  output [1:0]  ifextplpcie0cfghpocfglinkpowerstate,
  output [4:0]  ifextplpcie0cfghpocfglocalerrorout,
  output        ifextplpcie0cfghpocfglocalerrorvalid,
  output [5:0]  ifextplpcie0cfghpocfgltssmstate,
  output [31:0] ifextplpcie0cfghpocfgmgmtreaddata,
  output        ifextplpcie0cfghpocfgmgmtreadwritedone,
  output [2:0]  ifextplpcie0cfghpocfgnegotiatedwidth,
  output [3:0]  ifextplpcie0cfghpocfgpasidenable,
  output [3:0]  ifextplpcie0cfghpocfgpasidexecpermissionenable,
  output [3:0]  ifextplpcie0cfghpocfgpasidprivilmodeenable,
  output        ifextplpcie0cfghpocfgphylinkdown,
  output [1:0]  ifextplpcie0cfghpocfgphylinkstatus,
  output        ifextplpcie0cfghpocfgplstatuschange,
  output        ifextplpcie0cfghpocfgpowerstatechangeinterrupt,
  output [1:0]  ifextplpcie0cfghpocfgrxpmstate,
  output [1:0]  ifextplpcie0cfghpocfgtxpmstate,
  output [3:0]  ifextplpcie0cfglpocfg10btagrequesterenable,
  output [3:0]  ifextplpcie0cfglpocfgatomicrequesterenable,
  output        ifextplpcie0cfglpocfgexttagenable,
  output [11:0] ifextplpcie0cfglpocfgfccpld,
  output [1:0]  ifextplpcie0cfglpocfgfccpldscale,
  output [7:0]  ifextplpcie0cfglpocfgfccplh,
  output [1:0]  ifextplpcie0cfglpocfgfccplhscale,
  output [3:0]  ifextplpcie0cfglpocfgflrinprocess,
  output [11:0] ifextplpcie0cfglpocfgfunctionpowerstate,
  output [15:0] ifextplpcie0cfglpocfgfunctionstatus,
  output [31:0] ifextplpcie0cfglpocfginterruptmsidata,
  output [3:0]  ifextplpcie0cfglpocfginterruptmsienable,
  output        ifextplpcie0cfglpocfginterruptmsifail,
  output        extplpcie0cfglpocfginterruptmsifail, //msix
  output        ifextplpcie0cfglpocfginterruptmsimaskupdate,
  output [11:0] ifextplpcie0cfglpocfginterruptmsimmenable,
  output        ifextplpcie0cfglpocfginterruptmsisent,
  output        extplpcie0cfglpocfginterruptmsisent, //msix
  output [3:0]  ifextplpcie0cfglpocfginterruptmsixenable,
  output [3:0]  ifextplpcie0cfglpocfginterruptmsixmask,
  output        ifextplpcie0cfglpocfginterruptmsixvecpendingstatus,
  output [1:0]  ifextplpcie0cfglpocfgmaxpayload,
  output [2:0]  ifextplpcie0cfglpocfgmaxreadreq,
  output        ifextplpcie0cfglpocfgmsgreceived,
  output [7:0]  ifextplpcie0cfglpocfgmsgreceiveddata,
  output [4:0]  ifextplpcie0cfglpocfgmsgreceivedtype,
  output        ifextplpcie0cfglpocfgmsgtransmitdone,
  output [3:0]  ifextplpcie0cfglpocfgrcbstatus,
  output [3:0]  ifextplpcie0cfglpocfgtphrequesterenable,
  output [11:0] ifextplpcie0cfglpocfgtphstmode,
  output        ifextplpcie0cfglpocfgvc1enable,
  output        ifextplpcie0cfglpocfgvc1negotiationpending,

  output ifcpmplisrcorrevent,
  output ifcpmplisrmiscevent,
  output ifcpmplisruncorrevent,
  output ifcpmpciea1cfglpocfgmsgtransmitdone,

  output [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1:0]   ifpcie0plrcaxisaxisrctdata,
  output [15:0]   ifpcie0plrcaxisaxisrctkeep,
  output [160:0]  ifpcie0plrcaxisaxisrctuser,
  output          ifpcie0plrcaxisaxisrctlast,
  output          ifpcie0plrcaxisaxisrctvalid,
  input           ifpcie0plrcaxisaxisrctready,

  output [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1:0]   ifpcie0plcqaxisaxiscqtdata,
  output [15:0]   ifpcie0plcqaxisaxiscqtkeep,
  output [228:0]  ifpcie0plcqaxisaxiscqtuser,
  output          ifpcie0plcqaxisaxiscqtlast,
  output          ifpcie0plcqaxisaxiscqtvalid,
  input           ifpcie0plcqaxisaxiscqtready,

  output [C_CPM_PCIE1_AXISTEN_IF_WIDTH-1:0]   ifpcie1plrcaxisaxisrctdata,
  output [15:0]   ifpcie1plrcaxisaxisrctkeep,
  output [160:0]  ifpcie1plrcaxisaxisrctuser,
  output          ifpcie1plrcaxisaxisrctlast,
  output          ifpcie1plrcaxisaxisrctvalid,
  input           ifpcie1plrcaxisaxisrctready,

  output [C_CPM_PCIE1_AXISTEN_IF_WIDTH-1:0]   ifpcie1plcqaxisaxiscqtdata,
  output [15:0]   ifpcie1plcqaxisaxiscqtkeep,
  output [228:0]  ifpcie1plcqaxisaxiscqtuser,
  output          ifpcie1plcqaxisaxiscqtlast,
  output          ifpcie1plcqaxisaxiscqtvalid,
  input           ifpcie1plcqaxisaxiscqtready,

//Output ports from soft logic
  output xdma_reset_n,
  input  dma_soft_resetn,

  output [252-1:0]   cfg_vf_flr_in_process0,
  output [2*252-1:0] cfg_vf_status0,
  output [3*252-1:0] cfg_vf_power_state0,
  output [252-1:0]   cfg_vf_tph_requester_enable0,
  output [3*252-1:0] cfg_vf_tph_st_mode0,
  output [252-1:0]   cfg_interrupt_msix_vf_enable0,
  output [252-1:0]   cfg_interrupt_msix_vf_mask0,

  output [2*4-1:0]   cfg_pri_control0,
  output [4-1:0]     cfg_ats_control_enable0,
  output [252-1:0]   cfg_vf_ats_control_enable0,
  output [3*4-1:0]   cfg_pasid_control0,
  output [5*4-1:0]   cfg_max_pasid_width_control0,


  output [252-1:0]   cfg_vf_flr_in_process1,
  output [2*252-1:0] cfg_vf_status1,
  output [3*252-1:0] cfg_vf_power_state1,
  output [252-1:0]   cfg_vf_tph_requester_enable1,
  output [3*252-1:0] cfg_vf_tph_st_mode1,
  output [252-1:0]   cfg_interrupt_msix_vf_enable1,
  output [252-1:0]   cfg_interrupt_msix_vf_mask1,

  output [2*4-1:0]   cfg_pri_control1,
  output [4-1:0]     cfg_ats_control_enable1,
  output [252-1:0]   cfg_vf_ats_control_enable1,
  output [3*4-1:0]   cfg_pasid_control1,
  output [5*4-1:0]   cfg_max_pasid_width_control1,

  input  [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0] s_axis_c2h_tdata_0,
  input          s_axis_c2h_tlast_0,
  input          s_axis_c2h_tvalid_0,
  output         s_axis_c2h_tready_0,
  input  [63:0]  s_axis_c2h_tkeep_0,
  input  [63:0]  s_axis_c2h_tuser_0,

  output [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0] m_axis_h2c_tdata_0,
  output        m_axis_h2c_tlast_0,
  output        m_axis_h2c_tvalid_0,
  input         m_axis_h2c_tready_0,
  output [63:0] m_axis_h2c_tkeep_0,
  output [63:0] m_axis_h2c_tuser_0,

  input  [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0]  s_axis_c2h_tdata_1,
  input         s_axis_c2h_tlast_1,
  input         s_axis_c2h_tvalid_1,
  output        s_axis_c2h_tready_1,
  input  [63:0] s_axis_c2h_tkeep_1,
  input  [63:0] s_axis_c2h_tuser_1,

  output [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0] m_axis_h2c_tdata_1,
  output        m_axis_h2c_tlast_1,
  output        m_axis_h2c_tvalid_1,
  input         m_axis_h2c_tready_1,
  output [63:0] m_axis_h2c_tkeep_1,
  output [63:0] m_axis_h2c_tuser_1,

  input  [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0]  s_axis_c2h_tdata_2,
  input         s_axis_c2h_tlast_2,
  input         s_axis_c2h_tvalid_2,
  output        s_axis_c2h_tready_2,
  input  [63:0] s_axis_c2h_tkeep_2,
  input  [63:0] s_axis_c2h_tuser_2,

  output [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0] m_axis_h2c_tdata_2,
  output        m_axis_h2c_tlast_2,
  output        m_axis_h2c_tvalid_2,
  input         m_axis_h2c_tready_2,
  output [63:0] m_axis_h2c_tkeep_2,
  output [63:0] m_axis_h2c_tuser_2,

  input  [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0] s_axis_c2h_tdata_3,
  input          s_axis_c2h_tlast_3,
  input          s_axis_c2h_tvalid_3,
  output         s_axis_c2h_tready_3,
  input  [63:0]  s_axis_c2h_tkeep_3,
  input  [63:0]  s_axis_c2h_tuser_3,

  output [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0] m_axis_h2c_tdata_3,
  output        m_axis_h2c_tlast_3,
  output        m_axis_h2c_tvalid_3,
  input         m_axis_h2c_tready_3,
  output [63:0] m_axis_h2c_tkeep_3,
  output [63:0] m_axis_h2c_tuser_3,

  output        c2h_dsc_byp_ready_0,
  input  [63:0] c2h_dsc_byp_src_addr_0,
  input  [63:0] c2h_dsc_byp_dst_addr_0,
  input  [27:0] c2h_dsc_byp_len_0,
  input  [15:0] c2h_dsc_byp_ctl_0,
  input         c2h_dsc_byp_load_0,

  output        c2h_dsc_byp_ready_1,
  input  [63:0] c2h_dsc_byp_src_addr_1,
  input  [63:0] c2h_dsc_byp_dst_addr_1,
  input  [27:0] c2h_dsc_byp_len_1,
  input  [15:0] c2h_dsc_byp_ctl_1,
  input         c2h_dsc_byp_load_1,

  output        c2h_dsc_byp_ready_2,
  input  [63:0] c2h_dsc_byp_src_addr_2,
  input  [63:0] c2h_dsc_byp_dst_addr_2,
  input  [27:0] c2h_dsc_byp_len_2,
  input  [15:0] c2h_dsc_byp_ctl_2,
  input         c2h_dsc_byp_load_2,

  output        c2h_dsc_byp_ready_3,
  input  [63:0] c2h_dsc_byp_src_addr_3,
  input  [63:0] c2h_dsc_byp_dst_addr_3,
  input  [27:0] c2h_dsc_byp_len_3,
  input  [15:0] c2h_dsc_byp_ctl_3,
  input         c2h_dsc_byp_load_3,

  output        h2c_dsc_byp_ready_0,
  input  [63:0] h2c_dsc_byp_src_addr_0,
  input  [63:0] h2c_dsc_byp_dst_addr_0,
  input  [27:0] h2c_dsc_byp_len_0,
  input  [15:0] h2c_dsc_byp_ctl_0,
  input         h2c_dsc_byp_load_0,

  output        h2c_dsc_byp_ready_1,
  input  [63:0] h2c_dsc_byp_src_addr_1,
  input  [63:0] h2c_dsc_byp_dst_addr_1,
  input  [27:0] h2c_dsc_byp_len_1,
  input  [15:0] h2c_dsc_byp_ctl_1,
  input         h2c_dsc_byp_load_1,

  output        h2c_dsc_byp_ready_2,
  input  [63:0] h2c_dsc_byp_src_addr_2,
  input  [63:0] h2c_dsc_byp_dst_addr_2,
  input  [27:0] h2c_dsc_byp_len_2,
  input  [15:0] h2c_dsc_byp_ctl_2,
  input         h2c_dsc_byp_load_2,

  output        h2c_dsc_byp_ready_3,
  input  [63:0] h2c_dsc_byp_src_addr_3,
  input  [63:0] h2c_dsc_byp_dst_addr_3,
  input  [27:0] h2c_dsc_byp_len_3,
  input  [15:0] h2c_dsc_byp_ctl_3,
  input         h2c_dsc_byp_load_3,

  input  [C_CPM_PCIE0_NUM_USR_IRQ-1 : 0] usr_irq_req, // where c_cpm_pcie0_num_usr_irq is 1:16
  output [C_CPM_PCIE0_NUM_USR_IRQ-1 : 0] usr_irq_ack, // where c_cpm_pcie0_num_usr_irq is 1:16

  input  [7:0] usr_irq_function_number,

  output [7:0] c2h_sts_0,
  output [7:0] h2c_sts_0,

  // Status Channel 1
  output [7:0] c2h_sts_1,
  output [7:0] h2c_sts_1,
  // Status Channel 2
  output [7:0] c2h_sts_2,
  output [7:0] h2c_sts_2,

  // Status Channel 3
  output [7:0] c2h_sts_3,
  output [7:0] h2c_sts_3,

  input  [7:0] flr_in_fnc,
  input        flr_in_vld,
  output [7:0] flr_out_fnc,
  output       flr_out_set,
  output       flr_out_clr,

  output xdma_dma_irq_out ,

  input         mgmt_req_vld,
  input  [31:0] mgmt_req_dat,
  input  [31:0] mgmt_req_adr,
  input  [7:0]  mgmt_req_fnc,
  input  [5:0]  mgmt_req_msc,
  input  [1:0]  mgmt_req_cmd,
  output        mgmt_req_rdy,

  output        mgmt_cpl_vld,
  output [1:0]  mgmt_cpl_sts,
  output [31:0] mgmt_cpl_dat,
  input         mgmt_cpl_rdy,

  // VDM
  input         xdma_st_rx_msg_rdy,
  output [31:0] xdma_st_rx_msg_data,
  output        xdma_st_rx_msg_valid,
  output        xdma_st_rx_msg_last,

  input  pl_gen34_redo_equalization_i_0,
  input  pl_gen34_redo_eq_speed_i_0,
  input  pl_gen34_eq_mismatch_i_0,

  output pl_eq_mismatch_o_0,
  output pl_redo_eq_pending_o_0,
  output pl_gen34_redo_equalization_o_0,
  output pl_gen34_redo_eq_speed_o_0,

  input  pl_gen34_redo_equalization_i_1,
  input  pl_gen34_redo_eq_speed_i_1,
  input  pl_gen34_eq_mismatch_i_1,

  output pl_eq_mismatch_o_1,
  output pl_redo_eq_pending_o_1,
  output pl_gen34_redo_equalization_o_1,
  output pl_gen34_redo_eq_speed_o_1,

  output user_reset0,
  output user_lnk_up0,
  output user_reset1,
  output user_lnk_up1,

  output [1:0]  pcie1_cfg_max_payload,
  output [2:0]  pcie1_cfg_max_read_req,
  output        pcie1_cfg_ext_tag_enable,
  output [3:0]  pcie1_cfg_flr_in_process,
  output [15:0] pcie1_cfg_function_status,
  output [3:0]  pcie1_cfg_rcb_status,
  output [3:0]  pcie1_cfg_tag_10b_requester_enable,
  output [3:0]  pcie1_cfg_tph_requester_enable,
  output [11:0] pcie1_cfg_tph_st_mode,
  output [3:0]  pcie1_cfg_msi_enable,
  output [11:0] pcie1_cfg_msi_mmenable,
  output [31:0] pcie1_cfg_msi_data,
  output [3:0]  pcie1_cfg_msix_enable,
  output [3:0]  pcie1_cfg_msix_mask,

// Additional ports from soft logic ends

  output        ifextplpcie1cfghpocfgccixedrdataratechangereq,
  output [1:0]  ifextplpcie1cfghpocfgcurrentspeed,
  output        ifextplpcie1cfghpocfgedrenable,
  output        ifextplpcie1cfghpocfgerrcorout,
  output        ifextplpcie1cfghpocfgerrfatalout,
  output        ifextplpcie1cfghpocfgerrnonfatalout,
  output [7:0]  ifextplpcie1cfghpocfgextfunctionnumber,
  output        ifextplpcie1cfghpocfgextreadreceived,
  output [9:0]  ifextplpcie1cfghpocfgextregisternumber,
  output [3:0]  ifextplpcie1cfghpocfgextwritebyteenable,
  output [31:0] ifextplpcie1cfghpocfgextwritedata,
  output        ifextplpcie1cfghpocfgextwritereceived,
  output [11:0] ifextplpcie1cfghpocfgfcnpd,
  output [1:0]  ifextplpcie1cfghpocfgfcnpdscale,
  output [7:0]  ifextplpcie1cfghpocfgfcnph,
  output [1:0]  ifextplpcie1cfghpocfgfcnphscale,
  output [11:0] ifextplpcie1cfghpocfgfcpd,
  output [1:0]  ifextplpcie1cfghpocfgfcpdscale,
  output [7:0]  ifextplpcie1cfghpocfgfcph,
  output [1:0]  ifextplpcie1cfghpocfgfcphscale,
  output        ifextplpcie1cfghpocfghotresetout,
  output        ifextplpcie1cfghpocfginterruptsent,
  output [1:0]  ifextplpcie1cfghpocfglinkpowerstate,
  output [4:0]  ifextplpcie1cfghpocfglocalerrorout,
  output        ifextplpcie1cfghpocfglocalerrorvalid,
  output [5:0]  ifextplpcie1cfghpocfgltssmstate,
  output [31:0] ifextplpcie1cfghpocfgmgmtreaddata,
  output        ifextplpcie1cfghpocfgmgmtreadwritedone,
  output [2:0]  ifextplpcie1cfghpocfgnegotiatedwidth,
  output [3:0]  ifextplpcie1cfghpocfgpasidenable,
  output [3:0]  ifextplpcie1cfghpocfgpasidexecpermissionenable,
  output [3:0]  ifextplpcie1cfghpocfgpasidprivilmodeenable,
  output        ifextplpcie1cfghpocfgphylinkdown,
  output [1:0]  ifextplpcie1cfghpocfgphylinkstatus,
  output        ifextplpcie1cfghpocfgplstatuschange,
  output        ifextplpcie1cfghpocfgpowerstatechangeinterrupt,
  output [1:0]  ifextplpcie1cfghpocfgrxpmstate,
  output [1:0]  ifextplpcie1cfghpocfgtxpmstate,

  output        ifpcie0plccaxisaxiscctready,
  output        ifpcie0plrqaxisaxisrqtready,
  output        ifpcie1plccaxisaxiscctready,
  output        ifpcie1plrqaxisaxisrqtready,
  output [50:0] ifplcpmp0chicrspflit,
  output        ifplcpmp0chicrspflitpend,
  output        ifplcpmp0chicrspflitv,
  output        ifplcpmp0chimlinkactiveack,
  output [704:0] ifplcpmp0chirdatflit,
  output        ifplcpmp0chirdatflitpend,
  output        ifplcpmp0chirdatflitv,
  output        ifplcpmp0chireqlcrdv,
  output        ifplcpmp0chislinkactivereq,
  output [87:0] ifplcpmp0chisnpflit,
  output        ifplcpmp0chisnpflitpend,
  output        ifplcpmp0chisnpflitv,
  output        ifplcpmp0chisrsplcrdv,
  output        ifplcpmp0chissactive,
  output        ifplcpmp0chisyscoack,
  output        ifplcpmp0chiwdatlcrdv,
  output [50:0] ifplcpmp1chicrspflit,
  output        ifplcpmp1chicrspflitpend,
  output        ifplcpmp1chicrspflitv,
  output        ifplcpmp1chimlinkactiveack,
  output [704:0]ifplcpmp1chirdatflit,
  output        ifplcpmp1chirdatflitpend,
  output        ifplcpmp1chirdatflitv,
  output        ifplcpmp1chireqlcrdv,
  output        ifplcpmp1chislinkactivereq,
  output [87:0] ifplcpmp1chisnpflit,
  output        ifplcpmp1chisnpflitpend,
  output        ifplcpmp1chisnpflitv,
  output        ifplcpmp1chisrsplcrdv,
  output        ifplcpmp1chissactive,
  output        ifplcpmp1chisyscoack,
  output        ifplcpmp1chiwdatlcrdv,
  output [5:0]  ifplextpcie0axipciecqnpreqcount,
  output [5:0]  ifplextpcie0axipcierqseqnum0,
  output [5:0]  ifplextpcie0axipcierqseqnum1,
  output        ifplextpcie0axipcierqseqnumvld0,
  output        ifplextpcie0axipcierqseqnumvld1,
  output [9:0]  ifplextpcie0axipcierqtag0,
  output [9:0]  ifplextpcie0axipcierqtag1,
  output [3:0]  ifplextpcie0axipcierqtagav,
  output        ifplextpcie0axipcierqtagvld0,
  output        ifplextpcie0axipcierqtagvld1,
  output [3:0]  ifplextpcie0axipcietfcnpdav,
  output [3:0]  ifplextpcie0axipcietfcnphav,
  output [5:0]  ifplextpcie1axipciecqnpreqcount,
  output [5:0]  ifplextpcie1axipcierqseqnum0,
  output [5:0]  ifplextpcie1axipcierqseqnum1,
  output        ifplextpcie1axipcierqseqnumvld0,
  output        ifplextpcie1axipcierqseqnumvld1,
  output [9:0]  ifplextpcie1axipcierqtag0,
  output [9:0]  ifplextpcie1axipcierqtag1,
  output [3:0]  ifplextpcie1axipcierqtagav,
  output        ifplextpcie1axipcierqtagvld0,
  output        ifplextpcie1axipcierqtagvld1,
  output [3:0]  ifplextpcie1axipcietfcnpdav,
  output [3:0]  ifplextpcie1axipcietfcnphav,
  input         ifcpmpciea0cfghpicfgccixedrdataratechangeack,
  input         ifcpmpciea0cfghpicfgerrcorin,
  input         ifcpmpciea0cfghpicfgerruncorin,
  input  [31:0] ifcpmpciea0cfghpicfgextreaddata,
  input         ifcpmpciea0cfghpicfgextreaddatavalid,
  input  [2:0]  ifcpmpciea0cfghpicfgfcsel,
  input         ifcpmpciea0cfghpicfgfcvcsel,
  input  [3:0]  ifcpmpciea0cfghpicfgflrdone,
  input         ifcpmpciea0cfghpicfghotresetin,
  input  [3:0]  ifcpmpciea0cfghpicfginterruptint,
  input  [2:0]  ifcpmpciea0cfghpicfginterruptmsiattr,
  input  [2:0]  cpmpciea0cfghpicfginterruptmsiattr, //msix
  input  [7:0]  ifcpmpciea0cfghpicfginterruptmsifunctionnumber,
  input  [7:0]  cpmpciea0cfghpicfginterruptmsifunctionnumber, //msix
  input  [31:0] ifcpmpciea0cfghpicfginterruptmsiint,
  input  [31:0] cpmpciea0cfghpicfginterruptmsiint, //msix
  input  [31:0] ifcpmpciea0cfghpicfginterruptmsipendingstatus,
  input         ifcpmpciea0cfghpicfginterruptmsipendingstatusdataenable,
  input  [1:0]  ifcpmpciea0cfghpicfginterruptmsipendingstatusfunctionnum,
  input  [1:0]  ifcpmpciea0cfghpicfginterruptmsiselect,
  input         ifcpmpciea0cfghpicfginterruptmsitphpresent,
  input         cpmpciea0cfghpicfginterruptmsitphpresent, //msix
  input  [7:0]  ifcpmpciea0cfghpicfginterruptmsitphsttag,
  input  [7:0]  cpmpciea0cfghpicfginterruptmsitphsttag, //msix
  input  [1:0]  ifcpmpciea0cfghpicfginterruptmsitphtype,
  input  [1:0]  cpmpciea0cfghpicfginterruptmsitphtype, //msix
  input  [63:0] ifcpmpciea0cfghpicfginterruptmsixaddress,
  input  [31:0] ifcpmpciea0cfghpicfginterruptmsixdata,
  input         ifcpmpciea0cfghpicfginterruptmsixint,
  input  [1:0]  ifcpmpciea0cfghpicfginterruptmsixvecpending,
  input  [3:0]  ifcpmpciea0cfghpicfginterruptpending,
  input  [9:0]  ifcpmpciea0cfghpicfgmgmtaddr,
  input  [3:0]  ifcpmpciea0cfghpicfgmgmtbyteenable,
  input         ifcpmpciea0cfghpicfgmgmtdebugaccess,
  input  [7:0]  ifcpmpciea0cfghpicfgmgmtfunctionnumber,
  input         ifcpmpciea0cfghpicfgmgmtread,
  input         ifcpmpciea0cfghpicfgmgmtwrite,
  input  [31:0] ifcpmpciea0cfghpicfgmgmtwritedata,
  input         ifcpmpciea0cfghpicfgmsgtransmit,
  input  [31:0] ifcpmpciea0cfghpicfgmsgtransmitdata,
  input  [2:0]  ifcpmpciea0cfghpicfgmsgtransmittype,
  input         ifcpmpciea0cfghpicfgpowerstatechangeack,
  input         ifcpmpciea0cfghpicfgvfflrdone,
  input  [7:0]  ifcpmpciea0cfghpicfgvfflrfuncnum,
  input         ifcpmpciea1cfghpicfgccixedrdataratechangeack,
  input         ifcpmpciea1cfghpicfgerrcorin,
  input         ifcpmpciea1cfghpicfgerruncorin,
  input  [31:0] ifcpmpciea1cfghpicfgextreaddata,
  input         ifcpmpciea1cfghpicfgextreaddatavalid,
  input  [2:0]  ifcpmpciea1cfghpicfgfcsel,
  input         ifcpmpciea1cfghpicfgfcvcsel,
  input  [3:0]  ifcpmpciea1cfghpicfgflrdone,
  input         ifcpmpciea1cfghpicfghotresetin,
  input  [3:0]  ifcpmpciea1cfghpicfginterruptint,
  input  [2:0]  ifcpmpciea1cfghpicfginterruptmsiattr,
  input  [2:0]  cpmpciea1cfghpicfginterruptmsiattr, //msix
  input  [7:0]  ifcpmpciea1cfghpicfginterruptmsifunctionnumber,
  input  [7:0]  cpmpciea1cfghpicfginterruptmsifunctionnumber, //msix
  input  [31:0] ifcpmpciea1cfghpicfginterruptmsiint,
  input  [31:0] cpmpciea1cfghpicfginterruptmsiint, //msix
  input  [31:0] ifcpmpciea1cfghpicfginterruptmsipendingstatus,
  input         ifcpmpciea1cfghpicfginterruptmsipendingstatusdataenable,
  input  [1:0]  ifcpmpciea1cfghpicfginterruptmsipendingstatusfunctionnum,
  input  [1:0]  ifcpmpciea1cfghpicfginterruptmsiselect,
  input         ifcpmpciea1cfghpicfginterruptmsitphpresent,
  input         cpmpciea1cfghpicfginterruptmsitphpresent, //msix
  input  [7:0]  ifcpmpciea1cfghpicfginterruptmsitphsttag,
  input  [7:0]  cpmpciea1cfghpicfginterruptmsitphsttag, //msix
  input  [1:0]  ifcpmpciea1cfghpicfginterruptmsitphtype,
  input  [1:0]  cpmpciea1cfghpicfginterruptmsitphtype, //msix
  input  [63:0] ifcpmpciea1cfghpicfginterruptmsixaddress,
  input  [31:0] ifcpmpciea1cfghpicfginterruptmsixdata,
  input         ifcpmpciea1cfghpicfginterruptmsixint,
  input  [1:0]  ifcpmpciea1cfghpicfginterruptmsixvecpending,
  input  [3:0]  ifcpmpciea1cfghpicfginterruptpending,
  input  [9:0]  ifcpmpciea1cfghpicfgmgmtaddr,
  input  [3:0]  ifcpmpciea1cfghpicfgmgmtbyteenable,
  input         ifcpmpciea1cfghpicfgmgmtdebugaccess,
  input  [7:0]  ifcpmpciea1cfghpicfgmgmtfunctionnumber,
  input         ifcpmpciea1cfghpicfgmgmtread,
  input         ifcpmpciea1cfghpicfgmgmtwrite,
  input  [31:0] ifcpmpciea1cfghpicfgmgmtwritedata,
  input         ifcpmpciea1cfghpicfgmsgtransmit,
  input  [31:0] ifcpmpciea1cfghpicfgmsgtransmitdata,
  input  [2:0]  ifcpmpciea1cfghpicfgmsgtransmittype,
  input         ifcpmpciea1cfghpicfgpowerstatechangeack,
  input         ifcpmpciea1cfghpicfgvfflrdone,
  input  [7:0]  ifcpmpciea1cfghpicfgvfflrfuncnum,

  input  [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1:0] ifpcie0plccaxisaxiscctdata,
  input  [15:0] ifpcie0plccaxisaxiscctkeep,
  input         ifpcie0plccaxisaxiscctlast,
  input  [80:0] ifpcie0plccaxisaxiscctuser,
  input         ifpcie0plccaxisaxiscctvalid,
  input  [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1:0] ifpcie0plrqaxisaxisrqtdata,
  input  [15:0] ifpcie0plrqaxisaxisrqtkeep,
  input         ifpcie0plrqaxisaxisrqtlast,
  input  [178:0] ifpcie0plrqaxisaxisrqtuser,
  input         ifpcie0plrqaxisaxisrqtvalid,
  input  [C_CPM_PCIE1_AXISTEN_IF_WIDTH-1:0] ifpcie1plccaxisaxiscctdata,
  input  [15:0] ifpcie1plccaxisaxiscctkeep,
  input         ifpcie1plccaxisaxiscctlast,
  input  [80:0] ifpcie1plccaxisaxiscctuser,
  input         ifpcie1plccaxisaxiscctvalid,
  input  [C_CPM_PCIE1_AXISTEN_IF_WIDTH-1:0] ifpcie1plrqaxisaxisrqtdata,
  input  [15:0] ifpcie1plrqaxisaxisrqtkeep,
  input         ifpcie1plrqaxisaxisrqtlast,
  input  [178:0] ifpcie1plrqaxisaxisrqtuser,
  input         ifpcie1plrqaxisaxisrqtvalid,
  input         ifplcpmp0chicrsplcrdv,
  input         ifplcpmp0chimlinkactivereq,
  input         ifplcpmp0chimsactive,
  input         ifplcpmp0chirdatlcrdv,
  input  [120:0] ifplcpmp0chireqflit,
  input         ifplcpmp0chireqflitpend,
  input         ifplcpmp0chireqflitv,
  input         ifplcpmp0chislinkactiveack,
  input         ifplcpmp0chisnplcrdv,
  input  [50:0] ifplcpmp0chisrspflit,
  input         ifplcpmp0chisrspflitpend,
  input         ifplcpmp0chisrspflitv,
  input         ifplcpmp0chisyscoreq,
  input  [704:0] ifplcpmp0chiwdatflit,
  input         ifplcpmp0chiwdatflitpend,
  input         ifplcpmp0chiwdatflitv,
  input         ifplcpmp1chicrsplcrdv,
  input         ifplcpmp1chimlinkactivereq,
  input         ifplcpmp1chimsactive,
  input         ifplcpmp1chirdatlcrdv,
  input  [120:0] ifplcpmp1chireqflit,
  input         ifplcpmp1chireqflitpend,
  input         ifplcpmp1chireqflitv,
  input         ifplcpmp1chislinkactiveack,
  input         ifplcpmp1chisnplcrdv,
  input  [50:0] ifplcpmp1chisrspflit,
  input         ifplcpmp1chisrspflitpend,
  input         ifplcpmp1chisrspflitv,
  input         ifplcpmp1chisyscoreq,
  input  [704:0] ifplcpmp1chiwdatflit,
  input         ifplcpmp1chiwdatflitpend,
  input         ifplcpmp1chiwdatflitv,
  input  [1:0]  ifplextpcie0axipciecqnpreq,
  input  [1:0]  ifplextpcie1axipciecqnpreq,

  input  plchi0clk,
  input  plchi1clk,
  input  plcpmirq0,
  input  plcpmirq1,
  input  plrefclk,

  output fpd_swdt_wwdt_irq,
  output fpd_swdt_wwdt_reset,
  output fpd_swdt_wwdt_reset_pending,
  output lpd_swdt_wwdt_irq,
  output lpd_swdt_wwdt_reset,
  output lpd_swdt_wwdt_reset_pending,
  input  fpd_swdt_wwdt_clk,
  input  lpd_swdt_wwdt_clk,

  output lpd_swdt_gwdt_ws0,
  output lpd_swdt_gwdt_ws1,
  output fpd_swdt_gwdt_ws0,
  output fpd_swdt_gwdt_ws1,


  output  hsm0_ref_clk,
  output  hsm1_ref_clk,



//********qdma ports start here **************//
  // MDMA ports
  output mdma_resetn,
  input qdma_st_rx_msg_rdy,
  output [31:0] qdma_st_rx_msg_data,
  output qdma_st_rx_msg_valid,
  output qdma_st_rx_msg_last,

  input  [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0] qdma_c2h_tdata,
  input  [63:0] qdma_c2h_data_par,

  input qdma_c2h_ctrl_marker,
  input  [2:0] qdma_c2h_ctrl_port_id,
  input qdma_c2h_ctrl_imm_data,
  input qdma_c2h_ctrl_disable_wrb,
  input qdma_c2h_ctrl_user_trig,
  input  [10:0] qdma_c2h_ctrl_qid,
  input  [15:0] qdma_c2h_ctrl_len,
  input qdma_c2h_tvalid,
  input qdma_c2h_tlast,
  input  [5:0] qdma_c2h_mty,
  output qdma_c2h_tready,

  input  [127:0] qdma_c2h_wrb_data,
  input  [1:0]   qdma_c2h_wrb_type,
  input  [3:0]   qdma_c2h_wrb_dpar,
  input          qdma_c2h_wrb_tvalid,
  input          qdma_c2h_wrb_tlast,
  output         qdma_c2h_wrb_tready,
  output [C_CPM_PCIE0_AXISTEN_IF_WIDTH-1 : 0] qdma_h2c_tdata,
  output [63:0]  qdma_h2c_tdata_par,
  output [127:0] qdma_h2c_tuser,
  output         qdma_h2c_tlast,
  output         qdma_h2c_tvalid,
  input          qdma_h2c_tready,

//******* H2C Descriptor Bypass Out Interface ******///
  output         h2c_byp_out_dsc_wbi,
  output         h2c_byp_out_dsc_wbi_chk,
  output [1:0]   h2c_byp_out_dsc_dsc_sz,
  output         h2c_byp_out_dsc_mm_chn,
  output         h2c_byp_out_dsc_sel,
  output         h2c_byp_out_dsc_st_mm,
  output [10:0]  h2c_byp_out_dsc_qid,
  output         h2c_byp_out_dsc_last,
  output         h2c_byp_out_dsc_error,
  output [7:0]   h2c_byp_out_dsc_func,
  output [15:0]  h2c_byp_out_dsc_cidx,
  output [255:0] h2c_byp_out_dsc_dsc,
  output         h2c_byp_out_vld,
  input          h2c_byp_out_rdy,

//  // C2H Descriptor Bypass Out Interface

  output         c2h_byp_out_dsc_is_wb,
  output [2:0]   c2h_byp_out_dsc_port_id,
  output         c2h_byp_out_dsc_wbi,
  output         c2h_byp_out_dsc_wbi_chk,
  output [1:0]   c2h_byp_out_dsc_dsc_sz,
  output         c2h_byp_out_dsc_mm_chn,
  output         c2h_byp_out_dsc_sel,
  output         c2h_byp_out_dsc_st_mm,
  output [10:0]  c2h_byp_out_dsc_qid,
  output         c2h_byp_out_dsc_last,
  output         c2h_byp_out_dsc_error,
  output [7:0]   c2h_byp_out_dsc_func,
  output [15:0]  c2h_byp_out_dsc_cidx,
  output [255:0] c2h_byp_out_dsc_dsc,
  output         c2h_byp_out_vld,
  input          c2h_byp_out_rdy,

// ******** H2C Descriptor Bypass In Interface*******//
  input          h2c_byp_in_dsc_is_wb_0,
  input  [2:0]   h2c_byp_in_dsc_port_id_0,
  input          h2c_byp_in_dsc_wbi_0,
  input          h2c_byp_in_dsc_wbi_chk_0,
  input  [1:0]   h2c_byp_in_dsc_dsc_sz_0,
  input          h2c_byp_in_dsc_mm_chn_0,
  input          h2c_byp_in_dsc_sel_0,
  input          h2c_byp_in_dsc_st_mm_0,
  input  [10:0]  h2c_byp_in_dsc_qid_0,
  input          h2c_byp_in_dsc_last_0,
  input          h2c_byp_in_dsc_error_0,
  input  [7:0]   h2c_byp_in_dsc_func_0,
  input  [15:0]  h2c_byp_in_dsc_cidx_0,
  input  [255:0] h2c_byp_in_dsc_dsc_0,
  input          h2c_byp_in_vld_0,
  input          h2c_byp_in_dsc_is_wb_1,
  input  [2:0]   h2c_byp_in_dsc_port_id_1,
  input          h2c_byp_in_dsc_wbi_1,
  input          h2c_byp_in_dsc_wbi_chk_1,
  input  [1:0]   h2c_byp_in_dsc_dsc_sz_1,
  input          h2c_byp_in_dsc_mm_chn_1,
  input          h2c_byp_in_dsc_sel_1,
  input          h2c_byp_in_dsc_st_mm_1,
  input  [10:0]  h2c_byp_in_dsc_qid_1,
  input          h2c_byp_in_dsc_last_1,
  input          h2c_byp_in_dsc_error_1,
  input  [7:0]   h2c_byp_in_dsc_func_1,
  input  [15:0]  h2c_byp_in_dsc_cidx_1,
  input  [255:0] h2c_byp_in_dsc_dsc_1,
  input          h2c_byp_in_vld_1,
  input          h2c_byp_in_dsc_is_wb_2,
  input  [2:0]   h2c_byp_in_dsc_port_id_2,
  input          h2c_byp_in_dsc_wbi_2,
  input          h2c_byp_in_dsc_wbi_chk_2,
  input  [1:0]   h2c_byp_in_dsc_dsc_sz_2,
  input          h2c_byp_in_dsc_mm_chn_2,
  input          h2c_byp_in_dsc_sel_2,
  input          h2c_byp_in_dsc_st_mm_2,
  input  [10:0]  h2c_byp_in_dsc_qid_2,
  input          h2c_byp_in_dsc_last_2,
  input          h2c_byp_in_dsc_error_2,
  input  [7:0]   h2c_byp_in_dsc_func_2,
  input  [15:0]  h2c_byp_in_dsc_cidx_2,
  input  [255:0] h2c_byp_in_dsc_dsc_2,
  input          h2c_byp_in_vld_2,
  output         h2c_byp_in_rdy_0,
  output         h2c_byp_in_rdy_1,
  output         h2c_byp_in_rdy_2,

//  // C2H Descriptor Bypass In Interface

  input          c2h_byp_in_dsc_is_wb_0,
  input  [2:0]   c2h_byp_in_dsc_port_id_0,
  input          c2h_byp_in_dsc_wbi_0,
  input          c2h_byp_in_dsc_wbi_chk_0,
  input  [1:0]   c2h_byp_in_dsc_dsc_sz_0,
  input          c2h_byp_in_dsc_mm_chn_0,
  input          c2h_byp_in_dsc_sel_0,
  input          c2h_byp_in_dsc_st_mm_0,
  input  [10:0]  c2h_byp_in_dsc_qid_0,
  input          c2h_byp_in_dsc_last_0,
  input          c2h_byp_in_dsc_error_0,
  input  [7:0]   c2h_byp_in_dsc_func_0,
  input  [15:0]  c2h_byp_in_dsc_cidx_0,
  input  [255:0] c2h_byp_in_dsc_dsc_0,
  input          c2h_byp_in_vld_0,
  input          c2h_byp_in_dsc_is_wb_1,
  input  [2:0]   c2h_byp_in_dsc_port_id_1,
  input          c2h_byp_in_dsc_wbi_1,
  input          c2h_byp_in_dsc_wbi_chk_1,
  input  [1:0]   c2h_byp_in_dsc_dsc_sz_1,
  input          c2h_byp_in_dsc_mm_chn_1,
  input          c2h_byp_in_dsc_sel_1,
  input          c2h_byp_in_dsc_st_mm_1,
  input  [10:0]  c2h_byp_in_dsc_qid_1,
  input          c2h_byp_in_dsc_last_1,
  input          c2h_byp_in_dsc_error_1,
  input  [7:0]   c2h_byp_in_dsc_func_1,
  input  [15:0]  c2h_byp_in_dsc_cidx_1,
  input  [255:0] c2h_byp_in_dsc_dsc_1,
  input          c2h_byp_in_vld_1,
  input          c2h_byp_in_dsc_is_wb_2,
  input  [2:0]   c2h_byp_in_dsc_port_id_2,
  input          c2h_byp_in_dsc_wbi_2,
  input          c2h_byp_in_dsc_wbi_chk_2,
  input  [1:0]   c2h_byp_in_dsc_dsc_sz_2,
  input          c2h_byp_in_dsc_mm_chn_2,
  input          c2h_byp_in_dsc_sel_2,
  input          c2h_byp_in_dsc_st_mm_2,
  input  [10:0]  c2h_byp_in_dsc_qid_2,
  input          c2h_byp_in_dsc_last_2,
  input          c2h_byp_in_dsc_error_2,
  input  [7:0]   c2h_byp_in_dsc_func_2,
  input  [15:0]  c2h_byp_in_dsc_cidx_2,
  input  [255:0] c2h_byp_in_dsc_dsc_2,
  input          c2h_byp_in_vld_2,
  output         c2h_byp_in_rdy_0,
  output         c2h_byp_in_rdy_1,
  output         c2h_byp_in_rdy_2,

//  // Descriptor Fetch Engine Out

  output        tm_dsc_sts_vld,
  output        tm_dsc_sts_qen,
  output [2:0]  tm_dsc_sts_port_id,
  output        tm_dsc_sts_err,
  output        tm_dsc_sts_byp,
  output        tm_dsc_sts_dir,
  output        tm_dsc_sts_mm,
  output [11:0] tm_dsc_sts_qid,
  output [15:0] tm_dsc_sts_avl,
  output        tm_dsc_sts_qinv,
  output        tm_dsc_sts_irq_arm,
  input         tm_dsc_sts_rdy,

//  // Descriptor credit In

  input         dsc_crdt_in_vld,
  output        dsc_crdt_in_rdy,
  input  [1:0]  dsc_crdt_in_op,
  input         dsc_crdt_in_sel,
  input  [10:0] dsc_crdt_in_qid,
  input  [15:0] dsc_crdt_in_crdt,
  input         irq_in_vld,
  input  [4:0]  irq_in_vec,
  input  [7:0]  irq_in_fnc,
  input  [1:0]  irq_in_pnd,
  output [4:0]  irq_out_ack,
  output        irq_out_fail,
  output        qdma_c2h_drop_valid,
  output        qdma_c2h_drop_drop,
  output [10:0] qdma_c2h_drop_qid,

//qdma ports end here

  input  [C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH-1:0] gt_pcieA0_rxn,
  input  [C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH-1:0] gt_pcieA0_rxp,
  output [C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH-1:0] gt_pcieA0_txn,
  output [C_CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH-1:0] gt_pcieA0_txp,

  input  [C_CPM_PCIE1_PL_LINK_CAP_MAX_LINK_WIDTH-1:0] gt_pcieA1_rxn ,
  input  [C_CPM_PCIE1_PL_LINK_CAP_MAX_LINK_WIDTH-1:0] gt_pcieA1_rxp ,
  output [C_CPM_PCIE1_PL_LINK_CAP_MAX_LINK_WIDTH-1:0] gt_pcieA1_txn ,
  output [C_CPM_PCIE1_PL_LINK_CAP_MAX_LINK_WIDTH-1:0] gt_pcieA1_txp ,

  input   hsdp0_gt_rxn,
  input   hsdp0_gt_rxp,
  output  hsdp0_gt_txn,
  output  hsdp0_gt_txp,

  input   hsdp1_gt_rxn,
  input   hsdp1_gt_rxp,
  output  hsdp1_gt_txn,
  output  hsdp1_gt_txp,

  input gt_refclk0_clk_in_d_n,
  input gt_refclk0_clk_in_d_p,
  input gt_refclk1_clk_in_d_n,
  input gt_refclk1_clk_in_d_p,
  
//PS CPM4 ports for PS-VIP support
  
output cpm_osc_clk_div2,
input [63:0] m_axi0_ps_araddr,
input [1:0] m_axi0_ps_arburst,
input [3:0] m_axi0_ps_arcache,
input [15:0] m_axi0_ps_arid,
input [7:0] m_axi0_ps_arlen,
input m_axi0_ps_arlock,
input [2:0] m_axi0_ps_arprot,
input [3:0] m_axi0_ps_arqos,
output m_axi0_ps_arready,
input [3:0] m_axi0_ps_arregion,
input [2:0] m_axi0_ps_arsize,
input [31:0] m_axi0_ps_aruser,
input m_axi0_ps_arvalid,
input [63:0] m_axi0_ps_awaddr,
input [1:0] m_axi0_ps_awburst,
input [3:0] m_axi0_ps_awcache,
input [15:0] m_axi0_ps_awid,
input [7:0] m_axi0_ps_awlen,
input m_axi0_ps_awlock,
input [2:0] m_axi0_ps_awprot,
input [3:0] m_axi0_ps_awqos,
output m_axi0_ps_awready,
input [3:0] m_axi0_ps_awregion,
input [2:0] m_axi0_ps_awsize,
input [31:0] m_axi0_ps_awuser,
input m_axi0_ps_awvalid,
output [15:0] m_axi0_ps_bid,
input m_axi0_ps_bready,
output [1:0] m_axi0_ps_bresp,
output m_axi0_ps_buser,
output m_axi0_ps_bvalid,
output [127:0] m_axi0_ps_rdata,
output [15:0] m_axi0_ps_rid,
output m_axi0_ps_rlast,
input m_axi0_ps_rready,
output [1:0] m_axi0_ps_rresp,
output [17:0] m_axi0_ps_ruser,
output m_axi0_ps_rvalid,
input [127:0] m_axi0_ps_wdata,
input [15:0] m_axi0_ps_wid,
input m_axi0_ps_wlast,
output m_axi0_ps_wready,
input [15:0] m_axi0_ps_wstrb,
input [17:0] m_axi0_ps_wuser,
input m_axi0_ps_wvalid,
input [63:0] m_axi1_ps_araddr,
input [1:0] m_axi1_ps_arburst,
input [3:0] m_axi1_ps_arcache,
input [15:0] m_axi1_ps_arid,
input [7:0] m_axi1_ps_arlen,
input m_axi1_ps_arlock,
input [2:0] m_axi1_ps_arprot,
input [3:0] m_axi1_ps_arqos,
output m_axi1_ps_arready,
input [3:0] m_axi1_ps_arregion,
input [2:0] m_axi1_ps_arsize,
input [17:0] m_axi1_ps_aruser,
input m_axi1_ps_arvalid,
input [63:0] m_axi1_ps_awaddr,
input [1:0] m_axi1_ps_awburst,
input [3:0] m_axi1_ps_awcache,
input [15:0] m_axi1_ps_awid,
input [7:0] m_axi1_ps_awlen,
input m_axi1_ps_awlock,
input [2:0] m_axi1_ps_awprot,
input [3:0] m_axi1_ps_awqos,
output m_axi1_ps_awready,
input [3:0] m_axi1_ps_awregion,
input [2:0] m_axi1_ps_awsize,
input [17:0] m_axi1_ps_awuser,
input m_axi1_ps_awvalid,
output [15:0] m_axi1_ps_bid,
input m_axi1_ps_bready,
output [1:0] m_axi1_ps_bresp,
output [15:0] m_axi1_ps_buser,
output m_axi1_ps_bvalid,
output [127:0] m_axi1_ps_rdata,
output [15:0] m_axi1_ps_rid,
output m_axi1_ps_rlast,
input m_axi1_ps_rready,
output [1:0] m_axi1_ps_rresp,
output [16:0] m_axi1_ps_ruser,
output m_axi1_ps_rvalid,
input [127:0] m_axi1_ps_wdata,
input [15:0] m_axi1_ps_wid,
input m_axi1_ps_wlast,
output m_axi1_ps_wready,
input [15:0] m_axi1_ps_wstrb,
input [16:0] m_axi1_ps_wuser,
input m_axi1_ps_wvalid,
input cpmps_corr_irq,
input cpmps_misc_irq,
input cpmps_uncorr_irq,
output [63:0] s_axi_cfg_araddr,
output [1:0] s_axi_cfg_arburst,
output [3:0] s_axi_cfg_arcache,
output [15:0] s_axi_cfg_arid,
output [7:0] s_axi_cfg_arlen,
output s_axi_cfg_arlock,
output [2:0] s_axi_cfg_arprot,
output [3:0] s_axi_cfg_arqos,
input s_axi_cfg_arready,
output [3:0] s_axi_cfg_arregion,
output [2:0] s_axi_cfg_arsize,
output [15:0] s_axi_cfg_aruser,
output s_axi_cfg_arvalid,
output [63:0] s_axi_cfg_awaddr,
output [1:0] s_axi_cfg_awburst,
output [3:0] s_axi_cfg_awcache,
output [15:0] s_axi_cfg_awid,
output [7:0] s_axi_cfg_awlen,
output s_axi_cfg_awlock,
output [2:0] s_axi_cfg_awprot,
output [3:0] s_axi_cfg_awqos,
input s_axi_cfg_awready,
output [3:0] s_axi_cfg_awregion,
output [2:0] s_axi_cfg_awsize,
output [15:0] s_axi_cfg_awuser,
output s_axi_cfg_awvalid,
input [15:0] s_axi_cfg_bid,
output s_axi_cfg_bready,
input [1:0] s_axi_cfg_bresp,
input s_axi_cfg_buser,
input s_axi_cfg_bvalid,
input [31:0] s_axi_cfg_rdata,
input [15:0] s_axi_cfg_rid,
input s_axi_cfg_rlast,
output s_axi_cfg_rready,
input [1:0] s_axi_cfg_rresp,
input [5:0] s_axi_cfg_ruser,
input s_axi_cfg_rvalid,
output [31:0] s_axi_cfg_wdata,
output [15:0] s_axi_cfg_wid,
output s_axi_cfg_wlast,
input s_axi_cfg_wready,
output [3:0] s_axi_cfg_wstrb,
output [5:0] s_axi_cfg_wuser,
output s_axi_cfg_wvalid,
output [1:0] xpipe0_powerdown,
output [1:0] xpipe1_powerdown,
output [1:0] xpipe2_powerdown,
output [1:0] xpipe3_powerdown,
output [1:0] xpipe4_powerdown,
output [1:0] xpipe5_powerdown,
output [1:0] xpipe6_powerdown,
output [1:0] xpipe7_powerdown,
output [1:0] xpipe8_powerdown,
output [1:0] xpipe9_powerdown,
output [1:0] xpipe10_powerdown,
output [1:0] xpipe11_powerdown,
output [1:0] xpipe12_powerdown,
output [1:0] xpipe13_powerdown,
output [1:0] xpipe14_powerdown,
output [1:0] xpipe15_powerdown,
input xpipe1_phystatus,
input xpipe2_phystatus,
input xpipe3_phystatus,
input xpipe4_phystatus,
input xpipe5_phystatus,
input xpipe6_phystatus,
input xpipe7_phystatus,
input xpipe8_phystatus,
input xpipe9_phystatus,
input xpipe10_phystatus,
input xpipe11_phystatus,
input xpipe12_phystatus,
input xpipe13_phystatus,
input xpipe14_phystatus,
input xpipe15_phystatus,
input [1:0] xpipe0_rx_charisk,
input [1:0] xpipe1_rx_charisk,
input [1:0] xpipe2_rx_charisk,
input [1:0] xpipe3_rx_charisk,
input [1:0] xpipe4_rx_charisk,
input [1:0] xpipe5_rx_charisk,
input [1:0] xpipe6_rx_charisk,
input [1:0] xpipe7_rx_charisk,
input [1:0] xpipe8_rx_charisk,
input [1:0] xpipe9_rx_charisk,
input [1:0] xpipe10_rx_charisk,
input [1:0] xpipe11_rx_charisk,
input [1:0] xpipe12_rx_charisk,
input [1:0] xpipe13_rx_charisk,
input [1:0] xpipe14_rx_charisk,
input [1:0] xpipe15_rx_charisk,
input [31:0] xpipe0_rx_data,
input [31:0] xpipe1_rx_data,
input [31:0] xpipe2_rx_data,
input [31:0] xpipe3_rx_data,
input [31:0] xpipe4_rx_data,
input [31:0] xpipe5_rx_data,
input [31:0] xpipe6_rx_data,
input [31:0] xpipe7_rx_data,
input [31:0] xpipe8_rx_data,
input [31:0] xpipe9_rx_data,
input [31:0] xpipe10_rx_data,
input [31:0] xpipe11_rx_data,
input [31:0] xpipe12_rx_data,
input [31:0] xpipe13_rx_data,
input [31:0] xpipe14_rx_data,
input [31:0] xpipe15_rx_data,
input xpipe0_rx_datavalid,
input xpipe1_rx_datavalid,
input xpipe2_rx_datavalid,
input xpipe3_rx_datavalid,
input xpipe4_rx_datavalid,
input xpipe5_rx_datavalid,
input xpipe6_rx_datavalid,
input xpipe7_rx_datavalid,
input xpipe8_rx_datavalid,
input xpipe9_rx_datavalid,
input xpipe10_rx_datavalid,
input xpipe11_rx_datavalid,
input xpipe12_rx_datavalid,
input xpipe13_rx_datavalid,
input xpipe14_rx_datavalid,
input xpipe15_rx_datavalid,
input xpipe0_rx_elecidle,
input xpipe1_rx_elecidle,
input xpipe2_rx_elecidle,
input xpipe3_rx_elecidle,
input xpipe4_rx_elecidle,
input xpipe5_rx_elecidle,
input xpipe6_rx_elecidle,
input xpipe7_rx_elecidle,
input xpipe8_rx_elecidle,
input xpipe9_rx_elecidle,
input xpipe10_rx_elecidle,
input xpipe11_rx_elecidle,
input xpipe12_rx_elecidle,
input xpipe13_rx_elecidle,
input xpipe14_rx_elecidle,
input xpipe15_rx_elecidle,
output xpipe0_rx_polarity,
output xpipe1_rx_polarity,
output xpipe2_rx_polarity,
output xpipe3_rx_polarity,
output xpipe4_rx_polarity,
output xpipe5_rx_polarity,
output xpipe6_rx_polarity,
output xpipe7_rx_polarity,
output xpipe8_rx_polarity,
output xpipe9_rx_polarity,
output xpipe10_rx_polarity,
output xpipe11_rx_polarity,
output xpipe12_rx_polarity,
output xpipe13_rx_polarity,
output xpipe14_rx_polarity,
output xpipe15_rx_polarity,
input xpipe0_rx_startblock,
input xpipe1_rx_startblock,
input xpipe2_rx_startblock,
input xpipe3_rx_startblock,
input xpipe4_rx_startblock,
input xpipe5_rx_startblock,
input xpipe6_rx_startblock,
input xpipe7_rx_startblock,
input xpipe8_rx_startblock,
input xpipe9_rx_startblock,
input xpipe10_rx_startblock,
input xpipe11_rx_startblock,
input xpipe12_rx_startblock,
input xpipe13_rx_startblock,
input xpipe14_rx_startblock,
input xpipe15_rx_startblock,
input [2:0] xpipe0_rx_status,
input [2:0] xpipe1_rx_status,
input [2:0] xpipe2_rx_status,
input [2:0] xpipe3_rx_status,
input [2:0] xpipe4_rx_status,
input [2:0] xpipe5_rx_status,
input [2:0] xpipe6_rx_status,
input [2:0] xpipe7_rx_status,
input [2:0] xpipe8_rx_status,
input [2:0] xpipe9_rx_status,
input [2:0] xpipe10_rx_status,
input [2:0] xpipe11_rx_status,
input [2:0] xpipe12_rx_status,
input [2:0] xpipe13_rx_status,
input [2:0] xpipe14_rx_status,
input [2:0] xpipe15_rx_status,
input [1:0] xpipe0_rx_syncheader,
input [1:0] xpipe1_rx_syncheader,
input [1:0] xpipe2_rx_syncheader,
input [1:0] xpipe3_rx_syncheader,
input [1:0] xpipe4_rx_syncheader,
input [1:0] xpipe5_rx_syncheader,
input [1:0] xpipe6_rx_syncheader,
input [1:0] xpipe7_rx_syncheader,
input [1:0] xpipe8_rx_syncheader,
input [1:0] xpipe9_rx_syncheader,
input [1:0] xpipe10_rx_syncheader,
input [1:0] xpipe11_rx_syncheader,
input [1:0] xpipe12_rx_syncheader,
input [1:0] xpipe13_rx_syncheader,
input [1:0] xpipe14_rx_syncheader,
input [1:0] xpipe15_rx_syncheader,
output xpipe0_rx_termination,
output xpipe1_rx_termination,
output xpipe2_rx_termination,
output xpipe3_rx_termination,
output xpipe4_rx_termination,
output xpipe5_rx_termination,
output xpipe6_rx_termination,
output xpipe7_rx_termination,
output xpipe8_rx_termination,
output xpipe9_rx_termination,
output xpipe10_rx_termination,
output xpipe11_rx_termination,
output xpipe12_rx_termination,
output xpipe13_rx_termination,
output xpipe14_rx_termination,
output xpipe15_rx_termination,
input xpipe0_rx_valid,
input xpipe1_rx_valid,
input xpipe2_rx_valid,
input xpipe3_rx_valid,
input xpipe4_rx_valid,
input xpipe5_rx_valid,
input xpipe6_rx_valid,
input xpipe7_rx_valid,
input xpipe8_rx_valid,
input xpipe9_rx_valid,
input xpipe10_rx_valid,
input xpipe11_rx_valid,
input xpipe12_rx_valid,
input xpipe13_rx_valid,
input xpipe14_rx_valid,
input xpipe15_rx_valid,
output [1:0] xpipe0_tx_charisk,
output [1:0] xpipe1_tx_charisk,
output [1:0] xpipe2_tx_charisk,
output [1:0] xpipe3_tx_charisk,
output [1:0] xpipe4_tx_charisk,
output [1:0] xpipe5_tx_charisk,
output [1:0] xpipe6_tx_charisk,
output [1:0] xpipe7_tx_charisk,
output [1:0] xpipe8_tx_charisk,
output [1:0] xpipe9_tx_charisk,
output [1:0] xpipe10_tx_charisk,
output [1:0] xpipe11_tx_charisk,
output [1:0] xpipe12_tx_charisk,
output [1:0] xpipe13_tx_charisk,
output [1:0] xpipe14_tx_charisk,
output [1:0] xpipe15_tx_charisk,
output xpipe0_tx_compliance,
output xpipe1_tx_compliance,
output xpipe2_tx_compliance,
output xpipe3_tx_compliance,
output xpipe4_tx_compliance,
output xpipe5_tx_compliance,
output xpipe6_tx_compliance,
output xpipe7_tx_compliance,
output xpipe8_tx_compliance,
output xpipe9_tx_compliance,
output xpipe10_tx_compliance,
output xpipe11_tx_compliance,
output xpipe12_tx_compliance,
output xpipe13_tx_compliance,
output xpipe14_tx_compliance,
output xpipe15_tx_compliance,
output [31:0] xpipe0_tx_data,
output [31:0] xpipe1_tx_data,
output [31:0] xpipe2_tx_data,
output [31:0] xpipe3_tx_data,
output [31:0] xpipe4_tx_data,
output [31:0] xpipe5_tx_data,
output [31:0] xpipe6_tx_data,
output [31:0] xpipe7_tx_data,
output [31:0] xpipe8_tx_data,
output [31:0] xpipe9_tx_data,
output [31:0] xpipe10_tx_data,
output [31:0] xpipe11_tx_data,
output [31:0] xpipe12_tx_data,
output [31:0] xpipe13_tx_data,
output [31:0] xpipe14_tx_data,
output [31:0] xpipe15_tx_data,
output xpipe0_tx_datavalid,
output xpipe1_tx_datavalid,
output xpipe2_tx_datavalid,
output xpipe3_tx_datavalid,
output xpipe4_tx_datavalid,
output xpipe5_tx_datavalid,
output xpipe6_tx_datavalid,
output xpipe7_tx_datavalid,
output xpipe8_tx_datavalid,
output xpipe9_tx_datavalid,
output xpipe10_tx_datavalid,
output xpipe11_tx_datavalid,
output xpipe12_tx_datavalid,
output xpipe13_tx_datavalid,
output xpipe14_tx_datavalid,
output xpipe15_tx_datavalid,
output xpipe0_tx_deemph,
output xpipe1_tx_deemph,
output xpipe2_tx_deemph,
output xpipe3_tx_deemph,
output xpipe4_tx_deemph,
output xpipe5_tx_deemph,
output xpipe6_tx_deemph,
output xpipe7_tx_deemph,
output xpipe8_tx_deemph,
output xpipe9_tx_deemph,
output xpipe10_tx_deemph,
output xpipe11_tx_deemph,
output xpipe12_tx_deemph,
output xpipe13_tx_deemph,
output xpipe14_tx_deemph,
output xpipe15_tx_deemph,
output xpipe0_tx_detectrxloopback,
output xpipe1_tx_detectrxloopback,
output xpipe2_tx_detectrxloopback,
output xpipe3_tx_detectrxloopback,
output xpipe4_tx_detectrxloopback,
output xpipe5_tx_detectrxloopback,
output xpipe6_tx_detectrxloopback,
output xpipe7_tx_detectrxloopback,
output xpipe8_tx_detectrxloopback,
output xpipe9_tx_detectrxloopback,
output xpipe10_tx_detectrxloopback,
output xpipe11_tx_detectrxloopback,
output xpipe12_tx_detectrxloopback,
output xpipe13_tx_detectrxloopback,
output xpipe14_tx_detectrxloopback,
output xpipe15_tx_detectrxloopback,
output xpipe0_tx_elecidle,
output xpipe1_tx_elecidle,
output xpipe2_tx_elecidle,
output xpipe3_tx_elecidle,
output xpipe4_tx_elecidle,
output xpipe5_tx_elecidle,
output xpipe6_tx_elecidle,
output xpipe7_tx_elecidle,
output xpipe8_tx_elecidle,
output xpipe9_tx_elecidle,
output xpipe10_tx_elecidle,
output xpipe11_tx_elecidle,
output xpipe12_tx_elecidle,
output xpipe13_tx_elecidle,
output xpipe14_tx_elecidle,
output xpipe15_tx_elecidle,
output [6:0] xpipe0_tx_maincursor,
output [6:0] xpipe1_tx_maincursor,
output [6:0] xpipe2_tx_maincursor,
output [6:0] xpipe3_tx_maincursor,
output [6:0] xpipe4_tx_maincursor,
output [6:0] xpipe5_tx_maincursor,
output [6:0] xpipe6_tx_maincursor,
output [6:0] xpipe7_tx_maincursor,
output [6:0] xpipe8_tx_maincursor,
output [6:0] xpipe9_tx_maincursor,
output [6:0] xpipe10_tx_maincursor,
output [6:0] xpipe11_tx_maincursor,
output [6:0] xpipe12_tx_maincursor,
output [6:0] xpipe13_tx_maincursor,
output [6:0] xpipe14_tx_maincursor,
output [6:0] xpipe15_tx_maincursor,
output [2:0] xpipe0_tx_margin,
output [2:0] xpipe1_tx_margin,
output [2:0] xpipe2_tx_margin,
output [2:0] xpipe3_tx_margin,
output [2:0] xpipe4_tx_margin,
output [2:0] xpipe5_tx_margin,
output [2:0] xpipe6_tx_margin,
output [2:0] xpipe7_tx_margin,
output [2:0] xpipe8_tx_margin,
output [2:0] xpipe9_tx_margin,
output [2:0] xpipe10_tx_margin,
output [2:0] xpipe11_tx_margin,
output [2:0] xpipe12_tx_margin,
output [2:0] xpipe13_tx_margin,
output [2:0] xpipe14_tx_margin,
output [2:0] xpipe15_tx_margin,
output [4:0] xpipe0_tx_postcursor,
output [4:0] xpipe1_tx_postcursor,
output [4:0] xpipe2_tx_postcursor,
output [4:0] xpipe3_tx_postcursor,
output [4:0] xpipe4_tx_postcursor,
output [4:0] xpipe5_tx_postcursor,
output [4:0] xpipe6_tx_postcursor,
output [4:0] xpipe7_tx_postcursor,
output [4:0] xpipe8_tx_postcursor,
output [4:0] xpipe9_tx_postcursor,
output [4:0] xpipe10_tx_postcursor,
output [4:0] xpipe11_tx_postcursor,
output [4:0] xpipe12_tx_postcursor,
output [4:0] xpipe13_tx_postcursor,
output [4:0] xpipe14_tx_postcursor,
output [4:0] xpipe15_tx_postcursor,
output [4:0] xpipe0_tx_precursor,
output [4:0] xpipe1_tx_precursor,
output [4:0] xpipe2_tx_precursor,
output [4:0] xpipe3_tx_precursor,
output [4:0] xpipe4_tx_precursor,
output [4:0] xpipe5_tx_precursor,
output [4:0] xpipe6_tx_precursor,
output [4:0] xpipe7_tx_precursor,
output [4:0] xpipe8_tx_precursor,
output [4:0] xpipe9_tx_precursor,
output [4:0] xpipe10_tx_precursor,
output [4:0] xpipe11_tx_precursor,
output [4:0] xpipe12_tx_precursor,
output [4:0] xpipe13_tx_precursor,
output [4:0] xpipe14_tx_precursor,
output [4:0] xpipe15_tx_precursor,
output xpipe0_tx_startblock,
output xpipe1_tx_startblock,
output xpipe2_tx_startblock,
output xpipe3_tx_startblock,
output xpipe4_tx_startblock,
output xpipe5_tx_startblock,
output xpipe6_tx_startblock,
output xpipe7_tx_startblock,
output xpipe8_tx_startblock,
output xpipe9_tx_startblock,
output xpipe10_tx_startblock,
output xpipe11_tx_startblock,
output xpipe12_tx_startblock,
output xpipe13_tx_startblock,
output xpipe14_tx_startblock,
output xpipe15_tx_startblock,
output xpipe0_tx_swing,
output xpipe1_tx_swing,
output xpipe2_tx_swing,
output xpipe3_tx_swing,
output xpipe4_tx_swing,
output xpipe5_tx_swing,
output xpipe6_tx_swing,
output xpipe7_tx_swing,
output xpipe8_tx_swing,
output xpipe9_tx_swing,
output xpipe10_tx_swing,
output xpipe11_tx_swing,
output xpipe12_tx_swing,
output xpipe13_tx_swing,
output xpipe14_tx_swing,
output xpipe15_tx_swing,
output [1:0] xpipe0_tx_syncheader,
output [1:0] xpipe1_tx_syncheader,
output [1:0] xpipe2_tx_syncheader,
output [1:0] xpipe3_tx_syncheader,
output [1:0] xpipe4_tx_syncheader,
output [1:0] xpipe5_tx_syncheader,
output [1:0] xpipe6_tx_syncheader,
output [1:0] xpipe7_tx_syncheader,
output [1:0] xpipe8_tx_syncheader,
output [1:0] xpipe9_tx_syncheader,
output [1:0] xpipe10_tx_syncheader,
output [1:0] xpipe11_tx_syncheader,
output [1:0] xpipe12_tx_syncheader,
output [1:0] xpipe13_tx_syncheader,
output [1:0] xpipe14_tx_syncheader,
output [1:0] xpipe15_tx_syncheader,
input hsdp_xpipe0_rx_datavalid,
input hsdp_xpipe1_rx_datavalid,
input hsdp_xpipe2_rx_datavalid,
output hsdp_xpipe0_rx_gearboxslip,
output hsdp_xpipe1_rx_gearboxslip,
output hsdp_xpipe2_rx_gearboxslip,
input [1:0] hsdp_xpipe0_rx_header,
input [1:0] hsdp_xpipe1_rx_header,
input [1:0] hsdp_xpipe2_rx_header,
input hsdp_xpipe0_rx_headervalid,
input hsdp_xpipe1_rx_headervalid,
input hsdp_xpipe2_rx_headervalid,
output hsdp_xpipe0_rx_pcsreset,
output hsdp_xpipe1_rx_pcsreset,
output hsdp_xpipe2_rx_pcsreset,
input hsdp_xpipe0_rx_resetdone,
input hsdp_xpipe1_rx_resetdone,
input hsdp_xpipe2_rx_resetdone,
output [1:0] hsdp_xpipe0_tx_header,
output [1:0] hsdp_xpipe1_tx_header,
output [1:0] hsdp_xpipe2_tx_header,
input hsdp_xpipe0_tx_resetdone,
input hsdp_xpipe1_tx_resetdone,
input hsdp_xpipe2_tx_resetdone,
output [6:0] hsdp_xpipe0_tx_sequence,
output [6:0] hsdp_xpipe1_tx_sequence,
output [6:0] hsdp_xpipe2_tx_sequence,
input hsdp_gt_rxoutclk,
output hsdp_gt_txusrclk,
output phy_ready_frbot,
input phy_ready_tobot,
input link0_xpipe_bufgtce,
input link1_xpipe_bufgtce,
input [3:0] link0_xpipe_bufgtcemask,
input [3:0] link1_xpipe_bufgtcemask,
input [11:0] link0_xpipe_bufgtdiv,
input [11:0] link1_xpipe_bufgtdiv,
input link0_xpipe_bufgtrst,
input link1_xpipe_bufgtrst,
input [3:0] link0_xpipe_bufgtrstmask,
input [3:0] link1_xpipe_bufgtrstmask,
input link0_xpipe_gtoutclk,
input link1_xpipe_gtoutclk,
output link0_xpipe_gtpipeclk,
output link1_xpipe_gtpipeclk,
output link0_xpipe_pcielinkreachtarget,
output link1_xpipe_pcielinkreachtarget,
output [5:0] link0_xpipe_pcieltssmstate,
output [5:0] link1_xpipe_pcieltssmstate,
output link0_xpipe_pcieperstn,
output link1_xpipe_pcieperstn,
output link0_xpipe_phyesmadaptationsave,
output link1_xpipe_phyesmadaptationsave,
input link0_xpipe_phyready,
input link1_xpipe_phyready,
output [2:0] link0_xpipe_piperate,
output [2:0] link1_xpipe_piperate,
output [63:0] s_axi_pcie_araddr,
output [1:0] s_axi_pcie_arburst,
output [3:0] s_axi_pcie_arcache,
output [15:0] s_axi_pcie_arid,
output [7:0] s_axi_pcie_arlen,
output s_axi_pcie_arlock,
output [2:0] s_axi_pcie_arprot,
output [3:0] s_axi_pcie_arqos,
input s_axi_pcie_arready,
output [3:0] s_axi_pcie_arregion,
output [2:0] s_axi_pcie_arsize,
output [17:0] s_axi_pcie_aruser,
output s_axi_pcie_arvalid,
output [63:0] s_axi_pcie_awaddr,
output [1:0] s_axi_pcie_awburst,
output [3:0] s_axi_pcie_awcache,
output [15:0] s_axi_pcie_awid,
output [7:0] s_axi_pcie_awlen,
output s_axi_pcie_awlock,
output [2:0] s_axi_pcie_awprot,
output [3:0] s_axi_pcie_awqos,
input s_axi_pcie_awready,
output [3:0] s_axi_pcie_awregion,
output [2:0] s_axi_pcie_awsize,
output [17:0] s_axi_pcie_awuser,
output s_axi_pcie_awvalid,
input [15:0] s_axi_pcie_bid,
output s_axi_pcie_bready,
input [1:0] s_axi_pcie_bresp,
input [15:0] s_axi_pcie_buser,
input s_axi_pcie_bvalid,
input [127:0] s_axi_pcie_rdata,
input [15:0] s_axi_pcie_rid,
input s_axi_pcie_rlast,
output s_axi_pcie_rready,
input [1:0] s_axi_pcie_rresp,
input [16:0] s_axi_pcie_ruser,
input s_axi_pcie_rvalid,
output [127:0] s_axi_pcie_wdata,
output [15:0] s_axi_pcie_wid,
output s_axi_pcie_wlast,
input s_axi_pcie_wready,
output [15:0] s_axi_pcie_wstrb,
output [16:0] s_axi_pcie_wuser,
output s_axi_pcie_wvalid,
output cpm_pcr_apb_en,
output cpm_pcr_dis_npi_clk,
output cpm_pcr_fabric_en,
output cpm_pcr_gate_reg,
output cpm_pcr_hold_state,
output cpm_pcr_init_state,
output cpm_pcr_mem_clr,
output [3:0] cpm_pcr_o_disable,
output cpm_pcr_pcomplete,
output cpm_pcr_pwr_dn,
output cpm_pcr_scan_clr,
output cpm_pcr_start_bisr,
output cpm_pcr_start_cal,
output cpm_pcr_tristate,
input xpipe_q0_rxmargin_req_ack,
input xpipe_q1_rxmargin_req_ack,
input xpipe_q2_rxmargin_req_ack,
input xpipe_q3_rxmargin_req_ack,
output [3:0] xpipe_q0_rxmargin_req_cmd,
output [3:0] xpipe_q1_rxmargin_req_cmd,
output [3:0] xpipe_q2_rxmargin_req_cmd,
output [3:0] xpipe_q3_rxmargin_req_cmd,
output [1:0] xpipe_q0_rxmargin_req_lanenum,
output [1:0] xpipe_q1_rxmargin_req_lanenum,
output [1:0] xpipe_q2_rxmargin_req_lanenum,
output [1:0] xpipe_q3_rxmargin_req_lanenum,
output [7:0] xpipe_q0_rxmargin_req_payload,
output [7:0] xpipe_q1_rxmargin_req_payload,
output [7:0] xpipe_q2_rxmargin_req_payload,
output [7:0] xpipe_q3_rxmargin_req_payload,
output xpipe_q0_rxmargin_req_req,
output xpipe_q1_rxmargin_req_req,
output xpipe_q2_rxmargin_req_req,
output xpipe_q3_rxmargin_req_req,
output xpipe_q0_rxmargin_res_ack,
output xpipe_q1_rxmargin_res_ack,
output xpipe_q2_rxmargin_res_ack,
output xpipe_q3_rxmargin_res_ack,
input [3:0] xpipe_q0_rxmargin_res_cmd,
input [3:0] xpipe_q1_rxmargin_res_cmd,
input [3:0] xpipe_q2_rxmargin_res_cmd,
input [3:0] xpipe_q3_rxmargin_res_cmd,
input [1:0] xpipe_q0_rxmargin_res_lanenum,
input [1:0] xpipe_q1_rxmargin_res_lanenum,
input [1:0] xpipe_q2_rxmargin_res_lanenum,
input [1:0] xpipe_q3_rxmargin_res_lanenum,
input [7:0] xpipe_q0_rxmargin_res_payload,
input [7:0] xpipe_q1_rxmargin_res_payload,
input [7:0] xpipe_q2_rxmargin_res_payload,
input [7:0] xpipe_q3_rxmargin_res_payload,
input xpipe_q0_rxmargin_res_req,
input xpipe_q1_rxmargin_res_req,
input xpipe_q2_rxmargin_res_req,
input xpipe_q3_rxmargin_res_req,
output lpd_refclk_in,
output lpd_switch_timeout_cnt,
output lpd_swclk,
output perst0n,
input pl_error_pmc_0,
input pl_error_pmc_1,
input pl_error_pmc_2,
input pl_error_pmc_3,
output perst1n


//
  );
  wire [3:0] s_pmu_error_from_pl;
  generate
    if (C_PMC_USE_PL_ERR0 == 1 || C_PMC_USE_PL_ERR1 == 1 || C_PMC_USE_PL_ERR2 == 1 || C_PMC_USE_PL_ERR3 == 1) 
     begin
      assign s_pmu_error_from_pl = {pl_error_pmc_3, pl_error_pmc_2, pl_error_pmc_1, pl_error_pmc_0};
     end 
	else 
         begin
             if (C_PS_PMU_PERIPHERAL_ENABLE == 1) 
	      begin
               assign s_pmu_error_from_pl = pmu_error_from_pl;
              end
         end
  endgenerate
  wire slr1_captureclk_temp;
  wire slr1_captureb_temp;
  wire slr2_captureclk_temp;
  wire slr2_captureb_temp;
  wire slr3_captureclk_temp;
  wire slr3_captureb_temp;

  wire gem0_mdio_t_tmp;
  wire gem1_mdio_t_tmp;

  wire [3:0] gt_quad_base_serial_rxn;
  wire [3:0] gt_quad_base_serial_rxp;

  wire [3:0] gt_quad_base_serial_txn;
  wire [3:0] gt_quad_base_serial_txp;


  wire [3:0] q1_gt_quad_base_serial_rxn;
  wire [3:0] q1_gt_quad_base_serial_rxp;
  wire [3:0] q1_gt_quad_base_serial_txn;
  wire [3:0] q1_gt_quad_base_serial_txp;

  wire [3:0] q2_gt_quad_base_serial_rxn;
  wire [3:0] q2_gt_quad_base_serial_rxp;
  wire [3:0] q2_gt_quad_base_serial_txn;
  wire [3:0] q2_gt_quad_base_serial_txp;

  wire [3:0] q3_gt_quad_base_serial_rxn;
  wire [3:0] q3_gt_quad_base_serial_rxp;
  wire [3:0] q3_gt_quad_base_serial_txn;
  wire [3:0] q3_gt_quad_base_serial_txp;

  wire  ps_pl_trace_ctl_i;
  wire [C_PS_TRACE_WIDTH-1:0] ps_pl_trace_data_i;

  wire [1:0] hsm_ref_clk;
  wire [1:0] slr1_hsm_ref_clk;
  wire [1:0] slr2_hsm_ref_clk;
  wire [1:0] slr3_hsm_ref_clk;

  wire [1:0] gem0_tsu_inc_ctrl_wire;

  assign hsm0_ref_clk = hsm_ref_clk[0] ;
  assign hsm1_ref_clk = hsm_ref_clk[1] ;

 // Addition of wires for SLRx_PS_USE_CAPTURE


// Addition of wires for SLRx_HSM_CLKs


  
  generate 
   if( (C_PS_TRACE_PERIPHERAL == 1))
    begin
  	always @(posedge trace_ref_clk) begin
	    trace_data <= ps_pl_trace_data_i;
	    trace_ctrl <= ps_pl_trace_ctl_i;
	    trace_clk <= ~trace_clk;
	  end
    end
  endgenerate


 generate
  if ( C_GEM_TSU_ENABLE ==1 )
   begin
	assign gem0_tsu_inc_ctrl_wire = C_GEM0_TSU_INC_CTRL;
   end
  else
   begin
	assign gem0_tsu_inc_ctrl_wire = gem0_tsu_inc_ctrl;
   end
 endgenerate




//////////////////////////////////////////////////////////////////////////////////////////////////////

  wire ifpcie0plrcaxisaxisrccredit;
  wire ifpcie0plcqaxisaxiscqcredit;
  wire ifpcie1plrcaxisaxisrccredit;
  wire ifpcie1plcqaxisaxiscqcredit;

  wire s_ifextplpcie0cfglpocfginterruptmsifail;
  wire s_ifextplpcie0cfglpocfginterruptmsisent;

  wire [2:0]   s_ifcpmpciea0cfghpicfginterruptmsiattr;
  wire [7:0]   s_ifcpmpciea0cfghpicfginterruptmsifunctionnumber;
  wire [31:0]  s_ifcpmpciea0cfghpicfginterruptmsiint;
  wire         s_ifcpmpciea0cfghpicfginterruptmsitphpresent;
  wire [7:0]   s_ifcpmpciea0cfghpicfginterruptmsitphsttag;
  wire [1:0]   s_ifcpmpciea0cfghpicfginterruptmsitphtype;

//wire s_ifextplpcie1cfglpocfginterruptmsifail;
//wire s_ifextplpcie1cfglpocfginterruptmsisent;

  wire [2:0]   s_ifcpmpciea1cfghpicfginterruptmsiattr;
  wire [7:0]   s_ifcpmpciea1cfghpicfginterruptmsifunctionnumber;
  wire [31:0]  s_ifcpmpciea1cfghpicfginterruptmsiint;
  wire         s_ifcpmpciea1cfghpicfginterruptmsitphpresent;
  wire [7:0]   s_ifcpmpciea1cfghpicfginterruptmsitphsttag;
  wire [1:0]   s_ifcpmpciea1cfghpicfginterruptmsitphtype;

  // Controller 0

  //Output Ports
  assign extplpcie0cfglpocfginterruptmsifail = s_ifextplpcie0cfglpocfginterruptmsifail;
  assign extplpcie0cfglpocfginterruptmsisent = s_ifextplpcie0cfglpocfginterruptmsisent;
  assign ifextplpcie0cfglpocfginterruptmsifail = s_ifextplpcie0cfglpocfginterruptmsifail;
  assign ifextplpcie0cfglpocfginterruptmsisent = s_ifextplpcie0cfglpocfginterruptmsisent;


// Controller 1

    //Output Ports
    //assign extplpcie1cfglpocfginterruptmsifail = s_ifextplpcie1cfglpocfginterruptmsifail;
    //assign extplpcie1cfglpocfginterruptmsisent = s_ifextplpcie1cfglpocfginterruptmsisent;
    //assign ifextplpcie1cfglpocfginterruptmsifail = s_ifextplpcie1cfglpocfginterruptmsifail;
    //assign ifextplpcie1cfglpocfginterruptmsisent = s_ifextplpcie1cfglpocfginterruptmsisent;

  wire [5:0] lpdrclkclk;
  wire [5:0] pmc_pl_ref_clk;
  wire s_axi_gp0_rclk_temp;
  wire s_axi_gp0_wclk_temp;
  wire s_axi_gp2_rclk_temp;
  wire s_axi_gp2_wclk_temp;
  wire s_axi_gp4_rclk_temp;
  wire s_axi_gp4_wclk_temp;

  wire [3:0] usr_capture_i;
  wire [3:0] usr_drck_i;
  wire [3:0] usr_reset_i;
  wire [3:0] usr_runtest_i;
  wire [3:0] usr_sel_i;
  wire [3:0] usr_shift_i;
  wire [3:0] usr_tck_i;
  wire [3:0] usr_tdi_i;
  wire [3:0] usr_tms_i;
  wire [3:0] usr_update_i;
  wire [3:0] usr_tdo_i;

  wire [7:0] pl_ps_irq0_i;
  wire [7:0] pl_ps_irq1_i;
  wire [7:0] pl_ps_irq0_null = 8'h0;
  wire [7:0] pl_ps_irq1_null = 8'h0;
  
  wire [7:0] fmiosd0sdifdatoe_t;
  wire [7:0] fmiosd0sdifdatout_t;
  wire [7:0] fmiosd1sdifdatoe_t;
  wire [7:0] fmiosd1sdifdatout_t;
  
  wire [7:0] sd0_data_in_temp;
  wire [7:0] sd1_data_in_temp;

  //assign pl0_ref_clk = pmc_pl_ref_clk[0];
  //assign pl1_ref_clk = pmc_pl_ref_clk[1];
  //assign pl2_ref_clk = pmc_pl_ref_clk[2];
  //assign pl3_ref_clk = pmc_pl_ref_clk[3];
  
  assign sd0_data_oe =   fmiosd0sdifdatoe_t[C_SD0_DATA_WIDTH-1:0 ];
  assign sd0_data_out =  fmiosd0sdifdatout_t[C_SD0_DATA_WIDTH-1:0 ];
  assign sd1_data_oe =   fmiosd1sdifdatoe_t[C_SD1_DATA_WIDTH-1:0 ];
  assign sd1_data_out =  fmiosd1sdifdatout_t[C_SD1_DATA_WIDTH-1:0 ];
  
  assign sd0_data_in_temp = sd0_data_in;
  assign sd1_data_in_temp = sd1_data_in;

  assign fmio_gem_tsu_clk_to_pl = lpdrclkclk[4];
  assign gem1_fifo_rx_clk_to_pl = lpdrclkclk[3];
  assign gem1_fifo_tx_clk_to_pl = lpdrclkclk[2];
  assign gem0_fifo_rx_clk_to_pl = lpdrclkclk[1];
  assign gem0_fifo_tx_clk_to_pl  = lpdrclkclk[0];

  wire  s_axi_gp2_arready_t;
  wire  s_axi_gp2_awready_t;
  wire [5:0] s_axi_gp2_bid_t;
  wire [1:0] s_axi_gp2_bresp_t;
  wire  s_axi_gp2_bvalid_t;
  wire [3:0] s_axi_gp2_racount_t;
  wire [7:0] s_axi_gp2_rcount_t;
  wire [C_S_AXI_GP2_DATA_WIDTH-1:0] s_axi_gp2_rdata_t;
  wire [5:0] s_axi_gp2_rid_t;
  wire  s_axi_gp2_rlast_t;
  wire [1:0] s_axi_gp2_rresp_t;
  wire  s_axi_gp2_rvalid_t;
  wire [3:0] s_axi_gp2_wacount_t;
  wire [7:0] s_axi_gp2_wcount_t;
  wire  s_axi_gp2_wready_t;
  wire [48:0] s_axi_gp2_araddr_t;
  wire [1:0] s_axi_gp2_arburst_t;
  wire [3:0] s_axi_gp2_arcache_t;
  wire [5:0] s_axi_gp2_arid_t;
  wire [7:0] s_axi_gp2_arlen_t;
  wire  s_axi_gp2_arlock_t;
  wire [2:0] s_axi_gp2_arprot_t;
  wire [3:0] s_axi_gp2_arqos_t;
  wire [2:0] s_axi_gp2_arsize_t;
  wire [17:0] s_axi_gp2_aruser_t;
  wire  s_axi_gp2_arvalid_t;
  wire [48:0] s_axi_gp2_awaddr_t;
  wire [1:0] s_axi_gp2_awburst_t;
  wire [3:0] s_axi_gp2_awcache_t;
  wire [5:0] s_axi_gp2_awid_t;
  wire [7:0] s_axi_gp2_awlen_t;
  wire  s_axi_gp2_awlock_t;
  wire [2:0] s_axi_gp2_awprot_t;
  wire [3:0] s_axi_gp2_awqos_t;
  wire [2:0] s_axi_gp2_awsize_t;
  wire [17:0] s_axi_gp2_awuser_t;
  wire  s_axi_gp2_awvalid_t;
  wire  s_axi_gp2_bready_t;
  wire  s_axi_gp2_rclk_t;
  wire  s_axi_gp2_rready_t;
  wire  s_axi_gp2_wclk_t;
  wire [C_S_AXI_GP2_DATA_WIDTH-1:0] s_axi_gp2_wdata_t;
  wire  s_axi_gp2_wlast_t;
  wire [15:0] s_axi_gp2_wstrb_t;
  wire  s_axi_gp2_wvalid_t;
  wire  s_axi_gp2_aclk_t;

  wire [9:0] rsmid;
  wire [9:0] wsmid;

  wire [31:0] ps_pl_irq_fpd;
  wire [99:0] ps_pl_irq_lpd;
  wire [63:0] ps_pl_irq_pmc;
  wire [7:0] pl_2_adma_cvld_i;
  wire [7:0] pl_2_adma_tack_i;
  wire [7:0] adma_2_pl_cack_i;
  wire [7:0] adma_2_pl_tvld_i;
  wire [7:0] adma_fci_clk_i;

  assign lpd_dma0_cack = adma_2_pl_cack_i[0];
  assign lpd_dma1_cack = adma_2_pl_cack_i[1];
  assign lpd_dma2_cack = adma_2_pl_cack_i[2];
  assign lpd_dma3_cack = adma_2_pl_cack_i[3];
  assign lpd_dma4_cack = adma_2_pl_cack_i[4];
  assign lpd_dma5_cack = adma_2_pl_cack_i[5];
  assign lpd_dma6_cack = adma_2_pl_cack_i[6];
  assign lpd_dma7_cack = adma_2_pl_cack_i[7];
  assign lpd_dma0_tvld = adma_2_pl_tvld_i[0];
  assign lpd_dma1_tvld = adma_2_pl_tvld_i[1];
  assign lpd_dma2_tvld = adma_2_pl_tvld_i[2];
  assign lpd_dma3_tvld = adma_2_pl_tvld_i[3];
  assign lpd_dma4_tvld = adma_2_pl_tvld_i[4];
  assign lpd_dma5_tvld = adma_2_pl_tvld_i[5];
  assign lpd_dma6_tvld = adma_2_pl_tvld_i[6];
  assign lpd_dma7_tvld = adma_2_pl_tvld_i[7];

  assign pl_2_adma_cvld_i[0] = lpd_dma0_cvld;
  assign pl_2_adma_cvld_i[1] = lpd_dma1_cvld;
  assign pl_2_adma_cvld_i[2] = lpd_dma2_cvld;
  assign pl_2_adma_cvld_i[3] = lpd_dma3_cvld;
  assign pl_2_adma_cvld_i[4] = lpd_dma4_cvld;
  assign pl_2_adma_cvld_i[5] = lpd_dma5_cvld;
  assign pl_2_adma_cvld_i[6] = lpd_dma6_cvld;
  assign pl_2_adma_cvld_i[7] = lpd_dma7_cvld;
  assign pl_2_adma_tack_i[0] = lpd_dma0_tack;
  assign pl_2_adma_tack_i[1] = lpd_dma1_tack;
  assign pl_2_adma_tack_i[2] = lpd_dma2_tack;
  assign pl_2_adma_tack_i[3] = lpd_dma3_tack;
  assign pl_2_adma_tack_i[4] = lpd_dma4_tack;
  assign pl_2_adma_tack_i[5] = lpd_dma5_tack;
  assign pl_2_adma_tack_i[6] = lpd_dma6_tack;
  assign pl_2_adma_tack_i[7] = lpd_dma7_tack;

  assign adma_fci_clk_i[0] = lpd_dma_clk0;
  assign adma_fci_clk_i[1] = lpd_dma_clk1;
  assign adma_fci_clk_i[2] = lpd_dma_clk2;
  assign adma_fci_clk_i[3] = lpd_dma_clk3;
  assign adma_fci_clk_i[4] = lpd_dma_clk4;
  assign adma_fci_clk_i[5] = lpd_dma_clk5;
  assign adma_fci_clk_i[6] = lpd_dma_clk6;
  assign adma_fci_clk_i[7] = lpd_dma_clk7;


 //.PL2ADMACVLD(pl_2_adma_cvld),
 //.PL2ADMATACK(pl_2_adma_tack),

  wire cpmdpllpcie0userclk_loc;
  wire cpmdpllpcie1userclk_loc;
  wire [1:0]  ifplextpcie0axipciecompldelivered;
  wire [7:0]  ifplextpcie0axipciecompldeliveredtag0;
  wire [7:0]  ifplextpcie0axipciecompldeliveredtag1;
  wire        ifplextpcie0axipciecqnpusercreditrcvd;
  wire        ifplextpcie0axipciecqpipelineempty;
  wire        ifplextpcie0axipciepostedreqdelivered;
  wire        ifplextpcie0axitlrxcomplcreditreleased;
  wire [1:0]  ifplextpcie0axitlrxcomplheadercreditreleasedvalue;
  wire [6:0]  ifplextpcie0axitlrxcomplpayloadcreditreleasedvalue;
  wire        ifplextpcie0axitlrxnonpostedcreditreleased;
  wire [1:0]  ifplextpcie0axitlrxnonpostedpayloadcreditreleasedvalue;
  wire        ifplextpcie0axitlrxpostedcreditreleased;
  wire [6:0]  ifplextpcie0axitlrxpostedpayloadcreditreleasedvalue;
  wire [1:0]  ifplextpcie1axipciecompldelivered;
  wire [7:0]  ifplextpcie1axipciecompldeliveredtag0;
  wire [7:0]  ifplextpcie1axipciecompldeliveredtag1;
  wire        ifplextpcie1axipciecqnpusercreditrcvd;
  wire        ifplextpcie1axipciecqpipelineempty;
  wire        ifplextpcie1axipciepostedreqdelivered;
  wire        ifplextpcie1axitlrxcomplcreditreleased;
  wire [1:0]  ifplextpcie1axitlrxcomplheadercreditreleasedvalue;
  wire [6:0]  ifplextpcie1axitlrxcomplpayloadcreditreleasedvalue;
  wire        ifplextpcie1axitlrxnonpostedcreditreleased;
  wire [1:0]  ifplextpcie1axitlrxnonpostedpayloadcreditreleasedvalue;
  wire        ifplextpcie1axitlrxpostedcreditreleased;
  wire [6:0]  ifplextpcie1axitlrxpostedpayloadcreditreleasedvalue;
  wire [511:0]  ifextplpcie0unifiedcqaxisaxiscqtdata;
  wire [15:0]   ifextplpcie0unifiedcqaxisaxiscqtkeep;
  wire [228:0]  ifextplpcie0unifiedcqaxisaxiscqtuser;
  wire      ifextplpcie0unifiedcqaxisaxisport0cqtlast;
  wire      ifextplpcie0unifiedcqaxisaxisport0rctlast;
  wire      ifextplpcie0unifiedcqaxisaxisport1cqtlast;
  wire      ifextplpcie0unifiedcqaxisaxisport1rctlast;
  wire      ifextplpcie0unifiedcqaxispcieaxisport0cqvld;
  wire      ifextplpcie0unifiedcqaxispcieaxisport0rcvld;
  wire      ifextplpcie0unifiedcqaxispcieaxisport1cqvld;
  wire      ifextplpcie0unifiedcqaxispcieaxisport1rcvld;
  wire [511:0]  ifextplpcie1unifiedcqaxisaxiscqtdata;
  wire [15:0]   ifextplpcie1unifiedcqaxisaxiscqtkeep;
  wire [228:0]  ifextplpcie1unifiedcqaxisaxiscqtuser;
  wire ifextplpcie1unifiedcqaxisaxisport0cqtlast;
  wire ifextplpcie1unifiedcqaxisaxisport0rctlast;
  wire ifextplpcie1unifiedcqaxisaxisport1cqtlast;
  wire ifextplpcie1unifiedcqaxisaxisport1rctlast;
  wire ifextplpcie1unifiedcqaxispcieaxisport0cqvld;
  wire ifextplpcie1unifiedcqaxispcieaxisport0rcvld;
  wire ifextplpcie1unifiedcqaxispcieaxisport1cqvld;
  wire ifextplpcie1unifiedcqaxispcieaxisport1rcvld;
  wire ifextplpcie0unifiedcqaxispcieaxisport0cqcrdt;
  wire ifextplpcie0unifiedcqaxispcieaxisport0rccrdt;
  wire ifextplpcie0unifiedcqaxispcieaxisport1cqcrdt;
  wire ifextplpcie0unifiedcqaxispcieaxisport1rccrdt;
  wire ifextplpcie1unifiedcqaxispcieaxisport0cqcrdt;
  wire ifextplpcie1unifiedcqaxispcieaxisport0rccrdt;
  wire ifextplpcie1unifiedcqaxispcieaxisport1cqcrdt;
  wire ifextplpcie1unifiedcqaxispcieaxisport1rccrdt;
  wire ifcpmpcieadplldpll0cpmlocked;
  wire ifcpmpcieadpllcpmdpll0rstn;
  wire ifcpmpcieadplldpll1cpmlocked;
  wire ifcpmpcieadpllcpmdpll1rstn;

// Additional wires
  wire         s_axis_rq_tvalid;
  wire [511:0] s_axis_rq_tdata;
  wire [15:0]  s_axis_rq_tkeep;
  wire         s_axis_rq_tlast;
  wire [136:0] s_axis_rq_tuser;
  wire [3:0]   s_axis_rq_tready;

  wire         s_axis_cc_tvalid;
  wire [511:0] s_axis_cc_tdata;
  wire [15:0]  s_axis_cc_tkeep;
  wire         s_axis_cc_tlast;
  wire [136:0] s_axis_cc_tuser;
  wire [3:0]   s_axis_cc_tready;

   // CPM - PS Wires

//   wire  perst0n;
//   wire  perst1n;
   wire [63:0]  ifcpmpsaxi0araddr;
   wire [1:0]   ifcpmpsaxi0arburst;
   wire [3:0]   ifcpmpsaxi0arcache;
   wire [15:0]  ifcpmpsaxi0arid;
   wire [7:0]   ifcpmpsaxi0arlen;
   wire [0:0]   ifcpmpsaxi0arlock;
   wire [2:0]   ifcpmpsaxi0arprot;
   wire [3:0]   ifcpmpsaxi0arqos;
   wire [3:0]   ifcpmpsaxi0arregion;
   wire [2:0]   ifcpmpsaxi0arsize;
   wire [31:0]  ifcpmpsaxi0aruser;
   wire         ifcpmpsaxi0arvalid;
   wire [63:0]  ifcpmpsaxi0awaddr;
   wire [1:0]   ifcpmpsaxi0awburst;
   wire [3:0]   ifcpmpsaxi0awcache;
   wire [15:0]  ifcpmpsaxi0awid;
   wire [7:0]   ifcpmpsaxi0awlen;
   wire [0:0]   ifcpmpsaxi0awlock;
   wire [2:0]   ifcpmpsaxi0awprot;
   wire [3:0]   ifcpmpsaxi0awqos;
   wire [3:0]   ifcpmpsaxi0awregion;
   wire [2:0]   ifcpmpsaxi0awsize;
   wire [31:0]  ifcpmpsaxi0awuser;
   wire         ifcpmpsaxi0awvalid;
   wire         ifcpmpsaxi0bready;
   wire         ifcpmpsaxi0rready;
   wire [127:0] ifcpmpsaxi0wdata;
   wire [15:0]  ifcpmpsaxi0wid;
   wire [0:0]   ifcpmpsaxi0wlast;
   wire [15:0]  ifcpmpsaxi0wstrb;
   wire [17:0]  ifcpmpsaxi0wuser;
   wire         ifcpmpsaxi0wvalid;
   wire [15:0]  ifcpmpsaxi0bid;
   wire         ifcpmpsaxi0arready;
   wire         ifcpmpsaxi0rvalid;
   wire         ifcpmpsaxi0bvalid;
   wire         ifcpmpsaxi0wready;
   wire         ifcpmpsaxi0awready;
   wire [1:0]   ifcpmpsaxi0bresp;
   wire [0:0]   ifcpmpsaxi0buser;
   wire [127:0] ifcpmpsaxi0rdata;
   wire [15:0]  ifcpmpsaxi0rid;
   wire [0:0]   ifcpmpsaxi0rlast;
   wire [1:0]   ifcpmpsaxi0rresp;
   wire [17:0]  ifcpmpsaxi0ruser;

   wire [15:0]  ifcpmpsaxi1bid;
   wire         ifcpmpsaxi1arready;
   wire         ifcpmpsaxi1rvalid;
   wire         ifcpmpsaxi1bvalid;
   wire         ifcpmpsaxi1wready;
   wire         ifcpmpsaxi1awready;
   wire [1:0]   ifcpmpsaxi1bresp;
   wire [15:0]  ifcpmpsaxi1buser;
   wire [127:0] ifcpmpsaxi1rdata;
   wire [15:0]  ifcpmpsaxi1rid;
   wire [0:0]   ifcpmpsaxi1rlast;
   wire [1:0]   ifcpmpsaxi1rresp;
   wire [16:0]  ifcpmpsaxi1ruser;
   wire [63:0]  ifcpmpsaxi1araddr;
   wire [1:0]   ifcpmpsaxi1arburst;
   wire [3:0]   ifcpmpsaxi1arcache;
   wire [15:0]  ifcpmpsaxi1arid;
   wire [7:0]   ifcpmpsaxi1arlen;
   wire [0:0]   ifcpmpsaxi1arlock;
   wire [2:0]   ifcpmpsaxi1arprot;
   wire [3:0]   ifcpmpsaxi1arqos;
   wire [3:0]   ifcpmpsaxi1arregion;
   wire [2:0]   ifcpmpsaxi1arsize;
   wire [17:0]  ifcpmpsaxi1aruser;
   wire         ifcpmpsaxi1arvalid;
   wire [63:0]  ifcpmpsaxi1awaddr;
   wire [1:0]   ifcpmpsaxi1awburst;
   wire [3:0]   ifcpmpsaxi1awcache;
   wire [15:0]  ifcpmpsaxi1awid;
   wire [7:0]   ifcpmpsaxi1awlen;
   wire [0:0]   ifcpmpsaxi1awlock;
   wire [2:0]   ifcpmpsaxi1awprot;
   wire [3:0]   ifcpmpsaxi1awqos;
   wire [3:0]   ifcpmpsaxi1awregion;
   wire [2:0]   ifcpmpsaxi1awsize;
   wire [17:0]  ifcpmpsaxi1awuser;
   wire         ifcpmpsaxi1awvalid;
   wire         ifcpmpsaxi1bready;
   wire         ifcpmpsaxi1rready;
   wire [127:0] ifcpmpsaxi1wdata;
   wire [15:0]  ifcpmpsaxi1wid;
   wire [0:0]   ifcpmpsaxi1wlast;
   wire [15:0]  ifcpmpsaxi1wstrb;
   wire [16:0]  ifcpmpsaxi1wuser;
   wire         ifcpmpsaxi1wvalid;

   wire [63:0]  ifpscpmcfgaxiaraddr;
   wire [1:0]   ifpscpmcfgaxiarburst;
   wire [3:0]   ifpscpmcfgaxiarcache;
   wire [15:0]  ifpscpmcfgaxiarid;
   wire [7:0]   ifpscpmcfgaxiarlen;
   wire [0:0]   ifpscpmcfgaxiarlock;
   wire [2:0]   ifpscpmcfgaxiarprot;
   wire [3:0]   ifpscpmcfgaxiarqos;
   wire [3:0]   ifpscpmcfgaxiarregion;
   wire [2:0]   ifpscpmcfgaxiarsize;
   wire [15:0]  ifpscpmcfgaxiaruser;
   wire         ifpscpmcfgaxiarvalid;
   wire [63:0]  ifpscpmcfgaxiawaddr;
   wire [1:0]   ifpscpmcfgaxiawburst;
   wire [3:0]   ifpscpmcfgaxiawcache;
   wire [15:0]  ifpscpmcfgaxiawid;
   wire [7:0]   ifpscpmcfgaxiawlen;
   wire [0:0]   ifpscpmcfgaxiawlock;
   wire [2:0]   ifpscpmcfgaxiawprot;
   wire [3:0]   ifpscpmcfgaxiawqos;
   wire [3:0]   ifpscpmcfgaxiawregion;
   wire [2:0]   ifpscpmcfgaxiawsize;
   wire [15:0]  ifpscpmcfgaxiawuser;
   wire         ifpscpmcfgaxiawvalid;
   wire         ifpscpmcfgaxibready;
   wire         ifpscpmcfgaxirready;
   wire [31:0]  ifpscpmcfgaxiwdata;
   wire [15:0]  ifpscpmcfgaxiwid;
   wire [0:0]   ifpscpmcfgaxiwlast;
   wire [3:0]   ifpscpmcfgaxiwstrb;
   wire [5:0]   ifpscpmcfgaxiwuser;
   wire         ifpscpmcfgaxiwvalid;
   wire         ifpscpmcfgaxiarready;
   wire         ifpscpmcfgaxiawready;
   wire [15:0]  ifpscpmcfgaxibid;
   wire [1:0]   ifpscpmcfgaxibresp;
   wire [0:0]   ifpscpmcfgaxibuser;
   wire         ifpscpmcfgaxibvalid;
   wire [31:0]  ifpscpmcfgaxirdata;
   wire [15:0]  ifpscpmcfgaxirid;
   wire [0:0]   ifpscpmcfgaxirlast;
   wire [1:0]   ifpscpmcfgaxirresp;
   wire [5:0]   ifpscpmcfgaxiruser;
   wire         ifpscpmcfgaxirvalid;
   wire         ifpscpmcfgaxiwready;
   wire         ifpscpmpcieaxiarready;
   wire         ifpscpmpcieaxiawready;
   wire [15:0]  ifpscpmpcieaxibid;
   wire [1:0]   ifpscpmpcieaxibresp;
   wire [15:0]  ifpscpmpcieaxibuser;
   wire         ifpscpmpcieaxibvalid;
   wire [127:0] ifpscpmpcieaxirdata;
   wire [15:0]  ifpscpmpcieaxirid;
   wire [0:0]   ifpscpmpcieaxirlast;
   wire [1:0]   ifpscpmpcieaxirresp;
   wire [16:0]  ifpscpmpcieaxiruser;
   wire         ifpscpmpcieaxirvalid;
   wire         ifpscpmpcieaxiwready;
   wire [63:0]  ifpscpmpcieaxiaraddr;
   wire [1:0]   ifpscpmpcieaxiarburst;
   wire [3:0]   ifpscpmpcieaxiarcache;
   wire [15:0]  ifpscpmpcieaxiarid;
   wire [7:0]   ifpscpmpcieaxiarlen;
   wire [0:0]   ifpscpmpcieaxiarlock;
   wire [2:0]   ifpscpmpcieaxiarprot;
   wire [3:0]   ifpscpmpcieaxiarqos;
   wire [3:0]   ifpscpmpcieaxiarregion;
   wire [2:0]   ifpscpmpcieaxiarsize;
   wire [17:0]  ifpscpmpcieaxiaruser;
   wire         ifpscpmpcieaxiarvalid;
   wire [63:0]  ifpscpmpcieaxiawaddr;
   wire [1:0]   ifpscpmpcieaxiawburst;
   wire [3:0]   ifpscpmpcieaxiawcache;
   wire [15:0]  ifpscpmpcieaxiawid;
   wire [7:0]   ifpscpmpcieaxiawlen;
   wire [0:0]   ifpscpmpcieaxiawlock;
   wire [2:0]   ifpscpmpcieaxiawprot;
   wire [3:0]   ifpscpmpcieaxiawqos;
   wire [3:0]   ifpscpmpcieaxiawregion;
   wire [2:0]   ifpscpmpcieaxiawsize;
   wire [17:0]  ifpscpmpcieaxiawuser;
   wire         ifpscpmpcieaxiawvalid;
   wire         ifpscpmpcieaxibready;
   wire         ifpscpmpcieaxirready;
   wire [127:0] ifpscpmpcieaxiwdata;
   wire [15:0]  ifpscpmpcieaxiwid;
   wire [0:0]   ifpscpmpcieaxiwlast;
   wire [15:0]  ifpscpmpcieaxiwstrb;
   wire [16:0]  ifpscpmpcieaxiwuser;
   wire         ifpscpmpcieaxiwvalid;

   wire  ifpscpmpcsrpcrapben;
   wire  ifpscpmpcsrpcrdisnpiclk;
   wire  ifpscpmpcsrpcrfabricen;
   wire  ifpscpmpcsrpcrgatereg;
   wire  ifpscpmpcsrpcrholdstate;
   wire  ifpscpmpcsrpcrinitstate;
   wire  ifpscpmpcsrpcrmemclr;
   wire [3:0] ifpscpmpcsrpcrodisable;
   wire  ifpscpmpcsrpcrpcomplete;
   wire  ifpscpmpcsrpcrpwrdn;
   wire  ifpscpmpcsrpcrscanclr;
   wire  ifpscpmpcsrpcrstartbisr;
   wire  ifpscpmpcsrpcrstartcal;
   wire  ifpscpmpcsrpcrtristate;

   wire  ifcpmpsisrcorrevent;
   wire  ifcpmpsisrmiscevent;
   wire  ifcpmpsisruncorrevent;
   wire  ifpscpmchannel0xpipephystatus;
   wire [1:0] ifpscpmchannel0xpiperxcharisk;
   wire [31:0] ifpscpmchannel0xpiperxdata;
   wire  ifpscpmchannel0xpiperxdatavalid;
   wire  ifpscpmchannel0xpiperxelecidle;
   wire  ifpscpmchannel0xpiperxstartblock;
   wire [2:0] ifpscpmchannel0xpiperxstatus;
   wire [1:0] ifpscpmchannel0xpiperxsyncheader;
   wire [1:0] ifpscpmchannel0xpipepowerdown;
   wire  ifpscpmchannel0xpiperxpolarity;
   wire  ifpscpmchannel0xpiperxtermination;
   wire [1:0] ifpscpmchannel0xpipetxcharisk;
   wire  ifpscpmchannel0xpipetxcompliance;
   wire [31:0] ifpscpmchannel0xpipetxdata;
   wire  ifpscpmchannel0xpipetxdatavalid;
   wire  ifpscpmchannel0xpipetxdeemph;
   wire  ifpscpmchannel0xpipetxdetectrxloopback;
   wire  ifpscpmchannel0xpipetxelecidle;
   wire [6:0] ifpscpmchannel0xpipetxmaincursor;
   wire [2:0] ifpscpmchannel0xpipetxmargin;
   wire [4:0] ifpscpmchannel0xpipetxpostcursor;
   wire [4:0] ifpscpmchannel0xpipetxprecursor;
   wire  ifpscpmchannel0xpipetxstartblock;
   wire  ifpscpmchannel0xpipetxswing;
   wire [1:0] ifpscpmchannel0xpipetxsyncheader;
   wire  ifpscpmchannel0xpiperxvalid;
   wire  ifpscpmchannel10xpipephystatus;
   wire [1:0] ifpscpmchannel10xpiperxcharisk;
   wire [31:0] ifpscpmchannel10xpiperxdata;
   wire  ifpscpmchannel10xpiperxdatavalid;
   wire  ifpscpmchannel10xpiperxelecidle;
   wire  ifpscpmchannel10xpiperxstartblock;
   wire [2:0] ifpscpmchannel10xpiperxstatus;
   wire [1:0] ifpscpmchannel10xpiperxsyncheader;
   wire  ifpscpmchannel10xpiperxvalid;
   wire  ifpscpmchannel11xpipephystatus;
   wire [1:0] ifpscpmchannel11xpiperxcharisk;
   wire [31:0] ifpscpmchannel11xpiperxdata;
   wire  ifpscpmchannel11xpiperxdatavalid;
   wire  ifpscpmchannel11xpiperxelecidle;
   wire  ifpscpmchannel11xpiperxstartblock;
   wire [2:0] ifpscpmchannel11xpiperxstatus;
   wire [1:0] ifpscpmchannel11xpiperxsyncheader;
   wire  ifpscpmchannel11xpiperxvalid;
   wire  ifpscpmchannel12xpipephystatus;
   wire [1:0] ifpscpmchannel12xpiperxcharisk;
   wire [31:0] ifpscpmchannel12xpiperxdata;
   wire  ifpscpmchannel12xpiperxdatavalid;
   wire  ifpscpmchannel12xpiperxelecidle;
   wire  ifpscpmchannel12xpiperxstartblock;
   wire [2:0] ifpscpmchannel12xpiperxstatus;
   wire [1:0] ifpscpmchannel12xpiperxsyncheader;
   wire  ifpscpmchannel12xpiperxvalid;
   wire  ifpscpmchannel13xpipephystatus;
   wire [1:0] ifpscpmchannel13xpiperxcharisk;
   wire [31:0] ifpscpmchannel13xpiperxdata;
   wire  ifpscpmchannel13xpiperxdatavalid;
   wire  ifpscpmchannel13xpiperxelecidle;
   wire  ifpscpmchannel13xpiperxstartblock;
   wire [2:0] ifpscpmchannel13xpiperxstatus;
   wire [1:0] ifpscpmchannel13xpiperxsyncheader;
   wire  ifpscpmchannel13xpiperxvalid;
   wire  ifpscpmchannel14xpipephystatus;
   wire [1:0] ifpscpmchannel14xpiperxcharisk;
   wire [31:0] ifpscpmchannel14xpiperxdata;
   wire  ifpscpmchannel14xpiperxdatavalid;
   wire  ifpscpmchannel14xpiperxelecidle;
   wire  ifpscpmchannel14xpiperxstartblock;
   wire [2:0] ifpscpmchannel14xpiperxstatus;
   wire [1:0] ifpscpmchannel14xpiperxsyncheader;
   wire  ifpscpmchannel14xpiperxvalid;
   wire  ifpscpmchannel15xpipephystatus;
   wire [1:0] ifpscpmchannel15xpiperxcharisk;
   wire [31:0] ifpscpmchannel15xpiperxdata;
   wire  ifpscpmchannel15xpiperxdatavalid;
   wire  ifpscpmchannel15xpiperxelecidle;
   wire  ifpscpmchannel15xpiperxstartblock;
   wire [2:0] ifpscpmchannel15xpiperxstatus;
   wire [1:0] ifpscpmchannel15xpiperxsyncheader;
   wire  ifpscpmchannel15xpiperxvalid;
   wire  ifpscpmchannel1xpipephystatus;
   wire [1:0] ifpscpmchannel1xpiperxcharisk;
   wire [31:0] ifpscpmchannel1xpiperxdata;
   wire  ifpscpmchannel1xpiperxdatavalid;
   wire  ifpscpmchannel1xpiperxelecidle;
   wire  ifpscpmchannel1xpiperxstartblock;
   wire [2:0] ifpscpmchannel1xpiperxstatus;
   wire [1:0] ifpscpmchannel1xpiperxsyncheader;
   wire  ifpscpmchannel1xpiperxvalid;
   wire  ifpscpmchannel2xpipephystatus;
   wire [1:0] ifpscpmchannel2xpiperxcharisk;
   wire [31:0] ifpscpmchannel2xpiperxdata;
   wire  ifpscpmchannel2xpiperxdatavalid;
   wire  ifpscpmchannel2xpiperxelecidle;
   wire  ifpscpmchannel2xpiperxstartblock;
   wire [2:0] ifpscpmchannel2xpiperxstatus;
   wire [1:0] ifpscpmchannel2xpiperxsyncheader;
   wire  ifpscpmchannel2xpiperxvalid;
   wire  ifpscpmchannel3xpipephystatus;
   wire [1:0] ifpscpmchannel3xpiperxcharisk;
   wire [31:0] ifpscpmchannel3xpiperxdata;
   wire  ifpscpmchannel3xpiperxdatavalid;
   wire  ifpscpmchannel3xpiperxelecidle;
   wire  ifpscpmchannel3xpiperxstartblock;
   wire [2:0] ifpscpmchannel3xpiperxstatus;
   wire [1:0] ifpscpmchannel3xpiperxsyncheader;
   wire  ifpscpmchannel3xpiperxvalid;
   wire  ifpscpmchannel4xpipephystatus;
   wire [1:0] ifpscpmchannel4xpiperxcharisk;
   wire [31:0] ifpscpmchannel4xpiperxdata;
   wire  ifpscpmchannel4xpiperxdatavalid;
   wire  ifpscpmchannel4xpiperxelecidle;
   wire  ifpscpmchannel4xpiperxstartblock;
   wire [2:0] ifpscpmchannel4xpiperxstatus;
   wire [1:0] ifpscpmchannel4xpiperxsyncheader;
   wire  ifpscpmchannel4xpiperxvalid;
   wire  ifpscpmchannel5xpipephystatus;
   wire [1:0] ifpscpmchannel5xpiperxcharisk;
   wire [31:0] ifpscpmchannel5xpiperxdata;
   wire  ifpscpmchannel5xpiperxdatavalid;
   wire  ifpscpmchannel5xpiperxelecidle;
   wire  ifpscpmchannel5xpiperxstartblock;
   wire [2:0] ifpscpmchannel5xpiperxstatus;
   wire [1:0] ifpscpmchannel5xpiperxsyncheader;
   wire  ifpscpmchannel5xpiperxvalid;
   wire  ifpscpmchannel6xpipephystatus;
   wire [1:0] ifpscpmchannel6xpiperxcharisk;
   wire [31:0] ifpscpmchannel6xpiperxdata;
   wire  ifpscpmchannel6xpiperxdatavalid;
   wire  ifpscpmchannel6xpiperxelecidle;
   wire  ifpscpmchannel6xpiperxstartblock;
   wire [2:0] ifpscpmchannel6xpiperxstatus;
   wire [1:0] ifpscpmchannel6xpiperxsyncheader;
   wire  ifpscpmchannel6xpiperxvalid;
   wire  ifpscpmchannel7xpipephystatus;
   wire [1:0] ifpscpmchannel7xpiperxcharisk;
   wire [31:0] ifpscpmchannel7xpiperxdata;
   wire  ifpscpmchannel7xpiperxdatavalid;
   wire  ifpscpmchannel7xpiperxelecidle;
   wire  ifpscpmchannel7xpiperxstartblock;
   wire [2:0] ifpscpmchannel7xpiperxstatus;
   wire [1:0] ifpscpmchannel7xpiperxsyncheader;
   wire  ifpscpmchannel7xpiperxvalid;
   wire  ifpscpmchannel8xpipephystatus;
   wire [1:0] ifpscpmchannel8xpiperxcharisk;
   wire [31:0] ifpscpmchannel8xpiperxdata;
   wire  ifpscpmchannel8xpiperxdatavalid;
   wire  ifpscpmchannel8xpiperxelecidle;
   wire  ifpscpmchannel8xpiperxstartblock;
   wire [2:0] ifpscpmchannel8xpiperxstatus;
   wire [1:0] ifpscpmchannel8xpiperxsyncheader;
   wire  ifpscpmchannel8xpiperxvalid;
   wire  ifpscpmchannel9xpipephystatus;
   wire [1:0] ifpscpmchannel9xpiperxcharisk;
   wire [31:0] ifpscpmchannel9xpiperxdata;
   wire  ifpscpmchannel9xpiperxdatavalid;
   wire  ifpscpmchannel9xpiperxelecidle;
   wire  ifpscpmchannel9xpiperxstartblock;
   wire [2:0] ifpscpmchannel9xpiperxstatus;
   wire [1:0] ifpscpmchannel9xpiperxsyncheader;
   wire  ifpscpmchannel9xpiperxvalid;
   wire  ifpscpmhsdpchannel0xpiperxdatavalid;
   wire [1:0] ifpscpmhsdpchannel0xpiperxheader;
   wire  ifpscpmhsdpchannel0xpiperxheadervalid;
   wire  ifpscpmhsdpchannel0xpiperxresetdone;
   wire  ifpscpmhsdpchannel0xpipetxresetdone;
   wire  ifpscpmhsdpchannel1xpiperxdatavalid;
   wire [1:0] ifpscpmhsdpchannel1xpiperxheader;
   wire  ifpscpmhsdpchannel1xpiperxheadervalid;
   wire  ifpscpmhsdpchannel1xpiperxresetdone;
   wire  ifpscpmhsdpchannel1xpipetxresetdone;
   wire  ifpscpmhsdpchannel2xpiperxdatavalid;
   wire [1:0] ifpscpmhsdpchannel2xpiperxheader;
   wire  ifpscpmhsdpchannel2xpiperxheadervalid;
   wire  ifpscpmhsdpchannel2xpiperxresetdone;
   wire  ifpscpmhsdpchannel2xpipetxresetdone;
   wire  ifpscpmhsdplinkxpipegtrxoutclk;
   wire  ifpscpmintquadxpipephyreadytobot;
   wire  ifpscpmlink0xpipebufgtce;
   wire [3:0] ifpscpmlink0xpipebufgtcemask;
   wire [11:0] ifpscpmlink0xpipebufgtdiv;
   wire  ifpscpmlink0xpipebufgtrst;
   wire [3:0] ifpscpmlink0xpipebufgtrstmask;
   wire  ifpscpmlink0xpipegtoutclk;
   wire  ifpscpmlink0xpipephyready;
   wire  ifpscpmlink1xpipebufgtce;
   wire [3:0] ifpscpmlink1xpipebufgtcemask;
   wire [11:0] ifpscpmlink1xpipebufgtdiv;
   wire  ifpscpmlink1xpipebufgtrst;
   wire [3:0] ifpscpmlink1xpipebufgtrstmask;
   wire  ifpscpmlink1xpipegtoutclk;
   wire  ifpscpmlink1xpipephyready;
   wire  ifpscpmquad0xpiperxmarginreqack;
   wire [3:0] ifpscpmquad0xpiperxmarginrescmd;
   wire [1:0] ifpscpmquad0xpiperxmarginreslanenum;
   wire [7:0] ifpscpmquad0xpiperxmarginrespayload;
   wire  ifpscpmquad0xpiperxmarginresreq;
   wire  ifpscpmquad1xpiperxmarginreqack;
   wire [3:0] ifpscpmquad1xpiperxmarginrescmd;
   wire [1:0] ifpscpmquad1xpiperxmarginreslanenum;
   wire [7:0] ifpscpmquad1xpiperxmarginrespayload;
   wire  ifpscpmquad1xpiperxmarginresreq;
   wire  ifpscpmquad2xpiperxmarginreqack;
   wire [3:0] ifpscpmquad2xpiperxmarginrescmd;
   wire [1:0] ifpscpmquad2xpiperxmarginreslanenum;
   wire [7:0] ifpscpmquad2xpiperxmarginrespayload;
   wire  ifpscpmquad2xpiperxmarginresreq;
   wire  ifpscpmquad3xpiperxmarginreqack;
   wire [3:0] ifpscpmquad3xpiperxmarginrescmd;
   wire [1:0] ifpscpmquad3xpiperxmarginreslanenum;
   wire [7:0] ifpscpmquad3xpiperxmarginrespayload;
   wire  ifpscpmquad3xpiperxmarginresreq;

   wire [1:0] ifpscpmchannel10xpipepowerdown;
   wire  ifpscpmchannel10xpiperxpolarity;
   wire  ifpscpmchannel10xpiperxtermination;
   wire [1:0] ifpscpmchannel10xpipetxcharisk;
   wire  ifpscpmchannel10xpipetxcompliance;
   wire [31:0] ifpscpmchannel10xpipetxdata;
   wire  ifpscpmchannel10xpipetxdatavalid;
   wire  ifpscpmchannel10xpipetxdeemph;
   wire  ifpscpmchannel10xpipetxdetectrxloopback;
   wire  ifpscpmchannel10xpipetxelecidle;
   wire [6:0] ifpscpmchannel10xpipetxmaincursor;
   wire [2:0] ifpscpmchannel10xpipetxmargin;
   wire [4:0] ifpscpmchannel10xpipetxpostcursor;
   wire [4:0] ifpscpmchannel10xpipetxprecursor;
   wire  ifpscpmchannel10xpipetxstartblock;
   wire  ifpscpmchannel10xpipetxswing;
   wire [1:0] ifpscpmchannel10xpipetxsyncheader;
   wire [1:0] ifpscpmchannel11xpipepowerdown;
   wire  ifpscpmchannel11xpiperxpolarity;
   wire  ifpscpmchannel11xpiperxtermination;
   wire [1:0] ifpscpmchannel11xpipetxcharisk;
   wire  ifpscpmchannel11xpipetxcompliance;
   wire [31:0] ifpscpmchannel11xpipetxdata;
   wire  ifpscpmchannel11xpipetxdatavalid;
   wire  ifpscpmchannel11xpipetxdeemph;
   wire  ifpscpmchannel11xpipetxdetectrxloopback;
   wire  ifpscpmchannel11xpipetxelecidle;
   wire [6:0] ifpscpmchannel11xpipetxmaincursor;
   wire [2:0] ifpscpmchannel11xpipetxmargin;
   wire [4:0] ifpscpmchannel11xpipetxpostcursor;
   wire [4:0] ifpscpmchannel11xpipetxprecursor;
   wire  ifpscpmchannel11xpipetxstartblock;
   wire  ifpscpmchannel11xpipetxswing;
   wire [1:0] ifpscpmchannel11xpipetxsyncheader;
   wire [1:0] ifpscpmchannel12xpipepowerdown;
   wire  ifpscpmchannel12xpiperxpolarity;
   wire  ifpscpmchannel12xpiperxtermination;
   wire [1:0] ifpscpmchannel12xpipetxcharisk;
   wire  ifpscpmchannel12xpipetxcompliance;
   wire [31:0] ifpscpmchannel12xpipetxdata;
   wire  ifpscpmchannel12xpipetxdatavalid;
   wire  ifpscpmchannel12xpipetxdeemph;
   wire  ifpscpmchannel12xpipetxdetectrxloopback;
   wire  ifpscpmchannel12xpipetxelecidle;
   wire [6:0] ifpscpmchannel12xpipetxmaincursor;
   wire [2:0] ifpscpmchannel12xpipetxmargin;
   wire [4:0] ifpscpmchannel12xpipetxpostcursor;
   wire [4:0] ifpscpmchannel12xpipetxprecursor;
   wire  ifpscpmchannel12xpipetxstartblock;
   wire  ifpscpmchannel12xpipetxswing;
   wire [1:0] ifpscpmchannel12xpipetxsyncheader;
   wire [1:0] ifpscpmchannel13xpipepowerdown;
   wire  ifpscpmchannel13xpiperxpolarity;
   wire  ifpscpmchannel13xpiperxtermination;
   wire [1:0] ifpscpmchannel13xpipetxcharisk;
   wire  ifpscpmchannel13xpipetxcompliance;
   wire [31:0] ifpscpmchannel13xpipetxdata;
   wire  ifpscpmchannel13xpipetxdatavalid;
   wire  ifpscpmchannel13xpipetxdeemph;
   wire  ifpscpmchannel13xpipetxdetectrxloopback;
   wire  ifpscpmchannel13xpipetxelecidle;
   wire [6:0] ifpscpmchannel13xpipetxmaincursor;
   wire [2:0] ifpscpmchannel13xpipetxmargin;
   wire [4:0] ifpscpmchannel13xpipetxpostcursor;
   wire [4:0] ifpscpmchannel13xpipetxprecursor;
   wire  ifpscpmchannel13xpipetxstartblock;
   wire  ifpscpmchannel13xpipetxswing;
   wire [1:0] ifpscpmchannel13xpipetxsyncheader;
   wire [1:0] ifpscpmchannel14xpipepowerdown;
   wire  ifpscpmchannel14xpiperxpolarity;
   wire  ifpscpmchannel14xpiperxtermination;
   wire [1:0] ifpscpmchannel14xpipetxcharisk;
   wire  ifpscpmchannel14xpipetxcompliance;
   wire [31:0] ifpscpmchannel14xpipetxdata;
   wire  ifpscpmchannel14xpipetxdatavalid;
   wire  ifpscpmchannel14xpipetxdeemph;
   wire  ifpscpmchannel14xpipetxdetectrxloopback;
   wire  ifpscpmchannel14xpipetxelecidle;
   wire [6:0] ifpscpmchannel14xpipetxmaincursor;
   wire [2:0] ifpscpmchannel14xpipetxmargin;
   wire [4:0] ifpscpmchannel14xpipetxpostcursor;
   wire [4:0] ifpscpmchannel14xpipetxprecursor;
   wire  ifpscpmchannel14xpipetxstartblock;
   wire  ifpscpmchannel14xpipetxswing;
   wire [1:0] ifpscpmchannel14xpipetxsyncheader;
   wire [1:0] ifpscpmchannel15xpipepowerdown;
   wire  ifpscpmchannel15xpiperxpolarity;
   wire  ifpscpmchannel15xpiperxtermination;
   wire [1:0] ifpscpmchannel15xpipetxcharisk;
   wire  ifpscpmchannel15xpipetxcompliance;
   wire [31:0] ifpscpmchannel15xpipetxdata;
   wire  ifpscpmchannel15xpipetxdatavalid;
   wire  ifpscpmchannel15xpipetxdeemph;
   wire  ifpscpmchannel15xpipetxdetectrxloopback;
   wire  ifpscpmchannel15xpipetxelecidle;
   wire [6:0] ifpscpmchannel15xpipetxmaincursor;
   wire [2:0] ifpscpmchannel15xpipetxmargin;
   wire [4:0] ifpscpmchannel15xpipetxpostcursor;
   wire [4:0] ifpscpmchannel15xpipetxprecursor;
   wire  ifpscpmchannel15xpipetxstartblock;
   wire  ifpscpmchannel15xpipetxswing;
   wire [1:0] ifpscpmchannel15xpipetxsyncheader;
   wire [1:0] ifpscpmchannel1xpipepowerdown;
   wire  ifpscpmchannel1xpiperxpolarity;
   wire  ifpscpmchannel1xpiperxtermination;
   wire [1:0] ifpscpmchannel1xpipetxcharisk;
   wire  ifpscpmchannel1xpipetxcompliance;
   wire [31:0] ifpscpmchannel1xpipetxdata;
   wire  ifpscpmchannel1xpipetxdatavalid;
   wire  ifpscpmchannel1xpipetxdeemph;
   wire  ifpscpmchannel1xpipetxdetectrxloopback;
   wire  ifpscpmchannel1xpipetxelecidle;
   wire [6:0] ifpscpmchannel1xpipetxmaincursor;
   wire [2:0] ifpscpmchannel1xpipetxmargin;
   wire [4:0] ifpscpmchannel1xpipetxpostcursor;
   wire [4:0] ifpscpmchannel1xpipetxprecursor;
   wire  ifpscpmchannel1xpipetxstartblock;
   wire  ifpscpmchannel1xpipetxswing;
   wire [1:0] ifpscpmchannel1xpipetxsyncheader;
   wire [1:0] ifpscpmchannel2xpipepowerdown;
   wire  ifpscpmchannel2xpiperxpolarity;
   wire  ifpscpmchannel2xpiperxtermination;
   wire [1:0] ifpscpmchannel2xpipetxcharisk;
   wire  ifpscpmchannel2xpipetxcompliance;
   wire [31:0] ifpscpmchannel2xpipetxdata;
   wire  ifpscpmchannel2xpipetxdatavalid;
   wire  ifpscpmchannel2xpipetxdeemph;
   wire  ifpscpmchannel2xpipetxdetectrxloopback;
   wire  ifpscpmchannel2xpipetxelecidle;
   wire [6:0] ifpscpmchannel2xpipetxmaincursor;
   wire [2:0] ifpscpmchannel2xpipetxmargin;
   wire [4:0] ifpscpmchannel2xpipetxpostcursor;
   wire [4:0] ifpscpmchannel2xpipetxprecursor;
   wire  ifpscpmchannel2xpipetxstartblock;
   wire  ifpscpmchannel2xpipetxswing;
   wire [1:0] ifpscpmchannel2xpipetxsyncheader;
   wire [1:0] ifpscpmchannel3xpipepowerdown;
   wire  ifpscpmchannel3xpiperxpolarity;
   wire  ifpscpmchannel3xpiperxtermination;
   wire [1:0] ifpscpmchannel3xpipetxcharisk;
   wire  ifpscpmchannel3xpipetxcompliance;
   wire [31:0] ifpscpmchannel3xpipetxdata;
   wire  ifpscpmchannel3xpipetxdatavalid;
   wire  ifpscpmchannel3xpipetxdeemph;
   wire  ifpscpmchannel3xpipetxdetectrxloopback;
   wire  ifpscpmchannel3xpipetxelecidle;
   wire [6:0] ifpscpmchannel3xpipetxmaincursor;
   wire [2:0] ifpscpmchannel3xpipetxmargin;
   wire [4:0] ifpscpmchannel3xpipetxpostcursor;
   wire [4:0] ifpscpmchannel3xpipetxprecursor;
   wire  ifpscpmchannel3xpipetxstartblock;
   wire  ifpscpmchannel3xpipetxswing;
   wire [1:0] ifpscpmchannel3xpipetxsyncheader;
   wire [1:0] ifpscpmchannel4xpipepowerdown;
   wire  ifpscpmchannel4xpiperxpolarity;
   wire  ifpscpmchannel4xpiperxtermination;
   wire [1:0] ifpscpmchannel4xpipetxcharisk;
   wire  ifpscpmchannel4xpipetxcompliance;
   wire [31:0] ifpscpmchannel4xpipetxdata;
   wire  ifpscpmchannel4xpipetxdatavalid;
   wire  ifpscpmchannel4xpipetxdeemph;
   wire  ifpscpmchannel4xpipetxdetectrxloopback;
   wire  ifpscpmchannel4xpipetxelecidle;
   wire [6:0] ifpscpmchannel4xpipetxmaincursor;
   wire [2:0] ifpscpmchannel4xpipetxmargin;
   wire [4:0] ifpscpmchannel4xpipetxpostcursor;
   wire [4:0] ifpscpmchannel4xpipetxprecursor;
   wire  ifpscpmchannel4xpipetxstartblock;
   wire  ifpscpmchannel4xpipetxswing;
   wire [1:0] ifpscpmchannel4xpipetxsyncheader;
   wire [1:0] ifpscpmchannel5xpipepowerdown;
   wire  ifpscpmchannel5xpiperxpolarity;
   wire  ifpscpmchannel5xpiperxtermination;
   wire [1:0] ifpscpmchannel5xpipetxcharisk;
   wire  ifpscpmchannel5xpipetxcompliance;
   wire [31:0] ifpscpmchannel5xpipetxdata;
   wire  ifpscpmchannel5xpipetxdatavalid;
   wire  ifpscpmchannel5xpipetxdeemph;
   wire  ifpscpmchannel5xpipetxdetectrxloopback;
   wire  ifpscpmchannel5xpipetxelecidle;
   wire [6:0] ifpscpmchannel5xpipetxmaincursor;
   wire [2:0] ifpscpmchannel5xpipetxmargin;
   wire [4:0] ifpscpmchannel5xpipetxpostcursor;
   wire [4:0] ifpscpmchannel5xpipetxprecursor;
   wire  ifpscpmchannel5xpipetxstartblock;
   wire  ifpscpmchannel5xpipetxswing;
   wire [1:0] ifpscpmchannel5xpipetxsyncheader;
   wire [1:0] ifpscpmchannel6xpipepowerdown;
   wire  ifpscpmchannel6xpiperxpolarity;
   wire  ifpscpmchannel6xpiperxtermination;
   wire [1:0] ifpscpmchannel6xpipetxcharisk;
   wire  ifpscpmchannel6xpipetxcompliance;
   wire [31:0] ifpscpmchannel6xpipetxdata;
   wire  ifpscpmchannel6xpipetxdatavalid;
   wire  ifpscpmchannel6xpipetxdeemph;
   wire  ifpscpmchannel6xpipetxdetectrxloopback;
   wire  ifpscpmchannel6xpipetxelecidle;
   wire [6:0] ifpscpmchannel6xpipetxmaincursor;
   wire [2:0] ifpscpmchannel6xpipetxmargin;
   wire [4:0] ifpscpmchannel6xpipetxpostcursor;
   wire [4:0] ifpscpmchannel6xpipetxprecursor;
   wire  ifpscpmchannel6xpipetxstartblock;
   wire  ifpscpmchannel6xpipetxswing;
   wire [1:0] ifpscpmchannel6xpipetxsyncheader;
   wire [1:0] ifpscpmchannel7xpipepowerdown;
   wire  ifpscpmchannel7xpiperxpolarity;
   wire  ifpscpmchannel7xpiperxtermination;
   wire [1:0] ifpscpmchannel7xpipetxcharisk;
   wire  ifpscpmchannel7xpipetxcompliance;
   wire [31:0] ifpscpmchannel7xpipetxdata;
   wire  ifpscpmchannel7xpipetxdatavalid;
   wire  ifpscpmchannel7xpipetxdeemph;
   wire  ifpscpmchannel7xpipetxdetectrxloopback;
   wire  ifpscpmchannel7xpipetxelecidle;
   wire [6:0] ifpscpmchannel7xpipetxmaincursor;
   wire [2:0] ifpscpmchannel7xpipetxmargin;
   wire [4:0] ifpscpmchannel7xpipetxpostcursor;
   wire [4:0] ifpscpmchannel7xpipetxprecursor;
   wire  ifpscpmchannel7xpipetxstartblock;
   wire  ifpscpmchannel7xpipetxswing;
   wire [1:0] ifpscpmchannel7xpipetxsyncheader;
   wire [1:0] ifpscpmchannel8xpipepowerdown;
   wire  ifpscpmchannel8xpiperxpolarity;
   wire  ifpscpmchannel8xpiperxtermination;
   wire [1:0] ifpscpmchannel8xpipetxcharisk;
   wire  ifpscpmchannel8xpipetxcompliance;
   wire [31:0] ifpscpmchannel8xpipetxdata;
   wire  ifpscpmchannel8xpipetxdatavalid;
   wire  ifpscpmchannel8xpipetxdeemph;
   wire  ifpscpmchannel8xpipetxdetectrxloopback;
   wire  ifpscpmchannel8xpipetxelecidle;
   wire [6:0] ifpscpmchannel8xpipetxmaincursor;
   wire [2:0] ifpscpmchannel8xpipetxmargin;
   wire [4:0] ifpscpmchannel8xpipetxpostcursor;
   wire [4:0] ifpscpmchannel8xpipetxprecursor;
   wire  ifpscpmchannel8xpipetxstartblock;
   wire  ifpscpmchannel8xpipetxswing;
   wire [1:0] ifpscpmchannel8xpipetxsyncheader;
   wire [1:0] ifpscpmchannel9xpipepowerdown;
   wire  ifpscpmchannel9xpiperxpolarity;
   wire  ifpscpmchannel9xpiperxtermination;
   wire [1:0] ifpscpmchannel9xpipetxcharisk;
   wire  ifpscpmchannel9xpipetxcompliance;
   wire [31:0] ifpscpmchannel9xpipetxdata;
   wire  ifpscpmchannel9xpipetxdatavalid;
   wire  ifpscpmchannel9xpipetxdeemph;
   wire  ifpscpmchannel9xpipetxdetectrxloopback;
   wire  ifpscpmchannel9xpipetxelecidle;
   wire [6:0] ifpscpmchannel9xpipetxmaincursor;
   wire [2:0] ifpscpmchannel9xpipetxmargin;
   wire [4:0] ifpscpmchannel9xpipetxpostcursor;
   wire [4:0] ifpscpmchannel9xpipetxprecursor;
   wire  ifpscpmchannel9xpipetxstartblock;
   wire  ifpscpmchannel9xpipetxswing;
   wire [1:0] ifpscpmchannel9xpipetxsyncheader;
   wire  ifpscpmhsdpchannel0xpiperxgearboxslip;
   wire  ifpscpmhsdpchannel0xpiperxpcsreset;
   wire [1:0] ifpscpmhsdpchannel0xpipetxheader;
   wire [6:0] ifpscpmhsdpchannel0xpipetxsequence;
   wire  ifpscpmhsdpchannel1xpiperxgearboxslip;
   wire  ifpscpmhsdpchannel1xpiperxpcsreset;
   wire [1:0] ifpscpmhsdpchannel1xpipetxheader;
   wire [6:0] ifpscpmhsdpchannel1xpipetxsequence;
   wire  ifpscpmhsdpchannel2xpiperxgearboxslip;
   wire  ifpscpmhsdpchannel2xpiperxpcsreset;
   wire [1:0] ifpscpmhsdpchannel2xpipetxheader;
   wire [6:0] ifpscpmhsdpchannel2xpipetxsequence;
   wire  ifpscpmhsdplinkxpipegtrxusrclk;
   wire  ifpscpmintquadxpipephyreadyfrbot;
   wire  ifpscpmlink0xpipegtpipeclk;
   wire  ifpscpmlink0xpipepcielinkreachtarget;
   wire [5:0] ifpscpmlink0xpipepcieltssmstate;
   wire  ifpscpmlink0xpipepcieperstn;
   wire  ifpscpmlink0xpipephyesmadaptationsave;
   wire [2:0] ifpscpmlink0xpipepiperate;
   wire  ifpscpmlink1xpipegtpipeclk;
   wire  ifpscpmlink1xpipepcielinkreachtarget;
   wire [5:0] ifpscpmlink1xpipepcieltssmstate;
   wire  ifpscpmlink1xpipepcieperstn;
   wire  ifpscpmlink1xpipephyesmadaptationsave;
   wire [2:0] ifpscpmlink1xpipepiperate;
   wire  cpmoscclkdiv2;
   wire [3:0] ifpscpmquad0xpiperxmarginreqcmd;
   wire [1:0] ifpscpmquad0xpiperxmarginreqlanenum;
   wire [7:0] ifpscpmquad0xpiperxmarginreqpayload;
   wire  ifpscpmquad0xpiperxmarginreqreq;
   wire  ifpscpmquad0xpiperxmarginresack;
   wire [3:0] ifpscpmquad1xpiperxmarginreqcmd;
   wire [1:0] ifpscpmquad1xpiperxmarginreqlanenum;
   wire [7:0] ifpscpmquad1xpiperxmarginreqpayload;
   wire  ifpscpmquad1xpiperxmarginreqreq;
   wire  ifpscpmquad1xpiperxmarginresack;
   wire [3:0] ifpscpmquad2xpiperxmarginreqcmd;
   wire [1:0] ifpscpmquad2xpiperxmarginreqlanenum;
   wire [7:0] ifpscpmquad2xpiperxmarginreqpayload;
   wire  ifpscpmquad2xpiperxmarginreqreq;
   wire  ifpscpmquad2xpiperxmarginresack;
   wire [3:0] ifpscpmquad3xpiperxmarginreqcmd;
   wire [1:0] ifpscpmquad3xpiperxmarginreqlanenum;
   wire [7:0] ifpscpmquad3xpiperxmarginreqpayload;
   wire  ifpscpmquad3xpiperxmarginreqreq;
   wire  ifpscpmquad3xpiperxmarginresack;

   wire  lpdcpminrefclk;
   wire  lpdcpmswitchtimeoutcnt;
   wire  lpdcpmtopswclk;

//CPM-XPIPE wires

  wire ref_clk;
  wire reset;
  wire  xpipe_pcie_perst_n;
  wire  xpipe_pcie_perst_n_1;
  wire  q0q1_xpipe_pcie_perst_n_m;
  wire  q0q1_xpipe_pcie_perst_n_m_1;
  wire  q1q2_xpipe_pcie_perst_n_m;
  wire  q1q2_xpipe_pcie_perst_n_m_1;
  wire  q2q3_xpipe_pcie_perst_n_m;
  wire  q2q3_xpipe_pcie_perst_n_m_1;

  wire  xpipe_phyesmadaptsave;
  wire  xpipe_phyesmadaptsave_1;

  wire  q0q1_xpipe_phyesmadaptsave_m;
  wire  q0q1_xpipe_phyesmadaptsave_m_1;

  wire  q1q2_xpipe_phyesmadaptsave_m;
  wire  q1q2_xpipe_phyesmadaptsave_m_1;

  wire  q2q3_xpipe_phyesmadaptsave_m;
  wire  q2q3_xpipe_phyesmadaptsave_m_1;

  wire  q3q4_xpipe_phyesmadaptsave_m;
  wire  q3q4_xpipe_phyesmadaptsave_m_1;

  wire  xpipe_gt_pipeclk;
  wire  xpipe_gt_pipeclk_1;
  wire  xpipe_gt_rxusrclk;
  wire ifcpmxpipehsdplinkxpipegtrxout;
  wire xpipe_gt_outclk;

  wire q0q1_xpipe_gt_outclk_m;
  wire q0q1_xpipe_gt_outclk_m_1;
  wire  q0q1_xpipe_gt_rxoutclk_m;
  wire  q0q1_xpipe_gt_rxusrclk_m;
  wire  q0q1_xpipe_gt_pipeclk_m;
  wire  q0q1_xpipe_gt_pipeclk_m_1;
  wire  q0q1_xpipe_bufgtce_m;
  wire  q0q1_xpipe_bufgtce_m_1;
  wire [3:0] q0q1_xpipe_bufgtce_mask_m;
  wire [3:0] q0q1_xpipe_bufgtce_mask_m_1;
  wire [11:0]  q0q1_xpipe_bufgtdiv_m;
  wire [11:0]  q0q1_xpipe_bufgtdiv_m_1;
  wire  q0q1_xpipe_bufgtrst_m;
  wire [3:0] q0q1_xpipe_bufgtrst_mask_m;
  wire [3:0] q0q1_xpipe_bufgtrst_mask_m_1;
  wire  q0q1_xpipe_bufgtrst_m_1;
  wire  q0q1_xpipe_phyready_fr_bot_m;
  wire q0q1_xpipe_phyready_to_bot_m;

  wire q1q2_xpipe_gt_outclk_m;
  wire q1q2_xpipe_gt_outclk_m_1;
  wire  q1q2_xpipe_gt_rxoutclk_m;
  wire  q1q2_xpipe_gt_rxusrclk_m;
  wire  q1q2_xpipe_gt_pipeclk_m;
  wire  q1q2_xpipe_gt_pipeclk_m_1;
  wire  q1q2_xpipe_bufgtce_m;
  wire  q1q2_xpipe_bufgtce_m_1;
  wire [3:0] q1q2_xpipe_bufgtce_mask_m;
  wire [3:0] q1q2_xpipe_bufgtce_mask_m_1;
  wire [11:0]  q1q2_xpipe_bufgtdiv_m;
  wire [11:0]  q1q2_xpipe_bufgtdiv_m_1;
  wire  q1q2_xpipe_bufgtrst_m;
  wire [3:0] q1q2_xpipe_bufgtrst_mask_m;
  wire [3:0] q1q2_xpipe_bufgtrst_mask_m_1;
  wire  q1q2_xpipe_bufgtrst_m_1;
  wire  q1q2_xpipe_phyready_fr_bot_m;
  wire q1q2_xpipe_phyready_to_bot_m;

  wire q2q3_xpipe_gt_outclk_m;
  wire q2q3_xpipe_gt_outclk_m_1;
  wire  q2q3_xpipe_gt_rxoutclk_m;
  wire  q2q3_xpipe_gt_rxusrclk_m;
  wire  q2q3_xpipe_gt_pipeclk_m;
  wire  q2q3_xpipe_gt_pipeclk_m_1;
  wire  q2q3_xpipe_bufgtce_m;
  wire  q2q3_xpipe_bufgtce_m_1;
  wire [3:0] q2q3_xpipe_bufgtce_mask_m;
  wire [3:0] q2q3_xpipe_bufgtce_mask_m_1;
  wire [11:0]  q2q3_xpipe_bufgtdiv_m;
  wire [11:0]  q2q3_xpipe_bufgtdiv_m_1;
  wire  q2q3_xpipe_bufgtrst_m;
  wire [3:0] q2q3_xpipe_bufgtrst_mask_m;
  wire [3:0] q2q3_xpipe_bufgtrst_mask_m_1;
  wire  q2q3_xpipe_bufgtrst_m_1;
  wire  q2q3_xpipe_phyready_fr_bot_m;
  wire q2q3_xpipe_phyready_to_bot_m;

  wire  xpipe_phy_ready;
  wire  xpipe_phy_ready_1;

  wire xpipe_gt_outclk_1;
  wire xpipe_gt_rxoutclk;
  wire xpipe_phyready_to_bot;
  wire xpipe_bufgtce;
  wire [3:0]   xpipe_bufgtce_mask;
  wire [11:0]  xpipe_bufgtdiv;
  wire      xpipe_bufgtrst;
  wire [3:0]  xpipe_bufgtrst_mask;
  wire      xpipe_bufgtce_1;
  wire [3:0] xpipe_bufgtce_mask_1;
  wire [11:0]   xpipe_bufgtdiv_1;
  wire      xpipe_bufgtrst_1;
  wire [3:0]   xpipe_bufgtrst_mask_1;
  wire      xpipe_phyready_fr_bot;
  wire [2:0]   xpipe_pcie_rate;
  wire [2:0]   xpipe_pcie_rate_1;
  wire  xpipe_pcielinkreachtarget;
  wire  xpipe_pcielinkreachtarget_1;

  wire  q0q1_xpipe_pcielinkreachtarget_m;
  wire  q0q1_xpipe_pcielinkreachtarget_m_1;
  wire  q0q1_xpipe_phy_ready_m;
  wire  q0q1_xpipe_phy_ready_m_1;

  wire  q1q2_xpipe_phy_ready_m;
  wire  q1q2_xpipe_phy_ready_m_1;
  wire  q1q2_xpipe_pcielinkreachtarget_m;
  wire  q1q2_xpipe_pcielinkreachtarget_m_1;

  wire  q2q3_xpipe_phy_ready_m;
  wire  q2q3_xpipe_phy_ready_m_1;
  wire  q2q3_xpipe_pcielinkreachtarget_m;
  wire  q2q3_xpipe_pcielinkreachtarget_m_1;

  wire           xpipe_hsdp_rxgearboxslip;
  wire           xpipe_hsdp_rxpcsreset;
  wire [1:0]   xpipe_hsdp_txheader;
  wire [6:0]   xpipe_hsdp_txsequence;
  wire           xpipe_hsdp_rxdatavalid;
  wire [1:0]   xpipe_hsdp_rxheader;
  wire           xpipe_hsdp_rxheadervalid;
  wire           xpipe_hsdp_rxresetdone;
  wire           xpipe_hsdp_txresetdone;

  wire           xpipe_hsdp_rxgearboxslip_1;
  wire           xpipe_hsdp_rxpcsreset_1;
  wire [1:0]   xpipe_hsdp_txheader_1;
  wire [6:0]   xpipe_hsdp_txsequence_1;
  wire           xpipe_hsdp_rxdatavalid_1;
  wire [1:0]   xpipe_hsdp_rxheader_1;
  wire           xpipe_hsdp_rxheadervalid_1;
  wire           xpipe_hsdp_rxresetdone_1;
  wire           xpipe_hsdp_txresetdone_1;

  wire           xpipe_hsdp_rxgearboxslip_2;
  wire           xpipe_hsdp_rxpcsreset_2;
  wire [1:0]   xpipe_hsdp_txheader_2;
  wire [6:0]   xpipe_hsdp_txsequence_2;
  wire           xpipe_hsdp_rxdatavalid_2;
  wire [1:0]   xpipe_hsdp_rxheader_2;
  wire           xpipe_hsdp_rxheadervalid_2;
  wire           xpipe_hsdp_rxresetdone_2;
  wire           xpipe_hsdp_txresetdone_2;


  wire           q0q1_xpipe_hsdp_rxgearboxslip;
  wire           q0q1_xpipe_hsdp_rxpcsreset;
  wire [1:0]   q0q1_xpipe_hsdp_txheader;
  wire [6:0]   q0q1_xpipe_hsdp_txsequence;
  wire           q0q1_xpipe_hsdp_rxdatavalid;
  wire [1:0]   q0q1_xpipe_hsdp_rxheader;
  wire           q0q1_xpipe_hsdp_rxheadervalid;
  wire           q0q1_xpipe_hsdp_rxresetdone;
  wire           q0q1_xpipe_hsdp_txresetdone;

  wire           q0q1_xpipe_hsdp_rxgearboxslip_1;
  wire           q0q1_xpipe_hsdp_rxpcsreset_1;
  wire [1:0]   q0q1_xpipe_hsdp_txheader_1;
  wire [6:0]   q0q1_xpipe_hsdp_txsequence_1;
  wire           q0q1_xpipe_hsdp_rxdatavalid_1;
  wire [1:0]   q0q1_xpipe_hsdp_rxheader_1;
  wire           q0q1_xpipe_hsdp_rxheadervalid_1;
  wire           q0q1_xpipe_hsdp_rxresetdone_1;
  wire           q0q1_xpipe_hsdp_txresetdone_1;

  wire           q0q1_xpipe_hsdp_rxgearboxslip_2;
  wire           q0q1_xpipe_hsdp_rxpcsreset_2;
  wire [1:0]   q0q1_xpipe_hsdp_txheader_2;
  wire [6:0]   q0q1_xpipe_hsdp_txsequence_2;
  wire           q0q1_xpipe_hsdp_rxdatavalid_2;
  wire [1:0]   q0q1_xpipe_hsdp_rxheader_2;
  wire           q0q1_xpipe_hsdp_rxheadervalid_2;
  wire           q0q1_xpipe_hsdp_rxresetdone_2;
  wire           q0q1_xpipe_hsdp_txresetdone_2;


  wire           q1q2_xpipe_hsdp_rxgearboxslip;
  wire           q1q2_xpipe_hsdp_rxpcsreset;
  wire [1:0]   q1q2_xpipe_hsdp_txheader;
  wire [6:0]   q1q2_xpipe_hsdp_txsequence;
  wire           q1q2_xpipe_hsdp_rxdatavalid;
  wire [1:0]   q1q2_xpipe_hsdp_rxheader;
  wire           q1q2_xpipe_hsdp_rxheadervalid;
  wire           q1q2_xpipe_hsdp_rxresetdone;
  wire           q1q2_xpipe_hsdp_txresetdone;

  wire           q1q2_xpipe_hsdp_rxgearboxslip_1;
  wire           q1q2_xpipe_hsdp_rxpcsreset_1;
  wire [1:0]   q1q2_xpipe_hsdp_txheader_1;
  wire [6:0]   q1q2_xpipe_hsdp_txsequence_1;
  wire           q1q2_xpipe_hsdp_rxdatavalid_1;
  wire [1:0]   q1q2_xpipe_hsdp_rxheader_1;
  wire           q1q2_xpipe_hsdp_rxheadervalid_1;
  wire           q1q2_xpipe_hsdp_rxresetdone_1;
  wire           q1q2_xpipe_hsdp_txresetdone_1;

  wire           q1q2_xpipe_hsdp_rxgearboxslip_2;
  wire           q1q2_xpipe_hsdp_rxpcsreset_2;
  wire [1:0]   q1q2_xpipe_hsdp_txheader_2;
  wire [6:0]   q1q2_xpipe_hsdp_txsequence_2;
  wire           q1q2_xpipe_hsdp_rxdatavalid_2;
  wire [1:0]   q1q2_xpipe_hsdp_rxheader_2;
  wire           q1q2_xpipe_hsdp_rxheadervalid_2;
  wire           q1q2_xpipe_hsdp_rxresetdone_2;
  wire           q1q2_xpipe_hsdp_txresetdone_2;


  wire           q2q3_xpipe_hsdp_rxgearboxslip;
  wire           q2q3_xpipe_hsdp_rxpcsreset;
  wire [1:0]   q2q3_xpipe_hsdp_txheader;
  wire [6:0]   q2q3_xpipe_hsdp_txsequence;
  wire           q2q3_xpipe_hsdp_rxdatavalid;
  wire [1:0]   q2q3_xpipe_hsdp_rxheader;
  wire           q2q3_xpipe_hsdp_rxheadervalid;
  wire           q2q3_xpipe_hsdp_rxresetdone;
  wire           q2q3_xpipe_hsdp_txresetdone;

  wire           q2q3_xpipe_hsdp_rxgearboxslip_1;
  wire           q2q3_xpipe_hsdp_rxpcsreset_1;
  wire [1:0]   q2q3_xpipe_hsdp_txheader_1;
  wire [6:0]   q2q3_xpipe_hsdp_txsequence_1;
  wire           q2q3_xpipe_hsdp_rxdatavalid_1;
  wire [1:0]   q2q3_xpipe_hsdp_rxheader_1;
  wire           q2q3_xpipe_hsdp_rxheadervalid_1;
  wire           q2q3_xpipe_hsdp_rxresetdone_1;
  wire           q2q3_xpipe_hsdp_txresetdone_1;

  wire           q2q3_xpipe_hsdp_rxgearboxslip_2;
  wire           q2q3_xpipe_hsdp_rxpcsreset_2;
  wire [1:0]   q2q3_xpipe_hsdp_txheader_2;
  wire [6:0]   q2q3_xpipe_hsdp_txsequence_2;
  wire           q2q3_xpipe_hsdp_rxdatavalid_2;
  wire [1:0]   q2q3_xpipe_hsdp_rxheader_2;
  wire           q2q3_xpipe_hsdp_rxheadervalid_2;
  wire           q2q3_xpipe_hsdp_rxresetdone_2;
  wire           q2q3_xpipe_hsdp_txresetdone_2;

   wire [1:0] xpipe_rxmarginreslanenum;
   wire [1:0] xpipe_rxmarginreslanenum_1;
   wire [1:0] xpipe_rxmarginreslanenum_2;
   wire [1:0] xpipe_rxmarginreslanenum_3;
   wire [3:0] xpipe_rxmarginrescmd;
   wire [3:0] xpipe_rxmarginrescmd_1;
   wire [3:0] xpipe_rxmarginrescmd_2;
   wire [3:0] xpipe_rxmarginrescmd_3;
   wire [7:0] xpipe_rxmarginrespayload;
   wire [7:0] xpipe_rxmarginrespayload_1;
   wire [7:0] xpipe_rxmarginrespayload_2;
   wire [7:0] xpipe_rxmarginrespayload_3;

   wire  xpipe_rxmarginresreq;
   wire  xpipe_rxmarginresreq_1;
   wire  xpipe_rxmarginresreq_2;
   wire  xpipe_rxmarginresreq_3;


   wire [1:0] xpipe_rxmarginreqlanenum;
   wire [1:0] xpipe_rxmarginreqlanenum_1;
   wire [1:0] xpipe_rxmarginreqlanenum_2;
   wire [1:0] xpipe_rxmarginreqlanenum_3;
   wire [3:0] xpipe_rxmarginreqcmd;
   wire [3:0] xpipe_rxmarginreqcmd_1;
   wire [3:0] xpipe_rxmarginreqcmd_2;
   wire [3:0] xpipe_rxmarginreqcmd_3;
   wire [5:0] xpipe_pcieltssmstate;
   wire [5:0] xpipe_pcieltssmstate_1;

   wire [7:0] xpipe_rxmarginreqpayload;
   wire [7:0] xpipe_rxmarginreqpayload_1;
   wire [7:0] xpipe_rxmarginreqpayload_2;
   wire [7:0] xpipe_rxmarginreqpayload_3;
   wire  xpipe_rxmarginreqreq;
   wire  xpipe_rxmarginreqreq_1;
   wire  xpipe_rxmarginreqreq_2;
   wire  xpipe_rxmarginreqreq_3;
   wire  xpipe_rxmarginresack;
   wire  xpipe_rxmarginresack_1;
   wire  xpipe_rxmarginresack_2;
   wire  xpipe_rxmarginresack_3;

   wire  xpipe_rxmarginreqack;
   wire  xpipe_rxmarginreqack_1;
   wire  xpipe_rxmarginreqack_2;
   wire  xpipe_rxmarginreqack_3;

   wire [1:0] q0q1_xpipe_rxmarginreqlanenum_m;
   wire [1:0] q0q1_xpipe_rxmarginreqlanenum_m_1;
   wire [1:0] q0q1_xpipe_rxmarginreqlanenum_m_2;
   wire [1:0] q0q1_xpipe_rxmarginreqlanenum_m_3;
   wire [2:0] q0q1_xpipe_pcie_rate_m;
   wire [2:0] q0q1_xpipe_pcie_rate_m_1;
   wire [3:0] q0q1_xpipe_rxmarginreqcmd_m;
   wire [3:0] q0q1_xpipe_rxmarginreqcmd_m_1;
   wire [3:0] q0q1_xpipe_rxmarginreqcmd_m_2;
   wire [3:0] q0q1_xpipe_rxmarginreqcmd_m_3;
   wire [7:0] q0q1_xpipe_rxmarginreqpayload_m;
   wire [7:0] q0q1_xpipe_rxmarginreqpayload_m_1;
   wire [7:0] q0q1_xpipe_rxmarginreqpayload_m_2;
   wire [7:0] q0q1_xpipe_rxmarginreqpayload_m_3;
   wire  q0q1_xpipe_rxmarginresreq_m;
   wire  q0q1_xpipe_rxmarginresreq_m_1;
   wire  q0q1_xpipe_rxmarginresreq_m_2;
   wire  q0q1_xpipe_rxmarginresreq_m_3;
   wire [1:0] q0q1_xpipe_rxmarginreslanenum_m;
   wire [1:0] q0q1_xpipe_rxmarginreslanenum_m_1;
   wire [1:0] q0q1_xpipe_rxmarginreslanenum_m_2;
   wire [1:0] q0q1_xpipe_rxmarginreslanenum_m_3;
   wire [3:0] q0q1_xpipe_rxmarginrescmd_m;
   wire [3:0] q0q1_xpipe_rxmarginrescmd_m_1;
   wire [3:0] q0q1_xpipe_rxmarginrescmd_m_2;
   wire [3:0] q0q1_xpipe_rxmarginrescmd_m_3;
   wire [5:0] q0q1_xpipe_pcieltssmstate_m;
   wire [5:0] q0q1_xpipe_pcieltssmstate_m_1;
   wire [7:0] q0q1_xpipe_rxmarginrespayload_m;
   wire [7:0] q0q1_xpipe_rxmarginrespayload_m_1;
   wire [7:0] q0q1_xpipe_rxmarginrespayload_m_2;
   wire [7:0] q0q1_xpipe_rxmarginrespayload_m_3;
   wire  q0q1_xpipe_rxmarginreqreq_m;
   wire  q0q1_xpipe_rxmarginreqreq_m_1;
   wire  q0q1_xpipe_rxmarginreqreq_m_2;
   wire  q0q1_xpipe_rxmarginreqreq_m_3;
   wire  q0q1_xpipe_rxmarginresack_m;
   wire  q0q1_xpipe_rxmarginresack_m_1;
   wire  q0q1_xpipe_rxmarginresack_m_2;
   wire  q0q1_xpipe_rxmarginresack_m_3;
   wire  q0q1_xpipe_rxmarginreqack_m;
   wire  q0q1_xpipe_rxmarginreqack_m_1;
   wire  q0q1_xpipe_rxmarginreqack_m_2;
   wire  q0q1_xpipe_rxmarginreqack_m_3;

   wire [1:0] q1q2_xpipe_rxmarginreqlanenum_m;
   wire [1:0] q1q2_xpipe_rxmarginreqlanenum_m_1;
   wire [1:0] q1q2_xpipe_rxmarginreqlanenum_m_2;
   wire [1:0] q1q2_xpipe_rxmarginreqlanenum_m_3;
   wire [2:0] q1q2_xpipe_pcie_rate_m;
   wire [2:0] q1q2_xpipe_pcie_rate_m_1;
   wire [3:0] q1q2_xpipe_rxmarginreqcmd_m;
   wire [3:0] q1q2_xpipe_rxmarginreqcmd_m_1;
   wire [3:0] q1q2_xpipe_rxmarginreqcmd_m_2;
   wire [3:0] q1q2_xpipe_rxmarginreqcmd_m_3;
   wire [7:0] q1q2_xpipe_rxmarginreqpayload_m;
   wire [7:0] q1q2_xpipe_rxmarginreqpayload_m_1;
   wire [7:0] q1q2_xpipe_rxmarginreqpayload_m_2;
   wire [7:0] q1q2_xpipe_rxmarginreqpayload_m_3;
   wire  q1q2_xpipe_rxmarginresreq_m;
   wire  q1q2_xpipe_rxmarginresreq_m_1;
   wire  q1q2_xpipe_rxmarginresreq_m_2;
   wire  q1q2_xpipe_rxmarginresreq_m_3;
   wire [1:0] q1q2_xpipe_rxmarginreslanenum_m;
   wire [1:0] q1q2_xpipe_rxmarginreslanenum_m_1;
   wire [1:0] q1q2_xpipe_rxmarginreslanenum_m_2;
   wire [1:0] q1q2_xpipe_rxmarginreslanenum_m_3;
   wire [3:0] q1q2_xpipe_rxmarginrescmd_m;
   wire [3:0] q1q2_xpipe_rxmarginrescmd_m_1;
   wire [3:0] q1q2_xpipe_rxmarginrescmd_m_2;
   wire [3:0] q1q2_xpipe_rxmarginrescmd_m_3;
   wire [5:0] q1q2_xpipe_pcieltssmstate_m;
   wire [5:0] q1q2_xpipe_pcieltssmstate_m_1;
   wire [7:0] q1q2_xpipe_rxmarginrespayload_m;
   wire [7:0] q1q2_xpipe_rxmarginrespayload_m_1;
   wire [7:0] q1q2_xpipe_rxmarginrespayload_m_2;
   wire [7:0] q1q2_xpipe_rxmarginrespayload_m_3;
   wire  q1q2_xpipe_rxmarginreqreq_m;
   wire  q1q2_xpipe_rxmarginreqreq_m_1;
   wire  q1q2_xpipe_rxmarginreqreq_m_2;
   wire  q1q2_xpipe_rxmarginreqreq_m_3;
   wire  q1q2_xpipe_rxmarginresack_m;
   wire  q1q2_xpipe_rxmarginresack_m_1;
   wire  q1q2_xpipe_rxmarginresack_m_2;
   wire  q1q2_xpipe_rxmarginresack_m_3;
   wire  q1q2_xpipe_rxmarginreqack_m;
   wire  q1q2_xpipe_rxmarginreqack_m_1;
   wire  q1q2_xpipe_rxmarginreqack_m_2;
   wire  q1q2_xpipe_rxmarginreqack_m_3;

   wire [1:0] q2q3_xpipe_rxmarginreqlanenum_m;
   wire [1:0] q2q3_xpipe_rxmarginreqlanenum_m_1;
   wire [1:0] q2q3_xpipe_rxmarginreqlanenum_m_2;
   wire [1:0] q2q3_xpipe_rxmarginreqlanenum_m_3;
   wire [2:0] q2q3_xpipe_pcie_rate_m;
   wire [2:0] q2q3_xpipe_pcie_rate_m_1;
   wire [3:0] q2q3_xpipe_rxmarginreqcmd_m;
   wire [3:0] q2q3_xpipe_rxmarginreqcmd_m_1;
   wire [3:0] q2q3_xpipe_rxmarginreqcmd_m_2;
   wire [3:0] q2q3_xpipe_rxmarginreqcmd_m_3;
   wire [7:0] q2q3_xpipe_rxmarginreqpayload_m;
   wire [7:0] q2q3_xpipe_rxmarginreqpayload_m_1;
   wire [7:0] q2q3_xpipe_rxmarginreqpayload_m_2;
   wire [7:0] q2q3_xpipe_rxmarginreqpayload_m_3;
   wire  q2q3_xpipe_rxmarginresreq_m;
   wire  q2q3_xpipe_rxmarginresreq_m_1;
   wire  q2q3_xpipe_rxmarginresreq_m_2;
   wire  q2q3_xpipe_rxmarginresreq_m_3;
   wire [1:0] q2q3_xpipe_rxmarginreslanenum_m;
   wire [1:0] q2q3_xpipe_rxmarginreslanenum_m_1;
   wire [1:0] q2q3_xpipe_rxmarginreslanenum_m_2;
   wire [1:0] q2q3_xpipe_rxmarginreslanenum_m_3;
   wire [3:0] q2q3_xpipe_rxmarginrescmd_m;
   wire [3:0] q2q3_xpipe_rxmarginrescmd_m_1;
   wire [3:0] q2q3_xpipe_rxmarginrescmd_m_2;
   wire [3:0] q2q3_xpipe_rxmarginrescmd_m_3;
   wire [5:0] q2q3_xpipe_pcieltssmstate_m;
   wire [5:0] q2q3_xpipe_pcieltssmstate_m_1;
   wire [7:0] q2q3_xpipe_rxmarginrespayload_m;
   wire [7:0] q2q3_xpipe_rxmarginrespayload_m_1;
   wire [7:0] q2q3_xpipe_rxmarginrespayload_m_2;
   wire [7:0] q2q3_xpipe_rxmarginrespayload_m_3;
   wire  q2q3_xpipe_rxmarginreqreq_m;
   wire  q2q3_xpipe_rxmarginreqreq_m_1;
   wire  q2q3_xpipe_rxmarginreqreq_m_2;
   wire  q2q3_xpipe_rxmarginreqreq_m_3;
   wire  q2q3_xpipe_rxmarginresack_m;
   wire  q2q3_xpipe_rxmarginresack_m_1;
   wire  q2q3_xpipe_rxmarginresack_m_2;
   wire  q2q3_xpipe_rxmarginresack_m_3;
   wire  q2q3_xpipe_rxmarginreqack_m;
   wire  q2q3_xpipe_rxmarginreqack_m_1;
   wire  q2q3_xpipe_rxmarginreqack_m_2;
   wire  q2q3_xpipe_rxmarginreqack_m_3;

   wire  xpipe_pipe_ch0_phystatus;
   wire [1:0] xpipe_pipe_ch0_rxcharisk;
   wire [31:0] xpipe_pipe_ch0_rxdata;
   wire  xpipe_pipe_ch0_rxdatavalid;
   wire  xpipe_pipe_ch0_rxelecidle;
   wire  xpipe_pipe_ch0_rxstartblock;
   wire [2:0] xpipe_pipe_ch0_rxstatus;
   wire [1:0] xpipe_pipe_ch0_rxsyncheader;
   wire  xpipe_pipe_ch0_rxvalid;
   wire [1:0] xpipe_pipe_ch0_powerdown;
   wire  xpipe_pipe_ch0_rxpolarity;
   wire  xpipe_pipe_ch0_rxtermination;
   wire [1:0] xpipe_pipe_ch0_txcharisk;
   wire  xpipe_pipe_ch0_txcompliance;
   wire [31:0] xpipe_pipe_ch0_txdata;
   wire  xpipe_pipe_ch0_txdatavalid;
   wire  xpipe_pipe_ch0_txdeemph;
   wire  xpipe_pipe_ch0_txdetectrxloopback;
   wire  xpipe_pipe_ch0_txelecidle;
   wire [6:0] xpipe_pipe_ch0_txmaincursor;
   wire [2:0] xpipe_pipe_ch0_txmargin;
   wire [4:0] xpipe_pipe_ch0_txpostcursor;
   wire [4:0] xpipe_pipe_ch0_txprecursor;
   wire  xpipe_pipe_ch0_txstartblock;
   wire  xpipe_pipe_ch0_txswing;
   wire [1:0] xpipe_pipe_ch0_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch0_powerdown_m;
   wire  q0q1_xpipe_pipe_ch0_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch0_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch0_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch0_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch0_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch0_txdata_m;
   wire  q0q1_xpipe_pipe_ch0_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch0_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch0_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch0_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch0_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch0_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch0_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch0_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch0_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch0_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch0_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch0_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch0_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch0_rxdata_m;
   wire  q0q1_xpipe_pipe_ch0_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch0_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch0_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch0_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch0_rxvalid_m;

   wire  xpipe_pipe_ch1_phystatus;
   wire [1:0] xpipe_pipe_ch1_rxcharisk;
   wire [31:0] xpipe_pipe_ch1_rxdata;
   wire  xpipe_pipe_ch1_rxdatavalid;
   wire  xpipe_pipe_ch1_rxelecidle;
   wire  xpipe_pipe_ch1_rxstartblock;
   wire [2:0] xpipe_pipe_ch1_rxstatus;
   wire [1:0] xpipe_pipe_ch1_rxsyncheader;
   wire  xpipe_pipe_ch1_rxvalid;
   wire [1:0] xpipe_pipe_ch1_powerdown;
   wire  xpipe_pipe_ch1_rxpolarity;
   wire  xpipe_pipe_ch1_rxtermination;
   wire [1:0] xpipe_pipe_ch1_txcharisk;
   wire  xpipe_pipe_ch1_txcompliance;
   wire [31:0] xpipe_pipe_ch1_txdata;
   wire  xpipe_pipe_ch1_txdatavalid;
   wire  xpipe_pipe_ch1_txdeemph;
   wire  xpipe_pipe_ch1_txdetectrxloopback;
   wire  xpipe_pipe_ch1_txelecidle;
   wire [6:0] xpipe_pipe_ch1_txmaincursor;
   wire [2:0] xpipe_pipe_ch1_txmargin;
   wire [4:0] xpipe_pipe_ch1_txpostcursor;
   wire [4:0] xpipe_pipe_ch1_txprecursor;
   wire  xpipe_pipe_ch1_txstartblock;
   wire  xpipe_pipe_ch1_txswing;
   wire [1:0] xpipe_pipe_ch1_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch1_powerdown_m;
   wire  q0q1_xpipe_pipe_ch1_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch1_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch1_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch1_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch1_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch1_txdata_m;
   wire  q0q1_xpipe_pipe_ch1_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch1_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch1_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch1_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch1_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch1_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch1_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch1_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch1_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch1_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch1_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch1_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch1_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch1_rxdata_m;
   wire  q0q1_xpipe_pipe_ch1_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch1_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch1_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch1_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch1_rxvalid_m;

   wire  xpipe_pipe_ch2_phystatus;
   wire [1:0] xpipe_pipe_ch2_rxcharisk;
   wire [31:0] xpipe_pipe_ch2_rxdata;
   wire  xpipe_pipe_ch2_rxdatavalid;
   wire  xpipe_pipe_ch2_rxelecidle;
   wire  xpipe_pipe_ch2_rxstartblock;
   wire [2:0] xpipe_pipe_ch2_rxstatus;
   wire [1:0] xpipe_pipe_ch2_rxsyncheader;
   wire  xpipe_pipe_ch2_rxvalid;
   wire [1:0] xpipe_pipe_ch2_powerdown;
   wire  xpipe_pipe_ch2_rxpolarity;
   wire  xpipe_pipe_ch2_rxtermination;
   wire [1:0] xpipe_pipe_ch2_txcharisk;
   wire  xpipe_pipe_ch2_txcompliance;
   wire [31:0] xpipe_pipe_ch2_txdata;
   wire  xpipe_pipe_ch2_txdatavalid;
   wire  xpipe_pipe_ch2_txdeemph;
   wire  xpipe_pipe_ch2_txdetectrxloopback;
   wire  xpipe_pipe_ch2_txelecidle;
   wire [6:0] xpipe_pipe_ch2_txmaincursor;
   wire [2:0] xpipe_pipe_ch2_txmargin;
   wire [4:0] xpipe_pipe_ch2_txpostcursor;
   wire [4:0] xpipe_pipe_ch2_txprecursor;
   wire  xpipe_pipe_ch2_txstartblock;
   wire  xpipe_pipe_ch2_txswing;
   wire [1:0] xpipe_pipe_ch2_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch2_powerdown_m;
   wire  q0q1_xpipe_pipe_ch2_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch2_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch2_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch2_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch2_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch2_txdata_m;
   wire  q0q1_xpipe_pipe_ch2_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch2_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch2_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch2_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch2_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch2_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch2_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch2_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch2_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch2_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch2_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch2_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch2_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch2_rxdata_m;
   wire  q0q1_xpipe_pipe_ch2_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch2_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch2_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch2_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch2_rxvalid_m;

   wire  xpipe_pipe_ch3_phystatus;
   wire [1:0] xpipe_pipe_ch3_rxcharisk;
   wire [31:0] xpipe_pipe_ch3_rxdata;
   wire  xpipe_pipe_ch3_rxdatavalid;
   wire  xpipe_pipe_ch3_rxelecidle;
   wire  xpipe_pipe_ch3_rxstartblock;
   wire [2:0] xpipe_pipe_ch3_rxstatus;
   wire [1:0] xpipe_pipe_ch3_rxsyncheader;
   wire  xpipe_pipe_ch3_rxvalid;
   wire [1:0] xpipe_pipe_ch3_powerdown;
   wire  xpipe_pipe_ch3_rxpolarity;
   wire  xpipe_pipe_ch3_rxtermination;
   wire [1:0] xpipe_pipe_ch3_txcharisk;
   wire  xpipe_pipe_ch3_txcompliance;
   wire [31:0] xpipe_pipe_ch3_txdata;
   wire  xpipe_pipe_ch3_txdatavalid;
   wire  xpipe_pipe_ch3_txdeemph;
   wire  xpipe_pipe_ch3_txdetectrxloopback;
   wire  xpipe_pipe_ch3_txelecidle;
   wire [6:0] xpipe_pipe_ch3_txmaincursor;
   wire [2:0] xpipe_pipe_ch3_txmargin;
   wire [4:0] xpipe_pipe_ch3_txpostcursor;
   wire [4:0] xpipe_pipe_ch3_txprecursor;
   wire  xpipe_pipe_ch3_txstartblock;
   wire  xpipe_pipe_ch3_txswing;
   wire [1:0] xpipe_pipe_ch3_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch3_powerdown_m;
   wire  q0q1_xpipe_pipe_ch3_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch3_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch3_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch3_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch3_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch3_txdata_m;
   wire  q0q1_xpipe_pipe_ch3_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch3_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch3_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch3_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch3_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch3_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch3_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch3_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch3_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch3_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch3_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch3_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch3_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch3_rxdata_m;
   wire  q0q1_xpipe_pipe_ch3_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch3_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch3_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch3_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch3_rxvalid_m;

   wire  xpipe_pipe_ch4_phystatus;
   wire [1:0] xpipe_pipe_ch4_rxcharisk;
   wire [31:0] xpipe_pipe_ch4_rxdata;
   wire  xpipe_pipe_ch4_rxdatavalid;
   wire  xpipe_pipe_ch4_rxelecidle;
   wire  xpipe_pipe_ch4_rxstartblock;
   wire [2:0] xpipe_pipe_ch4_rxstatus;
   wire [1:0] xpipe_pipe_ch4_rxsyncheader;
   wire  xpipe_pipe_ch4_rxvalid;
   wire [1:0] xpipe_pipe_ch4_powerdown;
   wire  xpipe_pipe_ch4_rxpolarity;
   wire  xpipe_pipe_ch4_rxtermination;
   wire [1:0] xpipe_pipe_ch4_txcharisk;
   wire  xpipe_pipe_ch4_txcompliance;
   wire [31:0] xpipe_pipe_ch4_txdata;
   wire  xpipe_pipe_ch4_txdatavalid;
   wire  xpipe_pipe_ch4_txdeemph;
   wire  xpipe_pipe_ch4_txdetectrxloopback;
   wire  xpipe_pipe_ch4_txelecidle;
   wire [6:0] xpipe_pipe_ch4_txmaincursor;
   wire [2:0] xpipe_pipe_ch4_txmargin;
   wire [4:0] xpipe_pipe_ch4_txpostcursor;
   wire [4:0] xpipe_pipe_ch4_txprecursor;
   wire  xpipe_pipe_ch4_txstartblock;
   wire  xpipe_pipe_ch4_txswing;
   wire [1:0] xpipe_pipe_ch4_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch4_powerdown_m;
   wire  q0q1_xpipe_pipe_ch4_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch4_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch4_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch4_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch4_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch4_txdata_m;
   wire  q0q1_xpipe_pipe_ch4_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch4_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch4_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch4_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch4_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch4_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch4_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch4_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch4_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch4_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch4_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch4_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch4_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch4_rxdata_m;
   wire  q0q1_xpipe_pipe_ch4_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch4_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch4_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch4_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch4_rxvalid_m;

   wire  xpipe_pipe_ch5_phystatus;
   wire [1:0] xpipe_pipe_ch5_rxcharisk;
   wire [31:0] xpipe_pipe_ch5_rxdata;
   wire  xpipe_pipe_ch5_rxdatavalid;
   wire  xpipe_pipe_ch5_rxelecidle;
   wire  xpipe_pipe_ch5_rxstartblock;
   wire [2:0] xpipe_pipe_ch5_rxstatus;
   wire [1:0] xpipe_pipe_ch5_rxsyncheader;
   wire  xpipe_pipe_ch5_rxvalid;
   wire [1:0] xpipe_pipe_ch5_powerdown;
   wire  xpipe_pipe_ch5_rxpolarity;
   wire  xpipe_pipe_ch5_rxtermination;
   wire [1:0] xpipe_pipe_ch5_txcharisk;
   wire  xpipe_pipe_ch5_txcompliance;
   wire [31:0] xpipe_pipe_ch5_txdata;
   wire  xpipe_pipe_ch5_txdatavalid;
   wire  xpipe_pipe_ch5_txdeemph;
   wire  xpipe_pipe_ch5_txdetectrxloopback;
   wire  xpipe_pipe_ch5_txelecidle;
   wire [6:0] xpipe_pipe_ch5_txmaincursor;
   wire [2:0] xpipe_pipe_ch5_txmargin;
   wire [4:0] xpipe_pipe_ch5_txpostcursor;
   wire [4:0] xpipe_pipe_ch5_txprecursor;
   wire  xpipe_pipe_ch5_txstartblock;
   wire  xpipe_pipe_ch5_txswing;
   wire [1:0] xpipe_pipe_ch5_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch5_powerdown_m;
   wire  q0q1_xpipe_pipe_ch5_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch5_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch5_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch5_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch5_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch5_txdata_m;
   wire  q0q1_xpipe_pipe_ch5_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch5_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch5_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch5_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch5_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch5_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch5_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch5_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch5_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch5_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch5_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch5_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch5_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch5_rxdata_m;
   wire  q0q1_xpipe_pipe_ch5_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch5_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch5_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch5_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch5_rxvalid_m;

   wire  xpipe_pipe_ch6_phystatus;
   wire [1:0] xpipe_pipe_ch6_rxcharisk;
   wire [31:0] xpipe_pipe_ch6_rxdata;
   wire  xpipe_pipe_ch6_rxdatavalid;
   wire  xpipe_pipe_ch6_rxelecidle;
   wire  xpipe_pipe_ch6_rxstartblock;
   wire [2:0] xpipe_pipe_ch6_rxstatus;
   wire [1:0] xpipe_pipe_ch6_rxsyncheader;
   wire  xpipe_pipe_ch6_rxvalid;
   wire [1:0] xpipe_pipe_ch6_powerdown;
   wire  xpipe_pipe_ch6_rxpolarity;
   wire  xpipe_pipe_ch6_rxtermination;
   wire [1:0] xpipe_pipe_ch6_txcharisk;
   wire  xpipe_pipe_ch6_txcompliance;
   wire [31:0] xpipe_pipe_ch6_txdata;
   wire  xpipe_pipe_ch6_txdatavalid;
   wire  xpipe_pipe_ch6_txdeemph;
   wire  xpipe_pipe_ch6_txdetectrxloopback;
   wire  xpipe_pipe_ch6_txelecidle;
   wire [6:0] xpipe_pipe_ch6_txmaincursor;
   wire [2:0] xpipe_pipe_ch6_txmargin;
   wire [4:0] xpipe_pipe_ch6_txpostcursor;
   wire [4:0] xpipe_pipe_ch6_txprecursor;
   wire  xpipe_pipe_ch6_txstartblock;
   wire  xpipe_pipe_ch6_txswing;
   wire [1:0] xpipe_pipe_ch6_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch6_powerdown_m;
   wire  q0q1_xpipe_pipe_ch6_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch6_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch6_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch6_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch6_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch6_txdata_m;
   wire  q0q1_xpipe_pipe_ch6_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch6_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch6_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch6_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch6_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch6_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch6_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch6_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch6_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch6_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch6_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch6_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch6_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch6_rxdata_m;
   wire  q0q1_xpipe_pipe_ch6_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch6_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch6_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch6_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch6_rxvalid_m;

   wire  xpipe_pipe_ch7_phystatus;
   wire [1:0] xpipe_pipe_ch7_rxcharisk;
   wire [31:0] xpipe_pipe_ch7_rxdata;
   wire  xpipe_pipe_ch7_rxdatavalid;
   wire  xpipe_pipe_ch7_rxelecidle;
   wire  xpipe_pipe_ch7_rxstartblock;
   wire [2:0] xpipe_pipe_ch7_rxstatus;
   wire [1:0] xpipe_pipe_ch7_rxsyncheader;
   wire  xpipe_pipe_ch7_rxvalid;
   wire [1:0] xpipe_pipe_ch7_powerdown;
   wire  xpipe_pipe_ch7_rxpolarity;
   wire  xpipe_pipe_ch7_rxtermination;
   wire [1:0] xpipe_pipe_ch7_txcharisk;
   wire  xpipe_pipe_ch7_txcompliance;
   wire [31:0] xpipe_pipe_ch7_txdata;
   wire  xpipe_pipe_ch7_txdatavalid;
   wire  xpipe_pipe_ch7_txdeemph;
   wire  xpipe_pipe_ch7_txdetectrxloopback;
   wire  xpipe_pipe_ch7_txelecidle;
   wire [6:0] xpipe_pipe_ch7_txmaincursor;
   wire [2:0] xpipe_pipe_ch7_txmargin;
   wire [4:0] xpipe_pipe_ch7_txpostcursor;
   wire [4:0] xpipe_pipe_ch7_txprecursor;
   wire  xpipe_pipe_ch7_txstartblock;
   wire  xpipe_pipe_ch7_txswing;
   wire [1:0] xpipe_pipe_ch7_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch7_powerdown_m;
   wire  q0q1_xpipe_pipe_ch7_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch7_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch7_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch7_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch7_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch7_txdata_m;
   wire  q0q1_xpipe_pipe_ch7_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch7_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch7_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch7_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch7_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch7_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch7_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch7_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch7_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch7_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch7_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch7_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch7_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch7_rxdata_m;
   wire  q0q1_xpipe_pipe_ch7_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch7_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch7_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch7_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch7_rxvalid_m;

   wire  xpipe_pipe_ch8_phystatus;
   wire [1:0] xpipe_pipe_ch8_rxcharisk;
   wire [31:0] xpipe_pipe_ch8_rxdata;
   wire  xpipe_pipe_ch8_rxdatavalid;
   wire  xpipe_pipe_ch8_rxelecidle;
   wire  xpipe_pipe_ch8_rxstartblock;
   wire [2:0] xpipe_pipe_ch8_rxstatus;
   wire [1:0] xpipe_pipe_ch8_rxsyncheader;
   wire  xpipe_pipe_ch8_rxvalid;
   wire [1:0] xpipe_pipe_ch8_powerdown;
   wire  xpipe_pipe_ch8_rxpolarity;
   wire  xpipe_pipe_ch8_rxtermination;
   wire [1:0] xpipe_pipe_ch8_txcharisk;
   wire  xpipe_pipe_ch8_txcompliance;
   wire [31:0] xpipe_pipe_ch8_txdata;
   wire  xpipe_pipe_ch8_txdatavalid;
   wire  xpipe_pipe_ch8_txdeemph;
   wire  xpipe_pipe_ch8_txdetectrxloopback;
   wire  xpipe_pipe_ch8_txelecidle;
   wire [6:0] xpipe_pipe_ch8_txmaincursor;
   wire [2:0] xpipe_pipe_ch8_txmargin;
   wire [4:0] xpipe_pipe_ch8_txpostcursor;
   wire [4:0] xpipe_pipe_ch8_txprecursor;
   wire  xpipe_pipe_ch8_txstartblock;
   wire  xpipe_pipe_ch8_txswing;
   wire [1:0] xpipe_pipe_ch8_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch8_powerdown_m;
   wire  q0q1_xpipe_pipe_ch8_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch8_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch8_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch8_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch8_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch8_txdata_m;
   wire  q0q1_xpipe_pipe_ch8_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch8_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch8_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch8_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch8_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch8_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch8_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch8_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch8_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch8_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch8_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch8_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch8_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch8_rxdata_m;
   wire  q0q1_xpipe_pipe_ch8_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch8_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch8_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch8_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch8_rxvalid_m;

   wire  xpipe_pipe_ch9_phystatus;
   wire [1:0] xpipe_pipe_ch9_rxcharisk;
   wire [31:0] xpipe_pipe_ch9_rxdata;
   wire  xpipe_pipe_ch9_rxdatavalid;
   wire  xpipe_pipe_ch9_rxelecidle;
   wire  xpipe_pipe_ch9_rxstartblock;
   wire [2:0] xpipe_pipe_ch9_rxstatus;
   wire [1:0] xpipe_pipe_ch9_rxsyncheader;
   wire  xpipe_pipe_ch9_rxvalid;
   wire [1:0] xpipe_pipe_ch9_powerdown;
   wire  xpipe_pipe_ch9_rxpolarity;
   wire  xpipe_pipe_ch9_rxtermination;
   wire [1:0] xpipe_pipe_ch9_txcharisk;
   wire  xpipe_pipe_ch9_txcompliance;
   wire [31:0] xpipe_pipe_ch9_txdata;
   wire  xpipe_pipe_ch9_txdatavalid;
   wire  xpipe_pipe_ch9_txdeemph;
   wire  xpipe_pipe_ch9_txdetectrxloopback;
   wire  xpipe_pipe_ch9_txelecidle;
   wire [6:0] xpipe_pipe_ch9_txmaincursor;
   wire [2:0] xpipe_pipe_ch9_txmargin;
   wire [4:0] xpipe_pipe_ch9_txpostcursor;
   wire [4:0] xpipe_pipe_ch9_txprecursor;
   wire  xpipe_pipe_ch9_txstartblock;
   wire  xpipe_pipe_ch9_txswing;
   wire [1:0] xpipe_pipe_ch9_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch9_powerdown_m;
   wire  q0q1_xpipe_pipe_ch9_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch9_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch9_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch9_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch9_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch9_txdata_m;
   wire  q0q1_xpipe_pipe_ch9_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch9_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch9_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch9_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch9_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch9_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch9_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch9_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch9_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch9_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch9_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch9_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch9_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch9_rxdata_m;
   wire  q0q1_xpipe_pipe_ch9_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch9_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch9_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch9_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch9_rxvalid_m;

   wire  xpipe_pipe_ch10_phystatus;
   wire [1:0] xpipe_pipe_ch10_rxcharisk;
   wire [31:0] xpipe_pipe_ch10_rxdata;
   wire  xpipe_pipe_ch10_rxdatavalid;
   wire  xpipe_pipe_ch10_rxelecidle;
   wire  xpipe_pipe_ch10_rxstartblock;
   wire [2:0] xpipe_pipe_ch10_rxstatus;
   wire [1:0] xpipe_pipe_ch10_rxsyncheader;
   wire  xpipe_pipe_ch10_rxvalid;
   wire [1:0] xpipe_pipe_ch10_powerdown;
   wire  xpipe_pipe_ch10_rxpolarity;
   wire  xpipe_pipe_ch10_rxtermination;
   wire [1:0] xpipe_pipe_ch10_txcharisk;
   wire  xpipe_pipe_ch10_txcompliance;
   wire [31:0] xpipe_pipe_ch10_txdata;
   wire  xpipe_pipe_ch10_txdatavalid;
   wire  xpipe_pipe_ch10_txdeemph;
   wire  xpipe_pipe_ch10_txdetectrxloopback;
   wire  xpipe_pipe_ch10_txelecidle;
   wire [6:0] xpipe_pipe_ch10_txmaincursor;
   wire [2:0] xpipe_pipe_ch10_txmargin;
   wire [4:0] xpipe_pipe_ch10_txpostcursor;
   wire [4:0] xpipe_pipe_ch10_txprecursor;
   wire  xpipe_pipe_ch10_txstartblock;
   wire  xpipe_pipe_ch10_txswing;
   wire [1:0] xpipe_pipe_ch10_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch10_powerdown_m;
   wire  q0q1_xpipe_pipe_ch10_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch10_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch10_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch10_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch10_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch10_txdata_m;
   wire  q0q1_xpipe_pipe_ch10_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch10_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch10_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch10_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch10_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch10_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch10_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch10_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch10_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch10_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch10_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch10_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch10_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch10_rxdata_m;
   wire  q0q1_xpipe_pipe_ch10_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch10_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch10_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch10_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch10_rxvalid_m;

   wire  xpipe_pipe_ch11_phystatus;
   wire [1:0] xpipe_pipe_ch11_rxcharisk;
   wire [31:0] xpipe_pipe_ch11_rxdata;
   wire  xpipe_pipe_ch11_rxdatavalid;
   wire  xpipe_pipe_ch11_rxelecidle;
   wire  xpipe_pipe_ch11_rxstartblock;
   wire [2:0] xpipe_pipe_ch11_rxstatus;
   wire [1:0] xpipe_pipe_ch11_rxsyncheader;
   wire  xpipe_pipe_ch11_rxvalid;
   wire [1:0] xpipe_pipe_ch11_powerdown;
   wire  xpipe_pipe_ch11_rxpolarity;
   wire  xpipe_pipe_ch11_rxtermination;
   wire [1:0] xpipe_pipe_ch11_txcharisk;
   wire  xpipe_pipe_ch11_txcompliance;
   wire [31:0] xpipe_pipe_ch11_txdata;
   wire  xpipe_pipe_ch11_txdatavalid;
   wire  xpipe_pipe_ch11_txdeemph;
   wire  xpipe_pipe_ch11_txdetectrxloopback;
   wire  xpipe_pipe_ch11_txelecidle;
   wire [6:0] xpipe_pipe_ch11_txmaincursor;
   wire [2:0] xpipe_pipe_ch11_txmargin;
   wire [4:0] xpipe_pipe_ch11_txpostcursor;
   wire [4:0] xpipe_pipe_ch11_txprecursor;
   wire  xpipe_pipe_ch11_txstartblock;
   wire  xpipe_pipe_ch11_txswing;
   wire [1:0] xpipe_pipe_ch11_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch11_powerdown_m;
   wire  q0q1_xpipe_pipe_ch11_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch11_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch11_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch11_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch11_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch11_txdata_m;
   wire  q0q1_xpipe_pipe_ch11_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch11_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch11_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch11_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch11_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch11_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch11_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch11_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch11_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch11_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch11_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch11_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch11_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch11_rxdata_m;
   wire  q0q1_xpipe_pipe_ch11_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch11_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch11_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch11_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch11_rxvalid_m;

   wire  xpipe_pipe_ch12_phystatus;
   wire [1:0] xpipe_pipe_ch12_rxcharisk;
   wire [31:0] xpipe_pipe_ch12_rxdata;
   wire  xpipe_pipe_ch12_rxdatavalid;
   wire  xpipe_pipe_ch12_rxelecidle;
   wire  xpipe_pipe_ch12_rxstartblock;
   wire [2:0] xpipe_pipe_ch12_rxstatus;
   wire [1:0] xpipe_pipe_ch12_rxsyncheader;
   wire  xpipe_pipe_ch12_rxvalid;
   wire [1:0] xpipe_pipe_ch12_powerdown;
   wire  xpipe_pipe_ch12_rxpolarity;
   wire  xpipe_pipe_ch12_rxtermination;
   wire [1:0] xpipe_pipe_ch12_txcharisk;
   wire  xpipe_pipe_ch12_txcompliance;
   wire [31:0] xpipe_pipe_ch12_txdata;
   wire  xpipe_pipe_ch12_txdatavalid;
   wire  xpipe_pipe_ch12_txdeemph;
   wire  xpipe_pipe_ch12_txdetectrxloopback;
   wire  xpipe_pipe_ch12_txelecidle;
   wire [6:0] xpipe_pipe_ch12_txmaincursor;
   wire [2:0] xpipe_pipe_ch12_txmargin;
   wire [4:0] xpipe_pipe_ch12_txpostcursor;
   wire [4:0] xpipe_pipe_ch12_txprecursor;
   wire  xpipe_pipe_ch12_txstartblock;
   wire  xpipe_pipe_ch12_txswing;
   wire [1:0] xpipe_pipe_ch12_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch12_powerdown_m;
   wire  q0q1_xpipe_pipe_ch12_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch12_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch12_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch12_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch12_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch12_txdata_m;
   wire  q0q1_xpipe_pipe_ch12_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch12_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch12_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch12_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch12_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch12_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch12_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch12_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch12_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch12_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch12_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch12_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch12_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch12_rxdata_m;
   wire  q0q1_xpipe_pipe_ch12_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch12_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch12_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch12_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch12_rxvalid_m;

   wire  xpipe_pipe_ch13_phystatus;
   wire [1:0] xpipe_pipe_ch13_rxcharisk;
   wire [31:0] xpipe_pipe_ch13_rxdata;
   wire  xpipe_pipe_ch13_rxdatavalid;
   wire  xpipe_pipe_ch13_rxelecidle;
   wire  xpipe_pipe_ch13_rxstartblock;
   wire [2:0] xpipe_pipe_ch13_rxstatus;
   wire [1:0] xpipe_pipe_ch13_rxsyncheader;
   wire  xpipe_pipe_ch13_rxvalid;
   wire [1:0] xpipe_pipe_ch13_powerdown;
   wire  xpipe_pipe_ch13_rxpolarity;
   wire  xpipe_pipe_ch13_rxtermination;
   wire [1:0] xpipe_pipe_ch13_txcharisk;
   wire  xpipe_pipe_ch13_txcompliance;
   wire [31:0] xpipe_pipe_ch13_txdata;
   wire  xpipe_pipe_ch13_txdatavalid;
   wire  xpipe_pipe_ch13_txdeemph;
   wire  xpipe_pipe_ch13_txdetectrxloopback;
   wire  xpipe_pipe_ch13_txelecidle;
   wire [6:0] xpipe_pipe_ch13_txmaincursor;
   wire [2:0] xpipe_pipe_ch13_txmargin;
   wire [4:0] xpipe_pipe_ch13_txpostcursor;
   wire [4:0] xpipe_pipe_ch13_txprecursor;
   wire  xpipe_pipe_ch13_txstartblock;
   wire  xpipe_pipe_ch13_txswing;
   wire [1:0] xpipe_pipe_ch13_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch13_powerdown_m;
   wire  q0q1_xpipe_pipe_ch13_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch13_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch13_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch13_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch13_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch13_txdata_m;
   wire  q0q1_xpipe_pipe_ch13_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch13_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch13_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch13_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch13_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch13_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch13_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch13_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch13_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch13_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch13_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch13_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch13_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch13_rxdata_m;
   wire  q0q1_xpipe_pipe_ch13_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch13_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch13_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch13_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch13_rxvalid_m;

   wire  xpipe_pipe_ch14_phystatus;
   wire [1:0] xpipe_pipe_ch14_rxcharisk;
   wire [31:0] xpipe_pipe_ch14_rxdata;
   wire  xpipe_pipe_ch14_rxdatavalid;
   wire  xpipe_pipe_ch14_rxelecidle;
   wire  xpipe_pipe_ch14_rxstartblock;
   wire [2:0] xpipe_pipe_ch14_rxstatus;
   wire [1:0] xpipe_pipe_ch14_rxsyncheader;
   wire  xpipe_pipe_ch14_rxvalid;
   wire [1:0] xpipe_pipe_ch14_powerdown;
   wire  xpipe_pipe_ch14_rxpolarity;
   wire  xpipe_pipe_ch14_rxtermination;
   wire [1:0] xpipe_pipe_ch14_txcharisk;
   wire  xpipe_pipe_ch14_txcompliance;
   wire [31:0] xpipe_pipe_ch14_txdata;
   wire  xpipe_pipe_ch14_txdatavalid;
   wire  xpipe_pipe_ch14_txdeemph;
   wire  xpipe_pipe_ch14_txdetectrxloopback;
   wire  xpipe_pipe_ch14_txelecidle;
   wire [6:0] xpipe_pipe_ch14_txmaincursor;
   wire [2:0] xpipe_pipe_ch14_txmargin;
   wire [4:0] xpipe_pipe_ch14_txpostcursor;
   wire [4:0] xpipe_pipe_ch14_txprecursor;
   wire  xpipe_pipe_ch14_txstartblock;
   wire  xpipe_pipe_ch14_txswing;
   wire [1:0] xpipe_pipe_ch14_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch14_powerdown_m;
   wire  q0q1_xpipe_pipe_ch14_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch14_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch14_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch14_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch14_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch14_txdata_m;
   wire  q0q1_xpipe_pipe_ch14_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch14_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch14_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch14_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch14_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch14_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch14_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch14_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch14_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch14_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch14_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch14_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch14_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch14_rxdata_m;
   wire  q0q1_xpipe_pipe_ch14_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch14_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch14_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch14_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch14_rxvalid_m;

   wire  xpipe_pipe_ch15_phystatus;
   wire [1:0] xpipe_pipe_ch15_rxcharisk;
   wire [31:0] xpipe_pipe_ch15_rxdata;
   wire  xpipe_pipe_ch15_rxdatavalid;
   wire  xpipe_pipe_ch15_rxelecidle;
   wire  xpipe_pipe_ch15_rxstartblock;
   wire [2:0] xpipe_pipe_ch15_rxstatus;
   wire [1:0] xpipe_pipe_ch15_rxsyncheader;
   wire  xpipe_pipe_ch15_rxvalid;
   wire [1:0] xpipe_pipe_ch15_powerdown;
   wire  xpipe_pipe_ch15_rxpolarity;
   wire  xpipe_pipe_ch15_rxtermination;
   wire [1:0] xpipe_pipe_ch15_txcharisk;
   wire  xpipe_pipe_ch15_txcompliance;
   wire [31:0] xpipe_pipe_ch15_txdata;
   wire  xpipe_pipe_ch15_txdatavalid;
   wire  xpipe_pipe_ch15_txdeemph;
   wire  xpipe_pipe_ch15_txdetectrxloopback;
   wire  xpipe_pipe_ch15_txelecidle;
   wire [6:0] xpipe_pipe_ch15_txmaincursor;
   wire [2:0] xpipe_pipe_ch15_txmargin;
   wire [4:0] xpipe_pipe_ch15_txpostcursor;
   wire [4:0] xpipe_pipe_ch15_txprecursor;
   wire  xpipe_pipe_ch15_txstartblock;
   wire  xpipe_pipe_ch15_txswing;
   wire [1:0] xpipe_pipe_ch15_txsyncheader;

   wire [1:0] q0q1_xpipe_pipe_ch15_powerdown_m;
   wire  q0q1_xpipe_pipe_ch15_rxpolarity_m;
   wire  q0q1_xpipe_pipe_ch15_rxtermination_m;
   wire [1:0] q0q1_xpipe_pipe_ch15_txcharisk_m;
   wire  q0q1_xpipe_pipe_ch15_txcompliance_m;
   wire  q0q1_xpipe_pipe_ch15_txdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch15_txdata_m;
   wire  q0q1_xpipe_pipe_ch15_txdeemph_m;
   wire  q0q1_xpipe_pipe_ch15_txdetectrxloopback_m;
   wire  q0q1_xpipe_pipe_ch15_txelecidle_m;
   wire [6:0] q0q1_xpipe_pipe_ch15_txmaincursor_m;
   wire [2:0] q0q1_xpipe_pipe_ch15_txmargin_m;
   wire [4:0] q0q1_xpipe_pipe_ch15_txpostcursor_m;
   wire [4:0] q0q1_xpipe_pipe_ch15_txprecursor_m;
   wire  q0q1_xpipe_pipe_ch15_txstartblock_m;
   wire  q0q1_xpipe_pipe_ch15_txswing_m;
   wire [1:0] q0q1_xpipe_pipe_ch15_txsyncheader_m;
   wire  q0q1_xpipe_pipe_ch15_phystatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch15_rxcharisk_m;
   wire  q0q1_xpipe_pipe_ch15_rxdatavalid_m;
   wire [31:0] q0q1_xpipe_pipe_ch15_rxdata_m;
   wire  q0q1_xpipe_pipe_ch15_rxelecidle_m;
   wire  q0q1_xpipe_pipe_ch15_rxstartblock_m;
   wire [2:0] q0q1_xpipe_pipe_ch15_rxstatus_m;
   wire [1:0] q0q1_xpipe_pipe_ch15_rxsyncheader_m;
   wire  q0q1_xpipe_pipe_ch15_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch0_powerdown_m;
   wire  q1q2_xpipe_pipe_ch0_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch0_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch0_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch0_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch0_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch0_txdata_m;
   wire  q1q2_xpipe_pipe_ch0_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch0_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch0_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch0_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch0_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch0_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch0_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch0_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch0_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch0_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch0_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch0_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch0_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch0_rxdata_m;
   wire  q1q2_xpipe_pipe_ch0_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch0_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch0_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch0_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch0_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch1_powerdown_m;
   wire  q1q2_xpipe_pipe_ch1_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch1_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch1_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch1_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch1_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch1_txdata_m;
   wire  q1q2_xpipe_pipe_ch1_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch1_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch1_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch1_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch1_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch1_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch1_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch1_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch1_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch1_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch1_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch1_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch1_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch1_rxdata_m;
   wire  q1q2_xpipe_pipe_ch1_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch1_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch1_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch1_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch1_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch2_powerdown_m;
   wire  q1q2_xpipe_pipe_ch2_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch2_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch2_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch2_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch2_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch2_txdata_m;
   wire  q1q2_xpipe_pipe_ch2_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch2_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch2_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch2_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch2_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch2_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch2_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch2_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch2_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch2_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch2_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch2_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch2_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch2_rxdata_m;
   wire  q1q2_xpipe_pipe_ch2_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch2_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch2_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch2_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch2_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch3_powerdown_m;
   wire  q1q2_xpipe_pipe_ch3_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch3_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch3_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch3_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch3_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch3_txdata_m;
   wire  q1q2_xpipe_pipe_ch3_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch3_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch3_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch3_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch3_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch3_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch3_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch3_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch3_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch3_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch3_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch3_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch3_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch3_rxdata_m;
   wire  q1q2_xpipe_pipe_ch3_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch3_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch3_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch3_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch3_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch4_powerdown_m;
   wire  q1q2_xpipe_pipe_ch4_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch4_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch4_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch4_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch4_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch4_txdata_m;
   wire  q1q2_xpipe_pipe_ch4_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch4_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch4_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch4_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch4_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch4_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch4_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch4_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch4_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch4_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch4_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch4_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch4_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch4_rxdata_m;
   wire  q1q2_xpipe_pipe_ch4_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch4_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch4_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch4_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch4_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch5_powerdown_m;
   wire  q1q2_xpipe_pipe_ch5_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch5_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch5_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch5_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch5_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch5_txdata_m;
   wire  q1q2_xpipe_pipe_ch5_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch5_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch5_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch5_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch5_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch5_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch5_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch5_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch5_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch5_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch5_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch5_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch5_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch5_rxdata_m;
   wire  q1q2_xpipe_pipe_ch5_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch5_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch5_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch5_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch5_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch6_powerdown_m;
   wire  q1q2_xpipe_pipe_ch6_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch6_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch6_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch6_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch6_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch6_txdata_m;
   wire  q1q2_xpipe_pipe_ch6_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch6_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch6_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch6_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch6_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch6_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch6_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch6_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch6_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch6_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch6_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch6_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch6_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch6_rxdata_m;
   wire  q1q2_xpipe_pipe_ch6_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch6_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch6_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch6_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch6_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch7_powerdown_m;
   wire  q1q2_xpipe_pipe_ch7_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch7_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch7_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch7_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch7_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch7_txdata_m;
   wire  q1q2_xpipe_pipe_ch7_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch7_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch7_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch7_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch7_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch7_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch7_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch7_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch7_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch7_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch7_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch7_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch7_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch7_rxdata_m;
   wire  q1q2_xpipe_pipe_ch7_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch7_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch7_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch7_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch7_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch8_powerdown_m;
   wire  q1q2_xpipe_pipe_ch8_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch8_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch8_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch8_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch8_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch8_txdata_m;
   wire  q1q2_xpipe_pipe_ch8_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch8_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch8_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch8_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch8_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch8_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch8_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch8_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch8_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch8_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch8_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch8_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch8_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch8_rxdata_m;
   wire  q1q2_xpipe_pipe_ch8_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch8_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch8_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch8_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch8_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch9_powerdown_m;
   wire  q1q2_xpipe_pipe_ch9_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch9_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch9_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch9_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch9_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch9_txdata_m;
   wire  q1q2_xpipe_pipe_ch9_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch9_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch9_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch9_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch9_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch9_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch9_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch9_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch9_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch9_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch9_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch9_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch9_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch9_rxdata_m;
   wire  q1q2_xpipe_pipe_ch9_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch9_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch9_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch9_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch9_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch10_powerdown_m;
   wire  q1q2_xpipe_pipe_ch10_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch10_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch10_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch10_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch10_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch10_txdata_m;
   wire  q1q2_xpipe_pipe_ch10_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch10_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch10_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch10_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch10_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch10_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch10_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch10_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch10_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch10_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch10_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch10_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch10_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch10_rxdata_m;
   wire  q1q2_xpipe_pipe_ch10_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch10_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch10_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch10_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch10_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch11_powerdown_m;
   wire  q1q2_xpipe_pipe_ch11_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch11_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch11_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch11_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch11_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch11_txdata_m;
   wire  q1q2_xpipe_pipe_ch11_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch11_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch11_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch11_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch11_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch11_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch11_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch11_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch11_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch11_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch11_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch11_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch11_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch11_rxdata_m;
   wire  q1q2_xpipe_pipe_ch11_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch11_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch11_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch11_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch11_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch12_powerdown_m;
   wire  q1q2_xpipe_pipe_ch12_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch12_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch12_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch12_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch12_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch12_txdata_m;
   wire  q1q2_xpipe_pipe_ch12_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch12_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch12_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch12_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch12_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch12_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch12_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch12_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch12_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch12_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch12_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch12_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch12_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch12_rxdata_m;
   wire  q1q2_xpipe_pipe_ch12_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch12_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch12_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch12_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch12_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch13_powerdown_m;
   wire  q1q2_xpipe_pipe_ch13_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch13_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch13_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch13_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch13_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch13_txdata_m;
   wire  q1q2_xpipe_pipe_ch13_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch13_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch13_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch13_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch13_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch13_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch13_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch13_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch13_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch13_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch13_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch13_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch13_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch13_rxdata_m;
   wire  q1q2_xpipe_pipe_ch13_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch13_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch13_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch13_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch13_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch14_powerdown_m;
   wire  q1q2_xpipe_pipe_ch14_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch14_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch14_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch14_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch14_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch14_txdata_m;
   wire  q1q2_xpipe_pipe_ch14_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch14_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch14_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch14_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch14_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch14_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch14_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch14_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch14_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch14_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch14_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch14_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch14_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch14_rxdata_m;
   wire  q1q2_xpipe_pipe_ch14_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch14_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch14_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch14_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch14_rxvalid_m;

   wire [1:0] q1q2_xpipe_pipe_ch15_powerdown_m;
   wire  q1q2_xpipe_pipe_ch15_rxpolarity_m;
   wire  q1q2_xpipe_pipe_ch15_rxtermination_m;
   wire [1:0] q1q2_xpipe_pipe_ch15_txcharisk_m;
   wire  q1q2_xpipe_pipe_ch15_txcompliance_m;
   wire  q1q2_xpipe_pipe_ch15_txdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch15_txdata_m;
   wire  q1q2_xpipe_pipe_ch15_txdeemph_m;
   wire  q1q2_xpipe_pipe_ch15_txdetectrxloopback_m;
   wire  q1q2_xpipe_pipe_ch15_txelecidle_m;
   wire [6:0] q1q2_xpipe_pipe_ch15_txmaincursor_m;
   wire [2:0] q1q2_xpipe_pipe_ch15_txmargin_m;
   wire [4:0] q1q2_xpipe_pipe_ch15_txpostcursor_m;
   wire [4:0] q1q2_xpipe_pipe_ch15_txprecursor_m;
   wire  q1q2_xpipe_pipe_ch15_txstartblock_m;
   wire  q1q2_xpipe_pipe_ch15_txswing_m;
   wire [1:0] q1q2_xpipe_pipe_ch15_txsyncheader_m;
   wire  q1q2_xpipe_pipe_ch15_phystatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch15_rxcharisk_m;
   wire  q1q2_xpipe_pipe_ch15_rxdatavalid_m;
   wire [31:0] q1q2_xpipe_pipe_ch15_rxdata_m;
   wire  q1q2_xpipe_pipe_ch15_rxelecidle_m;
   wire  q1q2_xpipe_pipe_ch15_rxstartblock_m;
   wire [2:0] q1q2_xpipe_pipe_ch15_rxstatus_m;
   wire [1:0] q1q2_xpipe_pipe_ch15_rxsyncheader_m;
   wire  q1q2_xpipe_pipe_ch15_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch0_powerdown_m;
   wire  q2q3_xpipe_pipe_ch0_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch0_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch0_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch0_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch0_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch0_txdata_m;
   wire  q2q3_xpipe_pipe_ch0_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch0_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch0_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch0_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch0_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch0_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch0_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch0_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch0_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch0_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch0_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch0_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch0_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch0_rxdata_m;
   wire  q2q3_xpipe_pipe_ch0_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch0_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch0_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch0_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch0_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch1_powerdown_m;
   wire  q2q3_xpipe_pipe_ch1_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch1_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch1_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch1_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch1_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch1_txdata_m;
   wire  q2q3_xpipe_pipe_ch1_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch1_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch1_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch1_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch1_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch1_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch1_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch1_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch1_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch1_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch1_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch1_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch1_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch1_rxdata_m;
   wire  q2q3_xpipe_pipe_ch1_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch1_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch1_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch1_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch1_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch2_powerdown_m;
   wire  q2q3_xpipe_pipe_ch2_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch2_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch2_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch2_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch2_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch2_txdata_m;
   wire  q2q3_xpipe_pipe_ch2_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch2_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch2_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch2_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch2_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch2_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch2_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch2_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch2_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch2_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch2_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch2_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch2_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch2_rxdata_m;
   wire  q2q3_xpipe_pipe_ch2_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch2_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch2_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch2_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch2_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch3_powerdown_m;
   wire  q2q3_xpipe_pipe_ch3_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch3_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch3_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch3_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch3_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch3_txdata_m;
   wire  q2q3_xpipe_pipe_ch3_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch3_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch3_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch3_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch3_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch3_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch3_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch3_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch3_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch3_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch3_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch3_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch3_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch3_rxdata_m;
   wire  q2q3_xpipe_pipe_ch3_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch3_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch3_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch3_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch3_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch4_powerdown_m;
   wire  q2q3_xpipe_pipe_ch4_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch4_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch4_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch4_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch4_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch4_txdata_m;
   wire  q2q3_xpipe_pipe_ch4_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch4_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch4_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch4_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch4_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch4_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch4_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch4_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch4_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch4_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch4_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch4_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch4_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch4_rxdata_m;
   wire  q2q3_xpipe_pipe_ch4_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch4_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch4_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch4_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch4_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch5_powerdown_m;
   wire  q2q3_xpipe_pipe_ch5_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch5_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch5_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch5_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch5_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch5_txdata_m;
   wire  q2q3_xpipe_pipe_ch5_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch5_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch5_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch5_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch5_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch5_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch5_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch5_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch5_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch5_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch5_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch5_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch5_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch5_rxdata_m;
   wire  q2q3_xpipe_pipe_ch5_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch5_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch5_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch5_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch5_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch6_powerdown_m;
   wire  q2q3_xpipe_pipe_ch6_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch6_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch6_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch6_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch6_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch6_txdata_m;
   wire  q2q3_xpipe_pipe_ch6_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch6_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch6_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch6_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch6_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch6_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch6_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch6_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch6_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch6_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch6_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch6_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch6_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch6_rxdata_m;
   wire  q2q3_xpipe_pipe_ch6_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch6_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch6_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch6_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch6_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch7_powerdown_m;
   wire  q2q3_xpipe_pipe_ch7_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch7_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch7_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch7_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch7_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch7_txdata_m;
   wire  q2q3_xpipe_pipe_ch7_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch7_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch7_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch7_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch7_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch7_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch7_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch7_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch7_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch7_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch7_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch7_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch7_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch7_rxdata_m;
   wire  q2q3_xpipe_pipe_ch7_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch7_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch7_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch7_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch7_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch8_powerdown_m;
   wire  q2q3_xpipe_pipe_ch8_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch8_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch8_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch8_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch8_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch8_txdata_m;
   wire  q2q3_xpipe_pipe_ch8_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch8_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch8_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch8_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch8_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch8_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch8_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch8_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch8_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch8_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch8_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch8_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch8_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch8_rxdata_m;
   wire  q2q3_xpipe_pipe_ch8_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch8_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch8_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch8_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch8_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch9_powerdown_m;
   wire  q2q3_xpipe_pipe_ch9_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch9_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch9_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch9_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch9_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch9_txdata_m;
   wire  q2q3_xpipe_pipe_ch9_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch9_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch9_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch9_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch9_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch9_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch9_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch9_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch9_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch9_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch9_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch9_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch9_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch9_rxdata_m;
   wire  q2q3_xpipe_pipe_ch9_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch9_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch9_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch9_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch9_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch10_powerdown_m;
   wire  q2q3_xpipe_pipe_ch10_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch10_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch10_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch10_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch10_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch10_txdata_m;
   wire  q2q3_xpipe_pipe_ch10_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch10_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch10_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch10_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch10_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch10_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch10_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch10_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch10_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch10_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch10_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch10_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch10_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch10_rxdata_m;
   wire  q2q3_xpipe_pipe_ch10_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch10_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch10_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch10_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch10_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch11_powerdown_m;
   wire  q2q3_xpipe_pipe_ch11_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch11_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch11_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch11_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch11_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch11_txdata_m;
   wire  q2q3_xpipe_pipe_ch11_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch11_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch11_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch11_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch11_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch11_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch11_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch11_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch11_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch11_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch11_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch11_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch11_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch11_rxdata_m;
   wire  q2q3_xpipe_pipe_ch11_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch11_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch11_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch11_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch11_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch12_powerdown_m;
   wire  q2q3_xpipe_pipe_ch12_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch12_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch12_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch12_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch12_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch12_txdata_m;
   wire  q2q3_xpipe_pipe_ch12_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch12_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch12_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch12_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch12_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch12_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch12_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch12_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch12_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch12_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch12_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch12_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch12_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch12_rxdata_m;
   wire  q2q3_xpipe_pipe_ch12_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch12_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch12_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch12_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch12_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch13_powerdown_m;
   wire  q2q3_xpipe_pipe_ch13_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch13_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch13_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch13_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch13_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch13_txdata_m;
   wire  q2q3_xpipe_pipe_ch13_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch13_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch13_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch13_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch13_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch13_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch13_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch13_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch13_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch13_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch13_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch13_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch13_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch13_rxdata_m;
   wire  q2q3_xpipe_pipe_ch13_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch13_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch13_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch13_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch13_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch14_powerdown_m;
   wire  q2q3_xpipe_pipe_ch14_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch14_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch14_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch14_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch14_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch14_txdata_m;
   wire  q2q3_xpipe_pipe_ch14_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch14_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch14_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch14_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch14_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch14_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch14_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch14_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch14_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch14_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch14_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch14_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch14_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch14_rxdata_m;
   wire  q2q3_xpipe_pipe_ch14_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch14_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch14_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch14_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch14_rxvalid_m;

   wire [1:0] q2q3_xpipe_pipe_ch15_powerdown_m;
   wire  q2q3_xpipe_pipe_ch15_rxpolarity_m;
   wire  q2q3_xpipe_pipe_ch15_rxtermination_m;
   wire [1:0] q2q3_xpipe_pipe_ch15_txcharisk_m;
   wire  q2q3_xpipe_pipe_ch15_txcompliance_m;
   wire  q2q3_xpipe_pipe_ch15_txdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch15_txdata_m;
   wire  q2q3_xpipe_pipe_ch15_txdeemph_m;
   wire  q2q3_xpipe_pipe_ch15_txdetectrxloopback_m;
   wire  q2q3_xpipe_pipe_ch15_txelecidle_m;
   wire [6:0] q2q3_xpipe_pipe_ch15_txmaincursor_m;
   wire [2:0] q2q3_xpipe_pipe_ch15_txmargin_m;
   wire [4:0] q2q3_xpipe_pipe_ch15_txpostcursor_m;
   wire [4:0] q2q3_xpipe_pipe_ch15_txprecursor_m;
   wire  q2q3_xpipe_pipe_ch15_txstartblock_m;
   wire  q2q3_xpipe_pipe_ch15_txswing_m;
   wire [1:0] q2q3_xpipe_pipe_ch15_txsyncheader_m;
   wire  q2q3_xpipe_pipe_ch15_phystatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch15_rxcharisk_m;
   wire  q2q3_xpipe_pipe_ch15_rxdatavalid_m;
   wire [31:0] q2q3_xpipe_pipe_ch15_rxdata_m;
   wire  q2q3_xpipe_pipe_ch15_rxelecidle_m;
   wire  q2q3_xpipe_pipe_ch15_rxstartblock_m;
   wire [2:0] q2q3_xpipe_pipe_ch15_rxstatus_m;
   wire [1:0] q2q3_xpipe_pipe_ch15_rxsyncheader_m;
   wire  q2q3_xpipe_pipe_ch15_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch0_powerdown_m;
   wire  q3q4_xpipe_pipe_ch0_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch0_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch0_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch0_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch0_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch0_txdata_m;
   wire  q3q4_xpipe_pipe_ch0_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch0_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch0_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch0_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch0_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch0_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch0_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch0_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch0_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch0_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch0_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch0_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch0_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch0_rxdata_m;
   wire  q3q4_xpipe_pipe_ch0_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch0_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch0_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch0_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch0_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch1_powerdown_m;
   wire  q3q4_xpipe_pipe_ch1_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch1_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch1_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch1_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch1_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch1_txdata_m;
   wire  q3q4_xpipe_pipe_ch1_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch1_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch1_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch1_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch1_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch1_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch1_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch1_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch1_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch1_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch1_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch1_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch1_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch1_rxdata_m;
   wire  q3q4_xpipe_pipe_ch1_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch1_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch1_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch1_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch1_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch2_powerdown_m;
   wire  q3q4_xpipe_pipe_ch2_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch2_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch2_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch2_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch2_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch2_txdata_m;
   wire  q3q4_xpipe_pipe_ch2_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch2_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch2_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch2_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch2_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch2_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch2_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch2_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch2_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch2_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch2_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch2_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch2_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch2_rxdata_m;
   wire  q3q4_xpipe_pipe_ch2_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch2_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch2_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch2_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch2_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch3_powerdown_m;
   wire  q3q4_xpipe_pipe_ch3_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch3_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch3_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch3_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch3_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch3_txdata_m;
   wire  q3q4_xpipe_pipe_ch3_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch3_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch3_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch3_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch3_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch3_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch3_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch3_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch3_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch3_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch3_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch3_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch3_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch3_rxdata_m;
   wire  q3q4_xpipe_pipe_ch3_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch3_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch3_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch3_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch3_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch4_powerdown_m;
   wire  q3q4_xpipe_pipe_ch4_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch4_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch4_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch4_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch4_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch4_txdata_m;
   wire  q3q4_xpipe_pipe_ch4_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch4_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch4_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch4_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch4_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch4_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch4_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch4_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch4_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch4_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch4_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch4_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch4_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch4_rxdata_m;
   wire  q3q4_xpipe_pipe_ch4_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch4_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch4_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch4_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch4_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch5_powerdown_m;
   wire  q3q4_xpipe_pipe_ch5_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch5_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch5_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch5_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch5_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch5_txdata_m;
   wire  q3q4_xpipe_pipe_ch5_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch5_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch5_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch5_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch5_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch5_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch5_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch5_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch5_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch5_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch5_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch5_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch5_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch5_rxdata_m;
   wire  q3q4_xpipe_pipe_ch5_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch5_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch5_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch5_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch5_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch6_powerdown_m;
   wire  q3q4_xpipe_pipe_ch6_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch6_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch6_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch6_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch6_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch6_txdata_m;
   wire  q3q4_xpipe_pipe_ch6_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch6_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch6_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch6_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch6_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch6_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch6_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch6_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch6_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch6_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch6_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch6_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch6_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch6_rxdata_m;
   wire  q3q4_xpipe_pipe_ch6_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch6_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch6_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch6_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch6_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch7_powerdown_m;
   wire  q3q4_xpipe_pipe_ch7_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch7_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch7_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch7_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch7_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch7_txdata_m;
   wire  q3q4_xpipe_pipe_ch7_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch7_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch7_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch7_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch7_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch7_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch7_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch7_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch7_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch7_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch7_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch7_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch7_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch7_rxdata_m;
   wire  q3q4_xpipe_pipe_ch7_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch7_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch7_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch7_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch7_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch8_powerdown_m;
   wire  q3q4_xpipe_pipe_ch8_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch8_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch8_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch8_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch8_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch8_txdata_m;
   wire  q3q4_xpipe_pipe_ch8_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch8_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch8_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch8_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch8_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch8_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch8_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch8_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch8_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch8_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch8_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch8_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch8_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch8_rxdata_m;
   wire  q3q4_xpipe_pipe_ch8_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch8_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch8_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch8_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch8_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch9_powerdown_m;
   wire  q3q4_xpipe_pipe_ch9_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch9_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch9_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch9_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch9_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch9_txdata_m;
   wire  q3q4_xpipe_pipe_ch9_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch9_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch9_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch9_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch9_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch9_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch9_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch9_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch9_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch9_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch9_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch9_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch9_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch9_rxdata_m;
   wire  q3q4_xpipe_pipe_ch9_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch9_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch9_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch9_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch9_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch10_powerdown_m;
   wire  q3q4_xpipe_pipe_ch10_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch10_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch10_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch10_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch10_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch10_txdata_m;
   wire  q3q4_xpipe_pipe_ch10_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch10_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch10_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch10_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch10_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch10_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch10_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch10_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch10_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch10_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch10_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch10_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch10_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch10_rxdata_m;
   wire  q3q4_xpipe_pipe_ch10_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch10_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch10_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch10_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch10_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch11_powerdown_m;
   wire  q3q4_xpipe_pipe_ch11_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch11_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch11_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch11_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch11_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch11_txdata_m;
   wire  q3q4_xpipe_pipe_ch11_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch11_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch11_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch11_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch11_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch11_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch11_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch11_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch11_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch11_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch11_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch11_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch11_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch11_rxdata_m;
   wire  q3q4_xpipe_pipe_ch11_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch11_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch11_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch11_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch11_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch12_powerdown_m;
   wire  q3q4_xpipe_pipe_ch12_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch12_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch12_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch12_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch12_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch12_txdata_m;
   wire  q3q4_xpipe_pipe_ch12_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch12_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch12_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch12_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch12_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch12_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch12_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch12_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch12_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch12_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch12_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch12_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch12_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch12_rxdata_m;
   wire  q3q4_xpipe_pipe_ch12_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch12_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch12_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch12_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch12_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch13_powerdown_m;
   wire  q3q4_xpipe_pipe_ch13_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch13_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch13_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch13_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch13_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch13_txdata_m;
   wire  q3q4_xpipe_pipe_ch13_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch13_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch13_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch13_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch13_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch13_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch13_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch13_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch13_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch13_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch13_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch13_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch13_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch13_rxdata_m;
   wire  q3q4_xpipe_pipe_ch13_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch13_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch13_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch13_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch13_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch14_powerdown_m;
   wire  q3q4_xpipe_pipe_ch14_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch14_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch14_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch14_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch14_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch14_txdata_m;
   wire  q3q4_xpipe_pipe_ch14_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch14_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch14_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch14_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch14_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch14_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch14_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch14_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch14_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch14_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch14_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch14_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch14_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch14_rxdata_m;
   wire  q3q4_xpipe_pipe_ch14_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch14_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch14_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch14_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch14_rxvalid_m;

   wire [1:0] q3q4_xpipe_pipe_ch15_powerdown_m;
   wire  q3q4_xpipe_pipe_ch15_rxpolarity_m;
   wire  q3q4_xpipe_pipe_ch15_rxtermination_m;
   wire [1:0] q3q4_xpipe_pipe_ch15_txcharisk_m;
   wire  q3q4_xpipe_pipe_ch15_txcompliance_m;
   wire  q3q4_xpipe_pipe_ch15_txdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch15_txdata_m;
   wire  q3q4_xpipe_pipe_ch15_txdeemph_m;
   wire  q3q4_xpipe_pipe_ch15_txdetectrxloopback_m;
   wire  q3q4_xpipe_pipe_ch15_txelecidle_m;
   wire [6:0] q3q4_xpipe_pipe_ch15_txmaincursor_m;
   wire [2:0] q3q4_xpipe_pipe_ch15_txmargin_m;
   wire [4:0] q3q4_xpipe_pipe_ch15_txpostcursor_m;
   wire [4:0] q3q4_xpipe_pipe_ch15_txprecursor_m;
   wire  q3q4_xpipe_pipe_ch15_txstartblock_m;
   wire  q3q4_xpipe_pipe_ch15_txswing_m;
   wire [1:0] q3q4_xpipe_pipe_ch15_txsyncheader_m;
   wire  q3q4_xpipe_pipe_ch15_phystatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch15_rxcharisk_m;
   wire  q3q4_xpipe_pipe_ch15_rxdatavalid_m;
   wire [31:0] q3q4_xpipe_pipe_ch15_rxdata_m;
   wire  q3q4_xpipe_pipe_ch15_rxelecidle_m;
   wire  q3q4_xpipe_pipe_ch15_rxstartblock_m;
   wire [2:0] q3q4_xpipe_pipe_ch15_rxstatus_m;
   wire [1:0] q3q4_xpipe_pipe_ch15_rxsyncheader_m;
   wire  q3q4_xpipe_pipe_ch15_rxvalid_m;
   wire [1:0] r_cache;
   wire [1:0] w_cache;
   wire [1:0] s_ace_lite_gp2_ardomain_int;
   wire [1:0] s_ace_lite_gp2_awdomain_int;

   wire [3:0] s_ace_lite_gp2_arsnoop_int;
   wire [2:0] s_ace_lite_gp2_awsnoop_int;
   wire [C_PS_EMIO_GPIO_WIDTH-1:0] lpd_gpio_tn_temp;

   wire [(C_PMC_EMIO_GPIO_WIDTH-1):0] emio_pmc_gpio_oen_temp;
   wire [(C_PMC_EMIO_GPIO_WIDTH-1):0] emio_pmc_gpio_out_temp;
   wire [(C_PMC_EMIO_GPIO_WIDTH-1):0]  emio_pmc_gpio_in_temp;

   wire [51:0] fmio_lpd_pmc_emio_in;

  wire DetectCmo_to_PS;
  wire [7:0] s_ace_lite_gp2_arlen_t;
  
  wire i2c0_scl_tn_temp;
  wire i2c0_sda_tn_temp;
  wire i2c1_scl_tn_temp;
  wire i2c1_sda_tn_temp;
  
  wire pmc_i2c_scl_oen_temp;
  wire pmc_i2c_sda_oen_temp;
  
  generate
    if (C_PMC_I2CPMC_PERIPHERAL == 1) begin  
  assign pmc_i2c_scl_oen = pmc_i2c_scl_oen_temp ;
  assign pmc_i2c_scl_oen_tn = ~pmc_i2c_scl_oen_temp ;
  assign pmc_i2c_sda_oen = pmc_i2c_sda_oen_temp ;
  assign pmc_i2c_sda_oen_tn = ~pmc_i2c_sda_oen_temp ;
 
    end
  endgenerate
  
  

  

  generate
    if (C_LPD_GPIO_EMIO_ENABLE == 1) begin  
  assign lpd_gpio_t = ~lpd_gpio_tn_temp[C_PS_EMIO_GPIO_WIDTH-1:0];
  assign lpd_gpio_tn = lpd_gpio_tn_temp[C_PS_EMIO_GPIO_WIDTH-1:0];
    end
  endgenerate


  

  generate
    assign gem0_mdio_t_n = ~gem0_mdio_t_tmp;
    assign gem1_mdio_t_n = ~gem1_mdio_t_tmp;
  endgenerate


  generate
    if(C_PMC_EMIO_GPIO_WIDTH < 64 ) begin
      assign emio_pmc_gpio_in_temp =    {{(64-C_PMC_EMIO_GPIO_WIDTH){1'b0}},pmc_gpio_in};
    end
    else begin
      assign emio_pmc_gpio_in_temp =    {pmc_gpio_in};
    end
  endgenerate


generate
    if (C_PMC_GPIO_EMIO_ENABLE == 1) begin
    assign pmc_gpio_out = emio_pmc_gpio_out_temp [C_PMC_EMIO_GPIO_WIDTH-1:0];
    assign pmc_gpio_oe = ~emio_pmc_gpio_oen_temp [C_PMC_EMIO_GPIO_WIDTH-1:0];
    assign pmc_gpio_oen = emio_pmc_gpio_oen_temp [C_PMC_EMIO_GPIO_WIDTH-1:0];
    end
  endgenerate

    
  generate
    if (C_PL_SEM_GPO_ENABLE == 1) begin
        assign pl0_sem = pmc_pl_gpo [3];
        assign pl1_sem = pmc_pl_gpo [2];
        assign pl2_sem = pmc_pl_gpo [1];
        assign pl3_sem = pmc_pl_gpo [0];  
    end
  endgenerate


  generate
    if (C_PS_I2C0_PERIPHERAL_ENABLE == 1) begin  
  assign i2c0_scl_t = ~i2c0_scl_tn_temp;
  assign i2c0_scl_tn = i2c0_scl_tn_temp;
  assign i2c0_sda_tn = i2c0_sda_tn_temp;
  assign i2c0_sda_t = ~i2c0_sda_tn_temp;
    end
  endgenerate
    
  generate
    if (C_PS_I2C1_PERIPHERAL_ENABLE == 1) begin
  assign i2c1_scl_t = ~i2c1_scl_tn_temp;
  assign i2c1_scl_tn = i2c1_scl_tn_temp;
  assign i2c1_sda_tn = i2c1_sda_tn_temp;
  assign i2c1_sda_t = ~i2c1_sda_tn_temp;
    end
  endgenerate  

 

  assign bscan_user1_usr_capture = usr_capture_i[0];
  assign bscan_user1_usr_drck    = usr_drck_i[0];
  assign bscan_user1_usr_reset   = usr_reset_i[0];
  assign bscan_user1_usr_runtest = usr_runtest_i[0];
  assign bscan_user1_usr_sel     = usr_sel_i[0];
  assign bscan_user1_usr_shift   = usr_shift_i[0];
  assign bscan_user1_usr_tck     = usr_tck_i[0];
  assign bscan_user1_usr_tdi     = usr_tdi_i[0];
  assign bscan_user1_usr_tms     = usr_tms_i[0];
  assign bscan_user1_usr_update  = usr_update_i[0];
  assign usr_tdo_i[0] = bscan_user1_usr_tdo;

  assign bscan_user2_usr_capture = usr_capture_i[1];
  assign bscan_user2_usr_drck    = usr_drck_i[1];
  assign bscan_user2_usr_reset   = usr_reset_i[1];
  assign bscan_user2_usr_runtest = usr_runtest_i[1];
  assign bscan_user2_usr_sel     = usr_sel_i[1];
  assign bscan_user2_usr_shift   = usr_shift_i[1];
  assign bscan_user2_usr_tck     = usr_tck_i[1];
  assign bscan_user2_usr_tdi     = usr_tdi_i[1];
  assign bscan_user2_usr_tms     = usr_tms_i[1];
  assign bscan_user2_usr_update  = usr_update_i[1];
  assign usr_tdo_i[1] = bscan_user2_usr_tdo;

  assign bscan_user3_usr_capture = usr_capture_i[2];
  assign bscan_user3_usr_drck    = usr_drck_i[2];
  assign bscan_user3_usr_reset   = usr_reset_i[2];
  assign bscan_user3_usr_runtest = usr_runtest_i[2];
  assign bscan_user3_usr_sel     = usr_sel_i[2];
  assign bscan_user3_usr_shift   = usr_shift_i[2];
  assign bscan_user3_usr_tck     = usr_tck_i[2];
  assign bscan_user3_usr_tdi     = usr_tdi_i[2];
  assign bscan_user3_usr_tms     = usr_tms_i[2];
  assign bscan_user3_usr_update  = usr_update_i[2];
  assign usr_tdo_i[2] =       bscan_user3_usr_tdo;

  assign bscan_user4_usr_capture = usr_capture_i[3];
  assign bscan_user4_usr_drck    = usr_drck_i[3];
  assign bscan_user4_usr_reset   = usr_reset_i[3];
  assign bscan_user4_usr_runtest = usr_runtest_i[3];
  assign bscan_user4_usr_sel     = usr_sel_i[3];
  assign bscan_user4_usr_shift   = usr_shift_i[3];
  assign bscan_user4_usr_tck     = usr_tck_i[3];
  assign bscan_user4_usr_tdi     = usr_tdi_i[3];
  assign bscan_user4_usr_tms     = usr_tms_i[3];
  assign bscan_user4_usr_update  = usr_update_i[3];
  assign usr_tdo_i[3] = bscan_user4_usr_tdo;

  generate 
   if(C_PS_USE_S_AXI_GP2 == 1)
    begin
     if(C_ACE_LITE == 1)
       begin

        assign s_axi_gp2_arready = 'b0;
        assign s_cci_fpd_arready = s_axi_gp2_arready_t ;
								   
        assign s_axi_gp2_awready = 'b0;
        assign s_cci_fpd_awready = s_axi_gp2_awready_t;
								   
        assign s_axi_gp2_bid     = 'b0;
        assign s_cci_fpd_bid     = s_axi_gp2_bid_t;

        assign s_axi_gp2_bresp   = 'b0;
        assign s_cci_fpd_bresp   = s_axi_gp2_bresp_t;
								   
        assign s_axi_gp2_bvalid  = 'b0;
        assign s_cci_fpd_bvalid  = s_axi_gp2_bvalid_t;
								   
        assign s_axi_gp2_racount = 'b0;
        assign s_cci_fpd_racount = s_axi_gp2_racount_t;
								   
        assign s_axi_gp2_rcount  = 'b0;
        assign s_cci_fpd_rcount  = s_axi_gp2_rcount_t;
								   
        assign s_axi_gp2_rdata   = 'b0;
        assign s_cci_fpd_rdata   = s_axi_gp2_rdata_t;
								   
        assign s_axi_gp2_rid     = 'b0;
        assign s_cci_fpd_rid     = s_axi_gp2_rid_t;
								   
        assign s_axi_gp2_rlast   = 'b0;
        assign s_cci_fpd_rlast   = s_axi_gp2_rlast_t;
								   
        assign s_axi_gp2_rresp   = 'b0;
        assign s_cci_fpd_rresp   = s_axi_gp2_rresp_t;
								   
        assign s_axi_gp2_rvalid  = 'b0;
        assign s_cci_fpd_rvalid  = s_axi_gp2_rvalid_t;
								   
        assign s_axi_gp2_wacount = 'b0;
        assign s_cci_fpd_wacount = s_axi_gp2_wacount_t;
								   
        assign s_axi_gp2_wcount  = 'b0;
        assign s_cci_fpd_wcount  = s_axi_gp2_wcount_t;
								   
        assign s_axi_gp2_wready  = 'b0;
        assign s_cci_fpd_wready  = s_axi_gp2_wready_t;
        
        assign s_axi_gp2_araddr_t  = s_cci_fpd_araddr;
        assign s_axi_gp2_arburst_t = s_cci_fpd_arburst;
        assign s_axi_gp2_arcache_t = s_cci_fpd_arcache;
        assign s_axi_gp2_arid_t    = s_cci_fpd_arid;
        assign s_axi_gp2_arlen_t   = s_ace_lite_gp2_arlen_t;
        assign s_axi_gp2_arlock_t  = s_cci_fpd_arlock;
        assign s_axi_gp2_arprot_t  = s_cci_fpd_arprot;
        assign s_axi_gp2_arqos_t   = s_cci_fpd_arqos;
        assign s_axi_gp2_arsize_t  = s_cci_fpd_arsize;
        assign s_axi_gp2_arvalid_t = s_cci_fpd_arvalid;
        assign s_axi_gp2_awaddr_t  = s_cci_fpd_awaddr;
        assign s_axi_gp2_awburst_t = s_cci_fpd_awburst;
        assign s_axi_gp2_awcache_t = s_cci_fpd_awcache;
        assign s_axi_gp2_awid_t    = s_cci_fpd_awid;
        assign s_axi_gp2_awlen_t   = s_cci_fpd_awlen;
        assign s_axi_gp2_awlock_t  = s_cci_fpd_awlock;
        assign s_axi_gp2_awprot_t  = s_cci_fpd_awprot;
        assign s_axi_gp2_awqos_t   = s_cci_fpd_awqos;
        assign s_axi_gp2_awsize_t  = s_cci_fpd_awsize;
        assign s_axi_gp2_awvalid_t = s_cci_fpd_awvalid;
        assign s_axi_gp2_bready_t  = s_cci_fpd_bready;
//      assign s_axi_gp2_rclk_t    = s_cci_fpd_rclk;
        assign s_axi_gp2_rready_t  = s_cci_fpd_rready;
//      assign s_axi_gp2_wclk_t    = s_cci_fpd_wclk;
        assign s_axi_gp2_wdata_t   = s_cci_fpd_wdata;
        assign s_axi_gp2_wlast_t   = s_cci_fpd_wlast;
        assign s_axi_gp2_wstrb_t   = s_cci_fpd_wstrb;
        assign s_axi_gp2_wvalid_t  = s_cci_fpd_wvalid;
//      assign s_axi_gp2_aclk_t    = s_cci_fpd_aclk;
        
//       C_ACE_LITE = 0 >> AXI; C_ACE_LITE = 1 >> ACE_LITE; When AXI *snoop will not be visible in BD diagram
        assign s_ace_lite_gp2_arsnoop_int = s_cci_fpd_arsnoop;
        assign s_ace_lite_gp2_awsnoop_int = s_cci_fpd_awsnoop;


	assign r_cache = (s_axi_gp2_arcache[3:2] == 2'b0)? 2'b11 : 2'b10;
        assign w_cache =(s_axi_gp2_awcache[3:2] == 2'b0)? 2'b11 : 2'b10;

        assign s_ace_lite_gp2_ardomain_int = s_cci_fpd_ardomain;
        assign s_ace_lite_gp2_awdomain_int = s_cci_fpd_awdomain;

        assign rsmid = s_cci_fpd_aruser[9:0];
        assign wsmid = s_cci_fpd_awuser[9:0];

        assign s_axi_gp2_aruser_t  =  {{2'b0},{ {s_ace_lite_gp2_arsnoop_int },{s_ace_lite_gp2_ardomain_int},{rsmid}}};
        assign s_axi_gp2_awuser_t  =  {{3'b0},{ {s_ace_lite_gp2_awsnoop_int },{s_ace_lite_gp2_awdomain_int},{wsmid}}};

        assign DetectCmo_to_PS = (( s_ace_lite_gp2_ardomain_int  != 2'b11) && ( { {(s_ace_lite_gp2_arsnoop_int[2])},{(s_ace_lite_gp2_arsnoop_int[0])} } != 2'b10) && ( { {(s_ace_lite_gp2_arsnoop_int[3])},{(s_ace_lite_gp2_arsnoop_int[1])} } == 2'b10 ) && (( s_cci_fpd_arcache[3:2]) != 2'b0))? 1'b1:1'b0;
        assign s_ace_lite_gp2_arlen_t  = DetectCmo_to_PS ? 8'h00 : s_cci_fpd_arlen;
	  end
       else
	    begin
	     assign s_axi_gp2_arready = s_axi_gp2_arready_t ;
         assign s_cci_fpd_arready = 'b0;
         
         assign s_axi_gp2_awready = s_axi_gp2_awready_t;
         assign s_cci_fpd_awready = 'b0;

         assign s_axi_gp2_bid = s_axi_gp2_bid_t;
         assign s_cci_fpd_bid = 'b0;
         
         assign s_axi_gp2_bresp = s_axi_gp2_bresp_t;
         assign s_cci_fpd_bresp = 'b0;

         assign s_axi_gp2_bvalid = s_axi_gp2_bvalid_t;
         assign s_cci_fpd_bvalid = 'b0;
         
         assign s_axi_gp2_racount = s_axi_gp2_racount_t;
         assign s_cci_fpd_racount = 'b0;

         assign s_axi_gp2_rcount = s_axi_gp2_rcount_t;
         assign s_cci_fpd_rcount = 'b0;
         
         assign s_axi_gp2_rdata = s_axi_gp2_rdata_t;
         assign s_cci_fpd_rdata = 'b0;

         assign s_axi_gp2_rid = s_axi_gp2_rid_t;
         assign s_cci_fpd_rid = 'b0;
         
         assign s_axi_gp2_rlast = s_axi_gp2_rlast_t;
         assign s_cci_fpd_rlast = 'b0;

         assign s_axi_gp2_rresp = s_axi_gp2_rresp_t;
         assign s_cci_fpd_rresp = 'b0;
         
         assign s_axi_gp2_rvalid = s_axi_gp2_rvalid_t;
         assign s_cci_fpd_rvalid = 'b0;

         assign s_axi_gp2_wacount = s_axi_gp2_wacount_t;
         assign s_cci_fpd_wacount = 'b0;
         
         assign s_axi_gp2_wcount = s_axi_gp2_wcount_t;
         assign s_cci_fpd_wcount = 'b0;

         assign s_axi_gp2_wready = s_axi_gp2_wready_t;
         assign s_cci_fpd_wready = 'b0;

         assign s_axi_gp2_araddr_t  = s_axi_gp2_araddr;
         assign s_axi_gp2_arburst_t = s_axi_gp2_arburst;
         assign s_axi_gp2_arcache_t = s_axi_gp2_arcache;
         assign s_axi_gp2_arid_t    = s_axi_gp2_arid;
         assign s_axi_gp2_arlen_t   = s_axi_gp2_arlen;
         assign s_axi_gp2_arlock_t  = s_axi_gp2_arlock;
         assign s_axi_gp2_arprot_t  = s_axi_gp2_arprot;
         assign s_axi_gp2_arqos_t   = s_axi_gp2_arqos;
         assign s_axi_gp2_arsize_t  = s_axi_gp2_arsize;
         assign s_axi_gp2_arvalid_t = s_axi_gp2_arvalid;
         assign s_axi_gp2_awaddr_t  = s_axi_gp2_awaddr;
         assign s_axi_gp2_awburst_t = s_axi_gp2_awburst;
         assign s_axi_gp2_awcache_t = s_axi_gp2_awcache;
         assign s_axi_gp2_awid_t    = s_axi_gp2_awid;
         assign s_axi_gp2_awlen_t   = s_axi_gp2_awlen;
         assign s_axi_gp2_awlock_t  = s_axi_gp2_awlock;
         assign s_axi_gp2_awprot_t  = s_axi_gp2_awprot;
         assign s_axi_gp2_awqos_t   = s_axi_gp2_awqos;
         assign s_axi_gp2_awsize_t  = s_axi_gp2_awsize;
         assign s_axi_gp2_awvalid_t = s_axi_gp2_awvalid;
         assign s_axi_gp2_bready_t  = s_axi_gp2_bready;
//       assign s_axi_gp2_rclk_t    = s_axi_gp2_rclk;
         assign s_axi_gp2_rready_t  = s_axi_gp2_rready;
//       assign s_axi_gp2_wclk_t    = s_axi_gp2_wclk;
         assign s_axi_gp2_wdata_t   = s_axi_gp2_wdata;
         assign s_axi_gp2_wlast_t   = s_axi_gp2_wlast;
         assign s_axi_gp2_wstrb_t   = s_axi_gp2_wstrb;
         assign s_axi_gp2_wvalid_t  = s_axi_gp2_wvalid;
//       assign s_axi_gp2_aclk_t    = s_axi_gp2_aclk;

//        C_ACE_LITE = 0 >> AXI; C_ACE_LITE = 1 >> ACE_LITE; When AXI *snoop will not be visible in BD diagram
         assign s_ace_lite_gp2_arsnoop_int = 'b0;
         assign s_ace_lite_gp2_awsnoop_int = 'b0;

		assign r_cache = (s_axi_gp2_arcache[3:2] == 2'b0)? 2'b11 : 2'b10;
        assign w_cache = (s_axi_gp2_awcache[3:2] == 2'b0)? 2'b11 : 2'b10;
		 
         
         assign s_ace_lite_gp2_ardomain_int = r_cache;
         assign s_ace_lite_gp2_awdomain_int = w_cache;

         assign rsmid = (s_axi_gp2_aruser[9:0]);
         assign wsmid = (s_axi_gp2_awuser[9:0]);

         assign s_axi_gp2_aruser_t  =  {{2'b0},{ {s_ace_lite_gp2_arsnoop_int },{s_ace_lite_gp2_ardomain_int},{rsmid}}};
         assign s_axi_gp2_awuser_t  =  {{3'b0},{ {s_ace_lite_gp2_awsnoop_int },{s_ace_lite_gp2_awdomain_int},{wsmid}}};

         assign DetectCmo_to_PS = (( s_ace_lite_gp2_ardomain_int  != 2'b11) && ( { {(s_ace_lite_gp2_arsnoop_int[2])},{(s_ace_lite_gp2_arsnoop_int[0])} } != 2'b10) && ( { {(s_ace_lite_gp2_arsnoop_int[3])},{(s_ace_lite_gp2_arsnoop_int[1])} } == 2'b10 ) && (( s_cci_fpd_arcache[3:2]) != 2'b0))? 1'b1:1'b0;

         assign s_ace_lite_gp2_arlen_t  = DetectCmo_to_PS ? 8'h00 : s_cci_fpd_arlen;

	 end
	 end
//	 else
//	  begin
//	   assign s_axi_gp2_arready = s_axi_gp2_arready_t ;
//         assign s_cci_fpd_arready = 'b0;
//         
//         assign s_axi_gp2_awready = s_axi_gp2_awready_t;
//         assign s_cci_fpd_awready = 'b0;
//         
//         assign s_axi_gp2_bid = s_axi_gp2_bid_t;
//         assign s_cci_fpd_bid = 'b0;
//         
//         assign s_axi_gp2_bresp = s_axi_gp2_bresp_t;
//         assign s_cci_fpd_bresp = 'b0;
//         
//         assign s_axi_gp2_bvalid = s_axi_gp2_bvalid_t;
//         assign s_cci_fpd_bvalid = 'b0;
//         
//         assign s_axi_gp2_racount = s_axi_gp2_racount_t;
//         assign s_cci_fpd_racount = 'b0;
//         
//         assign s_axi_gp2_rcount = s_axi_gp2_rcount_t;
//         assign s_cci_fpd_rcount = 'b0;
//         
//         assign s_axi_gp2_rdata = s_axi_gp2_rdata_t;
//         assign s_cci_fpd_rdata = 'b0;
//         
//         assign s_axi_gp2_rid = s_axi_gp2_rid_t;
//         assign s_cci_fpd_rid = 'b0;
//         
//         assign s_axi_gp2_rlast = s_axi_gp2_rlast_t;
//         assign s_cci_fpd_rlast = 'b0;
//         
//         assign s_axi_gp2_rresp = s_axi_gp2_rresp_t;
//         assign s_cci_fpd_rresp = 'b0;
//         
//         assign s_axi_gp2_rvalid = s_axi_gp2_rvalid_t;
//         assign s_cci_fpd_rvalid = 'b0;
//         
//         assign s_axi_gp2_wacount = s_axi_gp2_wacount_t;
//         assign s_cci_fpd_wacount = 'b0;
//         
//         assign s_axi_gp2_wcount = s_axi_gp2_wcount_t;
//         assign s_cci_fpd_wcount = 'b0;
//         
//         assign s_axi_gp2_wready = s_axi_gp2_wready_t;
//         assign s_cci_fpd_wready = 'b0;
//         
//         assign s_axi_gp2_araddr_t  = s_axi_gp2_araddr;
//         assign s_axi_gp2_arburst_t = s_axi_gp2_arburst;
//         assign s_axi_gp2_arcache_t = s_axi_gp2_arcache;
//         assign s_axi_gp2_arid_t    = s_axi_gp2_arid;
//         assign s_axi_gp2_arlen_t   = s_axi_gp2_arlen;
//         assign s_axi_gp2_arlock_t  = s_axi_gp2_arlock;
//         assign s_axi_gp2_arprot_t  = s_axi_gp2_arprot;
//         assign s_axi_gp2_arqos_t   = s_axi_gp2_arqos;
//         assign s_axi_gp2_arsize_t  = s_axi_gp2_arsize;
//         assign s_axi_gp2_arvalid_t = s_axi_gp2_arvalid;
//         assign s_axi_gp2_awaddr_t  = s_axi_gp2_awaddr;
//         assign s_axi_gp2_awburst_t = s_axi_gp2_awburst;
//         assign s_axi_gp2_awcache_t = s_axi_gp2_awcache;
//         assign s_axi_gp2_awid_t    = s_axi_gp2_awid;
//         assign s_axi_gp2_awlen_t   = s_axi_gp2_awlen;
//         assign s_axi_gp2_awlock_t  = s_axi_gp2_awlock;
//         assign s_axi_gp2_awprot_t  = s_axi_gp2_awprot;
//         assign s_axi_gp2_awqos_t   = s_axi_gp2_awqos;
//         assign s_axi_gp2_awsize_t  = s_axi_gp2_awsize;
//         assign s_axi_gp2_awvalid_t = s_axi_gp2_awvalid;
//         assign s_axi_gp2_bready_t  = s_axi_gp2_bready;
////       assign s_axi_gp2_rclk_t    = s_axi_gp2_rclk;
//         assign s_axi_gp2_rready_t  = s_axi_gp2_rready;
////       assign s_axi_gp2_wclk_t    = s_axi_gp2_wclk;
//         assign s_axi_gp2_wdata_t   = s_axi_gp2_wdata;
//         assign s_axi_gp2_wlast_t   = s_axi_gp2_wlast;
//         assign s_axi_gp2_wstrb_t   = s_axi_gp2_wstrb;
//         assign s_axi_gp2_wvalid_t  = s_axi_gp2_wvalid;
////       assign s_axi_gp2_aclk_t    = s_axi_gp2_aclk;
//         
////        C_ACE_LITE = 0 >> AXI; C_ACE_LITE = 1 >> ACE_LITE; When AXI *snoop will not be visible in BD diagram
//         assign s_ace_lite_gp2_arsnoop_int = s_cci_fpd_arsnoop;
//         assign s_ace_lite_gp2_awsnoop_int = s_cci_fpd_awsnoop;
//         
//         assign r_cache = 2'b00;
//         assign w_cache = 2'b00;
//	     
//         
//         assign s_ace_lite_gp2_ardomain_int = s_cci_fpd_ardomain;
//         assign s_ace_lite_gp2_awdomain_int = s_cci_fpd_awdomain;
//         
//         assign rsmid = (s_axi_gp2_aruser[9:0]);
//         assign wsmid = (s_axi_gp2_awuser[9:0]);
//	  
//	     assign s_axi_gp2_aruser_t  =  {{2'b0},{ {s_ace_lite_gp2_arsnoop_int },{s_ace_lite_gp2_ardomain_int},{rsmid}}};
//         assign s_axi_gp2_awuser_t  =  {{3'b0},{ {s_ace_lite_gp2_awsnoop_int },{s_ace_lite_gp2_awdomain_int},{wsmid}}};
//
//         assign DetectCmo_to_PS = 'b0;
//
//         assign s_ace_lite_gp2_arlen_t  = 'b0;
//	  
//	  end
	
   endgenerate

  // PS to PL IINTERRUPT Mapping below
  //
  /////////////////////////LPD map below//////////////////////////////////////////
  assign ps_pl_irq_perfmonirq0_rpu_pl  = ps_pl_irq_lpd[8];
  assign ps_pl_irq_perfmonirq1_rpu_pl  = ps_pl_irq_lpd[9];
  assign ps_pl_irq_lpd_ocm_isr_lpd     = ps_pl_irq_lpd[10];
  assign ps_pl_irq_lpd_rpu0_critical_err = ps_pl_irq_lpd[11];
  assign ps_pl_irq_lpd_rpu1_critical_err = ps_pl_irq_lpd[12];
  assign ps_pl_irq_lpd_gpio_lpd        = ps_pl_irq_lpd[13];
  assign ps_pl_irq_lpd_i2c0            = ps_pl_irq_lpd[14];
  assign ps_pl_irq_lpd_i2c1            = ps_pl_irq_lpd[15];
  assign ps_pl_irq_lpd_spi0            = ps_pl_irq_lpd[16];
  assign ps_pl_irq_lpd_spi1            = ps_pl_irq_lpd[17];
  assign ps_pl_irq_lpd_uart0           = ps_pl_irq_lpd[18];
  assign ps_pl_irq_lpd_uart1           = ps_pl_irq_lpd[19];
  assign ps_pl_irq_lpd_can0            = ps_pl_irq_lpd[20];
  assign ps_pl_irq_lpd_can1            = ps_pl_irq_lpd[21];
  assign ps_pl_irq_lpd_usb2_interrupt  = ps_pl_irq_lpd[25:22];
  assign ps_pl_irq_lpd_usb2_otg_interrupt = ps_pl_irq_lpd[26];
  assign ps_pl_irq_lpd_ipi_pmc         = ps_pl_irq_lpd[27];
  assign ps_pl_irq_lpd_ipi_pmc_nobuf   = ps_pl_irq_lpd[28];
  assign ps_pl_irq_lpd_ipi_psm         = ps_pl_irq_lpd[29];
  assign ps_pl_irq_lpd_ipi_ipi0        = ps_pl_irq_lpd[30];
  assign ps_pl_irq_lpd_ipi_ipi1        = ps_pl_irq_lpd[31];
  assign ps_pl_irq_lpd_ipi_ipi2        = ps_pl_irq_lpd[32];
  assign ps_pl_irq_lpd_ipi_ipi3        = ps_pl_irq_lpd[33];
  assign ps_pl_irq_lpd_ipi_ipi4        = ps_pl_irq_lpd[34];
  assign ps_pl_irq_lpd_ipi_ipi5        = ps_pl_irq_lpd[35];
  assign ps_pl_irq_lpd_ipi_ipi6        = ps_pl_irq_lpd[36];
  assign ps_pl_irq_lpd_ttc0            = ps_pl_irq_lpd[39:37];
  assign ps_pl_irq_lpd_ttc1            = ps_pl_irq_lpd[42:40];
  assign ps_pl_irq_lpd_ttc2            = ps_pl_irq_lpd[45:43];
  assign ps_pl_irq_lpd_ttc3            = ps_pl_irq_lpd[48:46];
  assign ps_pl_irq_lpd_wwdt            = ps_pl_irq_lpd[49];
  assign ps_pl_irq_lpd_psm_mb          = ps_pl_irq_lpd[50];
  assign ps_pl_irq_lpd_xppu_err_interrupt = ps_pl_irq_lpd[51];
  assign ps_pl_irq_lpd_int_ir_status   = ps_pl_irq_lpd[52];
  assign ps_pl_irq_lpd_ams_isr         = ps_pl_irq_lpd[53];
  assign ps_pl_irq_lpd_gem1            = ps_pl_irq_lpd[56];
  assign ps_pl_irq_lpd_gem0_wol        = ps_pl_irq_lpd[57];
  assign ps_pl_irq_lpd_gem2            = ps_pl_irq_lpd[58];
  assign ps_pl_irq_lpd_gem1_wol        = ps_pl_irq_lpd[59];
  assign ps_pl_irq_lpd_dma             = ps_pl_irq_lpd[67:60];
  assign ps_pl_irq_lpd_xmpu_err_interrupt = ps_pl_irq_lpd[68];
  assign ps_pl_irq_lpd_wwdt_reset_pending = ps_pl_irq_lpd[69];
  assign ps_pl_irq_lpd_gwdt_ws0        = ps_pl_irq_lpd[70];
  assign ps_pl_irq_lpd_gwdt_ws1        = ps_pl_irq_lpd[71];
  assign ps_pl_irq_lpd_cpm_ps_isr_misc = ps_pl_irq_lpd[72];
  assign ps_pl_irq_lpd_cpm_ps_isr_corr = ps_pl_irq_lpd[73];
  assign ps_pl_irq_lpd_usb2_core_pme_generation = ps_pl_irq_lpd[74];
  assign ps_pl_irq_lpd_cpm_ps_isr_uncorr = ps_pl_irq_lpd[75];
  assign ps_pl_irq_lpd_ocm2_lpd        = ps_pl_irq_lpd[78];
  assign ps_pl_irq_lpd_ocm2_lpd_uncor_err = ps_pl_irq_lpd[79];
  //assign pl_ps_irq0                  = ps_pl_irq_lpd[91:84];

  /////////////////FPD map below ///////////////////////////////////////

//assign pl_ps_irq1                = ps_pl_irq_fpd[7:0];
  assign ps_pl_irq_fpd_wd          = ps_pl_irq_fpd[8];
  assign ps_pl_irq_fpd_ams_isr_fpd = ps_pl_irq_fpd[9];
  assign ps_pl_irq_fpd_fpd_psm_tz_err = ps_pl_irq_fpd[10];
  assign ps_pl_irq_fpd_apu_gic_l2err = ps_pl_irq_fpd[11];
  assign ps_pl_irq_fpd_apu_gic_exterr = ps_pl_irq_fpd[12];
  assign ps_pl_irq_fpd_apu_gic_regs = ps_pl_irq_fpd[13];
  assign ps_pl_irq_fpd_cci_isr     = ps_pl_irq_fpd[14];
  assign ps_pl_irq_fpd_smmu_isr    = ps_pl_irq_fpd[15];
  assign ps_pl_irq_fpd_gwdt_ws1    = ps_pl_irq_fpd[16];
  assign ps_pl_irq_fpd_wwdt_reset_pending = ps_pl_irq_fpd[17];
  assign ps_pl_irq_fpd_gwdt_ws2    = ps_pl_irq_fpd[18];

  /////////////////////// PMC map below

  assign ps_pl_irq_pmc_cfu_interrupt = ps_pl_irq_pmc[0];
  assign ps_pl_irq_pmc_cframe_seu_interrupt = ps_pl_irq_pmc[1];
  assign ps_pl_irq_pmc_gpio_pmc    = ps_pl_irq_pmc[2];
  assign ps_pl_irq_pmc_i2c         = ps_pl_irq_pmc[3];
  assign ps_pl_irq_pmc_ospi        = ps_pl_irq_pmc[4];
  assign ps_pl_irq_pmc_qspi        = ps_pl_irq_pmc[5];
  assign ps_pl_irq_pmc_sd0_axi     = ps_pl_irq_pmc[6];
  assign ps_pl_irq_pmc_sd0_axi_wkup = ps_pl_irq_pmc[7];
  assign ps_pl_irq_pmc_sd1_axi     = ps_pl_irq_pmc[8];
  assign ps_pl_irq_pmc_sd1_axi_wkup = ps_pl_irq_pmc[9];
  assign ps_pl_irq_pmc_debug       = ps_pl_irq_pmc[10];
  assign ps_pl_irq_pmc_dma0        = ps_pl_irq_pmc[11];
  assign ps_pl_irq_pmc_dma1        = ps_pl_irq_pmc[12];
  assign ps_pl_irq_pmc_int_ir_status = ps_pl_irq_pmc[13];
  assign ps_pl_irq_pmc_xppu        = ps_pl_irq_pmc[14];
  assign ps_pl_irq_pmc_xmpu        = ps_pl_irq_pmc[15];
  assign ps_pl_irq_pmc_sbi         = ps_pl_irq_pmc[16];
  assign ps_pl_irq_pmc_aes         = ps_pl_irq_pmc[17];
  assign ps_pl_irq_pmc_ecdsa_rsa   = ps_pl_irq_pmc[18];
  assign ps_pl_irq_pmc_efuse_isr   = ps_pl_irq_pmc[19];
  assign ps_pl_irq_pmc_sha         = ps_pl_irq_pmc[20];
  assign ps_pl_irq_pmc_trng        = ps_pl_irq_pmc[21];
  assign ps_pl_irq_pmc_rtc_alarm_int = ps_pl_irq_pmc[22];
  assign ps_pl_irq_pmc_rtc_seconds_int = ps_pl_irq_pmc[23];
  assign ps_pl_irq_pmc_sysmon_interrupt = ps_pl_irq_pmc[25:24];
  assign ps_pl_irq_pmc_npi_interrupt_out = ps_pl_irq_pmc[37:26];
  assign ps_pl_irq_pmc_ocm_isr     = ps_pl_irq_pmc[38];
  assign ps_pl_irq_pmc_vccint_glitch_detect = ps_pl_irq_pmc[39];

//  assign mio_pl_18 = fmio_lpd_pmc_emio_in[18];
//  assign mio_pl_19 = fmio_lpd_pmc_emio_in[19];
//  assign mio_pl_24 = fmio_lpd_pmc_emio_in[24];
//  assign mio_pl_25 = fmio_lpd_pmc_emio_in[25];
//  assign mio_pl_38 = fmio_lpd_pmc_emio_in[38];
//  assign mio_pl_39 = fmio_lpd_pmc_emio_in[39];

  generate
   if (C_PS_PCIE_EP_RESET1_IO == "{PS_MIO 18}")
   begin 
   assign pl_pcie0_resetn = fmio_lpd_pmc_emio_in[18];
   end
  else if (C_PS_PCIE_EP_RESET1_IO == "{PMC_MIO 24}")
   begin  
   assign pl_pcie0_resetn = fmio_lpd_pmc_emio_in[24];
   end
  else if (C_PS_PCIE_EP_RESET1_IO == "{PMC_MIO 38}")
   begin 
   assign pl_pcie0_resetn = fmio_lpd_pmc_emio_in[38];
   end
  endgenerate
  
  generate
   if (C_PS_PCIE_EP_RESET2_IO == "{PS_MIO 19}")
   begin 
   assign pl_pcie1_resetn = fmio_lpd_pmc_emio_in[19];
   end
  else if (C_PS_PCIE_EP_RESET2_IO == "{PMC_MIO 25}")
   begin 
   assign pl_pcie1_resetn = fmio_lpd_pmc_emio_in[25];
   end
  else if (C_PS_PCIE_EP_RESET2_IO == "{PMC_MIO 39}")
   begin 
   assign pl_pcie1_resetn = fmio_lpd_pmc_emio_in[39];
   end
  endgenerate
 
// PS to PL IINTERRUPT Mapping above
localparam SPP_DEVICE = "S80";


  generate
     if ( (C_PMCPL_CLK0_BUF == "true")  | (C_PMCPL_CLK0_BUF == "TRUE") | (C_PMCPL_CLK0_BUF == 1) | (C_PMCPL_CLK0_BUF == 'b1) && ( SPP_DEVICE != "xcvu440") ) begin : buffer_pl_clk_0
        BUFG_PS #(.SIM_DEVICE(C_SIM_DEVICE) ) PL_CLK_0_BUFG (.I(pmc_pl_ref_clk[0]), .O(pl0_ref_clk));
     end
     else begin
        assign pl0_ref_clk = pmc_pl_ref_clk[0];
     end

     if ( (C_PMCPL_CLK1_BUF == "true")  | (C_PMCPL_CLK1_BUF == "TRUE") | (C_PMCPL_CLK1_BUF == 1) | (C_PMCPL_CLK1_BUF == 'b1) && ( SPP_DEVICE != "xcvu440") ) begin : buffer_pl_clk_1
        BUFG_PS #(.SIM_DEVICE(C_SIM_DEVICE) ) PL_CLK_1_BUFG (.I(pmc_pl_ref_clk[1]), .O(pl1_ref_clk));
     end
     else begin
        assign pl1_ref_clk = pmc_pl_ref_clk[1];
     end

     if ( (C_PMCPL_CLK2_BUF == "true")  | (C_PMCPL_CLK2_BUF == "TRUE") | (C_PMCPL_CLK2_BUF == 1) | (C_PMCPL_CLK2_BUF == 'b1) && ( SPP_DEVICE != "xcvu440")) begin : buffer_pl_clk_2
        BUFG_PS #(.SIM_DEVICE(C_SIM_DEVICE) ) PL_CLK_2_BUFG (.I(pmc_pl_ref_clk[2]), .O(pl2_ref_clk));
     end
     else begin
        assign pl2_ref_clk = pmc_pl_ref_clk[2];
     end

     if ( (C_PMCPL_CLK3_BUF == "true")  | (C_PMCPL_CLK3_BUF == "TRUE") | (C_PMCPL_CLK3_BUF == 1) | (C_PMCPL_CLK3_BUF == 'b1) && ( SPP_DEVICE != "xcvu440") ) begin : buffer_pl_clk_3
        BUFG_PS  #(.SIM_DEVICE(C_SIM_DEVICE) ) PL_CLK_3_BUFG (.I(pmc_pl_ref_clk[3]), .O(pl3_ref_clk));
     end
     else begin
        assign pl3_ref_clk = pmc_pl_ref_clk[3];
     end

     if (( (C_PMCPL_IRO_CLK_BUF == "true")  | (C_PMCPL_IRO_CLK_BUF == "TRUE") | (C_PMCPL_IRO_CLK_BUF == 1)) &&  SPP_DEVICE != "xcvu440" ) begin : buffer_iro_clk
        BUFG_PS #(.SIM_DEVICE(C_SIM_DEVICE) ) PL_CLK_0_BUFG (.I(pmc_pl_ref_clk[5]), .O(pmc_iro_clk));
     end
     else begin
        assign pmc_iro_clk = pmc_pl_ref_clk[5];
     end
  endgenerate


  generate
    if (C_DIFF_RW_CLK_S_AXI_GP0 == 0) begin : clk_assign0
      assign s_axi_gp0_rclk_temp  =  s_axi_fpd_aclk;
      assign s_axi_gp0_wclk_temp  =  s_axi_fpd_aclk;
    end
    else begin
      assign s_axi_gp0_rclk_temp  =  s_axi_fpd_rclk;
      assign s_axi_gp0_wclk_temp  =  s_axi_fpd_wclk;
    end

    if (C_DIFF_RW_CLK_S_AXI_GP2 == 0) begin : clk_assign2
      assign s_axi_gp2_rclk_temp  = (C_ACE_LITE==1)?(s_cci_fpd_aclk):(s_axi_gp2_aclk);
      assign s_axi_gp2_wclk_temp  =  (C_ACE_LITE==1)?(s_cci_fpd_aclk):(s_axi_gp2_aclk);
    end
    else begin
      assign s_axi_gp2_rclk_temp  =  (C_ACE_LITE==1)?(s_cci_fpd_rclk):(s_axi_gp2_rclk);
      assign s_axi_gp2_wclk_temp  = (C_ACE_LITE==1)?(s_cci_fpd_wclk):(s_axi_gp2_wclk);
    end
    if (C_DIFF_RW_CLK_S_AXI_GP4 == 0) begin : clk_assign4
      assign s_axi_gp4_rclk_temp  =  s_axi_lpd_aclk;
      assign s_axi_gp4_wclk_temp  =  s_axi_lpd_aclk;
    end
    else begin
      assign s_axi_gp4_rclk_temp  =  s_axi_lpd_rclk;
      assign s_axi_gp4_wclk_temp  =  s_axi_lpd_wclk;
    end
  endgenerate

  assign pl_ps_irq0_i = {
    pl_ps_irq7,
    pl_ps_irq6,
    pl_ps_irq5,
    pl_ps_irq4,
    pl_ps_irq3,
    pl_ps_irq2,
    pl_ps_irq1,
    pl_ps_irq0 };

  assign pl_ps_irq1_i = {
    pl_ps_irq15,
    pl_ps_irq14,
    pl_ps_irq13,
    pl_ps_irq12,
    pl_ps_irq11,
    pl_ps_irq10,
    pl_ps_irq9,
    pl_ps_irq8 };


  versal_cips_ps_vip_0  PS9_VIP_inst ( 

      .ADMA2PLCACK(adma_2_pl_cack_i),
      .ADMA2PLTVLD(adma_2_pl_tvld_i),

      .CPUR5AXICLK(s_axi_xram3_aclk),
      .LPDLSBUSCLK(lpd_lsbus_clk),

    //.DPAUDIOREFCLK(dp_audio_ref_clk),
    //.DPVIDEOREFCLK(dp_video_ref_clk),
      .EMIOCAN0PHYTX(canfd0_phy_tx),
      .EMIOCAN1PHYTX(canfd1_phy_tx),
      .EMIOENET0DMABUSWIDTH(gem0_dma_bus_width),
      .EMIOENET0DMATXENDTOG(gem0_fifo_dma_tx_end_tog),
      .EMIOENET0GEMTSUTIMERCNT(gem0_tsu_timer_cnt),
      .EMIOENET0GMIITXD(gem0_gmii_tx_d),
      .EMIOENET0GMIITXEN(gem0_gmii_tx_en),
      .EMIOENET0GMIITXER(gem0_gmii_tx_err),
      .EMIOENET0MDIOMDC(gem0_mdio_mdc),
      .EMIOENET0MDIOO(gem0_mdio_o),
      .EMIOENET0MDIOTN(gem0_mdio_t_tmp),
      .EMIOENET0RXWDATA(gem0_fifo_rx_w_data),
      .EMIOENET0RXWEOP(gem0_fifo_rx_w_eop),
      .EMIOENET0RXWERR(gem0_fifo_rx_w_err),
      .EMIOENET0RXWFLUSH(gem0_fifo_rx_w_flush),
      .EMIOENET0RXWSOP(gem0_fifo_rx_w_sop),
      .EMIOENET0RXWSTATUS(gem0_fifo_rx_w_status),
      .EMIOENET0RXWWR(gem0_fifo_rx_w_wr),
      .EMIOENET0SPEEDMODE(emio_enet0_speed_mode),
      .EMIOENET0TXRRD(gem0_fifo_tx_r_rd),
      .EMIOENET0TXRSTATUS(gem0_fifo_tx_r_status),
      .EMIOENET1DMABUSWIDTH(emio_enet1_dma_bus_width),
      .EMIOENET1DMATXENDTOG(gem1_fifo_dma_tx_end_tog),
      .EMIOENET1GMIITXD(gem1_gmii_tx_d),
      .EMIOENET1GMIITXEN(gem1_gmii_tx_en),
      .EMIOENET1GMIITXER(gem1_gmii_tx_err),
      .EMIOENET1MDIOMDC(gem1_mdio_mdc),
      .EMIOENET1MDIOO(gem1_mdio_o),
      .EMIOENET1MDIOTN(gem1_mdio_t_tmp),
      .EMIOENET1RXWDATA(gem1_fifo_rx_w_data),
      .EMIOENET1RXWEOP(gem1_fifo_rx_w_eop),
      .EMIOENET1RXWERR(gem1_fifo_rx_w_err),
      .EMIOENET1RXWFLUSH(gem1_fifo_rx_w_flush),
      .EMIOENET1RXWSOP(gem1_fifo_rx_w_sop),
      .EMIOENET1RXWSTATUS(gem1_fifo_rx_w_status),
      .EMIOENET1RXWWR(gem1_fifo_rx_w_wr),
      .EMIOENET1SPEEDMODE(emio_enet1_speed_mode),
      .EMIOENET1TXRRD(gem1_fifo_tx_r_rd),
      .EMIOENET1TXRSTATUS(gem1_fifo_tx_r_status),
      .EMIOGEM0DELAYREQRX(gem0_ptp_delay_req_rx),
      .EMIOGEM0DELAYREQTX(gem0_ptp_delay_req_tx),
      .EMIOGEM0PDELAYREQRX(gem0_ptp_pdelay_req_rx),
      .EMIOGEM0PDELAYREQTX(gem0_ptp_pdelay_req_tx),
      .EMIOGEM0PDELAYRESPRX(gem0_ptp_pdelay_resp_rx),
      .EMIOGEM0PDELAYRESPTX(gem0_ptp_pdelay_resp_tx),
      .EMIOGEM0RXSOF(gem0_ptp_rx_sof),
      .EMIOGEM0SYNCFRAMERX(gem0_ptp_sync_frame_rx),
      .EMIOGEM0SYNCFRAMETX(gem0_ptp_sync_frame_tx),
      .EMIOGEM0TSUTIMERCMPVAL(gem0_tsu_timer_cmp_val),
      .EMIOGEM0TXRFIXEDLAT(emio_gem0_tx_r_fixed_lat),
      .EMIOGEM0TXSOF(gem0_ptp_tx_sof),
      .EMIOGEM1DELAYREQRX(gem1_ptp_delay_req_rx),
      .EMIOGEM1DELAYREQTX(gem1_ptp_delay_req_tx),
      .EMIOGEM1PDELAYREQRX(gem1_ptp_pdelay_req_rx),
      .EMIOGEM1PDELAYREQTX(gem1_ptp_pdelay_req_tx),
      .EMIOGEM1PDELAYRESPRX(gem1_ptp_pdelay_resp_rx),
      .EMIOGEM1PDELAYRESPTX(gem1_ptp_pdelay_resp_tx),
      .EMIOGEM1RXSOF(gem1_ptp_rx_sof),
      .EMIOGEM1SYNCFRAMERX(gem1_ptp_sync_frame_rx),
      .EMIOGEM1SYNCFRAMETX(gem1_ptp_sync_frame_tx),
      .EMIOGEM1TSUTIMERCMPVAL(gem1_tsu_timer_cmp_val),
      .EMIOGEM1TXRFIXEDLAT(emio_gem1_tx_r_fixed_lat),
      .EMIOGEM1TXSOF(gem1_ptp_tx_sof),
      .EMIOI2C0SCLO(i2c0_scl_o),
      .EMIOI2C0SCLTN(i2c0_scl_tn_temp),
      .EMIOI2C0SDAO(i2c0_sda_o),
      .EMIOI2C0SDATN(i2c0_sda_tn_temp),
      .EMIOI2C1SCLO(i2c1_scl_o),
      .EMIOI2C1SCLTN(i2c1_scl_tn_temp),
      .EMIOI2C1SDAO(i2c1_sda_o),
      .EMIOI2C1SDATN(i2c1_sda_tn_temp),
      .FMIOI2CSCLOEN(pmc_i2c_scl_oen_temp),
      .FMIOI2CSCLOUT(pmc_i2c_scl_out),
      .FMIOI2CSDAOEN(pmc_i2c_sda_oen_temp),
      .FMIOI2CSDAOUT(pmc_i2c_sda_out),
      .FMIOI2CSCLIN(pmc_i2c_scl_in),
      .FMIOI2CSDAIN(pmc_i2c_sda_in),
      .FMIOLPDPMCEMIOIN (fmio_lpd_pmc_emio_in),
      .EMIOSPI0MO(spi0_m_o),
      .EMIOSPI0MOTN(spi0_m_o_t_n),
      .EMIOSPI0SCLKO(spi0_sclk_o),
      .EMIOSPI0SCLKTN(spi0_sclk_t_n),
      .EMIOSPI0SO(spi0_s_o),
      .EMIOSPI0SSNTN(spi0_ss_n_t_n),
      .EMIOSPI0SSON({spi0_ss2_o_n, spi0_ss1_o_n, spi0_ss_o_n}),
      .EMIOSPI0STN(spi0_s_t_n),
      .EMIOSPI1MO(spi1_m_o),
      .EMIOSPI1MOTN(spi1_m_o_t_n),
      .EMIOSPI1SCLKO(spi1_sclk_o),
      .EMIOSPI1SCLKTN(spi1_sclk_t_n),
      .EMIOSPI1SO(spi1_s_o),
      .EMIOSPI1SSNTN(spi1_ss_n_t_n),
      .EMIOSPI1SSON({spi1_ss2_o_n, spi1_ss1_o_n, spi1_ss_o_n}),
      .EMIOSPI1STN(spi1_s_t_n),
      .EMIOTTC0WAVEO(ttc0_waveo),
      .EMIOTTC1WAVEO(ttc1_waveo),
      .EMIOTTC2WAVEO(ttc2_waveo),
      .EMIOTTC3WAVEO(ttc3_waveo),
      .EMIOU2DSPORTVBUSCTRLUSB30(emio_u2dsport_vbus_ctrl_usb3_0),
    //.EMIOU2DSPORTVBUSCTRLUSB31(emio_u2dsport_vbus_ctrl_usb3_1),
    //.EMIOU3DSPORTVBUSCTRLUSB30(emio_u3dsport_vbus_ctrl_usb3_0),
    //.EMIOU3DSPORTVBUSCTRLUSB31(emio_u3dsport_vbus_ctrl_usb3_1),
      .FMIOUART0NSIROUT(uart0_sir_outn),
      .FMIOUART0NUARTDTR(uart0_dtrn),
      .FMIOUART0NUARTOUT1(uart0_out1n),
      .FMIOUART0NUARTOUT2(uart0_out2n),
      .FMIOUART0NUARTRTS(uart0_rtsn),
      .FMIOUART0TXD(uart0_txd),
      .FMIOUART0NUARTCTS(uart0_ctsn),
      .FMIOUART0NUARTDCD(uart0_dcdn),
      .FMIOUART0NUARTDSR(uart0_dsrn),
      .FMIOUART0NUARTRI(uart0_rin),
      .FMIOUART0RXD(uart0_rxd),
      .FMIOUART0SIRIN(fmio_uart0_sir_in),
      .FMIOUART1NSIROUT(uart1_sir_outn),
      .FMIOUART1NUARTDTR(uart1_dtrn),
      .FMIOUART1NUARTOUT1(uart1_out1n),
      .FMIOUART1NUARTOUT2(uart1_out2n),
      .FMIOUART1NUARTRTS(uart1_rtsn),
      .FMIOUART1TXD(uart1_txd),
      .FMIOUART1NUARTCTS(uart1_ctsn),
      .FMIOUART1NUARTDCD(uart1_dcdn),
      .FMIOUART1NUARTDSR(uart1_dsrn),
      .FMIOUART1NUARTRI(uart1_rin),
      .FMIOUART1RXD(uart1_rxd),
      .FMIOUART1SIRIN(fmio_uart1_sir_in),
    //.EMIOUART0DTRN(emio_uart0dtrn),
    //.EMIOUART0RTSN(emio_uart0rtsn),
    //.EMIOUART0TX(emio_uart0tx),
    //.EMIOUART1DTRN(emio_uart1dtrn),
    //.EMIOUART1RTSN(emio_uart1rtsn),
    //.EMIOUART1TX(emio_uart1tx),
    //.EMIOUART2DTRN(emio_uart2dtrn),
    //.EMIOUART2RTSN(emio_uart2rtsn),
    //.EMIOUART2TX(emio_uart2tx),
    //.EMIOWDT0RSTO(emio_wdt0rsto),
    //.EMIOWDT1RSTO(emio_wdt1rsto),

    //.FMIOGEM0FIFORXCLKTOPLBUFG(fmiogem0fiforxclktoplbufg),
    //.FMIOGEM0FIFOTXCLKTOPLBUFG(fmiogem0fifotxclktoplbufg),

    //.FMIOGEM1FIFORXCLKTOPLBUFG(fmiogem1fiforxclktoplbufg),
    //.FMIOGEM1FIFOTXCLKTOPLBUFG(fmiogem1fifotxclktoplbufg),

    //.FMIOGEM2FIFORXCLKTOPLBUFG(fmiogem2fiforxclktoplbufg),
    //.FMIOGEM2FIFOTXCLKTOPLBUFG(fmiogem2fifotxclktoplbufg),
    //.FMIOGEM3FIFORXCLKTOPLBUFG(fmiogem3fiforxclktoplbufg),
    //.FMIOGEM3FIFOTXCLKTOPLBUFG(fmiogem3fifotxclktoplbufg),
    //.FMIOGEMTSUCLKTOPLBUFG(fmiogemtsuclktoplbufg),
    //.FMIOGPIOOEN(fmio_gpio_o_en),
    //.FMIOGPIOOUT(fmio_gpio_out),
    //.FMIOI2CSCLOEN(fmioi2cscloen),
    //.FMIOI2CSCLOUT(fmioi2csclout),
    //.FMIOI2CSDAOEN(fmioi2csdaoen),
    //.FMIOI2CSDAOUT(fmioi2csdaout),
    //.FMIOSD0BUSPOWEROUT(sd0_buspwr),
    //.FMIOSD0BUSVOLTAGEOUT(sd0_busvolt_sel),
    //.FMIOSD0DLLTESTOUT(sd0_dll_test_out),
    //.FMIOSD0LEDCONTROLOUT(sd0_led_ctrl),
    //.FMIOSD0SDIFCLKOUT(sd0_clk),
    //.FMIOSD0SDIFCMDOE(sd0_cmd_oe),
    //.FMIOSD0SDIFCMDOUT(sd0_cmd_out),
    //.FMIOSD0SDIFDATOE(sd0_data_oe),
    //.FMIOSD0SDIFDATOUT(sd0_data_out),
      .FMIOSD0BUSPOWEROUT(sd0_buspwr),
      .FMIOSD0BUSVOLTAGEOUT(sd0_busvolt_sel),
      .FMIOSD0DLLTESTCLK0(sd0_dll_test_clk0),
      .FMIOSD0DLLTESTCLKRX(sd0_dll_test_clk_rx),
      .FMIOSD0DLLTESTCLKTX(sd0_dll_test_clk_tx),
      .FMIOSD0DLLTESTOUT(sd0_dll_test_out),
      .FMIOSD0LEDCONTROLOUT(sd0_led_ctrl),
      .FMIOSD0SDIFCLKOUT(sd0_clk),
      .FMIOSD0SDIFCMDOE(sd0_cmd_oe),
      .FMIOSD0SDIFCMDOUT(sd0_cmd_out),
      .FMIOSD0SDIFDATOE(fmiosd0sdifdatoe_t),
      .FMIOSD0SDIFDATOUT(fmiosd0sdifdatout_t),
      .FMIOSD0DLLTESTIN(sd0_dll_test_in),
      .FMIOSD0SDIFCDNIN(sd0_cd_n),
      .FMIOSD0SDIFCMDIN(sd0_cmd_in),
      .FMIOSD0SDIFDATIN(sd0_data_in_temp),
      .FMIOSD0SDIFWPIN(sd0_wp),

      .FMIOSD1BUSPOWEROUT(sd1_bus_pwr),
      .FMIOSD1BUSVOLTAGEOUT(sd1_busvolt_sel),
      .FMIOSD1DLLTESTCLK0(sd1_dll_test_clk0),
      .FMIOSD1DLLTESTCLKRX(sd1_dll_test_clk_rx),
      .FMIOSD1DLLTESTCLKTX(sd1_dll_test_clk_tx),
      .FMIOSD1DLLTESTOUT(sd1_dll_test_out),
      .FMIOSD1LEDCONTROLOUT(sd1_led_ctrl),
      .FMIOSD1SDIFCLKOUT(sd1_clk),
      .FMIOSD1SDIFCMDOE(sd1_cmd_oe),
      .FMIOSD1SDIFCMDOUT(sd1_cmd_out),
      .FMIOSD1SDIFDATOE(fmiosd1sdifdatoe_t),
      .FMIOSD1SDIFDATOUT(fmiosd1sdifdatout_t),
      .FMIOSD1DLLTESTIN(sd1_dll_test_in),
      .FMIOSD1SDIFCDNIN(sd1_cd_n),
      .FMIOSD1SDIFCMDIN(sd1_cmd_in),
      .FMIOSD1SDIFDATIN(sd1_data_in_temp),
      .FMIOSD1SDIFWPIN(sd1_wp),

      .FMIOFPDWWDTINTERRUPT(fpd_swdt_wwdt_irq),
      .FMIOFPDWWDTRESET(fpd_swdt_wwdt_reset),
      .FMIOFPDWWDTRESETPENDING(fpd_swdt_wwdt_reset_pending),
      .FMIOWWDTINTERRUPT(lpd_swdt_wwdt_irq),
      .FMIOWWDTRESET(lpd_swdt_wwdt_reset),
      .FMIOWWDTRESETPENDING(lpd_swdt_wwdt_reset_pending),
      .FMIOFPDWWDTCLKIN(fpd_swdt_wwdt_clk),
      .FMIOWWDTCLKIN(lpd_swdt_wwdt_clk),
      .HSMREFCLK(hsm_ref_clk),
      .FMIOGWDTWS0(lpd_swdt_gwdt_ws0),
      .FMIOGWDTWS1(lpd_swdt_gwdt_ws1),
      .FMIOFPDGWDTWS0(fpd_swdt_gwdt_ws0),
      .FMIOFPDGWDTWS1(fpd_swdt_gwdt_ws1),

    //.FMIOSD1BUSPOWEROUT(sd1_bus_pwr),
    //.FMIOSD1BUSVOLTAGEOUT(sd0_busvolt_sel),
    //.FMIOSD1DLLTESTOUT(sd1_dll_test_out),
    //.FMIOSD1LEDCONTROLOUT(sd1_led_ctrl),
    //.FMIOSD1SDIFCLKOUT(sd1_clk),
    //.FMIOSD1SDIFCMDOE(sd1_cmd_oe),
    //.FMIOSD1SDIFCMDOUT(sd1_cmd_out),
    //.FMIOSD1SDIFDATOE(sd1_data_oe),
    //.FMIOSD1SDIFDATOUT(sd1_data_out),
      .EMIOGPIO2O(lpd_gpio_o),
      .EMIOGPIO2TN(lpd_gpio_tn_temp),
      .EMIOGPIO2I(lpd_gpio_i),
      .FMIOGPIOOEN(emio_pmc_gpio_oen_temp),
      .FMIOGPIOOUT(emio_pmc_gpio_out_temp),
      .FMIOGPIOIN(emio_pmc_gpio_in_temp),

      .FMIOSYSMONI2CSCLTRIB(pmc_pl_sysmon_i2c_scl_trib),
      .FMIOSYSMONI2CSDATRIB(pmc_pl_sysmon_i2c_sda_trib),
      .FMIOSYSMONI2CSMBALERTTRIB(pmc_pl_sysmon_i2c_smb_alert_trib),
      .FMIOSYSMONI2CSCLINPUT(pmc_pl_sysmon_i2c_scl_input),
      .FMIOSYSMONI2CSDAINPUT(pmc_pl_sysmon_i2c_sda_input),
      .PMCPLGPO (pmc_pl_gpo),
      .PMCPLGPI (pmc_pl_gpi),
      .PMCPLSYSMONROOTALARM(pmc_pl_sysmon_root_alarm),
      .PMCPLSYSMONROOTNEWDATA(pmc_pl_sysmon_root_new_data),
    //.IFFPDSYSMONSATTESTFABRICCLK(iffpdsysmonsattestfabricclk),
    //.IFFPDSYSMONSATTESTTESTADCIN(iffpdsysmonsattesttestadcin),
    //.IFFPDSYSMONSATTESTTESTADCINCLK(iffpdsysmonsattesttestadcinclk),
    //.IFLPDSYSMONSATTESTFABRICCLK(iflpdsysmonsattestfabricclk),
    //.IFLPDSYSMONSATTESTTESTADCIN(iflpdsysmonsattesttestadcin),
    //.IFLPDSYSMONSATTESTTESTADCINCLK(iflpdsysmonsattesttestadcinclk),
    //.IFSYSMONROOTTESTFABRICCLK(ifsysmonroottestfabricclk),
    //.IFSYSMONROOTTESTTESTADCIN(ifsysmonroottesttestadcin),
    //.IFSYSMONROOTTESTTESTADCINCLK(ifsysmonroottesttestadcinclk),
      .IFSYSMONROOTUSERMUXADDR(user_mux), 
      .IFPSOCM2APBPRDATA  (ps_ocm2_apb_prdata  ),
      .IFPSOCM2APBPREADY  (ps_ocm2_apb_pready  ),
      .IFPSOCM2APBPSLVERR (ps_ocm2_apb_pslverr ),
      .IFPSOCM2APBPADDR   (ps_ocm2_apb_paddr   ),
      .IFPSOCM2APBPENABLE (ps_ocm2_apb_penable ),
      .IFPSOCM2APBPPROT   (ps_ocm2_apb_pprot   ),
      .IFPSOCM2APBPSEL    (ps_ocm2_apb_psel    ),
      .IFPSOCM2APBPSTRB   (ps_ocm2_apb_pstrb   ),
      .IFPSOCM2APBPWDATA  (ps_ocm2_apb_pwdata  ),
      .IFPSOCM2APBPWRITE  (ps_ocm2_apb_pwrite  ),
      .IFPSOCM2AXIARREADY (ps_ocm2_axi_arready ),
      .IFPSOCM2AXIAWREADY (ps_ocm2_axi_awready ),
      .IFPSOCM2AXIBID     (ps_ocm2_axi_bid     ),
      .IFPSOCM2AXIBRESP   (ps_ocm2_axi_bresp   ),
      .IFPSOCM2AXIBUSER   (ps_ocm2_axi_buser   ),
      .IFPSOCM2AXIBVALID  (ps_ocm2_axi_bvalid  ),
      .IFPSOCM2AXIRDATA   (ps_ocm2_axi_rdata   ),
      .IFPSOCM2AXIRID     (ps_ocm2_axi_rid     ),
      .IFPSOCM2AXIRLAST   (ps_ocm2_axi_rlast   ),
      .IFPSOCM2AXIRRESP   (ps_ocm2_axi_rresp   ),
      .IFPSOCM2AXIRUSER   (ps_ocm2_axi_ruser   ),
      .IFPSOCM2AXIRVALID  (ps_ocm2_axi_rvalid  ),
      .IFPSOCM2AXIWREADY  (ps_ocm2_axi_wready  ),
      .IFPSOCM2AXIARADDR  (ps_ocm2_axi_araddr  ),
      .IFPSOCM2AXIARBURST (ps_ocm2_axi_arburst ),
      .IFPSOCM2AXIARCACHE (ps_ocm2_axi_arcache ),
      .IFPSOCM2AXIARID    (ps_ocm2_axi_arid    ),
      .IFPSOCM2AXIARLEN   (ps_ocm2_axi_arlen   ),
      .IFPSOCM2AXIARLOCK  (ps_ocm2_axi_arlock  ),
      .IFPSOCM2AXIARPROT  (ps_ocm2_axi_arprot  ),
      .IFPSOCM2AXIARQOS   (ps_ocm2_axi_arqos   ),
      .IFPSOCM2AXIARREGION(ps_ocm2_axi_arregion),
      .IFPSOCM2AXIARSIZE  (ps_ocm2_axi_arsize  ),
      .IFPSOCM2AXIARUSER  (ps_ocm2_axi_aruser  ),
      .IFPSOCM2AXIARVALID (ps_ocm2_axi_arvalid ),
      .IFPSOCM2AXIAWADDR  (ps_ocm2_axi_awaddr  ),
      .IFPSOCM2AXIAWBURST (ps_ocm2_axi_awburst ),
      .IFPSOCM2AXIAWCACHE (ps_ocm2_axi_awcache ),
      .IFPSOCM2AXIAWID    (ps_ocm2_axi_awid    ),
      .IFPSOCM2AXIAWLEN   (ps_ocm2_axi_awlen   ),
      .IFPSOCM2AXIAWLOCK  (ps_ocm2_axi_awlock  ),
      .IFPSOCM2AXIAWPROT  (ps_ocm2_axi_awprot  ),
      .IFPSOCM2AXIAWQOS   (ps_ocm2_axi_awqos   ),
      .IFPSOCM2AXIAWREGION(ps_ocm2_axi_awregion),
      .IFPSOCM2AXIAWSIZE  (ps_ocm2_axi_awsize  ),
      .IFPSOCM2AXIAWUSER  (ps_ocm2_axi_awuser  ),
      .IFPSOCM2AXIAWVALID (ps_ocm2_axi_awvalid ),
      .IFPSOCM2AXIBREADY  (ps_ocm2_axi_bready  ),
      .IFPSOCM2AXIRREADY  (ps_ocm2_axi_rready  ),
      .IFPSOCM2AXIWDATA   (ps_ocm2_axi_wdata   ),
      .IFPSOCM2AXIWID     (ps_ocm2_axi_wid     ),
      .IFPSOCM2AXIWLAST   (ps_ocm2_axi_wlast   ),
      .IFPSOCM2AXIWSTRB   (ps_ocm2_axi_wstrb   ),
      .IFPSOCM2AXIWUSER   (ps_ocm2_axi_wuser   ),
      .IFPSOCM2AXIWVALID  (ps_ocm2_axi_wvalid  ),
       
      .IFNOCPSCCIAXI0ARREADY(noc_fpd_cci_axi0_arready),
      .IFNOCPSCCIAXI0AWREADY(noc_fpd_cci_axi0_awready),
      .IFNOCPSCCIAXI0BID(noc_fpd_cci_axi0_bid),
      .IFNOCPSCCIAXI0BRESP(noc_fpd_cci_axi0_bresp),
      .IFNOCPSCCIAXI0BUSER(noc_fpd_cci_axi0_buser),
      .IFNOCPSCCIAXI0BVALID(noc_fpd_cci_axi0_bvalid),
      .IFNOCPSCCIAXI0RDATA(noc_fpd_cci_axi0_rdata),
      .IFNOCPSCCIAXI0RID(noc_fpd_cci_axi0_rid),
      .IFNOCPSCCIAXI0RLAST(noc_fpd_cci_axi0_rlast),
      .IFNOCPSCCIAXI0RRESP(noc_fpd_cci_axi0_rresp),
      .IFNOCPSCCIAXI0RUSER(noc_fpd_cci_axi0_ruser),
      .IFNOCPSCCIAXI0RVALID(noc_fpd_cci_axi0_rvalid),
      .IFNOCPSCCIAXI0WREADY(noc_fpd_cci_axi0_wready),
      .IFNOCPSCCIAXI1ARREADY(noc_fpd_cci_axi1_arready),
      .IFNOCPSCCIAXI1AWREADY(noc_fpd_cci_axi1_awready),
      .IFNOCPSCCIAXI1BID(noc_fpd_cci_axi1_bid),
      .IFNOCPSCCIAXI1BRESP(noc_fpd_cci_axi1_bresp),
      .IFNOCPSCCIAXI1BUSER(noc_fpd_cci_axi1_buser),
      .IFNOCPSCCIAXI1BVALID(noc_fpd_cci_axi1_bvalid),
      .IFNOCPSCCIAXI1RDATA(noc_fpd_cci_axi1_rdata),
      .IFNOCPSCCIAXI1RID(noc_fpd_cci_axi1_rid),
      .IFNOCPSCCIAXI1RLAST(noc_fpd_cci_axi1_rlast),
      .IFNOCPSCCIAXI1RRESP(noc_fpd_cci_axi1_rresp),
      .IFNOCPSCCIAXI1RUSER(noc_fpd_cci_axi1_ruser),
      .IFNOCPSCCIAXI1RVALID(noc_fpd_cci_axi1_rvalid),
      .IFNOCPSCCIAXI1WREADY(noc_fpd_cci_axi1_wready),
      .IFNOCPSNCIAXI0ARREADY(noc_fpd_axi_axi0_arready),
      .IFNOCPSNCIAXI0AWREADY(noc_fpd_axi_axi0_awready),
      .IFNOCPSNCIAXI0BID(noc_fpd_axi_axi0_bid),
      .IFNOCPSNCIAXI0BRESP(noc_fpd_axi_axi0_bresp),
      .IFNOCPSNCIAXI0BUSER(noc_fpd_axi_axi0_buser),
      .IFNOCPSNCIAXI0BVALID(noc_fpd_axi_axi0_bvalid),
      .IFNOCPSNCIAXI0RDATA(noc_fpd_axi_axi0_rdata),
      .IFNOCPSNCIAXI0RID(noc_fpd_axi_axi0_rid),
      .IFNOCPSNCIAXI0RLAST(noc_fpd_axi_axi0_rlast),
      .IFNOCPSNCIAXI0RRESP(noc_fpd_axi_axi0_rresp),
      .IFNOCPSNCIAXI0RUSER(noc_fpd_axi_axi0_ruser),
      .IFNOCPSNCIAXI0RVALID(noc_fpd_axi_axi0_rvalid),
      .IFNOCPSNCIAXI0WREADY(noc_fpd_axi_axi0_wready),
      .IFNOCPSNCIAXI1ARREADY(noc_fpd_axi_axi1_arready),
      .IFNOCPSNCIAXI1AWREADY(noc_fpd_axi_axi1_awready),
      .IFNOCPSNCIAXI1BID(noc_fpd_axi_axi1_bid),
      .IFNOCPSNCIAXI1BRESP(noc_fpd_axi_axi1_bresp),
      .IFNOCPSNCIAXI1BUSER(noc_fpd_axi_axi1_buser),
      .IFNOCPSNCIAXI1BVALID(noc_fpd_axi_axi1_bvalid),
      .IFNOCPSNCIAXI1RDATA(noc_fpd_axi_axi1_rdata),
      .IFNOCPSNCIAXI1RID(noc_fpd_axi_axi1_rid),
      .IFNOCPSNCIAXI1RLAST(noc_fpd_axi_axi1_rlast),
      .IFNOCPSNCIAXI1RRESP(noc_fpd_axi_axi1_rresp),
      .IFNOCPSNCIAXI1RUSER(noc_fpd_axi_axi1_ruser),
      .IFNOCPSNCIAXI1RVALID(noc_fpd_axi_axi1_rvalid),
      .IFNOCPSNCIAXI1WREADY(noc_fpd_axi_axi1_wready),
      .IFNOCPSPCIAXI0ARREADY(noc_cpm_pcie_axi0_arready),
      .IFNOCPSPCIAXI0AWREADY(noc_cpm_pcie_axi0_awready),
      .IFNOCPSPCIAXI0BID(noc_cpm_pcie_axi0_bid),
      .IFNOCPSPCIAXI0BRESP(noc_cpm_pcie_axi0_bresp),
      .IFNOCPSPCIAXI0BUSER(noc_cpm_pcie_axi0_buser),
      .IFNOCPSPCIAXI0BVALID(noc_cpm_pcie_axi0_bvalid),
      .IFNOCPSPCIAXI0RDATA(noc_cpm_pcie_axi0_rdata),
      .IFNOCPSPCIAXI0RID(noc_cpm_pcie_axi0_rid),
      .IFNOCPSPCIAXI0RLAST(noc_cpm_pcie_axi0_rlast),
      .IFNOCPSPCIAXI0RRESP(noc_cpm_pcie_axi0_rresp),
      .IFNOCPSPCIAXI0RUSER(noc_cpm_pcie_axi0_ruser),
      .IFNOCPSPCIAXI0RVALID(noc_cpm_pcie_axi0_rvalid),
      .IFNOCPSPCIAXI0WREADY(noc_cpm_pcie_axi0_wready),

      .IFPMCCFUSEUCFUSEUCRCERROR(debug_seu_crcerror),
      .IFPMCCFUSEUCFUSEUECCERROR(debug_seu_eccerror),
      .IFPMCCFUSEUCFUSEUENDOFCALIB(debug_seu_endofcalib),
      .IFPMCCFUSEUCFUSEUHALTED    (debug_seu_halted),
      .IFPMCCFUSEUCFUSEUHEARTBEAT(debug_seu_heartbeat),

      .IFPSNOCCCIAXI0ARADDR(fpd_cci_noc_axi0_araddr),
      .IFPSNOCCCIAXI0ARBURST(fpd_cci_noc_axi0_arburst),
      .IFPSNOCCCIAXI0ARCACHE(fpd_cci_noc_axi0_arcache),
      .IFPSNOCCCIAXI0ARID(fpd_cci_noc_axi0_arid),
      .IFPSNOCCCIAXI0ARLEN(fpd_cci_noc_axi0_arlen),
      .IFPSNOCCCIAXI0ARLOCK(fpd_cci_noc_axi0_arlock),
      .IFPSNOCCCIAXI0ARPROT(fpd_cci_noc_axi0_arprot),
      .IFPSNOCCCIAXI0ARQOS(fpd_cci_noc_axi0_arqos),
      .IFPSNOCCCIAXI0ARREGION(if_ps_noc_cci_axi0_arregion),
      .IFPSNOCCCIAXI0ARSIZE(fpd_cci_noc_axi0_arsize),
      .IFPSNOCCCIAXI0ARUSER(fpd_cci_noc_axi0_aruser),
      .IFPSNOCCCIAXI0ARVALID(fpd_cci_noc_axi0_arvalid),
      .IFPSNOCCCIAXI0AWADDR(fpd_cci_noc_axi0_awaddr),
      .IFPSNOCCCIAXI0AWBURST(fpd_cci_noc_axi0_awburst),
      .IFPSNOCCCIAXI0AWCACHE(fpd_cci_noc_axi0_awcache),
      .IFPSNOCCCIAXI0AWID(fpd_cci_noc_axi0_awid),
      .IFPSNOCCCIAXI0AWLEN(fpd_cci_noc_axi0_awlen),
      .IFPSNOCCCIAXI0AWLOCK(fpd_cci_noc_axi0_awlock),
      .IFPSNOCCCIAXI0AWPROT(fpd_cci_noc_axi0_awprot),
      .IFPSNOCCCIAXI0AWQOS(fpd_cci_noc_axi0_awqos),
      .IFPSNOCCCIAXI0AWREGION(if_ps_noc_cci_axi0_awregion),
      .IFPSNOCCCIAXI0AWSIZE(fpd_cci_noc_axi0_awsize),
      .IFPSNOCCCIAXI0AWUSER(fpd_cci_noc_axi0_awuser),
      .IFPSNOCCCIAXI0AWVALID(fpd_cci_noc_axi0_awvalid),
      .IFPSNOCCCIAXI0BREADY(fpd_cci_noc_axi0_bready),
      .IFPSNOCCCIAXI0RREADY(fpd_cci_noc_axi0_rready),
      .IFPSNOCCCIAXI0WDATA(fpd_cci_noc_axi0_wdata),
      .IFPSNOCCCIAXI0WID(if_ps_noc_cci_axi0_wid),
      .IFPSNOCCCIAXI0WLAST(fpd_cci_noc_axi0_wlast),
      .IFPSNOCCCIAXI0WSTRB(fpd_cci_noc_axi0_wstrb),
      .IFPSNOCCCIAXI0WUSER(fpd_cci_noc_axi0_wuser),
      .IFPSNOCCCIAXI0WVALID(fpd_cci_noc_axi0_wvalid),
      .IFPSNOCCCIAXI1ARADDR(fpd_cci_noc_axi1_araddr),
      .IFPSNOCCCIAXI1ARBURST(fpd_cci_noc_axi1_arburst),
      .IFPSNOCCCIAXI1ARCACHE(fpd_cci_noc_axi1_arcache),
      .IFPSNOCCCIAXI1ARID(fpd_cci_noc_axi1_arid),
      .IFPSNOCCCIAXI1ARLEN(fpd_cci_noc_axi1_arlen),
      .IFPSNOCCCIAXI1ARLOCK(fpd_cci_noc_axi1_arlock),
      .IFPSNOCCCIAXI1ARPROT(fpd_cci_noc_axi1_arprot),
      .IFPSNOCCCIAXI1ARQOS(fpd_cci_noc_axi1_arqos),
      .IFPSNOCCCIAXI1ARREGION(if_ps_noc_cci_axi1_arregion),
      .IFPSNOCCCIAXI1ARSIZE(fpd_cci_noc_axi1_arsize),
      .IFPSNOCCCIAXI1ARUSER(fpd_cci_noc_axi1_aruser),
      .IFPSNOCCCIAXI1ARVALID(fpd_cci_noc_axi1_arvalid),
      .IFPSNOCCCIAXI1AWADDR(fpd_cci_noc_axi1_awaddr),
      .IFPSNOCCCIAXI1AWBURST(fpd_cci_noc_axi1_awburst),
      .IFPSNOCCCIAXI1AWCACHE(fpd_cci_noc_axi1_awcache),
      .IFPSNOCCCIAXI1AWID(fpd_cci_noc_axi1_awid),
      .IFPSNOCCCIAXI1AWLEN(fpd_cci_noc_axi1_awlen),
      .IFPSNOCCCIAXI1AWLOCK(fpd_cci_noc_axi1_awlock),
      .IFPSNOCCCIAXI1AWPROT(fpd_cci_noc_axi1_awprot),
      .IFPSNOCCCIAXI1AWQOS(fpd_cci_noc_axi1_awqos),
      .IFPSNOCCCIAXI1AWREGION(if_ps_noc_cci_axi1_awregion),
      .IFPSNOCCCIAXI1AWSIZE(fpd_cci_noc_axi1_awsize),
      .IFPSNOCCCIAXI1AWUSER(fpd_cci_noc_axi1_awuser),
      .IFPSNOCCCIAXI1AWVALID(fpd_cci_noc_axi1_awvalid),
      .IFPSNOCCCIAXI1BREADY(fpd_cci_noc_axi1_bready),
      .IFPSNOCCCIAXI1RREADY(fpd_cci_noc_axi1_rready),
      .IFPSNOCCCIAXI1WDATA(fpd_cci_noc_axi1_wdata),
      .IFPSNOCCCIAXI1WID(if_ps_noc_cci_axi1_wid),
      .IFPSNOCCCIAXI1WLAST(fpd_cci_noc_axi1_wlast),
      .IFPSNOCCCIAXI1WSTRB(fpd_cci_noc_axi1_wstrb),
      .IFPSNOCCCIAXI1WUSER(fpd_cci_noc_axi1_wuser),
      .IFPSNOCCCIAXI1WVALID(fpd_cci_noc_axi1_wvalid),
      .IFPSNOCCCIAXI2ARADDR(fpd_cci_noc_axi2_araddr),
      .IFPSNOCCCIAXI2ARBURST(fpd_cci_noc_axi2_arburst),
      .IFPSNOCCCIAXI2ARCACHE(fpd_cci_noc_axi2_arcache),
      .IFPSNOCCCIAXI2ARID(fpd_cci_noc_axi2_arid),
      .IFPSNOCCCIAXI2ARLEN(fpd_cci_noc_axi2_arlen),
      .IFPSNOCCCIAXI2ARLOCK(fpd_cci_noc_axi2_arlock),
      .IFPSNOCCCIAXI2ARPROT(fpd_cci_noc_axi2_arprot),
      .IFPSNOCCCIAXI2ARQOS(fpd_cci_noc_axi2_arqos),
      .IFPSNOCCCIAXI2ARREGION(if_ps_noc_cci_axi2_arregion),
      .IFPSNOCCCIAXI2ARSIZE(fpd_cci_noc_axi2_arsize),
      .IFPSNOCCCIAXI2ARUSER(fpd_cci_noc_axi2_aruser),
      .IFPSNOCCCIAXI2ARVALID(fpd_cci_noc_axi2_arvalid),
      .IFPSNOCCCIAXI2AWADDR(fpd_cci_noc_axi2_awaddr),
      .IFPSNOCCCIAXI2AWBURST(fpd_cci_noc_axi2_awburst),
      .IFPSNOCCCIAXI2AWCACHE(fpd_cci_noc_axi2_awcache),
      .IFPSNOCCCIAXI2AWID(fpd_cci_noc_axi2_awid),
      .IFPSNOCCCIAXI2AWLEN(fpd_cci_noc_axi2_awlen),
      .IFPSNOCCCIAXI2AWLOCK(fpd_cci_noc_axi2_awlock),
      .IFPSNOCCCIAXI2AWPROT(fpd_cci_noc_axi2_awprot),
      .IFPSNOCCCIAXI2AWQOS(fpd_cci_noc_axi2_awqos),
      .IFPSNOCCCIAXI2AWREGION(if_ps_noc_cci_axi2_awregion),
      .IFPSNOCCCIAXI2AWSIZE(fpd_cci_noc_axi2_awsize),
      .IFPSNOCCCIAXI2AWUSER(fpd_cci_noc_axi2_awuser),
      .IFPSNOCCCIAXI2AWVALID(fpd_cci_noc_axi2_awvalid),
      .IFPSNOCCCIAXI2BREADY(fpd_cci_noc_axi2_bready),
      .IFPSNOCCCIAXI2RREADY(fpd_cci_noc_axi2_rready),
      .IFPSNOCCCIAXI2WDATA(fpd_cci_noc_axi2_wdata),
      .IFPSNOCCCIAXI2WID(if_ps_noc_cci_axi2_wid),
      .IFPSNOCCCIAXI2WLAST(fpd_cci_noc_axi2_wlast),
      .IFPSNOCCCIAXI2WSTRB(fpd_cci_noc_axi2_wstrb),
      .IFPSNOCCCIAXI2WUSER(fpd_cci_noc_axi2_wuser),
      .IFPSNOCCCIAXI2WVALID(fpd_cci_noc_axi2_wvalid),
      .IFPSNOCCCIAXI3ARADDR(fpd_cci_noc_axi3_araddr),
      .IFPSNOCCCIAXI3ARBURST(fpd_cci_noc_axi3_arburst),
      .IFPSNOCCCIAXI3ARCACHE(fpd_cci_noc_axi3_arcache),
      .IFPSNOCCCIAXI3ARID(fpd_cci_noc_axi3_arid),
      .IFPSNOCCCIAXI3ARLEN(fpd_cci_noc_axi3_arlen),
      .IFPSNOCCCIAXI3ARLOCK(fpd_cci_noc_axi3_arlock),
      .IFPSNOCCCIAXI3ARPROT(fpd_cci_noc_axi3_arprot),
      .IFPSNOCCCIAXI3ARQOS(fpd_cci_noc_axi3_arqos),
      .IFPSNOCCCIAXI3ARREGION(if_ps_noc_cci_axi3_arregion),
      .IFPSNOCCCIAXI3ARSIZE(fpd_cci_noc_axi3_arsize),
      .IFPSNOCCCIAXI3ARUSER(fpd_cci_noc_axi3_aruser),
      .IFPSNOCCCIAXI3ARVALID(fpd_cci_noc_axi3_arvalid),
      .IFPSNOCCCIAXI3AWADDR(fpd_cci_noc_axi3_awaddr),
      .IFPSNOCCCIAXI3AWBURST(fpd_cci_noc_axi3_awburst),
      .IFPSNOCCCIAXI3AWCACHE(fpd_cci_noc_axi3_awcache),
      .IFPSNOCCCIAXI3AWID(fpd_cci_noc_axi3_awid),
      .IFPSNOCCCIAXI3AWLEN(fpd_cci_noc_axi3_awlen),
      .IFPSNOCCCIAXI3AWLOCK(fpd_cci_noc_axi3_awlock),
      .IFPSNOCCCIAXI3AWPROT(fpd_cci_noc_axi3_awprot),
      .IFPSNOCCCIAXI3AWQOS(fpd_cci_noc_axi3_awqos),
      .IFPSNOCCCIAXI3AWREGION(if_ps_noc_cci_axi3_awregion),
      .IFPSNOCCCIAXI3AWSIZE(fpd_cci_noc_axi3_awsize),
      .IFPSNOCCCIAXI3AWUSER(fpd_cci_noc_axi3_awuser),
      .IFPSNOCCCIAXI3AWVALID(fpd_cci_noc_axi3_awvalid),
      .IFPSNOCCCIAXI3BREADY(fpd_cci_noc_axi3_bready),
      .IFPSNOCCCIAXI3RREADY(fpd_cci_noc_axi3_rready),
      .IFPSNOCCCIAXI3WDATA(fpd_cci_noc_axi3_wdata),
      .IFPSNOCCCIAXI3WID(if_ps_noc_cci_axi3_wid),
      .IFPSNOCCCIAXI3WLAST(fpd_cci_noc_axi3_wlast),
      .IFPSNOCCCIAXI3WSTRB(fpd_cci_noc_axi3_wstrb),
      .IFPSNOCCCIAXI3WUSER(fpd_cci_noc_axi3_wuser),
      .IFPSNOCCCIAXI3WVALID(fpd_cci_noc_axi3_wvalid),
      .IFPSNOCNCIAXI0ARADDR(fpd_axi_noc_axi0_araddr),
      .IFPSNOCNCIAXI0ARBURST(fpd_axi_noc_axi0_arburst),
      .IFPSNOCNCIAXI0ARCACHE(fpd_axi_noc_axi0_arcache),
      .IFPSNOCNCIAXI0ARID(fpd_axi_noc_axi0_arid),
      .IFPSNOCNCIAXI0ARLEN(fpd_axi_noc_axi0_arlen),
      .IFPSNOCNCIAXI0ARLOCK(fpd_axi_noc_axi0_arlock),
      .IFPSNOCNCIAXI0ARPROT(fpd_axi_noc_axi0_arprot),
      .IFPSNOCNCIAXI0ARQOS(fpd_axi_noc_axi0_arqos),
      .IFPSNOCNCIAXI0ARREGION(if_ps_noc_nci_axi0_arregion),
      .IFPSNOCNCIAXI0ARSIZE(fpd_axi_noc_axi0_arsize),
      .IFPSNOCNCIAXI0ARUSER(fpd_axi_noc_axi0_aruser),
      .IFPSNOCNCIAXI0ARVALID(fpd_axi_noc_axi0_arvalid),
      .IFPSNOCNCIAXI0AWADDR(fpd_axi_noc_axi0_awaddr),
      .IFPSNOCNCIAXI0AWBURST(fpd_axi_noc_axi0_awburst),
      .IFPSNOCNCIAXI0AWCACHE(fpd_axi_noc_axi0_awcache),
      .IFPSNOCNCIAXI0AWID(fpd_axi_noc_axi0_awid),
      .IFPSNOCNCIAXI0AWLEN(fpd_axi_noc_axi0_awlen),
      .IFPSNOCNCIAXI0AWLOCK(fpd_axi_noc_axi0_awlock),
      .IFPSNOCNCIAXI0AWPROT(fpd_axi_noc_axi0_awprot),
      .IFPSNOCNCIAXI0AWQOS(fpd_axi_noc_axi0_awqos),
      .IFPSNOCNCIAXI0AWREGION(if_ps_noc_nci_axi0_awregion),
      .IFPSNOCNCIAXI0AWSIZE(fpd_axi_noc_axi0_awsize),
      .IFPSNOCNCIAXI0AWUSER(fpd_axi_noc_axi0_awuser),
      .IFPSNOCNCIAXI0AWVALID(fpd_axi_noc_axi0_awvalid),
      .IFPSNOCNCIAXI0BREADY(fpd_axi_noc_axi0_bready),
      .IFPSNOCNCIAXI0RREADY(fpd_axi_noc_axi0_rready),
      .IFPSNOCNCIAXI0WDATA(fpd_axi_noc_axi0_wdata),
      .IFPSNOCNCIAXI0WID(if_ps_noc_nci_axi0_wid),
      .IFPSNOCNCIAXI0WLAST(fpd_axi_noc_axi0_wlast),
      .IFPSNOCNCIAXI0WSTRB(fpd_axi_noc_axi0_wstrb),
      .IFPSNOCNCIAXI0WUSER(if_ps_noc_nci_axi0_wuser),
      .IFPSNOCNCIAXI0WVALID(fpd_axi_noc_axi0_wvalid),
      .IFPSNOCNCIAXI1ARADDR(fpd_axi_noc_axi1_araddr),
      .IFPSNOCNCIAXI1ARBURST(fpd_axi_noc_axi1_arburst),
      .IFPSNOCNCIAXI1ARCACHE(fpd_axi_noc_axi1_arcache),
      .IFPSNOCNCIAXI1ARID(fpd_axi_noc_axi1_arid),
      .IFPSNOCNCIAXI1ARLEN(fpd_axi_noc_axi1_arlen),
      .IFPSNOCNCIAXI1ARLOCK(fpd_axi_noc_axi1_arlock),
      .IFPSNOCNCIAXI1ARPROT(fpd_axi_noc_axi1_arprot),
      .IFPSNOCNCIAXI1ARQOS(fpd_axi_noc_axi1_arqos),
      .IFPSNOCNCIAXI1ARREGION(if_ps_noc_nci_axi1_arregion),
      .IFPSNOCNCIAXI1ARSIZE(fpd_axi_noc_axi1_arsize),
      .IFPSNOCNCIAXI1ARUSER(fpd_axi_noc_axi1_aruser),
      .IFPSNOCNCIAXI1ARVALID(fpd_axi_noc_axi1_arvalid),
      .IFPSNOCNCIAXI1AWADDR(fpd_axi_noc_axi1_awaddr),
      .IFPSNOCNCIAXI1AWBURST(fpd_axi_noc_axi1_awburst),
      .IFPSNOCNCIAXI1AWCACHE(fpd_axi_noc_axi1_awcache),
      .IFPSNOCNCIAXI1AWID(fpd_axi_noc_axi1_awid),
      .IFPSNOCNCIAXI1AWLEN(fpd_axi_noc_axi1_awlen),
      .IFPSNOCNCIAXI1AWLOCK(fpd_axi_noc_axi1_awlock),
      .IFPSNOCNCIAXI1AWPROT(fpd_axi_noc_axi1_awprot),
      .IFPSNOCNCIAXI1AWQOS(fpd_axi_noc_axi1_awqos),
      .IFPSNOCNCIAXI1AWREGION(if_ps_noc_nci_axi1_awregion),
      .IFPSNOCNCIAXI1AWSIZE(fpd_axi_noc_axi1_awsize),
      .IFPSNOCNCIAXI1AWUSER(fpd_axi_noc_axi1_awuser),
      .IFPSNOCNCIAXI1AWVALID(fpd_axi_noc_axi1_awvalid),
      .IFPSNOCNCIAXI1BREADY(fpd_axi_noc_axi1_bready),
      .IFPSNOCNCIAXI1RREADY(fpd_axi_noc_axi1_rready),
      .IFPSNOCNCIAXI1WDATA(fpd_axi_noc_axi1_wdata),
      .IFPSNOCNCIAXI1WID(if_ps_noc_nci_axi1_wid),
      .IFPSNOCNCIAXI1WLAST(fpd_axi_noc_axi1_wlast),
      .IFPSNOCNCIAXI1WSTRB(fpd_axi_noc_axi1_wstrb),
      .IFPSNOCNCIAXI1WUSER(if_ps_noc_nci_axi1_wuser),
      .IFPSNOCNCIAXI1WVALID(fpd_axi_noc_axi1_wvalid),
      .IFPSNOCPCIAXI0ARADDR(cpm_pcie_noc_axi0_araddr),
      .IFPSNOCPCIAXI0ARBURST(cpm_pcie_noc_axi0_arburst),
      .IFPSNOCPCIAXI0ARCACHE(cpm_pcie_noc_axi0_arcache),
      .IFPSNOCPCIAXI0ARID(cpm_pcie_noc_axi0_arid),
      .IFPSNOCPCIAXI0ARLEN(cpm_pcie_noc_axi0_arlen),
      .IFPSNOCPCIAXI0ARLOCK(cpm_pcie_noc_axi0_arlock),
      .IFPSNOCPCIAXI0ARPROT(cpm_pcie_noc_axi0_arprot),
      .IFPSNOCPCIAXI0ARQOS(cpm_pcie_noc_axi0_arqos),
      .IFPSNOCPCIAXI0ARREGION(if_ps_noc_pci_axi0_arregion),
      .IFPSNOCPCIAXI0ARSIZE(cpm_pcie_noc_axi0_arsize),
      .IFPSNOCPCIAXI0ARUSER(cpm_pcie_noc_axi0_aruser),
      .IFPSNOCPCIAXI0ARVALID(cpm_pcie_noc_axi0_arvalid),
      .IFPSNOCPCIAXI0AWADDR(cpm_pcie_noc_axi0_awaddr),
      .IFPSNOCPCIAXI0AWBURST(cpm_pcie_noc_axi0_awburst),
      .IFPSNOCPCIAXI0AWCACHE(cpm_pcie_noc_axi0_awcache),
      .IFPSNOCPCIAXI0AWID(cpm_pcie_noc_axi0_awid),
      .IFPSNOCPCIAXI0AWLEN(cpm_pcie_noc_axi0_awlen),
      .IFPSNOCPCIAXI0AWLOCK(cpm_pcie_noc_axi0_awlock),
      .IFPSNOCPCIAXI0AWPROT(cpm_pcie_noc_axi0_awprot),
      .IFPSNOCPCIAXI0AWQOS(cpm_pcie_noc_axi0_awqos),
      .IFPSNOCPCIAXI0AWREGION(if_ps_noc_pci_axi0_awregion),
      .IFPSNOCPCIAXI0AWSIZE(cpm_pcie_noc_axi0_awsize),
      .IFPSNOCPCIAXI0AWUSER(cpm_pcie_noc_axi0_awuser),
      .IFPSNOCPCIAXI0AWVALID(cpm_pcie_noc_axi0_awvalid),
      .IFPSNOCPCIAXI0BREADY(cpm_pcie_noc_axi0_bready),
      .IFPSNOCPCIAXI0RREADY(cpm_pcie_noc_axi0_rready),
      .IFPSNOCPCIAXI0WDATA(cpm_pcie_noc_axi0_wdata),
      .IFPSNOCPCIAXI0WID(if_ps_noc_pci_axi0_wid),
      .IFPSNOCPCIAXI0WLAST(cpm_pcie_noc_axi0_wlast),
      .IFPSNOCPCIAXI0WSTRB(cpm_pcie_noc_axi0_wstrb),
      .IFPSNOCPCIAXI0WUSER(if_ps_noc_pci_axi0_wuser),
      .IFPSNOCPCIAXI0WVALID(cpm_pcie_noc_axi0_wvalid),
      .IFPSNOCPCIAXI1ARADDR(cpm_pcie_noc_axi1_araddr),
      .IFPSNOCPCIAXI1ARBURST(cpm_pcie_noc_axi1_arburst),
      .IFPSNOCPCIAXI1ARCACHE(cpm_pcie_noc_axi1_arcache),
      .IFPSNOCPCIAXI1ARID(cpm_pcie_noc_axi1_arid),
      .IFPSNOCPCIAXI1ARLEN(cpm_pcie_noc_axi1_arlen),
      .IFPSNOCPCIAXI1ARLOCK(cpm_pcie_noc_axi1_arlock),
      .IFPSNOCPCIAXI1ARPROT(cpm_pcie_noc_axi1_arprot),
      .IFPSNOCPCIAXI1ARQOS(cpm_pcie_noc_axi1_arqos),
      .IFPSNOCPCIAXI1ARREGION(if_ps_noc_pci_axi1_arregion),
      .IFPSNOCPCIAXI1ARSIZE(cpm_pcie_noc_axi1_arsize),
      .IFPSNOCPCIAXI1ARUSER(cpm_pcie_noc_axi1_aruser),
      .IFPSNOCPCIAXI1ARVALID(cpm_pcie_noc_axi1_arvalid),
      .IFPSNOCPCIAXI1AWADDR(cpm_pcie_noc_axi1_awaddr),
      .IFPSNOCPCIAXI1AWBURST(cpm_pcie_noc_axi1_awburst),
      .IFPSNOCPCIAXI1AWCACHE(cpm_pcie_noc_axi1_awcache),
      .IFPSNOCPCIAXI1AWID(cpm_pcie_noc_axi1_awid),
      .IFPSNOCPCIAXI1AWLEN(cpm_pcie_noc_axi1_awlen),
      .IFPSNOCPCIAXI1AWLOCK(cpm_pcie_noc_axi1_awlock),
      .IFPSNOCPCIAXI1AWPROT(cpm_pcie_noc_axi1_awprot),
      .IFPSNOCPCIAXI1AWQOS(cpm_pcie_noc_axi1_awqos),
      .IFPSNOCPCIAXI1AWREGION(if_ps_noc_pci_axi1_awregion),
      .IFPSNOCPCIAXI1AWSIZE(cpm_pcie_noc_axi1_awsize),
      .IFPSNOCPCIAXI1AWUSER(cpm_pcie_noc_axi1_awuser),
      .IFPSNOCPCIAXI1AWVALID(cpm_pcie_noc_axi1_awvalid),
      .IFPSNOCPCIAXI1BREADY(cpm_pcie_noc_axi1_bready),
      .IFPSNOCPCIAXI1RREADY(cpm_pcie_noc_axi1_rready),
      .IFPSNOCPCIAXI1WDATA(cpm_pcie_noc_axi1_wdata),
      .IFPSNOCPCIAXI1WID(if_ps_noc_pci_axi1_wid),
      .IFPSNOCPCIAXI1WLAST(cpm_pcie_noc_axi1_wlast),
      .IFPSNOCPCIAXI1WSTRB(cpm_pcie_noc_axi1_wstrb),
      .IFPSNOCPCIAXI1WUSER(if_ps_noc_pci_axi1_wuser),
      .IFPSNOCPCIAXI1WVALID(cpm_pcie_noc_axi1_wvalid),
      .IFPSNOCRPUAXI0ARADDR(lpd_axi_noc_axi0_araddr),
      .IFPSNOCRPUAXI0ARBURST(lpd_axi_noc_axi0_arburst),
      .IFPSNOCRPUAXI0ARCACHE(lpd_axi_noc_axi0_arcache),
      .IFPSNOCRPUAXI0ARID(lpd_axi_noc_axi0_arid),
      .IFPSNOCRPUAXI0ARLEN(lpd_axi_noc_axi0_arlen),
      .IFPSNOCRPUAXI0ARLOCK(lpd_axi_noc_axi0_arlock),
      .IFPSNOCRPUAXI0ARPROT(lpd_axi_noc_axi0_arprot),
      .IFPSNOCRPUAXI0ARQOS(lpd_axi_noc_axi0_arqos),
      .IFPSNOCRPUAXI0ARREGION(if_ps_noc_rpu_axi0_arregion),
      .IFPSNOCRPUAXI0ARSIZE(lpd_axi_noc_axi0_arsize),
      .IFPSNOCRPUAXI0ARUSER(lpd_axi_noc_axi0_aruser),
      .IFPSNOCRPUAXI0ARVALID(lpd_axi_noc_axi0_arvalid),
      .IFPSNOCRPUAXI0AWADDR(lpd_axi_noc_axi0_awaddr),
      .IFPSNOCRPUAXI0AWBURST(lpd_axi_noc_axi0_awburst),
      .IFPSNOCRPUAXI0AWCACHE(lpd_axi_noc_axi0_awcache),
      .IFPSNOCRPUAXI0AWID(lpd_axi_noc_axi0_awid),
      .IFPSNOCRPUAXI0AWLEN(lpd_axi_noc_axi0_awlen),
      .IFPSNOCRPUAXI0AWLOCK(lpd_axi_noc_axi0_awlock),
      .IFPSNOCRPUAXI0AWPROT(lpd_axi_noc_axi0_awprot),
      .IFPSNOCRPUAXI0AWQOS(lpd_axi_noc_axi0_awqos),
      .IFPSNOCRPUAXI0AWREGION(if_ps_noc_rpu_axi0_awregion),
      .IFPSNOCRPUAXI0AWSIZE(lpd_axi_noc_axi0_awsize),
      .IFPSNOCRPUAXI0AWUSER(lpd_axi_noc_axi0_awuser),
      .IFPSNOCRPUAXI0AWVALID(lpd_axi_noc_axi0_awvalid),
      .IFPSNOCRPUAXI0BREADY(lpd_axi_noc_axi0_bready),
      .IFPSNOCRPUAXI0RREADY(lpd_axi_noc_axi0_rready),
      .IFPSNOCRPUAXI0WDATA(lpd_axi_noc_axi0_wdata),
      .IFPSNOCRPUAXI0WID(if_ps_noc_rpu_axi0_wid),
      .IFPSNOCRPUAXI0WLAST(lpd_axi_noc_axi0_wlast),
      .IFPSNOCRPUAXI0WSTRB(lpd_axi_noc_axi0_wstrb),
      .IFPSNOCRPUAXI0WUSER(if_ps_noc_rpu_axi0_wuser),
      .IFPSNOCRPUAXI0WVALID(lpd_axi_noc_axi0_wvalid),
      .MAXIGP0ARADDR(m_axi_fpd_araddr),
      .MAXIGP0ARBURST(m_axi_fpd_arburst),
      .MAXIGP0ARCACHE(m_axi_fpd_arcache),
      .MAXIGP0ARID(m_axi_fpd_arid),
      .MAXIGP0ARLEN(m_axi_fpd_arlen),
      .MAXIGP0ARLOCK(m_axi_fpd_arlock),
      .MAXIGP0ARPROT(m_axi_fpd_arprot),
      .MAXIGP0ARQOS(m_axi_fpd_arqos),
      .MAXIGP0ARSIZE(m_axi_fpd_arsize),
      .MAXIGP0ARUSER(m_axi_fpd_aruser),
      .MAXIGP0ARVALID(m_axi_fpd_arvalid),
      .MAXIGP0AWADDR(m_axi_fpd_awaddr),
      .MAXIGP0AWBURST(m_axi_fpd_awburst),
      .MAXIGP0AWCACHE(m_axi_fpd_awcache),
      .MAXIGP0AWID(m_axi_fpd_awid),
      .MAXIGP0AWLEN(m_axi_fpd_awlen),
      .MAXIGP0AWLOCK(m_axi_fpd_awlock),
      .MAXIGP0AWPROT(m_axi_fpd_awprot),
      .MAXIGP0AWQOS(m_axi_fpd_awqos),
      .MAXIGP0AWSIZE(m_axi_fpd_awsize),
      .MAXIGP0AWUSER(m_axi_fpd_awuser),
      .MAXIGP0AWVALID(m_axi_fpd_awvalid),
      .MAXIGP0BREADY(m_axi_fpd_bready),
      .MAXIGP0RREADY(m_axi_fpd_rready),
      .MAXIGP0WDATA(m_axi_fpd_wdata),
      .MAXIGP0WLAST(m_axi_fpd_wlast),
      .MAXIGP0WSTRB(m_axi_fpd_wstrb),
      .MAXIGP0WVALID(m_axi_fpd_wvalid),
      .MAXIGP2ARADDR(m_axi_lpd_araddr),
      .MAXIGP2ARBURST(m_axi_lpd_arburst),
      .MAXIGP2ARCACHE(m_axi_lpd_arcache),
      .MAXIGP2ARID(m_axi_lpd_arid),
      .MAXIGP2ARLEN(m_axi_lpd_arlen),
      .MAXIGP2ARLOCK(m_axi_lpd_arlock),
      .MAXIGP2ARPROT(m_axi_lpd_arprot),
      .MAXIGP2ARQOS(m_axi_lpd_arqos),
      .MAXIGP2ARSIZE(m_axi_lpd_arsize),
      .MAXIGP2ARUSER(m_axi_lpd_aruser),
      .MAXIGP2ARVALID(m_axi_lpd_arvalid),
      .MAXIGP2AWADDR(m_axi_lpd_awaddr),
      .MAXIGP2AWBURST(m_axi_lpd_awburst),
      .MAXIGP2AWCACHE(m_axi_lpd_awcache),
      .MAXIGP2AWID(m_axi_lpd_awid),
      .MAXIGP2AWLEN(m_axi_lpd_awlen),
      .MAXIGP2AWLOCK(m_axi_lpd_awlock),
      .MAXIGP2AWPROT(m_axi_lpd_awprot),
      .MAXIGP2AWQOS(m_axi_lpd_awqos),
      .MAXIGP2AWSIZE(m_axi_lpd_awsize),
      .MAXIGP2AWUSER(m_axi_lpd_awuser),
      .MAXIGP2AWVALID(m_axi_lpd_awvalid),
      .MAXIGP2BREADY(m_axi_lpd_bready),
      .MAXIGP2RREADY(m_axi_lpd_rready),
      .MAXIGP2WDATA(m_axi_lpd_wdata),
      .MAXIGP2WLAST(m_axi_lpd_wlast),
      .MAXIGP2WSTRB(m_axi_lpd_wstrb),
      .MAXIGP2WVALID(m_axi_lpd_wvalid),
//      .MJTAGTDO(mjtag_tdo),
//      .MJTAGTCK(mjtag_tck),
//      .MJTAGTDI(mjtag_tdi),
//      .MJTAGTMS(mjtag_tms),
    //.NOCCLK(noc_clk),
    //.NOCRSTN(noc_rstn),
    //.NPICLK(npi_clk),
    //.NPIRSTN(npi_rstn),
      .OSCRTCCLK(rtc_clk),
      .PMCRCLKCLK(pmc_pl_ref_clk),
    //.PMCPLREFCLK(pmc_pl_ref_clk),

      .CFUEOS(eos),
      .CFUUSRGSRB(usrgsrb_temp),
      .CFUUSRGTSB(usrgtsb_temp),
      .CFUGCAPB(captureb_temp),
      .GCAPCLK(captureclk_temp) ,

      .PMUAIBAFIFMFPDREQ(pmu_aib_afi_fm_fpd_req),
      .PMUAIBAFIFMLPDREQ(pmu_aib_afi_fm_lpd_req),
      .PMUERRORTOPL(pmu_error_to_pl),
      .PSNOCPSCCIAXI0CLK(noc_fpd_cci_axi0_clk),
      .PSNOCPSCCIAXI1CLK(noc_fpd_cci_axi1_clk),
      .PSNOCPSNCIAXI0CLK(noc_fpd_axi_axi0_clk),
      .PSNOCPSNCIAXI1CLK(noc_fpd_axi_axi1_clk),
      .PSNOCPSPCIAXI0CLK(noc_cpm_pcie_axi0_clk),

      .PLPSATBCLK(atb_clk),
      .PLPSATBYTES(atbtbytes),
      .PLPSATDATA(pl_ps_atdata),
      .PLPSATID(pl_ps_atid),
      .PLPSATVALID(pl_ps_atvalid),
      .PSPLATREADY(pspl_atready),

      .PSPLEVENTO(apu_event_o),
      .PSPLIRQFPD(ps_pl_irq_fpd),
      .PSPLIRQLPD(ps_pl_irq_lpd),
      .PSPLIRQPMC(ps_pl_irq_pmc),
      .PSPLSTANDBYWFE(apu_event_standby_wfe),
      .PSPLSTANDBYWFI(apu_event_standby_wfi),
      .PSPLTRACECTL(ps_pl_trace_ctl_i),
      .PSPLTRACEDATA(ps_pl_trace_data_i),
      .PSPLTRIGACK ({pl_ps_trig3_ack, pl_ps_trig2_ack, pl_ps_trig1_ack, pl_ps_trig0_ack}),
      .PSPLTRIGGER ({ps_pl_trig3_req, ps_pl_trig2_req, ps_pl_trig1_req, ps_pl_trig0_req}),
      .PSPSNOCCCIAXI0CLK(fpd_cci_noc_axi0_clk),
      .PSPSNOCCCIAXI1CLK(fpd_cci_noc_axi1_clk),
      .PSPSNOCCCIAXI2CLK(fpd_cci_noc_axi2_clk),
      .PSPSNOCCCIAXI3CLK(fpd_cci_noc_axi3_clk),
      .PSPSNOCNCIAXI0CLK(fpd_axi_noc_axi0_clk),
      .PSPSNOCNCIAXI1CLK(fpd_axi_noc_axi1_clk),
      .PSPSNOCPCIAXI0CLK(cpm_pcie_noc_axi0_clk),
      .PSPSNOCPCIAXI1CLK(cpm_pcie_noc_axi1_clk),
      .PSPSNOCRPUAXI0CLK(lpd_axi_noc_clk),
      .RPUEVENTO0(lpd_rpu_event_o0),
      .RPUEVENTO1(lpd_rpu_event_o1),
      .SACEFPDACADDR(s_ace_fpd_acaddr),
      .SACEFPDACPROT(s_ace_fpd_acprot),
      .SACEFPDACSNOOP(s_ace_fpd_acsnoop),
      .SACEFPDACVALID(s_ace_fpd_acvalid),
      .SACEFPDARREADY(s_ace_fpd_arready),
      .SACEFPDAWREADY(s_ace_fpd_awready),
      .SACEFPDBID(s_ace_fpd_bid),
      .SACEFPDBRESP(s_ace_fpd_bresp),
      .SACEFPDBUSER(s_ace_fpd_buser),
      .SACEFPDBVALID(s_ace_fpd_bvalid),
      .SACEFPDCDREADY(s_ace_fpd_cdready),
      .SACEFPDCRREADY(s_ace_fpd_crready),
      .SACEFPDRDATA(s_ace_fpd_rdata),
      .SACEFPDRID(s_ace_fpd_rid),
      .SACEFPDRLAST(s_ace_fpd_rlast),
      .SACEFPDRRESP(s_ace_fpd_rresp),
      .SACEFPDRUSER(s_ace_fpd_ruser),
      .SACEFPDRVALID(s_ace_fpd_rvalid),
      .SACEFPDWREADY(s_ace_fpd_wready),
      .SAXIACPARREADY(s_acp_fpd_arready),
      .SAXIACPAWREADY(s_acp_fpd_awready),
      .SAXIACPBID(s_acp_fpd_bid),
      .SAXIACPBRESP(s_acp_fpd_bresp),
      .SAXIACPBVALID(s_acp_fpd_bvalid),
      .SAXIACPRDATA(s_acp_fpd_rdata),
      .SAXIACPRID(s_acp_fpd_rid),
      .SAXIACPRLAST(s_acp_fpd_rlast),
      .SAXIACPRRESP(s_acp_fpd_rresp),
      .SAXIACPRVALID(s_acp_fpd_rvalid),
      .SAXIACPWREADY(s_acp_fpd_wready),
      .SAXIGP0ARREADY(s_axi_fpd_arready),
      .SAXIGP0AWREADY(s_axi_fpd_awready),
      .SAXIGP0BID(s_axi_fpd_bid),
      .SAXIGP0BRESP(s_axi_fpd_bresp),
      .SAXIGP0BVALID(s_axi_fpd_bvalid),
      .SAXIGP0RACOUNT(s_axi_fpd_racount),
      .SAXIGP0RCOUNT(s_axi_fpd_rcount),
      .SAXIGP0RDATA(s_axi_fpd_rdata),
      .SAXIGP0RID(s_axi_fpd_rid),
      .SAXIGP0RLAST(s_axi_fpd_rlast),
      .SAXIGP0RRESP(s_axi_fpd_rresp),
      .SAXIGP0RVALID(s_axi_fpd_rvalid),
      .SAXIGP0WACOUNT(s_axi_fpd_wacount),
      .SAXIGP0WCOUNT(s_axi_fpd_wcount),
      .SAXIGP0WREADY(s_axi_fpd_wready),
      .SAXIGP2ARREADY(s_axi_gp2_arready_t),
      .SAXIGP2AWREADY(s_axi_gp2_awready_t),
      .SAXIGP2BID(s_axi_gp2_bid_t),
      .SAXIGP2BRESP(s_axi_gp2_bresp_t),
      .SAXIGP2BVALID(s_axi_gp2_bvalid_t),
      .SAXIGP2RACOUNT(s_axi_gp2_racount_t),
      .SAXIGP2RCOUNT(s_axi_gp2_rcount_t),
      .SAXIGP2RDATA(s_axi_gp2_rdata_t),
      .SAXIGP2RID(s_axi_gp2_rid_t),
      .SAXIGP2RLAST(s_axi_gp2_rlast_t),
      .SAXIGP2RRESP(s_axi_gp2_rresp_t),
      .SAXIGP2RVALID(s_axi_gp2_rvalid_t),
      .SAXIGP2WACOUNT(s_axi_gp2_wacount_t),
      .SAXIGP2WCOUNT(s_axi_gp2_wcount_t),
      .SAXIGP2WREADY(s_axi_gp2_wready_t),
      .SAXIGP4ARREADY(s_axi_lpd_arready),
      .SAXIGP4AWREADY(s_axi_lpd_awready),
      .SAXIGP4BID(s_axi_lpd_bid),
      .SAXIGP4BRESP(s_axi_lpd_bresp),
      .SAXIGP4BVALID(s_axi_lpd_bvalid),
      .SAXIGP4RACOUNT(s_axi_lpd_racount),
      .SAXIGP4RCOUNT(s_axi_lpd_rcount),
      .SAXIGP4RDATA(s_axi_lpd_rdata),
      .SAXIGP4RID(s_axi_lpd_rid),
      .SAXIGP4RLAST(s_axi_lpd_rlast),
      .SAXIGP4RRESP(s_axi_lpd_rresp),
      .SAXIGP4RVALID(s_axi_lpd_rvalid),
      .SAXIGP4WACOUNT(s_axi_lpd_wacount),
      .SAXIGP4WCOUNT(s_axi_lpd_wcount),
      .SAXIGP4WREADY(s_axi_lpd_wready),
      .PSS_PAD_LPDMIO(pss_pad_lpdmio),
      .ADMAFCICLK(adma_fci_clk_i),
      .AIBPMUAFIFMFPDACK(aib_pmu_afi_fm_fpd_ack),
      .AIBPMUAFIFMLPDACK(aib_pmu_afi_fm_lpd_ack),
      .EMIOCAN0PHYRX(canfd0_phy_rx),
      .EMIOCAN1PHYRX(canfd1_phy_rx),
      .EMIOENET0DMATXSTATUSTOG(gem0_fifo_dma_tx_status_tog),
      .EMIOENET0EXTINTIN(gem0_ext_int_in),
      .EMIOENET0GMIICOL(gem0_gmii_col),
      .EMIOENET0GMIICRS(gem0_gmii_crs),
      .EMIOENET0GMIIRXCLK(gem0_gmii_rx_clk),
      .EMIOENET0GMIIRXD(gem0_gmii_rx_d),
      .EMIOENET0GMIIRXDV(gem0_gmii_rx_dv),
      .EMIOENET0GMIIRXER(gem0_gmii_rx_err),
      .EMIOENET0GMIITXCLK(gem0_gmii_tx_clk),
      .EMIOENET0MDIOI(gem0_mdio_i),
      .EMIOENET0RXWOVERFLOW(gem0_fifo_rx_w_overflow),
      .EMIOENET0TXRCONTROL(gem0_fifo_tx_r_control),
      .EMIOENET0TXRDATA(gem0_fifo_tx_r_data),
      .EMIOENET0TXRDATARDY(gem0_fifo_tx_r_data_rdy),
      .EMIOENET0TXREOP(gem0_fifo_tx_r_eop),
      .EMIOENET0TXRERR(gem0_fifo_tx_r_err),
      .EMIOENET0TXRFLUSHED(gem0_fifo_tx_r_flushed),
      .EMIOENET0TXRSOP(gem0_fifo_tx_r_sop),
      .EMIOENET0TXRUNDERFLOW(gem0_fifo_tx_r_underflow),
      .EMIOENET0TXRVALID(gem0_fifo_tx_r_valid),
      .EMIOENET1DMATXSTATUSTOG(gem1_fifo_dma_tx_status_tog),
      .EMIOENET1EXTINTIN(emio_enet1_ext_int_in),
      .EMIOENET1GMIICOL(gem1_gmii_col),
      .EMIOENET1GMIICRS(gem1_gmii_crs),
      .EMIOENET1GMIIRXCLK(gem1_gmii_rx_clk),
      .EMIOENET1GMIIRXD(gem1_gmii_rx_d),
      .EMIOENET1GMIIRXDV(gem1_gmii_rx_dv),
      .EMIOENET1GMIIRXER(gem1_gmii_rx_err),
      .EMIOENET1GMIITXCLK(gem1_gmii_tx_clk),
      .EMIOENET1MDIOI(gem1_mdio_i),
      .EMIOENET1RXWOVERFLOW(gem1_fifo_rx_w_overflow),
      .EMIOENET1TXRCONTROL(gem1_fifo_tx_r_control),
      .EMIOENET1TXRDATA(gem1_fifo_tx_r_data),
      .EMIOENET1TXRDATARDY(gem1_fifo_tx_r_data_rdy),
      .EMIOENET1TXREOP(gem1_fifo_tx_r_eop),
      .EMIOENET1TXRERR(gem1_fifo_tx_r_err),
      .EMIOENET1TXRFLUSHED(gem1_fifo_tx_r_flushed),
      .EMIOENET1TXRSOP(gem1_fifo_tx_r_sop),
      .EMIOENET1TXRUNDERFLOW(gem1_fifo_tx_r_underflow),
      .EMIOENET1TXRVALID(gem1_fifo_tx_r_valid),
      .EMIOENETTSUCLK(emio_enet_tsu_clk),
      .EMIOGEM0TSUINCCTRL(gem0_tsu_inc_ctrl_wire),
      .EMIOGEM1TSUINCCTRL(gem1_tsu_inc_ctrl),
      .EMIOHUBPORTOVERCRNTUSB20(emio_hub_port_overcrnt_usb2_0),
    //.EMIOHUBPORTOVERCRNTUSB21(emio_hub_port_overcrnt_usb2_1),
    //.EMIOHUBPORTOVERCRNTUSB30(emio_hub_port_overcrnt_usb3_0),
    //.EMIOHUBPORTOVERCRNTUSB31(emio_hub_port_overcrnt_usb3_1),
      .EMIOI2C0SCLI(i2c0_scl_i),
      .EMIOI2C0SDAI(i2c0_sda_i),
      .EMIOI2C1SCLI(i2c1_scl_i),
      .EMIOI2C1SDAI(i2c1_sda_i),
      .EMIOSPI0MI(spi0_m_i),
      .EMIOSPI0SCLKI(spi0_sclk_i),
      .EMIOSPI0SI(spi0_s_i),
      .EMIOSPI0SSIN(spi0_ss_i_n),
      .EMIOSPI1MI(spi1_m_i),
      .EMIOSPI1SCLKI(spi1_sclk_i),
      .EMIOSPI1SI(spi1_s_i),
      .EMIOSPI1SSIN(spi1_ss_i_n),
      .EMIOTTC0CLKI(ttc0_clk),
      .EMIOTTC1CLKI(ttc1_clk),
      .EMIOTTC2CLKI(ttc2_clk),
      .EMIOTTC3CLKI(ttc3_clk),
    //.EMIOUART0CTSN(emio_uart0_ctsn),
    //.EMIOUART0DCDN(emio_uart0_dcdn),
    //.EMIOUART0DSRN(emio_uart0_dsrn),
    //.EMIOUART0RIN(emio_uart0_rin),
    //.EMIOUART0RX(emio_uart0_rx),
    //.EMIOUART1CTSN(emio_uart1_ctsn),
    //.EMIOUART1DCDN(emio_uart1_dcdn),
    //.EMIOUART1DSRN(emio_uart1_dsrn),
    //.EMIOUART1RIN(emio_uart1_rin),
    //.EMIOUART1RX(emio_uart1_rx),
    //.EMIOUART2CTSN(emio_uart2_ctsn),
    //.EMIOUART2DCDN(emio_uart2_dcdn),
    //.EMIOUART2DSRN(emio_uart2_dsrn),
    //.EMIOUART2RIN(emio_uart2_rin),
    //.EMIOUART2RX(emio_uart2_rx),
    //.EMIOWDT0CLKI(emio_wdt0_clk_i),
    //.EMIOWDT1CLKI(emio_wdt1_clk_i),
      .FMIOGEM0FIFORXCLKFROMPL(fmio_gem0_fifo_rx_clk_from_pl),
      .FMIOGEM0FIFOTXCLKFROMPL(fmio_gem0_fifo_tx_clk_from_pl),
    //.FMIOGEM0SIGNALDETECT(fmiogem0signaldetect),

      .FMIOGEM1FIFORXCLKFROMPL(fmio_gem1_fifo_rx_clk_from_pl),
      .FMIOGEM1FIFOTXCLKFROMPL(fmio_gem1_fifo_tx_clk_from_pl),

    //.FMIOGEM1SIGNALDETECT(fmiogem1signaldetect),
      .FMIOGEMTSUCLKFROMPL(fmio_gem_tsu_clk_from_pl),
    //.FMIOGPIOIN(fmio_gpio_in),
    //.FMIOI2CSCLIN(fmioi2csclin),
    //.FMIOI2CSDAIN(fmioi2csdain),
    //.FMIOSD0DLLTESTIN(sd0_dll_test_in),
    //.FMIOSD0SDIFCDNIN(sd0_cd_n),
    //.FMIOSD0SDIFCMDIN(sd0_cmd_in),
    //.FMIOSD0SDIFDATIN(sd0_data_in),
    //.FMIOSD0SDIFWPIN(sd0_wp),
    //.FMIOSD1DLLTESTIN(sd1_dll_test_in),
    //.FMIOSD1SDIFCDNIN(sd1_cd_n),
    //.FMIOSD1SDIFCMDIN(sd1_cmd_in),
    //.FMIOSD1SDIFDATIN(sd1_data_in),
    //.FMIOSD1SDIFWPIN(sd1_wp),
      .FMIOSDIO0RXCLKIN(sd0_rx_clk),
      .FMIOSDIO1RXCLKIN(sd1_rx_clk),
//      .FTMGPI(ftm_gpi),
      .IFNOCPSCCIAXI0ARADDR(noc_fpd_cci_axi0_araddr),
      .IFNOCPSCCIAXI0ARBURST(noc_fpd_cci_axi0_arburst),
      .IFNOCPSCCIAXI0ARCACHE(noc_fpd_cci_axi0_arcache),
      .IFNOCPSCCIAXI0ARID(noc_fpd_cci_axi0_arid),
      .IFNOCPSCCIAXI0ARLEN(noc_fpd_cci_axi0_arlen),
      .IFNOCPSCCIAXI0ARLOCK(noc_fpd_cci_axi0_arlock),
      .IFNOCPSCCIAXI0ARPROT(noc_fpd_cci_axi0_arprot),
      .IFNOCPSCCIAXI0ARQOS(noc_fpd_cci_axi0_arqos),
      .IFNOCPSCCIAXI0ARREGION(noc_fpd_cci_axi0_arregion),
      .IFNOCPSCCIAXI0ARSIZE(noc_fpd_cci_axi0_arsize),
      .IFNOCPSCCIAXI0ARUSER(noc_fpd_cci_axi0_aruser),
      .IFNOCPSCCIAXI0ARVALID(noc_fpd_cci_axi0_arvalid),
      .IFNOCPSCCIAXI0AWADDR(noc_fpd_cci_axi0_awaddr),
      .IFNOCPSCCIAXI0AWBURST(noc_fpd_cci_axi0_awburst),
      .IFNOCPSCCIAXI0AWCACHE(noc_fpd_cci_axi0_awcache),
      .IFNOCPSCCIAXI0AWID(noc_fpd_cci_axi0_awid),
      .IFNOCPSCCIAXI0AWLEN(noc_fpd_cci_axi0_awlen),
      .IFNOCPSCCIAXI0AWLOCK(noc_fpd_cci_axi0_awlock),
      .IFNOCPSCCIAXI0AWPROT(noc_fpd_cci_axi0_awprot),
      .IFNOCPSCCIAXI0AWQOS(noc_fpd_cci_axi0_awqos),
      .IFNOCPSCCIAXI0AWREGION(noc_fpd_cci_axi0_awregion),
      .IFNOCPSCCIAXI0AWSIZE(noc_fpd_cci_axi0_awsize),
      .IFNOCPSCCIAXI0AWUSER(noc_fpd_cci_axi0_awuser),
      .IFNOCPSCCIAXI0AWVALID(noc_fpd_cci_axi0_awvalid),
      .IFNOCPSCCIAXI0BREADY(noc_fpd_cci_axi0_bready),
      .IFNOCPSCCIAXI0RREADY(noc_fpd_cci_axi0_rready),
      .IFNOCPSCCIAXI0WDATA(noc_fpd_cci_axi0_wdata),
      .IFNOCPSCCIAXI0WID(noc_fpd_cci_axi0_wid),
      .IFNOCPSCCIAXI0WLAST(noc_fpd_cci_axi0_wlast),
      .IFNOCPSCCIAXI0WSTRB(noc_fpd_cci_axi0_wstrb),
      .IFNOCPSCCIAXI0WUSER(noc_fpd_cci_axi0_wuser),
      .IFNOCPSCCIAXI0WVALID(noc_fpd_cci_axi0_wvalid),
      .IFNOCPSCCIAXI1ARADDR(noc_fpd_cci_axi1_araddr),
      .IFNOCPSCCIAXI1ARBURST(noc_fpd_cci_axi1_arburst),
      .IFNOCPSCCIAXI1ARCACHE(noc_fpd_cci_axi1_arcache),
      .IFNOCPSCCIAXI1ARID(noc_fpd_cci_axi1_arid),
      .IFNOCPSCCIAXI1ARLEN(noc_fpd_cci_axi1_arlen),
      .IFNOCPSCCIAXI1ARLOCK(noc_fpd_cci_axi1_arlock),
      .IFNOCPSCCIAXI1ARPROT(noc_fpd_cci_axi1_arprot),
      .IFNOCPSCCIAXI1ARQOS(noc_fpd_cci_axi1_arqos),
      .IFNOCPSCCIAXI1ARREGION(noc_fpd_cci_axi1_arregion),
      .IFNOCPSCCIAXI1ARSIZE(noc_fpd_cci_axi1_arsize),
      .IFNOCPSCCIAXI1ARUSER(noc_fpd_cci_axi1_aruser),
      .IFNOCPSCCIAXI1ARVALID(noc_fpd_cci_axi1_arvalid),
      .IFNOCPSCCIAXI1AWADDR(noc_fpd_cci_axi1_awaddr),
      .IFNOCPSCCIAXI1AWBURST(noc_fpd_cci_axi1_awburst),
      .IFNOCPSCCIAXI1AWCACHE(noc_fpd_cci_axi1_awcache),
      .IFNOCPSCCIAXI1AWID(noc_fpd_cci_axi1_awid),
      .IFNOCPSCCIAXI1AWLEN(noc_fpd_cci_axi1_awlen),
      .IFNOCPSCCIAXI1AWLOCK(noc_fpd_cci_axi1_awlock),
      .IFNOCPSCCIAXI1AWPROT(noc_fpd_cci_axi1_awprot),
      .IFNOCPSCCIAXI1AWQOS(noc_fpd_cci_axi1_awqos),
      .IFNOCPSCCIAXI1AWREGION(noc_fpd_cci_axi1_awregion),
      .IFNOCPSCCIAXI1AWSIZE(noc_fpd_cci_axi1_awsize),
      .IFNOCPSCCIAXI1AWUSER(noc_fpd_cci_axi1_awuser),
      .IFNOCPSCCIAXI1AWVALID(noc_fpd_cci_axi1_awvalid),
      .IFNOCPSCCIAXI1BREADY(noc_fpd_cci_axi1_bready),
      .IFNOCPSCCIAXI1RREADY(noc_fpd_cci_axi1_rready),
      .IFNOCPSCCIAXI1WDATA(noc_fpd_cci_axi1_wdata),
      .IFNOCPSCCIAXI1WID(noc_fpd_cci_axi1_wid),
      .IFNOCPSCCIAXI1WLAST(noc_fpd_cci_axi1_wlast),
      .IFNOCPSCCIAXI1WSTRB(noc_fpd_cci_axi1_wstrb),
      .IFNOCPSCCIAXI1WUSER(noc_fpd_cci_axi1_wuser),
      .IFNOCPSCCIAXI1WVALID(noc_fpd_cci_axi1_wvalid),
      .IFNOCPSNCIAXI0ARADDR(noc_fpd_axi_axi0_araddr),
      .IFNOCPSNCIAXI0ARBURST(noc_fpd_axi_axi0_arburst),
      .IFNOCPSNCIAXI0ARCACHE(noc_fpd_axi_axi0_arcache),
      .IFNOCPSNCIAXI0ARID(noc_fpd_axi_axi0_arid),
      .IFNOCPSNCIAXI0ARLEN(noc_fpd_axi_axi0_arlen),
      .IFNOCPSNCIAXI0ARLOCK(noc_fpd_axi_axi0_arlock),
      .IFNOCPSNCIAXI0ARPROT(noc_fpd_axi_axi0_arprot),
      .IFNOCPSNCIAXI0ARQOS(noc_fpd_axi_axi0_arqos),
      .IFNOCPSNCIAXI0ARREGION(noc_fpd_axi_axi0_arregion),
      .IFNOCPSNCIAXI0ARSIZE(noc_fpd_axi_axi0_arsize),
      .IFNOCPSNCIAXI0ARUSER(noc_fpd_axi_axi0_aruser),
      .IFNOCPSNCIAXI0ARVALID(noc_fpd_axi_axi0_arvalid),
      .IFNOCPSNCIAXI0AWADDR(noc_fpd_axi_axi0_awaddr),
      .IFNOCPSNCIAXI0AWBURST(noc_fpd_axi_axi0_awburst),
      .IFNOCPSNCIAXI0AWCACHE(noc_fpd_axi_axi0_awcache),
      .IFNOCPSNCIAXI0AWID(noc_fpd_axi_axi0_awid),
      .IFNOCPSNCIAXI0AWLEN(noc_fpd_axi_axi0_awlen),
      .IFNOCPSNCIAXI0AWLOCK(noc_fpd_axi_axi0_awlock),
      .IFNOCPSNCIAXI0AWPROT(noc_fpd_axi_axi0_awprot),
      .IFNOCPSNCIAXI0AWQOS(noc_fpd_axi_axi0_awqos),
      .IFNOCPSNCIAXI0AWREGION(noc_fpd_axi_axi0_awregion),
      .IFNOCPSNCIAXI0AWSIZE(noc_fpd_axi_axi0_awsize),
      .IFNOCPSNCIAXI0AWUSER(noc_fpd_axi_axi0_awuser),
      .IFNOCPSNCIAXI0AWVALID(noc_fpd_axi_axi0_awvalid),
      .IFNOCPSNCIAXI0BREADY(noc_fpd_axi_axi0_bready),
      .IFNOCPSNCIAXI0RREADY(noc_fpd_axi_axi0_rready),
      .IFNOCPSNCIAXI0WDATA(noc_fpd_axi_axi0_wdata),
      .IFNOCPSNCIAXI0WID(noc_fpd_axi_axi0_wid),
      .IFNOCPSNCIAXI0WLAST(noc_fpd_axi_axi0_wlast),
      .IFNOCPSNCIAXI0WSTRB(noc_fpd_axi_axi0_wstrb),
      .IFNOCPSNCIAXI0WUSER(noc_fpd_axi_axi0_wuser),
      .IFNOCPSNCIAXI0WVALID(noc_fpd_axi_axi0_wvalid),
      .IFNOCPSNCIAXI1ARADDR(noc_fpd_axi_axi1_araddr),
      .IFNOCPSNCIAXI1ARBURST(noc_fpd_axi_axi1_arburst),
      .IFNOCPSNCIAXI1ARCACHE(noc_fpd_axi_axi1_arcache),
      .IFNOCPSNCIAXI1ARID(noc_fpd_axi_axi1_arid),
      .IFNOCPSNCIAXI1ARLEN(noc_fpd_axi_axi1_arlen),
      .IFNOCPSNCIAXI1ARLOCK(noc_fpd_axi_axi1_arlock),
      .IFNOCPSNCIAXI1ARPROT(noc_fpd_axi_axi1_arprot),
      .IFNOCPSNCIAXI1ARQOS(noc_fpd_axi_axi1_arqos),
      .IFNOCPSNCIAXI1ARREGION(noc_fpd_axi_axi1_arregion),
      .IFNOCPSNCIAXI1ARSIZE(noc_fpd_axi_axi1_arsize),
      .IFNOCPSNCIAXI1ARUSER(noc_fpd_axi_axi1_aruser),
      .IFNOCPSNCIAXI1ARVALID(noc_fpd_axi_axi1_arvalid),
      .IFNOCPSNCIAXI1AWADDR(noc_fpd_axi_axi1_awaddr),
      .IFNOCPSNCIAXI1AWBURST(noc_fpd_axi_axi1_awburst),
      .IFNOCPSNCIAXI1AWCACHE(noc_fpd_axi_axi1_awcache),
      .IFNOCPSNCIAXI1AWID(noc_fpd_axi_axi1_awid),
      .IFNOCPSNCIAXI1AWLEN(noc_fpd_axi_axi1_awlen),
      .IFNOCPSNCIAXI1AWLOCK(noc_fpd_axi_axi1_awlock),
      .IFNOCPSNCIAXI1AWPROT(noc_fpd_axi_axi1_awprot),
      .IFNOCPSNCIAXI1AWQOS(noc_fpd_axi_axi1_awqos),
      .IFNOCPSNCIAXI1AWREGION(noc_fpd_axi_axi1_awregion),
      .IFNOCPSNCIAXI1AWSIZE(noc_fpd_axi_axi1_awsize),
      .IFNOCPSNCIAXI1AWUSER(noc_fpd_axi_axi1_awuser),
      .IFNOCPSNCIAXI1AWVALID(noc_fpd_axi_axi1_awvalid),
      .IFNOCPSNCIAXI1BREADY(noc_fpd_axi_axi1_bready),
      .IFNOCPSNCIAXI1RREADY(noc_fpd_axi_axi1_rready),
      .IFNOCPSNCIAXI1WDATA(noc_fpd_axi_axi1_wdata),
      .IFNOCPSNCIAXI1WID(noc_fpd_axi_axi1_wid),
      .IFNOCPSNCIAXI1WLAST(noc_fpd_axi_axi1_wlast),
      .IFNOCPSNCIAXI1WSTRB(noc_fpd_axi_axi1_wstrb),
      .IFNOCPSNCIAXI1WUSER(noc_fpd_axi_axi1_wuser),
      .IFNOCPSNCIAXI1WVALID(noc_fpd_axi_axi1_wvalid),
      .IFNOCPSPCIAXI0ARADDR(noc_cpm_pcie_axi0_araddr),
      .IFNOCPSPCIAXI0ARBURST(noc_cpm_pcie_axi0_arburst),
      .IFNOCPSPCIAXI0ARCACHE(noc_cpm_pcie_axi0_arcache),
      .IFNOCPSPCIAXI0ARID(noc_cpm_pcie_axi0_arid),
      .IFNOCPSPCIAXI0ARLEN(noc_cpm_pcie_axi0_arlen),
      .IFNOCPSPCIAXI0ARLOCK(noc_cpm_pcie_axi0_arlock),
      .IFNOCPSPCIAXI0ARPROT(noc_cpm_pcie_axi0_arprot),
      .IFNOCPSPCIAXI0ARQOS(noc_cpm_pcie_axi0_arqos),
      .IFNOCPSPCIAXI0ARREGION(noc_cpm_pcie_axi0_arregion),
      .IFNOCPSPCIAXI0ARSIZE(noc_cpm_pcie_axi0_arsize),
      .IFNOCPSPCIAXI0ARUSER(noc_cpm_pcie_axi0_aruser),
      .IFNOCPSPCIAXI0ARVALID(noc_cpm_pcie_axi0_arvalid),
      .IFNOCPSPCIAXI0AWADDR(noc_cpm_pcie_axi0_awaddr),
      .IFNOCPSPCIAXI0AWBURST(noc_cpm_pcie_axi0_awburst),
      .IFNOCPSPCIAXI0AWCACHE(noc_cpm_pcie_axi0_awcache),
      .IFNOCPSPCIAXI0AWID(noc_cpm_pcie_axi0_awid),
      .IFNOCPSPCIAXI0AWLEN(noc_cpm_pcie_axi0_awlen),
      .IFNOCPSPCIAXI0AWLOCK(noc_cpm_pcie_axi0_awlock),
      .IFNOCPSPCIAXI0AWPROT(noc_cpm_pcie_axi0_awprot),
      .IFNOCPSPCIAXI0AWQOS(noc_cpm_pcie_axi0_awqos),
      .IFNOCPSPCIAXI0AWREGION(noc_cpm_pcie_axi0_awregion),
      .IFNOCPSPCIAXI0AWSIZE(noc_cpm_pcie_axi0_awsize),
      .IFNOCPSPCIAXI0AWUSER(noc_cpm_pcie_axi0_awuser),
      .IFNOCPSPCIAXI0AWVALID(noc_cpm_pcie_axi0_awvalid),
      .IFNOCPSPCIAXI0BREADY(noc_cpm_pcie_axi0_bready),
      .IFNOCPSPCIAXI0RREADY(noc_cpm_pcie_axi0_rready),
      .IFNOCPSPCIAXI0WDATA(noc_cpm_pcie_axi0_wdata),
      .IFNOCPSPCIAXI0WID(noc_cpm_pcie_axi0_wid),
      .IFNOCPSPCIAXI0WLAST(noc_cpm_pcie_axi0_wlast),
      .IFNOCPSPCIAXI0WSTRB(noc_cpm_pcie_axi0_wstrb),
      .IFNOCPSPCIAXI0WUSER(if_noc_ps_pci_axi0_wuser),
      .IFNOCPSPCIAXI0WVALID(noc_cpm_pcie_axi0_wvalid),
      .IFPSNOCCCIAXI0ARREADY(fpd_cci_noc_axi0_arready),
      .IFPSNOCCCIAXI0AWREADY(fpd_cci_noc_axi0_awready),
      .IFPSNOCCCIAXI0BID(fpd_cci_noc_axi0_bid),
      .IFPSNOCCCIAXI0BRESP(fpd_cci_noc_axi0_bresp),
      .IFPSNOCCCIAXI0BUSER(if_ps_noc_cci_axi0_buser),
      .IFPSNOCCCIAXI0BVALID(fpd_cci_noc_axi0_bvalid),
      .IFPSNOCCCIAXI0RDATA(fpd_cci_noc_axi0_rdata),
      .IFPSNOCCCIAXI0RID(fpd_cci_noc_axi0_rid),
      .IFPSNOCCCIAXI0RLAST(fpd_cci_noc_axi0_rlast),
      .IFPSNOCCCIAXI0RRESP(fpd_cci_noc_axi0_rresp),
      .IFPSNOCCCIAXI0RUSER(if_ps_noc_cci_axi0_ruser),
      .IFPSNOCCCIAXI0RVALID(fpd_cci_noc_axi0_rvalid),
      .IFPSNOCCCIAXI0WREADY(fpd_cci_noc_axi0_wready),
      .IFPSNOCCCIAXI1ARREADY(fpd_cci_noc_axi1_arready),
      .IFPSNOCCCIAXI1AWREADY(fpd_cci_noc_axi1_awready),
      .IFPSNOCCCIAXI1BID(fpd_cci_noc_axi1_bid),
      .IFPSNOCCCIAXI1BRESP(fpd_cci_noc_axi1_bresp),
      .IFPSNOCCCIAXI1BUSER(if_ps_noc_cci_axi1_buser),
      .IFPSNOCCCIAXI1BVALID(fpd_cci_noc_axi1_bvalid),
      .IFPSNOCCCIAXI1RDATA(fpd_cci_noc_axi1_rdata),
      .IFPSNOCCCIAXI1RID(fpd_cci_noc_axi1_rid),
      .IFPSNOCCCIAXI1RLAST(fpd_cci_noc_axi1_rlast),
      .IFPSNOCCCIAXI1RRESP(fpd_cci_noc_axi1_rresp),
      .IFPSNOCCCIAXI1RUSER(if_ps_noc_cci_axi1_ruser),
      .IFPSNOCCCIAXI1RVALID(fpd_cci_noc_axi1_rvalid),
      .IFPSNOCCCIAXI1WREADY(fpd_cci_noc_axi1_wready),
      .IFPSNOCCCIAXI2ARREADY(fpd_cci_noc_axi2_arready),
      .IFPSNOCCCIAXI2AWREADY(fpd_cci_noc_axi2_awready),
      .IFPSNOCCCIAXI2BID(fpd_cci_noc_axi2_bid),
      .IFPSNOCCCIAXI2BRESP(fpd_cci_noc_axi2_bresp),
      .IFPSNOCCCIAXI2BUSER(if_ps_noc_cci_axi2_buser),
      .IFPSNOCCCIAXI2BVALID(fpd_cci_noc_axi2_bvalid),
      .IFPSNOCCCIAXI2RDATA(fpd_cci_noc_axi2_rdata),
      .IFPSNOCCCIAXI2RID(fpd_cci_noc_axi2_rid),
      .IFPSNOCCCIAXI2RLAST(fpd_cci_noc_axi2_rlast),
      .IFPSNOCCCIAXI2RRESP(fpd_cci_noc_axi2_rresp),
      .IFPSNOCCCIAXI2RUSER(if_ps_noc_cci_axi2_ruser),
      .IFPSNOCCCIAXI2RVALID(fpd_cci_noc_axi2_rvalid),
      .IFPSNOCCCIAXI2WREADY(fpd_cci_noc_axi2_wready),
      .IFPSNOCCCIAXI3ARREADY(fpd_cci_noc_axi3_arready),
      .IFPSNOCCCIAXI3AWREADY(fpd_cci_noc_axi3_awready),
      .IFPSNOCCCIAXI3BID(fpd_cci_noc_axi3_bid),
      .IFPSNOCCCIAXI3BRESP(fpd_cci_noc_axi3_bresp),
      .IFPSNOCCCIAXI3BUSER(if_ps_noc_cci_axi3_buser),
      .IFPSNOCCCIAXI3BVALID(fpd_cci_noc_axi3_bvalid),
      .IFPSNOCCCIAXI3RDATA(fpd_cci_noc_axi3_rdata),
      .IFPSNOCCCIAXI3RID(fpd_cci_noc_axi3_rid),
      .IFPSNOCCCIAXI3RLAST(fpd_cci_noc_axi3_rlast),
      .IFPSNOCCCIAXI3RRESP(fpd_cci_noc_axi3_rresp),
      .IFPSNOCCCIAXI3RUSER(if_ps_noc_cci_axi3_ruser),
      .IFPSNOCCCIAXI3RVALID(fpd_cci_noc_axi3_rvalid),
      .IFPSNOCCCIAXI3WREADY(fpd_cci_noc_axi3_wready),
      .IFPSNOCNCIAXI0ARREADY(fpd_axi_noc_axi0_arready),
      .IFPSNOCNCIAXI0AWREADY(fpd_axi_noc_axi0_awready),
      .IFPSNOCNCIAXI0BID(fpd_axi_noc_axi0_bid),
      .IFPSNOCNCIAXI0BRESP(fpd_axi_noc_axi0_bresp),
      .IFPSNOCNCIAXI0BUSER(if_ps_noc_nci_axi0_buser),
      .IFPSNOCNCIAXI0BVALID(fpd_axi_noc_axi0_bvalid),
      .IFPSNOCNCIAXI0RDATA(fpd_axi_noc_axi0_rdata),
      .IFPSNOCNCIAXI0RID(fpd_axi_noc_axi0_rid),
      .IFPSNOCNCIAXI0RLAST(fpd_axi_noc_axi0_rlast),
      .IFPSNOCNCIAXI0RRESP(fpd_axi_noc_axi0_rresp),
      .IFPSNOCNCIAXI0RUSER(if_ps_noc_nci_axi0_ruser),
      .IFPSNOCNCIAXI0RVALID(fpd_axi_noc_axi0_rvalid),
      .IFPSNOCNCIAXI0WREADY(fpd_axi_noc_axi0_wready),
      .IFPSNOCNCIAXI1ARREADY(fpd_axi_noc_axi1_arready),
      .IFPSNOCNCIAXI1AWREADY(fpd_axi_noc_axi1_awready),
      .IFPSNOCNCIAXI1BID(fpd_axi_noc_axi1_bid),
      .IFPSNOCNCIAXI1BRESP(fpd_axi_noc_axi1_bresp),
      .IFPSNOCNCIAXI1BUSER(if_ps_noc_nci_axi1_buser),
      .IFPSNOCNCIAXI1BVALID(fpd_axi_noc_axi1_bvalid),
      .IFPSNOCNCIAXI1RDATA(fpd_axi_noc_axi1_rdata),
      .IFPSNOCNCIAXI1RID(fpd_axi_noc_axi1_rid),
      .IFPSNOCNCIAXI1RLAST(fpd_axi_noc_axi1_rlast),
      .IFPSNOCNCIAXI1RRESP(fpd_axi_noc_axi1_rresp),
      .IFPSNOCNCIAXI1RUSER(if_ps_noc_nci_axi1_ruser),
      .IFPSNOCNCIAXI1RVALID(fpd_axi_noc_axi1_rvalid),
      .IFPSNOCNCIAXI1WREADY(fpd_axi_noc_axi1_wready),
      .IFPSNOCPCIAXI0ARREADY(cpm_pcie_noc_axi0_arready),
      .IFPSNOCPCIAXI0AWREADY(cpm_pcie_noc_axi0_awready),
      .IFPSNOCPCIAXI0BID(cpm_pcie_noc_axi0_bid),
      .IFPSNOCPCIAXI0BRESP(cpm_pcie_noc_axi0_bresp),
      .IFPSNOCPCIAXI0BUSER(if_ps_noc_pci_axi0_buser),
      .IFPSNOCPCIAXI0BVALID(cpm_pcie_noc_axi0_bvalid),
      .IFPSNOCPCIAXI0RDATA(cpm_pcie_noc_axi0_rdata),
      .IFPSNOCPCIAXI0RID(cpm_pcie_noc_axi0_rid),
      .IFPSNOCPCIAXI0RLAST(cpm_pcie_noc_axi0_rlast),
      .IFPSNOCPCIAXI0RRESP(cpm_pcie_noc_axi0_rresp),
      .IFPSNOCPCIAXI0RUSER(if_ps_noc_pci_axi0_ruser),
      .IFPSNOCPCIAXI0RVALID(cpm_pcie_noc_axi0_rvalid),
      .IFPSNOCPCIAXI0WREADY(cpm_pcie_noc_axi0_wready),
      .IFPSNOCPCIAXI1ARREADY(cpm_pcie_noc_axi1_arready),
      .IFPSNOCPCIAXI1AWREADY(cpm_pcie_noc_axi1_awready),
      .IFPSNOCPCIAXI1BID(cpm_pcie_noc_axi1_bid),
      .IFPSNOCPCIAXI1BRESP(cpm_pcie_noc_axi1_bresp),
      .IFPSNOCPCIAXI1BUSER(if_ps_noc_pci_axi1_buser),
      .IFPSNOCPCIAXI1BVALID(cpm_pcie_noc_axi1_bvalid),
      .IFPSNOCPCIAXI1RDATA(cpm_pcie_noc_axi1_rdata),
      .IFPSNOCPCIAXI1RID(cpm_pcie_noc_axi1_rid),
      .IFPSNOCPCIAXI1RLAST(cpm_pcie_noc_axi1_rlast),
      .IFPSNOCPCIAXI1RRESP(cpm_pcie_noc_axi1_rresp),
      .IFPSNOCPCIAXI1RUSER(if_ps_noc_pci_axi1_ruser),
      .IFPSNOCPCIAXI1RVALID(cpm_pcie_noc_axi1_rvalid),
      .IFPSNOCPCIAXI1WREADY(cpm_pcie_noc_axi1_wready),
      .IFPSNOCRPUAXI0ARREADY(lpd_axi_noc_axi0_arready),
      .IFPSNOCRPUAXI0AWREADY(lpd_axi_noc_axi0_awready),
      .IFPSNOCRPUAXI0BID(lpd_axi_noc_axi0_bid),
      .IFPSNOCRPUAXI0BRESP(lpd_axi_noc_axi0_bresp),
      .IFPSNOCRPUAXI0BUSER(if_ps_noc_rpu_axi0_buser),
      .IFPSNOCRPUAXI0BVALID(lpd_axi_noc_axi0_bvalid),
      .IFPSNOCRPUAXI0RDATA(lpd_axi_noc_axi0_rdata),
      .IFPSNOCRPUAXI0RID(lpd_axi_noc_axi0_rid),
      .IFPSNOCRPUAXI0RLAST(lpd_axi_noc_axi0_rlast),
      .IFPSNOCRPUAXI0RRESP(lpd_axi_noc_axi0_rresp),
      .IFPSNOCRPUAXI0RUSER(if_ps_noc_rpu_axi0_ruser),
      .IFPSNOCRPUAXI0RVALID(lpd_axi_noc_axi0_rvalid),
      .IFPSNOCRPUAXI0WREADY(lpd_axi_noc_axi0_wready),
      .MAXIGP0ACLK(m_axi_fpd_aclk),
      .MAXIGP0ARREADY(m_axi_fpd_arready),
      .MAXIGP0AWREADY(m_axi_fpd_awready),
      .MAXIGP0BID(m_axi_fpd_bid),
      .MAXIGP0BRESP(m_axi_fpd_bresp),
      .MAXIGP0BVALID(m_axi_fpd_bvalid),
      .MAXIGP0RDATA(m_axi_fpd_rdata),
      .MAXIGP0RID(m_axi_fpd_rid),
      .MAXIGP0RLAST(m_axi_fpd_rlast),
      .MAXIGP0RRESP(m_axi_fpd_rresp),
      .MAXIGP0RVALID(m_axi_fpd_rvalid),
      .MAXIGP0WREADY(m_axi_fpd_wready),
      .MAXIGP2ACLK(m_axi_lpd_aclk),
      .MAXIGP2ARREADY(m_axi_lpd_arready),
      .MAXIGP2AWREADY(m_axi_lpd_awready),
      .MAXIGP2BID(m_axi_lpd_bid),
      .MAXIGP2BRESP(m_axi_lpd_bresp),
      .MAXIGP2BVALID(m_axi_lpd_bvalid),
      .MAXIGP2RDATA(m_axi_lpd_rdata),
      .MAXIGP2RID(m_axi_lpd_rid),
      .MAXIGP2RLAST(m_axi_lpd_rlast),
      .MAXIGP2RRESP(m_axi_lpd_rresp),
      .MAXIGP2RVALID(m_axi_lpd_rvalid),
      .MAXIGP2WREADY(m_axi_lpd_wready),
      .NFIQ0LPDRPU(lpd_rpu_fiq0n),
      .NFIQ1LPDRPU(lpd_rpu_fiq1n),
      .NIRQ0LPDRPU(lpd_rpu_irq0n),
      .NIRQ1LPDRPU(lpd_rpu_irq1n),
      .PL2ADMACVLD(pl_2_adma_cvld_i),
      .PL2ADMATACK(pl_2_adma_tack_i),
      .PLACECLK(s_ace_fpd_aclk),
      .PLACPINACT(s_acp_fpd_inact),
      .PLCONFIGDONE(pl_config_done),
    //.PLFPGASTOP(pl_fpga_stop),
      .PLFPDAUXREFCLK(pl_fpd_aux_ref_clk),
      .PLLPDAUXREFCLK(pl_lpd_aux_ref_clk),
      .PLPMCAUXREFCLK(pl_pmc_aux_ref_clk),
      .PLPSAPUGICFIQ(pl_ps_apu_gic_fiq),
      .PLPSAPUGICIRQ(pl_ps_apu_gic_irq),
      .PLPSEVENTI(apu_event_i),
      .PLPSIRQ0(pl_ps_irq0_i),
      .PLPSIRQ1(pl_ps_irq1_i),
      .PLPSSMMUARREADY(s_smmu_arready),
      .PLPSSMMUAWREADY(s_smmu_awready),
      .PLPSSMMUCOMPRDREADY(s_smmu_comprdready),
      .PLPSSMMUCOMPWRREADY(s_smmu_compwrready),
      .PSSMMUPLARADDR(m_smmu_araddr),
      .PSSMMUPLARCACHE(m_smmu_arcache),
      .PSSMMUPLARID(m_smmu_arid),
      .PSSMMUPLARVALID(m_smmu_arvalid),
      .PSSMMUPLAWADDR(m_smmu_awaddr),
      .PSSMMUPLAWCACHE(m_smmu_awcache),
      .PSSMMUPLAWID(m_smmu_awid),
      .PSSMMUPLAWVALID(m_smmu_awvalid),
      .PSSMMUPLBID(m_smmu_bid),
      .PSSMMUPLBRESP(m_smmu_bresp),
      .PSSMMUPLBVALID(m_smmu_bvalid),
      .PSSMMUPLRERR(m_smmu_rerr),
      .PSSMMUPLRID(m_smmu_rid),
      .PSSMMUPLRNS(m_smmu_rns),
      .PSSMMUPLRRESP(m_smmu_rresp),
      .PSSMMUPLRVALID(m_smmu_rvalid),
      .PSSMMUPLWERR(m_smmu_werr),
      .PSSMMUPLWNS(m_smmu_wns),
      .PLPSSMMUARADDR(s_smmu_araddr),
      .PLPSSMMUARCACHE(s_smmu_arcache),
      .PLPSSMMUARID(s_smmu_arid),
      .PLPSSMMUARVALID(s_smmu_arvalid),
      .PLPSSMMUAWADDR(s_smmu_awaddr),
      .PLPSSMMUAWCACHE(s_smmu_awcache),
      .PLPSSMMUAWID(s_smmu_awid),
      .PLPSSMMUAWVALID(s_smmu_awvalid),
      .PLPSSMMUCLOCK(smmu_ref_clk),
      .PLPSSMMUCOMPRDID(s_smmu_comprdid),
      .PLPSSMMUCOMPRDVAL(s_smmu_comprdval),
      .PLPSSMMUCOMPWRID(s_smmu_compwrid),
      .PLPSSMMUCOMPWRVAL(s_smmu_compwrval),
      .PLPSSMMURNS(s_smmu_rns),
      .PLPSSMMURSMID(s_smmu_rsmid),
      .PLPSSMMUWNS(s_smmu_wns),
      .PLPSSMMUWSMID(s_smmu_wsmid),
      .PSSMMUPLARREADY(m_smmu_arready),
      .PSSMMUPLAWREADY(m_smmu_awready),
      .PSSMMUPLBREADY(m_smmu_bready),
      .PSSMMUPLRREADY(m_smmu_rready),
      .PLREFCLKMUXMONITOR(pl_ref_clk_mux_monitor),
      .PLPSTRACECLK(trace_ref_clk),
      .PLPSTRIGACK ({ps_pl_trig3_ack, ps_pl_trig2_ack, ps_pl_trig1_ack, ps_pl_trig0_ack}),
      .PLPSTRIGGER ({pl_ps_trig3_req, pl_ps_trig2_req, pl_ps_trig1_req, pl_ps_trig0_req}),
      .PMUERRORFROMPL(s_pmu_error_from_pl),
      .RPUEVENTI0(lpd_rpu_event_i0),
      .RPUEVENTI1(lpd_rpu_event_i1),
      .SACEFPDACREADY(s_ace_fpd_acready),
      .SACEFPDARADDR(s_ace_fpd_araddr),
      .SACEFPDARBAR(s_ace_fpd_arbar),
      .SACEFPDARBURST(s_ace_fpd_arburst),
      .SACEFPDARCACHE(s_ace_fpd_arcache),
      .SACEFPDARDOMAIN(s_ace_fpd_ardomain),
      .SACEFPDARID(s_ace_fpd_arid),
      .SACEFPDARLEN(s_ace_fpd_arlen),
      .SACEFPDARLOCK(s_ace_fpd_arlock),
      .SACEFPDARPROT(s_ace_fpd_arprot),
      .SACEFPDARQOS(s_ace_fpd_arqos),
      .SACEFPDARREGION(s_ace_fpd_arregion),
      .SACEFPDARSIZE(s_ace_fpd_arsize),
      .SACEFPDARSNOOP(s_ace_fpd_arsnoop),
      .SACEFPDARUSER(s_ace_fpd_aruser),
      .SACEFPDARVALID(s_ace_fpd_arvalid),
      .SACEFPDAWADDR(s_ace_fpd_awaddr),
      .SACEFPDAWBAR(s_ace_fpd_awbar),
      .SACEFPDAWBURST(s_ace_fpd_awburst),
      .SACEFPDAWCACHE(s_ace_fpd_awcache),
      .SACEFPDAWDOMAIN(s_ace_fpd_awdomain),
      .SACEFPDAWID(s_ace_fpd_awid),
      .SACEFPDAWLEN(s_ace_fpd_awlen),
      .SACEFPDAWLOCK(s_ace_fpd_awlock),
      .SACEFPDAWPROT(s_ace_fpd_awprot),
      .SACEFPDAWQOS(s_ace_fpd_awqos),
      .SACEFPDAWREGION(s_ace_fpd_awregion),
      .SACEFPDAWSIZE(s_ace_fpd_awsize),
      .SACEFPDAWSNOOP(s_ace_fpd_awsnoop),
      .SACEFPDAWUSER(s_ace_fpd_awuser),
      .SACEFPDAWVALID(s_ace_fpd_awvalid),
      .SACEFPDBREADY(s_ace_fpd_bready),
      .SACEFPDCDDATA(s_ace_fpd_cddata),
      .SACEFPDCDLAST(s_ace_fpd_cdlast),
      .SACEFPDCDVALID(s_ace_fpd_cdvalid),
      .SACEFPDCRRESP(s_ace_fpd_crresp),
      .SACEFPDCRVALID(s_ace_fpd_crvalid),
      .SACEFPDRACK(s_ace_fpd_rack),
      .SACEFPDRREADY(s_ace_fpd_rready),
      .SACEFPDWACK(s_ace_fpd_wack),
      .SACEFPDWDATA(s_ace_fpd_wdata),
      .SACEFPDWLAST(s_ace_fpd_wlast),
      .SACEFPDWSTRB(s_ace_fpd_wstrb),
      .SACEFPDWUSER(s_ace_fpd_wuser),
      .SACEFPDWVALID(s_ace_fpd_wvalid),
      .SAXIACPACLK(s_acp_fpd_aclk),
      .SAXIACPARADDR(s_acp_fpd_araddr),
    //.SAXIACPARBURST(s_axi_acp_arburst),
      .SAXIACPARCACHE(s_acp_fpd_arcache),
      .SAXIACPARID(s_acp_fpd_arid),
      .SAXIACPARLEN(s_acp_fpd_arlen),
    //.SAXIACPARLOCK(s_axi_acp_arlock),
      .SAXIACPARPROT(s_acp_fpd_arprot),
    //.SAXIACPARQOS(s_axi_acp_arqos),
    //.SAXIACPARSIZE(s_axi_acp_arsize),
      .SAXIACPARUSER(s_acp_fpd_aruser),
      .SAXIACPARVALID(s_acp_fpd_arvalid),
      .SAXIACPAWADDR(s_acp_fpd_awaddr),
    //.SAXIACPAWBURST(s_axi_acp_awburst),
      .SAXIACPAWCACHE(s_acp_fpd_awcache),
      .SAXIACPAWID(s_acp_fpd_awid),
      .SAXIACPAWLEN(s_acp_fpd_awlen),
    //.SAXIACPAWLOCK(s_axi_acp_awlock),
      .SAXIACPAWPROT(s_acp_fpd_awprot),
    //.SAXIACPAWQOS(s_axi_acp_awqos),
    //.SAXIACPAWSIZE(s_axi_acp_awsize),
      .SAXIACPAWUSER(s_acp_fpd_awuser),
      .SAXIACPAWVALID(s_acp_fpd_awvalid),
      .SAXIACPBREADY(s_acp_fpd_bready),
      .SAXIACPRREADY(s_acp_fpd_rready),
      .SAXIACPWDATA(s_acp_fpd_wdata),
      .SAXIACPWLAST(s_acp_fpd_wlast),
      .SAXIACPWSTRB(s_acp_fpd_wstrb),
      .SAXIACPWVALID(s_acp_fpd_wvalid),
      .SAXIGP0ARADDR(s_axi_fpd_araddr),
      .SAXIGP0ARBURST(s_axi_fpd_arburst),
      .SAXIGP0ARCACHE(s_axi_fpd_arcache),
      .SAXIGP0ARID(s_axi_fpd_arid),
      .SAXIGP0ARLEN(s_axi_fpd_arlen),
      .SAXIGP0ARLOCK(s_axi_fpd_arlock),
      .SAXIGP0ARPROT(s_axi_fpd_arprot),
      .SAXIGP0ARQOS(s_axi_fpd_arqos),
      .SAXIGP0ARSIZE(s_axi_fpd_arsize),
      .SAXIGP0ARUSER(s_axi_fpd_aruser),
      .SAXIGP0ARVALID(s_axi_fpd_arvalid),
      .SAXIGP0AWADDR(s_axi_fpd_awaddr),
      .SAXIGP0AWBURST(s_axi_fpd_awburst),
      .SAXIGP0AWCACHE(s_axi_fpd_awcache),
      .SAXIGP0AWID(s_axi_fpd_awid),
      .SAXIGP0AWLEN(s_axi_fpd_awlen),
      .SAXIGP0AWLOCK(s_axi_fpd_awlock),
      .SAXIGP0AWPROT(s_axi_fpd_awprot),
      .SAXIGP0AWQOS(s_axi_fpd_awqos),
      .SAXIGP0AWSIZE(s_axi_fpd_awsize),
      .SAXIGP0AWUSER(s_axi_fpd_awuser),
      .SAXIGP0AWVALID(s_axi_fpd_awvalid),
      .SAXIGP0BREADY(s_axi_fpd_bready),
      .SAXIGP0RCLK(s_axi_gp0_rclk_temp),
      .SAXIGP0RREADY(s_axi_fpd_rready),
      .SAXIGP0WCLK(s_axi_gp0_wclk_temp),
      .SAXIGP0WDATA(s_axi_fpd_wdata),
      .SAXIGP0WLAST(s_axi_fpd_wlast),
      .SAXIGP0WSTRB(s_axi_fpd_wstrb),
      .SAXIGP0WVALID(s_axi_fpd_wvalid),
      .SAXIGP2ARADDR(s_axi_gp2_araddr_t),
      .SAXIGP2ARBURST(s_axi_gp2_arburst_t),
      .SAXIGP2ARCACHE(s_axi_gp2_arcache_t),
      .SAXIGP2ARID(s_axi_gp2_arid_t),
      .SAXIGP2ARLEN(s_axi_gp2_arlen_t),
      .SAXIGP2ARLOCK(s_axi_gp2_arlock_t),
      .SAXIGP2ARPROT(s_axi_gp2_arprot_t),
      .SAXIGP2ARQOS(s_axi_gp2_arqos_t),
      .SAXIGP2ARSIZE(s_axi_gp2_arsize_t),
      .SAXIGP2ARUSER(s_axi_gp2_aruser_t),
      .SAXIGP2ARVALID(s_axi_gp2_arvalid_t),
      .SAXIGP2AWADDR(s_axi_gp2_awaddr_t),
      .SAXIGP2AWBURST(s_axi_gp2_awburst_t),
      .SAXIGP2AWCACHE(s_axi_gp2_awcache_t),
      .SAXIGP2AWID(s_axi_gp2_awid_t),
      .SAXIGP2AWLEN(s_axi_gp2_awlen_t),
      .SAXIGP2AWLOCK(s_axi_gp2_awlock_t),
      .SAXIGP2AWPROT(s_axi_gp2_awprot_t),
      .SAXIGP2AWQOS(s_axi_gp2_awqos_t),
      .SAXIGP2AWSIZE(s_axi_gp2_awsize_t),
      .SAXIGP2AWUSER(s_axi_gp2_awuser_t),
      .SAXIGP2AWVALID(s_axi_gp2_awvalid_t),
      .SAXIGP2BREADY(s_axi_gp2_bready_t),
      .SAXIGP2RCLK(s_axi_gp2_rclk_temp),
      .SAXIGP2RREADY(s_axi_gp2_rready_t),
      .SAXIGP2WCLK(s_axi_gp2_wclk_temp),
      .SAXIGP2WDATA(s_axi_gp2_wdata_t),
      .SAXIGP2WLAST(s_axi_gp2_wlast_t),
      .SAXIGP2WSTRB(s_axi_gp2_wstrb_t),
      .SAXIGP2WVALID(s_axi_gp2_wvalid_t),
      .SAXIGP4ARADDR(s_axi_lpd_araddr),
      .SAXIGP4ARBURST(s_axi_lpd_arburst),
      .SAXIGP4ARCACHE(s_axi_lpd_arcache),
      .SAXIGP4ARID(s_axi_lpd_arid),
      .SAXIGP4ARLEN(s_axi_lpd_arlen),
      .SAXIGP4ARLOCK(s_axi_lpd_arlock),
      .SAXIGP4ARPROT(s_axi_lpd_arprot),
      .SAXIGP4ARQOS(s_axi_lpd_arqos),
      .SAXIGP4ARSIZE(s_axi_lpd_arsize),
      .SAXIGP4ARUSER(s_axi_lpd_aruser),
      .SAXIGP4ARVALID(s_axi_lpd_arvalid),
      .SAXIGP4AWADDR(s_axi_lpd_awaddr),
      .SAXIGP4AWBURST(s_axi_lpd_awburst),
      .SAXIGP4AWCACHE(s_axi_lpd_awcache),
      .SAXIGP4AWID(s_axi_lpd_awid),
      .SAXIGP4AWLEN(s_axi_lpd_awlen),
      .SAXIGP4AWLOCK(s_axi_lpd_awlock),
      .SAXIGP4AWPROT(s_axi_lpd_awprot),
      .SAXIGP4AWQOS(s_axi_lpd_awqos),
      .SAXIGP4AWSIZE(s_axi_lpd_awsize),
      .SAXIGP4AWUSER(s_axi_lpd_awuser),
      .SAXIGP4AWVALID(s_axi_lpd_awvalid),
      .SAXIGP4BREADY(s_axi_lpd_bready),
      .SAXIGP4RCLK(s_axi_gp4_rclk_temp),
      .SAXIGP4RREADY(s_axi_lpd_rready),
      .SAXIGP4WCLK(s_axi_gp4_wclk_temp),
      .SAXIGP4WDATA(s_axi_lpd_wdata),
      .SAXIGP4WLAST(s_axi_lpd_wlast),
      .SAXIGP4WSTRB(s_axi_lpd_wstrb),
      .SAXIGP4WVALID(s_axi_lpd_wvalid),

      // BSCAN ports
      .USRCAPTURE(usr_capture_i),
      .USRDRCK(usr_drck_i),
      .USRRESET(usr_reset_i),
      .USRRUNTEST(usr_runtest_i),
      .USRSEL(usr_sel_i),
      .USRSHIFT(usr_shift_i),
      .USRTCK(usr_tck_i),
      .USRTDI(usr_tdi_i),
      .USRTMS(usr_tms_i),
      .USRUPDATE(usr_update_i),
      .USRTDO(usr_tdo_i),
    //.SYSRST1N(pl_resetn1_i),
    //.SYSRST2N(pl2_resetn),
    //.SYSRST3N(pl3_resetn),
      .PLRST0N(pl0_resetn),
      .PLRST1N(pl1_resetn),
      .PLRST2N(pl2_resetn),
      .PLRST3N(pl3_resetn),

      //PMC_NOC ports below
      .IFPMCNOCAXI0ARADDR(pmc_noc_axi0_araddr),
      .IFPMCNOCAXI0ARBURST(pmc_noc_axi0_arburst),
      .IFPMCNOCAXI0ARCACHE(pmc_noc_axi0_arcache),
      .IFPMCNOCAXI0ARID(pmc_noc_axi0_arid),
      .IFPMCNOCAXI0ARLEN(pmc_noc_axi0_arlen),
      .IFPMCNOCAXI0ARLOCK(pmc_noc_axi0_arlock),
      .IFPMCNOCAXI0ARPROT(pmc_noc_axi0_arprot),
      .IFPMCNOCAXI0ARQOS(pmc_noc_axi0_arqos),
      .IFPMCNOCAXI0ARREGION(pmc_noc_axi0_arregion),
      .IFPMCNOCAXI0ARSIZE(pmc_noc_axi0_arsize),
      .IFPMCNOCAXI0ARUSER(pmc_noc_axi0_aruser),
      .IFPMCNOCAXI0ARVALID(pmc_noc_axi0_arvalid),
      .IFPMCNOCAXI0AWADDR(pmc_noc_axi0_awaddr),
      .IFPMCNOCAXI0AWBURST(pmc_noc_axi0_awburst),
      .IFPMCNOCAXI0AWCACHE(pmc_noc_axi0_awcache),
      .IFPMCNOCAXI0AWID(pmc_noc_axi0_awid),
      .IFPMCNOCAXI0AWLEN(pmc_noc_axi0_awlen),
      .IFPMCNOCAXI0AWLOCK(pmc_noc_axi0_awlock),
      .IFPMCNOCAXI0AWPROT(pmc_noc_axi0_awprot),
      .IFPMCNOCAXI0AWQOS(pmc_noc_axi0_awqos),
      .IFPMCNOCAXI0AWREGION(pmc_noc_axi0_awregion),
      .IFPMCNOCAXI0AWSIZE(pmc_noc_axi0_awsize),
      .IFPMCNOCAXI0AWUSER(pmc_noc_axi0_awuser),
      .IFPMCNOCAXI0AWVALID(pmc_noc_axi0_awvalid),
      .IFPMCNOCAXI0BREADY(pmc_noc_axi0_bready),
      .IFPMCNOCAXI0RREADY(pmc_noc_axi0_rready),
      .IFPMCNOCAXI0WDATA(pmc_noc_axi0_wdata),
      .IFPMCNOCAXI0WID(pmc_noc_axi0_wid),
      .IFPMCNOCAXI0WLAST(pmc_noc_axi0_wlast),
      .IFPMCNOCAXI0WSTRB(pmc_noc_axi0_wstrb),
      .IFPMCNOCAXI0WUSER(pmc_noc_axi0_wuser),
      .IFPMCNOCAXI0WVALID(pmc_noc_axi0_wvalid),
      .PSPMCNOCAXI0CLK(pmc_axi_noc_axi0_clk),
      .IFPMCNOCAXI0ARREADY(pmc_noc_axi0_arready),
      .IFPMCNOCAXI0AWREADY(pmc_noc_axi0_awready),
      .IFPMCNOCAXI0BID(pmc_noc_axi0_bid),
      .IFPMCNOCAXI0BRESP(pmc_noc_axi0_bresp),
      .IFPMCNOCAXI0BUSER(pmc_noc_axi0_buser),
      .IFPMCNOCAXI0BVALID(pmc_noc_axi0_bvalid),
      .IFPMCNOCAXI0RDATA(pmc_noc_axi0_rdata),
      .IFPMCNOCAXI0RID(pmc_noc_axi0_rid),
      .IFPMCNOCAXI0RLAST(pmc_noc_axi0_rlast),
      .IFPMCNOCAXI0RRESP(pmc_noc_axi0_rresp),
      .IFPMCNOCAXI0RUSER(pmc_noc_axi0_ruser),
      .IFPMCNOCAXI0RVALID(pmc_noc_axi0_rvalid),
      .IFPMCNOCAXI0WREADY(pmc_noc_axi0_wready),
      //PMC_NOC ports above

      //NOC_PMC ports below
      .IFNOCPMCAXI0ARREADY(noc_pmc_axi0_arready),
      .IFNOCPMCAXI0AWREADY(noc_pmc_axi0_awready),
      .IFNOCPMCAXI0BID(noc_pmc_axi0_bid),
      .IFNOCPMCAXI0BRESP(noc_pmc_axi0_bresp),
      .IFNOCPMCAXI0BUSER(noc_pmc_axi0_buser),
      .IFNOCPMCAXI0BVALID(noc_pmc_axi0_bvalid),
      .IFNOCPMCAXI0RDATA(noc_pmc_axi0_rdata),
      .IFNOCPMCAXI0RID(noc_pmc_axi0_rid),
      .IFNOCPMCAXI0RLAST(noc_pmc_axi0_rlast),
      .IFNOCPMCAXI0RRESP(noc_pmc_axi0_rresp),
      .IFNOCPMCAXI0RUSER(noc_pmc_axi0_ruser),
      .IFNOCPMCAXI0RVALID(noc_pmc_axi0_rvalid),
      .IFNOCPMCAXI0WREADY(noc_pmc_axi0_wready),
      .PSNOCPMCAXI0CLK(noc_pmc_axi_axi0_clk),
      .IFNOCPMCAXI0ARADDR(noc_pmc_axi0_araddr),
      .IFNOCPMCAXI0ARBURST(noc_pmc_axi0_arburst),
      .IFNOCPMCAXI0ARCACHE(noc_pmc_axi0_arcache),
      .IFNOCPMCAXI0ARID(noc_pmc_axi0_arid),
      .IFNOCPMCAXI0ARLEN(noc_pmc_axi0_arlen),
      .IFNOCPMCAXI0ARLOCK(noc_pmc_axi0_arlock),
      .IFNOCPMCAXI0ARPROT(noc_pmc_axi0_arprot),
      .IFNOCPMCAXI0ARQOS(noc_pmc_axi0_arqos),
      .IFNOCPMCAXI0ARREGION(noc_pmc_axi0_arregion),
      .IFNOCPMCAXI0ARSIZE(noc_pmc_axi0_arsize),
      .IFNOCPMCAXI0ARUSER(noc_pmc_axi0_aruser),
      .IFNOCPMCAXI0ARVALID(noc_pmc_axi0_arvalid),
      .IFNOCPMCAXI0AWADDR(noc_pmc_axi0_awaddr),
      .IFNOCPMCAXI0AWBURST(noc_pmc_axi0_awburst),
      .IFNOCPMCAXI0AWCACHE(noc_pmc_axi0_awcache),
      .IFNOCPMCAXI0AWID(noc_pmc_axi0_awid),
      .IFNOCPMCAXI0AWLEN(noc_pmc_axi0_awlen),
      .IFNOCPMCAXI0AWLOCK(noc_pmc_axi0_awlock),
      .IFNOCPMCAXI0AWPROT(noc_pmc_axi0_awprot),
      .IFNOCPMCAXI0AWQOS(noc_pmc_axi0_awqos),
      .IFNOCPMCAXI0AWREGION(noc_pmc_axi0_awregion),
      .IFNOCPMCAXI0AWSIZE(noc_pmc_axi0_awsize),
      .IFNOCPMCAXI0AWUSER(noc_pmc_axi0_awuser),
      .IFNOCPMCAXI0AWVALID(noc_pmc_axi0_awvalid),
      .IFNOCPMCAXI0BREADY(noc_pmc_axi0_bready),
      .IFNOCPMCAXI0RREADY(noc_pmc_axi0_rready),
      .IFNOCPMCAXI0WDATA(noc_pmc_axi0_wdata),
      .IFNOCPMCAXI0WID(noc_pmc_axi0_wid),
      .IFNOCPMCAXI0WLAST(noc_pmc_axi0_wlast),
      .IFNOCPMCAXI0WSTRB(noc_pmc_axi0_wstrb),
      .IFNOCPMCAXI0WUSER(noc_pmc_axi0_wuser),
      .IFNOCPMCAXI0WVALID(noc_pmc_axi0_wvalid),

      .PERST0N(perst0n),
      .PERST1N(perst1n),
      .PLHSDPEGRESSTDATA(s_axis_hsdp_egress_tdata),
      .PLHSDPEGRESSTKEEP(s_axis_hsdp_egress_tkeep),
      .PLHSDPEGRESSTLAST(s_axis_hsdp_egress_tlast),
      .PLHSDPEGRESSTUSER(s_axis_hsdp_egress_tuser),
      .PLHSDPEGRESSTVALID(s_axis_hsdp_egress_tvalid),
      .PLHSDPINGRESSTREADY(s_axis_hsdp_ingress_tready),
      .PLHSDPCLK(hsdp_ref_clk),
      .PLHSDPEGRESSTREADY(s_axis_hsdp_egress_tready),
      .PLHSDPINGRESSTDATA(s_axis_hsdp_ingress_tdata),
      .PLHSDPINGRESSTKEEP(s_axis_hsdp_ingress_tkeep),
      .PLHSDPINGRESSTLAST(s_axis_hsdp_ingress_tlast),
      .PLHSDPINGRESSTVALID(s_axis_hsdp_ingress_tvalid),

	  .IFCPMPSAXI0ARADDR(m_axi0_ps_araddr),
	  .IFCPMPSAXI0ARBURST(m_axi0_ps_arburst),
	  .IFCPMPSAXI0ARCACHE(m_axi0_ps_arcache),
	  .IFCPMPSAXI0ARID(m_axi0_ps_arid),
	  .IFCPMPSAXI0ARLEN(m_axi0_ps_arlen),
	  .IFCPMPSAXI0ARLOCK(m_axi0_ps_arlock),
	  .IFCPMPSAXI0ARPROT(m_axi0_ps_arprot),
	  .IFCPMPSAXI0ARQOS(m_axi0_ps_arqos),
	  .IFCPMPSAXI0ARREGION(m_axi0_ps_arregion),
	  .IFCPMPSAXI0ARSIZE(m_axi0_ps_arsize),
	  .IFCPMPSAXI0ARUSER(m_axi0_ps_aruser),
	  .IFCPMPSAXI0ARVALID(m_axi0_ps_arvalid),
	  .IFCPMPSAXI0AWADDR(m_axi0_ps_awaddr),
	  .IFCPMPSAXI0AWBURST(m_axi0_ps_awburst),
	  .IFCPMPSAXI0AWCACHE(m_axi0_ps_awcache),
	  .IFCPMPSAXI0AWID(m_axi0_ps_awid),
	  .IFCPMPSAXI0AWLEN(m_axi0_ps_awlen),
	  .IFCPMPSAXI0AWLOCK(m_axi0_ps_awlock),
	  .IFCPMPSAXI0AWPROT(m_axi0_ps_awprot),
	  .IFCPMPSAXI0AWQOS(m_axi0_ps_awqos),
	  .IFCPMPSAXI0AWREGION(m_axi0_ps_awregion),
	  .IFCPMPSAXI0AWSIZE(m_axi0_ps_awsize),
	  .IFCPMPSAXI0AWUSER(m_axi0_ps_awuser),
	  .IFCPMPSAXI0AWVALID(m_axi0_ps_awvalid),
	  .IFCPMPSAXI0BREADY(m_axi0_ps_bready),
	  .IFCPMPSAXI0RREADY(m_axi0_ps_rready),
	  .IFCPMPSAXI0WDATA(m_axi0_ps_wdata),
	  .IFCPMPSAXI0WID(m_axi0_ps_wid),
	  .IFCPMPSAXI0WLAST(m_axi0_ps_wlast),
	  .IFCPMPSAXI0WSTRB(m_axi0_ps_wstrb),
	  .IFCPMPSAXI0WUSER(m_axi0_ps_wuser),
	  .IFCPMPSAXI0WVALID(m_axi0_ps_wvalid),
	  .IFCPMPSAXI1ARADDR(m_axi1_ps_araddr),
	  .IFCPMPSAXI1ARBURST(m_axi1_ps_arburst), 
	  .IFCPMPSAXI1ARCACHE(m_axi1_ps_arcache), 
	  .IFCPMPSAXI1ARID(m_axi1_ps_arid), 
	  .IFCPMPSAXI1ARLEN(m_axi1_ps_arlen), 
	  .IFCPMPSAXI1ARLOCK(m_axi1_ps_arlock), 
	  .IFCPMPSAXI1ARPROT(m_axi1_ps_arprot), 
	  .IFCPMPSAXI1ARQOS(m_axi1_ps_arqos), 
	  .IFCPMPSAXI1ARREGION(m_axi1_ps_arregion),
	  .IFCPMPSAXI1ARSIZE(m_axi1_ps_arsize), 
	  .IFCPMPSAXI1ARUSER(m_axi1_ps_aruser), 
	  .IFCPMPSAXI1ARVALID(m_axi1_ps_arvalid), 
	  .IFCPMPSAXI1AWADDR(m_axi1_ps_awaddr), 
	  .IFCPMPSAXI1AWBURST(m_axi1_ps_awburst), 
	  .IFCPMPSAXI1AWCACHE(m_axi1_ps_awcache), 
	  .IFCPMPSAXI1AWID(m_axi1_ps_awid), 
	  .IFCPMPSAXI1AWLEN(m_axi1_ps_awlen), 
	  .IFCPMPSAXI1AWLOCK(m_axi1_ps_awlock), 
	  .IFCPMPSAXI1AWPROT(m_axi1_ps_awprot), 
	  .IFCPMPSAXI1AWQOS(m_axi1_ps_awqos), 
	  .IFCPMPSAXI1AWREGION(m_axi1_ps_awregion),
	  .IFCPMPSAXI1AWSIZE(m_axi1_ps_awsize), 
	  .IFCPMPSAXI1AWUSER(m_axi1_ps_awuser), 
	  .IFCPMPSAXI1AWVALID(m_axi1_ps_awvalid), 
	  .IFCPMPSAXI1BREADY(m_axi1_ps_bready), 
	  .IFCPMPSAXI1RREADY(m_axi1_ps_rready), 
	  .IFCPMPSAXI1WDATA(m_axi1_ps_wdata), 
	  .IFCPMPSAXI1WID(m_axi1_ps_wid), 
	  .IFCPMPSAXI1WLAST(m_axi1_ps_wlast), 
	  .IFCPMPSAXI1WSTRB(m_axi1_ps_wstrb), 
	  .IFCPMPSAXI1WUSER(m_axi1_ps_wuser), 
	  .IFCPMPSAXI1WVALID(m_axi1_ps_wvalid),
	  .IFCPMPSAXI0ARREADY(m_axi0_ps_arready),
      .IFCPMPSAXI0AWREADY(m_axi0_ps_awready),
      .IFCPMPSAXI0BID(m_axi0_ps_bid),
      .IFCPMPSAXI0BRESP(m_axi0_ps_bresp),
      .IFCPMPSAXI0BUSER(m_axi0_ps_buser),
      .IFCPMPSAXI0BVALID(m_axi0_ps_bvalid),
      .IFCPMPSAXI0RDATA(m_axi0_ps_rdata),
      .IFCPMPSAXI0RID(m_axi0_ps_rid),
      .IFCPMPSAXI0RLAST(m_axi0_ps_rlast),
      .IFCPMPSAXI0RRESP(m_axi0_ps_rresp),
      .IFCPMPSAXI0RUSER(m_axi0_ps_ruser),
      .IFCPMPSAXI0RVALID(m_axi0_ps_rvalid),
      .IFCPMPSAXI0WREADY(m_axi0_ps_wready),
      .IFCPMPSAXI1ARREADY(m_axi1_ps_arready),
      .IFCPMPSAXI1AWREADY(m_axi1_ps_awready),
      .IFCPMPSAXI1BID(m_axi1_ps_bid),
      .IFCPMPSAXI1BRESP(m_axi1_ps_bresp),
      .IFCPMPSAXI1BUSER(m_axi1_ps_buser),
      .IFCPMPSAXI1BVALID(m_axi1_ps_bvalid),
      .IFCPMPSAXI1RDATA(m_axi1_ps_rdata),
      .IFCPMPSAXI1RID(m_axi1_ps_rid),
      .IFCPMPSAXI1RLAST(m_axi1_ps_rlast),
      .IFCPMPSAXI1RRESP(m_axi1_ps_rresp),
      .IFCPMPSAXI1RUSER(m_axi1_ps_ruser),
      .IFCPMPSAXI1RVALID(m_axi1_ps_rvalid),
      .IFCPMPSAXI1WREADY(m_axi1_ps_wready),
	  .IFCPMPSISRCORREVENT(cpmps_corr_irq),
      .IFCPMPSISRMISCEVENT(cpmps_misc_irq),
      .IFCPMPSISRUNCORREVENT(cpmps_uncorr_irq),
      .IFPSCPMCHANNEL0XPIPEPHYSTATUS(xpipe0_phystatus),
      .IFPSCPMCHANNEL0XPIPERXCHARISK(xpipe0_rx_charisk),
      .IFPSCPMCHANNEL0XPIPERXDATA(xpipe0_rx_data),
      .IFPSCPMCHANNEL0XPIPERXDATAVALID(xpipe0_rx_datavalid),
      .IFPSCPMCHANNEL0XPIPERXELECIDLE(xpipe0_rx_elecidle),
      .IFPSCPMCHANNEL0XPIPERXSTARTBLOCK(xpipe0_rx_startblock),
      .IFPSCPMCHANNEL0XPIPERXSTATUS(xpipe0_rx_status),
      .IFPSCPMCHANNEL0XPIPERXSYNCHEADER(xpipe0_rx_syncheader),
      .IFPSCPMCHANNEL0XPIPERXVALID(xpipe0_rx_valid),
	  .IFPSCPMCHANNEL10XPIPEPHYSTATUS(xpipe10_phystatus),
      .IFPSCPMCHANNEL10XPIPERXCHARISK(xpipe10_rx_charisk),
      .IFPSCPMCHANNEL10XPIPERXDATA(xpipe10_rx_data),
      .IFPSCPMCHANNEL10XPIPERXDATAVALID(xpipe10_rx_datavalid),
      .IFPSCPMCHANNEL10XPIPERXELECIDLE(xpipe10_rx_elecidle),
      .IFPSCPMCHANNEL10XPIPERXSTARTBLOCK(xpipe10_rx_startblock),
      .IFPSCPMCHANNEL10XPIPERXSTATUS(xpipe10_rx_status),
      .IFPSCPMCHANNEL10XPIPERXSYNCHEADER(xpipe10_rx_syncheader),
      .IFPSCPMCHANNEL10XPIPERXVALID(xpipe10_rx_valid),
	  .IFPSCPMCHANNEL11XPIPEPHYSTATUS(xpipe11_phystatus),
      .IFPSCPMCHANNEL11XPIPERXCHARISK(xpipe11_rx_charisk),
      .IFPSCPMCHANNEL11XPIPERXDATA(xpipe11_rx_data),
      .IFPSCPMCHANNEL11XPIPERXDATAVALID(xpipe11_rx_datavalid),
      .IFPSCPMCHANNEL11XPIPERXELECIDLE(xpipe11_rx_elecidle),
      .IFPSCPMCHANNEL11XPIPERXSTARTBLOCK(xpipe11_rx_startblock),
      .IFPSCPMCHANNEL11XPIPERXSTATUS(xpipe11_rx_status),
      .IFPSCPMCHANNEL11XPIPERXSYNCHEADER(xpipe11_rx_syncheader),
      .IFPSCPMCHANNEL11XPIPERXVALID(xpipe11_rx_valid),
	  .IFPSCPMCHANNEL12XPIPEPHYSTATUS(xpipe12_phystatus),
      .IFPSCPMCHANNEL12XPIPERXCHARISK(xpipe12_rx_charisk),
      .IFPSCPMCHANNEL12XPIPERXDATA(xpipe12_rx_data),
      .IFPSCPMCHANNEL12XPIPERXDATAVALID(xpipe12_rx_datavalid),
      .IFPSCPMCHANNEL12XPIPERXELECIDLE(xpipe12_rx_elecidle),
      .IFPSCPMCHANNEL12XPIPERXSTARTBLOCK(xpipe12_rx_startblock),
      .IFPSCPMCHANNEL12XPIPERXSTATUS(xpipe12_rx_status),
      .IFPSCPMCHANNEL12XPIPERXSYNCHEADER(xpipe12_rx_syncheader),
      .IFPSCPMCHANNEL12XPIPERXVALID(xpipe12_rx_valid), 
   	  .IFPSCPMCHANNEL13XPIPEPHYSTATUS(xpipe13_phystatus),
      .IFPSCPMCHANNEL13XPIPERXCHARISK(xpipe13_rx_charisk),
      .IFPSCPMCHANNEL13XPIPERXDATA(xpipe13_rx_data),
      .IFPSCPMCHANNEL13XPIPERXDATAVALID(xpipe13_rx_datavalid),
      .IFPSCPMCHANNEL13XPIPERXELECIDLE(xpipe13_rx_elecidle),
      .IFPSCPMCHANNEL13XPIPERXSTARTBLOCK(xpipe13_rx_startblock),
      .IFPSCPMCHANNEL13XPIPERXSTATUS(xpipe13_rx_status),
      .IFPSCPMCHANNEL13XPIPERXSYNCHEADER(xpipe13_rx_syncheader),
      .IFPSCPMCHANNEL13XPIPERXVALID(xpipe13_rx_valid),
      .IFPSCPMCHANNEL14XPIPEPHYSTATUS(xpipe14_phystatus),
      .IFPSCPMCHANNEL14XPIPERXCHARISK(xpipe14_rx_charisk),
      .IFPSCPMCHANNEL14XPIPERXDATA(xpipe14_rx_data),
      .IFPSCPMCHANNEL14XPIPERXDATAVALID(xpipe14_rx_datavalid),
      .IFPSCPMCHANNEL14XPIPERXELECIDLE(xpipe14_rx_elecidle),
      .IFPSCPMCHANNEL14XPIPERXSTARTBLOCK(xpipe14_rx_startblock),
      .IFPSCPMCHANNEL14XPIPERXSTATUS(xpipe14_rx_status),
      .IFPSCPMCHANNEL14XPIPERXSYNCHEADER(xpipe14_rx_syncheader),
      .IFPSCPMCHANNEL14XPIPERXVALID(xpipe14_rx_valid),
	  .IFPSCPMCHANNEL15XPIPEPHYSTATUS(xpipe15_phystatus),
      .IFPSCPMCHANNEL15XPIPERXCHARISK(xpipe15_rx_charisk),
      .IFPSCPMCHANNEL15XPIPERXDATA(xpipe15_rx_data),
      .IFPSCPMCHANNEL15XPIPERXDATAVALID(xpipe15_rx_datavalid),
      .IFPSCPMCHANNEL15XPIPERXELECIDLE(xpipe15_rx_elecidle),
      .IFPSCPMCHANNEL15XPIPERXSTARTBLOCK(xpipe15_rx_startblock),
      .IFPSCPMCHANNEL15XPIPERXSTATUS(xpipe15_rx_status),
      .IFPSCPMCHANNEL15XPIPERXSYNCHEADER(xpipe15_rx_syncheader),
      .IFPSCPMCHANNEL15XPIPERXVALID(xpipe15_rx_valid),
      .IFPSCPMCHANNEL1XPIPEPHYSTATUS(xpipe1_phystatus),
      .IFPSCPMCHANNEL1XPIPERXCHARISK(xpipe1_rx_charisk),
      .IFPSCPMCHANNEL1XPIPERXDATA(xpipe1_rx_data),
      .IFPSCPMCHANNEL1XPIPERXDATAVALID(xpipe1_rx_datavalid),
      .IFPSCPMCHANNEL1XPIPERXELECIDLE(xpipe1_rx_elecidle),
      .IFPSCPMCHANNEL1XPIPERXSTARTBLOCK(xpipe1_rx_startblock),
      .IFPSCPMCHANNEL1XPIPERXSTATUS(xpipe1_rx_status),
      .IFPSCPMCHANNEL1XPIPERXSYNCHEADER(xpipe1_rx_syncheader),
      .IFPSCPMCHANNEL1XPIPERXVALID(xpipe1_rx_valid),
      .IFPSCPMCHANNEL2XPIPEPHYSTATUS(xpipe2_phystatus),
      .IFPSCPMCHANNEL2XPIPERXCHARISK(xpipe2_rx_charisk),
      .IFPSCPMCHANNEL2XPIPERXDATA(xpipe2_rx_data),
      .IFPSCPMCHANNEL2XPIPERXDATAVALID(xpipe2_rx_datavalid),
      .IFPSCPMCHANNEL2XPIPERXELECIDLE(xpipe2_rx_elecidle),
      .IFPSCPMCHANNEL2XPIPERXSTARTBLOCK(xpipe2_rx_startblock),
      .IFPSCPMCHANNEL2XPIPERXSTATUS(xpipe2_rx_status),
      .IFPSCPMCHANNEL2XPIPERXSYNCHEADER(xpipe2_rx_syncheader),
      .IFPSCPMCHANNEL2XPIPERXVALID(xpipe2_rx_valid),
      .IFPSCPMCHANNEL3XPIPEPHYSTATUS(xpipe3_phystatus),
      .IFPSCPMCHANNEL3XPIPERXCHARISK(xpipe3_rx_charisk),
      .IFPSCPMCHANNEL3XPIPERXDATA(xpipe3_rx_data),
      .IFPSCPMCHANNEL3XPIPERXDATAVALID(xpipe3_rx_datavalid),
      .IFPSCPMCHANNEL3XPIPERXELECIDLE(xpipe3_rx_elecidle),
      .IFPSCPMCHANNEL3XPIPERXSTARTBLOCK(xpipe3_rx_startblock),
      .IFPSCPMCHANNEL3XPIPERXSTATUS(xpipe3_rx_status),
      .IFPSCPMCHANNEL3XPIPERXSYNCHEADER(xpipe3_rx_syncheader),
      .IFPSCPMCHANNEL3XPIPERXVALID(xpipe3_rx_valid),
      .IFPSCPMCHANNEL4XPIPEPHYSTATUS(xpipe4_phystatus),
      .IFPSCPMCHANNEL4XPIPERXCHARISK(xpipe4_rx_charisk),
      .IFPSCPMCHANNEL4XPIPERXDATA(xpipe4_rx_data),
      .IFPSCPMCHANNEL4XPIPERXDATAVALID(xpipe4_rx_datavalid),
      .IFPSCPMCHANNEL4XPIPERXELECIDLE(xpipe4_rx_elecidle),
      .IFPSCPMCHANNEL4XPIPERXSTARTBLOCK(xpipe4_rx_startblock),
      .IFPSCPMCHANNEL4XPIPERXSTATUS(xpipe4_rx_status),
      .IFPSCPMCHANNEL4XPIPERXSYNCHEADER(xpipe4_rx_syncheader),
      .IFPSCPMCHANNEL4XPIPERXVALID(xpipe4_rx_valid),
      .IFPSCPMCHANNEL5XPIPEPHYSTATUS(xpipe5_phystatus),
      .IFPSCPMCHANNEL5XPIPERXCHARISK(xpipe5_rx_charisk),
      .IFPSCPMCHANNEL5XPIPERXDATA(xpipe5_rx_data),
      .IFPSCPMCHANNEL5XPIPERXDATAVALID(xpipe5_rx_datavalid),
      .IFPSCPMCHANNEL5XPIPERXELECIDLE(xpipe5_rx_elecidle),
      .IFPSCPMCHANNEL5XPIPERXSTARTBLOCK(xpipe5_rx_startblock),
      .IFPSCPMCHANNEL5XPIPERXSTATUS(xpipe5_rx_status),
      .IFPSCPMCHANNEL5XPIPERXSYNCHEADER(xpipe5_rx_syncheader),
      .IFPSCPMCHANNEL5XPIPERXVALID(xpipe5_rx_valid),
      .IFPSCPMCHANNEL6XPIPEPHYSTATUS(xpipe6_phystatus),
      .IFPSCPMCHANNEL6XPIPERXCHARISK(xpipe6_rx_charisk),
      .IFPSCPMCHANNEL6XPIPERXDATA(xpipe6_rx_data),
      .IFPSCPMCHANNEL6XPIPERXDATAVALID(xpipe6_rx_datavalid),
      .IFPSCPMCHANNEL6XPIPERXELECIDLE(xpipe6_rx_elecidle),
      .IFPSCPMCHANNEL6XPIPERXSTARTBLOCK(xpipe6_rx_startblock),
      .IFPSCPMCHANNEL6XPIPERXSTATUS(xpipe6_rx_status),
      .IFPSCPMCHANNEL6XPIPERXSYNCHEADER(xpipe6_rx_syncheader),
      .IFPSCPMCHANNEL6XPIPERXVALID(xpipe6_rx_valid),
      .IFPSCPMCHANNEL7XPIPEPHYSTATUS(xpipe7_phystatus),
      .IFPSCPMCHANNEL7XPIPERXCHARISK(xpipe7_rx_charisk),
      .IFPSCPMCHANNEL7XPIPERXDATA(xpipe7_rx_data),
      .IFPSCPMCHANNEL7XPIPERXDATAVALID(xpipe7_rx_datavalid),
      .IFPSCPMCHANNEL7XPIPERXELECIDLE(xpipe7_rx_elecidle),
      .IFPSCPMCHANNEL7XPIPERXSTARTBLOCK(xpipe7_rx_startblock),
      .IFPSCPMCHANNEL7XPIPERXSTATUS(xpipe7_rx_status),
      .IFPSCPMCHANNEL7XPIPERXSYNCHEADER(xpipe7_rx_syncheader),
      .IFPSCPMCHANNEL7XPIPERXVALID(xpipe7_rx_valid),
      .IFPSCPMCHANNEL8XPIPEPHYSTATUS(xpipe8_phystatus),
      .IFPSCPMCHANNEL8XPIPERXCHARISK(xpipe8_rx_charisk),
      .IFPSCPMCHANNEL8XPIPERXDATA(xpipe8_rx_data),
      .IFPSCPMCHANNEL8XPIPERXDATAVALID(xpipe8_rx_datavalid),
      .IFPSCPMCHANNEL8XPIPERXELECIDLE(xpipe8_rx_elecidle),
      .IFPSCPMCHANNEL8XPIPERXSTARTBLOCK(xpipe8_rx_startblock),
      .IFPSCPMCHANNEL8XPIPERXSTATUS(xpipe8_rx_status),
      .IFPSCPMCHANNEL8XPIPERXSYNCHEADER(xpipe8_rx_syncheader),
      .IFPSCPMCHANNEL8XPIPERXVALID(xpipe8_rx_valid),
      .IFPSCPMCHANNEL9XPIPEPHYSTATUS(xpipe9_phystatus),
      .IFPSCPMCHANNEL9XPIPERXCHARISK(xpipe9_rx_charisk),
      .IFPSCPMCHANNEL9XPIPERXDATA(xpipe9_rx_data),
      .IFPSCPMCHANNEL9XPIPERXDATAVALID(xpipe9_rx_datavalid),
      .IFPSCPMCHANNEL9XPIPERXELECIDLE(xpipe9_rx_elecidle),
      .IFPSCPMCHANNEL9XPIPERXSTARTBLOCK(xpipe9_rx_startblock),
      .IFPSCPMCHANNEL9XPIPERXSTATUS(xpipe9_rx_status),
      .IFPSCPMCHANNEL9XPIPERXSYNCHEADER(xpipe9_rx_syncheader),
      .IFPSCPMCHANNEL9XPIPERXVALID(xpipe9_rx_valid),
	  
      .IFPSCPMHSDPCHANNEL0XPIPERXDATAVALID(hsdp_xpipe0_rx_datavalid),
      .IFPSCPMHSDPCHANNEL0XPIPERXHEADER(hsdp_xpipe0_rx_header),
      .IFPSCPMHSDPCHANNEL0XPIPERXHEADERVALID(hsdp_xpipe0_rx_headervalid),
      .IFPSCPMHSDPCHANNEL0XPIPERXRESETDONE(hsdp_xpipe0_rx_resetdone),
      .IFPSCPMHSDPCHANNEL0XPIPETXRESETDONE(hsdp_xpipe0_tx_resetdone),
      .IFPSCPMHSDPCHANNEL1XPIPERXDATAVALID(hsdp_xpipe1_rx_datavalid),
      .IFPSCPMHSDPCHANNEL1XPIPERXHEADER(hsdp_xpipe1_rx_header),
      .IFPSCPMHSDPCHANNEL1XPIPERXHEADERVALID(hsdp_xpipe1_rx_headervalid),
      .IFPSCPMHSDPCHANNEL1XPIPERXRESETDONE(hsdp_xpipe1_rx_resetdone),
      .IFPSCPMHSDPCHANNEL1XPIPETXRESETDONE(hsdp_xpipe1_tx_resetdone),
      .IFPSCPMHSDPCHANNEL2XPIPERXDATAVALID(hsdp_xpipe2_rx_datavalid),
      .IFPSCPMHSDPCHANNEL2XPIPERXHEADER(hsdp_xpipe2_rx_header),
      .IFPSCPMHSDPCHANNEL2XPIPERXHEADERVALID(hsdp_xpipe2_rx_headervalid),
      .IFPSCPMHSDPCHANNEL2XPIPERXRESETDONE(hsdp_xpipe2_rx_resetdone),
      .IFPSCPMHSDPCHANNEL2XPIPETXRESETDONE(hsdp_xpipe2_tx_resetdone),       
	       
      .IFPSCPMHSDPLINKXPIPEGTRXOUTCLK(hsdp_gt_rxoutclk),
      .IFPSCPMINTQUADXPIPEPHYREADYTOBOT(phy_ready_tobot),
      .IFPSCPMLINK0XPIPEBUFGTCE(link0_xpipe_bufgtce),
      .IFPSCPMLINK0XPIPEBUFGTCEMASK(link0_xpipe_bufgtcemask),
      .IFPSCPMLINK0XPIPEBUFGTDIV(link0_xpipe_bufgtdiv),
      .IFPSCPMLINK0XPIPEBUFGTRST(link0_xpipe_bufgtrst),
      .IFPSCPMLINK0XPIPEBUFGTRSTMASK(link0_xpipe_bufgtrstmask),
      .IFPSCPMLINK0XPIPEGTOUTCLK(link0_xpipe_gtoutclk),
      .IFPSCPMLINK0XPIPEPHYREADY(link0_xpipe_phyready),
      .IFPSCPMLINK1XPIPEBUFGTCE(link1_xpipe_bufgtce),
      .IFPSCPMLINK1XPIPEBUFGTCEMASK(link1_xpipe_bufgtcemask),
      .IFPSCPMLINK1XPIPEBUFGTDIV(link1_xpipe_bufgtdiv),
      .IFPSCPMLINK1XPIPEBUFGTRST(link1_xpipe_bufgtrst),
      .IFPSCPMLINK1XPIPEBUFGTRSTMASK(link1_xpipe_bufgtrstmask),
      .IFPSCPMLINK1XPIPEGTOUTCLK(link1_xpipe_gtoutclk),
      .IFPSCPMLINK1XPIPEPHYREADY(link1_xpipe_phyready),
      .IFPSCPMQUAD0XPIPERXMARGINREQACK(xpipe_q0_rxmargin_req_ack),
      .IFPSCPMQUAD0XPIPERXMARGINRESCMD(xpipe_q0_rxmargin_res_cmd),
      .IFPSCPMQUAD0XPIPERXMARGINRESLANENUM(xpipe_q0_rxmargin_res_lanenum),
      .IFPSCPMQUAD0XPIPERXMARGINRESPAYLOAD(xpipe_q0_rxmargin_res_payload),
      .IFPSCPMQUAD0XPIPERXMARGINRESREQ(xpipe_q0_rxmargin_res_req),
      .IFPSCPMQUAD1XPIPERXMARGINREQACK(xpipe_q1_rxmargin_req_ack),
      .IFPSCPMQUAD1XPIPERXMARGINRESCMD(xpipe_q1_rxmargin_res_cmd),
      .IFPSCPMQUAD1XPIPERXMARGINRESLANENUM(xpipe_q1_rxmargin_res_lanenum),
      .IFPSCPMQUAD1XPIPERXMARGINRESPAYLOAD(xpipe_q1_rxmargin_res_payload),
      .IFPSCPMQUAD1XPIPERXMARGINRESREQ(xpipe_q1_rxmargin_res_req),
      .IFPSCPMQUAD2XPIPERXMARGINREQACK(xpipe_q2_rxmargin_req_ack),
      .IFPSCPMQUAD2XPIPERXMARGINRESCMD(xpipe_q2_rxmargin_res_cmd),
      .IFPSCPMQUAD2XPIPERXMARGINRESLANENUM(xpipe_q2_rxmargin_res_lanenum),
      .IFPSCPMQUAD2XPIPERXMARGINRESPAYLOAD(xpipe_q2_rxmargin_res_payload),
      .IFPSCPMQUAD2XPIPERXMARGINRESREQ(xpipe_q2_rxmargin_res_req),
      .IFPSCPMQUAD3XPIPERXMARGINREQACK(xpipe_q3_rxmargin_req_ack),
      .IFPSCPMQUAD3XPIPERXMARGINRESCMD(xpipe_q3_rxmargin_res_cmd),
      .IFPSCPMQUAD3XPIPERXMARGINRESLANENUM(xpipe_q3_rxmargin_res_lanenum),
      .IFPSCPMQUAD3XPIPERXMARGINRESPAYLOAD(xpipe_q3_rxmargin_res_payload),
      .IFPSCPMQUAD3XPIPERXMARGINRESREQ(xpipe_q3_rxmargin_res_req),
      .IFPSCPMCHANNEL0XPIPEPOWERDOWN(xpipe0_powerdown),
      .IFPSCPMCHANNEL0XPIPERXPOLARITY(xpipe0_rx_polarity),
      .IFPSCPMCHANNEL0XPIPERXTERMINATION(xpipe0_rx_termination),
      .IFPSCPMCHANNEL0XPIPETXCHARISK(xpipe0_tx_charisk),
      .IFPSCPMCHANNEL0XPIPETXCOMPLIANCE(xpipe0_tx_compliance),
      .IFPSCPMCHANNEL0XPIPETXDATA(xpipe0_tx_data),
      .IFPSCPMCHANNEL0XPIPETXDATAVALID(xpipe0_tx_datavalid),
      .IFPSCPMCHANNEL0XPIPETXDEEMPH(xpipe0_tx_deemph),
      .IFPSCPMCHANNEL0XPIPETXDETECTRXLOOPBACK(xpipe0_tx_detectrxloopback),
      .IFPSCPMCHANNEL0XPIPETXELECIDLE(xpipe0_tx_elecidle),
      .IFPSCPMCHANNEL0XPIPETXMAINCURSOR(xpipe0_tx_maincursor),
      .IFPSCPMCHANNEL0XPIPETXMARGIN(xpipe0_tx_margin),
      .IFPSCPMCHANNEL0XPIPETXPOSTCURSOR(xpipe0_tx_postcursor),
      .IFPSCPMCHANNEL0XPIPETXPRECURSOR(xpipe0_tx_precursor),
      .IFPSCPMCHANNEL0XPIPETXSTARTBLOCK(xpipe0_tx_startblock),
      .IFPSCPMCHANNEL0XPIPETXSWING(xpipe0_tx_swing),
      .IFPSCPMCHANNEL0XPIPETXSYNCHEADER(xpipe0_tx_syncheader),
      .IFPSCPMCHANNEL10XPIPEPOWERDOWN(xpipe10_powerdown),
      .IFPSCPMCHANNEL10XPIPERXPOLARITY(xpipe10_rx_polarity),
      .IFPSCPMCHANNEL10XPIPERXTERMINATION(xpipe10_rx_termination),
      .IFPSCPMCHANNEL10XPIPETXCHARISK(xpipe10_tx_charisk),
      .IFPSCPMCHANNEL10XPIPETXCOMPLIANCE(xpipe10_tx_compliance),
      .IFPSCPMCHANNEL10XPIPETXDATA(xpipe10_tx_data),
      .IFPSCPMCHANNEL10XPIPETXDATAVALID(xpipe10_tx_datavalid),
      .IFPSCPMCHANNEL10XPIPETXDEEMPH(xpipe10_tx_deemph),
      .IFPSCPMCHANNEL10XPIPETXDETECTRXLOOPBACK(xpipe10_tx_detectrxloopback),
      .IFPSCPMCHANNEL10XPIPETXELECIDLE(xpipe10_tx_elecidle),
      .IFPSCPMCHANNEL10XPIPETXMAINCURSOR(xpipe10_tx_maincursor),
      .IFPSCPMCHANNEL10XPIPETXMARGIN(xpipe10_tx_margin),
      .IFPSCPMCHANNEL10XPIPETXPOSTCURSOR(xpipe10_tx_postcursor),
      .IFPSCPMCHANNEL10XPIPETXPRECURSOR(xpipe10_tx_precursor),
      .IFPSCPMCHANNEL10XPIPETXSTARTBLOCK(xpipe10_tx_startblock),
      .IFPSCPMCHANNEL10XPIPETXSWING(xpipe10_tx_swing),
      .IFPSCPMCHANNEL10XPIPETXSYNCHEADER(xpipe10_tx_syncheader),   
      .IFPSCPMCHANNEL11XPIPEPOWERDOWN(xpipe11_powerdown),
      .IFPSCPMCHANNEL11XPIPERXPOLARITY(xpipe11_rx_polarity),
      .IFPSCPMCHANNEL11XPIPERXTERMINATION(xpipe11_rx_termination),
      .IFPSCPMCHANNEL11XPIPETXCHARISK(xpipe11_tx_charisk),
      .IFPSCPMCHANNEL11XPIPETXCOMPLIANCE(xpipe11_tx_compliance),
      .IFPSCPMCHANNEL11XPIPETXDATA(xpipe11_tx_data),
      .IFPSCPMCHANNEL11XPIPETXDATAVALID(xpipe11_tx_datavalid),
      .IFPSCPMCHANNEL11XPIPETXDEEMPH(xpipe11_tx_deemph),
      .IFPSCPMCHANNEL11XPIPETXDETECTRXLOOPBACK(xpipe11_tx_detectrxloopback),
      .IFPSCPMCHANNEL11XPIPETXELECIDLE(xpipe11_tx_elecidle),
      .IFPSCPMCHANNEL11XPIPETXMAINCURSOR(xpipe11_tx_maincursor),
      .IFPSCPMCHANNEL11XPIPETXMARGIN(xpipe11_tx_margin),
      .IFPSCPMCHANNEL11XPIPETXPOSTCURSOR(xpipe11_tx_postcursor),
      .IFPSCPMCHANNEL11XPIPETXPRECURSOR(xpipe11_tx_precursor),
      .IFPSCPMCHANNEL11XPIPETXSTARTBLOCK(xpipe11_tx_startblock),
      .IFPSCPMCHANNEL11XPIPETXSWING(xpipe11_tx_swing),
      .IFPSCPMCHANNEL11XPIPETXSYNCHEADER(xpipe11_tx_syncheader), 
      .IFPSCPMCHANNEL12XPIPEPOWERDOWN(xpipe12_powerdown),
      .IFPSCPMCHANNEL12XPIPERXPOLARITY(xpipe12_rx_polarity),
      .IFPSCPMCHANNEL12XPIPERXTERMINATION(xpipe12_rx_termination),
      .IFPSCPMCHANNEL12XPIPETXCHARISK(xpipe12_tx_charisk),
      .IFPSCPMCHANNEL12XPIPETXCOMPLIANCE(xpipe12_tx_compliance),
      .IFPSCPMCHANNEL12XPIPETXDATA(xpipe12_tx_data),
      .IFPSCPMCHANNEL12XPIPETXDATAVALID(xpipe12_tx_datavalid),
      .IFPSCPMCHANNEL12XPIPETXDEEMPH(xpipe12_tx_deemph),
      .IFPSCPMCHANNEL12XPIPETXDETECTRXLOOPBACK(xpipe12_tx_detectrxloopback),
      .IFPSCPMCHANNEL12XPIPETXELECIDLE(xpipe12_tx_elecidle),
      .IFPSCPMCHANNEL12XPIPETXMAINCURSOR(xpipe12_tx_maincursor),
      .IFPSCPMCHANNEL12XPIPETXMARGIN(xpipe12_tx_margin),
      .IFPSCPMCHANNEL12XPIPETXPOSTCURSOR(xpipe12_tx_postcursor),
      .IFPSCPMCHANNEL12XPIPETXPRECURSOR(xpipe12_tx_precursor),
      .IFPSCPMCHANNEL12XPIPETXSTARTBLOCK(xpipe12_tx_startblock),
      .IFPSCPMCHANNEL12XPIPETXSWING(xpipe12_tx_swing),
      .IFPSCPMCHANNEL12XPIPETXSYNCHEADER(xpipe12_tx_syncheader), 
      .IFPSCPMCHANNEL13XPIPEPOWERDOWN(xpipe13_powerdown),
      .IFPSCPMCHANNEL13XPIPERXPOLARITY(xpipe13_rx_polarity),
      .IFPSCPMCHANNEL13XPIPERXTERMINATION(xpipe13_rx_termination),
      .IFPSCPMCHANNEL13XPIPETXCHARISK(xpipe13_tx_charisk),
      .IFPSCPMCHANNEL13XPIPETXCOMPLIANCE(xpipe13_tx_compliance),
      .IFPSCPMCHANNEL13XPIPETXDATA(xpipe13_tx_data),
      .IFPSCPMCHANNEL13XPIPETXDATAVALID(xpipe13_tx_datavalid),
      .IFPSCPMCHANNEL13XPIPETXDEEMPH(xpipe13_tx_deemph),
      .IFPSCPMCHANNEL13XPIPETXDETECTRXLOOPBACK(xpipe13_tx_detectrxloopback),
      .IFPSCPMCHANNEL13XPIPETXELECIDLE(xpipe13_tx_elecidle),
      .IFPSCPMCHANNEL13XPIPETXMAINCURSOR(xpipe13_tx_maincursor),
      .IFPSCPMCHANNEL13XPIPETXMARGIN(xpipe13_tx_margin),
      .IFPSCPMCHANNEL13XPIPETXPOSTCURSOR(xpipe13_tx_postcursor),
      .IFPSCPMCHANNEL13XPIPETXPRECURSOR(xpipe13_tx_precursor),
      .IFPSCPMCHANNEL13XPIPETXSTARTBLOCK(xpipe13_tx_startblock),
      .IFPSCPMCHANNEL13XPIPETXSWING(xpipe13_tx_swing),
      .IFPSCPMCHANNEL13XPIPETXSYNCHEADER(xpipe13_tx_syncheader), 
      .IFPSCPMCHANNEL14XPIPEPOWERDOWN(xpipe14_powerdown),
      .IFPSCPMCHANNEL14XPIPERXPOLARITY(xpipe14_rx_polarity),
      .IFPSCPMCHANNEL14XPIPERXTERMINATION(xpipe14_rx_termination),
      .IFPSCPMCHANNEL14XPIPETXCHARISK(xpipe14_tx_charisk),
      .IFPSCPMCHANNEL14XPIPETXCOMPLIANCE(xpipe14_tx_compliance),
      .IFPSCPMCHANNEL14XPIPETXDATA(xpipe14_tx_data),
      .IFPSCPMCHANNEL14XPIPETXDATAVALID(xpipe14_tx_datavalid),
      .IFPSCPMCHANNEL14XPIPETXDEEMPH(xpipe14_tx_deemph),
      .IFPSCPMCHANNEL14XPIPETXDETECTRXLOOPBACK(xpipe14_tx_detectrxloopback),
      .IFPSCPMCHANNEL14XPIPETXELECIDLE(xpipe14_tx_elecidle),
      .IFPSCPMCHANNEL14XPIPETXMAINCURSOR(xpipe14_tx_maincursor),
      .IFPSCPMCHANNEL14XPIPETXMARGIN(xpipe14_tx_margin),
      .IFPSCPMCHANNEL14XPIPETXPOSTCURSOR(xpipe14_tx_postcursor),
      .IFPSCPMCHANNEL14XPIPETXPRECURSOR(xpipe14_tx_precursor),
      .IFPSCPMCHANNEL14XPIPETXSTARTBLOCK(xpipe14_tx_startblock),
      .IFPSCPMCHANNEL14XPIPETXSWING(xpipe14_tx_swing),
      .IFPSCPMCHANNEL14XPIPETXSYNCHEADER(xpipe14_tx_syncheader), 
      .IFPSCPMCHANNEL15XPIPEPOWERDOWN(xpipe15_powerdown),
      .IFPSCPMCHANNEL15XPIPERXPOLARITY(xpipe15_rx_polarity),
      .IFPSCPMCHANNEL15XPIPERXTERMINATION(xpipe15_rx_termination),
      .IFPSCPMCHANNEL15XPIPETXCHARISK(xpipe15_tx_charisk),
      .IFPSCPMCHANNEL15XPIPETXCOMPLIANCE(xpipe15_tx_compliance),
      .IFPSCPMCHANNEL15XPIPETXDATA(xpipe15_tx_data),
      .IFPSCPMCHANNEL15XPIPETXDATAVALID(xpipe15_tx_datavalid),
      .IFPSCPMCHANNEL15XPIPETXDEEMPH(xpipe15_tx_deemph),
      .IFPSCPMCHANNEL15XPIPETXDETECTRXLOOPBACK(xpipe15_tx_detectrxloopback),
      .IFPSCPMCHANNEL15XPIPETXELECIDLE(xpipe15_tx_elecidle),
      .IFPSCPMCHANNEL15XPIPETXMAINCURSOR(xpipe15_tx_maincursor),
      .IFPSCPMCHANNEL15XPIPETXMARGIN(xpipe15_tx_margin),
      .IFPSCPMCHANNEL15XPIPETXPOSTCURSOR(xpipe15_tx_postcursor),
      .IFPSCPMCHANNEL15XPIPETXPRECURSOR(xpipe15_tx_precursor),
      .IFPSCPMCHANNEL15XPIPETXSTARTBLOCK(xpipe15_tx_startblock),
      .IFPSCPMCHANNEL15XPIPETXSWING(xpipe15_tx_swing),
      .IFPSCPMCHANNEL15XPIPETXSYNCHEADER(xpipe15_tx_syncheader), 
      .IFPSCPMCHANNEL1XPIPEPOWERDOWN(xpipe1_powerdown),
      .IFPSCPMCHANNEL1XPIPERXPOLARITY(xpipe1_rx_polarity),
      .IFPSCPMCHANNEL1XPIPERXTERMINATION(xpipe1_rx_termination),
      .IFPSCPMCHANNEL1XPIPETXCHARISK(xpipe1_tx_charisk),
      .IFPSCPMCHANNEL1XPIPETXCOMPLIANCE(xpipe1_tx_compliance),
      .IFPSCPMCHANNEL1XPIPETXDATA(xpipe1_tx_data),
      .IFPSCPMCHANNEL1XPIPETXDATAVALID(xpipe1_tx_datavalid),
      .IFPSCPMCHANNEL1XPIPETXDEEMPH(xpipe1_tx_deemph),
      .IFPSCPMCHANNEL1XPIPETXDETECTRXLOOPBACK(xpipe1_tx_detectrxloopback),
      .IFPSCPMCHANNEL1XPIPETXELECIDLE(xpipe1_tx_elecidle),
      .IFPSCPMCHANNEL1XPIPETXMAINCURSOR(xpipe1_tx_maincursor),
      .IFPSCPMCHANNEL1XPIPETXMARGIN(xpipe1_tx_margin),
      .IFPSCPMCHANNEL1XPIPETXPOSTCURSOR(xpipe1_tx_postcursor),
      .IFPSCPMCHANNEL1XPIPETXPRECURSOR(xpipe1_tx_precursor),
      .IFPSCPMCHANNEL1XPIPETXSTARTBLOCK(xpipe1_tx_startblock),
      .IFPSCPMCHANNEL1XPIPETXSWING(xpipe1_tx_swing),
      .IFPSCPMCHANNEL1XPIPETXSYNCHEADER(xpipe1_tx_syncheader), 
      .IFPSCPMCHANNEL2XPIPEPOWERDOWN(xpipe2_powerdown),
      .IFPSCPMCHANNEL2XPIPERXPOLARITY(xpipe2_rx_polarity),
      .IFPSCPMCHANNEL2XPIPERXTERMINATION(xpipe2_rx_termination),
      .IFPSCPMCHANNEL2XPIPETXCHARISK(xpipe2_tx_charisk),
      .IFPSCPMCHANNEL2XPIPETXCOMPLIANCE(xpipe2_tx_compliance),
      .IFPSCPMCHANNEL2XPIPETXDATA(xpipe2_tx_data),
      .IFPSCPMCHANNEL2XPIPETXDATAVALID(xpipe2_tx_datavalid),
      .IFPSCPMCHANNEL2XPIPETXDEEMPH(xpipe2_tx_deemph),
      .IFPSCPMCHANNEL2XPIPETXDETECTRXLOOPBACK(xpipe2_tx_detectrxloopback),
      .IFPSCPMCHANNEL2XPIPETXELECIDLE(xpipe2_tx_elecidle),
      .IFPSCPMCHANNEL2XPIPETXMAINCURSOR(xpipe2_tx_maincursor),
      .IFPSCPMCHANNEL2XPIPETXMARGIN(xpipe2_tx_margin),
      .IFPSCPMCHANNEL2XPIPETXPOSTCURSOR(xpipe2_tx_postcursor),
      .IFPSCPMCHANNEL2XPIPETXPRECURSOR(xpipe2_tx_precursor),
      .IFPSCPMCHANNEL2XPIPETXSTARTBLOCK(xpipe2_tx_startblock),
      .IFPSCPMCHANNEL2XPIPETXSWING(xpipe2_tx_swing),
      .IFPSCPMCHANNEL2XPIPETXSYNCHEADER(xpipe2_tx_syncheader), 
      .IFPSCPMCHANNEL3XPIPEPOWERDOWN(xpipe3_powerdown),
      .IFPSCPMCHANNEL3XPIPERXPOLARITY(xpipe3_rx_polarity),
      .IFPSCPMCHANNEL3XPIPERXTERMINATION(xpipe3_rx_termination),
      .IFPSCPMCHANNEL3XPIPETXCHARISK(xpipe3_tx_charisk),
      .IFPSCPMCHANNEL3XPIPETXCOMPLIANCE(xpipe3_tx_compliance),
      .IFPSCPMCHANNEL3XPIPETXDATA(xpipe3_tx_data),
      .IFPSCPMCHANNEL3XPIPETXDATAVALID(xpipe3_tx_datavalid),
      .IFPSCPMCHANNEL3XPIPETXDEEMPH(xpipe3_tx_deemph),
      .IFPSCPMCHANNEL3XPIPETXDETECTRXLOOPBACK(xpipe3_tx_detectrxloopback),
      .IFPSCPMCHANNEL3XPIPETXELECIDLE(xpipe3_tx_elecidle),
      .IFPSCPMCHANNEL3XPIPETXMAINCURSOR(xpipe3_tx_maincursor),
      .IFPSCPMCHANNEL3XPIPETXMARGIN(xpipe3_tx_margin),
      .IFPSCPMCHANNEL3XPIPETXPOSTCURSOR(xpipe3_tx_postcursor),
      .IFPSCPMCHANNEL3XPIPETXPRECURSOR(xpipe3_tx_precursor),
      .IFPSCPMCHANNEL3XPIPETXSTARTBLOCK(xpipe3_tx_startblock),
      .IFPSCPMCHANNEL3XPIPETXSWING(xpipe3_tx_swing),
      .IFPSCPMCHANNEL3XPIPETXSYNCHEADER(xpipe3_tx_syncheader), 
      .IFPSCPMCHANNEL4XPIPEPOWERDOWN(xpipe4_powerdown),
      .IFPSCPMCHANNEL4XPIPERXPOLARITY(xpipe4_rx_polarity),
      .IFPSCPMCHANNEL4XPIPERXTERMINATION(xpipe4_rx_termination),
      .IFPSCPMCHANNEL4XPIPETXCHARISK(xpipe4_tx_charisk),
      .IFPSCPMCHANNEL4XPIPETXCOMPLIANCE(xpipe4_tx_compliance),
      .IFPSCPMCHANNEL4XPIPETXDATA(xpipe4_tx_data),
      .IFPSCPMCHANNEL4XPIPETXDATAVALID(xpipe4_tx_datavalid),
      .IFPSCPMCHANNEL4XPIPETXDEEMPH(xpipe4_tx_deemph),
      .IFPSCPMCHANNEL4XPIPETXDETECTRXLOOPBACK(xpipe4_tx_detectrxloopback),
      .IFPSCPMCHANNEL4XPIPETXELECIDLE(xpipe4_tx_elecidle),
      .IFPSCPMCHANNEL4XPIPETXMAINCURSOR(xpipe4_tx_maincursor),
      .IFPSCPMCHANNEL4XPIPETXMARGIN(xpipe4_tx_margin),
      .IFPSCPMCHANNEL4XPIPETXPOSTCURSOR(xpipe4_tx_postcursor),
      .IFPSCPMCHANNEL4XPIPETXPRECURSOR(xpipe4_tx_precursor),
      .IFPSCPMCHANNEL4XPIPETXSTARTBLOCK(xpipe4_tx_startblock),
      .IFPSCPMCHANNEL4XPIPETXSWING(xpipe4_tx_swing),
      .IFPSCPMCHANNEL4XPIPETXSYNCHEADER(xpipe4_tx_syncheader), 
      .IFPSCPMCHANNEL5XPIPEPOWERDOWN(xpipe5_powerdown),
      .IFPSCPMCHANNEL5XPIPERXPOLARITY(xpipe5_rx_polarity),
      .IFPSCPMCHANNEL5XPIPERXTERMINATION(xpipe5_rx_termination),
      .IFPSCPMCHANNEL5XPIPETXCHARISK(xpipe5_tx_charisk),
      .IFPSCPMCHANNEL5XPIPETXCOMPLIANCE(xpipe5_tx_compliance),
      .IFPSCPMCHANNEL5XPIPETXDATA(xpipe5_tx_data),
      .IFPSCPMCHANNEL5XPIPETXDATAVALID(xpipe5_tx_datavalid),
      .IFPSCPMCHANNEL5XPIPETXDEEMPH(xpipe5_tx_deemph),
      .IFPSCPMCHANNEL5XPIPETXDETECTRXLOOPBACK(xpipe5_tx_detectrxloopback),
      .IFPSCPMCHANNEL5XPIPETXELECIDLE(xpipe5_tx_elecidle),
      .IFPSCPMCHANNEL5XPIPETXMAINCURSOR(xpipe5_tx_maincursor),
      .IFPSCPMCHANNEL5XPIPETXMARGIN(xpipe5_tx_margin),
      .IFPSCPMCHANNEL5XPIPETXPOSTCURSOR(xpipe5_tx_postcursor),
      .IFPSCPMCHANNEL5XPIPETXPRECURSOR(xpipe5_tx_precursor),
      .IFPSCPMCHANNEL5XPIPETXSTARTBLOCK(xpipe5_tx_startblock),
      .IFPSCPMCHANNEL5XPIPETXSWING(xpipe5_tx_swing),
      .IFPSCPMCHANNEL5XPIPETXSYNCHEADER(xpipe5_tx_syncheader), 
      .IFPSCPMCHANNEL6XPIPEPOWERDOWN(xpipe6_powerdown),
      .IFPSCPMCHANNEL6XPIPERXPOLARITY(xpipe6_rx_polarity),
      .IFPSCPMCHANNEL6XPIPERXTERMINATION(xpipe6_rx_termination),
      .IFPSCPMCHANNEL6XPIPETXCHARISK(xpipe6_tx_charisk),
      .IFPSCPMCHANNEL6XPIPETXCOMPLIANCE(xpipe6_tx_compliance),
      .IFPSCPMCHANNEL6XPIPETXDATA(xpipe6_tx_data),
      .IFPSCPMCHANNEL6XPIPETXDATAVALID(xpipe6_tx_datavalid),
      .IFPSCPMCHANNEL6XPIPETXDEEMPH(xpipe6_tx_deemph),
      .IFPSCPMCHANNEL6XPIPETXDETECTRXLOOPBACK(xpipe6_tx_detectrxloopback),
      .IFPSCPMCHANNEL6XPIPETXELECIDLE(xpipe6_tx_elecidle),
      .IFPSCPMCHANNEL6XPIPETXMAINCURSOR(xpipe6_tx_maincursor),
      .IFPSCPMCHANNEL6XPIPETXMARGIN(xpipe6_tx_margin),
      .IFPSCPMCHANNEL6XPIPETXPOSTCURSOR(xpipe6_tx_postcursor),
      .IFPSCPMCHANNEL6XPIPETXPRECURSOR(xpipe6_tx_precursor),
      .IFPSCPMCHANNEL6XPIPETXSTARTBLOCK(xpipe6_tx_startblock),
      .IFPSCPMCHANNEL6XPIPETXSWING(xpipe6_tx_swing),
      .IFPSCPMCHANNEL6XPIPETXSYNCHEADER(xpipe6_tx_syncheader), 
      .IFPSCPMCHANNEL7XPIPEPOWERDOWN(xpipe7_powerdown),
      .IFPSCPMCHANNEL7XPIPERXPOLARITY(xpipe7_rx_polarity),
      .IFPSCPMCHANNEL7XPIPERXTERMINATION(xpipe7_rx_termination),
      .IFPSCPMCHANNEL7XPIPETXCHARISK(xpipe7_tx_charisk),
      .IFPSCPMCHANNEL7XPIPETXCOMPLIANCE(xpipe7_tx_compliance),
      .IFPSCPMCHANNEL7XPIPETXDATA(xpipe7_tx_data),
      .IFPSCPMCHANNEL7XPIPETXDATAVALID(xpipe7_tx_datavalid),
      .IFPSCPMCHANNEL7XPIPETXDEEMPH(xpipe7_tx_deemph),
      .IFPSCPMCHANNEL7XPIPETXDETECTRXLOOPBACK(xpipe7_tx_detectrxloopback),
      .IFPSCPMCHANNEL7XPIPETXELECIDLE(xpipe7_tx_elecidle),
      .IFPSCPMCHANNEL7XPIPETXMAINCURSOR(xpipe7_tx_maincursor),
      .IFPSCPMCHANNEL7XPIPETXMARGIN(xpipe7_tx_margin),
      .IFPSCPMCHANNEL7XPIPETXPOSTCURSOR(xpipe7_tx_postcursor),
      .IFPSCPMCHANNEL7XPIPETXPRECURSOR(xpipe7_tx_precursor),
      .IFPSCPMCHANNEL7XPIPETXSTARTBLOCK(xpipe7_tx_startblock),
      .IFPSCPMCHANNEL7XPIPETXSWING(xpipe7_tx_swing),
      .IFPSCPMCHANNEL7XPIPETXSYNCHEADER(xpipe7_tx_syncheader), 
      .IFPSCPMCHANNEL8XPIPEPOWERDOWN(xpipe8_powerdown),
      .IFPSCPMCHANNEL8XPIPERXPOLARITY(xpipe8_rx_polarity),
      .IFPSCPMCHANNEL8XPIPERXTERMINATION(xpipe8_rx_termination),
      .IFPSCPMCHANNEL8XPIPETXCHARISK(xpipe8_tx_charisk),
      .IFPSCPMCHANNEL8XPIPETXCOMPLIANCE(xpipe8_tx_compliance),
      .IFPSCPMCHANNEL8XPIPETXDATA(xpipe8_tx_data),
      .IFPSCPMCHANNEL8XPIPETXDATAVALID(xpipe8_tx_datavalid),
      .IFPSCPMCHANNEL8XPIPETXDEEMPH(xpipe8_tx_deemph),
      .IFPSCPMCHANNEL8XPIPETXDETECTRXLOOPBACK(xpipe8_tx_detectrxloopback),
      .IFPSCPMCHANNEL8XPIPETXELECIDLE(xpipe8_tx_elecidle),
      .IFPSCPMCHANNEL8XPIPETXMAINCURSOR(xpipe8_tx_maincursor),
      .IFPSCPMCHANNEL8XPIPETXMARGIN(xpipe8_tx_margin),
      .IFPSCPMCHANNEL8XPIPETXPOSTCURSOR(xpipe8_tx_postcursor),
      .IFPSCPMCHANNEL8XPIPETXPRECURSOR(xpipe8_tx_precursor),
      .IFPSCPMCHANNEL8XPIPETXSTARTBLOCK(xpipe8_tx_startblock),
      .IFPSCPMCHANNEL8XPIPETXSWING(xpipe8_tx_swing),
      .IFPSCPMCHANNEL8XPIPETXSYNCHEADER(xpipe8_tx_syncheader), 
      .IFPSCPMCHANNEL9XPIPEPOWERDOWN(xpipe9_powerdown),
      .IFPSCPMCHANNEL9XPIPERXPOLARITY(xpipe9_rx_polarity),
      .IFPSCPMCHANNEL9XPIPERXTERMINATION(xpipe9_rx_termination),
      .IFPSCPMCHANNEL9XPIPETXCHARISK(xpipe9_tx_charisk),
      .IFPSCPMCHANNEL9XPIPETXCOMPLIANCE(xpipe9_tx_compliance),
      .IFPSCPMCHANNEL9XPIPETXDATA(xpipe9_tx_data),
      .IFPSCPMCHANNEL9XPIPETXDATAVALID(xpipe9_tx_datavalid),
      .IFPSCPMCHANNEL9XPIPETXDEEMPH(xpipe9_tx_deemph),
      .IFPSCPMCHANNEL9XPIPETXDETECTRXLOOPBACK(xpipe9_tx_detectrxloopback),
      .IFPSCPMCHANNEL9XPIPETXELECIDLE(xpipe9_tx_elecidle),
      .IFPSCPMCHANNEL9XPIPETXMAINCURSOR(xpipe9_tx_maincursor),
      .IFPSCPMCHANNEL9XPIPETXMARGIN(xpipe9_tx_margin),
      .IFPSCPMCHANNEL9XPIPETXPOSTCURSOR(xpipe9_tx_postcursor),
      .IFPSCPMCHANNEL9XPIPETXPRECURSOR(xpipe9_tx_precursor),
      .IFPSCPMCHANNEL9XPIPETXSTARTBLOCK(xpipe9_tx_startblock),
      .IFPSCPMCHANNEL9XPIPETXSWING(xpipe9_tx_swing),
      .IFPSCPMCHANNEL9XPIPETXSYNCHEADER(xpipe9_tx_syncheader), 
      .IFPSCPMHSDPCHANNEL0XPIPERXGEARBOXSLIP(hsdp_xpipe0_rx_gearboxslip),
      .IFPSCPMHSDPCHANNEL0XPIPERXPCSRESET(hsdp_xpipe0_rx_pcsreset),
      .IFPSCPMHSDPCHANNEL0XPIPETXHEADER(hsdp_xpipe0_tx_header),
      .IFPSCPMHSDPCHANNEL0XPIPETXSEQUENCE(hsdp_xpipe0_tx_sequence),
      .IFPSCPMHSDPCHANNEL1XPIPERXGEARBOXSLIP(hsdp_xpipe1_rx_gearboxslip),
      .IFPSCPMHSDPCHANNEL1XPIPERXPCSRESET(hsdp_xpipe1_rx_pcsreset),
      .IFPSCPMHSDPCHANNEL1XPIPETXHEADER(hsdp_xpipe1_tx_header),
      .IFPSCPMHSDPCHANNEL1XPIPETXSEQUENCE(hsdp_xpipe1_tx_sequence),
      .IFPSCPMHSDPCHANNEL2XPIPERXGEARBOXSLIP(hsdp_xpipe2_rx_gearboxslip),
      .IFPSCPMHSDPCHANNEL2XPIPERXPCSRESET(hsdp_xpipe2_rx_pcsreset),
      .IFPSCPMHSDPCHANNEL2XPIPETXHEADER(hsdp_xpipe2_tx_header),
      .IFPSCPMHSDPCHANNEL2XPIPETXSEQUENCE(hsdp_xpipe2_tx_sequence),
      .IFPSCPMHSDPLINKXPIPEGTRXUSRCLK(hsdp_gt_txusrclk),
      .IFPSCPMINTQUADXPIPEPHYREADYFRBOT(phy_ready_frbot),
      .IFPSCPMLINK0XPIPEGTPIPECLK(link0_xpipe_gtpipeclk),
      .IFPSCPMLINK0XPIPEPCIELINKREACHTARGET(link0_xpipe_pcielinkreachtarget),
      .IFPSCPMLINK0XPIPEPCIELTSSMSTATE(link0_xpipe_pcieltssmstate),
      .IFPSCPMLINK0XPIPEPCIEPERSTN(link0_xpipe_pcieperstn),
      .IFPSCPMLINK0XPIPEPHYESMADAPTATIONSAVE(link0_xpipe_phyesmadaptationsave),
      .IFPSCPMLINK0XPIPEPIPERATE(link0_xpipe_piperate),
      .IFPSCPMLINK1XPIPEGTPIPECLK(link1_xpipe_gtpipeclk),
      .IFPSCPMLINK1XPIPEPCIELINKREACHTARGET(link1_xpipe_pcielinkreachtarget),
      .IFPSCPMLINK1XPIPEPCIELTSSMSTATE(link1_xpipe_pcieltssmstate),
      .IFPSCPMLINK1XPIPEPCIEPERSTN(link1_xpipe_pcieperstn),
      .IFPSCPMLINK1XPIPEPHYESMADAPTATIONSAVE(link1_xpipe_phyesmadaptationsave),
      .IFPSCPMLINK1XPIPEPIPERATE(link1_xpipe_piperate),
      .CPMOSCCLKDIV2(cpm_osc_clk_div2),
      .IFPSCPMCFGAXIARADDR(s_axi_cfg_araddr),
      .IFPSCPMCFGAXIARBURST(s_axi_cfg_arburst),
      .IFPSCPMCFGAXIARCACHE(s_axi_cfg_arcache),
      .IFPSCPMCFGAXIARID(s_axi_cfg_arid),
      .IFPSCPMCFGAXIARLEN(s_axi_cfg_arlen),
      .IFPSCPMCFGAXIARLOCK(s_axi_cfg_arlock),
      .IFPSCPMCFGAXIARPROT(s_axi_cfg_arprot),
      .IFPSCPMCFGAXIARQOS(s_axi_cfg_arqos),
      .IFPSCPMCFGAXIARREGION(s_axi_cfg_arregion),
      .IFPSCPMCFGAXIARSIZE(s_axi_cfg_arsize),
      .IFPSCPMCFGAXIARUSER(s_axi_cfg_aruser),
      .IFPSCPMCFGAXIARVALID(s_axi_cfg_arvalid),
      .IFPSCPMCFGAXIAWADDR(s_axi_cfg_awaddr),
      .IFPSCPMCFGAXIAWBURST(s_axi_cfg_awburst),
      .IFPSCPMCFGAXIAWCACHE(s_axi_cfg_awcache),
      .IFPSCPMCFGAXIAWID(s_axi_cfg_awid),
      .IFPSCPMCFGAXIAWLEN(s_axi_cfg_awlen),
      .IFPSCPMCFGAXIAWLOCK(s_axi_cfg_awlock),
      .IFPSCPMCFGAXIAWPROT(s_axi_cfg_awprot),
      .IFPSCPMCFGAXIAWQOS(s_axi_cfg_awqos),
      .IFPSCPMCFGAXIAWREGION(s_axi_cfg_awregion),
      .IFPSCPMCFGAXIAWSIZE(s_axi_cfg_awsize),
      .IFPSCPMCFGAXIAWUSER(s_axi_cfg_awuser),
      .IFPSCPMCFGAXIAWVALID(s_axi_cfg_awvalid),
      .IFPSCPMCFGAXIBREADY(s_axi_cfg_bready),
      .IFPSCPMCFGAXIRREADY(s_axi_cfg_rready),
      .IFPSCPMCFGAXIWDATA(s_axi_cfg_wdata),
      .IFPSCPMCFGAXIWID(s_axi_cfg_wid),
      .IFPSCPMCFGAXIWLAST(s_axi_cfg_wlast),
      .IFPSCPMCFGAXIWSTRB(s_axi_cfg_wstrb),
      .IFPSCPMCFGAXIWUSER(s_axi_cfg_wuser),
      .IFPSCPMCFGAXIWVALID(s_axi_cfg_wvalid),
      .IFPSCPMCFGAXIARREADY(s_axi_cfg_arready),
      .IFPSCPMCFGAXIAWREADY(s_axi_cfg_awready),
      .IFPSCPMCFGAXIBID(s_axi_cfg_bid),
      .IFPSCPMCFGAXIBRESP(s_axi_cfg_bresp),
      .IFPSCPMCFGAXIBUSER(s_axi_cfg_buser),
      .IFPSCPMCFGAXIBVALID(s_axi_cfg_bvalid),
      .IFPSCPMCFGAXIRDATA(s_axi_cfg_rdata),
      .IFPSCPMCFGAXIRID(s_axi_cfg_rid),
      .IFPSCPMCFGAXIRLAST(s_axi_cfg_rlast),
      .IFPSCPMCFGAXIRRESP(s_axi_cfg_rresp),
      .IFPSCPMCFGAXIRUSER(s_axi_cfg_ruser),
      .IFPSCPMCFGAXIRVALID(s_axi_cfg_rvalid),
      .IFPSCPMCFGAXIWREADY(s_axi_cfg_wready),

      .IFPSCPMPCIEAXIARREADY(s_axi_pcie_arready),
      .IFPSCPMPCIEAXIAWREADY(s_axi_pcie_awready),
      .IFPSCPMPCIEAXIBID(s_axi_pcie_bid),
      .IFPSCPMPCIEAXIBRESP(s_axi_pcie_bresp),
      .IFPSCPMPCIEAXIBUSER(s_axi_pcie_buser),
      .IFPSCPMPCIEAXIBVALID(s_axi_pcie_bvalid),
      .IFPSCPMPCIEAXIRDATA(s_axi_pcie_rdata),
      .IFPSCPMPCIEAXIRID(s_axi_pcie_rid),
      .IFPSCPMPCIEAXIRLAST(s_axi_pcie_rlast),
      .IFPSCPMPCIEAXIRRESP(s_axi_pcie_rresp),
      .IFPSCPMPCIEAXIRUSER(s_axi_pcie_ruser),
      .IFPSCPMPCIEAXIRVALID(s_axi_pcie_rvalid),
      .IFPSCPMPCIEAXIWREADY(s_axi_pcie_wready),
      .IFPSCPMPCIEAXIARADDR(s_axi_pcie_araddr),
      .IFPSCPMPCIEAXIARBURST(s_axi_pcie_arburst),
      .IFPSCPMPCIEAXIARCACHE(s_axi_pcie_arcache),
      .IFPSCPMPCIEAXIARID(s_axi_pcie_arid),
      .IFPSCPMPCIEAXIARLEN(s_axi_pcie_arlen),
      .IFPSCPMPCIEAXIARLOCK(s_axi_pcie_arlock),
      .IFPSCPMPCIEAXIARPROT(s_axi_pcie_arprot),
      .IFPSCPMPCIEAXIARQOS(s_axi_pcie_arqos),
      .IFPSCPMPCIEAXIARREGION(s_axi_pcie_arregion),
      .IFPSCPMPCIEAXIARSIZE(s_axi_pcie_arsize),
      .IFPSCPMPCIEAXIARUSER(s_axi_pcie_aruser),
      .IFPSCPMPCIEAXIARVALID(s_axi_pcie_arvalid),
      .IFPSCPMPCIEAXIAWADDR(s_axi_pcie_awaddr),
      .IFPSCPMPCIEAXIAWBURST(s_axi_pcie_awburst),
      .IFPSCPMPCIEAXIAWCACHE(s_axi_pcie_awcache),
      .IFPSCPMPCIEAXIAWID(s_axi_pcie_awid),
      .IFPSCPMPCIEAXIAWLEN(s_axi_pcie_awlen),
      .IFPSCPMPCIEAXIAWLOCK(s_axi_pcie_awlock),
      .IFPSCPMPCIEAXIAWPROT(s_axi_pcie_awprot),
      .IFPSCPMPCIEAXIAWQOS(s_axi_pcie_awqos),
      .IFPSCPMPCIEAXIAWREGION(s_axi_pcie_awregion),
      .IFPSCPMPCIEAXIAWSIZE(s_axi_pcie_awsize),
      .IFPSCPMPCIEAXIAWUSER(s_axi_pcie_awuser),
      .IFPSCPMPCIEAXIAWVALID(s_axi_pcie_awvalid),
      .IFPSCPMPCIEAXIBREADY(s_axi_pcie_bready),
      .IFPSCPMPCIEAXIRREADY(s_axi_pcie_rready),
      .IFPSCPMPCIEAXIWDATA(s_axi_pcie_wdata),
      .IFPSCPMPCIEAXIWID(s_axi_pcie_wid),
      .IFPSCPMPCIEAXIWLAST(s_axi_pcie_wlast),
      .IFPSCPMPCIEAXIWSTRB(s_axi_pcie_wstrb),
      .IFPSCPMPCIEAXIWUSER(s_axi_pcie_wuser),
      .IFPSCPMPCIEAXIWVALID(s_axi_pcie_wvalid),

      .IFPSCPMPCSRPCRAPBEN(cpm_pcr_apb_en),
      .IFPSCPMPCSRPCRDISNPICLK(cpm_pcr_dis_npi_clk),
      .IFPSCPMPCSRPCRFABRICEN(cpm_pcr_fabric_en),
      .IFPSCPMPCSRPCRGATEREG(cpm_pcr_gate_reg),
      .IFPSCPMPCSRPCRHOLDSTATE(cpm_pcr_hold_state),
      .IFPSCPMPCSRPCRINITSTATE(cpm_pcr_init_state),
      .IFPSCPMPCSRPCRMEMCLR(cpm_pcr_mem_clr),
      .IFPSCPMPCSRPCRODISABLE(cpm_pcr_o_disable),
      .IFPSCPMPCSRPCRPCOMPLETE(cpm_pcr_pcomplete),
      .IFPSCPMPCSRPCRPWRDN(cpm_pcr_pwr_dn),
      .IFPSCPMPCSRPCRSCANCLR(cpm_pcr_scan_clr),
      .IFPSCPMPCSRPCRSTARTBISR(cpm_pcr_start_bisr),
      .IFPSCPMPCSRPCRSTARTCAL(cpm_pcr_start_cal),
      .IFPSCPMPCSRPCRTRISTATE(cpm_pcr_tristate),


      .IFPSCPMQUAD0XPIPERXMARGINREQCMD(xpipe_q0_rxmargin_req_cmd),
      .IFPSCPMQUAD0XPIPERXMARGINREQLANENUM(xpipe_q0_rxmargin_req_lanenum),
      .IFPSCPMQUAD0XPIPERXMARGINREQPAYLOAD(xpipe_q0_rxmargin_req_payload),
      .IFPSCPMQUAD0XPIPERXMARGINREQREQ(xpipe_q0_rxmargin_req_req),
      .IFPSCPMQUAD0XPIPERXMARGINRESACK(xpipe_q0_rxmargin_res_ack),
      .IFPSCPMQUAD1XPIPERXMARGINREQCMD(xpipe_q1_rxmargin_req_cmd),
      .IFPSCPMQUAD1XPIPERXMARGINREQLANENUM(xpipe_q1_rxmargin_req_lanenum),
      .IFPSCPMQUAD1XPIPERXMARGINREQPAYLOAD(xpipe_q1_rxmargin_req_payload),
      .IFPSCPMQUAD1XPIPERXMARGINREQREQ(xpipe_q1_rxmargin_req_req),
      .IFPSCPMQUAD1XPIPERXMARGINRESACK(xpipe_q1_rxmargin_res_ack),
      .IFPSCPMQUAD2XPIPERXMARGINREQCMD(xpipe_q2_rxmargin_req_cmd),
      .IFPSCPMQUAD2XPIPERXMARGINREQLANENUM(xpipe_q2_rxmargin_req_lanenum),
      .IFPSCPMQUAD2XPIPERXMARGINREQPAYLOAD(xpipe_q2_rxmargin_req_payload),
      .IFPSCPMQUAD2XPIPERXMARGINREQREQ(xpipe_q2_rxmargin_req_req),
      .IFPSCPMQUAD2XPIPERXMARGINRESACK(xpipe_q2_rxmargin_res_ack),
      .IFPSCPMQUAD3XPIPERXMARGINREQCMD(xpipe_q3_rxmargin_req_cmd),
      .IFPSCPMQUAD3XPIPERXMARGINREQLANENUM(xpipe_q3_rxmargin_req_lanenum),
      .IFPSCPMQUAD3XPIPERXMARGINREQPAYLOAD(xpipe_q3_rxmargin_req_payload),
      .IFPSCPMQUAD3XPIPERXMARGINREQREQ(xpipe_q3_rxmargin_req_req),
      .IFPSCPMQUAD3XPIPERXMARGINRESACK(xpipe_q3_rxmargin_res_ack),
	  

      .LPDCPMINREFCLK(lpd_refclk_in),
      .LPDCPMSWITCHTIMEOUTCNT(lpd_switch_timeout_cnt),
      .LPDCPMTOPSWCLK(lpd_swclk),
      .LPDRCLKCLK(lpdrclkclk),

      .STMEVENT(stm_event)
    );




endmodule

