-- rv64_soc.vhd - SoC RV64IMAC: CPU + crossbar + perifericos.
--   Puerto AXI4 64 bit hacia la DRAM (0x8000_0000..): DDR/NoC en FPGA, controlador en ASIC.
--   Bus MMIO nativo de 16 ranuras para las IP_Cores (0x1001_0000) + irq_ip -> PLIC 2..17.
--   Ventana AXI4-Lite 32 bit (0x2000_0000) para IPs genericas.
--   UART 16550 en 0x1000_0000 (PLIC 1), CLINT, PLIC, boot ROM en 0x1000 (vector de reset).
-- Los DMA de las IP_Cores (maestros AXI4) se unen a la DRAM fuera del SoC (SmartConnect/NoC
-- o interconexion del ASIC); con D$ write-back son no coherentes: ver Zicbom en la spec.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

entity rv64_soc is
  generic (
    TICK_DIV : positive := 100;                       -- f_clk / timebase (DTS: timebase-frequency)
    RESET_PC : xword := x"0000000000001000"
  );
  port (
    clk, rst : in std_logic;
    -- DRAM (AXI4 64 bit)
    dram_awid    : out std_logic_vector(3 downto 0);
    dram_awaddr  : out xword;
    dram_awlen   : out std_logic_vector(7 downto 0);
    dram_awsize  : out std_logic_vector(2 downto 0);
    dram_awburst : out std_logic_vector(1 downto 0);
    dram_awcache : out std_logic_vector(3 downto 0);
    dram_awprot  : out std_logic_vector(2 downto 0);
    dram_awvalid : out std_logic;
    dram_awready : in  std_logic;
    dram_wdata   : out xword;
    dram_wstrb   : out std_logic_vector(7 downto 0);
    dram_wlast   : out std_logic;
    dram_wvalid  : out std_logic;
    dram_wready  : in  std_logic;
    dram_bid     : in  std_logic_vector(3 downto 0);
    dram_bresp   : in  std_logic_vector(1 downto 0);
    dram_bvalid  : in  std_logic;
    dram_bready  : out std_logic;
    dram_arid    : out std_logic_vector(3 downto 0);
    dram_araddr  : out xword;
    dram_arlen   : out std_logic_vector(7 downto 0);
    dram_arsize  : out std_logic_vector(2 downto 0);
    dram_arburst : out std_logic_vector(1 downto 0);
    dram_arcache : out std_logic_vector(3 downto 0);
    dram_arprot  : out std_logic_vector(2 downto 0);
    dram_arvalid : out std_logic;
    dram_arready : in  std_logic;
    dram_rid     : in  std_logic_vector(3 downto 0);
    dram_rdata   : in  xword;
    dram_rresp   : in  std_logic_vector(1 downto 0);
    dram_rlast   : in  std_logic;
    dram_rvalid  : in  std_logic;
    dram_rready  : out std_logic;
    -- IP_Cores: bus MMIO nativo
    mm_sel    : out std_logic_vector(15 downto 0);
    mm_req    : out std_logic;
    mm_addr   : out std_logic_vector(15 downto 0);
    mm_wdata  : out std_logic_vector(31 downto 0);
    mm_wstrb  : out std_logic_vector(3 downto 0);
    mm_rdata  : in  std_logic_vector(16 * 32 - 1 downto 0);
    irq_ip    : in  std_logic_vector(15 downto 0);
    -- AXI4-Lite 32 bit
    l_awaddr  : out std_logic_vector(31 downto 0);
    l_awprot  : out std_logic_vector(2 downto 0);
    l_awvalid : out std_logic;
    l_awready : in  std_logic;
    l_wdata   : out std_logic_vector(31 downto 0);
    l_wstrb   : out std_logic_vector(3 downto 0);
    l_wvalid  : out std_logic;
    l_wready  : in  std_logic;
    l_bresp   : in  std_logic_vector(1 downto 0);
    l_bvalid  : in  std_logic;
    l_bready  : out std_logic;
    l_araddr  : out std_logic_vector(31 downto 0);
    l_arprot  : out std_logic_vector(2 downto 0);
    l_arvalid : out std_logic;
    l_arready : in  std_logic;
    l_rdata   : in  std_logic_vector(31 downto 0);
    l_rresp   : in  std_logic_vector(1 downto 0);
    l_rvalid  : in  std_logic;
    l_rready  : out std_logic;
    -- UART
    uart_tx   : out std_logic;
    uart_rx   : in  std_logic;
    -- traza (simulacion; la sintesis la elimina si no se conecta)
    rvfi_valid     : out std_logic;
    rvfi_pc        : out xword;
    rvfi_insn      : out std_logic_vector(31 downto 0);
    rvfi_rd        : out std_logic_vector(4 downto 0);
    rvfi_rd_wdata  : out xword;
    rvfi_trap      : out std_logic;
    rvfi_cause     : out xword;
    rvfi_tval      : out xword;
    rvfi_mem_addr  : out xword;
    rvfi_mem_wstrb : out std_logic_vector(7 downto 0);
    rvfi_mem_wdata : out xword;
    rvfi_mip       : out xword;
    mtime_o        : out xword
  );
