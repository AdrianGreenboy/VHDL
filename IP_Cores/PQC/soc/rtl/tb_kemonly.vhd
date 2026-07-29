library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
use work.riscv_pkg.all;
entity tb_kemonly is end entity;
architecture sim of tb_kemonly is
  constant ADDR_W:natural:=16; constant AXI_AW:natural:=40; constant IMEM_D:natural:=1024;
  signal clk:std_logic:='0'; signal aresetn:std_logic:='0';
  signal s_awaddr:std_logic_vector(ADDR_W-1 downto 0):=(others=>'0');
  signal s_awvalid:std_logic:='0'; signal s_awready:std_logic;
  signal s_wdata:std_logic_vector(31 downto 0):=(others=>'0');
  signal s_wstrb:std_logic_vector(3 downto 0):="1111"; signal s_wvalid:std_logic:='0'; signal s_wready:std_logic;
  signal s_bresp:std_logic_vector(1 downto 0); signal s_bvalid:std_logic; signal s_bready:std_logic:='1';
  signal s_araddr:std_logic_vector(ADDR_W-1 downto 0):=(others=>'0'); signal s_arvalid:std_logic:='0'; signal s_arready:std_logic;
  signal s_rdata:std_logic_vector(31 downto 0); signal s_rresp:std_logic_vector(1 downto 0); signal s_rvalid:std_logic; signal s_rready:std_logic:='1';
  signal m_awaddr:std_logic_vector(AXI_AW-1 downto 0); signal m_awlen:std_logic_vector(7 downto 0); signal m_awsize:std_logic_vector(2 downto 0);
  signal m_awburst:std_logic_vector(1 downto 0); signal m_awvalid:std_logic; signal m_awready:std_logic;
  signal m_wdata:std_logic_vector(31 downto 0); signal m_wstrb:std_logic_vector(3 downto 0); signal m_wlast:std_logic; signal m_wvalid:std_logic; signal m_wready:std_logic;
  signal m_bresp:std_logic_vector(1 downto 0); signal m_bvalid:std_logic; signal m_bready:std_logic;
  signal m_araddr:std_logic_vector(AXI_AW-1 downto 0); signal m_arlen:std_logic_vector(7 downto 0); signal m_arsize:std_logic_vector(2 downto 0);
  signal m_arburst:std_logic_vector(1 downto 0); signal m_arvalid:std_logic; signal m_arready:std_logic;
  signal m_rdata:std_logic_vector(31 downto 0); signal m_rresp:std_logic_vector(1 downto 0); signal m_rlast:std_logic; signal m_rvalid:std_logic; signal m_rready:std_logic;
  signal irq_out,pqc_irq_out:std_logic; signal ddr_dbg_addr:natural:=0; signal ddr_dbg_data:word_t;
  constant TCLK:time:=25 ns;
