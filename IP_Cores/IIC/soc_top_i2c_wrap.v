// ============================================================================
//  soc_top_i2c_wrap.v - Wrapper Verilog del SoC v3 + IP IIC para el BD
//  Licencia: MIT
//
//  Patron heredado del USART: los IOBUF viven DENTRO del wrapper, asi el BD
//  ve pads inout unicos (scl/sda) y un solo bitstream sirve para loop_int y
//  para bus externo. Open-drain de verdad: I=1'b0 fijo y T=*_t del motor
//  ('1' = soltar la linea, '0' = jalarla a tierra; NUNCA se empuja un '1').
//
//  ASSOCIATED_BUSIF en aclk: s_axi y m_axi (leccion USART: sin esto los SIs
//  del NoC quedan colgados de aclk0 y hay CDC silencioso).
//
//  El top de implementacion es el WRAPPER DEL BD (make_wrapper), no este
//  archivo: este modulo se agrega al BD como RTL module reference.
// ============================================================================
`timescale 1ns / 1ps

module soc_top_i2c_wrap #(
  parameter ADDR_W    = 16,
  parameter DEPTH     = 256,
  parameter AXI_AW    = 40,
  parameter FIFO_LOG2 = 8
)(
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi:m_axi, ASSOCIATED_RESET aresetn, FREQ_HZ 100000000" *)
  input  wire                 aclk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
  (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
  input  wire                 aresetn,

  // ---- esclavo AXI4-Lite (control + ventana IMEM/DMEM) ----
  input  wire [ADDR_W-1:0]    s_axi_awaddr,
  input  wire                 s_axi_awvalid,
  output wire                 s_axi_awready,
  input  wire [31:0]          s_axi_wdata,
  input  wire [3:0]           s_axi_wstrb,
  input  wire                 s_axi_wvalid,
  output wire                 s_axi_wready,
  output wire [1:0]           s_axi_bresp,
  output wire                 s_axi_bvalid,
  input  wire                 s_axi_bready,
  input  wire [ADDR_W-1:0]    s_axi_araddr,
  input  wire                 s_axi_arvalid,
  output wire                 s_axi_arready,
  output wire [31:0]          s_axi_rdata,
  output wire [1:0]           s_axi_rresp,
  output wire                 s_axi_rvalid,
  input  wire                 s_axi_rready,

  // ---- maestro AXI4 del dma_burst del SoC ----
  output wire [AXI_AW-1:0]    m_axi_awaddr,
  output wire [7:0]           m_axi_awlen,
  output wire [2:0]           m_axi_awsize,
  output wire [1:0]           m_axi_awburst,
  output wire                 m_axi_awvalid,
  input  wire                 m_axi_awready,
  output wire [31:0]          m_axi_wdata,
  output wire [3:0]           m_axi_wstrb,
  output wire                 m_axi_wlast,
  output wire                 m_axi_wvalid,
  input  wire                 m_axi_wready,
  input  wire [1:0]           m_axi_bresp,
  input  wire                 m_axi_bvalid,
  output wire                 m_axi_bready,
  output wire [AXI_AW-1:0]    m_axi_araddr,
  output wire [7:0]           m_axi_arlen,
  output wire [2:0]           m_axi_arsize,
  output wire [1:0]           m_axi_arburst,
  output wire                 m_axi_arvalid,
  input  wire                 m_axi_arready,
  input  wire [31:0]          m_axi_rdata,
  input  wire [1:0]           m_axi_rresp,
  input  wire                 m_axi_rlast,
  input  wire                 m_axi_rvalid,
  output wire                 m_axi_rready,

  output wire                 irq_out,       // doorbell del core -> pl_ps_irq0
  output wire                 i2c_irq_out,   // IRQ del IIC       -> pl_ps_irq1

  // ---- pads IIC (open-drain, PULLUP en el XDC) ----
  inout  wire                 scl,
  inout  wire                 sda
);

  wire scl_i, scl_t, sda_i, sda_t;

  // Open-drain: I=0 fijo; T='1' suelta la linea (queda al pull-up),
  // T='0' la jala a tierra. Identico patron al TXD half-duplex del USART.
  IOBUF u_iobuf_scl (.IO(scl), .O(scl_i), .I(1'b0), .T(scl_t));
  IOBUF u_iobuf_sda (.IO(sda), .O(sda_i), .I(1'b0), .T(sda_t));

  soc_top_i2c #(
    .ADDR_W    (ADDR_W),
    .DEPTH     (DEPTH),
    .AXI_AW    (AXI_AW),
    .FIFO_LOG2 (FIFO_LOG2)
  ) u_soc (
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

    .irq_out     (irq_out),
    .i2c_irq_out (i2c_irq_out),

    .scl_i (scl_i),
    .scl_t (scl_t),
    .sda_i (sda_i),
    .sda_t (sda_t)
  );

endmodule
