
 
 
 
 


// (c) Copyright 2023-2024 Advanced Micro Devices, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of AMD, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
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

#if defined(XILINX_SIMULATOR)// || defined(SC_ALD_EXT) || defined(XM_SYSTEMC) || defined(VCSSYSTEMC) || defined(MTI_SYSTEMC)
#define ENABLE_SIM_QDMA
#endif

#define MM_STUB_INTF_INIT(intf_type, intf_name, stub_type) \
    if(!intf_name)                                 \
    {                                              \
        stub_type.push_back(new xtlm::xtlm_aximm_initiator_stub("intf_type##_wr_stub", 128)); \
        stub_type.back()->initiator_socket(*intf_name); \
    }

#define MM_STUB_INTF_TARG(intf_type, intf_name, stub_type) \
    if(!intf_name)                                 \
    {                                              \
       stub_type.push_back(new xtlm::xtlm_aximm_target_stub("intf_type##_wr_stub", 128)); \
       intf_name->bind(stub_type.back()->target_socket);        \
    }
#define S_STUB_INTF_INIT(intf_type, intf_name, stub_type) \
    if(!intf_name)                                 \
    {                                              \
        stub_type.push_back(new xtlm::xtlm_axis_initiator_stub("intf_type##_wr_stub", 128)); \
        stub_type.back()->initiator_socket(*intf_name); \
    }

#define S_STUB_INTF_TARG(intf_type, intf_name, stub_type) \
    if(!intf_name)                                 \
    {                                              \
       stub_type.push_back(new xtlm::xtlm_axis_target_stub("intf_type##_wr_stub", 128)); \
       intf_name->bind(stub_type.back()->target_socket);        \
    }

#include "versal_cips_v3_4_9_tlm.h"
#include "RdWrTCPSocket.h"
#include "rwd_tlmmodel.h"
#include "extensions/pmc_aie_extension.h"
#include<fstream>
#include <dirent.h>
#include <cstring>
#include <sys/stat.h>

xtlm::xtlm_aximm_target_socket* __attribute__((weak)) get_aie_npi_rd_socket();
xtlm::xtlm_aximm_target_socket* __attribute__((weak)) get_aie_npi_wr_socket();

/***************************************************************************************
*   Global method, get registered with tlm2xtlm bridge
*   This function is called when tlm2xtlm bridge convert tlm payload to xtlm payload.
*
*   caller:     tlm2xtlm bridge
*   purpose:    To get master id and other parameters out of genattr_extension
*               and use master id to AxUSER PIN of xtlm payload.
*
*
***************************************************************************************/
void get_extensions_from_tlm(xtlm::aximm_payload* xtlm_pay, const tlm::tlm_generic_payload* gp)
{
    if((xtlm_pay == NULL) || (gp == NULL))
        return;
    if((gp->get_command() == tlm::TLM_WRITE_COMMAND) && (xtlm_pay->get_awuser_size() > 0))
    {
  genattr_extension* ext = NULL;
  gp->get_extension(ext);
        if(ext == NULL)
            return;
  //Portion of master ID(master_id[5:0]) are transfered on AxUSER bits(refere Zynq UltraScale+ TRM page.no:414)
  uint32_t val = ext->get_master_id() && 0x3F;
    unsigned char* ptr = xtlm_pay->get_awuser_ptr();
    unsigned int size  = xtlm_pay->get_awuser_size();
    *ptr = (unsigned char)val;

    }
    else if((gp->get_command() == tlm::TLM_READ_COMMAND) && (xtlm_pay->get_aruser_size() > 0))
    {
        genattr_extension* ext = NULL;
        gp->get_extension(ext);
        if(ext == NULL)
            return;
        //Portion of master ID(master_id[5:0]) are transfered on AxUSER bits(refere Zynq UltraScale+ TRM page.no:414)
        uint32_t val = ext->get_master_id() && 0x3F;
    unsigned char* ptr = xtlm_pay->get_aruser_ptr();
    unsigned int size  = xtlm_pay->get_aruser_size();
    *ptr = (unsigned char)val;
  }
}
void get_extensions_from_tlm_pmc_noc(xtlm::aximm_payload* xtlm_pay, const tlm::tlm_generic_payload* gp)
{
    if((xtlm_pay == NULL) || (gp == NULL))
        return;
    if((gp->get_command() == tlm::TLM_WRITE_COMMAND) && (xtlm_pay->get_awuser_size() > 0))
    {
  genattr_extension* ext = NULL;
  gp->get_extension(ext);
        if(ext == NULL)
            return;
  //Portion of master ID(master_id[5:0]) are transfered on AxUSER bits(refere Zynq UltraScale+ TRM page.no:414)
  uint32_t val = ext->get_master_id() && 0x3F;
    unsigned char* ptr = xtlm_pay->get_awuser_ptr();
    unsigned int size  = xtlm_pay->get_awuser_size();
    *ptr = (unsigned char)val;

    }
    else if((gp->get_command() == tlm::TLM_READ_COMMAND) && (xtlm_pay->get_aruser_size() > 0))
    {
        genattr_extension* ext = NULL;
        gp->get_extension(ext);
        if(ext == NULL)
            return;
        //Portion of master ID(master_id[5:0]) are transfered on AxUSER bits(refere Zynq UltraScale+ TRM page.no:414)
        uint32_t val = ext->get_master_id() && 0x3F;
    unsigned char* ptr = xtlm_pay->get_aruser_ptr();
    unsigned int size  = xtlm_pay->get_aruser_size();
    *ptr = (unsigned char)val;
  }
  if((gp->get_address() >= 0x20000000000) && (gp->get_address() <= 0x200FFFFFFFF)) {
        xsc::extension::pmc_aie_extension *m_pmc_aie_extension = new xsc::extension::pmc_aie_extension;
        xtlm_pay->set_extension(m_pmc_aie_extension);
  }
}

