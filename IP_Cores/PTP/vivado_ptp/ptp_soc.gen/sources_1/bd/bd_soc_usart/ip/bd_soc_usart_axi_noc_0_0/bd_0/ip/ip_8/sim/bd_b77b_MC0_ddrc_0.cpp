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

#include "bd_b77b_MC0_ddrc_0.h"

#include "bd_b77b_MC0_ddrc_0_core.h"

#include <map>
#include <string>





#ifdef XILINX_SIMULATOR
bd_b77b_MC0_ddrc_0::bd_b77b_MC0_ddrc_0(const sc_core::sc_module_name& nm) : bd_b77b_MC0_ddrc_0_sc(nm), sys_clk_p("sys_clk_p"), sys_clk_n("sys_clk_n"), ch0_ddr4_adr("ch0_ddr4_adr"), ch0_ddr4_bg("ch0_ddr4_bg"), ch0_ddr4_ba("ch0_ddr4_ba"), ch0_ddr4_cke("ch0_ddr4_cke"), ch0_ddr4_ck_t("ch0_ddr4_ck_t"), ch0_ddr4_ck_c("ch0_ddr4_ck_c"), ch0_ddr4_cs_n("ch0_ddr4_cs_n"), ch0_ddr4_dm_dbi_n("ch0_ddr4_dm_dbi_n"), ch0_ddr4_dq("ch0_ddr4_dq"), ch0_ddr4_dqs_c("ch0_ddr4_dqs_c"), ch0_ddr4_dqs_t("ch0_ddr4_dqs_t"), ch0_ddr4_odt("ch0_ddr4_odt"), ch0_ddr4_reset_n("ch0_ddr4_reset_n"), ch0_ddr4_act_n("ch0_ddr4_act_n"), noc2dmc_valid_in_0("noc2dmc_valid_in_0"), noc2dmc_data_in_0("noc2dmc_data_in_0"), noc2dmc_credit_rdy_0("noc2dmc_credit_rdy_0"), dmc2noc_credit_rtn_0("dmc2noc_credit_rtn_0"), noc2dmc_valid_in_1("noc2dmc_valid_in_1"), noc2dmc_data_in_1("noc2dmc_data_in_1"), noc2dmc_credit_rdy_1("noc2dmc_credit_rdy_1"), dmc2noc_credit_rtn_1("dmc2noc_credit_rtn_1"), noc2dmc_valid_in_2("noc2dmc_valid_in_2"), noc2dmc_data_in_2("noc2dmc_data_in_2"), noc2dmc_credit_rdy_2("noc2dmc_credit_rdy_2"), dmc2noc_credit_rtn_2("dmc2noc_credit_rtn_2"), noc2dmc_valid_in_3("noc2dmc_valid_in_3"), noc2dmc_data_in_3("noc2dmc_data_in_3"), noc2dmc_credit_rdy_3("noc2dmc_credit_rdy_3"), dmc2noc_credit_rtn_3("dmc2noc_credit_rtn_3"), dmc2noc_valid_out_0("dmc2noc_valid_out_0"), dmc2noc_data_out_0("dmc2noc_data_out_0"), dmc2noc_credit_rdy_0("dmc2noc_credit_rdy_0"), noc2dmc_credit_rtn_0("noc2dmc_credit_rtn_0"), dmc2noc_valid_out_1("dmc2noc_valid_out_1"), dmc2noc_data_out_1("dmc2noc_data_out_1"), dmc2noc_credit_rdy_1("dmc2noc_credit_rdy_1"), noc2dmc_credit_rtn_1("noc2dmc_credit_rtn_1"), dmc2noc_valid_out_2("dmc2noc_valid_out_2"), dmc2noc_data_out_2("dmc2noc_data_out_2"), dmc2noc_credit_rdy_2("dmc2noc_credit_rdy_2"), noc2dmc_credit_rtn_2("noc2dmc_credit_rtn_2"), dmc2noc_valid_out_3("dmc2noc_valid_out_3"), dmc2noc_data_out_3("dmc2noc_data_out_3"), dmc2noc_credit_rdy_3("dmc2noc_credit_rdy_3"), noc2dmc_credit_rtn_3("noc2dmc_credit_rtn_3"), from_noc_0("from_noc_0"), from_noc_1("from_noc_1"), from_noc_2("from_noc_2"), from_noc_3("from_noc_3")
{

  // initialize pins
  mp_impl->sys_clk_p(sys_clk_p);
  mp_impl->sys_clk_n(sys_clk_n);
  mp_impl->ch0_ddr4_adr(ch0_ddr4_adr);
  mp_impl->ch0_ddr4_bg(ch0_ddr4_bg);
  mp_impl->ch0_ddr4_ba(ch0_ddr4_ba);
  mp_impl->ch0_ddr4_cke(ch0_ddr4_cke);
  mp_impl->ch0_ddr4_ck_t(ch0_ddr4_ck_t);
  mp_impl->ch0_ddr4_ck_c(ch0_ddr4_ck_c);
  mp_impl->ch0_ddr4_cs_n(ch0_ddr4_cs_n);
  mp_impl->ch0_ddr4_dm_dbi_n(ch0_ddr4_dm_dbi_n);
  mp_impl->ch0_ddr4_dq(ch0_ddr4_dq);
  mp_impl->ch0_ddr4_dqs_c(ch0_ddr4_dqs_c);
  mp_impl->ch0_ddr4_dqs_t(ch0_ddr4_dqs_t);
  mp_impl->ch0_ddr4_odt(ch0_ddr4_odt);
  mp_impl->ch0_ddr4_reset_n(ch0_ddr4_reset_n);
  mp_impl->ch0_ddr4_act_n(ch0_ddr4_act_n);
  mp_impl->noc2dmc_valid_in_0(noc2dmc_valid_in_0);
  mp_impl->noc2dmc_data_in_0(noc2dmc_data_in_0);
  mp_impl->noc2dmc_credit_rdy_0(noc2dmc_credit_rdy_0);
  mp_impl->dmc2noc_credit_rtn_0(dmc2noc_credit_rtn_0);
  mp_impl->noc2dmc_valid_in_1(noc2dmc_valid_in_1);
  mp_impl->noc2dmc_data_in_1(noc2dmc_data_in_1);
  mp_impl->noc2dmc_credit_rdy_1(noc2dmc_credit_rdy_1);
  mp_impl->dmc2noc_credit_rtn_1(dmc2noc_credit_rtn_1);
  mp_impl->noc2dmc_valid_in_2(noc2dmc_valid_in_2);
  mp_impl->noc2dmc_data_in_2(noc2dmc_data_in_2);
  mp_impl->noc2dmc_credit_rdy_2(noc2dmc_credit_rdy_2);
  mp_impl->dmc2noc_credit_rtn_2(dmc2noc_credit_rtn_2);
  mp_impl->noc2dmc_valid_in_3(noc2dmc_valid_in_3);
  mp_impl->noc2dmc_data_in_3(noc2dmc_data_in_3);
  mp_impl->noc2dmc_credit_rdy_3(noc2dmc_credit_rdy_3);
  mp_impl->dmc2noc_credit_rtn_3(dmc2noc_credit_rtn_3);
  mp_impl->dmc2noc_valid_out_0(dmc2noc_valid_out_0);
  mp_impl->dmc2noc_data_out_0(dmc2noc_data_out_0);
  mp_impl->dmc2noc_credit_rdy_0(dmc2noc_credit_rdy_0);
  mp_impl->noc2dmc_credit_rtn_0(noc2dmc_credit_rtn_0);
  mp_impl->dmc2noc_valid_out_1(dmc2noc_valid_out_1);
  mp_impl->dmc2noc_data_out_1(dmc2noc_data_out_1);
  mp_impl->dmc2noc_credit_rdy_1(dmc2noc_credit_rdy_1);
  mp_impl->noc2dmc_credit_rtn_1(noc2dmc_credit_rtn_1);
  mp_impl->dmc2noc_valid_out_2(dmc2noc_valid_out_2);
  mp_impl->dmc2noc_data_out_2(dmc2noc_data_out_2);
  mp_impl->dmc2noc_credit_rdy_2(dmc2noc_credit_rdy_2);
  mp_impl->noc2dmc_credit_rtn_2(noc2dmc_credit_rtn_2);
  mp_impl->dmc2noc_valid_out_3(dmc2noc_valid_out_3);
  mp_impl->dmc2noc_data_out_3(dmc2noc_data_out_3);
  mp_impl->dmc2noc_credit_rdy_3(dmc2noc_credit_rdy_3);
  mp_impl->noc2dmc_credit_rtn_3(noc2dmc_credit_rtn_3);
  mp_impl->from_noc_0(from_noc_0);
  mp_impl->from_noc_1(from_noc_1);
  mp_impl->from_noc_2(from_noc_2);
  mp_impl->from_noc_3(from_noc_3);

}

