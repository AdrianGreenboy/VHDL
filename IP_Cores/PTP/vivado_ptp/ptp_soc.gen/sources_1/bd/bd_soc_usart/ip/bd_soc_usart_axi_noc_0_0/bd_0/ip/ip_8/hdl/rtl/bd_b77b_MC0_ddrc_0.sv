

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
(* DowngradeIPIdentifiedWarnings = "yes" *)
module bd_b77b_MC0_ddrc_0 (
     from_noc_0
    ,from_noc_1
    ,from_noc_2
    ,from_noc_3
     //sys_clk
    ,sys_clk_p
    ,sys_clk_n
    ,ch0_ddr4_adr
    ,ch0_ddr4_ba
    ,ch0_ddr4_bg
    ,ch0_ddr4_cke
    ,ch0_ddr4_ck_t
    ,ch0_ddr4_ck_c
    ,ch0_ddr4_cs_n
    ,ch0_ddr4_dm_dbi_n
    ,ch0_ddr4_dq
    ,ch0_ddr4_dqs_c
    ,ch0_ddr4_dqs_t
    ,ch0_ddr4_odt
    ,ch0_ddr4_reset_n
    ,ch0_ddr4_act_n
    ,noc2dmc_valid_in_0
    ,noc2dmc_data_in_0
    ,noc2dmc_credit_rdy_0   
    ,dmc2noc_credit_rtn_0   
    ,noc2dmc_valid_in_1
    ,noc2dmc_data_in_1
    ,noc2dmc_credit_rdy_1   
    ,dmc2noc_credit_rtn_1 
    ,noc2dmc_valid_in_2
    ,noc2dmc_data_in_2
    ,noc2dmc_credit_rdy_2   
    ,dmc2noc_credit_rtn_2
    ,noc2dmc_valid_in_3
    ,noc2dmc_data_in_3
    ,noc2dmc_credit_rdy_3   
    ,dmc2noc_credit_rtn_3
    ,dmc2noc_valid_out_0 
    ,dmc2noc_data_out_0 
    ,dmc2noc_credit_rdy_0
    ,noc2dmc_credit_rtn_0
    ,dmc2noc_valid_out_1 
    ,dmc2noc_data_out_1 
    ,dmc2noc_credit_rdy_1
    ,noc2dmc_credit_rtn_1
    ,dmc2noc_valid_out_2 
    ,dmc2noc_data_out_2 
    ,dmc2noc_credit_rdy_2
    ,noc2dmc_credit_rtn_2
    ,dmc2noc_valid_out_3 
    ,dmc2noc_data_out_3 
    ,dmc2noc_credit_rdy_3
    ,noc2dmc_credit_rtn_3
);


