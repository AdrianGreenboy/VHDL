-- =============================================================================
--  usart_axi_top.vhd  -  IP core USART completo: usart_mmio (regs + FIFOs +
--                        motor) + usart_dma (dos canales AXI4) + IRQ
--  Licencia: MIT
--
--  Gemelo estructural del spi_axi_top, pero componiendo los modulos ya
--  validados en vez de replicar el regfile: usart_mmio v1.1 atiende los
--  offsets 0x00-0x28 (via sel gateado) y este top agrega los registros DMA
--  en 0x30+. Region planeada del SoC: 0x6000_0000, bits 31:28 = "0110".
--
--  Registros DMA (offset; acceso de 1 ciclo; 0x00-0x28 ver usart_mmio.vhd):
--    0x30 DMA_TXA   (rw) offset DDR de lectura, alineado a 4
--    0x34 DMA_TXLEN (rw) [23:0] bytes del canal TX
--    0x38 DMA_RXA   (rw) offset DDR de escritura, alineado a 4
--    0x3C DMA_RXLEN (rw) [23:0] bytes maximos del canal RX
--    0x40 DMA_CTRL  (w)  [0]=tx_start [1]=rx_start [2]=rx_abort
--                        [4]=irq_en_txdone [5]=irq_en_rxdone
--                        (los bits [5:4] se actualizan en CADA escritura)
--                   (r)  readback de [5:4]
--    0x44 DMA_STAT  (r)  [0]=tx_busy(pegajoso) [1]=rx_busy(pegajoso)
--                        [2]=tx_done* [3]=rx_done* [4]=rx_flushed*
--                        [5]=tx_rerr* [6]=rx_berr*
--                   (w)  cualquier escritura limpia los stickies (*)
--    0x48 DMA_RXCNT (r)  bytes realmente escritos a DDR (valido en done)
--
--  Semantica de done: tx_done = el DMA termino de MOVER bytes a los FIFOs,
--  no de transmitirlos por la linea; para fin de linea usar STAT.tx_empty y
--  tx_busy del MMIO. rx_done llega por cuenta, por idle-flush (rx_flushed=1,
--  RX_COUNT parcial) o por abort. Los busy pegajosos suben en el mismo ciclo
--  del start (deteccion combinacional, patron de mem_subsys_dma/spi_axi_top)
--  y bajan con el done real del canal.
--
--  irq_out = irq del MMIO (watermarks/idle/err segun IRQ_EN)
--            or (irq_en_txdone and tx_done) or (irq_en_rxdone and rx_done).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity usart_axi_top is
  generic (
    FIFO_LOG2 : natural := 8;
    ADDR_W    : natural := 40
  );
  port (
    clk      : in std_logic;
    aresetn  : in std_logic;
    ddr_base : in std_logic_vector(ADDR_W-1 downto 0);

    -- acceso MMIO estilo dmem (region ya decodificada afuera via sel)
    sel   : in  std_logic;
    req   : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);
    wdata : in  std_logic_vector(31 downto 0);
    wstrb : in  std_logic_vector(3 downto 0);
    rdata : out std_logic_vector(31 downto 0);

    irq_out : out std_logic;

    -- maestro AXI4 hacia la DDR (AR/R = canal TX, AW/W/B = canal RX)
    m_axi_awaddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic;
    m_axi_araddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic;

    -- pads USART
    rxd_i      : in  std_logic;
    txd_line_i : in  std_logic;
    txd_o      : out std_logic;
    txd_t      : out std_logic;
    cts_n_i    : in  std_logic;
    rts_n_o    : out std_logic
  );
end entity usart_axi_top;

