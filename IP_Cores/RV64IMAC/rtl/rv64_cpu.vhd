-- rv64_cpu.vhd - core RV64IMAC + I$ + D$ + maestro AXI4 de 64 bit.
-- Hacia fuera: un unico puerto maestro AXI4, interrupciones, mtime y traza.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;
use work.rv64_axi_pkg.all;

entity rv64_cpu is
  generic (RESET_PC : xword := x"0000000080000000");
  port (
    clk, rst : in std_logic;
    mtip, msip, meip, seip : in std_logic;
    time_i   : in xword;
    -- AXI4 maestro
    m_awid    : out std_logic_vector(3 downto 0);
    m_awaddr  : out xword;
    m_awlen   : out std_logic_vector(7 downto 0);
    m_awsize  : out std_logic_vector(2 downto 0);
    m_awburst : out std_logic_vector(1 downto 0);
    m_awcache : out std_logic_vector(3 downto 0);
    m_awprot  : out std_logic_vector(2 downto 0);
    m_awvalid : out std_logic;
    m_awready : in  std_logic;
    m_wdata   : out xword;
    m_wstrb   : out std_logic_vector(7 downto 0);
    m_wlast   : out std_logic;
    m_wvalid  : out std_logic;
    m_wready  : in  std_logic;
    m_bid     : in  std_logic_vector(3 downto 0);
    m_bresp   : in  std_logic_vector(1 downto 0);
    m_bvalid  : in  std_logic;
    m_bready  : out std_logic;
    m_arid    : out std_logic_vector(3 downto 0);
    m_araddr  : out xword;
    m_arlen   : out std_logic_vector(7 downto 0);
    m_arsize  : out std_logic_vector(2 downto 0);
    m_arburst : out std_logic_vector(1 downto 0);
    m_arcache : out std_logic_vector(3 downto 0);
    m_arprot  : out std_logic_vector(2 downto 0);
    m_arvalid : out std_logic;
    m_arready : in  std_logic;
    m_rid     : in  std_logic_vector(3 downto 0);
    m_rdata   : in  xword;
    m_rresp   : in  std_logic_vector(1 downto 0);
    m_rlast   : in  std_logic;
    m_rvalid  : in  std_logic;
    m_rready  : out std_logic;
    -- traza de retiro
    rvfi_valid    : out std_logic;
    rvfi_pc       : out xword;
    rvfi_insn     : out std_logic_vector(31 downto 0);
    rvfi_rd       : out std_logic_vector(4 downto 0);
    rvfi_rd_wdata : out xword;
    rvfi_trap     : out std_logic;
    rvfi_cause    : out xword;
    rvfi_tval     : out xword;
    rvfi_mem_addr  : out xword;
    rvfi_mem_wstrb : out std_logic_vector(7 downto 0);
    rvfi_mem_wdata : out xword;
    rvfi_mip       : out xword
  );
end entity;

architecture rtl of rv64_cpu is
  signal i_req_valid, i_req_ready, i_rsp_valid, i_rsp_err : std_logic;
  signal i_req_addr : xword;
  signal i_rsp_data : std_logic_vector(31 downto 0);
  signal d_req_valid, d_req_ready, d_rsp_valid, d_rsp_err : std_logic;
  signal d_req_addr, d_req_wdata, d_rsp_rdata : xword;
  signal d_req_kind, d_req_size : std_logic_vector(1 downto 0);
  signal d_req_amo_op : std_logic_vector(4 downto 0);
  signal d_req_wstrb : std_logic_vector(7 downto 0);
  signal fencei, sfence, flush_busy : std_logic;
  -- clientes AXI
  signal c0_req, c0_cache, c0_beat, c0_done, c1_req, c1_cache, c1_beat, c1_done, ax_err : std_logic;
  signal c0_kind, c0_size, c1_kind, c1_size : std_logic_vector(1 downto 0);
  signal c0_addr, c0_wdata, c1_addr, ax_rdata : xword;
  signal c0_wline : line_t;
  signal c0_wstrb : std_logic_vector(7 downto 0);
  signal ax_idx : std_logic_vector(2 downto 0);
