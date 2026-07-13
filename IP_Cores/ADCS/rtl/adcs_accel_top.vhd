-- ============================================================================
-- adcs_accel_top.vhd — Top del IP ADCS para el SoC RV32IM (familia VHDL).
--
-- Integra: adcs_regfile (bus dmem, patron A2) + bancos H/g/U + mpc_engine
-- (solver PGD) + axi_dma_engine (maestro AXI4 propio a DDR) + un SECUENCIADOR
-- HW que orquesta la operacion completa. El core solo escribe punteros/dims y
-- CTRL.START; el IP hace LOAD_H -> LOAD_G -> solve -> STORE_U por si mismo y
-- levanta DONE (sticky en el reg file). Doorbell/reporte a DDR lo hace el
-- firmware con el dma_burst del SoC (ortogonal a este maestro).
--
-- Interfaz de control: bus dmem de familia (dmem_sel/addr/wdata/wstrb/rdata/
-- ready). En el SoC, mem_subsys_dma decodifica la region 0xA -> dmem_sel.
-- Interfaz de datos: maestro AXI4 propio (m_axi_*), 32-bit, hacia el NoC.
--
-- v1: MODE_MPC_PGD (LOAD_G -> solve -> STORE_U) y MODE_LOAD_H (solo carga H).
-- MODE_SRUKF_QR reservado (fase 2): en v1 cae a T_FINISH sin operar.
--
-- MUT (solo verificacion): 0 = normal; 1 = secuenciador salta STORE_U (U nunca
-- llega a DDR); 2 = done_set antes de STORE_U (DONE prematuro).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;
use work.riscv_pkg.all;

