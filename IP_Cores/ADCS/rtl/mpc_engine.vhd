-- ============================================================================
-- mpc_engine.vhd — Solver PGD del MPC condensado (port de mpc_engine.sv rev B).
--
--   U = 0
--   repeat MAXITER:
--     for i: HU[i] = H[i,:] . U_snapshot        (Jacobi: U del INICIO de iter)
--     for i: U[i]  = clamp(U[i] - step*(HU[i]+g[i]), +/-umax)
--
-- Procesa por GRUPOS de NLANES=8 filas: carga 8 filas de H (latencia 1 del
-- banco), corre mpc_dot_x8, y actualiza los 8 lanes en secuencia. El snapshot
-- u_vec (u_bank) solo se refresca con iter_tick al final de cada iteracion.
--
-- Cadena de update:  t1 = fma(g, 1.0, HU) = HU+g ;  t2 = fma(-step, t1, U) ;
--                    U = clamp(t2)  (clamp entero signo-magnitud, combinacional)
-- El add se implementa con el MISMO motor FMA verificado (b=1.0): identico al
-- add IEEE (producto por 1.0 exacto), un solo motor en el contrato.
--
-- DESVIACION documentada vs el SV original: el update espera out_valid del
-- add/fma (un solo op en vuelo => inambiguo; mismo patron que D_RED_WAIT del
-- dot) en vez de contar LAT ciclos fijos. Numericamente identico y robusto
-- ante latencia efectiva del FPO distinta de la configurada — la clase de
-- hazard que causo el bug NACC=12 sim-OK/silicio-FALLA.
--
-- MUT (solo verificacion, 0 en uso normal):
--   1 = snapshot roto: tick tambien por grupo (Gauss-Seidel accidental)
--   2 = clamp no satura negativos
--   3 = step sin negar (asciende en vez de descender)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;
use work.fp32_pkg.all;

entity mpc_engine is
  generic (
    LAT_FMA : natural := 8;
    LAT_ADD : natural := 6;
    NLANES  : natural := 8;
    MUT     : natural := 0
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    -- control
    start      : in  std_logic;
    n_dim      : in  std_logic_vector(IDX_W-1 downto 0);
    maxiter    : in  std_logic_vector(15 downto 0);
    step_f     : in  std_logic_vector(31 downto 0);
    umax_f     : in  std_logic_vector(31 downto 0);
    busy       : out std_logic;
    done       : out std_logic;
    iter_cnt   : out std_logic_vector(15 downto 0);
    iter_tick  : out std_logic;      -- el top/u_bank refresca el snapshot
    -- BRAM H (RO), fila completa
    h_rd_en    : out std_logic;
    h_rd_row   : out std_logic_vector(IDX_W-1 downto 0);
    h_row_data : in  std_logic_vector(D*FP_W-1 downto 0);
    -- BRAM g (RO)
    g_rd_en    : out std_logic;
    g_rd_addr  : out std_logic_vector(IDX_W-1 downto 0);
    g_rd_data  : in  std_logic_vector(FP_W-1 downto 0);
    -- BRAM U (RW)
    u_rd_en    : out std_logic;
    u_rd_addr  : out std_logic_vector(IDX_W-1 downto 0);
    u_rd_data  : in  std_logic_vector(FP_W-1 downto 0);
    u_wr_en    : out std_logic;
    u_wr_addr  : out std_logic_vector(IDX_W-1 downto 0);
    u_wr_data  : out std_logic_vector(FP_W-1 downto 0);
    -- snapshot de U para la GEMV
    u_vec_data : in  std_logic_vector(D*FP_W-1 downto 0)
  );
end entity mpc_engine;

architecture rtl of mpc_engine is

  type state_e is (S_IDLE, S_INIT_U, S_INIT_TICK, S_SNAP,
                   S_LOAD_CAP, S_LOAD_REQ, S_DOT, S_DOT_WAIT,
                   S_UPD_START, S_UPD_RD, S_UPD_RDW, S_UPD_ADDW, S_UPD_FMAW,
                   S_ADVANCE, S_FLUSH, S_TICK, S_DONE);
  signal state : state_e;

  signal it        : unsigned(15 downto 0);
  signal grp_base  : unsigned(IDX_W-1 downto 0);
  signal ucnt      : unsigned(IDX_W-1 downto 0);
  signal load_i    : natural range 0 to NLANES-1;
  signal upd_i     : natural range 0 to NLANES-1;

  type row_arr is array (0 to NLANES-1) of std_logic_vector(D*FP_W-1 downto 0);
  signal h_rows_reg : row_arr;
  signal h_rows_fl  : std_logic_vector(NLANES*D*FP_W-1 downto 0);
  signal lane_en    : std_logic_vector(NLANES-1 downto 0);
  signal hu_flat    : std_logic_vector(NLANES*FP_W-1 downto 0);

  signal dot_start, dot_done : std_logic;

  signal neg_step : std_logic_vector(31 downto 0);

  signal add_v_in, add_v_out : std_logic;
  signal add_a, add_res      : std_logic_vector(31 downto 0);
  signal fma_v_in, fma_v_out : std_logic;
  signal fma_a, fma_b, fma_c, fma_res : std_logic_vector(31 downto 0);
  signal clamp_out : std_logic_vector(31 downto 0);

  signal u_i_reg  : std_logic_vector(FP_W-1 downto 0);
  signal hu_reg_c : std_logic_vector(FP_W-1 downto 0);

