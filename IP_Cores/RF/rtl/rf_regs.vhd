-- rf_regs.vhd - Banco de registros MMIO del RF Digital Front-End v1.
-- Contrato dmem de la familia:
--   * ESCRITURA registrada sincrona (we + addr + wdata).
--   * LECTURA COMBINACIONAL: rdata es un mux directo por addr, SIN registrar.
--     (Registrar rdata pasa capa 2 pero rompe capa 4: cada lw devuelve el dato
--      de la lectura previa.)
-- Direcciones (offset de palabra, addr en bytes con 2 LSB ignorados):
--   0x00 CTRL       RW  bit0 rx_en, bit1 tx_en, bit2 loop_en, bit3 agc_en,
--                       bit4 nco_reset (autolimpia)
--   0x04 STATUS     RO  bit0 rx_empty,1 rx_full,2 tx_empty,3 tx_full,4 irq
--   0x08 NCO_FTW    RW
--   0x0C RSSI       RO
--   0x10 AGC_CTRL   RW  [2:0] shift_man, [18:3]? -> se empaqueta th_high/low
--                       Aqui: [2:0] shift_man, [15:0] en otro? Se separan:
--                       usamos [2:0]=shift_man; th_high/low en 0x10 no caben,
--                       asi que th_high=bits[31:16], th_low=[15:3]<<? -> se
--                       simplifica: shift_man=[2:0], th_high=[31:16], th_low
--                       =[15:3] con 13 bits. Para el test se usan valores que
--                       caben. (El firmware del paso 6 fija estos campos.)
--   0x14 FIR_COEF_ADDR RW [3:0]
--   0x18 FIR_COEF_DATA WO  escribir dispara coef_we un ciclo (rx FIR)
--   0x1C RX_FIFO_LEVEL RO
--   0x20 RX_FIFO_DATA  RO  leer hace pop (rd_en un ciclo)
--   0x24 TX_FIFO_DATA  WO  escribir hace push (wr_en un ciclo)
--   0x28 IRQ_EN     RW
--   0x2C IRQ_STAT   RO/W1C  escribir 1 limpia el bit
--   0x30 IRQ_THRESH RW  nivel de rx_fifo que dispara irq
--   0x34 DMA_ADDR   RW  (cableado en paso 6)
--   0x38 DMA_LEN    RW
--   0x3C DMA_CTRL   RW
--   0x44 DBG_STATE  RO  (estado de depuracion; en este paso refleja un contador)
-- Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_regs is
  port (
    clk_i        : in  std_logic;
    aresetn_i    : in  std_logic;
    -- interfaz dmem estilo familia
    we_i         : in  std_logic;
    re_i         : in  std_logic;                       -- strobe de lectura (para side-effects)
    addr_i       : in  std_logic_vector(7 downto 0);   -- offset en bytes
    wdata_i      : in  std_logic_vector(31 downto 0);
    rdata_o      : out std_logic_vector(31 downto 0);   -- COMBINACIONAL
    -- control hacia el datapath
    rx_en_o      : out std_logic;
    tx_en_o      : out std_logic;
    loop_en_o    : out std_logic;
    agc_en_o     : out std_logic;
    nco_reset_o  : out std_logic;
    ftw_o        : out std_logic_vector(31 downto 0);
    shift_man_o  : out std_logic_vector(2 downto 0);
    th_high_o    : out std_logic_vector(15 downto 0);
    th_low_o     : out std_logic_vector(15 downto 0);
    coef_we_o    : out std_logic;
    coef_addr_o  : out std_logic_vector(3 downto 0);
    coef_data_o  : out std_logic_vector(15 downto 0);
    -- estado desde el datapath
    rssi_i       : in  std_logic_vector(15 downto 0);
    dbg_state_i  : in  std_logic_vector(31 downto 0);
    -- RX FIFO (lectura por MMIO)
    rxf_rd_en_o  : out std_logic;
    rxf_rd_data_i: in  std_logic_vector(31 downto 0);
    rxf_empty_i  : in  std_logic;
    rxf_full_i   : in  std_logic;
    rxf_level_i  : in  std_logic_vector(9 downto 0);
    -- TX FIFO (escritura por MMIO)
    txf_wr_en_o  : out std_logic;
    txf_wr_data_o: out std_logic_vector(31 downto 0);
    txf_empty_i  : in  std_logic;
    txf_full_i   : in  std_logic;
    -- IRQ
    irq_o        : out std_logic;
    -- DMA (paso 6/7)
    dma_busy_i   : in  std_logic := '0';
    dma_addr_o   : out std_logic_vector(31 downto 0);
    dma_len_o    : out std_logic_vector(31 downto 0);
    dma_ctrl_o   : out std_logic_vector(31 downto 0);
    tone_ftw_o   : out std_logic_vector(31 downto 0)
  );