/***************************************************************************************
*   Global method, get registered with xtlm2tlm bridge
*   This function is called when xtlm2tlm bridge convert xtlm payload to tlm payload.
*
*   caller:     xtlm2tlm bridge
*   purpose:    To create and add master id and other parameters to genattr_extension.
*               Master id red from AxID PIN of xtlm payload.
*
*
***************************************************************************************/
void add_extensions_to_tlm(const xtlm::aximm_payload* xtlm_pay, tlm::tlm_generic_payload* gp)
{
    if(gp == NULL)
        return;
  uint8_t val = 0;
    if((gp->get_command() != tlm::TLM_WRITE_COMMAND) && (gp->get_command() != tlm::TLM_READ_COMMAND))
        return;
  //portion of master ID bits(master_id[5:0]) are derived from the AXI ID(AWID/ARID). (refere Zynq UltraScale+ TRM page.no:414,415)
  val = ((uint8_t)(xtlm_pay->get_axi_id())) && 0x3F;
  genattr_extension* ext = new genattr_extension;
  ext->set_master_id(val);
  gp->set_extension(ext);
  gp->set_streaming_width(gp->get_data_length());
  if(gp->get_command() != tlm::TLM_WRITE_COMMAND)
  {
    gp->set_byte_enable_length(0);
    gp->set_byte_enable_ptr(0);
  }
}

