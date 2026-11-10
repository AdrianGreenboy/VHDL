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
// Filename:    bd_8be5_MC0_ddrc_0_stub.sv
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
module bd_8be5_MC0_ddrc_0 (
  input bit_as_bool sys_clk_p,
  input bit_as_bool sys_clk_n,
  output bit [16 : 0] ch0_ddr4_adr,
  output bit [0 : 0] ch0_ddr4_bg,
  output bit [1 : 0] ch0_ddr4_ba,
  output bit [0 : 0] ch0_ddr4_cke,
  output bit [0 : 0] ch0_ddr4_ck_t,
  output bit [0 : 0] ch0_ddr4_ck_c,
  output bit [0 : 0] ch0_ddr4_cs_n,
  output bit [7 : 0] ch0_ddr4_dm_dbi_n,
  output bit [63 : 0] ch0_ddr4_dq,
  output bit [7 : 0] ch0_ddr4_dqs_c,
  output bit [7 : 0] ch0_ddr4_dqs_t,
  output bit [0 : 0] ch0_ddr4_odt,
  output bit_as_bool ch0_ddr4_reset_n,
  output bit_as_bool ch0_ddr4_act_n,
  input bit [7 : 0] noc2dmc_valid_in_0,
  input bit [181 : 0] noc2dmc_data_in_0,
  input bit_as_bool noc2dmc_credit_rdy_0,
  output bit [7 : 0] dmc2noc_credit_rtn_0,
  input bit [7 : 0] noc2dmc_valid_in_1,
  input bit [181 : 0] noc2dmc_data_in_1,
  input bit_as_bool noc2dmc_credit_rdy_1,
  output bit [7 : 0] dmc2noc_credit_rtn_1,
  input bit [7 : 0] noc2dmc_valid_in_2,
  input bit [181 : 0] noc2dmc_data_in_2,
  input bit_as_bool noc2dmc_credit_rdy_2,
  output bit [7 : 0] dmc2noc_credit_rtn_2,
  input bit [7 : 0] noc2dmc_valid_in_3,
  input bit [181 : 0] noc2dmc_data_in_3,
  input bit_as_bool noc2dmc_credit_rdy_3,
  output bit [7 : 0] dmc2noc_credit_rtn_3,
  output bit [7 : 0] dmc2noc_valid_out_0,
  output bit [181 : 0] dmc2noc_data_out_0,
  output bit_as_bool dmc2noc_credit_rdy_0,
  input bit [7 : 0] noc2dmc_credit_rtn_0,
  output bit [7 : 0] dmc2noc_valid_out_1,
  output bit [181 : 0] dmc2noc_data_out_1,
  output bit_as_bool dmc2noc_credit_rdy_1,
  input bit [7 : 0] noc2dmc_credit_rtn_1,
  output bit [7 : 0] dmc2noc_valid_out_2,
  output bit [181 : 0] dmc2noc_data_out_2,
  output bit_as_bool dmc2noc_credit_rdy_2,
  input bit [7 : 0] noc2dmc_credit_rtn_2,
  output bit [7 : 0] dmc2noc_valid_out_3,
  output bit [181 : 0] dmc2noc_data_out_3,
  output bit_as_bool dmc2noc_credit_rdy_3,
  input bit [7 : 0] noc2dmc_credit_rtn_3,
  input bit_as_bool from_noc_0,
  input bit_as_bool from_noc_1,
  input bit_as_bool from_noc_2,
  input bit_as_bool from_noc_3
);
endmodule
`endif

`ifdef XCELIUM
(* XMSC_MODULE_EXPORT *)
module bd_8be5_MC0_ddrc_0 (sys_clk_p,sys_clk_n,ch0_ddr4_adr,ch0_ddr4_bg,ch0_ddr4_ba,ch0_ddr4_cke,ch0_ddr4_ck_t,ch0_ddr4_ck_c,ch0_ddr4_cs_n,ch0_ddr4_dm_dbi_n,ch0_ddr4_dq,ch0_ddr4_dqs_c,ch0_ddr4_dqs_t,ch0_ddr4_odt,ch0_ddr4_reset_n,ch0_ddr4_act_n,noc2dmc_valid_in_0,noc2dmc_data_in_0,noc2dmc_credit_rdy_0,dmc2noc_credit_rtn_0,noc2dmc_valid_in_1,noc2dmc_data_in_1,noc2dmc_credit_rdy_1,dmc2noc_credit_rtn_1,noc2dmc_valid_in_2,noc2dmc_data_in_2,noc2dmc_credit_rdy_2,dmc2noc_credit_rtn_2,noc2dmc_valid_in_3,noc2dmc_data_in_3,noc2dmc_credit_rdy_3,dmc2noc_credit_rtn_3,dmc2noc_valid_out_0,dmc2noc_data_out_0,dmc2noc_credit_rdy_0,noc2dmc_credit_rtn_0,dmc2noc_valid_out_1,dmc2noc_data_out_1,dmc2noc_credit_rdy_1,noc2dmc_credit_rtn_1,dmc2noc_valid_out_2,dmc2noc_data_out_2,dmc2noc_credit_rdy_2,noc2dmc_credit_rtn_2,dmc2noc_valid_out_3,dmc2noc_data_out_3,dmc2noc_credit_rdy_3,noc2dmc_credit_rtn_3,from_noc_0,from_noc_1,from_noc_2,from_noc_3)
(* integer foreign = "SystemC";
*);
  input bit sys_clk_p;
  input bit sys_clk_n;
  output wire [16 : 0] ch0_ddr4_adr;
  output wire [0 : 0] ch0_ddr4_bg;
  output wire [1 : 0] ch0_ddr4_ba;
  output wire [0 : 0] ch0_ddr4_cke;
  output wire [0 : 0] ch0_ddr4_ck_t;
  output wire [0 : 0] ch0_ddr4_ck_c;
  output wire [0 : 0] ch0_ddr4_cs_n;
  inout wire [7 : 0] ch0_ddr4_dm_dbi_n;
  inout wire [63 : 0] ch0_ddr4_dq;
  inout wire [7 : 0] ch0_ddr4_dqs_c;
  inout wire [7 : 0] ch0_ddr4_dqs_t;
  output wire [0 : 0] ch0_ddr4_odt;
  output wire ch0_ddr4_reset_n;
  output wire ch0_ddr4_act_n;
  input bit [7 : 0] noc2dmc_valid_in_0;
  input bit [181 : 0] noc2dmc_data_in_0;
  input bit noc2dmc_credit_rdy_0;
  output wire [7 : 0] dmc2noc_credit_rtn_0;
  input bit [7 : 0] noc2dmc_valid_in_1;
  input bit [181 : 0] noc2dmc_data_in_1;
  input bit noc2dmc_credit_rdy_1;
  output wire [7 : 0] dmc2noc_credit_rtn_1;
  input bit [7 : 0] noc2dmc_valid_in_2;
  input bit [181 : 0] noc2dmc_data_in_2;
  input bit noc2dmc_credit_rdy_2;
  output wire [7 : 0] dmc2noc_credit_rtn_2;
  input bit [7 : 0] noc2dmc_valid_in_3;
  input bit [181 : 0] noc2dmc_data_in_3;
  input bit noc2dmc_credit_rdy_3;
  output wire [7 : 0] dmc2noc_credit_rtn_3;
  output wire [7 : 0] dmc2noc_valid_out_0;
  output wire [181 : 0] dmc2noc_data_out_0;
  output wire dmc2noc_credit_rdy_0;
  input bit [7 : 0] noc2dmc_credit_rtn_0;
  output wire [7 : 0] dmc2noc_valid_out_1;
  output wire [181 : 0] dmc2noc_data_out_1;
  output wire dmc2noc_credit_rdy_1;
  input bit [7 : 0] noc2dmc_credit_rtn_1;
  output wire [7 : 0] dmc2noc_valid_out_2;
  output wire [181 : 0] dmc2noc_data_out_2;
  output wire dmc2noc_credit_rdy_2;
  input bit [7 : 0] noc2dmc_credit_rtn_2;
  output wire [7 : 0] dmc2noc_valid_out_3;
  output wire [181 : 0] dmc2noc_data_out_3;
  output wire dmc2noc_credit_rdy_3;
  input bit [7 : 0] noc2dmc_credit_rtn_3;
  input bit from_noc_0;
  input bit from_noc_1;
  input bit from_noc_2;
  input bit from_noc_3;
endmodule
`endif
