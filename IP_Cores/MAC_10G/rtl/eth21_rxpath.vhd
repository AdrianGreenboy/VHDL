-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Camino de recepcion (dominio rx_clk = RXUSRCLK del GT):
--
--   GT (rxdata/rxheader + valid) -> registro -> eth21_gtmap_rx
--     -> eth21_blocklock (cl.49, maneja rxgearboxslip)
--     -> mac25g_pcs66_rx (descrambler, Core 20) -> mac25g_rx (Core 20)
--     -> eth21_udp_chk
--
-- Solo con block_lock pasan bloques al descrambler y al MAC (sin lock el MAC
-- no ve nada). Contadores (indice local -> registro global en eth21_top):
--   0 RX_OK 1 RX_BYTES 2 RX_CRC_ERR 3 RX_RUNT 4 RX_OVERSIZE 5 RX_ABORT
--   6 RX_FILTERED 7 RX_PROTO 8 CHK_OK 9 CHK_BAD 10 CHK_SEQ_ERR 11 CHK_RXERR
--  12 BLK_SLIPS 13 BAD_SYNC_HDR 14 LOCK_LOSS 15 RX_BLOCKS (bloques con lock)
--  16 RX_IDLE (bloques de idle 0x1E) 17 RX_LF 18 RX_RF (bloques con un
--     ordered set de Local / Remote Fault, tipos 0x4B, 0x2D o 0x55). Un
--     extremo que NO decodifica lo que le enviamos responde con Remote
--     Fault (RF); Local Fault llega de un PHY/retimer intermedio.
--     Con trafico del PC estos tres contadores dicen si los flags de orden
--     de bits de RX (idles validos) y de TX (el PC deja de mandar RF) son
--     correctos.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth21_rxpath is
  generic (
    SLIP_WAIT : natural := 64
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    promisc    : in  std_logic;
    bit_rev    : in  std_logic;
    hdr_swap   : in  std_logic;
    own_mac    : in  std_logic_vector(47 downto 0);
    peer_mac   : in  std_logic_vector(47 downto 0);
    own_ip     : in  std_logic_vector(31 downto 0);
    peer_ip    : in  std_logic_vector(31 downto 0);
    sport      : in  std_logic_vector(15 downto 0);
    dport      : in  std_logic_vector(15 downto 0);

    chk_restart: in  std_logic;
    cnt_clear  : in  std_logic;

    rxdata     : in  std_logic_vector(63 downto 0);
    rxheader   : in  std_logic_vector(1 downto 0);
    rxvalid    : in  std_logic;
    rxslip     : out std_logic;

    st_lock    : out std_logic;
    st_link    : out std_logic;
    st_rx_act  : out std_logic;
    ev_crc     : out std_logic;
    ev_chkerr  : out std_logic;

    cnt_flat   : out std_logic_vector(19*32-1 downto 0)
  );
end entity eth21_rxpath;

architecture rtl of eth21_rxpath is
  signal i_d      : std_logic_vector(63 downto 0) := (others => '0');
  signal i_h      : std_logic_vector(1 downto 0) := (others => '0');
  signal i_v      : std_logic := '0';
  signal blk      : std_logic_vector(65 downto 0);
  signal b_v      : std_logic := '0';
  signal b_blk    : std_logic_vector(65 downto 0) := (others => '0');
  signal lock, slip, e_bad, e_slip, e_lost : std_logic;
  signal pr_valid, pr_isd : std_logic;
  signal pr_pl    : std_logic_vector(63 downto 0);
  signal r_tdata  : std_logic_vector(63 downto 0);
  signal r_tkeep  : std_logic_vector(7 downto 0);
  signal r_tlast, r_tuser, r_tvalid : std_logic;
  signal e_ok, e_crc, e_runt, e_r0, e_over, e_ab, e_a0, e_filt, e_proto, lnk : std_logic;
  signal e_bytes  : unsigned(15 downto 0);
  signal c_ok, c_bad, c_seq, c_rxe : std_logic;
  signal q_rxok, q_crc, q_over, q_filt, q_proto : std_logic := '0';
  signal q_cok, q_cbad, q_cseq, q_crxe, q_slip, q_bad, q_lost, q_blk : std_logic := '0';
  signal q_idle, q_lf, q_rf : std_logic := '0';
  signal q_rxb    : unsigned(15 downto 0) := (others => '0');
  signal q_runt, q_abort : unsigned(1 downto 0) := (others => '0');
  signal clr_r    : std_logic := '1';
  type cnt_t is array (0 to 18) of unsigned(31 downto 0);
  signal cnt      : cnt_t := (others => (others => '0'));
  signal rx_act   : std_logic := '0';
  signal slip_r   : std_logic := '0';
  attribute MAX_FANOUT : integer;
  attribute MAX_FANOUT of clr_r : signal is 64;
