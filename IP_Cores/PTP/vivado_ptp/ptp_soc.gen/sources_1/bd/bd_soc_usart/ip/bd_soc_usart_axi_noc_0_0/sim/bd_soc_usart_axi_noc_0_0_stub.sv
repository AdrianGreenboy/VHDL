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


//------------------------------------------------------------------------------------
// Filename:    bd_soc_usart_axi_noc_0_0_stub.sv
// Description: This HDL file is intended to be used with following simulators only:
//
//   Vivado Simulator (XSim)
//   Cadence Xcelium Simulator
//
//------------------------------------------------------------------------------------
`timescale 1ps/1ps

`ifdef XILINX_SIMULATOR

`ifndef XILINX_SIMULATOR_BITASBOOL
`define XILINX_SIMULATOR_BITASBOOL
typedef bit bit_as_bool;
`endif

(* SC_MODULE_EXPORT *)
module bd_soc_usart_axi_noc_0_0 (
  input bit [63 : 0] S00_AXI_awaddr,
  input bit [7 : 0] S00_AXI_awlen,
  input bit [2 : 0] S00_AXI_awsize,
  input bit [1 : 0] S00_AXI_awburst,
  input bit [0 : 0] S00_AXI_awlock,
  input bit [3 : 0] S00_AXI_awcache,
  input bit [2 : 0] S00_AXI_awprot,
  input bit [3 : 0] S00_AXI_awregion,
  input bit [3 : 0] S00_AXI_awqos,
  input bit [0 : 0] S00_AXI_awvalid,
  output bit [0 : 0] S00_AXI_awready,
  input bit [127 : 0] S00_AXI_wdata,
  input bit [15 : 0] S00_AXI_wstrb,
  input bit [0 : 0] S00_AXI_wlast,
  input bit [0 : 0] S00_AXI_wvalid,
  output bit [0 : 0] S00_AXI_wready,
  output bit [1 : 0] S00_AXI_bresp,
  output bit [0 : 0] S00_AXI_bvalid,
  input bit [0 : 0] S00_AXI_bready,
  input bit [63 : 0] S00_AXI_araddr,
  input bit [7 : 0] S00_AXI_arlen,
  input bit [2 : 0] S00_AXI_arsize,
  input bit [1 : 0] S00_AXI_arburst,
  input bit [0 : 0] S00_AXI_arlock,
  input bit [3 : 0] S00_AXI_arcache,
  input bit [2 : 0] S00_AXI_arprot,
  input bit [3 : 0] S00_AXI_arregion,
  input bit [3 : 0] S00_AXI_arqos,
  input bit [0 : 0] S00_AXI_arvalid,
  output bit [0 : 0] S00_AXI_arready,
  output bit [127 : 0] S00_AXI_rdata,
  output bit [1 : 0] S00_AXI_rresp,
  output bit [0 : 0] S00_AXI_rlast,
  output bit [0 : 0] S00_AXI_rvalid,
  input bit [0 : 0] S00_AXI_rready,
  input bit [63 : 0] S01_AXI_awaddr,
  input bit [7 : 0] S01_AXI_awlen,
  input bit [2 : 0] S01_AXI_awsize,
  input bit [1 : 0] S01_AXI_awburst,
  input bit [0 : 0] S01_AXI_awlock,
  input bit [3 : 0] S01_AXI_awcache,
  input bit [2 : 0] S01_AXI_awprot,
  input bit [3 : 0] S01_AXI_awregion,
  input bit [3 : 0] S01_AXI_awqos,
  input bit [0 : 0] S01_AXI_awvalid,
  output bit [0 : 0] S01_AXI_awready,
  input bit [127 : 0] S01_AXI_wdata,
  input bit [15 : 0] S01_AXI_wstrb,
  input bit [0 : 0] S01_AXI_wlast,
  input bit [0 : 0] S01_AXI_wvalid,
  output bit [0 : 0] S01_AXI_wready,
  output bit [1 : 0] S01_AXI_bresp,
  output bit [0 : 0] S01_AXI_bvalid,
  input bit [0 : 0] S01_AXI_bready,
  input bit [63 : 0] S01_AXI_araddr,
  input bit [7 : 0] S01_AXI_arlen,
  input bit [2 : 0] S01_AXI_arsize,
  input bit [1 : 0] S01_AXI_arburst,
  input bit [0 : 0] S01_AXI_arlock,
  input bit [3 : 0] S01_AXI_arcache,
  input bit [2 : 0] S01_AXI_arprot,
  input bit [3 : 0] S01_AXI_arregion,
  input bit [3 : 0] S01_AXI_arqos,
  input bit [0 : 0] S01_AXI_arvalid,
  output bit [0 : 0] S01_AXI_arready,
  output bit [127 : 0] S01_AXI_rdata,
  output bit [1 : 0] S01_AXI_rresp,
  output bit [0 : 0] S01_AXI_rlast,
  output bit [0 : 0] S01_AXI_rvalid,
  input bit [0 : 0] S01_AXI_rready,
  input bit [63 : 0] S02_AXI_awaddr,
  input bit [7 : 0] S02_AXI_awlen,
  input bit [2 : 0] S02_AXI_awsize,
  input bit [1 : 0] S02_AXI_awburst,
  input bit [0 : 0] S02_AXI_awlock,
  input bit [3 : 0] S02_AXI_awcache,
  input bit [2 : 0] S02_AXI_awprot,
  input bit [3 : 0] S02_AXI_awregion,
  input bit [3 : 0] S02_AXI_awqos,
  input bit [0 : 0] S02_AXI_awvalid,
  output bit [0 : 0] S02_AXI_awready,
  input bit [127 : 0] S02_AXI_wdata,
  input bit [15 : 0] S02_AXI_wstrb,
  input bit [0 : 0] S02_AXI_wlast,
  input bit [0 : 0] S02_AXI_wvalid,
  output bit [0 : 0] S02_AXI_wready,
  output bit [1 : 0] S02_AXI_bresp,
  output bit [0 : 0] S02_AXI_bvalid,
  input bit [0 : 0] S02_AXI_bready,
  input bit [63 : 0] S02_AXI_araddr,
  input bit [7 : 0] S02_AXI_arlen,
  input bit [2 : 0] S02_AXI_arsize,
  input bit [1 : 0] S02_AXI_arburst,
  input bit [0 : 0] S02_AXI_arlock,
  input bit [3 : 0] S02_AXI_arcache,
  input bit [2 : 0] S02_AXI_arprot,
  input bit [3 : 0] S02_AXI_arregion,
  input bit [3 : 0] S02_AXI_arqos,
  input bit [0 : 0] S02_AXI_arvalid,
  output bit [0 : 0] S02_AXI_arready,
  output bit [127 : 0] S02_AXI_rdata,
  output bit [1 : 0] S02_AXI_rresp,
  output bit [0 : 0] S02_AXI_rlast,
  output bit [0 : 0] S02_AXI_rvalid,
  input bit [0 : 0] S02_AXI_rready,
  input bit [63 : 0] S03_AXI_awaddr,
  input bit [7 : 0] S03_AXI_awlen,
  input bit [2 : 0] S03_AXI_awsize,
  input bit [1 : 0] S03_AXI_awburst,
  input bit [0 : 0] S03_AXI_awlock,
  input bit [3 : 0] S03_AXI_awcache,
  input bit [2 : 0] S03_AXI_awprot,
  input bit [3 : 0] S03_AXI_awregion,
  input bit [3 : 0] S03_AXI_awqos,
  input bit [0 : 0] S03_AXI_awvalid,
  output bit [0 : 0] S03_AXI_awready,
  input bit [127 : 0] S03_AXI_wdata,
  input bit [15 : 0] S03_AXI_wstrb,
  input bit [0 : 0] S03_AXI_wlast,
  input bit [0 : 0] S03_AXI_wvalid,
  output bit [0 : 0] S03_AXI_wready,
  output bit [1 : 0] S03_AXI_bresp,
  output bit [0 : 0] S03_AXI_bvalid,
  input bit [0 : 0] S03_AXI_bready,
  input bit [63 : 0] S03_AXI_araddr,
  input bit [7 : 0] S03_AXI_arlen,
  input bit [2 : 0] S03_AXI_arsize,
  input bit [1 : 0] S03_AXI_arburst,
  input bit [0 : 0] S03_AXI_arlock,
  input bit [3 : 0] S03_AXI_arcache,
  input bit [2 : 0] S03_AXI_arprot,
  input bit [3 : 0] S03_AXI_arregion,
  input bit [3 : 0] S03_AXI_arqos,
  input bit [0 : 0] S03_AXI_arvalid,
  output bit [0 : 0] S03_AXI_arready,
  output bit [127 : 0] S03_AXI_rdata,
  output bit [1 : 0] S03_AXI_rresp,
  output bit [0 : 0] S03_AXI_rlast,
  output bit [0 : 0] S03_AXI_rvalid,
  input bit [0 : 0] S03_AXI_rready,
  input bit [63 : 0] S04_AXI_awaddr,
  input bit [7 : 0] S04_AXI_awlen,
  input bit [2 : 0] S04_AXI_awsize,
  input bit [1 : 0] S04_AXI_awburst,
  input bit [0 : 0] S04_AXI_awlock,
  input bit [3 : 0] S04_AXI_awcache,
  input bit [2 : 0] S04_AXI_awprot,
  input bit [3 : 0] S04_AXI_awregion,
  input bit [3 : 0] S04_AXI_awqos,
  input bit [0 : 0] S04_AXI_awvalid,
  output bit [0 : 0] S04_AXI_awready,
  input bit [127 : 0] S04_AXI_wdata,
  input bit [15 : 0] S04_AXI_wstrb,
  input bit [0 : 0] S04_AXI_wlast,
  input bit [0 : 0] S04_AXI_wvalid,
  output bit [0 : 0] S04_AXI_wready,
  output bit [1 : 0] S04_AXI_bresp,
  output bit [0 : 0] S04_AXI_bvalid,
  input bit [0 : 0] S04_AXI_bready,
  input bit [63 : 0] S04_AXI_araddr,
  input bit [7 : 0] S04_AXI_arlen,
  input bit [2 : 0] S04_AXI_arsize,
  input bit [1 : 0] S04_AXI_arburst,
  input bit [0 : 0] S04_AXI_arlock,
  input bit [3 : 0] S04_AXI_arcache,
  input bit [2 : 0] S04_AXI_arprot,
  input bit [3 : 0] S04_AXI_arregion,
  input bit [3 : 0] S04_AXI_arqos,
  input bit [0 : 0] S04_AXI_arvalid,
  output bit [0 : 0] S04_AXI_arready,
  output bit [127 : 0] S04_AXI_rdata,
  output bit [1 : 0] S04_AXI_rresp,
  output bit [0 : 0] S04_AXI_rlast,
  output bit [0 : 0] S04_AXI_rvalid,
  input bit [0 : 0] S04_AXI_rready,
  input bit [63 : 0] S05_AXI_awaddr,
  input bit [7 : 0] S05_AXI_awlen,
  input bit [2 : 0] S05_AXI_awsize,
  input bit [1 : 0] S05_AXI_awburst,
  input bit [0 : 0] S05_AXI_awlock,
  input bit [3 : 0] S05_AXI_awcache,
  input bit [2 : 0] S05_AXI_awprot,
  input bit [3 : 0] S05_AXI_awregion,
  input bit [3 : 0] S05_AXI_awqos,
  input bit [0 : 0] S05_AXI_awvalid,
  output bit [0 : 0] S05_AXI_awready,
  input bit [127 : 0] S05_AXI_wdata,
  input bit [15 : 0] S05_AXI_wstrb,
  input bit [0 : 0] S05_AXI_wlast,
  input bit [0 : 0] S05_AXI_wvalid,
  output bit [0 : 0] S05_AXI_wready,
  output bit [1 : 0] S05_AXI_bresp,
  output bit [0 : 0] S05_AXI_bvalid,
  input bit [0 : 0] S05_AXI_bready,
  input bit [63 : 0] S05_AXI_araddr,
  input bit [7 : 0] S05_AXI_arlen,
  input bit [2 : 0] S05_AXI_arsize,
  input bit [1 : 0] S05_AXI_arburst,
  input bit [0 : 0] S05_AXI_arlock,
  input bit [3 : 0] S05_AXI_arcache,
  input bit [2 : 0] S05_AXI_arprot,
  input bit [3 : 0] S05_AXI_arregion,
  input bit [3 : 0] S05_AXI_arqos,
  input bit [0 : 0] S05_AXI_arvalid,
  output bit [0 : 0] S05_AXI_arready,
  output bit [127 : 0] S05_AXI_rdata,
  output bit [1 : 0] S05_AXI_rresp,
  output bit [0 : 0] S05_AXI_rlast,
  output bit [0 : 0] S05_AXI_rvalid,
  input bit [0 : 0] S05_AXI_rready,
  input bit [63 : 0] S06_AXI_awaddr,
  input bit [7 : 0] S06_AXI_awlen,
  input bit [2 : 0] S06_AXI_awsize,
  input bit [1 : 0] S06_AXI_awburst,
  input bit [0 : 0] S06_AXI_awlock,
  input bit [3 : 0] S06_AXI_awcache,
  input bit [2 : 0] S06_AXI_awprot,
  input bit [3 : 0] S06_AXI_awregion,
  input bit [3 : 0] S06_AXI_awqos,
  input bit [0 : 0] S06_AXI_awvalid,
  output bit [0 : 0] S06_AXI_awready,
  input bit [31 : 0] S06_AXI_wdata,
  input bit [3 : 0] S06_AXI_wstrb,
  input bit [0 : 0] S06_AXI_wlast,
  input bit [0 : 0] S06_AXI_wvalid,
  output bit [0 : 0] S06_AXI_wready,
  output bit [1 : 0] S06_AXI_bresp,
  output bit [0 : 0] S06_AXI_bvalid,
  input bit [0 : 0] S06_AXI_bready,
  input bit [63 : 0] S06_AXI_araddr,
  input bit [7 : 0] S06_AXI_arlen,
  input bit [2 : 0] S06_AXI_arsize,
  input bit [1 : 0] S06_AXI_arburst,
  input bit [0 : 0] S06_AXI_arlock,
  input bit [3 : 0] S06_AXI_arcache,
  input bit [2 : 0] S06_AXI_arprot,
  input bit [3 : 0] S06_AXI_arregion,
  input bit [3 : 0] S06_AXI_arqos,
  input bit [0 : 0] S06_AXI_arvalid,
  output bit [0 : 0] S06_AXI_arready,
  output bit [31 : 0] S06_AXI_rdata,
  output bit [1 : 0] S06_AXI_rresp,
  output bit [0 : 0] S06_AXI_rlast,
  output bit [0 : 0] S06_AXI_rvalid,
  input bit [0 : 0] S06_AXI_rready,
  input bit_as_bool aclk0,
  input bit_as_bool aclk1,
  input bit_as_bool aclk2,
  input bit_as_bool aclk3,
  input bit_as_bool aclk4,
  input bit_as_bool aclk5,
  input bit_as_bool aclk6,
  input bit [0 : 0] sys_clk0_clk_p,
  input bit [0 : 0] sys_clk0_clk_n,
  output bit [63 : 0] CH0_DDR4_0_dq,
  output bit [7 : 0] CH0_DDR4_0_dqs_t,
  output bit [7 : 0] CH0_DDR4_0_dqs_c,
  output bit [16 : 0] CH0_DDR4_0_adr,
  output bit [1 : 0] CH0_DDR4_0_ba,
  output bit [0 : 0] CH0_DDR4_0_bg,
  output bit [0 : 0] CH0_DDR4_0_act_n,
  output bit [0 : 0] CH0_DDR4_0_reset_n,
  output bit [0 : 0] CH0_DDR4_0_ck_t,
  output bit [0 : 0] CH0_DDR4_0_ck_c,
  output bit [0 : 0] CH0_DDR4_0_cke,
  output bit [0 : 0] CH0_DDR4_0_cs_n,
  output bit [7 : 0] CH0_DDR4_0_dm_n,
  output bit [0 : 0] CH0_DDR4_0_odt,
  input bit [15 : 0] S05_AXI_arid,
  input bit [17 : 0] S05_AXI_aruser,
  input bit [15 : 0] S05_AXI_awid,
  input bit [17 : 0] S05_AXI_awuser,
  output bit [15 : 0] S05_AXI_bid,
  output bit [15 : 0] S05_AXI_buser,
  output bit [15 : 0] S05_AXI_rid,
  output bit [16 : 0] S05_AXI_ruser,
  input bit [16 : 0] S05_AXI_wuser,
  input bit [15 : 0] S03_AXI_arid,
  input bit [17 : 0] S03_AXI_aruser,
  input bit [15 : 0] S03_AXI_awid,
  input bit [17 : 0] S03_AXI_awuser,
  output bit [15 : 0] S03_AXI_bid,
  output bit [15 : 0] S03_AXI_rid,
  output bit [16 : 0] S03_AXI_ruser,
  input bit [16 : 0] S03_AXI_wuser,
  input bit [15 : 0] S04_AXI_arid,
  input bit [17 : 0] S04_AXI_aruser,
  input bit [15 : 0] S04_AXI_awid,
  input bit [17 : 0] S04_AXI_awuser,
  output bit [15 : 0] S04_AXI_bid,
  output bit [15 : 0] S04_AXI_rid,
  output bit [16 : 0] S04_AXI_ruser,
  input bit [16 : 0] S04_AXI_wuser,
  input bit [15 : 0] S02_AXI_arid,
  input bit [17 : 0] S02_AXI_aruser,
  input bit [15 : 0] S02_AXI_awid,
  input bit [17 : 0] S02_AXI_awuser,
  output bit [15 : 0] S02_AXI_bid,
  output bit [15 : 0] S02_AXI_rid,
  output bit [16 : 0] S02_AXI_ruser,
  input bit [16 : 0] S02_AXI_wuser,
  input bit [0 : 0] S06_AXI_arid,
  input bit [0 : 0] S06_AXI_awid,
  output bit [0 : 0] S06_AXI_bid,
  output bit [0 : 0] S06_AXI_rid,
  input bit [15 : 0] S01_AXI_arid,
  input bit [17 : 0] S01_AXI_aruser,
  input bit [15 : 0] S01_AXI_awid,
  input bit [17 : 0] S01_AXI_awuser,
  output bit [15 : 0] S01_AXI_bid,
  output bit [15 : 0] S01_AXI_rid,
  output bit [16 : 0] S01_AXI_ruser,
  input bit [16 : 0] S01_AXI_wuser,
  input bit [15 : 0] S00_AXI_arid,
  input bit [17 : 0] S00_AXI_aruser,
  input bit [15 : 0] S00_AXI_awid,
  input bit [17 : 0] S00_AXI_awuser,
  output bit [15 : 0] S00_AXI_bid,
  output bit [15 : 0] S00_AXI_rid,
  output bit [16 : 0] S00_AXI_ruser,
  input bit [16 : 0] S00_AXI_wuser
);
endmodule
`endif

