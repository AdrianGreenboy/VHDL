from iss_ptp_tx import build_sync, full_frame_with_fcs, crc32_eth

# leer TS insertado por el RTL
ts = [int(x) for x in open("tx_sync_ts.txt").read().split()]
TS_SEC, TS_NS = ts[0], ts[1]
print(f"TS insertado por RTL: sec={TS_SEC} ns={TS_NS}")

# reensamblar la trama del stream MII
nibs = [int(x) for x in open("tx_sync_stream.txt").read().split()]
i = 0
while i < len(nibs) and nibs[i] == 5: i += 1
assert nibs[i] == 0xD, "SFD no hallado"
i += 1
pn = nibs[i:]
data = bytearray()
for k in range(0, len(pn)-1, 2):
    data.append((pn[k+1] << 4) | pn[k])
print(f"bytes reensamblados: {len(data)}")
print("hex:", data.hex())

# construir la trama esperada con el MISMO TS que el RTL uso
CLOCK_ID=0x0011223344556677; PORT_NUM=0x0001; SRC_MAC=0x02DECAFBADED; SEQ=0x0000
t = build_sync(CLOCK_ID, PORT_NUM, SRC_MAC, SEQ, TS_SEC, TS_NS)
expected = full_frame_with_fcs(t)
print("esperado:", expected.hex())

assert len(data) == len(expected), f"long difiere: {len(data)} vs {len(expected)}"
if bytes(data) == bytes(expected):
    print("=== PTP_TX Sync: TRAMA BIT-IDENTICA (plantilla+parcheo+originTS+FCS) — PASS ===")
else:
    # localizar primer byte que difiere
    for j in range(len(data)):
        if data[j] != expected[j]:
            print(f"DIFIERE en byte {j}: rtl={data[j]:#x} esperado={expected[j]:#x}")
            break
    raise SystemExit("FALLO")
