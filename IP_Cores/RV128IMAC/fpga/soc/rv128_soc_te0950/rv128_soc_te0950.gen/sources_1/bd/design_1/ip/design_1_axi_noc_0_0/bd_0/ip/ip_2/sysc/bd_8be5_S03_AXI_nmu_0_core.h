//**********************************************************************
// Copyright (c) 2016-2018 Xilinx Inc.  All Rights Reserved
//**********************************************************************
//
//   TLM wrapper for NoC nmu.
//   Provides a sc_module anchor to receive IP params. Represents the axi
//   side (xtlm sockets, clock and reset). The NPP side is modeled within
//   the snoc IP
//
//**********************************************************************
#ifndef _bd_8be5_S03_AXI_nmu_0_core_h_
#define _bd_8be5_S03_AXI_nmu_0_core_h_

#include "NOCMasterUnitXtlm.h"
#include "properties.h"

class bd_8be5_S03_AXI_nmu_0_core : public NOCMasterUnitXtlm
{
public:

  // axi clock and reset are defined in base class
  // following xtlm socket pointers refer to instances in base class
  xtlm::xtlm_aximm_target_socket* SAXI4_rd_socket;
  xtlm::xtlm_aximm_target_socket* SAXI4_wr_socket;
  xtlm::xtlm_axis_target_socket*  SAXI_STREAM_socket;

bd_8be5_S03_AXI_nmu_0_core( sc_core::sc_module_name nm, const xsc::common_cpp::properties& props )
  : NOCMasterUnitXtlm(nm, props)
  , SAXI4_rd_socket( &arr_socket )
  , SAXI4_wr_socket( &awb_socket )
  , SAXI_STREAM_socket ( &at_socket )
  , NMU_WR_USR_DST     ( "NMU_WR_USR_DST" )
  , NMU_RD_USR_DST     ( "NMU_RD_USR_DST" )
  
  , NMU_WR_DEST_MODE   ( "NMU_WR_DEST_MODE" )
  , NMU_RD_DEST_MODE   ( "NMU_RD_DEST_MODE" )
  , NMU                ( "NMU" )
  , AXI_IN             ( "AXI_IN" )
  
  {

  }

  virtual ~bd_8be5_S03_AXI_nmu_0_core() = default;
  
public: // stub pin-to-pin RTL interface

  sc_in< sc_bv<8> >    IF_NOC_NPP_OUT_NOC_CREDIT_RETURN;
  sc_in< bool >        IF_NOC_NPP_IN_NOC_CREDIT_RDY;
  sc_in< sc_bv<182> >  IF_NOC_NPP_IN_NOC_FLIT;
  sc_in< sc_bv<8> >    IF_NOC_NPP_IN_NOC_VALID;

  sc_out< sc_bv<8> >   IF_NOC_NPP_IN_NOC_CREDIT_RETURN;
  sc_out< bool >       IF_NOC_NPP_OUT_NOC_CREDIT_RDY;
  sc_out< sc_bv<182> > IF_NOC_NPP_OUT_NOC_FLIT;
  sc_out< sc_bv<8> >   IF_NOC_NPP_OUT_NOC_VALID;

  sc_in< sc_bv<12> > NMU_WR_USR_DST;
  sc_in< sc_bv<12> > NMU_RD_USR_DST;

  sc_in< bool >      NMU_WR_DEST_MODE;
  sc_in< bool >      NMU_RD_DEST_MODE;

  sc_out< bool>      NMU;
  sc_in< bool>       AXI_IN;

};

#endif