/*
template<int INIT_WIDTH, int TARGET_WIDTH>
class tlm_width_conversion :public sc_module {
  public:
    tlm_utils::simple_initiator_socket<tlm_width_conversion<INIT_WIDTH,TARGET_WIDTH>, INIT_WIDTH> initsock;
    tlm_utils::simple_target_socket<tlm_width_conversion<INIT_WIDTH,TARGET_WIDTH>, TARGET_WIDTH> tarsock;
    tlm_width_conversion<INIT_WIDTH, TARGET_WIDTH>(sc_module_name name):sc_module(name){
        tarsock.register_b_transport(this, &tlm_width_conversion<INIT_WIDTH, TARGET_WIDTH>::b_transport);
        tarsock.register_get_direct_mem_ptr(this, &tlm_width_conversion<INIT_WIDTH, TARGET_WIDTH>::get_direct_mem_ptr);
        tarsock.register_transport_dbg(this, &tlm_width_conversion<INIT_WIDTH, TARGET_WIDTH>::transport_dbg);
    }
    private:
    void b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay){
        initsock->b_transport(trans, delay);
    }
    unsigned int transport_dbg(tlm::tlm_generic_payload& trans){
        return initsock->transport_dbg(trans);
    }
    bool get_direct_mem_ptr(tlm::tlm_generic_payload& trans, tlm::tlm_dmi& dmi_data){
        return initsock->get_direct_mem_ptr(trans, dmi_data);
    }
};
*/

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                              //
// File:            versal_cips_v3_4_tlm.cpp                                                                         //
//                                                                                                              //
// Description:     versal_cips_v3_4_9_tlm class is a sc_module, act as intermediate layer between                     //
//                  xilinx_zynqmp qemu wrapper and Vivado generated systemc simulation ip wrapper.              //
//                  it's basically created for supporting tlm based xilinx_zynqmp from xtlm based vivado        //
//                  generated systemc wrapper. this wrapper is live only when SELECTED_SIM_MODEL is set         //
//                  to tlm. it's also act as bridge between vivado wrapper and xilinx_zynqmp wrapper.           //
//                  it fill the the gap between input/output ports of vivado generated wrapper to               //
//                  xilinx_zynqmp wrapper signals. This wrapper is auto generated by ttcl scripts               //
//                  based on IP configuration in vivado.                                                        //
//                                                                                                              //
//                                                                                                              //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
namespace cips_tlm {
    void export_simulation();
    void setup_for_mcpath() __attribute__ ((constructor));
}
void StartThreadedTCPServer(RdWrTCPSocket* m_rdwrtcpsock);
//TODO update clk with original freq from PARAM
//constructor having three paramters
// 1. module name in sc_module_name objec,
// 2. reference to map object of name and integer value pairs
// 3. reference to map object of name and string value pairs
// All the model parameters (integer and string) which are configuration parameters
// of ZynqUltraScale+ IP propogated from Vivado
versal_cips_v3_4_9_tlm :: versal_cips_v3_4_9_tlm (sc_core::sc_module_name name,
  xsc::common_cpp::properties model_param_props) : sc_module(name) //registering module name with parent
    ,pl0_ref_clk("pl0_ref_clk")
    ,pl0_resetn("pl0_resetn")
    ,m_axi_lpd_aclk("m_axi_lpd_aclk")
    ,fpd_cci_noc_axi0_clk("fpd_cci_noc_axi0_clk")
    ,fpd_cci_noc_axi1_clk("fpd_cci_noc_axi1_clk")
    ,fpd_cci_noc_axi2_clk("fpd_cci_noc_axi2_clk")
    ,fpd_cci_noc_axi3_clk("fpd_cci_noc_axi3_clk")
    ,lpd_axi_noc_clk("lpd_axi_noc_clk")
    ,pmc_axi_noc_axi0_clk("pmc_axi_noc_axi0_clk")
    ,gem0_tsu_timer_cnt("gem0_tsu_timer_cnt")
    ,pl_ps_irq0("pl_ps_irq0")
    ,pl_ps_irq1("pl_ps_irq1")
    ,pl0_ref_clk_clk("pl0_ref_clk_clk", sc_time(10.0,sc_core::SC_NS))//clock period in NANO oseconds = 1000/freq(in MZ)
    ,pmc_noc_clk("pmc_noc_clk", sc_time(3.125,sc_core::SC_NS))//clock period in NANOseconds = 1000/freq(in MZ)
    ,m_rp_bridge_M_AXI_LPD("m_rp_bridge_M_AXI_LPD")
    ,m_rp_bridge_FPD_CCI_NOC_0("m_rp_bridge_FPD_CCI_NOC_0")
    ,m_rp_bridge_FPD_CCI_NOC_1("m_rp_bridge_FPD_CCI_NOC_1")
    ,m_rp_bridge_FPD_CCI_NOC_2("m_rp_bridge_FPD_CCI_NOC_2")
    ,m_rp_bridge_FPD_CCI_NOC_3("m_rp_bridge_FPD_CCI_NOC_3")
    ,m_rp_bridge_LPD_AXI_NOC_0("m_rp_bridge_LPD_AXI_NOC_0")
    ,m_rp_bridge_PMC_NOC_AXI_0("m_rp_bridge_PMC_NOC_AXI_0")
    ,dummy_usr_irq_req("dummy_usr_irq_req")
    ,dummy_usr_irq_ack("dummy_usr_irq_ack")
{
    cips_tlm::export_simulation();
    fpd_cci_noc_clk = NULL;
    lpd_axi_noc_clk_sig = NULL;
        fpd_cci_noc_clk = new sc_core::sc_clock("fpd_cci_noc_clk",sc_time(1.8181818181818181,sc_core::SC_NS));
        lpd_axi_noc_clk_sig = new sc_core::sc_clock("lpd_axi_noc_clk_sig",sc_time(2.5,sc_core::SC_NS));
  //  Start versal_cips_v3_4_9_tlm()
  //creating instances of xtlm slave sockets
  // pmc_noc interface related initialization...
  m_rwd_tlmmodel = NULL;
  m_rdwrtcpsock = NULL;
  m_rwd_thread = NULL;
  rwd_tlm2xtlm_brdg = NULL;
  rwd_pmc_interconnect = NULL;
M_AXI_LPD_tlm_aximm_write_socket = new xtlm::xtlm_aximm_initiator_socket("M_AXI_LPD_tlm_aximm_write_socket",128);
M_AXI_LPD_tlm_aximm_read_socket = new xtlm::xtlm_aximm_initiator_socket("M_AXI_LPD_tlm_aximm_read_socket",128);
FPD_CCI_NOC_0_tlm_aximm_write_socket = new xtlm::xtlm_aximm_initiator_socket("FPD_CCI_NOC_0_tlm_aximm_write_socket",128 );
FPD_CCI_NOC_0_tlm_aximm_read_socket = new xtlm::xtlm_aximm_initiator_socket("FPD_CCI_NOC_0_tlm_aximm_read_socket",128 );
FPD_CCI_NOC_1_tlm_aximm_write_socket = new xtlm::xtlm_aximm_initiator_socket("FPD_CCI_NOC_1_tlm_aximm_write_socket",128 );
FPD_CCI_NOC_1_tlm_aximm_read_socket = new xtlm::xtlm_aximm_initiator_socket("FPD_CCI_NOC_1_tlm_aximm_read_socket",128 );
FPD_CCI_NOC_2_tlm_aximm_write_socket = new xtlm::xtlm_aximm_initiator_socket("FPD_CCI_NOC_2_tlm_aximm_write_socket",128 );
FPD_CCI_NOC_2_tlm_aximm_read_socket = new xtlm::xtlm_aximm_initiator_socket("FPD_CCI_NOC_2_tlm_aximm_read_socket",128 );
FPD_CCI_NOC_3_tlm_aximm_write_socket = new xtlm::xtlm_aximm_initiator_socket("FPD_CCI_NOC_3_tlm_aximm_write_socket",128 );
FPD_CCI_NOC_3_tlm_aximm_read_socket = new xtlm::xtlm_aximm_initiator_socket("FPD_CCI_NOC_3_tlm_aximm_read_socket",128 );
LPD_AXI_NOC_0_tlm_aximm_write_socket = new xtlm::xtlm_aximm_initiator_socket("LPD_AXI_NOC_0_tlm_aximm_write_socket",128 );
LPD_AXI_NOC_0_tlm_aximm_read_socket = new xtlm::xtlm_aximm_initiator_socket("LPD_AXI_NOC_0_tlm_aximm_read_socket",128 );
PMC_NOC_AXI_0_tlm_aximm_write_socket = new xtlm::xtlm_aximm_initiator_socket("PMC_NOC_AXI_0_tlm_aximm_write_socket",128 );
PMC_NOC_AXI_0_tlm_aximm_read_socket = new xtlm::xtlm_aximm_initiator_socket("PMC_NOC_AXI_0_tlm_aximm_read_socket",128 );
        //Adding AXIMM/AXIS interfaces here
  
        //Adding AXIMM/AXIS interfaces here for XRAM
  char* tcpip_addr = getenv("COSIM_MACHINE_TCPIP_ADDRESS");
  char* unix_addr = getenv("COSIM_MACHINE_PATH");
  char* skt_name;
  if (unix_addr != NULL){
      skt_name = strdup(unix_addr);
  } else if (tcpip_addr != NULL) {
      skt_name = strdup(tcpip_addr);
  } else {
      tcpip_addr = "NO_IP_ADDRESS";
      skt_name = strdup(tcpip_addr);
  }
  m_zynq3_tlm_model = new xilinx_versal_vitis("xilinx_versal_vitis",skt_name);

  //quantumkeeper value update
  char* qk_value = getenv("TLM_QUANTUM_IN_PS");
  if(qk_value != NULL) {
      double value = atof(qk_value);
      m_zynq3_tlm_model->m_qk.set_global_quantum(sc_core::sc_time(value,SC_PS));
  } else {
      m_zynq3_tlm_model->m_qk.set_global_quantum(sc_core::sc_time(20,SC_NS));
  }
  m_zynq3_tlm_model->m_qk.reset();



  XRAM_connections();

  //instantiating TLM2XTLM bridge and stiching it between
  //m_axi_gp_2 initiator socket of zynqmp Qemu tlm wrapper to M_AXI_LPD_tlm_aximm_write_socket/rd_socket sockets
  m_rp_bridge_M_AXI_LPD.clk(m_axi_lpd_aclk);
  m_rp_bridge_M_AXI_LPD.wr_socket.bind(*M_AXI_LPD_tlm_aximm_write_socket);
  m_rp_bridge_M_AXI_LPD.rd_socket.bind(*M_AXI_LPD_tlm_aximm_read_socket);
  m_rp_bridge_M_AXI_LPD.target_socket.bind(*m_zynq3_tlm_model->m_axi_lpd);

  //instantiating TLM2XTLM bridge and stiching it between
  //if_ps_noc_cci_0 initiator socket of zynqmp Qemu tlm wrapper to FPD_CCI_NOC_0_tlm_aximm_write_socket/rd_socket sockets
  m_rp_bridge_FPD_CCI_NOC_0.clk(fpd_cci_noc_axi0_clk);
  m_rp_bridge_FPD_CCI_NOC_0.wr_socket.bind(*FPD_CCI_NOC_0_tlm_aximm_write_socket);
  m_rp_bridge_FPD_CCI_NOC_0.rd_socket.bind(*FPD_CCI_NOC_0_tlm_aximm_read_socket);
  m_rp_bridge_FPD_CCI_NOC_0.target_socket.bind(*m_zynq3_tlm_model->fpd_cci_noc_0);

  //instantiating TLM2XTLM bridge and stiching it between
  //if_ps_noc_cci_1 initiator socket of zynqmp Qemu tlm wrapper to FPD_CCI_NOC_1_tlm_aximm_write_socket/rd_socket sockets
  m_rp_bridge_FPD_CCI_NOC_1.clk(fpd_cci_noc_axi1_clk);
  m_rp_bridge_FPD_CCI_NOC_1.wr_socket.bind(*FPD_CCI_NOC_1_tlm_aximm_write_socket);
  m_rp_bridge_FPD_CCI_NOC_1.rd_socket.bind(*FPD_CCI_NOC_1_tlm_aximm_read_socket);
  m_rp_bridge_FPD_CCI_NOC_1.target_socket.bind(*m_zynq3_tlm_model->fpd_cci_noc_1);

  //instantiating TLM2XTLM bridge and stiching it between
  //if_ps_noc_cci_2 initiator socket of zynqmp Qemu tlm wrapper to FPD_CCI_NOC_2_tlm_aximm_write_socket/rd_socket sockets
  m_rp_bridge_FPD_CCI_NOC_2.clk(fpd_cci_noc_axi2_clk);
  m_rp_bridge_FPD_CCI_NOC_2.wr_socket.bind(*FPD_CCI_NOC_2_tlm_aximm_write_socket);
  m_rp_bridge_FPD_CCI_NOC_2.rd_socket.bind(*FPD_CCI_NOC_2_tlm_aximm_read_socket);
  m_rp_bridge_FPD_CCI_NOC_2.target_socket.bind(*m_zynq3_tlm_model->fpd_cci_noc_2);

  //instantiating TLM2XTLM bridge and stiching it between
  //if_ps_noc_cci_3 initiator socket of zynqmp Qemu tlm wrapper to FPD_CCI_NOC_3_tlm_aximm_write_socket/rd_socket sockets
  m_rp_bridge_FPD_CCI_NOC_3.clk(fpd_cci_noc_axi3_clk);
  m_rp_bridge_FPD_CCI_NOC_3.wr_socket.bind(*FPD_CCI_NOC_3_tlm_aximm_write_socket);
  m_rp_bridge_FPD_CCI_NOC_3.rd_socket.bind(*FPD_CCI_NOC_3_tlm_aximm_read_socket);
  m_rp_bridge_FPD_CCI_NOC_3.target_socket.bind(*m_zynq3_tlm_model->fpd_cci_noc_3);

  //instantiating TLM2XTLM bridge and stiching it between
  //if_ps_noc_rpu_0 initiator socket of zynqmp Qemu tlm wrapper to LPD_AXI_NOC_0_tlm_aximm_write_socket/rd_socket sockets
  m_rp_bridge_LPD_AXI_NOC_0.clk(lpd_axi_noc_clk);
  m_rp_bridge_LPD_AXI_NOC_0.wr_socket.bind(*LPD_AXI_NOC_0_tlm_aximm_write_socket);
  m_rp_bridge_LPD_AXI_NOC_0.rd_socket.bind(*LPD_AXI_NOC_0_tlm_aximm_read_socket);
  m_rp_bridge_LPD_AXI_NOC_0.target_socket.bind(*m_zynq3_tlm_model->noc_lpd_axi_0);

  //instantiating TLM2XTLM bridge and stiching it between
  //if_pmc_noc_axi_0 initiator socket of zynqmp Qemu tlm wrapper to FPD_AXI_NOC_0_tlm_aximm_write_socket/rd_socket sockets
  rwd_tlmmodule_init();

  SC_METHOD(pl_ps_irq_method);
   
  sensitive << pl_ps_irq0 ;
   
  sensitive << pl_ps_irq1 ;
  dont_initialize();

  SC_METHOD(trigger_pl0_ref_clk_pin);
  sensitive << pl0_ref_clk_clk;
  dont_initialize();


  SC_METHOD(trigger_ps_pmc_noc_axi0_clk_pin);
  sensitive << pmc_noc_clk;
  dont_initialize();
  SC_METHOD(trigger_ps_noc_cci_axi0_clk_pin);
  sensitive << *fpd_cci_noc_clk;
  dont_initialize();
  SC_METHOD(trigger_ps_noc_cci_axi1_clk_pin);
  sensitive << *fpd_cci_noc_clk;
  dont_initialize();
  SC_METHOD(trigger_ps_noc_cci_axi2_clk_pin);
  sensitive << *fpd_cci_noc_clk;
  dont_initialize();
  SC_METHOD(trigger_ps_noc_cci_axi3_clk_pin);
  sensitive << *fpd_cci_noc_clk;
  dont_initialize();
  SC_METHOD(trigger_lpd_axi_noc_clk_pin);
  sensitive << *lpd_axi_noc_clk_sig;
  dont_initialize();

  m_rp_bridge_M_AXI_LPD.registerUserExtensionHandlerCallback(&get_extensions_from_tlm);
  m_rp_bridge_FPD_CCI_NOC_0.registerUserExtensionHandlerCallback(&get_extensions_from_tlm);
  m_rp_bridge_FPD_CCI_NOC_1.registerUserExtensionHandlerCallback(&get_extensions_from_tlm);
  m_rp_bridge_FPD_CCI_NOC_2.registerUserExtensionHandlerCallback(&get_extensions_from_tlm);
  m_rp_bridge_FPD_CCI_NOC_3.registerUserExtensionHandlerCallback(&get_extensions_from_tlm);
  m_rp_bridge_LPD_AXI_NOC_0.registerUserExtensionHandlerCallback(&get_extensions_from_tlm);
  m_rp_bridge_PMC_NOC_AXI_0.registerUserExtensionHandlerCallback(&get_extensions_from_tlm_pmc_noc);

  m_zynq3_tlm_model->rst(qemu_rst);

  SC_METHOD(pl0_resetn_trigger);
  sensitive << m_zynq3_tlm_model->pl_reset[0];
  //  End versal_cips_v3_4_9_tlm()
}

