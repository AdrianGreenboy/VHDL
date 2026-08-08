-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Testbench del TOP pcs_stats_top: ensayo de la secuencia de firmware del
-- silicon pass, ejecutada via AXI4-Lite con dos relojes reales (AXI 100 MHz,
-- data plane 390.625 MHz).
--
-- Secuencia (la misma que el firmware RV32 ejecutara en silicio):
--   1. Leer ID == 0x50435319
--   2. PRBS_CTRL = GEN_EN | CHK_EN
--   3. CTRL = PCS_EN | TX_EN | RX_EN | LOOPBACK  (arranca la cadena)
--   4. Esperar bring-up; CMD = PRBS_RESET (limpia BER del transitorio)
--   5. Ventana de medida limpia; STATS_SNAP; leer CNT_BER == 0,
--      CNT_TX/RX > 0, STATUS con BLOCK_LOCK y PRBS_LOCK
--   6. PRBS_CTRL |= INJ (inyecta 1 bit); esperar; STATS_SNAP;
--      leer CNT_BER == 9; IRQ_STATUS con EV_PRBS_ERR sticky
--
-- PASS: todas las propiedades. Es la verificacion Layer 4 del top y el
-- ensayo 1:1 del Layer 5.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_stats_top is end entity;

architecture sim of tb_pcs_stats_top is
  -- relojes reales: AXI 100 MHz (10 ns), DP 390.625 MHz (2.56 ns)
  signal clk_axi : std_logic := '0';
  signal clk_dp  : std_logic := '0';
  signal rstn    : std_logic := '0';
  signal rst_dp  : std_logic := '1';

  signal awaddr  : std_logic_vector(7 downto 0) := (others=>'0');
  signal awvalid, awready : std_logic := '0';
  signal wdata   : std_logic_vector(31 downto 0) := (others=>'0');
  signal wstrb   : std_logic_vector(3 downto 0) := "1111";
  signal wvalid, wready : std_logic := '0';
  signal bresp   : std_logic_vector(1 downto 0);
  signal bvalid  : std_logic; signal bready : std_logic := '0';
  signal araddr  : std_logic_vector(7 downto 0) := (others=>'0');
  signal arvalid, arready : std_logic := '0';
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rvalid  : std_logic; signal rready : std_logic := '0';
  signal irq     : std_logic;

  signal dma_addr, dma_db : std_logic_vector(31 downto 0);

  signal errors : natural := 0;

  -- offsets
  constant OFF_ID        : std_logic_vector(7 downto 0) := x"00";
  constant OFF_CTRL      : std_logic_vector(7 downto 0) := x"08";
  constant OFF_CMD       : std_logic_vector(7 downto 0) := x"0C";
  constant OFF_STATUS    : std_logic_vector(7 downto 0) := x"10";
  constant OFF_IRQ_ST    : std_logic_vector(7 downto 0) := x"14";
  constant OFF_PRBS_CTRL : std_logic_vector(7 downto 0) := x"1C";
  constant OFF_SNAP      : std_logic_vector(7 downto 0) := x"20";
  constant OFF_CNT_TX    : std_logic_vector(7 downto 0) := x"24";
  constant OFF_CNT_RX    : std_logic_vector(7 downto 0) := x"28";
  constant OFF_CNT_BER   : std_logic_vector(7 downto 0) := x"30";
