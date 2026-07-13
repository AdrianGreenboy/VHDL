-- ============================================================================
-- mpc_dot_row.vhd — Producto punto de fila (IP ADCS, port de mpc_dot_row.sv).
--   result = sum_{j=0..n_dim-1} h_row[j]*u_vec[j]
--
-- ACUMULADORES ENTRELAZADOS (contrato numerico, NACC=16 en adcs_pkg):
--   fase acumulacion : acc[j mod NACC] = fma(h[j], u[j], acc[j mod NACC])
--   fase reduccion   : acc[0] = fma(acc[k], 1.0, acc[0]),  k = 1..NACC-1
-- El FMA es FIFO de latencia fija: la k-esima salida corresponde a la k-esima
-- entrada; emision (issue_k) y captura (capt_k) rotan con contadores
-- independientes y el fin de fase se detecta por conteo (recv = n_dim).
--
-- INTERLOCK (leccion de silicio, Paso 1 de la tesis): solo se emite un MAC si
-- acc[issue_k] no tiene resultado en vuelo (inflight = 0). Con esto el modulo
-- es correcto ante CUALQUIER latencia real del FMA, no solo la del modelo
-- behavioral (NACC=12 pasaba en sim con LAT=8 y fallaba en placa por la
-- latencia efectiva del FPO). La capa 1b lo verifica corriendo con
-- LAT_FMA = 20 > NACC.
--
-- MUT (solo verificacion, 0 en uso normal):
--   1 = sin interlock (emite siempre)   -> debe fallar con LAT_FMA > NACC
--   2 = terminacion off-by-one (n_dim-1 elementos)
--   3 = reduccion trunca (omite acc[NACC-1])
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;
use work.fp32_pkg.all;

entity mpc_dot_row is
  generic (
    LAT_FMA : natural := 8;
    MUT     : natural := 0
  );
  port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    start  : in  std_logic;
    n_dim  : in  std_logic_vector(IDX_W-1 downto 0);
    h_row  : in  std_logic_vector(D*FP_W-1 downto 0);  -- {H[i,D-1],...,H[i,0]}
    u_vec  : in  std_logic_vector(D*FP_W-1 downto 0);  -- {U[D-1],...,U[0]}
    done   : out std_logic;
    result : out std_logic_vector(FP_W-1 downto 0)
  );
end entity mpc_dot_row;

architecture rtl of mpc_dot_row is

  type fp_arr_d  is array (0 to D-1)    of std_logic_vector(FP_W-1 downto 0);
  type fp_arr_na is array (0 to NACC-1) of std_logic_vector(FP_W-1 downto 0);
  type u2_arr_na is array (0 to NACC-1) of unsigned(1 downto 0);

  type dstate_e is (D_IDLE, D_ISSUE, D_DRAIN, D_RED_ISSUE, D_RED_WAIT, D_FIN);
  signal dstate : dstate_e;

  signal h, u      : fp_arr_d;
  signal accs      : fp_arr_na;
  signal inflight  : u2_arr_na;
  signal j, recv   : unsigned(IDX_W-1 downto 0);
  signal issue_k   : natural range 0 to NACC-1;
  signal capt_k    : natural range 0 to NACC-1;
  signal kr        : natural range 0 to NACC-1;
  signal acc_phase : std_logic;

  signal fma_v_in, fma_v_out : std_logic;
  signal fma_a, fma_b, fma_c, fma_res : std_logic_vector(FP_W-1 downto 0);

