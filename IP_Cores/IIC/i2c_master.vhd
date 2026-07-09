-- ============================================================================
--  i2c_master.vhd — Motor maestro I2C a nivel de byte (open-drain, PIO)
--  Familia de periféricos del RV32I SoC v3 — capa 1a (aislamiento)
--
--  * Comando por byte (pulso de 1 ciclo, aceptado solo con busy='0' — mismo
--    espíritu que el contrato dmem_req del SoC):
--      cmd_start  : genera START (o START repetido) antes del byte
--      cmd_stop   : genera STOP después del byte
--      cmd_read   : byte de lectura (SDA liberada, se muestrea);
--                   cmd_ackout es el ACK a emitir tras el byte ('0' = ACK)
--      cmd_nobyte : SOLO STOP, sin byte (p. ej. tras un NACK del esclavo)
--    Desde IDLE todo comando genera START aunque cmd_start='0': no existen
--    bytes sin transacción abierta.
--
--  * Temporización por cuartos de bit: F_SCL = Fclk / (4*(scl_div+1))
--      con Fclk = 100 MHz:  100 kHz -> 249 | ~400 kHz -> 62 | 1 MHz -> 24
--
--  * Clock stretching: en las fases de SCL liberada el contador de cuartos
--    se CONGELA hasta ver SCL alta de verdad (filtrada). Sin timeout en v1:
--    un esclavo que estire para siempre cuelga la transacción (el watchdog
--    va en software o en una v1.1 del mmio).
--
--  * Pérdida de arbitraje: emitimos '1' (línea liberada) y la línea está en
--    '0' — se chequea en los bits de dato de escritura y en la fase de
--    START. Se liberan ambas líneas, se pulsa arb_lost y se vuelve a IDLE.
--    (No se arbitra el slot de ACK: fuera de alcance v1, documentado.)
--
--  * Monitor de bus: detecta START/STOP ajenos (o propios) en la línea y
--    mantiene bus_busy. Desde IDLE el motor espera bus libre (ST_WAITFREE)
--    antes de generar su START — cortesía multi-master básica.
--
--  * Open-drain: *_t = '1' libera la línea, '0' la jala a tierra. NUNCA se
--    empuja un '1'. El IOBUF va en el wrapper (patrón half-duplex USART).
--
--  * Entre bytes sin STOP el motor queda en ST_HELD con SCL retenida abajo:
--    el bus es nuestro hasta el siguiente comando (legal en I2C).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                     -- síncrono, activo alto
    en         : in  std_logic;
    scl_div    : in  std_logic_vector(15 downto 0); -- clk por CUARTO de bit

    cmd_valid  : in  std_logic;                     -- pulso de 1 ciclo
    cmd_start  : in  std_logic;
    cmd_stop   : in  std_logic;
    cmd_read   : in  std_logic;
    cmd_ackout : in  std_logic;                     -- '0' = ACK tras lectura
    cmd_nobyte : in  std_logic;                     -- solo STOP
    cmd_wdata  : in  std_logic_vector(7 downto 0);

    busy       : out std_logic;
    done       : out std_logic;                     -- pulso de 1 ciclo
    rdata      : out std_logic_vector(7 downto 0);
    ack_in     : out std_logic;                     -- '0' = el esclavo dio ACK
    arb_lost   : out std_logic;                     -- pulso de 1 ciclo
    bus_busy   : out std_logic;                     -- nivel (monitor de línea)
    xact_open  : out std_logic;                     -- transacción propia abierta

    scl_i      : in  std_logic;
    scl_t      : out std_logic;                     -- '1' libera, '0' jala
    sda_i      : in  std_logic;
    sda_t      : out std_logic
  );
end entity i2c_master;

architecture rtl of i2c_master is

  -- sincronización 2FF + filtro de mayoría de 3 muestras
  signal scl_s, sda_s : std_logic_vector(1 downto 0) := (others => '1');
  signal scl_h, sda_h : std_logic_vector(2 downto 0) := (others => '1');
  signal scl_f, sda_f : std_logic := '1';
  signal sda_fd       : std_logic := '1';

  type st_t is (ST_IDLE, ST_WAITFREE, ST_START, ST_BITS, ST_HELD, ST_STOP);
  signal st : st_t := ST_IDLE;

  signal phase   : integer range 0 to 3 := 0;
  signal qcnt    : unsigned(15 downto 0) := (others => '0');
  signal bit_idx : integer range 0 to 8 := 0;
  signal buf_cnt : integer range 0 to 3 := 0;       -- cuartos de tBUF tras STOP

  signal shreg, rsh : std_logic_vector(7 downto 0) := (others => '0');
  signal is_read    : std_logic := '0';
  signal do_stop    : std_logic := '0';
  signal ackout_r   : std_logic := '0';

  signal scl_t_r, sda_t_r : std_logic := '1';
  signal busy_r, xopen_r  : std_logic := '0';
  signal done_r, arb_r    : std_logic := '0';
  signal ack_in_r         : std_logic := '1';
  signal bus_busy_r       : std_logic := '0';

