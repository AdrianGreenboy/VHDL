-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- tb_eth21_flow: IEEE 802.3x PAUSE through the MAC_10G paths (audit 2026-11)
--   eth21_txpath -> wire (GT bit order 0/0, aligned) -> eth21_rxpath, the
--   PAUSE value and the RX FIFO XOFF cross with mac25g_hsync / mac25g_lsync
--   exactly as in eth21_top. Continuous 1514-byte UDP traffic.
--   A  consumer stalled 60k cycles: XOFF sent + honoured, no data frame
--      sent while paused, no RX FIFO drop
--   B  consumer released: XON, traffic resumes, every frame checked good
--      and in sequence
--   C  honour off + stalled consumer: drops (negative control)
-- Prints TB_ETH21_FLOW_PASS / _FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tb_eth21_pkg.all;

entity tb_eth21_flow is end entity;

architecture sim of tb_eth21_flow is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal fin : boolean := false;
  signal start, honor, auto, rxr, restart : std_logic := '0';
  signal txd : std_logic_vector(63 downto 0);
  signal txh : std_logic_vector(1 downto 0);
  signal tcnt : std_logic_vector(4*32-1 downto 0);
  signal tcnt2, rcnt2 : std_logic_vector(4*32-1 downto 0);
  signal rcnt : std_logic_vector(19*32-1 downto 0);
  signal x_pstb, t_pstb, x_xoff, t_xoff, paused, lock : std_logic;
  signal x_pq, t_pq : std_logic_vector(15 downto 0);

  function ti(v : std_logic_vector; i : natural) return integer is
  begin
    return to_integer(unsigned(v(32*i+30 downto 32*i)));
  end function;
begin
  clk <= not clk after 3200 ps when not fin;          -- 156.25 MHz

  u_tx: entity work.eth21_txpath
    port map (clk=>clk, rst=>rst, mac_en=>'1', gen_cont=>'1', bit_rev=>'0', hdr_swap=>'0',
              peer_mac=>T_PEER_MAC, own_mac=>T_OWN_MAC, own_ip=>T_OWN_IP,
              peer_ip=>T_PEER_IP, sport=>T_SPORT, dport=>T_DPORT,
              len_min=>to_unsigned(1472, 11), len_max=>to_unsigned(1472, 11),
              len_step=>to_unsigned(0, 11), gen_count=>to_unsigned(0, 32),
              gen_gap=>to_unsigned(0, 16),
              gen_start=>start, gen_stop=>'0', cnt_clear=>'0', inj=>'0',
              st_busy=>open, st_done=>open, st_tx_act=>open,
              txdata=>txd, txheader=>txh, cnt_flat=>tcnt,
              pause_honor=>honor, pause_auto=>auto, pause_quanta=>x"0100",
              pause_sw_req=>'0', pause_sw_q=>x"0000",
              rx_pause_stb=>t_pstb, rx_pause_q=>t_pq, rx_xoff=>t_xoff,
              st_paused=>paused, cnt2_flat=>tcnt2);

  u_rx: entity work.eth21_rxpath
    generic map (SLIP_WAIT => 16)
    port map (clk=>clk, rst=>rst, promisc=>'1', bit_rev=>'0', hdr_swap=>'0',
              own_mac=>T_OWN_MAC, peer_mac=>T_PEER_MAC, own_ip=>T_OWN_IP,
              peer_ip=>T_PEER_IP, sport=>T_SPORT, dport=>T_DPORT,
              chk_restart=>restart, cnt_clear=>'0',
              rxdata=>txd, rxheader=>txh, rxvalid=>'1', rxslip=>open,
              st_lock=>lock, st_link=>open, st_rx_act=>open,
              ev_crc=>open, ev_chkerr=>open, cnt_flat=>rcnt,
              rx_tready=>rxr, rx_hi_wm=>to_unsigned(384, 16), rx_lo_wm=>to_unsigned(128, 16),
              pause_stb=>x_pstb, pause_q=>x_pq, xoff=>x_xoff, cnt2_flat=>rcnt2);

  u_hs: entity work.mac25g_hsync generic map (W => 16)
    port map (clk_src=>clk, rst_src=>rst, stb_in=>x_pstb, d_in=>x_pq,
              clk_dst=>clk, rst_dst=>rst, stb_out=>t_pstb, d_out=>t_pq);
  u_ls: entity work.mac25g_lsync port map (clk_dst=>clk, d=>x_xoff, q=>t_xoff);

  process
    variable ok : boolean := true;
    variable d0, d1, c0, c1, i : natural;
    procedure tick(k : natural) is
    begin
      for j in 1 to k loop wait until rising_edge(clk); end loop;
    end procedure;
    procedure fail(m : string) is
    begin
      report "TB_ETH21_FLOW_FAIL " & m severity error; ok := false;
    end procedure;
  begin
    tick(5); rst <= '0';
    honor <= '1'; auto <= '1'; rxr <= '1';
    i := 0;
    while lock = '0' and i < 5000 loop tick(1); i := i + 1; end loop;
    if lock = '0' then fail("no block lock"); end if;
    tick(100);
    restart <= '1'; tick(1); restart <= '0';
    start <= '1'; tick(1); start <= '0';
    tick(20000);
    if ti(rcnt, 8) < 10 then fail("no traffic"); end if;

    -- A
    rxr <= '0';
    tick(20000);
    d0 := ti(tcnt, 0) - ti(tcnt2, 0);
    tick(60000);
    d1 := ti(tcnt, 0) - ti(tcnt2, 0);
    if ti(tcnt2, 0) = 0 then fail("A: no PAUSE sent"); end if;
    if ti(tcnt2, 1) = 0 then fail("A: no PAUSE honoured"); end if;
    if d1 /= d0 then fail("A: data frames sent while paused"); end if;
    if ti(rcnt2, 2) /= 0 then fail("A: RX FIFO drops with flow control"); end if;
    if paused /= '1' then fail("A: not paused"); end if;
    report "A: TX_PAUSE=" & integer'image(ti(tcnt2, 0)) & " RX_PAUSE=" &
           integer'image(ti(rcnt2, 0)) & " RX_FIFO_MAX=" & integer'image(ti(rcnt2, 3));

    -- B
    c0 := ti(rcnt, 8);
    rxr <= '1';
    tick(40000);
    c1 := ti(rcnt, 8);
    if paused /= '0' then fail("B: still paused"); end if;
    if c1 - c0 < 30 then fail("B: traffic did not resume"); end if;
    if ti(rcnt, 9) /= 0 or ti(rcnt, 10) /= 0 or ti(rcnt, 11) /= 0 then
      fail("B: checker bad=" & integer'image(ti(rcnt, 9)) & " seq=" &
           integer'image(ti(rcnt, 10)) & " rxerr=" & integer'image(ti(rcnt, 11)));
    end if;
    if ti(tcnt, 3) /= 0 then fail("B: TX underrun"); end if;

    -- C
    honor <= '0'; rxr <= '0';
    tick(40000);
    if ti(rcnt2, 2) = 0 then fail("C: no drop without flow control"); end if;

    if ok then report "TB_ETH21_FLOW_PASS"; else report "TB_ETH21_FLOW_FAIL"; end if;
    fin <= true;
    wait;
  end process;
end architecture sim;
