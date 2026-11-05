-- =============================================================================
--  soc_top_pipe.vhd  -  SoC del TE0950 con core PIPELINE + interrupcion PL->PS
--  Licencia: MIT
--
--  Igual que soc_top pero: (1) instancia cpu_pipeline (mas Fmax), y (2) genera
--  una interrupcion 'irq_out' cuando el core escribe el "doorbell" (palabra 127
--  de la DMEM). El PS puede esperar por interrupcion (UIO) en vez de hacer
--  polling, y limpia el IRQ escribiendo 1 al registro IRQ (offset 0x0C).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity soc_top_pipe is
  generic (
    ADDR_W    : natural := 16;
    DEPTH     : natural := 256;
    IMEM_INIT : string  := "";
    DMEM_INIT : string  := "";
    DONE_WORD : natural := 127;         -- palabra de la DMEM usada como doorbell
    -- audit-2026-11 (defaults = legacy FPGA behaviour):
    --   SYNC_MEM      : IMEM/DMEM with 1-cycle synchronous read (ASIC SRAM /
    --                   BRAM); IMEM_INIT/DMEM_INIT then remain FPGA/sim-only.
    --   BOOT_FROM_ROM : autonomous boot from rv32_bootrom_pkg (boot_loader).
    SYNC_MEM      : boolean := false;
    BOOT_FROM_ROM : boolean := false
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
    s_axi_rready  : in  std_logic;

    irq_out : out std_logic             -- a una PL-PS IRQ del CIPS
  );
end entity soc_top_pipe;

architecture rtl of soc_top_pipe is
  signal cpu_rst        : std_logic;
  signal cpu_hold_reset : std_logic;
  signal axi_owns       : std_logic;
  signal dbg_pc         : word_t;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);

  signal imem_axi_addr, imem_axi_wdata, imem_axi_rdata : word_t;
  signal imem_axi_wstrb : std_logic_vector(3 downto 0);
  signal dmem_axi_addr, dmem_axi_wdata, dmem_axi_rdata : word_t;
  signal dmem_axi_wstrb : std_logic_vector(3 downto 0);

  signal done_pulse : std_logic;
  -- audit-2026-11: boot loader (BOOT_FROM_ROM) and IMEM port mux
  signal ld_busy : std_logic := '0';
  signal ld_addr, ld_wdata : word_t := (others => '0');
  signal ld_wstrb : std_logic_vector(3 downto 0) := "0000";
  signal im_addr, im_wdata : word_t;
  signal im_wstrb : std_logic_vector(3 downto 0);
  signal im_owns  : std_logic;

begin

  cpu_rst <= '1' when (aresetn = '0' or cpu_hold_reset = '1' or ld_busy = '1') else '0';

  -- Boot path. BOOT_FROM_ROM = false: the host loads the IMEM through the
  -- axil_soc window while the core is held (CONTROL.bit0 = 1 at reset).
  -- BOOT_FROM_ROM = true: boot_loader copies rv32_bootrom_pkg into the IMEM
  -- after reset and the core starts on its own (no host needed).
  g_rom : if BOOT_FROM_ROM generate
    u_boot : entity work.boot_loader
      generic map (DEPTH => DEPTH)
      port map (clk => aclk, aresetn => aresetn, busy => ld_busy,
                addr => ld_addr, wdata => ld_wdata, wstrb => ld_wstrb);
  end generate;

  im_addr  <= ld_addr  when ld_busy = '1' else imem_axi_addr;
  im_wdata <= ld_wdata when ld_busy = '1' else imem_axi_wdata;
  im_wstrb <= ld_wstrb when ld_busy = '1' else imem_axi_wstrb;
  im_owns  <= axi_owns or ld_busy;


  -- doorbell: el core escribio la palabra DONE_WORD de la DMEM
  done_pulse <= '1' when (dmem_wstrb /= "0000" and
                 unsigned(dmem_addr(ADDR_W-1 downto 2)) = to_unsigned(DONE_WORD, ADDR_W-2))
                else '0';

  u_cpu : entity work.cpu_pipeline
    generic map (IMEM_SYNC => SYNC_MEM, DMEM_SYNC => SYNC_MEM)
    port map (
      clk => aclk, rst => cpu_rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      irq_timer => '0', irq_soft => '0', irq_ext => '0',
      dbg_reg_addr => "00000", dbg_reg_data => open, dbg_pc => dbg_pc
    );

  u_imem : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => IMEM_INIT, SYNC_READ => SYNC_MEM)
    port map (
      clk => aclk,
      cpu_addr => imem_addr, cpu_wdata => ZERO_WORD, cpu_wstrb => "0000",
      cpu_rdata => imem_instr,
      axi_addr => im_addr, axi_wdata => im_wdata,
      axi_wstrb => im_wstrb, axi_rdata => imem_axi_rdata,
      axi_owns => im_owns
    );

  u_dmem : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => DMEM_INIT, SYNC_READ => SYNC_MEM)
    port map (
      clk => aclk,
      cpu_addr => dmem_addr, cpu_wdata => dmem_wdata, cpu_wstrb => dmem_wstrb,
      cpu_rdata => dmem_rdata,
      axi_addr => dmem_axi_addr, axi_wdata => dmem_axi_wdata,
      axi_wstrb => dmem_axi_wstrb, axi_rdata => dmem_axi_rdata,
      axi_owns => axi_owns
    );

  u_axil : entity work.axil_soc
    generic map (ADDR_W => ADDR_W, MEM_SYNC => SYNC_MEM, BOOT_HALTED => not BOOT_FROM_ROM)
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
      dmem_axi_wstrb => dmem_axi_wstrb, dmem_axi_rdata => dmem_axi_rdata,
      done_pulse => done_pulse, irq_out => irq_out
    );

end architecture rtl;
