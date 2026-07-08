// ============================================================================
//  soc_top_spi_wrap.v  -  Envoltorio Verilog del SoC v3 + IP SPI para el BD
//  Licencia: MIT
//
//  Igual que soc_top_master_wrap.v pero con el segundo maestro AXI4 del DMA
//  del SPI (m_axi_spi, para otro puerto SI del NoC), los pads SPI y las dos
//  IRQs (doorbell del core y done del DMA SPI). Ata IDs/LOCK/CACHE/PROT/QOS
//  de ambos maestros a constantes seguras para el NoC.
// ============================================================================
`timescale 1ns / 1ps

module soc_top_spi_wrap #(
    parameter integer S_ADDR_W = 16,
    parameter integer M_ADDR_W = 40
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi:m_axi_spi:s_axi, ASSOCIATED_RESET aresetn" *)
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

    // ---------------- maestro AXI4 (m_axi) ----------------
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

    // ---------------- maestro AXI4 (m_axi_spi) ----------------
    output wire [M_ADDR_W-1:0] m_axi_spi_awaddr,
    output wire [7:0]          m_axi_spi_awlen,
    output wire [2:0]          m_axi_spi_awsize,
    output wire [1:0]          m_axi_spi_awburst,
    output wire [0:0]          m_axi_spi_awid,
    output wire [0:0]          m_axi_spi_awlock,
    output wire [3:0]          m_axi_spi_awcache,
    output wire [2:0]          m_axi_spi_awprot,
    output wire [3:0]          m_axi_spi_awqos,
    output wire                m_axi_spi_awvalid,
    input  wire                m_axi_spi_awready,
    output wire [31:0]         m_axi_spi_wdata,
    output wire [3:0]          m_axi_spi_wstrb,
    output wire                m_axi_spi_wlast,
    output wire                m_axi_spi_wvalid,
    input  wire                m_axi_spi_wready,
    input  wire [0:0]          m_axi_spi_bid,
    input  wire [1:0]          m_axi_spi_bresp,
    input  wire                m_axi_spi_bvalid,
    output wire                m_axi_spi_bready,
    output wire [M_ADDR_W-1:0] m_axi_spi_araddr,
    output wire [7:0]          m_axi_spi_arlen,
    output wire [2:0]          m_axi_spi_arsize,
    output wire [1:0]          m_axi_spi_arburst,
    output wire [0:0]          m_axi_spi_arid,
    output wire [0:0]          m_axi_spi_arlock,
    output wire [3:0]          m_axi_spi_arcache,
    output wire [2:0]          m_axi_spi_arprot,
    output wire [3:0]          m_axi_spi_arqos,
    output wire                m_axi_spi_arvalid,
    input  wire                m_axi_spi_arready,
    input  wire [0:0]          m_axi_spi_rid,
    input  wire [31:0]         m_axi_spi_rdata,
    input  wire [1:0]          m_axi_spi_rresp,
    input  wire                m_axi_spi_rlast,
    input  wire                m_axi_spi_rvalid,
    output wire                m_axi_spi_rready,

    output wire irq_out,
    output wire spi_irq_out,

    // ---------------- pads SPI ----------------
    output wire spi_sclk,
    output wire spi_mosi,
    input  wire spi_miso,
    output wire spi_cs_n
);

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

    assign m_axi_spi_awid    = 1'b0;
    assign m_axi_spi_arid    = 1'b0;
    assign m_axi_spi_awlock  = 1'b0;
    assign m_axi_spi_arlock  = 1'b0;
    assign m_axi_spi_awcache = 4'b0011;   // Normal Non-cacheable Bufferable
    assign m_axi_spi_arcache = 4'b0011;
    assign m_axi_spi_awprot  = 3'b000;
    assign m_axi_spi_arprot  = 3'b000;
    assign m_axi_spi_awqos   = 4'b0000;
    assign m_axi_spi_arqos   = 4'b0000;

    soc_top_spi u_soc (
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

        .m_axi_spi_awaddr  (m_axi_spi_awaddr),
        .m_axi_spi_awlen   (m_axi_spi_awlen),
        .m_axi_spi_awsize  (m_axi_spi_awsize),
        .m_axi_spi_awburst (m_axi_spi_awburst),
        .m_axi_spi_awvalid (m_axi_spi_awvalid),
        .m_axi_spi_awready (m_axi_spi_awready),
        .m_axi_spi_wdata   (m_axi_spi_wdata),
        .m_axi_spi_wstrb   (m_axi_spi_wstrb),
        .m_axi_spi_wlast   (m_axi_spi_wlast),
        .m_axi_spi_wvalid  (m_axi_spi_wvalid),
        .m_axi_spi_wready  (m_axi_spi_wready),
        .m_axi_spi_bresp   (m_axi_spi_bresp),
        .m_axi_spi_bvalid  (m_axi_spi_bvalid),
        .m_axi_spi_bready  (m_axi_spi_bready),
        .m_axi_spi_araddr  (m_axi_spi_araddr),
        .m_axi_spi_arlen   (m_axi_spi_arlen),
        .m_axi_spi_arsize  (m_axi_spi_arsize),
        .m_axi_spi_arburst (m_axi_spi_arburst),
        .m_axi_spi_arvalid (m_axi_spi_arvalid),
        .m_axi_spi_arready (m_axi_spi_arready),
        .m_axi_spi_rdata   (m_axi_spi_rdata),
        .m_axi_spi_rresp   (m_axi_spi_rresp),
        .m_axi_spi_rlast   (m_axi_spi_rlast),
        .m_axi_spi_rvalid  (m_axi_spi_rvalid),
        .m_axi_spi_rready  (m_axi_spi_rready),

        .irq_out     (irq_out),
        .spi_irq_out (spi_irq_out),
        .spi_sclk    (spi_sclk),
        .spi_mosi    (spi_mosi),
        .spi_miso    (spi_miso),
        .spi_cs_n    (spi_cs_n)
    );

endmodule
