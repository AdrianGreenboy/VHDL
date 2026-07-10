-- ============================================================================
-- can_engine.vhd : nucleo CAN 2.0B (base + extendida, data + remote)
-- ----------------------------------------------------------------------------
-- * Temporizacion de bit programable: quantum = (brp+1) ciclos de clk,
--   bit = 1 (sync) + (tseg1+1) + (tseg2+1) cuantos, muestreo al final de TSEG1.
--   Hard sync en IDLE/SUSPEND, resincronizacion limitada por SJW (una por bit).
-- * TX con auto-reintento: tx_req latchea la peticion (pend) hasta tx_done o
--   tx_abort. Perdida de arbitraje: el nucleo pasa a receptor y reintenta.
-- * Stuffing/destuffing SOF..CRC, CRC-15 (poli 0x4599), ACK, EOF, intermision,
--   suspension (nodo pasivo tras transmitir), tramas de error activas/pasivas,
--   tramas de overload, TEC/REC con estados activo/pasivo/bus-off y
--   recuperacion automatica de bus-off (128 x 11 bits recesivos).
-- * Simplificaciones documentadas: excepciones de TEC secundarias (stuff error
--   en arbitraje, dominante tras flag propio, >13 dominantes) no implementadas;
--   dominante durante un delimitador reinicia la espera de recesivo.
-- '1' = recesivo, '0' = dominante.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity can_engine is
  port (
    clk         : in  std_logic;
    rstn        : in  std_logic;
    -- temporizacion de bit
    brp         : in  std_logic_vector(7 downto 0);
    tseg1       : in  std_logic_vector(3 downto 0);
    tseg2       : in  std_logic_vector(2 downto 0);
    sjw         : in  std_logic_vector(1 downto 0);
    -- ACK libre (self-ack, NO conforme): con '1' el transmisor da por
    -- valida la ranura de ACK recesiva (deputacion sin segundo nodo)
    ack_free    : in  std_logic := '0';
    -- peticion de transmision
    tx_req      : in  std_logic;
    tx_abort    : in  std_logic;
    tx_id       : in  std_logic_vector(28 downto 0);
    tx_ide      : in  std_logic;
    tx_rtr      : in  std_logic;
    tx_dlc      : in  std_logic_vector(3 downto 0);
    tx_data     : in  std_logic_vector(63 downto 0); -- byte0 en [63:56]
    tx_busy     : out std_logic;
    tx_done     : out std_logic;   -- pulso: trama propia transmitida con exito
    tx_arb_lost : out std_logic;   -- pulso informativo (reintento automatico)
    tx_err      : out std_logic;   -- pulso: error durante transmision propia
    -- recepcion
    rx_valid    : out std_logic;   -- pulso: trama ajena valida
    rx_id       : out std_logic_vector(28 downto 0);
    rx_ide      : out std_logic;
    rx_rtr      : out std_logic;
    rx_dlc      : out std_logic_vector(3 downto 0);
    rx_data     : out std_logic_vector(63 downto 0); -- byte0 en [63:56]
    -- maquina de errores
    tec         : out std_logic_vector(8 downto 0);
    rec         : out std_logic_vector(7 downto 0);
    err_state   : out std_logic_vector(1 downto 0); -- 00 activo 01 pasivo 10 busoff
    err_pulse   : out std_logic;
    -- bus
    can_rx      : in  std_logic;
    can_tx      : out std_logic );
end entity;

