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


#include "bd_b77b_S03_AXI_nmu_0_sc.h"

#include "bd_b77b_S03_AXI_nmu_0_core.h"

#include <map>
#include <string>

bd_b77b_S03_AXI_nmu_0_sc::bd_b77b_S03_AXI_nmu_0_sc(const sc_core::sc_module_name& nm) : sc_core::sc_module(nm), mp_impl(NULL)
{
  // configure connectivity manager
  xsc::utils::xsc_sim_manager::addInstance("bd_b77b_S03_AXI_nmu_0", this);

  // initialize module
    xsc::common_cpp::properties model_param_props;
    model_param_props.addLong("C_SPP_NOCNMU_TO_CORE_WIDTH", "2000");
    model_param_props.addLong("C_SPP_NOCNMU_FROM_CORE_WIDTH", "200");
    model_param_props.addLong("DEST_ID_VAL", "0");
    model_param_props.addLong("DESTID_WIDTH", "12");
    model_param_props.addLong("TDEST_WIDTH", "0");
    model_param_props.addString("C_XDEVICE", "xcve2302");
    model_param_props.addString("HDL_ATTR_FILE", "nocattrs.dat");
    model_param_props.addString("HDL_COMPONENT_NAME", "bd_b77b_S03_AXI_nmu_0");
    model_param_props.addString("DEST_IDS", "123 456");
    model_param_props.addString("CONN_SLV_BASE_ADDR", "0x00000000 0x800000000");
    model_param_props.addString("CONN_SLV_HIGH_ADDR", "0x7FFFFFFF 0x97FFFFFFF");
    model_param_props.addString("PHYS_NAME", "NOC_NMU128_X0Y9");
    model_param_props.addBitString("REG_ADDR_DST0", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST1", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST10", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST11", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST12", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST13", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST14", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST15", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST2", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST3", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST4", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST5", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST6", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST7", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST8", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_DST9", "000000000000000000", 18);
    model_param_props.addBitString("REG_ADDR_ENABLE", "0000000000000000", 16);
    model_param_props.addBitString("REG_ADDR_MADDR0", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR1", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR10", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR11", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR12", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR13", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR14", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR15", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR2", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR3", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR4", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR5", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR6", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR7", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR8", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MADDR9", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK0", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK1", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK10", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK11", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK12", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK13", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK14", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK15", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK2", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK3", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK4", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK5", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK6", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK7", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK8", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_MASK9", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_REMAP", "0000000000000000", 16);
    model_param_props.addBitString("REG_ADDR_RPADDR0", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR1", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR10", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR11", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR12", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR13", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR14", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR15", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR2", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR3", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR4", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR5", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR6", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR7", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR8", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADDR_RPADDR9", "00000000000000000000000000000000", 32);
    model_param_props.addBitString("REG_ADR_MAP_CPM", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_FPD_AFI_0", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_FPD_AFI_1", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_LPD_AFI_FS", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_ME_ARRAY_0", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_ME_ARRAY_1", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_ME_ARRAY_2", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_ME_ARRAY_3", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_PCIE", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_PMC", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_PMC_ALIAS_0", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_PMC_ALIAS_1", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_PMC_ALIAS_2", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_PMC_ALIAS_3", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_QSPI", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_STM_GIC", "00111111000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_USER_ID0", "00000000000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_USER_ID1", "00000000000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_USER_ID2", "00000000000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_USER_ID3", "00000000000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_USER_ID4", "00000000000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_USER_ID5", "00000000000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_USER_ID6", "00000000000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_USER_ID7", "00000000000000", 14);
    model_param_props.addBitString("REG_ADR_MAP_XPDS", "00111111000000", 14);
    model_param_props.addBitString("REG_AXI_NON_MOD_DISABLE", "0", 1);
    model_param_props.addBitString("REG_AXI_PAR_CHK", "00", 2);
    model_param_props.addBitString("REG_CHOPSIZE", "1010", 4);
    model_param_props.addBitString("REG_DDR_ADR_MAP0", "00110000000000000", 17);
    model_param_props.addBitString("REG_DDR_ADR_MAP1", "00001111111111111", 17);
    model_param_props.addBitString("REG_DDR_ADR_MAP2", "00001111111111111", 17);
    model_param_props.addBitString("REG_DDR_ADR_MAP3", "00001111111111111", 17);
    model_param_props.addBitString("REG_DDR_ADR_MAP4", "00001111111111111", 17);
    model_param_props.addBitString("REG_DDR_ADR_MAP5", "00001111111111111", 17);
    model_param_props.addBitString("REG_DDR_ADR_MAP6", "00001111111111111", 17);
    model_param_props.addBitString("REG_DDR_DST_MAP0", "001000000000", 12);
    model_param_props.addBitString("REG_DDR_DST_MAP1", "111111000000", 12);
    model_param_props.addBitString("REG_DDR_DST_MAP2", "111111000000", 12);
    model_param_props.addBitString("REG_DDR_DST_MAP3", "111111000000", 12);
    model_param_props.addBitString("REG_DDR_DST_MAP4", "111111000000", 12);
    model_param_props.addBitString("REG_DDR_DST_MAP5", "111111000000", 12);
    model_param_props.addBitString("REG_DDR_DST_MAP6", "111111000000", 12);
    model_param_props.addBitString("REG_DDR_DST_MAP7", "111111000000", 12);
    model_param_props.addBitString("REG_DWIDTH", "100", 3);
    model_param_props.addBitString("REG_ECC_CHK_EN", "1", 1);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH0", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH1", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH10", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH11", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH12", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH13", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH14", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH15", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH2", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH3", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH4", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH5", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH6", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH7", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH8", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T0_CH9", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH0", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH1", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH10", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH11", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH12", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH13", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH14", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH15", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH2", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH3", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH4", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH5", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH6", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH7", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH8", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T1_CH9", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH0", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH1", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH10", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH11", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH12", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH13", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH14", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH15", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH2", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH3", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH4", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH5", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH6", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH7", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH8", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T2_CH9", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH0", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH1", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH10", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH11", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH12", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH13", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH14", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH15", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH2", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH3", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH4", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH5", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH6", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH7", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH8", "00111111000000", 14);
    model_param_props.addBitString("REG_HBM_MAP_T3_CH9", "00111111000000", 14);
    model_param_props.addBitString("REG_HPHY_MODE", "0", 1);
    model_param_props.addBitString("REG_MODE_SELECT", "0000000000000000", 16);
    model_param_props.addBitString("REG_OUTSTANDING_RD_TXN", "1000000", 7);
    model_param_props.addBitString("REG_OUTSTANDING_WR_TXN", "1000000", 7);
    model_param_props.addBitString("REG_PRIORITY", "00", 2);
    model_param_props.addBitString("REG_QOS", "00000000", 8);
    model_param_props.addBitString("REG_RD_AXPROT_SEL", "000000", 6);
    model_param_props.addBitString("REG_RD_RATE_CREDIT_DROP", "0000000100", 10);
    model_param_props.addBitString("REG_RD_RATE_CREDIT_LIMIT", "00000100000000", 14);
    model_param_props.addBitString("REG_RD_VCA_TOKEN0", "00110011", 8);
    model_param_props.addBitString("REG_RPOISON_TO_SLVERR", "0", 1);
    model_param_props.addBitString("REG_RROB_RAM_SETTING", "000010010", 9);
    model_param_props.addBitString("REG_SMID_SEL", "00000000000000000000", 20);
    model_param_props.addBitString("REG_SRC", "000110000000", 12);
    model_param_props.addBitString("REG_TBASE_AXI_TIMEOUT", "0001", 4);
    model_param_props.addBitString("REG_TBASE_MODE_RLIMIT_RD", "010", 3);
    model_param_props.addBitString("REG_TBASE_MODE_RLIMIT_WR", "010", 3);
    model_param_props.addBitString("REG_TBASE_TRK_TIMEOUT", "0001", 4);
    model_param_props.addBitString("REG_VC_MAP", "111110101100", 12);
    model_param_props.addBitString("REG_WBUF_LAUNCH_SIZE", "010000", 6);
    model_param_props.addBitString("REG_WBUF_RAM_SETTING", "000010010", 9);
    model_param_props.addBitString("REG_WR_AXPROT_SEL", "000000", 6);
    model_param_props.addBitString("REG_WR_RATE_CREDIT_DROP", "0000000100", 10);
    model_param_props.addBitString("REG_WR_RATE_CREDIT_LIMIT", "00000100000000", 14);
    model_param_props.addBitString("REG_WR_VCA_TOKEN0", "11111111", 8);
    model_param_props.addBitString("VAL_DEST_IDS", "0000000000000000", 16);
    model_param_props.addString("COMPONENT_NAME", "bd_b77b_S03_AXI_nmu_0");

  mp_impl = new bd_b77b_S03_AXI_nmu_0_core("inst", model_param_props);

  // initialize AXI sockets
  SAXI4_rd_socket = mp_impl->SAXI4_rd_socket;
  SAXI4_wr_socket = mp_impl->SAXI4_wr_socket;
}

bd_b77b_S03_AXI_nmu_0_sc::~bd_b77b_S03_AXI_nmu_0_sc()
{
  xsc::utils::xsc_sim_manager::clean();

  delete mp_impl;
}

