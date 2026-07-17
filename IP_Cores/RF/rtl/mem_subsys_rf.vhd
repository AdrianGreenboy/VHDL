-- mem_subsys_rf.vhd - Subsistema de memoria del SoC con el dominio RF integrado.
-- Extiende el patron de mem_subsys_dma de la familia (RAM local en 0x0, DMA de
-- la familia en 0x4) anadiendo el DOMINIO RF en 0x6000_0000: el banco rf_regs,
-- el datapath RF (generador de tono -> cadena DDC -> RX FIFO) y el SEGUNDO
-- maestro AXI (rf_dma_axi) que drena la RX FIFO a la DDR por su propio m_axi_rf
-- (a S07_AXI del NoC). El DMA de la familia y su m_axi quedan intactos.
--
-- Mapa de dmem del core:
--   0x0xxxxxxx (31:30="00")   -> RAM local (dp_ram)
--   0x4xxxxxxx (31:28="0100") -> registros del DMA de la familia
--   0x6xxxxxxx (31:28="0110") -> banco RF (offsets de rf_regs)
-- Lectura de 1 ciclo, rdata combinacional (contrato de la familia).
-- Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity mem_subsys_rf is
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

    -- IRQ del RF (al PS)
    rf_irq_o   : out std_logic;

    -- maestro AXI4 del DMA de la familia (a S06_AXI)
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

    -- SEGUNDO maestro AXI4 del RF (a S07_AXI)
    rf_awaddr  : out std_logic_vector(ADDR_W-1 downto 0);
    rf_awlen   : out std_logic_vector(7 downto 0);
    rf_awsize  : out std_logic_vector(2 downto 0);
    rf_awburst : out std_logic_vector(1 downto 0);
    rf_awvalid : out std_logic;
    rf_awready : in  std_logic;
    rf_wdata   : out std_logic_vector(31 downto 0);
    rf_wstrb   : out std_logic_vector(3 downto 0);
    rf_wlast   : out std_logic;
    rf_wvalid  : out std_logic;
    rf_wready  : in  std_logic;
    rf_bresp   : in  std_logic_vector(1 downto 0);
    rf_bvalid  : in  std_logic;
    rf_bready  : out std_logic;
    rf_araddr  : out std_logic_vector(ADDR_W-1 downto 0);
    rf_arlen   : out std_logic_vector(7 downto 0);
    rf_arsize  : out std_logic_vector(2 downto 0);
    rf_arburst : out std_logic_vector(1 downto 0);
    rf_arvalid : out std_logic;
    rf_arready : in  std_logic;
    rf_rdata   : in  std_logic_vector(31 downto 0);
    rf_rresp   : in  std_logic_vector(1 downto 0);
    rf_rlast   : in  std_logic;
    rf_rvalid  : in  std_logic;
    rf_rready  : out std_logic
  );
end entity mem_subsys_rf;

architecture rtl of mem_subsys_rf is
  signal is_local, is_dmareg, is_rf : std_logic;
  signal loc_rdata  : word_t;
  signal cpu_wstrb  : std_logic_vector(3 downto 0);
  signal dmareg_rdata : word_t;
  signal rf_rdata_bus : word_t;

  -- registros DMA de la familia
  signal dma_src, dma_dst : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_len : std_logic_vector(8 downto 0) := (others => '0');
  signal dma_dir : std_logic := '0';
  signal dma_start, dma_busy : std_logic;
  signal dma_go, busy_sticky, dma_started : std_logic := '0';

  signal dloc_addr  : std_logic_vector(31 downto 0);
  signal dloc_wdata : word_t;
  signal dloc_we    : std_logic;
  signal dloc_rdata : word_t;
  signal dloc_wstrb : std_logic_vector(3 downto 0);

  -- banco RF
  signal rf_we, rf_re : std_logic;
  signal rf_bank_rdata : std_logic_vector(31 downto 0);
  signal rx_en, tx_en, loop_en, agc_en, nco_reset, coef_we, rf_irq : std_logic;
  signal ftw, tone_ftw : std_logic_vector(31 downto 0);
  signal shm : std_logic_vector(2 downto 0);
  signal thh, thl : std_logic_vector(15 downto 0);
  signal cfa : std_logic_vector(3 downto 0);
  signal cfd : std_logic_vector(15 downto 0);
  signal rssi : std_logic_vector(15 downto 0);
  signal rf_dma_addr, rf_dma_len, rf_dma_ctrl : std_logic_vector(31 downto 0);
  signal rf_dma_busy : std_logic;

  -- RX FIFO (compartida entre MMIO y el segundo maestro)
  signal rxf_rd_en_mmio, rxf_rd_en_dma, rxf_rd_en : std_logic;
  signal rxf_rd_data : std_logic_vector(31 downto 0);
  signal rxf_empty, rxf_full : std_logic;
  signal rxf_level : std_logic_vector(9 downto 0);

  -- TX FIFO (solo escritura por MMIO; sin uso en el lazo de bring-up)
  signal txf_wr_en : std_logic;
  signal txf_wr_data : std_logic_vector(31 downto 0);
  signal txf_empty, txf_full : std_logic;
  signal txf_level : unsigned(9 downto 0);
