-- ============================================================================
--  can_mmio.vhd - Capa 2: registros del IP CAN (dos nucleos, A y B)
--
--  Envuelve DOS instancias identicas de can_engine (nodo A y nodo B) con un
--  FIFO FWFT de recepcion de 128 bytes por nodo. Cada trama recibida se
--  empaqueta en un registro FIJO de 13 bytes: [flags+ID (4, MSB primero),
--  DLC (1), datos (8, byte0 primero, relleno a cero)]. Bus dmem simple:
--  sel (req de 1 ciclo), we, addr(7:0), wdata; rdata es COMBINACIONAL y el
--  pop-on-read se consume en el flanco del req (contrato dmem del RV32i).
--
--  Semanticas (heredadas de los IP IIC/I3C):
--    - STAT: los stickies (b16..) se limpian con CUALQUIER escritura a STAT;
--      los sets del mismo ciclo GANAN sobre la limpieza.
--    - IRQ por NIVEL sin ack: irq = or(IRQ_EN and IRQ_STAT).
--    - Overflow de RX: drop-newest a granularidad de TRAMA + sticky.
--    - CMD_x: escritura con b0 (GO) pulsa tx_req del nodo (el motor latchea
--      los campos y reintenta solo); b1 (ABORT) cancela la peticion.
--    - LOOP_INT (CTRL b7): bus interno resuelto entre A y B (AND cableado,
--      dominante = 0), pads liberados. Es el self-test de silicio.
--    - SELFACK_x (CTRL b8/b9): ack_free del nodo; NO conforme con ISO 11898
--      (un nodo jamas asiente su propia trama), solo para depuracion sin
--      segundo nodo.
--    - EN_x: con '0' el nucleo queda en reset sincrono (configurar BTR antes
--      de habilitar).
--
--  Mapa de registros (decode addr(7:0)):
--    0x00 CTRL    b0 EN_A, b1 EN_B, b7 LOOP_INT, b8 SELFACK_A, b9 SELFACK_B
--    0x04 STAT    vivos: b0 BUSY_A, b1 BUSY_B, b3:2 ESTADO_A, b5:4 ESTADO_B,
--                        b6 RXNE_A, b7 RXNE_B
--                 stickies: b16 TXDONE_A, b17 TXDONE_B, b18 ARB_A, b19 ARB_B,
--                        b20 TXERR_A, b21 TXERR_B, b22 ERR_A, b23 ERR_B,
--                        b24 RXV_A, b25 RXV_B, b26 RXOVF_A, b27 RXOVF_B
--    0x08 BTR     b7:0 BRP, b11:8 TSEG1, b14:12 TSEG2, b17:16 SJW
--    0x10 TXID_A  b28:0 ID, b29 RTR, b30 IDE      0x30 TXID_B
--    0x14 TXDLC_A b3:0                            0x34 TXDLC_B
--    0x18 TXDH_A  bytes 0-3 (tx_data 63:32)       0x38 TXDH_B
--    0x1C TXDL_A  bytes 4-7 (tx_data 31:0)        0x3C TXDL_B
--    0x20 CMD_A   b0 GO, b1 ABORT (por escritura) 0x40 CMD_B
--    0x24 RXFIFO_A pop-on-read: b7:0 byte, b8 VALID   0x44 RXFIFO_B
--    0x28 CNT_A   b8:0 TEC, b23:16 REC            0x48 CNT_B
--    0x50 LVL     b7:0 nivel_A, b15:8 nivel_B
--    0x54 IRQ_EN
--    0x58 IRQ_STAT b0 TXDONE_A(s), b1 TXDONE_B(s), b2 RXNE_A, b3 RXNE_B,
--                  b4 ARB_A(s), b5 ARB_B(s), b6 TXERR_A(s), b7 TXERR_B(s),
--                  b8 ERR_A(s), b9 ERR_B(s), b10 RXOVF_A(s), b11 RXOVF_B(s),
--                  b12 BUSOFF_A, b13 BUSOFF_B, b14 WMHIT_A, b15 WMHIT_B
--    0x5C WM      b7:0 WM_A, b15:8 WM_B (nivel >= WM dispara WMHIT)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity can_mmio is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;                        -- sincrono, activo alto

    sel      : in  std_logic;                        -- req de 1 ciclo
    we       : in  std_logic;
    addr     : in  std_logic_vector(7 downto 0);
    wdata    : in  std_logic_vector(31 downto 0);
    rdata    : out std_logic_vector(31 downto 0);    -- COMBINACIONAL

    irq      : out std_logic;

    can_tx_o : out std_logic;                        -- '0' dominante
    can_tx_t : out std_logic;                        -- '1' = pad liberado
    can_rx_i : in  std_logic
  );
