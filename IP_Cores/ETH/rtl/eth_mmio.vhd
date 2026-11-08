-- ============================================================================
-- eth_mmio.vhd -- MAC Ethernet 10/100 (familia TSN v1) con banco MMIO
-- ============================================================================
-- Region 0xD000_0000 (decode addr[31:28]="1101" en mem_subsys; aqui llegan
-- los bits bajos). Contrato del bus dmem del RV32: sel de 1 ciclo, rdata
-- COMBINACIONAL en el mismo ciclo, pop-on-read.
--
-- Envuelve el MAC completo (eth_mac: TX+RX+mii_ce/4+mux LOOP_INT) con dos
-- FIFOs byte-stream de 9 bits (8 dato + 1 EOF):
--   FIFO TX: el firmware escribe bytes en TXD; el bit EOF (b8 de la escritura)
--            marca el ultimo byte de la trama. El motor TX drena la FIFO byte
--            a byte y dispara cuando hay al menos el primer byte; el EOF le
--            dice donde acaba la trama (tx_last).
--   FIFO RX: el motor RX vuelca la trama aceptada byte a byte; el ultimo byte
--            lleva EOF. El firmware lee RXD con pop-on-read (VALID en b31).
--
-- Semanticas (revised by audit 2026-11):
--   - STAT stickies are W1C PER BIT: writing '1' to a sticky bit clears that
--     bit only; writing '0' leaves it. A set in the same cycle WINS. (v1
--     cleared all stickies on any write to STAT.)
--   - IRQ por NIVEL sin ack: irq = or(STAT and IRQEN) (registered).
--   - EN=0: FIFOs en limpieza continua (the MAC engines keep running; with
--     EN=0 nothing reaches/leaves the FIFOs).
--   - CMD: escritura pulsa TX_FLUSH/RX_FLUSH.
--   - LOOP_INT: realimenta TX->RX en el PL; pads idle. Self-test silicio.
--   - External PHY (LOOP_INT=0): real MII with mii_rx_clk / mii_tx_clk and
--     a CDC inside eth_mac (see eth_mii_cdc.vhd).
--   - RX FIFO holds WHOLE frames only: a frame that does not fit is written
--     speculatively, discarded entirely (rewind) and flagged in RXF_OVF; the
--     firmware never sees a truncated frame or a frame without EOF.
--   - FIFOs are synchronous-read (eth_fifo, SRAM/ASIC friendly) with FWFT
--     prefetch. Reset is synchronous active-high everywhere.
--
-- Mapa (offsets de palabra, addr(7:2)):
--   0x00 CTRL     RW  b0 EN, b1 LOOP_INT, b2 PROMISC
--   0x04 MACLO    RW  b31:0  MAC[31:0]   (byte0 en b7:0)
--   0x08 MACHI    RW  b15:0  MAC[47:32]
--   0x0C CMD      W1P b0 TX_FLUSH, b1 RX_FLUSH (b2 reserved, ignored: the v1
--                     doc listed a TX_GO that was never implemented; TX starts
--                     automatically once a frame with EOF is in the FIFO)
--   0x10 STAT     R   b0 TX_BUSY, b4 TXF_EMPTY, b5 TXF_FULL, b6 RXF_EMPTY,
--                     b7 RXF_FULL, b14:8 rxf_level SATURATED at 127 (full
--                     value in LEVEL);
--                     stickies b16 RX_OK, b17 RX_CRC, b18 RX_RUNT, b19 RX_DROP,
--                     b20 TX_UNDERRUN, b21 TXF_OVF, b22 RXF_OVF (frame dropped),
--                     b23 RX_OVERSIZE (> 1518 B dropped), b24 PHY_RX_OVF,
--                     b25 PHY_TX_UNF (CDC diagnostics, external PHY only)
--                 W   W1C per sticky bit (sets del mismo ciclo ganan)
--   0x14 TXD      W   b7:0 dato, b8 EOF (ultimo byte de la trama)
--                 R   b11:0 txf_level, b12 txf_full
--   0x18 RXD      R   pop-on-read b7:0 dato, b8 EOF, b31 VALID
--   0x1C IRQEN    RW  mascara sobre STAT
--   0x20 LEVEL    R   b11:0 rxf_level (committed bytes), b27:16 txf_level
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_mmio is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;                          -- sincrono, activo alto
    -- bus dmem
    sel   : in  std_logic;
    we    : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);
    wdata : in  std_logic_vector(31 downto 0);
    rdata : out std_logic_vector(31 downto 0);      -- COMBINACIONAL
    irq   : out std_logic;
    -- pines MII (PHY externo)
    mii_rx_clk : in std_logic := '0';
    mii_tx_clk : in std_logic := '0';
    mii_txd   : out std_logic_vector(3 downto 0);
    mii_tx_en : out std_logic;
    mii_rxd   : in  std_logic_vector(3 downto 0);
    mii_rx_dv : in  std_logic
  );
