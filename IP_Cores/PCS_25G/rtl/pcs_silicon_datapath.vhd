-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Subsistema de datos del silicon pass (dominio data plane, 390.625 MHz).
--
-- Cadena de loopback que ejercita TODO el PCS:
--
--   PRBS31 gen -> TX datapath (scrambler+gearbox) -> [loopback paralelo]
--              -> RX datapath (gearbox+descrambler) -> PRBS31 checker
--
-- Controlado por:
--   prbs_gen_en : habilita el generador PRBS31 hacia el TX datapath
--   loopback_en : conecta la salida del TX a la entrada del RX (parallel loop)
--   prbs_chk_en : habilita el checker sobre el payload recuperado
--
-- Salidas de observabilidad (hacia el data plane de estadisticas / banco):
--   ber_count   : errores acumulados del checker
--   chk_locked  : el checker sincronizo
--   tx_word_cnt : palabras emitidas por el TX (para contadores)
--
-- Verificado contra pcs_toplevel_oracle.py (propiedad: BER=0 en limpio,
-- BER>0 con inyeccion).
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_silicon_datapath is
  port (
    clk_dp      : in  std_logic;
    rst_dp      : in  std_logic;

    -- control
    prbs_gen_en : in  std_logic;
    loopback_en : in  std_logic;
    prbs_chk_en : in  std_logic;
    inject_err  : in  std_logic;   -- pulso: inyecta 1 bit error en el loopback
    clr_ber     : in  std_logic;   -- pulso: limpia el BER (descarta transitorio)

    -- observabilidad
    ber_count   : out std_logic_vector(31 downto 0);
    chk_locked  : out std_logic;
    tx_word_cnt : out std_logic_vector(31 downto 0);
    rx_block_cnt: out std_logic_vector(31 downto 0)
  );
end entity pcs_silicon_datapath;

architecture rtl of pcs_silicon_datapath is
  -- PRBS31 generador + skid hacia el TX
  signal gen_en     : std_logic;
  signal prbs_dout  : std_logic_vector(63 downto 0);
  signal prbs_dv    : std_logic;
  signal hold_valid : std_logic := '0';
  signal hold_word  : std_logic_vector(63 downto 0) := (others => '0');
  signal inj_pend   : std_logic := '0';
  signal tx_in_payload : std_logic_vector(63 downto 0);
  -- TX datapath
  signal tx_in_valid, tx_in_ready, tx_out_valid : std_logic;
  signal tx_out_word : std_logic_vector(63 downto 0);
  -- loopback -> RX
  signal loop_word  : std_logic_vector(63 downto 0);
  signal loop_valid : std_logic;
  -- RX datapath
  signal rx_in_ready, rx_out_valid, rx_out_isdata : std_logic;
  signal rx_out_payload : std_logic_vector(63 downto 0);
  -- checker
  signal chk_din : std_logic_vector(63 downto 0);
  signal chk_en  : std_logic;
  -- contadores
  signal r_txcnt : unsigned(31 downto 0) := (others => '0');
  signal r_rxcnt : unsigned(31 downto 0) := (others => '0');