end entity can_mmio;

architecture rtl of can_mmio is

  -- configuracion
  signal ena_r, enb_r, loop_r : std_logic := '0';
  signal sacka_r, sackb_r : std_logic := '0';
  signal brp_r   : std_logic_vector(7 downto 0) := x"09";
  signal tseg1_r : std_logic_vector(3 downto 0) := "1100";
  signal tseg2_r : std_logic_vector(2 downto 0) := "101";
  signal sjw_r   : std_logic_vector(1 downto 0) := "01";
  signal irqen_r : std_logic_vector(31 downto 0) := (others => '0');
  signal wma_r, wmb_r : unsigned(7 downto 0) := (others => '0');

  -- TX por nodo
  signal txida_r, txidb_r : std_logic_vector(28 downto 0) := (others => '0');
  signal idea_r, ideb_r, rtra_r, rtrb_r : std_logic := '0';
  signal dlca_r, dlcb_r : std_logic_vector(3 downto 0) := (others => '0');
  signal txda_r, txdb_r : std_logic_vector(63 downto 0) := (others => '0');
  signal reqa_p, reqb_p, aba_p, abb_p : std_logic := '0';

  -- stickies
  signal s_tda, s_tdb, s_arba, s_arbb : std_logic := '0';
  signal s_txea, s_txeb, s_erra, s_errb : std_logic := '0';
  signal s_rxva, s_rxvb, s_ovfa, s_ovfb : std_logic := '0';

  -- motores
  signal rstna, rstnb : std_logic;
  signal a_tx, b_tx, a_rx, b_rx, bus_int : std_logic;
  signal a_busy, a_done, a_arb, a_txe, a_rxv, a_errp : std_logic;
  signal b_busy, b_done, b_arb, b_txe, b_rxv, b_errp : std_logic;
  signal a_rid, b_rid : std_logic_vector(28 downto 0);
  signal a_ride, a_rrtr, b_ride, b_rrtr : std_logic;
  signal a_rdlc, b_rdlc : std_logic_vector(3 downto 0);
  signal a_rdat, b_rdat : std_logic_vector(63 downto 0);
  signal a_tec, b_tec : std_logic_vector(8 downto 0);
  signal a_rec, b_rec : std_logic_vector(7 downto 0);
  signal a_est, b_est : std_logic_vector(1 downto 0);

  -- FIFOs de recepcion (128 bytes, registros de 13 bytes)
  signal aresetn : std_logic;
  signal fa_wr, fa_rd, fa_full, fa_empty : std_logic;
  signal fa_d, fa_q : std_logic_vector(7 downto 0);
  signal fa_lvl : unsigned(7 downto 0);
  signal fb_wr, fb_rd, fb_full, fb_empty : std_logic;
  signal fb_d, fb_q : std_logic_vector(7 downto 0);
  signal fb_lvl : unsigned(7 downto 0);

  -- empaquetadores (13 bytes por trama)
  signal pka_sr, pkb_sr : std_logic_vector(103 downto 0) := (others => '0');
  signal pka_n, pkb_n : integer range 0 to 13 := 0;

  signal irqstat : std_logic_vector(31 downto 0);
  signal wmhita, wmhitb : std_logic;
  signal boffa, boffb : std_logic;

