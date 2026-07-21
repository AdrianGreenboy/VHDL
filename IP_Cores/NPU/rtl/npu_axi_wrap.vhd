-- HERCOSSNUX NPU - envoltorio VHDL-93 de npu_axi_top.
--
-- Vivado NO admite VHDL-2008 como fichero top de un module reference en el
-- block design (error filemgmt 56-195). Este envoltorio es VHDL-93 puro y
-- solo instancia el diseno real, que sigue siendo VHDL-2008.
--
-- Ademas declara los atributos X_INTERFACE_INFO para que Vivado agrupe las
-- senales sueltas en las interfaces AXI4 M_AXI y S_AXI, en lugar de dejarlas
-- como pines individuales.
library ieee;
use ieee.std_logic_1164.all;

entity npu_axi_wrap is
  generic (
    G_ID_W : natural := 4
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    s_awvalid  : in  std_logic;
    s_awready  : out std_logic;
    s_awaddr   : in  std_logic_vector(31 downto 0);
    s_awlen    : in  std_logic_vector(7 downto 0);
    s_awsize   : in  std_logic_vector(2 downto 0);
    s_awburst  : in  std_logic_vector(1 downto 0);
    s_awid     : in  std_logic_vector(G_ID_W-1 downto 0);
    s_wvalid   : in  std_logic;
    s_wready   : out std_logic;
    s_wdata    : in  std_logic_vector(31 downto 0);
    s_wstrb    : in  std_logic_vector(3 downto 0);
    s_wlast    : in  std_logic;
    s_bvalid   : out std_logic;
    s_bready   : in  std_logic;
    s_bresp    : out std_logic_vector(1 downto 0);
    s_bid      : out std_logic_vector(G_ID_W-1 downto 0);
    s_arvalid  : in  std_logic;
    s_arready  : out std_logic;
    s_araddr   : in  std_logic_vector(31 downto 0);
    s_arlen    : in  std_logic_vector(7 downto 0);
    s_arsize   : in  std_logic_vector(2 downto 0);
    s_arburst  : in  std_logic_vector(1 downto 0);
    s_arid     : in  std_logic_vector(G_ID_W-1 downto 0);
    s_rvalid   : out std_logic;
    s_rready   : in  std_logic;
    s_rdata    : out std_logic_vector(31 downto 0);
    s_rresp    : out std_logic_vector(1 downto 0);
    s_rlast    : out std_logic;
    s_rid      : out std_logic_vector(G_ID_W-1 downto 0);
    m_arvalid  : out std_logic;
    m_arready  : in  std_logic;
    m_araddr   : out std_logic_vector(31 downto 0);
    m_arlen    : out std_logic_vector(7 downto 0);
    m_arsize   : out std_logic_vector(2 downto 0);
    m_arburst  : out std_logic_vector(1 downto 0);
    m_rvalid   : in  std_logic;
    m_rready   : out std_logic;
    m_rdata    : in  std_logic_vector(31 downto 0);
    m_rresp    : in  std_logic_vector(1 downto 0);
    m_rlast    : in  std_logic;
    m_awvalid  : out std_logic;
    m_awready  : in  std_logic;
    m_awaddr   : out std_logic_vector(31 downto 0);
    m_awlen    : out std_logic_vector(7 downto 0);
    m_awsize   : out std_logic_vector(2 downto 0);
    m_awburst  : out std_logic_vector(1 downto 0);
    m_wvalid   : out std_logic;
    m_wready   : in  std_logic;
    m_wdata    : out std_logic_vector(31 downto 0);
    m_wstrb    : out std_logic_vector(3 downto 0);
    m_wlast    : out std_logic;
    m_bvalid   : in  std_logic;
    m_bready   : out std_logic;
    m_bresp    : in  std_logic_vector(1 downto 0)
  );

  attribute X_INTERFACE_INFO : string;
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_INFO of s_awvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWVALID";
  attribute X_INTERFACE_INFO of s_awready : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWREADY";
  attribute X_INTERFACE_INFO of s_awaddr : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWADDR";
  attribute X_INTERFACE_INFO of s_awlen : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWLEN";
  attribute X_INTERFACE_INFO of s_awsize : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWSIZE";
  attribute X_INTERFACE_INFO of s_awburst : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWBURST";
  attribute X_INTERFACE_INFO of s_awid : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWID";
  attribute X_INTERFACE_INFO of s_wvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI WVALID";
  attribute X_INTERFACE_INFO of s_wready : signal is "xilinx.com:interface:aximm:1.0 S_AXI WREADY";
  attribute X_INTERFACE_INFO of s_wdata : signal is "xilinx.com:interface:aximm:1.0 S_AXI WDATA";
  attribute X_INTERFACE_INFO of s_wstrb : signal is "xilinx.com:interface:aximm:1.0 S_AXI WSTRB";
  attribute X_INTERFACE_INFO of s_wlast : signal is "xilinx.com:interface:aximm:1.0 S_AXI WLAST";
  attribute X_INTERFACE_INFO of s_bvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI BVALID";
  attribute X_INTERFACE_INFO of s_bready : signal is "xilinx.com:interface:aximm:1.0 S_AXI BREADY";
  attribute X_INTERFACE_INFO of s_bresp : signal is "xilinx.com:interface:aximm:1.0 S_AXI BRESP";
  attribute X_INTERFACE_INFO of s_bid : signal is "xilinx.com:interface:aximm:1.0 S_AXI BID";
  attribute X_INTERFACE_INFO of s_arvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARVALID";
  attribute X_INTERFACE_INFO of s_arready : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARREADY";
  attribute X_INTERFACE_INFO of s_araddr : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARADDR";
  attribute X_INTERFACE_INFO of s_arlen : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARLEN";
  attribute X_INTERFACE_INFO of s_arsize : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARSIZE";
  attribute X_INTERFACE_INFO of s_arburst : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARBURST";
  attribute X_INTERFACE_INFO of s_arid : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARID";
  attribute X_INTERFACE_INFO of s_rvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI RVALID";
  attribute X_INTERFACE_INFO of s_rready : signal is "xilinx.com:interface:aximm:1.0 S_AXI RREADY";
  attribute X_INTERFACE_INFO of s_rdata : signal is "xilinx.com:interface:aximm:1.0 S_AXI RDATA";
  attribute X_INTERFACE_INFO of s_rresp : signal is "xilinx.com:interface:aximm:1.0 S_AXI RRESP";
  attribute X_INTERFACE_INFO of s_rlast : signal is "xilinx.com:interface:aximm:1.0 S_AXI RLAST";
  attribute X_INTERFACE_INFO of s_rid : signal is "xilinx.com:interface:aximm:1.0 S_AXI RID";
  attribute X_INTERFACE_INFO of m_arvalid : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARVALID";
  attribute X_INTERFACE_INFO of m_arready : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARREADY";
  attribute X_INTERFACE_INFO of m_araddr : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARADDR";
  attribute X_INTERFACE_INFO of m_arlen : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARLEN";
  attribute X_INTERFACE_INFO of m_arsize : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARSIZE";
  attribute X_INTERFACE_INFO of m_arburst : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARBURST";
  attribute X_INTERFACE_INFO of m_rvalid : signal is "xilinx.com:interface:aximm:1.0 M_AXI RVALID";
  attribute X_INTERFACE_INFO of m_rready : signal is "xilinx.com:interface:aximm:1.0 M_AXI RREADY";
  attribute X_INTERFACE_INFO of m_rdata : signal is "xilinx.com:interface:aximm:1.0 M_AXI RDATA";
  attribute X_INTERFACE_INFO of m_rresp : signal is "xilinx.com:interface:aximm:1.0 M_AXI RRESP";
  attribute X_INTERFACE_INFO of m_rlast : signal is "xilinx.com:interface:aximm:1.0 M_AXI RLAST";
  attribute X_INTERFACE_INFO of m_awvalid : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWVALID";
  attribute X_INTERFACE_INFO of m_awready : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWREADY";
  attribute X_INTERFACE_INFO of m_awaddr : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWADDR";
  attribute X_INTERFACE_INFO of m_awlen : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWLEN";
  attribute X_INTERFACE_INFO of m_awsize : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWSIZE";
  attribute X_INTERFACE_INFO of m_awburst : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWBURST";
  attribute X_INTERFACE_INFO of m_wvalid : signal is "xilinx.com:interface:aximm:1.0 M_AXI WVALID";
  attribute X_INTERFACE_INFO of m_wready : signal is "xilinx.com:interface:aximm:1.0 M_AXI WREADY";
  attribute X_INTERFACE_INFO of m_wdata : signal is "xilinx.com:interface:aximm:1.0 M_AXI WDATA";
  attribute X_INTERFACE_INFO of m_wstrb : signal is "xilinx.com:interface:aximm:1.0 M_AXI WSTRB";
  attribute X_INTERFACE_INFO of m_wlast : signal is "xilinx.com:interface:aximm:1.0 M_AXI WLAST";
  attribute X_INTERFACE_INFO of m_bvalid : signal is "xilinx.com:interface:aximm:1.0 M_AXI BVALID";
  attribute X_INTERFACE_INFO of m_bready : signal is "xilinx.com:interface:aximm:1.0 M_AXI BREADY";
  attribute X_INTERFACE_INFO of m_bresp : signal is "xilinx.com:interface:aximm:1.0 M_AXI BRESP";
  attribute X_INTERFACE_INFO of clk : signal is "xilinx.com:signal:clock:1.0 clk CLK";
  attribute X_INTERFACE_PARAMETER of clk : signal is "ASSOCIATED_BUSIF M_AXI:S_AXI, ASSOCIATED_RESET rst_n, FREQ_HZ 100000000";
  attribute X_INTERFACE_INFO of rst_n : signal is "xilinx.com:signal:reset:1.0 rst_n RST";
  attribute X_INTERFACE_PARAMETER of rst_n : signal is "POLARITY ACTIVE_LOW";

