-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- tb_mac_regs: register-bank checks of mac25g_top added by the audit 2026-11
--   T1 WSTRB byte lanes (SCRATCH, LEN_CFG); CMD without lane 0 is a no-op
--   T2 SLVERR on unmapped / unaligned offsets, OKAY on RO and mapped ones
--   T3 CMD_TIMEOUT kills the command: with clk_dp STOPPED a GEN_START times
--      out; when clk_dp runs again the stale command must NOT execute; the
--      next GEN_START works (fix B4)
--   T4 GEN_COUNT = 0: empty burst, GEN_DONE at once, no frame (fix M4)
--   T5 PAUSE_CTRL / PAUSE_WM / PAUSE_SWQ readback, counters 16..23 readable
-- Prints TB_MAC_REGS_PASS / _FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mac_regs is end entity;

architecture sim of tb_mac_regs is
  signal aclk, clk_dp : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal rst_dp  : std_logic := '1';
  signal dp_run  : boolean := true;
  signal done    : boolean := false;
  signal awaddr, araddr : std_logic_vector(7 downto 0) := (others => '0');
  signal awvalid, wvalid, bready, arvalid, rready : std_logic := '0';
  signal awready, wready, bvalid, arready, rvalid, irq : std_logic;
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := "1111";
  signal bresp, rresp : std_logic_vector(1 downto 0);