versal_cips_v3_4_9_tlm :: ~versal_cips_v3_4_9_tlm() {
  //deleting dynamically created objects
  if(fpd_cci_noc_clk != NULL) {
      delete fpd_cci_noc_clk;
      fpd_cci_noc_clk = NULL;
  }
  if(lpd_axi_noc_clk_sig != NULL) {
      delete lpd_axi_noc_clk_sig;
      lpd_axi_noc_clk_sig = NULL;
  }
    delete M_AXI_LPD_tlm_aximm_write_socket;
    delete M_AXI_LPD_tlm_aximm_read_socket;
M_AXI_LPD_tlm_aximm_write_socket = NULL;
M_AXI_LPD_tlm_aximm_read_socket = NULL;
    delete FPD_CCI_NOC_0_tlm_aximm_write_socket;
    delete FPD_CCI_NOC_0_tlm_aximm_read_socket;
FPD_CCI_NOC_0_tlm_aximm_write_socket = NULL;
FPD_CCI_NOC_0_tlm_aximm_read_socket = NULL;
    delete FPD_CCI_NOC_1_tlm_aximm_write_socket;
    delete FPD_CCI_NOC_1_tlm_aximm_read_socket;
FPD_CCI_NOC_1_tlm_aximm_write_socket = NULL;
FPD_CCI_NOC_1_tlm_aximm_read_socket = NULL;
    delete FPD_CCI_NOC_2_tlm_aximm_write_socket;
    delete FPD_CCI_NOC_2_tlm_aximm_read_socket;
FPD_CCI_NOC_2_tlm_aximm_write_socket = NULL;
FPD_CCI_NOC_2_tlm_aximm_read_socket = NULL;
    delete FPD_CCI_NOC_3_tlm_aximm_write_socket;
    delete FPD_CCI_NOC_3_tlm_aximm_read_socket;
FPD_CCI_NOC_3_tlm_aximm_write_socket = NULL;
FPD_CCI_NOC_3_tlm_aximm_read_socket = NULL;
    delete LPD_AXI_NOC_0_tlm_aximm_write_socket;
    delete LPD_AXI_NOC_0_tlm_aximm_read_socket;
LPD_AXI_NOC_0_tlm_aximm_write_socket = NULL;
LPD_AXI_NOC_0_tlm_aximm_read_socket = NULL;
    delete PMC_NOC_AXI_0_tlm_aximm_write_socket;
    delete PMC_NOC_AXI_0_tlm_aximm_read_socket;
PMC_NOC_AXI_0_tlm_aximm_write_socket = NULL;
PMC_NOC_AXI_0_tlm_aximm_read_socket = NULL;

    if(m_xtlm2tlm_10 != 0) {
        delete m_xtlm2tlm_10;
    }

  //deleting the thread object, RdWrTCPSocket and rwd_tlmmodel
  if(m_rwd_thread != NULL){
    delete m_rwd_thread;
    m_rwd_thread = NULL;
  }
  if(m_rdwrtcpsock != NULL){
    delete m_rdwrtcpsock;
    m_rdwrtcpsock = NULL;
  }
  if(m_rwd_tlmmodel != NULL){
    delete m_rwd_tlmmodel;
    m_rwd_tlmmodel = NULL;
  }
  if(rwd_tlm2xtlm_brdg != NULL){
    delete rwd_tlm2xtlm_brdg;
    rwd_tlm2xtlm_brdg = NULL;
  }
  if(rwd_pmc_interconnect != NULL){
    delete rwd_pmc_interconnect;
    rwd_pmc_interconnect = NULL;
  }
#ifndef XM_SYSTEMC
#endif
}

