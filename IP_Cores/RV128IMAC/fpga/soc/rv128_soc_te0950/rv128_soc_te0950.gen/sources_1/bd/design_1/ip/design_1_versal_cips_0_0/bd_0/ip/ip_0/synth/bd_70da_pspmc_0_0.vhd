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

-- IP VLNV: xilinx.com:ip:pspmc:1.4
-- IP Revision: 7

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY bd_70da_pspmc_0_0 IS
  PORT (
    pl0_ref_clk : OUT STD_LOGIC;
    pl0_resetn : OUT STD_LOGIC;
    m_axi_fpd_aclk : IN STD_LOGIC;
    m_axi_fpd_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axi_fpd_awaddr : OUT STD_LOGIC_VECTOR(43 DOWNTO 0);
    m_axi_fpd_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_fpd_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_fpd_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_fpd_awlock : OUT STD_LOGIC;
    m_axi_fpd_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_fpd_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_fpd_awvalid : OUT STD_LOGIC;
    m_axi_fpd_awuser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axi_fpd_awready : IN STD_LOGIC;
    m_axi_fpd_wlast : OUT STD_LOGIC;
    m_axi_fpd_wvalid : OUT STD_LOGIC;
    m_axi_fpd_wready : IN STD_LOGIC;
    m_axi_fpd_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axi_fpd_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_fpd_bvalid : IN STD_LOGIC;
    m_axi_fpd_bready : OUT STD_LOGIC;
    m_axi_fpd_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axi_fpd_araddr : OUT STD_LOGIC_VECTOR(43 DOWNTO 0);
    m_axi_fpd_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_fpd_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_fpd_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_fpd_arlock : OUT STD_LOGIC;
    m_axi_fpd_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_fpd_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_fpd_arvalid : OUT STD_LOGIC;
    m_axi_fpd_aruser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axi_fpd_arready : IN STD_LOGIC;
    m_axi_fpd_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axi_fpd_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_fpd_rlast : IN STD_LOGIC;
    m_axi_fpd_rvalid : IN STD_LOGIC;
    m_axi_fpd_rready : OUT STD_LOGIC;
    m_axi_fpd_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_fpd_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_fpd_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    m_axi_fpd_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axi_fpd_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi0_clk : OUT STD_LOGIC;
    fpd_cci_noc_axi0_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi0_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    fpd_cci_noc_axi0_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    fpd_cci_noc_axi0_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi0_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi0_awlock : OUT STD_LOGIC;
    fpd_cci_noc_axi0_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi0_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi0_awvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi0_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    fpd_cci_noc_axi0_awready : IN STD_LOGIC;
    fpd_cci_noc_axi0_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi0_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi0_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
    fpd_cci_noc_axi0_wlast : OUT STD_LOGIC;
    fpd_cci_noc_axi0_wvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi0_wready : IN STD_LOGIC;
    fpd_cci_noc_axi0_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi0_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi0_bvalid : IN STD_LOGIC;
    fpd_cci_noc_axi0_bready : OUT STD_LOGIC;
    fpd_cci_noc_axi0_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi0_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    fpd_cci_noc_axi0_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    fpd_cci_noc_axi0_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi0_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi0_arlock : OUT STD_LOGIC;
    fpd_cci_noc_axi0_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi0_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi0_arvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi0_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    fpd_cci_noc_axi0_arready : IN STD_LOGIC;
    fpd_cci_noc_axi0_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi0_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi0_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi0_rlast : IN STD_LOGIC;
    fpd_cci_noc_axi0_rvalid : IN STD_LOGIC;
    fpd_cci_noc_axi0_rready : OUT STD_LOGIC;
    fpd_cci_noc_axi0_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi0_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi1_clk : OUT STD_LOGIC;
    fpd_cci_noc_axi1_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi1_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    fpd_cci_noc_axi1_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    fpd_cci_noc_axi1_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi1_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi1_awlock : OUT STD_LOGIC;
    fpd_cci_noc_axi1_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi1_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi1_awvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi1_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    fpd_cci_noc_axi1_awready : IN STD_LOGIC;
    fpd_cci_noc_axi1_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi1_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi1_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
    fpd_cci_noc_axi1_wlast : OUT STD_LOGIC;
    fpd_cci_noc_axi1_wvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi1_wready : IN STD_LOGIC;
    fpd_cci_noc_axi1_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi1_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi1_bvalid : IN STD_LOGIC;
    fpd_cci_noc_axi1_bready : OUT STD_LOGIC;
    fpd_cci_noc_axi1_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi1_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    fpd_cci_noc_axi1_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    fpd_cci_noc_axi1_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi1_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi1_arlock : OUT STD_LOGIC;
    fpd_cci_noc_axi1_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi1_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi1_arvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi1_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    fpd_cci_noc_axi1_arready : IN STD_LOGIC;
    fpd_cci_noc_axi1_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi1_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi1_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi1_rlast : IN STD_LOGIC;
    fpd_cci_noc_axi1_rvalid : IN STD_LOGIC;
    fpd_cci_noc_axi1_rready : OUT STD_LOGIC;
    fpd_cci_noc_axi1_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi1_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi2_clk : OUT STD_LOGIC;
    fpd_cci_noc_axi2_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi2_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    fpd_cci_noc_axi2_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    fpd_cci_noc_axi2_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi2_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi2_awlock : OUT STD_LOGIC;
    fpd_cci_noc_axi2_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi2_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi2_awvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi2_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    fpd_cci_noc_axi2_awready : IN STD_LOGIC;
    fpd_cci_noc_axi2_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi2_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi2_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
    fpd_cci_noc_axi2_wlast : OUT STD_LOGIC;
    fpd_cci_noc_axi2_wvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi2_wready : IN STD_LOGIC;
    fpd_cci_noc_axi2_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi2_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi2_bvalid : IN STD_LOGIC;
    fpd_cci_noc_axi2_bready : OUT STD_LOGIC;
    fpd_cci_noc_axi2_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi2_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    fpd_cci_noc_axi2_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    fpd_cci_noc_axi2_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi2_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi2_arlock : OUT STD_LOGIC;
    fpd_cci_noc_axi2_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi2_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi2_arvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi2_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    fpd_cci_noc_axi2_arready : IN STD_LOGIC;
    fpd_cci_noc_axi2_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi2_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi2_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi2_rlast : IN STD_LOGIC;
    fpd_cci_noc_axi2_rvalid : IN STD_LOGIC;
    fpd_cci_noc_axi2_rready : OUT STD_LOGIC;
    fpd_cci_noc_axi2_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi2_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi3_clk : OUT STD_LOGIC;
    fpd_cci_noc_axi3_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi3_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    fpd_cci_noc_axi3_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    fpd_cci_noc_axi3_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi3_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi3_awlock : OUT STD_LOGIC;
    fpd_cci_noc_axi3_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi3_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi3_awvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi3_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    fpd_cci_noc_axi3_awready : IN STD_LOGIC;
    fpd_cci_noc_axi3_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi3_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi3_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
    fpd_cci_noc_axi3_wlast : OUT STD_LOGIC;
    fpd_cci_noc_axi3_wvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi3_wready : IN STD_LOGIC;
    fpd_cci_noc_axi3_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi3_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi3_bvalid : IN STD_LOGIC;
    fpd_cci_noc_axi3_bready : OUT STD_LOGIC;
    fpd_cci_noc_axi3_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi3_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    fpd_cci_noc_axi3_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    fpd_cci_noc_axi3_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi3_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi3_arlock : OUT STD_LOGIC;
    fpd_cci_noc_axi3_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi3_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    fpd_cci_noc_axi3_arvalid : OUT STD_LOGIC;
    fpd_cci_noc_axi3_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    fpd_cci_noc_axi3_arready : IN STD_LOGIC;
    fpd_cci_noc_axi3_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    fpd_cci_noc_axi3_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    fpd_cci_noc_axi3_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    fpd_cci_noc_axi3_rlast : IN STD_LOGIC;
    fpd_cci_noc_axi3_rvalid : IN STD_LOGIC;
    fpd_cci_noc_axi3_rready : OUT STD_LOGIC;
    fpd_cci_noc_axi3_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    fpd_cci_noc_axi3_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    lpd_axi_noc_clk : OUT STD_LOGIC;
    lpd_axi_noc_axi0_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    lpd_axi_noc_axi0_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    lpd_axi_noc_axi0_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    lpd_axi_noc_axi0_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    lpd_axi_noc_axi0_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    lpd_axi_noc_axi0_awlock : OUT STD_LOGIC;
    lpd_axi_noc_axi0_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    lpd_axi_noc_axi0_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    lpd_axi_noc_axi0_awvalid : OUT STD_LOGIC;
    lpd_axi_noc_axi0_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    lpd_axi_noc_axi0_awready : IN STD_LOGIC;
    lpd_axi_noc_axi0_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    lpd_axi_noc_axi0_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    lpd_axi_noc_axi0_wlast : OUT STD_LOGIC;
    lpd_axi_noc_axi0_wvalid : OUT STD_LOGIC;
    lpd_axi_noc_axi0_wready : IN STD_LOGIC;
    lpd_axi_noc_axi0_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    lpd_axi_noc_axi0_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    lpd_axi_noc_axi0_bvalid : IN STD_LOGIC;
    lpd_axi_noc_axi0_bready : OUT STD_LOGIC;
    lpd_axi_noc_axi0_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    lpd_axi_noc_axi0_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    lpd_axi_noc_axi0_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    lpd_axi_noc_axi0_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    lpd_axi_noc_axi0_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    lpd_axi_noc_axi0_arlock : OUT STD_LOGIC;
    lpd_axi_noc_axi0_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    lpd_axi_noc_axi0_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    lpd_axi_noc_axi0_arvalid : OUT STD_LOGIC;
    lpd_axi_noc_axi0_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    lpd_axi_noc_axi0_arready : IN STD_LOGIC;
    lpd_axi_noc_axi0_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    lpd_axi_noc_axi0_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    lpd_axi_noc_axi0_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    lpd_axi_noc_axi0_rlast : IN STD_LOGIC;
    lpd_axi_noc_axi0_rvalid : IN STD_LOGIC;
    lpd_axi_noc_axi0_rready : OUT STD_LOGIC;
    lpd_axi_noc_axi0_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    lpd_axi_noc_axi0_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pmc_axi_noc_axi0_clk : OUT STD_LOGIC;
    pmc_noc_axi0_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    pmc_noc_axi0_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    pmc_noc_axi0_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pmc_noc_axi0_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    pmc_noc_axi0_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    pmc_noc_axi0_arlock : OUT STD_LOGIC;
    pmc_noc_axi0_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    pmc_noc_axi0_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pmc_noc_axi0_arregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pmc_noc_axi0_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    pmc_noc_axi0_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    pmc_noc_axi0_arvalid : OUT STD_LOGIC;
    pmc_noc_axi0_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    pmc_noc_axi0_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    pmc_noc_axi0_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pmc_noc_axi0_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    pmc_noc_axi0_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    pmc_noc_axi0_awlock : OUT STD_LOGIC;
    pmc_noc_axi0_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    pmc_noc_axi0_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pmc_noc_axi0_awregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    pmc_noc_axi0_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    pmc_noc_axi0_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    pmc_noc_axi0_awvalid : OUT STD_LOGIC;
    pmc_noc_axi0_bready : OUT STD_LOGIC;
    pmc_noc_axi0_rready : OUT STD_LOGIC;
    pmc_noc_axi0_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    pmc_noc_axi0_wid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    pmc_noc_axi0_wlast : OUT STD_LOGIC;
    pmc_noc_axi0_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    pmc_noc_axi0_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
    pmc_noc_axi0_wvalid : OUT STD_LOGIC;
    pmc_noc_axi0_arready : IN STD_LOGIC;
    pmc_noc_axi0_awready : IN STD_LOGIC;
    pmc_noc_axi0_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    pmc_noc_axi0_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    pmc_noc_axi0_buser : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    pmc_noc_axi0_bvalid : IN STD_LOGIC;
    pmc_noc_axi0_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    pmc_noc_axi0_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    pmc_noc_axi0_rlast : IN STD_LOGIC;
    pmc_noc_axi0_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    pmc_noc_axi0_ruser : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
    pmc_noc_axi0_rvalid : IN STD_LOGIC;
    pmc_noc_axi0_wready : IN STD_LOGIC;
    gem0_tsu_timer_cnt : OUT STD_LOGIC_VECTOR(93 DOWNTO 0);
    s_axi_xram3_aclk : OUT STD_LOGIC;
    lpd_lsbus_clk : OUT STD_LOGIC;
    ps_ocm2_apb_prdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    ps_ocm2_apb_pready : IN STD_LOGIC;
    ps_ocm2_apb_pslverr : IN STD_LOGIC;
    ps_ocm2_apb_paddr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    ps_ocm2_apb_penable : OUT STD_LOGIC;
    ps_ocm2_apb_pprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_apb_psel : OUT STD_LOGIC;
    ps_ocm2_apb_pstrb : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_apb_pwdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    ps_ocm2_apb_pwrite : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    ps_ocm2_axi_arready : IN STD_LOGIC;
    ps_ocm2_axi_awready : IN STD_LOGIC;
    ps_ocm2_axi_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    ps_ocm2_axi_buser : IN STD_LOGIC;
    ps_ocm2_axi_bvalid : IN STD_LOGIC;
    ps_ocm2_axi_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    ps_ocm2_axi_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_rlast : IN STD_LOGIC;
    ps_ocm2_axi_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    ps_ocm2_axi_ruser : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    ps_ocm2_axi_rvalid : IN STD_LOGIC;
    ps_ocm2_axi_wready : IN STD_LOGIC;
    ps_ocm2_axi_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    ps_ocm2_axi_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    ps_ocm2_axi_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    ps_ocm2_axi_arlock : OUT STD_LOGIC;
    ps_ocm2_axi_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_axi_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_arregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_axi_aruser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_arvalid : OUT STD_LOGIC;
    ps_ocm2_axi_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    ps_ocm2_axi_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    ps_ocm2_axi_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    ps_ocm2_axi_awlock : OUT STD_LOGIC;
    ps_ocm2_axi_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_axi_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_awregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    ps_ocm2_axi_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    ps_ocm2_axi_awuser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_awvalid : OUT STD_LOGIC;
    ps_ocm2_axi_bready : OUT STD_LOGIC;
    ps_ocm2_axi_rready : OUT STD_LOGIC;
    ps_ocm2_axi_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    ps_ocm2_axi_wid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_wlast : OUT STD_LOGIC;
    ps_ocm2_axi_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    ps_ocm2_axi_wuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    ps_ocm2_axi_wvalid : OUT STD_LOGIC
  );