begin
  clk<=not clk after TCLK/2;
  u_soc: entity work.soc_top_pqc generic map(ADDR_W=>ADDR_W,DEPTH=>IMEM_D,IMEM_INIT=>"pqc_probe.mem",DONE_WORD=>127,AXI_AW=>AXI_AW)
    port map(aclk=>clk,aresetn=>aresetn,s_axi_awaddr=>s_awaddr,s_axi_awvalid=>s_awvalid,s_axi_awready=>s_awready,
      s_axi_wdata=>s_wdata,s_axi_wstrb=>s_wstrb,s_axi_wvalid=>s_wvalid,s_axi_wready=>s_wready,s_axi_bresp=>s_bresp,s_axi_bvalid=>s_bvalid,s_axi_bready=>s_bready,
      s_axi_araddr=>s_araddr,s_axi_arvalid=>s_arvalid,s_axi_arready=>s_arready,s_axi_rdata=>s_rdata,s_axi_rresp=>s_rresp,s_axi_rvalid=>s_rvalid,s_axi_rready=>s_rready,
      m_axi_awaddr=>m_awaddr,m_axi_awlen=>m_awlen,m_axi_awsize=>m_awsize,m_axi_awburst=>m_awburst,m_axi_awvalid=>m_awvalid,m_axi_awready=>m_awready,
      m_axi_wdata=>m_wdata,m_axi_wstrb=>m_wstrb,m_axi_wlast=>m_wlast,m_axi_wvalid=>m_wvalid,m_axi_wready=>m_wready,m_axi_bresp=>m_bresp,m_axi_bvalid=>m_bvalid,m_axi_bready=>m_bready,
      m_axi_araddr=>m_araddr,m_axi_arlen=>m_arlen,m_axi_arsize=>m_arsize,m_axi_arburst=>m_arburst,m_axi_arvalid=>m_arvalid,m_axi_arready=>m_arready,
      m_axi_rdata=>m_rdata,m_axi_rresp=>m_rresp,m_axi_rlast=>m_rlast,m_axi_rvalid=>m_rvalid,m_axi_rready=>m_rready,irq_out=>irq_out,pqc_irq_out=>pqc_irq_out);
  u_ddr: entity work.axi_ddr_sim generic map(ADDR_W=>AXI_AW,DEPTH=>4096,RD_LAT=>4)
    port map(clk=>clk,aresetn=>aresetn,s_axi_awaddr=>m_awaddr,s_axi_awlen=>m_awlen,s_axi_awvalid=>m_awvalid,s_axi_awready=>m_awready,
      s_axi_wdata=>m_wdata,s_axi_wstrb=>m_wstrb,s_axi_wlast=>m_wlast,s_axi_wvalid=>m_wvalid,s_axi_wready=>m_wready,s_axi_bresp=>m_bresp,s_axi_bvalid=>m_bvalid,s_axi_bready=>m_bready,
      s_axi_araddr=>m_araddr,s_axi_arlen=>m_arlen,s_axi_arvalid=>m_arvalid,s_axi_arready=>m_arready,s_axi_rdata=>m_rdata,s_axi_rresp=>m_rresp,s_axi_rlast=>m_rlast,s_axi_rvalid=>m_rvalid,s_axi_rready=>m_rready,
      dbg_addr=>ddr_dbg_addr,dbg_data=>ddr_dbg_data);
  stim: process
    variable khi,klo,dhi,dlo,sent:word_t;
  begin
    aresetn<='0'; wait for 200 ns; aresetn<='1'; wait for 100 ns;
    wait until rising_edge(clk); s_awaddr<=x"0000"; s_awvalid<='1'; s_wdata<=x"00000000"; s_wvalid<='1';
    wait until rising_edge(clk); wait until rising_edge(clk); s_awvalid<='0'; s_wvalid<='0';
    report "self-test completo corriendo (KEM+DSA, ~varios ms)..." severity note;
    wait for 16 ms;   -- 6 operaciones a 40MHz + moves
    ddr_dbg_addr<=0; wait for 20 ns; khi:=ddr_dbg_data;
    ddr_dbg_addr<=1; wait for 20 ns; klo:=ddr_dbg_data;
    ddr_dbg_addr<=2; wait for 20 ns; dhi:=ddr_dbg_data;
    ddr_dbg_addr<=3; wait for 20 ns; dlo:=ddr_dbg_data;
    ddr_dbg_addr<=8; wait for 20 ns; sent:=ddr_dbg_data;
    report "===================================================" severity note;
    report "KEM sig = "&to_hstring(khi)&to_hstring(klo)&" (esp 95E07091FA5B3CC4)" severity note;
    report "DSA sig = "&to_hstring(dhi)&to_hstring(dlo)&" (esp F93232F7EA2D1575)" severity note;
    report "centinela = "&to_hstring(sent) severity note;
    report "===================================================" severity note;
    if khi=x"95E07091" and klo=x"FA5B3CC4" and dhi=x"F93232F7" and dlo=x"EA2D1575" then
      report "*** PQC SELF-TEST COMPLETO PASS (ambas firmas coinciden) ***" severity note;
    else
      report "*** SELF-TEST: firmas no coinciden aun ***" severity warning;
    end if;
    std.env.stop;
  end process;
end architecture;
