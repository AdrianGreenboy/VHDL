-- =============================================================================
--  tb_spw_soc.vhd  -  Integracion completa: RV32 + mem_subsys_spw + spw_mmio
--  Licencia: MIT
--
--  El programa spw_test.mem corre en el core y maneja el IP SpaceWire por
--  MMIO (region 0xB000_0000): bring-up del enlace en LOOP_INT hasta Run,
--  datos + EOP con pop-on-read, time-code, rafaga de 16 bytes con XOR,
--  re-arranque a 50 Mbit/s; al final reporta 16 palabras a la DDR del SoC
--  con el dma_burst.
--
--  Todo el trafico SpaceWire es interno (LOOP_INT en CTRL[4]): un codec en
--  self-loopback con los pads liberados. El TB espera el doorbell
--  (DDRcpu[3] = 1337) y verifica:
--    DDRcpu[0]  = 1      (sticky RUNOK tras el bring-up)
--    DDRcpu[1]  = 0xA5   (primer dato del loopback)
--    DDRcpu[2]  = 0x5A   (segundo dato)
--    DDRcpu[4]  = 0x100  (EOP: b8=1, b0=0)
--    DDRcpu[5]  = 0x3C   (time-code recibido)
--    DDRcpu[6]  = 1      (contador de ticks)
--    DDRcpu[7]  = 0x10   (XOR de la rafaga 1..16)
--    DDRcpu[8]  = 5      (estado del enlace = Run)
--    DDRcpu[9]  = 0      (RX_AVAIL = 0: FIFO vacio al final)
--    DDRcpu[10] = 0xC3   (byte de ida y vuelta a 50 Mbit/s tras parchear DIV)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_spw_soc is
end entity tb_spw_soc;

architecture sim of tb_spw_soc is
  constant TCK    : time    := 10 ns;
  constant AXI_AW : natural := 40;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal aresetn : std_logic;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  -- puerto SPW del subsistema
  signal spw_sel   : std_logic;
  signal spw_addr  : std_logic_vector(7 downto 0);
  signal spw_rdata : word_t;
  signal spw_irq   : std_logic;
  signal spw_sel_req, spw_we : std_logic;

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

  -- pads (trafico interno via LOOP_INT: liberados)
  signal spw_dout, spw_sout : std_logic;

  signal cpu_dbg_addr : natural := 0;
  signal cpu_dbg_data : word_t;
begin

  clk <= not clk after TCK/2;
  aresetn <= not rst;

  u_imem : entity work.dp_ram
    generic map (DEPTH => 256, INIT_FILE => "spw_test.mem")
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
      irq_timer => '0', irq_soft => '0', irq_ext => spw_irq,
      dbg_reg_addr => (others => '0'), dbg_reg_data => open, dbg_pc => open
    );

  u_mem : entity work.mem_subsys_spw
    generic map (DEPTH => 256, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => (others => '0'),
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      spw_sel => spw_sel, spw_addr => spw_addr, spw_rdata => spw_rdata,
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

  spw_sel_req <= spw_sel and dmem_req;
  spw_we      <= '1' when dmem_wstrb /= "0000" else '0';

  u_spw : entity work.spw_mmio
    port map (
      clk => clk, rst => rst,
      sel => spw_sel_req, we => spw_we, addr => spw_addr,
      wdata => dmem_wdata, rdata => spw_rdata,
      irq => spw_irq,
      din => '0', sin => '0', dout => spw_dout, sout => spw_sout
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
  begin
    rst <= '1';
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;
    rst <= '0';

    -- doorbell: el programa escribe 1337 en local[3] y lo reporta a DDRcpu[3]
    cpu_dbg_addr <= 3;
    loop
      for i in 1 to 100 loop wait until rising_edge(clk); end loop;
      exit when to_integer(unsigned(cpu_dbg_data)) = 1337;
      timeout := timeout + 1;
      assert timeout < 20000
        report "FALLO: el programa nunca marco el doorbell" severity failure;
    end loop;
    report "doorbell recibido (DDRcpu[3] = 1337)";
    wait for 1 us;                       -- dejar aterrizar el resto de la rafaga

    -- resultados reportados por el programa
    chk_cpu(0,  x"00000001", "fase A sticky RUNOK = 1");
    chk_cpu(1,  x"000000A5", "fase B dato 1 = 0xA5");
    chk_cpu(2,  x"0000005A", "fase B dato 2 = 0x5A");
    chk_cpu(4,  x"00000100", "fase B EOP = 0x100");
    chk_cpu(5,  x"0000003C", "fase C time-code = 0x3C");
    chk_cpu(6,  x"00000001", "fase C contador de ticks = 1");
    chk_cpu(7,  x"00000010", "fase D XOR de la rafaga = 0x10");
    chk_cpu(8,  x"00000005", "fase E estado del enlace = Run");
    chk_cpu(9,  x"00000000", "fase E FIFO RX vacio = 0");
    chk_cpu(10, x"000000C3", "fase F byte a 50 Mbit/s = 0xC3");

    report "TEST PASSED" severity note;
    std.env.finish;
  end process;

end architecture sim;
