-- =============================================================================
--  spi_axi_top.vhd  -  IP core SPI completo: registros MMIO (esclavo) +
--                      FIFOs + motor SPI + DMA maestro AXI4 + IRQ
--  Licencia: MIT
--
--  Es el spi_mmio del paso 2 mas el spi_dma del paso 3 en un solo modulo,
--  listo para colgarse del subsistema de memoria del SoC (region planeada:
--  0x5000_0000, bits 31:28 = "0101") con su propio puerto maestro AXI4 hacia
--  la DDR via el NoC, igual que el dma_burst del SoC v3.
--
--  Mapa de registros (offset; acceso de 1 ciclo):
--    0x00 CTRL     (rw) [0]=en [1]=cpol [2]=cpha [3]=lsb_first
--                       [4]=sample_late [5]=cs_force [6]=irq_en
--                       [7]=loop_int (auto-test: MISO <= MOSI interno)
--    0x04 STATUS   (r)  [0]=busy [1]=tx_empty [2]=tx_full [3]=rx_empty
--                       [4]=rx_full [5]=rx_ovf* [6]=tx_ovf*
--                       [7]=dma_busy(pegajoso) [8]=dma_done*
--                  (w)  cualquier escritura limpia los stickies (*)
--    0x08 CLKDIV   (rw) medio periodo de SCLK en ciclos (1 -> 50 MHz)
--    0x0C TXDATA   (w)  push PIO al FIFO TX
--    0x10 RXDATA   (r)  pop PIO del FIFO RX
--    0x14 TXLVL    (r)  nivel FIFO TX      0x18 RXLVL (r) nivel FIFO RX
--    0x1C DMA_TXA  (rw) offset DDR de lectura (alineado a 4)
--    0x20 DMA_RXA  (rw) offset DDR de escritura (alineado a 4)
--    0x24 DMA_LEN  (rw) [23:0] longitud en BYTES
--    0x28 DMA_CTRL (w)  [0]=start [1]=tx_en [2]=rx_en [15:8]=dummy
--                  (r)  readback de tx_en/rx_en/dummy
--
--  dma_busy es pegajoso al estilo de mem_subsys_dma: sube en el mismo ciclo
--  del start (deteccion combinacional) y baja cuando el DMA de verdad
--  termino. dma_done sube al terminar y se limpia escribiendo STATUS o al
--  arrancar otra transferencia. irq_out = irq_en AND dma_done.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_axi_top is
  generic (
    DIV_W     : natural := 16;
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

    -- maestro AXI4 hacia la DDR
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

    -- pads SPI
    sclk_o : out std_logic;
    mosi_o : out std_logic;
    miso_i : in  std_logic;
    cs_n_o : out std_logic
  );
end entity spi_axi_top;

architecture rtl of spi_axi_top is
  -- registros de control
  signal en, cpol_r, cpha_r, lsbf_r, slate_r, csf_r, irqen_r : std_logic := '0';
  signal loopi_r : std_logic := '0';
  signal mosi_s, miso_eff : std_logic;
  signal clkdiv_r : unsigned(DIV_W-1 downto 0) := to_unsigned(4, DIV_W);
  signal tx_ovf, rx_ovf : std_logic := '0';

  -- registros del DMA
  signal txa_r, rxa_r : std_logic_vector(31 downto 0) := (others => '0');
  signal len_r        : unsigned(23 downto 0) := (others => '0');
  signal txen_r, rxen_r : std_logic := '0';
  signal dummy_r      : std_logic_vector(7 downto 0) := (others => '0');
  signal dma_start    : std_logic := '0';
  signal dma_go       : std_logic;
  signal dma_busy     : std_logic;
  signal busy_sticky, dma_started, done_sticky : std_logic := '0';

  -- motor
  signal eng_txd  : std_logic_vector(7 downto 0);
  signal eng_txv, eng_txr : std_logic;
  signal eng_rxd  : std_logic_vector(7 downto 0);
  signal eng_rxv, eng_busy : std_logic;
  signal eng_csn  : std_logic;

  -- FIFOs
  signal txf_wr, txf_full, txf_rd, txf_empty : std_logic;
  signal txf_rdata : std_logic_vector(7 downto 0);
  signal txf_wdata : std_logic_vector(7 downto 0);
  signal txf_lvl   : unsigned(FIFO_LOG2 downto 0);
  signal rxf_wr, rxf_full, rxf_rd, rxf_empty : std_logic;
  signal rxf_rdata : std_logic_vector(7 downto 0);
  signal rxf_lvl   : unsigned(FIFO_LOG2 downto 0);

  -- lados PIO y DMA de los FIFOs
  signal pio_tx_wr, pio_rx_rd : std_logic;
  signal dma_tx_wr, dma_rx_rd : std_logic;
  signal dma_tx_wdata : std_logic_vector(7 downto 0);

  signal wr_acc, rd_acc : std_logic;
