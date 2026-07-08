-- =============================================================================
--  usart_mmio.vhd  -  Registros MMIO + FIFOs TX/RX + motor USART (modo PIO)
--  Licencia: MIT
--
--  Gemelo en estilo de spi_mmio.vhd: se cuelga del subsistema de memoria del
--  SoC via el decodificador externo (plan: 0x6000_0000, bits 31:28 = "0110")
--  y recibe el OFFSET en addr(7:0). Acceso de 1 ciclo (dmem_ready = '1'),
--  escrituras de palabra completa (wstrb solo distingue lectura/escritura).
--
--  Mapa de registros (offset):
--    0x00 CTRL    (rw) [0]=en [1]=tx_en [2]=rx_en [3]=par_en [4]=par_odd
--                      [5]=stop2 [6]=data7 [7]=loop_int (misma posicion que
--                      el SPI) [8]=flow_en [9]=half_dup
--    0x04 STAT    (r)  [0]=tx_busy [1]=tx_empty [2]=tx_full [3]=rx_empty
--                      [4]=rx_full [5]=rx_ovf* [6]=tx_ovf* [7]=frame_err*
--                      [8]=par_err* [9]=break* [10]=rx_busy [11]=cts_n
--                      [12]=rts_n   (* = sticky)
--                 (w)  cualquier escritura limpia los stickies
--    0x08 BAUD    (rw) K del NCO: K = baud * 16 * 2^32 / Fclk
--                      reset = 79164837 (115200 @ 100 MHz)
--    0x0C TXDATA  (w)  empuja wdata(7:0) al FIFO TX (lleno: tx_ovf, se tira)
--    0x10 RXDATA  (r)  cabeza del FIFO RX; el pop ocurre en el flanco
--    0x14 TXLVL   (r)  bytes en el FIFO TX
--    0x18 RXLVL   (r)  bytes en el FIFO RX
--    0x1C IRQ_EN  (rw) [0]=rx_wm [1]=tx_wm [2]=rx_idle [3]=err
--    0x20 IRQ_STAT(r)  causas crudas, mismos bits que IRQ_EN
--    0x24 WM      (rw) [FIFO_LOG2:0]=umbral RX, [16+FIFO_LOG2:16]=umbral TX
--    0x28 IDLE_TO (rw) timeout de linea ociosa en tiempos de bit (16 bits)
--
--  Causas de IRQ (nivel; irq_o = or(IRQ_EN and IRQ_STAT)):
--    rx_wm   : RXLVL >= WM.rx                      (se limpia al drenar)
--    tx_wm   : TXLVL <= WM.tx                      (pedir recarga)
--    rx_idle : linea ociosa IDLE_TO tiempos de bit con FIFO RX no vacio;
--              el contador se rearma con cada push, pop o actividad de linea,
--              asi que la causa cae sola al drenar el FIFO (estilo 16550)
--    err     : or de los cinco stickies de STAT (limpiar via STAT)
--
--  RTS_n / DE segun modo:
--    flow_en=1            : flow control con histeresis, se desactiva
--                           (rts_n='1') con RXLVL >= DEPTH-8 (colchon de ~2
--                           caracteres en vuelo) y se reactiva al bajar del
--                           umbral WM.rx. Requiere FIFO_LOG2 >= 4.
--    flow_en=0, half_dup=1: el pad lleva DE activo-alto para transceiver
--                           RS-485 externo (= tx_active, cubre el frame
--                           completo). Ojo: polaridad NO invertida.
--    flow_en=0, full dup  : rts_n='0' fijo (siempre listo).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity usart_mmio is
  generic (
    FIFO_LOG2 : natural := 8             -- 256 bytes por FIFO (TB usa 4)
  );
  port (
    clk     : in std_logic;
    aresetn : in std_logic;

    -- acceso MMIO estilo dmem (region ya decodificada afuera via sel)
    sel   : in  std_logic;
    req   : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);
    wdata : in  std_logic_vector(31 downto 0);
    wstrb : in  std_logic_vector(3 downto 0);
    rdata : out std_logic_vector(31 downto 0);

    irq_o : out std_logic;

    -- pads USART
    rxd_i      : in  std_logic;
    txd_line_i : in  std_logic;          -- readback de linea compartida (HD)
    txd_o      : out std_logic;
    txd_t      : out std_logic;
    cts_n_i    : in  std_logic;
    rts_n_o    : out std_logic;

    -- ganchos DMA (v1.1, capa 3). Con estos puertos en open/'0' el modulo es
    -- funcionalmente identico al validado en capa 2 (tb_usart_mmio corre sin
    -- cambios). El DMA empuja al FIFO TX y drena el FIFO RX en paralelo al
    -- PIO; software no debe mezclar PIO y DMA sobre el mismo FIFO a la vez.
    dma_txf_wr    : in  std_logic := '0';
    dma_txf_wdata : in  std_logic_vector(7 downto 0) := (others => '0');
    dma_rxf_rd    : in  std_logic := '0';
    dma_rxf_rdata : out std_logic_vector(7 downto 0);
    dma_txf_lvl   : out unsigned(FIFO_LOG2 downto 0);
    dma_rxf_lvl   : out unsigned(FIFO_LOG2 downto 0);
    dma_rx_push   : out std_logic;
    dma_rx_busy   : out std_logic;
    dma_bit_tick  : out std_logic;
    dma_idle_to   : out unsigned(15 downto 0)
  );
