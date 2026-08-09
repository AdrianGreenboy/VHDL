// ============================================================================
//  soc_top_ecc_wrap.v  -  HERCOSSNUX Core 20 SoC Verilog wrapper for the BD.
//  Licencia: MIT
//
//  Vivado no acepta VHDL-2008 como top de "Module Reference"; este wrapper
//  Verilog envuelve ecc_soc_si y presenta al Block Design:
//    - s_axi : esclavo AXI4-Lite (control + IMEM)        [16 bits]
//    - m_axi : maestro AXI4 del core (DMA local<->DDR)   [40 bits]
//    - aclk, aresetn, irq_out
//  A diferencia del Core 19 (PCS), el ECC scrubber corre TODO en aclk: NO tiene
//  clk_dp ni dp_locked. Ata las senales AXI que el maestro DMA no genera
//  (IDs, LOCK, CACHE, PROT, QOS) a constantes seguras (AWCACHE 0011).
// ============================================================================
`timescale 1ns / 1ps

module soc_top_ecc_wrap #(
    parameter integer S_ADDR_W = 16,
    parameter integer M_ADDR_W = 40
)(
    input  wire aclk,
    input  wire aresetn,

    // ---------------- esclavo AXI4-Lite (control + IMEM) ----------------
    input  wire [S_ADDR_W-1:0] s_axi_awaddr,
    input  wire                s_axi_awvalid,
    output wire                s_axi_awready,
    input  wire [31:0]         s_axi_wdata,
    input  wire [3:0]          s_axi_wstrb,
    input  wire                s_axi_wvalid,
    output wire                s_axi_wready,
    output wire [1:0]          s_axi_bresp,
    output wire                s_axi_bvalid,
    input  wire                s_axi_bready,
    input  wire [S_ADDR_W-1:0] s_axi_araddr,
    input  wire                s_axi_arvalid,
    output wire                s_axi_arready,
    output wire [31:0]         s_axi_rdata,
    output wire [1:0]          s_axi_rresp,
    output wire                s_axi_rvalid,
    input  wire                s_axi_rready,

    // ---------------- maestro AXI4 del core (local<->DDR) ----------------
    output wire [M_ADDR_W-1:0] m_axi_awaddr,
    output wire [7:0]          m_axi_awlen,
    output wire [2:0]          m_axi_awsize,
    output wire [1:0]          m_axi_awburst,
    output wire [0:0]          m_axi_awid,
    output wire [0:0]          m_axi_awlock,
    output wire [3:0]          m_axi_awcache,
    output wire [2:0]          m_axi_awprot,
    output wire [3:0]          m_axi_awqos,
    output wire                m_axi_awvalid,
    input  wire                m_axi_awready,
    output wire [31:0]         m_axi_wdata,
    output wire [3:0]          m_axi_wstrb,
    output wire                m_axi_wlast,
    output wire                m_axi_wvalid,
    input  wire                m_axi_wready,
    input  wire [0:0]          m_axi_bid,
    input  wire [1:0]          m_axi_bresp,
    input  wire                m_axi_bvalid,
    output wire                m_axi_bready,
    output wire [M_ADDR_W-1:0] m_axi_araddr,
    output wire [7:0]          m_axi_arlen,
    output wire [2:0]          m_axi_arsize,
    output wire [1:0]          m_axi_arburst,
    output wire [0:0]          m_axi_arid,
    output wire [0:0]          m_axi_arlock,
    output wire [3:0]          m_axi_arcache,
    output wire [2:0]          m_axi_arprot,
    output wire [3:0]          m_axi_arqos,
    output wire                m_axi_arvalid,
    input  wire                m_axi_arready,
    input  wire [0:0]          m_axi_rid,
    input  wire [31:0]         m_axi_rdata,
    input  wire [1:0]          m_axi_rresp,
    input  wire                m_axi_rlast,
    input  wire                m_axi_rvalid,
    output wire                m_axi_rready,

    output wire irq_out
);

    // ---- Senales AXI que el maestro no genera -> constantes seguras ----
    assign m_axi_awid    = 1'b0;
    assign m_axi_arid    = 1'b0;
    assign m_axi_awlock  = 1'b0;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;   // Normal Non-cacheable Bufferable
    assign m_axi_arcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;
    assign m_axi_arqos   = 4'b0000;

    ecc_soc_si u_soc (
        .aclk      (aclk),
        .aresetn   (aresetn),
        // AXI-Lite slave
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        // core AXI master
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awlen   (m_axi_awlen),
        .m_axi_awsize  (m_axi_awsize),
        .m_axi_awburst (m_axi_awburst),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wlast   (m_axi_wlast),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),
        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen   (m_axi_arlen),
        .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst (m_axi_arburst),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rlast   (m_axi_rlast),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready),
        .irq_out (irq_out)
    );
endmodule
