#ifndef IP_BD_8BE5_S04_AXI_RPU_0_H_
#define IP_BD_8BE5_S04_AXI_RPU_0_H_

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

#include "bd_8be5_S04_AXI_rpu_0_sc.h"




#ifdef XILINX_SIMULATOR
class DllExport bd_8be5_S04_AXI_rpu_0 : public bd_8be5_S04_AXI_rpu_0_sc
{
public:

  bd_8be5_S04_AXI_rpu_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_S04_AXI_rpu_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > IF_NOC_AXI_WVALID;
  sc_core::sc_out< bool > IF_NOC_AXI_WREADY;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_WLAST;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_AWID;
  sc_core::sc_in< sc_dt::sc_bv<128> > IF_NOC_AXI_WDATA;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_WSTRB;
  sc_core::sc_out< bool > IF_NOC_AXI_ARREADY;
  sc_core::sc_out< bool > IF_NOC_AXI_AWREADY;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_BID;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_BRESP;
  sc_core::sc_out< bool > IF_NOC_AXI_BVALID;
  sc_core::sc_out< sc_dt::sc_bv<128> > IF_NOC_AXI_RDATA;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_RID;
  sc_core::sc_out< sc_dt::sc_bv<1> > IF_NOC_AXI_RLAST;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_RRESP;
  sc_core::sc_out< sc_dt::sc_bv<17> > IF_NOC_AXI_RUSER;
  sc_core::sc_out< bool > IF_NOC_AXI_RVALID;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_CREDIT_RETURN;
  sc_core::sc_out< bool > IF_NOC_NPP_OUT_NOC_CREDIT_RDY;
  sc_core::sc_out< sc_dt::sc_bv<182> > IF_NOC_NPP_OUT_NOC_FLIT;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_VALID;
  sc_core::sc_in< bool > aclk;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_ARADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_ARBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARCACHE;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_ARID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_ARLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_ARLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_ARUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_ARVALID;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_AWADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_AWBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWCACHE;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_AWLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_AWLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_AWUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_AWVALID;
  sc_core::sc_in< bool > IF_NOC_AXI_BREADY;
  sc_core::sc_in< bool > IF_NOC_AXI_RREADY;
  sc_core::sc_in< sc_dt::sc_bv<17> > IF_NOC_AXI_WUSER;
  sc_core::sc_in< bool > IF_NOC_NPP_IN_NOC_CREDIT_RDY;
  sc_core::sc_in< sc_dt::sc_bv<182> > IF_NOC_NPP_IN_NOC_FLIT;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_VALID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_CREDIT_RETURN;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_WR_USR_DST;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_RD_USR_DST;
  sc_core::sc_out< bool > NMU;
  sc_core::sc_in< bool > AXI_IN;
  sc_core::sc_in< bool > NMU_RD_DEST_MODE;
  sc_core::sc_in< bool > NMU_WR_DEST_MODE;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:

  xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>* mp_SAXI4_transactor;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_ARLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_ARLOCK_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_AWLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_AWLOCK_converter_signal;
  xsc::common::scalar2vectorN_converter<1>* mp_IF_NOC_AXI_RLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_RLAST_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_WLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_WLAST_converter_signal;
  sc_signal< bool > m_SAXI4_transactor_rst_signal;

};
#endif // XILINX_SIMULATOR




#ifdef XM_SYSTEMC
class DllExport bd_8be5_S04_AXI_rpu_0 : public bd_8be5_S04_AXI_rpu_0_sc
{
public:

