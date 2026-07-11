/******************************************************************************
// (c) Copyright 2017 - 2018 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
/******************************************************************************/
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 1.0
//  \   \         Application        : DDR4
//  /   /         Filename           : ddr_model_wrapper.sv
// /___/   /\     Date Last Modified : $Date: 2016/03/07 $
// \   \  /  \    Date Created       : March 7 2016
//  \___\/\___\
//
// Device           : Versal
// Design Name      : MC (Memory Controller)
// Purpose          : Memory Model
// 
// Reference        :
// Revision History :
//*****************************************************************************
`timescale 1ps/1ps

module bd_b77b_MC0_ddrc_0_phy_ddr_responder (
     input  [16 : 0]       ddr4_adr
    ,input  [0 : 0]         ddr4_bg
    ,input  [1 : 0]         ddr4_ba
    ,input  [0 : 0]        ddr4_cke
    ,input  [0 : 0]         ddr4_ck_t
    ,input  [0 : 0]         ddr4_ck_c
    ,input  [0 : 0]         ddr4_cs_n
    ,inout   [7 : 0]         ddr4_dm_dbi_n
    ,inout   [63 : 0]         ddr4_dq
    ,inout   [7 : 0]        ddr4_dqs_c
    ,inout   [7 : 0]        ddr4_dqs_t
    ,input  [0 : 0]        ddr4_odt
    ,input  ddr4_reset_n
    ,input  ddr4_act_n
);



//



 



ddr_model_wrapper #(
       .WL               (16)
      ,.RL               (22)
      ,.RANK_WIDTH       (1)
      ,.LRANK_WIDTH      (1)
      ,.ADDR_WIDTH_1     (17)
      ,.ROW_WIDTH        (17)
      ,.BA_WIDTH         (2)
      ,.BG_WIDTH         (1)
      ,.COL_WIDTH        (10)
      ,.DQ_WIDTH         (64)
      ,.DQS_WIDTH        (8)
      ,.DM_WIDTH         (8)
      ,.DDR4_COMPONENT_WIDTH ("x16")
      ,.NUM_RANKS        (1)
      ,.NUM_LRANKS       (1)
      ,.NUM_SLOTS        (1)
      ,.RCD_DELAY        (0)
      ,.DIMM_TYPE        (0)
      ,.DM_ENABLE        ("DM_NO_DBI")
      ,.RD_DBI_EN        (0)
) inst (
 .ddr4_adr(ddr4_adr)      
,.ddr4_bg(ddr4_bg)
,.ddr4_ba(ddr4_ba)
,.ddr4_cke(ddr4_cke)
,.ddr4_ck_t(ddr4_ck_t)
,.ddr4_ck_c(ddr4_ck_c)
,.ddr4_cs_n(ddr4_cs_n)
,.ddr4_dm_dbi_n(ddr4_dm_dbi_n)
,.ddr4_dq(ddr4_dq)
,.ddr4_dqs_c(ddr4_dqs_c)
,.ddr4_dqs_t(ddr4_dqs_t)
,.ddr4_odt(ddr4_odt)
,.ddr4_reset_n(ddr4_reset_n)
,.ddr4_act_n(ddr4_act_n)     
);

endmodule
