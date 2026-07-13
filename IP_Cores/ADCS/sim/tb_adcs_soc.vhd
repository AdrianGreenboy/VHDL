-- ============================================================================
-- tb_adcs_soc.vhd — Capa 4 del IP ADCS: el core RV32IM ejecuta adcs_test.mem,
-- programa y dispara el IP ADCS (region 0xA), y vuelca firma+doorbell a la DDR.
-- Sigue el patron de tb_ptp_soc_fw: carga IMEM por AXI-Lite, arranca el core,
-- espera el doorbell (irq_out), y lee el reporte de la DDR.
--
-- Topologia: soc_top_master_adcs con DOS maestros AXI (dma_burst del SoC +
-- maestro propio del ADCS), ambos a una ddr_sim_2p compartida (misma memoria
-- fisica en silicio). La DDR se precarga con H y g (rol del PS) via INIT_FILE.
--
-- PASS: el reporte en DDR contiene sentinela 0xD1A6 y firma == oraculo del
-- solver (0x0C4CCCD2 para el caso n=8,mi=2), disparados por el doorbell.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
use work.riscv_pkg.all;

entity tb_adcs_soc is
  generic (
    FW_FILE    : string  := "adcs_test.mem";
    DDR_INIT   : string  := "adcs_ddr_init.mem";
    EXP_SIG    : string  := "0C4CCCD2"
  );
end entity tb_adcs_soc;

architecture sim of tb_adcs_soc is
  constant TCK : time := 10 ns;
  constant SAW : natural := 16;
  constant AXI_AW : natural := 40;

  signal aclk : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal s_awaddr : std_logic_vector(SAW-1 downto 0) := (others=>'0');
  signal s_awvalid, s_awready : std_logic := '0';
  signal s_wdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal s_wstrb : std_logic_vector(3 downto 0) := "1111";
  signal s_wvalid, s_wready : std_logic := '0';
  signal s_bresp : std_logic_vector(1 downto 0);
  signal s_bvalid : std_logic; signal s_bready : std_logic := '0';
  signal s_araddr : std_logic_vector(SAW-1 downto 0) := (others=>'0');
  signal s_arvalid, s_arready : std_logic := '0';
  signal s_rdata : std_logic_vector(31 downto 0);
  signal s_rresp : std_logic_vector(1 downto 0);
  signal s_rvalid : std_logic; signal s_rready : std_logic := '0';

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

  signal a_araddr : std_logic_vector(31 downto 0);
  signal a_arlen  : std_logic_vector(7 downto 0);
  signal a_arsize : std_logic_vector(2 downto 0);
  signal a_arburst: std_logic_vector(1 downto 0);
  signal a_arprot : std_logic_vector(2 downto 0);
  signal a_arcache: std_logic_vector(3 downto 0);
  signal a_arvalid, a_arready : std_logic;
  signal a_rdata  : std_logic_vector(31 downto 0);
  signal a_rresp  : std_logic_vector(1 downto 0);
  signal a_rlast, a_rvalid, a_rready : std_logic;
  signal a_awaddr : std_logic_vector(31 downto 0);
  signal a_awlen  : std_logic_vector(7 downto 0);
  signal a_awsize : std_logic_vector(2 downto 0);
  signal a_awburst: std_logic_vector(1 downto 0);
  signal a_awprot : std_logic_vector(2 downto 0);
  signal a_awcache: std_logic_vector(3 downto 0);
  signal a_awvalid, a_awready : std_logic;
  signal a_wdata  : std_logic_vector(31 downto 0);
  signal a_wstrb  : std_logic_vector(3 downto 0);
  signal a_wlast, a_wvalid, a_wready : std_logic;
  signal a_bresp  : std_logic_vector(1 downto 0);
  signal a_bvalid, a_bready : std_logic;

  signal irq_out : std_logic;
  signal ddr_dbg_addr : natural := 0;
  signal ddr_dbg_data : word_t;
