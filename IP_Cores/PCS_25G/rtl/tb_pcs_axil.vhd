-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- tb_pcs_axil: AXI4-Lite protocol test of pcs_regbank (audit 2026-11).
--
-- Self-checking, independent of the oracle-generated Layer 1 testbench:
--   T1 B back-pressure: a second write is handshaken (AW+W) while the first
--      B response is stalled; s_axi_wdata changes right after the W
--      handshake. The stored value must be the HANDSHAKEN data (fix A1).
--   T2 W before AW, data changed after the W handshake (fix A1).
--   T3 exactly one CMD pulse per CMD write, even with B stalled (fix A1).
--   T4 WSTRB byte lanes honoured on SCRATCH/CTRL/CMD (fix M5).
--   T5 unmapped offset -> SLVERR on B and R, mapped -> OKAY (fix B7).
-- Prints TB_PCS_AXIL_PASS or TB_PCS_AXIL_FAIL <reason>.
-- Every handshake has a watchdog so a broken DUT fails instead of hanging.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_axil is end entity;

architecture sim of tb_pcs_axil is
  signal clk : std_logic := '0';
  signal rstn: std_logic := '0';
  signal awaddr : std_logic_vector(7 downto 0) := (others=>'0');
  signal awvalid: std_logic := '0'; signal awready: std_logic;
  signal wdata  : std_logic_vector(31 downto 0) := (others=>'0');
  signal wstrb  : std_logic_vector(3 downto 0) := "1111";
  signal wvalid : std_logic := '0'; signal wready : std_logic;
  signal bresp  : std_logic_vector(1 downto 0); signal bvalid: std_logic;
  signal bready : std_logic := '1';
  signal araddr : std_logic_vector(7 downto 0) := (others=>'0');
  signal arvalid: std_logic := '0'; signal arready: std_logic;
  signal rdata  : std_logic_vector(31 downto 0); signal rresp: std_logic_vector(1 downto 0);
  signal rvalid : std_logic; signal rready : std_logic := '1';
  signal irq    : std_logic;
  signal ctrl_reg : std_logic_vector(6 downto 0);
  signal prbs_ctrl_reg : std_logic_vector(2 downto 0);
  signal cmd_soft_reset, cmd_resync, cmd_cnt_clear, cmd_prbs_reset : std_logic;
  signal prbs_inj, stats_snap : std_logic;
  signal dma_addr_reg, dma_doorbell_reg : std_logic_vector(31 downto 0);
  signal n_clr : natural := 0;          -- cmd_cnt_clear pulses seen
  signal done  : boolean := false;
