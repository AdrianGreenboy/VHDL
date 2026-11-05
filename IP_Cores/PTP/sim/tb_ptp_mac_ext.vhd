-- tb_ptp_mac_ext.vhd - ptp_mac over a REAL MII (external PHY mode)
-- ---------------------------------------------------------------------------
-- Audit 2026-11. Self-checking. The TB is the PHY + the link partner:
-- asynchronous TX_CLK (25 MHz -100 ppm, gateable) / RX_CLK (25 MHz +100 ppm)
-- vs the 100 MHz core; it decodes every frame the DUT puts on TXD (FCS
-- checked) and crafts gPTP frames (with FCS) on RXD.
--   A 1-step Sync in external-PHY mode: originTimestamp inside the frame vs
--     the DUT clock at the wire SFD instant -> constant offset (TX path
--     latency), spread <= 2 core clocks over several Syncs.
--   B lost responses: 4 Pdelay_Req without answer -> 4 pd timeouts /
--     resp_lost, initiator never stuck, asCapable drops after the 4th
--     (allowedLostResponses = 3).
--   C Resp matching end-to-end: a Resp with a wrong sequenceId is ignored
--     (ev_resp_mismatch, no mpd); the matching one gives
--     mpd = ((t4 - t1) - corr) / 2 within 20 ns of the TB's wire-based
--     expectation; lostResponses cleared, asCapable back to 1.
--   D slave Sync offset honours correctionField: two Syncs with
--     correctionField 0 and 7000 ns: offset_ns within 25 ns of
--     t_rx - origin - corr - mpd (v1 ignored corr -> 7000 ns error).
--   E TX timestamp timeout + recovery: TX_CLK stopped -> Sync never reaches
--     the wire -> ev_ts_timeout, frame aborted; TX_CLK restarted -> next Sync
--     is clean (valid FCS, correct 1-step timestamp), no stale frame.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity tb_ptp_mac_ext is
end entity;

