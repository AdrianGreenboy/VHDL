-- =============================================================================
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 5 (simulacion): el RV32 real ejecuta el firmware compilado
-- (fw_rv32_sim.mem, N=64) contra mac25g_top, de extremo a extremo.
--
--   soc_top_mac (RV32 + MAC 25G + axil_soc + DMA del core)
--     m_axi -> axi_ddr_sim (recibe las 24 palabras de resultado por DMA)
--
-- Secuencia del PS (espejo de tb_soc_pcs): reset, carga del firmware en IMEM
-- por AXI-Lite (0x1000), DDR_BASE = 0, liberar el core, esperar el doorbell
-- (irq_out), comparar DDR+0x40.. con l5_expected.txt (oracle/expected_l5.py).
-- Relojes de la TE0950: aclk 40 MHz (clk_pl_0), clk_dp 390.625 MHz.
--
-- Criterio: LAYER5SIM_PASS.
-- MIT License.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.riscv_pkg.all;

entity tb_soc_mac is
  generic (FW : string := "fw_rv32_sim.mem"; EXP : string := "l5_expected.txt");
end entity;

architecture sim of tb_soc_mac is
  constant TCK    : time := 25 ns;
  constant TDP    : time := 2.56 ns;
  constant SAW    : natural := 16;
  constant AXI_AW : natural := 40;
  constant W_BASE : natural := 16#40#/4;
  constant NW     : natural := 24;

  signal aclk    : std_logic := '0';
  signal clk_dp  : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal done_sim : boolean := false;

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

  signal irq_out  : std_logic;
  signal dbg_addr : natural := 0;
  signal dbg_data : word_t;
begin
  aclk   <= not aclk   after TCK/2 when not done_sim;
  clk_dp <= not clk_dp after TDP/2 when not done_sim;

  dut : entity work.soc_top_mac
    generic map (ADDR_W => SAW, DEPTH => 256, IMEM_INIT => "",
                 DONE_WORD => 127, AXI_AW => AXI_AW)
    port map (
      aclk => aclk, aresetn => aresetn, clk_dp => clk_dp, dp_locked => '1',
      s_axi_awaddr => s_awaddr, s_axi_awvalid => s_awvalid, s_axi_awready => s_awready,
      s_axi_wdata => s_wdata, s_axi_wstrb => s_wstrb, s_axi_wvalid => s_wvalid, s_axi_wready => s_wready,
      s_axi_bresp => s_bresp, s_axi_bvalid => s_bvalid, s_axi_bready => s_bready,
      s_axi_araddr => s_araddr, s_axi_arvalid => s_arvalid, s_axi_arready => s_arready,
      s_axi_rdata => s_rdata, s_axi_rresp => s_rresp, s_axi_rvalid => s_rvalid, s_axi_rready => s_rready,
      m_axi_awaddr => c_awaddr, m_axi_awlen => c_awlen, m_axi_awsize => c_awsize,
      m_axi_awburst => c_awburst, m_axi_awvalid => c_awvalid, m_axi_awready => c_awready,
      m_axi_wdata => c_wdata, m_axi_wstrb => c_wstrb, m_axi_wlast => c_wlast,
      m_axi_wvalid => c_wvalid, m_axi_wready => c_wready,
      m_axi_bresp => c_bresp, m_axi_bvalid => c_bvalid, m_axi_bready => c_bready,
      m_axi_araddr => c_araddr, m_axi_arlen => c_arlen, m_axi_arsize => c_arsize,
      m_axi_arburst => c_arburst, m_axi_arvalid => c_arvalid, m_axi_arready => c_arready,
      m_axi_rdata => c_rdata, m_axi_rresp => c_rresp, m_axi_rlast => c_rlast,
      m_axi_rvalid => c_rvalid, m_axi_rready => c_rready,
      irq_out => irq_out);

  u_ddr : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => aclk, aresetn => aresetn,
      s_axi_awaddr => c_awaddr, s_axi_awlen => c_awlen, s_axi_awvalid => c_awvalid, s_axi_awready => c_awready,
      s_axi_wdata => c_wdata, s_axi_wstrb => c_wstrb, s_axi_wlast => c_wlast, s_axi_wvalid => c_wvalid, s_axi_wready => c_wready,
      s_axi_bresp => c_bresp, s_axi_bvalid => c_bvalid, s_axi_bready => c_bready,
      s_axi_araddr => c_araddr, s_axi_arlen => c_arlen, s_axi_arvalid => c_arvalid, s_axi_arready => c_arready,
      s_axi_rdata => c_rdata, s_axi_rresp => c_rresp, s_axi_rlast => c_rlast, s_axi_rvalid => c_rvalid, s_axi_rready => c_rready,
      dbg_addr => dbg_addr, dbg_data => dbg_data);

  stim : process
    file f : text;
    variable l : line;
    variable w, v : word_t;
    variable i, errs : natural := 0;
    variable s : string(1 to 8);
    variable burst, txb : natural;
    variable gbps : real;

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

    procedure ddr_read (constant idx : natural; variable data : out word_t) is
    begin
      dbg_addr <= idx;
      wait for 1 ns;
      data := dbg_data;
    end procedure;
  begin
    aresetn <= '0';
    wait for 8*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait for 4*TCK;

    report "--- PS: cargando " & FW & " en IMEM ---";
    file_open(f, FW, read_mode);
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
    axil_write(16#0010#, (others => '0'));
    axil_write(16#0014#, (others => '0'));
    axil_write(16#0000#, (others => '0'));
    report "--- core liberado; esperando doorbell ---";

    for k in 0 to 2000000 loop
      wait until rising_edge(aclk);
      exit when irq_out = '1';
    end loop;
    assert irq_out = '1' report "TIMEOUT: no llego el doorbell" severity failure;
    report "doorbell recibido a " & time'image(now);

    file_open(f, EXP, read_mode);
    for k in 0 to NW - 1 loop
      readline(f, l);
      read(l, s);
      ddr_read(W_BASE + k, v);
      if s /= "XXXXXXXX" then
        l := new string'(s);
        hread(l, w);
        if v /= w then
          errs := errs + 1;
          report "FAIL palabra " & integer'image(k) & " = 0x" & to_hstring(v) &
            " esperado 0x" & to_hstring(w) severity error;
        end if;
      end if;
    end loop;
    file_close(f);

    ddr_read(W_BASE + 3, v);  txb := to_integer(unsigned(v));     -- TX_BYTES
    ddr_read(W_BASE + 16, v); burst := to_integer(unsigned(v));   -- BURST_CYCLES
    gbps := real(txb) * 8.0 / (real(burst) / 390.625e6) / 1.0e9;
    ddr_read(W_BASE + 22, v);
    report "firma FNV = 0x" & to_hstring(v);
    ddr_read(W_BASE + 23, w);
    report "FLAGS     = 0x" & to_hstring(w) & "  BURST_CYCLES=" & integer'image(burst) &
      "  L2+FCS=" & real'image(gbps) & " Gb/s (banco 390.625 MHz)";

    if errs = 0 then
      report "LAYER5SIM_PASS firmware real en RV32 real, 24 palabras == oraculo";
    else
      report "LAYER5SIM_FAIL errores=" & integer'image(errs) severity error;
    end if;
    done_sim <= true;
    wait;
  end process;
end architecture;
