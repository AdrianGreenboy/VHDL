
/////////////////////////////////////////////////////////////////
// (c) Copyright 1995-2018 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:ip:noc_nmu:1.0
// IP Revision: 0
//
(* X_CORE_INFO = "noc_nmu_v1_0_3_0,Vivado 2018.1.0" *)
(* CHECK_LICENSE_TYPE = "noc_nmu_0,noc_nmu_v1_0_3_0,{}" *)


(* DowngradeIPIdentifiedWarnings = "yes" *)


`timescale 1ps/1ps

module bd_b77b_S01_AXI_nmu_0 
  (
  IF_NOC_AXI_WVALID,
  IF_NOC_AXI_WREADY,
  IF_NOC_AXI_WLAST,
  IF_NOC_AXI_AWID,
  IF_NOC_AXI_WDATA,
  IF_NOC_AXI_WSTRB,
  IF_NOC_AXI_ARREADY,
  IF_NOC_AXI_AWREADY,
  IF_NOC_AXI_BID,
  IF_NOC_AXI_BRESP,
  IF_NOC_AXI_BVALID,
  IF_NOC_AXI_RDATA,
  IF_NOC_AXI_RID,
  IF_NOC_AXI_RLAST,
  IF_NOC_AXI_RRESP,
  IF_NOC_AXI_RUSER,
  IF_NOC_AXI_RVALID,
  IF_NOC_AXI_ARADDR,
  IF_NOC_AXI_ARBURST,
  IF_NOC_AXI_ARCACHE,
  IF_NOC_AXI_ARID,
  IF_NOC_AXI_ARLEN,
  IF_NOC_AXI_ARLOCK,
  IF_NOC_AXI_ARPROT,
  IF_NOC_AXI_ARQOS,
  IF_NOC_AXI_ARREGION,
  IF_NOC_AXI_ARSIZE,
  IF_NOC_AXI_ARUSER,
  IF_NOC_AXI_ARVALID,
  IF_NOC_AXI_AWADDR,
  IF_NOC_AXI_AWBURST,
  IF_NOC_AXI_AWCACHE,
  IF_NOC_AXI_AWLEN,
  IF_NOC_AXI_AWLOCK,
  IF_NOC_AXI_AWPROT,
  IF_NOC_AXI_AWQOS,
  IF_NOC_AXI_AWREGION,
  IF_NOC_AXI_AWSIZE,
  IF_NOC_AXI_AWUSER,
  IF_NOC_AXI_AWVALID,
  IF_NOC_AXI_BREADY,
  IF_NOC_AXI_RREADY,
  IF_NOC_AXI_WUSER,
  NMU_RD_DEST_MODE,
  NMU_WR_DEST_MODE,
  IF_NOC_NPP_IN_NOC_CREDIT_RETURN,
  IF_NOC_NPP_OUT_NOC_CREDIT_RDY,
  IF_NOC_NPP_OUT_NOC_FLIT,
  IF_NOC_NPP_OUT_NOC_VALID,
  aclk,
  IF_NOC_NPP_IN_NOC_CREDIT_RDY,
  IF_NOC_NPP_IN_NOC_FLIT,
  IF_NOC_NPP_IN_NOC_VALID,
  IF_NOC_NPP_OUT_NOC_CREDIT_RETURN,
  NMU  
  ,AXI_IN
  ,NMU_WR_USR_DST 
  ,NMU_RD_USR_DST
  
  
);

(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 WVALID" *)
input wire IF_NOC_AXI_WVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 WREADY" *)
output wire IF_NOC_AXI_WREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 WLAST" *)
input wire [0 : 0] IF_NOC_AXI_WLAST;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWID" *)
input wire [15 : 0] IF_NOC_AXI_AWID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 WDATA" *)
input wire [128 -1 :0] IF_NOC_AXI_WDATA;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 WSTRB" *)
input wire [16 -1:0] IF_NOC_AXI_WSTRB;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARREADY" *)
output wire IF_NOC_AXI_ARREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWREADY" *)
output wire IF_NOC_AXI_AWREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 BID" *)
output wire [15 : 0] IF_NOC_AXI_BID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 BRESP" *)
output wire [1 : 0] IF_NOC_AXI_BRESP;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 BVALID" *)
output wire IF_NOC_AXI_BVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 RDATA" *)
output wire [128 -1 :0] IF_NOC_AXI_RDATA;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 RID" *)
output wire [15 : 0] IF_NOC_AXI_RID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 RLAST" *)
output wire [0 : 0] IF_NOC_AXI_RLAST;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 RRESP" *)
output wire [1 : 0] IF_NOC_AXI_RRESP;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 RUSER" *)
output wire [16 : 0] IF_NOC_AXI_RUSER;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 RVALID" *)
output wire IF_NOC_AXI_RVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARADDR" *)
input wire [63 : 0] IF_NOC_AXI_ARADDR;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARBURST" *)
input wire [1 : 0] IF_NOC_AXI_ARBURST;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARCACHE" *)
input wire [3 : 0] IF_NOC_AXI_ARCACHE;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARID" *)
input wire [15 : 0] IF_NOC_AXI_ARID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARLEN" *)
input wire [7 : 0] IF_NOC_AXI_ARLEN;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARLOCK" *)
input wire [0 : 0] IF_NOC_AXI_ARLOCK;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARPROT" *)
input wire [2 : 0] IF_NOC_AXI_ARPROT;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARQOS" *)
input wire [3 : 0] IF_NOC_AXI_ARQOS;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARREGION" *)
input wire [3 : 0] IF_NOC_AXI_ARREGION;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARSIZE" *)
input wire [2 : 0] IF_NOC_AXI_ARSIZE;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARUSER" *)
input wire [17 : 0] IF_NOC_AXI_ARUSER;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 ARVALID" *)
input wire IF_NOC_AXI_ARVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWADDR" *)
input wire [63 : 0] IF_NOC_AXI_AWADDR;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWBURST" *)
input wire [1 : 0] IF_NOC_AXI_AWBURST;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWCACHE" *)
input wire [3 : 0] IF_NOC_AXI_AWCACHE;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWLEN" *)
input wire [7 : 0] IF_NOC_AXI_AWLEN;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWLOCK" *)
input wire [0 : 0] IF_NOC_AXI_AWLOCK;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWPROT" *)
input wire [2 : 0] IF_NOC_AXI_AWPROT;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWQOS" *)
input wire [3 : 0] IF_NOC_AXI_AWQOS;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWREGION" *)
input wire [3 : 0] IF_NOC_AXI_AWREGION;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWSIZE" *)
input wire [2 : 0] IF_NOC_AXI_AWSIZE;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWUSER" *)
input wire [17 : 0] IF_NOC_AXI_AWUSER;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 AWVALID" *)
input wire IF_NOC_AXI_AWVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 BREADY" *)
input wire IF_NOC_AXI_BREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 RREADY" *)
input wire IF_NOC_AXI_RREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SAXI4 WUSER" *)
input wire [16 : 0] IF_NOC_AXI_WUSER;
input wire NMU_RD_DEST_MODE;
input wire NMU_WR_DEST_MODE;
(* X_INTERFACE_INFO = "xilinx.com:interface:npp:1.0 SNPP CREDIT_RDY" *)
input wire IF_NOC_NPP_IN_NOC_CREDIT_RDY;
(* X_INTERFACE_INFO = "xilinx.com:interface:npp:1.0 SNPP FLIT" *)
input wire [181 : 0] IF_NOC_NPP_IN_NOC_FLIT;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME SNPP, IN_SYNTHESIS_HDL NO, CAN_DEBUG false" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:npp:1.0 SNPP VALID" *)
input wire [7 : 0] IF_NOC_NPP_IN_NOC_VALID;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME MNPP, IN_SYNTHESIS_HDL NO, CAN_DEBUG false" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:npp:1.0 MNPP CREDIT_RETURN" *)
input wire [7 : 0] IF_NOC_NPP_OUT_NOC_CREDIT_RETURN;
(* X_INTERFACE_INFO = "xilinx.com:interface:npp:1.0 SNPP CREDIT_RETURN" *)
output wire [7 : 0] IF_NOC_NPP_IN_NOC_CREDIT_RETURN;
(* X_INTERFACE_INFO = "xilinx.com:interface:npp:1.0 MNPP CREDIT_RDY" *)
output wire IF_NOC_NPP_OUT_NOC_CREDIT_RDY;
(* X_INTERFACE_INFO = "xilinx.com:interface:npp:1.0 MNPP FLIT" *)
output wire [181 : 0] IF_NOC_NPP_OUT_NOC_FLIT;
(* X_INTERFACE_INFO = "xilinx.com:interface:npp:1.0 MNPP VALID" *)
output wire [7 : 0] IF_NOC_NPP_OUT_NOC_VALID;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF SAXI4:SAXI_STREAM, FREQ_HZ 100000000, PHASE 0.000" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk aclk" *)
input wire aclk;

input wire [11:0]   NMU_WR_USR_DST;
input wire [11:0]   NMU_RD_USR_DST; 

(* DONT_TOUCH = "TRUE" *)  output NMU;
  input AXI_IN;
bd_b77b_S01_AXI_nmu_0_top #
    (
    .REG_ADDR_DST0 ('H00000),
    .REG_ADDR_DST1 ('H00000),
    .REG_ADDR_DST10 ('H00000),
    .REG_ADDR_DST11 ('H00000),
    .REG_ADDR_DST12 ('H00000),
    .REG_ADDR_DST13 ('H00000),
    .REG_ADDR_DST14 ('H00000),
    .REG_ADDR_DST15 ('H00000),
    .REG_ADDR_DST2 ('H00000),
    .REG_ADDR_DST3 ('H00000),
    .REG_ADDR_DST4 ('H00000),
    .REG_ADDR_DST5 ('H00000),
    .REG_ADDR_DST6 ('H00000),
    .REG_ADDR_DST7 ('H00000),
    .REG_ADDR_DST8 ('H00000),
    .REG_ADDR_DST9 ('H00000),
    .REG_ADDR_ENABLE ('H0000),
    .REG_ADDR_MADDR0 ('H00000000),
    .REG_ADDR_MADDR1 ('H00000000),
    .REG_ADDR_MADDR10 ('H00000000),
    .REG_ADDR_MADDR11 ('H00000000),
    .REG_ADDR_MADDR12 ('H00000000),
    .REG_ADDR_MADDR13 ('H00000000),
    .REG_ADDR_MADDR14 ('H00000000),
    .REG_ADDR_MADDR15 ('H00000000),
    .REG_ADDR_MADDR2 ('H00000000),
    .REG_ADDR_MADDR3 ('H00000000),
    .REG_ADDR_MADDR4 ('H00000000),
    .REG_ADDR_MADDR5 ('H00000000),
    .REG_ADDR_MADDR6 ('H00000000),
    .REG_ADDR_MADDR7 ('H00000000),
    .REG_ADDR_MADDR8 ('H00000000),
    .REG_ADDR_MADDR9 ('H00000000),
    .REG_ADDR_MASK0 ('H00000000),
    .REG_ADDR_MASK1 ('H00000000),
    .REG_ADDR_MASK10 ('H00000000),
    .REG_ADDR_MASK11 ('H00000000),
    .REG_ADDR_MASK12 ('H00000000),
    .REG_ADDR_MASK13 ('H00000000),
    .REG_ADDR_MASK14 ('H00000000),
    .REG_ADDR_MASK15 ('H00000000),
    .REG_ADDR_MASK2 ('H00000000),
    .REG_ADDR_MASK3 ('H00000000),
    .REG_ADDR_MASK4 ('H00000000),
    .REG_ADDR_MASK5 ('H00000000),
    .REG_ADDR_MASK6 ('H00000000),
    .REG_ADDR_MASK7 ('H00000000),
    .REG_ADDR_MASK8 ('H00000000),
    .REG_ADDR_MASK9 ('H00000000),
    .REG_ADDR_REMAP ('H0000),
    .REG_ADDR_RPADDR0 ('H00000000),
    .REG_ADDR_RPADDR1 ('H00000000),
    .REG_ADDR_RPADDR10 ('H00000000),
    .REG_ADDR_RPADDR11 ('H00000000),
    .REG_ADDR_RPADDR12 ('H00000000),
    .REG_ADDR_RPADDR13 ('H00000000),
    .REG_ADDR_RPADDR14 ('H00000000),
    .REG_ADDR_RPADDR15 ('H00000000),
    .REG_ADDR_RPADDR2 ('H00000000),
    .REG_ADDR_RPADDR3 ('H00000000),
    .REG_ADDR_RPADDR4 ('H00000000),
    .REG_ADDR_RPADDR5 ('H00000000),
    .REG_ADDR_RPADDR6 ('H00000000),
    .REG_ADDR_RPADDR7 ('H00000000),
    .REG_ADDR_RPADDR8 ('H00000000),
    .REG_ADDR_RPADDR9 ('H00000000),
    .REG_ADR_MAP_CPM ('H0FC0),
    .REG_ADR_MAP_FPD_AFI_0 ('H0FC0),
    .REG_ADR_MAP_FPD_AFI_1 ('H0FC0),
    .REG_ADR_MAP_LPD_AFI_FS ('H0FC0),
    .REG_ADR_MAP_ME_ARRAY_0 ('H0FC0),
    .REG_ADR_MAP_ME_ARRAY_1 ('H0FC0),
    .REG_ADR_MAP_ME_ARRAY_2 ('H0FC0),
    .REG_ADR_MAP_ME_ARRAY_3 ('H0FC0),
    .REG_ADR_MAP_PCIE ('H0FC0),
    .REG_ADR_MAP_PMC ('H0FC0),
    .REG_ADR_MAP_PMC_ALIAS_0 ('H0FC0),
    .REG_ADR_MAP_PMC_ALIAS_1 ('H0FC0),
    .REG_ADR_MAP_PMC_ALIAS_2 ('H0FC0),
    .REG_ADR_MAP_PMC_ALIAS_3 ('H0FC0),
    .REG_ADR_MAP_QSPI ('H0FC0),
    .REG_ADR_MAP_STM_GIC ('H0FC0),
    .REG_ADR_MAP_XPDS ('H0FC0),
    .REG_AXI_NON_MOD_DISABLE ('H0),
    .REG_AXI_PAR_CHK ('H0),
    .REG_CHOPSIZE ('HA),
    .REG_DDR_ADR_MAP0 ('H06000),
    .REG_DDR_ADR_MAP1 ('H01FFF),
    .REG_DDR_ADR_MAP2 ('H01FFF),
    .REG_DDR_ADR_MAP3 ('H01FFF),
    .REG_DDR_ADR_MAP4 ('H01FFF),
    .REG_DDR_ADR_MAP5 ('H01FFF),
    .REG_DDR_ADR_MAP6 ('H01FFF),
    .REG_DDR_DST_MAP0 ('H240),
    .REG_DDR_DST_MAP1 ('HFC0),
    .REG_DDR_DST_MAP2 ('HFC0),
    .REG_DDR_DST_MAP3 ('HFC0),
    .REG_DDR_DST_MAP4 ('HFC0),
    .REG_DDR_DST_MAP5 ('HFC0),
    .REG_DDR_DST_MAP6 ('HFC0),
    .REG_DDR_DST_MAP7 ('HFC0),
    .REG_DWIDTH ('H4),
    .REG_ECC_CHK_EN ('H1),
    .REG_HBM_MAP_T0_CH0 ('H0FC0),
    .REG_HBM_MAP_T0_CH1 ('H0FC0),
    .REG_HBM_MAP_T0_CH10 ('H0FC0),
    .REG_HBM_MAP_T0_CH11 ('H0FC0),
    .REG_HBM_MAP_T0_CH12 ('H0FC0),
    .REG_HBM_MAP_T0_CH13 ('H0FC0),
    .REG_HBM_MAP_T0_CH14 ('H0FC0),
    .REG_HBM_MAP_T0_CH15 ('H0FC0),
    .REG_HBM_MAP_T0_CH2 ('H0FC0),
    .REG_HBM_MAP_T0_CH3 ('H0FC0),
    .REG_HBM_MAP_T0_CH4 ('H0FC0),
    .REG_HBM_MAP_T0_CH5 ('H0FC0),
    .REG_HBM_MAP_T0_CH6 ('H0FC0),
    .REG_HBM_MAP_T0_CH7 ('H0FC0),
    .REG_HBM_MAP_T0_CH8 ('H0FC0),
    .REG_HBM_MAP_T0_CH9 ('H0FC0),
    .REG_HBM_MAP_T1_CH0 ('H0FC0),
    .REG_HBM_MAP_T1_CH1 ('H0FC0),
    .REG_HBM_MAP_T1_CH10 ('H0FC0),
    .REG_HBM_MAP_T1_CH11 ('H0FC0),
    .REG_HBM_MAP_T1_CH12 ('H0FC0),
    .REG_HBM_MAP_T1_CH13 ('H0FC0),
    .REG_HBM_MAP_T1_CH14 ('H0FC0),
    .REG_HBM_MAP_T1_CH15 ('H0FC0),
    .REG_HBM_MAP_T1_CH2 ('H0FC0),
    .REG_HBM_MAP_T1_CH3 ('H0FC0),
    .REG_HBM_MAP_T1_CH4 ('H0FC0),
    .REG_HBM_MAP_T1_CH5 ('H0FC0),
    .REG_HBM_MAP_T1_CH6 ('H0FC0),
    .REG_HBM_MAP_T1_CH7 ('H0FC0),
    .REG_HBM_MAP_T1_CH8 ('H0FC0),
    .REG_HBM_MAP_T1_CH9 ('H0FC0),
    .REG_HBM_MAP_T2_CH0 ('H0FC0),
    .REG_HBM_MAP_T2_CH1 ('H0FC0),
    .REG_HBM_MAP_T2_CH10 ('H0FC0),
    .REG_HBM_MAP_T2_CH11 ('H0FC0),
    .REG_HBM_MAP_T2_CH12 ('H0FC0),
    .REG_HBM_MAP_T2_CH13 ('H0FC0),
    .REG_HBM_MAP_T2_CH14 ('H0FC0),
    .REG_HBM_MAP_T2_CH15 ('H0FC0),
    .REG_HBM_MAP_T2_CH2 ('H0FC0),
    .REG_HBM_MAP_T2_CH3 ('H0FC0),
    .REG_HBM_MAP_T2_CH4 ('H0FC0),
    .REG_HBM_MAP_T2_CH5 ('H0FC0),
    .REG_HBM_MAP_T2_CH6 ('H0FC0),
    .REG_HBM_MAP_T2_CH7 ('H0FC0),
    .REG_HBM_MAP_T2_CH8 ('H0FC0),
    .REG_HBM_MAP_T2_CH9 ('H0FC0),
    .REG_HBM_MAP_T3_CH0 ('H0FC0),
    .REG_HBM_MAP_T3_CH1 ('H0FC0),
    .REG_HBM_MAP_T3_CH10 ('H0FC0),
    .REG_HBM_MAP_T3_CH11 ('H0FC0),
    .REG_HBM_MAP_T3_CH12 ('H0FC0),
    .REG_HBM_MAP_T3_CH13 ('H0FC0),
    .REG_HBM_MAP_T3_CH14 ('H0FC0),
    .REG_HBM_MAP_T3_CH15 ('H0FC0),
    .REG_HBM_MAP_T3_CH2 ('H0FC0),
    .REG_HBM_MAP_T3_CH3 ('H0FC0),
    .REG_HBM_MAP_T3_CH4 ('H0FC0),
    .REG_HBM_MAP_T3_CH5 ('H0FC0),
    .REG_HBM_MAP_T3_CH6 ('H0FC0),
    .REG_HBM_MAP_T3_CH7 ('H0FC0),
    .REG_HBM_MAP_T3_CH8 ('H0FC0),
    .REG_HBM_MAP_T3_CH9 ('H0FC0),
    .REG_MODE_SELECT ('H0000),
    .REG_OUTSTANDING_RD_TXN ('H40),
    .REG_OUTSTANDING_WR_TXN ('H40),
    .REG_PRIORITY ('H0),
    .REG_RD_AXPROT_SEL ('H00),
    .REG_RD_RATE_CREDIT_DROP ('H004),
    .REG_RD_RATE_CREDIT_LIMIT ('H0100),
    .REG_RD_VCA_TOKEN0 ('H33),
    .REG_RPOISON_TO_SLVERR ('H0),
    .REG_RROB_RAM_SETTING ('H012),
    .REG_SMID_SEL ('H00000),
    .REG_SRC ('H100),
    .REG_TBASE_AXI_TIMEOUT ('H1),
    .REG_TBASE_MODE_RLIMIT_RD ('H2),
    .REG_TBASE_MODE_RLIMIT_WR ('H2),
    .REG_TBASE_TRK_TIMEOUT ('H1),
    .REG_VC_MAP ('HFAC),
    .REG_WBUF_LAUNCH_SIZE ('H10),
    .REG_WBUF_RAM_SETTING ('H012),
    .REG_WR_AXPROT_SEL ('H00),
    .REG_WR_RATE_CREDIT_DROP ('H004),
    .REG_WR_RATE_CREDIT_LIMIT ('H0100)
) bd_b77b_S01_AXI_nmu_0_top_INST (
    .IF_NOC_AXI_WVALID(IF_NOC_AXI_WVALID),
    .IF_NOC_AXI_WREADY(IF_NOC_AXI_WREADY),
    .IF_NOC_AXI_WLAST(IF_NOC_AXI_WLAST),
    .IF_NOC_AXI_AWID(IF_NOC_AXI_AWID),
    .IF_NOC_AXI_WDATA(IF_NOC_AXI_WDATA),
    .IF_NOC_AXI_WSTRB(IF_NOC_AXI_WSTRB),
    .IF_NOC_AXI_ARREADY(IF_NOC_AXI_ARREADY),
    .IF_NOC_AXI_AWREADY(IF_NOC_AXI_AWREADY),
    .IF_NOC_AXI_BID(IF_NOC_AXI_BID),
    .IF_NOC_AXI_BRESP(IF_NOC_AXI_BRESP),
    .IF_NOC_AXI_BVALID(IF_NOC_AXI_BVALID),
    .IF_NOC_AXI_RDATA(IF_NOC_AXI_RDATA),
    .IF_NOC_AXI_RID(IF_NOC_AXI_RID),
    .IF_NOC_AXI_RLAST(IF_NOC_AXI_RLAST),
    .IF_NOC_AXI_RRESP(IF_NOC_AXI_RRESP),
    .IF_NOC_AXI_RUSER(IF_NOC_AXI_RUSER),
    .IF_NOC_AXI_RVALID(IF_NOC_AXI_RVALID),
    .IF_NOC_AXI_ARADDR(IF_NOC_AXI_ARADDR),
    .IF_NOC_AXI_ARBURST(IF_NOC_AXI_ARBURST),
    .IF_NOC_AXI_ARCACHE(IF_NOC_AXI_ARCACHE),
    .IF_NOC_AXI_ARID(IF_NOC_AXI_ARID),
    .IF_NOC_AXI_ARLEN(IF_NOC_AXI_ARLEN),
    .IF_NOC_AXI_ARLOCK(IF_NOC_AXI_ARLOCK),
    .IF_NOC_AXI_ARPROT(IF_NOC_AXI_ARPROT),
    .IF_NOC_AXI_ARQOS(IF_NOC_AXI_ARQOS),
    .IF_NOC_AXI_ARREGION(IF_NOC_AXI_ARREGION),
    .IF_NOC_AXI_ARSIZE(IF_NOC_AXI_ARSIZE),
    .IF_NOC_AXI_ARUSER(IF_NOC_AXI_ARUSER),
    .IF_NOC_AXI_ARVALID(IF_NOC_AXI_ARVALID),
    .IF_NOC_AXI_AWADDR(IF_NOC_AXI_AWADDR),
    .IF_NOC_AXI_AWBURST(IF_NOC_AXI_AWBURST),
    .IF_NOC_AXI_AWCACHE(IF_NOC_AXI_AWCACHE),
    .IF_NOC_AXI_AWLEN(IF_NOC_AXI_AWLEN),
    .IF_NOC_AXI_AWLOCK(IF_NOC_AXI_AWLOCK),
    .IF_NOC_AXI_AWPROT(IF_NOC_AXI_AWPROT),
    .IF_NOC_AXI_AWQOS(IF_NOC_AXI_AWQOS),
    .IF_NOC_AXI_AWREGION(IF_NOC_AXI_AWREGION),
    .IF_NOC_AXI_AWSIZE(IF_NOC_AXI_AWSIZE),
    .IF_NOC_AXI_AWUSER(IF_NOC_AXI_AWUSER),
    .IF_NOC_AXI_AWVALID(IF_NOC_AXI_AWVALID),
    .IF_NOC_AXI_BREADY(IF_NOC_AXI_BREADY),
    .IF_NOC_AXI_RREADY(IF_NOC_AXI_RREADY),
    .IF_NOC_AXI_WUSER(IF_NOC_AXI_WUSER),
    .NMU_RD_DEST_MODE (NMU_RD_DEST_MODE),
    .NMU_WR_DEST_MODE (NMU_WR_DEST_MODE),
    .IF_NOC_NPP_IN_NOC_CREDIT_RETURN(IF_NOC_NPP_IN_NOC_CREDIT_RETURN),
    .IF_NOC_NPP_OUT_NOC_CREDIT_RDY(IF_NOC_NPP_OUT_NOC_CREDIT_RDY),
    .IF_NOC_NPP_OUT_NOC_FLIT(IF_NOC_NPP_OUT_NOC_FLIT),
    .IF_NOC_NPP_OUT_NOC_VALID(IF_NOC_NPP_OUT_NOC_VALID),
    .aclk(aclk),
    .IF_NOC_NPP_IN_NOC_CREDIT_RDY(IF_NOC_NPP_IN_NOC_CREDIT_RDY),
    .IF_NOC_NPP_IN_NOC_FLIT(IF_NOC_NPP_IN_NOC_FLIT),
    .IF_NOC_NPP_IN_NOC_VALID(IF_NOC_NPP_IN_NOC_VALID),
    .IF_NOC_NPP_OUT_NOC_CREDIT_RETURN(IF_NOC_NPP_OUT_NOC_CREDIT_RETURN),
    .NMU(NMU)
    ,.AXI_IN(AXI_IN)
    ,.NMU_WR_USR_DST (NMU_WR_USR_DST)
    ,.NMU_RD_USR_DST (NMU_RD_USR_DST)

    );

endmodule
