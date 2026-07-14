-- ============================================================================
-- pcie_ltssm.vhd -- PCIE IP v1
-- Link Training and Status State Machine, x1, Gen1 (2.5 GT/s logico).
-- Subconjunto v1: DETECT -> POLLING -> CONFIG -> L0, con RECOVERY, HOT_RESET,
-- LOOPBACK, DISABLED. Rol RC/EP simetrico (ambos entrenan igual en loopback).
--
-- Interfaz de emision (hacia un generador de TS externo / framer):
--   tx_send_ts : '1' pide emitir un TS (ts_kind=0 TS1, 1 TS2)
--   tx_ctl     : Training Control a incrustar en el TS emitido
--   El generador de TS confirma cada TS emitido con tx_ts_done (pulso).
-- Cuando link_up='1' (L0), el LTSSM cede el TX al datapath (framer de TLP/DLLP).
--
-- Interfaz de observacion (desde el deframer RX):
--   rx_ts_valid : pulso al recibir un TS completo
--   rx_is_ts2   : '1' si fue TS2
--   rx_ctl      : Training Control recibido (para Hot Reset / Loopback)
--
-- Ordenes externas por registro (desde MMIO, paso posterior):
--   cmd_start   : arranca Detect->Polling
--   cmd_hotrst  : fuerza envio de TS con Hot Reset
--   cmd_loopbk  : fuerza Loopback
--   cmd_disable : fuerza Disabled
--
-- Salidas de estado: state (ltssm_t), link_up ('1' en L0), y contadores.
-- Timeouts acotados (no 3 ms): si no se completa el entrenamiento en
-- TIMEOUT_CYCLES, vuelve a DETECT (fallo limpio observable).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_ltssm_pkg.all;

entity pcie_ltssm is
  generic (
    TIMEOUT_CYCLES : integer := 100000
  );
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    en          : in  std_logic;                 -- clock-enable de simbolo

    cmd_start   : in  std_logic;
    cmd_hotrst  : in  std_logic;
    cmd_loopbk  : in  std_logic;
    cmd_disable : in  std_logic;

    -- hacia el generador de TS / framer
    tx_send_ts  : out std_logic;
    tx_ts_kind  : out std_logic;                 -- 0=TS1, 1=TS2
    tx_ctl      : out byte_t;
    tx_ts_done  : in  std_logic;                 -- pulso: TS emitido

    -- desde el deframer RX
    rx_ts_valid : in  std_logic;
    rx_is_ts2   : in  std_logic;
    rx_ctl      : in  byte_t;

    -- estado
    state_o     : out std_logic_vector(3 downto 0);
    link_up     : out std_logic;
    ts1_rx_cnt  : out std_logic_vector(15 downto 0);
    ts2_rx_cnt  : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of pcie_ltssm is
  signal st        : ltssm_t := LT_DETECT;
  signal n_ts1_rx  : integer range 0 to 65535 := 0;
  signal n_ts2_rx  : integer range 0 to 65535 := 0;
  signal n_ts2_tx  : integer range 0 to 65535 := 0;
  signal tmo       : integer range 0 to TIMEOUT_CYCLES := 0;
