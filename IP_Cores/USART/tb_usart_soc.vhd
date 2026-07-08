-- =============================================================================
--  tb_usart_soc.vhd  -  Integracion completa: RV32 + mem_subsys_usart +
--                       usart_axi_top
--  Licencia: MIT
--
--  El programa usart_test.mem corre en el core y maneja el USART por MMIO
--  (region 0x6000_0000): fase PIO de 2 bytes en eco por loop_int, fase DMA
--  de 32 bytes con los dos canales CONCURRENTES, y al final reporta sus
--  resultados a la DDR del SoC con el dma_burst.
--
--  Dos DDR falsas, como en el silicio habra dos maestros AXI hacia el NoC:
--    u_ddr_cpu   : destino del dma_burst del SoC (reporte del programa)
--    u_ddr_usart : fuente/destino del DMA del USART (patron en usart_ddr.mem)
--  El eco es interno (loop_int en CTRL[7]): los pads quedan atados. El TB
--  espera el doorbell (DDR_cpu[3] = 1337) y verifica:
--    DDR_cpu[0..2] = {2, 0x5A, 0xC3}          (fase PIO)
--    DDR_usart[64..71] = palabras 0..7 del patron (fase DMA, RXA=0x100)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_usart_soc is
end entity tb_usart_soc;

architecture sim of tb_usart_soc is
  constant TCK    : time    := 10 ns;
  constant AXI_AW : natural := 40;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal aresetn : std_logic;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  -- puerto USART del subsistema
  signal usart_sel   : std_logic;
  signal usart_addr  : std_logic_vector(7 downto 0);
  signal usart_rdata : word_t;
  signal usart_irq   : std_logic;

  -- AXI del dma_burst del SoC -> DDR cpu
  signal c_aw_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal c_aw_len  : std_logic_vector(7 downto 0);
  signal c_aw_size : std_logic_vector(2 downto 0);
  signal c_aw_burst: std_logic_vector(1 downto 0);
  signal c_aw_valid, c_aw_ready : std_logic;
  signal c_w_data  : std_logic_vector(31 downto 0);
  signal c_w_strb  : std_logic_vector(3 downto 0);
  signal c_w_last, c_w_valid, c_w_ready : std_logic;
  signal c_b_resp  : std_logic_vector(1 downto 0);
  signal c_b_valid, c_b_ready : std_logic;
  signal c_ar_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal c_ar_len  : std_logic_vector(7 downto 0);
  signal c_ar_size : std_logic_vector(2 downto 0);
  signal c_ar_burst: std_logic_vector(1 downto 0);
  signal c_ar_valid, c_ar_ready : std_logic;
  signal c_r_data  : std_logic_vector(31 downto 0);
  signal c_r_resp  : std_logic_vector(1 downto 0);
  signal c_r_last, c_r_valid, c_r_ready : std_logic;

  -- AXI del DMA del USART -> DDR usart
  signal u_aw_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal u_aw_len  : std_logic_vector(7 downto 0);
  signal u_aw_size : std_logic_vector(2 downto 0);
  signal u_aw_burst: std_logic_vector(1 downto 0);
  signal u_aw_valid, u_aw_ready : std_logic;
  signal u_w_data  : std_logic_vector(31 downto 0);
  signal u_w_strb  : std_logic_vector(3 downto 0);
  signal u_w_last, u_w_valid, u_w_ready : std_logic;
  signal u_b_resp  : std_logic_vector(1 downto 0);
  signal u_b_valid, u_b_ready : std_logic;
  signal u_ar_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal u_ar_len  : std_logic_vector(7 downto 0);
  signal u_ar_size : std_logic_vector(2 downto 0);
  signal u_ar_burst: std_logic_vector(1 downto 0);
  signal u_ar_valid, u_ar_ready : std_logic;
  signal u_r_data  : std_logic_vector(31 downto 0);
  signal u_r_resp  : std_logic_vector(1 downto 0);
  signal u_r_last, u_r_valid, u_r_ready : std_logic;

  -- pads (eco interno via loop_int: todos atados)
  signal txd, txd_t, rts_n : std_logic;

  signal cpu_dbg_addr : natural := 0;
  signal cpu_dbg_data : word_t;
  signal usr_dbg_addr : natural := 0;
  signal usr_dbg_data : word_t;

  function pat_word(k : natural) return std_logic_vector is
    variable w : std_logic_vector(31 downto 0);
  begin
    w(7 downto 0)   := std_logic_vector(to_unsigned((4*k)     mod 256, 8));
    w(15 downto 8)  := std_logic_vector(to_unsigned((4*k + 1) mod 256, 8));
    w(23 downto 16) := std_logic_vector(to_unsigned((4*k + 2) mod 256, 8));
    w(31 downto 24) := std_logic_vector(to_unsigned((4*k + 3) mod 256, 8));
    return w;
  end function;
