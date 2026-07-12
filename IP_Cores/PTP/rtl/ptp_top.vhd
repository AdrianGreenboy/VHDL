-- ptp_top.vhd — top del IP PTP / IEEE 802.1AS v1
-- ---------------------------------------------------------------------------
-- Une el banco de registros MMIO (ptp_regs) con el datapath TSN (ptp_mac).
-- Es el bloque que se instancia en el SoC RV32IM: interfaz MMIO sel/we/addr/
-- wdata/rdata + irq, y los pines MII (inertes en LOOP_INT v1).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity ptp_top is
  generic (
    SHIFT_P : integer := SHIFT_P_DEF;
    SHIFT_I : integer := SHIFT_I_DEF
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    -- MMIO
    sel       : in  std_logic;
    we        : in  std_logic;
    addr      : in  std_logic_vector(5 downto 0);
    wdata     : in  std_logic_vector(31 downto 0);
    rdata     : out std_logic_vector(31 downto 0);
    irq       : out std_logic;
    -- pines MII
    mii_txd   : out std_logic_vector(3 downto 0);
    mii_tx_en : out std_logic;
    mii_rxd   : in  std_logic_vector(3 downto 0);
    mii_rx_dv : in  std_logic
  );
end entity ptp_top;

architecture rtl of ptp_top is
  -- control regs -> datapath
  signal role_slave, loopback, enable : std_logic;
  signal kp, ki, tx_lat, rx_lat : std_logic_vector(15 downto 0);
  signal clock_id : std_logic_vector(63 downto 0);
  signal port_num : std_logic_vector(15 downto 0);
  signal src_mac : std_logic_vector(47 downto 0);
  signal send_sync, start_pdelay : std_logic;
  -- datapath -> status regs
  signal now_sec : std_logic_vector(SEC_W-1 downto 0);
  signal now_ns  : std_logic_vector(NS_W-1 downto 0);
  signal mpd_ns  : std_logic_vector(63 downto 0);
  signal mpd_valid, offset_valid, rx_sync_ev, rx_resp_ev : std_logic;
  signal offset_ns : std_logic_vector(ERR_W-1 downto 0);
  signal rate_adj : std_logic_vector(RATE_W-1 downto 0);
  -- filtro RX derivado: multicast gPTP, byte0 en [7:0]
  constant GPTP_MC : std_logic_vector(47 downto 0) := x"0E0000C28001";
  signal dbg_state_sig : std_logic_vector(31 downto 0);
  signal dbg_rxdst_sig : std_logic_vector(47 downto 0);
  signal dbg_rxinfo_sig : std_logic_vector(31 downto 0);
  signal dbg_fptr_sig : std_logic_vector(31 downto 0);
  signal dbg_ftx_sig : std_logic_vector(31 downto 0);
begin

  u_regs : entity work.ptp_regs
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
              wdata => wdata, rdata => rdata, irq => irq,
              role_slave => role_slave, loopback => loopback, enable => enable,
              kp => kp, ki => ki, tx_lat => tx_lat, rx_lat => rx_lat,
              clock_id => clock_id, port_num => port_num, src_mac => src_mac,
              send_sync => send_sync, start_pdelay => start_pdelay,
              now_sec => now_sec, now_ns => now_ns, mpd_ns => mpd_ns,
              mpd_valid => mpd_valid, offset_ns => offset_ns, offset_valid => offset_valid,
              rate_adj => rate_adj, rx_sync_ev => rx_sync_ev, rx_resp_ev => rx_resp_ev, dbg_state => dbg_state_sig, dbg_rxdst => dbg_rxdst_sig, dbg_rxinfo => dbg_rxinfo_sig, dbg_fptr => dbg_fptr_sig, dbg_ftx => dbg_ftx_sig);

  u_mac : entity work.ptp_mac
    generic map (SHIFT_P => SHIFT_P, SHIFT_I => SHIFT_I)
    port map (clk => clk, rst => rst, loopback => loopback,
              role_slave => role_slave, clock_id => clock_id, port_num => port_num,
              src_mac => src_mac, macaddr => GPTP_MC,
              kp => kp, ki => ki, tx_lat => tx_lat, rx_lat => rx_lat,
              send_sync => send_sync, start_pdelay => start_pdelay,
              now_sec => now_sec, now_ns => now_ns, mpd_ns => mpd_ns, mpd_valid => mpd_valid,
              offset_ns => offset_ns, rate_adj => rate_adj,
              offset_valid_o => offset_valid, rx_sync_ev => rx_sync_ev, rx_resp_ev => rx_resp_ev,
              dbg_rx_mvalid => open, dbg_rx_mtype => open, dbg_rx_seqid => open,
              dbg_t1_ns => open, dbg_t4_ns => open, dbg_pd_corr => open, dbg_pd_calc => open,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv, dbg_state => dbg_state_sig, dbg_rxdst => dbg_rxdst_sig, dbg_rxinfo => dbg_rxinfo_sig, dbg_fptr => dbg_fptr_sig, dbg_ftx => dbg_ftx_sig);

end architecture rtl;
