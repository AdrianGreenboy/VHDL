-- tb_ptp_pdelay_tmo.vhd - ptp_pdelay_fsm timeouts, lostResponses, Resp matching
-- ---------------------------------------------------------------------------
-- Audit 2026-11 (ALTA ptp_pdelay_fsm.vhd:174-182, R_WAIT_DONE; MEDIA :176).
-- Unit test, the TB plays ptp_tx and ptp_rx. Self-checking.
--   T1 I_WAIT_RESP: no Resp -> pd_timeout + resp_lost, busy drops, lost_cnt++
--      (v1: busy stuck at '1' forever -> deadlock, test times out)
--   T2 allowedLostResponses = 3: after 4 consecutive losses as_capable = '0'
--   T3 Resp with wrong sequenceId, then wrong requestingPortIdentity: both
--      ignored (resp_mismatch), still waiting; the matching Resp is accepted,
--      pd_calc fires with ITS t4/corr, lost_cnt cleared, as_capable = '1'
--      (v1 accepted the first Resp of any seq / port)
--   T4 I_SEND_REQ: TX engine never free -> timeout, busy drops
--   T5 I_WAIT_REQ_DONE: tx_done never comes -> timeout
--   T6 R_SEND_RESP: Req received, engine never free -> timeout, back to idle
--   T7 R_WAIT_DONE: Resp sent, tx_done never comes -> timeout, back to idle
--      and the next Req is answered again (v1: responder deaf forever)
--   T8 the Resp is sent with the Req sequenceId (tx_req_seqid)
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity tb_ptp_pdelay_tmo is
end entity;

architecture sim of tb_ptp_pdelay_tmo is
  constant TCK : time := 10 ns;
  constant TMO : integer := 500;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal start, busy : std_logic := '0';
  signal rx_mvalid : std_logic := '0';
  signal rx_mtype : std_logic_vector(3 downto 0) := (others => '0');
  signal rx_seqid : std_logic_vector(15 downto 0) := (others => '0');
  signal rx_spid, rx_reqpid : std_logic_vector(79 downto 0) := (others => '0');
  signal rx_corr : std_logic_vector(63 downto 0) := (others => '0');
  signal rx_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal rx_ns : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal rx_ack, tx_send : std_logic;
  signal tx_sel : msg_sel_t;
  signal tx_req_seqid : std_logic_vector(15 downto 0);
  signal tx_busy, tx_done : std_logic := '0';
  signal tx_ready : std_logic := '1';
  signal tx_seq : std_logic_vector(15 downto 0) := x"0000";
  signal tx_ts_valid : std_logic := '0';
  signal pd_calc, pd_tmo, lost_p, mism_p, asc : std_logic;
  signal lost_cnt : unsigned(7 downto 0);
  signal pd_t4_ns : std_logic_vector(NS_W-1 downto 0);
  signal pd_corr : std_logic_vector(63 downto 0);
  signal n_tmo, n_lost, n_mism, n_calc, n_send : integer := 0;
  signal last_sel : msg_sel_t := SEL_SYNC;
  signal last_rseq : std_logic_vector(15 downto 0) := (others => '0');
  constant MYPID : std_logic_vector(79 downto 0) := x"0011223344556677" & x"0001";
