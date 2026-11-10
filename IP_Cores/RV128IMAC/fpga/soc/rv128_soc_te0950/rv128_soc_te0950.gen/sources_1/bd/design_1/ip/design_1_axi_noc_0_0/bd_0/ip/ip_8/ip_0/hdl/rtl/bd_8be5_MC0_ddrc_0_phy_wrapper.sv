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
//  \   \         Application        : DDR4, LPDDR4
//  /   /         Filename           : ddrmc_top_v1_0.sv
// /___/   /\     Date Last Modified : $Date: 2016/03/07 $
// \   \  /  \    Date Created       : March 7 2016
//  \___\/\___\
//
// Device           : Versal
// Design Name      : MC (Memory Controller)
// Purpose          : Top 
// 
// Reference        :
// Revision History :
//*****************************************************************************
`ifdef MODEL_TECH
  `define SIMULATION_MODE
`elsif INCA
  `define SIMULATION_MODE
`elsif VCS
  `define SIMULATION_MODE
`elsif XILINX_SIMULATOR
  `define SIMULATION_MODE
`elsif _VCP
  `define SIMULATION_MODE
`endif
`timescale 1ps/1ps

`define NON_S80
//`include "noc_dc_common_define.vh"
module bd_8be5_MC0_ddrc_0_phy_wrapper #(
  parameter [0:0] ARBITER_CONFIG = 1'h1,
  parameter [1:0] CAL_CS_CH = 2'h0,
  parameter [0:0] CAL_MODE = 1'h0,
  parameter [18:0] CLK_GATE = 19'h7FFFF,
  parameter [4:0] CPLX_BURST_ARRAY0 = 5'h01,
  parameter [4:0] CPLX_BURST_ARRAY1 = 5'h02,
  parameter [4:0] CPLX_BURST_ARRAY10 = 5'h05,
  parameter [4:0] CPLX_BURST_ARRAY11 = 5'h06,
  parameter [4:0] CPLX_BURST_ARRAY12 = 5'h03,
  parameter [4:0] CPLX_BURST_ARRAY13 = 5'h04,
  parameter [4:0] CPLX_BURST_ARRAY14 = 5'h05,
  parameter [4:0] CPLX_BURST_ARRAY15 = 5'h07,
  parameter [4:0] CPLX_BURST_ARRAY16 = 5'h08,
  parameter [4:0] CPLX_BURST_ARRAY17 = 5'h09,
  parameter [4:0] CPLX_BURST_ARRAY18 = 5'h0A,
  parameter [4:0] CPLX_BURST_ARRAY19 = 5'h0C,
  parameter [4:0] CPLX_BURST_ARRAY2 = 5'h03,
  parameter [4:0] CPLX_BURST_ARRAY20 = 5'h0D,
  parameter [4:0] CPLX_BURST_ARRAY21 = 5'h0E,
  parameter [4:0] CPLX_BURST_ARRAY22 = 5'h1E,
  parameter [4:0] CPLX_BURST_ARRAY3 = 5'h04,
  parameter [4:0] CPLX_BURST_ARRAY4 = 5'h05,
  parameter [4:0] CPLX_BURST_ARRAY5 = 5'h06,
  parameter [4:0] CPLX_BURST_ARRAY6 = 5'h01,
  parameter [4:0] CPLX_BURST_ARRAY7 = 5'h02,
  parameter [4:0] CPLX_BURST_ARRAY8 = 5'h03,
  parameter [4:0] CPLX_BURST_ARRAY9 = 5'h04,
  parameter [30:0] CPLX_CONFIG = 31'h3B7F8084,
  parameter [24:0] CPLX_CONFIG2 = 25'h10E0480,
  parameter [9:0] CPLX_CONFIG3 = 10'h000,
  parameter [15:0] CPLX_PATTERN0 = 16'hAAAA,
  parameter [15:0] CPLX_PATTERN1 = 16'hCCCC,
  parameter [15:0] CPLX_PATTERN10 = 16'hF8F8,
  parameter [15:0] CPLX_PATTERN100 = 16'hAA31,
  parameter [15:0] CPLX_PATTERN101 = 16'hBF47,
  parameter [15:0] CPLX_PATTERN102 = 16'hF525,
  parameter [15:0] CPLX_PATTERN103 = 16'h549A,
  parameter [15:0] CPLX_PATTERN104 = 16'h007A,
  parameter [15:0] CPLX_PATTERN105 = 16'hAA95,
  parameter [15:0] CPLX_PATTERN106 = 16'hBFDB,
  parameter [15:0] CPLX_PATTERN107 = 16'hF5F0,
  parameter [15:0] CPLX_PATTERN108 = 16'h5421,
  parameter [15:0] CPLX_PATTERN109 = 16'h008A,
  parameter [15:0] CPLX_PATTERN11 = 16'h3E3E,
  parameter [15:0] CPLX_PATTERN110 = 16'hAA25,
  parameter [15:0] CPLX_PATTERN111 = 16'hBF9A,
  parameter [15:0] CPLX_PATTERN112 = 16'hF57A,
  parameter [15:0] CPLX_PATTERN113 = 16'hAABF,
  parameter [15:0] CPLX_PATTERN114 = 16'hA057,
  parameter [15:0] CPLX_PATTERN115 = 16'h026F,
  parameter [15:0] CPLX_PATTERN116 = 16'hAAC0,
  parameter [15:0] CPLX_PATTERN117 = 16'h8084,
  parameter [15:0] CPLX_PATTERN118 = 16'h0A31,
  parameter [15:0] CPLX_PATTERN119 = 16'hAA47,
  parameter [15:0] CPLX_PATTERN12 = 16'h0F0F,
  parameter [15:0] CPLX_PATTERN120 = 16'h0025,
  parameter [15:0] CPLX_PATTERN121 = 16'h2A9A,
  parameter [15:0] CPLX_PATTERN122 = 16'hA87A,
  parameter [15:0] CPLX_PATTERN123 = 16'h0095,
  parameter [15:0] CPLX_PATTERN124 = 16'hAADB,
  parameter [15:0] CPLX_PATTERN125 = 16'hA0F0,
  parameter [15:0] CPLX_PATTERN126 = 16'h0221,
  parameter [15:0] CPLX_PATTERN127 = 16'h5757,
  parameter [15:0] CPLX_PATTERN128 = 16'h6F6F,
  parameter [15:0] CPLX_PATTERN129 = 16'hC0C0,
  parameter [15:0] CPLX_PATTERN13 = 16'h8383,
  parameter [15:0] CPLX_PATTERN130 = 16'h8684,
  parameter [15:0] CPLX_PATTERN131 = 16'h2831,
  parameter [15:0] CPLX_PATTERN132 = 16'hE447,
  parameter [15:0] CPLX_PATTERN133 = 16'hB325,
  parameter [15:0] CPLX_PATTERN134 = 16'h4F9B,
  parameter [15:0] CPLX_PATTERN135 = 16'hB555,
  parameter [15:0] CPLX_PATTERN136 = 16'hB555,
  parameter [15:0] CPLX_PATTERN137 = 16'h8798,
  parameter [15:0] CPLX_PATTERN138 = 16'hE31C,
  parameter [15:0] CPLX_PATTERN139 = 16'h0AF5,
  parameter [15:0] CPLX_PATTERN14 = 16'hE0E0,
  parameter [15:0] CPLX_PATTERN140 = 16'hD42B,
  parameter [15:0] CPLX_PATTERN141 = 16'h48B7,
  parameter [15:0] CPLX_PATTERN142 = 16'h1FE0,
  parameter [15:0] CPLX_PATTERN143 = 16'hBC43,
  parameter [15:0] CPLX_PATTERN144 = 16'h8F14,
  parameter [15:0] CPLX_PATTERN145 = 16'hB44B,
  parameter [15:0] CPLX_PATTERN146 = 16'hCB34,
  parameter [15:0] CPLX_PATTERN147 = 16'h0AF5,
  parameter [15:0] CPLX_PATTERN148 = 16'h8000,
  parameter [15:0] CPLX_PATTERN149 = 16'h0000,
  parameter [15:0] CPLX_PATTERN15 = 16'hFCFC,
  parameter [15:0] CPLX_PATTERN150 = 16'h5555,
  parameter [15:0] CPLX_PATTERN151 = 16'h5555,
  parameter [15:0] CPLX_PATTERN152 = 16'h0000,
  parameter [15:0] CPLX_PATTERN153 = 16'h0000,
  parameter [15:0] CPLX_PATTERN154 = 16'h552A,
  parameter [15:0] CPLX_PATTERN155 = 16'h55AA,
  parameter [15:0] CPLX_PATTERN156 = 16'h0080,
  parameter [15:0] CPLX_PATTERN16 = 16'h0F0F,
  parameter [15:0] CPLX_PATTERN17 = 16'hC0C0,
  parameter [15:0] CPLX_PATTERN18 = 16'hFCFC,
  parameter [15:0] CPLX_PATTERN19 = 16'h0F0F,
  parameter [15:0] CPLX_PATTERN2 = 16'hCCCC,
  parameter [15:0] CPLX_PATTERN20 = 16'hC0C0,
  parameter [15:0] CPLX_PATTERN21 = 16'hAA55,
  parameter [15:0] CPLX_PATTERN22 = 16'hCC33,
  parameter [15:0] CPLX_PATTERN23 = 16'hCC33,
  parameter [15:0] CPLX_PATTERN24 = 16'hE31C,
  parameter [15:0] CPLX_PATTERN25 = 16'hFE71,
  parameter [15:0] CPLX_PATTERN26 = 16'h38C7,
  parameter [15:0] CPLX_PATTERN27 = 16'hF00F,
  parameter [15:0] CPLX_PATTERN28 = 16'hF00F,
  parameter [15:0] CPLX_PATTERN29 = 16'hF00F,
  parameter [15:0] CPLX_PATTERN3 = 16'hE3E3,
  parameter [15:0] CPLX_PATTERN30 = 16'hF00F,
  parameter [15:0] CPLX_PATTERN31 = 16'hF807,
  parameter [15:0] CPLX_PATTERN32 = 16'h3EC1,
  parameter [15:0] CPLX_PATTERN33 = 16'h0FF0,
  parameter [15:0] CPLX_PATTERN34 = 16'h837C,
  parameter [15:0] CPLX_PATTERN35 = 16'hE01F,
  parameter [15:0] CPLX_PATTERN36 = 16'hFC03,
  parameter [15:0] CPLX_PATTERN37 = 16'h0FF0,
  parameter [15:0] CPLX_PATTERN38 = 16'hC03F,
  parameter [15:0] CPLX_PATTERN39 = 16'hFC03,
  parameter [15:0] CPLX_PATTERN4 = 16'h8E8E,
  parameter [15:0] CPLX_PATTERN40 = 16'h0FF0,
  parameter [15:0] CPLX_PATTERN41 = 16'hC03F,
  parameter [15:0] CPLX_PATTERN42 = 16'hB457,
  parameter [15:0] CPLX_PATTERN43 = 16'hB46F,
  parameter [15:0] CPLX_PATTERN44 = 16'hB4C0,
  parameter [15:0] CPLX_PATTERN45 = 16'hA284,
  parameter [15:0] CPLX_PATTERN46 = 16'h8A31,
  parameter [15:0] CPLX_PATTERN47 = 16'h2847,
  parameter [15:0] CPLX_PATTERN48 = 16'hA225,
  parameter [15:0] CPLX_PATTERN49 = 16'hAF9A,
  parameter [15:0] CPLX_PATTERN5 = 16'h3838,
  parameter [15:0] CPLX_PATTERN50 = 16'h507A,
  parameter [15:0] CPLX_PATTERN51 = 16'hAF95,
  parameter [15:0] CPLX_PATTERN52 = 16'h50DB,
  parameter [15:0] CPLX_PATTERN53 = 16'hAFF0,
  parameter [15:0] CPLX_PATTERN54 = 16'hA821,
  parameter [15:0] CPLX_PATTERN55 = 16'h2A8A,
  parameter [15:0] CPLX_PATTERN56 = 16'h0A25,
  parameter [15:0] CPLX_PATTERN57 = 16'h829A,
  parameter [15:0] CPLX_PATTERN58 = 16'hA07A,
  parameter [15:0] CPLX_PATTERN59 = 16'hA8BF,
  parameter [15:0] CPLX_PATTERN6 = 16'hF0F0,
  parameter [15:0] CPLX_PATTERN60 = 16'h2A57,
  parameter [15:0] CPLX_PATTERN61 = 16'hAB6F,
  parameter [15:0] CPLX_PATTERN62 = 16'hF5C0,
  parameter [15:0] CPLX_PATTERN63 = 16'h4084,
  parameter [15:0] CPLX_PATTERN64 = 16'hAB31,
  parameter [15:0] CPLX_PATTERN65 = 16'hF547,
  parameter [15:0] CPLX_PATTERN66 = 16'h4025,
  parameter [15:0] CPLX_PATTERN67 = 16'hAB9A,
  parameter [15:0] CPLX_PATTERN68 = 16'hF57A,
  parameter [15:0] CPLX_PATTERN69 = 16'hAA95,
  parameter [15:0] CPLX_PATTERN7 = 16'hF0F0,
  parameter [15:0] CPLX_PATTERN70 = 16'h02DB,
  parameter [15:0] CPLX_PATTERN71 = 16'hA8F0,
  parameter [15:0] CPLX_PATTERN72 = 16'h0A21,
  parameter [15:0] CPLX_PATTERN73 = 16'hA08A,
  parameter [15:0] CPLX_PATTERN74 = 16'h2A25,
  parameter [15:0] CPLX_PATTERN75 = 16'h809A,
  parameter [15:0] CPLX_PATTERN76 = 16'hAA7A,
  parameter [15:0] CPLX_PATTERN77 = 16'h02BF,
  parameter [15:0] CPLX_PATTERN78 = 16'hAA57,
  parameter [15:0] CPLX_PATTERN79 = 16'hFF6F,
  parameter [15:0] CPLX_PATTERN8 = 16'hF0F0,
  parameter [15:0] CPLX_PATTERN80 = 16'h55C0,
  parameter [15:0] CPLX_PATTERN81 = 16'h0084,
  parameter [15:0] CPLX_PATTERN82 = 16'hAA31,
  parameter [15:0] CPLX_PATTERN83 = 16'hFF47,
  parameter [15:0] CPLX_PATTERN84 = 16'h5525,
  parameter [15:0] CPLX_PATTERN85 = 16'h009A,
  parameter [15:0] CPLX_PATTERN86 = 16'hAA7A,
  parameter [15:0] CPLX_PATTERN87 = 16'hFF95,
  parameter [15:0] CPLX_PATTERN88 = 16'hAADB,
  parameter [15:0] CPLX_PATTERN89 = 16'h80F0,
  parameter [15:0] CPLX_PATTERN9 = 16'hF0F0,
  parameter [15:0] CPLX_PATTERN90 = 16'h2A21,
  parameter [15:0] CPLX_PATTERN91 = 16'hA08A,
  parameter [15:0] CPLX_PATTERN92 = 16'h0A25,
  parameter [15:0] CPLX_PATTERN93 = 16'hA89A,
  parameter [15:0] CPLX_PATTERN94 = 16'h027A,
  parameter [15:0] CPLX_PATTERN95 = 16'hAABF,
  parameter [15:0] CPLX_PATTERN96 = 16'h0057,
  parameter [15:0] CPLX_PATTERN97 = 16'hAA6F,
  parameter [15:0] CPLX_PATTERN98 = 16'h80C0,
  parameter [15:0] CPLX_PATTERN99 = 16'h2A84,
  parameter [2:0] DBG_TRIGGER = 3'h0,
  parameter [11:0] DC_CMD_CREDITS = 12'h2A8,
  parameter [9:0] DEFAULT_PATTERN = 10'h0A5,
  parameter [8:0] EXMON_CLR_EXE = 9'h100,
  parameter [6:0] FIFO_RDEN = 7'h00,
  parameter [17:0] PHY_RANK_READ_OVERRIDE = 18'h00000,
  parameter [17:0] PHY_RANK_WRITE_OVERRIDE = 18'h00000,
  parameter [6:0] PHY_RDEN0 = 7'h05,
  parameter [6:0] PHY_RDEN1 = 7'h05,
  parameter [6:0] PHY_RDEN10 = 7'h05,
  parameter [6:0] PHY_RDEN11 = 7'h05,
  parameter [6:0] PHY_RDEN12 = 7'h05,
  parameter [6:0] PHY_RDEN13 = 7'h05,
  parameter [6:0] PHY_RDEN14 = 7'h05,
  parameter [6:0] PHY_RDEN15 = 7'h05,
  parameter [6:0] PHY_RDEN16 = 7'h05,
  parameter [6:0] PHY_RDEN17 = 7'h05,
  parameter [6:0] PHY_RDEN18 = 7'h05,
  parameter [6:0] PHY_RDEN19 = 7'h05,
  parameter [6:0] PHY_RDEN2 = 7'h05,
  parameter [6:0] PHY_RDEN20 = 7'h05,
  parameter [6:0] PHY_RDEN21 = 7'h05,
  parameter [6:0] PHY_RDEN22 = 7'h05,
  parameter [6:0] PHY_RDEN23 = 7'h05,
  parameter [6:0] PHY_RDEN24 = 7'h05,
  parameter [6:0] PHY_RDEN25 = 7'h05,
  parameter [6:0] PHY_RDEN26 = 7'h05,
  parameter [6:0] PHY_RDEN3 = 7'h05,
  parameter [6:0] PHY_RDEN4 = 7'h05,
  parameter [6:0] PHY_RDEN5 = 7'h05,
  parameter [6:0] PHY_RDEN6 = 7'h05,
  parameter [6:0] PHY_RDEN7 = 7'h05,
  parameter [6:0] PHY_RDEN8 = 7'h05,
  parameter [6:0] PHY_RDEN9 = 7'h05,
  parameter [31:0] PRBS_CNT = 32'h00020004,
  parameter [16:0] PRBS_CONFIG = 17'h08244,
  parameter [17:0] PRBS_CONFIG2 = 18'h00000,
  parameter [22:0] PRBS_SEED0 = 23'h000001,
  parameter [22:0] PRBS_SEED1 = 23'h000002,
  parameter [22:0] PRBS_SEED2 = 23'h000004,
  parameter [22:0] PRBS_SEED3 = 23'h000008,
  parameter [22:0] PRBS_SEED4 = 23'h000010,
  parameter [22:0] PRBS_SEED5 = 23'h000020,
  parameter [22:0] PRBS_SEED6 = 23'h000040,
  parameter [22:0] PRBS_SEED7 = 23'h000080,
  parameter [22:0] PRBS_SEED8 = 23'h000100,
  parameter [7:0] RAM_SETTING_RF2PHS = 8'h12,
  parameter [6:0] RAM_SETTING_RFSPHD = 7'h0A,
  parameter [6:0] RAM_SETTING_SRSPHD = 7'h0A,
  parameter real READ_BANDWIDTH = 6400.000,
  parameter [19:0] REG_ADEC0 = 20'h00000,
  parameter [19:0] REG_ADEC1 = 20'h00000,
  parameter [29:0] REG_ADEC10 = 30'h00000000,
  parameter [23:0] REG_ADEC11 = 24'h000000,
  parameter [20:0] REG_ADEC2 = 21'h100000,
  parameter [19:0] REG_ADEC3 = 20'h00000,
  parameter [29:0] REG_ADEC4 = 30'h00000000,
  parameter [29:0] REG_ADEC5 = 30'h00000000,
  parameter [29:0] REG_ADEC6 = 30'h00000000,
  parameter [29:0] REG_ADEC7 = 30'h00000000,
  parameter [29:0] REG_ADEC8 = 30'h00000000,
  parameter [29:0] REG_ADEC9 = 30'h00000000,
  parameter [21:0] REG_CMDQ_BER_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_CMDQ_BEW_RATE_CTRL = 22'h3FFC0F,
  parameter [24:0] REG_CMDQ_CTRL0 = 25'h1084210,
  parameter [24:0] REG_CMDQ_CTRL1 = 25'h1084210,
  parameter [21:0] REG_CMDQ_ISR_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_CMDQ_ISW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_CMDQ_LLR_RATE_CTRL = 22'h3FFC0F,
  parameter [26:0] REG_COM_1 = 27'h0020000,
  parameter [26:0] REG_COM_2 = 27'h0020000,
  parameter [17:0] REG_COM_3 = 18'h14410,
  parameter [22:0] REG_CONFIG0 = 23'h400000,
  parameter [2:0] REG_CONFIG1 = 3'h0,
  parameter [30:0] REG_CONFIG2 = 31'h00000000,
  parameter [31:0] REG_CONFIG3 = 32'hFEC9FEC6,
  parameter [22:0] REG_CONFIG4 = 23'h1318A5,
  parameter [12:0] REG_DRAM_ARB = 13'h0910,
  parameter [25:0] REG_MRS_0 = 26'h0200924,
  parameter [31:0] REG_MRS_1 = 32'h92000000,
  parameter [2:0] REG_MRS_2 = 3'h0,
  parameter [7:0] REG_MRS_7 = 8'h28,
  parameter [11:0] REG_NSU0_PORT = 12'h000,
  parameter [11:0] REG_NSU1_PORT = 12'h000,
  parameter [11:0] REG_NSU2_PORT = 12'h000,
  parameter [11:0] REG_NSU3_PORT = 12'h000,
  parameter [22:0] REG_NSU_0_EGR = 23'h643210,
  parameter [26:0] REG_NSU_0_ING = 27'h6432101,
  parameter [27:0] REG_NSU_0_R_EGR = 28'h1010100,
  parameter [19:0] REG_NSU_0_W_EGR = 20'h10100,
  parameter [22:0] REG_NSU_1_EGR = 23'h643210,
  parameter [26:0] REG_NSU_1_ING = 27'h6432101,
  parameter [27:0] REG_NSU_1_R_EGR = 28'h1010100,
  parameter [19:0] REG_NSU_1_W_EGR = 20'h10100,
  parameter [22:0] REG_NSU_2_EGR = 23'h643210,
  parameter [26:0] REG_NSU_2_ING = 27'h6432101,
  parameter [27:0] REG_NSU_2_R_EGR = 28'h1010100,
  parameter [19:0] REG_NSU_2_W_EGR = 20'h10100,
  parameter [22:0] REG_NSU_3_EGR = 23'h643210,
  parameter [26:0] REG_NSU_3_ING = 27'h6432101,
  parameter [27:0] REG_NSU_3_R_EGR = 28'h1010100,
  parameter [19:0] REG_NSU_3_W_EGR = 20'h10100,
  parameter [21:0] REG_P0_BER_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P0_BEW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P0_ISR_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P0_ISW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P0_LLR_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P1_BER_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P1_BEW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P1_ISR_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P1_ISW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P1_LLR_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P2_BER_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P2_BEW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P2_ISR_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P2_ISW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P2_LLR_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P3_BER_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P3_BEW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P3_ISR_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P3_ISW_RATE_CTRL = 22'h3FFC0F,
  parameter [21:0] REG_P3_LLR_RATE_CTRL = 22'h3FFC0F,
  parameter [9:0] REG_PINOUT = 10'h000,
  parameter [19:0] REG_PT_CONFIG = 20'h00401,
  parameter [27:0] REG_QOS0 = 28'h00F00F0,
  parameter [29:0] REG_QOS1 = 30'h00200804,
  parameter [19:0] REG_QOS2 = 20'h00802,
  parameter [24:0] REG_QOS_RATE_CTRL_SCALE = 25'h0000000,
  parameter [24:0] REG_QOS_TIMEOUT0 = 25'h1084210,
  parameter [31:0] REG_QOS_TIMEOUT1 = 32'hFFFFFFFF,
  parameter [7:0] REG_QOS_TIMEOUT2 = 8'hFF,
  parameter [24:0] REG_RATE_CTRL_SCALE = 25'h0000000,
  parameter [29:0] REG_RD_CONFIG = 30'h10010010,
  parameter [23:0] REG_RD_DRR_TKN_P0 = 24'h040404,
  parameter [23:0] REG_RD_DRR_TKN_P1 = 24'h040404,
  parameter [23:0] REG_RD_DRR_TKN_P2 = 24'h040404,
  parameter [23:0] REG_RD_DRR_TKN_P3 = 24'h040404,
  parameter [1:0] REG_REF_0 = 2'h0,
  parameter [31:0] REG_REF_1 = 32'h05100080,
  parameter [1:0] REG_REF_2 = 2'h0,
  parameter [15:0] REG_REF_3 = 16'hC002,
  parameter [28:0] REG_RETRY_0 = 29'h0A2B604C,
  parameter [29:0] REG_RETRY_1 = 30'h14528140,
  parameter [31:0] REG_SAFE_CONFIG0 = 32'h0A310304,
  parameter [31:0] REG_SAFE_CONFIG1 = 32'h40C20308,
  parameter [31:0] REG_SAFE_CONFIG2 = 32'h4181F3D0,
  parameter [27:0] REG_SAFE_CONFIG3 = 28'h1018912,
  parameter [30:0] REG_SAFE_CONFIG4 = 31'h1A00610F,
  parameter [31:0] REG_SAFE_CONFIG5 = 32'h04101012,
  parameter [25:0] REG_SAFE_CONFIG6 = 26'h0C80800,
  parameter [29:0] REG_SAFE_CONFIG7 = 30'h00040200,
  parameter [31:0] REG_SAFE_CONFIG8 = 32'h00002000,
  parameter [31:0] REG_SCRUB0 = 32'hFF408281,
  parameter [31:0] REG_SCRUB1 = 32'hFF000001,
  parameter [1:0] REG_SCRUB8 = 2'h0,
  parameter [0:0] REG_SCRUB9 = 1'h0,
  parameter [19:0] REG_TXN_CONFIG = 20'h10500,
  parameter [31:0] REG_WR_CONFIG = 32'h05000500,
  parameter [15:0] REG_WR_DRR_TKN_P0 = 16'h0404,
  parameter [15:0] REG_WR_DRR_TKN_P1 = 16'h0404,
  parameter [15:0] REG_WR_DRR_TKN_P2 = 16'h0404,
  parameter [15:0] REG_WR_DRR_TKN_P3 = 16'h0404,
  parameter [0:0] SEQ_ADDR_DEFAULT = 1'h0,
  parameter [0:0] SEQ_BA_DEFAULT = 1'h0,
  parameter [0:0] SEQ_BG_DEFAULT = 1'h0,
  parameter [0:0] SEQ_CBIT_DEFAULT = 1'h0,
  parameter [15:0] SEQ_CK_CAL = 16'hF0F0,
  parameter [6:0] SEQ_CMD_DEFAULT = 7'h00,
  parameter [6:0] SEQ_CMD_POR = 7'h00,
  parameter [2:0] SEQ_DQS_DEFAULT = 3'h0,
  parameter [4:0] SEQ_DQ_DEFAULT = 5'h00,
  parameter [27:0] SEQ_INIT_ADDR0 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR1 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR10 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR11 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR12 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR13 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR14 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR15 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR16 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR17 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR18 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR19 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR2 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR20 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR21 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR22 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR23 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR24 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR25 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR26 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR27 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR28 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR29 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR3 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR30 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR31 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR32 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR33 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR34 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR35 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR36 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR37 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR38 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR39 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR4 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR40 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR41 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR42 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR43 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR44 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR45 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR46 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR47 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR48 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR49 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR5 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR50 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR51 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR52 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR53 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR54 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR55 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR56 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR57 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR58 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR59 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR6 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR60 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR61 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR62 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR63 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR64 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR65 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR66 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR67 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR68 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR69 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR7 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR70 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR71 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR72 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR73 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR74 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR75 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR76 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR77 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR78 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR79 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR8 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR80 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR81 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR82 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR83 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR84 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR85 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR86 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR87 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR88 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR89 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR9 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR90 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR91 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR92 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR93 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR94 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR95 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR96 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR97 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR98 = 28'h0000000,
  parameter [27:0] SEQ_INIT_ADDR99 = 28'h0000000,
  parameter [31:0] SEQ_INIT_CMD0 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD1 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD10 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD11 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD12 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD13 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD14 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD15 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD16 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD17 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD18 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD19 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD2 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD20 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD21 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD22 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD23 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD24 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD25 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD26 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD27 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD28 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD29 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD3 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD30 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD31 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD32 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD33 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD34 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD35 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD36 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD37 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD38 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD39 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD4 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD40 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD41 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD42 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD43 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD44 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD45 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD46 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD47 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD48 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD49 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD5 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD50 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD51 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD52 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD53 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD54 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD55 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD56 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD57 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD58 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD59 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD6 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD60 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD61 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD62 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD63 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD64 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD65 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD66 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD67 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD68 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD69 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD7 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD70 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD71 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD72 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD73 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD74 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD75 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD76 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD77 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD78 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD79 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD8 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD80 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD81 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD82 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD83 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD84 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD85 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD86 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD87 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD88 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD89 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD9 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD90 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD91 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD92 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD93 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD94 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD95 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD96 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD97 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD98 = 32'h00000000,
  parameter [31:0] SEQ_INIT_CMD99 = 32'h00000000,
  parameter [8:0] SEQ_INIT_CMD_SET = 9'h000,
  parameter [6:0] SEQ_INIT_CMD_VALID = 7'h00,
  parameter [9:0] SEQ_INIT_CNTRL0 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL1 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL10 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL11 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL12 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL13 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL14 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL15 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL16 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL17 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL18 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL19 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL2 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL20 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL21 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL22 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL23 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL24 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL25 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL26 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL27 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL28 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL29 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL3 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL30 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL31 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL32 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL33 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL34 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL35 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL36 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL37 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL38 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL39 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL4 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL40 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL41 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL42 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL43 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL44 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL45 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL46 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL47 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL48 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL49 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL5 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL50 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL51 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL52 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL53 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL54 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL55 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL56 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL57 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL58 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL59 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL6 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL60 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL61 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL62 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL63 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL64 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL65 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL66 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL67 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL68 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL69 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL7 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL70 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL71 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL72 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL73 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL74 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL75 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL76 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL77 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL78 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL79 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL8 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL80 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL81 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL82 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL83 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL84 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL85 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL86 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL87 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL88 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL89 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL9 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL90 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL91 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL92 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL93 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL94 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL95 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL96 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL97 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL98 = 10'h000,
  parameter [9:0] SEQ_INIT_CNTRL99 = 10'h000,
  parameter [16:0] SEQ_INIT_CONFIG = 17'h0F0F0,
  parameter [2:0] SEQ_MODE = 3'h0,
  parameter [25:0] TXNQ_RD_PRIORITY = 26'h0101010,
  parameter [24:0] TXNQ_WR_PRIORITY = 25'h0101010,
  parameter [0:0] T_TXBIT = 1'h1,
  parameter [1:0] UB_CLK_MUX = 2'h0,
  parameter real WRITE_BANDWIDTH = 6400.000,
  parameter [4:0] XMPU_CONFIG0 = 5'h08,
  parameter [4:0] XMPU_CONFIG1 = 5'h08,
  parameter [4:0] XMPU_CONFIG10 = 5'h08,
  parameter [4:0] XMPU_CONFIG11 = 5'h08,
  parameter [4:0] XMPU_CONFIG12 = 5'h08,
  parameter [4:0] XMPU_CONFIG13 = 5'h08,
  parameter [4:0] XMPU_CONFIG14 = 5'h08,
  parameter [4:0] XMPU_CONFIG15 = 5'h08,
  parameter [4:0] XMPU_CONFIG2 = 5'h08,
  parameter [4:0] XMPU_CONFIG3 = 5'h08,
  parameter [4:0] XMPU_CONFIG4 = 5'h08,
  parameter [4:0] XMPU_CONFIG5 = 5'h08,
  parameter [4:0] XMPU_CONFIG6 = 5'h08,
  parameter [4:0] XMPU_CONFIG7 = 5'h08,
  parameter [4:0] XMPU_CONFIG8 = 5'h08,
  parameter [4:0] XMPU_CONFIG9 = 5'h08,
  parameter [3:0] XMPU_CTRL = 4'hB,
  parameter [15:0] XMPU_END_HI0 = 16'h0000,
  parameter [15:0] XMPU_END_HI1 = 16'h0000,
  parameter [15:0] XMPU_END_HI10 = 16'h0000,
  parameter [15:0] XMPU_END_HI11 = 16'h0000,
  parameter [15:0] XMPU_END_HI12 = 16'h0000,
  parameter [15:0] XMPU_END_HI13 = 16'h0000,
  parameter [15:0] XMPU_END_HI14 = 16'h0000,
  parameter [15:0] XMPU_END_HI15 = 16'h0000,
  parameter [15:0] XMPU_END_HI2 = 16'h0000,
  parameter [15:0] XMPU_END_HI3 = 16'h0000,
  parameter [15:0] XMPU_END_HI4 = 16'h0000,
  parameter [15:0] XMPU_END_HI5 = 16'h0000,
  parameter [15:0] XMPU_END_HI6 = 16'h0000,
  parameter [15:0] XMPU_END_HI7 = 16'h0000,
  parameter [15:0] XMPU_END_HI8 = 16'h0000,
  parameter [15:0] XMPU_END_HI9 = 16'h0000,
  parameter [31:0] XMPU_END_LO0 = 32'h00000000,
  parameter [31:0] XMPU_END_LO1 = 32'h00000000,
  parameter [31:0] XMPU_END_LO10 = 32'h00000000,
  parameter [31:0] XMPU_END_LO11 = 32'h00000000,
  parameter [31:0] XMPU_END_LO12 = 32'h00000000,
  parameter [31:0] XMPU_END_LO13 = 32'h00000000,
  parameter [31:0] XMPU_END_LO14 = 32'h00000000,
  parameter [31:0] XMPU_END_LO15 = 32'h00000000,
  parameter [31:0] XMPU_END_LO2 = 32'h00000000,
  parameter [31:0] XMPU_END_LO3 = 32'h00000000,
  parameter [31:0] XMPU_END_LO4 = 32'h00000000,
  parameter [31:0] XMPU_END_LO5 = 32'h00000000,
  parameter [31:0] XMPU_END_LO6 = 32'h00000000,
  parameter [31:0] XMPU_END_LO7 = 32'h00000000,
  parameter [31:0] XMPU_END_LO8 = 32'h00000000,
  parameter [31:0] XMPU_END_LO9 = 32'h00000000,
  parameter [25:0] XMPU_MASTER0 = 26'h0000000,
  parameter [25:0] XMPU_MASTER1 = 26'h0000000,
  parameter [25:0] XMPU_MASTER10 = 26'h0000000,
  parameter [25:0] XMPU_MASTER11 = 26'h0000000,
  parameter [25:0] XMPU_MASTER12 = 26'h0000000,
  parameter [25:0] XMPU_MASTER13 = 26'h0000000,
  parameter [25:0] XMPU_MASTER14 = 26'h0000000,
  parameter [25:0] XMPU_MASTER15 = 26'h0000000,
  parameter [25:0] XMPU_MASTER2 = 26'h0000000,
  parameter [25:0] XMPU_MASTER3 = 26'h0000000,
  parameter [25:0] XMPU_MASTER4 = 26'h0000000,
  parameter [25:0] XMPU_MASTER5 = 26'h0000000,
  parameter [25:0] XMPU_MASTER6 = 26'h0000000,
  parameter [25:0] XMPU_MASTER7 = 26'h0000000,
  parameter [25:0] XMPU_MASTER8 = 26'h0000000,
  parameter [25:0] XMPU_MASTER9 = 26'h0000000,
  parameter [15:0] XMPU_START_HI0 = 16'h0000,
  parameter [15:0] XMPU_START_HI1 = 16'h0000,
  parameter [15:0] XMPU_START_HI10 = 16'h0000,
  parameter [15:0] XMPU_START_HI11 = 16'h0000,
  parameter [15:0] XMPU_START_HI12 = 16'h0000,
  parameter [15:0] XMPU_START_HI13 = 16'h0000,
  parameter [15:0] XMPU_START_HI14 = 16'h0000,
  parameter [15:0] XMPU_START_HI15 = 16'h0000,
  parameter [15:0] XMPU_START_HI2 = 16'h0000,
  parameter [15:0] XMPU_START_HI3 = 16'h0000,
  parameter [15:0] XMPU_START_HI4 = 16'h0000,
  parameter [15:0] XMPU_START_HI5 = 16'h0000,
  parameter [15:0] XMPU_START_HI6 = 16'h0000,
  parameter [15:0] XMPU_START_HI7 = 16'h0000,
  parameter [15:0] XMPU_START_HI8 = 16'h0000,
  parameter [15:0] XMPU_START_HI9 = 16'h0000,
  parameter [31:0] XMPU_START_LO0 = 32'h00000000,
  parameter [31:0] XMPU_START_LO1 = 32'h00000000,
  parameter [31:0] XMPU_START_LO10 = 32'h00000000,
  parameter [31:0] XMPU_START_LO11 = 32'h00000000,
  parameter [31:0] XMPU_START_LO12 = 32'h00000000,
  parameter [31:0] XMPU_START_LO13 = 32'h00000000,
  parameter [31:0] XMPU_START_LO14 = 32'h00000000,
  parameter [31:0] XMPU_START_LO15 = 32'h00000000,
  parameter [31:0] XMPU_START_LO2 = 32'h00000000,
  parameter [31:0] XMPU_START_LO3 = 32'h00000000,
  parameter [31:0] XMPU_START_LO4 = 32'h00000000,
  parameter [31:0] XMPU_START_LO5 = 32'h00000000,
  parameter [31:0] XMPU_START_LO6 = 32'h00000000,
  parameter [31:0] XMPU_START_LO7 = 32'h00000000,
  parameter [31:0] XMPU_START_LO8 = 32'h00000000,
  parameter [31:0] XMPU_START_LO9 = 32'h00000000,
  parameter [17:0] XPI_DATA_NIB_CHAN = 18'h00000,
  parameter [7:0] XPI_DQS = 8'h50,
  parameter [26:0] XPI_NIB_CHAN = 27'h0000000,
  parameter [15:0] XPI_OE = 16'h0000,
  parameter [10:0] XPI_OE_ALL_NIB = 11'h408,
  parameter [8:0] XPI_PMI_CONFIG = 9'h0C0,
  parameter [1:0] XPI_READ_DBI = 2'h0,
  parameter [13:0] XPI_READ_OFFSET = 14'h0895,
  parameter [10:0] XPI_WRDATA_ALL_NIB = 11'h408,
  parameter [3:0] XPI_WRITE_DM_DBI = 4'h0,

  parameter TCK                       = 625,
  parameter VERBOSITY_EN              = 32'h0,
  parameter bit EN_NPP_MONITOR        = 1'b0,
  parameter integer DQ_WIDTH          = 64,
  parameter integer DQS_WIDTH         = 8, 
  parameter integer DM_WIDTH          = 8, 
  parameter integer CK_WIDTH          = 1, 
  parameter integer CS_WIDTH          = 1, 
  parameter integer CKE_WIDTH         = 1, 
  parameter integer ADDR_WIDTH        = 17, 
  parameter integer BG_WIDTH          = 1, 
  parameter integer BA_WIDTH          = 2, 
  parameter integer ODT_WIDTH         = 1, 
  parameter integer STACKHEIGHT       = 1, 
  parameter integer LR_WIDTH          = 1, 
  parameter integer NUM_BANKS           = 3, 
  parameter integer NUM_CHANNELS        = 1, 
  parameter ECC_ENABLE                  = "false",
  parameter COMP_WIDTH                  = "x16",
  parameter SIM_DEVICE                  = "VERSAL_AI_CORE_ES1",
  parameter NOC_FREQ                    = 960,
  parameter SDRAM_WL                    = 16,
  parameter SDRAM_RL                    = 22,
  parameter CA_MIRROR                   = 0,
  parameter RCD_DELAY                   = 0,
  parameter SLOT0_CONFIG                = {{(8-CS_WIDTH){1'b0}},{CS_WIDTH{1'b1}}} , // Slot0 Physical configuration
  parameter SLOT1_CONFIG                = 8'b0000_0000, // Slot1 Physical configuration
  parameter SLOT0_FUNC_CS               = {{(8-CS_WIDTH){1'b0}},{CS_WIDTH{1'b1}}}, // Slot0 Functional chipselect
  parameter SLOT1_FUNC_CS               = 8'b0000_0000, // Slot1 Functional chipselect
  parameter DDR4_REG_RC03               = {9'b0_0000_0011, 4'b0000}, // RDIMM register RC03
  parameter DDR4_REG_RC04               = {9'b0_0000_0100, 4'b0000}, // RDIMM register RC04
  parameter DDR4_REG_RC05               = {9'b0_0000_0101, 4'b0000}, // RDIMM register RC05
  parameter DDR4_DB_HIF_RTT_NOM         =  4'b0011, // DDR4 Data Buffer Host I/F DQ RTT_NOM
  parameter DDR4_DB_HIF_RTT_WR          =  4'b0000, // DDR4 Data Buffer Host I/F DQ RTT_WR
  parameter DDR4_DB_HIF_RTT_PARK        =  4'b0000, // DDR4 Data Buffer Host I/F DQ RTT_PARK
  parameter DDR4_DB_HIF_DI              =  4'b0001, // DDR4 Data Buffer Host I/F DQ Driver Impedance
  parameter DDR4_DB_DIF_ODT             =  4'b0011, // DDR4 Data Buffer DRAM I/F MDQ ODT
  parameter DDR4_DB_DIF_DI              =  4'b0000, // DDR4 Data Buffer DRAM I/F MDQ Driver Impedance
  parameter DDR4_DB_HIF_VREF            =  8'b0001_1011, // DDR4 Data Buffer Host I/F VRef
  parameter DDR4_DB_DIF_VREF            =  8'b0001_1011, // DDR4 Data Buffer DRAM I/F VRef

  parameter DDR4_CLAMSHELL              = 0,

  
  parameter XLNX_RESPONDER              = 1
 )
 (
     input                                        from_noc_0
    ,input                                        from_noc_1
    ,input                                        from_noc_2
    ,input                                        from_noc_3
    // Clocking and Reset
    //,input  wire                       sys_clk
    ,input  wire                       sys_clk_p
    ,input  wire                       sys_clk_n
    // NoC Interface
    ,input  [7:0]                      noc2dmc_valid_in_0
  //  ,input                             noc2dmc_valid_in_en_0 all enable signals need to connect it to ground
    ,input  [181:0]       noc2dmc_data_in_0
//    ,input                             noc2dmc_data_in_en_0
    ,output [7:0]                      dmc2noc_credit_rtn_0 //Credit  from NA to NPG 
 //   ,output                            dmc2noc_credit_rtn_en_0 
    ,input                             noc2dmc_credit_rdy_0   //Ready  from NPG to receive Credits
//    ,input [1:0]                       noc2dmc_scan_0
 //   ,input [15:0]                      noc2dmc_dbi_0
   
    ,output logic [7:0]                dmc2noc_valid_out_0
 //   ,output                            dmc2noc_valid_out_en_0
    ,output logic [181:0] dmc2noc_data_out_0
//    ,output                            dmc2noc_data_out_en_0
    ,input  [7:0]                      noc2dmc_credit_rtn_0 //Credit from NPG to NA
 //   ,input                             noc2dmc_credit_rtn_en_0
    ,output logic                      dmc2noc_credit_rdy_0 //Ready from NA to NPG to receive credits 
  //  ,output [1:0]                      dmc2noc_scan_0
  //  ,output [15:0]                     dmc2noc_dbi_0
    
    ,input  [7:0]                      noc2dmc_valid_in_1
//    ,input                             noc2dmc_valid_in_en_1
    ,input  [181:0]       noc2dmc_data_in_1
//    ,input                             noc2dmc_data_in_en_1
    ,output [7:0]                      dmc2noc_credit_rtn_1 //Credit  from NA to NPG 
 //   ,output                            dmc2noc_credit_rtn_en_1 
    ,input                             noc2dmc_credit_rdy_1   //Ready  from NPG to receive Credits
  //  ,input [1:0]                       noc2dmc_scan_1
  //  ,input [15:0]                      noc2dmc_dbi_1
    
    ,output logic [7:0]                dmc2noc_valid_out_1 
  //  ,output                            dmc2noc_valid_out_en_1
    ,output logic [181:0] dmc2noc_data_out_1 
  //  ,output                            dmc2noc_data_out_en_1
    ,input  [7:0]                      noc2dmc_credit_rtn_1 //Credit from NPG to NA
  //  ,input                             noc2dmc_credit_rtn_en_1
    ,output logic                      dmc2noc_credit_rdy_1 //Ready from NA to NPG to receive credits 
  //  ,output [1:0]                      dmc2noc_scan_1
  //  ,output [15:0]                     dmc2noc_dbi_1

    ,input  [7:0]                      noc2dmc_valid_in_2
 //   ,input                             noc2dmc_valid_in_en_2
    ,input  [181:0]       noc2dmc_data_in_2
 //   ,input                             noc2dmc_data_in_en_2
    ,output [7:0]                      dmc2noc_credit_rtn_2 //Credit  from NA to NPG 
  //  ,output                            dmc2noc_credit_rtn_en_2
    ,input                             noc2dmc_credit_rdy_2   //Ready  from NPG to receive Credits
  //  ,input [1:0]                       noc2dmc_scan_2
  //  ,input [15:0]                      noc2dmc_dbi_2
    
    ,output logic [7:0]                dmc2noc_valid_out_2 
 //   ,output                            dmc2noc_valid_out_en_2
    ,output logic [181:0] dmc2noc_data_out_2 
 //   ,output                            dmc2noc_data_out_en_2
    ,input  [7:0]                      noc2dmc_credit_rtn_2 //Credit from NPG to NA
  //  ,input                             noc2dmc_credit_rtn_en_2 
    ,output logic                      dmc2noc_credit_rdy_2 //Ready from NA to NPG to receive credits 
 //   ,output [1:0]                      dmc2noc_scan_2
  //  ,output [15:0]                     dmc2noc_dbi_2
    
    ,input  [7:0]                      noc2dmc_valid_in_3
  //  ,input                             noc2dmc_valid_in_en_3
    ,input  [181:0]       noc2dmc_data_in_3
   // ,input                             noc2dmc_data_in_en_3
    ,output [7:0]                      dmc2noc_credit_rtn_3 //Credit  from NA to NPG 
   // ,output                            dmc2noc_credit_rtn_en_3 
    ,input                             noc2dmc_credit_rdy_3   //Ready  from NPG to receive Credits
  //  ,input [1:0]                       noc2dmc_scan_3
  //  ,input [15:0]                      noc2dmc_dbi_3
    
    ,output logic [7:0]                dmc2noc_valid_out_3 
   // ,output                            dmc2noc_valid_out_en_3
    ,output logic [181:0] dmc2noc_data_out_3 
    //,output                            dmc2noc_data_out_en_3
    ,input  [7:0]                      noc2dmc_credit_rtn_3 //Credit from NPG to NA
  //  ,input                             noc2dmc_credit_rtn_en_3
    ,output logic                      dmc2noc_credit_rdy_3 //Ready from NA to NPG to receive credits 
   // ,output [1:0]                      dmc2noc_scan_3    
   // ,output [15:0]                     dmc2noc_dbi_3

//Refresh & Periodic calibration Interface

    //ddr ports
    ,output wire [ADDR_WIDTH-1 : 0]  ch0_ddr4_adr
    ,output wire [BA_WIDTH-1 : 0]             ch0_ddr4_ba
    ,output wire [BG_WIDTH-1 : 0]             ch0_ddr4_bg
    ,output wire [CKE_WIDTH-1 : 0]     ch0_ddr4_cke
    ,output wire [CK_WIDTH-1 : 0]      ch0_ddr4_ck_t
    ,output wire [CK_WIDTH-1 : 0]      ch0_ddr4_ck_c
    ,output wire [CS_WIDTH-1 : 0]      ch0_ddr4_cs_n
    ,inout wire [DM_WIDTH-1:0]         ch0_ddr4_dm_dbi_n
    ,inout wire [DQ_WIDTH-1:0]       ch0_ddr4_dq
    ,inout wire [DQS_WIDTH-1:0]      ch0_ddr4_dqs_t
    ,inout wire [DQS_WIDTH-1:0]      ch0_ddr4_dqs_c
    ,output wire [ODT_WIDTH-1 : 0]     ch0_ddr4_odt
    ,output wire              ch0_ddr4_reset_n
    ,output wire              ch0_ddr4_act_n

);

   localparam MAX_BANK = 3 ;

  localparam   [8:0]        C_NIBBLE_EN [MAX_BANK-1 :0]                = '{9'b000001111,9'b011111111,9'b111111111};
  localparam   [3:0]        C_IOB_TYPE  [(54*MAX_BANK)-1 :0]           = '{4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0111,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0011,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0011,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0111,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0111,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0011,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0111,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0011,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0011,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0111,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0111,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0011,4'b0000,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0000,4'b0000,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0001,4'b0000,4'b0000,4'b0101,4'b0001,4'b0001,4'b0000,4'b0000,4'b0001,4'b0001,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0111,4'b0011,4'b0011,4'b0011,4'b0011,4'b0001,4'b0011,4'b0011,4'b0011,4'b0011,4'b0011,4'b0000,4'b0111,4'b0011,4'b0011,4'b0011,4'b0011,4'b0001,4'b0011}; 
  localparam   [39:0]       C_CASCADE_0 [(9*MAX_BANK)-1 :0]            = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_CASCADE_1 [(9*MAX_BANK)-1 :0]            = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_CASCADE_2 [(9*MAX_BANK)-1 :0]            = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_CASCADE_3 [(9*MAX_BANK)-1 :0]            = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_CASCADE_4 [(9*MAX_BANK)-1 :0]            = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_CASCADE_5 [(9*MAX_BANK)-1 :0]            = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_CONTINUOUS_DQS [(9*MAX_BANK)-1 :0]       = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_CRSE_DLY_EN [(9*MAX_BANK)-1 :0]          = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [10:0]       C_DELAY_VALUE_0 [(9*MAX_BANK)-1 :0]        = '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}; 
  localparam   [10:0]       C_DELAY_VALUE_1 [(9*MAX_BANK)-1 :0]        = '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}; 
  localparam   [10:0]       C_DELAY_VALUE_2 [(9*MAX_BANK)-1 :0]        = '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}; 
  localparam   [10:0]       C_DELAY_VALUE_3 [(9*MAX_BANK)-1 :0]        = '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}; 
  localparam   [10:0]       C_DELAY_VALUE_4 [(9*MAX_BANK)-1 :0]        = '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}; 
  localparam   [10:0]       C_DELAY_VALUE_5 [(9*MAX_BANK)-1 :0]        = '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}; 
  localparam   [39:0]       C_DIS_IDLY_VT_TRACK [(9*MAX_BANK)-1 :0]    = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_DIS_ODLY_VT_TRACK [(9*MAX_BANK)-1 :0]    = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_DIS_QDLY_VT_TRACK [(9*MAX_BANK)-1 :0]    = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_FAST_CK [(9*MAX_BANK)-1 :0]              = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [8*13:1]     C_DQS_MODE [(9*MAX_BANK)-1 :0]             = '{"DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK"}; 
  localparam   [47:0]       C_DQS_SRC [(9*MAX_BANK)-1 :0]              = '{"EXTERN","EXTERN","EXTERN","EXTERN","EXTERN","LOCAL","EXTERN","EXTERN","LOCAL","EXTERN","LOCAL","EXTERN","LOCAL","EXTERN","EXTERN","LOCAL","LOCAL","EXTERN","EXTERN","EXTERN","EXTERN","EXTERN","EXTERN","LOCAL","EXTERN","LOCAL","EXTERN"}; 
  localparam   [8*7:1]      C_EN_CLK_TO_UPPER [(9*MAX_BANK)-1 :0]      = '{"DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE"}; 
  localparam   [8*7:1]      C_EN_CLK_TO_LOWER [(9*MAX_BANK)-1 :0]      = '{"DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE"}; 
  localparam   [39:0]       C_EN_DYN_DLY_MODE [(9*MAX_BANK)-1 :0]      = '{"FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","TRUE","TRUE","TRUE","FALSE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","TRUE","TRUE","TRUE"}; 
  localparam   [39:0]       C_EN_OTHER_NCLK [(9*MAX_BANK)-1 :0]        = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","TRUE","FALSE","FALSE","FALSE","TRUE","FALSE","TRUE","TRUE","FALSE","FALSE","TRUE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","FALSE","TRUE"}; 
  localparam   [39:0]       C_EN_OTHER_PCLK [(9*MAX_BANK)-1 :0]        = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","TRUE","FALSE","FALSE","FALSE","TRUE","FALSE","TRUE","TRUE","FALSE","FALSE","TRUE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","FALSE","TRUE"}; 
  localparam   [47:0]       C_FIFO_MODE_0 [(9*MAX_BANK)-1 :0]          = '{"ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC"}; 
  localparam   [47:0]       C_FIFO_MODE_1 [(9*MAX_BANK)-1 :0]          = '{"ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC"}; 
  localparam   [47:0]       C_FIFO_MODE_2 [(9*MAX_BANK)-1 :0]          = '{"ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC"}; 
  localparam   [47:0]       C_FIFO_MODE_3 [(9*MAX_BANK)-1 :0]          = '{"ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC"}; 
  localparam   [47:0]       C_FIFO_MODE_4 [(9*MAX_BANK)-1 :0]          = '{"ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC"}; 
  localparam   [47:0]       C_FIFO_MODE_5 [(9*MAX_BANK)-1 :0]          = '{"ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC","ASYNC"}; 
  localparam   [63:0]       C_IBUF_DIS_SRC_0 [(9*MAX_BANK)-1 :0]       = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL"}; 
  localparam   [63:0]       C_IBUF_DIS_SRC_1 [(9*MAX_BANK)-1 :0]       = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL"}; 
  localparam   [63:0]       C_IBUF_DIS_SRC_2 [(9*MAX_BANK)-1 :0]       = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL"}; 
  localparam   [63:0]       C_IBUF_DIS_SRC_3 [(9*MAX_BANK)-1 :0]       = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL"}; 
  localparam   [63:0]       C_IBUF_DIS_SRC_4 [(9*MAX_BANK)-1 :0]       = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL"}; 
  localparam   [63:0]       C_IBUF_DIS_SRC_5 [(9*MAX_BANK)-1 :0]       = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL"}; 
  localparam   [39:0]       C_INV_RXCLK  [(9*MAX_BANK)-1 :0]           = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_LP4_DQS  [(9*MAX_BANK)-1 :0]             = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_ODELAY_BYPASS_0 [(9*MAX_BANK)-1 :0]      = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_ODELAY_BYPASS_1 [(9*MAX_BANK)-1 :0]      = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_ODELAY_BYPASS_2 [(9*MAX_BANK)-1 :0]      = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_ODELAY_BYPASS_3 [(9*MAX_BANK)-1 :0]      = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_ODELAY_BYPASS_4 [(9*MAX_BANK)-1 :0]      = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_ODELAY_BYPASS_5 [(9*MAX_BANK)-1 :0]      = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [63:0]       C_ODT_SRC_0  [(9*MAX_BANK)-1 :0]           = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL"}; 
  localparam   [63:0]       C_ODT_SRC_1  [(9*MAX_BANK)-1 :0]           = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","INTERNAL","EXTERNAL","EXTERNAL","INTERNAL","EXTERNAL","INTERNAL","EXTERNAL","INTERNAL","EXTERNAL","EXTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL"}; 
  localparam   [63:0]       C_ODT_SRC_2  [(9*MAX_BANK)-1 :0]           = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","EXTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL"}; 
  localparam   [63:0]       C_ODT_SRC_3  [(9*MAX_BANK)-1 :0]           = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL"}; 
  localparam   [63:0]       C_ODT_SRC_4  [(9*MAX_BANK)-1 :0]           = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL"}; 
  localparam   [63:0]       C_ODT_SRC_5  [(9*MAX_BANK)-1 :0]           = '{"EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","EXTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL","INTERNAL"}; 
  localparam   [63:0]       C_REFCLK_FREQUENCY  [(9*MAX_BANK)-1 :0]    = '{200.00,200.00,200.00,200.00,200.00,3200.0,3200.0,3200.0,3200.0,200.00,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0,3200.0}; 
  localparam   [63:0]       C_RX_CLK_PHASE_N [(9*MAX_BANK)-1 :0]       = '{"SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_0","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90"}; 
  localparam   [63:0]       C_RX_CLK_PHASE_P [(9*MAX_BANK)-1 :0]       = '{"SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_0","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_0","SHIFT_90","SHIFT_90","SHIFT_90","SHIFT_90"}; 
  localparam   [3:0]        C_RX_DATA_WIDTH [(9*MAX_BANK)-1 :0]        = '{8,8,8,8,8,4,4,4,4,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4}; 
  localparam   [8*7:1]      C_RX_GATING [(9*MAX_BANK)-1 :0]            = '{"DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","ENABLE","ENABLE","ENABLE","ENABLE","DISABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","ENABLE","ENABLE","ENABLE","ENABLE"}; 
  localparam   [8*7:1]      C_SELF_CALIBRATE [(9*MAX_BANK)-1 :0]       = '{"ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE"};
  localparam   [39:0]       C_SERIAL_MODE [(9*MAX_BANK)-1 :0]          = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [63:0]       C_TBYTE_CTL_0  [(9*MAX_BANK)-1 :0]         = '{"T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN"}; 
  localparam   [63:0]       C_TBYTE_CTL_1  [(9*MAX_BANK)-1 :0]         = '{"T","T","T","T","T","PHY_WREN","T","T","PHY_WREN","T","PHY_WREN","T","PHY_WREN","T","T","PHY_WREN","PHY_WREN","T","T","T","T","T","T","PHY_WREN","T","PHY_WREN","T"}; 
  localparam   [63:0]       C_TBYTE_CTL_2  [(9*MAX_BANK)-1 :0]         = '{"T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN"}; 
  localparam   [63:0]       C_TBYTE_CTL_3  [(9*MAX_BANK)-1 :0]         = '{"T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN"}; 
  localparam   [63:0]       C_TBYTE_CTL_4  [(9*MAX_BANK)-1 :0]         = '{"T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN"}; 
  localparam   [63:0]       C_TBYTE_CTL_5  [(9*MAX_BANK)-1 :0]         = '{"T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN","T","T","T","T","T","PHY_WREN","PHY_WREN","PHY_WREN","PHY_WREN"}; 
  localparam   [39:0]       C_TXRX_LOOPBACK_0  [(9*MAX_BANK)-1 :0]     = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_TXRX_LOOPBACK_1  [(9*MAX_BANK)-1 :0]     = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_TXRX_LOOPBACK_2  [(9*MAX_BANK)-1 :0]     = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_TXRX_LOOPBACK_3  [(9*MAX_BANK)-1 :0]     = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_TXRX_LOOPBACK_4  [(9*MAX_BANK)-1 :0]     = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_TXRX_LOOPBACK_5  [(9*MAX_BANK)-1 :0]     = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [3:0]        C_TX_DATA_WIDTH [(9*MAX_BANK)-1 :0]        = '{8,8,8,8,8,4,4,4,4,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4}; 
  localparam   [8*7:1]      C_TX_GATING [(9*MAX_BANK)-1 :0]            = '{"DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","ENABLE","ENABLE","ENABLE","ENABLE","DISABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","ENABLE","DISABLE","DISABLE","DISABLE","DISABLE","DISABLE","ENABLE","ENABLE","ENABLE","ENABLE"}; 
  localparam   [0:0]        C_TX_INIT_TRI [(9*MAX_BANK)-1 :0]          = '{1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}; 
  localparam   [0:0]        C_TX_INIT_0  [(9*MAX_BANK)-1 :0]              = '{1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}; 
  localparam   [0:0]        C_TX_INIT_1  [(9*MAX_BANK)-1 :0]              = '{1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}; 
  localparam   [0:0]        C_TX_INIT_2  [(9*MAX_BANK)-1 :0]              = '{1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}; 
  localparam   [0:0]        C_TX_INIT_3  [(9*MAX_BANK)-1 :0]              = '{1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}; 
  localparam   [0:0]        C_TX_INIT_4  [(9*MAX_BANK)-1 :0]              = '{1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}; 
  localparam   [0:0]        C_TX_INIT_5  [(9*MAX_BANK)-1 :0]              = '{1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}; 
  localparam   [0:0]        C_PRIME_VAL  [(9*MAX_BANK)-1 :0]              = '{1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}; 
  localparam   [39:0]       C_TX_OUTPUT_PHASE_90_0  [(9*MAX_BANK)-1 :0]   = '{"FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","FALSE","FALSE","TRUE","FALSE","TRUE","FALSE","TRUE","FALSE","FALSE","TRUE","TRUE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","FALSE","TRUE","FALSE"}; 
  localparam   [39:0]       C_TX_OUTPUT_PHASE_90_1  [(9*MAX_BANK)-1 :0]   = '{"FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","FALSE","FALSE","TRUE","FALSE","TRUE","FALSE","TRUE","FALSE","FALSE","TRUE","TRUE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","FALSE","TRUE","FALSE"}; 
  localparam   [39:0]       C_TX_OUTPUT_PHASE_90_2  [(9*MAX_BANK)-1 :0]   = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_TX_OUTPUT_PHASE_90_3  [(9*MAX_BANK)-1 :0]   = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_TX_OUTPUT_PHASE_90_4  [(9*MAX_BANK)-1 :0]   = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"}; 
  localparam   [39:0]       C_TX_OUTPUT_PHASE_90_5  [(9*MAX_BANK)-1 :0]   = '{"FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE","FALSE"};
  localparam   [39:0]       C_TX_OUTPUT_PHASE_90_TRI [(9*MAX_BANK)-1 :0]  = '{"FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","TRUE","TRUE","TRUE","FALSE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","TRUE","TRUE","TRUE"};
  localparam   [39:0]       C_WRITE_LEVELING [(9*MAX_BANK)-1 :0]          = '{"FALSE","FALSE","FALSE","FALSE","FALSE","TRUE","TRUE","TRUE","TRUE","FALSE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE","TRUE"};
  localparam   [47:0]       C_VREF_FABRIC [(9*MAX_BANK)-1 :0]             = '{"MEMCEL","MEMCEL","MEMCEL","MEMCEL","MEMCEL","RIU","RIU","RIU","RIU","MEMCEL","RIU","RIU","RIU","RIU","RIU","RIU","RIU","RIU","MEMCEL","MEMCEL","MEMCEL","MEMCEL","MEMCEL","RIU","RIU","RIU","RIU"};
  localparam   [63:0]       C_ISTANDARD [(9*MAX_BANK)-1 :0]               = '{"UNUSED","UNUSED","UNUSED","UNUSED","UNUSED","POD12","POD12","POD12","POD12","UNUSED","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12","POD12"};
  localparam                C_VREF_NIB                                                          = "VREF_RIU";

  localparam XPLL_F0_CLKFBOUT_MULT       = 16 ;
  localparam XPLL_F0_CLKOUT1_DIVIDE      = 4 ;
  localparam XPLL_F0_DIVCLK_DIVIDE       = 1 ;
  localparam XPLL_F0_CLKOUTPHY_DIVIDE    = "DIV1" ;
  localparam real XPLL_F0_INPUT_CLK           = 5.000 ;
  localparam real XPLL_F0_PLL0_CLKOUT0        = 1.250 ;
  localparam CLKFBOUT_MULT_PLL_SLAVE     =  8 ;
  localparam CLKOUTPHY_DIVIDE_PLL_SLAVE  = "DIV1" ;
  localparam DIVCLK_DIVIDE_PLL_SLAVE     = 2; 

  localparam XPLL_CLKOUT1_PH_CTRL  = 'h3 ;
  localparam XPLL_CLKOUT2_PH_CTRL  = 'h1 ;
  localparam XPLL_DSKW_DLY1        = 12 ;
  localparam XPLL_DSKW_DLY2        = 15 ;
  localparam XPLL_DSKW_DLY_EN1     = "TRUE" ;
  localparam XPLL_DSKW_DLY_EN2     = "TRUE" ;
  localparam XPLL_DSKW_DLY_PATH1   = "FALSE" ;
  localparam XPLL_DSKW_DLY_PATH2   = "TRUE" ;
  localparam XPLL_CLKOUT1_PHASE    = 236.25 ;
  localparam XPLL_CLKOUT2_PHASE    = 0.0 ;
 
  localparam XPLL_DIV4_CLKOUT3 = 1'b1;
 
  localparam XPLL_DIV4_CLKOUT012 = 1'b1;
 
  localparam XPLL_DESKEW_MUXIN_SEL = 1'b1;
 
  localparam XPLL_DESKEW2_MUXIN_SEL = 1'b1;

      localparam XPLL_CONNECT_TO_NOCMC = "DDR"; 
 
  
  // RDIMM register RC3X
  localparam mts_min = 1240;
  localparam mts_max = 3200;
  localparam mts_gap = 20;
  localparam mts = 2000000/TCK;
  localparam mts_final = (mts>mts_max) ? mts_max :
             (mts<mts_min) ? mts_min :
             mts;
  localparam [7:0] ddr4_reg_rc3x = ((mts_final-mts_min)>=1) ? (mts_final-mts_min-1)/mts_gap : 0;
  localparam         DDR4_REG_RC3X = {5'b0_0011, ddr4_reg_rc3x[7:0]};       

 wire   [53:0]                     nc_iob_bank0;
 wire   [53:0]                     nc_iob_bank1;
 wire   [53:0]                     nc_iob_bank2; 

wire [647:0] nc_dmc_d;
wire [1295:0] DMC_D;
wire [1295:0] DMC_Q;
wire pll_locked;
wire [107:0] DMC_Q0;
wire [107:0] DMC_Q1;
wire [107:0] DMC_Q2;
wire [107:0] DMC_Q3;
wire [107:0] DMC_Q4;
wire [107:0] DMC_Q5;

wire [107:0] DMC2PHY_WR_DQ0;
wire [107:0] DMC2PHY_WR_DQ1;
wire [107:0] DMC2PHY_WR_DQ2;
wire [107:0] DMC2PHY_WR_DQ3;
wire [107:0] DMC2PHY_WR_DQ4;
wire [107:0] DMC2PHY_WR_DQ5;
wire [26:0]  DMC2PHY_FIFO_RDEN;

wire [53:0] DMC2PHY_RDCS0;
wire [53:0] nc_dmc2phy_rdcs0;
wire [107:0] BW_DMC2PHY_RDCS0;
wire [53:0] DMC2PHY_RDCS1;
wire [53:0] nc_dmc2phy_rdcs1;
wire [107:0] BW_DMC2PHY_RDCS1;
wire [53:0] DMC2PHY_RDEN;
wire [53:0] nc_dmc2phy_rden;
wire [107:0] BW_DMC2PHY_RDEN;
wire [53:0] DMC2PHY_WRCS0;
wire [53:0] nc_dmc2phy_wrcs0;
wire [107:0] BW_DMC2PHY_WRCS0;
wire [53:0] DMC2PHY_WRCS1;
wire [53:0] nc_dmc2phy_wrcs1;
wire [107:0] BW_DMC2PHY_WRCS1;
wire [53:0] DMC2PHY_T_B;
wire [53:0] nc_dmc2phy_wren;
wire [107:0] BW_DMC2PHY_WREN;
wire [53:0] DMC2PHY_T_TXBIT0;
wire [53:0] DMC2PHY_T_TXBIT1;
wire [53:0] DMC2PHY_T_TXBIT2;
wire [53:0] DMC2PHY_T_TXBIT_NET0;
wire [53:0] DMC2PHY_T_TXBIT_NET1;
wire [53:0] DMC2PHY_T_TXBIT_NET2;
wire [26:0] DMC_FIFO_EMPTY;
wire [26:0] DMC_GT_STATUS;
wire mc_clk_xpll;
wire bank1_xpll0_fifo_rd_clk;

// RIU ports declaration
wire [9:0] riu2dmc_valid_0;
wire [9:0] riu2dmc_valid_1;
wire [9:0] riu2dmc_valid_2;
wire [159:0] riu2dmc_rd_data_0;
wire [159:0] riu2dmc_rd_data_1;
wire [159:0] riu2dmc_rd_data_2;
//XPHY output ports to RIU
wire [8:0] xphy2riu_rd_valid0;
wire [8:0] xphy2riu_rd_valid1;
wire [8:0] xphy2riu_rd_valid2;
wire [143:0] xphy2riu_rd_data0;
wire [143:0] xphy2riu_rd_data1;
wire [143:0] xphy2riu_rd_data2;

//XPLL to RIU wire declaration
wire xpll2riu_rd_valid0;
wire xpll2riu_rd_valid1;
wire xpll2riu_rd_valid2;
wire [15:0] xpll2riu_rd_data0;
wire [15:0] xpll2riu_rd_data1;
wire [15:0] xpll2riu_rd_data2;

//XPLL to XPHY wire declaration
wire [2:0] pll_clktoxphy; 
wire bank2xpll_clkoutphy;
(* dont_touch = "true" *) wire pll_clk_xpll;//bank1xpll_clkoutphy
//##TODO
wire lp4_pll_clk;//bank1xpll_clkoutphy
wire bank0xpll_clkoutphy;
wire bank1_clkout0;
wire xpll_clk_in;
wire sys_clk_O;
reg sys_clk_internal;

//RIU to XPHY,XPLL wire declarations
wire  [9:0]   riu2phy_ctrl_clk0;
wire  [9:0]   riu2phy_ctrl_clk2;
wire  [9:0]   riu2phy_ctrl_clk1;

wire  [79:0]  riu2xphy_addr2;
wire  [79:0]  riu2xphy_addr1;
wire  [79:0]  riu2xphy_addr0;
wire  [10:0]  riu2xphy_nibble_sel2;
wire  [10:0]  riu2xphy_nibble_sel1;
wire  [10:0]  riu2xphy_nibble_sel0;
wire  [159:0] riu2xphy_wr_data2;
wire  [159:0] riu2xphy_wr_data1;
wire  [159:0] riu2xphy_wr_data0;
wire  [9:0]   riu2xphy_wr_en2;
wire  [9:0]   riu2xphy_wr_en1;
wire  [9:0]   riu2xphy_wr_en0;
wire [31:25] ublaze_fabric_paddr1;
wire [24:0] ublaze_fabric_paddr0;


IBUFDS u_SYS_CLK_O(
		.O	(sys_clk_O),
		.I	(sys_clk_p),
		.IB	(sys_clk_n)
);


/*
*/
`ifndef SIMULATION_MODE
assign riu2dmc_rd_data_0         = {xpll2riu_rd_data0,xphy2riu_rd_data0}; 
assign riu2dmc_valid_0           = {xpll2riu_rd_valid0,xphy2riu_rd_valid0};
assign riu2dmc_rd_data_1         = {xpll2riu_rd_data1,xphy2riu_rd_data1}; 
assign riu2dmc_valid_1           = {xpll2riu_rd_valid1,xphy2riu_rd_valid1};
assign riu2dmc_rd_data_2         = {xpll2riu_rd_data2,xphy2riu_rd_data2}; 
assign riu2dmc_valid_2           = {xpll2riu_rd_valid2,xphy2riu_rd_valid2};

assign pll_clktoxphy             = {bank2xpll_clkoutphy,pll_clk_xpll,bank0xpll_clkoutphy};

assign BW_DMC2PHY_RDCS0[3:0] = {nc_dmc2phy_rdcs0[1:0],DMC2PHY_RDCS0[1:0]};
assign BW_DMC2PHY_RDCS1[3:0] = {nc_dmc2phy_rdcs1[1:0],DMC2PHY_RDCS1[1:0]};
assign BW_DMC2PHY_RDEN[3:0] = {nc_dmc2phy_rden[1:0],DMC2PHY_RDEN[1:0]};
assign BW_DMC2PHY_WRCS0[3:0] = {nc_dmc2phy_wrcs0[1:0],DMC2PHY_WRCS0[1:0]};
assign BW_DMC2PHY_WRCS1[3:0] = {nc_dmc2phy_wrcs1[1:0],DMC2PHY_WRCS1[1:0]};
assign BW_DMC2PHY_WREN[3:0] = {nc_dmc2phy_wren[1:0],DMC2PHY_T_B[1:0]};
assign BW_DMC2PHY_RDCS0[7:4] = {nc_dmc2phy_rdcs0[3:2],DMC2PHY_RDCS0[3:2]};
assign BW_DMC2PHY_RDCS1[7:4] = {nc_dmc2phy_rdcs1[3:2],DMC2PHY_RDCS1[3:2]};
assign BW_DMC2PHY_RDEN[7:4] = {nc_dmc2phy_rden[3:2],DMC2PHY_RDEN[3:2]};
assign BW_DMC2PHY_WRCS0[7:4] = {nc_dmc2phy_wrcs0[3:2],DMC2PHY_WRCS0[3:2]};
assign BW_DMC2PHY_WRCS1[7:4] = {nc_dmc2phy_wrcs1[3:2],DMC2PHY_WRCS1[3:2]};
assign BW_DMC2PHY_WREN[7:4] = {nc_dmc2phy_wren[3:2],DMC2PHY_T_B[3:2]};
assign BW_DMC2PHY_RDCS0[11:8] = {nc_dmc2phy_rdcs0[5:4],DMC2PHY_RDCS0[5:4]};
assign BW_DMC2PHY_RDCS1[11:8] = {nc_dmc2phy_rdcs1[5:4],DMC2PHY_RDCS1[5:4]};
assign BW_DMC2PHY_RDEN[11:8] = {nc_dmc2phy_rden[5:4],DMC2PHY_RDEN[5:4]};
assign BW_DMC2PHY_WRCS0[11:8] = {nc_dmc2phy_wrcs0[5:4],DMC2PHY_WRCS0[5:4]};
assign BW_DMC2PHY_WRCS1[11:8] = {nc_dmc2phy_wrcs1[5:4],DMC2PHY_WRCS1[5:4]};
assign BW_DMC2PHY_WREN[11:8] = {nc_dmc2phy_wren[5:4],DMC2PHY_T_B[5:4]};
assign BW_DMC2PHY_RDCS0[15:12] = {nc_dmc2phy_rdcs0[7:6],DMC2PHY_RDCS0[7:6]};
assign BW_DMC2PHY_RDCS1[15:12] = {nc_dmc2phy_rdcs1[7:6],DMC2PHY_RDCS1[7:6]};
assign BW_DMC2PHY_RDEN[15:12] = {nc_dmc2phy_rden[7:6],DMC2PHY_RDEN[7:6]};
assign BW_DMC2PHY_WRCS0[15:12] = {nc_dmc2phy_wrcs0[7:6],DMC2PHY_WRCS0[7:6]};
assign BW_DMC2PHY_WRCS1[15:12] = {nc_dmc2phy_wrcs1[7:6],DMC2PHY_WRCS1[7:6]};
assign BW_DMC2PHY_WREN[15:12] = {nc_dmc2phy_wren[7:6],DMC2PHY_T_B[7:6]};
assign BW_DMC2PHY_RDCS0[19:16] = {nc_dmc2phy_rdcs0[9:8],DMC2PHY_RDCS0[9:8]};
assign BW_DMC2PHY_RDCS1[19:16] = {nc_dmc2phy_rdcs1[9:8],DMC2PHY_RDCS1[9:8]};
assign BW_DMC2PHY_RDEN[19:16] = {nc_dmc2phy_rden[9:8],DMC2PHY_RDEN[9:8]};
assign BW_DMC2PHY_WRCS0[19:16] = {nc_dmc2phy_wrcs0[9:8],DMC2PHY_WRCS0[9:8]};
assign BW_DMC2PHY_WRCS1[19:16] = {nc_dmc2phy_wrcs1[9:8],DMC2PHY_WRCS1[9:8]};
assign BW_DMC2PHY_WREN[19:16] = {nc_dmc2phy_wren[9:8],DMC2PHY_T_B[9:8]};
assign BW_DMC2PHY_RDCS0[23:20] = {nc_dmc2phy_rdcs0[11:10],DMC2PHY_RDCS0[11:10]};
assign BW_DMC2PHY_RDCS1[23:20] = {nc_dmc2phy_rdcs1[11:10],DMC2PHY_RDCS1[11:10]};
assign BW_DMC2PHY_RDEN[23:20] = {nc_dmc2phy_rden[11:10],DMC2PHY_RDEN[11:10]};
assign BW_DMC2PHY_WRCS0[23:20] = {nc_dmc2phy_wrcs0[11:10],DMC2PHY_WRCS0[11:10]};
assign BW_DMC2PHY_WRCS1[23:20] = {nc_dmc2phy_wrcs1[11:10],DMC2PHY_WRCS1[11:10]};
assign BW_DMC2PHY_WREN[23:20] = {nc_dmc2phy_wren[11:10],DMC2PHY_T_B[11:10]};
assign BW_DMC2PHY_RDCS0[27:24] = {nc_dmc2phy_rdcs0[13:12],DMC2PHY_RDCS0[13:12]};
assign BW_DMC2PHY_RDCS1[27:24] = {nc_dmc2phy_rdcs1[13:12],DMC2PHY_RDCS1[13:12]};
assign BW_DMC2PHY_RDEN[27:24] = {nc_dmc2phy_rden[13:12],DMC2PHY_RDEN[13:12]};
assign BW_DMC2PHY_WRCS0[27:24] = {nc_dmc2phy_wrcs0[13:12],DMC2PHY_WRCS0[13:12]};
assign BW_DMC2PHY_WRCS1[27:24] = {nc_dmc2phy_wrcs1[13:12],DMC2PHY_WRCS1[13:12]};
assign BW_DMC2PHY_WREN[27:24] = {nc_dmc2phy_wren[13:12],DMC2PHY_T_B[13:12]};
assign BW_DMC2PHY_RDCS0[31:28] = {nc_dmc2phy_rdcs0[15:14],DMC2PHY_RDCS0[15:14]};
assign BW_DMC2PHY_RDCS1[31:28] = {nc_dmc2phy_rdcs1[15:14],DMC2PHY_RDCS1[15:14]};
assign BW_DMC2PHY_RDEN[31:28] = {nc_dmc2phy_rden[15:14],DMC2PHY_RDEN[15:14]};
assign BW_DMC2PHY_WRCS0[31:28] = {nc_dmc2phy_wrcs0[15:14],DMC2PHY_WRCS0[15:14]};
assign BW_DMC2PHY_WRCS1[31:28] = {nc_dmc2phy_wrcs1[15:14],DMC2PHY_WRCS1[15:14]};
assign BW_DMC2PHY_WREN[31:28] = {nc_dmc2phy_wren[15:14],DMC2PHY_T_B[15:14]};
assign BW_DMC2PHY_RDCS0[35:32] = {nc_dmc2phy_rdcs0[17:16],DMC2PHY_RDCS0[17:16]};
assign BW_DMC2PHY_RDCS1[35:32] = {nc_dmc2phy_rdcs1[17:16],DMC2PHY_RDCS1[17:16]};
assign BW_DMC2PHY_RDEN[35:32] = {nc_dmc2phy_rden[17:16],DMC2PHY_RDEN[17:16]};
assign BW_DMC2PHY_WRCS0[35:32] = {nc_dmc2phy_wrcs0[17:16],DMC2PHY_WRCS0[17:16]};
assign BW_DMC2PHY_WRCS1[35:32] = {nc_dmc2phy_wrcs1[17:16],DMC2PHY_WRCS1[17:16]};
assign BW_DMC2PHY_WREN[35:32] = {nc_dmc2phy_wren[17:16],DMC2PHY_T_B[17:16]};
assign BW_DMC2PHY_RDCS0[39:36] = {nc_dmc2phy_rdcs0[19:18],DMC2PHY_RDCS0[19:18]};
assign BW_DMC2PHY_RDCS1[39:36] = {nc_dmc2phy_rdcs1[19:18],DMC2PHY_RDCS1[19:18]};
assign BW_DMC2PHY_RDEN[39:36] = {nc_dmc2phy_rden[19:18],DMC2PHY_RDEN[19:18]};
assign BW_DMC2PHY_WRCS0[39:36] = {nc_dmc2phy_wrcs0[19:18],DMC2PHY_WRCS0[19:18]};
assign BW_DMC2PHY_WRCS1[39:36] = {nc_dmc2phy_wrcs1[19:18],DMC2PHY_WRCS1[19:18]};
assign BW_DMC2PHY_WREN[39:36] = {nc_dmc2phy_wren[19:18],DMC2PHY_T_B[19:18]};
assign BW_DMC2PHY_RDCS0[43:40] = {nc_dmc2phy_rdcs0[21:20],DMC2PHY_RDCS0[21:20]};
assign BW_DMC2PHY_RDCS1[43:40] = {nc_dmc2phy_rdcs1[21:20],DMC2PHY_RDCS1[21:20]};
assign BW_DMC2PHY_RDEN[43:40] = {nc_dmc2phy_rden[21:20],DMC2PHY_RDEN[21:20]};
assign BW_DMC2PHY_WRCS0[43:40] = {nc_dmc2phy_wrcs0[21:20],DMC2PHY_WRCS0[21:20]};
assign BW_DMC2PHY_WRCS1[43:40] = {nc_dmc2phy_wrcs1[21:20],DMC2PHY_WRCS1[21:20]};
assign BW_DMC2PHY_WREN[43:40] = {nc_dmc2phy_wren[21:20],DMC2PHY_T_B[21:20]};
assign BW_DMC2PHY_RDCS0[47:44] = {nc_dmc2phy_rdcs0[23:22],DMC2PHY_RDCS0[23:22]};
assign BW_DMC2PHY_RDCS1[47:44] = {nc_dmc2phy_rdcs1[23:22],DMC2PHY_RDCS1[23:22]};
assign BW_DMC2PHY_RDEN[47:44] = {nc_dmc2phy_rden[23:22],DMC2PHY_RDEN[23:22]};
assign BW_DMC2PHY_WRCS0[47:44] = {nc_dmc2phy_wrcs0[23:22],DMC2PHY_WRCS0[23:22]};
assign BW_DMC2PHY_WRCS1[47:44] = {nc_dmc2phy_wrcs1[23:22],DMC2PHY_WRCS1[23:22]};
assign BW_DMC2PHY_WREN[47:44] = {nc_dmc2phy_wren[23:22],DMC2PHY_T_B[23:22]};
assign BW_DMC2PHY_RDCS0[51:48] = {nc_dmc2phy_rdcs0[25:24],DMC2PHY_RDCS0[25:24]};
assign BW_DMC2PHY_RDCS1[51:48] = {nc_dmc2phy_rdcs1[25:24],DMC2PHY_RDCS1[25:24]};
assign BW_DMC2PHY_RDEN[51:48] = {nc_dmc2phy_rden[25:24],DMC2PHY_RDEN[25:24]};
assign BW_DMC2PHY_WRCS0[51:48] = {nc_dmc2phy_wrcs0[25:24],DMC2PHY_WRCS0[25:24]};
assign BW_DMC2PHY_WRCS1[51:48] = {nc_dmc2phy_wrcs1[25:24],DMC2PHY_WRCS1[25:24]};
assign BW_DMC2PHY_WREN[51:48] = {nc_dmc2phy_wren[25:24],DMC2PHY_T_B[25:24]};
assign BW_DMC2PHY_RDCS0[55:52] = {nc_dmc2phy_rdcs0[27:26],DMC2PHY_RDCS0[27:26]};
assign BW_DMC2PHY_RDCS1[55:52] = {nc_dmc2phy_rdcs1[27:26],DMC2PHY_RDCS1[27:26]};
assign BW_DMC2PHY_RDEN[55:52] = {nc_dmc2phy_rden[27:26],DMC2PHY_RDEN[27:26]};
assign BW_DMC2PHY_WRCS0[55:52] = {nc_dmc2phy_wrcs0[27:26],DMC2PHY_WRCS0[27:26]};
assign BW_DMC2PHY_WRCS1[55:52] = {nc_dmc2phy_wrcs1[27:26],DMC2PHY_WRCS1[27:26]};
assign BW_DMC2PHY_WREN[55:52] = {nc_dmc2phy_wren[27:26],DMC2PHY_T_B[27:26]};
assign BW_DMC2PHY_RDCS0[59:56] = {nc_dmc2phy_rdcs0[29:28],DMC2PHY_RDCS0[29:28]};
assign BW_DMC2PHY_RDCS1[59:56] = {nc_dmc2phy_rdcs1[29:28],DMC2PHY_RDCS1[29:28]};
assign BW_DMC2PHY_RDEN[59:56] = {nc_dmc2phy_rden[29:28],DMC2PHY_RDEN[29:28]};
assign BW_DMC2PHY_WRCS0[59:56] = {nc_dmc2phy_wrcs0[29:28],DMC2PHY_WRCS0[29:28]};
assign BW_DMC2PHY_WRCS1[59:56] = {nc_dmc2phy_wrcs1[29:28],DMC2PHY_WRCS1[29:28]};
assign BW_DMC2PHY_WREN[59:56] = {nc_dmc2phy_wren[29:28],DMC2PHY_T_B[29:28]};
assign BW_DMC2PHY_RDCS0[63:60] = {nc_dmc2phy_rdcs0[31:30],DMC2PHY_RDCS0[31:30]};
assign BW_DMC2PHY_RDCS1[63:60] = {nc_dmc2phy_rdcs1[31:30],DMC2PHY_RDCS1[31:30]};
assign BW_DMC2PHY_RDEN[63:60] = {nc_dmc2phy_rden[31:30],DMC2PHY_RDEN[31:30]};
assign BW_DMC2PHY_WRCS0[63:60] = {nc_dmc2phy_wrcs0[31:30],DMC2PHY_WRCS0[31:30]};
assign BW_DMC2PHY_WRCS1[63:60] = {nc_dmc2phy_wrcs1[31:30],DMC2PHY_WRCS1[31:30]};
assign BW_DMC2PHY_WREN[63:60] = {nc_dmc2phy_wren[31:30],DMC2PHY_T_B[31:30]};
assign BW_DMC2PHY_RDCS0[67:64] = {nc_dmc2phy_rdcs0[33:32],DMC2PHY_RDCS0[33:32]};
assign BW_DMC2PHY_RDCS1[67:64] = {nc_dmc2phy_rdcs1[33:32],DMC2PHY_RDCS1[33:32]};
assign BW_DMC2PHY_RDEN[67:64] = {nc_dmc2phy_rden[33:32],DMC2PHY_RDEN[33:32]};
assign BW_DMC2PHY_WRCS0[67:64] = {nc_dmc2phy_wrcs0[33:32],DMC2PHY_WRCS0[33:32]};
assign BW_DMC2PHY_WRCS1[67:64] = {nc_dmc2phy_wrcs1[33:32],DMC2PHY_WRCS1[33:32]};
assign BW_DMC2PHY_WREN[67:64] = {nc_dmc2phy_wren[33:32],DMC2PHY_T_B[33:32]};
assign BW_DMC2PHY_RDCS0[71:68] = {nc_dmc2phy_rdcs0[35:34],DMC2PHY_RDCS0[35:34]};
assign BW_DMC2PHY_RDCS1[71:68] = {nc_dmc2phy_rdcs1[35:34],DMC2PHY_RDCS1[35:34]};
assign BW_DMC2PHY_RDEN[71:68] = {nc_dmc2phy_rden[35:34],DMC2PHY_RDEN[35:34]};
assign BW_DMC2PHY_WRCS0[71:68] = {nc_dmc2phy_wrcs0[35:34],DMC2PHY_WRCS0[35:34]};
assign BW_DMC2PHY_WRCS1[71:68] = {nc_dmc2phy_wrcs1[35:34],DMC2PHY_WRCS1[35:34]};
assign BW_DMC2PHY_WREN[71:68] = {nc_dmc2phy_wren[35:34],DMC2PHY_T_B[35:34]};
assign BW_DMC2PHY_RDCS0[75:72] = {nc_dmc2phy_rdcs0[37:36],DMC2PHY_RDCS0[37:36]};
assign BW_DMC2PHY_RDCS1[75:72] = {nc_dmc2phy_rdcs1[37:36],DMC2PHY_RDCS1[37:36]};
assign BW_DMC2PHY_RDEN[75:72] = {nc_dmc2phy_rden[37:36],DMC2PHY_RDEN[37:36]};
assign BW_DMC2PHY_WRCS0[75:72] = {nc_dmc2phy_wrcs0[37:36],DMC2PHY_WRCS0[37:36]};
assign BW_DMC2PHY_WRCS1[75:72] = {nc_dmc2phy_wrcs1[37:36],DMC2PHY_WRCS1[37:36]};
assign BW_DMC2PHY_WREN[75:72] = {nc_dmc2phy_wren[37:36],DMC2PHY_T_B[37:36]};
assign BW_DMC2PHY_RDCS0[79:76] = {nc_dmc2phy_rdcs0[39:38],DMC2PHY_RDCS0[39:38]};
assign BW_DMC2PHY_RDCS1[79:76] = {nc_dmc2phy_rdcs1[39:38],DMC2PHY_RDCS1[39:38]};
assign BW_DMC2PHY_RDEN[79:76] = {nc_dmc2phy_rden[39:38],DMC2PHY_RDEN[39:38]};
assign BW_DMC2PHY_WRCS0[79:76] = {nc_dmc2phy_wrcs0[39:38],DMC2PHY_WRCS0[39:38]};
assign BW_DMC2PHY_WRCS1[79:76] = {nc_dmc2phy_wrcs1[39:38],DMC2PHY_WRCS1[39:38]};
assign BW_DMC2PHY_WREN[79:76] = {nc_dmc2phy_wren[39:38],DMC2PHY_T_B[39:38]};
assign BW_DMC2PHY_RDCS0[83:80] = {nc_dmc2phy_rdcs0[41:40],DMC2PHY_RDCS0[41:40]};
assign BW_DMC2PHY_RDCS1[83:80] = {nc_dmc2phy_rdcs1[41:40],DMC2PHY_RDCS1[41:40]};
assign BW_DMC2PHY_RDEN[83:80] = {nc_dmc2phy_rden[41:40],DMC2PHY_RDEN[41:40]};
assign BW_DMC2PHY_WRCS0[83:80] = {nc_dmc2phy_wrcs0[41:40],DMC2PHY_WRCS0[41:40]};
assign BW_DMC2PHY_WRCS1[83:80] = {nc_dmc2phy_wrcs1[41:40],DMC2PHY_WRCS1[41:40]};
assign BW_DMC2PHY_WREN[83:80] = {nc_dmc2phy_wren[41:40],DMC2PHY_T_B[41:40]};
assign BW_DMC2PHY_RDCS0[87:84] = {nc_dmc2phy_rdcs0[43:42],DMC2PHY_RDCS0[43:42]};
assign BW_DMC2PHY_RDCS1[87:84] = {nc_dmc2phy_rdcs1[43:42],DMC2PHY_RDCS1[43:42]};
assign BW_DMC2PHY_RDEN[87:84] = {nc_dmc2phy_rden[43:42],DMC2PHY_RDEN[43:42]};
assign BW_DMC2PHY_WRCS0[87:84] = {nc_dmc2phy_wrcs0[43:42],DMC2PHY_WRCS0[43:42]};
assign BW_DMC2PHY_WRCS1[87:84] = {nc_dmc2phy_wrcs1[43:42],DMC2PHY_WRCS1[43:42]};
assign BW_DMC2PHY_WREN[87:84] = {nc_dmc2phy_wren[43:42],DMC2PHY_T_B[43:42]};
assign BW_DMC2PHY_RDCS0[91:88] = {nc_dmc2phy_rdcs0[45:44],DMC2PHY_RDCS0[45:44]};
assign BW_DMC2PHY_RDCS1[91:88] = {nc_dmc2phy_rdcs1[45:44],DMC2PHY_RDCS1[45:44]};
assign BW_DMC2PHY_RDEN[91:88] = {nc_dmc2phy_rden[45:44],DMC2PHY_RDEN[45:44]};
assign BW_DMC2PHY_WRCS0[91:88] = {nc_dmc2phy_wrcs0[45:44],DMC2PHY_WRCS0[45:44]};
assign BW_DMC2PHY_WRCS1[91:88] = {nc_dmc2phy_wrcs1[45:44],DMC2PHY_WRCS1[45:44]};
assign BW_DMC2PHY_WREN[91:88] = {nc_dmc2phy_wren[45:44],DMC2PHY_T_B[45:44]};
assign BW_DMC2PHY_RDCS0[95:92] = {nc_dmc2phy_rdcs0[47:46],DMC2PHY_RDCS0[47:46]};
assign BW_DMC2PHY_RDCS1[95:92] = {nc_dmc2phy_rdcs1[47:46],DMC2PHY_RDCS1[47:46]};
assign BW_DMC2PHY_RDEN[95:92] = {nc_dmc2phy_rden[47:46],DMC2PHY_RDEN[47:46]};
assign BW_DMC2PHY_WRCS0[95:92] = {nc_dmc2phy_wrcs0[47:46],DMC2PHY_WRCS0[47:46]};
assign BW_DMC2PHY_WRCS1[95:92] = {nc_dmc2phy_wrcs1[47:46],DMC2PHY_WRCS1[47:46]};
assign BW_DMC2PHY_WREN[95:92] = {nc_dmc2phy_wren[47:46],DMC2PHY_T_B[47:46]};
assign BW_DMC2PHY_RDCS0[99:96] = {nc_dmc2phy_rdcs0[49:48],DMC2PHY_RDCS0[49:48]};
assign BW_DMC2PHY_RDCS1[99:96] = {nc_dmc2phy_rdcs1[49:48],DMC2PHY_RDCS1[49:48]};
assign BW_DMC2PHY_RDEN[99:96] = {nc_dmc2phy_rden[49:48],DMC2PHY_RDEN[49:48]};
assign BW_DMC2PHY_WRCS0[99:96] = {nc_dmc2phy_wrcs0[49:48],DMC2PHY_WRCS0[49:48]};
assign BW_DMC2PHY_WRCS1[99:96] = {nc_dmc2phy_wrcs1[49:48],DMC2PHY_WRCS1[49:48]};
assign BW_DMC2PHY_WREN[99:96] = {nc_dmc2phy_wren[49:48],DMC2PHY_T_B[49:48]};
assign BW_DMC2PHY_RDCS0[103:100] = {nc_dmc2phy_rdcs0[51:50],DMC2PHY_RDCS0[51:50]};
assign BW_DMC2PHY_RDCS1[103:100] = {nc_dmc2phy_rdcs1[51:50],DMC2PHY_RDCS1[51:50]};
assign BW_DMC2PHY_RDEN[103:100] = {nc_dmc2phy_rden[51:50],DMC2PHY_RDEN[51:50]};
assign BW_DMC2PHY_WRCS0[103:100] = {nc_dmc2phy_wrcs0[51:50],DMC2PHY_WRCS0[51:50]};
assign BW_DMC2PHY_WRCS1[103:100] = {nc_dmc2phy_wrcs1[51:50],DMC2PHY_WRCS1[51:50]};
assign BW_DMC2PHY_WREN[103:100] = {nc_dmc2phy_wren[51:50],DMC2PHY_T_B[51:50]};
assign BW_DMC2PHY_RDCS0[107:104] = {nc_dmc2phy_rdcs0[53:52],DMC2PHY_RDCS0[53:52]};
assign BW_DMC2PHY_RDCS1[107:104] = {nc_dmc2phy_rdcs1[53:52],DMC2PHY_RDCS1[53:52]};
assign BW_DMC2PHY_RDEN[107:104] = {nc_dmc2phy_rden[53:52],DMC2PHY_RDEN[53:52]};
assign BW_DMC2PHY_WRCS0[107:104] = {nc_dmc2phy_wrcs0[53:52],DMC2PHY_WRCS0[53:52]};
assign BW_DMC2PHY_WRCS1[107:104] = {nc_dmc2phy_wrcs1[53:52],DMC2PHY_WRCS1[53:52]};
assign BW_DMC2PHY_WREN[107:104] = {nc_dmc2phy_wren[53:52],DMC2PHY_T_B[53:52]};

`endif

`ifdef SIMULATION_MODE



ddr4mc_top #(
                      .ARBITER_CONFIG               (ARBITER_CONFIG),
                      .CAL_CS_CH                    (CAL_CS_CH),
                      .DDR4_CLAMSHELL               (DDR4_CLAMSHELL),
                      .CAL_MODE                     (CAL_MODE),
                      .CLK_GATE                     (CLK_GATE),
                      .CPLX_BURST_ARRAY0            (CPLX_BURST_ARRAY0),
                      .CPLX_BURST_ARRAY1            (CPLX_BURST_ARRAY1),
                      .CPLX_BURST_ARRAY10           (CPLX_BURST_ARRAY10),
                      .CPLX_BURST_ARRAY11           (CPLX_BURST_ARRAY11),
                      .CPLX_BURST_ARRAY12           (CPLX_BURST_ARRAY12),
                      .CPLX_BURST_ARRAY13           (CPLX_BURST_ARRAY13),
                      .CPLX_BURST_ARRAY14           (CPLX_BURST_ARRAY14),
                      .CPLX_BURST_ARRAY15           (CPLX_BURST_ARRAY15),
                      .CPLX_BURST_ARRAY16           (CPLX_BURST_ARRAY16),
                      .CPLX_BURST_ARRAY17           (CPLX_BURST_ARRAY17),
                      .CPLX_BURST_ARRAY18           (CPLX_BURST_ARRAY18),
                      .CPLX_BURST_ARRAY19           (CPLX_BURST_ARRAY19),
                      .CPLX_BURST_ARRAY2            (CPLX_BURST_ARRAY2),
                      .CPLX_BURST_ARRAY20           (CPLX_BURST_ARRAY20),
                      .CPLX_BURST_ARRAY21           (CPLX_BURST_ARRAY21),
                      .CPLX_BURST_ARRAY22           (CPLX_BURST_ARRAY22),
                      .CPLX_BURST_ARRAY3            (CPLX_BURST_ARRAY3),
                      .CPLX_BURST_ARRAY4            (CPLX_BURST_ARRAY4),
                      .CPLX_BURST_ARRAY5            (CPLX_BURST_ARRAY5),
                      .CPLX_BURST_ARRAY6            (CPLX_BURST_ARRAY6),
                      .CPLX_BURST_ARRAY7            (CPLX_BURST_ARRAY7),
                      .CPLX_BURST_ARRAY8            (CPLX_BURST_ARRAY8),
                      .CPLX_BURST_ARRAY9            (CPLX_BURST_ARRAY9),
                      .CPLX_CONFIG                  (CPLX_CONFIG),
                      .CPLX_CONFIG2                 (CPLX_CONFIG2),
                      .CPLX_CONFIG3                 (CPLX_CONFIG3),
                      .CPLX_PATTERN0                (CPLX_PATTERN0),
                      .CPLX_PATTERN1                (CPLX_PATTERN1),
                      .CPLX_PATTERN10               (CPLX_PATTERN10),
                      .CPLX_PATTERN100              (CPLX_PATTERN100),
                      .CPLX_PATTERN101              (CPLX_PATTERN101),
                      .CPLX_PATTERN102              (CPLX_PATTERN102),
                      .CPLX_PATTERN103              (CPLX_PATTERN103),
                      .CPLX_PATTERN104              (CPLX_PATTERN104),
                      .CPLX_PATTERN105              (CPLX_PATTERN105),
                      .CPLX_PATTERN106              (CPLX_PATTERN106),
                      .CPLX_PATTERN107              (CPLX_PATTERN107),
                      .CPLX_PATTERN108              (CPLX_PATTERN108),
                      .CPLX_PATTERN109              (CPLX_PATTERN109),
                      .CPLX_PATTERN11               (CPLX_PATTERN11),
                      .CPLX_PATTERN110              (CPLX_PATTERN110),
                      .CPLX_PATTERN111              (CPLX_PATTERN111),
                      .CPLX_PATTERN112              (CPLX_PATTERN112),
                      .CPLX_PATTERN113              (CPLX_PATTERN113),
                      .CPLX_PATTERN114              (CPLX_PATTERN114),
                      .CPLX_PATTERN115              (CPLX_PATTERN115),
                      .CPLX_PATTERN116              (CPLX_PATTERN116),
                      .CPLX_PATTERN117              (CPLX_PATTERN117),
                      .CPLX_PATTERN118              (CPLX_PATTERN118),
                      .CPLX_PATTERN119              (CPLX_PATTERN119),
                      .CPLX_PATTERN12               (CPLX_PATTERN12),
                      .CPLX_PATTERN120              (CPLX_PATTERN120),
                      .CPLX_PATTERN121              (CPLX_PATTERN121),
                      .CPLX_PATTERN122              (CPLX_PATTERN122),
                      .CPLX_PATTERN123              (CPLX_PATTERN123),
                      .CPLX_PATTERN124              (CPLX_PATTERN124),
                      .CPLX_PATTERN125              (CPLX_PATTERN125),
                      .CPLX_PATTERN126              (CPLX_PATTERN126),
                      .CPLX_PATTERN127              (CPLX_PATTERN127),
                      .CPLX_PATTERN128              (CPLX_PATTERN128),
                      .CPLX_PATTERN129              (CPLX_PATTERN129),
                      .CPLX_PATTERN13               (CPLX_PATTERN13),
                      .CPLX_PATTERN130              (CPLX_PATTERN130),
                      .CPLX_PATTERN131              (CPLX_PATTERN131),
                      .CPLX_PATTERN132              (CPLX_PATTERN132),
                      .CPLX_PATTERN133              (CPLX_PATTERN133),
                      .CPLX_PATTERN134              (CPLX_PATTERN134),
                      .CPLX_PATTERN135              (CPLX_PATTERN135),
                      .CPLX_PATTERN136              (CPLX_PATTERN136),
                      .CPLX_PATTERN137              (CPLX_PATTERN137),
                      .CPLX_PATTERN138              (CPLX_PATTERN138),
                      .CPLX_PATTERN139              (CPLX_PATTERN139),
                      .CPLX_PATTERN14               (CPLX_PATTERN14),
                      .CPLX_PATTERN140              (CPLX_PATTERN140),
                      .CPLX_PATTERN141              (CPLX_PATTERN141),
                      .CPLX_PATTERN142              (CPLX_PATTERN142),
                      .CPLX_PATTERN143              (CPLX_PATTERN143),
                      .CPLX_PATTERN144              (CPLX_PATTERN144),
                      .CPLX_PATTERN145              (CPLX_PATTERN145),
                      .CPLX_PATTERN146              (CPLX_PATTERN146),
                      .CPLX_PATTERN147              (CPLX_PATTERN147),
                      .CPLX_PATTERN148              (CPLX_PATTERN148),
                      .CPLX_PATTERN149              (CPLX_PATTERN149),
                      .CPLX_PATTERN15               (CPLX_PATTERN15),
                      .CPLX_PATTERN150              (CPLX_PATTERN150),
                      .CPLX_PATTERN151              (CPLX_PATTERN151),
                      .CPLX_PATTERN152              (CPLX_PATTERN152),
                      .CPLX_PATTERN153              (CPLX_PATTERN153),
                      .CPLX_PATTERN154              (CPLX_PATTERN154),
                      .CPLX_PATTERN155              (CPLX_PATTERN155),
                      .CPLX_PATTERN156              (CPLX_PATTERN156),
                      .CPLX_PATTERN16               (CPLX_PATTERN16),
                      .CPLX_PATTERN17               (CPLX_PATTERN17),
                      .CPLX_PATTERN18               (CPLX_PATTERN18),
                      .CPLX_PATTERN19               (CPLX_PATTERN19),
                      .CPLX_PATTERN2                (CPLX_PATTERN2),
                      .CPLX_PATTERN20               (CPLX_PATTERN20),
                      .CPLX_PATTERN21               (CPLX_PATTERN21),
                      .CPLX_PATTERN22               (CPLX_PATTERN22),
                      .CPLX_PATTERN23               (CPLX_PATTERN23),
                      .CPLX_PATTERN24               (CPLX_PATTERN24),
                      .CPLX_PATTERN25               (CPLX_PATTERN25),
                      .CPLX_PATTERN26               (CPLX_PATTERN26),
                      .CPLX_PATTERN27               (CPLX_PATTERN27),
                      .CPLX_PATTERN28               (CPLX_PATTERN28),
                      .CPLX_PATTERN29               (CPLX_PATTERN29),
                      .CPLX_PATTERN3                (CPLX_PATTERN3),
                      .CPLX_PATTERN30               (CPLX_PATTERN30),
                      .CPLX_PATTERN31               (CPLX_PATTERN31),
                      .CPLX_PATTERN32               (CPLX_PATTERN32),
                      .CPLX_PATTERN33               (CPLX_PATTERN33),
                      .CPLX_PATTERN34               (CPLX_PATTERN34),
                      .CPLX_PATTERN35               (CPLX_PATTERN35),
                      .CPLX_PATTERN36               (CPLX_PATTERN36),
                      .CPLX_PATTERN37               (CPLX_PATTERN37),
                      .CPLX_PATTERN38               (CPLX_PATTERN38),
                      .CPLX_PATTERN39               (CPLX_PATTERN39),
                      .CPLX_PATTERN4                (CPLX_PATTERN4),
                      .CPLX_PATTERN40               (CPLX_PATTERN40),
                      .CPLX_PATTERN41               (CPLX_PATTERN41),
                      .CPLX_PATTERN42               (CPLX_PATTERN42),
                      .CPLX_PATTERN43               (CPLX_PATTERN43),
                      .CPLX_PATTERN44               (CPLX_PATTERN44),
                      .CPLX_PATTERN45               (CPLX_PATTERN45),
                      .CPLX_PATTERN46               (CPLX_PATTERN46),
                      .CPLX_PATTERN47               (CPLX_PATTERN47),
                      .CPLX_PATTERN48               (CPLX_PATTERN48),
                      .CPLX_PATTERN49               (CPLX_PATTERN49),
                      .CPLX_PATTERN5                (CPLX_PATTERN5),
                      .CPLX_PATTERN50               (CPLX_PATTERN50),
                      .CPLX_PATTERN51               (CPLX_PATTERN51),
                      .CPLX_PATTERN52               (CPLX_PATTERN52),
                      .CPLX_PATTERN53               (CPLX_PATTERN53),
                      .CPLX_PATTERN54               (CPLX_PATTERN54),
                      .CPLX_PATTERN55               (CPLX_PATTERN55),
                      .CPLX_PATTERN56               (CPLX_PATTERN56),
                      .CPLX_PATTERN57               (CPLX_PATTERN57),
                      .CPLX_PATTERN58               (CPLX_PATTERN58),
                      .CPLX_PATTERN59               (CPLX_PATTERN59),
                      .CPLX_PATTERN6                (CPLX_PATTERN6),
                      .CPLX_PATTERN60               (CPLX_PATTERN60),
                      .CPLX_PATTERN61               (CPLX_PATTERN61),
                      .CPLX_PATTERN62               (CPLX_PATTERN62),
                      .CPLX_PATTERN63               (CPLX_PATTERN63),
                      .CPLX_PATTERN64               (CPLX_PATTERN64),
                      .CPLX_PATTERN65               (CPLX_PATTERN65),
                      .CPLX_PATTERN66               (CPLX_PATTERN66),
                      .CPLX_PATTERN67               (CPLX_PATTERN67),
                      .CPLX_PATTERN68               (CPLX_PATTERN68),
                      .CPLX_PATTERN69               (CPLX_PATTERN69),
                      .CPLX_PATTERN7                (CPLX_PATTERN7),
                      .CPLX_PATTERN70               (CPLX_PATTERN70),
                      .CPLX_PATTERN71               (CPLX_PATTERN71),
                      .CPLX_PATTERN72               (CPLX_PATTERN72),
                      .CPLX_PATTERN73               (CPLX_PATTERN73),
                      .CPLX_PATTERN74               (CPLX_PATTERN74),
                      .CPLX_PATTERN75               (CPLX_PATTERN75),
                      .CPLX_PATTERN76               (CPLX_PATTERN76),
                      .CPLX_PATTERN77               (CPLX_PATTERN77),
                      .CPLX_PATTERN78               (CPLX_PATTERN78),
                      .CPLX_PATTERN79               (CPLX_PATTERN79),
                      .CPLX_PATTERN8                (CPLX_PATTERN8),
                      .CPLX_PATTERN80               (CPLX_PATTERN80),
                      .CPLX_PATTERN81               (CPLX_PATTERN81),
                      .CPLX_PATTERN82               (CPLX_PATTERN82),
                      .CPLX_PATTERN83               (CPLX_PATTERN83),
                      .CPLX_PATTERN84               (CPLX_PATTERN84),
                      .CPLX_PATTERN85               (CPLX_PATTERN85),
                      .CPLX_PATTERN86               (CPLX_PATTERN86),
                      .CPLX_PATTERN87               (CPLX_PATTERN87),
                      .CPLX_PATTERN88               (CPLX_PATTERN88),
                      .CPLX_PATTERN89               (CPLX_PATTERN89),
                      .CPLX_PATTERN9                (CPLX_PATTERN9),
                      .CPLX_PATTERN90               (CPLX_PATTERN90),
                      .CPLX_PATTERN91               (CPLX_PATTERN91),
                      .CPLX_PATTERN92               (CPLX_PATTERN92),
                      .CPLX_PATTERN93               (CPLX_PATTERN93),
                      .CPLX_PATTERN94               (CPLX_PATTERN94),
                      .CPLX_PATTERN95               (CPLX_PATTERN95),
                      .CPLX_PATTERN96               (CPLX_PATTERN96),
                      .CPLX_PATTERN97               (CPLX_PATTERN97),
                      .CPLX_PATTERN98               (CPLX_PATTERN98),
                      .CPLX_PATTERN99               (CPLX_PATTERN99),
                      .DBG_TRIGGER                  (DBG_TRIGGER),
                      .DC_CMD_CREDITS               (DC_CMD_CREDITS),
                      .DEFAULT_PATTERN              (DEFAULT_PATTERN),
                      .EXMON_CLR_EXE                (EXMON_CLR_EXE), 
                      .FIFO_RDEN                    (FIFO_RDEN),
                      .PHY_RANK_READ_OVERRIDE       (PHY_RANK_READ_OVERRIDE),
                      .PHY_RANK_WRITE_OVERRIDE      (PHY_RANK_WRITE_OVERRIDE),
                      .PHY_RDEN0                    (PHY_RDEN0),
                      .PHY_RDEN1                    (PHY_RDEN1),
                      .PHY_RDEN10                   (PHY_RDEN10),
                      .PHY_RDEN11                   (PHY_RDEN11),
                      .PHY_RDEN12                   (PHY_RDEN12),
                      .PHY_RDEN13                   (PHY_RDEN13),
                      .PHY_RDEN14                   (PHY_RDEN14),
                      .PHY_RDEN15                   (PHY_RDEN15),
                      .PHY_RDEN16                   (PHY_RDEN16),
                      .PHY_RDEN17                   (PHY_RDEN17),
                      .PHY_RDEN18                   (PHY_RDEN18),
                      .PHY_RDEN19                   (PHY_RDEN19),
                      .PHY_RDEN2                    (PHY_RDEN2),
                      .PHY_RDEN20                   (PHY_RDEN20),
                      .PHY_RDEN21                   (PHY_RDEN21),
                      .PHY_RDEN22                   (PHY_RDEN22),
                      .PHY_RDEN23                   (PHY_RDEN23),
                      .PHY_RDEN24                   (PHY_RDEN24),
                      .PHY_RDEN25                   (PHY_RDEN25),
                      .PHY_RDEN26                   (PHY_RDEN26),
                      .PHY_RDEN3                    (PHY_RDEN3),
                      .PHY_RDEN4                    (PHY_RDEN4),
                      .PHY_RDEN5                    (PHY_RDEN5),
                      .PHY_RDEN6                    (PHY_RDEN6),
                      .PHY_RDEN7                    (PHY_RDEN7),
                      .PHY_RDEN8                    (PHY_RDEN8),
                      .PHY_RDEN9                    (PHY_RDEN9),
                      .PRBS_CNT                     (PRBS_CNT),
                      .PRBS_CONFIG                  (PRBS_CONFIG),
                      .PRBS_CONFIG2                 (PRBS_CONFIG2),
                      .PRBS_SEED0                   (PRBS_SEED0),
                      .PRBS_SEED1                   (PRBS_SEED1),
                      .PRBS_SEED2                   (PRBS_SEED2),
                      .PRBS_SEED3                   (PRBS_SEED3),
                      .PRBS_SEED4                   (PRBS_SEED4),
                      .PRBS_SEED5                   (PRBS_SEED5),
                      .PRBS_SEED6                   (PRBS_SEED6),
                      .PRBS_SEED7                   (PRBS_SEED7),
                      .PRBS_SEED8                   (PRBS_SEED8),
                      .RAM_SETTING_RF2PHS           (RAM_SETTING_RF2PHS), 
                      .RAM_SETTING_RFSPHD           (RAM_SETTING_RFSPHD),
                      .RAM_SETTING_SRSPHD           (RAM_SETTING_SRSPHD),
                      .REG_ADEC0                    (REG_ADEC0),
                      .REG_ADEC1                    (REG_ADEC1),
                      .REG_ADEC10                   (REG_ADEC10),
                      .REG_ADEC11                   (REG_ADEC11),
                      .REG_ADEC2                    (REG_ADEC2),
                      .REG_ADEC3                    (REG_ADEC3),
                      .REG_ADEC4                    (REG_ADEC4),
                      .REG_ADEC5                    (REG_ADEC5),
                      .REG_ADEC6                    (REG_ADEC6),
                      .REG_ADEC7                    (REG_ADEC7),
                      .REG_ADEC8                    (REG_ADEC8),
                      .REG_ADEC9                    (REG_ADEC9),
                      .REG_CMDQ_BER_RATE_CTRL       (REG_CMDQ_BER_RATE_CTRL),
                      .REG_CMDQ_BEW_RATE_CTRL       (REG_CMDQ_BEW_RATE_CTRL),
                      .REG_CMDQ_CTRL0               (REG_CMDQ_CTRL0),
                      .REG_CMDQ_CTRL1               (REG_CMDQ_CTRL1),
                      .REG_CMDQ_ISR_RATE_CTRL       (REG_CMDQ_ISR_RATE_CTRL),
                      .REG_CMDQ_ISW_RATE_CTRL       (REG_CMDQ_ISW_RATE_CTRL),
                      .REG_CMDQ_LLR_RATE_CTRL       (REG_CMDQ_LLR_RATE_CTRL),
                      .REG_COM_1                    (REG_COM_1),
                      .REG_COM_2                    (REG_COM_2),
                      .REG_COM_3                    (REG_COM_3),
                      .REG_CONFIG0                  (REG_CONFIG0),
                      .REG_CONFIG1                  (REG_CONFIG1),
                      .REG_CONFIG2                  (REG_CONFIG2),
                      .REG_CONFIG3                  (REG_CONFIG3),
                      .REG_CONFIG4                  (REG_CONFIG4),
                      .REG_DRAM_ARB                 (REG_DRAM_ARB),
                      .REG_MRS_0                    (REG_MRS_0),
                      .REG_MRS_1                    (REG_MRS_1),
                      .REG_MRS_2                    (REG_MRS_2),
                      .REG_MRS_7                    (REG_MRS_7),
                      .REG_NSU0_PORT                (REG_NSU0_PORT),
                      .REG_NSU1_PORT                (REG_NSU1_PORT),
                      .REG_NSU2_PORT                (REG_NSU2_PORT),
                      .REG_NSU3_PORT                (REG_NSU3_PORT),
                      .REG_NSU_0_ING                (REG_NSU_0_ING),
                      .REG_NSU_0_EGR                (REG_NSU_0_EGR),
                      .REG_NSU_0_R_EGR              (REG_NSU_0_R_EGR),
                      .REG_NSU_0_W_EGR              (REG_NSU_0_W_EGR),
                      .REG_NSU_1_ING                (REG_NSU_1_ING),
                      .REG_NSU_1_EGR                (REG_NSU_1_EGR),
                      .REG_NSU_1_R_EGR              (REG_NSU_1_R_EGR),
                      .REG_NSU_1_W_EGR              (REG_NSU_1_W_EGR),
                      .REG_NSU_2_ING                (REG_NSU_2_ING),
                      .REG_NSU_2_EGR                (REG_NSU_2_EGR),
                      .REG_NSU_2_R_EGR              (REG_NSU_2_R_EGR),
                      .REG_NSU_2_W_EGR              (REG_NSU_2_W_EGR),
                      .REG_NSU_3_ING                (REG_NSU_3_ING),
                      .REG_NSU_3_EGR                (REG_NSU_3_EGR),
                      .REG_NSU_3_R_EGR              (REG_NSU_3_R_EGR),
                      .REG_NSU_3_W_EGR              (REG_NSU_3_W_EGR),
                      .REG_P0_BER_RATE_CTRL           (REG_P0_BER_RATE_CTRL),
                      .REG_P0_BEW_RATE_CTRL           (REG_P0_BEW_RATE_CTRL),
                      .REG_P0_ISR_RATE_CTRL           (REG_P0_ISR_RATE_CTRL),
                      .REG_P0_ISW_RATE_CTRL           (REG_P0_ISW_RATE_CTRL),
                      .REG_P0_LLR_RATE_CTRL           (REG_P0_LLR_RATE_CTRL),
                      .REG_P1_BER_RATE_CTRL           (REG_P1_BER_RATE_CTRL),
                      .REG_P1_BEW_RATE_CTRL           (REG_P1_BEW_RATE_CTRL),
                      .REG_P1_ISR_RATE_CTRL           (REG_P1_ISR_RATE_CTRL),
                      .REG_P1_ISW_RATE_CTRL           (REG_P1_ISW_RATE_CTRL),
                      .REG_P1_LLR_RATE_CTRL           (REG_P1_LLR_RATE_CTRL),
                      .REG_P2_BER_RATE_CTRL           (REG_P2_BER_RATE_CTRL),
                      .REG_P2_BEW_RATE_CTRL           (REG_P2_BEW_RATE_CTRL),
                      .REG_P2_ISR_RATE_CTRL           (REG_P2_ISR_RATE_CTRL),
                      .REG_P2_ISW_RATE_CTRL           (REG_P2_ISW_RATE_CTRL),
                      .REG_P2_LLR_RATE_CTRL           (REG_P2_LLR_RATE_CTRL),
                      .REG_P3_BER_RATE_CTRL           (REG_P3_BER_RATE_CTRL),
                      .REG_P3_BEW_RATE_CTRL           (REG_P3_BEW_RATE_CTRL),
                      .REG_P3_ISR_RATE_CTRL           (REG_P3_ISR_RATE_CTRL),
                      .REG_P3_ISW_RATE_CTRL           (REG_P3_ISW_RATE_CTRL),
                      .REG_P3_LLR_RATE_CTRL           (REG_P3_LLR_RATE_CTRL),
                      .REG_PINOUT                     (REG_PINOUT),
                      .REG_PT_CONFIG                  (REG_PT_CONFIG),
                      .REG_QOS0                       (REG_QOS0),
                      .REG_QOS1                       (REG_QOS1),
                      .REG_QOS2                       (REG_QOS2),
                      .REG_QOS_RATE_CTRL_SCALE        (REG_QOS_RATE_CTRL_SCALE),
                      .REG_QOS_TIMEOUT0               (REG_QOS_TIMEOUT0),
                      .REG_QOS_TIMEOUT1               (REG_QOS_TIMEOUT1),
                      .REG_QOS_TIMEOUT2               (REG_QOS_TIMEOUT2),
                      .REG_RATE_CTRL_SCALE            (REG_RATE_CTRL_SCALE),
                      .REG_RD_CONFIG                  (REG_RD_CONFIG),
                      .REG_RD_DRR_TKN_P0              (REG_RD_DRR_TKN_P0),
                      .REG_RD_DRR_TKN_P1              (REG_RD_DRR_TKN_P1),
                      .REG_RD_DRR_TKN_P2              (REG_RD_DRR_TKN_P2),
                      .REG_RD_DRR_TKN_P3              (REG_RD_DRR_TKN_P3),
                      .REG_REF_0                      (REG_REF_0),
                      .REG_REF_1                      (REG_REF_1),
                      .REG_REF_2                      (REG_REF_2),
                      .REG_REF_3                      (REG_REF_3),
                      .REG_RETRY_0                    (REG_RETRY_0),
                      .REG_RETRY_1                    (REG_RETRY_1),
                      .REG_SAFE_CONFIG0               (REG_SAFE_CONFIG0),
                      .REG_SAFE_CONFIG1               (REG_SAFE_CONFIG1),
                      .REG_SAFE_CONFIG2               (REG_SAFE_CONFIG2),
                      .REG_SAFE_CONFIG3               (REG_SAFE_CONFIG3),
                      .REG_SAFE_CONFIG4               (REG_SAFE_CONFIG4), 
                      .REG_SAFE_CONFIG5               (REG_SAFE_CONFIG5), 
                      .REG_SAFE_CONFIG6               (REG_SAFE_CONFIG6), 
                      .REG_SAFE_CONFIG7               (REG_SAFE_CONFIG7), 
                      .REG_SAFE_CONFIG8               (REG_SAFE_CONFIG8),
                      .REG_SCRUB0                     (REG_SCRUB0),
                      .REG_SCRUB1                     (REG_SCRUB1),
                      .REG_SCRUB8                     (REG_SCRUB8),
                      .REG_SCRUB9                     (REG_SCRUB9),
                      .REG_TXN_CONFIG                 (REG_TXN_CONFIG),
                      .REG_WR_CONFIG                  (REG_WR_CONFIG),
                      .REG_WR_DRR_TKN_P0              (REG_WR_DRR_TKN_P0),
                      .REG_WR_DRR_TKN_P1              (REG_WR_DRR_TKN_P1),
                      .REG_WR_DRR_TKN_P2              (REG_WR_DRR_TKN_P2),
                      .REG_WR_DRR_TKN_P3              (REG_WR_DRR_TKN_P3),
                      .SEQ_ADDR_DEFAULT               (SEQ_ADDR_DEFAULT),
                      .SEQ_BA_DEFAULT                 (SEQ_BA_DEFAULT),
                      .SEQ_BG_DEFAULT                 (SEQ_BG_DEFAULT),
                      .SEQ_CBIT_DEFAULT               (SEQ_CBIT_DEFAULT),
                      .SEQ_CK_CAL                     (SEQ_CK_CAL),
                      .SEQ_CMD_DEFAULT                (SEQ_CMD_DEFAULT),
                      .SEQ_CMD_POR                    (SEQ_CMD_POR),
                      .SEQ_DQS_DEFAULT               (SEQ_DQS_DEFAULT),
                      .SEQ_DQ_DEFAULT               (SEQ_DQ_DEFAULT),
                      .SEQ_INIT_ADDR0               (SEQ_INIT_ADDR0),
                      .SEQ_INIT_ADDR1               (SEQ_INIT_ADDR1),
                      .SEQ_INIT_ADDR10               (SEQ_INIT_ADDR10),
                      .SEQ_INIT_ADDR11               (SEQ_INIT_ADDR11),
                      .SEQ_INIT_ADDR12               (SEQ_INIT_ADDR12),
                      .SEQ_INIT_ADDR13               (SEQ_INIT_ADDR13),
                      .SEQ_INIT_ADDR14               (SEQ_INIT_ADDR14),
                      .SEQ_INIT_ADDR15               (SEQ_INIT_ADDR15),
                      .SEQ_INIT_ADDR16               (SEQ_INIT_ADDR16),
                      .SEQ_INIT_ADDR17               (SEQ_INIT_ADDR17),
                      .SEQ_INIT_ADDR18               (SEQ_INIT_ADDR18),
                      .SEQ_INIT_ADDR19               (SEQ_INIT_ADDR19),
                      .SEQ_INIT_ADDR2               (SEQ_INIT_ADDR2),
                      .SEQ_INIT_ADDR20               (SEQ_INIT_ADDR20),
                      .SEQ_INIT_ADDR21               (SEQ_INIT_ADDR21),
                      .SEQ_INIT_ADDR22               (SEQ_INIT_ADDR22),
                      .SEQ_INIT_ADDR23               (SEQ_INIT_ADDR23),
                      .SEQ_INIT_ADDR24               (SEQ_INIT_ADDR24),
                      .SEQ_INIT_ADDR25               (SEQ_INIT_ADDR25),
                      .SEQ_INIT_ADDR26               (SEQ_INIT_ADDR26),
                      .SEQ_INIT_ADDR27               (SEQ_INIT_ADDR27),
                      .SEQ_INIT_ADDR28               (SEQ_INIT_ADDR28),
                      .SEQ_INIT_ADDR29               (SEQ_INIT_ADDR29),
                      .SEQ_INIT_ADDR3               (SEQ_INIT_ADDR3),
                      .SEQ_INIT_ADDR30               (SEQ_INIT_ADDR30),
                      .SEQ_INIT_ADDR31               (SEQ_INIT_ADDR31),
                      .SEQ_INIT_ADDR32               (SEQ_INIT_ADDR32),
                      .SEQ_INIT_ADDR33               (SEQ_INIT_ADDR33),
                      .SEQ_INIT_ADDR34               (SEQ_INIT_ADDR34),
                      .SEQ_INIT_ADDR35               (SEQ_INIT_ADDR35),
                      .SEQ_INIT_ADDR36               (SEQ_INIT_ADDR36),
                      .SEQ_INIT_ADDR37               (SEQ_INIT_ADDR37),
                      .SEQ_INIT_ADDR38               (SEQ_INIT_ADDR38),
                      .SEQ_INIT_ADDR39               (SEQ_INIT_ADDR39),
                      .SEQ_INIT_ADDR4               (SEQ_INIT_ADDR4),
                      .SEQ_INIT_ADDR40               (SEQ_INIT_ADDR40),
                      .SEQ_INIT_ADDR41               (SEQ_INIT_ADDR41),
                      .SEQ_INIT_ADDR42               (SEQ_INIT_ADDR42),
                      .SEQ_INIT_ADDR43               (SEQ_INIT_ADDR43),
                      .SEQ_INIT_ADDR44               (SEQ_INIT_ADDR44),
                      .SEQ_INIT_ADDR45               (SEQ_INIT_ADDR45),
                      .SEQ_INIT_ADDR46               (SEQ_INIT_ADDR46),
                      .SEQ_INIT_ADDR47               (SEQ_INIT_ADDR47),
                      .SEQ_INIT_ADDR48               (SEQ_INIT_ADDR48),
                      .SEQ_INIT_ADDR49               (SEQ_INIT_ADDR49),
                      .SEQ_INIT_ADDR5               (SEQ_INIT_ADDR5),
                      .SEQ_INIT_ADDR50               (SEQ_INIT_ADDR50),
                      .SEQ_INIT_ADDR51               (SEQ_INIT_ADDR51),
                      .SEQ_INIT_ADDR52               (SEQ_INIT_ADDR52),
                      .SEQ_INIT_ADDR53               (SEQ_INIT_ADDR53),
                      .SEQ_INIT_ADDR54               (SEQ_INIT_ADDR54),
                      .SEQ_INIT_ADDR55               (SEQ_INIT_ADDR55),
                      .SEQ_INIT_ADDR56               (SEQ_INIT_ADDR56),
                      .SEQ_INIT_ADDR57               (SEQ_INIT_ADDR57),
                      .SEQ_INIT_ADDR58               (SEQ_INIT_ADDR58),
                      .SEQ_INIT_ADDR59               (SEQ_INIT_ADDR59),
                      .SEQ_INIT_ADDR6               (SEQ_INIT_ADDR6),
                      .SEQ_INIT_ADDR60               (SEQ_INIT_ADDR60),
                      .SEQ_INIT_ADDR61               (SEQ_INIT_ADDR61),
                      .SEQ_INIT_ADDR62               (SEQ_INIT_ADDR62),
                      .SEQ_INIT_ADDR63               (SEQ_INIT_ADDR63),
                      .SEQ_INIT_ADDR64               (SEQ_INIT_ADDR64),
                      .SEQ_INIT_ADDR65               (SEQ_INIT_ADDR65),
                      .SEQ_INIT_ADDR66               (SEQ_INIT_ADDR66),
                      .SEQ_INIT_ADDR67               (SEQ_INIT_ADDR67),
                      .SEQ_INIT_ADDR68               (SEQ_INIT_ADDR68),
                      .SEQ_INIT_ADDR69               (SEQ_INIT_ADDR69),
                      .SEQ_INIT_ADDR7               (SEQ_INIT_ADDR7),
                      .SEQ_INIT_ADDR70               (SEQ_INIT_ADDR70),
                      .SEQ_INIT_ADDR71               (SEQ_INIT_ADDR71),
                      .SEQ_INIT_ADDR72               (SEQ_INIT_ADDR72),
                      .SEQ_INIT_ADDR73               (SEQ_INIT_ADDR73),
                      .SEQ_INIT_ADDR74               (SEQ_INIT_ADDR74),
                      .SEQ_INIT_ADDR75               (SEQ_INIT_ADDR75),
                      .SEQ_INIT_ADDR76               (SEQ_INIT_ADDR76),
                      .SEQ_INIT_ADDR77               (SEQ_INIT_ADDR77),
                      .SEQ_INIT_ADDR78               (SEQ_INIT_ADDR78),
                      .SEQ_INIT_ADDR79               (SEQ_INIT_ADDR79),
                      .SEQ_INIT_ADDR8               (SEQ_INIT_ADDR8),
                      .SEQ_INIT_ADDR80               (SEQ_INIT_ADDR80),
                      .SEQ_INIT_ADDR81               (SEQ_INIT_ADDR81),
                      .SEQ_INIT_ADDR82               (SEQ_INIT_ADDR82),
                      .SEQ_INIT_ADDR83               (SEQ_INIT_ADDR83),
                      .SEQ_INIT_ADDR84               (SEQ_INIT_ADDR84),
                      .SEQ_INIT_ADDR85               (SEQ_INIT_ADDR85),
                      .SEQ_INIT_ADDR86               (SEQ_INIT_ADDR86),
                      .SEQ_INIT_ADDR87               (SEQ_INIT_ADDR87),
                      .SEQ_INIT_ADDR88               (SEQ_INIT_ADDR88),
                      .SEQ_INIT_ADDR89               (SEQ_INIT_ADDR89),
                      .SEQ_INIT_ADDR9               (SEQ_INIT_ADDR9),
                      .SEQ_INIT_ADDR90               (SEQ_INIT_ADDR90),
                      .SEQ_INIT_ADDR91               (SEQ_INIT_ADDR91),
                      .SEQ_INIT_ADDR92               (SEQ_INIT_ADDR92),
                      .SEQ_INIT_ADDR93               (SEQ_INIT_ADDR93),
                      .SEQ_INIT_ADDR94               (SEQ_INIT_ADDR94),
                      .SEQ_INIT_ADDR95               (SEQ_INIT_ADDR95),
                      .SEQ_INIT_ADDR96               (SEQ_INIT_ADDR96),
                      .SEQ_INIT_ADDR97               (SEQ_INIT_ADDR97),
                      .SEQ_INIT_ADDR98               (SEQ_INIT_ADDR98),
                      .SEQ_INIT_ADDR99               (SEQ_INIT_ADDR99),
                      .SEQ_INIT_CMD0               (SEQ_INIT_CMD0),
                      .SEQ_INIT_CMD1               (SEQ_INIT_CMD1),
                      .SEQ_INIT_CMD10               (SEQ_INIT_CMD10),
                      .SEQ_INIT_CMD11               (SEQ_INIT_CMD11),
                      .SEQ_INIT_CMD12               (SEQ_INIT_CMD12),
                      .SEQ_INIT_CMD13               (SEQ_INIT_CMD13),
                      .SEQ_INIT_CMD14               (SEQ_INIT_CMD14),
                      .SEQ_INIT_CMD15               (SEQ_INIT_CMD15),
                      .SEQ_INIT_CMD16               (SEQ_INIT_CMD16),
                      .SEQ_INIT_CMD17               (SEQ_INIT_CMD17),
                      .SEQ_INIT_CMD18               (SEQ_INIT_CMD18),
                      .SEQ_INIT_CMD19               (SEQ_INIT_CMD19),
                      .SEQ_INIT_CMD2               (SEQ_INIT_CMD2),
                      .SEQ_INIT_CMD20               (SEQ_INIT_CMD20),
                      .SEQ_INIT_CMD21               (SEQ_INIT_CMD21),
                      .SEQ_INIT_CMD22               (SEQ_INIT_CMD22),
                      .SEQ_INIT_CMD23               (SEQ_INIT_CMD23),
                      .SEQ_INIT_CMD24               (SEQ_INIT_CMD24),
                      .SEQ_INIT_CMD25               (SEQ_INIT_CMD25),
                      .SEQ_INIT_CMD26               (SEQ_INIT_CMD26),
                      .SEQ_INIT_CMD27               (SEQ_INIT_CMD27),
                      .SEQ_INIT_CMD28               (SEQ_INIT_CMD28),
                      .SEQ_INIT_CMD29               (SEQ_INIT_CMD29),
                      .SEQ_INIT_CMD3               (SEQ_INIT_CMD3),
                      .SEQ_INIT_CMD30               (SEQ_INIT_CMD30),
                      .SEQ_INIT_CMD31               (SEQ_INIT_CMD31),
                      .SEQ_INIT_CMD32               (SEQ_INIT_CMD32),
                      .SEQ_INIT_CMD33               (SEQ_INIT_CMD33),
                      .SEQ_INIT_CMD34               (SEQ_INIT_CMD34),
                      .SEQ_INIT_CMD35               (SEQ_INIT_CMD35),
                      .SEQ_INIT_CMD36               (SEQ_INIT_CMD36),
                      .SEQ_INIT_CMD37               (SEQ_INIT_CMD37),
                      .SEQ_INIT_CMD38               (SEQ_INIT_CMD38),
                      .SEQ_INIT_CMD39               (SEQ_INIT_CMD39),
                      .SEQ_INIT_CMD4               (SEQ_INIT_CMD4),
                      .SEQ_INIT_CMD40               (SEQ_INIT_CMD40),
                      .SEQ_INIT_CMD41               (SEQ_INIT_CMD41),
                      .SEQ_INIT_CMD42               (SEQ_INIT_CMD42),
                      .SEQ_INIT_CMD43               (SEQ_INIT_CMD43),
                      .SEQ_INIT_CMD44               (SEQ_INIT_CMD44),
                      .SEQ_INIT_CMD45               (SEQ_INIT_CMD45),
                      .SEQ_INIT_CMD46               (SEQ_INIT_CMD46),
                      .SEQ_INIT_CMD47               (SEQ_INIT_CMD47),
                      .SEQ_INIT_CMD48               (SEQ_INIT_CMD48),
                      .SEQ_INIT_CMD49               (SEQ_INIT_CMD49),
                      .SEQ_INIT_CMD5               (SEQ_INIT_CMD5),
                      .SEQ_INIT_CMD50               (SEQ_INIT_CMD50),
                      .SEQ_INIT_CMD51               (SEQ_INIT_CMD51),
                      .SEQ_INIT_CMD52               (SEQ_INIT_CMD52),
                      .SEQ_INIT_CMD53               (SEQ_INIT_CMD53),
                      .SEQ_INIT_CMD54               (SEQ_INIT_CMD54),
                      .SEQ_INIT_CMD55               (SEQ_INIT_CMD55),
                      .SEQ_INIT_CMD56               (SEQ_INIT_CMD56),
                      .SEQ_INIT_CMD57               (SEQ_INIT_CMD57),
                      .SEQ_INIT_CMD58               (SEQ_INIT_CMD58),
                      .SEQ_INIT_CMD59               (SEQ_INIT_CMD59),
                      .SEQ_INIT_CMD6               (SEQ_INIT_CMD6),
                      .SEQ_INIT_CMD60               (SEQ_INIT_CMD60),
                      .SEQ_INIT_CMD61               (SEQ_INIT_CMD61),
                      .SEQ_INIT_CMD62               (SEQ_INIT_CMD62),
                      .SEQ_INIT_CMD63               (SEQ_INIT_CMD63),
                      .SEQ_INIT_CMD64               (SEQ_INIT_CMD64),
                      .SEQ_INIT_CMD65               (SEQ_INIT_CMD65),
                      .SEQ_INIT_CMD66               (SEQ_INIT_CMD66),
                      .SEQ_INIT_CMD67               (SEQ_INIT_CMD67),
                      .SEQ_INIT_CMD68               (SEQ_INIT_CMD68),
                      .SEQ_INIT_CMD69               (SEQ_INIT_CMD69),
                      .SEQ_INIT_CMD7               (SEQ_INIT_CMD7),
                      .SEQ_INIT_CMD70               (SEQ_INIT_CMD70),
                      .SEQ_INIT_CMD71               (SEQ_INIT_CMD71),
                      .SEQ_INIT_CMD72               (SEQ_INIT_CMD72),
                      .SEQ_INIT_CMD73               (SEQ_INIT_CMD73),
                      .SEQ_INIT_CMD74               (SEQ_INIT_CMD74),
                      .SEQ_INIT_CMD75               (SEQ_INIT_CMD75),
                      .SEQ_INIT_CMD76               (SEQ_INIT_CMD76),
                      .SEQ_INIT_CMD77               (SEQ_INIT_CMD77),
                      .SEQ_INIT_CMD78               (SEQ_INIT_CMD78),
                      .SEQ_INIT_CMD79               (SEQ_INIT_CMD79),
                      .SEQ_INIT_CMD8               (SEQ_INIT_CMD8),
                      .SEQ_INIT_CMD80               (SEQ_INIT_CMD80),
                      .SEQ_INIT_CMD81               (SEQ_INIT_CMD81),
                      .SEQ_INIT_CMD82               (SEQ_INIT_CMD82),
                      .SEQ_INIT_CMD83               (SEQ_INIT_CMD83),
                      .SEQ_INIT_CMD84               (SEQ_INIT_CMD84),
                      .SEQ_INIT_CMD85               (SEQ_INIT_CMD85),
                      .SEQ_INIT_CMD86               (SEQ_INIT_CMD86),
                      .SEQ_INIT_CMD87               (SEQ_INIT_CMD87),
                      .SEQ_INIT_CMD88               (SEQ_INIT_CMD88),
                      .SEQ_INIT_CMD89               (SEQ_INIT_CMD89),
                      .SEQ_INIT_CMD9               (SEQ_INIT_CMD9),
                      .SEQ_INIT_CMD90               (SEQ_INIT_CMD90),
                      .SEQ_INIT_CMD91               (SEQ_INIT_CMD91),
                      .SEQ_INIT_CMD92               (SEQ_INIT_CMD92),
                      .SEQ_INIT_CMD93               (SEQ_INIT_CMD93),
                      .SEQ_INIT_CMD94               (SEQ_INIT_CMD94),
                      .SEQ_INIT_CMD95               (SEQ_INIT_CMD95),
                      .SEQ_INIT_CMD96               (SEQ_INIT_CMD96),
                      .SEQ_INIT_CMD97               (SEQ_INIT_CMD97),
                      .SEQ_INIT_CMD98               (SEQ_INIT_CMD98),
                      .SEQ_INIT_CMD99               (SEQ_INIT_CMD99),
                      .SEQ_INIT_CMD_SET             (SEQ_INIT_CMD_SET),
                      .SEQ_INIT_CMD_VALID           (SEQ_INIT_CMD_VALID),
                      .SEQ_INIT_CNTRL0               (SEQ_INIT_CNTRL0),
                      .SEQ_INIT_CNTRL1               (SEQ_INIT_CNTRL1),
                      .SEQ_INIT_CNTRL10               (SEQ_INIT_CNTRL10),
                      .SEQ_INIT_CNTRL11               (SEQ_INIT_CNTRL11),
                      .SEQ_INIT_CNTRL12               (SEQ_INIT_CNTRL12),
                      .SEQ_INIT_CNTRL13               (SEQ_INIT_CNTRL13),
                      .SEQ_INIT_CNTRL14               (SEQ_INIT_CNTRL14),
                      .SEQ_INIT_CNTRL15               (SEQ_INIT_CNTRL15),
                      .SEQ_INIT_CNTRL16               (SEQ_INIT_CNTRL16),
                      .SEQ_INIT_CNTRL17               (SEQ_INIT_CNTRL17),
                      .SEQ_INIT_CNTRL18               (SEQ_INIT_CNTRL18),
                      .SEQ_INIT_CNTRL19               (SEQ_INIT_CNTRL19),
                      .SEQ_INIT_CNTRL2               (SEQ_INIT_CNTRL2),
                      .SEQ_INIT_CNTRL20               (SEQ_INIT_CNTRL20),
                      .SEQ_INIT_CNTRL21               (SEQ_INIT_CNTRL21),
                      .SEQ_INIT_CNTRL22               (SEQ_INIT_CNTRL22),
                      .SEQ_INIT_CNTRL23               (SEQ_INIT_CNTRL23),
                      .SEQ_INIT_CNTRL24               (SEQ_INIT_CNTRL24),
                      .SEQ_INIT_CNTRL25               (SEQ_INIT_CNTRL25),
                      .SEQ_INIT_CNTRL26               (SEQ_INIT_CNTRL26),
                      .SEQ_INIT_CNTRL27               (SEQ_INIT_CNTRL27),
                      .SEQ_INIT_CNTRL28               (SEQ_INIT_CNTRL28),
                      .SEQ_INIT_CNTRL29               (SEQ_INIT_CNTRL29),
                      .SEQ_INIT_CNTRL3               (SEQ_INIT_CNTRL3),
                      .SEQ_INIT_CNTRL30               (SEQ_INIT_CNTRL30),
                      .SEQ_INIT_CNTRL31               (SEQ_INIT_CNTRL31),
                      .SEQ_INIT_CNTRL32               (SEQ_INIT_CNTRL32),
                      .SEQ_INIT_CNTRL33               (SEQ_INIT_CNTRL33),
                      .SEQ_INIT_CNTRL34               (SEQ_INIT_CNTRL34),
                      .SEQ_INIT_CNTRL35               (SEQ_INIT_CNTRL35),
                      .SEQ_INIT_CNTRL36               (SEQ_INIT_CNTRL36),
                      .SEQ_INIT_CNTRL37               (SEQ_INIT_CNTRL37),
                      .SEQ_INIT_CNTRL38               (SEQ_INIT_CNTRL38),
                      .SEQ_INIT_CNTRL39               (SEQ_INIT_CNTRL39),
                      .SEQ_INIT_CNTRL4               (SEQ_INIT_CNTRL4),
                      .SEQ_INIT_CNTRL40               (SEQ_INIT_CNTRL40),
                      .SEQ_INIT_CNTRL41               (SEQ_INIT_CNTRL41),
                      .SEQ_INIT_CNTRL42               (SEQ_INIT_CNTRL42),
                      .SEQ_INIT_CNTRL43               (SEQ_INIT_CNTRL43),
                      .SEQ_INIT_CNTRL44               (SEQ_INIT_CNTRL44),
                      .SEQ_INIT_CNTRL45               (SEQ_INIT_CNTRL45),
                      .SEQ_INIT_CNTRL46               (SEQ_INIT_CNTRL46),
                      .SEQ_INIT_CNTRL47               (SEQ_INIT_CNTRL47),
                      .SEQ_INIT_CNTRL48               (SEQ_INIT_CNTRL48),
                      .SEQ_INIT_CNTRL49               (SEQ_INIT_CNTRL49),
                      .SEQ_INIT_CNTRL5               (SEQ_INIT_CNTRL5),
                      .SEQ_INIT_CNTRL50               (SEQ_INIT_CNTRL50),
                      .SEQ_INIT_CNTRL51               (SEQ_INIT_CNTRL51),
                      .SEQ_INIT_CNTRL52               (SEQ_INIT_CNTRL52),
                      .SEQ_INIT_CNTRL53               (SEQ_INIT_CNTRL53),
                      .SEQ_INIT_CNTRL54               (SEQ_INIT_CNTRL54),
                      .SEQ_INIT_CNTRL55               (SEQ_INIT_CNTRL55),
                      .SEQ_INIT_CNTRL56               (SEQ_INIT_CNTRL56),
                      .SEQ_INIT_CNTRL57               (SEQ_INIT_CNTRL57),
                      .SEQ_INIT_CNTRL58               (SEQ_INIT_CNTRL58),
                      .SEQ_INIT_CNTRL59               (SEQ_INIT_CNTRL59),
                      .SEQ_INIT_CNTRL6               (SEQ_INIT_CNTRL6),
                      .SEQ_INIT_CNTRL60               (SEQ_INIT_CNTRL60),
                      .SEQ_INIT_CNTRL61               (SEQ_INIT_CNTRL61),
                      .SEQ_INIT_CNTRL62               (SEQ_INIT_CNTRL62),
                      .SEQ_INIT_CNTRL63               (SEQ_INIT_CNTRL63),
                      .SEQ_INIT_CNTRL64               (SEQ_INIT_CNTRL64),
                      .SEQ_INIT_CNTRL65               (SEQ_INIT_CNTRL65),
                      .SEQ_INIT_CNTRL66               (SEQ_INIT_CNTRL66),
                      .SEQ_INIT_CNTRL67               (SEQ_INIT_CNTRL67),
                      .SEQ_INIT_CNTRL68               (SEQ_INIT_CNTRL68),
                      .SEQ_INIT_CNTRL69               (SEQ_INIT_CNTRL69),
                      .SEQ_INIT_CNTRL7               (SEQ_INIT_CNTRL7),
                      .SEQ_INIT_CNTRL70               (SEQ_INIT_CNTRL70),
                      .SEQ_INIT_CNTRL71               (SEQ_INIT_CNTRL71),
                      .SEQ_INIT_CNTRL72               (SEQ_INIT_CNTRL72),
                      .SEQ_INIT_CNTRL73               (SEQ_INIT_CNTRL73),
                      .SEQ_INIT_CNTRL74               (SEQ_INIT_CNTRL74),
                      .SEQ_INIT_CNTRL75               (SEQ_INIT_CNTRL75),
                      .SEQ_INIT_CNTRL76               (SEQ_INIT_CNTRL76),
                      .SEQ_INIT_CNTRL77               (SEQ_INIT_CNTRL77),
                      .SEQ_INIT_CNTRL78               (SEQ_INIT_CNTRL78),
                      .SEQ_INIT_CNTRL79               (SEQ_INIT_CNTRL79),
                      .SEQ_INIT_CNTRL8               (SEQ_INIT_CNTRL8),
                      .SEQ_INIT_CNTRL80               (SEQ_INIT_CNTRL80),
                      .SEQ_INIT_CNTRL81               (SEQ_INIT_CNTRL81),
                      .SEQ_INIT_CNTRL82               (SEQ_INIT_CNTRL82),
                      .SEQ_INIT_CNTRL83               (SEQ_INIT_CNTRL83),
                      .SEQ_INIT_CNTRL84                (SEQ_INIT_CNTRL84),
                      .SEQ_INIT_CNTRL85                (SEQ_INIT_CNTRL85),
                      .SEQ_INIT_CNTRL86                (SEQ_INIT_CNTRL86),
                      .SEQ_INIT_CNTRL87                (SEQ_INIT_CNTRL87),
                      .SEQ_INIT_CNTRL88                (SEQ_INIT_CNTRL88),
                      .SEQ_INIT_CNTRL89                (SEQ_INIT_CNTRL89),
                      .SEQ_INIT_CNTRL9                 (SEQ_INIT_CNTRL9),
                      .SEQ_INIT_CNTRL90                (SEQ_INIT_CNTRL90),
                      .SEQ_INIT_CNTRL91                (SEQ_INIT_CNTRL91),
                      .SEQ_INIT_CNTRL92                (SEQ_INIT_CNTRL92),
                      .SEQ_INIT_CNTRL93               (SEQ_INIT_CNTRL93),
                      .SEQ_INIT_CNTRL94               (SEQ_INIT_CNTRL94),
                      .SEQ_INIT_CNTRL95               (SEQ_INIT_CNTRL95),
                      .SEQ_INIT_CNTRL96               (SEQ_INIT_CNTRL96),
                      .SEQ_INIT_CNTRL97               (SEQ_INIT_CNTRL97),
                      .SEQ_INIT_CNTRL98               (SEQ_INIT_CNTRL98),
                      .SEQ_INIT_CNTRL99               (SEQ_INIT_CNTRL99),
                      .SEQ_INIT_CONFIG                (SEQ_INIT_CONFIG),
                      .SEQ_MODE                       (SEQ_MODE),
                      .TXNQ_RD_PRIORITY               (TXNQ_RD_PRIORITY),
                      .TXNQ_WR_PRIORITY               (TXNQ_WR_PRIORITY),
                      .T_TXBIT                        (T_TXBIT),
                      .UB_CLK_MUX                     (UB_CLK_MUX),
                      .XMPU_CONFIG0                   (XMPU_CONFIG0),
                      .XMPU_CONFIG1                   (XMPU_CONFIG1),
                      .XMPU_CONFIG10                  (XMPU_CONFIG10),
                      .XMPU_CONFIG11                  (XMPU_CONFIG11),
                      .XMPU_CONFIG12                  (XMPU_CONFIG12),
                      .XMPU_CONFIG13                  (XMPU_CONFIG13),
                      .XMPU_CONFIG14                  (XMPU_CONFIG14),
                      .XMPU_CONFIG15                  (XMPU_CONFIG15),
                      .XMPU_CONFIG2                   (XMPU_CONFIG2),
                      .XMPU_CONFIG3                   (XMPU_CONFIG3),
                      .XMPU_CONFIG4                   (XMPU_CONFIG4),
                      .XMPU_CONFIG5                   (XMPU_CONFIG5),
                      .XMPU_CONFIG6                   (XMPU_CONFIG6),
                      .XMPU_CONFIG7                   (XMPU_CONFIG7),
                      .XMPU_CONFIG8                   (XMPU_CONFIG8),
                      .XMPU_CONFIG9                   (XMPU_CONFIG9),
                      .XMPU_CTRL                      (XMPU_CTRL),
                      .XMPU_END_HI0                   (XMPU_END_HI0),
                      .XMPU_END_HI1                   (XMPU_END_HI1),
                      .XMPU_END_HI10                  (XMPU_END_HI10),
                      .XMPU_END_HI11                  (XMPU_END_HI11),
                      .XMPU_END_HI12                  (XMPU_END_HI12),
                      .XMPU_END_HI13                  (XMPU_END_HI13),
                      .XMPU_END_HI14                  (XMPU_END_HI14),
                      .XMPU_END_HI15                  (XMPU_END_HI15),
                      .XMPU_END_HI2                   (XMPU_END_HI2),
                      .XMPU_END_HI3                   (XMPU_END_HI3),
                      .XMPU_END_HI4                   (XMPU_END_HI4),
                      .XMPU_END_HI5                   (XMPU_END_HI5),
                      .XMPU_END_HI6                   (XMPU_END_HI6),
                      .XMPU_END_HI7                   (XMPU_END_HI7),
                      .XMPU_END_HI8                   (XMPU_END_HI8),
                      .XMPU_END_HI9                   (XMPU_END_HI9),
                      .XMPU_END_LO0                   (XMPU_END_LO0),
                      .XMPU_END_LO1                   (XMPU_END_LO1),
                      .XMPU_END_LO10                  (XMPU_END_LO10),
                      .XMPU_END_LO11                  (XMPU_END_LO11),
                      .XMPU_END_LO12                  (XMPU_END_LO12),
                      .XMPU_END_LO13                  (XMPU_END_LO13),
                      .XMPU_END_LO14                  (XMPU_END_LO14),
                      .XMPU_END_LO15                  (XMPU_END_LO15),
                      .XMPU_END_LO2                   (XMPU_END_LO2),
                      .XMPU_END_LO3                   (XMPU_END_LO3),
                      .XMPU_END_LO4                   (XMPU_END_LO4),
                      .XMPU_END_LO5                   (XMPU_END_LO5),
                      .XMPU_END_LO6                   (XMPU_END_LO6),
                      .XMPU_END_LO7                   (XMPU_END_LO7),
                      .XMPU_END_LO8                   (XMPU_END_LO8),
                      .XMPU_END_LO9                   (XMPU_END_LO9),
                      .XMPU_MASTER0                   (XMPU_MASTER0),
                      .XMPU_MASTER1                   (XMPU_MASTER1),
                      .XMPU_MASTER10                  (XMPU_MASTER10),
                      .XMPU_MASTER11                  (XMPU_MASTER11),
                      .XMPU_MASTER12                  (XMPU_MASTER12),
                      .XMPU_MASTER13                  (XMPU_MASTER13),
                      .XMPU_MASTER14                  (XMPU_MASTER14),
                      .XMPU_MASTER15                  (XMPU_MASTER15),
                      .XMPU_MASTER2                   (XMPU_MASTER2),
                      .XMPU_MASTER3                   (XMPU_MASTER3),
                      .XMPU_MASTER4                   (XMPU_MASTER4),
                      .XMPU_MASTER5                   (XMPU_MASTER5),
                      .XMPU_MASTER6                   (XMPU_MASTER6),
                      .XMPU_MASTER7                   (XMPU_MASTER7),
                      .XMPU_MASTER8                   (XMPU_MASTER8),
                      .XMPU_MASTER9                   (XMPU_MASTER9),
                      .XMPU_START_HI0                 (XMPU_START_HI0),
                      .XMPU_START_HI1                 (XMPU_START_HI1),
                      .XMPU_START_HI10                (XMPU_START_HI10),
                      .XMPU_START_HI11                (XMPU_START_HI11),
                      .XMPU_START_HI12                (XMPU_START_HI12),
                      .XMPU_START_HI13                (XMPU_START_HI13),
                      .XMPU_START_HI14                (XMPU_START_HI14),
                      .XMPU_START_HI15                (XMPU_START_HI15),
                      .XMPU_START_HI2                 (XMPU_START_HI2),
                      .XMPU_START_HI3                 (XMPU_START_HI3),
                      .XMPU_START_HI4                 (XMPU_START_HI4),
                      .XMPU_START_HI5                 (XMPU_START_HI5),
                      .XMPU_START_HI6                 (XMPU_START_HI6),
                      .XMPU_START_HI7                 (XMPU_START_HI7),
                      .XMPU_START_HI8                 (XMPU_START_HI8),
                      .XMPU_START_HI9                 (XMPU_START_HI9),
                      .XMPU_START_LO0                 (XMPU_START_LO0),
                      .XMPU_START_LO1                 (XMPU_START_LO1),
                      .XMPU_START_LO10                (XMPU_START_LO10),
                      .XMPU_START_LO11                (XMPU_START_LO11),
                      .XMPU_START_LO12                (XMPU_START_LO12),
                      .XMPU_START_LO13                (XMPU_START_LO13),
                      .XMPU_START_LO14                (XMPU_START_LO14),
                      .XMPU_START_LO15                (XMPU_START_LO15),
                      .XMPU_START_LO2                 (XMPU_START_LO2),
                      .XMPU_START_LO3                 (XMPU_START_LO3),
                      .XMPU_START_LO4                 (XMPU_START_LO4),
                      .XMPU_START_LO5                 (XMPU_START_LO5),
                      .XMPU_START_LO6                 (XMPU_START_LO6),
                      .XMPU_START_LO7                 (XMPU_START_LO7),
                      .XMPU_START_LO8                 (XMPU_START_LO8),
                      .XMPU_START_LO9                 (XMPU_START_LO9),
                      .XPI_DATA_NIB_CHAN              (XPI_DATA_NIB_CHAN),
                      .XPI_DQS                        (XPI_DQS),
                      .XPI_NIB_CHAN                   (XPI_NIB_CHAN),
                      .XPI_OE                         (XPI_OE),
                      .XPI_OE_ALL_NIB                 (XPI_OE_ALL_NIB),
                      .XPI_PMI_CONFIG                 (XPI_PMI_CONFIG),
                      .XPI_READ_DBI                   (XPI_READ_DBI),
                      .XPI_READ_OFFSET                (XPI_READ_OFFSET),
                      .XPI_WRDATA_ALL_NIB             (XPI_WRDATA_ALL_NIB),
                      .XPI_WRITE_DM_DBI               (XPI_WRITE_DM_DBI),
                      .ADDR_WIDTH(ADDR_WIDTH),
                      .BANK_WIDTH(BA_WIDTH),
                      .BANK_GROUP_WIDTH(BG_WIDTH),
                      .CKE_WIDTH(CKE_WIDTH),
                      .ODT_WIDTH(ODT_WIDTH),
                      .CS_WIDTH(CS_WIDTH),
                      .LRANK_WIDTH(LR_WIDTH),
                      .CK_WIDTH(CK_WIDTH),
                      .DM_WIDTH(DM_WIDTH),
                      .DQ_WIDTH(DQ_WIDTH),
                      .DQS_WIDTH(DQS_WIDTH),
                      .NUM_OF_CHS(NUM_CHANNELS),
                      .MC_TREFI(7800000),
                      .MC_REFRESH_RATE("1x"),
                      .NOC_FREQ(NOC_FREQ),
                      .XLNX_RESPONDER(XLNX_RESPONDER),
                      .CA_MIRROR(CA_MIRROR),
                      .TCK(TCK)
                      )  u_ddr4mc_top (
                           .pll_rst_n             ()                 
                          ,.pll_clk               (pll_clk_xpll)
                          ,.mc_rst_n              ()
                          ,.mc_clk                (mc_clk_xpll)
                          ,.noc_rst_n             ()
                          ,.noc_clk               ()
                          ,.noc2dmc_valid_in_0    (noc2dmc_valid_in_0)   
                          ,.noc2dmc_data_in_0     (noc2dmc_data_in_0)
                          ,.noc2dmc_credit_rdy_0  (noc2dmc_credit_rdy_0)
                          ,.dmc2noc_credit_rtn_0  (dmc2noc_credit_rtn_0)
                          ,.noc2dmc_valid_in_1    (noc2dmc_valid_in_1)
                          ,.noc2dmc_data_in_1     (noc2dmc_data_in_1)
                          ,.noc2dmc_credit_rdy_1  (noc2dmc_credit_rdy_1)
                          ,.dmc2noc_credit_rtn_1  (dmc2noc_credit_rtn_1)
                          ,.noc2dmc_valid_in_2    (noc2dmc_valid_in_2)
                          ,.noc2dmc_data_in_2     (noc2dmc_data_in_2)
                          ,.noc2dmc_credit_rdy_2  (noc2dmc_credit_rdy_2)
                          ,.dmc2noc_credit_rtn_2  (dmc2noc_credit_rtn_2)
                          ,.noc2dmc_valid_in_3    (noc2dmc_valid_in_3)
                          ,.noc2dmc_data_in_3     (noc2dmc_data_in_3)
                          ,.noc2dmc_credit_rdy_3  (noc2dmc_credit_rdy_3)
                          ,.dmc2noc_credit_rtn_3  (dmc2noc_credit_rtn_3)
                          ,.dmc2noc_valid_out_0   (dmc2noc_valid_out_0)
                          ,.dmc2noc_data_out_0    (dmc2noc_data_out_0)
                          ,.dmc2noc_credit_rdy_0  (dmc2noc_credit_rdy_0)
                          ,.noc2dmc_credit_rtn_0  (noc2dmc_credit_rtn_0)
                          ,.dmc2noc_valid_out_1   (dmc2noc_valid_out_1)
                          ,.dmc2noc_data_out_1    (dmc2noc_data_out_1)
                          ,.dmc2noc_credit_rdy_1  (dmc2noc_credit_rdy_1)
                          ,.noc2dmc_credit_rtn_1  (noc2dmc_credit_rtn_1)
                          ,.dmc2noc_valid_out_2   (dmc2noc_valid_out_2)
                          ,.dmc2noc_data_out_2    (dmc2noc_data_out_2)
                          ,.dmc2noc_credit_rdy_2  (dmc2noc_credit_rdy_2)
                          ,.noc2dmc_credit_rtn_2  (noc2dmc_credit_rtn_2)
                          ,.dmc2noc_valid_out_3   (dmc2noc_valid_out_3)
                          ,.dmc2noc_data_out_3    (dmc2noc_data_out_3)
                          ,.dmc2noc_credit_rdy_3  (dmc2noc_credit_rdy_3)
                          ,.noc2dmc_credit_rtn_3  (noc2dmc_credit_rtn_3)
                          ,.ch0_ddr4_act_n(ch0_ddr4_act_n)
                          ,.ch0_ddr4_adr(ch0_ddr4_adr)
                          ,.ch0_ddr4_ba(ch0_ddr4_ba)
                          ,.ch0_ddr4_bg(ch0_ddr4_bg)
                          ,.ch0_ddr4_cke(ch0_ddr4_cke)
                          ,.ch0_ddr4_odt(ch0_ddr4_odt)
                          ,.ch0_ddr4_cs_n(ch0_ddr4_cs_n)
                          ,.ch0_ddr4_ck_t(ch0_ddr4_ck_t)
                          ,.ch0_ddr4_ck_c(ch0_ddr4_ck_c)
                          ,.ch0_ddr4_reset_n(ch0_ddr4_reset_n)
                          ,.ch0_ddr4_dm_dbi_n(ch0_ddr4_dm_dbi_n)
                          ,.ch0_ddr4_dq(ch0_ddr4_dq)
                          ,.ch0_ddr4_dqs_c(ch0_ddr4_dqs_c)
                          ,.ch0_ddr4_dqs_t(ch0_ddr4_dqs_t)
 );
//synthesis translate_off
defparam u_ddr4mc_top.ddrmc_reg_u.IP_NAME = "bd_8be5_MC0_ddrc_0";
defparam u_ddr4mc_top.ddrmc_reg_u.REG_FILE = "nocattrs.dat";
//synthesis translate_on


`else 
(* DONT_TOUCH = "TRUE", DDRMC_CAL_MASK_POLL = "ENABLE" *) DDRMC 
#(
                      .ARBITER_CONFIG               (ARBITER_CONFIG),
                      .CAL_CS_CH                    (CAL_CS_CH),
                      .CAL_MODE                     (CAL_MODE),
                      .CLK_GATE                     (CLK_GATE),
                      .CPLX_BURST_ARRAY0            (CPLX_BURST_ARRAY0),
                      .CPLX_BURST_ARRAY1            (CPLX_BURST_ARRAY1),
                      .CPLX_BURST_ARRAY10           (CPLX_BURST_ARRAY10),
                      .CPLX_BURST_ARRAY11           (CPLX_BURST_ARRAY11),
                      .CPLX_BURST_ARRAY12           (CPLX_BURST_ARRAY12),
                      .CPLX_BURST_ARRAY13           (CPLX_BURST_ARRAY13),
                      .CPLX_BURST_ARRAY14           (CPLX_BURST_ARRAY14),
                      .CPLX_BURST_ARRAY15           (CPLX_BURST_ARRAY15),
                      .CPLX_BURST_ARRAY16           (CPLX_BURST_ARRAY16),
                      .CPLX_BURST_ARRAY17           (CPLX_BURST_ARRAY17),
                      .CPLX_BURST_ARRAY18           (CPLX_BURST_ARRAY18),
                      .CPLX_BURST_ARRAY19           (CPLX_BURST_ARRAY19),
                      .CPLX_BURST_ARRAY2            (CPLX_BURST_ARRAY2),
                      .CPLX_BURST_ARRAY20           (CPLX_BURST_ARRAY20),
                      .CPLX_BURST_ARRAY21           (CPLX_BURST_ARRAY21),
                      .CPLX_BURST_ARRAY22           (CPLX_BURST_ARRAY22),
                      .CPLX_BURST_ARRAY3            (CPLX_BURST_ARRAY3),
                      .CPLX_BURST_ARRAY4            (CPLX_BURST_ARRAY4),
                      .CPLX_BURST_ARRAY5            (CPLX_BURST_ARRAY5),
                      .CPLX_BURST_ARRAY6            (CPLX_BURST_ARRAY6),
                      .CPLX_BURST_ARRAY7            (CPLX_BURST_ARRAY7),
                      .CPLX_BURST_ARRAY8            (CPLX_BURST_ARRAY8),
                      .CPLX_BURST_ARRAY9            (CPLX_BURST_ARRAY9),
                      .CPLX_CONFIG                  (CPLX_CONFIG),
                      .CPLX_CONFIG2                 (CPLX_CONFIG2),
                      .CPLX_CONFIG3                 (CPLX_CONFIG3),
                      .CPLX_PATTERN0                (CPLX_PATTERN0),
                      .CPLX_PATTERN1                (CPLX_PATTERN1),
                      .CPLX_PATTERN10               (CPLX_PATTERN10),
                      .CPLX_PATTERN100              (CPLX_PATTERN100),
                      .CPLX_PATTERN101              (CPLX_PATTERN101),
                      .CPLX_PATTERN102              (CPLX_PATTERN102),
                      .CPLX_PATTERN103              (CPLX_PATTERN103),
                      .CPLX_PATTERN104              (CPLX_PATTERN104),
                      .CPLX_PATTERN105              (CPLX_PATTERN105),
                      .CPLX_PATTERN106              (CPLX_PATTERN106),
                      .CPLX_PATTERN107              (CPLX_PATTERN107),
                      .CPLX_PATTERN108              (CPLX_PATTERN108),
                      .CPLX_PATTERN109              (CPLX_PATTERN109),
                      .CPLX_PATTERN11               (CPLX_PATTERN11),
                      .CPLX_PATTERN110              (CPLX_PATTERN110),
                      .CPLX_PATTERN111              (CPLX_PATTERN111),
                      .CPLX_PATTERN112              (CPLX_PATTERN112),
                      .CPLX_PATTERN113              (CPLX_PATTERN113),
                      .CPLX_PATTERN114              (CPLX_PATTERN114),
                      .CPLX_PATTERN115              (CPLX_PATTERN115),
                      .CPLX_PATTERN116              (CPLX_PATTERN116),
                      .CPLX_PATTERN117              (CPLX_PATTERN117),
                      .CPLX_PATTERN118              (CPLX_PATTERN118),
                      .CPLX_PATTERN119              (CPLX_PATTERN119),
                      .CPLX_PATTERN12               (CPLX_PATTERN12),
                      .CPLX_PATTERN120              (CPLX_PATTERN120),
                      .CPLX_PATTERN121              (CPLX_PATTERN121),
                      .CPLX_PATTERN122              (CPLX_PATTERN122),
                      .CPLX_PATTERN123              (CPLX_PATTERN123),
                      .CPLX_PATTERN124              (CPLX_PATTERN124),
                      .CPLX_PATTERN125              (CPLX_PATTERN125),
                      .CPLX_PATTERN126              (CPLX_PATTERN126),
                      .CPLX_PATTERN127              (CPLX_PATTERN127),
                      .CPLX_PATTERN128              (CPLX_PATTERN128),
                      .CPLX_PATTERN129              (CPLX_PATTERN129),
                      .CPLX_PATTERN13               (CPLX_PATTERN13),
                      .CPLX_PATTERN130              (CPLX_PATTERN130),
                      .CPLX_PATTERN131              (CPLX_PATTERN131),
                      .CPLX_PATTERN132              (CPLX_PATTERN132),
                      .CPLX_PATTERN133              (CPLX_PATTERN133),
                      .CPLX_PATTERN134              (CPLX_PATTERN134),
                      .CPLX_PATTERN135              (CPLX_PATTERN135),
                      .CPLX_PATTERN136              (CPLX_PATTERN136),
                      .CPLX_PATTERN137              (CPLX_PATTERN137),
                      .CPLX_PATTERN138              (CPLX_PATTERN138),
                      .CPLX_PATTERN139              (CPLX_PATTERN139),
                      .CPLX_PATTERN14               (CPLX_PATTERN14),
                      .CPLX_PATTERN140              (CPLX_PATTERN140),
                      .CPLX_PATTERN141              (CPLX_PATTERN141),
                      .CPLX_PATTERN142              (CPLX_PATTERN142),
                      .CPLX_PATTERN143              (CPLX_PATTERN143),
                      .CPLX_PATTERN144              (CPLX_PATTERN144),
                      .CPLX_PATTERN145              (CPLX_PATTERN145),
                      .CPLX_PATTERN146              (CPLX_PATTERN146),
                      .CPLX_PATTERN147              (CPLX_PATTERN147),
                      .CPLX_PATTERN148              (CPLX_PATTERN148),
                      .CPLX_PATTERN149              (CPLX_PATTERN149),
                      .CPLX_PATTERN15               (CPLX_PATTERN15),
                      .CPLX_PATTERN150              (CPLX_PATTERN150),
                      .CPLX_PATTERN151              (CPLX_PATTERN151),
                      .CPLX_PATTERN152              (CPLX_PATTERN152),
                      .CPLX_PATTERN153              (CPLX_PATTERN153),
                      .CPLX_PATTERN154              (CPLX_PATTERN154),
                      .CPLX_PATTERN155              (CPLX_PATTERN155),
                      .CPLX_PATTERN156              (CPLX_PATTERN156),
                      .CPLX_PATTERN16               (CPLX_PATTERN16),
                      .CPLX_PATTERN17               (CPLX_PATTERN17),
                      .CPLX_PATTERN18               (CPLX_PATTERN18),
                      .CPLX_PATTERN19               (CPLX_PATTERN19),
                      .CPLX_PATTERN2                (CPLX_PATTERN2),
                      .CPLX_PATTERN20               (CPLX_PATTERN20),
                      .CPLX_PATTERN21               (CPLX_PATTERN21),
                      .CPLX_PATTERN22               (CPLX_PATTERN22),
                      .CPLX_PATTERN23               (CPLX_PATTERN23),
                      .CPLX_PATTERN24               (CPLX_PATTERN24),
                      .CPLX_PATTERN25               (CPLX_PATTERN25),
                      .CPLX_PATTERN26               (CPLX_PATTERN26),
                      .CPLX_PATTERN27               (CPLX_PATTERN27),
                      .CPLX_PATTERN28               (CPLX_PATTERN28),
                      .CPLX_PATTERN29               (CPLX_PATTERN29),
                      .CPLX_PATTERN3                (CPLX_PATTERN3),
                      .CPLX_PATTERN30               (CPLX_PATTERN30),
                      .CPLX_PATTERN31               (CPLX_PATTERN31),
                      .CPLX_PATTERN32               (CPLX_PATTERN32),
                      .CPLX_PATTERN33               (CPLX_PATTERN33),
                      .CPLX_PATTERN34               (CPLX_PATTERN34),
                      .CPLX_PATTERN35               (CPLX_PATTERN35),
                      .CPLX_PATTERN36               (CPLX_PATTERN36),
                      .CPLX_PATTERN37               (CPLX_PATTERN37),
                      .CPLX_PATTERN38               (CPLX_PATTERN38),
                      .CPLX_PATTERN39               (CPLX_PATTERN39),
                      .CPLX_PATTERN4                (CPLX_PATTERN4),
                      .CPLX_PATTERN40               (CPLX_PATTERN40),
                      .CPLX_PATTERN41               (CPLX_PATTERN41),
                      .CPLX_PATTERN42               (CPLX_PATTERN42),
                      .CPLX_PATTERN43               (CPLX_PATTERN43),
                      .CPLX_PATTERN44               (CPLX_PATTERN44),
                      .CPLX_PATTERN45               (CPLX_PATTERN45),
                      .CPLX_PATTERN46               (CPLX_PATTERN46),
                      .CPLX_PATTERN47               (CPLX_PATTERN47),
                      .CPLX_PATTERN48               (CPLX_PATTERN48),
                      .CPLX_PATTERN49               (CPLX_PATTERN49),
                      .CPLX_PATTERN5                (CPLX_PATTERN5),
                      .CPLX_PATTERN50               (CPLX_PATTERN50),
                      .CPLX_PATTERN51               (CPLX_PATTERN51),
                      .CPLX_PATTERN52               (CPLX_PATTERN52),
                      .CPLX_PATTERN53               (CPLX_PATTERN53),
                      .CPLX_PATTERN54               (CPLX_PATTERN54),
                      .CPLX_PATTERN55               (CPLX_PATTERN55),
                      .CPLX_PATTERN56               (CPLX_PATTERN56),
                      .CPLX_PATTERN57               (CPLX_PATTERN57),
                      .CPLX_PATTERN58               (CPLX_PATTERN58),
                      .CPLX_PATTERN59               (CPLX_PATTERN59),
                      .CPLX_PATTERN6                (CPLX_PATTERN6),
                      .CPLX_PATTERN60               (CPLX_PATTERN60),
                      .CPLX_PATTERN61               (CPLX_PATTERN61),
                      .CPLX_PATTERN62               (CPLX_PATTERN62),
                      .CPLX_PATTERN63               (CPLX_PATTERN63),
                      .CPLX_PATTERN64               (CPLX_PATTERN64),
                      .CPLX_PATTERN65               (CPLX_PATTERN65),
                      .CPLX_PATTERN66               (CPLX_PATTERN66),
                      .CPLX_PATTERN67               (CPLX_PATTERN67),
                      .CPLX_PATTERN68               (CPLX_PATTERN68),
                      .CPLX_PATTERN69               (CPLX_PATTERN69),
                      .CPLX_PATTERN7                (CPLX_PATTERN7),
                      .CPLX_PATTERN70               (CPLX_PATTERN70),
                      .CPLX_PATTERN71               (CPLX_PATTERN71),
                      .CPLX_PATTERN72               (CPLX_PATTERN72),
                      .CPLX_PATTERN73               (CPLX_PATTERN73),
                      .CPLX_PATTERN74               (CPLX_PATTERN74),
                      .CPLX_PATTERN75               (CPLX_PATTERN75),
                      .CPLX_PATTERN76               (CPLX_PATTERN76),
                      .CPLX_PATTERN77               (CPLX_PATTERN77),
                      .CPLX_PATTERN78               (CPLX_PATTERN78),
                      .CPLX_PATTERN79               (CPLX_PATTERN79),
                      .CPLX_PATTERN8                (CPLX_PATTERN8),
                      .CPLX_PATTERN80               (CPLX_PATTERN80),
                      .CPLX_PATTERN81               (CPLX_PATTERN81),
                      .CPLX_PATTERN82               (CPLX_PATTERN82),
                      .CPLX_PATTERN83               (CPLX_PATTERN83),
                      .CPLX_PATTERN84               (CPLX_PATTERN84),
                      .CPLX_PATTERN85               (CPLX_PATTERN85),
                      .CPLX_PATTERN86               (CPLX_PATTERN86),
                      .CPLX_PATTERN87               (CPLX_PATTERN87),
                      .CPLX_PATTERN88               (CPLX_PATTERN88),
                      .CPLX_PATTERN89               (CPLX_PATTERN89),
                      .CPLX_PATTERN9                (CPLX_PATTERN9),
                      .CPLX_PATTERN90               (CPLX_PATTERN90),
                      .CPLX_PATTERN91               (CPLX_PATTERN91),
                      .CPLX_PATTERN92               (CPLX_PATTERN92),
                      .CPLX_PATTERN93               (CPLX_PATTERN93),
                      .CPLX_PATTERN94               (CPLX_PATTERN94),
                      .CPLX_PATTERN95               (CPLX_PATTERN95),
                      .CPLX_PATTERN96               (CPLX_PATTERN96),
                      .CPLX_PATTERN97               (CPLX_PATTERN97),
                      .CPLX_PATTERN98               (CPLX_PATTERN98),
                      .CPLX_PATTERN99               (CPLX_PATTERN99),
                      .DBG_TRIGGER                  (DBG_TRIGGER),
                      .DC_CMD_CREDITS               (DC_CMD_CREDITS),
                      .DEFAULT_PATTERN              (DEFAULT_PATTERN),
                      .EXMON_CLR_EXE                (EXMON_CLR_EXE), 
                      .FIFO_RDEN                    (FIFO_RDEN),
                      .PHY_RANK_READ_OVERRIDE       (PHY_RANK_READ_OVERRIDE),
                      .PHY_RANK_WRITE_OVERRIDE      (PHY_RANK_WRITE_OVERRIDE),
                      .PHY_RDEN0                    (PHY_RDEN0),
                      .PHY_RDEN1                    (PHY_RDEN1),
                      .PHY_RDEN10                   (PHY_RDEN10),
                      .PHY_RDEN11                   (PHY_RDEN11),
                      .PHY_RDEN12                   (PHY_RDEN12),
                      .PHY_RDEN13                   (PHY_RDEN13),
                      .PHY_RDEN14                   (PHY_RDEN14),
                      .PHY_RDEN15                   (PHY_RDEN15),
                      .PHY_RDEN16                   (PHY_RDEN16),
                      .PHY_RDEN17                   (PHY_RDEN17),
                      .PHY_RDEN18                   (PHY_RDEN18),
                      .PHY_RDEN19                   (PHY_RDEN19),
                      .PHY_RDEN2                    (PHY_RDEN2),
                      .PHY_RDEN20                   (PHY_RDEN20),
                      .PHY_RDEN21                   (PHY_RDEN21),
                      .PHY_RDEN22                   (PHY_RDEN22),
                      .PHY_RDEN23                   (PHY_RDEN23),
                      .PHY_RDEN24                   (PHY_RDEN24),
                      .PHY_RDEN25                   (PHY_RDEN25),
                      .PHY_RDEN26                   (PHY_RDEN26),
                      .PHY_RDEN3                    (PHY_RDEN3),
                      .PHY_RDEN4                    (PHY_RDEN4),
                      .PHY_RDEN5                    (PHY_RDEN5),
                      .PHY_RDEN6                    (PHY_RDEN6),
                      .PHY_RDEN7                    (PHY_RDEN7),
                      .PHY_RDEN8                    (PHY_RDEN8),
                      .PHY_RDEN9                    (PHY_RDEN9),
                      .PRBS_CNT                     (PRBS_CNT),
                      .PRBS_CONFIG                  (PRBS_CONFIG),
                      .PRBS_CONFIG2                 (PRBS_CONFIG2),
                      .PRBS_SEED0                   (PRBS_SEED0),
                      .PRBS_SEED1                   (PRBS_SEED1),
                      .PRBS_SEED2                   (PRBS_SEED2),
                      .PRBS_SEED3                   (PRBS_SEED3),
                      .PRBS_SEED4                   (PRBS_SEED4),
                      .PRBS_SEED5                   (PRBS_SEED5),
                      .PRBS_SEED6                   (PRBS_SEED6),
                      .PRBS_SEED7                   (PRBS_SEED7),
                      .PRBS_SEED8                   (PRBS_SEED8),
                      .RAM_SETTING_RF2PHS           (RAM_SETTING_RF2PHS), 
                      .RAM_SETTING_RFSPHD           (RAM_SETTING_RFSPHD),
                      .RAM_SETTING_SRSPHD           (RAM_SETTING_SRSPHD),
                      .READ_BANDWIDTH               (READ_BANDWIDTH),
                      .REG_ADEC0                    (REG_ADEC0),
                      .REG_ADEC1                    (REG_ADEC1),
                      .REG_ADEC10                   (REG_ADEC10),
                      .REG_ADEC11                   (REG_ADEC11),
                      .REG_ADEC2                    (REG_ADEC2),
                      .REG_ADEC3                    (REG_ADEC3),
                      .REG_ADEC4                    (REG_ADEC4),
                      .REG_ADEC5                    (REG_ADEC5),
                      .REG_ADEC6                    (REG_ADEC6),
                      .REG_ADEC7                    (REG_ADEC7),
                      .REG_ADEC8                    (REG_ADEC8),
                      .REG_ADEC9                    (REG_ADEC9),
                      .REG_CMDQ_BER_RATE_CTRL       (REG_CMDQ_BER_RATE_CTRL),
                      .REG_CMDQ_BEW_RATE_CTRL       (REG_CMDQ_BEW_RATE_CTRL),
                      .REG_CMDQ_CTRL0               (REG_CMDQ_CTRL0),
                      .REG_CMDQ_CTRL1               (REG_CMDQ_CTRL1),
                      .REG_CMDQ_ISR_RATE_CTRL       (REG_CMDQ_ISR_RATE_CTRL),
                      .REG_CMDQ_ISW_RATE_CTRL       (REG_CMDQ_ISW_RATE_CTRL),
                      .REG_CMDQ_LLR_RATE_CTRL       (REG_CMDQ_LLR_RATE_CTRL),
                      .REG_COM_1                    (REG_COM_1),
                      .REG_COM_2                    (REG_COM_2),
                      .REG_COM_3                    (REG_COM_3),
                      .REG_CONFIG0                  (REG_CONFIG0),
                      .REG_CONFIG1                  (REG_CONFIG1),
                      .REG_CONFIG2                  (REG_CONFIG2),
                      .REG_CONFIG3                  (REG_CONFIG3),
                      .REG_CONFIG4                  (REG_CONFIG4),
                      .REG_DRAM_ARB                 (REG_DRAM_ARB),
                      .REG_MRS_0                    (REG_MRS_0),
                      .REG_MRS_1                    (REG_MRS_1),
                      .REG_MRS_2                    (REG_MRS_2),
                      .REG_MRS_7                    (REG_MRS_7),
                      .REG_NSU0_PORT                (REG_NSU0_PORT),
                      .REG_NSU1_PORT                (REG_NSU1_PORT),
                      .REG_NSU2_PORT                (REG_NSU2_PORT),
                      .REG_NSU3_PORT                (REG_NSU3_PORT),
                      .REG_NSU_0_ING                (REG_NSU_0_ING),
                      .REG_NSU_0_EGR                (REG_NSU_0_EGR),
                      .REG_NSU_0_R_EGR              (REG_NSU_0_R_EGR),
                      .REG_NSU_0_W_EGR              (REG_NSU_0_W_EGR),
                      .REG_NSU_1_ING                (REG_NSU_1_ING),
                      .REG_NSU_1_EGR                (REG_NSU_1_EGR),
                      .REG_NSU_1_R_EGR              (REG_NSU_1_R_EGR),
                      .REG_NSU_1_W_EGR              (REG_NSU_1_W_EGR),
                      .REG_NSU_2_ING                (REG_NSU_2_ING),
                      .REG_NSU_2_EGR                (REG_NSU_2_EGR),
                      .REG_NSU_2_R_EGR              (REG_NSU_2_R_EGR),
                      .REG_NSU_2_W_EGR              (REG_NSU_2_W_EGR),
                      .REG_NSU_3_ING                (REG_NSU_3_ING),
                      .REG_NSU_3_EGR                (REG_NSU_3_EGR),
                      .REG_NSU_3_R_EGR              (REG_NSU_3_R_EGR),
                      .REG_NSU_3_W_EGR              (REG_NSU_3_W_EGR),
                      .REG_P0_BER_RATE_CTRL           (REG_P0_BER_RATE_CTRL),
                      .REG_P0_BEW_RATE_CTRL           (REG_P0_BEW_RATE_CTRL),
                      .REG_P0_ISR_RATE_CTRL           (REG_P0_ISR_RATE_CTRL),
                      .REG_P0_ISW_RATE_CTRL           (REG_P0_ISW_RATE_CTRL),
                      .REG_P0_LLR_RATE_CTRL           (REG_P0_LLR_RATE_CTRL),
                      .REG_P1_BER_RATE_CTRL           (REG_P1_BER_RATE_CTRL),
                      .REG_P1_BEW_RATE_CTRL           (REG_P1_BEW_RATE_CTRL),
                      .REG_P1_ISR_RATE_CTRL           (REG_P1_ISR_RATE_CTRL),
                      .REG_P1_ISW_RATE_CTRL           (REG_P1_ISW_RATE_CTRL),
                      .REG_P1_LLR_RATE_CTRL           (REG_P1_LLR_RATE_CTRL),
                      .REG_P2_BER_RATE_CTRL           (REG_P2_BER_RATE_CTRL),
                      .REG_P2_BEW_RATE_CTRL           (REG_P2_BEW_RATE_CTRL),
                      .REG_P2_ISR_RATE_CTRL           (REG_P2_ISR_RATE_CTRL),
                      .REG_P2_ISW_RATE_CTRL           (REG_P2_ISW_RATE_CTRL),
                      .REG_P2_LLR_RATE_CTRL           (REG_P2_LLR_RATE_CTRL),
                      .REG_P3_BER_RATE_CTRL           (REG_P3_BER_RATE_CTRL),
                      .REG_P3_BEW_RATE_CTRL           (REG_P3_BEW_RATE_CTRL),
                      .REG_P3_ISR_RATE_CTRL           (REG_P3_ISR_RATE_CTRL),
                      .REG_P3_ISW_RATE_CTRL           (REG_P3_ISW_RATE_CTRL),
                      .REG_P3_LLR_RATE_CTRL           (REG_P3_LLR_RATE_CTRL),
                      .REG_PINOUT                     (REG_PINOUT),
                      .REG_PT_CONFIG                  (REG_PT_CONFIG),
                      .REG_QOS0                       (REG_QOS0),
                      .REG_QOS1                       (REG_QOS1),
                      .REG_QOS2                       (REG_QOS2),
                      .REG_QOS_RATE_CTRL_SCALE        (REG_QOS_RATE_CTRL_SCALE),
                      .REG_QOS_TIMEOUT0               (REG_QOS_TIMEOUT0),
                      .REG_QOS_TIMEOUT1               (REG_QOS_TIMEOUT1),
                      .REG_QOS_TIMEOUT2               (REG_QOS_TIMEOUT2),
                      .REG_RATE_CTRL_SCALE            (REG_RATE_CTRL_SCALE),
                      .REG_RD_CONFIG                  (REG_RD_CONFIG),
                      .REG_RD_DRR_TKN_P0              (REG_RD_DRR_TKN_P0),
                      .REG_RD_DRR_TKN_P1              (REG_RD_DRR_TKN_P1),
                      .REG_RD_DRR_TKN_P2              (REG_RD_DRR_TKN_P2),
                      .REG_RD_DRR_TKN_P3              (REG_RD_DRR_TKN_P3),
                      .REG_REF_0                      (REG_REF_0),
                      .REG_REF_1                      (REG_REF_1),
                      .REG_REF_2                      (REG_REF_2),
                      .REG_REF_3                      (REG_REF_3),
                      .REG_RETRY_0                    (REG_RETRY_0),
                      .REG_RETRY_1                    (REG_RETRY_1),
                      .REG_SAFE_CONFIG0               (REG_SAFE_CONFIG0),
                      .REG_SAFE_CONFIG1               (REG_SAFE_CONFIG1),
                      .REG_SAFE_CONFIG2               (REG_SAFE_CONFIG2),
                      .REG_SAFE_CONFIG3               (REG_SAFE_CONFIG3),
                      .REG_SAFE_CONFIG4               (REG_SAFE_CONFIG4), 
                      .REG_SAFE_CONFIG5               (REG_SAFE_CONFIG5), 
                      .REG_SAFE_CONFIG6               (REG_SAFE_CONFIG6), 
                      .REG_SAFE_CONFIG7               (REG_SAFE_CONFIG7), 
                      .REG_SAFE_CONFIG8               (REG_SAFE_CONFIG8),
                      .REG_SCRUB0                     (REG_SCRUB0),
                      .REG_SCRUB1                     (REG_SCRUB1),
                      .REG_SCRUB8                     (REG_SCRUB8),
                      .REG_SCRUB9                     (REG_SCRUB9),
                      .REG_TXN_CONFIG                 (REG_TXN_CONFIG),
                      .REG_WR_CONFIG                  (REG_WR_CONFIG),
                      .REG_WR_DRR_TKN_P0              (REG_WR_DRR_TKN_P0),
                      .REG_WR_DRR_TKN_P1              (REG_WR_DRR_TKN_P1),
                      .REG_WR_DRR_TKN_P2              (REG_WR_DRR_TKN_P2),
                      .REG_WR_DRR_TKN_P3              (REG_WR_DRR_TKN_P3),
                      .SEQ_ADDR_DEFAULT               (SEQ_ADDR_DEFAULT),
                      .SEQ_BA_DEFAULT                 (SEQ_BA_DEFAULT),
                      .SEQ_BG_DEFAULT                 (SEQ_BG_DEFAULT),
                      .SEQ_CBIT_DEFAULT               (SEQ_CBIT_DEFAULT),
                      .SEQ_CK_CAL                     (SEQ_CK_CAL),
                      .SEQ_CMD_DEFAULT                (SEQ_CMD_DEFAULT),
                      .SEQ_CMD_POR                    (SEQ_CMD_POR),
                      .SEQ_DQS_DEFAULT               (SEQ_DQS_DEFAULT),
                      .SEQ_DQ_DEFAULT               (SEQ_DQ_DEFAULT),
                      .SEQ_INIT_ADDR0               (SEQ_INIT_ADDR0),
                      .SEQ_INIT_ADDR1               (SEQ_INIT_ADDR1),
                      .SEQ_INIT_ADDR10               (SEQ_INIT_ADDR10),
                      .SEQ_INIT_ADDR11               (SEQ_INIT_ADDR11),
                      .SEQ_INIT_ADDR12               (SEQ_INIT_ADDR12),
                      .SEQ_INIT_ADDR13               (SEQ_INIT_ADDR13),
                      .SEQ_INIT_ADDR14               (SEQ_INIT_ADDR14),
                      .SEQ_INIT_ADDR15               (SEQ_INIT_ADDR15),
                      .SEQ_INIT_ADDR16               (SEQ_INIT_ADDR16),
                      .SEQ_INIT_ADDR17               (SEQ_INIT_ADDR17),
                      .SEQ_INIT_ADDR18               (SEQ_INIT_ADDR18),
                      .SEQ_INIT_ADDR19               (SEQ_INIT_ADDR19),
                      .SEQ_INIT_ADDR2               (SEQ_INIT_ADDR2),
                      .SEQ_INIT_ADDR20               (SEQ_INIT_ADDR20),
                      .SEQ_INIT_ADDR21               (SEQ_INIT_ADDR21),
                      .SEQ_INIT_ADDR22               (SEQ_INIT_ADDR22),
                      .SEQ_INIT_ADDR23               (SEQ_INIT_ADDR23),
                      .SEQ_INIT_ADDR24               (SEQ_INIT_ADDR24),
                      .SEQ_INIT_ADDR25               (SEQ_INIT_ADDR25),
                      .SEQ_INIT_ADDR26               (SEQ_INIT_ADDR26),
                      .SEQ_INIT_ADDR27               (SEQ_INIT_ADDR27),
                      .SEQ_INIT_ADDR28               (SEQ_INIT_ADDR28),
                      .SEQ_INIT_ADDR29               (SEQ_INIT_ADDR29),
                      .SEQ_INIT_ADDR3               (SEQ_INIT_ADDR3),
                      .SEQ_INIT_ADDR30               (SEQ_INIT_ADDR30),
                      .SEQ_INIT_ADDR31               (SEQ_INIT_ADDR31),
                      .SEQ_INIT_ADDR32               (SEQ_INIT_ADDR32),
                      .SEQ_INIT_ADDR33               (SEQ_INIT_ADDR33),
                      .SEQ_INIT_ADDR34               (SEQ_INIT_ADDR34),
                      .SEQ_INIT_ADDR35               (SEQ_INIT_ADDR35),
                      .SEQ_INIT_ADDR36               (SEQ_INIT_ADDR36),
                      .SEQ_INIT_ADDR37               (SEQ_INIT_ADDR37),
                      .SEQ_INIT_ADDR38               (SEQ_INIT_ADDR38),
                      .SEQ_INIT_ADDR39               (SEQ_INIT_ADDR39),
                      .SEQ_INIT_ADDR4               (SEQ_INIT_ADDR4),
                      .SEQ_INIT_ADDR40               (SEQ_INIT_ADDR40),
                      .SEQ_INIT_ADDR41               (SEQ_INIT_ADDR41),
                      .SEQ_INIT_ADDR42               (SEQ_INIT_ADDR42),
                      .SEQ_INIT_ADDR43               (SEQ_INIT_ADDR43),
                      .SEQ_INIT_ADDR44               (SEQ_INIT_ADDR44),
                      .SEQ_INIT_ADDR45               (SEQ_INIT_ADDR45),
                      .SEQ_INIT_ADDR46               (SEQ_INIT_ADDR46),
                      .SEQ_INIT_ADDR47               (SEQ_INIT_ADDR47),
                      .SEQ_INIT_ADDR48               (SEQ_INIT_ADDR48),
                      .SEQ_INIT_ADDR49               (SEQ_INIT_ADDR49),
                      .SEQ_INIT_ADDR5               (SEQ_INIT_ADDR5),
                      .SEQ_INIT_ADDR50               (SEQ_INIT_ADDR50),
                      .SEQ_INIT_ADDR51               (SEQ_INIT_ADDR51),
                      .SEQ_INIT_ADDR52               (SEQ_INIT_ADDR52),
                      .SEQ_INIT_ADDR53               (SEQ_INIT_ADDR53),
                      .SEQ_INIT_ADDR54               (SEQ_INIT_ADDR54),
                      .SEQ_INIT_ADDR55               (SEQ_INIT_ADDR55),
                      .SEQ_INIT_ADDR56               (SEQ_INIT_ADDR56),
                      .SEQ_INIT_ADDR57               (SEQ_INIT_ADDR57),
                      .SEQ_INIT_ADDR58               (SEQ_INIT_ADDR58),
                      .SEQ_INIT_ADDR59               (SEQ_INIT_ADDR59),
                      .SEQ_INIT_ADDR6               (SEQ_INIT_ADDR6),
                      .SEQ_INIT_ADDR60               (SEQ_INIT_ADDR60),
                      .SEQ_INIT_ADDR61               (SEQ_INIT_ADDR61),
                      .SEQ_INIT_ADDR62               (SEQ_INIT_ADDR62),
                      .SEQ_INIT_ADDR63               (SEQ_INIT_ADDR63),
                      .SEQ_INIT_ADDR64               (SEQ_INIT_ADDR64),
                      .SEQ_INIT_ADDR65               (SEQ_INIT_ADDR65),
                      .SEQ_INIT_ADDR66               (SEQ_INIT_ADDR66),
                      .SEQ_INIT_ADDR67               (SEQ_INIT_ADDR67),
                      .SEQ_INIT_ADDR68               (SEQ_INIT_ADDR68),
                      .SEQ_INIT_ADDR69               (SEQ_INIT_ADDR69),
                      .SEQ_INIT_ADDR7               (SEQ_INIT_ADDR7),
                      .SEQ_INIT_ADDR70               (SEQ_INIT_ADDR70),
                      .SEQ_INIT_ADDR71               (SEQ_INIT_ADDR71),
                      .SEQ_INIT_ADDR72               (SEQ_INIT_ADDR72),
                      .SEQ_INIT_ADDR73               (SEQ_INIT_ADDR73),
                      .SEQ_INIT_ADDR74               (SEQ_INIT_ADDR74),
                      .SEQ_INIT_ADDR75               (SEQ_INIT_ADDR75),
                      .SEQ_INIT_ADDR76               (SEQ_INIT_ADDR76),
                      .SEQ_INIT_ADDR77               (SEQ_INIT_ADDR77),
                      .SEQ_INIT_ADDR78               (SEQ_INIT_ADDR78),
                      .SEQ_INIT_ADDR79               (SEQ_INIT_ADDR79),
                      .SEQ_INIT_ADDR8               (SEQ_INIT_ADDR8),
                      .SEQ_INIT_ADDR80               (SEQ_INIT_ADDR80),
                      .SEQ_INIT_ADDR81               (SEQ_INIT_ADDR81),
                      .SEQ_INIT_ADDR82               (SEQ_INIT_ADDR82),
                      .SEQ_INIT_ADDR83               (SEQ_INIT_ADDR83),
                      .SEQ_INIT_ADDR84               (SEQ_INIT_ADDR84),
                      .SEQ_INIT_ADDR85               (SEQ_INIT_ADDR85),
                      .SEQ_INIT_ADDR86               (SEQ_INIT_ADDR86),
                      .SEQ_INIT_ADDR87               (SEQ_INIT_ADDR87),
                      .SEQ_INIT_ADDR88               (SEQ_INIT_ADDR88),
                      .SEQ_INIT_ADDR89               (SEQ_INIT_ADDR89),
                      .SEQ_INIT_ADDR9               (SEQ_INIT_ADDR9),
                      .SEQ_INIT_ADDR90               (SEQ_INIT_ADDR90),
                      .SEQ_INIT_ADDR91               (SEQ_INIT_ADDR91),
                      .SEQ_INIT_ADDR92               (SEQ_INIT_ADDR92),
                      .SEQ_INIT_ADDR93               (SEQ_INIT_ADDR93),
                      .SEQ_INIT_ADDR94               (SEQ_INIT_ADDR94),
                      .SEQ_INIT_ADDR95               (SEQ_INIT_ADDR95),
                      .SEQ_INIT_ADDR96               (SEQ_INIT_ADDR96),
                      .SEQ_INIT_ADDR97               (SEQ_INIT_ADDR97),
                      .SEQ_INIT_ADDR98               (SEQ_INIT_ADDR98),
                      .SEQ_INIT_ADDR99               (SEQ_INIT_ADDR99),
                      .SEQ_INIT_CMD0               (SEQ_INIT_CMD0),
                      .SEQ_INIT_CMD1               (SEQ_INIT_CMD1),
                      .SEQ_INIT_CMD10               (SEQ_INIT_CMD10),
                      .SEQ_INIT_CMD11               (SEQ_INIT_CMD11),
                      .SEQ_INIT_CMD12               (SEQ_INIT_CMD12),
                      .SEQ_INIT_CMD13               (SEQ_INIT_CMD13),
                      .SEQ_INIT_CMD14               (SEQ_INIT_CMD14),
                      .SEQ_INIT_CMD15               (SEQ_INIT_CMD15),
                      .SEQ_INIT_CMD16               (SEQ_INIT_CMD16),
                      .SEQ_INIT_CMD17               (SEQ_INIT_CMD17),
                      .SEQ_INIT_CMD18               (SEQ_INIT_CMD18),
                      .SEQ_INIT_CMD19               (SEQ_INIT_CMD19),
                      .SEQ_INIT_CMD2               (SEQ_INIT_CMD2),
                      .SEQ_INIT_CMD20               (SEQ_INIT_CMD20),
                      .SEQ_INIT_CMD21               (SEQ_INIT_CMD21),
                      .SEQ_INIT_CMD22               (SEQ_INIT_CMD22),
                      .SEQ_INIT_CMD23               (SEQ_INIT_CMD23),
                      .SEQ_INIT_CMD24               (SEQ_INIT_CMD24),
                      .SEQ_INIT_CMD25               (SEQ_INIT_CMD25),
                      .SEQ_INIT_CMD26               (SEQ_INIT_CMD26),
                      .SEQ_INIT_CMD27               (SEQ_INIT_CMD27),
                      .SEQ_INIT_CMD28               (SEQ_INIT_CMD28),
                      .SEQ_INIT_CMD29               (SEQ_INIT_CMD29),
                      .SEQ_INIT_CMD3               (SEQ_INIT_CMD3),
                      .SEQ_INIT_CMD30               (SEQ_INIT_CMD30),
                      .SEQ_INIT_CMD31               (SEQ_INIT_CMD31),
                      .SEQ_INIT_CMD32               (SEQ_INIT_CMD32),
                      .SEQ_INIT_CMD33               (SEQ_INIT_CMD33),
                      .SEQ_INIT_CMD34               (SEQ_INIT_CMD34),
                      .SEQ_INIT_CMD35               (SEQ_INIT_CMD35),
                      .SEQ_INIT_CMD36               (SEQ_INIT_CMD36),
                      .SEQ_INIT_CMD37               (SEQ_INIT_CMD37),
                      .SEQ_INIT_CMD38               (SEQ_INIT_CMD38),
                      .SEQ_INIT_CMD39               (SEQ_INIT_CMD39),
                      .SEQ_INIT_CMD4               (SEQ_INIT_CMD4),
                      .SEQ_INIT_CMD40               (SEQ_INIT_CMD40),
                      .SEQ_INIT_CMD41               (SEQ_INIT_CMD41),
                      .SEQ_INIT_CMD42               (SEQ_INIT_CMD42),
                      .SEQ_INIT_CMD43               (SEQ_INIT_CMD43),
                      .SEQ_INIT_CMD44               (SEQ_INIT_CMD44),
                      .SEQ_INIT_CMD45               (SEQ_INIT_CMD45),
                      .SEQ_INIT_CMD46               (SEQ_INIT_CMD46),
                      .SEQ_INIT_CMD47               (SEQ_INIT_CMD47),
                      .SEQ_INIT_CMD48               (SEQ_INIT_CMD48),
                      .SEQ_INIT_CMD49               (SEQ_INIT_CMD49),
                      .SEQ_INIT_CMD5               (SEQ_INIT_CMD5),
                      .SEQ_INIT_CMD50               (SEQ_INIT_CMD50),
                      .SEQ_INIT_CMD51               (SEQ_INIT_CMD51),
                      .SEQ_INIT_CMD52               (SEQ_INIT_CMD52),
                      .SEQ_INIT_CMD53               (SEQ_INIT_CMD53),
                      .SEQ_INIT_CMD54               (SEQ_INIT_CMD54),
                      .SEQ_INIT_CMD55               (SEQ_INIT_CMD55),
                      .SEQ_INIT_CMD56               (SEQ_INIT_CMD56),
                      .SEQ_INIT_CMD57               (SEQ_INIT_CMD57),
                      .SEQ_INIT_CMD58               (SEQ_INIT_CMD58),
                      .SEQ_INIT_CMD59               (SEQ_INIT_CMD59),
                      .SEQ_INIT_CMD6               (SEQ_INIT_CMD6),
                      .SEQ_INIT_CMD60               (SEQ_INIT_CMD60),
                      .SEQ_INIT_CMD61               (SEQ_INIT_CMD61),
                      .SEQ_INIT_CMD62               (SEQ_INIT_CMD62),
                      .SEQ_INIT_CMD63               (SEQ_INIT_CMD63),
                      .SEQ_INIT_CMD64               (SEQ_INIT_CMD64),
                      .SEQ_INIT_CMD65               (SEQ_INIT_CMD65),
                      .SEQ_INIT_CMD66               (SEQ_INIT_CMD66),
                      .SEQ_INIT_CMD67               (SEQ_INIT_CMD67),
                      .SEQ_INIT_CMD68               (SEQ_INIT_CMD68),
                      .SEQ_INIT_CMD69               (SEQ_INIT_CMD69),
                      .SEQ_INIT_CMD7               (SEQ_INIT_CMD7),
                      .SEQ_INIT_CMD70               (SEQ_INIT_CMD70),
                      .SEQ_INIT_CMD71               (SEQ_INIT_CMD71),
                      .SEQ_INIT_CMD72               (SEQ_INIT_CMD72),
                      .SEQ_INIT_CMD73               (SEQ_INIT_CMD73),
                      .SEQ_INIT_CMD74               (SEQ_INIT_CMD74),
                      .SEQ_INIT_CMD75               (SEQ_INIT_CMD75),
                      .SEQ_INIT_CMD76               (SEQ_INIT_CMD76),
                      .SEQ_INIT_CMD77               (SEQ_INIT_CMD77),
                      .SEQ_INIT_CMD78               (SEQ_INIT_CMD78),
                      .SEQ_INIT_CMD79               (SEQ_INIT_CMD79),
                      .SEQ_INIT_CMD8               (SEQ_INIT_CMD8),
                      .SEQ_INIT_CMD80               (SEQ_INIT_CMD80),
                      .SEQ_INIT_CMD81               (SEQ_INIT_CMD81),
                      .SEQ_INIT_CMD82               (SEQ_INIT_CMD82),
                      .SEQ_INIT_CMD83               (SEQ_INIT_CMD83),
                      .SEQ_INIT_CMD84               (SEQ_INIT_CMD84),
                      .SEQ_INIT_CMD85               (SEQ_INIT_CMD85),
                      .SEQ_INIT_CMD86               (SEQ_INIT_CMD86),
                      .SEQ_INIT_CMD87               (SEQ_INIT_CMD87),
                      .SEQ_INIT_CMD88               (SEQ_INIT_CMD88),
                      .SEQ_INIT_CMD89               (SEQ_INIT_CMD89),
                      .SEQ_INIT_CMD9               (SEQ_INIT_CMD9),
                      .SEQ_INIT_CMD90               (SEQ_INIT_CMD90),
                      .SEQ_INIT_CMD91               (SEQ_INIT_CMD91),
                      .SEQ_INIT_CMD92               (SEQ_INIT_CMD92),
                      .SEQ_INIT_CMD93               (SEQ_INIT_CMD93),
                      .SEQ_INIT_CMD94               (SEQ_INIT_CMD94),
                      .SEQ_INIT_CMD95               (SEQ_INIT_CMD95),
                      .SEQ_INIT_CMD96               (SEQ_INIT_CMD96),
                      .SEQ_INIT_CMD97               (SEQ_INIT_CMD97),
                      .SEQ_INIT_CMD98               (SEQ_INIT_CMD98),
                      .SEQ_INIT_CMD99               (SEQ_INIT_CMD99),
                      .SEQ_INIT_CMD_SET             (SEQ_INIT_CMD_SET),
                      .SEQ_INIT_CMD_VALID           (SEQ_INIT_CMD_VALID),
                      .SEQ_INIT_CNTRL0               (SEQ_INIT_CNTRL0),
                      .SEQ_INIT_CNTRL1               (SEQ_INIT_CNTRL1),
                      .SEQ_INIT_CNTRL10               (SEQ_INIT_CNTRL10),
                      .SEQ_INIT_CNTRL11               (SEQ_INIT_CNTRL11),
                      .SEQ_INIT_CNTRL12               (SEQ_INIT_CNTRL12),
                      .SEQ_INIT_CNTRL13               (SEQ_INIT_CNTRL13),
                      .SEQ_INIT_CNTRL14               (SEQ_INIT_CNTRL14),
                      .SEQ_INIT_CNTRL15               (SEQ_INIT_CNTRL15),
                      .SEQ_INIT_CNTRL16               (SEQ_INIT_CNTRL16),
                      .SEQ_INIT_CNTRL17               (SEQ_INIT_CNTRL17),
                      .SEQ_INIT_CNTRL18               (SEQ_INIT_CNTRL18),
                      .SEQ_INIT_CNTRL19               (SEQ_INIT_CNTRL19),
                      .SEQ_INIT_CNTRL2               (SEQ_INIT_CNTRL2),
                      .SEQ_INIT_CNTRL20               (SEQ_INIT_CNTRL20),
                      .SEQ_INIT_CNTRL21               (SEQ_INIT_CNTRL21),
                      .SEQ_INIT_CNTRL22               (SEQ_INIT_CNTRL22),
                      .SEQ_INIT_CNTRL23               (SEQ_INIT_CNTRL23),
                      .SEQ_INIT_CNTRL24               (SEQ_INIT_CNTRL24),
                      .SEQ_INIT_CNTRL25               (SEQ_INIT_CNTRL25),
                      .SEQ_INIT_CNTRL26               (SEQ_INIT_CNTRL26),
                      .SEQ_INIT_CNTRL27               (SEQ_INIT_CNTRL27),
                      .SEQ_INIT_CNTRL28               (SEQ_INIT_CNTRL28),
                      .SEQ_INIT_CNTRL29               (SEQ_INIT_CNTRL29),
                      .SEQ_INIT_CNTRL3               (SEQ_INIT_CNTRL3),
                      .SEQ_INIT_CNTRL30               (SEQ_INIT_CNTRL30),
                      .SEQ_INIT_CNTRL31               (SEQ_INIT_CNTRL31),
                      .SEQ_INIT_CNTRL32               (SEQ_INIT_CNTRL32),
                      .SEQ_INIT_CNTRL33               (SEQ_INIT_CNTRL33),
                      .SEQ_INIT_CNTRL34               (SEQ_INIT_CNTRL34),
                      .SEQ_INIT_CNTRL35               (SEQ_INIT_CNTRL35),
                      .SEQ_INIT_CNTRL36               (SEQ_INIT_CNTRL36),
                      .SEQ_INIT_CNTRL37               (SEQ_INIT_CNTRL37),
                      .SEQ_INIT_CNTRL38               (SEQ_INIT_CNTRL38),
                      .SEQ_INIT_CNTRL39               (SEQ_INIT_CNTRL39),
                      .SEQ_INIT_CNTRL4               (SEQ_INIT_CNTRL4),
                      .SEQ_INIT_CNTRL40               (SEQ_INIT_CNTRL40),
                      .SEQ_INIT_CNTRL41               (SEQ_INIT_CNTRL41),
                      .SEQ_INIT_CNTRL42               (SEQ_INIT_CNTRL42),
                      .SEQ_INIT_CNTRL43               (SEQ_INIT_CNTRL43),
                      .SEQ_INIT_CNTRL44               (SEQ_INIT_CNTRL44),
                      .SEQ_INIT_CNTRL45               (SEQ_INIT_CNTRL45),
                      .SEQ_INIT_CNTRL46               (SEQ_INIT_CNTRL46),
                      .SEQ_INIT_CNTRL47               (SEQ_INIT_CNTRL47),
                      .SEQ_INIT_CNTRL48               (SEQ_INIT_CNTRL48),
                      .SEQ_INIT_CNTRL49               (SEQ_INIT_CNTRL49),
                      .SEQ_INIT_CNTRL5               (SEQ_INIT_CNTRL5),
                      .SEQ_INIT_CNTRL50               (SEQ_INIT_CNTRL50),
                      .SEQ_INIT_CNTRL51               (SEQ_INIT_CNTRL51),
                      .SEQ_INIT_CNTRL52               (SEQ_INIT_CNTRL52),
                      .SEQ_INIT_CNTRL53               (SEQ_INIT_CNTRL53),
                      .SEQ_INIT_CNTRL54               (SEQ_INIT_CNTRL54),
                      .SEQ_INIT_CNTRL55               (SEQ_INIT_CNTRL55),
                      .SEQ_INIT_CNTRL56               (SEQ_INIT_CNTRL56),
                      .SEQ_INIT_CNTRL57               (SEQ_INIT_CNTRL57),
                      .SEQ_INIT_CNTRL58               (SEQ_INIT_CNTRL58),
                      .SEQ_INIT_CNTRL59               (SEQ_INIT_CNTRL59),
                      .SEQ_INIT_CNTRL6               (SEQ_INIT_CNTRL6),
                      .SEQ_INIT_CNTRL60               (SEQ_INIT_CNTRL60),
                      .SEQ_INIT_CNTRL61               (SEQ_INIT_CNTRL61),
                      .SEQ_INIT_CNTRL62               (SEQ_INIT_CNTRL62),
                      .SEQ_INIT_CNTRL63               (SEQ_INIT_CNTRL63),
                      .SEQ_INIT_CNTRL64               (SEQ_INIT_CNTRL64),
                      .SEQ_INIT_CNTRL65               (SEQ_INIT_CNTRL65),
                      .SEQ_INIT_CNTRL66               (SEQ_INIT_CNTRL66),
                      .SEQ_INIT_CNTRL67               (SEQ_INIT_CNTRL67),
                      .SEQ_INIT_CNTRL68               (SEQ_INIT_CNTRL68),
                      .SEQ_INIT_CNTRL69               (SEQ_INIT_CNTRL69),
                      .SEQ_INIT_CNTRL7               (SEQ_INIT_CNTRL7),
                      .SEQ_INIT_CNTRL70               (SEQ_INIT_CNTRL70),
                      .SEQ_INIT_CNTRL71               (SEQ_INIT_CNTRL71),
                      .SEQ_INIT_CNTRL72               (SEQ_INIT_CNTRL72),
                      .SEQ_INIT_CNTRL73               (SEQ_INIT_CNTRL73),
                      .SEQ_INIT_CNTRL74               (SEQ_INIT_CNTRL74),
                      .SEQ_INIT_CNTRL75               (SEQ_INIT_CNTRL75),
                      .SEQ_INIT_CNTRL76               (SEQ_INIT_CNTRL76),
                      .SEQ_INIT_CNTRL77               (SEQ_INIT_CNTRL77),
                      .SEQ_INIT_CNTRL78               (SEQ_INIT_CNTRL78),
                      .SEQ_INIT_CNTRL79               (SEQ_INIT_CNTRL79),
                      .SEQ_INIT_CNTRL8               (SEQ_INIT_CNTRL8),
                      .SEQ_INIT_CNTRL80               (SEQ_INIT_CNTRL80),
                      .SEQ_INIT_CNTRL81               (SEQ_INIT_CNTRL81),
                      .SEQ_INIT_CNTRL82               (SEQ_INIT_CNTRL82),
                      .SEQ_INIT_CNTRL83               (SEQ_INIT_CNTRL83),
                      .SEQ_INIT_CNTRL84                (SEQ_INIT_CNTRL84),
                      .SEQ_INIT_CNTRL85                (SEQ_INIT_CNTRL85),
                      .SEQ_INIT_CNTRL86                (SEQ_INIT_CNTRL86),
                      .SEQ_INIT_CNTRL87                (SEQ_INIT_CNTRL87),
                      .SEQ_INIT_CNTRL88                (SEQ_INIT_CNTRL88),
                      .SEQ_INIT_CNTRL89                (SEQ_INIT_CNTRL89),
                      .SEQ_INIT_CNTRL9                 (SEQ_INIT_CNTRL9),
                      .SEQ_INIT_CNTRL90                (SEQ_INIT_CNTRL90),
                      .SEQ_INIT_CNTRL91                (SEQ_INIT_CNTRL91),
                      .SEQ_INIT_CNTRL92                (SEQ_INIT_CNTRL92),
                      .SEQ_INIT_CNTRL93               (SEQ_INIT_CNTRL93),
                      .SEQ_INIT_CNTRL94               (SEQ_INIT_CNTRL94),
                      .SEQ_INIT_CNTRL95               (SEQ_INIT_CNTRL95),
                      .SEQ_INIT_CNTRL96               (SEQ_INIT_CNTRL96),
                      .SEQ_INIT_CNTRL97               (SEQ_INIT_CNTRL97),
                      .SEQ_INIT_CNTRL98               (SEQ_INIT_CNTRL98),
                      .SEQ_INIT_CNTRL99               (SEQ_INIT_CNTRL99),
                      .SEQ_INIT_CONFIG                (SEQ_INIT_CONFIG),
                      .SEQ_MODE                       (SEQ_MODE),
                      .TXNQ_RD_PRIORITY               (TXNQ_RD_PRIORITY),
                      .TXNQ_WR_PRIORITY               (TXNQ_WR_PRIORITY),
                      .T_TXBIT                        (T_TXBIT),
                      .UB_CLK_MUX                     (UB_CLK_MUX),
                      .WRITE_BANDWIDTH                (WRITE_BANDWIDTH),
                      .XMPU_CONFIG0                   (XMPU_CONFIG0),
                      .XMPU_CONFIG1                   (XMPU_CONFIG1),
                      .XMPU_CONFIG10                  (XMPU_CONFIG10),
                      .XMPU_CONFIG11                  (XMPU_CONFIG11),
                      .XMPU_CONFIG12                  (XMPU_CONFIG12),
                      .XMPU_CONFIG13                  (XMPU_CONFIG13),
                      .XMPU_CONFIG14                  (XMPU_CONFIG14),
                      .XMPU_CONFIG15                  (XMPU_CONFIG15),
                      .XMPU_CONFIG2                   (XMPU_CONFIG2),
                      .XMPU_CONFIG3                   (XMPU_CONFIG3),
                      .XMPU_CONFIG4                   (XMPU_CONFIG4),
                      .XMPU_CONFIG5                   (XMPU_CONFIG5),
                      .XMPU_CONFIG6                   (XMPU_CONFIG6),
                      .XMPU_CONFIG7                   (XMPU_CONFIG7),
                      .XMPU_CONFIG8                   (XMPU_CONFIG8),
                      .XMPU_CONFIG9                   (XMPU_CONFIG9),
                      .XMPU_CTRL                      (XMPU_CTRL),
                      .XMPU_END_HI0                   (XMPU_END_HI0),
                      .XMPU_END_HI1                   (XMPU_END_HI1),
                      .XMPU_END_HI10                  (XMPU_END_HI10),
                      .XMPU_END_HI11                  (XMPU_END_HI11),
                      .XMPU_END_HI12                  (XMPU_END_HI12),
                      .XMPU_END_HI13                  (XMPU_END_HI13),
                      .XMPU_END_HI14                  (XMPU_END_HI14),
                      .XMPU_END_HI15                  (XMPU_END_HI15),
                      .XMPU_END_HI2                   (XMPU_END_HI2),
                      .XMPU_END_HI3                   (XMPU_END_HI3),
                      .XMPU_END_HI4                   (XMPU_END_HI4),
                      .XMPU_END_HI5                   (XMPU_END_HI5),
                      .XMPU_END_HI6                   (XMPU_END_HI6),
                      .XMPU_END_HI7                   (XMPU_END_HI7),
                      .XMPU_END_HI8                   (XMPU_END_HI8),
                      .XMPU_END_HI9                   (XMPU_END_HI9),
                      .XMPU_END_LO0                   (XMPU_END_LO0),
                      .XMPU_END_LO1                   (XMPU_END_LO1),
                      .XMPU_END_LO10                  (XMPU_END_LO10),
                      .XMPU_END_LO11                  (XMPU_END_LO11),
                      .XMPU_END_LO12                  (XMPU_END_LO12),
                      .XMPU_END_LO13                  (XMPU_END_LO13),
                      .XMPU_END_LO14                  (XMPU_END_LO14),
                      .XMPU_END_LO15                  (XMPU_END_LO15),
                      .XMPU_END_LO2                   (XMPU_END_LO2),
                      .XMPU_END_LO3                   (XMPU_END_LO3),
                      .XMPU_END_LO4                   (XMPU_END_LO4),
                      .XMPU_END_LO5                   (XMPU_END_LO5),
                      .XMPU_END_LO6                   (XMPU_END_LO6),
                      .XMPU_END_LO7                   (XMPU_END_LO7),
                      .XMPU_END_LO8                   (XMPU_END_LO8),
                      .XMPU_END_LO9                   (XMPU_END_LO9),
                      .XMPU_MASTER0                   (XMPU_MASTER0),
                      .XMPU_MASTER1                   (XMPU_MASTER1),
                      .XMPU_MASTER10                  (XMPU_MASTER10),
                      .XMPU_MASTER11                  (XMPU_MASTER11),
                      .XMPU_MASTER12                  (XMPU_MASTER12),
                      .XMPU_MASTER13                  (XMPU_MASTER13),
                      .XMPU_MASTER14                  (XMPU_MASTER14),
                      .XMPU_MASTER15                  (XMPU_MASTER15),
                      .XMPU_MASTER2                   (XMPU_MASTER2),
                      .XMPU_MASTER3                   (XMPU_MASTER3),
                      .XMPU_MASTER4                   (XMPU_MASTER4),
                      .XMPU_MASTER5                   (XMPU_MASTER5),
                      .XMPU_MASTER6                   (XMPU_MASTER6),
                      .XMPU_MASTER7                   (XMPU_MASTER7),
                      .XMPU_MASTER8                   (XMPU_MASTER8),
                      .XMPU_MASTER9                   (XMPU_MASTER9),
                      .XMPU_START_HI0                 (XMPU_START_HI0),
                      .XMPU_START_HI1                 (XMPU_START_HI1),
                      .XMPU_START_HI10                (XMPU_START_HI10),
                      .XMPU_START_HI11                (XMPU_START_HI11),
                      .XMPU_START_HI12                (XMPU_START_HI12),
                      .XMPU_START_HI13                (XMPU_START_HI13),
                      .XMPU_START_HI14                (XMPU_START_HI14),
                      .XMPU_START_HI15                (XMPU_START_HI15),
                      .XMPU_START_HI2                 (XMPU_START_HI2),
                      .XMPU_START_HI3                 (XMPU_START_HI3),
                      .XMPU_START_HI4                 (XMPU_START_HI4),
                      .XMPU_START_HI5                 (XMPU_START_HI5),
                      .XMPU_START_HI6                 (XMPU_START_HI6),
                      .XMPU_START_HI7                 (XMPU_START_HI7),
                      .XMPU_START_HI8                 (XMPU_START_HI8),
                      .XMPU_START_HI9                 (XMPU_START_HI9),
                      .XMPU_START_LO0                 (XMPU_START_LO0),
                      .XMPU_START_LO1                 (XMPU_START_LO1),
                      .XMPU_START_LO10                (XMPU_START_LO10),
                      .XMPU_START_LO11                (XMPU_START_LO11),
                      .XMPU_START_LO12                (XMPU_START_LO12),
                      .XMPU_START_LO13                (XMPU_START_LO13),
                      .XMPU_START_LO14                (XMPU_START_LO14),
                      .XMPU_START_LO15                (XMPU_START_LO15),
                      .XMPU_START_LO2                 (XMPU_START_LO2),
                      .XMPU_START_LO3                 (XMPU_START_LO3),
                      .XMPU_START_LO4                 (XMPU_START_LO4),
                      .XMPU_START_LO5                 (XMPU_START_LO5),
                      .XMPU_START_LO6                 (XMPU_START_LO6),
                      .XMPU_START_LO7                 (XMPU_START_LO7),
                      .XMPU_START_LO8                 (XMPU_START_LO8),
                      .XMPU_START_LO9                 (XMPU_START_LO9),
                      .XPI_DATA_NIB_CHAN              (XPI_DATA_NIB_CHAN),
                      .XPI_DQS                        (XPI_DQS),
                      .XPI_NIB_CHAN                   (XPI_NIB_CHAN),
                      .XPI_OE                         (XPI_OE),
                      .XPI_OE_ALL_NIB                 (XPI_OE_ALL_NIB),
                      .XPI_PMI_CONFIG                 (XPI_PMI_CONFIG),
                      .XPI_READ_DBI                   (XPI_READ_DBI),
                      .XPI_READ_OFFSET                (XPI_READ_OFFSET),
                      .XPI_WRDATA_ALL_NIB             (XPI_WRDATA_ALL_NIB),
                      .XPI_WRITE_DM_DBI               (XPI_WRITE_DM_DBI)
   ) u_ddrmc_main
  (
  //outputs
  .DMC2PHY_CSSD_TRIG()
  ,.DMC2PHY_FIFO_RDEN(DMC2PHY_FIFO_RDEN)
  ,.DMC2PHY_RDCS0(DMC2PHY_RDCS0)
  ,.DMC2PHY_RDCS1(DMC2PHY_RDCS1)
  ,.DMC2PHY_RDEN(DMC2PHY_RDEN)
  ,.DMC2PHY_T_B(DMC2PHY_T_B)
  ,.DMC2PHY_T_TXBIT_0(DMC2PHY_T_TXBIT0)
  ,.DMC2PHY_T_TXBIT_1(DMC2PHY_T_TXBIT1)
  ,.DMC2PHY_T_TXBIT_2(DMC2PHY_T_TXBIT2)
  ,.DMC2PHY_WRCS0(DMC2PHY_WRCS0)
  ,.DMC2PHY_WRCS1(DMC2PHY_WRCS1)
  ,.DMC2PHY_WR_DQ0(DMC2PHY_WR_DQ0)
  ,.DMC2PHY_WR_DQ1(DMC2PHY_WR_DQ1)
  ,.DMC2PHY_WR_DQ2(DMC2PHY_WR_DQ2)
  ,.DMC2PHY_WR_DQ3(DMC2PHY_WR_DQ3)
  ,.DMC2PHY_WR_DQ4(DMC2PHY_WR_DQ4)
  ,.DMC2PHY_WR_DQ5(DMC2PHY_WR_DQ5)
  ,.DMC_CLK_DESKEW()
  ,.IF_CAL_CAL_BUSY()
  ,.IF_CAL_CAL_DONE()
  //,.IF_CAL_CAL_USR_PORT_AVAILABLE()
  ,.IF_DMC2NOC_OUT_0_NOC_CREDIT_RDY(dmc2noc_credit_rdy_0)
  ,.IF_DMC2NOC_OUT_0_NOC_FLIT(dmc2noc_data_out_0)
  ,.IF_DMC2NOC_OUT_0_NOC_FLIT_EN()
  ,.IF_DMC2NOC_OUT_0_NOC_VALID(dmc2noc_valid_out_0)
  ,.IF_DMC2NOC_OUT_0_NOC_VALID_EN()
  ,.IF_DMC2NOC_OUT_1_NOC_CREDIT_RDY(dmc2noc_credit_rdy_1)
  ,.IF_DMC2NOC_OUT_1_NOC_FLIT(dmc2noc_data_out_1)
  ,.IF_DMC2NOC_OUT_1_NOC_FLIT_EN()
  ,.IF_DMC2NOC_OUT_1_NOC_VALID(dmc2noc_valid_out_1)
  ,.IF_DMC2NOC_OUT_1_NOC_VALID_EN()
  ,.IF_DMC2NOC_OUT_2_NOC_CREDIT_RDY(dmc2noc_credit_rdy_2)
  ,.IF_DMC2NOC_OUT_2_NOC_FLIT(dmc2noc_data_out_2)
  ,.IF_DMC2NOC_OUT_2_NOC_FLIT_EN()
  ,.IF_DMC2NOC_OUT_2_NOC_VALID(dmc2noc_valid_out_2)
  ,.IF_DMC2NOC_OUT_2_NOC_VALID_EN()
  ,.IF_DMC2NOC_OUT_3_NOC_CREDIT_RDY(dmc2noc_credit_rdy_3)
  ,.IF_DMC2NOC_OUT_3_NOC_FLIT(dmc2noc_data_out_3)
  ,.IF_DMC2NOC_OUT_3_NOC_FLIT_EN()
  ,.IF_DMC2NOC_OUT_3_NOC_VALID(dmc2noc_valid_out_3)
  ,.IF_DMC2NOC_OUT_3_NOC_VALID_EN()
  ,.IF_DMC_FABRIC_ILA2BLI_ACK()
  ,.IF_DMC_FABRIC_ILA2BLI_TRIG()
  ,.IF_DMC_FABRIC_PADDR()
  ,.IF_DMC_FABRIC_REF_ACK_0()
  ,.IF_DMC_FABRIC_REF_ACK_1()
  ,.IF_DMC_FABRIC_REF_USR_PORT_AVAILABLE()
  ,.IF_DMC_FABRIC_UB2BLI_ACK()
  ,.IF_DMC_FABRIC_UB2BLI_TRACE_TDATA()
  ,.IF_DMC_FABRIC_UB2BLI_TRACE_TVALID()
  ,.IF_DMC_FABRIC_UB2BLI_TRIG()
  ,.IF_DMC_FABRIC_UB2BLI_UART_TX()
  ,.IF_NOC2DMC_IN_0_NOC_CREDIT_RETURN(dmc2noc_credit_rtn_0)
  ,.IF_NOC2DMC_IN_0_NOC_CREDIT_RETURN_EN()
  ,.IF_NOC2DMC_IN_1_NOC_CREDIT_RETURN(dmc2noc_credit_rtn_1)
  ,.IF_NOC2DMC_IN_1_NOC_CREDIT_RETURN_EN()
  ,.IF_NOC2DMC_IN_2_NOC_CREDIT_RETURN(dmc2noc_credit_rtn_2)
  ,.IF_NOC2DMC_IN_2_NOC_CREDIT_RETURN_EN()
  ,.IF_NOC2DMC_IN_3_NOC_CREDIT_RETURN(dmc2noc_credit_rtn_3)
  ,.IF_NOC2DMC_IN_3_NOC_CREDIT_RETURN_EN()
  ,.IF_UBLAZE_FABRIC_PADDR()
  ,.IF_UBLAZE_FABRIC_PENABLE()
  ,.IF_UBLAZE_FABRIC_PSELX()
  ,.IF_UBLAZE_FABRIC_PWDATA()
  ,.IF_UBLAZE_FABRIC_PWRITE()
  ,.IF_UBLAZE_FABRIC_UB_MISC_OUT()
  ,.IF_UBLAZE_FABRIC_PPROT()
  ,.IF_UBLAZE_FABRIC_PSTRB()
  //inputs
  ,.DBG_PLL1_CLK()
  ,.DMC_CLK(mc_clk_xpll)
 // ,.IF_CAL_CAL_START(cal_start)
  ,.IF_DMC2NOC_OUT_0_NOC_CREDIT_RETURN(noc2dmc_credit_rtn_0)
  ,.IF_DMC2NOC_OUT_0_NOC_CREDIT_RETURN_EN(1'b0)
  ,.IF_DMC2NOC_OUT_1_NOC_CREDIT_RETURN(noc2dmc_credit_rtn_1)
  ,.IF_DMC2NOC_OUT_1_NOC_CREDIT_RETURN_EN(1'b0)
  ,.IF_DMC2NOC_OUT_2_NOC_CREDIT_RETURN(noc2dmc_credit_rtn_2)
  ,.IF_DMC2NOC_OUT_2_NOC_CREDIT_RETURN_EN(1'b0)
  ,.IF_DMC2NOC_OUT_3_NOC_CREDIT_RETURN(noc2dmc_credit_rtn_3)
  ,.IF_DMC2NOC_OUT_3_NOC_CREDIT_RETURN_EN(1'b0)
  ,.IF_DMC_FABRIC_BLI2ILA_ACK()
  ,.IF_DMC_FABRIC_BLI2ILA_TRIG()
  ,.IF_DMC_FABRIC_BLI2UB_ACK()
  ,.IF_DMC_FABRIC_BLI2UB_TRACE_CLK()
  ,.IF_DMC_FABRIC_BLI2UB_TRACE_TREADY()
  ,.IF_DMC_FABRIC_BLI2UB_TRIG()
  ,.IF_DMC_FABRIC_BLI2UB_UART_RX()
  ,.IF_DMC_FABRIC_CSSD_TRIG_IN_N_EXT()
  ,.IF_DMC_FABRIC_BLOCK_PERIODIC_CAL()
  ,.IF_DMC_FABRIC_REF_REQ_0()
  ,.IF_DMC_FABRIC_REF_REQ_1()
  ,.IF_DMC_FABRIC_REF_RANK_EN_0()
  ,.IF_DMC_FABRIC_REF_RANK_EN_1()
  ,.IF_NOC2DMC_IN_0_NOC_CREDIT_RDY(noc2dmc_credit_rdy_0)
  ,.IF_NOC2DMC_IN_0_NOC_FLIT(noc2dmc_data_in_0)
  ,.IF_NOC2DMC_IN_0_NOC_FLIT_EN(1'b0)
  ,.IF_NOC2DMC_IN_0_NOC_VALID(noc2dmc_valid_in_0)
  ,.IF_NOC2DMC_IN_0_NOC_VALID_EN(1'b0)
  ,.IF_NOC2DMC_IN_1_NOC_CREDIT_RDY(noc2dmc_credit_rdy_1)
  ,.IF_NOC2DMC_IN_1_NOC_FLIT(noc2dmc_data_in_1)
  ,.IF_NOC2DMC_IN_1_NOC_FLIT_EN(1'b0)
  ,.IF_NOC2DMC_IN_1_NOC_VALID(noc2dmc_valid_in_1)
  ,.IF_NOC2DMC_IN_1_NOC_VALID_EN(1'b0)
  ,.IF_NOC2DMC_IN_2_NOC_CREDIT_RDY(noc2dmc_credit_rdy_2)
  ,.IF_NOC2DMC_IN_2_NOC_FLIT(noc2dmc_data_in_2)
  ,.IF_NOC2DMC_IN_2_NOC_FLIT_EN(1'b0)
  ,.IF_NOC2DMC_IN_2_NOC_VALID(noc2dmc_valid_in_2)
  ,.IF_NOC2DMC_IN_2_NOC_VALID_EN(1'b0)
  ,.IF_NOC2DMC_IN_3_NOC_CREDIT_RDY(noc2dmc_credit_rdy_3)
  ,.IF_NOC2DMC_IN_3_NOC_FLIT(noc2dmc_data_in_3)
  ,.IF_NOC2DMC_IN_3_NOC_FLIT_EN(1'b0)
  ,.IF_NOC2DMC_IN_3_NOC_VALID(noc2dmc_valid_in_3)
  ,.IF_NOC2DMC_IN_3_NOC_VALID_EN(1'b0)
  ,.IF_DMC_FABRIC_PRDATA()
  ,.IF_UBLAZE_FABRIC_FABRIC_CLK()
  ,.IF_UBLAZE_FABRIC_FABRIC_RST_N()
  ,.IF_UBLAZE_FABRIC_PRDATA()
  ,.IF_UBLAZE_FABRIC_PREADY()
  ,.IF_UBLAZE_FABRIC_PSLVERR()
  ,.IF_UBLAZE_FABRIC_UB_MISC_IN()
  ,.NOC_CLK() //1'b0
  ,.PHY2DMC_FIFO_EMPTY(DMC_FIFO_EMPTY)
  ,.PHY2DMC_GT_STATUS(DMC_GT_STATUS)
  ,.PHY2DMC_RD_DQ0(DMC_Q0)
  ,.PHY2DMC_RD_DQ1(DMC_Q1)
  ,.PHY2DMC_RD_DQ2(DMC_Q2)
  ,.PHY2DMC_RD_DQ3(DMC_Q3)
  ,.PHY2DMC_RD_DQ4(DMC_Q4)
  ,.PHY2DMC_RD_DQ5(DMC_Q5)
  ,.SYS_RST_NOC_N() //sys_clk_rst_n && pll_locked
  ,.SYS_RST_PL_N() //sys_clk_rst_n && pll_locked
  ,.SYS_RST_PS_N() //sys_clk_rst_n && pll_locked
  ,.FROM_NOC_0(from_noc_0)
  ,.FROM_NOC_1(from_noc_1)
  ,.FROM_NOC_2(from_noc_2)
  ,.FROM_NOC_3(from_noc_3)
);

(* DONT_TOUCH = "TRUE" *) DDRMC_RIU 
#(
) u_ddrmc_riu
(
//outputs
                         .IF_DMC2PHY0_RIU_DMC2PHY_CTRL_CLK(riu2phy_ctrl_clk0)
,.IF_DMC2PHY0_RIU_DMC2RIU_ADDR(riu2xphy_addr0)
,.IF_DMC2PHY0_RIU_DMC2RIU_NIBBLE_SEL(riu2xphy_nibble_sel0)
,.IF_DMC2PHY0_RIU_DMC2RIU_WR_DATA(riu2xphy_wr_data0)
,.IF_DMC2PHY0_RIU_DMC2RIU_WR_EN(riu2xphy_wr_en0)
,.IF_DMC2PHY1_RIU_DMC2PHY_CTRL_CLK(riu2phy_ctrl_clk1)
,.IF_DMC2PHY1_RIU_DMC2RIU_ADDR(riu2xphy_addr1)
,.IF_DMC2PHY1_RIU_DMC2RIU_NIBBLE_SEL(riu2xphy_nibble_sel1)
,.IF_DMC2PHY1_RIU_DMC2RIU_WR_DATA(riu2xphy_wr_data1)
,.IF_DMC2PHY1_RIU_DMC2RIU_WR_EN(riu2xphy_wr_en1)
,.IF_DMC2PHY2_RIU_DMC2PHY_CTRL_CLK(riu2phy_ctrl_clk2)
,.IF_DMC2PHY2_RIU_DMC2RIU_ADDR(riu2xphy_addr2)
,.IF_DMC2PHY2_RIU_DMC2RIU_NIBBLE_SEL(riu2xphy_nibble_sel2)
,.IF_DMC2PHY2_RIU_DMC2RIU_WR_DATA(riu2xphy_wr_data2)
,.IF_DMC2PHY2_RIU_DMC2RIU_WR_EN(riu2xphy_wr_en2)

//inputs
,.IF_DMC2PHY0_RIU_RIU2DMC_RD_DATA(riu2dmc_rd_data_0)
,.IF_DMC2PHY0_RIU_RIU2DMC_VALID(riu2dmc_valid_0)
,.IF_DMC2PHY1_RIU_RIU2DMC_RD_DATA(riu2dmc_rd_data_1)
,.IF_DMC2PHY1_RIU_RIU2DMC_VALID(riu2dmc_valid_1)
,.IF_DMC2PHY2_RIU_RIU2DMC_RD_DATA(riu2dmc_rd_data_2)
,.IF_DMC2PHY2_RIU_RIU2DMC_VALID(riu2dmc_valid_2)

);

//

 





wire ch0_ddr4_alert_routethru;
wire ch1_ddr4_alert_routethru;
//ch0_reset_n
OBUF CH0_RST_OBUF(
  .O	(ch0_ddr4_reset_n),
	.I	(DMC2PHY_WR_DQ2[68])
);




assign DMC_Q0[3:0] = {DMC_Q[7],DMC_Q[5],DMC_Q[3],DMC_Q[1]};
assign DMC_Q1[3:0] = {DMC_Q[15],DMC_Q[13],DMC_Q[11],DMC_Q[9]};
assign DMC_Q2[3:0] = {DMC_Q[23],DMC_Q[21],DMC_Q[19],DMC_Q[17]};
assign DMC_Q3[3:0] = {DMC_Q[31],DMC_Q[29],DMC_Q[27],DMC_Q[25]};
assign DMC_Q4[3:0] = {DMC_Q[39],DMC_Q[37],DMC_Q[35],DMC_Q[33]};
assign DMC_Q5[3:0] = {DMC_Q[47],DMC_Q[45],DMC_Q[43],DMC_Q[41]};
assign DMC_Q0[7:4] = {DMC_Q[55],DMC_Q[53],DMC_Q[51],DMC_Q[49]};
assign DMC_Q1[7:4] = {DMC_Q[63],DMC_Q[61],DMC_Q[59],DMC_Q[57]};
assign DMC_Q2[7:4] = {DMC_Q[71],DMC_Q[69],DMC_Q[67],DMC_Q[65]};
assign DMC_Q3[7:4] = {DMC_Q[79],DMC_Q[77],DMC_Q[75],DMC_Q[73]};
assign DMC_Q4[7:4] = {DMC_Q[87],DMC_Q[85],DMC_Q[83],DMC_Q[81]};
assign DMC_Q5[7:4] = {DMC_Q[95],DMC_Q[93],DMC_Q[91],DMC_Q[89]};
assign DMC_Q0[11:8] = {DMC_Q[103],DMC_Q[101],DMC_Q[99],DMC_Q[97]};
assign DMC_Q1[11:8] = {DMC_Q[111],DMC_Q[109],DMC_Q[107],DMC_Q[105]};
assign DMC_Q2[11:8] = {DMC_Q[119],DMC_Q[117],DMC_Q[115],DMC_Q[113]};
assign DMC_Q3[11:8] = {DMC_Q[127],DMC_Q[125],DMC_Q[123],DMC_Q[121]};
assign DMC_Q4[11:8] = {DMC_Q[135],DMC_Q[133],DMC_Q[131],DMC_Q[129]};
assign DMC_Q5[11:8] = {DMC_Q[143],DMC_Q[141],DMC_Q[139],DMC_Q[137]};
assign DMC_Q0[15:12] = {DMC_Q[151],DMC_Q[149],DMC_Q[147],DMC_Q[145]};
assign DMC_Q1[15:12] = {DMC_Q[159],DMC_Q[157],DMC_Q[155],DMC_Q[153]};
assign DMC_Q2[15:12] = {DMC_Q[167],DMC_Q[165],DMC_Q[163],DMC_Q[161]};
assign DMC_Q3[15:12] = {DMC_Q[175],DMC_Q[173],DMC_Q[171],DMC_Q[169]};
assign DMC_Q4[15:12] = {DMC_Q[183],DMC_Q[181],DMC_Q[179],DMC_Q[177]};
assign DMC_Q5[15:12] = {DMC_Q[191],DMC_Q[189],DMC_Q[187],DMC_Q[185]};
assign DMC_Q0[19:16] = {DMC_Q[199],DMC_Q[197],DMC_Q[195],DMC_Q[193]};
assign DMC_Q1[19:16] = {DMC_Q[207],DMC_Q[205],DMC_Q[203],DMC_Q[201]};
assign DMC_Q2[19:16] = {DMC_Q[215],DMC_Q[213],DMC_Q[211],DMC_Q[209]};
assign DMC_Q3[19:16] = {DMC_Q[223],DMC_Q[221],DMC_Q[219],DMC_Q[217]};
assign DMC_Q4[19:16] = {DMC_Q[231],DMC_Q[229],DMC_Q[227],DMC_Q[225]};
assign DMC_Q5[19:16] = {DMC_Q[239],DMC_Q[237],DMC_Q[235],DMC_Q[233]};
assign DMC_Q0[23:20] = {DMC_Q[247],DMC_Q[245],DMC_Q[243],DMC_Q[241]};
assign DMC_Q1[23:20] = {DMC_Q[255],DMC_Q[253],DMC_Q[251],DMC_Q[249]};
assign DMC_Q2[23:20] = {DMC_Q[263],DMC_Q[261],DMC_Q[259],DMC_Q[257]};
assign DMC_Q3[23:20] = {DMC_Q[271],DMC_Q[269],DMC_Q[267],DMC_Q[265]};
assign DMC_Q4[23:20] = {DMC_Q[279],DMC_Q[277],DMC_Q[275],DMC_Q[273]};
assign DMC_Q5[23:20] = {DMC_Q[287],DMC_Q[285],DMC_Q[283],DMC_Q[281]};
assign DMC_Q0[27:24] = {DMC_Q[295],DMC_Q[293],DMC_Q[291],DMC_Q[289]};
assign DMC_Q1[27:24] = {DMC_Q[303],DMC_Q[301],DMC_Q[299],DMC_Q[297]};
assign DMC_Q2[27:24] = {DMC_Q[311],DMC_Q[309],DMC_Q[307],DMC_Q[305]};
assign DMC_Q3[27:24] = {DMC_Q[319],DMC_Q[317],DMC_Q[315],DMC_Q[313]};
assign DMC_Q4[27:24] = {DMC_Q[327],DMC_Q[325],DMC_Q[323],DMC_Q[321]};
assign DMC_Q5[27:24] = {DMC_Q[335],DMC_Q[333],DMC_Q[331],DMC_Q[329]};
assign DMC_Q0[31:28] = {DMC_Q[343],DMC_Q[341],DMC_Q[339],DMC_Q[337]};
assign DMC_Q1[31:28] = {DMC_Q[351],DMC_Q[349],DMC_Q[347],DMC_Q[345]};
assign DMC_Q2[31:28] = {DMC_Q[359],DMC_Q[357],DMC_Q[355],DMC_Q[353]};
assign DMC_Q3[31:28] = {DMC_Q[367],DMC_Q[365],DMC_Q[363],DMC_Q[361]};
assign DMC_Q4[31:28] = {DMC_Q[375],DMC_Q[373],DMC_Q[371],DMC_Q[369]};
assign DMC_Q5[31:28] = {DMC_Q[383],DMC_Q[381],DMC_Q[379],DMC_Q[377]};
assign DMC_Q0[35:32] = {DMC_Q[391],DMC_Q[389],DMC_Q[387],DMC_Q[385]};
assign DMC_Q1[35:32] = {DMC_Q[399],DMC_Q[397],DMC_Q[395],DMC_Q[393]};
assign DMC_Q2[35:32] = {DMC_Q[407],DMC_Q[405],DMC_Q[403],DMC_Q[401]};
assign DMC_Q3[35:32] = {DMC_Q[415],DMC_Q[413],DMC_Q[411],DMC_Q[409]};
assign DMC_Q4[35:32] = {DMC_Q[423],DMC_Q[421],DMC_Q[419],DMC_Q[417]};
assign DMC_Q5[35:32] = {DMC_Q[431],DMC_Q[429],DMC_Q[427],DMC_Q[425]};
assign DMC_Q0[39:36] = {DMC_Q[439],DMC_Q[437],DMC_Q[435],DMC_Q[433]};
assign DMC_Q1[39:36] = {DMC_Q[447],DMC_Q[445],DMC_Q[443],DMC_Q[441]};
assign DMC_Q2[39:36] = {DMC_Q[455],DMC_Q[453],DMC_Q[451],DMC_Q[449]};
assign DMC_Q3[39:36] = {DMC_Q[463],DMC_Q[461],DMC_Q[459],DMC_Q[457]};
assign DMC_Q4[39:36] = {DMC_Q[471],DMC_Q[469],DMC_Q[467],DMC_Q[465]};
assign DMC_Q5[39:36] = {DMC_Q[479],DMC_Q[477],DMC_Q[475],DMC_Q[473]};
assign DMC_Q0[43:40] = {DMC_Q[487],DMC_Q[485],DMC_Q[483],DMC_Q[481]};
assign DMC_Q1[43:40] = {DMC_Q[495],DMC_Q[493],DMC_Q[491],DMC_Q[489]};
assign DMC_Q2[43:40] = {DMC_Q[503],DMC_Q[501],DMC_Q[499],DMC_Q[497]};
assign DMC_Q3[43:40] = {DMC_Q[511],DMC_Q[509],DMC_Q[507],DMC_Q[505]};
assign DMC_Q4[43:40] = {DMC_Q[519],DMC_Q[517],DMC_Q[515],DMC_Q[513]};
assign DMC_Q5[43:40] = {DMC_Q[527],DMC_Q[525],DMC_Q[523],DMC_Q[521]};
assign DMC_Q0[47:44] = {DMC_Q[535],DMC_Q[533],DMC_Q[531],DMC_Q[529]};
assign DMC_Q1[47:44] = {DMC_Q[543],DMC_Q[541],DMC_Q[539],DMC_Q[537]};
assign DMC_Q2[47:44] = {DMC_Q[551],DMC_Q[549],DMC_Q[547],DMC_Q[545]};
assign DMC_Q3[47:44] = {DMC_Q[559],DMC_Q[557],DMC_Q[555],DMC_Q[553]};
assign DMC_Q4[47:44] = {DMC_Q[567],DMC_Q[565],DMC_Q[563],DMC_Q[561]};
assign DMC_Q5[47:44] = {DMC_Q[575],DMC_Q[573],DMC_Q[571],DMC_Q[569]};
assign DMC_Q0[51:48] = {DMC_Q[583],DMC_Q[581],DMC_Q[579],DMC_Q[577]};
assign DMC_Q1[51:48] = {DMC_Q[591],DMC_Q[589],DMC_Q[587],DMC_Q[585]};
assign DMC_Q2[51:48] = {DMC_Q[599],DMC_Q[597],DMC_Q[595],DMC_Q[593]};
assign DMC_Q3[51:48] = {DMC_Q[607],DMC_Q[605],DMC_Q[603],DMC_Q[601]};
assign DMC_Q4[51:48] = {DMC_Q[615],DMC_Q[613],DMC_Q[611],DMC_Q[609]};
assign DMC_Q5[51:48] = {DMC_Q[623],DMC_Q[621],DMC_Q[619],DMC_Q[617]};
assign DMC_Q0[55:52] = {DMC_Q[631],DMC_Q[629],DMC_Q[627],DMC_Q[625]};
assign DMC_Q1[55:52] = {DMC_Q[639],DMC_Q[637],DMC_Q[635],DMC_Q[633]};
assign DMC_Q2[55:52] = {DMC_Q[647],DMC_Q[645],DMC_Q[643],DMC_Q[641]};
assign DMC_Q3[55:52] = {DMC_Q[655],DMC_Q[653],DMC_Q[651],DMC_Q[649]};
assign DMC_Q4[55:52] = {DMC_Q[663],DMC_Q[661],DMC_Q[659],DMC_Q[657]};
assign DMC_Q5[55:52] = {DMC_Q[671],DMC_Q[669],DMC_Q[667],DMC_Q[665]};
assign DMC_Q0[59:56] = {DMC_Q[679],DMC_Q[677],DMC_Q[675],DMC_Q[673]};
assign DMC_Q1[59:56] = {DMC_Q[687],DMC_Q[685],DMC_Q[683],DMC_Q[681]};
assign DMC_Q2[59:56] = {DMC_Q[695],DMC_Q[693],DMC_Q[691],DMC_Q[689]};
assign DMC_Q3[59:56] = {DMC_Q[703],DMC_Q[701],DMC_Q[699],DMC_Q[697]};
assign DMC_Q4[59:56] = {DMC_Q[711],DMC_Q[709],DMC_Q[707],DMC_Q[705]};
assign DMC_Q5[59:56] = {DMC_Q[719],DMC_Q[717],DMC_Q[715],DMC_Q[713]};
assign DMC_Q0[63:60] = {DMC_Q[727],DMC_Q[725],DMC_Q[723],DMC_Q[721]};
assign DMC_Q1[63:60] = {DMC_Q[735],DMC_Q[733],DMC_Q[731],DMC_Q[729]};
assign DMC_Q2[63:60] = {DMC_Q[743],DMC_Q[741],DMC_Q[739],DMC_Q[737]};
assign DMC_Q3[63:60] = {DMC_Q[751],DMC_Q[749],DMC_Q[747],DMC_Q[745]};
assign DMC_Q4[63:60] = {DMC_Q[759],DMC_Q[757],DMC_Q[755],DMC_Q[753]};
assign DMC_Q5[63:60] = {DMC_Q[767],DMC_Q[765],DMC_Q[763],DMC_Q[761]};
assign DMC_Q0[67:64] = {DMC_Q[775],DMC_Q[773],DMC_Q[771],DMC_Q[769]};
assign DMC_Q1[67:64] = {DMC_Q[783],DMC_Q[781],DMC_Q[779],DMC_Q[777]};
assign DMC_Q2[67:64] = {DMC_Q[791],DMC_Q[789],DMC_Q[787],DMC_Q[785]};
assign DMC_Q3[67:64] = {DMC_Q[799],DMC_Q[797],DMC_Q[795],DMC_Q[793]};
assign DMC_Q4[67:64] = {DMC_Q[807],DMC_Q[805],DMC_Q[803],DMC_Q[801]};
assign DMC_Q5[67:64] = {DMC_Q[815],DMC_Q[813],DMC_Q[811],DMC_Q[809]};
assign DMC_Q0[71:68] = {DMC_Q[823],DMC_Q[821],DMC_Q[819],DMC_Q[817]};
assign DMC_Q1[71:68] = {DMC_Q[831],DMC_Q[829],DMC_Q[827],DMC_Q[825]};
assign DMC_Q2[71:68] = {DMC_Q[839],DMC_Q[837],DMC_Q[835],DMC_Q[833]};
assign DMC_Q3[71:68] = {DMC_Q[847],DMC_Q[845],DMC_Q[843],DMC_Q[841]};
assign DMC_Q4[71:68] = {DMC_Q[855],DMC_Q[853],DMC_Q[851],DMC_Q[849]};
assign DMC_Q5[71:68] = {DMC_Q[863],DMC_Q[861],DMC_Q[859],DMC_Q[857]};
assign DMC_Q0[75:72] = {DMC_Q[871],DMC_Q[869],DMC_Q[867],DMC_Q[865]};
assign DMC_Q1[75:72] = {DMC_Q[879],DMC_Q[877],DMC_Q[875],DMC_Q[873]};
assign DMC_Q2[75:72] = {DMC_Q[887],DMC_Q[885],DMC_Q[883],DMC_Q[881]};
assign DMC_Q3[75:72] = {DMC_Q[895],DMC_Q[893],DMC_Q[891],DMC_Q[889]};
assign DMC_Q4[75:72] = {DMC_Q[903],DMC_Q[901],DMC_Q[899],DMC_Q[897]};
assign DMC_Q5[75:72] = {DMC_Q[911],DMC_Q[909],DMC_Q[907],DMC_Q[905]};
assign DMC_Q0[79:76] = {DMC_Q[919],DMC_Q[917],DMC_Q[915],DMC_Q[913]};
assign DMC_Q1[79:76] = {DMC_Q[927],DMC_Q[925],DMC_Q[923],DMC_Q[921]};
assign DMC_Q2[79:76] = {DMC_Q[935],DMC_Q[933],DMC_Q[931],DMC_Q[929]};
assign DMC_Q3[79:76] = {DMC_Q[943],DMC_Q[941],DMC_Q[939],DMC_Q[937]};
assign DMC_Q4[79:76] = {DMC_Q[951],DMC_Q[949],DMC_Q[947],DMC_Q[945]};
assign DMC_Q5[79:76] = {DMC_Q[959],DMC_Q[957],DMC_Q[955],DMC_Q[953]};
assign DMC_Q0[83:80] = {DMC_Q[967],DMC_Q[965],DMC_Q[963],DMC_Q[961]};
assign DMC_Q1[83:80] = {DMC_Q[975],DMC_Q[973],DMC_Q[971],DMC_Q[969]};
assign DMC_Q2[83:80] = {DMC_Q[983],DMC_Q[981],DMC_Q[979],DMC_Q[977]};
assign DMC_Q3[83:80] = {DMC_Q[991],DMC_Q[989],DMC_Q[987],DMC_Q[985]};
assign DMC_Q4[83:80] = {DMC_Q[999],DMC_Q[997],DMC_Q[995],DMC_Q[993]};
assign DMC_Q5[83:80] = {DMC_Q[1007],DMC_Q[1005],DMC_Q[1003],DMC_Q[1001]};
assign DMC_Q0[87:84] = {DMC_Q[1015],DMC_Q[1013],DMC_Q[1011],DMC_Q[1009]};
assign DMC_Q1[87:84] = {DMC_Q[1023],DMC_Q[1021],DMC_Q[1019],DMC_Q[1017]};
assign DMC_Q2[87:84] = {DMC_Q[1031],DMC_Q[1029],DMC_Q[1027],DMC_Q[1025]};
assign DMC_Q3[87:84] = {DMC_Q[1039],DMC_Q[1037],DMC_Q[1035],DMC_Q[1033]};
assign DMC_Q4[87:84] = {DMC_Q[1047],DMC_Q[1045],DMC_Q[1043],DMC_Q[1041]};
assign DMC_Q5[87:84] = {DMC_Q[1055],DMC_Q[1053],DMC_Q[1051],DMC_Q[1049]};
assign DMC_Q0[91:88] = {DMC_Q[1063],DMC_Q[1061],DMC_Q[1059],DMC_Q[1057]};
assign DMC_Q1[91:88] = {DMC_Q[1071],DMC_Q[1069],DMC_Q[1067],DMC_Q[1065]};
assign DMC_Q2[91:88] = {DMC_Q[1079],DMC_Q[1077],DMC_Q[1075],DMC_Q[1073]};
assign DMC_Q3[91:88] = {DMC_Q[1087],DMC_Q[1085],DMC_Q[1083],DMC_Q[1081]};
assign DMC_Q4[91:88] = {DMC_Q[1095],DMC_Q[1093],DMC_Q[1091],DMC_Q[1089]};
assign DMC_Q5[91:88] = {DMC_Q[1103],DMC_Q[1101],DMC_Q[1099],DMC_Q[1097]};
assign DMC_Q0[95:92] = {DMC_Q[1111],DMC_Q[1109],DMC_Q[1107],DMC_Q[1105]};
assign DMC_Q1[95:92] = {DMC_Q[1119],DMC_Q[1117],DMC_Q[1115],DMC_Q[1113]};
assign DMC_Q2[95:92] = {DMC_Q[1127],DMC_Q[1125],DMC_Q[1123],DMC_Q[1121]};
assign DMC_Q3[95:92] = {DMC_Q[1135],DMC_Q[1133],DMC_Q[1131],DMC_Q[1129]};
assign DMC_Q4[95:92] = {DMC_Q[1143],DMC_Q[1141],DMC_Q[1139],DMC_Q[1137]};
assign DMC_Q5[95:92] = {DMC_Q[1151],DMC_Q[1149],DMC_Q[1147],DMC_Q[1145]};
assign DMC_Q0[99:96] = {DMC_Q[1159],DMC_Q[1157],DMC_Q[1155],DMC_Q[1153]};
assign DMC_Q1[99:96] = {DMC_Q[1167],DMC_Q[1165],DMC_Q[1163],DMC_Q[1161]};
assign DMC_Q2[99:96] = {DMC_Q[1175],DMC_Q[1173],DMC_Q[1171],DMC_Q[1169]};
assign DMC_Q3[99:96] = {DMC_Q[1183],DMC_Q[1181],DMC_Q[1179],DMC_Q[1177]};
assign DMC_Q4[99:96] = {DMC_Q[1191],DMC_Q[1189],DMC_Q[1187],DMC_Q[1185]};
assign DMC_Q5[99:96] = {DMC_Q[1199],DMC_Q[1197],DMC_Q[1195],DMC_Q[1193]};
assign DMC_Q0[103:100] = {DMC_Q[1207],DMC_Q[1205],DMC_Q[1203],DMC_Q[1201]};
assign DMC_Q1[103:100] = {DMC_Q[1215],DMC_Q[1213],DMC_Q[1211],DMC_Q[1209]};
assign DMC_Q2[103:100] = {DMC_Q[1223],DMC_Q[1221],DMC_Q[1219],DMC_Q[1217]};
assign DMC_Q3[103:100] = {DMC_Q[1231],DMC_Q[1229],DMC_Q[1227],DMC_Q[1225]};
assign DMC_Q4[103:100] = {DMC_Q[1239],DMC_Q[1237],DMC_Q[1235],DMC_Q[1233]};
assign DMC_Q5[103:100] = {DMC_Q[1247],DMC_Q[1245],DMC_Q[1243],DMC_Q[1241]};
assign DMC_Q0[107:104] = {DMC_Q[1255],DMC_Q[1253],DMC_Q[1251],DMC_Q[1249]};
assign DMC_Q1[107:104] = {DMC_Q[1263],DMC_Q[1261],DMC_Q[1259],DMC_Q[1257]};
assign DMC_Q2[107:104] = {DMC_Q[1271],DMC_Q[1269],DMC_Q[1267],DMC_Q[1265]};
assign DMC_Q3[107:104] = {DMC_Q[1279],DMC_Q[1277],DMC_Q[1275],DMC_Q[1273]};
assign DMC_Q4[107:104] = {DMC_Q[1287],DMC_Q[1285],DMC_Q[1283],DMC_Q[1281]};
assign DMC_Q5[107:104] = {DMC_Q[1295],DMC_Q[1293],DMC_Q[1291],DMC_Q[1289]};
 

//From DMC each DMC2PHY_WR_DQx has 108 bit, then it has to connected to DQ0s of 27 nibbbles of XPHY, where each DQ0 has 4-bit wide
assign DMC_D[7:0] = {nc_dmc_d[3:0],DMC2PHY_WR_DQ0[3:0]};
assign DMC_D[15:8] = {nc_dmc_d[7:4],DMC2PHY_WR_DQ1[3:0]};
assign DMC_D[23:16] = {nc_dmc_d[11:8],DMC2PHY_WR_DQ2[3:0]};
assign DMC_D[31:24] = {nc_dmc_d[15:12],DMC2PHY_WR_DQ3[3:0]};
assign DMC_D[39:32] = {nc_dmc_d[19:16],DMC2PHY_WR_DQ4[3:0]};
assign DMC_D[47:40] = {nc_dmc_d[23:20],DMC2PHY_WR_DQ5[3:0]};
assign DMC_D[55:48] = {nc_dmc_d[27:24],DMC2PHY_WR_DQ0[7:4]};
assign DMC_D[63:56] = {nc_dmc_d[31:28],DMC2PHY_WR_DQ1[7:4]};
assign DMC_D[71:64] = {nc_dmc_d[35:32],DMC2PHY_WR_DQ2[7:4]};
assign DMC_D[79:72] = {nc_dmc_d[39:36],DMC2PHY_WR_DQ3[7:4]};
assign DMC_D[87:80] = {nc_dmc_d[43:40],DMC2PHY_WR_DQ4[7:4]};
assign DMC_D[95:88] = {nc_dmc_d[47:44],DMC2PHY_WR_DQ5[7:4]};
assign DMC_D[103:96] = {nc_dmc_d[51:48],DMC2PHY_WR_DQ0[11:8]};
assign DMC_D[111:104] = {nc_dmc_d[55:52],DMC2PHY_WR_DQ1[11:8]};
assign DMC_D[119:112] = {nc_dmc_d[59:56],DMC2PHY_WR_DQ2[11:8]};
assign DMC_D[127:120] = {nc_dmc_d[63:60],DMC2PHY_WR_DQ3[11:8]};
assign DMC_D[135:128] = {nc_dmc_d[67:64],DMC2PHY_WR_DQ4[11:8]};
assign DMC_D[143:136] = {nc_dmc_d[71:68],DMC2PHY_WR_DQ5[11:8]};
assign DMC_D[151:144] = {nc_dmc_d[75:72],DMC2PHY_WR_DQ0[15:12]};
assign DMC_D[159:152] = {nc_dmc_d[79:76],DMC2PHY_WR_DQ1[15:12]};
assign DMC_D[167:160] = {nc_dmc_d[83:80],DMC2PHY_WR_DQ2[15:12]};
assign DMC_D[175:168] = {nc_dmc_d[87:84],DMC2PHY_WR_DQ3[15:12]};
assign DMC_D[183:176] = {nc_dmc_d[91:88],DMC2PHY_WR_DQ4[15:12]};
assign DMC_D[191:184] = {nc_dmc_d[95:92],DMC2PHY_WR_DQ5[15:12]};
assign DMC_D[199:192] = {nc_dmc_d[99:96],DMC2PHY_WR_DQ0[19:16]};
assign DMC_D[207:200] = {nc_dmc_d[103:100],DMC2PHY_WR_DQ1[19:16]};
assign DMC_D[215:208] = {nc_dmc_d[107:104],DMC2PHY_WR_DQ2[19:16]};
assign DMC_D[223:216] = {nc_dmc_d[111:108],DMC2PHY_WR_DQ3[19:16]};
assign DMC_D[231:224] = {nc_dmc_d[115:112],DMC2PHY_WR_DQ4[19:16]};
assign DMC_D[239:232] = {nc_dmc_d[119:116],DMC2PHY_WR_DQ5[19:16]};
assign DMC_D[247:240] = {nc_dmc_d[123:120],DMC2PHY_WR_DQ0[23:20]};
assign DMC_D[255:248] = {nc_dmc_d[127:124],DMC2PHY_WR_DQ1[23:20]};
assign DMC_D[263:256] = {nc_dmc_d[131:128],DMC2PHY_WR_DQ2[23:20]};
assign DMC_D[271:264] = {nc_dmc_d[135:132],DMC2PHY_WR_DQ3[23:20]};
assign DMC_D[279:272] = {nc_dmc_d[139:136],DMC2PHY_WR_DQ4[23:20]};
assign DMC_D[287:280] = {nc_dmc_d[143:140],DMC2PHY_WR_DQ5[23:20]};
assign DMC_D[295:288] = {nc_dmc_d[147:144],DMC2PHY_WR_DQ0[27:24]};
assign DMC_D[303:296] = {nc_dmc_d[151:148],DMC2PHY_WR_DQ1[27:24]};
assign DMC_D[311:304] = {nc_dmc_d[155:152],DMC2PHY_WR_DQ2[27:24]};
assign DMC_D[319:312] = {nc_dmc_d[159:156],DMC2PHY_WR_DQ3[27:24]};
assign DMC_D[327:320] = {nc_dmc_d[163:160],DMC2PHY_WR_DQ4[27:24]};
assign DMC_D[335:328] = {nc_dmc_d[167:164],DMC2PHY_WR_DQ5[27:24]};
assign DMC_D[343:336] = {nc_dmc_d[171:168],DMC2PHY_WR_DQ0[31:28]};
assign DMC_D[351:344] = {nc_dmc_d[175:172],DMC2PHY_WR_DQ1[31:28]};
assign DMC_D[359:352] = {nc_dmc_d[179:176],DMC2PHY_WR_DQ2[31:28]};
assign DMC_D[367:360] = {nc_dmc_d[183:180],DMC2PHY_WR_DQ3[31:28]};
assign DMC_D[375:368] = {nc_dmc_d[187:184],DMC2PHY_WR_DQ4[31:28]};
assign DMC_D[383:376] = {nc_dmc_d[191:188],DMC2PHY_WR_DQ5[31:28]};
assign DMC_D[391:384] = {nc_dmc_d[195:192],DMC2PHY_WR_DQ0[35:32]};
assign DMC_D[399:392] = {nc_dmc_d[199:196],DMC2PHY_WR_DQ1[35:32]};
assign DMC_D[407:400] = {nc_dmc_d[203:200],DMC2PHY_WR_DQ2[35:32]};
assign DMC_D[415:408] = {nc_dmc_d[207:204],DMC2PHY_WR_DQ3[35:32]};
assign DMC_D[423:416] = {nc_dmc_d[211:208],DMC2PHY_WR_DQ4[35:32]};
assign DMC_D[431:424] = {nc_dmc_d[215:212],DMC2PHY_WR_DQ5[35:32]};
assign DMC_D[439:432] = {nc_dmc_d[219:216],DMC2PHY_WR_DQ0[39:36]};
assign DMC_D[447:440] = {nc_dmc_d[223:220],DMC2PHY_WR_DQ1[39:36]};
assign DMC_D[455:448] = {nc_dmc_d[227:224],DMC2PHY_WR_DQ2[39:36]};
assign DMC_D[463:456] = {nc_dmc_d[231:228],DMC2PHY_WR_DQ3[39:36]};
assign DMC_D[471:464] = {nc_dmc_d[235:232],DMC2PHY_WR_DQ4[39:36]};
assign DMC_D[479:472] = {nc_dmc_d[239:236],DMC2PHY_WR_DQ5[39:36]};
assign DMC_D[487:480] = {nc_dmc_d[243:240],DMC2PHY_WR_DQ0[43:40]};
assign DMC_D[495:488] = {nc_dmc_d[247:244],DMC2PHY_WR_DQ1[43:40]};
assign DMC_D[503:496] = {nc_dmc_d[251:248],DMC2PHY_WR_DQ2[43:40]};
assign DMC_D[511:504] = {nc_dmc_d[255:252],DMC2PHY_WR_DQ3[43:40]};
assign DMC_D[519:512] = {nc_dmc_d[259:256],DMC2PHY_WR_DQ4[43:40]};
assign DMC_D[527:520] = {nc_dmc_d[263:260],DMC2PHY_WR_DQ5[43:40]};
assign DMC_D[535:528] = {nc_dmc_d[267:264],DMC2PHY_WR_DQ0[47:44]};
assign DMC_D[543:536] = {nc_dmc_d[271:268],DMC2PHY_WR_DQ1[47:44]};
assign DMC_D[551:544] = {nc_dmc_d[275:272],DMC2PHY_WR_DQ2[47:44]};
assign DMC_D[559:552] = {nc_dmc_d[279:276],DMC2PHY_WR_DQ3[47:44]};
assign DMC_D[567:560] = {nc_dmc_d[283:280],DMC2PHY_WR_DQ4[47:44]};
assign DMC_D[575:568] = {nc_dmc_d[287:284],DMC2PHY_WR_DQ5[47:44]};
assign DMC_D[583:576] = {nc_dmc_d[291:288],DMC2PHY_WR_DQ0[51:48]};
assign DMC_D[591:584] = {nc_dmc_d[295:292],DMC2PHY_WR_DQ1[51:48]};
assign DMC_D[599:592] = {nc_dmc_d[299:296],DMC2PHY_WR_DQ2[51:48]};
assign DMC_D[607:600] = {nc_dmc_d[303:300],DMC2PHY_WR_DQ3[51:48]};
assign DMC_D[615:608] = {nc_dmc_d[307:304],DMC2PHY_WR_DQ4[51:48]};
assign DMC_D[623:616] = {nc_dmc_d[311:308],DMC2PHY_WR_DQ5[51:48]};
assign DMC_D[631:624] = {nc_dmc_d[315:312],DMC2PHY_WR_DQ0[55:52]};
assign DMC_D[639:632] = {nc_dmc_d[319:316],DMC2PHY_WR_DQ1[55:52]};
assign DMC_D[647:640] = {nc_dmc_d[323:320],DMC2PHY_WR_DQ2[55:52]};
assign DMC_D[655:648] = {nc_dmc_d[327:324],DMC2PHY_WR_DQ3[55:52]};
assign DMC_D[663:656] = {nc_dmc_d[331:328],DMC2PHY_WR_DQ4[55:52]};
assign DMC_D[671:664] = {nc_dmc_d[335:332],DMC2PHY_WR_DQ5[55:52]};
assign DMC_D[679:672] = {nc_dmc_d[339:336],DMC2PHY_WR_DQ0[59:56]};
assign DMC_D[687:680] = {nc_dmc_d[343:340],DMC2PHY_WR_DQ1[59:56]};
assign DMC_D[695:688] = {nc_dmc_d[347:344],DMC2PHY_WR_DQ2[59:56]};
assign DMC_D[703:696] = {nc_dmc_d[351:348],DMC2PHY_WR_DQ3[59:56]};
assign DMC_D[711:704] = {nc_dmc_d[355:352],DMC2PHY_WR_DQ4[59:56]};
assign DMC_D[719:712] = {nc_dmc_d[359:356],DMC2PHY_WR_DQ5[59:56]};
assign DMC_D[727:720] = {nc_dmc_d[363:360],DMC2PHY_WR_DQ0[63:60]};
assign DMC_D[735:728] = {nc_dmc_d[367:364],DMC2PHY_WR_DQ1[63:60]};
assign DMC_D[743:736] = {nc_dmc_d[371:368],DMC2PHY_WR_DQ2[63:60]};
assign DMC_D[751:744] = {nc_dmc_d[375:372],DMC2PHY_WR_DQ3[63:60]};
assign DMC_D[759:752] = {nc_dmc_d[379:376],DMC2PHY_WR_DQ4[63:60]};
assign DMC_D[767:760] = {nc_dmc_d[383:380],DMC2PHY_WR_DQ5[63:60]};
assign DMC_D[775:768] = {nc_dmc_d[387:384],DMC2PHY_WR_DQ0[67:64]};
assign DMC_D[783:776] = {nc_dmc_d[391:388],DMC2PHY_WR_DQ1[67:64]};
assign DMC_D[791:784] = {nc_dmc_d[395:392],DMC2PHY_WR_DQ2[67:64]};
assign DMC_D[799:792] = {nc_dmc_d[399:396],DMC2PHY_WR_DQ3[67:64]};
assign DMC_D[807:800] = {nc_dmc_d[403:400],DMC2PHY_WR_DQ4[67:64]};
assign DMC_D[815:808] = {nc_dmc_d[407:404],DMC2PHY_WR_DQ5[67:64]};
assign DMC_D[823:816] = {nc_dmc_d[411:408],DMC2PHY_WR_DQ0[71:68]};
assign DMC_D[831:824] = {nc_dmc_d[415:412],DMC2PHY_WR_DQ1[71:68]};
   //ch0_reset Route-thru
assign DMC_D[847:840] = {nc_dmc_d[423:420],DMC2PHY_WR_DQ3[71:68]};
assign DMC_D[855:848] = {nc_dmc_d[427:424],DMC2PHY_WR_DQ4[71:68]};
assign DMC_D[863:856] = {nc_dmc_d[431:428],DMC2PHY_WR_DQ5[71:68]};
assign DMC_D[871:864] = {nc_dmc_d[435:432],DMC2PHY_WR_DQ0[75:72]};
assign DMC_D[879:872] = {nc_dmc_d[439:436],DMC2PHY_WR_DQ1[75:72]};
assign DMC_D[887:880] = {nc_dmc_d[443:440],DMC2PHY_WR_DQ2[75:72]};
assign DMC_D[895:888] = {nc_dmc_d[447:444],DMC2PHY_WR_DQ3[75:72]};
assign DMC_D[903:896] = {nc_dmc_d[451:448],DMC2PHY_WR_DQ4[75:72]};
assign DMC_D[911:904] = {nc_dmc_d[455:452],DMC2PHY_WR_DQ5[75:72]};
assign DMC_D[919:912] = {nc_dmc_d[459:456],DMC2PHY_WR_DQ0[79:76]};
assign DMC_D[927:920] = {nc_dmc_d[463:460],DMC2PHY_WR_DQ1[79:76]};
assign DMC_D[935:928] = {nc_dmc_d[467:464],DMC2PHY_WR_DQ2[79:76]};
assign DMC_D[943:936] = {nc_dmc_d[471:468],DMC2PHY_WR_DQ3[79:76]};
assign DMC_D[951:944] = {nc_dmc_d[475:472],DMC2PHY_WR_DQ4[79:76]};
assign DMC_D[959:952] = {nc_dmc_d[479:476],DMC2PHY_WR_DQ5[79:76]};
assign DMC_D[967:960] = {nc_dmc_d[483:480],DMC2PHY_WR_DQ0[83:80]};
assign DMC_D[975:968] = {nc_dmc_d[487:484],DMC2PHY_WR_DQ1[83:80]};
assign DMC_D[983:976] = {nc_dmc_d[491:488],DMC2PHY_WR_DQ2[83:80]};
assign DMC_D[991:984] = {nc_dmc_d[495:492],DMC2PHY_WR_DQ3[83:80]};
assign DMC_D[999:992] = {nc_dmc_d[499:496],DMC2PHY_WR_DQ4[83:80]};
assign DMC_D[1007:1000] = {nc_dmc_d[503:500],DMC2PHY_WR_DQ5[83:80]};
assign DMC_D[1015:1008] = {nc_dmc_d[507:504],DMC2PHY_WR_DQ0[87:84]};
assign DMC_D[1023:1016] = {nc_dmc_d[511:508],DMC2PHY_WR_DQ1[87:84]};
assign DMC_D[1031:1024] = {nc_dmc_d[515:512],DMC2PHY_WR_DQ2[87:84]};
assign DMC_D[1039:1032] = {nc_dmc_d[519:516],DMC2PHY_WR_DQ3[87:84]};
assign DMC_D[1047:1040] = {nc_dmc_d[523:520],DMC2PHY_WR_DQ4[87:84]};
assign DMC_D[1055:1048] = {nc_dmc_d[527:524],DMC2PHY_WR_DQ5[87:84]};
assign DMC_D[1063:1056] = {nc_dmc_d[531:528],DMC2PHY_WR_DQ0[91:88]};
assign DMC_D[1071:1064] = {nc_dmc_d[535:532],DMC2PHY_WR_DQ1[91:88]};
assign DMC_D[1079:1072] = {nc_dmc_d[539:536],DMC2PHY_WR_DQ2[91:88]};
assign DMC_D[1087:1080] = {nc_dmc_d[543:540],DMC2PHY_WR_DQ3[91:88]};
assign DMC_D[1095:1088] = {nc_dmc_d[547:544],DMC2PHY_WR_DQ4[91:88]};
assign DMC_D[1103:1096] = {nc_dmc_d[551:548],DMC2PHY_WR_DQ5[91:88]};
assign DMC_D[1111:1104] = {nc_dmc_d[555:552],DMC2PHY_WR_DQ0[95:92]};
assign DMC_D[1119:1112] = {nc_dmc_d[559:556],DMC2PHY_WR_DQ1[95:92]};
assign DMC_D[1127:1120] = {nc_dmc_d[563:560],DMC2PHY_WR_DQ2[95:92]};
assign DMC_D[1135:1128] = {nc_dmc_d[567:564],DMC2PHY_WR_DQ3[95:92]};
assign DMC_D[1143:1136] = {nc_dmc_d[571:568],DMC2PHY_WR_DQ4[95:92]};
assign DMC_D[1151:1144] = {nc_dmc_d[575:572],DMC2PHY_WR_DQ5[95:92]};
assign DMC_D[1159:1152] = {nc_dmc_d[579:576],DMC2PHY_WR_DQ0[99:96]};
assign DMC_D[1167:1160] = {nc_dmc_d[583:580],DMC2PHY_WR_DQ1[99:96]};
assign DMC_D[1175:1168] = {nc_dmc_d[587:584],DMC2PHY_WR_DQ2[99:96]};
assign DMC_D[1183:1176] = {nc_dmc_d[591:588],DMC2PHY_WR_DQ3[99:96]};
assign DMC_D[1191:1184] = {nc_dmc_d[595:592],DMC2PHY_WR_DQ4[99:96]};
assign DMC_D[1199:1192] = {nc_dmc_d[599:596],DMC2PHY_WR_DQ5[99:96]};
assign DMC_D[1207:1200] = {nc_dmc_d[603:600],DMC2PHY_WR_DQ0[103:100]};
assign DMC_D[1215:1208] = {nc_dmc_d[607:604],DMC2PHY_WR_DQ1[103:100]};
assign DMC_D[1223:1216] = {nc_dmc_d[611:608],DMC2PHY_WR_DQ2[103:100]};
assign DMC_D[1231:1224] = {nc_dmc_d[615:612],DMC2PHY_WR_DQ3[103:100]};
assign DMC_D[1239:1232] = {nc_dmc_d[619:616],DMC2PHY_WR_DQ4[103:100]};
assign DMC_D[1247:1240] = {nc_dmc_d[623:620],DMC2PHY_WR_DQ5[103:100]};
assign DMC_D[1255:1248] = {nc_dmc_d[627:624],DMC2PHY_WR_DQ0[107:104]};
assign DMC_D[1263:1256] = {nc_dmc_d[631:628],DMC2PHY_WR_DQ1[107:104]};
assign DMC_D[1271:1264] = {nc_dmc_d[635:632],DMC2PHY_WR_DQ2[107:104]};
assign DMC_D[1279:1272] = {nc_dmc_d[639:636],DMC2PHY_WR_DQ3[107:104]};
assign DMC_D[1287:1280] = {nc_dmc_d[643:640],DMC2PHY_WR_DQ4[107:104]};
assign DMC_D[1295:1288] = {nc_dmc_d[647:644],DMC2PHY_WR_DQ5[107:104]};

//For alert rouethru, need to connect DMC2PHY_T_TXBIT pin to T of IOBUF
assign DMC2PHY_T_TXBIT_NET0 = DMC2PHY_T_TXBIT0;
assign DMC2PHY_T_TXBIT_NET1 = DMC2PHY_T_TXBIT1;
assign DMC2PHY_T_TXBIT_NET2 = DMC2PHY_T_TXBIT2;



//From advanced IO to DMC
//Instantance Advanced IO Phy
//######
//bank Wrapper Instantiation

 advanced_io_wizard_phy_v1_0_bank_wrapper #(
       .nibble               (C_NIBBLE_EN[0]),
       .INTF                 ("DDR4"),
       .iob_type             (C_IOB_TYPE[53:0]),
       .CASCADE_0            (C_CASCADE_0[8:0]) ,
       .CASCADE_1            (C_CASCADE_1[8:0]) ,
       .CASCADE_2            (C_CASCADE_2[8:0]) ,
       .CASCADE_3            (C_CASCADE_3[8:0]) ,
       .CASCADE_4            (C_CASCADE_4[8:0]) ,
       .CASCADE_5            (C_CASCADE_5[8:0]) ,
       .CONTINUOUS_DQS       (C_CONTINUOUS_DQS[8:0]),
       .CRSE_DLY_EN          (C_CRSE_DLY_EN[8:0]) ,
       .DELAY_VALUE_0        (C_DELAY_VALUE_0[8:0]),
       .DELAY_VALUE_1        (C_DELAY_VALUE_1[8:0]),
       .DELAY_VALUE_2        (C_DELAY_VALUE_2[8:0]),
       .DELAY_VALUE_3        (C_DELAY_VALUE_3[8:0]),
       .DELAY_VALUE_4        (C_DELAY_VALUE_4[8:0]),
       .DELAY_VALUE_5        (C_DELAY_VALUE_5[8:0]),
       .DIS_IDLY_VT_TRACK    (C_DIS_IDLY_VT_TRACK[8:0]) ,
       .DIS_ODLY_VT_TRACK    (C_DIS_ODLY_VT_TRACK[8:0]) ,
       .DIS_QDLY_VT_TRACK    (C_DIS_QDLY_VT_TRACK[8:0]) ,
       .FAST_CK              (C_FAST_CK[8:0]) ,
       .DQS_MODE 	           (C_DQS_MODE[8:0]) ,
       .DQS_SRC 	           (C_DQS_SRC[8:0]) ,
       .EN_CLK_TO_UPPER      (C_EN_CLK_TO_UPPER[8:0]) ,
       .EN_CLK_TO_LOWER      (C_EN_CLK_TO_LOWER[8:0]) ,
       .EN_DYN_DLY_MODE      (C_EN_DYN_DLY_MODE[8:0]) ,
       .EN_OTHER_NCLK        (C_EN_OTHER_NCLK[8:0]) ,
       .EN_OTHER_PCLK        (C_EN_OTHER_PCLK[8:0]) ,
       .FIFO_MODE_0          (C_FIFO_MODE_0[8:0]) ,
       .FIFO_MODE_1          (C_FIFO_MODE_1[8:0]) ,
       .FIFO_MODE_2          (C_FIFO_MODE_2[8:0]) ,
       .FIFO_MODE_3          (C_FIFO_MODE_3[8:0]) ,
       .FIFO_MODE_4          (C_FIFO_MODE_4[8:0]) ,
       .FIFO_MODE_5          (C_FIFO_MODE_5[8:0]) ,
       .IBUF_DIS_SRC_0       (C_IBUF_DIS_SRC_0[8:0]) ,
       .IBUF_DIS_SRC_1       (C_IBUF_DIS_SRC_1[8:0]) ,
       .IBUF_DIS_SRC_2       (C_IBUF_DIS_SRC_2[8:0]) ,
       .IBUF_DIS_SRC_3       (C_IBUF_DIS_SRC_3[8:0]) ,
       .IBUF_DIS_SRC_4       (C_IBUF_DIS_SRC_4[8:0]) ,
       .IBUF_DIS_SRC_5       (C_IBUF_DIS_SRC_5[8:0]) ,
       .INV_RXCLK            (C_INV_RXCLK[8:0]) ,
       .LP4_DQS              (C_LP4_DQS[8:0]) ,
       .ODELAY_BYPASS_0      (C_ODELAY_BYPASS_0[8:0]) ,
       .ODELAY_BYPASS_1      (C_ODELAY_BYPASS_1[8:0]) ,
       .ODELAY_BYPASS_2      (C_ODELAY_BYPASS_2[8:0]) ,
       .ODELAY_BYPASS_3      (C_ODELAY_BYPASS_3[8:0]) ,
       .ODELAY_BYPASS_4      (C_ODELAY_BYPASS_4[8:0]) ,
       .ODELAY_BYPASS_5      (C_ODELAY_BYPASS_5[8:0]) ,
       .ODT_SRC_0            (C_ODT_SRC_0[8:0]) ,
       .ODT_SRC_1            (C_ODT_SRC_1[8:0]) ,
       .ODT_SRC_2            (C_ODT_SRC_2[8:0]) ,
       .ODT_SRC_3            (C_ODT_SRC_3[8:0]) ,
       .ODT_SRC_4            (C_ODT_SRC_4[8:0]) ,
       .ODT_SRC_5            (C_ODT_SRC_5[8:0]) ,
       .REFCLK_FREQUENCY     (C_REFCLK_FREQUENCY[8:0]) , 
       .RX_CLK_PHASE_N       (C_RX_CLK_PHASE_N[8:0]),
       .RX_CLK_PHASE_P       (C_RX_CLK_PHASE_P[8:0]),
       .RX_DATA_WIDTH        (C_RX_DATA_WIDTH[8:0]),
       .RX_GATING            (C_RX_GATING[8:0]),
       .SERIAL_MODE          (C_SERIAL_MODE[8:0]),
       .TBYTE_CTL_0          (C_TBYTE_CTL_0[8:0]),
       .TBYTE_CTL_1          (C_TBYTE_CTL_1[8:0]),
       .TBYTE_CTL_2          (C_TBYTE_CTL_2[8:0]),
       .TBYTE_CTL_3          (C_TBYTE_CTL_3[8:0]),
       .TBYTE_CTL_4          (C_TBYTE_CTL_4[8:0]),
       .TBYTE_CTL_5          (C_TBYTE_CTL_5[8:0]),
       .TXRX_LOOPBACK_0      (C_TXRX_LOOPBACK_0[8:0]),
       .TXRX_LOOPBACK_1      (C_TXRX_LOOPBACK_1[8:0]),
       .TXRX_LOOPBACK_2      (C_TXRX_LOOPBACK_2[8:0]),
       .TXRX_LOOPBACK_3      (C_TXRX_LOOPBACK_3[8:0]),
       .TXRX_LOOPBACK_4      (C_TXRX_LOOPBACK_4[8:0]),
       .TXRX_LOOPBACK_5      (C_TXRX_LOOPBACK_5[8:0]),
       .TX_DATA_WIDTH        (C_TX_DATA_WIDTH[8:0]),
       .TX_GATING            (C_TX_GATING[8:0]),
       .TX_INIT_0            (C_TX_INIT_0[8:0]),
       .TX_INIT_1            (C_TX_INIT_1[8:0]),
       .TX_INIT_2            (C_TX_INIT_2[8:0]),
       .TX_INIT_3            (C_TX_INIT_3[8:0]),
       .TX_INIT_4            (C_TX_INIT_4[8:0]),
       .TX_INIT_5            (C_TX_INIT_5[8:0]),
       .TX_INIT_TRI          (C_TX_INIT_TRI[8:0]),
       .PRIME_VAL            (C_PRIME_VAL[8:0]),
       .VREF_FABRIC          (C_VREF_FABRIC[8:0]),
       .ISTANDARD            (C_ISTANDARD[8:0]),
       .WRITE_LEVELING       (C_WRITE_LEVELING[8:0]),
       .SELF_CALIBRATE       (C_SELF_CALIBRATE[8:0]),
       .TX_OUTPUT_PHASE_90_0 (C_TX_OUTPUT_PHASE_90_0[8:0]),
       .TX_OUTPUT_PHASE_90_1 (C_TX_OUTPUT_PHASE_90_1[8:0]),
       .TX_OUTPUT_PHASE_90_2 (C_TX_OUTPUT_PHASE_90_2[8:0]),
       .TX_OUTPUT_PHASE_90_3 (C_TX_OUTPUT_PHASE_90_3[8:0]),
       .TX_OUTPUT_PHASE_90_4 (C_TX_OUTPUT_PHASE_90_4[8:0]),
       .TX_OUTPUT_PHASE_90_5 (C_TX_OUTPUT_PHASE_90_5[8:0]),
       .TX_OUTPUT_PHASE_90_TRI (C_TX_OUTPUT_PHASE_90_TRI[8:0]),
       .SIM_DEVICE           (SIM_DEVICE),
       .VREF_NIB             (C_VREF_NIB)
  ) BANK_WRAPPER_INST0 (
      .FIFO_EMPTY(DMC_FIFO_EMPTY[8:0]),                                
      .GT_STATUS(DMC_GT_STATUS[8:0]),
      .Q(DMC_Q[431:0]),
      .RIU_RD_VALID(xphy2riu_rd_valid0),                              
      .RIU_RD_DATA(xphy2riu_rd_data0),                          
      //.ctrl_clk(mc_clk_xpll),                            // input wire ctrl_clk
      .PLL_CLK(pll_clktoxphy[0]),                   
      .CTRL_CLK(riu2phy_ctrl_clk0[8:0]),                            // input wire ctrl_clk
      .D(DMC_D[431:0]),
      .FIFO_RDEN(DMC2PHY_FIFO_RDEN[8:0]),                                
      .FIFO_RD_CLK(bank1_xpll0_fifo_rd_clk),                        // input wire fifo_rd_clk
      .PHY_RDCS0(BW_DMC2PHY_RDCS0[35:0]),                           
      .PHY_RDCS1(BW_DMC2PHY_RDCS1[35:0]),                           
      .PHY_RDEN(BW_DMC2PHY_RDEN[35:0]),                            
      .PHY_WRCS0(BW_DMC2PHY_WRCS0[35:0]),                           
      .PHY_WRCS1(BW_DMC2PHY_WRCS1[35:0]),                           
      .PHY_WREN(BW_DMC2PHY_WREN[35:0]),                            // input wire [107 : 0] phy_wren
      .RIU_ADDR(riu2xphy_addr0[71:0]),                       
      .RIU_NIBBLE_SEL(riu2xphy_nibble_sel0[8:0]),            
      .RIU_WR_DATA(riu2xphy_wr_data0[143:0]),            
      .RIU_WR_EN(riu2xphy_wr_en0[8:0]),                       
      .RST(1'b1),
      .T(DMC2PHY_T_TXBIT_NET0),
      .DCI_TERM_DISABLE_EXTERNAL(54'b0),
      .IBUF_DISABLE_EXTERNAL(54'b0),
      .IOB                    ({nc_iob_bank0[53],ch0_ddr4_adr[5],ch0_ddr4_adr[8],ch0_ddr4_adr[11],ch0_ddr4_adr[13],ch0_ddr4_adr[6],ch0_ddr4_odt[0],ch0_ddr4_cke[0],nc_iob_bank0[45],nc_iob_bank0[44],ch0_ddr4_adr[10],ch0_ddr4_bg[0],ch0_ddr4_ba[0],ch0_ddr4_adr[3],ch0_ddr4_adr[16],ch0_ddr4_adr[9],ch0_ddr4_act_n,ch0_ddr4_adr[0],ch0_ddr4_adr[1],ch0_ddr4_adr[2],ch0_ddr4_adr[14],nc_iob_bank0[32],ch0_ddr4_ck_c[0],ch0_ddr4_ck_t[0],ch0_ddr4_adr[15],ch0_ddr4_cs_n[0],nc_iob_bank0[27],nc_iob_bank0[26],ch0_ddr4_ba[1],ch0_ddr4_adr[4],ch0_ddr4_dq[5],ch0_ddr4_dq[7],ch0_ddr4_dq[6],ch0_ddr4_dq[4],ch0_ddr4_dqs_c[0],ch0_ddr4_dqs_t[0],ch0_ddr4_dq[0],ch0_ddr4_dq[2],ch0_ddr4_dq[1],ch0_ddr4_dq[3],ch0_ddr4_adr[7],ch0_ddr4_dm_dbi_n[0],ch0_ddr4_dq[15],ch0_ddr4_dq[13],ch0_ddr4_dq[14],ch0_ddr4_dq[12],ch0_ddr4_dqs_c[1],ch0_ddr4_dqs_t[1],ch0_ddr4_dq[8],ch0_ddr4_dq[10],ch0_ddr4_dq[9],ch0_ddr4_dq[11],ch0_ddr4_adr[12],ch0_ddr4_dm_dbi_n[1]})
  );

 advanced_io_wizard_phy_v1_0_bank_wrapper #(
       .nibble               (C_NIBBLE_EN[1]),
       .INTF                 ("DDR4"),
       .iob_type             (C_IOB_TYPE[107:54]),
       .CASCADE_0            (C_CASCADE_0[17:9]) ,
       .CASCADE_1            (C_CASCADE_1[17:9]) ,
       .CASCADE_2            (C_CASCADE_2[17:9]) ,
       .CASCADE_3            (C_CASCADE_3[17:9]) ,
       .CASCADE_4            (C_CASCADE_4[17:9]) ,
       .CASCADE_5            (C_CASCADE_5[17:9]) ,
       .CONTINUOUS_DQS       (C_CONTINUOUS_DQS[17:9]),
       .CRSE_DLY_EN          (C_CRSE_DLY_EN[17:9]) ,
       .DELAY_VALUE_0        (C_DELAY_VALUE_0[17:9]),
       .DELAY_VALUE_1        (C_DELAY_VALUE_1[17:9]),
       .DELAY_VALUE_2        (C_DELAY_VALUE_2[17:9]),
       .DELAY_VALUE_3        (C_DELAY_VALUE_3[17:9]),
       .DELAY_VALUE_4        (C_DELAY_VALUE_4[17:9]),
       .DELAY_VALUE_5        (C_DELAY_VALUE_5[17:9]),
       .DIS_IDLY_VT_TRACK    (C_DIS_IDLY_VT_TRACK[17:9]) ,
       .DIS_ODLY_VT_TRACK    (C_DIS_ODLY_VT_TRACK[17:9]) ,
       .DIS_QDLY_VT_TRACK    (C_DIS_QDLY_VT_TRACK[17:9]) ,
       .FAST_CK              (C_FAST_CK[17:9]) ,
       .DQS_MODE 	           (C_DQS_MODE[17:9]) ,
       .DQS_SRC 	           (C_DQS_SRC[17:9]) ,
       .EN_CLK_TO_UPPER      (C_EN_CLK_TO_UPPER[17:9]) ,
       .EN_CLK_TO_LOWER      (C_EN_CLK_TO_LOWER[17:9]) ,
       .EN_DYN_DLY_MODE      (C_EN_DYN_DLY_MODE[17:9]) ,
       .EN_OTHER_NCLK        (C_EN_OTHER_NCLK[17:9]) ,
       .EN_OTHER_PCLK        (C_EN_OTHER_PCLK[17:9]) ,
       .FIFO_MODE_0          (C_FIFO_MODE_0[17:9]) ,
       .FIFO_MODE_1          (C_FIFO_MODE_1[17:9]) ,
       .FIFO_MODE_2          (C_FIFO_MODE_2[17:9]) ,
       .FIFO_MODE_3          (C_FIFO_MODE_3[17:9]) ,
       .FIFO_MODE_4          (C_FIFO_MODE_4[17:9]) ,
       .FIFO_MODE_5          (C_FIFO_MODE_5[17:9]) ,
       .IBUF_DIS_SRC_0       (C_IBUF_DIS_SRC_0[17:9]) ,
       .IBUF_DIS_SRC_1       (C_IBUF_DIS_SRC_1[17:9]) ,
       .IBUF_DIS_SRC_2       (C_IBUF_DIS_SRC_2[17:9]) ,
       .IBUF_DIS_SRC_3       (C_IBUF_DIS_SRC_3[17:9]) ,
       .IBUF_DIS_SRC_4       (C_IBUF_DIS_SRC_4[17:9]) ,
       .IBUF_DIS_SRC_5       (C_IBUF_DIS_SRC_5[17:9]) ,
       .INV_RXCLK            (C_INV_RXCLK[17:9]) ,
       .LP4_DQS              (C_LP4_DQS[17:9]) ,
       .ODELAY_BYPASS_0      (C_ODELAY_BYPASS_0[17:9]) ,
       .ODELAY_BYPASS_1      (C_ODELAY_BYPASS_1[17:9]) ,
       .ODELAY_BYPASS_2      (C_ODELAY_BYPASS_2[17:9]) ,
       .ODELAY_BYPASS_3      (C_ODELAY_BYPASS_3[17:9]) ,
       .ODELAY_BYPASS_4      (C_ODELAY_BYPASS_4[17:9]) ,
       .ODELAY_BYPASS_5      (C_ODELAY_BYPASS_5[17:9]) ,
       .ODT_SRC_0            (C_ODT_SRC_0[17:9]) ,
       .ODT_SRC_1            (C_ODT_SRC_1[17:9]) ,
       .ODT_SRC_2            (C_ODT_SRC_2[17:9]) ,
       .ODT_SRC_3            (C_ODT_SRC_3[17:9]) ,
       .ODT_SRC_4            (C_ODT_SRC_4[17:9]) ,
       .ODT_SRC_5            (C_ODT_SRC_5[17:9]) ,
       .REFCLK_FREQUENCY     (C_REFCLK_FREQUENCY[17:9]) , 
       .RX_CLK_PHASE_N       (C_RX_CLK_PHASE_N[17:9]),
       .RX_CLK_PHASE_P       (C_RX_CLK_PHASE_P[17:9]),
       .RX_DATA_WIDTH        (C_RX_DATA_WIDTH[17:9]),
       .RX_GATING            (C_RX_GATING[17:9]),
       .SERIAL_MODE          (C_SERIAL_MODE[17:9]),
       .TBYTE_CTL_0          (C_TBYTE_CTL_0[17:9]),
       .TBYTE_CTL_1          (C_TBYTE_CTL_1[17:9]),
       .TBYTE_CTL_2          (C_TBYTE_CTL_2[17:9]),
       .TBYTE_CTL_3          (C_TBYTE_CTL_3[17:9]),
       .TBYTE_CTL_4          (C_TBYTE_CTL_4[17:9]),
       .TBYTE_CTL_5          (C_TBYTE_CTL_5[17:9]),
       .TXRX_LOOPBACK_0      (C_TXRX_LOOPBACK_0[17:9]),
       .TXRX_LOOPBACK_1      (C_TXRX_LOOPBACK_1[17:9]),
       .TXRX_LOOPBACK_2      (C_TXRX_LOOPBACK_2[17:9]),
       .TXRX_LOOPBACK_3      (C_TXRX_LOOPBACK_3[17:9]),
       .TXRX_LOOPBACK_4      (C_TXRX_LOOPBACK_4[17:9]),
       .TXRX_LOOPBACK_5      (C_TXRX_LOOPBACK_5[17:9]),
       .TX_DATA_WIDTH        (C_TX_DATA_WIDTH[17:9]),
       .TX_GATING            (C_TX_GATING[17:9]),
       .TX_INIT_0            (C_TX_INIT_0[17:9]),
       .TX_INIT_1            (C_TX_INIT_1[17:9]),
       .TX_INIT_2            (C_TX_INIT_2[17:9]),
       .TX_INIT_3            (C_TX_INIT_3[17:9]),
       .TX_INIT_4            (C_TX_INIT_4[17:9]),
       .TX_INIT_5            (C_TX_INIT_5[17:9]),
       .TX_INIT_TRI          (C_TX_INIT_TRI[17:9]),
       .PRIME_VAL            (C_PRIME_VAL[17:9]),
       .VREF_FABRIC          (C_VREF_FABRIC[17:9]),
       .ISTANDARD            (C_ISTANDARD[17:9]),
       .WRITE_LEVELING       (C_WRITE_LEVELING[17:9]),
       .SELF_CALIBRATE       (C_SELF_CALIBRATE[17:9]),
       .TX_OUTPUT_PHASE_90_0 (C_TX_OUTPUT_PHASE_90_0[17:9]),
       .TX_OUTPUT_PHASE_90_1 (C_TX_OUTPUT_PHASE_90_1[17:9]),
       .TX_OUTPUT_PHASE_90_2 (C_TX_OUTPUT_PHASE_90_2[17:9]),
       .TX_OUTPUT_PHASE_90_3 (C_TX_OUTPUT_PHASE_90_3[17:9]),
       .TX_OUTPUT_PHASE_90_4 (C_TX_OUTPUT_PHASE_90_4[17:9]),
       .TX_OUTPUT_PHASE_90_5 (C_TX_OUTPUT_PHASE_90_5[17:9]),
       .TX_OUTPUT_PHASE_90_TRI (C_TX_OUTPUT_PHASE_90_TRI[17:9]),
       .SIM_DEVICE           (SIM_DEVICE),
       .VREF_NIB             (C_VREF_NIB)
  ) BANK_WRAPPER_INST1 (
      .FIFO_EMPTY(DMC_FIFO_EMPTY[17:9]),                                
      .GT_STATUS(DMC_GT_STATUS[17:9]),
      .Q(DMC_Q[863:432]),
      .RIU_RD_VALID(xphy2riu_rd_valid1),                              
      .RIU_RD_DATA(xphy2riu_rd_data1),                          
      //.ctrl_clk(mc_clk_xpll),                            // input wire ctrl_clk
      .PLL_CLK(pll_clktoxphy[1]),                   
      .CTRL_CLK(riu2phy_ctrl_clk1[8:0]),                            // input wire ctrl_clk
      .D(DMC_D[863:432]),
      .FIFO_RDEN(DMC2PHY_FIFO_RDEN[17:9]),                                
      .FIFO_RD_CLK(bank1_xpll0_fifo_rd_clk),                        // input wire fifo_rd_clk
      .PHY_RDCS0(BW_DMC2PHY_RDCS0[71:36]),                           
      .PHY_RDCS1(BW_DMC2PHY_RDCS1[71:36]),                           
      .PHY_RDEN(BW_DMC2PHY_RDEN[71:36]),                            
      .PHY_WRCS0(BW_DMC2PHY_WRCS0[71:36]),                           
      .PHY_WRCS1(BW_DMC2PHY_WRCS1[71:36]),                           
      .PHY_WREN(BW_DMC2PHY_WREN[71:36]),                            // input wire [107 : 0] phy_wren
      .RIU_ADDR(riu2xphy_addr1[71:0]),                       
      .RIU_NIBBLE_SEL(riu2xphy_nibble_sel1[8:0]),            
      .RIU_WR_DATA(riu2xphy_wr_data1[143:0]),            
      .RIU_WR_EN(riu2xphy_wr_en1[8:0]),                       
      .RST(1'b1),
      .T(DMC2PHY_T_TXBIT_NET1),
      .DCI_TERM_DISABLE_EXTERNAL(54'b0),
      .IBUF_DISABLE_EXTERNAL(54'b0),
      .IOB                    ({nc_iob_bank1[53],nc_iob_bank1[52],nc_iob_bank1[51],nc_iob_bank1[50],nc_iob_bank1[49],nc_iob_bank1[48],ch0_ddr4_dq[45],ch0_ddr4_dq[47],ch0_ddr4_dq[42],ch0_ddr4_dq[40],ch0_ddr4_dqs_c[5],ch0_ddr4_dqs_t[5],ch0_ddr4_dq[43],ch0_ddr4_dq[41],ch0_ddr4_dq[44],ch0_ddr4_dq[46],nc_iob_bank1[37],ch0_ddr4_dm_dbi_n[5],ch0_ddr4_dq[23],ch0_ddr4_dq[18],ch0_ddr4_dq[19],ch0_ddr4_dq[22],ch0_ddr4_dqs_c[2],ch0_ddr4_dqs_t[2],ch0_ddr4_dq[17],ch0_ddr4_dq[21],ch0_ddr4_dq[16],ch0_ddr4_dq[20],nc_iob_bank1[25],ch0_ddr4_dm_dbi_n[2],ch0_ddr4_dq[36],ch0_ddr4_dq[32],ch0_ddr4_dq[38],ch0_ddr4_dq[39],nc_iob_bank1[19],ch0_ddr4_dm_dbi_n[4],ch0_ddr4_dq[34],ch0_ddr4_dq[33],ch0_ddr4_dq[35],ch0_ddr4_dq[37],ch0_ddr4_dqs_c[4],ch0_ddr4_dqs_t[4],ch0_ddr4_dq[25],ch0_ddr4_dq[27],ch0_ddr4_dq[28],ch0_ddr4_dq[30],ch0_ddr4_dqs_c[3],ch0_ddr4_dqs_t[3],ch0_ddr4_dq[29],ch0_ddr4_dq[31],ch0_ddr4_dq[26],ch0_ddr4_dq[24],nc_iob_bank1[1],ch0_ddr4_dm_dbi_n[3]})
  );

 advanced_io_wizard_phy_v1_0_bank_wrapper #(
       .nibble               (C_NIBBLE_EN[2]),
       .INTF                 ("DDR4"),
       .iob_type             (C_IOB_TYPE[161:108]),
       .CASCADE_0            (C_CASCADE_0[26:18]) ,
       .CASCADE_1            (C_CASCADE_1[26:18]) ,
       .CASCADE_2            (C_CASCADE_2[26:18]) ,
       .CASCADE_3            (C_CASCADE_3[26:18]) ,
       .CASCADE_4            (C_CASCADE_4[26:18]) ,
       .CASCADE_5            (C_CASCADE_5[26:18]) ,
       .CONTINUOUS_DQS       (C_CONTINUOUS_DQS[26:18]),
       .CRSE_DLY_EN          (C_CRSE_DLY_EN[26:18]) ,
       .DELAY_VALUE_0        (C_DELAY_VALUE_0[26:18]),
       .DELAY_VALUE_1        (C_DELAY_VALUE_1[26:18]),
       .DELAY_VALUE_2        (C_DELAY_VALUE_2[26:18]),
       .DELAY_VALUE_3        (C_DELAY_VALUE_3[26:18]),
       .DELAY_VALUE_4        (C_DELAY_VALUE_4[26:18]),
       .DELAY_VALUE_5        (C_DELAY_VALUE_5[26:18]),
       .DIS_IDLY_VT_TRACK    (C_DIS_IDLY_VT_TRACK[26:18]) ,
       .DIS_ODLY_VT_TRACK    (C_DIS_ODLY_VT_TRACK[26:18]) ,
       .DIS_QDLY_VT_TRACK    (C_DIS_QDLY_VT_TRACK[26:18]) ,
       .FAST_CK              (C_FAST_CK[26:18]) ,
       .DQS_MODE 	           (C_DQS_MODE[26:18]) ,
       .DQS_SRC 	           (C_DQS_SRC[26:18]) ,
       .EN_CLK_TO_UPPER      (C_EN_CLK_TO_UPPER[26:18]) ,
       .EN_CLK_TO_LOWER      (C_EN_CLK_TO_LOWER[26:18]) ,
       .EN_DYN_DLY_MODE      (C_EN_DYN_DLY_MODE[26:18]) ,
       .EN_OTHER_NCLK        (C_EN_OTHER_NCLK[26:18]) ,
       .EN_OTHER_PCLK        (C_EN_OTHER_PCLK[26:18]) ,
       .FIFO_MODE_0          (C_FIFO_MODE_0[26:18]) ,
       .FIFO_MODE_1          (C_FIFO_MODE_1[26:18]) ,
       .FIFO_MODE_2          (C_FIFO_MODE_2[26:18]) ,
       .FIFO_MODE_3          (C_FIFO_MODE_3[26:18]) ,
       .FIFO_MODE_4          (C_FIFO_MODE_4[26:18]) ,
       .FIFO_MODE_5          (C_FIFO_MODE_5[26:18]) ,
       .IBUF_DIS_SRC_0       (C_IBUF_DIS_SRC_0[26:18]) ,
       .IBUF_DIS_SRC_1       (C_IBUF_DIS_SRC_1[26:18]) ,
       .IBUF_DIS_SRC_2       (C_IBUF_DIS_SRC_2[26:18]) ,
       .IBUF_DIS_SRC_3       (C_IBUF_DIS_SRC_3[26:18]) ,
       .IBUF_DIS_SRC_4       (C_IBUF_DIS_SRC_4[26:18]) ,
       .IBUF_DIS_SRC_5       (C_IBUF_DIS_SRC_5[26:18]) ,
       .INV_RXCLK            (C_INV_RXCLK[26:18]) ,
       .LP4_DQS              (C_LP4_DQS[26:18]) ,
       .ODELAY_BYPASS_0      (C_ODELAY_BYPASS_0[26:18]) ,
       .ODELAY_BYPASS_1      (C_ODELAY_BYPASS_1[26:18]) ,
       .ODELAY_BYPASS_2      (C_ODELAY_BYPASS_2[26:18]) ,
       .ODELAY_BYPASS_3      (C_ODELAY_BYPASS_3[26:18]) ,
       .ODELAY_BYPASS_4      (C_ODELAY_BYPASS_4[26:18]) ,
       .ODELAY_BYPASS_5      (C_ODELAY_BYPASS_5[26:18]) ,
       .ODT_SRC_0            (C_ODT_SRC_0[26:18]) ,
       .ODT_SRC_1            (C_ODT_SRC_1[26:18]) ,
       .ODT_SRC_2            (C_ODT_SRC_2[26:18]) ,
       .ODT_SRC_3            (C_ODT_SRC_3[26:18]) ,
       .ODT_SRC_4            (C_ODT_SRC_4[26:18]) ,
       .ODT_SRC_5            (C_ODT_SRC_5[26:18]) ,
       .REFCLK_FREQUENCY     (C_REFCLK_FREQUENCY[26:18]) , 
       .RX_CLK_PHASE_N       (C_RX_CLK_PHASE_N[26:18]),
       .RX_CLK_PHASE_P       (C_RX_CLK_PHASE_P[26:18]),
       .RX_DATA_WIDTH        (C_RX_DATA_WIDTH[26:18]),
       .RX_GATING            (C_RX_GATING[26:18]),
       .SERIAL_MODE          (C_SERIAL_MODE[26:18]),
       .TBYTE_CTL_0          (C_TBYTE_CTL_0[26:18]),
       .TBYTE_CTL_1          (C_TBYTE_CTL_1[26:18]),
       .TBYTE_CTL_2          (C_TBYTE_CTL_2[26:18]),
       .TBYTE_CTL_3          (C_TBYTE_CTL_3[26:18]),
       .TBYTE_CTL_4          (C_TBYTE_CTL_4[26:18]),
       .TBYTE_CTL_5          (C_TBYTE_CTL_5[26:18]),
       .TXRX_LOOPBACK_0      (C_TXRX_LOOPBACK_0[26:18]),
       .TXRX_LOOPBACK_1      (C_TXRX_LOOPBACK_1[26:18]),
       .TXRX_LOOPBACK_2      (C_TXRX_LOOPBACK_2[26:18]),
       .TXRX_LOOPBACK_3      (C_TXRX_LOOPBACK_3[26:18]),
       .TXRX_LOOPBACK_4      (C_TXRX_LOOPBACK_4[26:18]),
       .TXRX_LOOPBACK_5      (C_TXRX_LOOPBACK_5[26:18]),
       .TX_DATA_WIDTH        (C_TX_DATA_WIDTH[26:18]),
       .TX_GATING            (C_TX_GATING[26:18]),
       .TX_INIT_0            (C_TX_INIT_0[26:18]),
       .TX_INIT_1            (C_TX_INIT_1[26:18]),
       .TX_INIT_2            (C_TX_INIT_2[26:18]),
       .TX_INIT_3            (C_TX_INIT_3[26:18]),
       .TX_INIT_4            (C_TX_INIT_4[26:18]),
       .TX_INIT_5            (C_TX_INIT_5[26:18]),
       .TX_INIT_TRI          (C_TX_INIT_TRI[26:18]),
       .PRIME_VAL            (C_PRIME_VAL[26:18]),
       .VREF_FABRIC          (C_VREF_FABRIC[26:18]),
       .ISTANDARD            (C_ISTANDARD[26:18]),
       .WRITE_LEVELING       (C_WRITE_LEVELING[26:18]),
       .SELF_CALIBRATE       (C_SELF_CALIBRATE[26:18]),
       .TX_OUTPUT_PHASE_90_0 (C_TX_OUTPUT_PHASE_90_0[26:18]),
       .TX_OUTPUT_PHASE_90_1 (C_TX_OUTPUT_PHASE_90_1[26:18]),
       .TX_OUTPUT_PHASE_90_2 (C_TX_OUTPUT_PHASE_90_2[26:18]),
       .TX_OUTPUT_PHASE_90_3 (C_TX_OUTPUT_PHASE_90_3[26:18]),
       .TX_OUTPUT_PHASE_90_4 (C_TX_OUTPUT_PHASE_90_4[26:18]),
       .TX_OUTPUT_PHASE_90_5 (C_TX_OUTPUT_PHASE_90_5[26:18]),
       .TX_OUTPUT_PHASE_90_TRI (C_TX_OUTPUT_PHASE_90_TRI[26:18]),
       .SIM_DEVICE           (SIM_DEVICE),
       .VREF_NIB             (C_VREF_NIB)
  ) BANK_WRAPPER_INST2 (
      .FIFO_EMPTY(DMC_FIFO_EMPTY[26:18]),                                
      .GT_STATUS(DMC_GT_STATUS[26:18]),
      .Q(DMC_Q[1295:864]),
      .RIU_RD_VALID(xphy2riu_rd_valid2),                              
      .RIU_RD_DATA(xphy2riu_rd_data2),                          
      //.ctrl_clk(mc_clk_xpll),                            // input wire ctrl_clk
      .PLL_CLK(pll_clktoxphy[2]),                   
      .CTRL_CLK(riu2phy_ctrl_clk2[8:0]),                            // input wire ctrl_clk
      .D(DMC_D[1295:864]),
      .FIFO_RDEN(DMC2PHY_FIFO_RDEN[26:18]),                                
      .FIFO_RD_CLK(bank1_xpll0_fifo_rd_clk),                        // input wire fifo_rd_clk
      .PHY_RDCS0(BW_DMC2PHY_RDCS0[107:72]),                           
      .PHY_RDCS1(BW_DMC2PHY_RDCS1[107:72]),                           
      .PHY_RDEN(BW_DMC2PHY_RDEN[107:72]),                            
      .PHY_WRCS0(BW_DMC2PHY_WRCS0[107:72]),                           
      .PHY_WRCS1(BW_DMC2PHY_WRCS1[107:72]),                           
      .PHY_WREN(BW_DMC2PHY_WREN[107:72]),                            // input wire [107 : 0] phy_wren
      .RIU_ADDR(riu2xphy_addr2[71:0]),                       
      .RIU_NIBBLE_SEL(riu2xphy_nibble_sel2[8:0]),            
      .RIU_WR_DATA(riu2xphy_wr_data2[143:0]),            
      .RIU_WR_EN(riu2xphy_wr_en2[8:0]),                       
      .RST(1'b1),
      .T(DMC2PHY_T_TXBIT_NET2),
      .DCI_TERM_DISABLE_EXTERNAL(54'b0),
      .IBUF_DISABLE_EXTERNAL(54'b0),
      .IOB                    ({nc_iob_bank2[53],nc_iob_bank2[52],nc_iob_bank2[51],nc_iob_bank2[50],nc_iob_bank2[49],nc_iob_bank2[48],nc_iob_bank2[47],nc_iob_bank2[46],nc_iob_bank2[45],nc_iob_bank2[44],nc_iob_bank2[43],nc_iob_bank2[42],nc_iob_bank2[41],nc_iob_bank2[40],nc_iob_bank2[39],nc_iob_bank2[38],nc_iob_bank2[37],nc_iob_bank2[36],nc_iob_bank2[35],nc_iob_bank2[34],nc_iob_bank2[33],nc_iob_bank2[32],nc_iob_bank2[31],nc_iob_bank2[30],nc_iob_bank2[29],nc_iob_bank2[28],nc_iob_bank2[27],nc_iob_bank2[26],nc_iob_bank2[25],nc_iob_bank2[24],ch0_ddr4_dq[61],ch0_ddr4_dq[59],ch0_ddr4_dq[60],ch0_ddr4_dq[62],ch0_ddr4_dqs_c[7],ch0_ddr4_dqs_t[7],ch0_ddr4_dq[56],ch0_ddr4_dq[58],ch0_ddr4_dq[63],ch0_ddr4_dq[57],nc_iob_bank2[13],ch0_ddr4_dm_dbi_n[7],ch0_ddr4_dq[51],ch0_ddr4_dq[55],ch0_ddr4_dq[52],ch0_ddr4_dq[54],nc_iob_bank2[7],ch0_ddr4_dm_dbi_n[6],ch0_ddr4_dq[50],ch0_ddr4_dq[48],ch0_ddr4_dq[53],ch0_ddr4_dq[49],ch0_ddr4_dqs_c[6],ch0_ddr4_dqs_t[6]})
  );


`endif

wire bank1_xpll_clkoutphy_casc_out;






(* DONT_TOUCH = "TRUE" *) XPLL 
 #(
  . CLKFBOUT_MULT      (CLKFBOUT_MULT_PLL_SLAVE)
  ,.CLKFBOUT_PHASE     (0.000)
  ,.CLKIN_PERIOD       (XPLL_F0_PLL0_CLKOUT0)
  ,.CLKOUT0_DIVIDE     (2)
  ,.CLKOUT0_DUTY_CYCLE (0.500)
  ,.CLKOUT0_PHASE      (0.000)
  ,.CLKOUT1_DIVIDE     (8)
  ,.CLKOUT1_DUTY_CYCLE (0.500)
  ,.CLKOUT1_PHASE      (0.000)
  ,.CLKOUT2_DIVIDE     (2)
  ,.CLKOUT2_DUTY_CYCLE (0.500)
  ,.CLKOUT2_PHASE      (0.000)
  ,.CLKOUT3_DIVIDE     (2)
  ,.CLKOUT3_DUTY_CYCLE (0.500)
  ,.CLKOUT3_PHASE      (0.000)
  ,.CLKOUTPHY_DIVIDE   (CLKOUTPHY_DIVIDE_PLL_SLAVE)
  ,.DIV4_CLKOUT3       (1'b0)
  ,.DIV4_CLKOUT012     (1'b0)
  ,.CLKOUTPHY_CASCIN_EN     (1'b1)
  ,.CLKOUTPHY_CASCOUT_EN     (1'b0)
  ,.DESKEW_MUXIN_SEL   (1'b0)
  ,.DESKEW2_MUXIN_SEL  (1'b0)
  ,.DIVCLK_DIVIDE      (DIVCLK_DIVIDE_PLL_SLAVE)
  ,.IS_CLKIN_INVERTED  (1'b0)
  ,.IS_PSEN_INVERTED   (1'b0)
  ,.IS_PSINCDEC_INVERTED (1'b0)
  ,.IS_PWRDWN_INVERTED (1'b0)
  ,.IS_RST_INVERTED (1'b0)
  ,.REF_JITTER (0.010)
  ,.XPLL_CONNECT_TO_NOCMC(XPLL_CONNECT_TO_NOCMC)

) u_xpll0_bank0 
(
 .CLKOUT0()
,.CLKOUT1()
,.CLKOUT2()
,.CLKOUT3()
,.CLKOUTPHY(bank0xpll_clkoutphy)
,.DO()
,.DRDY()
,.LOCKED(pll0_locked)
,.PSDONE()
,.RIU_RD_DATA(xpll2riu_rd_data0)
,.RIU_VALID(xpll2riu_rd_valid0)
,.CLKIN(bank1_clkout0)
,.CLKOUTPHYEN(1'b1)
,.CLKOUTPHY_CASC_IN(bank1_xpll_clkoutphy_casc_out)
,.CLKOUTPHY_CASC_OUT()
,.DADDR()
,.DCLK()
,.DEN()
,.DI()
,.DWE()
,.PSCLK()
,.PSEN()
,.PSINCDEC()
,.PWRDWN()
,.RIU_ADDR(riu2xphy_addr0[79:72])
,.RIU_CLK(riu2phy_ctrl_clk0[9])
,.RIU_NIBBLE_SEL(riu2xphy_nibble_sel0[9])
,.RIU_WR_DATA(riu2xphy_wr_data0[159:144])
,.RIU_WR_EN(riu2xphy_wr_en0[9])
,.RST()
);


(* DONT_TOUCH = "TRUE" *) XPLL 
#(
  . CLKFBOUT_MULT      (XPLL_F0_CLKFBOUT_MULT)
  ,.CLKFBOUT_PHASE     (0.000)
  ,.CLKIN_PERIOD       (XPLL_F0_INPUT_CLK)
  ,.CLKOUT0_DIVIDE     (XPLL_F0_CLKOUT1_DIVIDE)
  ,.CLKOUT0_DUTY_CYCLE (0.500)
  ,.CLKOUT0_PHASE      (0.000)
  ,.CLKOUT1_DIVIDE     (XPLL_F0_CLKOUT1_DIVIDE)
  ,.CLKOUT1_DUTY_CYCLE (0.500)
  ,.CLKOUT1_PHASE      (XPLL_CLKOUT1_PHASE)
  ,.CLKOUT2_PHASE      (XPLL_CLKOUT2_PHASE)
  ,.CLKOUT1_PHASE_CTRL ('h3)
  ,.CLKOUT2_PHASE_CTRL ('h1)
  ,.DESKEW_DELAY1      (XPLL_DSKW_DLY1)
  ,.DESKEW_DELAY2      (XPLL_DSKW_DLY2)
  ,.DESKEW_DELAY_EN1   (XPLL_DSKW_DLY_EN1)
  ,.DESKEW_DELAY_EN2   (XPLL_DSKW_DLY_EN2)
  ,.DESKEW_DELAY_PATH1 (XPLL_DSKW_DLY_PATH1)
  ,.DESKEW_DELAY_PATH2 (XPLL_DSKW_DLY_PATH2)
  ,.CLKOUT2_DIVIDE     (XPLL_F0_CLKOUT1_DIVIDE)
  ,.CLKOUT2_DUTY_CYCLE (0.500)
  ,.CLKOUT3_DIVIDE     (2)
  ,.CLKOUT3_DUTY_CYCLE (0.500)
  ,.CLKOUT3_PHASE      (0.000)
  ,.CLKOUTPHY_DIVIDE   (XPLL_F0_CLKOUTPHY_DIVIDE)
  ,.DIVCLK_DIVIDE      (XPLL_F0_DIVCLK_DIVIDE)
  ,.DIV4_CLKOUT3       (XPLL_DIV4_CLKOUT3)
  ,.DIV4_CLKOUT012     (XPLL_DIV4_CLKOUT012)
  ,.CLKOUTPHY_CASCIN_EN     (1'b1)
  ,.CLKOUTPHY_CASCOUT_EN     (1'b1)
  ,.DESKEW_MUXIN_SEL   (XPLL_DESKEW_MUXIN_SEL)
  ,.DESKEW2_MUXIN_SEL  (XPLL_DESKEW2_MUXIN_SEL)
  ,.IS_CLKIN_INVERTED  (1'b0)
  ,.IS_PSEN_INVERTED   (1'b0)
  ,.IS_PSINCDEC_INVERTED (1'b0)
  ,.IS_PWRDWN_INVERTED (1'b0)
  ,.IS_RST_INVERTED (1'b0)
  ,.REF_JITTER (0.010)
  ,.XPLL_CONNECT_TO_NOCMC(XPLL_CONNECT_TO_NOCMC)

) u_xpll0_bank1 
(
 .CLKOUT0(bank1_clkout0)
,.CLKOUT1(mc_clk_xpll)
,.CLKOUT2(bank1_xpll0_fifo_rd_clk)
,.CLKOUT3()
,.CLKOUTPHY(pll_clk_xpll)
,.DO()
,.DRDY()
,.LOCKED(pll1_locked)
,.PSDONE()
,.RIU_RD_DATA(xpll2riu_rd_data1)
,.RIU_VALID(xpll2riu_rd_valid1)
,.CLKIN(sys_clk_O)
,.CLKOUTPHYEN(1'b1)
,.CLKOUTPHY_CASC_IN(bank1_xpll_clkoutphy_casc_out)
,.CLKOUTPHY_CASC_OUT(bank1_xpll_clkoutphy_casc_out)
,.DADDR()
,.DCLK()
,.DEN()
,.DI()
,.DWE()
,.PSCLK()
,.PSEN()
,.PSINCDEC()
,.PWRDWN()
,.RIU_ADDR(riu2xphy_addr1[79:72])
,.RIU_CLK(riu2phy_ctrl_clk1[9])
,.RIU_NIBBLE_SEL(riu2xphy_nibble_sel1[9])
,.RIU_WR_DATA(riu2xphy_wr_data1[159:144])
,.RIU_WR_EN(riu2xphy_wr_en1[9])
,.RST()
);


(* DONT_TOUCH = "TRUE" *) XPLL 
 #(
  . CLKFBOUT_MULT      (CLKFBOUT_MULT_PLL_SLAVE)
  ,.CLKFBOUT_PHASE     (0.000)
  ,.CLKIN_PERIOD       (XPLL_F0_PLL0_CLKOUT0)
  ,.CLKOUT0_DIVIDE     (2)
  ,.CLKOUT0_DUTY_CYCLE (0.500)
  ,.CLKOUT0_PHASE      (0.000)
  ,.CLKOUT1_DIVIDE     (8)
  ,.CLKOUT1_DUTY_CYCLE (0.500)
  ,.CLKOUT1_PHASE      (0.000)
  ,.CLKOUT2_DIVIDE     (2)
  ,.CLKOUT2_DUTY_CYCLE (0.500)
  ,.CLKOUT2_PHASE      (0.000)
  ,.CLKOUT3_DIVIDE     (2)
  ,.CLKOUT3_DUTY_CYCLE (0.500)
  ,.CLKOUT3_PHASE      (0.000)
  ,.CLKOUTPHY_DIVIDE   (CLKOUTPHY_DIVIDE_PLL_SLAVE)
  ,.DIVCLK_DIVIDE      (DIVCLK_DIVIDE_PLL_SLAVE)
//  ,.INTERP0_SEL        (2'b00)
//  ,.INTERP1_SEL        (2'b00)
//  ,.INTERP2_SEL        (2'b00)
//  ,.INTERP3_SEL        (2'b00)
  ,.DIV4_CLKOUT3       (1'b0)
  ,.DIV4_CLKOUT012     (1'b0)
  ,.CLKOUTPHY_CASCIN_EN     (1'b1)
  ,.CLKOUTPHY_CASCOUT_EN     (1'b0)
  ,.DESKEW_MUXIN_SEL   (1'b0)
  ,.DESKEW2_MUXIN_SEL  (1'b0)
  ,.IS_CLKIN_INVERTED  (1'b0)
  ,.IS_PSEN_INVERTED   (1'b0)
  ,.IS_PSINCDEC_INVERTED (1'b0)
  ,.IS_PWRDWN_INVERTED (1'b0)
  ,.IS_RST_INVERTED (1'b0)
  ,.REF_JITTER (0.010)
  ,.XPLL_CONNECT_TO_NOCMC(XPLL_CONNECT_TO_NOCMC)

) u_xpll0_bank2 
(
 .CLKOUT0()
,.CLKOUT1()
,.CLKOUT2()
,.CLKOUT3()
,.CLKOUTPHY(bank2xpll_clkoutphy)
,.DO()
,.DRDY()
,.LOCKED(pll2_locked)
,.PSDONE()
,.RIU_RD_DATA(xpll2riu_rd_data2)
,.RIU_VALID(xpll2riu_rd_valid2)
//,.CLKFB_DESKEW()
,.CLKIN(bank1_clkout0)
//,.CLKIN_DESKEW()
,.CLKOUTPHYEN(1'b1)
,.CLKOUTPHY_CASC_IN(bank1_xpll_clkoutphy_casc_out)
,.CLKOUTPHY_CASC_OUT()
,.DADDR()
,.DCLK()
,.DEN()
,.DI()
,.DWE()
,.PSCLK()
,.PSEN()
,.PSINCDEC()
,.PWRDWN()
,.RIU_ADDR(riu2xphy_addr2[79:72])
,.RIU_CLK(riu2phy_ctrl_clk2[9])
,.RIU_NIBBLE_SEL(riu2xphy_nibble_sel2[9])
,.RIU_WR_DATA(riu2xphy_wr_data2[159:144])
,.RIU_WR_EN(riu2xphy_wr_en2[9])
,.RST()
);


endmodule
