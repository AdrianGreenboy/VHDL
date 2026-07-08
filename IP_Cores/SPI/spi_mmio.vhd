-- =============================================================================
--  spi_mmio.vhd  -  Registros MMIO + FIFOs TX/RX + motor SPI (modo PIO)
--  Licencia: MIT
--
--  Se cuelga del subsistema de memoria del SoC igual que los registros del
--  DMA: el decodificador externo selecciona la region (plan: 0x5000_0000,
--  bits 31:28 = "0101") y este modulo recibe el OFFSET en addr(7:0). El
--  acceso es de 1 ciclo (dmem_ready = '1'), consistente con mem_subsys_dma.
--
--  Mapa de registros (offset):
--    0x00 CTRL   (rw) [0]=en  [1]=cpol  [2]=cpha  [3]=lsb_first
--                     [4]=sample_late  [5]=cs_force
--    0x04 STATUS (r)  [0]=busy [1]=tx_empty [2]=tx_full [3]=rx_empty
--                     [4]=rx_full [5]=rx_ovf(sticky) [6]=tx_ovf(sticky)
--                (w)  cualquier escritura limpia los stickies
--    0x08 CLKDIV (rw) medio periodo de SCLK en ciclos (>=1; 1 -> 50 MHz)
--    0x0C TXDATA (w)  empuja wdata(7:0) al FIFO TX (si esta lleno: tx_ovf)
--    0x10 RXDATA (r)  cabeza del FIFO RX; el pop ocurre en el flanco
--    0x14 TXLVL  (r)  bytes en el FIFO TX
--    0x18 RXLVL  (r)  bytes en el FIFO RX
--
--  Semantica de CS: el motor baja CS solo mientras el FIFO TX alimente bytes
--  back-to-back. Para transacciones lentas por PIO (o con fases separadas
--  comando/dummy/datos), cs_force = '1' mantiene el pad CS_n abajo entre
--  bytes aunque el motor pase por idle; SCLK descansa en CPOL entre bytes.
--
--  Terminacion por software (PIO): esperar STATUS.tx_empty = 1 y busy = 0.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_mmio is
  generic (
    DIV_W     : natural := 16;
    FIFO_LOG2 : natural := 8             -- 256 bytes por FIFO
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

    -- pads SPI
    sclk_o : out std_logic;
    mosi_o : out std_logic;
    miso_i : in  std_logic;
    cs_n_o : out std_logic
  );
end entity spi_mmio;

architecture rtl of spi_mmio is
  -- registros de control
  signal en, cpol_r, cpha_r, lsbf_r, slate_r, csf_r : std_logic := '0';
  signal clkdiv_r : unsigned(DIV_W-1 downto 0) := to_unsigned(4, DIV_W);
  signal tx_ovf, rx_ovf : std_logic := '0';

  -- motor
  signal eng_txd  : std_logic_vector(7 downto 0);
  signal eng_txv, eng_txr : std_logic;
  signal eng_rxd  : std_logic_vector(7 downto 0);
  signal eng_rxv, eng_busy : std_logic;
  signal eng_csn  : std_logic;

  -- FIFOs
  signal txf_wr, txf_full, txf_rd, txf_empty : std_logic;
  signal txf_rdata : std_logic_vector(7 downto 0);
  signal txf_lvl   : unsigned(FIFO_LOG2 downto 0);
  signal rxf_wr, rxf_full, rxf_rd, rxf_empty : std_logic;
  signal rxf_rdata : std_logic_vector(7 downto 0);
  signal rxf_lvl   : unsigned(FIFO_LOG2 downto 0);

  signal wr_acc, rd_acc : std_logic;
begin

  -- un acceso valido por ciclo (dmem_req dura 1 ciclo con dmem_ready = '1')
  wr_acc <= '1' when (sel = '1' and req = '1' and wstrb /= "0000") else '0';
  rd_acc <= '1' when (sel = '1' and req = '1' and wstrb  = "0000") else '0';

  txf_wr <= '1' when (wr_acc = '1' and addr = x"0C") else '0';
  rxf_rd <= '1' when (rd_acc = '1' and addr = x"10") else '0';

  u_txf : entity work.byte_fifo
    generic map (LOG2_DEPTH => FIFO_LOG2)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => txf_wr, wr_data => wdata(7 downto 0), full => txf_full,
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

  -- motor <-> FIFOs: mientras haya bytes y en = '1', el motor encadena solo
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
      sclk_o => sclk_o, mosi_o => mosi_o, miso_i => miso_i, cs_n_o => eng_csn
    );

  -- cs_force mantiene el pad abajo entre bytes (transacciones lentas por PIO)
  cs_n_o <= '0' when csf_r = '1' else eng_csn;

  -- escritura de registros + banderas sticky de overflow
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        en <= '0'; cpol_r <= '0'; cpha_r <= '0';
        lsbf_r <= '0'; slate_r <= '0'; csf_r <= '0';
        clkdiv_r <= to_unsigned(4, DIV_W);
        tx_ovf <= '0'; rx_ovf <= '0';
      else
        if wr_acc = '1' then
          case addr is
            when x"00" =>
              en      <= wdata(0);
              cpol_r  <= wdata(1);
              cpha_r  <= wdata(2);
              lsbf_r  <= wdata(3);
              slate_r <= wdata(4);
              csf_r   <= wdata(5);
            when x"04" =>                -- limpia los stickies
              tx_ovf <= '0';
              rx_ovf <= '0';
            when x"08" =>
              clkdiv_r <= unsigned(wdata(DIV_W-1 downto 0));
            when others => null;
          end case;
        end if;

        if txf_wr = '1' and txf_full = '1' then
          tx_ovf <= '1';                 -- push a FIFO lleno: byte descartado
        end if;
        if eng_rxv = '1' and rxf_full = '1' then
          rx_ovf <= '1';                 -- byte recibido sin lugar: descartado
        end if;
      end if;
    end if;
  end process;

  -- lectura combinacional (1 ciclo, como los registros del DMA)
  process(all)
  begin
    rdata <= (others => '0');
    if sel = '1' then
      case addr is
        when x"00" =>
          rdata(0) <= en;      rdata(1) <= cpol_r;  rdata(2) <= cpha_r;
          rdata(3) <= lsbf_r;  rdata(4) <= slate_r; rdata(5) <= csf_r;
        when x"04" =>
          rdata(0) <= eng_busy;  rdata(1) <= txf_empty; rdata(2) <= txf_full;
          rdata(3) <= rxf_empty; rdata(4) <= rxf_full;
          rdata(5) <= rx_ovf;    rdata(6) <= tx_ovf;
        when x"08" =>
          rdata(DIV_W-1 downto 0) <= std_logic_vector(clkdiv_r);
        when x"10" =>
          rdata(7 downto 0) <= rxf_rdata;
        when x"14" =>
          rdata(FIFO_LOG2 downto 0) <= std_logic_vector(txf_lvl);
        when x"18" =>
          rdata(FIFO_LOG2 downto 0) <= std_logic_vector(rxf_lvl);
        when others => null;
      end case;
    end if;
  end process;

end architecture rtl;
