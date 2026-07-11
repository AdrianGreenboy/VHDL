-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
-- -------------------------------------------------------------------------------
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

-- MODULE VLNV: amd.com:blockdesign:bd_soc_usart:1.0

-- The following code must appear in the VHDL architecture header.

-- COMP_TAG     ------ Begin cut for COMPONENT Declaration ------
COMPONENT bd_soc_usart
  PORT (
    ddr4_bank0_dq : INOUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    ddr4_bank0_dqs_t : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    ddr4_bank0_dqs_c : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    ddr4_bank0_adr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
    ddr4_bank0_ba : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    ddr4_bank0_bg : OUT STD_LOGIC;
    ddr4_bank0_act_n : OUT STD_LOGIC;
    ddr4_bank0_reset_n : OUT STD_LOGIC;
    ddr4_bank0_ck_t : OUT STD_LOGIC;
    ddr4_bank0_ck_c : OUT STD_LOGIC;
    ddr4_bank0_cke : OUT STD_LOGIC;
    ddr4_bank0_cs_n : OUT STD_LOGIC;
    ddr4_bank0_dm_n : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    ddr4_bank0_odt : OUT STD_LOGIC;
    ddr4_bank0_sys_clk_clk_p : IN STD_LOGIC;
    ddr4_bank0_sys_clk_clk_n : IN STD_LOGIC
  );
END COMPONENT;
-- COMP_TAG_END ------  End cut for COMPONENT Declaration  ------

-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.

-- INST_TAG     ------ Begin cut for INSTANTIATION Template ------
your_instance_name : bd_soc_usart
  PORT MAP (
    ddr4_bank0_dq => ddr4_bank0_dq,
    ddr4_bank0_dqs_t => ddr4_bank0_dqs_t,
    ddr4_bank0_dqs_c => ddr4_bank0_dqs_c,
    ddr4_bank0_adr => ddr4_bank0_adr,
    ddr4_bank0_ba => ddr4_bank0_ba,
    ddr4_bank0_bg => ddr4_bank0_bg,
    ddr4_bank0_act_n => ddr4_bank0_act_n,
    ddr4_bank0_reset_n => ddr4_bank0_reset_n,
    ddr4_bank0_ck_t => ddr4_bank0_ck_t,
    ddr4_bank0_ck_c => ddr4_bank0_ck_c,
    ddr4_bank0_cke => ddr4_bank0_cke,
    ddr4_bank0_cs_n => ddr4_bank0_cs_n,
    ddr4_bank0_dm_n => ddr4_bank0_dm_n,
    ddr4_bank0_odt => ddr4_bank0_odt,
    ddr4_bank0_sys_clk_clk_p => ddr4_bank0_sys_clk_clk_p,
    ddr4_bank0_sys_clk_clk_n => ddr4_bank0_sys_clk_clk_n
  );
-- INST_TAG_END ------  End cut for INSTANTIATION Template  ------

-- You must compile the wrapper file bd_soc_usart.vhd when simulating
-- the module, bd_soc_usart. When compiling the wrapper file, be sure to
-- reference the VHDL simulation library.
