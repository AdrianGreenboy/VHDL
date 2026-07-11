-- ptp_clock.vhd — reloj ajustable + servo PI (IP PTP / IEEE 802.1AS v1)
-- ---------------------------------------------------------------------------
-- Reloj PTP de 48b.32b (+32b subns) que avanza a 100 MHz por acumulador de
-- fase. Dos vias de ajuste:
--   1) OFFSET_ADJ  : salto atomico UNICO. En cuanto llega el primer error de
--                    offset valido (esclavo, offset_valid='1' y offset_applied
--                    aun '0'), se aplica de golpe a {sec,ns} y se arma
--                    offset_applied. NO se vuelve a saltar (solo reset/rol lo
--                    limpia). Evita la pelea salto-vs-integral.
--   2) servo PI    : con offset_applied='1', cada offset_valid entra al lazo:
--                    P   = (KP*err) >>> SHIFT_P
--                    acc = sat( acc + ((KI*err) >>> SHIFT_I) )
--                    RATE_ADJ = sat32( P + acc )
--                    err es signed ns. KP,KI unsigned 16b (registro SERVO_K).
--
-- Aritmetica ENTERA PURA, replicada bit a bit por iss_ptp.py. Truncamiento
-- por desplazamiento aritmetico (>>>). Todos los anchos en ptp_pkg.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity ptp_clock is
  generic (
    SHIFT_P : integer := SHIFT_P_DEF;
    SHIFT_I : integer := SHIFT_I_DEF
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;                  -- sincrono activo-alto
    -- control de rol / limpieza del salto
    role_slave   : in  std_logic;                  -- '1' esclavo (aplica ajustes)
    clr_servo    : in  std_logic;                  -- pulso: rearma offset_applied
    -- coeficientes del servo (registro SERVO_K)
    kp           : in  std_logic_vector(15 downto 0);
    ki           : in  std_logic_vector(15 downto 0);
    -- entrada de error de offset (desde el motor de sincronizacion)
    offset_err   : in  std_logic_vector(ERR_W-1 downto 0);  -- signed ns
    offset_valid : in  std_logic;                  -- pulso de 1 clk
    -- snapshot del reloj (para timestamping de SFD): combinacional
    now_sec      : out std_logic_vector(SEC_W-1 downto 0);
    now_ns       : out std_logic_vector(NS_W-1 downto 0);
    -- observabilidad
    rate_adj_o   : out std_logic_vector(RATE_W-1 downto 0);
    offset_applied_o : out std_logic
  );
end entity ptp_clock;

architecture rtl of ptp_clock is

  signal sec   : unsigned(SEC_W-1 downto 0)   := (others => '0');
  signal ns    : unsigned(NS_W-1 downto 0)    := (others => '0');
  signal subns : unsigned(SUBNS_W-1 downto 0) := (others => '0');

  signal rate_adj : signed(RATE_W-1 downto 0) := (others => '0');
  signal acc      : signed(ACC_W-1 downto 0)  := (others => '0');
  signal offset_applied : std_logic := '0';
  -- registro para detectar el FLANCO de offset_valid: el error de offset es un
  -- EVENTO de un ciclo, no un nivel. Sin esto, un offset_valid sostenido dos
  -- ciclos dispara el salto y ademas un paso de PI con el mismo error enorme.
  signal ov_d : std_logic := '0';

  -- INC nominal por tick en peso subns: 10 ns => 10 * 2^32 en el campo
  -- comun {ns,subns}. Como INC nominal solo afecta a la parte ns entera, lo
  -- inyectamos como (10 << 32) en el campo signed de fase.
  constant INC_NOM_PHASE : signed(NS_W + SUBNS_W + 1 downto 0) :=
    to_signed(INC_NS_NOM, NS_W + SUBNS_W + 2) sll SUBNS_W;

