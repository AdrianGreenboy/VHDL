-- tb_dma_audit_adcs.vhd - Audit 2026-11 regression for mem_subsys_dma_adcs +
-- soc/dma_burst (same checks as ECC_Scrubber/tb_dma_audit.vhd; the ADCS
-- accelerator AXI port is tied idle).
-- Self-checking (assert ... severity failure). Fails on the pre-audit RTL:
--   D1 CPU store to local RAM while the DMA is busy must not be lost.
--   D2 LEN = 300 (> 256): every AXI burst must have AxLEN+1 beats with
--      WLAST/RLAST on the last one (AxLEN is 8 bits) and all data must arrive.
--   D3 LEN = 0 is ignored: no AXI traffic and STATUS.busy returns to 0.
-- The AXI slave below is a protocol checker + 4096-word memory with
-- back-pressure (it inserts wait states) so the DMA stays busy long enough.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity tb_dma_audit_adcs is
end entity;

architecture sim of tb_dma_audit_adcs is
  constant AW : natural := 40;
  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal ddr_base : std_logic_vector(AW-1 downto 0) := (others => '0');

  signal dmem_addr, dmem_wdata, dmem_rdata : word_t := (others => '0');
  signal dmem_wstrb : std_logic_vector(3 downto 0) := "0000";
  signal dmem_req, dmem_ready : std_logic := '0';

  signal awaddr, araddr : std_logic_vector(AW-1 downto 0);
  signal awlen, arlen   : std_logic_vector(7 downto 0);
  signal awsize, arsize : std_logic_vector(2 downto 0);
  signal awburst, arburst : std_logic_vector(1 downto 0);
  signal awvalid, wvalid, wlast, bready, arvalid, rready : std_logic;
  signal awready, wready, arready : std_logic := '0';
  signal wdata : std_logic_vector(31 downto 0);
  signal wstrb : std_logic_vector(3 downto 0);
  signal bvalid, rvalid, rlast : std_logic := '0';
  signal bresp, rresp : std_logic_vector(1 downto 0) := "00";
  signal rdata : std_logic_vector(31 downto 0) := (others => '0');

  type ddr_t is array (0 to 4095) of std_logic_vector(31 downto 0);
  signal ddr : ddr_t;
  signal n_ar, n_aw, n_beats_r, n_beats_w : natural := 0;
