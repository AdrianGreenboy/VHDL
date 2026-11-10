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

-- IP VLNV: xilinx.com:module_ref:rv128_soc_wrap:1.0
-- IP Revision: 1

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY design_1_rv128_0 IS
  PORT (
    clk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    m_axi_dram_awid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_dram_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_dram_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_dram_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_dram_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_dram_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_dram_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_dram_awvalid : OUT STD_LOGIC;
    m_axi_dram_awready : IN STD_LOGIC;
    m_axi_dram_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    m_axi_dram_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axi_dram_wlast : OUT STD_LOGIC;
    m_axi_dram_wvalid : OUT STD_LOGIC;
    m_axi_dram_wready : IN STD_LOGIC;
    m_axi_dram_bid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_dram_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_dram_bvalid : IN STD_LOGIC;
    m_axi_dram_bready : OUT STD_LOGIC;
    m_axi_dram_arid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_dram_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_dram_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_dram_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_dram_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_dram_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_dram_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_dram_arvalid : OUT STD_LOGIC;
    m_axi_dram_arready : IN STD_LOGIC;
    m_axi_dram_rid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_dram_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    m_axi_dram_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_dram_rlast : IN STD_LOGIC;
    m_axi_dram_rvalid : IN STD_LOGIC;
    m_axi_dram_rready : OUT STD_LOGIC;
    s_axi_ctrl_awaddr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_ctrl_awvalid : IN STD_LOGIC;
    s_axi_ctrl_awready : OUT STD_LOGIC;
    s_axi_ctrl_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_ctrl_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_ctrl_wvalid : IN STD_LOGIC;
    s_axi_ctrl_wready : OUT STD_LOGIC;
    s_axi_ctrl_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_ctrl_bvalid : OUT STD_LOGIC;
    s_axi_ctrl_bready : IN STD_LOGIC;
    s_axi_ctrl_araddr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_ctrl_arvalid : IN STD_LOGIC;
    s_axi_ctrl_arready : OUT STD_LOGIC;
    s_axi_ctrl_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_ctrl_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_ctrl_rvalid : OUT STD_LOGIC;
    s_axi_ctrl_rready : IN STD_LOGIC;
    mm_sel : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    mm_req : OUT STD_LOGIC;
    mm_addr : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    mm_wdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    mm_wstrb : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    mm_rdata : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
    irq_ip : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    soc_rst : OUT STD_LOGIC
  );
END design_1_rv128_0;

ARCHITECTURE design_1_rv128_0_arch OF design_1_rv128_0 IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF design_1_rv128_0_arch: ARCHITECTURE IS "yes";
  COMPONENT rv128_soc_wrap IS
    GENERIC (
      TICK_DIV : INTEGER;
      DRAM_PHYS : STD_LOGIC_VECTOR;
      DRAM_MASK : STD_LOGIC_VECTOR
    );
    PORT (
      clk : IN STD_LOGIC;
      aresetn : IN STD_LOGIC;
      m_axi_dram_awid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_dram_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axi_dram_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_dram_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_dram_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_dram_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_dram_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_dram_awvalid : OUT STD_LOGIC;
      m_axi_dram_awready : IN STD_LOGIC;
      m_axi_dram_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      m_axi_dram_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axi_dram_wlast : OUT STD_LOGIC;
      m_axi_dram_wvalid : OUT STD_LOGIC;
      m_axi_dram_wready : IN STD_LOGIC;
      m_axi_dram_bid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_dram_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_dram_bvalid : IN STD_LOGIC;
      m_axi_dram_bready : OUT STD_LOGIC;
      m_axi_dram_arid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_dram_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axi_dram_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_dram_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_dram_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_dram_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_dram_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_dram_arvalid : OUT STD_LOGIC;
      m_axi_dram_arready : IN STD_LOGIC;
      m_axi_dram_rid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_dram_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      m_axi_dram_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_dram_rlast : IN STD_LOGIC;
      m_axi_dram_rvalid : IN STD_LOGIC;
      m_axi_dram_rready : OUT STD_LOGIC;
      s_axi_ctrl_awaddr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      s_axi_ctrl_awvalid : IN STD_LOGIC;
      s_axi_ctrl_awready : OUT STD_LOGIC;
      s_axi_ctrl_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axi_ctrl_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      s_axi_ctrl_wvalid : IN STD_LOGIC;
      s_axi_ctrl_wready : OUT STD_LOGIC;
      s_axi_ctrl_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      s_axi_ctrl_bvalid : OUT STD_LOGIC;
      s_axi_ctrl_bready : IN STD_LOGIC;
      s_axi_ctrl_araddr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      s_axi_ctrl_arvalid : IN STD_LOGIC;
      s_axi_ctrl_arready : OUT STD_LOGIC;
      s_axi_ctrl_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axi_ctrl_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      s_axi_ctrl_rvalid : OUT STD_LOGIC;
      s_axi_ctrl_rready : IN STD_LOGIC;
      mm_sel : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      mm_req : OUT STD_LOGIC;
      mm_addr : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      mm_wdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      mm_wstrb : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      mm_rdata : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
      irq_ip : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      soc_rst : OUT STD_LOGIC
    );
  END COMPONENT rv128_soc_wrap;
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_MODE : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF aresetn: SIGNAL IS "xilinx.com:signal:reset:1.0 aresetn RST";
  ATTRIBUTE X_INTERFACE_MODE OF aresetn: SIGNAL IS "slave aresetn";
  ATTRIBUTE X_INTERFACE_PARAMETER OF aresetn: SIGNAL IS "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF clk: SIGNAL IS "xilinx.com:signal:clock:1.0 clk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF clk: SIGNAL IS "slave clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF clk: SIGNAL IS "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF m_axi_dram:s_axi_ctrl, ASSOCIATED_RESET aresetn, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWID";
  ATTRIBUTE X_INTERFACE_MODE OF m_axi_dram_awid: SIGNAL IS "master m_axi_dram";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axi_dram_awid: SIGNAL IS "XIL_INTERFACENAME m_axi_dram, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 50000000, ID_WIDTH 4, ADDR_WIDTH 64, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, NUM_READ_THREADS 1, NUM_WR" & 
"ITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram BID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram RID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_dram_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 m_axi_dram WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWADDR";
  ATTRIBUTE X_INTERFACE_MODE OF s_axi_ctrl_awaddr: SIGNAL IS "slave s_axi_ctrl";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axi_ctrl_awaddr: SIGNAL IS "XIL_INTERFACENAME s_axi_ctrl, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 50000000, ID_WIDTH 0, ADDR_WIDTH 16, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, NUM_READ_THREADS 1, NUM_W" & 
"RITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF s_axi_ctrl_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 s_axi_ctrl WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF soc_rst: SIGNAL IS "xilinx.com:signal:reset:1.0 soc_rst RST";
  ATTRIBUTE X_INTERFACE_MODE OF soc_rst: SIGNAL IS "master soc_rst";
  ATTRIBUTE X_INTERFACE_PARAMETER OF soc_rst: SIGNAL IS "XIL_INTERFACENAME soc_rst, POLARITY ACTIVE_LOW, INSERT_VIP 0";
BEGIN
  U0 : rv128_soc_wrap
    GENERIC MAP (
      TICK_DIV => 50,
      DRAM_PHYS => X"0000000070000000",
      DRAM_MASK => X"0000000007FFFFFF"
    )
    PORT MAP (
      clk => clk,
      aresetn => aresetn,
      m_axi_dram_awid => m_axi_dram_awid,
      m_axi_dram_awaddr => m_axi_dram_awaddr,
      m_axi_dram_awlen => m_axi_dram_awlen,
      m_axi_dram_awsize => m_axi_dram_awsize,
      m_axi_dram_awburst => m_axi_dram_awburst,
      m_axi_dram_awcache => m_axi_dram_awcache,
      m_axi_dram_awprot => m_axi_dram_awprot,
      m_axi_dram_awvalid => m_axi_dram_awvalid,
      m_axi_dram_awready => m_axi_dram_awready,
      m_axi_dram_wdata => m_axi_dram_wdata,
      m_axi_dram_wstrb => m_axi_dram_wstrb,
      m_axi_dram_wlast => m_axi_dram_wlast,
      m_axi_dram_wvalid => m_axi_dram_wvalid,
      m_axi_dram_wready => m_axi_dram_wready,
      m_axi_dram_bid => m_axi_dram_bid,
      m_axi_dram_bresp => m_axi_dram_bresp,
      m_axi_dram_bvalid => m_axi_dram_bvalid,
      m_axi_dram_bready => m_axi_dram_bready,
      m_axi_dram_arid => m_axi_dram_arid,
      m_axi_dram_araddr => m_axi_dram_araddr,
      m_axi_dram_arlen => m_axi_dram_arlen,
      m_axi_dram_arsize => m_axi_dram_arsize,
      m_axi_dram_arburst => m_axi_dram_arburst,
      m_axi_dram_arcache => m_axi_dram_arcache,
      m_axi_dram_arprot => m_axi_dram_arprot,
      m_axi_dram_arvalid => m_axi_dram_arvalid,
      m_axi_dram_arready => m_axi_dram_arready,
      m_axi_dram_rid => m_axi_dram_rid,
      m_axi_dram_rdata => m_axi_dram_rdata,
      m_axi_dram_rresp => m_axi_dram_rresp,
      m_axi_dram_rlast => m_axi_dram_rlast,
      m_axi_dram_rvalid => m_axi_dram_rvalid,
      m_axi_dram_rready => m_axi_dram_rready,
      s_axi_ctrl_awaddr => s_axi_ctrl_awaddr,
      s_axi_ctrl_awvalid => s_axi_ctrl_awvalid,
      s_axi_ctrl_awready => s_axi_ctrl_awready,
      s_axi_ctrl_wdata => s_axi_ctrl_wdata,
      s_axi_ctrl_wstrb => s_axi_ctrl_wstrb,
      s_axi_ctrl_wvalid => s_axi_ctrl_wvalid,
      s_axi_ctrl_wready => s_axi_ctrl_wready,
      s_axi_ctrl_bresp => s_axi_ctrl_bresp,
      s_axi_ctrl_bvalid => s_axi_ctrl_bvalid,
      s_axi_ctrl_bready => s_axi_ctrl_bready,
      s_axi_ctrl_araddr => s_axi_ctrl_araddr,
      s_axi_ctrl_arvalid => s_axi_ctrl_arvalid,
      s_axi_ctrl_arready => s_axi_ctrl_arready,
      s_axi_ctrl_rdata => s_axi_ctrl_rdata,
      s_axi_ctrl_rresp => s_axi_ctrl_rresp,
      s_axi_ctrl_rvalid => s_axi_ctrl_rvalid,
      s_axi_ctrl_rready => s_axi_ctrl_rready,
      mm_sel => mm_sel,
      mm_req => mm_req,
      mm_addr => mm_addr,
      mm_wdata => mm_wdata,
      mm_wstrb => mm_wstrb,
      mm_rdata => mm_rdata,
      irq_ip => irq_ip,
      soc_rst => soc_rst
    );
END design_1_rv128_0_arch;