begin

  -- ==== PRBS31 generador con skid hacia el TX datapath ====
  -- El TX datapath baja in_ready un ciclo en cada limite de periodo 32/33 del
  -- gearbox. El generador tiene 1 ciclo de latencia, asi que una palabra puede
  -- quedar "en vuelo" cuando ready baja: el skid la retiene y la reintenta.
  -- Sin esto se pierde 1 palabra por periodo y el stream PRBS pierde
  -- continuidad (el checker cuenta rafagas de errores en cada perdida).
  gen_en <= prbs_gen_en and tx_in_ready and (not hold_valid);

  u_gen: entity work.prbs31_gen
    port map (clk=>clk_dp, rst=>rst_dp, en=>gen_en,
              dout=>prbs_dout, dvalid=>prbs_dv);

  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then
        hold_valid <= '0';
        hold_word  <= (others => '0');
      else
        if hold_valid = '1' then
          if tx_in_ready = '1' then
            hold_valid <= '0';        -- el TX tomo la palabra retenida
          end if;
        elsif prbs_dv = '1' and tx_in_ready = '0' then
          hold_valid <= '1';          -- palabra en vuelo sin ready: retener
          hold_word  <= prbs_dout;
        end if;
      end if;
    end if;
  end process;

  -- hacia el TX: prioridad a la palabra retenida
  tx_in_valid   <= hold_valid or prbs_dv;
  tx_in_payload <= hold_word when hold_valid = '1' else prbs_dout;

  -- ==== TX datapath: el PRBS entra como payload ====
  u_tx: entity work.pcs_tx_datapath
    port map (clk=>clk_dp, rst=>rst_dp,
              in_valid=>tx_in_valid, in_payload=>tx_in_payload, in_is_data=>'1',
              in_ready=>tx_in_ready,
              out_valid=>tx_out_valid, out_word=>tx_out_word);

  -- ==== loopback paralelo con inyeccion opcional de error ====
  -- inject_err (pulso) se RETIENE en inj_pend hasta la primera palabra valida
  -- del TX: si el pulso cae en un ciclo sin tx_out_valid, no se pierde. Se
  -- consume exactamente una vez (flip del bit 0 de una unica palabra).
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then
        inj_pend <= '0';
      else
        if inject_err = '1' then
          inj_pend <= '1';
        elsif inj_pend = '1' and tx_out_valid = '1' then
          inj_pend <= '0';            -- consumida en esta palabra
        end if;
      end if;
    end if;
  end process;

  -- loop_word/loop_valid REGISTRADOS: parte el camino de timing
  -- sync(loopback_en) -> mux -> insercion dinamica del gearbox RX en dos
  -- tramos cortos (+1 ciclo de latencia de loopback, tolerado por todas las
  -- propiedades: BER=0, deteccion de inyeccion, conteos).
  loop_gen: process(clk_dp)
    variable w : std_logic_vector(63 downto 0);
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then
        loop_word  <= (others => '0');
        loop_valid <= '0';
      else
        w := tx_out_word;
        w(0) := w(0) xor inj_pend;
        if loopback_en = '1' then
          loop_word <= w;
        else
          loop_word <= (others => '0');
        end if;
        loop_valid <= tx_out_valid and loopback_en;
      end if;
    end if;
  end process;

  -- ==== RX datapath ====
  u_rx: entity work.pcs_rx_datapath
    port map (clk=>clk_dp, rst=>rst_dp,
              in_valid=>loop_valid, in_word=>loop_word, in_ready=>rx_in_ready,
              out_valid=>rx_out_valid, out_payload=>rx_out_payload,
              out_is_data=>rx_out_isdata);

  -- ==== PRBS31 checker sobre el payload recuperado ====
  chk_din <= rx_out_payload;
  chk_en  <= rx_out_valid and prbs_chk_en;
  u_chk: entity work.prbs31_chk
    port map (clk=>clk_dp, rst=>rst_dp, en=>chk_en, clr_ber=>clr_ber, din=>chk_din,
              err_count=>ber_count, locked=>chk_locked);

  -- ==== contadores de observabilidad ====
  process(clk_dp)
  begin
    if rising_edge(clk_dp) then
      if rst_dp = '1' then
        r_txcnt <= (others => '0');
        r_rxcnt <= (others => '0');
      else
        if tx_out_valid = '1' then r_txcnt <= r_txcnt + 1; end if;
        if rx_out_valid = '1' then r_rxcnt <= r_rxcnt + 1; end if;
      end if;
    end if;
  end process;

  tx_word_cnt  <= std_logic_vector(r_txcnt);
  rx_block_cnt <= std_logic_vector(r_rxcnt);

end architecture rtl;
