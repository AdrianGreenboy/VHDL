-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- TOP-LEVEL pcs_stats_top: el modulo que se instancia en el SoC.
--
-- Integra:
--   * pcs_regbank        (dominio AXI): banco de 64 registros AXI4-Lite
--   * pcs_cdc            (cruce):       estado/eventos dp->axi + snapshot
--   * pcs_dataplane      (dominio DP):  maquina block-lock, hi_ber, eventos
--   * pcs_silicon_datapath (dominio DP): PRBS31 -> PCS TX -> loopback ->
--                                        PCS RX -> checker (el silicon pass)
--
-- Sincronizacion axi -> dp (anadida aqui, el pcs_cdc cubre dp -> axi):
--   * NIVELES (doble FF): loopback_en (CTRL.3), prbs_gen_en (PRBS_CTRL.0),
--     prbs_chk_en (PRBS_CTRL.1). Cuasi-estaticos: el software los fija antes
--     de arrancar el test.
--   * PULSOS (toggle-sync): prbs_inj, cmd_prbs_reset, cmd_cnt_clear,
--     cmd_soft_reset, cmd_resync.
--
-- Arquitectura de contadores (decision de integracion):
--   * Los contadores DE REGISTRO (los que lee el firmware via snapshot) vienen
--     del silicon datapath, que es la verdad de tierra: tx_word_cnt,
--     rx_block_cnt, ber_count (bits de error del checker).
--   * Block lock / hi_ber (audit 2026-11, fix A3): the REAL clause-49 block
--     sync lives in the RX datapath (pcs_rx_datapath -> pcs_blocksync, it
--     drives the gearbox bit slip). The dataplane runs with EXT_SYNC = true:
--     it takes lock / hi_ber from there and receives one strobe per valid
--     and per INVALID sync header, so EVT_RXBAD / RX_ERR are now reachable.
--     TX, RX-header and PRBS events arrive on independent strobes (before:
--     a priority mux PRBS_BAD > RX_OK > TX dropped coincident events and
--     never produced RX_BAD).
--   * ST_PRBS_LOCK viene del chk_locked real del checker.
--
-- MIT License.
-------------------------------------------------------------------------------

-- ==== helper: sincronizador de nivel (doble FF) ====
library ieee;
use ieee.std_logic_1164.all;

entity pcs_lsync is
  port (
    clk_dst : in  std_logic;
    d       : in  std_logic;
    q       : out std_logic
  );
end entity pcs_lsync;

architecture rtl of pcs_lsync is
  signal f1, f2 : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of f1, f2 : signal is "TRUE";
begin
  process(clk_dst)
  begin
    if rising_edge(clk_dst) then
      f1 <= d;
      f2 <= f1;
    end if;
  end process;
  q <= f2;
end architecture rtl;


-- ==== helper: sincronizador de pulso (toggle) ====
-- Audit 2026-11 (fix M6): the toggle is reset ONLY by the asynchronous
-- power-on reset of the source domain (por_src); the synchroniser chain has
-- no reset and the output is gated by the destination reset. Before, the
-- toggle was reset by rst_src and the chain by rst_dst: a reset of only one
-- domain created a fake edge, i.e. a spurious SOFT_RESET / CNT_CLEAR /
-- RESYNC / PRBS_RESET / INJ command in the data plane.
library ieee;
use ieee.std_logic_1164.all;

entity pcs_psync is
  port (
    clk_src : in  std_logic;
    rst_src : in  std_logic;
    pulse_in: in  std_logic;   -- pulso 1 ciclo en clk_src
    clk_dst : in  std_logic;
    rst_dst : in  std_logic;
    pulse_out: out std_logic;  -- pulso 1 ciclo en clk_dst
    por_src : in  std_logic := '0'
  );
end entity pcs_psync;

architecture rtl of pcs_psync is
  signal tg : std_logic := '0';
  signal s1, s2, s3 : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of s1, s2 : signal is "TRUE";
begin
  process(clk_src, por_src)
  begin
    if por_src = '1' then
      tg <= '0';
    elsif rising_edge(clk_src) then
      if rst_src = '0' and pulse_in = '1' then tg <= not tg; end if;
    end if;
  end process;
  process(clk_dst)
  begin
    if rising_edge(clk_dst) then
      s1<=tg; s2<=s1; s3<=s2;
    end if;
  end process;
  pulse_out <= (s2 xor s3) and not rst_dst;
end architecture rtl;