  bd_8be5_S04_AXI_rpu_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_S04_AXI_rpu_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > IF_NOC_AXI_WVALID;
  sc_core::sc_out< bool > IF_NOC_AXI_WREADY;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_WLAST;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_AWID;
  sc_core::sc_in< sc_dt::sc_bv<128> > IF_NOC_AXI_WDATA;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_WSTRB;
  sc_core::sc_out< bool > IF_NOC_AXI_ARREADY;
  sc_core::sc_out< bool > IF_NOC_AXI_AWREADY;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_BID;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_BRESP;
  sc_core::sc_out< bool > IF_NOC_AXI_BVALID;
  sc_core::sc_out< sc_dt::sc_bv<128> > IF_NOC_AXI_RDATA;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_RID;
  sc_core::sc_out< sc_dt::sc_bv<1> > IF_NOC_AXI_RLAST;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_RRESP;
  sc_core::sc_out< sc_dt::sc_bv<17> > IF_NOC_AXI_RUSER;
  sc_core::sc_out< bool > IF_NOC_AXI_RVALID;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_CREDIT_RETURN;
  sc_core::sc_out< bool > IF_NOC_NPP_OUT_NOC_CREDIT_RDY;
  sc_core::sc_out< sc_dt::sc_bv<182> > IF_NOC_NPP_OUT_NOC_FLIT;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_VALID;
  sc_core::sc_in< bool > aclk;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_ARADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_ARBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARCACHE;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_ARID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_ARLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_ARLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_ARUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_ARVALID;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_AWADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_AWBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWCACHE;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_AWLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_AWLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_AWUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_AWVALID;
  sc_core::sc_in< bool > IF_NOC_AXI_BREADY;
  sc_core::sc_in< bool > IF_NOC_AXI_RREADY;
  sc_core::sc_in< sc_dt::sc_bv<17> > IF_NOC_AXI_WUSER;
  sc_core::sc_in< bool > IF_NOC_NPP_IN_NOC_CREDIT_RDY;
  sc_core::sc_in< sc_dt::sc_bv<182> > IF_NOC_NPP_IN_NOC_FLIT;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_VALID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_CREDIT_RETURN;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_WR_USR_DST;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_RD_USR_DST;
  sc_core::sc_out< bool > NMU;
  sc_core::sc_in< bool > AXI_IN;
  sc_core::sc_in< bool > NMU_RD_DEST_MODE;
  sc_core::sc_in< bool > NMU_WR_DEST_MODE;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:

  xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>* mp_SAXI4_transactor;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_ARLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_ARLOCK_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_AWLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_AWLOCK_converter_signal;
  xsc::common::scalar2vectorN_converter<1>* mp_IF_NOC_AXI_RLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_RLAST_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_WLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_WLAST_converter_signal;
  sc_signal< bool > m_SAXI4_transactor_rst_signal;

};
#endif // XM_SYSTEMC




#ifdef RIVIERA
class DllExport bd_8be5_S04_AXI_rpu_0 : public bd_8be5_S04_AXI_rpu_0_sc
{
public:

  bd_8be5_S04_AXI_rpu_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_S04_AXI_rpu_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > IF_NOC_AXI_WVALID;
  sc_core::sc_out< bool > IF_NOC_AXI_WREADY;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_WLAST;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_AWID;
  sc_core::sc_in< sc_dt::sc_bv<128> > IF_NOC_AXI_WDATA;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_WSTRB;
  sc_core::sc_out< bool > IF_NOC_AXI_ARREADY;
  sc_core::sc_out< bool > IF_NOC_AXI_AWREADY;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_BID;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_BRESP;
  sc_core::sc_out< bool > IF_NOC_AXI_BVALID;
  sc_core::sc_out< sc_dt::sc_bv<128> > IF_NOC_AXI_RDATA;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_RID;
  sc_core::sc_out< sc_dt::sc_bv<1> > IF_NOC_AXI_RLAST;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_RRESP;
  sc_core::sc_out< sc_dt::sc_bv<17> > IF_NOC_AXI_RUSER;
  sc_core::sc_out< bool > IF_NOC_AXI_RVALID;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_CREDIT_RETURN;
  sc_core::sc_out< bool > IF_NOC_NPP_OUT_NOC_CREDIT_RDY;
  sc_core::sc_out< sc_dt::sc_bv<182> > IF_NOC_NPP_OUT_NOC_FLIT;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_VALID;
  sc_core::sc_in< bool > aclk;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_ARADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_ARBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARCACHE;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_ARID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_ARLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_ARLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_ARUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_ARVALID;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_AWADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_AWBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWCACHE;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_AWLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_AWLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_AWUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_AWVALID;
  sc_core::sc_in< bool > IF_NOC_AXI_BREADY;
  sc_core::sc_in< bool > IF_NOC_AXI_RREADY;
  sc_core::sc_in< sc_dt::sc_bv<17> > IF_NOC_AXI_WUSER;
  sc_core::sc_in< bool > IF_NOC_NPP_IN_NOC_CREDIT_RDY;
  sc_core::sc_in< sc_dt::sc_bv<182> > IF_NOC_NPP_IN_NOC_FLIT;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_VALID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_CREDIT_RETURN;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_WR_USR_DST;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_RD_USR_DST;
  sc_core::sc_out< bool > NMU;
  sc_core::sc_in< bool > AXI_IN;
  sc_core::sc_in< bool > NMU_RD_DEST_MODE;
  sc_core::sc_in< bool > NMU_WR_DEST_MODE;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:

  xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>* mp_SAXI4_transactor;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_ARLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_ARLOCK_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_AWLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_AWLOCK_converter_signal;
  xsc::common::scalar2vectorN_converter<1>* mp_IF_NOC_AXI_RLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_RLAST_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_WLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_WLAST_converter_signal;
  sc_signal< bool > m_SAXI4_transactor_rst_signal;

};
#endif // RIVIERA




#ifdef VCSSYSTEMC
#include "utils/xtlm_aximm_target_stub.h"

class DllExport bd_8be5_S04_AXI_rpu_0 : public bd_8be5_S04_AXI_rpu_0_sc
{
public:

  bd_8be5_S04_AXI_rpu_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_S04_AXI_rpu_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > IF_NOC_AXI_WVALID;
  sc_core::sc_out< bool > IF_NOC_AXI_WREADY;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_WLAST;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_AWID;
  sc_core::sc_in< sc_dt::sc_bv<128> > IF_NOC_AXI_WDATA;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_WSTRB;
  sc_core::sc_out< bool > IF_NOC_AXI_ARREADY;
  sc_core::sc_out< bool > IF_NOC_AXI_AWREADY;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_BID;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_BRESP;
  sc_core::sc_out< bool > IF_NOC_AXI_BVALID;
  sc_core::sc_out< sc_dt::sc_bv<128> > IF_NOC_AXI_RDATA;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_RID;
  sc_core::sc_out< sc_dt::sc_bv<1> > IF_NOC_AXI_RLAST;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_RRESP;
  sc_core::sc_out< sc_dt::sc_bv<17> > IF_NOC_AXI_RUSER;
  sc_core::sc_out< bool > IF_NOC_AXI_RVALID;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_CREDIT_RETURN;
  sc_core::sc_out< bool > IF_NOC_NPP_OUT_NOC_CREDIT_RDY;
  sc_core::sc_out< sc_dt::sc_bv<182> > IF_NOC_NPP_OUT_NOC_FLIT;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_VALID;
  sc_core::sc_in< bool > aclk;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_ARADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_ARBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARCACHE;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_ARID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_ARLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_ARLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_ARUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_ARVALID;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_AWADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_AWBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWCACHE;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_AWLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_AWLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_AWUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_AWVALID;
  sc_core::sc_in< bool > IF_NOC_AXI_BREADY;
  sc_core::sc_in< bool > IF_NOC_AXI_RREADY;
  sc_core::sc_in< sc_dt::sc_bv<17> > IF_NOC_AXI_WUSER;
  sc_core::sc_in< bool > IF_NOC_NPP_IN_NOC_CREDIT_RDY;
  sc_core::sc_in< sc_dt::sc_bv<182> > IF_NOC_NPP_IN_NOC_FLIT;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_VALID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_CREDIT_RETURN;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_WR_USR_DST;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_RD_USR_DST;
  sc_core::sc_out< bool > NMU;
  sc_core::sc_in< bool > AXI_IN;
  sc_core::sc_in< bool > NMU_RD_DEST_MODE;
  sc_core::sc_in< bool > NMU_WR_DEST_MODE;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:

  xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>* mp_SAXI4_transactor;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_ARLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_ARLOCK_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_AWLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_AWLOCK_converter_signal;
  xsc::common::scalar2vectorN_converter<1>* mp_IF_NOC_AXI_RLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_RLAST_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_WLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_WLAST_converter_signal;
  sc_signal< bool > m_SAXI4_transactor_rst_signal;

  // Transactor stubs
  xtlm::xtlm_aximm_target_stub * SAXI4_transactor_target_rd_socket_stub;
  xtlm::xtlm_aximm_target_stub * SAXI4_transactor_target_wr_socket_stub;

  // Socket stubs

};
#endif // VCSSYSTEMC




#ifdef MTI_SYSTEMC
#include "utils/xtlm_aximm_target_stub.h"

class DllExport bd_8be5_S04_AXI_rpu_0 : public bd_8be5_S04_AXI_rpu_0_sc
{
public:

  bd_8be5_S04_AXI_rpu_0(const sc_core::sc_module_name& nm);
  virtual ~bd_8be5_S04_AXI_rpu_0();

  // module pin-to-pin RTL interface

