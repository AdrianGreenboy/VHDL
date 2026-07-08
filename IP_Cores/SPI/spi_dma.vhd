-- =============================================================================
--  spi_dma.vhd  -  Maestro AXI4 en rafagas para el IP SPI (DDR <-> FIFOs)
--  Licencia: MIT
--
--  Primo del dma_burst del SoC v3, pero con los FIFOs de bytes del SPI como
--  endpoints y operacion FULL-DUPLEX: en una transferencia de LEN bytes, el
--  lado TX trae bytes de la DDR (o inyecta un byte dummy si tx_en = '0') y el
--  lado RX lleva a la DDR los bytes que el motor SPI recibe (o los descarta
--  si rx_en = '0'). El FSM alterna entre ambos lados con PRIORIDAD al drenado
--  de RX, para que el FIFO RX nunca se desborde por culpa del DMA.
--
--  Rafagas INCR de hasta 16 beats, troceadas en fronteras de 4 KB (mismo
--  truco words_to_4k del dma_burst). El ultimo beat puede ser parcial: se
--  escribe con wstrb enmascarado, asi LEN puede ser cualquier numero de
--  bytes. tx_addr / rx_addr son offsets en DDR relativos a ddr_base,
--  ALINEADOS a 4 bytes (mismo contrato que el DMA del SoC).
--
--  Direccion de bytes little-endian: el byte 0 de cada palabra es el primero
--  que sale por MOSI, consistente con la memoria del RV32.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_dma is
  generic (
    ADDR_W    : natural := 40;
    FIFO_LOG2 : natural := 8
  );
  port (
    clk      : in std_logic;
    aresetn  : in std_logic;
    ddr_base : in std_logic_vector(ADDR_W-1 downto 0);

    -- comando (estable durante la transferencia)
    tx_addr : in  std_logic_vector(31 downto 0);  -- offset DDR (lectura)
    rx_addr : in  std_logic_vector(31 downto 0);  -- offset DDR (escritura)
    nbytes  : in  unsigned(23 downto 0);
    tx_en   : in  std_logic;   -- '0': inyecta dummy en vez de leer DDR
    rx_en   : in  std_logic;   -- '0': descarta lo recibido (no escribe DDR)
    dummy   : in  std_logic_vector(7 downto 0);
    start   : in  std_logic;   -- pulso
    busy    : out std_logic;

    -- FIFO TX (push)
    txf_wr    : out std_logic;
    txf_wdata : out std_logic_vector(7 downto 0);
    txf_lvl   : in  unsigned(FIFO_LOG2 downto 0);

    -- FIFO RX (pop; rd_data es FWFT)
    rxf_rd    : out std_logic;
    rxf_rdata : in  std_logic_vector(7 downto 0);
    rxf_lvl   : in  unsigned(FIFO_LOG2 downto 0);

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
    m_axi_rready  : out std_logic
  );
end entity spi_dma;

architecture rtl of spi_dma is
  constant DEPTH : natural := 2**FIFO_LOG2;

  type state_t is (S_IDLE, S_DECIDE, S_DISC, S_DUM,
                   R_AR, R_BEAT, R_PUSH,
                   W_AW, W_COL, W_BEAT, W_RESP);
  signal state : state_t := S_IDLE;

  signal tx_left, rx_left : unsigned(23 downto 0) := (others => '0');
  signal txa_c, rxa_c     : unsigned(ADDR_W-1 downto 0) := (others => '0');

  signal burst_beats : unsigned(4 downto 0) := (others => '0');  -- beats del burst
  signal burst_bytes : unsigned(6 downto 0) := (others => '0');  -- bytes del burst
  signal beat_bytes  : unsigned(2 downto 0) := (others => '0');  -- bytes del beat
  signal col_cnt     : unsigned(2 downto 0) := (others => '0');  -- bytes por juntar
  signal arlen_r, awlen_r : std_logic_vector(7 downto 0) := (others => '0');
  signal wordbuf : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb_r : std_logic_vector(3 downto 0) := "0000";
  signal bidx    : unsigned(1 downto 0) := "00";
  signal chunk_cnt : unsigned(4 downto 0) := (others => '0');

  signal txf_byte : std_logic_vector(7 downto 0);

  function fmin(a, b : natural) return natural is
  begin
    if a < b then return a; else return b; end if;
  end function;