void bd_b77b_MC0_ddrc_0::before_end_of_elaboration()
{
}

#endif // XILINX_SIMULATOR




#ifdef XM_SYSTEMC
bd_b77b_MC0_ddrc_0::bd_b77b_MC0_ddrc_0(const sc_core::sc_module_name& nm) : bd_b77b_MC0_ddrc_0_sc(nm), sys_clk_p("sys_clk_p"), sys_clk_n("sys_clk_n"), ch0_ddr4_adr("ch0_ddr4_adr"), ch0_ddr4_bg("ch0_ddr4_bg"), ch0_ddr4_ba("ch0_ddr4_ba"), ch0_ddr4_cke("ch0_ddr4_cke"), ch0_ddr4_ck_t("ch0_ddr4_ck_t"), ch0_ddr4_ck_c("ch0_ddr4_ck_c"), ch0_ddr4_cs_n("ch0_ddr4_cs_n"), ch0_ddr4_dm_dbi_n("ch0_ddr4_dm_dbi_n"), ch0_ddr4_dq("ch0_ddr4_dq"), ch0_ddr4_dqs_c("ch0_ddr4_dqs_c"), ch0_ddr4_dqs_t("ch0_ddr4_dqs_t"), ch0_ddr4_odt("ch0_ddr4_odt"), ch0_ddr4_reset_n("ch0_ddr4_reset_n"), ch0_ddr4_act_n("ch0_ddr4_act_n"), noc2dmc_valid_in_0("noc2dmc_valid_in_0"), noc2dmc_data_in_0("noc2dmc_data_in_0"), noc2dmc_credit_rdy_0("noc2dmc_credit_rdy_0"), dmc2noc_credit_rtn_0("dmc2noc_credit_rtn_0"), noc2dmc_valid_in_1("noc2dmc_valid_in_1"), noc2dmc_data_in_1("noc2dmc_data_in_1"), noc2dmc_credit_rdy_1("noc2dmc_credit_rdy_1"), dmc2noc_credit_rtn_1("dmc2noc_credit_rtn_1"), noc2dmc_valid_in_2("noc2dmc_valid_in_2"), noc2dmc_data_in_2("noc2dmc_data_in_2"), noc2dmc_credit_rdy_2("noc2dmc_credit_rdy_2"), dmc2noc_credit_rtn_2("dmc2noc_credit_rtn_2"), noc2dmc_valid_in_3("noc2dmc_valid_in_3"), noc2dmc_data_in_3("noc2dmc_data_in_3"), noc2dmc_credit_rdy_3("noc2dmc_credit_rdy_3"), dmc2noc_credit_rtn_3("dmc2noc_credit_rtn_3"), dmc2noc_valid_out_0("dmc2noc_valid_out_0"), dmc2noc_data_out_0("dmc2noc_data_out_0"), dmc2noc_credit_rdy_0("dmc2noc_credit_rdy_0"), noc2dmc_credit_rtn_0("noc2dmc_credit_rtn_0"), dmc2noc_valid_out_1("dmc2noc_valid_out_1"), dmc2noc_data_out_1("dmc2noc_data_out_1"), dmc2noc_credit_rdy_1("dmc2noc_credit_rdy_1"), noc2dmc_credit_rtn_1("noc2dmc_credit_rtn_1"), dmc2noc_valid_out_2("dmc2noc_valid_out_2"), dmc2noc_data_out_2("dmc2noc_data_out_2"), dmc2noc_credit_rdy_2("dmc2noc_credit_rdy_2"), noc2dmc_credit_rtn_2("noc2dmc_credit_rtn_2"), dmc2noc_valid_out_3("dmc2noc_valid_out_3"), dmc2noc_data_out_3("dmc2noc_data_out_3"), dmc2noc_credit_rdy_3("dmc2noc_credit_rdy_3"), noc2dmc_credit_rtn_3("noc2dmc_credit_rtn_3"), from_noc_0("from_noc_0"), from_noc_1("from_noc_1"), from_noc_2("from_noc_2"), from_noc_3("from_noc_3")
{

  // initialize pins
  mp_impl->sys_clk_p(sys_clk_p);
  mp_impl->sys_clk_n(sys_clk_n);
  mp_impl->ch0_ddr4_adr(ch0_ddr4_adr);
  mp_impl->ch0_ddr4_bg(ch0_ddr4_bg);
  mp_impl->ch0_ddr4_ba(ch0_ddr4_ba);
  mp_impl->ch0_ddr4_cke(ch0_ddr4_cke);
  mp_impl->ch0_ddr4_ck_t(ch0_ddr4_ck_t);
  mp_impl->ch0_ddr4_ck_c(ch0_ddr4_ck_c);
  mp_impl->ch0_ddr4_cs_n(ch0_ddr4_cs_n);
  mp_impl->ch0_ddr4_dm_dbi_n(ch0_ddr4_dm_dbi_n);
  mp_impl->ch0_ddr4_dq(ch0_ddr4_dq);
  mp_impl->ch0_ddr4_dqs_c(ch0_ddr4_dqs_c);
  mp_impl->ch0_ddr4_dqs_t(ch0_ddr4_dqs_t);
  mp_impl->ch0_ddr4_odt(ch0_ddr4_odt);
  mp_impl->ch0_ddr4_reset_n(ch0_ddr4_reset_n);
  mp_impl->ch0_ddr4_act_n(ch0_ddr4_act_n);
  mp_impl->noc2dmc_valid_in_0(noc2dmc_valid_in_0);
  mp_impl->noc2dmc_data_in_0(noc2dmc_data_in_0);
  mp_impl->noc2dmc_credit_rdy_0(noc2dmc_credit_rdy_0);
  mp_impl->dmc2noc_credit_rtn_0(dmc2noc_credit_rtn_0);
  mp_impl->noc2dmc_valid_in_1(noc2dmc_valid_in_1);
  mp_impl->noc2dmc_data_in_1(noc2dmc_data_in_1);
  mp_impl->noc2dmc_credit_rdy_1(noc2dmc_credit_rdy_1);
  mp_impl->dmc2noc_credit_rtn_1(dmc2noc_credit_rtn_1);
  mp_impl->noc2dmc_valid_in_2(noc2dmc_valid_in_2);
  mp_impl->noc2dmc_data_in_2(noc2dmc_data_in_2);
  mp_impl->noc2dmc_credit_rdy_2(noc2dmc_credit_rdy_2);
  mp_impl->dmc2noc_credit_rtn_2(dmc2noc_credit_rtn_2);
  mp_impl->noc2dmc_valid_in_3(noc2dmc_valid_in_3);
  mp_impl->noc2dmc_data_in_3(noc2dmc_data_in_3);
  mp_impl->noc2dmc_credit_rdy_3(noc2dmc_credit_rdy_3);
  mp_impl->dmc2noc_credit_rtn_3(dmc2noc_credit_rtn_3);
  mp_impl->dmc2noc_valid_out_0(dmc2noc_valid_out_0);
  mp_impl->dmc2noc_data_out_0(dmc2noc_data_out_0);
  mp_impl->dmc2noc_credit_rdy_0(dmc2noc_credit_rdy_0);
  mp_impl->noc2dmc_credit_rtn_0(noc2dmc_credit_rtn_0);
  mp_impl->dmc2noc_valid_out_1(dmc2noc_valid_out_1);
  mp_impl->dmc2noc_data_out_1(dmc2noc_data_out_1);
  mp_impl->dmc2noc_credit_rdy_1(dmc2noc_credit_rdy_1);
  mp_impl->noc2dmc_credit_rtn_1(noc2dmc_credit_rtn_1);
  mp_impl->dmc2noc_valid_out_2(dmc2noc_valid_out_2);
  mp_impl->dmc2noc_data_out_2(dmc2noc_data_out_2);
  mp_impl->dmc2noc_credit_rdy_2(dmc2noc_credit_rdy_2);
  mp_impl->noc2dmc_credit_rtn_2(noc2dmc_credit_rtn_2);
  mp_impl->dmc2noc_valid_out_3(dmc2noc_valid_out_3);
  mp_impl->dmc2noc_data_out_3(dmc2noc_data_out_3);
  mp_impl->dmc2noc_credit_rdy_3(dmc2noc_credit_rdy_3);
  mp_impl->noc2dmc_credit_rtn_3(noc2dmc_credit_rtn_3);
  mp_impl->from_noc_0(from_noc_0);
  mp_impl->from_noc_1(from_noc_1);
  mp_impl->from_noc_2(from_noc_2);
  mp_impl->from_noc_3(from_noc_3);

}

