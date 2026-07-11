-- ptp_axil.vhd — wrapper AXI4-Lite del IP PTP / IEEE 802.1AS v1
-- ---------------------------------------------------------------------------
-- Envuelve ptp_top (interfaz MMIO sel/we/addr/wdata/rdata) en un esclavo
-- AXI4-Lite de 32b para el SoC RV32IM. Base 0x8000_0000, 64 KiB.
--
-- El banco de registros del IP usa direccion de PALABRA (addr[5:0]); el AXI
-- usa direccion de BYTE. Se traduce awaddr[7:2]/araddr[7:2] -> addr[5:0].
--
-- FSM AXI simple (una transaccion en vuelo). rdata del IP es combinacional, se
-- captura en el ciclo de arvalid&arready. Sin bursts (AXI-Lite).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity ptp_axil is
  generic (
    SHIFT_P : integer := SHIFT_P_DEF;
    SHIFT_I : integer := SHIFT_I_DEF
  );
  port (
    -- reloj y reset AXI (activo-bajo)
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    -- write address
    s_axi_awaddr  : in  std_logic_vector(15 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    -- write data
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    -- write response
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    -- read address
    s_axi_araddr  : in  std_logic_vector(15 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    -- read data
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;
    -- interrupcion
    irq           : out std_logic;
    -- pines MII (inertes en LOOP_INT v1)
    mii_txd       : out std_logic_vector(3 downto 0);
    mii_tx_en     : out std_logic;
    mii_rxd       : in  std_logic_vector(3 downto 0);
    mii_rx_dv     : in  std_logic
  );
end entity ptp_axil;

architecture rtl of ptp_axil is
  signal rst      : std_logic;
  -- MMIO hacia ptp_top
  signal mm_sel   : std_logic := '0';
  signal mm_we    : std_logic := '0';
  signal mm_addr  : std_logic_vector(5 downto 0);
  signal mm_wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal mm_rdata : std_logic_vector(31 downto 0);
  -- direcciones separadas por canal (un solo driver cada una)
  signal wr_addr_r : std_logic_vector(5 downto 0) := (others => '0');
  signal rd_addr_r : std_logic_vector(5 downto 0) := (others => '0');

  -- handshakes AXI
  signal awready_r : std_logic := '0';
  signal wready_r  : std_logic := '0';
  signal bvalid_r  : std_logic := '0';
  signal arready_r : std_logic := '0';
  signal rvalid_r  : std_logic := '0';
  signal rdata_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal aw_addr_r : std_logic_vector(5 downto 0) := (others => '0');
begin
  rst <= not s_axi_aresetn;

  s_axi_awready <= awready_r;
  s_axi_wready  <= wready_r;
  s_axi_bvalid  <= bvalid_r;
  s_axi_bresp   <= "00";                       -- OKAY siempre
  s_axi_arready <= arready_r;
  s_axi_rvalid  <= rvalid_r;
  s_axi_rdata   <= rdata_r;
  s_axi_rresp   <= "00";

  -- ---- canal de escritura ----
  wr_ch : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if rst = '1' then
        awready_r <= '0'; wready_r <= '0'; bvalid_r <= '0';
        mm_sel <= '0'; mm_we <= '0';
        aw_addr_r <= (others => '0');
      else
        mm_sel <= '0'; mm_we <= '0';
        -- aceptar direccion y datos de escritura cuando ambos validos
        if awready_r = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' then
          awready_r <= '1'; wready_r <= '1';
          aw_addr_r <= s_axi_awaddr(7 downto 2);   -- byte -> palabra
        else
          awready_r <= '0'; wready_r <= '0';
        end if;
        -- ejecutar la escritura al MMIO un ciclo tras aceptar
        if awready_r = '1' and wready_r = '1' then
          mm_sel    <= '1';
          mm_we     <= '1';
          wr_addr_r <= aw_addr_r;
          mm_wdata  <= s_axi_wdata;
          bvalid_r  <= '1';
        elsif bvalid_r = '1' and s_axi_bready = '1' then
          bvalid_r <= '0';
        end if;
      end if;
    end if;
  end process;

  -- ---- canal de lectura ----
  rd_ch : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if rst = '1' then
        arready_r <= '0'; rvalid_r <= '0'; rdata_r <= (others => '0');
      else
        if arready_r = '0' and s_axi_arvalid = '1' and rvalid_r = '0' then
          arready_r <= '1';
          -- presentar la direccion al MMIO (rdata combinacional)
          rd_addr_r <= s_axi_araddr(7 downto 2);
        else
          arready_r <= '0';
        end if;
        -- capturar rdata combinacional el ciclo tras presentar la direccion
        if arready_r = '1' then
          rdata_r  <= mm_rdata;
          rvalid_r <= '1';
        elsif rvalid_r = '1' and s_axi_rready = '1' then
          rvalid_r <= '0';
        end if;
      end if;
    end if;
  end process;

  -- mm_addr muxeado: durante una lectura (arready_r) se presenta rd_addr_r;
  -- en escritura, wr_addr_r. Un solo driver combinacional, sin conflicto.
  mm_addr <= rd_addr_r when arready_r = '1' else wr_addr_r;

  -- El sel al ptp_top se afirma tanto en escritura (mm_sel) como durante la
  -- presentacion de direccion de lectura (arready_r), ya que rdata es
  -- combinacional y debe estar valido en ese ciclo.
  u_ptp : entity work.ptp_top
    generic map (SHIFT_P => SHIFT_P, SHIFT_I => SHIFT_I)
    port map (clk => s_axi_aclk, rst => rst,
              sel => (mm_sel or arready_r), we => mm_we, addr => mm_addr,
              wdata => mm_wdata, rdata => mm_rdata, irq => irq,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv);

end architecture rtl;