end entity rf_regs;

architecture rtl of rf_regs is
  signal ctrl_r    : std_logic_vector(31 downto 0) := (others => '0');
  signal ftw_r     : std_logic_vector(31 downto 0) := (others => '0');
  signal toneftw_r : std_logic_vector(31 downto 0) := (others => '0');
  signal agc_r     : std_logic_vector(31 downto 0) := (others => '0');
  signal coefa_r   : std_logic_vector(3 downto 0)  := (others => '0');
  signal irqen_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal irqstat_r : std_logic_vector(31 downto 0) := (others => '0');
  signal irqthr_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal dmaa_r    : std_logic_vector(31 downto 0) := (others => '0');
  signal dmal_r    : std_logic_vector(31 downto 0) := (others => '0');
  signal dmac_r    : std_logic_vector(31 downto 0) := (others => '0');
  signal ncorst_r  : std_logic := '0';
  signal coefwe_r  : std_logic := '0';
  signal coefd_r   : std_logic_vector(15 downto 0) := (others => '0');
  signal txwr_r    : std_logic := '0';
  signal txwd_r    : std_logic_vector(31 downto 0) := (others => '0');

  constant A_CTRL   : std_logic_vector(7 downto 0) := x"00";
  constant A_STATUS : std_logic_vector(7 downto 0) := x"04";
  constant A_FTW    : std_logic_vector(7 downto 0) := x"08";
  constant A_RSSI   : std_logic_vector(7 downto 0) := x"0C";
  constant A_AGC    : std_logic_vector(7 downto 0) := x"10";
  constant A_CFA    : std_logic_vector(7 downto 0) := x"14";
  constant A_CFD    : std_logic_vector(7 downto 0) := x"18";
  constant A_RXLVL  : std_logic_vector(7 downto 0) := x"1C";
  constant A_RXDAT  : std_logic_vector(7 downto 0) := x"20";
  constant A_TXDAT  : std_logic_vector(7 downto 0) := x"24";
  constant A_IRQEN  : std_logic_vector(7 downto 0) := x"28";
  constant A_IRQST  : std_logic_vector(7 downto 0) := x"2C";
  constant A_IRQTH  : std_logic_vector(7 downto 0) := x"30";
  constant A_DMAA   : std_logic_vector(7 downto 0) := x"34";
  constant A_DMAL   : std_logic_vector(7 downto 0) := x"38";
  constant A_DMAC   : std_logic_vector(7 downto 0) := x"3C";
  constant A_TONE   : std_logic_vector(7 downto 0) := x"40";
  constant A_DBG    : std_logic_vector(7 downto 0) := x"44";

  signal aw : std_logic_vector(7 downto 0);
  signal irq_s : std_logic;