END bd_70da_pspmc_0_0;

ARCHITECTURE bd_70da_pspmc_0_0_arch OF bd_70da_pspmc_0_0 IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF bd_70da_pspmc_0_0_arch: ARCHITECTURE IS "yes";
  COMPONENT pspmc_v1_4_7_pspmc IS
    GENERIC (
      C_M_AXI_GP0_DATA_WIDTH : INTEGER;
      C_M_AXI_GP2_DATA_WIDTH : INTEGER;
      C_DIFF_RW_CLK_S_AXI_GP0 : INTEGER;
      C_DIFF_RW_CLK_S_AXI_GP2 : INTEGER;
      C_DIFF_RW_CLK_S_AXI_GP4 : INTEGER;
      C_S_AXI_GP0_DATA_WIDTH : INTEGER;
      C_S_AXI_GP2_DATA_WIDTH : INTEGER;
      C_S_AXI_GP4_DATA_WIDTH : INTEGER;
      C_S_AXI_ACP_DATA_WIDTH : INTEGER;
      C_S_AXI_ACE_DATA_WIDTH : INTEGER;
      C_PS_NOC_CCI_DATA_WIDTH : INTEGER;
      C_PS_NOC_NCI_DATA_WIDTH : INTEGER;
      C_NOC_PS_CCI_DATA_WIDTH : INTEGER;
      C_PS_NOC_PMC_DATA_WIDTH : INTEGER;
      C_NOC_PS_PMC_DATA_WIDTH : INTEGER;
      C_PS_NOC_RPU_DATA_WIDTH : INTEGER;
      C_PS_EMIO_GPIO_WIDTH : INTEGER;
      C_PMC_EMIO_GPIO_WIDTH : INTEGER;
      C_PMC_GPO_WIDTH : INTEGER;
      C_PMC_GPI_WIDTH : INTEGER;
      C_PL_SEM_GPO_ENABLE : INTEGER;
      C_PMC_NOC_ADDR_WIDTH : INTEGER;
      C_PMC_NOC_DATA_WIDTH : INTEGER;
      C_NOC_PMC_ADDR_WIDTH : INTEGER;
      C_NOC_PMC_DATA_WIDTH : INTEGER;
      C_XDEVICE : STRING;
      C_SIM_DEVICE : STRING;
      C_SPP_PSPMC_TO_CORE_WIDTH : INTEGER;
      C_SPP_PSPMC_FROM_CORE_WIDTH : INTEGER;
      C_NUM_F2P0_INTR_INPUTS : STRING;
      C_NUM_F2P1_INTR_INPUTS : STRING;
      C_PMCPL_CLK0_BUF : INTEGER;
      C_PMCPL_CLK1_BUF : INTEGER;
      C_PMCPL_CLK2_BUF : INTEGER;
      C_PMCPL_CLK3_BUF : INTEGER;
      C_PMCPL_IRO_CLK_BUF : INTEGER;
      C_ACE_LITE : INTEGER;
      C_PS_USE_S_AXI_GP2 : INTEGER;
      C_AXI4_EXT_USER_BITS : INTEGER;
      C_PMC_USE_PL_ERR0 : INTEGER;
      C_PMC_USE_PL_ERR1 : INTEGER;
      C_PMC_USE_PL_ERR2 : INTEGER;
      C_PMC_USE_PL_ERR3 : INTEGER;
      C_PS_PMU_PERIPHERAL_ENABLE : INTEGER;
      C_SUBCORE_NAME : STRING;
      C_VIP_SUBCORE_NAME : STRING;
      C_CORE_NAME : STRING;
      C_SD0_DATA_WIDTH : INTEGER;
      C_SD1_DATA_WIDTH : INTEGER;
      C_PS_TRACE_WIDTH : INTEGER;
      C_PS_TRACE_PERIPHERAL : INTEGER;
      C_PS_USE_STARTUP : INTEGER;
      C_PS_USE_CAPTURE : INTEGER;
      C_SLR1_PS_USE_CAPTURE : INTEGER;
      C_SLR2_PS_USE_CAPTURE : INTEGER;
      C_SLR3_PS_USE_CAPTURE : INTEGER;
      C_PS_USE_RPU_INTERRUPT : INTEGER;
      C_PS_PCIE_EP_RESET1_IO : STRING;
      C_PS_PCIE_EP_RESET2_IO : STRING;
      C_PS_TIE_MJTAG_TCK_TO_GND : INTEGER;
      C_LPD_GPIO_EMIO_ENABLE : INTEGER;
      C_PMC_GPIO_EMIO_ENABLE : INTEGER;
      C_PS_I2C0_PERIPHERAL_ENABLE : INTEGER;
      C_PS_I2C1_PERIPHERAL_ENABLE : INTEGER;
      C_PMC_I2CPMC_PERIPHERAL : INTEGER;
      C_GEM0_TSU_INC_CTRL : INTEGER;
      C_GEM_TSU_ENABLE : INTEGER
    );
    PORT (
      pl0_ref_clk : OUT STD_LOGIC;
      pl0_resetn : OUT STD_LOGIC;
      m_axi_fpd_aclk : IN STD_LOGIC;
      m_axi_fpd_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axi_fpd_awaddr : OUT STD_LOGIC_VECTOR(43 DOWNTO 0);
      m_axi_fpd_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_fpd_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_fpd_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_fpd_awlock : OUT STD_LOGIC;
      m_axi_fpd_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_fpd_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_fpd_awvalid : OUT STD_LOGIC;
      m_axi_fpd_awuser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axi_fpd_awready : IN STD_LOGIC;
      m_axi_fpd_wlast : OUT STD_LOGIC;
      m_axi_fpd_wvalid : OUT STD_LOGIC;
      m_axi_fpd_wready : IN STD_LOGIC;
      m_axi_fpd_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axi_fpd_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_fpd_bvalid : IN STD_LOGIC;
      m_axi_fpd_bready : OUT STD_LOGIC;
      m_axi_fpd_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axi_fpd_araddr : OUT STD_LOGIC_VECTOR(43 DOWNTO 0);
      m_axi_fpd_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_fpd_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_fpd_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_fpd_arlock : OUT STD_LOGIC;
      m_axi_fpd_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_fpd_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_fpd_arvalid : OUT STD_LOGIC;
      m_axi_fpd_aruser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axi_fpd_arready : IN STD_LOGIC;
      m_axi_fpd_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axi_fpd_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_fpd_rlast : IN STD_LOGIC;
      m_axi_fpd_rvalid : IN STD_LOGIC;
      m_axi_fpd_rready : OUT STD_LOGIC;
      m_axi_fpd_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_fpd_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_fpd_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      m_axi_fpd_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axi_fpd_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi0_clk : OUT STD_LOGIC;
      fpd_cci_noc_axi0_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi0_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      fpd_cci_noc_axi0_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      fpd_cci_noc_axi0_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi0_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi0_awlock : OUT STD_LOGIC;
      fpd_cci_noc_axi0_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi0_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi0_awvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi0_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fpd_cci_noc_axi0_awready : IN STD_LOGIC;
      fpd_cci_noc_axi0_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi0_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi0_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      fpd_cci_noc_axi0_wlast : OUT STD_LOGIC;
      fpd_cci_noc_axi0_wvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi0_wready : IN STD_LOGIC;
      fpd_cci_noc_axi0_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi0_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi0_bvalid : IN STD_LOGIC;
      fpd_cci_noc_axi0_bready : OUT STD_LOGIC;
      fpd_cci_noc_axi0_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi0_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      fpd_cci_noc_axi0_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      fpd_cci_noc_axi0_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi0_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi0_arlock : OUT STD_LOGIC;
      fpd_cci_noc_axi0_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi0_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi0_arvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi0_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fpd_cci_noc_axi0_arready : IN STD_LOGIC;
      fpd_cci_noc_axi0_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi0_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi0_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi0_rlast : IN STD_LOGIC;
      fpd_cci_noc_axi0_rvalid : IN STD_LOGIC;
      fpd_cci_noc_axi0_rready : OUT STD_LOGIC;
      fpd_cci_noc_axi0_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi0_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi1_clk : OUT STD_LOGIC;
      fpd_cci_noc_axi1_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi1_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      fpd_cci_noc_axi1_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      fpd_cci_noc_axi1_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi1_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi1_awlock : OUT STD_LOGIC;
      fpd_cci_noc_axi1_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi1_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi1_awvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi1_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fpd_cci_noc_axi1_awready : IN STD_LOGIC;
      fpd_cci_noc_axi1_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi1_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi1_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      fpd_cci_noc_axi1_wlast : OUT STD_LOGIC;
      fpd_cci_noc_axi1_wvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi1_wready : IN STD_LOGIC;
      fpd_cci_noc_axi1_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi1_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi1_bvalid : IN STD_LOGIC;
      fpd_cci_noc_axi1_bready : OUT STD_LOGIC;
      fpd_cci_noc_axi1_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi1_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      fpd_cci_noc_axi1_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      fpd_cci_noc_axi1_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi1_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi1_arlock : OUT STD_LOGIC;
      fpd_cci_noc_axi1_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi1_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi1_arvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi1_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fpd_cci_noc_axi1_arready : IN STD_LOGIC;
      fpd_cci_noc_axi1_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi1_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi1_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi1_rlast : IN STD_LOGIC;
      fpd_cci_noc_axi1_rvalid : IN STD_LOGIC;
      fpd_cci_noc_axi1_rready : OUT STD_LOGIC;
      fpd_cci_noc_axi1_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi1_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi2_clk : OUT STD_LOGIC;
      fpd_cci_noc_axi2_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi2_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      fpd_cci_noc_axi2_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      fpd_cci_noc_axi2_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi2_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi2_awlock : OUT STD_LOGIC;
      fpd_cci_noc_axi2_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi2_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi2_awvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi2_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fpd_cci_noc_axi2_awready : IN STD_LOGIC;
      fpd_cci_noc_axi2_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi2_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi2_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      fpd_cci_noc_axi2_wlast : OUT STD_LOGIC;
      fpd_cci_noc_axi2_wvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi2_wready : IN STD_LOGIC;
      fpd_cci_noc_axi2_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi2_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi2_bvalid : IN STD_LOGIC;
      fpd_cci_noc_axi2_bready : OUT STD_LOGIC;
      fpd_cci_noc_axi2_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi2_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      fpd_cci_noc_axi2_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      fpd_cci_noc_axi2_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi2_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi2_arlock : OUT STD_LOGIC;
      fpd_cci_noc_axi2_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi2_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi2_arvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi2_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fpd_cci_noc_axi2_arready : IN STD_LOGIC;
      fpd_cci_noc_axi2_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi2_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi2_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi2_rlast : IN STD_LOGIC;
      fpd_cci_noc_axi2_rvalid : IN STD_LOGIC;
      fpd_cci_noc_axi2_rready : OUT STD_LOGIC;
      fpd_cci_noc_axi2_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi2_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi3_clk : OUT STD_LOGIC;
      fpd_cci_noc_axi3_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi3_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      fpd_cci_noc_axi3_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      fpd_cci_noc_axi3_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi3_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi3_awlock : OUT STD_LOGIC;
      fpd_cci_noc_axi3_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi3_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi3_awvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi3_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fpd_cci_noc_axi3_awready : IN STD_LOGIC;
      fpd_cci_noc_axi3_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi3_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi3_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      fpd_cci_noc_axi3_wlast : OUT STD_LOGIC;
      fpd_cci_noc_axi3_wvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi3_wready : IN STD_LOGIC;
      fpd_cci_noc_axi3_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi3_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi3_bvalid : IN STD_LOGIC;
      fpd_cci_noc_axi3_bready : OUT STD_LOGIC;
      fpd_cci_noc_axi3_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi3_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      fpd_cci_noc_axi3_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      fpd_cci_noc_axi3_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi3_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi3_arlock : OUT STD_LOGIC;
      fpd_cci_noc_axi3_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi3_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      fpd_cci_noc_axi3_arvalid : OUT STD_LOGIC;
      fpd_cci_noc_axi3_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      fpd_cci_noc_axi3_arready : IN STD_LOGIC;
      fpd_cci_noc_axi3_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      fpd_cci_noc_axi3_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      fpd_cci_noc_axi3_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fpd_cci_noc_axi3_rlast : IN STD_LOGIC;
      fpd_cci_noc_axi3_rvalid : IN STD_LOGIC;
      fpd_cci_noc_axi3_rready : OUT STD_LOGIC;
      fpd_cci_noc_axi3_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      fpd_cci_noc_axi3_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      lpd_axi_noc_clk : OUT STD_LOGIC;
      lpd_axi_noc_axi0_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      lpd_axi_noc_axi0_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      lpd_axi_noc_axi0_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      lpd_axi_noc_axi0_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      lpd_axi_noc_axi0_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      lpd_axi_noc_axi0_awlock : OUT STD_LOGIC;
      lpd_axi_noc_axi0_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      lpd_axi_noc_axi0_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      lpd_axi_noc_axi0_awvalid : OUT STD_LOGIC;
      lpd_axi_noc_axi0_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      lpd_axi_noc_axi0_awready : IN STD_LOGIC;
      lpd_axi_noc_axi0_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      lpd_axi_noc_axi0_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      lpd_axi_noc_axi0_wlast : OUT STD_LOGIC;
      lpd_axi_noc_axi0_wvalid : OUT STD_LOGIC;
      lpd_axi_noc_axi0_wready : IN STD_LOGIC;
      lpd_axi_noc_axi0_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      lpd_axi_noc_axi0_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      lpd_axi_noc_axi0_bvalid : IN STD_LOGIC;
      lpd_axi_noc_axi0_bready : OUT STD_LOGIC;
      lpd_axi_noc_axi0_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      lpd_axi_noc_axi0_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      lpd_axi_noc_axi0_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      lpd_axi_noc_axi0_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      lpd_axi_noc_axi0_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      lpd_axi_noc_axi0_arlock : OUT STD_LOGIC;
      lpd_axi_noc_axi0_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      lpd_axi_noc_axi0_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      lpd_axi_noc_axi0_arvalid : OUT STD_LOGIC;
      lpd_axi_noc_axi0_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      lpd_axi_noc_axi0_arready : IN STD_LOGIC;
      lpd_axi_noc_axi0_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      lpd_axi_noc_axi0_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      lpd_axi_noc_axi0_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      lpd_axi_noc_axi0_rlast : IN STD_LOGIC;
      lpd_axi_noc_axi0_rvalid : IN STD_LOGIC;
      lpd_axi_noc_axi0_rready : OUT STD_LOGIC;
      lpd_axi_noc_axi0_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      lpd_axi_noc_axi0_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pmc_axi_noc_axi0_clk : OUT STD_LOGIC;
      pmc_noc_axi0_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      pmc_noc_axi0_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      pmc_noc_axi0_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pmc_noc_axi0_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      pmc_noc_axi0_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      pmc_noc_axi0_arlock : OUT STD_LOGIC;
      pmc_noc_axi0_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      pmc_noc_axi0_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pmc_noc_axi0_arregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pmc_noc_axi0_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      pmc_noc_axi0_aruser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      pmc_noc_axi0_arvalid : OUT STD_LOGIC;
      pmc_noc_axi0_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      pmc_noc_axi0_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      pmc_noc_axi0_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pmc_noc_axi0_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      pmc_noc_axi0_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      pmc_noc_axi0_awlock : OUT STD_LOGIC;
      pmc_noc_axi0_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      pmc_noc_axi0_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pmc_noc_axi0_awregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      pmc_noc_axi0_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      pmc_noc_axi0_awuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      pmc_noc_axi0_awvalid : OUT STD_LOGIC;
      pmc_noc_axi0_bready : OUT STD_LOGIC;
      pmc_noc_axi0_rready : OUT STD_LOGIC;
      pmc_noc_axi0_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      pmc_noc_axi0_wid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      pmc_noc_axi0_wlast : OUT STD_LOGIC;
      pmc_noc_axi0_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      pmc_noc_axi0_wuser : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      pmc_noc_axi0_wvalid : OUT STD_LOGIC;
      pmc_noc_axi0_arready : IN STD_LOGIC;
      pmc_noc_axi0_awready : IN STD_LOGIC;
      pmc_noc_axi0_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      pmc_noc_axi0_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      pmc_noc_axi0_buser : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      pmc_noc_axi0_bvalid : IN STD_LOGIC;
      pmc_noc_axi0_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      pmc_noc_axi0_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      pmc_noc_axi0_rlast : IN STD_LOGIC;
      pmc_noc_axi0_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      pmc_noc_axi0_ruser : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
      pmc_noc_axi0_rvalid : IN STD_LOGIC;
      pmc_noc_axi0_wready : IN STD_LOGIC;
      gem0_tsu_timer_cnt : OUT STD_LOGIC_VECTOR(93 DOWNTO 0);
      s_axi_xram3_aclk : OUT STD_LOGIC;
      lpd_lsbus_clk : OUT STD_LOGIC;
      ps_ocm2_apb_prdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      ps_ocm2_apb_pready : IN STD_LOGIC;
      ps_ocm2_apb_pslverr : IN STD_LOGIC;
      ps_ocm2_apb_paddr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      ps_ocm2_apb_penable : OUT STD_LOGIC;
      ps_ocm2_apb_pprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_apb_psel : OUT STD_LOGIC;
      ps_ocm2_apb_pstrb : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_apb_pwdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      ps_ocm2_apb_pwrite : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      ps_ocm2_axi_arready : IN STD_LOGIC;
      ps_ocm2_axi_awready : IN STD_LOGIC;
      ps_ocm2_axi_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      ps_ocm2_axi_buser : IN STD_LOGIC;
      ps_ocm2_axi_bvalid : IN STD_LOGIC;
      ps_ocm2_axi_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
      ps_ocm2_axi_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_rlast : IN STD_LOGIC;
      ps_ocm2_axi_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      ps_ocm2_axi_ruser : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      ps_ocm2_axi_rvalid : IN STD_LOGIC;
      ps_ocm2_axi_wready : IN STD_LOGIC;
      ps_ocm2_axi_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      ps_ocm2_axi_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      ps_ocm2_axi_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      ps_ocm2_axi_arlock : OUT STD_LOGIC;
      ps_ocm2_axi_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_axi_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_arregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_axi_aruser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_arvalid : OUT STD_LOGIC;
      ps_ocm2_axi_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      ps_ocm2_axi_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      ps_ocm2_axi_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      ps_ocm2_axi_awlock : OUT STD_LOGIC;
      ps_ocm2_axi_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_axi_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_awregion : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      ps_ocm2_axi_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      ps_ocm2_axi_awuser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_awvalid : OUT STD_LOGIC;
      ps_ocm2_axi_bready : OUT STD_LOGIC;
      ps_ocm2_axi_rready : OUT STD_LOGIC;
      ps_ocm2_axi_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
      ps_ocm2_axi_wid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_wlast : OUT STD_LOGIC;
      ps_ocm2_axi_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      ps_ocm2_axi_wuser : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      ps_ocm2_axi_wvalid : OUT STD_LOGIC
    );
  END COMPONENT pspmc_v1_4_7_pspmc;
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF bd_70da_pspmc_0_0_arch: ARCHITECTURE IS "pspmc_v1_4_7_pspmc,Vivado 2025.2.1";
  ATTRIBUTE CHECK_LICENSE_TYPE : STRING;
  ATTRIBUTE CHECK_LICENSE_TYPE OF bd_70da_pspmc_0_0_arch : ARCHITECTURE IS "bd_70da_pspmc_0_0,pspmc_v1_4_7_pspmc,{}";
  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF bd_70da_pspmc_0_0_arch: ARCHITECTURE IS "bd_70da_pspmc_0_0,pspmc_v1_4_7_pspmc,{x_ipProduct=Vivado 2025.2.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=pspmc,x_ipVersion=1.4,x_ipCoreRevision=7,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,C_M_AXI_GP0_DATA_WIDTH=128,C_M_AXI_GP2_DATA_WIDTH=128,C_DIFF_RW_CLK_S_AXI_GP0=0,C_DIFF_RW_CLK_S_AXI_GP2=0,C_DIFF_RW_CLK_S_AXI_GP4=0,C_S_AXI_GP0_DATA_WIDTH=128,C_S_AXI_GP2_DATA_WIDTH=128,C_S_AXI_GP4_DATA_WIDTH=128,C_S_AXI_ACP_DATA_WIDTH=128,C_S_AXI_ACE_DATA_WIDTH=128,C_PS_NOC_CCI_DATA_WIDTH=128,C_PS_NOC_NCI" & 
