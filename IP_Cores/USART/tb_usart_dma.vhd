-- =============================================================================
--  tb_usart_dma.vhd - Unit test of usart_dma for the audit 2026-11 fixes
--
--  The DUT is driven directly (no MMIO) against a TB-side AXI responder whose
--  handshakes can be stalled at will, so that abort pulses can be placed in
--  states other than the burst-decision states.
--
--  Tests:
--    D1  rx_abort pulse while the RX channel is stalled in X_AW (mid burst):
--        the request must be latched, the burst must complete cleanly
--        (B response accepted) and the channel must close with
--        rx_done + rx_aborted instead of waiting for more data forever.
--    D2  tx_abort pulse while the TX channel waits for R beats (T_BEAT):
--        same expectations on the read side (tx_done + tx_aborted).
--    D3  Full 32-bit DDR offsets: bit 31 of tx_addr / rx_addr reaches
--        araddr / awaddr (was truncated to 31 bits).
--    D4  RLAST missing on the last beat -> tx_rerr pulse, channel still
--        completes on its beat count (no hang).
--    D5  Abort pulse while idle is ignored (no stale request on next start).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_usart_dma is
end entity;

architecture sim of tb_usart_dma is
  constant AW   : natural := 40;
  constant LOG2 : natural := 4;

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal tx_addr, rx_addr : std_logic_vector(31 downto 0) := (others => '0');
  signal tx_len, rx_len   : unsigned(23 downto 0) := (others => '0');
  signal tx_start, rx_start, tx_abort, rx_abort : std_logic := '0';
  signal tx_busy, tx_done, tx_rerr, tx_aborted : std_logic;
  signal rx_busy, rx_done, rx_flushed, rx_berr, rx_aborted : std_logic;
  signal rx_count : unsigned(23 downto 0);

  signal txf_wr  : std_logic;
  signal txf_wdata : std_logic_vector(7 downto 0);
  signal rxf_rd  : std_logic;
  signal rxf_lvl : unsigned(LOG2 downto 0) := (others => '0');
  signal rxf_rdata : std_logic_vector(7 downto 0) := x"00";

  signal awaddr, araddr : std_logic_vector(AW-1 downto 0);
  signal awlen, arlen : std_logic_vector(7 downto 0);
  signal awsize, arsize : std_logic_vector(2 downto 0);
  signal awburst, arburst : std_logic_vector(1 downto 0);
  signal awvalid, awready, wvalid, wready, wlast : std_logic;
  signal wdata : std_logic_vector(31 downto 0);
  signal wstrb : std_logic_vector(3 downto 0);
  signal bvalid, bready : std_logic;
  signal arvalid, arready, rvalid, rready, rlast : std_logic;
  signal rdata : std_logic_vector(31 downto 0);

  -- responder controls
  signal aw_en, ar_en, r_en : std_logic := '1';
  signal drop_rlast : boolean := false;
  signal last_awaddr, last_araddr : std_logic_vector(AW-1 downto 0) := (others => '0');

  -- monitors
  signal n_push, n_pop, n_rerr, n_bresp : natural := 0;
  signal mon_clr : std_logic := '0';
