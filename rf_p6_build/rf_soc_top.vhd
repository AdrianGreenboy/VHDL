-- rf_soc_top.vhd - Top del SoC RF (capa 4). Integra:
--   core RV32IM -> decodificador de memoria (dmem scratch vs MMIO 0x60000000)
--   -> banco rf_regs -> RX/TX word_fifo -> datapath RF (NCO+loopmix+CIC+FIR+AGC)
--   -> DMA maestro dma_burst -> puerto de escritura a DDR (0x70000000).
-- El core ve dmem con lectura COMBINACIONAL. Los accesos a 0x6xxxxxxx van al
-- banco; los de 0x0xxxxxxx a la scratch RAM. La escritura de DMA_CTRL dispara el
-- DMA, que drena la RX FIFO a DDR. El puerto ddr_wr_* se expone al TB (BFM DDR).
-- El lazo RF se auto-alimenta con banda base DC cuando rx_en=1 (fuente interna
-- de estimulo para la captura; en el SoC real vendria del ADC).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_soc_top is
  port (
    clk_i     : in  std_logic;
    aresetn_i : in  std_logic;
    -- imem (cargado por el TB)
    imem_addr_o : out std_logic_vector(31 downto 0);
    imem_data_i : in  std_logic_vector(31 downto 0);
    -- scratch dmem (en el TB)
    dm_addr_o  : out std_logic_vector(31 downto 0);
    dm_wdata_o : out std_logic_vector(31 downto 0);
    dm_we_o    : out std_logic;
    dm_rdata_i : in  std_logic_vector(31 downto 0);
    -- DDR write port (al BFM del TB)
    ddr_wr_en_o   : out std_logic;
    ddr_wr_addr_o : out std_logic_vector(31 downto 0);
    ddr_wr_data_o : out std_logic_vector(31 downto 0);
    halt_o     : out std_logic
  );
end entity rf_soc_top;

architecture rtl of rf_soc_top is
  -- core <-> memoria
  signal c_dmem_addr, c_dmem_wdata, c_dmem_rdata : std_logic_vector(31 downto 0);
  signal c_dmem_we, c_dmem_re : std_logic;
  signal c_dmem_be : std_logic_vector(3 downto 0);

  signal is_mmio, is_ddr : std_logic;
  signal mmio_we, mmio_re : std_logic;
  signal mmio_rdata : std_logic_vector(31 downto 0);

  -- banco
  signal rx_en,tx_en,loop_en,agc_en,nco_reset,coef_we,irq : std_logic;
  signal ftw : std_logic_vector(31 downto 0);
  signal shm : std_logic_vector(2 downto 0);
  signal thh, thl : std_logic_vector(15 downto 0);
  signal cfa : std_logic_vector(3 downto 0);
  signal cfd : std_logic_vector(15 downto 0);
  signal rssi : std_logic_vector(15 downto 0);
  signal dma_addr, dma_len, dma_ctrl : std_logic_vector(31 downto 0);

  -- RX FIFO
  signal rxf_wr_en, rxf_rd_en_mmio, rxf_rd_en_dma, rxf_rd_en : std_logic;
  signal rxf_wr_data, rxf_rd_data : std_logic_vector(31 downto 0);
  signal rxf_empty, rxf_full : std_logic;
  signal rxf_level : unsigned(9 downto 0);
  -- TX FIFO
  signal txf_wr_en : std_logic;
  signal txf_wr_data : std_logic_vector(31 downto 0);
  signal txf_empty, txf_full : std_logic;
  signal txf_level : unsigned(9 downto 0);

  -- datapath RF
  signal nco_en, nco_v : std_logic;
  signal nco_s, nco_c : std_logic_vector(15 downto 0);
  signal txfir_vin : std_logic;
  signal bb_i, bb_q : std_logic_vector(15 downto 0);
  signal zcwe : std_logic := '0';
  signal zca : std_logic_vector(3 downto 0) := (others=>'0');
  signal zcd : std_logic_vector(15 downto 0) := (others=>'0');
  signal txfir_i, txfir_q : std_logic_vector(15 downto 0);
  signal txfir_v : std_logic;
  signal itp_i, itp_q : std_logic_vector(15 downto 0);
  signal itp_v : std_logic;
  signal itpd_i, itpd_q : std_logic_vector(15 downto 0) := (others=>'0');
  signal itpd_v : std_logic := '0';
  signal rf_i, rf_q, lm_i, lm_q : std_logic_vector(15 downto 0);
  signal lm_v : std_logic;
  signal dec_i, dec_q : std_logic_vector(15 downto 0);
  signal dec_v : std_logic;
  signal rxfir_i, rxfir_q : std_logic_vector(15 downto 0);
  signal rxfir_v : std_logic;
  signal agc_i, agc_q : std_logic_vector(15 downto 0);
  signal agc_v : std_logic;
  constant SEL : std_logic_vector(2 downto 0) := "001";

  -- generador de estimulo (banda base DC) mientras rx_en
  signal gap_r : unsigned(3 downto 0) := (others=>'0');

  -- DMA
  signal dma_start, dma_busy, dma_done : std_logic;
  signal dma_wr_en : std_logic;
  signal dma_wr_addr, dma_wr_data : std_logic_vector(31 downto 0);
  signal dma_ctrl_prev : std_logic := '0';
