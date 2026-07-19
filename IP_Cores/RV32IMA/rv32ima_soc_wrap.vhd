-- =============================================================
-- rv32ima_soc_wrap.vhd - Paso 7b: envoltorio VHDL-93 del top.
--
-- POR QUE EXISTE ESTE FICHERO:
--   Vivado NO acepta un fichero VHDL-2008 como top de referencia
--   de un modulo RTL dentro de un block design:
--     [filemgmt 56-195] ... of type VHDL 2008. This type is not
--     allowed as the top file in the reference.
--   Este envoltorio esta escrito en VHDL-93 (marcalo asi en el
--   proyecto) e instancia el top real, que sigue siendo 2008.
--   Vivado solo exige 93 en el FICHERO DE REFERENCIA; el resto
--   de la jerarquia puede ser 2008 sin problema.
--
-- Ademas los puertos se renombran al convenio de Xilinx
-- (S_AXI_*, M_AXI_*) para que la inferencia automatica de
-- interfaces AXI del BD los agrupe sola, en vez de dejar
-- cuarenta pines sueltos que habria que cablear a mano.
--
-- Los generics se replican para poder ajustarlos desde el BD.
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;

entity rv32ima_soc_wrap is
  generic (
    DDR_BASE_PHYS  : std_logic_vector(31 downto 0) := x"70000000";
    RESET_PC       : std_logic_vector(31 downto 0) := x"83F00000";
    TICK_DIV       : natural := 100;
    UART_FIFO_LOG2 : natural := 12
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    -- ---- AXI4-Lite esclavo: banco de control (desde el PS) ----
    S_AXI_awaddr  : in  std_logic_vector(31 downto 0);
    S_AXI_awvalid : in  std_logic;
    S_AXI_awready : out std_logic;
    S_AXI_wdata   : in  std_logic_vector(31 downto 0);
    S_AXI_wstrb   : in  std_logic_vector(3 downto 0);
    S_AXI_wvalid  : in  std_logic;
    S_AXI_wready  : out std_logic;
    S_AXI_bresp   : out std_logic_vector(1 downto 0);
    S_AXI_bvalid  : out std_logic;
    S_AXI_bready  : in  std_logic;
    S_AXI_araddr  : in  std_logic_vector(31 downto 0);
    S_AXI_arvalid : in  std_logic;
    S_AXI_arready : out std_logic;
    S_AXI_rdata   : out std_logic_vector(31 downto 0);
    S_AXI_rresp   : out std_logic_vector(1 downto 0);
    S_AXI_rvalid  : out std_logic;
    S_AXI_rready  : in  std_logic;

    -- ---- AXI4-Lite maestro: hacia la DDR por el NoC ----
    M_AXI_awaddr  : out std_logic_vector(31 downto 0);
    M_AXI_awvalid : out std_logic;
    M_AXI_awready : in  std_logic;
    M_AXI_wdata   : out std_logic_vector(31 downto 0);
    M_AXI_wstrb   : out std_logic_vector(3 downto 0);
    M_AXI_wvalid  : out std_logic;
    M_AXI_wready  : in  std_logic;
    M_AXI_bresp   : in  std_logic_vector(1 downto 0);
    M_AXI_bvalid  : in  std_logic;
    M_AXI_bready  : out std_logic;
    M_AXI_araddr  : out std_logic_vector(31 downto 0);
    M_AXI_arvalid : out std_logic;
    M_AXI_arready : in  std_logic;
    M_AXI_rdata   : in  std_logic_vector(31 downto 0);
    M_AXI_rresp   : in  std_logic_vector(1 downto 0);
    M_AXI_rvalid  : in  std_logic;
    M_AXI_rready  : out std_logic
  );
end rv32ima_soc_wrap;

