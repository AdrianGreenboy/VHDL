-- ptp_mac.vhd — integracion TSN: eth_mac + bloque PTP completo (802.1AS v1)
-- ---------------------------------------------------------------------------
-- Envolvente que ata todas las piezas verificadas alrededor del eth_mac:
--   - ptp_clock       : reloj ajustable + servo PI
--   - ptp_tstamp x2   : captura de TS en SFD TX y SFD RX
--   - ptp_tx          : motor generador (Sync/Pdelay_Req/Pdelay_Resp)
--   - ptp_rx          : parser de mensajes gPTP entrantes
--   - ptp_pdelay_fsm  : orquestacion peer-delay (iniciador + respondedor)
--   - ptp_pdelay      : calculo del meanPathDelay
--   - lazo esclavo Sync: RX Sync -> offset -> servo (aqui, logica local)
--   - FIFO de trama TX-PTP + gate store-and-forward
--
-- Rol conmutable por role_slave (CONTROL.role). LOOP_INT via eth_mac.loopback.
-- Un solo dominio de reloj a 100 MHz; el reloj PTP avanza a full clock.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity ptp_mac is
  generic (
    SHIFT_P : integer := SHIFT_P_DEF;
    SHIFT_I : integer := SHIFT_I_DEF
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    loopback   : in  std_logic;                     -- '1' LOOP_INT
    -- rol e identidad (registros MMIO)
    role_slave : in  std_logic;                     -- '1' esclavo, '0' maestro
    clock_id   : in  std_logic_vector(63 downto 0);
    port_num   : in  std_logic_vector(15 downto 0);
    src_mac    : in  std_logic_vector(47 downto 0);
    macaddr    : in  std_logic_vector(47 downto 0); -- filtro RX (= src_mac o multicast)
    -- servo
    kp         : in  std_logic_vector(15 downto 0);
    ki         : in  std_logic_vector(15 downto 0);
    tx_lat     : in  std_logic_vector(15 downto 0); -- latencia calib TX SFD
    rx_lat     : in  std_logic_vector(15 downto 0); -- latencia calib RX SFD
    -- ordenes
    send_sync    : in  std_logic;                   -- pulso: emitir un Sync (maestro)
    start_pdelay : in  std_logic;                   -- pulso: iniciar Pdelay
    -- observabilidad
    now_sec    : out std_logic_vector(SEC_W-1 downto 0);
    now_ns     : out std_logic_vector(NS_W-1 downto 0);
    mpd_ns     : out std_logic_vector(63 downto 0); -- meanPathDelay
    mpd_valid  : out std_logic;
    offset_valid_o : out std_logic;                 -- pulso: offset procesado
    rx_sync_ev : out std_logic;                     -- pulso: Sync recibido
    rx_resp_ev : out std_logic;                     -- pulso: Pdelay_Resp recibido
    offset_ns  : out std_logic_vector(ERR_W-1 downto 0);  -- ultimo offset medido
    rate_adj   : out std_logic_vector(RATE_W-1 downto 0);
    -- observabilidad del parser RX (para verificacion/depuracion)
    dbg_rx_mvalid : out std_logic;
    dbg_rx_mtype  : out std_logic_vector(3 downto 0);
    dbg_rx_seqid  : out std_logic_vector(15 downto 0);
    -- observabilidad del peer-delay (t1..t4 y corr usados en el calculo)
    dbg_t1_ns     : out std_logic_vector(NS_W-1 downto 0);
    dbg_t4_ns     : out std_logic_vector(NS_W-1 downto 0);
    dbg_pd_corr   : out std_logic_vector(63 downto 0);
    dbg_pd_calc   : out std_logic;
    -- pines MII (externos; inertes en LOOP_INT)
    mii_txd    : out std_logic_vector(3 downto 0);
    mii_tx_en  : out std_logic;
    mii_rxd    : in  std_logic_vector(3 downto 0);
    mii_rx_dv  : in  std_logic;
    dbg_state  : out std_logic_vector(31 downto 0)
  );
