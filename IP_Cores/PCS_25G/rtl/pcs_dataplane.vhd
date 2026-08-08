-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Data plane de estadisticas (Layer 2), dominio de reloj de 390.625 MHz.
--
-- Modela lo que el oraculo pcs_stats_oracle.py llama DataPlane:
--   * contadores live: tx_blk, rx_blk, rx_err, ber, lock_time
--   * FSM de block-sync: 64 sync-headers validos consecutivos -> block_lock
--     (Opcion B: umbral real de silicio, IEEE 802.3 clausula 49)
--   * deteccion hi_ber: 16 errores acumulados -> hi_ber
--   * generacion de eventos de transicion (lock gained/lost, rx_err, prbs_err)
--
-- Interfaz de estimulo (desde el testbench o, en el core completo, desde el
-- PCS RX real): un puerto 'blk_evt' que codifica el tipo de bloque procesado
-- este ciclo. Esto reemplaza la abstraccion dp_* de Layer 1 por el generador
-- de eventos real.
--
-- Los comandos (cnt_clear, soft_reset, resync, prbs_reset) llegan ya
-- sincronizados a este dominio (la CDC vive en el modulo superior).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_dataplane is
  generic (
    LOCK_THRESHOLD  : natural := 64;   -- sync-headers validos para lock
    HIBER_THRESHOLD : natural := 16    -- errores para hi_ber
  );
  port (
    clk_dp    : in  std_logic;         -- 390.625 MHz
    rst_dp    : in  std_logic;         -- reset sincrono del data plane

    -- evento de bloque procesado este ciclo:
    --   "000" idle, "001" tx, "010" rx_ok, "011" rx_bad, "100" prbs_bad
    blk_evt   : in  std_logic_vector(2 downto 0);

    -- comandos (ya sincronizados a clk_dp)
    cmd_cnt_clear  : in std_logic;
    cmd_soft_reset : in std_logic;
    cmd_resync     : in std_logic;
    cmd_prbs_reset : in std_logic;

    -- contadores live (hacia la logica de snapshot)
    cnt_tx_blk : out std_logic_vector(31 downto 0);
    cnt_rx_blk : out std_logic_vector(31 downto 0);
    cnt_rx_err : out std_logic_vector(31 downto 0);
    cnt_ber    : out std_logic_vector(31 downto 0);
    lock_time  : out std_logic_vector(31 downto 0);

    -- estado
    st_block_lock : out std_logic;
    st_scr_sync   : out std_logic;
    st_prbs_lock  : out std_logic;
    st_hi_ber     : out std_logic;
    st_tx_active  : out std_logic;
    st_rx_active  : out std_logic;

    -- pulsos de evento (1 ciclo dp) hacia el sincronizador de stickies
    ev_lock_gained : out std_logic;
    ev_lock_lost   : out std_logic;
    ev_hi_ber      : out std_logic;
    ev_rx_err      : out std_logic;
    ev_prbs_err    : out std_logic
  );
end entity pcs_dataplane;

architecture rtl of pcs_dataplane is
  constant EVT_IDLE : std_logic_vector(2 downto 0) := "000";
  constant EVT_TX   : std_logic_vector(2 downto 0) := "001";
  constant EVT_RXOK : std_logic_vector(2 downto 0) := "010";
  constant EVT_RXBAD: std_logic_vector(2 downto 0) := "011";
  constant EVT_PRBSB: std_logic_vector(2 downto 0) := "100";

  signal r_tx    : unsigned(31 downto 0) := (others => '0');
  signal r_rx    : unsigned(31 downto 0) := (others => '0');
  signal r_rxerr : unsigned(31 downto 0) := (others => '0');
  signal r_ber   : unsigned(31 downto 0) := (others => '0');
  signal r_lockt : unsigned(31 downto 0) := (others => '0');
  signal r_cycle : unsigned(31 downto 0) := (others => '0');

  signal r_consec : unsigned(15 downto 0) := (others => '0');  -- headers buenos seguidos
  signal r_hiberw : unsigned(15 downto 0) := (others => '0');  -- errores acumulados

  signal r_lock    : std_logic := '0';
  signal r_scr     : std_logic := '0';
  signal r_prbs    : std_logic := '0';
  signal r_hiber   : std_logic := '0';
  signal r_txact   : std_logic := '0';
  signal r_rxact   : std_logic := '0';
  signal r_prevlock: std_logic := '0';

  signal p_lock_gained : std_logic := '0';
  signal p_lock_lost   : std_logic := '0';
  signal p_hi_ber      : std_logic := '0';
  signal p_rx_err      : std_logic := '0';
  signal p_prbs_err    : std_logic := '0';

