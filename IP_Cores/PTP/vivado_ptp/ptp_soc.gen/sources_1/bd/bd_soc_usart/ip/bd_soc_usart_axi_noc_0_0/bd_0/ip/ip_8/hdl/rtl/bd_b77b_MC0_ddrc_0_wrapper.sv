

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
(* DowngradeIPIdentifiedWarnings = "yes",
   X_VERSAL_IO_FLOW = "xilinx.com:ip:noc_mc_ddr4_phy:1.0",
   DONT_TOUCH                                 = "TRUE",
   XPHYIO_PHY_IP_INST_NAME                    = "noc_ddr4_phy",
   XPHYIO_Component_Name                      = "bd_b77b_MC0_ddrc_0",
   XPHYIO_CONTROLLERTYPE                      = "DDR4_SDRAM",
   XPHYIO_MC_MEMORY_TIMEPERIOD0             = 625,
   XPHYIO_MC_MEMORY_TIMEPERIOD1             = 625,
   XPHYIO_MC_INPUT_FREQUENCY0               = 200.000,
   XPHYIO_MC_INPUTCLK0_PERIOD               = 5000,
   XPHYIO_MC_OP_TIMEPERIOD0                 = 625,
   XPHYIO_MC_IP_TIMEPERIOD0_FOR_OP          = 1250,
   XPHYIO_MC_FREQ_SEL                       = "SYS_CLK_FROM_MEMORY_CLK",
   XPHYIO_MC_INPUTCLK0_PERIOD_NS            = 5.000,
   XPHYIO_MC_F0_PLL0_CLKOUT0_NS             = 1.250,
   XPHYIO_MC_F0_CLKFBOUT_MULT               = 16, 
   XPHYIO_MC_F0_DIVCLK_DIVIDE               = 1, 
   XPHYIO_MC_F0_CLKOUTPHY_DIVIDE            = "DIV1", 
   XPHYIO_MC_F0_CLKOUT0_DIVIDE               = 1, 
   XPHYIO_MC_F0_CLKOUT1_DIVIDE               = 4, 
   XPHYIO_MC_F0_CLKOUT2_DIVIDE               = 4, 
   XPHYIO_MC_F0_CLKOUT3_DIVIDE               = 1, 
   XPHYIO_MC_INPUTCLK1_PERIOD               = 2500,
   XPHYIO_MC_INPUT_FREQUENCY1               = 400.000,
   XPHYIO_MC_INPUTCLK1_PERIOD_NS            = 2.5,
   XPHYIO_MC_F1_PLL0_CLKOUT0_NS             = 1.25,
   XPHYIO_MC_F1_CLKFBOUT_MULT               = 16, 
   XPHYIO_MC_F1_DIVCLK_DIVIDE               = 1, 
   XPHYIO_MC_F1_CLKOUTPHY_DIVIDE            = "DIV1", 
   XPHYIO_MC_F1_CLKOUT0_DIVIDE               = 1, 
   XPHYIO_MC_F1_CLKOUT1_DIVIDE               = 4, 
   XPHYIO_MC_F1_CLKOUT2_DIVIDE               = 4, 
   XPHYIO_MC_F1_CLKOUT3_DIVIDE               = 1, 
   XPHYIO_MC_SYSTEM_CLOCK                   = "Differential", 
   XPHYIO_MC_MEMORY_DEVICETYPE              = "Components", 
   XPHYIO_MC_MEMORY_SPEEDGRADE              = "DDR4-3200AA(22-22-22)", 
   XPHYIO_MC_BURST_LENGTH                   = "8", 
   XPHYIO_MC_COMPONENT_WIDTH                = "x16",
   XPHYIO_MC_MAIN_MODULE_NAME                = "DDRMC_MAIN_0",
   XPHYIO_MC_NOC_MODULE_NAME                = "DDRMC_NOC_0",
   XPHYIO_MC_MAIN_BASE_ADDR                = "0xF6150000",
   XPHYIO_MC_NOC_BASE_ADDR                 = "0xF6070000",
   XPHYIO_MC_COMPONENT_DENSITY              = "16Gb",
   XPHYIO_MC_CA_MIRROR                      = "false",
   XPHYIO_MC_TCKE                           = "8",
   XPHYIO_MC_TDQSCK_MIN                      =  1500,
   XPHYIO_MC_TDQSCK_MAX                      =  0,
   XPHYIO_MC_TDQSS_MIN                       =  0.75,
   XPHYIO_MC_TDQSS_MAX                       =  1.25,
   XPHYIO_MC_TDQS2DQ_MIN                       =  0,
   XPHYIO_MC_TDQS2DQ_MAX                       =  0,
   XPHYIO_MC_TFAW                            =  30000,
   XPHYIO_MC_TFAW_nCK                        =  48,
   XPHYIO_MC_TFAW_DLR                        =  0,
   XPHYIO_MC_TMRD                            =  8,
   XPHYIO_MC_TMRD_div4                       =  0,
   XPHYIO_MC_TMRD_nCK                        =  0,
   XPHYIO_MC_TCMR_MRD                        =  0,
   XPHYIO_MC_TSTAB                           =  0,
   XPHYIO_MC_PARITY                          =  "false",
   XPHYIO_MC_REGVAL_COMPARE                  =  "false",
   XPHYIO_MC_RCD_PARITY                      =  "false",
   XPHYIO_MC_PARITYLATENCY                   =  "0",
   XPHYIO_MC_F1_PARITYLATENCY                =  "0",
   XPHYIO_MC_TPAR_ALERT_ON                   =  "10",
   XPHYIO_MC_F1_TPAR_ALERT_ON                =  "0",
   XPHYIO_MC_TPAR_ALERT_PW_MAX               =  "192",
   XPHYIO_MC_F1_TPAR_ALERT_PW_MAX            =  "0",
   XPHYIO_MC_TPDM_RD                         =  "0",  
   XPHYIO_MC_F1_TPDM_RD                      =  "0", 
   XPHYIO_MC_TRAS                            =  32000,
   XPHYIO_MC_TRAS_nCK                        =  0,
   XPHYIO_MC_TRCD                            =  13750,
   XPHYIO_MC_TRCD_nCK                        =  0,
   XPHYIO_MC_TREFI                           =  7800000,
   XPHYIO_MC_TRFC                            =  550000,
   XPHYIO_MC_TRP                             =  13750,
   XPHYIO_MC_TOSCO                           =  0,
   XPHYIO_MC_TOSCO_nCK                       =  0,
   XPHYIO_MC_TWPST                           =  0.33,
   XPHYIO_MC_TWPRE                           =  0.9,
   XPHYIO_MC_TRPST                           =  0.4,
   XPHYIO_MC_TRPRE                           =  0.9,
   XPHYIO_MC_TRRD_S                          =  9,
   XPHYIO_MC_TRRD_S_nCK                      =  1,
   XPHYIO_MC_TRRD_L                          =  11,
   XPHYIO_MC_TRRD_L_nCK                      =  1,
   XPHYIO_MC_TRRD_DLR                        =  0,
   XPHYIO_MC_TRTP                            =  7500,
   XPHYIO_MC_TRTP_nCK                        =  12,
   XPHYIO_MC_TMOD                            =  24,
   XPHYIO_MC_TMOD_nCK                        =  24,
   XPHYIO_MC_TMPRR                           =  1,
   XPHYIO_MC_TBCW                            =  0,
   XPHYIO_MC_TMRC                            =  0,
   XPHYIO_MC_TWR                             =  15000,
   XPHYIO_MC_TWR_nCK                         =  0,
   XPHYIO_MC_TWTR_S                          =  2500,
   XPHYIO_MC_TWTR_L                          =  7500,
   XPHYIO_MC_TXP                             =  10,
   XPHYIO_MC_TXPR                            =  896,
   XPHYIO_MC_TXPR_nCK                        =  5,
   XPHYIO_MC_TZQCS                           =  128,
   XPHYIO_MC_TZQINIT                         =  1024,
   XPHYIO_MC_TZQCS_ITVL                      =  1000000000,
   XPHYIO_MC_TZQ_START_ITVL                  =  0,
   XPHYIO_MC_TZQCAL                          =  0,
   XPHYIO_MC_TZQCAL_div4                     =  0,
   XPHYIO_MC_TZQLAT                          =  0,
   XPHYIO_MC_TZQLAT_div4                     =  0,
   XPHYIO_MC_TZQLAT_nCK                      =  0,
   XPHYIO_MC_TMRW                            =  0,
   XPHYIO_MC_TMRW_div4                       =  0,
   XPHYIO_MC_TMRW_nCK                        =  0,
   XPHYIO_MC_TMRR                            =  8,
   XPHYIO_MC_TCCD_3DS                        =  0,
   XPHYIO_MC_TRTW                            =  350,
   XPHYIO_MC_TREFIPB                         =  0,
   XPHYIO_MC_TRFCAB                          =  0,
   XPHYIO_MC_TRFCPB                          =  0,
   XPHYIO_MC_TPBR2PBR                        =  0,
   XPHYIO_MC_TRPAB                           =  0,
   XPHYIO_MC_TRPAB_nCK                       =  0,
   XPHYIO_MC_TRPPB                           =  0,
   XPHYIO_MC_TRPPB_nCK                       =  0,
   XPHYIO_MC_TRRD                            =  0,
   XPHYIO_MC_TRRD_nCK                        =  0,
   XPHYIO_MC_TWTR                            =  0,
   XPHYIO_MC_TWTR_nCK                        =  0,
   XPHYIO_MC_TCCD                            =  0,
   XPHYIO_MC_TCCDMW                          =  32,
   XPHYIO_MC_ZQINTVL                         =  350,
   XPHYIO_MC_RTT                             =  "RZQ/6",
   XPHYIO_MC_CLAMSHELL                       =  "false",
   XPHYIO_MC_CLA                             =  "0",
   XPHYIO_MC_F1_CLA                          =  "0",
   XPHYIO_MC_NO_CHANNELS                     =  "Single",
   XPHYIO_MC_DATAWIDTH                       =  64,
   XPHYIO_MC_ROWADDRESSWIDTH                 =  17,
   XPHYIO_MC_COLUMNADDRESSWIDTH              =  10,
   XPHYIO_MC_BG_WIDTH                        =  1,
   XPHYIO_MC_BA_WIDTH                        =  2,
   XPHYIO_MC_RANK                            =  1,
   XPHYIO_MC_STACKHEIGHT                     =  1,
   XPHYIO_MC_SLOT                            =  "Single",
   XPHYIO_MC_ECC                             =  "false",
   XPHYIO_MC_DDR4_2T                         =  "Enable",
   XPHYIO_MC_CHANNEL_INTERLEAVING            =  "false",
   XPHYIO_MC_CH_INTERLEAVING_SIZE            =  "NONE",
   XPHYIO_MC_CASLATENCY                      =  22,
   XPHYIO_MC_CASWRITELATENCY                 =  16,
   XPHYIO_MC_ORDERING                        =  "Strict",
   XPHYIO_MC_ADDRESSMAP                      =  "ROW_COLUMN_BANK",
   XPHYIO_MC_SELFREFRESH                     =  "false",
   XPHYIO_MC_LPDDR4_REFRESH_TYPE             =  "ALL_BANK",
   XPHYIO_MC_ADD_CMD_DELAY_EN                =  "Disable",
   XPHYIO_MC_ADD_CMD_DELAY                   =  "0",
   XPHYIO_MC_F1_ADD_CMD_DELAY_EN                =  "Disable",
   XPHYIO_MC_F1_ADD_CMD_DELAY                   =  "0",
   XPHYIO_MC_RCD_DELAY                       =  "0",
   XPHYIO_MC_F1_RCD_DELAY                       =  "0",
   XPHYIO_MC_SAVERESTORE                     =  "false",
   XPHYIO_MC_SIMMODE                         =  "BFM",
   XPHYIO_MC_POWERMODES                      =  "true",
   XPHYIO_MC_ZQCS_FREQUENCY                  =  "true",
   XPHYIO_MC_USERREFRESH                     =  "false",
   XPHYIO_MC_ZQCS_PIN                        =  "true",
   XPHYIO_MC_SCRUBBING                       =  "off",
   XPHYIO_MC_EN_BACKGROUND_SCRUBBING         =  "false",
   XPHYIO_MC_PER_RD_INTVL                    =  20000000,
   XPHYIO_MC_TCCD_S                          =  4,
   XPHYIO_MC_TCCD_L                          =  8,
   XPHYIO_MC_TCCD_L_nCK                      =  5,
   XPHYIO_MC_TRC                             =  45750,
   XPHYIO_MC_REFRESH_RATE                    =  "1x",
   XPHYIO_MC_REFRESH_SPEED                   =  "1x_SPEED-NORMAL_TEMPERATURE",
   XPHYIO_MC_TRFC_DLR                        =  "0",
   XPHYIO_MC_REGION                          =  0,
   XPHYIO_MC_EN_NPP_MONITOR                  =  1,
   XPHYIO_MC_DISABLE_DATA_CHECK              =  1,
   XPHYIO_MC_LR_WIDTH                        =  1,
   XPHYIO_MC_CS_WIDTH                        =  1,
   XPHYIO_MC_PRE_DEF_ADDR_MAP_SEL            =  "ROW_BANK_COLUMN_BGO",
   XPHYIO_MC_SVFLOW                          =  "Disable",
   XPHYIO_MC_SKIPCAL                         =  "Disable",
   XPHYIO_MC_FCV_FULLCAL                     =  "Disable",
   XPHYIO_MC_PRUNECHIP_SIM_CHANGES           =  "Disable",
   XPHYIO_MC_ADDR_BIT43                      =  "NA",
   XPHYIO_MC_ADDR_BIT42                      =  "NA",
   XPHYIO_MC_ADDR_BIT41                      =  "NA",
   XPHYIO_MC_ADDR_BIT40                      =  "NA",
   XPHYIO_MC_ADDR_BIT39                      =  "NA",
   XPHYIO_MC_ADDR_BIT38                      =  "NA",
   XPHYIO_MC_ADDR_BIT37                      =  "NA",
   XPHYIO_MC_ADDR_BIT36                      =  "NA",
   XPHYIO_MC_ADDR_BIT35                      =  "NA",
   XPHYIO_MC_ADDR_BIT34                      =  "NA",
   XPHYIO_MC_ADDR_BIT33                      =  "NA",
   XPHYIO_MC_ADDR_BIT32                      =  "RA16",
   XPHYIO_MC_ADDR_BIT31                      =  "RA15",
   XPHYIO_MC_ADDR_BIT30                      =  "RA14",
   XPHYIO_MC_ADDR_BIT29                      =  "RA13",
   XPHYIO_MC_ADDR_BIT28                      =  "RA12",
   XPHYIO_MC_ADDR_BIT27                      =  "RA11",
   XPHYIO_MC_ADDR_BIT26                      =  "RA10",
   XPHYIO_MC_ADDR_BIT25                      =  "RA9",
   XPHYIO_MC_ADDR_BIT24                      =  "RA8",
   XPHYIO_MC_ADDR_BIT23                      =  "RA7",
   XPHYIO_MC_ADDR_BIT22                      =  "RA6",
   XPHYIO_MC_ADDR_BIT21                      =  "RA5",
   XPHYIO_MC_ADDR_BIT20                      =  "RA4",
   XPHYIO_MC_ADDR_BIT19                      =  "RA3",
   XPHYIO_MC_ADDR_BIT18                      =  "RA2",
   XPHYIO_MC_ADDR_BIT17                      =  "RA1",
   XPHYIO_MC_ADDR_BIT16                      =  "RA0",
   XPHYIO_MC_ADDR_BIT15                      =  "BA1",
   XPHYIO_MC_ADDR_BIT14                      =  "BA0",
   XPHYIO_MC_ADDR_BIT13                      =  "CA9",
   XPHYIO_MC_ADDR_BIT12                      =  "CA8",
   XPHYIO_MC_ADDR_BIT11                      =  "CA7",
   XPHYIO_MC_ADDR_BIT10                      =  "CA6",
   XPHYIO_MC_ADDR_BIT9                       =  "CA5",
   XPHYIO_MC_ADDR_BIT8                       =  "CA4",
   XPHYIO_MC_ADDR_BIT7                       =  "CA3",
   XPHYIO_MC_ADDR_BIT6                       =  "BG0",
   XPHYIO_MC_ADDR_BIT5                       =  "CA2",
   XPHYIO_MC_ADDR_BIT4                       =  "CA1",
   XPHYIO_MC_ADDR_BIT3                       =  "CA0",
   XPHYIO_MC_ADDR_BIT2                       =  "NC",
   XPHYIO_MC_ADDR_BIT1                       =  "NC",
   XPHYIO_MC_ADDR_BIT0                       =  "NC",
   XPHYIO_MC_DQ_WIDTH                        =  64,
   XPHYIO_MC_DQS_WIDTH                       =  8,
   XPHYIO_MC_DM_WIDTH                        =  8,
   XPHYIO_MC_CK_WIDTH                        =  1,
   XPHYIO_MC_CKE_WIDTH                       =  1,
   XPHYIO_MC_ADDR_WIDTH                      =  17,
   XPHYIO_MC_ODT_WIDTH                       =  1,
   XPHYIO_MC_TEMP_DIR_DELETE                 =  "TRUE",
   XPHYIO_MC_NUM_CK                          =  1,
   XPHYIO_MC_LP4_PIN_EFFICIENT               =  "false",
   XPHYIO_MC_CH0_LP4_CHA_ENABLE              =  "false",
   XPHYIO_MC_CH0_LP4_CHB_ENABLE              =  "false",
   XPHYIO_MC_CH1_LP4_CHA_ENABLE              =  "false",
   XPHYIO_MC_CH1_LP4_CHB_ENABLE              =  "false",
   XPHYIO_MC_LP4_DQ_A_WIDTH                  =  0,
   XPHYIO_MC_LP4_DQ_B_WIDTH                  =  0,
   XPHYIO_MC_LP4_DQS_A_WIDTH                 =  0,
   XPHYIO_MC_LP4_DQS_B_WIDTH                 =  0,
   XPHYIO_MC_LP4_DMI_A_WIDTH                 =  0,
   XPHYIO_MC_LP4_DMI_B_WIDTH                 =  0,
   XPHYIO_MC_LP4_CA_A_WIDTH                  =  0,
   XPHYIO_MC_LP4_CA_B_WIDTH                  =  0,
   XPHYIO_MC_LP4_CKT_A_WIDTH                 =  0,
   XPHYIO_MC_LP4_CKT_B_WIDTH                 =  0,
   XPHYIO_MC_LP4_CKE_A_WIDTH                 =  0,
   XPHYIO_MC_LP4_CKE_B_WIDTH                 =  0,
   XPHYIO_MC_LP4_CS_A_WIDTH                  =  0,
   XPHYIO_MC_LP4_CS_B_WIDTH                  =  0,
   XPHYIO_MC_LP4_RESETN_WIDTH                =  0,
   XPHYIO_MC_FLIPPED_PINOUT                  =  "false",
   XPHYIO_MC_WRITE_DM_DBI                    =  "DM_NO_DBI",
   XPHYIO_MC_READ_DBI                        =  "false",
   XPHYIO_MC_EN_ECC_SCRUBBING                =  "false",
   XPHYIO_MC_ECC_SCRUB_PERIOD                =  "0x003E80",
   XPHYIO_MC_INIT_MEM_USING_ECC_SCRUB        =  "false",
   XPHYIO_MC_OTF_SCRUBBING	             =  "false",
   XPHYIO_MC_IDLE_TIME_ENTR_PWR_DOWN_MODE    =  "0x00000AA",
   XPHYIO_MC_IDLE_TIME_ENTR_SELF_REF_MODE    =  "0x0020000",
   XPHYIO_MC_ATTR_FILE                  =  "nocattrs.dat",
   XPHYIO_MC_COMPONENT_NAME                  =  "bd_b77b_MC0_ddrc_0",
   XPHYIO_MC_EN_INTR_RESP                    =  "FALSE",
   XPHYIO_MC_EXTENDED_WDQS                   =  "TRUE",
   XPHYIO_MC_VNC_ENABLE                      =  "FALSE",
   XPHYIO_MC_DEVICE_TYPE                      =  "NON_S80",
   XPHYIO_MC_ODTLon                          =  "0",
   XPHYIO_MC_F1_ODTLon                          =  "0",
   XPHYIO_MC_TODTon_MIN                      =  "0",
   XPHYIO_MC_F1_TODTon_MIN                      =  "0",
   XPHYIO_MC_XPLL_MODE                       =  "VarRxVarTx",
   XPHYIO_MC_XPLL_CLKOUT1_PH_CTRL            =  "0x3",
   XPHYIO_MC_XPLL_CLKOUT2_PH_CTRL            =  "0x1",
   XPHYIO_MC_XPLL_DSKW_DLY1                  =  12,
   XPHYIO_MC_XPLL_DSKW_DLY2                  =  15,
   XPHYIO_MC_XPLL_DSKW_DLY_EN1               =  "TRUE",
   XPHYIO_MC_XPLL_DSKW_DLY_EN2               =  "TRUE",
   XPHYIO_MC_XPLL_DSKW_DLY_PATH1             =  "FALSE",
   XPHYIO_MC_XPLL_DSKW_DLY_PATH2             =  "TRUE",
   XPHYIO_MC_XPLL_CLKOUT1_PHASE              =  236.25,
   XPHYIO_MC_XPLL_CLKOUT2_PHASE              =  0.0,
   XPHYIO_MC_XPLL_CLKOUT1_PERIOD             =  1250,
   XPHYIO_MC_XPLL_DIV4_CLKOUT12              =  "TRUE",
   XPHYIO_MC_XPLL_DIV4_CLKOUT3               =  "TRUE",
   XPHYIO_MC_XPLL_CLKOUTPHY_CASCIN_EN        =  "TRUE",
   XPHYIO_MC_XPLL_CLKOUTPHY_CASCOUT_EN        =  "FALSE",
   XPHYIO_MC_XPLL_DESKEW_MUXIN_SEL           =  "TRUE",
   XPHYIO_MC_XPLL_DESKEW2_MUXIN_SEL           =  "TRUE",
   XPHYIO_MC_LP4_OPERATING_TEMP              =  "STANDARD",
   XPHYIO_MC_CONFIG_NUM                      =  "config11",
   XPHYIO_MC_SIM_DEVICE                      =  "VERSAL_AI_CORE_ES1",
   XPHYIO_MC_DDR4_CTLE                       =  "000",
   XPHYIO_MC_ECC_SCRUB_SIZE                  =  8192,
   XPHYIO_MC_XLNX_RESPONDER                  =  "true",
   XPHYIO_MC_NETLIST_SIMULATION              =  "false",
   XPHYIO_MC_DDR4_MIGRATION                  =  "false",
   XPHYIO_MC_CH0_DDR4_CK_SKEW_0              =  0,
   XPHYIO_MC_CH0_DDR4_CK_SKEW_1              =  0,
   XPHYIO_MC_CH0_DDR4_CK_SKEW_2              =  0,
   XPHYIO_MC_CH0_DDR4_CK_SKEW_3              =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_0            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_1            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_2            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_3            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_4            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_5            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_6            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_7            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_8            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_9            =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_10           =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_11           =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_12           =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_13           =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_14           =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_15           =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_16           =  0,
   XPHYIO_MC_CH0_DDR4_ADDR_SKEW_17           =  0,
   XPHYIO_MC_CH0_DDR4_BA_SKEW_0              =  0,
   XPHYIO_MC_CH0_DDR4_BA_SKEW_1              =  0,
   XPHYIO_MC_CH0_DDR4_BG_SKEW_0              =  0,
   XPHYIO_MC_CH0_DDR4_BG_SKEW_1              =  0,
   XPHYIO_MC_CH0_DDR4_CS_SKEW_0              =  0,
   XPHYIO_MC_CH0_DDR4_CS_SKEW_1              =  0,
   XPHYIO_MC_CH0_DDR4_CS_SKEW_2              =  0,
   XPHYIO_MC_CH0_DDR4_CS_SKEW_3              =  0,
   XPHYIO_MC_CH0_DDR4_CKE_SKEW_0             =  0,
   XPHYIO_MC_CH0_DDR4_CKE_SKEW_1             =  0,
   XPHYIO_MC_CH0_DDR4_CKE_SKEW_2             =  0,
   XPHYIO_MC_CH0_DDR4_CKE_SKEW_3             =  0,
   XPHYIO_MC_CH0_DDR4_ACT_SKEW               =  0,
   XPHYIO_MC_CH0_DDR4_PAR_SKEW               =  0,
   XPHYIO_MC_CH0_DDR4_ODT_SKEW_0             =  0,
   XPHYIO_MC_CH0_DDR4_ODT_SKEW_1             =  0,
   XPHYIO_MC_CH0_DDR4_ODT_SKEW_2             =  0,
   XPHYIO_MC_CH0_DDR4_ODT_SKEW_3             =  0,
   XPHYIO_MC_CH0_DDR4_LR_SKEW_0             =  0,
   XPHYIO_MC_CH0_DDR4_LR_SKEW_1             =  0,
   XPHYIO_MC_CH0_DDR4_LR_SKEW_2             =  0,
   XPHYIO_MC_CH1_DDR4_CK_SKEW_0              =  0,
   XPHYIO_MC_CH1_DDR4_CK_SKEW_1              =  0,
   XPHYIO_MC_CH1_DDR4_CK_SKEW_2              =  0,
   XPHYIO_MC_CH1_DDR4_CK_SKEW_3              =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_0            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_1            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_2            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_3            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_4            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_5            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_6            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_7            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_8            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_9            =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_10           =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_11           =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_12           =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_13           =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_14           =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_15           =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_16           =  0,
   XPHYIO_MC_CH1_DDR4_ADDR_SKEW_17           =  0,
   XPHYIO_MC_CH1_DDR4_BA_SKEW_0              =  0,
   XPHYIO_MC_CH1_DDR4_BA_SKEW_1              =  0,
   XPHYIO_MC_CH1_DDR4_BG_SKEW_0              =  0,
   XPHYIO_MC_CH1_DDR4_BG_SKEW_1              =  0,
   XPHYIO_MC_CH1_DDR4_CS_SKEW_0              =  0,
   XPHYIO_MC_CH1_DDR4_CS_SKEW_1              =  0,
   XPHYIO_MC_CH1_DDR4_CS_SKEW_2              =  0,
   XPHYIO_MC_CH1_DDR4_CS_SKEW_3              =  0,
   XPHYIO_MC_CH1_DDR4_CKE_SKEW_0             =  0,
   XPHYIO_MC_CH1_DDR4_CKE_SKEW_1             =  0,
   XPHYIO_MC_CH1_DDR4_CKE_SKEW_2             =  0,
   XPHYIO_MC_CH1_DDR4_CKE_SKEW_3             =  0,
   XPHYIO_MC_CH1_DDR4_ACT_SKEW               =  0,
   XPHYIO_MC_CH1_DDR4_PAR_SKEW               =  0,
   XPHYIO_MC_CH1_DDR4_ODT_SKEW_0             =  0,
   XPHYIO_MC_CH1_DDR4_ODT_SKEW_1             =  0,
   XPHYIO_MC_CH1_DDR4_ODT_SKEW_2             =  0,
   XPHYIO_MC_CH1_DDR4_ODT_SKEW_3             =  0,
   XPHYIO_MC_CH1_DDR4_LR_SKEW_0              =  0,
   XPHYIO_MC_CH1_DDR4_LR_SKEW_1              =  0,
   XPHYIO_MC_CH1_DDR4_LR_SKEW_2              =  0,


   XPHYIO_MC_FREQ_SWITCHING_EN                 = "FALSE",
   XPHYIO_MC_FREQ_PARAM                        = "F0",
   XPHYIO_MC_IP_TIMEPERIOD1                    =  625, 
   XPHYIO_MC_OP_TIMEPERIOD1                    =  625,
   XPHYIO_MC_F1_CASLATENCY                     =  24,
   XPHYIO_MC_F1_CASWRITELATENCY                =  20,
   XPHYIO_MC_F1_TFAW                           =  30000,
   XPHYIO_MC_F1_TFAW_nCK                       =  0,
   XPHYIO_MC_F1_TRRD_S                         =  9,
   XPHYIO_MC_F1_TRRD_L                         =  11,
   XPHYIO_MC_F1_TRTP                           =  7500,
   XPHYIO_MC_F1_TRTP_nCK                       =  0,
   XPHYIO_MC_F1_TWTR_S                         =  2500,
   XPHYIO_MC_F1_TWTR_L                         =  7500,
   XPHYIO_MC_F1_TCCD_L                         =  8,
   XPHYIO_MC_F1_TCCD_3DS                       =  0,
   XPHYIO_MC_F1_TMOD                           =  24,
   XPHYIO_MC_F1_TCKE                           =  0,
   XPHYIO_MC_F1_TXP                            =  0,
   XPHYIO_MC_F1_TMRD                           =  8,
   XPHYIO_MC_F1_TMRD_nCK                       =  0,
   XPHYIO_MC_F1_TRAS                           =  32000,
   XPHYIO_MC_F1_TRAS_nCK                       =  0,
   XPHYIO_MC_F1_TRCD                           =  13750,
   XPHYIO_MC_F1_TRCD_nCK                       =  0,
   XPHYIO_MC_F1_TRPAB                          =  0,
   XPHYIO_MC_F1_TRPAB_nCK                      =  0,
   XPHYIO_MC_F1_TRPPB                          =  0,
   XPHYIO_MC_F1_TRPPB_nCK                      =  0,
   XPHYIO_MC_F1_TRRD                           =  0,
   XPHYIO_MC_F1_TRRD_nCK                    =  0,
   XPHYIO_MC_F1_TWR                            =  15000,
   XPHYIO_MC_F1_TWR_nCK                        =  0,
   XPHYIO_MC_F1_TWTR                           =  0,
   XPHYIO_MC_F1_TWTR_nCK                       =  0,
   XPHYIO_MC_F1_TZQLAT                         =  0,
   XPHYIO_MC_F1_TZQLAT_nCK                     =  0,
   XPHYIO_MC_F1_TMRW                           =  0,
   XPHYIO_MC_F1_TOSCO                          =  0,
   XPHYIO_MC_F1_TOSCO_nCK                      =  0,
   XPHYIO_MC_SILICON_REVISION                  =  "NA",
   XPHYIO_MC_UBLAZE_APB_INTF                   =  "FALSE",
   XPHYIO_MC_REF_AND_PER_CAL_INTF              =  "FALSE",
   XPHYIO_MC_F1_LPDDR4_MR1                     = "0x0000",
   XPHYIO_MC_F1_LPDDR4_MR2                     = "0x0000",
   XPHYIO_MC_F1_LPDDR4_MR3                     = "0x0000",
   XPHYIO_MC_F1_LPDDR4_MR11                    = "0x0000",
   XPHYIO_MC_F1_LPDDR4_MR13                    = "0x0000",
   XPHYIO_MC_F1_LPDDR4_MR22                    = "0x0000",
   XPHYIO_MC_DDR_INIT_TIMEOUT                  = "0x00079C3E",
   XPHYIO_NUM_MC                               = "1",
   XPHYIO_USER_NPI_REG_MC_NSU_0_ING         = "0x04534101",
   XPHYIO_USER_NPI_REG_MC_NSU_0_EGR         = "0x00473610",
   XPHYIO_USER_NPI_REG_MC_NSU_0_R_EGR       = "0x01010100",
   XPHYIO_USER_NPI_REG_MC_NSU_0_W_EGR       = "0x00010100",
   XPHYIO_USER_NPI_REG_MC_NSU_1_ING         = "0x04534101",
   XPHYIO_USER_NPI_REG_MC_NSU_1_EGR         = "0x00473610",
   XPHYIO_USER_NPI_REG_MC_NSU_1_R_EGR       = "0x01010100",
   XPHYIO_USER_NPI_REG_MC_NSU_1_W_EGR       = "0x00010100",
   XPHYIO_USER_NPI_REG_MC_NSU_2_ING         = "0x04534101",
   XPHYIO_USER_NPI_REG_MC_NSU_2_EGR         = "0x00473610",
   XPHYIO_USER_NPI_REG_MC_NSU_2_R_EGR       = "0x01010100",
   XPHYIO_USER_NPI_REG_MC_NSU_2_W_EGR       = "0x00010100",
   XPHYIO_USER_NPI_REG_MC_NSU_3_ING         = "0x04534101",
   XPHYIO_USER_NPI_REG_MC_NSU_3_EGR         = "0x00473610",
   XPHYIO_USER_NPI_REG_MC_NSU_3_R_EGR       = "0x01010100",
   XPHYIO_USER_NPI_REG_MC_NSU_3_W_EGR       = "0x00010100",
   XPHYIO_MC_REG_RD_DRR_TKN_P0              = "0x00ff0404", 
   XPHYIO_MC_REG_RD_DRR_TKN_P1              = "0x002b0404", 
   XPHYIO_MC_REG_RD_DRR_TKN_P2              = "0x00550404",
   XPHYIO_MC_REG_RD_DRR_TKN_P3              = "0x00550404",
   XPHYIO_MC_REG_WR_DRR_TKN_P0              = "0x0000ff04", 
   XPHYIO_MC_REG_WR_DRR_TKN_P1              = "0x00002b04", 
   XPHYIO_MC_REG_WR_DRR_TKN_P2              = "0x00005504",
   XPHYIO_MC_REG_WR_DRR_TKN_P3              = "0x00005504",
   XPHYIO_MC_REG_QOS0                       = "0x001e01e0",
   XPHYIO_MC_REG_QOS1                       = "0x0ff00804",
   XPHYIO_MC_REG_QOS2                       = "0x0003fc02",
   XPHYIO_MC_REG_QOS_TIMEOUT0               = "0x00421084",
   XPHYIO_MC_REG_QOS_TIMEOUT1               = "0xb4b4b4b4",
   XPHYIO_MC_REG_QOS_TIMEOUT2               = "0x000000b4",
   XPHYIO_MC_REG_RATE_CTRL_SCALE            = "0x00000000",
   XPHYIO_MC_REG_P0_LLR_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P0_ISR_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P0_BER_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P0_ISW_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P0_BEW_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P1_LLR_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P1_ISR_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P1_BER_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P1_ISW_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P1_BEW_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P2_LLR_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P2_ISR_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P2_BER_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P2_ISW_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P2_BEW_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P3_LLR_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P3_ISR_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P3_BER_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P3_ISW_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_P3_BEW_RATE_CTRL           = "0x003ffc0f",
   XPHYIO_MC_REG_CMDQ_CTRL0                 = "0x01ffffff",
   XPHYIO_MC_REG_CMDQ_CTRL1                 = "0x01084210",
   XPHYIO_MC_REG_CMDQ_LLR_RATE_CTRL         = "0x003ffc0f",
   XPHYIO_MC_REG_CMDQ_ISR_RATE_CTRL         = "0x003ffc0f",
   XPHYIO_MC_REG_CMDQ_BER_RATE_CTRL         = "0x003ffc0f",
   XPHYIO_MC_REG_CMDQ_ISW_RATE_CTRL         = "0x003ffc0f",
   XPHYIO_MC_REG_CMDQ_BEW_RATE_CTRL         = "0x003ffc0f",
   XPHYIO_MC_REG_QOS_RATE_CTRL_SCALE        = "0x00000000",
   XPHYIO_MC_DC_CMD_CREDITS                 = "0x000002a8",
   XPHYIO_MC_EXMON_CLR_EXE                  = "0x00000100",
   XPHYIO_MC_XMPU_CTRL                      = "0x0000000b",
   XPHYIO_MC_XMPU_START_LO0                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI0                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO0                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI0                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER0                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG0                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO1                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI1                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO1                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI1                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER1                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG1                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO2                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI2                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO2                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI2                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER2                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG2                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO3                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI3                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO3                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI3                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER3                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG3                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO4                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI4                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO4                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI4                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER4                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG4                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO5                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI5                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO5                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI5                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER5                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG5                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO6                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI6                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO6                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI6                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER6                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG6                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO7                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI7                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO7                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI7                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER7                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG7                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO8                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI8                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO8                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI8                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER8                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG8                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO9                 = "0x00000000",
   XPHYIO_MC_XMPU_START_HI9                 = "0x00000000",
   XPHYIO_MC_XMPU_END_LO9                   = "0x00000000",
   XPHYIO_MC_XMPU_END_HI9                   = "0x00000000",
   XPHYIO_MC_XMPU_MASTER9                   = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG9                   = "0x00000008",
   XPHYIO_MC_XMPU_START_LO10                = "0x00000000",
   XPHYIO_MC_XMPU_START_HI10                = "0x00000000",
   XPHYIO_MC_XMPU_END_LO10                  = "0x00000000",
   XPHYIO_MC_XMPU_END_HI10                  = "0x00000000",
   XPHYIO_MC_XMPU_MASTER10                  = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG10                  = "0x00000008",
   XPHYIO_MC_XMPU_START_LO11                = "0x00000000",
   XPHYIO_MC_XMPU_START_HI11                = "0x00000000",
   XPHYIO_MC_XMPU_END_LO11                  = "0x00000000",
   XPHYIO_MC_XMPU_END_HI11                  = "0x00000000",
   XPHYIO_MC_XMPU_MASTER11                  = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG11                  = "0x00000008",
   XPHYIO_MC_XMPU_START_LO12                = "0x00000000",
   XPHYIO_MC_XMPU_START_HI12                = "0x00000000",
   XPHYIO_MC_XMPU_END_LO12                  = "0x00000000",
   XPHYIO_MC_XMPU_END_HI12                  = "0x00000000",
   XPHYIO_MC_XMPU_MASTER12                  = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG12                  = "0x00000008",
   XPHYIO_MC_XMPU_START_LO13                = "0x00000000",
   XPHYIO_MC_XMPU_START_HI13                = "0x00000000",
   XPHYIO_MC_XMPU_END_LO13                  = "0x00000000",
   XPHYIO_MC_XMPU_END_HI13                  = "0x00000000",
   XPHYIO_MC_XMPU_MASTER13                  = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG13                  = "0x00000008",
   XPHYIO_MC_XMPU_START_LO14                = "0x00000000",
   XPHYIO_MC_XMPU_START_HI14                = "0x00000000",
   XPHYIO_MC_XMPU_END_LO14                  = "0x00000000",
   XPHYIO_MC_XMPU_END_HI14                  = "0x00000000",
   XPHYIO_MC_XMPU_MASTER14                  = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG14                  = "0x00000008",
   XPHYIO_MC_XMPU_START_LO15                = "0x00000000",
   XPHYIO_MC_XMPU_START_HI15                = "0x00000000",
   XPHYIO_MC_XMPU_END_LO15                  = "0x00000000",
   XPHYIO_MC_XMPU_END_HI15                  = "0x00000000",
   XPHYIO_MC_XMPU_MASTER15                  = "0x00000000",
   XPHYIO_MC_XMPU_CONFIG15                  = "0x00000008",
   XPHYIO_MC_REG_ADEC0                      = "0x00000000",
   XPHYIO_MC_REG_ADEC1                      = "0x00000000",
   XPHYIO_MC_REG_ADEC2                      = "0x00100080",
   XPHYIO_MC_REG_ADEC3                      = "0x00000078",
   XPHYIO_MC_REG_NSU0_PORT                  = "0x000001c0",
   XPHYIO_MC_REG_NSU1_PORT                  = "0x00000200",
   XPHYIO_MC_REG_NSU2_PORT                  = "0x00000240",
   XPHYIO_MC_REG_NSU3_PORT                  = "0x00000280",
   XPHYIO_MC_UB_CLK_MUX                     = "0x00000000",
   XPHYIO_MC_DDR4_ADDR_BIT                  = "RA16,RA15,RA14,RA13,RA12,RA11,RA10,RA9,RA8,RA7,RA6,RA5,RA4,RA3,RA2,RA1,RA0,BA1,BA0,CA9,CA8,CA7,CA6,CA5,CA4,CA3,BG0,CA2,CA1,CA0,NC,NC,NC",
   XPHYIO_MC_PIN_ARGS                       = "CONTROLLERTYPE DDR4_SDRAM MC_DQ_WIDTH 64 MC_DQS_WIDTH 8 MC_DM_WIDTH 8 MC_ADDR_WIDTH 17 MC_BG_WIDTH 1 MC_BA_WIDTH 2 MC_CKE_WIDTH 1 MC_CK_WIDTH 1 MC_CS_WIDTH 1 MC_STACKHEIGHT 1 MC_LR_WIDTH 1 MC_ODT_WIDTH 1 MC_COMPONENT_WIDTH x16 MC_MEMORY_DEVICETYPE Components MC_NO_CHANNELS Single MC_RANK 1 MC_SLOT Single MC_NUM_CK 1 MC_LP4_PIN_EFFICIENT false MC_CH0_LP4_CHA_ENABLE false MC_CH0_LP4_CHB_ENABLE false MC_CH1_LP4_CHA_ENABLE false MC_CH1_LP4_CHB_ENABLE false MC_LP4_DQ_A_WIDTH 0 MC_LP4_DQ_B_WIDTH 0 MC_LP4_DQS_A_WIDTH 0 MC_LP4_DQS_B_WIDTH 0 MC_LP4_DMI_A_WIDTH 0 MC_LP4_DMI_B_WIDTH 0 MC_LP4_CA_A_WIDTH 0 MC_LP4_CA_B_WIDTH 0 MC_LP4_CKT_A_WIDTH 0 MC_LP4_CKT_B_WIDTH 0 MC_LP4_CKE_A_WIDTH 0 MC_LP4_CKE_B_WIDTH 0 MC_LP4_CS_A_WIDTH 0 MC_LP4_CS_B_WIDTH 0 MC_LP4_RESETN_WIDTH 0 MC_PARITY false MC_WRITE_DM_DBI DM_NO_DBI MC_READ_DBI false MC_SYSTEM_CLOCK Differential MC_CONFIG_NUM config11",
   XPHYIO_MC_F0_MR0                         = "0x0000D50",  
   XPHYIO_MC_F0_MR1                         = "0x0000301",  
   XPHYIO_MC_F0_MR2                         = "0x00000E8",  
   XPHYIO_MC_F0_MR3                         = "0x0000020",  
   XPHYIO_MC_F0_MR4                         = "0x0000000",  
   XPHYIO_MC_F0_MR5                         = "0x0000400",  
   XPHYIO_MC_F0_MR6                         = "0x0001014",
   XPHYIO_MC_F1_MR0                         = "0x0000000",  
   XPHYIO_MC_F1_MR1                         = "0x0000000",  
   XPHYIO_MC_F1_MR2                         = "0x0000000",  
   XPHYIO_MC_F1_MR3                         = "0x0000020",  
   XPHYIO_MC_F1_MR4                         = "0x0000000",  
   XPHYIO_MC_F1_MR5                         = "0x0000000",  
   XPHYIO_MC_F1_MR6                         = "0x0000000",
   XPHYIO_MC_REG_RC00                       = "0x0000",
   XPHYIO_MC_REG_RC01                       = "0x0000",
   XPHYIO_MC_REG_RC02                       = "0x0000",
   XPHYIO_MC_REG_RC03                       = "0x0000",
   XPHYIO_MC_REG_RC03_F1                    = "0x0000",
   XPHYIO_MC_REG_RC04                       = "0x0000",
   XPHYIO_MC_REG_RC04_F1                    = "0x0000",
   XPHYIO_MC_REG_RC05                       = "0x0000",
   XPHYIO_MC_REG_RC05_F1                    = "0x0000",
   XPHYIO_MC_REG_RC08                       = "0x0000",
   XPHYIO_MC_REG_RC0A                       = "0x0000",
   XPHYIO_MC_REG_RC0A_F1                    = "0x0000",
   XPHYIO_MC_REG_RC0B                       = "0x0000",
   XPHYIO_MC_REG_RC0D                       = "0x0000",
   XPHYIO_MC_REG_RC0E                       = "0x0000",
   XPHYIO_MC_REG_RC0F                       = "0x0000",
   XPHYIO_MC_REG_RC0F_F1                    = "0x0000",
   XPHYIO_MC_REG_RC2X                       = "0x0000",
   XPHYIO_MC_REG_RC3X                       = "0x0000",
   XPHYIO_MC_REG_RC3X_F1                    = "0x0000",
   XPHYIO_MC_REG_RC5X                       = "0x0000",
   XPHYIO_MC_REG_RC5X_F1                    = "0x0000",
   XPHYIO_MC_REG_RC8X                       = "0x0000",
   XPHYIO_MC_REG_RC8X_F1                    = "0x0000",
   XPHYIO_MC_DB_F0BC00                      = "0x0000",
   XPHYIO_MC_DB_F0BC01                      = "0x0000",
   XPHYIO_MC_DB_F0BC02                      = "0x0000",
   XPHYIO_MC_DB_F0BC03                      = "0x0000",
   XPHYIO_MC_DB_F0BC04                      = "0x0000",
   XPHYIO_MC_DB_F0BC05                      = "0x0000",
   XPHYIO_MC_DB_F0BC06                      = "0x0000",
   XPHYIO_MC_DB_F0BC0A                      = "0x0000",
   XPHYIO_MC_DB_F1BC0A                      = "0x0000",
   XPHYIO_MC_DB_F5BC5X                      = "0x0000",
   XPHYIO_MC_DB_F0BC6X                      = "0x0000",
   XPHYIO_MC_DB_F1BC6X                      = "0x0000",
   XPHYIO_MC_DB_F5BC6X                      = "0x0000",
   XPHYIO_MC_DB_FXBC7X_F6                   = "0x0000",
   XPHYIO_MC_DB_F6BC4X                      = "0x0000",
   XPHYIO_MC_DB_FXBC7X_F5                   = "0x0000",
   XPHYIO_MC_DB_FXBC7X_F0                   = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR1                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR2                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR3                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR11                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR12                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR13                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR14                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR15                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR16                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR17                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR20                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR22                  = "0x0000",
   XPHYIO_MC_F0_LPDDR4_MR23                  = "0x0000",
   XPHYIO_MC_NOC_FREQ                        = 960,
   XPHYIO_MC_IBUFDISABLE                     = "false",
   XPHYIO_MC_INIT_DONE_SIG_EN                = "false",
   XPHYIO_MC_MIN_VLD_CNT_CTRL                = "false",
   XPHYIO_MC_CAL_MASK_POLL                   = "ENABLE",

   XPHYIO_MC_CH0_LP4_CK_A_SKEW_0             = "0",                 
   XPHYIO_MC_CH0_LP4_CK_A_SKEW_1             = "0",                 
   XPHYIO_MC_CH0_LP4_CK_A_SKEW_2             = "0",                 
   XPHYIO_MC_CH0_LP4_CK_A_SKEW_3             = "0",                 
   XPHYIO_MC_CH0_LP4_CK_B_SKEW_0             = "0",                 
   XPHYIO_MC_CH0_LP4_CK_B_SKEW_1             = "0",                 
   XPHYIO_MC_CH0_LP4_CK_B_SKEW_2             = "0",                 
   XPHYIO_MC_CH0_LP4_CK_B_SKEW_3             = "0",                 

   XPHYIO_MC_CH0_LP4_CKE_A_SKEW_0            = "0",         
   XPHYIO_MC_CH0_LP4_CKE_A_SKEW_1            = "0",         
   XPHYIO_MC_CH0_LP4_CKE_A_SKEW_2            = "0",         
   XPHYIO_MC_CH0_LP4_CKE_A_SKEW_3            = "0",         
   XPHYIO_MC_CH0_LP4_CKE_B_SKEW_0            = "0",         
   XPHYIO_MC_CH0_LP4_CKE_B_SKEW_1            = "0",         
   XPHYIO_MC_CH0_LP4_CKE_B_SKEW_2            = "0",         
   XPHYIO_MC_CH0_LP4_CKE_B_SKEW_3            = "0", 
        
   XPHYIO_MC_CH0_LP4_CS_A_SKEW_0             = "0",
   XPHYIO_MC_CH0_LP4_CS_A_SKEW_1             = "0",
   XPHYIO_MC_CH0_LP4_CS_A_SKEW_2             = "0",
   XPHYIO_MC_CH0_LP4_CS_A_SKEW_3             = "0",
   XPHYIO_MC_CH0_LP4_CS_B_SKEW_0             = "0",
   XPHYIO_MC_CH0_LP4_CS_B_SKEW_1             = "0",
   XPHYIO_MC_CH0_LP4_CS_B_SKEW_2             = "0",
   XPHYIO_MC_CH0_LP4_CS_B_SKEW_3             = "0",

   XPHYIO_MC_CH1_LP4_CK_A_SKEW_0             = "0", 
   XPHYIO_MC_CH1_LP4_CK_A_SKEW_1             = "0", 
   XPHYIO_MC_CH1_LP4_CK_A_SKEW_2             = "0", 
   XPHYIO_MC_CH1_LP4_CK_A_SKEW_3             = "0", 
   XPHYIO_MC_CH1_LP4_CK_B_SKEW_0             = "0", 
   XPHYIO_MC_CH1_LP4_CK_B_SKEW_1             = "0", 
   XPHYIO_MC_CH1_LP4_CK_B_SKEW_2             = "0", 
   XPHYIO_MC_CH1_LP4_CK_B_SKEW_3             = "0",
 
   XPHYIO_MC_CH1_LP4_CKE_A_SKEW_0            = "0",                
   XPHYIO_MC_CH1_LP4_CKE_A_SKEW_1            = "0",                
   XPHYIO_MC_CH1_LP4_CKE_A_SKEW_2            = "0",                
   XPHYIO_MC_CH1_LP4_CKE_A_SKEW_3            = "0",                
   XPHYIO_MC_CH1_LP4_CKE_B_SKEW_0            = "0",                
   XPHYIO_MC_CH1_LP4_CKE_B_SKEW_1            = "0",                
   XPHYIO_MC_CH1_LP4_CKE_B_SKEW_2            = "0",                
   XPHYIO_MC_CH1_LP4_CKE_B_SKEW_3            = "0",   
             
   XPHYIO_MC_CH1_LP4_CS_A_SKEW_0             = "0",
   XPHYIO_MC_CH1_LP4_CS_A_SKEW_1             = "0",
   XPHYIO_MC_CH1_LP4_CS_A_SKEW_2             = "0",
   XPHYIO_MC_CH1_LP4_CS_A_SKEW_3             = "0",
   XPHYIO_MC_CH1_LP4_CS_B_SKEW_0             = "0",
   XPHYIO_MC_CH1_LP4_CS_B_SKEW_1             = "0",
   XPHYIO_MC_CH1_LP4_CS_B_SKEW_2             = "0",
   XPHYIO_MC_CH1_LP4_CS_B_SKEW_3             = "0",
   XPHYIO_MC_PIN_LOC                         = "None"

*)