begin
  clk <= not clk after 5 ns;

  dut : entity work.usart_dma
    generic map (ADDR_W => AW, FIFO_LOG2 => LOG2)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => (others => '0'),
      tx_addr => tx_addr, tx_len => tx_len, tx_start => tx_start,
      tx_abort => tx_abort, tx_busy => tx_busy, tx_done => tx_done,
      tx_rerr => tx_rerr, tx_aborted => tx_aborted,
      rx_addr => rx_addr, rx_len => rx_len, rx_start => rx_start,
      rx_abort => rx_abort, rx_busy => rx_busy, rx_done => rx_done,
      rx_flushed => rx_flushed, rx_aborted => rx_aborted,
      rx_berr => rx_berr, rx_count => rx_count,
      idle_to => to_unsigned(0, 16),
      txf_wr => txf_wr, txf_wdata => txf_wdata,
      txf_lvl => to_unsigned(0, LOG2+1),
      rxf_rd => rxf_rd, rxf_rdata => rxf_rdata, rxf_lvl => rxf_lvl,
      rx_push => '0', rx_line_busy => '0', bit_tick => '0',
      m_axi_awaddr => awaddr, m_axi_awlen => awlen, m_axi_awsize => awsize,
      m_axi_awburst => awburst, m_axi_awvalid => awvalid, m_axi_awready => awready,
      m_axi_wdata => wdata, m_axi_wstrb => wstrb, m_axi_wlast => wlast,
      m_axi_wvalid => wvalid, m_axi_wready => wready,
      m_axi_bresp => "00", m_axi_bvalid => bvalid, m_axi_bready => bready,
      m_axi_araddr => araddr, m_axi_arlen => arlen, m_axi_arsize => arsize,
      m_axi_arburst => arburst, m_axi_arvalid => arvalid, m_axi_arready => arready,
      m_axi_rdata => rdata, m_axi_rresp => "00", m_axi_rlast => rlast,
      m_axi_rvalid => rvalid, m_axi_rready => rready
    );

  -- ---------------- simple AXI responder ----------------
  awready <= aw_en;
  arready <= ar_en;
  wready  <= '1';

  wr_resp : process(clk)
  begin
    if rising_edge(clk) then
      if awvalid = '1' and awready = '1' then last_awaddr <= awaddr; end if;
      if wvalid = '1' and wready = '1' and wlast = '1' then
        bvalid <= '1';
      elsif bready = '1' then
        bvalid <= '0';
      end if;
      if aresetn = '0' then bvalid <= '0'; end if;
    end if;
  end process;

  rd_resp : process(clk)
    variable left : integer := 0;
  begin
    if rising_edge(clk) then
      if arvalid = '1' and arready = '1' then
        last_araddr <= araddr;
        left := to_integer(unsigned(arlen)) + 1;
      elsif rvalid = '1' and rready = '1' then
        left := left - 1;
      end if;
      if aresetn = '0' then left := 0; end if;
      if left > 0 and r_en = '1' then rvalid <= '1'; else rvalid <= '0'; end if;
      if left = 1 and not drop_rlast then rlast <= '1'; else rlast <= '0'; end if;
      rdata <= x"03020100";
    end if;
  end process;

  -- ---------------- FIFO-side models + monitors ----------------
  mon : process(clk)
  begin
    if rising_edge(clk) then
      if mon_clr = '1' then
        n_push <= 0; n_pop <= 0; n_rerr <= 0;
      else
        if txf_wr = '1' then n_push <= n_push + 1; end if;
        if rxf_rd = '1' then n_pop  <= n_pop + 1;  end if;
        if tx_rerr = '1' then n_rerr <= n_rerr + 1; end if;
      end if;
    end if;
  end process;

  stim : process
    procedure tick(n : natural := 1) is
    begin
      for i in 1 to n loop wait until rising_edge(clk); end loop;
    end procedure;
    procedure pulse(signal s : out std_logic) is
    begin
      s <= '1'; tick; s <= '0';
    end procedure;
    procedure wait_hi(signal s : in std_logic; tmax : natural; tag : string) is
      variable t : natural := 0;
    begin
      loop
        tick;
        exit when s = '1';
        t := t + 1;
        assert t < tmax report tag & ": timeout" severity failure;
      end loop;
    end procedure;
    variable got_ab : boolean;
  begin
    aresetn <= '0'; tick(5); aresetn <= '1'; tick(5);

    ------------------------------------------------------------------ D1
    report "[D1] rx_abort while stalled in X_AW is latched";
    rx_addr <= x"00000100"; rx_len <= to_unsigned(64, 24);
    aw_en <= '0';
    rxf_lvl <= to_unsigned(8, LOG2+1);         -- 8 bytes ready -> 2-beat burst
    pulse(rx_start);
    wait until awvalid = '1' for 1 us;
    assert awvalid = '1' report "D1: no AW issued" severity failure;
    tick(3);
    pulse(rx_abort);                           -- DUT is in X_AW, not X_DEC
    tick(10);
    rxf_lvl <= to_unsigned(0, LOG2+1);          -- burst bytes are "in the FIFO"
    aw_en <= '1';
    got_ab := false;
    for t in 0 to 2000 loop
      tick;
      if rx_done = '1' then got_ab := (rx_aborted = '1'); exit; end if;
      assert t < 2000 report "D1: RX channel never closed (abort lost)"
        severity failure;
    end loop;
    assert got_ab report "D1: rx_done without rx_aborted" severity failure;
    assert rx_count = 8
      report "D1: burst in flight not completed (count=" &
             integer'image(to_integer(rx_count)) & ")" severity failure;
    tick(2);
    assert rx_busy = '0' report "D1: still busy" severity failure;
    report "[D1] PASS";

    ------------------------------------------------------------------ D2
    report "[D2] tx_abort while waiting for R beats is latched";
    mon_clr <= '1'; tick; mon_clr <= '0';
    tx_addr <= x"00000200"; tx_len <= to_unsigned(256, 24);
    r_en <= '0';
    pulse(tx_start);
    wait until arvalid = '1' for 1 us;
    tick(4);
    pulse(tx_abort);                           -- DUT is in T_BEAT
    tick(10);
    r_en <= '1';
    got_ab := false;
    for t in 0 to 2000 loop
      tick;
      if tx_done = '1' then got_ab := (tx_aborted = '1'); exit; end if;
      assert t < 2000 report "D2: TX channel never closed" severity failure;
    end loop;
    assert got_ab report "D2: tx_done without tx_aborted" severity failure;
    -- burst size is bounded by FIFO space (DEPTH=16 -> 4 beats = 16 bytes)
    assert n_push = 16
      report "D2: in-flight burst (4 beats) not fully pushed: " &
             integer'image(n_push) severity failure;
    report "[D2] PASS";

    ------------------------------------------------------------------ D3
    report "[D3] full 32-bit DDR offsets";
    tx_addr <= x"80000040"; tx_len <= to_unsigned(4, 24);
    pulse(tx_start);
    wait_hi(tx_done, 2000, "D3 tx");
    assert last_araddr = x"0080000040"
      report "D3: araddr = 0x" & to_hstring(last_araddr) &
             " (bit 31 truncated?)" severity failure;
    rx_addr <= x"C0000080"; rx_len <= to_unsigned(4, 24);
    rxf_lvl <= to_unsigned(4, LOG2+1);
    pulse(rx_start);
    wait until awvalid = '1' and awready = '1' for 2 us;
    rxf_lvl <= to_unsigned(0, LOG2+1);
    wait_hi(rx_done, 2000, "D3 rx");
    assert last_awaddr = x"00C0000080"
      report "D3: awaddr = 0x" & to_hstring(last_awaddr) severity failure;
    report "[D3] PASS";

    ------------------------------------------------------------------ D4
    report "[D4] missing RLAST is reported, no hang";
    mon_clr <= '1'; tick; mon_clr <= '0';
    drop_rlast <= true;
    tx_addr <= x"00000000"; tx_len <= to_unsigned(16, 24);
    pulse(tx_start);
    wait_hi(tx_done, 4000, "D4");
    assert n_rerr >= 1 report "D4: RLAST mismatch not reported" severity failure;
    assert n_push = 16 report "D4: wrong byte count" severity failure;
    drop_rlast <= false;
    mon_clr <= '1'; tick; mon_clr <= '0';
    pulse(tx_start);
    wait_hi(tx_done, 4000, "D4b");
    assert n_rerr = 0 report "D4: false RLAST error with a correct slave"
      severity failure;
    report "[D4] PASS";

    ------------------------------------------------------------------ D5
    report "[D5] abort while idle is ignored";
    pulse(rx_abort); pulse(tx_abort);
    tick(5);
    mon_clr <= '1'; tick; mon_clr <= '0';
    tx_len <= to_unsigned(8, 24);
    pulse(tx_start);
    got_ab := true;
    for t in 0 to 4000 loop
      tick;
      if tx_done = '1' then got_ab := (tx_aborted = '1'); exit; end if;
    end loop;
    assert not got_ab and n_push = 8
      report "D5: stale abort request killed a new transfer" severity failure;
    report "[D5] PASS";

    report "tb_usart_dma: ALL TESTS PASSED";
    finish;
  end process;
end architecture sim;
