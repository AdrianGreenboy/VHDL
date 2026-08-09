library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use work.riscv_pkg.all;
entity tb_selfcheck_si is end entity;
architecture sim of tb_selfcheck_si is
  signal aclk: std_logic:='0'; signal aresetn: std_logic:='0';
  signal s_awaddr,s_araddr: std_logic_vector(15 downto 0):=(others=>'0');
  signal s_awvalid,s_awready,s_wvalid,s_wready,s_bvalid,s_bready,s_arvalid,s_arready,s_rvalid,s_rready: std_logic:='0';
  signal s_wdata,s_rdata: std_logic_vector(31 downto 0):=(others=>'0');
  signal s_wstrb: std_logic_vector(3 downto 0):=(others=>'0');
  signal s_bresp,s_rresp: std_logic_vector(1 downto 0);
  -- maestro AXI: sin DDR real, dejamos ready en 1 y rvalid en 0 (DMA no se usa en smoke)
  signal m_awaddr,m_araddr: std_logic_vector(39 downto 0);
  signal m_awlen,m_arlen: std_logic_vector(7 downto 0);
  signal m_awsize,m_arsize: std_logic_vector(2 downto 0);
  signal m_awburst,m_arburst: std_logic_vector(1 downto 0);
  signal m_awvalid,m_wvalid,m_wlast,m_bready,m_arvalid,m_rready: std_logic;
  signal m_wdata: std_logic_vector(31 downto 0); signal m_wstrb: std_logic_vector(3 downto 0);
  signal m_bvalid,m_rvalid,m_rlast: std_logic:='0';
  signal m_bresp,m_rresp: std_logic_vector(1 downto 0):=(others=>'0');
  signal m_awready,m_wready,m_arready: std_logic:='1';
  signal irq: std_logic;
begin
  aclk <= not aclk after 5 ns;
  dut: entity work.ecc_soc_si
    generic map (ADDR_W=>16, DEPTH=>256, SCRUB_DEPTH=>32, IMEM_INIT=>"ecc_fw_selfcheck.mem", DONE_WORD=>127, AXI_AW=>40)
    port map (aclk=>aclk, aresetn=>aresetn,
      s_axi_awaddr=>s_awaddr,s_axi_awvalid=>s_awvalid,s_axi_awready=>s_awready,
      s_axi_wdata=>s_wdata,s_axi_wstrb=>s_wstrb,s_axi_wvalid=>s_wvalid,s_axi_wready=>s_wready,
      s_axi_bresp=>s_bresp,s_axi_bvalid=>s_bvalid,s_axi_bready=>s_bready,
      s_axi_araddr=>s_araddr,s_axi_arvalid=>s_arvalid,s_axi_arready=>s_arready,
      s_axi_rdata=>s_rdata,s_axi_rresp=>s_rresp,s_axi_rvalid=>s_rvalid,s_axi_rready=>s_rready,
      m_axi_awaddr=>m_awaddr,m_axi_awlen=>m_awlen,m_axi_awsize=>m_awsize,m_axi_awburst=>m_awburst,
      m_axi_awvalid=>m_awvalid,m_axi_awready=>m_awready,m_axi_wdata=>m_wdata,m_axi_wstrb=>m_wstrb,
      m_axi_wlast=>m_wlast,m_axi_wvalid=>m_wvalid,m_axi_wready=>m_wready,m_axi_bresp=>m_bresp,
      m_axi_bvalid=>m_bvalid,m_axi_bready=>m_bready,m_axi_araddr=>m_araddr,m_axi_arlen=>m_arlen,
      m_axi_arsize=>m_arsize,m_axi_arburst=>m_arburst,m_axi_arvalid=>m_arvalid,m_axi_arready=>m_arready,
      m_axi_rdata=>m_wdata,m_axi_rresp=>m_rresp,m_axi_rlast=>m_rlast,m_axi_rvalid=>m_rvalid,m_axi_rready=>m_rready,
      irq_out=>irq);
  process
    alias pcs is << signal .tb_selfcheck_si.dut.dbg_pc : work.riscv_pkg.word_t >>;
    procedure axi_write(addr: std_logic_vector(15 downto 0); data: std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      s_awaddr <= addr; s_awvalid <= '1'; s_wdata <= data; s_wstrb <= "1111"; s_wvalid <= '1'; s_bready <= '1';
      loop wait until rising_edge(aclk); exit when s_awready='1' and s_wready='1'; end loop;
      s_awvalid <= '0'; s_wvalid <= '0';
      loop wait until rising_edge(aclk); exit when s_bvalid='1'; end loop;
      s_bready <= '0';
    end procedure;
  begin
    aresetn<='0'; wait for 40 ns; aresetn<='1'; wait for 20 ns;
    -- liberar el core: CONTROL (0x0000) = 0
    axi_write(x"0000", x"00000000");
    for k in 0 to 200 loop
      wait for 50 ns;
      report "t PC=" & to_hstring(pcs) & " irq=" & std_logic'image(irq);
      exit when irq='1';
    end loop;
    report "selfcheck fin: irq=" & std_logic'image(irq);
    wait;
  end process;
end architecture;
