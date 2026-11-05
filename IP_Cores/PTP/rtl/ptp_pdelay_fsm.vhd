-- ptp_pdelay_fsm.vhd — orquestacion peer-delay (IP PTP / IEEE 802.1AS v1)
-- ---------------------------------------------------------------------------
-- Ata las piezas verificadas en el mecanismo peer-delay completo. Dos
-- sub-maquinas que comparten el motor TX (una a la vez):
--
-- RESPONDEDOR (siempre activo, prioridad):
--   - Al parsear un Pdelay_Req (msg_type=0x2): guarda t2 = rx_ts del parser y
--     el sourcePortIdentity del requester (-> requestingPortIdentity del Resp).
--   - Dispara un Pdelay_Resp por el motor TX. El motor, al emitir el SFD del
--     Resp (t3), calcula el residence t3-t2 y lo mete en el correctionField.
--
-- INICIADOR (arranca por 'start'):
--   - Dispara un Pdelay_Req por el motor. Guarda t1 = ts del SFD del Req.
--   - Espera al parser un Pdelay_Resp (msg_type=0x3): guarda t4 = rx_ts y el
--     correctionField. Dispara ptp_pdelay -> meanPathDelay.
--
-- Arbitraje del motor TX: el orquestador multiplexa 'send'/'sel'/campos hacia
-- el motor. Respondedor y iniciador no envian a la vez (Pdelay es ping-pong);
-- si coinciden, gana el respondedor (obligacion de responder) y el iniciador
-- reintenta. En LOOP_INT el flujo es secuencial y determinista.
--
-- Audit 2026-11 (ALTA: a lost Pdelay_Resp deadlocked the initiator forever):
--   * EVERY wait state is bounded by tmo_cycles (core clocks; 0 = no timeout,
--     legacy). On expiry the sub-machine returns to idle and pd_timeout
--     pulses (sticky in STATUS).
--   * 802.1AS 11.2.19 lostResponses accounting: each initiator exchange that
--     times out waiting for the Pdelay_Resp increments lost_cnt (saturating);
--     a valid matching Resp clears it. as_capable = (lost_cnt <=
--     allowed_lost) (allowedLostResponses, default 3, register PD_CFG).
--     resp_lost pulses on each lost response; when lost_cnt exceeds
--     allowed_lost, the neighbour is reported not-asCapable (STATUS).
--   * a Pdelay_Resp is accepted only if sequenceId == sequenceId of the
--     outstanding Pdelay_Req (tx_seq, exported by ptp_tx) AND
--     requestingPortIdentity == our portIdentity (my_portid). Others are
--     consumed (acked) and ignored, resp_mismatch pulses.
--   * the responder copies the Req sequenceId into the Resp (tx_req_seqid).
--   * Pdelay_Resp_Follow_Up (two-step responders) is NOT supported; the
--     residence time is taken from the 1-step Resp correctionField.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity ptp_pdelay_fsm is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- orden de iniciar un intercambio Pdelay (iniciador)
    start      : in  std_logic;
    busy       : out std_logic;
    -- del parser RX (ptp_rx)
    rx_mvalid  : in  std_logic;
    rx_mtype   : in  std_logic_vector(3 downto 0);
    rx_seqid   : in  std_logic_vector(15 downto 0);
    rx_spid    : in  std_logic_vector(79 downto 0);
    rx_reqpid  : in  std_logic_vector(79 downto 0) := (others => '0'); -- requestingPortIdentity
    rx_corr    : in  std_logic_vector(63 downto 0);
    rx_sec     : in  std_logic_vector(SEC_W-1 downto 0);
    rx_ns      : in  std_logic_vector(NS_W-1 downto 0);
    rx_ack     : out std_logic;                  -- limpia el sticky del parser
    -- al motor TX (arbitrado)
    tx_send    : out std_logic;
    tx_sel     : out msg_sel_t;
    tx_req_rx_sec : out std_logic_vector(SEC_W-1 downto 0);  -- t2 para Resp
    tx_req_rx_ns  : out std_logic_vector(NS_W-1 downto 0);
    tx_req_portid : out std_logic_vector(79 downto 0);       -- reqPortId para Resp
    tx_req_seqid  : out std_logic_vector(15 downto 0);       -- Req seq para Resp
    tx_busy    : in  std_logic;
    tx_done    : in  std_logic;
    tx_ready   : in  std_logic := '1';   -- '1' si el motor puede aceptar trama (serializacion)
    tx_seq     : in  std_logic_vector(15 downto 0) := (others => '0'); -- seq of last sent frame
    -- timestamp del SFD TX (para t1 del Req del iniciador)
    tx_ts_sec  : in  std_logic_vector(SEC_W-1 downto 0);
    tx_ts_ns   : in  std_logic_vector(NS_W-1 downto 0);
    tx_ts_valid: in  std_logic;
    -- identity / policy
    my_portid  : in  std_logic_vector(79 downto 0) := (others => '0');
    chk_resp   : in  std_logic := '1';   -- '1' enforce seq + requestingPortIdentity match
    tmo_cycles : in  unsigned(31 downto 0) := (others => '0');   -- 0 = no timeout
    allowed_lost : in unsigned(7 downto 0) := to_unsigned(3, 8);
    -- a ptp_pdelay (calculo del meanPathDelay)
    pd_calc    : out std_logic;
    pd_t1_sec  : out std_logic_vector(SEC_W-1 downto 0);
    pd_t1_ns   : out std_logic_vector(NS_W-1 downto 0);
    pd_t4_sec  : out std_logic_vector(SEC_W-1 downto 0);
    pd_t4_ns   : out std_logic_vector(NS_W-1 downto 0);
    pd_corr    : out std_logic_vector(63 downto 0);
    -- error reporting
    pd_timeout    : out std_logic;           -- pulse: a wait state expired
    resp_lost     : out std_logic;           -- pulse: initiator lost a Resp
    resp_mismatch : out std_logic;           -- pulse: Resp ignored (seq/port)
    lost_cnt      : out unsigned(7 downto 0);
    as_capable    : out std_logic;
    dbg_ist    : out std_logic_vector(2 downto 0);
    dbg_rstt   : out std_logic_vector(1 downto 0)
  );