begin
  clk_axi <= not clk_axi after 5 ns;      -- 100 MHz
  clk_dp  <= not clk_dp  after 1.28 ns;   -- 390.625 MHz

  dut: entity work.pcs_stats_top
    port map (
      s_axi_aclk=>clk_axi, s_axi_aresetn=>rstn,
      s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
      s_axi_wdata=>wdata, s_axi_wstrb=>wstrb, s_axi_wvalid=>wvalid, s_axi_wready=>wready,
      s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,
      s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,
      s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready,
      irq_out=>irq,
      clk_dp=>clk_dp, rst_dp=>rst_dp,
      dma_addr=>dma_addr, dma_doorbell=>dma_db,
      dma_busy=>'0', dma_done_pulse=>'0'
    );

  main: process
    variable rd : std_logic_vector(31 downto 0);
    variable ber_clean : unsigned(31 downto 0);

    procedure axi_wr(addr : std_logic_vector(7 downto 0);
                     data : std_logic_vector(31 downto 0)) is
      variable aw_done, w_done : boolean;
    begin
      awaddr <= addr; awvalid <= '1';
      wdata  <= data; wvalid  <= '1';
      bready <= '1';
      aw_done := false; w_done := false;
      while not (aw_done and w_done) loop
        wait until rising_edge(clk_axi);
        if awvalid = '1' and awready = '1' then aw_done := true; awvalid <= '0'; end if;
        if wvalid  = '1' and wready  = '1' then w_done  := true; wvalid  <= '0'; end if;
      end loop;
      while bvalid /= '1' loop wait until rising_edge(clk_axi); end loop;
      wait until rising_edge(clk_axi);
      bready <= '0';
      wait until rising_edge(clk_axi);
    end procedure;

    procedure axi_rd(addr : std_logic_vector(7 downto 0);
                     data : out std_logic_vector(31 downto 0)) is
    begin
      araddr <= addr; arvalid <= '1'; rready <= '1';
      while not (arvalid = '1' and arready = '1') loop
        wait until rising_edge(clk_axi);
        if arvalid = '1' and arready = '1' then arvalid <= '0'; end if;
      end loop;
      arvalid <= '0';
      while rvalid /= '1' loop wait until rising_edge(clk_axi); end loop;
      data := rdata;
      wait until rising_edge(clk_axi);
      rready <= '0';
      wait until rising_edge(clk_axi);
    end procedure;
  begin
    rstn <= '0'; rst_dp <= '1';
    wait for 100 ns;
    wait until rising_edge(clk_axi); rstn <= '1';
    wait until rising_edge(clk_dp);  rst_dp <= '0';
    wait for 100 ns;
    wait until rising_edge(clk_axi);

    -- 1. ID
    axi_rd(OFF_ID, rd);
    assert rd = x"50435319"
      report "FW1 FAIL: ID incorrecto " & to_hstring(rd) severity error;
    if rd /= x"50435319" then errors <= errors + 1; end if;
    report "FW1 ID = 0x" & to_hstring(rd);

    -- 2. PRBS_CTRL = GEN_EN | CHK_EN
    axi_wr(OFF_PRBS_CTRL, x"00000003");

    -- 3. CTRL = PCS_EN|TX_EN|RX_EN|LOOPBACK -> arranca la cadena
    axi_wr(OFF_CTRL, x"0000000F");

    -- 4. SOFT_RESET: reinicia el silicon datapath atomicamente con todos los
    -- enables ya estables (evita el arranque desalineado por enables
    -- escalonados: el RX gearbox debe ver el stream desde la palabra 0).
    axi_wr(OFF_CMD, x"00000001");   -- CMD_SOFT_RESET
    wait for 2 us;                  -- bring-up de la cadena limpia
    axi_wr(OFF_CMD, x"00000008");   -- CMD_PRBS_RESET (descarta transitorio)

    -- 5. ventana de medida limpia
    wait for 5 us;
    axi_wr(OFF_SNAP, x"00000001");  -- STATS_SNAP
    wait for 1 us;                  -- cruce CDC del snapshot
    axi_rd(OFF_CNT_BER, rd);
    ber_clean := unsigned(rd);
    assert ber_clean = 0
      report "FW5 FAIL: BER no cero en ventana limpia: " & to_hstring(rd) severity error;
    if ber_clean /= 0 then errors <= errors + 1; end if;
    axi_rd(OFF_CNT_TX, rd);
    assert unsigned(rd) > 0
      report "FW5 FAIL: CNT_TX_BLK cero" severity error;
    if unsigned(rd) = 0 then errors <= errors + 1; end if;
    report "FW5 snapshot limpio: CNT_TX=0x" & to_hstring(rd);
    axi_rd(OFF_CNT_RX, rd);
    assert unsigned(rd) > 0
      report "FW5 FAIL: CNT_RX_BLK cero" severity error;
    if unsigned(rd) = 0 then errors <= errors + 1; end if;
    axi_rd(OFF_STATUS, rd);
    -- ST_BLOCK_LOCK=bit0, ST_PRBS_LOCK=bit3
    assert rd(0) = '1'
      report "FW5 FAIL: sin BLOCK_LOCK" severity error;
    if rd(0) /= '1' then errors <= errors + 1; end if;
    assert rd(3) = '1'
      report "FW5 FAIL: sin PRBS_LOCK" severity error;
    if rd(3) /= '1' then errors <= errors + 1; end if;
    report "FW5 STATUS = 0x" & to_hstring(rd);

    -- 6. inyeccion: PRBS_CTRL con INJ -> 1 bit -> BER debe ser 9
    axi_wr(OFF_PRBS_CTRL, x"00000007");   -- GEN|CHK|INJ (INJ auto-clear)
    wait for 2 us;
    axi_wr(OFF_SNAP, x"00000001");
    wait for 1 us;
    axi_rd(OFF_CNT_BER, rd);
    assert unsigned(rd) = 9
      report "FW6 FAIL: BER tras inyeccion no es 9: " & to_hstring(rd) severity error;
    if unsigned(rd) /= 9 then errors <= errors + 1; end if;
    report "FW6 BER tras inyeccion = 0x" & to_hstring(rd) & " (esperado 9)";
    axi_rd(OFF_IRQ_ST, rd);
    -- EV_PRBS_ERR = bit 4
    assert rd(4) = '1'
      report "FW6 FAIL: sticky EV_PRBS_ERR no activo" severity error;
    if rd(4) /= '1' then errors <= errors + 1; end if;
    report "FW6 IRQ_STATUS = 0x" & to_hstring(rd);

    wait for 10 ns;
    if errors = 0 then
      report "LAYER4TOP_PASS secuencia de firmware completa OK" severity note;
    else
      report "LAYER4TOP_FAIL errores=" & integer'image(errors) severity error;
    end if;
    std.env.stop;
  end process;

end architecture;
