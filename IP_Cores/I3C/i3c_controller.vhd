-- ============================================================================
--  i3c_controller.vhd - Motor controller MIPI I3C SDR (capa 1a)
--
--  Motor de bits del controller I3C. Genera SCL push-pull SIEMPRE que es
--  dueno del bus (en I3C no existe clock stretching: no se muestrea SCL).
--  SDA alterna entre open-drain (header arbitrado tras START, bits ACK,
--  START/Sr/STOP, colecta ENTDAA, captura IBI) y push-pull (headers tras
--  Sr, datos de escritura, bit T de paridad).
--
--  Temporizacion: cada bit son 4 cuartos; cada cuarto dura (div+1) ciclos
--  de clk. div_pp gobierna las fases push-pull (div_pp=1 -> 12.5 MHz con
--  clk=100 MHz) y div_od las fases open-drain (limitadas por el pull-up).
--  SCL bajo en cuartos q0-q1, alto en q2-q3. SDA se coloca en el tick
--  q0->q1 (un cuarto de hold tras la bajada de SCL) y se muestrea via
--  doble FF al final de q3, salvo el bit T de lectura que se muestrea al
--  final de q2 para poder apoderarse de SDA en q3 (terminacion de lectura
--  por el controller = Sr/STOP durante T alto).
--
--  Comandos (pulso cmd_valid de 1 ciclo, aceptado con busy=0):
--    cmd_start + cmd_wdata : START (desde IDLE, header open-drain con
--                            arbitraje) o Sr (con transaccion abierta,
--                            header push-pull). El 9no bit es ACK.
--    cmd_wdata solo        : byte de datos push-pull; 9no bit = T paridad
--                            impar generada por el motor.
--    cmd_read              : byte de lectura; el target conduce; 9no = T.
--                            t_bit='0' => el target termino (el motor
--                            retiene SDA bajo y espera STOP/Sr firmware).
--    cmd_read + cmd_rlast  : ultima lectura: si T=1 el motor se apodera de
--                            SDA durante T alto (Sr); con cmd_stop encadena
--                            STOP; sin el, deja Sr hecho (srskip) y el
--                            siguiente cmd_start va directo a los bits.
--    cmd_daa               : ronda ENTDAA: Sr + 0x7E/R + ACK open-drain;
--                            si ACK colecta 64 bits open-drain emitiendo
--                            rvalid cada 8; si NACK termina con ack_in=1.
--    cmd_daadr             : envia DA en cmd_wdata(7:1) + paridad impar de
--                            7 bits + bit ACK.
--    cmd_nobyte + cmd_stop : STOP sin byte.
--    cmd_ibiack            : conduce el ACK del IBI pendiente (open-drain).
--    cmd_ibinak            : NACK del IBI (libera el 9no bit); con
--                            cmd_stop encadena STOP.
--
--  IBI: en IDLE con la linea armada (SDA visto alto), una caida de SDA es
--  un START de target. El motor genera SCL, captura los 8 bits arbitrados
--  sin conducir, publica ibi_addr/ibi_avalid, aparca SCL bajo (S_IBIWAIT,
--  busy=0, ibi_req=1) y espera cmd_ibiack/cmd_ibinak. La perdida de
--  arbitraje en un header open-drain propio desemboca en el mismo camino
--  (arb_lost + ibi_avalid + done del comando perdido).
--
--  done: exactamente un pulso por comando aceptado (incluida la perdida de
--  arbitraje). La captura de IBI desde IDLE no es un comando: solo emite
--  ibi_avalid. rvalid pulsa por cada byte leido (lecturas y ENTDAA).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i3c_controller is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                      -- sincrono, activo alto
    en         : in  std_logic;
    div_pp     : in  std_logic_vector(15 downto 0);  -- clk por CUARTO - 1 (push-pull)
    div_od     : in  std_logic_vector(15 downto 0);  -- clk por CUARTO - 1 (open-drain)

    cmd_valid  : in  std_logic;
    cmd_start  : in  std_logic;
    cmd_stop   : in  std_logic;
    cmd_read   : in  std_logic;
    cmd_rlast  : in  std_logic;
    cmd_nobyte : in  std_logic;
    cmd_daa    : in  std_logic;
    cmd_daadr  : in  std_logic;
    cmd_ibiack : in  std_logic;
    cmd_ibinak : in  std_logic;
    cmd_wdata  : in  std_logic_vector(7 downto 0);

    busy       : out std_logic;
    done       : out std_logic;                      -- pulso
    rdata      : out std_logic_vector(7 downto 0);
    rvalid     : out std_logic;                      -- pulso por byte leido
    ack_in     : out std_logic;                      -- '0' = ACK recibido
    t_bit      : out std_logic;                      -- ultimo T de lectura
    arb_lost   : out std_logic;                      -- pulso
    ibi_req    : out std_logic;                      -- nivel: IBI pendiente
    ibi_addr   : out std_logic_vector(7 downto 0);   -- header capturado
    ibi_avalid : out std_logic;                      -- pulso
    xact_open  : out std_logic;

    scl_o      : out std_logic;
    scl_t      : out std_logic;                      -- '1' libera
    scl_i      : in  std_logic;
    sda_o      : out std_logic;
    sda_t      : out std_logic;                      -- '1' libera
    sda_i      : in  std_logic
  );
