-- =============================================================================
--  tb_dma.vhd  -  Valida el motor DMA en aislamiento (sin core)
--  Licencia: MIT
--
--  La DDR falsa arranca con [10,20,..,80]. El testbench dispara una DMA de
--  lectura (DDR -> RAM local) de 8 palabras con UN burst AXI4, y verifica que
--  la RAM local recibio los 8 valores. Luego una DMA de escritura (local ->
--  DDR) a otra region y comprueba que la DDR recibio el bloque.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_dma is
end entity tb_dma;

architecture sim of tb_dma is
  constant TCK    : time := 10 ns;
  constant AXI_AW : natural := 40;

  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';

  -- control DMA
  signal src, dst : std_logic_vector(31 downto 0) := (others => '0');
  signal len      : std_logic_vector(8 downto 0) := (others => '0');
  signal dir, start, busy : std_logic := '0';

  -- DMA <-> RAM local
  signal loc_addr  : std_logic_vector(31 downto 0);
  signal loc_wdata : word_t;
  signal loc_we    : std_logic;
  signal loc_rdata : word_t;
  signal loc_wstrb : std_logic_vector(3 downto 0);

  -- lectura de la RAM local por el testbench
  signal tb_addr : word_t := (others => '0');
  signal tb_rdata : word_t;

  -- AXI maestro DMA <-> DDR falsa
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

  loc_wstrb <= "1111" when loc_we = '1' else "0000";

  -- RAM local: puerto axi = DMA (escritura), puerto cpu = testbench (lectura)
  u_local : entity work.dp_ram
    generic map (DEPTH => 256, INIT_FILE => "")
    port map (
      clk => clk,
      cpu_addr => tb_addr, cpu_wdata => ZERO_WORD, cpu_wstrb => "0000",
      cpu_rdata => tb_rdata,
      axi_addr => loc_addr, axi_wdata => loc_wdata, axi_wstrb => loc_wstrb,
      axi_rdata => loc_rdata, axi_owns => '1'
    );

  u_dma : entity work.dma_burst
    generic map (ADDR_W => AXI_AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => (others => '0'),
      src => src, dst => dst, len => len, dir => dir, start => start, busy => busy,
      loc_addr => loc_addr, loc_wdata => loc_wdata, loc_we => loc_we, loc_rdata => loc_rdata,
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
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 3, INIT_FILE => "ddr_init.mem")
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

    procedure dma_go (constant s, d : integer; constant l : integer; constant di : std_logic) is
    begin
      src <= std_logic_vector(to_unsigned(s, 32));
      dst <= std_logic_vector(to_unsigned(d, 32));
      len <= std_logic_vector(to_unsigned(l, 9));
      dir <= di;
      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      loop wait until rising_edge(clk); exit when busy = '0'; end loop;
      wait until rising_edge(clk);
    end procedure;

    procedure check_loc (constant w : integer; constant exp : integer) is
    begin
      tb_addr <= std_logic_vector(to_unsigned(w*4, 32));
      wait for 1 ns;
      if to_integer(unsigned(tb_rdata)) = exp then
        report "PASS local[" & integer'image(w) & "] = " & integer'image(exp) severity note;
      else
        report "FAIL local[" & integer'image(w) & "] got=" & integer'image(to_integer(unsigned(tb_rdata))) &
               " exp=" & integer'image(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;

    procedure check_ddr (constant w : integer; constant exp : integer) is
    begin
      ddr_dbg_addr <= w;
      wait for 1 ns;
      if to_integer(unsigned(ddr_dbg_data)) = exp then
        report "PASS DDR[" & integer'image(w) & "] = " & integer'image(exp) severity note;
      else
        report "FAIL DDR[" & integer'image(w) & "] got=" & integer'image(to_integer(unsigned(ddr_dbg_data))) &
               " exp=" & integer'image(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;
  begin
    aresetn <= '0';
    wait for 5*TCK;
    wait until rising_edge(clk);
    aresetn <= '1';
    wait until rising_edge(clk);

    -- (1) DMA lectura: DDR[0..7] -> local[0..7] (un burst de 8)
    report "--- DMA lectura DDR->local (burst de 8) ---";
    dma_go(0, 0, 8, '0');
    check_loc(0, 10); check_loc(1, 20); check_loc(2, 30); check_loc(3, 40);
    check_loc(4, 50); check_loc(5, 60); check_loc(6, 70); check_loc(7, 80);

    -- (2) DMA escritura: local[0..7] -> DDR[16..23] (un burst de 8)
    report "--- DMA escritura local->DDR (burst de 8) ---";
    dma_go(0, 16*4, 8, '1');   -- src=local word 0, dst=DDR byte 64 (word 16)
    check_ddr(16, 10); check_ddr(17, 20); check_ddr(18, 30); check_ddr(19, 40);
    check_ddr(20, 50); check_ddr(21, 60); check_ddr(22, 70); check_ddr(23, 80);

    report "-----------------------------------------";
    if errors = 0 then
      report "MOTOR DMA CON BURSTS AXI4: OK" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