architecture sim of tb_ptp_mac_ext is
  constant TCK : time := 10 ns;
  constant TTX : time := 40004 ps;
  constant TRX : time := 39996 ps;
  constant TMO : integer := 5000;           -- 50 us
  constant MYCLK : std_logic_vector(63 downto 0) := x"0011223344556677";
  constant MYPORT : std_logic_vector(15 downto 0) := x"0001";
  constant PEERCLK : std_logic_vector(63 downto 0) := x"AABBCCDDEEFF0011";

  signal clk, txc_raw, rxc : std_logic := '0';
  signal txc_en : std_logic := '1';
  signal txc : std_logic;
  signal rst : std_logic := '1';
  signal role_slave, send_sync, start_pd : std_logic := '0';
  signal now_sec : std_logic_vector(SEC_W-1 downto 0);
  signal now_ns  : std_logic_vector(NS_W-1 downto 0);
  signal mpd_ns  : std_logic_vector(63 downto 0);
  signal mpd_valid, offset_valid : std_logic;
  signal offset_ns : std_logic_vector(ERR_W-1 downto 0);
  signal mii_txd, mii_rxd : std_logic_vector(3 downto 0) := (others => '0');
  signal mii_tx_en, mii_rx_dv : std_logic := '0';
  signal ev_pd_tmo, ev_ts_tmo, ev_lost, ev_mism, ev_ovs, ev_phy : std_logic;
  signal lost_cnt : unsigned(7 downto 0);
  signal as_cap : std_logic;

  -- monitor results
  signal n_txf : integer := 0;
  signal f_type : std_logic_vector(3 downto 0);
  signal f_seq : std_logic_vector(15 downto 0);
  signal f_orig_ns : integer := 0;
  signal f_now_wire : integer := 0;
  signal f_len : integer := 0;
  -- event counters
  signal n_pdtmo, n_tstmo, n_lost, n_mism, n_mpd, n_off, n_phy : integer := 0;
  signal last_off : integer := 0;
  signal rx_now_wire : integer := 0;

  function crc_upd(c : std_logic_vector(31 downto 0); b : std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable v : std_logic_vector(31 downto 0) := c;
  begin
    for k in 0 to 7 loop
      if (v(0) xor b(k)) = '1' then v := ('0' & v(31 downto 1)) xor x"EDB88320";
      else v := '0' & v(31 downto 1); end if;
    end loop;
    return v;
  end function;
  function nsint(v : std_logic_vector(NS_W-1 downto 0)) return integer is
  begin
    return to_integer(unsigned(v(30 downto 0)));
  end function;
begin
  clk <= not clk after TCK / 2;
  txc_raw <= not txc_raw after TTX / 2;
  rxc <= not rxc after TRX / 2;
  txc <= txc_raw and txc_en;

  dut : entity work.ptp_mac
    port map (clk => clk, rst => rst, enable => '1', loopback => '0',
      role_slave => role_slave, clock_id => MYCLK, port_num => MYPORT,
      src_mac => x"02DECAFBADED", macaddr => x"0E0000C28001",
      kp => x"0000", ki => x"0000", tx_lat => x"0000", rx_lat => x"0000",
      send_sync => send_sync, start_pdelay => start_pd,
      tmo_cycles => to_unsigned(TMO, 32), allowed_lost => to_unsigned(3, 8), chk_resp => '1',
      ev_pd_timeout => ev_pd_tmo, ev_ts_timeout => ev_ts_tmo, ev_resp_lost => ev_lost,
      ev_resp_mismatch => ev_mism, ev_rx_oversize => ev_ovs, ev_phy_err => ev_phy,
      pd_lost_cnt => lost_cnt, pd_as_capable => as_cap,
      now_sec => now_sec, now_ns => now_ns, mpd_ns => mpd_ns, mpd_valid => mpd_valid,
      offset_valid_o => offset_valid, rx_sync_ev => open, rx_resp_ev => open,
      offset_ns => offset_ns, rate_adj => open,
      dbg_rx_mvalid => open, dbg_rx_mtype => open, dbg_rx_seqid => open,
      dbg_t1_ns => open, dbg_t4_ns => open, dbg_pd_corr => open, dbg_pd_calc => open,
      mii_rx_clk => rxc, mii_tx_clk => txc,
      mii_txd => mii_txd, mii_tx_en => mii_tx_en, mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv,
      dbg_state => open, dbg_rxdst => open, dbg_rxinfo => open, dbg_fptr => open, dbg_ftx => open);

  p_ev : process(clk)
  begin
    if rising_edge(clk) then
      if ev_pd_tmo = '1' then n_pdtmo <= n_pdtmo + 1; end if;
      if ev_ts_tmo = '1' then n_tstmo <= n_tstmo + 1; end if;
      if ev_lost = '1' then n_lost <= n_lost + 1; end if;
      if ev_mism = '1' then n_mism <= n_mism + 1; end if;
      if mpd_valid = '1' then n_mpd <= n_mpd + 1; end if;
      if offset_valid = '1' then
        n_off <= n_off + 1; last_off <= to_integer(signed(offset_ns));
      end if;
      if ev_phy = '1' then n_phy <= n_phy + 1; end if;
    end if;
  end process;

  -- -------------------------------------------- TX monitor (PHY, TX_CLK)
  p_mon : process
    variable inframe, pre : boolean := false;
    variable npre, nib, nb : integer := 0;
    variable lo : std_logic_vector(3 downto 0);
    type buf_t is array (0 to 2047) of std_logic_vector(7 downto 0);
    variable buf : buf_t;
    variable crc : std_logic_vector(31 downto 0);
    variable nw : integer;
    variable o : unsigned(31 downto 0);
  begin
    wait until rising_edge(txc);
    if mii_tx_en = '1' then
      if not inframe and not pre then
        assert mii_txd = x"5" report "MON: frame does not start with preamble" severity failure;
        pre := true; npre := 1;
      elsif pre then
        if mii_txd = x"5" then npre := npre + 1;
        else
          assert mii_txd = x"D" and npre = 15 report "MON: bad preamble/SFD" severity failure;
          -- wire SFD launched one TX_CLK before this edge (10 ns quantization)
          nw := nsint(now_ns) - 40;
          pre := false; inframe := true; nib := 0; nb := 0;
        end if;
      else
        if nib = 0 then lo := mii_txd; nib := 1;
        else buf(nb) := mii_txd & lo; nb := nb + 1; nib := 0; end if;
      end if;
    else
      assert not pre report "MON: TX_EN dropped in preamble" severity failure;
      if inframe then
        assert nib = 0 report "MON: odd nibble count" severity failure;
        crc := x"FFFFFFFF";
        for i in 0 to nb - 1 loop crc := crc_upd(crc, buf(i)); end loop;
        assert crc = x"DEBB20E3" report "MON: bad FCS on a DUT frame" severity failure;
        assert buf(12) = x"88" and buf(13) = x"F7" report "MON: not gPTP" severity failure;
        o := unsigned(std_logic_vector'(buf(54) & buf(55) & buf(56) & buf(57)));
        f_type <= buf(14)(3 downto 0);
        f_seq  <= buf(44) & buf(45);
        f_orig_ns <= to_integer(o(30 downto 0));
        f_now_wire <= nw;
        f_len <= nb;
        n_txf <= n_txf + 1;
      end if;
      inframe := false;
    end if;
  end process;

  -- -------------------------------------------- stimulus / link partner
  stim : process
    variable frm : byte_arr(0 to 67);
    variable crc, fcs : std_logic_vector(31 downto 0);
    variable k0, d, mn, mx, s0, exp_i, t1w, t4w : integer;
    variable seq : std_logic_vector(15 downto 0);
    variable c64 : signed(63 downto 0);
    variable ln : integer;
    variable mpd_i : integer;

    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure waitc(n : integer) is begin for i in 1 to n loop step; end loop; end procedure;
    procedure pulse(signal s : out std_logic) is begin s <= '1'; step; s <= '0'; end procedure;
    procedure wait_txf(n : integer) is
      variable g : integer := 0;
    begin
      while n_txf < n loop
        step; g := g + 1;
        assert g < 200000 report "TB: expected DUT frame never appeared" severity failure;
      end loop;
    end procedure;
    procedure nibr(n : std_logic_vector(3 downto 0); v : std_logic) is
    begin
      wait until falling_edge(rxc);
      mii_rxd <= n; mii_rx_dv <= v;
    end procedure;
    -- send frm(0 to ln-1) + padding to 60 + FCS on RXD; rx_now_wire = DUT
    -- clock when the MAC samples the SFD nibble
    procedure send_rx(ln : integer) is
      variable b : std_logic_vector(7 downto 0);
      variable L : integer := ln;
    begin
      if L < 60 then L := 60; end if;
      for i in 1 to 15 loop nibr(x"5", '1'); end loop;
      nibr(x"D", '1');
      wait until rising_edge(rxc);
      rx_now_wire <= nsint(now_ns);
      crc := x"FFFFFFFF";
      for i in 0 to L - 1 loop
        if i < ln then b := frm(i); else b := x"00"; end if;
        crc := crc_upd(crc, b);
        nibr(b(3 downto 0), '1'); nibr(b(7 downto 4), '1');
      end loop;
      fcs := not crc;
      for i in 0 to 7 loop nibr(fcs(i*4+3 downto i*4), '1'); end loop;
      for i in 1 to 24 loop nibr(x"0", '0'); end loop;
    end procedure;
    procedure mk(tpl : byte_arr; seqv : std_logic_vector(15 downto 0);
                 corr : signed(63 downto 0)) is
    begin
      frm := (others => x"00");
      frm(tpl'range) := tpl;
      frm(6 to 11) := (x"02", x"00", x"00", x"00", x"00", x"99");
      for i in 0 to 7 loop frm(22 + i) := std_logic_vector(corr((7-i)*8+7 downto (7-i)*8)); end loop;
      for i in 0 to 7 loop frm(34 + i) := PEERCLK((7-i)*8+7 downto (7-i)*8); end loop;
      frm(42) := x"00"; frm(43) := x"02";
      frm(44) := seqv(15 downto 8); frm(45) := seqv(7 downto 0);
    end procedure;
    procedure set_ts48(off : integer; ns : integer) is   -- sec = 0, ns 32b BE
      variable u : unsigned(31 downto 0) := to_unsigned(ns, 32);
    begin
      for i in 0 to 5 loop frm(off + i) := x"00"; end loop;
      for i in 0 to 3 loop frm(off + 6 + i) := std_logic_vector(u((3-i)*8+7 downto (3-i)*8)); end loop;
    end procedure;
  begin
    rst <= '1'; waitc(5); rst <= '0';
    waitc(300);                                       -- PHY domains out of reset

    -- ================= A: 1-step Sync timestamps in external-PHY mode
    mn := integer'high; mx := integer'low;
    for k in 1 to 4 loop
      k0 := n_txf;
      pulse(send_sync);
      wait_txf(k0 + 1);
      assert f_type = x"0" and f_len = 64 report "A: expected a 60+4 byte Sync" severity failure;
      d := f_orig_ns - f_now_wire;
      if d < mn then mn := d; end if;
      if d > mx then mx := d; end if;
      waitc(2000);
    end loop;
    report "A: originTimestamp - wire-SFD clock = [" & integer'image(mn) & ", " &
           integer'image(mx) & "] ns";
    assert mn >= 0 and mx <= 60 report "A: 1-step timestamp far from the wire SFD" severity failure;
    assert mx - mn <= 20 report "A: 1-step timestamp jitter > 2 core clocks" severity failure;

    -- ================= B: four Pdelay_Req without answer
    for k in 1 to 4 loop
      s0 := n_lost;
      k0 := n_txf;
      pulse(start_pd);
      wait_txf(k0 + 1);
      assert f_type = x"2" report "B: expected a Pdelay_Req" severity failure;
      d := 0;
      while n_lost = s0 loop
        step; d := d + 1;
        assert d < 4 * TMO report "B: initiator stuck waiting for a Resp" severity failure;
      end loop;
    end loop;
    waitc(5);
    assert to_integer(lost_cnt) = 4 and as_cap = '0'
      report "B: lostResponses/asCapable wrong" severity failure;

    -- ================= C: wrong-seq Resp ignored, matching Resp accepted
    k0 := n_txf;
    pulse(start_pd);
    wait_txf(k0 + 1);
    assert f_type = x"2" report "C: expected a Pdelay_Req" severity failure;
    seq := f_seq; t1w := f_now_wire;
    c64 := shift_left(to_signed(10000, 64), 16);       -- residence 10 us
    mk(TPL_RESP_ROM, std_logic_vector(unsigned(seq) + 1), shift_left(to_signed(777777, 64), 16));
    set_ts48(48, 1234);
    for i in 0 to 7 loop frm(58 + i) := MYCLK((7-i)*8+7 downto (7-i)*8); end loop;
    frm(66) := MYPORT(15 downto 8); frm(67) := MYPORT(7 downto 0);
    s0 := n_mpd;
    send_rx(68);
    waitc(300);
    assert n_mism >= 1 report "C: wrong-seq Resp not reported as mismatch" severity failure;
    assert n_mpd = s0 report "C: wrong-seq Resp was used for meanPathDelay" severity failure;
    mk(TPL_RESP_ROM, seq, c64);
    set_ts48(48, 1234);
    for i in 0 to 7 loop frm(58 + i) := MYCLK((7-i)*8+7 downto (7-i)*8); end loop;
    frm(66) := MYPORT(15 downto 8); frm(67) := MYPORT(7 downto 0);
    send_rx(68);
    t4w := rx_now_wire;
    waitc(300);
    assert n_mpd = s0 + 1 report "C: matching Resp not accepted" severity failure;
    mpd_i := to_integer(signed(mpd_ns(31 downto 0)));
    -- TX path ~25 ns, RX path ~85 ns: ((t4w+85) - (t1w+25) - 10000) / 2
    exp_i := ((t4w - t1w) - 10000 + 60) / 2;
    report "C: mpd = " & integer'image(mpd_i) & " ns, wire-based expectation " &
           integer'image(exp_i) & " ns";
    assert abs (mpd_i - exp_i) <= 20 report "C: meanPathDelay inconsistent" severity failure;
    assert lost_cnt = 0 and as_cap = '1' report "C: lostResponses not cleared" severity failure;

    -- ================= D: slave Sync with correctionField 0 and 7000 ns
    role_slave <= '1';
    for k in 0 to 1 loop
      s0 := n_off;
      mk(TPL_SYNC_ROM, std_logic_vector(to_unsigned(100 + k, 16)),
         shift_left(to_signed(k * 7000, 64), 16));
      set_ts48(48, nsint(now_ns) + 3000);             -- origin 3 us ahead of us
      ln := 58;
      d := nsint(now_ns) + 3000;
      send_rx(ln);
      waitc(300);
      assert n_off = s0 + 1 report "D: Sync not processed exactly once" severity failure;
      exp_i := (rx_now_wire + 85) - d - k * 7000 - mpd_i;
      report "D: corr=" & integer'image(k * 7000) & " offset=" & integer'image(last_off) &
             " expected~" & integer'image(exp_i);
      assert abs (last_off - exp_i) <= 25
        report "D: slave offset ignores correctionField" severity failure;
    end loop;
    role_slave <= '0';

    -- ================= E: TX_CLK stopped -> TS timeout, abort, recovery
    wait until falling_edge(txc_raw); txc_en <= '0';
    s0 := n_tstmo;
    k0 := n_txf;
    pulse(send_sync);
    d := 0;
    while n_tstmo = s0 loop
      step; d := d + 1;
      assert d < 4 * TMO report "E: no TX timestamp timeout" severity failure;
    end loop;
    waitc(100);
    wait until falling_edge(txc_raw); txc_en <= '1';
    waitc(3000);
    assert n_txf = k0 report "E: the aborted frame leaked onto the wire" severity failure;
    pulse(send_sync);
    wait_txf(k0 + 1);
    d := f_orig_ns - f_now_wire;
    assert f_type = x"0" and d >= mn - 10 and d <= mx + 10
      report "E: Sync after recovery has a wrong 1-step timestamp (" & integer'image(d) & ")"
      severity failure;
    waitc(2000);
    assert n_phy = 0 report "CDC error reported" severity failure;

    report "TB_PTP_MAC_EXT PASS (real MII: 1-step TS, lostResponses, Resp match, corr, TS timeout)";
    finish;
  end process;

  wd : process
  begin
    wait for 5 ms;
    assert false report "TB_PTP_MAC_EXT: timeout" severity failure;
    wait;
  end process;
end architecture;
