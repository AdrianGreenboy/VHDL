-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Datapath de silicio (dominio clk_dp, 390.625 MHz: una ranura de bloque de
-- 66 bits por ciclo; con el gearbox de fabric 66->64 del banco de loopback
-- eso equivale a 25.0 Gb/s serie, ver README seccion 3):
--
--   mac25g_gen -> TX frame FIFO (store-and-forward) -> mac25g_pause_tx
--      -> mac25g_tx -> FIFO de bloques -> mac25g_pcs_tx
--      -> loopback paralelo registrado
--   pcs_rx_datapath (Core 19) -> mac25g_rx -> RX frame FIFO -> mac25g_chk
--                                         \-> mac25g_pause_rx
--
-- Audit 2026-11:
--   * TX frame FIFO (mac25g_axis_fifo, 2**TXQ_AW words) in front of the MAC:
--     tvalid bubbles of an AXIS master are legal (fix M3)
--   * IEEE 802.3x PAUSE (product gap): received PAUSE frames stop new data
--     frames for pause_time x 512 bit times (pause_honor); the RX FIFO
--     level drives XOFF / XON PAUSE frames with hysteresis (pause_auto,
--     rx_hi_wm / rx_lo_wm); pause_sw_req sends one PAUSE frame. The RX FIFO
--     is drained with rx_tready (back-pressure from the consumer), MAC
--     control frames are consumed, frames that do not fit are dropped.
--   * 32-bit counters saturate at 0xFFFFFFFF instead of wrapping (fix B3)
--   * the block FIFO write is guarded (never overwrites; sticky + assert)
--
-- Control de flujo TX: el PCS acepta 32 bloques cada 33 ciclos (gearbox
-- 64/66). En vez de propagar su in_ready combinacional por todo el MAC, el
-- MAC avanza con un 'ce' registrado que vale 1 mientras la FIFO tiene <= 4
-- bloques. El MAC emite siempre (idles sin trafico, como necesita un PMA
-- real); MAC_EN solo deja pasar tramas del generador. La FIFO (8 + 1 registro de salida) absorbe el desfase; la salida
-- hacia el scrambler es un REGISTRO (el Core 19 cerro a WNS 0.000 ns: no se
-- anade logica delante de su scrambler).
--
-- Contadores de 32 bits (indice -> registro, ver doc/register_map.md):
--   0 TX_FRAMES   1 TX_BYTES    2 RX_OK      3 RX_BYTES   4 RX_CRC_ERR
--   5 RX_RUNT     6 RX_OVERSIZE 7 RX_ABORT   8 RX_FILTERED 9 RX_PROTO
--  10 CHK_OK     11 CHK_BAD    12 CHK_SEQ_ERR 13 CHK_RXERR
--  14 BURST_CYCLES (ciclos con el generador activo o tramas en la TX FIFO)
--  15 TX_UNDERRUN
-- cnt2_flat (audit 2026-11):
--   0 RX_PAUSE (PAUSE frames received and honoured)  1 TX_PAUSE (sent)
--   2 RX_CTRL (MAC control frames consumed)  3 RX_FIFO_DROP (no room)
--   4 TX_KEEP_ERR (malformed tkeep)  5 BLK_FIFO_OVF  6 PAUSED_SLOTS
--   7 RX_FIFO_MAX (high-water mark of the RX FIFO level, in words)
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;

