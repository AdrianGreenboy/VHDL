-- ptp_regs.vhd — banco de registros MMIO (IP PTP / IEEE 802.1AS v1)
-- ---------------------------------------------------------------------------
-- Interfaz AXI-Lite-like simplificada (sel/we/addr/wdata/rdata) hacia el SoC
-- RV32IM. Sigue el patron MMIO de la familia (8 IPs previos):
--   - rdata COMBINACIONAL (un rdata registrado pasa L2 pero falla L4).
--   - stickies de STATUS limpiados por escritura-1, con set-del-mismo-ciclo
--     ganando (si el evento y la limpieza coinciden, el sticky queda a 1).
--   - IRQ por NIVEL: irq = OR(STATUS and IRQEN).
--   - snapshot ATOMICO del reloj: leer NOW_SEC congela NOW_NS (y MPD_HI
--     congela MPD_LO) para evitar desgarro sec/ns en el cruce de segundo.
--
-- Mapa (offset de palabra, 32b):
--   0x00 CONTROL   [0]=role_slave [1]=loopback [2]=enable          (rw)
--   0x04 SERVO_K   [31:16]=KP [15:0]=KI                            (rw)
--   0x08 LAT       [31:16]=tx_lat [15:0]=rx_lat                    (rw)
--   0x0C CMD       [0]=send_sync [1]=start_pdelay (auto-clear)     (w, disparo)
--   0x10 CLKID_HI  clockIdentity[63:32]                            (rw)
--   0x14 CLKID_LO  clockIdentity[31:0]                             (rw)
--   0x18 PORTNUM   [15:0]=portNumber                               (rw)
--   0x1C SMAC_HI   src_mac[47:32]                                  (rw)
--   0x20 SMAC_LO   src_mac[31:0]                                   (rw)
--   0x24 STATUS    [0]=rx_sync [1]=rx_resp [2]=mpd_valid [3]=off_v (r, W1C)
--                  audit 2026-11 (all W1C per bit, set wins):
--                  [4]=pd_timeout [5]=tx_ts_timeout [6]=resp_lost
--                  [7]=resp_mismatch [8]=not_as_capable (lost > allowed)
--                  [9]=rx_oversize [10]=phy_cdc_err
--   0x28 NOW_SEC   segundos [31:0] (lectura congela NOW_NS y NOW_SECHI) (r)
--   0x2C NOW_NS    nanosegundos (congelado por lectura de NOW_SEC) (r)
--   0x30 MPD_LO    meanPathDelay[31:0] (lectura congela MPD_HI)    (r)
--   0x34 MPD_HI    meanPathDelay[63:32]                            (r)
--   0x38 OFFSET    ultimo offset medido (signed ns)                (r)
--   0x3C RATE_ADJ  rate_adj actual del servo                       (r)
--   0x40 IRQEN     mascara de interrupcion (bit-a-bit con STATUS)  (rw)
--   0x44..0x58     debug probes (r)
--   0x5C NOW_SECHI segundos [47:32] (congelado por lectura de NOW_SEC) (r)
--   0x60 TMO       timeout de toda espera PTP en ciclos de core; 0 = sin
--                  timeout (v1). Reset: 0x0010_0000 (~10.5 ms @100 MHz) (rw)
--   0x64 PD_CFG    [7:0] allowedLostResponses (reset 3)
--                  [8] =1 disables the Resp seq/portIdentity check (debug) (rw)
--   0x68 PD_STAT   [7:0] lostResponses [8] asCapable (live)          (r)
-- CONTROL[2] enable: '0' holds the port datapath in reset (clock keeps running).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity ptp_regs is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                    -- sincrono activo-alto
    -- interfaz MMIO
    sel        : in  std_logic;
    we         : in  std_logic;
    addr       : in  std_logic_vector(5 downto 0); -- offset de palabra (0..0x40)
    wdata      : in  std_logic_vector(31 downto 0);
    rdata      : out std_logic_vector(31 downto 0); -- COMBINACIONAL
    irq        : out std_logic;
    -- control hacia el datapath
    role_slave : out std_logic;
    loopback   : out std_logic;
    enable     : out std_logic;
    kp         : out std_logic_vector(15 downto 0);
    ki         : out std_logic_vector(15 downto 0);
    tx_lat     : out std_logic_vector(15 downto 0);
    rx_lat     : out std_logic_vector(15 downto 0);
    clock_id   : out std_logic_vector(63 downto 0);
    port_num   : out std_logic_vector(15 downto 0);
    src_mac    : out std_logic_vector(47 downto 0);
    send_sync    : out std_logic;                  -- pulso
    start_pdelay : out std_logic;                  -- pulso
    tmo_cycles   : out unsigned(31 downto 0);
    allowed_lost : out unsigned(7 downto 0);
    chk_resp     : out std_logic;
    -- estado desde el datapath
    now_sec    : in  std_logic_vector(SEC_W-1 downto 0);
    now_ns     : in  std_logic_vector(NS_W-1 downto 0);
    mpd_ns     : in  std_logic_vector(63 downto 0);
    mpd_valid  : in  std_logic;                    -- pulso: nuevo mpd
    offset_ns  : in  std_logic_vector(ERR_W-1 downto 0);
    offset_valid : in std_logic;                   -- pulso: offset procesado
    rate_adj   : in  std_logic_vector(RATE_W-1 downto 0);
    rx_sync_ev : in  std_logic;                    -- pulso: Sync recibido
    rx_resp_ev : in  std_logic;                    -- pulso: Pdelay_Resp recibido
    -- audit 2026-11 events (pulses) and live state
    ev_pd_timeout    : in std_logic := '0';
    ev_ts_timeout    : in std_logic := '0';
    ev_resp_lost     : in std_logic := '0';
    ev_resp_mismatch : in std_logic := '0';
    ev_rx_oversize   : in std_logic := '0';
    ev_phy_err       : in std_logic := '0';
    pd_lost_cnt      : in unsigned(7 downto 0) := (others => '0');
    pd_as_capable    : in std_logic := '1';
    dbg_state  : in  std_logic_vector(31 downto 0);
    dbg_rxdst  : in  std_logic_vector(47 downto 0);
    dbg_rxinfo : in  std_logic_vector(31 downto 0);
    dbg_fptr   : in  std_logic_vector(31 downto 0);
    dbg_ftx    : in  std_logic_vector(31 downto 0)
  );