"_DATA_WIDTH=128,C_NOC_PS_CCI_DATA_WIDTH=128,C_PS_NOC_PMC_DATA_WIDTH=128,C_NOC_PS_PMC_DATA_WIDTH=128,C_PS_NOC_RPU_DATA_WIDTH=128,C_PS_EMIO_GPIO_WIDTH=32,C_PMC_EMIO_GPIO_WIDTH=64,C_PMC_GPO_WIDTH=32,C_PMC_GPI_WIDTH=32,C_PL_SEM_GPO_ENABLE=0,C_PMC_NOC_ADDR_WIDTH=64,C_PMC_NOC_DATA_WIDTH=128,C_NOC_PMC_ADDR_WIDTH=64,C_NOC_PMC_DATA_WIDTH=128,C_XDEVICE=xcve2302,C_SIM_DEVICE=VERSAL_AI_CORE,C_SPP_PSPMC_TO_CORE_WIDTH=12000,C_SPP_PSPMC_FROM_CORE_WIDTH=12000,C_NUM_F2P0_INTR_INPUTS=1,C_NUM_F2P1_INTR_INPUTS=1,C_" & 
"PMCPL_CLK0_BUF=1,C_PMCPL_CLK1_BUF=0,C_PMCPL_CLK2_BUF=0,C_PMCPL_CLK3_BUF=0,C_PMCPL_IRO_CLK_BUF=0,C_ACE_LITE=0,C_PS_USE_S_AXI_GP2=0,C_AXI4_EXT_USER_BITS=0,C_PMC_USE_PL_ERR0=0,C_PMC_USE_PL_ERR1=0,C_PMC_USE_PL_ERR2=0,C_PMC_USE_PL_ERR3=0,C_PS_PMU_PERIPHERAL_ENABLE=0,C_SUBCORE_NAME=design_2_versal_cips_0_0_gt_quad_base,C_VIP_SUBCORE_NAME=versal_cips_ps_vip,C_CORE_NAME=design_2_versal_cips_0_0,C_SD0_DATA_WIDTH=8,C_SD1_DATA_WIDTH=4,C_PS_TRACE_WIDTH=2,C_PS_TRACE_PERIPHERAL=0,C_PS_USE_STARTUP=0,C_PS_USE_C" & 
"APTURE=0,C_SLR1_PS_USE_CAPTURE=0,C_SLR2_PS_USE_CAPTURE=0,C_SLR3_PS_USE_CAPTURE=0,C_PS_USE_RPU_INTERRUPT=0,C_PS_PCIE_EP_RESET1_IO=None,C_PS_PCIE_EP_RESET2_IO=None,C_PS_TIE_MJTAG_TCK_TO_GND=1,C_LPD_GPIO_EMIO_ENABLE=0,C_PMC_GPIO_EMIO_ENABLE=0,C_PS_I2C0_PERIPHERAL_ENABLE=0,C_PS_I2C1_PERIPHERAL_ENABLE=0,C_PMC_I2CPMC_PERIPHERAL=0,C_GEM0_TSU_INC_CTRL=3,C_GEM_TSU_ENABLE=1}";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_MODE : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARQOS";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_aruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWID";
  ATTRIBUTE X_INTERFACE_MODE OF fpd_cci_noc_axi0_awid: SIGNAL IS "master FPD_CCI_NOC_0";
  ATTRIBUTE X_INTERFACE_PARAMETER OF fpd_cci_noc_axi0_awid: SIGNAL IS "XIL_INTERFACENAME FPD_CCI_NOC_0, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 550000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_fpd_cci_noc_axi0_clk, NUM_REA" & 
