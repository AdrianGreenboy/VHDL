-- =============================================================================
--  tb_bus_err.vhd  -  audit-2026-11: AXI SLVERR -> load/store access fault
--  License: MIT
--  cpu_pipeline + mem_subsys (axi4_master) + axi_ddr_sim with ERR_WORD = 8.
--  Runs bus_err_test.mem and checks mcause 5/7, mtval = faulting address,
--  that the faulting load does not write rd, that the younger instructions
--  are replayed correctly after the handler, and that a good DDR access in
--  between still works. Both memory modes (SYNC_MEM). Prints TB_BUS_ERR_PASS.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_bus_err is
  generic (
    SYNC_MEM : boolean := false   -- 1-cycle synchronous IMEM/DMEM (ASIC SRAM mode)
  );
end entity tb_bus_err;

architecture sim of tb_bus_err is
  constant TCK    : time := 10 ns;
  constant AXI_AW : natural := 40;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready, dmem_err : std_logic;
  type log_t is array (0 to 63) of word_t;
  signal log   : log_t := (others => (others => 'U'));
  signal mem63 : word_t := (others => 'U');
  signal done  : boolean := false;
  type exp_t is array (natural range <>) of word_t;
  constant EXP_LOG : exp_t := (
    x"00000005", x"80000020",    -- T1 load access fault
    x"00000007", x"80000020",    -- T2 store access fault
    x"00000005", x"80000020");   -- T3 load access fault

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

  clk <= not clk after TCK/2 when not done else '0';
  aresetn <= not rst;

  u_imem : entity work.dp_ram
    generic map (DEPTH => 256, INIT_FILE => "bus_err_test.mem", SYNC_READ => SYNC_MEM)
    port map (
      clk => clk,
      cpu_addr => imem_addr, cpu_wdata => ZERO_WORD, cpu_wstrb => "0000",
      cpu_rdata => imem_instr,
      axi_addr => ZERO_WORD, axi_wdata => ZERO_WORD, axi_wstrb => "0000",
      axi_rdata => open, axi_owns => '0'
    );

  u_cpu : entity work.cpu_pipeline
    generic map (IMEM_SYNC => SYNC_MEM, DMEM_SYNC => SYNC_MEM)
    port map (
      clk => clk, rst => rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dmem_req => dmem_req, dmem_ready => dmem_ready, dmem_err => dmem_err,
      irq_timer => '0', irq_soft => '0', irq_ext => '0',
      dbg_reg_addr => dbg_reg_addr, dbg_reg_data => dbg_reg_data, dbg_pc => open
    );

  u_mem : entity work.mem_subsys
    generic map (DEPTH => 256, INIT_FILE => "", ADDR_W => AXI_AW, SYNC_READ => SYNC_MEM,
                 AXI_BASE => to_unsigned(0, AXI_AW))
    port map (
      clk => clk, aresetn => aresetn,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      dmem_err => dmem_err,
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
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, ERR_WORD => 8)
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_awaddr => aw_addr, s_axi_awlen => aw_len, s_axi_awvalid => aw_valid, s_axi_awready => aw_ready,
      s_axi_wdata => w_data, s_axi_wstrb => w_strb, s_axi_wlast => w_last, s_axi_wvalid => w_valid, s_axi_wready => w_ready,
      s_axi_bresp => b_resp, s_axi_bvalid => b_valid, s_axi_bready => b_ready,
      s_axi_araddr => ar_addr, s_axi_arlen => ar_len, s_axi_arvalid => ar_valid, s_axi_arready => ar_ready,
      s_axi_rdata => r_data, s_axi_rresp => r_resp, s_axi_rlast => r_last, s_axi_rvalid => r_valid, s_axi_rready => r_ready,
      dbg_addr => ddr_dbg_addr, dbg_data => ddr_dbg_data
    );

  -- store monitor on the local RAM: handler log and final trap count
  process(clk)
    variable a : natural;
  begin
    if rising_edge(clk) and rst = '0' and dmem_wstrb = "1111" and dmem_addr(31) = '0' then
      a := to_integer(unsigned(dmem_addr(9 downto 0)));
      if a >= 256 and a < 512 then log((a - 256) / 4) <= dmem_wdata;
      elsif a = 252 then mem63 <= dmem_wdata; end if;
    end if;
  end process;

  stim : process
    variable errors : natural := 0;
    procedure chk_reg (constant r : natural; constant exp : word_t; constant name : string) is
    begin
      dbg_reg_addr <= std_logic_vector(to_unsigned(r, 5));
      wait for 1 ns;
      if dbg_reg_data = exp then report "PASS " & name severity note;
      else
        report "FAIL " & name & " got=0x" & to_hstring(dbg_reg_data) & " exp=0x" & to_hstring(exp)
          severity error;
        errors := errors + 1;
      end if;
    end procedure;
  begin
    rst <= '1';
    wait for 3*TCK;
    wait until rising_edge(clk);
    rst <= '0';
    for i in 0 to 5000 loop
      wait until rising_edge(clk);
      exit when mem63 /= (31 downto 0 => 'U');
    end loop;
    for i in 0 to 20 loop wait until rising_edge(clk); end loop;
    if mem63 = x"00000003" then report "PASS trap count = 3" severity note;
    else report "FAIL trap count got=0x" & to_hstring(mem63) severity error; errors := errors + 1; end if;
    for i in EXP_LOG'range loop
      if log(i) /= EXP_LOG(i) then
        report "FAIL log[" & integer'image(i) & "] got=0x" & to_hstring(log(i)) &
               " exp=0x" & to_hstring(EXP_LOG(i)) severity error;
        errors := errors + 1;
      end if;
    end loop;
    chk_reg(11, x"5A5A5A5A", "faulting load did not write rd");
    chk_reg(12, x"5A5A5A5B", "consumer replayed after the fault");
    chk_reg(13, x"CAFEF00D", "good DDR read after faults");
    chk_reg(15, x"00000777", "second faulting load did not write rd");
    chk_reg(16, x"00000001", "div behind the faulting load");
    ddr_dbg_addr <= 8; wait for 1 ns;
    if ddr_dbg_data = x"00000000" then report "PASS errored store not written" severity note;
    else report "FAIL errored store reached DDR" severity error; errors := errors + 1; end if;
    if errors = 0 then
      report "TB_BUS_ERR_PASS (SYNC_MEM=" & boolean'image(SYNC_MEM) & ")" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    done <= true;
    wait;
  end process;
end architecture sim;
