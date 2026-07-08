// ============================================================================
//  soc_top_usart_wrap.v  -  Envoltorio Verilog del SoC v3 + IP USART para el BD
//  Licencia: MIT
//
//  Igual que soc_top_spi_wrap.v pero con el segundo maestro AXI4 del DMA del
//  USART (m_axi_usart, para otro puerto SI del NoC), los pads USART y las dos
//  IRQs. Ata IDs/LOCK/CACHE/PROT/QOS de ambos maestros a constantes seguras.
//
//  Novedad vs el SPI: el IOBUF del half-duplex vive AQUI. El pad usart_txd
//  sale como inout unico: en full duplex el IP mantiene txd_t=0 (siempre
//  drivea) y el IOBUF se comporta como OBUF; en half duplex/RS-485 el IP
//  suelta la linea entre frames (PULLUP obligatorio en el XDC). El readback
//  del IOBUF alimenta txd_line_i del IP.
// ============================================================================
`timescale 1ns / 1ps

module soc_top_usart_wrap #(
    parameter integer S_ADDR_W = 16,
    parameter integer M_ADDR_W = 40
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi:m_axi_usart:s_axi, ASSOCIATED_RESET aresetn" *)
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

    // ---------------- maestro AXI4 (m_axi, dma_burst del SoC) --------------
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

    // ---------------- maestro AXI4 (m_axi_usart, DMA del USART) ------------
    output wire [M_ADDR_W-1:0] m_axi_usart_awaddr,
    output wire [7:0]          m_axi_usart_awlen,
    output wire [2:0]          m_axi_usart_awsize,
    output wire [1:0]          m_axi_usart_awburst,
    output wire [0:0]          m_axi_usart_awid,
    output wire [0:0]          m_axi_usart_awlock,
    output wire [3:0]          m_axi_usart_awcache,
    output wire [2:0]          m_axi_usart_awprot,
    output wire [3:0]          m_axi_usart_awqos,
    output wire                m_axi_usart_awvalid,
    input  wire                m_axi_usart_awready,
    output wire [31:0]         m_axi_usart_wdata,
    output wire [3:0]          m_axi_usart_wstrb,
    output wire                m_axi_usart_wlast,
    output wire                m_axi_usart_wvalid,
    input  wire                m_axi_usart_wready,
    input  wire [0:0]          m_axi_usart_bid,
    input  wire [1:0]          m_axi_usart_bresp,
    input  wire                m_axi_usart_bvalid,
    output wire                m_axi_usart_bready,
    output wire [M_ADDR_W-1:0] m_axi_usart_araddr,
    output wire [7:0]          m_axi_usart_arlen,
    output wire [2:0]          m_axi_usart_arsize,
    output wire [1:0]          m_axi_usart_arburst,
    output wire [0:0]          m_axi_usart_arid,
    output wire [0:0]          m_axi_usart_arlock,
    output wire [3:0]          m_axi_usart_arcache,
    output wire [2:0]          m_axi_usart_arprot,
    output wire [3:0]          m_axi_usart_arqos,
    output wire                m_axi_usart_arvalid,
    input  wire                m_axi_usart_arready,
    input  wire [0:0]          m_axi_usart_rid,
    input  wire [31:0]         m_axi_usart_rdata,
    input  wire [1:0]          m_axi_usart_rresp,
    input  wire                m_axi_usart_rlast,
    input  wire                m_axi_usart_rvalid,
    output wire                m_axi_usart_rready,

    output wire irq_out,
    output wire usart_irq_out,

    // ---------------- pads USART (CRUVI LS, banco 302) ----------------
    input  wire usart_rxd,
    inout  wire usart_txd,      // IOBUF interno: full duplex drivea siempre
    input  wire usart_cts_n,
    output wire usart_rts_n
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

    assign m_axi_usart_awid    = 1'b0;
    assign m_axi_usart_arid    = 1'b0;
    assign m_axi_usart_awlock  = 1'b0;
    assign m_axi_usart_arlock  = 1'b0;
    assign m_axi_usart_awcache = 4'b0011; // Normal Non-cacheable Bufferable
    assign m_axi_usart_arcache = 4'b0011;
    assign m_axi_usart_awprot  = 3'b000;
    assign m_axi_usart_arprot  = 3'b000;
    assign m_axi_usart_awqos   = 4'b0000;
    assign m_axi_usart_arqos   = 4'b0000;

    // ---------------- IOBUF del TXD (half duplex / RS-485) -----------------
    wire txd_int, txd_t_int, txd_line;

    IOBUF u_txd_iobuf (
        .I  (txd_int),
        .T  (txd_t_int),          // '1' = suelta el pad (Hi-Z + PULLUP del XDC)
        .O  (txd_line),           // readback de la linea compartida
        .IO (usart_txd)
    );

    soc_top_usart u_soc (
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

        .m_axi_usart_awaddr  (m_axi_usart_awaddr),
        .m_axi_usart_awlen   (m_axi_usart_awlen),
        .m_axi_usart_awsize  (m_axi_usart_awsize),
        .m_axi_usart_awburst (m_axi_usart_awburst),
        .m_axi_usart_awvalid (m_axi_usart_awvalid),
        .m_axi_usart_awready (m_axi_usart_awready),
        .m_axi_usart_wdata   (m_axi_usart_wdata),
        .m_axi_usart_wstrb   (m_axi_usart_wstrb),
        .m_axi_usart_wlast   (m_axi_usart_wlast),
        .m_axi_usart_wvalid  (m_axi_usart_wvalid),
        .m_axi_usart_wready  (m_axi_usart_wready),
        .m_axi_usart_bresp   (m_axi_usart_bresp),
        .m_axi_usart_bvalid  (m_axi_usart_bvalid),
        .m_axi_usart_bready  (m_axi_usart_bready),
        .m_axi_usart_araddr  (m_axi_usart_araddr),
        .m_axi_usart_arlen   (m_axi_usart_arlen),
        .m_axi_usart_arsize  (m_axi_usart_arsize),
        .m_axi_usart_arburst (m_axi_usart_arburst),
        .m_axi_usart_arvalid (m_axi_usart_arvalid),
        .m_axi_usart_arready (m_axi_usart_arready),
        .m_axi_usart_rdata   (m_axi_usart_rdata),
        .m_axi_usart_rresp   (m_axi_usart_rresp),
        .m_axi_usart_rlast   (m_axi_usart_rlast),
        .m_axi_usart_rvalid  (m_axi_usart_rvalid),
        .m_axi_usart_rready  (m_axi_usart_rready),

        .irq_out       (irq_out),
        .usart_irq_out (usart_irq_out),

        .usart_rxd      (usart_rxd),
        .usart_txd      (txd_int),
        .usart_txd_t    (txd_t_int),
        .usart_txd_line (txd_line),
        .usart_cts_n    (usart_cts_n),
        .usart_rts_n    (usart_rts_n)
    );

endmodule
