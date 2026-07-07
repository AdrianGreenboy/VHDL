-- =============================================================================
--  tb_soc_master.vhd  -  Valida el SoC v3 COMPLETO tal como va a hardware
--  Licencia: MIT
--
--  Emula al PS: (1) carga el programa GEMV en el IMEM por AXI-Lite, (2) arranca
--  el core (CONTROL=0), (3) espera la IRQ del doorbell, (4) lee y de la DDR.
--  El maestro del DMA lee/escribe una DDR falsa precargada con la matriz.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.riscv_pkg.all;

entity tb_soc_master is
end entity tb_soc_master;

architecture sim of tb_soc_master is
  constant TCK    : time := 10 ns;
  constant SAW    : natural := 16;   -- ancho dir esclavo
  constant AXI_AW : natural := 40;   -- ancho dir maestro

  signal aclk : std_logic := '0';
  signal aresetn : std_logic := '0';

  -- esclavo AXI-Lite
  signal s_awaddr : std_logic_vector(SAW-1 downto 0) := (others=>'0');
  signal s_awvalid, s_awready : std_logic := '0';
  signal s_wdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal s_wstrb : std_logic_vector(3 downto 0) := "1111";
  signal s_wvalid, s_wready : std_logic := '0';
  signal s_bresp : std_logic_vector(1 downto 0);
  signal s_bvalid : std_logic; signal s_bready : std_logic := '0';
  signal s_araddr : std_logic_vector(SAW-1 downto 0) := (others=>'0');
  signal s_arvalid, s_arready : std_logic := '0';
  signal s_rdata : std_logic_vector(31 downto 0);
  signal s_rresp : std_logic_vector(1 downto 0);
  signal s_rvalid : std_logic; signal s_rready : std_logic := '0';

  -- maestro AXI4 <-> DDR falsa
  signal aw_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal aw_len  : std_logic_vector(7 downto 0);
  signal aw_size : std_logic_vector(2 downto 0);
  signal aw_burst: std_logic_vector(1 downto 0);
  signal aw_valid, aw_ready : std_logic;
  signal w_data  : std_logic_vector(31 downto 0);
  signal w_strb  : std_logic_vector(3 downto 0);
  signal w_last, w_valid, w_ready : std_logic;
  signal b_resp  : std_logic_vector(1 downto 0);
  signal b_valid, b_ready : std_logic;
  signal ar_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal ar_len  : std_logic_vector(7 downto 0);
  signal ar_size : std_logic_vector(2 downto 0);
  signal ar_burst: std_logic_vector(1 downto 0);
  signal ar_valid, ar_ready : std_logic;
  signal r_data  : std_logic_vector(31 downto 0);
  signal r_resp  : std_logic_vector(1 downto 0);
  signal r_last, r_valid, r_ready : std_logic;

  signal irq_out : std_logic;
  signal ddr_dbg_addr : natural := 0;
  signal ddr_dbg_data : word_t;