end entity;

architecture rtl of rv64_soc is
  -- AXI4 de la CPU
  signal awid, arid, bid, rid : std_logic_vector(3 downto 0);
  signal awaddr, araddr, wdata, rdata : xword;
  signal awlen, arlen : std_logic_vector(7 downto 0);
  signal awsize, arsize, awprot, arprot : std_logic_vector(2 downto 0);
  signal awburst, arburst, bresp, rresp : std_logic_vector(1 downto 0);
  signal awcache, arcache : std_logic_vector(3 downto 0);
  signal awvalid, awready, wlast, wvalid, wready, bvalid, bready : std_logic;
  signal arvalid, arready, rlast, rvalid, rready : std_logic;
  signal wstrb : std_logic_vector(7 downto 0);
  -- esclavo de perifericos
  signal p_awvalid, p_awready, p_wvalid, p_wready, p_bvalid, p_bready : std_logic;
  signal p_arvalid, p_arready, p_rvalid, p_rready, p_rlast : std_logic;
  signal p_bresp, p_rresp : std_logic_vector(1 downto 0);
  signal p_rdata : xword;
  -- seleccion (0: DRAM, 1: perifericos); una transaccion en vuelo por direccion
  signal rsel, wsel : std_logic;
  signal ar_s, aw_s : std_logic;
  signal mtip, msip, meip, seip : std_logic;
  signal mtime : xword;
