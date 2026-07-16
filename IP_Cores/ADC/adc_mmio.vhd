-- ============================================================================
-- adc_mmio.vhd : Subsistema MMIO del ADC delta-sigma soft IP v1
-- adc_regs + adc_fifo cableados. El lado de empuje de la FIFO recibe la
-- muestra etiquetada ([31:24] tag/canal = 0x00 en v1, [23:0] muestra Q1.23);
-- en el top del paso 6 lo alimenta sample_valid de adc_core, en la capa 2
-- lo alimenta el testbench directamente.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_mmio is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;  -- sincrono, activo alto
    -- bus dmem
    sel           : in  std_logic;
    we            : in  std_logic;
    addr          : in  std_logic_vector(7 downto 0);
    wdata         : in  std_logic_vector(31 downto 0);
    rdata         : out std_logic_vector(31 downto 0);
    irq           : out std_logic;
    -- empuje de muestras (del datapath / TB)
    smp_push_i    : in  std_logic;
    smp_word_i    : in  std_logic_vector(31 downto 0);
    -- control hacia adc_core
    enable        : out std_logic;
    src_sel       : out std_logic;
    osr_sel       : out std_logic_vector(1 downto 0);
    finc          : out std_logic_vector(31 downto 0);
    -- estado del datapath
    ext_timeout_i : in  std_logic;
    -- DMA (motor en paso 5)
    dma_addr      : out std_logic_vector(31 downto 0);
    dma_len       : out std_logic_vector(31 downto 0);
    dma_go        : out std_logic;
    dma_busy_i    : in  std_logic;
    dma_done_p_i  : in  std_logic;
    -- acceso del DMA a la FIFO (paso 5; abierto en capa 2)
    dma_fifo_rd_i : in  std_logic;
    fifo_rdata_o  : out std_logic_vector(31 downto 0);
    fifo_empty_o  : out std_logic;
    -- debug
    dbg_i         : in  std_logic_vector(31 downto 0)
  );
end entity adc_mmio;

architecture rtl of adc_mmio is
  signal f_rd    : std_logic;
  signal f_rdata : std_logic_vector(31 downto 0);
  signal f_level : unsigned(10 downto 0);
  signal f_empty : std_logic;
  signal f_full  : std_logic;
  signal mmio_rd : std_logic;
begin

  u_fifo : entity work.adc_fifo
    generic map (
      LOG2_DEPTH => 9
    )
    port map (
      clk     => clk,
      rst     => rst,
      wr_en   => smp_push_i,
      wr_data => smp_word_i,
      rd_en   => f_rd,
      rd_data => f_rdata,
      empty   => f_empty,
      full    => f_full,
      level   => f_level
    );

  -- pop por MMIO o por el motor DMA (paso 5)
  f_rd <= mmio_rd or dma_fifo_rd_i;

  u_regs : entity work.adc_regs
    port map (
      clk           => clk,
      rst           => rst,
      sel           => sel,
      we            => we,
      addr          => addr,
      wdata         => wdata,
      rdata         => rdata,
      irq           => irq,
      enable        => enable,
      src_sel       => src_sel,
      osr_sel       => osr_sel,
      finc          => finc,
      fifo_rd       => mmio_rd,
      fifo_rdata    => f_rdata,
      fifo_level    => f_level(9 downto 0),
      fifo_empty    => f_empty,
      fifo_full     => f_full,
      ext_timeout_i => ext_timeout_i,
      dma_addr      => dma_addr,
      dma_len       => dma_len,
      dma_go        => dma_go,
      dma_busy_i    => dma_busy_i,
      dma_done_p_i  => dma_done_p_i,
      dbg_i         => dbg_i
    );

  fifo_rdata_o <= f_rdata;
  fifo_empty_o <= f_empty;

end architecture rtl;
