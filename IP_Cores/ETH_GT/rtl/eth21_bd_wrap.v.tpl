// ============================================================================
//  eth21_bd_wrap.v  -  HERCOSSNUX Core 21 (ETH GT) wrapper Verilog para el BD.
//  GENERADO por vivado/build_eth_soc.tcl a partir de rtl/eth21_bd_wrap.v.tpl
//  (el nombre logico del puerto de loopback de CH0_DEBUG se lee del Vivado
//  instalado). Licencia: MIT
//
//  Vivado no acepta VHDL-2008 como top de "Module Reference": este wrapper
//  envuelve eth21_top y declara con X_INTERFACE_INFO las interfaces del canal
//  0 del gt_quad_base (TX0_GT_IP_Interface, RX0_GT_IP_Interface, CH0_DEBUG),
//  de modo que en el BD se conectan con connect_bd_intf_net. Las senales de
//  la interfaz que el core no usa quedan con su valor por defecto del IP.
// ============================================================================
`timescale 1ns / 1ps

module eth21_bd_wrap #(
    parameter integer ACLK_HZ   = 40000000,
    parameter integer SLIP_WAIT = 64
)(
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [15:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [15:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    input  wire        tx_usrclk,
    input  wire        rx_usrclk,

    (* X_INTERFACE_MODE = "master" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_tx_interface:1.0 TX0 ch_txdata" *)
    output wire [127:0] tx0_txdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_tx_interface:1.0 TX0 ch_txheader" *)
    output wire [5:0]   tx0_txheader,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_tx_interface:1.0 TX0 ch_txsequence" *)
    output wire [6:0]   tx0_txsequence,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_tx_interface:1.0 TX0 ch_txmstreset" *)
    output wire         tx0_txmstreset,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_tx_interface:1.0 TX0 ch_txuserrdy" *)
    output wire         tx0_txuserrdy,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_tx_interface:1.0 TX0 ch_txpolarity" *)
    output wire         tx0_txpolarity,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_tx_interface:1.0 TX0 ch_txmstresetdone" *)
    input  wire         tx0_txmstresetdone,

    (* X_INTERFACE_MODE = "master" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxdata" *)
    input  wire [127:0] rx0_rxdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxdatavalid" *)
    input  wire [1:0]   rx0_rxdatavalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxheader" *)
    input  wire [5:0]   rx0_rxheader,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxheadervalid" *)
    input  wire [1:0]   rx0_rxheadervalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxgearboxslip" *)
    output wire         rx0_rxgearboxslip,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxmstreset" *)
    output wire         rx0_rxmstreset,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxuserrdy" *)
    output wire         rx0_rxuserrdy,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxpolarity" *)
    output wire         rx0_rxpolarity,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxmstresetdone" *)
    input  wire         rx0_rxmstresetdone,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_rx_interface:1.0 RX0 ch_rxcdrlock" *)
    input  wire         rx0_rxcdrlock,

// @DBG_BEGIN@
    (* X_INTERFACE_MODE = "master" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:gt_channel_debug:1.0 DBG0 @LB_LOGICAL@" *)
    output wire [2:0]   dbg0_loopback,
// @DBG_END@

    input  wire         gtpowergood,
    input  wire         lcplllock,
    output wire         lcpllreset
);

    wire [2:0] loopback_w;
// @DBG_ASSIGN@

    eth21_top #(
        .ACLK_HZ   (ACLK_HZ),
        .SLIP_WAIT (SLIP_WAIT)
    ) u_core (
        .s_axi_aclk        (aclk),
        .s_axi_aresetn     (aresetn),
        .s_axi_awaddr      (s_axi_awaddr[7:0]),
        .s_axi_awvalid     (s_axi_awvalid),
        .s_axi_awready     (s_axi_awready),
        .s_axi_wdata       (s_axi_wdata),
        .s_axi_wstrb       (s_axi_wstrb),
        .s_axi_wvalid      (s_axi_wvalid),
        .s_axi_wready      (s_axi_wready),
        .s_axi_bresp       (s_axi_bresp),
        .s_axi_bvalid      (s_axi_bvalid),
        .s_axi_bready      (s_axi_bready),
        .s_axi_araddr      (s_axi_araddr[7:0]),
        .s_axi_arvalid     (s_axi_arvalid),
        .s_axi_arready     (s_axi_arready),
        .s_axi_rdata       (s_axi_rdata),
        .s_axi_rresp       (s_axi_rresp),
        .s_axi_rvalid      (s_axi_rvalid),
        .s_axi_rready      (s_axi_rready),
        .tx_clk            (tx_usrclk),
        .rx_clk            (rx_usrclk),
        .gt_txdata         (tx0_txdata),
        .gt_txheader       (tx0_txheader),
        .gt_txsequence     (tx0_txsequence),
        .gt_txmstreset     (tx0_txmstreset),
        .gt_txuserrdy      (tx0_txuserrdy),
        .gt_txpolarity     (tx0_txpolarity),
        .gt_txmstresetdone (tx0_txmstresetdone),
        .gt_rxdata         (rx0_rxdata),
        .gt_rxdatavalid    (rx0_rxdatavalid),
        .gt_rxheader       (rx0_rxheader),
        .gt_rxheadervalid  (rx0_rxheadervalid),
        .gt_rxgearboxslip  (rx0_rxgearboxslip),
        .gt_rxmstreset     (rx0_rxmstreset),
        .gt_rxuserrdy      (rx0_rxuserrdy),
        .gt_rxpolarity     (rx0_rxpolarity),
        .gt_rxmstresetdone (rx0_rxmstresetdone),
        .gt_rxcdrlock      (rx0_rxcdrlock),
        .gt_powergood      (gtpowergood),
        .gt_lcplllock      (lcplllock),
        .gt_lcpllreset     (lcpllreset),
        .gt_loopback       (loopback_w)
    );
endmodule