begin
  clk <= not clk after TCK / 2;

  dut : entity work.ptp_pdelay_fsm
    port map (clk => clk, rst => rst, start => start, busy => busy,
      rx_mvalid => rx_mvalid, rx_mtype => rx_mtype, rx_seqid => rx_seqid,
      rx_spid => rx_spid, rx_reqpid => rx_reqpid, rx_corr => rx_corr,
      rx_sec => rx_sec, rx_ns => rx_ns, rx_ack => rx_ack,
      tx_send => tx_send, tx_sel => tx_sel,
      tx_req_rx_sec => open, tx_req_rx_ns => open, tx_req_portid => open,
      tx_req_seqid => tx_req_seqid,
      tx_busy => tx_busy, tx_done => tx_done, tx_ready => tx_ready, tx_seq => tx_seq,
      tx_ts_sec => (others => '0'), tx_ts_ns => (others => '0'), tx_ts_valid => tx_ts_valid,
      my_portid => MYPID, chk_resp => '1',
      tmo_cycles => to_unsigned(TMO, 32), allowed_lost => to_unsigned(3, 8),
      pd_calc => pd_calc, pd_t1_sec => open, pd_t1_ns => open,
      pd_t4_sec => open, pd_t4_ns => pd_t4_ns, pd_corr => pd_corr,
      pd_timeout => pd_tmo, resp_lost => lost_p, resp_mismatch => mism_p,
      lost_cnt => lost_cnt, as_capable => asc, dbg_ist => open, dbg_rstt => open);

  p_cnt : process(clk)
  begin
    if rising_edge(clk) then
      if pd_tmo = '1' then n_tmo <= n_tmo + 1; end if;
      if lost_p = '1' then n_lost <= n_lost + 1; end if;
      if mism_p = '1' then n_mism <= n_mism + 1; end if;
      if pd_calc = '1' then n_calc <= n_calc + 1; end if;
      if tx_send = '1' then
        n_send <= n_send + 1; last_sel <= tx_sel; last_rseq <= tx_req_seqid;
      end if;
    end if;
  end process;

  -- parser model: sticky msg_valid cleared by rx_ack
  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure waitc(n : integer) is begin for i in 1 to n loop step; end loop; end procedure;
    procedure msg(t : std_logic_vector(3 downto 0); seq : std_logic_vector(15 downto 0);
                  rpid : std_logic_vector(79 downto 0); t4 : integer; corr : integer) is
    begin
      rx_mtype <= t; rx_seqid <= seq; rx_reqpid <= rpid; rx_spid <= MYPID;
      rx_ns <= std_logic_vector(to_unsigned(t4, NS_W));
      rx_corr <= std_logic_vector(shift_left(to_signed(corr, 64), 16));
      rx_mvalid <= '1';
      loop step; exit when rx_ack = '1'; end loop;
      rx_mvalid <= '0';
      step;
    end procedure;
    -- the TB plays ptp_tx for one Req: busy, then done; tx_seq = seq
    procedure req_sent(seq : std_logic_vector(15 downto 0)) is
    begin
      loop step; exit when tx_send = '1'; end loop;
      assert tx_sel = SEL_PDELAY_REQ report "expected a Pdelay_Req" severity failure;
      tx_busy <= '1'; tx_seq <= seq; waitc(5);
      tx_ts_valid <= '1'; step; tx_ts_valid <= '0';
      tx_busy <= '0'; tx_done <= '1'; step; tx_done <= '0';
    end procedure;
    variable t0, s0 : integer;
  begin
    rst <= '1'; waitc(3); rst <= '0'; waitc(2);

    -- T1 + T2: four lost responses
    for k in 1 to 4 loop
      start <= '1'; step; start <= '0';
      req_sent(std_logic_vector(to_unsigned(k, 16)));
      t0 := 0;
      loop
        step; t0 := t0 + 1;
        exit when busy = '0';
        assert t0 < 10 * TMO report "T1: initiator never timed out (deadlock)" severity failure;
      end loop;
      step;
      assert to_integer(lost_cnt) = k
        report "T1: lost_cnt=" & integer'image(to_integer(lost_cnt)) severity failure;
      if k <= 3 then
        assert asc = '1' report "T2: as_capable dropped too early" severity failure;
      else
        assert asc = '0' report "T2: as_capable still 1 after 4 losses" severity failure;
      end if;
    end loop;
    assert n_lost = 4 and n_tmo = 4 report "T1: wrong timeout/lost pulse count" severity failure;

    -- T3: wrong seq, wrong port, then matching Resp
    start <= '1'; step; start <= '0';
    req_sent(x"0042");
    waitc(10);
    msg(MT_PDELAY_RESP, x"0041", MYPID, 1111, 77);                  -- wrong seq
    msg(MT_PDELAY_RESP, x"0042", x"00112233445566770002", 2222, 88);  -- wrong port
    assert busy = '1' and n_calc = 0
      report "T3: a non-matching Pdelay_Resp was accepted" severity failure;
    assert n_mism = 2 report "T3: resp_mismatch not reported twice" severity failure;
    msg(MT_PDELAY_RESP, x"0042", MYPID, 3333, 99);                  -- matching
    waitc(3);
    assert n_calc = 1 report "T3: matching Resp not accepted" severity failure;
    assert to_integer(unsigned(pd_t4_ns)) = 3333 and
           to_integer(shift_right(signed(pd_corr), 16)) = 99
      report "T3: t4/corr not taken from the matching Resp" severity failure;
    assert lost_cnt = 0 and asc = '1' report "T3: lostResponses not cleared" severity failure;

    -- T4: engine never free in I_SEND_REQ
    tx_busy <= '1';
    start <= '1'; step; start <= '0';
    t0 := n_tmo;
    loop step; exit when busy = '0'; end loop;
    waitc(2);
    assert n_tmo = t0 + 1 report "T4: no timeout in I_SEND_REQ" severity failure;
    tx_busy <= '0'; waitc(3);

    -- T5: tx_done never comes
    start <= '1'; step; start <= '0';
    loop step; exit when tx_send = '1'; end loop;
    tx_busy <= '1';
    t0 := n_tmo;
    loop step; exit when busy = '0'; end loop;
    waitc(2);
    assert n_tmo = t0 + 1 report "T5: no timeout in I_WAIT_REQ_DONE" severity failure;
    tx_busy <= '0'; waitc(3);

    -- T6: Req received while the engine is never free
    tx_busy <= '1';
    t0 := n_tmo;
    msg(MT_PDELAY_REQ, x"0777", MYPID, 10, 0);
    waitc(2 * TMO);
    assert n_tmo = t0 + 1 report "T6: no timeout in R_SEND_RESP" severity failure;
    tx_busy <= '0'; waitc(3);

    -- T7: Resp sent, tx_done never comes; then the responder must answer again
    s0 := n_send;
    msg(MT_PDELAY_REQ, x"0888", MYPID, 10, 0);
    loop step; exit when n_send > s0; end loop;
    assert last_sel = SEL_PDELAY_RESP report "T7: expected a Pdelay_Resp" severity failure;
    assert last_rseq = x"0888" report "T8: Resp does not carry the Req sequenceId" severity failure;
    t0 := n_tmo;
    waitc(2 * TMO);
    assert n_tmo = t0 + 1 report "T7: no timeout in R_WAIT_DONE" severity failure;
    s0 := n_send;
    msg(MT_PDELAY_REQ, x"0999", MYPID, 10, 0);
    t0 := 0;
    loop
      step; t0 := t0 + 1;
      exit when n_send > s0;
      assert t0 < 50 report "T7: responder deaf after R_WAIT_DONE timeout" severity failure;
    end loop;
    tx_done <= '1'; step; tx_done <= '0';

    report "TB_PTP_PDELAY_TMO PASS (all wait states bounded, lostResponses, Resp matching)";
    finish;
  end process;

  wd : process
  begin
    wait for 1 ms;
    assert false report "TB_PTP_PDELAY_TMO: timeout (deadlock)" severity failure;
    wait;
  end process;
end architecture;
