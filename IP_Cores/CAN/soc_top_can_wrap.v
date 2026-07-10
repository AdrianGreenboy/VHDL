// ============================================================================
//  soc_top_can_wrap.v - Wrapper Verilog del SoC v3 + IP CAN para el BD
//  Licencia: MIT
//
//  Patron heredado del I3C/IIC/USART: los IOBUF viven DENTRO del wrapper, asi
//  el BD ve un pad inout unico (can_bus) y un solo bitstream sirve para
//  LOOP_INT (pads liberados, trafico interno) y para un transceptor externo.
//
//  DIFERENCIA frente al I3C: el CAN tiene UN solo par can_tx/can_rx, no dos
//  lineas scl/sda. Un unico IOBUF con I/T dinamicos:
//    can_tx_t = '1' suelta la linea (recesivo, queda al pull-up del bus),
//    can_tx_t = '0' conduce can_tx_o (dominante = '0').
//  can_rx_i lee el estado del bus (el receptor del transceptor en la placa).
//
//  En modo transceptor real (p. ej. SN65HVD230), can_bus NO va directo al
//  par CAN_H/CAN_L: va a los pines TXD/RXD del transceptor. Como el
//  transceptor ya separa TX y RX, en esa topologia se usan DOS pads (uno a
//  TXD, otro desde RXD) y este IOBUF unico se sustituye por un OBUF+IBUF.
//  Para el bring-up en LOOP_INT no se conduce el pad: T=1 siempre y can_rx_i
//  lo alimenta el propio can_mmio internamente, por lo que un IOBUF unico
//  basta y deja el pad libre. (Ver can_pins.xdc: pregunta abierta D10/C10.)
//
//  ASSOCIATED_BUSIF en aclk: s_axi y m_axi (leccion USART: sin esto los SIs
//  del NoC quedan colgados de aclk0 y hay CDC silencioso).
//
//  El top de implementacion es el WRAPPER DEL BD (make_wrapper), no este
//  archivo: este modulo se agrega al BD como RTL module reference.
// ============================================================================
`timescale 1ns / 1ps

module soc_top_can_wrap #(
  parameter ADDR_W = 16,
  parameter DEPTH  = 256,
  parameter AXI_AW = 40
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
  output wire                 can_irq_out,   // IRQ del CAN       -> pl_ps_irq1

  // ---- pad CAN (I/T dinamicos, PULLUP en el XDC) ----
  inout  wire                 can_bus
);

  wire can_rx_i, can_tx_o, can_tx_t;

  // Un unico IOBUF: T='1' libera (recesivo), T='0' conduce dominante.
  // En LOOP_INT el can_mmio mantiene can_tx_t='1' (pad libre) y alimenta su
  // propio can_rx internamente; can_rx_i queda como '1' (recesivo).
  IOBUF u_iobuf_can (.IO(can_bus), .O(can_rx_i), .I(can_tx_o), .T(can_tx_t));

  soc_top_can #(
    .ADDR_W (ADDR_W),
    .DEPTH  (DEPTH),
    .AXI_AW (AXI_AW)
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
    .can_irq_out (can_irq_out),

    .can_rx_i (can_rx_i),
    .can_tx_o (can_tx_o),
    .can_tx_t (can_tx_t)
  );

endmodule