"D_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_cci, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, INDEX 0";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWQOS";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 fpd_cci_noc_axi0_clk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF fpd_cci_noc_axi0_clk: SIGNAL IS "master fpd_cci_noc_axi0_clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF fpd_cci_noc_axi0_clk: SIGNAL IS "XIL_INTERFACENAME fpd_cci_noc_axi0_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_fpd_cci_noc_axi0_clk, ASSOCIATED_BUSIF FPD_CCI_NOC_0, INSERT_VIP 0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_wuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi0_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_0 WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARQOS";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_aruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWID";
  ATTRIBUTE X_INTERFACE_MODE OF fpd_cci_noc_axi1_awid: SIGNAL IS "master FPD_CCI_NOC_1";
  ATTRIBUTE X_INTERFACE_PARAMETER OF fpd_cci_noc_axi1_awid: SIGNAL IS "XIL_INTERFACENAME FPD_CCI_NOC_1, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 550000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_fpd_cci_noc_axi1_clk, NUM_REA" & 
"D_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_cci, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, INDEX 1";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWQOS";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 fpd_cci_noc_axi1_clk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF fpd_cci_noc_axi1_clk: SIGNAL IS "master fpd_cci_noc_axi1_clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF fpd_cci_noc_axi1_clk: SIGNAL IS "XIL_INTERFACENAME fpd_cci_noc_axi1_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_fpd_cci_noc_axi1_clk, ASSOCIATED_BUSIF FPD_CCI_NOC_1, INSERT_VIP 0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_wuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi1_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_1 WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARQOS";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_aruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWID";
  ATTRIBUTE X_INTERFACE_MODE OF fpd_cci_noc_axi2_awid: SIGNAL IS "master FPD_CCI_NOC_2";
  ATTRIBUTE X_INTERFACE_PARAMETER OF fpd_cci_noc_axi2_awid: SIGNAL IS "XIL_INTERFACENAME FPD_CCI_NOC_2, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 550000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_fpd_cci_noc_axi2_clk, NUM_REA" & 
