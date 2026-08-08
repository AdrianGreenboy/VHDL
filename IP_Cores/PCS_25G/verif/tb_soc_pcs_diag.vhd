-- =============================================================================
-- HERCOSSNUX Core 19 - PCS 64B/66B @ 25G
-- Testbench de integracion del SoC: el RV32 real ejecuta el firmware compilado
-- (fw_rv32.mem) contra el periferico PCS, de extremo a extremo.
--
--   soc_top_pcs (RV32 + PCS + axil_soc + DMA del core)
--     m_axi -> u_ddr_core (recibe las palabras de resultado por el DMA)
--
-- Secuencia de arranque (espejo de tb_soc_mipi):
--   1. reset, 2. el PS carga el firmware en IMEM por AXI-Lite (ventana 0x1000),
--   3. el PS fija DDR_BASE, 4. el PS libera el core (CONTROL=0),
--   5. espera irq_out (doorbell), 6. lee los resultados de la DDR simulada.
--
-- El firmware deja en la RAM local (y por DMA en DDR) las palabras:
-- (por DMA al offset 0x40 de la DDR = palabra 16 en adelante)
--   [118] ID           esperado 0x50435319
--   [119] STATUS       esperado 0x0000007D
--   [120] CNT_TX_BLK   esperado > 0
--   [121] CNT_RX_BLK   esperado > 0
--   [122] CNT_BER      esperado 0  (ventana limpia)
--   [123] CNT_BER      esperado 9  (tras inyeccion de 1 bit)
--   [124] IRQ_STATUS   esperado bit4 (EV_PRBS_ERR) a 1
--   [125] firma FNV-1a sobre [118..124]
--   [126] flags        esperado 0xF (los cuatro chequeos del firmware OK)
--   [127] doorbell
--
-- Este es el ensayo completo del silicon pass en simulacion (Layer 5).
-- Nota: el dominio del data plane corre aqui a 390.625 MHz reales frente a un
-- reloj de CPU de 100 ns/ciclo escalado; las esperas del firmware estan
-- dimensionadas con holgura, por eso el tiempo simulado es largo.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.riscv_pkg.all;

entity tb_soc_pcs_diag is
end entity;

architecture sim of tb_soc_pcs_diag is
  constant TCK    : time := 10 ns;         -- reloj AXI/CPU
  constant TDP    : time := 1.28 ns;       -- data plane 390.625 MHz
  constant SAW    : natural := 16;
  constant AXI_AW : natural := 40;

  -- indices de palabra en la DDR simulada (DDR_BASE = 0). El firmware hace
  -- DMA de 9 palabras (LRAM[118..126]) al offset 0x40 -> palabra 16.
  constant W_BASE   : natural := 16#40#/4;   -- 16
  constant W_ID     : natural := W_BASE + 0;
  constant W_STATUS : natural := W_BASE + 1;
  constant W_TX     : natural := W_BASE + 2;
  constant W_RX     : natural := W_BASE + 3;
  constant W_BER0   : natural := W_BASE + 4;
  constant W_BER1   : natural := W_BASE + 5;
  constant W_IRQ    : natural := W_BASE + 6;
  constant W_SIG    : natural := W_BASE + 7;
  constant W_FLAGS  : natural := W_BASE + 8;

  signal aclk    : std_logic := '0';
  signal clk_dp  : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal s_awaddr : std_logic_vector(SAW-1 downto 0) := (others=>'0');
  signal s_awvalid, s_awready : std_logic := '0';
  signal s_wdata  : std_logic_vector(31 downto 0) := (others=>'0');
  signal s_wstrb  : std_logic_vector(3 downto 0) := (others=>'0');
  signal s_wvalid, s_wready : std_logic := '0';
  signal s_bresp  : std_logic_vector(1 downto 0);
  signal s_bvalid : std_logic; signal s_bready : std_logic := '0';
  signal s_araddr : std_logic_vector(SAW-1 downto 0) := (others=>'0');
  signal s_arvalid, s_arready : std_logic := '0';
  signal s_rdata  : std_logic_vector(31 downto 0);
  signal s_rresp  : std_logic_vector(1 downto 0);
  signal s_rvalid : std_logic; signal s_rready : std_logic := '0';

  signal c_awaddr : std_logic_vector(AXI_AW-1 downto 0);
  signal c_awlen  : std_logic_vector(7 downto 0);
  signal c_awsize : std_logic_vector(2 downto 0);
  signal c_awburst: std_logic_vector(1 downto 0);
  signal c_awvalid, c_awready : std_logic;
  signal c_wdata  : std_logic_vector(31 downto 0);
  signal c_wstrb  : std_logic_vector(3 downto 0);
  signal c_wlast, c_wvalid, c_wready : std_logic;
  signal c_bresp  : std_logic_vector(1 downto 0);
  signal c_bvalid, c_bready : std_logic;
  signal c_araddr : std_logic_vector(AXI_AW-1 downto 0);
  signal c_arlen  : std_logic_vector(7 downto 0);
  signal c_arsize : std_logic_vector(2 downto 0);
  signal c_arburst: std_logic_vector(1 downto 0);
  signal c_arvalid, c_arready : std_logic;
  signal c_rdata  : std_logic_vector(31 downto 0);
  signal c_rresp  : std_logic_vector(1 downto 0);
  signal c_rlast, c_rvalid, c_rready : std_logic;

  signal irq_out : std_logic;

  signal dbg_addr : natural := 0;
  signal dbg_data : word_t;

  signal errors : natural := 0;
  signal seen_dp_pe, seen_dp_lg, seen_axi_pe, seen_axi_lg, seen_sticky : std_logic := '0';
  signal rd14_pend  : std_logic := '0';
  signal irq_at_ar  : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata_14   : std_logic_vector(31 downto 0) := (others => '0');
  signal n_rd14     : natural := 0;
  signal n_sel14, n_sel10, n_sel30, n_ar_tot : natural := 0;
  signal dmem_a : word_t;      -- copia del bus dmem (GHDL no indexa externos)
  signal pcs_s  : std_logic;
  signal arv    : std_logic;
  signal p_ara  : std_logic_vector(7 downto 0);
  signal p_rdat : std_logic_vector(31 downto 0);
  signal p_rv   : std_logic;
  signal irq_int: std_logic_vector(31 downto 0);
  type trace_t is array (0 to 31) of std_logic_vector(7 downto 0);
  signal trace   : trace_t := (others => (others => '0'));
  type twr_t is array (0 to 31) of std_logic;
  signal trace_w : twr_t := (others => '0');
  signal t_idx   : natural := 0;
  signal sel_d   : std_logic := '0';
  signal dwstrb  : std_logic_vector(3 downto 0);
  function rw_str(b : std_logic) return string is
  begin
    if b = '1' then return "WR"; else return "RD"; end if;
  end function;
