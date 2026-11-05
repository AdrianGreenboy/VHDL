-- ============================================================================
-- pcie_node.vhd -- PCIE IP (reworked in audit 2026-11)
-- Complete PCIe node (one end of the link):
--
--   [training]  LTSSM + ts_gen -----------------\
--   [L0 data]   arbiter -> DLL_TX -> framer ----->-- MUX TX -- scrambler --> PIPE
--                                     ^ DLLP (Ack/Nak from local DLL_RX)
--
--   PIPE -> [elastic buf] -> scrambler -> deframer -+- TS ------> LTSSM
--                                                   +- TLP -> rx_adapt -> DLL_RX
--                                                   |     -> rx_tlp_fifo -> TL_EP
--                                                   +- DLLP -> dllp_rx -> DLL_TX
--
-- Integrity chain (audit 2026-11):
--   * The TL only sees TLPs that passed LCRC and in-order sequence checks in
--     the DLL RX (buffered in pcie_rx_tlp_fifo, released on commit).
--   * Ack/Nak travel across the link as real DLLPs (CRC-16). The local DLL TX
--     purges its replay buffer with the PEER's acknowledged sequence number.
--   * AckNak latency timer (DLL RX), REPLAY_TIMER and REPLAY_NUM (DLL TX); a
--     REPLAY_NUM rollover or a burst of receiver framing errors requests a
--     retrain (L0 -> Recovery).
--   * The DLL is held in reset while the link is down (DL_Down: sequence
--     numbers restart on the next link-up, as both ends do).
--   * TX arbiter between injected requests (req_*) and local completer
--     responses: one whole TLP at a time (the old mux could interleave a
--     response into a request in progress).
--   * Requester-side completion timeout for non-posted requests sent on req_*
--     (MRd, CfgRd0, CfgWr0): CPL_TMO_C cycles; a request is also blocked while
--     all CPL_ENTRIES tracking entries are busy.
-- Role RC/EP: 'is_rc' (informative; both ends have a completer).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;
use work.pcie_ltssm_pkg.all;
use work.pcie_tl_pkg.all;
use work.pcie_dll_pkg.all;