"D_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_cci, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, INDEX 2";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWQOS";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 fpd_cci_noc_axi2_clk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF fpd_cci_noc_axi2_clk: SIGNAL IS "master fpd_cci_noc_axi2_clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF fpd_cci_noc_axi2_clk: SIGNAL IS "XIL_INTERFACENAME fpd_cci_noc_axi2_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_fpd_cci_noc_axi2_clk, ASSOCIATED_BUSIF FPD_CCI_NOC_2, INSERT_VIP 0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_wuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi2_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_2 WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARQOS";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_aruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWID";
  ATTRIBUTE X_INTERFACE_MODE OF fpd_cci_noc_axi3_awid: SIGNAL IS "master FPD_CCI_NOC_3";
  ATTRIBUTE X_INTERFACE_PARAMETER OF fpd_cci_noc_axi3_awid: SIGNAL IS "XIL_INTERFACENAME FPD_CCI_NOC_3, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 550000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_fpd_cci_noc_axi3_clk, NUM_REA" & 
"D_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_cci, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU, INDEX 3";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWQOS";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 fpd_cci_noc_axi3_clk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF fpd_cci_noc_axi3_clk: SIGNAL IS "master fpd_cci_noc_axi3_clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF fpd_cci_noc_axi3_clk: SIGNAL IS "XIL_INTERFACENAME fpd_cci_noc_axi3_clk, FREQ_HZ 550000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_fpd_cci_noc_axi3_clk, ASSOCIATED_BUSIF FPD_CCI_NOC_3, INSERT_VIP 0, PHYSICAL_CHANNEL PS_CCI_TO_NOC_NMU";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_wuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WUSER";
  ATTRIBUTE X_INTERFACE_INFO OF fpd_cci_noc_axi3_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 FPD_CCI_NOC_3 WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARQOS";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_aruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARUSER";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWID";
  ATTRIBUTE X_INTERFACE_MODE OF lpd_axi_noc_axi0_awid: SIGNAL IS "master LPD_AXI_NOC_0";
  ATTRIBUTE X_INTERFACE_PARAMETER OF lpd_axi_noc_axi0_awid: SIGNAL IS "XIL_INTERFACENAME LPD_AXI_NOC_0, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 400000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_lpd_axi_noc_clk, NUM_READ_THRE" & 
"ADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_rpu, PHYSICAL_CHANNEL PS_RPU_TO_NOC_NMU, INDEX 0";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWQOS";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWUSER";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_axi0_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 LPD_AXI_NOC_0 WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_axi_noc_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 lpd_axi_noc_clk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF lpd_axi_noc_clk: SIGNAL IS "master lpd_axi_noc_clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF lpd_axi_noc_clk: SIGNAL IS "XIL_INTERFACENAME lpd_axi_noc_clk, FREQ_HZ 400000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_lpd_axi_noc_clk, ASSOCIATED_BUSIF LPD_AXI_NOC_0, INSERT_VIP 0, PHYSICAL_CHANNEL PS_RPU_TO_NOC_NMU";
  ATTRIBUTE X_INTERFACE_INFO OF lpd_lsbus_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 lpd_lsbus_clk LPD_LSBUS_CLK";
  ATTRIBUTE X_INTERFACE_MODE OF lpd_lsbus_clk: SIGNAL IS "master lpd_lsbus_clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF lpd_lsbus_clk: SIGNAL IS "XIL_INTERFACENAME lpd_lsbus_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_lpd_lsbus_clk, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_aclk: SIGNAL IS "xilinx.com:signal:clock:1.0 m_axi_fpd_aclk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF m_axi_fpd_aclk: SIGNAL IS "slave m_axi_fpd_aclk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axi_fpd_aclk: SIGNAL IS "XIL_INTERFACENAME m_axi_fpd_aclk, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, ASSOCIATED_BUSIF M_AXI_FPD, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARADDR";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARQOS";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_aruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARUSER";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWID";
  ATTRIBUTE X_INTERFACE_MODE OF m_axi_fpd_awid: SIGNAL IS "master M_AXI_FPD";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axi_fpd_awid: SIGNAL IS "XIL_INTERFACENAME M_AXI_FPD, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 50000000, ID_WIDTH 16, ADDR_WIDTH 44, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, NUM_READ_THREADS 1, NUM_" & 
"WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY pl, MY_CATEGORY ps";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWQOS";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWUSER";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD BID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD RID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF m_axi_fpd_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 M_AXI_FPD WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF pl0_ref_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 PL0_REF_CLK CLK";
  ATTRIBUTE X_INTERFACE_MODE OF pl0_ref_clk: SIGNAL IS "master PL0_REF_CLK";
  ATTRIBUTE X_INTERFACE_PARAMETER OF pl0_ref_clk: SIGNAL IS "XIL_INTERFACENAME PL0_REF_CLK, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF pl0_resetn: SIGNAL IS "xilinx.com:signal:reset:1.0 PL0_RESETN RESET";
  ATTRIBUTE X_INTERFACE_MODE OF pl0_resetn: SIGNAL IS "master PL0_RESETN";
  ATTRIBUTE X_INTERFACE_PARAMETER OF pl0_resetn: SIGNAL IS "XIL_INTERFACENAME PL0_RESETN, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_axi_noc_axi0_clk: SIGNAL IS "xilinx.com:signal:clock:1.0 pmc_axi_noc_axi0_clk CLK";
  ATTRIBUTE X_INTERFACE_MODE OF pmc_axi_noc_axi0_clk: SIGNAL IS "master pmc_axi_noc_axi0_clk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF pmc_axi_noc_axi0_clk: SIGNAL IS "XIL_INTERFACENAME pmc_axi_noc_axi0_clk, FREQ_HZ 320000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pmc_axi_noc_axi0_clk, ASSOCIATED_BUSIF PMC_NOC_AXI_0, INSERT_VIP 0, PHYSICAL_CHANNEL PS_PMC_TO_NOC_NMU";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_araddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARADDR";
  ATTRIBUTE X_INTERFACE_MODE OF pmc_noc_axi0_araddr: SIGNAL IS "master PMC_NOC_AXI_0";
  ATTRIBUTE X_INTERFACE_PARAMETER OF pmc_noc_axi0_araddr: SIGNAL IS "XIL_INTERFACENAME PMC_NOC_AXI_0, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 320000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 18, ARUSER_WIDTH 18, WUSER_WIDTH 17, RUSER_WIDTH 17, BUSER_WIDTH 16, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 64, NUM_WRITE_OUTSTANDING 64, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pmc_axi_noc_axi0_clk, NUM_R" & 
"EAD_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0, CATEGORY noc, MY_CATEGORY ps_pmc, PHYSICAL_CHANNEL PS_PMC_TO_NOC_NMU, HD_TANDEM 0, INDEX 0, SLR_INDEX 0";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARBURST";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARLEN";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARPROT";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARQOS";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arready: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARREADY";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arregion: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARREGION";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_aruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARUSER";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_arvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 ARVALID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awaddr: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWADDR";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awburst: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWBURST";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awcache: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWCACHE";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awlen: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWLEN";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awlock: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWLOCK";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awprot: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWPROT";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awqos: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWQOS";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awready: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWREADY";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awregion: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWREGION";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awsize: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWSIZE";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWUSER";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_awvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 AWVALID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_bid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_bready: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BREADY";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_bresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BRESP";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_buser: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BUSER";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_bvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 BVALID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_rdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RDATA";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_rid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_rlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RLAST";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_rready: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RREADY";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_rresp: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RRESP";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_ruser: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RUSER";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_rvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 RVALID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_wdata: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WDATA";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_wid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WID";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_wlast: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WLAST";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_wready: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WREADY";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_wstrb: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WSTRB";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_wuser: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WUSER";
  ATTRIBUTE X_INTERFACE_INFO OF pmc_noc_axi0_wvalid: SIGNAL IS "xilinx.com:interface:aximm:1.0 PMC_NOC_AXI_0 WVALID";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_paddr: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PADDR";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_penable: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PENABLE";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_pprot: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PPROT";
  ATTRIBUTE X_INTERFACE_INFO OF ps_ocm2_apb_prdata: SIGNAL IS "xilinx.com:interface:apb:1.0 S_APB_XRAM PRDATA";
  ATTRIBUTE X_INTERFACE_MODE OF ps_ocm2_apb_prdata: SIGNAL IS "master S_APB_XRAM";
  ATTRIBUTE X_INTERFACE_PARAMETER OF ps_ocm2_apb_prdata: SIGNAL IS "XIL_INTERFACENAME S_APB_XRAM, ADDR_WIDTH 32";
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
  ATTRIBUTE X_INTERFACE_MODE OF ps_ocm2_axi_arready: SIGNAL IS "master S_AXI_XRAM3";
  ATTRIBUTE X_INTERFACE_PARAMETER OF ps_ocm2_axi_arready: SIGNAL IS "XIL_INTERFACENAME S_AXI_XRAM3, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 64, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 18, RUSER_WIDTH 18, BUSER_WIDTH 1, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE " & 
"0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
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
  ATTRIBUTE X_INTERFACE_MODE OF s_axi_xram3_aclk: SIGNAL IS "master s_axi_xram3_aclk";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axi_xram3_aclk: SIGNAL IS "XIL_INTERFACENAME s_axi_xram3_aclk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_s_axi_xram3_aclk, ASSOCIATED_BUSIF S_AXI_XRAM3, INSERT_VIP 0";