end entity ptp_pdelay_fsm;

architecture rtl of ptp_pdelay_fsm is
  type ist_t is (I_IDLE, I_SEND_REQ, I_WAIT_REQ_DONE, I_WAIT_RESP, I_CALC);
  signal ist : ist_t := I_IDLE;
  type rst_t is (R_IDLE, R_SEND_RESP, R_WAIT_DONE);
  signal rstt : rst_t := R_IDLE;

  -- iniciador
  signal t1_sec_r, t4_sec_r : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal t1_ns_r, t4_ns_r   : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal corr_r  : std_logic_vector(63 downto 0) := (others => '0');
  signal my_seq  : std_logic_vector(15 downto 0) := (others => '0');
  signal busy_r  : std_logic := '0';
  signal pd_calc_r : std_logic := '0';
  signal icnt    : unsigned(31 downto 0) := (others => '0');   -- initiator wait timer
  signal lost_r  : unsigned(7 downto 0) := (others => '0');

  -- respondedor
  signal t2_sec_r : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal t2_ns_r  : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal rpid_r   : std_logic_vector(79 downto 0) := (others => '0');
  signal rseq_r   : std_logic_vector(15 downto 0) := (others => '0');
  signal rcnt     : unsigned(31 downto 0) := (others => '0');   -- responder wait timer

  -- arbitraje del motor TX
  signal send_r   : std_logic := '0';
  signal sel_r    : msg_sel_t := SEL_SYNC;
  signal rx_ack_r : std_logic := '0';
  signal tmo_p, lost_p, mism_p : std_logic := '0';

  function expired(c : unsigned(31 downto 0); t : unsigned(31 downto 0)) return boolean is
  begin
    return t /= 0 and c >= t;
  end function;