end entity i3c_controller;

architecture rtl of i3c_controller is

  type st_t is (S_IDLE, S_STA_A, S_STA_B,
                S_SR_A, S_SR_B, S_SR_C, S_SR_D,
                S_BITS, S_ACKB, S_ACKDRV, S_TBWR, S_TBRD,
                S_RSEIZE, S_RSEIZE2, S_HOLD0,
                S_STP_A, S_STP_B, S_STP_C,
                S_XOPEN, S_IBIWAIT, S_IBI_S);
  type md_t is (M_HDR_OD, M_HDR_PP, M_WR, M_RD, M_DAA64, M_DAADR, M_IBIC);

  signal st      : st_t := S_IDLE;
  signal md      : md_t := M_WR;
  signal q       : unsigned(1 downto 0)  := (others => '0');
  signal qcnt    : unsigned(15 downto 0) := (others => '0');
  signal bit_i   : unsigned(5 downto 0)  := (others => '0');
  signal shreg   : std_logic_vector(7 downto 0) := (others => '0');
  signal txreg   : std_logic_vector(7 downto 0) := (others => '0');
  signal od_cur  : std_logic := '1';
  signal lost_r  : std_logic := '0';
  signal daahdr  : std_logic := '0';
  signal nackib  : std_logic := '0';
  signal p_stop  : std_logic := '0';
  signal p_rlast : std_logic := '0';
  signal p_wdata : std_logic_vector(7 downto 0) := (others => '0');
  signal srskip  : std_logic := '0';
  signal armed   : std_logic := '0';

  signal busy_r  : std_logic := '0';
  signal xopen_r : std_logic := '0';
  signal ibirq_r : std_logic := '0';
  signal done_p  : std_logic := '0';
  signal rval_p  : std_logic := '0';
  signal ibiav_p : std_logic := '0';
  signal arb_p   : std_logic := '0';
  signal rdata_r : std_logic_vector(7 downto 0) := (others => '0');
  signal ibiad_r : std_logic_vector(7 downto 0) := (others => '0');
  signal ack_r   : std_logic := '1';
  signal tbit_r  : std_logic := '1';

  signal sclo_r  : std_logic := '1';
  signal sclt_r  : std_logic := '1';
  signal sdao_r  : std_logic := '1';
  signal sdat_r  : std_logic := '1';

  signal sda_f1, sda_f2 : std_logic := '1';
  signal scl_f1, scl_f2 : std_logic := '1';

  function pxor(v : std_logic_vector) return std_logic is
    variable x : std_logic := '0';
  begin
    for i in v'range loop
      x := x xor v(i);
    end loop;
    return x;
  end function;

