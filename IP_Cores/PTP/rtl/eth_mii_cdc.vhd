-- eth_mii_cdc.vhd - MII PHY clock-domain interface (one port, RX + TX)
-- ---------------------------------------------------------------------------
-- Moves the MII nibble streams between the PHY clocks (RX_CLK, TX_CLK; both
-- 25 MHz for 100 Mb/s or 2.5 MHz for 10 Mb/s, +/-100 ppm, unrelated to the
-- core clock) and the core clock. The frame engines (eth_rx_mii /
-- eth_tx_mii) stay in the core domain and are paced by the clock-enables
-- produced here; ONLY this block touches the PHY clocks. This keeps a
-- single engine instance per port, no clock multiplexer for the LOOP_INT /
-- injector modes (which keep using the internal /4 enable), and a narrow,
-- auditable CDC boundary.
--
-- RX (RX_CLK domain -> core):
--   * pads registered on RX_CLK rising edge (IOB register; MII: the PHY
--     drives RXD/RX_DV so that they are stable around RX_CLK rising).
--   * EVERY RX_CLK cycle (idle included) the registered {rx_dv, rxd} nibble
--     is written into a Gray-pointer async FIFO (eth_async_fifo, 8 deep).
--   * core side pops whenever non-empty and emits rx_ce + nibble (registered)
--     to the RX engine. Because the core (>= 4x MII rate) always drains the
--     FIFO immediately, its occupancy is <= 1 and every nibble sees the same
--     latency to within one core clock -> deterministic RX SFD timestamp.
--   * FIFO full on write (only possible if f_core < ~2 f_mii) drops the
--     nibble and raises rx_ovf (pulse-synchronized to core).
-- TX (core -> TX_CLK domain):
--   * the TX engine produces one nibble per tx_ce; tx_ce is asserted while
--     the async FIFO has room, so the engine runs ahead and keeps the FIFO
--     near full; the TX_CLK side pops one entry per TX_CLK (idle included)
--     and drives the pads from registers. The stream is continuous, so the
--     engine's preamble/IPG nibble counts are preserved exactly on the wire.
--   * each entry carries an SFD tag (engine's tx_sfd pulse). When the tagged
--     nibble is LAUNCHED on the wire, the TX_CLK side toggles an event that
--     is pulse-synchronized to core -> tx_sfd_wire. This timestamps the real
--     wire instant (not the earlier production instant).
--   * if the FIFO is empty while a frame is on the wire, TX_EN is dropped and
--     tx_unf is raised (cannot happen with f_core >= ~2 f_mii).
-- Resets: rst (core, sync active-high) feeds an eth_rst_sync per PHY domain;
-- the core side of each FIFO is held in reset until the matching PHY domain
-- has left reset (observed through a 2-FF synchronizer), so the core never
-- reads an unreset pointer even if the PHY clock starts late.
--
-- Timestamp accuracy (both directions): fixed latency (calibrated with the
-- TX_LAT/RX_LAT registers) + uniform quantization of ONE core clock (10 ns
-- p-p at 100 MHz) from the 2-FF synchronizers. Measured values: see
-- tb_eth_mii_cdc / AUDIT_FIXES.md. PHY-internal latency is NOT included and
-- must be calibrated on the board.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_mii_cdc is
  generic (
    G_LOG2_DEPTH : positive := 3
  );
  port (
    -- core domain
    clk         : in  std_logic;
    rst         : in  std_logic;                     -- sync, active high
    -- RX nibble stream to the RX engine (core domain)
    rx_ce       : out std_logic;
    rx_nib      : out std_logic_vector(3 downto 0);
    rx_dv       : out std_logic;
    -- TX nibble stream from the TX engine (core domain)
    tx_ce       : out std_logic;                     -- engine may advance
    tx_nib      : in  std_logic_vector(3 downto 0);  -- engine txd (registered)
    tx_en       : in  std_logic;                     -- engine tx_en (registered)
    tx_sfd      : in  std_logic;                     -- engine SFD pulse (aligned)
    tx_sfd_wire : out std_logic;                     -- pulse: SFD launched on wire
    -- diagnostics (core-domain pulses)
    rx_ovf      : out std_logic;
    tx_unf      : out std_logic;
    -- PHY pins
    mii_rx_clk  : in  std_logic;
    mii_rxd     : in  std_logic_vector(3 downto 0);
    mii_rx_dv   : in  std_logic;
    mii_tx_clk  : in  std_logic;
    mii_txd     : out std_logic_vector(3 downto 0);
    mii_tx_en   : out std_logic
  );
end entity eth_mii_cdc;

architecture rtl of eth_mii_cdc is
  constant DEPTH : natural := 2**G_LOG2_DEPTH;

  -- reset per domain
  signal rst_rx, rst_tx         : std_logic;
  signal rx_up, tx_up           : std_logic;     -- PHY domain out of reset (core view)
  signal rrst_c, wrst_c         : std_logic;

  -- RX domain
  signal rxd_q   : std_logic_vector(3 downto 0) := (others => '0');
  signal rxdv_q  : std_logic := '0';
  signal rxq_vld : std_logic := '0';               -- IOB register holds a sample
  signal rxf_full : std_logic;
  signal rx_ovf_p : std_logic := '0';
  signal rxf_wdat : std_logic_vector(4 downto 0);

  -- RX core side
  signal rxf_head  : std_logic_vector(4 downto 0);
  signal rxf_empty : std_logic;
  signal rxf_ren   : std_logic;
  signal rx_ce_r   : std_logic := '0';
  signal rx_nib_r  : std_logic_vector(3 downto 0) := (others => '0');
  signal rx_dv_r   : std_logic := '0';

  -- TX core side
  signal txf_full  : std_logic;
  signal txf_level : unsigned(G_LOG2_DEPTH downto 0);
  signal tx_ce_r   : std_logic := '0';
  signal tx_ce_d   : std_logic := '0';
  signal txf_wdat  : std_logic_vector(5 downto 0);

  -- TX domain
  signal txf_head  : std_logic_vector(5 downto 0);
  signal txf_empty : std_logic;
  signal txf_ren   : std_logic;
  signal txd_o     : std_logic_vector(3 downto 0) := (others => '0');
  signal txen_o    : std_logic := '0';
  signal sfd_launch : std_logic;
  signal unf_p     : std_logic := '0';
begin
  -- ===================== resets =====================
  u_rst_rx : entity work.eth_rst_sync port map (clk => mii_rx_clk, rst_in => rst, rst_out => rst_rx);
  u_rst_tx : entity work.eth_rst_sync port map (clk => mii_tx_clk, rst_in => rst, rst_out => rst_tx);
  -- core sees "PHY domain is out of reset" only after its reset deasserted
  u_rx_up : entity work.eth_sync_bit port map (clk => clk, rst => rst, d => not rst_rx, q => rx_up);
  u_tx_up : entity work.eth_sync_bit port map (clk => clk, rst => rst, d => not rst_tx, q => tx_up);
  rrst_c <= rst or not rx_up;
  wrst_c <= rst or not tx_up;

  -- ===================== RX =====================
  p_rx_pads : process(mii_rx_clk)
  begin
    if rising_edge(mii_rx_clk) then
      rx_ovf_p <= '0';
      if rst_rx = '1' then
        rxd_q <= (others => '0'); rxdv_q <= '0'; rxq_vld <= '0';
      else
        rxd_q   <= mii_rxd;
        rxdv_q  <= mii_rx_dv;
        rxq_vld <= '1';
        if rxq_vld = '1' and rxf_full = '1' then
          rx_ovf_p <= '1';                          -- nibble lost
        end if;
      end if;
    end if;
  end process;

  rxf_wdat <= rxdv_q & rxd_q;

  u_rxf : entity work.eth_async_fifo
    generic map (WIDTH => 5, LOG2_DEPTH => G_LOG2_DEPTH)
    port map (wclk => mii_rx_clk, wrst => rst_rx, wen => rxq_vld, wdata => rxf_wdat,
              wfull => rxf_full, wlevel => open,
              rclk => clk, rrst => rrst_c, ren => rxf_ren, rdata => rxf_head,
              rempty => rxf_empty);

  rxf_ren <= not rxf_empty;                         -- always drain

  p_rx_core : process(clk)
  begin
    if rising_edge(clk) then
      if rrst_c = '1' then
        rx_ce_r <= '0'; rx_dv_r <= '0'; rx_nib_r <= (others => '0');
      else
        rx_ce_r <= not rxf_empty;
        if rxf_empty = '0' then
          rx_dv_r  <= rxf_head(4);
          rx_nib_r <= rxf_head(3 downto 0);
        end if;
      end if;
    end if;
  end process;

  rx_ce  <= rx_ce_r;
  rx_nib <= rx_nib_r;
  rx_dv  <= rx_dv_r;

  u_ovf : entity work.eth_pulse_sync
    port map (src_clk => mii_rx_clk, src_rst => rst_rx, src_pulse => rx_ovf_p,
              dst_clk => clk, dst_rst => rst, dst_pulse => rx_ovf);

  -- ===================== TX =====================
  -- tx_ce_r = engine advances this cycle; its registered nibble is pushed the
  -- next cycle (tx_ce_d). A new ce is only granted if, after the push already
  -- in flight (tx_ce_d) and the one being granted, one slot remains.
  p_tx_core : process(clk)
    variable used : integer range 0 to 2*DEPTH;
  begin
    if rising_edge(clk) then
      if wrst_c = '1' then
        tx_ce_r <= '0'; tx_ce_d <= '0';
      else
        tx_ce_d <= tx_ce_r;
        used := to_integer(txf_level);
        if tx_ce_r = '1' then used := used + 1; end if;
        if tx_ce_d = '1' then used := used + 1; end if;
        if used < DEPTH - 1 then
          tx_ce_r <= '1';
        else
          tx_ce_r <= '0';
        end if;
      end if;
    end if;
  end process;

  tx_ce    <= tx_ce_r;
  txf_wdat <= tx_sfd & tx_en & tx_nib;

  u_txf : entity work.eth_async_fifo
    generic map (WIDTH => 6, LOG2_DEPTH => G_LOG2_DEPTH)
    port map (wclk => clk, wrst => wrst_c, wen => tx_ce_d, wdata => txf_wdat,
              wfull => txf_full, wlevel => txf_level,
              rclk => mii_tx_clk, rrst => rst_tx, ren => txf_ren, rdata => txf_head,
              rempty => txf_empty);

  -- synthesis-time sanity in simulation: the ce throttle must never overrun
  p_chk : process(clk)
  begin
    if rising_edge(clk) then
      if wrst_c = '0' then
        assert not (tx_ce_d = '1' and txf_full = '1')
          report "eth_mii_cdc: TX nibble pushed into a full FIFO" severity failure;
      end if;
    end if;
  end process;

  txf_ren <= not txf_empty;

  p_tx_pads : process(mii_tx_clk)
  begin
    if rising_edge(mii_tx_clk) then
      unf_p   <= '0';
      if rst_tx = '1' then
        txd_o <= (others => '0'); txen_o <= '0';
      elsif txf_empty = '0' then
        txd_o  <= txf_head(3 downto 0);
        txen_o <= txf_head(4);
      else
        if txen_o = '1' then unf_p <= '1'; end if;   -- starved mid-frame
        txd_o  <= (others => '0');
        txen_o <= '0';
      end if;
    end if;
  end process;

  -- the edge that loads an SFD-tagged nibble into the pad register is the
  -- wire instant of the SFD; the pulse synchronizer toggles on that same edge
  sfd_launch <= '1' when txf_empty = '0' and txf_head(5) = '1' else '0';

  mii_txd   <= txd_o;
  mii_tx_en <= txen_o;

  u_sfd : entity work.eth_pulse_sync
    port map (src_clk => mii_tx_clk, src_rst => rst_tx, src_pulse => sfd_launch,
              dst_clk => clk, dst_rst => rst, dst_pulse => tx_sfd_wire);

  u_unf : entity work.eth_pulse_sync
    port map (src_clk => mii_tx_clk, src_rst => rst_tx, src_pulse => unf_p,
              dst_clk => clk, dst_rst => rst, dst_pulse => tx_unf);
end architecture rtl;