begin
  aclk <= not aclk after 5 ns when not done;               -- 100 MHz
  process
  begin
    while not done loop
      if dp_run then clk_dp <= not clk_dp; end if;
      wait for 1280 ps;
    end loop;
    wait;
  end process;

  dut: entity work.mac25g_top
    port map (s_axi_aclk=>aclk, s_axi_aresetn=>aresetn,
              s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
              s_axi_wdata=>wdata, s_axi_wstrb=>wstrb, s_axi_wvalid=>wvalid, s_axi_wready=>wready,
              s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,
              s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,
              s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready,
              irq_out=>irq, clk_dp=>clk_dp, rst_dp=>rst_dp);

  stim: process
    variable ok : boolean := true;
    variable v  : std_logic_vector(31 downto 0);
    variable r  : std_logic_vector(1 downto 0);
    variable t0 : time;

    procedure fail(m : string) is
    begin
      report "TB_MAC_REGS_FAIL " & m severity error; ok := false;
    end procedure;

    procedure wr(a : natural; d : std_logic_vector(31 downto 0); s : std_logic_vector(3 downto 0);
                 resp : out std_logic_vector(1 downto 0)) is
      variable n : natural := 0;
    begin
      awaddr <= std_logic_vector(to_unsigned(a, 8)); wdata <= d; wstrb <= s;
      awvalid <= '1'; wvalid <= '1'; bready <= '1';
      loop
        wait until rising_edge(aclk); n := n + 1;
        exit when awready = '1' or n > 2000;
      end loop;
      awvalid <= '0'; wvalid <= '0';
      loop
        exit when bvalid = '1';
        wait until rising_edge(aclk); n := n + 1;
        exit when n > 2000;
      end loop;
      resp := bresp;
      if n > 2000 then fail("write timeout at " & integer'image(a)); end if;
      wait until rising_edge(aclk);
      bready <= '0';
    end procedure;

    procedure wr(a : natural; d : std_logic_vector(31 downto 0)) is
      variable rr : std_logic_vector(1 downto 0);
    begin
      wr(a, d, "1111", rr);
    end procedure;

    procedure rd(a : natural; d : out std_logic_vector(31 downto 0);
                 resp : out std_logic_vector(1 downto 0)) is
    begin
      araddr <= std_logic_vector(to_unsigned(a, 8)); arvalid <= '1'; rready <= '1';
      wait until rising_edge(aclk) and arready = '1';
      arvalid <= '0';
      if rvalid = '0' then wait until rising_edge(aclk) and rvalid = '1'; end if;
      d := rdata; resp := rresp;
      wait until rising_edge(aclk);
      rready <= '0';
    end procedure;

    procedure rd(a : natural; d : out std_logic_vector(31 downto 0)) is
      variable rr : std_logic_vector(1 downto 0);
    begin
      rd(a, d, rr);
    end procedure;

    procedure counter(i : natural; d : out std_logic_vector(31 downto 0)) is
      variable x : std_logic_vector(31 downto 0);
    begin
      wr(16#1C#, x"00000001");
      for k in 1 to 200 loop
        rd(16#10#, x); exit when x(8) = '1';
      end loop;
      rd(16#40# + 4 * i, d);
    end procedure;
  begin
    aresetn <= '0'; rst_dp <= '1';
    wait for 200 ns;
    wait until rising_edge(aclk); aresetn <= '1';
    wait until rising_edge(clk_dp); rst_dp <= '0';
    wait for 200 ns;

    -- T1 WSTRB
    wr(16#04#, x"AABBCCDD");
    wr(16#04#, x"11223344", "0101", r);
    rd(16#04#, v);
    if v /= x"AA22CC44" then fail("T1 SCRATCH strb 0101 -> " & to_hstring(v)); end if;
    wr(16#30#, x"05EA0014");
    wr(16#30#, x"00FF0040", "0001", r);              -- only len_min[7:0]
    rd(16#30#, v);
    if v /= x"05EA0040" then fail("T1 LEN_CFG strb 0001 -> " & to_hstring(v)); end if;
    wr(16#0C#, x"00000004", "1110", r);              -- GEN_START without lane 0
    rd(16#10#, v);
    if v(9) /= '0' or v(1) /= '0' then fail("T1 CMD executed without byte lane 0"); end if;

    -- T2 SLVERR / OKAY
    wr(16#88#, x"12345678", "1111", r);
    if r /= "10" then fail("T2 write 0x88 bresp=" & to_string(r)); end if;
    wr(16#02#, x"12345678", "1111", r);
    if r /= "10" then fail("T2 unaligned write bresp=" & to_string(r)); end if;
    rd(16#04#, v);
    if v /= x"AA22CC44" then fail("T2 unaligned write modified SCRATCH"); end if;
    wr(16#00#, x"12345678", "1111", r);
    if r /= "00" then fail("T2 write to RO ID bresp=" & to_string(r)); end if;
    rd(16#C4#, v, r);
    if r /= "10" then fail("T2 read 0xC4 rresp=" & to_string(r)); end if;
    rd(16#A0#, v, r);
    if r /= "00" then fail("T2 read 0xA0 (counter 16) rresp=" & to_string(r)); end if;
    rd(16#10#, v, r);
    if r /= "00" then fail("T2 read STATUS rresp=" & to_string(r)); end if;

    -- configuration for traffic: MAC_EN | LOOPBACK, 4 frames
    wr(16#30#, x"00400040");                         -- 64-byte frames
    wr(16#38#, x"00000004");
    wr(16#08#, x"00000003");
    wr(16#0C#, x"00000001");                         -- SOFT_RESET (captures)
    wait for 2 us;

    -- T3 stale command after CMD_TIMEOUT
    dp_run <= false;                                 -- clk_dp stopped
    wait for 100 ns;
    wr(16#0C#, x"00000004");                         -- GEN_START: times out
    t0 := now;
    loop
      rd(16#10#, v);
      exit when v(9) = '0' or now - t0 > 20 us;
    end loop;
    if v(10) /= '1' then fail("T3 no CMD_TIMEOUT with clk_dp stopped"); end if;
    dp_run <= true;
    wait for 20 us;
    counter(0, v);
    if v /= x"00000000" then
      fail("T3 stale GEN_START executed after the timeout: TX_FRAMES=" & to_hstring(v));
    end if;
    rd(16#10#, v);
    if v(1) /= '0' then fail("T3 generator busy from a killed command"); end if;
    wr(16#0C#, x"00000004");                         -- a fresh GEN_START works
    t0 := now;
    loop
      rd(16#10#, v);
      exit when v(2) = '1' or now - t0 > 50 us;
    end loop;
    wait for 5 us;
    counter(0, v);
    if v /= x"00000004" then fail("T3 fresh GEN_START: TX_FRAMES=" & to_hstring(v)); end if;

    -- T4 GEN_COUNT = 0
    wr(16#38#, x"00000000");
    wr(16#0C#, x"00000002");                         -- CNT_CLEAR
    wr(16#0C#, x"00000004");                         -- GEN_START with count 0
    wait for 2 us;
    rd(16#10#, v);
    if v(2) /= '1' or v(1) /= '0' then
      fail("T4 GEN_COUNT=0: STATUS=" & to_hstring(v) & " (expected DONE, not BUSY)");
    end if;
    wait for 20 us;
    counter(0, v);
    if v /= x"00000000" then fail("T4 GEN_COUNT=0 sent frames: " & to_hstring(v)); end if;
    wr(16#0C#, x"00000008");                         -- GEN_STOP (cleanup)

    -- T5 PAUSE registers
    wr(16#3C#, x"12340003"); rd(16#3C#, v);
    if v /= x"12340003" then fail("T5 PAUSE_CTRL " & to_hstring(v)); end if;
    wr(16#80#, x"00C00040"); rd(16#80#, v);
    if v /= x"00C00040" then fail("T5 PAUSE_WM " & to_hstring(v)); end if;
    wr(16#84#, x"0000BEEF"); rd(16#84#, v);
    if v /= x"0000BEEF" then fail("T5 PAUSE_SWQ " & to_hstring(v)); end if;

    if ok then report "TB_MAC_REGS_PASS" severity note;
    else report "TB_MAC_REGS_FAIL" severity note; end if;
    done <= true;
    wait;
  end process;
end architecture sim;