begin

  now_sec          <= std_logic_vector(sec);
  now_ns           <= std_logic_vector(ns);
  rate_adj_o       <= std_logic_vector(rate_adj);
  offset_applied_o <= offset_applied;

  process(clk)
    variable inc_v    : signed(NS_W + SUBNS_W + 1 downto 0);
    variable packed   : std_logic_vector(SEC_W + NS_W + SUBNS_W - 1 downto 0);
    variable err_s    : signed(ERR_W-1 downto 0);
    variable kp_u     : unsigned(15 downto 0);
    variable ki_u     : unsigned(15 downto 0);
    variable p_term   : signed(ERR_W + 16 downto 0);
    variable i_step   : signed(ERR_W + 16 downto 0);
    variable acc_v    : signed(ACC_W-1 downto 0);
    variable rate_v   : signed(ACC_W+1 downto 0);
    variable new_sec  : signed(SEC_W downto 0);
    variable new_ns   : signed(NS_W downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sec <= (others => '0');
        ns  <= (others => '0');
        subns <= (others => '0');
        rate_adj <= (others => '0');
        acc <= (others => '0');
        offset_applied <= '0';
        ov_d <= '0';
      else
        ov_d <= offset_valid;   -- para deteccion de flanco

        -- ---- 1) avance del reloj por acumulador de fase (cada tick) -------
        inc_v  := INC_NOM_PHASE + resize(rate_adj, inc_v'length);
        packed := clk_tick(sec, ns, subns, inc_v);
        sec   <= unsigned(packed(SEC_W + NS_W + SUBNS_W - 1 downto NS_W + SUBNS_W));
        ns    <= unsigned(packed(NS_W + SUBNS_W - 1 downto SUBNS_W));
        subns <= unsigned(packed(SUBNS_W - 1 downto 0));

        -- ---- limpieza del armado de salto (cambio de rol / clr) -----------
        if clr_servo = '1' then
          offset_applied <= '0';
          acc      <= (others => '0');
          rate_adj <= (others => '0');
        end if;

        -- ---- 2) tratamiento del error de offset (por FLANCO, no nivel) ----
        if offset_valid = '1' and ov_d = '0' and role_slave = '1' then
          err_s := signed(offset_err);

          if offset_applied = '0' and clr_servo = '0' then
            -- SALTO UNICO: aplicar err de golpe a {sec,ns}. err en ns con signo.
            -- Recalcular sobre el valor recien avanzado este mismo ciclo.
            new_sec := resize(signed('0' & std_logic_vector(
                         unsigned(packed(SEC_W + NS_W + SUBNS_W - 1 downto NS_W + SUBNS_W)))),
                         new_sec'length);
            new_ns  := resize(signed('0' & std_logic_vector(
                         unsigned(packed(NS_W + SUBNS_W - 1 downto SUBNS_W)))),
                         new_ns'length) + resize(err_s, new_ns'length);
            -- normalizar ns tras el salto (un solo wrap arriba/abajo basta para
            -- |err| < 1e9; para saltos mayores el guion de bring-up trocea)
            if new_ns >= to_signed(1_000_000_000, new_ns'length) then
              new_ns  := new_ns - to_signed(1_000_000_000, new_ns'length);
              new_sec := new_sec + 1;
            elsif new_ns < 0 then
              new_ns  := new_ns + to_signed(1_000_000_000, new_ns'length);
              new_sec := new_sec - 1;
            end if;
            sec <= unsigned(std_logic_vector(new_sec(SEC_W-1 downto 0)));
            ns  <= unsigned(std_logic_vector(new_ns(NS_W-1 downto 0)));
            offset_applied <= '1';

          elsif offset_applied = '1' then
            -- LAZO PI (de libro, punto fijo):
            --   El integral ACUMULA en alta resolucion (sin truncar antes),
            --   asi no muere con errores pequenos. Se trunca solo AL LEER.
            --   P    = (KP * err) >>> SHIFT_P
            --   acc  = sat( acc + KP_I*err )         [alta resolucion]
            --   RATE = sat32( P + (acc >>> SHIFT_I) )
            kp_u := unsigned(kp);
            ki_u := unsigned(ki);
            -- P = (KP * err) >>> SHIFT_P
            p_term := resize(err_s * signed('0' & std_logic_vector(kp_u)), p_term'length);
            p_term := shift_right(p_term, SHIFT_P);
            -- aporte integral SIN truncar: KI*err directo al acumulador
            i_step := resize(err_s * signed('0' & std_logic_vector(ki_u)), i_step'length);
            acc_v := sat_signed(resize(acc, ACC_W+2) + resize(i_step, ACC_W+2), ACC_W);
            acc <= acc_v;
            -- RATE = sat32( P + (acc >>> SHIFT_I) )
            rate_v := resize(p_term, ACC_W+2) +
                      shift_right(resize(acc_v, ACC_W+2), SHIFT_I);
            rate_adj <= sat_signed(rate_v, RATE_W);
          end if;
        end if;

      end if;
    end if;
  end process;

end architecture rtl;