begin

  -- alinear direccion a palabra (ignora 2 LSB)
  aw <= addr_i(7 downto 2) & "00";

  -- salidas de control directas de los registros
  rx_en_o     <= ctrl_r(0);
  tx_en_o     <= ctrl_r(1);
  loop_en_o   <= ctrl_r(2);
  agc_en_o    <= ctrl_r(3);
  nco_reset_o <= ncorst_r;
  ftw_o       <= ftw_r;
  tone_ftw_o  <= toneftw_r;
  shift_man_o <= agc_r(2 downto 0);
  th_high_o   <= agc_r(31 downto 16);
  th_low_o    <= agc_r(15 downto 3) & "000";
  coef_we_o   <= coefwe_r;
  coef_addr_o <= coefa_r;
  coef_data_o <= coefd_r;
  rxf_rd_en_o <= '1' when (re_i = '1' and aw = A_RXDAT and rxf_empty_i = '0')
                 else '0';
  txf_wr_en_o <= txwr_r;
  txf_wr_data_o <= txwd_r;
  dma_addr_o  <= dmaa_r;
  dma_len_o   <= dmal_r;
  dma_ctrl_o  <= dmac_r;

  -- IRQ: se activa si rx_level >= umbral (>0) y esta habilitado
  irq_s <= '1' when (unsigned(irqthr_r(9 downto 0)) > 0)
                    and (unsigned(rxf_level_i) >= unsigned(irqthr_r(9 downto 0)))
                    and (irqen_r(0) = '1') else '0';
  irq_o <= irqstat_r(0) and irqen_r(0);

  -- ---------- LECTURA COMBINACIONAL (mux directo) ----------
  proc_rd : process (aw, ctrl_r, ftw_r, toneftw_r, agc_r, coefa_r, irqen_r, irqstat_r,
                     irqthr_r, dmaa_r, dmal_r, dmac_r, rssi_i, dbg_state_i,
                     rxf_rd_data_i, rxf_empty_i, rxf_full_i, rxf_level_i,
                     txf_empty_i, txf_full_i, dma_busy_i)
  begin
    case aw is
      when A_CTRL   => rdata_o <= ctrl_r;
      when A_STATUS => rdata_o <= (0 => rxf_empty_i, 1 => rxf_full_i,
                                   2 => txf_empty_i, 3 => txf_full_i,
                                   4 => (irqstat_r(0) and irqen_r(0)),
                                   5 => dma_busy_i,
                                   others => '0');
      when A_FTW    => rdata_o <= ftw_r;
      when A_TONE   => rdata_o <= toneftw_r;
      when A_RSSI   => rdata_o <= x"0000" & rssi_i;
      when A_AGC    => rdata_o <= agc_r;
      when A_CFA    => rdata_o <= x"0000000" & coefa_r;
      when A_RXLVL  => rdata_o <= x"00000" & "00" & rxf_level_i;
      when A_RXDAT  => rdata_o <= rxf_rd_data_i;   -- frente combinacional
      when A_IRQEN  => rdata_o <= irqen_r;
      when A_IRQST  => rdata_o <= irqstat_r;
      when A_IRQTH  => rdata_o <= irqthr_r;
      when A_DMAA   => rdata_o <= dmaa_r;
      when A_DMAL   => rdata_o <= dmal_r;
      when A_DMAC   => rdata_o <= dmac_r;
      when A_DBG    => rdata_o <= dbg_state_i;
      when others   => rdata_o <= (others => '0');
    end case;
  end process proc_rd;

  -- ---------- ESCRITURA REGISTRADA + pulsos ----------
  proc_wr : process (clk_i, aresetn_i)
  begin
    if aresetn_i = '0' then
      ctrl_r    <= (others => '0');
      ftw_r     <= (others => '0');
      toneftw_r <= (others => '0');
      agc_r     <= (others => '0');
      coefa_r   <= (others => '0');
      irqen_r   <= (others => '0');
      irqstat_r <= (others => '0');
      irqthr_r  <= (others => '0');
      dmaa_r    <= (others => '0');
      dmal_r    <= (others => '0');
      dmac_r    <= (others => '0');
      ncorst_r  <= '0';
      coefwe_r  <= '0';
      coefd_r   <= (others => '0');
      txwr_r    <= '0';
      txwd_r    <= (others => '0');
    elsif rising_edge(clk_i) then
      -- pulsos de un ciclo se autolimpian
      ncorst_r <= '0';
      coefwe_r <= '0';
      txwr_r   <= '0';

      -- IRQ pendiente (bit0): semantica W1C con PRIORIDAD DE SET. Primero se
      -- aplica el clear W1C (si el acceso lo pide), luego se re-evalua la
      -- condicion: si sigue activa, el bit queda en 1 (no se puede limpiar un
      -- IRQ cuya condicion persiste). Asi el clear solo baja el bit si la
      -- condicion ya ceso.
      if we_i = '1' and aw = A_IRQST then
        irqstat_r <= irqstat_r and not wdata_i;
        if irq_s = '1' then
          irqstat_r(0) <= '1';
        end if;
      elsif irq_s = '1' then
        irqstat_r(0) <= '1';
      end if;

      if we_i = '1' then
        case aw is
          when A_CTRL   =>
            ctrl_r <= wdata_i;
            ncorst_r <= wdata_i(4);   -- pulso si se escribe bit4
          when A_FTW    => ftw_r <= wdata_i;
          when A_TONE   => toneftw_r <= wdata_i;
          when A_AGC    => agc_r <= wdata_i;
          when A_CFA    => coefa_r <= wdata_i(3 downto 0);
          when A_CFD    =>
            coefd_r  <= wdata_i(15 downto 0);
            coefwe_r <= '1';          -- dispara coef_we un ciclo
          when A_RXDAT  =>
            null;                    -- lectura hace pop via re_i (abajo)
          when A_TXDAT  =>
            txwd_r <= wdata_i;
            txwr_r <= '1';            -- push
          when A_IRQEN  => irqen_r <= wdata_i;
          when A_IRQST  =>
            null;                    -- W1C ya aplicado arriba (con set-priority)
          when A_IRQTH  => irqthr_r <= wdata_i;
          when A_DMAA   => dmaa_r <= wdata_i;
          when A_DMAL   => dmal_r <= wdata_i;
          when A_DMAC   => dmac_r <= wdata_i;
          when others   => null;
        end case;
      end if;

      -- pop de RX en LECTURA: cuando re_i='1' y la direccion es A_RXDAT.
    end if;
  end process proc_wr;

end architecture rtl;
