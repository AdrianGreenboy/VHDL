-- =============================================================================
--  usart_dma.vhd  -  Maestro AXI4 de dos canales para el IP USART
--  Licencia: MIT
--
--  Primo del spi_dma, con una diferencia arquitectonica deliberada: aqui NO
--  hay FSM unico ni prioridades. El UART no es full-duplex acoplado (TX y RX
--  ocurren cuando quieren, con longitudes distintas), asi que el DMA son DOS
--  CANALES INDEPENDIENTES que corren en paralelo sobre el mismo m_axi:
--
--    Canal TX : DDR -> FIFO TX.  Usa SOLO el canal de lectura AXI (AR/R).
--    Canal RX : FIFO RX -> DDR.  Usa SOLO el canal de escritura (AW/W/B).
--
--  Como AXI define lectura y escritura como canales independientes, ambos
--  motores comparten el puerto maestro SIN arbitro.
--
--  Heredado de dma_burst/spi_dma: rafagas INCR de hasta 16 beats, troceo en
--  fronteras de 4 KB (cap 1024 - addr(11:2)), LEN en bytes con ultimo beat
--  parcial via wstrb enmascarado, tx_addr/rx_addr como offsets DDR sobre
--  ddr_base ALINEADOS a 4 bytes, byte 0 de cada palabra = primer byte en la
--  linea (little-endian, consistente con la memoria del RV32).
--
--  Terminacion del canal RX (la novedad; sin esto el DMA RX es inusable con
--  trafico real): el canal cierra por CUENTA (rx_count == rx_len) o por
--  IDLE-FLUSH: linea ociosa idle_to tiempos de bit despues de haber recibido
--  al menos un byte -> drena el residuo del FIFO con rafaga parcial, termina
--  con rx_done + rx_flushed y deja en rx_count los bytes realmente escritos.
--  El contador de idle es PROPIO (no el del MMIO, que se congela con FIFO
--  vacio): se rearma con cada push del motor o actividad de linea, y solo
--  arma despues del primer byte, asi que un DMA esperando un paquete no se
--  vence antes de que el paquete empiece. rx_abort (atendido en la frontera
--  entre rafagas, nunca a media transaccion AXI) permite cancelar un canal
--  armado que nunca recibio nada.
--
--  Contrato con usart_mmio v1.1: los FIFOs viven alla; este modulo empuja
--  (dma_txf_*) y drena (dma_rxf_*) via los ganchos. Los pops del DMA rearman
--  el idle-timeout del MMIO igual que los pops de PIO.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity usart_dma is
  generic (
    ADDR_W    : natural := 40;
    FIFO_LOG2 : natural := 8
  );
  port (
    clk      : in std_logic;
    aresetn  : in std_logic;
    ddr_base : in std_logic_vector(ADDR_W-1 downto 0);

    -- comando canal TX (estable durante la transferencia)
    tx_addr  : in  std_logic_vector(31 downto 0);  -- offset DDR (lectura)
    tx_len   : in  unsigned(23 downto 0);          -- bytes
    tx_start : in  std_logic;                      -- pulso
    tx_busy  : out std_logic;
    tx_done  : out std_logic;                      -- pulso
    tx_rerr  : out std_logic;                      -- pulso: RRESP /= OKAY

    -- comando canal RX
    rx_addr    : in  std_logic_vector(31 downto 0); -- offset DDR (escritura)
    rx_len     : in  unsigned(23 downto 0);         -- bytes maximos
    rx_start   : in  std_logic;                     -- pulso
    rx_abort   : in  std_logic;                     -- pulso
    rx_busy    : out std_logic;
    rx_done    : out std_logic;                     -- pulso
    rx_flushed : out std_logic;                     -- con rx_done: cerro por idle
    rx_berr    : out std_logic;                     -- pulso: BRESP /= OKAY
    rx_count   : out unsigned(23 downto 0);         -- bytes escritos a DDR

    idle_to : in unsigned(15 downto 0);             -- en tiempos de bit (del MMIO)

    -- ganchos hacia usart_mmio v1.1
    txf_wr    : out std_logic;
    txf_wdata : out std_logic_vector(7 downto 0);
    txf_lvl   : in  unsigned(FIFO_LOG2 downto 0);
    rxf_rd    : out std_logic;
    rxf_rdata : in  std_logic_vector(7 downto 0);
    rxf_lvl   : in  unsigned(FIFO_LOG2 downto 0);
    rx_push      : in std_logic;                    -- eng_rxv del MMIO
    rx_line_busy : in std_logic;                    -- rx_busy del motor
    bit_tick     : in std_logic;

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
    m_axi_rready  : out std_logic
  );