end entity ptp_regs;

architecture rtl of ptp_regs is
  -- registros de control
  signal ctrl_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal servo_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal lat_r    : std_logic_vector(31 downto 0) := (others => '0');
  signal clkid_r  : std_logic_vector(63 downto 0) := (others => '0');
  signal port_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal smac_hi_r: std_logic_vector(31 downto 0) := (others => '0');
  signal smac_lo_r: std_logic_vector(31 downto 0) := (others => '0');
  signal irqen_r  : std_logic_vector(31 downto 0) := (others => '0');

  -- comandos (pulsos)
  signal send_sync_r, start_pdelay_r : std_logic := '0';

  -- STATUS stickies (W1C per bit): see map above
  constant NSTAT  : integer := 11;
  signal status_r : std_logic_vector(NSTAT-1 downto 0) := (others => '0');
  signal tmo_r    : std_logic_vector(31 downto 0) := x"00100000";
  signal pdcfg_r  : std_logic_vector(31 downto 0) := x"00000003";
  signal sechi_snap : std_logic_vector(15 downto 0) := (others => '0');
  signal nac_d    : std_logic := '1';

  -- snapshots atomicos
  signal ns_snap  : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal mpdhi_snap : std_logic_vector(31 downto 0) := (others => '0');

  -- direcciones (offset de palabra)
  constant A_CTRL   : std_logic_vector(5 downto 0) := "000000"; -- 0x00
  constant A_SERVO  : std_logic_vector(5 downto 0) := "000001"; -- 0x04
  constant A_LAT    : std_logic_vector(5 downto 0) := "000010"; -- 0x08
  constant A_CMD    : std_logic_vector(5 downto 0) := "000011"; -- 0x0C
  constant A_CLKIDH : std_logic_vector(5 downto 0) := "000100"; -- 0x10
  constant A_CLKIDL : std_logic_vector(5 downto 0) := "000101"; -- 0x14
  constant A_PORT   : std_logic_vector(5 downto 0) := "000110"; -- 0x18
  constant A_SMACH  : std_logic_vector(5 downto 0) := "000111"; -- 0x1C
  constant A_SMACL  : std_logic_vector(5 downto 0) := "001000"; -- 0x20
  constant A_STATUS : std_logic_vector(5 downto 0) := "001001"; -- 0x24
  constant A_NOWSEC : std_logic_vector(5 downto 0) := "001010"; -- 0x28
  constant A_NOWNS  : std_logic_vector(5 downto 0) := "001011"; -- 0x2C
  constant A_MPDLO  : std_logic_vector(5 downto 0) := "001100"; -- 0x30
  constant A_MPDHI  : std_logic_vector(5 downto 0) := "001101"; -- 0x34
  constant A_OFFSET : std_logic_vector(5 downto 0) := "001110"; -- 0x38
  constant A_RATE   : std_logic_vector(5 downto 0) := "001111"; -- 0x3C
  constant A_IRQEN  : std_logic_vector(5 downto 0) := "010000"; -- 0x40
  constant A_DBGST  : std_logic_vector(5 downto 0) := "010001"; -- 0x44
  constant A_DBGD0  : std_logic_vector(5 downto 0) := "010010"; -- 0x48 dst[31:0]
  constant A_DBGD1  : std_logic_vector(5 downto 0) := "010011"; -- 0x4C dst[47:32]
  constant A_DBGD2  : std_logic_vector(5 downto 0) := "010100"; -- 0x50 nivel FIFO | len drop
  constant A_DBGD3  : std_logic_vector(5 downto 0) := "010101"; -- 0x54 wptr | rptr
  constant A_DBGD4  : std_logic_vector(5 downto 0) := "010110"; -- 0x58 1er byte a FIFO
  constant A_SECHI  : std_logic_vector(5 downto 0) := "010111"; -- 0x5C
  constant A_TMO    : std_logic_vector(5 downto 0) := "011000"; -- 0x60
  constant A_PDCFG  : std_logic_vector(5 downto 0) := "011001"; -- 0x64
  constant A_PDSTAT : std_logic_vector(5 downto 0) := "011010"; -- 0x68