end entity eth_mmio;

architecture rtl of eth_mmio is

  -- registros
  signal ctrl_r  : std_logic_vector(2 downto 0)  := (others => '0');
  signal maclo_r : std_logic_vector(31 downto 0) := (others => '0');
  signal machi_r : std_logic_vector(15 downto 0) := (others => '0');
  signal irqen_r : std_logic_vector(31 downto 0) := (others => '0');

  signal en_i, loop_i, promisc_i : std_logic;

  -- stickies b25:16 (10 bits)
  signal stk : std_logic_vector(9 downto 0) := (others => '0');

  -- decode
  signal sel_ctrl, sel_maclo, sel_machi, sel_cmd : std_logic;
  signal sel_stat, sel_txd, sel_rxd, sel_irqen    : std_logic;
  signal sel_level : std_logic;

  -- FIFO TX (9 b: 8 dato + 1 EOF)
  signal txf_clr, txf_wr, txf_rd, txf_empty, txf_full : std_logic;
  signal txf_head  : std_logic_vector(8 downto 0);
  signal txf_level : std_logic_vector(11 downto 0);

  -- FIFO RX (9 b: 8 dato + 1 EOF)
  signal rxf_clr, rxf_wr, rxf_rd, rxf_empty, rxf_full : std_logic;
  signal rxf_wdata, rxf_head : std_logic_vector(8 downto 0);
  signal rxf_level : std_logic_vector(11 downto 0);
  signal rxf_commit, rxf_rewind : std_logic;
  signal rx_doomed : std_logic := '0';   -- current RX frame lost a byte
  signal rxf_lvl7  : std_logic_vector(6 downto 0);

  -- interfaz con el MAC
  signal mac_tx_data  : std_logic_vector(7 downto 0);
  signal mac_tx_valid : std_logic;
  signal mac_tx_last  : std_logic;
  signal mac_tx_ready : std_logic;
  signal mac_tx_busy  : std_logic;
  signal mac_tx_underrun : std_logic;

  signal mac_rx_data  : std_logic_vector(7 downto 0);
  signal mac_rx_valid : std_logic;
  signal mac_rx_last  : std_logic;
  signal mac_rx_ev_ok, mac_rx_ev_crc, mac_rx_ev_runt, mac_rx_ev_drop : std_logic;
  signal mac_rx_ev_ovs, mac_phy_ovf, mac_phy_unf : std_logic;

  signal macaddr : std_logic_vector(47 downto 0);

  -- store-and-forward: cuenta de tramas completas (EOF) en la FIFO TX
  signal frames_pending : unsigned(6 downto 0) := (others => '0');
  signal tx_go          : std_logic;

  signal stat_v : std_logic_vector(31 downto 0);

