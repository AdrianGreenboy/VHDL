-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 4: mac25g_top por registros, con relojes reales de la TE0950
-- (aclk 40 MHz, clk_dp 390.625 MHz). Acceso directo AXI4-Lite o, con
-- BRIDGE=true, a traves de pcs_mmio_bridge (Core 19), el mismo camino que
-- usa el RV32 en el SoC.
--
-- Secuencia (la misma del firmware):
--   ID -> configuracion -> CTRL=MAC_EN|LOOPBACK -> CMD=SOFT_RESET -> LINK_UP
--   -> CMD=CNT_CLEAR -> CMD=GEN_START -> GEN_DONE -> drenaje -> SNAP ->
--   SNAP_DONE -> 16 contadores == oraculo (l3_l3a)
--   -> CMD=CNT_CLEAR -> CMD=GEN_START|INJ -> ... == oraculo (l3_l3b)
--   -> IRQ_STATUS: GEN_DONE y RX_CRC_ERR activos; W1C los limpia.
--   -> con el dominio dp en reset, dos escrituras seguidas a CMD no cuelgan
--      el bus (timeout) y STATUS.CMD_TIMEOUT se activa.
-- Un monitor comprueba en todo momento que B y R llegan DESPUES de su
-- handshake (BVALID nunca junto a AWREADY, RVALID nunca junto a ARREADY).
-- Criterio: LAYER4_PASS (o LAYER4MMIO_PASS con BRIDGE=true).
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_mac_top is
  generic (BRIDGE : boolean := false);
end entity;

architecture sim of tb_mac_top is
  constant TA : time := 25 ns;
  constant TD : time := 2.56 ns;
  signal aclk, clk_dp : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal rst_dp  : std_logic := '1';
  signal done_sim : boolean := false;

  signal awaddr, araddr : std_logic_vector(7 downto 0) := (others => '0');
  signal awvalid, awready, wvalid, wready, bvalid, bready : std_logic := '0';
  signal arvalid, arready, rvalid, rready : std_logic := '0';
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb : std_logic_vector(3 downto 0) := (others => '0');
  signal bresp, rresp : std_logic_vector(1 downto 0);
  signal irq : std_logic;
  signal axi_errs : natural := 0;

  -- lado MMIO del puente
  signal m_sel, m_ready : std_logic := '0';
  signal m_wstrb : std_logic_vector(3 downto 0) := (others => '0');
  signal m_addr  : std_logic_vector(7 downto 0) := (others => '0');
  signal m_wdata, m_rdata : std_logic_vector(31 downto 0) := (others => '0');
  -- AXI del BFM directo
  signal t_awaddr, t_araddr : std_logic_vector(7 downto 0) := (others => '0');
  signal t_awvalid, t_wvalid, t_bready, t_arvalid, t_rready : std_logic := '0';
  signal t_wdata : std_logic_vector(31 downto 0) := (others => '0');
  -- AXI del puente
  signal b_awaddr, b_araddr : std_logic_vector(7 downto 0);
  signal b_awvalid, b_wvalid, b_bready, b_arvalid, b_rready : std_logic;
  signal b_wdata : std_logic_vector(31 downto 0);
  signal b_wstrb : std_logic_vector(3 downto 0);
