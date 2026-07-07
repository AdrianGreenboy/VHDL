-- =============================================================================
--  tb_master.vhd  -  Valida el puerto MAESTRO: el core lee/escribe la DDR
--  Licencia: MIT
--
--  El core corre accel_ddr.mem, que escribe 42/99 en la DDR (region 0x8000_0000
--  via el maestro AXI), los lee de vuelta, suma (141), y guarda 141 en DDR[2].
--  Comprueba los registros del core (x4,x5,x6) por el puerto de depuracion y el
--  contenido de la DDR falsa. Prueba que el core se congela y avanza bien con
--  la latencia AXI.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_master is
end entity tb_master;

architecture sim of tb_master is
  constant TCK    : time := 10 ns;
  constant AXI_AW : natural := 40;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  signal dbg_reg_addr : reg_addr_t := (others => '0');
  signal dbg_reg_data : word_t;

  -- AXI maestro <-> DDR falsa
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

  signal aresetn : std_logic;
begin

  clk <= not clk after TCK/2;
  aresetn <= not rst;

  u_imem : entity work.dp_ram
    generic map (DEPTH => 256, INIT_FILE => "accel_ddr.mem")
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
      dbg_reg_addr => dbg_reg_addr, dbg_reg_data => dbg_reg_data, dbg_pc => open
    );

  u_mem : entity work.mem_subsys
    generic map (DEPTH => 256, INIT_FILE => "", ADDR_W => AXI_AW,
                 AXI_BASE => to_unsigned(0, AXI_AW))
    port map (
      clk => clk, aresetn => aresetn,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      loc_axi_rdata => open,
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
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4)
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

    procedure check_reg (constant r : natural; constant exp : integer; constant name : string) is
    begin
      dbg_reg_addr <= std_logic_vector(to_unsigned(r, 5));
      wait for 1 ns;
      if to_integer(unsigned(dbg_reg_data)) = exp then
        report "PASS " & name & " = " & integer'image(exp) severity note;
      else
        report "FAIL " & name & " got=" & integer'image(to_integer(unsigned(dbg_reg_data))) &
               " exp=" & integer'image(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;

    procedure check_ddr (constant w : natural; constant exp : integer; constant name : string) is
    begin
      ddr_dbg_addr <= w;
      wait for 1 ns;
      if to_integer(unsigned(ddr_dbg_data)) = exp then
        report "PASS " & name & " = " & integer'image(exp) severity note;
      else
        report "FAIL " & name & " got=" & integer'image(to_integer(unsigned(ddr_dbg_data))) &
               " exp=" & integer'image(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;
  begin
    rst <= '1';
    wait for 5*TCK;
    wait until rising_edge(clk);
    rst <= '0';

    -- deja correr: 5 accesos AXI con latencia + pipeline
    for k in 0 to 299 loop wait until rising_edge(clk); end loop;

    report "--- registros del core (leidos por lw desde la DDR) ---";
    check_reg(4, 42,  "x4 (DDR[0])");
    check_reg(5, 99,  "x5 (DDR[1])");
    check_reg(6, 141, "x6 (x4+x5)");

    report "--- contenido de la DDR (escrito por sw del core) ---";
    check_ddr(0, 42,  "DDR[0]");
    check_ddr(1, 99,  "DDR[1]");
    check_ddr(2, 141, "DDR[2]");

    report "-----------------------------------------";
    if errors = 0 then
      report "PUERTO MAESTRO AXI: EL CORE LEE/ESCRIBE LA DDR" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