architecture rtl of usart_axi_top is
  -- decode interno: 0x00-0x2F -> usart_mmio, 0x30+ -> registros DMA locales
  signal sel_mmio   : std_logic;
  signal rdata_mmio : std_logic_vector(31 downto 0);
  signal rdata_dma  : std_logic_vector(31 downto 0);
  signal mmio_irq   : std_logic;

  -- registros del DMA
  signal txa_r, rxa_r     : std_logic_vector(31 downto 0) := (others => '0');
  signal txlen_r, rxlen_r : unsigned(23 downto 0) := (others => '0');
  signal ientx_r, ienrx_r : std_logic := '0';
  signal tx_start_p, rx_start_p, rx_abort_p : std_logic := '0';
  signal go_tx, go_rx     : std_logic;

  -- stickies (busy pegajoso + dones + errores de respuesta)
  signal txb_s, rxb_s : std_logic := '0';
  signal txd_s, rxd_s : std_logic := '0';
  signal rxf_s        : std_logic := '0';
  signal terr_s, berr_s : std_logic := '0';

  -- cables del DMA
  signal d_txdone, d_txrerr           : std_logic;
  signal d_rxdone, d_rxflush, d_rxberr : std_logic;
  signal d_rxcnt : unsigned(23 downto 0);

  -- ganchos mmio <-> dma
  signal h_txf_wr    : std_logic;
  signal h_txf_wdata : std_logic_vector(7 downto 0);
  signal h_rxf_rd    : std_logic;
  signal h_rxf_rdata : std_logic_vector(7 downto 0);
  signal h_txf_lvl   : unsigned(FIFO_LOG2 downto 0);
  signal h_rxf_lvl   : unsigned(FIFO_LOG2 downto 0);
  signal h_rx_push, h_rx_busy, h_bit_tick : std_logic;
  signal h_idle_to   : unsigned(15 downto 0);

  signal wr_acc : std_logic;