begin
  aclk   <= not aclk   after TCK/2;
  clk_dp <= not clk_dp after TDP/2;

  -- === DUT: el SoC del PCS (RV32 real + PCS real) ===
  dut : entity work.soc_top_pcs
    generic map (ADDR_W => SAW, DEPTH => 256, IMEM_INIT => "",
                 DONE_WORD => 127, AXI_AW => AXI_AW)
    port map (
      aclk => aclk, aresetn => aresetn,
      clk_dp => clk_dp, dp_locked => '1',
      s_axi_awaddr => s_awaddr, s_axi_awvalid => s_awvalid, s_axi_awready => s_awready,
      s_axi_wdata => s_wdata, s_axi_wstrb => s_wstrb, s_axi_wvalid => s_wvalid, s_axi_wready => s_wready,
      s_axi_bresp => s_bresp, s_axi_bvalid => s_bvalid, s_axi_bready => s_bready,
      s_axi_araddr => s_araddr, s_axi_arvalid => s_arvalid, s_axi_arready => s_arready,
      s_axi_rdata => s_rdata, s_axi_rresp => s_rresp, s_axi_rvalid => s_rvalid, s_axi_rready => s_rready,
      m_axi_awaddr => c_awaddr, m_axi_awlen => c_awlen, m_axi_awsize => c_awsize,
      m_axi_awburst => c_awburst, m_axi_awvalid => c_awvalid, m_axi_awready => c_awready,
      m_axi_wdata => c_wdata, m_axi_wstrb => c_wstrb, m_axi_wlast => c_wlast,
      m_axi_wvalid => c_wvalid, m_axi_wready => c_wready,
      m_axi_bresp => c_bresp, m_axi_bvalid => c_bvalid, m_axi_bready => c_bready,
      m_axi_araddr => c_araddr, m_axi_arlen => c_arlen, m_axi_arsize => c_arsize,
      m_axi_arburst => c_arburst, m_axi_arvalid => c_arvalid, m_axi_arready => c_arready,
      m_axi_rdata => c_rdata, m_axi_rresp => c_rresp, m_axi_rlast => c_rlast,
      m_axi_rvalid => c_rvalid, m_axi_rready => c_rready,
      irq_out => irq_out
    );

  -- === modelo de DDR en el maestro del core (recibe los resultados) ===
  u_ddr_core : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => aclk, aresetn => aresetn,
      s_axi_awaddr => c_awaddr, s_axi_awlen => c_awlen, s_axi_awvalid => c_awvalid, s_axi_awready => c_awready,
      s_axi_wdata => c_wdata, s_axi_wstrb => c_wstrb, s_axi_wlast => c_wlast, s_axi_wvalid => c_wvalid, s_axi_wready => c_wready,
      s_axi_bresp => c_bresp, s_axi_bvalid => c_bvalid, s_axi_bready => c_bready,
      s_axi_araddr => c_araddr, s_axi_arlen => c_arlen, s_axi_arvalid => c_arvalid, s_axi_arready => c_arready,
      s_axi_rdata => c_rdata, s_axi_rresp => c_rresp, s_axi_rlast => c_rlast, s_axi_rvalid => c_rvalid, s_axi_rready => c_rready,
      dbg_addr => dbg_addr, dbg_data => dbg_data
    );


  -- === MONITOR DE DIAGNOSTICO (barato: solo stickies, sin contadores) ===
  dmem_a <= <<signal .tb_soc_pcs_diag.dut.dmem_addr : word_t>>;
  p_ara   <= <<signal .tb_soc_pcs_diag.dut.p_araddr : std_logic_vector(7 downto 0)>>;
  p_rdat  <= <<signal .tb_soc_pcs_diag.dut.p_rdata : std_logic_vector(31 downto 0)>>;
  p_rv    <= <<signal .tb_soc_pcs_diag.dut.p_rvalid : std_logic>>;
  irq_int <= <<signal .tb_soc_pcs_diag.dut.u_pcs.u_bank.reg_irq_status : std_logic_vector(31 downto 0)>>;
  pcs_s  <= <<signal .tb_soc_pcs_diag.dut.pcs_sel : std_logic>>;
  arv    <= <<signal .tb_soc_pcs_diag.dut.p_arvalid : std_logic>>;
  dwstrb <= <<signal .tb_soc_pcs_diag.dut.dmem_wstrb : std_logic_vector(3 downto 0)>>;

  diag_dp : process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if <<signal .tb_soc_pcs_diag.dut.u_pcs.dpl_ev_pe : std_logic>> = '1' then
        seen_dp_pe <= '1';
      end if;
      if <<signal .tb_soc_pcs_diag.dut.u_pcs.dpl_ev_lg : std_logic>> = '1' then
        seen_dp_lg <= '1';
      end if;
    end if;
  end process;

  diag_axi : process(aclk)
  begin
    if rising_edge(aclk) then
      if <<signal .tb_soc_pcs_diag.dut.u_pcs.axi_ev_pe : std_logic>> = '1' then
        seen_axi_pe <= '1';
      end if;
      if <<signal .tb_soc_pcs_diag.dut.u_pcs.axi_ev_lg : std_logic>> = '1' then
        seen_axi_lg <= '1';
      end if;
      if irq_int /= x"00000000" then
        seen_sticky <= '1';
      end if;
      -- traza: registrar el flanco de subida de cada acceso a la ventana PCS
      sel_d <= pcs_s;
      if pcs_s = '1' and sel_d = '0' and t_idx < 32 then
        trace(t_idx)   <= dmem_a(7 downto 0);
        if dwstrb = "0000" then trace_w(t_idx) <= '0';
        else trace_w(t_idx) <= '1'; end if;
        t_idx <= t_idx + 1;
      end if;
      -- que pide el CPU en el bus dmem (antes del puente)
      if pcs_s = '1' then
        case dmem_a(7 downto 0) is
          when x"14" => n_sel14 <= n_sel14 + 1;
          when x"10" => n_sel10 <= n_sel10 + 1;
          when x"30" => n_sel30 <= n_sel30 + 1;
          when others => null;
        end case;
      end if;
      if arv = '1' then
        n_ar_tot <= n_ar_tot + 1;
      end if;
      -- capturar el instante de una lectura AXI al offset 0x14 (IRQ_STATUS)
      if arv = '1' and p_ara = x"14" then
        irq_at_ar <= irq_int;
        rd14_pend <= '1';
        n_rd14    <= n_rd14 + 1;
      end if;
      if rd14_pend = '1' and p_rv = '1' then
        rdata_14  <= p_rdat;
        rd14_pend <= '0';
      end if;
    end if;
  end process;

  stim : process
    file f : text;
    variable l : line;
    variable w : word_t;
    variable i : natural;
    variable v : word_t;

    procedure axil_write (constant addr : integer; constant data : std_logic_vector(31 downto 0)) is
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

    procedure ddr_read (constant idx : natural; variable data : out word_t) is
    begin
      dbg_addr <= idx;
      wait for 1 ns;
      data := dbg_data;
    end procedure;
  begin
    aresetn <= '0';
    wait for 8*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait for 4*TCK;

    -- (1) el PS carga el firmware en IMEM por la ventana AXI-Lite 0x1000
    report "--- PS: cargando fw_rv32.mem en IMEM (AXI-Lite) ---";
    file_open(f, "fw_rv32_sim.mem", read_mode);
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

    -- (1b) base fisica de DDR (la DDR simulada empieza en 0)
    axil_write(16#0010#, (others => '0'));   -- DDR_BASE_LO
    axil_write(16#0014#, (others => '0'));   -- DDR_BASE_HI

    -- (2) liberar el core: CONTROL = 0 (quita el halt)
    axil_write(16#0000#, (others => '0'));
    report "--- core liberado; esperando doorbell IRQ ---";

    -- (3) esperar el doorbell (ventana amplia: bring-up del PCS + ventanas de
    --     medida + inyeccion + DMA suman muchos miles de ciclos)
    for k in 0 to 4000000 loop
      wait until rising_edge(aclk);
      exit when irq_out = '1';
    end loop;
    if irq_out /= '1' then
      report "TIMEOUT: no llego el doorbell IRQ" severity failure;
    end if;
    report "doorbell IRQ recibido";

    -- (4) leer y verificar las palabras de resultado en la DDR simulada
    ddr_read(W_ID, v);
    report "ID        = 0x" & to_hstring(v);
    if v /= x"50435319" then errors <= errors + 1;
      report "FAIL: ID incorrecto" severity error; end if;

    ddr_read(W_STATUS, v);
    report "STATUS    = 0x" & to_hstring(v);
    if v /= x"0000007D" then errors <= errors + 1;
      report "FAIL: STATUS no es 0x7D" severity error; end if;

    ddr_read(W_TX, v);
    report "CNT_TX    = 0x" & to_hstring(v);
    if unsigned(v) = 0 then errors <= errors + 1;
      report "FAIL: CNT_TX es cero" severity error; end if;

    ddr_read(W_RX, v);
    report "CNT_RX    = 0x" & to_hstring(v);
    if unsigned(v) = 0 then errors <= errors + 1;
      report "FAIL: CNT_RX es cero" severity error; end if;

    ddr_read(W_BER0, v);
    report "BER limpio= 0x" & to_hstring(v);
    if unsigned(v) /= 0 then errors <= errors + 1;
      report "FAIL: BER de ventana limpia no es cero" severity error; end if;

    ddr_read(W_BER1, v);
    report "BER inyec.= 0x" & to_hstring(v);
    if unsigned(v) /= 9 then errors <= errors + 1;
      report "FAIL: BER tras inyeccion no es 9" severity error; end if;

    ddr_read(W_IRQ, v);
    report "IRQ_STATUS= 0x" & to_hstring(v);
    if v(4) /= '1' then errors <= errors + 1;
      report "FAIL: EV_PRBS_ERR sticky no activo" severity error; end if;

    ddr_read(W_SIG, v);
    report "FIRMA FNV = 0x" & to_hstring(v);

    ddr_read(W_FLAGS, v);
    report "FLAGS     = 0x" & to_hstring(v);
    if v /= x"0000000F" then errors <= errors + 1;
      report "FAIL: flags del firmware no son 0xF" severity error; end if;

    -- === DIAGNOSTICO ===
    report "DIAG visto dp_ev_prbs_err  = " & std_logic'image(seen_dp_pe);
    report "DIAG visto axi_ev_prbs_err = " & std_logic'image(seen_axi_pe);
    report "DIAG visto dp_ev_lock_gain = " & std_logic'image(seen_dp_lg);
    report "DIAG visto axi_ev_lock_gain= " & std_logic'image(seen_axi_lg);
    report "DIAG sticky alguna vez /=0 = " & std_logic'image(seen_sticky);
    for t in 0 to 23 loop
      if t < t_idx then
        report "TRAZA " & integer'image(t) & ": off=0x" & to_hstring(trace(t)) &
               "  " & rw_str(trace_w(t));
      end if;
    end loop;
    report "DIAG accesos PCS totales   = " & integer'image(t_idx);
    report "DIAG dmem sel addr 0x14    = " & integer'image(n_sel14);
    report "DIAG dmem sel addr 0x10    = " & integer'image(n_sel10);
    report "DIAG dmem sel addr 0x30    = " & integer'image(n_sel30);
    report "DIAG ciclos AR totales     = " & integer'image(n_ar_tot);
    report "DIAG lecturas AXI a 0x14   = " & integer'image(n_rd14);
    report "DIAG irq_status en el AR    = 0x" & to_hstring(irq_at_ar);
    report "DIAG rdata devuelto en 0x14 = 0x" & to_hstring(rdata_14);
    report "DIAG reg_irq_status interno= 0x" &
      to_hstring(irq_int);

    -- veredicto
    if errors = 0 then
      report "LAYER5SIM_PASS firmware RV32 real contra PCS real: silicon pass ensayado"
        severity note;
    else
      report "LAYER5SIM_FAIL errores=" & integer'image(errors) severity note;
    end if;
    wait;
  end process;
end architecture;