begin

  main : process(clk)
    variable adv    : boolean;   -- cuarto de bit completado en este ciclo
    variable v_lost : boolean;   -- arbitraje perdido en este ciclo
  begin
    if rising_edge(clk) then
      done_r <= '0';
      arb_r  <= '0';

      -- =================== filtros de entrada ===================
      scl_s <= scl_s(0) & scl_i;
      sda_s <= sda_s(0) & sda_i;
      scl_h <= scl_h(1 downto 0) & scl_s(1);
      sda_h <= sda_h(1 downto 0) & sda_s(1);
      scl_f <= (scl_h(2) and scl_h(1)) or (scl_h(2) and scl_h(0))
               or (scl_h(1) and scl_h(0));
      sda_f <= (sda_h(2) and sda_h(1)) or (sda_h(2) and sda_h(0))
               or (sda_h(1) and sda_h(0));
      sda_fd <= sda_f;

      -- ============ monitor de bus: START/STOP en la línea ============
      if scl_f = '1' and sda_fd = '1' and sda_f = '0' then
        bus_busy_r <= '1';                          -- START (propio o ajeno)
      elsif scl_f = '1' and sda_fd = '0' and sda_f = '1' then
        bus_busy_r <= '0';                          -- STOP
      end if;

      -- =================== contador de cuartos ===================
      -- En las fases con SCL liberada (phase 1 de START/BITS/STOP) el conteo
      -- se congela hasta que SCL esté alta de verdad: clock stretching y
      -- tiempos de subida quedan absorbidos aquí.
      adv := false;
      if busy_r = '1' then
        if phase = 1 and scl_f = '0'
           and (st = ST_BITS or st = ST_START or st = ST_STOP) then
          qcnt <= (others => '0');
        elsif qcnt >= unsigned(scl_div) then
          qcnt <= (others => '0');
          adv  := true;
        else
          qcnt <= qcnt + 1;
        end if;
      else
        qcnt <= (others => '0');
      end if;

      -- =================== FSM principal ===================
      case st is

        when ST_IDLE =>
          scl_t_r <= '1';
          sda_t_r <= '1';
          xopen_r <= '0';
          if en = '1' and cmd_valid = '1' and busy_r = '0' then
            if cmd_nobyte = '1' then
              done_r <= '1';                        -- STOP sin xact: no-op
            else
              shreg    <= cmd_wdata;
              is_read  <= cmd_read;
              do_stop  <= cmd_stop;
              ackout_r <= cmd_ackout;
              busy_r   <= '1';
              st       <= ST_WAITFREE;              -- START implícito
            end if;
          end if;

        when ST_WAITFREE =>
          if bus_busy_r = '0' then
            phase <= 0;
            st    <= ST_START;
          end if;

        when ST_START =>
          case phase is
            when 0 =>                               -- SDA liberada (SCL como esté)
              sda_t_r <= '1';
              if adv then phase <= 1; end if;
            when 1 =>                               -- SCL liberada; esperar alta
              scl_t_r <= '1';
              if adv then
                if sda_f = '0' then                 -- otro maestro sostiene SDA
                  sda_t_r <= '1';
                  busy_r  <= '0';
                  xopen_r <= '0';
                  arb_r   <= '1';
                  st      <= ST_IDLE;
                else
                  phase <= 2;
                end if;
              end if;
            when 2 =>                               -- START: SDA cae con SCL alta
              sda_t_r <= '0';
              if adv then phase <= 3; end if;
            when 3 =>                               -- SCL abajo, arranca bit 0
              scl_t_r <= '0';
              if adv then
                xopen_r <= '1';
                bit_idx <= 0;
                phase   <= 0;
                st      <= ST_BITS;
              end if;
          end case;

        when ST_BITS =>
          case phase is
            when 0 =>                               -- SCL abajo: colocar SDA
              scl_t_r <= '0';
              if bit_idx < 8 then
                if is_read = '1' then
                  sda_t_r <= '1';
                else
                  sda_t_r <= shreg(7);
                end if;
              else                                  -- slot de ACK
                if is_read = '1' then
                  sda_t_r <= ackout_r;
                else
                  sda_t_r <= '1';
                end if;
              end if;
              if adv then phase <= 1; end if;

            when 1 =>                               -- SCL liberada; muestrear
              scl_t_r <= '1';
              if adv then
                v_lost := false;
                if bit_idx < 8 then
                  if is_read = '1' then
                    rsh <= rsh(6 downto 0) & sda_f;
                  elsif shreg(7) = '1' and sda_f = '0' then
                    v_lost := true;                 -- arbitraje perdido
                  end if;
                elsif is_read = '0' then
                  ack_in_r <= sda_f;                -- ACK del esclavo
                end if;
                if v_lost then
                  sda_t_r <= '1';
                  busy_r  <= '0';
                  xopen_r <= '0';
                  arb_r   <= '1';
                  st      <= ST_IDLE;
                else
                  phase <= 2;
                end if;
              end if;

            when 2 =>                               -- SCL alta, segunda mitad
              if adv then phase <= 3; end if;

            when 3 =>                               -- SCL abajo de nuevo
              scl_t_r <= '0';
              if adv then
                if bit_idx < 8 then
                  shreg   <= shreg(6 downto 0) & '0';
                  bit_idx <= bit_idx + 1;
                  phase   <= 0;
                else                                -- byte + ACK completos
                  if do_stop = '1' then
                    phase <= 0;
                    st    <= ST_STOP;
                  else
                    busy_r <= '0';
                    done_r <= '1';
                    st     <= ST_HELD;
                  end if;
                end if;
              end if;
          end case;

        when ST_HELD =>                             -- SCL retenida entre bytes
          scl_t_r <= '0';
          sda_t_r <= '1';
          if en = '1' and cmd_valid = '1' and busy_r = '0' then
            if cmd_nobyte = '1' then
              busy_r <= '1';
              phase  <= 0;
              st     <= ST_STOP;
            else
              shreg    <= cmd_wdata;
              is_read  <= cmd_read;
              do_stop  <= cmd_stop;
              ackout_r <= cmd_ackout;
              busy_r   <= '1';
              phase    <= 0;
              if cmd_start = '1' then               -- START repetido
                st <= ST_START;
              else
                bit_idx <= 0;
                st      <= ST_BITS;
              end if;
            end if;
          end if;

        when ST_STOP =>
          case phase is
            when 0 =>                               -- SDA abajo con SCL abajo
              scl_t_r <= '0';
              sda_t_r <= '0';
              if adv then phase <= 1; end if;
            when 1 =>                               -- SCL liberada; esperar alta
              scl_t_r <= '1';
              if adv then phase <= 2; end if;
            when 2 =>                               -- STOP: SDA sube con SCL alta
              sda_t_r <= '1';
              if adv then
                buf_cnt <= 0;
                phase   <= 3;
              end if;
            when 3 =>                               -- tBUF: 4 cuartos libres
              xopen_r <= '0';
              if adv then
                if buf_cnt = 3 then
                  busy_r <= '0';
                  done_r <= '1';
                  st     <= ST_IDLE;
                else
                  buf_cnt <= buf_cnt + 1;
                end if;
              end if;
          end case;

      end case;

      -- =================== reset síncrono ===================
      if rst = '1' then
        st         <= ST_IDLE;
        phase      <= 0;
        bit_idx    <= 0;
        buf_cnt    <= 0;
        qcnt       <= (others => '0');
        busy_r     <= '0';
        xopen_r    <= '0';
        done_r     <= '0';
        arb_r      <= '0';
        ack_in_r   <= '1';
        bus_busy_r <= '0';
        scl_t_r    <= '1';
        sda_t_r    <= '1';
      end if;
    end if;
  end process;

  busy      <= busy_r;
  done      <= done_r;
  rdata     <= rsh;
  ack_in    <= ack_in_r;
  arb_lost  <= arb_r;
  bus_busy  <= bus_busy_r;
  xact_open <= xopen_r;
  scl_t     <= scl_t_r;
  sda_t     <= sda_t_r;

end architecture rtl;