//;input                             sys_clk
;input                             sys_clk_p
;input                             sys_clk_n
;output  [16 : 0]                  ch0_ddr4_adr
;output  [0 : 0]                   ch0_ddr4_bg
;output  [1 : 0]                   ch0_ddr4_ba
;output  [0 : 0]                   ch0_ddr4_cke
;output  [0 : 0]                   ch0_ddr4_ck_t
;output  [0 : 0]                   ch0_ddr4_ck_c
;output  [0 : 0]                   ch0_ddr4_cs_n
;inout   [7 : 0]                    ch0_ddr4_dm_dbi_n
;inout   [63 : 0]                   ch0_ddr4_dq
;inout   [7 : 0]                    ch0_ddr4_dqs_c
;inout   [7 : 0]                    ch0_ddr4_dqs_t
;output  [0 : 0]                   ch0_ddr4_odt
;output  ch0_ddr4_reset_n
;output  ch0_ddr4_act_n
;input  [7:0]                      noc2dmc_valid_in_0
;input  [181:0]                    noc2dmc_data_in_0
;input                             noc2dmc_credit_rdy_0  
;output [7:0]                      dmc2noc_credit_rtn_0 
;input  [7:0]                      noc2dmc_valid_in_1
;input  [181:0]                    noc2dmc_data_in_1
;input                             noc2dmc_credit_rdy_1 
;output [7:0]                      dmc2noc_credit_rtn_1 
;input  [7:0]                      noc2dmc_valid_in_2
;input  [181:0]                    noc2dmc_data_in_2
;input                             noc2dmc_credit_rdy_2 
;output [7:0]                      dmc2noc_credit_rtn_2 
;input  [7:0]                      noc2dmc_valid_in_3
;input  [181:0]                    noc2dmc_data_in_3
;input                             noc2dmc_credit_rdy_3
;output [7:0]                      dmc2noc_credit_rtn_3
;output logic [7:0]                dmc2noc_valid_out_0 
;output logic [181:0]              dmc2noc_data_out_0 
;output logic                      dmc2noc_credit_rdy_0
;input  [7:0]                      noc2dmc_credit_rtn_0
;output logic [7:0]                dmc2noc_valid_out_1 
;output logic [181:0]              dmc2noc_data_out_1 
;output logic                      dmc2noc_credit_rdy_1
;input  [7:0]                      noc2dmc_credit_rtn_1
;output logic [7:0]                dmc2noc_valid_out_2 
;output logic [181:0]              dmc2noc_data_out_2 
;output logic                      dmc2noc_credit_rdy_2
;input  [7:0]                      noc2dmc_credit_rtn_2
;output logic [7:0]                dmc2noc_valid_out_3 
;output logic [181:0]              dmc2noc_data_out_3 
;output logic                      dmc2noc_credit_rdy_3
;input  [7:0]                      noc2dmc_credit_rtn_3
;input                             from_noc_0
;input                             from_noc_1
;input                             from_noc_2
;input                             from_noc_3;


//Ryan Arp request for the init_cal_complete
//assign init_cal_complete = inst.noc_ddr4_phy.inst.u_ddr4mc_top.initDone;
/* 
assign init_cal_complete = inst.noc_ddr4_phy.inst.u_ddr4mc_top.initDone;
 */