architecture rtl of can_engine is

  type st_t is (S_BUSOFF, S_IDLE, S_SOF, S_IDA, S_SRTR, S_IDE, S_IDB, S_ERTR,
                S_R1, S_R0, S_DLC, S_DATA, S_CRC, S_CRCDEL, S_ACK, S_ACKDEL,
                S_EOF, S_INTER, S_SUSP,
                S_EFLAGA, S_EFLAGP, S_EWAIT, S_EDEL,
                S_OFLAG, S_OWAIT, S_ODEL);

  -- campos sujetos a stuffing (SOF se trata aparte)
  function stuffed(s : st_t) return boolean is
  begin
    case s is
      when S_IDA | S_SRTR | S_IDE | S_IDB | S_ERTR | S_R1 | S_R0
         | S_DLC | S_DATA | S_CRC => return true;
      when others => return false;
    end case;
  end function;

  -- campos que alimentan el CRC (SOF se alimenta aparte)
  function crcfeed(s : st_t) return boolean is
  begin
    case s is
      when S_IDA | S_SRTR | S_IDE | S_IDB | S_ERTR | S_R1 | S_R0
         | S_DLC | S_DATA => return true;
      when others => return false;
    end case;
  end function;

  -- campo de arbitraje (recesivo propio + dominante muestreado = arb perdido)
  function arbst(s : st_t) return boolean is
  begin
    case s is
      when S_IDA | S_SRTR | S_IDE | S_IDB | S_ERTR => return true;
      when others => return false;
    end case;
  end function;

  signal rxq1, rxq2 : std_logic := '1';

