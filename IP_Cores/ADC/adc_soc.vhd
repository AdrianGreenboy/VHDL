-- ============================================================================
-- adc_soc.vhd : Cara dmem del ADC delta-sigma soft IP v1 (patron tsn_soc)
-- Esclavo dmem de 1 ciclo (rdata combinacional) para colgar del mem_subsys
-- en 0x6000_0000. Une adc_core (datapath, reset asincrono activo bajo) con
-- adc_mmio (banco + FIFO, reset sincrono activo alto): cada sample_valid
-- empuja {0x00, muestra Q1.23} a la FIFO.
-- Los registros DMA del IP (0x20/0x24/0x28) quedan como hooks para
-- integracion standalone; en el SoC v3 el movimiento a DDR usa el
-- dma_burst del mem_subsys (patron de la familia): dma_busy_i='0'.
-- DBG_STATE (0x44): [31:24]=0xAD, [16]=ext_timeout, [10:0]=nivel FIFO.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_soc is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;  -- sincrono, activo alto
    sel     : in  std_logic;
    we      : in  std_logic;
    addr    : in  std_logic_vector(7 downto 0);
    wdata   : in  std_logic_vector(31 downto 0);
    rdata   : out std_logic_vector(31 downto 0);
    ready   : out std_logic;
    irq     : out std_logic;
    -- hook B hacia pines (v2): comparador LVDS + realimentacion RC
    pdm_ext_i : in  std_logic;
    pdm_clk_i : in  std_logic := '0';   -- AUDIT 2026-11: modulator bit clock
    pdm_fb_o  : out std_logic
  );
end entity adc_soc;

architecture rtl of adc_soc is
  signal aresetn   : std_logic;
  signal enable_w  : std_logic;
  signal src_w     : std_logic;
  signal osr_w     : std_logic_vector(1 downto 0);
  signal finc_w    : std_logic_vector(31 downto 0);
  signal tout_w    : std_logic;
  signal smp_w     : std_logic_vector(23 downto 0);
  signal smp_v     : std_logic;
  signal push_word : std_logic_vector(31 downto 0);
  signal dbg_w     : std_logic_vector(31 downto 0);
  signal rst_m, rst_s : std_logic := '1';           -- AUDIT: reset synchronizer
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of rst_m, rst_s : signal is "TRUE";
  signal extclk_w, extovr_w, ready_w : std_logic;
begin

  -- AUDIT 2026-11: 2-flop reset synchronizer at the ADC top (assert and
  -- release synchronous to clk, 2 cycles), feeding both the synchronous
  -- active-high reset of the MMIO side and the async active-low reset of the
  -- datapath (which is therefore released synchronously as well).
  proc_rst : process (clk)
  begin
    if rising_edge(clk) then
      rst_m <= rst;
      rst_s <= rst_m;
    end if;
  end process proc_rst;

  aresetn <= not rst_s;

  u_core : entity work.adc_core
    port map (
      clk            => clk,
      aresetn        => aresetn,
      en_i           => enable_w,
      src_sel_i      => src_w,
      finc_i         => finc_w,
      osr_sel_i      => osr_w,
      pdm_ext_i      => pdm_ext_i,
      pdm_clk_i      => pdm_clk_i,
      ext_clk_i      => extclk_w,
      ext_ovr_o      => extovr_w,
      pdm_fb_o       => pdm_fb_o,
      ext_timeout_o  => tout_w,
      sample_o       => smp_w,
      sample_valid_o => smp_v
    );

  -- etiqueta de canal (v1: canal unico 0x00) + muestra Q1.23
  push_word <= x"00" & smp_w;

  u_mmio : entity work.adc_mmio
    port map (
      clk           => clk,
      rst           => rst_s,
      sel           => sel,
      we            => we,
      addr          => addr,
      wdata         => wdata,
      rdata         => rdata,
      irq           => irq,
      smp_push_i    => smp_v,
      smp_word_i    => push_word,
      enable        => enable_w,
      src_sel       => src_w,
      osr_sel       => osr_w,
      finc          => finc_w,
      ext_timeout_i => tout_w,
      dma_addr      => open,
      dma_len       => open,
      dma_go        => open,
      dma_busy_i    => '0',
      dma_done_p_i  => '0',
      dma_fifo_rd_i => '0',
      fifo_rdata_o  => open,
      fifo_empty_o  => open,
      dbg_i         => dbg_w,
      ready         => ready_w,
      ext_ovr_i     => extovr_w,
      ext_clk       => extclk_w
    );

  -- DBG_STATE: firma 0xAD + timeout en bit 16; [15:0] reservado 0 en v1
  -- (solo diagnostico en silicio; no forma parte del vector del oraculo)
  dbg_w <= x"AD" & "0000000" & tout_w & x"0000";

  ready <= ready_w;

end architecture rtl;