entity mac25g_datapath is
  generic (
    -- false: PCS de 66 bits sin gearbox (interfaz de un GT con gearbox
    --        interno; 1 bloque/ciclo = 25.78125 Gb/s a 390.625 MHz)
    -- true : gearboxes de fabric 66<->64 del Core 19 (loopback de 64 bits,
    --        32 bloques cada 33 ciclos = 25.0 Gb/s)
    GEARBOX : boolean := false;
    TXQ_AW  : positive := 9;          -- TX frame FIFO 512 x 8 bytes
    RXQ_AW  : positive := 10          -- RX frame FIFO 1024 x 8 bytes
  );
  port (
    clk_dp    : in  std_logic;
    rst_dp    : in  std_logic;

    -- configuracion (estable mientras corre)
    mac_en    : in  std_logic;
    loopback  : in  std_logic;
    promisc   : in  std_logic;
    gen_cont  : in  std_logic;
    own_mac   : in  std_logic_vector(47 downto 0);
    src_mac   : in  std_logic_vector(47 downto 0);
    len_min   : in  unsigned(10 downto 0);
    len_max   : in  unsigned(10 downto 0);
    len_step  : in  unsigned(10 downto 0);
    gen_count : in  unsigned(31 downto 0);

    -- comandos (pulsos de 1 ciclo en clk_dp)
    gen_start : in  std_logic;
    gen_stop  : in  std_logic;
    cnt_clear : in  std_logic;
    inj       : in  std_logic;

    -- estado
    st_link   : out std_logic;
    st_busy   : out std_logic;
    st_done   : out std_logic;
    st_rx_act : out std_logic;
    st_tx_act : out std_logic;

    -- eventos (pulsos)
    ev_done   : out std_logic;
    ev_crc    : out std_logic;
    ev_chkerr : out std_logic;
    ev_lnk_lo : out std_logic;

    -- contadores vivos
    cnt_flat  : out std_logic_vector(16*32-1 downto 0);

    -- IEEE 802.3x flow control (audit 2026-11); defaults = disabled
    pause_honor     : in  std_logic := '0';
    pause_auto      : in  std_logic := '0';
    pause_quanta    : in  std_logic_vector(15 downto 0) := x"FFFF";
    rx_hi_wm        : in  unsigned(15 downto 0) := to_unsigned(384, 16);
    rx_lo_wm        : in  unsigned(15 downto 0) := to_unsigned(128, 16);
    pause_sw_req    : in  std_logic := '0';
    pause_sw_quanta : in  std_logic_vector(15 downto 0) := x"0000";
    rx_tready       : in  std_logic := '1';   -- consumer back-pressure
    st_paused       : out std_logic;
    st_xoff         : out std_logic;
    cnt2_flat       : out std_logic_vector(8*32-1 downto 0)
  );
end entity mac25g_datapath;