//Method which is sentive to pl0_ref_clk_clk sc_clock object
//pl0_ref_clk pin written based on pl0_ref_clk_clk clock value
void versal_cips_v3_4_9_tlm :: trigger_pl0_ref_clk_pin() {
    pl0_ref_clk.write(pl0_ref_clk_clk.read());
}
void versal_cips_v3_4_9_tlm :: trigger_ps_pmc_noc_axi0_clk_pin() {
    pmc_axi_noc_axi0_clk.write(pmc_noc_clk.read());
}

void versal_cips_v3_4_9_tlm :: trigger_ps_noc_cci_axi0_clk_pin() {
  fpd_cci_noc_axi0_clk.write((*fpd_cci_noc_clk).read());
}
void versal_cips_v3_4_9_tlm :: trigger_ps_noc_cci_axi1_clk_pin() {
  fpd_cci_noc_axi1_clk.write((*fpd_cci_noc_clk).read());
}
void versal_cips_v3_4_9_tlm :: trigger_ps_noc_cci_axi2_clk_pin() {
  fpd_cci_noc_axi2_clk.write((*fpd_cci_noc_clk).read());
}
void versal_cips_v3_4_9_tlm :: trigger_ps_noc_cci_axi3_clk_pin() {
  fpd_cci_noc_axi3_clk.write((*fpd_cci_noc_clk).read());
}
  void versal_cips_v3_4_9_tlm :: trigger_lpd_axi_noc_clk_pin() {
    lpd_axi_noc_clk.write((*lpd_axi_noc_clk_sig).read());
  }