begin

  is_local  <= '1' when dmem_addr(31 downto 30) = "00"   else '0';
  is_dmareg <= '1' when dmem_addr(31 downto 28) = "0100" else '0';
  is_rf     <= '1' when dmem_addr(31 downto 28) = "0110" else '0';

  ---------------------------------------------------------------------------
  -- RAM local + DMA de la familia (identico a mem_subsys_dma)
  ---------------------------------------------------------------------------
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
        if dma_go = '1' then busy_sticky <= '1'; end if;
        if dma_busy = '1' then dma_started <= '1';
        elsif dma_started = '1' then busy_sticky <= '0'; dma_started <= '0';
        end if;
      end if;
    end if;
  end process;

  dmareg_rdata <= (0 => busy_sticky, others => '0')
                  when dmem_addr(7 downto 0) = x"10" else (others => '0');

  ---------------------------------------------------------------------------
  -- Dominio RF (0x6000_0000): banco + datapath + segundo maestro
  ---------------------------------------------------------------------------
  rf_we <= '1' when (is_rf = '1' and dmem_wstrb /= "0000") else '0';
  rf_re <= '1' when (is_rf = '1' and dmem_wstrb = "0000" and dmem_req = '1') else '0';

  u_rfregs : entity work.rf_regs
    port map (
      clk_i=>clk, aresetn_i=>aresetn,
      we_i=>rf_we, re_i=>rf_re, addr_i=>dmem_addr(7 downto 0),
      wdata_i=>dmem_wdata, rdata_o=>rf_bank_rdata,
      rx_en_o=>rx_en, tx_en_o=>tx_en, loop_en_o=>loop_en, agc_en_o=>agc_en,
      nco_reset_o=>nco_reset, ftw_o=>ftw, shift_man_o=>shm,
      th_high_o=>thh, th_low_o=>thl, coef_we_o=>coef_we,
      coef_addr_o=>cfa, coef_data_o=>cfd,
      rssi_i=>rssi, dbg_state_i=>x"C0FFEE00", dma_busy_i=>rf_dma_busy,
      rxf_rd_en_o=>rxf_rd_en_mmio, rxf_rd_data_i=>rxf_rd_data, rxf_empty_i=>rxf_empty,
      rxf_full_i=>rxf_full, rxf_level_i=>rxf_level,
      txf_wr_en_o=>txf_wr_en, txf_wr_data_o=>txf_wr_data,
      txf_empty_i=>txf_empty, txf_full_i=>txf_full,
      irq_o=>rf_irq, dma_addr_o=>rf_dma_addr, dma_len_o=>rf_dma_len, dma_ctrl_o=>rf_dma_ctrl,
      tone_ftw_o=>tone_ftw);

  u_rfdp : entity work.rf_datapath
    port map (
      clk_i=>clk, aresetn_i=>aresetn, rx_en_i=>rx_en,
      ftw_i=>ftw, tone_ftw_i=>tone_ftw,
      coef_we_i=>coef_we, coef_addr_i=>cfa, coef_data_i=>cfd,
      rssi_o=>rssi,
      rxf_rd_en_i=>rxf_rd_en, rxf_rd_data_o=>rxf_rd_data,
      rxf_empty_o=>rxf_empty, rxf_full_o=>rxf_full, rxf_level_o=>rxf_level);

  rxf_rd_en <= rxf_rd_en_mmio or rxf_rd_en_dma;

  -- TX FIFO (presente por completitud del banco; sin uso en bring-up)
  u_txf : entity work.word_fifo
    generic map (LOG2_DEPTH=>9)
    port map (clk=>clk, aresetn=>aresetn, wr_en=>txf_wr_en, wr_data=>txf_wr_data,
              full=>txf_full, rd_en=>'0', rd_data=>open, empty=>txf_empty, level=>txf_level);

  u_rfdma : entity work.rf_dma_axi
    generic map (ADDR_W => ADDR_W)
    port map (
      clk=>clk, aresetn=>aresetn, ddr_base=>ddr_base,
      dma_addr_i=>rf_dma_addr, dma_len_i=>rf_dma_len, dma_ctrl_i=>rf_dma_ctrl,
      busy_o=>rf_dma_busy, done_o=>open,
      fifo_rd_en_o=>rxf_rd_en_dma, fifo_rd_data_i=>rxf_rd_data, fifo_empty_i=>rxf_empty,
      m_axi_awaddr=>rf_awaddr, m_axi_awlen=>rf_awlen, m_axi_awsize=>rf_awsize,
      m_axi_awburst=>rf_awburst, m_axi_awvalid=>rf_awvalid, m_axi_awready=>rf_awready,
      m_axi_wdata=>rf_wdata, m_axi_wstrb=>rf_wstrb, m_axi_wlast=>rf_wlast,
      m_axi_wvalid=>rf_wvalid, m_axi_wready=>rf_wready,
      m_axi_bresp=>rf_bresp, m_axi_bvalid=>rf_bvalid, m_axi_bready=>rf_bready,
      m_axi_araddr=>rf_araddr, m_axi_arlen=>rf_arlen, m_axi_arsize=>rf_arsize,
      m_axi_arburst=>rf_arburst, m_axi_arvalid=>rf_arvalid, m_axi_arready=>rf_arready,
      m_axi_rdata=>rf_rdata, m_axi_rresp=>rf_rresp, m_axi_rlast=>rf_rlast,
      m_axi_rvalid=>rf_rvalid, m_axi_rready=>rf_rready);

  rf_irq_o <= rf_irq;
  rf_rdata_bus <= rf_bank_rdata;

  ---------------------------------------------------------------------------
  -- rdata / ready hacia el core (todo de 1 ciclo, combinacional)
  ---------------------------------------------------------------------------
  dmem_rdata <= loc_rdata    when is_local  = '1' else
                dmareg_rdata when is_dmareg = '1' else
                rf_rdata_bus when is_rf     = '1' else
                (others => '0');
  dmem_ready <= '1';

end architecture rtl;