module bd_b77b_MC0_ddrc_0_wrapper #(
                        parameter NPI_REG_DDRMC_NSU_0_ING   = 32'h0113_2400
                       ,parameter NPI_REG_DDRMC_NSU_0_EGR   = 32'h0013_4012
                       ,parameter NPI_REG_DDRMC_NSU_0_R_EGR = 32'h0_FF_FF_FF_0
                       ,parameter NPI_REG_DDRMC_NSU_0_W_EGR = 32'h0_FF_FF_FF_0
                       ,parameter NPI_REG_DDRMC_NSU_1_ING   = 32'h0113_2400
                       ,parameter NPI_REG_DDRMC_NSU_1_EGR   = 32'h0013_4012
                       ,parameter NPI_REG_DDRMC_NSU_1_R_EGR = 32'h0_FF_FF_FF_0
                       ,parameter NPI_REG_DDRMC_NSU_1_W_EGR = 32'h0_FF_FF_FF_0
                       ,parameter NPI_REG_DDRMC_NSU_2_ING   = 32'h0113_2400
                       ,parameter NPI_REG_DDRMC_NSU_2_EGR   = 32'h0013_4012
                       ,parameter NPI_REG_DDRMC_NSU_2_R_EGR = 32'h0_FF_FF_FF_0
                       ,parameter NPI_REG_DDRMC_NSU_2_W_EGR = 32'h0_FF_FF_FF_0
                       ,parameter NPI_REG_DDRMC_NSU_3_ING   = 32'h0113_2400
                       ,parameter NPI_REG_DDRMC_NSU_3_EGR   = 32'h0013_4012
                       ,parameter NPI_REG_DDRMC_NSU_3_R_EGR = 32'h0_FF_FF_FF_0
                       ,parameter NPI_REG_DDRMC_NSU_3_W_EGR = 32'h0_FF_FF_FF_0
                       ,parameter REG_RD_DRR_TKN_P0         = 32'h00040404
                       ,parameter REG_RD_DRR_TKN_P1         = 32'h00040404
                       ,parameter REG_RD_DRR_TKN_P2         = 32'h00040404
                       ,parameter REG_RD_DRR_TKN_P3         = 32'h00040404
                       ,parameter REG_WR_DRR_TKN_P0         = 32'h00000404
                       ,parameter REG_WR_DRR_TKN_P1         = 32'h00000404
                       ,parameter REG_WR_DRR_TKN_P2         = 32'h00000404
                       ,parameter REG_WR_DRR_TKN_P3         = 32'h00000404
                       ,parameter REG_QOS0                  = 32'h0_00F_00F_1 
                       ,parameter REG_QOS1                  = 32'b00_0000010000_0000010000_0000010000 
                       ,parameter REG_QOS2                  = 32'b000000000000_0000010000_0000010000 
                       ,parameter REG_QOS_TIMEOUT0          = 32'b0000000_00111_00111_00111_00111_00111
                       ,parameter REG_QOS_TIMEOUT1          = 32'b00111111_00111111_00111111_00111111
                       ,parameter REG_QOS_TIMEOUT2          = 32'b00000000_00000000_00000000_00111111
                       ,parameter REG_RATE_CTRL_SCALE       = 32'b00000000_01000_01000_01000_01000_01000
                       ,parameter REG_P0_LLR_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P0_ISR_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P0_BER_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P0_ISW_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P0_BEW_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P1_LLR_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P1_ISR_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P1_BER_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P1_ISW_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P1_BEW_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P2_LLR_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P2_ISR_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P2_BER_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P2_ISW_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P2_BEW_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P3_LLR_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P3_ISR_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P3_BER_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P3_ISW_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_P3_BEW_RATE_CTRL      = 32'h0_3FF_C0F
                       ,parameter REG_CMDQ_CTRL0            = 32'b0000000_10000_10000_10000_10000_10000
                       ,parameter REG_CMDQ_CTRL1            = 32'b0000000_10000_10000_10000_10000_10000
                       ,parameter REG_CMDQ_LLR_RATE_CTRL    = 32'h0_3FF_C0F
                       ,parameter REG_CMDQ_ISR_RATE_CTRL    = 32'h0_3FF_C0F
                       ,parameter REG_CMDQ_BER_RATE_CTRL    = 32'h0_3FF_C0F
                       ,parameter REG_CMDQ_ISW_RATE_CTRL    = 32'h0_3FF_C0F
                       ,parameter REG_CMDQ_BEW_RATE_CTRL    = 32'h0_3FF_C0F
                       ,parameter REG_QOS_RATE_CTRL_SCALE   = 32'h0000_0000
                       ,parameter DC_CMD_CREDITS            = 32'h0000_02A8
                       ,parameter EXMON_CLR_EXE             = 32'h0000_0100
                       ,parameter XMPU_CTRL                 = 32'h0000_000B
                       ,parameter XMPU_START_LO0            = 32'h0000_0000
                       ,parameter XMPU_START_HI0            = 32'h0000_0000
                       ,parameter XMPU_END_LO0              = 32'h0000_0000
                       ,parameter XMPU_END_HI0              = 32'h0000_0000
                       ,parameter XMPU_MASTER0              = 32'h0000_0000
                       ,parameter XMPU_CONFIG0              = 32'h0000_0008
                       ,parameter XMPU_START_LO1            = 32'h0000_0000
                       ,parameter XMPU_START_HI1            = 32'h0000_0000
                       ,parameter XMPU_END_LO1              = 32'h0000_0000
                       ,parameter XMPU_END_HI1              = 32'h0000_0000
                       ,parameter XMPU_MASTER1              = 32'h0000_0000
                       ,parameter XMPU_CONFIG1              = 32'h0000_0008
                       ,parameter XMPU_START_LO2            = 32'h0000_0000
                       ,parameter XMPU_START_HI2            = 32'h0000_0000
                       ,parameter XMPU_END_LO2              = 32'h0000_0000
                       ,parameter XMPU_END_HI2              = 32'h0000_0000
                       ,parameter XMPU_MASTER2              = 32'h0000_0000
                       ,parameter XMPU_CONFIG2              = 32'h0000_0008
                       ,parameter XMPU_START_LO3            = 32'h0000_0000
                       ,parameter XMPU_START_HI3            = 32'h0000_0000
                       ,parameter XMPU_END_LO3              = 32'h0000_0000
                       ,parameter XMPU_END_HI3              = 32'h0000_0000
                       ,parameter XMPU_MASTER3              = 32'h0000_0000
                       ,parameter XMPU_CONFIG3              = 32'h0000_0008
                       ,parameter XMPU_START_LO4            = 32'h0000_0000
                       ,parameter XMPU_START_HI4            = 32'h0000_0000
                       ,parameter XMPU_END_LO4              = 32'h0000_0000
                       ,parameter XMPU_END_HI4              = 32'h0000_0000
                       ,parameter XMPU_MASTER4              = 32'h0000_0000
                       ,parameter XMPU_CONFIG4              = 32'h0000_0008
                       ,parameter XMPU_START_LO5            = 32'h0000_0000
                       ,parameter XMPU_START_HI5            = 32'h0000_0000
                       ,parameter XMPU_END_LO5              = 32'h0000_0000
                       ,parameter XMPU_END_HI5              = 32'h0000_0000
                       ,parameter XMPU_MASTER5              = 32'h0000_0000
                       ,parameter XMPU_CONFIG5              = 32'h0000_0008
                       ,parameter XMPU_START_LO6            = 32'h0000_0000
                       ,parameter XMPU_START_HI6            = 32'h0000_0000
                       ,parameter XMPU_END_LO6              = 32'h0000_0000
                       ,parameter XMPU_END_HI6              = 32'h0000_0000
                       ,parameter XMPU_MASTER6              = 32'h0000_0000
                       ,parameter XMPU_CONFIG6              = 32'h0000_0008
                       ,parameter XMPU_START_LO7            = 32'h0000_0000
                       ,parameter XMPU_START_HI7            = 32'h0000_0000
                       ,parameter XMPU_END_LO7              = 32'h0000_0000
                       ,parameter XMPU_END_HI7              = 32'h0000_0000
                       ,parameter XMPU_MASTER7              = 32'h0000_0000
                       ,parameter XMPU_CONFIG7              = 32'h0000_0008
                       ,parameter XMPU_START_LO8            = 32'h0000_0000
                       ,parameter XMPU_START_HI8            = 32'h0000_0000
                       ,parameter XMPU_END_LO8              = 32'h0000_0000
                       ,parameter XMPU_END_HI8              = 32'h0000_0000
                       ,parameter XMPU_MASTER8              = 32'h0000_0000
                       ,parameter XMPU_CONFIG8              = 32'h0000_0008
                       ,parameter XMPU_START_LO9            = 32'h0000_0000
                       ,parameter XMPU_START_HI9            = 32'h0000_0000
                       ,parameter XMPU_END_LO9              = 32'h0000_0000
                       ,parameter XMPU_END_HI9              = 32'h0000_0000
                       ,parameter XMPU_MASTER9              = 32'h0000_0000
                       ,parameter XMPU_CONFIG9              = 32'h0000_0008
                       ,parameter XMPU_START_LO10           = 32'h0000_0000
                       ,parameter XMPU_START_HI10           = 32'h0000_0000
                       ,parameter XMPU_END_LO10             = 32'h0000_0000
                       ,parameter XMPU_END_HI10             = 32'h0000_0000
                       ,parameter XMPU_MASTER10             = 32'h0000_0000
                       ,parameter XMPU_CONFIG10             = 32'h0000_0008
                       ,parameter XMPU_START_LO11           = 32'h0000_0000
                       ,parameter XMPU_START_HI11           = 32'h0000_0000
                       ,parameter XMPU_END_LO11             = 32'h0000_0000
                       ,parameter XMPU_END_HI11             = 32'h0000_0000
                       ,parameter XMPU_MASTER11             = 32'h0000_0000
                       ,parameter XMPU_CONFIG11             = 32'h0000_0008
                       ,parameter XMPU_START_LO12           = 32'h0000_0000
                       ,parameter XMPU_START_HI12           = 32'h0000_0000
                       ,parameter XMPU_END_LO12             = 32'h0000_0000
                       ,parameter XMPU_END_HI12             = 32'h0000_0000
                       ,parameter XMPU_MASTER12             = 32'h0000_0000
                       ,parameter XMPU_CONFIG12             = 32'h0000_0008
                       ,parameter XMPU_START_LO13           = 32'h0000_0000
                       ,parameter XMPU_START_HI13           = 32'h0000_0000
                       ,parameter XMPU_END_LO13             = 32'h0000_0000
                       ,parameter XMPU_END_HI13             = 32'h0000_0000
                       ,parameter XMPU_MASTER13             = 32'h0000_0000
                       ,parameter XMPU_CONFIG13             = 32'h0000_0008
                       ,parameter XMPU_START_LO14           = 32'h0000_0000
                       ,parameter XMPU_START_HI14           = 32'h0000_0000
                       ,parameter XMPU_END_LO14             = 32'h0000_0000
                       ,parameter XMPU_END_HI14             = 32'h0000_0000
                       ,parameter XMPU_MASTER14             = 32'h0000_0000
                       ,parameter XMPU_CONFIG14             = 32'h0000_0008
                       ,parameter XMPU_START_LO15           = 32'h0000_0000
                       ,parameter XMPU_START_HI15           = 32'h0000_0000
                       ,parameter XMPU_END_LO15             = 32'h0000_0000
                       ,parameter XMPU_END_HI15             = 32'h0000_0000
                       ,parameter XMPU_MASTER15             = 32'h0000_0000
                       ,parameter XMPU_CONFIG15             = 32'h0000_0008
                       ,parameter REG_ADEC0                 = 32'b0000_0000_0000_0000_0000_0000_0000_0000 //low_mem_base 
                       ,parameter REG_ADEC1                 = 32'b0000_0000_0000_0000_0000_0000_0000_0000 //low_mem_offset
                       ,parameter REG_ADEC2                 = 32'b0000_0000_0000_0000_0010_0000_0000_0000 //high_mem_base
                       ,parameter REG_ADEC3                 = 32'b0000_0000_0000_0000_0001_0000_0000_0000 //high_mem_offset
                       ,parameter REG_NSU0_PORT             = 32'h00000000
                       ,parameter REG_NSU1_PORT             = 32'h00000000
                       ,parameter REG_NSU2_PORT             = 32'h00000000
                       ,parameter REG_NSU3_PORT             = 32'h00000000
                       ,parameter UB_CLK_MUX                = 32'h00000000
                       ,parameter TCK                       = 32'h0
                       ,parameter VERBOSITY_EN              = 32'h0
                       ,parameter bit EN_NPP_MONITOR        = 1'b0
                       ,parameter REG_PINOUT                = 32'h0
                       ,parameter NOC_FREQ                  = 960
) (
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
;output   ch0_ddr4_reset_n
;output   ch0_ddr4_act_n

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


bd_b77b_MC0_ddrc_0_phy noc_ddr4_phy (
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