`ifdef XCELIUM
(* XMSC_MODULE_EXPORT *)
module bd_soc_usart_axi_noc_0_0 (S00_AXI_awaddr,S00_AXI_awlen,S00_AXI_awsize,S00_AXI_awburst,S00_AXI_awlock,S00_AXI_awcache,S00_AXI_awprot,S00_AXI_awregion,S00_AXI_awqos,S00_AXI_awvalid,S00_AXI_awready,S00_AXI_wdata,S00_AXI_wstrb,S00_AXI_wlast,S00_AXI_wvalid,S00_AXI_wready,S00_AXI_bresp,S00_AXI_bvalid,S00_AXI_bready,S00_AXI_araddr,S00_AXI_arlen,S00_AXI_arsize,S00_AXI_arburst,S00_AXI_arlock,S00_AXI_arcache,S00_AXI_arprot,S00_AXI_arregion,S00_AXI_arqos,S00_AXI_arvalid,S00_AXI_arready,S00_AXI_rdata,S00_AXI_rresp,S00_AXI_rlast,S00_AXI_rvalid,S00_AXI_rready,S01_AXI_awaddr,S01_AXI_awlen,S01_AXI_awsize,S01_AXI_awburst,S01_AXI_awlock,S01_AXI_awcache,S01_AXI_awprot,S01_AXI_awregion,S01_AXI_awqos,S01_AXI_awvalid,S01_AXI_awready,S01_AXI_wdata,S01_AXI_wstrb,S01_AXI_wlast,S01_AXI_wvalid,S01_AXI_wready,S01_AXI_bresp,S01_AXI_bvalid,S01_AXI_bready,S01_AXI_araddr,S01_AXI_arlen,S01_AXI_arsize,S01_AXI_arburst,S01_AXI_arlock,S01_AXI_arcache,S01_AXI_arprot,S01_AXI_arregion,S01_AXI_arqos,S01_AXI_arvalid,S01_AXI_arready,S01_AXI_rdata,S01_AXI_rresp,S01_AXI_rlast,S01_AXI_rvalid,S01_AXI_rready,S02_AXI_awaddr,S02_AXI_awlen,S02_AXI_awsize,S02_AXI_awburst,S02_AXI_awlock,S02_AXI_awcache,S02_AXI_awprot,S02_AXI_awregion,S02_AXI_awqos,S02_AXI_awvalid,S02_AXI_awready,S02_AXI_wdata,S02_AXI_wstrb,S02_AXI_wlast,S02_AXI_wvalid,S02_AXI_wready,S02_AXI_bresp,S02_AXI_bvalid,S02_AXI_bready,S02_AXI_araddr,S02_AXI_arlen,S02_AXI_arsize,S02_AXI_arburst,S02_AXI_arlock,S02_AXI_arcache,S02_AXI_arprot,S02_AXI_arregion,S02_AXI_arqos,S02_AXI_arvalid,S02_AXI_arready,S02_AXI_rdata,S02_AXI_rresp,S02_AXI_rlast,S02_AXI_rvalid,S02_AXI_rready,S03_AXI_awaddr,S03_AXI_awlen,S03_AXI_awsize,S03_AXI_awburst,S03_AXI_awlock,S03_AXI_awcache,S03_AXI_awprot,S03_AXI_awregion,S03_AXI_awqos,S03_AXI_awvalid,S03_AXI_awready,S03_AXI_wdata,S03_AXI_wstrb,S03_AXI_wlast,S03_AXI_wvalid,S03_AXI_wready,S03_AXI_bresp,S03_AXI_bvalid,S03_AXI_bready,S03_AXI_araddr,S03_AXI_arlen,S03_AXI_arsize,S03_AXI_arburst,S03_AXI_arlock,S03_AXI_arcache,S03_AXI_arprot,S03_AXI_arregion,S03_AXI_arqos,S03_AXI_arvalid,S03_AXI_arready,S03_AXI_rdata,S03_AXI_rresp,S03_AXI_rlast,S03_AXI_rvalid,S03_AXI_rready,S04_AXI_awaddr,S04_AXI_awlen,S04_AXI_awsize,S04_AXI_awburst,S04_AXI_awlock,S04_AXI_awcache,S04_AXI_awprot,S04_AXI_awregion,S04_AXI_awqos,S04_AXI_awvalid,S04_AXI_awready,S04_AXI_wdata,S04_AXI_wstrb,S04_AXI_wlast,S04_AXI_wvalid,S04_AXI_wready,S04_AXI_bresp,S04_AXI_bvalid,S04_AXI_bready,S04_AXI_araddr,S04_AXI_arlen,S04_AXI_arsize,S04_AXI_arburst,S04_AXI_arlock,S04_AXI_arcache,S04_AXI_arprot,S04_AXI_arregion,S04_AXI_arqos,S04_AXI_arvalid,S04_AXI_arready,S04_AXI_rdata,S04_AXI_rresp,S04_AXI_rlast,S04_AXI_rvalid,S04_AXI_rready,S05_AXI_awaddr,S05_AXI_awlen,S05_AXI_awsize,S05_AXI_awburst,S05_AXI_awlock,S05_AXI_awcache,S05_AXI_awprot,S05_AXI_awregion,S05_AXI_awqos,S05_AXI_awvalid,S05_AXI_awready,S05_AXI_wdata,S05_AXI_wstrb,S05_AXI_wlast,S05_AXI_wvalid,S05_AXI_wready,S05_AXI_bresp,S05_AXI_bvalid,S05_AXI_bready,S05_AXI_araddr,S05_AXI_arlen,S05_AXI_arsize,S05_AXI_arburst,S05_AXI_arlock,S05_AXI_arcache,S05_AXI_arprot,S05_AXI_arregion,S05_AXI_arqos,S05_AXI_arvalid,S05_AXI_arready,S05_AXI_rdata,S05_AXI_rresp,S05_AXI_rlast,S05_AXI_rvalid,S05_AXI_rready,S06_AXI_awaddr,S06_AXI_awlen,S06_AXI_awsize,S06_AXI_awburst,S06_AXI_awlock,S06_AXI_awcache,S06_AXI_awprot,S06_AXI_awregion,S06_AXI_awqos,S06_AXI_awvalid,S06_AXI_awready,S06_AXI_wdata,S06_AXI_wstrb,S06_AXI_wlast,S06_AXI_wvalid,S06_AXI_wready,S06_AXI_bresp,S06_AXI_bvalid,S06_AXI_bready,S06_AXI_araddr,S06_AXI_arlen,S06_AXI_arsize,S06_AXI_arburst,S06_AXI_arlock,S06_AXI_arcache,S06_AXI_arprot,S06_AXI_arregion,S06_AXI_arqos,S06_AXI_arvalid,S06_AXI_arready,S06_AXI_rdata,S06_AXI_rresp,S06_AXI_rlast,S06_AXI_rvalid,S06_AXI_rready,aclk0,aclk1,aclk2,aclk3,aclk4,aclk5,aclk6,sys_clk0_clk_p,sys_clk0_clk_n,CH0_DDR4_0_dq,CH0_DDR4_0_dqs_t,CH0_DDR4_0_dqs_c,CH0_DDR4_0_adr,CH0_DDR4_0_ba,CH0_DDR4_0_bg,CH0_DDR4_0_act_n,CH0_DDR4_0_reset_n,CH0_DDR4_0_ck_t,CH0_DDR4_0_ck_c,CH0_DDR4_0_cke,CH0_DDR4_0_cs_n,CH0_DDR4_0_dm_n,CH0_DDR4_0_odt,S05_AXI_arid,S05_AXI_aruser,S05_AXI_awid,S05_AXI_awuser,S05_AXI_bid,S05_AXI_buser,S05_AXI_rid,S05_AXI_ruser,S05_AXI_wuser,S03_AXI_arid,S03_AXI_aruser,S03_AXI_awid,S03_AXI_awuser,S03_AXI_bid,S03_AXI_rid,S03_AXI_ruser,S03_AXI_wuser,S04_AXI_arid,S04_AXI_aruser,S04_AXI_awid,S04_AXI_awuser,S04_AXI_bid,S04_AXI_rid,S04_AXI_ruser,S04_AXI_wuser,S02_AXI_arid,S02_AXI_aruser,S02_AXI_awid,S02_AXI_awuser,S02_AXI_bid,S02_AXI_rid,S02_AXI_ruser,S02_AXI_wuser,S06_AXI_arid,S06_AXI_awid,S06_AXI_bid,S06_AXI_rid,S01_AXI_arid,S01_AXI_aruser,S01_AXI_awid,S01_AXI_awuser,S01_AXI_bid,S01_AXI_rid,S01_AXI_ruser,S01_AXI_wuser,S00_AXI_arid,S00_AXI_aruser,S00_AXI_awid,S00_AXI_awuser,S00_AXI_bid,S00_AXI_rid,S00_AXI_ruser,S00_AXI_wuser)
(* integer foreign = "SystemC";
*);
  input bit [63 : 0] S00_AXI_awaddr;
  input bit [7 : 0] S00_AXI_awlen;
  input bit [2 : 0] S00_AXI_awsize;
  input bit [1 : 0] S00_AXI_awburst;
  input bit [0 : 0] S00_AXI_awlock;
  input bit [3 : 0] S00_AXI_awcache;
  input bit [2 : 0] S00_AXI_awprot;
  input bit [3 : 0] S00_AXI_awregion;
  input bit [3 : 0] S00_AXI_awqos;
  input bit [0 : 0] S00_AXI_awvalid;
  output wire [0 : 0] S00_AXI_awready;
  input bit [127 : 0] S00_AXI_wdata;
  input bit [15 : 0] S00_AXI_wstrb;
  input bit [0 : 0] S00_AXI_wlast;
  input bit [0 : 0] S00_AXI_wvalid;
  output wire [0 : 0] S00_AXI_wready;
  output wire [1 : 0] S00_AXI_bresp;
  output wire [0 : 0] S00_AXI_bvalid;
  input bit [0 : 0] S00_AXI_bready;
  input bit [63 : 0] S00_AXI_araddr;
  input bit [7 : 0] S00_AXI_arlen;
  input bit [2 : 0] S00_AXI_arsize;
  input bit [1 : 0] S00_AXI_arburst;
  input bit [0 : 0] S00_AXI_arlock;
  input bit [3 : 0] S00_AXI_arcache;
  input bit [2 : 0] S00_AXI_arprot;
  input bit [3 : 0] S00_AXI_arregion;
  input bit [3 : 0] S00_AXI_arqos;
  input bit [0 : 0] S00_AXI_arvalid;
  output wire [0 : 0] S00_AXI_arready;
  output wire [127 : 0] S00_AXI_rdata;
  output wire [1 : 0] S00_AXI_rresp;
  output wire [0 : 0] S00_AXI_rlast;
  output wire [0 : 0] S00_AXI_rvalid;
  input bit [0 : 0] S00_AXI_rready;
  input bit [63 : 0] S01_AXI_awaddr;
  input bit [7 : 0] S01_AXI_awlen;
  input bit [2 : 0] S01_AXI_awsize;
  input bit [1 : 0] S01_AXI_awburst;
  input bit [0 : 0] S01_AXI_awlock;
  input bit [3 : 0] S01_AXI_awcache;
  input bit [2 : 0] S01_AXI_awprot;
  input bit [3 : 0] S01_AXI_awregion;
  input bit [3 : 0] S01_AXI_awqos;
  input bit [0 : 0] S01_AXI_awvalid;
  output wire [0 : 0] S01_AXI_awready;
  input bit [127 : 0] S01_AXI_wdata;
  input bit [15 : 0] S01_AXI_wstrb;
  input bit [0 : 0] S01_AXI_wlast;
  input bit [0 : 0] S01_AXI_wvalid;
  output wire [0 : 0] S01_AXI_wready;
  output wire [1 : 0] S01_AXI_bresp;
  output wire [0 : 0] S01_AXI_bvalid;
  input bit [0 : 0] S01_AXI_bready;
  input bit [63 : 0] S01_AXI_araddr;
  input bit [7 : 0] S01_AXI_arlen;
  input bit [2 : 0] S01_AXI_arsize;
  input bit [1 : 0] S01_AXI_arburst;
  input bit [0 : 0] S01_AXI_arlock;
  input bit [3 : 0] S01_AXI_arcache;
  input bit [2 : 0] S01_AXI_arprot;
  input bit [3 : 0] S01_AXI_arregion;
  input bit [3 : 0] S01_AXI_arqos;
  input bit [0 : 0] S01_AXI_arvalid;
  output wire [0 : 0] S01_AXI_arready;
  output wire [127 : 0] S01_AXI_rdata;
  output wire [1 : 0] S01_AXI_rresp;
  output wire [0 : 0] S01_AXI_rlast;
  output wire [0 : 0] S01_AXI_rvalid;
  input bit [0 : 0] S01_AXI_rready;
  input bit [63 : 0] S02_AXI_awaddr;
  input bit [7 : 0] S02_AXI_awlen;
  input bit [2 : 0] S02_AXI_awsize;
  input bit [1 : 0] S02_AXI_awburst;
  input bit [0 : 0] S02_AXI_awlock;
  input bit [3 : 0] S02_AXI_awcache;
  input bit [2 : 0] S02_AXI_awprot;
  input bit [3 : 0] S02_AXI_awregion;
  input bit [3 : 0] S02_AXI_awqos;
  input bit [0 : 0] S02_AXI_awvalid;
  output wire [0 : 0] S02_AXI_awready;
  input bit [127 : 0] S02_AXI_wdata;
  input bit [15 : 0] S02_AXI_wstrb;
  input bit [0 : 0] S02_AXI_wlast;
  input bit [0 : 0] S02_AXI_wvalid;
  output wire [0 : 0] S02_AXI_wready;
  output wire [1 : 0] S02_AXI_bresp;
  output wire [0 : 0] S02_AXI_bvalid;
  input bit [0 : 0] S02_AXI_bready;
  input bit [63 : 0] S02_AXI_araddr;
  input bit [7 : 0] S02_AXI_arlen;
  input bit [2 : 0] S02_AXI_arsize;
  input bit [1 : 0] S02_AXI_arburst;
  input bit [0 : 0] S02_AXI_arlock;
  input bit [3 : 0] S02_AXI_arcache;
  input bit [2 : 0] S02_AXI_arprot;
  input bit [3 : 0] S02_AXI_arregion;
  input bit [3 : 0] S02_AXI_arqos;
  input bit [0 : 0] S02_AXI_arvalid;
  output wire [0 : 0] S02_AXI_arready;
  output wire [127 : 0] S02_AXI_rdata;
  output wire [1 : 0] S02_AXI_rresp;
  output wire [0 : 0] S02_AXI_rlast;
  output wire [0 : 0] S02_AXI_rvalid;
  input bit [0 : 0] S02_AXI_rready;
  input bit [63 : 0] S03_AXI_awaddr;
  input bit [7 : 0] S03_AXI_awlen;
  input bit [2 : 0] S03_AXI_awsize;
  input bit [1 : 0] S03_AXI_awburst;
  input bit [0 : 0] S03_AXI_awlock;
  input bit [3 : 0] S03_AXI_awcache;
  input bit [2 : 0] S03_AXI_awprot;
  input bit [3 : 0] S03_AXI_awregion;
  input bit [3 : 0] S03_AXI_awqos;
  input bit [0 : 0] S03_AXI_awvalid;
  output wire [0 : 0] S03_AXI_awready;
  input bit [127 : 0] S03_AXI_wdata;
  input bit [15 : 0] S03_AXI_wstrb;
  input bit [0 : 0] S03_AXI_wlast;
  input bit [0 : 0] S03_AXI_wvalid;
  output wire [0 : 0] S03_AXI_wready;
  output wire [1 : 0] S03_AXI_bresp;
  output wire [0 : 0] S03_AXI_bvalid;
  input bit [0 : 0] S03_AXI_bready;
  input bit [63 : 0] S03_AXI_araddr;
  input bit [7 : 0] S03_AXI_arlen;
  input bit [2 : 0] S03_AXI_arsize;
  input bit [1 : 0] S03_AXI_arburst;
  input bit [0 : 0] S03_AXI_arlock;
  input bit [3 : 0] S03_AXI_arcache;
  input bit [2 : 0] S03_AXI_arprot;
  input bit [3 : 0] S03_AXI_arregion;
  input bit [3 : 0] S03_AXI_arqos;
  input bit [0 : 0] S03_AXI_arvalid;
  output wire [0 : 0] S03_AXI_arready;
  output wire [127 : 0] S03_AXI_rdata;
  output wire [1 : 0] S03_AXI_rresp;
  output wire [0 : 0] S03_AXI_rlast;
  output wire [0 : 0] S03_AXI_rvalid;
  input bit [0 : 0] S03_AXI_rready;
  input bit [63 : 0] S04_AXI_awaddr;
  input bit [7 : 0] S04_AXI_awlen;
  input bit [2 : 0] S04_AXI_awsize;
  input bit [1 : 0] S04_AXI_awburst;
  input bit [0 : 0] S04_AXI_awlock;
  input bit [3 : 0] S04_AXI_awcache;
  input bit [2 : 0] S04_AXI_awprot;
  input bit [3 : 0] S04_AXI_awregion;
  input bit [3 : 0] S04_AXI_awqos;
  input bit [0 : 0] S04_AXI_awvalid;
  output wire [0 : 0] S04_AXI_awready;
  input bit [127 : 0] S04_AXI_wdata;
  input bit [15 : 0] S04_AXI_wstrb;
  input bit [0 : 0] S04_AXI_wlast;
  input bit [0 : 0] S04_AXI_wvalid;
  output wire [0 : 0] S04_AXI_wready;
  output wire [1 : 0] S04_AXI_bresp;
  output wire [0 : 0] S04_AXI_bvalid;
  input bit [0 : 0] S04_AXI_bready;
  input bit [63 : 0] S04_AXI_araddr;
  input bit [7 : 0] S04_AXI_arlen;
  input bit [2 : 0] S04_AXI_arsize;
  input bit [1 : 0] S04_AXI_arburst;
  input bit [0 : 0] S04_AXI_arlock;
  input bit [3 : 0] S04_AXI_arcache;
  input bit [2 : 0] S04_AXI_arprot;
  input bit [3 : 0] S04_AXI_arregion;
  input bit [3 : 0] S04_AXI_arqos;
  input bit [0 : 0] S04_AXI_arvalid;
  output wire [0 : 0] S04_AXI_arready;
  output wire [127 : 0] S04_AXI_rdata;
  output wire [1 : 0] S04_AXI_rresp;
  output wire [0 : 0] S04_AXI_rlast;
  output wire [0 : 0] S04_AXI_rvalid;
  input bit [0 : 0] S04_AXI_rready;
  input bit [63 : 0] S05_AXI_awaddr;
  input bit [7 : 0] S05_AXI_awlen;
  input bit [2 : 0] S05_AXI_awsize;
  input bit [1 : 0] S05_AXI_awburst;
  input bit [0 : 0] S05_AXI_awlock;
  input bit [3 : 0] S05_AXI_awcache;
  input bit [2 : 0] S05_AXI_awprot;
  input bit [3 : 0] S05_AXI_awregion;
  input bit [3 : 0] S05_AXI_awqos;
  input bit [0 : 0] S05_AXI_awvalid;
  output wire [0 : 0] S05_AXI_awready;
  input bit [127 : 0] S05_AXI_wdata;
  input bit [15 : 0] S05_AXI_wstrb;
  input bit [0 : 0] S05_AXI_wlast;
  input bit [0 : 0] S05_AXI_wvalid;
  output wire [0 : 0] S05_AXI_wready;
  output wire [1 : 0] S05_AXI_bresp;
  output wire [0 : 0] S05_AXI_bvalid;
  input bit [0 : 0] S05_AXI_bready;
  input bit [63 : 0] S05_AXI_araddr;
  input bit [7 : 0] S05_AXI_arlen;
  input bit [2 : 0] S05_AXI_arsize;
  input bit [1 : 0] S05_AXI_arburst;
  input bit [0 : 0] S05_AXI_arlock;
  input bit [3 : 0] S05_AXI_arcache;
  input bit [2 : 0] S05_AXI_arprot;
  input bit [3 : 0] S05_AXI_arregion;
  input bit [3 : 0] S05_AXI_arqos;
  input bit [0 : 0] S05_AXI_arvalid;
  output wire [0 : 0] S05_AXI_arready;
  output wire [127 : 0] S05_AXI_rdata;
  output wire [1 : 0] S05_AXI_rresp;
  output wire [0 : 0] S05_AXI_rlast;
  output wire [0 : 0] S05_AXI_rvalid;
  input bit [0 : 0] S05_AXI_rready;
  input bit [63 : 0] S06_AXI_awaddr;
  input bit [7 : 0] S06_AXI_awlen;
  input bit [2 : 0] S06_AXI_awsize;
  input bit [1 : 0] S06_AXI_awburst;
  input bit [0 : 0] S06_AXI_awlock;
  input bit [3 : 0] S06_AXI_awcache;
  input bit [2 : 0] S06_AXI_awprot;
  input bit [3 : 0] S06_AXI_awregion;
  input bit [3 : 0] S06_AXI_awqos;
  input bit [0 : 0] S06_AXI_awvalid;
  output wire [0 : 0] S06_AXI_awready;
  input bit [31 : 0] S06_AXI_wdata;
  input bit [3 : 0] S06_AXI_wstrb;
  input bit [0 : 0] S06_AXI_wlast;
  input bit [0 : 0] S06_AXI_wvalid;
  output wire [0 : 0] S06_AXI_wready;
  output wire [1 : 0] S06_AXI_bresp;
  output wire [0 : 0] S06_AXI_bvalid;
  input bit [0 : 0] S06_AXI_bready;
  input bit [63 : 0] S06_AXI_araddr;
  input bit [7 : 0] S06_AXI_arlen;
  input bit [2 : 0] S06_AXI_arsize;
  input bit [1 : 0] S06_AXI_arburst;
  input bit [0 : 0] S06_AXI_arlock;
  input bit [3 : 0] S06_AXI_arcache;
  input bit [2 : 0] S06_AXI_arprot;
  input bit [3 : 0] S06_AXI_arregion;
  input bit [3 : 0] S06_AXI_arqos;
  input bit [0 : 0] S06_AXI_arvalid;
  output wire [0 : 0] S06_AXI_arready;
  output wire [31 : 0] S06_AXI_rdata;
  output wire [1 : 0] S06_AXI_rresp;
  output wire [0 : 0] S06_AXI_rlast;
  output wire [0 : 0] S06_AXI_rvalid;
  input bit [0 : 0] S06_AXI_rready;
  input bit aclk0;
  input bit aclk1;
  input bit aclk2;
  input bit aclk3;
  input bit aclk4;
  input bit aclk5;
  input bit aclk6;
  input bit [0 : 0] sys_clk0_clk_p;
  input bit [0 : 0] sys_clk0_clk_n;
  inout wire [63 : 0] CH0_DDR4_0_dq;
  inout wire [7 : 0] CH0_DDR4_0_dqs_t;
  inout wire [7 : 0] CH0_DDR4_0_dqs_c;
  output wire [16 : 0] CH0_DDR4_0_adr;
  output wire [1 : 0] CH0_DDR4_0_ba;
  output wire [0 : 0] CH0_DDR4_0_bg;
  output wire [0 : 0] CH0_DDR4_0_act_n;
  output wire [0 : 0] CH0_DDR4_0_reset_n;
  output wire [0 : 0] CH0_DDR4_0_ck_t;
  output wire [0 : 0] CH0_DDR4_0_ck_c;
  output wire [0 : 0] CH0_DDR4_0_cke;
  output wire [0 : 0] CH0_DDR4_0_cs_n;
  inout wire [7 : 0] CH0_DDR4_0_dm_n;
  output wire [0 : 0] CH0_DDR4_0_odt;
  input bit [15 : 0] S05_AXI_arid;
  input bit [17 : 0] S05_AXI_aruser;
  input bit [15 : 0] S05_AXI_awid;
  input bit [17 : 0] S05_AXI_awuser;
  output wire [15 : 0] S05_AXI_bid;
  output wire [15 : 0] S05_AXI_buser;
  output wire [15 : 0] S05_AXI_rid;
  output wire [16 : 0] S05_AXI_ruser;
  input bit [16 : 0] S05_AXI_wuser;
  input bit [15 : 0] S03_AXI_arid;
  input bit [17 : 0] S03_AXI_aruser;
  input bit [15 : 0] S03_AXI_awid;
  input bit [17 : 0] S03_AXI_awuser;
  output wire [15 : 0] S03_AXI_bid;
  output wire [15 : 0] S03_AXI_rid;
  output wire [16 : 0] S03_AXI_ruser;
  input bit [16 : 0] S03_AXI_wuser;
  input bit [15 : 0] S04_AXI_arid;
  input bit [17 : 0] S04_AXI_aruser;
  input bit [15 : 0] S04_AXI_awid;
  input bit [17 : 0] S04_AXI_awuser;
  output wire [15 : 0] S04_AXI_bid;
  output wire [15 : 0] S04_AXI_rid;
  output wire [16 : 0] S04_AXI_ruser;
  input bit [16 : 0] S04_AXI_wuser;
  input bit [15 : 0] S02_AXI_arid;
  input bit [17 : 0] S02_AXI_aruser;
  input bit [15 : 0] S02_AXI_awid;
  input bit [17 : 0] S02_AXI_awuser;
  output wire [15 : 0] S02_AXI_bid;
  output wire [15 : 0] S02_AXI_rid;
  output wire [16 : 0] S02_AXI_ruser;
  input bit [16 : 0] S02_AXI_wuser;
  input bit [0 : 0] S06_AXI_arid;
  input bit [0 : 0] S06_AXI_awid;
  output wire [0 : 0] S06_AXI_bid;
  output wire [0 : 0] S06_AXI_rid;
  input bit [15 : 0] S01_AXI_arid;
  input bit [17 : 0] S01_AXI_aruser;
  input bit [15 : 0] S01_AXI_awid;
  input bit [17 : 0] S01_AXI_awuser;
  output wire [15 : 0] S01_AXI_bid;
  output wire [15 : 0] S01_AXI_rid;
  output wire [16 : 0] S01_AXI_ruser;
  input bit [16 : 0] S01_AXI_wuser;
  input bit [15 : 0] S00_AXI_arid;
  input bit [17 : 0] S00_AXI_aruser;
  input bit [15 : 0] S00_AXI_awid;
  input bit [17 : 0] S00_AXI_awuser;
  output wire [15 : 0] S00_AXI_bid;
  output wire [15 : 0] S00_AXI_rid;
  output wire [16 : 0] S00_AXI_ruser;
  input bit [16 : 0] S00_AXI_wuser;
endmodule
`endif