void versal_cips_v3_4_9_tlm :: pl_ps_irq_method() {
   
  if(pl_ps_irq0.event()) {
    m_zynq3_tlm_model->pl2ps_irq[0].write(pl_ps_irq0.read());
  }
   
  if(pl_ps_irq1.event()) {
    m_zynq3_tlm_model->pl2ps_irq[1].write(pl_ps_irq1.read());
  }
}
//pl0_resetn output reset pin get toggle when emio bank 2's 31th signal gets toggled
//EMIO[2] bank 31th(GPIO[95] signal)acts as reset signal to the PL(refer Zynq UltraScale+ TRM, page no:761)
void versal_cips_v3_4_9_tlm :: pl0_resetn_trigger() {
    pl0_resetn.write(m_zynq3_tlm_model->pl_reset[0]);
}

void versal_cips_v3_4_9_tlm :: start_of_simulation()
{
  qemu_rst.write(false);
  char* tcpip_addr = getenv("COSIM_MACHINE_TCPIP_ADDRESS");
  char* unix_addr = getenv("COSIM_MACHINE_PATH");
  if(tcpip_addr == NULL && unix_addr == NULL) {
      std::cerr << "\n\n############################################################## \n#\n"
                << " #  You have set SELECTED_SIM_MODLE=TLM for Versal CIPS block.\n" 
                << " #  Since this requires software content, the QEMU based simulation in Vivado will not generate any transactions on master interfaces and will also not respond to any transactions on slave interfaces.\n" 
                << " #  To use SW driven simulation, create use the Vitis flow\n" 
                << "\n#\n##############################################################\n\n";
      //exit(0);
  }
  char* rwd = getenv("ENABLE_RDWR_DEBUG");
  if((rwd != NULL) && (strcasecmp(rwd, "true") == 0)) {
    char* rdwr_port = getenv("RDWR_DEBUG_PORT");
    int rdwr_port_number = 10100;
    std::cout << "ENABLE_RDWR_DEBUG is set"<<std::endl;
    if(rdwr_port == NULL) {
      std::cout << "\nRDWR_DEBUG_PORT is not mentioned. Default port number is 10100" << std::endl;
    }
    else {
      char* skt_name = strdup(rdwr_port);
      rdwr_port_number = atoi(skt_name);
      std::cout << "\nRDWR_DEBUG_PORT is " << dec << rdwr_port_number << std::endl;
    }
    m_rdwrtcpsock = new RdWrTCPSocket(rdwr_port_number);
    m_rwd_thread = new std::thread(StartThreadedTCPServer,m_rdwrtcpsock);
  }
}
void versal_cips_v3_4_9_tlm :: rwd_tlmmodule_init() {
    // instantiating xtlm_interconnect with 2 slave and one master interface
    xsc::common_cpp::properties imp_prop;
    imp_prop.addLong("C_NUM_SI","2");
    imp_prop.addLong("C_NUM_MI","1");
    imp_prop.addLong("C_ADDR_RANGES","1");

    std::string width = std::to_string(128);
    std::string addr_width = std::to_string(128);
    imp_prop.addLong("C_M00_AXI_DATA_WIDTH",width.c_str());
    imp_prop.addLong("C_M00_AXI_ADDR_WIDTH",addr_width.c_str());
    imp_prop.addLong("C_M00_A00_BASE_ADDRESS","0x0");
    imp_prop.addLong("C_M00_A00_ADDR_RANGE","0xFFFFFFFFFFFFFFFF");

    imp_prop.addLong("C_S00_AXI_DATA_WIDTH",width.c_str());
    imp_prop.addLong("C_S00_AXI_ADDR_WIDTH",addr_width.c_str());
    imp_prop.addLong("C_S01_AXI_DATA_WIDTH",width.c_str());
    imp_prop.addLong("C_S01_AXI_ADDR_WIDTH",addr_width.c_str());

    imp_prop.addLong("C_M00_S00_CONNECTIVITY","1");
    imp_prop.addLong("C_M00_S01_CONNECTIVITY","1");
    rwd_pmc_interconnect = new xtlm_simple_interconnect_model("rwd_pmc_interconnect",imp_prop);
    rwd_pmc_interconnect->initiator_wr_sockets[0]->bind(*PMC_NOC_AXI_0_tlm_aximm_write_socket);
    rwd_pmc_interconnect->initiator_rd_sockets[0]->bind(*PMC_NOC_AXI_0_tlm_aximm_read_socket);

    //intantiating rwd_tcpserver and rwd_tlmmodel here
    m_rwd_tlmmodel = dynamic_cast<rwd_tlmmodel*>(&rwd_interface::getInstance());
    rwd_tlm2xtlm_brdg = new rptlm2xtlm_converter<32, 128>("rwd_tlm2xtlm_brdg");

    m_rwd_tlmmodel->init_sock(rwd_tlm2xtlm_brdg->target_socket);
    rwd_tlm2xtlm_brdg->rd_socket.bind(*rwd_pmc_interconnect->target_rd_sockets[1]);
    rwd_tlm2xtlm_brdg->wr_socket.bind(*rwd_pmc_interconnect->target_wr_sockets[1]);
    rwd_tlm2xtlm_brdg->clk(pmc_axi_noc_axi0_clk);

    //Qemu to simple_interconnect
    m_rp_bridge_PMC_NOC_AXI_0.clk(pmc_axi_noc_axi0_clk);
    m_rp_bridge_PMC_NOC_AXI_0.wr_socket.bind(*rwd_pmc_interconnect->target_wr_sockets[0]);
    m_rp_bridge_PMC_NOC_AXI_0.rd_socket.bind(*rwd_pmc_interconnect->target_rd_sockets[0]);
    m_rp_bridge_PMC_NOC_AXI_0.target_socket.bind(*m_zynq3_tlm_model->pmc_noc_axi_0);

}
#ifndef XM_SYSTEMC
void versal_cips_v3_4_9_tlm :: enable_sim_qdma() {
}
#else
void versal_cips_v3_4_9_tlm :: disable_sim_qdma(){
}
#endif
void StartThreadedTCPServer(RdWrTCPSocket* m_rdwrtcpsock) {
  m_rdwrtcpsock->StartTCPServer();
}
template <int IN_WIDTH, int OUT_WIDTH>
rptlm2xtlm_converter<IN_WIDTH, OUT_WIDTH>::rptlm2xtlm_converter(sc_module_name name):sc_module(name)
  ,target_socket("target_socket")
  ,wr_socket("init_wr_socket",OUT_WIDTH)
  ,rd_socket("init_rd_socket",OUT_WIDTH)
  ,m_btrans_conv("b_transport_converter")
  ,xtlm_bridge("tlm2xtlmbridge")
{
  target_socket.bind(m_btrans_conv.target_socket);
  m_btrans_conv.initiator_socket.bind(xtlm_bridge.target_socket);
  xtlm_bridge.rd_socket->bind(rd_socket);
  xtlm_bridge.wr_socket->bind(wr_socket);
}
template <int IN_WIDTH, int OUT_WIDTH>
void rptlm2xtlm_converter<IN_WIDTH, OUT_WIDTH>::registerUserExtensionHandlerCallback(
  void (*callback)(xtlm::aximm_payload*,
    const tlm::tlm_generic_payload*)) {
  xtlm_bridge.registerUserExtensionHandlerCallback(callback);
}
template <int IN_WIDTH, int OUT_WIDTH>
void rptlm2xtlm_converter<IN_WIDTH, OUT_WIDTH>::before_end_of_elaboration() {
  m_btrans_conv.clk(clk);
}