void bd_b77b_MC0_ddrc_0::before_end_of_elaboration()
{
}

#endif // XM_SYSTEMC




#ifdef RIVIERA
bd_b77b_MC0_ddrc_0::bd_b77b_MC0_ddrc_0(const sc_core::sc_module_name& nm) : bd_b77b_MC0_ddrc_0_sc(nm), sys_clk_p("sys_clk_p"), sys_clk_n("sys_clk_n"), ch0_ddr4_adr("ch0_ddr4_adr"), ch0_ddr4_bg("ch0_ddr4_bg"), ch0_ddr4_ba("ch0_ddr4_ba"), ch0_ddr4_cke("ch0_ddr4_cke"), ch0_ddr4_ck_t("ch0_ddr4_ck_t"), ch0_ddr4_ck_c("ch0_ddr4_ck_c"), ch0_ddr4_cs_n("ch0_ddr4_cs_n"), ch0_ddr4_dm_dbi_n("ch0_ddr4_dm_dbi_n"), ch0_ddr4_dq("ch0_ddr4_dq"), ch0_ddr4_dqs_c("ch0_ddr4_dqs_c"), ch0_ddr4_dqs_t("ch0_ddr4_dqs_t"), ch0_ddr4_odt("ch0_ddr4_odt"), ch0_ddr4_reset_n("ch0_ddr4_reset_n"), ch0_ddr4_act_n("ch0_ddr4_act_n"), noc2dmc_valid_in_0("noc2dmc_valid_in_0"), noc2dmc_data_in_0("noc2dmc_data_in_0"), noc2dmc_credit_rdy_0("noc2dmc_credit_rdy_0"), dmc2noc_credit_rtn_0("dmc2noc_credit_rtn_0"), noc2dmc_valid_in_1("noc2dmc_valid_in_1"), noc2dmc_data_in_1("noc2dmc_data_in_1"), noc2dmc_credit_rdy_1("noc2dmc_credit_rdy_1"), dmc2noc_credit_rtn_1("dmc2noc_credit_rtn_1"), noc2dmc_valid_in_2("noc2dmc_valid_in_2"), noc2dmc_data_in_2("noc2dmc_data_in_2"), noc2dmc_credit_rdy_2("noc2dmc_credit_rdy_2"), dmc2noc_credit_rtn_2("dmc2noc_credit_rtn_2"), noc2dmc_valid_in_3("noc2dmc_valid_in_3"), noc2dmc_data_in_3("noc2dmc_data_in_3"), noc2dmc_credit_rdy_3("noc2dmc_credit_rdy_3"), dmc2noc_credit_rtn_3("dmc2noc_credit_rtn_3"), dmc2noc_valid_out_0("dmc2noc_valid_out_0"), dmc2noc_data_out_0("dmc2noc_data_out_0"), dmc2noc_credit_rdy_0("dmc2noc_credit_rdy_0"), noc2dmc_credit_rtn_0("noc2dmc_credit_rtn_0"), dmc2noc_valid_out_1("dmc2noc_valid_out_1"), dmc2noc_data_out_1("dmc2noc_data_out_1"), dmc2noc_credit_rdy_1("dmc2noc_credit_rdy_1"), noc2dmc_credit_rtn_1("noc2dmc_credit_rtn_1"), dmc2noc_valid_out_2("dmc2noc_valid_out_2"), dmc2noc_data_out_2("dmc2noc_data_out_2"), dmc2noc_credit_rdy_2("dmc2noc_credit_rdy_2"), noc2dmc_credit_rtn_2("noc2dmc_credit_rtn_2"), dmc2noc_valid_out_3("dmc2noc_valid_out_3"), dmc2noc_data_out_3("dmc2noc_data_out_3"), dmc2noc_credit_rdy_3("dmc2noc_credit_rdy_3"), noc2dmc_credit_rtn_3("noc2dmc_credit_rtn_3"), from_noc_0("from_noc_0"), from_noc_1("from_noc_1"), from_noc_2("from_noc_2"), from_noc_3("from_noc_3")
{

  // initialize pins
  mp_impl->sys_clk_p(sys_clk_p);
  mp_impl->sys_clk_n(sys_clk_n);
  mp_impl->ch0_ddr4_adr(ch0_ddr4_adr);
  mp_impl->ch0_ddr4_bg(ch0_ddr4_bg);
  mp_impl->ch0_ddr4_ba(ch0_ddr4_ba);
  mp_impl->ch0_ddr4_cke(ch0_ddr4_cke);
  mp_impl->ch0_ddr4_ck_t(ch0_ddr4_ck_t);
  mp_impl->ch0_ddr4_ck_c(ch0_ddr4_ck_c);
  mp_impl->ch0_ddr4_cs_n(ch0_ddr4_cs_n);
  mp_impl->ch0_ddr4_dm_dbi_n(ch0_ddr4_dm_dbi_n);
  mp_impl->ch0_ddr4_dq(ch0_ddr4_dq);
  mp_impl->ch0_ddr4_dqs_c(ch0_ddr4_dqs_c);
  mp_impl->ch0_ddr4_dqs_t(ch0_ddr4_dqs_t);
  mp_impl->ch0_ddr4_odt(ch0_ddr4_odt);
  mp_impl->ch0_ddr4_reset_n(ch0_ddr4_reset_n);
  mp_impl->ch0_ddr4_act_n(ch0_ddr4_act_n);
  mp_impl->noc2dmc_valid_in_0(noc2dmc_valid_in_0);
  mp_impl->noc2dmc_data_in_0(noc2dmc_data_in_0);
  mp_impl->noc2dmc_credit_rdy_0(noc2dmc_credit_rdy_0);
  mp_impl->dmc2noc_credit_rtn_0(dmc2noc_credit_rtn_0);
  mp_impl->noc2dmc_valid_in_1(noc2dmc_valid_in_1);
  mp_impl->noc2dmc_data_in_1(noc2dmc_data_in_1);
  mp_impl->noc2dmc_credit_rdy_1(noc2dmc_credit_rdy_1);
  mp_impl->dmc2noc_credit_rtn_1(dmc2noc_credit_rtn_1);
  mp_impl->noc2dmc_valid_in_2(noc2dmc_valid_in_2);
  mp_impl->noc2dmc_data_in_2(noc2dmc_data_in_2);
  mp_impl->noc2dmc_credit_rdy_2(noc2dmc_credit_rdy_2);
  mp_impl->dmc2noc_credit_rtn_2(dmc2noc_credit_rtn_2);
  mp_impl->noc2dmc_valid_in_3(noc2dmc_valid_in_3);
  mp_impl->noc2dmc_data_in_3(noc2dmc_data_in_3);
  mp_impl->noc2dmc_credit_rdy_3(noc2dmc_credit_rdy_3);
  mp_impl->dmc2noc_credit_rtn_3(dmc2noc_credit_rtn_3);
  mp_impl->dmc2noc_valid_out_0(dmc2noc_valid_out_0);
  mp_impl->dmc2noc_data_out_0(dmc2noc_data_out_0);
  mp_impl->dmc2noc_credit_rdy_0(dmc2noc_credit_rdy_0);
  mp_impl->noc2dmc_credit_rtn_0(noc2dmc_credit_rtn_0);
  mp_impl->dmc2noc_valid_out_1(dmc2noc_valid_out_1);
  mp_impl->dmc2noc_data_out_1(dmc2noc_data_out_1);
  mp_impl->dmc2noc_credit_rdy_1(dmc2noc_credit_rdy_1);
  mp_impl->noc2dmc_credit_rtn_1(noc2dmc_credit_rtn_1);
  mp_impl->dmc2noc_valid_out_2(dmc2noc_valid_out_2);
  mp_impl->dmc2noc_data_out_2(dmc2noc_data_out_2);
  mp_impl->dmc2noc_credit_rdy_2(dmc2noc_credit_rdy_2);
  mp_impl->noc2dmc_credit_rtn_2(noc2dmc_credit_rtn_2);
  mp_impl->dmc2noc_valid_out_3(dmc2noc_valid_out_3);
  mp_impl->dmc2noc_data_out_3(dmc2noc_data_out_3);
  mp_impl->dmc2noc_credit_rdy_3(dmc2noc_credit_rdy_3);
  mp_impl->noc2dmc_credit_rtn_3(noc2dmc_credit_rtn_3);
  mp_impl->from_noc_0(from_noc_0);
  mp_impl->from_noc_1(from_noc_1);
  mp_impl->from_noc_2(from_noc_2);
  mp_impl->from_noc_3(from_noc_3);

}

