-- tsn_top.vhd - Switch SDN-TSN 4x4 completo
-- 4x eth_rx_mii + 4x tsn_ingress + tsn_xbar + 4x tsn_tx_adapt + 4x eth_tx_mii
-- + tsn_regs. Todos los puertos en promisc (un switch reenvia todo; la
-- clasificacion la hace el xbar por la tabla MMIO).
--
-- LOOP_INT: cuando loop_int='1', cada txd(o)/tx_en(o) se realimenta al
-- rxd(o)/rx_dv(o) del MISMO indice (validacion en silicio sin PHY). Con
-- loop_int='0' se exponen los pines MII externos.
--
-- Audit 2026-11:
--   * rx_src="00" (external PHY) is now a REAL MII: per port, mii_rx_clk(i)
--     / mii_tx_clk(i) from the PHY and an eth_mii_cdc (Gray async FIFOs,
--     2-FF synchronizers, reset synchronizers) between the PHY clocks and the
--     core. v1 sampled the pins with the internal 25 MHz enable (no CDC).
--     In rx_src="01"/"10" the engines keep the internal mii_ce (unchanged).
--     Change rx_src only while the ports are idle.
--   * PTP timestamp hooks: rx_sfd(i) / tx_sfd(i) are 1-cycle core-domain
--     pulses at the RX SFD (after the RX FIFO) / TX wire SFD of each port
--     (+/-1 core clock, fixed latency) -- the hook needed for 802.1AS and
--     for Qbv gate timing (phase 2).
--   * RX max length 1522 (802.1Q tagged); longer frames are dropped by the
--     RX engine (counted in DROP_FCS and flagged in ERR_STICKY).
--
-- Bus dmem del SoC: sel/we/addr(8:0)/wdata/rdata (rdata COMBINACIONAL).
-- STATUS: [3:0] descriptor pending per input, [7:4] egress engine busy per
-- output (level, IPG included), [11:8] ingress byte read this cycle (pulse).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tsn_pkg.all;

entity tsn_top is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    mii_ce    : in  std_logic;                       -- tasa de nibble (25 MHz)
    -- bus dmem (MMIO en 0x6000_0000 del core)
    sel       : in  std_logic;
    we        : in  std_logic;
    addr      : in  std_logic_vector(8 downto 0);
    wdata     : in  std_logic_vector(31 downto 0);
    rdata     : out std_logic_vector(31 downto 0);
    irq       : out std_logic;
    -- MII externo (4 puertos) - usados cuando rx_src selecciona pin
    -- rx_src: "00" pin externo, "01" loop_int (TX propio), "10" inyector
    rx_src    : in  std_logic_vector(1 downto 0);
    mii_txd   : out byte_arr4;                        -- solo [3:0] util
    mii_tx_en : out std_logic_vector(3 downto 0);
    mii_rxd   : in  byte_arr4;                        -- solo [3:0] util
    mii_rx_dv : in  std_logic_vector(3 downto 0);
    mii_rx_clk : in std_logic_vector(3 downto 0) := (others => '0');  -- PHY RX_CLK
    mii_tx_clk : in std_logic_vector(3 downto 0) := (others => '0');  -- PHY TX_CLK
    -- PTP timestamp hooks (core-domain pulses)
    rx_sfd    : out std_logic_vector(3 downto 0);
    tx_sfd    : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of tsn_top is
  -- RX -> ingress
  signal rxd  : byte_arr4;
  signal rxdv : std_logic_vector(3 downto 0);
  signal r_data : byte_arr4;
  signal r_valid, r_last, r_crc, r_runt : std_logic_vector(3 downto 0);
  signal r_ovs, r_fcsdrop : std_logic_vector(3 downto 0);
  -- per-port clock-enables and CDC
  signal ext : std_logic;
  signal rx_ce_p, tx_ce_p : std_logic_vector(3 downto 0);
  signal x_rx_ce, x_rx_dv, x_tx_ce, x_sfd_w, x_ovf, x_unf : std_logic_vector(3 downto 0);
  signal x_rx_nib : byte_arr4 := (others => (others => '0'));
  signal x_txd : byte_arr4 := (others => (others => '0'));
  signal x_txen : std_logic_vector(3 downto 0);
  signal eng_sfd, rxe_sfd, cdc_txen, cdc_sfd : std_logic_vector(3 downto 0);
  signal err_set : std_logic_vector(8 downto 0);
  signal inj_err : std_logic;

  -- ingress -> xbar
  signal dv, dtag, dpop, ird_en, ird_valid, ircm, irrw
    : std_logic_vector(3 downto 0);
  signal dmac : mac_arr4;
  signal dlen : len_arr4;
  signal ird_data : byte_arr4;
  signal c_rx, c_ovf, c_fcs, c_tag : std_logic_vector(3 downto 0);

  -- xbar -> adapt
  signal xtx_data : byte_arr4;
  signal xtx_valid, xtx_last, xtx_ready : std_logic_vector(3 downto 0);
  signal x_cnt_tx : std_logic_vector(3 downto 0);

  -- adapt -> tx_mii
  signal atx_data : byte_arr4;
  signal atx_valid, atx_last, atx_ready, atx_busy : std_logic_vector(3 downto 0);

  -- tx_mii salida
  signal txd_i  : byte_arr4;
  signal txen_i : std_logic_vector(3 downto 0);

  -- regs
  signal enable : std_logic;
  signal tbl_wr, tbl_vld : std_logic;
  signal tbl_idx : std_logic_vector(3 downto 0);
  signal tbl_mac : std_logic_vector(47 downto 0);
  signal tbl_port : std_logic_vector(1 downto 0);
  signal status_in : std_logic_vector(11 downto 0);
  signal dbg_in : std_logic_vector(31 downto 0);

  -- observabilidad para STATUS
  signal st_fifo, st_obusy, st_drain : std_logic_vector(3 downto 0);

  -- inyector
  signal inj_push, inj_clr, inj_go, inj_busy : std_logic;
  signal inj_word : std_logic_vector(31 downto 0);
  signal inj_len : unsigned(11 downto 0);
  signal inj_psel : std_logic_vector(1 downto 0);
  signal inj_port : std_logic_vector(1 downto 0);
  signal inj_rxd : std_logic_vector(3 downto 0);
  signal inj_rx_dv : std_logic;