void versal_cips_v3_4_9_tlm :: before_end_of_elaboration() {
    if(get_aie_npi_wr_socket && get_aie_npi_rd_socket) {
        xtlm::xtlm_aximm_target_socket* wr_intf = get_aie_npi_wr_socket();
        xtlm::xtlm_aximm_target_socket* rd_intf = get_aie_npi_rd_socket();
        if(rd_intf && wr_intf) {
            m_rp_bridge_pmc_npi_aie2 = new rptlm2xtlm_converter<32,32 >("m_rp_bridge_pmc_npi_aie2");
            m_rp_bridge_pmc_npi_aie2->clk(fpd_cci_noc_axi0_clk);
            m_rp_bridge_pmc_npi_aie2->wr_socket.bind(*wr_intf);
            m_rp_bridge_pmc_npi_aie2->rd_socket.bind(*rd_intf);
            m_rp_bridge_pmc_npi_aie2->target_socket.bind(*m_zynq3_tlm_model->pmc_npi);
        } else {
            m_rp_bridge_pmc_npi_aie2 = NULL;
        }
    } 
    else 
    {
        m_rp_bridge_pmc_npi_aie2 = NULL;
    }
    m_zynq3_tlm_model->tie_off();
}

void versal_cips_v3_4_9_tlm :: end_of_elaboration() {
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,M_AXI_LPD_tlm_aximm_read_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,M_AXI_LPD_tlm_aximm_write_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,FPD_CCI_NOC_0_tlm_aximm_read_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,FPD_CCI_NOC_0_tlm_aximm_write_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,FPD_CCI_NOC_1_tlm_aximm_read_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,FPD_CCI_NOC_1_tlm_aximm_write_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,FPD_CCI_NOC_2_tlm_aximm_read_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,FPD_CCI_NOC_2_tlm_aximm_write_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,FPD_CCI_NOC_3_tlm_aximm_read_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,FPD_CCI_NOC_3_tlm_aximm_write_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,LPD_AXI_NOC_0_tlm_aximm_read_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,LPD_AXI_NOC_0_tlm_aximm_write_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,PMC_NOC_AXI_0_tlm_aximm_read_socket,aximm_master_stub)
        MM_STUB_INTF_INIT(xtlm::xtlm_aximm_initiator_socket,PMC_NOC_AXI_0_tlm_aximm_write_socket,aximm_master_stub)
        //Adding AXIMM/AXIS interfaces here


}
void versal_cips_v3_4_9_tlm :: XRAM_connections() {

  unsigned int intf_count = 0;

if(intf_count > 0) {
  unsigned int count = 0;
  std::stringstream ss;
  ss << intf_count;
  std::string str = ss.str();

  std::string intr_addr_width[4] = {
    "C_S00_AXI_ADDR_WIDTH",    
    "C_S01_AXI_ADDR_WIDTH",    
    "C_S02_AXI_ADDR_WIDTH",    
    "C_S03_AXI_ADDR_WIDTH" };    

  std::string intr_datawidth[4] = {
    "C_S00_AXI_DATA_WIDTH",
    "C_S01_AXI_DATA_WIDTH",
    "C_S02_AXI_DATA_WIDTH",
    "C_S03_AXI_DATA_WIDTH" };

  std::string intf_connectivity[4] = {
    "C_M00_S00_CONNECTIVITY",
    "C_M00_S01_CONNECTIVITY",
    "C_M00_S02_CONNECTIVITY",
    "C_M00_S03_CONNECTIVITY" };

  xsc::common_cpp::properties imp_prop;
  imp_prop.addLong("C_NUM_SI",str.c_str());
  imp_prop.addLong("C_NUM_MI","1");
  imp_prop.addLong("C_ADDR_RANGES","1");

  std::string width;

  imp_prop.addLong("C_M00_AXI_DATA_WIDTH","32");
  imp_prop.addLong("C_M00_AXI_ADDR_WIDTH","64");
  imp_prop.addLong("C_M00_A00_BASE_ADDRESS","0x0");
  imp_prop.addLong("C_M00_A00_ADDR_RANGE","0xFFFFFFFFFFFFFFFF");

  xram_interconnect = new xtlm_simple_interconnect_model("XRAM_interconnect",imp_prop);
  count =0;
  
  m_xtlm2tlm_10 = new xtlm::xaximm_xtlm2tlm_t<32,32>("XRAM_xtlm2tlm_bg");
  xram_interconnect->initiator_wr_sockets[0]->bind(*m_xtlm2tlm_10->wr_socket);
  xram_interconnect->initiator_rd_sockets[0]->bind(*m_xtlm2tlm_10->rd_socket);
  m_zynq3_tlm_model->s_axi_xram->bind(m_xtlm2tlm_10->initiator_socket);

} else {
   xram_interconnect = 0;
   m_xtlm2tlm_10 = 0;
}

}




