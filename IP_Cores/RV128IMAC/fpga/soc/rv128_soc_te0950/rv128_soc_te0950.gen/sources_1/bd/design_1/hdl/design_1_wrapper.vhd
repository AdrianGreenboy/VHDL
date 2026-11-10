--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
--Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2025.2.1 (lin64) Build 6403652 Thu Mar 19 13:47:00 MDT 2026
--Date        : Tue Nov 10 08:27:37 2026
--Host        : adrian running 64-bit Ubuntu 24.04.5 LTS
--Command     : generate_target design_1_wrapper.bd
--Design      : design_1_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity design_1_wrapper is
  port (
    ddr4_bank0_act_n : out STD_LOGIC;
    ddr4_bank0_adr : out STD_LOGIC_VECTOR ( 16 downto 0 );
    ddr4_bank0_ba : out STD_LOGIC_VECTOR ( 1 downto 0 );
    ddr4_bank0_bg : out STD_LOGIC;
    ddr4_bank0_ck_c : out STD_LOGIC;
    ddr4_bank0_ck_t : out STD_LOGIC;
    ddr4_bank0_cke : out STD_LOGIC;
    ddr4_bank0_cs_n : out STD_LOGIC;
    ddr4_bank0_dm_n : inout STD_LOGIC_VECTOR ( 7 downto 0 );
    ddr4_bank0_dq : inout STD_LOGIC_VECTOR ( 63 downto 0 );
    ddr4_bank0_dqs_c : inout STD_LOGIC_VECTOR ( 7 downto 0 );
    ddr4_bank0_dqs_t : inout STD_LOGIC_VECTOR ( 7 downto 0 );
    ddr4_bank0_odt : out STD_LOGIC;
    ddr4_bank0_reset_n : out STD_LOGIC;
    ddr4_bank0_sys_clk_clk_n : in STD_LOGIC;
    ddr4_bank0_sys_clk_clk_p : in STD_LOGIC
  );
end design_1_wrapper;

architecture STRUCTURE of design_1_wrapper is
  component design_1 is
  port (
    ddr4_bank0_dq : inout STD_LOGIC_VECTOR ( 63 downto 0 );
    ddr4_bank0_dqs_t : inout STD_LOGIC_VECTOR ( 7 downto 0 );
    ddr4_bank0_dqs_c : inout STD_LOGIC_VECTOR ( 7 downto 0 );
    ddr4_bank0_adr : out STD_LOGIC_VECTOR ( 16 downto 0 );
    ddr4_bank0_ba : out STD_LOGIC_VECTOR ( 1 downto 0 );
    ddr4_bank0_bg : out STD_LOGIC;
    ddr4_bank0_act_n : out STD_LOGIC;
    ddr4_bank0_reset_n : out STD_LOGIC;
    ddr4_bank0_ck_t : out STD_LOGIC;
    ddr4_bank0_ck_c : out STD_LOGIC;
    ddr4_bank0_cke : out STD_LOGIC;
    ddr4_bank0_cs_n : out STD_LOGIC;
    ddr4_bank0_dm_n : inout STD_LOGIC_VECTOR ( 7 downto 0 );
    ddr4_bank0_odt : out STD_LOGIC;
    ddr4_bank0_sys_clk_clk_p : in STD_LOGIC;
    ddr4_bank0_sys_clk_clk_n : in STD_LOGIC
  );
  end component design_1;
begin
design_1_i: component design_1
     port map (
      ddr4_bank0_act_n => ddr4_bank0_act_n,
      ddr4_bank0_adr(16 downto 0) => ddr4_bank0_adr(16 downto 0),
      ddr4_bank0_ba(1 downto 0) => ddr4_bank0_ba(1 downto 0),
      ddr4_bank0_bg => ddr4_bank0_bg,
      ddr4_bank0_ck_c => ddr4_bank0_ck_c,
      ddr4_bank0_ck_t => ddr4_bank0_ck_t,
      ddr4_bank0_cke => ddr4_bank0_cke,
      ddr4_bank0_cs_n => ddr4_bank0_cs_n,
      ddr4_bank0_dm_n(7 downto 0) => ddr4_bank0_dm_n(7 downto 0),
      ddr4_bank0_dq(63 downto 0) => ddr4_bank0_dq(63 downto 0),
      ddr4_bank0_dqs_c(7 downto 0) => ddr4_bank0_dqs_c(7 downto 0),
      ddr4_bank0_dqs_t(7 downto 0) => ddr4_bank0_dqs_t(7 downto 0),
      ddr4_bank0_odt => ddr4_bank0_odt,
      ddr4_bank0_reset_n => ddr4_bank0_reset_n,
      ddr4_bank0_sys_clk_clk_n => ddr4_bank0_sys_clk_clk_n,
      ddr4_bank0_sys_clk_clk_p => ddr4_bank0_sys_clk_clk_p
    );
end STRUCTURE;