begin

  clk <= not clk after TCK/2;
  aresetn <= not rst;

  u_imem : entity work.dp_ram
    generic map (DEPTH => 256, INIT_FILE => "usart_test.mem")
    port map (
      clk => clk,
      cpu_addr => imem_addr, cpu_wdata => ZERO_WORD, cpu_wstrb => "0000",
      cpu_rdata => imem_instr,
      axi_addr => ZERO_WORD, axi_wdata => ZERO_WORD, axi_wstrb => "0000",
      axi_rdata => open, axi_owns => '0'
    );

  u_cpu : entity work.cpu_pipeline
    port map (
      clk => clk, rst => rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dmem_req => dmem_req, dmem_ready => dmem_ready,
      irq_timer => '0', irq_soft => '0', irq_ext => usart_irq,
      dbg_reg_addr => (others => '0'), dbg_reg_data => open, dbg_pc => open
    );

  u_mem : entity work.mem_subsys_usart
    generic map (DEPTH => 256, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => (others => '0'),
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      usart_sel => usart_sel, usart_addr => usart_addr, usart_rdata => usart_rdata,
      m_axi_awaddr => c_aw_addr, m_axi_awlen => c_aw_len, m_axi_awsize => c_aw_size,
      m_axi_awburst => c_aw_burst, m_axi_awvalid => c_aw_valid, m_axi_awready => c_aw_ready,
      m_axi_wdata => c_w_data, m_axi_wstrb => c_w_strb, m_axi_wlast => c_w_last,
      m_axi_wvalid => c_w_valid, m_axi_wready => c_w_ready,
      m_axi_bresp => c_b_resp, m_axi_bvalid => c_b_valid, m_axi_bready => c_b_ready,
      m_axi_araddr => c_ar_addr, m_axi_arlen => c_ar_len, m_axi_arsize => c_ar_size,
      m_axi_arburst => c_ar_burst, m_axi_arvalid => c_ar_valid, m_axi_arready => c_ar_ready,
      m_axi_rdata => c_r_data, m_axi_rresp => c_r_resp, m_axi_rlast => c_r_last,
      m_axi_rvalid => c_r_valid, m_axi_rready => c_r_ready
    );

  u_usart : entity work.usart_axi_top
    generic map (FIFO_LOG2 => 8, ADDR_W => AXI_AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => (others => '0'),
      sel => usart_sel, req => dmem_req, addr => usart_addr,
      wdata => dmem_wdata, wstrb => dmem_wstrb, rdata => usart_rdata,
      irq_out => usart_irq,
      m_axi_awaddr => u_aw_addr, m_axi_awlen => u_aw_len, m_axi_awsize => u_aw_size,
      m_axi_awburst => u_aw_burst, m_axi_awvalid => u_aw_valid, m_axi_awready => u_aw_ready,
      m_axi_wdata => u_w_data, m_axi_wstrb => u_w_strb, m_axi_wlast => u_w_last,
      m_axi_wvalid => u_w_valid, m_axi_wready => u_w_ready,
      m_axi_bresp => u_b_resp, m_axi_bvalid => u_b_valid, m_axi_bready => u_b_ready,
      m_axi_araddr => u_ar_addr, m_axi_arlen => u_ar_len, m_axi_arsize => u_ar_size,
      m_axi_arburst => u_ar_burst, m_axi_arvalid => u_ar_valid, m_axi_arready => u_ar_ready,
      m_axi_rdata => u_r_data, m_axi_rresp => u_r_resp, m_axi_rlast => u_r_last,
      m_axi_rvalid => u_r_valid, m_axi_rready => u_r_ready,
      rxd_i => '1', txd_line_i => '1',
      txd_o => txd, txd_t => txd_t,
      cts_n_i => '0', rts_n_o => rts_n
    );

  u_ddr_cpu : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_awaddr => c_aw_addr, s_axi_awlen => c_aw_len,
      s_axi_awvalid => c_aw_valid, s_axi_awready => c_aw_ready,
      s_axi_wdata => c_w_data, s_axi_wstrb => c_w_strb, s_axi_wlast => c_w_last,
      s_axi_wvalid => c_w_valid, s_axi_wready => c_w_ready,
      s_axi_bresp => c_b_resp, s_axi_bvalid => c_b_valid, s_axi_bready => c_b_ready,
      s_axi_araddr => c_ar_addr, s_axi_arlen => c_ar_len,
      s_axi_arvalid => c_ar_valid, s_axi_arready => c_ar_ready,
      s_axi_rdata => c_r_data, s_axi_rresp => c_r_resp, s_axi_rlast => c_r_last,
      s_axi_rvalid => c_r_valid, s_axi_rready => c_r_ready,
      dbg_addr => cpu_dbg_addr, dbg_data => cpu_dbg_data
    );

  u_ddr_usart : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "usart_ddr.mem")
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_awaddr => u_aw_addr, s_axi_awlen => u_aw_len,
      s_axi_awvalid => u_aw_valid, s_axi_awready => u_aw_ready,
      s_axi_wdata => u_w_data, s_axi_wstrb => u_w_strb, s_axi_wlast => u_w_last,
      s_axi_wvalid => u_w_valid, s_axi_wready => u_w_ready,
      s_axi_bresp => u_b_resp, s_axi_bvalid => u_b_valid, s_axi_bready => u_b_ready,
      s_axi_araddr => u_ar_addr, s_axi_arlen => u_ar_len,
      s_axi_arvalid => u_ar_valid, s_axi_arready => u_ar_ready,
      s_axi_rdata => u_r_data, s_axi_rresp => u_r_resp, s_axi_rlast => u_r_last,
      s_axi_rvalid => u_r_valid, s_axi_rready => u_r_ready,
      dbg_addr => usr_dbg_addr, dbg_data => usr_dbg_data
    );

  stim : process
    variable timeout : natural := 0;

    procedure chk_cpu(widx : natural; exp : std_logic_vector(31 downto 0);
                      msg : string) is
    begin
      cpu_dbg_addr <= widx;
      wait for 1 ns;
      assert cpu_dbg_data = exp
        report msg & ": DDRcpu[" & integer'image(widx) & "] = "
               & to_hstring(cpu_dbg_data) & ", esperaba " & to_hstring(exp)
        severity failure;
      report msg & " OK";
    end procedure;

    procedure chk_usart(widx : natural; exp : std_logic_vector(31 downto 0);
                        msg : string) is
    begin
      usr_dbg_addr <= widx;
      wait for 1 ns;
      assert usr_dbg_data = exp
        report msg & ": DDRusart[" & integer'image(widx) & "] = "
               & to_hstring(usr_dbg_data) & ", esperaba " & to_hstring(exp)
        severity failure;
    end procedure;
  begin
    rst <= '1';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;
    rst <= '0';

    -- doorbell: el programa escribe 1337 en DDRcpu[3] al terminar todo
    cpu_dbg_addr <= 3;
    loop
      for i in 1 to 100 loop wait until rising_edge(clk); end loop;
      exit when to_integer(unsigned(cpu_dbg_data)) = 1337;
      timeout := timeout + 1;
      assert timeout < 5000
        report "TIMEOUT: el programa nunca marco el doorbell" severity failure;
    end loop;
    report "doorbell recibido (DDRcpu[3] = 1337)";

    -- fase PIO reportada por el programa
    chk_cpu(0, x"00000002", "fase PIO rxlvl=2");
    chk_cpu(1, x"0000005A", "fase PIO byte0=0x5A");
    chk_cpu(2, x"000000C3", "fase PIO byte1=0xC3");

    -- fase DMA del USART: eco de 32 bytes en DDRusart[0x100..0x11F]
    for k in 0 to 7 loop
      chk_usart(64 + k, pat_word(k), "fase DMA");
    end loop;
    report "fase DMA: eco concurrente de 32 bytes en DDRusart OK";

    report "TEST PASSED" severity note;
    std.env.finish;
  end process;

end architecture sim;