void bd_b77b_MC0_ddrc_0::before_end_of_elaboration()
{
}

#endif // RIVIERA




#ifdef VCSSYSTEMC
bd_b77b_MC0_ddrc_0::bd_b77b_MC0_ddrc_0(const sc_core::sc_module_name& nm) : bd_b77b_MC0_ddrc_0_sc(nm),  sys_clk_p("sys_clk_p"), sys_clk_n("sys_clk_n"), ch0_ddr4_adr("ch0_ddr4_adr"), ch0_ddr4_bg("ch0_ddr4_bg"), ch0_ddr4_ba("ch0_ddr4_ba"), ch0_ddr4_cke("ch0_ddr4_cke"), ch0_ddr4_ck_t("ch0_ddr4_ck_t"), ch0_ddr4_ck_c("ch0_ddr4_ck_c"), ch0_ddr4_cs_n("ch0_ddr4_cs_n"), ch0_ddr4_dm_dbi_n("ch0_ddr4_dm_dbi_n"), ch0_ddr4_dq("ch0_ddr4_dq"), ch0_ddr4_dqs_c("ch0_ddr4_dqs_c"), ch0_ddr4_dqs_t("ch0_ddr4_dqs_t"), ch0_ddr4_odt("ch0_ddr4_odt"), ch0_ddr4_reset_n("ch0_ddr4_reset_n"), ch0_ddr4_act_n("ch0_ddr4_act_n"), noc2dmc_valid_in_0("noc2dmc_valid_in_0"), noc2dmc_data_in_0("noc2dmc_data_in_0"), noc2dmc_credit_rdy_0("noc2dmc_credit_rdy_0"), dmc2noc_credit_rtn_0("dmc2noc_credit_rtn_0"), noc2dmc_valid_in_1("noc2dmc_valid_in_1"), noc2dmc_data_in_1("noc2dmc_data_in_1"), noc2dmc_credit_rdy_1("noc2dmc_credit_rdy_1"), dmc2noc_credit_rtn_1("dmc2noc_credit_rtn_1"), noc2dmc_valid_in_2("noc2dmc_valid_in_2"), noc2dmc_data_in_2("noc2dmc_data_in_2"), noc2dmc_credit_rdy_2("noc2dmc_credit_rdy_2"), dmc2noc_credit_rtn_2("dmc2noc_credit_rtn_2"), noc2dmc_valid_in_3("noc2dmc_valid_in_3"), noc2dmc_data_in_3("noc2dmc_data_in_3"), noc2dmc_credit_rdy_3("noc2dmc_credit_rdy_3"), dmc2noc_credit_rtn_3("dmc2noc_credit_rtn_3"), dmc2noc_valid_out_0("dmc2noc_valid_out_0"), dmc2noc_data_out_0("dmc2noc_data_out_0"), dmc2noc_credit_rdy_0("dmc2noc_credit_rdy_0"), noc2dmc_credit_rtn_0("noc2dmc_credit_rtn_0"), dmc2noc_valid_out_1("dmc2noc_valid_out_1"), dmc2noc_data_out_1("dmc2noc_data_out_1"), dmc2noc_credit_rdy_1("dmc2noc_credit_rdy_1"), noc2dmc_credit_rtn_1("noc2dmc_credit_rtn_1"), dmc2noc_valid_out_2("dmc2noc_valid_out_2"), dmc2noc_data_out_2("dmc2noc_data_out_2"), dmc2noc_credit_rdy_2("dmc2noc_credit_rdy_2"), noc2dmc_credit_rtn_2("noc2dmc_credit_rtn_2"), dmc2noc_valid_out_3("dmc2noc_valid_out_3"), dmc2noc_data_out_3("dmc2noc_data_out_3"), dmc2noc_credit_rdy_3("dmc2noc_credit_rdy_3"), noc2dmc_credit_rtn_3("noc2dmc_credit_rtn_3"), from_noc_0("from_noc_0"), from_noc_1("from_noc_1"), from_noc_2("from_noc_2"), from_noc_3("from_noc_3")
{
  // initialize pins
  mp_impl->sys_clk_p(sys_clk_p);
  mp_impl->sys_clk_n(sys_clk_n);
  mp_impl->ch0_ddr4_adr(ch0_ddr4_adr);
  mp_impl->ch0_ddr4_bg(ch0_ddr4_bg);
  mp_impl->ch0_ddr4_ba(ch0_ddr4_ba);
  mp_impl->ch0_ddr4_cke(ch0_ddr4_cke);
  mp_impl->ch0_ddr4_ck_t(ch0_ddr4_ck_t);
  mp_impl->ch0_ddr4_ck_c(ch0_ddr4_ck_c);
  mp_impl->ch0_ddr4_cs_n(ch0_ddr4_cs_n);
  mp_impl->ch0_ddr4_dm_dbi_n(ch0_ddr4_dm_dbi_n);
  mp_impl->ch0_ddr4_dq(ch0_ddr4_dq);
  mp_impl->ch0_ddr4_dqs_c(ch0_ddr4_dqs_c);
  mp_impl->ch0_ddr4_dqs_t(ch0_ddr4_dqs_t);
  mp_impl->ch0_ddr4_odt(ch0_ddr4_odt);
  mp_impl->ch0_ddr4_reset_n(ch0_ddr4_reset_n);
  mp_impl->ch0_ddr4_act_n(ch0_ddr4_act_n);
  mp_impl->noc2dmc_valid_in_0(noc2dmc_valid_in_0);
  mp_impl->noc2dmc_data_in_0(noc2dmc_data_in_0);
  mp_impl->noc2dmc_credit_rdy_0(noc2dmc_credit_rdy_0);
  mp_impl->dmc2noc_credit_rtn_0(dmc2noc_credit_rtn_0);
  mp_impl->noc2dmc_valid_in_1(noc2dmc_valid_in_1);
  mp_impl->noc2dmc_data_in_1(noc2dmc_data_in_1);
  mp_impl->noc2dmc_credit_rdy_1(noc2dmc_credit_rdy_1);
  mp_impl->dmc2noc_credit_rtn_1(dmc2noc_credit_rtn_1);
  mp_impl->noc2dmc_valid_in_2(noc2dmc_valid_in_2);
  mp_impl->noc2dmc_data_in_2(noc2dmc_data_in_2);
  mp_impl->noc2dmc_credit_rdy_2(noc2dmc_credit_rdy_2);
  mp_impl->dmc2noc_credit_rtn_2(dmc2noc_credit_rtn_2);
  mp_impl->noc2dmc_valid_in_3(noc2dmc_valid_in_3);
  mp_impl->noc2dmc_data_in_3(noc2dmc_data_in_3);
  mp_impl->noc2dmc_credit_rdy_3(noc2dmc_credit_rdy_3);
  mp_impl->dmc2noc_credit_rtn_3(dmc2noc_credit_rtn_3);
  mp_impl->dmc2noc_valid_out_0(dmc2noc_valid_out_0);
  mp_impl->dmc2noc_data_out_0(dmc2noc_data_out_0);
  mp_impl->dmc2noc_credit_rdy_0(dmc2noc_credit_rdy_0);
  mp_impl->noc2dmc_credit_rtn_0(noc2dmc_credit_rtn_0);
  mp_impl->dmc2noc_valid_out_1(dmc2noc_valid_out_1);
  mp_impl->dmc2noc_data_out_1(dmc2noc_data_out_1);
  mp_impl->dmc2noc_credit_rdy_1(dmc2noc_credit_rdy_1);
  mp_impl->noc2dmc_credit_rtn_1(noc2dmc_credit_rtn_1);
  mp_impl->dmc2noc_valid_out_2(dmc2noc_valid_out_2);
  mp_impl->dmc2noc_data_out_2(dmc2noc_data_out_2);
  mp_impl->dmc2noc_credit_rdy_2(dmc2noc_credit_rdy_2);
  mp_impl->noc2dmc_credit_rtn_2(noc2dmc_credit_rtn_2);
  mp_impl->dmc2noc_valid_out_3(dmc2noc_valid_out_3);
  mp_impl->dmc2noc_data_out_3(dmc2noc_data_out_3);
  mp_impl->dmc2noc_credit_rdy_3(dmc2noc_credit_rdy_3);
  mp_impl->noc2dmc_credit_rtn_3(noc2dmc_credit_rtn_3);
  mp_impl->from_noc_0(from_noc_0);
  mp_impl->from_noc_1(from_noc_1);
  mp_impl->from_noc_2(from_noc_2);
  mp_impl->from_noc_3(from_noc_3);

  // Instantiate Socket Stubs


}

