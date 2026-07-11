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


#include "bd_soc_usart_axi_noc_0_0_sc.h"

#include "bd_soc_usart_axi_noc_0_0.h"

#include "bd_b77b.h"

#include <map>
#include <string>





#ifdef XILINX_SIMULATOR
bd_soc_usart_axi_noc_0_0::bd_soc_usart_axi_noc_0_0(const sc_core::sc_module_name& nm) : bd_soc_usart_axi_noc_0_0_sc(nm), S00_AXI_awaddr("S00_AXI_awaddr"), S00_AXI_awlen("S00_AXI_awlen"), S00_AXI_awsize("S00_AXI_awsize"), S00_AXI_awburst("S00_AXI_awburst"), S00_AXI_awlock("S00_AXI_awlock"), S00_AXI_awcache("S00_AXI_awcache"), S00_AXI_awprot("S00_AXI_awprot"), S00_AXI_awregion("S00_AXI_awregion"), S00_AXI_awqos("S00_AXI_awqos"), S00_AXI_awvalid("S00_AXI_awvalid"), S00_AXI_awready("S00_AXI_awready"), S00_AXI_wdata("S00_AXI_wdata"), S00_AXI_wstrb("S00_AXI_wstrb"), S00_AXI_wlast("S00_AXI_wlast"), S00_AXI_wvalid("S00_AXI_wvalid"), S00_AXI_wready("S00_AXI_wready"), S00_AXI_bresp("S00_AXI_bresp"), S00_AXI_bvalid("S00_AXI_bvalid"), S00_AXI_bready("S00_AXI_bready"), S00_AXI_araddr("S00_AXI_araddr"), S00_AXI_arlen("S00_AXI_arlen"), S00_AXI_arsize("S00_AXI_arsize"), S00_AXI_arburst("S00_AXI_arburst"), S00_AXI_arlock("S00_AXI_arlock"), S00_AXI_arcache("S00_AXI_arcache"), S00_AXI_arprot("S00_AXI_arprot"), S00_AXI_arregion("S00_AXI_arregion"), S00_AXI_arqos("S00_AXI_arqos"), S00_AXI_arvalid("S00_AXI_arvalid"), S00_AXI_arready("S00_AXI_arready"), S00_AXI_rdata("S00_AXI_rdata"), S00_AXI_rresp("S00_AXI_rresp"), S00_AXI_rlast("S00_AXI_rlast"), S00_AXI_rvalid("S00_AXI_rvalid"), S00_AXI_rready("S00_AXI_rready"), S01_AXI_awaddr("S01_AXI_awaddr"), S01_AXI_awlen("S01_AXI_awlen"), S01_AXI_awsize("S01_AXI_awsize"), S01_AXI_awburst("S01_AXI_awburst"), S01_AXI_awlock("S01_AXI_awlock"), S01_AXI_awcache("S01_AXI_awcache"), S01_AXI_awprot("S01_AXI_awprot"), S01_AXI_awregion("S01_AXI_awregion"), S01_AXI_awqos("S01_AXI_awqos"), S01_AXI_awvalid("S01_AXI_awvalid"), S01_AXI_awready("S01_AXI_awready"), S01_AXI_wdata("S01_AXI_wdata"), S01_AXI_wstrb("S01_AXI_wstrb"), S01_AXI_wlast("S01_AXI_wlast"), S01_AXI_wvalid("S01_AXI_wvalid"), S01_AXI_wready("S01_AXI_wready"), S01_AXI_bresp("S01_AXI_bresp"), S01_AXI_bvalid("S01_AXI_bvalid"), S01_AXI_bready("S01_AXI_bready"), S01_AXI_araddr("S01_AXI_araddr"), S01_AXI_arlen("S01_AXI_arlen"), S01_AXI_arsize("S01_AXI_arsize"), S01_AXI_arburst("S01_AXI_arburst"), S01_AXI_arlock("S01_AXI_arlock"), S01_AXI_arcache("S01_AXI_arcache"), S01_AXI_arprot("S01_AXI_arprot"), S01_AXI_arregion("S01_AXI_arregion"), S01_AXI_arqos("S01_AXI_arqos"), S01_AXI_arvalid("S01_AXI_arvalid"), S01_AXI_arready("S01_AXI_arready"), S01_AXI_rdata("S01_AXI_rdata"), S01_AXI_rresp("S01_AXI_rresp"), S01_AXI_rlast("S01_AXI_rlast"), S01_AXI_rvalid("S01_AXI_rvalid"), S01_AXI_rready("S01_AXI_rready"), S02_AXI_awaddr("S02_AXI_awaddr"), S02_AXI_awlen("S02_AXI_awlen"), S02_AXI_awsize("S02_AXI_awsize"), S02_AXI_awburst("S02_AXI_awburst"), S02_AXI_awlock("S02_AXI_awlock"), S02_AXI_awcache("S02_AXI_awcache"), S02_AXI_awprot("S02_AXI_awprot"), S02_AXI_awregion("S02_AXI_awregion"), S02_AXI_awqos("S02_AXI_awqos"), S02_AXI_awvalid("S02_AXI_awvalid"), S02_AXI_awready("S02_AXI_awready"), S02_AXI_wdata("S02_AXI_wdata"), S02_AXI_wstrb("S02_AXI_wstrb"), S02_AXI_wlast("S02_AXI_wlast"), S02_AXI_wvalid("S02_AXI_wvalid"), S02_AXI_wready("S02_AXI_wready"), S02_AXI_bresp("S02_AXI_bresp"), S02_AXI_bvalid("S02_AXI_bvalid"), S02_AXI_bready("S02_AXI_bready"), S02_AXI_araddr("S02_AXI_araddr"), S02_AXI_arlen("S02_AXI_arlen"), S02_AXI_arsize("S02_AXI_arsize"), S02_AXI_arburst("S02_AXI_arburst"), S02_AXI_arlock("S02_AXI_arlock"), S02_AXI_arcache("S02_AXI_arcache"), S02_AXI_arprot("S02_AXI_arprot"), S02_AXI_arregion("S02_AXI_arregion"), S02_AXI_arqos("S02_AXI_arqos"), S02_AXI_arvalid("S02_AXI_arvalid"), S02_AXI_arready("S02_AXI_arready"), S02_AXI_rdata("S02_AXI_rdata"), S02_AXI_rresp("S02_AXI_rresp"), S02_AXI_rlast("S02_AXI_rlast"), S02_AXI_rvalid("S02_AXI_rvalid"), S02_AXI_rready("S02_AXI_rready"), S03_AXI_awaddr("S03_AXI_awaddr"), S03_AXI_awlen("S03_AXI_awlen"), S03_AXI_awsize("S03_AXI_awsize"), S03_AXI_awburst("S03_AXI_awburst"), S03_AXI_awlock("S03_AXI_awlock"), S03_AXI_awcache("S03_AXI_awcache"), S03_AXI_awprot("S03_AXI_awprot"), S03_AXI_awregion("S03_AXI_awregion"), S03_AXI_awqos("S03_AXI_awqos"), S03_AXI_awvalid("S03_AXI_awvalid"), S03_AXI_awready("S03_AXI_awready"), S03_AXI_wdata("S03_AXI_wdata"), S03_AXI_wstrb("S03_AXI_wstrb"), S03_AXI_wlast("S03_AXI_wlast"), S03_AXI_wvalid("S03_AXI_wvalid"), S03_AXI_wready("S03_AXI_wready"), S03_AXI_bresp("S03_AXI_bresp"), S03_AXI_bvalid("S03_AXI_bvalid"), S03_AXI_bready("S03_AXI_bready"), S03_AXI_araddr("S03_AXI_araddr"), S03_AXI_arlen("S03_AXI_arlen"), S03_AXI_arsize("S03_AXI_arsize"), S03_AXI_arburst("S03_AXI_arburst"), S03_AXI_arlock("S03_AXI_arlock"), S03_AXI_arcache("S03_AXI_arcache"), S03_AXI_arprot("S03_AXI_arprot"), S03_AXI_arregion("S03_AXI_arregion"), S03_AXI_arqos("S03_AXI_arqos"), S03_AXI_arvalid("S03_AXI_arvalid"), S03_AXI_arready("S03_AXI_arready"), S03_AXI_rdata("S03_AXI_rdata"), S03_AXI_rresp("S03_AXI_rresp"), S03_AXI_rlast("S03_AXI_rlast"), S03_AXI_rvalid("S03_AXI_rvalid"), S03_AXI_rready("S03_AXI_rready"), S04_AXI_awaddr("S04_AXI_awaddr"), S04_AXI_awlen("S04_AXI_awlen"), S04_AXI_awsize("S04_AXI_awsize"), S04_AXI_awburst("S04_AXI_awburst"), S04_AXI_awlock("S04_AXI_awlock"), S04_AXI_awcache("S04_AXI_awcache"), S04_AXI_awprot("S04_AXI_awprot"), S04_AXI_awregion("S04_AXI_awregion"), S04_AXI_awqos("S04_AXI_awqos"), S04_AXI_awvalid("S04_AXI_awvalid"), S04_AXI_awready("S04_AXI_awready"), S04_AXI_wdata("S04_AXI_wdata"), S04_AXI_wstrb("S04_AXI_wstrb"), S04_AXI_wlast("S04_AXI_wlast"), S04_AXI_wvalid("S04_AXI_wvalid"), S04_AXI_wready("S04_AXI_wready"), S04_AXI_bresp("S04_AXI_bresp"), S04_AXI_bvalid("S04_AXI_bvalid"), S04_AXI_bready("S04_AXI_bready"), S04_AXI_araddr("S04_AXI_araddr"), S04_AXI_arlen("S04_AXI_arlen"), S04_AXI_arsize("S04_AXI_arsize"), S04_AXI_arburst("S04_AXI_arburst"), S04_AXI_arlock("S04_AXI_arlock"), S04_AXI_arcache("S04_AXI_arcache"), S04_AXI_arprot("S04_AXI_arprot"), S04_AXI_arregion("S04_AXI_arregion"), S04_AXI_arqos("S04_AXI_arqos"), S04_AXI_arvalid("S04_AXI_arvalid"), S04_AXI_arready("S04_AXI_arready"), S04_AXI_rdata("S04_AXI_rdata"), S04_AXI_rresp("S04_AXI_rresp"), S04_AXI_rlast("S04_AXI_rlast"), S04_AXI_rvalid("S04_AXI_rvalid"), S04_AXI_rready("S04_AXI_rready"), S05_AXI_awaddr("S05_AXI_awaddr"), S05_AXI_awlen("S05_AXI_awlen"), S05_AXI_awsize("S05_AXI_awsize"), S05_AXI_awburst("S05_AXI_awburst"), S05_AXI_awlock("S05_AXI_awlock"), S05_AXI_awcache("S05_AXI_awcache"), S05_AXI_awprot("S05_AXI_awprot"), S05_AXI_awregion("S05_AXI_awregion"), S05_AXI_awqos("S05_AXI_awqos"), S05_AXI_awvalid("S05_AXI_awvalid"), S05_AXI_awready("S05_AXI_awready"), S05_AXI_wdata("S05_AXI_wdata"), S05_AXI_wstrb("S05_AXI_wstrb"), S05_AXI_wlast("S05_AXI_wlast"), S05_AXI_wvalid("S05_AXI_wvalid"), S05_AXI_wready("S05_AXI_wready"), S05_AXI_bresp("S05_AXI_bresp"), S05_AXI_bvalid("S05_AXI_bvalid"), S05_AXI_bready("S05_AXI_bready"), S05_AXI_araddr("S05_AXI_araddr"), S05_AXI_arlen("S05_AXI_arlen"), S05_AXI_arsize("S05_AXI_arsize"), S05_AXI_arburst("S05_AXI_arburst"), S05_AXI_arlock("S05_AXI_arlock"), S05_AXI_arcache("S05_AXI_arcache"), S05_AXI_arprot("S05_AXI_arprot"), S05_AXI_arregion("S05_AXI_arregion"), S05_AXI_arqos("S05_AXI_arqos"), S05_AXI_arvalid("S05_AXI_arvalid"), S05_AXI_arready("S05_AXI_arready"), S05_AXI_rdata("S05_AXI_rdata"), S05_AXI_rresp("S05_AXI_rresp"), S05_AXI_rlast("S05_AXI_rlast"), S05_AXI_rvalid("S05_AXI_rvalid"), S05_AXI_rready("S05_AXI_rready"), S06_AXI_awaddr("S06_AXI_awaddr"), S06_AXI_awlen("S06_AXI_awlen"), S06_AXI_awsize("S06_AXI_awsize"), S06_AXI_awburst("S06_AXI_awburst"), S06_AXI_awlock("S06_AXI_awlock"), S06_AXI_awcache("S06_AXI_awcache"), S06_AXI_awprot("S06_AXI_awprot"), S06_AXI_awregion("S06_AXI_awregion"), S06_AXI_awqos("S06_AXI_awqos"), S06_AXI_awvalid("S06_AXI_awvalid"), S06_AXI_awready("S06_AXI_awready"), S06_AXI_wdata("S06_AXI_wdata"), S06_AXI_wstrb("S06_AXI_wstrb"), S06_AXI_wlast("S06_AXI_wlast"), S06_AXI_wvalid("S06_AXI_wvalid"), S06_AXI_wready("S06_AXI_wready"), S06_AXI_bresp("S06_AXI_bresp"), S06_AXI_bvalid("S06_AXI_bvalid"), S06_AXI_bready("S06_AXI_bready"), S06_AXI_araddr("S06_AXI_araddr"), S06_AXI_arlen("S06_AXI_arlen"), S06_AXI_arsize("S06_AXI_arsize"), S06_AXI_arburst("S06_AXI_arburst"), S06_AXI_arlock("S06_AXI_arlock"), S06_AXI_arcache("S06_AXI_arcache"), S06_AXI_arprot("S06_AXI_arprot"), S06_AXI_arregion("S06_AXI_arregion"), S06_AXI_arqos("S06_AXI_arqos"), S06_AXI_arvalid("S06_AXI_arvalid"), S06_AXI_arready("S06_AXI_arready"), S06_AXI_rdata("S06_AXI_rdata"), S06_AXI_rresp("S06_AXI_rresp"), S06_AXI_rlast("S06_AXI_rlast"), S06_AXI_rvalid("S06_AXI_rvalid"), S06_AXI_rready("S06_AXI_rready"), aclk0("aclk0"), aclk1("aclk1"), aclk2("aclk2"), aclk3("aclk3"), aclk4("aclk4"), aclk5("aclk5"), aclk6("aclk6"), sys_clk0_clk_p("sys_clk0_clk_p"), sys_clk0_clk_n("sys_clk0_clk_n"), CH0_DDR4_0_dq("CH0_DDR4_0_dq"), CH0_DDR4_0_dqs_t("CH0_DDR4_0_dqs_t"), CH0_DDR4_0_dqs_c("CH0_DDR4_0_dqs_c"), CH0_DDR4_0_adr("CH0_DDR4_0_adr"), CH0_DDR4_0_ba("CH0_DDR4_0_ba"), CH0_DDR4_0_bg("CH0_DDR4_0_bg"), CH0_DDR4_0_act_n("CH0_DDR4_0_act_n"), CH0_DDR4_0_reset_n("CH0_DDR4_0_reset_n"), CH0_DDR4_0_ck_t("CH0_DDR4_0_ck_t"), CH0_DDR4_0_ck_c("CH0_DDR4_0_ck_c"), CH0_DDR4_0_cke("CH0_DDR4_0_cke"), CH0_DDR4_0_cs_n("CH0_DDR4_0_cs_n"), CH0_DDR4_0_dm_n("CH0_DDR4_0_dm_n"), CH0_DDR4_0_odt("CH0_DDR4_0_odt"), S05_AXI_arid("S05_AXI_arid"), S05_AXI_aruser("S05_AXI_aruser"), S05_AXI_awid("S05_AXI_awid"), S05_AXI_awuser("S05_AXI_awuser"), S05_AXI_bid("S05_AXI_bid"), S05_AXI_buser("S05_AXI_buser"), S05_AXI_rid("S05_AXI_rid"), S05_AXI_ruser("S05_AXI_ruser"), S05_AXI_wuser("S05_AXI_wuser"), S03_AXI_arid("S03_AXI_arid"), S03_AXI_aruser("S03_AXI_aruser"), S03_AXI_awid("S03_AXI_awid"), S03_AXI_awuser("S03_AXI_awuser"), S03_AXI_bid("S03_AXI_bid"), S03_AXI_rid("S03_AXI_rid"), S03_AXI_ruser("S03_AXI_ruser"), S03_AXI_wuser("S03_AXI_wuser"), S04_AXI_arid("S04_AXI_arid"), S04_AXI_aruser("S04_AXI_aruser"), S04_AXI_awid("S04_AXI_awid"), S04_AXI_awuser("S04_AXI_awuser"), S04_AXI_bid("S04_AXI_bid"), S04_AXI_rid("S04_AXI_rid"), S04_AXI_ruser("S04_AXI_ruser"), S04_AXI_wuser("S04_AXI_wuser"), S02_AXI_arid("S02_AXI_arid"), S02_AXI_aruser("S02_AXI_aruser"), S02_AXI_awid("S02_AXI_awid"), S02_AXI_awuser("S02_AXI_awuser"), S02_AXI_bid("S02_AXI_bid"), S02_AXI_rid("S02_AXI_rid"), S02_AXI_ruser("S02_AXI_ruser"), S02_AXI_wuser("S02_AXI_wuser"), S06_AXI_arid("S06_AXI_arid"), S06_AXI_awid("S06_AXI_awid"), S06_AXI_bid("S06_AXI_bid"), S06_AXI_rid("S06_AXI_rid"), S01_AXI_arid("S01_AXI_arid"), S01_AXI_aruser("S01_AXI_aruser"), S01_AXI_awid("S01_AXI_awid"), S01_AXI_awuser("S01_AXI_awuser"), S01_AXI_bid("S01_AXI_bid"), S01_AXI_rid("S01_AXI_rid"), S01_AXI_ruser("S01_AXI_ruser"), S01_AXI_wuser("S01_AXI_wuser"), S00_AXI_arid("S00_AXI_arid"), S00_AXI_aruser("S00_AXI_aruser"), S00_AXI_awid("S00_AXI_awid"), S00_AXI_awuser("S00_AXI_awuser"), S00_AXI_bid("S00_AXI_bid"), S00_AXI_rid("S00_AXI_rid"), S00_AXI_ruser("S00_AXI_ruser"), S00_AXI_wuser("S00_AXI_wuser")
{

  // initialize pins
  mp_impl->aclk0(aclk0);
  mp_impl->aclk1(aclk1);
  mp_impl->aclk2(aclk2);
  mp_impl->aclk3(aclk3);
  mp_impl->aclk4(aclk4);
  mp_impl->aclk5(aclk5);
  mp_impl->aclk6(aclk6);
  mp_impl->sys_clk0_clk_p(sys_clk0_clk_p);
  mp_impl->sys_clk0_clk_n(sys_clk0_clk_n);
  mp_impl->CH0_DDR4_0_dq(CH0_DDR4_0_dq);
  mp_impl->CH0_DDR4_0_dqs_t(CH0_DDR4_0_dqs_t);
  mp_impl->CH0_DDR4_0_dqs_c(CH0_DDR4_0_dqs_c);
  mp_impl->CH0_DDR4_0_adr(CH0_DDR4_0_adr);
  mp_impl->CH0_DDR4_0_ba(CH0_DDR4_0_ba);
  mp_impl->CH0_DDR4_0_bg(CH0_DDR4_0_bg);
  mp_impl->CH0_DDR4_0_act_n(CH0_DDR4_0_act_n);
  mp_impl->CH0_DDR4_0_reset_n(CH0_DDR4_0_reset_n);
  mp_impl->CH0_DDR4_0_ck_t(CH0_DDR4_0_ck_t);
  mp_impl->CH0_DDR4_0_ck_c(CH0_DDR4_0_ck_c);
  mp_impl->CH0_DDR4_0_cke(CH0_DDR4_0_cke);
  mp_impl->CH0_DDR4_0_cs_n(CH0_DDR4_0_cs_n);
  mp_impl->CH0_DDR4_0_dm_n(CH0_DDR4_0_dm_n);
  mp_impl->CH0_DDR4_0_odt(CH0_DDR4_0_odt);

  // initialize transactors
  mp_S00_AXI_transactor = NULL;
  mp_S00_AXI_awlock_converter = NULL;
  mp_S00_AXI_awvalid_converter = NULL;
  mp_S00_AXI_awready_converter = NULL;
  mp_S00_AXI_wlast_converter = NULL;
  mp_S00_AXI_wvalid_converter = NULL;
  mp_S00_AXI_wready_converter = NULL;
  mp_S00_AXI_bvalid_converter = NULL;
  mp_S00_AXI_bready_converter = NULL;
  mp_S00_AXI_arlock_converter = NULL;
  mp_S00_AXI_arvalid_converter = NULL;
  mp_S00_AXI_arready_converter = NULL;
  mp_S00_AXI_rlast_converter = NULL;
  mp_S00_AXI_rvalid_converter = NULL;
  mp_S00_AXI_rready_converter = NULL;
  mp_S01_AXI_transactor = NULL;
  mp_S01_AXI_awlock_converter = NULL;
  mp_S01_AXI_awvalid_converter = NULL;
  mp_S01_AXI_awready_converter = NULL;
  mp_S01_AXI_wlast_converter = NULL;
  mp_S01_AXI_wvalid_converter = NULL;
  mp_S01_AXI_wready_converter = NULL;
  mp_S01_AXI_bvalid_converter = NULL;
  mp_S01_AXI_bready_converter = NULL;
  mp_S01_AXI_arlock_converter = NULL;
  mp_S01_AXI_arvalid_converter = NULL;
  mp_S01_AXI_arready_converter = NULL;
  mp_S01_AXI_rlast_converter = NULL;
  mp_S01_AXI_rvalid_converter = NULL;
  mp_S01_AXI_rready_converter = NULL;
  mp_S02_AXI_transactor = NULL;
  mp_S02_AXI_awlock_converter = NULL;
  mp_S02_AXI_awvalid_converter = NULL;
  mp_S02_AXI_awready_converter = NULL;
  mp_S02_AXI_wlast_converter = NULL;
  mp_S02_AXI_wvalid_converter = NULL;
  mp_S02_AXI_wready_converter = NULL;
  mp_S02_AXI_bvalid_converter = NULL;
  mp_S02_AXI_bready_converter = NULL;
  mp_S02_AXI_arlock_converter = NULL;
  mp_S02_AXI_arvalid_converter = NULL;
  mp_S02_AXI_arready_converter = NULL;
  mp_S02_AXI_rlast_converter = NULL;
  mp_S02_AXI_rvalid_converter = NULL;
  mp_S02_AXI_rready_converter = NULL;
  mp_S03_AXI_transactor = NULL;
  mp_S03_AXI_awlock_converter = NULL;
  mp_S03_AXI_awvalid_converter = NULL;
  mp_S03_AXI_awready_converter = NULL;
  mp_S03_AXI_wlast_converter = NULL;
  mp_S03_AXI_wvalid_converter = NULL;
  mp_S03_AXI_wready_converter = NULL;
  mp_S03_AXI_bvalid_converter = NULL;
  mp_S03_AXI_bready_converter = NULL;
  mp_S03_AXI_arlock_converter = NULL;
  mp_S03_AXI_arvalid_converter = NULL;
  mp_S03_AXI_arready_converter = NULL;
  mp_S03_AXI_rlast_converter = NULL;
  mp_S03_AXI_rvalid_converter = NULL;
  mp_S03_AXI_rready_converter = NULL;
  mp_S04_AXI_transactor = NULL;
  mp_S04_AXI_awlock_converter = NULL;
  mp_S04_AXI_awvalid_converter = NULL;
  mp_S04_AXI_awready_converter = NULL;
  mp_S04_AXI_wlast_converter = NULL;
  mp_S04_AXI_wvalid_converter = NULL;
  mp_S04_AXI_wready_converter = NULL;
  mp_S04_AXI_bvalid_converter = NULL;
  mp_S04_AXI_bready_converter = NULL;
  mp_S04_AXI_arlock_converter = NULL;
  mp_S04_AXI_arvalid_converter = NULL;
  mp_S04_AXI_arready_converter = NULL;
  mp_S04_AXI_rlast_converter = NULL;
  mp_S04_AXI_rvalid_converter = NULL;
  mp_S04_AXI_rready_converter = NULL;
  mp_S05_AXI_transactor = NULL;
  mp_S05_AXI_awlock_converter = NULL;
  mp_S05_AXI_awvalid_converter = NULL;
  mp_S05_AXI_awready_converter = NULL;
  mp_S05_AXI_wlast_converter = NULL;
  mp_S05_AXI_wvalid_converter = NULL;
  mp_S05_AXI_wready_converter = NULL;
  mp_S05_AXI_bvalid_converter = NULL;
  mp_S05_AXI_bready_converter = NULL;
  mp_S05_AXI_arlock_converter = NULL;
  mp_S05_AXI_arvalid_converter = NULL;
  mp_S05_AXI_arready_converter = NULL;
  mp_S05_AXI_rlast_converter = NULL;
  mp_S05_AXI_rvalid_converter = NULL;
  mp_S05_AXI_rready_converter = NULL;
  mp_S06_AXI_transactor = NULL;
  mp_S06_AXI_awlock_converter = NULL;
  mp_S06_AXI_awvalid_converter = NULL;
  mp_S06_AXI_awready_converter = NULL;
  mp_S06_AXI_wlast_converter = NULL;
  mp_S06_AXI_wvalid_converter = NULL;
  mp_S06_AXI_wready_converter = NULL;
  mp_S06_AXI_bvalid_converter = NULL;
  mp_S06_AXI_bready_converter = NULL;
  mp_S06_AXI_arlock_converter = NULL;
  mp_S06_AXI_arvalid_converter = NULL;
  mp_S06_AXI_arready_converter = NULL;
  mp_S06_AXI_rlast_converter = NULL;
  mp_S06_AXI_rvalid_converter = NULL;
  mp_S06_AXI_rready_converter = NULL;

  // initialize socket stubs

}

void bd_soc_usart_axi_noc_0_0::before_end_of_elaboration()
{
  // configure 'S00_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S00_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S00_AXI' transactor parameters
    xsc::common_cpp::properties S00_AXI_transactor_param_props;
    S00_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S00_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S00_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S00_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S00_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S00_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S00_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S00_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S00_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S00_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S00_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S00_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S00_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S00_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S00_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S00_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S00_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S00_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");
    S00_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S00_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S00_AXI_transactor_param_props.addString("REGION", "0");
    S00_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S00_AXI_transactor_param_props.addString("DEST_IDS", "");
    S00_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S00_AXI_transactor_param_props.addString("REMAPS", "");
    S00_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S00_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S00_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S00_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S00_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S00_AXI_transactor", S00_AXI_transactor_param_props);

    // S00_AXI' transactor ports

    mp_S00_AXI_transactor->AWADDR(S00_AXI_awaddr);
    mp_S00_AXI_transactor->AWLEN(S00_AXI_awlen);
    mp_S00_AXI_transactor->AWSIZE(S00_AXI_awsize);
    mp_S00_AXI_transactor->AWBURST(S00_AXI_awburst);
    mp_S00_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awlock_converter");
    mp_S00_AXI_awlock_converter->vector_in(S00_AXI_awlock);
    mp_S00_AXI_awlock_converter->scalar_out(m_S00_AXI_awlock_converter_signal);
    mp_S00_AXI_transactor->AWLOCK(m_S00_AXI_awlock_converter_signal);
    mp_S00_AXI_transactor->AWCACHE(S00_AXI_awcache);
    mp_S00_AXI_transactor->AWPROT(S00_AXI_awprot);
    mp_S00_AXI_transactor->AWREGION(S00_AXI_awregion);
    mp_S00_AXI_transactor->AWQOS(S00_AXI_awqos);
    mp_S00_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awvalid_converter");
    mp_S00_AXI_awvalid_converter->vector_in(S00_AXI_awvalid);
    mp_S00_AXI_awvalid_converter->scalar_out(m_S00_AXI_awvalid_converter_signal);
    mp_S00_AXI_transactor->AWVALID(m_S00_AXI_awvalid_converter_signal);
    mp_S00_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_awready_converter");
    mp_S00_AXI_awready_converter->scalar_in(m_S00_AXI_awready_converter_signal);
    mp_S00_AXI_awready_converter->vector_out(S00_AXI_awready);
    mp_S00_AXI_transactor->AWREADY(m_S00_AXI_awready_converter_signal);
    mp_S00_AXI_transactor->WDATA(S00_AXI_wdata);
    mp_S00_AXI_transactor->WSTRB(S00_AXI_wstrb);
    mp_S00_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wlast_converter");
    mp_S00_AXI_wlast_converter->vector_in(S00_AXI_wlast);
    mp_S00_AXI_wlast_converter->scalar_out(m_S00_AXI_wlast_converter_signal);
    mp_S00_AXI_transactor->WLAST(m_S00_AXI_wlast_converter_signal);
    mp_S00_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wvalid_converter");
    mp_S00_AXI_wvalid_converter->vector_in(S00_AXI_wvalid);
    mp_S00_AXI_wvalid_converter->scalar_out(m_S00_AXI_wvalid_converter_signal);
    mp_S00_AXI_transactor->WVALID(m_S00_AXI_wvalid_converter_signal);
    mp_S00_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_wready_converter");
    mp_S00_AXI_wready_converter->scalar_in(m_S00_AXI_wready_converter_signal);
    mp_S00_AXI_wready_converter->vector_out(S00_AXI_wready);
    mp_S00_AXI_transactor->WREADY(m_S00_AXI_wready_converter_signal);
    mp_S00_AXI_transactor->BRESP(S00_AXI_bresp);
    mp_S00_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_bvalid_converter");
    mp_S00_AXI_bvalid_converter->scalar_in(m_S00_AXI_bvalid_converter_signal);
    mp_S00_AXI_bvalid_converter->vector_out(S00_AXI_bvalid);
    mp_S00_AXI_transactor->BVALID(m_S00_AXI_bvalid_converter_signal);
    mp_S00_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_bready_converter");
    mp_S00_AXI_bready_converter->vector_in(S00_AXI_bready);
    mp_S00_AXI_bready_converter->scalar_out(m_S00_AXI_bready_converter_signal);
    mp_S00_AXI_transactor->BREADY(m_S00_AXI_bready_converter_signal);
    mp_S00_AXI_transactor->ARADDR(S00_AXI_araddr);
    mp_S00_AXI_transactor->ARLEN(S00_AXI_arlen);
    mp_S00_AXI_transactor->ARSIZE(S00_AXI_arsize);
    mp_S00_AXI_transactor->ARBURST(S00_AXI_arburst);
    mp_S00_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arlock_converter");
    mp_S00_AXI_arlock_converter->vector_in(S00_AXI_arlock);
    mp_S00_AXI_arlock_converter->scalar_out(m_S00_AXI_arlock_converter_signal);
    mp_S00_AXI_transactor->ARLOCK(m_S00_AXI_arlock_converter_signal);
    mp_S00_AXI_transactor->ARCACHE(S00_AXI_arcache);
    mp_S00_AXI_transactor->ARPROT(S00_AXI_arprot);
    mp_S00_AXI_transactor->ARREGION(S00_AXI_arregion);
    mp_S00_AXI_transactor->ARQOS(S00_AXI_arqos);
    mp_S00_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arvalid_converter");
    mp_S00_AXI_arvalid_converter->vector_in(S00_AXI_arvalid);
    mp_S00_AXI_arvalid_converter->scalar_out(m_S00_AXI_arvalid_converter_signal);
    mp_S00_AXI_transactor->ARVALID(m_S00_AXI_arvalid_converter_signal);
    mp_S00_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_arready_converter");
    mp_S00_AXI_arready_converter->scalar_in(m_S00_AXI_arready_converter_signal);
    mp_S00_AXI_arready_converter->vector_out(S00_AXI_arready);
    mp_S00_AXI_transactor->ARREADY(m_S00_AXI_arready_converter_signal);
    mp_S00_AXI_transactor->RDATA(S00_AXI_rdata);
    mp_S00_AXI_transactor->RRESP(S00_AXI_rresp);
    mp_S00_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rlast_converter");
    mp_S00_AXI_rlast_converter->scalar_in(m_S00_AXI_rlast_converter_signal);
    mp_S00_AXI_rlast_converter->vector_out(S00_AXI_rlast);
    mp_S00_AXI_transactor->RLAST(m_S00_AXI_rlast_converter_signal);
    mp_S00_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rvalid_converter");
    mp_S00_AXI_rvalid_converter->scalar_in(m_S00_AXI_rvalid_converter_signal);
    mp_S00_AXI_rvalid_converter->vector_out(S00_AXI_rvalid);
    mp_S00_AXI_transactor->RVALID(m_S00_AXI_rvalid_converter_signal);
    mp_S00_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_rready_converter");
    mp_S00_AXI_rready_converter->vector_in(S00_AXI_rready);
    mp_S00_AXI_rready_converter->scalar_out(m_S00_AXI_rready_converter_signal);
    mp_S00_AXI_transactor->RREADY(m_S00_AXI_rready_converter_signal);
    mp_S00_AXI_transactor->ARID(S00_AXI_arid);
    mp_S00_AXI_transactor->ARUSER(S00_AXI_aruser);
    mp_S00_AXI_transactor->AWID(S00_AXI_awid);
    mp_S00_AXI_transactor->AWUSER(S00_AXI_awuser);
    mp_S00_AXI_transactor->BID(S00_AXI_bid);
    mp_S00_AXI_transactor->RID(S00_AXI_rid);
    mp_S00_AXI_transactor->RUSER(S00_AXI_ruser);
    mp_S00_AXI_transactor->WUSER(S00_AXI_wuser);
    mp_S00_AXI_transactor->CLK(aclk0);
    m_S00_AXI_transactor_rst_signal.write(1);
    mp_S00_AXI_transactor->RST(m_S00_AXI_transactor_rst_signal);

    // S00_AXI' transactor sockets

    mp_impl->S00_AXI_tlm_aximm_read_socket->bind(*(mp_S00_AXI_transactor->rd_socket));
    mp_impl->S00_AXI_tlm_aximm_write_socket->bind(*(mp_S00_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S01_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S01_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S01_AXI' transactor parameters
    xsc::common_cpp::properties S01_AXI_transactor_param_props;
    S01_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S01_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S01_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S01_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S01_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S01_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S01_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S01_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S01_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S01_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S01_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S01_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S01_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S01_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S01_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S01_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S01_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S01_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk");
    S01_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S01_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S01_AXI_transactor_param_props.addString("REGION", "0");
    S01_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S01_AXI_transactor_param_props.addString("DEST_IDS", "");
    S01_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S01_AXI_transactor_param_props.addString("REMAPS", "");
    S01_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S01_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S01_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S01_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S01_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S01_AXI_transactor", S01_AXI_transactor_param_props);

    // S01_AXI' transactor ports

    mp_S01_AXI_transactor->AWADDR(S01_AXI_awaddr);
    mp_S01_AXI_transactor->AWLEN(S01_AXI_awlen);
    mp_S01_AXI_transactor->AWSIZE(S01_AXI_awsize);
    mp_S01_AXI_transactor->AWBURST(S01_AXI_awburst);
    mp_S01_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awlock_converter");
    mp_S01_AXI_awlock_converter->vector_in(S01_AXI_awlock);
    mp_S01_AXI_awlock_converter->scalar_out(m_S01_AXI_awlock_converter_signal);
    mp_S01_AXI_transactor->AWLOCK(m_S01_AXI_awlock_converter_signal);
    mp_S01_AXI_transactor->AWCACHE(S01_AXI_awcache);
    mp_S01_AXI_transactor->AWPROT(S01_AXI_awprot);
    mp_S01_AXI_transactor->AWREGION(S01_AXI_awregion);
    mp_S01_AXI_transactor->AWQOS(S01_AXI_awqos);
    mp_S01_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awvalid_converter");
    mp_S01_AXI_awvalid_converter->vector_in(S01_AXI_awvalid);
    mp_S01_AXI_awvalid_converter->scalar_out(m_S01_AXI_awvalid_converter_signal);
    mp_S01_AXI_transactor->AWVALID(m_S01_AXI_awvalid_converter_signal);
    mp_S01_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_awready_converter");
    mp_S01_AXI_awready_converter->scalar_in(m_S01_AXI_awready_converter_signal);
    mp_S01_AXI_awready_converter->vector_out(S01_AXI_awready);
    mp_S01_AXI_transactor->AWREADY(m_S01_AXI_awready_converter_signal);
    mp_S01_AXI_transactor->WDATA(S01_AXI_wdata);
    mp_S01_AXI_transactor->WSTRB(S01_AXI_wstrb);
    mp_S01_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wlast_converter");
    mp_S01_AXI_wlast_converter->vector_in(S01_AXI_wlast);
    mp_S01_AXI_wlast_converter->scalar_out(m_S01_AXI_wlast_converter_signal);
    mp_S01_AXI_transactor->WLAST(m_S01_AXI_wlast_converter_signal);
    mp_S01_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wvalid_converter");
    mp_S01_AXI_wvalid_converter->vector_in(S01_AXI_wvalid);
    mp_S01_AXI_wvalid_converter->scalar_out(m_S01_AXI_wvalid_converter_signal);
    mp_S01_AXI_transactor->WVALID(m_S01_AXI_wvalid_converter_signal);
    mp_S01_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_wready_converter");
    mp_S01_AXI_wready_converter->scalar_in(m_S01_AXI_wready_converter_signal);
    mp_S01_AXI_wready_converter->vector_out(S01_AXI_wready);
    mp_S01_AXI_transactor->WREADY(m_S01_AXI_wready_converter_signal);
    mp_S01_AXI_transactor->BRESP(S01_AXI_bresp);
    mp_S01_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_bvalid_converter");
    mp_S01_AXI_bvalid_converter->scalar_in(m_S01_AXI_bvalid_converter_signal);
    mp_S01_AXI_bvalid_converter->vector_out(S01_AXI_bvalid);
    mp_S01_AXI_transactor->BVALID(m_S01_AXI_bvalid_converter_signal);
    mp_S01_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_bready_converter");
    mp_S01_AXI_bready_converter->vector_in(S01_AXI_bready);
    mp_S01_AXI_bready_converter->scalar_out(m_S01_AXI_bready_converter_signal);
    mp_S01_AXI_transactor->BREADY(m_S01_AXI_bready_converter_signal);
    mp_S01_AXI_transactor->ARADDR(S01_AXI_araddr);
    mp_S01_AXI_transactor->ARLEN(S01_AXI_arlen);
    mp_S01_AXI_transactor->ARSIZE(S01_AXI_arsize);
    mp_S01_AXI_transactor->ARBURST(S01_AXI_arburst);
    mp_S01_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arlock_converter");
    mp_S01_AXI_arlock_converter->vector_in(S01_AXI_arlock);
    mp_S01_AXI_arlock_converter->scalar_out(m_S01_AXI_arlock_converter_signal);
    mp_S01_AXI_transactor->ARLOCK(m_S01_AXI_arlock_converter_signal);
    mp_S01_AXI_transactor->ARCACHE(S01_AXI_arcache);
    mp_S01_AXI_transactor->ARPROT(S01_AXI_arprot);
    mp_S01_AXI_transactor->ARREGION(S01_AXI_arregion);
    mp_S01_AXI_transactor->ARQOS(S01_AXI_arqos);
    mp_S01_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arvalid_converter");
    mp_S01_AXI_arvalid_converter->vector_in(S01_AXI_arvalid);
    mp_S01_AXI_arvalid_converter->scalar_out(m_S01_AXI_arvalid_converter_signal);
    mp_S01_AXI_transactor->ARVALID(m_S01_AXI_arvalid_converter_signal);
    mp_S01_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_arready_converter");
    mp_S01_AXI_arready_converter->scalar_in(m_S01_AXI_arready_converter_signal);
    mp_S01_AXI_arready_converter->vector_out(S01_AXI_arready);
    mp_S01_AXI_transactor->ARREADY(m_S01_AXI_arready_converter_signal);
    mp_S01_AXI_transactor->RDATA(S01_AXI_rdata);
    mp_S01_AXI_transactor->RRESP(S01_AXI_rresp);
    mp_S01_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rlast_converter");
    mp_S01_AXI_rlast_converter->scalar_in(m_S01_AXI_rlast_converter_signal);
    mp_S01_AXI_rlast_converter->vector_out(S01_AXI_rlast);
    mp_S01_AXI_transactor->RLAST(m_S01_AXI_rlast_converter_signal);
    mp_S01_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rvalid_converter");
    mp_S01_AXI_rvalid_converter->scalar_in(m_S01_AXI_rvalid_converter_signal);
    mp_S01_AXI_rvalid_converter->vector_out(S01_AXI_rvalid);
    mp_S01_AXI_transactor->RVALID(m_S01_AXI_rvalid_converter_signal);
    mp_S01_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_rready_converter");
    mp_S01_AXI_rready_converter->vector_in(S01_AXI_rready);
    mp_S01_AXI_rready_converter->scalar_out(m_S01_AXI_rready_converter_signal);
    mp_S01_AXI_transactor->RREADY(m_S01_AXI_rready_converter_signal);
    mp_S01_AXI_transactor->ARID(S01_AXI_arid);
    mp_S01_AXI_transactor->ARUSER(S01_AXI_aruser);
    mp_S01_AXI_transactor->AWID(S01_AXI_awid);
    mp_S01_AXI_transactor->AWUSER(S01_AXI_awuser);
    mp_S01_AXI_transactor->BID(S01_AXI_bid);
    mp_S01_AXI_transactor->RID(S01_AXI_rid);
    mp_S01_AXI_transactor->RUSER(S01_AXI_ruser);
    mp_S01_AXI_transactor->WUSER(S01_AXI_wuser);
    mp_S01_AXI_transactor->CLK(aclk1);
    m_S01_AXI_transactor_rst_signal.write(1);
    mp_S01_AXI_transactor->RST(m_S01_AXI_transactor_rst_signal);

    // S01_AXI' transactor sockets

    mp_impl->S01_AXI_tlm_aximm_read_socket->bind(*(mp_S01_AXI_transactor->rd_socket));
    mp_impl->S01_AXI_tlm_aximm_write_socket->bind(*(mp_S01_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S02_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S02_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S02_AXI' transactor parameters
    xsc::common_cpp::properties S02_AXI_transactor_param_props;
    S02_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S02_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S02_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S02_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S02_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S02_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S02_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S02_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S02_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S02_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S02_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S02_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S02_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S02_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S02_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S02_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S02_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S02_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk");
    S02_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S02_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S02_AXI_transactor_param_props.addString("REGION", "0");
    S02_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S02_AXI_transactor_param_props.addString("DEST_IDS", "");
    S02_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S02_AXI_transactor_param_props.addString("REMAPS", "");
    S02_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S02_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S02_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S02_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S02_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S02_AXI_transactor", S02_AXI_transactor_param_props);

    // S02_AXI' transactor ports

    mp_S02_AXI_transactor->AWADDR(S02_AXI_awaddr);
    mp_S02_AXI_transactor->AWLEN(S02_AXI_awlen);
    mp_S02_AXI_transactor->AWSIZE(S02_AXI_awsize);
    mp_S02_AXI_transactor->AWBURST(S02_AXI_awburst);
    mp_S02_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awlock_converter");
    mp_S02_AXI_awlock_converter->vector_in(S02_AXI_awlock);
    mp_S02_AXI_awlock_converter->scalar_out(m_S02_AXI_awlock_converter_signal);
    mp_S02_AXI_transactor->AWLOCK(m_S02_AXI_awlock_converter_signal);
    mp_S02_AXI_transactor->AWCACHE(S02_AXI_awcache);
    mp_S02_AXI_transactor->AWPROT(S02_AXI_awprot);
    mp_S02_AXI_transactor->AWREGION(S02_AXI_awregion);
    mp_S02_AXI_transactor->AWQOS(S02_AXI_awqos);
    mp_S02_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awvalid_converter");
    mp_S02_AXI_awvalid_converter->vector_in(S02_AXI_awvalid);
    mp_S02_AXI_awvalid_converter->scalar_out(m_S02_AXI_awvalid_converter_signal);
    mp_S02_AXI_transactor->AWVALID(m_S02_AXI_awvalid_converter_signal);
    mp_S02_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_awready_converter");
    mp_S02_AXI_awready_converter->scalar_in(m_S02_AXI_awready_converter_signal);
    mp_S02_AXI_awready_converter->vector_out(S02_AXI_awready);
    mp_S02_AXI_transactor->AWREADY(m_S02_AXI_awready_converter_signal);
    mp_S02_AXI_transactor->WDATA(S02_AXI_wdata);
    mp_S02_AXI_transactor->WSTRB(S02_AXI_wstrb);
    mp_S02_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wlast_converter");
    mp_S02_AXI_wlast_converter->vector_in(S02_AXI_wlast);
    mp_S02_AXI_wlast_converter->scalar_out(m_S02_AXI_wlast_converter_signal);
    mp_S02_AXI_transactor->WLAST(m_S02_AXI_wlast_converter_signal);
    mp_S02_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wvalid_converter");
    mp_S02_AXI_wvalid_converter->vector_in(S02_AXI_wvalid);
    mp_S02_AXI_wvalid_converter->scalar_out(m_S02_AXI_wvalid_converter_signal);
    mp_S02_AXI_transactor->WVALID(m_S02_AXI_wvalid_converter_signal);
    mp_S02_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_wready_converter");
    mp_S02_AXI_wready_converter->scalar_in(m_S02_AXI_wready_converter_signal);
    mp_S02_AXI_wready_converter->vector_out(S02_AXI_wready);
    mp_S02_AXI_transactor->WREADY(m_S02_AXI_wready_converter_signal);
    mp_S02_AXI_transactor->BRESP(S02_AXI_bresp);
    mp_S02_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_bvalid_converter");
    mp_S02_AXI_bvalid_converter->scalar_in(m_S02_AXI_bvalid_converter_signal);
    mp_S02_AXI_bvalid_converter->vector_out(S02_AXI_bvalid);
    mp_S02_AXI_transactor->BVALID(m_S02_AXI_bvalid_converter_signal);
    mp_S02_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_bready_converter");
    mp_S02_AXI_bready_converter->vector_in(S02_AXI_bready);
    mp_S02_AXI_bready_converter->scalar_out(m_S02_AXI_bready_converter_signal);
    mp_S02_AXI_transactor->BREADY(m_S02_AXI_bready_converter_signal);
    mp_S02_AXI_transactor->ARADDR(S02_AXI_araddr);
    mp_S02_AXI_transactor->ARLEN(S02_AXI_arlen);
    mp_S02_AXI_transactor->ARSIZE(S02_AXI_arsize);
    mp_S02_AXI_transactor->ARBURST(S02_AXI_arburst);
    mp_S02_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arlock_converter");
    mp_S02_AXI_arlock_converter->vector_in(S02_AXI_arlock);
    mp_S02_AXI_arlock_converter->scalar_out(m_S02_AXI_arlock_converter_signal);
    mp_S02_AXI_transactor->ARLOCK(m_S02_AXI_arlock_converter_signal);
    mp_S02_AXI_transactor->ARCACHE(S02_AXI_arcache);
    mp_S02_AXI_transactor->ARPROT(S02_AXI_arprot);
    mp_S02_AXI_transactor->ARREGION(S02_AXI_arregion);
    mp_S02_AXI_transactor->ARQOS(S02_AXI_arqos);
    mp_S02_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arvalid_converter");
    mp_S02_AXI_arvalid_converter->vector_in(S02_AXI_arvalid);
    mp_S02_AXI_arvalid_converter->scalar_out(m_S02_AXI_arvalid_converter_signal);
    mp_S02_AXI_transactor->ARVALID(m_S02_AXI_arvalid_converter_signal);
    mp_S02_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_arready_converter");
    mp_S02_AXI_arready_converter->scalar_in(m_S02_AXI_arready_converter_signal);
    mp_S02_AXI_arready_converter->vector_out(S02_AXI_arready);
    mp_S02_AXI_transactor->ARREADY(m_S02_AXI_arready_converter_signal);
    mp_S02_AXI_transactor->RDATA(S02_AXI_rdata);
    mp_S02_AXI_transactor->RRESP(S02_AXI_rresp);
    mp_S02_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rlast_converter");
    mp_S02_AXI_rlast_converter->scalar_in(m_S02_AXI_rlast_converter_signal);
    mp_S02_AXI_rlast_converter->vector_out(S02_AXI_rlast);
    mp_S02_AXI_transactor->RLAST(m_S02_AXI_rlast_converter_signal);
    mp_S02_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rvalid_converter");
    mp_S02_AXI_rvalid_converter->scalar_in(m_S02_AXI_rvalid_converter_signal);
    mp_S02_AXI_rvalid_converter->vector_out(S02_AXI_rvalid);
    mp_S02_AXI_transactor->RVALID(m_S02_AXI_rvalid_converter_signal);
    mp_S02_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_rready_converter");
    mp_S02_AXI_rready_converter->vector_in(S02_AXI_rready);
    mp_S02_AXI_rready_converter->scalar_out(m_S02_AXI_rready_converter_signal);
    mp_S02_AXI_transactor->RREADY(m_S02_AXI_rready_converter_signal);
    mp_S02_AXI_transactor->ARID(S02_AXI_arid);
    mp_S02_AXI_transactor->ARUSER(S02_AXI_aruser);
    mp_S02_AXI_transactor->AWID(S02_AXI_awid);
    mp_S02_AXI_transactor->AWUSER(S02_AXI_awuser);
    mp_S02_AXI_transactor->BID(S02_AXI_bid);
    mp_S02_AXI_transactor->RID(S02_AXI_rid);
    mp_S02_AXI_transactor->RUSER(S02_AXI_ruser);
    mp_S02_AXI_transactor->WUSER(S02_AXI_wuser);
    mp_S02_AXI_transactor->CLK(aclk2);
    m_S02_AXI_transactor_rst_signal.write(1);
    mp_S02_AXI_transactor->RST(m_S02_AXI_transactor_rst_signal);

    // S02_AXI' transactor sockets

    mp_impl->S02_AXI_tlm_aximm_read_socket->bind(*(mp_S02_AXI_transactor->rd_socket));
    mp_impl->S02_AXI_tlm_aximm_write_socket->bind(*(mp_S02_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S03_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S03_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S03_AXI' transactor parameters
    xsc::common_cpp::properties S03_AXI_transactor_param_props;
    S03_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S03_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S03_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S03_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S03_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S03_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S03_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S03_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S03_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S03_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S03_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S03_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S03_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S03_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S03_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S03_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S03_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S03_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk");
    S03_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S03_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S03_AXI_transactor_param_props.addString("REGION", "0");
    S03_AXI_transactor_param_props.addString("CONNECTIONS", "MC_1 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S03_AXI_transactor_param_props.addString("DEST_IDS", "");
    S03_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S03_AXI_transactor_param_props.addString("REMAPS", "");
    S03_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S03_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S03_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S03_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S03_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S03_AXI_transactor", S03_AXI_transactor_param_props);

    // S03_AXI' transactor ports

    mp_S03_AXI_transactor->AWADDR(S03_AXI_awaddr);
    mp_S03_AXI_transactor->AWLEN(S03_AXI_awlen);
    mp_S03_AXI_transactor->AWSIZE(S03_AXI_awsize);
    mp_S03_AXI_transactor->AWBURST(S03_AXI_awburst);
    mp_S03_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awlock_converter");
    mp_S03_AXI_awlock_converter->vector_in(S03_AXI_awlock);
    mp_S03_AXI_awlock_converter->scalar_out(m_S03_AXI_awlock_converter_signal);
    mp_S03_AXI_transactor->AWLOCK(m_S03_AXI_awlock_converter_signal);
    mp_S03_AXI_transactor->AWCACHE(S03_AXI_awcache);
    mp_S03_AXI_transactor->AWPROT(S03_AXI_awprot);
    mp_S03_AXI_transactor->AWREGION(S03_AXI_awregion);
    mp_S03_AXI_transactor->AWQOS(S03_AXI_awqos);
    mp_S03_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awvalid_converter");
    mp_S03_AXI_awvalid_converter->vector_in(S03_AXI_awvalid);
    mp_S03_AXI_awvalid_converter->scalar_out(m_S03_AXI_awvalid_converter_signal);
    mp_S03_AXI_transactor->AWVALID(m_S03_AXI_awvalid_converter_signal);
    mp_S03_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_awready_converter");
    mp_S03_AXI_awready_converter->scalar_in(m_S03_AXI_awready_converter_signal);
    mp_S03_AXI_awready_converter->vector_out(S03_AXI_awready);
    mp_S03_AXI_transactor->AWREADY(m_S03_AXI_awready_converter_signal);
    mp_S03_AXI_transactor->WDATA(S03_AXI_wdata);
    mp_S03_AXI_transactor->WSTRB(S03_AXI_wstrb);
    mp_S03_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wlast_converter");
    mp_S03_AXI_wlast_converter->vector_in(S03_AXI_wlast);
    mp_S03_AXI_wlast_converter->scalar_out(m_S03_AXI_wlast_converter_signal);
    mp_S03_AXI_transactor->WLAST(m_S03_AXI_wlast_converter_signal);
    mp_S03_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wvalid_converter");
    mp_S03_AXI_wvalid_converter->vector_in(S03_AXI_wvalid);
    mp_S03_AXI_wvalid_converter->scalar_out(m_S03_AXI_wvalid_converter_signal);
    mp_S03_AXI_transactor->WVALID(m_S03_AXI_wvalid_converter_signal);
    mp_S03_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_wready_converter");
    mp_S03_AXI_wready_converter->scalar_in(m_S03_AXI_wready_converter_signal);
    mp_S03_AXI_wready_converter->vector_out(S03_AXI_wready);
    mp_S03_AXI_transactor->WREADY(m_S03_AXI_wready_converter_signal);
    mp_S03_AXI_transactor->BRESP(S03_AXI_bresp);
    mp_S03_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_bvalid_converter");
    mp_S03_AXI_bvalid_converter->scalar_in(m_S03_AXI_bvalid_converter_signal);
    mp_S03_AXI_bvalid_converter->vector_out(S03_AXI_bvalid);
    mp_S03_AXI_transactor->BVALID(m_S03_AXI_bvalid_converter_signal);
    mp_S03_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_bready_converter");
    mp_S03_AXI_bready_converter->vector_in(S03_AXI_bready);
    mp_S03_AXI_bready_converter->scalar_out(m_S03_AXI_bready_converter_signal);
    mp_S03_AXI_transactor->BREADY(m_S03_AXI_bready_converter_signal);
    mp_S03_AXI_transactor->ARADDR(S03_AXI_araddr);
    mp_S03_AXI_transactor->ARLEN(S03_AXI_arlen);
    mp_S03_AXI_transactor->ARSIZE(S03_AXI_arsize);
    mp_S03_AXI_transactor->ARBURST(S03_AXI_arburst);
    mp_S03_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arlock_converter");
    mp_S03_AXI_arlock_converter->vector_in(S03_AXI_arlock);
    mp_S03_AXI_arlock_converter->scalar_out(m_S03_AXI_arlock_converter_signal);
    mp_S03_AXI_transactor->ARLOCK(m_S03_AXI_arlock_converter_signal);
    mp_S03_AXI_transactor->ARCACHE(S03_AXI_arcache);
    mp_S03_AXI_transactor->ARPROT(S03_AXI_arprot);
    mp_S03_AXI_transactor->ARREGION(S03_AXI_arregion);
    mp_S03_AXI_transactor->ARQOS(S03_AXI_arqos);
    mp_S03_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arvalid_converter");
    mp_S03_AXI_arvalid_converter->vector_in(S03_AXI_arvalid);
    mp_S03_AXI_arvalid_converter->scalar_out(m_S03_AXI_arvalid_converter_signal);
    mp_S03_AXI_transactor->ARVALID(m_S03_AXI_arvalid_converter_signal);
    mp_S03_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_arready_converter");
    mp_S03_AXI_arready_converter->scalar_in(m_S03_AXI_arready_converter_signal);
    mp_S03_AXI_arready_converter->vector_out(S03_AXI_arready);
    mp_S03_AXI_transactor->ARREADY(m_S03_AXI_arready_converter_signal);
    mp_S03_AXI_transactor->RDATA(S03_AXI_rdata);
    mp_S03_AXI_transactor->RRESP(S03_AXI_rresp);
    mp_S03_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rlast_converter");
    mp_S03_AXI_rlast_converter->scalar_in(m_S03_AXI_rlast_converter_signal);
    mp_S03_AXI_rlast_converter->vector_out(S03_AXI_rlast);
    mp_S03_AXI_transactor->RLAST(m_S03_AXI_rlast_converter_signal);
    mp_S03_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rvalid_converter");
    mp_S03_AXI_rvalid_converter->scalar_in(m_S03_AXI_rvalid_converter_signal);
    mp_S03_AXI_rvalid_converter->vector_out(S03_AXI_rvalid);
    mp_S03_AXI_transactor->RVALID(m_S03_AXI_rvalid_converter_signal);
    mp_S03_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_rready_converter");
    mp_S03_AXI_rready_converter->vector_in(S03_AXI_rready);
    mp_S03_AXI_rready_converter->scalar_out(m_S03_AXI_rready_converter_signal);
    mp_S03_AXI_transactor->RREADY(m_S03_AXI_rready_converter_signal);
    mp_S03_AXI_transactor->ARID(S03_AXI_arid);
    mp_S03_AXI_transactor->ARUSER(S03_AXI_aruser);
    mp_S03_AXI_transactor->AWID(S03_AXI_awid);
    mp_S03_AXI_transactor->AWUSER(S03_AXI_awuser);
    mp_S03_AXI_transactor->BID(S03_AXI_bid);
    mp_S03_AXI_transactor->RID(S03_AXI_rid);
    mp_S03_AXI_transactor->RUSER(S03_AXI_ruser);
    mp_S03_AXI_transactor->WUSER(S03_AXI_wuser);
    mp_S03_AXI_transactor->CLK(aclk3);
    m_S03_AXI_transactor_rst_signal.write(1);
    mp_S03_AXI_transactor->RST(m_S03_AXI_transactor_rst_signal);

    // S03_AXI' transactor sockets

    mp_impl->S03_AXI_tlm_aximm_read_socket->bind(*(mp_S03_AXI_transactor->rd_socket));
    mp_impl->S03_AXI_tlm_aximm_write_socket->bind(*(mp_S03_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S04_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S04_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S04_AXI' transactor parameters
    xsc::common_cpp::properties S04_AXI_transactor_param_props;
    S04_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S04_AXI_transactor_param_props.addLong("FREQ_HZ", "400000000");
    S04_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S04_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S04_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S04_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S04_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S04_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S04_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S04_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S04_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S04_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S04_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S04_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S04_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S04_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S04_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S04_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_lpd_axi_noc_clk");
    S04_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S04_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S04_AXI_transactor_param_props.addString("REGION", "0");
    S04_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S04_AXI_transactor_param_props.addString("DEST_IDS", "");
    S04_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S04_AXI_transactor_param_props.addString("REMAPS", "");
    S04_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S04_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S04_AXI_transactor_param_props.addString("CATEGORY", "ps_rpu");
    S04_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S04_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S04_AXI_transactor", S04_AXI_transactor_param_props);

    // S04_AXI' transactor ports

    mp_S04_AXI_transactor->AWADDR(S04_AXI_awaddr);
    mp_S04_AXI_transactor->AWLEN(S04_AXI_awlen);
    mp_S04_AXI_transactor->AWSIZE(S04_AXI_awsize);
    mp_S04_AXI_transactor->AWBURST(S04_AXI_awburst);
    mp_S04_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awlock_converter");
    mp_S04_AXI_awlock_converter->vector_in(S04_AXI_awlock);
    mp_S04_AXI_awlock_converter->scalar_out(m_S04_AXI_awlock_converter_signal);
    mp_S04_AXI_transactor->AWLOCK(m_S04_AXI_awlock_converter_signal);
    mp_S04_AXI_transactor->AWCACHE(S04_AXI_awcache);
    mp_S04_AXI_transactor->AWPROT(S04_AXI_awprot);
    mp_S04_AXI_transactor->AWREGION(S04_AXI_awregion);
    mp_S04_AXI_transactor->AWQOS(S04_AXI_awqos);
    mp_S04_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awvalid_converter");
    mp_S04_AXI_awvalid_converter->vector_in(S04_AXI_awvalid);
    mp_S04_AXI_awvalid_converter->scalar_out(m_S04_AXI_awvalid_converter_signal);
    mp_S04_AXI_transactor->AWVALID(m_S04_AXI_awvalid_converter_signal);
    mp_S04_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_awready_converter");
    mp_S04_AXI_awready_converter->scalar_in(m_S04_AXI_awready_converter_signal);
    mp_S04_AXI_awready_converter->vector_out(S04_AXI_awready);
    mp_S04_AXI_transactor->AWREADY(m_S04_AXI_awready_converter_signal);
    mp_S04_AXI_transactor->WDATA(S04_AXI_wdata);
    mp_S04_AXI_transactor->WSTRB(S04_AXI_wstrb);
    mp_S04_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wlast_converter");
    mp_S04_AXI_wlast_converter->vector_in(S04_AXI_wlast);
    mp_S04_AXI_wlast_converter->scalar_out(m_S04_AXI_wlast_converter_signal);
    mp_S04_AXI_transactor->WLAST(m_S04_AXI_wlast_converter_signal);
    mp_S04_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wvalid_converter");
    mp_S04_AXI_wvalid_converter->vector_in(S04_AXI_wvalid);
    mp_S04_AXI_wvalid_converter->scalar_out(m_S04_AXI_wvalid_converter_signal);
    mp_S04_AXI_transactor->WVALID(m_S04_AXI_wvalid_converter_signal);
    mp_S04_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_wready_converter");
    mp_S04_AXI_wready_converter->scalar_in(m_S04_AXI_wready_converter_signal);
    mp_S04_AXI_wready_converter->vector_out(S04_AXI_wready);
    mp_S04_AXI_transactor->WREADY(m_S04_AXI_wready_converter_signal);
    mp_S04_AXI_transactor->BRESP(S04_AXI_bresp);
    mp_S04_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_bvalid_converter");
    mp_S04_AXI_bvalid_converter->scalar_in(m_S04_AXI_bvalid_converter_signal);
    mp_S04_AXI_bvalid_converter->vector_out(S04_AXI_bvalid);
    mp_S04_AXI_transactor->BVALID(m_S04_AXI_bvalid_converter_signal);
    mp_S04_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_bready_converter");
    mp_S04_AXI_bready_converter->vector_in(S04_AXI_bready);
    mp_S04_AXI_bready_converter->scalar_out(m_S04_AXI_bready_converter_signal);
    mp_S04_AXI_transactor->BREADY(m_S04_AXI_bready_converter_signal);
    mp_S04_AXI_transactor->ARADDR(S04_AXI_araddr);
    mp_S04_AXI_transactor->ARLEN(S04_AXI_arlen);
    mp_S04_AXI_transactor->ARSIZE(S04_AXI_arsize);
    mp_S04_AXI_transactor->ARBURST(S04_AXI_arburst);
    mp_S04_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arlock_converter");
    mp_S04_AXI_arlock_converter->vector_in(S04_AXI_arlock);
    mp_S04_AXI_arlock_converter->scalar_out(m_S04_AXI_arlock_converter_signal);
    mp_S04_AXI_transactor->ARLOCK(m_S04_AXI_arlock_converter_signal);
    mp_S04_AXI_transactor->ARCACHE(S04_AXI_arcache);
    mp_S04_AXI_transactor->ARPROT(S04_AXI_arprot);
    mp_S04_AXI_transactor->ARREGION(S04_AXI_arregion);
    mp_S04_AXI_transactor->ARQOS(S04_AXI_arqos);
    mp_S04_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arvalid_converter");
    mp_S04_AXI_arvalid_converter->vector_in(S04_AXI_arvalid);
    mp_S04_AXI_arvalid_converter->scalar_out(m_S04_AXI_arvalid_converter_signal);
    mp_S04_AXI_transactor->ARVALID(m_S04_AXI_arvalid_converter_signal);
    mp_S04_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_arready_converter");
    mp_S04_AXI_arready_converter->scalar_in(m_S04_AXI_arready_converter_signal);
    mp_S04_AXI_arready_converter->vector_out(S04_AXI_arready);
    mp_S04_AXI_transactor->ARREADY(m_S04_AXI_arready_converter_signal);
    mp_S04_AXI_transactor->RDATA(S04_AXI_rdata);
    mp_S04_AXI_transactor->RRESP(S04_AXI_rresp);
    mp_S04_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rlast_converter");
    mp_S04_AXI_rlast_converter->scalar_in(m_S04_AXI_rlast_converter_signal);
    mp_S04_AXI_rlast_converter->vector_out(S04_AXI_rlast);
    mp_S04_AXI_transactor->RLAST(m_S04_AXI_rlast_converter_signal);
    mp_S04_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rvalid_converter");
    mp_S04_AXI_rvalid_converter->scalar_in(m_S04_AXI_rvalid_converter_signal);
    mp_S04_AXI_rvalid_converter->vector_out(S04_AXI_rvalid);
    mp_S04_AXI_transactor->RVALID(m_S04_AXI_rvalid_converter_signal);
    mp_S04_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_rready_converter");
    mp_S04_AXI_rready_converter->vector_in(S04_AXI_rready);
    mp_S04_AXI_rready_converter->scalar_out(m_S04_AXI_rready_converter_signal);
    mp_S04_AXI_transactor->RREADY(m_S04_AXI_rready_converter_signal);
    mp_S04_AXI_transactor->ARID(S04_AXI_arid);
    mp_S04_AXI_transactor->ARUSER(S04_AXI_aruser);
    mp_S04_AXI_transactor->AWID(S04_AXI_awid);
    mp_S04_AXI_transactor->AWUSER(S04_AXI_awuser);
    mp_S04_AXI_transactor->BID(S04_AXI_bid);
    mp_S04_AXI_transactor->RID(S04_AXI_rid);
    mp_S04_AXI_transactor->RUSER(S04_AXI_ruser);
    mp_S04_AXI_transactor->WUSER(S04_AXI_wuser);
    mp_S04_AXI_transactor->CLK(aclk4);
    m_S04_AXI_transactor_rst_signal.write(1);
    mp_S04_AXI_transactor->RST(m_S04_AXI_transactor_rst_signal);

    // S04_AXI' transactor sockets

    mp_impl->S04_AXI_tlm_aximm_read_socket->bind(*(mp_S04_AXI_transactor->rd_socket));
    mp_impl->S04_AXI_tlm_aximm_write_socket->bind(*(mp_S04_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S05_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S05_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S05_AXI' transactor parameters
    xsc::common_cpp::properties S05_AXI_transactor_param_props;
    S05_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S05_AXI_transactor_param_props.addLong("FREQ_HZ", "320000000");
    S05_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S05_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("BUSER_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S05_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S05_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S05_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S05_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S05_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S05_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S05_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S05_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S05_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S05_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S05_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S05_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk");
    S05_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S05_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S05_AXI_transactor_param_props.addString("REGION", "0");
    S05_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S05_AXI_transactor_param_props.addString("DEST_IDS", "");
    S05_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S05_AXI_transactor_param_props.addString("REMAPS", "");
    S05_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S05_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S05_AXI_transactor_param_props.addString("CATEGORY", "ps_pmc");
    S05_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S05_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,16,18,17>("S05_AXI_transactor", S05_AXI_transactor_param_props);

    // S05_AXI' transactor ports

    mp_S05_AXI_transactor->AWADDR(S05_AXI_awaddr);
    mp_S05_AXI_transactor->AWLEN(S05_AXI_awlen);
    mp_S05_AXI_transactor->AWSIZE(S05_AXI_awsize);
    mp_S05_AXI_transactor->AWBURST(S05_AXI_awburst);
    mp_S05_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awlock_converter");
    mp_S05_AXI_awlock_converter->vector_in(S05_AXI_awlock);
    mp_S05_AXI_awlock_converter->scalar_out(m_S05_AXI_awlock_converter_signal);
    mp_S05_AXI_transactor->AWLOCK(m_S05_AXI_awlock_converter_signal);
    mp_S05_AXI_transactor->AWCACHE(S05_AXI_awcache);
    mp_S05_AXI_transactor->AWPROT(S05_AXI_awprot);
    mp_S05_AXI_transactor->AWREGION(S05_AXI_awregion);
    mp_S05_AXI_transactor->AWQOS(S05_AXI_awqos);
    mp_S05_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awvalid_converter");
    mp_S05_AXI_awvalid_converter->vector_in(S05_AXI_awvalid);
    mp_S05_AXI_awvalid_converter->scalar_out(m_S05_AXI_awvalid_converter_signal);
    mp_S05_AXI_transactor->AWVALID(m_S05_AXI_awvalid_converter_signal);
    mp_S05_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_awready_converter");
    mp_S05_AXI_awready_converter->scalar_in(m_S05_AXI_awready_converter_signal);
    mp_S05_AXI_awready_converter->vector_out(S05_AXI_awready);
    mp_S05_AXI_transactor->AWREADY(m_S05_AXI_awready_converter_signal);
    mp_S05_AXI_transactor->WDATA(S05_AXI_wdata);
    mp_S05_AXI_transactor->WSTRB(S05_AXI_wstrb);
    mp_S05_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wlast_converter");
    mp_S05_AXI_wlast_converter->vector_in(S05_AXI_wlast);
    mp_S05_AXI_wlast_converter->scalar_out(m_S05_AXI_wlast_converter_signal);
    mp_S05_AXI_transactor->WLAST(m_S05_AXI_wlast_converter_signal);
    mp_S05_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wvalid_converter");
    mp_S05_AXI_wvalid_converter->vector_in(S05_AXI_wvalid);
    mp_S05_AXI_wvalid_converter->scalar_out(m_S05_AXI_wvalid_converter_signal);
    mp_S05_AXI_transactor->WVALID(m_S05_AXI_wvalid_converter_signal);
    mp_S05_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_wready_converter");
    mp_S05_AXI_wready_converter->scalar_in(m_S05_AXI_wready_converter_signal);
    mp_S05_AXI_wready_converter->vector_out(S05_AXI_wready);
    mp_S05_AXI_transactor->WREADY(m_S05_AXI_wready_converter_signal);
    mp_S05_AXI_transactor->BRESP(S05_AXI_bresp);
    mp_S05_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_bvalid_converter");
    mp_S05_AXI_bvalid_converter->scalar_in(m_S05_AXI_bvalid_converter_signal);
    mp_S05_AXI_bvalid_converter->vector_out(S05_AXI_bvalid);
    mp_S05_AXI_transactor->BVALID(m_S05_AXI_bvalid_converter_signal);
    mp_S05_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_bready_converter");
    mp_S05_AXI_bready_converter->vector_in(S05_AXI_bready);
    mp_S05_AXI_bready_converter->scalar_out(m_S05_AXI_bready_converter_signal);
    mp_S05_AXI_transactor->BREADY(m_S05_AXI_bready_converter_signal);
    mp_S05_AXI_transactor->ARADDR(S05_AXI_araddr);
    mp_S05_AXI_transactor->ARLEN(S05_AXI_arlen);
    mp_S05_AXI_transactor->ARSIZE(S05_AXI_arsize);
    mp_S05_AXI_transactor->ARBURST(S05_AXI_arburst);
    mp_S05_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arlock_converter");
    mp_S05_AXI_arlock_converter->vector_in(S05_AXI_arlock);
    mp_S05_AXI_arlock_converter->scalar_out(m_S05_AXI_arlock_converter_signal);
    mp_S05_AXI_transactor->ARLOCK(m_S05_AXI_arlock_converter_signal);
    mp_S05_AXI_transactor->ARCACHE(S05_AXI_arcache);
    mp_S05_AXI_transactor->ARPROT(S05_AXI_arprot);
    mp_S05_AXI_transactor->ARREGION(S05_AXI_arregion);
    mp_S05_AXI_transactor->ARQOS(S05_AXI_arqos);
    mp_S05_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arvalid_converter");
    mp_S05_AXI_arvalid_converter->vector_in(S05_AXI_arvalid);
    mp_S05_AXI_arvalid_converter->scalar_out(m_S05_AXI_arvalid_converter_signal);
    mp_S05_AXI_transactor->ARVALID(m_S05_AXI_arvalid_converter_signal);
    mp_S05_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_arready_converter");
    mp_S05_AXI_arready_converter->scalar_in(m_S05_AXI_arready_converter_signal);
    mp_S05_AXI_arready_converter->vector_out(S05_AXI_arready);
    mp_S05_AXI_transactor->ARREADY(m_S05_AXI_arready_converter_signal);
    mp_S05_AXI_transactor->RDATA(S05_AXI_rdata);
    mp_S05_AXI_transactor->RRESP(S05_AXI_rresp);
    mp_S05_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rlast_converter");
    mp_S05_AXI_rlast_converter->scalar_in(m_S05_AXI_rlast_converter_signal);
    mp_S05_AXI_rlast_converter->vector_out(S05_AXI_rlast);
    mp_S05_AXI_transactor->RLAST(m_S05_AXI_rlast_converter_signal);
    mp_S05_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rvalid_converter");
    mp_S05_AXI_rvalid_converter->scalar_in(m_S05_AXI_rvalid_converter_signal);
    mp_S05_AXI_rvalid_converter->vector_out(S05_AXI_rvalid);
    mp_S05_AXI_transactor->RVALID(m_S05_AXI_rvalid_converter_signal);
    mp_S05_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_rready_converter");
    mp_S05_AXI_rready_converter->vector_in(S05_AXI_rready);
    mp_S05_AXI_rready_converter->scalar_out(m_S05_AXI_rready_converter_signal);
    mp_S05_AXI_transactor->RREADY(m_S05_AXI_rready_converter_signal);
    mp_S05_AXI_transactor->ARID(S05_AXI_arid);
    mp_S05_AXI_transactor->ARUSER(S05_AXI_aruser);
    mp_S05_AXI_transactor->AWID(S05_AXI_awid);
    mp_S05_AXI_transactor->AWUSER(S05_AXI_awuser);
    mp_S05_AXI_transactor->BID(S05_AXI_bid);
    mp_S05_AXI_transactor->BUSER(S05_AXI_buser);
    mp_S05_AXI_transactor->RID(S05_AXI_rid);
    mp_S05_AXI_transactor->RUSER(S05_AXI_ruser);
    mp_S05_AXI_transactor->WUSER(S05_AXI_wuser);
    mp_S05_AXI_transactor->CLK(aclk5);
    m_S05_AXI_transactor_rst_signal.write(1);
    mp_S05_AXI_transactor->RST(m_S05_AXI_transactor_rst_signal);

    // S05_AXI' transactor sockets

    mp_impl->S05_AXI_tlm_aximm_read_socket->bind(*(mp_S05_AXI_transactor->rd_socket));
    mp_impl->S05_AXI_tlm_aximm_write_socket->bind(*(mp_S05_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S06_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S06_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S06_AXI' transactor parameters
    xsc::common_cpp::properties S06_AXI_transactor_param_props;
    S06_AXI_transactor_param_props.addLong("DATA_WIDTH", "32");
    S06_AXI_transactor_param_props.addLong("FREQ_HZ", "100000000");
    S06_AXI_transactor_param_props.addLong("ID_WIDTH", "1");
    S06_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S06_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("RUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S06_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S06_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S06_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S06_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S06_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S06_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S06_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S06_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S06_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S06_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S06_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S06_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pl0_ref_clk");
    S06_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S06_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S06_AXI_transactor_param_props.addString("REGION", "");
    S06_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {500} write_bw {500}}");
    S06_AXI_transactor_param_props.addString("DEST_IDS", "");
    S06_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S06_AXI_transactor_param_props.addString("REMAPS", "");
    S06_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S06_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S06_AXI_transactor_param_props.addString("CATEGORY", "pl");
    S06_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S06_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<32,64,1,1,1,1,1,1>("S06_AXI_transactor", S06_AXI_transactor_param_props);

    // S06_AXI' transactor ports

    mp_S06_AXI_transactor->AWADDR(S06_AXI_awaddr);
    mp_S06_AXI_transactor->AWLEN(S06_AXI_awlen);
    mp_S06_AXI_transactor->AWSIZE(S06_AXI_awsize);
    mp_S06_AXI_transactor->AWBURST(S06_AXI_awburst);
    mp_S06_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awlock_converter");
    mp_S06_AXI_awlock_converter->vector_in(S06_AXI_awlock);
    mp_S06_AXI_awlock_converter->scalar_out(m_S06_AXI_awlock_converter_signal);
    mp_S06_AXI_transactor->AWLOCK(m_S06_AXI_awlock_converter_signal);
    mp_S06_AXI_transactor->AWCACHE(S06_AXI_awcache);
    mp_S06_AXI_transactor->AWPROT(S06_AXI_awprot);
    mp_S06_AXI_transactor->AWREGION(S06_AXI_awregion);
    mp_S06_AXI_transactor->AWQOS(S06_AXI_awqos);
    mp_S06_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awvalid_converter");
    mp_S06_AXI_awvalid_converter->vector_in(S06_AXI_awvalid);
    mp_S06_AXI_awvalid_converter->scalar_out(m_S06_AXI_awvalid_converter_signal);
    mp_S06_AXI_transactor->AWVALID(m_S06_AXI_awvalid_converter_signal);
    mp_S06_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_awready_converter");
    mp_S06_AXI_awready_converter->scalar_in(m_S06_AXI_awready_converter_signal);
    mp_S06_AXI_awready_converter->vector_out(S06_AXI_awready);
    mp_S06_AXI_transactor->AWREADY(m_S06_AXI_awready_converter_signal);
    mp_S06_AXI_transactor->WDATA(S06_AXI_wdata);
    mp_S06_AXI_transactor->WSTRB(S06_AXI_wstrb);
    mp_S06_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wlast_converter");
    mp_S06_AXI_wlast_converter->vector_in(S06_AXI_wlast);
    mp_S06_AXI_wlast_converter->scalar_out(m_S06_AXI_wlast_converter_signal);
    mp_S06_AXI_transactor->WLAST(m_S06_AXI_wlast_converter_signal);
    mp_S06_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wvalid_converter");
    mp_S06_AXI_wvalid_converter->vector_in(S06_AXI_wvalid);
    mp_S06_AXI_wvalid_converter->scalar_out(m_S06_AXI_wvalid_converter_signal);
    mp_S06_AXI_transactor->WVALID(m_S06_AXI_wvalid_converter_signal);
    mp_S06_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_wready_converter");
    mp_S06_AXI_wready_converter->scalar_in(m_S06_AXI_wready_converter_signal);
    mp_S06_AXI_wready_converter->vector_out(S06_AXI_wready);
    mp_S06_AXI_transactor->WREADY(m_S06_AXI_wready_converter_signal);
    mp_S06_AXI_transactor->BRESP(S06_AXI_bresp);
    mp_S06_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_bvalid_converter");
    mp_S06_AXI_bvalid_converter->scalar_in(m_S06_AXI_bvalid_converter_signal);
    mp_S06_AXI_bvalid_converter->vector_out(S06_AXI_bvalid);
    mp_S06_AXI_transactor->BVALID(m_S06_AXI_bvalid_converter_signal);
    mp_S06_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_bready_converter");
    mp_S06_AXI_bready_converter->vector_in(S06_AXI_bready);
    mp_S06_AXI_bready_converter->scalar_out(m_S06_AXI_bready_converter_signal);
    mp_S06_AXI_transactor->BREADY(m_S06_AXI_bready_converter_signal);
    mp_S06_AXI_transactor->ARADDR(S06_AXI_araddr);
    mp_S06_AXI_transactor->ARLEN(S06_AXI_arlen);
    mp_S06_AXI_transactor->ARSIZE(S06_AXI_arsize);
    mp_S06_AXI_transactor->ARBURST(S06_AXI_arburst);
    mp_S06_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arlock_converter");
    mp_S06_AXI_arlock_converter->vector_in(S06_AXI_arlock);
    mp_S06_AXI_arlock_converter->scalar_out(m_S06_AXI_arlock_converter_signal);
    mp_S06_AXI_transactor->ARLOCK(m_S06_AXI_arlock_converter_signal);
    mp_S06_AXI_transactor->ARCACHE(S06_AXI_arcache);
    mp_S06_AXI_transactor->ARPROT(S06_AXI_arprot);
    mp_S06_AXI_transactor->ARREGION(S06_AXI_arregion);
    mp_S06_AXI_transactor->ARQOS(S06_AXI_arqos);
    mp_S06_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arvalid_converter");
    mp_S06_AXI_arvalid_converter->vector_in(S06_AXI_arvalid);
    mp_S06_AXI_arvalid_converter->scalar_out(m_S06_AXI_arvalid_converter_signal);
    mp_S06_AXI_transactor->ARVALID(m_S06_AXI_arvalid_converter_signal);
    mp_S06_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_arready_converter");
    mp_S06_AXI_arready_converter->scalar_in(m_S06_AXI_arready_converter_signal);
    mp_S06_AXI_arready_converter->vector_out(S06_AXI_arready);
    mp_S06_AXI_transactor->ARREADY(m_S06_AXI_arready_converter_signal);
    mp_S06_AXI_transactor->RDATA(S06_AXI_rdata);
    mp_S06_AXI_transactor->RRESP(S06_AXI_rresp);
    mp_S06_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rlast_converter");
    mp_S06_AXI_rlast_converter->scalar_in(m_S06_AXI_rlast_converter_signal);
    mp_S06_AXI_rlast_converter->vector_out(S06_AXI_rlast);
    mp_S06_AXI_transactor->RLAST(m_S06_AXI_rlast_converter_signal);
    mp_S06_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rvalid_converter");
    mp_S06_AXI_rvalid_converter->scalar_in(m_S06_AXI_rvalid_converter_signal);
    mp_S06_AXI_rvalid_converter->vector_out(S06_AXI_rvalid);
    mp_S06_AXI_transactor->RVALID(m_S06_AXI_rvalid_converter_signal);
    mp_S06_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_rready_converter");
    mp_S06_AXI_rready_converter->vector_in(S06_AXI_rready);
    mp_S06_AXI_rready_converter->scalar_out(m_S06_AXI_rready_converter_signal);
    mp_S06_AXI_transactor->RREADY(m_S06_AXI_rready_converter_signal);
    mp_S06_AXI_transactor->ARID(S06_AXI_arid);
    mp_S06_AXI_transactor->AWID(S06_AXI_awid);
    mp_S06_AXI_transactor->BID(S06_AXI_bid);
    mp_S06_AXI_transactor->RID(S06_AXI_rid);
    mp_S06_AXI_transactor->CLK(aclk6);
    m_S06_AXI_transactor_rst_signal.write(1);
    mp_S06_AXI_transactor->RST(m_S06_AXI_transactor_rst_signal);

    // S06_AXI' transactor sockets

    mp_impl->S06_AXI_tlm_aximm_read_socket->bind(*(mp_S06_AXI_transactor->rd_socket));
    mp_impl->S06_AXI_tlm_aximm_write_socket->bind(*(mp_S06_AXI_transactor->wr_socket));
  }
  else
  {
  }

}

#endif // XILINX_SIMULATOR




#ifdef XM_SYSTEMC
bd_soc_usart_axi_noc_0_0::bd_soc_usart_axi_noc_0_0(const sc_core::sc_module_name& nm) : bd_soc_usart_axi_noc_0_0_sc(nm), S00_AXI_awaddr("S00_AXI_awaddr"), S00_AXI_awlen("S00_AXI_awlen"), S00_AXI_awsize("S00_AXI_awsize"), S00_AXI_awburst("S00_AXI_awburst"), S00_AXI_awlock("S00_AXI_awlock"), S00_AXI_awcache("S00_AXI_awcache"), S00_AXI_awprot("S00_AXI_awprot"), S00_AXI_awregion("S00_AXI_awregion"), S00_AXI_awqos("S00_AXI_awqos"), S00_AXI_awvalid("S00_AXI_awvalid"), S00_AXI_awready("S00_AXI_awready"), S00_AXI_wdata("S00_AXI_wdata"), S00_AXI_wstrb("S00_AXI_wstrb"), S00_AXI_wlast("S00_AXI_wlast"), S00_AXI_wvalid("S00_AXI_wvalid"), S00_AXI_wready("S00_AXI_wready"), S00_AXI_bresp("S00_AXI_bresp"), S00_AXI_bvalid("S00_AXI_bvalid"), S00_AXI_bready("S00_AXI_bready"), S00_AXI_araddr("S00_AXI_araddr"), S00_AXI_arlen("S00_AXI_arlen"), S00_AXI_arsize("S00_AXI_arsize"), S00_AXI_arburst("S00_AXI_arburst"), S00_AXI_arlock("S00_AXI_arlock"), S00_AXI_arcache("S00_AXI_arcache"), S00_AXI_arprot("S00_AXI_arprot"), S00_AXI_arregion("S00_AXI_arregion"), S00_AXI_arqos("S00_AXI_arqos"), S00_AXI_arvalid("S00_AXI_arvalid"), S00_AXI_arready("S00_AXI_arready"), S00_AXI_rdata("S00_AXI_rdata"), S00_AXI_rresp("S00_AXI_rresp"), S00_AXI_rlast("S00_AXI_rlast"), S00_AXI_rvalid("S00_AXI_rvalid"), S00_AXI_rready("S00_AXI_rready"), S01_AXI_awaddr("S01_AXI_awaddr"), S01_AXI_awlen("S01_AXI_awlen"), S01_AXI_awsize("S01_AXI_awsize"), S01_AXI_awburst("S01_AXI_awburst"), S01_AXI_awlock("S01_AXI_awlock"), S01_AXI_awcache("S01_AXI_awcache"), S01_AXI_awprot("S01_AXI_awprot"), S01_AXI_awregion("S01_AXI_awregion"), S01_AXI_awqos("S01_AXI_awqos"), S01_AXI_awvalid("S01_AXI_awvalid"), S01_AXI_awready("S01_AXI_awready"), S01_AXI_wdata("S01_AXI_wdata"), S01_AXI_wstrb("S01_AXI_wstrb"), S01_AXI_wlast("S01_AXI_wlast"), S01_AXI_wvalid("S01_AXI_wvalid"), S01_AXI_wready("S01_AXI_wready"), S01_AXI_bresp("S01_AXI_bresp"), S01_AXI_bvalid("S01_AXI_bvalid"), S01_AXI_bready("S01_AXI_bready"), S01_AXI_araddr("S01_AXI_araddr"), S01_AXI_arlen("S01_AXI_arlen"), S01_AXI_arsize("S01_AXI_arsize"), S01_AXI_arburst("S01_AXI_arburst"), S01_AXI_arlock("S01_AXI_arlock"), S01_AXI_arcache("S01_AXI_arcache"), S01_AXI_arprot("S01_AXI_arprot"), S01_AXI_arregion("S01_AXI_arregion"), S01_AXI_arqos("S01_AXI_arqos"), S01_AXI_arvalid("S01_AXI_arvalid"), S01_AXI_arready("S01_AXI_arready"), S01_AXI_rdata("S01_AXI_rdata"), S01_AXI_rresp("S01_AXI_rresp"), S01_AXI_rlast("S01_AXI_rlast"), S01_AXI_rvalid("S01_AXI_rvalid"), S01_AXI_rready("S01_AXI_rready"), S02_AXI_awaddr("S02_AXI_awaddr"), S02_AXI_awlen("S02_AXI_awlen"), S02_AXI_awsize("S02_AXI_awsize"), S02_AXI_awburst("S02_AXI_awburst"), S02_AXI_awlock("S02_AXI_awlock"), S02_AXI_awcache("S02_AXI_awcache"), S02_AXI_awprot("S02_AXI_awprot"), S02_AXI_awregion("S02_AXI_awregion"), S02_AXI_awqos("S02_AXI_awqos"), S02_AXI_awvalid("S02_AXI_awvalid"), S02_AXI_awready("S02_AXI_awready"), S02_AXI_wdata("S02_AXI_wdata"), S02_AXI_wstrb("S02_AXI_wstrb"), S02_AXI_wlast("S02_AXI_wlast"), S02_AXI_wvalid("S02_AXI_wvalid"), S02_AXI_wready("S02_AXI_wready"), S02_AXI_bresp("S02_AXI_bresp"), S02_AXI_bvalid("S02_AXI_bvalid"), S02_AXI_bready("S02_AXI_bready"), S02_AXI_araddr("S02_AXI_araddr"), S02_AXI_arlen("S02_AXI_arlen"), S02_AXI_arsize("S02_AXI_arsize"), S02_AXI_arburst("S02_AXI_arburst"), S02_AXI_arlock("S02_AXI_arlock"), S02_AXI_arcache("S02_AXI_arcache"), S02_AXI_arprot("S02_AXI_arprot"), S02_AXI_arregion("S02_AXI_arregion"), S02_AXI_arqos("S02_AXI_arqos"), S02_AXI_arvalid("S02_AXI_arvalid"), S02_AXI_arready("S02_AXI_arready"), S02_AXI_rdata("S02_AXI_rdata"), S02_AXI_rresp("S02_AXI_rresp"), S02_AXI_rlast("S02_AXI_rlast"), S02_AXI_rvalid("S02_AXI_rvalid"), S02_AXI_rready("S02_AXI_rready"), S03_AXI_awaddr("S03_AXI_awaddr"), S03_AXI_awlen("S03_AXI_awlen"), S03_AXI_awsize("S03_AXI_awsize"), S03_AXI_awburst("S03_AXI_awburst"), S03_AXI_awlock("S03_AXI_awlock"), S03_AXI_awcache("S03_AXI_awcache"), S03_AXI_awprot("S03_AXI_awprot"), S03_AXI_awregion("S03_AXI_awregion"), S03_AXI_awqos("S03_AXI_awqos"), S03_AXI_awvalid("S03_AXI_awvalid"), S03_AXI_awready("S03_AXI_awready"), S03_AXI_wdata("S03_AXI_wdata"), S03_AXI_wstrb("S03_AXI_wstrb"), S03_AXI_wlast("S03_AXI_wlast"), S03_AXI_wvalid("S03_AXI_wvalid"), S03_AXI_wready("S03_AXI_wready"), S03_AXI_bresp("S03_AXI_bresp"), S03_AXI_bvalid("S03_AXI_bvalid"), S03_AXI_bready("S03_AXI_bready"), S03_AXI_araddr("S03_AXI_araddr"), S03_AXI_arlen("S03_AXI_arlen"), S03_AXI_arsize("S03_AXI_arsize"), S03_AXI_arburst("S03_AXI_arburst"), S03_AXI_arlock("S03_AXI_arlock"), S03_AXI_arcache("S03_AXI_arcache"), S03_AXI_arprot("S03_AXI_arprot"), S03_AXI_arregion("S03_AXI_arregion"), S03_AXI_arqos("S03_AXI_arqos"), S03_AXI_arvalid("S03_AXI_arvalid"), S03_AXI_arready("S03_AXI_arready"), S03_AXI_rdata("S03_AXI_rdata"), S03_AXI_rresp("S03_AXI_rresp"), S03_AXI_rlast("S03_AXI_rlast"), S03_AXI_rvalid("S03_AXI_rvalid"), S03_AXI_rready("S03_AXI_rready"), S04_AXI_awaddr("S04_AXI_awaddr"), S04_AXI_awlen("S04_AXI_awlen"), S04_AXI_awsize("S04_AXI_awsize"), S04_AXI_awburst("S04_AXI_awburst"), S04_AXI_awlock("S04_AXI_awlock"), S04_AXI_awcache("S04_AXI_awcache"), S04_AXI_awprot("S04_AXI_awprot"), S04_AXI_awregion("S04_AXI_awregion"), S04_AXI_awqos("S04_AXI_awqos"), S04_AXI_awvalid("S04_AXI_awvalid"), S04_AXI_awready("S04_AXI_awready"), S04_AXI_wdata("S04_AXI_wdata"), S04_AXI_wstrb("S04_AXI_wstrb"), S04_AXI_wlast("S04_AXI_wlast"), S04_AXI_wvalid("S04_AXI_wvalid"), S04_AXI_wready("S04_AXI_wready"), S04_AXI_bresp("S04_AXI_bresp"), S04_AXI_bvalid("S04_AXI_bvalid"), S04_AXI_bready("S04_AXI_bready"), S04_AXI_araddr("S04_AXI_araddr"), S04_AXI_arlen("S04_AXI_arlen"), S04_AXI_arsize("S04_AXI_arsize"), S04_AXI_arburst("S04_AXI_arburst"), S04_AXI_arlock("S04_AXI_arlock"), S04_AXI_arcache("S04_AXI_arcache"), S04_AXI_arprot("S04_AXI_arprot"), S04_AXI_arregion("S04_AXI_arregion"), S04_AXI_arqos("S04_AXI_arqos"), S04_AXI_arvalid("S04_AXI_arvalid"), S04_AXI_arready("S04_AXI_arready"), S04_AXI_rdata("S04_AXI_rdata"), S04_AXI_rresp("S04_AXI_rresp"), S04_AXI_rlast("S04_AXI_rlast"), S04_AXI_rvalid("S04_AXI_rvalid"), S04_AXI_rready("S04_AXI_rready"), S05_AXI_awaddr("S05_AXI_awaddr"), S05_AXI_awlen("S05_AXI_awlen"), S05_AXI_awsize("S05_AXI_awsize"), S05_AXI_awburst("S05_AXI_awburst"), S05_AXI_awlock("S05_AXI_awlock"), S05_AXI_awcache("S05_AXI_awcache"), S05_AXI_awprot("S05_AXI_awprot"), S05_AXI_awregion("S05_AXI_awregion"), S05_AXI_awqos("S05_AXI_awqos"), S05_AXI_awvalid("S05_AXI_awvalid"), S05_AXI_awready("S05_AXI_awready"), S05_AXI_wdata("S05_AXI_wdata"), S05_AXI_wstrb("S05_AXI_wstrb"), S05_AXI_wlast("S05_AXI_wlast"), S05_AXI_wvalid("S05_AXI_wvalid"), S05_AXI_wready("S05_AXI_wready"), S05_AXI_bresp("S05_AXI_bresp"), S05_AXI_bvalid("S05_AXI_bvalid"), S05_AXI_bready("S05_AXI_bready"), S05_AXI_araddr("S05_AXI_araddr"), S05_AXI_arlen("S05_AXI_arlen"), S05_AXI_arsize("S05_AXI_arsize"), S05_AXI_arburst("S05_AXI_arburst"), S05_AXI_arlock("S05_AXI_arlock"), S05_AXI_arcache("S05_AXI_arcache"), S05_AXI_arprot("S05_AXI_arprot"), S05_AXI_arregion("S05_AXI_arregion"), S05_AXI_arqos("S05_AXI_arqos"), S05_AXI_arvalid("S05_AXI_arvalid"), S05_AXI_arready("S05_AXI_arready"), S05_AXI_rdata("S05_AXI_rdata"), S05_AXI_rresp("S05_AXI_rresp"), S05_AXI_rlast("S05_AXI_rlast"), S05_AXI_rvalid("S05_AXI_rvalid"), S05_AXI_rready("S05_AXI_rready"), S06_AXI_awaddr("S06_AXI_awaddr"), S06_AXI_awlen("S06_AXI_awlen"), S06_AXI_awsize("S06_AXI_awsize"), S06_AXI_awburst("S06_AXI_awburst"), S06_AXI_awlock("S06_AXI_awlock"), S06_AXI_awcache("S06_AXI_awcache"), S06_AXI_awprot("S06_AXI_awprot"), S06_AXI_awregion("S06_AXI_awregion"), S06_AXI_awqos("S06_AXI_awqos"), S06_AXI_awvalid("S06_AXI_awvalid"), S06_AXI_awready("S06_AXI_awready"), S06_AXI_wdata("S06_AXI_wdata"), S06_AXI_wstrb("S06_AXI_wstrb"), S06_AXI_wlast("S06_AXI_wlast"), S06_AXI_wvalid("S06_AXI_wvalid"), S06_AXI_wready("S06_AXI_wready"), S06_AXI_bresp("S06_AXI_bresp"), S06_AXI_bvalid("S06_AXI_bvalid"), S06_AXI_bready("S06_AXI_bready"), S06_AXI_araddr("S06_AXI_araddr"), S06_AXI_arlen("S06_AXI_arlen"), S06_AXI_arsize("S06_AXI_arsize"), S06_AXI_arburst("S06_AXI_arburst"), S06_AXI_arlock("S06_AXI_arlock"), S06_AXI_arcache("S06_AXI_arcache"), S06_AXI_arprot("S06_AXI_arprot"), S06_AXI_arregion("S06_AXI_arregion"), S06_AXI_arqos("S06_AXI_arqos"), S06_AXI_arvalid("S06_AXI_arvalid"), S06_AXI_arready("S06_AXI_arready"), S06_AXI_rdata("S06_AXI_rdata"), S06_AXI_rresp("S06_AXI_rresp"), S06_AXI_rlast("S06_AXI_rlast"), S06_AXI_rvalid("S06_AXI_rvalid"), S06_AXI_rready("S06_AXI_rready"), aclk0("aclk0"), aclk1("aclk1"), aclk2("aclk2"), aclk3("aclk3"), aclk4("aclk4"), aclk5("aclk5"), aclk6("aclk6"), sys_clk0_clk_p("sys_clk0_clk_p"), sys_clk0_clk_n("sys_clk0_clk_n"), CH0_DDR4_0_dq("CH0_DDR4_0_dq"), CH0_DDR4_0_dqs_t("CH0_DDR4_0_dqs_t"), CH0_DDR4_0_dqs_c("CH0_DDR4_0_dqs_c"), CH0_DDR4_0_adr("CH0_DDR4_0_adr"), CH0_DDR4_0_ba("CH0_DDR4_0_ba"), CH0_DDR4_0_bg("CH0_DDR4_0_bg"), CH0_DDR4_0_act_n("CH0_DDR4_0_act_n"), CH0_DDR4_0_reset_n("CH0_DDR4_0_reset_n"), CH0_DDR4_0_ck_t("CH0_DDR4_0_ck_t"), CH0_DDR4_0_ck_c("CH0_DDR4_0_ck_c"), CH0_DDR4_0_cke("CH0_DDR4_0_cke"), CH0_DDR4_0_cs_n("CH0_DDR4_0_cs_n"), CH0_DDR4_0_dm_n("CH0_DDR4_0_dm_n"), CH0_DDR4_0_odt("CH0_DDR4_0_odt"), S05_AXI_arid("S05_AXI_arid"), S05_AXI_aruser("S05_AXI_aruser"), S05_AXI_awid("S05_AXI_awid"), S05_AXI_awuser("S05_AXI_awuser"), S05_AXI_bid("S05_AXI_bid"), S05_AXI_buser("S05_AXI_buser"), S05_AXI_rid("S05_AXI_rid"), S05_AXI_ruser("S05_AXI_ruser"), S05_AXI_wuser("S05_AXI_wuser"), S03_AXI_arid("S03_AXI_arid"), S03_AXI_aruser("S03_AXI_aruser"), S03_AXI_awid("S03_AXI_awid"), S03_AXI_awuser("S03_AXI_awuser"), S03_AXI_bid("S03_AXI_bid"), S03_AXI_rid("S03_AXI_rid"), S03_AXI_ruser("S03_AXI_ruser"), S03_AXI_wuser("S03_AXI_wuser"), S04_AXI_arid("S04_AXI_arid"), S04_AXI_aruser("S04_AXI_aruser"), S04_AXI_awid("S04_AXI_awid"), S04_AXI_awuser("S04_AXI_awuser"), S04_AXI_bid("S04_AXI_bid"), S04_AXI_rid("S04_AXI_rid"), S04_AXI_ruser("S04_AXI_ruser"), S04_AXI_wuser("S04_AXI_wuser"), S02_AXI_arid("S02_AXI_arid"), S02_AXI_aruser("S02_AXI_aruser"), S02_AXI_awid("S02_AXI_awid"), S02_AXI_awuser("S02_AXI_awuser"), S02_AXI_bid("S02_AXI_bid"), S02_AXI_rid("S02_AXI_rid"), S02_AXI_ruser("S02_AXI_ruser"), S02_AXI_wuser("S02_AXI_wuser"), S06_AXI_arid("S06_AXI_arid"), S06_AXI_awid("S06_AXI_awid"), S06_AXI_bid("S06_AXI_bid"), S06_AXI_rid("S06_AXI_rid"), S01_AXI_arid("S01_AXI_arid"), S01_AXI_aruser("S01_AXI_aruser"), S01_AXI_awid("S01_AXI_awid"), S01_AXI_awuser("S01_AXI_awuser"), S01_AXI_bid("S01_AXI_bid"), S01_AXI_rid("S01_AXI_rid"), S01_AXI_ruser("S01_AXI_ruser"), S01_AXI_wuser("S01_AXI_wuser"), S00_AXI_arid("S00_AXI_arid"), S00_AXI_aruser("S00_AXI_aruser"), S00_AXI_awid("S00_AXI_awid"), S00_AXI_awuser("S00_AXI_awuser"), S00_AXI_bid("S00_AXI_bid"), S00_AXI_rid("S00_AXI_rid"), S00_AXI_ruser("S00_AXI_ruser"), S00_AXI_wuser("S00_AXI_wuser")
{

  // initialize pins
  mp_impl->aclk0(aclk0);
  mp_impl->aclk1(aclk1);
  mp_impl->aclk2(aclk2);
  mp_impl->aclk3(aclk3);
  mp_impl->aclk4(aclk4);
  mp_impl->aclk5(aclk5);
  mp_impl->aclk6(aclk6);
  mp_impl->sys_clk0_clk_p(sys_clk0_clk_p);
  mp_impl->sys_clk0_clk_n(sys_clk0_clk_n);
  mp_impl->CH0_DDR4_0_dq(CH0_DDR4_0_dq);
  mp_impl->CH0_DDR4_0_dqs_t(CH0_DDR4_0_dqs_t);
  mp_impl->CH0_DDR4_0_dqs_c(CH0_DDR4_0_dqs_c);
  mp_impl->CH0_DDR4_0_adr(CH0_DDR4_0_adr);
  mp_impl->CH0_DDR4_0_ba(CH0_DDR4_0_ba);
  mp_impl->CH0_DDR4_0_bg(CH0_DDR4_0_bg);
  mp_impl->CH0_DDR4_0_act_n(CH0_DDR4_0_act_n);
  mp_impl->CH0_DDR4_0_reset_n(CH0_DDR4_0_reset_n);
  mp_impl->CH0_DDR4_0_ck_t(CH0_DDR4_0_ck_t);
  mp_impl->CH0_DDR4_0_ck_c(CH0_DDR4_0_ck_c);
  mp_impl->CH0_DDR4_0_cke(CH0_DDR4_0_cke);
  mp_impl->CH0_DDR4_0_cs_n(CH0_DDR4_0_cs_n);
  mp_impl->CH0_DDR4_0_dm_n(CH0_DDR4_0_dm_n);
  mp_impl->CH0_DDR4_0_odt(CH0_DDR4_0_odt);

  // initialize transactors
  mp_S00_AXI_transactor = NULL;
  mp_S00_AXI_awlock_converter = NULL;
  mp_S00_AXI_awvalid_converter = NULL;
  mp_S00_AXI_awready_converter = NULL;
  mp_S00_AXI_wlast_converter = NULL;
  mp_S00_AXI_wvalid_converter = NULL;
  mp_S00_AXI_wready_converter = NULL;
  mp_S00_AXI_bvalid_converter = NULL;
  mp_S00_AXI_bready_converter = NULL;
  mp_S00_AXI_arlock_converter = NULL;
  mp_S00_AXI_arvalid_converter = NULL;
  mp_S00_AXI_arready_converter = NULL;
  mp_S00_AXI_rlast_converter = NULL;
  mp_S00_AXI_rvalid_converter = NULL;
  mp_S00_AXI_rready_converter = NULL;
  mp_S01_AXI_transactor = NULL;
  mp_S01_AXI_awlock_converter = NULL;
  mp_S01_AXI_awvalid_converter = NULL;
  mp_S01_AXI_awready_converter = NULL;
  mp_S01_AXI_wlast_converter = NULL;
  mp_S01_AXI_wvalid_converter = NULL;
  mp_S01_AXI_wready_converter = NULL;
  mp_S01_AXI_bvalid_converter = NULL;
  mp_S01_AXI_bready_converter = NULL;
  mp_S01_AXI_arlock_converter = NULL;
  mp_S01_AXI_arvalid_converter = NULL;
  mp_S01_AXI_arready_converter = NULL;
  mp_S01_AXI_rlast_converter = NULL;
  mp_S01_AXI_rvalid_converter = NULL;
  mp_S01_AXI_rready_converter = NULL;
  mp_S02_AXI_transactor = NULL;
  mp_S02_AXI_awlock_converter = NULL;
  mp_S02_AXI_awvalid_converter = NULL;
  mp_S02_AXI_awready_converter = NULL;
  mp_S02_AXI_wlast_converter = NULL;
  mp_S02_AXI_wvalid_converter = NULL;
  mp_S02_AXI_wready_converter = NULL;
  mp_S02_AXI_bvalid_converter = NULL;
  mp_S02_AXI_bready_converter = NULL;
  mp_S02_AXI_arlock_converter = NULL;
  mp_S02_AXI_arvalid_converter = NULL;
  mp_S02_AXI_arready_converter = NULL;
  mp_S02_AXI_rlast_converter = NULL;
  mp_S02_AXI_rvalid_converter = NULL;
  mp_S02_AXI_rready_converter = NULL;
  mp_S03_AXI_transactor = NULL;
  mp_S03_AXI_awlock_converter = NULL;
  mp_S03_AXI_awvalid_converter = NULL;
  mp_S03_AXI_awready_converter = NULL;
  mp_S03_AXI_wlast_converter = NULL;
  mp_S03_AXI_wvalid_converter = NULL;
  mp_S03_AXI_wready_converter = NULL;
  mp_S03_AXI_bvalid_converter = NULL;
  mp_S03_AXI_bready_converter = NULL;
  mp_S03_AXI_arlock_converter = NULL;
  mp_S03_AXI_arvalid_converter = NULL;
  mp_S03_AXI_arready_converter = NULL;
  mp_S03_AXI_rlast_converter = NULL;
  mp_S03_AXI_rvalid_converter = NULL;
  mp_S03_AXI_rready_converter = NULL;
  mp_S04_AXI_transactor = NULL;
  mp_S04_AXI_awlock_converter = NULL;
  mp_S04_AXI_awvalid_converter = NULL;
  mp_S04_AXI_awready_converter = NULL;
  mp_S04_AXI_wlast_converter = NULL;
  mp_S04_AXI_wvalid_converter = NULL;
  mp_S04_AXI_wready_converter = NULL;
  mp_S04_AXI_bvalid_converter = NULL;
  mp_S04_AXI_bready_converter = NULL;
  mp_S04_AXI_arlock_converter = NULL;
  mp_S04_AXI_arvalid_converter = NULL;
  mp_S04_AXI_arready_converter = NULL;
  mp_S04_AXI_rlast_converter = NULL;
  mp_S04_AXI_rvalid_converter = NULL;
  mp_S04_AXI_rready_converter = NULL;
  mp_S05_AXI_transactor = NULL;
  mp_S05_AXI_awlock_converter = NULL;
  mp_S05_AXI_awvalid_converter = NULL;
  mp_S05_AXI_awready_converter = NULL;
  mp_S05_AXI_wlast_converter = NULL;
  mp_S05_AXI_wvalid_converter = NULL;
  mp_S05_AXI_wready_converter = NULL;
  mp_S05_AXI_bvalid_converter = NULL;
  mp_S05_AXI_bready_converter = NULL;
  mp_S05_AXI_arlock_converter = NULL;
  mp_S05_AXI_arvalid_converter = NULL;
  mp_S05_AXI_arready_converter = NULL;
  mp_S05_AXI_rlast_converter = NULL;
  mp_S05_AXI_rvalid_converter = NULL;
  mp_S05_AXI_rready_converter = NULL;
  mp_S06_AXI_transactor = NULL;
  mp_S06_AXI_awlock_converter = NULL;
  mp_S06_AXI_awvalid_converter = NULL;
  mp_S06_AXI_awready_converter = NULL;
  mp_S06_AXI_wlast_converter = NULL;
  mp_S06_AXI_wvalid_converter = NULL;
  mp_S06_AXI_wready_converter = NULL;
  mp_S06_AXI_bvalid_converter = NULL;
  mp_S06_AXI_bready_converter = NULL;
  mp_S06_AXI_arlock_converter = NULL;
  mp_S06_AXI_arvalid_converter = NULL;
  mp_S06_AXI_arready_converter = NULL;
  mp_S06_AXI_rlast_converter = NULL;
  mp_S06_AXI_rvalid_converter = NULL;
  mp_S06_AXI_rready_converter = NULL;

  // initialize socket stubs

}

void bd_soc_usart_axi_noc_0_0::before_end_of_elaboration()
{
  // configure 'S00_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S00_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S00_AXI' transactor parameters
    xsc::common_cpp::properties S00_AXI_transactor_param_props;
    S00_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S00_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S00_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S00_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S00_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S00_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S00_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S00_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S00_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S00_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S00_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S00_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S00_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S00_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S00_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S00_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S00_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S00_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");
    S00_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S00_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S00_AXI_transactor_param_props.addString("REGION", "0");
    S00_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S00_AXI_transactor_param_props.addString("DEST_IDS", "");
    S00_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S00_AXI_transactor_param_props.addString("REMAPS", "");
    S00_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S00_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S00_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S00_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S00_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S00_AXI_transactor", S00_AXI_transactor_param_props);

    // S00_AXI' transactor ports

    mp_S00_AXI_transactor->AWADDR(S00_AXI_awaddr);
    mp_S00_AXI_transactor->AWLEN(S00_AXI_awlen);
    mp_S00_AXI_transactor->AWSIZE(S00_AXI_awsize);
    mp_S00_AXI_transactor->AWBURST(S00_AXI_awburst);
    mp_S00_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awlock_converter");
    mp_S00_AXI_awlock_converter->vector_in(S00_AXI_awlock);
    mp_S00_AXI_awlock_converter->scalar_out(m_S00_AXI_awlock_converter_signal);
    mp_S00_AXI_transactor->AWLOCK(m_S00_AXI_awlock_converter_signal);
    mp_S00_AXI_transactor->AWCACHE(S00_AXI_awcache);
    mp_S00_AXI_transactor->AWPROT(S00_AXI_awprot);
    mp_S00_AXI_transactor->AWREGION(S00_AXI_awregion);
    mp_S00_AXI_transactor->AWQOS(S00_AXI_awqos);
    mp_S00_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awvalid_converter");
    mp_S00_AXI_awvalid_converter->vector_in(S00_AXI_awvalid);
    mp_S00_AXI_awvalid_converter->scalar_out(m_S00_AXI_awvalid_converter_signal);
    mp_S00_AXI_transactor->AWVALID(m_S00_AXI_awvalid_converter_signal);
    mp_S00_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_awready_converter");
    mp_S00_AXI_awready_converter->scalar_in(m_S00_AXI_awready_converter_signal);
    mp_S00_AXI_awready_converter->vector_out(S00_AXI_awready);
    mp_S00_AXI_transactor->AWREADY(m_S00_AXI_awready_converter_signal);
    mp_S00_AXI_transactor->WDATA(S00_AXI_wdata);
    mp_S00_AXI_transactor->WSTRB(S00_AXI_wstrb);
    mp_S00_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wlast_converter");
    mp_S00_AXI_wlast_converter->vector_in(S00_AXI_wlast);
    mp_S00_AXI_wlast_converter->scalar_out(m_S00_AXI_wlast_converter_signal);
    mp_S00_AXI_transactor->WLAST(m_S00_AXI_wlast_converter_signal);
    mp_S00_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wvalid_converter");
    mp_S00_AXI_wvalid_converter->vector_in(S00_AXI_wvalid);
    mp_S00_AXI_wvalid_converter->scalar_out(m_S00_AXI_wvalid_converter_signal);
    mp_S00_AXI_transactor->WVALID(m_S00_AXI_wvalid_converter_signal);
    mp_S00_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_wready_converter");
    mp_S00_AXI_wready_converter->scalar_in(m_S00_AXI_wready_converter_signal);
    mp_S00_AXI_wready_converter->vector_out(S00_AXI_wready);
    mp_S00_AXI_transactor->WREADY(m_S00_AXI_wready_converter_signal);
    mp_S00_AXI_transactor->BRESP(S00_AXI_bresp);
    mp_S00_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_bvalid_converter");
    mp_S00_AXI_bvalid_converter->scalar_in(m_S00_AXI_bvalid_converter_signal);
    mp_S00_AXI_bvalid_converter->vector_out(S00_AXI_bvalid);
    mp_S00_AXI_transactor->BVALID(m_S00_AXI_bvalid_converter_signal);
    mp_S00_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_bready_converter");
    mp_S00_AXI_bready_converter->vector_in(S00_AXI_bready);
    mp_S00_AXI_bready_converter->scalar_out(m_S00_AXI_bready_converter_signal);
    mp_S00_AXI_transactor->BREADY(m_S00_AXI_bready_converter_signal);
    mp_S00_AXI_transactor->ARADDR(S00_AXI_araddr);
    mp_S00_AXI_transactor->ARLEN(S00_AXI_arlen);
    mp_S00_AXI_transactor->ARSIZE(S00_AXI_arsize);
    mp_S00_AXI_transactor->ARBURST(S00_AXI_arburst);
    mp_S00_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arlock_converter");
    mp_S00_AXI_arlock_converter->vector_in(S00_AXI_arlock);
    mp_S00_AXI_arlock_converter->scalar_out(m_S00_AXI_arlock_converter_signal);
    mp_S00_AXI_transactor->ARLOCK(m_S00_AXI_arlock_converter_signal);
    mp_S00_AXI_transactor->ARCACHE(S00_AXI_arcache);
    mp_S00_AXI_transactor->ARPROT(S00_AXI_arprot);
    mp_S00_AXI_transactor->ARREGION(S00_AXI_arregion);
    mp_S00_AXI_transactor->ARQOS(S00_AXI_arqos);
    mp_S00_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arvalid_converter");
    mp_S00_AXI_arvalid_converter->vector_in(S00_AXI_arvalid);
    mp_S00_AXI_arvalid_converter->scalar_out(m_S00_AXI_arvalid_converter_signal);
    mp_S00_AXI_transactor->ARVALID(m_S00_AXI_arvalid_converter_signal);
    mp_S00_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_arready_converter");
    mp_S00_AXI_arready_converter->scalar_in(m_S00_AXI_arready_converter_signal);
    mp_S00_AXI_arready_converter->vector_out(S00_AXI_arready);
    mp_S00_AXI_transactor->ARREADY(m_S00_AXI_arready_converter_signal);
    mp_S00_AXI_transactor->RDATA(S00_AXI_rdata);
    mp_S00_AXI_transactor->RRESP(S00_AXI_rresp);
    mp_S00_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rlast_converter");
    mp_S00_AXI_rlast_converter->scalar_in(m_S00_AXI_rlast_converter_signal);
    mp_S00_AXI_rlast_converter->vector_out(S00_AXI_rlast);
    mp_S00_AXI_transactor->RLAST(m_S00_AXI_rlast_converter_signal);
    mp_S00_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rvalid_converter");
    mp_S00_AXI_rvalid_converter->scalar_in(m_S00_AXI_rvalid_converter_signal);
    mp_S00_AXI_rvalid_converter->vector_out(S00_AXI_rvalid);
    mp_S00_AXI_transactor->RVALID(m_S00_AXI_rvalid_converter_signal);
    mp_S00_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_rready_converter");
    mp_S00_AXI_rready_converter->vector_in(S00_AXI_rready);
    mp_S00_AXI_rready_converter->scalar_out(m_S00_AXI_rready_converter_signal);
    mp_S00_AXI_transactor->RREADY(m_S00_AXI_rready_converter_signal);
    mp_S00_AXI_transactor->ARID(S00_AXI_arid);
    mp_S00_AXI_transactor->ARUSER(S00_AXI_aruser);
    mp_S00_AXI_transactor->AWID(S00_AXI_awid);
    mp_S00_AXI_transactor->AWUSER(S00_AXI_awuser);
    mp_S00_AXI_transactor->BID(S00_AXI_bid);
    mp_S00_AXI_transactor->RID(S00_AXI_rid);
    mp_S00_AXI_transactor->RUSER(S00_AXI_ruser);
    mp_S00_AXI_transactor->WUSER(S00_AXI_wuser);
    mp_S00_AXI_transactor->CLK(aclk0);
    m_S00_AXI_transactor_rst_signal.write(1);
    mp_S00_AXI_transactor->RST(m_S00_AXI_transactor_rst_signal);

    // S00_AXI' transactor sockets

    mp_impl->S00_AXI_tlm_aximm_read_socket->bind(*(mp_S00_AXI_transactor->rd_socket));
    mp_impl->S00_AXI_tlm_aximm_write_socket->bind(*(mp_S00_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S01_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S01_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S01_AXI' transactor parameters
    xsc::common_cpp::properties S01_AXI_transactor_param_props;
    S01_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S01_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S01_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S01_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S01_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S01_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S01_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S01_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S01_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S01_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S01_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S01_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S01_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S01_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S01_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S01_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S01_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S01_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk");
    S01_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S01_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S01_AXI_transactor_param_props.addString("REGION", "0");
    S01_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S01_AXI_transactor_param_props.addString("DEST_IDS", "");
    S01_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S01_AXI_transactor_param_props.addString("REMAPS", "");
    S01_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S01_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S01_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S01_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S01_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S01_AXI_transactor", S01_AXI_transactor_param_props);

    // S01_AXI' transactor ports

    mp_S01_AXI_transactor->AWADDR(S01_AXI_awaddr);
    mp_S01_AXI_transactor->AWLEN(S01_AXI_awlen);
    mp_S01_AXI_transactor->AWSIZE(S01_AXI_awsize);
    mp_S01_AXI_transactor->AWBURST(S01_AXI_awburst);
    mp_S01_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awlock_converter");
    mp_S01_AXI_awlock_converter->vector_in(S01_AXI_awlock);
    mp_S01_AXI_awlock_converter->scalar_out(m_S01_AXI_awlock_converter_signal);
    mp_S01_AXI_transactor->AWLOCK(m_S01_AXI_awlock_converter_signal);
    mp_S01_AXI_transactor->AWCACHE(S01_AXI_awcache);
    mp_S01_AXI_transactor->AWPROT(S01_AXI_awprot);
    mp_S01_AXI_transactor->AWREGION(S01_AXI_awregion);
    mp_S01_AXI_transactor->AWQOS(S01_AXI_awqos);
    mp_S01_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awvalid_converter");
    mp_S01_AXI_awvalid_converter->vector_in(S01_AXI_awvalid);
    mp_S01_AXI_awvalid_converter->scalar_out(m_S01_AXI_awvalid_converter_signal);
    mp_S01_AXI_transactor->AWVALID(m_S01_AXI_awvalid_converter_signal);
    mp_S01_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_awready_converter");
    mp_S01_AXI_awready_converter->scalar_in(m_S01_AXI_awready_converter_signal);
    mp_S01_AXI_awready_converter->vector_out(S01_AXI_awready);
    mp_S01_AXI_transactor->AWREADY(m_S01_AXI_awready_converter_signal);
    mp_S01_AXI_transactor->WDATA(S01_AXI_wdata);
    mp_S01_AXI_transactor->WSTRB(S01_AXI_wstrb);
    mp_S01_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wlast_converter");
    mp_S01_AXI_wlast_converter->vector_in(S01_AXI_wlast);
    mp_S01_AXI_wlast_converter->scalar_out(m_S01_AXI_wlast_converter_signal);
    mp_S01_AXI_transactor->WLAST(m_S01_AXI_wlast_converter_signal);
    mp_S01_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wvalid_converter");
    mp_S01_AXI_wvalid_converter->vector_in(S01_AXI_wvalid);
    mp_S01_AXI_wvalid_converter->scalar_out(m_S01_AXI_wvalid_converter_signal);
    mp_S01_AXI_transactor->WVALID(m_S01_AXI_wvalid_converter_signal);
    mp_S01_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_wready_converter");
    mp_S01_AXI_wready_converter->scalar_in(m_S01_AXI_wready_converter_signal);
    mp_S01_AXI_wready_converter->vector_out(S01_AXI_wready);
    mp_S01_AXI_transactor->WREADY(m_S01_AXI_wready_converter_signal);
    mp_S01_AXI_transactor->BRESP(S01_AXI_bresp);
    mp_S01_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_bvalid_converter");
    mp_S01_AXI_bvalid_converter->scalar_in(m_S01_AXI_bvalid_converter_signal);
    mp_S01_AXI_bvalid_converter->vector_out(S01_AXI_bvalid);
    mp_S01_AXI_transactor->BVALID(m_S01_AXI_bvalid_converter_signal);
    mp_S01_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_bready_converter");
    mp_S01_AXI_bready_converter->vector_in(S01_AXI_bready);
    mp_S01_AXI_bready_converter->scalar_out(m_S01_AXI_bready_converter_signal);
    mp_S01_AXI_transactor->BREADY(m_S01_AXI_bready_converter_signal);
    mp_S01_AXI_transactor->ARADDR(S01_AXI_araddr);
    mp_S01_AXI_transactor->ARLEN(S01_AXI_arlen);
    mp_S01_AXI_transactor->ARSIZE(S01_AXI_arsize);
    mp_S01_AXI_transactor->ARBURST(S01_AXI_arburst);
    mp_S01_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arlock_converter");
    mp_S01_AXI_arlock_converter->vector_in(S01_AXI_arlock);
    mp_S01_AXI_arlock_converter->scalar_out(m_S01_AXI_arlock_converter_signal);
    mp_S01_AXI_transactor->ARLOCK(m_S01_AXI_arlock_converter_signal);
    mp_S01_AXI_transactor->ARCACHE(S01_AXI_arcache);
    mp_S01_AXI_transactor->ARPROT(S01_AXI_arprot);
    mp_S01_AXI_transactor->ARREGION(S01_AXI_arregion);
    mp_S01_AXI_transactor->ARQOS(S01_AXI_arqos);
    mp_S01_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arvalid_converter");
    mp_S01_AXI_arvalid_converter->vector_in(S01_AXI_arvalid);
    mp_S01_AXI_arvalid_converter->scalar_out(m_S01_AXI_arvalid_converter_signal);
    mp_S01_AXI_transactor->ARVALID(m_S01_AXI_arvalid_converter_signal);
    mp_S01_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_arready_converter");
    mp_S01_AXI_arready_converter->scalar_in(m_S01_AXI_arready_converter_signal);
    mp_S01_AXI_arready_converter->vector_out(S01_AXI_arready);
    mp_S01_AXI_transactor->ARREADY(m_S01_AXI_arready_converter_signal);
    mp_S01_AXI_transactor->RDATA(S01_AXI_rdata);
    mp_S01_AXI_transactor->RRESP(S01_AXI_rresp);
    mp_S01_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rlast_converter");
    mp_S01_AXI_rlast_converter->scalar_in(m_S01_AXI_rlast_converter_signal);
    mp_S01_AXI_rlast_converter->vector_out(S01_AXI_rlast);
    mp_S01_AXI_transactor->RLAST(m_S01_AXI_rlast_converter_signal);
    mp_S01_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rvalid_converter");
    mp_S01_AXI_rvalid_converter->scalar_in(m_S01_AXI_rvalid_converter_signal);
    mp_S01_AXI_rvalid_converter->vector_out(S01_AXI_rvalid);
    mp_S01_AXI_transactor->RVALID(m_S01_AXI_rvalid_converter_signal);
    mp_S01_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_rready_converter");
    mp_S01_AXI_rready_converter->vector_in(S01_AXI_rready);
    mp_S01_AXI_rready_converter->scalar_out(m_S01_AXI_rready_converter_signal);
    mp_S01_AXI_transactor->RREADY(m_S01_AXI_rready_converter_signal);
    mp_S01_AXI_transactor->ARID(S01_AXI_arid);
    mp_S01_AXI_transactor->ARUSER(S01_AXI_aruser);
    mp_S01_AXI_transactor->AWID(S01_AXI_awid);
    mp_S01_AXI_transactor->AWUSER(S01_AXI_awuser);
    mp_S01_AXI_transactor->BID(S01_AXI_bid);
    mp_S01_AXI_transactor->RID(S01_AXI_rid);
    mp_S01_AXI_transactor->RUSER(S01_AXI_ruser);
    mp_S01_AXI_transactor->WUSER(S01_AXI_wuser);
    mp_S01_AXI_transactor->CLK(aclk1);
    m_S01_AXI_transactor_rst_signal.write(1);
    mp_S01_AXI_transactor->RST(m_S01_AXI_transactor_rst_signal);

    // S01_AXI' transactor sockets

    mp_impl->S01_AXI_tlm_aximm_read_socket->bind(*(mp_S01_AXI_transactor->rd_socket));
    mp_impl->S01_AXI_tlm_aximm_write_socket->bind(*(mp_S01_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S02_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S02_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S02_AXI' transactor parameters
    xsc::common_cpp::properties S02_AXI_transactor_param_props;
    S02_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S02_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S02_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S02_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S02_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S02_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S02_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S02_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S02_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S02_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S02_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S02_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S02_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S02_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S02_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S02_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S02_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S02_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk");
    S02_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S02_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S02_AXI_transactor_param_props.addString("REGION", "0");
    S02_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S02_AXI_transactor_param_props.addString("DEST_IDS", "");
    S02_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S02_AXI_transactor_param_props.addString("REMAPS", "");
    S02_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S02_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S02_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S02_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S02_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S02_AXI_transactor", S02_AXI_transactor_param_props);

    // S02_AXI' transactor ports

    mp_S02_AXI_transactor->AWADDR(S02_AXI_awaddr);
    mp_S02_AXI_transactor->AWLEN(S02_AXI_awlen);
    mp_S02_AXI_transactor->AWSIZE(S02_AXI_awsize);
    mp_S02_AXI_transactor->AWBURST(S02_AXI_awburst);
    mp_S02_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awlock_converter");
    mp_S02_AXI_awlock_converter->vector_in(S02_AXI_awlock);
    mp_S02_AXI_awlock_converter->scalar_out(m_S02_AXI_awlock_converter_signal);
    mp_S02_AXI_transactor->AWLOCK(m_S02_AXI_awlock_converter_signal);
    mp_S02_AXI_transactor->AWCACHE(S02_AXI_awcache);
    mp_S02_AXI_transactor->AWPROT(S02_AXI_awprot);
    mp_S02_AXI_transactor->AWREGION(S02_AXI_awregion);
    mp_S02_AXI_transactor->AWQOS(S02_AXI_awqos);
    mp_S02_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awvalid_converter");
    mp_S02_AXI_awvalid_converter->vector_in(S02_AXI_awvalid);
    mp_S02_AXI_awvalid_converter->scalar_out(m_S02_AXI_awvalid_converter_signal);
    mp_S02_AXI_transactor->AWVALID(m_S02_AXI_awvalid_converter_signal);
    mp_S02_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_awready_converter");
    mp_S02_AXI_awready_converter->scalar_in(m_S02_AXI_awready_converter_signal);
    mp_S02_AXI_awready_converter->vector_out(S02_AXI_awready);
    mp_S02_AXI_transactor->AWREADY(m_S02_AXI_awready_converter_signal);
    mp_S02_AXI_transactor->WDATA(S02_AXI_wdata);
    mp_S02_AXI_transactor->WSTRB(S02_AXI_wstrb);
    mp_S02_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wlast_converter");
    mp_S02_AXI_wlast_converter->vector_in(S02_AXI_wlast);
    mp_S02_AXI_wlast_converter->scalar_out(m_S02_AXI_wlast_converter_signal);
    mp_S02_AXI_transactor->WLAST(m_S02_AXI_wlast_converter_signal);
    mp_S02_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wvalid_converter");
    mp_S02_AXI_wvalid_converter->vector_in(S02_AXI_wvalid);
    mp_S02_AXI_wvalid_converter->scalar_out(m_S02_AXI_wvalid_converter_signal);
    mp_S02_AXI_transactor->WVALID(m_S02_AXI_wvalid_converter_signal);
    mp_S02_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_wready_converter");
    mp_S02_AXI_wready_converter->scalar_in(m_S02_AXI_wready_converter_signal);
    mp_S02_AXI_wready_converter->vector_out(S02_AXI_wready);
    mp_S02_AXI_transactor->WREADY(m_S02_AXI_wready_converter_signal);
    mp_S02_AXI_transactor->BRESP(S02_AXI_bresp);
    mp_S02_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_bvalid_converter");
    mp_S02_AXI_bvalid_converter->scalar_in(m_S02_AXI_bvalid_converter_signal);
    mp_S02_AXI_bvalid_converter->vector_out(S02_AXI_bvalid);
    mp_S02_AXI_transactor->BVALID(m_S02_AXI_bvalid_converter_signal);
    mp_S02_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_bready_converter");
    mp_S02_AXI_bready_converter->vector_in(S02_AXI_bready);
    mp_S02_AXI_bready_converter->scalar_out(m_S02_AXI_bready_converter_signal);
    mp_S02_AXI_transactor->BREADY(m_S02_AXI_bready_converter_signal);
    mp_S02_AXI_transactor->ARADDR(S02_AXI_araddr);
    mp_S02_AXI_transactor->ARLEN(S02_AXI_arlen);
    mp_S02_AXI_transactor->ARSIZE(S02_AXI_arsize);
    mp_S02_AXI_transactor->ARBURST(S02_AXI_arburst);
    mp_S02_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arlock_converter");
    mp_S02_AXI_arlock_converter->vector_in(S02_AXI_arlock);
    mp_S02_AXI_arlock_converter->scalar_out(m_S02_AXI_arlock_converter_signal);
    mp_S02_AXI_transactor->ARLOCK(m_S02_AXI_arlock_converter_signal);
    mp_S02_AXI_transactor->ARCACHE(S02_AXI_arcache);
    mp_S02_AXI_transactor->ARPROT(S02_AXI_arprot);
    mp_S02_AXI_transactor->ARREGION(S02_AXI_arregion);
    mp_S02_AXI_transactor->ARQOS(S02_AXI_arqos);
    mp_S02_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arvalid_converter");
    mp_S02_AXI_arvalid_converter->vector_in(S02_AXI_arvalid);
    mp_S02_AXI_arvalid_converter->scalar_out(m_S02_AXI_arvalid_converter_signal);
    mp_S02_AXI_transactor->ARVALID(m_S02_AXI_arvalid_converter_signal);
    mp_S02_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_arready_converter");
    mp_S02_AXI_arready_converter->scalar_in(m_S02_AXI_arready_converter_signal);
    mp_S02_AXI_arready_converter->vector_out(S02_AXI_arready);
    mp_S02_AXI_transactor->ARREADY(m_S02_AXI_arready_converter_signal);
    mp_S02_AXI_transactor->RDATA(S02_AXI_rdata);
    mp_S02_AXI_transactor->RRESP(S02_AXI_rresp);
    mp_S02_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rlast_converter");
    mp_S02_AXI_rlast_converter->scalar_in(m_S02_AXI_rlast_converter_signal);
    mp_S02_AXI_rlast_converter->vector_out(S02_AXI_rlast);
    mp_S02_AXI_transactor->RLAST(m_S02_AXI_rlast_converter_signal);
    mp_S02_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rvalid_converter");
    mp_S02_AXI_rvalid_converter->scalar_in(m_S02_AXI_rvalid_converter_signal);
    mp_S02_AXI_rvalid_converter->vector_out(S02_AXI_rvalid);
    mp_S02_AXI_transactor->RVALID(m_S02_AXI_rvalid_converter_signal);
    mp_S02_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_rready_converter");
    mp_S02_AXI_rready_converter->vector_in(S02_AXI_rready);
    mp_S02_AXI_rready_converter->scalar_out(m_S02_AXI_rready_converter_signal);
    mp_S02_AXI_transactor->RREADY(m_S02_AXI_rready_converter_signal);
    mp_S02_AXI_transactor->ARID(S02_AXI_arid);
    mp_S02_AXI_transactor->ARUSER(S02_AXI_aruser);
    mp_S02_AXI_transactor->AWID(S02_AXI_awid);
    mp_S02_AXI_transactor->AWUSER(S02_AXI_awuser);
    mp_S02_AXI_transactor->BID(S02_AXI_bid);
    mp_S02_AXI_transactor->RID(S02_AXI_rid);
    mp_S02_AXI_transactor->RUSER(S02_AXI_ruser);
    mp_S02_AXI_transactor->WUSER(S02_AXI_wuser);
    mp_S02_AXI_transactor->CLK(aclk2);
    m_S02_AXI_transactor_rst_signal.write(1);
    mp_S02_AXI_transactor->RST(m_S02_AXI_transactor_rst_signal);

    // S02_AXI' transactor sockets

    mp_impl->S02_AXI_tlm_aximm_read_socket->bind(*(mp_S02_AXI_transactor->rd_socket));
    mp_impl->S02_AXI_tlm_aximm_write_socket->bind(*(mp_S02_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S03_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S03_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S03_AXI' transactor parameters
    xsc::common_cpp::properties S03_AXI_transactor_param_props;
    S03_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S03_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S03_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S03_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S03_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S03_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S03_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S03_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S03_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S03_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S03_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S03_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S03_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S03_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S03_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S03_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S03_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S03_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk");
    S03_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S03_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S03_AXI_transactor_param_props.addString("REGION", "0");
    S03_AXI_transactor_param_props.addString("CONNECTIONS", "MC_1 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S03_AXI_transactor_param_props.addString("DEST_IDS", "");
    S03_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S03_AXI_transactor_param_props.addString("REMAPS", "");
    S03_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S03_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S03_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S03_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S03_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S03_AXI_transactor", S03_AXI_transactor_param_props);

    // S03_AXI' transactor ports

    mp_S03_AXI_transactor->AWADDR(S03_AXI_awaddr);
    mp_S03_AXI_transactor->AWLEN(S03_AXI_awlen);
    mp_S03_AXI_transactor->AWSIZE(S03_AXI_awsize);
    mp_S03_AXI_transactor->AWBURST(S03_AXI_awburst);
    mp_S03_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awlock_converter");
    mp_S03_AXI_awlock_converter->vector_in(S03_AXI_awlock);
    mp_S03_AXI_awlock_converter->scalar_out(m_S03_AXI_awlock_converter_signal);
    mp_S03_AXI_transactor->AWLOCK(m_S03_AXI_awlock_converter_signal);
    mp_S03_AXI_transactor->AWCACHE(S03_AXI_awcache);
    mp_S03_AXI_transactor->AWPROT(S03_AXI_awprot);
    mp_S03_AXI_transactor->AWREGION(S03_AXI_awregion);
    mp_S03_AXI_transactor->AWQOS(S03_AXI_awqos);
    mp_S03_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awvalid_converter");
    mp_S03_AXI_awvalid_converter->vector_in(S03_AXI_awvalid);
    mp_S03_AXI_awvalid_converter->scalar_out(m_S03_AXI_awvalid_converter_signal);
    mp_S03_AXI_transactor->AWVALID(m_S03_AXI_awvalid_converter_signal);
    mp_S03_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_awready_converter");
    mp_S03_AXI_awready_converter->scalar_in(m_S03_AXI_awready_converter_signal);
    mp_S03_AXI_awready_converter->vector_out(S03_AXI_awready);
    mp_S03_AXI_transactor->AWREADY(m_S03_AXI_awready_converter_signal);
    mp_S03_AXI_transactor->WDATA(S03_AXI_wdata);
    mp_S03_AXI_transactor->WSTRB(S03_AXI_wstrb);
    mp_S03_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wlast_converter");
    mp_S03_AXI_wlast_converter->vector_in(S03_AXI_wlast);
    mp_S03_AXI_wlast_converter->scalar_out(m_S03_AXI_wlast_converter_signal);
    mp_S03_AXI_transactor->WLAST(m_S03_AXI_wlast_converter_signal);
    mp_S03_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wvalid_converter");
    mp_S03_AXI_wvalid_converter->vector_in(S03_AXI_wvalid);
    mp_S03_AXI_wvalid_converter->scalar_out(m_S03_AXI_wvalid_converter_signal);
    mp_S03_AXI_transactor->WVALID(m_S03_AXI_wvalid_converter_signal);
    mp_S03_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_wready_converter");
    mp_S03_AXI_wready_converter->scalar_in(m_S03_AXI_wready_converter_signal);
    mp_S03_AXI_wready_converter->vector_out(S03_AXI_wready);
    mp_S03_AXI_transactor->WREADY(m_S03_AXI_wready_converter_signal);
    mp_S03_AXI_transactor->BRESP(S03_AXI_bresp);
    mp_S03_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_bvalid_converter");
    mp_S03_AXI_bvalid_converter->scalar_in(m_S03_AXI_bvalid_converter_signal);
    mp_S03_AXI_bvalid_converter->vector_out(S03_AXI_bvalid);
    mp_S03_AXI_transactor->BVALID(m_S03_AXI_bvalid_converter_signal);
    mp_S03_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_bready_converter");
    mp_S03_AXI_bready_converter->vector_in(S03_AXI_bready);
    mp_S03_AXI_bready_converter->scalar_out(m_S03_AXI_bready_converter_signal);
    mp_S03_AXI_transactor->BREADY(m_S03_AXI_bready_converter_signal);
    mp_S03_AXI_transactor->ARADDR(S03_AXI_araddr);
    mp_S03_AXI_transactor->ARLEN(S03_AXI_arlen);
    mp_S03_AXI_transactor->ARSIZE(S03_AXI_arsize);
    mp_S03_AXI_transactor->ARBURST(S03_AXI_arburst);
    mp_S03_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arlock_converter");
    mp_S03_AXI_arlock_converter->vector_in(S03_AXI_arlock);
    mp_S03_AXI_arlock_converter->scalar_out(m_S03_AXI_arlock_converter_signal);
    mp_S03_AXI_transactor->ARLOCK(m_S03_AXI_arlock_converter_signal);
    mp_S03_AXI_transactor->ARCACHE(S03_AXI_arcache);
    mp_S03_AXI_transactor->ARPROT(S03_AXI_arprot);
    mp_S03_AXI_transactor->ARREGION(S03_AXI_arregion);
    mp_S03_AXI_transactor->ARQOS(S03_AXI_arqos);
    mp_S03_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arvalid_converter");
    mp_S03_AXI_arvalid_converter->vector_in(S03_AXI_arvalid);
    mp_S03_AXI_arvalid_converter->scalar_out(m_S03_AXI_arvalid_converter_signal);
    mp_S03_AXI_transactor->ARVALID(m_S03_AXI_arvalid_converter_signal);
    mp_S03_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_arready_converter");
    mp_S03_AXI_arready_converter->scalar_in(m_S03_AXI_arready_converter_signal);
    mp_S03_AXI_arready_converter->vector_out(S03_AXI_arready);
    mp_S03_AXI_transactor->ARREADY(m_S03_AXI_arready_converter_signal);
    mp_S03_AXI_transactor->RDATA(S03_AXI_rdata);
    mp_S03_AXI_transactor->RRESP(S03_AXI_rresp);
    mp_S03_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rlast_converter");
    mp_S03_AXI_rlast_converter->scalar_in(m_S03_AXI_rlast_converter_signal);
    mp_S03_AXI_rlast_converter->vector_out(S03_AXI_rlast);
    mp_S03_AXI_transactor->RLAST(m_S03_AXI_rlast_converter_signal);
    mp_S03_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rvalid_converter");
    mp_S03_AXI_rvalid_converter->scalar_in(m_S03_AXI_rvalid_converter_signal);
    mp_S03_AXI_rvalid_converter->vector_out(S03_AXI_rvalid);
    mp_S03_AXI_transactor->RVALID(m_S03_AXI_rvalid_converter_signal);
    mp_S03_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_rready_converter");
    mp_S03_AXI_rready_converter->vector_in(S03_AXI_rready);
    mp_S03_AXI_rready_converter->scalar_out(m_S03_AXI_rready_converter_signal);
    mp_S03_AXI_transactor->RREADY(m_S03_AXI_rready_converter_signal);
    mp_S03_AXI_transactor->ARID(S03_AXI_arid);
    mp_S03_AXI_transactor->ARUSER(S03_AXI_aruser);
    mp_S03_AXI_transactor->AWID(S03_AXI_awid);
    mp_S03_AXI_transactor->AWUSER(S03_AXI_awuser);
    mp_S03_AXI_transactor->BID(S03_AXI_bid);
    mp_S03_AXI_transactor->RID(S03_AXI_rid);
    mp_S03_AXI_transactor->RUSER(S03_AXI_ruser);
    mp_S03_AXI_transactor->WUSER(S03_AXI_wuser);
    mp_S03_AXI_transactor->CLK(aclk3);
    m_S03_AXI_transactor_rst_signal.write(1);
    mp_S03_AXI_transactor->RST(m_S03_AXI_transactor_rst_signal);

    // S03_AXI' transactor sockets

    mp_impl->S03_AXI_tlm_aximm_read_socket->bind(*(mp_S03_AXI_transactor->rd_socket));
    mp_impl->S03_AXI_tlm_aximm_write_socket->bind(*(mp_S03_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S04_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S04_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S04_AXI' transactor parameters
    xsc::common_cpp::properties S04_AXI_transactor_param_props;
    S04_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S04_AXI_transactor_param_props.addLong("FREQ_HZ", "400000000");
    S04_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S04_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S04_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S04_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S04_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S04_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S04_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S04_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S04_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S04_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S04_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S04_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S04_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S04_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S04_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S04_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_lpd_axi_noc_clk");
    S04_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S04_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S04_AXI_transactor_param_props.addString("REGION", "0");
    S04_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S04_AXI_transactor_param_props.addString("DEST_IDS", "");
    S04_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S04_AXI_transactor_param_props.addString("REMAPS", "");
    S04_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S04_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S04_AXI_transactor_param_props.addString("CATEGORY", "ps_rpu");
    S04_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S04_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S04_AXI_transactor", S04_AXI_transactor_param_props);

    // S04_AXI' transactor ports

    mp_S04_AXI_transactor->AWADDR(S04_AXI_awaddr);
    mp_S04_AXI_transactor->AWLEN(S04_AXI_awlen);
    mp_S04_AXI_transactor->AWSIZE(S04_AXI_awsize);
    mp_S04_AXI_transactor->AWBURST(S04_AXI_awburst);
    mp_S04_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awlock_converter");
    mp_S04_AXI_awlock_converter->vector_in(S04_AXI_awlock);
    mp_S04_AXI_awlock_converter->scalar_out(m_S04_AXI_awlock_converter_signal);
    mp_S04_AXI_transactor->AWLOCK(m_S04_AXI_awlock_converter_signal);
    mp_S04_AXI_transactor->AWCACHE(S04_AXI_awcache);
    mp_S04_AXI_transactor->AWPROT(S04_AXI_awprot);
    mp_S04_AXI_transactor->AWREGION(S04_AXI_awregion);
    mp_S04_AXI_transactor->AWQOS(S04_AXI_awqos);
    mp_S04_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awvalid_converter");
    mp_S04_AXI_awvalid_converter->vector_in(S04_AXI_awvalid);
    mp_S04_AXI_awvalid_converter->scalar_out(m_S04_AXI_awvalid_converter_signal);
    mp_S04_AXI_transactor->AWVALID(m_S04_AXI_awvalid_converter_signal);
    mp_S04_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_awready_converter");
    mp_S04_AXI_awready_converter->scalar_in(m_S04_AXI_awready_converter_signal);
    mp_S04_AXI_awready_converter->vector_out(S04_AXI_awready);
    mp_S04_AXI_transactor->AWREADY(m_S04_AXI_awready_converter_signal);
    mp_S04_AXI_transactor->WDATA(S04_AXI_wdata);
    mp_S04_AXI_transactor->WSTRB(S04_AXI_wstrb);
    mp_S04_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wlast_converter");
    mp_S04_AXI_wlast_converter->vector_in(S04_AXI_wlast);
    mp_S04_AXI_wlast_converter->scalar_out(m_S04_AXI_wlast_converter_signal);
    mp_S04_AXI_transactor->WLAST(m_S04_AXI_wlast_converter_signal);
    mp_S04_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wvalid_converter");
    mp_S04_AXI_wvalid_converter->vector_in(S04_AXI_wvalid);
    mp_S04_AXI_wvalid_converter->scalar_out(m_S04_AXI_wvalid_converter_signal);
    mp_S04_AXI_transactor->WVALID(m_S04_AXI_wvalid_converter_signal);
    mp_S04_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_wready_converter");
    mp_S04_AXI_wready_converter->scalar_in(m_S04_AXI_wready_converter_signal);
    mp_S04_AXI_wready_converter->vector_out(S04_AXI_wready);
    mp_S04_AXI_transactor->WREADY(m_S04_AXI_wready_converter_signal);
    mp_S04_AXI_transactor->BRESP(S04_AXI_bresp);
    mp_S04_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_bvalid_converter");
    mp_S04_AXI_bvalid_converter->scalar_in(m_S04_AXI_bvalid_converter_signal);
    mp_S04_AXI_bvalid_converter->vector_out(S04_AXI_bvalid);
    mp_S04_AXI_transactor->BVALID(m_S04_AXI_bvalid_converter_signal);
    mp_S04_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_bready_converter");
    mp_S04_AXI_bready_converter->vector_in(S04_AXI_bready);
    mp_S04_AXI_bready_converter->scalar_out(m_S04_AXI_bready_converter_signal);
    mp_S04_AXI_transactor->BREADY(m_S04_AXI_bready_converter_signal);
    mp_S04_AXI_transactor->ARADDR(S04_AXI_araddr);
    mp_S04_AXI_transactor->ARLEN(S04_AXI_arlen);
    mp_S04_AXI_transactor->ARSIZE(S04_AXI_arsize);
    mp_S04_AXI_transactor->ARBURST(S04_AXI_arburst);
    mp_S04_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arlock_converter");
    mp_S04_AXI_arlock_converter->vector_in(S04_AXI_arlock);
    mp_S04_AXI_arlock_converter->scalar_out(m_S04_AXI_arlock_converter_signal);
    mp_S04_AXI_transactor->ARLOCK(m_S04_AXI_arlock_converter_signal);
    mp_S04_AXI_transactor->ARCACHE(S04_AXI_arcache);
    mp_S04_AXI_transactor->ARPROT(S04_AXI_arprot);
    mp_S04_AXI_transactor->ARREGION(S04_AXI_arregion);
    mp_S04_AXI_transactor->ARQOS(S04_AXI_arqos);
    mp_S04_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arvalid_converter");
    mp_S04_AXI_arvalid_converter->vector_in(S04_AXI_arvalid);
    mp_S04_AXI_arvalid_converter->scalar_out(m_S04_AXI_arvalid_converter_signal);
    mp_S04_AXI_transactor->ARVALID(m_S04_AXI_arvalid_converter_signal);
    mp_S04_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_arready_converter");
    mp_S04_AXI_arready_converter->scalar_in(m_S04_AXI_arready_converter_signal);
    mp_S04_AXI_arready_converter->vector_out(S04_AXI_arready);
    mp_S04_AXI_transactor->ARREADY(m_S04_AXI_arready_converter_signal);
    mp_S04_AXI_transactor->RDATA(S04_AXI_rdata);
    mp_S04_AXI_transactor->RRESP(S04_AXI_rresp);
    mp_S04_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rlast_converter");
    mp_S04_AXI_rlast_converter->scalar_in(m_S04_AXI_rlast_converter_signal);
    mp_S04_AXI_rlast_converter->vector_out(S04_AXI_rlast);
    mp_S04_AXI_transactor->RLAST(m_S04_AXI_rlast_converter_signal);
    mp_S04_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rvalid_converter");
    mp_S04_AXI_rvalid_converter->scalar_in(m_S04_AXI_rvalid_converter_signal);
    mp_S04_AXI_rvalid_converter->vector_out(S04_AXI_rvalid);
    mp_S04_AXI_transactor->RVALID(m_S04_AXI_rvalid_converter_signal);
    mp_S04_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_rready_converter");
    mp_S04_AXI_rready_converter->vector_in(S04_AXI_rready);
    mp_S04_AXI_rready_converter->scalar_out(m_S04_AXI_rready_converter_signal);
    mp_S04_AXI_transactor->RREADY(m_S04_AXI_rready_converter_signal);
    mp_S04_AXI_transactor->ARID(S04_AXI_arid);
    mp_S04_AXI_transactor->ARUSER(S04_AXI_aruser);
    mp_S04_AXI_transactor->AWID(S04_AXI_awid);
    mp_S04_AXI_transactor->AWUSER(S04_AXI_awuser);
    mp_S04_AXI_transactor->BID(S04_AXI_bid);
    mp_S04_AXI_transactor->RID(S04_AXI_rid);
    mp_S04_AXI_transactor->RUSER(S04_AXI_ruser);
    mp_S04_AXI_transactor->WUSER(S04_AXI_wuser);
    mp_S04_AXI_transactor->CLK(aclk4);
    m_S04_AXI_transactor_rst_signal.write(1);
    mp_S04_AXI_transactor->RST(m_S04_AXI_transactor_rst_signal);

    // S04_AXI' transactor sockets

    mp_impl->S04_AXI_tlm_aximm_read_socket->bind(*(mp_S04_AXI_transactor->rd_socket));
    mp_impl->S04_AXI_tlm_aximm_write_socket->bind(*(mp_S04_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S05_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S05_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S05_AXI' transactor parameters
    xsc::common_cpp::properties S05_AXI_transactor_param_props;
    S05_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S05_AXI_transactor_param_props.addLong("FREQ_HZ", "320000000");
    S05_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S05_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("BUSER_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S05_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S05_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S05_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S05_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S05_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S05_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S05_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S05_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S05_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S05_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S05_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S05_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk");
    S05_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S05_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S05_AXI_transactor_param_props.addString("REGION", "0");
    S05_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S05_AXI_transactor_param_props.addString("DEST_IDS", "");
    S05_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S05_AXI_transactor_param_props.addString("REMAPS", "");
    S05_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S05_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S05_AXI_transactor_param_props.addString("CATEGORY", "ps_pmc");
    S05_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S05_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,16,18,17>("S05_AXI_transactor", S05_AXI_transactor_param_props);

    // S05_AXI' transactor ports

    mp_S05_AXI_transactor->AWADDR(S05_AXI_awaddr);
    mp_S05_AXI_transactor->AWLEN(S05_AXI_awlen);
    mp_S05_AXI_transactor->AWSIZE(S05_AXI_awsize);
    mp_S05_AXI_transactor->AWBURST(S05_AXI_awburst);
    mp_S05_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awlock_converter");
    mp_S05_AXI_awlock_converter->vector_in(S05_AXI_awlock);
    mp_S05_AXI_awlock_converter->scalar_out(m_S05_AXI_awlock_converter_signal);
    mp_S05_AXI_transactor->AWLOCK(m_S05_AXI_awlock_converter_signal);
    mp_S05_AXI_transactor->AWCACHE(S05_AXI_awcache);
    mp_S05_AXI_transactor->AWPROT(S05_AXI_awprot);
    mp_S05_AXI_transactor->AWREGION(S05_AXI_awregion);
    mp_S05_AXI_transactor->AWQOS(S05_AXI_awqos);
    mp_S05_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awvalid_converter");
    mp_S05_AXI_awvalid_converter->vector_in(S05_AXI_awvalid);
    mp_S05_AXI_awvalid_converter->scalar_out(m_S05_AXI_awvalid_converter_signal);
    mp_S05_AXI_transactor->AWVALID(m_S05_AXI_awvalid_converter_signal);
    mp_S05_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_awready_converter");
    mp_S05_AXI_awready_converter->scalar_in(m_S05_AXI_awready_converter_signal);
    mp_S05_AXI_awready_converter->vector_out(S05_AXI_awready);
    mp_S05_AXI_transactor->AWREADY(m_S05_AXI_awready_converter_signal);
    mp_S05_AXI_transactor->WDATA(S05_AXI_wdata);
    mp_S05_AXI_transactor->WSTRB(S05_AXI_wstrb);
    mp_S05_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wlast_converter");
    mp_S05_AXI_wlast_converter->vector_in(S05_AXI_wlast);
    mp_S05_AXI_wlast_converter->scalar_out(m_S05_AXI_wlast_converter_signal);
    mp_S05_AXI_transactor->WLAST(m_S05_AXI_wlast_converter_signal);
    mp_S05_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wvalid_converter");
    mp_S05_AXI_wvalid_converter->vector_in(S05_AXI_wvalid);
    mp_S05_AXI_wvalid_converter->scalar_out(m_S05_AXI_wvalid_converter_signal);
    mp_S05_AXI_transactor->WVALID(m_S05_AXI_wvalid_converter_signal);
    mp_S05_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_wready_converter");
    mp_S05_AXI_wready_converter->scalar_in(m_S05_AXI_wready_converter_signal);
    mp_S05_AXI_wready_converter->vector_out(S05_AXI_wready);
    mp_S05_AXI_transactor->WREADY(m_S05_AXI_wready_converter_signal);
    mp_S05_AXI_transactor->BRESP(S05_AXI_bresp);
    mp_S05_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_bvalid_converter");
    mp_S05_AXI_bvalid_converter->scalar_in(m_S05_AXI_bvalid_converter_signal);
    mp_S05_AXI_bvalid_converter->vector_out(S05_AXI_bvalid);
    mp_S05_AXI_transactor->BVALID(m_S05_AXI_bvalid_converter_signal);
    mp_S05_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_bready_converter");
    mp_S05_AXI_bready_converter->vector_in(S05_AXI_bready);
    mp_S05_AXI_bready_converter->scalar_out(m_S05_AXI_bready_converter_signal);
    mp_S05_AXI_transactor->BREADY(m_S05_AXI_bready_converter_signal);
    mp_S05_AXI_transactor->ARADDR(S05_AXI_araddr);
    mp_S05_AXI_transactor->ARLEN(S05_AXI_arlen);
    mp_S05_AXI_transactor->ARSIZE(S05_AXI_arsize);
    mp_S05_AXI_transactor->ARBURST(S05_AXI_arburst);
    mp_S05_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arlock_converter");
    mp_S05_AXI_arlock_converter->vector_in(S05_AXI_arlock);
    mp_S05_AXI_arlock_converter->scalar_out(m_S05_AXI_arlock_converter_signal);
    mp_S05_AXI_transactor->ARLOCK(m_S05_AXI_arlock_converter_signal);
    mp_S05_AXI_transactor->ARCACHE(S05_AXI_arcache);
    mp_S05_AXI_transactor->ARPROT(S05_AXI_arprot);
    mp_S05_AXI_transactor->ARREGION(S05_AXI_arregion);
    mp_S05_AXI_transactor->ARQOS(S05_AXI_arqos);
    mp_S05_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arvalid_converter");
    mp_S05_AXI_arvalid_converter->vector_in(S05_AXI_arvalid);
    mp_S05_AXI_arvalid_converter->scalar_out(m_S05_AXI_arvalid_converter_signal);
    mp_S05_AXI_transactor->ARVALID(m_S05_AXI_arvalid_converter_signal);
    mp_S05_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_arready_converter");
    mp_S05_AXI_arready_converter->scalar_in(m_S05_AXI_arready_converter_signal);
    mp_S05_AXI_arready_converter->vector_out(S05_AXI_arready);
    mp_S05_AXI_transactor->ARREADY(m_S05_AXI_arready_converter_signal);
    mp_S05_AXI_transactor->RDATA(S05_AXI_rdata);
    mp_S05_AXI_transactor->RRESP(S05_AXI_rresp);
    mp_S05_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rlast_converter");
    mp_S05_AXI_rlast_converter->scalar_in(m_S05_AXI_rlast_converter_signal);
    mp_S05_AXI_rlast_converter->vector_out(S05_AXI_rlast);
    mp_S05_AXI_transactor->RLAST(m_S05_AXI_rlast_converter_signal);
    mp_S05_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rvalid_converter");
    mp_S05_AXI_rvalid_converter->scalar_in(m_S05_AXI_rvalid_converter_signal);
    mp_S05_AXI_rvalid_converter->vector_out(S05_AXI_rvalid);
    mp_S05_AXI_transactor->RVALID(m_S05_AXI_rvalid_converter_signal);
    mp_S05_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_rready_converter");
    mp_S05_AXI_rready_converter->vector_in(S05_AXI_rready);
    mp_S05_AXI_rready_converter->scalar_out(m_S05_AXI_rready_converter_signal);
    mp_S05_AXI_transactor->RREADY(m_S05_AXI_rready_converter_signal);
    mp_S05_AXI_transactor->ARID(S05_AXI_arid);
    mp_S05_AXI_transactor->ARUSER(S05_AXI_aruser);
    mp_S05_AXI_transactor->AWID(S05_AXI_awid);
    mp_S05_AXI_transactor->AWUSER(S05_AXI_awuser);
    mp_S05_AXI_transactor->BID(S05_AXI_bid);
    mp_S05_AXI_transactor->BUSER(S05_AXI_buser);
    mp_S05_AXI_transactor->RID(S05_AXI_rid);
    mp_S05_AXI_transactor->RUSER(S05_AXI_ruser);
    mp_S05_AXI_transactor->WUSER(S05_AXI_wuser);
    mp_S05_AXI_transactor->CLK(aclk5);
    m_S05_AXI_transactor_rst_signal.write(1);
    mp_S05_AXI_transactor->RST(m_S05_AXI_transactor_rst_signal);

    // S05_AXI' transactor sockets

    mp_impl->S05_AXI_tlm_aximm_read_socket->bind(*(mp_S05_AXI_transactor->rd_socket));
    mp_impl->S05_AXI_tlm_aximm_write_socket->bind(*(mp_S05_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S06_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S06_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S06_AXI' transactor parameters
    xsc::common_cpp::properties S06_AXI_transactor_param_props;
    S06_AXI_transactor_param_props.addLong("DATA_WIDTH", "32");
    S06_AXI_transactor_param_props.addLong("FREQ_HZ", "100000000");
    S06_AXI_transactor_param_props.addLong("ID_WIDTH", "1");
    S06_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S06_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("RUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S06_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S06_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S06_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S06_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S06_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S06_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S06_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S06_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S06_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S06_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S06_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S06_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pl0_ref_clk");
    S06_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S06_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S06_AXI_transactor_param_props.addString("REGION", "");
    S06_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {500} write_bw {500}}");
    S06_AXI_transactor_param_props.addString("DEST_IDS", "");
    S06_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S06_AXI_transactor_param_props.addString("REMAPS", "");
    S06_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S06_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S06_AXI_transactor_param_props.addString("CATEGORY", "pl");
    S06_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S06_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<32,64,1,1,1,1,1,1>("S06_AXI_transactor", S06_AXI_transactor_param_props);

    // S06_AXI' transactor ports

    mp_S06_AXI_transactor->AWADDR(S06_AXI_awaddr);
    mp_S06_AXI_transactor->AWLEN(S06_AXI_awlen);
    mp_S06_AXI_transactor->AWSIZE(S06_AXI_awsize);
    mp_S06_AXI_transactor->AWBURST(S06_AXI_awburst);
    mp_S06_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awlock_converter");
    mp_S06_AXI_awlock_converter->vector_in(S06_AXI_awlock);
    mp_S06_AXI_awlock_converter->scalar_out(m_S06_AXI_awlock_converter_signal);
    mp_S06_AXI_transactor->AWLOCK(m_S06_AXI_awlock_converter_signal);
    mp_S06_AXI_transactor->AWCACHE(S06_AXI_awcache);
    mp_S06_AXI_transactor->AWPROT(S06_AXI_awprot);
    mp_S06_AXI_transactor->AWREGION(S06_AXI_awregion);
    mp_S06_AXI_transactor->AWQOS(S06_AXI_awqos);
    mp_S06_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awvalid_converter");
    mp_S06_AXI_awvalid_converter->vector_in(S06_AXI_awvalid);
    mp_S06_AXI_awvalid_converter->scalar_out(m_S06_AXI_awvalid_converter_signal);
    mp_S06_AXI_transactor->AWVALID(m_S06_AXI_awvalid_converter_signal);
    mp_S06_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_awready_converter");
    mp_S06_AXI_awready_converter->scalar_in(m_S06_AXI_awready_converter_signal);
    mp_S06_AXI_awready_converter->vector_out(S06_AXI_awready);
    mp_S06_AXI_transactor->AWREADY(m_S06_AXI_awready_converter_signal);
    mp_S06_AXI_transactor->WDATA(S06_AXI_wdata);
    mp_S06_AXI_transactor->WSTRB(S06_AXI_wstrb);
    mp_S06_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wlast_converter");
    mp_S06_AXI_wlast_converter->vector_in(S06_AXI_wlast);
    mp_S06_AXI_wlast_converter->scalar_out(m_S06_AXI_wlast_converter_signal);
    mp_S06_AXI_transactor->WLAST(m_S06_AXI_wlast_converter_signal);
    mp_S06_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wvalid_converter");
    mp_S06_AXI_wvalid_converter->vector_in(S06_AXI_wvalid);
    mp_S06_AXI_wvalid_converter->scalar_out(m_S06_AXI_wvalid_converter_signal);
    mp_S06_AXI_transactor->WVALID(m_S06_AXI_wvalid_converter_signal);
    mp_S06_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_wready_converter");
    mp_S06_AXI_wready_converter->scalar_in(m_S06_AXI_wready_converter_signal);
    mp_S06_AXI_wready_converter->vector_out(S06_AXI_wready);
    mp_S06_AXI_transactor->WREADY(m_S06_AXI_wready_converter_signal);
    mp_S06_AXI_transactor->BRESP(S06_AXI_bresp);
    mp_S06_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_bvalid_converter");
    mp_S06_AXI_bvalid_converter->scalar_in(m_S06_AXI_bvalid_converter_signal);
    mp_S06_AXI_bvalid_converter->vector_out(S06_AXI_bvalid);
    mp_S06_AXI_transactor->BVALID(m_S06_AXI_bvalid_converter_signal);
    mp_S06_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_bready_converter");
    mp_S06_AXI_bready_converter->vector_in(S06_AXI_bready);
    mp_S06_AXI_bready_converter->scalar_out(m_S06_AXI_bready_converter_signal);
    mp_S06_AXI_transactor->BREADY(m_S06_AXI_bready_converter_signal);
    mp_S06_AXI_transactor->ARADDR(S06_AXI_araddr);
    mp_S06_AXI_transactor->ARLEN(S06_AXI_arlen);
    mp_S06_AXI_transactor->ARSIZE(S06_AXI_arsize);
    mp_S06_AXI_transactor->ARBURST(S06_AXI_arburst);
    mp_S06_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arlock_converter");
    mp_S06_AXI_arlock_converter->vector_in(S06_AXI_arlock);
    mp_S06_AXI_arlock_converter->scalar_out(m_S06_AXI_arlock_converter_signal);
    mp_S06_AXI_transactor->ARLOCK(m_S06_AXI_arlock_converter_signal);
    mp_S06_AXI_transactor->ARCACHE(S06_AXI_arcache);
    mp_S06_AXI_transactor->ARPROT(S06_AXI_arprot);
    mp_S06_AXI_transactor->ARREGION(S06_AXI_arregion);
    mp_S06_AXI_transactor->ARQOS(S06_AXI_arqos);
    mp_S06_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arvalid_converter");
    mp_S06_AXI_arvalid_converter->vector_in(S06_AXI_arvalid);
    mp_S06_AXI_arvalid_converter->scalar_out(m_S06_AXI_arvalid_converter_signal);
    mp_S06_AXI_transactor->ARVALID(m_S06_AXI_arvalid_converter_signal);
    mp_S06_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_arready_converter");
    mp_S06_AXI_arready_converter->scalar_in(m_S06_AXI_arready_converter_signal);
    mp_S06_AXI_arready_converter->vector_out(S06_AXI_arready);
    mp_S06_AXI_transactor->ARREADY(m_S06_AXI_arready_converter_signal);
    mp_S06_AXI_transactor->RDATA(S06_AXI_rdata);
    mp_S06_AXI_transactor->RRESP(S06_AXI_rresp);
    mp_S06_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rlast_converter");
    mp_S06_AXI_rlast_converter->scalar_in(m_S06_AXI_rlast_converter_signal);
    mp_S06_AXI_rlast_converter->vector_out(S06_AXI_rlast);
    mp_S06_AXI_transactor->RLAST(m_S06_AXI_rlast_converter_signal);
    mp_S06_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rvalid_converter");
    mp_S06_AXI_rvalid_converter->scalar_in(m_S06_AXI_rvalid_converter_signal);
    mp_S06_AXI_rvalid_converter->vector_out(S06_AXI_rvalid);
    mp_S06_AXI_transactor->RVALID(m_S06_AXI_rvalid_converter_signal);
    mp_S06_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_rready_converter");
    mp_S06_AXI_rready_converter->vector_in(S06_AXI_rready);
    mp_S06_AXI_rready_converter->scalar_out(m_S06_AXI_rready_converter_signal);
    mp_S06_AXI_transactor->RREADY(m_S06_AXI_rready_converter_signal);
    mp_S06_AXI_transactor->ARID(S06_AXI_arid);
    mp_S06_AXI_transactor->AWID(S06_AXI_awid);
    mp_S06_AXI_transactor->BID(S06_AXI_bid);
    mp_S06_AXI_transactor->RID(S06_AXI_rid);
    mp_S06_AXI_transactor->CLK(aclk6);
    m_S06_AXI_transactor_rst_signal.write(1);
    mp_S06_AXI_transactor->RST(m_S06_AXI_transactor_rst_signal);

    // S06_AXI' transactor sockets

    mp_impl->S06_AXI_tlm_aximm_read_socket->bind(*(mp_S06_AXI_transactor->rd_socket));
    mp_impl->S06_AXI_tlm_aximm_write_socket->bind(*(mp_S06_AXI_transactor->wr_socket));
  }
  else
  {
  }

}

#endif // XM_SYSTEMC




#ifdef RIVIERA
bd_soc_usart_axi_noc_0_0::bd_soc_usart_axi_noc_0_0(const sc_core::sc_module_name& nm) : bd_soc_usart_axi_noc_0_0_sc(nm), S00_AXI_awaddr("S00_AXI_awaddr"), S00_AXI_awlen("S00_AXI_awlen"), S00_AXI_awsize("S00_AXI_awsize"), S00_AXI_awburst("S00_AXI_awburst"), S00_AXI_awlock("S00_AXI_awlock"), S00_AXI_awcache("S00_AXI_awcache"), S00_AXI_awprot("S00_AXI_awprot"), S00_AXI_awregion("S00_AXI_awregion"), S00_AXI_awqos("S00_AXI_awqos"), S00_AXI_awvalid("S00_AXI_awvalid"), S00_AXI_awready("S00_AXI_awready"), S00_AXI_wdata("S00_AXI_wdata"), S00_AXI_wstrb("S00_AXI_wstrb"), S00_AXI_wlast("S00_AXI_wlast"), S00_AXI_wvalid("S00_AXI_wvalid"), S00_AXI_wready("S00_AXI_wready"), S00_AXI_bresp("S00_AXI_bresp"), S00_AXI_bvalid("S00_AXI_bvalid"), S00_AXI_bready("S00_AXI_bready"), S00_AXI_araddr("S00_AXI_araddr"), S00_AXI_arlen("S00_AXI_arlen"), S00_AXI_arsize("S00_AXI_arsize"), S00_AXI_arburst("S00_AXI_arburst"), S00_AXI_arlock("S00_AXI_arlock"), S00_AXI_arcache("S00_AXI_arcache"), S00_AXI_arprot("S00_AXI_arprot"), S00_AXI_arregion("S00_AXI_arregion"), S00_AXI_arqos("S00_AXI_arqos"), S00_AXI_arvalid("S00_AXI_arvalid"), S00_AXI_arready("S00_AXI_arready"), S00_AXI_rdata("S00_AXI_rdata"), S00_AXI_rresp("S00_AXI_rresp"), S00_AXI_rlast("S00_AXI_rlast"), S00_AXI_rvalid("S00_AXI_rvalid"), S00_AXI_rready("S00_AXI_rready"), S01_AXI_awaddr("S01_AXI_awaddr"), S01_AXI_awlen("S01_AXI_awlen"), S01_AXI_awsize("S01_AXI_awsize"), S01_AXI_awburst("S01_AXI_awburst"), S01_AXI_awlock("S01_AXI_awlock"), S01_AXI_awcache("S01_AXI_awcache"), S01_AXI_awprot("S01_AXI_awprot"), S01_AXI_awregion("S01_AXI_awregion"), S01_AXI_awqos("S01_AXI_awqos"), S01_AXI_awvalid("S01_AXI_awvalid"), S01_AXI_awready("S01_AXI_awready"), S01_AXI_wdata("S01_AXI_wdata"), S01_AXI_wstrb("S01_AXI_wstrb"), S01_AXI_wlast("S01_AXI_wlast"), S01_AXI_wvalid("S01_AXI_wvalid"), S01_AXI_wready("S01_AXI_wready"), S01_AXI_bresp("S01_AXI_bresp"), S01_AXI_bvalid("S01_AXI_bvalid"), S01_AXI_bready("S01_AXI_bready"), S01_AXI_araddr("S01_AXI_araddr"), S01_AXI_arlen("S01_AXI_arlen"), S01_AXI_arsize("S01_AXI_arsize"), S01_AXI_arburst("S01_AXI_arburst"), S01_AXI_arlock("S01_AXI_arlock"), S01_AXI_arcache("S01_AXI_arcache"), S01_AXI_arprot("S01_AXI_arprot"), S01_AXI_arregion("S01_AXI_arregion"), S01_AXI_arqos("S01_AXI_arqos"), S01_AXI_arvalid("S01_AXI_arvalid"), S01_AXI_arready("S01_AXI_arready"), S01_AXI_rdata("S01_AXI_rdata"), S01_AXI_rresp("S01_AXI_rresp"), S01_AXI_rlast("S01_AXI_rlast"), S01_AXI_rvalid("S01_AXI_rvalid"), S01_AXI_rready("S01_AXI_rready"), S02_AXI_awaddr("S02_AXI_awaddr"), S02_AXI_awlen("S02_AXI_awlen"), S02_AXI_awsize("S02_AXI_awsize"), S02_AXI_awburst("S02_AXI_awburst"), S02_AXI_awlock("S02_AXI_awlock"), S02_AXI_awcache("S02_AXI_awcache"), S02_AXI_awprot("S02_AXI_awprot"), S02_AXI_awregion("S02_AXI_awregion"), S02_AXI_awqos("S02_AXI_awqos"), S02_AXI_awvalid("S02_AXI_awvalid"), S02_AXI_awready("S02_AXI_awready"), S02_AXI_wdata("S02_AXI_wdata"), S02_AXI_wstrb("S02_AXI_wstrb"), S02_AXI_wlast("S02_AXI_wlast"), S02_AXI_wvalid("S02_AXI_wvalid"), S02_AXI_wready("S02_AXI_wready"), S02_AXI_bresp("S02_AXI_bresp"), S02_AXI_bvalid("S02_AXI_bvalid"), S02_AXI_bready("S02_AXI_bready"), S02_AXI_araddr("S02_AXI_araddr"), S02_AXI_arlen("S02_AXI_arlen"), S02_AXI_arsize("S02_AXI_arsize"), S02_AXI_arburst("S02_AXI_arburst"), S02_AXI_arlock("S02_AXI_arlock"), S02_AXI_arcache("S02_AXI_arcache"), S02_AXI_arprot("S02_AXI_arprot"), S02_AXI_arregion("S02_AXI_arregion"), S02_AXI_arqos("S02_AXI_arqos"), S02_AXI_arvalid("S02_AXI_arvalid"), S02_AXI_arready("S02_AXI_arready"), S02_AXI_rdata("S02_AXI_rdata"), S02_AXI_rresp("S02_AXI_rresp"), S02_AXI_rlast("S02_AXI_rlast"), S02_AXI_rvalid("S02_AXI_rvalid"), S02_AXI_rready("S02_AXI_rready"), S03_AXI_awaddr("S03_AXI_awaddr"), S03_AXI_awlen("S03_AXI_awlen"), S03_AXI_awsize("S03_AXI_awsize"), S03_AXI_awburst("S03_AXI_awburst"), S03_AXI_awlock("S03_AXI_awlock"), S03_AXI_awcache("S03_AXI_awcache"), S03_AXI_awprot("S03_AXI_awprot"), S03_AXI_awregion("S03_AXI_awregion"), S03_AXI_awqos("S03_AXI_awqos"), S03_AXI_awvalid("S03_AXI_awvalid"), S03_AXI_awready("S03_AXI_awready"), S03_AXI_wdata("S03_AXI_wdata"), S03_AXI_wstrb("S03_AXI_wstrb"), S03_AXI_wlast("S03_AXI_wlast"), S03_AXI_wvalid("S03_AXI_wvalid"), S03_AXI_wready("S03_AXI_wready"), S03_AXI_bresp("S03_AXI_bresp"), S03_AXI_bvalid("S03_AXI_bvalid"), S03_AXI_bready("S03_AXI_bready"), S03_AXI_araddr("S03_AXI_araddr"), S03_AXI_arlen("S03_AXI_arlen"), S03_AXI_arsize("S03_AXI_arsize"), S03_AXI_arburst("S03_AXI_arburst"), S03_AXI_arlock("S03_AXI_arlock"), S03_AXI_arcache("S03_AXI_arcache"), S03_AXI_arprot("S03_AXI_arprot"), S03_AXI_arregion("S03_AXI_arregion"), S03_AXI_arqos("S03_AXI_arqos"), S03_AXI_arvalid("S03_AXI_arvalid"), S03_AXI_arready("S03_AXI_arready"), S03_AXI_rdata("S03_AXI_rdata"), S03_AXI_rresp("S03_AXI_rresp"), S03_AXI_rlast("S03_AXI_rlast"), S03_AXI_rvalid("S03_AXI_rvalid"), S03_AXI_rready("S03_AXI_rready"), S04_AXI_awaddr("S04_AXI_awaddr"), S04_AXI_awlen("S04_AXI_awlen"), S04_AXI_awsize("S04_AXI_awsize"), S04_AXI_awburst("S04_AXI_awburst"), S04_AXI_awlock("S04_AXI_awlock"), S04_AXI_awcache("S04_AXI_awcache"), S04_AXI_awprot("S04_AXI_awprot"), S04_AXI_awregion("S04_AXI_awregion"), S04_AXI_awqos("S04_AXI_awqos"), S04_AXI_awvalid("S04_AXI_awvalid"), S04_AXI_awready("S04_AXI_awready"), S04_AXI_wdata("S04_AXI_wdata"), S04_AXI_wstrb("S04_AXI_wstrb"), S04_AXI_wlast("S04_AXI_wlast"), S04_AXI_wvalid("S04_AXI_wvalid"), S04_AXI_wready("S04_AXI_wready"), S04_AXI_bresp("S04_AXI_bresp"), S04_AXI_bvalid("S04_AXI_bvalid"), S04_AXI_bready("S04_AXI_bready"), S04_AXI_araddr("S04_AXI_araddr"), S04_AXI_arlen("S04_AXI_arlen"), S04_AXI_arsize("S04_AXI_arsize"), S04_AXI_arburst("S04_AXI_arburst"), S04_AXI_arlock("S04_AXI_arlock"), S04_AXI_arcache("S04_AXI_arcache"), S04_AXI_arprot("S04_AXI_arprot"), S04_AXI_arregion("S04_AXI_arregion"), S04_AXI_arqos("S04_AXI_arqos"), S04_AXI_arvalid("S04_AXI_arvalid"), S04_AXI_arready("S04_AXI_arready"), S04_AXI_rdata("S04_AXI_rdata"), S04_AXI_rresp("S04_AXI_rresp"), S04_AXI_rlast("S04_AXI_rlast"), S04_AXI_rvalid("S04_AXI_rvalid"), S04_AXI_rready("S04_AXI_rready"), S05_AXI_awaddr("S05_AXI_awaddr"), S05_AXI_awlen("S05_AXI_awlen"), S05_AXI_awsize("S05_AXI_awsize"), S05_AXI_awburst("S05_AXI_awburst"), S05_AXI_awlock("S05_AXI_awlock"), S05_AXI_awcache("S05_AXI_awcache"), S05_AXI_awprot("S05_AXI_awprot"), S05_AXI_awregion("S05_AXI_awregion"), S05_AXI_awqos("S05_AXI_awqos"), S05_AXI_awvalid("S05_AXI_awvalid"), S05_AXI_awready("S05_AXI_awready"), S05_AXI_wdata("S05_AXI_wdata"), S05_AXI_wstrb("S05_AXI_wstrb"), S05_AXI_wlast("S05_AXI_wlast"), S05_AXI_wvalid("S05_AXI_wvalid"), S05_AXI_wready("S05_AXI_wready"), S05_AXI_bresp("S05_AXI_bresp"), S05_AXI_bvalid("S05_AXI_bvalid"), S05_AXI_bready("S05_AXI_bready"), S05_AXI_araddr("S05_AXI_araddr"), S05_AXI_arlen("S05_AXI_arlen"), S05_AXI_arsize("S05_AXI_arsize"), S05_AXI_arburst("S05_AXI_arburst"), S05_AXI_arlock("S05_AXI_arlock"), S05_AXI_arcache("S05_AXI_arcache"), S05_AXI_arprot("S05_AXI_arprot"), S05_AXI_arregion("S05_AXI_arregion"), S05_AXI_arqos("S05_AXI_arqos"), S05_AXI_arvalid("S05_AXI_arvalid"), S05_AXI_arready("S05_AXI_arready"), S05_AXI_rdata("S05_AXI_rdata"), S05_AXI_rresp("S05_AXI_rresp"), S05_AXI_rlast("S05_AXI_rlast"), S05_AXI_rvalid("S05_AXI_rvalid"), S05_AXI_rready("S05_AXI_rready"), S06_AXI_awaddr("S06_AXI_awaddr"), S06_AXI_awlen("S06_AXI_awlen"), S06_AXI_awsize("S06_AXI_awsize"), S06_AXI_awburst("S06_AXI_awburst"), S06_AXI_awlock("S06_AXI_awlock"), S06_AXI_awcache("S06_AXI_awcache"), S06_AXI_awprot("S06_AXI_awprot"), S06_AXI_awregion("S06_AXI_awregion"), S06_AXI_awqos("S06_AXI_awqos"), S06_AXI_awvalid("S06_AXI_awvalid"), S06_AXI_awready("S06_AXI_awready"), S06_AXI_wdata("S06_AXI_wdata"), S06_AXI_wstrb("S06_AXI_wstrb"), S06_AXI_wlast("S06_AXI_wlast"), S06_AXI_wvalid("S06_AXI_wvalid"), S06_AXI_wready("S06_AXI_wready"), S06_AXI_bresp("S06_AXI_bresp"), S06_AXI_bvalid("S06_AXI_bvalid"), S06_AXI_bready("S06_AXI_bready"), S06_AXI_araddr("S06_AXI_araddr"), S06_AXI_arlen("S06_AXI_arlen"), S06_AXI_arsize("S06_AXI_arsize"), S06_AXI_arburst("S06_AXI_arburst"), S06_AXI_arlock("S06_AXI_arlock"), S06_AXI_arcache("S06_AXI_arcache"), S06_AXI_arprot("S06_AXI_arprot"), S06_AXI_arregion("S06_AXI_arregion"), S06_AXI_arqos("S06_AXI_arqos"), S06_AXI_arvalid("S06_AXI_arvalid"), S06_AXI_arready("S06_AXI_arready"), S06_AXI_rdata("S06_AXI_rdata"), S06_AXI_rresp("S06_AXI_rresp"), S06_AXI_rlast("S06_AXI_rlast"), S06_AXI_rvalid("S06_AXI_rvalid"), S06_AXI_rready("S06_AXI_rready"), aclk0("aclk0"), aclk1("aclk1"), aclk2("aclk2"), aclk3("aclk3"), aclk4("aclk4"), aclk5("aclk5"), aclk6("aclk6"), sys_clk0_clk_p("sys_clk0_clk_p"), sys_clk0_clk_n("sys_clk0_clk_n"), CH0_DDR4_0_dq("CH0_DDR4_0_dq"), CH0_DDR4_0_dqs_t("CH0_DDR4_0_dqs_t"), CH0_DDR4_0_dqs_c("CH0_DDR4_0_dqs_c"), CH0_DDR4_0_adr("CH0_DDR4_0_adr"), CH0_DDR4_0_ba("CH0_DDR4_0_ba"), CH0_DDR4_0_bg("CH0_DDR4_0_bg"), CH0_DDR4_0_act_n("CH0_DDR4_0_act_n"), CH0_DDR4_0_reset_n("CH0_DDR4_0_reset_n"), CH0_DDR4_0_ck_t("CH0_DDR4_0_ck_t"), CH0_DDR4_0_ck_c("CH0_DDR4_0_ck_c"), CH0_DDR4_0_cke("CH0_DDR4_0_cke"), CH0_DDR4_0_cs_n("CH0_DDR4_0_cs_n"), CH0_DDR4_0_dm_n("CH0_DDR4_0_dm_n"), CH0_DDR4_0_odt("CH0_DDR4_0_odt"), S05_AXI_arid("S05_AXI_arid"), S05_AXI_aruser("S05_AXI_aruser"), S05_AXI_awid("S05_AXI_awid"), S05_AXI_awuser("S05_AXI_awuser"), S05_AXI_bid("S05_AXI_bid"), S05_AXI_buser("S05_AXI_buser"), S05_AXI_rid("S05_AXI_rid"), S05_AXI_ruser("S05_AXI_ruser"), S05_AXI_wuser("S05_AXI_wuser"), S03_AXI_arid("S03_AXI_arid"), S03_AXI_aruser("S03_AXI_aruser"), S03_AXI_awid("S03_AXI_awid"), S03_AXI_awuser("S03_AXI_awuser"), S03_AXI_bid("S03_AXI_bid"), S03_AXI_rid("S03_AXI_rid"), S03_AXI_ruser("S03_AXI_ruser"), S03_AXI_wuser("S03_AXI_wuser"), S04_AXI_arid("S04_AXI_arid"), S04_AXI_aruser("S04_AXI_aruser"), S04_AXI_awid("S04_AXI_awid"), S04_AXI_awuser("S04_AXI_awuser"), S04_AXI_bid("S04_AXI_bid"), S04_AXI_rid("S04_AXI_rid"), S04_AXI_ruser("S04_AXI_ruser"), S04_AXI_wuser("S04_AXI_wuser"), S02_AXI_arid("S02_AXI_arid"), S02_AXI_aruser("S02_AXI_aruser"), S02_AXI_awid("S02_AXI_awid"), S02_AXI_awuser("S02_AXI_awuser"), S02_AXI_bid("S02_AXI_bid"), S02_AXI_rid("S02_AXI_rid"), S02_AXI_ruser("S02_AXI_ruser"), S02_AXI_wuser("S02_AXI_wuser"), S06_AXI_arid("S06_AXI_arid"), S06_AXI_awid("S06_AXI_awid"), S06_AXI_bid("S06_AXI_bid"), S06_AXI_rid("S06_AXI_rid"), S01_AXI_arid("S01_AXI_arid"), S01_AXI_aruser("S01_AXI_aruser"), S01_AXI_awid("S01_AXI_awid"), S01_AXI_awuser("S01_AXI_awuser"), S01_AXI_bid("S01_AXI_bid"), S01_AXI_rid("S01_AXI_rid"), S01_AXI_ruser("S01_AXI_ruser"), S01_AXI_wuser("S01_AXI_wuser"), S00_AXI_arid("S00_AXI_arid"), S00_AXI_aruser("S00_AXI_aruser"), S00_AXI_awid("S00_AXI_awid"), S00_AXI_awuser("S00_AXI_awuser"), S00_AXI_bid("S00_AXI_bid"), S00_AXI_rid("S00_AXI_rid"), S00_AXI_ruser("S00_AXI_ruser"), S00_AXI_wuser("S00_AXI_wuser")
{

  // initialize pins
  mp_impl->aclk0(aclk0);
  mp_impl->aclk1(aclk1);
  mp_impl->aclk2(aclk2);
  mp_impl->aclk3(aclk3);
  mp_impl->aclk4(aclk4);
  mp_impl->aclk5(aclk5);
  mp_impl->aclk6(aclk6);
  mp_impl->sys_clk0_clk_p(sys_clk0_clk_p);
  mp_impl->sys_clk0_clk_n(sys_clk0_clk_n);
  mp_impl->CH0_DDR4_0_dq(CH0_DDR4_0_dq);
  mp_impl->CH0_DDR4_0_dqs_t(CH0_DDR4_0_dqs_t);
  mp_impl->CH0_DDR4_0_dqs_c(CH0_DDR4_0_dqs_c);
  mp_impl->CH0_DDR4_0_adr(CH0_DDR4_0_adr);
  mp_impl->CH0_DDR4_0_ba(CH0_DDR4_0_ba);
  mp_impl->CH0_DDR4_0_bg(CH0_DDR4_0_bg);
  mp_impl->CH0_DDR4_0_act_n(CH0_DDR4_0_act_n);
  mp_impl->CH0_DDR4_0_reset_n(CH0_DDR4_0_reset_n);
  mp_impl->CH0_DDR4_0_ck_t(CH0_DDR4_0_ck_t);
  mp_impl->CH0_DDR4_0_ck_c(CH0_DDR4_0_ck_c);
  mp_impl->CH0_DDR4_0_cke(CH0_DDR4_0_cke);
  mp_impl->CH0_DDR4_0_cs_n(CH0_DDR4_0_cs_n);
  mp_impl->CH0_DDR4_0_dm_n(CH0_DDR4_0_dm_n);
  mp_impl->CH0_DDR4_0_odt(CH0_DDR4_0_odt);

  // initialize transactors
  mp_S00_AXI_transactor = NULL;
  mp_S00_AXI_awlock_converter = NULL;
  mp_S00_AXI_awvalid_converter = NULL;
  mp_S00_AXI_awready_converter = NULL;
  mp_S00_AXI_wlast_converter = NULL;
  mp_S00_AXI_wvalid_converter = NULL;
  mp_S00_AXI_wready_converter = NULL;
  mp_S00_AXI_bvalid_converter = NULL;
  mp_S00_AXI_bready_converter = NULL;
  mp_S00_AXI_arlock_converter = NULL;
  mp_S00_AXI_arvalid_converter = NULL;
  mp_S00_AXI_arready_converter = NULL;
  mp_S00_AXI_rlast_converter = NULL;
  mp_S00_AXI_rvalid_converter = NULL;
  mp_S00_AXI_rready_converter = NULL;
  mp_S01_AXI_transactor = NULL;
  mp_S01_AXI_awlock_converter = NULL;
  mp_S01_AXI_awvalid_converter = NULL;
  mp_S01_AXI_awready_converter = NULL;
  mp_S01_AXI_wlast_converter = NULL;
  mp_S01_AXI_wvalid_converter = NULL;
  mp_S01_AXI_wready_converter = NULL;
  mp_S01_AXI_bvalid_converter = NULL;
  mp_S01_AXI_bready_converter = NULL;
  mp_S01_AXI_arlock_converter = NULL;
  mp_S01_AXI_arvalid_converter = NULL;
  mp_S01_AXI_arready_converter = NULL;
  mp_S01_AXI_rlast_converter = NULL;
  mp_S01_AXI_rvalid_converter = NULL;
  mp_S01_AXI_rready_converter = NULL;
  mp_S02_AXI_transactor = NULL;
  mp_S02_AXI_awlock_converter = NULL;
  mp_S02_AXI_awvalid_converter = NULL;
  mp_S02_AXI_awready_converter = NULL;
  mp_S02_AXI_wlast_converter = NULL;
  mp_S02_AXI_wvalid_converter = NULL;
  mp_S02_AXI_wready_converter = NULL;
  mp_S02_AXI_bvalid_converter = NULL;
  mp_S02_AXI_bready_converter = NULL;
  mp_S02_AXI_arlock_converter = NULL;
  mp_S02_AXI_arvalid_converter = NULL;
  mp_S02_AXI_arready_converter = NULL;
  mp_S02_AXI_rlast_converter = NULL;
  mp_S02_AXI_rvalid_converter = NULL;
  mp_S02_AXI_rready_converter = NULL;
  mp_S03_AXI_transactor = NULL;
  mp_S03_AXI_awlock_converter = NULL;
  mp_S03_AXI_awvalid_converter = NULL;
  mp_S03_AXI_awready_converter = NULL;
  mp_S03_AXI_wlast_converter = NULL;
  mp_S03_AXI_wvalid_converter = NULL;
  mp_S03_AXI_wready_converter = NULL;
  mp_S03_AXI_bvalid_converter = NULL;
  mp_S03_AXI_bready_converter = NULL;
  mp_S03_AXI_arlock_converter = NULL;
  mp_S03_AXI_arvalid_converter = NULL;
  mp_S03_AXI_arready_converter = NULL;
  mp_S03_AXI_rlast_converter = NULL;
  mp_S03_AXI_rvalid_converter = NULL;
  mp_S03_AXI_rready_converter = NULL;
  mp_S04_AXI_transactor = NULL;
  mp_S04_AXI_awlock_converter = NULL;
  mp_S04_AXI_awvalid_converter = NULL;
  mp_S04_AXI_awready_converter = NULL;
  mp_S04_AXI_wlast_converter = NULL;
  mp_S04_AXI_wvalid_converter = NULL;
  mp_S04_AXI_wready_converter = NULL;
  mp_S04_AXI_bvalid_converter = NULL;
  mp_S04_AXI_bready_converter = NULL;
  mp_S04_AXI_arlock_converter = NULL;
  mp_S04_AXI_arvalid_converter = NULL;
  mp_S04_AXI_arready_converter = NULL;
  mp_S04_AXI_rlast_converter = NULL;
  mp_S04_AXI_rvalid_converter = NULL;
  mp_S04_AXI_rready_converter = NULL;
  mp_S05_AXI_transactor = NULL;
  mp_S05_AXI_awlock_converter = NULL;
  mp_S05_AXI_awvalid_converter = NULL;
  mp_S05_AXI_awready_converter = NULL;
  mp_S05_AXI_wlast_converter = NULL;
  mp_S05_AXI_wvalid_converter = NULL;
  mp_S05_AXI_wready_converter = NULL;
  mp_S05_AXI_bvalid_converter = NULL;
  mp_S05_AXI_bready_converter = NULL;
  mp_S05_AXI_arlock_converter = NULL;
  mp_S05_AXI_arvalid_converter = NULL;
  mp_S05_AXI_arready_converter = NULL;
  mp_S05_AXI_rlast_converter = NULL;
  mp_S05_AXI_rvalid_converter = NULL;
  mp_S05_AXI_rready_converter = NULL;
  mp_S06_AXI_transactor = NULL;
  mp_S06_AXI_awlock_converter = NULL;
  mp_S06_AXI_awvalid_converter = NULL;
  mp_S06_AXI_awready_converter = NULL;
  mp_S06_AXI_wlast_converter = NULL;
  mp_S06_AXI_wvalid_converter = NULL;
  mp_S06_AXI_wready_converter = NULL;
  mp_S06_AXI_bvalid_converter = NULL;
  mp_S06_AXI_bready_converter = NULL;
  mp_S06_AXI_arlock_converter = NULL;
  mp_S06_AXI_arvalid_converter = NULL;
  mp_S06_AXI_arready_converter = NULL;
  mp_S06_AXI_rlast_converter = NULL;
  mp_S06_AXI_rvalid_converter = NULL;
  mp_S06_AXI_rready_converter = NULL;

  // initialize socket stubs

}

void bd_soc_usart_axi_noc_0_0::before_end_of_elaboration()
{
  // configure 'S00_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S00_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S00_AXI' transactor parameters
    xsc::common_cpp::properties S00_AXI_transactor_param_props;
    S00_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S00_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S00_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S00_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S00_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S00_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S00_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S00_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S00_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S00_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S00_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S00_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S00_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S00_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S00_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S00_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S00_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S00_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");
    S00_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S00_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S00_AXI_transactor_param_props.addString("REGION", "0");
    S00_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S00_AXI_transactor_param_props.addString("DEST_IDS", "");
    S00_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S00_AXI_transactor_param_props.addString("REMAPS", "");
    S00_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S00_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S00_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S00_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S00_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S00_AXI_transactor", S00_AXI_transactor_param_props);

    // S00_AXI' transactor ports

    mp_S00_AXI_transactor->AWADDR(S00_AXI_awaddr);
    mp_S00_AXI_transactor->AWLEN(S00_AXI_awlen);
    mp_S00_AXI_transactor->AWSIZE(S00_AXI_awsize);
    mp_S00_AXI_transactor->AWBURST(S00_AXI_awburst);
    mp_S00_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awlock_converter");
    mp_S00_AXI_awlock_converter->vector_in(S00_AXI_awlock);
    mp_S00_AXI_awlock_converter->scalar_out(m_S00_AXI_awlock_converter_signal);
    mp_S00_AXI_transactor->AWLOCK(m_S00_AXI_awlock_converter_signal);
    mp_S00_AXI_transactor->AWCACHE(S00_AXI_awcache);
    mp_S00_AXI_transactor->AWPROT(S00_AXI_awprot);
    mp_S00_AXI_transactor->AWREGION(S00_AXI_awregion);
    mp_S00_AXI_transactor->AWQOS(S00_AXI_awqos);
    mp_S00_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awvalid_converter");
    mp_S00_AXI_awvalid_converter->vector_in(S00_AXI_awvalid);
    mp_S00_AXI_awvalid_converter->scalar_out(m_S00_AXI_awvalid_converter_signal);
    mp_S00_AXI_transactor->AWVALID(m_S00_AXI_awvalid_converter_signal);
    mp_S00_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_awready_converter");
    mp_S00_AXI_awready_converter->scalar_in(m_S00_AXI_awready_converter_signal);
    mp_S00_AXI_awready_converter->vector_out(S00_AXI_awready);
    mp_S00_AXI_transactor->AWREADY(m_S00_AXI_awready_converter_signal);
    mp_S00_AXI_transactor->WDATA(S00_AXI_wdata);
    mp_S00_AXI_transactor->WSTRB(S00_AXI_wstrb);
    mp_S00_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wlast_converter");
    mp_S00_AXI_wlast_converter->vector_in(S00_AXI_wlast);
    mp_S00_AXI_wlast_converter->scalar_out(m_S00_AXI_wlast_converter_signal);
    mp_S00_AXI_transactor->WLAST(m_S00_AXI_wlast_converter_signal);
    mp_S00_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wvalid_converter");
    mp_S00_AXI_wvalid_converter->vector_in(S00_AXI_wvalid);
    mp_S00_AXI_wvalid_converter->scalar_out(m_S00_AXI_wvalid_converter_signal);
    mp_S00_AXI_transactor->WVALID(m_S00_AXI_wvalid_converter_signal);
    mp_S00_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_wready_converter");
    mp_S00_AXI_wready_converter->scalar_in(m_S00_AXI_wready_converter_signal);
    mp_S00_AXI_wready_converter->vector_out(S00_AXI_wready);
    mp_S00_AXI_transactor->WREADY(m_S00_AXI_wready_converter_signal);
    mp_S00_AXI_transactor->BRESP(S00_AXI_bresp);
    mp_S00_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_bvalid_converter");
    mp_S00_AXI_bvalid_converter->scalar_in(m_S00_AXI_bvalid_converter_signal);
    mp_S00_AXI_bvalid_converter->vector_out(S00_AXI_bvalid);
    mp_S00_AXI_transactor->BVALID(m_S00_AXI_bvalid_converter_signal);
    mp_S00_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_bready_converter");
    mp_S00_AXI_bready_converter->vector_in(S00_AXI_bready);
    mp_S00_AXI_bready_converter->scalar_out(m_S00_AXI_bready_converter_signal);
    mp_S00_AXI_transactor->BREADY(m_S00_AXI_bready_converter_signal);
    mp_S00_AXI_transactor->ARADDR(S00_AXI_araddr);
    mp_S00_AXI_transactor->ARLEN(S00_AXI_arlen);
    mp_S00_AXI_transactor->ARSIZE(S00_AXI_arsize);
    mp_S00_AXI_transactor->ARBURST(S00_AXI_arburst);
    mp_S00_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arlock_converter");
    mp_S00_AXI_arlock_converter->vector_in(S00_AXI_arlock);
    mp_S00_AXI_arlock_converter->scalar_out(m_S00_AXI_arlock_converter_signal);
    mp_S00_AXI_transactor->ARLOCK(m_S00_AXI_arlock_converter_signal);
    mp_S00_AXI_transactor->ARCACHE(S00_AXI_arcache);
    mp_S00_AXI_transactor->ARPROT(S00_AXI_arprot);
    mp_S00_AXI_transactor->ARREGION(S00_AXI_arregion);
    mp_S00_AXI_transactor->ARQOS(S00_AXI_arqos);
    mp_S00_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arvalid_converter");
    mp_S00_AXI_arvalid_converter->vector_in(S00_AXI_arvalid);
    mp_S00_AXI_arvalid_converter->scalar_out(m_S00_AXI_arvalid_converter_signal);
    mp_S00_AXI_transactor->ARVALID(m_S00_AXI_arvalid_converter_signal);
    mp_S00_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_arready_converter");
    mp_S00_AXI_arready_converter->scalar_in(m_S00_AXI_arready_converter_signal);
    mp_S00_AXI_arready_converter->vector_out(S00_AXI_arready);
    mp_S00_AXI_transactor->ARREADY(m_S00_AXI_arready_converter_signal);
    mp_S00_AXI_transactor->RDATA(S00_AXI_rdata);
    mp_S00_AXI_transactor->RRESP(S00_AXI_rresp);
    mp_S00_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rlast_converter");
    mp_S00_AXI_rlast_converter->scalar_in(m_S00_AXI_rlast_converter_signal);
    mp_S00_AXI_rlast_converter->vector_out(S00_AXI_rlast);
    mp_S00_AXI_transactor->RLAST(m_S00_AXI_rlast_converter_signal);
    mp_S00_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rvalid_converter");
    mp_S00_AXI_rvalid_converter->scalar_in(m_S00_AXI_rvalid_converter_signal);
    mp_S00_AXI_rvalid_converter->vector_out(S00_AXI_rvalid);
    mp_S00_AXI_transactor->RVALID(m_S00_AXI_rvalid_converter_signal);
    mp_S00_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_rready_converter");
    mp_S00_AXI_rready_converter->vector_in(S00_AXI_rready);
    mp_S00_AXI_rready_converter->scalar_out(m_S00_AXI_rready_converter_signal);
    mp_S00_AXI_transactor->RREADY(m_S00_AXI_rready_converter_signal);
    mp_S00_AXI_transactor->ARID(S00_AXI_arid);
    mp_S00_AXI_transactor->ARUSER(S00_AXI_aruser);
    mp_S00_AXI_transactor->AWID(S00_AXI_awid);
    mp_S00_AXI_transactor->AWUSER(S00_AXI_awuser);
    mp_S00_AXI_transactor->BID(S00_AXI_bid);
    mp_S00_AXI_transactor->RID(S00_AXI_rid);
    mp_S00_AXI_transactor->RUSER(S00_AXI_ruser);
    mp_S00_AXI_transactor->WUSER(S00_AXI_wuser);
    mp_S00_AXI_transactor->CLK(aclk0);
    m_S00_AXI_transactor_rst_signal.write(1);
    mp_S00_AXI_transactor->RST(m_S00_AXI_transactor_rst_signal);

    // S00_AXI' transactor sockets

    mp_impl->S00_AXI_tlm_aximm_read_socket->bind(*(mp_S00_AXI_transactor->rd_socket));
    mp_impl->S00_AXI_tlm_aximm_write_socket->bind(*(mp_S00_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S01_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S01_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S01_AXI' transactor parameters
    xsc::common_cpp::properties S01_AXI_transactor_param_props;
    S01_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S01_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S01_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S01_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S01_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S01_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S01_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S01_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S01_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S01_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S01_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S01_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S01_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S01_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S01_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S01_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S01_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S01_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk");
    S01_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S01_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S01_AXI_transactor_param_props.addString("REGION", "0");
    S01_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S01_AXI_transactor_param_props.addString("DEST_IDS", "");
    S01_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S01_AXI_transactor_param_props.addString("REMAPS", "");
    S01_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S01_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S01_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S01_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S01_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S01_AXI_transactor", S01_AXI_transactor_param_props);

    // S01_AXI' transactor ports

    mp_S01_AXI_transactor->AWADDR(S01_AXI_awaddr);
    mp_S01_AXI_transactor->AWLEN(S01_AXI_awlen);
    mp_S01_AXI_transactor->AWSIZE(S01_AXI_awsize);
    mp_S01_AXI_transactor->AWBURST(S01_AXI_awburst);
    mp_S01_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awlock_converter");
    mp_S01_AXI_awlock_converter->vector_in(S01_AXI_awlock);
    mp_S01_AXI_awlock_converter->scalar_out(m_S01_AXI_awlock_converter_signal);
    mp_S01_AXI_transactor->AWLOCK(m_S01_AXI_awlock_converter_signal);
    mp_S01_AXI_transactor->AWCACHE(S01_AXI_awcache);
    mp_S01_AXI_transactor->AWPROT(S01_AXI_awprot);
    mp_S01_AXI_transactor->AWREGION(S01_AXI_awregion);
    mp_S01_AXI_transactor->AWQOS(S01_AXI_awqos);
    mp_S01_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awvalid_converter");
    mp_S01_AXI_awvalid_converter->vector_in(S01_AXI_awvalid);
    mp_S01_AXI_awvalid_converter->scalar_out(m_S01_AXI_awvalid_converter_signal);
    mp_S01_AXI_transactor->AWVALID(m_S01_AXI_awvalid_converter_signal);
    mp_S01_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_awready_converter");
    mp_S01_AXI_awready_converter->scalar_in(m_S01_AXI_awready_converter_signal);
    mp_S01_AXI_awready_converter->vector_out(S01_AXI_awready);
    mp_S01_AXI_transactor->AWREADY(m_S01_AXI_awready_converter_signal);
    mp_S01_AXI_transactor->WDATA(S01_AXI_wdata);
    mp_S01_AXI_transactor->WSTRB(S01_AXI_wstrb);
    mp_S01_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wlast_converter");
    mp_S01_AXI_wlast_converter->vector_in(S01_AXI_wlast);
    mp_S01_AXI_wlast_converter->scalar_out(m_S01_AXI_wlast_converter_signal);
    mp_S01_AXI_transactor->WLAST(m_S01_AXI_wlast_converter_signal);
    mp_S01_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wvalid_converter");
    mp_S01_AXI_wvalid_converter->vector_in(S01_AXI_wvalid);
    mp_S01_AXI_wvalid_converter->scalar_out(m_S01_AXI_wvalid_converter_signal);
    mp_S01_AXI_transactor->WVALID(m_S01_AXI_wvalid_converter_signal);
    mp_S01_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_wready_converter");
    mp_S01_AXI_wready_converter->scalar_in(m_S01_AXI_wready_converter_signal);
    mp_S01_AXI_wready_converter->vector_out(S01_AXI_wready);
    mp_S01_AXI_transactor->WREADY(m_S01_AXI_wready_converter_signal);
    mp_S01_AXI_transactor->BRESP(S01_AXI_bresp);
    mp_S01_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_bvalid_converter");
    mp_S01_AXI_bvalid_converter->scalar_in(m_S01_AXI_bvalid_converter_signal);
    mp_S01_AXI_bvalid_converter->vector_out(S01_AXI_bvalid);
    mp_S01_AXI_transactor->BVALID(m_S01_AXI_bvalid_converter_signal);
    mp_S01_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_bready_converter");
    mp_S01_AXI_bready_converter->vector_in(S01_AXI_bready);
    mp_S01_AXI_bready_converter->scalar_out(m_S01_AXI_bready_converter_signal);
    mp_S01_AXI_transactor->BREADY(m_S01_AXI_bready_converter_signal);
    mp_S01_AXI_transactor->ARADDR(S01_AXI_araddr);
    mp_S01_AXI_transactor->ARLEN(S01_AXI_arlen);
    mp_S01_AXI_transactor->ARSIZE(S01_AXI_arsize);
    mp_S01_AXI_transactor->ARBURST(S01_AXI_arburst);
    mp_S01_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arlock_converter");
    mp_S01_AXI_arlock_converter->vector_in(S01_AXI_arlock);
    mp_S01_AXI_arlock_converter->scalar_out(m_S01_AXI_arlock_converter_signal);
    mp_S01_AXI_transactor->ARLOCK(m_S01_AXI_arlock_converter_signal);
    mp_S01_AXI_transactor->ARCACHE(S01_AXI_arcache);
    mp_S01_AXI_transactor->ARPROT(S01_AXI_arprot);
    mp_S01_AXI_transactor->ARREGION(S01_AXI_arregion);
    mp_S01_AXI_transactor->ARQOS(S01_AXI_arqos);
    mp_S01_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arvalid_converter");
    mp_S01_AXI_arvalid_converter->vector_in(S01_AXI_arvalid);
    mp_S01_AXI_arvalid_converter->scalar_out(m_S01_AXI_arvalid_converter_signal);
    mp_S01_AXI_transactor->ARVALID(m_S01_AXI_arvalid_converter_signal);
    mp_S01_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_arready_converter");
    mp_S01_AXI_arready_converter->scalar_in(m_S01_AXI_arready_converter_signal);
    mp_S01_AXI_arready_converter->vector_out(S01_AXI_arready);
    mp_S01_AXI_transactor->ARREADY(m_S01_AXI_arready_converter_signal);
    mp_S01_AXI_transactor->RDATA(S01_AXI_rdata);
    mp_S01_AXI_transactor->RRESP(S01_AXI_rresp);
    mp_S01_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rlast_converter");
    mp_S01_AXI_rlast_converter->scalar_in(m_S01_AXI_rlast_converter_signal);
    mp_S01_AXI_rlast_converter->vector_out(S01_AXI_rlast);
    mp_S01_AXI_transactor->RLAST(m_S01_AXI_rlast_converter_signal);
    mp_S01_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rvalid_converter");
    mp_S01_AXI_rvalid_converter->scalar_in(m_S01_AXI_rvalid_converter_signal);
    mp_S01_AXI_rvalid_converter->vector_out(S01_AXI_rvalid);
    mp_S01_AXI_transactor->RVALID(m_S01_AXI_rvalid_converter_signal);
    mp_S01_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_rready_converter");
    mp_S01_AXI_rready_converter->vector_in(S01_AXI_rready);
    mp_S01_AXI_rready_converter->scalar_out(m_S01_AXI_rready_converter_signal);
    mp_S01_AXI_transactor->RREADY(m_S01_AXI_rready_converter_signal);
    mp_S01_AXI_transactor->ARID(S01_AXI_arid);
    mp_S01_AXI_transactor->ARUSER(S01_AXI_aruser);
    mp_S01_AXI_transactor->AWID(S01_AXI_awid);
    mp_S01_AXI_transactor->AWUSER(S01_AXI_awuser);
    mp_S01_AXI_transactor->BID(S01_AXI_bid);
    mp_S01_AXI_transactor->RID(S01_AXI_rid);
    mp_S01_AXI_transactor->RUSER(S01_AXI_ruser);
    mp_S01_AXI_transactor->WUSER(S01_AXI_wuser);
    mp_S01_AXI_transactor->CLK(aclk1);
    m_S01_AXI_transactor_rst_signal.write(1);
    mp_S01_AXI_transactor->RST(m_S01_AXI_transactor_rst_signal);

    // S01_AXI' transactor sockets

    mp_impl->S01_AXI_tlm_aximm_read_socket->bind(*(mp_S01_AXI_transactor->rd_socket));
    mp_impl->S01_AXI_tlm_aximm_write_socket->bind(*(mp_S01_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S02_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S02_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S02_AXI' transactor parameters
    xsc::common_cpp::properties S02_AXI_transactor_param_props;
    S02_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S02_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S02_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S02_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S02_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S02_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S02_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S02_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S02_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S02_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S02_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S02_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S02_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S02_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S02_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S02_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S02_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S02_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk");
    S02_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S02_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S02_AXI_transactor_param_props.addString("REGION", "0");
    S02_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S02_AXI_transactor_param_props.addString("DEST_IDS", "");
    S02_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S02_AXI_transactor_param_props.addString("REMAPS", "");
    S02_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S02_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S02_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S02_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S02_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S02_AXI_transactor", S02_AXI_transactor_param_props);

    // S02_AXI' transactor ports

    mp_S02_AXI_transactor->AWADDR(S02_AXI_awaddr);
    mp_S02_AXI_transactor->AWLEN(S02_AXI_awlen);
    mp_S02_AXI_transactor->AWSIZE(S02_AXI_awsize);
    mp_S02_AXI_transactor->AWBURST(S02_AXI_awburst);
    mp_S02_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awlock_converter");
    mp_S02_AXI_awlock_converter->vector_in(S02_AXI_awlock);
    mp_S02_AXI_awlock_converter->scalar_out(m_S02_AXI_awlock_converter_signal);
    mp_S02_AXI_transactor->AWLOCK(m_S02_AXI_awlock_converter_signal);
    mp_S02_AXI_transactor->AWCACHE(S02_AXI_awcache);
    mp_S02_AXI_transactor->AWPROT(S02_AXI_awprot);
    mp_S02_AXI_transactor->AWREGION(S02_AXI_awregion);
    mp_S02_AXI_transactor->AWQOS(S02_AXI_awqos);
    mp_S02_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awvalid_converter");
    mp_S02_AXI_awvalid_converter->vector_in(S02_AXI_awvalid);
    mp_S02_AXI_awvalid_converter->scalar_out(m_S02_AXI_awvalid_converter_signal);
    mp_S02_AXI_transactor->AWVALID(m_S02_AXI_awvalid_converter_signal);
    mp_S02_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_awready_converter");
    mp_S02_AXI_awready_converter->scalar_in(m_S02_AXI_awready_converter_signal);
    mp_S02_AXI_awready_converter->vector_out(S02_AXI_awready);
    mp_S02_AXI_transactor->AWREADY(m_S02_AXI_awready_converter_signal);
    mp_S02_AXI_transactor->WDATA(S02_AXI_wdata);
    mp_S02_AXI_transactor->WSTRB(S02_AXI_wstrb);
    mp_S02_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wlast_converter");
    mp_S02_AXI_wlast_converter->vector_in(S02_AXI_wlast);
    mp_S02_AXI_wlast_converter->scalar_out(m_S02_AXI_wlast_converter_signal);
    mp_S02_AXI_transactor->WLAST(m_S02_AXI_wlast_converter_signal);
    mp_S02_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wvalid_converter");
    mp_S02_AXI_wvalid_converter->vector_in(S02_AXI_wvalid);
    mp_S02_AXI_wvalid_converter->scalar_out(m_S02_AXI_wvalid_converter_signal);
    mp_S02_AXI_transactor->WVALID(m_S02_AXI_wvalid_converter_signal);
    mp_S02_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_wready_converter");
    mp_S02_AXI_wready_converter->scalar_in(m_S02_AXI_wready_converter_signal);
    mp_S02_AXI_wready_converter->vector_out(S02_AXI_wready);
    mp_S02_AXI_transactor->WREADY(m_S02_AXI_wready_converter_signal);
    mp_S02_AXI_transactor->BRESP(S02_AXI_bresp);
    mp_S02_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_bvalid_converter");
    mp_S02_AXI_bvalid_converter->scalar_in(m_S02_AXI_bvalid_converter_signal);
    mp_S02_AXI_bvalid_converter->vector_out(S02_AXI_bvalid);
    mp_S02_AXI_transactor->BVALID(m_S02_AXI_bvalid_converter_signal);
    mp_S02_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_bready_converter");
    mp_S02_AXI_bready_converter->vector_in(S02_AXI_bready);
    mp_S02_AXI_bready_converter->scalar_out(m_S02_AXI_bready_converter_signal);
    mp_S02_AXI_transactor->BREADY(m_S02_AXI_bready_converter_signal);
    mp_S02_AXI_transactor->ARADDR(S02_AXI_araddr);
    mp_S02_AXI_transactor->ARLEN(S02_AXI_arlen);
    mp_S02_AXI_transactor->ARSIZE(S02_AXI_arsize);
    mp_S02_AXI_transactor->ARBURST(S02_AXI_arburst);
    mp_S02_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arlock_converter");
    mp_S02_AXI_arlock_converter->vector_in(S02_AXI_arlock);
    mp_S02_AXI_arlock_converter->scalar_out(m_S02_AXI_arlock_converter_signal);
    mp_S02_AXI_transactor->ARLOCK(m_S02_AXI_arlock_converter_signal);
    mp_S02_AXI_transactor->ARCACHE(S02_AXI_arcache);
    mp_S02_AXI_transactor->ARPROT(S02_AXI_arprot);
    mp_S02_AXI_transactor->ARREGION(S02_AXI_arregion);
    mp_S02_AXI_transactor->ARQOS(S02_AXI_arqos);
    mp_S02_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arvalid_converter");
    mp_S02_AXI_arvalid_converter->vector_in(S02_AXI_arvalid);
    mp_S02_AXI_arvalid_converter->scalar_out(m_S02_AXI_arvalid_converter_signal);
    mp_S02_AXI_transactor->ARVALID(m_S02_AXI_arvalid_converter_signal);
    mp_S02_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_arready_converter");
    mp_S02_AXI_arready_converter->scalar_in(m_S02_AXI_arready_converter_signal);
    mp_S02_AXI_arready_converter->vector_out(S02_AXI_arready);
    mp_S02_AXI_transactor->ARREADY(m_S02_AXI_arready_converter_signal);
    mp_S02_AXI_transactor->RDATA(S02_AXI_rdata);
    mp_S02_AXI_transactor->RRESP(S02_AXI_rresp);
    mp_S02_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rlast_converter");
    mp_S02_AXI_rlast_converter->scalar_in(m_S02_AXI_rlast_converter_signal);
    mp_S02_AXI_rlast_converter->vector_out(S02_AXI_rlast);
    mp_S02_AXI_transactor->RLAST(m_S02_AXI_rlast_converter_signal);
    mp_S02_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rvalid_converter");
    mp_S02_AXI_rvalid_converter->scalar_in(m_S02_AXI_rvalid_converter_signal);
    mp_S02_AXI_rvalid_converter->vector_out(S02_AXI_rvalid);
    mp_S02_AXI_transactor->RVALID(m_S02_AXI_rvalid_converter_signal);
    mp_S02_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_rready_converter");
    mp_S02_AXI_rready_converter->vector_in(S02_AXI_rready);
    mp_S02_AXI_rready_converter->scalar_out(m_S02_AXI_rready_converter_signal);
    mp_S02_AXI_transactor->RREADY(m_S02_AXI_rready_converter_signal);
    mp_S02_AXI_transactor->ARID(S02_AXI_arid);
    mp_S02_AXI_transactor->ARUSER(S02_AXI_aruser);
    mp_S02_AXI_transactor->AWID(S02_AXI_awid);
    mp_S02_AXI_transactor->AWUSER(S02_AXI_awuser);
    mp_S02_AXI_transactor->BID(S02_AXI_bid);
    mp_S02_AXI_transactor->RID(S02_AXI_rid);
    mp_S02_AXI_transactor->RUSER(S02_AXI_ruser);
    mp_S02_AXI_transactor->WUSER(S02_AXI_wuser);
    mp_S02_AXI_transactor->CLK(aclk2);
    m_S02_AXI_transactor_rst_signal.write(1);
    mp_S02_AXI_transactor->RST(m_S02_AXI_transactor_rst_signal);

    // S02_AXI' transactor sockets

    mp_impl->S02_AXI_tlm_aximm_read_socket->bind(*(mp_S02_AXI_transactor->rd_socket));
    mp_impl->S02_AXI_tlm_aximm_write_socket->bind(*(mp_S02_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S03_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S03_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S03_AXI' transactor parameters
    xsc::common_cpp::properties S03_AXI_transactor_param_props;
    S03_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S03_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S03_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S03_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S03_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S03_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S03_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S03_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S03_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S03_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S03_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S03_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S03_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S03_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S03_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S03_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S03_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S03_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk");
    S03_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S03_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S03_AXI_transactor_param_props.addString("REGION", "0");
    S03_AXI_transactor_param_props.addString("CONNECTIONS", "MC_1 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S03_AXI_transactor_param_props.addString("DEST_IDS", "");
    S03_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S03_AXI_transactor_param_props.addString("REMAPS", "");
    S03_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S03_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S03_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S03_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S03_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S03_AXI_transactor", S03_AXI_transactor_param_props);

    // S03_AXI' transactor ports

    mp_S03_AXI_transactor->AWADDR(S03_AXI_awaddr);
    mp_S03_AXI_transactor->AWLEN(S03_AXI_awlen);
    mp_S03_AXI_transactor->AWSIZE(S03_AXI_awsize);
    mp_S03_AXI_transactor->AWBURST(S03_AXI_awburst);
    mp_S03_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awlock_converter");
    mp_S03_AXI_awlock_converter->vector_in(S03_AXI_awlock);
    mp_S03_AXI_awlock_converter->scalar_out(m_S03_AXI_awlock_converter_signal);
    mp_S03_AXI_transactor->AWLOCK(m_S03_AXI_awlock_converter_signal);
    mp_S03_AXI_transactor->AWCACHE(S03_AXI_awcache);
    mp_S03_AXI_transactor->AWPROT(S03_AXI_awprot);
    mp_S03_AXI_transactor->AWREGION(S03_AXI_awregion);
    mp_S03_AXI_transactor->AWQOS(S03_AXI_awqos);
    mp_S03_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awvalid_converter");
    mp_S03_AXI_awvalid_converter->vector_in(S03_AXI_awvalid);
    mp_S03_AXI_awvalid_converter->scalar_out(m_S03_AXI_awvalid_converter_signal);
    mp_S03_AXI_transactor->AWVALID(m_S03_AXI_awvalid_converter_signal);
    mp_S03_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_awready_converter");
    mp_S03_AXI_awready_converter->scalar_in(m_S03_AXI_awready_converter_signal);
    mp_S03_AXI_awready_converter->vector_out(S03_AXI_awready);
    mp_S03_AXI_transactor->AWREADY(m_S03_AXI_awready_converter_signal);
    mp_S03_AXI_transactor->WDATA(S03_AXI_wdata);
    mp_S03_AXI_transactor->WSTRB(S03_AXI_wstrb);
    mp_S03_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wlast_converter");
    mp_S03_AXI_wlast_converter->vector_in(S03_AXI_wlast);
    mp_S03_AXI_wlast_converter->scalar_out(m_S03_AXI_wlast_converter_signal);
    mp_S03_AXI_transactor->WLAST(m_S03_AXI_wlast_converter_signal);
    mp_S03_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wvalid_converter");
    mp_S03_AXI_wvalid_converter->vector_in(S03_AXI_wvalid);
    mp_S03_AXI_wvalid_converter->scalar_out(m_S03_AXI_wvalid_converter_signal);
    mp_S03_AXI_transactor->WVALID(m_S03_AXI_wvalid_converter_signal);
    mp_S03_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_wready_converter");
    mp_S03_AXI_wready_converter->scalar_in(m_S03_AXI_wready_converter_signal);
    mp_S03_AXI_wready_converter->vector_out(S03_AXI_wready);
    mp_S03_AXI_transactor->WREADY(m_S03_AXI_wready_converter_signal);
    mp_S03_AXI_transactor->BRESP(S03_AXI_bresp);
    mp_S03_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_bvalid_converter");
    mp_S03_AXI_bvalid_converter->scalar_in(m_S03_AXI_bvalid_converter_signal);
    mp_S03_AXI_bvalid_converter->vector_out(S03_AXI_bvalid);
    mp_S03_AXI_transactor->BVALID(m_S03_AXI_bvalid_converter_signal);
    mp_S03_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_bready_converter");
    mp_S03_AXI_bready_converter->vector_in(S03_AXI_bready);
    mp_S03_AXI_bready_converter->scalar_out(m_S03_AXI_bready_converter_signal);
    mp_S03_AXI_transactor->BREADY(m_S03_AXI_bready_converter_signal);
    mp_S03_AXI_transactor->ARADDR(S03_AXI_araddr);
    mp_S03_AXI_transactor->ARLEN(S03_AXI_arlen);
    mp_S03_AXI_transactor->ARSIZE(S03_AXI_arsize);
    mp_S03_AXI_transactor->ARBURST(S03_AXI_arburst);
    mp_S03_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arlock_converter");
    mp_S03_AXI_arlock_converter->vector_in(S03_AXI_arlock);
    mp_S03_AXI_arlock_converter->scalar_out(m_S03_AXI_arlock_converter_signal);
    mp_S03_AXI_transactor->ARLOCK(m_S03_AXI_arlock_converter_signal);
    mp_S03_AXI_transactor->ARCACHE(S03_AXI_arcache);
    mp_S03_AXI_transactor->ARPROT(S03_AXI_arprot);
    mp_S03_AXI_transactor->ARREGION(S03_AXI_arregion);
    mp_S03_AXI_transactor->ARQOS(S03_AXI_arqos);
    mp_S03_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arvalid_converter");
    mp_S03_AXI_arvalid_converter->vector_in(S03_AXI_arvalid);
    mp_S03_AXI_arvalid_converter->scalar_out(m_S03_AXI_arvalid_converter_signal);
    mp_S03_AXI_transactor->ARVALID(m_S03_AXI_arvalid_converter_signal);
    mp_S03_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_arready_converter");
    mp_S03_AXI_arready_converter->scalar_in(m_S03_AXI_arready_converter_signal);
    mp_S03_AXI_arready_converter->vector_out(S03_AXI_arready);
    mp_S03_AXI_transactor->ARREADY(m_S03_AXI_arready_converter_signal);
    mp_S03_AXI_transactor->RDATA(S03_AXI_rdata);
    mp_S03_AXI_transactor->RRESP(S03_AXI_rresp);
    mp_S03_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rlast_converter");
    mp_S03_AXI_rlast_converter->scalar_in(m_S03_AXI_rlast_converter_signal);
    mp_S03_AXI_rlast_converter->vector_out(S03_AXI_rlast);
    mp_S03_AXI_transactor->RLAST(m_S03_AXI_rlast_converter_signal);
    mp_S03_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rvalid_converter");
    mp_S03_AXI_rvalid_converter->scalar_in(m_S03_AXI_rvalid_converter_signal);
    mp_S03_AXI_rvalid_converter->vector_out(S03_AXI_rvalid);
    mp_S03_AXI_transactor->RVALID(m_S03_AXI_rvalid_converter_signal);
    mp_S03_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_rready_converter");
    mp_S03_AXI_rready_converter->vector_in(S03_AXI_rready);
    mp_S03_AXI_rready_converter->scalar_out(m_S03_AXI_rready_converter_signal);
    mp_S03_AXI_transactor->RREADY(m_S03_AXI_rready_converter_signal);
    mp_S03_AXI_transactor->ARID(S03_AXI_arid);
    mp_S03_AXI_transactor->ARUSER(S03_AXI_aruser);
    mp_S03_AXI_transactor->AWID(S03_AXI_awid);
    mp_S03_AXI_transactor->AWUSER(S03_AXI_awuser);
    mp_S03_AXI_transactor->BID(S03_AXI_bid);
    mp_S03_AXI_transactor->RID(S03_AXI_rid);
    mp_S03_AXI_transactor->RUSER(S03_AXI_ruser);
    mp_S03_AXI_transactor->WUSER(S03_AXI_wuser);
    mp_S03_AXI_transactor->CLK(aclk3);
    m_S03_AXI_transactor_rst_signal.write(1);
    mp_S03_AXI_transactor->RST(m_S03_AXI_transactor_rst_signal);

    // S03_AXI' transactor sockets

    mp_impl->S03_AXI_tlm_aximm_read_socket->bind(*(mp_S03_AXI_transactor->rd_socket));
    mp_impl->S03_AXI_tlm_aximm_write_socket->bind(*(mp_S03_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S04_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S04_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S04_AXI' transactor parameters
    xsc::common_cpp::properties S04_AXI_transactor_param_props;
    S04_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S04_AXI_transactor_param_props.addLong("FREQ_HZ", "400000000");
    S04_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S04_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S04_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S04_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S04_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S04_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S04_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S04_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S04_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S04_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S04_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S04_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S04_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S04_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S04_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S04_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_lpd_axi_noc_clk");
    S04_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S04_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S04_AXI_transactor_param_props.addString("REGION", "0");
    S04_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S04_AXI_transactor_param_props.addString("DEST_IDS", "");
    S04_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S04_AXI_transactor_param_props.addString("REMAPS", "");
    S04_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S04_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S04_AXI_transactor_param_props.addString("CATEGORY", "ps_rpu");
    S04_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S04_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S04_AXI_transactor", S04_AXI_transactor_param_props);

    // S04_AXI' transactor ports

    mp_S04_AXI_transactor->AWADDR(S04_AXI_awaddr);
    mp_S04_AXI_transactor->AWLEN(S04_AXI_awlen);
    mp_S04_AXI_transactor->AWSIZE(S04_AXI_awsize);
    mp_S04_AXI_transactor->AWBURST(S04_AXI_awburst);
    mp_S04_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awlock_converter");
    mp_S04_AXI_awlock_converter->vector_in(S04_AXI_awlock);
    mp_S04_AXI_awlock_converter->scalar_out(m_S04_AXI_awlock_converter_signal);
    mp_S04_AXI_transactor->AWLOCK(m_S04_AXI_awlock_converter_signal);
    mp_S04_AXI_transactor->AWCACHE(S04_AXI_awcache);
    mp_S04_AXI_transactor->AWPROT(S04_AXI_awprot);
    mp_S04_AXI_transactor->AWREGION(S04_AXI_awregion);
    mp_S04_AXI_transactor->AWQOS(S04_AXI_awqos);
    mp_S04_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awvalid_converter");
    mp_S04_AXI_awvalid_converter->vector_in(S04_AXI_awvalid);
    mp_S04_AXI_awvalid_converter->scalar_out(m_S04_AXI_awvalid_converter_signal);
    mp_S04_AXI_transactor->AWVALID(m_S04_AXI_awvalid_converter_signal);
    mp_S04_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_awready_converter");
    mp_S04_AXI_awready_converter->scalar_in(m_S04_AXI_awready_converter_signal);
    mp_S04_AXI_awready_converter->vector_out(S04_AXI_awready);
    mp_S04_AXI_transactor->AWREADY(m_S04_AXI_awready_converter_signal);
    mp_S04_AXI_transactor->WDATA(S04_AXI_wdata);
    mp_S04_AXI_transactor->WSTRB(S04_AXI_wstrb);
    mp_S04_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wlast_converter");
    mp_S04_AXI_wlast_converter->vector_in(S04_AXI_wlast);
    mp_S04_AXI_wlast_converter->scalar_out(m_S04_AXI_wlast_converter_signal);
    mp_S04_AXI_transactor->WLAST(m_S04_AXI_wlast_converter_signal);
    mp_S04_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wvalid_converter");
    mp_S04_AXI_wvalid_converter->vector_in(S04_AXI_wvalid);
    mp_S04_AXI_wvalid_converter->scalar_out(m_S04_AXI_wvalid_converter_signal);
    mp_S04_AXI_transactor->WVALID(m_S04_AXI_wvalid_converter_signal);
    mp_S04_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_wready_converter");
    mp_S04_AXI_wready_converter->scalar_in(m_S04_AXI_wready_converter_signal);
    mp_S04_AXI_wready_converter->vector_out(S04_AXI_wready);
    mp_S04_AXI_transactor->WREADY(m_S04_AXI_wready_converter_signal);
    mp_S04_AXI_transactor->BRESP(S04_AXI_bresp);
    mp_S04_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_bvalid_converter");
    mp_S04_AXI_bvalid_converter->scalar_in(m_S04_AXI_bvalid_converter_signal);
    mp_S04_AXI_bvalid_converter->vector_out(S04_AXI_bvalid);
    mp_S04_AXI_transactor->BVALID(m_S04_AXI_bvalid_converter_signal);
    mp_S04_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_bready_converter");
    mp_S04_AXI_bready_converter->vector_in(S04_AXI_bready);
    mp_S04_AXI_bready_converter->scalar_out(m_S04_AXI_bready_converter_signal);
    mp_S04_AXI_transactor->BREADY(m_S04_AXI_bready_converter_signal);
    mp_S04_AXI_transactor->ARADDR(S04_AXI_araddr);
    mp_S04_AXI_transactor->ARLEN(S04_AXI_arlen);
    mp_S04_AXI_transactor->ARSIZE(S04_AXI_arsize);
    mp_S04_AXI_transactor->ARBURST(S04_AXI_arburst);
    mp_S04_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arlock_converter");
    mp_S04_AXI_arlock_converter->vector_in(S04_AXI_arlock);
    mp_S04_AXI_arlock_converter->scalar_out(m_S04_AXI_arlock_converter_signal);
    mp_S04_AXI_transactor->ARLOCK(m_S04_AXI_arlock_converter_signal);
    mp_S04_AXI_transactor->ARCACHE(S04_AXI_arcache);
    mp_S04_AXI_transactor->ARPROT(S04_AXI_arprot);
    mp_S04_AXI_transactor->ARREGION(S04_AXI_arregion);
    mp_S04_AXI_transactor->ARQOS(S04_AXI_arqos);
    mp_S04_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arvalid_converter");
    mp_S04_AXI_arvalid_converter->vector_in(S04_AXI_arvalid);
    mp_S04_AXI_arvalid_converter->scalar_out(m_S04_AXI_arvalid_converter_signal);
    mp_S04_AXI_transactor->ARVALID(m_S04_AXI_arvalid_converter_signal);
    mp_S04_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_arready_converter");
    mp_S04_AXI_arready_converter->scalar_in(m_S04_AXI_arready_converter_signal);
    mp_S04_AXI_arready_converter->vector_out(S04_AXI_arready);
    mp_S04_AXI_transactor->ARREADY(m_S04_AXI_arready_converter_signal);
    mp_S04_AXI_transactor->RDATA(S04_AXI_rdata);
    mp_S04_AXI_transactor->RRESP(S04_AXI_rresp);
    mp_S04_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rlast_converter");
    mp_S04_AXI_rlast_converter->scalar_in(m_S04_AXI_rlast_converter_signal);
    mp_S04_AXI_rlast_converter->vector_out(S04_AXI_rlast);
    mp_S04_AXI_transactor->RLAST(m_S04_AXI_rlast_converter_signal);
    mp_S04_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rvalid_converter");
    mp_S04_AXI_rvalid_converter->scalar_in(m_S04_AXI_rvalid_converter_signal);
    mp_S04_AXI_rvalid_converter->vector_out(S04_AXI_rvalid);
    mp_S04_AXI_transactor->RVALID(m_S04_AXI_rvalid_converter_signal);
    mp_S04_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_rready_converter");
    mp_S04_AXI_rready_converter->vector_in(S04_AXI_rready);
    mp_S04_AXI_rready_converter->scalar_out(m_S04_AXI_rready_converter_signal);
    mp_S04_AXI_transactor->RREADY(m_S04_AXI_rready_converter_signal);
    mp_S04_AXI_transactor->ARID(S04_AXI_arid);
    mp_S04_AXI_transactor->ARUSER(S04_AXI_aruser);
    mp_S04_AXI_transactor->AWID(S04_AXI_awid);
    mp_S04_AXI_transactor->AWUSER(S04_AXI_awuser);
    mp_S04_AXI_transactor->BID(S04_AXI_bid);
    mp_S04_AXI_transactor->RID(S04_AXI_rid);
    mp_S04_AXI_transactor->RUSER(S04_AXI_ruser);
    mp_S04_AXI_transactor->WUSER(S04_AXI_wuser);
    mp_S04_AXI_transactor->CLK(aclk4);
    m_S04_AXI_transactor_rst_signal.write(1);
    mp_S04_AXI_transactor->RST(m_S04_AXI_transactor_rst_signal);

    // S04_AXI' transactor sockets

    mp_impl->S04_AXI_tlm_aximm_read_socket->bind(*(mp_S04_AXI_transactor->rd_socket));
    mp_impl->S04_AXI_tlm_aximm_write_socket->bind(*(mp_S04_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S05_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S05_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S05_AXI' transactor parameters
    xsc::common_cpp::properties S05_AXI_transactor_param_props;
    S05_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S05_AXI_transactor_param_props.addLong("FREQ_HZ", "320000000");
    S05_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S05_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("BUSER_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S05_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S05_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S05_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S05_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S05_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S05_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S05_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S05_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S05_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S05_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S05_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S05_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk");
    S05_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S05_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S05_AXI_transactor_param_props.addString("REGION", "0");
    S05_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S05_AXI_transactor_param_props.addString("DEST_IDS", "");
    S05_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S05_AXI_transactor_param_props.addString("REMAPS", "");
    S05_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S05_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S05_AXI_transactor_param_props.addString("CATEGORY", "ps_pmc");
    S05_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S05_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,16,18,17>("S05_AXI_transactor", S05_AXI_transactor_param_props);

    // S05_AXI' transactor ports

    mp_S05_AXI_transactor->AWADDR(S05_AXI_awaddr);
    mp_S05_AXI_transactor->AWLEN(S05_AXI_awlen);
    mp_S05_AXI_transactor->AWSIZE(S05_AXI_awsize);
    mp_S05_AXI_transactor->AWBURST(S05_AXI_awburst);
    mp_S05_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awlock_converter");
    mp_S05_AXI_awlock_converter->vector_in(S05_AXI_awlock);
    mp_S05_AXI_awlock_converter->scalar_out(m_S05_AXI_awlock_converter_signal);
    mp_S05_AXI_transactor->AWLOCK(m_S05_AXI_awlock_converter_signal);
    mp_S05_AXI_transactor->AWCACHE(S05_AXI_awcache);
    mp_S05_AXI_transactor->AWPROT(S05_AXI_awprot);
    mp_S05_AXI_transactor->AWREGION(S05_AXI_awregion);
    mp_S05_AXI_transactor->AWQOS(S05_AXI_awqos);
    mp_S05_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awvalid_converter");
    mp_S05_AXI_awvalid_converter->vector_in(S05_AXI_awvalid);
    mp_S05_AXI_awvalid_converter->scalar_out(m_S05_AXI_awvalid_converter_signal);
    mp_S05_AXI_transactor->AWVALID(m_S05_AXI_awvalid_converter_signal);
    mp_S05_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_awready_converter");
    mp_S05_AXI_awready_converter->scalar_in(m_S05_AXI_awready_converter_signal);
    mp_S05_AXI_awready_converter->vector_out(S05_AXI_awready);
    mp_S05_AXI_transactor->AWREADY(m_S05_AXI_awready_converter_signal);
    mp_S05_AXI_transactor->WDATA(S05_AXI_wdata);
    mp_S05_AXI_transactor->WSTRB(S05_AXI_wstrb);
    mp_S05_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wlast_converter");
    mp_S05_AXI_wlast_converter->vector_in(S05_AXI_wlast);
    mp_S05_AXI_wlast_converter->scalar_out(m_S05_AXI_wlast_converter_signal);
    mp_S05_AXI_transactor->WLAST(m_S05_AXI_wlast_converter_signal);
    mp_S05_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wvalid_converter");
    mp_S05_AXI_wvalid_converter->vector_in(S05_AXI_wvalid);
    mp_S05_AXI_wvalid_converter->scalar_out(m_S05_AXI_wvalid_converter_signal);
    mp_S05_AXI_transactor->WVALID(m_S05_AXI_wvalid_converter_signal);
    mp_S05_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_wready_converter");
    mp_S05_AXI_wready_converter->scalar_in(m_S05_AXI_wready_converter_signal);
    mp_S05_AXI_wready_converter->vector_out(S05_AXI_wready);
    mp_S05_AXI_transactor->WREADY(m_S05_AXI_wready_converter_signal);
    mp_S05_AXI_transactor->BRESP(S05_AXI_bresp);
    mp_S05_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_bvalid_converter");
    mp_S05_AXI_bvalid_converter->scalar_in(m_S05_AXI_bvalid_converter_signal);
    mp_S05_AXI_bvalid_converter->vector_out(S05_AXI_bvalid);
    mp_S05_AXI_transactor->BVALID(m_S05_AXI_bvalid_converter_signal);
    mp_S05_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_bready_converter");
    mp_S05_AXI_bready_converter->vector_in(S05_AXI_bready);
    mp_S05_AXI_bready_converter->scalar_out(m_S05_AXI_bready_converter_signal);
    mp_S05_AXI_transactor->BREADY(m_S05_AXI_bready_converter_signal);
    mp_S05_AXI_transactor->ARADDR(S05_AXI_araddr);
    mp_S05_AXI_transactor->ARLEN(S05_AXI_arlen);
    mp_S05_AXI_transactor->ARSIZE(S05_AXI_arsize);
    mp_S05_AXI_transactor->ARBURST(S05_AXI_arburst);
    mp_S05_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arlock_converter");
    mp_S05_AXI_arlock_converter->vector_in(S05_AXI_arlock);
    mp_S05_AXI_arlock_converter->scalar_out(m_S05_AXI_arlock_converter_signal);
    mp_S05_AXI_transactor->ARLOCK(m_S05_AXI_arlock_converter_signal);
    mp_S05_AXI_transactor->ARCACHE(S05_AXI_arcache);
    mp_S05_AXI_transactor->ARPROT(S05_AXI_arprot);
    mp_S05_AXI_transactor->ARREGION(S05_AXI_arregion);
    mp_S05_AXI_transactor->ARQOS(S05_AXI_arqos);
    mp_S05_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arvalid_converter");
    mp_S05_AXI_arvalid_converter->vector_in(S05_AXI_arvalid);
    mp_S05_AXI_arvalid_converter->scalar_out(m_S05_AXI_arvalid_converter_signal);
    mp_S05_AXI_transactor->ARVALID(m_S05_AXI_arvalid_converter_signal);
    mp_S05_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_arready_converter");
    mp_S05_AXI_arready_converter->scalar_in(m_S05_AXI_arready_converter_signal);
    mp_S05_AXI_arready_converter->vector_out(S05_AXI_arready);
    mp_S05_AXI_transactor->ARREADY(m_S05_AXI_arready_converter_signal);
    mp_S05_AXI_transactor->RDATA(S05_AXI_rdata);
    mp_S05_AXI_transactor->RRESP(S05_AXI_rresp);
    mp_S05_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rlast_converter");
    mp_S05_AXI_rlast_converter->scalar_in(m_S05_AXI_rlast_converter_signal);
    mp_S05_AXI_rlast_converter->vector_out(S05_AXI_rlast);
    mp_S05_AXI_transactor->RLAST(m_S05_AXI_rlast_converter_signal);
    mp_S05_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rvalid_converter");
    mp_S05_AXI_rvalid_converter->scalar_in(m_S05_AXI_rvalid_converter_signal);
    mp_S05_AXI_rvalid_converter->vector_out(S05_AXI_rvalid);
    mp_S05_AXI_transactor->RVALID(m_S05_AXI_rvalid_converter_signal);
    mp_S05_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_rready_converter");
    mp_S05_AXI_rready_converter->vector_in(S05_AXI_rready);
    mp_S05_AXI_rready_converter->scalar_out(m_S05_AXI_rready_converter_signal);
    mp_S05_AXI_transactor->RREADY(m_S05_AXI_rready_converter_signal);
    mp_S05_AXI_transactor->ARID(S05_AXI_arid);
    mp_S05_AXI_transactor->ARUSER(S05_AXI_aruser);
    mp_S05_AXI_transactor->AWID(S05_AXI_awid);
    mp_S05_AXI_transactor->AWUSER(S05_AXI_awuser);
    mp_S05_AXI_transactor->BID(S05_AXI_bid);
    mp_S05_AXI_transactor->BUSER(S05_AXI_buser);
    mp_S05_AXI_transactor->RID(S05_AXI_rid);
    mp_S05_AXI_transactor->RUSER(S05_AXI_ruser);
    mp_S05_AXI_transactor->WUSER(S05_AXI_wuser);
    mp_S05_AXI_transactor->CLK(aclk5);
    m_S05_AXI_transactor_rst_signal.write(1);
    mp_S05_AXI_transactor->RST(m_S05_AXI_transactor_rst_signal);

    // S05_AXI' transactor sockets

    mp_impl->S05_AXI_tlm_aximm_read_socket->bind(*(mp_S05_AXI_transactor->rd_socket));
    mp_impl->S05_AXI_tlm_aximm_write_socket->bind(*(mp_S05_AXI_transactor->wr_socket));
  }
  else
  {
  }

  // configure 'S06_AXI' transactor

  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S06_AXI_TLM_MODE") != 1)
  {
    // Instantiate Socket Stubs

  // 'S06_AXI' transactor parameters
    xsc::common_cpp::properties S06_AXI_transactor_param_props;
    S06_AXI_transactor_param_props.addLong("DATA_WIDTH", "32");
    S06_AXI_transactor_param_props.addLong("FREQ_HZ", "100000000");
    S06_AXI_transactor_param_props.addLong("ID_WIDTH", "1");
    S06_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S06_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("RUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S06_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S06_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S06_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S06_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S06_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S06_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S06_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S06_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S06_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S06_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S06_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S06_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pl0_ref_clk");
    S06_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S06_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S06_AXI_transactor_param_props.addString("REGION", "");
    S06_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {500} write_bw {500}}");
    S06_AXI_transactor_param_props.addString("DEST_IDS", "");
    S06_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S06_AXI_transactor_param_props.addString("REMAPS", "");
    S06_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S06_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S06_AXI_transactor_param_props.addString("CATEGORY", "pl");
    S06_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S06_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<32,64,1,1,1,1,1,1>("S06_AXI_transactor", S06_AXI_transactor_param_props);

    // S06_AXI' transactor ports

    mp_S06_AXI_transactor->AWADDR(S06_AXI_awaddr);
    mp_S06_AXI_transactor->AWLEN(S06_AXI_awlen);
    mp_S06_AXI_transactor->AWSIZE(S06_AXI_awsize);
    mp_S06_AXI_transactor->AWBURST(S06_AXI_awburst);
    mp_S06_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awlock_converter");
    mp_S06_AXI_awlock_converter->vector_in(S06_AXI_awlock);
    mp_S06_AXI_awlock_converter->scalar_out(m_S06_AXI_awlock_converter_signal);
    mp_S06_AXI_transactor->AWLOCK(m_S06_AXI_awlock_converter_signal);
    mp_S06_AXI_transactor->AWCACHE(S06_AXI_awcache);
    mp_S06_AXI_transactor->AWPROT(S06_AXI_awprot);
    mp_S06_AXI_transactor->AWREGION(S06_AXI_awregion);
    mp_S06_AXI_transactor->AWQOS(S06_AXI_awqos);
    mp_S06_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awvalid_converter");
    mp_S06_AXI_awvalid_converter->vector_in(S06_AXI_awvalid);
    mp_S06_AXI_awvalid_converter->scalar_out(m_S06_AXI_awvalid_converter_signal);
    mp_S06_AXI_transactor->AWVALID(m_S06_AXI_awvalid_converter_signal);
    mp_S06_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_awready_converter");
    mp_S06_AXI_awready_converter->scalar_in(m_S06_AXI_awready_converter_signal);
    mp_S06_AXI_awready_converter->vector_out(S06_AXI_awready);
    mp_S06_AXI_transactor->AWREADY(m_S06_AXI_awready_converter_signal);
    mp_S06_AXI_transactor->WDATA(S06_AXI_wdata);
    mp_S06_AXI_transactor->WSTRB(S06_AXI_wstrb);
    mp_S06_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wlast_converter");
    mp_S06_AXI_wlast_converter->vector_in(S06_AXI_wlast);
    mp_S06_AXI_wlast_converter->scalar_out(m_S06_AXI_wlast_converter_signal);
    mp_S06_AXI_transactor->WLAST(m_S06_AXI_wlast_converter_signal);
    mp_S06_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wvalid_converter");
    mp_S06_AXI_wvalid_converter->vector_in(S06_AXI_wvalid);
    mp_S06_AXI_wvalid_converter->scalar_out(m_S06_AXI_wvalid_converter_signal);
    mp_S06_AXI_transactor->WVALID(m_S06_AXI_wvalid_converter_signal);
    mp_S06_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_wready_converter");
    mp_S06_AXI_wready_converter->scalar_in(m_S06_AXI_wready_converter_signal);
    mp_S06_AXI_wready_converter->vector_out(S06_AXI_wready);
    mp_S06_AXI_transactor->WREADY(m_S06_AXI_wready_converter_signal);
    mp_S06_AXI_transactor->BRESP(S06_AXI_bresp);
    mp_S06_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_bvalid_converter");
    mp_S06_AXI_bvalid_converter->scalar_in(m_S06_AXI_bvalid_converter_signal);
    mp_S06_AXI_bvalid_converter->vector_out(S06_AXI_bvalid);
    mp_S06_AXI_transactor->BVALID(m_S06_AXI_bvalid_converter_signal);
    mp_S06_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_bready_converter");
    mp_S06_AXI_bready_converter->vector_in(S06_AXI_bready);
    mp_S06_AXI_bready_converter->scalar_out(m_S06_AXI_bready_converter_signal);
    mp_S06_AXI_transactor->BREADY(m_S06_AXI_bready_converter_signal);
    mp_S06_AXI_transactor->ARADDR(S06_AXI_araddr);
    mp_S06_AXI_transactor->ARLEN(S06_AXI_arlen);
    mp_S06_AXI_transactor->ARSIZE(S06_AXI_arsize);
    mp_S06_AXI_transactor->ARBURST(S06_AXI_arburst);
    mp_S06_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arlock_converter");
    mp_S06_AXI_arlock_converter->vector_in(S06_AXI_arlock);
    mp_S06_AXI_arlock_converter->scalar_out(m_S06_AXI_arlock_converter_signal);
    mp_S06_AXI_transactor->ARLOCK(m_S06_AXI_arlock_converter_signal);
    mp_S06_AXI_transactor->ARCACHE(S06_AXI_arcache);
    mp_S06_AXI_transactor->ARPROT(S06_AXI_arprot);
    mp_S06_AXI_transactor->ARREGION(S06_AXI_arregion);
    mp_S06_AXI_transactor->ARQOS(S06_AXI_arqos);
    mp_S06_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arvalid_converter");
    mp_S06_AXI_arvalid_converter->vector_in(S06_AXI_arvalid);
    mp_S06_AXI_arvalid_converter->scalar_out(m_S06_AXI_arvalid_converter_signal);
    mp_S06_AXI_transactor->ARVALID(m_S06_AXI_arvalid_converter_signal);
    mp_S06_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_arready_converter");
    mp_S06_AXI_arready_converter->scalar_in(m_S06_AXI_arready_converter_signal);
    mp_S06_AXI_arready_converter->vector_out(S06_AXI_arready);
    mp_S06_AXI_transactor->ARREADY(m_S06_AXI_arready_converter_signal);
    mp_S06_AXI_transactor->RDATA(S06_AXI_rdata);
    mp_S06_AXI_transactor->RRESP(S06_AXI_rresp);
    mp_S06_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rlast_converter");
    mp_S06_AXI_rlast_converter->scalar_in(m_S06_AXI_rlast_converter_signal);
    mp_S06_AXI_rlast_converter->vector_out(S06_AXI_rlast);
    mp_S06_AXI_transactor->RLAST(m_S06_AXI_rlast_converter_signal);
    mp_S06_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rvalid_converter");
    mp_S06_AXI_rvalid_converter->scalar_in(m_S06_AXI_rvalid_converter_signal);
    mp_S06_AXI_rvalid_converter->vector_out(S06_AXI_rvalid);
    mp_S06_AXI_transactor->RVALID(m_S06_AXI_rvalid_converter_signal);
    mp_S06_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_rready_converter");
    mp_S06_AXI_rready_converter->vector_in(S06_AXI_rready);
    mp_S06_AXI_rready_converter->scalar_out(m_S06_AXI_rready_converter_signal);
    mp_S06_AXI_transactor->RREADY(m_S06_AXI_rready_converter_signal);
    mp_S06_AXI_transactor->ARID(S06_AXI_arid);
    mp_S06_AXI_transactor->AWID(S06_AXI_awid);
    mp_S06_AXI_transactor->BID(S06_AXI_bid);
    mp_S06_AXI_transactor->RID(S06_AXI_rid);
    mp_S06_AXI_transactor->CLK(aclk6);
    m_S06_AXI_transactor_rst_signal.write(1);
    mp_S06_AXI_transactor->RST(m_S06_AXI_transactor_rst_signal);

    // S06_AXI' transactor sockets

    mp_impl->S06_AXI_tlm_aximm_read_socket->bind(*(mp_S06_AXI_transactor->rd_socket));
    mp_impl->S06_AXI_tlm_aximm_write_socket->bind(*(mp_S06_AXI_transactor->wr_socket));
  }
  else
  {
  }

}

#endif // RIVIERA




#ifdef VCSSYSTEMC
bd_soc_usart_axi_noc_0_0::bd_soc_usart_axi_noc_0_0(const sc_core::sc_module_name& nm) : bd_soc_usart_axi_noc_0_0_sc(nm),  S00_AXI_awaddr("S00_AXI_awaddr"), S00_AXI_awlen("S00_AXI_awlen"), S00_AXI_awsize("S00_AXI_awsize"), S00_AXI_awburst("S00_AXI_awburst"), S00_AXI_awlock("S00_AXI_awlock"), S00_AXI_awcache("S00_AXI_awcache"), S00_AXI_awprot("S00_AXI_awprot"), S00_AXI_awregion("S00_AXI_awregion"), S00_AXI_awqos("S00_AXI_awqos"), S00_AXI_awvalid("S00_AXI_awvalid"), S00_AXI_awready("S00_AXI_awready"), S00_AXI_wdata("S00_AXI_wdata"), S00_AXI_wstrb("S00_AXI_wstrb"), S00_AXI_wlast("S00_AXI_wlast"), S00_AXI_wvalid("S00_AXI_wvalid"), S00_AXI_wready("S00_AXI_wready"), S00_AXI_bresp("S00_AXI_bresp"), S00_AXI_bvalid("S00_AXI_bvalid"), S00_AXI_bready("S00_AXI_bready"), S00_AXI_araddr("S00_AXI_araddr"), S00_AXI_arlen("S00_AXI_arlen"), S00_AXI_arsize("S00_AXI_arsize"), S00_AXI_arburst("S00_AXI_arburst"), S00_AXI_arlock("S00_AXI_arlock"), S00_AXI_arcache("S00_AXI_arcache"), S00_AXI_arprot("S00_AXI_arprot"), S00_AXI_arregion("S00_AXI_arregion"), S00_AXI_arqos("S00_AXI_arqos"), S00_AXI_arvalid("S00_AXI_arvalid"), S00_AXI_arready("S00_AXI_arready"), S00_AXI_rdata("S00_AXI_rdata"), S00_AXI_rresp("S00_AXI_rresp"), S00_AXI_rlast("S00_AXI_rlast"), S00_AXI_rvalid("S00_AXI_rvalid"), S00_AXI_rready("S00_AXI_rready"), S01_AXI_awaddr("S01_AXI_awaddr"), S01_AXI_awlen("S01_AXI_awlen"), S01_AXI_awsize("S01_AXI_awsize"), S01_AXI_awburst("S01_AXI_awburst"), S01_AXI_awlock("S01_AXI_awlock"), S01_AXI_awcache("S01_AXI_awcache"), S01_AXI_awprot("S01_AXI_awprot"), S01_AXI_awregion("S01_AXI_awregion"), S01_AXI_awqos("S01_AXI_awqos"), S01_AXI_awvalid("S01_AXI_awvalid"), S01_AXI_awready("S01_AXI_awready"), S01_AXI_wdata("S01_AXI_wdata"), S01_AXI_wstrb("S01_AXI_wstrb"), S01_AXI_wlast("S01_AXI_wlast"), S01_AXI_wvalid("S01_AXI_wvalid"), S01_AXI_wready("S01_AXI_wready"), S01_AXI_bresp("S01_AXI_bresp"), S01_AXI_bvalid("S01_AXI_bvalid"), S01_AXI_bready("S01_AXI_bready"), S01_AXI_araddr("S01_AXI_araddr"), S01_AXI_arlen("S01_AXI_arlen"), S01_AXI_arsize("S01_AXI_arsize"), S01_AXI_arburst("S01_AXI_arburst"), S01_AXI_arlock("S01_AXI_arlock"), S01_AXI_arcache("S01_AXI_arcache"), S01_AXI_arprot("S01_AXI_arprot"), S01_AXI_arregion("S01_AXI_arregion"), S01_AXI_arqos("S01_AXI_arqos"), S01_AXI_arvalid("S01_AXI_arvalid"), S01_AXI_arready("S01_AXI_arready"), S01_AXI_rdata("S01_AXI_rdata"), S01_AXI_rresp("S01_AXI_rresp"), S01_AXI_rlast("S01_AXI_rlast"), S01_AXI_rvalid("S01_AXI_rvalid"), S01_AXI_rready("S01_AXI_rready"), S02_AXI_awaddr("S02_AXI_awaddr"), S02_AXI_awlen("S02_AXI_awlen"), S02_AXI_awsize("S02_AXI_awsize"), S02_AXI_awburst("S02_AXI_awburst"), S02_AXI_awlock("S02_AXI_awlock"), S02_AXI_awcache("S02_AXI_awcache"), S02_AXI_awprot("S02_AXI_awprot"), S02_AXI_awregion("S02_AXI_awregion"), S02_AXI_awqos("S02_AXI_awqos"), S02_AXI_awvalid("S02_AXI_awvalid"), S02_AXI_awready("S02_AXI_awready"), S02_AXI_wdata("S02_AXI_wdata"), S02_AXI_wstrb("S02_AXI_wstrb"), S02_AXI_wlast("S02_AXI_wlast"), S02_AXI_wvalid("S02_AXI_wvalid"), S02_AXI_wready("S02_AXI_wready"), S02_AXI_bresp("S02_AXI_bresp"), S02_AXI_bvalid("S02_AXI_bvalid"), S02_AXI_bready("S02_AXI_bready"), S02_AXI_araddr("S02_AXI_araddr"), S02_AXI_arlen("S02_AXI_arlen"), S02_AXI_arsize("S02_AXI_arsize"), S02_AXI_arburst("S02_AXI_arburst"), S02_AXI_arlock("S02_AXI_arlock"), S02_AXI_arcache("S02_AXI_arcache"), S02_AXI_arprot("S02_AXI_arprot"), S02_AXI_arregion("S02_AXI_arregion"), S02_AXI_arqos("S02_AXI_arqos"), S02_AXI_arvalid("S02_AXI_arvalid"), S02_AXI_arready("S02_AXI_arready"), S02_AXI_rdata("S02_AXI_rdata"), S02_AXI_rresp("S02_AXI_rresp"), S02_AXI_rlast("S02_AXI_rlast"), S02_AXI_rvalid("S02_AXI_rvalid"), S02_AXI_rready("S02_AXI_rready"), S03_AXI_awaddr("S03_AXI_awaddr"), S03_AXI_awlen("S03_AXI_awlen"), S03_AXI_awsize("S03_AXI_awsize"), S03_AXI_awburst("S03_AXI_awburst"), S03_AXI_awlock("S03_AXI_awlock"), S03_AXI_awcache("S03_AXI_awcache"), S03_AXI_awprot("S03_AXI_awprot"), S03_AXI_awregion("S03_AXI_awregion"), S03_AXI_awqos("S03_AXI_awqos"), S03_AXI_awvalid("S03_AXI_awvalid"), S03_AXI_awready("S03_AXI_awready"), S03_AXI_wdata("S03_AXI_wdata"), S03_AXI_wstrb("S03_AXI_wstrb"), S03_AXI_wlast("S03_AXI_wlast"), S03_AXI_wvalid("S03_AXI_wvalid"), S03_AXI_wready("S03_AXI_wready"), S03_AXI_bresp("S03_AXI_bresp"), S03_AXI_bvalid("S03_AXI_bvalid"), S03_AXI_bready("S03_AXI_bready"), S03_AXI_araddr("S03_AXI_araddr"), S03_AXI_arlen("S03_AXI_arlen"), S03_AXI_arsize("S03_AXI_arsize"), S03_AXI_arburst("S03_AXI_arburst"), S03_AXI_arlock("S03_AXI_arlock"), S03_AXI_arcache("S03_AXI_arcache"), S03_AXI_arprot("S03_AXI_arprot"), S03_AXI_arregion("S03_AXI_arregion"), S03_AXI_arqos("S03_AXI_arqos"), S03_AXI_arvalid("S03_AXI_arvalid"), S03_AXI_arready("S03_AXI_arready"), S03_AXI_rdata("S03_AXI_rdata"), S03_AXI_rresp("S03_AXI_rresp"), S03_AXI_rlast("S03_AXI_rlast"), S03_AXI_rvalid("S03_AXI_rvalid"), S03_AXI_rready("S03_AXI_rready"), S04_AXI_awaddr("S04_AXI_awaddr"), S04_AXI_awlen("S04_AXI_awlen"), S04_AXI_awsize("S04_AXI_awsize"), S04_AXI_awburst("S04_AXI_awburst"), S04_AXI_awlock("S04_AXI_awlock"), S04_AXI_awcache("S04_AXI_awcache"), S04_AXI_awprot("S04_AXI_awprot"), S04_AXI_awregion("S04_AXI_awregion"), S04_AXI_awqos("S04_AXI_awqos"), S04_AXI_awvalid("S04_AXI_awvalid"), S04_AXI_awready("S04_AXI_awready"), S04_AXI_wdata("S04_AXI_wdata"), S04_AXI_wstrb("S04_AXI_wstrb"), S04_AXI_wlast("S04_AXI_wlast"), S04_AXI_wvalid("S04_AXI_wvalid"), S04_AXI_wready("S04_AXI_wready"), S04_AXI_bresp("S04_AXI_bresp"), S04_AXI_bvalid("S04_AXI_bvalid"), S04_AXI_bready("S04_AXI_bready"), S04_AXI_araddr("S04_AXI_araddr"), S04_AXI_arlen("S04_AXI_arlen"), S04_AXI_arsize("S04_AXI_arsize"), S04_AXI_arburst("S04_AXI_arburst"), S04_AXI_arlock("S04_AXI_arlock"), S04_AXI_arcache("S04_AXI_arcache"), S04_AXI_arprot("S04_AXI_arprot"), S04_AXI_arregion("S04_AXI_arregion"), S04_AXI_arqos("S04_AXI_arqos"), S04_AXI_arvalid("S04_AXI_arvalid"), S04_AXI_arready("S04_AXI_arready"), S04_AXI_rdata("S04_AXI_rdata"), S04_AXI_rresp("S04_AXI_rresp"), S04_AXI_rlast("S04_AXI_rlast"), S04_AXI_rvalid("S04_AXI_rvalid"), S04_AXI_rready("S04_AXI_rready"), S05_AXI_awaddr("S05_AXI_awaddr"), S05_AXI_awlen("S05_AXI_awlen"), S05_AXI_awsize("S05_AXI_awsize"), S05_AXI_awburst("S05_AXI_awburst"), S05_AXI_awlock("S05_AXI_awlock"), S05_AXI_awcache("S05_AXI_awcache"), S05_AXI_awprot("S05_AXI_awprot"), S05_AXI_awregion("S05_AXI_awregion"), S05_AXI_awqos("S05_AXI_awqos"), S05_AXI_awvalid("S05_AXI_awvalid"), S05_AXI_awready("S05_AXI_awready"), S05_AXI_wdata("S05_AXI_wdata"), S05_AXI_wstrb("S05_AXI_wstrb"), S05_AXI_wlast("S05_AXI_wlast"), S05_AXI_wvalid("S05_AXI_wvalid"), S05_AXI_wready("S05_AXI_wready"), S05_AXI_bresp("S05_AXI_bresp"), S05_AXI_bvalid("S05_AXI_bvalid"), S05_AXI_bready("S05_AXI_bready"), S05_AXI_araddr("S05_AXI_araddr"), S05_AXI_arlen("S05_AXI_arlen"), S05_AXI_arsize("S05_AXI_arsize"), S05_AXI_arburst("S05_AXI_arburst"), S05_AXI_arlock("S05_AXI_arlock"), S05_AXI_arcache("S05_AXI_arcache"), S05_AXI_arprot("S05_AXI_arprot"), S05_AXI_arregion("S05_AXI_arregion"), S05_AXI_arqos("S05_AXI_arqos"), S05_AXI_arvalid("S05_AXI_arvalid"), S05_AXI_arready("S05_AXI_arready"), S05_AXI_rdata("S05_AXI_rdata"), S05_AXI_rresp("S05_AXI_rresp"), S05_AXI_rlast("S05_AXI_rlast"), S05_AXI_rvalid("S05_AXI_rvalid"), S05_AXI_rready("S05_AXI_rready"), S06_AXI_awaddr("S06_AXI_awaddr"), S06_AXI_awlen("S06_AXI_awlen"), S06_AXI_awsize("S06_AXI_awsize"), S06_AXI_awburst("S06_AXI_awburst"), S06_AXI_awlock("S06_AXI_awlock"), S06_AXI_awcache("S06_AXI_awcache"), S06_AXI_awprot("S06_AXI_awprot"), S06_AXI_awregion("S06_AXI_awregion"), S06_AXI_awqos("S06_AXI_awqos"), S06_AXI_awvalid("S06_AXI_awvalid"), S06_AXI_awready("S06_AXI_awready"), S06_AXI_wdata("S06_AXI_wdata"), S06_AXI_wstrb("S06_AXI_wstrb"), S06_AXI_wlast("S06_AXI_wlast"), S06_AXI_wvalid("S06_AXI_wvalid"), S06_AXI_wready("S06_AXI_wready"), S06_AXI_bresp("S06_AXI_bresp"), S06_AXI_bvalid("S06_AXI_bvalid"), S06_AXI_bready("S06_AXI_bready"), S06_AXI_araddr("S06_AXI_araddr"), S06_AXI_arlen("S06_AXI_arlen"), S06_AXI_arsize("S06_AXI_arsize"), S06_AXI_arburst("S06_AXI_arburst"), S06_AXI_arlock("S06_AXI_arlock"), S06_AXI_arcache("S06_AXI_arcache"), S06_AXI_arprot("S06_AXI_arprot"), S06_AXI_arregion("S06_AXI_arregion"), S06_AXI_arqos("S06_AXI_arqos"), S06_AXI_arvalid("S06_AXI_arvalid"), S06_AXI_arready("S06_AXI_arready"), S06_AXI_rdata("S06_AXI_rdata"), S06_AXI_rresp("S06_AXI_rresp"), S06_AXI_rlast("S06_AXI_rlast"), S06_AXI_rvalid("S06_AXI_rvalid"), S06_AXI_rready("S06_AXI_rready"), aclk0("aclk0"), aclk1("aclk1"), aclk2("aclk2"), aclk3("aclk3"), aclk4("aclk4"), aclk5("aclk5"), aclk6("aclk6"), sys_clk0_clk_p("sys_clk0_clk_p"), sys_clk0_clk_n("sys_clk0_clk_n"), CH0_DDR4_0_dq("CH0_DDR4_0_dq"), CH0_DDR4_0_dqs_t("CH0_DDR4_0_dqs_t"), CH0_DDR4_0_dqs_c("CH0_DDR4_0_dqs_c"), CH0_DDR4_0_adr("CH0_DDR4_0_adr"), CH0_DDR4_0_ba("CH0_DDR4_0_ba"), CH0_DDR4_0_bg("CH0_DDR4_0_bg"), CH0_DDR4_0_act_n("CH0_DDR4_0_act_n"), CH0_DDR4_0_reset_n("CH0_DDR4_0_reset_n"), CH0_DDR4_0_ck_t("CH0_DDR4_0_ck_t"), CH0_DDR4_0_ck_c("CH0_DDR4_0_ck_c"), CH0_DDR4_0_cke("CH0_DDR4_0_cke"), CH0_DDR4_0_cs_n("CH0_DDR4_0_cs_n"), CH0_DDR4_0_dm_n("CH0_DDR4_0_dm_n"), CH0_DDR4_0_odt("CH0_DDR4_0_odt"), S05_AXI_arid("S05_AXI_arid"), S05_AXI_aruser("S05_AXI_aruser"), S05_AXI_awid("S05_AXI_awid"), S05_AXI_awuser("S05_AXI_awuser"), S05_AXI_bid("S05_AXI_bid"), S05_AXI_buser("S05_AXI_buser"), S05_AXI_rid("S05_AXI_rid"), S05_AXI_ruser("S05_AXI_ruser"), S05_AXI_wuser("S05_AXI_wuser"), S03_AXI_arid("S03_AXI_arid"), S03_AXI_aruser("S03_AXI_aruser"), S03_AXI_awid("S03_AXI_awid"), S03_AXI_awuser("S03_AXI_awuser"), S03_AXI_bid("S03_AXI_bid"), S03_AXI_rid("S03_AXI_rid"), S03_AXI_ruser("S03_AXI_ruser"), S03_AXI_wuser("S03_AXI_wuser"), S04_AXI_arid("S04_AXI_arid"), S04_AXI_aruser("S04_AXI_aruser"), S04_AXI_awid("S04_AXI_awid"), S04_AXI_awuser("S04_AXI_awuser"), S04_AXI_bid("S04_AXI_bid"), S04_AXI_rid("S04_AXI_rid"), S04_AXI_ruser("S04_AXI_ruser"), S04_AXI_wuser("S04_AXI_wuser"), S02_AXI_arid("S02_AXI_arid"), S02_AXI_aruser("S02_AXI_aruser"), S02_AXI_awid("S02_AXI_awid"), S02_AXI_awuser("S02_AXI_awuser"), S02_AXI_bid("S02_AXI_bid"), S02_AXI_rid("S02_AXI_rid"), S02_AXI_ruser("S02_AXI_ruser"), S02_AXI_wuser("S02_AXI_wuser"), S06_AXI_arid("S06_AXI_arid"), S06_AXI_awid("S06_AXI_awid"), S06_AXI_bid("S06_AXI_bid"), S06_AXI_rid("S06_AXI_rid"), S01_AXI_arid("S01_AXI_arid"), S01_AXI_aruser("S01_AXI_aruser"), S01_AXI_awid("S01_AXI_awid"), S01_AXI_awuser("S01_AXI_awuser"), S01_AXI_bid("S01_AXI_bid"), S01_AXI_rid("S01_AXI_rid"), S01_AXI_ruser("S01_AXI_ruser"), S01_AXI_wuser("S01_AXI_wuser"), S00_AXI_arid("S00_AXI_arid"), S00_AXI_aruser("S00_AXI_aruser"), S00_AXI_awid("S00_AXI_awid"), S00_AXI_awuser("S00_AXI_awuser"), S00_AXI_bid("S00_AXI_bid"), S00_AXI_rid("S00_AXI_rid"), S00_AXI_ruser("S00_AXI_ruser"), S00_AXI_wuser("S00_AXI_wuser")
{
  // initialize pins
  mp_impl->aclk0(aclk0);
  mp_impl->aclk1(aclk1);
  mp_impl->aclk2(aclk2);
  mp_impl->aclk3(aclk3);
  mp_impl->aclk4(aclk4);
  mp_impl->aclk5(aclk5);
  mp_impl->aclk6(aclk6);
  mp_impl->sys_clk0_clk_p(sys_clk0_clk_p);
  mp_impl->sys_clk0_clk_n(sys_clk0_clk_n);
  mp_impl->CH0_DDR4_0_dq(CH0_DDR4_0_dq);
  mp_impl->CH0_DDR4_0_dqs_t(CH0_DDR4_0_dqs_t);
  mp_impl->CH0_DDR4_0_dqs_c(CH0_DDR4_0_dqs_c);
  mp_impl->CH0_DDR4_0_adr(CH0_DDR4_0_adr);
  mp_impl->CH0_DDR4_0_ba(CH0_DDR4_0_ba);
  mp_impl->CH0_DDR4_0_bg(CH0_DDR4_0_bg);
  mp_impl->CH0_DDR4_0_act_n(CH0_DDR4_0_act_n);
  mp_impl->CH0_DDR4_0_reset_n(CH0_DDR4_0_reset_n);
  mp_impl->CH0_DDR4_0_ck_t(CH0_DDR4_0_ck_t);
  mp_impl->CH0_DDR4_0_ck_c(CH0_DDR4_0_ck_c);
  mp_impl->CH0_DDR4_0_cke(CH0_DDR4_0_cke);
  mp_impl->CH0_DDR4_0_cs_n(CH0_DDR4_0_cs_n);
  mp_impl->CH0_DDR4_0_dm_n(CH0_DDR4_0_dm_n);
  mp_impl->CH0_DDR4_0_odt(CH0_DDR4_0_odt);

  // initialize transactors
  mp_S00_AXI_transactor = NULL;
  mp_S00_AXI_awlock_converter = NULL;
  mp_S00_AXI_awvalid_converter = NULL;
  mp_S00_AXI_awready_converter = NULL;
  mp_S00_AXI_wlast_converter = NULL;
  mp_S00_AXI_wvalid_converter = NULL;
  mp_S00_AXI_wready_converter = NULL;
  mp_S00_AXI_bvalid_converter = NULL;
  mp_S00_AXI_bready_converter = NULL;
  mp_S00_AXI_arlock_converter = NULL;
  mp_S00_AXI_arvalid_converter = NULL;
  mp_S00_AXI_arready_converter = NULL;
  mp_S00_AXI_rlast_converter = NULL;
  mp_S00_AXI_rvalid_converter = NULL;
  mp_S00_AXI_rready_converter = NULL;
  mp_S01_AXI_transactor = NULL;
  mp_S01_AXI_awlock_converter = NULL;
  mp_S01_AXI_awvalid_converter = NULL;
  mp_S01_AXI_awready_converter = NULL;
  mp_S01_AXI_wlast_converter = NULL;
  mp_S01_AXI_wvalid_converter = NULL;
  mp_S01_AXI_wready_converter = NULL;
  mp_S01_AXI_bvalid_converter = NULL;
  mp_S01_AXI_bready_converter = NULL;
  mp_S01_AXI_arlock_converter = NULL;
  mp_S01_AXI_arvalid_converter = NULL;
  mp_S01_AXI_arready_converter = NULL;
  mp_S01_AXI_rlast_converter = NULL;
  mp_S01_AXI_rvalid_converter = NULL;
  mp_S01_AXI_rready_converter = NULL;
  mp_S02_AXI_transactor = NULL;
  mp_S02_AXI_awlock_converter = NULL;
  mp_S02_AXI_awvalid_converter = NULL;
  mp_S02_AXI_awready_converter = NULL;
  mp_S02_AXI_wlast_converter = NULL;
  mp_S02_AXI_wvalid_converter = NULL;
  mp_S02_AXI_wready_converter = NULL;
  mp_S02_AXI_bvalid_converter = NULL;
  mp_S02_AXI_bready_converter = NULL;
  mp_S02_AXI_arlock_converter = NULL;
  mp_S02_AXI_arvalid_converter = NULL;
  mp_S02_AXI_arready_converter = NULL;
  mp_S02_AXI_rlast_converter = NULL;
  mp_S02_AXI_rvalid_converter = NULL;
  mp_S02_AXI_rready_converter = NULL;
  mp_S03_AXI_transactor = NULL;
  mp_S03_AXI_awlock_converter = NULL;
  mp_S03_AXI_awvalid_converter = NULL;
  mp_S03_AXI_awready_converter = NULL;
  mp_S03_AXI_wlast_converter = NULL;
  mp_S03_AXI_wvalid_converter = NULL;
  mp_S03_AXI_wready_converter = NULL;
  mp_S03_AXI_bvalid_converter = NULL;
  mp_S03_AXI_bready_converter = NULL;
  mp_S03_AXI_arlock_converter = NULL;
  mp_S03_AXI_arvalid_converter = NULL;
  mp_S03_AXI_arready_converter = NULL;
  mp_S03_AXI_rlast_converter = NULL;
  mp_S03_AXI_rvalid_converter = NULL;
  mp_S03_AXI_rready_converter = NULL;
  mp_S04_AXI_transactor = NULL;
  mp_S04_AXI_awlock_converter = NULL;
  mp_S04_AXI_awvalid_converter = NULL;
  mp_S04_AXI_awready_converter = NULL;
  mp_S04_AXI_wlast_converter = NULL;
  mp_S04_AXI_wvalid_converter = NULL;
  mp_S04_AXI_wready_converter = NULL;
  mp_S04_AXI_bvalid_converter = NULL;
  mp_S04_AXI_bready_converter = NULL;
  mp_S04_AXI_arlock_converter = NULL;
  mp_S04_AXI_arvalid_converter = NULL;
  mp_S04_AXI_arready_converter = NULL;
  mp_S04_AXI_rlast_converter = NULL;
  mp_S04_AXI_rvalid_converter = NULL;
  mp_S04_AXI_rready_converter = NULL;
  mp_S05_AXI_transactor = NULL;
  mp_S05_AXI_awlock_converter = NULL;
  mp_S05_AXI_awvalid_converter = NULL;
  mp_S05_AXI_awready_converter = NULL;
  mp_S05_AXI_wlast_converter = NULL;
  mp_S05_AXI_wvalid_converter = NULL;
  mp_S05_AXI_wready_converter = NULL;
  mp_S05_AXI_bvalid_converter = NULL;
  mp_S05_AXI_bready_converter = NULL;
  mp_S05_AXI_arlock_converter = NULL;
  mp_S05_AXI_arvalid_converter = NULL;
  mp_S05_AXI_arready_converter = NULL;
  mp_S05_AXI_rlast_converter = NULL;
  mp_S05_AXI_rvalid_converter = NULL;
  mp_S05_AXI_rready_converter = NULL;
  mp_S06_AXI_transactor = NULL;
  mp_S06_AXI_awlock_converter = NULL;
  mp_S06_AXI_awvalid_converter = NULL;
  mp_S06_AXI_awready_converter = NULL;
  mp_S06_AXI_wlast_converter = NULL;
  mp_S06_AXI_wvalid_converter = NULL;
  mp_S06_AXI_wready_converter = NULL;
  mp_S06_AXI_bvalid_converter = NULL;
  mp_S06_AXI_bready_converter = NULL;
  mp_S06_AXI_arlock_converter = NULL;
  mp_S06_AXI_arvalid_converter = NULL;
  mp_S06_AXI_arready_converter = NULL;
  mp_S06_AXI_rlast_converter = NULL;
  mp_S06_AXI_rvalid_converter = NULL;
  mp_S06_AXI_rready_converter = NULL;

  // Instantiate Socket Stubs

  // configure S00_AXI_transactor
    xsc::common_cpp::properties S00_AXI_transactor_param_props;
    S00_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S00_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S00_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S00_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S00_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S00_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S00_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S00_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S00_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S00_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S00_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S00_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S00_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S00_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S00_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S00_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S00_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S00_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");
    S00_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S00_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S00_AXI_transactor_param_props.addString("REGION", "0");
    S00_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S00_AXI_transactor_param_props.addString("DEST_IDS", "");
    S00_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S00_AXI_transactor_param_props.addString("REMAPS", "");
    S00_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S00_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S00_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S00_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S00_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S00_AXI_transactor", S00_AXI_transactor_param_props);
  mp_S00_AXI_transactor->AWADDR(S00_AXI_awaddr);
  mp_S00_AXI_transactor->AWLEN(S00_AXI_awlen);
  mp_S00_AXI_transactor->AWSIZE(S00_AXI_awsize);
  mp_S00_AXI_transactor->AWBURST(S00_AXI_awburst);
  mp_S00_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awlock_converter");
  mp_S00_AXI_awlock_converter->vector_in(S00_AXI_awlock);
  mp_S00_AXI_awlock_converter->scalar_out(m_S00_AXI_awlock_converter_signal);
  mp_S00_AXI_transactor->AWLOCK(m_S00_AXI_awlock_converter_signal);
  mp_S00_AXI_transactor->AWCACHE(S00_AXI_awcache);
  mp_S00_AXI_transactor->AWPROT(S00_AXI_awprot);
  mp_S00_AXI_transactor->AWREGION(S00_AXI_awregion);
  mp_S00_AXI_transactor->AWQOS(S00_AXI_awqos);
  mp_S00_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awvalid_converter");
  mp_S00_AXI_awvalid_converter->vector_in(S00_AXI_awvalid);
  mp_S00_AXI_awvalid_converter->scalar_out(m_S00_AXI_awvalid_converter_signal);
  mp_S00_AXI_transactor->AWVALID(m_S00_AXI_awvalid_converter_signal);
  mp_S00_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_awready_converter");
  mp_S00_AXI_awready_converter->scalar_in(m_S00_AXI_awready_converter_signal);
  mp_S00_AXI_awready_converter->vector_out(S00_AXI_awready);
  mp_S00_AXI_transactor->AWREADY(m_S00_AXI_awready_converter_signal);
  mp_S00_AXI_transactor->WDATA(S00_AXI_wdata);
  mp_S00_AXI_transactor->WSTRB(S00_AXI_wstrb);
  mp_S00_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wlast_converter");
  mp_S00_AXI_wlast_converter->vector_in(S00_AXI_wlast);
  mp_S00_AXI_wlast_converter->scalar_out(m_S00_AXI_wlast_converter_signal);
  mp_S00_AXI_transactor->WLAST(m_S00_AXI_wlast_converter_signal);
  mp_S00_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wvalid_converter");
  mp_S00_AXI_wvalid_converter->vector_in(S00_AXI_wvalid);
  mp_S00_AXI_wvalid_converter->scalar_out(m_S00_AXI_wvalid_converter_signal);
  mp_S00_AXI_transactor->WVALID(m_S00_AXI_wvalid_converter_signal);
  mp_S00_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_wready_converter");
  mp_S00_AXI_wready_converter->scalar_in(m_S00_AXI_wready_converter_signal);
  mp_S00_AXI_wready_converter->vector_out(S00_AXI_wready);
  mp_S00_AXI_transactor->WREADY(m_S00_AXI_wready_converter_signal);
  mp_S00_AXI_transactor->BRESP(S00_AXI_bresp);
  mp_S00_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_bvalid_converter");
  mp_S00_AXI_bvalid_converter->scalar_in(m_S00_AXI_bvalid_converter_signal);
  mp_S00_AXI_bvalid_converter->vector_out(S00_AXI_bvalid);
  mp_S00_AXI_transactor->BVALID(m_S00_AXI_bvalid_converter_signal);
  mp_S00_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_bready_converter");
  mp_S00_AXI_bready_converter->vector_in(S00_AXI_bready);
  mp_S00_AXI_bready_converter->scalar_out(m_S00_AXI_bready_converter_signal);
  mp_S00_AXI_transactor->BREADY(m_S00_AXI_bready_converter_signal);
  mp_S00_AXI_transactor->ARADDR(S00_AXI_araddr);
  mp_S00_AXI_transactor->ARLEN(S00_AXI_arlen);
  mp_S00_AXI_transactor->ARSIZE(S00_AXI_arsize);
  mp_S00_AXI_transactor->ARBURST(S00_AXI_arburst);
  mp_S00_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arlock_converter");
  mp_S00_AXI_arlock_converter->vector_in(S00_AXI_arlock);
  mp_S00_AXI_arlock_converter->scalar_out(m_S00_AXI_arlock_converter_signal);
  mp_S00_AXI_transactor->ARLOCK(m_S00_AXI_arlock_converter_signal);
  mp_S00_AXI_transactor->ARCACHE(S00_AXI_arcache);
  mp_S00_AXI_transactor->ARPROT(S00_AXI_arprot);
  mp_S00_AXI_transactor->ARREGION(S00_AXI_arregion);
  mp_S00_AXI_transactor->ARQOS(S00_AXI_arqos);
  mp_S00_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arvalid_converter");
  mp_S00_AXI_arvalid_converter->vector_in(S00_AXI_arvalid);
  mp_S00_AXI_arvalid_converter->scalar_out(m_S00_AXI_arvalid_converter_signal);
  mp_S00_AXI_transactor->ARVALID(m_S00_AXI_arvalid_converter_signal);
  mp_S00_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_arready_converter");
  mp_S00_AXI_arready_converter->scalar_in(m_S00_AXI_arready_converter_signal);
  mp_S00_AXI_arready_converter->vector_out(S00_AXI_arready);
  mp_S00_AXI_transactor->ARREADY(m_S00_AXI_arready_converter_signal);
  mp_S00_AXI_transactor->RDATA(S00_AXI_rdata);
  mp_S00_AXI_transactor->RRESP(S00_AXI_rresp);
  mp_S00_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rlast_converter");
  mp_S00_AXI_rlast_converter->scalar_in(m_S00_AXI_rlast_converter_signal);
  mp_S00_AXI_rlast_converter->vector_out(S00_AXI_rlast);
  mp_S00_AXI_transactor->RLAST(m_S00_AXI_rlast_converter_signal);
  mp_S00_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rvalid_converter");
  mp_S00_AXI_rvalid_converter->scalar_in(m_S00_AXI_rvalid_converter_signal);
  mp_S00_AXI_rvalid_converter->vector_out(S00_AXI_rvalid);
  mp_S00_AXI_transactor->RVALID(m_S00_AXI_rvalid_converter_signal);
  mp_S00_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_rready_converter");
  mp_S00_AXI_rready_converter->vector_in(S00_AXI_rready);
  mp_S00_AXI_rready_converter->scalar_out(m_S00_AXI_rready_converter_signal);
  mp_S00_AXI_transactor->RREADY(m_S00_AXI_rready_converter_signal);
  mp_S00_AXI_transactor->ARID(S00_AXI_arid);
  mp_S00_AXI_transactor->ARUSER(S00_AXI_aruser);
  mp_S00_AXI_transactor->AWID(S00_AXI_awid);
  mp_S00_AXI_transactor->AWUSER(S00_AXI_awuser);
  mp_S00_AXI_transactor->BID(S00_AXI_bid);
  mp_S00_AXI_transactor->RID(S00_AXI_rid);
  mp_S00_AXI_transactor->RUSER(S00_AXI_ruser);
  mp_S00_AXI_transactor->WUSER(S00_AXI_wuser);
  mp_S00_AXI_transactor->CLK(aclk0);
  m_S00_AXI_transactor_rst_signal.write(1);
  mp_S00_AXI_transactor->RST(m_S00_AXI_transactor_rst_signal);
  // configure S01_AXI_transactor
    xsc::common_cpp::properties S01_AXI_transactor_param_props;
    S01_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S01_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S01_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S01_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S01_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S01_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S01_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S01_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S01_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S01_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S01_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S01_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S01_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S01_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S01_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S01_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S01_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S01_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk");
    S01_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S01_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S01_AXI_transactor_param_props.addString("REGION", "0");
    S01_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S01_AXI_transactor_param_props.addString("DEST_IDS", "");
    S01_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S01_AXI_transactor_param_props.addString("REMAPS", "");
    S01_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S01_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S01_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S01_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S01_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S01_AXI_transactor", S01_AXI_transactor_param_props);
  mp_S01_AXI_transactor->AWADDR(S01_AXI_awaddr);
  mp_S01_AXI_transactor->AWLEN(S01_AXI_awlen);
  mp_S01_AXI_transactor->AWSIZE(S01_AXI_awsize);
  mp_S01_AXI_transactor->AWBURST(S01_AXI_awburst);
  mp_S01_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awlock_converter");
  mp_S01_AXI_awlock_converter->vector_in(S01_AXI_awlock);
  mp_S01_AXI_awlock_converter->scalar_out(m_S01_AXI_awlock_converter_signal);
  mp_S01_AXI_transactor->AWLOCK(m_S01_AXI_awlock_converter_signal);
  mp_S01_AXI_transactor->AWCACHE(S01_AXI_awcache);
  mp_S01_AXI_transactor->AWPROT(S01_AXI_awprot);
  mp_S01_AXI_transactor->AWREGION(S01_AXI_awregion);
  mp_S01_AXI_transactor->AWQOS(S01_AXI_awqos);
  mp_S01_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awvalid_converter");
  mp_S01_AXI_awvalid_converter->vector_in(S01_AXI_awvalid);
  mp_S01_AXI_awvalid_converter->scalar_out(m_S01_AXI_awvalid_converter_signal);
  mp_S01_AXI_transactor->AWVALID(m_S01_AXI_awvalid_converter_signal);
  mp_S01_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_awready_converter");
  mp_S01_AXI_awready_converter->scalar_in(m_S01_AXI_awready_converter_signal);
  mp_S01_AXI_awready_converter->vector_out(S01_AXI_awready);
  mp_S01_AXI_transactor->AWREADY(m_S01_AXI_awready_converter_signal);
  mp_S01_AXI_transactor->WDATA(S01_AXI_wdata);
  mp_S01_AXI_transactor->WSTRB(S01_AXI_wstrb);
  mp_S01_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wlast_converter");
  mp_S01_AXI_wlast_converter->vector_in(S01_AXI_wlast);
  mp_S01_AXI_wlast_converter->scalar_out(m_S01_AXI_wlast_converter_signal);
  mp_S01_AXI_transactor->WLAST(m_S01_AXI_wlast_converter_signal);
  mp_S01_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wvalid_converter");
  mp_S01_AXI_wvalid_converter->vector_in(S01_AXI_wvalid);
  mp_S01_AXI_wvalid_converter->scalar_out(m_S01_AXI_wvalid_converter_signal);
  mp_S01_AXI_transactor->WVALID(m_S01_AXI_wvalid_converter_signal);
  mp_S01_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_wready_converter");
  mp_S01_AXI_wready_converter->scalar_in(m_S01_AXI_wready_converter_signal);
  mp_S01_AXI_wready_converter->vector_out(S01_AXI_wready);
  mp_S01_AXI_transactor->WREADY(m_S01_AXI_wready_converter_signal);
  mp_S01_AXI_transactor->BRESP(S01_AXI_bresp);
  mp_S01_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_bvalid_converter");
  mp_S01_AXI_bvalid_converter->scalar_in(m_S01_AXI_bvalid_converter_signal);
  mp_S01_AXI_bvalid_converter->vector_out(S01_AXI_bvalid);
  mp_S01_AXI_transactor->BVALID(m_S01_AXI_bvalid_converter_signal);
  mp_S01_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_bready_converter");
  mp_S01_AXI_bready_converter->vector_in(S01_AXI_bready);
  mp_S01_AXI_bready_converter->scalar_out(m_S01_AXI_bready_converter_signal);
  mp_S01_AXI_transactor->BREADY(m_S01_AXI_bready_converter_signal);
  mp_S01_AXI_transactor->ARADDR(S01_AXI_araddr);
  mp_S01_AXI_transactor->ARLEN(S01_AXI_arlen);
  mp_S01_AXI_transactor->ARSIZE(S01_AXI_arsize);
  mp_S01_AXI_transactor->ARBURST(S01_AXI_arburst);
  mp_S01_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arlock_converter");
  mp_S01_AXI_arlock_converter->vector_in(S01_AXI_arlock);
  mp_S01_AXI_arlock_converter->scalar_out(m_S01_AXI_arlock_converter_signal);
  mp_S01_AXI_transactor->ARLOCK(m_S01_AXI_arlock_converter_signal);
  mp_S01_AXI_transactor->ARCACHE(S01_AXI_arcache);
  mp_S01_AXI_transactor->ARPROT(S01_AXI_arprot);
  mp_S01_AXI_transactor->ARREGION(S01_AXI_arregion);
  mp_S01_AXI_transactor->ARQOS(S01_AXI_arqos);
  mp_S01_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arvalid_converter");
  mp_S01_AXI_arvalid_converter->vector_in(S01_AXI_arvalid);
  mp_S01_AXI_arvalid_converter->scalar_out(m_S01_AXI_arvalid_converter_signal);
  mp_S01_AXI_transactor->ARVALID(m_S01_AXI_arvalid_converter_signal);
  mp_S01_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_arready_converter");
  mp_S01_AXI_arready_converter->scalar_in(m_S01_AXI_arready_converter_signal);
  mp_S01_AXI_arready_converter->vector_out(S01_AXI_arready);
  mp_S01_AXI_transactor->ARREADY(m_S01_AXI_arready_converter_signal);
  mp_S01_AXI_transactor->RDATA(S01_AXI_rdata);
  mp_S01_AXI_transactor->RRESP(S01_AXI_rresp);
  mp_S01_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rlast_converter");
  mp_S01_AXI_rlast_converter->scalar_in(m_S01_AXI_rlast_converter_signal);
  mp_S01_AXI_rlast_converter->vector_out(S01_AXI_rlast);
  mp_S01_AXI_transactor->RLAST(m_S01_AXI_rlast_converter_signal);
  mp_S01_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rvalid_converter");
  mp_S01_AXI_rvalid_converter->scalar_in(m_S01_AXI_rvalid_converter_signal);
  mp_S01_AXI_rvalid_converter->vector_out(S01_AXI_rvalid);
  mp_S01_AXI_transactor->RVALID(m_S01_AXI_rvalid_converter_signal);
  mp_S01_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_rready_converter");
  mp_S01_AXI_rready_converter->vector_in(S01_AXI_rready);
  mp_S01_AXI_rready_converter->scalar_out(m_S01_AXI_rready_converter_signal);
  mp_S01_AXI_transactor->RREADY(m_S01_AXI_rready_converter_signal);
  mp_S01_AXI_transactor->ARID(S01_AXI_arid);
  mp_S01_AXI_transactor->ARUSER(S01_AXI_aruser);
  mp_S01_AXI_transactor->AWID(S01_AXI_awid);
  mp_S01_AXI_transactor->AWUSER(S01_AXI_awuser);
  mp_S01_AXI_transactor->BID(S01_AXI_bid);
  mp_S01_AXI_transactor->RID(S01_AXI_rid);
  mp_S01_AXI_transactor->RUSER(S01_AXI_ruser);
  mp_S01_AXI_transactor->WUSER(S01_AXI_wuser);
  mp_S01_AXI_transactor->CLK(aclk1);
  m_S01_AXI_transactor_rst_signal.write(1);
  mp_S01_AXI_transactor->RST(m_S01_AXI_transactor_rst_signal);
  // configure S02_AXI_transactor
    xsc::common_cpp::properties S02_AXI_transactor_param_props;
    S02_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S02_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S02_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S02_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S02_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S02_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S02_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S02_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S02_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S02_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S02_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S02_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S02_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S02_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S02_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S02_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S02_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S02_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk");
    S02_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S02_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S02_AXI_transactor_param_props.addString("REGION", "0");
    S02_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S02_AXI_transactor_param_props.addString("DEST_IDS", "");
    S02_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S02_AXI_transactor_param_props.addString("REMAPS", "");
    S02_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S02_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S02_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S02_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S02_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S02_AXI_transactor", S02_AXI_transactor_param_props);
  mp_S02_AXI_transactor->AWADDR(S02_AXI_awaddr);
  mp_S02_AXI_transactor->AWLEN(S02_AXI_awlen);
  mp_S02_AXI_transactor->AWSIZE(S02_AXI_awsize);
  mp_S02_AXI_transactor->AWBURST(S02_AXI_awburst);
  mp_S02_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awlock_converter");
  mp_S02_AXI_awlock_converter->vector_in(S02_AXI_awlock);
  mp_S02_AXI_awlock_converter->scalar_out(m_S02_AXI_awlock_converter_signal);
  mp_S02_AXI_transactor->AWLOCK(m_S02_AXI_awlock_converter_signal);
  mp_S02_AXI_transactor->AWCACHE(S02_AXI_awcache);
  mp_S02_AXI_transactor->AWPROT(S02_AXI_awprot);
  mp_S02_AXI_transactor->AWREGION(S02_AXI_awregion);
  mp_S02_AXI_transactor->AWQOS(S02_AXI_awqos);
  mp_S02_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awvalid_converter");
  mp_S02_AXI_awvalid_converter->vector_in(S02_AXI_awvalid);
  mp_S02_AXI_awvalid_converter->scalar_out(m_S02_AXI_awvalid_converter_signal);
  mp_S02_AXI_transactor->AWVALID(m_S02_AXI_awvalid_converter_signal);
  mp_S02_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_awready_converter");
  mp_S02_AXI_awready_converter->scalar_in(m_S02_AXI_awready_converter_signal);
  mp_S02_AXI_awready_converter->vector_out(S02_AXI_awready);
  mp_S02_AXI_transactor->AWREADY(m_S02_AXI_awready_converter_signal);
  mp_S02_AXI_transactor->WDATA(S02_AXI_wdata);
  mp_S02_AXI_transactor->WSTRB(S02_AXI_wstrb);
  mp_S02_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wlast_converter");
  mp_S02_AXI_wlast_converter->vector_in(S02_AXI_wlast);
  mp_S02_AXI_wlast_converter->scalar_out(m_S02_AXI_wlast_converter_signal);
  mp_S02_AXI_transactor->WLAST(m_S02_AXI_wlast_converter_signal);
  mp_S02_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wvalid_converter");
  mp_S02_AXI_wvalid_converter->vector_in(S02_AXI_wvalid);
  mp_S02_AXI_wvalid_converter->scalar_out(m_S02_AXI_wvalid_converter_signal);
  mp_S02_AXI_transactor->WVALID(m_S02_AXI_wvalid_converter_signal);
  mp_S02_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_wready_converter");
  mp_S02_AXI_wready_converter->scalar_in(m_S02_AXI_wready_converter_signal);
  mp_S02_AXI_wready_converter->vector_out(S02_AXI_wready);
  mp_S02_AXI_transactor->WREADY(m_S02_AXI_wready_converter_signal);
  mp_S02_AXI_transactor->BRESP(S02_AXI_bresp);
  mp_S02_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_bvalid_converter");
  mp_S02_AXI_bvalid_converter->scalar_in(m_S02_AXI_bvalid_converter_signal);
  mp_S02_AXI_bvalid_converter->vector_out(S02_AXI_bvalid);
  mp_S02_AXI_transactor->BVALID(m_S02_AXI_bvalid_converter_signal);
  mp_S02_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_bready_converter");
  mp_S02_AXI_bready_converter->vector_in(S02_AXI_bready);
  mp_S02_AXI_bready_converter->scalar_out(m_S02_AXI_bready_converter_signal);
  mp_S02_AXI_transactor->BREADY(m_S02_AXI_bready_converter_signal);
  mp_S02_AXI_transactor->ARADDR(S02_AXI_araddr);
  mp_S02_AXI_transactor->ARLEN(S02_AXI_arlen);
  mp_S02_AXI_transactor->ARSIZE(S02_AXI_arsize);
  mp_S02_AXI_transactor->ARBURST(S02_AXI_arburst);
  mp_S02_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arlock_converter");
  mp_S02_AXI_arlock_converter->vector_in(S02_AXI_arlock);
  mp_S02_AXI_arlock_converter->scalar_out(m_S02_AXI_arlock_converter_signal);
  mp_S02_AXI_transactor->ARLOCK(m_S02_AXI_arlock_converter_signal);
  mp_S02_AXI_transactor->ARCACHE(S02_AXI_arcache);
  mp_S02_AXI_transactor->ARPROT(S02_AXI_arprot);
  mp_S02_AXI_transactor->ARREGION(S02_AXI_arregion);
  mp_S02_AXI_transactor->ARQOS(S02_AXI_arqos);
  mp_S02_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arvalid_converter");
  mp_S02_AXI_arvalid_converter->vector_in(S02_AXI_arvalid);
  mp_S02_AXI_arvalid_converter->scalar_out(m_S02_AXI_arvalid_converter_signal);
  mp_S02_AXI_transactor->ARVALID(m_S02_AXI_arvalid_converter_signal);
  mp_S02_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_arready_converter");
  mp_S02_AXI_arready_converter->scalar_in(m_S02_AXI_arready_converter_signal);
  mp_S02_AXI_arready_converter->vector_out(S02_AXI_arready);
  mp_S02_AXI_transactor->ARREADY(m_S02_AXI_arready_converter_signal);
  mp_S02_AXI_transactor->RDATA(S02_AXI_rdata);
  mp_S02_AXI_transactor->RRESP(S02_AXI_rresp);
  mp_S02_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rlast_converter");
  mp_S02_AXI_rlast_converter->scalar_in(m_S02_AXI_rlast_converter_signal);
  mp_S02_AXI_rlast_converter->vector_out(S02_AXI_rlast);
  mp_S02_AXI_transactor->RLAST(m_S02_AXI_rlast_converter_signal);
  mp_S02_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rvalid_converter");
  mp_S02_AXI_rvalid_converter->scalar_in(m_S02_AXI_rvalid_converter_signal);
  mp_S02_AXI_rvalid_converter->vector_out(S02_AXI_rvalid);
  mp_S02_AXI_transactor->RVALID(m_S02_AXI_rvalid_converter_signal);
  mp_S02_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_rready_converter");
  mp_S02_AXI_rready_converter->vector_in(S02_AXI_rready);
  mp_S02_AXI_rready_converter->scalar_out(m_S02_AXI_rready_converter_signal);
  mp_S02_AXI_transactor->RREADY(m_S02_AXI_rready_converter_signal);
  mp_S02_AXI_transactor->ARID(S02_AXI_arid);
  mp_S02_AXI_transactor->ARUSER(S02_AXI_aruser);
  mp_S02_AXI_transactor->AWID(S02_AXI_awid);
  mp_S02_AXI_transactor->AWUSER(S02_AXI_awuser);
  mp_S02_AXI_transactor->BID(S02_AXI_bid);
  mp_S02_AXI_transactor->RID(S02_AXI_rid);
  mp_S02_AXI_transactor->RUSER(S02_AXI_ruser);
  mp_S02_AXI_transactor->WUSER(S02_AXI_wuser);
  mp_S02_AXI_transactor->CLK(aclk2);
  m_S02_AXI_transactor_rst_signal.write(1);
  mp_S02_AXI_transactor->RST(m_S02_AXI_transactor_rst_signal);
  // configure S03_AXI_transactor
    xsc::common_cpp::properties S03_AXI_transactor_param_props;
    S03_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S03_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S03_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S03_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S03_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S03_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S03_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S03_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S03_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S03_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S03_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S03_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S03_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S03_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S03_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S03_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S03_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S03_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk");
    S03_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S03_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S03_AXI_transactor_param_props.addString("REGION", "0");
    S03_AXI_transactor_param_props.addString("CONNECTIONS", "MC_1 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S03_AXI_transactor_param_props.addString("DEST_IDS", "");
    S03_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S03_AXI_transactor_param_props.addString("REMAPS", "");
    S03_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S03_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S03_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S03_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S03_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S03_AXI_transactor", S03_AXI_transactor_param_props);
  mp_S03_AXI_transactor->AWADDR(S03_AXI_awaddr);
  mp_S03_AXI_transactor->AWLEN(S03_AXI_awlen);
  mp_S03_AXI_transactor->AWSIZE(S03_AXI_awsize);
  mp_S03_AXI_transactor->AWBURST(S03_AXI_awburst);
  mp_S03_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awlock_converter");
  mp_S03_AXI_awlock_converter->vector_in(S03_AXI_awlock);
  mp_S03_AXI_awlock_converter->scalar_out(m_S03_AXI_awlock_converter_signal);
  mp_S03_AXI_transactor->AWLOCK(m_S03_AXI_awlock_converter_signal);
  mp_S03_AXI_transactor->AWCACHE(S03_AXI_awcache);
  mp_S03_AXI_transactor->AWPROT(S03_AXI_awprot);
  mp_S03_AXI_transactor->AWREGION(S03_AXI_awregion);
  mp_S03_AXI_transactor->AWQOS(S03_AXI_awqos);
  mp_S03_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awvalid_converter");
  mp_S03_AXI_awvalid_converter->vector_in(S03_AXI_awvalid);
  mp_S03_AXI_awvalid_converter->scalar_out(m_S03_AXI_awvalid_converter_signal);
  mp_S03_AXI_transactor->AWVALID(m_S03_AXI_awvalid_converter_signal);
  mp_S03_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_awready_converter");
  mp_S03_AXI_awready_converter->scalar_in(m_S03_AXI_awready_converter_signal);
  mp_S03_AXI_awready_converter->vector_out(S03_AXI_awready);
  mp_S03_AXI_transactor->AWREADY(m_S03_AXI_awready_converter_signal);
  mp_S03_AXI_transactor->WDATA(S03_AXI_wdata);
  mp_S03_AXI_transactor->WSTRB(S03_AXI_wstrb);
  mp_S03_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wlast_converter");
  mp_S03_AXI_wlast_converter->vector_in(S03_AXI_wlast);
  mp_S03_AXI_wlast_converter->scalar_out(m_S03_AXI_wlast_converter_signal);
  mp_S03_AXI_transactor->WLAST(m_S03_AXI_wlast_converter_signal);
  mp_S03_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wvalid_converter");
  mp_S03_AXI_wvalid_converter->vector_in(S03_AXI_wvalid);
  mp_S03_AXI_wvalid_converter->scalar_out(m_S03_AXI_wvalid_converter_signal);
  mp_S03_AXI_transactor->WVALID(m_S03_AXI_wvalid_converter_signal);
  mp_S03_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_wready_converter");
  mp_S03_AXI_wready_converter->scalar_in(m_S03_AXI_wready_converter_signal);
  mp_S03_AXI_wready_converter->vector_out(S03_AXI_wready);
  mp_S03_AXI_transactor->WREADY(m_S03_AXI_wready_converter_signal);
  mp_S03_AXI_transactor->BRESP(S03_AXI_bresp);
  mp_S03_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_bvalid_converter");
  mp_S03_AXI_bvalid_converter->scalar_in(m_S03_AXI_bvalid_converter_signal);
  mp_S03_AXI_bvalid_converter->vector_out(S03_AXI_bvalid);
  mp_S03_AXI_transactor->BVALID(m_S03_AXI_bvalid_converter_signal);
  mp_S03_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_bready_converter");
  mp_S03_AXI_bready_converter->vector_in(S03_AXI_bready);
  mp_S03_AXI_bready_converter->scalar_out(m_S03_AXI_bready_converter_signal);
  mp_S03_AXI_transactor->BREADY(m_S03_AXI_bready_converter_signal);
  mp_S03_AXI_transactor->ARADDR(S03_AXI_araddr);
  mp_S03_AXI_transactor->ARLEN(S03_AXI_arlen);
  mp_S03_AXI_transactor->ARSIZE(S03_AXI_arsize);
  mp_S03_AXI_transactor->ARBURST(S03_AXI_arburst);
  mp_S03_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arlock_converter");
  mp_S03_AXI_arlock_converter->vector_in(S03_AXI_arlock);
  mp_S03_AXI_arlock_converter->scalar_out(m_S03_AXI_arlock_converter_signal);
  mp_S03_AXI_transactor->ARLOCK(m_S03_AXI_arlock_converter_signal);
  mp_S03_AXI_transactor->ARCACHE(S03_AXI_arcache);
  mp_S03_AXI_transactor->ARPROT(S03_AXI_arprot);
  mp_S03_AXI_transactor->ARREGION(S03_AXI_arregion);
  mp_S03_AXI_transactor->ARQOS(S03_AXI_arqos);
  mp_S03_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arvalid_converter");
  mp_S03_AXI_arvalid_converter->vector_in(S03_AXI_arvalid);
  mp_S03_AXI_arvalid_converter->scalar_out(m_S03_AXI_arvalid_converter_signal);
  mp_S03_AXI_transactor->ARVALID(m_S03_AXI_arvalid_converter_signal);
  mp_S03_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_arready_converter");
  mp_S03_AXI_arready_converter->scalar_in(m_S03_AXI_arready_converter_signal);
  mp_S03_AXI_arready_converter->vector_out(S03_AXI_arready);
  mp_S03_AXI_transactor->ARREADY(m_S03_AXI_arready_converter_signal);
  mp_S03_AXI_transactor->RDATA(S03_AXI_rdata);
  mp_S03_AXI_transactor->RRESP(S03_AXI_rresp);
  mp_S03_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rlast_converter");
  mp_S03_AXI_rlast_converter->scalar_in(m_S03_AXI_rlast_converter_signal);
  mp_S03_AXI_rlast_converter->vector_out(S03_AXI_rlast);
  mp_S03_AXI_transactor->RLAST(m_S03_AXI_rlast_converter_signal);
  mp_S03_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rvalid_converter");
  mp_S03_AXI_rvalid_converter->scalar_in(m_S03_AXI_rvalid_converter_signal);
  mp_S03_AXI_rvalid_converter->vector_out(S03_AXI_rvalid);
  mp_S03_AXI_transactor->RVALID(m_S03_AXI_rvalid_converter_signal);
  mp_S03_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_rready_converter");
  mp_S03_AXI_rready_converter->vector_in(S03_AXI_rready);
  mp_S03_AXI_rready_converter->scalar_out(m_S03_AXI_rready_converter_signal);
  mp_S03_AXI_transactor->RREADY(m_S03_AXI_rready_converter_signal);
  mp_S03_AXI_transactor->ARID(S03_AXI_arid);
  mp_S03_AXI_transactor->ARUSER(S03_AXI_aruser);
  mp_S03_AXI_transactor->AWID(S03_AXI_awid);
  mp_S03_AXI_transactor->AWUSER(S03_AXI_awuser);
  mp_S03_AXI_transactor->BID(S03_AXI_bid);
  mp_S03_AXI_transactor->RID(S03_AXI_rid);
  mp_S03_AXI_transactor->RUSER(S03_AXI_ruser);
  mp_S03_AXI_transactor->WUSER(S03_AXI_wuser);
  mp_S03_AXI_transactor->CLK(aclk3);
  m_S03_AXI_transactor_rst_signal.write(1);
  mp_S03_AXI_transactor->RST(m_S03_AXI_transactor_rst_signal);
  // configure S04_AXI_transactor
    xsc::common_cpp::properties S04_AXI_transactor_param_props;
    S04_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S04_AXI_transactor_param_props.addLong("FREQ_HZ", "400000000");
    S04_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S04_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S04_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S04_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S04_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S04_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S04_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S04_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S04_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S04_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S04_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S04_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S04_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S04_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S04_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S04_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_lpd_axi_noc_clk");
    S04_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S04_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S04_AXI_transactor_param_props.addString("REGION", "0");
    S04_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S04_AXI_transactor_param_props.addString("DEST_IDS", "");
    S04_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S04_AXI_transactor_param_props.addString("REMAPS", "");
    S04_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S04_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S04_AXI_transactor_param_props.addString("CATEGORY", "ps_rpu");
    S04_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S04_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S04_AXI_transactor", S04_AXI_transactor_param_props);
  mp_S04_AXI_transactor->AWADDR(S04_AXI_awaddr);
  mp_S04_AXI_transactor->AWLEN(S04_AXI_awlen);
  mp_S04_AXI_transactor->AWSIZE(S04_AXI_awsize);
  mp_S04_AXI_transactor->AWBURST(S04_AXI_awburst);
  mp_S04_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awlock_converter");
  mp_S04_AXI_awlock_converter->vector_in(S04_AXI_awlock);
  mp_S04_AXI_awlock_converter->scalar_out(m_S04_AXI_awlock_converter_signal);
  mp_S04_AXI_transactor->AWLOCK(m_S04_AXI_awlock_converter_signal);
  mp_S04_AXI_transactor->AWCACHE(S04_AXI_awcache);
  mp_S04_AXI_transactor->AWPROT(S04_AXI_awprot);
  mp_S04_AXI_transactor->AWREGION(S04_AXI_awregion);
  mp_S04_AXI_transactor->AWQOS(S04_AXI_awqos);
  mp_S04_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awvalid_converter");
  mp_S04_AXI_awvalid_converter->vector_in(S04_AXI_awvalid);
  mp_S04_AXI_awvalid_converter->scalar_out(m_S04_AXI_awvalid_converter_signal);
  mp_S04_AXI_transactor->AWVALID(m_S04_AXI_awvalid_converter_signal);
  mp_S04_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_awready_converter");
  mp_S04_AXI_awready_converter->scalar_in(m_S04_AXI_awready_converter_signal);
  mp_S04_AXI_awready_converter->vector_out(S04_AXI_awready);
  mp_S04_AXI_transactor->AWREADY(m_S04_AXI_awready_converter_signal);
  mp_S04_AXI_transactor->WDATA(S04_AXI_wdata);
  mp_S04_AXI_transactor->WSTRB(S04_AXI_wstrb);
  mp_S04_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wlast_converter");
  mp_S04_AXI_wlast_converter->vector_in(S04_AXI_wlast);
  mp_S04_AXI_wlast_converter->scalar_out(m_S04_AXI_wlast_converter_signal);
  mp_S04_AXI_transactor->WLAST(m_S04_AXI_wlast_converter_signal);
  mp_S04_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wvalid_converter");
  mp_S04_AXI_wvalid_converter->vector_in(S04_AXI_wvalid);
  mp_S04_AXI_wvalid_converter->scalar_out(m_S04_AXI_wvalid_converter_signal);
  mp_S04_AXI_transactor->WVALID(m_S04_AXI_wvalid_converter_signal);
  mp_S04_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_wready_converter");
  mp_S04_AXI_wready_converter->scalar_in(m_S04_AXI_wready_converter_signal);
  mp_S04_AXI_wready_converter->vector_out(S04_AXI_wready);
  mp_S04_AXI_transactor->WREADY(m_S04_AXI_wready_converter_signal);
  mp_S04_AXI_transactor->BRESP(S04_AXI_bresp);
  mp_S04_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_bvalid_converter");
  mp_S04_AXI_bvalid_converter->scalar_in(m_S04_AXI_bvalid_converter_signal);
  mp_S04_AXI_bvalid_converter->vector_out(S04_AXI_bvalid);
  mp_S04_AXI_transactor->BVALID(m_S04_AXI_bvalid_converter_signal);
  mp_S04_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_bready_converter");
  mp_S04_AXI_bready_converter->vector_in(S04_AXI_bready);
  mp_S04_AXI_bready_converter->scalar_out(m_S04_AXI_bready_converter_signal);
  mp_S04_AXI_transactor->BREADY(m_S04_AXI_bready_converter_signal);
  mp_S04_AXI_transactor->ARADDR(S04_AXI_araddr);
  mp_S04_AXI_transactor->ARLEN(S04_AXI_arlen);
  mp_S04_AXI_transactor->ARSIZE(S04_AXI_arsize);
  mp_S04_AXI_transactor->ARBURST(S04_AXI_arburst);
  mp_S04_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arlock_converter");
  mp_S04_AXI_arlock_converter->vector_in(S04_AXI_arlock);
  mp_S04_AXI_arlock_converter->scalar_out(m_S04_AXI_arlock_converter_signal);
  mp_S04_AXI_transactor->ARLOCK(m_S04_AXI_arlock_converter_signal);
  mp_S04_AXI_transactor->ARCACHE(S04_AXI_arcache);
  mp_S04_AXI_transactor->ARPROT(S04_AXI_arprot);
  mp_S04_AXI_transactor->ARREGION(S04_AXI_arregion);
  mp_S04_AXI_transactor->ARQOS(S04_AXI_arqos);
  mp_S04_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arvalid_converter");
  mp_S04_AXI_arvalid_converter->vector_in(S04_AXI_arvalid);
  mp_S04_AXI_arvalid_converter->scalar_out(m_S04_AXI_arvalid_converter_signal);
  mp_S04_AXI_transactor->ARVALID(m_S04_AXI_arvalid_converter_signal);
  mp_S04_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_arready_converter");
  mp_S04_AXI_arready_converter->scalar_in(m_S04_AXI_arready_converter_signal);
  mp_S04_AXI_arready_converter->vector_out(S04_AXI_arready);
  mp_S04_AXI_transactor->ARREADY(m_S04_AXI_arready_converter_signal);
  mp_S04_AXI_transactor->RDATA(S04_AXI_rdata);
  mp_S04_AXI_transactor->RRESP(S04_AXI_rresp);
  mp_S04_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rlast_converter");
  mp_S04_AXI_rlast_converter->scalar_in(m_S04_AXI_rlast_converter_signal);
  mp_S04_AXI_rlast_converter->vector_out(S04_AXI_rlast);
  mp_S04_AXI_transactor->RLAST(m_S04_AXI_rlast_converter_signal);
  mp_S04_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rvalid_converter");
  mp_S04_AXI_rvalid_converter->scalar_in(m_S04_AXI_rvalid_converter_signal);
  mp_S04_AXI_rvalid_converter->vector_out(S04_AXI_rvalid);
  mp_S04_AXI_transactor->RVALID(m_S04_AXI_rvalid_converter_signal);
  mp_S04_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_rready_converter");
  mp_S04_AXI_rready_converter->vector_in(S04_AXI_rready);
  mp_S04_AXI_rready_converter->scalar_out(m_S04_AXI_rready_converter_signal);
  mp_S04_AXI_transactor->RREADY(m_S04_AXI_rready_converter_signal);
  mp_S04_AXI_transactor->ARID(S04_AXI_arid);
  mp_S04_AXI_transactor->ARUSER(S04_AXI_aruser);
  mp_S04_AXI_transactor->AWID(S04_AXI_awid);
  mp_S04_AXI_transactor->AWUSER(S04_AXI_awuser);
  mp_S04_AXI_transactor->BID(S04_AXI_bid);
  mp_S04_AXI_transactor->RID(S04_AXI_rid);
  mp_S04_AXI_transactor->RUSER(S04_AXI_ruser);
  mp_S04_AXI_transactor->WUSER(S04_AXI_wuser);
  mp_S04_AXI_transactor->CLK(aclk4);
  m_S04_AXI_transactor_rst_signal.write(1);
  mp_S04_AXI_transactor->RST(m_S04_AXI_transactor_rst_signal);
  // configure S05_AXI_transactor
    xsc::common_cpp::properties S05_AXI_transactor_param_props;
    S05_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S05_AXI_transactor_param_props.addLong("FREQ_HZ", "320000000");
    S05_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S05_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("BUSER_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S05_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S05_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S05_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S05_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S05_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S05_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S05_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S05_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S05_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S05_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S05_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S05_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk");
    S05_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S05_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S05_AXI_transactor_param_props.addString("REGION", "0");
    S05_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S05_AXI_transactor_param_props.addString("DEST_IDS", "");
    S05_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S05_AXI_transactor_param_props.addString("REMAPS", "");
    S05_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S05_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S05_AXI_transactor_param_props.addString("CATEGORY", "ps_pmc");
    S05_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S05_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,16,18,17>("S05_AXI_transactor", S05_AXI_transactor_param_props);
  mp_S05_AXI_transactor->AWADDR(S05_AXI_awaddr);
  mp_S05_AXI_transactor->AWLEN(S05_AXI_awlen);
  mp_S05_AXI_transactor->AWSIZE(S05_AXI_awsize);
  mp_S05_AXI_transactor->AWBURST(S05_AXI_awburst);
  mp_S05_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awlock_converter");
  mp_S05_AXI_awlock_converter->vector_in(S05_AXI_awlock);
  mp_S05_AXI_awlock_converter->scalar_out(m_S05_AXI_awlock_converter_signal);
  mp_S05_AXI_transactor->AWLOCK(m_S05_AXI_awlock_converter_signal);
  mp_S05_AXI_transactor->AWCACHE(S05_AXI_awcache);
  mp_S05_AXI_transactor->AWPROT(S05_AXI_awprot);
  mp_S05_AXI_transactor->AWREGION(S05_AXI_awregion);
  mp_S05_AXI_transactor->AWQOS(S05_AXI_awqos);
  mp_S05_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awvalid_converter");
  mp_S05_AXI_awvalid_converter->vector_in(S05_AXI_awvalid);
  mp_S05_AXI_awvalid_converter->scalar_out(m_S05_AXI_awvalid_converter_signal);
  mp_S05_AXI_transactor->AWVALID(m_S05_AXI_awvalid_converter_signal);
  mp_S05_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_awready_converter");
  mp_S05_AXI_awready_converter->scalar_in(m_S05_AXI_awready_converter_signal);
  mp_S05_AXI_awready_converter->vector_out(S05_AXI_awready);
  mp_S05_AXI_transactor->AWREADY(m_S05_AXI_awready_converter_signal);
  mp_S05_AXI_transactor->WDATA(S05_AXI_wdata);
  mp_S05_AXI_transactor->WSTRB(S05_AXI_wstrb);
  mp_S05_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wlast_converter");
  mp_S05_AXI_wlast_converter->vector_in(S05_AXI_wlast);
  mp_S05_AXI_wlast_converter->scalar_out(m_S05_AXI_wlast_converter_signal);
  mp_S05_AXI_transactor->WLAST(m_S05_AXI_wlast_converter_signal);
  mp_S05_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wvalid_converter");
  mp_S05_AXI_wvalid_converter->vector_in(S05_AXI_wvalid);
  mp_S05_AXI_wvalid_converter->scalar_out(m_S05_AXI_wvalid_converter_signal);
  mp_S05_AXI_transactor->WVALID(m_S05_AXI_wvalid_converter_signal);
  mp_S05_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_wready_converter");
  mp_S05_AXI_wready_converter->scalar_in(m_S05_AXI_wready_converter_signal);
  mp_S05_AXI_wready_converter->vector_out(S05_AXI_wready);
  mp_S05_AXI_transactor->WREADY(m_S05_AXI_wready_converter_signal);
  mp_S05_AXI_transactor->BRESP(S05_AXI_bresp);
  mp_S05_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_bvalid_converter");
  mp_S05_AXI_bvalid_converter->scalar_in(m_S05_AXI_bvalid_converter_signal);
  mp_S05_AXI_bvalid_converter->vector_out(S05_AXI_bvalid);
  mp_S05_AXI_transactor->BVALID(m_S05_AXI_bvalid_converter_signal);
  mp_S05_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_bready_converter");
  mp_S05_AXI_bready_converter->vector_in(S05_AXI_bready);
  mp_S05_AXI_bready_converter->scalar_out(m_S05_AXI_bready_converter_signal);
  mp_S05_AXI_transactor->BREADY(m_S05_AXI_bready_converter_signal);
  mp_S05_AXI_transactor->ARADDR(S05_AXI_araddr);
  mp_S05_AXI_transactor->ARLEN(S05_AXI_arlen);
  mp_S05_AXI_transactor->ARSIZE(S05_AXI_arsize);
  mp_S05_AXI_transactor->ARBURST(S05_AXI_arburst);
  mp_S05_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arlock_converter");
  mp_S05_AXI_arlock_converter->vector_in(S05_AXI_arlock);
  mp_S05_AXI_arlock_converter->scalar_out(m_S05_AXI_arlock_converter_signal);
  mp_S05_AXI_transactor->ARLOCK(m_S05_AXI_arlock_converter_signal);
  mp_S05_AXI_transactor->ARCACHE(S05_AXI_arcache);
  mp_S05_AXI_transactor->ARPROT(S05_AXI_arprot);
  mp_S05_AXI_transactor->ARREGION(S05_AXI_arregion);
  mp_S05_AXI_transactor->ARQOS(S05_AXI_arqos);
  mp_S05_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arvalid_converter");
  mp_S05_AXI_arvalid_converter->vector_in(S05_AXI_arvalid);
  mp_S05_AXI_arvalid_converter->scalar_out(m_S05_AXI_arvalid_converter_signal);
  mp_S05_AXI_transactor->ARVALID(m_S05_AXI_arvalid_converter_signal);
  mp_S05_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_arready_converter");
  mp_S05_AXI_arready_converter->scalar_in(m_S05_AXI_arready_converter_signal);
  mp_S05_AXI_arready_converter->vector_out(S05_AXI_arready);
  mp_S05_AXI_transactor->ARREADY(m_S05_AXI_arready_converter_signal);
  mp_S05_AXI_transactor->RDATA(S05_AXI_rdata);
  mp_S05_AXI_transactor->RRESP(S05_AXI_rresp);
  mp_S05_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rlast_converter");
  mp_S05_AXI_rlast_converter->scalar_in(m_S05_AXI_rlast_converter_signal);
  mp_S05_AXI_rlast_converter->vector_out(S05_AXI_rlast);
  mp_S05_AXI_transactor->RLAST(m_S05_AXI_rlast_converter_signal);
  mp_S05_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rvalid_converter");
  mp_S05_AXI_rvalid_converter->scalar_in(m_S05_AXI_rvalid_converter_signal);
  mp_S05_AXI_rvalid_converter->vector_out(S05_AXI_rvalid);
  mp_S05_AXI_transactor->RVALID(m_S05_AXI_rvalid_converter_signal);
  mp_S05_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_rready_converter");
  mp_S05_AXI_rready_converter->vector_in(S05_AXI_rready);
  mp_S05_AXI_rready_converter->scalar_out(m_S05_AXI_rready_converter_signal);
  mp_S05_AXI_transactor->RREADY(m_S05_AXI_rready_converter_signal);
  mp_S05_AXI_transactor->ARID(S05_AXI_arid);
  mp_S05_AXI_transactor->ARUSER(S05_AXI_aruser);
  mp_S05_AXI_transactor->AWID(S05_AXI_awid);
  mp_S05_AXI_transactor->AWUSER(S05_AXI_awuser);
  mp_S05_AXI_transactor->BID(S05_AXI_bid);
  mp_S05_AXI_transactor->BUSER(S05_AXI_buser);
  mp_S05_AXI_transactor->RID(S05_AXI_rid);
  mp_S05_AXI_transactor->RUSER(S05_AXI_ruser);
  mp_S05_AXI_transactor->WUSER(S05_AXI_wuser);
  mp_S05_AXI_transactor->CLK(aclk5);
  m_S05_AXI_transactor_rst_signal.write(1);
  mp_S05_AXI_transactor->RST(m_S05_AXI_transactor_rst_signal);
  // configure S06_AXI_transactor
    xsc::common_cpp::properties S06_AXI_transactor_param_props;
    S06_AXI_transactor_param_props.addLong("DATA_WIDTH", "32");
    S06_AXI_transactor_param_props.addLong("FREQ_HZ", "100000000");
    S06_AXI_transactor_param_props.addLong("ID_WIDTH", "1");
    S06_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S06_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("RUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S06_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S06_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S06_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S06_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S06_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S06_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S06_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S06_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S06_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S06_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S06_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S06_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pl0_ref_clk");
    S06_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S06_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S06_AXI_transactor_param_props.addString("REGION", "");
    S06_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {500} write_bw {500}}");
    S06_AXI_transactor_param_props.addString("DEST_IDS", "");
    S06_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S06_AXI_transactor_param_props.addString("REMAPS", "");
    S06_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S06_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S06_AXI_transactor_param_props.addString("CATEGORY", "pl");
    S06_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S06_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<32,64,1,1,1,1,1,1>("S06_AXI_transactor", S06_AXI_transactor_param_props);
  mp_S06_AXI_transactor->AWADDR(S06_AXI_awaddr);
  mp_S06_AXI_transactor->AWLEN(S06_AXI_awlen);
  mp_S06_AXI_transactor->AWSIZE(S06_AXI_awsize);
  mp_S06_AXI_transactor->AWBURST(S06_AXI_awburst);
  mp_S06_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awlock_converter");
  mp_S06_AXI_awlock_converter->vector_in(S06_AXI_awlock);
  mp_S06_AXI_awlock_converter->scalar_out(m_S06_AXI_awlock_converter_signal);
  mp_S06_AXI_transactor->AWLOCK(m_S06_AXI_awlock_converter_signal);
  mp_S06_AXI_transactor->AWCACHE(S06_AXI_awcache);
  mp_S06_AXI_transactor->AWPROT(S06_AXI_awprot);
  mp_S06_AXI_transactor->AWREGION(S06_AXI_awregion);
  mp_S06_AXI_transactor->AWQOS(S06_AXI_awqos);
  mp_S06_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awvalid_converter");
  mp_S06_AXI_awvalid_converter->vector_in(S06_AXI_awvalid);
  mp_S06_AXI_awvalid_converter->scalar_out(m_S06_AXI_awvalid_converter_signal);
  mp_S06_AXI_transactor->AWVALID(m_S06_AXI_awvalid_converter_signal);
  mp_S06_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_awready_converter");
  mp_S06_AXI_awready_converter->scalar_in(m_S06_AXI_awready_converter_signal);
  mp_S06_AXI_awready_converter->vector_out(S06_AXI_awready);
  mp_S06_AXI_transactor->AWREADY(m_S06_AXI_awready_converter_signal);
  mp_S06_AXI_transactor->WDATA(S06_AXI_wdata);
  mp_S06_AXI_transactor->WSTRB(S06_AXI_wstrb);
  mp_S06_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wlast_converter");
  mp_S06_AXI_wlast_converter->vector_in(S06_AXI_wlast);
  mp_S06_AXI_wlast_converter->scalar_out(m_S06_AXI_wlast_converter_signal);
  mp_S06_AXI_transactor->WLAST(m_S06_AXI_wlast_converter_signal);
  mp_S06_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wvalid_converter");
  mp_S06_AXI_wvalid_converter->vector_in(S06_AXI_wvalid);
  mp_S06_AXI_wvalid_converter->scalar_out(m_S06_AXI_wvalid_converter_signal);
  mp_S06_AXI_transactor->WVALID(m_S06_AXI_wvalid_converter_signal);
  mp_S06_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_wready_converter");
  mp_S06_AXI_wready_converter->scalar_in(m_S06_AXI_wready_converter_signal);
  mp_S06_AXI_wready_converter->vector_out(S06_AXI_wready);
  mp_S06_AXI_transactor->WREADY(m_S06_AXI_wready_converter_signal);
  mp_S06_AXI_transactor->BRESP(S06_AXI_bresp);
  mp_S06_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_bvalid_converter");
  mp_S06_AXI_bvalid_converter->scalar_in(m_S06_AXI_bvalid_converter_signal);
  mp_S06_AXI_bvalid_converter->vector_out(S06_AXI_bvalid);
  mp_S06_AXI_transactor->BVALID(m_S06_AXI_bvalid_converter_signal);
  mp_S06_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_bready_converter");
  mp_S06_AXI_bready_converter->vector_in(S06_AXI_bready);
  mp_S06_AXI_bready_converter->scalar_out(m_S06_AXI_bready_converter_signal);
  mp_S06_AXI_transactor->BREADY(m_S06_AXI_bready_converter_signal);
  mp_S06_AXI_transactor->ARADDR(S06_AXI_araddr);
  mp_S06_AXI_transactor->ARLEN(S06_AXI_arlen);
  mp_S06_AXI_transactor->ARSIZE(S06_AXI_arsize);
  mp_S06_AXI_transactor->ARBURST(S06_AXI_arburst);
  mp_S06_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arlock_converter");
  mp_S06_AXI_arlock_converter->vector_in(S06_AXI_arlock);
  mp_S06_AXI_arlock_converter->scalar_out(m_S06_AXI_arlock_converter_signal);
  mp_S06_AXI_transactor->ARLOCK(m_S06_AXI_arlock_converter_signal);
  mp_S06_AXI_transactor->ARCACHE(S06_AXI_arcache);
  mp_S06_AXI_transactor->ARPROT(S06_AXI_arprot);
  mp_S06_AXI_transactor->ARREGION(S06_AXI_arregion);
  mp_S06_AXI_transactor->ARQOS(S06_AXI_arqos);
  mp_S06_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arvalid_converter");
  mp_S06_AXI_arvalid_converter->vector_in(S06_AXI_arvalid);
  mp_S06_AXI_arvalid_converter->scalar_out(m_S06_AXI_arvalid_converter_signal);
  mp_S06_AXI_transactor->ARVALID(m_S06_AXI_arvalid_converter_signal);
  mp_S06_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_arready_converter");
  mp_S06_AXI_arready_converter->scalar_in(m_S06_AXI_arready_converter_signal);
  mp_S06_AXI_arready_converter->vector_out(S06_AXI_arready);
  mp_S06_AXI_transactor->ARREADY(m_S06_AXI_arready_converter_signal);
  mp_S06_AXI_transactor->RDATA(S06_AXI_rdata);
  mp_S06_AXI_transactor->RRESP(S06_AXI_rresp);
  mp_S06_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rlast_converter");
  mp_S06_AXI_rlast_converter->scalar_in(m_S06_AXI_rlast_converter_signal);
  mp_S06_AXI_rlast_converter->vector_out(S06_AXI_rlast);
  mp_S06_AXI_transactor->RLAST(m_S06_AXI_rlast_converter_signal);
  mp_S06_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rvalid_converter");
  mp_S06_AXI_rvalid_converter->scalar_in(m_S06_AXI_rvalid_converter_signal);
  mp_S06_AXI_rvalid_converter->vector_out(S06_AXI_rvalid);
  mp_S06_AXI_transactor->RVALID(m_S06_AXI_rvalid_converter_signal);
  mp_S06_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_rready_converter");
  mp_S06_AXI_rready_converter->vector_in(S06_AXI_rready);
  mp_S06_AXI_rready_converter->scalar_out(m_S06_AXI_rready_converter_signal);
  mp_S06_AXI_transactor->RREADY(m_S06_AXI_rready_converter_signal);
  mp_S06_AXI_transactor->ARID(S06_AXI_arid);
  mp_S06_AXI_transactor->AWID(S06_AXI_awid);
  mp_S06_AXI_transactor->BID(S06_AXI_bid);
  mp_S06_AXI_transactor->RID(S06_AXI_rid);
  mp_S06_AXI_transactor->CLK(aclk6);
  m_S06_AXI_transactor_rst_signal.write(1);
  mp_S06_AXI_transactor->RST(m_S06_AXI_transactor_rst_signal);

  // initialize transactors stubs
  S00_AXI_transactor_target_wr_socket_stub = nullptr;
  S00_AXI_transactor_target_rd_socket_stub = nullptr;
  S01_AXI_transactor_target_wr_socket_stub = nullptr;
  S01_AXI_transactor_target_rd_socket_stub = nullptr;
  S02_AXI_transactor_target_wr_socket_stub = nullptr;
  S02_AXI_transactor_target_rd_socket_stub = nullptr;
  S03_AXI_transactor_target_wr_socket_stub = nullptr;
  S03_AXI_transactor_target_rd_socket_stub = nullptr;
  S04_AXI_transactor_target_wr_socket_stub = nullptr;
  S04_AXI_transactor_target_rd_socket_stub = nullptr;
  S05_AXI_transactor_target_wr_socket_stub = nullptr;
  S05_AXI_transactor_target_rd_socket_stub = nullptr;
  S06_AXI_transactor_target_wr_socket_stub = nullptr;
  S06_AXI_transactor_target_rd_socket_stub = nullptr;

}

void bd_soc_usart_axi_noc_0_0::before_end_of_elaboration()
{
  // configure 'S00_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S00_AXI_TLM_MODE") != 1)
  {
    mp_impl->S00_AXI_tlm_aximm_read_socket->bind(*(mp_S00_AXI_transactor->rd_socket));
    mp_impl->S00_AXI_tlm_aximm_write_socket->bind(*(mp_S00_AXI_transactor->wr_socket));
  
  }
  else
  {
    S00_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S00_AXI_transactor_target_wr_socket_stub->bind(*(mp_S00_AXI_transactor->wr_socket));
    S00_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S00_AXI_transactor_target_rd_socket_stub->bind(*(mp_S00_AXI_transactor->rd_socket));
    mp_S00_AXI_transactor->disable_transactor();
  }

  // configure 'S01_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S01_AXI_TLM_MODE") != 1)
  {
    mp_impl->S01_AXI_tlm_aximm_read_socket->bind(*(mp_S01_AXI_transactor->rd_socket));
    mp_impl->S01_AXI_tlm_aximm_write_socket->bind(*(mp_S01_AXI_transactor->wr_socket));
  
  }
  else
  {
    S01_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S01_AXI_transactor_target_wr_socket_stub->bind(*(mp_S01_AXI_transactor->wr_socket));
    S01_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S01_AXI_transactor_target_rd_socket_stub->bind(*(mp_S01_AXI_transactor->rd_socket));
    mp_S01_AXI_transactor->disable_transactor();
  }

  // configure 'S02_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S02_AXI_TLM_MODE") != 1)
  {
    mp_impl->S02_AXI_tlm_aximm_read_socket->bind(*(mp_S02_AXI_transactor->rd_socket));
    mp_impl->S02_AXI_tlm_aximm_write_socket->bind(*(mp_S02_AXI_transactor->wr_socket));
  
  }
  else
  {
    S02_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S02_AXI_transactor_target_wr_socket_stub->bind(*(mp_S02_AXI_transactor->wr_socket));
    S02_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S02_AXI_transactor_target_rd_socket_stub->bind(*(mp_S02_AXI_transactor->rd_socket));
    mp_S02_AXI_transactor->disable_transactor();
  }

  // configure 'S03_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S03_AXI_TLM_MODE") != 1)
  {
    mp_impl->S03_AXI_tlm_aximm_read_socket->bind(*(mp_S03_AXI_transactor->rd_socket));
    mp_impl->S03_AXI_tlm_aximm_write_socket->bind(*(mp_S03_AXI_transactor->wr_socket));
  
  }
  else
  {
    S03_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S03_AXI_transactor_target_wr_socket_stub->bind(*(mp_S03_AXI_transactor->wr_socket));
    S03_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S03_AXI_transactor_target_rd_socket_stub->bind(*(mp_S03_AXI_transactor->rd_socket));
    mp_S03_AXI_transactor->disable_transactor();
  }

  // configure 'S04_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S04_AXI_TLM_MODE") != 1)
  {
    mp_impl->S04_AXI_tlm_aximm_read_socket->bind(*(mp_S04_AXI_transactor->rd_socket));
    mp_impl->S04_AXI_tlm_aximm_write_socket->bind(*(mp_S04_AXI_transactor->wr_socket));
  
  }
  else
  {
    S04_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S04_AXI_transactor_target_wr_socket_stub->bind(*(mp_S04_AXI_transactor->wr_socket));
    S04_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S04_AXI_transactor_target_rd_socket_stub->bind(*(mp_S04_AXI_transactor->rd_socket));
    mp_S04_AXI_transactor->disable_transactor();
  }

  // configure 'S05_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S05_AXI_TLM_MODE") != 1)
  {
    mp_impl->S05_AXI_tlm_aximm_read_socket->bind(*(mp_S05_AXI_transactor->rd_socket));
    mp_impl->S05_AXI_tlm_aximm_write_socket->bind(*(mp_S05_AXI_transactor->wr_socket));
  
  }
  else
  {
    S05_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S05_AXI_transactor_target_wr_socket_stub->bind(*(mp_S05_AXI_transactor->wr_socket));
    S05_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S05_AXI_transactor_target_rd_socket_stub->bind(*(mp_S05_AXI_transactor->rd_socket));
    mp_S05_AXI_transactor->disable_transactor();
  }

  // configure 'S06_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S06_AXI_TLM_MODE") != 1)
  {
    mp_impl->S06_AXI_tlm_aximm_read_socket->bind(*(mp_S06_AXI_transactor->rd_socket));
    mp_impl->S06_AXI_tlm_aximm_write_socket->bind(*(mp_S06_AXI_transactor->wr_socket));
  
  }
  else
  {
    S06_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S06_AXI_transactor_target_wr_socket_stub->bind(*(mp_S06_AXI_transactor->wr_socket));
    S06_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S06_AXI_transactor_target_rd_socket_stub->bind(*(mp_S06_AXI_transactor->rd_socket));
    mp_S06_AXI_transactor->disable_transactor();
  }

}

#endif // VCSSYSTEMC




#ifdef MTI_SYSTEMC
bd_soc_usart_axi_noc_0_0::bd_soc_usart_axi_noc_0_0(const sc_core::sc_module_name& nm) : bd_soc_usart_axi_noc_0_0_sc(nm),  S00_AXI_awaddr("S00_AXI_awaddr"), S00_AXI_awlen("S00_AXI_awlen"), S00_AXI_awsize("S00_AXI_awsize"), S00_AXI_awburst("S00_AXI_awburst"), S00_AXI_awlock("S00_AXI_awlock"), S00_AXI_awcache("S00_AXI_awcache"), S00_AXI_awprot("S00_AXI_awprot"), S00_AXI_awregion("S00_AXI_awregion"), S00_AXI_awqos("S00_AXI_awqos"), S00_AXI_awvalid("S00_AXI_awvalid"), S00_AXI_awready("S00_AXI_awready"), S00_AXI_wdata("S00_AXI_wdata"), S00_AXI_wstrb("S00_AXI_wstrb"), S00_AXI_wlast("S00_AXI_wlast"), S00_AXI_wvalid("S00_AXI_wvalid"), S00_AXI_wready("S00_AXI_wready"), S00_AXI_bresp("S00_AXI_bresp"), S00_AXI_bvalid("S00_AXI_bvalid"), S00_AXI_bready("S00_AXI_bready"), S00_AXI_araddr("S00_AXI_araddr"), S00_AXI_arlen("S00_AXI_arlen"), S00_AXI_arsize("S00_AXI_arsize"), S00_AXI_arburst("S00_AXI_arburst"), S00_AXI_arlock("S00_AXI_arlock"), S00_AXI_arcache("S00_AXI_arcache"), S00_AXI_arprot("S00_AXI_arprot"), S00_AXI_arregion("S00_AXI_arregion"), S00_AXI_arqos("S00_AXI_arqos"), S00_AXI_arvalid("S00_AXI_arvalid"), S00_AXI_arready("S00_AXI_arready"), S00_AXI_rdata("S00_AXI_rdata"), S00_AXI_rresp("S00_AXI_rresp"), S00_AXI_rlast("S00_AXI_rlast"), S00_AXI_rvalid("S00_AXI_rvalid"), S00_AXI_rready("S00_AXI_rready"), S01_AXI_awaddr("S01_AXI_awaddr"), S01_AXI_awlen("S01_AXI_awlen"), S01_AXI_awsize("S01_AXI_awsize"), S01_AXI_awburst("S01_AXI_awburst"), S01_AXI_awlock("S01_AXI_awlock"), S01_AXI_awcache("S01_AXI_awcache"), S01_AXI_awprot("S01_AXI_awprot"), S01_AXI_awregion("S01_AXI_awregion"), S01_AXI_awqos("S01_AXI_awqos"), S01_AXI_awvalid("S01_AXI_awvalid"), S01_AXI_awready("S01_AXI_awready"), S01_AXI_wdata("S01_AXI_wdata"), S01_AXI_wstrb("S01_AXI_wstrb"), S01_AXI_wlast("S01_AXI_wlast"), S01_AXI_wvalid("S01_AXI_wvalid"), S01_AXI_wready("S01_AXI_wready"), S01_AXI_bresp("S01_AXI_bresp"), S01_AXI_bvalid("S01_AXI_bvalid"), S01_AXI_bready("S01_AXI_bready"), S01_AXI_araddr("S01_AXI_araddr"), S01_AXI_arlen("S01_AXI_arlen"), S01_AXI_arsize("S01_AXI_arsize"), S01_AXI_arburst("S01_AXI_arburst"), S01_AXI_arlock("S01_AXI_arlock"), S01_AXI_arcache("S01_AXI_arcache"), S01_AXI_arprot("S01_AXI_arprot"), S01_AXI_arregion("S01_AXI_arregion"), S01_AXI_arqos("S01_AXI_arqos"), S01_AXI_arvalid("S01_AXI_arvalid"), S01_AXI_arready("S01_AXI_arready"), S01_AXI_rdata("S01_AXI_rdata"), S01_AXI_rresp("S01_AXI_rresp"), S01_AXI_rlast("S01_AXI_rlast"), S01_AXI_rvalid("S01_AXI_rvalid"), S01_AXI_rready("S01_AXI_rready"), S02_AXI_awaddr("S02_AXI_awaddr"), S02_AXI_awlen("S02_AXI_awlen"), S02_AXI_awsize("S02_AXI_awsize"), S02_AXI_awburst("S02_AXI_awburst"), S02_AXI_awlock("S02_AXI_awlock"), S02_AXI_awcache("S02_AXI_awcache"), S02_AXI_awprot("S02_AXI_awprot"), S02_AXI_awregion("S02_AXI_awregion"), S02_AXI_awqos("S02_AXI_awqos"), S02_AXI_awvalid("S02_AXI_awvalid"), S02_AXI_awready("S02_AXI_awready"), S02_AXI_wdata("S02_AXI_wdata"), S02_AXI_wstrb("S02_AXI_wstrb"), S02_AXI_wlast("S02_AXI_wlast"), S02_AXI_wvalid("S02_AXI_wvalid"), S02_AXI_wready("S02_AXI_wready"), S02_AXI_bresp("S02_AXI_bresp"), S02_AXI_bvalid("S02_AXI_bvalid"), S02_AXI_bready("S02_AXI_bready"), S02_AXI_araddr("S02_AXI_araddr"), S02_AXI_arlen("S02_AXI_arlen"), S02_AXI_arsize("S02_AXI_arsize"), S02_AXI_arburst("S02_AXI_arburst"), S02_AXI_arlock("S02_AXI_arlock"), S02_AXI_arcache("S02_AXI_arcache"), S02_AXI_arprot("S02_AXI_arprot"), S02_AXI_arregion("S02_AXI_arregion"), S02_AXI_arqos("S02_AXI_arqos"), S02_AXI_arvalid("S02_AXI_arvalid"), S02_AXI_arready("S02_AXI_arready"), S02_AXI_rdata("S02_AXI_rdata"), S02_AXI_rresp("S02_AXI_rresp"), S02_AXI_rlast("S02_AXI_rlast"), S02_AXI_rvalid("S02_AXI_rvalid"), S02_AXI_rready("S02_AXI_rready"), S03_AXI_awaddr("S03_AXI_awaddr"), S03_AXI_awlen("S03_AXI_awlen"), S03_AXI_awsize("S03_AXI_awsize"), S03_AXI_awburst("S03_AXI_awburst"), S03_AXI_awlock("S03_AXI_awlock"), S03_AXI_awcache("S03_AXI_awcache"), S03_AXI_awprot("S03_AXI_awprot"), S03_AXI_awregion("S03_AXI_awregion"), S03_AXI_awqos("S03_AXI_awqos"), S03_AXI_awvalid("S03_AXI_awvalid"), S03_AXI_awready("S03_AXI_awready"), S03_AXI_wdata("S03_AXI_wdata"), S03_AXI_wstrb("S03_AXI_wstrb"), S03_AXI_wlast("S03_AXI_wlast"), S03_AXI_wvalid("S03_AXI_wvalid"), S03_AXI_wready("S03_AXI_wready"), S03_AXI_bresp("S03_AXI_bresp"), S03_AXI_bvalid("S03_AXI_bvalid"), S03_AXI_bready("S03_AXI_bready"), S03_AXI_araddr("S03_AXI_araddr"), S03_AXI_arlen("S03_AXI_arlen"), S03_AXI_arsize("S03_AXI_arsize"), S03_AXI_arburst("S03_AXI_arburst"), S03_AXI_arlock("S03_AXI_arlock"), S03_AXI_arcache("S03_AXI_arcache"), S03_AXI_arprot("S03_AXI_arprot"), S03_AXI_arregion("S03_AXI_arregion"), S03_AXI_arqos("S03_AXI_arqos"), S03_AXI_arvalid("S03_AXI_arvalid"), S03_AXI_arready("S03_AXI_arready"), S03_AXI_rdata("S03_AXI_rdata"), S03_AXI_rresp("S03_AXI_rresp"), S03_AXI_rlast("S03_AXI_rlast"), S03_AXI_rvalid("S03_AXI_rvalid"), S03_AXI_rready("S03_AXI_rready"), S04_AXI_awaddr("S04_AXI_awaddr"), S04_AXI_awlen("S04_AXI_awlen"), S04_AXI_awsize("S04_AXI_awsize"), S04_AXI_awburst("S04_AXI_awburst"), S04_AXI_awlock("S04_AXI_awlock"), S04_AXI_awcache("S04_AXI_awcache"), S04_AXI_awprot("S04_AXI_awprot"), S04_AXI_awregion("S04_AXI_awregion"), S04_AXI_awqos("S04_AXI_awqos"), S04_AXI_awvalid("S04_AXI_awvalid"), S04_AXI_awready("S04_AXI_awready"), S04_AXI_wdata("S04_AXI_wdata"), S04_AXI_wstrb("S04_AXI_wstrb"), S04_AXI_wlast("S04_AXI_wlast"), S04_AXI_wvalid("S04_AXI_wvalid"), S04_AXI_wready("S04_AXI_wready"), S04_AXI_bresp("S04_AXI_bresp"), S04_AXI_bvalid("S04_AXI_bvalid"), S04_AXI_bready("S04_AXI_bready"), S04_AXI_araddr("S04_AXI_araddr"), S04_AXI_arlen("S04_AXI_arlen"), S04_AXI_arsize("S04_AXI_arsize"), S04_AXI_arburst("S04_AXI_arburst"), S04_AXI_arlock("S04_AXI_arlock"), S04_AXI_arcache("S04_AXI_arcache"), S04_AXI_arprot("S04_AXI_arprot"), S04_AXI_arregion("S04_AXI_arregion"), S04_AXI_arqos("S04_AXI_arqos"), S04_AXI_arvalid("S04_AXI_arvalid"), S04_AXI_arready("S04_AXI_arready"), S04_AXI_rdata("S04_AXI_rdata"), S04_AXI_rresp("S04_AXI_rresp"), S04_AXI_rlast("S04_AXI_rlast"), S04_AXI_rvalid("S04_AXI_rvalid"), S04_AXI_rready("S04_AXI_rready"), S05_AXI_awaddr("S05_AXI_awaddr"), S05_AXI_awlen("S05_AXI_awlen"), S05_AXI_awsize("S05_AXI_awsize"), S05_AXI_awburst("S05_AXI_awburst"), S05_AXI_awlock("S05_AXI_awlock"), S05_AXI_awcache("S05_AXI_awcache"), S05_AXI_awprot("S05_AXI_awprot"), S05_AXI_awregion("S05_AXI_awregion"), S05_AXI_awqos("S05_AXI_awqos"), S05_AXI_awvalid("S05_AXI_awvalid"), S05_AXI_awready("S05_AXI_awready"), S05_AXI_wdata("S05_AXI_wdata"), S05_AXI_wstrb("S05_AXI_wstrb"), S05_AXI_wlast("S05_AXI_wlast"), S05_AXI_wvalid("S05_AXI_wvalid"), S05_AXI_wready("S05_AXI_wready"), S05_AXI_bresp("S05_AXI_bresp"), S05_AXI_bvalid("S05_AXI_bvalid"), S05_AXI_bready("S05_AXI_bready"), S05_AXI_araddr("S05_AXI_araddr"), S05_AXI_arlen("S05_AXI_arlen"), S05_AXI_arsize("S05_AXI_arsize"), S05_AXI_arburst("S05_AXI_arburst"), S05_AXI_arlock("S05_AXI_arlock"), S05_AXI_arcache("S05_AXI_arcache"), S05_AXI_arprot("S05_AXI_arprot"), S05_AXI_arregion("S05_AXI_arregion"), S05_AXI_arqos("S05_AXI_arqos"), S05_AXI_arvalid("S05_AXI_arvalid"), S05_AXI_arready("S05_AXI_arready"), S05_AXI_rdata("S05_AXI_rdata"), S05_AXI_rresp("S05_AXI_rresp"), S05_AXI_rlast("S05_AXI_rlast"), S05_AXI_rvalid("S05_AXI_rvalid"), S05_AXI_rready("S05_AXI_rready"), S06_AXI_awaddr("S06_AXI_awaddr"), S06_AXI_awlen("S06_AXI_awlen"), S06_AXI_awsize("S06_AXI_awsize"), S06_AXI_awburst("S06_AXI_awburst"), S06_AXI_awlock("S06_AXI_awlock"), S06_AXI_awcache("S06_AXI_awcache"), S06_AXI_awprot("S06_AXI_awprot"), S06_AXI_awregion("S06_AXI_awregion"), S06_AXI_awqos("S06_AXI_awqos"), S06_AXI_awvalid("S06_AXI_awvalid"), S06_AXI_awready("S06_AXI_awready"), S06_AXI_wdata("S06_AXI_wdata"), S06_AXI_wstrb("S06_AXI_wstrb"), S06_AXI_wlast("S06_AXI_wlast"), S06_AXI_wvalid("S06_AXI_wvalid"), S06_AXI_wready("S06_AXI_wready"), S06_AXI_bresp("S06_AXI_bresp"), S06_AXI_bvalid("S06_AXI_bvalid"), S06_AXI_bready("S06_AXI_bready"), S06_AXI_araddr("S06_AXI_araddr"), S06_AXI_arlen("S06_AXI_arlen"), S06_AXI_arsize("S06_AXI_arsize"), S06_AXI_arburst("S06_AXI_arburst"), S06_AXI_arlock("S06_AXI_arlock"), S06_AXI_arcache("S06_AXI_arcache"), S06_AXI_arprot("S06_AXI_arprot"), S06_AXI_arregion("S06_AXI_arregion"), S06_AXI_arqos("S06_AXI_arqos"), S06_AXI_arvalid("S06_AXI_arvalid"), S06_AXI_arready("S06_AXI_arready"), S06_AXI_rdata("S06_AXI_rdata"), S06_AXI_rresp("S06_AXI_rresp"), S06_AXI_rlast("S06_AXI_rlast"), S06_AXI_rvalid("S06_AXI_rvalid"), S06_AXI_rready("S06_AXI_rready"), aclk0("aclk0"), aclk1("aclk1"), aclk2("aclk2"), aclk3("aclk3"), aclk4("aclk4"), aclk5("aclk5"), aclk6("aclk6"), sys_clk0_clk_p("sys_clk0_clk_p"), sys_clk0_clk_n("sys_clk0_clk_n"), CH0_DDR4_0_dq("CH0_DDR4_0_dq"), CH0_DDR4_0_dqs_t("CH0_DDR4_0_dqs_t"), CH0_DDR4_0_dqs_c("CH0_DDR4_0_dqs_c"), CH0_DDR4_0_adr("CH0_DDR4_0_adr"), CH0_DDR4_0_ba("CH0_DDR4_0_ba"), CH0_DDR4_0_bg("CH0_DDR4_0_bg"), CH0_DDR4_0_act_n("CH0_DDR4_0_act_n"), CH0_DDR4_0_reset_n("CH0_DDR4_0_reset_n"), CH0_DDR4_0_ck_t("CH0_DDR4_0_ck_t"), CH0_DDR4_0_ck_c("CH0_DDR4_0_ck_c"), CH0_DDR4_0_cke("CH0_DDR4_0_cke"), CH0_DDR4_0_cs_n("CH0_DDR4_0_cs_n"), CH0_DDR4_0_dm_n("CH0_DDR4_0_dm_n"), CH0_DDR4_0_odt("CH0_DDR4_0_odt"), S05_AXI_arid("S05_AXI_arid"), S05_AXI_aruser("S05_AXI_aruser"), S05_AXI_awid("S05_AXI_awid"), S05_AXI_awuser("S05_AXI_awuser"), S05_AXI_bid("S05_AXI_bid"), S05_AXI_buser("S05_AXI_buser"), S05_AXI_rid("S05_AXI_rid"), S05_AXI_ruser("S05_AXI_ruser"), S05_AXI_wuser("S05_AXI_wuser"), S03_AXI_arid("S03_AXI_arid"), S03_AXI_aruser("S03_AXI_aruser"), S03_AXI_awid("S03_AXI_awid"), S03_AXI_awuser("S03_AXI_awuser"), S03_AXI_bid("S03_AXI_bid"), S03_AXI_rid("S03_AXI_rid"), S03_AXI_ruser("S03_AXI_ruser"), S03_AXI_wuser("S03_AXI_wuser"), S04_AXI_arid("S04_AXI_arid"), S04_AXI_aruser("S04_AXI_aruser"), S04_AXI_awid("S04_AXI_awid"), S04_AXI_awuser("S04_AXI_awuser"), S04_AXI_bid("S04_AXI_bid"), S04_AXI_rid("S04_AXI_rid"), S04_AXI_ruser("S04_AXI_ruser"), S04_AXI_wuser("S04_AXI_wuser"), S02_AXI_arid("S02_AXI_arid"), S02_AXI_aruser("S02_AXI_aruser"), S02_AXI_awid("S02_AXI_awid"), S02_AXI_awuser("S02_AXI_awuser"), S02_AXI_bid("S02_AXI_bid"), S02_AXI_rid("S02_AXI_rid"), S02_AXI_ruser("S02_AXI_ruser"), S02_AXI_wuser("S02_AXI_wuser"), S06_AXI_arid("S06_AXI_arid"), S06_AXI_awid("S06_AXI_awid"), S06_AXI_bid("S06_AXI_bid"), S06_AXI_rid("S06_AXI_rid"), S01_AXI_arid("S01_AXI_arid"), S01_AXI_aruser("S01_AXI_aruser"), S01_AXI_awid("S01_AXI_awid"), S01_AXI_awuser("S01_AXI_awuser"), S01_AXI_bid("S01_AXI_bid"), S01_AXI_rid("S01_AXI_rid"), S01_AXI_ruser("S01_AXI_ruser"), S01_AXI_wuser("S01_AXI_wuser"), S00_AXI_arid("S00_AXI_arid"), S00_AXI_aruser("S00_AXI_aruser"), S00_AXI_awid("S00_AXI_awid"), S00_AXI_awuser("S00_AXI_awuser"), S00_AXI_bid("S00_AXI_bid"), S00_AXI_rid("S00_AXI_rid"), S00_AXI_ruser("S00_AXI_ruser"), S00_AXI_wuser("S00_AXI_wuser")
{
  // initialize pins
  mp_impl->aclk0(aclk0);
  mp_impl->aclk1(aclk1);
  mp_impl->aclk2(aclk2);
  mp_impl->aclk3(aclk3);
  mp_impl->aclk4(aclk4);
  mp_impl->aclk5(aclk5);
  mp_impl->aclk6(aclk6);
  mp_impl->sys_clk0_clk_p(sys_clk0_clk_p);
  mp_impl->sys_clk0_clk_n(sys_clk0_clk_n);
  mp_impl->CH0_DDR4_0_dq(CH0_DDR4_0_dq);
  mp_impl->CH0_DDR4_0_dqs_t(CH0_DDR4_0_dqs_t);
  mp_impl->CH0_DDR4_0_dqs_c(CH0_DDR4_0_dqs_c);
  mp_impl->CH0_DDR4_0_adr(CH0_DDR4_0_adr);
  mp_impl->CH0_DDR4_0_ba(CH0_DDR4_0_ba);
  mp_impl->CH0_DDR4_0_bg(CH0_DDR4_0_bg);
  mp_impl->CH0_DDR4_0_act_n(CH0_DDR4_0_act_n);
  mp_impl->CH0_DDR4_0_reset_n(CH0_DDR4_0_reset_n);
  mp_impl->CH0_DDR4_0_ck_t(CH0_DDR4_0_ck_t);
  mp_impl->CH0_DDR4_0_ck_c(CH0_DDR4_0_ck_c);
  mp_impl->CH0_DDR4_0_cke(CH0_DDR4_0_cke);
  mp_impl->CH0_DDR4_0_cs_n(CH0_DDR4_0_cs_n);
  mp_impl->CH0_DDR4_0_dm_n(CH0_DDR4_0_dm_n);
  mp_impl->CH0_DDR4_0_odt(CH0_DDR4_0_odt);

  // initialize transactors
  mp_S00_AXI_transactor = NULL;
  mp_S00_AXI_awlock_converter = NULL;
  mp_S00_AXI_awvalid_converter = NULL;
  mp_S00_AXI_awready_converter = NULL;
  mp_S00_AXI_wlast_converter = NULL;
  mp_S00_AXI_wvalid_converter = NULL;
  mp_S00_AXI_wready_converter = NULL;
  mp_S00_AXI_bvalid_converter = NULL;
  mp_S00_AXI_bready_converter = NULL;
  mp_S00_AXI_arlock_converter = NULL;
  mp_S00_AXI_arvalid_converter = NULL;
  mp_S00_AXI_arready_converter = NULL;
  mp_S00_AXI_rlast_converter = NULL;
  mp_S00_AXI_rvalid_converter = NULL;
  mp_S00_AXI_rready_converter = NULL;
  mp_S01_AXI_transactor = NULL;
  mp_S01_AXI_awlock_converter = NULL;
  mp_S01_AXI_awvalid_converter = NULL;
  mp_S01_AXI_awready_converter = NULL;
  mp_S01_AXI_wlast_converter = NULL;
  mp_S01_AXI_wvalid_converter = NULL;
  mp_S01_AXI_wready_converter = NULL;
  mp_S01_AXI_bvalid_converter = NULL;
  mp_S01_AXI_bready_converter = NULL;
  mp_S01_AXI_arlock_converter = NULL;
  mp_S01_AXI_arvalid_converter = NULL;
  mp_S01_AXI_arready_converter = NULL;
  mp_S01_AXI_rlast_converter = NULL;
  mp_S01_AXI_rvalid_converter = NULL;
  mp_S01_AXI_rready_converter = NULL;
  mp_S02_AXI_transactor = NULL;
  mp_S02_AXI_awlock_converter = NULL;
  mp_S02_AXI_awvalid_converter = NULL;
  mp_S02_AXI_awready_converter = NULL;
  mp_S02_AXI_wlast_converter = NULL;
  mp_S02_AXI_wvalid_converter = NULL;
  mp_S02_AXI_wready_converter = NULL;
  mp_S02_AXI_bvalid_converter = NULL;
  mp_S02_AXI_bready_converter = NULL;
  mp_S02_AXI_arlock_converter = NULL;
  mp_S02_AXI_arvalid_converter = NULL;
  mp_S02_AXI_arready_converter = NULL;
  mp_S02_AXI_rlast_converter = NULL;
  mp_S02_AXI_rvalid_converter = NULL;
  mp_S02_AXI_rready_converter = NULL;
  mp_S03_AXI_transactor = NULL;
  mp_S03_AXI_awlock_converter = NULL;
  mp_S03_AXI_awvalid_converter = NULL;
  mp_S03_AXI_awready_converter = NULL;
  mp_S03_AXI_wlast_converter = NULL;
  mp_S03_AXI_wvalid_converter = NULL;
  mp_S03_AXI_wready_converter = NULL;
  mp_S03_AXI_bvalid_converter = NULL;
  mp_S03_AXI_bready_converter = NULL;
  mp_S03_AXI_arlock_converter = NULL;
  mp_S03_AXI_arvalid_converter = NULL;
  mp_S03_AXI_arready_converter = NULL;
  mp_S03_AXI_rlast_converter = NULL;
  mp_S03_AXI_rvalid_converter = NULL;
  mp_S03_AXI_rready_converter = NULL;
  mp_S04_AXI_transactor = NULL;
  mp_S04_AXI_awlock_converter = NULL;
  mp_S04_AXI_awvalid_converter = NULL;
  mp_S04_AXI_awready_converter = NULL;
  mp_S04_AXI_wlast_converter = NULL;
  mp_S04_AXI_wvalid_converter = NULL;
  mp_S04_AXI_wready_converter = NULL;
  mp_S04_AXI_bvalid_converter = NULL;
  mp_S04_AXI_bready_converter = NULL;
  mp_S04_AXI_arlock_converter = NULL;
  mp_S04_AXI_arvalid_converter = NULL;
  mp_S04_AXI_arready_converter = NULL;
  mp_S04_AXI_rlast_converter = NULL;
  mp_S04_AXI_rvalid_converter = NULL;
  mp_S04_AXI_rready_converter = NULL;
  mp_S05_AXI_transactor = NULL;
  mp_S05_AXI_awlock_converter = NULL;
  mp_S05_AXI_awvalid_converter = NULL;
  mp_S05_AXI_awready_converter = NULL;
  mp_S05_AXI_wlast_converter = NULL;
  mp_S05_AXI_wvalid_converter = NULL;
  mp_S05_AXI_wready_converter = NULL;
  mp_S05_AXI_bvalid_converter = NULL;
  mp_S05_AXI_bready_converter = NULL;
  mp_S05_AXI_arlock_converter = NULL;
  mp_S05_AXI_arvalid_converter = NULL;
  mp_S05_AXI_arready_converter = NULL;
  mp_S05_AXI_rlast_converter = NULL;
  mp_S05_AXI_rvalid_converter = NULL;
  mp_S05_AXI_rready_converter = NULL;
  mp_S06_AXI_transactor = NULL;
  mp_S06_AXI_awlock_converter = NULL;
  mp_S06_AXI_awvalid_converter = NULL;
  mp_S06_AXI_awready_converter = NULL;
  mp_S06_AXI_wlast_converter = NULL;
  mp_S06_AXI_wvalid_converter = NULL;
  mp_S06_AXI_wready_converter = NULL;
  mp_S06_AXI_bvalid_converter = NULL;
  mp_S06_AXI_bready_converter = NULL;
  mp_S06_AXI_arlock_converter = NULL;
  mp_S06_AXI_arvalid_converter = NULL;
  mp_S06_AXI_arready_converter = NULL;
  mp_S06_AXI_rlast_converter = NULL;
  mp_S06_AXI_rvalid_converter = NULL;
  mp_S06_AXI_rready_converter = NULL;

  // Instantiate Socket Stubs

  // configure S00_AXI_transactor
    xsc::common_cpp::properties S00_AXI_transactor_param_props;
    S00_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S00_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S00_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S00_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S00_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S00_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S00_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S00_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S00_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S00_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S00_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S00_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S00_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S00_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S00_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S00_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S00_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S00_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S00_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S00_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S00_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S00_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S00_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S00_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi0_clk");
    S00_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S00_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S00_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S00_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S00_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S00_AXI_transactor_param_props.addString("REGION", "0");
    S00_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S00_AXI_transactor_param_props.addString("DEST_IDS", "");
    S00_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S00_AXI_transactor_param_props.addString("REMAPS", "");
    S00_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S00_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S00_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S00_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S00_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S00_AXI_transactor", S00_AXI_transactor_param_props);
  mp_S00_AXI_transactor->AWADDR(S00_AXI_awaddr);
  mp_S00_AXI_transactor->AWLEN(S00_AXI_awlen);
  mp_S00_AXI_transactor->AWSIZE(S00_AXI_awsize);
  mp_S00_AXI_transactor->AWBURST(S00_AXI_awburst);
  mp_S00_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awlock_converter");
  mp_S00_AXI_awlock_converter->vector_in(S00_AXI_awlock);
  mp_S00_AXI_awlock_converter->scalar_out(m_S00_AXI_awlock_converter_signal);
  mp_S00_AXI_transactor->AWLOCK(m_S00_AXI_awlock_converter_signal);
  mp_S00_AXI_transactor->AWCACHE(S00_AXI_awcache);
  mp_S00_AXI_transactor->AWPROT(S00_AXI_awprot);
  mp_S00_AXI_transactor->AWREGION(S00_AXI_awregion);
  mp_S00_AXI_transactor->AWQOS(S00_AXI_awqos);
  mp_S00_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_awvalid_converter");
  mp_S00_AXI_awvalid_converter->vector_in(S00_AXI_awvalid);
  mp_S00_AXI_awvalid_converter->scalar_out(m_S00_AXI_awvalid_converter_signal);
  mp_S00_AXI_transactor->AWVALID(m_S00_AXI_awvalid_converter_signal);
  mp_S00_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_awready_converter");
  mp_S00_AXI_awready_converter->scalar_in(m_S00_AXI_awready_converter_signal);
  mp_S00_AXI_awready_converter->vector_out(S00_AXI_awready);
  mp_S00_AXI_transactor->AWREADY(m_S00_AXI_awready_converter_signal);
  mp_S00_AXI_transactor->WDATA(S00_AXI_wdata);
  mp_S00_AXI_transactor->WSTRB(S00_AXI_wstrb);
  mp_S00_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wlast_converter");
  mp_S00_AXI_wlast_converter->vector_in(S00_AXI_wlast);
  mp_S00_AXI_wlast_converter->scalar_out(m_S00_AXI_wlast_converter_signal);
  mp_S00_AXI_transactor->WLAST(m_S00_AXI_wlast_converter_signal);
  mp_S00_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_wvalid_converter");
  mp_S00_AXI_wvalid_converter->vector_in(S00_AXI_wvalid);
  mp_S00_AXI_wvalid_converter->scalar_out(m_S00_AXI_wvalid_converter_signal);
  mp_S00_AXI_transactor->WVALID(m_S00_AXI_wvalid_converter_signal);
  mp_S00_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_wready_converter");
  mp_S00_AXI_wready_converter->scalar_in(m_S00_AXI_wready_converter_signal);
  mp_S00_AXI_wready_converter->vector_out(S00_AXI_wready);
  mp_S00_AXI_transactor->WREADY(m_S00_AXI_wready_converter_signal);
  mp_S00_AXI_transactor->BRESP(S00_AXI_bresp);
  mp_S00_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_bvalid_converter");
  mp_S00_AXI_bvalid_converter->scalar_in(m_S00_AXI_bvalid_converter_signal);
  mp_S00_AXI_bvalid_converter->vector_out(S00_AXI_bvalid);
  mp_S00_AXI_transactor->BVALID(m_S00_AXI_bvalid_converter_signal);
  mp_S00_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_bready_converter");
  mp_S00_AXI_bready_converter->vector_in(S00_AXI_bready);
  mp_S00_AXI_bready_converter->scalar_out(m_S00_AXI_bready_converter_signal);
  mp_S00_AXI_transactor->BREADY(m_S00_AXI_bready_converter_signal);
  mp_S00_AXI_transactor->ARADDR(S00_AXI_araddr);
  mp_S00_AXI_transactor->ARLEN(S00_AXI_arlen);
  mp_S00_AXI_transactor->ARSIZE(S00_AXI_arsize);
  mp_S00_AXI_transactor->ARBURST(S00_AXI_arburst);
  mp_S00_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arlock_converter");
  mp_S00_AXI_arlock_converter->vector_in(S00_AXI_arlock);
  mp_S00_AXI_arlock_converter->scalar_out(m_S00_AXI_arlock_converter_signal);
  mp_S00_AXI_transactor->ARLOCK(m_S00_AXI_arlock_converter_signal);
  mp_S00_AXI_transactor->ARCACHE(S00_AXI_arcache);
  mp_S00_AXI_transactor->ARPROT(S00_AXI_arprot);
  mp_S00_AXI_transactor->ARREGION(S00_AXI_arregion);
  mp_S00_AXI_transactor->ARQOS(S00_AXI_arqos);
  mp_S00_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_arvalid_converter");
  mp_S00_AXI_arvalid_converter->vector_in(S00_AXI_arvalid);
  mp_S00_AXI_arvalid_converter->scalar_out(m_S00_AXI_arvalid_converter_signal);
  mp_S00_AXI_transactor->ARVALID(m_S00_AXI_arvalid_converter_signal);
  mp_S00_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_arready_converter");
  mp_S00_AXI_arready_converter->scalar_in(m_S00_AXI_arready_converter_signal);
  mp_S00_AXI_arready_converter->vector_out(S00_AXI_arready);
  mp_S00_AXI_transactor->ARREADY(m_S00_AXI_arready_converter_signal);
  mp_S00_AXI_transactor->RDATA(S00_AXI_rdata);
  mp_S00_AXI_transactor->RRESP(S00_AXI_rresp);
  mp_S00_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rlast_converter");
  mp_S00_AXI_rlast_converter->scalar_in(m_S00_AXI_rlast_converter_signal);
  mp_S00_AXI_rlast_converter->vector_out(S00_AXI_rlast);
  mp_S00_AXI_transactor->RLAST(m_S00_AXI_rlast_converter_signal);
  mp_S00_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S00_AXI_rvalid_converter");
  mp_S00_AXI_rvalid_converter->scalar_in(m_S00_AXI_rvalid_converter_signal);
  mp_S00_AXI_rvalid_converter->vector_out(S00_AXI_rvalid);
  mp_S00_AXI_transactor->RVALID(m_S00_AXI_rvalid_converter_signal);
  mp_S00_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S00_AXI_rready_converter");
  mp_S00_AXI_rready_converter->vector_in(S00_AXI_rready);
  mp_S00_AXI_rready_converter->scalar_out(m_S00_AXI_rready_converter_signal);
  mp_S00_AXI_transactor->RREADY(m_S00_AXI_rready_converter_signal);
  mp_S00_AXI_transactor->ARID(S00_AXI_arid);
  mp_S00_AXI_transactor->ARUSER(S00_AXI_aruser);
  mp_S00_AXI_transactor->AWID(S00_AXI_awid);
  mp_S00_AXI_transactor->AWUSER(S00_AXI_awuser);
  mp_S00_AXI_transactor->BID(S00_AXI_bid);
  mp_S00_AXI_transactor->RID(S00_AXI_rid);
  mp_S00_AXI_transactor->RUSER(S00_AXI_ruser);
  mp_S00_AXI_transactor->WUSER(S00_AXI_wuser);
  mp_S00_AXI_transactor->CLK(aclk0);
  m_S00_AXI_transactor_rst_signal.write(1);
  mp_S00_AXI_transactor->RST(m_S00_AXI_transactor_rst_signal);
  // configure S01_AXI_transactor
    xsc::common_cpp::properties S01_AXI_transactor_param_props;
    S01_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S01_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S01_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S01_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S01_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S01_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S01_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S01_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S01_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S01_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S01_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S01_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S01_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S01_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S01_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S01_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S01_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S01_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S01_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S01_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S01_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S01_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S01_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S01_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi1_clk");
    S01_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S01_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S01_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S01_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S01_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S01_AXI_transactor_param_props.addString("REGION", "0");
    S01_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S01_AXI_transactor_param_props.addString("DEST_IDS", "");
    S01_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S01_AXI_transactor_param_props.addString("REMAPS", "");
    S01_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S01_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S01_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S01_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S01_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S01_AXI_transactor", S01_AXI_transactor_param_props);
  mp_S01_AXI_transactor->AWADDR(S01_AXI_awaddr);
  mp_S01_AXI_transactor->AWLEN(S01_AXI_awlen);
  mp_S01_AXI_transactor->AWSIZE(S01_AXI_awsize);
  mp_S01_AXI_transactor->AWBURST(S01_AXI_awburst);
  mp_S01_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awlock_converter");
  mp_S01_AXI_awlock_converter->vector_in(S01_AXI_awlock);
  mp_S01_AXI_awlock_converter->scalar_out(m_S01_AXI_awlock_converter_signal);
  mp_S01_AXI_transactor->AWLOCK(m_S01_AXI_awlock_converter_signal);
  mp_S01_AXI_transactor->AWCACHE(S01_AXI_awcache);
  mp_S01_AXI_transactor->AWPROT(S01_AXI_awprot);
  mp_S01_AXI_transactor->AWREGION(S01_AXI_awregion);
  mp_S01_AXI_transactor->AWQOS(S01_AXI_awqos);
  mp_S01_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_awvalid_converter");
  mp_S01_AXI_awvalid_converter->vector_in(S01_AXI_awvalid);
  mp_S01_AXI_awvalid_converter->scalar_out(m_S01_AXI_awvalid_converter_signal);
  mp_S01_AXI_transactor->AWVALID(m_S01_AXI_awvalid_converter_signal);
  mp_S01_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_awready_converter");
  mp_S01_AXI_awready_converter->scalar_in(m_S01_AXI_awready_converter_signal);
  mp_S01_AXI_awready_converter->vector_out(S01_AXI_awready);
  mp_S01_AXI_transactor->AWREADY(m_S01_AXI_awready_converter_signal);
  mp_S01_AXI_transactor->WDATA(S01_AXI_wdata);
  mp_S01_AXI_transactor->WSTRB(S01_AXI_wstrb);
  mp_S01_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wlast_converter");
  mp_S01_AXI_wlast_converter->vector_in(S01_AXI_wlast);
  mp_S01_AXI_wlast_converter->scalar_out(m_S01_AXI_wlast_converter_signal);
  mp_S01_AXI_transactor->WLAST(m_S01_AXI_wlast_converter_signal);
  mp_S01_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_wvalid_converter");
  mp_S01_AXI_wvalid_converter->vector_in(S01_AXI_wvalid);
  mp_S01_AXI_wvalid_converter->scalar_out(m_S01_AXI_wvalid_converter_signal);
  mp_S01_AXI_transactor->WVALID(m_S01_AXI_wvalid_converter_signal);
  mp_S01_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_wready_converter");
  mp_S01_AXI_wready_converter->scalar_in(m_S01_AXI_wready_converter_signal);
  mp_S01_AXI_wready_converter->vector_out(S01_AXI_wready);
  mp_S01_AXI_transactor->WREADY(m_S01_AXI_wready_converter_signal);
  mp_S01_AXI_transactor->BRESP(S01_AXI_bresp);
  mp_S01_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_bvalid_converter");
  mp_S01_AXI_bvalid_converter->scalar_in(m_S01_AXI_bvalid_converter_signal);
  mp_S01_AXI_bvalid_converter->vector_out(S01_AXI_bvalid);
  mp_S01_AXI_transactor->BVALID(m_S01_AXI_bvalid_converter_signal);
  mp_S01_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_bready_converter");
  mp_S01_AXI_bready_converter->vector_in(S01_AXI_bready);
  mp_S01_AXI_bready_converter->scalar_out(m_S01_AXI_bready_converter_signal);
  mp_S01_AXI_transactor->BREADY(m_S01_AXI_bready_converter_signal);
  mp_S01_AXI_transactor->ARADDR(S01_AXI_araddr);
  mp_S01_AXI_transactor->ARLEN(S01_AXI_arlen);
  mp_S01_AXI_transactor->ARSIZE(S01_AXI_arsize);
  mp_S01_AXI_transactor->ARBURST(S01_AXI_arburst);
  mp_S01_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arlock_converter");
  mp_S01_AXI_arlock_converter->vector_in(S01_AXI_arlock);
  mp_S01_AXI_arlock_converter->scalar_out(m_S01_AXI_arlock_converter_signal);
  mp_S01_AXI_transactor->ARLOCK(m_S01_AXI_arlock_converter_signal);
  mp_S01_AXI_transactor->ARCACHE(S01_AXI_arcache);
  mp_S01_AXI_transactor->ARPROT(S01_AXI_arprot);
  mp_S01_AXI_transactor->ARREGION(S01_AXI_arregion);
  mp_S01_AXI_transactor->ARQOS(S01_AXI_arqos);
  mp_S01_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_arvalid_converter");
  mp_S01_AXI_arvalid_converter->vector_in(S01_AXI_arvalid);
  mp_S01_AXI_arvalid_converter->scalar_out(m_S01_AXI_arvalid_converter_signal);
  mp_S01_AXI_transactor->ARVALID(m_S01_AXI_arvalid_converter_signal);
  mp_S01_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_arready_converter");
  mp_S01_AXI_arready_converter->scalar_in(m_S01_AXI_arready_converter_signal);
  mp_S01_AXI_arready_converter->vector_out(S01_AXI_arready);
  mp_S01_AXI_transactor->ARREADY(m_S01_AXI_arready_converter_signal);
  mp_S01_AXI_transactor->RDATA(S01_AXI_rdata);
  mp_S01_AXI_transactor->RRESP(S01_AXI_rresp);
  mp_S01_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rlast_converter");
  mp_S01_AXI_rlast_converter->scalar_in(m_S01_AXI_rlast_converter_signal);
  mp_S01_AXI_rlast_converter->vector_out(S01_AXI_rlast);
  mp_S01_AXI_transactor->RLAST(m_S01_AXI_rlast_converter_signal);
  mp_S01_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S01_AXI_rvalid_converter");
  mp_S01_AXI_rvalid_converter->scalar_in(m_S01_AXI_rvalid_converter_signal);
  mp_S01_AXI_rvalid_converter->vector_out(S01_AXI_rvalid);
  mp_S01_AXI_transactor->RVALID(m_S01_AXI_rvalid_converter_signal);
  mp_S01_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S01_AXI_rready_converter");
  mp_S01_AXI_rready_converter->vector_in(S01_AXI_rready);
  mp_S01_AXI_rready_converter->scalar_out(m_S01_AXI_rready_converter_signal);
  mp_S01_AXI_transactor->RREADY(m_S01_AXI_rready_converter_signal);
  mp_S01_AXI_transactor->ARID(S01_AXI_arid);
  mp_S01_AXI_transactor->ARUSER(S01_AXI_aruser);
  mp_S01_AXI_transactor->AWID(S01_AXI_awid);
  mp_S01_AXI_transactor->AWUSER(S01_AXI_awuser);
  mp_S01_AXI_transactor->BID(S01_AXI_bid);
  mp_S01_AXI_transactor->RID(S01_AXI_rid);
  mp_S01_AXI_transactor->RUSER(S01_AXI_ruser);
  mp_S01_AXI_transactor->WUSER(S01_AXI_wuser);
  mp_S01_AXI_transactor->CLK(aclk1);
  m_S01_AXI_transactor_rst_signal.write(1);
  mp_S01_AXI_transactor->RST(m_S01_AXI_transactor_rst_signal);
  // configure S02_AXI_transactor
    xsc::common_cpp::properties S02_AXI_transactor_param_props;
    S02_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S02_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S02_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S02_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S02_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S02_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S02_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S02_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S02_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S02_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S02_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S02_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S02_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S02_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S02_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S02_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S02_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S02_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S02_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S02_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S02_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S02_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S02_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S02_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi2_clk");
    S02_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S02_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S02_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S02_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S02_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S02_AXI_transactor_param_props.addString("REGION", "0");
    S02_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S02_AXI_transactor_param_props.addString("DEST_IDS", "");
    S02_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S02_AXI_transactor_param_props.addString("REMAPS", "");
    S02_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S02_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S02_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S02_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S02_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S02_AXI_transactor", S02_AXI_transactor_param_props);
  mp_S02_AXI_transactor->AWADDR(S02_AXI_awaddr);
  mp_S02_AXI_transactor->AWLEN(S02_AXI_awlen);
  mp_S02_AXI_transactor->AWSIZE(S02_AXI_awsize);
  mp_S02_AXI_transactor->AWBURST(S02_AXI_awburst);
  mp_S02_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awlock_converter");
  mp_S02_AXI_awlock_converter->vector_in(S02_AXI_awlock);
  mp_S02_AXI_awlock_converter->scalar_out(m_S02_AXI_awlock_converter_signal);
  mp_S02_AXI_transactor->AWLOCK(m_S02_AXI_awlock_converter_signal);
  mp_S02_AXI_transactor->AWCACHE(S02_AXI_awcache);
  mp_S02_AXI_transactor->AWPROT(S02_AXI_awprot);
  mp_S02_AXI_transactor->AWREGION(S02_AXI_awregion);
  mp_S02_AXI_transactor->AWQOS(S02_AXI_awqos);
  mp_S02_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_awvalid_converter");
  mp_S02_AXI_awvalid_converter->vector_in(S02_AXI_awvalid);
  mp_S02_AXI_awvalid_converter->scalar_out(m_S02_AXI_awvalid_converter_signal);
  mp_S02_AXI_transactor->AWVALID(m_S02_AXI_awvalid_converter_signal);
  mp_S02_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_awready_converter");
  mp_S02_AXI_awready_converter->scalar_in(m_S02_AXI_awready_converter_signal);
  mp_S02_AXI_awready_converter->vector_out(S02_AXI_awready);
  mp_S02_AXI_transactor->AWREADY(m_S02_AXI_awready_converter_signal);
  mp_S02_AXI_transactor->WDATA(S02_AXI_wdata);
  mp_S02_AXI_transactor->WSTRB(S02_AXI_wstrb);
  mp_S02_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wlast_converter");
  mp_S02_AXI_wlast_converter->vector_in(S02_AXI_wlast);
  mp_S02_AXI_wlast_converter->scalar_out(m_S02_AXI_wlast_converter_signal);
  mp_S02_AXI_transactor->WLAST(m_S02_AXI_wlast_converter_signal);
  mp_S02_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_wvalid_converter");
  mp_S02_AXI_wvalid_converter->vector_in(S02_AXI_wvalid);
  mp_S02_AXI_wvalid_converter->scalar_out(m_S02_AXI_wvalid_converter_signal);
  mp_S02_AXI_transactor->WVALID(m_S02_AXI_wvalid_converter_signal);
  mp_S02_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_wready_converter");
  mp_S02_AXI_wready_converter->scalar_in(m_S02_AXI_wready_converter_signal);
  mp_S02_AXI_wready_converter->vector_out(S02_AXI_wready);
  mp_S02_AXI_transactor->WREADY(m_S02_AXI_wready_converter_signal);
  mp_S02_AXI_transactor->BRESP(S02_AXI_bresp);
  mp_S02_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_bvalid_converter");
  mp_S02_AXI_bvalid_converter->scalar_in(m_S02_AXI_bvalid_converter_signal);
  mp_S02_AXI_bvalid_converter->vector_out(S02_AXI_bvalid);
  mp_S02_AXI_transactor->BVALID(m_S02_AXI_bvalid_converter_signal);
  mp_S02_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_bready_converter");
  mp_S02_AXI_bready_converter->vector_in(S02_AXI_bready);
  mp_S02_AXI_bready_converter->scalar_out(m_S02_AXI_bready_converter_signal);
  mp_S02_AXI_transactor->BREADY(m_S02_AXI_bready_converter_signal);
  mp_S02_AXI_transactor->ARADDR(S02_AXI_araddr);
  mp_S02_AXI_transactor->ARLEN(S02_AXI_arlen);
  mp_S02_AXI_transactor->ARSIZE(S02_AXI_arsize);
  mp_S02_AXI_transactor->ARBURST(S02_AXI_arburst);
  mp_S02_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arlock_converter");
  mp_S02_AXI_arlock_converter->vector_in(S02_AXI_arlock);
  mp_S02_AXI_arlock_converter->scalar_out(m_S02_AXI_arlock_converter_signal);
  mp_S02_AXI_transactor->ARLOCK(m_S02_AXI_arlock_converter_signal);
  mp_S02_AXI_transactor->ARCACHE(S02_AXI_arcache);
  mp_S02_AXI_transactor->ARPROT(S02_AXI_arprot);
  mp_S02_AXI_transactor->ARREGION(S02_AXI_arregion);
  mp_S02_AXI_transactor->ARQOS(S02_AXI_arqos);
  mp_S02_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_arvalid_converter");
  mp_S02_AXI_arvalid_converter->vector_in(S02_AXI_arvalid);
  mp_S02_AXI_arvalid_converter->scalar_out(m_S02_AXI_arvalid_converter_signal);
  mp_S02_AXI_transactor->ARVALID(m_S02_AXI_arvalid_converter_signal);
  mp_S02_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_arready_converter");
  mp_S02_AXI_arready_converter->scalar_in(m_S02_AXI_arready_converter_signal);
  mp_S02_AXI_arready_converter->vector_out(S02_AXI_arready);
  mp_S02_AXI_transactor->ARREADY(m_S02_AXI_arready_converter_signal);
  mp_S02_AXI_transactor->RDATA(S02_AXI_rdata);
  mp_S02_AXI_transactor->RRESP(S02_AXI_rresp);
  mp_S02_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rlast_converter");
  mp_S02_AXI_rlast_converter->scalar_in(m_S02_AXI_rlast_converter_signal);
  mp_S02_AXI_rlast_converter->vector_out(S02_AXI_rlast);
  mp_S02_AXI_transactor->RLAST(m_S02_AXI_rlast_converter_signal);
  mp_S02_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S02_AXI_rvalid_converter");
  mp_S02_AXI_rvalid_converter->scalar_in(m_S02_AXI_rvalid_converter_signal);
  mp_S02_AXI_rvalid_converter->vector_out(S02_AXI_rvalid);
  mp_S02_AXI_transactor->RVALID(m_S02_AXI_rvalid_converter_signal);
  mp_S02_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S02_AXI_rready_converter");
  mp_S02_AXI_rready_converter->vector_in(S02_AXI_rready);
  mp_S02_AXI_rready_converter->scalar_out(m_S02_AXI_rready_converter_signal);
  mp_S02_AXI_transactor->RREADY(m_S02_AXI_rready_converter_signal);
  mp_S02_AXI_transactor->ARID(S02_AXI_arid);
  mp_S02_AXI_transactor->ARUSER(S02_AXI_aruser);
  mp_S02_AXI_transactor->AWID(S02_AXI_awid);
  mp_S02_AXI_transactor->AWUSER(S02_AXI_awuser);
  mp_S02_AXI_transactor->BID(S02_AXI_bid);
  mp_S02_AXI_transactor->RID(S02_AXI_rid);
  mp_S02_AXI_transactor->RUSER(S02_AXI_ruser);
  mp_S02_AXI_transactor->WUSER(S02_AXI_wuser);
  mp_S02_AXI_transactor->CLK(aclk2);
  m_S02_AXI_transactor_rst_signal.write(1);
  mp_S02_AXI_transactor->RST(m_S02_AXI_transactor_rst_signal);
  // configure S03_AXI_transactor
    xsc::common_cpp::properties S03_AXI_transactor_param_props;
    S03_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S03_AXI_transactor_param_props.addLong("FREQ_HZ", "550000000");
    S03_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S03_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S03_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S03_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S03_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S03_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S03_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S03_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S03_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S03_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S03_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S03_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S03_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S03_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S03_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S03_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S03_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S03_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S03_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S03_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S03_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S03_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_fpd_cci_noc_axi3_clk");
    S03_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S03_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S03_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S03_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S03_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S03_AXI_transactor_param_props.addString("REGION", "0");
    S03_AXI_transactor_param_props.addString("CONNECTIONS", "MC_1 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S03_AXI_transactor_param_props.addString("DEST_IDS", "");
    S03_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S03_AXI_transactor_param_props.addString("REMAPS", "");
    S03_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S03_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S03_AXI_transactor_param_props.addString("CATEGORY", "ps_cci");
    S03_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S03_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S03_AXI_transactor", S03_AXI_transactor_param_props);
  mp_S03_AXI_transactor->AWADDR(S03_AXI_awaddr);
  mp_S03_AXI_transactor->AWLEN(S03_AXI_awlen);
  mp_S03_AXI_transactor->AWSIZE(S03_AXI_awsize);
  mp_S03_AXI_transactor->AWBURST(S03_AXI_awburst);
  mp_S03_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awlock_converter");
  mp_S03_AXI_awlock_converter->vector_in(S03_AXI_awlock);
  mp_S03_AXI_awlock_converter->scalar_out(m_S03_AXI_awlock_converter_signal);
  mp_S03_AXI_transactor->AWLOCK(m_S03_AXI_awlock_converter_signal);
  mp_S03_AXI_transactor->AWCACHE(S03_AXI_awcache);
  mp_S03_AXI_transactor->AWPROT(S03_AXI_awprot);
  mp_S03_AXI_transactor->AWREGION(S03_AXI_awregion);
  mp_S03_AXI_transactor->AWQOS(S03_AXI_awqos);
  mp_S03_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_awvalid_converter");
  mp_S03_AXI_awvalid_converter->vector_in(S03_AXI_awvalid);
  mp_S03_AXI_awvalid_converter->scalar_out(m_S03_AXI_awvalid_converter_signal);
  mp_S03_AXI_transactor->AWVALID(m_S03_AXI_awvalid_converter_signal);
  mp_S03_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_awready_converter");
  mp_S03_AXI_awready_converter->scalar_in(m_S03_AXI_awready_converter_signal);
  mp_S03_AXI_awready_converter->vector_out(S03_AXI_awready);
  mp_S03_AXI_transactor->AWREADY(m_S03_AXI_awready_converter_signal);
  mp_S03_AXI_transactor->WDATA(S03_AXI_wdata);
  mp_S03_AXI_transactor->WSTRB(S03_AXI_wstrb);
  mp_S03_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wlast_converter");
  mp_S03_AXI_wlast_converter->vector_in(S03_AXI_wlast);
  mp_S03_AXI_wlast_converter->scalar_out(m_S03_AXI_wlast_converter_signal);
  mp_S03_AXI_transactor->WLAST(m_S03_AXI_wlast_converter_signal);
  mp_S03_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_wvalid_converter");
  mp_S03_AXI_wvalid_converter->vector_in(S03_AXI_wvalid);
  mp_S03_AXI_wvalid_converter->scalar_out(m_S03_AXI_wvalid_converter_signal);
  mp_S03_AXI_transactor->WVALID(m_S03_AXI_wvalid_converter_signal);
  mp_S03_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_wready_converter");
  mp_S03_AXI_wready_converter->scalar_in(m_S03_AXI_wready_converter_signal);
  mp_S03_AXI_wready_converter->vector_out(S03_AXI_wready);
  mp_S03_AXI_transactor->WREADY(m_S03_AXI_wready_converter_signal);
  mp_S03_AXI_transactor->BRESP(S03_AXI_bresp);
  mp_S03_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_bvalid_converter");
  mp_S03_AXI_bvalid_converter->scalar_in(m_S03_AXI_bvalid_converter_signal);
  mp_S03_AXI_bvalid_converter->vector_out(S03_AXI_bvalid);
  mp_S03_AXI_transactor->BVALID(m_S03_AXI_bvalid_converter_signal);
  mp_S03_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_bready_converter");
  mp_S03_AXI_bready_converter->vector_in(S03_AXI_bready);
  mp_S03_AXI_bready_converter->scalar_out(m_S03_AXI_bready_converter_signal);
  mp_S03_AXI_transactor->BREADY(m_S03_AXI_bready_converter_signal);
  mp_S03_AXI_transactor->ARADDR(S03_AXI_araddr);
  mp_S03_AXI_transactor->ARLEN(S03_AXI_arlen);
  mp_S03_AXI_transactor->ARSIZE(S03_AXI_arsize);
  mp_S03_AXI_transactor->ARBURST(S03_AXI_arburst);
  mp_S03_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arlock_converter");
  mp_S03_AXI_arlock_converter->vector_in(S03_AXI_arlock);
  mp_S03_AXI_arlock_converter->scalar_out(m_S03_AXI_arlock_converter_signal);
  mp_S03_AXI_transactor->ARLOCK(m_S03_AXI_arlock_converter_signal);
  mp_S03_AXI_transactor->ARCACHE(S03_AXI_arcache);
  mp_S03_AXI_transactor->ARPROT(S03_AXI_arprot);
  mp_S03_AXI_transactor->ARREGION(S03_AXI_arregion);
  mp_S03_AXI_transactor->ARQOS(S03_AXI_arqos);
  mp_S03_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_arvalid_converter");
  mp_S03_AXI_arvalid_converter->vector_in(S03_AXI_arvalid);
  mp_S03_AXI_arvalid_converter->scalar_out(m_S03_AXI_arvalid_converter_signal);
  mp_S03_AXI_transactor->ARVALID(m_S03_AXI_arvalid_converter_signal);
  mp_S03_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_arready_converter");
  mp_S03_AXI_arready_converter->scalar_in(m_S03_AXI_arready_converter_signal);
  mp_S03_AXI_arready_converter->vector_out(S03_AXI_arready);
  mp_S03_AXI_transactor->ARREADY(m_S03_AXI_arready_converter_signal);
  mp_S03_AXI_transactor->RDATA(S03_AXI_rdata);
  mp_S03_AXI_transactor->RRESP(S03_AXI_rresp);
  mp_S03_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rlast_converter");
  mp_S03_AXI_rlast_converter->scalar_in(m_S03_AXI_rlast_converter_signal);
  mp_S03_AXI_rlast_converter->vector_out(S03_AXI_rlast);
  mp_S03_AXI_transactor->RLAST(m_S03_AXI_rlast_converter_signal);
  mp_S03_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S03_AXI_rvalid_converter");
  mp_S03_AXI_rvalid_converter->scalar_in(m_S03_AXI_rvalid_converter_signal);
  mp_S03_AXI_rvalid_converter->vector_out(S03_AXI_rvalid);
  mp_S03_AXI_transactor->RVALID(m_S03_AXI_rvalid_converter_signal);
  mp_S03_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S03_AXI_rready_converter");
  mp_S03_AXI_rready_converter->vector_in(S03_AXI_rready);
  mp_S03_AXI_rready_converter->scalar_out(m_S03_AXI_rready_converter_signal);
  mp_S03_AXI_transactor->RREADY(m_S03_AXI_rready_converter_signal);
  mp_S03_AXI_transactor->ARID(S03_AXI_arid);
  mp_S03_AXI_transactor->ARUSER(S03_AXI_aruser);
  mp_S03_AXI_transactor->AWID(S03_AXI_awid);
  mp_S03_AXI_transactor->AWUSER(S03_AXI_awuser);
  mp_S03_AXI_transactor->BID(S03_AXI_bid);
  mp_S03_AXI_transactor->RID(S03_AXI_rid);
  mp_S03_AXI_transactor->RUSER(S03_AXI_ruser);
  mp_S03_AXI_transactor->WUSER(S03_AXI_wuser);
  mp_S03_AXI_transactor->CLK(aclk3);
  m_S03_AXI_transactor_rst_signal.write(1);
  mp_S03_AXI_transactor->RST(m_S03_AXI_transactor_rst_signal);
  // configure S04_AXI_transactor
    xsc::common_cpp::properties S04_AXI_transactor_param_props;
    S04_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S04_AXI_transactor_param_props.addLong("FREQ_HZ", "400000000");
    S04_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S04_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S04_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S04_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S04_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S04_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S04_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S04_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S04_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S04_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S04_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S04_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S04_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S04_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S04_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S04_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S04_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S04_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S04_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S04_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S04_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S04_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_lpd_axi_noc_clk");
    S04_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S04_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S04_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S04_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S04_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S04_AXI_transactor_param_props.addString("REGION", "0");
    S04_AXI_transactor_param_props.addString("CONNECTIONS", "MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S04_AXI_transactor_param_props.addString("DEST_IDS", "");
    S04_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S04_AXI_transactor_param_props.addString("REMAPS", "");
    S04_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S04_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S04_AXI_transactor_param_props.addString("CATEGORY", "ps_rpu");
    S04_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S04_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,1,18,17>("S04_AXI_transactor", S04_AXI_transactor_param_props);
  mp_S04_AXI_transactor->AWADDR(S04_AXI_awaddr);
  mp_S04_AXI_transactor->AWLEN(S04_AXI_awlen);
  mp_S04_AXI_transactor->AWSIZE(S04_AXI_awsize);
  mp_S04_AXI_transactor->AWBURST(S04_AXI_awburst);
  mp_S04_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awlock_converter");
  mp_S04_AXI_awlock_converter->vector_in(S04_AXI_awlock);
  mp_S04_AXI_awlock_converter->scalar_out(m_S04_AXI_awlock_converter_signal);
  mp_S04_AXI_transactor->AWLOCK(m_S04_AXI_awlock_converter_signal);
  mp_S04_AXI_transactor->AWCACHE(S04_AXI_awcache);
  mp_S04_AXI_transactor->AWPROT(S04_AXI_awprot);
  mp_S04_AXI_transactor->AWREGION(S04_AXI_awregion);
  mp_S04_AXI_transactor->AWQOS(S04_AXI_awqos);
  mp_S04_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_awvalid_converter");
  mp_S04_AXI_awvalid_converter->vector_in(S04_AXI_awvalid);
  mp_S04_AXI_awvalid_converter->scalar_out(m_S04_AXI_awvalid_converter_signal);
  mp_S04_AXI_transactor->AWVALID(m_S04_AXI_awvalid_converter_signal);
  mp_S04_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_awready_converter");
  mp_S04_AXI_awready_converter->scalar_in(m_S04_AXI_awready_converter_signal);
  mp_S04_AXI_awready_converter->vector_out(S04_AXI_awready);
  mp_S04_AXI_transactor->AWREADY(m_S04_AXI_awready_converter_signal);
  mp_S04_AXI_transactor->WDATA(S04_AXI_wdata);
  mp_S04_AXI_transactor->WSTRB(S04_AXI_wstrb);
  mp_S04_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wlast_converter");
  mp_S04_AXI_wlast_converter->vector_in(S04_AXI_wlast);
  mp_S04_AXI_wlast_converter->scalar_out(m_S04_AXI_wlast_converter_signal);
  mp_S04_AXI_transactor->WLAST(m_S04_AXI_wlast_converter_signal);
  mp_S04_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_wvalid_converter");
  mp_S04_AXI_wvalid_converter->vector_in(S04_AXI_wvalid);
  mp_S04_AXI_wvalid_converter->scalar_out(m_S04_AXI_wvalid_converter_signal);
  mp_S04_AXI_transactor->WVALID(m_S04_AXI_wvalid_converter_signal);
  mp_S04_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_wready_converter");
  mp_S04_AXI_wready_converter->scalar_in(m_S04_AXI_wready_converter_signal);
  mp_S04_AXI_wready_converter->vector_out(S04_AXI_wready);
  mp_S04_AXI_transactor->WREADY(m_S04_AXI_wready_converter_signal);
  mp_S04_AXI_transactor->BRESP(S04_AXI_bresp);
  mp_S04_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_bvalid_converter");
  mp_S04_AXI_bvalid_converter->scalar_in(m_S04_AXI_bvalid_converter_signal);
  mp_S04_AXI_bvalid_converter->vector_out(S04_AXI_bvalid);
  mp_S04_AXI_transactor->BVALID(m_S04_AXI_bvalid_converter_signal);
  mp_S04_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_bready_converter");
  mp_S04_AXI_bready_converter->vector_in(S04_AXI_bready);
  mp_S04_AXI_bready_converter->scalar_out(m_S04_AXI_bready_converter_signal);
  mp_S04_AXI_transactor->BREADY(m_S04_AXI_bready_converter_signal);
  mp_S04_AXI_transactor->ARADDR(S04_AXI_araddr);
  mp_S04_AXI_transactor->ARLEN(S04_AXI_arlen);
  mp_S04_AXI_transactor->ARSIZE(S04_AXI_arsize);
  mp_S04_AXI_transactor->ARBURST(S04_AXI_arburst);
  mp_S04_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arlock_converter");
  mp_S04_AXI_arlock_converter->vector_in(S04_AXI_arlock);
  mp_S04_AXI_arlock_converter->scalar_out(m_S04_AXI_arlock_converter_signal);
  mp_S04_AXI_transactor->ARLOCK(m_S04_AXI_arlock_converter_signal);
  mp_S04_AXI_transactor->ARCACHE(S04_AXI_arcache);
  mp_S04_AXI_transactor->ARPROT(S04_AXI_arprot);
  mp_S04_AXI_transactor->ARREGION(S04_AXI_arregion);
  mp_S04_AXI_transactor->ARQOS(S04_AXI_arqos);
  mp_S04_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_arvalid_converter");
  mp_S04_AXI_arvalid_converter->vector_in(S04_AXI_arvalid);
  mp_S04_AXI_arvalid_converter->scalar_out(m_S04_AXI_arvalid_converter_signal);
  mp_S04_AXI_transactor->ARVALID(m_S04_AXI_arvalid_converter_signal);
  mp_S04_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_arready_converter");
  mp_S04_AXI_arready_converter->scalar_in(m_S04_AXI_arready_converter_signal);
  mp_S04_AXI_arready_converter->vector_out(S04_AXI_arready);
  mp_S04_AXI_transactor->ARREADY(m_S04_AXI_arready_converter_signal);
  mp_S04_AXI_transactor->RDATA(S04_AXI_rdata);
  mp_S04_AXI_transactor->RRESP(S04_AXI_rresp);
  mp_S04_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rlast_converter");
  mp_S04_AXI_rlast_converter->scalar_in(m_S04_AXI_rlast_converter_signal);
  mp_S04_AXI_rlast_converter->vector_out(S04_AXI_rlast);
  mp_S04_AXI_transactor->RLAST(m_S04_AXI_rlast_converter_signal);
  mp_S04_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S04_AXI_rvalid_converter");
  mp_S04_AXI_rvalid_converter->scalar_in(m_S04_AXI_rvalid_converter_signal);
  mp_S04_AXI_rvalid_converter->vector_out(S04_AXI_rvalid);
  mp_S04_AXI_transactor->RVALID(m_S04_AXI_rvalid_converter_signal);
  mp_S04_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S04_AXI_rready_converter");
  mp_S04_AXI_rready_converter->vector_in(S04_AXI_rready);
  mp_S04_AXI_rready_converter->scalar_out(m_S04_AXI_rready_converter_signal);
  mp_S04_AXI_transactor->RREADY(m_S04_AXI_rready_converter_signal);
  mp_S04_AXI_transactor->ARID(S04_AXI_arid);
  mp_S04_AXI_transactor->ARUSER(S04_AXI_aruser);
  mp_S04_AXI_transactor->AWID(S04_AXI_awid);
  mp_S04_AXI_transactor->AWUSER(S04_AXI_awuser);
  mp_S04_AXI_transactor->BID(S04_AXI_bid);
  mp_S04_AXI_transactor->RID(S04_AXI_rid);
  mp_S04_AXI_transactor->RUSER(S04_AXI_ruser);
  mp_S04_AXI_transactor->WUSER(S04_AXI_wuser);
  mp_S04_AXI_transactor->CLK(aclk4);
  m_S04_AXI_transactor_rst_signal.write(1);
  mp_S04_AXI_transactor->RST(m_S04_AXI_transactor_rst_signal);
  // configure S05_AXI_transactor
    xsc::common_cpp::properties S05_AXI_transactor_param_props;
    S05_AXI_transactor_param_props.addLong("DATA_WIDTH", "128");
    S05_AXI_transactor_param_props.addLong("FREQ_HZ", "320000000");
    S05_AXI_transactor_param_props.addLong("ID_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S05_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "18");
    S05_AXI_transactor_param_props.addLong("WUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("RUSER_WIDTH", "17");
    S05_AXI_transactor_param_props.addLong("BUSER_WIDTH", "16");
    S05_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S05_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S05_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S05_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S05_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S05_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S05_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S05_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S05_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "64");
    S05_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S05_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S05_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S05_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S05_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S05_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S05_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S05_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pmc_axi_noc_axi0_clk");
    S05_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S05_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S05_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S05_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S05_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S05_AXI_transactor_param_props.addString("REGION", "0");
    S05_AXI_transactor_param_props.addString("CONNECTIONS", "MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4} initial_boot {true} }");
    S05_AXI_transactor_param_props.addString("DEST_IDS", "");
    S05_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S05_AXI_transactor_param_props.addString("REMAPS", "");
    S05_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S05_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S05_AXI_transactor_param_props.addString("CATEGORY", "ps_pmc");
    S05_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S05_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<128,64,16,18,17,16,18,17>("S05_AXI_transactor", S05_AXI_transactor_param_props);
  mp_S05_AXI_transactor->AWADDR(S05_AXI_awaddr);
  mp_S05_AXI_transactor->AWLEN(S05_AXI_awlen);
  mp_S05_AXI_transactor->AWSIZE(S05_AXI_awsize);
  mp_S05_AXI_transactor->AWBURST(S05_AXI_awburst);
  mp_S05_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awlock_converter");
  mp_S05_AXI_awlock_converter->vector_in(S05_AXI_awlock);
  mp_S05_AXI_awlock_converter->scalar_out(m_S05_AXI_awlock_converter_signal);
  mp_S05_AXI_transactor->AWLOCK(m_S05_AXI_awlock_converter_signal);
  mp_S05_AXI_transactor->AWCACHE(S05_AXI_awcache);
  mp_S05_AXI_transactor->AWPROT(S05_AXI_awprot);
  mp_S05_AXI_transactor->AWREGION(S05_AXI_awregion);
  mp_S05_AXI_transactor->AWQOS(S05_AXI_awqos);
  mp_S05_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_awvalid_converter");
  mp_S05_AXI_awvalid_converter->vector_in(S05_AXI_awvalid);
  mp_S05_AXI_awvalid_converter->scalar_out(m_S05_AXI_awvalid_converter_signal);
  mp_S05_AXI_transactor->AWVALID(m_S05_AXI_awvalid_converter_signal);
  mp_S05_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_awready_converter");
  mp_S05_AXI_awready_converter->scalar_in(m_S05_AXI_awready_converter_signal);
  mp_S05_AXI_awready_converter->vector_out(S05_AXI_awready);
  mp_S05_AXI_transactor->AWREADY(m_S05_AXI_awready_converter_signal);
  mp_S05_AXI_transactor->WDATA(S05_AXI_wdata);
  mp_S05_AXI_transactor->WSTRB(S05_AXI_wstrb);
  mp_S05_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wlast_converter");
  mp_S05_AXI_wlast_converter->vector_in(S05_AXI_wlast);
  mp_S05_AXI_wlast_converter->scalar_out(m_S05_AXI_wlast_converter_signal);
  mp_S05_AXI_transactor->WLAST(m_S05_AXI_wlast_converter_signal);
  mp_S05_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_wvalid_converter");
  mp_S05_AXI_wvalid_converter->vector_in(S05_AXI_wvalid);
  mp_S05_AXI_wvalid_converter->scalar_out(m_S05_AXI_wvalid_converter_signal);
  mp_S05_AXI_transactor->WVALID(m_S05_AXI_wvalid_converter_signal);
  mp_S05_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_wready_converter");
  mp_S05_AXI_wready_converter->scalar_in(m_S05_AXI_wready_converter_signal);
  mp_S05_AXI_wready_converter->vector_out(S05_AXI_wready);
  mp_S05_AXI_transactor->WREADY(m_S05_AXI_wready_converter_signal);
  mp_S05_AXI_transactor->BRESP(S05_AXI_bresp);
  mp_S05_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_bvalid_converter");
  mp_S05_AXI_bvalid_converter->scalar_in(m_S05_AXI_bvalid_converter_signal);
  mp_S05_AXI_bvalid_converter->vector_out(S05_AXI_bvalid);
  mp_S05_AXI_transactor->BVALID(m_S05_AXI_bvalid_converter_signal);
  mp_S05_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_bready_converter");
  mp_S05_AXI_bready_converter->vector_in(S05_AXI_bready);
  mp_S05_AXI_bready_converter->scalar_out(m_S05_AXI_bready_converter_signal);
  mp_S05_AXI_transactor->BREADY(m_S05_AXI_bready_converter_signal);
  mp_S05_AXI_transactor->ARADDR(S05_AXI_araddr);
  mp_S05_AXI_transactor->ARLEN(S05_AXI_arlen);
  mp_S05_AXI_transactor->ARSIZE(S05_AXI_arsize);
  mp_S05_AXI_transactor->ARBURST(S05_AXI_arburst);
  mp_S05_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arlock_converter");
  mp_S05_AXI_arlock_converter->vector_in(S05_AXI_arlock);
  mp_S05_AXI_arlock_converter->scalar_out(m_S05_AXI_arlock_converter_signal);
  mp_S05_AXI_transactor->ARLOCK(m_S05_AXI_arlock_converter_signal);
  mp_S05_AXI_transactor->ARCACHE(S05_AXI_arcache);
  mp_S05_AXI_transactor->ARPROT(S05_AXI_arprot);
  mp_S05_AXI_transactor->ARREGION(S05_AXI_arregion);
  mp_S05_AXI_transactor->ARQOS(S05_AXI_arqos);
  mp_S05_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_arvalid_converter");
  mp_S05_AXI_arvalid_converter->vector_in(S05_AXI_arvalid);
  mp_S05_AXI_arvalid_converter->scalar_out(m_S05_AXI_arvalid_converter_signal);
  mp_S05_AXI_transactor->ARVALID(m_S05_AXI_arvalid_converter_signal);
  mp_S05_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_arready_converter");
  mp_S05_AXI_arready_converter->scalar_in(m_S05_AXI_arready_converter_signal);
  mp_S05_AXI_arready_converter->vector_out(S05_AXI_arready);
  mp_S05_AXI_transactor->ARREADY(m_S05_AXI_arready_converter_signal);
  mp_S05_AXI_transactor->RDATA(S05_AXI_rdata);
  mp_S05_AXI_transactor->RRESP(S05_AXI_rresp);
  mp_S05_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rlast_converter");
  mp_S05_AXI_rlast_converter->scalar_in(m_S05_AXI_rlast_converter_signal);
  mp_S05_AXI_rlast_converter->vector_out(S05_AXI_rlast);
  mp_S05_AXI_transactor->RLAST(m_S05_AXI_rlast_converter_signal);
  mp_S05_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S05_AXI_rvalid_converter");
  mp_S05_AXI_rvalid_converter->scalar_in(m_S05_AXI_rvalid_converter_signal);
  mp_S05_AXI_rvalid_converter->vector_out(S05_AXI_rvalid);
  mp_S05_AXI_transactor->RVALID(m_S05_AXI_rvalid_converter_signal);
  mp_S05_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S05_AXI_rready_converter");
  mp_S05_AXI_rready_converter->vector_in(S05_AXI_rready);
  mp_S05_AXI_rready_converter->scalar_out(m_S05_AXI_rready_converter_signal);
  mp_S05_AXI_transactor->RREADY(m_S05_AXI_rready_converter_signal);
  mp_S05_AXI_transactor->ARID(S05_AXI_arid);
  mp_S05_AXI_transactor->ARUSER(S05_AXI_aruser);
  mp_S05_AXI_transactor->AWID(S05_AXI_awid);
  mp_S05_AXI_transactor->AWUSER(S05_AXI_awuser);
  mp_S05_AXI_transactor->BID(S05_AXI_bid);
  mp_S05_AXI_transactor->BUSER(S05_AXI_buser);
  mp_S05_AXI_transactor->RID(S05_AXI_rid);
  mp_S05_AXI_transactor->RUSER(S05_AXI_ruser);
  mp_S05_AXI_transactor->WUSER(S05_AXI_wuser);
  mp_S05_AXI_transactor->CLK(aclk5);
  m_S05_AXI_transactor_rst_signal.write(1);
  mp_S05_AXI_transactor->RST(m_S05_AXI_transactor_rst_signal);
  // configure S06_AXI_transactor
    xsc::common_cpp::properties S06_AXI_transactor_param_props;
    S06_AXI_transactor_param_props.addLong("DATA_WIDTH", "32");
    S06_AXI_transactor_param_props.addLong("FREQ_HZ", "100000000");
    S06_AXI_transactor_param_props.addLong("ID_WIDTH", "1");
    S06_AXI_transactor_param_props.addLong("ADDR_WIDTH", "64");
    S06_AXI_transactor_param_props.addLong("AWUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("ARUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("RUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("BUSER_WIDTH", "0");
    S06_AXI_transactor_param_props.addLong("HAS_BURST", "1");
    S06_AXI_transactor_param_props.addLong("HAS_LOCK", "1");
    S06_AXI_transactor_param_props.addLong("HAS_PROT", "1");
    S06_AXI_transactor_param_props.addLong("HAS_CACHE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_QOS", "1");
    S06_AXI_transactor_param_props.addLong("HAS_REGION", "1");
    S06_AXI_transactor_param_props.addLong("HAS_WSTRB", "1");
    S06_AXI_transactor_param_props.addLong("HAS_BRESP", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RRESP", "1");
    S06_AXI_transactor_param_props.addLong("SUPPORTS_NARROW_BURST", "1");
    S06_AXI_transactor_param_props.addLong("NUM_READ_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_OUTSTANDING", "2");
    S06_AXI_transactor_param_props.addLong("MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addLong("NUM_READ_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("NUM_WRITE_THREADS", "1");
    S06_AXI_transactor_param_props.addLong("RUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("WUSER_BITS_PER_BYTE", "0");
    S06_AXI_transactor_param_props.addLong("HAS_SIZE", "1");
    S06_AXI_transactor_param_props.addLong("HAS_RESET", "0");
    S06_AXI_transactor_param_props.addFloat("PHASE", "0.0");
    S06_AXI_transactor_param_props.addString("PROTOCOL", "AXI4");
    S06_AXI_transactor_param_props.addString("READ_WRITE_MODE", "READ_WRITE");
    S06_AXI_transactor_param_props.addString("CLK_DOMAIN", "bd_9435_pspmc_0_0_pl0_ref_clk");
    S06_AXI_transactor_param_props.addString("R_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("W_TRAFFIC_CLASS", "BEST_EFFORT");
    S06_AXI_transactor_param_props.addString("R_LATENCY", "300");
    S06_AXI_transactor_param_props.addString("R_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("W_RATE_LIMITER", "10");
    S06_AXI_transactor_param_props.addString("R_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("W_MAX_BURST_LENGTH", "256");
    S06_AXI_transactor_param_props.addString("PHYSICAL_LOC", "");
    S06_AXI_transactor_param_props.addString("REGION", "");
    S06_AXI_transactor_param_props.addString("CONNECTIONS", "MC_0 {read_bw {500} write_bw {500}}");
    S06_AXI_transactor_param_props.addString("DEST_IDS", "");
    S06_AXI_transactor_param_props.addString("WRITE_BUFFER_SIZE", "80");
    S06_AXI_transactor_param_props.addString("REMAPS", "");
    S06_AXI_transactor_param_props.addString("NOC_PARAMS", "");
    S06_AXI_transactor_param_props.addString("MY_CATEGORY", "noc");
    S06_AXI_transactor_param_props.addString("CATEGORY", "pl");
    S06_AXI_transactor_param_props.addString("PHYSICAL_CHANNEL", "");

    mp_S06_AXI_transactor = new xtlm::xaximm_pin2xtlm_t<32,64,1,1,1,1,1,1>("S06_AXI_transactor", S06_AXI_transactor_param_props);
  mp_S06_AXI_transactor->AWADDR(S06_AXI_awaddr);
  mp_S06_AXI_transactor->AWLEN(S06_AXI_awlen);
  mp_S06_AXI_transactor->AWSIZE(S06_AXI_awsize);
  mp_S06_AXI_transactor->AWBURST(S06_AXI_awburst);
  mp_S06_AXI_awlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awlock_converter");
  mp_S06_AXI_awlock_converter->vector_in(S06_AXI_awlock);
  mp_S06_AXI_awlock_converter->scalar_out(m_S06_AXI_awlock_converter_signal);
  mp_S06_AXI_transactor->AWLOCK(m_S06_AXI_awlock_converter_signal);
  mp_S06_AXI_transactor->AWCACHE(S06_AXI_awcache);
  mp_S06_AXI_transactor->AWPROT(S06_AXI_awprot);
  mp_S06_AXI_transactor->AWREGION(S06_AXI_awregion);
  mp_S06_AXI_transactor->AWQOS(S06_AXI_awqos);
  mp_S06_AXI_awvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_awvalid_converter");
  mp_S06_AXI_awvalid_converter->vector_in(S06_AXI_awvalid);
  mp_S06_AXI_awvalid_converter->scalar_out(m_S06_AXI_awvalid_converter_signal);
  mp_S06_AXI_transactor->AWVALID(m_S06_AXI_awvalid_converter_signal);
  mp_S06_AXI_awready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_awready_converter");
  mp_S06_AXI_awready_converter->scalar_in(m_S06_AXI_awready_converter_signal);
  mp_S06_AXI_awready_converter->vector_out(S06_AXI_awready);
  mp_S06_AXI_transactor->AWREADY(m_S06_AXI_awready_converter_signal);
  mp_S06_AXI_transactor->WDATA(S06_AXI_wdata);
  mp_S06_AXI_transactor->WSTRB(S06_AXI_wstrb);
  mp_S06_AXI_wlast_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wlast_converter");
  mp_S06_AXI_wlast_converter->vector_in(S06_AXI_wlast);
  mp_S06_AXI_wlast_converter->scalar_out(m_S06_AXI_wlast_converter_signal);
  mp_S06_AXI_transactor->WLAST(m_S06_AXI_wlast_converter_signal);
  mp_S06_AXI_wvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_wvalid_converter");
  mp_S06_AXI_wvalid_converter->vector_in(S06_AXI_wvalid);
  mp_S06_AXI_wvalid_converter->scalar_out(m_S06_AXI_wvalid_converter_signal);
  mp_S06_AXI_transactor->WVALID(m_S06_AXI_wvalid_converter_signal);
  mp_S06_AXI_wready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_wready_converter");
  mp_S06_AXI_wready_converter->scalar_in(m_S06_AXI_wready_converter_signal);
  mp_S06_AXI_wready_converter->vector_out(S06_AXI_wready);
  mp_S06_AXI_transactor->WREADY(m_S06_AXI_wready_converter_signal);
  mp_S06_AXI_transactor->BRESP(S06_AXI_bresp);
  mp_S06_AXI_bvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_bvalid_converter");
  mp_S06_AXI_bvalid_converter->scalar_in(m_S06_AXI_bvalid_converter_signal);
  mp_S06_AXI_bvalid_converter->vector_out(S06_AXI_bvalid);
  mp_S06_AXI_transactor->BVALID(m_S06_AXI_bvalid_converter_signal);
  mp_S06_AXI_bready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_bready_converter");
  mp_S06_AXI_bready_converter->vector_in(S06_AXI_bready);
  mp_S06_AXI_bready_converter->scalar_out(m_S06_AXI_bready_converter_signal);
  mp_S06_AXI_transactor->BREADY(m_S06_AXI_bready_converter_signal);
  mp_S06_AXI_transactor->ARADDR(S06_AXI_araddr);
  mp_S06_AXI_transactor->ARLEN(S06_AXI_arlen);
  mp_S06_AXI_transactor->ARSIZE(S06_AXI_arsize);
  mp_S06_AXI_transactor->ARBURST(S06_AXI_arburst);
  mp_S06_AXI_arlock_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arlock_converter");
  mp_S06_AXI_arlock_converter->vector_in(S06_AXI_arlock);
  mp_S06_AXI_arlock_converter->scalar_out(m_S06_AXI_arlock_converter_signal);
  mp_S06_AXI_transactor->ARLOCK(m_S06_AXI_arlock_converter_signal);
  mp_S06_AXI_transactor->ARCACHE(S06_AXI_arcache);
  mp_S06_AXI_transactor->ARPROT(S06_AXI_arprot);
  mp_S06_AXI_transactor->ARREGION(S06_AXI_arregion);
  mp_S06_AXI_transactor->ARQOS(S06_AXI_arqos);
  mp_S06_AXI_arvalid_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_arvalid_converter");
  mp_S06_AXI_arvalid_converter->vector_in(S06_AXI_arvalid);
  mp_S06_AXI_arvalid_converter->scalar_out(m_S06_AXI_arvalid_converter_signal);
  mp_S06_AXI_transactor->ARVALID(m_S06_AXI_arvalid_converter_signal);
  mp_S06_AXI_arready_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_arready_converter");
  mp_S06_AXI_arready_converter->scalar_in(m_S06_AXI_arready_converter_signal);
  mp_S06_AXI_arready_converter->vector_out(S06_AXI_arready);
  mp_S06_AXI_transactor->ARREADY(m_S06_AXI_arready_converter_signal);
  mp_S06_AXI_transactor->RDATA(S06_AXI_rdata);
  mp_S06_AXI_transactor->RRESP(S06_AXI_rresp);
  mp_S06_AXI_rlast_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rlast_converter");
  mp_S06_AXI_rlast_converter->scalar_in(m_S06_AXI_rlast_converter_signal);
  mp_S06_AXI_rlast_converter->vector_out(S06_AXI_rlast);
  mp_S06_AXI_transactor->RLAST(m_S06_AXI_rlast_converter_signal);
  mp_S06_AXI_rvalid_converter = new xsc::common::scalar2vectorN_converter<1>("S06_AXI_rvalid_converter");
  mp_S06_AXI_rvalid_converter->scalar_in(m_S06_AXI_rvalid_converter_signal);
  mp_S06_AXI_rvalid_converter->vector_out(S06_AXI_rvalid);
  mp_S06_AXI_transactor->RVALID(m_S06_AXI_rvalid_converter_signal);
  mp_S06_AXI_rready_converter = new xsc::common::vectorN2scalar_converter<1>("S06_AXI_rready_converter");
  mp_S06_AXI_rready_converter->vector_in(S06_AXI_rready);
  mp_S06_AXI_rready_converter->scalar_out(m_S06_AXI_rready_converter_signal);
  mp_S06_AXI_transactor->RREADY(m_S06_AXI_rready_converter_signal);
  mp_S06_AXI_transactor->ARID(S06_AXI_arid);
  mp_S06_AXI_transactor->AWID(S06_AXI_awid);
  mp_S06_AXI_transactor->BID(S06_AXI_bid);
  mp_S06_AXI_transactor->RID(S06_AXI_rid);
  mp_S06_AXI_transactor->CLK(aclk6);
  m_S06_AXI_transactor_rst_signal.write(1);
  mp_S06_AXI_transactor->RST(m_S06_AXI_transactor_rst_signal);

  // initialize transactors stubs
  S00_AXI_transactor_target_wr_socket_stub = nullptr;
  S00_AXI_transactor_target_rd_socket_stub = nullptr;
  S01_AXI_transactor_target_wr_socket_stub = nullptr;
  S01_AXI_transactor_target_rd_socket_stub = nullptr;
  S02_AXI_transactor_target_wr_socket_stub = nullptr;
  S02_AXI_transactor_target_rd_socket_stub = nullptr;
  S03_AXI_transactor_target_wr_socket_stub = nullptr;
  S03_AXI_transactor_target_rd_socket_stub = nullptr;
  S04_AXI_transactor_target_wr_socket_stub = nullptr;
  S04_AXI_transactor_target_rd_socket_stub = nullptr;
  S05_AXI_transactor_target_wr_socket_stub = nullptr;
  S05_AXI_transactor_target_rd_socket_stub = nullptr;
  S06_AXI_transactor_target_wr_socket_stub = nullptr;
  S06_AXI_transactor_target_rd_socket_stub = nullptr;

}

void bd_soc_usart_axi_noc_0_0::before_end_of_elaboration()
{
  // configure 'S00_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S00_AXI_TLM_MODE") != 1)
  {
    mp_impl->S00_AXI_tlm_aximm_read_socket->bind(*(mp_S00_AXI_transactor->rd_socket));
    mp_impl->S00_AXI_tlm_aximm_write_socket->bind(*(mp_S00_AXI_transactor->wr_socket));
  
  }
  else
  {
    S00_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S00_AXI_transactor_target_wr_socket_stub->bind(*(mp_S00_AXI_transactor->wr_socket));
    S00_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S00_AXI_transactor_target_rd_socket_stub->bind(*(mp_S00_AXI_transactor->rd_socket));
    mp_S00_AXI_transactor->disable_transactor();
  }

  // configure 'S01_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S01_AXI_TLM_MODE") != 1)
  {
    mp_impl->S01_AXI_tlm_aximm_read_socket->bind(*(mp_S01_AXI_transactor->rd_socket));
    mp_impl->S01_AXI_tlm_aximm_write_socket->bind(*(mp_S01_AXI_transactor->wr_socket));
  
  }
  else
  {
    S01_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S01_AXI_transactor_target_wr_socket_stub->bind(*(mp_S01_AXI_transactor->wr_socket));
    S01_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S01_AXI_transactor_target_rd_socket_stub->bind(*(mp_S01_AXI_transactor->rd_socket));
    mp_S01_AXI_transactor->disable_transactor();
  }

  // configure 'S02_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S02_AXI_TLM_MODE") != 1)
  {
    mp_impl->S02_AXI_tlm_aximm_read_socket->bind(*(mp_S02_AXI_transactor->rd_socket));
    mp_impl->S02_AXI_tlm_aximm_write_socket->bind(*(mp_S02_AXI_transactor->wr_socket));
  
  }
  else
  {
    S02_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S02_AXI_transactor_target_wr_socket_stub->bind(*(mp_S02_AXI_transactor->wr_socket));
    S02_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S02_AXI_transactor_target_rd_socket_stub->bind(*(mp_S02_AXI_transactor->rd_socket));
    mp_S02_AXI_transactor->disable_transactor();
  }

  // configure 'S03_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S03_AXI_TLM_MODE") != 1)
  {
    mp_impl->S03_AXI_tlm_aximm_read_socket->bind(*(mp_S03_AXI_transactor->rd_socket));
    mp_impl->S03_AXI_tlm_aximm_write_socket->bind(*(mp_S03_AXI_transactor->wr_socket));
  
  }
  else
  {
    S03_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S03_AXI_transactor_target_wr_socket_stub->bind(*(mp_S03_AXI_transactor->wr_socket));
    S03_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S03_AXI_transactor_target_rd_socket_stub->bind(*(mp_S03_AXI_transactor->rd_socket));
    mp_S03_AXI_transactor->disable_transactor();
  }

  // configure 'S04_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S04_AXI_TLM_MODE") != 1)
  {
    mp_impl->S04_AXI_tlm_aximm_read_socket->bind(*(mp_S04_AXI_transactor->rd_socket));
    mp_impl->S04_AXI_tlm_aximm_write_socket->bind(*(mp_S04_AXI_transactor->wr_socket));
  
  }
  else
  {
    S04_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S04_AXI_transactor_target_wr_socket_stub->bind(*(mp_S04_AXI_transactor->wr_socket));
    S04_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S04_AXI_transactor_target_rd_socket_stub->bind(*(mp_S04_AXI_transactor->rd_socket));
    mp_S04_AXI_transactor->disable_transactor();
  }

  // configure 'S05_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S05_AXI_TLM_MODE") != 1)
  {
    mp_impl->S05_AXI_tlm_aximm_read_socket->bind(*(mp_S05_AXI_transactor->rd_socket));
    mp_impl->S05_AXI_tlm_aximm_write_socket->bind(*(mp_S05_AXI_transactor->wr_socket));
  
  }
  else
  {
    S05_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S05_AXI_transactor_target_wr_socket_stub->bind(*(mp_S05_AXI_transactor->wr_socket));
    S05_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S05_AXI_transactor_target_rd_socket_stub->bind(*(mp_S05_AXI_transactor->rd_socket));
    mp_S05_AXI_transactor->disable_transactor();
  }

  // configure 'S06_AXI' transactor
  if (xsc::utils::xsc_sim_manager::getInstanceParameterInt("bd_soc_usart_axi_noc_0_0", "S06_AXI_TLM_MODE") != 1)
  {
    mp_impl->S06_AXI_tlm_aximm_read_socket->bind(*(mp_S06_AXI_transactor->rd_socket));
    mp_impl->S06_AXI_tlm_aximm_write_socket->bind(*(mp_S06_AXI_transactor->wr_socket));
  
  }
  else
  {
    S06_AXI_transactor_target_wr_socket_stub = new xtlm::xtlm_aximm_target_stub("wr_socket",0);
    S06_AXI_transactor_target_wr_socket_stub->bind(*(mp_S06_AXI_transactor->wr_socket));
    S06_AXI_transactor_target_rd_socket_stub = new xtlm::xtlm_aximm_target_stub("rd_socket",0);
    S06_AXI_transactor_target_rd_socket_stub->bind(*(mp_S06_AXI_transactor->rd_socket));
    mp_S06_AXI_transactor->disable_transactor();
  }

}

#endif // MTI_SYSTEMC




bd_soc_usart_axi_noc_0_0::~bd_soc_usart_axi_noc_0_0()
{
  delete mp_S00_AXI_transactor;
  delete mp_S00_AXI_awlock_converter;
  delete mp_S00_AXI_awvalid_converter;
  delete mp_S00_AXI_awready_converter;
  delete mp_S00_AXI_wlast_converter;
  delete mp_S00_AXI_wvalid_converter;
  delete mp_S00_AXI_wready_converter;
  delete mp_S00_AXI_bvalid_converter;
  delete mp_S00_AXI_bready_converter;
  delete mp_S00_AXI_arlock_converter;
  delete mp_S00_AXI_arvalid_converter;
  delete mp_S00_AXI_arready_converter;
  delete mp_S00_AXI_rlast_converter;
  delete mp_S00_AXI_rvalid_converter;
  delete mp_S00_AXI_rready_converter;

  delete mp_S01_AXI_transactor;
  delete mp_S01_AXI_awlock_converter;
  delete mp_S01_AXI_awvalid_converter;
  delete mp_S01_AXI_awready_converter;
  delete mp_S01_AXI_wlast_converter;
  delete mp_S01_AXI_wvalid_converter;
  delete mp_S01_AXI_wready_converter;
  delete mp_S01_AXI_bvalid_converter;
  delete mp_S01_AXI_bready_converter;
  delete mp_S01_AXI_arlock_converter;
  delete mp_S01_AXI_arvalid_converter;
  delete mp_S01_AXI_arready_converter;
  delete mp_S01_AXI_rlast_converter;
  delete mp_S01_AXI_rvalid_converter;
  delete mp_S01_AXI_rready_converter;

  delete mp_S02_AXI_transactor;
  delete mp_S02_AXI_awlock_converter;
  delete mp_S02_AXI_awvalid_converter;
  delete mp_S02_AXI_awready_converter;
  delete mp_S02_AXI_wlast_converter;
  delete mp_S02_AXI_wvalid_converter;
  delete mp_S02_AXI_wready_converter;
  delete mp_S02_AXI_bvalid_converter;
  delete mp_S02_AXI_bready_converter;
  delete mp_S02_AXI_arlock_converter;
  delete mp_S02_AXI_arvalid_converter;
  delete mp_S02_AXI_arready_converter;
  delete mp_S02_AXI_rlast_converter;
  delete mp_S02_AXI_rvalid_converter;
  delete mp_S02_AXI_rready_converter;

  delete mp_S03_AXI_transactor;
  delete mp_S03_AXI_awlock_converter;
  delete mp_S03_AXI_awvalid_converter;
  delete mp_S03_AXI_awready_converter;
  delete mp_S03_AXI_wlast_converter;
  delete mp_S03_AXI_wvalid_converter;
  delete mp_S03_AXI_wready_converter;
  delete mp_S03_AXI_bvalid_converter;
  delete mp_S03_AXI_bready_converter;
  delete mp_S03_AXI_arlock_converter;
  delete mp_S03_AXI_arvalid_converter;
  delete mp_S03_AXI_arready_converter;
  delete mp_S03_AXI_rlast_converter;
  delete mp_S03_AXI_rvalid_converter;
  delete mp_S03_AXI_rready_converter;

  delete mp_S04_AXI_transactor;
  delete mp_S04_AXI_awlock_converter;
  delete mp_S04_AXI_awvalid_converter;
  delete mp_S04_AXI_awready_converter;
  delete mp_S04_AXI_wlast_converter;
  delete mp_S04_AXI_wvalid_converter;
  delete mp_S04_AXI_wready_converter;
  delete mp_S04_AXI_bvalid_converter;
  delete mp_S04_AXI_bready_converter;
  delete mp_S04_AXI_arlock_converter;
  delete mp_S04_AXI_arvalid_converter;
  delete mp_S04_AXI_arready_converter;
  delete mp_S04_AXI_rlast_converter;
  delete mp_S04_AXI_rvalid_converter;
  delete mp_S04_AXI_rready_converter;

  delete mp_S05_AXI_transactor;
  delete mp_S05_AXI_awlock_converter;
  delete mp_S05_AXI_awvalid_converter;
  delete mp_S05_AXI_awready_converter;
  delete mp_S05_AXI_wlast_converter;
  delete mp_S05_AXI_wvalid_converter;
  delete mp_S05_AXI_wready_converter;
  delete mp_S05_AXI_bvalid_converter;
  delete mp_S05_AXI_bready_converter;
  delete mp_S05_AXI_arlock_converter;
  delete mp_S05_AXI_arvalid_converter;
  delete mp_S05_AXI_arready_converter;
  delete mp_S05_AXI_rlast_converter;
  delete mp_S05_AXI_rvalid_converter;
  delete mp_S05_AXI_rready_converter;

  delete mp_S06_AXI_transactor;
  delete mp_S06_AXI_awlock_converter;
  delete mp_S06_AXI_awvalid_converter;
  delete mp_S06_AXI_awready_converter;
  delete mp_S06_AXI_wlast_converter;
  delete mp_S06_AXI_wvalid_converter;
  delete mp_S06_AXI_wready_converter;
  delete mp_S06_AXI_bvalid_converter;
  delete mp_S06_AXI_bready_converter;
  delete mp_S06_AXI_arlock_converter;
  delete mp_S06_AXI_arvalid_converter;
  delete mp_S06_AXI_arready_converter;
  delete mp_S06_AXI_rlast_converter;
  delete mp_S06_AXI_rvalid_converter;
  delete mp_S06_AXI_rready_converter;

}

#ifdef MTI_SYSTEMC
SC_MODULE_EXPORT(bd_soc_usart_axi_noc_0_0);
#endif

#ifdef XM_SYSTEMC
XMSC_MODULE_EXPORT(bd_soc_usart_axi_noc_0_0);
#endif

#ifdef RIVIERA
SC_MODULE_EXPORT(bd_soc_usart_axi_noc_0_0);
SC_REGISTER_BV(128);
#endif

