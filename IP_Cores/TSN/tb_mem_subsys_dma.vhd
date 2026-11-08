-- tb_mem_subsys_dma.vhd - TSN-local mem_subsys_dma bus qualification (audit 2026-11)
-- ---------------------------------------------------------------------------
-- Self-checking. Needs riscv_pkg / dp_ram / dma_burst from ../RV32i (read-only).
--   M1 a partial store (sh, wstrb=1100) to a TSN register is ignored; a full
--      sw writes it (v1: wstrb was OR-reduced -> the garbage lower lanes were
--      written into TBL_MAC_HI).
--   M2 a store-shaped bus state WITHOUT dmem_req (stale wstrb/addr) must not
--      write the DMA CTRL register / start a DMA (v1: started it).
--   M3 DMA registers honour byte lanes: sw SRC=0x11223344 then sb lane 1
--      (0xAB) -> the DMA reads DDR at 0x1122AB44 (v1: 0x0000AB00).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.riscv_pkg.all;

entity tb_mem_subsys_dma is
end entity;

architecture sim of tb_mem_subsys_dma is
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal addr, wdata, rdata : word_t := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := "0000";
  signal req : std_logic := '0';
  signal ready : std_logic;
  signal araddr : std_logic_vector(39 downto 0);
  signal arvalid : std_logic;
begin
  clk <= not clk after 5 ns;

  dut : entity work.mem_subsys_dma
    port map (clk => clk, aresetn => aresetn, ddr_base => (others => '0'),
      dmem_addr => addr, dmem_wdata => wdata, dmem_wstrb => wstrb, dmem_req => req,
      dmem_rdata => rdata, dmem_ready => ready,
      m_axi_awaddr => open, m_axi_awlen => open, m_axi_awsize => open,
      m_axi_awburst => open, m_axi_awvalid => open, m_axi_awready => '0',
      m_axi_wdata => open, m_axi_wstrb => open, m_axi_wlast => open,
      m_axi_wvalid => open, m_axi_wready => '0',
      m_axi_bresp => "00", m_axi_bvalid => '0', m_axi_bready => open,
      m_axi_araddr => araddr, m_axi_arlen => open, m_axi_arsize => open,
      m_axi_arburst => open, m_axi_arvalid => arvalid, m_axi_arready => '0',
      m_axi_rdata => (others => '0'), m_axi_rresp => "00", m_axi_rlast => '0',
      m_axi_rvalid => '0', m_axi_rready => open);

  stim : process
    variable v : word_t;
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure st(a : word_t; d : word_t; s : std_logic_vector(3 downto 0)) is
    begin
      addr <= a; wdata <= d; wstrb <= s; req <= '1'; step;
      req <= '0'; wstrb <= "0000"; step;
    end procedure;
    procedure ld(a : word_t; o : out word_t) is
    begin
      addr <= a; wstrb <= "0000"; req <= '1'; wait for 1 ns; o := rdata; step;
      req <= '0'; step;
    end procedure;
  begin
    aresetn <= '0'; step; step; aresetn <= '1'; step;

    -- M1
    st(x"6000000C", x"8001DEAD", "1100");
    ld(x"6000000C", v);
    assert v = x"00000000"
      report "M1: partial store wrote TSN TBL_MAC_HI = " & to_hstring(v) severity failure;
    st(x"6000000C", x"8001BEEF", "1111");
    ld(x"6000000C", v);
    assert v = x"8001BEEF" report "M1: full store to TSN failed" severity failure;

    -- M2: stale store pattern on the bus without dmem_req
    addr <= x"4000000C"; wdata <= x"00000001"; wstrb <= "1111"; req <= '0';
    step; step; step;
    wstrb <= "0000"; step;
    ld(x"40000010", v);
    assert v(0) = '0' report "M2: DMA started by a bus state without dmem_req" severity failure;

    -- M3
    st(x"40000000", x"11223344", "1111");
    st(x"40000000", x"0000AB00", "0010");
    st(x"40000008", x"00000004", "1111");          -- LEN 4 words
    st(x"4000000C", x"00000001", "1111");          -- start, dir=0 (DDR -> local)
    for i in 0 to 20 loop
      step;
      exit when arvalid = '1';
    end loop;
    assert arvalid = '1' report "M3: DMA did not start" severity failure;
    assert araddr(31 downto 0) = x"1122AB44"
      report "M3: DMA SRC = " & to_hstring(araddr(31 downto 0)) & " (byte lane merge)"
      severity failure;
    report "TB_MEM_SUBSYS_DMA PASS (dmem_req qualification, wstrb lanes, TSN full-word)";
    finish;
  end process;
end architecture;
