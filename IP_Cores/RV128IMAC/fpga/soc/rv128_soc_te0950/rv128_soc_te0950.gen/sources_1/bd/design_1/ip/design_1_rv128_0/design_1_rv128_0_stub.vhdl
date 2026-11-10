-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.2.1 (lin64) Build 6403652 Thu Mar 19 13:47:00 MDT 2026
-- Date        : Tue Nov 10 08:29:08 2026
-- Host        : adrian running 64-bit Ubuntu 24.04.5 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /home/adrian/vhdl_repo/IP_Cores/RV128IMAC/fpga/soc/rv128_soc_te0950/rv128_soc_te0950.gen/sources_1/bd/design_1/ip/design_1_rv128_0/design_1_rv128_0_stub.vhdl
-- Design      : design_1_rv128_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcve2302-sfva784-1LP-e-S
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity design_1_rv128_0 is
  Port ( 
    clk : in STD_LOGIC;
    aresetn : in STD_LOGIC;
    m_axi_dram_awid : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_dram_awaddr : out STD_LOGIC_VECTOR ( 63 downto 0 );
    m_axi_dram_awlen : out STD_LOGIC_VECTOR ( 7 downto 0 );
    m_axi_dram_awsize : out STD_LOGIC_VECTOR ( 2 downto 0 );
    m_axi_dram_awburst : out STD_LOGIC_VECTOR ( 1 downto 0 );
    m_axi_dram_awcache : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_dram_awprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
    m_axi_dram_awvalid : out STD_LOGIC;
    m_axi_dram_awready : in STD_LOGIC;
    m_axi_dram_wdata : out STD_LOGIC_VECTOR ( 127 downto 0 );
    m_axi_dram_wstrb : out STD_LOGIC_VECTOR ( 15 downto 0 );
    m_axi_dram_wlast : out STD_LOGIC;
    m_axi_dram_wvalid : out STD_LOGIC;
    m_axi_dram_wready : in STD_LOGIC;
    m_axi_dram_bid : in STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_dram_bresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    m_axi_dram_bvalid : in STD_LOGIC;
    m_axi_dram_bready : out STD_LOGIC;
    m_axi_dram_arid : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_dram_araddr : out STD_LOGIC_VECTOR ( 63 downto 0 );
    m_axi_dram_arlen : out STD_LOGIC_VECTOR ( 7 downto 0 );
    m_axi_dram_arsize : out STD_LOGIC_VECTOR ( 2 downto 0 );
    m_axi_dram_arburst : out STD_LOGIC_VECTOR ( 1 downto 0 );
    m_axi_dram_arcache : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_dram_arprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
    m_axi_dram_arvalid : out STD_LOGIC;
    m_axi_dram_arready : in STD_LOGIC;
    m_axi_dram_rid : in STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_dram_rdata : in STD_LOGIC_VECTOR ( 127 downto 0 );
    m_axi_dram_rresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    m_axi_dram_rlast : in STD_LOGIC;
    m_axi_dram_rvalid : in STD_LOGIC;
    m_axi_dram_rready : out STD_LOGIC;
    s_axi_ctrl_awaddr : in STD_LOGIC_VECTOR ( 15 downto 0 );
    s_axi_ctrl_awvalid : in STD_LOGIC;
    s_axi_ctrl_awready : out STD_LOGIC;
    s_axi_ctrl_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_ctrl_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axi_ctrl_wvalid : in STD_LOGIC;
    s_axi_ctrl_wready : out STD_LOGIC;
    s_axi_ctrl_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axi_ctrl_bvalid : out STD_LOGIC;
    s_axi_ctrl_bready : in STD_LOGIC;
    s_axi_ctrl_araddr : in STD_LOGIC_VECTOR ( 15 downto 0 );
    s_axi_ctrl_arvalid : in STD_LOGIC;
    s_axi_ctrl_arready : out STD_LOGIC;
    s_axi_ctrl_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_ctrl_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axi_ctrl_rvalid : out STD_LOGIC;
    s_axi_ctrl_rready : in STD_LOGIC;
    mm_sel : out STD_LOGIC_VECTOR ( 15 downto 0 );
    mm_req : out STD_LOGIC;
    mm_addr : out STD_LOGIC_VECTOR ( 15 downto 0 );
    mm_wdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    mm_wstrb : out STD_LOGIC_VECTOR ( 3 downto 0 );
    mm_rdata : in STD_LOGIC_VECTOR ( 511 downto 0 );
    irq_ip : in STD_LOGIC_VECTOR ( 15 downto 0 );
    soc_rst : out STD_LOGIC
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of design_1_rv128_0 : entity is "design_1_rv128_0,rv128_soc_wrap,{}";
  attribute core_generation_info : string;
  attribute core_generation_info of design_1_rv128_0 : entity is "design_1_rv128_0,rv128_soc_wrap,{x_ipProduct=Vivado 2025.2.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=rv128_soc_wrap,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,TICK_DIV=50,DRAM_PHYS=0x0000000070000000,DRAM_MASK=0x0000000007FFFFFF}";
  attribute downgradeipidentifiedwarnings : string;
  attribute downgradeipidentifiedwarnings of design_1_rv128_0 : entity is "yes";
  attribute ip_definition_source : string;
  attribute ip_definition_source of design_1_rv128_0 : entity is "module_ref";
end design_1_rv128_0;

architecture stub of design_1_rv128_0 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "clk,aresetn,m_axi_dram_awid[3:0],m_axi_dram_awaddr[63:0],m_axi_dram_awlen[7:0],m_axi_dram_awsize[2:0],m_axi_dram_awburst[1:0],m_axi_dram_awcache[3:0],m_axi_dram_awprot[2:0],m_axi_dram_awvalid,m_axi_dram_awready,m_axi_dram_wdata[127:0],m_axi_dram_wstrb[15:0],m_axi_dram_wlast,m_axi_dram_wvalid,m_axi_dram_wready,m_axi_dram_bid[3:0],m_axi_dram_bresp[1:0],m_axi_dram_bvalid,m_axi_dram_bready,m_axi_dram_arid[3:0],m_axi_dram_araddr[63:0],m_axi_dram_arlen[7:0],m_axi_dram_arsize[2:0],m_axi_dram_arburst[1:0],m_axi_dram_arcache[3:0],m_axi_dram_arprot[2:0],m_axi_dram_arvalid,m_axi_dram_arready,m_axi_dram_rid[3:0],m_axi_dram_rdata[127:0],m_axi_dram_rresp[1:0],m_axi_dram_rlast,m_axi_dram_rvalid,m_axi_dram_rready,s_axi_ctrl_awaddr[15:0],s_axi_ctrl_awvalid,s_axi_ctrl_awready,s_axi_ctrl_wdata[31:0],s_axi_ctrl_wstrb[3:0],s_axi_ctrl_wvalid,s_axi_ctrl_wready,s_axi_ctrl_bresp[1:0],s_axi_ctrl_bvalid,s_axi_ctrl_bready,s_axi_ctrl_araddr[15:0],s_axi_ctrl_arvalid,s_axi_ctrl_arready,s_axi_ctrl_rdata[31:0],s_axi_ctrl_rresp[1:0],s_axi_ctrl_rvalid,s_axi_ctrl_rready,mm_sel[15:0],mm_req,mm_addr[15:0],mm_wdata[31:0],mm_wstrb[3:0],mm_rdata[511:0],irq_ip[15:0],soc_rst";
  attribute x_interface_info : string;
  attribute x_interface_info of clk : signal is "xilinx.com:signal:clock:1.0 clk CLK";
  attribute x_interface_mode : string;
  attribute x_interface_mode of clk : signal is "slave clk";
  attribute x_interface_parameter : string;
  attribute x_interface_parameter of clk : signal is "ASSOCIATED_BUSIF m_axi_dram:s_axi_ctrl, ASSOCIATED_RESET aresetn";
  attribute x_interface_info of aresetn : signal is "xilinx.com:signal:reset:1.0 aresetn RST";
  attribute x_interface_mode of aresetn : signal is "slave aresetn";
  attribute x_interface_parameter of aresetn : signal is "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  attribute x_interface_info of m_axi_dram_awid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWID";
  attribute x_interface_mode of m_axi_dram_awid : signal is "master m_axi_dram";
  attribute x_interface_parameter of m_axi_dram_awid : signal is "XIL_INTERFACENAME m_axi_dram, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 50000000, ID_WIDTH 4, ADDR_WIDTH 64, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute x_interface_info of m_axi_dram_awaddr : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWADDR";
  attribute x_interface_info of m_axi_dram_awlen : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWLEN";
  attribute x_interface_info of m_axi_dram_awsize : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWSIZE";
  attribute x_interface_info of m_axi_dram_awburst : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWBURST";
  attribute x_interface_info of m_axi_dram_awcache : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWCACHE";
  attribute x_interface_info of m_axi_dram_awprot : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWPROT";
  attribute x_interface_info of m_axi_dram_awvalid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWVALID";
  attribute x_interface_info of m_axi_dram_awready : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram AWREADY";
  attribute x_interface_info of m_axi_dram_wdata : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram WDATA";
  attribute x_interface_info of m_axi_dram_wstrb : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram WSTRB";
  attribute x_interface_info of m_axi_dram_wlast : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram WLAST";
  attribute x_interface_info of m_axi_dram_wvalid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram WVALID";
  attribute x_interface_info of m_axi_dram_wready : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram WREADY";
  attribute x_interface_info of m_axi_dram_bid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram BID";
  attribute x_interface_info of m_axi_dram_bresp : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram BRESP";
  attribute x_interface_info of m_axi_dram_bvalid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram BVALID";
  attribute x_interface_info of m_axi_dram_bready : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram BREADY";
  attribute x_interface_info of m_axi_dram_arid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARID";
  attribute x_interface_info of m_axi_dram_araddr : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARADDR";
  attribute x_interface_info of m_axi_dram_arlen : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARLEN";
  attribute x_interface_info of m_axi_dram_arsize : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARSIZE";
  attribute x_interface_info of m_axi_dram_arburst : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARBURST";
  attribute x_interface_info of m_axi_dram_arcache : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARCACHE";
  attribute x_interface_info of m_axi_dram_arprot : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARPROT";
  attribute x_interface_info of m_axi_dram_arvalid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARVALID";
  attribute x_interface_info of m_axi_dram_arready : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram ARREADY";
  attribute x_interface_info of m_axi_dram_rid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram RID";
  attribute x_interface_info of m_axi_dram_rdata : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram RDATA";
  attribute x_interface_info of m_axi_dram_rresp : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram RRESP";
  attribute x_interface_info of m_axi_dram_rlast : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram RLAST";
  attribute x_interface_info of m_axi_dram_rvalid : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram RVALID";
  attribute x_interface_info of m_axi_dram_rready : signal is "xilinx.com:interface:aximm:1.0 m_axi_dram RREADY";
  attribute x_interface_info of s_axi_ctrl_awaddr : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWADDR";
  attribute x_interface_mode of s_axi_ctrl_awaddr : signal is "slave s_axi_ctrl";
  attribute x_interface_parameter of s_axi_ctrl_awaddr : signal is "XIL_INTERFACENAME s_axi_ctrl, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 50000000, ID_WIDTH 0, ADDR_WIDTH 16, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute x_interface_info of s_axi_ctrl_awvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWVALID";
  attribute x_interface_info of s_axi_ctrl_awready : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWREADY";
  attribute x_interface_info of s_axi_ctrl_wdata : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl WDATA";
  attribute x_interface_info of s_axi_ctrl_wstrb : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl WSTRB";
  attribute x_interface_info of s_axi_ctrl_wvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl WVALID";
  attribute x_interface_info of s_axi_ctrl_wready : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl WREADY";
  attribute x_interface_info of s_axi_ctrl_bresp : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl BRESP";
  attribute x_interface_info of s_axi_ctrl_bvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl BVALID";
  attribute x_interface_info of s_axi_ctrl_bready : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl BREADY";
  attribute x_interface_info of s_axi_ctrl_araddr : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARADDR";
  attribute x_interface_info of s_axi_ctrl_arvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARVALID";
  attribute x_interface_info of s_axi_ctrl_arready : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARREADY";
  attribute x_interface_info of s_axi_ctrl_rdata : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl RDATA";
  attribute x_interface_info of s_axi_ctrl_rresp : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl RRESP";
  attribute x_interface_info of s_axi_ctrl_rvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl RVALID";
  attribute x_interface_info of s_axi_ctrl_rready : signal is "xilinx.com:interface:aximm:1.0 s_axi_ctrl RREADY";
  attribute x_interface_info of soc_rst : signal is "xilinx.com:signal:reset:1.0 soc_rst RST";
  attribute x_interface_mode of soc_rst : signal is "master soc_rst";
  attribute x_interface_parameter of soc_rst : signal is "XIL_INTERFACENAME soc_rst, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  attribute x_core_info : string;
  attribute x_core_info of stub : architecture is "rv128_soc_wrap,Vivado 2025.2.1";
begin
end;