begin
  clk <= not clk after 5 ns when not done;

  dut: entity work.pcs_regbank
    port map (
      s_axi_aclk=>clk, s_axi_aresetn=>rstn,
      s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
      s_axi_wdata=>wdata, s_axi_wstrb=>wstrb, s_axi_wvalid=>wvalid, s_axi_wready=>wready,
      s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,
      s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,
      s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready,
      irq_out=>irq,
      dp_block_lock=>'0', dp_hi_ber=>'0', dp_scr_sync=>'0', dp_prbs_lock=>'0',
      dp_tx_active=>'0', dp_rx_active=>'0', dp_dma_busy=>'0',
      dp_cnt_tx_blk=>(others=>'0'), dp_cnt_rx_blk=>(others=>'0'),
      dp_cnt_rx_err=>(others=>'0'), dp_cnt_ber=>(others=>'0'),
      dp_lock_time=>(others=>'0'),
      dp_ev_lock_gained=>'0', dp_ev_lock_lost=>'0', dp_ev_hi_ber=>'0',
      dp_ev_rx_err=>'0', dp_ev_prbs_err=>'0', dp_ev_dma_done=>'0',
      ctrl_reg=>ctrl_reg, prbs_ctrl_reg=>prbs_ctrl_reg,
      cmd_soft_reset=>cmd_soft_reset, cmd_resync=>cmd_resync,
      cmd_cnt_clear=>cmd_cnt_clear, cmd_prbs_reset=>cmd_prbs_reset,
      prbs_inj=>prbs_inj, stats_snap=>stats_snap,
      dma_addr_reg=>dma_addr_reg, dma_doorbell_reg=>dma_doorbell_reg);

  -- count CNT_CLEAR pulses
  process(clk)
  begin
    if rising_edge(clk) then
      if cmd_cnt_clear = '1' then n_clr <= n_clr + 1; end if;
    end if;
  end process;

  stim: process
    variable ok   : boolean := true;
    variable rd   : std_logic_vector(31 downto 0);
    variable rr   : std_logic_vector(1 downto 0);
    variable br   : std_logic_vector(1 downto 0);

    procedure fail(msg : string) is
    begin
      report "TB_PCS_AXIL_FAIL " & msg severity error;
      ok := false;
    end procedure;

    -- AW and W handshakes only (no B wait); data changed right after W
    procedure aw_w(a : std_logic_vector(7 downto 0); d : std_logic_vector(31 downto 0);
                   s : std_logic_vector(3 downto 0); tag : string) is
      variable awd, wd : boolean := false;
      variable n : natural := 0;
    begin
      awaddr <= a; awvalid <= '1'; wdata <= d; wstrb <= s; wvalid <= '1';
      loop
        wait until rising_edge(clk);
        if awvalid = '1' and awready = '1' then awd := true; end if;
        if wvalid  = '1' and wready  = '1' then wd  := true; end if;
        if awd then awvalid <= '0'; awaddr <= x"FF"; end if;
        if wd  then wvalid  <= '0'; wdata <= x"DEADBEEF"; wstrb <= "1111"; end if;
        n := n + 1;
        exit when (awd and wd) or n > 50;
      end loop;
      if n > 50 then fail(tag & ": AW/W handshake timeout"); end if;
      wait for 1 ns;
    end procedure;

    procedure wait_b(resp : out std_logic_vector(1 downto 0); tag : string) is
      variable n : natural := 0;
    begin
      bready <= '1';
      loop
        wait until rising_edge(clk);
        n := n + 1;
        exit when bvalid = '1' or n > 50;
      end loop;
      resp := bresp;
      if n > 50 then fail(tag & ": B timeout"); end if;
      wait for 1 ns;
    end procedure;

    procedure wr(a : std_logic_vector(7 downto 0); d : std_logic_vector(31 downto 0);
                 s : std_logic_vector(3 downto 0); resp : out std_logic_vector(1 downto 0);
                 tag : string) is
    begin
      aw_w(a, d, s, tag);
      wait_b(resp, tag);
    end procedure;

    procedure rdr(a : std_logic_vector(7 downto 0); d : out std_logic_vector(31 downto 0);
                  resp : out std_logic_vector(1 downto 0); tag : string) is
      variable n : natural := 0;
      variable got : boolean := false;
    begin
      araddr <= a; arvalid <= '1'; rready <= '1';
      loop
        wait until rising_edge(clk);
        if arvalid = '1' and arready = '1' then arvalid <= '0'; got := true; end if;
        n := n + 1;
        exit when got or n > 50;
      end loop;
      n := 0;
      loop
        if rvalid = '1' then exit; end if;
        wait until rising_edge(clk);
        n := n + 1;
        exit when n > 50;
      end loop;
      d := rdata; resp := rresp;
      if n > 50 then fail(tag & ": R timeout"); end if;
      wait until rising_edge(clk);   -- R handshake (rready = 1)
      wait for 1 ns;
    end procedure;

    procedure expect(a : std_logic_vector(7 downto 0); e : std_logic_vector(31 downto 0);
                     tag : string) is
      variable d : std_logic_vector(31 downto 0);
      variable r : std_logic_vector(1 downto 0);
    begin
      rdr(a, d, r, tag);
      if d /= e then
        fail(tag & ": read " & to_hstring(d) & " expected " & to_hstring(e));
      end if;
    end procedure;
  begin
    rstn <= '0';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;
    rstn <= '1';
    wait until rising_edge(clk); wait for 1 ns;

    -- T1: second write handshaken while B of the first is stalled
    bready <= '0';
    aw_w(x"04", x"11111111", "1111", "T1a");
    for i in 1 to 3 loop wait until rising_edge(clk); end loop;   -- B pending
    aw_w(x"04", x"22222222", "1111", "T1b");                       -- held in DUT
    for i in 1 to 4 loop wait until rising_edge(clk); end loop;    -- wdata = DEADBEEF
    wait_b(br, "T1 B1");
    wait until rising_edge(clk); wait for 1 ns;
    wait_b(br, "T1 B2");
    wait until rising_edge(clk); wait for 1 ns;
    expect(x"04", x"22222222", "T1 scratch after stalled B");

    -- T2: W before AW, data changed after the W handshake
    wdata <= x"33333333"; wstrb <= "1111"; wvalid <= '1';
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      if wready = '1' then exit; end if;
    end loop;
    wvalid <= '0'; wdata <= x"DEADBEEF";
    for i in 1 to 3 loop wait until rising_edge(clk); end loop;
    awaddr <= x"04"; awvalid <= '1';
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      if awready = '1' then exit; end if;
    end loop;
    awvalid <= '0'; wait for 1 ns;
    wait_b(br, "T2 B");
    wait until rising_edge(clk); wait for 1 ns;
    expect(x"04", x"33333333", "T2 W-before-AW");

    -- T3: one CNT_CLEAR pulse per CMD write, with B stalled in between
    bready <= '0';
    aw_w(x"0C", x"00000004", "1111", "T3a");
    for i in 1 to 3 loop wait until rising_edge(clk); end loop;
    aw_w(x"04", x"44444444", "1111", "T3b");     -- unrelated write queued behind
    for i in 1 to 6 loop wait until rising_edge(clk); end loop;
    wait_b(br, "T3 B1");
    wait until rising_edge(clk); wait for 1 ns;
    wait_b(br, "T3 B2");
    for i in 1 to 6 loop wait until rising_edge(clk); end loop;
    if n_clr /= 1 then fail("T3: CNT_CLEAR pulses = " & integer'image(n_clr) & " (expected 1)"); end if;
    expect(x"04", x"44444444", "T3 scratch");

    -- T4: WSTRB
    wr(x"04", x"AABBCCDD", "1111", br, "T4a");
    wr(x"04", x"11223344", "0101", br, "T4b");
    expect(x"04", x"AA22CC44", "T4 scratch strb 0101");
    wr(x"04", x"55667788", "1000", br, "T4c");
    expect(x"04", x"5522CC44", "T4 scratch strb 1000");
    wr(x"08", x"0000007F", "0000", br, "T4d");   -- no lane: CTRL unchanged
    expect(x"08", x"00000000", "T4 ctrl strb 0000");
    wr(x"0C", x"00000004", "1110", br, "T4e");   -- CMD without lane 0: no pulse
    for i in 1 to 4 loop wait until rising_edge(clk); end loop;
    if n_clr /= 1 then fail("T4: CMD pulse with wstrb(0)=0"); end if;

    -- T5: SLVERR on unmapped offsets
    wr(x"80", x"12345678", "1111", br, "T5a");
    if br /= "10" then fail("T5: write to 0x80 bresp=" & to_string(br) & " (expected 10)"); end if;
    wr(x"06", x"12345678", "1111", br, "T5b");
    if br /= "10" then fail("T5: unaligned write bresp=" & to_string(br)); end if;
    wr(x"04", x"00000001", "1111", br, "T5c");
    if br /= "00" then fail("T5: mapped write bresp=" & to_string(br)); end if;
    rdr(x"C0", rd, rr, "T5d");
    if rr /= "10" then fail("T5: read 0xC0 rresp=" & to_string(rr)); end if;
    rdr(x"00", rd, rr, "T5e");
    if rr /= "00" or rd /= x"50435319" then fail("T5: read ID " & to_hstring(rd)); end if;

    if ok then report "TB_PCS_AXIL_PASS" severity note;
    else report "TB_PCS_AXIL_FAIL" severity note; end if;
    done <= true;
    wait;
  end process;
end architecture sim;