architecture rtl of mac25g_datapath is
  -- generador
  signal g_tdata  : std_logic_vector(63 downto 0);
  signal g_tkeep  : std_logic_vector(7 downto 0);
  signal g_tlast, g_tvalid, g_tready, g_busy, g_done : std_logic;
  -- TX MAC
  signal ce       : std_logic := '0';
  signal s_tvalid, s_tready : std_logic;
  -- register slice AXIS (2 entradas) entre generador y MAC: el tready del MAC
  -- no atraviesa el generador
  signal rs_v, rs_sv : std_logic := '0';
  signal rs_d, rs_sd : std_logic_vector(72 downto 0) := (others => '0');
  signal rs_ready, rs_take : std_logic;
  signal clr_r : std_logic := '1';
  -- eventos registrados un ciclo antes de los contadores (corta el camino
  -- evento -> suma de 32 bits); los incrementos dobles ya precalculados
  signal q_txf, q_rxok, q_crc, q_over, q_filt, q_proto : std_logic := '0';
  signal q_cok, q_cbad, q_cseq, q_crxe, q_busy, q_und : std_logic := '0';
  signal q_txb, q_rxb : unsigned(15 downto 0) := (others => '0');
  signal q_runt, q_abort : unsigned(1 downto 0) := (others => '0');
  attribute MAX_FANOUT : integer;
  attribute MAX_FANOUT of ce : signal is 32;
  attribute MAX_FANOUT of clr_r : signal is 64;
  attribute MAX_FANOUT of rs_take : signal is 32;
  signal b_valid, b_isd : std_logic;
  signal b_pl     : std_logic_vector(63 downto 0);
  signal t_evf, t_evu : std_logic;
  signal t_evb    : unsigned(15 downto 0);
  -- FIFO de bloques
  type fifo_t is array (0 to 7) of std_logic_vector(64 downto 0);
  signal fmem     : fifo_t := (others => (others => '0'));
  signal wptr, rptr : unsigned(2 downto 0) := (others => '0');
  signal flevel   : unsigned(3 downto 0) := (others => '0');
  signal o_v      : std_logic := '0';
  signal o_blk    : std_logic_vector(64 downto 0) := (others => '0');
  -- PCS
  signal pt_ready, pt_ovalid : std_logic;
  signal pt_oword : std_logic_vector(63 downto 0);
  signal loop_word : std_logic_vector(63 downto 0) := (others => '0');
  signal loop_valid : std_logic := '0';
  signal pr_ready, pr_valid, pr_isd : std_logic;
  signal pr_pl    : std_logic_vector(63 downto 0);
  -- RX MAC
  signal r_tdata  : std_logic_vector(63 downto 0);
  signal r_tkeep  : std_logic_vector(7 downto 0);
  signal r_tlast, r_tuser, r_tvalid : std_logic;
  signal e_ok, e_crc, e_runt, e_r0, e_over, e_ab, e_a0, e_filt, e_proto, lnk : std_logic;
  signal e_bytes  : unsigned(15 downto 0);
  -- checker
  signal c_ok, c_bad, c_seq, c_rxe : std_logic;
  -- contadores
  type cnt_t is array (0 to 15) of unsigned(31 downto 0);
  signal cnt      : cnt_t := (others => (others => '0'));
  signal rx_act, tx_act, lnk_d, done_d : std_logic := '0';
  signal p_lnk_lo, p_done : std_logic := '0';
  -- frame FIFOs and flow control
  signal q_s_tvalid, q_s_tready : std_logic;
  signal q_tdata  : std_logic_vector(63 downto 0);
  signal q_tkeep  : std_logic_vector(7 downto 0);
  signal q_tlast, q_tvalid, q_tready : std_logic;
  signal p_tdata  : std_logic_vector(63 downto 0);
  signal p_tkeep  : std_logic_vector(7 downto 0);
  signal p_tlast  : std_logic;
  signal t_evk    : std_logic;
  signal x_ctrl, x_pstb : std_logic;
  signal x_pq     : std_logic_vector(15 downto 0);
  signal f_tdata  : std_logic_vector(63 downto 0);
  signal f_tkeep  : std_logic_vector(7 downto 0);
  signal f_tlast, f_tuser, f_tvalid : std_logic;
  signal f_level  : unsigned(RXQ_AW downto 0);
  signal f_ovf, f_drop : std_logic;
  signal xoff_r   : std_logic := '0';
  signal paused, e_txp, e_rxp : std_logic;
  signal blk_ovf  : std_logic := '0';
  type cnt2_t is array (0 to 7) of unsigned(31 downto 0);
  signal cnt2     : cnt2_t := (others => (others => '0'));
  signal q2_rxp, q2_txp, q2_ctl, q2_ovf, q2_kerr, q2_bovf, q2_paused : std_logic := '0';
  signal blk_ovf_p : std_logic := '0';
  signal q_level  : unsigned(TXQ_AW downto 0);
  signal tx_pend, x_busy, x_done : std_logic;

  -- saturating counter arithmetic (fix B3)
  function sat_add(c : unsigned(31 downto 0); x : unsigned(31 downto 0)) return unsigned is
    variable t : unsigned(32 downto 0);
  begin
    t := ('0' & c) + ('0' & x);
    if t(32) = '1' then return x"FFFFFFFF"; else return t(31 downto 0); end if;
  end function;