begin

  busy       <= busy_r;
  done       <= done_p;
  rdata      <= rdata_r;
  rvalid     <= rval_p;
  ack_in     <= ack_r;
  t_bit      <= tbit_r;
  arb_lost   <= arb_p;
  ibi_req    <= ibirq_r;
  ibi_addr   <= ibiad_r;
  ibi_avalid <= ibiav_p;
  xact_open  <= xopen_r;
  scl_o      <= sclo_r;
  scl_t      <= sclt_r;
  sda_o      <= sdao_r;
  sda_t      <= sdat_r;

  process(clk)
    variable div_sel : unsigned(15 downto 0);
    variable b       : std_logic;
    variable timed   : boolean;
  begin
    if rising_edge(clk) then
      -- sincronizadores 2FF
      sda_f1 <= sda_i;
      sda_f2 <= sda_f1;
      scl_f1 <= scl_i;
      scl_f2 <= scl_f1;

      -- pulsos por defecto a cero
      done_p  <= '0';
      rval_p  <= '0';
      ibiav_p <= '0';
      arb_p   <= '0';

      if rst = '1' or en = '0' then
        st      <= S_IDLE;
        busy_r  <= '0';
        xopen_r <= '0';
        ibirq_r <= '0';
        armed   <= '0';
        srskip  <= '0';
        lost_r  <= '0';
        daahdr  <= '0';
        nackib  <= '0';
        q       <= (others => '0');
        qcnt    <= (others => '0');
        sclo_r  <= '1';
        sclt_r  <= '1';
        sdao_r  <= '1';
        sdat_r  <= '1';
      else

        -- --------------------------------------------------------------
        -- IDLE: SCL conducido alto, deteccion de IBI (caida de SDA con la
        -- linea previamente armada = START de un target)
        -- --------------------------------------------------------------
        if st = S_IDLE then
          sclt_r <= '0';
          sclo_r <= '1';
          if sda_f2 = '1' then
            armed <= '1';
          elsif armed = '1' then
            -- IBI entrante
            st      <= S_IBI_S;
            md      <= M_IBIC;
            od_cur  <= '1';
            q       <= (others => '0');
            qcnt    <= (others => '0');
            busy_r  <= '1';
            xopen_r <= '1';
            armed   <= '0';
            lost_r  <= '0';
          end if;
        end if;

        -- --------------------------------------------------------------
        -- Aceptacion de comando
        -- --------------------------------------------------------------
        if cmd_valid = '1' and busy_r = '0' and
           ((st = S_IDLE and sda_f2 = '1') or st = S_XOPEN or st = S_IBIWAIT) then
          busy_r  <= '1';
          p_stop  <= cmd_stop;
          p_rlast <= cmd_rlast;
          p_wdata <= cmd_wdata;
          lost_r  <= '0';
          daahdr  <= '0';
          nackib  <= '0';
          q       <= (others => '0');
          qcnt    <= (others => '0');

          if st = S_IBIWAIT then
            if cmd_ibiack = '1' then
              st     <= S_ACKDRV;
              od_cur <= '1';
            elsif cmd_ibinak = '1' then
              st     <= S_ACKB;
              od_cur <= '1';
              nackib <= '1';
            else
              -- comando no valido en IBIWAIT: no-op con done
              done_p <= '1';
              busy_r <= '0';
            end if;

          elsif cmd_daa = '1' then
            daahdr <= '1';
            txreg  <= x"FD";              -- 0x7E<<1 | R
            md     <= M_HDR_PP;
            st     <= S_SR_A;
            od_cur <= '1';
            sdat_r <= '0';
            sdao_r <= '1';                -- SDA alto para preparar Sr

          elsif cmd_daadr = '1' then
            md     <= M_DAADR;
            txreg  <= cmd_wdata(7 downto 1) &
                      (not pxor(cmd_wdata(7 downto 1)));
            st     <= S_BITS;
            od_cur <= '0';
            bit_i  <= to_unsigned(7, 6);
            sclo_r <= '0';

          elsif cmd_nobyte = '1' then
            if cmd_stop = '1' then
              st     <= S_STP_A;
              od_cur <= '1';
              sdat_r <= '0';
              sdao_r <= '0';
              sclo_r <= '0';
            else
              done_p <= '1';
              busy_r <= '0';
            end if;

          elsif cmd_read = '1' then
            md     <= M_RD;
            st     <= S_BITS;
            od_cur <= '0';
            bit_i  <= to_unsigned(7, 6);
            sdat_r <= '1';
            sclo_r <= '0';

          else
            -- byte de escritura (header con cmd_start, dato sin el)
            txreg <= cmd_wdata;
            if cmd_start = '1' then
              if st = S_IDLE then
                md      <= M_HDR_OD;
                od_cur  <= '1';
                st      <= S_STA_A;
                sdat_r  <= '0';
                sdao_r  <= '0';           -- START: SDA bajo con SCL alto
                xopen_r <= '1';
              elsif srskip = '1' then
                srskip <= '0';
                md     <= M_HDR_PP;
                od_cur <= '0';
                st     <= S_BITS;
                bit_i  <= to_unsigned(7, 6);
                sclo_r <= '0';
              else
                md     <= M_HDR_PP;
                st     <= S_SR_A;
                od_cur <= '1';
                sdat_r <= '0';
                sdao_r <= '1';            -- SDA alto para preparar Sr
              end if;
            else
              md     <= M_WR;
              od_cur <= '0';
              st     <= S_BITS;
              bit_i  <= to_unsigned(7, 6);
              sclo_r <= '0';
            end if;
          end if;
        end if;

        -- --------------------------------------------------------------
        -- Estados temporizados por cuartos
        -- --------------------------------------------------------------
        timed := (st = S_STA_A) or (st = S_STA_B) or
                 (st = S_SR_A) or (st = S_SR_B) or (st = S_SR_C) or (st = S_SR_D) or
                 (st = S_BITS) or (st = S_ACKB) or (st = S_ACKDRV) or
                 (st = S_TBWR) or (st = S_TBRD) or
                 (st = S_RSEIZE) or (st = S_RSEIZE2) or (st = S_HOLD0) or
                 (st = S_STP_A) or (st = S_STP_B) or (st = S_STP_C) or
                 (st = S_IBI_S);

        if od_cur = '1' then
          div_sel := unsigned(div_od);
        else
          div_sel := unsigned(div_pp);
        end if;

        if timed then
          if qcnt >= div_sel then
            qcnt <= (others => '0');

            case st is

              when S_STA_A =>                       -- SDA bajo, SCL alto, 2 cuartos
                if q = "01" then
                  q      <= "00";
                  st     <= S_STA_B;
                  sclo_r <= '0';
                else
                  q <= q + 1;
                end if;

              when S_STA_B =>                       -- SCL bajo, 1 cuarto
                st    <= S_BITS;
                bit_i <= to_unsigned(7, 6);
                q     <= "00";

              when S_SR_A =>                        -- SDA alto, SCL bajo, 1 cuarto
                st     <= S_SR_B;
                sclo_r <= '1';
                q      <= "00";

              when S_SR_B =>                        -- SCL alto, SDA alto, 2 cuartos
                if q = "01" then
                  q      <= "00";
                  st     <= S_SR_C;
                  sdao_r <= '0';                    -- caida de SDA = Sr
                else
                  q <= q + 1;
                end if;

              when S_SR_C =>                        -- SDA bajo, SCL alto, 2 cuartos
                if q = "01" then
                  q      <= "00";
                  st     <= S_SR_D;
                  sclo_r <= '0';
                else
                  q <= q + 1;
                end if;

              when S_SR_D =>                        -- SCL bajo, 1 cuarto
                st     <= S_BITS;
                bit_i  <= to_unsigned(7, 6);
                q      <= "00";
                od_cur <= '0';                      -- header tras Sr: push-pull

              when S_BITS =>
                case q is
                  when "00" =>                      -- colocar dato (hold de 1 cuarto)
                    case md is
                      when M_HDR_OD =>
                        if lost_r = '0' then
                          if txreg(7) = '1' then
                            sdat_r <= '1';
                          else
                            sdat_r <= '0';
                            sdao_r <= '0';
                          end if;
                        else
                          sdat_r <= '1';
                        end if;
                      when M_HDR_PP | M_WR | M_DAADR =>
                        sdat_r <= '0';
                        sdao_r <= txreg(7);
                      when others =>                -- M_RD, M_DAA64, M_IBIC
                        sdat_r <= '1';
                    end case;
                    q <= "01";

                  when "01" =>
                    sclo_r <= '1';
                    q      <= "10";

                  when "10" =>
                    q <= "11";

                  when others =>                    -- "11": muestreo y avance
                    b := sda_f2;
                    sclo_r <= '0';
                    shreg  <= shreg(6 downto 0) & b;
                    if md = M_HDR_OD and lost_r = '0' and
                       txreg(7) = '1' and b = '0' then
                      lost_r <= '1';
                      sdat_r <= '1';
                    end if;
                    txreg <= txreg(6 downto 0) & '0';
                    if md = M_DAA64 and bit_i(2 downto 0) = "000" then
                      rval_p  <= '1';
                      rdata_r <= shreg(6 downto 0) & b;
                    end if;

                    if bit_i = 0 then
                      q <= "00";
                      case md is
                        when M_WR =>
                          st <= S_TBWR;
                        when M_RD =>
                          rval_p  <= '1';
                          rdata_r <= shreg(6 downto 0) & b;
                          st      <= S_TBRD;
                        when M_DAA64 =>
                          done_p <= '1';
                          busy_r <= '0';
                          st     <= S_XOPEN;
                        when M_IBIC =>
                          ibiad_r <= shreg(6 downto 0) & b;
                          ibiav_p <= '1';
                          ibirq_r <= '1';
                          busy_r  <= '0';
                          st      <= S_IBIWAIT;
                        when M_HDR_OD =>
                          if lost_r = '1' then
                            ibiad_r <= shreg(6 downto 0) & b;
                            ibiav_p <= '1';
                            arb_p   <= '1';
                            ibirq_r <= '1';
                            done_p  <= '1';
                            busy_r  <= '0';
                            st      <= S_IBIWAIT;
                          else
                            st     <= S_ACKB;
                            od_cur <= '1';
                            sdat_r <= '1';          -- handoff: el target conduce el ACK
                          end if;
                        when others =>              -- M_HDR_PP, M_DAADR
                          st     <= S_ACKB;
                          od_cur <= '1';
                          sdat_r <= '1';            -- handoff: el target conduce el ACK
                      end case;
                    else
                      bit_i <= bit_i - 1;
                      q     <= "00";
                    end if;
                end case;

              when S_ACKB =>                        -- 9no bit muestreado (OD)
                case q is
                  when "00" =>
                    sdat_r <= '1';                  -- liberar SDA
                    q <= "01";
                  when "01" =>
                    sclo_r <= '1';
                    q <= "10";
                  when "10" =>
                    q <= "11";
                  when others =>
                    b := sda_f2;
                    ack_r  <= b;
                    sclo_r <= '0';
                    q      <= "00";
                    if daahdr = '1' then
                      if b = '0' then
                        md     <= M_DAA64;
                        bit_i  <= to_unsigned(63, 6);
                        st     <= S_BITS;
                        od_cur <= '1';
                      else
                        daahdr <= '0';
                        done_p <= '1';
                        busy_r <= '0';
                        st     <= S_XOPEN;
                      end if;
                    elsif nackib = '1' then
                      nackib  <= '0';
                      ibirq_r <= '0';
                      if p_stop = '1' then
                        st     <= S_STP_A;
                        od_cur <= '1';
                        sdat_r <= '0';
                        sdao_r <= '0';
                      else
                        done_p <= '1';
                        busy_r <= '0';
                        st     <= S_XOPEN;
                      end if;
                    else
                      if p_stop = '1' then
                        st     <= S_STP_A;
                        od_cur <= '1';
                        sdat_r <= '0';
                        sdao_r <= '0';
                      else
                        done_p <= '1';
                        busy_r <= '0';
                        st     <= S_XOPEN;
                      end if;
                    end if;
                end case;

              when S_ACKDRV =>                      -- ACK del IBI conducido bajo
                case q is
                  when "00" =>
                    sdat_r <= '0';
                    sdao_r <= '0';
                    q <= "01";
                  when "01" =>
                    sclo_r <= '1';
                    q <= "10";
                  when "10" =>
                    q <= "11";
                  when others =>
                    sclo_r  <= '0';
                    sdat_r  <= '1';
                    ibirq_r <= '0';
                    done_p  <= '1';
                    busy_r  <= '0';
                    st      <= S_XOPEN;
                    q       <= "00";
                end case;

              when S_TBWR =>                        -- T = paridad impar (PP)
                case q is
                  when "00" =>
                    sdat_r <= '0';
                    sdao_r <= not pxor(p_wdata);
                    q <= "01";
                  when "01" =>
                    sclo_r <= '1';
                    q <= "10";
                  when "10" =>
                    q <= "11";
                  when others =>
                    sclo_r <= '0';
                    q      <= "00";
                    if p_stop = '1' then
                      st     <= S_STP_A;
                      od_cur <= '1';
                      sdat_r <= '0';
                      sdao_r <= '0';
                    else
                      -- la paridad queda conducida durante el aparcado
                      done_p <= '1';
                      busy_r <= '0';
                      st     <= S_XOPEN;
                    end if;
                end case;

              when S_TBRD =>                        -- T del target en lectura
                case q is
                  when "00" =>
                    q <= "01";                      -- SDA ya liberado
                  when "01" =>
                    sclo_r <= '1';
                    q <= "10";
                  when "10" =>
                    b := sda_f2;                    -- muestreo temprano del T
                    tbit_r <= b;
                    if p_rlast = '1' and b = '1' then
                      sdat_r <= '0';                -- apoderarse: Sr durante T alto
                      sdao_r <= '0';
                    end if;
                    q <= "11";
                  when others =>
                    q <= "00";
                    if tbit_r = '0' then
                      sclo_r <= '0';
                      sdat_r <= '0';                -- retener SDA bajo tras T=0
                      sdao_r <= '0';
                      st     <= S_HOLD0;
                      od_cur <= '1';
                    elsif p_rlast = '1' then
                      st     <= S_RSEIZE;           -- SCL sigue alto, SDA bajo (Sr)
                      od_cur <= '1';
                    else
                      sclo_r <= '0';
                      done_p <= '1';
                      busy_r <= '0';
                      st     <= S_XOPEN;
                    end if;
                end case;

              when S_RSEIZE =>                      -- Sr hecho durante T; 2 cuartos
                if q = "01" then
                  q <= "00";
                  if p_stop = '1' then
                    sdat_r <= '1';                  -- subida con SCL alto = STOP
                    st     <= S_STP_C;
                  else
                    sclo_r <= '0';
                    st     <= S_RSEIZE2;
                  end if;
                else
                  q <= q + 1;
                end if;

              when S_RSEIZE2 =>                     -- SCL bajo tras el Sr
                srskip <= '1';
                done_p <= '1';
                busy_r <= '0';
                st     <= S_XOPEN;
                q      <= "00";

              when S_HOLD0 =>                       -- tras T=0: SDA retenido bajo
                q <= "00";
                if p_stop = '1' then
                  st <= S_STP_A;
                else
                  done_p <= '1';
                  busy_r <= '0';
                  st     <= S_XOPEN;
                end if;

              when S_STP_A =>                       -- SDA bajo, SCL bajo, 1 cuarto
                st <= S_STP_B;
                sclo_r <= '1';
                q <= "00";

              when S_STP_B =>                       -- SCL alto, SDA bajo, 2 cuartos
                if q = "01" then
                  q      <= "00";
                  st     <= S_STP_C;
                  sdat_r <= '1';                    -- subida de SDA = STOP
                else
                  q <= q + 1;
                end if;

              when S_STP_C =>                       -- bus libre, 2 cuartos
                if q = "01" then
                  q       <= "00";
                  st      <= S_IDLE;
                  done_p  <= '1';
                  busy_r  <= '0';
                  xopen_r <= '0';
                  srskip  <= '0';
                  armed   <= '0';
                else
                  q <= q + 1;
                end if;

              when S_IBI_S =>                       -- tCAS tras START de target
                if q = "01" then
                  q      <= "00";
                  st     <= S_BITS;
                  bit_i  <= to_unsigned(7, 6);
                  sclo_r <= '0';
                else
                  q <= q + 1;
                end if;

              when others =>
                null;
            end case;

          else
            qcnt <= qcnt + 1;
          end if;
        end if;

      end if;
    end if;
  end process;

end architecture rtl;
