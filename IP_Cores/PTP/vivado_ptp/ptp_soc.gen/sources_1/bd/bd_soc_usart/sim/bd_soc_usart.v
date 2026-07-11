//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2.1 (lin64) Build 6403652 Thu Mar 19 13:47:00 MDT 2026
//Date        : Sun Jul 12 00:14:30 2026
//Host        : adrian running 64-bit Ubuntu 24.04.4 LTS
//Command     : generate_target bd_soc_usart.bd
//Design      : bd_soc_usart
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "bd_soc_usart,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=bd_soc_usart,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=5,numReposBlks=5,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=1,numPkgbdBlks=0,bdsource=USER,synth_mode=Hierarchical}" *) (* HW_HANDOFF = "bd_soc_usart.hwdef" *) 
module bd_soc_usart
   (ddr4_bank0_act_n,
    ddr4_bank0_adr,
    ddr4_bank0_ba,
    ddr4_bank0_bg,
    ddr4_bank0_ck_c,
    ddr4_bank0_ck_t,
    ddr4_bank0_cke,
    ddr4_bank0_cs_n,
    ddr4_bank0_dm_n,
    ddr4_bank0_dq,
    ddr4_bank0_dqs_c,
    ddr4_bank0_dqs_t,
    ddr4_bank0_odt,
    ddr4_bank0_reset_n,
    ddr4_bank0_sys_clk_clk_n,
    ddr4_bank0_sys_clk_clk_p);
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 ACT_N" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME ddr4_bank0, AXI_ARBITRATION_SCHEME TDM, BURST_LENGTH 8, CAN_DEBUG false, CAS_LATENCY 11, CAS_WRITE_LATENCY 11, CS_ENABLED true, DATA_MASK_ENABLED true, DATA_WIDTH 8, MEMORY_TYPE COMPONENTS, MEM_ADDR_MAP ROW_COLUMN_BANK, SLOT Single, TIMEPERIOD_PS 1250" *) output ddr4_bank0_act_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 ADR" *) output [16:0]ddr4_bank0_adr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 BA" *) output [1:0]ddr4_bank0_ba;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 BG" *) output ddr4_bank0_bg;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 CK_C" *) output ddr4_bank0_ck_c;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 CK_T" *) output ddr4_bank0_ck_t;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 CKE" *) output ddr4_bank0_cke;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 CS_N" *) output ddr4_bank0_cs_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 DM_N" *) inout [7:0]ddr4_bank0_dm_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 DQ" *) inout [63:0]ddr4_bank0_dq;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 DQS_C" *) inout [7:0]ddr4_bank0_dqs_c;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 DQS_T" *) inout [7:0]ddr4_bank0_dqs_t;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 ODT" *) output ddr4_bank0_odt;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 ddr4_bank0 RESET_N" *) output ddr4_bank0_reset_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 ddr4_bank0_sys_clk CLK_N" *) (* X_INTERFACE_MODE = "Slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME ddr4_bank0_sys_clk, CAN_DEBUG false, FREQ_HZ 200000000" *) input ddr4_bank0_sys_clk_clk_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 ddr4_bank0_sys_clk CLK_P" *) input ddr4_bank0_sys_clk_clk_p;

  wire [15:0]axi_smc_M00_AXI_ARADDR;
  wire axi_smc_M00_AXI_ARREADY;
  wire axi_smc_M00_AXI_ARVALID;
  wire [15:0]axi_smc_M00_AXI_AWADDR;
  wire axi_smc_M00_AXI_AWREADY;
  wire axi_smc_M00_AXI_AWVALID;
  wire axi_smc_M00_AXI_BREADY;
  wire [1:0]axi_smc_M00_AXI_BRESP;
  wire axi_smc_M00_AXI_BVALID;
  wire [31:0]axi_smc_M00_AXI_RDATA;
  wire axi_smc_M00_AXI_RREADY;
  wire [1:0]axi_smc_M00_AXI_RRESP;
  wire axi_smc_M00_AXI_RVALID;
  wire [31:0]axi_smc_M00_AXI_WDATA;
  wire axi_smc_M00_AXI_WREADY;
  wire [3:0]axi_smc_M00_AXI_WSTRB;
  wire axi_smc_M00_AXI_WVALID;
  wire [0:0]\^ddr4_bank0_act_n ;
  wire [16:0]ddr4_bank0_adr;
  wire [1:0]ddr4_bank0_ba;
  wire [0:0]\^ddr4_bank0_bg ;
  wire [0:0]\^ddr4_bank0_ck_c ;
  wire [0:0]\^ddr4_bank0_ck_t ;
  wire [0:0]\^ddr4_bank0_cke ;
  wire [0:0]\^ddr4_bank0_cs_n ;
  wire [7:0]ddr4_bank0_dm_n;
  wire [63:0]ddr4_bank0_dq;
  wire [7:0]ddr4_bank0_dqs_c;
  wire [7:0]ddr4_bank0_dqs_t;
  wire [0:0]\^ddr4_bank0_odt ;
  wire [0:0]\^ddr4_bank0_reset_n ;
  wire ddr4_bank0_sys_clk_clk_n;
  wire ddr4_bank0_sys_clk_clk_p;
  wire [0:0]rst_versal_cips_0_240M_peripheral_aresetn;
  wire u_soc_irq_out;
  wire [39:0]u_soc_m_axi_ARADDR;
  wire [1:0]u_soc_m_axi_ARBURST;
  wire [3:0]u_soc_m_axi_ARCACHE;
  wire [0:0]u_soc_m_axi_ARID;
  wire [7:0]u_soc_m_axi_ARLEN;
  wire [0:0]u_soc_m_axi_ARLOCK;
  wire [2:0]u_soc_m_axi_ARPROT;
  wire [3:0]u_soc_m_axi_ARQOS;
  wire [0:0]u_soc_m_axi_ARREADY;
  wire [2:0]u_soc_m_axi_ARSIZE;
  wire u_soc_m_axi_ARVALID;
  wire [39:0]u_soc_m_axi_AWADDR;
  wire [1:0]u_soc_m_axi_AWBURST;
  wire [3:0]u_soc_m_axi_AWCACHE;
  wire [0:0]u_soc_m_axi_AWID;
  wire [7:0]u_soc_m_axi_AWLEN;
  wire [0:0]u_soc_m_axi_AWLOCK;
  wire [2:0]u_soc_m_axi_AWPROT;
  wire [3:0]u_soc_m_axi_AWQOS;
  wire [0:0]u_soc_m_axi_AWREADY;
  wire [2:0]u_soc_m_axi_AWSIZE;
  wire u_soc_m_axi_AWVALID;
  wire [0:0]u_soc_m_axi_BID;
  wire u_soc_m_axi_BREADY;
  wire [1:0]u_soc_m_axi_BRESP;
  wire [0:0]u_soc_m_axi_BVALID;
  wire [31:0]u_soc_m_axi_RDATA;
  wire [0:0]u_soc_m_axi_RID;
  wire [0:0]u_soc_m_axi_RLAST;
  wire u_soc_m_axi_RREADY;
  wire [1:0]u_soc_m_axi_RRESP;
  wire [0:0]u_soc_m_axi_RVALID;
  wire [31:0]u_soc_m_axi_WDATA;
  wire u_soc_m_axi_WLAST;
  wire [0:0]u_soc_m_axi_WREADY;
  wire [3:0]u_soc_m_axi_WSTRB;
  wire u_soc_m_axi_WVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_FPD_CCI_NOC_0_ARADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_0_ARBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_0_ARCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_0_ARID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_FPD_CCI_NOC_0_ARLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_0_ARLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_0_ARPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_0_ARQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_0_ARREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_0_ARSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_FPD_CCI_NOC_0_ARUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_0_ARVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_FPD_CCI_NOC_0_AWADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_0_AWBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_0_AWCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_0_AWID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_FPD_CCI_NOC_0_AWLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_0_AWLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_0_AWPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_0_AWQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_0_AWREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_0_AWSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_FPD_CCI_NOC_0_AWUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_0_AWVALID;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_0_BID;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_0_BREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_0_BRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_0_BVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_FPD_CCI_NOC_0_RDATA;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_0_RID;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_0_RLAST;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_0_RREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_0_RRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_0_RVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_FPD_CCI_NOC_0_WDATA;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_0_WLAST;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_0_WREADY;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_0_WSTRB;
  (* HARD_CONN = "true" *) wire [16:0]versal_cips_0_FPD_CCI_NOC_0_WUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_0_WVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_FPD_CCI_NOC_1_ARADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_1_ARBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_1_ARCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_1_ARID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_FPD_CCI_NOC_1_ARLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_1_ARLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_1_ARPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_1_ARQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_1_ARREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_1_ARSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_FPD_CCI_NOC_1_ARUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_1_ARVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_FPD_CCI_NOC_1_AWADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_1_AWBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_1_AWCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_1_AWID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_FPD_CCI_NOC_1_AWLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_1_AWLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_1_AWPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_1_AWQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_1_AWREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_1_AWSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_FPD_CCI_NOC_1_AWUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_1_AWVALID;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_1_BID;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_1_BREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_1_BRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_1_BVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_FPD_CCI_NOC_1_RDATA;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_1_RID;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_1_RLAST;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_1_RREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_1_RRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_1_RVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_FPD_CCI_NOC_1_WDATA;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_1_WLAST;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_1_WREADY;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_1_WSTRB;
  (* HARD_CONN = "true" *) wire [16:0]versal_cips_0_FPD_CCI_NOC_1_WUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_1_WVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_FPD_CCI_NOC_2_ARADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_2_ARBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_2_ARCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_2_ARID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_FPD_CCI_NOC_2_ARLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_2_ARLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_2_ARPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_2_ARQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_2_ARREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_2_ARSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_FPD_CCI_NOC_2_ARUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_2_ARVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_FPD_CCI_NOC_2_AWADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_2_AWBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_2_AWCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_2_AWID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_FPD_CCI_NOC_2_AWLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_2_AWLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_2_AWPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_2_AWQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_2_AWREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_2_AWSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_FPD_CCI_NOC_2_AWUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_2_AWVALID;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_2_BID;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_2_BREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_2_BRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_2_BVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_FPD_CCI_NOC_2_RDATA;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_2_RID;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_2_RLAST;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_2_RREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_2_RRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_2_RVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_FPD_CCI_NOC_2_WDATA;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_2_WLAST;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_2_WREADY;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_2_WSTRB;
  (* HARD_CONN = "true" *) wire [16:0]versal_cips_0_FPD_CCI_NOC_2_WUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_2_WVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_FPD_CCI_NOC_3_ARADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_3_ARBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_3_ARCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_3_ARID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_FPD_CCI_NOC_3_ARLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_3_ARLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_3_ARPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_3_ARQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_3_ARREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_3_ARSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_FPD_CCI_NOC_3_ARUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_3_ARVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_FPD_CCI_NOC_3_AWADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_3_AWBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_3_AWCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_3_AWID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_FPD_CCI_NOC_3_AWLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_3_AWLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_3_AWPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_FPD_CCI_NOC_3_AWQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_3_AWREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_FPD_CCI_NOC_3_AWSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_FPD_CCI_NOC_3_AWUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_3_AWVALID;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_3_BID;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_3_BREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_3_BRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_3_BVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_FPD_CCI_NOC_3_RDATA;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_3_RID;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_3_RLAST;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_3_RREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_FPD_CCI_NOC_3_RRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_3_RVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_FPD_CCI_NOC_3_WDATA;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_3_WLAST;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_FPD_CCI_NOC_3_WREADY;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_FPD_CCI_NOC_3_WSTRB;
  (* HARD_CONN = "true" *) wire [16:0]versal_cips_0_FPD_CCI_NOC_3_WUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_FPD_CCI_NOC_3_WVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_LPD_AXI_NOC_0_ARADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_LPD_AXI_NOC_0_ARBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_LPD_AXI_NOC_0_ARCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_LPD_AXI_NOC_0_ARID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_LPD_AXI_NOC_0_ARLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_LPD_AXI_NOC_0_ARLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_LPD_AXI_NOC_0_ARPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_LPD_AXI_NOC_0_ARQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_LPD_AXI_NOC_0_ARREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_LPD_AXI_NOC_0_ARSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_LPD_AXI_NOC_0_ARUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_LPD_AXI_NOC_0_ARVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_LPD_AXI_NOC_0_AWADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_LPD_AXI_NOC_0_AWBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_LPD_AXI_NOC_0_AWCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_LPD_AXI_NOC_0_AWID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_LPD_AXI_NOC_0_AWLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_LPD_AXI_NOC_0_AWLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_LPD_AXI_NOC_0_AWPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_LPD_AXI_NOC_0_AWQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_LPD_AXI_NOC_0_AWREADY;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_LPD_AXI_NOC_0_AWSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_LPD_AXI_NOC_0_AWUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_LPD_AXI_NOC_0_AWVALID;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_LPD_AXI_NOC_0_BID;
  (* HARD_CONN = "true" *) wire versal_cips_0_LPD_AXI_NOC_0_BREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_LPD_AXI_NOC_0_BRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_LPD_AXI_NOC_0_BVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_LPD_AXI_NOC_0_RDATA;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_LPD_AXI_NOC_0_RID;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_LPD_AXI_NOC_0_RLAST;
  (* HARD_CONN = "true" *) wire versal_cips_0_LPD_AXI_NOC_0_RREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_LPD_AXI_NOC_0_RRESP;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_LPD_AXI_NOC_0_RVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_LPD_AXI_NOC_0_WDATA;
  (* HARD_CONN = "true" *) wire versal_cips_0_LPD_AXI_NOC_0_WLAST;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_LPD_AXI_NOC_0_WREADY;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_LPD_AXI_NOC_0_WSTRB;
  (* HARD_CONN = "true" *) wire versal_cips_0_LPD_AXI_NOC_0_WVALID;
  wire [43:0]versal_cips_0_M_AXI_LPD_ARADDR;
  wire [1:0]versal_cips_0_M_AXI_LPD_ARBURST;
  wire [3:0]versal_cips_0_M_AXI_LPD_ARCACHE;
  wire [15:0]versal_cips_0_M_AXI_LPD_ARID;
  wire [7:0]versal_cips_0_M_AXI_LPD_ARLEN;
  wire versal_cips_0_M_AXI_LPD_ARLOCK;
  wire [2:0]versal_cips_0_M_AXI_LPD_ARPROT;
  wire [3:0]versal_cips_0_M_AXI_LPD_ARQOS;
  wire versal_cips_0_M_AXI_LPD_ARREADY;
  wire [2:0]versal_cips_0_M_AXI_LPD_ARSIZE;
  wire [15:0]versal_cips_0_M_AXI_LPD_ARUSER;
  wire versal_cips_0_M_AXI_LPD_ARVALID;
  wire [43:0]versal_cips_0_M_AXI_LPD_AWADDR;
  wire [1:0]versal_cips_0_M_AXI_LPD_AWBURST;
  wire [3:0]versal_cips_0_M_AXI_LPD_AWCACHE;
  wire [15:0]versal_cips_0_M_AXI_LPD_AWID;
  wire [7:0]versal_cips_0_M_AXI_LPD_AWLEN;
  wire versal_cips_0_M_AXI_LPD_AWLOCK;
  wire [2:0]versal_cips_0_M_AXI_LPD_AWPROT;
  wire [3:0]versal_cips_0_M_AXI_LPD_AWQOS;
  wire versal_cips_0_M_AXI_LPD_AWREADY;
  wire [2:0]versal_cips_0_M_AXI_LPD_AWSIZE;
  wire [15:0]versal_cips_0_M_AXI_LPD_AWUSER;
  wire versal_cips_0_M_AXI_LPD_AWVALID;
  wire [15:0]versal_cips_0_M_AXI_LPD_BID;
  wire versal_cips_0_M_AXI_LPD_BREADY;
  wire [1:0]versal_cips_0_M_AXI_LPD_BRESP;
  wire versal_cips_0_M_AXI_LPD_BVALID;
  wire [127:0]versal_cips_0_M_AXI_LPD_RDATA;
  wire [15:0]versal_cips_0_M_AXI_LPD_RID;
  wire versal_cips_0_M_AXI_LPD_RLAST;
  wire versal_cips_0_M_AXI_LPD_RREADY;
  wire [1:0]versal_cips_0_M_AXI_LPD_RRESP;
  wire versal_cips_0_M_AXI_LPD_RVALID;
  wire [127:0]versal_cips_0_M_AXI_LPD_WDATA;
  wire versal_cips_0_M_AXI_LPD_WLAST;
  wire versal_cips_0_M_AXI_LPD_WREADY;
  wire [15:0]versal_cips_0_M_AXI_LPD_WSTRB;
  wire versal_cips_0_M_AXI_LPD_WVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_PMC_NOC_AXI_0_ARADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_PMC_NOC_AXI_0_ARBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_PMC_NOC_AXI_0_ARCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_PMC_NOC_AXI_0_ARID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_PMC_NOC_AXI_0_ARLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_PMC_NOC_AXI_0_ARLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_PMC_NOC_AXI_0_ARPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_PMC_NOC_AXI_0_ARQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_PMC_NOC_AXI_0_ARREADY;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_PMC_NOC_AXI_0_ARREGION;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_PMC_NOC_AXI_0_ARSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_PMC_NOC_AXI_0_ARUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_PMC_NOC_AXI_0_ARVALID;
  (* HARD_CONN = "true" *) wire [63:0]versal_cips_0_PMC_NOC_AXI_0_AWADDR;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_PMC_NOC_AXI_0_AWBURST;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_PMC_NOC_AXI_0_AWCACHE;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_PMC_NOC_AXI_0_AWID;
  (* HARD_CONN = "true" *) wire [7:0]versal_cips_0_PMC_NOC_AXI_0_AWLEN;
  (* HARD_CONN = "true" *) wire versal_cips_0_PMC_NOC_AXI_0_AWLOCK;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_PMC_NOC_AXI_0_AWPROT;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_PMC_NOC_AXI_0_AWQOS;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_PMC_NOC_AXI_0_AWREADY;
  (* HARD_CONN = "true" *) wire [3:0]versal_cips_0_PMC_NOC_AXI_0_AWREGION;
  (* HARD_CONN = "true" *) wire [2:0]versal_cips_0_PMC_NOC_AXI_0_AWSIZE;
  (* HARD_CONN = "true" *) wire [17:0]versal_cips_0_PMC_NOC_AXI_0_AWUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_PMC_NOC_AXI_0_AWVALID;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_PMC_NOC_AXI_0_BID;
  (* HARD_CONN = "true" *) wire versal_cips_0_PMC_NOC_AXI_0_BREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_PMC_NOC_AXI_0_BRESP;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_PMC_NOC_AXI_0_BUSER;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_PMC_NOC_AXI_0_BVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_PMC_NOC_AXI_0_RDATA;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_PMC_NOC_AXI_0_RID;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_PMC_NOC_AXI_0_RLAST;
  (* HARD_CONN = "true" *) wire versal_cips_0_PMC_NOC_AXI_0_RREADY;
  (* HARD_CONN = "true" *) wire [1:0]versal_cips_0_PMC_NOC_AXI_0_RRESP;
  (* HARD_CONN = "true" *) wire [16:0]versal_cips_0_PMC_NOC_AXI_0_RUSER;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_PMC_NOC_AXI_0_RVALID;
  (* HARD_CONN = "true" *) wire [127:0]versal_cips_0_PMC_NOC_AXI_0_WDATA;
  (* HARD_CONN = "true" *) wire versal_cips_0_PMC_NOC_AXI_0_WLAST;
  (* HARD_CONN = "true" *) wire [0:0]versal_cips_0_PMC_NOC_AXI_0_WREADY;
  (* HARD_CONN = "true" *) wire [15:0]versal_cips_0_PMC_NOC_AXI_0_WSTRB;
  (* HARD_CONN = "true" *) wire [16:0]versal_cips_0_PMC_NOC_AXI_0_WUSER;
  (* HARD_CONN = "true" *) wire versal_cips_0_PMC_NOC_AXI_0_WVALID;
  (* HARD_CONN = "true" *) wire versal_cips_0_fpd_cci_noc_axi0_clk;
  (* HARD_CONN = "true" *) wire versal_cips_0_fpd_cci_noc_axi1_clk;
  (* HARD_CONN = "true" *) wire versal_cips_0_fpd_cci_noc_axi2_clk;
  (* HARD_CONN = "true" *) wire versal_cips_0_fpd_cci_noc_axi3_clk;
  (* HARD_CONN = "true" *) wire versal_cips_0_lpd_axi_noc_clk;
  wire versal_cips_0_pl0_ref_clk;
  wire versal_cips_0_pl0_resetn;
  (* HARD_CONN = "true" *) wire versal_cips_0_pmc_axi_noc_axi0_clk;

  assign ddr4_bank0_act_n = \^ddr4_bank0_act_n [0];
  assign ddr4_bank0_bg = \^ddr4_bank0_bg [0];
  assign ddr4_bank0_ck_c = \^ddr4_bank0_ck_c [0];
  assign ddr4_bank0_ck_t = \^ddr4_bank0_ck_t [0];
  assign ddr4_bank0_cke = \^ddr4_bank0_cke [0];
  assign ddr4_bank0_cs_n = \^ddr4_bank0_cs_n [0];
  assign ddr4_bank0_odt = \^ddr4_bank0_odt [0];
  assign ddr4_bank0_reset_n = \^ddr4_bank0_reset_n [0];
  bd_soc_usart_axi_noc_0_0 axi_noc_0
       (.CH0_DDR4_0_act_n(\^ddr4_bank0_act_n ),
        .CH0_DDR4_0_adr(ddr4_bank0_adr),
        .CH0_DDR4_0_ba(ddr4_bank0_ba),
        .CH0_DDR4_0_bg(\^ddr4_bank0_bg ),
        .CH0_DDR4_0_ck_c(\^ddr4_bank0_ck_c ),
        .CH0_DDR4_0_ck_t(\^ddr4_bank0_ck_t ),
        .CH0_DDR4_0_cke(\^ddr4_bank0_cke ),
        .CH0_DDR4_0_cs_n(\^ddr4_bank0_cs_n ),
        .CH0_DDR4_0_dm_n(ddr4_bank0_dm_n),
        .CH0_DDR4_0_dq(ddr4_bank0_dq),
        .CH0_DDR4_0_dqs_c(ddr4_bank0_dqs_c),
        .CH0_DDR4_0_dqs_t(ddr4_bank0_dqs_t),
        .CH0_DDR4_0_odt(\^ddr4_bank0_odt ),
        .CH0_DDR4_0_reset_n(\^ddr4_bank0_reset_n ),
        .S00_AXI_araddr(versal_cips_0_FPD_CCI_NOC_0_ARADDR),
        .S00_AXI_arburst(versal_cips_0_FPD_CCI_NOC_0_ARBURST),
        .S00_AXI_arcache(versal_cips_0_FPD_CCI_NOC_0_ARCACHE),
        .S00_AXI_arid(versal_cips_0_FPD_CCI_NOC_0_ARID),
        .S00_AXI_arlen(versal_cips_0_FPD_CCI_NOC_0_ARLEN),
        .S00_AXI_arlock(versal_cips_0_FPD_CCI_NOC_0_ARLOCK),
        .S00_AXI_arprot(versal_cips_0_FPD_CCI_NOC_0_ARPROT),
        .S00_AXI_arqos(versal_cips_0_FPD_CCI_NOC_0_ARQOS),
        .S00_AXI_arready(versal_cips_0_FPD_CCI_NOC_0_ARREADY),
        .S00_AXI_arregion({1'b0,1'b0,1'b0,1'b0}),
        .S00_AXI_arsize(versal_cips_0_FPD_CCI_NOC_0_ARSIZE),
        .S00_AXI_aruser(versal_cips_0_FPD_CCI_NOC_0_ARUSER),
        .S00_AXI_arvalid(versal_cips_0_FPD_CCI_NOC_0_ARVALID),
        .S00_AXI_awaddr(versal_cips_0_FPD_CCI_NOC_0_AWADDR),
        .S00_AXI_awburst(versal_cips_0_FPD_CCI_NOC_0_AWBURST),
        .S00_AXI_awcache(versal_cips_0_FPD_CCI_NOC_0_AWCACHE),
        .S00_AXI_awid(versal_cips_0_FPD_CCI_NOC_0_AWID),
        .S00_AXI_awlen(versal_cips_0_FPD_CCI_NOC_0_AWLEN),
        .S00_AXI_awlock(versal_cips_0_FPD_CCI_NOC_0_AWLOCK),
        .S00_AXI_awprot(versal_cips_0_FPD_CCI_NOC_0_AWPROT),
        .S00_AXI_awqos(versal_cips_0_FPD_CCI_NOC_0_AWQOS),
        .S00_AXI_awready(versal_cips_0_FPD_CCI_NOC_0_AWREADY),
        .S00_AXI_awregion({1'b0,1'b0,1'b0,1'b0}),
        .S00_AXI_awsize(versal_cips_0_FPD_CCI_NOC_0_AWSIZE),
        .S00_AXI_awuser(versal_cips_0_FPD_CCI_NOC_0_AWUSER),
        .S00_AXI_awvalid(versal_cips_0_FPD_CCI_NOC_0_AWVALID),
        .S00_AXI_bid(versal_cips_0_FPD_CCI_NOC_0_BID),
        .S00_AXI_bready(versal_cips_0_FPD_CCI_NOC_0_BREADY),
        .S00_AXI_bresp(versal_cips_0_FPD_CCI_NOC_0_BRESP),
        .S00_AXI_bvalid(versal_cips_0_FPD_CCI_NOC_0_BVALID),
        .S00_AXI_rdata(versal_cips_0_FPD_CCI_NOC_0_RDATA),
        .S00_AXI_rid(versal_cips_0_FPD_CCI_NOC_0_RID),
        .S00_AXI_rlast(versal_cips_0_FPD_CCI_NOC_0_RLAST),
        .S00_AXI_rready(versal_cips_0_FPD_CCI_NOC_0_RREADY),
        .S00_AXI_rresp(versal_cips_0_FPD_CCI_NOC_0_RRESP),
        .S00_AXI_rvalid(versal_cips_0_FPD_CCI_NOC_0_RVALID),
        .S00_AXI_wdata(versal_cips_0_FPD_CCI_NOC_0_WDATA),
        .S00_AXI_wlast(versal_cips_0_FPD_CCI_NOC_0_WLAST),
        .S00_AXI_wready(versal_cips_0_FPD_CCI_NOC_0_WREADY),
        .S00_AXI_wstrb(versal_cips_0_FPD_CCI_NOC_0_WSTRB),
        .S00_AXI_wuser(versal_cips_0_FPD_CCI_NOC_0_WUSER),
        .S00_AXI_wvalid(versal_cips_0_FPD_CCI_NOC_0_WVALID),
        .S01_AXI_araddr(versal_cips_0_FPD_CCI_NOC_1_ARADDR),
        .S01_AXI_arburst(versal_cips_0_FPD_CCI_NOC_1_ARBURST),
        .S01_AXI_arcache(versal_cips_0_FPD_CCI_NOC_1_ARCACHE),
        .S01_AXI_arid(versal_cips_0_FPD_CCI_NOC_1_ARID),
        .S01_AXI_arlen(versal_cips_0_FPD_CCI_NOC_1_ARLEN),
        .S01_AXI_arlock(versal_cips_0_FPD_CCI_NOC_1_ARLOCK),
        .S01_AXI_arprot(versal_cips_0_FPD_CCI_NOC_1_ARPROT),
        .S01_AXI_arqos(versal_cips_0_FPD_CCI_NOC_1_ARQOS),
        .S01_AXI_arready(versal_cips_0_FPD_CCI_NOC_1_ARREADY),
        .S01_AXI_arregion({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_arsize(versal_cips_0_FPD_CCI_NOC_1_ARSIZE),
        .S01_AXI_aruser(versal_cips_0_FPD_CCI_NOC_1_ARUSER),
        .S01_AXI_arvalid(versal_cips_0_FPD_CCI_NOC_1_ARVALID),
        .S01_AXI_awaddr(versal_cips_0_FPD_CCI_NOC_1_AWADDR),
        .S01_AXI_awburst(versal_cips_0_FPD_CCI_NOC_1_AWBURST),
        .S01_AXI_awcache(versal_cips_0_FPD_CCI_NOC_1_AWCACHE),
        .S01_AXI_awid(versal_cips_0_FPD_CCI_NOC_1_AWID),
        .S01_AXI_awlen(versal_cips_0_FPD_CCI_NOC_1_AWLEN),
        .S01_AXI_awlock(versal_cips_0_FPD_CCI_NOC_1_AWLOCK),
        .S01_AXI_awprot(versal_cips_0_FPD_CCI_NOC_1_AWPROT),
        .S01_AXI_awqos(versal_cips_0_FPD_CCI_NOC_1_AWQOS),
        .S01_AXI_awready(versal_cips_0_FPD_CCI_NOC_1_AWREADY),
        .S01_AXI_awregion({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_awsize(versal_cips_0_FPD_CCI_NOC_1_AWSIZE),
        .S01_AXI_awuser(versal_cips_0_FPD_CCI_NOC_1_AWUSER),
        .S01_AXI_awvalid(versal_cips_0_FPD_CCI_NOC_1_AWVALID),
        .S01_AXI_bid(versal_cips_0_FPD_CCI_NOC_1_BID),
        .S01_AXI_bready(versal_cips_0_FPD_CCI_NOC_1_BREADY),
        .S01_AXI_bresp(versal_cips_0_FPD_CCI_NOC_1_BRESP),
        .S01_AXI_bvalid(versal_cips_0_FPD_CCI_NOC_1_BVALID),
        .S01_AXI_rdata(versal_cips_0_FPD_CCI_NOC_1_RDATA),
        .S01_AXI_rid(versal_cips_0_FPD_CCI_NOC_1_RID),
        .S01_AXI_rlast(versal_cips_0_FPD_CCI_NOC_1_RLAST),
        .S01_AXI_rready(versal_cips_0_FPD_CCI_NOC_1_RREADY),
        .S01_AXI_rresp(versal_cips_0_FPD_CCI_NOC_1_RRESP),
        .S01_AXI_rvalid(versal_cips_0_FPD_CCI_NOC_1_RVALID),
        .S01_AXI_wdata(versal_cips_0_FPD_CCI_NOC_1_WDATA),
        .S01_AXI_wlast(versal_cips_0_FPD_CCI_NOC_1_WLAST),
        .S01_AXI_wready(versal_cips_0_FPD_CCI_NOC_1_WREADY),
        .S01_AXI_wstrb(versal_cips_0_FPD_CCI_NOC_1_WSTRB),
        .S01_AXI_wuser(versal_cips_0_FPD_CCI_NOC_1_WUSER),
        .S01_AXI_wvalid(versal_cips_0_FPD_CCI_NOC_1_WVALID),
        .S02_AXI_araddr(versal_cips_0_FPD_CCI_NOC_2_ARADDR),
        .S02_AXI_arburst(versal_cips_0_FPD_CCI_NOC_2_ARBURST),
        .S02_AXI_arcache(versal_cips_0_FPD_CCI_NOC_2_ARCACHE),
        .S02_AXI_arid(versal_cips_0_FPD_CCI_NOC_2_ARID),
        .S02_AXI_arlen(versal_cips_0_FPD_CCI_NOC_2_ARLEN),
        .S02_AXI_arlock(versal_cips_0_FPD_CCI_NOC_2_ARLOCK),
        .S02_AXI_arprot(versal_cips_0_FPD_CCI_NOC_2_ARPROT),
        .S02_AXI_arqos(versal_cips_0_FPD_CCI_NOC_2_ARQOS),
        .S02_AXI_arready(versal_cips_0_FPD_CCI_NOC_2_ARREADY),
        .S02_AXI_arregion({1'b0,1'b0,1'b0,1'b0}),
        .S02_AXI_arsize(versal_cips_0_FPD_CCI_NOC_2_ARSIZE),
        .S02_AXI_aruser(versal_cips_0_FPD_CCI_NOC_2_ARUSER),
        .S02_AXI_arvalid(versal_cips_0_FPD_CCI_NOC_2_ARVALID),
        .S02_AXI_awaddr(versal_cips_0_FPD_CCI_NOC_2_AWADDR),
        .S02_AXI_awburst(versal_cips_0_FPD_CCI_NOC_2_AWBURST),
        .S02_AXI_awcache(versal_cips_0_FPD_CCI_NOC_2_AWCACHE),
        .S02_AXI_awid(versal_cips_0_FPD_CCI_NOC_2_AWID),
        .S02_AXI_awlen(versal_cips_0_FPD_CCI_NOC_2_AWLEN),
        .S02_AXI_awlock(versal_cips_0_FPD_CCI_NOC_2_AWLOCK),
        .S02_AXI_awprot(versal_cips_0_FPD_CCI_NOC_2_AWPROT),
        .S02_AXI_awqos(versal_cips_0_FPD_CCI_NOC_2_AWQOS),
        .S02_AXI_awready(versal_cips_0_FPD_CCI_NOC_2_AWREADY),
        .S02_AXI_awregion({1'b0,1'b0,1'b0,1'b0}),
        .S02_AXI_awsize(versal_cips_0_FPD_CCI_NOC_2_AWSIZE),
        .S02_AXI_awuser(versal_cips_0_FPD_CCI_NOC_2_AWUSER),
        .S02_AXI_awvalid(versal_cips_0_FPD_CCI_NOC_2_AWVALID),
        .S02_AXI_bid(versal_cips_0_FPD_CCI_NOC_2_BID),
        .S02_AXI_bready(versal_cips_0_FPD_CCI_NOC_2_BREADY),
        .S02_AXI_bresp(versal_cips_0_FPD_CCI_NOC_2_BRESP),
        .S02_AXI_bvalid(versal_cips_0_FPD_CCI_NOC_2_BVALID),
        .S02_AXI_rdata(versal_cips_0_FPD_CCI_NOC_2_RDATA),
        .S02_AXI_rid(versal_cips_0_FPD_CCI_NOC_2_RID),
        .S02_AXI_rlast(versal_cips_0_FPD_CCI_NOC_2_RLAST),
        .S02_AXI_rready(versal_cips_0_FPD_CCI_NOC_2_RREADY),
        .S02_AXI_rresp(versal_cips_0_FPD_CCI_NOC_2_RRESP),
        .S02_AXI_rvalid(versal_cips_0_FPD_CCI_NOC_2_RVALID),
        .S02_AXI_wdata(versal_cips_0_FPD_CCI_NOC_2_WDATA),
        .S02_AXI_wlast(versal_cips_0_FPD_CCI_NOC_2_WLAST),
        .S02_AXI_wready(versal_cips_0_FPD_CCI_NOC_2_WREADY),
        .S02_AXI_wstrb(versal_cips_0_FPD_CCI_NOC_2_WSTRB),
        .S02_AXI_wuser(versal_cips_0_FPD_CCI_NOC_2_WUSER),
        .S02_AXI_wvalid(versal_cips_0_FPD_CCI_NOC_2_WVALID),
        .S03_AXI_araddr(versal_cips_0_FPD_CCI_NOC_3_ARADDR),
        .S03_AXI_arburst(versal_cips_0_FPD_CCI_NOC_3_ARBURST),
        .S03_AXI_arcache(versal_cips_0_FPD_CCI_NOC_3_ARCACHE),
        .S03_AXI_arid(versal_cips_0_FPD_CCI_NOC_3_ARID),
        .S03_AXI_arlen(versal_cips_0_FPD_CCI_NOC_3_ARLEN),
        .S03_AXI_arlock(versal_cips_0_FPD_CCI_NOC_3_ARLOCK),
        .S03_AXI_arprot(versal_cips_0_FPD_CCI_NOC_3_ARPROT),
        .S03_AXI_arqos(versal_cips_0_FPD_CCI_NOC_3_ARQOS),
        .S03_AXI_arready(versal_cips_0_FPD_CCI_NOC_3_ARREADY),
        .S03_AXI_arregion({1'b0,1'b0,1'b0,1'b0}),
        .S03_AXI_arsize(versal_cips_0_FPD_CCI_NOC_3_ARSIZE),
        .S03_AXI_aruser(versal_cips_0_FPD_CCI_NOC_3_ARUSER),
        .S03_AXI_arvalid(versal_cips_0_FPD_CCI_NOC_3_ARVALID),
        .S03_AXI_awaddr(versal_cips_0_FPD_CCI_NOC_3_AWADDR),
        .S03_AXI_awburst(versal_cips_0_FPD_CCI_NOC_3_AWBURST),
        .S03_AXI_awcache(versal_cips_0_FPD_CCI_NOC_3_AWCACHE),
        .S03_AXI_awid(versal_cips_0_FPD_CCI_NOC_3_AWID),
        .S03_AXI_awlen(versal_cips_0_FPD_CCI_NOC_3_AWLEN),
        .S03_AXI_awlock(versal_cips_0_FPD_CCI_NOC_3_AWLOCK),
        .S03_AXI_awprot(versal_cips_0_FPD_CCI_NOC_3_AWPROT),
        .S03_AXI_awqos(versal_cips_0_FPD_CCI_NOC_3_AWQOS),
        .S03_AXI_awready(versal_cips_0_FPD_CCI_NOC_3_AWREADY),
        .S03_AXI_awregion({1'b0,1'b0,1'b0,1'b0}),
        .S03_AXI_awsize(versal_cips_0_FPD_CCI_NOC_3_AWSIZE),
        .S03_AXI_awuser(versal_cips_0_FPD_CCI_NOC_3_AWUSER),
        .S03_AXI_awvalid(versal_cips_0_FPD_CCI_NOC_3_AWVALID),
        .S03_AXI_bid(versal_cips_0_FPD_CCI_NOC_3_BID),
        .S03_AXI_bready(versal_cips_0_FPD_CCI_NOC_3_BREADY),
        .S03_AXI_bresp(versal_cips_0_FPD_CCI_NOC_3_BRESP),
        .S03_AXI_bvalid(versal_cips_0_FPD_CCI_NOC_3_BVALID),
        .S03_AXI_rdata(versal_cips_0_FPD_CCI_NOC_3_RDATA),
        .S03_AXI_rid(versal_cips_0_FPD_CCI_NOC_3_RID),
        .S03_AXI_rlast(versal_cips_0_FPD_CCI_NOC_3_RLAST),
        .S03_AXI_rready(versal_cips_0_FPD_CCI_NOC_3_RREADY),
        .S03_AXI_rresp(versal_cips_0_FPD_CCI_NOC_3_RRESP),
        .S03_AXI_rvalid(versal_cips_0_FPD_CCI_NOC_3_RVALID),
        .S03_AXI_wdata(versal_cips_0_FPD_CCI_NOC_3_WDATA),
        .S03_AXI_wlast(versal_cips_0_FPD_CCI_NOC_3_WLAST),
        .S03_AXI_wready(versal_cips_0_FPD_CCI_NOC_3_WREADY),
        .S03_AXI_wstrb(versal_cips_0_FPD_CCI_NOC_3_WSTRB),
        .S03_AXI_wuser(versal_cips_0_FPD_CCI_NOC_3_WUSER),
        .S03_AXI_wvalid(versal_cips_0_FPD_CCI_NOC_3_WVALID),
        .S04_AXI_araddr(versal_cips_0_LPD_AXI_NOC_0_ARADDR),
        .S04_AXI_arburst(versal_cips_0_LPD_AXI_NOC_0_ARBURST),
        .S04_AXI_arcache(versal_cips_0_LPD_AXI_NOC_0_ARCACHE),
        .S04_AXI_arid(versal_cips_0_LPD_AXI_NOC_0_ARID),
        .S04_AXI_arlen(versal_cips_0_LPD_AXI_NOC_0_ARLEN),
        .S04_AXI_arlock(versal_cips_0_LPD_AXI_NOC_0_ARLOCK),
        .S04_AXI_arprot(versal_cips_0_LPD_AXI_NOC_0_ARPROT),
        .S04_AXI_arqos(versal_cips_0_LPD_AXI_NOC_0_ARQOS),
        .S04_AXI_arready(versal_cips_0_LPD_AXI_NOC_0_ARREADY),
        .S04_AXI_arregion({1'b0,1'b0,1'b0,1'b0}),
        .S04_AXI_arsize(versal_cips_0_LPD_AXI_NOC_0_ARSIZE),
        .S04_AXI_aruser(versal_cips_0_LPD_AXI_NOC_0_ARUSER),
        .S04_AXI_arvalid(versal_cips_0_LPD_AXI_NOC_0_ARVALID),
        .S04_AXI_awaddr(versal_cips_0_LPD_AXI_NOC_0_AWADDR),
        .S04_AXI_awburst(versal_cips_0_LPD_AXI_NOC_0_AWBURST),
        .S04_AXI_awcache(versal_cips_0_LPD_AXI_NOC_0_AWCACHE),
        .S04_AXI_awid(versal_cips_0_LPD_AXI_NOC_0_AWID),
        .S04_AXI_awlen(versal_cips_0_LPD_AXI_NOC_0_AWLEN),
        .S04_AXI_awlock(versal_cips_0_LPD_AXI_NOC_0_AWLOCK),
        .S04_AXI_awprot(versal_cips_0_LPD_AXI_NOC_0_AWPROT),
        .S04_AXI_awqos(versal_cips_0_LPD_AXI_NOC_0_AWQOS),
        .S04_AXI_awready(versal_cips_0_LPD_AXI_NOC_0_AWREADY),
        .S04_AXI_awregion({1'b0,1'b0,1'b0,1'b0}),
        .S04_AXI_awsize(versal_cips_0_LPD_AXI_NOC_0_AWSIZE),
        .S04_AXI_awuser(versal_cips_0_LPD_AXI_NOC_0_AWUSER),
        .S04_AXI_awvalid(versal_cips_0_LPD_AXI_NOC_0_AWVALID),
        .S04_AXI_bid(versal_cips_0_LPD_AXI_NOC_0_BID),
        .S04_AXI_bready(versal_cips_0_LPD_AXI_NOC_0_BREADY),
        .S04_AXI_bresp(versal_cips_0_LPD_AXI_NOC_0_BRESP),
        .S04_AXI_bvalid(versal_cips_0_LPD_AXI_NOC_0_BVALID),
        .S04_AXI_rdata(versal_cips_0_LPD_AXI_NOC_0_RDATA),
        .S04_AXI_rid(versal_cips_0_LPD_AXI_NOC_0_RID),
        .S04_AXI_rlast(versal_cips_0_LPD_AXI_NOC_0_RLAST),
        .S04_AXI_rready(versal_cips_0_LPD_AXI_NOC_0_RREADY),
        .S04_AXI_rresp(versal_cips_0_LPD_AXI_NOC_0_RRESP),
        .S04_AXI_rvalid(versal_cips_0_LPD_AXI_NOC_0_RVALID),
        .S04_AXI_wdata(versal_cips_0_LPD_AXI_NOC_0_WDATA),
        .S04_AXI_wlast(versal_cips_0_LPD_AXI_NOC_0_WLAST),
        .S04_AXI_wready(versal_cips_0_LPD_AXI_NOC_0_WREADY),
        .S04_AXI_wstrb(versal_cips_0_LPD_AXI_NOC_0_WSTRB),
        .S04_AXI_wuser({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .S04_AXI_wvalid(versal_cips_0_LPD_AXI_NOC_0_WVALID),
        .S05_AXI_araddr(versal_cips_0_PMC_NOC_AXI_0_ARADDR),
        .S05_AXI_arburst(versal_cips_0_PMC_NOC_AXI_0_ARBURST),
        .S05_AXI_arcache(versal_cips_0_PMC_NOC_AXI_0_ARCACHE),
        .S05_AXI_arid(versal_cips_0_PMC_NOC_AXI_0_ARID),
        .S05_AXI_arlen(versal_cips_0_PMC_NOC_AXI_0_ARLEN),
        .S05_AXI_arlock(versal_cips_0_PMC_NOC_AXI_0_ARLOCK),
        .S05_AXI_arprot(versal_cips_0_PMC_NOC_AXI_0_ARPROT),
        .S05_AXI_arqos(versal_cips_0_PMC_NOC_AXI_0_ARQOS),
        .S05_AXI_arready(versal_cips_0_PMC_NOC_AXI_0_ARREADY),
        .S05_AXI_arregion(versal_cips_0_PMC_NOC_AXI_0_ARREGION),
        .S05_AXI_arsize(versal_cips_0_PMC_NOC_AXI_0_ARSIZE),
        .S05_AXI_aruser(versal_cips_0_PMC_NOC_AXI_0_ARUSER),
        .S05_AXI_arvalid(versal_cips_0_PMC_NOC_AXI_0_ARVALID),
        .S05_AXI_awaddr(versal_cips_0_PMC_NOC_AXI_0_AWADDR),
        .S05_AXI_awburst(versal_cips_0_PMC_NOC_AXI_0_AWBURST),
        .S05_AXI_awcache(versal_cips_0_PMC_NOC_AXI_0_AWCACHE),
        .S05_AXI_awid(versal_cips_0_PMC_NOC_AXI_0_AWID),
        .S05_AXI_awlen(versal_cips_0_PMC_NOC_AXI_0_AWLEN),
        .S05_AXI_awlock(versal_cips_0_PMC_NOC_AXI_0_AWLOCK),
        .S05_AXI_awprot(versal_cips_0_PMC_NOC_AXI_0_AWPROT),
        .S05_AXI_awqos(versal_cips_0_PMC_NOC_AXI_0_AWQOS),
        .S05_AXI_awready(versal_cips_0_PMC_NOC_AXI_0_AWREADY),
        .S05_AXI_awregion(versal_cips_0_PMC_NOC_AXI_0_AWREGION),
        .S05_AXI_awsize(versal_cips_0_PMC_NOC_AXI_0_AWSIZE),
        .S05_AXI_awuser(versal_cips_0_PMC_NOC_AXI_0_AWUSER),
        .S05_AXI_awvalid(versal_cips_0_PMC_NOC_AXI_0_AWVALID),
        .S05_AXI_bid(versal_cips_0_PMC_NOC_AXI_0_BID),
        .S05_AXI_bready(versal_cips_0_PMC_NOC_AXI_0_BREADY),
        .S05_AXI_bresp(versal_cips_0_PMC_NOC_AXI_0_BRESP),
        .S05_AXI_buser(versal_cips_0_PMC_NOC_AXI_0_BUSER),
        .S05_AXI_bvalid(versal_cips_0_PMC_NOC_AXI_0_BVALID),
        .S05_AXI_rdata(versal_cips_0_PMC_NOC_AXI_0_RDATA),
        .S05_AXI_rid(versal_cips_0_PMC_NOC_AXI_0_RID),
        .S05_AXI_rlast(versal_cips_0_PMC_NOC_AXI_0_RLAST),
        .S05_AXI_rready(versal_cips_0_PMC_NOC_AXI_0_RREADY),
        .S05_AXI_rresp(versal_cips_0_PMC_NOC_AXI_0_RRESP),
        .S05_AXI_ruser(versal_cips_0_PMC_NOC_AXI_0_RUSER),
        .S05_AXI_rvalid(versal_cips_0_PMC_NOC_AXI_0_RVALID),
        .S05_AXI_wdata(versal_cips_0_PMC_NOC_AXI_0_WDATA),
        .S05_AXI_wlast(versal_cips_0_PMC_NOC_AXI_0_WLAST),
        .S05_AXI_wready(versal_cips_0_PMC_NOC_AXI_0_WREADY),
        .S05_AXI_wstrb(versal_cips_0_PMC_NOC_AXI_0_WSTRB),
        .S05_AXI_wuser(versal_cips_0_PMC_NOC_AXI_0_WUSER),
        .S05_AXI_wvalid(versal_cips_0_PMC_NOC_AXI_0_WVALID),
        .S06_AXI_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,u_soc_m_axi_ARADDR}),
        .S06_AXI_arburst(u_soc_m_axi_ARBURST),
        .S06_AXI_arcache(u_soc_m_axi_ARCACHE),
        .S06_AXI_arid(u_soc_m_axi_ARID),
        .S06_AXI_arlen(u_soc_m_axi_ARLEN),
        .S06_AXI_arlock(u_soc_m_axi_ARLOCK),
        .S06_AXI_arprot(u_soc_m_axi_ARPROT),
        .S06_AXI_arqos(u_soc_m_axi_ARQOS),
        .S06_AXI_arready(u_soc_m_axi_ARREADY),
        .S06_AXI_arregion({1'b0,1'b0,1'b0,1'b0}),
        .S06_AXI_arsize(u_soc_m_axi_ARSIZE),
        .S06_AXI_arvalid(u_soc_m_axi_ARVALID),
        .S06_AXI_awaddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,u_soc_m_axi_AWADDR}),
        .S06_AXI_awburst(u_soc_m_axi_AWBURST),
        .S06_AXI_awcache(u_soc_m_axi_AWCACHE),
        .S06_AXI_awid(u_soc_m_axi_AWID),
        .S06_AXI_awlen(u_soc_m_axi_AWLEN),
        .S06_AXI_awlock(u_soc_m_axi_AWLOCK),
        .S06_AXI_awprot(u_soc_m_axi_AWPROT),
        .S06_AXI_awqos(u_soc_m_axi_AWQOS),
        .S06_AXI_awready(u_soc_m_axi_AWREADY),
        .S06_AXI_awregion({1'b0,1'b0,1'b0,1'b0}),
        .S06_AXI_awsize(u_soc_m_axi_AWSIZE),
        .S06_AXI_awvalid(u_soc_m_axi_AWVALID),
        .S06_AXI_bid(u_soc_m_axi_BID),
        .S06_AXI_bready(u_soc_m_axi_BREADY),
        .S06_AXI_bresp(u_soc_m_axi_BRESP),
        .S06_AXI_bvalid(u_soc_m_axi_BVALID),
        .S06_AXI_rdata(u_soc_m_axi_RDATA),
        .S06_AXI_rid(u_soc_m_axi_RID),
        .S06_AXI_rlast(u_soc_m_axi_RLAST),
        .S06_AXI_rready(u_soc_m_axi_RREADY),
        .S06_AXI_rresp(u_soc_m_axi_RRESP),
        .S06_AXI_rvalid(u_soc_m_axi_RVALID),
        .S06_AXI_wdata(u_soc_m_axi_WDATA),
        .S06_AXI_wlast(u_soc_m_axi_WLAST),
        .S06_AXI_wready(u_soc_m_axi_WREADY),
        .S06_AXI_wstrb(u_soc_m_axi_WSTRB),
        .S06_AXI_wvalid(u_soc_m_axi_WVALID),
        .aclk0(versal_cips_0_fpd_cci_noc_axi0_clk),
        .aclk1(versal_cips_0_fpd_cci_noc_axi1_clk),
        .aclk2(versal_cips_0_fpd_cci_noc_axi2_clk),
        .aclk3(versal_cips_0_fpd_cci_noc_axi3_clk),
        .aclk4(versal_cips_0_lpd_axi_noc_clk),
        .aclk5(versal_cips_0_pmc_axi_noc_axi0_clk),
        .aclk6(versal_cips_0_pl0_ref_clk),
        .sys_clk0_clk_n(ddr4_bank0_sys_clk_clk_n),
        .sys_clk0_clk_p(ddr4_bank0_sys_clk_clk_p));
  bd_soc_usart_axi_smc_0 axi_smc
       (.M00_AXI_araddr(axi_smc_M00_AXI_ARADDR),
        .M00_AXI_arready(axi_smc_M00_AXI_ARREADY),
        .M00_AXI_arvalid(axi_smc_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_smc_M00_AXI_AWADDR),
        .M00_AXI_awready(axi_smc_M00_AXI_AWREADY),
        .M00_AXI_awvalid(axi_smc_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_smc_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_smc_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_smc_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_smc_M00_AXI_RDATA),
        .M00_AXI_rready(axi_smc_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_smc_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_smc_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_smc_M00_AXI_WDATA),
        .M00_AXI_wready(axi_smc_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_smc_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_smc_M00_AXI_WVALID),
        .S00_AXI_araddr(versal_cips_0_M_AXI_LPD_ARADDR),
        .S00_AXI_arburst(versal_cips_0_M_AXI_LPD_ARBURST),
        .S00_AXI_arcache(versal_cips_0_M_AXI_LPD_ARCACHE),
        .S00_AXI_arid(versal_cips_0_M_AXI_LPD_ARID),
        .S00_AXI_arlen(versal_cips_0_M_AXI_LPD_ARLEN),
        .S00_AXI_arlock(versal_cips_0_M_AXI_LPD_ARLOCK),
        .S00_AXI_arprot(versal_cips_0_M_AXI_LPD_ARPROT),
        .S00_AXI_arqos(versal_cips_0_M_AXI_LPD_ARQOS),
        .S00_AXI_arready(versal_cips_0_M_AXI_LPD_ARREADY),
        .S00_AXI_arsize(versal_cips_0_M_AXI_LPD_ARSIZE),
        .S00_AXI_aruser(versal_cips_0_M_AXI_LPD_ARUSER),
        .S00_AXI_arvalid(versal_cips_0_M_AXI_LPD_ARVALID),
        .S00_AXI_awaddr(versal_cips_0_M_AXI_LPD_AWADDR),
        .S00_AXI_awburst(versal_cips_0_M_AXI_LPD_AWBURST),
        .S00_AXI_awcache(versal_cips_0_M_AXI_LPD_AWCACHE),
        .S00_AXI_awid(versal_cips_0_M_AXI_LPD_AWID),
        .S00_AXI_awlen(versal_cips_0_M_AXI_LPD_AWLEN),
        .S00_AXI_awlock(versal_cips_0_M_AXI_LPD_AWLOCK),
        .S00_AXI_awprot(versal_cips_0_M_AXI_LPD_AWPROT),
        .S00_AXI_awqos(versal_cips_0_M_AXI_LPD_AWQOS),
        .S00_AXI_awready(versal_cips_0_M_AXI_LPD_AWREADY),
        .S00_AXI_awsize(versal_cips_0_M_AXI_LPD_AWSIZE),
        .S00_AXI_awuser(versal_cips_0_M_AXI_LPD_AWUSER),
        .S00_AXI_awvalid(versal_cips_0_M_AXI_LPD_AWVALID),
        .S00_AXI_bid(versal_cips_0_M_AXI_LPD_BID),
        .S00_AXI_bready(versal_cips_0_M_AXI_LPD_BREADY),
        .S00_AXI_bresp(versal_cips_0_M_AXI_LPD_BRESP),
        .S00_AXI_bvalid(versal_cips_0_M_AXI_LPD_BVALID),
        .S00_AXI_rdata(versal_cips_0_M_AXI_LPD_RDATA),
        .S00_AXI_rid(versal_cips_0_M_AXI_LPD_RID),
        .S00_AXI_rlast(versal_cips_0_M_AXI_LPD_RLAST),
        .S00_AXI_rready(versal_cips_0_M_AXI_LPD_RREADY),
        .S00_AXI_rresp(versal_cips_0_M_AXI_LPD_RRESP),
        .S00_AXI_rvalid(versal_cips_0_M_AXI_LPD_RVALID),
        .S00_AXI_wdata(versal_cips_0_M_AXI_LPD_WDATA),
        .S00_AXI_wlast(versal_cips_0_M_AXI_LPD_WLAST),
        .S00_AXI_wready(versal_cips_0_M_AXI_LPD_WREADY),
        .S00_AXI_wstrb(versal_cips_0_M_AXI_LPD_WSTRB),
        .S00_AXI_wvalid(versal_cips_0_M_AXI_LPD_WVALID),
        .aclk(versal_cips_0_pl0_ref_clk),
        .aresetn(rst_versal_cips_0_240M_peripheral_aresetn));
  bd_soc_usart_rst_versal_cips_0_240M_0 rst_versal_cips_0_240M
       (.aux_reset_in(1'b1),
        .dcm_locked(1'b1),
        .ext_reset_in(versal_cips_0_pl0_resetn),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_versal_cips_0_240M_peripheral_aresetn),
        .slowest_sync_clk(versal_cips_0_pl0_ref_clk));
  bd_soc_usart_u_soc_ptp_0 u_soc_ptp
       (.aclk(versal_cips_0_pl0_ref_clk),
        .aresetn(rst_versal_cips_0_240M_peripheral_aresetn),
        .irq_out(u_soc_irq_out),
        .m_axi_araddr(u_soc_m_axi_ARADDR),
        .m_axi_arburst(u_soc_m_axi_ARBURST),
        .m_axi_arcache(u_soc_m_axi_ARCACHE),
        .m_axi_arid(u_soc_m_axi_ARID),
        .m_axi_arlen(u_soc_m_axi_ARLEN),
        .m_axi_arlock(u_soc_m_axi_ARLOCK),
        .m_axi_arprot(u_soc_m_axi_ARPROT),
        .m_axi_arqos(u_soc_m_axi_ARQOS),
        .m_axi_arready(u_soc_m_axi_ARREADY),
        .m_axi_arsize(u_soc_m_axi_ARSIZE),
        .m_axi_arvalid(u_soc_m_axi_ARVALID),
        .m_axi_awaddr(u_soc_m_axi_AWADDR),
        .m_axi_awburst(u_soc_m_axi_AWBURST),
        .m_axi_awcache(u_soc_m_axi_AWCACHE),
        .m_axi_awid(u_soc_m_axi_AWID),
        .m_axi_awlen(u_soc_m_axi_AWLEN),
        .m_axi_awlock(u_soc_m_axi_AWLOCK),
        .m_axi_awprot(u_soc_m_axi_AWPROT),
        .m_axi_awqos(u_soc_m_axi_AWQOS),
        .m_axi_awready(u_soc_m_axi_AWREADY),
        .m_axi_awsize(u_soc_m_axi_AWSIZE),
        .m_axi_awvalid(u_soc_m_axi_AWVALID),
        .m_axi_bid(u_soc_m_axi_BID),
        .m_axi_bready(u_soc_m_axi_BREADY),
        .m_axi_bresp(u_soc_m_axi_BRESP),
        .m_axi_bvalid(u_soc_m_axi_BVALID),
        .m_axi_rdata(u_soc_m_axi_RDATA),
        .m_axi_rid(u_soc_m_axi_RID),
        .m_axi_rlast(u_soc_m_axi_RLAST),
        .m_axi_rready(u_soc_m_axi_RREADY),
        .m_axi_rresp(u_soc_m_axi_RRESP),
        .m_axi_rvalid(u_soc_m_axi_RVALID),
        .m_axi_wdata(u_soc_m_axi_WDATA),
        .m_axi_wlast(u_soc_m_axi_WLAST),
        .m_axi_wready(u_soc_m_axi_WREADY),
        .m_axi_wstrb(u_soc_m_axi_WSTRB),
        .m_axi_wvalid(u_soc_m_axi_WVALID),
        .s_axi_araddr(axi_smc_M00_AXI_ARADDR),
        .s_axi_arready(axi_smc_M00_AXI_ARREADY),
        .s_axi_arvalid(axi_smc_M00_AXI_ARVALID),
        .s_axi_awaddr(axi_smc_M00_AXI_AWADDR),
        .s_axi_awready(axi_smc_M00_AXI_AWREADY),
        .s_axi_awvalid(axi_smc_M00_AXI_AWVALID),
        .s_axi_bready(axi_smc_M00_AXI_BREADY),
        .s_axi_bresp(axi_smc_M00_AXI_BRESP),
        .s_axi_bvalid(axi_smc_M00_AXI_BVALID),
        .s_axi_rdata(axi_smc_M00_AXI_RDATA),
        .s_axi_rready(axi_smc_M00_AXI_RREADY),
        .s_axi_rresp(axi_smc_M00_AXI_RRESP),
        .s_axi_rvalid(axi_smc_M00_AXI_RVALID),
        .s_axi_wdata(axi_smc_M00_AXI_WDATA),
        .s_axi_wready(axi_smc_M00_AXI_WREADY),
        .s_axi_wstrb(axi_smc_M00_AXI_WSTRB),
        .s_axi_wvalid(axi_smc_M00_AXI_WVALID));
  bd_soc_usart_versal_cips_0_0 versal_cips_0
       (.FPD_CCI_NOC_0_araddr(versal_cips_0_FPD_CCI_NOC_0_ARADDR),
        .FPD_CCI_NOC_0_arburst(versal_cips_0_FPD_CCI_NOC_0_ARBURST),
        .FPD_CCI_NOC_0_arcache(versal_cips_0_FPD_CCI_NOC_0_ARCACHE),
        .FPD_CCI_NOC_0_arid(versal_cips_0_FPD_CCI_NOC_0_ARID),
        .FPD_CCI_NOC_0_arlen(versal_cips_0_FPD_CCI_NOC_0_ARLEN),
        .FPD_CCI_NOC_0_arlock(versal_cips_0_FPD_CCI_NOC_0_ARLOCK),
        .FPD_CCI_NOC_0_arprot(versal_cips_0_FPD_CCI_NOC_0_ARPROT),
        .FPD_CCI_NOC_0_arqos(versal_cips_0_FPD_CCI_NOC_0_ARQOS),
        .FPD_CCI_NOC_0_arready(versal_cips_0_FPD_CCI_NOC_0_ARREADY),
        .FPD_CCI_NOC_0_arsize(versal_cips_0_FPD_CCI_NOC_0_ARSIZE),
        .FPD_CCI_NOC_0_aruser(versal_cips_0_FPD_CCI_NOC_0_ARUSER),
        .FPD_CCI_NOC_0_arvalid(versal_cips_0_FPD_CCI_NOC_0_ARVALID),
        .FPD_CCI_NOC_0_awaddr(versal_cips_0_FPD_CCI_NOC_0_AWADDR),
        .FPD_CCI_NOC_0_awburst(versal_cips_0_FPD_CCI_NOC_0_AWBURST),
        .FPD_CCI_NOC_0_awcache(versal_cips_0_FPD_CCI_NOC_0_AWCACHE),
        .FPD_CCI_NOC_0_awid(versal_cips_0_FPD_CCI_NOC_0_AWID),
        .FPD_CCI_NOC_0_awlen(versal_cips_0_FPD_CCI_NOC_0_AWLEN),
        .FPD_CCI_NOC_0_awlock(versal_cips_0_FPD_CCI_NOC_0_AWLOCK),
        .FPD_CCI_NOC_0_awprot(versal_cips_0_FPD_CCI_NOC_0_AWPROT),
        .FPD_CCI_NOC_0_awqos(versal_cips_0_FPD_CCI_NOC_0_AWQOS),
        .FPD_CCI_NOC_0_awready(versal_cips_0_FPD_CCI_NOC_0_AWREADY),
        .FPD_CCI_NOC_0_awsize(versal_cips_0_FPD_CCI_NOC_0_AWSIZE),
        .FPD_CCI_NOC_0_awuser(versal_cips_0_FPD_CCI_NOC_0_AWUSER),
        .FPD_CCI_NOC_0_awvalid(versal_cips_0_FPD_CCI_NOC_0_AWVALID),
        .FPD_CCI_NOC_0_bid(versal_cips_0_FPD_CCI_NOC_0_BID),
        .FPD_CCI_NOC_0_bready(versal_cips_0_FPD_CCI_NOC_0_BREADY),
        .FPD_CCI_NOC_0_bresp(versal_cips_0_FPD_CCI_NOC_0_BRESP),
        .FPD_CCI_NOC_0_bvalid(versal_cips_0_FPD_CCI_NOC_0_BVALID),
        .FPD_CCI_NOC_0_rdata(versal_cips_0_FPD_CCI_NOC_0_RDATA),
        .FPD_CCI_NOC_0_rid(versal_cips_0_FPD_CCI_NOC_0_RID),
        .FPD_CCI_NOC_0_rlast(versal_cips_0_FPD_CCI_NOC_0_RLAST),
        .FPD_CCI_NOC_0_rready(versal_cips_0_FPD_CCI_NOC_0_RREADY),
        .FPD_CCI_NOC_0_rresp(versal_cips_0_FPD_CCI_NOC_0_RRESP),
        .FPD_CCI_NOC_0_rvalid(versal_cips_0_FPD_CCI_NOC_0_RVALID),
        .FPD_CCI_NOC_0_wdata(versal_cips_0_FPD_CCI_NOC_0_WDATA),
        .FPD_CCI_NOC_0_wlast(versal_cips_0_FPD_CCI_NOC_0_WLAST),
        .FPD_CCI_NOC_0_wready(versal_cips_0_FPD_CCI_NOC_0_WREADY),
        .FPD_CCI_NOC_0_wstrb(versal_cips_0_FPD_CCI_NOC_0_WSTRB),
        .FPD_CCI_NOC_0_wuser(versal_cips_0_FPD_CCI_NOC_0_WUSER),
        .FPD_CCI_NOC_0_wvalid(versal_cips_0_FPD_CCI_NOC_0_WVALID),
        .FPD_CCI_NOC_1_araddr(versal_cips_0_FPD_CCI_NOC_1_ARADDR),
        .FPD_CCI_NOC_1_arburst(versal_cips_0_FPD_CCI_NOC_1_ARBURST),
        .FPD_CCI_NOC_1_arcache(versal_cips_0_FPD_CCI_NOC_1_ARCACHE),
        .FPD_CCI_NOC_1_arid(versal_cips_0_FPD_CCI_NOC_1_ARID),
        .FPD_CCI_NOC_1_arlen(versal_cips_0_FPD_CCI_NOC_1_ARLEN),
        .FPD_CCI_NOC_1_arlock(versal_cips_0_FPD_CCI_NOC_1_ARLOCK),
        .FPD_CCI_NOC_1_arprot(versal_cips_0_FPD_CCI_NOC_1_ARPROT),
        .FPD_CCI_NOC_1_arqos(versal_cips_0_FPD_CCI_NOC_1_ARQOS),
        .FPD_CCI_NOC_1_arready(versal_cips_0_FPD_CCI_NOC_1_ARREADY),
        .FPD_CCI_NOC_1_arsize(versal_cips_0_FPD_CCI_NOC_1_ARSIZE),
        .FPD_CCI_NOC_1_aruser(versal_cips_0_FPD_CCI_NOC_1_ARUSER),
        .FPD_CCI_NOC_1_arvalid(versal_cips_0_FPD_CCI_NOC_1_ARVALID),
        .FPD_CCI_NOC_1_awaddr(versal_cips_0_FPD_CCI_NOC_1_AWADDR),
        .FPD_CCI_NOC_1_awburst(versal_cips_0_FPD_CCI_NOC_1_AWBURST),
        .FPD_CCI_NOC_1_awcache(versal_cips_0_FPD_CCI_NOC_1_AWCACHE),
        .FPD_CCI_NOC_1_awid(versal_cips_0_FPD_CCI_NOC_1_AWID),
        .FPD_CCI_NOC_1_awlen(versal_cips_0_FPD_CCI_NOC_1_AWLEN),
        .FPD_CCI_NOC_1_awlock(versal_cips_0_FPD_CCI_NOC_1_AWLOCK),
        .FPD_CCI_NOC_1_awprot(versal_cips_0_FPD_CCI_NOC_1_AWPROT),
        .FPD_CCI_NOC_1_awqos(versal_cips_0_FPD_CCI_NOC_1_AWQOS),
        .FPD_CCI_NOC_1_awready(versal_cips_0_FPD_CCI_NOC_1_AWREADY),
        .FPD_CCI_NOC_1_awsize(versal_cips_0_FPD_CCI_NOC_1_AWSIZE),
        .FPD_CCI_NOC_1_awuser(versal_cips_0_FPD_CCI_NOC_1_AWUSER),
        .FPD_CCI_NOC_1_awvalid(versal_cips_0_FPD_CCI_NOC_1_AWVALID),
        .FPD_CCI_NOC_1_bid(versal_cips_0_FPD_CCI_NOC_1_BID),
        .FPD_CCI_NOC_1_bready(versal_cips_0_FPD_CCI_NOC_1_BREADY),
        .FPD_CCI_NOC_1_bresp(versal_cips_0_FPD_CCI_NOC_1_BRESP),
        .FPD_CCI_NOC_1_bvalid(versal_cips_0_FPD_CCI_NOC_1_BVALID),
        .FPD_CCI_NOC_1_rdata(versal_cips_0_FPD_CCI_NOC_1_RDATA),
        .FPD_CCI_NOC_1_rid(versal_cips_0_FPD_CCI_NOC_1_RID),
        .FPD_CCI_NOC_1_rlast(versal_cips_0_FPD_CCI_NOC_1_RLAST),
        .FPD_CCI_NOC_1_rready(versal_cips_0_FPD_CCI_NOC_1_RREADY),
        .FPD_CCI_NOC_1_rresp(versal_cips_0_FPD_CCI_NOC_1_RRESP),
        .FPD_CCI_NOC_1_rvalid(versal_cips_0_FPD_CCI_NOC_1_RVALID),
        .FPD_CCI_NOC_1_wdata(versal_cips_0_FPD_CCI_NOC_1_WDATA),
        .FPD_CCI_NOC_1_wlast(versal_cips_0_FPD_CCI_NOC_1_WLAST),
        .FPD_CCI_NOC_1_wready(versal_cips_0_FPD_CCI_NOC_1_WREADY),
        .FPD_CCI_NOC_1_wstrb(versal_cips_0_FPD_CCI_NOC_1_WSTRB),
        .FPD_CCI_NOC_1_wuser(versal_cips_0_FPD_CCI_NOC_1_WUSER),
        .FPD_CCI_NOC_1_wvalid(versal_cips_0_FPD_CCI_NOC_1_WVALID),
        .FPD_CCI_NOC_2_araddr(versal_cips_0_FPD_CCI_NOC_2_ARADDR),
        .FPD_CCI_NOC_2_arburst(versal_cips_0_FPD_CCI_NOC_2_ARBURST),
        .FPD_CCI_NOC_2_arcache(versal_cips_0_FPD_CCI_NOC_2_ARCACHE),
        .FPD_CCI_NOC_2_arid(versal_cips_0_FPD_CCI_NOC_2_ARID),
        .FPD_CCI_NOC_2_arlen(versal_cips_0_FPD_CCI_NOC_2_ARLEN),
        .FPD_CCI_NOC_2_arlock(versal_cips_0_FPD_CCI_NOC_2_ARLOCK),
        .FPD_CCI_NOC_2_arprot(versal_cips_0_FPD_CCI_NOC_2_ARPROT),
        .FPD_CCI_NOC_2_arqos(versal_cips_0_FPD_CCI_NOC_2_ARQOS),
        .FPD_CCI_NOC_2_arready(versal_cips_0_FPD_CCI_NOC_2_ARREADY),
        .FPD_CCI_NOC_2_arsize(versal_cips_0_FPD_CCI_NOC_2_ARSIZE),
        .FPD_CCI_NOC_2_aruser(versal_cips_0_FPD_CCI_NOC_2_ARUSER),
        .FPD_CCI_NOC_2_arvalid(versal_cips_0_FPD_CCI_NOC_2_ARVALID),
        .FPD_CCI_NOC_2_awaddr(versal_cips_0_FPD_CCI_NOC_2_AWADDR),
        .FPD_CCI_NOC_2_awburst(versal_cips_0_FPD_CCI_NOC_2_AWBURST),
        .FPD_CCI_NOC_2_awcache(versal_cips_0_FPD_CCI_NOC_2_AWCACHE),
        .FPD_CCI_NOC_2_awid(versal_cips_0_FPD_CCI_NOC_2_AWID),
        .FPD_CCI_NOC_2_awlen(versal_cips_0_FPD_CCI_NOC_2_AWLEN),
        .FPD_CCI_NOC_2_awlock(versal_cips_0_FPD_CCI_NOC_2_AWLOCK),
        .FPD_CCI_NOC_2_awprot(versal_cips_0_FPD_CCI_NOC_2_AWPROT),
        .FPD_CCI_NOC_2_awqos(versal_cips_0_FPD_CCI_NOC_2_AWQOS),
        .FPD_CCI_NOC_2_awready(versal_cips_0_FPD_CCI_NOC_2_AWREADY),
        .FPD_CCI_NOC_2_awsize(versal_cips_0_FPD_CCI_NOC_2_AWSIZE),
        .FPD_CCI_NOC_2_awuser(versal_cips_0_FPD_CCI_NOC_2_AWUSER),
        .FPD_CCI_NOC_2_awvalid(versal_cips_0_FPD_CCI_NOC_2_AWVALID),
        .FPD_CCI_NOC_2_bid(versal_cips_0_FPD_CCI_NOC_2_BID),
        .FPD_CCI_NOC_2_bready(versal_cips_0_FPD_CCI_NOC_2_BREADY),
        .FPD_CCI_NOC_2_bresp(versal_cips_0_FPD_CCI_NOC_2_BRESP),
        .FPD_CCI_NOC_2_bvalid(versal_cips_0_FPD_CCI_NOC_2_BVALID),
        .FPD_CCI_NOC_2_rdata(versal_cips_0_FPD_CCI_NOC_2_RDATA),
        .FPD_CCI_NOC_2_rid(versal_cips_0_FPD_CCI_NOC_2_RID),
        .FPD_CCI_NOC_2_rlast(versal_cips_0_FPD_CCI_NOC_2_RLAST),
        .FPD_CCI_NOC_2_rready(versal_cips_0_FPD_CCI_NOC_2_RREADY),
        .FPD_CCI_NOC_2_rresp(versal_cips_0_FPD_CCI_NOC_2_RRESP),
        .FPD_CCI_NOC_2_rvalid(versal_cips_0_FPD_CCI_NOC_2_RVALID),
        .FPD_CCI_NOC_2_wdata(versal_cips_0_FPD_CCI_NOC_2_WDATA),
        .FPD_CCI_NOC_2_wlast(versal_cips_0_FPD_CCI_NOC_2_WLAST),
        .FPD_CCI_NOC_2_wready(versal_cips_0_FPD_CCI_NOC_2_WREADY),
        .FPD_CCI_NOC_2_wstrb(versal_cips_0_FPD_CCI_NOC_2_WSTRB),
        .FPD_CCI_NOC_2_wuser(versal_cips_0_FPD_CCI_NOC_2_WUSER),
        .FPD_CCI_NOC_2_wvalid(versal_cips_0_FPD_CCI_NOC_2_WVALID),
        .FPD_CCI_NOC_3_araddr(versal_cips_0_FPD_CCI_NOC_3_ARADDR),
        .FPD_CCI_NOC_3_arburst(versal_cips_0_FPD_CCI_NOC_3_ARBURST),
        .FPD_CCI_NOC_3_arcache(versal_cips_0_FPD_CCI_NOC_3_ARCACHE),
        .FPD_CCI_NOC_3_arid(versal_cips_0_FPD_CCI_NOC_3_ARID),
        .FPD_CCI_NOC_3_arlen(versal_cips_0_FPD_CCI_NOC_3_ARLEN),
        .FPD_CCI_NOC_3_arlock(versal_cips_0_FPD_CCI_NOC_3_ARLOCK),
        .FPD_CCI_NOC_3_arprot(versal_cips_0_FPD_CCI_NOC_3_ARPROT),
        .FPD_CCI_NOC_3_arqos(versal_cips_0_FPD_CCI_NOC_3_ARQOS),
        .FPD_CCI_NOC_3_arready(versal_cips_0_FPD_CCI_NOC_3_ARREADY),
        .FPD_CCI_NOC_3_arsize(versal_cips_0_FPD_CCI_NOC_3_ARSIZE),
        .FPD_CCI_NOC_3_aruser(versal_cips_0_FPD_CCI_NOC_3_ARUSER),
        .FPD_CCI_NOC_3_arvalid(versal_cips_0_FPD_CCI_NOC_3_ARVALID),
        .FPD_CCI_NOC_3_awaddr(versal_cips_0_FPD_CCI_NOC_3_AWADDR),
        .FPD_CCI_NOC_3_awburst(versal_cips_0_FPD_CCI_NOC_3_AWBURST),
        .FPD_CCI_NOC_3_awcache(versal_cips_0_FPD_CCI_NOC_3_AWCACHE),
        .FPD_CCI_NOC_3_awid(versal_cips_0_FPD_CCI_NOC_3_AWID),
        .FPD_CCI_NOC_3_awlen(versal_cips_0_FPD_CCI_NOC_3_AWLEN),
        .FPD_CCI_NOC_3_awlock(versal_cips_0_FPD_CCI_NOC_3_AWLOCK),
        .FPD_CCI_NOC_3_awprot(versal_cips_0_FPD_CCI_NOC_3_AWPROT),
        .FPD_CCI_NOC_3_awqos(versal_cips_0_FPD_CCI_NOC_3_AWQOS),
        .FPD_CCI_NOC_3_awready(versal_cips_0_FPD_CCI_NOC_3_AWREADY),
        .FPD_CCI_NOC_3_awsize(versal_cips_0_FPD_CCI_NOC_3_AWSIZE),
        .FPD_CCI_NOC_3_awuser(versal_cips_0_FPD_CCI_NOC_3_AWUSER),
        .FPD_CCI_NOC_3_awvalid(versal_cips_0_FPD_CCI_NOC_3_AWVALID),
        .FPD_CCI_NOC_3_bid(versal_cips_0_FPD_CCI_NOC_3_BID),
        .FPD_CCI_NOC_3_bready(versal_cips_0_FPD_CCI_NOC_3_BREADY),
        .FPD_CCI_NOC_3_bresp(versal_cips_0_FPD_CCI_NOC_3_BRESP),
        .FPD_CCI_NOC_3_bvalid(versal_cips_0_FPD_CCI_NOC_3_BVALID),
        .FPD_CCI_NOC_3_rdata(versal_cips_0_FPD_CCI_NOC_3_RDATA),
        .FPD_CCI_NOC_3_rid(versal_cips_0_FPD_CCI_NOC_3_RID),
        .FPD_CCI_NOC_3_rlast(versal_cips_0_FPD_CCI_NOC_3_RLAST),
        .FPD_CCI_NOC_3_rready(versal_cips_0_FPD_CCI_NOC_3_RREADY),
        .FPD_CCI_NOC_3_rresp(versal_cips_0_FPD_CCI_NOC_3_RRESP),
        .FPD_CCI_NOC_3_rvalid(versal_cips_0_FPD_CCI_NOC_3_RVALID),
        .FPD_CCI_NOC_3_wdata(versal_cips_0_FPD_CCI_NOC_3_WDATA),
        .FPD_CCI_NOC_3_wlast(versal_cips_0_FPD_CCI_NOC_3_WLAST),
        .FPD_CCI_NOC_3_wready(versal_cips_0_FPD_CCI_NOC_3_WREADY),
        .FPD_CCI_NOC_3_wstrb(versal_cips_0_FPD_CCI_NOC_3_WSTRB),
        .FPD_CCI_NOC_3_wuser(versal_cips_0_FPD_CCI_NOC_3_WUSER),
        .FPD_CCI_NOC_3_wvalid(versal_cips_0_FPD_CCI_NOC_3_WVALID),
        .LPD_AXI_NOC_0_araddr(versal_cips_0_LPD_AXI_NOC_0_ARADDR),
        .LPD_AXI_NOC_0_arburst(versal_cips_0_LPD_AXI_NOC_0_ARBURST),
        .LPD_AXI_NOC_0_arcache(versal_cips_0_LPD_AXI_NOC_0_ARCACHE),
        .LPD_AXI_NOC_0_arid(versal_cips_0_LPD_AXI_NOC_0_ARID),
        .LPD_AXI_NOC_0_arlen(versal_cips_0_LPD_AXI_NOC_0_ARLEN),
        .LPD_AXI_NOC_0_arlock(versal_cips_0_LPD_AXI_NOC_0_ARLOCK),
        .LPD_AXI_NOC_0_arprot(versal_cips_0_LPD_AXI_NOC_0_ARPROT),
        .LPD_AXI_NOC_0_arqos(versal_cips_0_LPD_AXI_NOC_0_ARQOS),
        .LPD_AXI_NOC_0_arready(versal_cips_0_LPD_AXI_NOC_0_ARREADY),
        .LPD_AXI_NOC_0_arsize(versal_cips_0_LPD_AXI_NOC_0_ARSIZE),
        .LPD_AXI_NOC_0_aruser(versal_cips_0_LPD_AXI_NOC_0_ARUSER),
        .LPD_AXI_NOC_0_arvalid(versal_cips_0_LPD_AXI_NOC_0_ARVALID),
        .LPD_AXI_NOC_0_awaddr(versal_cips_0_LPD_AXI_NOC_0_AWADDR),
        .LPD_AXI_NOC_0_awburst(versal_cips_0_LPD_AXI_NOC_0_AWBURST),
        .LPD_AXI_NOC_0_awcache(versal_cips_0_LPD_AXI_NOC_0_AWCACHE),
        .LPD_AXI_NOC_0_awid(versal_cips_0_LPD_AXI_NOC_0_AWID),
        .LPD_AXI_NOC_0_awlen(versal_cips_0_LPD_AXI_NOC_0_AWLEN),
        .LPD_AXI_NOC_0_awlock(versal_cips_0_LPD_AXI_NOC_0_AWLOCK),
        .LPD_AXI_NOC_0_awprot(versal_cips_0_LPD_AXI_NOC_0_AWPROT),
        .LPD_AXI_NOC_0_awqos(versal_cips_0_LPD_AXI_NOC_0_AWQOS),
        .LPD_AXI_NOC_0_awready(versal_cips_0_LPD_AXI_NOC_0_AWREADY),
        .LPD_AXI_NOC_0_awsize(versal_cips_0_LPD_AXI_NOC_0_AWSIZE),
        .LPD_AXI_NOC_0_awuser(versal_cips_0_LPD_AXI_NOC_0_AWUSER),
        .LPD_AXI_NOC_0_awvalid(versal_cips_0_LPD_AXI_NOC_0_AWVALID),
        .LPD_AXI_NOC_0_bid(versal_cips_0_LPD_AXI_NOC_0_BID),
        .LPD_AXI_NOC_0_bready(versal_cips_0_LPD_AXI_NOC_0_BREADY),
        .LPD_AXI_NOC_0_bresp(versal_cips_0_LPD_AXI_NOC_0_BRESP),
        .LPD_AXI_NOC_0_bvalid(versal_cips_0_LPD_AXI_NOC_0_BVALID),
        .LPD_AXI_NOC_0_rdata(versal_cips_0_LPD_AXI_NOC_0_RDATA),
        .LPD_AXI_NOC_0_rid(versal_cips_0_LPD_AXI_NOC_0_RID),
        .LPD_AXI_NOC_0_rlast(versal_cips_0_LPD_AXI_NOC_0_RLAST),
        .LPD_AXI_NOC_0_rready(versal_cips_0_LPD_AXI_NOC_0_RREADY),
        .LPD_AXI_NOC_0_rresp(versal_cips_0_LPD_AXI_NOC_0_RRESP),
        .LPD_AXI_NOC_0_rvalid(versal_cips_0_LPD_AXI_NOC_0_RVALID),
        .LPD_AXI_NOC_0_wdata(versal_cips_0_LPD_AXI_NOC_0_WDATA),
        .LPD_AXI_NOC_0_wlast(versal_cips_0_LPD_AXI_NOC_0_WLAST),
        .LPD_AXI_NOC_0_wready(versal_cips_0_LPD_AXI_NOC_0_WREADY),
        .LPD_AXI_NOC_0_wstrb(versal_cips_0_LPD_AXI_NOC_0_WSTRB),
        .LPD_AXI_NOC_0_wvalid(versal_cips_0_LPD_AXI_NOC_0_WVALID),
        .M_AXI_LPD_araddr(versal_cips_0_M_AXI_LPD_ARADDR),
        .M_AXI_LPD_arburst(versal_cips_0_M_AXI_LPD_ARBURST),
        .M_AXI_LPD_arcache(versal_cips_0_M_AXI_LPD_ARCACHE),
        .M_AXI_LPD_arid(versal_cips_0_M_AXI_LPD_ARID),
        .M_AXI_LPD_arlen(versal_cips_0_M_AXI_LPD_ARLEN),
        .M_AXI_LPD_arlock(versal_cips_0_M_AXI_LPD_ARLOCK),
        .M_AXI_LPD_arprot(versal_cips_0_M_AXI_LPD_ARPROT),
        .M_AXI_LPD_arqos(versal_cips_0_M_AXI_LPD_ARQOS),
        .M_AXI_LPD_arready(versal_cips_0_M_AXI_LPD_ARREADY),
        .M_AXI_LPD_arsize(versal_cips_0_M_AXI_LPD_ARSIZE),
        .M_AXI_LPD_aruser(versal_cips_0_M_AXI_LPD_ARUSER),
        .M_AXI_LPD_arvalid(versal_cips_0_M_AXI_LPD_ARVALID),
        .M_AXI_LPD_awaddr(versal_cips_0_M_AXI_LPD_AWADDR),
        .M_AXI_LPD_awburst(versal_cips_0_M_AXI_LPD_AWBURST),
        .M_AXI_LPD_awcache(versal_cips_0_M_AXI_LPD_AWCACHE),
        .M_AXI_LPD_awid(versal_cips_0_M_AXI_LPD_AWID),
        .M_AXI_LPD_awlen(versal_cips_0_M_AXI_LPD_AWLEN),
        .M_AXI_LPD_awlock(versal_cips_0_M_AXI_LPD_AWLOCK),
        .M_AXI_LPD_awprot(versal_cips_0_M_AXI_LPD_AWPROT),
        .M_AXI_LPD_awqos(versal_cips_0_M_AXI_LPD_AWQOS),
        .M_AXI_LPD_awready(versal_cips_0_M_AXI_LPD_AWREADY),
        .M_AXI_LPD_awsize(versal_cips_0_M_AXI_LPD_AWSIZE),
        .M_AXI_LPD_awuser(versal_cips_0_M_AXI_LPD_AWUSER),
        .M_AXI_LPD_awvalid(versal_cips_0_M_AXI_LPD_AWVALID),
        .M_AXI_LPD_bid(versal_cips_0_M_AXI_LPD_BID),
        .M_AXI_LPD_bready(versal_cips_0_M_AXI_LPD_BREADY),
        .M_AXI_LPD_bresp(versal_cips_0_M_AXI_LPD_BRESP),
        .M_AXI_LPD_bvalid(versal_cips_0_M_AXI_LPD_BVALID),
        .M_AXI_LPD_rdata(versal_cips_0_M_AXI_LPD_RDATA),
        .M_AXI_LPD_rid(versal_cips_0_M_AXI_LPD_RID),
        .M_AXI_LPD_rlast(versal_cips_0_M_AXI_LPD_RLAST),
        .M_AXI_LPD_rready(versal_cips_0_M_AXI_LPD_RREADY),
        .M_AXI_LPD_rresp(versal_cips_0_M_AXI_LPD_RRESP),
        .M_AXI_LPD_rvalid(versal_cips_0_M_AXI_LPD_RVALID),
        .M_AXI_LPD_wdata(versal_cips_0_M_AXI_LPD_WDATA),
        .M_AXI_LPD_wlast(versal_cips_0_M_AXI_LPD_WLAST),
        .M_AXI_LPD_wready(versal_cips_0_M_AXI_LPD_WREADY),
        .M_AXI_LPD_wstrb(versal_cips_0_M_AXI_LPD_WSTRB),
        .M_AXI_LPD_wvalid(versal_cips_0_M_AXI_LPD_WVALID),
        .PMC_NOC_AXI_0_araddr(versal_cips_0_PMC_NOC_AXI_0_ARADDR),
        .PMC_NOC_AXI_0_arburst(versal_cips_0_PMC_NOC_AXI_0_ARBURST),
        .PMC_NOC_AXI_0_arcache(versal_cips_0_PMC_NOC_AXI_0_ARCACHE),
        .PMC_NOC_AXI_0_arid(versal_cips_0_PMC_NOC_AXI_0_ARID),
        .PMC_NOC_AXI_0_arlen(versal_cips_0_PMC_NOC_AXI_0_ARLEN),
        .PMC_NOC_AXI_0_arlock(versal_cips_0_PMC_NOC_AXI_0_ARLOCK),
        .PMC_NOC_AXI_0_arprot(versal_cips_0_PMC_NOC_AXI_0_ARPROT),
        .PMC_NOC_AXI_0_arqos(versal_cips_0_PMC_NOC_AXI_0_ARQOS),
        .PMC_NOC_AXI_0_arready(versal_cips_0_PMC_NOC_AXI_0_ARREADY),
        .PMC_NOC_AXI_0_arregion(versal_cips_0_PMC_NOC_AXI_0_ARREGION),
        .PMC_NOC_AXI_0_arsize(versal_cips_0_PMC_NOC_AXI_0_ARSIZE),
        .PMC_NOC_AXI_0_aruser(versal_cips_0_PMC_NOC_AXI_0_ARUSER),
        .PMC_NOC_AXI_0_arvalid(versal_cips_0_PMC_NOC_AXI_0_ARVALID),
        .PMC_NOC_AXI_0_awaddr(versal_cips_0_PMC_NOC_AXI_0_AWADDR),
        .PMC_NOC_AXI_0_awburst(versal_cips_0_PMC_NOC_AXI_0_AWBURST),
        .PMC_NOC_AXI_0_awcache(versal_cips_0_PMC_NOC_AXI_0_AWCACHE),
        .PMC_NOC_AXI_0_awid(versal_cips_0_PMC_NOC_AXI_0_AWID),
        .PMC_NOC_AXI_0_awlen(versal_cips_0_PMC_NOC_AXI_0_AWLEN),
        .PMC_NOC_AXI_0_awlock(versal_cips_0_PMC_NOC_AXI_0_AWLOCK),
        .PMC_NOC_AXI_0_awprot(versal_cips_0_PMC_NOC_AXI_0_AWPROT),
        .PMC_NOC_AXI_0_awqos(versal_cips_0_PMC_NOC_AXI_0_AWQOS),
        .PMC_NOC_AXI_0_awready(versal_cips_0_PMC_NOC_AXI_0_AWREADY),
        .PMC_NOC_AXI_0_awregion(versal_cips_0_PMC_NOC_AXI_0_AWREGION),
        .PMC_NOC_AXI_0_awsize(versal_cips_0_PMC_NOC_AXI_0_AWSIZE),
        .PMC_NOC_AXI_0_awuser(versal_cips_0_PMC_NOC_AXI_0_AWUSER),
        .PMC_NOC_AXI_0_awvalid(versal_cips_0_PMC_NOC_AXI_0_AWVALID),
        .PMC_NOC_AXI_0_bid(versal_cips_0_PMC_NOC_AXI_0_BID),
        .PMC_NOC_AXI_0_bready(versal_cips_0_PMC_NOC_AXI_0_BREADY),
        .PMC_NOC_AXI_0_bresp(versal_cips_0_PMC_NOC_AXI_0_BRESP),
        .PMC_NOC_AXI_0_buser(versal_cips_0_PMC_NOC_AXI_0_BUSER),
        .PMC_NOC_AXI_0_bvalid(versal_cips_0_PMC_NOC_AXI_0_BVALID),
        .PMC_NOC_AXI_0_rdata(versal_cips_0_PMC_NOC_AXI_0_RDATA),
        .PMC_NOC_AXI_0_rid(versal_cips_0_PMC_NOC_AXI_0_RID),
        .PMC_NOC_AXI_0_rlast(versal_cips_0_PMC_NOC_AXI_0_RLAST),
        .PMC_NOC_AXI_0_rready(versal_cips_0_PMC_NOC_AXI_0_RREADY),
        .PMC_NOC_AXI_0_rresp(versal_cips_0_PMC_NOC_AXI_0_RRESP),
        .PMC_NOC_AXI_0_ruser(versal_cips_0_PMC_NOC_AXI_0_RUSER),
        .PMC_NOC_AXI_0_rvalid(versal_cips_0_PMC_NOC_AXI_0_RVALID),
        .PMC_NOC_AXI_0_wdata(versal_cips_0_PMC_NOC_AXI_0_WDATA),
        .PMC_NOC_AXI_0_wlast(versal_cips_0_PMC_NOC_AXI_0_WLAST),
        .PMC_NOC_AXI_0_wready(versal_cips_0_PMC_NOC_AXI_0_WREADY),
        .PMC_NOC_AXI_0_wstrb(versal_cips_0_PMC_NOC_AXI_0_WSTRB),
        .PMC_NOC_AXI_0_wuser(versal_cips_0_PMC_NOC_AXI_0_WUSER),
        .PMC_NOC_AXI_0_wvalid(versal_cips_0_PMC_NOC_AXI_0_WVALID),
        .fpd_cci_noc_axi0_clk(versal_cips_0_fpd_cci_noc_axi0_clk),
        .fpd_cci_noc_axi1_clk(versal_cips_0_fpd_cci_noc_axi1_clk),
        .fpd_cci_noc_axi2_clk(versal_cips_0_fpd_cci_noc_axi2_clk),
        .fpd_cci_noc_axi3_clk(versal_cips_0_fpd_cci_noc_axi3_clk),
        .lpd_axi_noc_clk(versal_cips_0_lpd_axi_noc_clk),
        .m_axi_lpd_aclk(versal_cips_0_pl0_ref_clk),
        .pl0_ref_clk(versal_cips_0_pl0_ref_clk),
        .pl0_resetn(versal_cips_0_pl0_resetn),
        .pl_ps_irq0(u_soc_irq_out),
        .pl_ps_irq1(1'b0),
        .pmc_axi_noc_axi0_clk(versal_cips_0_pmc_axi_noc_axi0_clk));
endmodule