begin

  -----------------------------------------------------------------------------
  -- fuente de trafico
  -----------------------------------------------------------------------------
  u_gen: entity work.mac25g_gen
    port map (clk=>clk_dp, rst=>rst_dp, start=>gen_start, stop=>gen_stop,
              cont=>gen_cont, dst=>own_mac, src=>src_mac,
              len_min=>len_min, len_max=>len_max, len_step=>len_step,
              count=>gen_count,
              m_tdata=>g_tdata, m_tkeep=>g_tkeep, m_tlast=>g_tlast,
              m_tvalid=>g_tvalid, m_tready=>g_tready, busy=>g_busy, done=>g_done);

  -----------------------------------------------------------------------------
  -- MAC TX con ce por nivel de FIFO
  -----------------------------------------------------------------------------
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then ce <= '0';
      elsif flevel <= 4 then ce <= '1';
      else ce <= '0';
      end if;
    end if;
  end process;

  -- TX frame FIFO: store-and-forward, a frame is offered to the MAC only
  -- when it is complete (AXIS bubbles of the source are absorbed here)
  u_txq: entity work.mac25g_axis_fifo
    generic map (AW => TXQ_AW, STORE_FW => true, NO_BP => false)
    port map (clk=>clk_dp, rst=>rst_dp,
              s_tdata=>rs_d(63 downto 0), s_tkeep=>rs_d(71 downto 64),
              s_tlast=>rs_d(72), s_tuser=>'0', s_tdrop=>'0',
              s_tvalid=>q_s_tvalid, s_tready=>q_s_tready,
              m_tdata=>q_tdata, m_tkeep=>q_tkeep, m_tlast=>q_tlast, m_tuser=>open,
              m_tvalid=>q_tvalid, m_tready=>q_tready,
              level=>q_level, ev_ovf=>open, ev_drop=>open);

  -- the burst is finished when the generator is done AND the TX FIFO has
  -- handed its last word to the MAC (same meaning as before the FIFO)
  tx_pend <= '1' when q_level /= 0 or q_tvalid = '1' else '0';
  x_busy  <= g_busy or tx_pend;
  x_done  <= g_done and not tx_pend;

  -- PAUSE: honour received pause at frame boundaries, insert PAUSE frames
  u_ptx: entity work.mac25g_pause_tx
    port map (clk=>clk_dp, rst=>rst_dp, ce=>ce, own_mac=>own_mac,
              honor_en=>pause_honor, auto_en=>pause_auto, quanta=>pause_quanta,
              rx_stb=>x_pstb, rx_quanta=>x_pq, xoff=>xoff_r,
              sw_req=>pause_sw_req, sw_quanta=>pause_sw_quanta,
              s_tdata=>q_tdata, s_tkeep=>q_tkeep, s_tlast=>q_tlast,
              s_tvalid=>q_tvalid, s_tready=>q_tready,
              m_tdata=>p_tdata, m_tkeep=>p_tkeep, m_tlast=>p_tlast,
              m_tvalid=>s_tvalid, m_tready=>s_tready,
              paused=>paused, ev_tx_pause=>e_txp, ev_rx_pause=>e_rxp);

  u_tx: entity work.mac25g_tx
    port map (clk=>clk_dp, rst=>rst_dp, ce=>ce,
              s_tdata=>p_tdata, s_tkeep=>p_tkeep, s_tlast=>p_tlast,
              s_tvalid=>s_tvalid, s_tready=>s_tready, inj=>inj,
              blk_valid=>b_valid, blk_payload=>b_pl, blk_is_data=>b_isd,
              ev_frame=>t_evf, ev_bytes=>t_evb, ev_underrun=>t_evu,
              ev_keep_err=>t_evk);

  -- MAC_EN abre el paso de tramas (cuasi-estatico: se captura con CMD)
  q_s_tvalid <= rs_v and mac_en;
  rs_take  <= q_s_tready and mac_en;
  rs_ready <= not rs_sv;                      -- registrado
  g_tready <= rs_ready;

  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then
        rs_v <= '0'; rs_sv <= '0';
      elsif rs_take = '1' or rs_v = '0' then
        -- la salida se vacia (o esta vacia): cargar desde skid o entrada
        if rs_sv = '1' then
          rs_d <= rs_sd; rs_v <= '1'; rs_sv <= '0';
        else
          rs_d <= g_tlast & g_tkeep & g_tdata; rs_v <= g_tvalid;
        end if;
      elsif g_tvalid = '1' and rs_sv = '0' then
        -- salida retenida: la palabra aceptada va al skid
        rs_sd <= g_tlast & g_tkeep & g_tdata; rs_sv <= '1';
      end if;
    end if;
  end process;

  -- FIFO 8 + registro de salida (FWFT)
  process(clk_dp)
    variable v_lvl : unsigned(3 downto 0);
    variable v_rp  : unsigned(2 downto 0);
    variable pop, load : boolean;
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then
        wptr <= (others => '0'); rptr <= (others => '0');
        flevel <= (others => '0'); o_v <= '0'; blk_ovf <= '0'; blk_ovf_p <= '0';
      else
        v_lvl := flevel;
        v_rp  := rptr;
        pop := (o_v = '1' and pt_ready = '1');
        -- carga del registro de salida desde la memoria
        load := (o_v = '0' or pop) and v_lvl /= 0;
        if load then
          o_blk <= fmem(to_integer(v_rp));
          v_rp  := v_rp + 1;
          v_lvl := v_lvl - 1;
          o_v   <= '1';
        elsif pop then
          o_v <= '0';
        end if;
        blk_ovf_p <= '0';
        if b_valid = '1' then
          if v_lvl /= 8 then
            fmem(to_integer(wptr)) <= b_isd & b_pl;
            wptr  <= wptr + 1;
            v_lvl := v_lvl + 1;
          else
            -- cannot happen with ce = (level <= 4); never overwrite (fix B1)
            blk_ovf <= '1'; blk_ovf_p <= '1';
          end if;
        end if;
        rptr   <= v_rp;
        flevel <= v_lvl;
      end if;
    end if;
  end process;

  -- pragma translate_off
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      assert not (rst_dp = '0' and b_valid = '1' and flevel = 8)
        report "mac25g_datapath: block FIFO overflow (block dropped)" severity error;
    end if;
  end process;
  -- pragma translate_on

  -----------------------------------------------------------------------------
  -- PCS 64B/66B
  -----------------------------------------------------------------------------
  g_gb: if GEARBOX generate
    -- TX a tasa de linea (mac25g_pcs_tx: scrambler + gearbox del Core 19) y
    -- RX del Core 19 sin modificar, con loopback de palabras de 64 bits
    u_pcs_tx: entity work.mac25g_pcs_tx
      port map (clk=>clk_dp, rst=>rst_dp,
                in_valid=>o_v, in_payload=>o_blk(63 downto 0), in_is_data=>o_blk(64),
                in_ready=>pt_ready, out_valid=>pt_ovalid, out_word=>pt_oword);

    process(clk_dp)
    begin
      if rising_edge(clk_dp) then
        if rst_dp = '1' then
          loop_valid <= '0';
        else
          loop_valid <= pt_ovalid and loopback;
        end if;
        if loopback = '1' then loop_word <= pt_oword;
        else loop_word <= (others => '0'); end if;
      end if;
    end process;

    -- Core 19 RX with clause-49 block sync (bit slip on the 64-bit words).
    -- Blocks reach the MAC only with block_lock; a block with an invalid
    -- sync header becomes an /E/ block (clause 49 R_TYPE = E).
    b_gb: block
      signal g_v, g_isd, g_hok, g_lock : std_logic;
      signal g_pl : std_logic_vector(63 downto 0);
    begin
      u_pcs_rx: entity work.pcs_rx_datapath
        port map (clk=>clk_dp, rst=>rst_dp,
                  in_valid=>loop_valid, in_word=>loop_word, in_ready=>pr_ready,
                  out_valid=>g_v, out_payload=>g_pl, out_is_data=>g_isd,
                  out_hdr_ok=>g_hok, out_lock=>g_lock, out_hi_ber=>open,
                  ev_goodsh=>open, ev_badsh=>open, ev_slip=>open, ev_lost=>open);
      pr_valid <= g_v and g_lock;
      pr_isd   <= g_isd;
      pr_pl    <= g_pl when g_hok = '1' else ERROR_BLOCK;
    end block;
  end generate;

  g_66: if not GEARBOX generate
    -- bloque de 66 bits por ciclo (como el gearbox interno de un GT)
    signal b66_v, l66_v : std_logic := '0';
    signal b66, l66 : std_logic_vector(65 downto 0) := (others => '0');
  begin
    pt_ready <= '1';
    u_pcs_tx: entity work.mac25g_pcs66_tx
      port map (clk=>clk_dp, rst=>rst_dp,
                in_valid=>o_v, in_payload=>o_blk(63 downto 0), in_is_data=>o_blk(64),
                out_valid=>b66_v, out_block=>b66);

    process(clk_dp)
    begin
      if rising_edge(clk_dp) then
        if rst_dp = '1' then
          l66_v <= '0';
        else
          l66_v <= b66_v and loopback;
        end if;
        if loopback = '1' then l66 <= b66; else l66 <= (others => '0'); end if;
      end if;
    end process;

    u_pcs_rx: entity work.mac25g_pcs66_rx
      port map (clk=>clk_dp, rst=>rst_dp,
                in_valid=>l66_v, in_block=>l66,
                out_valid=>pr_valid, out_payload=>pr_pl, out_is_data=>pr_isd,
                out_hdr_ok=>open);
  end generate;

  -----------------------------------------------------------------------------
  -- MAC RX + checker
  -----------------------------------------------------------------------------
  u_rx: entity work.mac25g_rx
    port map (clk=>clk_dp, rst=>rst_dp,
              in_valid=>pr_valid, in_payload=>pr_pl, in_is_data=>pr_isd,
              own_mac=>own_mac, promisc=>promisc,
              m_tdata=>r_tdata, m_tkeep=>r_tkeep, m_tlast=>r_tlast,
              m_tuser=>r_tuser, m_tvalid=>r_tvalid,
              ev_ok=>e_ok, ev_bytes=>e_bytes, ev_crc=>e_crc, ev_runt=>e_runt,
              ev_runt0=>e_r0, ev_over=>e_over, ev_abort=>e_ab, ev_abort0=>e_a0,
              ev_filt=>e_filt, ev_proto=>e_proto, link_up=>lnk);

  -- PAUSE detection on the RX stream (MAC control frames are consumed)
  u_prx: entity work.mac25g_pause_rx
    port map (clk=>clk_dp, rst=>rst_dp, own_mac=>own_mac,
              s_tdata=>r_tdata, s_tlast=>r_tlast, s_tuser=>r_tuser, s_tvalid=>r_tvalid,
              is_ctrl=>x_ctrl, pause_stb=>x_pstb, pause_quanta=>x_pq);

  -- RX frame FIFO: commit at tlast, control frames dropped, no-room drop,
  -- drained with the consumer's rx_tready
  u_rxq: entity work.mac25g_axis_fifo
    generic map (AW => RXQ_AW, STORE_FW => true, NO_BP => true)
    port map (clk=>clk_dp, rst=>rst_dp,
              s_tdata=>r_tdata, s_tkeep=>r_tkeep, s_tlast=>r_tlast,
              s_tuser=>r_tuser, s_tdrop=>x_ctrl, s_tvalid=>r_tvalid, s_tready=>open,
              m_tdata=>f_tdata, m_tkeep=>f_tkeep, m_tlast=>f_tlast, m_tuser=>f_tuser,
              m_tvalid=>f_tvalid, m_tready=>rx_tready,
              level=>f_level, ev_ovf=>f_ovf, ev_drop=>f_drop);

  -- XOFF with hysteresis from the RX FIFO level
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then xoff_r <= '0';
      elsif resize(f_level, 16) >= rx_hi_wm then xoff_r <= '1';
      elsif resize(f_level, 16) <= rx_lo_wm then xoff_r <= '0';
      end if;
    end if;
  end process;

  u_chk: entity work.mac25g_chk
    port map (clk=>clk_dp, rst=>rst_dp, restart=>gen_start,
              dst=>own_mac, src=>src_mac,
              s_tdata=>f_tdata, s_tkeep=>f_tkeep, s_tlast=>f_tlast,
              s_tuser=>f_tuser, s_tvalid=>f_tvalid and rx_tready,
              ev_ok=>c_ok, ev_bad=>c_bad, ev_seq=>c_seq, ev_rxerr=>c_rxe);

  -----------------------------------------------------------------------------
  -- contadores y estado
  -----------------------------------------------------------------------------
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      q_txf <= t_evf; q_txb <= t_evb; q_rxok <= e_ok; q_rxb <= e_bytes;
      q_crc <= e_crc; q_over <= e_over; q_filt <= e_filt; q_proto <= e_proto;
      q_cok <= c_ok; q_cbad <= c_bad; q_cseq <= c_seq; q_crxe <= c_rxe;
      q_busy <= x_busy; q_und <= t_evu;
      q_runt  <= ('0' & e_runt) + ('0' & e_r0);
      q_abort <= ('0' & e_ab) + ('0' & e_a0);
    end if;
  end process;

  process(clk_dp)
    procedure inc(signal c : inout unsigned(31 downto 0); en : std_logic) is
    begin
      if en = '1' and c /= x"FFFFFFFF" then c <= c + 1; end if;    -- saturates
    end procedure;
  begin
    if rising_edge(clk_dp) then
      p_lnk_lo <= '0'; p_done <= '0';
      clr_r <= rst_dp or cnt_clear;           -- clear registrado y replicado
      if clr_r = '1' then
        cnt <= (others => (others => '0'));
        rx_act <= '0'; tx_act <= '0';
        if rst_dp = '1' then lnk_d <= '0'; done_d <= '0'; end if;
      else
        if q_txf = '1' then
          inc(cnt(0), '1');
          cnt(1) <= sat_add(cnt(1), resize(q_txb, 32));
          tx_act <= '1';
        end if;
        if q_rxok = '1' then
          inc(cnt(2), '1');
          cnt(3) <= sat_add(cnt(3), resize(q_rxb, 32));
          rx_act <= '1';
        end if;
        inc(cnt(4), q_crc);
        -- runt/aborto pueden llegar de dos fuentes en el mismo ciclo
        cnt(5) <= sat_add(cnt(5), resize(q_runt, 32));
        inc(cnt(6), q_over);
        cnt(7) <= sat_add(cnt(7), resize(q_abort, 32));
        inc(cnt(8), q_filt);
        inc(cnt(9), q_proto);
        inc(cnt(10), q_cok);
        inc(cnt(11), q_cbad);
        inc(cnt(12), q_cseq);
        inc(cnt(13), q_crxe);
        inc(cnt(14), q_busy);
        inc(cnt(15), q_und);
      end if;
      -- flow-control / FIFO counters (cnt2)
      q2_rxp <= e_rxp; q2_txp <= e_txp; q2_ctl <= f_drop; q2_ovf <= f_ovf;
      q2_kerr <= t_evk; q2_bovf <= blk_ovf_p; q2_paused <= paused and ce;
      if clr_r = '1' then
        cnt2 <= (others => (others => '0'));
      else
        inc(cnt2(0), q2_rxp);
        inc(cnt2(1), q2_txp);
        inc(cnt2(2), q2_ctl);
        inc(cnt2(3), q2_ovf);
        inc(cnt2(4), q2_kerr);
        inc(cnt2(5), q2_bovf);
        inc(cnt2(6), q2_paused);
        if resize(f_level, 32) > cnt2(7) then cnt2(7) <= resize(f_level, 32); end if;
      end if;
      if rst_dp = '0' then
        lnk_d  <= lnk;
        done_d <= x_done;
        if lnk_d = '1' and lnk = '0' then p_lnk_lo <= '1'; end if;
        if done_d = '0' and x_done = '1' then p_done <= '1'; end if;
      end if;
    end if;
  end process;

  gen_flat: for i in 0 to 15 generate
    cnt_flat(32*i+31 downto 32*i) <= std_logic_vector(cnt(i));
  end generate;
  gen_flat2: for i in 0 to 7 generate
    cnt2_flat(32*i+31 downto 32*i) <= std_logic_vector(cnt2(i));
  end generate;
  st_paused <= paused;
  st_xoff   <= xoff_r;

  st_link   <= lnk;
  st_busy   <= x_busy;
  st_done   <= x_done;
  st_rx_act <= rx_act;
  st_tx_act <= tx_act;

  ev_done   <= p_done;
  ev_crc    <= e_crc;
  ev_chkerr <= c_bad or c_seq;
  ev_lnk_lo <= p_lnk_lo;

end architecture rtl;
