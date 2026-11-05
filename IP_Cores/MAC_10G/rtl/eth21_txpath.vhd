-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Camino de transmision (dominio tx_clk = TXUSRCLK del GT: 156.25 MHz a
-- 10.3125 Gb/s, 390.625 MHz a 25.78125 Gb/s; un bloque de 66 bits por ciclo):
--
--   eth21_udp_gen -> register slice AXIS -> TX frame FIFO (store-and-
--     forward, audit 2026-11) -> mac25g_pause_tx -> mac25g_tx (Core 20,
--     ce = 1) -> mac25g_pcs66_tx (scrambler) -> eth21_gtmap_tx -> registro
--     -> GT
--
-- IEEE 802.3x PAUSE (audit 2026-11): rx_pause_stb / rx_pause_q come from
-- the RX clock domain through mac25g_hsync, rx_xoff (RX FIFO above its high
-- watermark) through mac25g_lsync (both crossings are in eth21_top).
--
-- El GT en 64B66B_ASYNC consume una palabra por ciclo sin backpressure, asi
-- que el MAC avanza siempre (ce = 1) y emite idles sin trafico; MAC_EN solo
-- deja pasar las tramas del generador.
--
-- Contadores: TX_FRAMES, TX_BYTES (bytes en el cable incl. FCS),
-- BURST_CYCLES (ciclos con el generador activo), TX_UNDERRUN.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth21_txpath is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;

    mac_en    : in  std_logic;
    gen_cont  : in  std_logic;
    bit_rev   : in  std_logic;
    hdr_swap  : in  std_logic;
    peer_mac  : in  std_logic_vector(47 downto 0);
    own_mac   : in  std_logic_vector(47 downto 0);
    own_ip    : in  std_logic_vector(31 downto 0);
    peer_ip   : in  std_logic_vector(31 downto 0);
    sport     : in  std_logic_vector(15 downto 0);
    dport     : in  std_logic_vector(15 downto 0);
    len_min   : in  unsigned(10 downto 0);
    len_max   : in  unsigned(10 downto 0);
    len_step  : in  unsigned(10 downto 0);
    gen_count : in  unsigned(31 downto 0);
    gen_gap   : in  unsigned(15 downto 0);

    gen_start : in  std_logic;
    gen_stop  : in  std_logic;
    cnt_clear : in  std_logic;
    inj       : in  std_logic;

    st_busy   : out std_logic;
    st_done   : out std_logic;
    st_tx_act : out std_logic;

    txdata    : out std_logic_vector(63 downto 0);
    txheader  : out std_logic_vector(1 downto 0);

    -- 0 TX_FRAMES 1 TX_BYTES 2 BURST_CYCLES 3 TX_UNDERRUN
    cnt_flat  : out std_logic_vector(4*32-1 downto 0);

    -- 802.3x flow control (defaults: disabled)
    pause_honor  : in  std_logic := '0';
    pause_auto   : in  std_logic := '0';
    pause_quanta : in  std_logic_vector(15 downto 0) := x"FFFF";
    pause_sw_req : in  std_logic := '0';
    pause_sw_q   : in  std_logic_vector(15 downto 0) := x"0000";
    rx_pause_stb : in  std_logic := '0';
    rx_pause_q   : in  std_logic_vector(15 downto 0) := x"0000";
    rx_xoff      : in  std_logic := '0';
    st_paused    : out std_logic;
    -- 0 TX_PAUSE (sent) 1 PAUSE_HONOURED 2 TX_KEEP_ERR 3 PAUSED_CYCLES
    cnt2_flat    : out std_logic_vector(4*32-1 downto 0)
  );
end entity eth21_txpath;

