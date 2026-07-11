-- ptp_rx.vhd — motor RX-PTP (parser) (IP PTP / IEEE 802.1AS v1)
-- ---------------------------------------------------------------------------
-- Parsea el byte-stream de una trama recibida (interfaz rx_data/rx_valid/
-- rx_last del eth_rx_mii, ya validada por FCS y filtro MAC). Identifica si es
-- gPTP (EtherType 0x88F7 en offset 12), extrae messageType y los campos de
-- interes, y empareja con el timestamp de recepcion capturado en el SFD.
--
-- Contrato de entrada:
--   - rx_valid pulsa 1 clk por cada byte de datos (offset 0 = primer byte dst).
--   - rx_last marca el ultimo byte (sin FCS).
--   - ev_ok pulsa cuando la trama fue aceptada (FCS ok, filtro ok).
--   - rx_ts_sec/ns/valid: timestamp del SFD de ESTA trama (ptp_tstamp RX).
--
-- Salida (sticky, limpiado por rd_ack):
--   - msg_valid: hay un mensaje gPTP parseado disponible.
--   - msg_type: messageType (nibble).
--   - seq_id, src_port_id, origin_sec/ns (Sync), rx_sec/ns (TS de recepcion).
--   - Si la trama no es gPTP o el tipo no se reconoce, NO se afirma msg_valid.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity ptp_rx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- byte-stream de la trama recibida (de eth_rx_mii)
    rx_data    : in  std_logic_vector(7 downto 0);
    rx_valid   : in  std_logic;
    rx_last    : in  std_logic;
    ev_ok      : in  std_logic;
    -- timestamp de recepcion (de ptp_tstamp RX, enganchado a rx_sfd_pulse)
    rx_ts_sec  : in  std_logic_vector(SEC_W-1 downto 0);
    rx_ts_ns   : in  std_logic_vector(NS_W-1 downto 0);
    rx_ts_valid: in  std_logic;
    rx_ts_ack  : out std_logic;
    -- mensaje parseado (sticky)
    msg_valid  : out std_logic;
    msg_type   : out std_logic_vector(3 downto 0);
    seq_id     : out std_logic_vector(15 downto 0);
    src_port_id: out std_logic_vector(79 downto 0);   -- clockIdentity(8)+portNumber(2)
    origin_sec : out std_logic_vector(SEC_W-1 downto 0);
    origin_ns  : out std_logic_vector(NS_W-1 downto 0);
    corr_field : out std_logic_vector(63 downto 0);   -- correctionField
    rx_sec     : out std_logic_vector(SEC_W-1 downto 0);
    rx_ns      : out std_logic_vector(NS_W-1 downto 0);
    rd_ack     : in  std_logic
  );
end entity ptp_rx;

architecture rtl of ptp_rx is
  signal pos      : integer range 0 to 2047 := 0;
  signal is_ptp   : std_logic := '0';   -- EtherType 0x88F7 confirmado
  signal et_hi    : std_logic_vector(7 downto 0) := (others => '0');

  signal mt_r     : std_logic_vector(3 downto 0) := (others => '0');
  signal seq_r    : std_logic_vector(15 downto 0) := (others => '0');
  signal spid_r   : std_logic_vector(79 downto 0) := (others => '0');
  signal osec_r   : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal ons_r    : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal corr_r   : std_logic_vector(63 downto 0) := (others => '0');

  signal rxsec_r  : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal rxns_r   : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal mvalid_r : std_logic := '0';
  signal ack_ts_r : std_logic := '0';

  -- captura del rx_ts asociado a la TRAMA EN CURSO: se toma en cuanto el
  -- ptp_tstamp RX presenta el timestamp del SFD (rx_ts_valid), se consume el
  -- sticky en ese momento (ack), y se guarda hasta el cierre de la trama. Asi
  -- el emparejamiento no depende de que el sticky siga valido al cerrar (que
  -- fallaba en el auto-ping-pong con tramas RX consecutivas).
  signal rxts_sec_w : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal rxts_ns_w  : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal rxts_got   : std_logic := '0';   -- ya capturado para esta trama
