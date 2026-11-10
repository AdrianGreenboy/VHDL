//**********************************************************************
// Copyright (c) 2016-2019 Xilinx Inc.  All Rights Reserved
//
//   TLM wrapper for NoC mc_ddr4.
//
//**********************************************************************
#ifndef bd_8be5_MC0_ddrc_0_core_h_
#define bd_8be5_MC0_ddrc_0_core_h_

#include "NOCDdrMcXtlm.h"
#include "properties.h"

class bd_8be5_MC0_ddrc_0_core : public NOCDdrMcXtlm
{
public:
  bd_8be5_MC0_ddrc_0_core( sc_core::sc_module_name nm, const xsc::common_cpp::properties& props )
  : NOCDdrMcXtlm(nm, props)
  {
  }

  virtual ~bd_8be5_MC0_ddrc_0_core()
  {
  }

public:  // stub pin-to-pin RTL interface

  sc_core::sc_in< bool >sys_clk_p;
  sc_core::sc_in< bool >sys_clk_n;
  sc_core::sc_out<sc_bv<17> >ch0_ddr4_adr;
  sc_core::sc_out<sc_bv<1> >ch0_ddr4_bg;
  sc_core::sc_out<sc_bv<2> >ch0_ddr4_ba;
  sc_core::sc_out<sc_bv<1> >ch0_ddr4_cke;
  sc_core::sc_out<sc_bv<1> >ch0_ddr4_ck_t;
  sc_core::sc_out<sc_bv<1> >ch0_ddr4_ck_c;
  sc_core::sc_out<sc_bv<1> >ch0_ddr4_cs_n;
  sc_core::sc_out<sc_bv<8> >ch0_ddr4_dm_dbi_n;
  sc_core::sc_out<sc_bv<64> >ch0_ddr4_dq;
  sc_core::sc_out<sc_bv<8> >ch0_ddr4_dqs_c;
  sc_core::sc_out<sc_bv<8> >ch0_ddr4_dqs_t;
  sc_core::sc_out<sc_bv<1> >ch0_ddr4_odt;
  sc_core::sc_out< bool >ch0_ddr4_reset_n;
  sc_core::sc_out< bool >ch0_ddr4_act_n;
  sc_core::sc_in<sc_bv<8> >noc2dmc_valid_in_0;
  sc_core::sc_in<sc_bv<182> >noc2dmc_data_in_0;
  sc_core::sc_in< bool >noc2dmc_credit_rdy_0;
  sc_core::sc_out<sc_bv<8> >dmc2noc_credit_rtn_0;
  sc_core::sc_in<sc_bv<8> >noc2dmc_valid_in_1;
  sc_core::sc_in<sc_bv<182> >noc2dmc_data_in_1;
  sc_core::sc_in< bool >noc2dmc_credit_rdy_1;
  sc_core::sc_out<sc_bv<8> >dmc2noc_credit_rtn_1;
  sc_core::sc_in<sc_bv<8> >noc2dmc_valid_in_2;
  sc_core::sc_in<sc_bv<182> >noc2dmc_data_in_2;
  sc_core::sc_in< bool >noc2dmc_credit_rdy_2;
  sc_core::sc_out<sc_bv<8> >dmc2noc_credit_rtn_2;
  sc_core::sc_in<sc_bv<8> >noc2dmc_valid_in_3;
  sc_core::sc_in<sc_bv<182> >noc2dmc_data_in_3;
  sc_core::sc_in< bool >noc2dmc_credit_rdy_3;
  sc_core::sc_out<sc_bv<8> >dmc2noc_credit_rtn_3;
  sc_core::sc_out<sc_bv<8> >dmc2noc_valid_out_0;
  sc_core::sc_out<sc_bv<182> >dmc2noc_data_out_0;
  sc_core::sc_out< bool >dmc2noc_credit_rdy_0;
  sc_core::sc_in<sc_bv<8> >noc2dmc_credit_rtn_0;
  sc_core::sc_out<sc_bv<8> >dmc2noc_valid_out_1;
  sc_core::sc_out<sc_bv<182> >dmc2noc_data_out_1;
  sc_core::sc_out< bool >dmc2noc_credit_rdy_1;
  sc_core::sc_in<sc_bv<8> >noc2dmc_credit_rtn_1;
  sc_core::sc_out<sc_bv<8> >dmc2noc_valid_out_2;
  sc_core::sc_out<sc_bv<182> >dmc2noc_data_out_2;
  sc_core::sc_out< bool >dmc2noc_credit_rdy_2;
  sc_core::sc_in<sc_bv<8> >noc2dmc_credit_rtn_2;
  sc_core::sc_out<sc_bv<8> >dmc2noc_valid_out_3;
  sc_core::sc_out<sc_bv<182> >dmc2noc_data_out_3;
  sc_core::sc_out< bool >dmc2noc_credit_rdy_3;
  sc_core::sc_in<sc_bv<8> >noc2dmc_credit_rtn_3;
  sc_core::sc_in< bool >from_noc_0;
  sc_core::sc_in< bool >from_noc_1;
  sc_core::sc_in< bool >from_noc_2;
  sc_core::sc_in< bool >from_noc_3;
};

#endif
