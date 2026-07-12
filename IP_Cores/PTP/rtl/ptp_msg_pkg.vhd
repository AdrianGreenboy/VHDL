-- ptp_msg_pkg.vhd — formato de mensajes gPTP / IEEE 802.1AS v1
-- ---------------------------------------------------------------------------
-- Layout EXACTO de las tramas gPTP sobre Ethernet. Las plantillas son
-- constantes (ROM) y el HW parchea solo los campos variables. El ISS
-- (iss_ptp_msg.py) replica estas mismas constantes byte a byte.
--
-- Trama = cabecera Ethernet (14) + PDU gPTP.
--   Ethernet: dst(6) 01-80-C2-00-00-0E | src(6) MAC propia | type(2) 0x88F7
--   PDU: cabecera comun PTPv2 (34) + cuerpo por tipo.
--
-- Cabecera comun PTPv2 (offsets RELATIVOS al inicio del PDU, byte 0):
--    0: majorSdoId[7:4] | messageType[3:0]
--    1: minorVersionPTP[7:4] | versionPTP[3:0]   (=0x12: ver 2, minor 1 gPTP? usamos 0x02)
--    2..3: messageLength (BE)
--    4: domainNumber (=0)
--    5: minorSdoId (=0)
--    6..7: flags
--    8..15: correctionField (BE, 8 bytes; ns<<16 fraccion)
--    16..19: messageTypeSpecific (=0)
--    20..29: sourcePortIdentity (clockIdentity[8] portNumber[2])
--    30..31: sequenceId (BE)
--    32: controlField
--    33: logMessageInterval
--   PDU byte 34+: cuerpo especifico.
--
-- Sync (messageType=0x0): cuerpo = originTimestamp (10 bytes):
--    34..39: secondsField (48b BE)
--    40..43: nanosecondsField (32b BE)
--   => PDU total 44 bytes; trama 14+44 = 58 (padding a 60 en el MAC + FCS).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ptp_msg_pkg is

  -- tipos de mensaje (messageType, nibble bajo del byte 0 del PDU)
  constant MT_SYNC        : std_logic_vector(3 downto 0) := x"0";
  constant MT_PDELAY_REQ  : std_logic_vector(3 downto 0) := x"2";
  constant MT_PDELAY_RESP : std_logic_vector(3 downto 0) := x"3";
  constant MT_PDELAY_RFU  : std_logic_vector(3 downto 0) := x"A"; -- Resp_Follow_Up
  constant MT_ANNOUNCE    : std_logic_vector(3 downto 0) := x"B";
  constant MT_FOLLOW_UP   : std_logic_vector(3 downto 0) := x"8";

  -- selector para la FSM unificada del TX-PTP
  type msg_sel_t is (SEL_SYNC, SEL_PDELAY_REQ, SEL_PDELAY_RESP,
                     SEL_PDELAY_RFU, SEL_ANNOUNCE);

  -- Ethernet
  constant ETH_DST : std_logic_vector(47 downto 0) := x"0180C200000E";  -- gPTP multicast
  constant ETH_TYP : std_logic_vector(15 downto 0) := x"88F7";

  -- offsets (relativos al inicio de la TRAMA, byte 0 = primer byte de dst)
  constant OFF_ETH_SRC   : integer := 6;
  constant OFF_ETH_TYPE  : integer := 12;
  constant OFF_PDU       : integer := 14;   -- inicio cabecera PTPv2
  constant OFF_MSGTYPE   : integer := OFF_PDU + 0;
  constant OFF_CORR      : integer := OFF_PDU + 8;   -- correctionField (8)
  constant OFF_SPID      : integer := OFF_PDU + 20;  -- sourcePortIdentity (10)
  constant OFF_SEQID     : integer := OFF_PDU + 30;  -- sequenceId (2)
  constant OFF_ORIGIN_TS : integer := OFF_PDU + 34;  -- originTimestamp (10) [Sync]

  -- Pdelay: cuerpo tras la cabecera (offset OFF_PDU+34).
  -- Pdelay_Req:  originTimestamp(10) + reserved(10)              => PDU 54
  -- Pdelay_Resp: requestReceiptTimestamp(10) + requestingPortId(10) => PDU 54
  constant OFF_REQ_RX_TS : integer := OFF_PDU + 34;  -- requestReceiptTimestamp (10) [Resp]
  constant OFF_REQ_PORTID: integer := OFF_PDU + 44;  -- requestingPortIdentity (10) [Resp]

  -- longitud de trama Sync (sin FCS; el MAC hace padding a 60 + FCS)
  constant SYNC_FRAME_LEN : integer := OFF_PDU + 44;  -- 14 + 44 = 58
  -- Pdelay Req/Resp: PDU 54 => trama 68
  constant PDELAY_FRAME_LEN : integer := OFF_PDU + 54; -- 14 + 54 = 68

  -- versionPTP byte (byte 1 del PDU): versionPTP=2 en nibble bajo
  constant PTP_VERSION_B : std_logic_vector(7 downto 0) := x"02";

  -- tipo del array de plantilla
  type byte_arr is array (natural range <>) of std_logic_vector(7 downto 0);

  -- Plantilla Sync: 58 bytes. Los campos variables van a 0 en la ROM y el HW
  -- los parchea. src, sourcePortIdentity, sequenceId, correctionField y
  -- originTimestamp = 0 en plantilla.
  function sync_template return byte_arr;

  -- Plantilla Pdelay_Req: 68 bytes. messageType=0x2, messageLength=54.
  -- originTimestamp y reserved a 0; src/spid/seqId parcheados por HW.
  function pdelay_req_template return byte_arr;

  -- Plantilla Pdelay_Resp: 68 bytes. messageType=0x3, messageLength=54.
  -- requestReceiptTimestamp(t2) y requestingPortIdentity parcheados por el
  -- motor; correctionField (residence t3-t2) por override 1-step del MAC.
  function pdelay_resp_template return byte_arr;

  -- ================= PLANTILLAS COMO CONSTANTES LITERALES ================
  -- Generadas desde las funciones de referencia (evaluadas con GHDL) y
  -- verificadas bit-identicas contra el oraculo ISS por la regresion.
  -- Motivo: Vivado 2025.2.1 elabora mal constantes inicializadas desde
  -- funciones que construyen arreglos (plantilla Pdelay quedaba en CEROS
  -- en silicio). Literales = cero elaboracion = cero riesgo.
  constant TPL_SYNC_ROM : byte_arr(0 to 57) := (
    x"01", x"80", x"C2", x"00", x"00", x"0E", x"00", x"00", x"00", x"00",
    x"00", x"00", x"88", x"F7", x"00", x"02", x"00", x"2C", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00"
  );
  constant TPL_REQ_ROM : byte_arr(0 to 67) := (
    x"01", x"80", x"C2", x"00", x"00", x"0E", x"00", x"00", x"00", x"00",
    x"00", x"00", x"88", x"F7", x"02", x"02", x"00", x"36", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"05", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00"
  );
  constant TPL_RESP_ROM : byte_arr(0 to 67) := (
    x"01", x"80", x"C2", x"00", x"00", x"0E", x"00", x"00", x"00", x"00",
    x"00", x"00", x"88", x"F7", x"03", x"02", x"00", x"36", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"05", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00"
  );