begin
  aclk <= not aclk after TCK/2;

  dut : entity work.soc_top_master_adcs
    generic map (ADDR_W => SAW, DEPTH => 256, IMEM_INIT => "",
                 DONE_WORD => 127, AXI_AW => AXI_AW)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_axi_awaddr => s_awaddr, s_axi_awvalid => s_awvalid, s_axi_awready => s_awready,
      s_axi_wdata => s_wdata, s_axi_wstrb => s_wstrb, s_axi_wvalid => s_wvalid, s_axi_wready => s_wready,
      s_axi_bresp => s_bresp, s_axi_bvalid => s_bvalid, s_axi_bready => s_bready,
      s_axi_araddr => s_araddr, s_axi_arvalid => s_arvalid, s_axi_arready => s_arready,
      s_axi_rdata => s_rdata, s_axi_rresp => s_rresp, s_axi_rvalid => s_rvalid, s_axi_rready => s_rready,
      m_axi_awaddr => aw_addr, m_axi_awlen => aw_len, m_axi_awsize => aw_size,
      m_axi_awburst => aw_burst, m_axi_awvalid => aw_valid, m_axi_awready => aw_ready,
      m_axi_wdata => w_data, m_axi_wstrb => w_strb, m_axi_wlast => w_last,
      m_axi_wvalid => w_valid, m_axi_wready => w_ready,
      m_axi_bresp => b_resp, m_axi_bvalid => b_valid, m_axi_bready => b_ready,
      m_axi_araddr => ar_addr, m_axi_arlen => ar_len, m_axi_arsize => ar_size,
      m_axi_arburst => ar_burst, m_axi_arvalid => ar_valid, m_axi_arready => ar_ready,
      m_axi_rdata => r_data, m_axi_rresp => r_resp, m_axi_rlast => r_last,
      m_axi_rvalid => r_valid, m_axi_rready => r_ready,
      a_axi_araddr => a_araddr, a_axi_arlen => a_arlen, a_axi_arsize => a_arsize,
      a_axi_arburst => a_arburst, a_axi_arprot => a_arprot, a_axi_arcache => a_arcache,
      a_axi_arvalid => a_arvalid, a_axi_arready => a_arready,
      a_axi_rdata => a_rdata, a_axi_rresp => a_rresp, a_axi_rlast => a_rlast,
      a_axi_rvalid => a_rvalid, a_axi_rready => a_rready,
      a_axi_awaddr => a_awaddr, a_axi_awlen => a_awlen, a_axi_awsize => a_awsize,
      a_axi_awburst => a_awburst, a_axi_awprot => a_awprot, a_axi_awcache => a_awcache,
      a_axi_awvalid => a_awvalid, a_axi_awready => a_awready,
      a_axi_wdata => a_wdata, a_axi_wstrb => a_wstrb, a_axi_wlast => a_wlast,
      a_axi_wvalid => a_wvalid, a_axi_wready => a_wready,
      a_axi_bresp => a_bresp, a_axi_bvalid => a_bvalid, a_axi_bready => a_bready,
      irq_out => irq_out);

  u_ddr : entity work.ddr_sim_2p
    generic map (ADDR_W => AXI_AW, DEPTH => 16384, INIT_FILE => DDR_INIT)
    port map (
      clk => aclk, aresetn => aresetn,
      p0_awaddr => aw_addr, p0_awlen => aw_len, p0_awvalid => aw_valid, p0_awready => aw_ready,
      p0_wdata => w_data, p0_wstrb => w_strb, p0_wlast => w_last, p0_wvalid => w_valid, p0_wready => w_ready,
      p0_bresp => b_resp, p0_bvalid => b_valid, p0_bready => b_ready,
      p0_araddr => ar_addr, p0_arlen => ar_len, p0_arvalid => ar_valid, p0_arready => ar_ready,
      p0_rdata => r_data, p0_rresp => r_resp, p0_rlast => r_last, p0_rvalid => r_valid, p0_rready => r_ready,
      p1_awaddr => a_awaddr, p1_awvalid => a_awvalid, p1_awready => a_awready,
      p1_wdata => a_wdata, p1_wstrb => a_wstrb, p1_wlast => a_wlast, p1_wvalid => a_wvalid, p1_wready => a_wready,
      p1_bresp => a_bresp, p1_bvalid => a_bvalid, p1_bready => a_bready,
      p1_araddr => a_araddr, p1_arvalid => a_arvalid, p1_arready => a_arready,
      p1_rdata => a_rdata, p1_rresp => a_rresp, p1_rlast => a_rlast, p1_rvalid => a_rvalid, p1_rready => a_rready,
      dbg_addr => ddr_dbg_addr, dbg_data => ddr_dbg_data);

  stim : process
    variable errors : natural := 0;
    file     f : text;
    variable l : line;
    variable w : word_t;
    variable i : natural;
    variable exp_sig_v : std_logic_vector(31 downto 0);

    function hstr2slv(s : string) return std_logic_vector is
      variable r : std_logic_vector(31 downto 0) := (others => '0');
      variable nib : integer;
    begin
      for k in 1 to 8 loop
        case s(k) is
          when '0' => nib := 0;  when '1' => nib := 1;
          when '2' => nib := 2;  when '3' => nib := 3;
          when '4' => nib := 4;  when '5' => nib := 5;
          when '6' => nib := 6;  when '7' => nib := 7;
          when '8' => nib := 8;  when '9' => nib := 9;
          when 'A'|'a' => nib := 10; when 'B'|'b' => nib := 11;
          when 'C'|'c' => nib := 12; when 'D'|'d' => nib := 13;
          when 'E'|'e' => nib := 14; when 'F'|'f' => nib := 15;
          when others => nib := 0;
        end case;
        r(35-4*k downto 32-4*k) := std_logic_vector(to_unsigned(nib, 4));
      end loop;
      return r;
    end function;

    procedure axil_write (constant addr : integer;
                          constant data : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(aclk);
      s_awaddr <= std_logic_vector(to_unsigned(addr, SAW));
      s_wdata  <= data; s_wstrb <= "1111";
      s_awvalid <= '1'; s_wvalid <= '1'; s_bready <= '1';
      loop wait until rising_edge(aclk); exit when s_awready = '1'; end loop;
      s_awvalid <= '0'; s_wvalid <= '0';
      loop wait until rising_edge(aclk); exit when s_bvalid = '1'; end loop;
      s_bready <= '0';
    end procedure;
  begin
    exp_sig_v := hstr2slv(EXP_SIG);
    aresetn <= '0';
    wait for 8*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait for 4*TCK;

    -- (1) cargar el firmware en el IMEM (ventana 0x1000 del AXI-Lite)
    report "--- cargando " & FW_FILE & " en el IMEM ---";
    file_open(f, FW_FILE, read_mode);
    i := 0;
    while not endfile(f) loop
      readline(f, l);
      if l'length > 0 then
        hread(l, w);
        axil_write(16#1000# + i*4, w);
        i := i + 1;
      end if;
    end loop;
    file_close(f);
    report "  cargadas " & integer'image(i) & " instrucciones";

    -- (1b) DDR_BASE = 0 (ambos maestros ven la misma DDR con offset 0)
    axil_write(16#0010#, (others => '0'));
    axil_write(16#0014#, (others => '0'));

    -- (2) arrancar el core
    axil_write(16#0000#, (others => '0'));
    report "--- core arrancado; ejecutando adcs_test ---";

    -- (3) esperar el doorbell (irq del SoC cuando el core escribe DONE_WORD)
    for k in 0 to 4000000 loop
      wait until rising_edge(aclk);
      exit when irq_out = '1';
    end loop;
    if irq_out /= '1' then
      report "TIMEOUT: el firmware no disparo el doorbell" severity failure;
    end if;
    report "--- doorbell recibido; leyendo reporte de la DDR ---";

    -- (4) leer el reporte en DDR offset 0xC000 (word 0x3000): sentinela, firma
    ddr_dbg_addr <= 16#C000#/4;
    wait for 1 ns;
    if ddr_dbg_data /= x"0000D1A6" then
      report "FAIL sentinela: got=0x" & to_hstring(ddr_dbg_data) &
             " exp=0x0000D1A6" severity error;
      errors := errors + 1;
    else
      report "PASS sentinela 0xD1A6" severity note;
    end if;

    ddr_dbg_addr <= 16#C000#/4 + 1;
    wait for 1 ns;
    if ddr_dbg_data /= exp_sig_v then
      report "FAIL firma: got=0x" & to_hstring(ddr_dbg_data) &
             " exp=0x" & to_hstring(exp_sig_v) severity error;
      errors := errors + 1;
    else
      report "PASS firma = 0x" & to_hstring(exp_sig_v) severity note;
    end if;

    report "-----------------------------------------";
    if errors = 0 then
      report "CAPA 4 ADCS SOC: PASS (core ejecuta fw, firma bit-identica) T=" &
             time'image(now) severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON en CAPA 4" severity failure;
    end if;
    finish;
  end process;

end architecture sim;