begin

  -- registro de entrada desde el GT
  process(clk)
  begin
    if rising_edge(clk) then
      i_v <= rxvalid and not rst;
      i_d <= rxdata;
      i_h <= rxheader;
    end if;
  end process;

  u_map: entity work.eth21_gtmap_rx
    port map (rxdata=>i_d, rxheader=>i_h, bit_rev=>bit_rev, hdr_swap=>hdr_swap,
              blk=>blk);

  u_bl: entity work.eth21_blocklock
    generic map (SLIP_WAIT => SLIP_WAIT)
    port map (clk=>clk, rst=>rst, in_valid=>i_v, in_header=>blk(1 downto 0),
              slip=>slip, lock=>lock, ev_badsh=>e_bad, ev_slip=>e_slip,
              ev_lost=>e_lost);

  -- bloque alineado con la decision de lock (un ciclo)
  process(clk)
  begin
    if rising_edge(clk) then
      b_v   <= i_v and lock and not rst;
      b_blk <= blk;
      slip_r <= slip;
    end if;
  end process;
  rxslip <= slip_r;

  u_pcs: entity work.mac25g_pcs66_rx
    port map (clk=>clk, rst=>rst, in_valid=>b_v, in_block=>b_blk,
              out_valid=>pr_valid, out_payload=>pr_pl, out_is_data=>pr_isd);

  u_rx: entity work.mac25g_rx
    port map (clk=>clk, rst=>rst,
              in_valid=>pr_valid, in_payload=>pr_pl, in_is_data=>pr_isd,
              own_mac=>own_mac, promisc=>promisc,
              m_tdata=>r_tdata, m_tkeep=>r_tkeep, m_tlast=>r_tlast,
              m_tuser=>r_tuser, m_tvalid=>r_tvalid,
              ev_ok=>e_ok, ev_bytes=>e_bytes, ev_crc=>e_crc, ev_runt=>e_runt,
              ev_runt0=>e_r0, ev_over=>e_over, ev_abort=>e_ab, ev_abort0=>e_a0,
              ev_filt=>e_filt, ev_proto=>e_proto, link_up=>lnk);

  -- el checker espera las tramas del propio generador (loopback): destino =
  -- peer_mac, origen = own_mac, IP origen = own_ip
  u_chk: entity work.eth21_udp_chk
    port map (clk=>clk, rst=>rst, restart=>chk_restart,
              dst=>peer_mac, src=>own_mac, sip=>own_ip, dip=>peer_ip,
              sport=>sport, dport=>dport,
              s_tdata=>r_tdata, s_tkeep=>r_tkeep, s_tlast=>r_tlast,
              s_tuser=>r_tuser, s_tvalid=>r_tvalid,
              ev_ok=>c_ok, ev_bad=>c_bad, ev_seq=>c_seq, ev_rxerr=>c_rxe);

  -- contadores
  process(clk)
  begin
    if rising_edge(clk) then
      q_rxok <= e_ok; q_rxb <= e_bytes; q_crc <= e_crc; q_over <= e_over;
      q_filt <= e_filt; q_proto <= e_proto;
      q_cok <= c_ok; q_cbad <= c_bad; q_cseq <= c_seq; q_crxe <= c_rxe;
      q_slip <= e_slip; q_bad <= e_bad; q_lost <= e_lost; q_blk <= b_v;
      q_runt  <= ('0' & e_runt) + ('0' & e_r0);
      -- bloques de control a la salida del descrambler
      -- ordered set en la mitad baja (O0, bytes 1..3) o alta (O4, bytes
      -- 5..7): 0x4B = OS|C, 0x2D = C|OS, 0x55 = OS|OS. Cada bloque cuenta
      -- una vez.
      q_idle <= '0'; q_lf <= '0'; q_rf <= '0';
      if pr_valid = '1' and pr_isd = '0' then
        if pr_pl(7 downto 0) = x"1E" then q_idle <= '1'; end if;
        if ((pr_pl(7 downto 0) = x"4B" or pr_pl(7 downto 0) = x"55") and
            pr_pl(35 downto 8) = x"0010000") or
           ((pr_pl(7 downto 0) = x"2D" or pr_pl(7 downto 0) = x"55") and
            pr_pl(63 downto 36) = x"0100000") then q_lf <= '1'; end if;
        if ((pr_pl(7 downto 0) = x"4B" or pr_pl(7 downto 0) = x"55") and
            pr_pl(35 downto 8) = x"0020000") or
           ((pr_pl(7 downto 0) = x"2D" or pr_pl(7 downto 0) = x"55") and
            pr_pl(63 downto 36) = x"0200000") then q_rf <= '1'; end if;
      end if;
      q_abort <= ('0' & e_ab) + ('0' & e_a0);
    end if;
  end process;

  process(clk)
    procedure inc(signal c : inout unsigned(31 downto 0); en : std_logic) is
    begin
      if en = '1' then c <= c + 1; end if;
    end procedure;
  begin
    if rising_edge(clk) then
      clr_r <= rst or cnt_clear;
      if clr_r = '1' then
        cnt <= (others => (others => '0'));
        rx_act <= '0';
      else
        if q_rxok = '1' then
          cnt(0) <= cnt(0) + 1;
          cnt(1) <= cnt(1) + resize(q_rxb, 32);
          rx_act <= '1';
        end if;
        inc(cnt(2), q_crc);
        cnt(3) <= cnt(3) + resize(q_runt, 32);
        inc(cnt(4), q_over);
        cnt(5) <= cnt(5) + resize(q_abort, 32);
        inc(cnt(6), q_filt);
        inc(cnt(7), q_proto);
        inc(cnt(8), q_cok);
        inc(cnt(9), q_cbad);
        inc(cnt(10), q_cseq);
        inc(cnt(11), q_crxe);
        inc(cnt(12), q_slip);
        inc(cnt(13), q_bad);
        inc(cnt(14), q_lost);
        inc(cnt(15), q_blk);
        inc(cnt(16), q_idle);
        inc(cnt(17), q_lf);
        inc(cnt(18), q_rf);
      end if;
    end if;
  end process;

  gen_flat: for i in 0 to 18 generate
    cnt_flat(32*i+31 downto 32*i) <= std_logic_vector(cnt(i));
  end generate;

  st_lock   <= lock;
  st_link   <= lnk;
  st_rx_act <= rx_act;
  ev_crc    <= e_crc;
  ev_chkerr <= c_bad or c_seq;

end architecture rtl;
