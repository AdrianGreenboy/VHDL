-- ============================================================================
--  i3c_mmio.vhd - Capa 2: registros del IP I3C (controller + target + FIFOs)
--
--  Envuelve i3c_controller e i3c_target con tres FIFOs FWFT de 32 bytes
--  (RX del controller, TTX de lecturas del target, TRX de escrituras al
--  target) y el banco de registros. Bus dmem simple: sel (req de 1 ciclo),
--  we, addr(7:0), wdata; rdata es COMBINACIONAL y el pop-on-read se consume
--  en el flanco del req (contrato dmem del RV32i).
--
--  Semanticas (heredadas del IP IIC):
--    - STAT: los stickies se limpian con CUALQUIER escritura a STAT; los
--      sets del mismo ciclo GANAN sobre la limpieza.
--    - IRQ por NIVEL sin ack: irq = or(IRQ_EN and IRQ_STAT).
--    - Overflow de FIFO: drop-newest + sticky.
--    - CMD: la escritura latchea los campos y arma issue_pend; cmd_valid
--      pulsa cuando el motor esta libre. Si tras un CMD con START aparece
--      IBI_REQ en vez de DONE, el comando se perdio contra un IBI entrante:
--      el firmware debe atender el IBI y reintentar.
--    - LOOP_INT (CTRL b7): bus interno resuelto entre controller y target
--      (wired-AND con pull-up implicito), pads liberados. Es el self-test.
--
--  Mapa de registros: ver README (offsets 0x00-0x4C, decode addr(7:0)).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i3c_mmio is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;                          -- sincrono, activo alto

    sel    : in  std_logic;                          -- req de 1 ciclo
    we     : in  std_logic;
    addr   : in  std_logic_vector(7 downto 0);
    wdata  : in  std_logic_vector(31 downto 0);
    rdata  : out std_logic_vector(31 downto 0);      -- COMBINACIONAL

    irq    : out std_logic;

    scl_o  : out std_logic;
    scl_t  : out std_logic;
    scl_i  : in  std_logic;
    sda_o  : out std_logic;
    sda_t  : out std_logic;
    sda_i  : in  std_logic
  );
end entity i3c_mmio;

architecture rtl of i3c_mmio is

  -- registros de configuracion
  signal en_r, ten_r, loop_r : std_logic := '0';
  signal divpp_r : std_logic_vector(15 downto 0) := x"0004";
  signal divod_r : std_logic_vector(15 downto 0) := x"0009";
  signal sa_r    : std_logic_vector(6 downto 0)  := (others => '0');
  signal pidl_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal pidh_r  : std_logic_vector(15 downto 0) := (others => '0');
  signal bcr_r   : std_logic_vector(7 downto 0)  := x"46";
  signal dcr_r   : std_logic_vector(7 downto 0)  := x"C6";
  signal mdb_r   : std_logic_vector(7 downto 0)  := x"00";
  signal stsw_r  : std_logic_vector(15 downto 0) := (others => '0');
  signal irqen_r : std_logic_vector(31 downto 0) := (others => '0');
  signal wmrx_r  : unsigned(5 downto 0) := (others => '0');
  signal wmtrx_r : unsigned(5 downto 0) := (others => '0');

  -- stickies
  signal s_done, s_arb, s_ibia, s_evda, s_rst : std_logic := '0';
  signal s_perr, s_ibid, s_ibin, s_hjd        : std_logic := '0';
  signal s_rxovf, s_ttxovf, s_trxovf          : std_logic := '0';

  -- comando latcheado + pendiente
  signal l_wdata : std_logic_vector(7 downto 0) := (others => '0');
  signal l_start, l_stop, l_read, l_rlast, l_nobyte : std_logic := '0';
  signal l_daa, l_daadr, l_ibiack, l_ibinak : std_logic := '0';
  signal pend_r  : std_logic := '0';
  signal cvalid_r : std_logic := '0';

  -- pulsos hacia el target
  signal ibigo_p, hjgo_p : std_logic := '0';

  -- controller
  signal c_busy, c_done, c_rvalid, c_ack, c_tbit, c_arb : std_logic;
  signal c_rdata, c_ibiaddr : std_logic_vector(7 downto 0);
  signal c_ibireq, c_ibiav, c_xopen : std_logic;
  signal c_scl_o, c_scl_t, c_sda_o, c_sda_t : std_logic;
  signal c_scl_i, c_sda_i : std_logic;

  -- target
  signal t_txdata : std_logic_vector(7 downto 0);
  signal t_txvalid, t_txren : std_logic;
  signal t_rxdata : std_logic_vector(7 downto 0);
  signal t_rxvalid, t_rxperr : std_logic;
  signal t_da : std_logic_vector(6 downto 0);
  signal t_dav, t_ibien, t_hjen : std_logic;
  signal t_mwl, t_mrl : std_logic_vector(15 downto 0);
  signal t_ibip, t_hjp : std_logic;
  signal t_ibid, t_ibin, t_hjd : std_logic;
  signal t_evda, t_evrst, t_inframe : std_logic;
  signal t_sda_o, t_sda_t : std_logic;
  signal t_scl_i, t_sda_i : std_logic;

  -- bus interno del loopback
  signal scl_int, sda_int : std_logic;

  -- FIFOs
  signal aresetn : std_logic;
  signal rx_wr, rx_rd, rx_full, rx_empty : std_logic;
  signal rx_q : std_logic_vector(7 downto 0);
  signal rx_lvl : unsigned(5 downto 0);
  signal ttx_wr, ttx_full, ttx_empty : std_logic;
  signal ttx_q : std_logic_vector(7 downto 0);
  signal ttx_lvl : unsigned(5 downto 0);
  signal trx_wr, trx_rd, trx_full, trx_empty : std_logic;
  signal trx_q : std_logic_vector(7 downto 0);
  signal trx_lvl : unsigned(5 downto 0);

  signal irqstat : std_logic_vector(31 downto 0);
  signal rx_wmhit, trx_wmhit : std_logic;
  signal pid_w : std_logic_vector(47 downto 0);