begin

  wr_acc <= '1' when (sel = '1' and req = '1' and wstrb /= "0000") else '0';

  sel_mmio <= sel when unsigned(addr) < to_unsigned(16#30#, 8) else '0';
  rdata    <= rdata_mmio when unsigned(addr) < to_unsigned(16#30#, 8) else
              rdata_dma;

  u_mmio : entity work.usart_mmio
    generic map (FIFO_LOG2 => FIFO_LOG2)
    port map (
      clk => clk, aresetn => aresetn,
      sel => sel_mmio, req => req, addr => addr,
      wdata => wdata, wstrb => wstrb, rdata => rdata_mmio,
      irq_o => mmio_irq,
      rxd_i => rxd_i, txd_line_i => txd_line_i,
      txd_o => txd_o, txd_t => txd_t,
      cts_n_i => cts_n_i, rts_n_o => rts_n_o,
      dma_txf_wr => h_txf_wr, dma_txf_wdata => h_txf_wdata,
      dma_rxf_rd => h_rxf_rd, dma_rxf_rdata => h_rxf_rdata,
      dma_txf_lvl => h_txf_lvl, dma_rxf_lvl => h_rxf_lvl,
      dma_rx_push => h_rx_push, dma_rx_busy => h_rx_busy,
      dma_bit_tick => h_bit_tick, dma_idle_to => h_idle_to
    );

  u_dma : entity work.usart_dma
    generic map (ADDR_W => ADDR_W, FIFO_LOG2 => FIFO_LOG2)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => ddr_base,
      tx_addr => txa_r, tx_len => txlen_r,
      tx_start => tx_start_p, tx_busy => open,
      tx_done => d_txdone, tx_rerr => d_txrerr,
      rx_addr => rxa_r, rx_len => rxlen_r,
      rx_start => rx_start_p, rx_abort => rx_abort_p,
      rx_busy => open, rx_done => d_rxdone, rx_flushed => d_rxflush,
      rx_berr => d_rxberr, rx_count => d_rxcnt,
      idle_to => h_idle_to,
      txf_wr => h_txf_wr, txf_wdata => h_txf_wdata, txf_lvl => h_txf_lvl,
      rxf_rd => h_rxf_rd, rxf_rdata => h_rxf_rdata, rxf_lvl => h_rxf_lvl,
      rx_push => h_rx_push, rx_line_busy => h_rx_busy, bit_tick => h_bit_tick,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen,
      m_axi_awsize => m_axi_awsize, m_axi_awburst => m_axi_awburst,
      m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb,
      m_axi_wlast => m_axi_wlast, m_axi_wvalid => m_axi_wvalid,
      m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid,
      m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen,
      m_axi_arsize => m_axi_arsize, m_axi_arburst => m_axi_arburst,
      m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp,
      m_axi_rlast => m_axi_rlast, m_axi_rvalid => m_axi_rvalid,
      m_axi_rready => m_axi_rready
    );

  -- deteccion combinacional del start (busy pegajoso en el mismo ciclo)
  go_tx <= '1' when (wr_acc = '1' and addr = x"40" and wdata(0) = '1') else '0';
  go_rx <= '1' when (wr_acc = '1' and addr = x"40" and wdata(1) = '1') else '0';

  irq_out <= mmio_irq or (ientx_r and txd_s) or (ienrx_r and rxd_s);

  -- escritura de registros DMA + stickies
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        txa_r <= (others => '0'); rxa_r <= (others => '0');
        txlen_r <= (others => '0'); rxlen_r <= (others => '0');
        ientx_r <= '0'; ienrx_r <= '0';
        tx_start_p <= '0'; rx_start_p <= '0'; rx_abort_p <= '0';
        txb_s <= '0'; rxb_s <= '0'; txd_s <= '0'; rxd_s <= '0';
        rxf_s <= '0'; terr_s <= '0'; berr_s <= '0';
      else
        tx_start_p <= '0';
        rx_start_p <= '0';
        rx_abort_p <= '0';

        if wr_acc = '1' then
          case addr is
            when x"30" => txa_r <= wdata;
            when x"34" => txlen_r <= unsigned(wdata(23 downto 0));
            when x"38" => rxa_r <= wdata;
            when x"3C" => rxlen_r <= unsigned(wdata(23 downto 0));
            when x"40" =>
              ientx_r <= wdata(4);
              ienrx_r <= wdata(5);
              if wdata(0) = '1' then tx_start_p <= '1'; end if;
              if wdata(1) = '1' then rx_start_p <= '1'; end if;
              if wdata(2) = '1' then rx_abort_p <= '1'; end if;
            when x"44" =>                -- limpia stickies
              txd_s <= '0'; rxd_s <= '0'; rxf_s <= '0';
              terr_s <= '0'; berr_s <= '0';
            when others => null;
          end case;
        end if;

        -- busy pegajoso desde el ciclo del start; done real lo baja
        if go_tx = '1' then txb_s <= '1'; txd_s <= '0'; end if;
        if go_rx = '1' then rxb_s <= '1'; rxd_s <= '0'; rxf_s <= '0'; end if;

        if d_txdone = '1' then txb_s <= '0'; txd_s <= '1'; end if;
        if d_rxdone = '1' then
          rxb_s <= '0';
          rxd_s <= '1';
          if d_rxflush = '1' then rxf_s <= '1'; end if;
        end if;

        if d_txrerr = '1' then terr_s <= '1'; end if;
        if d_rxberr = '1' then berr_s <= '1'; end if;
      end if;
    end if;
  end process;

  -- lectura combinacional de los registros DMA (1 ciclo)
  process(all)
  begin
    rdata_dma <= (others => '0');
    if sel = '1' then
      case addr is
        when x"30" => rdata_dma <= txa_r;
        when x"34" => rdata_dma(23 downto 0) <= std_logic_vector(txlen_r);
        when x"38" => rdata_dma <= rxa_r;
        when x"3C" => rdata_dma(23 downto 0) <= std_logic_vector(rxlen_r);
        when x"40" =>
          rdata_dma(4) <= ientx_r; rdata_dma(5) <= ienrx_r;
        when x"44" =>
          rdata_dma(0) <= txb_s;  rdata_dma(1) <= rxb_s;
          rdata_dma(2) <= txd_s;  rdata_dma(3) <= rxd_s;
          rdata_dma(4) <= rxf_s;
          rdata_dma(5) <= terr_s; rdata_dma(6) <= berr_s;
        when x"48" =>
          rdata_dma(23 downto 0) <= std_logic_vector(d_rxcnt);
        when others => null;
      end case;
    end if;
  end process;

end architecture rtl;
