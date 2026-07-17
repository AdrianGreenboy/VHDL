-- tb_rf_soc.vhd - Capa 4 de silicio: valida el SoC RF COMPLETO tal como va a
-- hardware. Emula al PS: (1) carga fw_rf.mem en el IMEM por AXI-Lite, (2) fija
-- DDR_BASE=0, (3) arranca el core (CONTROL=0), (4) espera la IRQ del doorbell,
-- (5) lee las 64 muestras de la DDR del RF (escritas por el SEGUNDO maestro) y
-- calcula el checksum canonico, comparandolo con el golden 0xB74940EB.
-- Hay dos BFM de DDR: uno para el maestro de la familia (sin uso en este test) y
-- otro para el segundo maestro del RF (recibe la captura).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.riscv_pkg.all;

entity tb_rf_soc is
end entity tb_rf_soc;

architecture sim of tb_rf_soc is
  constant TCK    : time := 10 ns;
  constant SAW    : natural := 16;
  constant AXI_AW : natural := 40;
  constant GOLDEN : std_logic_vector(31 downto 0) := x"B74940EB";

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

  -- maestro de la familia (sin uso; a DDR falsa 0)
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

  -- segundo maestro del RF (a DDR del RF)
  signal raw_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal raw_len  : std_logic_vector(7 downto 0);
  signal raw_size : std_logic_vector(2 downto 0);
  signal raw_burst: std_logic_vector(1 downto 0);
  signal raw_valid, raw_ready : std_logic;
  signal rw_data  : std_logic_vector(31 downto 0);
  signal rw_strb  : std_logic_vector(3 downto 0);
  signal rw_last, rw_valid, rw_ready : std_logic;
  signal rb_resp  : std_logic_vector(1 downto 0);
  signal rb_valid, rb_ready : std_logic;
  signal rar_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal rar_len  : std_logic_vector(7 downto 0);
  signal rar_size : std_logic_vector(2 downto 0);
  signal rar_burst: std_logic_vector(1 downto 0);
  signal rar_valid, rar_ready : std_logic;
  signal rr_data  : std_logic_vector(31 downto 0);
  signal rr_resp  : std_logic_vector(1 downto 0);
  signal rr_last, rr_valid, rr_ready : std_logic;

  signal irq_out, rf_irq_out : std_logic;
  signal ddr_dbg_addr : natural := 0;
  signal ddr_dbg_data : word_t;
  signal rf_dbg_addr : natural := 0;
  signal rf_dbg_data : word_t;
begin

  aclk <= not aclk after TCK/2;

  dut : entity work.rf_soc_top_master
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
      rf_axi_awaddr => raw_addr, rf_axi_awlen => raw_len, rf_axi_awsize => raw_size,
      rf_axi_awburst => raw_burst, rf_axi_awvalid => raw_valid, rf_axi_awready => raw_ready,
      rf_axi_wdata => rw_data, rf_axi_wstrb => rw_strb, rf_axi_wlast => rw_last,
      rf_axi_wvalid => rw_valid, rf_axi_wready => rw_ready,
      rf_axi_bresp => rb_resp, rf_axi_bvalid => rb_valid, rf_axi_bready => rb_ready,
      rf_axi_araddr => rar_addr, rf_axi_arlen => rar_len, rf_axi_arsize => rar_size,
      rf_axi_arburst => rar_burst, rf_axi_arvalid => rar_valid, rf_axi_arready => rar_ready,
      rf_axi_rdata => rr_data, rf_axi_rresp => rr_resp, rf_axi_rlast => rr_last,
      rf_axi_rvalid => rr_valid, rf_axi_rready => rr_ready,
      irq_out => irq_out, rf_irq_out => rf_irq_out
    );

  -- DDR del maestro de la familia (sin uso real en este test)
  u_ddr : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => aclk, aresetn => aresetn,
      s_axi_awaddr => aw_addr, s_axi_awlen => aw_len, s_axi_awvalid => aw_valid, s_axi_awready => aw_ready,
      s_axi_wdata => w_data, s_axi_wstrb => w_strb, s_axi_wlast => w_last, s_axi_wvalid => w_valid, s_axi_wready => w_ready,
      s_axi_bresp => b_resp, s_axi_bvalid => b_valid, s_axi_bready => b_ready,
      s_axi_araddr => ar_addr, s_axi_arlen => ar_len, s_axi_arvalid => ar_valid, s_axi_arready => ar_ready,
      s_axi_rdata => r_data, s_axi_rresp => r_resp, s_axi_rlast => r_last, s_axi_rvalid => r_valid, s_axi_rready => r_ready,
      dbg_addr => ddr_dbg_addr, dbg_data => ddr_dbg_data
    );

  -- DDR del SEGUNDO maestro del RF: recibe las 64 muestras capturadas
  u_ddr_rf : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => aclk, aresetn => aresetn,
      s_axi_awaddr => raw_addr, s_axi_awlen => raw_len, s_axi_awvalid => raw_valid, s_axi_awready => raw_ready,
      s_axi_wdata => rw_data, s_axi_wstrb => rw_strb, s_axi_wlast => rw_last, s_axi_wvalid => rw_valid, s_axi_wready => rw_ready,
      s_axi_bresp => rb_resp, s_axi_bvalid => rb_valid, s_axi_bready => rb_ready,
      s_axi_araddr => rar_addr, s_axi_arlen => rar_len, s_axi_arvalid => rar_valid, s_axi_arready => rar_ready,
      s_axi_rdata => rr_data, s_axi_rresp => rr_resp, s_axi_rlast => rr_last, s_axi_rvalid => rr_valid, s_axi_rready => rr_ready,
      dbg_addr => rf_dbg_addr, dbg_data => rf_dbg_data
    );

  stim : process
    variable errors : natural := 0;
    file     f : text;
    variable l : line;
    variable w : word_t;
    variable i : natural;
    variable chk : unsigned(31 downto 0) := (others => '0');

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

    report "--- PS: cargando fw_rf en el IMEM (AXI-Lite) ---";
    file_open(f, "fw_rf.mem", read_mode);
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
    report "  cargadas " & integer'image(i) & " instrucciones";

    axil_write(16#0010#, (others => '0'));   -- DDR_BASE_LO = 0
    axil_write(16#0014#, (others => '0'));   -- DDR_BASE_HI = 0

    axil_write(16#0000#, (others => '0'));   -- CONTROL = 0: arranca el core
    report "--- core arrancado; esperando IRQ del doorbell ---";

    for k in 0 to 200000 loop
      wait until rising_edge(aclk);
      exit when irq_out = '1';
    end loop;
    if irq_out = '1' then
      report "IRQ recibida del core (doorbell)" severity note;
    else
      report "TIMEOUT esperando IRQ" severity error;
      errors := errors + 1;
    end if;

    -- leer las 64 muestras de la DDR del RF y calcular el checksum canonico
    chk := (others => '0');
    for idx in 0 to 63 loop
      rf_dbg_addr <= idx;
      wait for 1 ns;
      chk := (chk(30 downto 0) & chk(31)) xor unsigned(rf_dbg_data);
    end loop;

    report "-----------------------------------------";
    if std_logic_vector(chk) = GOLDEN and errors = 0 then
      report "FIN SIMULACION RFSOC: PASS CHK=0x" & to_hstring(chk) & " N=64 @ " & time'image(now) severity note;
    else
      report "FIN SIMULACION RFSOC: FAIL CHK=0x" & to_hstring(chk) & " esp=0x" & to_hstring(GOLDEN) severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