void bd_b77b_MC0_ddrc_0::before_end_of_elaboration()
{
}

#endif // VCSSYSTEMC




#ifdef MTI_SYSTEMC
bd_b77b_MC0_ddrc_0::bd_b77b_MC0_ddrc_0(const sc_core::sc_module_name& nm) : bd_b77b_MC0_ddrc_0_sc(nm),  sys_clk_p("sys_clk_p"), sys_clk_n("sys_clk_n"), ch0_ddr4_adr("ch0_ddr4_adr"), ch0_ddr4_bg("ch0_ddr4_bg"), ch0_ddr4_ba("ch0_ddr4_ba"), ch0_ddr4_cke("ch0_ddr4_cke"), ch0_ddr4_ck_t("ch0_ddr4_ck_t"), ch0_ddr4_ck_c("ch0_ddr4_ck_c"), ch0_ddr4_cs_n("ch0_ddr4_cs_n"), ch0_ddr4_dm_dbi_n("ch0_ddr4_dm_dbi_n"), ch0_ddr4_dq("ch0_ddr4_dq"), ch0_ddr4_dqs_c("ch0_ddr4_dqs_c"), ch0_ddr4_dqs_t("ch0_ddr4_dqs_t"), ch0_ddr4_odt("ch0_ddr4_odt"), ch0_ddr4_reset_n("ch0_ddr4_reset_n"), ch0_ddr4_act_n("ch0_ddr4_act_n"), noc2dmc_valid_in_0("noc2dmc_valid_in_0"), noc2dmc_data_in_0("noc2dmc_data_in_0"), noc2dmc_credit_rdy_0("noc2dmc_credit_rdy_0"), dmc2noc_credit_rtn_0("dmc2noc_credit_rtn_0"), noc2dmc_valid_in_1("noc2dmc_valid_in_1"), noc2dmc_data_in_1("noc2dmc_data_in_1"), noc2dmc_credit_rdy_1("noc2dmc_credit_rdy_1"), dmc2noc_credit_rtn_1("dmc2noc_credit_rtn_1"), noc2dmc_valid_in_2("noc2dmc_valid_in_2"), noc2dmc_data_in_2("noc2dmc_data_in_2"), noc2dmc_credit_rdy_2("noc2dmc_credit_rdy_2"), dmc2noc_credit_rtn_2("dmc2noc_credit_rtn_2"), noc2dmc_valid_in_3("noc2dmc_valid_in_3"), noc2dmc_data_in_3("noc2dmc_data_in_3"), noc2dmc_credit_rdy_3("noc2dmc_credit_rdy_3"), dmc2noc_credit_rtn_3("dmc2noc_credit_rtn_3"), dmc2noc_valid_out_0("dmc2noc_valid_out_0"), dmc2noc_data_out_0("dmc2noc_data_out_0"), dmc2noc_credit_rdy_0("dmc2noc_credit_rdy_0"), noc2dmc_credit_rtn_0("noc2dmc_credit_rtn_0"), dmc2noc_valid_out_1("dmc2noc_valid_out_1"), dmc2noc_data_out_1("dmc2noc_data_out_1"), dmc2noc_credit_rdy_1("dmc2noc_credit_rdy_1"), noc2dmc_credit_rtn_1("noc2dmc_credit_rtn_1"), dmc2noc_valid_out_2("dmc2noc_valid_out_2"), dmc2noc_data_out_2("dmc2noc_data_out_2"), dmc2noc_credit_rdy_2("dmc2noc_credit_rdy_2"), noc2dmc_credit_rtn_2("noc2dmc_credit_rtn_2"), dmc2noc_valid_out_3("dmc2noc_valid_out_3"), dmc2noc_data_out_3("dmc2noc_data_out_3"), dmc2noc_credit_rdy_3("dmc2noc_credit_rdy_3"), noc2dmc_credit_rtn_3("noc2dmc_credit_rtn_3"), from_noc_0("from_noc_0"), from_noc_1("from_noc_1"), from_noc_2("from_noc_2"), from_noc_3("from_noc_3")
{
  // initialize pins
  mp_impl->sys_clk_p(sys_clk_p);
  mp_impl->sys_clk_n(sys_clk_n);
  mp_impl->ch0_ddr4_adr(ch0_ddr4_adr);
  mp_impl->ch0_ddr4_bg(ch0_ddr4_bg);
  mp_impl->ch0_ddr4_ba(ch0_ddr4_ba);
  mp_impl->ch0_ddr4_cke(ch0_ddr4_cke);
  mp_impl->ch0_ddr4_ck_t(ch0_ddr4_ck_t);
  mp_impl->ch0_ddr4_ck_c(ch0_ddr4_ck_c);
  mp_impl->ch0_ddr4_cs_n(ch0_ddr4_cs_n);
  mp_impl->ch0_ddr4_dm_dbi_n(ch0_ddr4_dm_dbi_n);
  mp_impl->ch0_ddr4_dq(ch0_ddr4_dq);
  mp_impl->ch0_ddr4_dqs_c(ch0_ddr4_dqs_c);
  mp_impl->ch0_ddr4_dqs_t(ch0_ddr4_dqs_t);
  mp_impl->ch0_ddr4_odt(ch0_ddr4_odt);
  mp_impl->ch0_ddr4_reset_n(ch0_ddr4_reset_n);
  mp_impl->ch0_ddr4_act_n(ch0_ddr4_act_n);
  mp_impl->noc2dmc_valid_in_0(noc2dmc_valid_in_0);
  mp_impl->noc2dmc_data_in_0(noc2dmc_data_in_0);
  mp_impl->noc2dmc_credit_rdy_0(noc2dmc_credit_rdy_0);
  mp_impl->dmc2noc_credit_rtn_0(dmc2noc_credit_rtn_0);
  mp_impl->noc2dmc_valid_in_1(noc2dmc_valid_in_1);
  mp_impl->noc2dmc_data_in_1(noc2dmc_data_in_1);
  mp_impl->noc2dmc_credit_rdy_1(noc2dmc_credit_rdy_1);
  mp_impl->dmc2noc_credit_rtn_1(dmc2noc_credit_rtn_1);
  mp_impl->noc2dmc_valid_in_2(noc2dmc_valid_in_2);
  mp_impl->noc2dmc_data_in_2(noc2dmc_data_in_2);
  mp_impl->noc2dmc_credit_rdy_2(noc2dmc_credit_rdy_2);
  mp_impl->dmc2noc_credit_rtn_2(dmc2noc_credit_rtn_2);
  mp_impl->noc2dmc_valid_in_3(noc2dmc_valid_in_3);
  mp_impl->noc2dmc_data_in_3(noc2dmc_data_in_3);
  mp_impl->noc2dmc_credit_rdy_3(noc2dmc_credit_rdy_3);
  mp_impl->dmc2noc_credit_rtn_3(dmc2noc_credit_rtn_3);
  mp_impl->dmc2noc_valid_out_0(dmc2noc_valid_out_0);
  mp_impl->dmc2noc_data_out_0(dmc2noc_data_out_0);
  mp_impl->dmc2noc_credit_rdy_0(dmc2noc_credit_rdy_0);
  mp_impl->noc2dmc_credit_rtn_0(noc2dmc_credit_rtn_0);
  mp_impl->dmc2noc_valid_out_1(dmc2noc_valid_out_1);
  mp_impl->dmc2noc_data_out_1(dmc2noc_data_out_1);
  mp_impl->dmc2noc_credit_rdy_1(dmc2noc_credit_rdy_1);
  mp_impl->noc2dmc_credit_rtn_1(noc2dmc_credit_rtn_1);
  mp_impl->dmc2noc_valid_out_2(dmc2noc_valid_out_2);
  mp_impl->dmc2noc_data_out_2(dmc2noc_data_out_2);
  mp_impl->dmc2noc_credit_rdy_2(dmc2noc_credit_rdy_2);
  mp_impl->noc2dmc_credit_rtn_2(noc2dmc_credit_rtn_2);
  mp_impl->dmc2noc_valid_out_3(dmc2noc_valid_out_3);
  mp_impl->dmc2noc_data_out_3(dmc2noc_data_out_3);
  mp_impl->dmc2noc_credit_rdy_3(dmc2noc_credit_rdy_3);
  mp_impl->noc2dmc_credit_rtn_3(noc2dmc_credit_rtn_3);
  mp_impl->from_noc_0(from_noc_0);
  mp_impl->from_noc_1(from_noc_1);
  mp_impl->from_noc_2(from_noc_2);
  mp_impl->from_noc_3(from_noc_3);

  // Instantiate Socket Stubs


}

void bd_b77b_MC0_ddrc_0::before_end_of_elaboration()
{
}

#endif // MTI_SYSTEMC




bd_b77b_MC0_ddrc_0::~bd_b77b_MC0_ddrc_0()
{
}

#ifdef MTI_SYSTEMC
SC_MODULE_EXPORT(bd_b77b_MC0_ddrc_0);
#endif

#ifdef XM_SYSTEMC
XMSC_MODULE_EXPORT(bd_b77b_MC0_ddrc_0);
#endif

#ifdef RIVIERA
SC_MODULE_EXPORT(bd_b77b_MC0_ddrc_0);
SC_REGISTER_BV(182);
#endif