BEGIN
  U0 : pspmc_v1_4_7_pspmc
    GENERIC MAP (
      C_M_AXI_GP0_DATA_WIDTH => 128,
      C_M_AXI_GP2_DATA_WIDTH => 128,
      C_DIFF_RW_CLK_S_AXI_GP0 => 0,
      C_DIFF_RW_CLK_S_AXI_GP2 => 0,
      C_DIFF_RW_CLK_S_AXI_GP4 => 0,
      C_S_AXI_GP0_DATA_WIDTH => 128,
      C_S_AXI_GP2_DATA_WIDTH => 128,
      C_S_AXI_GP4_DATA_WIDTH => 128,
      C_S_AXI_ACP_DATA_WIDTH => 128,
      C_S_AXI_ACE_DATA_WIDTH => 128,
      C_PS_NOC_CCI_DATA_WIDTH => 128,
      C_PS_NOC_NCI_DATA_WIDTH => 128,
      C_NOC_PS_CCI_DATA_WIDTH => 128,
      C_PS_NOC_PMC_DATA_WIDTH => 128,
      C_NOC_PS_PMC_DATA_WIDTH => 128,
      C_PS_NOC_RPU_DATA_WIDTH => 128,
      C_PS_EMIO_GPIO_WIDTH => 32,
      C_PMC_EMIO_GPIO_WIDTH => 64,
      C_PMC_GPO_WIDTH => 32,
      C_PMC_GPI_WIDTH => 32,
      C_PL_SEM_GPO_ENABLE => 0,
      C_PMC_NOC_ADDR_WIDTH => 64,
      C_PMC_NOC_DATA_WIDTH => 128,
      C_NOC_PMC_ADDR_WIDTH => 64,
      C_NOC_PMC_DATA_WIDTH => 128,
      C_XDEVICE => "xcve2302",
      C_SIM_DEVICE => "VERSAL_AI_CORE",
      C_SPP_PSPMC_TO_CORE_WIDTH => 12000,
      C_SPP_PSPMC_FROM_CORE_WIDTH => 12000,
      C_NUM_F2P0_INTR_INPUTS => "1",
      C_NUM_F2P1_INTR_INPUTS => "1",
      C_PMCPL_CLK0_BUF => 1,
      C_PMCPL_CLK1_BUF => 0,
      C_PMCPL_CLK2_BUF => 0,
      C_PMCPL_CLK3_BUF => 0,
      C_PMCPL_IRO_CLK_BUF => 0,
      C_ACE_LITE => 0,
      C_PS_USE_S_AXI_GP2 => 0,
      C_AXI4_EXT_USER_BITS => 0,
      C_PMC_USE_PL_ERR0 => 0,
      C_PMC_USE_PL_ERR1 => 0,
      C_PMC_USE_PL_ERR2 => 0,
      C_PMC_USE_PL_ERR3 => 0,
      C_PS_PMU_PERIPHERAL_ENABLE => 0,
      C_SUBCORE_NAME => "design_2_versal_cips_0_0_gt_quad_base",
      C_VIP_SUBCORE_NAME => "versal_cips_ps_vip",
      C_CORE_NAME => "design_2_versal_cips_0_0",
      C_SD0_DATA_WIDTH => 8,
      C_SD1_DATA_WIDTH => 4,
      C_PS_TRACE_WIDTH => 2,
      C_PS_TRACE_PERIPHERAL => 0,
      C_PS_USE_STARTUP => 0,
      C_PS_USE_CAPTURE => 0,
      C_SLR1_PS_USE_CAPTURE => 0,
      C_SLR2_PS_USE_CAPTURE => 0,
      C_SLR3_PS_USE_CAPTURE => 0,
      C_PS_USE_RPU_INTERRUPT => 0,
      C_PS_PCIE_EP_RESET1_IO => "None",
      C_PS_PCIE_EP_RESET2_IO => "None",
      C_PS_TIE_MJTAG_TCK_TO_GND => 1,
      C_LPD_GPIO_EMIO_ENABLE => 0,
      C_PMC_GPIO_EMIO_ENABLE => 0,
      C_PS_I2C0_PERIPHERAL_ENABLE => 0,
      C_PS_I2C1_PERIPHERAL_ENABLE => 0,
      C_PMC_I2CPMC_PERIPHERAL => 0,
      C_GEM0_TSU_INC_CTRL => 3,
      C_GEM_TSU_ENABLE => 1
    )
    PORT MAP (
      pl0_ref_clk => pl0_ref_clk,
      pl0_resetn => pl0_resetn,
      m_axi_fpd_aclk => m_axi_fpd_aclk,
      m_axi_fpd_awid => m_axi_fpd_awid,
      m_axi_fpd_awaddr => m_axi_fpd_awaddr,
      m_axi_fpd_awlen => m_axi_fpd_awlen,
      m_axi_fpd_awsize => m_axi_fpd_awsize,
      m_axi_fpd_awburst => m_axi_fpd_awburst,
      m_axi_fpd_awlock => m_axi_fpd_awlock,
      m_axi_fpd_awcache => m_axi_fpd_awcache,
      m_axi_fpd_awprot => m_axi_fpd_awprot,
      m_axi_fpd_awvalid => m_axi_fpd_awvalid,
      m_axi_fpd_awuser => m_axi_fpd_awuser,
      m_axi_fpd_awready => m_axi_fpd_awready,
      m_axi_fpd_wlast => m_axi_fpd_wlast,
      m_axi_fpd_wvalid => m_axi_fpd_wvalid,
      m_axi_fpd_wready => m_axi_fpd_wready,
      m_axi_fpd_bid => m_axi_fpd_bid,
      m_axi_fpd_bresp => m_axi_fpd_bresp,
      m_axi_fpd_bvalid => m_axi_fpd_bvalid,
      m_axi_fpd_bready => m_axi_fpd_bready,
      m_axi_fpd_arid => m_axi_fpd_arid,
      m_axi_fpd_araddr => m_axi_fpd_araddr,
      m_axi_fpd_arlen => m_axi_fpd_arlen,
      m_axi_fpd_arsize => m_axi_fpd_arsize,
      m_axi_fpd_arburst => m_axi_fpd_arburst,
      m_axi_fpd_arlock => m_axi_fpd_arlock,
      m_axi_fpd_arcache => m_axi_fpd_arcache,
      m_axi_fpd_arprot => m_axi_fpd_arprot,
      m_axi_fpd_arvalid => m_axi_fpd_arvalid,
      m_axi_fpd_aruser => m_axi_fpd_aruser,
      m_axi_fpd_arready => m_axi_fpd_arready,
      m_axi_fpd_rid => m_axi_fpd_rid,
      m_axi_fpd_rresp => m_axi_fpd_rresp,
      m_axi_fpd_rlast => m_axi_fpd_rlast,
      m_axi_fpd_rvalid => m_axi_fpd_rvalid,
      m_axi_fpd_rready => m_axi_fpd_rready,
      m_axi_fpd_awqos => m_axi_fpd_awqos,
      m_axi_fpd_arqos => m_axi_fpd_arqos,
      m_axi_fpd_wdata => m_axi_fpd_wdata,
      m_axi_fpd_wstrb => m_axi_fpd_wstrb,
      m_axi_fpd_rdata => m_axi_fpd_rdata,
      fpd_cci_noc_axi0_clk => fpd_cci_noc_axi0_clk,
      fpd_cci_noc_axi0_awid => fpd_cci_noc_axi0_awid,
      fpd_cci_noc_axi0_awaddr => fpd_cci_noc_axi0_awaddr,
      fpd_cci_noc_axi0_awlen => fpd_cci_noc_axi0_awlen,
      fpd_cci_noc_axi0_awsize => fpd_cci_noc_axi0_awsize,
      fpd_cci_noc_axi0_awburst => fpd_cci_noc_axi0_awburst,
      fpd_cci_noc_axi0_awlock => fpd_cci_noc_axi0_awlock,
      fpd_cci_noc_axi0_awcache => fpd_cci_noc_axi0_awcache,
      fpd_cci_noc_axi0_awprot => fpd_cci_noc_axi0_awprot,
      fpd_cci_noc_axi0_awvalid => fpd_cci_noc_axi0_awvalid,
      fpd_cci_noc_axi0_awuser => fpd_cci_noc_axi0_awuser,
      fpd_cci_noc_axi0_awready => fpd_cci_noc_axi0_awready,
      fpd_cci_noc_axi0_wdata => fpd_cci_noc_axi0_wdata,
      fpd_cci_noc_axi0_wstrb => fpd_cci_noc_axi0_wstrb,
      fpd_cci_noc_axi0_wuser => fpd_cci_noc_axi0_wuser,
      fpd_cci_noc_axi0_wlast => fpd_cci_noc_axi0_wlast,
      fpd_cci_noc_axi0_wvalid => fpd_cci_noc_axi0_wvalid,
      fpd_cci_noc_axi0_wready => fpd_cci_noc_axi0_wready,
      fpd_cci_noc_axi0_bid => fpd_cci_noc_axi0_bid,
      fpd_cci_noc_axi0_bresp => fpd_cci_noc_axi0_bresp,
      fpd_cci_noc_axi0_bvalid => fpd_cci_noc_axi0_bvalid,
      fpd_cci_noc_axi0_bready => fpd_cci_noc_axi0_bready,
      fpd_cci_noc_axi0_arid => fpd_cci_noc_axi0_arid,
      fpd_cci_noc_axi0_araddr => fpd_cci_noc_axi0_araddr,
      fpd_cci_noc_axi0_arlen => fpd_cci_noc_axi0_arlen,
      fpd_cci_noc_axi0_arsize => fpd_cci_noc_axi0_arsize,
      fpd_cci_noc_axi0_arburst => fpd_cci_noc_axi0_arburst,
      fpd_cci_noc_axi0_arlock => fpd_cci_noc_axi0_arlock,
      fpd_cci_noc_axi0_arcache => fpd_cci_noc_axi0_arcache,
      fpd_cci_noc_axi0_arprot => fpd_cci_noc_axi0_arprot,
      fpd_cci_noc_axi0_arvalid => fpd_cci_noc_axi0_arvalid,
      fpd_cci_noc_axi0_aruser => fpd_cci_noc_axi0_aruser,
      fpd_cci_noc_axi0_arready => fpd_cci_noc_axi0_arready,
      fpd_cci_noc_axi0_rid => fpd_cci_noc_axi0_rid,
      fpd_cci_noc_axi0_rdata => fpd_cci_noc_axi0_rdata,
      fpd_cci_noc_axi0_rresp => fpd_cci_noc_axi0_rresp,
      fpd_cci_noc_axi0_rlast => fpd_cci_noc_axi0_rlast,
      fpd_cci_noc_axi0_rvalid => fpd_cci_noc_axi0_rvalid,
      fpd_cci_noc_axi0_rready => fpd_cci_noc_axi0_rready,
      fpd_cci_noc_axi0_awqos => fpd_cci_noc_axi0_awqos,
      fpd_cci_noc_axi0_arqos => fpd_cci_noc_axi0_arqos,
      fpd_cci_noc_axi1_clk => fpd_cci_noc_axi1_clk,
      fpd_cci_noc_axi1_awid => fpd_cci_noc_axi1_awid,
      fpd_cci_noc_axi1_awaddr => fpd_cci_noc_axi1_awaddr,
      fpd_cci_noc_axi1_awlen => fpd_cci_noc_axi1_awlen,
      fpd_cci_noc_axi1_awsize => fpd_cci_noc_axi1_awsize,
      fpd_cci_noc_axi1_awburst => fpd_cci_noc_axi1_awburst,
      fpd_cci_noc_axi1_awlock => fpd_cci_noc_axi1_awlock,
      fpd_cci_noc_axi1_awcache => fpd_cci_noc_axi1_awcache,
      fpd_cci_noc_axi1_awprot => fpd_cci_noc_axi1_awprot,
      fpd_cci_noc_axi1_awvalid => fpd_cci_noc_axi1_awvalid,
      fpd_cci_noc_axi1_awuser => fpd_cci_noc_axi1_awuser,
      fpd_cci_noc_axi1_awready => fpd_cci_noc_axi1_awready,
      fpd_cci_noc_axi1_wdata => fpd_cci_noc_axi1_wdata,
      fpd_cci_noc_axi1_wstrb => fpd_cci_noc_axi1_wstrb,
      fpd_cci_noc_axi1_wuser => fpd_cci_noc_axi1_wuser,
      fpd_cci_noc_axi1_wlast => fpd_cci_noc_axi1_wlast,
      fpd_cci_noc_axi1_wvalid => fpd_cci_noc_axi1_wvalid,
      fpd_cci_noc_axi1_wready => fpd_cci_noc_axi1_wready,
      fpd_cci_noc_axi1_bid => fpd_cci_noc_axi1_bid,
      fpd_cci_noc_axi1_bresp => fpd_cci_noc_axi1_bresp,
      fpd_cci_noc_axi1_bvalid => fpd_cci_noc_axi1_bvalid,
      fpd_cci_noc_axi1_bready => fpd_cci_noc_axi1_bready,
      fpd_cci_noc_axi1_arid => fpd_cci_noc_axi1_arid,
      fpd_cci_noc_axi1_araddr => fpd_cci_noc_axi1_araddr,
      fpd_cci_noc_axi1_arlen => fpd_cci_noc_axi1_arlen,
      fpd_cci_noc_axi1_arsize => fpd_cci_noc_axi1_arsize,
      fpd_cci_noc_axi1_arburst => fpd_cci_noc_axi1_arburst,
      fpd_cci_noc_axi1_arlock => fpd_cci_noc_axi1_arlock,
      fpd_cci_noc_axi1_arcache => fpd_cci_noc_axi1_arcache,
      fpd_cci_noc_axi1_arprot => fpd_cci_noc_axi1_arprot,
      fpd_cci_noc_axi1_arvalid => fpd_cci_noc_axi1_arvalid,
      fpd_cci_noc_axi1_aruser => fpd_cci_noc_axi1_aruser,
      fpd_cci_noc_axi1_arready => fpd_cci_noc_axi1_arready,
      fpd_cci_noc_axi1_rid => fpd_cci_noc_axi1_rid,
      fpd_cci_noc_axi1_rdata => fpd_cci_noc_axi1_rdata,
      fpd_cci_noc_axi1_rresp => fpd_cci_noc_axi1_rresp,
      fpd_cci_noc_axi1_rlast => fpd_cci_noc_axi1_rlast,
      fpd_cci_noc_axi1_rvalid => fpd_cci_noc_axi1_rvalid,
      fpd_cci_noc_axi1_rready => fpd_cci_noc_axi1_rready,
      fpd_cci_noc_axi1_awqos => fpd_cci_noc_axi1_awqos,
      fpd_cci_noc_axi1_arqos => fpd_cci_noc_axi1_arqos,
      fpd_cci_noc_axi2_clk => fpd_cci_noc_axi2_clk,
      fpd_cci_noc_axi2_awid => fpd_cci_noc_axi2_awid,
      fpd_cci_noc_axi2_awaddr => fpd_cci_noc_axi2_awaddr,
      fpd_cci_noc_axi2_awlen => fpd_cci_noc_axi2_awlen,
      fpd_cci_noc_axi2_awsize => fpd_cci_noc_axi2_awsize,
      fpd_cci_noc_axi2_awburst => fpd_cci_noc_axi2_awburst,
      fpd_cci_noc_axi2_awlock => fpd_cci_noc_axi2_awlock,
      fpd_cci_noc_axi2_awcache => fpd_cci_noc_axi2_awcache,
      fpd_cci_noc_axi2_awprot => fpd_cci_noc_axi2_awprot,
      fpd_cci_noc_axi2_awvalid => fpd_cci_noc_axi2_awvalid,
      fpd_cci_noc_axi2_awuser => fpd_cci_noc_axi2_awuser,
      fpd_cci_noc_axi2_awready => fpd_cci_noc_axi2_awready,
      fpd_cci_noc_axi2_wdata => fpd_cci_noc_axi2_wdata,
      fpd_cci_noc_axi2_wstrb => fpd_cci_noc_axi2_wstrb,
      fpd_cci_noc_axi2_wuser => fpd_cci_noc_axi2_wuser,
      fpd_cci_noc_axi2_wlast => fpd_cci_noc_axi2_wlast,
      fpd_cci_noc_axi2_wvalid => fpd_cci_noc_axi2_wvalid,
      fpd_cci_noc_axi2_wready => fpd_cci_noc_axi2_wready,
      fpd_cci_noc_axi2_bid => fpd_cci_noc_axi2_bid,
      fpd_cci_noc_axi2_bresp => fpd_cci_noc_axi2_bresp,
      fpd_cci_noc_axi2_bvalid => fpd_cci_noc_axi2_bvalid,
      fpd_cci_noc_axi2_bready => fpd_cci_noc_axi2_bready,
      fpd_cci_noc_axi2_arid => fpd_cci_noc_axi2_arid,
      fpd_cci_noc_axi2_araddr => fpd_cci_noc_axi2_araddr,
      fpd_cci_noc_axi2_arlen => fpd_cci_noc_axi2_arlen,
      fpd_cci_noc_axi2_arsize => fpd_cci_noc_axi2_arsize,
      fpd_cci_noc_axi2_arburst => fpd_cci_noc_axi2_arburst,
      fpd_cci_noc_axi2_arlock => fpd_cci_noc_axi2_arlock,
      fpd_cci_noc_axi2_arcache => fpd_cci_noc_axi2_arcache,
      fpd_cci_noc_axi2_arprot => fpd_cci_noc_axi2_arprot,
      fpd_cci_noc_axi2_arvalid => fpd_cci_noc_axi2_arvalid,
      fpd_cci_noc_axi2_aruser => fpd_cci_noc_axi2_aruser,
      fpd_cci_noc_axi2_arready => fpd_cci_noc_axi2_arready,
      fpd_cci_noc_axi2_rid => fpd_cci_noc_axi2_rid,
      fpd_cci_noc_axi2_rdata => fpd_cci_noc_axi2_rdata,
      fpd_cci_noc_axi2_rresp => fpd_cci_noc_axi2_rresp,
      fpd_cci_noc_axi2_rlast => fpd_cci_noc_axi2_rlast,
      fpd_cci_noc_axi2_rvalid => fpd_cci_noc_axi2_rvalid,
      fpd_cci_noc_axi2_rready => fpd_cci_noc_axi2_rready,
      fpd_cci_noc_axi2_awqos => fpd_cci_noc_axi2_awqos,
      fpd_cci_noc_axi2_arqos => fpd_cci_noc_axi2_arqos,
      fpd_cci_noc_axi3_clk => fpd_cci_noc_axi3_clk,
      fpd_cci_noc_axi3_awid => fpd_cci_noc_axi3_awid,
      fpd_cci_noc_axi3_awaddr => fpd_cci_noc_axi3_awaddr,
      fpd_cci_noc_axi3_awlen => fpd_cci_noc_axi3_awlen,
      fpd_cci_noc_axi3_awsize => fpd_cci_noc_axi3_awsize,
      fpd_cci_noc_axi3_awburst => fpd_cci_noc_axi3_awburst,
      fpd_cci_noc_axi3_awlock => fpd_cci_noc_axi3_awlock,
      fpd_cci_noc_axi3_awcache => fpd_cci_noc_axi3_awcache,
      fpd_cci_noc_axi3_awprot => fpd_cci_noc_axi3_awprot,
      fpd_cci_noc_axi3_awvalid => fpd_cci_noc_axi3_awvalid,
      fpd_cci_noc_axi3_awuser => fpd_cci_noc_axi3_awuser,
      fpd_cci_noc_axi3_awready => fpd_cci_noc_axi3_awready,
      fpd_cci_noc_axi3_wdata => fpd_cci_noc_axi3_wdata,
      fpd_cci_noc_axi3_wstrb => fpd_cci_noc_axi3_wstrb,
      fpd_cci_noc_axi3_wuser => fpd_cci_noc_axi3_wuser,
      fpd_cci_noc_axi3_wlast => fpd_cci_noc_axi3_wlast,
      fpd_cci_noc_axi3_wvalid => fpd_cci_noc_axi3_wvalid,
      fpd_cci_noc_axi3_wready => fpd_cci_noc_axi3_wready,
      fpd_cci_noc_axi3_bid => fpd_cci_noc_axi3_bid,
      fpd_cci_noc_axi3_bresp => fpd_cci_noc_axi3_bresp,
      fpd_cci_noc_axi3_bvalid => fpd_cci_noc_axi3_bvalid,
      fpd_cci_noc_axi3_bready => fpd_cci_noc_axi3_bready,
      fpd_cci_noc_axi3_arid => fpd_cci_noc_axi3_arid,
      fpd_cci_noc_axi3_araddr => fpd_cci_noc_axi3_araddr,
      fpd_cci_noc_axi3_arlen => fpd_cci_noc_axi3_arlen,
      fpd_cci_noc_axi3_arsize => fpd_cci_noc_axi3_arsize,
      fpd_cci_noc_axi3_arburst => fpd_cci_noc_axi3_arburst,
      fpd_cci_noc_axi3_arlock => fpd_cci_noc_axi3_arlock,
      fpd_cci_noc_axi3_arcache => fpd_cci_noc_axi3_arcache,
      fpd_cci_noc_axi3_arprot => fpd_cci_noc_axi3_arprot,
      fpd_cci_noc_axi3_arvalid => fpd_cci_noc_axi3_arvalid,
      fpd_cci_noc_axi3_aruser => fpd_cci_noc_axi3_aruser,
      fpd_cci_noc_axi3_arready => fpd_cci_noc_axi3_arready,
      fpd_cci_noc_axi3_rid => fpd_cci_noc_axi3_rid,
      fpd_cci_noc_axi3_rdata => fpd_cci_noc_axi3_rdata,
      fpd_cci_noc_axi3_rresp => fpd_cci_noc_axi3_rresp,
      fpd_cci_noc_axi3_rlast => fpd_cci_noc_axi3_rlast,
      fpd_cci_noc_axi3_rvalid => fpd_cci_noc_axi3_rvalid,
      fpd_cci_noc_axi3_rready => fpd_cci_noc_axi3_rready,
      fpd_cci_noc_axi3_awqos => fpd_cci_noc_axi3_awqos,
      fpd_cci_noc_axi3_arqos => fpd_cci_noc_axi3_arqos,
      lpd_axi_noc_clk => lpd_axi_noc_clk,
      lpd_axi_noc_axi0_awid => lpd_axi_noc_axi0_awid,
      lpd_axi_noc_axi0_awaddr => lpd_axi_noc_axi0_awaddr,
      lpd_axi_noc_axi0_awlen => lpd_axi_noc_axi0_awlen,
      lpd_axi_noc_axi0_awsize => lpd_axi_noc_axi0_awsize,
      lpd_axi_noc_axi0_awburst => lpd_axi_noc_axi0_awburst,
      lpd_axi_noc_axi0_awlock => lpd_axi_noc_axi0_awlock,
      lpd_axi_noc_axi0_awcache => lpd_axi_noc_axi0_awcache,
      lpd_axi_noc_axi0_awprot => lpd_axi_noc_axi0_awprot,
      lpd_axi_noc_axi0_awvalid => lpd_axi_noc_axi0_awvalid,
      lpd_axi_noc_axi0_awuser => lpd_axi_noc_axi0_awuser,
      lpd_axi_noc_axi0_awready => lpd_axi_noc_axi0_awready,
      lpd_axi_noc_axi0_wdata => lpd_axi_noc_axi0_wdata,
      lpd_axi_noc_axi0_wstrb => lpd_axi_noc_axi0_wstrb,
      lpd_axi_noc_axi0_wlast => lpd_axi_noc_axi0_wlast,
      lpd_axi_noc_axi0_wvalid => lpd_axi_noc_axi0_wvalid,
      lpd_axi_noc_axi0_wready => lpd_axi_noc_axi0_wready,
      lpd_axi_noc_axi0_bid => lpd_axi_noc_axi0_bid,
      lpd_axi_noc_axi0_bresp => lpd_axi_noc_axi0_bresp,
      lpd_axi_noc_axi0_bvalid => lpd_axi_noc_axi0_bvalid,
      lpd_axi_noc_axi0_bready => lpd_axi_noc_axi0_bready,
      lpd_axi_noc_axi0_arid => lpd_axi_noc_axi0_arid,
      lpd_axi_noc_axi0_araddr => lpd_axi_noc_axi0_araddr,
      lpd_axi_noc_axi0_arlen => lpd_axi_noc_axi0_arlen,
      lpd_axi_noc_axi0_arsize => lpd_axi_noc_axi0_arsize,
      lpd_axi_noc_axi0_arburst => lpd_axi_noc_axi0_arburst,
      lpd_axi_noc_axi0_arlock => lpd_axi_noc_axi0_arlock,
      lpd_axi_noc_axi0_arcache => lpd_axi_noc_axi0_arcache,
      lpd_axi_noc_axi0_arprot => lpd_axi_noc_axi0_arprot,
      lpd_axi_noc_axi0_arvalid => lpd_axi_noc_axi0_arvalid,
      lpd_axi_noc_axi0_aruser => lpd_axi_noc_axi0_aruser,
      lpd_axi_noc_axi0_arready => lpd_axi_noc_axi0_arready,
      lpd_axi_noc_axi0_rid => lpd_axi_noc_axi0_rid,
      lpd_axi_noc_axi0_rdata => lpd_axi_noc_axi0_rdata,
      lpd_axi_noc_axi0_rresp => lpd_axi_noc_axi0_rresp,
      lpd_axi_noc_axi0_rlast => lpd_axi_noc_axi0_rlast,
      lpd_axi_noc_axi0_rvalid => lpd_axi_noc_axi0_rvalid,
      lpd_axi_noc_axi0_rready => lpd_axi_noc_axi0_rready,
      lpd_axi_noc_axi0_awqos => lpd_axi_noc_axi0_awqos,
      lpd_axi_noc_axi0_arqos => lpd_axi_noc_axi0_arqos,
      pmc_axi_noc_axi0_clk => pmc_axi_noc_axi0_clk,
      pmc_noc_axi0_araddr => pmc_noc_axi0_araddr,
      pmc_noc_axi0_arburst => pmc_noc_axi0_arburst,
      pmc_noc_axi0_arcache => pmc_noc_axi0_arcache,
      pmc_noc_axi0_arid => pmc_noc_axi0_arid,
      pmc_noc_axi0_arlen => pmc_noc_axi0_arlen,
      pmc_noc_axi0_arlock => pmc_noc_axi0_arlock,
      pmc_noc_axi0_arprot => pmc_noc_axi0_arprot,
      pmc_noc_axi0_arqos => pmc_noc_axi0_arqos,
      pmc_noc_axi0_arregion => pmc_noc_axi0_arregion,
      pmc_noc_axi0_arsize => pmc_noc_axi0_arsize,
      pmc_noc_axi0_aruser => pmc_noc_axi0_aruser,
      pmc_noc_axi0_arvalid => pmc_noc_axi0_arvalid,
      pmc_noc_axi0_awaddr => pmc_noc_axi0_awaddr,
      pmc_noc_axi0_awburst => pmc_noc_axi0_awburst,
      pmc_noc_axi0_awcache => pmc_noc_axi0_awcache,
      pmc_noc_axi0_awid => pmc_noc_axi0_awid,
      pmc_noc_axi0_awlen => pmc_noc_axi0_awlen,
      pmc_noc_axi0_awlock => pmc_noc_axi0_awlock,
      pmc_noc_axi0_awprot => pmc_noc_axi0_awprot,
      pmc_noc_axi0_awqos => pmc_noc_axi0_awqos,
      pmc_noc_axi0_awregion => pmc_noc_axi0_awregion,
      pmc_noc_axi0_awsize => pmc_noc_axi0_awsize,
      pmc_noc_axi0_awuser => pmc_noc_axi0_awuser,
      pmc_noc_axi0_awvalid => pmc_noc_axi0_awvalid,
      pmc_noc_axi0_bready => pmc_noc_axi0_bready,
      pmc_noc_axi0_rready => pmc_noc_axi0_rready,
      pmc_noc_axi0_wdata => pmc_noc_axi0_wdata,
      pmc_noc_axi0_wid => pmc_noc_axi0_wid,
      pmc_noc_axi0_wlast => pmc_noc_axi0_wlast,
      pmc_noc_axi0_wstrb => pmc_noc_axi0_wstrb,
      pmc_noc_axi0_wuser => pmc_noc_axi0_wuser,
      pmc_noc_axi0_wvalid => pmc_noc_axi0_wvalid,
      pmc_noc_axi0_arready => pmc_noc_axi0_arready,
      pmc_noc_axi0_awready => pmc_noc_axi0_awready,
      pmc_noc_axi0_bid => pmc_noc_axi0_bid,
      pmc_noc_axi0_bresp => pmc_noc_axi0_bresp,
      pmc_noc_axi0_buser => pmc_noc_axi0_buser,
      pmc_noc_axi0_bvalid => pmc_noc_axi0_bvalid,
      pmc_noc_axi0_rdata => pmc_noc_axi0_rdata,
      pmc_noc_axi0_rid => pmc_noc_axi0_rid,
      pmc_noc_axi0_rlast => pmc_noc_axi0_rlast,
      pmc_noc_axi0_rresp => pmc_noc_axi0_rresp,
      pmc_noc_axi0_ruser => pmc_noc_axi0_ruser,
      pmc_noc_axi0_rvalid => pmc_noc_axi0_rvalid,
      pmc_noc_axi0_wready => pmc_noc_axi0_wready,
      gem0_tsu_timer_cnt => gem0_tsu_timer_cnt,
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
END bd_70da_pspmc_0_0_arch;
