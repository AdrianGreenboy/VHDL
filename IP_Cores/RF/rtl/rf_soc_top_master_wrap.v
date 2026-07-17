// =============================================================================
//  rf_soc_top_master_wrap.v - Envoltorio Verilog del SoC RF para el BD.
//  Expone dos maestros AXI4 de 40 bits con las senales que el NoC de Versal
//  exige (id/lock/cache/prot/qos atadas a constantes):
//    - m_axi : DMA de la familia (dma_burst)     -> S06_AXI
//    - rf    : segundo maestro del RF            -> S07_AXI
//  Dos IRQ: irq_out (doorbell del core) y rf_irq_out (nivel RX FIFO).
//  Envuelve la entidad VHDL rf_soc_top_master. Licencia: MIT.
// =============================================================================
module rf_soc_top_master_wrap #(
    parameter integer S_ADDR_W = 16,
    parameter integer M_ADDR_W = 40
)(
    input  wire aclk,
    input  wire aresetn,

    // ---- esclavo AXI4-Lite (control + IMEM) ----
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

    // ---- maestro m_axi (40b) ----
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
    input  wire [31:0]         m_axi_rdata,
    input  wire [1:0]          m_axi_rresp,
    input  wire                m_axi_rlast,
    input  wire                m_axi_rvalid,
    output wire                m_axi_rready,

    // ---- maestro rf (40b) ----
    output wire [M_ADDR_W-1:0] rf_axi_awaddr,
    output wire [7:0]          rf_axi_awlen,
    output wire [2:0]          rf_axi_awsize,
    output wire [1:0]          rf_axi_awburst,
    output wire [0:0]          rf_axi_awid,
    output wire [0:0]          rf_axi_awlock,
    output wire [3:0]          rf_axi_awcache,
    output wire [2:0]          rf_axi_awprot,
    output wire [3:0]          rf_axi_awqos,
    output wire                rf_axi_awvalid,
    input  wire                rf_axi_awready,
    output wire [31:0]         rf_axi_wdata,
    output wire [3:0]          rf_axi_wstrb,
    output wire                rf_axi_wlast,
    output wire                rf_axi_wvalid,
    input  wire                rf_axi_wready,
    input  wire [1:0]          rf_axi_bresp,
    input  wire                rf_axi_bvalid,
    output wire                rf_axi_bready,
    output wire [M_ADDR_W-1:0] rf_axi_araddr,
    output wire [7:0]          rf_axi_arlen,
    output wire [2:0]          rf_axi_arsize,
    output wire [1:0]          rf_axi_arburst,
    output wire [0:0]          rf_axi_arid,
    output wire [0:0]          rf_axi_arlock,
    output wire [3:0]          rf_axi_arcache,
    output wire [2:0]          rf_axi_arprot,
    output wire [3:0]          rf_axi_arqos,
    output wire                rf_axi_arvalid,
    input  wire                rf_axi_arready,
    input  wire [31:0]         rf_axi_rdata,
    input  wire [1:0]          rf_axi_rresp,
    input  wire                rf_axi_rlast,
    input  wire                rf_axi_rvalid,
    output wire                rf_axi_rready,

    output wire irq_out,
    output wire rf_irq_out
);

    // tie-offs AXI4 que el axi4_master de la familia no genera
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

    assign rf_axi_awid    = 1'b0;
    assign rf_axi_arid    = 1'b0;
    assign rf_axi_awlock  = 1'b0;
    assign rf_axi_arlock  = 1'b0;
    assign rf_axi_awcache = 4'b0011;
    assign rf_axi_arcache = 4'b0011;
    assign rf_axi_awprot  = 3'b000;
    assign rf_axi_arprot  = 3'b000;
    assign rf_axi_awqos   = 4'b0000;
    assign rf_axi_arqos   = 4'b0000;

    rf_soc_top_master u_soc (
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
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awlen  (m_axi_awlen),
        .m_axi_awsize  (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_wdata  (m_axi_wdata),
        .m_axi_wstrb  (m_axi_wstrb),
        .m_axi_wlast  (m_axi_wlast),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),
        .m_axi_bresp  (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen  (m_axi_arlen),
        .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rdata  (m_axi_rdata),
        .m_axi_rresp  (m_axi_rresp),
        .m_axi_rlast  (m_axi_rlast),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready),
        .rf_axi_awaddr  (rf_axi_awaddr),
        .rf_axi_awlen  (rf_axi_awlen),
        .rf_axi_awsize  (rf_axi_awsize),
        .rf_axi_awburst  (rf_axi_awburst),
        .rf_axi_awvalid  (rf_axi_awvalid),
        .rf_axi_awready  (rf_axi_awready),
        .rf_axi_wdata  (rf_axi_wdata),
        .rf_axi_wstrb  (rf_axi_wstrb),
        .rf_axi_wlast  (rf_axi_wlast),
        .rf_axi_wvalid  (rf_axi_wvalid),
        .rf_axi_wready  (rf_axi_wready),
        .rf_axi_bresp  (rf_axi_bresp),
        .rf_axi_bvalid  (rf_axi_bvalid),
        .rf_axi_bready  (rf_axi_bready),
        .rf_axi_araddr  (rf_axi_araddr),
        .rf_axi_arlen  (rf_axi_arlen),
        .rf_axi_arsize  (rf_axi_arsize),
        .rf_axi_arburst  (rf_axi_arburst),
        .rf_axi_arvalid  (rf_axi_arvalid),
        .rf_axi_arready  (rf_axi_arready),
        .rf_axi_rdata  (rf_axi_rdata),
        .rf_axi_rresp  (rf_axi_rresp),
        .rf_axi_rlast  (rf_axi_rlast),
        .rf_axi_rvalid  (rf_axi_rvalid),
        .rf_axi_rready  (rf_axi_rready),
        .irq_out    (irq_out),
        .rf_irq_out (rf_irq_out)
    );

endmodule