begin

  ---------------------------------------------------------------------------
  -- Core
  ---------------------------------------------------------------------------
  u_core : entity work.rv32im_core
    generic map (IMEM_WORDS => 256)
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i,
              imem_addr_o=>imem_addr_o, imem_data_i=>imem_data_i,
              dmem_addr_o=>c_dmem_addr, dmem_wdata_o=>c_dmem_wdata, dmem_we_o=>c_dmem_we,
              dmem_re_o=>c_dmem_re, dmem_be_o=>c_dmem_be, dmem_rdata_i=>c_dmem_rdata,
              halt_o=>halt_o);

  -- decodificacion de memoria
  is_mmio <= '1' when c_dmem_addr(31 downto 28) = x"6" else '0';
  is_ddr  <= '1' when c_dmem_addr(31 downto 28) = x"7" else '0';

  mmio_we <= c_dmem_we and is_mmio;
  mmio_re <= c_dmem_re and is_mmio;

  -- scratch dmem (fuera del top): solo cuando no es MMIO ni DDR
  dm_addr_o  <= c_dmem_addr;
  dm_wdata_o <= c_dmem_wdata;
  dm_we_o    <= c_dmem_we and not is_mmio and not is_ddr;

  -- rdata combinacional multiplexado hacia el core
  c_dmem_rdata <= mmio_rdata when is_mmio = '1' else dm_rdata_i;

  ---------------------------------------------------------------------------
  -- Banco de registros
  ---------------------------------------------------------------------------
  u_regs : entity work.rf_regs
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i,
              we_i=>mmio_we, re_i=>mmio_re, addr_i=>c_dmem_addr(7 downto 0),
              wdata_i=>c_dmem_wdata, rdata_o=>mmio_rdata,
              rx_en_o=>rx_en, tx_en_o=>tx_en, loop_en_o=>loop_en, agc_en_o=>agc_en,
              nco_reset_o=>nco_reset, ftw_o=>ftw, shift_man_o=>shm,
              th_high_o=>thh, th_low_o=>thl, coef_we_o=>coef_we,
              coef_addr_o=>cfa, coef_data_o=>cfd,
              rssi_i=>rssi, dbg_state_i=>x"C0FFEE00",
              rxf_rd_en_o=>rxf_rd_en_mmio, rxf_rd_data_i=>rxf_rd_data, rxf_empty_i=>rxf_empty,
              rxf_full_i=>rxf_full, rxf_level_i=>std_logic_vector(rxf_level),
              txf_wr_en_o=>txf_wr_en, txf_wr_data_o=>txf_wr_data,
              txf_empty_i=>txf_empty, txf_full_i=>txf_full,
              irq_o=>irq, dma_addr_o=>dma_addr, dma_len_o=>dma_len, dma_ctrl_o=>dma_ctrl);

  ---------------------------------------------------------------------------
  -- Datapath RF (auto-estimulo banda base DC mientras rx_en)
  ---------------------------------------------------------------------------
  nco_en <= itp_v;

  proc_stim : process (clk_i, aresetn_i)
  begin
    if aresetn_i = '0' then
      txfir_vin <= '0'; bb_i <= (others=>'0'); bb_q <= (others=>'0'); gap_r <= (others=>'0');
    elsif rising_edge(clk_i) then
      txfir_vin <= '0';
      if rx_en = '1' then
        if gap_r = 0 then
          bb_i <= std_logic_vector(to_signed(20000,16));
          bb_q <= (others=>'0');
          txfir_vin <= '1';
          gap_r <= to_unsigned(8-1, 4);   -- un push cada R=8 ciclos
        else
          gap_r <= gap_r - 1;
        end if;
      end if;
    end if;
  end process proc_stim;

  proc_align : process (clk_i) is
  begin
    if rising_edge(clk_i) then
      itpd_i <= itp_i; itpd_q <= itp_q; itpd_v <= itp_v;
    end if;
  end process proc_align;

  u_nco : entity work.rf_nco
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, en_i=>nco_en, ftw_i=>ftw,
              sin_o=>nco_s, cos_o=>nco_c, valid_o=>nco_v);
  -- TX FIR de compensacion: en v1 es passthrough, se omite del lazo (no-op
  -- funcional). El interpolador toma la banda base directamente. El generador de
  -- estimulo marca txfir_v-equivalente con su propio strobe.
  u_txfir : entity work.rf_fir
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>'0', i_i=>(others=>'0'), q_i=>(others=>'0'),
              coef_we_i=>zcwe, coef_addr_i=>zca, coef_data_i=>zcd,
              i_o=>txfir_i, q_o=>txfir_q, valid_o=>txfir_v);
  u_int : entity work.rf_cic_int
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>txfir_vin, i_i=>bb_i, q_i=>bb_q,
              int_sel_i=>SEL, i_o=>itp_i, q_o=>itp_q, valid_o=>itp_v);
  u_lm : entity work.rf_loopmix
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>itpd_v, loop_en_i=>'1',
              i_i=>itpd_i, q_i=>itpd_q, sin_i=>nco_s, cos_i=>nco_c,
              rf_i_o=>rf_i, rf_q_o=>rf_q, i_o=>lm_i, q_o=>lm_q, valid_o=>lm_v);
  u_dec : entity work.rf_cic_dec
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>lm_v, i_i=>lm_i, q_i=>lm_q,
              dec_sel_i=>SEL, i_o=>dec_i, q_o=>dec_q, valid_o=>dec_v);
  u_rxfir : entity work.rf_fir
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>dec_v, i_i=>dec_i, q_i=>dec_q,
              coef_we_i=>coef_we, coef_addr_i=>cfa, coef_data_i=>cfd,
              i_o=>rxfir_i, q_o=>rxfir_q, valid_o=>rxfir_v);
  u_agc : entity work.rf_agc
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, clr_i=>'0', valid_i=>rxfir_v,
              i_i=>rxfir_i, q_i=>rxfir_q, agc_en_i=>'0', shift_man_i=>"000",
              th_high_i=>x"FFFF", th_low_i=>x"0000",
              i_o=>agc_i, q_o=>agc_q, rssi_o=>rssi, valid_o=>agc_v);

  rxf_wr_en   <= agc_v;
  rxf_wr_data <= agc_i & agc_q;
  rxf_rd_en   <= rxf_rd_en_mmio or rxf_rd_en_dma;

  u_rxf : entity work.word_fifo
    generic map (LOG2_DEPTH=>9)
    port map (clk=>clk_i, aresetn=>aresetn_i, wr_en=>rxf_wr_en, wr_data=>rxf_wr_data,
              full=>rxf_full, rd_en=>rxf_rd_en, rd_data=>rxf_rd_data,
              empty=>rxf_empty, level=>rxf_level);

  u_txf : entity work.word_fifo
    generic map (LOG2_DEPTH=>9)
    port map (clk=>clk_i, aresetn=>aresetn_i, wr_en=>txf_wr_en, wr_data=>txf_wr_data,
              full=>txf_full, rd_en=>'0', rd_data=>open,
              empty=>txf_empty, level=>txf_level);

  ---------------------------------------------------------------------------
  -- DMA: se dispara con flanco de subida de DMA_CTRL bit0
  ---------------------------------------------------------------------------
  proc_dmatrig : process (clk_i, aresetn_i)
  begin
    if aresetn_i = '0' then
      dma_ctrl_prev <= '0';
    elsif rising_edge(clk_i) then
      dma_ctrl_prev <= dma_ctrl(0);
    end if;
  end process proc_dmatrig;
  dma_start <= dma_ctrl(0) and not dma_ctrl_prev;

  u_dma : entity work.dma_burst
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, start_i=>dma_start,
              addr_i=>dma_addr, len_i=>dma_len,
              fifo_rd_en_o=>rxf_rd_en_dma, fifo_rd_data_i=>rxf_rd_data, fifo_empty_i=>rxf_empty,
              wr_en_o=>dma_wr_en, wr_addr_o=>dma_wr_addr, wr_data_o=>dma_wr_data,
              busy_o=>dma_busy, burst_start_o=>open, burst_len_o=>open, done_o=>dma_done);

  ddr_wr_en_o   <= dma_wr_en;
  ddr_wr_addr_o <= dma_wr_addr;
  ddr_wr_data_o <= dma_wr_data;

end architecture rtl;