end entity npu_axi_wrap;

architecture rtl of npu_axi_wrap is

begin

  u_impl : entity work.npu_axi_top
    generic map (G_ID_W => G_ID_W)
    port map (
      clk => clk,
      rst_n => rst_n,
      s_awvalid => s_awvalid,
      s_awready => s_awready,
      s_awaddr => s_awaddr,
      s_awlen => s_awlen,
      s_awsize => s_awsize,
      s_awburst => s_awburst,
      s_awid => s_awid,
      s_wvalid => s_wvalid,
      s_wready => s_wready,
      s_wdata => s_wdata,
      s_wstrb => s_wstrb,
      s_wlast => s_wlast,
      s_bvalid => s_bvalid,
      s_bready => s_bready,
      s_bresp => s_bresp,
      s_bid => s_bid,
      s_arvalid => s_arvalid,
      s_arready => s_arready,
      s_araddr => s_araddr,
      s_arlen => s_arlen,
      s_arsize => s_arsize,
      s_arburst => s_arburst,
      s_arid => s_arid,
      s_rvalid => s_rvalid,
      s_rready => s_rready,
      s_rdata => s_rdata,
      s_rresp => s_rresp,
      s_rlast => s_rlast,
      s_rid => s_rid,
      m_arvalid => m_arvalid,
      m_arready => m_arready,
      m_araddr => m_araddr,
      m_arlen => m_arlen,
      m_arsize => m_arsize,
      m_arburst => m_arburst,
      m_rvalid => m_rvalid,
      m_rready => m_rready,
      m_rdata => m_rdata,
      m_rresp => m_rresp,
      m_rlast => m_rlast,
      m_awvalid => m_awvalid,
      m_awready => m_awready,
      m_awaddr => m_awaddr,
      m_awlen => m_awlen,
      m_awsize => m_awsize,
      m_awburst => m_awburst,
      m_wvalid => m_wvalid,
      m_wready => m_wready,
      m_wdata => m_wdata,
      m_wstrb => m_wstrb,
      m_wlast => m_wlast,
      m_bvalid => m_bvalid,
      m_bready => m_bready,
      m_bresp => m_bresp
    );

end architecture rtl;