begin

  g_unpack : for gi in 0 to D-1 generate
    h(gi) <= h_row((gi+1)*FP_W-1 downto gi*FP_W);
    u(gi) <= u_vec((gi+1)*FP_W-1 downto gi*FP_W);
  end generate;

  u_fma : entity work.fp32_fma
    generic map (LAT_FMA => LAT_FMA, MUT => 0)
    port map (
      clk => clk, rst_n => rst_n, in_valid => fma_v_in,
      a => fma_a, b => fma_b, c => fma_c,
      out_valid => fma_v_out, result => fma_res);

  p_fsm : process (clk, rst_n)
    variable can_issue : boolean;
    variable j_last    : unsigned(IDX_W-1 downto 0);
  begin
    if rst_n = '0' then
      dstate    <= D_IDLE;
      j         <= (others => '0');
      recv      <= (others => '0');
      issue_k   <= 0;
      capt_k    <= 0;
      kr        <= 0;
      done      <= '0';
      result    <= (others => '0');
      fma_v_in  <= '0';
      fma_a     <= (others => '0');
      fma_b     <= (others => '0');
      fma_c     <= (others => '0');
      acc_phase <= '0';
      accs      <= (others => (others => '0'));
      inflight  <= (others => (others => '0'));
    elsif rising_edge(clk) then
      done     <= '0';
      fma_v_in <= '0';

      -- ------ captura de salidas del FMA en fase de acumulacion ------------
      if acc_phase = '1' and fma_v_out = '1' then
        accs(capt_k)     <= fma_res;
        inflight(capt_k) <= inflight(capt_k) - 1;   -- libera el acumulador
        if capt_k = NACC-1 then capt_k <= 0; else capt_k <= capt_k + 1; end if;
        recv <= recv + 1;
      end if;

      case dstate is

        when D_IDLE =>
          if start = '1' then
            accs      <= (others => (others => '0'));
            inflight  <= (others => (others => '0'));
            j         <= (others => '0');
            recv      <= (others => '0');
            issue_k   <= 0;
            capt_k    <= 0;
            acc_phase <= '1';
            dstate    <= D_ISSUE;
          end if;

        -- emitir 1 MAC/ciclo: acc[issue_k] = h[j]*u[j] + acc[issue_k]
        -- INTERLOCK: solo si acc[issue_k] no tiene resultado en vuelo.
        when D_ISSUE =>
          can_issue := (inflight(issue_k) = 0);
          if MUT = 1 then can_issue := true; end if;     -- MUT1: sin interlock
          if can_issue then
            fma_a    <= h(to_integer(j));
            fma_b    <= u(to_integer(j));
            fma_c    <= accs(issue_k);
            fma_v_in <= '1';
            inflight(issue_k) <= inflight(issue_k) + 1;
            if issue_k = NACC-1 then issue_k <= 0;
            else issue_k <= issue_k + 1; end if;
            j_last := unsigned(n_dim) - 1;
            if MUT = 2 then j_last := unsigned(n_dim) - 2; end if; -- MUT2
            if j = j_last then
              dstate <= D_DRAIN;
            else
              j <= j + 1;
            end if;
          end if;
          -- si no: stall (acc ocupado); reintenta el proximo ciclo

        -- esperar las n_dim salidas (n_dim-1 con MUT2)
        when D_DRAIN =>
          if (recv = unsigned(n_dim)) or
             (MUT = 2 and recv = unsigned(n_dim) - 1) then
            acc_phase <= '0';
            kr        <= 1;          -- reducir acc[1..NACC-1] sobre acc[0]
            dstate    <= D_RED_ISSUE;
          end if;

        -- reduccion: acc[0] = fma(acc[kr], 1.0, acc[0])
        when D_RED_ISSUE =>
          fma_a    <= accs(kr);
          fma_b    <= FP32_PONE;
          fma_c    <= accs(0);
          fma_v_in <= '1';
          dstate   <= D_RED_WAIT;

        when D_RED_WAIT =>
          if fma_v_out = '1' then
            accs(0) <= fma_res;
            if (kr = NACC-1) or (MUT = 3 and kr = NACC-2) then  -- MUT3
              dstate <= D_FIN;
            else
              kr     <= kr + 1;
              dstate <= D_RED_ISSUE;
            end if;
          end if;

        when D_FIN =>
          result <= accs(0);
          done   <= '1';
          dstate <= D_IDLE;

      end case;
    end if;
  end process;

end architecture rtl;
