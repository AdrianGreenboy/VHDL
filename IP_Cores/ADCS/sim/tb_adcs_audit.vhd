-- ============================================================================
-- tb_adcs_audit.vhd -- audit 2026-11 regression of adcs_accel_top.
-- Own AXI4 slave BFM (64K words, programmable faults) + AXI protocol checker.
-- Self-checking (severity failure); each test fails on the pre-audit RTL:
--   T1 RRESP=SLVERR during LOAD_H -> STATUS.DONE + STATUS.ERR
--      (was: error ignored, garbage written, DONE without ERR)
--   T2 soft reset while ARVALID waits for ARREADY: ARVALID must stay high
--      until ARREADY (was: async reset dropped it -> protocol violation),
--      the DMA drains and STATUS.BUSY returns to 0
--   T3 slave never accepts AR -> watchdog -> DONE + ERR (was: deadlock)
--   T4 NDIM / MAXITER clamps (0 -> 1, > D -> D)
--   T5 NaN in g -> U[0] = NaN stored to DDR and STATUS.ERR
--      (was: NaN silently saturated to +/-umax)
--   T6 a normal MPC solve afterwards still completes without ERR
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;
use work.adcs_pkg.all;

entity tb_adcs_audit is
end entity;

architecture sim of tb_adcs_audit is
  constant TCLK : time := 4 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal rst_n : std_logic := '0';
  signal irq : std_logic;
  signal sel : std_logic := '0';
  signal addr, wdata, rdata : word_t := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := "0000";
  signal ready : std_logic;

  signal araddr, awaddr, wdat, rdat : std_logic_vector(31 downto 0) := (others => '0');
  signal arlen, awlen : std_logic_vector(7 downto 0);
  signal arsize, awsize, arprot, awprot : std_logic_vector(2 downto 0);
  signal arburst, awburst : std_logic_vector(1 downto 0);
  signal arcache, awcache, wstrb_m : std_logic_vector(3 downto 0);
  signal arvalid, rready, awvalid, wvalid, wlast, bready : std_logic;
  signal arready, rvalid, rlast, awready, wready, bvalid : std_logic := '0';
  signal rresp, bresp : std_logic_vector(1 downto 0) := "00";

  -- BFM controls
  signal ar_block  : boolean := false;     -- never accept AR
  signal ar_delay  : natural := 0;         -- cycles before ARREADY
  signal rerr_beat : integer := -1;        -- SLVERR on this read beat (global count)
  signal n_rbeat   : natural := 0;
  signal chk_en    : boolean := true;       -- off only for the dead-slave test

  type mem_t is array (0 to 65535) of std_logic_vector(31 downto 0);
  type mem_pt is protected
    procedure set(i : natural; v : std_logic_vector(31 downto 0));
    impure function get(i : natural) return std_logic_vector;
  end protected;
  type mem_pt is protected body
    variable m : mem_t := (others => (others => '0'));
    procedure set(i : natural; v : std_logic_vector(31 downto 0)) is
    begin m(i) := v; end procedure;
    impure function get(i : natural) return std_logic_vector is
    begin return m(i); end function;
  end protected body;
  shared variable mem : mem_pt;
