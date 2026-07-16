-- ============================================================================
-- tb_adc_soc.vhd : Capa 4 del ADC delta-sigma soft IP v1
-- SoC completo en simulacion: cpu_pipeline RV32IM ejecutando el firmware
-- real adc_bringup.mem (ensamblado con asm.py) + mem_subsys_adc (RAM local
-- + dma_burst + IP ADC en 0x6000_0000) + axi_ddr_sim como LPDDR4.
-- El firmware drena 64 muestras, escribe la sentinela 0xADC0FEED y copia
-- 65 palabras a DDR[0] por DMA. El TB espera la sentinela en DDR word 64
-- (con watchdog) y compara las 65 palabras bit-identicas contra el oraculo
-- ISS (iss_adc_oracle.txt) mas checksum LFSR-32.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

use work.riscv_pkg.all;

entity tb_adc_soc is
end entity tb_adc_soc;

architecture sim of tb_adc_soc is
  constant TCK    : time := 10 ns;
  constant AXI_AW : natural := 40;
  constant C_WDOG : integer := 400000;  -- ciclos de watchdog

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal aresetn : std_logic;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  signal aw_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal aw_len  : std_logic_vector(7 downto 0);
  signal aw_size : std_logic_vector(2 downto 0);
  signal aw_burst: std_logic_vector(1 downto 0);
  signal aw_valid, aw_ready : std_logic;
  signal w_data  : std_logic_vector(31 downto 0);
  signal w_strb  : std_logic_vector(3 downto 0);
  signal w_last, w_valid, w_ready : std_logic;
  signal b_resp  : std_logic_vector(1 downto 0);
  signal b_valid, b_ready : std_logic;
  signal ar_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal ar_len  : std_logic_vector(7 downto 0);
  signal ar_size : std_logic_vector(2 downto 0);
  signal ar_burst: std_logic_vector(1 downto 0);
  signal ar_valid, ar_ready : std_logic;
  signal r_data  : std_logic_vector(31 downto 0);
  signal r_resp  : std_logic_vector(1 downto 0);
  signal r_last, r_valid, r_ready : std_logic;

  signal ddr_dbg_addr : natural := 0;
  signal ddr_dbg_data : word_t;
begin

  clk <= not clk after TCK/2;
  aresetn <= not rst;

  u_imem : entity work.dp_ram
    generic map (DEPTH => 256, INIT_FILE => "adc_bringup.mem")
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
      irq_timer => '0', irq_soft => '0', irq_ext => '0',
      dbg_reg_addr => "00000", dbg_reg_data => open, dbg_pc => open
    );

  u_mem : entity work.mem_subsys_adc
    generic map (DEPTH => 256, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => (others => '0'),
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      m_axi_awaddr => aw_addr, m_axi_awlen => aw_len, m_axi_awsize => aw_size,
      m_axi_awburst => aw_burst, m_axi_awvalid => aw_valid, m_axi_awready => aw_ready,
      m_axi_wdata => w_data, m_axi_wstrb => w_strb, m_axi_wlast => w_last,
      m_axi_wvalid => w_valid, m_axi_wready => w_ready,
      m_axi_bresp => b_resp, m_axi_bvalid => b_valid, m_axi_bready => b_ready,
      m_axi_araddr => ar_addr, m_axi_arlen => ar_len, m_axi_arsize => ar_size,
      m_axi_arburst => ar_burst, m_axi_arvalid => ar_valid, m_axi_arready => ar_ready,
      m_axi_rdata => r_data, m_axi_rresp => r_resp, m_axi_rlast => r_last,
      m_axi_rvalid => r_valid, m_axi_rready => r_ready
    );

  u_ddr : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_awaddr => aw_addr, s_axi_awlen => aw_len,
      s_axi_awvalid => aw_valid, s_axi_awready => aw_ready,
      s_axi_wdata => w_data, s_axi_wstrb => w_strb, s_axi_wlast => w_last,
      s_axi_wvalid => w_valid, s_axi_wready => w_ready,
      s_axi_bresp => b_resp, s_axi_bvalid => b_valid, s_axi_bready => b_ready,
      s_axi_araddr => ar_addr, s_axi_arlen => ar_len,
      s_axi_arvalid => ar_valid, s_axi_arready => ar_ready,
      s_axi_rdata => r_data, s_axi_rresp => r_resp, s_axi_rlast => r_last,
      s_axi_rvalid => r_valid, s_axi_rready => r_ready,
      dbg_addr => ddr_dbg_addr, dbg_data => ddr_dbg_data
    );

  p_main : process
    file f_or       : text;
    variable v_l    : line;
    variable v_exp  : std_logic_vector(31 downto 0);
    variable v_chk  : unsigned(31 downto 0) := (others => '1');
    variable v_msb  : std_logic;
    variable v_ciclo: integer := 0;
    variable v_ok   : boolean := false;
  begin
    rst <= '1';
    for k in 1 to 8 loop
      wait until rising_edge(clk);
    end loop;
    rst <= '0';

    -- watchdog: esperar la sentinela 0xADC0FEED en DDR word 64
    ddr_dbg_addr <= 64;
    while v_ciclo < C_WDOG loop
      wait until rising_edge(clk);
      v_ciclo := v_ciclo + 1;
      if ddr_dbg_data = x"ADC0FEED" then
        v_ok := true;
        exit;
      end if;
    end loop;
    assert v_ok
      report "FALLO SOC: watchdog, sentinela ausente tras " &
             integer'image(C_WDOG) & " ciclos"
      severity failure;

    -- margen para que asiente el B-channel del ultimo burst
    for k in 1 to 32 loop
      wait until rising_edge(clk);
    end loop;

    -- comparar 65 palabras contra el oraculo ISS
    file_open(f_or, "iss_adc_oracle.txt", read_mode);
    for k in 0 to 64 loop
      ddr_dbg_addr <= k;
      wait until rising_edge(clk);
      wait for 1 ns;
      readline(f_or, v_l);
      hread(v_l, v_exp);
      assert ddr_dbg_data = v_exp
        report "FALLO SOC: DDR word " & integer'image(k) &
               " esperada 0x" & to_hstring(v_exp) &
               " obtenida 0x" & to_hstring(ddr_dbg_data)
        severity failure;
      for b in 31 downto 0 loop
        v_msb := v_chk(31);
        v_chk := v_chk(30 downto 0) & ddr_dbg_data(b);
        if v_msb = '1' then
          v_chk := v_chk xor x"04C11DB7";
        end if;
      end loop;
    end loop;

    report "FIN SIMULACION SOC: PASS N=65 CHK=0x" &
           to_hstring(std_logic_vector(v_chk)) & " @ " & time'image(now);
    finish;
  end process p_main;

end architecture sim;
