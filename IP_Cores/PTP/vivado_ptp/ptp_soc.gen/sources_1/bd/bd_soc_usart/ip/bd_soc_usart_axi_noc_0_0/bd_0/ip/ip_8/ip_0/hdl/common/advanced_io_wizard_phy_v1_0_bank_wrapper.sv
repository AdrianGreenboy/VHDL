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

`timescale 1 ps / 1 ps

module advanced_io_wizard_phy_v1_0_bank_wrapper #(

  //initializing parameters for xphy_nibbles/iob
  parameter [8:0] nibble = 9'b111111111,
  parameter [3:0] iob_type [53:0] = {4'b0001,4'b0010,4'b0011,4'b0101,4'b0000,4'b0000,4'b0101,4'b0110,4'b0000,4'b0000,4'b0110,4'b0111,4'b0000,4'b0000,4'b0111,4'b0000,4'b1110,4'b0000,4'b1101,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000,4'b0000},
  parameter INTF = "DDR4",	
  //xphy parameters	
  parameter [8*5:1] CASCADE_0 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] CASCADE_1 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] CASCADE_2 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] CASCADE_3 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] CASCADE_4 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] CASCADE_5 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] CONTINUOUS_DQS [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] CRSE_DLY_EN [8:0] = '{"FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [10:0] DELAY_VALUE_0 [8:0] = '{0,0,0,0,0,0,0,0,0},
  parameter [10:0] DELAY_VALUE_1 [8:0] = '{0,0,0,0,0,0,0,0,0},
  parameter [10:0] DELAY_VALUE_2 [8:0] = '{0,0,0,0,0,0,0,0,0},
  parameter [10:0] DELAY_VALUE_3 [8:0] = '{0,0,0,0,0,0,0,0,0},
  parameter [10:0] DELAY_VALUE_4 [8:0] = '{0,0,0,0,0,0,0,0,0},
  parameter [10:0] DELAY_VALUE_5 [8:0] = '{0,0,0,0,0,0,0,0,0},
  parameter [8*5:1] DIS_IDLY_VT_TRACK [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"}, 
  parameter [8*5:1] DIS_ODLY_VT_TRACK [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"}, 
  parameter [8*5:1] DIS_QDLY_VT_TRACK [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"}, 
  parameter [8*5:1] FAST_CK [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*13:1] DQS_MODE [8:0] = '{"DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK","DDR4_1TCK"},
  parameter [8*6:1] DQS_SRC [8:0] = '{ "EXTERN", "EXTERN", "EXTERN", "EXTERN", "EXTERN", "EXTERN", "EXTERN", "EXTERN", "EXTERN"},
  parameter [8*7:1] EN_CLK_TO_UPPER [8:0] = '{ "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE"},
  parameter [8*7:1] EN_CLK_TO_LOWER [8:0] = '{ "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE"},
  parameter [8*5:1] EN_DYN_DLY_MODE [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] EN_OTHER_NCLK [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] EN_OTHER_PCLK [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*6:1] FIFO_MODE_0 [8:0] = '{ "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC"},
  parameter [8*6:1] FIFO_MODE_1 [8:0] = '{ "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC"},
  parameter [8*6:1] FIFO_MODE_2 [8:0] = '{ "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC"},
  parameter [8*6:1] FIFO_MODE_3 [8:0] = '{ "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC"},
  parameter [8*6:1] FIFO_MODE_4 [8:0] = '{ "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC"},
  parameter [8*6:1] FIFO_MODE_5 [8:0] = '{ "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC", "SYNC"},
  parameter [8*8:1] IBUF_DIS_SRC_0 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] IBUF_DIS_SRC_1 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] IBUF_DIS_SRC_2 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] IBUF_DIS_SRC_3 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] IBUF_DIS_SRC_4 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] IBUF_DIS_SRC_5 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*5:1] INV_RXCLK [8:0]  = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] LP4_DQS [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] ODELAY_BYPASS_0 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] ODELAY_BYPASS_1 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] ODELAY_BYPASS_2 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] ODELAY_BYPASS_3 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] ODELAY_BYPASS_4 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] ODELAY_BYPASS_5 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*8:1] ODT_SRC_0 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] ODT_SRC_1 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] ODT_SRC_2 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] ODT_SRC_3 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] ODT_SRC_4 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [8*8:1] ODT_SRC_5 [8:0] = '{ "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL", "EXTERNAL"},
  parameter [63:0]  REFCLK_FREQUENCY [8:0] = '{200.0,200.0,200.0,200.0,200.0,200.0,200.0,200.0,200.0},
  parameter [8*8:1] RX_CLK_PHASE_N [8:0] = '{ "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0"},
  parameter [8*8:1] RX_CLK_PHASE_P [8:0] = '{ "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0", "SHIFT_0"},
  parameter [3:0]  RX_DATA_WIDTH 	  [8:0] = '{8,8,8,8,8,8,8,8,8},
  parameter [8*7:1] RX_GATING [8:0]= '{ "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE"},
  parameter [8*7:1] SELF_CALIBRATE [8:0] = '{ "ENABLE", "ENABLE", "ENABLE", "ENABLE", "ENABLE", "ENABLE", "ENABLE", "ENABLE", "ENABLE"},
  parameter [8*5:1] SERIAL_MODE [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*8:1] TBYTE_CTL_0 [8:0] = '{ "T", "T", "T", "T", "T", "T", "T", "T", "T"},
  parameter [8*8:1] TBYTE_CTL_1 [8:0] = '{ "T", "T", "T", "T", "T", "T", "T", "T", "T"},
  parameter [8*8:1] TBYTE_CTL_2 [8:0] = '{ "T", "T", "T", "T", "T", "T", "T", "T", "T"},
  parameter [8*8:1] TBYTE_CTL_3 [8:0] = '{ "T", "T", "T", "T", "T", "T", "T", "T", "T"},
  parameter [8*8:1] TBYTE_CTL_4 [8:0] = '{ "T", "T", "T", "T", "T", "T", "T", "T", "T"},
  parameter [8*8:1] TBYTE_CTL_5 [8:0] = '{ "T", "T", "T", "T", "T", "T", "T", "T", "T"},
  parameter [8*5:1] TXRX_LOOPBACK_0 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TXRX_LOOPBACK_1 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TXRX_LOOPBACK_2 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TXRX_LOOPBACK_3 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TXRX_LOOPBACK_4 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TXRX_LOOPBACK_5 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [3:0]  TX_DATA_WIDTH     [8:0] = '{8,8,8,8,8,8,8,8,8},
  parameter [8*7:1] TX_GATING [8:0] = '{ "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE", "DISABLE"},
  parameter [0:0] TX_INIT_0 [8:0] = '{1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  parameter [0:0] TX_INIT_1 [8:0] = '{1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  parameter [0:0] TX_INIT_2 [8:0] = '{1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  parameter [0:0] TX_INIT_3 [8:0] = '{1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  parameter [0:0] TX_INIT_4 [8:0] = '{1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  parameter [0:0] TX_INIT_5 [8:0] = '{1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  parameter [0:0] TX_INIT_TRI [8:0] = '{1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1},
  parameter [0:0] PRIME_VAL [8:0] = '{1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  parameter [8*5:1] TX_OUTPUT_PHASE_90_0 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TX_OUTPUT_PHASE_90_1 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TX_OUTPUT_PHASE_90_2 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TX_OUTPUT_PHASE_90_3 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TX_OUTPUT_PHASE_90_4 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TX_OUTPUT_PHASE_90_5 [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] TX_OUTPUT_PHASE_90_TRI [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*5:1] WRITE_LEVELING [8:0] = '{ "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE", "FALSE"},
  parameter [8*6:1] VREF_FABRIC [8:0] = '{"MEMCEL","MEMCEL","MEMCEL","MEMCEL","MEMCEL","MEMCEL","MEMCEL","MEMCEL","MEMCEL"},
  parameter [8*8:1] ISTANDARD [8:0] = '{"UNUSED","UNUSED","UNUSED","UNUSED","UNUSED","UNUSED","UNUSED","UNUSED","UNUSED"},
  parameter SIM_DEVICE = "VERSAL_AI_CORE_ES1",
  parameter VREF_NIB = "VREF_RIU"

)(
  
  //xphy ports
  `ifdef BLH_INTF
  	global_signal_interface glbl_intf,
  	global_sideband_interface glbl_sband_intf,
  `endif
  
  output [8:0] DLY_RDY,
  output [8:0] FIFO_EMPTY,
  output [8:0] FIFO_WR_CLK,
  output [8:0] GT_STATUS,
  output [8:0] PHY_RDY,
  output [431:0] Q,
  output [143:0] RIU_RD_DATA,
  output [8:0] RIU_RD_VALID,
  output [485:0] CNTVALUEOUT,

  input PLL_CLK,
  input [8:0] CTRL_CLK,
  input [431:0] D,
  input EN_VTC,
  input [8:0] FIFO_RDEN,
  input FIFO_RD_CLK,
  input [35:0] PHY_RDCS0,
  input [35:0] PHY_RDCS1,
  input [35:0] PHY_RDEN,
  input [35:0] PHY_WRCS0,
  input [35:0] PHY_WRCS1,
  input [35:0] PHY_WREN,
  input [71:0] RIU_ADDR,
  input [8:0] RIU_NIBBLE_SEL,
  input [143:0] RIU_WR_DATA,
  input [8:0] RIU_WR_EN,
  input RST,				//RST going to phy nibbles
  input [53:0] CE,
  input [485:0] CNTVALUEIN,
  input [53:0] RX_EN_VTC,
  input [53:0] INC,
  input [53:0] LD,
  input [53:0] RXTX_SEL,
  input RX_RST,
  input [53:0] T,
  input [53:0] TX_EN_VTC,
  input TX_RST,
  
  //io ports
  inout [53:0] IOB,
  inout [53:0] LPTX_I_RX_O,
  inout [53:0] LPTX_T_RX_DISABLE,
  input [53:0] HSRX_DISABLE	,
  input [53:0] IBUF_DISABLE_EXTERNAL,
  input [53:0] DCI_TERM_DISABLE_EXTERNAL,
  input [89:0] VREF	
);

  wire [71:0] Q0;
  wire [71:0] Q1;
  wire [71:0] Q2;
  wire [71:0] Q3;
  wire [71:0] Q4;
  wire [71:0] Q5;
  wire [71:0] D0;
  wire [71:0] D1;
  wire [71:0] D2;
  wire [71:0] D3;
  wire [71:0] D4;
  wire [71:0] D5;
wire [53:0] O0;
wire [53:0] T_OUT;
wire [53:0] DATAIN;
wire [53:0] DYN_DCI;
wire [53:0] IBUF_DISABLE;

wire [8:0] CLK_TO_UPPER;
wire [8:0] CLK_TO_LOWER;
wire [8:0] NCLK_NIBBLE_OUT;
wire [8:0] PCLK_NIBBLE_OUT;
wire [8:0] clk_ew_tmp;
wire [8:0] nclk_nibble_tmp;
wire [8:0] pclk_nibble_tmp;
wire [9:0] bisc_start_wire;
wire [9:0] bisc_stop_wire;
wire [53:0] nc;
wire [8:0] VREF_int;
wire [53:0] T_int;

assign  Q[7:0]     = Q0[7:0]    ;
assign  Q[15:8]    = Q1[7:0]    ;
assign  Q[23:16]   = Q2[7:0]    ;
assign  Q[31:24]   = Q3[7:0]    ;
assign  Q[39:32]   = Q4[7:0]    ;
assign  Q[47:40]   = Q5[7:0]    ;
assign  Q[55:48]   = Q0[15:8]   ;
assign  Q[63:56]   = Q1[15:8]   ;
assign  Q[71:64]   = Q2[15:8]   ;
assign  Q[79:72]   = Q3[15:8]   ;
assign  Q[87:80]   = Q4[15:8]   ;
assign  Q[95:88]   = Q5[15:8]   ;
assign  Q[103:96]  = Q0[23:16]  ;
assign  Q[111:104] = Q1[23:16]  ;
assign  Q[119:112] = Q2[23:16]  ;
assign  Q[127:120] = Q3[23:16]  ;
assign  Q[135:128] = Q4[23:16]  ;
assign  Q[143:136] = Q5[23:16]  ;
assign  Q[151:144] = Q0[31:24]  ;
assign  Q[159:152] = Q1[31:24]  ;
assign  Q[167:160] = Q2[31:24]  ;
assign  Q[175:168] = Q3[31:24]  ;
assign  Q[183:176] = Q4[31:24]  ;
assign  Q[191:184] = Q5[31:24]  ;
assign  Q[199:192] = Q0[39:32]  ;
assign  Q[207:200] = Q1[39:32]  ;
assign  Q[215:208] = Q2[39:32]  ;
assign  Q[223:216] = Q3[39:32]  ;
assign  Q[231:224] = Q4[39:32]  ;
assign  Q[239:232] = Q5[39:32]  ;
assign  Q[247:240] = Q0[47:40]  ;
assign  Q[255:248] = Q1[47:40]  ;
assign  Q[263:256] = Q2[47:40]  ;
assign  Q[271:264] = Q3[47:40]  ;
assign  Q[279:272] = Q4[47:40]  ;
assign  Q[287:280] = Q5[47:40]  ;
assign  Q[295:288] = Q0[55:48]  ;
assign  Q[303:296] = Q1[55:48]  ;
assign  Q[311:304] = Q2[55:48]  ;
assign  Q[319:312] = Q3[55:48]  ;
assign  Q[327:320] = Q4[55:48]  ;
assign  Q[335:328] = Q5[55:48]  ;
assign  Q[343:336] = Q0[63:56]  ;
assign  Q[351:344] = Q1[63:56]  ;
assign  Q[359:352] = Q2[63:56]  ;
assign  Q[367:360] = Q3[63:56]  ;
assign  Q[375:368] = Q4[63:56]  ;
assign  Q[383:376] = Q5[63:56]  ;
assign  Q[391:384] = Q0[71:64]  ;
assign  Q[399:392] = Q1[71:64]  ;
assign  Q[407:400] = Q2[71:64]  ;
assign  Q[415:408] = Q3[71:64]  ;
assign  Q[423:416] = Q4[71:64]  ;
assign  Q[431:424] = Q5[71:64]  ;


assign D0[7:0]   = D[7:0]    ;
assign D1[7:0]   = D[15:8]   ;
assign D2[7:0]   = D[23:16]  ;
assign D3[7:0]   = D[31:24]  ;
assign D4[7:0]   = D[39:32]  ;
assign D5[7:0]   = D[47:40]  ;
assign D0[15:8]  = D[55:48]  ;
assign D1[15:8]  = D[63:56]  ;
assign D2[15:8]  = D[71:64]  ;
assign D3[15:8]  = D[79:72]  ;
assign D4[15:8]  = D[87:80]  ;
assign D5[15:8]  = D[95:88]  ;
assign D0[23:16] = D[103:96] ;
assign D1[23:16] = D[111:104];
assign D2[23:16] = D[119:112];
assign D3[23:16] = D[127:120];
assign D4[23:16] = D[135:128];
assign D5[23:16] = D[143:136];
assign D0[31:24] = D[151:144];
assign D1[31:24] = D[159:152];
assign D2[31:24] = D[167:160];
assign D3[31:24] = D[175:168];
assign D4[31:24] = D[183:176];
assign D5[31:24] = D[191:184];
assign D0[39:32] = D[199:192];
assign D1[39:32] = D[207:200];
assign D2[39:32] = D[215:208];
assign D3[39:32] = D[223:216];
assign D4[39:32] = D[231:224];
assign D5[39:32] = D[239:232];
assign D0[47:40] = D[247:240];
assign D1[47:40] = D[255:248];
assign D2[47:40] = D[263:256];
assign D3[47:40] = D[271:264];
assign D4[47:40] = D[279:272];
assign D5[47:40] = D[287:280];
assign D0[55:48] = D[295:288];
assign D1[55:48] = D[303:296];
assign D2[55:48] = D[311:304];
assign D3[55:48] = D[319:312];
assign D4[55:48] = D[327:320];
assign D5[55:48] = D[335:328];
assign D0[63:56] = D[343:336];
assign D1[63:56] = D[351:344];
assign D2[63:56] = D[359:352];
assign D3[63:56] = D[367:360];
assign D4[63:56] = D[375:368];
assign D5[63:56] = D[383:376];
assign D0[71:64] = D[391:384];
assign D1[71:64] = D[399:392];
assign D2[71:64] = D[407:400];
assign D3[71:64] = D[415:408];
assign D4[71:64] = D[423:416];
assign D5[71:64] = D[431:424];

assign bisc_start_wire[0] = bisc_stop_wire[0];
assign bisc_stop_wire[9] = 1'b1;

genvar i;
generate for (i=0; i<=8; i=i+1) 
   begin: NIBBLE
   
   if(i<4)
   begin
   	assign clk_ew_tmp[i] = CLK_TO_LOWER[i+2];
   end
   else if(i==8)
   begin
   	assign clk_ew_tmp[i]= CLK_TO_LOWER[i-2];
   end
   else
   begin
   	assign clk_ew_tmp[i]= CLK_TO_UPPER[i-2];
   end
   
   if(i==8)
   begin
   	assign nclk_nibble_tmp[i]= 1'b0;
   	assign pclk_nibble_tmp[i]= 1'b0;
   end
   else if(i%2)
   begin
   	assign nclk_nibble_tmp[i]= NCLK_NIBBLE_OUT[i-1];
   	assign pclk_nibble_tmp[i]= PCLK_NIBBLE_OUT[i-1];
   end
   else
   begin
   	assign nclk_nibble_tmp[i]= NCLK_NIBBLE_OUT[i+1];
   	assign pclk_nibble_tmp[i]= PCLK_NIBBLE_OUT[i+1];
   end
   
   assign T_int[(i*6)+5] = (iob_type[(i*6)+5]!=4'b0000)? T[(i*6)+5] : nc[(i*6)+5] ;
   assign T_int[(i*6)+4] = (iob_type[(i*6)+4]!=4'b0000)? T[(i*6)+4] : nc[(i*6)+4] ;
   assign T_int[(i*6)+3] = (iob_type[(i*6)+3]!=4'b0000)? T[(i*6)+3] : nc[(i*6)+3] ;
   assign T_int[(i*6)+2] = (iob_type[(i*6)+2]!=4'b0000)? T[(i*6)+2] : nc[(i*6)+2] ;
   assign T_int[(i*6)+1] = (iob_type[(i*6)+1]!=4'b0000)? T[(i*6)+1] : nc[(i*6)+1] ;
   assign T_int[(i*6)+0] = (iob_type[(i*6)+0]!=4'b0000)? T[(i*6)+0] : nc[(i*6)+0] ;
//****************intantiating 9 XPHY***************************
	if(nibble[i]==1)
	begin: UNISIM
		`ifdef XPHY_BLH
			B_XPHY 
		`else
			XPHY
		`endif	
			#(
	 		.CASCADE_0                        ((CASCADE_0[i]=="FALSE")? "FALSE" : "TRUE"),
			.CASCADE_1                        ((CASCADE_1[i]=="FALSE")? "FALSE" : "TRUE"),
			.CASCADE_2                        ((CASCADE_2[i]=="FALSE")? "FALSE" : "TRUE"),
			.CASCADE_3                        ((CASCADE_3[i]=="FALSE")? "FALSE" : "TRUE"),
			.CASCADE_4                        ((CASCADE_4[i]=="FALSE")? "FALSE" : "TRUE"),
			.CASCADE_5                        ((CASCADE_5[i]=="FALSE")? "FALSE" : "TRUE"),
			.CONTINUOUS_DQS		          ((CONTINUOUS_DQS[i]=="FALSE")? "FALSE" : "TRUE"),
			.CRSE_DLY_EN                      ((CRSE_DLY_EN[i]=="FALSE")? "FALSE" : "TRUE"),
			.DELAY_VALUE_0                    ((DELAY_VALUE_0[i])),
			.DELAY_VALUE_1                    ((DELAY_VALUE_1[i])),
			.DELAY_VALUE_2                    ((DELAY_VALUE_2[i])),
			.DELAY_VALUE_3                    ((DELAY_VALUE_3[i])),
			.DELAY_VALUE_4                    ((DELAY_VALUE_4[i])),
			.DELAY_VALUE_5                    ((DELAY_VALUE_5[i])),
			.DIS_IDLY_VT_TRACK                ((DIS_IDLY_VT_TRACK[i]=="FALSE")? "FALSE" : "TRUE"),
			.DIS_ODLY_VT_TRACK                ((DIS_ODLY_VT_TRACK[i]=="FALSE")? "FALSE" : "TRUE"),
			.DIS_QDLY_VT_TRACK                ((DIS_QDLY_VT_TRACK[i]=="FALSE")? "FALSE" : "TRUE"),
			.DQS_MODE                         ((DQS_MODE[i]=="DDR4_1TCK")?"DDR4_1TCK":(DQS_MODE[i]=="DDR4_2TCK")?"DDR4_2TCK":(DQS_MODE[i]=="LPDDR4_TOGGLE")?"LPDDR4_TOGGLE":(DQS_MODE[i]=="LPDDR4")?"LPDDR4":"DDR3"),
			.DQS_SRC                          ((DQS_SRC[i]=="LOCAL")? "LOCAL" : "EXTERN"),
			.EN_CLK_TO_UPPER                  ((EN_CLK_TO_UPPER[i]=="DISABLE")? "DISABLE" : "ENABLE"),
			.EN_CLK_TO_LOWER                  ((EN_CLK_TO_LOWER[i]=="DISABLE")? "DISABLE" : "ENABLE"),
			.EN_DYN_DLY_MODE                  ((EN_DYN_DLY_MODE[i]=="FALSE")? "FALSE" : "TRUE"),
			.EN_OTHER_NCLK                    ((EN_OTHER_NCLK[i]=="FALSE")? "FALSE" : "TRUE"),
			.EN_OTHER_PCLK                    ((EN_OTHER_PCLK[i]=="FALSE")? "FALSE" : "TRUE"),
			.FAST_CK 			  ((FAST_CK[i]=="FALSE")? "FALSE" : "TRUE"),	
			.FIFO_MODE_0                      ((FIFO_MODE_0[i]=="ASYNC")? "ASYNC" : (FIFO_MODE_0[i]=="SYNC")? "SYNC" : "BYPASS"),
			.FIFO_MODE_1                      ((FIFO_MODE_1[i]=="ASYNC")? "ASYNC" : (FIFO_MODE_1[i]=="SYNC")? "SYNC" : "BYPASS"),
			.FIFO_MODE_2                      ((FIFO_MODE_2[i]=="ASYNC")? "ASYNC" : (FIFO_MODE_2[i]=="SYNC")? "SYNC" : "BYPASS"),
			.FIFO_MODE_3                      ((FIFO_MODE_3[i]=="ASYNC")? "ASYNC" : (FIFO_MODE_3[i]=="SYNC")? "SYNC" : "BYPASS"),
			.FIFO_MODE_4                      ((FIFO_MODE_4[i]=="ASYNC")? "ASYNC" : (FIFO_MODE_4[i]=="SYNC")? "SYNC" : "BYPASS"),
			.FIFO_MODE_5                      ((FIFO_MODE_5[i]=="ASYNC")? "ASYNC" : (FIFO_MODE_5[i]=="SYNC")? "SYNC" : "BYPASS"),
			.IBUF_DIS_SRC_0                   ((IBUF_DIS_SRC_0[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.IBUF_DIS_SRC_1                   ((IBUF_DIS_SRC_1[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.IBUF_DIS_SRC_2                   ((IBUF_DIS_SRC_2[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.IBUF_DIS_SRC_3                   ((IBUF_DIS_SRC_3[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.IBUF_DIS_SRC_4                   ((IBUF_DIS_SRC_4[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.IBUF_DIS_SRC_5                   ((IBUF_DIS_SRC_5[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.INV_RXCLK                        ((INV_RXCLK[i]=="FALSE")? "FALSE" : "TRUE"),
			.LP4_DQS                          ((LP4_DQS[i] =="FALSE")? "FALSE" : "TRUE"),
			.ODELAY_BYPASS_0                  ((ODELAY_BYPASS_0[i]=="FALSE")? "FALSE" : "TRUE"),
			.ODELAY_BYPASS_1                  ((ODELAY_BYPASS_1[i]=="FALSE")? "FALSE" : "TRUE"),
			.ODELAY_BYPASS_2                  ((ODELAY_BYPASS_2[i]=="FALSE")? "FALSE" : "TRUE"),
			.ODELAY_BYPASS_3                  ((ODELAY_BYPASS_3[i]=="FALSE")? "FALSE" : "TRUE"),
			.ODELAY_BYPASS_4                  ((ODELAY_BYPASS_4[i]=="FALSE")? "FALSE" : "TRUE"),
			.ODELAY_BYPASS_5                  ((ODELAY_BYPASS_5[i]=="FALSE")? "FALSE" : "TRUE"),
			.ODT_SRC_0                        ((ODT_SRC_0[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.ODT_SRC_1                        ((ODT_SRC_1[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.ODT_SRC_2                        ((ODT_SRC_2[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.ODT_SRC_3                        ((ODT_SRC_3[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.ODT_SRC_4                        ((ODT_SRC_4[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.ODT_SRC_5                        ((ODT_SRC_5[i]=="EXTERNAL")? "EXTERNAL" : "INTERNAL"),
			.PRIME_VAL			  ((PRIME_VAL[i])),
			.REFCLK_FREQUENCY                 ((REFCLK_FREQUENCY[i])),
			.RX_CLK_PHASE_N                   ((RX_CLK_PHASE_N[i] =="SHIFT_0")? "SHIFT_0" : "SHIFT_90"),
			.RX_CLK_PHASE_P                   ((RX_CLK_PHASE_P[i] =="SHIFT_0")? "SHIFT_0" : "SHIFT_90"),
			.RX_DATA_WIDTH                    ((RX_DATA_WIDTH[i])),
			.RX_GATING                        ((RX_GATING[i]  =="DISABLE")? "DISABLE" : "ENABLE"),
			.SELF_CALIBRATE                   ((SELF_CALIBRATE[i] =="DISABLE")? "DISABLE" : "ENABLE"),
			.SERIAL_MODE                      ((SERIAL_MODE[i]=="FALSE")? "FALSE" : "TRUE"),
			.TBYTE_CTL_0                      ((TBYTE_CTL_0[i]=="T")? "T" : "PHY_WREN"),
			.TBYTE_CTL_1                      ((TBYTE_CTL_1[i]=="T")? "T" : "PHY_WREN"),
			.TBYTE_CTL_2                      ((TBYTE_CTL_2[i]=="T")? "T" : "PHY_WREN"),
			.TBYTE_CTL_3                      ((TBYTE_CTL_3[i]=="T")? "T" : "PHY_WREN"),
			.TBYTE_CTL_4                      ((TBYTE_CTL_4[i]=="T")? "T" : "PHY_WREN"),
			.TBYTE_CTL_5                      ((TBYTE_CTL_5[i]=="T")? "T" : "PHY_WREN"),
			.TXRX_LOOPBACK_0                  ((TXRX_LOOPBACK_0[i]=="FALSE")? "FALSE" : "TRUE"),
			.TXRX_LOOPBACK_1                  ((TXRX_LOOPBACK_1[i]=="FALSE")? "FALSE" : "TRUE"),
			.TXRX_LOOPBACK_2                  ((TXRX_LOOPBACK_2[i]=="FALSE")? "FALSE" : "TRUE"),
			.TXRX_LOOPBACK_3                  ((TXRX_LOOPBACK_3[i]=="FALSE")? "FALSE" : "TRUE"),
			.TXRX_LOOPBACK_4                  ((TXRX_LOOPBACK_4[i]=="FALSE")? "FALSE" : "TRUE"),
			.TXRX_LOOPBACK_5                  ((TXRX_LOOPBACK_5[i]=="FALSE")? "FALSE" : "TRUE"),
			.TX_DATA_WIDTH                    ((TX_DATA_WIDTH[i])),
			.TX_GATING                        ((TX_GATING[i]=="DISABLE")? "DISABLE" : "ENABLE"),
			.TX_INIT_0                        ((TX_INIT_0[i])),
			.TX_INIT_1                        ((TX_INIT_1[i])),
			.TX_INIT_2                        ((TX_INIT_2[i])),
			.TX_INIT_3                        ((TX_INIT_3[i])),
			.TX_INIT_4                        ((TX_INIT_4[i])),
			.TX_INIT_5                        ((TX_INIT_5[i])),
			.TX_INIT_TRI                      ((TX_INIT_TRI[i])),
			.TX_OUTPUT_PHASE_90_0             ((TX_OUTPUT_PHASE_90_0[i] =="FALSE")? "FALSE" : "TRUE"),
			.TX_OUTPUT_PHASE_90_1             ((TX_OUTPUT_PHASE_90_1[i] =="FALSE")? "FALSE" : "TRUE"),
			.TX_OUTPUT_PHASE_90_2             ((TX_OUTPUT_PHASE_90_2[i] =="FALSE")? "FALSE" : "TRUE"),
			.TX_OUTPUT_PHASE_90_3             ((TX_OUTPUT_PHASE_90_3[i] =="FALSE")? "FALSE" : "TRUE"),
			.TX_OUTPUT_PHASE_90_4             ((TX_OUTPUT_PHASE_90_4[i] =="FALSE")? "FALSE" : "TRUE"),
			.TX_OUTPUT_PHASE_90_5             ((TX_OUTPUT_PHASE_90_5[i] =="FALSE")? "FALSE" : "TRUE"),
			.TX_OUTPUT_PHASE_90_TRI           ((TX_OUTPUT_PHASE_90_TRI[i]=="FALSE")? "FALSE" : "TRUE"),
			.WRITE_LEVELING                   ((WRITE_LEVELING[i] =="FALSE")? "FALSE" : "TRUE")      
   		     ) I_XPHY (
`ifdef BLH_INTF
   			.glbl_intf ( glbl_intf ),
   			.glbl_sband_intf ( glbl_sband_intf ),
`endif
			.CLK_TO_UPPER                	(CLK_TO_UPPER[i]),		
			.CLK_TO_LOWER                	(CLK_TO_LOWER[i]),		
			.DLY_RDY                        (DLY_RDY[i]),	
			.DYN_DCI                        (DYN_DCI[(i+1)*6-1:i*6]),			
			.FIFO_EMPTY                  	(FIFO_EMPTY[i]),		
			.FIFO_WR_CLK                	(FIFO_WR_CLK[i]),		
			.GT_STATUS                   	(GT_STATUS[i]),		
			.IBUF_DISABLE              	    (IBUF_DISABLE[(i+1)*6-1:i*6]),		
			.NCLK_NIBBLE_OUT        	    (NCLK_NIBBLE_OUT[i]),	
			.O0                             (O0[(i+1)*6-1:i*6]),				  
			.PCLK_NIBBLE_OUT        	    (PCLK_NIBBLE_OUT[i]),	
			.PHY_RDY                        (PHY_RDY[i]),			
			.Q0                             ({Q0[i*8+6],Q0[i*8+4],Q0[i*8+2],Q0[i*8+0],Q0[i*8+7],Q0[i*8+5],Q0[i*8+3],Q0[i*8+1]}),				 
			.Q1                             ({Q1[i*8+6],Q1[i*8+4],Q1[i*8+2],Q1[i*8+0],Q1[i*8+7],Q1[i*8+5],Q1[i*8+3],Q1[i*8+1]}),				 
			.Q2                             ({Q2[i*8+6],Q2[i*8+4],Q2[i*8+2],Q2[i*8+0],Q2[i*8+7],Q2[i*8+5],Q2[i*8+3],Q2[i*8+1]}),				 
			.Q3                             ({Q3[i*8+6],Q3[i*8+4],Q3[i*8+2],Q3[i*8+0],Q3[i*8+7],Q3[i*8+5],Q3[i*8+3],Q3[i*8+1]}),				 
			.Q4                             ({Q4[i*8+6],Q4[i*8+4],Q4[i*8+2],Q4[i*8+0],Q4[i*8+7],Q4[i*8+5],Q4[i*8+3],Q4[i*8+1]}),				 
			.Q5                             ({Q5[i*8+6],Q5[i*8+4],Q5[i*8+2],Q5[i*8+0],Q5[i*8+7],Q5[i*8+5],Q5[i*8+3],Q5[i*8+1]}),				 
			.RIU_RD_DATA                	(RIU_RD_DATA[(i+1)*16-1:i*16]),		
			.RIU_RD_VALID              	    (RIU_RD_VALID[i]),	
			.CNTVALUEOUT          	        ( ),	
			.T_OUT                          (T_OUT[(i+1)*6-1:i*6]),			
			.CLK_FROM_OTHER_XPHY            (clk_ew_tmp[i]),		//inter byte clocking
			.CTRL_CLK                      	(CTRL_CLK[i]),		
			.D0                             (D0[(i+1)*8-1:i*8]),				 
			.D1                             (D1[(i+1)*8-1:i*8]),				 
			.D2                             (D2[(i+1)*8-1:i*8]),				 
			.D3                             (D3[(i+1)*8-1:i*8]),				 
			.D4                             (D4[(i+1)*8-1:i*8]),				 
			.D5                             (D5[(i+1)*8-1:i*8]),				 
			.DATAIN                         (DATAIN[(i+1)*6-1:i*6]),
			.EN_VTC                         (EN_VTC),			
			.FIFO_RDEN                    	(FIFO_RDEN[i]),		
			.FIFO_RD_CLK                	(FIFO_RD_CLK),
			.NCLK_NIBBLE_IN          	    (nclk_nibble_tmp[i]), //inter nibble clocking	
			.PCLK_NIBBLE_IN          	    (pclk_nibble_tmp[i]), //inter nibble clocking
			.PHY_RDCS0                    	(PHY_RDCS0[(i+1)*4-1:i*4]),		
			.PHY_RDCS1                    	(PHY_RDCS1[(i+1)*4-1:i*4]),		
			.PHY_RDEN                      	(PHY_RDEN[(i+1)*4-1:i*4]),		
			.PHY_WRCS0                    	(PHY_WRCS0[(i+1)*4-1:i*4]),		
			.PHY_WRCS1                    	(PHY_WRCS1[(i+1)*4-1:i*4]),		
			.PHY_WREN                      	(PHY_WREN[(i+1)*4-1:i*4]),		
			.PLL_CLK                      	(PLL_CLK),	
			.RIU_ADDR                      	(RIU_ADDR[(i+1)*8-1:i*8]),		
			.RIU_NIBBLE_SEL          	    (RIU_NIBBLE_SEL[i]),	
			.RIU_WR_DATA                	(RIU_WR_DATA[(i+1)*16-1:i*16]),		
			.RIU_WR_EN                    	(RIU_WR_EN[i]),		
			.RST                            (RST),				
			.CE                             ( ),			
			.CNTVALUEIN            	        ( ),	
			.RX_EN_VTC                    	(RX_EN_VTC[(i+1)*6-1:i*6]),		
			.INC                            ( ),			
			.LD                             ( ),	
			.RXTX_SEL	                    (RXTX_SEL[(i+1)*6-1:i*6]),
			.RX_RST                         ( ),			
			.T                              (T[(i+1)*6-1:i*6]),		
			.TX_EN_VTC                    	(TX_EN_VTC[(i+1)*6-1:i*6]),	
			.TX_RST         	            ({6{TX_RST}})						      
		    );
		// synthesis translate_off
		initial
		begin
		    `ifdef XPHY_BLH
			force NIBBLE[i].UNISIM.I_XPHY.SHIP._phy2phy_bisc_start_in = bisc_start_wire[i];
			force bisc_start_wire[i+1] = NIBBLE[i].UNISIM.I_XPHY.SHIP._phy2phy_bisc_start_out;
			force NIBBLE[i].UNISIM.I_XPHY.SHIP._phy2phy_bisc_stop_in = bisc_stop_wire[i+1];
			force bisc_stop_wire[i] = NIBBLE[i].UNISIM.I_XPHY.SHIP._phy2phy_bisc_stop_out;
			`else
			force NIBBLE[i].UNISIM.I_XPHY.SIP_XPHY_INST.PHY2PHY_BISC_START_IN = bisc_start_wire[i];
			force bisc_start_wire[i+1] = NIBBLE[i].UNISIM.I_XPHY.SIP_XPHY_INST.PHY2PHY_BISC_START_OUT;
			force NIBBLE[i].UNISIM.I_XPHY.SIP_XPHY_INST.PHY2PHY_BISC_STOP_IN = bisc_stop_wire[i+1];
			force bisc_stop_wire[i] = NIBBLE[i].UNISIM.I_XPHY.SIP_XPHY_INST.PHY2PHY_BISC_STOP_OUT;
			`endif
		end 
		// synthesis translate_on
	end 
	else
	begin
		assign CLK_TO_UPPER[i]= 1'b1;       //if nibble not instantiated, taking care of inter nibble and inter byte clocking
		assign CLK_TO_LOWER[i]= 1'b1;
		assign NCLK_NIBBLE_OUT[i]= 1'b0;
		assign PCLK_NIBBLE_OUT[i]= 1'b0;
		assign DLY_RDY[i] = 1'b1;
		assign PHY_RDY[i] = 1'b1;
		assign bisc_stop_wire[i]= bisc_stop_wire[i+1];
		assign bisc_start_wire[i+1]= bisc_start_wire[i];
		assign RIU_RD_VALID[i] = 1'b1;
	end
   end
endgenerate //NIBBLE

//MIG only
genvar j;
generate for (j=0; j<=53; j=j+1)
   begin: IOB_SINGLE
        if(iob_type[j]== 4'b0010)
        begin
                IBUF I_IBUF(
                .O      (DATAIN[j]),
                .I      (IOB[j])
                );
        end
        else if(iob_type[j]== 4'b0001)
        begin
                OBUF I_OBUF(
                .O      (IOB[j]),
                .I      (O0[j])
                );
        end
  end
endgenerate

generate for (j=0; j<=53; j=j+6) 
   begin: IOB_SINGLE_0
      /*  if(iob_type[j]== 4'b0010)
		begin
			IOBUFE3 I_IBUF(
			.O	(DATAIN[j]),
			.I	(),
			.T (1'b1),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_0[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_0[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
		end
	else if(iob_type[j]== 4'b0001)
	begin
		IOBUFE3 I_OBUF(
			.O	(),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_0[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_0[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
	end
	else */if(iob_type[j]== 4'b0011)
	begin
		IOBUF I_IOBUF(
			.O	(DATAIN[j]),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j])
			);
	end
  end
endgenerate //IOB_NIBBLE
generate for (j=1; j<=53; j=j+6) 
   begin: IOB_SINGLE_1
     /*   if(iob_type[j]== 4'b0010)
		begin
			IOBUFE3 I_IBUF(
			.O	(DATAIN[j]),
			.I	(),
			.T (1'b1),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_1[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_1[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
		end
	else if(iob_type[j]== 4'b0001)
	begin
		IOBUFE3 I_OBUF(
			.O	(),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_1[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_1[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
	end
	else */if(iob_type[j]== 4'b0011)
	begin
		IOBUF I_IOBUF(
			.O	(DATAIN[j]),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j])
			);
	end
  end
endgenerate //IOB_NIBBLE
generate for (j=2; j<=53; j=j+6) 
   begin: IOB_SINGLE_2
      /*  if(iob_type[j]== 4'b0010)
		begin
			IOBUFE3 I_IBUF(
			.O	(DATAIN[j]),
			.I	(),
			.T (1'b1),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_2[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_2[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
		end
	else if(iob_type[j]== 4'b0001)
	begin
		IOBUFE3 I_OBUF(
			.O	(),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_2[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_2[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
	end
	else*/ if(iob_type[j]== 4'b0011)
	begin
		IOBUF I_IOBUF(
			.O	(DATAIN[j]),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j])
			);
	end
  end
endgenerate //IOB_NIBBLE
generate for (j=3; j<=53; j=j+6) 
   begin: IOB_SINGLE_3
       /* if(iob_type[j]== 4'b0010)
		begin
			IOBUFE3 I_IBUF(
			.O	(DATAIN[j]),
			.I	(),
			.T (1'b1),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_3[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_3[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
		end
	else if(iob_type[j]== 4'b0001)
	begin
		IOBUFE3 I_OBUF(
			.O	(),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_3[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_3[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
	end
	else */if(iob_type[j]== 4'b0011)
	begin
		IOBUF I_IOBUF(
			.O	(DATAIN[j]),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j])
			);
	end
  end
endgenerate //IOB_NIBBLE
generate for (j=4; j<=53; j=j+6) 
   begin: IOB_SINGLE_4
      /*  if(iob_type[j]== 4'b0010)
		begin
			IOBUFE3 I_IBUF(
			.O	(DATAIN[j]),
			.I	(),
			.T (1'b1),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_4[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_4[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
		end
	else if(iob_type[j]== 4'b0001)
	begin
		IOBUFE3 I_OBUF(
			.O	(),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_4[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_4[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
	end
	else */if(iob_type[j]== 4'b0011)
	begin
		IOBUF I_IOBUF(
			.O	(DATAIN[j]),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j])
			);
	end
  end
endgenerate //IOB_NIBBLE
generate for (j=5; j<=53; j=j+6) 
   begin: IOB_SINGLE_5
      /*  if(iob_type[j]== 4'b0010)
		begin
			IOBUFE3 I_IBUF(
			.O	(DATAIN[j]),
			.I	(),
			.T (1'b1),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_5[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_5[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
		end
	else if(iob_type[j]== 4'b0001)
	begin
		IOBUFE3 I_OBUF(
			.O	(),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j]),
			.OSC(1'b0),
			.OSC_EN(1'b0),
			.VREF(VREF_int[j/6]),
			.IBUFDISABLE((IBUF_DIS_SRC_5[j/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[j] : IBUF_DISABLE[j]),
			.DCITERMDISABLE((ODT_SRC_5[j/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[j] : DYN_DCI[j])
			);
	end
	else */if(iob_type[j]== 4'b0011)
	begin
		IOBUF I_IOBUF(
			.O	(DATAIN[j]),
			.I	(O0[j]),
			.T (T_OUT[j]),
			.IO (IOB[j])
			);
	end
  end
endgenerate //IOB_NIBBLE
 
//This loop for the Differential IO Side
genvar k;
generate for( k = 0; k <=52; k=k+6) 
 begin : IOB_DIFF_EVEN_0
        if(iob_type[k]==4'b0111)
	begin
          if(INTF == "LPDDR4")  
          begin  
		          IOBUFDS_COMP #( .USE_IBUFDISABLE("FALSE")) I_IOBUFDS (
		          .I(O0[k+1]),
		          .O(DATAIN[k]),
		          .T(T_OUT[k+1]),
		          .IO(IOB[k]),
		          .IOB(IOB[k+1]),
			        .IBUFDISABLE(1'b1),
		          .DCITERMDISABLE((ODT_SRC_0[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		          );
          end
	        else 
          begin
		          IOBUFDS I_IOBUFDS(
		          .I(O0[k]),
		          .O(DATAIN[k]),
		          .T(T_OUT[k]),
		          .IO(IOB[k]),
		          .IOB(IOB[k+1])
		          );
          end
	end
	else if(iob_type[k]== 4'b0110)
	begin
		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_IBUFDS(
		.I(),
		.O(DATAIN[k]),
		.OB(DATAIN[k+1]),
		.TM(1'b1),
		.TS(1'b1),
		.IO(IOB[k]),
		.IOB(IOB[k+1]),
    .IBUFDISABLE((IBUF_DIS_SRC_0[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		.DCITERMDISABLE((ODT_SRC_0[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		);
	end
	else if(iob_type[k]== 4'b0101)
//	begin
//		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_OBUFDS(
//		.I(O0[k]),
//		.O(),
//		.OB(),
//		.TM(T_OUT[k]),
//		.TS(T_OUT[k]),
//		.IO(IOB[k]),
//		.IOB(IOB[k+1]),
//    .IBUFDISABLE((IBUF_DIS_SRC_0[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
//		.DCITERMDISABLE((ODT_SRC_0[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
//		);
//	end
	begin
		OBUFDS I_OBUFDS(
		.I  (O0[k]),
                .O  (IOB[k]), 
                .OB (IOB[k+1]));
	end
	else if(iob_type[k]== 4'b1101)
	begin
		OBUFDS_DPHY I_OBUFDS_DPHY(
		.O  (IOB[k]), 
                .OB (IOB[k+1]),
	        .HSTX_I(O0[k]),
                .HSTX_T(T_OUT[k]),
                .LPTX_I_N(LPTX_I_RX_O[k+1]),
                .LPTX_I_P(LPTX_I_RX_O[k]),
                .LPTX_T(LPTX_T_RX_DISABLE[k]));
	end
	else if(iob_type[k]== 4'b1110)
	begin
		IBUFDS_DPHY #(
          .SIM_DEVICE (SIM_DEVICE)
		)
		I_IBUFDS_DPHY(
		.HSRX_O(DATAIN[k]),
                .LPRX_O_N(LPTX_I_RX_O[k+1]),
                .LPRX_O_P(LPTX_I_RX_O[k]),
                .HSRX_DISABLE(HSRX_DISABLE[k]),
                .I(IOB[k]),
                .IB(IOB[k+1]),
                .LPRX_DISABLE(LPTX_T_RX_DISABLE[k]));
	end
  end
endgenerate


generate for( k = 1; k <=53; k=k+6) 
 begin : IOB_DIFF_ODD_1
        if(iob_type[k]==4'b0111)
	begin
            if(INTF == "LPDDR4")  
            begin
		          IOBUFDS_COMP I_IOBUFDS(
		          .I(O0[k-1]),
		          .O(DATAIN[k]),
		          .T(T_OUT[k-1]),
		          .IO(IOB[k]),
		          .IOB(IOB[k-1]),
              .IBUFDISABLE((IBUF_DIS_SRC_1[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		          .DCITERMDISABLE((ODT_SRC_1[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		          );
            end
            else 
            begin
		          IOBUFDS I_IOBUFDS(
		          .I(O0[k]),
		          .O(DATAIN[k]),
		          .T(T_OUT[k]),
		          .IO(IOB[k]),
		          .IOB(IOB[k-1])
		          );            
            end
	end
	else if(iob_type[k]== 4'b0110)
	begin
		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_IBUFDS(
		.I(),
		.O(DATAIN[k]),
		.OB(DATAIN[k-1]),
		.TM(1'b1),
		.TS(1'b1),
		.IO(IOB[k]),
		.IOB(IOB[k-1]),
    .IBUFDISABLE((IBUF_DIS_SRC_1[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		.DCITERMDISABLE((ODT_SRC_1[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		);
	end
	else if(iob_type[k]== 4'b0101)
//	begin
//		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_OBUFDS(
//		.I(O0[k]),
//		.O(),
//		.OB(),
//		.TM(T_OUT[k]),
//		.TS(T_OUT[k]),
//		.IO(IOB[k]),
//		.IOB(IOB[k-1]),
//    .IBUFDISABLE((IBUF_DIS_SRC_1[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
//		.DCITERMDISABLE((ODT_SRC_1[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
//		);
//	end
	begin
		OBUFDS I_OBUFDS(
		.I  (O0[k]),
                .O  (IOB[k]), 
                .OB (IOB[k-1]));
	end
	else if(iob_type[k]== 4'b1101)
	begin
		OBUFDS_DPHY I_OBUFDS_DPHY(
		.O  (IOB[k]), 
                .OB (IOB[k-1]),
	        .HSTX_I(O0[k]),
                .HSTX_T(T_OUT[k]),
                .LPTX_I_N(LPTX_I_RX_O[k-1]),
                .LPTX_I_P(LPTX_I_RX_O[k]),
                .LPTX_T(LPTX_T_RX_DISABLE[k]));
	end
	else if(iob_type[k]== 4'b1110)
	begin
		IBUFDS_DPHY #(
          .SIM_DEVICE (SIM_DEVICE)
		) I_IBUFDS_DPHY(
		.HSRX_O(DATAIN[k]),
                .LPRX_O_N(LPTX_I_RX_O[k-1]),
                .LPRX_O_P(LPTX_I_RX_O[k]),
                .HSRX_DISABLE(HSRX_DISABLE[k]),
                .I(IOB[k]),
                .IB(IOB[k-1]),
                .LPRX_DISABLE(LPTX_T_RX_DISABLE[k]));
	end
  end
endgenerate

generate for( k = 2; k <=52; k=k+6) 
 begin : IOB_DIFF_EVEN_2
        if(iob_type[k]==4'b0111)
	begin
          if(INTF == "LPDDR4")  
          begin
		        IOBUFDS_COMP I_IOBUFDS(
		        .I(O0[k+1]),
		        .O(DATAIN[k]),
		        .T(T_OUT[k+1]),
		        .IO(IOB[k]),
		        .IOB(IOB[k+1]),
           .IBUFDISABLE((IBUF_DIS_SRC_2[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		        .DCITERMDISABLE((ODT_SRC_2[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		        );
          end 
          else 
          begin
		        IOBUFDS I_IOBUFDS(
		        .I(O0[k]),
		        .O(DATAIN[k]),
		        .T(T_OUT[k]),
		        .IO(IOB[k]),
		        .IOB(IOB[k+1])
		        );          
          end
	end
	else if(iob_type[k]== 4'b0110)
	begin
		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_IBUFDS(
		.I(),
		.O(DATAIN[k]),
		.OB(DATAIN[k+1]),
		.TM(1'b1),
		.TS(1'b1),
		.IO(IOB[k]),
		.IOB(IOB[k+1]),
    .IBUFDISABLE((IBUF_DIS_SRC_2[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		.DCITERMDISABLE((ODT_SRC_2[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		);
	end
	else if(iob_type[k]== 4'b0101)
	begin
//		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_OBUFDS(
//		.I(O0[k]),
//		.O(),
//		.OB(),
//		.TM(T_OUT[k]),
//		.TS(T_OUT[k]),
//		.IO(IOB[k]),
//		.IOB(IOB[k+1]),
//    .IBUFDISABLE((IBUF_DIS_SRC_2[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
//		.DCITERMDISABLE((ODT_SRC_2[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
//		);
		OBUFDS I_OBUFDS(
		.I  (O0[k]),
                .O  (IOB[k]), 
                .OB (IOB[k+1]));
	end
	else if(iob_type[k]== 4'b1101)
	begin
		OBUFDS_DPHY I_OBUFDS_DPHY(
		.O  (IOB[k]), 
                .OB (IOB[k+1]),
	        .HSTX_I(O0[k]),
                .HSTX_T(T_OUT[k]),
                .LPTX_I_N(LPTX_I_RX_O[k+1]),
                .LPTX_I_P(LPTX_I_RX_O[k]),
                .LPTX_T(LPTX_T_RX_DISABLE[k]));
	end
	else if(iob_type[k]== 4'b1110)
	begin
		IBUFDS_DPHY #(
          .SIM_DEVICE (SIM_DEVICE)
		)
		I_IBUFDS_DPHY(
		.HSRX_O(DATAIN[k]),
                .LPRX_O_N(LPTX_I_RX_O[k+1]),
                .LPRX_O_P(LPTX_I_RX_O[k]),
                .HSRX_DISABLE(HSRX_DISABLE[k]),
                .I(IOB[k]),
                .IB(IOB[k+1]),
                .LPRX_DISABLE(LPTX_T_RX_DISABLE[k]));
	end
  end
endgenerate


generate for( k = 3; k <=53; k=k+6) 
 begin : IOB_DIFF_ODD_3
        if(iob_type[k]==4'b0111)
	begin
          if(INTF == "LPDDR4") 
          begin 
		        IOBUFDS_COMP I_IOBUFDS(
		        .I(O0[k-1]),
		        .O(DATAIN[k]),
		        .T(T_OUT[k-1]),
		        .IO(IOB[k]),
		        .IOB(IOB[k-1]),
            .IBUFDISABLE((IBUF_DIS_SRC_3[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		        .DCITERMDISABLE((ODT_SRC_3[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		        );
         end
         else
         begin
		        IOBUFDS I_IOBUFDS(
		        .I(O0[k]),
		        .O(DATAIN[k]),
		        .T(T_OUT[k]),
		        .IO(IOB[k]),
		        .IOB(IOB[k-1]) 
           );         
         end
	end
	else if(iob_type[k]== 4'b0110)
	begin
		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_IBUFDS(
		.I(),
		.O(DATAIN[k]),
		.OB(DATAIN[k-1]),
		.TM(1'b1),
		.TS(1'b1),
		.IO(IOB[k]),
		.IOB(IOB[k-1]),
    .IBUFDISABLE((IBUF_DIS_SRC_3[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		.DCITERMDISABLE((ODT_SRC_3[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		);
	end
	else if(iob_type[k]== 4'b0101)
	begin
//		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_OBUFDS(
//		.I(O0[k]),
//		.O(),
//		.OB(),
//		.TM(T_OUT[k]),
//		.TS(T_OUT[k]),
//		.IO(IOB[k]),
//		.IOB(IOB[k-1]),
//    .IBUFDISABLE((IBUF_DIS_SRC_3[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
//		.DCITERMDISABLE((ODT_SRC_3[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
//		);
		OBUFDS I_OBUFDS(
		.I  (O0[k]),
                .O  (IOB[k]), 
                .OB (IOB[k-1]));
	end
	else if(iob_type[k]== 4'b1101)
	begin
		OBUFDS_DPHY I_OBUFDS_DPHY(
		.O  (IOB[k]), 
                .OB (IOB[k-1]),
	        .HSTX_I(O0[k]),
                .HSTX_T(T_OUT[k]),
                .LPTX_I_N(LPTX_I_RX_O[k-1]),
                .LPTX_I_P(LPTX_I_RX_O[k]),
                .LPTX_T(LPTX_T_RX_DISABLE[k]));
	end
	else if(iob_type[k]== 4'b1110)
	begin
		IBUFDS_DPHY #(
          .SIM_DEVICE (SIM_DEVICE)
		) I_IBUFDS_DPHY(
		.HSRX_O(DATAIN[k]),
                .LPRX_O_N(LPTX_I_RX_O[k-1]),
                .LPRX_O_P(LPTX_I_RX_O[k]),
                .HSRX_DISABLE(HSRX_DISABLE[k]),
                .I(IOB[k]),
                .IB(IOB[k-1]),
                .LPRX_DISABLE(LPTX_T_RX_DISABLE[k]));
	end
  end
endgenerate
generate for( k = 4; k <=52; k=k+6) 
 begin : IOB_DIFF_EVEN_4
        if(iob_type[k]==4'b0111)
	begin
          if(INTF == "LPDDR4") 
          begin
		        IOBUFDS_COMP I_IOBUFDS(
		        .I(O0[k+1]),
		        .O(DATAIN[k]),
		        .T(T_OUT[k+1]),
		        .IO(IOB[k]),
		        .IOB(IOB[k+1]),
            .IBUFDISABLE((IBUF_DIS_SRC_4[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		        .DCITERMDISABLE((ODT_SRC_4[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		        );
         end
         else
         begin
		        IOBUFDS I_IOBUFDS(
		        .I(O0[k]),
		        .O(DATAIN[k]),
		        .T(T_OUT[k]),
		        .IO(IOB[k]),
		        .IOB(IOB[k+1])
		        );
         end
	end
	else if(iob_type[k]== 4'b0110)
	begin
		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_IBUFDS(
		.I(),
		.O(DATAIN[k]),
		.OB(DATAIN[k+1]),
		.TM(1'b1),
		.TS(1'b1),
		.IO(IOB[k]),
		.IOB(IOB[k+1]),
    .IBUFDISABLE((IBUF_DIS_SRC_4[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		.DCITERMDISABLE((ODT_SRC_4[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		);
	end
	else if(iob_type[k]== 4'b0101)
	begin
//		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_OBUFDS(
//		.I(O0[k]),
//		.O(),
//		.OB(),
//		.TM(T_OUT[k]),
//		.TS(T_OUT[k]),
//		.IO(IOB[k]),
//		.IOB(IOB[k+1]),
//    .IBUFDISABLE((IBUF_DIS_SRC_4[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
//		.DCITERMDISABLE((ODT_SRC_4[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
//		);
		OBUFDS I_OBUFDS(
		.I  (O0[k]),
                .O  (IOB[k]), 
                .OB (IOB[k+1]));
	end
	else if(iob_type[k]== 4'b1101)
	begin
		OBUFDS_DPHY I_OBUFDS_DPHY(
		.O  (IOB[k]), 
                .OB (IOB[k+1]),
	        .HSTX_I(O0[k]),
                .HSTX_T(T_OUT[k]),
                .LPTX_I_N(LPTX_I_RX_O[k+1]),
                .LPTX_I_P(LPTX_I_RX_O[k]),
                .LPTX_T(LPTX_T_RX_DISABLE[k]));
	end
	else if(iob_type[k]== 4'b1110)
	begin
		IBUFDS_DPHY #(
          .SIM_DEVICE (SIM_DEVICE)
		)
		I_IBUFDS_DPHY(
		.HSRX_O(DATAIN[k]),
                .LPRX_O_N(LPTX_I_RX_O[k+1]),
                .LPRX_O_P(LPTX_I_RX_O[k]),
                .HSRX_DISABLE(HSRX_DISABLE[k]),
                .I(IOB[k]),
                .IB(IOB[k+1]),
                .LPRX_DISABLE(LPTX_T_RX_DISABLE[k]));
	end
  end
endgenerate


generate for( k = 5; k <=53; k=k+6) 
 begin : IOB_DIFF_ODD_5
        if(iob_type[k]==4'b0111)
	begin
          if(INTF == "LPDDR4")
          begin       
		          IOBUFDS_COMP I_IOBUFDS(
		          .I(O0[k-1]),
		          .O(DATAIN[k]),
		          .T(T_OUT[k-1]),
		          .IO(IOB[k]),
		          .IOB(IOB[k-1]),
              .IBUFDISABLE((IBUF_DIS_SRC_5[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		          .DCITERMDISABLE((ODT_SRC_5[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		          );
         end
         else
         begin
		          IOBUFDS I_IOBUFDS(
		          .I(O0[k]),
		          .O(DATAIN[k]),
		          .T(T_OUT[k]),
		          .IO(IOB[k]),
		          .IOB(IOB[k-1])
		          );
         end
	end
	else if(iob_type[k]== 4'b0110)
	begin
		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_IBUFDS(
		.I(),
		.O(DATAIN[k]),
		.OB(DATAIN[k-1]),
		.TM(1'b1),
		.TS(1'b1),
		.IO(IOB[k]),
		.IOB(IOB[k-1]),
    .IBUFDISABLE((IBUF_DIS_SRC_5[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
		.DCITERMDISABLE((ODT_SRC_5[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
		);
	end
	else if(iob_type[k]== 4'b0101)
	begin
//		IOBUFDS_DIFF_OUT_DCIEN #( .SIM_DEVICE(SIM_DEVICE)) I_OBUFDS(
//		.I(O0[k]),
//		.O(),
//		.OB(),
//		.TM(T_OUT[k]),
//		.TS(T_OUT[k]),
//		.IO(IOB[k]),
//		.IOB(IOB[k-1]),
//    .IBUFDISABLE((IBUF_DIS_SRC_5[k/6]=="EXTERNAL")? IBUF_DISABLE_EXTERNAL[k] : IBUF_DISABLE[k]),
//		.DCITERMDISABLE((ODT_SRC_5[k/6]=="EXTERNAL")? DCI_TERM_DISABLE_EXTERNAL[k] : DYN_DCI[k])
//		);
		OBUFDS I_OBUFDS(
		.I  (O0[k]),
                .O  (IOB[k]), 
                .OB (IOB[k-1]));
	end
	else if(iob_type[k]== 4'b1101)
	begin
		OBUFDS_DPHY I_OBUFDS_DPHY(
		.O  (IOB[k]), 
                .OB (IOB[k-1]),
	        .HSTX_I(O0[k]),
                .HSTX_T(T_OUT[k]),
                .LPTX_I_N(LPTX_I_RX_O[k-1]),
                .LPTX_I_P(LPTX_I_RX_O[k]),
                .LPTX_T(LPTX_T_RX_DISABLE[k]));
	end
	else if(iob_type[k]== 4'b1110)
	begin
		IBUFDS_DPHY #(
          .SIM_DEVICE (SIM_DEVICE)
		) I_IBUFDS_DPHY(
		.HSRX_O(DATAIN[k]),
                .LPRX_O_N(LPTX_I_RX_O[k-1]),
                .LPRX_O_P(LPTX_I_RX_O[k]),
                .HSRX_DISABLE(HSRX_DISABLE[k]),
                .I(IOB[k]),
                .IB(IOB[k-1]),
                .LPRX_DISABLE(LPTX_T_RX_DISABLE[k]));
	end
  end
endgenerate

//addition of VREF 
generate for(k = 0; k <9; k=k+1)
begin: IO_VREF
	if(VREF_FABRIC[k]=="FABRIC")
	begin
(* DONT_TOUCH = "TRUE"*)		XPIO_VREF#(
    .VREF_NIB (VREF_NIB),
    .ISTANDARD ((ISTANDARD[k]=="POD12")? "POD12" : ((ISTANDARD[k]=="LVSTL_11")? "LVSTL_11" : ((ISTANDARD[k]=="LVSTL06_12")? "LVSTL06_12" : "UNUSED")) )
) I_VREF(
		.FABRIC_VREF_TUNE(VREF[(k+1)*10-1:k*10]),
		.VREF(VREF_int[k])
		);
	end
	else if(VREF_FABRIC[k]=="RIU")
	begin
(* DONT_TOUCH = "TRUE"*)		XPIO_VREF#(
    .VREF_NIB (VREF_NIB),
    .ISTANDARD ((ISTANDARD[k]=="POD12")? "POD12" : ((ISTANDARD[k]=="LVSTL_11")? "LVSTL_11" : ((ISTANDARD[k]=="LVSTL06_12")? "LVSTL06_12" : "UNUSED")) )
) I_VREF(
		.FABRIC_VREF_TUNE(),
		.VREF(VREF_int[k])
		);
	end
end
endgenerate
endmodule