begin
  core_u : entity work.rv64_core generic map (RESET_PC => RESET_PC) port map (
    clk => clk, rst => rst,
    i_req_valid => i_req_valid, i_req_ready => i_req_ready, i_req_addr => i_req_addr,
    i_rsp_valid => i_rsp_valid, i_rsp_data => i_rsp_data, i_rsp_err => i_rsp_err,
    d_req_valid => d_req_valid, d_req_ready => d_req_ready, d_req_addr => d_req_addr,
    d_req_kind => d_req_kind, d_req_amo_op => d_req_amo_op, d_req_size => d_req_size,
    d_req_wdata => d_req_wdata, d_req_wstrb => d_req_wstrb,
    d_rsp_valid => d_rsp_valid, d_rsp_rdata => d_rsp_rdata, d_rsp_err => d_rsp_err,
    mtip => mtip, msip => msip, meip => meip, seip => seip, time_i => time_i,
    fencei_o => fencei, sfence_o => sfence,
    rvfi_valid => rvfi_valid, rvfi_pc => rvfi_pc, rvfi_insn => rvfi_insn, rvfi_rd => rvfi_rd,
    rvfi_rd_wdata => rvfi_rd_wdata, rvfi_trap => rvfi_trap, rvfi_cause => rvfi_cause,
    rvfi_tval => rvfi_tval, rvfi_mem_addr => rvfi_mem_addr, rvfi_mem_wstrb => rvfi_mem_wstrb,
    rvfi_mem_wdata => rvfi_mem_wdata, rvfi_mip => rvfi_mip);

  icache_u : entity work.rv64_icache port map (
    clk => clk, rst => rst,
    req_valid => i_req_valid, req_ready => i_req_ready, req_addr => i_req_addr,
    rsp_valid => i_rsp_valid, rsp_data => i_rsp_data, rsp_err => i_rsp_err,
    inval => fencei, hold => flush_busy,
    m_req => c1_req, m_kind => c1_kind, m_addr => c1_addr, m_size => c1_size, m_cache => c1_cache,
    m_beat => c1_beat, m_done => c1_done, m_idx => ax_idx, m_rdata => ax_rdata, m_err => ax_err);

  dcache_u : entity work.rv64_dcache port map (
    clk => clk, rst => rst,
    req_valid => d_req_valid, req_ready => d_req_ready, req_addr => d_req_addr,
    req_kind => d_req_kind, req_amo_op => d_req_amo_op, req_size => d_req_size,
    req_wdata => d_req_wdata, req_wstrb => d_req_wstrb,
    rsp_valid => d_rsp_valid, rsp_rdata => d_rsp_rdata, rsp_err => d_rsp_err,
    flush => fencei, flush_busy => flush_busy,
    m_req => c0_req, m_kind => c0_kind, m_addr => c0_addr, m_size => c0_size, m_wline => c0_wline,
    m_wdata => c0_wdata, m_wstrb => c0_wstrb, m_cache => c0_cache,
    m_beat => c0_beat, m_done => c0_done, m_idx => ax_idx, m_rdata => ax_rdata, m_err => ax_err);

  axi_u : entity work.rv64_axi_master port map (
    clk => clk, rst => rst,
    c0_req => c0_req, c0_kind => c0_kind, c0_addr => c0_addr, c0_size => c0_size,
    c0_wline => c0_wline, c0_wdata => c0_wdata, c0_wstrb => c0_wstrb, c0_cache => c0_cache,
    c0_beat => c0_beat, c0_done => c0_done,
    c1_req => c1_req, c1_kind => c1_kind, c1_addr => c1_addr, c1_size => c1_size, c1_cache => c1_cache,
    c1_beat => c1_beat, c1_done => c1_done,
    beat_idx => ax_idx, rdata => ax_rdata, err => ax_err,
    m_awid => m_awid, m_awaddr => m_awaddr, m_awlen => m_awlen, m_awsize => m_awsize,
    m_awburst => m_awburst, m_awcache => m_awcache, m_awprot => m_awprot,
    m_awvalid => m_awvalid, m_awready => m_awready,
    m_wdata => m_wdata, m_wstrb => m_wstrb, m_wlast => m_wlast, m_wvalid => m_wvalid, m_wready => m_wready,
    m_bid => m_bid, m_bresp => m_bresp, m_bvalid => m_bvalid, m_bready => m_bready,
    m_arid => m_arid, m_araddr => m_araddr, m_arlen => m_arlen, m_arsize => m_arsize,
    m_arburst => m_arburst, m_arcache => m_arcache, m_arprot => m_arprot,
    m_arvalid => m_arvalid, m_arready => m_arready,
    m_rid => m_rid, m_rdata => m_rdata, m_rresp => m_rresp, m_rlast => m_rlast,
    m_rvalid => m_rvalid, m_rready => m_rready);
end architecture;