begin
  cpu_u : entity work.rv64_cpu generic map (RESET_PC => RESET_PC) port map (
    clk => clk, rst => rst, mtip => mtip, msip => msip, meip => meip, seip => seip, time_i => mtime,
    m_awid => awid, m_awaddr => awaddr, m_awlen => awlen, m_awsize => awsize, m_awburst => awburst,
    m_awcache => awcache, m_awprot => awprot, m_awvalid => awvalid, m_awready => awready,
    m_wdata => wdata, m_wstrb => wstrb, m_wlast => wlast, m_wvalid => wvalid, m_wready => wready,
    m_bid => bid, m_bresp => bresp, m_bvalid => bvalid, m_bready => bready,
    m_arid => arid, m_araddr => araddr, m_arlen => arlen, m_arsize => arsize, m_arburst => arburst,
    m_arcache => arcache, m_arprot => arprot, m_arvalid => arvalid, m_arready => arready,
    m_rid => rid, m_rdata => rdata, m_rresp => rresp, m_rlast => rlast, m_rvalid => rvalid,
    m_rready => rready,
    rvfi_valid => rvfi_valid, rvfi_pc => rvfi_pc, rvfi_insn => rvfi_insn, rvfi_rd => rvfi_rd,
    rvfi_rd_wdata => rvfi_rd_wdata, rvfi_trap => rvfi_trap, rvfi_cause => rvfi_cause,
    rvfi_tval => rvfi_tval, rvfi_mem_addr => rvfi_mem_addr, rvfi_mem_wstrb => rvfi_mem_wstrb,
    rvfi_mem_wdata => rvfi_mem_wdata, rvfi_mip => rvfi_mip);
  mtime_o <= mtime;

  -- ---------------------------------------------------------------- crossbar 1 -> 2
  -- decodificacion por direccion en AR/AW; R/W/B siguen a la ultima seleccion aceptada
  ar_s <= '0' when pma_dram(araddr) else '1';
  aw_s <= '0' when pma_dram(awaddr) else '1';
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then rsel <= '0'; wsel <= '0';
      else
        if arvalid = '1' and arready = '1' then rsel <= ar_s; end if;
        if awvalid = '1' and awready = '1' then wsel <= aw_s; end if;
      end if;
    end if;
  end process;

  dram_arid <= arid; dram_araddr <= araddr; dram_arlen <= arlen; dram_arsize <= arsize;
  dram_arburst <= arburst; dram_arcache <= arcache; dram_arprot <= arprot;
  dram_arvalid <= arvalid and not ar_s;
  p_arvalid    <= arvalid and ar_s;
  arready      <= dram_arready when ar_s = '0' else p_arready;
  rid    <= dram_rid when rsel = '0' else (others => '0');
  rdata  <= dram_rdata when rsel = '0' else p_rdata;
  rresp  <= dram_rresp when rsel = '0' else p_rresp;
  rlast  <= dram_rlast when rsel = '0' else p_rlast;
  rvalid <= dram_rvalid when rsel = '0' else p_rvalid;
  dram_rready <= rready and not rsel;
  p_rready    <= rready and rsel;

  dram_awid <= awid; dram_awaddr <= awaddr; dram_awlen <= awlen; dram_awsize <= awsize;
  dram_awburst <= awburst; dram_awcache <= awcache; dram_awprot <= awprot;
  dram_awvalid <= awvalid and not aw_s;
  p_awvalid    <= awvalid and aw_s;
  awready      <= dram_awready when aw_s = '0' else p_awready;
  dram_wdata <= wdata; dram_wstrb <= wstrb; dram_wlast <= wlast;
  dram_wvalid <= wvalid and not wsel;
  p_wvalid    <= wvalid and wsel;
  wready      <= dram_wready when wsel = '0' else p_wready;
  bid    <= dram_bid when wsel = '0' else (others => '0');
  bresp  <= dram_bresp when wsel = '0' else p_bresp;
  bvalid <= dram_bvalid when wsel = '0' else p_bvalid;
  dram_bready <= bready and not wsel;
  p_bready    <= bready and wsel;

  -- ---------------------------------------------------------------- perifericos
  periph_u : entity work.rv64_periph generic map (TICK_DIV => TICK_DIV) port map (
    clk => clk, rst => rst,
    s_awaddr => awaddr, s_awlen => awlen, s_awsize => awsize, s_awvalid => p_awvalid, s_awready => p_awready,
    s_wdata => wdata, s_wstrb => wstrb, s_wlast => wlast, s_wvalid => p_wvalid, s_wready => p_wready,
    s_bresp => p_bresp, s_bvalid => p_bvalid, s_bready => p_bready,
    s_araddr => araddr, s_arlen => arlen, s_arsize => arsize, s_arvalid => p_arvalid, s_arready => p_arready,
    s_rdata => p_rdata, s_rresp => p_rresp, s_rlast => p_rlast, s_rvalid => p_rvalid, s_rready => p_rready,
    mm_sel => mm_sel, mm_req => mm_req, mm_addr => mm_addr, mm_wdata => mm_wdata, mm_wstrb => mm_wstrb,
    mm_rdata => mm_rdata,
    l_awaddr => l_awaddr, l_awprot => l_awprot, l_awvalid => l_awvalid, l_awready => l_awready,
    l_wdata => l_wdata, l_wstrb => l_wstrb, l_wvalid => l_wvalid, l_wready => l_wready,
    l_bresp => l_bresp, l_bvalid => l_bvalid, l_bready => l_bready,
    l_araddr => l_araddr, l_arprot => l_arprot, l_arvalid => l_arvalid, l_arready => l_arready,
    l_rdata => l_rdata, l_rresp => l_rresp, l_rvalid => l_rvalid, l_rready => l_rready,
    irq_ip => irq_ip, mtip => mtip, msip => msip, meip => meip, seip => seip, mtime => mtime,
    uart_tx => uart_tx, uart_rx => uart_rx);
end architecture;