namespace cips_tlm {
    bool findFileInDirectory(const std::string& directoryPath, const std::string& fileName) {
        DIR* dir = opendir(directoryPath.c_str());
        if (!dir) {
            return false;
        }

        struct dirent* entry;
        while ((entry = readdir(dir)) != NULL) {
            if (fileName == entry->d_name) {
                closedir(dir);
                return true;
            }
        }

        closedir(dir);
        return false;
    }
    void export_simulation() {
        static bool call = false;
        if(!call) {
            call = true;
            auto cosim_path = std::getenv("COSIM_MACHINE_PATH");
            if(cosim_path)  // return if env is already set
                return;
            const char* unix_sock = "unix:./qemu-rport-_pl@0";
            //int ret = std::system("ls qemu-rport-_pl@0 &> /dev/null");
            bool ret =findFileInDirectory(".", "qemu-rport-_pl@0");
            if(ret == false){
                return;
            }
            setenv("COSIM_MACHINE_PATH",unix_sock,0);
    
            std::string noc_mem_file = "noc_memory_config.txt";
            std::ifstream fin(noc_mem_file.c_str(), std::ios::in);
            if(!fin.good()) {
                return;
            }
            setenv("NOCSIM_MULTI_DRAM_FILE",noc_mem_file.c_str(),0);
        }
    }
    void setup_for_mcpath() {
        auto mcpath_env = std::getenv("QEMU_MACHINE_PATH");
        if(mcpath_env == nullptr)
            return;
        std::string noc_org_file_path(mcpath_env);
        noc_org_file_path.append("/noc_memory_config.txt");
        std::ifstream noc_org_file(noc_org_file_path.c_str());
        if (!noc_org_file.is_open())
            return;
        std::string line;
        std::ofstream new_noc_file("noc_memory_config_reloc.txt");
        if(!new_noc_file.is_open())
            return;
        while (std::getline(noc_org_file, line))
        {
            new_noc_file<< mcpath_env<< "/" <<line<<std::endl ;
        }
        noc_org_file.close();
        new_noc_file.close();
        std::string noc_full_path("noc_memory_config_reloc.txt");
        setenv("NOCSIM_MULTI_DRAM_FILE",noc_full_path.c_str(),1);
    }
}