  sc_core::sc_in< bool > IF_NOC_AXI_WVALID;
  sc_core::sc_out< bool > IF_NOC_AXI_WREADY;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_WLAST;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_AWID;
  sc_core::sc_in< sc_dt::sc_bv<128> > IF_NOC_AXI_WDATA;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_WSTRB;
  sc_core::sc_out< bool > IF_NOC_AXI_ARREADY;
  sc_core::sc_out< bool > IF_NOC_AXI_AWREADY;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_BID;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_BRESP;
  sc_core::sc_out< bool > IF_NOC_AXI_BVALID;
  sc_core::sc_out< sc_dt::sc_bv<128> > IF_NOC_AXI_RDATA;
  sc_core::sc_out< sc_dt::sc_bv<16> > IF_NOC_AXI_RID;
  sc_core::sc_out< sc_dt::sc_bv<1> > IF_NOC_AXI_RLAST;
  sc_core::sc_out< sc_dt::sc_bv<2> > IF_NOC_AXI_RRESP;
  sc_core::sc_out< sc_dt::sc_bv<17> > IF_NOC_AXI_RUSER;
  sc_core::sc_out< bool > IF_NOC_AXI_RVALID;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_CREDIT_RETURN;
  sc_core::sc_out< bool > IF_NOC_NPP_OUT_NOC_CREDIT_RDY;
  sc_core::sc_out< sc_dt::sc_bv<182> > IF_NOC_NPP_OUT_NOC_FLIT;
  sc_core::sc_out< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_VALID;
  sc_core::sc_in< bool > aclk;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_ARADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_ARBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARCACHE;
  sc_core::sc_in< sc_dt::sc_bv<16> > IF_NOC_AXI_ARID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_ARLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_ARLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_ARREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_ARSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_ARUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_ARVALID;
  sc_core::sc_in< sc_dt::sc_bv<64> > IF_NOC_AXI_AWADDR;
  sc_core::sc_in< sc_dt::sc_bv<2> > IF_NOC_AXI_AWBURST;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWCACHE;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_AXI_AWLEN;
  sc_core::sc_in< sc_dt::sc_bv<1> > IF_NOC_AXI_AWLOCK;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWPROT;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWQOS;
  sc_core::sc_in< sc_dt::sc_bv<4> > IF_NOC_AXI_AWREGION;
  sc_core::sc_in< sc_dt::sc_bv<3> > IF_NOC_AXI_AWSIZE;
  sc_core::sc_in< sc_dt::sc_bv<18> > IF_NOC_AXI_AWUSER;
  sc_core::sc_in< bool > IF_NOC_AXI_AWVALID;
  sc_core::sc_in< bool > IF_NOC_AXI_BREADY;
  sc_core::sc_in< bool > IF_NOC_AXI_RREADY;
  sc_core::sc_in< sc_dt::sc_bv<17> > IF_NOC_AXI_WUSER;
  sc_core::sc_in< bool > IF_NOC_NPP_IN_NOC_CREDIT_RDY;
  sc_core::sc_in< sc_dt::sc_bv<182> > IF_NOC_NPP_IN_NOC_FLIT;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_IN_NOC_VALID;
  sc_core::sc_in< sc_dt::sc_bv<8> > IF_NOC_NPP_OUT_NOC_CREDIT_RETURN;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_WR_USR_DST;
  sc_core::sc_in< sc_dt::sc_bv<12> > NMU_RD_USR_DST;
  sc_core::sc_out< bool > NMU;
  sc_core::sc_in< bool > AXI_IN;
  sc_core::sc_in< bool > NMU_RD_DEST_MODE;
  sc_core::sc_in< bool > NMU_WR_DEST_MODE;

  // Dummy Signals for IP Ports


protected:

  virtual void before_end_of_elaboration();

private:

  xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>* mp_SAXI4_transactor;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_ARLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_ARLOCK_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_AWLOCK_converter;
  sc_signal< bool > m_IF_NOC_AXI_AWLOCK_converter_signal;
  xsc::common::scalar2vectorN_converter<1>* mp_IF_NOC_AXI_RLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_RLAST_converter_signal;
  xsc::common::vectorN2scalar_converter<1>* mp_IF_NOC_AXI_WLAST_converter;
  sc_signal< bool > m_IF_NOC_AXI_WLAST_converter_signal;
  sc_signal< bool > m_SAXI4_transactor_rst_signal;

  // Transactor stubs
  xtlm::xtlm_aximm_target_stub * SAXI4_transactor_target_rd_socket_stub;
  xtlm::xtlm_aximm_target_stub * SAXI4_transactor_target_wr_socket_stub;

  // Socket stubs

};
#endif // MTI_SYSTEMC
#endif // IP_BD_8BE5_S04_AXI_RPU_0_H_
