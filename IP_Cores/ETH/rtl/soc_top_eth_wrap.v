// ===========================================================================
//  soc_top_eth_wrap.v - Wrapper Verilog del soc_top_eth (VHDL)
//
//  Envoltura mecanica para que el Block Design de Vivado referencie el SoC
//  como un module (create_bd_cell -type module -reference soc_top_eth_wrap).
//  Espeja EXACTAMENTE los puertos de la entidad soc_top_eth. Los genericos se
//  dejan en sus valores por defecto (AXI_AW=40, ADDR_W=16, DEPTH=256); si el
//  clon del 1553 fijaba IMEM_INIT o DEPTH por parametro en el wrapper del BD,
//  replicar aqui el mismo override (ver soc_top_m1553_wrap.v del proyecto
//  padre).
//
//  NOTA: los pines MII de entrada (mii_rxd/mii_rx_dv) se exponen al BD, que a
//  su vez los saca a puertos externos restringidos por XDC. En LOOP_INT v1 el
//  MAC los ignora (mux interno), pero deben existir para que el wrapper case
//  con la entidad.
// ===========================================================================
`timescale 1ns / 1ps

module soc_top_eth_wrap #(
    parameter integer ADDR_W = 16,
    parameter integer DEPTH  = 256,
    parameter         IMEM_INIT = "",
    parameter integer DONE_WORD = 127,
    parameter integer AXI_AW = 40
) (
    input  wire        aclk,
    input  wire        aresetn,

    // esclavo AXI4-Lite
    input  wire [ADDR_W-1:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [ADDR_W-1:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // maestro AXI4
    output wire [AXI_AW-1:0] m_axi_awaddr,
    output wire [7:0]  m_axi_awlen,
    output wire [2:0]  m_axi_awsize,
    output wire [1:0]  m_axi_awburst,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    output wire [AXI_AW-1:0] m_axi_araddr,
    output wire [7:0]  m_axi_arlen,
    output wire [2:0]  m_axi_arsize,
    output wire [1:0]  m_axi_arburst,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,

    output wire        irq_out,
    output wire        eth_irq_out,

    // pads MII
    output wire [3:0]  mii_txd,
    output wire        mii_tx_en,
    input  wire [3:0]  mii_rxd,
    input  wire        mii_rx_dv
);

    soc_top_eth #(
        .ADDR_W(ADDR_W),
        .DEPTH(DEPTH),
        .IMEM_INIT(IMEM_INIT),
        .DONE_WORD(DONE_WORD),
        .AXI_AW(AXI_AW)
    ) u_soc_top_eth (
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),

        .irq_out(irq_out),
        .eth_irq_out(eth_irq_out),

        .mii_txd(mii_txd),
        .mii_tx_en(mii_tx_en),
        .mii_rxd(mii_rxd),
        .mii_rx_dv(mii_rx_dv)
    );

endmodule
