-- =============================================================================
-- HERCOSSNUX Core 18 - MIPI CSI-2 RX
-- SoC integration testbench: the real RV32 core executes the compiled firmware
-- (fw_rv32.mem) against the MIPI peripheral, end to end.
--
--   soc_top_mipi (RV32 + MIPI + axil_soc + core DMA)
--     m_axi     -> u_ddr_core  (receives the signature via the core DMA)
--     mipi_axi  -> u_ddr_mipi  (receives the framebuffers via the MIPI DMA)
--
-- Boot sequence mirrors tb_soc_master:
--   1. reset, 2. PS loads firmware into IMEM via AXI-Lite (0x1000 window),
--   3. PS sets DDR_BASE, 4. PS releases the core (CONTROL=0),
--   5. wait for irq_out (doorbell), 6. read the signature from DDR (dbg_data)
--      at word 16 (DDR_RESULT_OFF 0x40 / 4) and compare to 0xE6898DC5.
--
-- This is the full silicon dress rehearsal in simulation.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.riscv_pkg.all;

entity tb_soc_mipi is
end entity;

architecture sim of tb_soc_mipi is
  constant TCK    : time := 10 ns;
  constant SAW    : natural := 16;        -- AXI-Lite address width
  constant AXI_AW : natural := 40;        -- AXI master address width
  constant GOLDEN : word_t := x"E6898DC5";
  constant RESULT_WORD : natural := 16#40#/4;   -- DDR_RESULT_OFF 0x40 -> word 16

  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  -- AXI-Lite slave signals
  signal s_awaddr : std_logic_vector(SAW-1 downto 0) := (others=>'0');
  signal s_awvalid, s_awready : std_logic := '0';
  signal s_wdata  : std_logic_vector(31 downto 0) := (others=>'0');
  signal s_wstrb  : std_logic_vector(3 downto 0) := (others=>'0');
  signal s_wvalid, s_wready : std_logic := '0';
  signal s_bresp  : std_logic_vector(1 downto 0);
  signal s_bvalid : std_logic; signal s_bready : std_logic := '0';
  signal s_araddr : std_logic_vector(SAW-1 downto 0) := (others=>'0');
  signal s_arvalid, s_arready : std_logic := '0';
  signal s_rdata  : std_logic_vector(31 downto 0);
  signal s_rresp  : std_logic_vector(1 downto 0);
  signal s_rvalid : std_logic; signal s_rready : std_logic := '0';

  -- core AXI master (m_axi) -> u_ddr_core
  signal c_awaddr : std_logic_vector(AXI_AW-1 downto 0);
  signal c_awlen  : std_logic_vector(7 downto 0);
  signal c_awsize : std_logic_vector(2 downto 0);
  signal c_awburst: std_logic_vector(1 downto 0);
  signal c_awvalid, c_awready : std_logic;
  signal c_wdata  : std_logic_vector(31 downto 0);
  signal c_wstrb  : std_logic_vector(3 downto 0);
  signal c_wlast, c_wvalid, c_wready : std_logic;
  signal c_bresp  : std_logic_vector(1 downto 0);
  signal c_bvalid, c_bready : std_logic;
  signal c_araddr : std_logic_vector(AXI_AW-1 downto 0);
  signal c_arlen  : std_logic_vector(7 downto 0);
  signal c_arsize : std_logic_vector(2 downto 0);
  signal c_arburst: std_logic_vector(1 downto 0);
  signal c_arvalid, c_arready : std_logic;
  signal c_rdata  : std_logic_vector(31 downto 0);
  signal c_rresp  : std_logic_vector(1 downto 0);
  signal c_rlast, c_rvalid, c_rready : std_logic;

  -- MIPI AXI master (mipi_axi, write-only) -> u_ddr_mipi
  signal m_awaddr : std_logic_vector(AXI_AW-1 downto 0);
  signal m_awlen  : std_logic_vector(7 downto 0);
  signal m_awsize : std_logic_vector(2 downto 0);
  signal m_awburst: std_logic_vector(1 downto 0);
  signal m_awvalid, m_awready : std_logic;
  signal m_wdata  : std_logic_vector(31 downto 0);
  signal m_wstrb  : std_logic_vector(3 downto 0);
  signal m_wlast, m_wvalid, m_wready : std_logic;
  signal m_bresp  : std_logic_vector(1 downto 0);
  signal m_bvalid, m_bready : std_logic;
  -- MIPI DDR read channel (unused; tie off)
  signal m_araddr : std_logic_vector(AXI_AW-1 downto 0) := (others=>'0');
  signal m_arlen  : std_logic_vector(7 downto 0) := (others=>'0');
  signal m_arvalid : std_logic := '0'; signal m_arready : std_logic;
  signal m_rdata  : std_logic_vector(31 downto 0);
  signal m_rresp  : std_logic_vector(1 downto 0);
  signal m_rlast, m_rvalid : std_logic; signal m_rready : std_logic := '0';

  signal irq_out : std_logic;

  signal core_dbg_addr : natural := 0;
  signal core_dbg_data : word_t;
  signal mipi_dbg_addr : natural := 0;
  signal mipi_dbg_data : word_t;