begin

  busy <= '1' when (state /= S_IDLE) and (state /= S_DONE) else '0';
  iter_cnt <= std_logic_vector(it);

  neg_step <= (not step_f(31)) & step_f(30 downto 0)
              when MUT /= 3 else step_f;                 -- MUT3

  g_flat : for L in 0 to NLANES-1 generate
    h_rows_fl((L+1)*D*FP_W-1 downto L*D*FP_W) <= h_rows_reg(L);
  end generate;

  u_dotx8 : entity work.mpc_dot_x8
    generic map (LAT_FMA => LAT_FMA, NLANES => NLANES)
    port map (
      clk => clk, rst_n => rst_n,
      start => dot_start, n_dim => n_dim, lane_en => lane_en,
      h_rows => h_rows_fl, u_vec => u_vec_data,
      done => dot_done, results => hu_flat);

  -- add = fma(g, 1.0, HU): mismo motor verificado, contrato de familia
  u_add : entity work.fp32_fma
    generic map (LAT_FMA => LAT_ADD, MUT => 0)
    port map (
      clk => clk, rst_n => rst_n, in_valid => add_v_in,
      a => add_a, b => FP32_PONE, c => hu_reg_c, out_valid => add_v_out,
      result => add_res);

  u_fma : entity work.fp32_fma
    generic map (LAT_FMA => LAT_FMA, MUT => 0)
    port map (
      clk => clk, rst_n => rst_n, in_valid => fma_v_in,
      a => fma_a, b => fma_b, c => fma_c,
      out_valid => fma_v_out, result => fma_res);

  -- clamp entero signo-magnitud (combinacional): |x|>|umax| => {sig_x, |umax|}
  p_clamp : process (all)
  begin
    if unsigned(fma_res(30 downto 0)) > unsigned(umax_f(30 downto 0)) then
      if MUT = 2 and fma_res(31) = '1' then
        clamp_out <= fma_res;                            -- MUT2: negativos sin saturar
      else
        clamp_out <= fma_res(31) & umax_f(30 downto 0);
      end if;
    else
      clamp_out <= fma_res;
    end if;
  end process;

  p_fsm : process (clk, rst_n)
    variable hu_cur : std_logic_vector(FP_W-1 downto 0);
  begin
    if rst_n = '0' then
      state      <= S_IDLE;
      it         <= (others => '0');
      grp_base   <= (others => '0');
      ucnt       <= (others => '0');
      load_i     <= 0;
      upd_i      <= 0;
      done       <= '0';
      iter_tick  <= '0';
      dot_start  <= '0';
      h_rd_en    <= '0';  h_rd_row  <= (others => '0');
      g_rd_en    <= '0';  g_rd_addr <= (others => '0');
      u_rd_en    <= '0';  u_rd_addr <= (others => '0');
      u_wr_en    <= '0';  u_wr_addr <= (others => '0');
      u_wr_data  <= (others => '0');
      add_v_in   <= '0';  add_a <= (others => '0');
      fma_v_in   <= '0';
      fma_a      <= (others => '0');
      fma_b      <= (others => '0');
      fma_c      <= (others => '0');
      hu_reg_c   <= (others => '0');
      u_i_reg    <= (others => '0');
      lane_en    <= (others => '0');
      h_rows_reg <= (others => (others => '0'));
    elsif rising_edge(clk) then
      -- defaults de pulsos
      done      <= '0';
      iter_tick <= '0';
      dot_start <= '0';
      h_rd_en   <= '0';
      g_rd_en   <= '0';
      u_rd_en   <= '0';
      u_wr_en   <= '0';
      add_v_in  <= '0';
      fma_v_in  <= '0';

      case state is

        when S_IDLE =>
          if start = '1' then
            it    <= (others => '0');
            ucnt  <= (others => '0');
            state <= S_INIT_U;
          end if;

        when S_INIT_U =>
          u_wr_en   <= '1';
          u_wr_addr <= std_logic_vector(ucnt);
          u_wr_data <= (others => '0');
          if ucnt = unsigned(n_dim) - 1 then
            ucnt     <= (others => '0');
            grp_base <= (others => '0');
            state    <= S_INIT_TICK;
          else
            ucnt <= ucnt + 1;
          end if;

        -- BUGFIX (hallado en capa 1c, latente tambien en el SV original): el
        -- tick inicial NO puede coincidir con la ultima escritura de INIT; el
        -- espejo del u_bank consuma esa escritura en el mismo flanco en que el
        -- snapshot muestrea, y u_vec[n-1] quedaria con el valor del solve
        -- ANTERIOR (invisible tras reset; corrompe la 1a iteracion en solves
        -- consecutivos). Un ciclo de separacion garantiza espejo fresco.
        when S_INIT_TICK =>
          iter_tick <= '1';        -- snapshot inicial (U=0)
          state     <= S_SNAP;

        -- ciclo de guarda: el snapshot u_vec se estabiliza
        -- BUGFIX (hallado en capa 1c, presente tambien en el SV rev B): la
        -- entrada a la carga DEBE pasar por S_LOAD_REQ. Ir directo a CAP
        -- captura un flanco antes de que el banco (latencia 1) entregue la
        -- fila pedida, y lane 0 se queda con la fila retenida ANTERIOR.
        -- Invisible en la iteracion 0 (snapshot U=0 => HU=0 con cualquier H)
        -- y enmascarable por el clamp: solo la firma bit-exacta lo caza.
        when S_SNAP =>
          load_i   <= 0;
          h_rd_en  <= '1';
          h_rd_row <= std_logic_vector(grp_base);
          state    <= S_LOAD_REQ;

        -- captura de la fila 'load_i' (pedida el ciclo anterior, latencia 1)
        when S_LOAD_CAP =>
          h_rows_reg(load_i) <= h_row_data;
          if grp_base + load_i < unsigned(n_dim) then
            lane_en(load_i) <= '1';
          else
            lane_en(load_i) <= '0';
          end if;
          if load_i = NLANES-1 then
            state <= S_DOT;
          else
            h_rd_en  <= '1';
            h_rd_row <= std_logic_vector(grp_base + load_i + 1);
            load_i   <= load_i + 1;
            state    <= S_LOAD_REQ;
          end if;

        when S_LOAD_REQ =>
          state <= S_LOAD_CAP;

        when S_DOT =>
          dot_start <= '1';
          state     <= S_DOT_WAIT;

        when S_DOT_WAIT =>
          if dot_done = '1' then
            upd_i <= 0;
            state <= S_UPD_START;
          end if;

        -- update del lane upd_i: U = clamp(U - step*(HU+g))
        when S_UPD_START =>
          if lane_en(upd_i) = '0' then
            if upd_i = NLANES-1 then
              state <= S_ADVANCE;
            else
              upd_i <= upd_i + 1;
            end if;
          else
            g_rd_en   <= '1';
            g_rd_addr <= std_logic_vector(grp_base + upd_i);
            u_rd_en   <= '1';
            u_rd_addr <= std_logic_vector(grp_base + upd_i);
            state     <= S_UPD_RD;
          end if;

        when S_UPD_RD =>
          g_rd_en   <= '1';
          g_rd_addr <= std_logic_vector(grp_base + upd_i);
          u_rd_en   <= '1';
          u_rd_addr <= std_logic_vector(grp_base + upd_i);
          state     <= S_UPD_RDW;

        -- datos del banco validos: capturar U, lanzar add = fma(g, 1.0, HU)
        when S_UPD_RDW =>
          u_i_reg  <= u_rd_data;
          hu_cur   := hu_flat((upd_i+1)*FP_W-1 downto upd_i*FP_W);
          add_a    <= g_rd_data;
          hu_reg_c <= hu_cur;
          add_v_in <= '1';
          state    <= S_UPD_ADDW;

        -- esperar out_valid del add (un solo op en vuelo => inambiguo),
        -- lanzar fma: (-step)*t1 + U
        when S_UPD_ADDW =>
          if add_v_out = '1' then
            fma_a    <= neg_step;
            fma_b    <= add_res;
            fma_c    <= u_i_reg;
            fma_v_in <= '1';
            state    <= S_UPD_FMAW;
          end if;

        -- esperar out_valid del fma; clamp_out combinacional valido ese ciclo
        when S_UPD_FMAW =>
          if fma_v_out = '1' then
            u_wr_en   <= '1';
            u_wr_addr <= std_logic_vector(grp_base + upd_i);
            u_wr_data <= clamp_out;
            if upd_i = NLANES-1 then
              state <= S_ADVANCE;
            else
              upd_i <= upd_i + 1;
              state <= S_UPD_START;
            end if;
          end if;

        when S_ADVANCE =>
          if MUT = 1 then
            iter_tick <= '1';        -- MUT1: snapshot por grupo (Gauss-Seidel)
          end if;
          if grp_base + NLANES >= unsigned(n_dim) then
            grp_base <= (others => '0');
            state    <= S_FLUSH;
          else
            grp_base <= grp_base + NLANES;
            load_i   <= 0;
            h_rd_en  <= '1';
            h_rd_row <= std_logic_vector(grp_base + NLANES);
            state    <= S_LOAD_REQ;   -- BUGFIX: mismo espaciado que S_SNAP
          end if;

        when S_FLUSH =>
          state <= S_TICK;

        when S_TICK =>
          iter_tick <= '1';
          if it = unsigned(maxiter) - 1 then
            state <= S_DONE;
          else
            it    <= it + 1;
            state <= S_SNAP;
          end if;

        when S_DONE =>
          done  <= '1';
          state <= S_IDLE;

      end case;
    end if;
  end process;

end architecture rtl;