end entity usart_dma;

architecture rtl of usart_dma is
  constant DEPTH : natural := 2**FIFO_LOG2;

  -- canal TX (lectura DDR -> FIFO TX)
  type txs_t is (T_IDLE, T_DEC, T_AR, T_BEAT, T_PUSH);
  signal ts       : txs_t := T_IDLE;
  signal tx_left  : unsigned(23 downto 0) := (others => '0');
  signal txa_c    : unsigned(ADDR_W-1 downto 0) := (others => '0');
  signal t_beats  : unsigned(4 downto 0) := (others => '0');
  signal t_bytes  : unsigned(6 downto 0) := (others => '0');
  signal t_beatb  : unsigned(2 downto 0) := (others => '0');
  signal t_bidx   : unsigned(1 downto 0) := "00";
  signal arlen_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal t_word   : std_logic_vector(31 downto 0) := (others => '0');

  -- canal RX (FIFO RX -> escritura DDR)
  type rxs_t is (X_IDLE, X_DEC, X_AW, X_COL, X_BEAT, X_RESP);
  signal xs       : rxs_t := X_IDLE;
  signal rx_left  : unsigned(23 downto 0) := (others => '0');
  signal rxa_c    : unsigned(ADDR_W-1 downto 0) := (others => '0');
  signal x_beats  : unsigned(4 downto 0) := (others => '0');
  signal x_bytes  : unsigned(6 downto 0) := (others => '0');
  signal x_beatb  : unsigned(2 downto 0) := (others => '0');
  signal x_colc    : unsigned(2 downto 0) := (others => '0');
  signal x_bidx   : unsigned(1 downto 0) := "00";
  signal awlen_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal x_word   : std_logic_vector(31 downto 0) := (others => '0');
  signal x_strb   : std_logic_vector(3 downto 0) := "0000";
  signal rx_cnt_r : unsigned(23 downto 0) := (others => '0');

  -- idle-flush propio del canal RX
  signal ic        : unsigned(15 downto 0) := (others => '0');
  signal flush_hit : std_logic;

  function fmin(a, b : natural) return natural is
  begin
    if a < b then return a; else return b; end if;
  end function;