begin

  sync_p : process(clk)
  begin
    if rising_edge(clk) then
      rxq1 <= can_rx;
      rxq2 <= rxq1;
    end if;
  end process;

  main_p : process(clk)
    -- temporizacion
    variable v_q      : integer range 0 to 255 := 0;
    variable v_sc     : integer range 0 to 63  := 0;
    variable v_ts1n   : integer range 1 to 16;
    variable v_ntqn   : integer range 3 to 25;
    variable v_sjwn   : integer range 1 to 4;
    variable v_ts1e   : integer range 1 to 20 := 13;
    variable v_ntqe   : integer range 3 to 25 := 20;
    variable v_resd   : boolean := false;
    variable v_rxp    : std_logic := '1';
    variable fedge    : boolean;
    variable hsync    : boolean;
    variable v_sample : boolean;
    variable v_bstart : boolean;
    variable rxb      : std_logic;
    -- FSM de trama
    variable st       : st_t := S_IDLE;
    variable v_istx   : std_logic := '0';
    variable cnt      : integer range 0 to 127 := 0;
    variable run      : integer range 0 to 7 := 0;
    variable lastb    : std_logic := '1';
    variable crc      : std_logic_vector(14 downto 0) := (others => '0');
    variable crch     : std_logic_vector(14 downto 0) := (others => '0');
    variable ida      : std_logic_vector(10 downto 0) := (others => '0');
    variable idb      : std_logic_vector(17 downto 0) := (others => '0');
    variable srtr     : std_logic := '1';
    variable idev     : std_logic := '0';
    variable rtrv     : std_logic := '0';
    variable dlcv     : std_logic_vector(3 downto 0) := (others => '0');
    variable nbits    : integer range 0 to 64 := 0;
    variable dsr      : std_logic_vector(63 downto 0) := (others => '0');
    variable crcr     : std_logic_vector(14 downto 0) := (others => '0');
    variable crcok    : boolean := false;
    variable ackdrv   : std_logic := '0';
    variable gotack   : boolean := false;
    variable wastx    : boolean := false;
    variable pcl      : std_logic := '1';
    variable pcn      : integer range 0 to 7 := 0;
    variable ovln     : integer range 0 to 3 := 0;
    -- transmision
    variable pend     : std_logic := '0';
    variable lid      : std_logic_vector(28 downto 0) := (others => '0');
    variable lide     : std_logic := '0';
    variable lrtr     : std_logic := '0';
    variable ldlc     : std_logic_vector(3 downto 0) := (others => '0');
    variable ldat     : std_logic_vector(63 downto 0) := (others => '0');
    variable tds      : std_logic_vector(63 downto 0) := (others => '0');
    variable txn      : std_logic := '1';
    variable txr      : std_logic := '1';
    -- errores
    variable tecv     : integer range 0 to 300 := 0;
    variable recv     : integer range 0 to 255 := 0;
    variable passv    : boolean := false;
    variable b11      : integer range 0 to 15 := 0;
    variable bseq     : integer range 0 to 255 := 0;
    -- pulsos
    variable p_done, p_arb, p_txe, p_err_v, p_rxv : std_logic;
    variable skip     : boolean;
    variable n        : integer;

    procedure crc_step(b : std_logic) is
      variable inv : std_logic;
    begin
      inv := b xor crc(14);
      crc := crc(13 downto 0) & '0';
      if inv = '1' then
        crc := crc xor "100010110011001"; -- 0x4599
      end if;
    end procedure;

    procedure upd_state is
    begin
      passv := (tecv > 127) or (recv > 127);
    end procedure;

    procedure attempt_init is
    begin
      tds    := ldat;
      gotack := false;
      wastx  := true;
    end procedure;

    -- error detectado en el bit muestreado; el flag arranca en el bit siguiente
    procedure p_err(txe : boolean; acke : boolean) is
    begin
      p_err_v := '1';
      if txe then
        p_txe := '1';
        if not (acke and passv) then
          tecv := tecv + 8;
          if tecv > 256 then
            tecv := 256;
          end if;
        end if;
        v_istx := '0';
      else
        if recv < 255 then
          recv := recv + 1;
        end if;
      end if;
      upd_state;
      if tecv > 255 then
        st   := S_BUSOFF;
        b11  := 0;
        bseq := 0;
      elsif passv then
        st  := S_EFLAGP;
        pcn := 0;
      else
        st  := S_EFLAGA;
        cnt := 0;
      end if;
    end procedure;

    -- el bit muestreado es un SOF: iniciar trama (decodifica desde S_IDA)
    procedure p_sofbit(jointx : boolean) is
    begin
      crc := (others => '0');
      crc_step('0');
      run   := 1;
      lastb := '0';
      ovln  := 0;
      dsr   := (others => '0');
      st    := S_IDA;
      cnt   := 10;
      if jointx then
        v_istx := '1';
        attempt_init;
      else
        v_istx := '0';
      end if;
    end procedure;

    procedure p_ovl is
    begin
      if ovln < 2 then
        ovln := ovln + 1;
        st   := S_OFLAG;
        cnt  := 0;
      else
        p_err(false, false);
      end if;
    end procedure;

    -- seleccion del proximo bit a transmitir (estado ya avanzado)
    procedure p_txsel is
    begin
      txn := '1';
      case st is
        when S_EFLAGA | S_OFLAG =>
          txn := '0';
        when S_ACK =>
          if ackdrv = '1' then
            txn := '0';
          end if;
        when S_IDA | S_SRTR | S_IDE | S_IDB | S_ERTR | S_R1 | S_R0
           | S_DLC | S_DATA | S_CRC | S_CRCDEL =>
          if v_istx = '1' then
            if run = 5 and stuffed(st) then
              txn := not lastb;
            else
              case st is
                when S_IDA =>
                  if lide = '1' then
                    txn := lid(18 + cnt);
                  else
                    txn := lid(cnt);
                  end if;
                when S_SRTR =>
                  if lide = '1' then
                    txn := '1';
                  else
                    txn := lrtr;
                  end if;
                when S_IDE  => txn := lide;
                when S_IDB  => txn := lid(cnt);
                when S_ERTR => txn := lrtr;
                when S_R1 | S_R0 => txn := '0';
                when S_DLC  => txn := ldlc(cnt);
                when S_DATA => txn := tds(63);
                when S_CRC  => txn := crch(cnt);
                when others => txn := '1';
              end case;
            end if;
          end if;
        when others =>
          txn := '1';
      end case;
    end procedure;

  begin
    if rising_edge(clk) then
      if rstn = '0' then
        v_q := 0; v_sc := 0; v_resd := false; v_rxp := '1';
        v_ts1e := 13; v_ntqe := 20;
        st := S_IDLE; v_istx := '0'; cnt := 0; run := 0; lastb := '1';
        pend := '0'; txn := '1'; txr := '1';
        tecv := 0; recv := 0; passv := false; b11 := 0; bseq := 0;
        ackdrv := '0'; wastx := false; ovln := 0; gotack := false;
        can_tx <= '1'; tx_busy <= '0'; tx_done <= '0'; tx_arb_lost <= '0';
        tx_err <= '0'; rx_valid <= '0'; err_pulse <= '0';
        rx_id <= (others => '0'); rx_ide <= '0'; rx_rtr <= '0';
        rx_dlc <= (others => '0'); rx_data <= (others => '0');
        tec <= (others => '0'); rec <= (others => '0'); err_state <= "00";
      else
        -- valores nominales de temporizacion
        v_ts1n := to_integer(unsigned(tseg1)) + 1;
        v_ntqn := 1 + v_ts1n + to_integer(unsigned(tseg2)) + 1;
        v_sjwn := to_integer(unsigned(sjw)) + 1;

        p_done := '0'; p_arb := '0'; p_txe := '0'; p_err_v := '0'; p_rxv := '0';
        v_sample := false; v_bstart := false;

        -- latch de peticion
        if tx_req = '1' and pend = '0' then
          pend := '1';
          lid  := tx_id; lide := tx_ide; lrtr := tx_rtr;
          ldlc := tx_dlc; ldat := tx_data;
        end if;
        if tx_abort = '1' then
          pend := '0';
        end if;

        -- deteccion de flanco recesivo -> dominante
        fedge := (v_rxp = '1') and (rxq2 = '0');
        v_rxp := rxq2;

        -- hard sync (IDLE / SUSPEND) sobre flanco ajeno
        hsync := false;
        if fedge and txr = '1' and (st = S_IDLE or st = S_SUSP) then
          hsync := true;
          v_q := 0; v_sc := 0; v_resd := false;
          v_ts1e := v_ts1n; v_ntqe := v_ntqn;
          if st = S_IDLE then
            st := S_SOF;
            if pend = '1' then
              v_istx := '1';
              attempt_init;
              txr := '0'; -- conducir el resto del SOF
            else
              v_istx := '0';
            end if;
          else
            st := S_SOF;
            v_istx := '0';
          end if;
        elsif fedge and txr = '1' and (not v_resd)
              and st /= S_BUSOFF and st /= S_IDLE and st /= S_SUSP then
          -- resincronizacion (una por bit)
          v_resd := true;
          if v_sc = 0 then
            null; -- flanco en el segmento de sincronizacion
          elsif v_sc <= v_ts1e then
            n := v_sc;
            if n > v_sjwn then
              n := v_sjwn;
            end if;
            v_ts1e := v_ts1e + n;
          else
            if (v_ntqe - 1 - v_sc) <= v_sjwn then
              v_ntqe := v_sc + 1; -- terminar el bit en el proximo cuanto
            else
              v_ntqe := v_ntqe - v_sjwn;
            end if;
          end if;
        end if;

        -- avance del prescaler / cuantos (se salta el clk del hard sync)
        if not hsync then
          if v_q = to_integer(unsigned(brp)) then
            v_q := 0;
            if v_sc = v_ts1e then
              v_sample := true;
              v_sc := v_sc + 1;
            elsif v_sc >= v_ntqe - 1 then
              v_sc := 0;
              v_bstart := true;
            else
              v_sc := v_sc + 1;
            end if;
          else
            v_q := v_q + 1;
          end if;
        end if;

        -- ------------------------------------------------------------------
        -- procesamiento en el punto de muestreo
        -- ------------------------------------------------------------------
        if v_sample then
          rxb := rxq2;
          case st is
            when S_BUSOFF =>
              if rxb = '1' then
                b11 := b11 + 1;
                if b11 = 11 then
                  b11 := 0;
                  bseq := bseq + 1;
                  if bseq = 128 then
                    tecv := 0; recv := 0;
                    upd_state;
                    st := S_IDLE;
                    wastx := false;
                  end if;
                end if;
              else
                b11 := 0;
              end if;

            when S_IDLE =>
              if rxb = '0' then
                -- respaldo (el hard sync es la via normal)
                p_sofbit(pend = '1');
              end if;

            when S_SOF =>
              if rxb = '0' then
                crc := (others => '0');
                crc_step('0');
                run := 1; lastb := '0'; ovln := 0;
                dsr := (others => '0');
                st := S_IDA; cnt := 10;
              else
                if v_istx = '1' then
                  p_err(true, false);
                else
                  st := S_IDLE;
                end if;
              end if;

            when S_EFLAGA =>
              if rxb = '0' then
                cnt := cnt + 1;
                if cnt = 6 then
                  st := S_EWAIT;
                end if;
              else
                cnt := 0; -- flag corrompido: reiniciar
              end if;

            when S_EFLAGP =>
              if pcn = 0 then
                pcl := rxb; pcn := 1;
              elsif rxb = pcl then
                pcn := pcn + 1;
                if pcn = 6 then
                  st := S_EWAIT;
                end if;
              else
                pcl := rxb; pcn := 1;
              end if;

            when S_EWAIT =>
              if rxb = '1' then
                cnt := 7;
                st := S_EDEL;
              end if;

            when S_EDEL =>
              if rxb = '0' then
                st := S_EWAIT;
              else
                cnt := cnt - 1;
                if cnt = 0 then
                  st := S_INTER; cnt := 0; ovln := 0;
                end if;
              end if;

            when S_OFLAG =>
              if rxb = '0' then
                cnt := cnt + 1;
                if cnt = 6 then
                  st := S_OWAIT;
                end if;
              else
                cnt := 0;
              end if;

            when S_OWAIT =>
              if rxb = '1' then
                cnt := 7;
                st := S_ODEL;
              end if;

            when S_ODEL =>
              if rxb = '0' then
                st := S_OWAIT;
              else
                cnt := cnt - 1;
                if cnt = 0 then
                  st := S_INTER; cnt := 0;
                end if;
              end if;

            when S_INTER =>
              if rxb = '0' then
                if cnt >= 2 then
                  -- tercer bit dominante = SOF
                  p_sofbit((pend = '1') and not (passv and wastx));
                else
                  p_ovl;
                end if;
              else
                cnt := cnt + 1;
                if cnt = 3 then
                  if passv and wastx then
                    st := S_SUSP; cnt := 0;
                  else
                    st := S_IDLE;
                  end if;
                  wastx := false;
                end if;
              end if;

            when S_SUSP =>
              if rxb = '0' then
                p_sofbit(false);
              else
                cnt := cnt + 1;
                if cnt = 8 then
                  st := S_IDLE;
                end if;
              end if;

            when others =>
              -- campos de trama: S_IDA .. S_EOF
              skip := false;

              -- 1) bit de stuff esperado
              if stuffed(st) and run = 5 then
                skip := true;
                if rxb = lastb then
                  if v_istx = '1' then
                    p_err(true, false);
                  else
                    p_err(false, false);
                  end if;
                else
                  lastb := rxb;
                  run := 1;
                end if;
              end if;

              -- 2) monitor del transmisor
              if not skip and v_istx = '1' then
                if st = S_ACK then
                  if rxb = '1' then
                    if ack_free = '1' then
                      gotack := true; -- self-ack (no conforme, solo debug)
                    else
                      p_err(true, true); -- error de ACK
                      skip := true;
                    end if;
                  else
                    gotack := true;
                  end if;
                elsif txr /= rxb then
                  if txr = '1' and rxb = '0' and arbst(st) then
                    v_istx := '0';
                    p_arb := '1'; -- arbitraje perdido: continua como receptor
                  else
                    p_err(true, false); -- error de bit
                    skip := true;
                  end if;
                end if;
              end if;

              if not skip then
                -- 3) seguimiento de stuffing
                if stuffed(st) then
                  if rxb = lastb then
                    run := run + 1;
                  else
                    run := 1;
                    lastb := rxb;
                  end if;
                end if;
                -- 4) CRC
                if crcfeed(st) then
                  crc_step(rxb);
                end if;
                -- 5) decodificacion de campo
                case st is
                  when S_IDA =>
                    ida(cnt) := rxb;
                    if cnt = 0 then
                      st := S_SRTR;
                    else
                      cnt := cnt - 1;
                    end if;
                  when S_SRTR =>
                    srtr := rxb;
                    st := S_IDE;
                  when S_IDE =>
                    idev := rxb;
                    if rxb = '1' then
                      st := S_IDB; cnt := 17;
                    else
                      rtrv := srtr;
                      st := S_R0;
                    end if;
                  when S_IDB =>
                    idb(cnt) := rxb;
                    if cnt = 0 then
                      st := S_ERTR;
                    else
                      cnt := cnt - 1;
                    end if;
                  when S_ERTR =>
                    rtrv := rxb;
                    st := S_R1;
                  when S_R1 =>
                    st := S_R0;
                  when S_R0 =>
                    st := S_DLC; cnt := 3;
                  when S_DLC =>
                    dlcv(cnt) := rxb;
                    if cnt = 0 then
                      n := to_integer(unsigned(dlcv));
                      if n > 8 then
                        n := 8;
                      end if;
                      if rtrv = '1' then
                        n := 0;
                      end if;
                      nbits := 8 * n;
                      if nbits = 0 then
                        crch := crc;
                        st := S_CRC; cnt := 14;
                      else
                        st := S_DATA; cnt := nbits;
                      end if;
                    else
                      cnt := cnt - 1;
                    end if;
                  when S_DATA =>
                    dsr := dsr(62 downto 0) & rxb;
                    tds := tds(62 downto 0) & '0';
                    cnt := cnt - 1;
                    if cnt = 0 then
                      crch := crc;
                      st := S_CRC; cnt := 14;
                    end if;
                  when S_CRC =>
                    crcr(cnt) := rxb;
                    if cnt = 0 then
                      crcok := (crcr = crch);
                      st := S_CRCDEL;
                    else
                      cnt := cnt - 1;
                    end if;
                  when S_CRCDEL =>
                    if rxb = '0' then
                      p_err(false, false); -- error de forma
                    else
                      st := S_ACK;
                      if v_istx = '0' and crcok then
                        ackdrv := '1';
                      else
                        ackdrv := '0';
                      end if;
                    end if;
                  when S_ACK =>
                    ackdrv := '0';
                    st := S_ACKDEL;
                  when S_ACKDEL =>
                    if rxb = '0' then
                      p_err(false, false); -- error de forma
                    elsif v_istx = '0' and (not crcok) then
                      p_err(false, false); -- error de CRC
                    else
                      st := S_EOF; cnt := 0;
                    end if;
                  when S_EOF =>
                    if rxb = '0' then
                      if v_istx = '1' then
                        p_err(true, false);
                      elsif cnt = 6 then
                        p_ovl; -- trama ya valida
                      else
                        p_err(false, false);
                      end if;
                    else
                      if v_istx = '0' and cnt = 5 then
                        -- trama ajena valida
                        p_rxv := '1';
                        if idev = '1' then
                          rx_id <= ida & idb;
                        else
                          rx_id <= (28 downto 11 => '0') & ida;
                        end if;
                        rx_ide <= idev;
                        rx_rtr <= rtrv;
                        rx_dlc <= dlcv;
                        rx_data <= std_logic_vector(
                                     shift_left(unsigned(dsr), 64 - nbits));
                        if recv > 127 then
                          recv := 119;
                        elsif recv > 0 then
                          recv := recv - 1;
                        end if;
                        upd_state;
                      end if;
                      if cnt = 6 then
                        if v_istx = '1' then
                          p_done := '1';
                          pend := '0';
                          if tecv > 0 and tecv < 256 then
                            tecv := tecv - 1;
                          end if;
                          upd_state;
                        end if;
                        wastx := (v_istx = '1') or wastx;
                        v_istx := '0';
                        st := S_INTER; cnt := 0;
                      else
                        cnt := cnt + 1;
                      end if;
                    end if;
                  when others =>
                    null;
                end case;
              end if;
          end case;

          -- proximo bit a conducir
          p_txsel;
        end if;

        -- ------------------------------------------------------------------
        -- arranque de bit
        -- ------------------------------------------------------------------
        if v_bstart then
          txr := txn;
          v_resd := false;
          v_ts1e := v_ts1n;
          v_ntqe := v_ntqn;
          if st = S_IDLE and pend = '1' then
            st := S_SOF;
            v_istx := '1';
            attempt_init;
            txr := '0';
          end if;
        end if;

        -- salidas
        can_tx <= txr;
        tx_busy <= pend;
        tx_done <= p_done;
        tx_arb_lost <= p_arb;
        tx_err <= p_txe;
        err_pulse <= p_err_v;
        rx_valid <= p_rxv;
        tec <= std_logic_vector(to_unsigned(tecv, 9));
        rec <= std_logic_vector(to_unsigned(recv, 8));
        if st = S_BUSOFF then
          err_state <= "10";
        elsif passv then
          err_state <= "01";
        else
          err_state <= "00";
        end if;
      end if;
    end if;
  end process;

end architecture;
