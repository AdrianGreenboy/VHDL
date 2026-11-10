-- (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:ip:xram:1.0
-- IP Revision: 1

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY bd_70da_xram_0 IS
  PORT (
    s_axi_xram3_aclk : IN STD_LOGIC;
    lpd_lsbus_clk : IN STD_LOGIC;
    ps_ocm2_apb_prdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    ps_ocm2_apb_pready : OUT STD_LOGIC;
    ps_ocm2_apb_pslverr : OUT STD_LOGIC;
    ps_ocm2_apb_paddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    ps_ocm2_apb_penable : IN STD_LOGIC;
    ps_ocm2_apb_pprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_apb_psel : IN STD_LOGIC;
    ps_ocm2_apb_pstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_apb_pwdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    ps_ocm2_apb_pwrite : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    ps_ocm2_axi_arready : OUT STD_LOGIC;
    ps_ocm2_axi_awready : OUT STD_LOGIC;
    ps_ocm2_axi_bid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    ps_ocm2_axi_buser : OUT STD_LOGIC;
    ps_ocm2_axi_bvalid : OUT STD_LOGIC;
    ps_ocm2_axi_rdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    ps_ocm2_axi_rid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_rlast : OUT STD_LOGIC;
    ps_ocm2_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    ps_ocm2_axi_ruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    ps_ocm2_axi_rvalid : OUT STD_LOGIC;
    ps_ocm2_axi_wready : OUT STD_LOGIC;
    ps_ocm2_axi_araddr : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    ps_ocm2_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    ps_ocm2_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_arid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    ps_ocm2_axi_arlock : IN STD_LOGIC;
    ps_ocm2_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_axi_arqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_arregion : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_axi_aruser : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_arvalid : IN STD_LOGIC;
    ps_ocm2_axi_awaddr : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    ps_ocm2_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    ps_ocm2_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_awid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    ps_ocm2_axi_awlock : IN STD_LOGIC;
    ps_ocm2_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_axi_awqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_awregion : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_axi_awuser : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_awvalid : IN STD_LOGIC;
    ps_ocm2_axi_bready : IN STD_LOGIC;
    ps_ocm2_axi_rready : IN STD_LOGIC;
    ps_ocm2_axi_wdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    ps_ocm2_axi_wid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_wlast : IN STD_LOGIC;
    ps_ocm2_axi_wstrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_wuser : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    ps_ocm2_axi_wvalid : IN STD_LOGIC
  );
END bd_70da_xram_0;

ARCHITECTURE bd_70da_xram_0_arch OF bd_70da_xram_0 IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF bd_70da_xram_0_arch: ARCHITECTURE IS "yes";
  COMPONENT xram_v1_0_1 IS
    GENERIC (
      C_S_AXI_XRAM0_DATA_WIDTH : INTEGER;
      C_S_AXI_XRAM1_DATA_WIDTH : INTEGER;
      C_S_AXI_XRAM2_DATA_WIDTH : INTEGER;
      C_S_AXI_LITE_XRAM_DATA_WIDTH : INTEGER;
      C_SIM_DEVICE : STRING;
      C_CORE_NAME : STRING;
      C_PL_INTERFACE_0_INTERFACE_USAGE : INTEGER;
      C_PL_INTERFACE_1_INTERFACE_USAGE : INTEGER;
      C_PL_INTERFACE_2_INTERFACE_USAGE : INTEGER;
      C_MEM_FREQ : INTEGER;
      C_PL_INTERFACE_0_FREQUENCY : INTEGER;
      C_PL_INTERFACE_1_FREQUENCY : INTEGER;
      C_PL_INTERFACE_2_FREQUENCY : INTEGER
    );
    PORT (
      s_axi_xram3_aclk : IN STD_LOGIC;
      lpd_lsbus_clk : IN STD_LOGIC;
      ps_ocm2_apb_prdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      ps_ocm2_apb_pready : OUT STD_LOGIC;
      ps_ocm2_apb_pslverr : OUT STD_LOGIC;
      ps_ocm2_apb_paddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      ps_ocm2_apb_penable : IN STD_LOGIC;
      ps_ocm2_apb_pprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_apb_psel : IN STD_LOGIC;
      ps_ocm2_apb_pstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_apb_pwdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      ps_ocm2_apb_pwrite : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      ps_ocm2_axi_arready : OUT STD_LOGIC;
      ps_ocm2_axi_awready : OUT STD_LOGIC;
      ps_ocm2_axi_bid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      ps_ocm2_axi_buser : OUT STD_LOGIC;
      ps_ocm2_axi_bvalid : OUT STD_LOGIC;
      ps_ocm2_axi_rdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      ps_ocm2_axi_rid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_rlast : OUT STD_LOGIC;
      ps_ocm2_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      ps_ocm2_axi_ruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      ps_ocm2_axi_rvalid : OUT STD_LOGIC;
      ps_ocm2_axi_wready : OUT STD_LOGIC;
      ps_ocm2_axi_araddr : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      ps_ocm2_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      ps_ocm2_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_arid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      ps_ocm2_axi_arlock : IN STD_LOGIC;
      ps_ocm2_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_axi_arqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_arregion : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_axi_aruser : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_arvalid : IN STD_LOGIC;
      ps_ocm2_axi_awaddr : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      ps_ocm2_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      ps_ocm2_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_awid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      ps_ocm2_axi_awlock : IN STD_LOGIC;
      ps_ocm2_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_axi_awqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_awregion : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_axi_awuser : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_awvalid : IN STD_LOGIC;
      ps_ocm2_axi_bready : IN STD_LOGIC;
      ps_ocm2_axi_rready : IN STD_LOGIC;
      ps_ocm2_axi_wdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      ps_ocm2_axi_wid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_wlast : IN STD_LOGIC;
      ps_ocm2_axi_wstrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_wuser : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      ps_ocm2_axi_wvalid : IN STD_LOGIC
    );
  END COMPONENT xram_v1_0_1;
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF bd_70da_xram_0_arch: ARCHITECTURE IS "xram_v1_0_1,Vivado 2025.2.1";
  ATTRIBUTE CHECK_LICENSE_TYPE : STRING;
  ATTRIBUTE CHECK_LICENSE_TYPE OF bd_70da_xram_0_arch : ARCHITECTURE IS "bd_70da_xram_0,xram_v1_0_1,{}";
  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF bd_70da_xram_0_arch: ARCHITECTURE IS "bd_70da_xram_0,xram_v1_0_1,{x_ipProduct=Vivado 2025.2.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=xram,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,C_S_AXI_XRAM0_DATA_WIDTH=256,C_S_AXI_XRAM1_DATA_WIDTH=256,C_S_AXI_XRAM2_DATA_WIDTH=256,C_S_AXI_LITE_XRAM_DATA_WIDTH=32,C_SIM_DEVICE=VERSAL_CORE,C_CORE_NAME=xram_0,C_PL_INTERFACE_0_INTERFACE_USAGE=0,C_PL_INTERFACE_1_INTERFACE_USAGE=0,C_PL_INTERFACE_2_INTERFACE_USAGE=0,C_MEM_FREQ=400,C_PL_INTERFACE_0_FREQUENCY=0,C_PL_I" & 
"NTERFACE_1_FREQUENCY=0,C_PL_INTERFACE_2_FREQUENCY=0}";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_MODE : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF lpd_lsbus_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 lpd_lsbus_clk LPD_LSBUS_CLK";
  ATTRIBUTE X_INTERFACE_MODE OF lpd_lsbus_clk: SIGNAL IS "slave lpd_lsbus_clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF lpd_lsbus_clk: SIGNAL IS "XIL_INTERFACENAME lpd_lsbus_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_lpd_lsbus_clk, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_paddr: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PADDR";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_penable: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PENABLE";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_pprot: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PPROT";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_prdata: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PRDATA";
  ATTRIBUTE X_INTERFACE_MODE OF ps_ocm2_apb_prdata: SIGNAL IS "slave S_APB_XRAM";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_pready: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PREADY";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_psel: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PSEL";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_pslverr: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PSLVERR";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_pstrb: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_pwdata: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PWDATA";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_pwrite: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PWRITE";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARQOS";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARREADY";
  ATTRIBUTE X_INTERFACE_MODE OF ps_ocm2_axi_arready: SIGNAL IS "slave S_AXI_XRAM3";
  ATTRIBUTE X_INTERFACE_PARAMETER OF ps_ocm2_axi_arready: SIGNAL IS "XIL_INTERFACENAME S_AXI_XRAM3, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 18, RUSER_WIDTH 18, BUSER_WIDTH 1, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_s_axi_xram3_aclk, NUM_READ_THREA" & 
"DS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arregion: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARREGION";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_aruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARUSER";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWQOS";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awregion: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWREGION";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWUSER";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_buser: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BUSER";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_ruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RUSER";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_wid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_wuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WUSER";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_axi_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 S_AXI_XRAM3 WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_xram3_aclk: SIGNAL IS "xilinx.com:signal:clock:1.0 s_axi_xram3_aclk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF s_axi_xram3_aclk: SIGNAL IS "slave s_axi_xram3_aclk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axi_xram3_aclk: SIGNAL IS "XIL_INTERFACENAME s_axi_xram3_aclk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_s_axi_xram3_aclk, ASSOCIATED_BUSIF S_AXI_XRAM3, INSERT_VIP 0";
BEGIN
  U0 : xram_v1_0_1
    GENERIC MAP (
      C_S_AXI_XRAM0_DATA_WIDTH => 256,
      C_S_AXI_XRAM1_DATA_WIDTH => 256,
      C_S_AXI_XRAM2_DATA_WIDTH => 256,
      C_S_AXI_LITE_XRAM_DATA_WIDTH => 32,
      C_SIM_DEVICE => "VERSAL_CORE",
      C_CORE_NAME => "xram_0",
      C_PL_INTERFACE_0_INTERFACE_USAGE => 0,
      C_PL_INTERFACE_1_INTERFACE_USAGE => 0,
      C_PL_INTERFACE_2_INTERFACE_USAGE => 0,
      C_MEM_FREQ => 400,
      C_PL_INTERFACE_0_FREQUENCY => 0,
      C_PL_INTERFACE_1_FREQUENCY => 0,
      C_PL_INTERFACE_2_FREQUENCY => 0
    )
    PORT MAP (
      s_axi_xram3_aclk => s_axi_xram3_aclk,
      lpd_lsbus_clk => lpd_lsbus_clk,
      ps_ocm2_apb_prdata => ps_ocm2_apb_prdata,
      ps_ocm2_apb_pready => ps_ocm2_apb_pready,
      ps_ocm2_apb_pslverr => ps_ocm2_apb_pslverr,
      ps_ocm2_apb_paddr => ps_ocm2_apb_paddr,
      ps_ocm2_apb_penable => ps_ocm2_apb_penable,
      ps_ocm2_apb_pprot => ps_ocm2_apb_pprot,
      ps_ocm2_apb_psel => ps_ocm2_apb_psel,
      ps_ocm2_apb_pstrb => ps_ocm2_apb_pstrb,
      ps_ocm2_apb_pwdata => ps_ocm2_apb_pwdata,
      ps_ocm2_apb_pwrite => ps_ocm2_apb_pwrite,
      ps_ocm2_axi_arready => ps_ocm2_axi_arready,
      ps_ocm2_axi_awready => ps_ocm2_axi_awready,
      ps_ocm2_axi_bid => ps_ocm2_axi_bid,
      ps_ocm2_axi_bresp => ps_ocm2_axi_bresp,
      ps_ocm2_axi_buser => ps_ocm2_axi_buser,
      ps_ocm2_axi_bvalid => ps_ocm2_axi_bvalid,
      ps_ocm2_axi_rdata => ps_ocm2_axi_rdata,
      ps_ocm2_axi_rid => ps_ocm2_axi_rid,
      ps_ocm2_axi_rlast => ps_ocm2_axi_rlast,
      ps_ocm2_axi_rresp => ps_ocm2_axi_rresp,
      ps_ocm2_axi_ruser => ps_ocm2_axi_ruser,
      ps_ocm2_axi_rvalid => ps_ocm2_axi_rvalid,
      ps_ocm2_axi_wready => ps_ocm2_axi_wready,
      ps_ocm2_axi_araddr => ps_ocm2_axi_araddr,
      ps_ocm2_axi_arburst => ps_ocm2_axi_arburst,
      ps_ocm2_axi_arcache => ps_ocm2_axi_arcache,
      ps_ocm2_axi_arid => ps_ocm2_axi_arid,
      ps_ocm2_axi_arlen => ps_ocm2_axi_arlen,
      ps_ocm2_axi_arlock => ps_ocm2_axi_arlock,
      ps_ocm2_axi_arprot => ps_ocm2_axi_arprot,
      ps_ocm2_axi_arqos => ps_ocm2_axi_arqos,
      ps_ocm2_axi_arregion => ps_ocm2_axi_arregion,
      ps_ocm2_axi_arsize => ps_ocm2_axi_arsize,
      ps_ocm2_axi_aruser => ps_ocm2_axi_aruser,
      ps_ocm2_axi_arvalid => ps_ocm2_axi_arvalid,
      ps_ocm2_axi_awaddr => ps_ocm2_axi_awaddr,
      ps_ocm2_axi_awburst => ps_ocm2_axi_awburst,
      ps_ocm2_axi_awcache => ps_ocm2_axi_awcache,
      ps_ocm2_axi_awid => ps_ocm2_axi_awid,
      ps_ocm2_axi_awlen => ps_ocm2_axi_awlen,
      ps_ocm2_axi_awlock => ps_ocm2_axi_awlock,
      ps_ocm2_axi_awprot => ps_ocm2_axi_awprot,
      ps_ocm2_axi_awqos => ps_ocm2_axi_awqos,
      ps_ocm2_axi_awregion => ps_ocm2_axi_awregion,
      ps_ocm2_axi_awsize => ps_ocm2_axi_awsize,
      ps_ocm2_axi_awuser => ps_ocm2_axi_awuser,
      ps_ocm2_axi_awvalid => ps_ocm2_axi_awvalid,
      ps_ocm2_axi_bready => ps_ocm2_axi_bready,
      ps_ocm2_axi_rready => ps_ocm2_axi_rready,
      ps_ocm2_axi_wdata => ps_ocm2_axi_wdata,
      ps_ocm2_axi_wid => ps_ocm2_axi_wid,
      ps_ocm2_axi_wlast => ps_ocm2_axi_wlast,
      ps_ocm2_axi_wstrb => ps_ocm2_axi_wstrb,
      ps_ocm2_axi_wuser => ps_ocm2_axi_wuser,
      ps_ocm2_axi_wvalid => ps_ocm2_axi_wvalid
    );
END bd_70da_xram_0_arch;
