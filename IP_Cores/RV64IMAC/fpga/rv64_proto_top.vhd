-- rv64_proto_top.vhd - prototipo del SoC RV64IMAC en Versal (TE0950 / VCK190).
-- NO VALIDADO EN SILICIO TODAVIA (Paso 9).
--
--   * Remapeo de la DRAM: el core ve 0x8000_0000 + off; la DDR fisica es
--     DRAM_PHYS + off (reserva no-map del Linux del PS). Fuera de DRAM_SIZE -> se
--     enmascara (la PMA del core ya limita la DRAM).
--   * Banco de control AXI4-Lite para el PS (0xA400_0000, como el RV32IMA):
--       0x00 CTRL    bit0 RUN (suelta el reset del SoC), bit1 RST (lo fuerza)
--       0x04 STATUS  bit0 en marcha
--       0x08 RETIRED_LO / 0x0C RETIRED_HI  instrucciones retiradas
--       0x10 PC      PC del ultimo retiro (32 bits bajos)
--       0x14 DRAM_PHYS (solo lectura, 32 bits bajos)
--       0x40 + 4*n   registro n (0..7) de la UART del lado host (byte en 7:0)
--   * Consola: una segunda UART 16550 (lado host) cruzada con la del SoC
--     (tx->rx, rx<-tx). El cargador del PS la programa con el mismo divisor.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

entity rv64_proto_top is
  generic (
    TICK_DIV  : positive := 50;                        -- 50 MHz / 50 = 1 MHz (DTS)
    DRAM_PHYS : xword := x"0000000070000000";
    DRAM_MASK : xword := x"0000000007FFFFFF"           -- 128 MiB
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    -- DRAM (AXI4 64 bit) hacia el NoC
    m_axi_dram_awid    : out std_logic_vector(3 downto 0);
    m_axi_dram_awaddr  : out std_logic_vector(63 downto 0);
    m_axi_dram_awlen   : out std_logic_vector(7 downto 0);
    m_axi_dram_awsize  : out std_logic_vector(2 downto 0);
    m_axi_dram_awburst : out std_logic_vector(1 downto 0);
    m_axi_dram_awcache : out std_logic_vector(3 downto 0);
    m_axi_dram_awprot  : out std_logic_vector(2 downto 0);
    m_axi_dram_awvalid : out std_logic;
    m_axi_dram_awready : in  std_logic;
    m_axi_dram_wdata   : out std_logic_vector(63 downto 0);
    m_axi_dram_wstrb   : out std_logic_vector(7 downto 0);
    m_axi_dram_wlast   : out std_logic;
    m_axi_dram_wvalid  : out std_logic;
    m_axi_dram_wready  : in  std_logic;
    m_axi_dram_bid     : in  std_logic_vector(3 downto 0);
    m_axi_dram_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_dram_bvalid  : in  std_logic;
    m_axi_dram_bready  : out std_logic;
    m_axi_dram_arid    : out std_logic_vector(3 downto 0);
    m_axi_dram_araddr  : out std_logic_vector(63 downto 0);
    m_axi_dram_arlen   : out std_logic_vector(7 downto 0);
    m_axi_dram_arsize  : out std_logic_vector(2 downto 0);
    m_axi_dram_arburst : out std_logic_vector(1 downto 0);
    m_axi_dram_arcache : out std_logic_vector(3 downto 0);
    m_axi_dram_arprot  : out std_logic_vector(2 downto 0);
    m_axi_dram_arvalid : out std_logic;
    m_axi_dram_arready : in  std_logic;
    m_axi_dram_rid     : in  std_logic_vector(3 downto 0);
    m_axi_dram_rdata   : in  std_logic_vector(63 downto 0);
    m_axi_dram_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_dram_rlast   : in  std_logic;
    m_axi_dram_rvalid  : in  std_logic;
    m_axi_dram_rready  : out std_logic;
    -- banco de control (AXI4-Lite 32 bit, desde M_AXI_FPD)
    s_axi_ctrl_awaddr  : in  std_logic_vector(15 downto 0);
    s_axi_ctrl_awvalid : in  std_logic;
    s_axi_ctrl_awready : out std_logic;
    s_axi_ctrl_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_ctrl_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_ctrl_wvalid  : in  std_logic;
    s_axi_ctrl_wready  : out std_logic;
    s_axi_ctrl_bresp   : out std_logic_vector(1 downto 0);
    s_axi_ctrl_bvalid  : out std_logic;
    s_axi_ctrl_bready  : in  std_logic;
    s_axi_ctrl_araddr  : in  std_logic_vector(15 downto 0);
    s_axi_ctrl_arvalid : in  std_logic;
    s_axi_ctrl_arready : out std_logic;
    s_axi_ctrl_rdata   : out std_logic_vector(31 downto 0);
    s_axi_ctrl_rresp   : out std_logic_vector(1 downto 0);
    s_axi_ctrl_rvalid  : out std_logic;
    s_axi_ctrl_rready  : in  std_logic;
    -- IP_Cores (bus MMIO nativo) y su irq
    mm_sel    : out std_logic_vector(15 downto 0);
    mm_req    : out std_logic;
    mm_addr   : out std_logic_vector(15 downto 0);
    mm_wdata  : out std_logic_vector(31 downto 0);
    mm_wstrb  : out std_logic_vector(3 downto 0);
    mm_rdata  : in  std_logic_vector(511 downto 0);
    irq_ip    : in  std_logic_vector(15 downto 0);
    soc_rst_o : out std_logic                            -- reset del SoC (para las IP_Cores)
  );