architecture wrap of rv32ima_soc_wrap is

  -- declaracion explicita del componente: evita depender de la
  -- visibilidad directa de la entidad 2008 desde este fichero 93
  component rv32ima_soc_top
    generic (
      DDR_BASE_PHYS  : std_logic_vector(31 downto 0);
      RESET_PC       : std_logic_vector(31 downto 0);
      TICK_DIV       : natural;
      UART_FIFO_LOG2 : natural
    );
    port (
      aclk    : in  std_logic;
      aresetn : in  std_logic;
      s_awaddr  : in  std_logic_vector(31 downto 0);
      s_awvalid : in  std_logic;
      s_awready : out std_logic;
      s_wdata   : in  std_logic_vector(31 downto 0);
      s_wstrb   : in  std_logic_vector(3 downto 0);
      s_wvalid  : in  std_logic;
      s_wready  : out std_logic;
      s_bresp   : out std_logic_vector(1 downto 0);
      s_bvalid  : out std_logic;
      s_bready  : in  std_logic;
      s_araddr  : in  std_logic_vector(31 downto 0);
      s_arvalid : in  std_logic;
      s_arready : out std_logic;
      s_rdata   : out std_logic_vector(31 downto 0);
      s_rresp   : out std_logic_vector(1 downto 0);
      s_rvalid  : out std_logic;
      s_rready  : in  std_logic;
      m_awaddr  : out std_logic_vector(31 downto 0);
      m_awvalid : out std_logic;
      m_awready : in  std_logic;
      m_wdata   : out std_logic_vector(31 downto 0);
      m_wstrb   : out std_logic_vector(3 downto 0);
      m_wvalid  : out std_logic;
      m_wready  : in  std_logic;
      m_bresp   : in  std_logic_vector(1 downto 0);
      m_bvalid  : in  std_logic;
      m_bready  : out std_logic;
      m_araddr  : out std_logic_vector(31 downto 0);
      m_arvalid : out std_logic;
      m_arready : in  std_logic;
      m_rdata   : in  std_logic_vector(31 downto 0);
      m_rresp   : in  std_logic_vector(1 downto 0);
      m_rvalid  : in  std_logic;
      m_rready  : out std_logic
    );
  end component;

begin

  u_soc : rv32ima_soc_top
    generic map (
      DDR_BASE_PHYS  => DDR_BASE_PHYS,
      RESET_PC       => RESET_PC,
      TICK_DIV       => TICK_DIV,
      UART_FIFO_LOG2 => UART_FIFO_LOG2
    )
    port map (
      aclk    => aclk,
      aresetn => aresetn,
      s_awaddr  => S_AXI_awaddr,
      s_awvalid => S_AXI_awvalid,
      s_awready => S_AXI_awready,
      s_wdata   => S_AXI_wdata,
      s_wstrb   => S_AXI_wstrb,
      s_wvalid  => S_AXI_wvalid,
      s_wready  => S_AXI_wready,
      s_bresp   => S_AXI_bresp,
      s_bvalid  => S_AXI_bvalid,
      s_bready  => S_AXI_bready,
      s_araddr  => S_AXI_araddr,
      s_arvalid => S_AXI_arvalid,
      s_arready => S_AXI_arready,
      s_rdata   => S_AXI_rdata,
      s_rresp   => S_AXI_rresp,
      s_rvalid  => S_AXI_rvalid,
      s_rready  => S_AXI_rready,
      m_awaddr  => M_AXI_awaddr,
      m_awvalid => M_AXI_awvalid,
      m_awready => M_AXI_awready,
      m_wdata   => M_AXI_wdata,
      m_wstrb   => M_AXI_wstrb,
      m_wvalid  => M_AXI_wvalid,
      m_wready  => M_AXI_wready,
      m_bresp   => M_AXI_bresp,
      m_bvalid  => M_AXI_bvalid,
      m_bready  => M_AXI_bready,
      m_araddr  => M_AXI_araddr,
      m_arvalid => M_AXI_arvalid,
      m_arready => M_AXI_arready,
      m_rdata   => M_AXI_rdata,
      m_rresp   => M_AXI_rresp,
      m_rvalid  => M_AXI_rvalid,
      m_rready  => M_AXI_rready
    );

end wrap;
