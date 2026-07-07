-- =============================================================================
--  mem_subsys.vhd  -  Subsistema de memoria del core: local + maestro AXI
--  Licencia: MIT
--
--  Decodifica cada acceso de datos del core por el bit 31 de la direccion:
--    addr(31) = '0'  -> RAM local (dp_ram), 1 ciclo, dmem_ready siempre '1'
--    addr(31) = '1'  -> maestro AXI4 (DDR externa); congela el core (ready='0')
--                       hasta que la transaccion termina.
--  La direccion AXI = AXI_BASE + addr(30 downto 0) extendido a ADDR_W bits.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity mem_subsys is
  generic (
    DEPTH     : natural := 256;
    INIT_FILE : string  := "";
    ADDR_W    : natural := 40;
    AXI_BASE  : unsigned                       -- base de la DDR en el espacio AXI
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;

    -- lado del core (interfaz dmem + handshake)
    dmem_addr  : in  word_t;
    dmem_wdata : in  word_t;
    dmem_wstrb : in  std_logic_vector(3 downto 0);
    dmem_req   : in  std_logic;
    dmem_rdata : out word_t;
    dmem_ready : out std_logic;

    -- puerto AXI del lado del PS a la RAM local (opcional; tie-off si no se usa)
    loc_axi_addr  : in  word_t := (others => '0');
    loc_axi_wdata : in  word_t := (others => '0');
    loc_axi_wstrb : in  std_logic_vector(3 downto 0) := "0000";
    loc_axi_rdata : out word_t;
    loc_axi_owns  : in  std_logic := '0';

    -- maestro AXI4 hacia la DDR
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
    m_axi_rready  : out std_logic
  );
end entity mem_subsys;

architecture rtl of mem_subsys is
  signal is_axi      : std_logic;
  signal loc_rdata   : word_t;
  signal loc_wstrb   : std_logic_vector(3 downto 0);

  -- interfaz al bridge maestro
  signal mst_req, mst_we, mst_done, mst_busy : std_logic;
  signal mst_addr  : std_logic_vector(ADDR_W-1 downto 0);
  signal mst_rdata : std_logic_vector(31 downto 0);

  type astate_t is (A_IDLE, A_BUSY, A_DONE);
  signal astate : astate_t := A_IDLE;
  signal rdata_lat : word_t := (others => '0');
begin

  is_axi <= dmem_addr(31);

  -- la RAM local solo escribe si el acceso es de region baja
  loc_wstrb <= dmem_wstrb when is_axi = '0' else "0000";

  u_local : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => INIT_FILE)
    port map (
      clk => clk,
      cpu_addr => dmem_addr, cpu_wdata => dmem_wdata, cpu_wstrb => loc_wstrb,
      cpu_rdata => loc_rdata,
      axi_addr => loc_axi_addr, axi_wdata => loc_axi_wdata,
      axi_wstrb => loc_axi_wstrb, axi_rdata => loc_axi_rdata,
      axi_owns => loc_axi_owns
    );

  -- direccion AXI = base + offset (bits 30:0 del acceso del core)
  mst_addr <= std_logic_vector(AXI_BASE + resize(unsigned(dmem_addr(30 downto 0)), ADDR_W));
  mst_we   <= '1' when dmem_wstrb /= "0000" else '0';

  u_master : entity work.axi4_master
    generic map (ADDR_W => ADDR_W)
    port map (
      clk => clk, aresetn => aresetn,
      req => mst_req, we => mst_we, addr => mst_addr,
      wdata => dmem_wdata, wstrb => dmem_wstrb, rdata => mst_rdata,
      done => mst_done, busy => mst_busy,
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

  -- FSM que arranca el maestro una vez y espera el done
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        astate    <= A_IDLE;
        mst_req   <= '0';
        rdata_lat <= (others => '0');
      else
        mst_req <= '0';
        case astate is
          when A_IDLE =>
            if dmem_req = '1' and is_axi = '1' then
              mst_req <= '1';
              astate  <= A_BUSY;
            end if;
          when A_BUSY =>
            if mst_done = '1' then
              rdata_lat <= mst_rdata;
              astate    <= A_DONE;
            end if;
          when A_DONE =>
            astate <= A_IDLE;
        end case;
      end if;
    end if;
  end process;

  -- rdata y ready hacia el core
  dmem_rdata <= rdata_lat when is_axi = '1' else loc_rdata;
  dmem_ready <= '1' when is_axi = '0' else
                '1' when astate = A_DONE else
                '0';

end architecture rtl;