begin

  m_axi_awsize  <= "010";
  m_axi_arsize  <= "010";
  m_axi_awburst <= "01";
  m_axi_arburst <= "01";
  m_axi_awlen   <= awlen_r;
  m_axi_arlen   <= arlen_r;
  m_axi_awaddr  <= std_logic_vector(rxa_c);
  m_axi_araddr  <= std_logic_vector(txa_c);
  m_axi_wdata   <= wordbuf;
  m_axi_wstrb   <= wstrb_r;
  m_axi_wlast   <= '1' when (state = W_BEAT and burst_beats = 1) else '0';

  m_axi_awvalid <= '1' when state = W_AW   else '0';
  m_axi_wvalid  <= '1' when state = W_BEAT else '0';
  m_axi_bready  <= '1' when state = W_RESP else '0';
  m_axi_arvalid <= '1' when state = R_AR   else '0';
  m_axi_rready  <= '1' when state = R_BEAT else '0';

  busy <= '0' when state = S_IDLE else '1';

  -- pushes / pops (un byte por ciclo en los estados correspondientes)
  txf_byte <= wordbuf(7 downto 0)   when bidx = 0 else
              wordbuf(15 downto 8)  when bidx = 1 else
              wordbuf(23 downto 16) when bidx = 2 else
              wordbuf(31 downto 24);
  txf_wr    <= '1' when (state = R_PUSH or state = S_DUM) else '0';
  txf_wdata <= dummy when state = S_DUM else txf_byte;
  rxf_rd    <= '1' when (state = W_COL or state = S_DISC) else '0';

  process(clk)
    variable v_lvl, v_space, v_left : natural;
    variable v_bb, v_beats, v_cap, v_w, v_chunk : natural;
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        state <= S_IDLE;
      else
        case state is
          when S_IDLE =>
            if start = '1' then
              tx_left <= nbytes;
              rx_left <= nbytes;
              txa_c <= unsigned(ddr_base) + resize(unsigned(tx_addr(30 downto 0)), ADDR_W);
              rxa_c <= unsigned(ddr_base) + resize(unsigned(rx_addr(30 downto 0)), ADDR_W);
              state <= S_DECIDE;
            end if;

          -- decide la proxima accion; prioridad: drenar RX > alimentar TX
          when S_DECIDE =>
            if tx_left = 0 and rx_left = 0 then
              state <= S_IDLE;
            else
              v_lvl  := to_integer(rxf_lvl);
              v_left := to_integer(rx_left);

              if rx_en = '0' and v_left > 0 and v_lvl > 0 then
                -- descarta lo recibido
                v_chunk := fmin(fmin(v_lvl, v_left), 16);
                chunk_cnt <= to_unsigned(v_chunk, 5);
                state <= S_DISC;

              elsif rx_en = '1' and v_left > 0 and
                    (v_lvl >= 4 or v_lvl >= v_left) then
                -- burst de escritura: palabras completas, o la cola final
                if v_lvl >= v_left then
                  v_bb := v_left;                    -- flush total (cola parcial)
                else
                  v_bb := (v_lvl / 4) * 4;           -- solo palabras completas
                end if;
                v_beats := (v_bb + 3) / 4;
                v_cap   := fmin(16, 1024 - to_integer(unsigned(rxa_c(11 downto 2))));
                if v_beats > v_cap then
                  v_beats := v_cap;
                  v_bb    := v_beats * 4;
                end if;
                awlen_r     <= std_logic_vector(to_unsigned(v_beats - 1, 8));
                burst_beats <= to_unsigned(v_beats, 5);
                burst_bytes <= to_unsigned(v_bb, 7);
                state <= W_AW;

              elsif tx_left /= 0 then
                v_space := DEPTH - to_integer(txf_lvl);
                v_left  := to_integer(tx_left);
                if tx_en = '1' then
                  if v_space >= 4 then
                    -- burst de lectura acotado por espacio, restante y 4 KB
                    v_w := fmin(fmin(v_space / 4, (v_left + 3) / 4),
                                fmin(16, 1024 - to_integer(unsigned(txa_c(11 downto 2)))));
                    arlen_r     <= std_logic_vector(to_unsigned(v_w - 1, 8));
                    burst_beats <= to_unsigned(v_w, 5);
                    burst_bytes <= to_unsigned(fmin(v_w * 4, v_left), 7);
                    state <= R_AR;
                  end if;
                else
                  if v_space > 0 then
                    v_chunk := fmin(fmin(v_space, v_left), 16);
                    chunk_cnt <= to_unsigned(v_chunk, 5);
                    state <= S_DUM;
                  end if;
                end if;
              end if;
            end if;

          -- descarta bytes de RX (rx_en = '0'), uno por ciclo
          when S_DISC =>
            rx_left   <= rx_left - 1;
            chunk_cnt <= chunk_cnt - 1;
            if chunk_cnt = 1 then state <= S_DECIDE; end if;

          -- inyecta dummies al FIFO TX (tx_en = '0'), uno por ciclo
          when S_DUM =>
            tx_left   <= tx_left - 1;
            chunk_cnt <= chunk_cnt - 1;
            if chunk_cnt = 1 then state <= S_DECIDE; end if;

          -- lectura DDR -> FIFO TX
          when R_AR =>
            if m_axi_arready = '1' then state <= R_BEAT; end if;
          when R_BEAT =>
            if m_axi_rvalid = '1' then
              wordbuf     <= m_axi_rdata;
              txa_c       <= txa_c + 4;
              burst_beats <= burst_beats - 1;
              beat_bytes  <= to_unsigned(fmin(4, to_integer(burst_bytes)), 3);
              bidx        <= "00";
              state       <= R_PUSH;
            end if;
          when R_PUSH =>                  -- un push por ciclo
            tx_left     <= tx_left - 1;
            burst_bytes <= burst_bytes - 1;
            beat_bytes  <= beat_bytes - 1;
            bidx        <= bidx + 1;
            if beat_bytes = 1 then
              if burst_beats = 0 then state <= S_DECIDE;
              else                    state <= R_BEAT;
              end if;
            end if;

          -- escritura FIFO RX -> DDR
          when W_AW =>
            if m_axi_awready = '1' then
              wordbuf    <= (others => '0');
              wstrb_r    <= "0000";
              bidx       <= "00";
              beat_bytes <= to_unsigned(fmin(4, to_integer(burst_bytes)), 3);
              col_cnt    <= to_unsigned(fmin(4, to_integer(burst_bytes)), 3);
              state      <= W_COL;
            end if;
          when W_COL =>                   -- junta los bytes del beat (un pop/ciclo)
            case bidx is
              when "00"   => wordbuf(7 downto 0)   <= rxf_rdata; wstrb_r(0) <= '1';
              when "01"   => wordbuf(15 downto 8)  <= rxf_rdata; wstrb_r(1) <= '1';
              when "10"   => wordbuf(23 downto 16) <= rxf_rdata; wstrb_r(2) <= '1';
              when others => wordbuf(31 downto 24) <= rxf_rdata; wstrb_r(3) <= '1';
            end case;
            bidx    <= bidx + 1;
            col_cnt <= col_cnt - 1;
            if col_cnt = 1 then
              state <= W_BEAT;
            end if;
          when W_BEAT =>
            if m_axi_wready = '1' then
              rx_left     <= rx_left - resize(beat_bytes, 24);
              burst_bytes <= burst_bytes - resize(beat_bytes, 7);
              rxa_c       <= rxa_c + 4;
              burst_beats <= burst_beats - 1;
              if burst_beats = 1 then
                state <= W_RESP;
              else
                wordbuf    <= (others => '0');
                wstrb_r    <= "0000";
                bidx       <= "00";
                beat_bytes <= to_unsigned(fmin(4, to_integer(burst_bytes) - to_integer(beat_bytes)), 3);
                col_cnt    <= to_unsigned(fmin(4, to_integer(burst_bytes) - to_integer(beat_bytes)), 3);
                state      <= W_COL;
              end if;
            end if;
          when W_RESP =>
            if m_axi_bvalid = '1' then state <= S_DECIDE; end if;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