end entity ptp_mac;

architecture rtl of ptp_mac is
  -- reloj
  signal clk_sec : std_logic_vector(SEC_W-1 downto 0);
  signal clk_ns  : std_logic_vector(NS_W-1 downto 0);
  signal offset_err : std_logic_vector(ERR_W-1 downto 0) := (others => '0');
  signal offset_valid : std_logic := '0';

  -- SFD pulses
  signal tx_sfd, rx_sfd : std_logic;

  -- timestamping
  signal txts_sec, rxts_sec : std_logic_vector(SEC_W-1 downto 0);
  signal txts_ns,  rxts_ns  : std_logic_vector(NS_W-1 downto 0);
  signal txts_valid, rxts_valid : std_logic;
  signal txts_ack, rxts_ack : std_logic;

  -- motor TX-PTP
  signal tx_send : std_logic;
  signal tx_sel  : msg_sel_t;
  signal tx_busy, tx_done : std_logic;
  signal tx_req_rx_sec : std_logic_vector(SEC_W-1 downto 0);
  signal tx_req_rx_ns  : std_logic_vector(NS_W-1 downto 0);
  signal tx_req_portid : std_logic_vector(79 downto 0);
  -- arbitraje: send_sync (maestro) vs orquestador pdelay
  signal orch_send : std_logic;
  signal orch_sel  : msg_sel_t;

  -- FIFO de trama TX
  signal f_wr, f_full, f_rd, f_empty : std_logic;
  signal f_din, f_dout : std_logic_vector(8 downto 0);
  signal frame_ready : std_logic := '0';
  signal tx_pending  : std_logic;
  signal tx_inflight : std_logic := '0';
  signal sync_pend   : std_logic := '0';   -- CMD.send_sync en cola (no descartar)

  -- override
  signal ovr_en : std_logic;
  signal ovr_off : std_logic_vector(10 downto 0);
  signal ovr_len : std_logic_vector(3 downto 0);
  signal ovr_data : std_logic_vector(79 downto 0);

  -- MAC streams
  signal mac_txd  : std_logic_vector(7 downto 0);
  signal mac_tvalid, mac_tlast, mac_tready, mac_tbusy, mac_underrun : std_logic;
  signal mac_rxd  : std_logic_vector(7 downto 0);
  signal mac_rvalid, mac_rlast : std_logic;
  signal mac_ev_ok, mac_ev_crc, mac_ev_runt, mac_ev_drop : std_logic;

  -- parser RX-PTP
  signal rx_mvalid : std_logic;
  signal rx_mtype  : std_logic_vector(3 downto 0);
  signal rx_seqid  : std_logic_vector(15 downto 0);
  signal rx_spid   : std_logic_vector(79 downto 0);
  signal rx_corr   : std_logic_vector(63 downto 0);
  signal rx_osec   : std_logic_vector(SEC_W-1 downto 0);
  signal rx_ons    : std_logic_vector(NS_W-1 downto 0);
  signal rx_rsec   : std_logic_vector(SEC_W-1 downto 0);
  signal rx_rns    : std_logic_vector(NS_W-1 downto 0);
  signal rx_mack   : std_logic;
  signal rx_mack_orch, rx_mack_sync : std_logic;

  -- orquestador -> meanPathDelay
  signal pd_calc : std_logic;
  signal pd_t1_sec, pd_t4_sec : std_logic_vector(SEC_W-1 downto 0);
  signal pd_t1_ns, pd_t4_ns : std_logic_vector(NS_W-1 downto 0);
  signal pd_corr : std_logic_vector(63 downto 0);
  signal mpd_val_i : std_logic;
  signal mpd_i : std_logic_vector(63 downto 0);
  signal mpd_reg : std_logic_vector(63 downto 0) := (others => '0');

  -- lazo esclavo Sync
  signal orch_busy : std_logic;
  signal dbg_tx_st     : std_logic_vector(2 downto 0);
  signal dbg_orch_ist  : std_logic_vector(2 downto 0);
  signal dbg_orch_rstt : std_logic_vector(1 downto 0);
