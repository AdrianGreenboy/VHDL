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
// Filename:    bd_8be5_S04_AXI_rpu_0_stub.sv
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
module bd_8be5_S04_AXI_rpu_0 (
  input bit_as_bool IF_NOC_AXI_WVALID,
  output bit_as_bool IF_NOC_AXI_WREADY,
  input bit [0 : 0] IF_NOC_AXI_WLAST,
  input bit [15 : 0] IF_NOC_AXI_AWID,
  input bit [127 : 0] IF_NOC_AXI_WDATA,
  input bit [15 : 0] IF_NOC_AXI_WSTRB,
  output bit_as_bool IF_NOC_AXI_ARREADY,
  output bit_as_bool IF_NOC_AXI_AWREADY,
  output bit [15 : 0] IF_NOC_AXI_BID,
  output bit [1 : 0] IF_NOC_AXI_BRESP,
  output bit_as_bool IF_NOC_AXI_BVALID,
  output bit [127 : 0] IF_NOC_AXI_RDATA,
  output bit [15 : 0] IF_NOC_AXI_RID,
  output bit [0 : 0] IF_NOC_AXI_RLAST,
  output bit [1 : 0] IF_NOC_AXI_RRESP,
  output bit [16 : 0] IF_NOC_AXI_RUSER,
  output bit_as_bool IF_NOC_AXI_RVALID,
  output bit [7 : 0] IF_NOC_NPP_IN_NOC_CREDIT_RETURN,
  output bit_as_bool IF_NOC_NPP_OUT_NOC_CREDIT_RDY,
  output bit [181 : 0] IF_NOC_NPP_OUT_NOC_FLIT,
  output bit [7 : 0] IF_NOC_NPP_OUT_NOC_VALID,
  input bit_as_bool aclk,
  input bit [63 : 0] IF_NOC_AXI_ARADDR,
  input bit [1 : 0] IF_NOC_AXI_ARBURST,
  input bit [3 : 0] IF_NOC_AXI_ARCACHE,
  input bit [15 : 0] IF_NOC_AXI_ARID,
  input bit [7 : 0] IF_NOC_AXI_ARLEN,
  input bit [0 : 0] IF_NOC_AXI_ARLOCK,
  input bit [2 : 0] IF_NOC_AXI_ARPROT,
  input bit [3 : 0] IF_NOC_AXI_ARQOS,
  input bit [3 : 0] IF_NOC_AXI_ARREGION,
  input bit [2 : 0] IF_NOC_AXI_ARSIZE,
  input bit [17 : 0] IF_NOC_AXI_ARUSER,
  input bit_as_bool IF_NOC_AXI_ARVALID,
  input bit [63 : 0] IF_NOC_AXI_AWADDR,
  input bit [1 : 0] IF_NOC_AXI_AWBURST,
  input bit [3 : 0] IF_NOC_AXI_AWCACHE,
  input bit [7 : 0] IF_NOC_AXI_AWLEN,
  input bit [0 : 0] IF_NOC_AXI_AWLOCK,
  input bit [2 : 0] IF_NOC_AXI_AWPROT,
  input bit [3 : 0] IF_NOC_AXI_AWQOS,
  input bit [3 : 0] IF_NOC_AXI_AWREGION,
  input bit [2 : 0] IF_NOC_AXI_AWSIZE,
  input bit [17 : 0] IF_NOC_AXI_AWUSER,
  input bit_as_bool IF_NOC_AXI_AWVALID,
  input bit_as_bool IF_NOC_AXI_BREADY,
  input bit_as_bool IF_NOC_AXI_RREADY,
  input bit [16 : 0] IF_NOC_AXI_WUSER,
  input bit_as_bool IF_NOC_NPP_IN_NOC_CREDIT_RDY,
  input bit [181 : 0] IF_NOC_NPP_IN_NOC_FLIT,
  input bit [7 : 0] IF_NOC_NPP_IN_NOC_VALID,
  input bit [7 : 0] IF_NOC_NPP_OUT_NOC_CREDIT_RETURN,
  input bit [11 : 0] NMU_WR_USR_DST,
  input bit [11 : 0] NMU_RD_USR_DST,
  output bit_as_bool NMU,
  input bit_as_bool AXI_IN,
  input bit_as_bool NMU_RD_DEST_MODE,
  input bit_as_bool NMU_WR_DEST_MODE
);
endmodule
`endif

`ifdef XCELIUM
(* XMSC_MODULE_EXPORT *)
module bd_8be5_S04_AXI_rpu_0 (IF_NOC_AXI_WVALID,IF_NOC_AXI_WREADY,IF_NOC_AXI_WLAST,IF_NOC_AXI_AWID,IF_NOC_AXI_WDATA,IF_NOC_AXI_WSTRB,IF_NOC_AXI_ARREADY,IF_NOC_AXI_AWREADY,IF_NOC_AXI_BID,IF_NOC_AXI_BRESP,IF_NOC_AXI_BVALID,IF_NOC_AXI_RDATA,IF_NOC_AXI_RID,IF_NOC_AXI_RLAST,IF_NOC_AXI_RRESP,IF_NOC_AXI_RUSER,IF_NOC_AXI_RVALID,IF_NOC_NPP_IN_NOC_CREDIT_RETURN,IF_NOC_NPP_OUT_NOC_CREDIT_RDY,IF_NOC_NPP_OUT_NOC_FLIT,IF_NOC_NPP_OUT_NOC_VALID,aclk,IF_NOC_AXI_ARADDR,IF_NOC_AXI_ARBURST,IF_NOC_AXI_ARCACHE,IF_NOC_AXI_ARID,IF_NOC_AXI_ARLEN,IF_NOC_AXI_ARLOCK,IF_NOC_AXI_ARPROT,IF_NOC_AXI_ARQOS,IF_NOC_AXI_ARREGION,IF_NOC_AXI_ARSIZE,IF_NOC_AXI_ARUSER,IF_NOC_AXI_ARVALID,IF_NOC_AXI_AWADDR,IF_NOC_AXI_AWBURST,IF_NOC_AXI_AWCACHE,IF_NOC_AXI_AWLEN,IF_NOC_AXI_AWLOCK,IF_NOC_AXI_AWPROT,IF_NOC_AXI_AWQOS,IF_NOC_AXI_AWREGION,IF_NOC_AXI_AWSIZE,IF_NOC_AXI_AWUSER,IF_NOC_AXI_AWVALID,IF_NOC_AXI_BREADY,IF_NOC_AXI_RREADY,IF_NOC_AXI_WUSER,IF_NOC_NPP_IN_NOC_CREDIT_RDY,IF_NOC_NPP_IN_NOC_FLIT,IF_NOC_NPP_IN_NOC_VALID,IF_NOC_NPP_OUT_NOC_CREDIT_RETURN,NMU_WR_USR_DST,NMU_RD_USR_DST,NMU,AXI_IN,NMU_RD_DEST_MODE,NMU_WR_DEST_MODE)
(* integer foreign = "SystemC";
*);
  input bit IF_NOC_AXI_WVALID;
  output wire IF_NOC_AXI_WREADY;
  input bit [0 : 0] IF_NOC_AXI_WLAST;
  input bit [15 : 0] IF_NOC_AXI_AWID;
  input bit [127 : 0] IF_NOC_AXI_WDATA;
  input bit [15 : 0] IF_NOC_AXI_WSTRB;
  output wire IF_NOC_AXI_ARREADY;
  output wire IF_NOC_AXI_AWREADY;
  output wire [15 : 0] IF_NOC_AXI_BID;
  output wire [1 : 0] IF_NOC_AXI_BRESP;
  output wire IF_NOC_AXI_BVALID;
  output wire [127 : 0] IF_NOC_AXI_RDATA;
  output wire [15 : 0] IF_NOC_AXI_RID;
  output wire [0 : 0] IF_NOC_AXI_RLAST;
  output wire [1 : 0] IF_NOC_AXI_RRESP;
  output wire [16 : 0] IF_NOC_AXI_RUSER;
  output wire IF_NOC_AXI_RVALID;
  output wire [7 : 0] IF_NOC_NPP_IN_NOC_CREDIT_RETURN;
  output wire IF_NOC_NPP_OUT_NOC_CREDIT_RDY;
  output wire [181 : 0] IF_NOC_NPP_OUT_NOC_FLIT;
  output wire [7 : 0] IF_NOC_NPP_OUT_NOC_VALID;
  input bit aclk;
  input bit [63 : 0] IF_NOC_AXI_ARADDR;
  input bit [1 : 0] IF_NOC_AXI_ARBURST;
  input bit [3 : 0] IF_NOC_AXI_ARCACHE;
  input bit [15 : 0] IF_NOC_AXI_ARID;
  input bit [7 : 0] IF_NOC_AXI_ARLEN;
  input bit [0 : 0] IF_NOC_AXI_ARLOCK;
  input bit [2 : 0] IF_NOC_AXI_ARPROT;
  input bit [3 : 0] IF_NOC_AXI_ARQOS;
  input bit [3 : 0] IF_NOC_AXI_ARREGION;
  input bit [2 : 0] IF_NOC_AXI_ARSIZE;
  input bit [17 : 0] IF_NOC_AXI_ARUSER;
  input bit IF_NOC_AXI_ARVALID;
  input bit [63 : 0] IF_NOC_AXI_AWADDR;
  input bit [1 : 0] IF_NOC_AXI_AWBURST;
  input bit [3 : 0] IF_NOC_AXI_AWCACHE;
  input bit [7 : 0] IF_NOC_AXI_AWLEN;
  input bit [0 : 0] IF_NOC_AXI_AWLOCK;
  input bit [2 : 0] IF_NOC_AXI_AWPROT;
  input bit [3 : 0] IF_NOC_AXI_AWQOS;
  input bit [3 : 0] IF_NOC_AXI_AWREGION;
  input bit [2 : 0] IF_NOC_AXI_AWSIZE;
  input bit [17 : 0] IF_NOC_AXI_AWUSER;
  input bit IF_NOC_AXI_AWVALID;
  input bit IF_NOC_AXI_BREADY;
  input bit IF_NOC_AXI_RREADY;
  input bit [16 : 0] IF_NOC_AXI_WUSER;
  input bit IF_NOC_NPP_IN_NOC_CREDIT_RDY;
  input bit [181 : 0] IF_NOC_NPP_IN_NOC_FLIT;
  input bit [7 : 0] IF_NOC_NPP_IN_NOC_VALID;
  input bit [7 : 0] IF_NOC_NPP_OUT_NOC_CREDIT_RETURN;
  input bit [11 : 0] NMU_WR_USR_DST;
  input bit [11 : 0] NMU_RD_USR_DST;
  output wire NMU;
  input bit AXI_IN;
  input bit NMU_RD_DEST_MODE;
  input bit NMU_WR_DEST_MODE;
endmodule
`endif
