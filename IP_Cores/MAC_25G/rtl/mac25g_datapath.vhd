-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Datapath de silicio (dominio clk_dp, 390.625 MHz: una ranura de bloque de
-- 66 bits por ciclo; con el gearbox de fabric 66->64 del banco de loopback
-- eso equivale a 25.0 Gb/s serie, ver README seccion 3):
--
--   mac25g_gen -> mac25g_tx -> FIFO de bloques -> mac25g_pcs_tx
--      -> loopback paralelo registrado
--   pcs_rx_datapath (Core 19) -> mac25g_rx -> mac25g_chk
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
--  14 BURST_CYCLES (ciclos con el generador activo)  15 TX_UNDERRUN
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
    GEARBOX : boolean := false
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
    cnt_flat  : out std_logic_vector(16*32-1 downto 0)
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
  attribute MAX_FANOUT : integer;
  attribute MAX_FANOUT of ce : signal is 32;
  attribute MAX_FANOUT of clr_r : signal is 64;
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

  u_tx: entity work.mac25g_tx
    port map (clk=>clk_dp, rst=>rst_dp, ce=>ce,
              s_tdata=>rs_d(63 downto 0), s_tkeep=>rs_d(71 downto 64),
              s_tlast=>rs_d(72),
              s_tvalid=>s_tvalid, s_tready=>s_tready, inj=>inj,
              blk_valid=>b_valid, blk_payload=>b_pl, blk_is_data=>b_isd,
              ev_frame=>t_evf, ev_bytes=>t_evb, ev_underrun=>t_evu);

  -- MAC_EN abre el paso de tramas (cuasi-estatico: se captura con CMD)
  s_tvalid <= rs_v and mac_en;
  rs_take  <= s_tready and mac_en;
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
        flevel <= (others => '0'); o_v <= '0';
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
        if b_valid = '1' then
          fmem(to_integer(wptr)) <= b_isd & b_pl;
          wptr  <= wptr + 1;
          v_lvl := v_lvl + 1;
        end if;
        rptr   <= v_rp;
        flevel <= v_lvl;
      end if;
    end if;
  end process;

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

    u_pcs_rx: entity work.pcs_rx_datapath
      port map (clk=>clk_dp, rst=>rst_dp,
                in_valid=>loop_valid, in_word=>loop_word, in_ready=>pr_ready,
                out_valid=>pr_valid, out_payload=>pr_pl, out_is_data=>pr_isd);
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
                out_valid=>pr_valid, out_payload=>pr_pl, out_is_data=>pr_isd);
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

  u_chk: entity work.mac25g_chk
    port map (clk=>clk_dp, rst=>rst_dp, restart=>gen_start,
              dst=>own_mac, src=>src_mac,
              s_tdata=>r_tdata, s_tkeep=>r_tkeep, s_tlast=>r_tlast,
              s_tuser=>r_tuser, s_tvalid=>r_tvalid,
              ev_ok=>c_ok, ev_bad=>c_bad, ev_seq=>c_seq, ev_rxerr=>c_rxe);

  -----------------------------------------------------------------------------
  -- contadores y estado
  -----------------------------------------------------------------------------
  process(clk_dp)
    procedure inc(signal c : inout unsigned(31 downto 0); en : std_logic) is
    begin
      if en = '1' then c <= c + 1; end if;
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
        if t_evf = '1' then
          cnt(0) <= cnt(0) + 1;
          cnt(1) <= cnt(1) + resize(t_evb, 32);
          tx_act <= '1';
        end if;
        if e_ok = '1' then
          cnt(2) <= cnt(2) + 1;
          cnt(3) <= cnt(3) + resize(e_bytes, 32);
          rx_act <= '1';
        end if;
        inc(cnt(4), e_crc);
        -- runt/aborto pueden llegar de dos fuentes en el mismo ciclo
        if e_runt = '1' and e_r0 = '1' then cnt(5) <= cnt(5) + 2;
        elsif e_runt = '1' or e_r0 = '1' then cnt(5) <= cnt(5) + 1; end if;
        inc(cnt(6), e_over);
        if e_ab = '1' and e_a0 = '1' then cnt(7) <= cnt(7) + 2;
        elsif e_ab = '1' or e_a0 = '1' then cnt(7) <= cnt(7) + 1; end if;
        inc(cnt(8), e_filt);
        inc(cnt(9), e_proto);
        inc(cnt(10), c_ok);
        inc(cnt(11), c_bad);
        inc(cnt(12), c_seq);
        inc(cnt(13), c_rxe);
        inc(cnt(14), g_busy);
        inc(cnt(15), t_evu);
      end if;
      if rst_dp = '0' then
        lnk_d  <= lnk;
        done_d <= g_done;
        if lnk_d = '1' and lnk = '0' then p_lnk_lo <= '1'; end if;
        if done_d = '0' and g_done = '1' then p_done <= '1'; end if;
      end if;
    end if;
  end process;

  gen_flat: for i in 0 to 15 generate
    cnt_flat(32*i+31 downto 32*i) <= std_logic_vector(cnt(i));
  end generate;

  st_link   <= lnk;
  st_busy   <= g_busy;
  st_done   <= g_done;
  st_rx_act <= rx_act;
  st_tx_act <= tx_act;

  ev_done   <= p_done;
  ev_crc    <= e_crc;
  ev_chkerr <= c_bad or c_seq;
  ev_lnk_lo <= p_lnk_lo;

end architecture rtl;
