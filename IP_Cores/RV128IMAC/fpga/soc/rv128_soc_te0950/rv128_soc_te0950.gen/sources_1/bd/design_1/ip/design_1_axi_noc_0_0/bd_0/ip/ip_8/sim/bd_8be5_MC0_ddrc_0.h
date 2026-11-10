#ifndef IP_BD_8BE5_MC0_DDRC_0_H_
#define IP_BD_8BE5_MC0_DDRC_0_H_

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


#ifndef XTLM
#include "xtlm.h"
#endif
#ifndef SYSTEMC_INCLUDED
#include <systemc>
#endif

#if defined(_MSC_VER)
#define DllExport __declspec(dllexport)
#elif defined(__GNUC__)
#define DllExport __attribute__ ((visibility("default")))
#else
#define DllExport
#endif

#include "bd_8be5_MC0_ddrc_0_sc.h"




#ifdef XILINX_SIMULATOR
class DllExport bd_8be5_MC0_ddrc_0 : public bd_8be5_MC0_ddrc_0_sc
{
public:

  bd_8be5_MC0_ddrc_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_MC0_ddrc_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > sys_clk_p;
  sc_core::sc_in< bool > sys_clk_n;
  sc_core::sc_out< sc_dt::sc_bv<17> > ch0_ddr4_adr;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_bg;
  sc_core::sc_out< sc_dt::sc_bv<2> > ch0_ddr4_ba;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cke;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_c;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cs_n;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dm_dbi_n;
  sc_core::sc_out< sc_dt::sc_bv<64> > ch0_ddr4_dq;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dqs_c;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dqs_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_odt;
  sc_core::sc_out< bool > ch0_ddr4_reset_n;
  sc_core::sc_out< bool > ch0_ddr4_act_n;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_0;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_0;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_1;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_1;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_2;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_2;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_3;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_3;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_0;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_0;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_1;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_1;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_2;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_2;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_3;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_3;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_3;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_3;
  sc_core::sc_in< bool > from_noc_0;
  sc_core::sc_in< bool > from_noc_1;
  sc_core::sc_in< bool > from_noc_2;
  sc_core::sc_in< bool > from_noc_3;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:


};
#endif // XILINX_SIMULATOR




#ifdef XM_SYSTEMC
class DllExport bd_8be5_MC0_ddrc_0 : public bd_8be5_MC0_ddrc_0_sc
{
public:

  bd_8be5_MC0_ddrc_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_MC0_ddrc_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > sys_clk_p;
  sc_core::sc_in< bool > sys_clk_n;
  sc_core::sc_out< sc_dt::sc_bv<17> > ch0_ddr4_adr;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_bg;
  sc_core::sc_out< sc_dt::sc_bv<2> > ch0_ddr4_ba;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cke;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_c;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cs_n;
  sc_core::sc_inout< sc_dt::sc_bv<8> > ch0_ddr4_dm_dbi_n;
  sc_core::sc_inout< sc_dt::sc_bv<64> > ch0_ddr4_dq;
  sc_core::sc_inout< sc_dt::sc_bv<8> > ch0_ddr4_dqs_c;
  sc_core::sc_inout< sc_dt::sc_bv<8> > ch0_ddr4_dqs_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_odt;
  sc_core::sc_out< bool > ch0_ddr4_reset_n;
  sc_core::sc_out< bool > ch0_ddr4_act_n;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_0;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_0;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_1;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_1;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_2;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_2;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_3;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_3;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_0;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_0;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_1;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_1;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_2;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_2;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_3;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_3;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_3;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_3;
  sc_core::sc_in< bool > from_noc_0;
  sc_core::sc_in< bool > from_noc_1;
  sc_core::sc_in< bool > from_noc_2;
  sc_core::sc_in< bool > from_noc_3;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:


};
#endif // XM_SYSTEMC




#ifdef RIVIERA
class DllExport bd_8be5_MC0_ddrc_0 : public bd_8be5_MC0_ddrc_0_sc
{
public:

  bd_8be5_MC0_ddrc_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_MC0_ddrc_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > sys_clk_p;
  sc_core::sc_in< bool > sys_clk_n;
  sc_core::sc_out< sc_dt::sc_bv<17> > ch0_ddr4_adr;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_bg;
  sc_core::sc_out< sc_dt::sc_bv<2> > ch0_ddr4_ba;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cke;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_c;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cs_n;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dm_dbi_n;
  sc_core::sc_out< sc_dt::sc_bv<64> > ch0_ddr4_dq;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dqs_c;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dqs_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_odt;
  sc_core::sc_out< bool > ch0_ddr4_reset_n;
  sc_core::sc_out< bool > ch0_ddr4_act_n;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_0;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_0;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_1;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_1;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_2;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_2;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_3;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_3;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_0;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_0;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_1;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_1;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_2;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_2;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_3;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_3;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_3;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_3;
  sc_core::sc_in< bool > from_noc_0;
  sc_core::sc_in< bool > from_noc_1;
  sc_core::sc_in< bool > from_noc_2;
  sc_core::sc_in< bool > from_noc_3;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:


};
#endif // RIVIERA




#ifdef VCSSYSTEMC
class DllExport bd_8be5_MC0_ddrc_0 : public bd_8be5_MC0_ddrc_0_sc
{
public:

  bd_8be5_MC0_ddrc_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_MC0_ddrc_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > sys_clk_p;
  sc_core::sc_in< bool > sys_clk_n;
  sc_core::sc_out< sc_dt::sc_bv<17> > ch0_ddr4_adr;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_bg;
  sc_core::sc_out< sc_dt::sc_bv<2> > ch0_ddr4_ba;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cke;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_c;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cs_n;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dm_dbi_n;
  sc_core::sc_out< sc_dt::sc_bv<64> > ch0_ddr4_dq;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dqs_c;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dqs_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_odt;
  sc_core::sc_out< bool > ch0_ddr4_reset_n;
  sc_core::sc_out< bool > ch0_ddr4_act_n;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_0;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_0;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_1;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_1;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_2;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_2;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_3;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_3;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_0;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_0;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_1;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_1;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_2;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_2;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_3;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_3;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_3;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_3;
  sc_core::sc_in< bool > from_noc_0;
  sc_core::sc_in< bool > from_noc_1;
  sc_core::sc_in< bool > from_noc_2;
  sc_core::sc_in< bool > from_noc_3;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:


  // Transactor stubs

  // Socket stubs

};
#endif // VCSSYSTEMC




#ifdef MTI_SYSTEMC
class DllExport bd_8be5_MC0_ddrc_0 : public bd_8be5_MC0_ddrc_0_sc
{
public:

  bd_8be5_MC0_ddrc_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_MC0_ddrc_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > sys_clk_p;
  sc_core::sc_in< bool > sys_clk_n;
  sc_core::sc_out< sc_dt::sc_bv<17> > ch0_ddr4_adr;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_bg;
  sc_core::sc_out< sc_dt::sc_bv<2> > ch0_ddr4_ba;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cke;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_ck_c;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_cs_n;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dm_dbi_n;
  sc_core::sc_out< sc_dt::sc_bv<64> > ch0_ddr4_dq;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dqs_c;
  sc_core::sc_out< sc_dt::sc_bv<8> > ch0_ddr4_dqs_t;
  sc_core::sc_out< sc_dt::sc_bv<1> > ch0_ddr4_odt;
  sc_core::sc_out< bool > ch0_ddr4_reset_n;
  sc_core::sc_out< bool > ch0_ddr4_act_n;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_0;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_0;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_1;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_1;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_2;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_2;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_valid_in_3;
  sc_core::sc_in< sc_dt::sc_bv<182> > noc2dmc_data_in_3;
  sc_core::sc_in< bool > noc2dmc_credit_rdy_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_credit_rtn_3;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_0;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_0;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_0;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_0;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_1;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_1;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_1;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_1;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_2;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_2;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_2;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_2;
  sc_core::sc_out< sc_dt::sc_bv<8> > dmc2noc_valid_out_3;
  sc_core::sc_out< sc_dt::sc_bv<182> > dmc2noc_data_out_3;
  sc_core::sc_out< bool > dmc2noc_credit_rdy_3;
  sc_core::sc_in< sc_dt::sc_bv<8> > noc2dmc_credit_rtn_3;
  sc_core::sc_in< bool > from_noc_0;
  sc_core::sc_in< bool > from_noc_1;
  sc_core::sc_in< bool > from_noc_2;
  sc_core::sc_in< bool > from_noc_3;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:


  // Transactor stubs

  // Socket stubs

};
#endif // MTI_SYSTEMC
#endif // IP_BD_8BE5_MC0_DDRC_0_H_
