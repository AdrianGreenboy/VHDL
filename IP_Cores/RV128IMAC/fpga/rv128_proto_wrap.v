// rv128_proto_wrap.v - Verilog wrapper of the RV128IMAC bare-metal prototype for the
// Vivado Block Design (a VHDL-2008 top cannot be a module reference). The s_axi_ctrl_*
// names make Vivado infer the AXI4-Lite interface.
`timescale 1ns / 1ps
module rv128_proto_wrap #(
  parameter integer MEM_KB   = 128,
  parameter integer TICK_DIV = 50,            // 50 MHz / 50 = 1 MHz mtime
  parameter integer FIFO_LG  = 12
) (
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi_ctrl, ASSOCIATED_RESET aresetn" *)
  input  wire         clk,
  input  wire         aresetn,
  input  wire [17:0]  s_axi_ctrl_awaddr,
  input  wire         s_axi_ctrl_awvalid,
  output wire         s_axi_ctrl_awready,
  input  wire [31:0]  s_axi_ctrl_wdata,
  input  wire [3:0]   s_axi_ctrl_wstrb,
  input  wire         s_axi_ctrl_wvalid,
  output wire         s_axi_ctrl_wready,
  output wire [1:0]   s_axi_ctrl_bresp,
  output wire         s_axi_ctrl_bvalid,
  input  wire         s_axi_ctrl_bready,
  input  wire [17:0]  s_axi_ctrl_araddr,
  input  wire         s_axi_ctrl_arvalid,
  output wire         s_axi_ctrl_arready,
  output wire [31:0]  s_axi_ctrl_rdata,
  output wire [1:0]   s_axi_ctrl_rresp,
  output wire         s_axi_ctrl_rvalid,
  input  wire         s_axi_ctrl_rready,
  output wire         halt
);
  rv128_proto_top #(.MEM_KB(MEM_KB), .TICK_DIV(TICK_DIV), .FIFO_LG(FIFO_LG)) u (
    .clk(clk), .aresetn(aresetn),
    .s_axi_ctrl_awaddr(s_axi_ctrl_awaddr), .s_axi_ctrl_awvalid(s_axi_ctrl_awvalid),
    .s_axi_ctrl_awready(s_axi_ctrl_awready), .s_axi_ctrl_wdata(s_axi_ctrl_wdata),
    .s_axi_ctrl_wstrb(s_axi_ctrl_wstrb), .s_axi_ctrl_wvalid(s_axi_ctrl_wvalid),
    .s_axi_ctrl_wready(s_axi_ctrl_wready), .s_axi_ctrl_bresp(s_axi_ctrl_bresp),
    .s_axi_ctrl_bvalid(s_axi_ctrl_bvalid), .s_axi_ctrl_bready(s_axi_ctrl_bready),
    .s_axi_ctrl_araddr(s_axi_ctrl_araddr), .s_axi_ctrl_arvalid(s_axi_ctrl_arvalid),
    .s_axi_ctrl_arready(s_axi_ctrl_arready), .s_axi_ctrl_rdata(s_axi_ctrl_rdata),
    .s_axi_ctrl_rresp(s_axi_ctrl_rresp), .s_axi_ctrl_rvalid(s_axi_ctrl_rvalid),
    .s_axi_ctrl_rready(s_axi_ctrl_rready), .halt_o(halt)
  );
endmodule