begin

  -- salidas de control
  role_slave <= ctrl_r(0);
  loopback   <= ctrl_r(1);
  enable     <= ctrl_r(2);
  kp         <= servo_r(31 downto 16);
  ki         <= servo_r(15 downto 0);
  tx_lat     <= lat_r(31 downto 16);
  rx_lat     <= lat_r(15 downto 0);
  clock_id   <= clkid_r;
  port_num   <= port_r(15 downto 0);
  src_mac    <= smac_hi_r(15 downto 0) & smac_lo_r;
  send_sync    <= send_sync_r;
  start_pdelay <= start_pdelay_r;
  tmo_cycles   <= unsigned(tmo_r);
  allowed_lost <= unsigned(pdcfg_r(7 downto 0));
  chk_resp     <= not pdcfg_r(8);

  -- IRQ por nivel: OR de STATUS enmascarado por IRQEN
  irq <= '1' when (status_r and irqen_r(NSTAT-1 downto 0)) /= (status_r'range => '0') else '0';

  -- ---- rdata COMBINACIONAL ----
  process(all)
  begin
    rdata <= (others => '0');
    if sel = '1' then
      case addr is
        when A_CTRL   => rdata <= ctrl_r;
        when A_SERVO  => rdata <= servo_r;
        when A_LAT    => rdata <= lat_r;
        when A_CLKIDH => rdata <= clkid_r(63 downto 32);
        when A_CLKIDL => rdata <= clkid_r(31 downto 0);
        when A_PORT   => rdata <= port_r;
        when A_SMACH  => rdata <= smac_hi_r;
        when A_SMACL  => rdata <= smac_lo_r;
        when A_STATUS => rdata <= (31 downto NSTAT => '0') & status_r;
        when A_NOWSEC => rdata <= now_sec(31 downto 0);   -- 32b bajos del sec
        when A_NOWNS  => rdata <= ns_snap;                -- congelado
        when A_MPDLO  => rdata <= mpd_ns(31 downto 0);
        when A_MPDHI  => rdata <= mpdhi_snap;             -- congelado
        when A_OFFSET => rdata <= offset_ns;
        when A_RATE   => rdata <= rate_adj;
        when A_IRQEN  => rdata <= irqen_r;
        when A_DBGST  => rdata <= dbg_state;
        when A_DBGD0  => rdata <= dbg_rxdst(31 downto 0);
        when A_DBGD1  => rdata <= x"A5D" & "0000" & dbg_rxdst(47 downto 32);  -- tag: sonda presente
        when A_DBGD2  => rdata <= dbg_rxinfo;
        when A_DBGD3  => rdata <= dbg_fptr;
        when A_DBGD4  => rdata <= dbg_ftx;
        when A_SECHI  => rdata <= x"0000" & sechi_snap;   -- congelado
        when A_TMO    => rdata <= tmo_r;
        when A_PDCFG  => rdata <= pdcfg_r;
        when A_PDSTAT => rdata <= (31 downto 9 => '0') & pd_as_capable
                                  & std_logic_vector(pd_lost_cnt);
        when others   => rdata <= (others => '0');
      end case;
    end if;
  end process;

  -- ---- escritura + stickies + snapshots ----
  process(clk)
    variable set_v : std_logic_vector(NSTAT-1 downto 0);
    variable clr_v : std_logic_vector(NSTAT-1 downto 0);
  begin
    if rising_edge(clk) then
      -- pulsos de comando: default 0 (auto-clear)
      send_sync_r    <= '0';
      start_pdelay_r <= '0';

      if rst = '1' then
        ctrl_r <= (others => '0'); servo_r <= (others => '0');
        lat_r <= (others => '0'); clkid_r <= (others => '0');
        port_r <= (others => '0'); smac_hi_r <= (others => '0');
        smac_lo_r <= (others => '0'); irqen_r <= (others => '0');
        status_r <= (others => '0');
        ns_snap <= (others => '0'); mpdhi_snap <= (others => '0');
        sechi_snap <= (others => '0');
        tmo_r <= x"00100000"; pdcfg_r <= x"00000003";
        nac_d <= '1';
      else
        -- eventos que ARMAN stickies este ciclo
        nac_d <= pd_as_capable;
        set_v := (0 => rx_sync_ev, 1 => rx_resp_ev,
                  2 => mpd_valid,  3 => offset_valid,
                  4 => ev_pd_timeout, 5 => ev_ts_timeout,
                  6 => ev_resp_lost, 7 => ev_resp_mismatch,
                  8 => nac_d and not pd_as_capable,     -- asCapable 1->0 edge
                  9 => ev_rx_oversize, 10 => ev_phy_err);
        clr_v := (others => '0');

        -- escrituras
        if sel = '1' and we = '1' then
          case addr is
            when A_CTRL   => ctrl_r  <= wdata;
            when A_SERVO  => servo_r <= wdata;
            when A_LAT    => lat_r   <= wdata;
            when A_CMD    =>
              send_sync_r    <= wdata(0);
              start_pdelay_r <= wdata(1);
            when A_CLKIDH => clkid_r(63 downto 32) <= wdata;
            when A_CLKIDL => clkid_r(31 downto 0)  <= wdata;
            when A_PORT   => port_r  <= wdata;
            when A_SMACH  => smac_hi_r <= wdata;
            when A_SMACL  => smac_lo_r <= wdata;
            when A_STATUS => clr_v := wdata(NSTAT-1 downto 0);   -- W1C per bit
            when A_TMO    => tmo_r   <= wdata;
            when A_PDCFG  => pdcfg_r <= wdata;
            when A_IRQEN  => irqen_r <= wdata;
            when others   => null;
          end case;
        end if;

        -- snapshot atomico: leer NOW_SEC congela ns; leer MPD_LO congela hi
        if sel = '1' and we = '0' then
          if addr = A_NOWSEC then
            ns_snap    <= now_ns;
            sechi_snap <= now_sec(47 downto 32);
          end if;
          if addr = A_MPDLO  then mpdhi_snap <= mpd_ns(63 downto 32); end if;
        end if;

        -- actualizar stickies: set gana sobre clear en el mismo ciclo
        for i in 0 to NSTAT-1 loop
          if set_v(i) = '1' then
            status_r(i) <= '1';
          elsif clr_v(i) = '1' then
            status_r(i) <= '0';
          end if;
        end loop;
      end if;
    end if;
  end process;

end architecture rtl;