entity adcs_accel_top is
  generic (
    LAT_FMA : natural := 8;
    LAT_ADD : natural := 6;
    MUT     : natural := 0
  );
  port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    irq    : out std_logic;
    -- bus dmem de familia (region 0xA decodificada por mem_subsys_dma)
    dmem_sel   : in  std_logic;
    dmem_addr  : in  word_t;
    dmem_wdata : in  word_t;
    dmem_wstrb : in  std_logic_vector(3 downto 0);
    dmem_rdata : out word_t;
    dmem_ready : out std_logic;
    -- maestro AXI4 propio hacia DDR
    m_axi_araddr  : out std_logic_vector(31 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arprot  : out std_logic_vector(2 downto 0);
    m_axi_arcache : out std_logic_vector(3 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic;
    m_axi_awaddr  : out std_logic_vector(31 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awprot  : out std_logic_vector(2 downto 0);
    m_axi_awcache : out std_logic_vector(3 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic
  );
end entity adcs_accel_top;

architecture rtl of adcs_accel_top is

  -- control desde el reg file
  signal start_pulse, soft_reset, irq_en : std_logic;
  signal mode    : std_logic_vector(1 downto 0);
  signal n_dim   : std_logic_vector(IDX_W-1 downto 0);
  signal maxiter : std_logic_vector(15 downto 0);
  signal step_f, umax_f : std_logic_vector(31 downto 0);
  signal h_base, g_base, u_base : std_logic_vector(31 downto 0);
  signal busy_all, done_set, err_set : std_logic;
  signal dbg_vec : std_logic_vector(31 downto 0);

  -- engine <-> bancos
  signal eng_start, eng_busy, eng_done, iter_tick : std_logic;
  signal iter_cnt : std_logic_vector(15 downto 0);
  signal h_rd_en  : std_logic;
  signal h_rd_row : std_logic_vector(IDX_W-1 downto 0);
  signal h_row_d  : std_logic_vector(D*FP_W-1 downto 0);
  signal g_rd_en  : std_logic;
  signal g_rd_a   : std_logic_vector(IDX_W-1 downto 0);
  signal g_rd_d   : std_logic_vector(FP_W-1 downto 0);
  signal u_rd_en, u_wr_en : std_logic;
  signal u_rd_a, u_wr_a   : std_logic_vector(IDX_W-1 downto 0);
  signal u_rd_d, u_wr_d   : std_logic_vector(FP_W-1 downto 0);
  signal u_vec    : std_logic_vector(D*FP_W-1 downto 0);

  -- DMA <-> bancos
  signal dma_cmd_valid : std_logic;
  signal dma_cmd_op    : std_logic_vector(1 downto 0);
  signal dma_cmd_addr  : std_logic_vector(31 downto 0);
  signal dma_cmd_words : std_logic_vector(15 downto 0);
  signal dma_cmd_done, dma_cmd_busy : std_logic;
  signal dma_dbg_st    : std_logic_vector(3 downto 0);
  signal dma_dbg_beat  : std_logic_vector(15 downto 0);
  signal dh_wr_en : std_logic;
  signal dh_wr_row, dh_wr_col : std_logic_vector(IDX_W-1 downto 0);
  signal dh_wr_data : std_logic_vector(FP_W-1 downto 0);
  signal dg_wr_en : std_logic;
  signal dg_wr_addr : std_logic_vector(IDX_W-1 downto 0);
  signal dg_wr_data : std_logic_vector(FP_W-1 downto 0);
  signal u_ext_rd_addr : std_logic_vector(IDX_W-1 downto 0);
  signal u_ext_rd_data : std_logic_vector(FP_W-1 downto 0);
  signal dma_lin : std_logic_vector(15 downto 0);

  -- bancos: muxes de puerto de escritura (DMA carga / engine escribe U)
  signal h_wr_en  : std_logic;
  signal h_wr_row, h_wr_col : std_logic_vector(IDX_W-1 downto 0);
  signal h_wr_data : std_logic_vector(FP_W-1 downto 0);
  signal g_wr_en  : std_logic;
  signal g_wr_addr : std_logic_vector(IDX_W-1 downto 0);
  signal g_wr_data : std_logic_vector(FP_W-1 downto 0);
  signal uwr_en   : std_logic;
  signal uwr_addr : std_logic_vector(IDX_W-1 downto 0);
  signal uwr_data : std_logic_vector(FP_W-1 downto 0);

  signal rstn_eff : std_logic;

  -- secuenciador
  type tstate_e is (T_IDLE, T_LOADH_ISSUE, T_LOADH_WAIT,
                    T_LOADG_ISSUE, T_LOADG_WAIT, T_MPC_RUN, T_MPC_WAIT,
                    T_STOREU_ISSUE, T_STOREU_WAIT, T_FINISH);
  signal ts : tstate_e;

  constant OP_LOAD_H  : std_logic_vector(1 downto 0) := "00";
  constant OP_LOAD_G  : std_logic_vector(1 downto 0) := "01";
  constant OP_STORE_U : std_logic_vector(1 downto 0) := "10";

  function ts_code(s : tstate_e) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(tstate_e'pos(s), 5));
  end function;
begin

  rstn_eff <= rst_n and (not soft_reset);
  irq_en   <= '0';   -- v1: sin IRQ del IP (el firmware usa doorbell del SoC)

  -- ---------------- reg file (bus dmem) ----------------
  u_reg : entity work.adcs_regfile
    generic map (MUT => 0)
    port map (
      clk => clk, rst_n => rst_n,
      dmem_sel => dmem_sel, dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      start_pulse => start_pulse, soft_reset => soft_reset, irq_en => open,
      mode => mode, n_dim => n_dim, maxiter => maxiter,
      step_f => step_f, umax_f => umax_f,
      h_base => h_base, g_base => g_base, u_base => u_base,
      busy => busy_all, done_set => done_set, err_set => err_set,
      iter_cnt => iter_cnt, dbg_in => dbg_vec);

  -- ---------------- bancos ----------------
  -- H: escribe el DMA (carga). g: escribe el DMA. U: escribe el engine.
  h_wr_en   <= dh_wr_en;
  h_wr_row  <= dh_wr_row;
  h_wr_col  <= dh_wr_col;
  h_wr_data <= dh_wr_data;
  g_wr_en   <= dg_wr_en;
  g_wr_addr <= dg_wr_addr;
  g_wr_data <= dg_wr_data;
  uwr_en    <= u_wr_en;
  uwr_addr  <= u_wr_a;
  uwr_data  <= u_wr_d;

  u_h : entity work.h_bank
    port map (clk => clk,
              wr_en => h_wr_en, wr_row => h_wr_row, wr_col => h_wr_col,
              wr_data => h_wr_data,
              rd_en => h_rd_en, rd_row => h_rd_row, row_data => h_row_d);

  u_g : entity work.g_bank
    port map (clk => clk,
              wr_en => g_wr_en, wr_addr => g_wr_addr, wr_data => g_wr_data,
              rd_en => g_rd_en, rd_addr => g_rd_a, rd_data => g_rd_d);

  u_u : entity work.u_bank
    port map (clk => clk, rst_n => rst_n,
              wr_en => uwr_en, wr_addr => uwr_addr, wr_data => uwr_data,
              rd_en => u_rd_en, rd_addr => u_rd_a, rd_data => u_rd_d,
              snap_tick => iter_tick, u_vec => u_vec,
              ext_rd_addr => u_ext_rd_addr, ext_rd_data => u_ext_rd_data);

  -- ---------------- engine PGD ----------------
  u_eng : entity work.mpc_engine
    generic map (LAT_FMA => LAT_FMA, LAT_ADD => LAT_ADD, NLANES => 8, MUT => 0)
    port map (
      clk => clk, rst_n => rstn_eff,
      start => eng_start, n_dim => n_dim, maxiter => maxiter,
      step_f => step_f, umax_f => umax_f,
      busy => eng_busy, done => eng_done, iter_cnt => iter_cnt,
      iter_tick => iter_tick,
      h_rd_en => h_rd_en, h_rd_row => h_rd_row, h_row_data => h_row_d,
      g_rd_en => g_rd_en, g_rd_addr => g_rd_a, g_rd_data => g_rd_d,
      u_rd_en => u_rd_en, u_rd_addr => u_rd_a, u_rd_data => u_rd_d,
      u_wr_en => u_wr_en, u_wr_addr => u_wr_a, u_wr_data => u_wr_d,
      u_vec_data => u_vec);

  -- ---------------- DMA maestro ----------------
  u_dma : entity work.axi_dma_engine
    generic map (MUT => 0)
    port map (
      clk => clk, rst_n => rstn_eff,
      cmd_valid => dma_cmd_valid, cmd_op => dma_cmd_op, cmd_addr => dma_cmd_addr,
      cmd_words => dma_cmd_words, cmd_done => dma_cmd_done, cmd_busy => dma_cmd_busy,
      dbg_st => dma_dbg_st, dbg_beat => dma_dbg_beat,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen,
      m_axi_arsize => m_axi_arsize, m_axi_arburst => m_axi_arburst,
      m_axi_arprot => m_axi_arprot, m_axi_arcache => m_axi_arcache,
      m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp,
      m_axi_rlast => m_axi_rlast, m_axi_rvalid => m_axi_rvalid,
      m_axi_rready => m_axi_rready,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen,
      m_axi_awsize => m_axi_awsize, m_axi_awburst => m_axi_awburst,
      m_axi_awprot => m_axi_awprot, m_axi_awcache => m_axi_awcache,
      m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb,
      m_axi_wlast => m_axi_wlast, m_axi_wvalid => m_axi_wvalid,
      m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid,
      m_axi_bready => m_axi_bready,
      h_wr_en => dh_wr_en, h_wr_row => dh_wr_row, h_wr_col => dh_wr_col,
      h_wr_data => dh_wr_data,
      g_wr_en => dg_wr_en, g_wr_addr => dg_wr_addr, g_wr_data => dg_wr_data,
      u_ext_rd_addr => u_ext_rd_addr, u_ext_rd_data => u_ext_rd_data,
      lin_addr => dma_lin);

  busy_all <= '0' when ts = T_IDLE else '1';

  -- vector de debug (REG_DEBUG 0x44), REGISTRADO (rompe ruta larga a 240 MHz):
  --   [31:16] tag de presencia 0xADC5
  --   [15:9]  beat del DMA (7 bits bajos)
  --   [8:5]   estado FSM del DMA
  --   [4:0]   estado FSM del secuenciador
  p_dbg : process (clk)
  begin
    if rising_edge(clk) then
      dbg_vec <= x"ADC5" & dma_dbg_beat(6 downto 0) & dma_dbg_st & ts_code(ts);
    end if;
  end process;

  -- ================= SECUENCIADOR MAESTRO =================
  p_seq : process (clk, rstn_eff)
  begin
    if rstn_eff = '0' then
      ts            <= T_IDLE;
      dma_cmd_valid <= '0';
      dma_cmd_op    <= (others => '0');
      dma_cmd_addr  <= (others => '0');
      dma_cmd_words <= (others => '0');
      eng_start     <= '0';
      done_set      <= '0';
      err_set       <= '0';
      irq           <= '0';
    elsif rising_edge(clk) then
      dma_cmd_valid <= '0';
      dma_cmd_words <= (others => '0');
      eng_start     <= '0';
      done_set      <= '0';
      err_set       <= '0';

      case ts is
        when T_IDLE =>
          if start_pulse = '1' then
            if mode = MODE_LOAD_H then
              ts <= T_LOADH_ISSUE;
            elsif mode = MODE_MPC_PGD then
              ts <= T_LOADG_ISSUE;
            else
              ts <= T_FINISH;          -- MODE_SRUKF_QR reservado en v1
            end if;
          end if;

        -- LOAD H (solo)
        when T_LOADH_ISSUE =>
          dma_cmd_valid <= '1';
          dma_cmd_op    <= OP_LOAD_H;
          dma_cmd_addr  <= h_base;
          ts <= T_LOADH_WAIT;
        when T_LOADH_WAIT =>
          if dma_cmd_done = '1' then ts <= T_FINISH; end if;

        -- MPC: LOAD G -> solve -> STORE U
        -- (H debe haberse cargado antes con una operacion MODE_LOAD_H previa;
        -- el firmware hace START(LOAD_H) y luego START(MPC_PGD))
        when T_LOADG_ISSUE =>
          dma_cmd_valid <= '1';
          dma_cmd_op    <= OP_LOAD_G;
          dma_cmd_addr  <= g_base;
          ts <= T_LOADG_WAIT;
        when T_LOADG_WAIT =>
          if dma_cmd_done = '1' then ts <= T_MPC_RUN; end if;

        when T_MPC_RUN =>
          eng_start <= '1';
          ts <= T_MPC_WAIT;
        when T_MPC_WAIT =>
          if eng_done = '1' then
            if MUT = 1 then
              ts <= T_FINISH;          -- MUT1: salta STORE_U
            else
              ts <= T_STOREU_ISSUE;
            end if;
          end if;

        when T_STOREU_ISSUE =>
          if MUT = 2 then done_set <= '1'; end if;   -- MUT2: DONE prematuro
          dma_cmd_valid <= '1';
          dma_cmd_op    <= OP_STORE_U;
          dma_cmd_addr  <= u_base;
          ts <= T_STOREU_WAIT;
        when T_STOREU_WAIT =>
          if dma_cmd_done = '1' then ts <= T_FINISH; end if;

        when T_FINISH =>
          done_set <= '1';
          ts <= T_IDLE;

      end case;
    end if;
  end process;

end architecture rtl;