begin
  aclk   <= not aclk after TA/2 when not done_sim;
  clk_dp <= not clk_dp after TD/2 when not done_sim;

  dut: entity work.mac25g_top
    port map (s_axi_aclk=>aclk, s_axi_aresetn=>aresetn,
              s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
              s_axi_wdata=>wdata, s_axi_wstrb=>wstrb, s_axi_wvalid=>wvalid,
              s_axi_wready=>wready, s_axi_bresp=>bresp, s_axi_bvalid=>bvalid,
              s_axi_bready=>bready, s_axi_araddr=>araddr, s_axi_arvalid=>arvalid,
              s_axi_arready=>arready, s_axi_rdata=>rdata, s_axi_rresp=>rresp,
              s_axi_rvalid=>rvalid, s_axi_rready=>rready, irq_out=>irq,
              clk_dp=>clk_dp, rst_dp=>rst_dp);

  g_br: if BRIDGE generate
    u_br: entity work.pcs_mmio_bridge
      port map (clk=>aclk, aresetn=>aresetn, sel=>m_sel, wstrb=>m_wstrb,
                addr=>m_addr, wdata=>m_wdata, rdata=>m_rdata, ready=>m_ready,
                m_awaddr=>b_awaddr, m_awvalid=>b_awvalid, m_awready=>awready,
                m_wdata=>b_wdata, m_wstrb=>b_wstrb, m_wvalid=>b_wvalid, m_wready=>wready,
                m_bresp=>bresp, m_bvalid=>bvalid, m_bready=>b_bready,
                m_araddr=>b_araddr, m_arvalid=>b_arvalid, m_arready=>arready,
                m_rdata=>rdata, m_rresp=>rresp, m_rvalid=>rvalid, m_rready=>b_rready);
    awaddr <= b_awaddr; awvalid <= b_awvalid; wdata <= b_wdata; wstrb <= b_wstrb;
    wvalid <= b_wvalid; bready <= b_bready; araddr <= b_araddr; arvalid <= b_arvalid;
    rready <= b_rready;
  end generate;
  g_ax: if not BRIDGE generate
    awaddr <= t_awaddr; awvalid <= t_awvalid; wdata <= t_wdata; wstrb <= x"F";
    wvalid <= t_wvalid; bready <= t_bready; araddr <= t_araddr; arvalid <= t_arvalid;
    rready <= t_rready;
  end generate;

  -- watchdog global: un bus colgado (p. ej. CMD retenido para siempre) es un fallo
  process
  begin
    wait for 500 us;
    assert done_sim report "TIMEOUT global: bus AXI colgado" severity failure;
    wait;
  end process;

  -- monitor de protocolo AXI (respuesta posterior al handshake)
  process(aclk)
  begin
    if rising_edge(aclk) then
      if bvalid = '1' and awready = '1' then
        report "FAIL AXI: BVALID en el mismo ciclo que AWREADY" severity error;
        axi_errs <= axi_errs + 1;
      end if;
      if rvalid = '1' and arready = '1' then
        report "FAIL AXI: RVALID en el mismo ciclo que ARREADY" severity error;
        axi_errs <= axi_errs + 1;
      end if;
    end if;
  end process;

  process
    variable errs : natural := 0;
    variable v : std_logic_vector(31 downto 0);
    variable h : unsigned(31 downto 0);

    procedure wr(a : natural; d : std_logic_vector(31 downto 0)) is
    begin
      if BRIDGE then
        m_addr <= std_logic_vector(to_unsigned(a, 8)); m_wdata <= d;
        m_wstrb <= x"F"; m_sel <= '1';
        wait until rising_edge(aclk) and m_ready = '1';
        m_sel <= '0'; m_wstrb <= x"0";
        wait until rising_edge(aclk);
      else
        t_awaddr <= std_logic_vector(to_unsigned(a, 8)); t_wdata <= d;
        t_awvalid <= '1'; t_wvalid <= '1'; t_bready <= '1';
        wait until rising_edge(aclk) and awready = '1';
        t_awvalid <= '0'; t_wvalid <= '0';
        if bvalid = '0' then wait until rising_edge(aclk) and bvalid = '1'; end if;
        wait until rising_edge(aclk);
        t_bready <= '0';
      end if;
    end procedure;

    procedure rd(a : natural; d : out std_logic_vector(31 downto 0)) is
    begin
      if BRIDGE then
        m_addr <= std_logic_vector(to_unsigned(a, 8)); m_wstrb <= x"0"; m_sel <= '1';
        wait until rising_edge(aclk) and m_ready = '1';
        d := m_rdata;
        m_sel <= '0';
        wait until rising_edge(aclk);
      else
        t_araddr <= std_logic_vector(to_unsigned(a, 8)); t_arvalid <= '1'; t_rready <= '1';
        wait until rising_edge(aclk) and arready = '1';
        t_arvalid <= '0';
        if rvalid = '0' then wait until rising_edge(aclk) and rvalid = '1'; end if;
        d := rdata;
        wait until rising_edge(aclk);
        t_rready <= '0';
      end if;
    end procedure;

    procedure poll(a, bit_i : natural; tmo_us : natural) is
      variable x : std_logic_vector(31 downto 0);
      variable t0 : time := now;
    begin
      loop
        rd(a, x);
        exit when x(bit_i) = '1';
        assert now - t0 < tmo_us * 1 us
          report "TIMEOUT esperando bit " & integer'image(bit_i) & " de 0x" &
            to_hstring(std_logic_vector(to_unsigned(a, 8))) severity failure;
      end loop;
    end procedure;

    procedure run_burst(vec : string; cmd : std_logic_vector(31 downto 0)) is
      file f : text;
      variable l : line;
      variable e, g, slots : integer;
      variable x : std_logic_vector(31 downto 0);
    begin
      wr(16#0C#, x"00000002");                -- CNT_CLEAR
      wr(16#0C#, cmd);                        -- GEN_START (| INJ)
      poll(16#10#, 2, 200);                   -- GEN_DONE
      wait for 2 us;                          -- drenaje
      wr(16#1C#, x"00000001");                -- SNAP
      poll(16#10#, 8, 10);                    -- SNAP_DONE
      file_open(f, vec, read_mode);
      for i in 0 to 15 loop
        readline(f, l); read(l, e);
        rd(16#40# + 4*i, x);
        g := to_integer(unsigned(x));
        if i = 14 then
          slots := e;
          if g < slots - 3 or g > (slots*33)/32 + 64 then
            report "FAIL BURST_CYCLES " & integer'image(g) severity error;
            errs := errs + 1;
          end if;
        elsif g /= e then
          report "FAIL contador " & integer'image(i) & " = " & integer'image(g) &
            " esperado " & integer'image(e) severity error;
          errs := errs + 1;
        end if;
      end loop;
      file_close(f);
    end procedure;
  begin
    aresetn <= '0'; rst_dp <= '1';
    wait for 200 ns;
    wait until rising_edge(aclk); aresetn <= '1';
    wait until rising_edge(clk_dp); rst_dp <= '0';
    wait for 100 ns;

    rd(16#00#, v);
    if v /= x"4D414320" then report "FAIL ID " & to_hstring(v) severity error; errs := errs + 1; end if;
    wr(16#04#, x"A5A55A5A"); rd(16#04#, v);
    if v /= x"A5A55A5A" then report "FAIL SCRATCH" severity error; errs := errs + 1; end if;
    -- configuracion del oraculo (GenCfg por defecto)
    wr(16#20#, x"43414D02"); wr(16#24#, x"00002032");
    wr(16#28#, x"45474E02"); wr(16#2C#, x"0000204E");
    wr(16#30#, std_logic_vector(to_unsigned(1514, 16)) & std_logic_vector(to_unsigned(20, 16)));
    wr(16#34#, x"00000025");                  -- 37
    wr(16#38#, x"00000040");                  -- 64 tramas
    rd(16#30#, v);
    if v /= x"05EA0014" then report "FAIL LEN_CFG readback" severity error; errs := errs + 1; end if;
    wr(16#18#, x"0000000F");                  -- IRQ_ENABLE
    wr(16#08#, x"00000003");                  -- MAC_EN | LOOPBACK
    wr(16#0C#, x"00000001");                  -- SOFT_RESET (captura config)
    poll(16#10#, 0, 20);                      -- LINK_UP

    run_burst("l3_l3a.txt", x"00000004");
    rd(16#14#, v);
    if v(0) /= '1' or v(1) /= '0' or v(2) /= '0' then
      report "FAIL IRQ_STATUS tras rafaga limpia = " & to_hstring(v) severity error;
      errs := errs + 1;
    end if;
    if irq /= '1' then report "FAIL irq_out no activo" severity error; errs := errs + 1; end if;
    wr(16#14#, x"0000000F");                  -- W1C
    rd(16#14#, v);
    if v(3 downto 0) /= "0000" then report "FAIL W1C" severity error; errs := errs + 1; end if;

    run_burst("l3_l3b.txt", x"00000014");     -- GEN_START | INJ
    rd(16#14#, v);
    if v(0) /= '1' or v(1) /= '1' or v(2) /= '0' then
      report "FAIL IRQ_STATUS tras inyeccion = " & to_hstring(v) severity error;
      errs := errs + 1;
    end if;
    rd(16#10#, v);
    if v(0) /= '1' or v(2) /= '1' or v(3) /= '1' or v(4) /= '1' then
      report "FAIL STATUS final = " & to_hstring(v) severity error;
      errs := errs + 1;
    end if;

    -- dominio dp parado: el CMD no se confirma nunca -> timeout, sin cuelgue
    rst_dp <= '1';
    wait for 100 ns;
    wr(16#0C#, x"00000002");
    wr(16#0C#, x"00000002");                  -- colgaria sin timeout
    rd(16#10#, v);
    if v(10) /= '1' then
      report "FAIL: CMD_TIMEOUT no activo con el dominio dp en reset" severity error;
      errs := errs + 1;
    end if;
    wait until rising_edge(clk_dp); rst_dp <= '0';
    errs := errs + axi_errs;

    if errs = 0 then
      if BRIDGE then report "LAYER4MMIO_PASS STATUS=0x" & to_hstring(v);
      else report "LAYER4_PASS STATUS=0x" & to_hstring(v); end if;
    else
      report "LAYER4_FAIL errores=" & integer'image(errs) severity error;
    end if;
    done_sim <= true;
    wait;
  end process;
end architecture;