begin

  aresetn <= not rst;
  pid_w   <= pidh_r & pidl_r;

  -- ==========================================================================
  --  Motores
  -- ==========================================================================
  u_ctrl : entity work.i3c_controller
    port map (
      clk => clk, rst => rst, en => en_r,
      div_pp => divpp_r, div_od => divod_r,
      cmd_valid => cvalid_r, cmd_start => l_start, cmd_stop => l_stop,
      cmd_read => l_read, cmd_rlast => l_rlast, cmd_nobyte => l_nobyte,
      cmd_daa => l_daa, cmd_daadr => l_daadr,
      cmd_ibiack => l_ibiack, cmd_ibinak => l_ibinak,
      cmd_wdata => l_wdata,
      busy => c_busy, done => c_done, rdata => c_rdata, rvalid => c_rvalid,
      ack_in => c_ack, t_bit => c_tbit, arb_lost => c_arb,
      ibi_req => c_ibireq, ibi_addr => c_ibiaddr, ibi_avalid => c_ibiav,
      xact_open => c_xopen,
      scl_o => c_scl_o, scl_t => c_scl_t, scl_i => c_scl_i,
      sda_o => c_sda_o, sda_t => c_sda_t, sda_i => c_sda_i
    );

  u_tgt : entity work.i3c_target
    port map (
      clk => clk, rst => rst, en => ten_r,
      sa => sa_r, pid => pid_w, bcr => bcr_r, dcr => dcr_r,
      status_in => stsw_r, mdb => mdb_r,
      ibi_go => ibigo_p, hj_go => hjgo_p,
      tx_data => t_txdata, tx_valid => t_txvalid, tx_ren => t_txren,
      rx_data => t_rxdata, rx_valid => t_rxvalid, rx_perr => t_rxperr,
      da => t_da, da_valid => t_dav, ibi_en => t_ibien, hj_en => t_hjen,
      mwl => t_mwl, mrl => t_mrl,
      ibi_pend => t_ibip, hj_pend => t_hjp,
      ibi_done => t_ibid, ibi_nakd => t_ibin, hj_done => t_hjd,
      ev_daset => t_evda, ev_rstdaa => t_evrst, in_frame => t_inframe,
      scl_i => t_scl_i, sda_i => t_sda_i, sda_o => t_sda_o, sda_t => t_sda_t
    );

  -- ==========================================================================
  --  Loopback interno / pads
  -- ==========================================================================
  scl_int <= c_scl_o or c_scl_t;                     -- pull-up implicito
  sda_int <= (c_sda_o or c_sda_t) and (t_sda_o or t_sda_t);

  c_scl_i <= scl_int when loop_r = '1' else scl_i;
  c_sda_i <= sda_int when loop_r = '1' else sda_i;
  t_scl_i <= scl_int when loop_r = '1' else scl_i;
  t_sda_i <= sda_int when loop_r = '1' else sda_i;

  scl_o <= c_scl_o;
  scl_t <= '1' when loop_r = '1' else c_scl_t;
  sda_o <= c_sda_o when c_sda_t = '0' else t_sda_o;
  sda_t <= '1' when loop_r = '1' else (c_sda_t and t_sda_t);

  -- ==========================================================================
  --  FIFOs FWFT de 32 bytes
  -- ==========================================================================
  u_rx : entity work.byte_fifo
    generic map (LOG2_DEPTH => 5)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => rx_wr, wr_data => c_rdata, full => rx_full,
      rd_en => rx_rd, rd_data => rx_q, empty => rx_empty, level => rx_lvl
    );

  u_ttx : entity work.byte_fifo
    generic map (LOG2_DEPTH => 5)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => ttx_wr, wr_data => wdata(7 downto 0), full => ttx_full,
      rd_en => t_txren, rd_data => ttx_q, empty => ttx_empty, level => ttx_lvl
    );

  u_trx : entity work.byte_fifo
    generic map (LOG2_DEPTH => 5)
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => trx_wr, wr_data => t_rxdata, full => trx_full,
      rd_en => trx_rd, rd_data => trx_q, empty => trx_empty, level => trx_lvl
    );

  rx_wr  <= c_rvalid and not rx_full;
  trx_wr <= t_rxvalid and not trx_full;
  ttx_wr <= '1' when sel = '1' and we = '1' and addr = x"38" and
                     ttx_full = '0' else '0';

  t_txdata  <= ttx_q;
  t_txvalid <= not ttx_empty;

  -- pop-on-read consumido en el flanco del req
  rx_rd  <= '1' when sel = '1' and we = '0' and addr = x"10" and
                     rx_empty = '0' else '0';
  trx_rd <= '1' when sel = '1' and we = '0' and addr = x"3C" and
                     trx_empty = '0' else '0';

  -- ==========================================================================
  --  IRQ por nivel
  -- ==========================================================================
  rx_wmhit  <= '1' when rx_lvl  >= ('0' & wmrx_r)  else '0';
  trx_wmhit <= '1' when trx_lvl >= ('0' & wmtrx_r) else '0';

  irqstat <= (0 => s_done, 1 => s_arb, 2 => c_ibireq, 3 => s_ibia,
              4 => rx_wmhit, 5 => trx_wmhit,
              6 => s_perr, 7 => s_ibid, 8 => s_ibin, 9 => s_hjd,
              10 => s_evda, 11 => s_rst, 12 => s_rxovf, 13 => s_ttxovf,
              14 => s_trxovf, others => '0');

  irq <= '1' when (irqstat and irqen_r) /= x"00000000" else '0';

  -- ==========================================================================
  --  rdata combinacional
  -- ==========================================================================
  process(all)
  begin
    case addr is
      when x"00" =>
        rdata <= (0 => en_r, 1 => ten_r, 7 => loop_r, others => '0');
      when x"04" =>
        rdata <= (0 => c_busy, 1 => c_xopen, 2 => c_ibireq, 3 => c_ack,
                  4 => c_tbit, 5 => t_inframe, 6 => t_dav, 7 => t_ibip,
                  8 => t_hjp, 9 => t_ibien, 10 => t_hjen,
                  16 => s_done, 17 => s_arb, 18 => s_ibia, 19 => s_evda,
                  20 => s_rst, 21 => s_perr, 22 => s_ibid, 23 => s_ibin,
                  24 => s_hjd, 25 => s_rxovf, 26 => s_ttxovf, 27 => s_trxovf,
                  others => '0');
      when x"08" =>
        rdata <= divod_r & divpp_r;
      when x"10" =>
        rdata <= x"00000" & "000" & (not rx_empty) & rx_q;
      when x"14" =>
        rdata <= x"000000" & c_ibiaddr;
      when x"18" =>
        rdata <= x"000000" & '0' & sa_r;
      when x"1C" =>
        rdata <= pidl_r;
      when x"20" =>
        rdata <= x"0000" & pidh_r;
      when x"24" =>
        rdata <= x"00" & mdb_r & dcr_r & bcr_r;
      when x"28" =>
        rdata <= x"0000" & stsw_r;
      when x"2C" =>
        rdata <= x"00000" & '0' & t_hjen & t_ibien & t_dav & '0' & t_da;
      when x"30" =>
        rdata <= t_mrl & t_mwl;
      when x"3C" =>
        rdata <= x"00000" & "000" & (not trx_empty) & trx_q;
      when x"40" =>
        rdata <= x"00" & "00" & std_logic_vector(trx_lvl) &
                 "00" & std_logic_vector(ttx_lvl) &
                 "00" & std_logic_vector(rx_lvl);
      when x"44" =>
        rdata <= irqen_r;
      when x"48" =>
        rdata <= irqstat;
      when x"4C" =>
        rdata <= x"0000" & "00" & std_logic_vector(wmtrx_r) &
                 "00" & std_logic_vector(wmrx_r);
      when others =>
        rdata <= (others => '0');
    end case;
  end process;

  -- ==========================================================================
  --  Escrituras, stickies y emision de comandos
  -- ==========================================================================
  process(clk)
  begin
    if rising_edge(clk) then
      ibigo_p  <= '0';
      hjgo_p   <= '0';
      cvalid_r <= '0';

      if rst = '1' then
        en_r <= '0'; ten_r <= '0'; loop_r <= '0';
        divpp_r <= x"0004"; divod_r <= x"0009";
        sa_r <= (others => '0');
        pidl_r <= (others => '0'); pidh_r <= (others => '0');
        bcr_r <= x"46"; dcr_r <= x"C6"; mdb_r <= x"00";
        stsw_r <= (others => '0');
        irqen_r <= (others => '0');
        wmrx_r <= (others => '0'); wmtrx_r <= (others => '0');
        s_done <= '0'; s_arb <= '0'; s_ibia <= '0'; s_evda <= '0';
        s_rst <= '0'; s_perr <= '0'; s_ibid <= '0'; s_ibin <= '0';
        s_hjd <= '0'; s_rxovf <= '0'; s_ttxovf <= '0'; s_trxovf <= '0';
        pend_r <= '0';
        l_start <= '0'; l_stop <= '0'; l_read <= '0'; l_rlast <= '0';
        l_nobyte <= '0'; l_daa <= '0'; l_daadr <= '0';
        l_ibiack <= '0'; l_ibinak <= '0';
        l_wdata <= (others => '0');
      else

        -- escrituras de registros
        if sel = '1' and we = '1' then
          case addr is
            when x"00" =>
              en_r   <= wdata(0);
              ten_r  <= wdata(1);
              loop_r <= wdata(7);
            when x"04" =>
              -- limpiar stickies (los sets de este mismo ciclo GANAN abajo)
              s_done <= '0'; s_arb <= '0'; s_ibia <= '0'; s_evda <= '0';
              s_rst <= '0'; s_perr <= '0'; s_ibid <= '0'; s_ibin <= '0';
              s_hjd <= '0'; s_rxovf <= '0'; s_ttxovf <= '0'; s_trxovf <= '0';
            when x"08" =>
              divpp_r <= wdata(15 downto 0);
              divod_r <= wdata(31 downto 16);
            when x"0C" =>
              l_wdata  <= wdata(7 downto 0);
              l_start  <= wdata(8);
              l_stop   <= wdata(9);
              l_read   <= wdata(10);
              l_rlast  <= wdata(11);
              l_nobyte <= wdata(12);
              l_daa    <= wdata(13);
              l_daadr  <= wdata(14);
              l_ibiack <= wdata(15);
              l_ibinak <= wdata(16);
              pend_r   <= '1';
            when x"18" =>
              sa_r <= wdata(6 downto 0);
            when x"1C" =>
              pidl_r <= wdata;
            when x"20" =>
              pidh_r <= wdata(15 downto 0);
            when x"24" =>
              bcr_r <= wdata(7 downto 0);
              dcr_r <= wdata(15 downto 8);
              mdb_r <= wdata(23 downto 16);
            when x"28" =>
              stsw_r <= wdata(15 downto 0);
            when x"34" =>
              ibigo_p <= wdata(0);
              hjgo_p  <= wdata(1);
            when x"44" =>
              irqen_r <= wdata;
            when x"4C" =>
              wmrx_r  <= unsigned(wdata(5 downto 0));
              wmtrx_r <= unsigned(wdata(13 downto 8));
            when others =>
              null;
          end case;
        end if;

        -- emision del comando cuando el motor esta libre
        if pend_r = '1' and c_busy = '0' and cvalid_r = '0' then
          cvalid_r <= '1';
          pend_r   <= '0';
        end if;

        -- stickies: los sets van DESPUES de la limpieza para ganar el ciclo
        if c_done = '1'   then s_done <= '1'; end if;
        if c_arb = '1'    then s_arb  <= '1'; end if;
        if c_ibiav = '1'  then s_ibia <= '1'; end if;
        if t_evda = '1'   then s_evda <= '1'; end if;
        if t_evrst = '1'  then s_rst  <= '1'; end if;
        if t_rxperr = '1' then s_perr <= '1'; end if;
        if t_ibid = '1'   then s_ibid <= '1'; end if;
        if t_ibin = '1'   then s_ibin <= '1'; end if;
        if t_hjd = '1'    then s_hjd  <= '1'; end if;
        if c_rvalid = '1' and rx_full = '1'   then s_rxovf  <= '1'; end if;
        if sel = '1' and we = '1' and addr = x"38" and ttx_full = '1' then
          s_ttxovf <= '1';
        end if;
        if t_rxvalid = '1' and trx_full = '1' then s_trxovf <= '1'; end if;

      end if;
    end if;
  end process;

end architecture rtl;
