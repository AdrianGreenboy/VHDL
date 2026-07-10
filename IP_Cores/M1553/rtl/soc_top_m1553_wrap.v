// ============================================================================
//  soc_top_m1553_wrap.v  -  Envoltorio Verilog del SoC v3 + IP MIL-STD-1553B
//  Licencia: MIT
//
//  El BD instancia este module reference (create_bd_cell -type module
//  -reference soc_top_m1553_wrap). Es un passthrough puro a la entidad VHDL
//  soc_top_m1553: mismos puertos, mismos anchos. Clonado del
//  soc_top_spw_wrap sustituyendo los 4 pads LVDS del SPW por los 3 pines
//  single-ended del 1553 (m1553_rx entra; m1553_tx/m1553_txen salen) y la
//  IRQ spw_irq_out por m1553_irq_out.
// ============================================================================
`timescale 1ns / 1ps

module soc_top_m1553_wrap #(
    parameter ADDR_W    = 16,
    parameter DEPTH     = 256,
    parameter IMEM_INIT = "",
    parameter DONE_WORD = 127,
    parameter AXI_AW    = 40
) (
    input  wire                     aclk,
    input  wire                     aresetn,

    // ---- AXI4-Lite esclavo (control + IMEM) ----
    input  wire [ADDR_W-1:0]        s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,
    input  wire [31:0]              s_axi_wdata,
    input  wire [3:0]               s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,
    output wire [1:0]               s_axi_bresp,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,
    input  wire [ADDR_W-1:0]        s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    output wire [31:0]              s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    // ---- AXI4 maestro (dma_burst -> LPDDR4) ----
    output wire [AXI_AW-1:0]        m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,
    output wire [31:0]              m_axi_wdata,
    output wire [3:0]               m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,
    input  wire [1:0]               m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready,
    output wire [AXI_AW-1:0]        m_axi_araddr,
    output wire [7:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,
    input  wire [31:0]              m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready,

    output wire                     irq_out,
    output wire                     m1553_irq_out,

    // ---- pads MIL-STD-1553 (single-ended; inocuos en LOOP_INT) ----
    input  wire                     m1553_rx,
    output wire                     m1553_tx,
    output wire                     m1553_txen
);

    soc_top_m1553 #(
        .ADDR_W    (ADDR_W),
        .DEPTH     (DEPTH),
        .IMEM_INIT (IMEM_INIT),
        .DONE_WORD (DONE_WORD),
        .AXI_AW    (AXI_AW)
    ) u_soc (
        .aclk          (aclk),
        .aresetn       (aresetn),
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
        .irq_out       (irq_out),
        .m1553_irq_out (m1553_irq_out),
        .m1553_rx      (m1553_rx),
        .m1553_tx      (m1553_tx),
        .m1553_txen    (m1553_txen)
    );

endmodule