entity pcie_node is
  generic (
    is_rc      : boolean := false;
    TIMEOUT_C  : integer := 5000;
    MAX_TLP    : integer := 128;    -- header+payload bytes
    REPLAY_TMO : integer := 4000;   -- DLL TX REPLAY_TIMER (cycles)
    ACKNAK_LAT : integer := 64;     -- DLL RX AckNak latency (cycles)
    CPL_TMO_C  : integer := 50000;  -- requester completion timeout (cycles)
    USE_EB     : boolean := false   -- insert the RX elastic buffer
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    en         : in  std_logic;

    cmd_start  : in  std_logic;
    cmd_hotrst : in  std_logic;

    pt_sym     : out work.pcie_8b10b_pkg.byte_t;
    pt_k       : out std_logic;
    pr_sym     : in  work.pcie_8b10b_pkg.byte_t;
    pr_k       : in  std_logic;

    -- raw TLP injection (header+payload) towards the local DLL
    req_valid  : in  std_logic;
    req_data   : in  work.pcie_8b10b_pkg.byte_t;
    req_last   : in  std_logic;
    req_ready  : out std_logic;

    msi_trigger: in  std_logic;

    link_up    : out std_logic;
    ltssm_state: out std_logic_vector(3 downto 0);
    bar0_dbg   : out work.pcie_tl_pkg.dw_t;
    mwr_cnt    : out std_logic_vector(15 downto 0);
    mrd_cnt    : out std_logic_vector(15 downto 0);
    good_rx    : out std_logic_vector(15 downto 0);
    replays    : out std_logic_vector(15 downto 0);
    -- completer output (so a TB can observe the EP's CplD)
    tlresp_valid : out std_logic;
    tlresp_data  : out work.pcie_8b10b_pkg.byte_t;
    tlresp_start : out std_logic;
    tlresp_last  : out std_logic;
    -- TLPs received from the link, VALIDATED (header+payload, no seq/LCRC)
    rxtlp_valid  : out std_logic;
    rxtlp_data   : out work.pcie_8b10b_pkg.byte_t;
    rxtlp_start  : out std_logic;
    rxtlp_last   : out std_logic;
    -- error / statistics (audit 2026-11)
    cpl_tmo      : out std_logic;                      -- pulse
    cpl_tmo_cnt  : out std_logic_vector(15 downto 0);
    bad_rx       : out std_logic_vector(15 downto 0);  -- TLPs NAKed/dropped
    nak_tx       : out std_logic_vector(15 downto 0);  -- Naks sent
    rpl_tmo      : out std_logic_vector(15 downto 0);  -- replay timer expiries
    ur_cnt       : out std_logic_vector(15 downto 0);  -- UR completions sent
    retrain_cnt  : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of pcie_node is
  signal send_ts, ts_kind : std_logic;
  signal ts_ctl : work.pcie_8b10b_pkg.byte_t;
  signal ts_done : std_logic;
  signal lt_state : std_logic_vector(3 downto 0);
  signal lup : std_logic;
  signal dl_up, dl_rst : std_logic := '1';

  signal g_sym : work.pcie_8b10b_pkg.byte_t; signal g_k, g_com, g_skp, g_byp, g_active : std_logic;
  signal f_sym : work.pcie_8b10b_pkg.byte_t; signal f_k, f_com, f_skp, f_byp, f_busy : std_logic;
  signal d2f_valid, d2f_last, d2f_ready, d2f_start, d2f_abort : std_logic;
  signal d2f_data : work.pcie_8b10b_pkg.byte_t;

  signal tx_sym : work.pcie_8b10b_pkg.byte_t; signal tx_k, tx_com, tx_skp, tx_byp : std_logic;
  signal rx_sym : work.pcie_8b10b_pkg.byte_t; signal rx_k, rxcom, rxskp : std_logic;
  signal eb_sym : work.pcie_8b10b_pkg.byte_t; signal eb_k, eb_en : std_logic;

  signal tok : rx_kind_t; signal tok_data : work.pcie_8b10b_pkg.byte_t; signal tok_valid : std_logic;
  signal ts_valid, ts_is_ts2, dfr_com, dfr_skp : std_logic;
  signal ts_link, ts_lane, ts_nfts, ts_rate, ts_ctl_rx : work.pcie_8b10b_pkg.byte_t;

  -- RX raw stream -> DLL RX
  signal ao_v, ao_s, ao_l, ao_a : std_logic; signal ao_d : work.pcie_8b10b_pkg.byte_t;
  -- DLL RX -> RX TLP buffer
  signal fw_wr, fw_last, fw_commit, fw_rollback, fw_ovf : std_logic;
  signal fw_data : work.pcie_8b10b_pkg.byte_t;
  signal fw_space : unsigned(9 downto 0);
  -- RX TLP buffer -> TL
  signal rq_v, rq_s, rq_l, rq_rdy : std_logic; signal rq_d : work.pcie_8b10b_pkg.byte_t;

  -- Ack/Nak: local DLL RX -> DLLP -> framer ; peer DLLP -> local DLL TX
  signal an_v, an_nak, an_rdy : std_logic; signal an_seq : std_logic_vector(11 downto 0);
  signal pk_v, pk_nak : std_logic; signal pk_seq : std_logic_vector(11 downto 0);
  signal dllp_bytes : std_logic_vector(47 downto 0);

  -- TX arbiter
  type src_t is (SRC_NONE, SRC_REQ, SRC_RESP);
  signal lock_src : src_t := SRC_NONE;
  signal grant    : src_t;
  signal dtx_valid, dtx_last, dll_ready : std_logic;
  signal dtx_data : work.pcie_8b10b_pkg.byte_t;
  signal tlep_ready, req_ok : std_logic;
  signal tr_v, tr_s, tr_l : std_logic; signal tr_d : work.pcie_8b10b_pkg.byte_t;

  -- DLL TX status
  signal retrain_dll, retrain_err, retrain_any : std_logic;
  signal rtr_cnt : unsigned(15 downto 0) := (others => '0');
  signal err_lvl : integer range 0 to 15 := 0;
  signal err_div : integer range 0 to 1023 := 0;

  -- completion-timeout tracker (requester side, req_* path)
  constant CPL_ENTRIES : integer := 4;
  type tag_arr_t is array (0 to CPL_ENTRIES-1) of std_logic_vector(7 downto 0);
  type tmr_arr_t is array (0 to CPL_ENTRIES-1) of integer range 0 to CPL_TMO_C;
  signal ct_used : std_logic_vector(CPL_ENTRIES-1 downto 0) := (others => '0');
  signal ct_tag  : tag_arr_t := (others => (others => '0'));
  signal ct_tmr  : tmr_arr_t := (others => 0);
  signal ct_full : std_logic;
  signal tq_i    : integer range 0 to 15 := 0;   -- byte index of the req TLP
  signal tq_np   : std_logic := '0';
  signal tq_tag  : std_logic_vector(7 downto 0) := (others => '0');
  signal rc_i    : integer range 0 to 15 := 0;   -- byte index of received TLP
  signal rc_cpl  : std_logic := '0';
  signal rc_hd   : std_logic_vector(7 downto 0) := (others => '0');  -- byte0
  signal rc_len  : unsigned(9 downto 0) := (others => '0');
  signal rc_bc   : unsigned(11 downto 0) := (others => '0');
  signal rc_tag  : std_logic_vector(7 downto 0) := (others => '0');
  signal tmo_cnt : unsigned(15 downto 0) := (others => '0');
  signal cpl_tmo_i : std_logic := '0';

  function is_np(b0 : std_logic_vector(7 downto 0)) return boolean is
  begin
    return b0 = B0_MRD3 or b0 = B0_MRD4 or b0 = B0_CFGRD0 or b0 = B0_CFGWR0;
  end function;
begin

  link_up     <= lup;
  ltssm_state <= lt_state;
  retrain_cnt <= std_logic_vector(rtr_cnt);
  cpl_tmo     <= cpl_tmo_i;
  cpl_tmo_cnt <= std_logic_vector(tmo_cnt);

  -- ---------------- LTSSM / TS ----------------
  u_ltssm : entity work.pcie_ltssm
    generic map (TIMEOUT_CYCLES => TIMEOUT_C)
    port map (clk=>clk, rst=>rst, en=>en,
              cmd_start=>cmd_start, cmd_hotrst=>cmd_hotrst,
              cmd_loopbk=>'0', cmd_disable=>'0', retrain=>retrain_any,
              tx_send_ts=>send_ts, tx_ts_kind=>ts_kind, tx_ctl=>ts_ctl,
              tx_ts_done=>ts_done,
              rx_ts_valid=>ts_valid, rx_is_ts2=>ts_is_ts2, rx_ctl=>ts_ctl_rx,
              state_o=>lt_state, link_up=>lup,
              ts1_rx_cnt=>open, ts2_rx_cnt=>open);

  u_tsgen : entity work.pcie_ts_gen
    port map (clk=>clk, rst=>rst, en=>en,
              send=>send_ts, ts_kind=>ts_kind, train_ctl=>ts_ctl,
              n_fts=>x"08", link_num=>PAD_BYTE, lane_num=>PAD_BYTE,
              done=>ts_done, active=>g_active,
              sym=>g_sym, sym_k=>g_k, sym_com=>g_com, sym_skp=>g_skp,
              sym_byp=>g_byp);

  -- Data Link up/down: the DLL (and TL parse state) run only after the first
  -- L0 entry and are reset when the LTSSM falls back to Detect / Hot Reset /
  -- Disabled (Recovery keeps the DLL state, as in the spec).
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        dl_up <= '0';
      elsif lup = '1' then
        dl_up <= '1';
      elsif lt_state = x"0" or lt_state = x"5" or lt_state = x"7" then
        dl_up <= '0';
      end if;
    end if;
  end process;
  dl_rst <= rst or not dl_up;

  -- ---------------- TX arbiter: one whole TLP at a time ----------------
  ct_full <= '1' when ct_used = (ct_used'range => '1') else '0';
  -- a new non-posted request needs a free completion-tracking entry
  req_ok  <= '0' when (ct_full = '1' and is_np(req_data)) else '1';
  grant   <= lock_src when lock_src /= SRC_NONE else
             SRC_RESP when tr_v = '1' else
             SRC_REQ  when (req_valid = '1' and req_ok = '1') else
             SRC_NONE;
  dtx_valid  <= tr_v when grant = SRC_RESP else req_valid when grant = SRC_REQ else '0';
  dtx_data   <= tr_d when grant = SRC_RESP else req_data;
  dtx_last   <= tr_l when grant = SRC_RESP else req_last;
  tlep_ready <= dll_ready when grant = SRC_RESP else '0';
  req_ready  <= dll_ready when grant = SRC_REQ  else '0';

  tlresp_valid <= tr_v; tlresp_data <= tr_d; tlresp_start <= tr_s; tlresp_last <= tr_l;

  arb_p : process(clk)
  begin
    if rising_edge(clk) then
      if dl_rst = '1' then
        lock_src <= SRC_NONE;
      elsif dtx_valid = '1' and dll_ready = '1' then
        if dtx_last = '1' then lock_src <= SRC_NONE; else lock_src <= grant; end if;
      end if;
    end if;
  end process;

  u_dlltx : entity work.pcie_dll_tx
    generic map (MAX_TLP => MAX_TLP, REPLAY_SLOTS => 8, RB_LOG2 => 10,
                 REPLAY_TMO => REPLAY_TMO)
    port map (clk=>clk, rst=>dl_rst, link_up=>lup,
              tl_valid=>dtx_valid, tl_data=>dtx_data, tl_last=>dtx_last,
              tl_ready=>dll_ready,
              fr_valid=>d2f_valid, fr_data=>d2f_data, fr_last=>d2f_last,
              fr_start=>d2f_start, fr_abort=>d2f_abort, fr_ready=>d2f_ready,
              ak_valid=>pk_v, ak_is_nak=>pk_nak, ak_seq=>pk_seq,
              retrain_req=>retrain_dll,
              nseq_o=>open, acked_o=>open, inflight_o=>open, replays_o=>replays,
              tmo_o=>rpl_tmo, ovsz_o=>open, akerr_o=>open);

  dllp_bytes <= f_acknak_dllp(an_nak, an_seq);

  u_framer : entity work.pcie_tlp_frame
    generic map (SKP_INTERVAL => 600, BUF_BYTES => MAX_TLP + 6)
    port map (clk=>clk, rst=>dl_rst, en=>en, link_up=>lup,
              start=>d2f_start, din=>d2f_data, dvalid=>d2f_valid,
              dlast=>d2f_last, dabort=>d2f_abort, dready=>d2f_ready,
              dl_valid=>an_v, dl_data=>dllp_bytes, dl_ready=>an_rdy,
              sym=>f_sym, sym_k=>f_k, sym_com=>f_com, sym_skp=>f_skp,
              sym_byp=>f_byp, busy=>f_busy);

  -- MUX TX: training symbols unless in L0; in L0 the framer owns the lane
  process(lup, g_active, send_ts, f_busy, g_sym, g_k, g_com, g_skp, g_byp,
          f_sym, f_k, f_com, f_skp, f_byp)
  begin
    if lup='1' and (f_busy='1' or (g_active='0' and send_ts='0')) then
      tx_sym<=f_sym; tx_k<=f_k; tx_com<=f_com; tx_skp<=f_skp; tx_byp<=f_byp;
    else
      tx_sym<=g_sym; tx_k<=g_k; tx_com<=g_com; tx_skp<=g_skp; tx_byp<=g_byp;
    end if;
  end process;

  u_scrtx : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>en, din=>tx_sym, is_k=>tx_k,
              is_com=>tx_com, is_skp=>tx_skp, bypass=>tx_byp,
              dout=>pt_sym, dout_k=>pt_k, lfsr_mon=>open);

  -- ---------------- RX ----------------
  g_eb : if USE_EB generate
    -- single-clock model: recovered clock = local clock (structural hook; a
    -- real PHY connects wclk to its recovered RX clock)
    u_eb : entity work.pcie_elastic_buf
      port map (wclk=>clk, wrst=>rst, w_sym=>pr_sym, w_k=>pr_k, w_en=>en,
                rclk=>clk, rrst=>rst, r_sym=>eb_sym, r_k=>eb_k, r_en=>eb_en,
                ovf=>open, udf=>open, skp_added=>open, skp_dropped=>open);
  end generate;
  g_noeb : if not USE_EB generate
    eb_sym <= pr_sym; eb_k <= pr_k; eb_en <= en;
  end generate;

  rxcom <= '1' when (eb_k='1' and eb_sym=K_COM) else '0';
  rxskp <= '1' when (eb_k='1' and eb_sym=K_SKP) else '0';
  u_scrrx : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>eb_en, din=>eb_sym, is_k=>eb_k,
              is_com=>rxcom, is_skp=>rxskp, bypass=>'0',
              dout=>rx_sym, dout_k=>rx_k, lfsr_mon=>open);

  u_deframer : entity work.pcie_deframer
    port map (clk=>clk, rst=>rst, en=>eb_en, sym=>rx_sym, sym_k=>rx_k,
              tok=>tok, tok_data=>tok_data, tok_valid=>tok_valid,
              ts_valid=>ts_valid, ts_is_ts2=>ts_is_ts2,
              ts_link=>ts_link, ts_lane=>ts_lane, ts_nfts=>ts_nfts,
              ts_rate=>ts_rate, ts_ctl=>ts_ctl_rx,
              is_com_o=>dfr_com, is_skp_o=>dfr_skp);

  u_adapt : entity work.pcie_rx_adapt
    generic map (MAX_BYTES => MAX_TLP + 6)
    port map (clk=>clk, rst=>dl_rst, tok=>tok, tok_data=>tok_data,
              tok_valid=>tok_valid,
              out_valid=>ao_v, out_data=>ao_d, out_start=>ao_s, out_last=>ao_l,
              out_abort=>ao_a);

  u_dllrx : entity work.pcie_dll_rx
    generic map (MAX_TLP => MAX_TLP, ACKNAK_LAT => ACKNAK_LAT)
    port map (clk=>clk, rst=>dl_rst,
              in_valid=>ao_v, in_data=>ao_d, in_start=>ao_s, in_last=>ao_l,
              in_abort=>ao_a,
              f_wr=>fw_wr, f_data=>fw_data, f_last=>fw_last,
              f_commit=>fw_commit, f_rollback=>fw_rollback,
              f_ovf=>fw_ovf, f_space=>fw_space,
              an_valid=>an_v, an_is_nak=>an_nak, an_seq=>an_seq, an_ready=>an_rdy,
              good_o=>good_rx, bad_o=>bad_rx, dup_o=>open, nak_o=>nak_tx,
              nextrx_o=>open);

  u_rxbuf : entity work.pcie_rx_tlp_fifo
    generic map (LOG2_DEPTH => 9)
    port map (clk=>clk, rst=>dl_rst,
              wr_en=>fw_wr, wr_data=>fw_data, wr_last=>fw_last,
              commit=>fw_commit, rollback=>fw_rollback,
              wr_ovf=>fw_ovf, wr_space=>fw_space,
              rd_valid=>rq_v, rd_data=>rq_d, rd_start=>rq_s, rd_last=>rq_l,
              rd_ready=>rq_rdy);

  u_dllprx : entity work.pcie_dllp_rx
    port map (clk=>clk, rst=>dl_rst, tok=>tok, tok_data=>tok_data,
              tok_valid=>tok_valid,
              ak_valid=>pk_v, ak_is_nak=>pk_nak, ak_seq=>pk_seq,
              good_o=>open, bad_o=>open, other_o=>open);

  -- validated TLP stream as it is consumed by the TL (for the RC's RX FIFO)
  rxtlp_valid <= rq_v and rq_rdy;
  rxtlp_data  <= rq_d;
  rxtlp_start <= rq_s;
  rxtlp_last  <= rq_l;

  u_tlep : entity work.pcie_tl_ep
    generic map (BAR0_WORDS => 256)
    port map (clk=>clk, rst=>dl_rst,
              rx_valid=>rq_v, rx_data=>rq_d, rx_start=>rq_s, rx_last=>rq_l,
              rx_ready=>rq_rdy,
              tx_valid=>tr_v, tx_data=>tr_d,
              tx_start=>tr_s, tx_last=>tr_l, tx_ready=>tlep_ready,
              msi_trigger=>msi_trigger,
              bar0_dbg=>bar0_dbg, cfg_done=>open,
              mwr_cnt_o=>mwr_cnt, mrd_cnt_o=>mrd_cnt, ur_cnt_o=>ur_cnt);

  -- ---------------- retrain requests ----------------
  -- receiver sync loss: leaky counter of framing-error tokens while in L0
  err_p : process(clk)
  begin
    if rising_edge(clk) then
      retrain_err <= '0';
      if rst = '1' or lup = '0' then
        err_lvl <= 0; err_div <= 0;
      else
        if err_div = 1023 then err_div <= 0; else err_div <= err_div + 1; end if;
        if tok_valid = '1' and tok = RK_ERR then
          if err_lvl >= 3 then
            err_lvl <= 0; retrain_err <= '1';
          else
            err_lvl <= err_lvl + 1;
          end if;
        elsif err_div = 1023 and err_lvl > 0 then
          err_lvl <= err_lvl - 1;
        end if;
      end if;
    end if;
  end process;
  retrain_any <= retrain_dll or retrain_err;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then rtr_cnt <= (others => '0');
      elsif retrain_any = '1' then rtr_cnt <= rtr_cnt + 1; end if;
    end if;
  end process;

  -- ---------------- completion timeout tracker ----------------
  ct_p : process(clk)
    variable alloc, done : boolean;
    variable fin  : boolean;
  begin
    if rising_edge(clk) then
      cpl_tmo_i <= '0';
      if dl_rst = '1' then
        ct_used <= (others => '0'); tq_i <= 0; tq_np <= '0'; rc_i <= 0; rc_cpl <= '0';
        if rst = '1' then tmo_cnt <= (others => '0'); end if;
      else
        -- timers
        for e in 0 to CPL_ENTRIES-1 loop
          if ct_used(e) = '1' then
            if ct_tmr(e) >= CPL_TMO_C - 1 then
              ct_used(e) <= '0'; cpl_tmo_i <= '1'; tmo_cnt <= tmo_cnt + 1;
            else
              ct_tmr(e) <= ct_tmr(e) + 1;
            end if;
          end if;
        end loop;

        -- outgoing requests on req_*: byte 0 (type) and byte 6 (tag)
        if grant = SRC_REQ and req_valid = '1' and dll_ready = '1' then
          if tq_i = 0 then
            if is_np(req_data) then tq_np <= '1'; else tq_np <= '0'; end if;
          end if;
          if tq_i = 6 then tq_tag <= req_data; end if;
          if req_last = '1' then
            tq_i <= 0;
            alloc := tq_np = '1' or (tq_i = 0 and is_np(req_data));
            if alloc then
              for e in 0 to CPL_ENTRIES-1 loop
                if ct_used(e) = '0' and alloc then
                  ct_used(e) <= '1'; ct_tmr(e) <= 0;
                  if tq_i = 6 then ct_tag(e) <= req_data; else ct_tag(e) <= tq_tag; end if;
                  alloc := false;
                end if;
              end loop;
            end if;
          elsif tq_i < 15 then
            tq_i <= tq_i + 1;
          end if;
        end if;

        -- received completions (validated stream): bytes 0, 2-3, 6-7, 10
        if rq_v = '1' and rq_rdy = '1' then
          if rq_s = '1' then
            rc_i <= 1; rc_hd <= rq_d;
          else
            if rc_i < 15 then rc_i <= rc_i + 1; end if;
            case rc_i is
              when 2 => rc_len(9 downto 8) <= unsigned(rq_d(1 downto 0));
              when 3 => rc_len(7 downto 0) <= unsigned(rq_d);
              when 6 => rc_bc(11 downto 8) <= unsigned(rq_d(3 downto 0));
              when 7 => rc_bc(7 downto 0) <= unsigned(rq_d);
              when 10 => rc_tag <= rq_d;
              when others => null;
            end case;
          end if;
          -- the header is complete at byte 11; decide when the TLP ends
          if rq_l = '1' and rc_i >= 11 and (rc_hd = B0_CPL or rc_hd = B0_CPLD) then
            -- final completion: Cpl without data, or Byte Count fits in this one
            fin := rc_hd = B0_CPL or
                   (to_integer(rc_bc) <= 4 * to_integer(rc_len)) or rc_bc = 0;
            if fin then
              for e in 0 to CPL_ENTRIES-1 loop
                if ct_used(e) = '1' and ct_tag(e) = rc_tag then
                  ct_used(e) <= '0';
                end if;
              end loop;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;