bd_b77b_MC0_ddrc_0_wrapper #(
    .NPI_REG_DDRMC_NSU_0_ING('H04534101),
    .NPI_REG_DDRMC_NSU_0_EGR('H00473610),
    .NPI_REG_DDRMC_NSU_0_R_EGR('H01010100),
    .NPI_REG_DDRMC_NSU_0_W_EGR('H00010100),
    .NPI_REG_DDRMC_NSU_1_ING('H04534101),
    .NPI_REG_DDRMC_NSU_1_EGR('H00473610),
    .NPI_REG_DDRMC_NSU_1_R_EGR('H01010100),
    .NPI_REG_DDRMC_NSU_1_W_EGR('H00010100),
    .NPI_REG_DDRMC_NSU_2_ING('H04534101),
    .NPI_REG_DDRMC_NSU_2_EGR('H00473610),
    .NPI_REG_DDRMC_NSU_2_R_EGR('H01010100),
    .NPI_REG_DDRMC_NSU_2_W_EGR('H00010100),
    .NPI_REG_DDRMC_NSU_3_ING('H04534101),
    .NPI_REG_DDRMC_NSU_3_EGR('H00473610),
    .NPI_REG_DDRMC_NSU_3_R_EGR('H01010100),
    .NPI_REG_DDRMC_NSU_3_W_EGR('H00010100),
    .REG_RD_DRR_TKN_P0('H00ff0404),
    .REG_RD_DRR_TKN_P1('H002b0404),
    .REG_RD_DRR_TKN_P2('H00550404),
    .REG_RD_DRR_TKN_P3('H00550404),
    .REG_WR_DRR_TKN_P0('H0000ff04),
    .REG_WR_DRR_TKN_P1('H00002b04),
    .REG_WR_DRR_TKN_P2('H00005504),
    .REG_WR_DRR_TKN_P3('H00005504),
    .REG_QOS0('H001e01e0),
    .REG_QOS1('H0ff00804),
    .REG_QOS2('H0003fc02),
    .REG_QOS_TIMEOUT0('H00421084),
    .REG_QOS_TIMEOUT1('Hb4b4b4b4),
    .REG_QOS_TIMEOUT2('H000000b4),
    .REG_RATE_CTRL_SCALE('H00000000),
    .REG_P0_LLR_RATE_CTRL('H003ffc0f),
    .REG_P0_ISR_RATE_CTRL('H003ffc0f),
    .REG_P0_BER_RATE_CTRL('H003ffc0f),
    .REG_P0_ISW_RATE_CTRL('H003ffc0f),
    .REG_P0_BEW_RATE_CTRL('H003ffc0f),
    .REG_P1_LLR_RATE_CTRL('H003ffc0f),
    .REG_P1_ISR_RATE_CTRL('H003ffc0f),
    .REG_P1_BER_RATE_CTRL('H003ffc0f),
    .REG_P1_ISW_RATE_CTRL('H003ffc0f),
    .REG_P1_BEW_RATE_CTRL('H003ffc0f),
    .REG_P2_LLR_RATE_CTRL('H003ffc0f),
    .REG_P2_ISR_RATE_CTRL('H003ffc0f),
    .REG_P2_BER_RATE_CTRL('H003ffc0f),
    .REG_P2_ISW_RATE_CTRL('H003ffc0f),
    .REG_P2_BEW_RATE_CTRL('H003ffc0f),
    .REG_P3_LLR_RATE_CTRL('H003ffc0f),
    .REG_P3_ISR_RATE_CTRL('H003ffc0f),
    .REG_P3_BER_RATE_CTRL('H003ffc0f),
    .REG_P3_ISW_RATE_CTRL('H003ffc0f),
    .REG_P3_BEW_RATE_CTRL('H003ffc0f),
    .REG_CMDQ_CTRL0('H01ffffff),
    .REG_CMDQ_CTRL1('H01084210),
    .REG_CMDQ_LLR_RATE_CTRL('H003ffc0f),
    .REG_CMDQ_ISR_RATE_CTRL('H003ffc0f),
    .REG_CMDQ_BER_RATE_CTRL('H003ffc0f),
    .REG_CMDQ_ISW_RATE_CTRL('H003ffc0f),
    .REG_CMDQ_BEW_RATE_CTRL('H003ffc0f),
    .REG_QOS_RATE_CTRL_SCALE('H00000000),
    .DC_CMD_CREDITS('H000002a8),
    .EXMON_CLR_EXE('H00000100),
    .XMPU_CTRL('H0000000b),
    .XMPU_START_LO0('H00000000),
    .XMPU_START_HI0('H00000000),
    .XMPU_END_LO0('H00000000),
    .XMPU_END_HI0('H00000000),
    .XMPU_MASTER0('H00000000),
    .XMPU_CONFIG0('H00000008),
    .XMPU_START_LO1('H00000000),
    .XMPU_START_HI1('H00000000),
    .XMPU_END_LO1('H00000000),
    .XMPU_END_HI1('H00000000),
    .XMPU_MASTER1('H00000000),
    .XMPU_CONFIG1('H00000008),
    .XMPU_START_LO2('H00000000),
    .XMPU_START_HI2('H00000000),
    .XMPU_END_LO2('H00000000),
    .XMPU_END_HI2('H00000000),
    .XMPU_MASTER2('H00000000),
    .XMPU_CONFIG2('H00000008),
    .XMPU_START_LO3('H00000000),
    .XMPU_START_HI3('H00000000),
    .XMPU_END_LO3('H00000000),
    .XMPU_END_HI3('H00000000),
    .XMPU_MASTER3('H00000000),
    .XMPU_CONFIG3('H00000008),
    .XMPU_START_LO4('H00000000),
    .XMPU_START_HI4('H00000000),
    .XMPU_END_LO4('H00000000),
    .XMPU_END_HI4('H00000000),
    .XMPU_MASTER4('H00000000),
    .XMPU_CONFIG4('H00000008),
    .XMPU_START_LO5('H00000000),
    .XMPU_START_HI5('H00000000),
    .XMPU_END_LO5('H00000000),
    .XMPU_END_HI5('H00000000),
    .XMPU_MASTER5('H00000000),
    .XMPU_CONFIG5('H00000008),
    .XMPU_START_LO6('H00000000),
    .XMPU_START_HI6('H00000000),
    .XMPU_END_LO6('H00000000),
    .XMPU_END_HI6('H00000000),
    .XMPU_MASTER6('H00000000),
    .XMPU_CONFIG6('H00000008),
    .XMPU_START_LO7('H00000000),
    .XMPU_START_HI7('H00000000),
    .XMPU_END_LO7('H00000000),
    .XMPU_END_HI7('H00000000),
    .XMPU_MASTER7('H00000000),
    .XMPU_CONFIG7('H00000008),
    .XMPU_START_LO8('H00000000),
    .XMPU_START_HI8('H00000000),
    .XMPU_END_LO8('H00000000),
    .XMPU_END_HI8('H00000000),
    .XMPU_MASTER8('H00000000),
    .XMPU_CONFIG8('H00000008),
    .XMPU_START_LO9('H00000000),
    .XMPU_START_HI9('H00000000),
    .XMPU_END_LO9('H00000000),
    .XMPU_END_HI9('H00000000),
    .XMPU_MASTER9('H00000000),
    .XMPU_CONFIG9('H00000008),
    .XMPU_START_LO10('H00000000),
    .XMPU_START_HI10('H00000000),
    .XMPU_END_LO10('H00000000),
    .XMPU_END_HI10('H00000000),
    .XMPU_MASTER10('H00000000),
    .XMPU_CONFIG10('H00000008),
    .XMPU_START_LO11('H00000000),
    .XMPU_START_HI11('H00000000),
    .XMPU_END_LO11('H00000000),
    .XMPU_END_HI11('H00000000),
    .XMPU_MASTER11('H00000000),
    .XMPU_CONFIG11('H00000008),
    .XMPU_START_LO12('H00000000),
    .XMPU_START_HI12('H00000000),
    .XMPU_END_LO12('H00000000),
    .XMPU_END_HI12('H00000000),
    .XMPU_MASTER12('H00000000),
    .XMPU_CONFIG12('H00000008),
    .XMPU_START_LO13('H00000000),
    .XMPU_START_HI13('H00000000),
    .XMPU_END_LO13('H00000000),
    .XMPU_END_HI13('H00000000),
    .XMPU_MASTER13('H00000000),
    .XMPU_CONFIG13('H00000008),
    .XMPU_START_LO14('H00000000),
    .XMPU_START_HI14('H00000000),
    .XMPU_END_LO14('H00000000),
    .XMPU_END_HI14('H00000000),
    .XMPU_MASTER14('H00000000),
    .XMPU_CONFIG14('H00000008),
    .XMPU_START_LO15('H00000000),
    .XMPU_START_HI15('H00000000),
    .XMPU_END_LO15('H00000000),
    .XMPU_END_HI15('H00000000),
    .XMPU_MASTER15('H00000000),
    .XMPU_CONFIG15('H00000008),
    .REG_ADEC0('H00000000),
    .REG_ADEC1('H00000000),
    .REG_ADEC2('H00100080),
    .REG_ADEC3('H00000078),
    .REG_NSU0_PORT('H000001c0),
    .REG_NSU1_PORT('H00000200),
    .REG_NSU2_PORT('H00000240),
    .REG_NSU3_PORT('H00000280),
    .UB_CLK_MUX('H00000000),
    .TCK(628)
) inst (
 .from_noc_0(from_noc_0)
,.from_noc_1(from_noc_1)
,.from_noc_2(from_noc_2)
,.from_noc_3(from_noc_3)
//,.sys_clk(sys_clk)
,.sys_clk_p(sys_clk_p)
,.sys_clk_n(sys_clk_n)
,.ch0_ddr4_adr(ch0_ddr4_adr)      
,.ch0_ddr4_bg(ch0_ddr4_bg)
,.ch0_ddr4_ba(ch0_ddr4_ba)
,.ch0_ddr4_cke(ch0_ddr4_cke)
,.ch0_ddr4_ck_t(ch0_ddr4_ck_t)
,.ch0_ddr4_ck_c(ch0_ddr4_ck_c)
,.ch0_ddr4_cs_n(ch0_ddr4_cs_n)
,.ch0_ddr4_dm_dbi_n(ch0_ddr4_dm_dbi_n)
,.ch0_ddr4_dq(ch0_ddr4_dq)
,.ch0_ddr4_dqs_c(ch0_ddr4_dqs_c)
,.ch0_ddr4_dqs_t(ch0_ddr4_dqs_t)
,.ch0_ddr4_odt(ch0_ddr4_odt)
,.ch0_ddr4_reset_n(ch0_ddr4_reset_n)
,.ch0_ddr4_act_n(ch0_ddr4_act_n)     
,.noc2dmc_valid_in_0(noc2dmc_valid_in_0)
,.noc2dmc_data_in_0(noc2dmc_data_in_0)
,.noc2dmc_credit_rdy_0(noc2dmc_credit_rdy_0)
,.dmc2noc_credit_rtn_0(dmc2noc_credit_rtn_0)
,.noc2dmc_valid_in_1(noc2dmc_valid_in_1)
,.noc2dmc_data_in_1(noc2dmc_data_in_1)
,.noc2dmc_credit_rdy_1(noc2dmc_credit_rdy_1)
,.dmc2noc_credit_rtn_1(dmc2noc_credit_rtn_1)
,.noc2dmc_valid_in_2(noc2dmc_valid_in_2)
,.noc2dmc_data_in_2(noc2dmc_data_in_2)
,.noc2dmc_credit_rdy_2(noc2dmc_credit_rdy_2)
,.dmc2noc_credit_rtn_2(dmc2noc_credit_rtn_2)
,.noc2dmc_valid_in_3(noc2dmc_valid_in_3)
,.noc2dmc_data_in_3(noc2dmc_data_in_3)
,.noc2dmc_credit_rdy_3(noc2dmc_credit_rdy_3)
,.dmc2noc_credit_rtn_3(dmc2noc_credit_rtn_3)
,.dmc2noc_valid_out_0(dmc2noc_valid_out_0)
,.dmc2noc_data_out_0(dmc2noc_data_out_0)
,.dmc2noc_credit_rdy_0(dmc2noc_credit_rdy_0)
,.noc2dmc_credit_rtn_0(noc2dmc_credit_rtn_0)
,.dmc2noc_valid_out_1(dmc2noc_valid_out_1)
,.dmc2noc_data_out_1(dmc2noc_data_out_1)
,.dmc2noc_credit_rdy_1(dmc2noc_credit_rdy_1)
,.noc2dmc_credit_rtn_1(noc2dmc_credit_rtn_1)
,.dmc2noc_valid_out_2(dmc2noc_valid_out_2)
,.dmc2noc_data_out_2(dmc2noc_data_out_2)
,.dmc2noc_credit_rdy_2(dmc2noc_credit_rdy_2)
,.noc2dmc_credit_rtn_2(noc2dmc_credit_rtn_2)
,.dmc2noc_valid_out_3(dmc2noc_valid_out_3)
,.dmc2noc_data_out_3(dmc2noc_data_out_3)
,.dmc2noc_credit_rdy_3(dmc2noc_credit_rdy_3)
,.noc2dmc_credit_rtn_3(noc2dmc_credit_rtn_3)
);

endmodule