begin

  busy      <= busy_r;
  rx_ack    <= rx_ack_r;
  tx_send   <= send_r;
  tx_sel    <= sel_r;
  tx_req_rx_sec <= t2_sec_r;
  tx_req_rx_ns  <= t2_ns_r;
  tx_req_portid <= rpid_r;
  tx_req_seqid  <= rseq_r;
  pd_calc   <= pd_calc_r;
  pd_t1_sec <= t1_sec_r;  pd_t1_ns <= t1_ns_r;
  pd_t4_sec <= t4_sec_r;  pd_t4_ns <= t4_ns_r;
  pd_corr   <= corr_r;
  pd_timeout    <= tmo_p;
  resp_lost     <= lost_p;
  resp_mismatch <= mism_p;
  lost_cnt      <= lost_r;
  as_capable    <= '1' when lost_r <= allowed_lost else '0';
  dbg_ist  <= "000" when ist=I_IDLE else "001" when ist=I_SEND_REQ else "010" when ist=I_WAIT_REQ_DONE else "011" when ist=I_WAIT_RESP else "100";
  dbg_rstt <= "00" when rstt=R_IDLE else "01" when rstt=R_SEND_RESP else "10";

  process(clk)
    variable tx_taken : boolean;   -- el respondedor tomo el motor este ciclo
    variable resp_ok  : boolean;
  begin
    if rising_edge(clk) then
      send_r    <= '0';
      rx_ack_r  <= '0';
      pd_calc_r <= '0';
      tmo_p     <= '0';
      lost_p    <= '0';
      mism_p    <= '0';
      tx_taken  := false;
      if rst = '1' then
        ist <= I_IDLE; rstt <= R_IDLE; busy_r <= '0';
        lost_r <= (others => '0');
        icnt <= (others => '0'); rcnt <= (others => '0');
      else

        -- ============ RESPONDEDOR (prioridad sobre iniciador) ============
        case rstt is
          when R_IDLE =>
            rcnt <= (others => '0');
            -- detectar Pdelay_Req entrante
            if rx_mvalid = '1' and rx_mtype = MT_PDELAY_REQ then
              t2_sec_r <= rx_sec;                 -- t2 = SFD RX del Req
              t2_ns_r  <= rx_ns;
              rpid_r   <= rx_spid;                -- sourcePortIdentity del requester
              rseq_r   <= rx_seqid;               -- Resp carries the Req sequenceId
              rx_ack_r <= '1';                    -- consumir el mensaje
              rstt     <= R_SEND_RESP;
            end if;

          when R_SEND_RESP =>
            rcnt <= rcnt + 1;
            -- disparar Resp si el motor esta libre Y listo (trama previa se fue)
            if tx_busy = '0' and tx_ready = '1' then
              send_r   <= '1';
              sel_r    <= SEL_PDELAY_RESP;
              tx_taken := true;
              rcnt     <= (others => '0');
              rstt     <= R_WAIT_DONE;
            elsif expired(rcnt, tmo_cycles) then
              tmo_p <= '1';                       -- engine never freed: drop the Resp
              rstt  <= R_IDLE;
            end if;

          when R_WAIT_DONE =>
            rcnt <= rcnt + 1;
            if tx_done = '1' then
              rstt <= R_IDLE;
            elsif expired(rcnt, tmo_cycles) then
              tmo_p <= '1';
              rstt  <= R_IDLE;
            end if;
        end case;

        -- ============ INICIADOR ============
        case ist is
          when I_IDLE =>
            icnt <= (others => '0');
            if start = '1' then
              busy_r <= '1';
              ist    <= I_SEND_REQ;
            end if;

          when I_SEND_REQ =>
            icnt <= icnt + 1;
            -- enviar Req solo si el motor esta libre y listo, el respondedor no
            -- lo tomo este ciclo (prioridad del respondedor) ni esta ocupado
            if tx_busy = '0' and tx_ready = '1' and rstt = R_IDLE and not tx_taken then
              send_r <= '1';
              sel_r  <= SEL_PDELAY_REQ;
              icnt   <= (others => '0');
              ist    <= I_WAIT_REQ_DONE;
            elsif expired(icnt, tmo_cycles) then
              tmo_p  <= '1';
              busy_r <= '0';
              ist    <= I_IDLE;
            end if;

          when I_WAIT_REQ_DONE =>
            icnt <= icnt + 1;
            -- capturar t1 = SFD TX del Req (llega via tx_ts_valid durante el envio)
            if tx_ts_valid = '1' then
              t1_sec_r <= tx_ts_sec;
              t1_ns_r  <= tx_ts_ns;
            end if;
            if tx_done = '1' then
              my_seq <= tx_seq;                   -- sequenceId of the Req just sent
              icnt   <= (others => '0');          -- Resp timer starts at Req done
              ist    <= I_WAIT_RESP;
            elsif expired(icnt, tmo_cycles) then
              tmo_p  <= '1';
              busy_r <= '0';
              ist    <= I_IDLE;
            end if;

          when I_WAIT_RESP =>
            icnt <= icnt + 1;
            -- esperar el Pdelay_Resp entrante (only the one answering OUR Req)
            resp_ok := (chk_resp = '0') or
                       (rx_seqid = my_seq and rx_reqpid = my_portid);
            if rx_mvalid = '1' and rx_mtype = MT_PDELAY_RESP and rx_ack_r = '0' then
              if resp_ok then
                t4_sec_r <= rx_sec;               -- t4 = SFD RX del Resp
                t4_ns_r  <= rx_ns;
                corr_r   <= rx_corr;              -- residence del respondedor
                rx_ack_r <= '1';
                lost_r   <= (others => '0');      -- valid response: clear lostResponses
                ist      <= I_CALC;
              else
                rx_ack_r <= '1';                  -- consume and ignore
                mism_p   <= '1';
              end if;
            elsif expired(icnt, tmo_cycles) then
              tmo_p  <= '1';
              lost_p <= '1';                      -- 802.1AS: lostResponses++
              if lost_r /= x"FF" then lost_r <= lost_r + 1; end if;
              busy_r <= '0';
              ist    <= I_IDLE;
            end if;

          when I_CALC =>
            pd_calc_r <= '1';                     -- disparar meanPathDelay
            busy_r    <= '0';
            ist       <= I_IDLE;
        end case;

      end if;
    end if;
  end process;

end architecture rtl;
