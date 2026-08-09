-- ecc_soc_top.vhd - SoC de Layer 4 del ECC scrubber. Core 20 HERCOSSNUX.
-- RV32 pipeline (cpu_pipeline) + RAM local (datos/stack del firmware) + regbank
-- del scrubber como slave MMIO. Ruteo del dmem:
--   addr(31)='0' -> RAM local (dp_ram), 1 ciclo
--   addr(31)='1' -> regbank del scrubber (0x8000_0000): registros + ventana datos
-- La IMEM se precarga con el firmware (ecc_fw.mem). La RAM local se precarga con
-- la palabra de config en la posicion 0 (cfg: bit0 = correr scrub).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity ecc_soc_top is
  generic (
    DEPTH      : natural := 256;         -- palabras IMEM y RAM local
    SCRUB_DEPTH: natural := 32;          -- palabras de la region protegida
    IMEM_INIT  : string  := "ecc_fw.mem";
    LOCAL_INIT : string  := "";          -- config del firmware (palabra 0)
    DONE_WORD  : natural := 127
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;
    irq_out : out std_logic;
    dbg_pc  : out word_t;
    -- sonda de RAM local (lectura para el TB): dirige por byte-addr, lee word
    dbg_local_addr  : in  word_t := (others => '0');
    dbg_local_rdata : out word_t
  );
end entity;

architecture rtl of ecc_soc_top is
  signal cpu_rst : std_logic;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  -- RAM local
  signal loc_rdata : word_t;
  signal loc_wstrb : std_logic_vector(3 downto 0);

  -- regbank scrubber
  signal rb_sel, rb_wr, rb_ready : std_logic;
  signal rb_rdata : std_logic_vector(31 downto 0);

  signal is_mmio : std_logic;
  signal done_pulse : std_logic;
begin

  cpu_rst <= not aresetn;

  is_mmio <= dmem_addr(31);   -- '1' -> scrubber MMIO, '0' -> RAM local

  u_cpu : entity work.cpu_pipeline
    port map (
      clk => aclk, rst => cpu_rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dmem_req => dmem_req, dmem_ready => dmem_ready,
      irq_timer => '0', irq_soft => '0', irq_ext => '0',
      dbg_reg_addr => "00000", dbg_reg_data => open, dbg_pc => dbg_pc
    );

  u_imem : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => IMEM_INIT)
    port map (
      clk => aclk,
      cpu_addr => imem_addr, cpu_wdata => ZERO_WORD, cpu_wstrb => "0000",
      cpu_rdata => imem_instr,
      axi_addr => ZERO_WORD, axi_wdata => ZERO_WORD, axi_wstrb => "0000",
      axi_rdata => open, axi_owns => '0'
    );

  -- RAM local: escribe solo si el acceso NO es MMIO
  loc_wstrb <= dmem_wstrb when is_mmio = '0' else "0000";
  u_local : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => LOCAL_INIT)
    port map (
      clk => aclk,
      cpu_addr => dmem_addr, cpu_wdata => dmem_wdata, cpu_wstrb => loc_wstrb,
      cpu_rdata => loc_rdata,
      axi_addr => dbg_local_addr, axi_wdata => ZERO_WORD, axi_wstrb => "0000",
      axi_rdata => dbg_local_rdata, axi_owns => '0'
    );

  -- regbank del scrubber
  rb_sel <= dmem_req and is_mmio;
  rb_wr  <= '1' when (dmem_wstrb /= "0000") else '0';
  u_scrub : entity work.ecc_regbank
    generic map (DEPTH => SCRUB_DEPTH, INITFILE => "layer4_init.txt")
    port map (
      clk => aclk, rst => cpu_rst,
      sel => rb_sel, wr => rb_wr,
      addr => dmem_addr(15 downto 0),
      wdata => dmem_wdata, rdata => rb_rdata, ready => rb_ready
    );

  -- mux de lectura y ready
  dmem_rdata <= rb_rdata when is_mmio = '1' else loc_rdata;
  dmem_ready <= rb_ready when is_mmio = '1' else '1';

  -- doorbell: escritura a la palabra DONE_WORD de la RAM local
  done_pulse <= '1' when (dmem_wstrb /= "0000" and is_mmio = '0' and
                unsigned(dmem_addr(15 downto 2)) = to_unsigned(DONE_WORD, 14))
                else '0';
  irq_out <= done_pulse;

end architecture;