end package ptp_msg_pkg;

package body ptp_msg_pkg is

  function sync_template return byte_arr is
    variable t : byte_arr(0 to SYNC_FRAME_LEN-1) := (others => x"00");
  begin
    -- Ethernet dst = 01-80-C2-00-00-0E
    t(0) := x"01"; t(1) := x"80"; t(2) := x"C2";
    t(3) := x"00"; t(4) := x"00"; t(5) := x"0E";
    -- src (6..11): parcheado por HW -> 0 en plantilla
    -- EtherType 0x88F7
    t(12) := x"88"; t(13) := x"F7";
    -- ---- cabecera PTPv2 ----
    -- byte0 PDU: majorSdoId(0) | messageType(SYNC=0) = 0x00
    t(OFF_PDU + 0) := x"00";
    -- byte1: minorVersionPTP(0) | versionPTP(2) = 0x02
    t(OFF_PDU + 1) := PTP_VERSION_B;
    -- messageLength (2..3 del PDU) = 44 (0x002C) BE
    t(OFF_PDU + 2) := x"00"; t(OFF_PDU + 3) := x"2C";
    -- domainNumber(4)=0, minorSdoId(5)=0
    -- flags (6..7) = twoStepFlag off (1-step) => 0x0000
    -- correctionField (8..15) = 0 (parcheado si aplica)
    -- messageTypeSpecific (16..19) = 0
    -- sourcePortIdentity (20..29) = 0 (parcheado)
    -- sequenceId (30..31) = 0 (parcheado)
    -- controlField (32): Sync = 0x00
    t(OFF_PDU + 32) := x"00";
    -- logMessageInterval (33): 802.1AS Sync usa 0x00 (rate configurable; v1 fijo)
    t(OFF_PDU + 33) := x"00";
    -- originTimestamp (34..43) = 0 (parcheado desde ptp_tstamp)
    return t;
  end function;

  -- NOTA DE SINTESIS: las plantillas se construyen con asignaciones DIRECTAS
  -- en una sola funcion (estilo sync_template). La version anterior usaba un
  -- helper anidado (pdelay_base) que devolvia un arreglo no restringido;
  -- Vivado 2025.2.1 elaboraba mal esa constante y dejaba la plantilla en
  -- ceros EN SILICIO (GHDL la evaluaba bien): tramas Pdelay con DA=00:...:00,
  -- descartadas por el filtro MAC. No reintroducir el helper.

  function pdelay_req_template return byte_arr is
    variable t : byte_arr(0 to PDELAY_FRAME_LEN-1) := (others => x"00");
  begin
    -- Ethernet
    t(0) := x"01"; t(1) := x"80"; t(2) := x"C2";
    t(3) := x"00"; t(4) := x"00"; t(5) := x"0E";
    t(12) := x"88"; t(13) := x"F7";
    -- PTPv2
    t(OFF_PDU + 0) := x"0" & MT_PDELAY_REQ;         -- majorSdoId(0)|messageType
    t(OFF_PDU + 1) := PTP_VERSION_B;                -- versionPTP=2
    t(OFF_PDU + 2) := x"00"; t(OFF_PDU + 3) := x"36"; -- messageLength=54 (0x36)
    t(OFF_PDU + 32) := x"05";                       -- controlField
    t(OFF_PDU + 33) := x"00";                       -- logMessageInterval
    -- originTimestamp (34..43) y reserved (44..53) = 0
    return t;
  end function;

  function pdelay_resp_template return byte_arr is
    variable t : byte_arr(0 to PDELAY_FRAME_LEN-1) := (others => x"00");
  begin
    -- Ethernet
    t(0) := x"01"; t(1) := x"80"; t(2) := x"C2";
    t(3) := x"00"; t(4) := x"00"; t(5) := x"0E";
    t(12) := x"88"; t(13) := x"F7";
    -- PTPv2
    t(OFF_PDU + 0) := x"0" & MT_PDELAY_RESP;        -- majorSdoId(0)|messageType
    t(OFF_PDU + 1) := PTP_VERSION_B;                -- versionPTP=2
    t(OFF_PDU + 2) := x"00"; t(OFF_PDU + 3) := x"36"; -- messageLength=54 (0x36)
    t(OFF_PDU + 32) := x"05";                       -- controlField
    t(OFF_PDU + 33) := x"00";                       -- logMessageInterval
    -- requestReceiptTimestamp (34..43) = t2 (parcheado por el motor)
    -- requestingPortIdentity (44..53) = spid del Req (parcheado por el motor)
    -- correctionField (22..29) = residence t3-t2 (override 1-step del MAC)
    return t;
  end function;

end package body ptp_msg_pkg;
