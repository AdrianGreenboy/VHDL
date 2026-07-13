-- =============================================================================
--  mem_subsys_dma_adcs.vhd  -  Subsistema DMA (bursts) + IP ADCS (region 0xA)
--  Licencia: MIT
--
--  Variante de familia de mem_subsys_dma.vhd que cuelga el IP ADCS al core:
--    region 0x0000_0000 (31:30 = "00")  -> RAM local, 1 ciclo
--    region 0x4000_0000 (31:28 = "0100")-> registros del dma_burst del SoC
--    region 0xA000_0000 (31:28 = "1010")-> IP ADCS (bus dmem directo, patron A2)
--
--  El ADCS usa el bus dmem de familia (rdata combinacional, ready='1'), NO un
--  maestro AXI-Lite como el PTP: su banco de registros responde en 1 ciclo. Su
--  propio maestro AXI4 hacia DDR (a_axi_*) se expone hacia arriba como SEGUNDO
--  puerto NoC, independiente del m_axi del dma_burst del SoC.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity mem_subsys_dma_adcs is
  generic (
    DEPTH    : natural := 256;
    INIT_FILE: string  := "";
    ADDR_W   : natural := 40
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    ddr_base : in std_logic_vector(ADDR_W-1 downto 0);

    dmem_addr  : in  word_t;
    dmem_wdata : in  word_t;
    dmem_wstrb : in  std_logic_vector(3 downto 0);
    dmem_req   : in  std_logic;
    dmem_rdata : out word_t;
    dmem_ready : out std_logic;

    -- maestro AXI4 del dma_burst del SoC (reporte/doorbell)
    m_axi_awaddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic;
    m_axi_araddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic;

    -- maestro AXI4 propio del IP ADCS (2do puerto NoC), 32-bit addr
    a_axi_araddr  : out std_logic_vector(31 downto 0);
    a_axi_arlen   : out std_logic_vector(7 downto 0);
    a_axi_arsize  : out std_logic_vector(2 downto 0);
    a_axi_arburst : out std_logic_vector(1 downto 0);
    a_axi_arprot  : out std_logic_vector(2 downto 0);
    a_axi_arcache : out std_logic_vector(3 downto 0);
    a_axi_arvalid : out std_logic;
    a_axi_arready : in  std_logic;
    a_axi_rdata   : in  std_logic_vector(31 downto 0);
    a_axi_rresp   : in  std_logic_vector(1 downto 0);
    a_axi_rlast   : in  std_logic;
    a_axi_rvalid  : in  std_logic;
    a_axi_rready  : out std_logic;
    a_axi_awaddr  : out std_logic_vector(31 downto 0);
    a_axi_awlen   : out std_logic_vector(7 downto 0);
    a_axi_awsize  : out std_logic_vector(2 downto 0);
    a_axi_awburst : out std_logic_vector(1 downto 0);
    a_axi_awprot  : out std_logic_vector(2 downto 0);
    a_axi_awcache : out std_logic_vector(3 downto 0);
    a_axi_awvalid : out std_logic;
    a_axi_awready : in  std_logic;
    a_axi_wdata   : out std_logic_vector(31 downto 0);
    a_axi_wstrb   : out std_logic_vector(3 downto 0);
    a_axi_wlast   : out std_logic;
    a_axi_wvalid  : out std_logic;
    a_axi_wready  : in  std_logic;
    a_axi_bresp   : in  std_logic_vector(1 downto 0);
    a_axi_bvalid  : in  std_logic;
    a_axi_bready  : out std_logic;

    adcs_irq : out std_logic
  );
end entity mem_subsys_dma_adcs;

architecture rtl of mem_subsys_dma_adcs is
  signal is_local, is_dmareg, is_adcs : std_logic;
  signal loc_rdata  : word_t;
  signal cpu_wstrb  : std_logic_vector(3 downto 0);
  signal dmareg_rdata : word_t;
  signal adcs_rdata : word_t;
  signal adcs_ready : std_logic;

  -- registros DMA del SoC
  signal dma_src, dma_dst : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_len : std_logic_vector(8 downto 0) := (others => '0');
  signal dma_dir : std_logic := '0';
  signal dma_start, dma_busy : std_logic;
  signal dma_go, busy_sticky, dma_started : std_logic := '0';

  -- puerto DMA <-> RAM local
  signal dloc_addr  : std_logic_vector(31 downto 0);
  signal dloc_wdata : word_t;
  signal dloc_we    : std_logic;
  signal dloc_rdata : word_t;
  signal dloc_wstrb : std_logic_vector(3 downto 0);
