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


#include "bd_b77b_S00_AXI_nmu_0_sc.h"

#include "bd_b77b_S00_AXI_nmu_0.h"

#include "bd_b77b_S00_AXI_nmu_0_core.h"

#include <map>
#include <string>





#ifdef XILINX_SIMULATOR
bd_b77b_S00_AXI_nmu_0::bd_b77b_S00_AXI_nmu_0(const sc_core::sc_module_name& nm) : bd_b77b_S00_AXI_nmu_0_sc(nm), IF_NOC_AXI_WVALID("IF_NOC_AXI_WVALID"), IF_NOC_AXI_WREADY("IF_NOC_AXI_WREADY"), IF_NOC_AXI_WLAST("IF_NOC_AXI_WLAST"), IF_NOC_AXI_AWID("IF_NOC_AXI_AWID"), IF_NOC_AXI_WDATA("IF_NOC_AXI_WDATA"), IF_NOC_AXI_WSTRB("IF_NOC_AXI_WSTRB"), IF_NOC_AXI_ARREADY("IF_NOC_AXI_ARREADY"), IF_NOC_AXI_AWREADY("IF_NOC_AXI_AWREADY"), IF_NOC_AXI_BID("IF_NOC_AXI_BID"), IF_NOC_AXI_BRESP("IF_NOC_AXI_BRESP"), IF_NOC_AXI_BVALID("IF_NOC_AXI_BVALID"), IF_NOC_AXI_RDATA("IF_NOC_AXI_RDATA"), IF_NOC_AXI_RID("IF_NOC_AXI_RID"), IF_NOC_AXI_RLAST("IF_NOC_AXI_RLAST"), IF_NOC_AXI_RRESP("IF_NOC_AXI_RRESP"), IF_NOC_AXI_RUSER("IF_NOC_AXI_RUSER"), IF_NOC_AXI_RVALID("IF_NOC_AXI_RVALID"), IF_NOC_NPP_IN_NOC_CREDIT_RETURN("IF_NOC_NPP_IN_NOC_CREDIT_RETURN"), IF_NOC_NPP_OUT_NOC_CREDIT_RDY("IF_NOC_NPP_OUT_NOC_CREDIT_RDY"), IF_NOC_NPP_OUT_NOC_FLIT("IF_NOC_NPP_OUT_NOC_FLIT"), IF_NOC_NPP_OUT_NOC_VALID("IF_NOC_NPP_OUT_NOC_VALID"), aclk("aclk"), IF_NOC_AXI_ARADDR("IF_NOC_AXI_ARADDR"), IF_NOC_AXI_ARBURST("IF_NOC_AXI_ARBURST"), IF_NOC_AXI_ARCACHE("IF_NOC_AXI_ARCACHE"), IF_NOC_AXI_ARID("IF_NOC_AXI_ARID"), IF_NOC_AXI_ARLEN("IF_NOC_AXI_ARLEN"), IF_NOC_AXI_ARLOCK("IF_NOC_AXI_ARLOCK"), IF_NOC_AXI_ARPROT("IF_NOC_AXI_ARPROT"), IF_NOC_AXI_ARQOS("IF_NOC_AXI_ARQOS"), IF_NOC_AXI_ARREGION("IF_NOC_AXI_ARREGION"), IF_NOC_AXI_ARSIZE("IF_NOC_AXI_ARSIZE"), IF_NOC_AXI_ARUSER("IF_NOC_AXI_ARUSER"), IF_NOC_AXI_ARVALID("IF_NOC_AXI_ARVALID"), IF_NOC_AXI_AWADDR("IF_NOC_AXI_AWADDR"), IF_NOC_AXI_AWBURST("IF_NOC_AXI_AWBURST"), IF_NOC_AXI_AWCACHE("IF_NOC_AXI_AWCACHE"), IF_NOC_AXI_AWLEN("IF_NOC_AXI_AWLEN"), IF_NOC_AXI_AWLOCK("IF_NOC_AXI_AWLOCK"), IF_NOC_AXI_AWPROT("IF_NOC_AXI_AWPROT"), IF_NOC_AXI_AWQOS("IF_NOC_AXI_AWQOS"), IF_NOC_AXI_AWREGION("IF_NOC_AXI_AWREGION"), IF_NOC_AXI_AWSIZE("IF_NOC_AXI_AWSIZE"), IF_NOC_AXI_AWUSER("IF_NOC_AXI_AWUSER"), IF_NOC_AXI_AWVALID("IF_NOC_AXI_AWVALID"), IF_NOC_AXI_BREADY("IF_NOC_AXI_BREADY"), IF_NOC_AXI_RREADY("IF_NOC_AXI_RREADY"), IF_NOC_AXI_WUSER("IF_NOC_AXI_WUSER"), IF_NOC_NPP_IN_NOC_CREDIT_RDY("IF_NOC_NPP_IN_NOC_CREDIT_RDY"), IF_NOC_NPP_IN_NOC_FLIT("IF_NOC_NPP_IN_NOC_FLIT"), IF_NOC_NPP_IN_NOC_VALID("IF_NOC_NPP_IN_NOC_VALID"), IF_NOC_NPP_OUT_NOC_CREDIT_RETURN("IF_NOC_NPP_OUT_NOC_CREDIT_RETURN"), NMU_WR_USR_DST("NMU_WR_USR_DST"), NMU_RD_USR_DST("NMU_RD_USR_DST"), NMU("NMU"), AXI_IN("AXI_IN"), NMU_RD_DEST_MODE("NMU_RD_DEST_MODE"), NMU_WR_DEST_MODE("NMU_WR_DEST_MODE")
{

  // initialize pins
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RETURN(IF_NOC_NPP_IN_NOC_CREDIT_RETURN);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RDY(IF_NOC_NPP_OUT_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_OUT_NOC_FLIT(IF_NOC_NPP_OUT_NOC_FLIT);
  mp_impl->IF_NOC_NPP_OUT_NOC_VALID(IF_NOC_NPP_OUT_NOC_VALID);
  mp_impl->aclk(aclk);
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RDY(IF_NOC_NPP_IN_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_IN_NOC_FLIT(IF_NOC_NPP_IN_NOC_FLIT);
  mp_impl->IF_NOC_NPP_IN_NOC_VALID(IF_NOC_NPP_IN_NOC_VALID);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RETURN(IF_NOC_NPP_OUT_NOC_CREDIT_RETURN);
  mp_impl->NMU_WR_USR_DST(NMU_WR_USR_DST);
  mp_impl->NMU_RD_USR_DST(NMU_RD_USR_DST);
  mp_impl->NMU(NMU);
  mp_impl->AXI_IN(AXI_IN);
  mp_impl->NMU_RD_DEST_MODE(NMU_RD_DEST_MODE);
  mp_impl->NMU_WR_DEST_MODE(NMU_WR_DEST_MODE);

  // initialize transactors
  mp_SAXI4_transactor = NULL;
  mp_IF_NOC_AXI_ARLOCK_converter = NULL;
  mp_IF_NOC_AXI_AWLOCK_converter = NULL;
  mp_IF_NOC_AXI_RLAST_converter = NULL;
  mp_IF_NOC_AXI_WLAST_converter = NULL;

  // initialize socket stubs

}

void bd_b77b_S00_AXI_nmu_0::before_end_of_elaboration()
{
  // configure 'SAXI4' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_b77b_S00_AXI_nmu_0", "SAXI4_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'SAXI4' transactor parameters
    xsc::common_cpp::properties SAXI4_transactor_param_props;
    SAXI4_transactor_param_props.addLong("DATA_WIDTH", "128");
    SAXI4_transactor_param_props.addLong("FREQ_HZ", "550000000");
    SAXI4_transactor_param_props.addLong("ID_WIDTH", "16");
    SAXI4_transactor_param_props.addLong("ADDR_WIDTH", "64");
    SAXI4_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("WUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("RUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("BUSER_WIDTH", "0");
    SAXI4_transactor_param_props.addLong("HAS_BURST", "1");
    SAXI4_transactor_param_props.addLong("HAS_LOCK", "1");
    SAXI4_transactor_param_props.addLong("HAS_PROT", "1");
    SAXI4_transactor_param_props.addLong("HAS_CACHE", "1");
    SAXI4_transactor_param_props.addLong("HAS_QOS", "1");
    SAXI4_transactor_param_props.addLong("HAS_REGION", "1");
    SAXI4_transactor_param_props.addLong("HAS_WSTRB", "1");
    SAXI4_transactor_param_props.addLong("HAS_BRESP", "1");
    SAXI4_transactor_param_props.addLong("HAS_RRESP", "1");
    SAXI4_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    SAXI4_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    SAXI4_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    SAXI4_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("HAS_SIZE", "1");
    SAXI4_transactor_param_props.addLong("HAS_RESET", "0");
    SAXI4_transactor_param_props.addFloat("PHASE", "0.0");
    SAXI4_transactor_param_props.addString("PROTOCOL", "AXI4");
    SAXI4_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    SAXI4_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");

    mp_SAXI4_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("SAXI4_transactor", SAXI4_transactor_param_props);

    // SAXI4' transactor ports

    mp_SAXI4_transactor->ARADDR(IF_NOC_AXI_ARADDR);
    mp_SAXI4_transactor->ARBURST(IF_NOC_AXI_ARBURST);
    mp_SAXI4_transactor->ARCACHE(IF_NOC_AXI_ARCACHE);
    mp_SAXI4_transactor->ARID(IF_NOC_AXI_ARID);
    mp_SAXI4_transactor->ARLEN(IF_NOC_AXI_ARLEN);
    mp_IF_NOC_AXI_ARLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_ARLOCK_converter");
    mp_IF_NOC_AXI_ARLOCK_converter->vector_in(IF_NOC_AXI_ARLOCK);
    mp_IF_NOC_AXI_ARLOCK_converter->scalar_out(m_IF_NOC_AXI_ARLOCK_converter_signal);
    mp_SAXI4_transactor->ARLOCK(m_IF_NOC_AXI_ARLOCK_converter_signal);
    mp_SAXI4_transactor->ARPROT(IF_NOC_AXI_ARPROT);
    mp_SAXI4_transactor->ARQOS(IF_NOC_AXI_ARQOS);
    mp_SAXI4_transactor->ARREADY(IF_NOC_AXI_ARREADY);
    mp_SAXI4_transactor->ARREGION(IF_NOC_AXI_ARREGION);
    mp_SAXI4_transactor->ARSIZE(IF_NOC_AXI_ARSIZE);
    mp_SAXI4_transactor->ARUSER(IF_NOC_AXI_ARUSER);
    mp_SAXI4_transactor->ARVALID(IF_NOC_AXI_ARVALID);
    mp_SAXI4_transactor->AWADDR(IF_NOC_AXI_AWADDR);
    mp_SAXI4_transactor->AWBURST(IF_NOC_AXI_AWBURST);
    mp_SAXI4_transactor->AWCACHE(IF_NOC_AXI_AWCACHE);
    mp_SAXI4_transactor->AWID(IF_NOC_AXI_AWID);
    mp_SAXI4_transactor->AWLEN(IF_NOC_AXI_AWLEN);
    mp_IF_NOC_AXI_AWLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_AWLOCK_converter");
    mp_IF_NOC_AXI_AWLOCK_converter->vector_in(IF_NOC_AXI_AWLOCK);
    mp_IF_NOC_AXI_AWLOCK_converter->scalar_out(m_IF_NOC_AXI_AWLOCK_converter_signal);
    mp_SAXI4_transactor->AWLOCK(m_IF_NOC_AXI_AWLOCK_converter_signal);
    mp_SAXI4_transactor->AWPROT(IF_NOC_AXI_AWPROT);
    mp_SAXI4_transactor->AWQOS(IF_NOC_AXI_AWQOS);
    mp_SAXI4_transactor->AWREADY(IF_NOC_AXI_AWREADY);
    mp_SAXI4_transactor->AWREGION(IF_NOC_AXI_AWREGION);
    mp_SAXI4_transactor->AWSIZE(IF_NOC_AXI_AWSIZE);
    mp_SAXI4_transactor->AWUSER(IF_NOC_AXI_AWUSER);
    mp_SAXI4_transactor->AWVALID(IF_NOC_AXI_AWVALID);
    mp_SAXI4_transactor->BID(IF_NOC_AXI_BID);
    mp_SAXI4_transactor->BREADY(IF_NOC_AXI_BREADY);
    mp_SAXI4_transactor->BRESP(IF_NOC_AXI_BRESP);
    mp_SAXI4_transactor->BVALID(IF_NOC_AXI_BVALID);
    mp_SAXI4_transactor->RDATA(IF_NOC_AXI_RDATA);
    mp_SAXI4_transactor->RID(IF_NOC_AXI_RID);
    mp_IF_NOC_AXI_RLAST_converter = new xsc::common::scalar2vectorN_converter<1>("IF_NOC_AXI_RLAST_converter");
    mp_IF_NOC_AXI_RLAST_converter->scalar_in(m_IF_NOC_AXI_RLAST_converter_signal);
    mp_IF_NOC_AXI_RLAST_converter->vector_out(IF_NOC_AXI_RLAST);
    mp_SAXI4_transactor->RLAST(m_IF_NOC_AXI_RLAST_converter_signal);
    mp_SAXI4_transactor->RREADY(IF_NOC_AXI_RREADY);
    mp_SAXI4_transactor->RRESP(IF_NOC_AXI_RRESP);
    mp_SAXI4_transactor->RUSER(IF_NOC_AXI_RUSER);
    mp_SAXI4_transactor->RVALID(IF_NOC_AXI_RVALID);
    mp_SAXI4_transactor->WDATA(IF_NOC_AXI_WDATA);
    mp_IF_NOC_AXI_WLAST_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_WLAST_converter");
    mp_IF_NOC_AXI_WLAST_converter->vector_in(IF_NOC_AXI_WLAST);
    mp_IF_NOC_AXI_WLAST_converter->scalar_out(m_IF_NOC_AXI_WLAST_converter_signal);
    mp_SAXI4_transactor->WLAST(m_IF_NOC_AXI_WLAST_converter_signal);
    mp_SAXI4_transactor->WREADY(IF_NOC_AXI_WREADY);
    mp_SAXI4_transactor->WSTRB(IF_NOC_AXI_WSTRB);
    mp_SAXI4_transactor->WUSER(IF_NOC_AXI_WUSER);
    mp_SAXI4_transactor->WVALID(IF_NOC_AXI_WVALID);
    mp_SAXI4_transactor->CLK(aclk);
    m_SAXI4_transactor_rst_signal.write(1);
    mp_SAXI4_transactor->RST(m_SAXI4_transactor_rst_signal);

    // SAXI4' transactor sockets

    mp_impl->SAXI4_rd_socket->bind(*(mp_SAXI4_transactor->rd_socket));
    mp_impl->SAXI4_wr_socket->bind(*(mp_SAXI4_transactor->wr_socket));
  }
  else
  {
  }

}

#endif // XILINX_SIMULATOR




#ifdef XM_SYSTEMC
bd_b77b_S00_AXI_nmu_0::bd_b77b_S00_AXI_nmu_0(const sc_core::sc_module_name& nm) : bd_b77b_S00_AXI_nmu_0_sc(nm), IF_NOC_AXI_WVALID("IF_NOC_AXI_WVALID"), IF_NOC_AXI_WREADY("IF_NOC_AXI_WREADY"), IF_NOC_AXI_WLAST("IF_NOC_AXI_WLAST"), IF_NOC_AXI_AWID("IF_NOC_AXI_AWID"), IF_NOC_AXI_WDATA("IF_NOC_AXI_WDATA"), IF_NOC_AXI_WSTRB("IF_NOC_AXI_WSTRB"), IF_NOC_AXI_ARREADY("IF_NOC_AXI_ARREADY"), IF_NOC_AXI_AWREADY("IF_NOC_AXI_AWREADY"), IF_NOC_AXI_BID("IF_NOC_AXI_BID"), IF_NOC_AXI_BRESP("IF_NOC_AXI_BRESP"), IF_NOC_AXI_BVALID("IF_NOC_AXI_BVALID"), IF_NOC_AXI_RDATA("IF_NOC_AXI_RDATA"), IF_NOC_AXI_RID("IF_NOC_AXI_RID"), IF_NOC_AXI_RLAST("IF_NOC_AXI_RLAST"), IF_NOC_AXI_RRESP("IF_NOC_AXI_RRESP"), IF_NOC_AXI_RUSER("IF_NOC_AXI_RUSER"), IF_NOC_AXI_RVALID("IF_NOC_AXI_RVALID"), IF_NOC_NPP_IN_NOC_CREDIT_RETURN("IF_NOC_NPP_IN_NOC_CREDIT_RETURN"), IF_NOC_NPP_OUT_NOC_CREDIT_RDY("IF_NOC_NPP_OUT_NOC_CREDIT_RDY"), IF_NOC_NPP_OUT_NOC_FLIT("IF_NOC_NPP_OUT_NOC_FLIT"), IF_NOC_NPP_OUT_NOC_VALID("IF_NOC_NPP_OUT_NOC_VALID"), aclk("aclk"), IF_NOC_AXI_ARADDR("IF_NOC_AXI_ARADDR"), IF_NOC_AXI_ARBURST("IF_NOC_AXI_ARBURST"), IF_NOC_AXI_ARCACHE("IF_NOC_AXI_ARCACHE"), IF_NOC_AXI_ARID("IF_NOC_AXI_ARID"), IF_NOC_AXI_ARLEN("IF_NOC_AXI_ARLEN"), IF_NOC_AXI_ARLOCK("IF_NOC_AXI_ARLOCK"), IF_NOC_AXI_ARPROT("IF_NOC_AXI_ARPROT"), IF_NOC_AXI_ARQOS("IF_NOC_AXI_ARQOS"), IF_NOC_AXI_ARREGION("IF_NOC_AXI_ARREGION"), IF_NOC_AXI_ARSIZE("IF_NOC_AXI_ARSIZE"), IF_NOC_AXI_ARUSER("IF_NOC_AXI_ARUSER"), IF_NOC_AXI_ARVALID("IF_NOC_AXI_ARVALID"), IF_NOC_AXI_AWADDR("IF_NOC_AXI_AWADDR"), IF_NOC_AXI_AWBURST("IF_NOC_AXI_AWBURST"), IF_NOC_AXI_AWCACHE("IF_NOC_AXI_AWCACHE"), IF_NOC_AXI_AWLEN("IF_NOC_AXI_AWLEN"), IF_NOC_AXI_AWLOCK("IF_NOC_AXI_AWLOCK"), IF_NOC_AXI_AWPROT("IF_NOC_AXI_AWPROT"), IF_NOC_AXI_AWQOS("IF_NOC_AXI_AWQOS"), IF_NOC_AXI_AWREGION("IF_NOC_AXI_AWREGION"), IF_NOC_AXI_AWSIZE("IF_NOC_AXI_AWSIZE"), IF_NOC_AXI_AWUSER("IF_NOC_AXI_AWUSER"), IF_NOC_AXI_AWVALID("IF_NOC_AXI_AWVALID"), IF_NOC_AXI_BREADY("IF_NOC_AXI_BREADY"), IF_NOC_AXI_RREADY("IF_NOC_AXI_RREADY"), IF_NOC_AXI_WUSER("IF_NOC_AXI_WUSER"), IF_NOC_NPP_IN_NOC_CREDIT_RDY("IF_NOC_NPP_IN_NOC_CREDIT_RDY"), IF_NOC_NPP_IN_NOC_FLIT("IF_NOC_NPP_IN_NOC_FLIT"), IF_NOC_NPP_IN_NOC_VALID("IF_NOC_NPP_IN_NOC_VALID"), IF_NOC_NPP_OUT_NOC_CREDIT_RETURN("IF_NOC_NPP_OUT_NOC_CREDIT_RETURN"), NMU_WR_USR_DST("NMU_WR_USR_DST"), NMU_RD_USR_DST("NMU_RD_USR_DST"), NMU("NMU"), AXI_IN("AXI_IN"), NMU_RD_DEST_MODE("NMU_RD_DEST_MODE"), NMU_WR_DEST_MODE("NMU_WR_DEST_MODE")
{

  // initialize pins
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RETURN(IF_NOC_NPP_IN_NOC_CREDIT_RETURN);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RDY(IF_NOC_NPP_OUT_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_OUT_NOC_FLIT(IF_NOC_NPP_OUT_NOC_FLIT);
  mp_impl->IF_NOC_NPP_OUT_NOC_VALID(IF_NOC_NPP_OUT_NOC_VALID);
  mp_impl->aclk(aclk);
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RDY(IF_NOC_NPP_IN_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_IN_NOC_FLIT(IF_NOC_NPP_IN_NOC_FLIT);
  mp_impl->IF_NOC_NPP_IN_NOC_VALID(IF_NOC_NPP_IN_NOC_VALID);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RETURN(IF_NOC_NPP_OUT_NOC_CREDIT_RETURN);
  mp_impl->NMU_WR_USR_DST(NMU_WR_USR_DST);
  mp_impl->NMU_RD_USR_DST(NMU_RD_USR_DST);
  mp_impl->NMU(NMU);
  mp_impl->AXI_IN(AXI_IN);
  mp_impl->NMU_RD_DEST_MODE(NMU_RD_DEST_MODE);
  mp_impl->NMU_WR_DEST_MODE(NMU_WR_DEST_MODE);

  // initialize transactors
  mp_SAXI4_transactor = NULL;
  mp_IF_NOC_AXI_ARLOCK_converter = NULL;
  mp_IF_NOC_AXI_AWLOCK_converter = NULL;
  mp_IF_NOC_AXI_RLAST_converter = NULL;
  mp_IF_NOC_AXI_WLAST_converter = NULL;

  // initialize socket stubs

}

void bd_b77b_S00_AXI_nmu_0::before_end_of_elaboration()
{
  // configure 'SAXI4' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_b77b_S00_AXI_nmu_0", "SAXI4_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'SAXI4' transactor parameters
    xsc::common_cpp::properties SAXI4_transactor_param_props;
    SAXI4_transactor_param_props.addLong("DATA_WIDTH", "128");
    SAXI4_transactor_param_props.addLong("FREQ_HZ", "550000000");
    SAXI4_transactor_param_props.addLong("ID_WIDTH", "16");
    SAXI4_transactor_param_props.addLong("ADDR_WIDTH", "64");
    SAXI4_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("WUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("RUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("BUSER_WIDTH", "0");
    SAXI4_transactor_param_props.addLong("HAS_BURST", "1");
    SAXI4_transactor_param_props.addLong("HAS_LOCK", "1");
    SAXI4_transactor_param_props.addLong("HAS_PROT", "1");
    SAXI4_transactor_param_props.addLong("HAS_CACHE", "1");
    SAXI4_transactor_param_props.addLong("HAS_QOS", "1");
    SAXI4_transactor_param_props.addLong("HAS_REGION", "1");
    SAXI4_transactor_param_props.addLong("HAS_WSTRB", "1");
    SAXI4_transactor_param_props.addLong("HAS_BRESP", "1");
    SAXI4_transactor_param_props.addLong("HAS_RRESP", "1");
    SAXI4_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    SAXI4_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    SAXI4_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    SAXI4_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("HAS_SIZE", "1");
    SAXI4_transactor_param_props.addLong("HAS_RESET", "0");
    SAXI4_transactor_param_props.addFloat("PHASE", "0.0");
    SAXI4_transactor_param_props.addString("PROTOCOL", "AXI4");
    SAXI4_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    SAXI4_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");

    mp_SAXI4_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("SAXI4_transactor", SAXI4_transactor_param_props);

    // SAXI4' transactor ports

    mp_SAXI4_transactor->ARADDR(IF_NOC_AXI_ARADDR);
    mp_SAXI4_transactor->ARBURST(IF_NOC_AXI_ARBURST);
    mp_SAXI4_transactor->ARCACHE(IF_NOC_AXI_ARCACHE);
    mp_SAXI4_transactor->ARID(IF_NOC_AXI_ARID);
    mp_SAXI4_transactor->ARLEN(IF_NOC_AXI_ARLEN);
    mp_IF_NOC_AXI_ARLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_ARLOCK_converter");
    mp_IF_NOC_AXI_ARLOCK_converter->vector_in(IF_NOC_AXI_ARLOCK);
    mp_IF_NOC_AXI_ARLOCK_converter->scalar_out(m_IF_NOC_AXI_ARLOCK_converter_signal);
    mp_SAXI4_transactor->ARLOCK(m_IF_NOC_AXI_ARLOCK_converter_signal);
    mp_SAXI4_transactor->ARPROT(IF_NOC_AXI_ARPROT);
    mp_SAXI4_transactor->ARQOS(IF_NOC_AXI_ARQOS);
    mp_SAXI4_transactor->ARREADY(IF_NOC_AXI_ARREADY);
    mp_SAXI4_transactor->ARREGION(IF_NOC_AXI_ARREGION);
    mp_SAXI4_transactor->ARSIZE(IF_NOC_AXI_ARSIZE);
    mp_SAXI4_transactor->ARUSER(IF_NOC_AXI_ARUSER);
    mp_SAXI4_transactor->ARVALID(IF_NOC_AXI_ARVALID);
    mp_SAXI4_transactor->AWADDR(IF_NOC_AXI_AWADDR);
    mp_SAXI4_transactor->AWBURST(IF_NOC_AXI_AWBURST);
    mp_SAXI4_transactor->AWCACHE(IF_NOC_AXI_AWCACHE);
    mp_SAXI4_transactor->AWID(IF_NOC_AXI_AWID);
    mp_SAXI4_transactor->AWLEN(IF_NOC_AXI_AWLEN);
    mp_IF_NOC_AXI_AWLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_AWLOCK_converter");
    mp_IF_NOC_AXI_AWLOCK_converter->vector_in(IF_NOC_AXI_AWLOCK);
    mp_IF_NOC_AXI_AWLOCK_converter->scalar_out(m_IF_NOC_AXI_AWLOCK_converter_signal);
    mp_SAXI4_transactor->AWLOCK(m_IF_NOC_AXI_AWLOCK_converter_signal);
    mp_SAXI4_transactor->AWPROT(IF_NOC_AXI_AWPROT);
    mp_SAXI4_transactor->AWQOS(IF_NOC_AXI_AWQOS);
    mp_SAXI4_transactor->AWREADY(IF_NOC_AXI_AWREADY);
    mp_SAXI4_transactor->AWREGION(IF_NOC_AXI_AWREGION);
    mp_SAXI4_transactor->AWSIZE(IF_NOC_AXI_AWSIZE);
    mp_SAXI4_transactor->AWUSER(IF_NOC_AXI_AWUSER);
    mp_SAXI4_transactor->AWVALID(IF_NOC_AXI_AWVALID);
    mp_SAXI4_transactor->BID(IF_NOC_AXI_BID);
    mp_SAXI4_transactor->BREADY(IF_NOC_AXI_BREADY);
    mp_SAXI4_transactor->BRESP(IF_NOC_AXI_BRESP);
    mp_SAXI4_transactor->BVALID(IF_NOC_AXI_BVALID);
    mp_SAXI4_transactor->RDATA(IF_NOC_AXI_RDATA);
    mp_SAXI4_transactor->RID(IF_NOC_AXI_RID);
    mp_IF_NOC_AXI_RLAST_converter = new xsc::common::scalar2vectorN_converter<1>("IF_NOC_AXI_RLAST_converter");
    mp_IF_NOC_AXI_RLAST_converter->scalar_in(m_IF_NOC_AXI_RLAST_converter_signal);
    mp_IF_NOC_AXI_RLAST_converter->vector_out(IF_NOC_AXI_RLAST);
    mp_SAXI4_transactor->RLAST(m_IF_NOC_AXI_RLAST_converter_signal);
    mp_SAXI4_transactor->RREADY(IF_NOC_AXI_RREADY);
    mp_SAXI4_transactor->RRESP(IF_NOC_AXI_RRESP);
    mp_SAXI4_transactor->RUSER(IF_NOC_AXI_RUSER);
    mp_SAXI4_transactor->RVALID(IF_NOC_AXI_RVALID);
    mp_SAXI4_transactor->WDATA(IF_NOC_AXI_WDATA);
    mp_IF_NOC_AXI_WLAST_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_WLAST_converter");
    mp_IF_NOC_AXI_WLAST_converter->vector_in(IF_NOC_AXI_WLAST);
    mp_IF_NOC_AXI_WLAST_converter->scalar_out(m_IF_NOC_AXI_WLAST_converter_signal);
    mp_SAXI4_transactor->WLAST(m_IF_NOC_AXI_WLAST_converter_signal);
    mp_SAXI4_transactor->WREADY(IF_NOC_AXI_WREADY);
    mp_SAXI4_transactor->WSTRB(IF_NOC_AXI_WSTRB);
    mp_SAXI4_transactor->WUSER(IF_NOC_AXI_WUSER);
    mp_SAXI4_transactor->WVALID(IF_NOC_AXI_WVALID);
    mp_SAXI4_transactor->CLK(aclk);
    m_SAXI4_transactor_rst_signal.write(1);
    mp_SAXI4_transactor->RST(m_SAXI4_transactor_rst_signal);

    // SAXI4' transactor sockets

    mp_impl->SAXI4_rd_socket->bind(*(mp_SAXI4_transactor->rd_socket));
    mp_impl->SAXI4_wr_socket->bind(*(mp_SAXI4_transactor->wr_socket));
  }
  else
  {
  }

}

#endif // XM_SYSTEMC




#ifdef RIVIERA
bd_b77b_S00_AXI_nmu_0::bd_b77b_S00_AXI_nmu_0(const sc_core::sc_module_name& nm) : bd_b77b_S00_AXI_nmu_0_sc(nm), IF_NOC_AXI_WVALID("IF_NOC_AXI_WVALID"), IF_NOC_AXI_WREADY("IF_NOC_AXI_WREADY"), IF_NOC_AXI_WLAST("IF_NOC_AXI_WLAST"), IF_NOC_AXI_AWID("IF_NOC_AXI_AWID"), IF_NOC_AXI_WDATA("IF_NOC_AXI_WDATA"), IF_NOC_AXI_WSTRB("IF_NOC_AXI_WSTRB"), IF_NOC_AXI_ARREADY("IF_NOC_AXI_ARREADY"), IF_NOC_AXI_AWREADY("IF_NOC_AXI_AWREADY"), IF_NOC_AXI_BID("IF_NOC_AXI_BID"), IF_NOC_AXI_BRESP("IF_NOC_AXI_BRESP"), IF_NOC_AXI_BVALID("IF_NOC_AXI_BVALID"), IF_NOC_AXI_RDATA("IF_NOC_AXI_RDATA"), IF_NOC_AXI_RID("IF_NOC_AXI_RID"), IF_NOC_AXI_RLAST("IF_NOC_AXI_RLAST"), IF_NOC_AXI_RRESP("IF_NOC_AXI_RRESP"), IF_NOC_AXI_RUSER("IF_NOC_AXI_RUSER"), IF_NOC_AXI_RVALID("IF_NOC_AXI_RVALID"), IF_NOC_NPP_IN_NOC_CREDIT_RETURN("IF_NOC_NPP_IN_NOC_CREDIT_RETURN"), IF_NOC_NPP_OUT_NOC_CREDIT_RDY("IF_NOC_NPP_OUT_NOC_CREDIT_RDY"), IF_NOC_NPP_OUT_NOC_FLIT("IF_NOC_NPP_OUT_NOC_FLIT"), IF_NOC_NPP_OUT_NOC_VALID("IF_NOC_NPP_OUT_NOC_VALID"), aclk("aclk"), IF_NOC_AXI_ARADDR("IF_NOC_AXI_ARADDR"), IF_NOC_AXI_ARBURST("IF_NOC_AXI_ARBURST"), IF_NOC_AXI_ARCACHE("IF_NOC_AXI_ARCACHE"), IF_NOC_AXI_ARID("IF_NOC_AXI_ARID"), IF_NOC_AXI_ARLEN("IF_NOC_AXI_ARLEN"), IF_NOC_AXI_ARLOCK("IF_NOC_AXI_ARLOCK"), IF_NOC_AXI_ARPROT("IF_NOC_AXI_ARPROT"), IF_NOC_AXI_ARQOS("IF_NOC_AXI_ARQOS"), IF_NOC_AXI_ARREGION("IF_NOC_AXI_ARREGION"), IF_NOC_AXI_ARSIZE("IF_NOC_AXI_ARSIZE"), IF_NOC_AXI_ARUSER("IF_NOC_AXI_ARUSER"), IF_NOC_AXI_ARVALID("IF_NOC_AXI_ARVALID"), IF_NOC_AXI_AWADDR("IF_NOC_AXI_AWADDR"), IF_NOC_AXI_AWBURST("IF_NOC_AXI_AWBURST"), IF_NOC_AXI_AWCACHE("IF_NOC_AXI_AWCACHE"), IF_NOC_AXI_AWLEN("IF_NOC_AXI_AWLEN"), IF_NOC_AXI_AWLOCK("IF_NOC_AXI_AWLOCK"), IF_NOC_AXI_AWPROT("IF_NOC_AXI_AWPROT"), IF_NOC_AXI_AWQOS("IF_NOC_AXI_AWQOS"), IF_NOC_AXI_AWREGION("IF_NOC_AXI_AWREGION"), IF_NOC_AXI_AWSIZE("IF_NOC_AXI_AWSIZE"), IF_NOC_AXI_AWUSER("IF_NOC_AXI_AWUSER"), IF_NOC_AXI_AWVALID("IF_NOC_AXI_AWVALID"), IF_NOC_AXI_BREADY("IF_NOC_AXI_BREADY"), IF_NOC_AXI_RREADY("IF_NOC_AXI_RREADY"), IF_NOC_AXI_WUSER("IF_NOC_AXI_WUSER"), IF_NOC_NPP_IN_NOC_CREDIT_RDY("IF_NOC_NPP_IN_NOC_CREDIT_RDY"), IF_NOC_NPP_IN_NOC_FLIT("IF_NOC_NPP_IN_NOC_FLIT"), IF_NOC_NPP_IN_NOC_VALID("IF_NOC_NPP_IN_NOC_VALID"), IF_NOC_NPP_OUT_NOC_CREDIT_RETURN("IF_NOC_NPP_OUT_NOC_CREDIT_RETURN"), NMU_WR_USR_DST("NMU_WR_USR_DST"), NMU_RD_USR_DST("NMU_RD_USR_DST"), NMU("NMU"), AXI_IN("AXI_IN"), NMU_RD_DEST_MODE("NMU_RD_DEST_MODE"), NMU_WR_DEST_MODE("NMU_WR_DEST_MODE")
{

  // initialize pins
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RETURN(IF_NOC_NPP_IN_NOC_CREDIT_RETURN);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RDY(IF_NOC_NPP_OUT_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_OUT_NOC_FLIT(IF_NOC_NPP_OUT_NOC_FLIT);
  mp_impl->IF_NOC_NPP_OUT_NOC_VALID(IF_NOC_NPP_OUT_NOC_VALID);
  mp_impl->aclk(aclk);
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RDY(IF_NOC_NPP_IN_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_IN_NOC_FLIT(IF_NOC_NPP_IN_NOC_FLIT);
  mp_impl->IF_NOC_NPP_IN_NOC_VALID(IF_NOC_NPP_IN_NOC_VALID);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RETURN(IF_NOC_NPP_OUT_NOC_CREDIT_RETURN);
  mp_impl->NMU_WR_USR_DST(NMU_WR_USR_DST);
  mp_impl->NMU_RD_USR_DST(NMU_RD_USR_DST);
  mp_impl->NMU(NMU);
  mp_impl->AXI_IN(AXI_IN);
  mp_impl->NMU_RD_DEST_MODE(NMU_RD_DEST_MODE);
  mp_impl->NMU_WR_DEST_MODE(NMU_WR_DEST_MODE);

  // initialize transactors
  mp_SAXI4_transactor = NULL;
  mp_IF_NOC_AXI_ARLOCK_converter = NULL;
  mp_IF_NOC_AXI_AWLOCK_converter = NULL;
  mp_IF_NOC_AXI_RLAST_converter = NULL;
  mp_IF_NOC_AXI_WLAST_converter = NULL;

  // initialize socket stubs

}

void bd_b77b_S00_AXI_nmu_0::before_end_of_elaboration()
{
  // configure 'SAXI4' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_b77b_S00_AXI_nmu_0", "SAXI4_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'SAXI4' transactor parameters
    xsc::common_cpp::properties SAXI4_transactor_param_props;
    SAXI4_transactor_param_props.addLong("DATA_WIDTH", "128");
    SAXI4_transactor_param_props.addLong("FREQ_HZ", "550000000");
    SAXI4_transactor_param_props.addLong("ID_WIDTH", "16");
    SAXI4_transactor_param_props.addLong("ADDR_WIDTH", "64");
    SAXI4_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("WUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("RUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("BUSER_WIDTH", "0");
    SAXI4_transactor_param_props.addLong("HAS_BURST", "1");
    SAXI4_transactor_param_props.addLong("HAS_LOCK", "1");
    SAXI4_transactor_param_props.addLong("HAS_PROT", "1");
    SAXI4_transactor_param_props.addLong("HAS_CACHE", "1");
    SAXI4_transactor_param_props.addLong("HAS_QOS", "1");
    SAXI4_transactor_param_props.addLong("HAS_REGION", "1");
    SAXI4_transactor_param_props.addLong("HAS_WSTRB", "1");
    SAXI4_transactor_param_props.addLong("HAS_BRESP", "1");
    SAXI4_transactor_param_props.addLong("HAS_RRESP", "1");
    SAXI4_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    SAXI4_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    SAXI4_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    SAXI4_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("HAS_SIZE", "1");
    SAXI4_transactor_param_props.addLong("HAS_RESET", "0");
    SAXI4_transactor_param_props.addFloat("PHASE", "0.0");
    SAXI4_transactor_param_props.addString("PROTOCOL", "AXI4");
    SAXI4_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    SAXI4_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");

    mp_SAXI4_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("SAXI4_transactor", SAXI4_transactor_param_props);

    // SAXI4' transactor ports

    mp_SAXI4_transactor->ARADDR(IF_NOC_AXI_ARADDR);
    mp_SAXI4_transactor->ARBURST(IF_NOC_AXI_ARBURST);
    mp_SAXI4_transactor->ARCACHE(IF_NOC_AXI_ARCACHE);
    mp_SAXI4_transactor->ARID(IF_NOC_AXI_ARID);
    mp_SAXI4_transactor->ARLEN(IF_NOC_AXI_ARLEN);
    mp_IF_NOC_AXI_ARLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_ARLOCK_converter");
    mp_IF_NOC_AXI_ARLOCK_converter->vector_in(IF_NOC_AXI_ARLOCK);
    mp_IF_NOC_AXI_ARLOCK_converter->scalar_out(m_IF_NOC_AXI_ARLOCK_converter_signal);
    mp_SAXI4_transactor->ARLOCK(m_IF_NOC_AXI_ARLOCK_converter_signal);
    mp_SAXI4_transactor->ARPROT(IF_NOC_AXI_ARPROT);
    mp_SAXI4_transactor->ARQOS(IF_NOC_AXI_ARQOS);
    mp_SAXI4_transactor->ARREADY(IF_NOC_AXI_ARREADY);
    mp_SAXI4_transactor->ARREGION(IF_NOC_AXI_ARREGION);
    mp_SAXI4_transactor->ARSIZE(IF_NOC_AXI_ARSIZE);
    mp_SAXI4_transactor->ARUSER(IF_NOC_AXI_ARUSER);
    mp_SAXI4_transactor->ARVALID(IF_NOC_AXI_ARVALID);
    mp_SAXI4_transactor->AWADDR(IF_NOC_AXI_AWADDR);
    mp_SAXI4_transactor->AWBURST(IF_NOC_AXI_AWBURST);
    mp_SAXI4_transactor->AWCACHE(IF_NOC_AXI_AWCACHE);
    mp_SAXI4_transactor->AWID(IF_NOC_AXI_AWID);
    mp_SAXI4_transactor->AWLEN(IF_NOC_AXI_AWLEN);
    mp_IF_NOC_AXI_AWLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_AWLOCK_converter");
    mp_IF_NOC_AXI_AWLOCK_converter->vector_in(IF_NOC_AXI_AWLOCK);
    mp_IF_NOC_AXI_AWLOCK_converter->scalar_out(m_IF_NOC_AXI_AWLOCK_converter_signal);
    mp_SAXI4_transactor->AWLOCK(m_IF_NOC_AXI_AWLOCK_converter_signal);
    mp_SAXI4_transactor->AWPROT(IF_NOC_AXI_AWPROT);
    mp_SAXI4_transactor->AWQOS(IF_NOC_AXI_AWQOS);
    mp_SAXI4_transactor->AWREADY(IF_NOC_AXI_AWREADY);
    mp_SAXI4_transactor->AWREGION(IF_NOC_AXI_AWREGION);
    mp_SAXI4_transactor->AWSIZE(IF_NOC_AXI_AWSIZE);
    mp_SAXI4_transactor->AWUSER(IF_NOC_AXI_AWUSER);
    mp_SAXI4_transactor->AWVALID(IF_NOC_AXI_AWVALID);
    mp_SAXI4_transactor->BID(IF_NOC_AXI_BID);
    mp_SAXI4_transactor->BREADY(IF_NOC_AXI_BREADY);
    mp_SAXI4_transactor->BRESP(IF_NOC_AXI_BRESP);
    mp_SAXI4_transactor->BVALID(IF_NOC_AXI_BVALID);
    mp_SAXI4_transactor->RDATA(IF_NOC_AXI_RDATA);
    mp_SAXI4_transactor->RID(IF_NOC_AXI_RID);
    mp_IF_NOC_AXI_RLAST_converter = new xsc::common::scalar2vectorN_converter<1>("IF_NOC_AXI_RLAST_converter");
    mp_IF_NOC_AXI_RLAST_converter->scalar_in(m_IF_NOC_AXI_RLAST_converter_signal);
    mp_IF_NOC_AXI_RLAST_converter->vector_out(IF_NOC_AXI_RLAST);
    mp_SAXI4_transactor->RLAST(m_IF_NOC_AXI_RLAST_converter_signal);
    mp_SAXI4_transactor->RREADY(IF_NOC_AXI_RREADY);
    mp_SAXI4_transactor->RRESP(IF_NOC_AXI_RRESP);
    mp_SAXI4_transactor->RUSER(IF_NOC_AXI_RUSER);
    mp_SAXI4_transactor->RVALID(IF_NOC_AXI_RVALID);
    mp_SAXI4_transactor->WDATA(IF_NOC_AXI_WDATA);
    mp_IF_NOC_AXI_WLAST_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_WLAST_converter");
    mp_IF_NOC_AXI_WLAST_converter->vector_in(IF_NOC_AXI_WLAST);
    mp_IF_NOC_AXI_WLAST_converter->scalar_out(m_IF_NOC_AXI_WLAST_converter_signal);
    mp_SAXI4_transactor->WLAST(m_IF_NOC_AXI_WLAST_converter_signal);
    mp_SAXI4_transactor->WREADY(IF_NOC_AXI_WREADY);
    mp_SAXI4_transactor->WSTRB(IF_NOC_AXI_WSTRB);
    mp_SAXI4_transactor->WUSER(IF_NOC_AXI_WUSER);
    mp_SAXI4_transactor->WVALID(IF_NOC_AXI_WVALID);
    mp_SAXI4_transactor->CLK(aclk);
    m_SAXI4_transactor_rst_signal.write(1);
    mp_SAXI4_transactor->RST(m_SAXI4_transactor_rst_signal);

    // SAXI4' transactor sockets

    mp_impl->SAXI4_rd_socket->bind(*(mp_SAXI4_transactor->rd_socket));
    mp_impl->SAXI4_wr_socket->bind(*(mp_SAXI4_transactor->wr_socket));
  }
  else
  {
  }

}

#endif // RIVIERA




#ifdef VCSSYSTEMC
bd_b77b_S00_AXI_nmu_0::bd_b77b_S00_AXI_nmu_0(const sc_core::sc_module_name& nm) : bd_b77b_S00_AXI_nmu_0_sc(nm),  IF_NOC_AXI_WVALID("IF_NOC_AXI_WVALID"), IF_NOC_AXI_WREADY("IF_NOC_AXI_WREADY"), IF_NOC_AXI_WLAST("IF_NOC_AXI_WLAST"), IF_NOC_AXI_AWID("IF_NOC_AXI_AWID"), IF_NOC_AXI_WDATA("IF_NOC_AXI_WDATA"), IF_NOC_AXI_WSTRB("IF_NOC_AXI_WSTRB"), IF_NOC_AXI_ARREADY("IF_NOC_AXI_ARREADY"), IF_NOC_AXI_AWREADY("IF_NOC_AXI_AWREADY"), IF_NOC_AXI_BID("IF_NOC_AXI_BID"), IF_NOC_AXI_BRESP("IF_NOC_AXI_BRESP"), IF_NOC_AXI_BVALID("IF_NOC_AXI_BVALID"), IF_NOC_AXI_RDATA("IF_NOC_AXI_RDATA"), IF_NOC_AXI_RID("IF_NOC_AXI_RID"), IF_NOC_AXI_RLAST("IF_NOC_AXI_RLAST"), IF_NOC_AXI_RRESP("IF_NOC_AXI_RRESP"), IF_NOC_AXI_RUSER("IF_NOC_AXI_RUSER"), IF_NOC_AXI_RVALID("IF_NOC_AXI_RVALID"), IF_NOC_NPP_IN_NOC_CREDIT_RETURN("IF_NOC_NPP_IN_NOC_CREDIT_RETURN"), IF_NOC_NPP_OUT_NOC_CREDIT_RDY("IF_NOC_NPP_OUT_NOC_CREDIT_RDY"), IF_NOC_NPP_OUT_NOC_FLIT("IF_NOC_NPP_OUT_NOC_FLIT"), IF_NOC_NPP_OUT_NOC_VALID("IF_NOC_NPP_OUT_NOC_VALID"), aclk("aclk"), IF_NOC_AXI_ARADDR("IF_NOC_AXI_ARADDR"), IF_NOC_AXI_ARBURST("IF_NOC_AXI_ARBURST"), IF_NOC_AXI_ARCACHE("IF_NOC_AXI_ARCACHE"), IF_NOC_AXI_ARID("IF_NOC_AXI_ARID"), IF_NOC_AXI_ARLEN("IF_NOC_AXI_ARLEN"), IF_NOC_AXI_ARLOCK("IF_NOC_AXI_ARLOCK"), IF_NOC_AXI_ARPROT("IF_NOC_AXI_ARPROT"), IF_NOC_AXI_ARQOS("IF_NOC_AXI_ARQOS"), IF_NOC_AXI_ARREGION("IF_NOC_AXI_ARREGION"), IF_NOC_AXI_ARSIZE("IF_NOC_AXI_ARSIZE"), IF_NOC_AXI_ARUSER("IF_NOC_AXI_ARUSER"), IF_NOC_AXI_ARVALID("IF_NOC_AXI_ARVALID"), IF_NOC_AXI_AWADDR("IF_NOC_AXI_AWADDR"), IF_NOC_AXI_AWBURST("IF_NOC_AXI_AWBURST"), IF_NOC_AXI_AWCACHE("IF_NOC_AXI_AWCACHE"), IF_NOC_AXI_AWLEN("IF_NOC_AXI_AWLEN"), IF_NOC_AXI_AWLOCK("IF_NOC_AXI_AWLOCK"), IF_NOC_AXI_AWPROT("IF_NOC_AXI_AWPROT"), IF_NOC_AXI_AWQOS("IF_NOC_AXI_AWQOS"), IF_NOC_AXI_AWREGION("IF_NOC_AXI_AWREGION"), IF_NOC_AXI_AWSIZE("IF_NOC_AXI_AWSIZE"), IF_NOC_AXI_AWUSER("IF_NOC_AXI_AWUSER"), IF_NOC_AXI_AWVALID("IF_NOC_AXI_AWVALID"), IF_NOC_AXI_BREADY("IF_NOC_AXI_BREADY"), IF_NOC_AXI_RREADY("IF_NOC_AXI_RREADY"), IF_NOC_AXI_WUSER("IF_NOC_AXI_WUSER"), IF_NOC_NPP_IN_NOC_CREDIT_RDY("IF_NOC_NPP_IN_NOC_CREDIT_RDY"), IF_NOC_NPP_IN_NOC_FLIT("IF_NOC_NPP_IN_NOC_FLIT"), IF_NOC_NPP_IN_NOC_VALID("IF_NOC_NPP_IN_NOC_VALID"), IF_NOC_NPP_OUT_NOC_CREDIT_RETURN("IF_NOC_NPP_OUT_NOC_CREDIT_RETURN"), NMU_WR_USR_DST("NMU_WR_USR_DST"), NMU_RD_USR_DST("NMU_RD_USR_DST"), NMU("NMU"), AXI_IN("AXI_IN"), NMU_RD_DEST_MODE("NMU_RD_DEST_MODE"), NMU_WR_DEST_MODE("NMU_WR_DEST_MODE")
{
  // initialize pins
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RETURN(IF_NOC_NPP_IN_NOC_CREDIT_RETURN);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RDY(IF_NOC_NPP_OUT_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_OUT_NOC_FLIT(IF_NOC_NPP_OUT_NOC_FLIT);
  mp_impl->IF_NOC_NPP_OUT_NOC_VALID(IF_NOC_NPP_OUT_NOC_VALID);
  mp_impl->aclk(aclk);
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RDY(IF_NOC_NPP_IN_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_IN_NOC_FLIT(IF_NOC_NPP_IN_NOC_FLIT);
  mp_impl->IF_NOC_NPP_IN_NOC_VALID(IF_NOC_NPP_IN_NOC_VALID);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RETURN(IF_NOC_NPP_OUT_NOC_CREDIT_RETURN);
  mp_impl->NMU_WR_USR_DST(NMU_WR_USR_DST);
  mp_impl->NMU_RD_USR_DST(NMU_RD_USR_DST);
  mp_impl->NMU(NMU);
  mp_impl->AXI_IN(AXI_IN);
  mp_impl->NMU_RD_DEST_MODE(NMU_RD_DEST_MODE);
  mp_impl->NMU_WR_DEST_MODE(NMU_WR_DEST_MODE);

  // initialize transactors
  mp_SAXI4_transactor = NULL;
  mp_IF_NOC_AXI_ARLOCK_converter = NULL;
  mp_IF_NOC_AXI_AWLOCK_converter = NULL;
  mp_IF_NOC_AXI_RLAST_converter = NULL;
  mp_IF_NOC_AXI_WLAST_converter = NULL;

  // Instantiate Socket Stubs

  // configure SAXI4_transactor
    xsc::common_cpp::properties SAXI4_transactor_param_props;
    SAXI4_transactor_param_props.addLong("DATA_WIDTH", "128");
    SAXI4_transactor_param_props.addLong("FREQ_HZ", "550000000");
    SAXI4_transactor_param_props.addLong("ID_WIDTH", "16");
    SAXI4_transactor_param_props.addLong("ADDR_WIDTH", "64");
    SAXI4_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("WUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("RUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("BUSER_WIDTH", "0");
    SAXI4_transactor_param_props.addLong("HAS_BURST", "1");
    SAXI4_transactor_param_props.addLong("HAS_LOCK", "1");
    SAXI4_transactor_param_props.addLong("HAS_PROT", "1");
    SAXI4_transactor_param_props.addLong("HAS_CACHE", "1");
    SAXI4_transactor_param_props.addLong("HAS_QOS", "1");
    SAXI4_transactor_param_props.addLong("HAS_REGION", "1");
    SAXI4_transactor_param_props.addLong("HAS_WSTRB", "1");
    SAXI4_transactor_param_props.addLong("HAS_BRESP", "1");
    SAXI4_transactor_param_props.addLong("HAS_RRESP", "1");
    SAXI4_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    SAXI4_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    SAXI4_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    SAXI4_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("HAS_SIZE", "1");
    SAXI4_transactor_param_props.addLong("HAS_RESET", "0");
    SAXI4_transactor_param_props.addFloat("PHASE", "0.0");
    SAXI4_transactor_param_props.addString("PROTOCOL", "AXI4");
    SAXI4_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    SAXI4_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");

    mp_SAXI4_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("SAXI4_transactor", SAXI4_transactor_param_props);
  mp_SAXI4_transactor->ARADDR(IF_NOC_AXI_ARADDR);
  mp_SAXI4_transactor->ARBURST(IF_NOC_AXI_ARBURST);
  mp_SAXI4_transactor->ARCACHE(IF_NOC_AXI_ARCACHE);
  mp_SAXI4_transactor->ARID(IF_NOC_AXI_ARID);
  mp_SAXI4_transactor->ARLEN(IF_NOC_AXI_ARLEN);
  mp_IF_NOC_AXI_ARLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_ARLOCK_converter");
  mp_IF_NOC_AXI_ARLOCK_converter->vector_in(IF_NOC_AXI_ARLOCK);
  mp_IF_NOC_AXI_ARLOCK_converter->scalar_out(m_IF_NOC_AXI_ARLOCK_converter_signal);
  mp_SAXI4_transactor->ARLOCK(m_IF_NOC_AXI_ARLOCK_converter_signal);
  mp_SAXI4_transactor->ARPROT(IF_NOC_AXI_ARPROT);
  mp_SAXI4_transactor->ARQOS(IF_NOC_AXI_ARQOS);
  mp_SAXI4_transactor->ARREADY(IF_NOC_AXI_ARREADY);
  mp_SAXI4_transactor->ARREGION(IF_NOC_AXI_ARREGION);
  mp_SAXI4_transactor->ARSIZE(IF_NOC_AXI_ARSIZE);
  mp_SAXI4_transactor->ARUSER(IF_NOC_AXI_ARUSER);
  mp_SAXI4_transactor->ARVALID(IF_NOC_AXI_ARVALID);
  mp_SAXI4_transactor->AWADDR(IF_NOC_AXI_AWADDR);
  mp_SAXI4_transactor->AWBURST(IF_NOC_AXI_AWBURST);
  mp_SAXI4_transactor->AWCACHE(IF_NOC_AXI_AWCACHE);
  mp_SAXI4_transactor->AWID(IF_NOC_AXI_AWID);
  mp_SAXI4_transactor->AWLEN(IF_NOC_AXI_AWLEN);
  mp_IF_NOC_AXI_AWLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_AWLOCK_converter");
  mp_IF_NOC_AXI_AWLOCK_converter->vector_in(IF_NOC_AXI_AWLOCK);
  mp_IF_NOC_AXI_AWLOCK_converter->scalar_out(m_IF_NOC_AXI_AWLOCK_converter_signal);
  mp_SAXI4_transactor->AWLOCK(m_IF_NOC_AXI_AWLOCK_converter_signal);
  mp_SAXI4_transactor->AWPROT(IF_NOC_AXI_AWPROT);
  mp_SAXI4_transactor->AWQOS(IF_NOC_AXI_AWQOS);
  mp_SAXI4_transactor->AWREADY(IF_NOC_AXI_AWREADY);
  mp_SAXI4_transactor->AWREGION(IF_NOC_AXI_AWREGION);
  mp_SAXI4_transactor->AWSIZE(IF_NOC_AXI_AWSIZE);
  mp_SAXI4_transactor->AWUSER(IF_NOC_AXI_AWUSER);
  mp_SAXI4_transactor->AWVALID(IF_NOC_AXI_AWVALID);
  mp_SAXI4_transactor->BID(IF_NOC_AXI_BID);
  mp_SAXI4_transactor->BREADY(IF_NOC_AXI_BREADY);
  mp_SAXI4_transactor->BRESP(IF_NOC_AXI_BRESP);
  mp_SAXI4_transactor->BVALID(IF_NOC_AXI_BVALID);
  mp_SAXI4_transactor->RDATA(IF_NOC_AXI_RDATA);
  mp_SAXI4_transactor->RID(IF_NOC_AXI_RID);
  mp_IF_NOC_AXI_RLAST_converter = new xsc::common::scalar2vectorN_converter<1>("IF_NOC_AXI_RLAST_converter");
  mp_IF_NOC_AXI_RLAST_converter->scalar_in(m_IF_NOC_AXI_RLAST_converter_signal);
  mp_IF_NOC_AXI_RLAST_converter->vector_out(IF_NOC_AXI_RLAST);
  mp_SAXI4_transactor->RLAST(m_IF_NOC_AXI_RLAST_converter_signal);
  mp_SAXI4_transactor->RREADY(IF_NOC_AXI_RREADY);
  mp_SAXI4_transactor->RRESP(IF_NOC_AXI_RRESP);
  mp_SAXI4_transactor->RUSER(IF_NOC_AXI_RUSER);
  mp_SAXI4_transactor->RVALID(IF_NOC_AXI_RVALID);
  mp_SAXI4_transactor->WDATA(IF_NOC_AXI_WDATA);
  mp_IF_NOC_AXI_WLAST_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_WLAST_converter");
  mp_IF_NOC_AXI_WLAST_converter->vector_in(IF_NOC_AXI_WLAST);
  mp_IF_NOC_AXI_WLAST_converter->scalar_out(m_IF_NOC_AXI_WLAST_converter_signal);
  mp_SAXI4_transactor->WLAST(m_IF_NOC_AXI_WLAST_converter_signal);
  mp_SAXI4_transactor->WREADY(IF_NOC_AXI_WREADY);
  mp_SAXI4_transactor->WSTRB(IF_NOC_AXI_WSTRB);
  mp_SAXI4_transactor->WUSER(IF_NOC_AXI_WUSER);
  mp_SAXI4_transactor->WVALID(IF_NOC_AXI_WVALID);
  mp_SAXI4_transactor->CLK(aclk);
  m_SAXI4_transactor_rst_signal.write(1);
  mp_SAXI4_transactor->RST(m_SAXI4_transactor_rst_signal);

  // initialize transactors stubs
  SAXI4_transactor_target_wr_socket_stub = nullptr;
  SAXI4_transactor_target_rd_socket_stub = nullptr;

}

void bd_b77b_S00_AXI_nmu_0::before_end_of_elaboration()
{
  // configure 'SAXI4' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_b77b_S00_AXI_nmu_0", "SAXI4_TLM_MODE") != 1)
  {
    mp_impl->SAXI4_rd_socket->bind(*(mp_SAXI4_transactor->rd_socket));
    mp_impl->SAXI4_wr_socket->bind(*(mp_SAXI4_transactor->wr_socket));
  
  }
  else
  {
    SAXI4_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    SAXI4_transactor_target_wr_socket_stub->bind(*(mp_SAXI4_transactor->wr_socket));
    SAXI4_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    SAXI4_transactor_target_rd_socket_stub->bind(*(mp_SAXI4_transactor->rd_socket));
    mp_SAXI4_transactor->disable_transactor();
  }

}

#endif // VCSSYSTEMC




#ifdef MTI_SYSTEMC
bd_b77b_S00_AXI_nmu_0::bd_b77b_S00_AXI_nmu_0(const sc_core::sc_module_name& nm) : bd_b77b_S00_AXI_nmu_0_sc(nm),  IF_NOC_AXI_WVALID("IF_NOC_AXI_WVALID"), IF_NOC_AXI_WREADY("IF_NOC_AXI_WREADY"), IF_NOC_AXI_WLAST("IF_NOC_AXI_WLAST"), IF_NOC_AXI_AWID("IF_NOC_AXI_AWID"), IF_NOC_AXI_WDATA("IF_NOC_AXI_WDATA"), IF_NOC_AXI_WSTRB("IF_NOC_AXI_WSTRB"), IF_NOC_AXI_ARREADY("IF_NOC_AXI_ARREADY"), IF_NOC_AXI_AWREADY("IF_NOC_AXI_AWREADY"), IF_NOC_AXI_BID("IF_NOC_AXI_BID"), IF_NOC_AXI_BRESP("IF_NOC_AXI_BRESP"), IF_NOC_AXI_BVALID("IF_NOC_AXI_BVALID"), IF_NOC_AXI_RDATA("IF_NOC_AXI_RDATA"), IF_NOC_AXI_RID("IF_NOC_AXI_RID"), IF_NOC_AXI_RLAST("IF_NOC_AXI_RLAST"), IF_NOC_AXI_RRESP("IF_NOC_AXI_RRESP"), IF_NOC_AXI_RUSER("IF_NOC_AXI_RUSER"), IF_NOC_AXI_RVALID("IF_NOC_AXI_RVALID"), IF_NOC_NPP_IN_NOC_CREDIT_RETURN("IF_NOC_NPP_IN_NOC_CREDIT_RETURN"), IF_NOC_NPP_OUT_NOC_CREDIT_RDY("IF_NOC_NPP_OUT_NOC_CREDIT_RDY"), IF_NOC_NPP_OUT_NOC_FLIT("IF_NOC_NPP_OUT_NOC_FLIT"), IF_NOC_NPP_OUT_NOC_VALID("IF_NOC_NPP_OUT_NOC_VALID"), aclk("aclk"), IF_NOC_AXI_ARADDR("IF_NOC_AXI_ARADDR"), IF_NOC_AXI_ARBURST("IF_NOC_AXI_ARBURST"), IF_NOC_AXI_ARCACHE("IF_NOC_AXI_ARCACHE"), IF_NOC_AXI_ARID("IF_NOC_AXI_ARID"), IF_NOC_AXI_ARLEN("IF_NOC_AXI_ARLEN"), IF_NOC_AXI_ARLOCK("IF_NOC_AXI_ARLOCK"), IF_NOC_AXI_ARPROT("IF_NOC_AXI_ARPROT"), IF_NOC_AXI_ARQOS("IF_NOC_AXI_ARQOS"), IF_NOC_AXI_ARREGION("IF_NOC_AXI_ARREGION"), IF_NOC_AXI_ARSIZE("IF_NOC_AXI_ARSIZE"), IF_NOC_AXI_ARUSER("IF_NOC_AXI_ARUSER"), IF_NOC_AXI_ARVALID("IF_NOC_AXI_ARVALID"), IF_NOC_AXI_AWADDR("IF_NOC_AXI_AWADDR"), IF_NOC_AXI_AWBURST("IF_NOC_AXI_AWBURST"), IF_NOC_AXI_AWCACHE("IF_NOC_AXI_AWCACHE"), IF_NOC_AXI_AWLEN("IF_NOC_AXI_AWLEN"), IF_NOC_AXI_AWLOCK("IF_NOC_AXI_AWLOCK"), IF_NOC_AXI_AWPROT("IF_NOC_AXI_AWPROT"), IF_NOC_AXI_AWQOS("IF_NOC_AXI_AWQOS"), IF_NOC_AXI_AWREGION("IF_NOC_AXI_AWREGION"), IF_NOC_AXI_AWSIZE("IF_NOC_AXI_AWSIZE"), IF_NOC_AXI_AWUSER("IF_NOC_AXI_AWUSER"), IF_NOC_AXI_AWVALID("IF_NOC_AXI_AWVALID"), IF_NOC_AXI_BREADY("IF_NOC_AXI_BREADY"), IF_NOC_AXI_RREADY("IF_NOC_AXI_RREADY"), IF_NOC_AXI_WUSER("IF_NOC_AXI_WUSER"), IF_NOC_NPP_IN_NOC_CREDIT_RDY("IF_NOC_NPP_IN_NOC_CREDIT_RDY"), IF_NOC_NPP_IN_NOC_FLIT("IF_NOC_NPP_IN_NOC_FLIT"), IF_NOC_NPP_IN_NOC_VALID("IF_NOC_NPP_IN_NOC_VALID"), IF_NOC_NPP_OUT_NOC_CREDIT_RETURN("IF_NOC_NPP_OUT_NOC_CREDIT_RETURN"), NMU_WR_USR_DST("NMU_WR_USR_DST"), NMU_RD_USR_DST("NMU_RD_USR_DST"), NMU("NMU"), AXI_IN("AXI_IN"), NMU_RD_DEST_MODE("NMU_RD_DEST_MODE"), NMU_WR_DEST_MODE("NMU_WR_DEST_MODE")
{
  // initialize pins
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RETURN(IF_NOC_NPP_IN_NOC_CREDIT_RETURN);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RDY(IF_NOC_NPP_OUT_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_OUT_NOC_FLIT(IF_NOC_NPP_OUT_NOC_FLIT);
  mp_impl->IF_NOC_NPP_OUT_NOC_VALID(IF_NOC_NPP_OUT_NOC_VALID);
  mp_impl->aclk(aclk);
  mp_impl->IF_NOC_NPP_IN_NOC_CREDIT_RDY(IF_NOC_NPP_IN_NOC_CREDIT_RDY);
  mp_impl->IF_NOC_NPP_IN_NOC_FLIT(IF_NOC_NPP_IN_NOC_FLIT);
  mp_impl->IF_NOC_NPP_IN_NOC_VALID(IF_NOC_NPP_IN_NOC_VALID);
  mp_impl->IF_NOC_NPP_OUT_NOC_CREDIT_RETURN(IF_NOC_NPP_OUT_NOC_CREDIT_RETURN);
  mp_impl->NMU_WR_USR_DST(NMU_WR_USR_DST);
  mp_impl->NMU_RD_USR_DST(NMU_RD_USR_DST);
  mp_impl->NMU(NMU);
  mp_impl->AXI_IN(AXI_IN);
  mp_impl->NMU_RD_DEST_MODE(NMU_RD_DEST_MODE);
  mp_impl->NMU_WR_DEST_MODE(NMU_WR_DEST_MODE);

  // initialize transactors
  mp_SAXI4_transactor = NULL;
  mp_IF_NOC_AXI_ARLOCK_converter = NULL;
  mp_IF_NOC_AXI_AWLOCK_converter = NULL;
  mp_IF_NOC_AXI_RLAST_converter = NULL;
  mp_IF_NOC_AXI_WLAST_converter = NULL;

  // Instantiate Socket Stubs

  // configure SAXI4_transactor
    xsc::common_cpp::properties SAXI4_transactor_param_props;
    SAXI4_transactor_param_props.addLong("DATA_WIDTH", "128");
    SAXI4_transactor_param_props.addLong("FREQ_HZ", "550000000");
    SAXI4_transactor_param_props.addLong("ID_WIDTH", "16");
    SAXI4_transactor_param_props.addLong("ADDR_WIDTH", "64");
    SAXI4_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    SAXI4_transactor_param_props.addLong("WUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("RUSER_WIDTH", "17");
    SAXI4_transactor_param_props.addLong("BUSER_WIDTH", "0");
    SAXI4_transactor_param_props.addLong("HAS_BURST", "1");
    SAXI4_transactor_param_props.addLong("HAS_LOCK", "1");
    SAXI4_transactor_param_props.addLong("HAS_PROT", "1");
    SAXI4_transactor_param_props.addLong("HAS_CACHE", "1");
    SAXI4_transactor_param_props.addLong("HAS_QOS", "1");
    SAXI4_transactor_param_props.addLong("HAS_REGION", "1");
    SAXI4_transactor_param_props.addLong("HAS_WSTRB", "1");
    SAXI4_transactor_param_props.addLong("HAS_BRESP", "1");
    SAXI4_transactor_param_props.addLong("HAS_RRESP", "1");
    SAXI4_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    SAXI4_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    SAXI4_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    SAXI4_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    SAXI4_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    SAXI4_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    SAXI4_transactor_param_props.addLong("HAS_SIZE", "1");
    SAXI4_transactor_param_props.addLong("HAS_RESET", "0");
    SAXI4_transactor_param_props.addFloat("PHASE", "0.0");
    SAXI4_transactor_param_props.addString("PROTOCOL", "AXI4");
    SAXI4_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    SAXI4_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");

    mp_SAXI4_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("SAXI4_transactor", SAXI4_transactor_param_props);
  mp_SAXI4_transactor->ARADDR(IF_NOC_AXI_ARADDR);
  mp_SAXI4_transactor->ARBURST(IF_NOC_AXI_ARBURST);
  mp_SAXI4_transactor->ARCACHE(IF_NOC_AXI_ARCACHE);
  mp_SAXI4_transactor->ARID(IF_NOC_AXI_ARID);
  mp_SAXI4_transactor->ARLEN(IF_NOC_AXI_ARLEN);
  mp_IF_NOC_AXI_ARLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_ARLOCK_converter");
  mp_IF_NOC_AXI_ARLOCK_converter->vector_in(IF_NOC_AXI_ARLOCK);
  mp_IF_NOC_AXI_ARLOCK_converter->scalar_out(m_IF_NOC_AXI_ARLOCK_converter_signal);
  mp_SAXI4_transactor->ARLOCK(m_IF_NOC_AXI_ARLOCK_converter_signal);
  mp_SAXI4_transactor->ARPROT(IF_NOC_AXI_ARPROT);
  mp_SAXI4_transactor->ARQOS(IF_NOC_AXI_ARQOS);
  mp_SAXI4_transactor->ARREADY(IF_NOC_AXI_ARREADY);
  mp_SAXI4_transactor->ARREGION(IF_NOC_AXI_ARREGION);
  mp_SAXI4_transactor->ARSIZE(IF_NOC_AXI_ARSIZE);
  mp_SAXI4_transactor->ARUSER(IF_NOC_AXI_ARUSER);
  mp_SAXI4_transactor->ARVALID(IF_NOC_AXI_ARVALID);
  mp_SAXI4_transactor->AWADDR(IF_NOC_AXI_AWADDR);
  mp_SAXI4_transactor->AWBURST(IF_NOC_AXI_AWBURST);
  mp_SAXI4_transactor->AWCACHE(IF_NOC_AXI_AWCACHE);
  mp_SAXI4_transactor->AWID(IF_NOC_AXI_AWID);
  mp_SAXI4_transactor->AWLEN(IF_NOC_AXI_AWLEN);
  mp_IF_NOC_AXI_AWLOCK_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_AWLOCK_converter");
  mp_IF_NOC_AXI_AWLOCK_converter->vector_in(IF_NOC_AXI_AWLOCK);
  mp_IF_NOC_AXI_AWLOCK_converter->scalar_out(m_IF_NOC_AXI_AWLOCK_converter_signal);
  mp_SAXI4_transactor->AWLOCK(m_IF_NOC_AXI_AWLOCK_converter_signal);
  mp_SAXI4_transactor->AWPROT(IF_NOC_AXI_AWPROT);
  mp_SAXI4_transactor->AWQOS(IF_NOC_AXI_AWQOS);
  mp_SAXI4_transactor->AWREADY(IF_NOC_AXI_AWREADY);
  mp_SAXI4_transactor->AWREGION(IF_NOC_AXI_AWREGION);
  mp_SAXI4_transactor->AWSIZE(IF_NOC_AXI_AWSIZE);
  mp_SAXI4_transactor->AWUSER(IF_NOC_AXI_AWUSER);
  mp_SAXI4_transactor->AWVALID(IF_NOC_AXI_AWVALID);
  mp_SAXI4_transactor->BID(IF_NOC_AXI_BID);
  mp_SAXI4_transactor->BREADY(IF_NOC_AXI_BREADY);
  mp_SAXI4_transactor->BRESP(IF_NOC_AXI_BRESP);
  mp_SAXI4_transactor->BVALID(IF_NOC_AXI_BVALID);
  mp_SAXI4_transactor->RDATA(IF_NOC_AXI_RDATA);
  mp_SAXI4_transactor->RID(IF_NOC_AXI_RID);
  mp_IF_NOC_AXI_RLAST_converter = new xsc::common::scalar2vectorN_converter<1>("IF_NOC_AXI_RLAST_converter");
  mp_IF_NOC_AXI_RLAST_converter->scalar_in(m_IF_NOC_AXI_RLAST_converter_signal);
  mp_IF_NOC_AXI_RLAST_converter->vector_out(IF_NOC_AXI_RLAST);
  mp_SAXI4_transactor->RLAST(m_IF_NOC_AXI_RLAST_converter_signal);
  mp_SAXI4_transactor->RREADY(IF_NOC_AXI_RREADY);
  mp_SAXI4_transactor->RRESP(IF_NOC_AXI_RRESP);
  mp_SAXI4_transactor->RUSER(IF_NOC_AXI_RUSER);
  mp_SAXI4_transactor->RVALID(IF_NOC_AXI_RVALID);
  mp_SAXI4_transactor->WDATA(IF_NOC_AXI_WDATA);
  mp_IF_NOC_AXI_WLAST_converter = new xsc::common::vectorN2scalar_converter<1>("IF_NOC_AXI_WLAST_converter");
  mp_IF_NOC_AXI_WLAST_converter->vector_in(IF_NOC_AXI_WLAST);
  mp_IF_NOC_AXI_WLAST_converter->scalar_out(m_IF_NOC_AXI_WLAST_converter_signal);
  mp_SAXI4_transactor->WLAST(m_IF_NOC_AXI_WLAST_converter_signal);
  mp_SAXI4_transactor->WREADY(IF_NOC_AXI_WREADY);
  mp_SAXI4_transactor->WSTRB(IF_NOC_AXI_WSTRB);
  mp_SAXI4_transactor->WUSER(IF_NOC_AXI_WUSER);
  mp_SAXI4_transactor->WVALID(IF_NOC_AXI_WVALID);
  mp_SAXI4_transactor->CLK(aclk);
  m_SAXI4_transactor_rst_signal.write(1);
  mp_SAXI4_transactor->RST(m_SAXI4_transactor_rst_signal);

  // initialize transactors stubs
  SAXI4_transactor_target_wr_socket_stub = nullptr;
  SAXI4_transactor_target_rd_socket_stub = nullptr;

}

void bd_b77b_S00_AXI_nmu_0::before_end_of_elaboration()
{
  // configure 'SAXI4' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_b77b_S00_AXI_nmu_0", "SAXI4_TLM_MODE") != 1)
  {
    mp_impl->SAXI4_rd_socket->bind(*(mp_SAXI4_transactor->rd_socket));
    mp_impl->SAXI4_wr_socket->bind(*(mp_SAXI4_transactor->wr_socket));
  
  }
  else
  {
    SAXI4_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    SAXI4_transactor_target_wr_socket_stub->bind(*(mp_SAXI4_transactor->wr_socket));
    SAXI4_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    SAXI4_transactor_target_rd_socket_stub->bind(*(mp_SAXI4_transactor->rd_socket));
    mp_SAXI4_transactor->disable_transactor();
  }

}

#endif // MTI_SYSTEMC




bd_b77b_S00_AXI_nmu_0::~bd_b77b_S00_AXI_nmu_0()
{
  delete mp_SAXI4_transactor;
  delete mp_IF_NOC_AXI_ARLOCK_converter;
  delete mp_IF_NOC_AXI_AWLOCK_converter;
  delete mp_IF_NOC_AXI_RLAST_converter;
  delete mp_IF_NOC_AXI_WLAST_converter;

}

#ifdef MTI_SYSTEMC
SC_MODULE_EXPORT(bd_b77b_S00_AXI_nmu_0);
#endif

#ifdef XM_SYSTEMC
XMSC_MODULE_EXPORT(bd_b77b_S00_AXI_nmu_0);
#endif

#ifdef RIVIERA
SC_MODULE_EXPORT(bd_b77b_S00_AXI_nmu_0);
SC_REGISTER_BV(182);
#endif