begin
  aclk <= not aclk after TCK/2;

  -- === DUT: the MIPI SoC (real RV32 + MIPI) ===
  dut : entity work.soc_top_mipi
    generic map (ADDR_W => SAW, DEPTH => 256, IMEM_INIT => "",
                 DONE_WORD => 127, AXI_AW => AXI_AW)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_axi_awaddr => s_awaddr, s_axi_awvalid => s_awvalid, s_axi_awready => s_awready,
      s_axi_wdata => s_wdata, s_axi_wstrb => s_wstrb, s_axi_wvalid => s_wvalid, s_axi_wready => s_wready,
      s_axi_bresp => s_bresp, s_axi_bvalid => s_bvalid, s_axi_bready => s_bready,
      s_axi_araddr => s_araddr, s_axi_arvalid => s_arvalid, s_axi_arready => s_arready,
      s_axi_rdata => s_rdata, s_axi_rresp => s_rresp, s_axi_rvalid => s_rvalid, s_axi_rready => s_rready,
      -- core DMA master
      m_axi_awaddr => c_awaddr, m_axi_awlen => c_awlen, m_axi_awsize => c_awsize,
      m_axi_awburst => c_awburst, m_axi_awvalid => c_awvalid, m_axi_awready => c_awready,
      m_axi_wdata => c_wdata, m_axi_wstrb => c_wstrb, m_axi_wlast => c_wlast,
      m_axi_wvalid => c_wvalid, m_axi_wready => c_wready,
      m_axi_bresp => c_bresp, m_axi_bvalid => c_bvalid, m_axi_bready => c_bready,
      m_axi_araddr => c_araddr, m_axi_arlen => c_arlen, m_axi_arsize => c_arsize,
      m_axi_arburst => c_arburst, m_axi_arvalid => c_arvalid, m_axi_arready => c_arready,
      m_axi_rdata => c_rdata, m_axi_rresp => c_rresp, m_axi_rlast => c_rlast,
      m_axi_rvalid => c_rvalid, m_axi_rready => c_rready,
      -- MIPI DMA master
      mipi_awaddr => m_awaddr, mipi_awlen => m_awlen, mipi_awsize => m_awsize,
      mipi_awburst => m_awburst, mipi_awvalid => m_awvalid, mipi_awready => m_awready,
      mipi_wdata => m_wdata, mipi_wstrb => m_wstrb, mipi_wlast => m_wlast,
      mipi_wvalid => m_wvalid, mipi_wready => m_wready,
      mipi_bresp => m_bresp, mipi_bvalid => m_bvalid, mipi_bready => m_bready,
      irq_out => irq_out
    );

  -- === DDR model on the core master (receives the signature) ===
  u_ddr_core : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => aclk, aresetn => aresetn,
      s_axi_awaddr => c_awaddr, s_axi_awlen => c_awlen, s_axi_awvalid => c_awvalid, s_axi_awready => c_awready,
      s_axi_wdata => c_wdata, s_axi_wstrb => c_wstrb, s_axi_wlast => c_wlast, s_axi_wvalid => c_wvalid, s_axi_wready => c_wready,
      s_axi_bresp => c_bresp, s_axi_bvalid => c_bvalid, s_axi_bready => c_bready,
      s_axi_araddr => c_araddr, s_axi_arlen => c_arlen, s_axi_arvalid => c_arvalid, s_axi_arready => c_arready,
      s_axi_rdata => c_rdata, s_axi_rresp => c_rresp, s_axi_rlast => c_rlast, s_axi_rvalid => c_rvalid, s_axi_rready => c_rready,
      dbg_addr => core_dbg_addr, dbg_data => core_dbg_data
    );

  -- === DDR model on the MIPI master (receives the framebuffers) ===
  -- FB0 @ 0x1000, FB1 @ 0x9000, each 18432 bytes. FB1 ends at 0xD800 = word
  -- 13824. DEPTH=16384 words (64 KB) covers both with margin.
  u_ddr_mipi : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 16384, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => aclk, aresetn => aresetn,
      s_axi_awaddr => m_awaddr, s_axi_awlen => m_awlen, s_axi_awvalid => m_awvalid, s_axi_awready => m_awready,
      s_axi_wdata => m_wdata, s_axi_wstrb => m_wstrb, s_axi_wlast => m_wlast, s_axi_wvalid => m_wvalid, s_axi_wready => m_wready,
      s_axi_bresp => m_bresp, s_axi_bvalid => m_bvalid, s_axi_bready => m_bready,
      s_axi_araddr => m_araddr, s_axi_arlen => m_arlen, s_axi_arvalid => m_arvalid, s_axi_arready => m_arready,
      s_axi_rdata => m_rdata, s_axi_rresp => m_rresp, s_axi_rlast => m_rlast, s_axi_rvalid => m_rvalid, s_axi_rready => m_rready,
      dbg_addr => mipi_dbg_addr, dbg_data => mipi_dbg_data
    );

  stim : process
    file f : text;
    variable l : line;
    variable w : word_t;
    variable i : natural;

    procedure axil_write (constant addr : integer; constant data : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      s_awaddr <= std_logic_vector(to_unsigned(addr, SAW));
      s_wdata  <= data; s_wstrb <= "1111";
      s_awvalid <= '1'; s_wvalid <= '1'; s_bready <= '1';
      loop wait until rising_edge(aclk); exit when s_awready = '1'; end loop;
      s_awvalid <= '0'; s_wvalid <= '0';
      loop wait until rising_edge(aclk); exit when s_bvalid = '1'; end loop;
      s_bready <= '0';
    end procedure;
  begin
    aresetn <= '0';
    wait for 8*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait for 4*TCK;

    -- (1) PS loads the firmware into IMEM via the AXI-Lite 0x1000 window
    report "--- PS: loading fw_rv32.mem into IMEM (AXI-Lite) ---";
    file_open(f, "fw_rv32.mem", read_mode);
    i := 0;
    while not endfile(f) loop
      readline(f, l);
      if l'length > 0 then
        hread(l, w);
        axil_write(16#1000# + i*4, w);
        i := i + 1;
      end if;
    end loop;
    file_close(f);
    report "  loaded " & integer'image(i) & " instructions";

    -- (1b) PS sets the physical DDR base (fake DDR starts at 0 here)
    axil_write(16#0010#, (others => '0'));   -- DDR_BASE_LO
    axil_write(16#0014#, (others => '0'));   -- DDR_BASE_HI

    -- (2) release the core: CONTROL = 0 (clear halt)
    axil_write(16#0000#, (others => '0'));
    report "--- core released; waiting for doorbell IRQ ---";

    -- (3) wait for the doorbell interrupt (generous window: the self-test frame
    --     generation + FNV fold + DMA takes many thousands of cycles)
    for k in 0 to 2000000 loop
      wait until rising_edge(aclk);
      exit when irq_out = '1';
    end loop;

    if irq_out /= '1' then
      report "TIMEOUT: no doorbell IRQ" severity failure;
    end if;
    report "doorbell IRQ received";

    -- (4) read the signature from the core DDR at DDR_RESULT_OFF word
    core_dbg_addr <= RESULT_WORD;
    wait for 1 ns;
    report "signature @DDR = 0x" & to_hstring(core_dbg_data);
    core_dbg_addr <= RESULT_WORD + 1;
    wait for 1 ns;
    report "status    @DDR = 0x" & to_hstring(core_dbg_data);

    -- final verdict
    core_dbg_addr <= RESULT_WORD;
    wait for 1 ns;
    if core_dbg_data = GOLDEN then
      report "L5 SOC-SIM PASS - RV32 firmware produced 0x" & to_hstring(GOLDEN)
        severity note;
    else
      report "L5 SOC-SIM FAIL - got 0x" & to_hstring(core_dbg_data) &
             " exp 0x" & to_hstring(GOLDEN) severity failure;
    end if;

    wait;
  end process;
end architecture;
