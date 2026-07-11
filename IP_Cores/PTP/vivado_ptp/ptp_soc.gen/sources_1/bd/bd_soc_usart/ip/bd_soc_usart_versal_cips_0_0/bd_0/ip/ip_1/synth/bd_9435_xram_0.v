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


// IP VLNV: xilinx.com:ip:xram:1.0
// IP Revision: 1

(* X_CORE_INFO = "xram_v1_0_1,Vivado 2025.2.1" *)
(* CHECK_LICENSE_TYPE = "bd_9435_xram_0,xram_v1_0_1,{}" *)
(* CORE_GENERATION_INFO = "bd_9435_xram_0,xram_v1_0_1,{x_ipProduct=Vivado 2025.2.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=xram,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_S_AXI_XRAM0_DATA_WIDTH=256,C_S_AXI_XRAM1_DATA_WIDTH=256,C_S_AXI_XRAM2_DATA_WIDTH=256,C_S_AXI_LITE_XRAM_DATA_WIDTH=32,C_SIM_DEVICE=VERSAL_CORE,C_CORE_NAME=xram_0,C_PL_INTERFACE_0_INTERFACE_USAGE=0,C_PL_INTERFACE_1_INTERFACE_USAGE=0,C_PL_INTERFACE_2_INTERFACE_USAGE=0,C_MEM_FREQ=400,C_PL_INTERFACE_0_FREQUENCY=0,C_P\
L_INTERFACE_1_FREQUENCY=0,C_PL_INTERFACE_2_FREQUENCY=0}" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module bd_9435_xram_0 (
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

(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_xram3_aclk CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_xram3_aclk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_s_axi_xram3_aclk, ASSOCIATED_BUSIF S_AXI_XRAM3, INSERT_VIP 0" *)
input wire s_axi_xram3_aclk;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 lpd_lsbus_clk LPD_LSBUS_CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME lpd_lsbus_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_lpd_lsbus_clk, INSERT_VIP 0" *)
input wire lpd_lsbus_clk;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PRDATA" *)
(* X_INTERFACE_MODE = "slave" *)
output wire [31 : 0] ps_ocm2_apb_prdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PREADY" *)
output wire ps_ocm2_apb_pready;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PSLVERR" *)
output wire ps_ocm2_apb_pslverr;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PADDR" *)
input wire [31 : 0] ps_ocm2_apb_paddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PENABLE" *)
input wire ps_ocm2_apb_penable;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PPROT" *)
input wire [2 : 0] ps_ocm2_apb_pprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PSEL" *)
input wire ps_ocm2_apb_psel;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PSTRB" *)
input wire [3 : 0] ps_ocm2_apb_pstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PWDATA" *)
input wire [31 : 0] ps_ocm2_apb_pwdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 S_APB_XRAM PWRITE" *)
input wire [0 : 0] ps_ocm2_apb_pwrite;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARREADY" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_XRAM3, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 18, RUSER_WIDTH 18, BUSER_WIDTH 1, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_9435_pspmc_0_0_s_axi_xram3_aclk, NUM_READ_THREA\
DS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
output wire ps_ocm2_axi_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWREADY" *)
output wire ps_ocm2_axi_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BID" *)
output wire [15 : 0] ps_ocm2_axi_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BRESP" *)
output wire [1 : 0] ps_ocm2_axi_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BUSER" *)
output wire ps_ocm2_axi_buser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BVALID" *)
output wire ps_ocm2_axi_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RDATA" *)
output wire [127 : 0] ps_ocm2_axi_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RID" *)
output wire [15 : 0] ps_ocm2_axi_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RLAST" *)
output wire ps_ocm2_axi_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RRESP" *)
output wire [1 : 0] ps_ocm2_axi_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RUSER" *)
output wire [17 : 0] ps_ocm2_axi_ruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RVALID" *)
output wire ps_ocm2_axi_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WREADY" *)
output wire ps_ocm2_axi_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARADDR" *)
input wire [63 : 0] ps_ocm2_axi_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARBURST" *)
input wire [1 : 0] ps_ocm2_axi_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARCACHE" *)
input wire [3 : 0] ps_ocm2_axi_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARID" *)
input wire [15 : 0] ps_ocm2_axi_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARLEN" *)
input wire [7 : 0] ps_ocm2_axi_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARLOCK" *)
input wire ps_ocm2_axi_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARPROT" *)
input wire [2 : 0] ps_ocm2_axi_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARQOS" *)
input wire [3 : 0] ps_ocm2_axi_arqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARREGION" *)
input wire [3 : 0] ps_ocm2_axi_arregion;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARSIZE" *)
input wire [2 : 0] ps_ocm2_axi_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARUSER" *)
input wire [15 : 0] ps_ocm2_axi_aruser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARVALID" *)
input wire ps_ocm2_axi_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWADDR" *)
input wire [63 : 0] ps_ocm2_axi_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWBURST" *)
input wire [1 : 0] ps_ocm2_axi_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWCACHE" *)
input wire [3 : 0] ps_ocm2_axi_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWID" *)
input wire [15 : 0] ps_ocm2_axi_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWLEN" *)
input wire [7 : 0] ps_ocm2_axi_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWLOCK" *)
input wire ps_ocm2_axi_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWPROT" *)
input wire [2 : 0] ps_ocm2_axi_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWQOS" *)
input wire [3 : 0] ps_ocm2_axi_awqos;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWREGION" *)
input wire [3 : 0] ps_ocm2_axi_awregion;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWSIZE" *)
input wire [2 : 0] ps_ocm2_axi_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWUSER" *)
input wire [15 : 0] ps_ocm2_axi_awuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWVALID" *)
input wire ps_ocm2_axi_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BREADY" *)
input wire ps_ocm2_axi_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RREADY" *)
input wire ps_ocm2_axi_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WDATA" *)
input wire [127 : 0] ps_ocm2_axi_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WID" *)
input wire [15 : 0] ps_ocm2_axi_wid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WLAST" *)
input wire ps_ocm2_axi_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WSTRB" *)
input wire [15 : 0] ps_ocm2_axi_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WUSER" *)
input wire [17 : 0] ps_ocm2_axi_wuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WVALID" *)
input wire ps_ocm2_axi_wvalid;

  xram_v1_0_1 #(
    .C_S_AXI_XRAM0_DATA_WIDTH(256),
    .C_S_AXI_XRAM1_DATA_WIDTH(256),
    .C_S_AXI_XRAM2_DATA_WIDTH(256),
    .C_S_AXI_LITE_XRAM_DATA_WIDTH(32),
    .C_SIM_DEVICE("VERSAL_CORE"),
    .C_CORE_NAME("xram_0"),
    .C_PL_INTERFACE_0_INTERFACE_USAGE(0),
    .C_PL_INTERFACE_1_INTERFACE_USAGE(0),
    .C_PL_INTERFACE_2_INTERFACE_USAGE(0),
    .C_MEM_FREQ(400),
    .C_PL_INTERFACE_0_FREQUENCY(0),
    .C_PL_INTERFACE_1_FREQUENCY(0),
    .C_PL_INTERFACE_2_FREQUENCY(0)
  ) inst (
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