begin

  aclk <= not aclk after TCK/2;

  dut : entity work.soc_top_master
    generic map (ADDR_W => SAW, DEPTH => 256, IMEM_INIT => "",
                 DONE_WORD => 127, AXI_AW => AXI_AW)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_axi_awaddr => s_awaddr, s_axi_awvalid => s_awvalid, s_axi_awready => s_awready,
      s_axi_wdata => s_wdata, s_axi_wstrb => s_wstrb, s_axi_wvalid => s_wvalid, s_axi_wready => s_wready,
      s_axi_bresp => s_bresp, s_axi_bvalid => s_bvalid, s_axi_bready => s_bready,
      s_axi_araddr => s_araddr, s_axi_arvalid => s_arvalid, s_axi_arready => s_arready,
      s_axi_rdata => s_rdata, s_axi_rresp => s_rresp, s_axi_rvalid => s_rvalid, s_axi_rready => s_rready,
      m_axi_awaddr => aw_addr, m_axi_awlen => aw_len, m_axi_awsize => aw_size,
      m_axi_awburst => aw_burst, m_axi_awvalid => aw_valid, m_axi_awready => aw_ready,
      m_axi_wdata => w_data, m_axi_wstrb => w_strb, m_axi_wlast => w_last,
      m_axi_wvalid => w_valid, m_axi_wready => w_ready,
      m_axi_bresp => b_resp, m_axi_bvalid => b_valid, m_axi_bready => b_ready,
      m_axi_araddr => ar_addr, m_axi_arlen => ar_len, m_axi_arsize => ar_size,
      m_axi_arburst => ar_burst, m_axi_arvalid => ar_valid, m_axi_arready => ar_ready,
      m_axi_rdata => r_data, m_axi_rresp => r_resp, m_axi_rlast => r_last,
      m_axi_rvalid => r_valid, m_axi_rready => r_ready,
      irq_out => irq_out
    );

  u_ddr : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "ddr_gemv.mem")
    port map (
      clk => aclk, aresetn => aresetn,
      s_axi_awaddr => aw_addr, s_axi_awlen => aw_len, s_axi_awvalid => aw_valid, s_axi_awready => aw_ready,
      s_axi_wdata => w_data, s_axi_wstrb => w_strb, s_axi_wlast => w_last, s_axi_wvalid => w_valid, s_axi_wready => w_ready,
      s_axi_bresp => b_resp, s_axi_bvalid => b_valid, s_axi_bready => b_ready,
      s_axi_araddr => ar_addr, s_axi_arlen => ar_len, s_axi_arvalid => ar_valid, s_axi_arready => ar_ready,
      s_axi_rdata => r_data, s_axi_rresp => r_resp, s_axi_rlast => r_last, s_axi_rvalid => r_valid, s_axi_rready => r_ready,
      dbg_addr => ddr_dbg_addr, dbg_data => ddr_dbg_data
    );

  stim : process
    variable errors : natural := 0;
    file     f : text;
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

    procedure axil_read (constant addr : integer; variable data : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      s_araddr <= std_logic_vector(to_unsigned(addr, SAW));
      s_arvalid <= '1'; s_rready <= '1';
      loop wait until rising_edge(aclk); exit when s_arready = '1'; end loop;
      s_arvalid <= '0';
      loop wait until rising_edge(aclk); exit when s_rvalid = '1'; end loop;
      data := s_rdata; s_rready <= '0';
    end procedure;

    procedure check_y (constant idx : natural; constant exp : integer) is
    begin
      ddr_dbg_addr <= 12 + idx;
      wait for 1 ns;
      if to_integer(unsigned(ddr_dbg_data)) = exp then
        report "PASS y[" & integer'image(idx) & "] = " & integer'image(exp) severity note;
      else
        report "FAIL y[" & integer'image(idx) & "] got=" & integer'image(to_integer(unsigned(ddr_dbg_data))) &
               " exp=" & integer'image(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;
  begin
    aresetn <= '0';
    wait for 8*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait for 4*TCK;

    -- (1) el PS mantiene el core en halt (CONTROL bit0=1 tras reset) y carga el IMEM
    report "--- PS: cargando programa GEMV en el IMEM (AXI-Lite) ---";
    file_open(f, "gemv_dma_hw.mem", read_mode);
    i := 0;
    while not endfile(f) loop
      readline(f, l);
      if l'length > 0 then
        hread(l, w);
        axil_write(16#1000# + i*4, w);   -- ventana IMEM
        i := i + 1;
      end if;
    end loop;
    file_close(f);
    report "  cargadas " & integer'image(i) & " instrucciones";

    -- (1b) el PS fija la base fisica de la DDR (aqui 0: la DDR falsa arranca en 0)
    axil_write(16#0010#, (others => '0'));   -- DDR_BASE_LO
    axil_write(16#0014#, (others => '0'));   -- DDR_BASE_HI

    -- (2) arranca el core: CONTROL = 0 (quita el halt)
    axil_write(16#0000#, (others => '0'));
    report "--- core arrancado; esperando IRQ del doorbell ---";

    -- (3) espera la interrupcion
    for k in 0 to 4000 loop
      wait until rising_edge(aclk);
      exit when irq_out = '1';
    end loop;
    if irq_out = '1' then
      report "IRQ recibida del core (doorbell)" severity note;
    else
      report "TIMEOUT esperando IRQ" severity error;
      errors := errors + 1;
    end if;

    -- (4) lee y de la DDR
    report "--- resultado y en la DDR ---";
    check_y(0, 6);
    check_y(1, 15);
    check_y(2, 24);

    report "-----------------------------------------";
    if errors = 0 then
      report "SOC v3 (MAESTRO + DMA + IRQ) EN SIM: OK" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