-- ==== TOP ====
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_stats_top is
  port (
    -- dominio AXI
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
    irq_out       : out std_logic;

    -- dominio data plane
    clk_dp        : in  std_logic;
    rst_dp        : in  std_logic;

    -- pegamento DMA hacia el SoC (dominio AXI)
    dma_addr      : out std_logic_vector(31 downto 0);
    dma_doorbell  : out std_logic_vector(31 downto 0);
    dma_busy      : in  std_logic;
    dma_done_pulse: in  std_logic;

    -- chip power-on reset, active low, asynchronous (ASIC). '1' (default)
    -- = FPGA behaviour with initial values. See pcs_cdc header for the
    -- release order it guarantees.
    por_n         : in  std_logic := '1'
  );
end entity pcs_stats_top;

architecture rtl of pcs_stats_top is
  signal rst_axi : std_logic;
  signal rst_dp_i, por_axi, por_dp : std_logic;

  -- regbank <-> resto
  signal ctrl_reg      : std_logic_vector(6 downto 0);
  signal prbs_ctrl_reg : std_logic_vector(2 downto 0);
  signal cmd_soft_reset, cmd_resync, cmd_cnt_clear, cmd_prbs_reset : std_logic;
  signal prbs_inj, stats_snap : std_logic;

  -- niveles sincronizados a dp
  signal dp_loopback_en, dp_gen_en, dp_chk_en : std_logic;
  -- pulsos sincronizados a dp
  signal dp_soft_reset, dp_resync, dp_cnt_clear, dp_prbs_reset, dp_inj : std_logic;

  -- silicon datapath
  signal sil_rst : std_logic;
  signal sil_ber, sil_txc, sil_rxc : std_logic_vector(31 downto 0);
  signal sil_lock : std_logic;
  signal sil_rx_lock, sil_rx_hiber, sil_goodsh, sil_badsh : std_logic;

  -- derivacion de eventos para el dataplane
  signal prev_txc, prev_ber : unsigned(31 downto 0) := (others => '0');
  signal tx_inc, ber_inc : std_logic := '0';

  -- dataplane
  signal dpl_cnt_tx, dpl_cnt_rx, dpl_cnt_re, dpl_cnt_be, dpl_lock_t : std_logic_vector(31 downto 0);
  signal dpl_block_lock, dpl_scr_sync, dpl_prbs_lock, dpl_hi_ber : std_logic;
  signal dpl_tx_active, dpl_rx_active : std_logic;
  signal dpl_ev_lg, dpl_ev_ll, dpl_ev_hb, dpl_ev_re, dpl_ev_pe : std_logic;

  -- cdc -> axi
  signal axi_block_lock, axi_scr_sync, axi_prbs_lock, axi_hi_ber : std_logic;
  signal axi_tx_active, axi_rx_active : std_logic;
  signal axi_ev_lg, axi_ev_ll, axi_ev_hb, axi_ev_re, axi_ev_pe : std_logic;
  signal axi_sh_tx, axi_sh_rx, axi_sh_re, axi_sh_be, axi_sh_lt : std_logic_vector(31 downto 0);
  signal axi_snap_done : std_logic;

