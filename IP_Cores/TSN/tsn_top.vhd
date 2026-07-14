-- tsn_top.vhd - Switch SDN-TSN 4x4 completo
-- 4x eth_rx_mii + 4x tsn_ingress + tsn_xbar + 4x tsn_tx_adapt + 4x eth_tx_mii
-- + tsn_regs. Todos los puertos en promisc (un switch reenvia todo; la
-- clasificacion la hace el xbar por la tabla MMIO).
--
-- LOOP_INT: cuando loop_int='1', cada txd(o)/tx_en(o) se realimenta al
-- rxd(o)/rx_dv(o) del MISMO indice (validacion en silicio sin PHY). Con
-- loop_int='0' se exponen los pines MII externos.
--
-- Bus dmem del SoC: sel/we/addr(8:0)/wdata/rdata (rdata COMBINACIONAL).
-- STATUS se compone aqui de la observabilidad del xbar.

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
    mii_rx_dv : in  std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of tsn_top is
  -- RX -> ingress
  signal rxd  : byte_arr4;
  signal rxdv : std_logic_vector(3 downto 0);
  signal r_data : byte_arr4;
  signal r_valid, r_last, r_crc, r_runt : std_logic_vector(3 downto 0);

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
  -- mux de entrada RX de 3 vias por puerto:
  --   rx_src="00" pin externo | "01" loop_int (TX propio) | "10" inyector
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
        when others =>                    -- pin externo
          rxd(i)  <= mii_rxd(i);
          rxdv(i) <= mii_rx_dv(i);
      end case;
    end process;
    mii_txd(i)   <= txd_i(i);
    mii_tx_en(i) <= txen_i(i);
  end generate;

  -- RX MII x4 (promisc: el switch reenvia todo)
  g_rx : for i in 0 to 3 generate
    rx_i : entity work.eth_rx_mii
      port map (clk => clk, rst => rst, mii_ce => mii_ce,
        macaddr => x"000000000000", promisc => '1',
        rxd => rxd(i)(3 downto 0), rx_dv => rxdv(i),
        rx_data => r_data(i), rx_valid => r_valid(i), rx_last => r_last(i),
        ev_ok => open, ev_crc => r_crc(i), ev_runt => r_runt(i), ev_drop => open);
  end generate;

  -- ingress x4
  g_ing : for i in 0 to 3 generate
    ing_i : entity work.tsn_ingress
      generic map (LOG2_DEPTH => 11)
      port map (clk => clk, rst => rst,
        rx_data => r_data(i), rx_valid => r_valid(i), rx_last => r_last(i),
        ev_crc => r_crc(i), ev_runt => r_runt(i),
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
      port map (clk => clk, rst => rst, mii_ce => mii_ce,
        tx_data => atx_data(i), tx_valid => atx_valid(i), tx_last => atx_last(i),
        tx_ready => atx_ready(i), tx_busy => atx_busy(i), underrun => open,
        txd => txd_i(i)(3 downto 0), tx_en => txen_i(i));
    txd_i(i)(7 downto 4) <= "0000";
  end generate;

  -- inyector MII
  inj_i : entity work.tsn_inject
    generic map (LOG2_DEPTH => 11)
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      wr_push => inj_push, wr_word => inj_word, clr_buf => inj_clr,
      len_bytes => inj_len, go => inj_go, port_sel => inj_psel,
      busy => inj_busy,
      inj_port => inj_port, inj_rxd => inj_rxd, inj_rx_dv => inj_rx_dv);

  -- STATUS: fifo no-vacia (hay descriptor), salida ocupada, entrada drenando
  st_fifo  <= dv;
  st_obusy <= x_cnt_tx;                 -- proxy de actividad (pulso por trama)
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
      p_tag => c_tag, status_in => status_in, dbg_in => dbg_in);
end architecture;
