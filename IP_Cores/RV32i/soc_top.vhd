-- =============================================================================
--  soc_top.vhd  -  SoC minimo para el TE0950: core RV32IM + IMEM/DMEM + AXI4-Lite
--  Licencia: MIT
--
--  El PS (via AXI4-Lite) carga el programa en IMEM, arranca/detiene el core con
--  el registro CONTROL, y lee resultados de DMEM y el PC de depuracion. Las RAMs
--  admiten precarga por INIT_FILE (para sim, o RAM init en sintesis).
--
--  Integracion en Vivado (TE0950 / Versal): instanciar este modulo como RTL,
--  conectar s_axi_* al AXI4-Lite del CIPS/NoC, aclk/aresetn del PS. La
--  automatizacion CIPS+NoC en 2025.2.1 se hace por GUI (el TCL truena con
--  'mc_type').
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity soc_top is
  generic (
    ADDR_W    : natural := 16;
    DEPTH     : natural := 256;
    IMEM_INIT : string  := "";     -- precarga opcional de IMEM
    DMEM_INIT : string  := ""
  );
  port (
    aclk    : in std_logic;
    aresetn : in std_logic;

    s_axi_awaddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(ADDR_W-1 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic
  );
end entity soc_top;

architecture rtl of soc_top is
  signal cpu_rst        : std_logic;
  signal cpu_hold_reset : std_logic;
  signal axi_owns       : std_logic;
  signal dbg_pc         : word_t;

  -- CPU <-> memorias
  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);

  -- AXI <-> memorias
  signal imem_axi_addr, imem_axi_wdata, imem_axi_rdata : word_t;
  signal imem_axi_wstrb : std_logic_vector(3 downto 0);
  signal dmem_axi_addr, dmem_axi_wdata, dmem_axi_rdata : word_t;
  signal dmem_axi_wstrb : std_logic_vector(3 downto 0);
begin

  -- reset del core: por el PS (aresetn) o por CONTROL.bit0 (halt)
  cpu_rst <= '1' when (aresetn = '0' or cpu_hold_reset = '1') else '0';

  u_cpu : entity work.cpu
    port map (
      clk => aclk, rst => cpu_rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      irq_timer => '0', irq_soft => '0', irq_ext => '0',
      dbg_reg_addr => "00000", dbg_reg_data => open, dbg_pc => dbg_pc
    );

  -- IMEM: el CPU solo lee (cpu_wstrb = 0); el PS escribe cuando axi_owns
  u_imem : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => IMEM_INIT)
    port map (
      clk => aclk,
      cpu_addr => imem_addr, cpu_wdata => ZERO_WORD, cpu_wstrb => "0000",
      cpu_rdata => imem_instr,
      axi_addr => imem_axi_addr, axi_wdata => imem_axi_wdata,
      axi_wstrb => imem_axi_wstrb, axi_rdata => imem_axi_rdata,
      axi_owns => axi_owns
    );

  u_dmem : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => DMEM_INIT)
    port map (
      clk => aclk,
      cpu_addr => dmem_addr, cpu_wdata => dmem_wdata, cpu_wstrb => dmem_wstrb,
      cpu_rdata => dmem_rdata,
      axi_addr => dmem_axi_addr, axi_wdata => dmem_axi_wdata,
      axi_wstrb => dmem_axi_wstrb, axi_rdata => dmem_axi_rdata,
      axi_owns => axi_owns
    );

  u_axil : entity work.axil_soc
    generic map (ADDR_W => ADDR_W)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_axi_awaddr => s_axi_awaddr, s_axi_awvalid => s_axi_awvalid, s_axi_awready => s_axi_awready,
      s_axi_wdata => s_axi_wdata, s_axi_wstrb => s_axi_wstrb, s_axi_wvalid => s_axi_wvalid, s_axi_wready => s_axi_wready,
      s_axi_bresp => s_axi_bresp, s_axi_bvalid => s_axi_bvalid, s_axi_bready => s_axi_bready,
      s_axi_araddr => s_axi_araddr, s_axi_arvalid => s_axi_arvalid, s_axi_arready => s_axi_arready,
      s_axi_rdata => s_axi_rdata, s_axi_rresp => s_axi_rresp, s_axi_rvalid => s_axi_rvalid, s_axi_rready => s_axi_rready,
      cpu_hold_reset => cpu_hold_reset, axi_owns_mem => axi_owns, dbg_pc => dbg_pc,
      imem_axi_addr => imem_axi_addr, imem_axi_wdata => imem_axi_wdata,
      imem_axi_wstrb => imem_axi_wstrb, imem_axi_rdata => imem_axi_rdata,
      dmem_axi_addr => dmem_axi_addr, dmem_axi_wdata => dmem_axi_wdata,
      dmem_axi_wstrb => dmem_axi_wstrb, dmem_axi_rdata => dmem_axi_rdata
    );

end architecture rtl;