begin
  clk <= not clk after 5 ns;

  dut : entity work.mem_subsys_dma_adcs
    generic map (DEPTH => 1024, INIT_FILE => "", ADDR_W => AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => ddr_base,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      m_axi_awaddr => awaddr, m_axi_awlen => awlen, m_axi_awsize => awsize,
      m_axi_awburst => awburst, m_axi_awvalid => awvalid, m_axi_awready => awready,
      m_axi_wdata => wdata, m_axi_wstrb => wstrb, m_axi_wlast => wlast,
      m_axi_wvalid => wvalid, m_axi_wready => wready,
      m_axi_bresp => bresp, m_axi_bvalid => bvalid, m_axi_bready => bready,
      m_axi_araddr => araddr, m_axi_arlen => arlen, m_axi_arsize => arsize,
      m_axi_arburst => arburst, m_axi_arvalid => arvalid, m_axi_arready => arready,
      m_axi_rdata => rdata, m_axi_rresp => rresp, m_axi_rlast => rlast,
      m_axi_rvalid => rvalid, m_axi_rready => rready,
      a_axi_araddr => open, a_axi_arlen => open, a_axi_arsize => open, a_axi_arburst => open,
      a_axi_arprot => open, a_axi_arcache => open, a_axi_arvalid => open, a_axi_arready => '0',
      a_axi_rdata => (others => '0'), a_axi_rresp => "00", a_axi_rlast => '0',
      a_axi_rvalid => '0', a_axi_rready => open,
      a_axi_awaddr => open, a_axi_awlen => open, a_axi_awsize => open, a_axi_awburst => open,
      a_axi_awprot => open, a_axi_awcache => open, a_axi_awvalid => open, a_axi_awready => '0',
      a_axi_wdata => open, a_axi_wstrb => open, a_axi_wlast => open, a_axi_wvalid => open,
      a_axi_wready => '0', a_axi_bresp => "00", a_axi_bvalid => '0', a_axi_bready => open,
      adcs_irq => open);

  -- AXI4 slave with protocol checks (single outstanding transaction per channel)
  slave : process
    variable a, beats, k : natural;
    variable init : boolean := false;
  begin
    if not init then
      for i in 0 to 4095 loop ddr(i) <= std_logic_vector(to_unsigned(16#A0000# + i, 32)); end loop;
      init := true;
    end if;
    wait until rising_edge(clk);
    if arvalid = '1' then
      arready <= '1'; wait until rising_edge(clk); arready <= '0';
      a := to_integer(unsigned(araddr(13 downto 2))); beats := to_integer(unsigned(arlen)) + 1;
      n_ar <= n_ar + 1;
      for b in 0 to beats-1 loop
        -- one wait state every other beat
        if b mod 2 = 1 then wait until rising_edge(clk); end if;
        rdata <= ddr((a + b) mod 4096); rvalid <= '1';
        if b = beats-1 then rlast <= '1'; else rlast <= '0'; end if;
        loop wait until rising_edge(clk); exit when rready = '1'; end loop;
        rvalid <= '0'; rlast <= '0';
        n_beats_r <= n_beats_r + 1;
      end loop;
    elsif awvalid = '1' then
      awready <= '1'; wait until rising_edge(clk); awready <= '0';
      a := to_integer(unsigned(awaddr(13 downto 2))); beats := to_integer(unsigned(awlen)) + 1;
      n_aw <= n_aw + 1;
      k := 0;
      while k < beats loop
        wready <= '1';
        wait until rising_edge(clk);
        if wvalid = '1' then
          ddr((a + k) mod 4096) <= wdata;
          assert (wlast = '1') = (k = beats-1)
            report "D2: WLAST does not match AWLEN (beat " & integer'image(k) &
                   " of " & integer'image(beats) & ")" severity failure;
          k := k + 1;
          n_beats_w <= n_beats_w + 1;
        end if;
      end loop;
      wready <= '0';
      bvalid <= '1';
      loop wait until rising_edge(clk); exit when bready = '1'; end loop;
      bvalid <= '0';
    end if;
  end process;

  -- the DMA must never emit a beat outside a burst
  chk : process(clk)
  begin
    if rising_edge(clk) then
      if wvalid = '1' and wready = '1' and awvalid = '1' then
        assert false report "W beat while AW still pending" severity failure;
      end if;
    end if;
  end process;

  cpu : process
    variable d : word_t;
    procedure cpu_wr(a : natural; v : word_t) is
    begin
      dmem_addr <= std_logic_vector(to_unsigned(a, 32)); dmem_wdata <= v;
      dmem_wstrb <= "1111"; dmem_req <= '1';
      loop wait until rising_edge(clk); exit when dmem_ready = '1'; end loop;
      dmem_req <= '0'; dmem_wstrb <= "0000";
    end procedure;
    procedure cpu_rd(a : natural; v : out word_t) is
    begin
      dmem_addr <= std_logic_vector(to_unsigned(a, 32)); dmem_wstrb <= "0000"; dmem_req <= '1';
      loop
        wait for 1 ns;
        if dmem_ready = '1' then
          v := dmem_rdata;
          wait until rising_edge(clk);
          exit;
        end if;
        wait until rising_edge(clk);
      end loop;
      dmem_req <= '0';
    end procedure;
    procedure wait_idle is
      variable s : word_t;
    begin
      for k in 0 to 20000 loop
        cpu_rd(16#4000_0010#, s);
        if s(0) = '0' then return; end if;
      end loop;
      assert false report "DMA never went idle" severity failure;
    end procedure;
    variable ar0 : natural;
  begin
    aresetn <= '0';
    for k in 0 to 4 loop wait until rising_edge(clk); end loop;
    aresetn <= '1';
    wait until rising_edge(clk);

    -- ---------------- D1: store during DMA -----------------------------
    cpu_wr(16#4000_0000#, x"00000000");        -- SRC (DDR byte offset)
    cpu_wr(16#4000_0004#, x"00000000");        -- DST local byte 0
    cpu_wr(16#4000_0008#, x"00000040");        -- LEN 64 words
    cpu_wr(16#4000_000C#, x"00000001");        -- start, DDR->local
    for k in 0 to 5 loop wait until rising_edge(clk); end loop;
    cpu_wr(16#0000_0F00#, x"CAFEF00D");        -- local word 960, outside DMA dst
    wait_idle;
    cpu_rd(16#0000_0F00#, d);
    assert d = x"CAFEF00D" report "D1: CPU store during DMA was lost" severity failure;
    cpu_rd(16#0000_0000# + 4*63, d);
    assert d = std_logic_vector(to_unsigned(16#A0000# + 63, 32))
      report "D1: DMA data wrong" severity failure;
    report "D1 PASS CPU store during DMA is preserved";

    -- ---------------- D2: LEN = 300 local->DDR and DDR->local ----------
    for i in 0 to 299 loop cpu_wr(16#0000_0400# + 4*i, std_logic_vector(to_unsigned(16#5000# + i, 32))); end loop;
    cpu_wr(16#4000_0000#, x"00000400");        -- SRC local byte 0x400
    cpu_wr(16#4000_0004#, x"00002000");        -- DST DDR byte 0x2000 (page aligned)
    cpu_wr(16#4000_0008#, std_logic_vector(to_unsigned(300, 32)));
    cpu_wr(16#4000_000C#, x"00000003");        -- start, local->DDR
    wait_idle;
    for k in 0 to 5 loop wait until rising_edge(clk); end loop;
    for i in 0 to 299 loop
      assert ddr(16#800# + i) = std_logic_vector(to_unsigned(16#5000# + i, 32))
        report "D2: DDR word " & integer'image(i) & " wrong after 300-word write" severity failure;
    end loop;
    assert n_aw >= 2 report "D2: 300 words must be split into >= 2 bursts" severity failure;
    ar0 := n_ar;
    cpu_wr(16#4000_0000#, x"00002000");        -- SRC DDR 0x2000
    cpu_wr(16#4000_0004#, x"00000800");        -- DST local byte 0x800
    cpu_wr(16#4000_000C#, x"00000001");        -- start, DDR->local
    wait_idle;
    for i in 0 to 299 loop
      cpu_rd(16#0000_0800# + 4*i, d);
      assert d = std_logic_vector(to_unsigned(16#5000# + i, 32))
        report "D2: local word " & integer'image(i) & " wrong after 300-word read" severity failure;
    end loop;
    assert n_ar - ar0 >= 2 report "D2: read not split" severity failure;
    report "D2 PASS LEN > 256 split into legal bursts";

    -- ---------------- D3: LEN = 0 --------------------------------------
    ar0 := n_ar;
    cpu_wr(16#4000_0008#, x"00000000");
    cpu_wr(16#4000_000C#, x"00000001");
    for k in 0 to 20 loop wait until rising_edge(clk); end loop;
    wait_idle;
    assert n_ar = ar0 report "D3: LEN=0 produced AXI traffic" severity failure;
    report "D3 PASS LEN=0 ignored";

    report "TB_DMA_AUDIT_ADCS PASS";
    std.env.finish;
  end process;
end architecture;