begin

  state_o    <= ltssm_code(st);
  link_up    <= '1' when st = LT_L0 else '0';
  ts1_rx_cnt <= std_logic_vector(to_unsigned(n_ts1_rx, 16));
  ts2_rx_cnt <= std_logic_vector(to_unsigned(n_ts2_rx, 16));

  process(clk)
    procedure to_detect is
    begin
      st <= LT_DETECT; n_ts1_rx <= 0; n_ts2_rx <= 0; n_ts2_tx <= 0; tmo <= 0;
    end procedure;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= LT_DETECT; n_ts1_rx <= 0; n_ts2_rx <= 0; n_ts2_tx <= 0; tmo <= 0;
        tx_send_ts <= '0'; tx_ts_kind <= '0'; tx_ctl <= (others => '0');
      else
        tx_send_ts <= '0';

        -- ordenes globales de maxima prioridad
        if cmd_disable = '1' then
          st <= LT_DISABLED;
        elsif en = '1' then

          -- timeout global de entrenamiento (excepto en estados estables)
          if st = LT_POLLING or st = LT_CONFIG or st = LT_RECOVERY then
            if tmo = TIMEOUT_CYCLES then
              to_detect;
            else
              tmo <= tmo + 1;
            end if;
          else
            tmo <= 0;
          end if;

          case st is
            when LT_DETECT =>
              n_ts1_rx <= 0; n_ts2_rx <= 0; n_ts2_tx <= 0;
              if cmd_start = '1' then
                st <= LT_POLLING;
              end if;

            when LT_POLLING =>
              -- emitir TS1 con Link/Lane = PAD (lo gestiona el generador),
              -- contar TS1 recibidos; salir a CONFIG tras N_TS_POLL
              tx_send_ts <= '1'; tx_ts_kind <= '0';
              tx_ctl <= (others => '0');
              if rx_ts_valid = '1' then
                if rx_is_ts2 = '0' then
                  if n_ts1_rx < N_TS_POLL then n_ts1_rx <= n_ts1_rx + 1; end if;
                end if;
                -- ver un TS2 temprano tambien acepta (partner adelantado)
              end if;
              if n_ts1_rx >= N_TS_POLL - 1 and rx_ts_valid = '1'
                 and rx_is_ts2 = '0' then
                st <= LT_CONFIG; n_ts2_rx <= 0; n_ts2_tx <= 0; tmo <= 0;
              end if;

            when LT_CONFIG =>
              -- emitir TS2; salir a L0 tras N_TS_CFG TS2 rx y >=N_TS_CFG tx
              tx_send_ts <= '1'; tx_ts_kind <= '1';
              tx_ctl <= (others => '0');
              if tx_ts_done = '1' and n_ts2_tx < 65535 then
                n_ts2_tx <= n_ts2_tx + 1;
              end if;
              if rx_ts_valid = '1' and rx_is_ts2 = '1' then
                if n_ts2_rx < N_TS_CFG then n_ts2_rx <= n_ts2_rx + 1; end if;
                -- deteccion de ordenes en Training Control
                if rx_ctl(TC_HOTRESET) = '1' then
                  st <= LT_HOTRESET;
                elsif rx_ctl(TC_LOOPBACK) = '1' then
                  st <= LT_LOOPBACK;
                end if;
              end if;
              if n_ts2_rx >= N_TS_CFG - 1 and rx_ts_valid = '1'
                 and rx_is_ts2 = '1' and n_ts2_tx >= N_TS_CFG then
                st <= LT_L0;
              end if;

            when LT_L0 =>
              -- enlace activo: el TX lo controla el datapath (framer TLP/DLLP)
              tx_send_ts <= '0';
              if cmd_hotrst = '1' then
                st <= LT_HOTRESET;
              elsif cmd_loopbk = '1' then
                st <= LT_LOOPBACK;
              elsif cmd_start = '0' then
                null;  -- permanece en L0
              end if;

            when LT_RECOVERY =>
              tx_send_ts <= '1'; tx_ts_kind <= '1'; tx_ctl <= (others => '0');
              if rx_ts_valid = '1' and rx_is_ts2 = '1' then
                st <= LT_L0;
              end if;

            when LT_HOTRESET =>
              -- emite TS1 con Hot Reset; vuelve a Detect (reinicio de enlace)
              tx_send_ts <= '1'; tx_ts_kind <= '0';
              tx_ctl <= (others => '0'); tx_ctl(TC_HOTRESET) <= '1';
              to_detect;

            when LT_LOOPBACK =>
              -- espejo: el datapath reenvía lo recibido (gestionado fuera)
              tx_send_ts <= '0';
              if cmd_disable = '1' then st <= LT_DISABLED; end if;

            when LT_DISABLED =>
              tx_send_ts <= '0';
              if cmd_start = '1' then st <= LT_DETECT; end if;
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture;