end entity;

architecture rtl of rv64_proto_top is
  signal rst_soc  : std_logic;
  signal ctrl_run, ctrl_rst : std_logic;
  signal rst_sync : std_logic_vector(1 downto 0);
  signal awaddr, araddr : xword;
  signal uart_soc_tx, uart_host_tx : std_logic;
  signal rvfi_valid : std_logic;
  signal rvfi_pc : xword;
  signal retired : unsigned(63 downto 0);
  -- UART del lado host
  signal hu_req, hu_we, hu_err, hu_irq : std_logic;
  signal hu_addr : std_logic_vector(2 downto 0);
  signal hu_wdata, hu_rdata : xword;
  -- AXI-Lite
  type cst_t is (C_IDLE, C_WRESP, C_RRESP);
  signal cst : cst_t;
  signal c_rdata : std_logic_vector(31 downto 0);
  -- sin ventana AXI-Lite en el prototipo (DECERR): las IPs Xilinx van por el NoC del PS
  signal l_awready, l_wready, l_arready : std_logic := '0';
begin
  -- reset del SoC: aresetn de la plataforma, o RUN=0, o RST=1; sincronizado
  process (clk)
  begin
    if rising_edge(clk) then
      rst_sync <= rst_sync(0) & ((not aresetn) or (not ctrl_run) or ctrl_rst);
    end if;
  end process;
  rst_soc <= rst_sync(1);
  soc_rst_o <= rst_soc;

  soc_u : entity work.rv64_soc generic map (TICK_DIV => TICK_DIV) port map (
    clk => clk, rst => rst_soc,
    dram_awid => m_axi_dram_awid, dram_awaddr => awaddr, dram_awlen => m_axi_dram_awlen,
    dram_awsize => m_axi_dram_awsize, dram_awburst => m_axi_dram_awburst, dram_awcache => m_axi_dram_awcache,
    dram_awprot => m_axi_dram_awprot, dram_awvalid => m_axi_dram_awvalid, dram_awready => m_axi_dram_awready,
    dram_wdata => m_axi_dram_wdata, dram_wstrb => m_axi_dram_wstrb, dram_wlast => m_axi_dram_wlast,
    dram_wvalid => m_axi_dram_wvalid, dram_wready => m_axi_dram_wready,
    dram_bid => m_axi_dram_bid, dram_bresp => m_axi_dram_bresp, dram_bvalid => m_axi_dram_bvalid,
    dram_bready => m_axi_dram_bready,
    dram_arid => m_axi_dram_arid, dram_araddr => araddr, dram_arlen => m_axi_dram_arlen,
    dram_arsize => m_axi_dram_arsize, dram_arburst => m_axi_dram_arburst, dram_arcache => m_axi_dram_arcache,
    dram_arprot => m_axi_dram_arprot, dram_arvalid => m_axi_dram_arvalid, dram_arready => m_axi_dram_arready,
    dram_rid => m_axi_dram_rid, dram_rdata => m_axi_dram_rdata, dram_rresp => m_axi_dram_rresp,
    dram_rlast => m_axi_dram_rlast, dram_rvalid => m_axi_dram_rvalid, dram_rready => m_axi_dram_rready,
    mm_sel => mm_sel, mm_req => mm_req, mm_addr => mm_addr, mm_wdata => mm_wdata, mm_wstrb => mm_wstrb,
    mm_rdata => mm_rdata, irq_ip => irq_ip,
    l_awaddr => open, l_awprot => open, l_awvalid => open, l_awready => l_awready,
    l_wdata => open, l_wstrb => open, l_wvalid => open, l_wready => l_wready,
    l_bresp => "11", l_bvalid => '1', l_bready => open,
    l_araddr => open, l_arprot => open, l_arvalid => open, l_arready => l_arready,
    l_rdata => (others => '0'), l_rresp => "11", l_rvalid => '1', l_rready => open,
    uart_tx => uart_soc_tx, uart_rx => uart_host_tx,
    rvfi_valid => rvfi_valid, rvfi_pc => rvfi_pc,
    rvfi_insn => open, rvfi_rd => open, rvfi_rd_wdata => open, rvfi_trap => open, rvfi_cause => open,
    rvfi_tval => open, rvfi_mem_addr => open, rvfi_mem_wstrb => open, rvfi_mem_wdata => open,
    rvfi_mip => open, mtime_o => open);

  -- ventana AXI-Lite deshabilitada: aceptar y responder DECERR
  l_awready <= '1'; l_wready <= '1'; l_arready <= '1';

  -- remapeo de la DRAM
  m_axi_dram_awaddr <= std_logic_vector(unsigned(DRAM_PHYS) + unsigned(awaddr and DRAM_MASK));
  m_axi_dram_araddr <= std_logic_vector(unsigned(DRAM_PHYS) + unsigned(araddr and DRAM_MASK));

  -- contador de retiros (visibilidad desde el PS)
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_soc = '1' then retired <= (others => '0');
      elsif rvfi_valid = '1' then retired <= retired + 1; end if;
    end if;
  end process;

  -- UART del lado host, cruzada con la del SoC
  host_uart_u : entity work.rv64_uart port map (
    clk => clk, rst => not aresetn, req => hu_req, we => hu_we, addr => hu_addr, size => "00",
    wdata => hu_wdata, rdata => hu_rdata, err => hu_err, irq => hu_irq,
    tx => uart_host_tx, rx => uart_soc_tx);

  -- ---------------------------------------------------------------- banco de control
  s_axi_ctrl_awready <= '1' when cst = C_IDLE and s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1' else '0';
  s_axi_ctrl_wready  <= '1' when cst = C_IDLE and s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1' else '0';
  s_axi_ctrl_arready <= '1' when cst = C_IDLE and s_axi_ctrl_arvalid = '1' and s_axi_ctrl_awvalid = '0' else '0';
  s_axi_ctrl_bvalid  <= '1' when cst = C_WRESP else '0';
  s_axi_ctrl_bresp   <= "00";
  s_axi_ctrl_rvalid  <= '1' when cst = C_RRESP else '0';
  s_axi_ctrl_rresp   <= "00";
  s_axi_ctrl_rdata   <= c_rdata;

  hu_addr  <= s_axi_ctrl_awaddr(4 downto 2) when s_axi_ctrl_awvalid = '1' else s_axi_ctrl_araddr(4 downto 2);
  hu_wdata <= std_logic_vector(shift_left(resize(unsigned(s_axi_ctrl_wdata(7 downto 0)), 64),
                                          8 * to_integer(unsigned(hu_addr))));
  hu_we    <= '1' when s_axi_ctrl_awvalid = '1' else '0';
  hu_req   <= '1' when cst = C_IDLE and
                       ((s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1' and s_axi_ctrl_awaddr(15 downto 5) = "00000000010") or
                        (s_axi_ctrl_arvalid = '1' and s_axi_ctrl_awvalid = '0' and s_axi_ctrl_araddr(15 downto 5) = "00000000010"))
              else '0';

  process (clk)
    variable a : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        cst <= C_IDLE; ctrl_run <= '0'; ctrl_rst <= '0';
      else
        case cst is
          when C_IDLE =>
            if s_axi_ctrl_awvalid = '1' and s_axi_ctrl_wvalid = '1' then
              a := s_axi_ctrl_awaddr;
              if a = x"0000" then ctrl_run <= s_axi_ctrl_wdata(0); ctrl_rst <= s_axi_ctrl_wdata(1); end if;
              cst <= C_WRESP;
            elsif s_axi_ctrl_arvalid = '1' then
              a := s_axi_ctrl_araddr;
              c_rdata <= (others => '0');
              case a is
                when x"0000" => c_rdata(1 downto 0) <= ctrl_rst & ctrl_run;
                when x"0004" => c_rdata(0) <= not rst_soc;
                when x"0008" => c_rdata <= std_logic_vector(retired(31 downto 0));
                when x"000C" => c_rdata <= std_logic_vector(retired(63 downto 32));
                when x"0010" => c_rdata <= rvfi_pc(31 downto 0);
                when x"0014" => c_rdata <= DRAM_PHYS(31 downto 0);
                when others =>
                  if a(15 downto 5) = "00000000010" then
                    c_rdata(7 downto 0) <= hu_rdata(8 * to_integer(unsigned(a(4 downto 2))) + 7 downto
                                                    8 * to_integer(unsigned(a(4 downto 2))));
                  end if;
              end case;
              cst <= C_RRESP;
            end if;
          when C_WRESP =>
            if s_axi_ctrl_bready = '1' then cst <= C_IDLE; end if;
          when C_RRESP =>
            if s_axi_ctrl_rready = '1' then cst <= C_IDLE; end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