begin

  msg_valid   <= mvalid_r;
  msg_type    <= mt_r;
  seq_id      <= seq_r;
  src_port_id <= spid_r;
  origin_sec  <= osec_r;
  origin_ns   <= ons_r;
  corr_field  <= corr_r;
  rx_sec      <= rxsec_r;
  rx_ns       <= rxns_r;
  rx_ts_ack   <= ack_ts_r;

  process(clk)
    variable p : integer;
  begin
    if rising_edge(clk) then
      ack_ts_r <= '0';
      if rst = '1' then
        pos <= 0; is_ptp <= '0'; mvalid_r <= '0';
        mt_r <= (others => '0'); seq_r <= (others => '0');
        spid_r <= (others => '0'); osec_r <= (others => '0');
        ons_r <= (others => '0'); corr_r <= (others => '0');
        rxts_got <= '0';
      else
        if rd_ack = '1' then
          mvalid_r <= '0';
        end if;

        if rx_valid = '1' then
          p := pos;

          -- capturar el rx_ts de ESTA trama en cuanto este disponible, una sola
          -- vez, y consumir el sticky del ptp_tstamp RX en ese momento.
          if rxts_got = '0' and rx_ts_valid = '1' then
            rxts_sec_w <= rx_ts_sec;
            rxts_ns_w  <= rx_ts_ns;
            rxts_got   <= '1';
            ack_ts_r   <= '1';
          end if;

          -- al procesar el primer byte de una trama nueva, invalidar el mensaje
          -- anterior: evita que el consumidor vea msg_valid del mensaje previo
          -- combinado con campos (mtype, rx_ns) ya sobrescribiendose con los de
          -- la trama en curso -> lectura inconsistente del t2 (carrera de ciclo).
          if pos = 0 then
            mvalid_r <= '0';
          end if;

          -- EtherType: bytes 12..13
          if p = OFF_ETH_TYPE then
            et_hi <= rx_data;                       -- 0x88
          elsif p = OFF_ETH_TYPE + 1 then
            if et_hi = x"88" and rx_data = x"F7" then
              is_ptp <= '1';
            else
              is_ptp <= '0';
            end if;
          end if;

          -- messageType: nibble bajo del byte OFF_MSGTYPE (offset 14)
          if p = OFF_MSGTYPE then
            mt_r <= rx_data(3 downto 0);
          end if;

          -- correctionField: bytes OFF_CORR..OFF_CORR+7 (BE)
          if p >= OFF_CORR and p < OFF_CORR + 8 then
            corr_r((7-(p-OFF_CORR))*8+7 downto (7-(p-OFF_CORR))*8) <= rx_data;
          end if;

          -- sourcePortIdentity: bytes OFF_SPID..OFF_SPID+9 (10 bytes, BE)
          if p >= OFF_SPID and p < OFF_SPID + 10 then
            spid_r((9-(p-OFF_SPID))*8+7 downto (9-(p-OFF_SPID))*8) <= rx_data;
          end if;

          -- sequenceId: bytes OFF_SEQID..+1 (BE)
          if p = OFF_SEQID then
            seq_r(15 downto 8) <= rx_data;
          elsif p = OFF_SEQID + 1 then
            seq_r(7 downto 0) <= rx_data;
          end if;

          -- originTimestamp (Sync): secondsField OFF_ORIGIN_TS..+5 (48b BE),
          -- nanosecondsField +6..+9 (32b BE)
          if p >= OFF_ORIGIN_TS and p < OFF_ORIGIN_TS + 6 then
            osec_r((5-(p-OFF_ORIGIN_TS))*8+7 downto (5-(p-OFF_ORIGIN_TS))*8) <= rx_data;
          elsif p >= OFF_ORIGIN_TS + 6 and p < OFF_ORIGIN_TS + 10 then
            ons_r((3-(p-OFF_ORIGIN_TS-6))*8+7 downto (3-(p-OFF_ORIGIN_TS-6))*8) <= rx_data;
          end if;

          -- avanzar / cerrar
          if rx_last = '1' then
            pos <= 0;
            -- al cerrar, si fue PTP valido, emparejar con el TS capturado
            -- durante ESTA trama (no dependemos del sticky al cerrar).
            if is_ptp = '1' then
              rxsec_r  <= rxts_sec_w;
              rxns_r   <= rxts_ns_w;
              mvalid_r <= '1';
            end if;
            is_ptp <= '0';
            rxts_got <= '0';        -- rearmar para la siguiente trama
          else
            pos <= pos + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