begin
  dbg_state <= (31 downto 14 => '0') & orch_busy & orch_send & tx_busy & mac_tbusy & frame_ready & tx_inflight & dbg_orch_ist & dbg_orch_rstt & dbg_tx_st;

  now_sec <= clk_sec;
  now_ns  <= clk_ns;
  mpd_ns  <= mpd_reg;
  offset_ns <= offset_err;
  dbg_rx_mvalid <= rx_mvalid;
  dbg_rx_mtype  <= rx_mtype;
  dbg_rx_seqid  <= rx_seqid;
  dbg_t1_ns     <= pd_t1_ns;
  dbg_t4_ns     <= pd_t4_ns;
  dbg_pd_corr   <= pd_corr;
  dbg_pd_calc   <= pd_calc;

  -- ---- reloj + servo ----
  u_clk : entity work.ptp_clock
    generic map (SHIFT_P => SHIFT_P, SHIFT_I => SHIFT_I)
    port map (clk => clk, rst => rst, role_slave => role_slave, clr_servo => '0',
              kp => kp, ki => ki, offset_err => offset_err, offset_valid => offset_valid,
              now_sec => clk_sec, now_ns => clk_ns,
              rate_adj_o => rate_adj, offset_applied_o => open);

  -- ---- timestamping TX y RX ----
  u_txts : entity work.ptp_tstamp
    port map (clk => clk, rst => rst, now_sec => clk_sec, now_ns => clk_ns,
              lat_ns => tx_lat, sfd_pulse => tx_sfd, rd_ack => txts_ack,
              ts_sec => txts_sec, ts_ns => txts_ns, ts_valid => txts_valid, ts_overrun => open);

  u_rxts : entity work.ptp_tstamp
    port map (clk => clk, rst => rst, now_sec => clk_sec, now_ns => clk_ns,
              lat_ns => rx_lat, sfd_pulse => rx_sfd, rd_ack => rxts_ack,
              ts_sec => rxts_sec, ts_ns => rxts_ns, ts_valid => rxts_valid, ts_overrun => open);

  -- ---- arbitraje del motor TX: orquestador pdelay o send_sync (maestro) ----
  -- send_sync solo emite Sync cuando el orquestador no esta enviando.
  -- SERIALIZACION: el motor no arranca una trama nueva hasta que la anterior
  -- se ha transmitido POR COMPLETO (FIFO vacia + MAC libre). Sin esto, el motor
  -- resetearia ovr_dat_r al arrancar la siguiente trama mientras el MAC aun
  -- transmite la actual y aun no ha leido su ventana de override (byte del
  -- correctionField del Pdelay_Resp) -> residence=0.
  -- send_sync se ENCOLA (sync_pend) y se lanza cuando el motor queda libre;
  -- antes, un pulso de CMD durante una trama en vuelo se descartaba en silencio.
  tx_pending <= orch_send or (sync_pend and not tx_busy and not tx_inflight);
  tx_send <= tx_pending;
  tx_sel  <= orch_sel  when orch_send = '1' else SEL_SYNC;

  -- tx_inflight: se arma cuando el motor arranca una trama; se libera cuando la
  -- trama se ha ido por completo (gate frame_ready bajo, FIFO vacia, MAC libre,
  -- sostenido un ciclo para robustez, no por flanco).
  serialize : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        tx_inflight <= '0';
        sync_pend   <= '0';
      else
        -- liberar la cola cuando el Sync efectivamente se lanza este ciclo
        if sync_pend = '1' and orch_send = '0'
           and tx_busy = '0' and tx_inflight = '0' then
          sync_pend <= '0';
        end if;
        -- encolar CMD.send_sync (gana sobre la liberacion si coinciden)
        if send_sync = '1' then
          sync_pend <= '1';
        end if;
        if tx_send = '1' then
          tx_inflight <= '1';
        elsif tx_inflight = '1' and frame_ready = '0'
              and f_empty = '1' and mac_tbusy = '0' and tx_busy = '0' then
          tx_inflight <= '0';
        end if;
      end if;
    end if;
  end process;

  -- ---- motor TX-PTP ----
  u_tx : entity work.ptp_tx
    port map (clk => clk, rst => rst, send => tx_send, sel => tx_sel,
              busy => tx_busy, done => tx_done,
              clock_id => clock_id, port_num => port_num, src_mac => src_mac,
              req_rx_sec => tx_req_rx_sec, req_rx_ns => tx_req_rx_ns, req_portid => tx_req_portid,
              ts_sec => txts_sec, ts_ns => txts_ns, ts_valid => txts_valid, ts_ack => txts_ack,
              fifo_wr => f_wr, fifo_din => f_din, fifo_full => f_full,
              ovr_en => ovr_en, ovr_off => ovr_off, ovr_len => ovr_len, ovr_data => ovr_data, dbg_st => dbg_tx_st);

  -- ---- FIFO de trama + gate store-and-forward ----
  u_fifo : entity work.spw_fifo
    generic map (LOG2_DEPTH => 11, WIDTH => 9)
    port map (clk => clk, aresetn => not rst, clr => '0',
              wr_en => f_wr, wdata => f_din, full => f_full,
              rdata => f_dout, rd_en => f_rd, empty => f_empty, level => open);

  sf_gate : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then frame_ready <= '0';
      else
        if f_wr = '1' and f_din(8) = '1' then frame_ready <= '1'; end if;
        if frame_ready = '1' and f_empty = '1' and mac_tbusy = '0' then frame_ready <= '0'; end if;
      end if;
    end if;
  end process;

  mac_tvalid <= (not f_empty) and frame_ready;
  mac_txd    <= f_dout(7 downto 0);
  mac_tlast  <= f_dout(8);
  f_rd       <= mac_tready and (not f_empty) and frame_ready;

  -- ---- eth_mac con ganchos PTP ----
  u_mac : entity work.eth_mac
    port map (clk => clk, rst => rst, loopback => loopback,
              macaddr => macaddr, promisc => '0',
              tx_data => mac_txd, tx_valid => mac_tvalid, tx_last => mac_tlast,
              tx_ready => mac_tready, tx_busy => mac_tbusy, tx_underrun => mac_underrun,
              rx_data => mac_rxd, rx_valid => mac_rvalid, rx_last => mac_rlast,
              rx_ev_ok => mac_ev_ok, rx_ev_crc => mac_ev_crc,
              rx_ev_runt => mac_ev_runt, rx_ev_drop => mac_ev_drop,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv,
              tx_sfd_pulse => tx_sfd, rx_sfd_pulse => rx_sfd,
              ovr_en => ovr_en, ovr_off => ovr_off, ovr_len => ovr_len, ovr_data => ovr_data);

  -- ---- parser RX-PTP ----
  rx_mack <= rx_mack_orch or rx_mack_sync;
  u_rx : entity work.ptp_rx
    port map (clk => clk, rst => rst,
              rx_data => mac_rxd, rx_valid => mac_rvalid, rx_last => mac_rlast, ev_ok => mac_ev_ok,
              rx_ts_sec => rxts_sec, rx_ts_ns => rxts_ns, rx_ts_valid => rxts_valid, rx_ts_ack => rxts_ack,
              msg_valid => rx_mvalid, msg_type => rx_mtype, seq_id => rx_seqid,
              src_port_id => rx_spid, origin_sec => rx_osec, origin_ns => rx_ons,
              corr_field => rx_corr, rx_sec => rx_rsec, rx_ns => rx_rns, rd_ack => rx_mack);

  -- ---- orquestador peer-delay ----
  u_orch : entity work.ptp_pdelay_fsm
    port map (clk => clk, rst => rst, start => start_pdelay, busy => orch_busy,
              rx_mvalid => rx_mvalid, rx_mtype => rx_mtype, rx_seqid => rx_seqid,
              rx_spid => rx_spid, rx_corr => rx_corr, rx_sec => rx_rsec, rx_ns => rx_rns,
              rx_ack => rx_mack_orch,
              tx_send => orch_send, tx_sel => orch_sel,
              tx_req_rx_sec => tx_req_rx_sec, tx_req_rx_ns => tx_req_rx_ns, tx_req_portid => tx_req_portid,
              tx_busy => tx_busy, tx_done => tx_done, tx_ready => not tx_inflight,
              tx_ts_sec => txts_sec, tx_ts_ns => txts_ns, tx_ts_valid => txts_valid,
              pd_calc => pd_calc, pd_t1_sec => pd_t1_sec, pd_t1_ns => pd_t1_ns,
              pd_t4_sec => pd_t4_sec, pd_t4_ns => pd_t4_ns, pd_corr => pd_corr, dbg_ist => dbg_orch_ist, dbg_rstt => dbg_orch_rstt);

  -- ---- calculo meanPathDelay ----
  u_pd : entity work.ptp_pdelay
    port map (clk => clk, rst => rst, calc => pd_calc,
              t1_sec => pd_t1_sec, t1_ns => pd_t1_ns, t4_sec => pd_t4_sec, t4_ns => pd_t4_ns,
              corr_field => pd_corr, delay_ns => mpd_i, valid => mpd_val_i);

  -- registrar el ultimo meanPathDelay
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then mpd_reg <= (others => '0');
      elsif mpd_val_i = '1' then mpd_reg <= mpd_i; end if;
    end if;
  end process;
  mpd_valid <= mpd_val_i;

  -- eventos de un ciclo para el banco de registros: pulso en el flanco de
  -- rx_mvalid segun el tipo de mensaje, y el offset_valid del lazo esclavo.
  offset_valid_o <= offset_valid;
  ev_proc : process(clk)
    variable mv_d : std_logic := '0';
  begin
    if rising_edge(clk) then
      rx_sync_ev <= '0';
      rx_resp_ev <= '0';
      if rst = '1' then
        mv_d := '0';
      else
        if rx_mvalid = '1' and mv_d = '0' then   -- flanco de subida
          if rx_mtype = MT_SYNC then rx_sync_ev <= '1'; end if;
          if rx_mtype = MT_PDELAY_RESP then rx_resp_ev <= '1'; end if;
        end if;
        mv_d := rx_mvalid;
      end if;
    end if;
  end process;

  -- ---- lazo esclavo Sync: RX Sync -> offset -> servo ----
  -- offset = t_slave_rx - t_master_origin - meanPathDelay.
  -- Cuando el parser entrega un Sync y somos esclavos, calculamos el offset y
  -- pulsamos offset_valid al reloj. Consumimos el mensaje (rx_mack_sync).
  sync_loop : process(clk)
    variable slave_ns  : signed(63 downto 0);
    variable master_ns : signed(63 downto 0);
    variable off       : signed(63 downto 0);
  begin
    if rising_edge(clk) then
      offset_valid <= '0';
      rx_mack_sync <= '0';
      if rst = '1' then
        offset_err <= (others => '0');
      else
        if rx_mvalid = '1' and rx_mtype = MT_SYNC and role_slave = '1' then
          -- t_slave_rx (rx TS) y t_master_origin (originTimestamp del Sync)
          slave_ns  := resize(signed('0' & rx_rsec) * to_signed(1_000_000_000, 34), 64)
                       + resize(signed('0' & rx_rns), 64);
          master_ns := resize(signed('0' & rx_osec) * to_signed(1_000_000_000, 34), 64)
                       + resize(signed('0' & rx_ons), 64);
          off := slave_ns - master_ns - signed(mpd_reg);
          offset_err <= std_logic_vector(resize(off, ERR_W));
          offset_valid <= '1';
          rx_mack_sync <= '1';
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