begin

  is_local  <= '1' when dmem_addr(31 downto 30) = "00"   else '0';
  is_dmareg <= '1' when dmem_addr(31 downto 28) = "0100" else '0';
  is_adcs   <= '1' when dmem_addr(31 downto 28) = "1010" else '0';   -- 0xA000_0000

  -- deteccion combinacional del "start" del dma_burst (sw a CTRL con bit0=1)
  dma_go <= '1' when (is_dmareg = '1' and dmem_wstrb /= "0000"
                      and dmem_addr(7 downto 0) = x"0C" and dmem_wdata(0) = '1')
            else '0';

  cpu_wstrb <= dmem_wstrb when is_local = '1' else "0000";
  dloc_wstrb <= "1111" when dloc_we = '1' else "0000";

  u_local : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => INIT_FILE)
    port map (
      clk => clk,
      cpu_addr => dmem_addr, cpu_wdata => dmem_wdata, cpu_wstrb => cpu_wstrb,
      cpu_rdata => loc_rdata,
      axi_addr => dloc_addr, axi_wdata => dloc_wdata, axi_wstrb => dloc_wstrb,
      axi_rdata => dloc_rdata, axi_owns => dma_busy
    );

  u_dma : entity work.dma_burst
    generic map (ADDR_W => ADDR_W)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => ddr_base,
      src => dma_src, dst => dma_dst, len => dma_len, dir => dma_dir,
      start => dma_start, busy => dma_busy,
      loc_addr => dloc_addr, loc_wdata => dloc_wdata, loc_we => dloc_we, loc_rdata => dloc_rdata,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen, m_axi_awsize => m_axi_awsize,
      m_axi_awburst => m_axi_awburst, m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb, m_axi_wlast => m_axi_wlast,
      m_axi_wvalid => m_axi_wvalid, m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid, m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen, m_axi_arsize => m_axi_arsize,
      m_axi_arburst => m_axi_arburst, m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp, m_axi_rlast => m_axi_rlast,
      m_axi_rvalid => m_axi_rvalid, m_axi_rready => m_axi_rready
    );

  -- IP ADCS colgado en region 0xA por el bus dmem directo (patron A2).
  -- dmem_sel = dmem_req and is_adcs; rdata combinacional, ready='1'.
  u_adcs : entity work.adcs_accel_top
    port map (
      clk => clk, rst_n => aresetn, irq => adcs_irq,
      dmem_sel => (dmem_req and is_adcs), dmem_addr => dmem_addr,
      dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_rdata => adcs_rdata, dmem_ready => adcs_ready,
      m_axi_araddr => a_axi_araddr, m_axi_arlen => a_axi_arlen,
      m_axi_arsize => a_axi_arsize, m_axi_arburst => a_axi_arburst,
      m_axi_arprot => a_axi_arprot, m_axi_arcache => a_axi_arcache,
      m_axi_arvalid => a_axi_arvalid, m_axi_arready => a_axi_arready,
      m_axi_rdata => a_axi_rdata, m_axi_rresp => a_axi_rresp,
      m_axi_rlast => a_axi_rlast, m_axi_rvalid => a_axi_rvalid,
      m_axi_rready => a_axi_rready,
      m_axi_awaddr => a_axi_awaddr, m_axi_awlen => a_axi_awlen,
      m_axi_awsize => a_axi_awsize, m_axi_awburst => a_axi_awburst,
      m_axi_awprot => a_axi_awprot, m_axi_awcache => a_axi_awcache,
      m_axi_awvalid => a_axi_awvalid, m_axi_awready => a_axi_awready,
      m_axi_wdata => a_axi_wdata, m_axi_wstrb => a_axi_wstrb,
      m_axi_wlast => a_axi_wlast, m_axi_wvalid => a_axi_wvalid,
      m_axi_wready => a_axi_wready,
      m_axi_bresp => a_axi_bresp, m_axi_bvalid => a_axi_bvalid,
      m_axi_bready => a_axi_bready);

  -- escritura de registros del dma_burst + pulso de start + busy pegajoso
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        dma_src <= (others => '0'); dma_dst <= (others => '0');
        dma_len <= (others => '0'); dma_dir <= '0'; dma_start <= '0';
        busy_sticky <= '0'; dma_started <= '0';
      else
        dma_start <= '0';
        if is_dmareg = '1' and dmem_wstrb /= "0000" then
          case dmem_addr(7 downto 0) is
            when x"00" => dma_src <= dmem_wdata;
            when x"04" => dma_dst <= dmem_wdata;
            when x"08" => dma_len <= dmem_wdata(8 downto 0);
            when x"0C" => dma_dir <= dmem_wdata(1);
                          if dmem_wdata(0) = '1' then dma_start <= '1'; end if;
            when others => null;
          end case;
        end if;

        if dma_go = '1' then
          busy_sticky <= '1';
        end if;
        if dma_busy = '1' then
          dma_started <= '1';
        elsif dma_started = '1' then
          busy_sticky <= '0';
          dma_started <= '0';
        end if;
      end if;
    end if;
  end process;

  dmareg_rdata <= (0 => busy_sticky, others => '0')
                  when dmem_addr(7 downto 0) = x"10" else (others => '0');

  -- rdata y ready hacia el core
  dmem_rdata <= loc_rdata    when is_local  = '1' else
                dmareg_rdata when is_dmareg = '1' else
                adcs_rdata   when is_adcs   = '1' else
                (others => '0');
  dmem_ready <= adcs_ready when is_adcs = '1' else '1';

end architecture rtl;