end entity usart_mmio;

architecture rtl of usart_mmio is
  constant DEPTH  : natural := 2**FIFO_LOG2;
  constant RTS_HI : natural := DEPTH - 8;

  -- registros de control
  signal en_r, txen_r, rxen_r          : std_logic := '0';
  signal paren_r, parodd_r, stop2_r    : std_logic := '0';
  signal data7_r, loop_r, flow_r, hd_r : std_logic := '0';
  signal baud_r   : unsigned(31 downto 0) := to_unsigned(79164837, 32);
  signal irqen_r  : std_logic_vector(3 downto 0) := (others => '0');
  signal wm_rx    : unsigned(FIFO_LOG2 downto 0) := to_unsigned(DEPTH/2, FIFO_LOG2+1);
  signal wm_tx    : unsigned(FIFO_LOG2 downto 0) := to_unsigned(DEPTH/4, FIFO_LOG2+1);
  signal idleto_r : unsigned(15 downto 0) := to_unsigned(40, 16);

  -- stickies
  signal rx_ovf, tx_ovf, ferr_s, perr_s, brk_s : std_logic := '0';

  -- motor
  signal eng_txv, eng_txr, eng_rxv     : std_logic;
  signal eng_rxd                       : std_logic_vector(7 downto 0);
  signal e_ferr, e_perr, e_brk         : std_logic;
  signal e_txbusy, e_rxbusy, e_bittick : std_logic;
  signal e_txact                       : std_logic;

  -- FIFOs
  signal txf_wr, txf_full, txf_rd, txf_empty : std_logic;
  signal txf_rdata : std_logic_vector(7 downto 0);
  signal txf_lvl   : unsigned(FIFO_LOG2 downto 0);
  signal rxf_wr, rxf_full, rxf_rd, rxf_empty : std_logic;
  signal rxf_rdata : std_logic_vector(7 downto 0);
  signal rxf_lvl   : unsigned(FIFO_LOG2 downto 0);

  -- idle timeout + RTS + sync de CTS para STAT
  signal idle_cnt  : unsigned(15 downto 0) := (others => '0');
  signal rts_state : std_logic := '0';
  signal rts_n_int : std_logic;
  signal cts_m, cts_s : std_logic := '1';

  -- causas de IRQ
  signal c_rxwm, c_txwm, c_idle, c_err : std_logic;

  signal wr_acc, rd_acc : std_logic;

  -- muxes PIO/DMA hacia los FIFOs (v1.1)
  signal pio_txf_wr, pio_rxf_rd : std_logic;
  signal txf_wsel : std_logic_vector(7 downto 0);