begin

  ------------------------------------------------------------------------------
  -- lados AXI fijos y muxes de canal
  ------------------------------------------------------------------------------
  m_axi_arsize  <= "010";
  m_axi_arburst <= "01";
  m_axi_arlen   <= arlen_r;
  m_axi_araddr  <= std_logic_vector(txa_c);
  m_axi_arvalid <= '1' when ts = T_AR   else '0';
  m_axi_rready  <= '1' when ts = T_BEAT else '0';

  m_axi_awsize  <= "010";
  m_axi_awburst <= "01";
  m_axi_awlen   <= awlen_r;
  m_axi_awaddr  <= std_logic_vector(rxa_c);
  m_axi_awvalid <= '1' when xs = X_AW   else '0';
  m_axi_wvalid  <= '1' when xs = X_BEAT else '0';
  m_axi_wdata   <= x_word;
  m_axi_wstrb   <= x_strb;
  m_axi_wlast   <= '1' when (xs = X_BEAT and x_beats = 1) else '0';
  m_axi_bready  <= '1' when xs = X_RESP else '0';

  tx_busy  <= '0' when ts = T_IDLE else '1';
  rx_busy  <= '0' when xs = X_IDLE else '1';
  rx_count <= rx_cnt_r;

  -- pushes al FIFO TX (un byte por ciclo en T_PUSH), pops del RX en X_COL
  txf_wdata <= t_word(7 downto 0)   when t_bidx = 0 else
               t_word(15 downto 8)  when t_bidx = 1 else
               t_word(23 downto 16) when t_bidx = 2 else
               t_word(31 downto 24);
  txf_wr <= '1' when ts = T_PUSH else '0';
  rxf_rd <= '1' when xs = X_COL  else '0';

  ------------------------------------------------------------------------------
  -- canal TX: lectura DDR -> FIFO TX (calca del camino R del spi_dma)
  ------------------------------------------------------------------------------
  p_tx : process(clk)
    variable v_space, v_left, v_w : natural;
  begin
    if rising_edge(clk) then
      tx_done <= '0';
      tx_rerr <= '0';
      if aresetn = '0' then
        ts <= T_IDLE;
      else
        case ts is
          when T_IDLE =>
            if tx_start = '1' then
              tx_left <= tx_len;
              txa_c   <= unsigned(ddr_base) +
                         resize(unsigned(tx_addr(30 downto 0)), ADDR_W);
              ts <= T_DEC;
            end if;

          when T_DEC =>
            if tx_left = 0 then
              tx_done <= '1';
              ts <= T_IDLE;
            else
              v_space := DEPTH - to_integer(txf_lvl);
              v_left  := to_integer(tx_left);
              if v_space >= 4 then
                -- rafaga acotada por espacio, restante y frontera de 4 KB
                v_w := fmin(fmin(v_space / 4, (v_left + 3) / 4),
                            fmin(16, 1024 - to_integer(unsigned(txa_c(11 downto 2)))));
                arlen_r <= std_logic_vector(to_unsigned(v_w - 1, 8));
                t_beats <= to_unsigned(v_w, 5);
                t_bytes <= to_unsigned(fmin(v_w * 4, v_left), 7);
                ts <= T_AR;
              end if;
            end if;

          when T_AR =>
            if m_axi_arready = '1' then ts <= T_BEAT; end if;

          when T_BEAT =>
            if m_axi_rvalid = '1' then
              t_word  <= m_axi_rdata;
              txa_c   <= txa_c + 4;
              t_beats <= t_beats - 1;
              t_beatb <= to_unsigned(fmin(4, to_integer(t_bytes)), 3);
              t_bidx  <= "00";
              if m_axi_rresp /= "00" then tx_rerr <= '1'; end if;
              ts <= T_PUSH;
            end if;

          when T_PUSH =>                 -- un push por ciclo
            tx_left <= tx_left - 1;
            t_bytes <= t_bytes - 1;
            t_beatb <= t_beatb - 1;
            t_bidx  <= t_bidx + 1;
            if t_beatb = 1 then
              if t_beats = 0 then ts <= T_DEC;
              else                ts <= T_BEAT;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- idle-flush del canal RX: arma tras el primer byte, se rearma con pushes
  -- del motor o actividad de linea. Los pops del DMA NO lo rearman: el flush
  -- debe sobrevivir al drenado del residuo.
  ------------------------------------------------------------------------------
  p_idle : process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' or xs = X_IDLE or rx_push = '1' or rx_line_busy = '1' then
        ic <= (others => '0');
      elsif bit_tick = '1' and (rx_cnt_r /= 0 or rxf_lvl /= 0)
            and ic /= idle_to then
        ic <= ic + 1;
      end if;
    end if;
  end process;

  flush_hit <= '1' when idle_to /= 0 and ic = idle_to else '0';

  ------------------------------------------------------------------------------
  -- canal RX: FIFO RX -> escritura DDR (camino W del spi_dma + terminacion
  -- por count o idle-flush)
  ------------------------------------------------------------------------------
  p_rx : process(clk)
    variable v_lvl, v_left, v_bb, v_beats, v_cap : natural;
  begin
    if rising_edge(clk) then
      rx_done    <= '0';
      rx_flushed <= '0';
      rx_berr    <= '0';
      if aresetn = '0' then
        xs <= X_IDLE;
      else
        case xs is
          when X_IDLE =>
            if rx_start = '1' then
              rx_left  <= rx_len;
              rx_cnt_r <= (others => '0');
              rxa_c    <= unsigned(ddr_base) +
                          resize(unsigned(rx_addr(30 downto 0)), ADDR_W);
              xs <= X_DEC;
            end if;

          when X_DEC =>
            v_lvl  := to_integer(rxf_lvl);
            v_left := to_integer(rx_left);
            if v_left = 0 then
              rx_done <= '1';                            -- cierre por cuenta
              xs <= X_IDLE;
            elsif rx_abort = '1' then
              rx_done <= '1';                            -- cancelado; el
              xs <= X_IDLE;                              -- residuo queda en PIO
            elsif v_lvl >= 4 or (v_lvl > 0 and v_lvl >= v_left) or
                  (flush_hit = '1' and v_lvl > 0) then
              if v_lvl >= v_left then
                v_bb := v_left;                          -- flush total (cola)
              elsif flush_hit = '1' and v_lvl < 4 then
                v_bb := v_lvl;                           -- residuo parcial
              else
                v_bb := (v_lvl / 4) * 4;                 -- palabras completas
              end if;
              v_beats := (v_bb + 3) / 4;
              v_cap   := fmin(16, 1024 - to_integer(unsigned(rxa_c(11 downto 2))));
              if v_beats > v_cap then
                v_beats := v_cap;
                v_bb    := v_beats * 4;
              end if;
              awlen_r <= std_logic_vector(to_unsigned(v_beats - 1, 8));
              x_beats <= to_unsigned(v_beats, 5);
              x_bytes <= to_unsigned(v_bb, 7);
              xs <= X_AW;
            elsif flush_hit = '1' and v_lvl = 0 and rx_cnt_r /= 0 then
              rx_done    <= '1';                         -- cierre por idle
              rx_flushed <= '1';
              xs <= X_IDLE;
            end if;

          when X_AW =>
            if m_axi_awready = '1' then
              x_word  <= (others => '0');
              x_strb  <= "0000";
              x_bidx  <= "00";
              x_beatb <= to_unsigned(fmin(4, to_integer(x_bytes)), 3);
              x_colc   <= to_unsigned(fmin(4, to_integer(x_bytes)), 3);
              xs <= X_COL;
            end if;

          when X_COL =>                  -- junta los bytes del beat (un pop/ciclo)
            case x_bidx is
              when "00"   => x_word(7 downto 0)   <= rxf_rdata; x_strb(0) <= '1';
              when "01"   => x_word(15 downto 8)  <= rxf_rdata; x_strb(1) <= '1';
              when "10"   => x_word(23 downto 16) <= rxf_rdata; x_strb(2) <= '1';
              when others => x_word(31 downto 24) <= rxf_rdata; x_strb(3) <= '1';
            end case;
            x_bidx <= x_bidx + 1;
            x_colc  <= x_colc - 1;
            if x_colc = 1 then
              xs <= X_BEAT;
            end if;

          when X_BEAT =>
            if m_axi_wready = '1' then
              rx_left  <= rx_left  - resize(x_beatb, 24);
              rx_cnt_r <= rx_cnt_r + resize(x_beatb, 24);
              x_bytes  <= x_bytes  - resize(x_beatb, 7);
              rxa_c    <= rxa_c + 4;
              x_beats  <= x_beats - 1;
              if x_beats = 1 then
                xs <= X_RESP;
              else
                x_word  <= (others => '0');
                x_strb  <= "0000";
                x_bidx  <= "00";
                x_beatb <= to_unsigned(fmin(4, to_integer(x_bytes) - to_integer(x_beatb)), 3);
                x_colc   <= to_unsigned(fmin(4, to_integer(x_bytes) - to_integer(x_beatb)), 3);
                xs <= X_COL;
              end if;
            end if;

          when X_RESP =>
            if m_axi_bvalid = '1' then
              if m_axi_bresp /= "00" then rx_berr <= '1'; end if;
              xs <= X_DEC;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
