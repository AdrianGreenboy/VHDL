// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2.1 (lin64) Build 6403652 Thu Mar 19 13:47:00 MDT 2026
// Date        : Wed Nov 11 17:04:01 2026
// Host        : adrian running 64-bit Ubuntu 24.04.5 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/adrian/vhdl_repo/IP_Cores/RV128IMAC/fpga/soc/rv128_soc_te0950/rv128_soc_te0950.gen/sources_1/bd/design_1/ip/design_1_rv128_0/design_1_rv128_0_stub.v
// Design      : design_1_rv128_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xcve2302-sfva784-1LP-e-S
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "design_1_rv128_0,rv128_soc_wrap,{}" *) (* core_generation_info = "design_1_rv128_0,rv128_soc_wrap,{x_ipProduct=Vivado 2025.2.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=rv128_soc_wrap,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,TICK_DIV=50,DRAM_PHYS=0x0000000070000000,DRAM_MASK=0x0000000007FFFFFF}" *) (* downgradeipidentifiedwarnings = "yes" *) 
(* ip_definition_source = "module_ref" *) (* x_core_info = "rv128_soc_wrap,Vivado 2025.2.1" *) 
module design_1_rv128_0(clk, aresetn, m_axi_dram_awid, 
  m_axi_dram_awaddr, m_axi_dram_awlen, m_axi_dram_awsize, m_axi_dram_awburst, 
  m_axi_dram_awcache, m_axi_dram_awprot, m_axi_dram_awvalid, m_axi_dram_awready, 
  m_axi_dram_wdata, m_axi_dram_wstrb, m_axi_dram_wlast, m_axi_dram_wvalid, 
  m_axi_dram_wready, m_axi_dram_bid, m_axi_dram_bresp, m_axi_dram_bvalid, 
  m_axi_dram_bready, m_axi_dram_arid, m_axi_dram_araddr, m_axi_dram_arlen, 
  m_axi_dram_arsize, m_axi_dram_arburst, m_axi_dram_arcache, m_axi_dram_arprot, 
  m_axi_dram_arvalid, m_axi_dram_arready, m_axi_dram_rid, m_axi_dram_rdata, 
  m_axi_dram_rresp, m_axi_dram_rlast, m_axi_dram_rvalid, m_axi_dram_rready, 
  s_axi_ctrl_awaddr, s_axi_ctrl_awvalid, s_axi_ctrl_awready, s_axi_ctrl_wdata, 
  s_axi_ctrl_wstrb, s_axi_ctrl_wvalid, s_axi_ctrl_wready, s_axi_ctrl_bresp, 
  s_axi_ctrl_bvalid, s_axi_ctrl_bready, s_axi_ctrl_araddr, s_axi_ctrl_arvalid, 
  s_axi_ctrl_arready, s_axi_ctrl_rdata, s_axi_ctrl_rresp, s_axi_ctrl_rvalid, 
  s_axi_ctrl_rready, mm_sel, mm_req, mm_addr, mm_wdata, mm_wstrb, mm_rdata, irq_ip, soc_rst)