begin

  process(clk_dp)
    variable v_lock : std_logic;
  begin
    if rising_edge(clk_dp) then
      -- pulsos de evento por defecto a 0
      p_lock_gained <= '0';
      p_lock_lost   <= '0';
      p_hi_ber      <= '0';
      p_rx_err      <= '0';
      p_prbs_err    <= '0';

      if rst_dp = '1' then
        r_tx <= (others=>'0'); r_rx <= (others=>'0'); r_rxerr <= (others=>'0');
        r_ber <= (others=>'0'); r_lockt <= (others=>'0'); r_cycle <= (others=>'0');
        r_consec <= (others=>'0'); r_hiberw <= (others=>'0');
        r_lock <= '0'; r_scr <= '0'; r_prbs <= '0'; r_hiber <= '0';
        r_txact <= '0'; r_rxact <= '0'; r_prevlock <= '0';
      else
        r_cycle <= r_cycle + 1;

        -- comandos (prioridad sobre el evento del ciclo)
        if cmd_cnt_clear = '1' then
          r_tx <= (others=>'0'); r_rx <= (others=>'0');
          r_rxerr <= (others=>'0'); r_ber <= (others=>'0');
        end if;
        if cmd_soft_reset = '1' then
          r_lock <= '0'; r_scr <= '0'; r_prbs <= '0';
          r_consec <= (others=>'0'); r_hiber <= '0'; r_hiberw <= (others=>'0');
          r_prevlock <= '0';
        elsif cmd_resync = '1' then
          r_lock <= '0'; r_consec <= (others=>'0'); r_prevlock <= '0';
        end if;
        if cmd_prbs_reset = '1' then
          r_ber <= (others=>'0'); r_prbs <= '0';
        end if;

        -- procesar evento de bloque (si no hubo soft_reset este ciclo)
        if cmd_soft_reset = '0' then
          case blk_evt is
            when EVT_TX =>
              r_tx <= r_tx + 1;
              r_txact <= '1';

            when EVT_RXOK =>
              r_rx <= r_rx + 1;
              r_rxact <= '1';
              r_consec <= r_consec + 1;
              if to_integer(r_consec + 1) >= LOCK_THRESHOLD and r_lock = '0' then
                r_lock  <= '1';
                r_scr   <= '1';
                r_lockt <= r_cycle;
              end if;

            when EVT_RXBAD =>
              r_rx <= r_rx + 1;
              r_rxact <= '1';
              if cmd_cnt_clear = '0' then
                r_rxerr <= r_rxerr + 1;
              end if;
              r_consec <= (others=>'0');
              r_hiberw <= r_hiberw + 1;
              if to_integer(r_hiberw + 1) >= HIBER_THRESHOLD then
                r_hiber <= '1';
              end if;
              if r_lock = '1' then
                r_lock <= '0';
                r_scr  <= '0';
              end if;
              p_rx_err <= '1';

            when EVT_PRBSB =>
              if cmd_cnt_clear = '0' and cmd_prbs_reset = '0' then
                r_ber <= r_ber + 1;
              end if;
              p_prbs_err <= '1';

            when others =>
              null;
          end case;
        end if;

        -- deteccion de transiciones de lock para stickies
        -- v_lock = valor de lock que tendra tras este ciclo
        v_lock := r_lock;
        if cmd_soft_reset = '1' or cmd_resync = '1' then
          v_lock := '0';
        elsif blk_evt = EVT_RXOK and to_integer(r_consec + 1) >= LOCK_THRESHOLD then
          v_lock := '1';
        elsif blk_evt = EVT_RXBAD and r_lock = '1' then
          v_lock := '0';
        end if;

        if r_prevlock = '0' and v_lock = '1' then p_lock_gained <= '1'; end if;
        if r_prevlock = '1' and v_lock = '0' then p_lock_lost   <= '1'; end if;
        r_prevlock <= v_lock;

        -- prbs_lock sigue a v_lock (mismo ciclo que el lock), respetando
        -- soft_reset/resync/prbs_reset que lo bajan.
        if v_lock = '1' and cmd_soft_reset = '0' and cmd_resync = '0'
           and cmd_prbs_reset = '0' then
          r_prbs <= '1';
        end if;

        -- hi_ber sticky
        if blk_evt = EVT_RXBAD and to_integer(r_hiberw + 1) >= HIBER_THRESHOLD then
          p_hi_ber <= '1';
        end if;
      end if;
    end if;
  end process;

  cnt_tx_blk <= std_logic_vector(r_tx);
  cnt_rx_blk <= std_logic_vector(r_rx);
  cnt_rx_err <= std_logic_vector(r_rxerr);
  cnt_ber    <= std_logic_vector(r_ber);
  lock_time  <= std_logic_vector(r_lockt);

  st_block_lock <= r_lock;
  st_scr_sync   <= r_scr;
  st_prbs_lock  <= r_prbs;
  st_hi_ber     <= r_hiber;
  st_tx_active  <= r_txact;
  st_rx_active  <= r_rxact;

  ev_lock_gained <= p_lock_gained;
  ev_lock_lost   <= p_lock_lost;
  ev_hi_ber      <= p_hi_ber;
  ev_rx_err      <= p_rx_err;
  ev_prbs_err    <= p_prbs_err;

end architecture rtl;
