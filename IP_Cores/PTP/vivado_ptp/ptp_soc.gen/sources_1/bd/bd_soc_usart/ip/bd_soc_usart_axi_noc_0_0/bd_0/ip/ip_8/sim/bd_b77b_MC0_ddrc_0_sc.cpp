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


#include "bd_b77b_MC0_ddrc_0_sc.h"

#include "bd_b77b_MC0_ddrc_0_core.h"

#include <map>
#include <string>

bd_b77b_MC0_ddrc_0_sc::bd_b77b_MC0_ddrc_0_sc(const sc_core::sc_module_name& nm) : sc_core::sc_module(nm), mp_impl(NULL)
{
  // configure connectivity manager
  xsc::utils::xsc_sim_manager::addInstance("bd_b77b_MC0_ddrc_0", this);

  // initialize module
    xsc::common_cpp::properties model_param_props;
    model_param_props.addLong("NOC_NPP_WIDTH", "182");
    model_param_props.addLong("MC_F0_CLKFBOUT_MULT", "16");
    model_param_props.addLong("MC_F0_DIVCLK_DIVIDE", "1");
    model_param_props.addLong("MC_F0_CLKOUT0_DIVIDE", "1");
    model_param_props.addLong("MC_F0_CLKOUT1_DIVIDE", "4");
    model_param_props.addLong("MC_F0_CLKOUT2_DIVIDE", "4");
    model_param_props.addLong("MC_F0_CLKOUT3_DIVIDE", "1");
    model_param_props.addLong("MC_F1_CLKFBOUT_MULT", "16");
    model_param_props.addLong("MC_F1_DIVCLK_DIVIDE", "1");
    model_param_props.addLong("MC_F1_CLKOUT0_DIVIDE", "1");
    model_param_props.addLong("MC_F1_CLKOUT1_DIVIDE", "4");
    model_param_props.addLong("MC_F1_CLKOUT2_DIVIDE", "4");
    model_param_props.addLong("MC_F1_CLKOUT3_DIVIDE", "1");
    model_param_props.addLong("MEMORY_TIMEPERIOD0", "625");
    model_param_props.addLong("MC_NOC_FREQ", "960");
    model_param_props.addFloat("MC_INPUTCLK0_PERIOD_NS", "5.000");
    model_param_props.addFloat("MC_F0_PLL0_CLKOUT0_NS", "1.250");
    model_param_props.addFloat("MC_INPUTCLK1_PERIOD_NS", "2.5");
    model_param_props.addFloat("MC_F1_PLL0_CLKOUT0_NS", "1.25");
    model_param_props.addString("MC_PIN_PLACEMENT_ARGS", "CONTROLLERTYPE DDR4_SDRAM MC_DQ_WIDTH 64 MC_DQS_WIDTH 8 MC_DM_WIDTH 8 MC_ADDR_WIDTH 17 MC_BG_WIDTH 1 MC_BA_WIDTH 2 MC_CKE_WIDTH 1 MC_CK_WIDTH 1 MC_CS_WIDTH 1 MC_STACKHEIGHT 1 MC_LR_WIDTH 1 MC_ODT_WIDTH 1 MC_COMPONENT_WIDTH x16 MC_MEMORY_DEVICETYPE Components MC_NO_CHANNELS Single MC_RANK 1 MC_SLOT Single MC_NUM_CK 1 MC_LP4_PIN_EFFICIENT false MC_CH0_LP4_CHA_ENABLE false MC_CH0_LP4_CHB_ENABLE false MC_CH1_LP4_CHA_ENABLE false MC_CH1_LP4_CHB_ENABLE false MC_LP4_DQ_A_WIDTH 0 MC_LP4_DQ_B_WIDTH 0 MC_LP4_DQS_A_WIDTH 0 MC_LP4_DQS_B_WIDTH 0 MC_LP4_DMI_A_WIDTH 0 MC_LP4_DMI_B_WIDTH 0 MC_LP4_CA_A_WIDTH 0 MC_LP4_CA_B_WIDTH 0 MC_LP4_CKT_A_WIDTH 0 MC_LP4_CKT_B_WIDTH 0 MC_LP4_CKE_A_WIDTH 0 MC_LP4_CKE_B_WIDTH 0 MC_LP4_CS_A_WIDTH 0 MC_LP4_CS_B_WIDTH 0 MC_LP4_RESETN_WIDTH 0 MC_PARITY false MC_WRITE_DM_DBI DM_NO_DBI MC_READ_DBI false MC_SYSTEM_CLOCK Differential MC_CONFIG_NUM config11");
    model_param_props.addString("MC_DDR4_ADDR_BIT", "RA16,RA15,RA14,RA13,RA12,RA11,RA10,RA9,RA8,RA7,RA6,RA5,RA4,RA3,RA2,RA1,RA0,BA1,BA0,CA9,CA8,CA7,CA6,CA5,CA4,CA3,BG0,CA2,CA1,CA0,NC,NC,NC");
    model_param_props.addString("MC_NIBBLE_GROUP", "NONE");
    model_param_props.addString("MC_F0_CLKOUTPHY_DIVIDE", "DIV1");
    model_param_props.addString("MC_F1_CLKOUTPHY_DIVIDE", "DIV1");
    model_param_props.addString("HDL_ATTR_FILE", "nocattrs.dat");
    model_param_props.addString("HDL_COMPONENT_NAME", "bd_b77b_MC0_ddrc_0");
    model_param_props.addString("MC_SIM_DEVICE", "VERSAL_AI_CORE_ES1");
    model_param_props.addString("PHYS_NAME", "DDRMC_X0Y0");
    model_param_props.addString("MEM_INIT_FILE", "no_file_loaded");
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_0_ING", "00000100010100110100000100000001", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_0_EGR", "00000000010001110011011000010000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_0_R_EGR", "00000001000000010000000100000000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_0_W_EGR", "00000000000000010000000100000000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_1_ING", "00000100010100110100000100000001", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_1_EGR", "00000000010001110011011000010000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_1_R_EGR", "00000001000000010000000100000000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_1_W_EGR", "00000000000000010000000100000000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_2_ING", "00000100010100110100000100000001", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_2_EGR", "00000000010001110011011000010000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_2_R_EGR", "00000001000000010000000100000000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_2_W_EGR", "00000000000000010000000100000000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_3_ING", "00000100010100110100000100000001", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_3_EGR", "00000000010001110011011000010000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_3_R_EGR", "00000001000000010000000100000000", 32);
    model_param_props.addBitString("NPI_REG_DDRMC_NSU_3_W_EGR", "00000000000000010000000100000000", 32);
    model_param_props.addBitString("REG_RD_DRR_TNK_P0", "00000000000011110000111100001111", 32);
    model_param_props.addBitString("REG_WR_DRR_TNK_P0", "00000000000000000000111100001111", 32);
    model_param_props.addBitString("REG_RD_DRR_TNK_P1", "00000000000011110000111100001111", 32);
    model_param_props.addBitString("REG_WR_DRR_TNK_P1", "00000000000000000000111100001111", 32);
    model_param_props.addBitString("REG_RD_DRR_TNK_P2", "00000000000011110000111100001111", 32);
    model_param_props.addBitString("REG_WR_DRR_TNK_P2", "00000000000000000000111100001111", 32);
    model_param_props.addBitString("REG_RD_DRR_TNK_P3", "00000000000011110000111100001111", 32);
    model_param_props.addBitString("REG_WR_DRR_TNK_P3", "00000000000000000000111100001111", 32);
    model_param_props.addBitString("REG_P0_LLR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P0_ISR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P0_BER_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P0_ISW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P0_BEW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P1_LLR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P1_ISR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P1_BER_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P1_ISW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P1_BEW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P2_LLR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P2_ISR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P2_BER_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P2_ISW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P2_BEW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P3_LLR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P3_ISR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P3_BER_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P3_ISW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_P3_BEW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_CMDQ_CTRL0", "00000001000010000100001000010000", 32);
    model_param_props.addBitString("REG_CMDQ_CTRL1", "00000001000010000100001000010000", 32);
    model_param_props.addBitString("REG_CMDQ_LLR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_CMDQ_ISR_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_CMDQ_BER_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_CMDQ_ISW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_CMDQ_BEW_RATE_CTRL", "00000000001111111111110000001111", 32);
    model_param_props.addBitString("REG_QOS0", "00000000000011110000000011110001", 32);
    model_param_props.addBitString("REG_QOS1", "00000001000000000100000000010000", 32);
    model_param_props.addBitString("REG_QOS2", "00000000000000000100000000010000", 32);
    model_param_props.addBitString("REG_QOS_TIMEOUT0", "00000000011100111001110011100111", 32);
    model_param_props.addBitString("REG_QOS_TIMEOUT1", "00111111001111110011111100111111", 32);
    model_param_props.addBitString("REG_QOS_TIMEOUT2", "00000000000000000000000000111111", 32);
    model_param_props.addBitString("REG_RATE_CTRL_SCALE", "00000000100001000010000100001000", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG0", "00010000010010100000001100000100", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG1", "00000000110000011000001100000110", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG2", "01000110001100110001010000010100", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG3", "00000010000001000001000000011000", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG4", "00101100101110001110000111010000", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG5", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG6", "00000000000000000011000010000100", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG7", "00000010000000001000001000101110", 32);
    model_param_props.addBitString("REG_SAFE_CONFIG8", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_REF_0", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_TXN_CONFIG", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_WR_CONFIG", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_RD_CONFIG", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_PT_CONFIG", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_DRAM_ARB", "00000000000000000000000000011111", 32);
    model_param_props.addBitString("REG_CONFIG0", "00000000000000000000010000010000", 32);
    model_param_props.addBitString("REG_PINOUT", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADEC0", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADEC1", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADEC2", "00000000000000000101000000000000", 32);
    model_param_props.addBitString("REG_ADEC3", "00000000000000000101000000000000", 32);
    model_param_props.addBitString("REG_ADEC4", "00100111100110100101100100100011", 32);
    model_param_props.addBitString("REG_ADEC5", "00010011010010010001010000001111", 32);
    model_param_props.addBitString("REG_ADEC6", "00011000010111010110010101010100", 32);
    model_param_props.addBitString("REG_ADEC7", "00011101011100011011011010011001", 32);
    model_param_props.addBitString("REG_ADEC8", "00000011000000100000011111011110", 32);
    model_param_props.addBitString("REG_ADEC9", "00001000000111000110000101000100", 32);
    model_param_props.addBitString("REG_ADEC10", "00001101001100001011001010001001", 32);
    model_param_props.addBitString("REG_ADEC11", "00000000000110100010100001001110", 32);
    model_param_props.addBitString("TCK", "00000000000000000000001001110100", 32);
    model_param_props.addBitString("VERBOSITY_EN", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("EN_NPP_MONITOR", "1", 1);
    model_param_props.addBitString("DISABLE_DATA_CHECK_MONITOR", "1", 1);
    model_param_props.addBitString("F0_MR0", "0000000000000000110101010000", 28);
    model_param_props.addBitString("F0_MR1", "0000000000000000001100000001", 28);
    model_param_props.addBitString("F0_MR2", "0000000000000000000011101000", 28);
    model_param_props.addBitString("F0_MR3", "0000000000000000000000100000", 28);
    model_param_props.addBitString("F0_MR4", "0000000000000000000000000000", 28);
    model_param_props.addBitString("F0_MR5", "0000000000000000010000000000", 28);
    model_param_props.addBitString("F0_MR6", "0000000000000001000000010100", 28);
    model_param_props.addBitString("F1_MR0", "0000000000000000000000000000", 28);
    model_param_props.addBitString("F1_MR1", "0000000000000000000000000000", 28);
    model_param_props.addBitString("F1_MR2", "0000000000000000000000000000", 28);
    model_param_props.addBitString("F1_MR3", "0000000000000000000000100000", 28);
    model_param_props.addBitString("F1_MR4", "0000000000000000000000000000", 28);
    model_param_props.addBitString("F1_MR5", "0000000000000000000000000000", 28);
    model_param_props.addBitString("F1_MR6", "0000000000000000000000000000", 28);
    model_param_props.addBitString("REG_RC00", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC01", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC02", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC03", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC03_F1", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC04", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC04_F1", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC05", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC05_F1", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC08", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC0A", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC0A_F1", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC0B", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC0D", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC0E", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC0F", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC0F_F1", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC2X", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC3X", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC3X_F1", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC5X", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC8X", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC5X_F1", "0000000000000000", 16);
    model_param_props.addBitString("REG_RC8X_F1", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC00", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC01", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC02", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC03", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC04", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC05", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC06", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC0A", "0000000000000000", 16);
    model_param_props.addBitString("DB_F1BC0A", "0000000000000000", 16);
    model_param_props.addBitString("DB_F5BC5X", "0000000000000000", 16);
    model_param_props.addBitString("DB_F0BC6X", "0000000000000000", 16);
    model_param_props.addBitString("DB_F1BC6X", "0000000000000000", 16);
    model_param_props.addBitString("DB_F5BC6X", "0000000000000000", 16);
    model_param_props.addBitString("DB_F6BC4X", "0000000000000000", 16);
    model_param_props.addBitString("DB_FXBC7X_F6", "0000000000000000", 16);
    model_param_props.addBitString("DB_FXBC7X_F5", "0000000000000000", 16);
    model_param_props.addBitString("DB_FXBC7X_F0", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR1", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR2", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR3", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR11", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR12", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR13", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR14", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR15", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR16", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR17", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR20", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR22", "0000000000000000", 16);
    model_param_props.addBitString("F0_LPDDR4_MR23", "0000000000000000", 16);
    model_param_props.addString("COMPONENT_NAME", "bd_b77b_MC0_ddrc_0");

  mp_impl = new bd_b77b_MC0_ddrc_0_core("inst", model_param_props);
}

bd_b77b_MC0_ddrc_0_sc::~bd_b77b_MC0_ddrc_0_sc()
{
  xsc::utils::xsc_sim_manager::clean();

  delete mp_impl;
}

