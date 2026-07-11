#!/usr/bin/env python3
# iss_ptp_tx.py — modelo de referencia del motor TX-PTP (Sync).
# Construye la trama Sync esperada byte a byte: plantilla + parcheo de campos
# de registro (src, sourcePortIdentity, sequenceId) + originTimestamp (que en
# HW inserta el override 1-step). Replica ptp_msg_pkg.sync_template y ptp_tx.
# El verificador compara esto contra el stream MII capturado del RTL.

OFF_ETH_SRC = 6
OFF_PDU = 14
OFF_SPID = OFF_PDU + 20
OFF_SEQID = OFF_PDU + 30
OFF_ORIGIN_TS = OFF_PDU + 34
SYNC_FRAME_LEN = OFF_PDU + 44   # 58

def sync_template():
    t = bytearray(SYNC_FRAME_LEN)
    # dst
    t[0:6] = bytes([0x01,0x80,0xC2,0x00,0x00,0x0E])
    # type
    t[12] = 0x88; t[13] = 0xF7
    # PTPv2 header
    t[OFF_PDU+0] = 0x00          # majorSdoId|messageType(Sync)
    t[OFF_PDU+1] = 0x02          # versionPTP=2
    t[OFF_PDU+2] = 0x00; t[OFF_PDU+3] = 0x2C   # messageLength=44
    t[OFF_PDU+32] = 0x00         # controlField
    t[OFF_PDU+33] = 0x00         # logMessageInterval
    return t

def build_sync(clock_id, port_num, src_mac, seq, ts_sec, ts_ns):
    t = sync_template()
    # src (6..11) big-endian
    for i in range(6):
        t[OFF_ETH_SRC+i] = (src_mac >> ((5-i)*8)) & 0xFF
    # sourcePortIdentity clockIdentity (8) big-endian
    for i in range(8):
        t[OFF_SPID+i] = (clock_id >> ((7-i)*8)) & 0xFF
    # portNumber (2) BE
    t[OFF_SPID+8] = (port_num >> 8) & 0xFF
    t[OFF_SPID+9] = port_num & 0xFF
    # sequenceId (2) BE
    t[OFF_SEQID+0] = (seq >> 8) & 0xFF
    t[OFF_SEQID+1] = seq & 0xFF
    # originTimestamp: secondsField (6) BE + nanosecondsField (4) BE
    for i in range(6):
        t[OFF_ORIGIN_TS+i] = (ts_sec >> ((5-i)*8)) & 0xFF
    for i in range(4):
        t[OFF_ORIGIN_TS+6+i] = (ts_ns >> ((3-i)*8)) & 0xFF
    return t

def crc32_eth(data: bytes) -> int:
    crc = 0xFFFFFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xEDB88320 if (crc & 1) else (crc >> 1)
    return crc ^ 0xFFFFFFFF

def full_frame_with_fcs(t):
    # padding a 60 bytes de datos + FCS (4) LE
    data = bytearray(t)
    if len(data) < 60:
        data += bytes(60 - len(data))
    crc = crc32_eth(bytes(data))
    data += bytes([(crc >> (8*b)) & 0xFF for b in range(4)])
    return data

OFF_CORR = OFF_PDU + 8
OFF_REQ_RX_TS = OFF_PDU + 34
OFF_REQ_PORTID = OFF_PDU + 44
PDELAY_FRAME_LEN = OFF_PDU + 54   # 68

def pdelay_base(mtype):
    t = bytearray(PDELAY_FRAME_LEN)
    t[0:6] = bytes([0x01,0x80,0xC2,0x00,0x00,0x0E])
    t[12] = 0x88; t[13] = 0xF7
    t[OFF_PDU+0] = mtype & 0x0F
    t[OFF_PDU+1] = 0x02
    t[OFF_PDU+2] = 0x00; t[OFF_PDU+3] = 0x36   # messageLength=54
    t[OFF_PDU+32] = 0x05   # controlField
    return t

def build_pdelay_req(clock_id, port_num, src_mac, seq, ts_sec, ts_ns):
    t = pdelay_base(0x2)
    for i in range(6): t[OFF_ETH_SRC+i] = (src_mac >> ((5-i)*8)) & 0xFF
    for i in range(8): t[OFF_SPID+i] = (clock_id >> ((7-i)*8)) & 0xFF
    t[OFF_SPID+8] = (port_num >> 8) & 0xFF; t[OFF_SPID+9] = port_num & 0xFF
    t[OFF_SEQID+0] = (seq >> 8) & 0xFF; t[OFF_SEQID+1] = seq & 0xFF
    # originTimestamp (t1) por override
    for i in range(6): t[OFF_ORIGIN_TS+i] = (ts_sec >> ((5-i)*8)) & 0xFF
    for i in range(4): t[OFF_ORIGIN_TS+6+i] = (ts_ns >> ((3-i)*8)) & 0xFF
    return t

def build_pdelay_resp(clock_id, port_num, src_mac, seq, resid_corr,
                      t2_sec, t2_ns, req_portid):
    t = pdelay_base(0x3)
    for i in range(6): t[OFF_ETH_SRC+i] = (src_mac >> ((5-i)*8)) & 0xFF
    for i in range(8): t[OFF_SPID+i] = (clock_id >> ((7-i)*8)) & 0xFF
    t[OFF_SPID+8] = (port_num >> 8) & 0xFF; t[OFF_SPID+9] = port_num & 0xFF
    t[OFF_SEQID+0] = (seq >> 8) & 0xFF; t[OFF_SEQID+1] = seq & 0xFF
    # correctionField (residence t3-t2) por override, big-endian 8B
    for i in range(8): t[OFF_CORR+i] = (resid_corr >> ((7-i)*8)) & 0xFF
    # requestReceiptTimestamp (t2)
    for i in range(6): t[OFF_REQ_RX_TS+i] = (t2_sec >> ((5-i)*8)) & 0xFF
    for i in range(4): t[OFF_REQ_RX_TS+6+i] = (t2_ns >> ((3-i)*8)) & 0xFF
    # requestingPortIdentity (10B)
    for i in range(10): t[OFF_REQ_PORTID+i] = (req_portid >> ((9-i)*8)) & 0xFF
    return t


if __name__ == "__main__":
    # parametros del escenario de TB
    CLOCK_ID = 0x0011223344556677
    PORT_NUM = 0x0001
    SRC_MAC  = 0x02DECAFBADED
    SEQ      = 0x0000
    # timestamp que el TB inyecta en el SFD de la trama (now del reloj - lat)
    TS_SEC   = 0x000000000005
    TS_NS    = 0x00000640        # 1600
    t = build_sync(CLOCK_ID, PORT_NUM, SRC_MAC, SEQ, TS_SEC, TS_NS)
    frame = full_frame_with_fcs(t)
    with open("ref_sync_frame.txt", "w") as f:
        f.write(frame.hex() + "\n")
    print("trama Sync esperada (con FCS):")
    print(frame.hex())
    print(f"longitud: {len(frame)} bytes")
