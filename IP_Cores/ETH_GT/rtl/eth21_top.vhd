-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT (MAC 10G/25G sobre un canal GTYP real)
-- Top del core: banco AXI4-Lite (s_axi_aclk, reloj libre), secuencia de
-- reset del GT, medidores de reloj, camino TX (tx_clk) y RX (rx_clk).
--
-- Mapa de registros (offset de byte, ver doc/register_map.md):
--   0x00 ID        RO  0x47544521 ("GTE" + core 0x21)
--   0x04 SCRATCH   RW
--   0x08 CTRL      RW  b0 MAC_EN b1 GT_LOOPBACK (near-end PMA) b2 PROMISC
--                      b3 GEN_CONT b4 TX_BITREV b5 TX_HDRSWAP b6 RX_BITREV
--                      b7 RX_HDRSWAP b8 TX_POLARITY b9 RX_POLARITY
--   0x0C CMD       W   b0 SOFT_RESET b1 CNT_CLEAR b2 GEN_START b3 GEN_STOP
--                      b4 INJ (CRC) b5 GT_RESET
--   0x10 STATUS    RO  b0 BLOCK_LOCK b1 GEN_BUSY b2 GEN_DONE b3 RX_ACTIVE
--                      b4 TX_ACTIVE b5 LINK_UP b8 SNAP_DONE b9 CMD_BUSY
--                      b10 CMD_TIMEOUT b11 SNAP_TX b12 SNAP_RX
--                      b16 GT_POWERGOOD b17 LCPLL_LOCK b18 TX_RESETDONE
--                      b19 RX_RESETDONE b20 RX_CDRLOCK b21 TX_READY
--                      b22 RX_READY b23 TX_CLK_ALIVE b28 RX_CLK_ALIVE
--                      b25:24 FSM comun (0 PG 1 PLLRST 2 PLLWT 3 RUN)
--                      b26 pista TX en OK b27 pista RX en OK
--   0x14 GT_CTRL   RW  b0 MANUAL b1 LCPLLRESET b2 TXMSTRESET b3 RXMSTRESET
--                      b4 TXUSERRDY b5 RXUSERRDY (solo con MANUAL = 1)
--   0x18 GEN_GAP   RW  [15:0] ciclos extra entre tramas
--   0x1C SNAP      W   congela los 23 contadores (SNAP_DONE al acabar)
--   0x20/0x24 OWN_MAC_LO/HI  0x28/0x2C PEER_MAC_LO/HI
--   0x30 OWN_IP    0x34 PEER_IP    0x38 PORTS [31:16] origen [15:0] destino
--   0x3C LEN_CFG   [10:0] L min [26:16] L max (payload UDP, 18..1472)
--   0x40 LEN_STEP  0x44 GEN_COUNT
--   0x48 TXCLK_MEAS / 0x4C RXCLK_MEAS  (f = valor * 1280 Hz)
--   0x80..0xD8     contadores 0..22 (instantanea)
--
-- Cruces de reloj (como el Core 20, ahora con DOS dominios rapidos):
--   * CMD: registro AXI estable + un toggle a cada dominio; cada dominio
--     captura su configuracion y ejecuta; CMD_BUSY hasta que AMBOS confirman
--     (timeout de 256 aclk -> CMD_TIMEOUT; el bus nunca se bloquea).
--   * SNAP: toggle a ambos dominios; cada uno copia sus contadores a su
--     sombra y confirma.
--   * Estado: doble FF por bit. Configuracion multibit: estable (max_delay
--     -datapath_only en el XDC).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth21_top is
  generic (
    ACLK_HZ   : natural := 100_000_000;
    SLIP_WAIT : natural := 64
  );
  port (
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    s_axi_awaddr  : in  std_logic_vector(7 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(7 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    -- relojes de usuario del GT (BUFG_GT de TX/RXPROGDIVCLK)
    tx_clk        : in  std_logic;
    rx_clk        : in  std_logic;

    -- canal 0 del gt_quad_base
    gt_txdata          : out std_logic_vector(127 downto 0);
    gt_txheader        : out std_logic_vector(5 downto 0);
    gt_txsequence      : out std_logic_vector(6 downto 0);
    gt_txmstreset      : out std_logic;
    gt_txuserrdy       : out std_logic;
    gt_txpolarity      : out std_logic;
    gt_txmstresetdone  : in  std_logic;
    gt_rxdata          : in  std_logic_vector(127 downto 0);
    gt_rxdatavalid     : in  std_logic_vector(1 downto 0);
    gt_rxheader        : in  std_logic_vector(5 downto 0);
    gt_rxheadervalid   : in  std_logic_vector(1 downto 0);
    gt_rxgearboxslip   : out std_logic;
    gt_rxmstreset      : out std_logic;
    gt_rxuserrdy       : out std_logic;
    gt_rxpolarity      : out std_logic;
    gt_rxmstresetdone  : in  std_logic;
    gt_rxcdrlock       : in  std_logic;
    gt_powergood       : in  std_logic;
    gt_lcplllock       : in  std_logic;
    gt_lcpllreset      : out std_logic;
    gt_loopback        : out std_logic_vector(2 downto 0)
  );
end entity eth21_top;

architecture rtl of eth21_top is
  constant ID_MAGIC : std_logic_vector(31 downto 0) := x"47544521";
  constant NCNT     : natural := 23;

  signal rst_axi : std_logic;

  -- ---- AXI ----
  signal awready_i, wready_i, bvalid_i, arready_i, rvalid_i : std_logic := '0';
  signal rdata_i    : std_logic_vector(31 downto 0) := (others => '0');
  signal r_scratch  : std_logic_vector(31 downto 0) := (others => '0');
  signal r_ctrl     : std_logic_vector(9 downto 0) := (others => '0');
  signal r_cmd      : std_logic_vector(4 downto 0) := (others => '0');
  signal r_gtctrl   : std_logic_vector(5 downto 0) := (others => '0');
  signal r_gap      : std_logic_vector(15 downto 0) := (others => '0');
  signal r_own_lo, r_peer_lo, r_own_ip, r_peer_ip, r_ports, r_count : std_logic_vector(31 downto 0) := (others => '0');
  signal r_own_hi, r_peer_hi : std_logic_vector(15 downto 0) := (others => '0');
  signal r_lmin, r_lmax, r_lstep : std_logic_vector(10 downto 0) := (others => '0');
  signal p_cmd, p_snap, p_gtrst : std_logic := '0';
  signal snap_tx, snap_rx : std_logic := '0';
  signal cmd_busy, ack_tx, ack_rx : std_logic := '0';
  signal cmd_tmo    : unsigned(7 downto 0) := (others => '0');
  signal cmd_err    : std_logic := '0';
  signal a_lock, a_busy, a_done, a_rx, a_tx, a_link, a_cdr : std_logic;
  signal a_cmd_ack_tx, a_cmd_ack_rx, a_snap_ack_tx, a_snap_ack_rx : std_logic;
  signal txclk_meas, rxclk_meas : std_logic_vector(31 downto 0);
  signal tx_alive, rx_alive : std_logic;

  -- ---- GT reset ----
  signal tx_ready, rx_ready : std_logic;
  signal fsm_st : std_logic_vector(3 downto 0);
  signal s_pg, s_lock, s_txd, s_rxd : std_logic;

  -- ---- dominio TX ----
  signal t_rst_s : std_logic_vector(2 downto 0) := (others => '1');
  signal t_rst, t_prst : std_logic := '1';
  signal t_cmd_stb, t_snap_stb : std_logic;
  signal t_cmd_r, t_go, t_ack1, t_ack2, t_snap_r, t_snap_ack : std_logic := '0';
  signal t_ctrl   : std_logic_vector(9 downto 0) := (others => '0');
  signal t_cmd    : std_logic_vector(4 downto 0) := (others => '0');
  signal t_own, t_peer : std_logic_vector(47 downto 0) := (others => '0');
  signal t_oip, t_pip, t_ports : std_logic_vector(31 downto 0) := (others => '0');
  signal t_lmin, t_lmax, t_lstep : unsigned(10 downto 0) := (others => '0');
  signal t_count  : unsigned(31 downto 0) := (others => '0');
  signal t_gap    : unsigned(15 downto 0) := (others => '0');
  signal t_soft, t_clr, t_start, t_stop, t_inj : std_logic := '0';
  signal t_busy, t_done, t_act : std_logic;
  signal t_cnt, t_shadow : std_logic_vector(4*32-1 downto 0) := (others => '0');
  signal t_txd    : std_logic_vector(63 downto 0);
  signal t_txh    : std_logic_vector(1 downto 0);

  -- ---- dominio RX ----
  signal r_rst_s : std_logic_vector(2 downto 0) := (others => '1');
  signal r_rst, r_prst : std_logic := '1';
  signal r_cmd_stb, r_snap_stb : std_logic;
  signal r_cmd_r, r_go, r_ack1, r_ack2, r_snap_r, r_snap_ack : std_logic := '0';
  signal x_ctrl   : std_logic_vector(9 downto 0) := (others => '0');
  signal x_cmd    : std_logic_vector(4 downto 0) := (others => '0');
  signal x_own, x_peer : std_logic_vector(47 downto 0) := (others => '0');
  signal x_oip, x_pip, x_ports : std_logic_vector(31 downto 0) := (others => '0');
  signal x_soft, x_clr, x_restart : std_logic := '0';
  signal x_lock, x_link, x_act, x_evcrc, x_evchk : std_logic;
  signal x_cnt, x_shadow : std_logic_vector(19*32-1 downto 0) := (others => '0');
  signal x_valid  : std_logic;

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of t_rst_s, r_rst_s : signal is "TRUE";
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of t_shadow, x_shadow : signal is "TRUE";
  attribute MAX_FANOUT : integer;
  attribute MAX_FANOUT of t_prst, r_prst : signal is 64;
  attribute MAX_FANOUT of t_cmd_r, r_cmd_r, t_snap_r, r_snap_r : signal is 32;

  -- contador global i (0..22) desde las sombras de TX y RX
  function cnt_sel(i : natural; t : std_logic_vector; x : std_logic_vector)
    return std_logic_vector is
  begin
    case i is
      when 0  => return t(31 downto 0);
      when 1  => return t(63 downto 32);
      when 14 => return t(95 downto 64);
      when 15 => return t(127 downto 96);
      when 2 to 13 => return x(32*(i-2)+31 downto 32*(i-2));
      when 16 to 22 => return x(32*(i-4)+31 downto 32*(i-4));
      when others => return x"00000000";
    end case;
  end function;
begin
  rst_axi <= not s_axi_aresetn;

  -----------------------------------------------------------------------------
  -- AXI4-Lite
  -----------------------------------------------------------------------------
  process(s_axi_aclk)
    variable a : std_logic_vector(7 downto 0);
  begin
    if rising_edge(s_axi_aclk) then
      p_cmd <= '0'; p_snap <= '0'; p_gtrst <= '0';
      awready_i <= '0'; wready_i <= '0';
      if s_axi_aresetn = '0' then
        bvalid_i <= '0';
        r_scratch <= (others => '0'); r_ctrl <= (others => '0');
        r_cmd <= (others => '0'); r_gtctrl <= (others => '0');
        r_gap <= (others => '0');
        r_own_lo  <= x"45474E02"; r_own_hi  <= x"204E";   -- 02:4E:47:45:4E:20
        r_peer_lo <= x"FFFFFFFF"; r_peer_hi <= x"FFFF";   -- broadcast
        r_own_ip  <= x"C0A81502";                         -- 192.168.21.2
        r_peer_ip <= x"C0A81501";                         -- 192.168.21.1
        r_ports   <= x"52105211";                         -- 21008 -> 21009
        r_lmin <= std_logic_vector(to_unsigned(1472, 11));
        r_lmax <= std_logic_vector(to_unsigned(1472, 11));
        r_lstep <= (others => '0');
        r_count <= std_logic_vector(to_unsigned(1000, 32));
        snap_tx <= '0'; snap_rx <= '0';
        cmd_busy <= '0'; ack_tx <= '0'; ack_rx <= '0';
        cmd_tmo <= (others => '0'); cmd_err <= '0';
      else
        if a_snap_ack_tx = '1' then snap_tx <= '1'; end if;
        if a_snap_ack_rx = '1' then snap_rx <= '1'; end if;
        if a_cmd_ack_tx = '1' then ack_tx <= '1'; end if;
        if a_cmd_ack_rx = '1' then ack_rx <= '1'; end if;
        if cmd_busy = '1' then
          if (ack_tx = '1' or a_cmd_ack_tx = '1') and (ack_rx = '1' or a_cmd_ack_rx = '1') then
            cmd_busy <= '0'; cmd_err <= '0';
          elsif cmd_tmo = 255 then
            cmd_busy <= '0'; cmd_err <= '1';
          else
            cmd_tmo <= cmd_tmo + 1;
          end if;
        end if;
        if awready_i = '1' then bvalid_i <= '1'; end if;

        if s_axi_awvalid = '1' and s_axi_wvalid = '1' and bvalid_i = '0' and
           awready_i = '0' and cmd_busy = '0' then
          awready_i <= '1'; wready_i <= '1';
          a := s_axi_awaddr;
          case a(7 downto 2) is
            when "000001" => r_scratch <= s_axi_wdata;
            when "000010" => r_ctrl <= s_axi_wdata(9 downto 0);
            when "000011" =>
              r_cmd <= s_axi_wdata(4 downto 0);
              if s_axi_wdata(5) = '1' then p_gtrst <= '1'; end if;
              if s_axi_wdata(4 downto 0) /= "00000" then
                p_cmd <= '1'; cmd_busy <= '1'; cmd_tmo <= (others => '0');
                ack_tx <= '0'; ack_rx <= '0';
              end if;
            when "000101" => r_gtctrl <= s_axi_wdata(5 downto 0);
            when "000110" => r_gap <= s_axi_wdata(15 downto 0);
            when "000111" => p_snap <= '1'; snap_tx <= '0'; snap_rx <= '0';
            when "001000" => r_own_lo <= s_axi_wdata;
            when "001001" => r_own_hi <= s_axi_wdata(15 downto 0);
            when "001010" => r_peer_lo <= s_axi_wdata;
            when "001011" => r_peer_hi <= s_axi_wdata(15 downto 0);
            when "001100" => r_own_ip <= s_axi_wdata;
            when "001101" => r_peer_ip <= s_axi_wdata;
            when "001110" => r_ports <= s_axi_wdata;
            when "001111" =>
              r_lmin <= s_axi_wdata(10 downto 0); r_lmax <= s_axi_wdata(26 downto 16);
            when "010000" => r_lstep <= s_axi_wdata(10 downto 0);
            when "010001" => r_count <= s_axi_wdata;
            when others => null;
          end case;
        elsif bvalid_i = '1' and s_axi_bready = '1' then
          bvalid_i <= '0';
        end if;
      end if;
    end if;
  end process;

  process(s_axi_aclk)
    variable a : std_logic_vector(7 downto 0);
  begin
    if rising_edge(s_axi_aclk) then
      arready_i <= '0';
      if s_axi_aresetn = '0' then
        rvalid_i <= '0'; rdata_i <= (others => '0');
      elsif arready_i = '1' then
        rvalid_i <= '1';
      elsif s_axi_arvalid = '1' and rvalid_i = '0' then
        arready_i <= '1';
        a := s_axi_araddr;
        if a(7) = '1' then
          rdata_i <= cnt_sel(to_integer(unsigned(a(6 downto 2))), t_shadow, x_shadow);
        else
          case a(7 downto 2) is
            when "000000" => rdata_i <= ID_MAGIC;
            when "000001" => rdata_i <= r_scratch;
            when "000010" => rdata_i <= "0000000000000000000000" & r_ctrl;
            when "000100" =>
              rdata_i <= (0 => a_lock, 1 => a_busy or cmd_busy,
                          2 => a_done and not cmd_busy, 3 => a_rx, 4 => a_tx,
                          5 => a_link,
                          8 => snap_tx and snap_rx, 9 => cmd_busy, 10 => cmd_err,
                          11 => snap_tx, 12 => snap_rx,
                          16 => s_pg, 17 => s_lock, 18 => s_txd, 19 => s_rxd,
                          20 => a_cdr, 21 => tx_ready, 22 => rx_ready,
                          23 => tx_alive,
                          24 => fsm_st(0), 25 => fsm_st(1), 26 => fsm_st(2),
                          27 => fsm_st(3), 28 => rx_alive, others => '0');
            when "000101" => rdata_i <= "00000000000000000000000000" & r_gtctrl;
            when "000110" => rdata_i <= x"0000" & r_gap;
            when "001000" => rdata_i <= r_own_lo;
            when "001001" => rdata_i <= x"0000" & r_own_hi;
            when "001010" => rdata_i <= r_peer_lo;
            when "001011" => rdata_i <= x"0000" & r_peer_hi;
            when "001100" => rdata_i <= r_own_ip;
            when "001101" => rdata_i <= r_peer_ip;
            when "001110" => rdata_i <= r_ports;
            when "001111" => rdata_i <= "00000" & r_lmax & "00000" & r_lmin;
            when "010000" => rdata_i <= x"00000" & '0' & r_lstep;
            when "010001" => rdata_i <= r_count;
            when "010010" => rdata_i <= txclk_meas;
            when "010011" => rdata_i <= rxclk_meas;
            when others   => rdata_i <= (others => '0');
          end case;
        end if;
      elsif rvalid_i = '1' and s_axi_rready = '1' then
        rvalid_i <= '0';
      end if;
    end if;
  end process;

  s_axi_awready <= awready_i;
  s_axi_wready  <= wready_i;
  s_axi_bresp   <= "00";
  s_axi_bvalid  <= bvalid_i;
  s_axi_arready <= arready_i;
  s_axi_rdata   <= rdata_i;
  s_axi_rresp   <= "00";
  s_axi_rvalid  <= rvalid_i;

  -----------------------------------------------------------------------------
  -- reset del GT y medidores (aclk)
  -----------------------------------------------------------------------------
  u_rst: entity work.eth21_gt_rst
    generic map (ACLK_HZ => ACLK_HZ)
    port map (clk=>s_axi_aclk, rst=>rst_axi, restart=>p_gtrst,
              manual=>r_gtctrl(0), man_pllrst=>r_gtctrl(1), man_txmst=>r_gtctrl(2),
              man_rxmst=>r_gtctrl(3), man_txusr=>r_gtctrl(4), man_rxusr=>r_gtctrl(5),
              gtpowergood=>gt_powergood, lcplllock=>gt_lcplllock,
              txmstdone=>gt_txmstresetdone, rxmstdone=>gt_rxmstresetdone,
              tx_alive=>tx_alive, rx_alive=>rx_alive,
              lcpllreset=>gt_lcpllreset, txmstreset=>gt_txmstreset,
              rxmstreset=>gt_rxmstreset, txuserrdy=>gt_txuserrdy,
              rxuserrdy=>gt_rxuserrdy, tx_ready=>tx_ready, rx_ready=>rx_ready,
              state=>fsm_st, s_pg=>s_pg, s_lock=>s_lock, s_txd=>s_txd, s_rxd=>s_rxd);

  gt_loopback <= "010" when r_ctrl(1) = '1' else "000";   -- near-end PMA

  u_mtx: entity work.eth21_clkmeter generic map (ACLK_HZ => ACLK_HZ)
    port map (clk_m=>tx_clk, aclk=>s_axi_aclk, result=>txclk_meas, alive=>tx_alive);
  u_mrx: entity work.eth21_clkmeter generic map (ACLK_HZ => ACLK_HZ)
    port map (clk_m=>rx_clk, aclk=>s_axi_aclk, result=>rxclk_meas, alive=>rx_alive);

  -----------------------------------------------------------------------------
  -- dominio TX
  -----------------------------------------------------------------------------
  -- reset: asercion asincrona, liberacion sincronizada
  process(tx_clk, tx_ready, s_axi_aresetn)
  begin
    if tx_ready = '0' or s_axi_aresetn = '0' then
      t_rst_s <= (others => '1');
    elsif rising_edge(tx_clk) then
      t_rst_s <= t_rst_s(1 downto 0) & '0';
    end if;
  end process;
  t_rst <= t_rst_s(2);

  u_ps_ct: entity work.mac25g_psync
    port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, pulse_in=>p_cmd,
              clk_dst=>tx_clk, rst_dst=>t_rst, pulse_out=>t_cmd_stb);
  u_ps_st: entity work.mac25g_psync
    port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, pulse_in=>p_snap,
              clk_dst=>tx_clk, rst_dst=>t_rst, pulse_out=>t_snap_stb);

  process(tx_clk)
  begin
    if rising_edge(tx_clk) then
      t_soft <= '0'; t_clr <= '0'; t_start <= '0'; t_stop <= '0'; t_inj <= '0';
      t_snap_ack <= '0';
      t_cmd_r <= t_cmd_stb;
      t_snap_r <= t_snap_stb;
      if t_rst = '1' then
        t_go <= '0'; t_ack1 <= '0'; t_ack2 <= '0';
      else
        t_go <= t_cmd_r;
        t_ack1 <= t_go; t_ack2 <= t_ack1;
        if t_cmd_r = '1' then
          t_ctrl <= r_ctrl; t_cmd <= r_cmd;
          t_own <= r_own_hi & r_own_lo; t_peer <= r_peer_hi & r_peer_lo;
          t_oip <= r_own_ip; t_pip <= r_peer_ip; t_ports <= r_ports;
          t_lmin <= unsigned(r_lmin); t_lmax <= unsigned(r_lmax);
          t_lstep <= unsigned(r_lstep); t_count <= unsigned(r_count);
          t_gap <= unsigned(r_gap);
        end if;
        if t_go = '1' then
          t_soft <= t_cmd(0); t_clr <= t_cmd(1); t_start <= t_cmd(2);
          t_stop <= t_cmd(3); t_inj <= t_cmd(4);
        end if;
      end if;
      if t_snap_r = '1' then
        t_shadow <= t_cnt; t_snap_ack <= '1';
      end if;
      t_prst <= t_rst or t_soft;
    end if;
  end process;

  u_tx: entity work.eth21_txpath
    port map (clk=>tx_clk, rst=>t_prst,
              mac_en=>t_ctrl(0), gen_cont=>t_ctrl(3),
              bit_rev=>t_ctrl(4), hdr_swap=>t_ctrl(5),
              peer_mac=>t_peer, own_mac=>t_own, own_ip=>t_oip, peer_ip=>t_pip,
              sport=>t_ports(31 downto 16), dport=>t_ports(15 downto 0),
              len_min=>t_lmin, len_max=>t_lmax, len_step=>t_lstep,
              gen_count=>t_count, gen_gap=>t_gap,
              gen_start=>t_start, gen_stop=>t_stop, cnt_clear=>t_clr, inj=>t_inj,
              st_busy=>t_busy, st_done=>t_done, st_tx_act=>t_act,
              txdata=>t_txd, txheader=>t_txh, cnt_flat=>t_cnt);

  gt_txdata     <= x"0000000000000000" & t_txd;
  gt_txheader   <= "0000" & t_txh;
  gt_txsequence <= (others => '0');
  gt_txpolarity <= t_ctrl(8);

  -----------------------------------------------------------------------------
  -- dominio RX
  -----------------------------------------------------------------------------
  process(rx_clk, rx_ready, s_axi_aresetn)
  begin
    if rx_ready = '0' or s_axi_aresetn = '0' then
      r_rst_s <= (others => '1');
    elsif rising_edge(rx_clk) then
      r_rst_s <= r_rst_s(1 downto 0) & '0';
    end if;
  end process;
  r_rst <= r_rst_s(2);

  u_ps_cr: entity work.mac25g_psync
    port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, pulse_in=>p_cmd,
              clk_dst=>rx_clk, rst_dst=>r_rst, pulse_out=>r_cmd_stb);
  u_ps_sr: entity work.mac25g_psync
    port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, pulse_in=>p_snap,
              clk_dst=>rx_clk, rst_dst=>r_rst, pulse_out=>r_snap_stb);

  process(rx_clk)
  begin
    if rising_edge(rx_clk) then
      x_soft <= '0'; x_clr <= '0'; x_restart <= '0';
      r_snap_ack <= '0';
      r_cmd_r <= r_cmd_stb;
      r_snap_r <= r_snap_stb;
      if r_rst = '1' then
        r_go <= '0'; r_ack1 <= '0'; r_ack2 <= '0';
      else
        r_go <= r_cmd_r;
        r_ack1 <= r_go; r_ack2 <= r_ack1;
        if r_cmd_r = '1' then
          x_ctrl <= r_ctrl; x_cmd <= r_cmd;
          x_own <= r_own_hi & r_own_lo; x_peer <= r_peer_hi & r_peer_lo;
          x_oip <= r_own_ip; x_pip <= r_peer_ip; x_ports <= r_ports;
        end if;
        if r_go = '1' then
          x_soft <= x_cmd(0); x_clr <= x_cmd(1);
          x_restart <= x_cmd(2) or x_cmd(1);      -- GEN_START / CNT_CLEAR
        end if;
      end if;
      if r_snap_r = '1' then
        x_shadow <= x_cnt; r_snap_ack <= '1';
      end if;
      r_prst <= r_rst or x_soft;
    end if;
  end process;

  x_valid <= gt_rxdatavalid(0) and gt_rxheadervalid(0);

  u_rx: entity work.eth21_rxpath
    generic map (SLIP_WAIT => SLIP_WAIT)
    port map (clk=>rx_clk, rst=>r_prst,
              promisc=>x_ctrl(2), bit_rev=>x_ctrl(6), hdr_swap=>x_ctrl(7),
              own_mac=>x_own, peer_mac=>x_peer, own_ip=>x_oip, peer_ip=>x_pip,
              sport=>x_ports(31 downto 16), dport=>x_ports(15 downto 0),
              chk_restart=>x_restart, cnt_clear=>x_clr,
              rxdata=>gt_rxdata(63 downto 0), rxheader=>gt_rxheader(1 downto 0),
              rxvalid=>x_valid, rxslip=>gt_rxgearboxslip,
              st_lock=>x_lock, st_link=>x_link, st_rx_act=>x_act,
              ev_crc=>x_evcrc, ev_chkerr=>x_evchk, cnt_flat=>x_cnt);

  gt_rxpolarity <= x_ctrl(9);

  -----------------------------------------------------------------------------
  -- cruces hacia AXI
  -----------------------------------------------------------------------------
  u_l0: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>x_lock, q=>a_lock);
  u_l1: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>t_busy, q=>a_busy);
  u_l2: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>t_done, q=>a_done);
  u_l3: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>x_act,  q=>a_rx);
  u_l4: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>t_act,  q=>a_tx);
  u_l5: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>x_link, q=>a_link);
  u_l6: entity work.mac25g_lsync port map (clk_dst=>s_axi_aclk, d=>gt_rxcdrlock, q=>a_cdr);

  u_e0: entity work.mac25g_evsync
    port map (clk_src=>tx_clk, rst_src=>t_rst, ev_in=>t_ack2,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_cmd_ack_tx);
  u_e1: entity work.mac25g_evsync
    port map (clk_src=>rx_clk, rst_src=>r_rst, ev_in=>r_ack2,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_cmd_ack_rx);
  u_e2: entity work.mac25g_evsync
    port map (clk_src=>tx_clk, rst_src=>t_rst, ev_in=>t_snap_ack,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_snap_ack_tx);
  u_e3: entity work.mac25g_evsync
    port map (clk_src=>rx_clk, rst_src=>r_rst, ev_in=>r_snap_ack,
              clk_dst=>s_axi_aclk, rst_dst=>rst_axi, ev_out=>a_snap_ack_rx);

end architecture rtl;