begin

  assert FIFO_LOG2 >= 4
    report "usart_mmio: FIFO_LOG2 < 4 rompe la histeresis de RTS (DEPTH-8)"
    severity failure;

  -- un acceso valido por ciclo (dmem_req dura 1 ciclo con dmem_ready = '1')
  wr_acc <= '1' when (sel = '1' and req = '1' and wstrb /= "0000") else '0';
  rd_acc <= '1' when (sel = '1' and req = '1' and wstrb  = "0000") else '0';

  pio_txf_wr <= '1' when (wr_acc = '1' and addr = x"0C") else '0';
  pio_rxf_rd <= '1' when (rd_acc = '1' and addr = x"10") else '0';

  txf_wr   <= pio_txf_wr or dma_txf_wr;
  rxf_rd   <= pio_rxf_rd or dma_rxf_rd;
  txf_wsel <= dma_txf_wdata when dma_txf_wr = '1' else wdata(7 downto 0);

  u_txf : entity work.byte_fifo
    generic map (LOG2_DEPTH => FIFO_LOG2)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => txf_wr, wr_data => txf_wsel, full => txf_full,
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

  rxf_wr  <= eng_rxv;                    -- push directo; lleno -> drop + sticky
  eng_txv <= not txf_empty;              -- FWFT: cabeza siempre lista

  u_eng : entity work.usart_engine
    port map (
      clk => clk, rst_n => aresetn,
      en => en_r, tx_en => txen_r, rx_en => rxen_r,
      par_en => paren_r, par_odd => parodd_r, stop2 => stop2_r,
      data7 => data7_r, flow_en => flow_r, half_dup => hd_r,
      loop_int => loop_r,
      baud_k => std_logic_vector(baud_r),
      tx_valid => eng_txv, tx_data => txf_rdata, tx_ready => eng_txr,
      rx_valid => eng_rxv, rx_data => eng_rxd,
      frame_err => e_ferr, par_err => e_perr, break_det => e_brk,
      tx_busy => e_txbusy, rx_busy => e_rxbusy, bit_tick => e_bittick,
      rxd_i => rxd_i, txd_line_i => txd_line_i,
      txd_o => txd_o, txd_t => txd_t,
      cts_n_i => cts_n_i, tx_active => e_txact
    );

  txf_rd <= eng_txr;                     -- el pop del FIFO TX es el pop del motor

  -- exports hacia usart_dma (v1.1)
  dma_rxf_rdata <= rxf_rdata;
  dma_txf_lvl   <= txf_lvl;
  dma_rxf_lvl   <= rxf_lvl;
  dma_rx_push   <= eng_rxv;
  dma_rx_busy   <= e_rxbusy;
  dma_bit_tick  <= e_bittick;
  dma_idle_to   <= idleto_r;

  -- escritura de registros + stickies + idle timeout + histeresis de RTS
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        en_r <= '0'; txen_r <= '0'; rxen_r <= '0';
        paren_r <= '0'; parodd_r <= '0'; stop2_r <= '0';
        data7_r <= '0'; loop_r <= '0'; flow_r <= '0'; hd_r <= '0';
        baud_r   <= to_unsigned(79164837, 32);
        irqen_r  <= (others => '0');
        wm_rx    <= to_unsigned(DEPTH/2, FIFO_LOG2+1);
        wm_tx    <= to_unsigned(DEPTH/4, FIFO_LOG2+1);
        idleto_r <= to_unsigned(40, 16);
        rx_ovf <= '0'; tx_ovf <= '0';
        ferr_s <= '0'; perr_s <= '0'; brk_s <= '0';
        idle_cnt  <= (others => '0');
        rts_state <= '0';
      else
        if wr_acc = '1' then
          case addr is
            when x"00" =>
              en_r     <= wdata(0);
              txen_r   <= wdata(1);
              rxen_r   <= wdata(2);
              paren_r  <= wdata(3);
              parodd_r <= wdata(4);
              stop2_r  <= wdata(5);
              data7_r  <= wdata(6);
              loop_r   <= wdata(7);
              flow_r   <= wdata(8);
              hd_r     <= wdata(9);
            when x"04" =>                -- limpia los stickies
              rx_ovf <= '0'; tx_ovf <= '0';
              ferr_s <= '0'; perr_s <= '0'; brk_s <= '0';
            when x"08" =>
              baud_r <= unsigned(wdata);
            when x"1C" =>
              irqen_r <= wdata(3 downto 0);
            when x"24" =>
              wm_rx <= unsigned(wdata(FIFO_LOG2 downto 0));
              wm_tx <= unsigned(wdata(16 + FIFO_LOG2 downto 16));
            when x"28" =>
              idleto_r <= unsigned(wdata(15 downto 0));
            when others => null;
          end case;
        end if;

        -- stickies: overflows con politica drop, eventos del motor
        if txf_wr = '1' and txf_full = '1' then
          tx_ovf <= '1';                 -- push a FIFO lleno: byte descartado
        end if;
        if eng_rxv = '1' and rxf_full = '1' then
          rx_ovf <= '1';                 -- byte recibido sin lugar: descartado
        end if;
        if e_ferr = '1' then ferr_s <= '1'; end if;
        if e_perr = '1' then perr_s <= '1'; end if;
        if e_brk  = '1' then brk_s  <= '1'; end if;

        -- idle timeout: cuenta tiempos de bit con datos pendientes y linea
        -- ociosa; se rearma con push, pop o actividad de linea
        if eng_rxv = '1' or rxf_rd = '1' or e_rxbusy = '1' or rxf_empty = '1' then
          idle_cnt <= (others => '0');
        elsif e_bittick = '1' and idle_cnt /= idleto_r then
          idle_cnt <= idle_cnt + 1;
        end if;

        -- histeresis de RTS (solo tiene efecto con flow_en=1)
        if rxf_lvl >= RTS_HI then
          rts_state <= '1';
        elsif rxf_lvl < wm_rx then
          rts_state <= '0';
        end if;
      end if;
    end if;
  end process;

  -- sync de CTS solo para observabilidad en STAT (el motor trae su propio 2FF)
  process(clk)
  begin
    if rising_edge(clk) then
      cts_m <= cts_n_i;
      cts_s <= cts_m;
    end if;
  end process;

  -- causas de IRQ (nivel)
  c_rxwm <= '1' when rxf_lvl >= wm_rx else '0';
  c_txwm <= '1' when txf_lvl <= wm_tx else '0';
  c_idle <= '1' when rxf_empty = '0' and idleto_r /= 0 and idle_cnt = idleto_r
                else '0';
  c_err  <= rx_ovf or tx_ovf or ferr_s or perr_s or brk_s;

  irq_o <= (irqen_r(0) and c_rxwm) or (irqen_r(1) and c_txwm) or
           (irqen_r(2) and c_idle) or (irqen_r(3) and c_err);

  -- RTS_n / DE segun modo (ver cabecera)
  rts_n_int <= e_txact   when (hd_r = '1' and flow_r = '0') else  -- DE RS-485
               rts_state when flow_r = '1'                  else
               '0';
  rts_n_o <= rts_n_int;

  -- lectura combinacional (1 ciclo, como los registros del DMA)
  process(all)
  begin
    rdata <= (others => '0');
    if sel = '1' then
      case addr is
        when x"00" =>
          rdata(0) <= en_r;     rdata(1) <= txen_r;   rdata(2) <= rxen_r;
          rdata(3) <= paren_r;  rdata(4) <= parodd_r; rdata(5) <= stop2_r;
          rdata(6) <= data7_r;  rdata(7) <= loop_r;   rdata(8) <= flow_r;
          rdata(9) <= hd_r;
        when x"04" =>
          rdata(0)  <= e_txbusy;  rdata(1)  <= txf_empty; rdata(2) <= txf_full;
          rdata(3)  <= rxf_empty; rdata(4)  <= rxf_full;
          rdata(5)  <= rx_ovf;    rdata(6)  <= tx_ovf;
          rdata(7)  <= ferr_s;    rdata(8)  <= perr_s;    rdata(9) <= brk_s;
          rdata(10) <= e_rxbusy;  rdata(11) <= cts_s;     rdata(12) <= rts_n_int;
        when x"08" =>
          rdata <= std_logic_vector(baud_r);
        when x"10" =>
          rdata(7 downto 0) <= rxf_rdata;
        when x"14" =>
          rdata(FIFO_LOG2 downto 0) <= std_logic_vector(txf_lvl);
        when x"18" =>
          rdata(FIFO_LOG2 downto 0) <= std_logic_vector(rxf_lvl);
        when x"1C" =>
          rdata(3 downto 0) <= irqen_r;
        when x"20" =>
          rdata(0) <= c_rxwm; rdata(1) <= c_txwm;
          rdata(2) <= c_idle; rdata(3) <= c_err;
        when x"24" =>
          rdata(FIFO_LOG2 downto 0)           <= std_logic_vector(wm_rx);
          rdata(16 + FIFO_LOG2 downto 16)     <= std_logic_vector(wm_tx);
        when x"28" =>
          rdata(15 downto 0) <= std_logic_vector(idleto_r);
        when others => null;
      end case;
    end if;
  end process;

end architecture rtl;