begin

  wr_acc <= '1' when (sel = '1' and req = '1' and wstrb /= "0000") else '0';
  rd_acc <= '1' when (sel = '1' and req = '1' and wstrb  = "0000") else '0';

  pio_tx_wr <= '1' when (wr_acc = '1' and addr = x"0C") else '0';
  pio_rx_rd <= '1' when (rd_acc = '1' and addr = x"10") else '0';

  -- deteccion combinacional del start (para el busy pegajoso, mismo ciclo)
  dma_go <= '1' when (wr_acc = '1' and addr = x"28" and wdata(0) = '1') else '0';

  -- los FIFOs son del DMA mientras este corre; PIO el resto del tiempo
  txf_wr    <= dma_tx_wr when dma_busy = '1' else pio_tx_wr;
  txf_wdata <= dma_tx_wdata when dma_busy = '1' else wdata(7 downto 0);
  rxf_rd    <= dma_rx_rd when dma_busy = '1' else pio_rx_rd;

  u_txf : entity work.byte_fifo
    generic map (LOG2_DEPTH => FIFO_LOG2)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => txf_wr, wr_data => txf_wdata, full => txf_full,
      rd_en => txf_rd, rd_data => txf_rdata, empty => txf_empty,
      level => txf_lvl
    );

  u_rxf : entity work.byte_fifo
    generic map (LOG2_DEPTH => FIFO_LOG2)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => rxf_wr, wr_data => eng_rxd, full => rxf_full,
      rd_en => rxf_rd, rd_data => rxf_rdata, empty => rxf_empty,
      level => rxf_lvl
    );

  eng_txd <= txf_rdata;
  eng_txv <= '1' when (en = '1' and txf_empty = '0') else '0';
  txf_rd  <= eng_txr;
  rxf_wr  <= eng_rxv;

  u_eng : entity work.spi_engine
    generic map (DIV_W => DIV_W)
    port map (
      clk => clk, aresetn => aresetn,
      cpol => cpol_r, cpha => cpha_r, lsb_first => lsbf_r,
      clkdiv => clkdiv_r, sample_late => slate_r,
      tx_data => eng_txd, tx_valid => eng_txv, tx_ready => eng_txr,
      rx_data => eng_rxd, rx_valid => eng_rxv, busy => eng_busy,
      sclk_o => sclk_o, mosi_o => mosi_s, miso_i => miso_eff, cs_n_o => eng_csn
    );

  cs_n_o <= '0' when csf_r = '1' else eng_csn;

  -- loopback interno de auto-test (antes de los pads)
  mosi_o   <= mosi_s;
  miso_eff <= mosi_s when loopi_r = '1' else miso_i;

  u_dma : entity work.spi_dma
    generic map (ADDR_W => ADDR_W, FIFO_LOG2 => FIFO_LOG2)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => ddr_base,
      tx_addr => txa_r, rx_addr => rxa_r, nbytes => len_r,
      tx_en => txen_r, rx_en => rxen_r, dummy => dummy_r,
      start => dma_start, busy => dma_busy,
      txf_wr => dma_tx_wr, txf_wdata => dma_tx_wdata, txf_lvl => txf_lvl,
      rxf_rd => dma_rx_rd, rxf_rdata => rxf_rdata, rxf_lvl => rxf_lvl,
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

  irq_out <= irqen_r and done_sticky;

  -- escritura de registros, stickies y arranque del DMA
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        en <= '0'; cpol_r <= '0'; cpha_r <= '0';
        lsbf_r <= '0'; slate_r <= '0'; csf_r <= '0'; irqen_r <= '0';
        loopi_r <= '0';
        clkdiv_r <= to_unsigned(4, DIV_W);
        tx_ovf <= '0'; rx_ovf <= '0';
        txa_r <= (others => '0'); rxa_r <= (others => '0');
        len_r <= (others => '0');
        txen_r <= '0'; rxen_r <= '0'; dummy_r <= (others => '0');
        dma_start <= '0';
        busy_sticky <= '0'; dma_started <= '0'; done_sticky <= '0';
      else
        dma_start <= '0';

        if wr_acc = '1' then
          case addr is
            when x"00" =>
              en      <= wdata(0);
              cpol_r  <= wdata(1);
              cpha_r  <= wdata(2);
              lsbf_r  <= wdata(3);
              slate_r <= wdata(4);
              csf_r   <= wdata(5);
              irqen_r <= wdata(6);
              loopi_r <= wdata(7);
            when x"04" =>                -- limpia stickies
              tx_ovf <= '0'; rx_ovf <= '0'; done_sticky <= '0';
            when x"08" =>
              clkdiv_r <= unsigned(wdata(DIV_W-1 downto 0));
            when x"1C" => txa_r <= wdata;
            when x"20" => rxa_r <= wdata;
            when x"24" => len_r <= unsigned(wdata(23 downto 0));
            when x"28" =>
              txen_r  <= wdata(1);
              rxen_r  <= wdata(2);
              dummy_r <= wdata(15 downto 8);
              if wdata(0) = '1' then dma_start <= '1'; end if;
            when others => null;
          end case;
        end if;

        if txf_wr = '1' and txf_full = '1' then tx_ovf <= '1'; end if;
        if eng_rxv = '1' and rxf_full = '1' then rx_ovf <= '1'; end if;

        -- busy pegajoso + done, patron de mem_subsys_dma
        if dma_go = '1' then
          busy_sticky <= '1';
          done_sticky <= '0';
        end if;
        if dma_busy = '1' then
          dma_started <= '1';
        elsif dma_started = '1' then     -- el DMA estuvo activo y ya termino
          busy_sticky <= '0';
          dma_started <= '0';
          done_sticky <= '1';
        end if;
      end if;
    end if;
  end process;

  -- lectura combinacional (1 ciclo)
  process(all)
  begin
    rdata <= (others => '0');
    if sel = '1' then
      case addr is
        when x"00" =>
          rdata(0) <= en;      rdata(1) <= cpol_r;  rdata(2) <= cpha_r;
          rdata(3) <= lsbf_r;  rdata(4) <= slate_r; rdata(5) <= csf_r;
          rdata(6) <= irqen_r;
          rdata(7) <= loopi_r;
        when x"04" =>
          rdata(0) <= eng_busy;  rdata(1) <= txf_empty; rdata(2) <= txf_full;
          rdata(3) <= rxf_empty; rdata(4) <= rxf_full;
          rdata(5) <= rx_ovf;    rdata(6) <= tx_ovf;
          rdata(7) <= busy_sticky; rdata(8) <= done_sticky;
        when x"08" =>
          rdata(DIV_W-1 downto 0) <= std_logic_vector(clkdiv_r);
        when x"10" =>
          rdata(7 downto 0) <= rxf_rdata;
        when x"14" =>
          rdata(FIFO_LOG2 downto 0) <= std_logic_vector(txf_lvl);
        when x"18" =>
          rdata(FIFO_LOG2 downto 0) <= std_logic_vector(rxf_lvl);
        when x"1C" => rdata <= txa_r;
        when x"20" => rdata <= rxa_r;
        when x"24" => rdata(23 downto 0) <= std_logic_vector(len_r);
        when x"28" =>
          rdata(1) <= txen_r; rdata(2) <= rxen_r;
          rdata(15 downto 8) <= dummy_r;
        when others => null;
      end case;
    end if;
  end process;

end architecture rtl;
