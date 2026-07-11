// (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:ip:pspmc:1.4
// IP Revision: 7

`timescale 1ns/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module bd_9435_pspmc_0_0 (
  pl0_ref_clk,
  pl0_resetn,
  m_axi_lpd_aclk,
  m_axi_lpd_awid,
  m_axi_lpd_awaddr,
  m_axi_lpd_awlen,
  m_axi_lpd_awsize,
  m_axi_lpd_awburst,
  m_axi_lpd_awlock,
  m_axi_lpd_awcache,
  m_axi_lpd_awprot,
  m_axi_lpd_awvalid,
  m_axi_lpd_awuser,
  m_axi_lpd_awready,
  m_axi_lpd_wlast,
  m_axi_lpd_wvalid,
  m_axi_lpd_wready,
  m_axi_lpd_bid,
  m_axi_lpd_bresp,
  m_axi_lpd_bvalid,
  m_axi_lpd_bready,
  m_axi_lpd_arid,
  m_axi_lpd_araddr,
  m_axi_lpd_arlen,
  m_axi_lpd_arsize,
  m_axi_lpd_arburst,
  m_axi_lpd_arlock,
  m_axi_lpd_arcache,
  m_axi_lpd_arprot,
  m_axi_lpd_arvalid,
  m_axi_lpd_aruser,
  m_axi_lpd_arready,
  m_axi_lpd_rid,
  m_axi_lpd_rresp,
  m_axi_lpd_rlast,
  m_axi_lpd_rvalid,
  m_axi_lpd_rready,
  m_axi_lpd_awqos,
  m_axi_lpd_arqos,
  m_axi_lpd_wdata,
  m_axi_lpd_wstrb,
  m_axi_lpd_rdata,
  fpd_cci_noc_axi0_clk,
  fpd_cci_noc_axi0_awid,
  fpd_cci_noc_axi0_awaddr,
  fpd_cci_noc_axi0_awlen,
  fpd_cci_noc_axi0_awsize,
  fpd_cci_noc_axi0_awburst,
  fpd_cci_noc_axi0_awlock,
  fpd_cci_noc_axi0_awcache,
  fpd_cci_noc_axi0_awprot,
  fpd_cci_noc_axi0_awvalid,
  fpd_cci_noc_axi0_awuser,
  fpd_cci_noc_axi0_awready,
  fpd_cci_noc_axi0_wdata,
  fpd_cci_noc_axi0_wstrb,
  fpd_cci_noc_axi0_wuser,
  fpd_cci_noc_axi0_wlast,
  fpd_cci_noc_axi0_wvalid,
  fpd_cci_noc_axi0_wready,
  fpd_cci_noc_axi0_bid,
  fpd_cci_noc_axi0_bresp,
  fpd_cci_noc_axi0_bvalid,
  fpd_cci_noc_axi0_bready,
  fpd_cci_noc_axi0_arid,
  fpd_cci_noc_axi0_araddr,
  fpd_cci_noc_axi0_arlen,
  fpd_cci_noc_axi0_arsize,
  fpd_cci_noc_axi0_arburst,
  fpd_cci_noc_axi0_arlock,
  fpd_cci_noc_axi0_arcache,
  fpd_cci_noc_axi0_arprot,
  fpd_cci_noc_axi0_arvalid,
  fpd_cci_noc_axi0_aruser,
  fpd_cci_noc_axi0_arready,
  fpd_cci_noc_axi0_rid,
  fpd_cci_noc_axi0_rdata,
  fpd_cci_noc_axi0_rresp,
  fpd_cci_noc_axi0_rlast,
  fpd_cci_noc_axi0_rvalid,
  fpd_cci_noc_axi0_rready,
  fpd_cci_noc_axi0_awqos,
  fpd_cci_noc_axi0_arqos,
  fpd_cci_noc_axi1_clk,
  fpd_cci_noc_axi1_awid,
  fpd_cci_noc_axi1_awaddr,
  fpd_cci_noc_axi1_awlen,
  fpd_cci_noc_axi1_awsize,
  fpd_cci_noc_axi1_awburst,
  fpd_cci_noc_axi1_awlock,
  fpd_cci_noc_axi1_awcache,
  fpd_cci_noc_axi1_awprot,
  fpd_cci_noc_axi1_awvalid,
  fpd_cci_noc_axi1_awuser,
  fpd_cci_noc_axi1_awready,
  fpd_cci_noc_axi1_wdata,
  fpd_cci_noc_axi1_wstrb,
  fpd_cci_noc_axi1_wuser,
  fpd_cci_noc_axi1_wlast,
  fpd_cci_noc_axi1_wvalid,
  fpd_cci_noc_axi1_wready,
  fpd_cci_noc_axi1_bid,
  fpd_cci_noc_axi1_bresp,
  fpd_cci_noc_axi1_bvalid,
  fpd_cci_noc_axi1_bready,
  fpd_cci_noc_axi1_arid,
  fpd_cci_noc_axi1_araddr,
  fpd_cci_noc_axi1_arlen,
  fpd_cci_noc_axi1_arsize,
  fpd_cci_noc_axi1_arburst,
  fpd_cci_noc_axi1_arlock,
  fpd_cci_noc_axi1_arcache,
  fpd_cci_noc_axi1_arprot,
  fpd_cci_noc_axi1_arvalid,
  fpd_cci_noc_axi1_aruser,
  fpd_cci_noc_axi1_arready,
  fpd_cci_noc_axi1_rid,
  fpd_cci_noc_axi1_rdata,
  fpd_cci_noc_axi1_rresp,
  fpd_cci_noc_axi1_rlast,
  fpd_cci_noc_axi1_rvalid,
  fpd_cci_noc_axi1_rready,
  fpd_cci_noc_axi1_awqos,
  fpd_cci_noc_axi1_arqos,
  fpd_cci_noc_axi2_clk,
  fpd_cci_noc_axi2_awid,
  fpd_cci_noc_axi2_awaddr,
  fpd_cci_noc_axi2_awlen,
  fpd_cci_noc_axi2_awsize,
  fpd_cci_noc_axi2_awburst,
  fpd_cci_noc_axi2_awlock,
  fpd_cci_noc_axi2_awcache,
  fpd_cci_noc_axi2_awprot,
  fpd_cci_noc_axi2_awvalid,
  fpd_cci_noc_axi2_awuser,
  fpd_cci_noc_axi2_awready,
  fpd_cci_noc_axi2_wdata,
  fpd_cci_noc_axi2_wstrb,
  fpd_cci_noc_axi2_wuser,
  fpd_cci_noc_axi2_wlast,
  fpd_cci_noc_axi2_wvalid,
  fpd_cci_noc_axi2_wready,
  fpd_cci_noc_axi2_bid,
  fpd_cci_noc_axi2_bresp,
  fpd_cci_noc_axi2_bvalid,
  fpd_cci_noc_axi2_bready,
  fpd_cci_noc_axi2_arid,
  fpd_cci_noc_axi2_araddr,
  fpd_cci_noc_axi2_arlen,
  fpd_cci_noc_axi2_arsize,
  fpd_cci_noc_axi2_arburst,
  fpd_cci_noc_axi2_arlock,
  fpd_cci_noc_axi2_arcache,
  fpd_cci_noc_axi2_arprot,
  fpd_cci_noc_axi2_arvalid,
  fpd_cci_noc_axi2_aruser,
  fpd_cci_noc_axi2_arready,
  fpd_cci_noc_axi2_rid,
  fpd_cci_noc_axi2_rdata,
  fpd_cci_noc_axi2_rresp,
  fpd_cci_noc_axi2_rlast,
  fpd_cci_noc_axi2_rvalid,
  fpd_cci_noc_axi2_rready,
  fpd_cci_noc_axi2_awqos,
  fpd_cci_noc_axi2_arqos,
  fpd_cci_noc_axi3_clk,
  fpd_cci_noc_axi3_awid,
  fpd_cci_noc_axi3_awaddr,
  fpd_cci_noc_axi3_awlen,
  fpd_cci_noc_axi3_awsize,
  fpd_cci_noc_axi3_awburst,
  fpd_cci_noc_axi3_awlock,
  fpd_cci_noc_axi3_awcache,
  fpd_cci_noc_axi3_awprot,
  fpd_cci_noc_axi3_awvalid,
  fpd_cci_noc_axi3_awuser,
  fpd_cci_noc_axi3_awready,
  fpd_cci_noc_axi3_wdata,
  fpd_cci_noc_axi3_wstrb,
  fpd_cci_noc_axi3_wuser,
  fpd_cci_noc_axi3_wlast,
  fpd_cci_noc_axi3_wvalid,
  fpd_cci_noc_axi3_wready,
  fpd_cci_noc_axi3_bid,
  fpd_cci_noc_axi3_bresp,
  fpd_cci_noc_axi3_bvalid,
  fpd_cci_noc_axi3_bready,
  fpd_cci_noc_axi3_arid,
  fpd_cci_noc_axi3_araddr,
  fpd_cci_noc_axi3_arlen,
  fpd_cci_noc_axi3_arsize,
  fpd_cci_noc_axi3_arburst,
  fpd_cci_noc_axi3_arlock,
  fpd_cci_noc_axi3_arcache,
  fpd_cci_noc_axi3_arprot,
  fpd_cci_noc_axi3_arvalid,
  fpd_cci_noc_axi3_aruser,
  fpd_cci_noc_axi3_arready,
  fpd_cci_noc_axi3_rid,
  fpd_cci_noc_axi3_rdata,
  fpd_cci_noc_axi3_rresp,
  fpd_cci_noc_axi3_rlast,
  fpd_cci_noc_axi3_rvalid,
  fpd_cci_noc_axi3_rready,
  fpd_cci_noc_axi3_awqos,
  fpd_cci_noc_axi3_arqos,
  lpd_axi_noc_clk,
  lpd_axi_noc_axi0_awid,
  lpd_axi_noc_axi0_awaddr,
  lpd_axi_noc_axi0_awlen,
  lpd_axi_noc_axi0_awsize,
  lpd_axi_noc_axi0_awburst,
  lpd_axi_noc_axi0_awlock,
  lpd_axi_noc_axi0_awcache,
  lpd_axi_noc_axi0_awprot,
  lpd_axi_noc_axi0_awvalid,
  lpd_axi_noc_axi0_awuser,
  lpd_axi_noc_axi0_awready,
  lpd_axi_noc_axi0_wdata,
  lpd_axi_noc_axi0_wstrb,
  lpd_axi_noc_axi0_wlast,
  lpd_axi_noc_axi0_wvalid,
  lpd_axi_noc_axi0_wready,
  lpd_axi_noc_axi0_bid,
  lpd_axi_noc_axi0_bresp,
  lpd_axi_noc_axi0_bvalid,
  lpd_axi_noc_axi0_bready,
  lpd_axi_noc_axi0_arid,
  lpd_axi_noc_axi0_araddr,
  lpd_axi_noc_axi0_arlen,
  lpd_axi_noc_axi0_arsize,
  lpd_axi_noc_axi0_arburst,
  lpd_axi_noc_axi0_arlock,
  lpd_axi_noc_axi0_arcache,
  lpd_axi_noc_axi0_arprot,
  lpd_axi_noc_axi0_arvalid,
  lpd_axi_noc_axi0_aruser,
  lpd_axi_noc_axi0_arready,
  lpd_axi_noc_axi0_rid,
  lpd_axi_noc_axi0_rdata,
  lpd_axi_noc_axi0_rresp,
  lpd_axi_noc_axi0_rlast,
  lpd_axi_noc_axi0_rvalid,
  lpd_axi_noc_axi0_rready,
  lpd_axi_noc_axi0_awqos,
  lpd_axi_noc_axi0_arqos,
  pmc_axi_noc_axi0_clk,
  pmc_noc_axi0_araddr,
  pmc_noc_axi0_arburst,
  pmc_noc_axi0_arcache,
  pmc_noc_axi0_arid,
  pmc_noc_axi0_arlen,
  pmc_noc_axi0_arlock,
  pmc_noc_axi0_arprot,
  pmc_noc_axi0_arqos,
  pmc_noc_axi0_arregion,
  pmc_noc_axi0_arsize,
  pmc_noc_axi0_aruser,
  pmc_noc_axi0_arvalid,
  pmc_noc_axi0_awaddr,
  pmc_noc_axi0_awburst,
  pmc_noc_axi0_awcache,
  pmc_noc_axi0_awid,
  pmc_noc_axi0_awlen,
  pmc_noc_axi0_awlock,
  pmc_noc_axi0_awprot,
  pmc_noc_axi0_awqos,
  pmc_noc_axi0_awregion,
  pmc_noc_axi0_awsize,
  pmc_noc_axi0_awuser,
  pmc_noc_axi0_awvalid,
  pmc_noc_axi0_bready,
  pmc_noc_axi0_rready,
  pmc_noc_axi0_wdata,
  pmc_noc_axi0_wid,
  pmc_noc_axi0_wlast,
  pmc_noc_axi0_wstrb,
  pmc_noc_axi0_wuser,
  pmc_noc_axi0_wvalid,
  pmc_noc_axi0_arready,
  pmc_noc_axi0_awready,
  pmc_noc_axi0_bid,
  pmc_noc_axi0_bresp,
  pmc_noc_axi0_buser,
  pmc_noc_axi0_bvalid,
  pmc_noc_axi0_rdata,
  pmc_noc_axi0_rid,
  pmc_noc_axi0_rlast,
  pmc_noc_axi0_rresp,
  pmc_noc_axi0_ruser,
  pmc_noc_axi0_rvalid,
  pmc_noc_axi0_wready,
  gem0_tsu_timer_cnt,
  pl_ps_irq0,
  pl_ps_irq1,
  s_axi_xram3_aclk,
  lpd_lsbus_clk,
  ps_ocm2_apb_prdata,
  ps_ocm2_apb_pready,
  ps_ocm2_apb_pslverr,
  ps_ocm2_apb_paddr,
  ps_ocm2_apb_penable,
  ps_ocm2_apb_pprot,
  ps_ocm2_apb_psel,
  ps_ocm2_apb_pstrb,
  ps_ocm2_apb_pwdata,
  ps_ocm2_apb_pwrite,
  ps_ocm2_axi_arready,
  ps_ocm2_axi_awready,
  ps_ocm2_axi_bid,
  ps_ocm2_axi_bresp,
  ps_ocm2_axi_buser,
  ps_ocm2_axi_bvalid,
  ps_ocm2_axi_rdata,
  ps_ocm2_axi_rid,
  ps_ocm2_axi_rlast,
  ps_ocm2_axi_rresp,
  ps_ocm2_axi_ruser,
  ps_ocm2_axi_rvalid,
  ps_ocm2_axi_wready,
  ps_ocm2_axi_araddr,
  ps_ocm2_axi_arburst,
  ps_ocm2_axi_arcache,
  ps_ocm2_axi_arid,
  ps_ocm2_axi_arlen,
  ps_ocm2_axi_arlock,
  ps_ocm2_axi_arprot,
  ps_ocm2_axi_arqos,
  ps_ocm2_axi_arregion,
  ps_ocm2_axi_arsize,
  ps_ocm2_axi_aruser,
  ps_ocm2_axi_arvalid,
  ps_ocm2_axi_awaddr,
  ps_ocm2_axi_awburst,
  ps_ocm2_axi_awcache,
  ps_ocm2_axi_awid,
  ps_ocm2_axi_awlen,
  ps_ocm2_axi_awlock,
  ps_ocm2_axi_awprot,
  ps_ocm2_axi_awqos,
  ps_ocm2_axi_awregion,
  ps_ocm2_axi_awsize,
  ps_ocm2_axi_awuser,
  ps_ocm2_axi_awvalid,
  ps_ocm2_axi_bready,
  ps_ocm2_axi_rready,
  ps_ocm2_axi_wdata,
  ps_ocm2_axi_wid,
  ps_ocm2_axi_wlast,
  ps_ocm2_axi_wstrb,
  ps_ocm2_axi_wuser,
  ps_ocm2_axi_wvalid
);

(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 PL0_REF_CLK CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PL0_REF_CLK, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_pl0_ref_clk, INSERT_VIP 0" *)
output wire pl0_ref_clk;
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 PL0_RESETN RESET" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PL0_RESETN, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
output wire pl0_resetn;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 m_axi_lpd_aclk CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_axi_lpd_aclk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_pl0_ref_clk, ASSOCIATED_BUSIF M_AXI_LPD, INSERT_VIP 0" *)
input wire m_axi_lpd_aclk;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWID" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_LPD, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 44, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_pl0_ref_clk, NUM_READ_THREADS 1, NUM\
_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY pl, MY_CATEGORY ps" *)
output wire [15 : 0] m_axi_lpd_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWADDR" *)
output wire [43 : 0] m_axi_lpd_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWLEN" *)
output wire [7 : 0] m_axi_lpd_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWSIZE" *)
output wire [2 : 0] m_axi_lpd_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWBURST" *)
output wire [1 : 0] m_axi_lpd_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWLOCK" *)
output wire m_axi_lpd_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWCACHE" *)
output wire [3 : 0] m_axi_lpd_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWPROT" *)
output wire [2 : 0] m_axi_lpd_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWVALID" *)
output wire m_axi_lpd_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWUSER" *)
output wire [15 : 0] m_axi_lpd_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWREADY" *)
input wire m_axi_lpd_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WLAST" *)
output wire m_axi_lpd_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WVALID" *)
output wire m_axi_lpd_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WREADY" *)
input wire m_axi_lpd_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD BID" *)
input wire [15 : 0] m_axi_lpd_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD BRESP" *)
input wire [1 : 0] m_axi_lpd_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD BVALID" *)
input wire m_axi_lpd_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD BREADY" *)
output wire m_axi_lpd_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARID" *)
output wire [15 : 0] m_axi_lpd_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARADDR" *)
output wire [43 : 0] m_axi_lpd_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARLEN" *)
output wire [7 : 0] m_axi_lpd_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARSIZE" *)
output wire [2 : 0] m_axi_lpd_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARBURST" *)
output wire [1 : 0] m_axi_lpd_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARLOCK" *)
output wire m_axi_lpd_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARCACHE" *)
output wire [3 : 0] m_axi_lpd_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARPROT" *)
output wire [2 : 0] m_axi_lpd_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARVALID" *)
output wire m_axi_lpd_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARUSER" *)
output wire [15 : 0] m_axi_lpd_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARREADY" *)
input wire m_axi_lpd_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RID" *)
input wire [15 : 0] m_axi_lpd_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RRESP" *)
input wire [1 : 0] m_axi_lpd_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RLAST" *)
input wire m_axi_lpd_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RVALID" *)
input wire m_axi_lpd_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RREADY" *)
output wire m_axi_lpd_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD AWQOS" *)
output wire [3 : 0] m_axi_lpd_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD ARQOS" *)
output wire [3 : 0] m_axi_lpd_arqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WDATA" *)
output wire [127 : 0] m_axi_lpd_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD WSTRB" *)
output wire [15 : 0] m_axi_lpd_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_LPD RDATA" *)
input wire [127 : 0] m_axi_lpd_rdata;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 fpd_cci_noc_axi0_clk CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME fpd_cci_noc_axi0_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk, ASSOCIATED_BUSIF FPD_CCI_NOC_0, INSERT_VIP 0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU" *)
output wire fpd_cci_noc_axi0_clk;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWID" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FPD_CCI_NOC_0, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk, NUM_REA\
D_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_cci, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, INDEX 0" *)
output wire [15 : 0] fpd_cci_noc_axi0_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWADDR" *)
output wire [63 : 0] fpd_cci_noc_axi0_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWLEN" *)
output wire [7 : 0] fpd_cci_noc_axi0_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWSIZE" *)
output wire [2 : 0] fpd_cci_noc_axi0_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWBURST" *)
output wire [1 : 0] fpd_cci_noc_axi0_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWLOCK" *)
output wire fpd_cci_noc_axi0_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWCACHE" *)
output wire [3 : 0] fpd_cci_noc_axi0_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWPROT" *)
output wire [2 : 0] fpd_cci_noc_axi0_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWVALID" *)
output wire fpd_cci_noc_axi0_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWUSER" *)
output wire [17 : 0] fpd_cci_noc_axi0_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWREADY" *)
input wire fpd_cci_noc_axi0_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WDATA" *)
output wire [127 : 0] fpd_cci_noc_axi0_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WSTRB" *)
output wire [15 : 0] fpd_cci_noc_axi0_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WUSER" *)
output wire [16 : 0] fpd_cci_noc_axi0_wuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WLAST" *)
output wire fpd_cci_noc_axi0_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WVALID" *)
output wire fpd_cci_noc_axi0_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WREADY" *)
input wire fpd_cci_noc_axi0_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BID" *)
input wire [15 : 0] fpd_cci_noc_axi0_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BRESP" *)
input wire [1 : 0] fpd_cci_noc_axi0_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BVALID" *)
input wire fpd_cci_noc_axi0_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BREADY" *)
output wire fpd_cci_noc_axi0_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARID" *)
output wire [15 : 0] fpd_cci_noc_axi0_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARADDR" *)
output wire [63 : 0] fpd_cci_noc_axi0_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARLEN" *)
output wire [7 : 0] fpd_cci_noc_axi0_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARSIZE" *)
output wire [2 : 0] fpd_cci_noc_axi0_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARBURST" *)
output wire [1 : 0] fpd_cci_noc_axi0_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARLOCK" *)
output wire fpd_cci_noc_axi0_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARCACHE" *)
output wire [3 : 0] fpd_cci_noc_axi0_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARPROT" *)
output wire [2 : 0] fpd_cci_noc_axi0_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARVALID" *)
output wire fpd_cci_noc_axi0_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARUSER" *)
output wire [17 : 0] fpd_cci_noc_axi0_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARREADY" *)
input wire fpd_cci_noc_axi0_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RID" *)
input wire [15 : 0] fpd_cci_noc_axi0_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RDATA" *)
input wire [127 : 0] fpd_cci_noc_axi0_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RRESP" *)
input wire [1 : 0] fpd_cci_noc_axi0_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RLAST" *)
input wire fpd_cci_noc_axi0_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RVALID" *)
input wire fpd_cci_noc_axi0_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RREADY" *)
output wire fpd_cci_noc_axi0_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWQOS" *)
output wire [3 : 0] fpd_cci_noc_axi0_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARQOS" *)
output wire [3 : 0] fpd_cci_noc_axi0_arqos;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 fpd_cci_noc_axi1_clk CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME fpd_cci_noc_axi1_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk, ASSOCIATED_BUSIF FPD_CCI_NOC_1, INSERT_VIP 0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU" *)
output wire fpd_cci_noc_axi1_clk;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWID" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FPD_CCI_NOC_1, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk, NUM_REA\
D_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_cci, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, INDEX 1" *)
output wire [15 : 0] fpd_cci_noc_axi1_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWADDR" *)
output wire [63 : 0] fpd_cci_noc_axi1_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWLEN" *)
output wire [7 : 0] fpd_cci_noc_axi1_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWSIZE" *)
output wire [2 : 0] fpd_cci_noc_axi1_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWBURST" *)
output wire [1 : 0] fpd_cci_noc_axi1_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWLOCK" *)
output wire fpd_cci_noc_axi1_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWCACHE" *)
output wire [3 : 0] fpd_cci_noc_axi1_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWPROT" *)
output wire [2 : 0] fpd_cci_noc_axi1_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWVALID" *)
output wire fpd_cci_noc_axi1_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWUSER" *)
output wire [17 : 0] fpd_cci_noc_axi1_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWREADY" *)
input wire fpd_cci_noc_axi1_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WDATA" *)
output wire [127 : 0] fpd_cci_noc_axi1_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WSTRB" *)
output wire [15 : 0] fpd_cci_noc_axi1_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WUSER" *)
output wire [16 : 0] fpd_cci_noc_axi1_wuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WLAST" *)
output wire fpd_cci_noc_axi1_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WVALID" *)
output wire fpd_cci_noc_axi1_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WREADY" *)
input wire fpd_cci_noc_axi1_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BID" *)
input wire [15 : 0] fpd_cci_noc_axi1_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BRESP" *)
input wire [1 : 0] fpd_cci_noc_axi1_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BVALID" *)
input wire fpd_cci_noc_axi1_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BREADY" *)
output wire fpd_cci_noc_axi1_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARID" *)
output wire [15 : 0] fpd_cci_noc_axi1_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARADDR" *)
output wire [63 : 0] fpd_cci_noc_axi1_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARLEN" *)
output wire [7 : 0] fpd_cci_noc_axi1_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARSIZE" *)
output wire [2 : 0] fpd_cci_noc_axi1_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARBURST" *)
output wire [1 : 0] fpd_cci_noc_axi1_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARLOCK" *)
output wire fpd_cci_noc_axi1_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARCACHE" *)
output wire [3 : 0] fpd_cci_noc_axi1_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARPROT" *)
output wire [2 : 0] fpd_cci_noc_axi1_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARVALID" *)
output wire fpd_cci_noc_axi1_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARUSER" *)
output wire [17 : 0] fpd_cci_noc_axi1_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARREADY" *)
input wire fpd_cci_noc_axi1_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RID" *)
input wire [15 : 0] fpd_cci_noc_axi1_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RDATA" *)
input wire [127 : 0] fpd_cci_noc_axi1_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RRESP" *)
input wire [1 : 0] fpd_cci_noc_axi1_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RLAST" *)
input wire fpd_cci_noc_axi1_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RVALID" *)
input wire fpd_cci_noc_axi1_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RREADY" *)
output wire fpd_cci_noc_axi1_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWQOS" *)
output wire [3 : 0] fpd_cci_noc_axi1_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARQOS" *)
output wire [3 : 0] fpd_cci_noc_axi1_arqos;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 fpd_cci_noc_axi2_clk CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME fpd_cci_noc_axi2_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk, ASSOCIATED_BUSIF FPD_CCI_NOC_2, INSERT_VIP 0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU" *)
output wire fpd_cci_noc_axi2_clk;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWID" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FPD_CCI_NOC_2, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk, NUM_REA\
D_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_cci, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, INDEX 2" *)
output wire [15 : 0] fpd_cci_noc_axi2_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWADDR" *)
output wire [63 : 0] fpd_cci_noc_axi2_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWLEN" *)
output wire [7 : 0] fpd_cci_noc_axi2_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWSIZE" *)
output wire [2 : 0] fpd_cci_noc_axi2_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWBURST" *)
output wire [1 : 0] fpd_cci_noc_axi2_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWLOCK" *)
output wire fpd_cci_noc_axi2_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWCACHE" *)
output wire [3 : 0] fpd_cci_noc_axi2_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWPROT" *)
output wire [2 : 0] fpd_cci_noc_axi2_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWVALID" *)
output wire fpd_cci_noc_axi2_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWUSER" *)
output wire [17 : 0] fpd_cci_noc_axi2_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWREADY" *)
input wire fpd_cci_noc_axi2_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WDATA" *)
output wire [127 : 0] fpd_cci_noc_axi2_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WSTRB" *)
output wire [15 : 0] fpd_cci_noc_axi2_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WUSER" *)
output wire [16 : 0] fpd_cci_noc_axi2_wuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WLAST" *)
output wire fpd_cci_noc_axi2_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WVALID" *)
output wire fpd_cci_noc_axi2_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WREADY" *)
input wire fpd_cci_noc_axi2_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BID" *)
input wire [15 : 0] fpd_cci_noc_axi2_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BRESP" *)
input wire [1 : 0] fpd_cci_noc_axi2_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BVALID" *)
input wire fpd_cci_noc_axi2_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BREADY" *)
output wire fpd_cci_noc_axi2_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARID" *)
output wire [15 : 0] fpd_cci_noc_axi2_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARADDR" *)
output wire [63 : 0] fpd_cci_noc_axi2_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARLEN" *)
output wire [7 : 0] fpd_cci_noc_axi2_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARSIZE" *)
output wire [2 : 0] fpd_cci_noc_axi2_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARBURST" *)
output wire [1 : 0] fpd_cci_noc_axi2_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARLOCK" *)
output wire fpd_cci_noc_axi2_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARCACHE" *)
output wire [3 : 0] fpd_cci_noc_axi2_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARPROT" *)
output wire [2 : 0] fpd_cci_noc_axi2_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARVALID" *)
output wire fpd_cci_noc_axi2_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARUSER" *)
output wire [17 : 0] fpd_cci_noc_axi2_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARREADY" *)
input wire fpd_cci_noc_axi2_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RID" *)
input wire [15 : 0] fpd_cci_noc_axi2_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RDATA" *)
input wire [127 : 0] fpd_cci_noc_axi2_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RRESP" *)
input wire [1 : 0] fpd_cci_noc_axi2_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RLAST" *)
input wire fpd_cci_noc_axi2_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RVALID" *)
input wire fpd_cci_noc_axi2_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RREADY" *)
output wire fpd_cci_noc_axi2_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWQOS" *)
output wire [3 : 0] fpd_cci_noc_axi2_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARQOS" *)
output wire [3 : 0] fpd_cci_noc_axi2_arqos;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 fpd_cci_noc_axi3_clk CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME fpd_cci_noc_axi3_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk, ASSOCIATED_BUSIF FPD_CCI_NOC_3, INSERT_VIP 0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU" *)
output wire fpd_cci_noc_axi3_clk;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWID" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FPD_CCI_NOC_3, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk, NUM_REA\
D_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_cci, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, INDEX 3" *)
output wire [15 : 0] fpd_cci_noc_axi3_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWADDR" *)
output wire [63 : 0] fpd_cci_noc_axi3_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWLEN" *)
output wire [7 : 0] fpd_cci_noc_axi3_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWSIZE" *)
output wire [2 : 0] fpd_cci_noc_axi3_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWBURST" *)
output wire [1 : 0] fpd_cci_noc_axi3_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWLOCK" *)
output wire fpd_cci_noc_axi3_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWCACHE" *)
output wire [3 : 0] fpd_cci_noc_axi3_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWPROT" *)
output wire [2 : 0] fpd_cci_noc_axi3_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWVALID" *)
output wire fpd_cci_noc_axi3_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWUSER" *)
output wire [17 : 0] fpd_cci_noc_axi3_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWREADY" *)
input wire fpd_cci_noc_axi3_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WDATA" *)
output wire [127 : 0] fpd_cci_noc_axi3_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WSTRB" *)
output wire [15 : 0] fpd_cci_noc_axi3_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WUSER" *)
output wire [16 : 0] fpd_cci_noc_axi3_wuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WLAST" *)
output wire fpd_cci_noc_axi3_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WVALID" *)
output wire fpd_cci_noc_axi3_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WREADY" *)
input wire fpd_cci_noc_axi3_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BID" *)
input wire [15 : 0] fpd_cci_noc_axi3_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BRESP" *)
input wire [1 : 0] fpd_cci_noc_axi3_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BVALID" *)
input wire fpd_cci_noc_axi3_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BREADY" *)
output wire fpd_cci_noc_axi3_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARID" *)
output wire [15 : 0] fpd_cci_noc_axi3_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARADDR" *)
output wire [63 : 0] fpd_cci_noc_axi3_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARLEN" *)
output wire [7 : 0] fpd_cci_noc_axi3_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARSIZE" *)
output wire [2 : 0] fpd_cci_noc_axi3_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARBURST" *)
output wire [1 : 0] fpd_cci_noc_axi3_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARLOCK" *)
output wire fpd_cci_noc_axi3_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARCACHE" *)
output wire [3 : 0] fpd_cci_noc_axi3_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARPROT" *)
output wire [2 : 0] fpd_cci_noc_axi3_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARVALID" *)
output wire fpd_cci_noc_axi3_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARUSER" *)
output wire [17 : 0] fpd_cci_noc_axi3_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARREADY" *)
input wire fpd_cci_noc_axi3_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RID" *)
input wire [15 : 0] fpd_cci_noc_axi3_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RDATA" *)
input wire [127 : 0] fpd_cci_noc_axi3_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RRESP" *)
input wire [1 : 0] fpd_cci_noc_axi3_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RLAST" *)
input wire fpd_cci_noc_axi3_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RVALID" *)
input wire fpd_cci_noc_axi3_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RREADY" *)
output wire fpd_cci_noc_axi3_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWQOS" *)
output wire [3 : 0] fpd_cci_noc_axi3_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARQOS" *)
output wire [3 : 0] fpd_cci_noc_axi3_arqos;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 lpd_axi_noc_clk CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME lpd_axi_noc_clk, FREQ_HZ 400000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_lpd_axi_noc_clk, ASSOCIATED_BUSIF LPD_AXI_NOC_0, INSERT_VIP 0, PHYSICAL_CHANNEL PS_RPU_TO_NOC_NMU" *)
output wire lpd_axi_noc_clk;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWID" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME LPD_AXI_NOC_0, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_lpd_axi_noc_clk, NUM_READ_THRE\
ADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_rpu, PHYSICAL_CHANNEL PS_RPU_TO_NOC_NMU, INDEX 0" *)
output wire [15 : 0] lpd_axi_noc_axi0_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWADDR" *)
output wire [63 : 0] lpd_axi_noc_axi0_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWLEN" *)
output wire [7 : 0] lpd_axi_noc_axi0_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWSIZE" *)
output wire [2 : 0] lpd_axi_noc_axi0_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWBURST" *)
output wire [1 : 0] lpd_axi_noc_axi0_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWLOCK" *)
output wire lpd_axi_noc_axi0_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWCACHE" *)
output wire [3 : 0] lpd_axi_noc_axi0_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWPROT" *)
output wire [2 : 0] lpd_axi_noc_axi0_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWVALID" *)
output wire lpd_axi_noc_axi0_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWUSER" *)
output wire [17 : 0] lpd_axi_noc_axi0_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWREADY" *)
input wire lpd_axi_noc_axi0_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WDATA" *)
output wire [127 : 0] lpd_axi_noc_axi0_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WSTRB" *)
output wire [15 : 0] lpd_axi_noc_axi0_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WLAST" *)
output wire lpd_axi_noc_axi0_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WVALID" *)
output wire lpd_axi_noc_axi0_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WREADY" *)
input wire lpd_axi_noc_axi0_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BID" *)
input wire [15 : 0] lpd_axi_noc_axi0_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BRESP" *)
input wire [1 : 0] lpd_axi_noc_axi0_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BVALID" *)
input wire lpd_axi_noc_axi0_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BREADY" *)
output wire lpd_axi_noc_axi0_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARID" *)
output wire [15 : 0] lpd_axi_noc_axi0_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARADDR" *)
output wire [63 : 0] lpd_axi_noc_axi0_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARLEN" *)
output wire [7 : 0] lpd_axi_noc_axi0_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARSIZE" *)
output wire [2 : 0] lpd_axi_noc_axi0_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARBURST" *)
output wire [1 : 0] lpd_axi_noc_axi0_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARLOCK" *)
output wire lpd_axi_noc_axi0_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARCACHE" *)
output wire [3 : 0] lpd_axi_noc_axi0_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARPROT" *)
output wire [2 : 0] lpd_axi_noc_axi0_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARVALID" *)
output wire lpd_axi_noc_axi0_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARUSER" *)
output wire [17 : 0] lpd_axi_noc_axi0_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARREADY" *)
input wire lpd_axi_noc_axi0_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RID" *)
input wire [15 : 0] lpd_axi_noc_axi0_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RDATA" *)
input wire [127 : 0] lpd_axi_noc_axi0_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RRESP" *)
input wire [1 : 0] lpd_axi_noc_axi0_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RLAST" *)
input wire lpd_axi_noc_axi0_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RVALID" *)
input wire lpd_axi_noc_axi0_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RREADY" *)
output wire lpd_axi_noc_axi0_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWQOS" *)
output wire [3 : 0] lpd_axi_noc_axi0_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARQOS" *)
output wire [3 : 0] lpd_axi_noc_axi0_arqos;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 pmc_axi_noc_axi0_clk CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME pmc_axi_noc_axi0_clk, FREQ_HZ 320000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk, ASSOCIATED_BUSIF PMC_NOC_AXI_0, INSERT_VIP 0, PHYSICAL_CHANNEL PS_PMC_TO_NOC_NMU" *)
output wire pmc_axi_noc_axi0_clk;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARADDR" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PMC_NOC_AXI_0, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 17, BUSER_WIDTH 16, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk, NUM_R\
EAD_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_pmc, PHYSICAL_CHANNEL PS_PMC_TO_NOC_NMU, HD_TANDEM 0, INDEX 0, SLR_INDEX 0" *)
output wire [63 : 0] pmc_noc_axi0_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARBURST" *)
output wire [1 : 0] pmc_noc_axi0_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARCACHE" *)
output wire [3 : 0] pmc_noc_axi0_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARID" *)
output wire [15 : 0] pmc_noc_axi0_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARLEN" *)
output wire [7 : 0] pmc_noc_axi0_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARLOCK" *)
output wire pmc_noc_axi0_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARPROT" *)
output wire [2 : 0] pmc_noc_axi0_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARQOS" *)
output wire [3 : 0] pmc_noc_axi0_arqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARREGION" *)
output wire [3 : 0] pmc_noc_axi0_arregion;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARSIZE" *)
output wire [2 : 0] pmc_noc_axi0_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARUSER" *)
output wire [17 : 0] pmc_noc_axi0_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARVALID" *)
output wire pmc_noc_axi0_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWADDR" *)
output wire [63 : 0] pmc_noc_axi0_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWBURST" *)
output wire [1 : 0] pmc_noc_axi0_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWCACHE" *)
output wire [3 : 0] pmc_noc_axi0_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWID" *)
output wire [15 : 0] pmc_noc_axi0_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWLEN" *)
output wire [7 : 0] pmc_noc_axi0_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWLOCK" *)
output wire pmc_noc_axi0_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWPROT" *)
output wire [2 : 0] pmc_noc_axi0_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWQOS" *)
output wire [3 : 0] pmc_noc_axi0_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWREGION" *)
output wire [3 : 0] pmc_noc_axi0_awregion;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWSIZE" *)
output wire [2 : 0] pmc_noc_axi0_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWUSER" *)
output wire [17 : 0] pmc_noc_axi0_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWVALID" *)
output wire pmc_noc_axi0_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BREADY" *)
output wire pmc_noc_axi0_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RREADY" *)
output wire pmc_noc_axi0_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WDATA" *)
output wire [127 : 0] pmc_noc_axi0_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WID" *)
output wire [15 : 0] pmc_noc_axi0_wid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WLAST" *)
output wire pmc_noc_axi0_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WSTRB" *)
output wire [15 : 0] pmc_noc_axi0_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WUSER" *)
output wire [16 : 0] pmc_noc_axi0_wuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WVALID" *)
output wire pmc_noc_axi0_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARREADY" *)
input wire pmc_noc_axi0_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWREADY" *)
input wire pmc_noc_axi0_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BID" *)
input wire [15 : 0] pmc_noc_axi0_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BRESP" *)
input wire [1 : 0] pmc_noc_axi0_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BUSER" *)
input wire [15 : 0] pmc_noc_axi0_buser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BVALID" *)
input wire pmc_noc_axi0_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RDATA" *)
input wire [127 : 0] pmc_noc_axi0_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RID" *)
input wire [15 : 0] pmc_noc_axi0_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RLAST" *)
input wire pmc_noc_axi0_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RRESP" *)
input wire [1 : 0] pmc_noc_axi0_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RUSER" *)
input wire [16 : 0] pmc_noc_axi0_ruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RVALID" *)
input wire pmc_noc_axi0_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WREADY" *)
input wire pmc_noc_axi0_wready;
output wire [93 : 0] gem0_tsu_timer_cnt;
(* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 PL_PS_IRQ0 INTERRUPT" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PL_PS_IRQ0, SENSITIVITY LEVEL_HIGH, PortWidth 1" *)
input wire pl_ps_irq0;
(* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 PL_PS_IRQ1 INTERRUPT" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PL_PS_IRQ1, SENSITIVITY LEVEL_HIGH, PortWidth 1" *)
input wire pl_ps_irq1;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_xram3_aclk CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_xram3_aclk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_s_axi_xram3_aclk, ASSOCIATED_BUSIF S_AXI_XRAM3, INSERT_VIP 0" *)
output wire s_axi_xram3_aclk;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 lpd_lsbus_clk LPD_LSBUS_CLK" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME lpd_lsbus_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_lpd_lsbus_clk, INSERT_VIP 0" *)
output wire lpd_lsbus_clk;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PRDATA" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_APB_XRAM, ADDR_WIDTH 32" *)
input wire [31 : 0] ps_ocm2_apb_prdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PREADY" *)
input wire ps_ocm2_apb_pready;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PSLVERR" *)
input wire ps_ocm2_apb_pslverr;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PADDR" *)
output wire [31 : 0] ps_ocm2_apb_paddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PENABLE" *)
output wire ps_ocm2_apb_penable;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PPROT" *)
output wire [2 : 0] ps_ocm2_apb_pprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PSEL" *)
output wire ps_ocm2_apb_psel;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PSTRB" *)
output wire [3 : 0] ps_ocm2_apb_pstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PWDATA" *)
output wire [31 : 0] ps_ocm2_apb_pwdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PWRITE" *)
output wire [0 : 0] ps_ocm2_apb_pwrite;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARREADY" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_XRAM3, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 18, RUSER_WIDTH 18, BUSER_WIDTH 1, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE \
0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
input wire ps_ocm2_axi_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWREADY" *)
input wire ps_ocm2_axi_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BID" *)
input wire [15 : 0] ps_ocm2_axi_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BRESP" *)
input wire [1 : 0] ps_ocm2_axi_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BUSER" *)
input wire ps_ocm2_axi_buser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BVALID" *)
input wire ps_ocm2_axi_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RDATA" *)
input wire [127 : 0] ps_ocm2_axi_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RID" *)
input wire [15 : 0] ps_ocm2_axi_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RLAST" *)
input wire ps_ocm2_axi_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RRESP" *)
input wire [1 : 0] ps_ocm2_axi_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RUSER" *)
input wire [17 : 0] ps_ocm2_axi_ruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RVALID" *)
input wire ps_ocm2_axi_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WREADY" *)
input wire ps_ocm2_axi_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARADDR" *)
output wire [63 : 0] ps_ocm2_axi_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARBURST" *)
output wire [1 : 0] ps_ocm2_axi_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARCACHE" *)
output wire [3 : 0] ps_ocm2_axi_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARID" *)
output wire [15 : 0] ps_ocm2_axi_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARLEN" *)
output wire [7 : 0] ps_ocm2_axi_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARLOCK" *)
output wire ps_ocm2_axi_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARPROT" *)
output wire [2 : 0] ps_ocm2_axi_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARQOS" *)
output wire [3 : 0] ps_ocm2_axi_arqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARREGION" *)
output wire [3 : 0] ps_ocm2_axi_arregion;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARSIZE" *)
output wire [2 : 0] ps_ocm2_axi_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARUSER" *)
output wire [15 : 0] ps_ocm2_axi_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARVALID" *)
output wire ps_ocm2_axi_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWADDR" *)
output wire [63 : 0] ps_ocm2_axi_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWBURST" *)
output wire [1 : 0] ps_ocm2_axi_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWCACHE" *)
output wire [3 : 0] ps_ocm2_axi_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWID" *)
output wire [15 : 0] ps_ocm2_axi_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWLEN" *)
output wire [7 : 0] ps_ocm2_axi_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWLOCK" *)
output wire ps_ocm2_axi_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWPROT" *)
output wire [2 : 0] ps_ocm2_axi_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWQOS" *)
output wire [3 : 0] ps_ocm2_axi_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWREGION" *)
output wire [3 : 0] ps_ocm2_axi_awregion;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWSIZE" *)
output wire [2 : 0] ps_ocm2_axi_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWUSER" *)
output wire [15 : 0] ps_ocm2_axi_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWVALID" *)
output wire ps_ocm2_axi_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BREADY" *)
output wire ps_ocm2_axi_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RREADY" *)
output wire ps_ocm2_axi_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WDATA" *)
output wire [127 : 0] ps_ocm2_axi_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WID" *)
output wire [15 : 0] ps_ocm2_axi_wid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WLAST" *)
output wire ps_ocm2_axi_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WSTRB" *)
output wire [15 : 0] ps_ocm2_axi_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WUSER" *)
output wire [17 : 0] ps_ocm2_axi_wuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WVALID" *)
output wire ps_ocm2_axi_wvalid;

  pspmc_v1_4_7_pspmc #(
    .C_M_AXI_GP0_DATA_WIDTH(128),
    .C_M_AXI_GP2_DATA_WIDTH(128),
    .C_DIFF_RW_CLK_S_AXI_GP0(0),
    .C_DIFF_RW_CLK_S_AXI_GP2(0),
    .C_DIFF_RW_CLK_S_AXI_GP4(0),
    .C_S_AXI_GP0_DATA_WIDTH(128),
    .C_S_AXI_GP2_DATA_WIDTH(128),
    .C_S_AXI_GP4_DATA_WIDTH(128),
    .C_S_AXI_ACP_DATA_WIDTH(128),
    .C_S_AXI_ACE_DATA_WIDTH(128),
    .C_PS_NOC_CCI_DATA_WIDTH(128),
    .C_PS_NOC_NCI_DATA_WIDTH(128),
    .C_NOC_PS_CCI_DATA_WIDTH(128),
    .C_PS_NOC_PMC_DATA_WIDTH(128),
    .C_NOC_PS_PMC_DATA_WIDTH(128),
    .C_PS_NOC_RPU_DATA_WIDTH(128),
    .C_PS_EMIO_GPIO_WIDTH(32),
    .C_PMC_EMIO_GPIO_WIDTH(64),
    .C_PMC_GPO_WIDTH(32),
    .C_PMC_GPI_WIDTH(32),
    .C_PL_SEM_GPO_ENABLE(0),
    .C_PMC_NOC_ADDR_WIDTH(64),
    .C_PMC_NOC_DATA_WIDTH(128),
    .C_NOC_PMC_ADDR_WIDTH(64),
    .C_NOC_PMC_DATA_WIDTH(128),
    .C_XDEVICE("xcve2302"),
    .C_SIM_DEVICE("VERSAL_AI_CORE"),
    .C_SPP_PSPMC_TO_CORE_WIDTH(12000),
    .C_SPP_PSPMC_FROM_CORE_WIDTH(12000),
    .C_NUM_F2P0_INTR_INPUTS("1"),
    .C_NUM_F2P1_INTR_INPUTS("1"),
    .C_PMCPL_CLK0_BUF(1),
    .C_PMCPL_CLK1_BUF(0),
    .C_PMCPL_CLK2_BUF(0),
    .C_PMCPL_CLK3_BUF(0),
    .C_PMCPL_IRO_CLK_BUF(0),
    .C_ACE_LITE(0),
    .C_PS_USE_S_AXI_GP2(0),
    .C_AXI4_EXT_USER_BITS(0),
    .C_PMC_USE_PL_ERR0(0),
    .C_PMC_USE_PL_ERR1(0),
    .C_PMC_USE_PL_ERR2(0),
    .C_PMC_USE_PL_ERR3(0),
    .C_PS_PMU_PERIPHERAL_ENABLE(0),
    .C_SUBCORE_NAME("design_2_versal_cips_0_0_gt_quad_base"),
    .C_VIP_SUBCORE_NAME("versal_cips_ps_vip"),
    .C_CORE_NAME("design_2_versal_cips_0_0"),
    .C_SD0_DATA_WIDTH(8),
    .C_SD1_DATA_WIDTH(4),
    .C_PS_TRACE_WIDTH(2),
    .C_PS_TRACE_PERIPHERAL(0),
    .C_PS_USE_STARTUP(0),
    .C_PS_USE_CAPTURE(0),
    .C_SLR1_PS_USE_CAPTURE(0),
    .C_SLR2_PS_USE_CAPTURE(0),
    .C_SLR3_PS_USE_CAPTURE(0),
    .C_PS_USE_RPU_INTERRUPT(0),
    .C_PS_PCIE_EP_RESET1_IO("None"),
    .C_PS_PCIE_EP_RESET2_IO("None"),
    .C_PS_TIE_MJTAG_TCK_TO_GND(1),
    .C_LPD_GPIO_EMIO_ENABLE(0),
    .C_PMC_GPIO_EMIO_ENABLE(0),
    .C_PS_I2C0_PERIPHERAL_ENABLE(0),
    .C_PS_I2C1_PERIPHERAL_ENABLE(0),
    .C_PMC_I2CPMC_PERIPHERAL(0),
    .C_GEM0_TSU_INC_CTRL(3),
    .C_GEM_TSU_ENABLE(1)
  ) inst (
    .pl0_ref_clk(pl0_ref_clk),
    .pl0_resetn(pl0_resetn),
    .m_axi_lpd_aclk(m_axi_lpd_aclk),
    .m_axi_lpd_awid(m_axi_lpd_awid),
    .m_axi_lpd_awaddr(m_axi_lpd_awaddr),
    .m_axi_lpd_awlen(m_axi_lpd_awlen),
    .m_axi_lpd_awsize(m_axi_lpd_awsize),
    .m_axi_lpd_awburst(m_axi_lpd_awburst),
    .m_axi_lpd_awlock(m_axi_lpd_awlock),
    .m_axi_lpd_awcache(m_axi_lpd_awcache),
    .m_axi_lpd_awprot(m_axi_lpd_awprot),
    .m_axi_lpd_awvalid(m_axi_lpd_awvalid),
    .m_axi_lpd_awuser(m_axi_lpd_awuser),
    .m_axi_lpd_awready(m_axi_lpd_awready),
    .m_axi_lpd_wlast(m_axi_lpd_wlast),
    .m_axi_lpd_wvalid(m_axi_lpd_wvalid),
    .m_axi_lpd_wready(m_axi_lpd_wready),
    .m_axi_lpd_bid(m_axi_lpd_bid),
    .m_axi_lpd_bresp(m_axi_lpd_bresp),
    .m_axi_lpd_bvalid(m_axi_lpd_bvalid),
    .m_axi_lpd_bready(m_axi_lpd_bready),
    .m_axi_lpd_arid(m_axi_lpd_arid),
    .m_axi_lpd_araddr(m_axi_lpd_araddr),
    .m_axi_lpd_arlen(m_axi_lpd_arlen),
    .m_axi_lpd_arsize(m_axi_lpd_arsize),
    .m_axi_lpd_arburst(m_axi_lpd_arburst),
    .m_axi_lpd_arlock(m_axi_lpd_arlock),
    .m_axi_lpd_arcache(m_axi_lpd_arcache),
    .m_axi_lpd_arprot(m_axi_lpd_arprot),
    .m_axi_lpd_arvalid(m_axi_lpd_arvalid),
    .m_axi_lpd_aruser(m_axi_lpd_aruser),
    .m_axi_lpd_arready(m_axi_lpd_arready),
    .m_axi_lpd_rid(m_axi_lpd_rid),
    .m_axi_lpd_rresp(m_axi_lpd_rresp),
    .m_axi_lpd_rlast(m_axi_lpd_rlast),
    .m_axi_lpd_rvalid(m_axi_lpd_rvalid),
    .m_axi_lpd_rready(m_axi_lpd_rready),
    .m_axi_lpd_awqos(m_axi_lpd_awqos),
    .m_axi_lpd_arqos(m_axi_lpd_arqos),
    .m_axi_lpd_wdata(m_axi_lpd_wdata),
    .m_axi_lpd_wstrb(m_axi_lpd_wstrb),
    .m_axi_lpd_rdata(m_axi_lpd_rdata),
    .fpd_cci_noc_axi0_clk(fpd_cci_noc_axi0_clk),
    .fpd_cci_noc_axi0_awid(fpd_cci_noc_axi0_awid),
    .fpd_cci_noc_axi0_awaddr(fpd_cci_noc_axi0_awaddr),
    .fpd_cci_noc_axi0_awlen(fpd_cci_noc_axi0_awlen),
    .fpd_cci_noc_axi0_awsize(fpd_cci_noc_axi0_awsize),
    .fpd_cci_noc_axi0_awburst(fpd_cci_noc_axi0_awburst),
    .fpd_cci_noc_axi0_awlock(fpd_cci_noc_axi0_awlock),
    .fpd_cci_noc_axi0_awcache(fpd_cci_noc_axi0_awcache),
    .fpd_cci_noc_axi0_awprot(fpd_cci_noc_axi0_awprot),
    .fpd_cci_noc_axi0_awvalid(fpd_cci_noc_axi0_awvalid),
    .fpd_cci_noc_axi0_awuser(fpd_cci_noc_axi0_awuser),
    .fpd_cci_noc_axi0_awready(fpd_cci_noc_axi0_awready),
    .fpd_cci_noc_axi0_wdata(fpd_cci_noc_axi0_wdata),
    .fpd_cci_noc_axi0_wstrb(fpd_cci_noc_axi0_wstrb),
    .fpd_cci_noc_axi0_wuser(fpd_cci_noc_axi0_wuser),
    .fpd_cci_noc_axi0_wlast(fpd_cci_noc_axi0_wlast),
    .fpd_cci_noc_axi0_wvalid(fpd_cci_noc_axi0_wvalid),
    .fpd_cci_noc_axi0_wready(fpd_cci_noc_axi0_wready),
    .fpd_cci_noc_axi0_bid(fpd_cci_noc_axi0_bid),
    .fpd_cci_noc_axi0_bresp(fpd_cci_noc_axi0_bresp),
    .fpd_cci_noc_axi0_bvalid(fpd_cci_noc_axi0_bvalid),
    .fpd_cci_noc_axi0_bready(fpd_cci_noc_axi0_bready),
    .fpd_cci_noc_axi0_arid(fpd_cci_noc_axi0_arid),
    .fpd_cci_noc_axi0_araddr(fpd_cci_noc_axi0_araddr),
    .fpd_cci_noc_axi0_arlen(fpd_cci_noc_axi0_arlen),
    .fpd_cci_noc_axi0_arsize(fpd_cci_noc_axi0_arsize),
    .fpd_cci_noc_axi0_arburst(fpd_cci_noc_axi0_arburst),
    .fpd_cci_noc_axi0_arlock(fpd_cci_noc_axi0_arlock),
    .fpd_cci_noc_axi0_arcache(fpd_cci_noc_axi0_arcache),
    .fpd_cci_noc_axi0_arprot(fpd_cci_noc_axi0_arprot),
    .fpd_cci_noc_axi0_arvalid(fpd_cci_noc_axi0_arvalid),
    .fpd_cci_noc_axi0_aruser(fpd_cci_noc_axi0_aruser),
    .fpd_cci_noc_axi0_arready(fpd_cci_noc_axi0_arready),
    .fpd_cci_noc_axi0_rid(fpd_cci_noc_axi0_rid),
    .fpd_cci_noc_axi0_rdata(fpd_cci_noc_axi0_rdata),
    .fpd_cci_noc_axi0_rresp(fpd_cci_noc_axi0_rresp),
    .fpd_cci_noc_axi0_rlast(fpd_cci_noc_axi0_rlast),
    .fpd_cci_noc_axi0_rvalid(fpd_cci_noc_axi0_rvalid),
    .fpd_cci_noc_axi0_rready(fpd_cci_noc_axi0_rready),
    .fpd_cci_noc_axi0_awqos(fpd_cci_noc_axi0_awqos),
    .fpd_cci_noc_axi0_arqos(fpd_cci_noc_axi0_arqos),
    .fpd_cci_noc_axi1_clk(fpd_cci_noc_axi1_clk),
    .fpd_cci_noc_axi1_awid(fpd_cci_noc_axi1_awid),
    .fpd_cci_noc_axi1_awaddr(fpd_cci_noc_axi1_awaddr),
    .fpd_cci_noc_axi1_awlen(fpd_cci_noc_axi1_awlen),
    .fpd_cci_noc_axi1_awsize(fpd_cci_noc_axi1_awsize),
    .fpd_cci_noc_axi1_awburst(fpd_cci_noc_axi1_awburst),
    .fpd_cci_noc_axi1_awlock(fpd_cci_noc_axi1_awlock),
    .fpd_cci_noc_axi1_awcache(fpd_cci_noc_axi1_awcache),
    .fpd_cci_noc_axi1_awprot(fpd_cci_noc_axi1_awprot),
    .fpd_cci_noc_axi1_awvalid(fpd_cci_noc_axi1_awvalid),
    .fpd_cci_noc_axi1_awuser(fpd_cci_noc_axi1_awuser),
    .fpd_cci_noc_axi1_awready(fpd_cci_noc_axi1_awready),
    .fpd_cci_noc_axi1_wdata(fpd_cci_noc_axi1_wdata),
    .fpd_cci_noc_axi1_wstrb(fpd_cci_noc_axi1_wstrb),
    .fpd_cci_noc_axi1_wuser(fpd_cci_noc_axi1_wuser),
    .fpd_cci_noc_axi1_wlast(fpd_cci_noc_axi1_wlast),
    .fpd_cci_noc_axi1_wvalid(fpd_cci_noc_axi1_wvalid),
    .fpd_cci_noc_axi1_wready(fpd_cci_noc_axi1_wready),
    .fpd_cci_noc_axi1_bid(fpd_cci_noc_axi1_bid),
    .fpd_cci_noc_axi1_bresp(fpd_cci_noc_axi1_bresp),
    .fpd_cci_noc_axi1_bvalid(fpd_cci_noc_axi1_bvalid),
    .fpd_cci_noc_axi1_bready(fpd_cci_noc_axi1_bready),
    .fpd_cci_noc_axi1_arid(fpd_cci_noc_axi1_arid),
    .fpd_cci_noc_axi1_araddr(fpd_cci_noc_axi1_araddr),
    .fpd_cci_noc_axi1_arlen(fpd_cci_noc_axi1_arlen),
    .fpd_cci_noc_axi1_arsize(fpd_cci_noc_axi1_arsize),
    .fpd_cci_noc_axi1_arburst(fpd_cci_noc_axi1_arburst),
    .fpd_cci_noc_axi1_arlock(fpd_cci_noc_axi1_arlock),
    .fpd_cci_noc_axi1_arcache(fpd_cci_noc_axi1_arcache),
    .fpd_cci_noc_axi1_arprot(fpd_cci_noc_axi1_arprot),
    .fpd_cci_noc_axi1_arvalid(fpd_cci_noc_axi1_arvalid),
    .fpd_cci_noc_axi1_aruser(fpd_cci_noc_axi1_aruser),
    .fpd_cci_noc_axi1_arready(fpd_cci_noc_axi1_arready),
    .fpd_cci_noc_axi1_rid(fpd_cci_noc_axi1_rid),
    .fpd_cci_noc_axi1_rdata(fpd_cci_noc_axi1_rdata),
    .fpd_cci_noc_axi1_rresp(fpd_cci_noc_axi1_rresp),
    .fpd_cci_noc_axi1_rlast(fpd_cci_noc_axi1_rlast),
    .fpd_cci_noc_axi1_rvalid(fpd_cci_noc_axi1_rvalid),
    .fpd_cci_noc_axi1_rready(fpd_cci_noc_axi1_rready),
    .fpd_cci_noc_axi1_awqos(fpd_cci_noc_axi1_awqos),
    .fpd_cci_noc_axi1_arqos(fpd_cci_noc_axi1_arqos),
    .fpd_cci_noc_axi2_clk(fpd_cci_noc_axi2_clk),
    .fpd_cci_noc_axi2_awid(fpd_cci_noc_axi2_awid),
    .fpd_cci_noc_axi2_awaddr(fpd_cci_noc_axi2_awaddr),
    .fpd_cci_noc_axi2_awlen(fpd_cci_noc_axi2_awlen),
    .fpd_cci_noc_axi2_awsize(fpd_cci_noc_axi2_awsize),
    .fpd_cci_noc_axi2_awburst(fpd_cci_noc_axi2_awburst),
    .fpd_cci_noc_axi2_awlock(fpd_cci_noc_axi2_awlock),
    .fpd_cci_noc_axi2_awcache(fpd_cci_noc_axi2_awcache),
    .fpd_cci_noc_axi2_awprot(fpd_cci_noc_axi2_awprot),
    .fpd_cci_noc_axi2_awvalid(fpd_cci_noc_axi2_awvalid),
    .fpd_cci_noc_axi2_awuser(fpd_cci_noc_axi2_awuser),
    .fpd_cci_noc_axi2_awready(fpd_cci_noc_axi2_awready),
    .fpd_cci_noc_axi2_wdata(fpd_cci_noc_axi2_wdata),
    .fpd_cci_noc_axi2_wstrb(fpd_cci_noc_axi2_wstrb),
    .fpd_cci_noc_axi2_wuser(fpd_cci_noc_axi2_wuser),
    .fpd_cci_noc_axi2_wlast(fpd_cci_noc_axi2_wlast),
    .fpd_cci_noc_axi2_wvalid(fpd_cci_noc_axi2_wvalid),
    .fpd_cci_noc_axi2_wready(fpd_cci_noc_axi2_wready),
    .fpd_cci_noc_axi2_bid(fpd_cci_noc_axi2_bid),
    .fpd_cci_noc_axi2_bresp(fpd_cci_noc_axi2_bresp),
    .fpd_cci_noc_axi2_bvalid(fpd_cci_noc_axi2_bvalid),
    .fpd_cci_noc_axi2_bready(fpd_cci_noc_axi2_bready),
    .fpd_cci_noc_axi2_arid(fpd_cci_noc_axi2_arid),
    .fpd_cci_noc_axi2_araddr(fpd_cci_noc_axi2_araddr),
    .fpd_cci_noc_axi2_arlen(fpd_cci_noc_axi2_arlen),
    .fpd_cci_noc_axi2_arsize(fpd_cci_noc_axi2_arsize),
    .fpd_cci_noc_axi2_arburst(fpd_cci_noc_axi2_arburst),
    .fpd_cci_noc_axi2_arlock(fpd_cci_noc_axi2_arlock),
    .fpd_cci_noc_axi2_arcache(fpd_cci_noc_axi2_arcache),
    .fpd_cci_noc_axi2_arprot(fpd_cci_noc_axi2_arprot),
    .fpd_cci_noc_axi2_arvalid(fpd_cci_noc_axi2_arvalid),
    .fpd_cci_noc_axi2_aruser(fpd_cci_noc_axi2_aruser),
    .fpd_cci_noc_axi2_arready(fpd_cci_noc_axi2_arready),
    .fpd_cci_noc_axi2_rid(fpd_cci_noc_axi2_rid),
    .fpd_cci_noc_axi2_rdata(fpd_cci_noc_axi2_rdata),
    .fpd_cci_noc_axi2_rresp(fpd_cci_noc_axi2_rresp),
    .fpd_cci_noc_axi2_rlast(fpd_cci_noc_axi2_rlast),
    .fpd_cci_noc_axi2_rvalid(fpd_cci_noc_axi2_rvalid),
    .fpd_cci_noc_axi2_rready(fpd_cci_noc_axi2_rready),
    .fpd_cci_noc_axi2_awqos(fpd_cci_noc_axi2_awqos),
    .fpd_cci_noc_axi2_arqos(fpd_cci_noc_axi2_arqos),
    .fpd_cci_noc_axi3_clk(fpd_cci_noc_axi3_clk),
    .fpd_cci_noc_axi3_awid(fpd_cci_noc_axi3_awid),
    .fpd_cci_noc_axi3_awaddr(fpd_cci_noc_axi3_awaddr),
    .fpd_cci_noc_axi3_awlen(fpd_cci_noc_axi3_awlen),
    .fpd_cci_noc_axi3_awsize(fpd_cci_noc_axi3_awsize),
    .fpd_cci_noc_axi3_awburst(fpd_cci_noc_axi3_awburst),
    .fpd_cci_noc_axi3_awlock(fpd_cci_noc_axi3_awlock),
    .fpd_cci_noc_axi3_awcache(fpd_cci_noc_axi3_awcache),
    .fpd_cci_noc_axi3_awprot(fpd_cci_noc_axi3_awprot),
    .fpd_cci_noc_axi3_awvalid(fpd_cci_noc_axi3_awvalid),
    .fpd_cci_noc_axi3_awuser(fpd_cci_noc_axi3_awuser),
    .fpd_cci_noc_axi3_awready(fpd_cci_noc_axi3_awready),
    .fpd_cci_noc_axi3_wdata(fpd_cci_noc_axi3_wdata),
    .fpd_cci_noc_axi3_wstrb(fpd_cci_noc_axi3_wstrb),
    .fpd_cci_noc_axi3_wuser(fpd_cci_noc_axi3_wuser),
    .fpd_cci_noc_axi3_wlast(fpd_cci_noc_axi3_wlast),
    .fpd_cci_noc_axi3_wvalid(fpd_cci_noc_axi3_wvalid),
    .fpd_cci_noc_axi3_wready(fpd_cci_noc_axi3_wready),
    .fpd_cci_noc_axi3_bid(fpd_cci_noc_axi3_bid),
    .fpd_cci_noc_axi3_bresp(fpd_cci_noc_axi3_bresp),
    .fpd_cci_noc_axi3_bvalid(fpd_cci_noc_axi3_bvalid),
    .fpd_cci_noc_axi3_bready(fpd_cci_noc_axi3_bready),
    .fpd_cci_noc_axi3_arid(fpd_cci_noc_axi3_arid),
    .fpd_cci_noc_axi3_araddr(fpd_cci_noc_axi3_araddr),
    .fpd_cci_noc_axi3_arlen(fpd_cci_noc_axi3_arlen),
    .fpd_cci_noc_axi3_arsize(fpd_cci_noc_axi3_arsize),
    .fpd_cci_noc_axi3_arburst(fpd_cci_noc_axi3_arburst),
    .fpd_cci_noc_axi3_arlock(fpd_cci_noc_axi3_arlock),
    .fpd_cci_noc_axi3_arcache(fpd_cci_noc_axi3_arcache),
    .fpd_cci_noc_axi3_arprot(fpd_cci_noc_axi3_arprot),
    .fpd_cci_noc_axi3_arvalid(fpd_cci_noc_axi3_arvalid),
    .fpd_cci_noc_axi3_aruser(fpd_cci_noc_axi3_aruser),
    .fpd_cci_noc_axi3_arready(fpd_cci_noc_axi3_arready),
    .fpd_cci_noc_axi3_rid(fpd_cci_noc_axi3_rid),
    .fpd_cci_noc_axi3_rdata(fpd_cci_noc_axi3_rdata),
    .fpd_cci_noc_axi3_rresp(fpd_cci_noc_axi3_rresp),
    .fpd_cci_noc_axi3_rlast(fpd_cci_noc_axi3_rlast),
    .fpd_cci_noc_axi3_rvalid(fpd_cci_noc_axi3_rvalid),
    .fpd_cci_noc_axi3_rready(fpd_cci_noc_axi3_rready),
    .fpd_cci_noc_axi3_awqos(fpd_cci_noc_axi3_awqos),
    .fpd_cci_noc_axi3_arqos(fpd_cci_noc_axi3_arqos),
    .lpd_axi_noc_clk(lpd_axi_noc_clk),
    .lpd_axi_noc_axi0_awid(lpd_axi_noc_axi0_awid),
    .lpd_axi_noc_axi0_awaddr(lpd_axi_noc_axi0_awaddr),
    .lpd_axi_noc_axi0_awlen(lpd_axi_noc_axi0_awlen),
    .lpd_axi_noc_axi0_awsize(lpd_axi_noc_axi0_awsize),
    .lpd_axi_noc_axi0_awburst(lpd_axi_noc_axi0_awburst),
    .lpd_axi_noc_axi0_awlock(lpd_axi_noc_axi0_awlock),
    .lpd_axi_noc_axi0_awcache(lpd_axi_noc_axi0_awcache),
    .lpd_axi_noc_axi0_awprot(lpd_axi_noc_axi0_awprot),
    .lpd_axi_noc_axi0_awvalid(lpd_axi_noc_axi0_awvalid),
    .lpd_axi_noc_axi0_awuser(lpd_axi_noc_axi0_awuser),
    .lpd_axi_noc_axi0_awready(lpd_axi_noc_axi0_awready),
    .lpd_axi_noc_axi0_wdata(lpd_axi_noc_axi0_wdata),
    .lpd_axi_noc_axi0_wstrb(lpd_axi_noc_axi0_wstrb),
    .lpd_axi_noc_axi0_wlast(lpd_axi_noc_axi0_wlast),
    .lpd_axi_noc_axi0_wvalid(lpd_axi_noc_axi0_wvalid),
    .lpd_axi_noc_axi0_wready(lpd_axi_noc_axi0_wready),
    .lpd_axi_noc_axi0_bid(lpd_axi_noc_axi0_bid),
    .lpd_axi_noc_axi0_bresp(lpd_axi_noc_axi0_bresp),
    .lpd_axi_noc_axi0_bvalid(lpd_axi_noc_axi0_bvalid),
    .lpd_axi_noc_axi0_bready(lpd_axi_noc_axi0_bready),
    .lpd_axi_noc_axi0_arid(lpd_axi_noc_axi0_arid),
    .lpd_axi_noc_axi0_araddr(lpd_axi_noc_axi0_araddr),
    .lpd_axi_noc_axi0_arlen(lpd_axi_noc_axi0_arlen),
    .lpd_axi_noc_axi0_arsize(lpd_axi_noc_axi0_arsize),
    .lpd_axi_noc_axi0_arburst(lpd_axi_noc_axi0_arburst),
    .lpd_axi_noc_axi0_arlock(lpd_axi_noc_axi0_arlock),
    .lpd_axi_noc_axi0_arcache(lpd_axi_noc_axi0_arcache),
    .lpd_axi_noc_axi0_arprot(lpd_axi_noc_axi0_arprot),
    .lpd_axi_noc_axi0_arvalid(lpd_axi_noc_axi0_arvalid),
    .lpd_axi_noc_axi0_aruser(lpd_axi_noc_axi0_aruser),
    .lpd_axi_noc_axi0_arready(lpd_axi_noc_axi0_arready),
    .lpd_axi_noc_axi0_rid(lpd_axi_noc_axi0_rid),
    .lpd_axi_noc_axi0_rdata(lpd_axi_noc_axi0_rdata),
    .lpd_axi_noc_axi0_rresp(lpd_axi_noc_axi0_rresp),
    .lpd_axi_noc_axi0_rlast(lpd_axi_noc_axi0_rlast),
    .lpd_axi_noc_axi0_rvalid(lpd_axi_noc_axi0_rvalid),
    .lpd_axi_noc_axi0_rready(lpd_axi_noc_axi0_rready),
    .lpd_axi_noc_axi0_awqos(lpd_axi_noc_axi0_awqos),
    .lpd_axi_noc_axi0_arqos(lpd_axi_noc_axi0_arqos),
    .pmc_axi_noc_axi0_clk(pmc_axi_noc_axi0_clk),
    .pmc_noc_axi0_araddr(pmc_noc_axi0_araddr),
    .pmc_noc_axi0_arburst(pmc_noc_axi0_arburst),
    .pmc_noc_axi0_arcache(pmc_noc_axi0_arcache),
    .pmc_noc_axi0_arid(pmc_noc_axi0_arid),
    .pmc_noc_axi0_arlen(pmc_noc_axi0_arlen),
    .pmc_noc_axi0_arlock(pmc_noc_axi0_arlock),
    .pmc_noc_axi0_arprot(pmc_noc_axi0_arprot),
    .pmc_noc_axi0_arqos(pmc_noc_axi0_arqos),
    .pmc_noc_axi0_arregion(pmc_noc_axi0_arregion),
    .pmc_noc_axi0_arsize(pmc_noc_axi0_arsize),
    .pmc_noc_axi0_aruser(pmc_noc_axi0_aruser),
    .pmc_noc_axi0_arvalid(pmc_noc_axi0_arvalid),
    .pmc_noc_axi0_awaddr(pmc_noc_axi0_awaddr),
    .pmc_noc_axi0_awburst(pmc_noc_axi0_awburst),
    .pmc_noc_axi0_awcache(pmc_noc_axi0_awcache),
    .pmc_noc_axi0_awid(pmc_noc_axi0_awid),
    .pmc_noc_axi0_awlen(pmc_noc_axi0_awlen),
    .pmc_noc_axi0_awlock(pmc_noc_axi0_awlock),
    .pmc_noc_axi0_awprot(pmc_noc_axi0_awprot),
    .pmc_noc_axi0_awqos(pmc_noc_axi0_awqos),
    .pmc_noc_axi0_awregion(pmc_noc_axi0_awregion),
    .pmc_noc_axi0_awsize(pmc_noc_axi0_awsize),
    .pmc_noc_axi0_awuser(pmc_noc_axi0_awuser),
    .pmc_noc_axi0_awvalid(pmc_noc_axi0_awvalid),
    .pmc_noc_axi0_bready(pmc_noc_axi0_bready),
    .pmc_noc_axi0_rready(pmc_noc_axi0_rready),
    .pmc_noc_axi0_wdata(pmc_noc_axi0_wdata),
    .pmc_noc_axi0_wid(pmc_noc_axi0_wid),
    .pmc_noc_axi0_wlast(pmc_noc_axi0_wlast),
    .pmc_noc_axi0_wstrb(pmc_noc_axi0_wstrb),
    .pmc_noc_axi0_wuser(pmc_noc_axi0_wuser),
    .pmc_noc_axi0_wvalid(pmc_noc_axi0_wvalid),
    .pmc_noc_axi0_arready(pmc_noc_axi0_arready),
    .pmc_noc_axi0_awready(pmc_noc_axi0_awready),
    .pmc_noc_axi0_bid(pmc_noc_axi0_bid),
    .pmc_noc_axi0_bresp(pmc_noc_axi0_bresp),
    .pmc_noc_axi0_buser(pmc_noc_axi0_buser),
    .pmc_noc_axi0_bvalid(pmc_noc_axi0_bvalid),
    .pmc_noc_axi0_rdata(pmc_noc_axi0_rdata),
    .pmc_noc_axi0_rid(pmc_noc_axi0_rid),
    .pmc_noc_axi0_rlast(pmc_noc_axi0_rlast),
    .pmc_noc_axi0_rresp(pmc_noc_axi0_rresp),
    .pmc_noc_axi0_ruser(pmc_noc_axi0_ruser),
    .pmc_noc_axi0_rvalid(pmc_noc_axi0_rvalid),
    .pmc_noc_axi0_wready(pmc_noc_axi0_wready),
    .gem0_tsu_timer_cnt(gem0_tsu_timer_cnt),
    .pl_ps_irq0(pl_ps_irq0),
    .pl_ps_irq1(pl_ps_irq1),
    .s_axi_xram3_aclk(s_axi_xram3_aclk),
    .lpd_lsbus_clk(lpd_lsbus_clk),
    .ps_ocm2_apb_prdata(ps_ocm2_apb_prdata),
    .ps_ocm2_apb_pready(ps_ocm2_apb_pready),
    .ps_ocm2_apb_pslverr(ps_ocm2_apb_pslverr),
    .ps_ocm2_apb_paddr(ps_ocm2_apb_paddr),
    .ps_ocm2_apb_penable(ps_ocm2_apb_penable),
    .ps_ocm2_apb_pprot(ps_ocm2_apb_pprot),
    .ps_ocm2_apb_psel(ps_ocm2_apb_psel),
    .ps_ocm2_apb_pstrb(ps_ocm2_apb_pstrb),
    .ps_ocm2_apb_pwdata(ps_ocm2_apb_pwdata),
    .ps_ocm2_apb_pwrite(ps_ocm2_apb_pwrite),
    .ps_ocm2_axi_arready(ps_ocm2_axi_arready),
    .ps_ocm2_axi_awready(ps_ocm2_axi_awready),
    .ps_ocm2_axi_bid(ps_ocm2_axi_bid),
    .ps_ocm2_axi_bresp(ps_ocm2_axi_bresp),
    .ps_ocm2_axi_buser(ps_ocm2_axi_buser),
    .ps_ocm2_axi_bvalid(ps_ocm2_axi_bvalid),
    .ps_ocm2_axi_rdata(ps_ocm2_axi_rdata),
    .ps_ocm2_axi_rid(ps_ocm2_axi_rid),
    .ps_ocm2_axi_rlast(ps_ocm2_axi_rlast),
    .ps_ocm2_axi_rresp(ps_ocm2_axi_rresp),
    .ps_ocm2_axi_ruser(ps_ocm2_axi_ruser),
    .ps_ocm2_axi_rvalid(ps_ocm2_axi_rvalid),
    .ps_ocm2_axi_wready(ps_ocm2_axi_wready),
    .ps_ocm2_axi_araddr(ps_ocm2_axi_araddr),
    .ps_ocm2_axi_arburst(ps_ocm2_axi_arburst),
    .ps_ocm2_axi_arcache(ps_ocm2_axi_arcache),
    .ps_ocm2_axi_arid(ps_ocm2_axi_arid),
    .ps_ocm2_axi_arlen(ps_ocm2_axi_arlen),
    .ps_ocm2_axi_arlock(ps_ocm2_axi_arlock),
    .ps_ocm2_axi_arprot(ps_ocm2_axi_arprot),
    .ps_ocm2_axi_arqos(ps_ocm2_axi_arqos),
    .ps_ocm2_axi_arregion(ps_ocm2_axi_arregion),
    .ps_ocm2_axi_arsize(ps_ocm2_axi_arsize),
    .ps_ocm2_axi_aruser(ps_ocm2_axi_aruser),
    .ps_ocm2_axi_arvalid(ps_ocm2_axi_arvalid),
    .ps_ocm2_axi_awaddr(ps_ocm2_axi_awaddr),
    .ps_ocm2_axi_awburst(ps_ocm2_axi_awburst),
    .ps_ocm2_axi_awcache(ps_ocm2_axi_awcache),
    .ps_ocm2_axi_awid(ps_ocm2_axi_awid),
    .ps_ocm2_axi_awlen(ps_ocm2_axi_awlen),
    .ps_ocm2_axi_awlock(ps_ocm2_axi_awlock),
    .ps_ocm2_axi_awprot(ps_ocm2_axi_awprot),
    .ps_ocm2_axi_awqos(ps_ocm2_axi_awqos),
    .ps_ocm2_axi_awregion(ps_ocm2_axi_awregion),
    .ps_ocm2_axi_awsize(ps_ocm2_axi_awsize),
    .ps_ocm2_axi_awuser(ps_ocm2_axi_awuser),
    .ps_ocm2_axi_awvalid(ps_ocm2_axi_awvalid),
    .ps_ocm2_axi_bready(ps_ocm2_axi_bready),
    .ps_ocm2_axi_rready(ps_ocm2_axi_rready),
    .ps_ocm2_axi_wdata(ps_ocm2_axi_wdata),
    .ps_ocm2_axi_wid(ps_ocm2_axi_wid),
    .ps_ocm2_axi_wlast(ps_ocm2_axi_wlast),
    .ps_ocm2_axi_wstrb(ps_ocm2_axi_wstrb),
    .ps_ocm2_axi_wuser(ps_ocm2_axi_wuser),
    .ps_ocm2_axi_wvalid(ps_ocm2_axi_wvalid)
  );
endmodule