begin
  ext <= '1' when rx_src = "00" else '0';

  -- external PHY interface per port (always present; idle unless rx_src=00)
  g_cdc : for i in 0 to 3 generate
    cdc_i : entity work.eth_mii_cdc
      port map (clk => clk, rst => rst,
        rx_ce => x_rx_ce(i), rx_nib => x_rx_nib(i)(3 downto 0), rx_dv => x_rx_dv(i),
        tx_ce => x_tx_ce(i), tx_nib => txd_i(i)(3 downto 0), tx_en => cdc_txen(i),
        tx_sfd => cdc_sfd(i), tx_sfd_wire => x_sfd_w(i),
        rx_ovf => x_ovf(i), tx_unf => x_unf(i),
        mii_rx_clk => mii_rx_clk(i), mii_rxd => mii_rxd(i)(3 downto 0),
        mii_rx_dv => mii_rx_dv(i),
        mii_tx_clk => mii_tx_clk(i), mii_txd => x_txd(i)(3 downto 0),
        mii_tx_en => x_txen(i));
    cdc_txen(i) <= txen_i(i) and ext;
    cdc_sfd(i)  <= eng_sfd(i) and ext;
    rx_ce_p(i)  <= x_rx_ce(i) when ext = '1' else mii_ce;
    tx_ce_p(i)  <= x_tx_ce(i) when ext = '1' else mii_ce;
    tx_sfd(i)   <= x_sfd_w(i) when ext = '1' else eng_sfd(i);
    rx_sfd(i)   <= rxe_sfd(i);
  end generate;

  -- mux de entrada RX de 3 vias por puerto:
  --   rx_src="00" pin externo (via CDC) | "01" loop_int (TX propio) | "10" inyector
  -- el inyector solo conduce el puerto inj_port; los demas quedan en reposo.
  g_loop : for i in 0 to 3 generate
    process(all)
    begin
      case rx_src is
        when "01" =>                      -- loop_int
          rxd(i)  <= txd_i(i);
          rxdv(i) <= txen_i(i);
        when "10" =>                      -- inyector (solo el puerto elegido)
          if inj_port = std_logic_vector(to_unsigned(i, 2)) then
            rxd(i)  <= "0000" & inj_rxd;
            rxdv(i) <= inj_rx_dv;
          else
            rxd(i)  <= (others => '0');
            rxdv(i) <= '0';
          end if;
        when others =>                    -- pin externo (RX_CLK domain -> CDC)
          rxd(i)  <= x_rx_nib(i);
          rxdv(i) <= x_rx_dv(i);
      end case;
    end process;
    -- pads: TX_CLK registers in external mode; engine lines otherwise (v1)
    mii_txd(i)   <= x_txd(i) when ext = '1' else txd_i(i);
    mii_tx_en(i) <= x_txen(i) when ext = '1' else txen_i(i);
  end generate;

  -- RX MII x4 (promisc: el switch reenvia todo)
  g_rx : for i in 0 to 3 generate
    rx_i : entity work.eth_rx_mii
      generic map (G_MAXLEN => 1522)            -- 802.1Q tagged max frame
      port map (clk => clk, rst => rst, mii_ce => rx_ce_p(i),
        macaddr => x"000000000000", promisc => '1',
        rxd => rxd(i)(3 downto 0), rx_dv => rxdv(i),
        rx_data => r_data(i), rx_valid => r_valid(i), rx_last => r_last(i),
        ev_ok => open, ev_crc => r_crc(i), ev_runt => r_runt(i), ev_drop => open,
        ev_oversize => r_ovs(i), rx_sfd_pulse => rxe_sfd(i),
        dbg_dst => open, dbg_nb => open);
    -- the ingress 'drop by RX validity' counter also counts oversize frames
    r_fcsdrop(i) <= r_runt(i) or r_ovs(i);
  end generate;

  -- ingress x4
  g_ing : for i in 0 to 3 generate
    ing_i : entity work.tsn_ingress
      generic map (LOG2_DEPTH => 11)
      port map (clk => clk, rst => rst,
        rx_data => r_data(i), rx_valid => r_valid(i), rx_last => r_last(i),
        ev_crc => r_crc(i), ev_runt => r_fcsdrop(i),
        rd_en => ird_en(i), rd_data => ird_data(i), rd_valid => ird_valid(i),
        rd_commit => ircm(i), rd_rewind => irrw(i),
        desc_valid => dv(i), desc_mac => dmac(i), desc_len => dlen(i),
        desc_tagged => dtag(i), desc_pop => dpop(i),
        cnt_rx => c_rx(i), cnt_drop_ovf => c_ovf(i),
        cnt_drop_fcs => c_fcs(i), cnt_tagged => c_tag(i));
  end generate;

  -- crossbar
  xbar_i : entity work.tsn_xbar
    port map (clk => clk, rst => rst,
      desc_valid => dv, desc_mac => dmac, desc_len => dlen, desc_pop => dpop,
      rd_en => ird_en, rd_data => ird_data, rd_valid => ird_valid,
      rd_commit => ircm, rd_rewind => irrw,
      tx_data => xtx_data, tx_valid => xtx_valid, tx_last => xtx_last,
      tx_ready => xtx_ready,
      tbl_wr => tbl_wr, tbl_idx => tbl_idx, tbl_mac => tbl_mac,
      tbl_port => tbl_port, tbl_vld => tbl_vld,
      cnt_tx => x_cnt_tx);

  -- adaptadores + TX MII x4
  g_tx : for i in 0 to 3 generate
    adapt_i : entity work.tsn_tx_adapt
      port map (clk => clk, rst => rst,
        xbar_data => xtx_data(i), xbar_valid => xtx_valid(i),
        xbar_last => xtx_last(i), xbar_ready => xtx_ready(i),
        mii_data => atx_data(i), mii_valid => atx_valid(i),
        mii_last => atx_last(i), mii_ready => atx_ready(i),
        mii_busy => atx_busy(i));
    tx_i : entity work.eth_tx_mii
      port map (clk => clk, rst => rst, mii_ce => tx_ce_p(i),
        tx_data => atx_data(i), tx_valid => atx_valid(i), tx_last => atx_last(i),
        tx_ready => atx_ready(i), tx_busy => atx_busy(i), underrun => open,
        txd => txd_i(i)(3 downto 0), tx_en => txen_i(i), tx_sfd_pulse => eng_sfd(i));
    txd_i(i)(7 downto 4) <= "0000";
  end generate;

  -- inyector MII
  inj_i : entity work.tsn_inject
    generic map (LOG2_DEPTH => 11)
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      wr_push => inj_push, wr_word => inj_word, clr_buf => inj_clr,
      len_bytes => inj_len, go => inj_go, port_sel => inj_psel,
      busy => inj_busy, err => inj_err,
      inj_port => inj_port, inj_rxd => inj_rxd, inj_rx_dv => inj_rx_dv);

  -- STATUS: descriptor pendiente (nivel), salida ocupada (nivel), byte de
  -- entrada leido este ciclo (pulso). v1 put the 1-cycle cnt_tx pulse in
  -- [7:4], contradicting the documented "salida ocupada" level.
  st_fifo  <= dv;
  st_obusy <= atx_busy;                 -- egress engine busy (IPG included)
  st_drain <= ird_en;                   -- alguna entrada esta siendo leida
  status_in <= st_drain & st_obusy & st_fifo;
  dbg_in    <= x"000000" & "00" & inj_busy & enable & st_drain(0)
               & st_obusy(0) & st_fifo(0) & rx_src(0);

  -- banco de registros
  regs_i : entity work.tsn_regs
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
      wdata => wdata, rdata => rdata, irq => irq, enable => enable,
      tbl_wr => tbl_wr, tbl_idx => tbl_idx, tbl_mac => tbl_mac,
      tbl_port => tbl_port, tbl_vld => tbl_vld,
      inj_push => inj_push, inj_word => inj_word, inj_clr => inj_clr,
      inj_len => inj_len, inj_go => inj_go, inj_psel => inj_psel,
      inj_busy => inj_busy,
      p_rx => c_rx, p_tx => x_cnt_tx, p_ovf => c_ovf, p_fcs => c_fcs,
      p_tag => c_tag, status_in => status_in, dbg_in => dbg_in,
      err_set => err_set);
  -- ERR_STICKY sources: [3:0] RX oversize, [7:4] CDC FIFO ovf/unf (ext PHY),
  -- [8] injector request refused
  err_set <= inj_err & ((x_ovf or x_unf) and (3 downto 0 => ext)) & r_ovs;
end architecture;
