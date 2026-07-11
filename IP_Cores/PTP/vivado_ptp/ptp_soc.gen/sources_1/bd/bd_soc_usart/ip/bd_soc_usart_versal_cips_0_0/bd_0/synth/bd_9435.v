//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Command: generate_target bd_9435.bd
//Design : bd_9435
//Purpose: IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "bd_9435,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=bd_9435,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=2,numReposBlks=2,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=SBD,synth_mode=None}" *) (* HW_HANDOFF = "bd_soc_usart_versal_cips_0_0.hwdef" *) 
module bd_9435
   (FPD_CCI_NOC_0_araddr,
    FPD_CCI_NOC_0_arburst,
    FPD_CCI_NOC_0_arcache,
    FPD_CCI_NOC_0_arid,
    FPD_CCI_NOC_0_arlen,
    FPD_CCI_NOC_0_arlock,
    FPD_CCI_NOC_0_arprot,
    FPD_CCI_NOC_0_arqos,
    FPD_CCI_NOC_0_arready,
    FPD_CCI_NOC_0_arsize,
    FPD_CCI_NOC_0_aruser,
    FPD_CCI_NOC_0_arvalid,
    FPD_CCI_NOC_0_awaddr,
    FPD_CCI_NOC_0_awburst,
    FPD_CCI_NOC_0_awcache,
    FPD_CCI_NOC_0_awid,
    FPD_CCI_NOC_0_awlen,
    FPD_CCI_NOC_0_awlock,
    FPD_CCI_NOC_0_awprot,
    FPD_CCI_NOC_0_awqos,
    FPD_CCI_NOC_0_awready,
    FPD_CCI_NOC_0_awsize,
    FPD_CCI_NOC_0_awuser,
    FPD_CCI_NOC_0_awvalid,
    FPD_CCI_NOC_0_bid,
    FPD_CCI_NOC_0_bready,
    FPD_CCI_NOC_0_bresp,
    FPD_CCI_NOC_0_bvalid,
    FPD_CCI_NOC_0_rdata,
    FPD_CCI_NOC_0_rid,
    FPD_CCI_NOC_0_rlast,
    FPD_CCI_NOC_0_rready,
    FPD_CCI_NOC_0_rresp,
    FPD_CCI_NOC_0_rvalid,
    FPD_CCI_NOC_0_wdata,
    FPD_CCI_NOC_0_wlast,
    FPD_CCI_NOC_0_wready,
    FPD_CCI_NOC_0_wstrb,
    FPD_CCI_NOC_0_wuser,
    FPD_CCI_NOC_0_wvalid,
    FPD_CCI_NOC_1_araddr,
    FPD_CCI_NOC_1_arburst,
    FPD_CCI_NOC_1_arcache,
    FPD_CCI_NOC_1_arid,
    FPD_CCI_NOC_1_arlen,
    FPD_CCI_NOC_1_arlock,
    FPD_CCI_NOC_1_arprot,
    FPD_CCI_NOC_1_arqos,
    FPD_CCI_NOC_1_arready,
    FPD_CCI_NOC_1_arsize,
    FPD_CCI_NOC_1_aruser,
    FPD_CCI_NOC_1_arvalid,
    FPD_CCI_NOC_1_awaddr,
    FPD_CCI_NOC_1_awburst,
    FPD_CCI_NOC_1_awcache,
    FPD_CCI_NOC_1_awid,
    FPD_CCI_NOC_1_awlen,
    FPD_CCI_NOC_1_awlock,
    FPD_CCI_NOC_1_awprot,
    FPD_CCI_NOC_1_awqos,
    FPD_CCI_NOC_1_awready,
    FPD_CCI_NOC_1_awsize,
    FPD_CCI_NOC_1_awuser,
    FPD_CCI_NOC_1_awvalid,
    FPD_CCI_NOC_1_bid,
    FPD_CCI_NOC_1_bready,
    FPD_CCI_NOC_1_bresp,
    FPD_CCI_NOC_1_bvalid,
    FPD_CCI_NOC_1_rdata,
    FPD_CCI_NOC_1_rid,
    FPD_CCI_NOC_1_rlast,
    FPD_CCI_NOC_1_rready,
    FPD_CCI_NOC_1_rresp,
    FPD_CCI_NOC_1_rvalid,
    FPD_CCI_NOC_1_wdata,
    FPD_CCI_NOC_1_wlast,
    FPD_CCI_NOC_1_wready,
    FPD_CCI_NOC_1_wstrb,
    FPD_CCI_NOC_1_wuser,
    FPD_CCI_NOC_1_wvalid,
    FPD_CCI_NOC_2_araddr,
    FPD_CCI_NOC_2_arburst,
    FPD_CCI_NOC_2_arcache,
    FPD_CCI_NOC_2_arid,
    FPD_CCI_NOC_2_arlen,
    FPD_CCI_NOC_2_arlock,
    FPD_CCI_NOC_2_arprot,
    FPD_CCI_NOC_2_arqos,
    FPD_CCI_NOC_2_arready,
    FPD_CCI_NOC_2_arsize,
    FPD_CCI_NOC_2_aruser,
    FPD_CCI_NOC_2_arvalid,
    FPD_CCI_NOC_2_awaddr,
    FPD_CCI_NOC_2_awburst,
    FPD_CCI_NOC_2_awcache,
    FPD_CCI_NOC_2_awid,
    FPD_CCI_NOC_2_awlen,
    FPD_CCI_NOC_2_awlock,
    FPD_CCI_NOC_2_awprot,
    FPD_CCI_NOC_2_awqos,
    FPD_CCI_NOC_2_awready,
    FPD_CCI_NOC_2_awsize,
    FPD_CCI_NOC_2_awuser,
    FPD_CCI_NOC_2_awvalid,
    FPD_CCI_NOC_2_bid,
    FPD_CCI_NOC_2_bready,
    FPD_CCI_NOC_2_bresp,
    FPD_CCI_NOC_2_bvalid,
    FPD_CCI_NOC_2_rdata,
    FPD_CCI_NOC_2_rid,
    FPD_CCI_NOC_2_rlast,
    FPD_CCI_NOC_2_rready,
    FPD_CCI_NOC_2_rresp,
    FPD_CCI_NOC_2_rvalid,
    FPD_CCI_NOC_2_wdata,
    FPD_CCI_NOC_2_wlast,
    FPD_CCI_NOC_2_wready,
    FPD_CCI_NOC_2_wstrb,
    FPD_CCI_NOC_2_wuser,
    FPD_CCI_NOC_2_wvalid,
    FPD_CCI_NOC_3_araddr,
    FPD_CCI_NOC_3_arburst,
    FPD_CCI_NOC_3_arcache,
    FPD_CCI_NOC_3_arid,
    FPD_CCI_NOC_3_arlen,
    FPD_CCI_NOC_3_arlock,
    FPD_CCI_NOC_3_arprot,
    FPD_CCI_NOC_3_arqos,
    FPD_CCI_NOC_3_arready,
    FPD_CCI_NOC_3_arsize,
    FPD_CCI_NOC_3_aruser,
    FPD_CCI_NOC_3_arvalid,
    FPD_CCI_NOC_3_awaddr,
    FPD_CCI_NOC_3_awburst,
    FPD_CCI_NOC_3_awcache,
    FPD_CCI_NOC_3_awid,
    FPD_CCI_NOC_3_awlen,
    FPD_CCI_NOC_3_awlock,
    FPD_CCI_NOC_3_awprot,
    FPD_CCI_NOC_3_awqos,
    FPD_CCI_NOC_3_awready,
    FPD_CCI_NOC_3_awsize,
    FPD_CCI_NOC_3_awuser,
    FPD_CCI_NOC_3_awvalid,
    FPD_CCI_NOC_3_bid,
    FPD_CCI_NOC_3_bready,
    FPD_CCI_NOC_3_bresp,
    FPD_CCI_NOC_3_bvalid,
    FPD_CCI_NOC_3_rdata,
    FPD_CCI_NOC_3_rid,
    FPD_CCI_NOC_3_rlast,
    FPD_CCI_NOC_3_rready,
    FPD_CCI_NOC_3_rresp,
    FPD_CCI_NOC_3_rvalid,
    FPD_CCI_NOC_3_wdata,
    FPD_CCI_NOC_3_wlast,
    FPD_CCI_NOC_3_wready,
    FPD_CCI_NOC_3_wstrb,
    FPD_CCI_NOC_3_wuser,
    FPD_CCI_NOC_3_wvalid,
    LPD_AXI_NOC_0_araddr,
    LPD_AXI_NOC_0_arburst,
    LPD_AXI_NOC_0_arcache,
    LPD_AXI_NOC_0_arid,
    LPD_AXI_NOC_0_arlen,
    LPD_AXI_NOC_0_arlock,
    LPD_AXI_NOC_0_arprot,
    LPD_AXI_NOC_0_arqos,
    LPD_AXI_NOC_0_arready,
    LPD_AXI_NOC_0_arsize,
    LPD_AXI_NOC_0_aruser,
    LPD_AXI_NOC_0_arvalid,
    LPD_AXI_NOC_0_awaddr,
    LPD_AXI_NOC_0_awburst,
    LPD_AXI_NOC_0_awcache,
    LPD_AXI_NOC_0_awid,
    LPD_AXI_NOC_0_awlen,
    LPD_AXI_NOC_0_awlock,
    LPD_AXI_NOC_0_awprot,
    LPD_AXI_NOC_0_awqos,
    LPD_AXI_NOC_0_awready,
    LPD_AXI_NOC_0_awsize,
    LPD_AXI_NOC_0_awuser,
    LPD_AXI_NOC_0_awvalid,
    LPD_AXI_NOC_0_bid,
    LPD_AXI_NOC_0_bready,
    LPD_AXI_NOC_0_bresp,
    LPD_AXI_NOC_0_bvalid,
    LPD_AXI_NOC_0_rdata,
    LPD_AXI_NOC_0_rid,
    LPD_AXI_NOC_0_rlast,
    LPD_AXI_NOC_0_rready,
    LPD_AXI_NOC_0_rresp,
    LPD_AXI_NOC_0_rvalid,
    LPD_AXI_NOC_0_wdata,
    LPD_AXI_NOC_0_wlast,
    LPD_AXI_NOC_0_wready,
    LPD_AXI_NOC_0_wstrb,
    LPD_AXI_NOC_0_wvalid,
    M_AXI_LPD_araddr,
    M_AXI_LPD_arburst,
    M_AXI_LPD_arcache,
    M_AXI_LPD_arid,
    M_AXI_LPD_arlen,
    M_AXI_LPD_arlock,
    M_AXI_LPD_arprot,
    M_AXI_LPD_arqos,
    M_AXI_LPD_arready,
    M_AXI_LPD_arsize,
    M_AXI_LPD_aruser,
    M_AXI_LPD_arvalid,
    M_AXI_LPD_awaddr,
    M_AXI_LPD_awburst,
    M_AXI_LPD_awcache,
    M_AXI_LPD_awid,
    M_AXI_LPD_awlen,
    M_AXI_LPD_awlock,
    M_AXI_LPD_awprot,
    M_AXI_LPD_awqos,
    M_AXI_LPD_awready,
    M_AXI_LPD_awsize,
    M_AXI_LPD_awuser,
    M_AXI_LPD_awvalid,
    M_AXI_LPD_bid,
    M_AXI_LPD_bready,
    M_AXI_LPD_bresp,
    M_AXI_LPD_bvalid,
    M_AXI_LPD_rdata,
    M_AXI_LPD_rid,
    M_AXI_LPD_rlast,
    M_AXI_LPD_rready,
    M_AXI_LPD_rresp,
    M_AXI_LPD_rvalid,
    M_AXI_LPD_wdata,
    M_AXI_LPD_wlast,
    M_AXI_LPD_wready,
    M_AXI_LPD_wstrb,
    M_AXI_LPD_wvalid,
    PMC_NOC_AXI_0_araddr,
    PMC_NOC_AXI_0_arburst,
    PMC_NOC_AXI_0_arcache,
    PMC_NOC_AXI_0_arid,
    PMC_NOC_AXI_0_arlen,
    PMC_NOC_AXI_0_arlock,
    PMC_NOC_AXI_0_arprot,
    PMC_NOC_AXI_0_arqos,
    PMC_NOC_AXI_0_arready,
    PMC_NOC_AXI_0_arregion,
    PMC_NOC_AXI_0_arsize,
    PMC_NOC_AXI_0_aruser,
    PMC_NOC_AXI_0_arvalid,
    PMC_NOC_AXI_0_awaddr,
    PMC_NOC_AXI_0_awburst,
    PMC_NOC_AXI_0_awcache,
    PMC_NOC_AXI_0_awid,
    PMC_NOC_AXI_0_awlen,
    PMC_NOC_AXI_0_awlock,
    PMC_NOC_AXI_0_awprot,
    PMC_NOC_AXI_0_awqos,
    PMC_NOC_AXI_0_awready,
    PMC_NOC_AXI_0_awregion,
    PMC_NOC_AXI_0_awsize,
    PMC_NOC_AXI_0_awuser,
    PMC_NOC_AXI_0_awvalid,
    PMC_NOC_AXI_0_bid,
    PMC_NOC_AXI_0_bready,
    PMC_NOC_AXI_0_bresp,
    PMC_NOC_AXI_0_buser,
    PMC_NOC_AXI_0_bvalid,
    PMC_NOC_AXI_0_rdata,
    PMC_NOC_AXI_0_rid,
    PMC_NOC_AXI_0_rlast,
    PMC_NOC_AXI_0_rready,
    PMC_NOC_AXI_0_rresp,
    PMC_NOC_AXI_0_ruser,
    PMC_NOC_AXI_0_rvalid,
    PMC_NOC_AXI_0_wdata,
    PMC_NOC_AXI_0_wid,
    PMC_NOC_AXI_0_wlast,
    PMC_NOC_AXI_0_wready,
    PMC_NOC_AXI_0_wstrb,
    PMC_NOC_AXI_0_wuser,
    PMC_NOC_AXI_0_wvalid,
    fpd_cci_noc_axi0_clk,
    fpd_cci_noc_axi1_clk,
    fpd_cci_noc_axi2_clk,
    fpd_cci_noc_axi3_clk,
    gem0_tsu_timer_cnt,
    lpd_axi_noc_clk,
    m_axi_lpd_aclk,
    pl0_ref_clk,
    pl0_resetn,
    pl_ps_irq0,
    pl_ps_irq1,
    pmc_axi_noc_axi0_clk);
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FPD_CCI_NOC_0, ADDR_WIDTH 64, ARUSER_WIDTH 18, AWUSER_WIDTH 18, BUSER_WIDTH 0, CATEGORY noc, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk, DATA_WIDTH 128, FREQ_HZ 550000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 16, INDEX 0, INSERT_VIP 0, MAX_BURST_LENGTH 256, MY_CATEGORY ps_cci, NUM_READ_OUTSTANDING 64, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 64, NUM_WRITE_THREADS 1, PHASE 0.0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 17" *) output [63:0]FPD_CCI_NOC_0_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARBURST" *) output [1:0]FPD_CCI_NOC_0_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARCACHE" *) output [3:0]FPD_CCI_NOC_0_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARID" *) output [15:0]FPD_CCI_NOC_0_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARLEN" *) output [7:0]FPD_CCI_NOC_0_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARLOCK" *) output FPD_CCI_NOC_0_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARPROT" *) output [2:0]FPD_CCI_NOC_0_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARQOS" *) output [3:0]FPD_CCI_NOC_0_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARREADY" *) input FPD_CCI_NOC_0_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARSIZE" *) output [2:0]FPD_CCI_NOC_0_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARUSER" *) output [17:0]FPD_CCI_NOC_0_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARVALID" *) output FPD_CCI_NOC_0_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWADDR" *) output [63:0]FPD_CCI_NOC_0_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWBURST" *) output [1:0]FPD_CCI_NOC_0_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWCACHE" *) output [3:0]FPD_CCI_NOC_0_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWID" *) output [15:0]FPD_CCI_NOC_0_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWLEN" *) output [7:0]FPD_CCI_NOC_0_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWLOCK" *) output FPD_CCI_NOC_0_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWPROT" *) output [2:0]FPD_CCI_NOC_0_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWQOS" *) output [3:0]FPD_CCI_NOC_0_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWREADY" *) input FPD_CCI_NOC_0_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWSIZE" *) output [2:0]FPD_CCI_NOC_0_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWUSER" *) output [17:0]FPD_CCI_NOC_0_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWVALID" *) output FPD_CCI_NOC_0_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BID" *) input [15:0]FPD_CCI_NOC_0_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BREADY" *) output FPD_CCI_NOC_0_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BRESP" *) input [1:0]FPD_CCI_NOC_0_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BVALID" *) input FPD_CCI_NOC_0_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RDATA" *) input [127:0]FPD_CCI_NOC_0_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RID" *) input [15:0]FPD_CCI_NOC_0_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RLAST" *) input FPD_CCI_NOC_0_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RREADY" *) output FPD_CCI_NOC_0_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RRESP" *) input [1:0]FPD_CCI_NOC_0_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RVALID" *) input FPD_CCI_NOC_0_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WDATA" *) output [127:0]FPD_CCI_NOC_0_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WLAST" *) output FPD_CCI_NOC_0_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WREADY" *) input FPD_CCI_NOC_0_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WSTRB" *) output [15:0]FPD_CCI_NOC_0_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WUSER" *) output [16:0]FPD_CCI_NOC_0_wuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WVALID" *) output FPD_CCI_NOC_0_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FPD_CCI_NOC_1, ADDR_WIDTH 64, ARUSER_WIDTH 18, AWUSER_WIDTH 18, BUSER_WIDTH 0, CATEGORY noc, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk, DATA_WIDTH 128, FREQ_HZ 550000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 16, INDEX 1, INSERT_VIP 0, MAX_BURST_LENGTH 256, MY_CATEGORY ps_cci, NUM_READ_OUTSTANDING 64, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 64, NUM_WRITE_THREADS 1, PHASE 0.0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 17" *) output [63:0]FPD_CCI_NOC_1_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARBURST" *) output [1:0]FPD_CCI_NOC_1_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARCACHE" *) output [3:0]FPD_CCI_NOC_1_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARID" *) output [15:0]FPD_CCI_NOC_1_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARLEN" *) output [7:0]FPD_CCI_NOC_1_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARLOCK" *) output FPD_CCI_NOC_1_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARPROT" *) output [2:0]FPD_CCI_NOC_1_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARQOS" *) output [3:0]FPD_CCI_NOC_1_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARREADY" *) input FPD_CCI_NOC_1_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARSIZE" *) output [2:0]FPD_CCI_NOC_1_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARUSER" *) output [17:0]FPD_CCI_NOC_1_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARVALID" *) output FPD_CCI_NOC_1_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWADDR" *) output [63:0]FPD_CCI_NOC_1_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWBURST" *) output [1:0]FPD_CCI_NOC_1_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWCACHE" *) output [3:0]FPD_CCI_NOC_1_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWID" *) output [15:0]FPD_CCI_NOC_1_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWLEN" *) output [7:0]FPD_CCI_NOC_1_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWLOCK" *) output FPD_CCI_NOC_1_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWPROT" *) output [2:0]FPD_CCI_NOC_1_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWQOS" *) output [3:0]FPD_CCI_NOC_1_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWREADY" *) input FPD_CCI_NOC_1_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWSIZE" *) output [2:0]FPD_CCI_NOC_1_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWUSER" *) output [17:0]FPD_CCI_NOC_1_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWVALID" *) output FPD_CCI_NOC_1_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BID" *) input [15:0]FPD_CCI_NOC_1_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BREADY" *) output FPD_CCI_NOC_1_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BRESP" *) input [1:0]FPD_CCI_NOC_1_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BVALID" *) input FPD_CCI_NOC_1_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RDATA" *) input [127:0]FPD_CCI_NOC_1_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RID" *) input [15:0]FPD_CCI_NOC_1_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RLAST" *) input FPD_CCI_NOC_1_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RREADY" *) output FPD_CCI_NOC_1_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RRESP" *) input [1:0]FPD_CCI_NOC_1_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RVALID" *) input FPD_CCI_NOC_1_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WDATA" *) output [127:0]FPD_CCI_NOC_1_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WLAST" *) output FPD_CCI_NOC_1_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WREADY" *) input FPD_CCI_NOC_1_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WSTRB" *) output [15:0]FPD_CCI_NOC_1_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WUSER" *) output [16:0]FPD_CCI_NOC_1_wuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WVALID" *) output FPD_CCI_NOC_1_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FPD_CCI_NOC_2, ADDR_WIDTH 64, ARUSER_WIDTH 18, AWUSER_WIDTH 18, BUSER_WIDTH 0, CATEGORY noc, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk, DATA_WIDTH 128, FREQ_HZ 550000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 16, INDEX 2, INSERT_VIP 0, MAX_BURST_LENGTH 256, MY_CATEGORY ps_cci, NUM_READ_OUTSTANDING 64, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 64, NUM_WRITE_THREADS 1, PHASE 0.0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 17" *) output [63:0]FPD_CCI_NOC_2_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARBURST" *) output [1:0]FPD_CCI_NOC_2_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARCACHE" *) output [3:0]FPD_CCI_NOC_2_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARID" *) output [15:0]FPD_CCI_NOC_2_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARLEN" *) output [7:0]FPD_CCI_NOC_2_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARLOCK" *) output FPD_CCI_NOC_2_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARPROT" *) output [2:0]FPD_CCI_NOC_2_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARQOS" *) output [3:0]FPD_CCI_NOC_2_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARREADY" *) input FPD_CCI_NOC_2_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARSIZE" *) output [2:0]FPD_CCI_NOC_2_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARUSER" *) output [17:0]FPD_CCI_NOC_2_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARVALID" *) output FPD_CCI_NOC_2_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWADDR" *) output [63:0]FPD_CCI_NOC_2_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWBURST" *) output [1:0]FPD_CCI_NOC_2_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWCACHE" *) output [3:0]FPD_CCI_NOC_2_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWID" *) output [15:0]FPD_CCI_NOC_2_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWLEN" *) output [7:0]FPD_CCI_NOC_2_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWLOCK" *) output FPD_CCI_NOC_2_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWPROT" *) output [2:0]FPD_CCI_NOC_2_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWQOS" *) output [3:0]FPD_CCI_NOC_2_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWREADY" *) input FPD_CCI_NOC_2_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWSIZE" *) output [2:0]FPD_CCI_NOC_2_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWUSER" *) output [17:0]FPD_CCI_NOC_2_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWVALID" *) output FPD_CCI_NOC_2_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BID" *) input [15:0]FPD_CCI_NOC_2_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BREADY" *) output FPD_CCI_NOC_2_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BRESP" *) input [1:0]FPD_CCI_NOC_2_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BVALID" *) input FPD_CCI_NOC_2_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RDATA" *) input [127:0]FPD_CCI_NOC_2_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RID" *) input [15:0]FPD_CCI_NOC_2_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RLAST" *) input FPD_CCI_NOC_2_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RREADY" *) output FPD_CCI_NOC_2_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RRESP" *) input [1:0]FPD_CCI_NOC_2_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RVALID" *) input FPD_CCI_NOC_2_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WDATA" *) output [127:0]FPD_CCI_NOC_2_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WLAST" *) output FPD_CCI_NOC_2_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WREADY" *) input FPD_CCI_NOC_2_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WSTRB" *) output [15:0]FPD_CCI_NOC_2_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WUSER" *) output [16:0]FPD_CCI_NOC_2_wuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WVALID" *) output FPD_CCI_NOC_2_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FPD_CCI_NOC_3, ADDR_WIDTH 64, ARUSER_WIDTH 18, AWUSER_WIDTH 18, BUSER_WIDTH 0, CATEGORY noc, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk, DATA_WIDTH 128, FREQ_HZ 550000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 16, INDEX 3, INSERT_VIP 0, MAX_BURST_LENGTH 256, MY_CATEGORY ps_cci, NUM_READ_OUTSTANDING 64, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 64, NUM_WRITE_THREADS 1, PHASE 0.0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 17" *) output [63:0]FPD_CCI_NOC_3_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARBURST" *) output [1:0]FPD_CCI_NOC_3_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARCACHE" *) output [3:0]FPD_CCI_NOC_3_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARID" *) output [15:0]FPD_CCI_NOC_3_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARLEN" *) output [7:0]FPD_CCI_NOC_3_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARLOCK" *) output FPD_CCI_NOC_3_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARPROT" *) output [2:0]FPD_CCI_NOC_3_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARQOS" *) output [3:0]FPD_CCI_NOC_3_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARREADY" *) input FPD_CCI_NOC_3_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARSIZE" *) output [2:0]FPD_CCI_NOC_3_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARUSER" *) output [17:0]FPD_CCI_NOC_3_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARVALID" *) output FPD_CCI_NOC_3_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWADDR" *) output [63:0]FPD_CCI_NOC_3_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWBURST" *) output [1:0]FPD_CCI_NOC_3_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWCACHE" *) output [3:0]FPD_CCI_NOC_3_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWID" *) output [15:0]FPD_CCI_NOC_3_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWLEN" *) output [7:0]FPD_CCI_NOC_3_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWLOCK" *) output FPD_CCI_NOC_3_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWPROT" *) output [2:0]FPD_CCI_NOC_3_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWQOS" *) output [3:0]FPD_CCI_NOC_3_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWREADY" *) input FPD_CCI_NOC_3_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWSIZE" *) output [2:0]FPD_CCI_NOC_3_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWUSER" *) output [17:0]FPD_CCI_NOC_3_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWVALID" *) output FPD_CCI_NOC_3_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BID" *) input [15:0]FPD_CCI_NOC_3_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BREADY" *) output FPD_CCI_NOC_3_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BRESP" *) input [1:0]FPD_CCI_NOC_3_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BVALID" *) input FPD_CCI_NOC_3_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RDATA" *) input [127:0]FPD_CCI_NOC_3_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RID" *) input [15:0]FPD_CCI_NOC_3_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RLAST" *) input FPD_CCI_NOC_3_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RREADY" *) output FPD_CCI_NOC_3_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RRESP" *) input [1:0]FPD_CCI_NOC_3_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RVALID" *) input FPD_CCI_NOC_3_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WDATA" *) output [127:0]FPD_CCI_NOC_3_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WLAST" *) output FPD_CCI_NOC_3_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WREADY" *) input FPD_CCI_NOC_3_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WSTRB" *) output [15:0]FPD_CCI_NOC_3_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WUSER" *) output [16:0]FPD_CCI_NOC_3_wuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WVALID" *) output FPD_CCI_NOC_3_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME LPD_AXI_NOC_0, ADDR_WIDTH 64, ARUSER_WIDTH 18, AWUSER_WIDTH 18, BUSER_WIDTH 0, CATEGORY noc, CLK_DOMAIN bd_9435_pspmc_0_0_lpd_axi_noc_clk, DATA_WIDTH 128, FREQ_HZ 400000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 16, INDEX 0, INSERT_VIP 0, MAX_BURST_LENGTH 256, MY_CATEGORY ps_rpu, NUM_READ_OUTSTANDING 64, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 64, NUM_WRITE_THREADS 1, PHASE 0.0, PHYSICAL_CHANNEL PS_RPU_TO_NOC_NMU, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [63:0]LPD_AXI_NOC_0_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARBURST" *) output [1:0]LPD_AXI_NOC_0_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARCACHE" *) output [3:0]LPD_AXI_NOC_0_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARID" *) output [15:0]LPD_AXI_NOC_0_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARLEN" *) output [7:0]LPD_AXI_NOC_0_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARLOCK" *) output LPD_AXI_NOC_0_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARPROT" *) output [2:0]LPD_AXI_NOC_0_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARQOS" *) output [3:0]LPD_AXI_NOC_0_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARREADY" *) input LPD_AXI_NOC_0_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARSIZE" *) output [2:0]LPD_AXI_NOC_0_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARUSER" *) output [17:0]LPD_AXI_NOC_0_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARVALID" *) output LPD_AXI_NOC_0_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWADDR" *) output [63:0]LPD_AXI_NOC_0_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWBURST" *) output [1:0]LPD_AXI_NOC_0_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWCACHE" *) output [3:0]LPD_AXI_NOC_0_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWID" *) output [15:0]LPD_AXI_NOC_0_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWLEN" *) output [7:0]LPD_AXI_NOC_0_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWLOCK" *) output LPD_AXI_NOC_0_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWPROT" *) output [2:0]LPD_AXI_NOC_0_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWQOS" *) output [3:0]LPD_AXI_NOC_0_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWREADY" *) input LPD_AXI_NOC_0_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWSIZE" *) output [2:0]LPD_AXI_NOC_0_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWUSER" *) output [17:0]LPD_AXI_NOC_0_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWVALID" *) output LPD_AXI_NOC_0_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BID" *) input [15:0]LPD_AXI_NOC_0_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BREADY" *) output LPD_AXI_NOC_0_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BRESP" *) input [1:0]LPD_AXI_NOC_0_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BVALID" *) input LPD_AXI_NOC_0_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RDATA" *) input [127:0]LPD_AXI_NOC_0_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RID" *) input [15:0]LPD_AXI_NOC_0_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RLAST" *) input LPD_AXI_NOC_0_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RREADY" *) output LPD_AXI_NOC_0_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RRESP" *) input [1:0]LPD_AXI_NOC_0_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RVALID" *) input LPD_AXI_NOC_0_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WDATA" *) output [127:0]LPD_AXI_NOC_0_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WLAST" *) output LPD_AXI_NOC_0_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WREADY" *) input LPD_AXI_NOC_0_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WSTRB" *) output [15:0]LPD_AXI_NOC_0_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WVALID" *) output LPD_AXI_NOC_0_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_LPD, ADDR_WIDTH 44, ARUSER_WIDTH 16, AWUSER_WIDTH 16, BUSER_WIDTH 0, CATEGORY pl, CLK_DOMAIN bd_9435_pspmc_0_0_pl0_ref_clk, DATA_WIDTH 128, FREQ_HZ 100000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 16, INSERT_VIP 0, MAX_BURST_LENGTH 256, MY_CATEGORY ps, NUM_READ_OUTSTANDING 2, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 2, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [43:0]M_AXI_LPD_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARBURST" *) output [1:0]M_AXI_LPD_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARCACHE" *) output [3:0]M_AXI_LPD_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARID" *) output [15:0]M_AXI_LPD_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARLEN" *) output [7:0]M_AXI_LPD_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARLOCK" *) output M_AXI_LPD_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARPROT" *) output [2:0]M_AXI_LPD_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARQOS" *) output [3:0]M_AXI_LPD_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARREADY" *) input M_AXI_LPD_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARSIZE" *) output [2:0]M_AXI_LPD_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARUSER" *) output [15:0]M_AXI_LPD_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARVALID" *) output M_AXI_LPD_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWADDR" *) output [43:0]M_AXI_LPD_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWBURST" *) output [1:0]M_AXI_LPD_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWCACHE" *) output [3:0]M_AXI_LPD_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWID" *) output [15:0]M_AXI_LPD_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWLEN" *) output [7:0]M_AXI_LPD_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWLOCK" *) output M_AXI_LPD_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWPROT" *) output [2:0]M_AXI_LPD_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWQOS" *) output [3:0]M_AXI_LPD_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWREADY" *) input M_AXI_LPD_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWSIZE" *) output [2:0]M_AXI_LPD_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWUSER" *) output [15:0]M_AXI_LPD_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWVALID" *) output M_AXI_LPD_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD BID" *) input [15:0]M_AXI_LPD_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD BREADY" *) output M_AXI_LPD_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD BRESP" *) input [1:0]M_AXI_LPD_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD BVALID" *) input M_AXI_LPD_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RDATA" *) input [127:0]M_AXI_LPD_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RID" *) input [15:0]M_AXI_LPD_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RLAST" *) input M_AXI_LPD_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RREADY" *) output M_AXI_LPD_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RRESP" *) input [1:0]M_AXI_LPD_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RVALID" *) input M_AXI_LPD_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WDATA" *) output [127:0]M_AXI_LPD_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WLAST" *) output M_AXI_LPD_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WREADY" *) input M_AXI_LPD_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WSTRB" *) output [15:0]M_AXI_LPD_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WVALID" *) output M_AXI_LPD_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PMC_NOC_AXI_0, ADDR_WIDTH 64, ARUSER_WIDTH 18, AWUSER_WIDTH 18, BUSER_WIDTH 16, CATEGORY noc, CLK_DOMAIN bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk, DATA_WIDTH 128, FREQ_HZ 320000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 1, HAS_RRESP 1, HAS_WSTRB 1, HD_TANDEM 0, ID_WIDTH 16, INDEX 0, INSERT_VIP 0, MAX_BURST_LENGTH 256, MY_CATEGORY ps_pmc, NUM_READ_OUTSTANDING 64, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 64, NUM_WRITE_THREADS 1, PHASE 0.0, PHYSICAL_CHANNEL PS_PMC_TO_NOC_NMU, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 17, SLR_INDEX 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 17" *) output [63:0]PMC_NOC_AXI_0_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARBURST" *) output [1:0]PMC_NOC_AXI_0_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARCACHE" *) output [3:0]PMC_NOC_AXI_0_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARID" *) output [15:0]PMC_NOC_AXI_0_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARLEN" *) output [7:0]PMC_NOC_AXI_0_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARLOCK" *) output PMC_NOC_AXI_0_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARPROT" *) output [2:0]PMC_NOC_AXI_0_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARQOS" *) output [3:0]PMC_NOC_AXI_0_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARREADY" *) input PMC_NOC_AXI_0_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARREGION" *) output [3:0]PMC_NOC_AXI_0_arregion;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARSIZE" *) output [2:0]PMC_NOC_AXI_0_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARUSER" *) output [17:0]PMC_NOC_AXI_0_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARVALID" *) output PMC_NOC_AXI_0_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWADDR" *) output [63:0]PMC_NOC_AXI_0_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWBURST" *) output [1:0]PMC_NOC_AXI_0_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWCACHE" *) output [3:0]PMC_NOC_AXI_0_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWID" *) output [15:0]PMC_NOC_AXI_0_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWLEN" *) output [7:0]PMC_NOC_AXI_0_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWLOCK" *) output PMC_NOC_AXI_0_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWPROT" *) output [2:0]PMC_NOC_AXI_0_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWQOS" *) output [3:0]PMC_NOC_AXI_0_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWREADY" *) input PMC_NOC_AXI_0_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWREGION" *) output [3:0]PMC_NOC_AXI_0_awregion;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWSIZE" *) output [2:0]PMC_NOC_AXI_0_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWUSER" *) output [17:0]PMC_NOC_AXI_0_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWVALID" *) output PMC_NOC_AXI_0_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BID" *) input [15:0]PMC_NOC_AXI_0_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BREADY" *) output PMC_NOC_AXI_0_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BRESP" *) input [1:0]PMC_NOC_AXI_0_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BUSER" *) input [15:0]PMC_NOC_AXI_0_buser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BVALID" *) input PMC_NOC_AXI_0_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RDATA" *) input [127:0]PMC_NOC_AXI_0_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RID" *) input [15:0]PMC_NOC_AXI_0_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RLAST" *) input PMC_NOC_AXI_0_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RREADY" *) output PMC_NOC_AXI_0_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RRESP" *) input [1:0]PMC_NOC_AXI_0_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RUSER" *) input [16:0]PMC_NOC_AXI_0_ruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RVALID" *) input PMC_NOC_AXI_0_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WDATA" *) output [127:0]PMC_NOC_AXI_0_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WID" *) output [15:0]PMC_NOC_AXI_0_wid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WLAST" *) output PMC_NOC_AXI_0_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WREADY" *) input PMC_NOC_AXI_0_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WSTRB" *) output [15:0]PMC_NOC_AXI_0_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WUSER" *) output [16:0]PMC_NOC_AXI_0_wuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WVALID" *) output PMC_NOC_AXI_0_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.FPD_CCI_NOC_AXI0_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.FPD_CCI_NOC_AXI0_CLK, ASSOCIATED_BUSIF FPD_CCI_NOC_0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU" *) output fpd_cci_noc_axi0_clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.FPD_CCI_NOC_AXI1_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.FPD_CCI_NOC_AXI1_CLK, ASSOCIATED_BUSIF FPD_CCI_NOC_1, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU" *) output fpd_cci_noc_axi1_clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.FPD_CCI_NOC_AXI2_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.FPD_CCI_NOC_AXI2_CLK, ASSOCIATED_BUSIF FPD_CCI_NOC_2, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU" *) output fpd_cci_noc_axi2_clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.FPD_CCI_NOC_AXI3_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.FPD_CCI_NOC_AXI3_CLK, ASSOCIATED_BUSIF FPD_CCI_NOC_3, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU" *) output fpd_cci_noc_axi3_clk;
  output [93:0]gem0_tsu_timer_cnt;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.LPD_AXI_NOC_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.LPD_AXI_NOC_CLK, ASSOCIATED_BUSIF LPD_AXI_NOC_0, CLK_DOMAIN bd_9435_pspmc_0_0_lpd_axi_noc_clk, FREQ_HZ 400000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0, PHYSICAL_CHANNEL PS_RPU_TO_NOC_NMU" *) output lpd_axi_noc_clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.M_AXI_LPD_ACLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.M_AXI_LPD_ACLK, ASSOCIATED_BUSIF M_AXI_LPD, CLK_DOMAIN bd_9435_pspmc_0_0_pl0_ref_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input m_axi_lpd_aclk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.PL0_REF_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.PL0_REF_CLK, CLK_DOMAIN bd_9435_pspmc_0_0_pl0_ref_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) output pl0_ref_clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.PL0_RESETN RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.PL0_RESETN, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) output pl0_resetn;
  (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 INTR.PL_PS_IRQ0 INTERRUPT" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME INTR.PL_PS_IRQ0, PortWidth 1, SENSITIVITY LEVEL_HIGH" *) input pl_ps_irq0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 INTR.PL_PS_IRQ1 INTERRUPT" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME INTR.PL_PS_IRQ1, PortWidth 1, SENSITIVITY LEVEL_HIGH" *) input pl_ps_irq1;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.PMC_AXI_NOC_AXI0_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.PMC_AXI_NOC_AXI0_CLK, ASSOCIATED_BUSIF PMC_NOC_AXI_0, CLK_DOMAIN bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk, FREQ_HZ 320000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0, PHYSICAL_CHANNEL PS_PMC_TO_NOC_NMU" *) output pmc_axi_noc_axi0_clk;

  (* HARD_CONN = "true" *) wire [63:0]FPD_CCI_NOC_0_araddr;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_0_arburst;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_0_arcache;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_0_arid;
  (* HARD_CONN = "true" *) wire [7:0]FPD_CCI_NOC_0_arlen;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_arlock;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_0_arprot;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_0_arqos;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_arready;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_0_arsize;
  (* HARD_CONN = "true" *) wire [17:0]FPD_CCI_NOC_0_aruser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_arvalid;
  (* HARD_CONN = "true" *) wire [63:0]FPD_CCI_NOC_0_awaddr;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_0_awburst;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_0_awcache;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_0_awid;
  (* HARD_CONN = "true" *) wire [7:0]FPD_CCI_NOC_0_awlen;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_awlock;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_0_awprot;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_0_awqos;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_awready;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_0_awsize;
  (* HARD_CONN = "true" *) wire [17:0]FPD_CCI_NOC_0_awuser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_awvalid;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_0_bid;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_bready;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_0_bresp;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_bvalid;
  (* HARD_CONN = "true" *) wire [127:0]FPD_CCI_NOC_0_rdata;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_0_rid;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_rlast;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_rready;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_0_rresp;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_rvalid;
  (* HARD_CONN = "true" *) wire [127:0]FPD_CCI_NOC_0_wdata;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_wlast;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_wready;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_0_wstrb;
  (* HARD_CONN = "true" *) wire [16:0]FPD_CCI_NOC_0_wuser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_0_wvalid;
  (* HARD_CONN = "true" *) wire [63:0]FPD_CCI_NOC_1_araddr;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_1_arburst;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_1_arcache;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_1_arid;
  (* HARD_CONN = "true" *) wire [7:0]FPD_CCI_NOC_1_arlen;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_arlock;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_1_arprot;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_1_arqos;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_arready;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_1_arsize;
  (* HARD_CONN = "true" *) wire [17:0]FPD_CCI_NOC_1_aruser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_arvalid;
  (* HARD_CONN = "true" *) wire [63:0]FPD_CCI_NOC_1_awaddr;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_1_awburst;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_1_awcache;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_1_awid;
  (* HARD_CONN = "true" *) wire [7:0]FPD_CCI_NOC_1_awlen;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_awlock;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_1_awprot;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_1_awqos;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_awready;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_1_awsize;
  (* HARD_CONN = "true" *) wire [17:0]FPD_CCI_NOC_1_awuser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_awvalid;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_1_bid;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_bready;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_1_bresp;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_bvalid;
  (* HARD_CONN = "true" *) wire [127:0]FPD_CCI_NOC_1_rdata;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_1_rid;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_rlast;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_rready;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_1_rresp;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_rvalid;
  (* HARD_CONN = "true" *) wire [127:0]FPD_CCI_NOC_1_wdata;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_wlast;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_wready;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_1_wstrb;
  (* HARD_CONN = "true" *) wire [16:0]FPD_CCI_NOC_1_wuser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_1_wvalid;
  (* HARD_CONN = "true" *) wire [63:0]FPD_CCI_NOC_2_araddr;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_2_arburst;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_2_arcache;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_2_arid;
  (* HARD_CONN = "true" *) wire [7:0]FPD_CCI_NOC_2_arlen;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_arlock;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_2_arprot;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_2_arqos;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_arready;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_2_arsize;
  (* HARD_CONN = "true" *) wire [17:0]FPD_CCI_NOC_2_aruser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_arvalid;
  (* HARD_CONN = "true" *) wire [63:0]FPD_CCI_NOC_2_awaddr;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_2_awburst;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_2_awcache;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_2_awid;
  (* HARD_CONN = "true" *) wire [7:0]FPD_CCI_NOC_2_awlen;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_awlock;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_2_awprot;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_2_awqos;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_awready;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_2_awsize;
  (* HARD_CONN = "true" *) wire [17:0]FPD_CCI_NOC_2_awuser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_awvalid;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_2_bid;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_bready;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_2_bresp;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_bvalid;
  (* HARD_CONN = "true" *) wire [127:0]FPD_CCI_NOC_2_rdata;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_2_rid;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_rlast;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_rready;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_2_rresp;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_rvalid;
  (* HARD_CONN = "true" *) wire [127:0]FPD_CCI_NOC_2_wdata;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_wlast;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_wready;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_2_wstrb;
  (* HARD_CONN = "true" *) wire [16:0]FPD_CCI_NOC_2_wuser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_2_wvalid;
  (* HARD_CONN = "true" *) wire [63:0]FPD_CCI_NOC_3_araddr;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_3_arburst;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_3_arcache;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_3_arid;
  (* HARD_CONN = "true" *) wire [7:0]FPD_CCI_NOC_3_arlen;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_arlock;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_3_arprot;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_3_arqos;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_arready;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_3_arsize;
  (* HARD_CONN = "true" *) wire [17:0]FPD_CCI_NOC_3_aruser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_arvalid;
  (* HARD_CONN = "true" *) wire [63:0]FPD_CCI_NOC_3_awaddr;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_3_awburst;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_3_awcache;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_3_awid;
  (* HARD_CONN = "true" *) wire [7:0]FPD_CCI_NOC_3_awlen;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_awlock;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_3_awprot;
  (* HARD_CONN = "true" *) wire [3:0]FPD_CCI_NOC_3_awqos;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_awready;
  (* HARD_CONN = "true" *) wire [2:0]FPD_CCI_NOC_3_awsize;
  (* HARD_CONN = "true" *) wire [17:0]FPD_CCI_NOC_3_awuser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_awvalid;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_3_bid;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_bready;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_3_bresp;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_bvalid;
  (* HARD_CONN = "true" *) wire [127:0]FPD_CCI_NOC_3_rdata;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_3_rid;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_rlast;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_rready;
  (* HARD_CONN = "true" *) wire [1:0]FPD_CCI_NOC_3_rresp;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_rvalid;
  (* HARD_CONN = "true" *) wire [127:0]FPD_CCI_NOC_3_wdata;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_wlast;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_wready;
  (* HARD_CONN = "true" *) wire [15:0]FPD_CCI_NOC_3_wstrb;
  (* HARD_CONN = "true" *) wire [16:0]FPD_CCI_NOC_3_wuser;
  (* HARD_CONN = "true" *) wire FPD_CCI_NOC_3_wvalid;
  (* HARD_CONN = "true" *) wire [63:0]LPD_AXI_NOC_0_araddr;
  (* HARD_CONN = "true" *) wire [1:0]LPD_AXI_NOC_0_arburst;
  (* HARD_CONN = "true" *) wire [3:0]LPD_AXI_NOC_0_arcache;
  (* HARD_CONN = "true" *) wire [15:0]LPD_AXI_NOC_0_arid;
  (* HARD_CONN = "true" *) wire [7:0]LPD_AXI_NOC_0_arlen;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_arlock;
  (* HARD_CONN = "true" *) wire [2:0]LPD_AXI_NOC_0_arprot;
  (* HARD_CONN = "true" *) wire [3:0]LPD_AXI_NOC_0_arqos;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_arready;
  (* HARD_CONN = "true" *) wire [2:0]LPD_AXI_NOC_0_arsize;
  (* HARD_CONN = "true" *) wire [17:0]LPD_AXI_NOC_0_aruser;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_arvalid;
  (* HARD_CONN = "true" *) wire [63:0]LPD_AXI_NOC_0_awaddr;
  (* HARD_CONN = "true" *) wire [1:0]LPD_AXI_NOC_0_awburst;
  (* HARD_CONN = "true" *) wire [3:0]LPD_AXI_NOC_0_awcache;
  (* HARD_CONN = "true" *) wire [15:0]LPD_AXI_NOC_0_awid;
  (* HARD_CONN = "true" *) wire [7:0]LPD_AXI_NOC_0_awlen;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_awlock;
  (* HARD_CONN = "true" *) wire [2:0]LPD_AXI_NOC_0_awprot;
  (* HARD_CONN = "true" *) wire [3:0]LPD_AXI_NOC_0_awqos;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_awready;
  (* HARD_CONN = "true" *) wire [2:0]LPD_AXI_NOC_0_awsize;
  (* HARD_CONN = "true" *) wire [17:0]LPD_AXI_NOC_0_awuser;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_awvalid;
  (* HARD_CONN = "true" *) wire [15:0]LPD_AXI_NOC_0_bid;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_bready;
  (* HARD_CONN = "true" *) wire [1:0]LPD_AXI_NOC_0_bresp;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_bvalid;
  (* HARD_CONN = "true" *) wire [127:0]LPD_AXI_NOC_0_rdata;
  (* HARD_CONN = "true" *) wire [15:0]LPD_AXI_NOC_0_rid;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_rlast;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_rready;
  (* HARD_CONN = "true" *) wire [1:0]LPD_AXI_NOC_0_rresp;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_rvalid;
  (* HARD_CONN = "true" *) wire [127:0]LPD_AXI_NOC_0_wdata;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_wlast;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_wready;
  (* HARD_CONN = "true" *) wire [15:0]LPD_AXI_NOC_0_wstrb;
  (* HARD_CONN = "true" *) wire LPD_AXI_NOC_0_wvalid;
  wire [43:0]M_AXI_LPD_araddr;
  wire [1:0]M_AXI_LPD_arburst;
  wire [3:0]M_AXI_LPD_arcache;
  wire [15:0]M_AXI_LPD_arid;
  wire [7:0]M_AXI_LPD_arlen;
  wire M_AXI_LPD_arlock;
  wire [2:0]M_AXI_LPD_arprot;
  wire [3:0]M_AXI_LPD_arqos;
  wire M_AXI_LPD_arready;
  wire [2:0]M_AXI_LPD_arsize;
  wire [15:0]M_AXI_LPD_aruser;
  wire M_AXI_LPD_arvalid;
  wire [43:0]M_AXI_LPD_awaddr;
  wire [1:0]M_AXI_LPD_awburst;
  wire [3:0]M_AXI_LPD_awcache;
  wire [15:0]M_AXI_LPD_awid;
  wire [7:0]M_AXI_LPD_awlen;
  wire M_AXI_LPD_awlock;
  wire [2:0]M_AXI_LPD_awprot;
  wire [3:0]M_AXI_LPD_awqos;
  wire M_AXI_LPD_awready;
  wire [2:0]M_AXI_LPD_awsize;
  wire [15:0]M_AXI_LPD_awuser;
  wire M_AXI_LPD_awvalid;
  wire [15:0]M_AXI_LPD_bid;
  wire M_AXI_LPD_bready;
  wire [1:0]M_AXI_LPD_bresp;
  wire M_AXI_LPD_bvalid;
  wire [127:0]M_AXI_LPD_rdata;
  wire [15:0]M_AXI_LPD_rid;
  wire M_AXI_LPD_rlast;
  wire M_AXI_LPD_rready;
  wire [1:0]M_AXI_LPD_rresp;
  wire M_AXI_LPD_rvalid;
  wire [127:0]M_AXI_LPD_wdata;
  wire M_AXI_LPD_wlast;
  wire M_AXI_LPD_wready;
  wire [15:0]M_AXI_LPD_wstrb;
  wire M_AXI_LPD_wvalid;
  (* HARD_CONN = "true" *) wire [63:0]PMC_NOC_AXI_0_araddr;
  (* HARD_CONN = "true" *) wire [1:0]PMC_NOC_AXI_0_arburst;
  (* HARD_CONN = "true" *) wire [3:0]PMC_NOC_AXI_0_arcache;
  (* HARD_CONN = "true" *) wire [15:0]PMC_NOC_AXI_0_arid;
  (* HARD_CONN = "true" *) wire [7:0]PMC_NOC_AXI_0_arlen;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_arlock;
  (* HARD_CONN = "true" *) wire [2:0]PMC_NOC_AXI_0_arprot;
  (* HARD_CONN = "true" *) wire [3:0]PMC_NOC_AXI_0_arqos;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_arready;
  (* HARD_CONN = "true" *) wire [3:0]PMC_NOC_AXI_0_arregion;
  (* HARD_CONN = "true" *) wire [2:0]PMC_NOC_AXI_0_arsize;
  (* HARD_CONN = "true" *) wire [17:0]PMC_NOC_AXI_0_aruser;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_arvalid;
  (* HARD_CONN = "true" *) wire [63:0]PMC_NOC_AXI_0_awaddr;
  (* HARD_CONN = "true" *) wire [1:0]PMC_NOC_AXI_0_awburst;
  (* HARD_CONN = "true" *) wire [3:0]PMC_NOC_AXI_0_awcache;
  (* HARD_CONN = "true" *) wire [15:0]PMC_NOC_AXI_0_awid;
  (* HARD_CONN = "true" *) wire [7:0]PMC_NOC_AXI_0_awlen;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_awlock;
  (* HARD_CONN = "true" *) wire [2:0]PMC_NOC_AXI_0_awprot;
  (* HARD_CONN = "true" *) wire [3:0]PMC_NOC_AXI_0_awqos;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_awready;
  (* HARD_CONN = "true" *) wire [3:0]PMC_NOC_AXI_0_awregion;
  (* HARD_CONN = "true" *) wire [2:0]PMC_NOC_AXI_0_awsize;
  (* HARD_CONN = "true" *) wire [17:0]PMC_NOC_AXI_0_awuser;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_awvalid;
  (* HARD_CONN = "true" *) wire [15:0]PMC_NOC_AXI_0_bid;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_bready;
  (* HARD_CONN = "true" *) wire [1:0]PMC_NOC_AXI_0_bresp;
  (* HARD_CONN = "true" *) wire [15:0]PMC_NOC_AXI_0_buser;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_bvalid;
  (* HARD_CONN = "true" *) wire [127:0]PMC_NOC_AXI_0_rdata;
  (* HARD_CONN = "true" *) wire [15:0]PMC_NOC_AXI_0_rid;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_rlast;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_rready;
  (* HARD_CONN = "true" *) wire [1:0]PMC_NOC_AXI_0_rresp;
  (* HARD_CONN = "true" *) wire [16:0]PMC_NOC_AXI_0_ruser;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_rvalid;
  (* HARD_CONN = "true" *) wire [127:0]PMC_NOC_AXI_0_wdata;
  (* HARD_CONN = "true" *) wire [15:0]PMC_NOC_AXI_0_wid;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_wlast;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_wready;
  (* HARD_CONN = "true" *) wire [15:0]PMC_NOC_AXI_0_wstrb;
  (* HARD_CONN = "true" *) wire [16:0]PMC_NOC_AXI_0_wuser;
  (* HARD_CONN = "true" *) wire PMC_NOC_AXI_0_wvalid;
  (* HARD_CONN = "true" *) wire fpd_cci_noc_axi0_clk;
  (* HARD_CONN = "true" *) wire fpd_cci_noc_axi1_clk;
  (* HARD_CONN = "true" *) wire fpd_cci_noc_axi2_clk;
  (* HARD_CONN = "true" *) wire fpd_cci_noc_axi3_clk;
  wire [93:0]gem0_tsu_timer_cnt;
  (* HARD_CONN = "true" *) wire lpd_axi_noc_clk;
  wire m_axi_lpd_aclk;
  wire pl0_ref_clk;
  wire pl0_resetn;
  wire pl_ps_irq0;
  wire pl_ps_irq1;
  (* HARD_CONN = "true" *) wire pmc_axi_noc_axi0_clk;
  wire [31:0]pspmc_0_S_APB_XRAM_PADDR;
  wire pspmc_0_S_APB_XRAM_PENABLE;
  wire [2:0]pspmc_0_S_APB_XRAM_PPROT;
  wire [31:0]pspmc_0_S_APB_XRAM_PRDATA;
  wire pspmc_0_S_APB_XRAM_PREADY;
  wire pspmc_0_S_APB_XRAM_PSEL;
  wire pspmc_0_S_APB_XRAM_PSLVERR;
  wire [3:0]pspmc_0_S_APB_XRAM_PSTRB;
  wire [31:0]pspmc_0_S_APB_XRAM_PWDATA;
  wire [0:0]pspmc_0_S_APB_XRAM_PWRITE;
  wire [63:0]pspmc_0_S_AXI_XRAM3_ARADDR;
  wire [1:0]pspmc_0_S_AXI_XRAM3_ARBURST;
  wire [3:0]pspmc_0_S_AXI_XRAM3_ARCACHE;
  wire [15:0]pspmc_0_S_AXI_XRAM3_ARID;
  wire [7:0]pspmc_0_S_AXI_XRAM3_ARLEN;
  wire pspmc_0_S_AXI_XRAM3_ARLOCK;
  wire [2:0]pspmc_0_S_AXI_XRAM3_ARPROT;
  wire [3:0]pspmc_0_S_AXI_XRAM3_ARQOS;
  wire pspmc_0_S_AXI_XRAM3_ARREADY;
  wire [3:0]pspmc_0_S_AXI_XRAM3_ARREGION;
  wire [2:0]pspmc_0_S_AXI_XRAM3_ARSIZE;
  wire [15:0]pspmc_0_S_AXI_XRAM3_ARUSER;
  wire pspmc_0_S_AXI_XRAM3_ARVALID;
  wire [63:0]pspmc_0_S_AXI_XRAM3_AWADDR;
  wire [1:0]pspmc_0_S_AXI_XRAM3_AWBURST;
  wire [3:0]pspmc_0_S_AXI_XRAM3_AWCACHE;
  wire [15:0]pspmc_0_S_AXI_XRAM3_AWID;
  wire [7:0]pspmc_0_S_AXI_XRAM3_AWLEN;
  wire pspmc_0_S_AXI_XRAM3_AWLOCK;
  wire [2:0]pspmc_0_S_AXI_XRAM3_AWPROT;
  wire [3:0]pspmc_0_S_AXI_XRAM3_AWQOS;
  wire pspmc_0_S_AXI_XRAM3_AWREADY;
  wire [3:0]pspmc_0_S_AXI_XRAM3_AWREGION;
  wire [2:0]pspmc_0_S_AXI_XRAM3_AWSIZE;
  wire [15:0]pspmc_0_S_AXI_XRAM3_AWUSER;
  wire pspmc_0_S_AXI_XRAM3_AWVALID;
  wire [15:0]pspmc_0_S_AXI_XRAM3_BID;
  wire pspmc_0_S_AXI_XRAM3_BREADY;
  wire [1:0]pspmc_0_S_AXI_XRAM3_BRESP;
  wire pspmc_0_S_AXI_XRAM3_BUSER;
  wire pspmc_0_S_AXI_XRAM3_BVALID;
  wire [127:0]pspmc_0_S_AXI_XRAM3_RDATA;
  wire [15:0]pspmc_0_S_AXI_XRAM3_RID;
  wire pspmc_0_S_AXI_XRAM3_RLAST;
  wire pspmc_0_S_AXI_XRAM3_RREADY;
  wire [1:0]pspmc_0_S_AXI_XRAM3_RRESP;
  wire [17:0]pspmc_0_S_AXI_XRAM3_RUSER;
  wire pspmc_0_S_AXI_XRAM3_RVALID;
  wire [127:0]pspmc_0_S_AXI_XRAM3_WDATA;
  wire [15:0]pspmc_0_S_AXI_XRAM3_WID;
  wire pspmc_0_S_AXI_XRAM3_WLAST;
  wire pspmc_0_S_AXI_XRAM3_WREADY;
  wire [15:0]pspmc_0_S_AXI_XRAM3_WSTRB;
  wire [17:0]pspmc_0_S_AXI_XRAM3_WUSER;
  wire pspmc_0_S_AXI_XRAM3_WVALID;
  wire pspmc_0_lpd_lsbus_clk;
  wire pspmc_0_s_axi_xram3_aclk;

  bd_9435_pspmc_0_0 pspmc_0
       (.fpd_cci_noc_axi0_araddr(FPD_CCI_NOC_0_araddr),
        .fpd_cci_noc_axi0_arburst(FPD_CCI_NOC_0_arburst),
        .fpd_cci_noc_axi0_arcache(FPD_CCI_NOC_0_arcache),
        .fpd_cci_noc_axi0_arid(FPD_CCI_NOC_0_arid),
        .fpd_cci_noc_axi0_arlen(FPD_CCI_NOC_0_arlen),
        .fpd_cci_noc_axi0_arlock(FPD_CCI_NOC_0_arlock),
        .fpd_cci_noc_axi0_arprot(FPD_CCI_NOC_0_arprot),
        .fpd_cci_noc_axi0_arqos(FPD_CCI_NOC_0_arqos),
        .fpd_cci_noc_axi0_arready(FPD_CCI_NOC_0_arready),
        .fpd_cci_noc_axi0_arsize(FPD_CCI_NOC_0_arsize),
        .fpd_cci_noc_axi0_aruser(FPD_CCI_NOC_0_aruser),
        .fpd_cci_noc_axi0_arvalid(FPD_CCI_NOC_0_arvalid),
        .fpd_cci_noc_axi0_awaddr(FPD_CCI_NOC_0_awaddr),
        .fpd_cci_noc_axi0_awburst(FPD_CCI_NOC_0_awburst),
        .fpd_cci_noc_axi0_awcache(FPD_CCI_NOC_0_awcache),
        .fpd_cci_noc_axi0_awid(FPD_CCI_NOC_0_awid),
        .fpd_cci_noc_axi0_awlen(FPD_CCI_NOC_0_awlen),
        .fpd_cci_noc_axi0_awlock(FPD_CCI_NOC_0_awlock),
        .fpd_cci_noc_axi0_awprot(FPD_CCI_NOC_0_awprot),
        .fpd_cci_noc_axi0_awqos(FPD_CCI_NOC_0_awqos),
        .fpd_cci_noc_axi0_awready(FPD_CCI_NOC_0_awready),
        .fpd_cci_noc_axi0_awsize(FPD_CCI_NOC_0_awsize),
        .fpd_cci_noc_axi0_awuser(FPD_CCI_NOC_0_awuser),
        .fpd_cci_noc_axi0_awvalid(FPD_CCI_NOC_0_awvalid),
        .fpd_cci_noc_axi0_bid(FPD_CCI_NOC_0_bid),
        .fpd_cci_noc_axi0_bready(FPD_CCI_NOC_0_bready),
        .fpd_cci_noc_axi0_bresp(FPD_CCI_NOC_0_bresp),
        .fpd_cci_noc_axi0_bvalid(FPD_CCI_NOC_0_bvalid),
        .fpd_cci_noc_axi0_clk(fpd_cci_noc_axi0_clk),
        .fpd_cci_noc_axi0_rdata(FPD_CCI_NOC_0_rdata),
        .fpd_cci_noc_axi0_rid(FPD_CCI_NOC_0_rid),
        .fpd_cci_noc_axi0_rlast(FPD_CCI_NOC_0_rlast),
        .fpd_cci_noc_axi0_rready(FPD_CCI_NOC_0_rready),
        .fpd_cci_noc_axi0_rresp(FPD_CCI_NOC_0_rresp),
        .fpd_cci_noc_axi0_rvalid(FPD_CCI_NOC_0_rvalid),
        .fpd_cci_noc_axi0_wdata(FPD_CCI_NOC_0_wdata),
        .fpd_cci_noc_axi0_wlast(FPD_CCI_NOC_0_wlast),
        .fpd_cci_noc_axi0_wready(FPD_CCI_NOC_0_wready),
        .fpd_cci_noc_axi0_wstrb(FPD_CCI_NOC_0_wstrb),
        .fpd_cci_noc_axi0_wuser(FPD_CCI_NOC_0_wuser),
        .fpd_cci_noc_axi0_wvalid(FPD_CCI_NOC_0_wvalid),
        .fpd_cci_noc_axi1_araddr(FPD_CCI_NOC_1_araddr),
        .fpd_cci_noc_axi1_arburst(FPD_CCI_NOC_1_arburst),
        .fpd_cci_noc_axi1_arcache(FPD_CCI_NOC_1_arcache),
        .fpd_cci_noc_axi1_arid(FPD_CCI_NOC_1_arid),
        .fpd_cci_noc_axi1_arlen(FPD_CCI_NOC_1_arlen),
        .fpd_cci_noc_axi1_arlock(FPD_CCI_NOC_1_arlock),
        .fpd_cci_noc_axi1_arprot(FPD_CCI_NOC_1_arprot),
        .fpd_cci_noc_axi1_arqos(FPD_CCI_NOC_1_arqos),
        .fpd_cci_noc_axi1_arready(FPD_CCI_NOC_1_arready),
        .fpd_cci_noc_axi1_arsize(FPD_CCI_NOC_1_arsize),
        .fpd_cci_noc_axi1_aruser(FPD_CCI_NOC_1_aruser),
        .fpd_cci_noc_axi1_arvalid(FPD_CCI_NOC_1_arvalid),
        .fpd_cci_noc_axi1_awaddr(FPD_CCI_NOC_1_awaddr),
        .fpd_cci_noc_axi1_awburst(FPD_CCI_NOC_1_awburst),
        .fpd_cci_noc_axi1_awcache(FPD_CCI_NOC_1_awcache),
        .fpd_cci_noc_axi1_awid(FPD_CCI_NOC_1_awid),
        .fpd_cci_noc_axi1_awlen(FPD_CCI_NOC_1_awlen),
        .fpd_cci_noc_axi1_awlock(FPD_CCI_NOC_1_awlock),
        .fpd_cci_noc_axi1_awprot(FPD_CCI_NOC_1_awprot),
        .fpd_cci_noc_axi1_awqos(FPD_CCI_NOC_1_awqos),
        .fpd_cci_noc_axi1_awready(FPD_CCI_NOC_1_awready),
        .fpd_cci_noc_axi1_awsize(FPD_CCI_NOC_1_awsize),
        .fpd_cci_noc_axi1_awuser(FPD_CCI_NOC_1_awuser),
        .fpd_cci_noc_axi1_awvalid(FPD_CCI_NOC_1_awvalid),
        .fpd_cci_noc_axi1_bid(FPD_CCI_NOC_1_bid),
        .fpd_cci_noc_axi1_bready(FPD_CCI_NOC_1_bready),
        .fpd_cci_noc_axi1_bresp(FPD_CCI_NOC_1_bresp),
        .fpd_cci_noc_axi1_bvalid(FPD_CCI_NOC_1_bvalid),
        .fpd_cci_noc_axi1_clk(fpd_cci_noc_axi1_clk),
        .fpd_cci_noc_axi1_rdata(FPD_CCI_NOC_1_rdata),
        .fpd_cci_noc_axi1_rid(FPD_CCI_NOC_1_rid),
        .fpd_cci_noc_axi1_rlast(FPD_CCI_NOC_1_rlast),
        .fpd_cci_noc_axi1_rready(FPD_CCI_NOC_1_rready),
        .fpd_cci_noc_axi1_rresp(FPD_CCI_NOC_1_rresp),
        .fpd_cci_noc_axi1_rvalid(FPD_CCI_NOC_1_rvalid),
        .fpd_cci_noc_axi1_wdata(FPD_CCI_NOC_1_wdata),
        .fpd_cci_noc_axi1_wlast(FPD_CCI_NOC_1_wlast),
        .fpd_cci_noc_axi1_wready(FPD_CCI_NOC_1_wready),
        .fpd_cci_noc_axi1_wstrb(FPD_CCI_NOC_1_wstrb),
        .fpd_cci_noc_axi1_wuser(FPD_CCI_NOC_1_wuser),
        .fpd_cci_noc_axi1_wvalid(FPD_CCI_NOC_1_wvalid),
        .fpd_cci_noc_axi2_araddr(FPD_CCI_NOC_2_araddr),
        .fpd_cci_noc_axi2_arburst(FPD_CCI_NOC_2_arburst),
        .fpd_cci_noc_axi2_arcache(FPD_CCI_NOC_2_arcache),
        .fpd_cci_noc_axi2_arid(FPD_CCI_NOC_2_arid),
        .fpd_cci_noc_axi2_arlen(FPD_CCI_NOC_2_arlen),
        .fpd_cci_noc_axi2_arlock(FPD_CCI_NOC_2_arlock),
        .fpd_cci_noc_axi2_arprot(FPD_CCI_NOC_2_arprot),
        .fpd_cci_noc_axi2_arqos(FPD_CCI_NOC_2_arqos),
        .fpd_cci_noc_axi2_arready(FPD_CCI_NOC_2_arready),
        .fpd_cci_noc_axi2_arsize(FPD_CCI_NOC_2_arsize),
        .fpd_cci_noc_axi2_aruser(FPD_CCI_NOC_2_aruser),
        .fpd_cci_noc_axi2_arvalid(FPD_CCI_NOC_2_arvalid),
        .fpd_cci_noc_axi2_awaddr(FPD_CCI_NOC_2_awaddr),
        .fpd_cci_noc_axi2_awburst(FPD_CCI_NOC_2_awburst),
        .fpd_cci_noc_axi2_awcache(FPD_CCI_NOC_2_awcache),
        .fpd_cci_noc_axi2_awid(FPD_CCI_NOC_2_awid),
        .fpd_cci_noc_axi2_awlen(FPD_CCI_NOC_2_awlen),
        .fpd_cci_noc_axi2_awlock(FPD_CCI_NOC_2_awlock),
        .fpd_cci_noc_axi2_awprot(FPD_CCI_NOC_2_awprot),
        .fpd_cci_noc_axi2_awqos(FPD_CCI_NOC_2_awqos),
        .fpd_cci_noc_axi2_awready(FPD_CCI_NOC_2_awready),
        .fpd_cci_noc_axi2_awsize(FPD_CCI_NOC_2_awsize),
        .fpd_cci_noc_axi2_awuser(FPD_CCI_NOC_2_awuser),
        .fpd_cci_noc_axi2_awvalid(FPD_CCI_NOC_2_awvalid),
        .fpd_cci_noc_axi2_bid(FPD_CCI_NOC_2_bid),
        .fpd_cci_noc_axi2_bready(FPD_CCI_NOC_2_bready),
        .fpd_cci_noc_axi2_bresp(FPD_CCI_NOC_2_bresp),
        .fpd_cci_noc_axi2_bvalid(FPD_CCI_NOC_2_bvalid),
        .fpd_cci_noc_axi2_clk(fpd_cci_noc_axi2_clk),
        .fpd_cci_noc_axi2_rdata(FPD_CCI_NOC_2_rdata),
        .fpd_cci_noc_axi2_rid(FPD_CCI_NOC_2_rid),
        .fpd_cci_noc_axi2_rlast(FPD_CCI_NOC_2_rlast),
        .fpd_cci_noc_axi2_rready(FPD_CCI_NOC_2_rready),
        .fpd_cci_noc_axi2_rresp(FPD_CCI_NOC_2_rresp),
        .fpd_cci_noc_axi2_rvalid(FPD_CCI_NOC_2_rvalid),
        .fpd_cci_noc_axi2_wdata(FPD_CCI_NOC_2_wdata),
        .fpd_cci_noc_axi2_wlast(FPD_CCI_NOC_2_wlast),
        .fpd_cci_noc_axi2_wready(FPD_CCI_NOC_2_wready),
        .fpd_cci_noc_axi2_wstrb(FPD_CCI_NOC_2_wstrb),
        .fpd_cci_noc_axi2_wuser(FPD_CCI_NOC_2_wuser),
        .fpd_cci_noc_axi2_wvalid(FPD_CCI_NOC_2_wvalid),
        .fpd_cci_noc_axi3_araddr(FPD_CCI_NOC_3_araddr),
        .fpd_cci_noc_axi3_arburst(FPD_CCI_NOC_3_arburst),
        .fpd_cci_noc_axi3_arcache(FPD_CCI_NOC_3_arcache),
        .fpd_cci_noc_axi3_arid(FPD_CCI_NOC_3_arid),
        .fpd_cci_noc_axi3_arlen(FPD_CCI_NOC_3_arlen),
        .fpd_cci_noc_axi3_arlock(FPD_CCI_NOC_3_arlock),
        .fpd_cci_noc_axi3_arprot(FPD_CCI_NOC_3_arprot),
        .fpd_cci_noc_axi3_arqos(FPD_CCI_NOC_3_arqos),
        .fpd_cci_noc_axi3_arready(FPD_CCI_NOC_3_arready),
        .fpd_cci_noc_axi3_arsize(FPD_CCI_NOC_3_arsize),
        .fpd_cci_noc_axi3_aruser(FPD_CCI_NOC_3_aruser),
        .fpd_cci_noc_axi3_arvalid(FPD_CCI_NOC_3_arvalid),
        .fpd_cci_noc_axi3_awaddr(FPD_CCI_NOC_3_awaddr),
        .fpd_cci_noc_axi3_awburst(FPD_CCI_NOC_3_awburst),
        .fpd_cci_noc_axi3_awcache(FPD_CCI_NOC_3_awcache),
        .fpd_cci_noc_axi3_awid(FPD_CCI_NOC_3_awid),
        .fpd_cci_noc_axi3_awlen(FPD_CCI_NOC_3_awlen),
        .fpd_cci_noc_axi3_awlock(FPD_CCI_NOC_3_awlock),
        .fpd_cci_noc_axi3_awprot(FPD_CCI_NOC_3_awprot),
        .fpd_cci_noc_axi3_awqos(FPD_CCI_NOC_3_awqos),
        .fpd_cci_noc_axi3_awready(FPD_CCI_NOC_3_awready),
        .fpd_cci_noc_axi3_awsize(FPD_CCI_NOC_3_awsize),
        .fpd_cci_noc_axi3_awuser(FPD_CCI_NOC_3_awuser),
        .fpd_cci_noc_axi3_awvalid(FPD_CCI_NOC_3_awvalid),
        .fpd_cci_noc_axi3_bid(FPD_CCI_NOC_3_bid),
        .fpd_cci_noc_axi3_bready(FPD_CCI_NOC_3_bready),
        .fpd_cci_noc_axi3_bresp(FPD_CCI_NOC_3_bresp),
        .fpd_cci_noc_axi3_bvalid(FPD_CCI_NOC_3_bvalid),
        .fpd_cci_noc_axi3_clk(fpd_cci_noc_axi3_clk),
        .fpd_cci_noc_axi3_rdata(FPD_CCI_NOC_3_rdata),
        .fpd_cci_noc_axi3_rid(FPD_CCI_NOC_3_rid),
        .fpd_cci_noc_axi3_rlast(FPD_CCI_NOC_3_rlast),
        .fpd_cci_noc_axi3_rready(FPD_CCI_NOC_3_rready),
        .fpd_cci_noc_axi3_rresp(FPD_CCI_NOC_3_rresp),
        .fpd_cci_noc_axi3_rvalid(FPD_CCI_NOC_3_rvalid),
        .fpd_cci_noc_axi3_wdata(FPD_CCI_NOC_3_wdata),
        .fpd_cci_noc_axi3_wlast(FPD_CCI_NOC_3_wlast),
        .fpd_cci_noc_axi3_wready(FPD_CCI_NOC_3_wready),
        .fpd_cci_noc_axi3_wstrb(FPD_CCI_NOC_3_wstrb),
        .fpd_cci_noc_axi3_wuser(FPD_CCI_NOC_3_wuser),
        .fpd_cci_noc_axi3_wvalid(FPD_CCI_NOC_3_wvalid),
        .gem0_tsu_timer_cnt(gem0_tsu_timer_cnt),
        .lpd_axi_noc_axi0_araddr(LPD_AXI_NOC_0_araddr),
        .lpd_axi_noc_axi0_arburst(LPD_AXI_NOC_0_arburst),
        .lpd_axi_noc_axi0_arcache(LPD_AXI_NOC_0_arcache),
        .lpd_axi_noc_axi0_arid(LPD_AXI_NOC_0_arid),
        .lpd_axi_noc_axi0_arlen(LPD_AXI_NOC_0_arlen),
        .lpd_axi_noc_axi0_arlock(LPD_AXI_NOC_0_arlock),
        .lpd_axi_noc_axi0_arprot(LPD_AXI_NOC_0_arprot),
        .lpd_axi_noc_axi0_arqos(LPD_AXI_NOC_0_arqos),
        .lpd_axi_noc_axi0_arready(LPD_AXI_NOC_0_arready),
        .lpd_axi_noc_axi0_arsize(LPD_AXI_NOC_0_arsize),
        .lpd_axi_noc_axi0_aruser(LPD_AXI_NOC_0_aruser),
        .lpd_axi_noc_axi0_arvalid(LPD_AXI_NOC_0_arvalid),
        .lpd_axi_noc_axi0_awaddr(LPD_AXI_NOC_0_awaddr),
        .lpd_axi_noc_axi0_awburst(LPD_AXI_NOC_0_awburst),
        .lpd_axi_noc_axi0_awcache(LPD_AXI_NOC_0_awcache),
        .lpd_axi_noc_axi0_awid(LPD_AXI_NOC_0_awid),
        .lpd_axi_noc_axi0_awlen(LPD_AXI_NOC_0_awlen),
        .lpd_axi_noc_axi0_awlock(LPD_AXI_NOC_0_awlock),
        .lpd_axi_noc_axi0_awprot(LPD_AXI_NOC_0_awprot),
        .lpd_axi_noc_axi0_awqos(LPD_AXI_NOC_0_awqos),
        .lpd_axi_noc_axi0_awready(LPD_AXI_NOC_0_awready),
        .lpd_axi_noc_axi0_awsize(LPD_AXI_NOC_0_awsize),
        .lpd_axi_noc_axi0_awuser(LPD_AXI_NOC_0_awuser),
        .lpd_axi_noc_axi0_awvalid(LPD_AXI_NOC_0_awvalid),
        .lpd_axi_noc_axi0_bid(LPD_AXI_NOC_0_bid),
        .lpd_axi_noc_axi0_bready(LPD_AXI_NOC_0_bready),
        .lpd_axi_noc_axi0_bresp(LPD_AXI_NOC_0_bresp),
        .lpd_axi_noc_axi0_bvalid(LPD_AXI_NOC_0_bvalid),
        .lpd_axi_noc_axi0_rdata(LPD_AXI_NOC_0_rdata),
        .lpd_axi_noc_axi0_rid(LPD_AXI_NOC_0_rid),
        .lpd_axi_noc_axi0_rlast(LPD_AXI_NOC_0_rlast),
        .lpd_axi_noc_axi0_rready(LPD_AXI_NOC_0_rready),
        .lpd_axi_noc_axi0_rresp(LPD_AXI_NOC_0_rresp),
        .lpd_axi_noc_axi0_rvalid(LPD_AXI_NOC_0_rvalid),
        .lpd_axi_noc_axi0_wdata(LPD_AXI_NOC_0_wdata),
        .lpd_axi_noc_axi0_wlast(LPD_AXI_NOC_0_wlast),
        .lpd_axi_noc_axi0_wready(LPD_AXI_NOC_0_wready),
        .lpd_axi_noc_axi0_wstrb(LPD_AXI_NOC_0_wstrb),
        .lpd_axi_noc_axi0_wvalid(LPD_AXI_NOC_0_wvalid),
        .lpd_axi_noc_clk(lpd_axi_noc_clk),
        .lpd_lsbus_clk(pspmc_0_lpd_lsbus_clk),
        .m_axi_lpd_aclk(m_axi_lpd_aclk),
        .m_axi_lpd_araddr(M_AXI_LPD_araddr),
        .m_axi_lpd_arburst(M_AXI_LPD_arburst),
        .m_axi_lpd_arcache(M_AXI_LPD_arcache),
        .m_axi_lpd_arid(M_AXI_LPD_arid),
        .m_axi_lpd_arlen(M_AXI_LPD_arlen),
        .m_axi_lpd_arlock(M_AXI_LPD_arlock),
        .m_axi_lpd_arprot(M_AXI_LPD_arprot),
        .m_axi_lpd_arqos(M_AXI_LPD_arqos),
        .m_axi_lpd_arready(M_AXI_LPD_arready),
        .m_axi_lpd_arsize(M_AXI_LPD_arsize),
        .m_axi_lpd_aruser(M_AXI_LPD_aruser),
        .m_axi_lpd_arvalid(M_AXI_LPD_arvalid),
        .m_axi_lpd_awaddr(M_AXI_LPD_awaddr),
        .m_axi_lpd_awburst(M_AXI_LPD_awburst),
        .m_axi_lpd_awcache(M_AXI_LPD_awcache),
        .m_axi_lpd_awid(M_AXI_LPD_awid),
        .m_axi_lpd_awlen(M_AXI_LPD_awlen),
        .m_axi_lpd_awlock(M_AXI_LPD_awlock),
        .m_axi_lpd_awprot(M_AXI_LPD_awprot),
        .m_axi_lpd_awqos(M_AXI_LPD_awqos),
        .m_axi_lpd_awready(M_AXI_LPD_awready),
        .m_axi_lpd_awsize(M_AXI_LPD_awsize),
        .m_axi_lpd_awuser(M_AXI_LPD_awuser),
        .m_axi_lpd_awvalid(M_AXI_LPD_awvalid),
        .m_axi_lpd_bid(M_AXI_LPD_bid),
        .m_axi_lpd_bready(M_AXI_LPD_bready),
        .m_axi_lpd_bresp(M_AXI_LPD_bresp),
        .m_axi_lpd_bvalid(M_AXI_LPD_bvalid),
        .m_axi_lpd_rdata(M_AXI_LPD_rdata),
        .m_axi_lpd_rid(M_AXI_LPD_rid),
        .m_axi_lpd_rlast(M_AXI_LPD_rlast),
        .m_axi_lpd_rready(M_AXI_LPD_rready),
        .m_axi_lpd_rresp(M_AXI_LPD_rresp),
        .m_axi_lpd_rvalid(M_AXI_LPD_rvalid),
        .m_axi_lpd_wdata(M_AXI_LPD_wdata),
        .m_axi_lpd_wlast(M_AXI_LPD_wlast),
        .m_axi_lpd_wready(M_AXI_LPD_wready),
        .m_axi_lpd_wstrb(M_AXI_LPD_wstrb),
        .m_axi_lpd_wvalid(M_AXI_LPD_wvalid),
        .pl0_ref_clk(pl0_ref_clk),
        .pl0_resetn(pl0_resetn),
        .pl_ps_irq0(pl_ps_irq0),
        .pl_ps_irq1(pl_ps_irq1),
        .pmc_axi_noc_axi0_clk(pmc_axi_noc_axi0_clk),
        .pmc_noc_axi0_araddr(PMC_NOC_AXI_0_araddr),
        .pmc_noc_axi0_arburst(PMC_NOC_AXI_0_arburst),
        .pmc_noc_axi0_arcache(PMC_NOC_AXI_0_arcache),
        .pmc_noc_axi0_arid(PMC_NOC_AXI_0_arid),
        .pmc_noc_axi0_arlen(PMC_NOC_AXI_0_arlen),
        .pmc_noc_axi0_arlock(PMC_NOC_AXI_0_arlock),
        .pmc_noc_axi0_arprot(PMC_NOC_AXI_0_arprot),
        .pmc_noc_axi0_arqos(PMC_NOC_AXI_0_arqos),
        .pmc_noc_axi0_arready(PMC_NOC_AXI_0_arready),
        .pmc_noc_axi0_arregion(PMC_NOC_AXI_0_arregion),
        .pmc_noc_axi0_arsize(PMC_NOC_AXI_0_arsize),
        .pmc_noc_axi0_aruser(PMC_NOC_AXI_0_aruser),
        .pmc_noc_axi0_arvalid(PMC_NOC_AXI_0_arvalid),
        .pmc_noc_axi0_awaddr(PMC_NOC_AXI_0_awaddr),
        .pmc_noc_axi0_awburst(PMC_NOC_AXI_0_awburst),
        .pmc_noc_axi0_awcache(PMC_NOC_AXI_0_awcache),
        .pmc_noc_axi0_awid(PMC_NOC_AXI_0_awid),
        .pmc_noc_axi0_awlen(PMC_NOC_AXI_0_awlen),
        .pmc_noc_axi0_awlock(PMC_NOC_AXI_0_awlock),
        .pmc_noc_axi0_awprot(PMC_NOC_AXI_0_awprot),
        .pmc_noc_axi0_awqos(PMC_NOC_AXI_0_awqos),
        .pmc_noc_axi0_awready(PMC_NOC_AXI_0_awready),
        .pmc_noc_axi0_awregion(PMC_NOC_AXI_0_awregion),
        .pmc_noc_axi0_awsize(PMC_NOC_AXI_0_awsize),
        .pmc_noc_axi0_awuser(PMC_NOC_AXI_0_awuser),
        .pmc_noc_axi0_awvalid(PMC_NOC_AXI_0_awvalid),
        .pmc_noc_axi0_bid(PMC_NOC_AXI_0_bid),
        .pmc_noc_axi0_bready(PMC_NOC_AXI_0_bready),
        .pmc_noc_axi0_bresp(PMC_NOC_AXI_0_bresp),
        .pmc_noc_axi0_buser(PMC_NOC_AXI_0_buser),
        .pmc_noc_axi0_bvalid(PMC_NOC_AXI_0_bvalid),
        .pmc_noc_axi0_rdata(PMC_NOC_AXI_0_rdata),
        .pmc_noc_axi0_rid(PMC_NOC_AXI_0_rid),
        .pmc_noc_axi0_rlast(PMC_NOC_AXI_0_rlast),
        .pmc_noc_axi0_rready(PMC_NOC_AXI_0_rready),
        .pmc_noc_axi0_rresp(PMC_NOC_AXI_0_rresp),
        .pmc_noc_axi0_ruser(PMC_NOC_AXI_0_ruser),
        .pmc_noc_axi0_rvalid(PMC_NOC_AXI_0_rvalid),
        .pmc_noc_axi0_wdata(PMC_NOC_AXI_0_wdata),
        .pmc_noc_axi0_wid(PMC_NOC_AXI_0_wid),
        .pmc_noc_axi0_wlast(PMC_NOC_AXI_0_wlast),
        .pmc_noc_axi0_wready(PMC_NOC_AXI_0_wready),
        .pmc_noc_axi0_wstrb(PMC_NOC_AXI_0_wstrb),
        .pmc_noc_axi0_wuser(PMC_NOC_AXI_0_wuser),
        .pmc_noc_axi0_wvalid(PMC_NOC_AXI_0_wvalid),
        .ps_ocm2_apb_paddr(pspmc_0_S_APB_XRAM_PADDR),
        .ps_ocm2_apb_penable(pspmc_0_S_APB_XRAM_PENABLE),
        .ps_ocm2_apb_pprot(pspmc_0_S_APB_XRAM_PPROT),
        .ps_ocm2_apb_prdata(pspmc_0_S_APB_XRAM_PRDATA),
        .ps_ocm2_apb_pready(pspmc_0_S_APB_XRAM_PREADY),
        .ps_ocm2_apb_psel(pspmc_0_S_APB_XRAM_PSEL),
        .ps_ocm2_apb_pslverr(pspmc_0_S_APB_XRAM_PSLVERR),
        .ps_ocm2_apb_pstrb(pspmc_0_S_APB_XRAM_PSTRB),
        .ps_ocm2_apb_pwdata(pspmc_0_S_APB_XRAM_PWDATA),
        .ps_ocm2_apb_pwrite(pspmc_0_S_APB_XRAM_PWRITE),
        .ps_ocm2_axi_araddr(pspmc_0_S_AXI_XRAM3_ARADDR),
        .ps_ocm2_axi_arburst(pspmc_0_S_AXI_XRAM3_ARBURST),
        .ps_ocm2_axi_arcache(pspmc_0_S_AXI_XRAM3_ARCACHE),
        .ps_ocm2_axi_arid(pspmc_0_S_AXI_XRAM3_ARID),
        .ps_ocm2_axi_arlen(pspmc_0_S_AXI_XRAM3_ARLEN),
        .ps_ocm2_axi_arlock(pspmc_0_S_AXI_XRAM3_ARLOCK),
        .ps_ocm2_axi_arprot(pspmc_0_S_AXI_XRAM3_ARPROT),
        .ps_ocm2_axi_arqos(pspmc_0_S_AXI_XRAM3_ARQOS),
        .ps_ocm2_axi_arready(pspmc_0_S_AXI_XRAM3_ARREADY),
        .ps_ocm2_axi_arregion(pspmc_0_S_AXI_XRAM3_ARREGION),
        .ps_ocm2_axi_arsize(pspmc_0_S_AXI_XRAM3_ARSIZE),
        .ps_ocm2_axi_aruser(pspmc_0_S_AXI_XRAM3_ARUSER),
        .ps_ocm2_axi_arvalid(pspmc_0_S_AXI_XRAM3_ARVALID),
        .ps_ocm2_axi_awaddr(pspmc_0_S_AXI_XRAM3_AWADDR),
        .ps_ocm2_axi_awburst(pspmc_0_S_AXI_XRAM3_AWBURST),
        .ps_ocm2_axi_awcache(pspmc_0_S_AXI_XRAM3_AWCACHE),
        .ps_ocm2_axi_awid(pspmc_0_S_AXI_XRAM3_AWID),
        .ps_ocm2_axi_awlen(pspmc_0_S_AXI_XRAM3_AWLEN),
        .ps_ocm2_axi_awlock(pspmc_0_S_AXI_XRAM3_AWLOCK),
        .ps_ocm2_axi_awprot(pspmc_0_S_AXI_XRAM3_AWPROT),
        .ps_ocm2_axi_awqos(pspmc_0_S_AXI_XRAM3_AWQOS),
        .ps_ocm2_axi_awready(pspmc_0_S_AXI_XRAM3_AWREADY),
        .ps_ocm2_axi_awregion(pspmc_0_S_AXI_XRAM3_AWREGION),
        .ps_ocm2_axi_awsize(pspmc_0_S_AXI_XRAM3_AWSIZE),
        .ps_ocm2_axi_awuser(pspmc_0_S_AXI_XRAM3_AWUSER),
        .ps_ocm2_axi_awvalid(pspmc_0_S_AXI_XRAM3_AWVALID),
        .ps_ocm2_axi_bid(pspmc_0_S_AXI_XRAM3_BID),
        .ps_ocm2_axi_bready(pspmc_0_S_AXI_XRAM3_BREADY),
        .ps_ocm2_axi_bresp(pspmc_0_S_AXI_XRAM3_BRESP),
        .ps_ocm2_axi_buser(pspmc_0_S_AXI_XRAM3_BUSER),
        .ps_ocm2_axi_bvalid(pspmc_0_S_AXI_XRAM3_BVALID),
        .ps_ocm2_axi_rdata(pspmc_0_S_AXI_XRAM3_RDATA),
        .ps_ocm2_axi_rid(pspmc_0_S_AXI_XRAM3_RID),
        .ps_ocm2_axi_rlast(pspmc_0_S_AXI_XRAM3_RLAST),
        .ps_ocm2_axi_rready(pspmc_0_S_AXI_XRAM3_RREADY),
        .ps_ocm2_axi_rresp(pspmc_0_S_AXI_XRAM3_RRESP),
        .ps_ocm2_axi_ruser(pspmc_0_S_AXI_XRAM3_RUSER),
        .ps_ocm2_axi_rvalid(pspmc_0_S_AXI_XRAM3_RVALID),
        .ps_ocm2_axi_wdata(pspmc_0_S_AXI_XRAM3_WDATA),
        .ps_ocm2_axi_wid(pspmc_0_S_AXI_XRAM3_WID),
        .ps_ocm2_axi_wlast(pspmc_0_S_AXI_XRAM3_WLAST),
        .ps_ocm2_axi_wready(pspmc_0_S_AXI_XRAM3_WREADY),
        .ps_ocm2_axi_wstrb(pspmc_0_S_AXI_XRAM3_WSTRB),
        .ps_ocm2_axi_wuser(pspmc_0_S_AXI_XRAM3_WUSER),
        .ps_ocm2_axi_wvalid(pspmc_0_S_AXI_XRAM3_WVALID),
        .s_axi_xram3_aclk(pspmc_0_s_axi_xram3_aclk));
  bd_9435_xram_0 xram
       (.lpd_lsbus_clk(pspmc_0_lpd_lsbus_clk),
        .ps_ocm2_apb_paddr(pspmc_0_S_APB_XRAM_PADDR),
        .ps_ocm2_apb_penable(pspmc_0_S_APB_XRAM_PENABLE),
        .ps_ocm2_apb_pprot(pspmc_0_S_APB_XRAM_PPROT),
        .ps_ocm2_apb_prdata(pspmc_0_S_APB_XRAM_PRDATA),
        .ps_ocm2_apb_pready(pspmc_0_S_APB_XRAM_PREADY),
        .ps_ocm2_apb_psel(pspmc_0_S_APB_XRAM_PSEL),
        .ps_ocm2_apb_pslverr(pspmc_0_S_APB_XRAM_PSLVERR),
        .ps_ocm2_apb_pstrb(pspmc_0_S_APB_XRAM_PSTRB),
        .ps_ocm2_apb_pwdata(pspmc_0_S_APB_XRAM_PWDATA),
        .ps_ocm2_apb_pwrite(pspmc_0_S_APB_XRAM_PWRITE),
        .ps_ocm2_axi_araddr(pspmc_0_S_AXI_XRAM3_ARADDR),
        .ps_ocm2_axi_arburst(pspmc_0_S_AXI_XRAM3_ARBURST),
        .ps_ocm2_axi_arcache(pspmc_0_S_AXI_XRAM3_ARCACHE),
        .ps_ocm2_axi_arid(pspmc_0_S_AXI_XRAM3_ARID),
        .ps_ocm2_axi_arlen(pspmc_0_S_AXI_XRAM3_ARLEN),
        .ps_ocm2_axi_arlock(pspmc_0_S_AXI_XRAM3_ARLOCK),
        .ps_ocm2_axi_arprot(pspmc_0_S_AXI_XRAM3_ARPROT),
        .ps_ocm2_axi_arqos(pspmc_0_S_AXI_XRAM3_ARQOS),
        .ps_ocm2_axi_arready(pspmc_0_S_AXI_XRAM3_ARREADY),
        .ps_ocm2_axi_arregion(pspmc_0_S_AXI_XRAM3_ARREGION),
        .ps_ocm2_axi_arsize(pspmc_0_S_AXI_XRAM3_ARSIZE),
        .ps_ocm2_axi_aruser(pspmc_0_S_AXI_XRAM3_ARUSER),
        .ps_ocm2_axi_arvalid(pspmc_0_S_AXI_XRAM3_ARVALID),
        .ps_ocm2_axi_awaddr(pspmc_0_S_AXI_XRAM3_AWADDR),
        .ps_ocm2_axi_awburst(pspmc_0_S_AXI_XRAM3_AWBURST),
        .ps_ocm2_axi_awcache(pspmc_0_S_AXI_XRAM3_AWCACHE),
        .ps_ocm2_axi_awid(pspmc_0_S_AXI_XRAM3_AWID),
        .ps_ocm2_axi_awlen(pspmc_0_S_AXI_XRAM3_AWLEN),
        .ps_ocm2_axi_awlock(pspmc_0_S_AXI_XRAM3_AWLOCK),
        .ps_ocm2_axi_awprot(pspmc_0_S_AXI_XRAM3_AWPROT),
        .ps_ocm2_axi_awqos(pspmc_0_S_AXI_XRAM3_AWQOS),
        .ps_ocm2_axi_awready(pspmc_0_S_AXI_XRAM3_AWREADY),
        .ps_ocm2_axi_awregion(pspmc_0_S_AXI_XRAM3_AWREGION),
        .ps_ocm2_axi_awsize(pspmc_0_S_AXI_XRAM3_AWSIZE),
        .ps_ocm2_axi_awuser(pspmc_0_S_AXI_XRAM3_AWUSER),
        .ps_ocm2_axi_awvalid(pspmc_0_S_AXI_XRAM3_AWVALID),
        .ps_ocm2_axi_bid(pspmc_0_S_AXI_XRAM3_BID),
        .ps_ocm2_axi_bready(pspmc_0_S_AXI_XRAM3_BREADY),
        .ps_ocm2_axi_bresp(pspmc_0_S_AXI_XRAM3_BRESP),
        .ps_ocm2_axi_buser(pspmc_0_S_AXI_XRAM3_BUSER),
        .ps_ocm2_axi_bvalid(pspmc_0_S_AXI_XRAM3_BVALID),
        .ps_ocm2_axi_rdata(pspmc_0_S_AXI_XRAM3_RDATA),
        .ps_ocm2_axi_rid(pspmc_0_S_AXI_XRAM3_RID),
        .ps_ocm2_axi_rlast(pspmc_0_S_AXI_XRAM3_RLAST),
        .ps_ocm2_axi_rready(pspmc_0_S_AXI_XRAM3_RREADY),
        .ps_ocm2_axi_rresp(pspmc_0_S_AXI_XRAM3_RRESP),
        .ps_ocm2_axi_ruser(pspmc_0_S_AXI_XRAM3_RUSER),
        .ps_ocm2_axi_rvalid(pspmc_0_S_AXI_XRAM3_RVALID),
        .ps_ocm2_axi_wdata(pspmc_0_S_AXI_XRAM3_WDATA),
        .ps_ocm2_axi_wid(pspmc_0_S_AXI_XRAM3_WID),
        .ps_ocm2_axi_wlast(pspmc_0_S_AXI_XRAM3_WLAST),
        .ps_ocm2_axi_wready(pspmc_0_S_AXI_XRAM3_WREADY),
        .ps_ocm2_axi_wstrb(pspmc_0_S_AXI_XRAM3_WSTRB),
        .ps_ocm2_axi_wuser(pspmc_0_S_AXI_XRAM3_WUSER),
        .ps_ocm2_axi_wvalid(pspmc_0_S_AXI_XRAM3_WVALID),
        .s_axi_xram3_aclk(pspmc_0_s_axi_xram3_aclk));
endmodule