/* synthesis syn_black_box black_box_pad_pin="aresetn,m_axi_dram_awid[3:0],m_axi_dram_awaddr[63:0],m_axi_dram_awlen[7:0],m_axi_dram_awsize[2:0],m_axi_dram_awburst[1:0],m_axi_dram_awcache[3:0],m_axi_dram_awprot[2:0],m_axi_dram_awvalid,m_axi_dram_awready,m_axi_dram_wdata[127:0],m_axi_dram_wstrb[15:0],m_axi_dram_wlast,m_axi_dram_wvalid,m_axi_dram_wready,m_axi_dram_bid[3:0],m_axi_dram_bresp[1:0],m_axi_dram_bvalid,m_axi_dram_bready,m_axi_dram_arid[3:0],m_axi_dram_araddr[63:0],m_axi_dram_arlen[7:0],m_axi_dram_arsize[2:0],m_axi_dram_arburst[1:0],m_axi_dram_arcache[3:0],m_axi_dram_arprot[2:0],m_axi_dram_arvalid,m_axi_dram_arready,m_axi_dram_rid[3:0],m_axi_dram_rdata[127:0],m_axi_dram_rresp[1:0],m_axi_dram_rlast,m_axi_dram_rvalid,m_axi_dram_rready,s_axi_ctrl_awaddr[15:0],s_axi_ctrl_awvalid,s_axi_ctrl_awready,s_axi_ctrl_wdata[31:0],s_axi_ctrl_wstrb[3:0],s_axi_ctrl_wvalid,s_axi_ctrl_wready,s_axi_ctrl_bresp[1:0],s_axi_ctrl_bvalid,s_axi_ctrl_bready,s_axi_ctrl_araddr[15:0],s_axi_ctrl_arvalid,s_axi_ctrl_arready,s_axi_ctrl_rdata[31:0],s_axi_ctrl_rresp[1:0],s_axi_ctrl_rvalid,s_axi_ctrl_rready,mm_sel[15:0],mm_req,mm_addr[15:0],mm_wdata[31:0],mm_wstrb[3:0],mm_rdata[511:0],irq_ip[15:0],soc_rst" */
/* synthesis syn_force_seq_prim="clk" */;
  (* x_interface_info = "xilinx.com:signal:clock:1.0 clk CLK" *) (* x_interface_mode = "slave clk" *) (* x_interface_parameter = "ASSOCIATED_BUSIF m_axi_dram:s_axi_ctrl, ASSOCIATED_RESET aresetn" *) input clk /* synthesis syn_isclock = 1 */;
  (* x_interface_info = "xilinx.com:signal:reset:1.0 aresetn RST" *) (* x_interface_mode = "slave aresetn" *) (* x_interface_parameter = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) input aresetn;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWID" *) (* x_interface_mode = "master m_axi_dram" *) (* x_interface_parameter = "XIL_INTERFACENAME m_axi_dram, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 50000000, ID_WIDTH 4, ADDR_WIDTH 64, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [3:0]m_axi_dram_awid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWADDR" *) output [63:0]m_axi_dram_awaddr;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWLEN" *) output [7:0]m_axi_dram_awlen;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWSIZE" *) output [2:0]m_axi_dram_awsize;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWBURST" *) output [1:0]m_axi_dram_awburst;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWCACHE" *) output [3:0]m_axi_dram_awcache;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWPROT" *) output [2:0]m_axi_dram_awprot;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWVALID" *) output m_axi_dram_awvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram AWREADY" *) input m_axi_dram_awready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram WDATA" *) output [127:0]m_axi_dram_wdata;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram WSTRB" *) output [15:0]m_axi_dram_wstrb;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram WLAST" *) output m_axi_dram_wlast;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram WVALID" *) output m_axi_dram_wvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram WREADY" *) input m_axi_dram_wready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram BID" *) input [3:0]m_axi_dram_bid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram BRESP" *) input [1:0]m_axi_dram_bresp;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram BVALID" *) input m_axi_dram_bvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram BREADY" *) output m_axi_dram_bready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARID" *) output [3:0]m_axi_dram_arid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARADDR" *) output [63:0]m_axi_dram_araddr;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARLEN" *) output [7:0]m_axi_dram_arlen;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARSIZE" *) output [2:0]m_axi_dram_arsize;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARBURST" *) output [1:0]m_axi_dram_arburst;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARCACHE" *) output [3:0]m_axi_dram_arcache;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARPROT" *) output [2:0]m_axi_dram_arprot;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARVALID" *) output m_axi_dram_arvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram ARREADY" *) input m_axi_dram_arready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram RID" *) input [3:0]m_axi_dram_rid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram RDATA" *) input [127:0]m_axi_dram_rdata;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram RRESP" *) input [1:0]m_axi_dram_rresp;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram RLAST" *) input m_axi_dram_rlast;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram RVALID" *) input m_axi_dram_rvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 m_axi_dram RREADY" *) output m_axi_dram_rready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWADDR" *) (* x_interface_mode = "slave s_axi_ctrl" *) (* x_interface_parameter = "XIL_INTERFACENAME s_axi_ctrl, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 50000000, ID_WIDTH 0, ADDR_WIDTH 16, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN bd_70da_pspmc_0_0_pl0_ref_clk, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input [15:0]s_axi_ctrl_awaddr;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWVALID" *) input s_axi_ctrl_awvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl AWREADY" *) output s_axi_ctrl_awready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl WDATA" *) input [31:0]s_axi_ctrl_wdata;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl WSTRB" *) input [3:0]s_axi_ctrl_wstrb;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl WVALID" *) input s_axi_ctrl_wvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl WREADY" *) output s_axi_ctrl_wready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl BRESP" *) output [1:0]s_axi_ctrl_bresp;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl BVALID" *) output s_axi_ctrl_bvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl BREADY" *) input s_axi_ctrl_bready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARADDR" *) input [15:0]s_axi_ctrl_araddr;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARVALID" *) input s_axi_ctrl_arvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl ARREADY" *) output s_axi_ctrl_arready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl RDATA" *) output [31:0]s_axi_ctrl_rdata;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl RRESP" *) output [1:0]s_axi_ctrl_rresp;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl RVALID" *) output s_axi_ctrl_rvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 s_axi_ctrl RREADY" *) input s_axi_ctrl_rready;
  output [15:0]mm_sel;
  output mm_req;
  output [15:0]mm_addr;
  output [31:0]mm_wdata;
  output [3:0]mm_wstrb;
  input [511:0]mm_rdata;
  input [15:0]irq_ip;
  (* x_interface_info = "xilinx.com:signal:reset:1.0 soc_rst RST" *) (* x_interface_mode = "master soc_rst" *) (* x_interface_parameter = "XIL_INTERFACENAME soc_rst, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) output soc_rst;
endmodule