begin

  aresetn <= not rst;
  rstna <= (not rst) and ena_r;
  rstnb <= (not rst) and enb_r;

  -- ==========================================================================
  --  Nucleos
  -- ==========================================================================
  nodo_a : entity work.can_engine
    port map (
      clk => clk, rstn => rstna,
      brp => brp_r, tseg1 => tseg1_r, tseg2 => tseg2_r, sjw => sjw_r,
      ack_free => sacka_r,
      tx_req => reqa_p, tx_abort => aba_p,
      tx_id => txida_r, tx_ide => idea_r, tx_rtr => rtra_r,
      tx_dlc => dlca_r, tx_data => txda_r,
      tx_busy => a_busy, tx_done => a_done, tx_arb_lost => a_arb,
      tx_err => a_txe,
      rx_valid => a_rxv, rx_id => a_rid, rx_ide => a_ride,
      rx_rtr => a_rrtr, rx_dlc => a_rdlc, rx_data => a_rdat,
      tec => a_tec, rec => a_rec, err_state => a_est, err_pulse => a_errp,
      can_rx => a_rx, can_tx => a_tx );

  nodo_b : entity work.can_engine
    port map (
      clk => clk, rstn => rstnb,
      brp => brp_r, tseg1 => tseg1_r, tseg2 => tseg2_r, sjw => sjw_r,
      ack_free => sackb_r,
      tx_req => reqb_p, tx_abort => abb_p,
      tx_id => txidb_r, tx_ide => ideb_r, tx_rtr => rtrb_r,
      tx_dlc => dlcb_r, tx_data => txdb_r,
      tx_busy => b_busy, tx_done => b_done, tx_arb_lost => b_arb,
      tx_err => b_txe,
      rx_valid => b_rxv, rx_id => b_rid, rx_ide => b_ride,
      rx_rtr => b_rrtr, rx_dlc => b_rdlc, rx_data => b_rdat,
      tec => b_tec, rec => b_rec, err_state => b_est, err_pulse => b_errp,
      can_rx => b_rx, can_tx => b_tx );

  -- ==========================================================================
  --  Bus interno resuelto (AND cableado, dominante = 0) / pads
  -- ==========================================================================
  bus_int <= a_tx and b_tx;

  a_rx <= bus_int when loop_r = '1' else (bus_int and can_rx_i);
  b_rx <= bus_int when loop_r = '1' else (bus_int and can_rx_i);

  can_tx_o <= bus_int;
  can_tx_t <= '1' when loop_r = '1' else '0';

  -- ==========================================================================
  --  FIFOs FWFT de recepcion (128 bytes por nodo)
  -- ==========================================================================
  fifo_a : entity work.byte_fifo
    generic map (LOG2_DEPTH => 7)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => fa_wr, wr_data => fa_d, full => fa_full,
      rd_en => fa_rd, rd_data => fa_q, empty => fa_empty, level => fa_lvl
    );

  fifo_b : entity work.byte_fifo
    generic map (LOG2_DEPTH => 7)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => fb_wr, wr_data => fb_d, full => fb_full,
      rd_en => fb_rd, rd_data => fb_q, empty => fb_empty, level => fb_lvl
    );

  fa_wr <= '1' when pka_n /= 0 else '0';
  fb_wr <= '1' when pkb_n /= 0 else '0';
  fa_d  <= pka_sr(103 downto 96);
  fb_d  <= pkb_sr(103 downto 96);

  -- pop-on-read consumido en el flanco del req
  fa_rd <= '1' when sel = '1' and we = '0' and addr = x"24" and
                    fa_empty = '0' else '0';
  fb_rd <= '1' when sel = '1' and we = '0' and addr = x"44" and
                    fb_empty = '0' else '0';

  -- ==========================================================================
  --  IRQ por nivel
  -- ==========================================================================
  boffa <= '1' when a_est = "10" else '0';
  boffb <= '1' when b_est = "10" else '0';

  wmhita <= '1' when fa_lvl >= wma_r else '0';
  wmhitb <= '1' when fb_lvl >= wmb_r else '0';

  irqstat <= (0 => s_tda, 1 => s_tdb,
              2 => not fa_empty, 3 => not fb_empty,
              4 => s_arba, 5 => s_arbb,
              6 => s_txea, 7 => s_txeb,
              8 => s_erra, 9 => s_errb,
              10 => s_ovfa, 11 => s_ovfb,
              12 => boffa, 13 => boffb,
              14 => wmhita, 15 => wmhitb,
              others => '0');

  irq <= '1' when (irqstat and irqen_r) /= x"00000000" else '0';

  -- ==========================================================================
  --  rdata combinacional
  -- ==========================================================================
  process(all)
  begin
    case addr is
      when x"00" =>
        rdata <= (0 => ena_r, 1 => enb_r, 7 => loop_r,
                  8 => sacka_r, 9 => sackb_r, others => '0');
      when x"04" =>
        rdata <= (0 => a_busy, 1 => b_busy,
                  2 => a_est(0), 3 => a_est(1),
                  4 => b_est(0), 5 => b_est(1),
                  6 => not fa_empty, 7 => not fb_empty,
                  16 => s_tda, 17 => s_tdb, 18 => s_arba, 19 => s_arbb,
                  20 => s_txea, 21 => s_txeb, 22 => s_erra, 23 => s_errb,
                  24 => s_rxva, 25 => s_rxvb, 26 => s_ovfa, 27 => s_ovfb,
                  others => '0');
      when x"08" =>
        rdata <= x"000" & "00" & sjw_r & '0' & tseg2_r & tseg1_r & brp_r;
      when x"10" =>
        rdata <= '0' & idea_r & rtra_r & txida_r;
      when x"14" =>
        rdata <= x"0000000" & dlca_r;
      when x"18" =>
        rdata <= txda_r(63 downto 32);
      when x"1C" =>
        rdata <= txda_r(31 downto 0);
      when x"24" =>
        rdata <= x"00000" & "000" & (not fa_empty) & fa_q;
      when x"28" =>
        rdata <= x"00" & a_rec & '0' & "000000" & a_tec;
      when x"30" =>
        rdata <= '0' & ideb_r & rtrb_r & txidb_r;
      when x"34" =>
        rdata <= x"0000000" & dlcb_r;
      when x"38" =>
        rdata <= txdb_r(63 downto 32);
      when x"3C" =>
        rdata <= txdb_r(31 downto 0);
      when x"44" =>
        rdata <= x"00000" & "000" & (not fb_empty) & fb_q;
      when x"48" =>
        rdata <= x"00" & b_rec & '0' & "000000" & b_tec;
      when x"50" =>
        rdata <= x"0000" & std_logic_vector(fb_lvl) & std_logic_vector(fa_lvl);
      when x"54" =>
        rdata <= irqen_r;
      when x"58" =>
        rdata <= irqstat;
      when x"5C" =>
        rdata <= x"0000" & std_logic_vector(wmb_r) & std_logic_vector(wma_r);
      when others =>
        rdata <= (others => '0');
    end case;
  end process;

  -- ==========================================================================
  --  Escrituras, stickies y empaquetado de RX
  -- ==========================================================================
  process(clk)
  begin
    if rising_edge(clk) then
      reqa_p <= '0'; reqb_p <= '0';
      aba_p <= '0'; abb_p <= '0';

      if rst = '1' then
        ena_r <= '0'; enb_r <= '0'; loop_r <= '0';
        sacka_r <= '0'; sackb_r <= '0';
        brp_r <= x"09"; tseg1_r <= "1100"; tseg2_r <= "101"; sjw_r <= "01";
        irqen_r <= (others => '0');
        wma_r <= (others => '0'); wmb_r <= (others => '0');
        txida_r <= (others => '0'); txidb_r <= (others => '0');
        idea_r <= '0'; ideb_r <= '0'; rtra_r <= '0'; rtrb_r <= '0';
        dlca_r <= (others => '0'); dlcb_r <= (others => '0');
        txda_r <= (others => '0'); txdb_r <= (others => '0');
        s_tda <= '0'; s_tdb <= '0'; s_arba <= '0'; s_arbb <= '0';
        s_txea <= '0'; s_txeb <= '0'; s_erra <= '0'; s_errb <= '0';
        s_rxva <= '0'; s_rxvb <= '0'; s_ovfa <= '0'; s_ovfb <= '0';
        pka_n <= 0; pkb_n <= 0;
      else

        -- escrituras de registros
        if sel = '1' and we = '1' then
          case addr is
            when x"00" =>
              ena_r   <= wdata(0);
              enb_r   <= wdata(1);
              loop_r  <= wdata(7);
              sacka_r <= wdata(8);
              sackb_r <= wdata(9);
            when x"04" =>
              -- limpiar stickies (los sets de este mismo ciclo GANAN abajo)
              s_tda <= '0'; s_tdb <= '0'; s_arba <= '0'; s_arbb <= '0';
              s_txea <= '0'; s_txeb <= '0'; s_erra <= '0'; s_errb <= '0';
              s_rxva <= '0'; s_rxvb <= '0'; s_ovfa <= '0'; s_ovfb <= '0';
            when x"08" =>
              brp_r   <= wdata(7 downto 0);
              tseg1_r <= wdata(11 downto 8);
              tseg2_r <= wdata(14 downto 12);
              sjw_r   <= wdata(17 downto 16);
            when x"10" =>
              txida_r <= wdata(28 downto 0);
              rtra_r  <= wdata(29);
              idea_r  <= wdata(30);
            when x"14" =>
              dlca_r <= wdata(3 downto 0);
            when x"18" =>
              txda_r(63 downto 32) <= wdata;
            when x"1C" =>
              txda_r(31 downto 0) <= wdata;
            when x"20" =>
              reqa_p <= wdata(0);
              aba_p  <= wdata(1);
            when x"30" =>
              txidb_r <= wdata(28 downto 0);
              rtrb_r  <= wdata(29);
              ideb_r  <= wdata(30);
            when x"34" =>
              dlcb_r <= wdata(3 downto 0);
            when x"38" =>
              txdb_r(63 downto 32) <= wdata;
            when x"3C" =>
              txdb_r(31 downto 0) <= wdata;
            when x"40" =>
              reqb_p <= wdata(0);
              abb_p  <= wdata(1);
            when x"54" =>
              irqen_r <= wdata;
            when x"5C" =>
              wma_r <= unsigned(wdata(7 downto 0));
              wmb_r <= unsigned(wdata(15 downto 8));
            when others =>
              null;
          end case;
        end if;

        -- empaquetado de tramas recibidas (13 bytes, drop-newest por trama)
        if a_rxv = '1' then
          if pka_n = 0 and fa_lvl <= 115 then
            pka_sr <= '0' & a_ride & a_rrtr & a_rid & x"0" & a_rdlc & a_rdat;
            pka_n  <= 13;
          else
            s_ovfa <= '1';
          end if;
        elsif pka_n /= 0 then
          pka_sr <= pka_sr(95 downto 0) & x"00";
          pka_n  <= pka_n - 1;
        end if;

        if b_rxv = '1' then
          if pkb_n = 0 and fb_lvl <= 115 then
            pkb_sr <= '0' & b_ride & b_rrtr & b_rid & x"0" & b_rdlc & b_rdat;
            pkb_n  <= 13;
          else
            s_ovfb <= '1';
          end if;
        elsif pkb_n /= 0 then
          pkb_sr <= pkb_sr(95 downto 0) & x"00";
          pkb_n  <= pkb_n - 1;
        end if;

        -- stickies: los sets van DESPUES de la limpieza para ganar el ciclo
        if a_done = '1' then s_tda  <= '1'; end if;
        if b_done = '1' then s_tdb  <= '1'; end if;
        if a_arb  = '1' then s_arba <= '1'; end if;
        if b_arb  = '1' then s_arbb <= '1'; end if;
        if a_txe  = '1' then s_txea <= '1'; end if;
        if b_txe  = '1' then s_txeb <= '1'; end if;
        if a_errp = '1' then s_erra <= '1'; end if;
        if b_errp = '1' then s_errb <= '1'; end if;
        if a_rxv  = '1' then s_rxva <= '1'; end if;
        if b_rxv  = '1' then s_rxvb <= '1'; end if;

      end if;
    end if;
  end process;

end architecture rtl;
