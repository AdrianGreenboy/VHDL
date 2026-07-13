// ============================================================================
//  soc_top_master_adcs_wrap.v  -  Envoltorio Verilog del SoC ADCS para el BD
//  Licencia: MIT
//
//  Vivado no acepta VHDL-2008 como top de "Module Reference" en un BD; este
//  wrapper Verilog envuelve soc_top_master_adcs y presenta:
//    - s_axi : esclavo AXI4-Lite (control + IMEM)      [16 bits de direccion]
//    - m_axi : maestro AXI4 dma_burst del SoC          [40 bits] -> S06_AXI
//    - a_axi : maestro AXI4 propio del IP ADCS         [32 bits] -> S07_AXI
//    - irq_out
//  Ata a constantes seguras las senales AXI que el maestro no genera (IDs,
//  LOCK, QOS). El a_axi SI genera arprot/awprot=010 y arcache/awcache=0011
//  desde el IP (leccion de silicio: sin AxPROT NON-SECURE el NoC descarta la
//  transaccion) -> esos se propagan, no se atan.
// ============================================================================
`timescale 1ns / 1ps

module soc_top_master_adcs_wrap #(
    parameter integer S_ADDR_W = 16,
    parameter integer M_ADDR_W = 40
)(
    input  wire aclk,
    input  wire aresetn,

    // ---------------- esclavo AXI4-Lite ----------------
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

    // ---------------- maestro 1: m_axi (dma_burst del SoC, 40b) ----------------
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

    // ---------------- maestro 2: a_axi (IP ADCS propio, 32b) ----------------
    output wire [31:0]         a_axi_awaddr,
    output wire [7:0]          a_axi_awlen,
    output wire [2:0]          a_axi_awsize,
    output wire [1:0]          a_axi_awburst,
    output wire [0:0]          a_axi_awid,
    output wire [0:0]          a_axi_awlock,
    output wire [3:0]          a_axi_awcache,
    output wire [2:0]          a_axi_awprot,
    output wire [3:0]          a_axi_awqos,
    output wire                a_axi_awvalid,
    input  wire                a_axi_awready,
    output wire [31:0]         a_axi_wdata,
    output wire [3:0]          a_axi_wstrb,
    output wire                a_axi_wlast,
    output wire                a_axi_wvalid,
    input  wire                a_axi_wready,
    input  wire [0:0]          a_axi_bid,
    input  wire [1:0]          a_axi_bresp,
    input  wire                a_axi_bvalid,
    output wire                a_axi_bready,
    output wire [31:0]         a_axi_araddr,
    output wire [7:0]          a_axi_arlen,
    output wire [2:0]          a_axi_arsize,
    output wire [1:0]          a_axi_arburst,
    output wire [0:0]          a_axi_arid,
    output wire [0:0]          a_axi_arlock,
    output wire [3:0]          a_axi_arcache,
    output wire [2:0]          a_axi_arprot,
    output wire [3:0]          a_axi_arqos,
    output wire                a_axi_arvalid,
    input  wire                a_axi_arready,
    input  wire [0:0]          a_axi_rid,
    input  wire [31:0]         a_axi_rdata,
    input  wire [1:0]          a_axi_rresp,
    input  wire                a_axi_rlast,
    input  wire                a_axi_rvalid,
    output wire                a_axi_rready,

    output wire irq_out
);

    // --- m_axi: senales que el dma_burst no genera -> constantes seguras ---
    assign m_axi_awid    = 1'b0;
    assign m_axi_arid    = 1'b0;
    assign m_axi_awlock  = 1'b0;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;
    assign m_axi_arqos   = 4'b0000;

    // --- a_axi: IDs/lock/qos a constantes; prot/cache VIENEN del IP ---
    assign a_axi_awid    = 1'b0;
    assign a_axi_arid    = 1'b0;
    assign a_axi_awlock  = 1'b0;
    assign a_axi_arlock  = 1'b0;
    assign a_axi_awqos   = 4'b0000;
    assign a_axi_arqos   = 4'b0000;

    soc_top_master_adcs u_soc (
        .aclk    (aclk),
        .aresetn (aresetn),

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

        // maestro 1: dma_burst
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

        // maestro 2: IP ADCS (prot/cache los genera el axi_dma_engine)
        .a_axi_awaddr  (a_axi_awaddr),
        .a_axi_awlen   (a_axi_awlen),
        .a_axi_awsize  (a_axi_awsize),
        .a_axi_awburst (a_axi_awburst),
        .a_axi_awprot  (a_axi_awprot),
        .a_axi_awcache (a_axi_awcache),
        .a_axi_awvalid (a_axi_awvalid),
        .a_axi_awready (a_axi_awready),
        .a_axi_wdata   (a_axi_wdata),
        .a_axi_wstrb   (a_axi_wstrb),
        .a_axi_wlast   (a_axi_wlast),
        .a_axi_wvalid  (a_axi_wvalid),
        .a_axi_wready  (a_axi_wready),
        .a_axi_bresp   (a_axi_bresp),
        .a_axi_bvalid  (a_axi_bvalid),
        .a_axi_bready  (a_axi_bready),
        .a_axi_araddr  (a_axi_araddr),
        .a_axi_arlen   (a_axi_arlen),
        .a_axi_arsize  (a_axi_arsize),
        .a_axi_arburst (a_axi_arburst),
        .a_axi_arprot  (a_axi_arprot),
        .a_axi_arcache (a_axi_arcache),
        .a_axi_arvalid (a_axi_arvalid),
        .a_axi_arready (a_axi_arready),
        .a_axi_rdata   (a_axi_rdata),
        .a_axi_rresp   (a_axi_rresp),
        .a_axi_rlast   (a_axi_rlast),
        .a_axi_rvalid  (a_axi_rvalid),
        .a_axi_rready  (a_axi_rready),

        .irq_out (irq_out)
    );

endmodule