architecture rtl of eth21_txpath is
  signal g_tdata  : std_logic_vector(63 downto 0);
  signal g_tkeep  : std_logic_vector(7 downto 0);
  signal g_tlast, g_tvalid, g_tready, g_busy, g_done : std_logic;
  signal s_tvalid, s_tready : std_logic;
  signal rs_v, rs_sv : std_logic := '0';
  signal rs_d, rs_sd : std_logic_vector(72 downto 0) := (others => '0');
  signal rs_ready, rs_take : std_logic;
  signal b_valid, b_isd : std_logic;
  signal b_pl     : std_logic_vector(63 downto 0);
  signal t_evf, t_evu : std_logic;
  signal t_evb    : unsigned(15 downto 0);
  signal b66_v    : std_logic;
  signal b66      : std_logic_vector(65 downto 0);
  signal m_d      : std_logic_vector(63 downto 0);
  signal m_h      : std_logic_vector(1 downto 0);
  signal o_d      : std_logic_vector(63 downto 0) := (others => '0');
  signal o_h      : std_logic_vector(1 downto 0) := (others => '0');
  signal q_txf, q_busy, q_und : std_logic := '0';
  signal q_txb    : unsigned(15 downto 0) := (others => '0');
  signal clr_r    : std_logic := '1';
  type cnt_t is array (0 to 3) of unsigned(31 downto 0);
  signal cnt      : cnt_t := (others => (others => '0'));
  signal tx_act   : std_logic := '0';
  signal q_s_tvalid, q_s_tready, q_tlast, q_tvalid, q_tready, p_tlast : std_logic;
  signal q_tdata, p_tdata : std_logic_vector(63 downto 0);
  signal q_tkeep, p_tkeep : std_logic_vector(7 downto 0);
  signal q_level  : unsigned(9 downto 0);
  signal t_evk, paused, e_txp, e_rxp, tx_pend : std_logic;
  signal q2_txp, q2_rxp, q2_kerr, q2_pau : std_logic := '0';
  type cnt2_t is array (0 to 3) of unsigned(31 downto 0);
  signal cnt2     : cnt2_t := (others => (others => '0'));

  -- saturating counter arithmetic (audit 2026-11, B3)
  function sat_add(c : unsigned(31 downto 0); x : unsigned(31 downto 0)) return unsigned is
    variable t : unsigned(32 downto 0);
  begin
    t := ('0' & c) + ('0' & x);
    if t(32) = '1' then return x"FFFFFFFF"; else return t(31 downto 0); end if;
  end function;
  attribute MAX_FANOUT : integer;
  attribute MAX_FANOUT of clr_r : signal is 64;
  attribute MAX_FANOUT of rs_take : signal is 32;