begin
  -- power-on reset per domain; OR-ed into the functional resets so each
  -- domain leaves reset >= 4 of its own clock edges after power-on
  u_por_axi: entity work.pcs_porsync port map (clk=>s_axi_aclk, por_n=>por_n, por=>por_axi);
  u_por_dp:  entity work.pcs_porsync port map (clk=>clk_dp,     por_n=>por_n, por=>por_dp);
  rst_axi  <= (not s_axi_aresetn) or por_axi;
  rst_dp_i <= rst_dp or por_dp;

  -- ==== banco de registros (dominio AXI) ====
  u_bank: entity work.pcs_regbank
    port map (
      s_axi_aclk=>s_axi_aclk, s_axi_aresetn=>s_axi_aresetn,
      s_axi_awaddr=>s_axi_awaddr, s_axi_awvalid=>s_axi_awvalid, s_axi_awready=>s_axi_awready,
      s_axi_wdata=>s_axi_wdata, s_axi_wstrb=>s_axi_wstrb, s_axi_wvalid=>s_axi_wvalid,
      s_axi_wready=>s_axi_wready, s_axi_bresp=>s_axi_bresp, s_axi_bvalid=>s_axi_bvalid,
      s_axi_bready=>s_axi_bready, s_axi_araddr=>s_axi_araddr, s_axi_arvalid=>s_axi_arvalid,
      s_axi_arready=>s_axi_arready, s_axi_rdata=>s_axi_rdata, s_axi_rresp=>s_axi_rresp,
      s_axi_rvalid=>s_axi_rvalid, s_axi_rready=>s_axi_rready,
      irq_out=>irq_out,
      dp_block_lock=>axi_block_lock, dp_hi_ber=>axi_hi_ber, dp_scr_sync=>axi_scr_sync,
      dp_prbs_lock=>axi_prbs_lock, dp_tx_active=>axi_tx_active, dp_rx_active=>axi_rx_active,
      dp_dma_busy=>dma_busy,
      dp_cnt_tx_blk=>axi_sh_tx, dp_cnt_rx_blk=>axi_sh_rx, dp_cnt_rx_err=>axi_sh_re,
      dp_cnt_ber=>axi_sh_be, dp_lock_time=>axi_sh_lt,
      dp_ev_lock_gained=>axi_ev_lg, dp_ev_lock_lost=>axi_ev_ll, dp_ev_hi_ber=>axi_ev_hb,
      dp_ev_rx_err=>axi_ev_re, dp_ev_prbs_err=>axi_ev_pe, dp_ev_dma_done=>dma_done_pulse,
      ctrl_reg=>ctrl_reg, prbs_ctrl_reg=>prbs_ctrl_reg,
      cmd_soft_reset=>cmd_soft_reset, cmd_resync=>cmd_resync,
      cmd_cnt_clear=>cmd_cnt_clear, cmd_prbs_reset=>cmd_prbs_reset,
      prbs_inj=>prbs_inj, stats_snap=>stats_snap,
      snap_latch_ext=>axi_snap_done,
      dma_addr_reg=>dma_addr, dma_doorbell_reg=>dma_doorbell
    );

  -- ==== sincronizacion axi -> dp ====
  -- niveles (cuasi-estaticos)
  u_ls_loop: entity work.pcs_lsync port map (clk_dst=>clk_dp, d=>ctrl_reg(3),      q=>dp_loopback_en);
  u_ls_gen:  entity work.pcs_lsync port map (clk_dst=>clk_dp, d=>prbs_ctrl_reg(0), q=>dp_gen_en);
  u_ls_chk:  entity work.pcs_lsync port map (clk_dst=>clk_dp, d=>prbs_ctrl_reg(1), q=>dp_chk_en);
  -- pulsos
  u_ps_srst: entity work.pcs_psync port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, por_src=>por_axi, pulse_in=>cmd_soft_reset,
                                             clk_dst=>clk_dp, rst_dst=>rst_dp_i, pulse_out=>dp_soft_reset);
  u_ps_rsyn: entity work.pcs_psync port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, por_src=>por_axi, pulse_in=>cmd_resync,
                                             clk_dst=>clk_dp, rst_dst=>rst_dp_i, pulse_out=>dp_resync);
  u_ps_cclr: entity work.pcs_psync port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, por_src=>por_axi, pulse_in=>cmd_cnt_clear,
                                             clk_dst=>clk_dp, rst_dst=>rst_dp_i, pulse_out=>dp_cnt_clear);
  u_ps_prst: entity work.pcs_psync port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, por_src=>por_axi, pulse_in=>cmd_prbs_reset,
                                             clk_dst=>clk_dp, rst_dst=>rst_dp_i, pulse_out=>dp_prbs_reset);
  u_ps_inj:  entity work.pcs_psync port map (clk_src=>s_axi_aclk, rst_src=>rst_axi, por_src=>por_axi, pulse_in=>prbs_inj,
                                             clk_dst=>clk_dp, rst_dst=>rst_dp_i, pulse_out=>dp_inj);

  -- ==== silicon datapath (dominio DP) ====
  -- soft_reset reinicia toda la cadena (scrambler/gearbox/prbs) limpiamente
  sil_rst <= rst_dp_i or dp_soft_reset;

  u_sil: entity work.pcs_silicon_datapath
    port map (
      clk_dp=>clk_dp, rst_dp=>sil_rst,
      prbs_gen_en=>dp_gen_en, loopback_en=>dp_loopback_en, prbs_chk_en=>dp_chk_en,
      inject_err=>dp_inj, clr_ber=>dp_prbs_reset,
      ber_count=>sil_ber, chk_locked=>sil_lock,
      tx_word_cnt=>sil_txc, rx_block_cnt=>sil_rxc,
      resync=>dp_resync, rx_lock=>sil_rx_lock, rx_hi_ber=>sil_rx_hiber,
      rx_ev_goodsh=>sil_goodsh, rx_ev_badsh=>sil_badsh, rx_ev_slip=>open
    );

  -- ==== event strobes for the dataplane ====
  -- TX words and PRBS errors from the counter increments (one strobe each,
  -- independent); RX header events come straight from the block sync.
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if rst_dp_i = '1' then
        prev_txc <= (others=>'0'); prev_ber <= (others=>'0');
        tx_inc <= '0'; ber_inc <= '0';
      else
        if unsigned(sil_txc) /= prev_txc then tx_inc <= '1'; else tx_inc <= '0'; end if;
        if unsigned(sil_ber) /= prev_ber then ber_inc <= '1'; else ber_inc <= '0'; end if;
        prev_txc <= unsigned(sil_txc);
        prev_ber <= unsigned(sil_ber);
      end if;
    end if;
  end process;

  -- ==== dataplane (dominio DP): block-lock, hi_ber, lock_time, eventos ====
  u_dpl: entity work.pcs_dataplane
    generic map (EXT_SYNC => true)
    port map (
      clk_dp=>clk_dp, rst_dp=>rst_dp_i,
      blk_evt=>"000",
      tx_stb=>tx_inc, hdr_ok_stb=>sil_goodsh, hdr_bad_stb=>sil_badsh,
      prbs_stb=>ber_inc, ext_lock=>sil_rx_lock, ext_hiber=>sil_rx_hiber,
      cmd_cnt_clear=>dp_cnt_clear, cmd_soft_reset=>dp_soft_reset,
      cmd_resync=>dp_resync, cmd_prbs_reset=>dp_prbs_reset,
      cnt_tx_blk=>dpl_cnt_tx, cnt_rx_blk=>dpl_cnt_rx, cnt_rx_err=>dpl_cnt_re,
      cnt_ber=>dpl_cnt_be, lock_time=>dpl_lock_t,
      st_block_lock=>dpl_block_lock, st_scr_sync=>dpl_scr_sync,
      st_prbs_lock=>dpl_prbs_lock, st_hi_ber=>dpl_hi_ber,
      st_tx_active=>dpl_tx_active, st_rx_active=>dpl_rx_active,
      ev_lock_gained=>dpl_ev_lg, ev_lock_lost=>dpl_ev_ll, ev_hi_ber=>dpl_ev_hb,
      ev_rx_err=>dpl_ev_re, ev_prbs_err=>dpl_ev_pe
    );

  -- ==== CDC dp -> axi ====
  -- Contadores de registro: silicon datapath (verdad de tierra) para tx/rx/ber;
  -- dataplane para rx_err y lock_time. ST_PRBS_LOCK del checker real.
  u_cdc: entity work.pcs_cdc
    port map (
      clk_dp=>clk_dp, rst_dp=>rst_dp_i,
      clk_axi=>s_axi_aclk, rst_axi=>rst_axi,
      por_dp=>por_dp, por_axi=>por_axi,
      dp_block_lock=>dpl_block_lock, dp_scr_sync=>dpl_scr_sync,
      dp_prbs_lock=>sil_lock, dp_hi_ber=>dpl_hi_ber,
      dp_tx_active=>dpl_tx_active, dp_rx_active=>dpl_rx_active,
      axi_block_lock=>axi_block_lock, axi_scr_sync=>axi_scr_sync,
      axi_prbs_lock=>axi_prbs_lock, axi_hi_ber=>axi_hi_ber,
      axi_tx_active=>axi_tx_active, axi_rx_active=>axi_rx_active,
      dp_ev_lock_gained=>dpl_ev_lg, dp_ev_lock_lost=>dpl_ev_ll,
      dp_ev_hi_ber=>dpl_ev_hb, dp_ev_rx_err=>dpl_ev_re, dp_ev_prbs_err=>dpl_ev_pe,
      axi_ev_lock_gained=>axi_ev_lg, axi_ev_lock_lost=>axi_ev_ll,
      axi_ev_hi_ber=>axi_ev_hb, axi_ev_rx_err=>axi_ev_re, axi_ev_prbs_err=>axi_ev_pe,
      axi_snap_req=>stats_snap,
      dp_cnt_tx=>sil_txc, dp_cnt_rx=>sil_rxc, dp_cnt_re=>dpl_cnt_re,
      dp_cnt_be=>sil_ber, dp_lock_t=>dpl_lock_t,
      axi_sh_tx=>axi_sh_tx, axi_sh_rx=>axi_sh_rx, axi_sh_re=>axi_sh_re,
      axi_sh_be=>axi_sh_be, axi_sh_lt=>axi_sh_lt,
      axi_snap_done=>axi_snap_done
    );

end architecture rtl;
