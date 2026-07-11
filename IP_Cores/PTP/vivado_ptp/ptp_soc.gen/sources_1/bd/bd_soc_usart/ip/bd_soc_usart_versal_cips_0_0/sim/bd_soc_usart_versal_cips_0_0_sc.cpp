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


#include "bd_soc_usart_versal_cips_0_0_sc.h"

#include "versal_cips_v3_4_9_tlm.h"

#include <map>
#include <string>

bd_soc_usart_versal_cips_0_0_sc::bd_soc_usart_versal_cips_0_0_sc(const sc_core::sc_module_name& nm) : sc_core::sc_module(nm), mp_impl(NULL)
{
  // configure connectivity manager
  xsc::utils::xsc_sim_manager::addInstance("bd_soc_usart_versal_cips_0_0", this);

  // initialize module
    xsc::common_cpp::properties model_param_props;
    model_param_props.addString("COMPONENT_NAME", "bd_soc_usart_versal_cips_0_0");

  mp_impl = new versal_cips_v3_4_9_tlm("inst", model_param_props);

  // initialize AXI sockets
  M_AXI_LPD_tlm_aximm_read_socket = mp_impl->M_AXI_LPD_tlm_aximm_read_socket;
  M_AXI_LPD_tlm_aximm_write_socket = mp_impl->M_AXI_LPD_tlm_aximm_write_socket;
  FPD_CCI_NOC_0_tlm_aximm_read_socket = mp_impl->FPD_CCI_NOC_0_tlm_aximm_read_socket;
  FPD_CCI_NOC_0_tlm_aximm_write_socket = mp_impl->FPD_CCI_NOC_0_tlm_aximm_write_socket;
  FPD_CCI_NOC_1_tlm_aximm_read_socket = mp_impl->FPD_CCI_NOC_1_tlm_aximm_read_socket;
  FPD_CCI_NOC_1_tlm_aximm_write_socket = mp_impl->FPD_CCI_NOC_1_tlm_aximm_write_socket;
  FPD_CCI_NOC_2_tlm_aximm_read_socket = mp_impl->FPD_CCI_NOC_2_tlm_aximm_read_socket;
  FPD_CCI_NOC_2_tlm_aximm_write_socket = mp_impl->FPD_CCI_NOC_2_tlm_aximm_write_socket;
  FPD_CCI_NOC_3_tlm_aximm_read_socket = mp_impl->FPD_CCI_NOC_3_tlm_aximm_read_socket;
  FPD_CCI_NOC_3_tlm_aximm_write_socket = mp_impl->FPD_CCI_NOC_3_tlm_aximm_write_socket;
  LPD_AXI_NOC_0_tlm_aximm_read_socket = mp_impl->LPD_AXI_NOC_0_tlm_aximm_read_socket;
  LPD_AXI_NOC_0_tlm_aximm_write_socket = mp_impl->LPD_AXI_NOC_0_tlm_aximm_write_socket;
  PMC_NOC_AXI_0_tlm_aximm_read_socket = mp_impl->PMC_NOC_AXI_0_tlm_aximm_read_socket;
  PMC_NOC_AXI_0_tlm_aximm_write_socket = mp_impl->PMC_NOC_AXI_0_tlm_aximm_write_socket;
}

bd_soc_usart_versal_cips_0_0_sc::~bd_soc_usart_versal_cips_0_0_sc()
{
  xsc::utils::xsc_sim_manager::clean();

  delete mp_impl;
}