begin

  en_i      <= ctrl_r(0);
  loop_i    <= ctrl_r(1);
  promisc_i <= ctrl_r(2);
  macaddr   <= machi_r & maclo_r;

  -- ------------------------------------------------------------------ decode
  sel_ctrl  <= '1' when addr(7 downto 2) = "000000" else '0';
  sel_maclo <= '1' when addr(7 downto 2) = "000001" else '0';
  sel_machi <= '1' when addr(7 downto 2) = "000010" else '0';
  sel_cmd   <= '1' when addr(7 downto 2) = "000011" else '0';
  sel_stat  <= '1' when addr(7 downto 2) = "000100" else '0';
  sel_txd   <= '1' when addr(7 downto 2) = "000101" else '0';
  sel_rxd   <= '1' when addr(7 downto 2) = "000110" else '0';
  sel_irqen <= '1' when addr(7 downto 2) = "000111" else '0';
  sel_level <= '1' when addr(7 downto 2) = "001000" else '0';

  -- ------------------------------------------------------------------- FIFOs
  txf_wr <= sel and we and sel_txd and (not txf_full);
  -- el motor TX consume un byte cada vez que afirma tx_ready
  txf_rd <= mac_tx_ready and (not txf_empty);
  rxf_rd <= sel and (not we) and sel_rxd and (not rxf_empty);

  u_txf : entity work.eth_fifo
    generic map (LOG2_DEPTH => 11, WIDTH => 9, G_SPEC => false)
    port map (
      clk => clk, rst => rst, clr => txf_clr,
      wr_en => txf_wr, wdata => wdata(8 downto 0),
      rd_en => txf_rd, rdata => txf_head,
      empty => txf_empty, full => txf_full, level => txf_level);

  -- la FIFO TX alimenta el motor: dato en b7:0, EOF (tx_last) en b8.
  mac_tx_data <= txf_head(7 downto 0);
  mac_tx_last <= txf_head(8);
  -- STORE-AND-FORWARD: no arrancar hasta tener una trama COMPLETA en la FIFO
  -- (al menos un EOF escrito). Asi el drenaje del motor (rapido) nunca alcanza
  -- a la escritura del firmware (lenta) -> sin underrun. tx_go se mantiene alto
  -- mientras haya tramas pendientes y cae cuando se drena el ultimo EOF.
  mac_tx_valid <= tx_go and (not txf_empty);

  -- el motor RX vuelca la trama aceptada: dato + EOF en el ultimo byte.
  -- Whole-frame policy (tsn_ingress doom/rewind pattern): bytes are written
  -- speculatively; if any byte of the frame found the FIFO full the frame is
  -- doomed and rewound on its last byte, otherwise it is committed with it.
  rxf_wr     <= mac_rx_valid and (not rxf_full) and (not rx_doomed);
  rxf_wdata  <= mac_rx_last & mac_rx_data;
  rxf_commit <= mac_rx_valid and mac_rx_last and not (rx_doomed or rxf_full);
  rxf_rewind <= mac_rx_valid and mac_rx_last and (rx_doomed or rxf_full);

  u_rxf : entity work.eth_fifo
    generic map (LOG2_DEPTH => 11, WIDTH => 9, G_SPEC => true)
    port map (
      clk => clk, rst => rst, clr => rxf_clr,
      wr_en => rxf_wr, wdata => rxf_wdata,
      wr_commit => rxf_commit, wr_rewind => rxf_rewind,
      rd_en => rxf_rd, rdata => rxf_head,
      empty => rxf_empty, full => rxf_full, level => rxf_level);

  p_doom : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or rxf_clr = '1' then
        rx_doomed <= '0';
      elsif mac_rx_valid = '1' then
        if mac_rx_last = '1' then
          rx_doomed <= '0';                         -- next frame starts clean
        elsif rxf_full = '1' then
          rx_doomed <= '1';                         -- a byte was lost
        end if;
      end if;
    end if;
  end process p_doom;

  tx_go <= '1' when frames_pending /= 0 else '0';

  -- contador de tramas completas en la FIFO TX (store-and-forward):
  -- +1 cuando el firmware escribe un byte con EOF; -1 cuando el motor drena
  -- un byte con EOF (fin de la trama transmitida).
  sf_p : process (clk)
    variable inc, dec : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' or en_i = '0' or txf_clr = '1' then
        frames_pending <= (others => '0');
      else
        inc := (txf_wr = '1') and (wdata(8) = '1');
        dec := (txf_rd = '1') and (txf_head(8) = '1');
        if inc and not dec then
          frames_pending <= frames_pending + 1;
        elsif dec and not inc then
          frames_pending <= frames_pending - 1;
        end if;
      end if;
    end if;
  end process sf_p;

  -- ---------------------------------------------------------------- MAC core
  u_mac : entity work.eth_mac
    port map (
      clk => clk, rst => rst, loopback => loop_i,
      macaddr => macaddr, promisc => promisc_i,
      tx_data => mac_tx_data, tx_valid => mac_tx_valid, tx_last => mac_tx_last,
      tx_ready => mac_tx_ready, tx_busy => mac_tx_busy, tx_underrun => mac_tx_underrun,
      rx_data => mac_rx_data, rx_valid => mac_rx_valid, rx_last => mac_rx_last,
      rx_ev_ok => mac_rx_ev_ok, rx_ev_crc => mac_rx_ev_crc,
      rx_ev_runt => mac_rx_ev_runt, rx_ev_drop => mac_rx_ev_drop,
      rx_ev_oversize => mac_rx_ev_ovs,
      rx_dbg_dst => open, rx_dbg_nb => open,
      phy_rx_ovf => mac_phy_ovf, phy_tx_unf => mac_phy_unf,
      mii_rx_clk => mii_rx_clk, mii_tx_clk => mii_tx_clk,
      mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv,
      tx_sfd_pulse => open, rx_sfd_pulse => open);

  -- --------------------------------------------------------------- vista STAT
  stat_v(0)            <= mac_tx_busy;
  stat_v(3 downto 1)   <= (others => '0');
  stat_v(4)            <= txf_empty;
  stat_v(5)            <= txf_full;
  stat_v(6)            <= rxf_empty;
  stat_v(7)            <= rxf_full;
  -- 7-bit view saturates (v1 truncated the 12-bit level: 128 read as 0)
  rxf_lvl7 <= rxf_level(6 downto 0) when unsigned(rxf_level) < 128 else (others => '1');
  stat_v(14 downto 8)  <= rxf_lvl7;
  stat_v(15)           <= '0';
  stat_v(25 downto 16) <= stk;
  stat_v(31 downto 26) <= (others => '0');

  -- --------------------------------------------- rdata COMBINACIONAL (contrato)
  rdata <=
    (31 downto 3 => '0') & ctrl_r                         when sel_ctrl  = '1' else
    maclo_r                                               when sel_maclo = '1' else
    (31 downto 16 => '0') & machi_r                       when sel_machi = '1' else
    stat_v                                                when sel_stat  = '1' else
    (31 downto 13 => '0') & txf_full & txf_level          when sel_txd   = '1' else
    (not rxf_empty) & (30 downto 9 => '0') & rxf_head     when sel_rxd   = '1' else
    irqen_r                                               when sel_irqen = '1' else
    "0000" & txf_level & "0000" & rxf_level               when sel_level = '1' else
    (others => '0');

  -- ----------------------------------------------------------- IRQ por nivel
  irq_p : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        irq <= '0';
      else
        irq <= or (stat_v and irqen_r);
      end if;
    end if;
  end process irq_p;

  -- ------------------------------------------------------ registros y stickies
  regs : process (clk)
    variable wr : boolean;
  begin
    if rising_edge(clk) then
     if rst = '1' then
      ctrl_r  <= (others => '0');
      maclo_r <= (others => '0');
      machi_r <= (others => '0');
      irqen_r <= (others => '0');
      stk     <= (others => '0');
      txf_clr <= '1';
      rxf_clr <= '1';
     else
      wr := (sel = '1') and (we = '1');

      -- pulsos por defecto: EN=0 -> FIFOs en limpieza continua
      txf_clr <= not en_i;
      rxf_clr <= not en_i;

      -- escrituras de registros
      if wr then
        if sel_ctrl = '1' then
          ctrl_r <= wdata(2 downto 0);
        elsif sel_maclo = '1' then
          maclo_r <= wdata;
        elsif sel_machi = '1' then
          machi_r <= wdata(15 downto 0);
        elsif sel_cmd = '1' then
          if wdata(0) = '1' then txf_clr <= '1'; end if;
          if wdata(1) = '1' then rxf_clr <= '1'; end if;
        elsif sel_irqen = '1' then
          irqen_r <= wdata;
        elsif sel_stat = '1' then
          -- W1C per bit: only the stickies written with '1' are cleared...
          stk <= stk and not wdata(25 downto 16);
        end if;
      end if;

      -- ...y los sets del mismo ciclo GANAN
      if mac_rx_ev_ok   = '1' then stk(0) <= '1'; end if;  -- RX_OK
      if mac_rx_ev_crc  = '1' then stk(1) <= '1'; end if;  -- RX_CRC
      if mac_rx_ev_runt = '1' then stk(2) <= '1'; end if;  -- RX_RUNT
      if mac_rx_ev_drop = '1' then stk(3) <= '1'; end if;  -- RX_DROP
      if mac_tx_underrun = '1' then stk(4) <= '1'; end if; -- TX_UNDERRUN
      -- TXF_OVF: escritura a TXD con FIFO lleno (byte perdido)
      if sel = '1' and we = '1' and sel_txd = '1' and txf_full = '1' then
        stk(5) <= '1';
      end if;
      -- RXF_OVF: an RX frame was dropped whole because it did not fit
      if rxf_rewind = '1' then
        stk(6) <= '1';
      end if;
      if mac_rx_ev_ovs = '1' then stk(7) <= '1'; end if;  -- RX_OVERSIZE
      if mac_phy_ovf   = '1' then stk(8) <= '1'; end if;  -- PHY_RX_OVF
      if mac_phy_unf   = '1' then stk(9) <= '1'; end if;  -- PHY_TX_UNF
     end if;
    end if;
  end process regs;

end architecture rtl;
