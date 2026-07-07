-- =============================================================================
--  tb_gemv_big.vhd  -  GEMV GENERAL 32x32 con DDR_BASE=0x7FF00000 (como HW)
--  Licencia: MIT
--
--  Reproduce el escenario de hardware que fallaba: matriz 32x32 con la base de
--  la DDR en 0x7FF00000, de modo que la fila 31 cruzaria un limite de 4KB. La
--  DDR falsa ASERTA si algun burst cruza 4KB, asi que este test valida que el
--  DMA trocea los bursts. y esperado = [528, 1552, ..., 32272].
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_gemv_big is
end entity tb_gemv_big;

architecture sim of tb_gemv_big is
  constant TCK    : time := 10 ns;
  constant AXI_AW : natural := 40;
  constant YOFF   : natural := 1058;    -- word de y en el buffer (2 + 32*32 + 32)
  type iarr is array (0 to 31) of integer;
  constant Y_EXP : iarr := (
    528,1552,2576,3600,4624,5648,6672,7696,8720,9744,10768,11792,12816,13840,
    14864,15888,16912,17936,18960,19984,21008,22032,23056,24080,25104,26128,
    27152,28176,29200,30224,31248,32272);
  -- base de la DDR igual que en hardware
  constant DBASE  : unsigned(AXI_AW-1 downto 0) := to_unsigned(16#7FF00000#, AXI_AW);

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
    generic map (DEPTH => 256, INIT_FILE => "gemv_big.mem")
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
      dbg_reg_addr => (others => '0'), dbg_reg_data => open, dbg_pc => open
    );

  u_mem : entity work.mem_subsys_dma
    generic map (DEPTH => 256, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => std_logic_vector(DBASE),
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

  -- DDR falsa (2048 palabras = 8KB) cubre el buffer 32x32 y el cruce de 4KB
  u_ddr : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 2048, RD_LAT => 4, INIT_FILE => "ddr_big.mem")
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_awaddr => aw_addr, s_axi_awlen => aw_len, s_axi_awvalid => aw_valid, s_axi_awready => aw_ready,
      s_axi_wdata => w_data, s_axi_wstrb => w_strb, s_axi_wlast => w_last, s_axi_wvalid => w_valid, s_axi_wready => w_ready,
      s_axi_bresp => b_resp, s_axi_bvalid => b_valid, s_axi_bready => b_ready,
      s_axi_araddr => ar_addr, s_axi_arlen => ar_len, s_axi_arvalid => ar_valid, s_axi_arready => ar_ready,
      s_axi_rdata => r_data, s_axi_rresp => r_resp, s_axi_rlast => r_last, s_axi_rvalid => r_valid, s_axi_rready => r_ready,
      dbg_addr => ddr_dbg_addr, dbg_data => ddr_dbg_data
    );

  stim : process
    variable errors : natural := 0;
    procedure check_y (constant i : natural; constant exp : integer) is
    begin
      ddr_dbg_addr <= YOFF + i;
      wait for 1 ns;
      if to_integer(unsigned(ddr_dbg_data)) = exp then
        report "PASS y[" & integer'image(i) & "] = " & integer'image(exp) severity note;
      else
        report "FAIL y[" & integer'image(i) & "] got=" & integer'image(to_integer(unsigned(ddr_dbg_data))) &
               " exp=" & integer'image(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;
  begin
    rst <= '1';
    wait for 5*TCK;
    wait until rising_edge(clk);
    rst <= '0';
    -- 32x32 con la latencia de DDR: dale bastantes ciclos
    for k in 0 to 39999 loop wait until rising_edge(clk); end loop;

    report "--- GEMV GENERAL 32x32 con DDR_BASE=0x7FF00000 (cruce de 4KB) ---";
    for i in 0 to 31 loop check_y(i, Y_EXP(i)); end loop;

    report "-----------------------------------------";
    if errors = 0 then
      report "GEMV 32x32 CON TROCEO DE BURSTS EN 4KB: OK" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
