#!/usr/bin/env python3
# verify_tx_override.py — verificador INDEPENDIENTE del stream MII capturado.
# 1) reensambla bytes desde los nibbles (nibble bajo primero), saltando
#    preambulo (0x5 x15) + SFD (0xD).
# 2) comprueba que la ventana de override quedo parcheada (bytes 8,9 = 0x55,0x66).
# 3) valida el FCS: CRC-32 Ethernet reflejado (init 0xFFFFFFFF, xorout final)
#    sobre los bytes de datos; el FCS transmitido debe cumplir el residuo.
# CRC implementado de forma INDEPENDIENTE del RTL (bit a bit, no por nibble).

def crc32_eth(data: bytes) -> int:
    crc = 0xFFFFFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
    return crc ^ 0xFFFFFFFF

def main():
    nibs = [int(x) for x in open("tx_stream.txt").read().split()]
    # saltar preambulo + SFD: buscar el nibble 0xD (13) que cierra el preambulo
    i = 0
    while i < len(nibs) and nibs[i] == 5:
        i += 1
    assert i < len(nibs) and nibs[i] == 0xD, f"SFD no encontrado en pos {i}"
    i += 1  # saltar el 0xD
    payload_nibs = nibs[i:]
    # reensamblar bytes: nibble bajo primero
    assert len(payload_nibs) % 2 == 0, "nibbles impares"
    data = bytearray()
    for k in range(0, len(payload_nibs), 2):
        lo = payload_nibs[k]
        hi = payload_nibs[k+1]
        data.append((hi << 4) | lo)
    print(f"bytes reensamblados: {len(data)}")
    print("hex:", data.hex())

    # el motor hace padding a 60 bytes de DATOS + 4 de FCS = 64 total
    assert len(data) == 64, f"esperaba 64 bytes (60 datos+4 FCS), hay {len(data)}"
    frame_data = data[:60]   # datos con padding
    fcs_rx = data[60:64]     # 4 bytes de FCS, byte bajo primero

    # 2) comprobar override en bytes 8,9
    assert frame_data[8] == 0x55, f"byte8 override falla: {frame_data[8]:#x}"
    assert frame_data[9] == 0x66, f"byte9 override falla: {frame_data[9]:#x}"
    print(f"OVERRIDE OK: bytes[8:10] = {frame_data[8]:#x} {frame_data[9]:#x}")

    # 3) validar FCS: CRC sobre los 60 bytes de datos, comparar con el FCS tx.
    # El MAC transmite FCS = ~crc, byte bajo primero, nibble bajo primero. El
    # CRC del estandar Ethernet: crc32_eth(data) da el valor que va en el FCS
    # (ya con xorout). Se transmite en little-endian de bytes.
    crc_calc = crc32_eth(bytes(frame_data))
    fcs_calc = bytes([(crc_calc >> (8*b)) & 0xFF for b in range(4)])  # LE
    print(f"FCS rx    = {fcs_rx.hex()}")
    print(f"FCS calc  = {fcs_calc.hex()}")
    assert bytes(fcs_rx) == fcs_calc, "FCS NO cubre los bytes parcheados!"
    print("FCS OK: el CRC cubre correctamente los bytes PARCHEADOS")

    # verificacion cruzada: residuo canonico sobre datos+FCS debe dar la
    # constante magica 0x2144DF1C (o el residuo 0xDEBB20E3 sin xorout)
    crc_check = 0xFFFFFFFF
    for byte in bytes(frame_data) + bytes(fcs_rx):
        crc_check ^= byte
        for _ in range(8):
            crc_check = (crc_check >> 1) ^ 0xEDB88320 if (crc_check & 1) else (crc_check >> 1)
    print(f"residuo (sin xorout) = {crc_check:#010x}  (esperado 0xDEBB20E3)")
    assert crc_check == 0xDEBB20E3, "residuo canonico incorrecto"
    print("=== TX_OVERRIDE 1-STEP: FCS VALIDO SOBRE BYTES PARCHEADOS — PASS ===")

if __name__ == "__main__":
    main()