begin
  clk <= '0' when fin else not clk after TCLK/2;

  dut : entity work.adcs_accel_top
    port map (
      clk => clk, rst_n => rst_n, irq => irq,
      dmem_sel => sel, dmem_addr => addr, dmem_wdata => wdata, dmem_wstrb => wstrb,
      dmem_rdata => rdata, dmem_ready => ready,
      m_axi_araddr => araddr, m_axi_arlen => arlen, m_axi_arsize => arsize,
      m_axi_arburst => arburst, m_axi_arprot => arprot, m_axi_arcache => arcache,
      m_axi_arvalid => arvalid, m_axi_arready => arready,
      m_axi_rdata => rdat, m_axi_rresp => rresp, m_axi_rlast => rlast,
      m_axi_rvalid => rvalid, m_axi_rready => rready,
      m_axi_awaddr => awaddr, m_axi_awlen => awlen, m_axi_awsize => awsize,
      m_axi_awburst => awburst, m_axi_awprot => awprot, m_axi_awcache => awcache,
      m_axi_awvalid => awvalid, m_axi_awready => awready,
      m_axi_wdata => wdat, m_axi_wstrb => wstrb_m, m_axi_wlast => wlast,
      m_axi_wvalid => wvalid, m_axi_wready => wready,
      m_axi_bresp => bresp, m_axi_bvalid => bvalid, m_axi_bready => bready);

  -- ---------------- AXI slave BFM (single beat transactions) ----------------
  rd_bfm : process
    variable a : natural;
  begin
    wait until rising_edge(clk);
    if arvalid = '1' and not ar_block then
      for i in 1 to ar_delay loop wait until rising_edge(clk); end loop;
      if not ar_block then
        arready <= '1'; a := to_integer(unsigned(araddr(17 downto 2)));
        wait until rising_edge(clk); arready <= '0';
        rdat <= mem.get(a); rvalid <= '1'; rlast <= '1';
        if n_rbeat = rerr_beat then rresp <= "10"; else rresp <= "00"; end if;
        loop wait until rising_edge(clk); exit when rready = '1'; end loop;
        rvalid <= '0'; rlast <= '0'; rresp <= "00";
        n_rbeat <= n_rbeat + 1;
      end if;
    end if;
  end process;

  wr_bfm : process
    variable a : natural;
  begin
    wait until rising_edge(clk);
    if awvalid = '1' then
      awready <= '1'; a := to_integer(unsigned(awaddr(17 downto 2)));
      wait until rising_edge(clk); awready <= '0';
      wready <= '1';
      loop wait until rising_edge(clk); exit when wvalid = '1'; end loop;
      mem.set(a, wdat); wready <= '0';
      bvalid <= '1'; bresp <= "00";
      loop wait until rising_edge(clk); exit when bready = '1'; end loop;
      bvalid <= '0';
    end if;
  end process;

  -- ---------------- AXI protocol checker ----------------
  chk : process(clk)
    variable arv_q, awv_q, wv_q, arr_q, awr_q, wr_q : std_logic := '0';
  begin
    if rising_edge(clk) then
      if rst_n = '1' and chk_en then
        assert not (arv_q = '1' and arr_q = '0' and arvalid = '0')
          report "AXI: ARVALID dropped before ARREADY" severity failure;
        assert not (awv_q = '1' and awr_q = '0' and awvalid = '0')
          report "AXI: AWVALID dropped before AWREADY" severity failure;
        assert not (wv_q = '1' and wr_q = '0' and wvalid = '0')
          report "AXI: WVALID dropped before WREADY" severity failure;
      end if;
      arv_q := arvalid; arr_q := arready;
      awv_q := awvalid; awr_q := awready;
      wv_q := wvalid;   wr_q := wready;
    end if;
  end process;

  main : process
    variable v : word_t;
    variable c : natural;
    procedure wr(off : natural; d : word_t) is
    begin
      addr <= std_logic_vector(to_unsigned(off, 32)); wdata <= d; wstrb <= "1111"; sel <= '1';
      wait until rising_edge(clk);
      sel <= '0'; wstrb <= "0000";
      wait until rising_edge(clk);
    end procedure;
    procedure rd(off : natural; d : out word_t) is
    begin
      addr <= std_logic_vector(to_unsigned(off, 32)); wstrb <= "0000"; sel <= '1';
      wait for 1 ns; d := rdata;
      wait until rising_edge(clk);
      sel <= '0';
    end procedure;
    procedure wait_done(lim : natural; msg : string) is
      variable s : word_t;
      variable k : natural := 0;
    begin
      loop
        rd(16#04#, s);
        exit when s(ST_DONE_BIT) = '1';
        k := k + 1;
        assert k < lim report msg & ": DONE never set" severity failure;
      end loop;
    end procedure;
  begin
    -- DDR content: H (8x8 at 0x0000, row stride DP), g at 0x2000, U at 0x3000
    for i in 0 to 7 loop
      for j in 0 to 7 loop
        if i = j then mem.set(i*DP + j, x"3F800000"); else mem.set(i*DP + j, x"3C000000"); end if;
      end loop;
      mem.set(16#800# + i, x"3E800000");            -- g = 0.25
    end loop;

    rst_n <= '0';
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;
    rst_n <= '1';
    wait until rising_edge(clk);

    wr(16#1C#, x"00000000");   -- HBASE
    wr(16#20#, x"00002000");   -- GBASE
    wr(16#24#, x"00003000");   -- UBASE
    wr(16#14#, x"3E000000");   -- STEP 0.125
    wr(16#18#, x"3F000000");   -- UMAX 0.5

    -- ---------- T4: clamps ----------
    wr(16#0C#, x"00000000"); rd(16#0C#, v);
    assert unsigned(v) = 1 report "T4: NDIM=0 not clamped to 1" severity failure;
    wr(16#0C#, x"0000012C"); rd(16#0C#, v);
    assert unsigned(v) = D report "T4: NDIM=300 not clamped to D" severity failure;
    wr(16#10#, x"00000000"); rd(16#10#, v);
    assert unsigned(v) = 1 report "T4: MAXITER=0 not clamped to 1" severity failure;
    report "T4: PASS NDIM/MAXITER clamps";
    wr(16#0C#, x"00000008");   -- NDIM 8
    wr(16#10#, x"00000002");   -- MAXITER 2

    -- ---------- T1: RRESP error during LOAD_H ----------
    rerr_beat <= n_rbeat + 5;
    wr(16#08#, x"00000002");   -- MODE_LOAD_H
    wr(16#00#, x"00000001");   -- START
    wait_done(100000, "T1");
    rd(16#04#, v);
    assert v(ST_ERR_BIT) = '1' report "T1: RRESP=SLVERR not reported in STATUS.ERR" severity failure;
    rerr_beat <= -1;
    report "T1: PASS RRESP error -> STATUS.ERR + DONE";

    -- ---------- T2: soft reset while AR is pending ----------
    ar_delay <= 300;
    wr(16#08#, x"00000002");
    wr(16#00#, x"00000001");
    c := 0;
    loop wait until rising_edge(clk); c := c + 1; exit when arvalid = '1' or c > 1000; end loop;
    assert arvalid = '1' report "T2: no AR issued" severity failure;
    for i in 0 to 20 loop wait until rising_edge(clk); end loop;
    wr(16#00#, x"00000002");   -- SRESET (protocol checker watches ARVALID)
    c := 0;
    loop
      rd(16#04#, v); c := c + 1;
      exit when v(ST_BUSY_BIT) = '0';
      assert c < 5000 report "T2: DMA did not drain after soft reset" severity failure;
    end loop;
    for i in 0 to 50 loop wait until rising_edge(clk); end loop;
    assert arvalid = '0' report "T2: new AR issued after soft reset" severity failure;
    wr(16#00#, x"00000000");   -- release SRESET
    ar_delay <= 0;
    report "T2: PASS soft reset drains the AXI master (no handshake cut)";

    -- ---------- T3: watchdog ----------
    ar_block <= true;
    chk_en <= false;   -- the watchdog abort of a dead slave drops ARVALID by design
    wr(16#08#, x"00000002");
    wr(16#00#, x"00000001");
    wait_done(100000, "T3");
    rd(16#04#, v);
    assert v(ST_ERR_BIT) = '1' report "T3: watchdog timeout not reported" severity failure;
    ar_block <= false;
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;
    chk_en <= true;
    report "T3: PASS dead slave -> watchdog -> STATUS.ERR";

    -- ---------- T5: NaN in g ----------
    wr(16#08#, x"00000002"); wr(16#00#, x"00000001"); wait_done(100000, "T5 loadH");
    rd(16#04#, v);
    assert v(ST_ERR_BIT) = '0' report "T5: LOAD_H failed" severity failure;
    mem.set(16#800#, x"7FC00000");                  -- g[0] = NaN
    mem.set(16#C00#, x"12345678");
    wr(16#08#, x"00000000");   -- MODE_MPC_PGD
    wr(16#00#, x"00000001");
    wait_done(200000, "T5");
    rd(16#04#, v);
    assert v(ST_ERR_BIT) = '1' report "T5: NaN in the solve not flagged" severity failure;
    assert mem.get(16#C00#)(30 downto 23) = x"FF" and unsigned(mem.get(16#C00#)(22 downto 0)) /= 0
      report "T5: NaN saturated instead of propagated (U[0]=" & to_hstring(mem.get(16#C00#)) & ")"
      severity failure;
    report "T5: PASS NaN propagated to U and flagged";

    -- ---------- T6: normal solve ----------
    mem.set(16#800#, x"3E800000");
    wr(16#00#, x"00000001");
    wait_done(200000, "T6");
    rd(16#04#, v);
    assert v(ST_ERR_BIT) = '0' report "T6: clean solve reports ERR" severity failure;
    assert mem.get(16#C00#)(31) = '1' and mem.get(16#C00#)(30 downto 23) /= x"FF"
      report "T6: U[0] not a negative finite value" severity failure;
    report "T6: PASS clean solve, U[0]=" & to_hstring(mem.get(16#C00#));

    report "TB_ADCS_AUDIT PASS";
    fin <= true; wait;
  end process;
end architecture;
