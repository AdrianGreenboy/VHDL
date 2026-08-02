// ============================================================================
//  soc_top_mipi_wrap.v  -  HERCOSSNUX Core 18 SoC Verilog wrapper for the BD.
//  Licencia: MIT
//
//  Vivado no acepta VHDL-2008 como top de "Module Reference"; este wrapper
//  Verilog envuelve soc_top_mipi y presenta:
//    - s_axi     : esclavo AXI4-Lite (control + IMEM)          [16 bits]
//    - m_axi     : maestro AXI4 del core (DMA local<->DDR)     [40 bits]
//    - mipi_axi  : maestro AXI4 del MIPI (framebuffer->DDR)    [40 bits]
//    - irq_out
//  Ata las senales AXI que el NoC espera pero que los maestros no generan
//  (IDs, LOCK, CACHE, PROT, QOS) a constantes seguras. Ambos maestros son
//  write-only hacia la DDR salvo el core, que ademas lee (canal AR/R).
//
//  Lecciones Versal aplicadas: los maestros PL van a esclavos NoC dedicados del
//  mismo MC que el CIPS (wiring por Tcl, no Connection Automation); AWCACHE
//  Normal Non-cacheable Bufferable (0011); el MIPI no cruza fronteras de 4 KB
//  (el motor de bursts parte en la pagina).
// ============================================================================
`timescale 1ns / 1ps

module soc_top_mipi_wrap #(
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

    // ---------------- maestro AXI4 del MIPI (framebuffer->DDR) ------------
    // write-only (el MIPI solo escribe framebuffers a la DDR)
    output wire [M_ADDR_W-1:0] mipi_axi_awaddr,
    output wire [7:0]          mipi_axi_awlen,
    output wire [2:0]          mipi_axi_awsize,
    output wire [1:0]          mipi_axi_awburst,
    output wire [0:0]          mipi_axi_awid,
    output wire [0:0]          mipi_axi_awlock,
    output wire [3:0]          mipi_axi_awcache,
    output wire [2:0]          mipi_axi_awprot,
    output wire [3:0]          mipi_axi_awqos,
    output wire                mipi_axi_awvalid,
    input  wire                mipi_axi_awready,
    output wire [31:0]         mipi_axi_wdata,
    output wire [3:0]          mipi_axi_wstrb,
    output wire                mipi_axi_wlast,
    output wire                mipi_axi_wvalid,
    input  wire                mipi_axi_wready,
    input  wire [0:0]          mipi_axi_bid,
    input  wire [1:0]          mipi_axi_bresp,
    input  wire                mipi_axi_bvalid,
    output wire                mipi_axi_bready,

    output wire irq_out
);

    // ---- Senales AXI que los maestros no generan -> constantes seguras ----
    // core master
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
    // MIPI master (write-only)
    assign mipi_axi_awid    = 1'b0;
    assign mipi_axi_awlock  = 1'b0;
    assign mipi_axi_awcache = 4'b0011;
    assign mipi_axi_awprot  = 3'b000;
    assign mipi_axi_awqos   = 4'b0000;

    soc_top_mipi u_soc (
        .aclk    (aclk),
        .aresetn (aresetn),

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

        // MIPI AXI master (write-only)
        .mipi_awaddr  (mipi_axi_awaddr),
        .mipi_awlen   (mipi_axi_awlen),
        .mipi_awsize  (mipi_axi_awsize),
        .mipi_awburst (mipi_axi_awburst),
        .mipi_awvalid (mipi_axi_awvalid),
        .mipi_awready (mipi_axi_awready),
        .mipi_wdata   (mipi_axi_wdata),
        .mipi_wstrb   (mipi_axi_wstrb),
        .mipi_wlast   (mipi_axi_wlast),
        .mipi_wvalid  (mipi_axi_wvalid),
        .mipi_wready  (mipi_axi_wready),
        .mipi_bresp   (mipi_axi_bresp),
        .mipi_bvalid  (mipi_axi_bvalid),
        .mipi_bready  (mipi_axi_bready),

        .irq_out (irq_out)
    );

endmodule
