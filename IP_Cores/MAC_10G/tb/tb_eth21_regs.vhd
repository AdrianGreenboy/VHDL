-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- tb_eth21_regs: eth21_top register bank, audit 2026-11:
--   WSTRB byte lanes (SCRATCH, LEN_CFG, CMD without lane 0 = no-op),
--   SLVERR on unmapped / unaligned offsets, OKAY on RO and mapped ones,
--   PAUSE_CTRL / PAUSE_WM / PAUSE_SWQ readback, counters 23..30 readable.
-- Prints TB_ETH21_REGS_PASS / _FAIL.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_eth21_regs is end entity;

architecture sim of tb_eth21_regs is
  signal aclk, gclk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal done : boolean := false;
  signal awaddr, araddr : std_logic_vector(7 downto 0) := (others => '0');
  signal awvalid, wvalid, bready, arvalid, rready : std_logic := '0';
  signal awready, wready, bvalid, arready, rvalid : std_logic;
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := "1111";
  signal bresp, rresp : std_logic_vector(1 downto 0);
begin
  aclk <= not aclk after 5 ns when not done;
  gclk <= not gclk after 3200 ps when not done;

  dut: entity work.eth21_top
    generic map (ACLK_HZ => 100_000, SLIP_WAIT => 16)
    port map (
      s_axi_aclk=>aclk, s_axi_aresetn=>aresetn,
      s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
      s_axi_wdata=>wdata, s_axi_wstrb=>wstrb, s_axi_wvalid=>wvalid, s_axi_wready=>wready,
      s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,
      s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,
      s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready,
      tx_clk=>gclk, rx_clk=>gclk,
      gt_txdata=>open, gt_txheader=>open, gt_txsequence=>open,
      gt_txmstreset=>open, gt_txuserrdy=>open, gt_txpolarity=>open,
      gt_txmstresetdone=>'1',
      gt_rxdata=>(others => '0'), gt_rxdatavalid=>"00", gt_rxheader=>(others => '0'),
      gt_rxheadervalid=>"00", gt_rxgearboxslip=>open, gt_rxmstreset=>open,
      gt_rxuserrdy=>open, gt_rxpolarity=>open, gt_rxmstresetdone=>'1',
      gt_rxcdrlock=>'1', gt_powergood=>'1', gt_lcplllock=>'1',
      gt_lcpllreset=>open, gt_loopback=>open);

  stim: process
    variable ok : boolean := true;
    variable v  : std_logic_vector(31 downto 0);
    variable r  : std_logic_vector(1 downto 0);

    procedure fail(m : string) is
    begin
      report "TB_ETH21_REGS_FAIL " & m severity error; ok := false;
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
      if n > 2000 then fail("write timeout"); end if;
      wait until rising_edge(aclk);
      bready <= '0';
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
  begin
    wait for 100 ns;
    wait until rising_edge(aclk); aresetn <= '1';
    wait for 500 ns;

    wr(16#04#, x"AABBCCDD", "1111", r);
    wr(16#04#, x"11223344", "1010", r);
    rd(16#04#, v, r);
    if v /= x"11BB33DD" then fail("SCRATCH strb 1010 -> " & to_hstring(v)); end if;
    wr(16#3C#, x"05C005C0", "1111", r);
    wr(16#3C#, x"00120034", "0100", r);           -- len_max[7:0] only
    rd(16#3C#, v, r);
    if v /= x"051205C0" then fail("LEN_CFG strb 0100 -> " & to_hstring(v)); end if;
    wr(16#0C#, x"00000004", "1110", r);           -- GEN_START without lane 0
    rd(16#10#, v, r);
    if v(9) /= '0' then fail("CMD executed without byte lane 0"); end if;

    wr(16#5C#, x"00000001", "1111", r);
    if r /= "10" then fail("write 0x5C bresp=" & to_string(r)); end if;
    wr(16#05#, x"00000001", "1111", r);
    if r /= "10" then fail("unaligned write bresp=" & to_string(r)); end if;
    wr(16#10#, x"00000001", "1111", r);
    if r /= "00" then fail("write RO STATUS bresp=" & to_string(r)); end if;
    rd(16#FC#, v, r);
    if r /= "10" then fail("read 0xFC rresp=" & to_string(r)); end if;
    rd(16#60#, v, r);
    if r /= "10" then fail("read 0x60 rresp=" & to_string(r)); end if;
    rd(16#4C#, v, r);
    if r /= "00" then fail("read RXCLK_MEAS rresp=" & to_string(r)); end if;
    rd(16#F8#, v, r);
    if r /= "00" then fail("read counter 30 rresp=" & to_string(r)); end if;

    wr(16#50#, x"0ABC0007", "1111", r); rd(16#50#, v, r);
    if v /= x"0ABC0007" then fail("PAUSE_CTRL " & to_hstring(v)); end if;
    wr(16#54#, x"01000040", "1111", r); rd(16#54#, v, r);
    if v /= x"01000040" then fail("PAUSE_WM " & to_hstring(v)); end if;
    wr(16#58#, x"00001234", "1111", r); rd(16#58#, v, r);
    if v /= x"00001234" then fail("PAUSE_SWQ " & to_hstring(v)); end if;

    if ok then report "TB_ETH21_REGS_PASS"; else report "TB_ETH21_REGS_FAIL"; end if;
    done <= true;
    wait;
  end process;
end architecture sim;
