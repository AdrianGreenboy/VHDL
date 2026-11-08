-- ptp_axil.vhd — wrapper AXI4-Lite del IP PTP / IEEE 802.1AS v1
-- ---------------------------------------------------------------------------
-- Envuelve ptp_top (interfaz MMIO sel/we/addr/wdata/rdata) en un esclavo
-- AXI4-Lite de 32b para el SoC RV32IM. Base 0x8000_0000, 64 KiB.
--
-- El banco de registros del IP usa direccion de PALABRA (addr[5:0]); el AXI
-- usa direccion de BYTE. Se traduce awaddr[7:2]/araddr[7:2] -> addr[5:0].
--
-- Audit 2026-11 rewrite (ALTA):
--   * ONE transaction at a time: a single FSM serializes the write (AW+W) and
--     read (AR) channels, so the MMIO address/sel can never be shared by a
--     concurrent read and write (v1 muxed rd_addr over a write in flight and
--     could write to the read address). Reads and writes alternate priority
--     when both are pending (no starvation).
--   * AW/W are accepted together and wdata/wstrb/awaddr are captured AT the
--     handshake edge (v1 sampled s_axi_wdata one cycle after the handshake,
--     when the master may already have changed it).
--   * a new write is not accepted while BVALID is pending (v1 could
--     overwrite an unacknowledged response).
--   * WSTRB policy: "1111" -> write; "0000" -> no write, OKAY; any partial
--     strobe -> no write, SLVERR (all registers are 32-bit, several have
--     write side effects: CMD, STATUS W1C).
--   * all MMIO strobes (sel/we/addr/wdata) are registered.
-- rdata del IP es combinacional; se captura en el ciclo en que sel=1, we=0.
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
    -- pines MII (real MII with PHY clocks when CONTROL.loopback = 0)
    mii_rx_clk    : in  std_logic := '0';
    mii_tx_clk    : in  std_logic := '0';
    mii_txd       : out std_logic_vector(3 downto 0);
    mii_tx_en     : out std_logic;
    mii_rxd       : in  std_logic_vector(3 downto 0);
    mii_rx_dv     : in  std_logic
  );
end entity ptp_axil;

architecture rtl of ptp_axil is
  signal rst      : std_logic;
  type st_t is (S_IDLE, S_WACC, S_WR, S_B, S_RACC, S_RD, S_R);
  signal st       : st_t := S_IDLE;
  signal last_rd  : std_logic := '0';     -- fairness: '1' after a read

  -- MMIO hacia ptp_top (all registered)
  signal mm_sel   : std_logic := '0';
  signal mm_we    : std_logic := '0';
  signal mm_addr  : std_logic_vector(5 downto 0) := (others => '0');
  signal mm_wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal mm_rdata : std_logic_vector(31 downto 0);

  -- handshakes AXI
  signal awready_r, wready_r, arready_r : std_logic := '0';
  signal bvalid_r, rvalid_r : std_logic := '0';
  signal bresp_r  : std_logic_vector(1 downto 0) := "00";
  signal rdata_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal strb_r   : std_logic_vector(3 downto 0) := (others => '0');
begin
  rst <= not s_axi_aresetn;

  s_axi_awready <= awready_r;
  s_axi_wready  <= wready_r;
  s_axi_bvalid  <= bvalid_r;
  s_axi_bresp   <= bresp_r;
  s_axi_arready <= arready_r;
  s_axi_rvalid  <= rvalid_r;
  s_axi_rdata   <= rdata_r;
  s_axi_rresp   <= "00";

  p_fsm : process(s_axi_aclk)
    variable want_wr, want_rd : boolean;
  begin
    if rising_edge(s_axi_aclk) then
      mm_sel <= '0'; mm_we <= '0';
      awready_r <= '0'; wready_r <= '0'; arready_r <= '0';
      if rst = '1' then
        st <= S_IDLE; last_rd <= '0';
        bvalid_r <= '0'; rvalid_r <= '0'; bresp_r <= "00";
      else
        case st is
          when S_IDLE =>
            want_wr := s_axi_awvalid = '1' and s_axi_wvalid = '1';
            want_rd := s_axi_arvalid = '1';
            if want_wr and (not want_rd or last_rd = '1') then
              awready_r <= '1'; wready_r <= '1';      -- handshake next edge
              st <= S_WACC;
            elsif want_rd then
              arready_r <= '1';
              st <= S_RACC;
            end if;

          when S_WACC =>
            -- AW and W handshake on THIS edge (valids are held per AXI):
            -- capture address, data and strobes now
            mm_addr  <= s_axi_awaddr(7 downto 2);    -- byte -> palabra
            mm_wdata <= s_axi_wdata;
            strb_r   <= s_axi_wstrb;
            if s_axi_wstrb = "1111" then
              mm_sel <= '1'; mm_we <= '1';           -- write cycle in S_WR
            end if;
            st <= S_WR;

          when S_WR =>
            if strb_r = "1111" or strb_r = "0000" then
              bresp_r <= "00";                       -- OKAY
            else
              bresp_r <= "10";                       -- SLVERR: partial write refused
            end if;
            bvalid_r <= '1';
            last_rd  <= '0';
            st <= S_B;

          when S_B =>
            if s_axi_bready = '1' then
              bvalid_r <= '0';
              st <= S_IDLE;
            end if;

          when S_RACC =>
            mm_addr <= s_axi_araddr(7 downto 2);     -- AR handshake on this edge
            mm_sel  <= '1';                          -- read strobe in S_RD
            st <= S_RD;

          when S_RD =>
            rdata_r  <= mm_rdata;                    -- combinational rdata, sel=1
            rvalid_r <= '1';
            last_rd  <= '1';
            st <= S_R;

          when S_R =>
            if s_axi_rready = '1' then
              rvalid_r <= '0';
              st <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  u_ptp : entity work.ptp_top
    generic map (SHIFT_P => SHIFT_P, SHIFT_I => SHIFT_I)
    port map (clk => s_axi_aclk, rst => rst,
              sel => mm_sel, we => mm_we, addr => mm_addr,
              wdata => mm_wdata, rdata => mm_rdata, irq => irq,
              mii_rx_clk => mii_rx_clk, mii_tx_clk => mii_tx_clk,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv);

end architecture rtl;