begin

  u_gen: entity work.eth21_udp_gen
    port map (clk=>clk, rst=>rst, start=>gen_start, stop=>gen_stop, cont=>gen_cont,
              dst=>peer_mac, src=>own_mac, sip=>own_ip, dip=>peer_ip,
              sport=>sport, dport=>dport,
              len_min=>len_min, len_max=>len_max, len_step=>len_step,
              count=>gen_count, gap=>gen_gap,
              m_tdata=>g_tdata, m_tkeep=>g_tkeep, m_tlast=>g_tlast,
              m_tvalid=>g_tvalid, m_tready=>g_tready, busy=>g_busy, done=>g_done);

  -- register slice de 2 entradas: el tready del MAC no atraviesa el generador
  q_s_tvalid <= rs_v and mac_en;
  rs_take  <= q_s_tready and mac_en;
  rs_ready <= not rs_sv;
  g_tready <= rs_ready;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rs_v <= '0'; rs_sv <= '0';
      elsif rs_take = '1' or rs_v = '0' then
        if rs_sv = '1' then
          rs_d <= rs_sd; rs_v <= '1'; rs_sv <= '0';
        else
          rs_d <= g_tlast & g_tkeep & g_tdata; rs_v <= g_tvalid;
        end if;
      elsif g_tvalid = '1' and rs_sv = '0' then
        rs_sd <= g_tlast & g_tkeep & g_tdata; rs_sv <= '1';
      end if;
    end if;
  end process;

  -- TX frame FIFO (store-and-forward): AXIS bubbles of the source are legal
  u_txq: entity work.mac25g_axis_fifo
    generic map (AW => 9, STORE_FW => true, NO_BP => false)
    port map (clk=>clk, rst=>rst,
              s_tdata=>rs_d(63 downto 0), s_tkeep=>rs_d(71 downto 64),
              s_tlast=>rs_d(72), s_tuser=>'0', s_tdrop=>'0',
              s_tvalid=>q_s_tvalid, s_tready=>q_s_tready,
              m_tdata=>q_tdata, m_tkeep=>q_tkeep, m_tlast=>q_tlast, m_tuser=>open,
              m_tvalid=>q_tvalid, m_tready=>q_tready,
              level=>q_level, ev_ovf=>open, ev_drop=>open);
  tx_pend <= '1' when q_level /= 0 or q_tvalid = '1' else '0';

  u_ptx: entity work.mac25g_pause_tx
    port map (clk=>clk, rst=>rst, ce=>'1', own_mac=>own_mac,
              honor_en=>pause_honor, auto_en=>pause_auto, quanta=>pause_quanta,
              rx_stb=>rx_pause_stb, rx_quanta=>rx_pause_q, xoff=>rx_xoff,
              sw_req=>pause_sw_req, sw_quanta=>pause_sw_q,
              s_tdata=>q_tdata, s_tkeep=>q_tkeep, s_tlast=>q_tlast,
              s_tvalid=>q_tvalid, s_tready=>q_tready,
              m_tdata=>p_tdata, m_tkeep=>p_tkeep, m_tlast=>p_tlast,
              m_tvalid=>s_tvalid, m_tready=>s_tready,
              paused=>paused, ev_tx_pause=>e_txp, ev_rx_pause=>e_rxp);

  u_tx: entity work.mac25g_tx
    port map (clk=>clk, rst=>rst, ce=>'1',
              s_tdata=>p_tdata, s_tkeep=>p_tkeep, s_tlast=>p_tlast,
              s_tvalid=>s_tvalid, s_tready=>s_tready, inj=>inj,
              blk_valid=>b_valid, blk_payload=>b_pl, blk_is_data=>b_isd,
              ev_frame=>t_evf, ev_bytes=>t_evb, ev_underrun=>t_evu,
              ev_keep_err=>t_evk);

  u_pcs: entity work.mac25g_pcs66_tx
    port map (clk=>clk, rst=>rst, in_valid=>b_valid, in_payload=>b_pl,
              in_is_data=>b_isd, out_valid=>b66_v, out_block=>b66);

  u_map: entity work.eth21_gtmap_tx
    port map (blk=>b66, bit_rev=>bit_rev, hdr_swap=>hdr_swap,
              txdata=>m_d, txheader=>m_h);

  -- registro de salida hacia el GT (durante el reset: bloques de idle validos
  -- no; se envia todo a cero = cabecera invalida, el enlace no levanta)
  process(clk)
  begin
    if rising_edge(clk) then
      if b66_v = '1' then
        o_d <= m_d; o_h <= m_h;
      else
        o_d <= (others => '0'); o_h <= "00";
      end if;
    end if;
  end process;

  txdata   <= o_d;
  txheader <= o_h;

  -- contadores
  process(clk)
  begin
    if rising_edge(clk) then
      q_txf <= t_evf; q_txb <= t_evb; q_busy <= g_busy or tx_pend; q_und <= t_evu;
      q2_txp <= e_txp; q2_rxp <= e_rxp; q2_kerr <= t_evk; q2_pau <= paused;
      clr_r <= rst or cnt_clear;
      if clr_r = '1' then
        cnt <= (others => (others => '0'));
        cnt2 <= (others => (others => '0'));
        tx_act <= '0';
      else
        if q_txf = '1' then
          cnt(0) <= sat_add(cnt(0), x"00000001");
          cnt(1) <= sat_add(cnt(1), resize(q_txb, 32));
          tx_act <= '1';
        end if;
        if q_busy = '1' then cnt(2) <= sat_add(cnt(2), x"00000001"); end if;
        if q_und = '1' then cnt(3) <= sat_add(cnt(3), x"00000001"); end if;
        if q2_txp = '1' then cnt2(0) <= sat_add(cnt2(0), x"00000001"); end if;
        if q2_rxp = '1' then cnt2(1) <= sat_add(cnt2(1), x"00000001"); end if;
        if q2_kerr = '1' then cnt2(2) <= sat_add(cnt2(2), x"00000001"); end if;
        if q2_pau = '1' then cnt2(3) <= sat_add(cnt2(3), x"00000001"); end if;
      end if;
    end if;
  end process;

  gen_flat: for i in 0 to 3 generate
    cnt_flat(32*i+31 downto 32*i) <= std_logic_vector(cnt(i));
    cnt2_flat(32*i+31 downto 32*i) <= std_logic_vector(cnt2(i));
  end generate;

  -- the burst ends when the generator is done AND the TX FIFO is empty
  st_busy   <= g_busy or tx_pend;
  st_done   <= g_done and not tx_pend;
  st_paused <= paused;
  st_tx_act <= tx_act;

end architecture rtl;
