#!/usr/bin/env python3
# =============================================================================
#  iss_eth.py  -  Modelo de referencia (ISS) de la capa 4 del MAC Ethernet.
#
#  Modela la SEMANTICA FUNCIONAL del eth_mmio (ya validada bit a bit en la
#  capa 2) a nivel de transacciones MMIO en LOOP_INT, y ejecuta el MISMO guion
#  que correra el programa RV32 en el SoC. Produce la firma de 8 palabras que
#  el firmware vuelca por DMA a la DDR.
#
#  El MAC en LOOP_INT: una trama escrita byte a byte en TXD (con EOF en el
#  ultimo byte) da la vuelta por el PL y, si pasa FCS y filtro MAC, aparece
#  intacta (sin preambulo/SFD/FCS) en la FIFO RX, legible byte a byte por RXD.
#
#  No es ciclo a ciclo: es el oraculo funcional. El RTL de capa 4 debe
#  reproducir exactamente esta firma.
#  Licencia: MIT
# =============================================================================

BCAST = [0xFF] * 6

def crc32_eth(data):
    """CRC-32 Ethernet (igual convencion que el RTL: reflejado, complemento)."""
    crc = 0xFFFFFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xEDB88320 if (crc & 1) else (crc >> 1)
    return (~crc) & 0xFFFFFFFF


class EthMacModel:
    """Reproduce la logica funcional de eth_mmio en LOOP_INT."""
    def __init__(self, macaddr, promisc=False):
        self.mac = macaddr[:]           # 6 bytes, byte0 primero
        self.promisc = promisc
        self.txbuf = []                 # bytes de la trama en curso (sin FCS)
        self.rxfifo = []                # bytes de tramas aceptadas (con EOF)
        self.ev_ok = 0
        self.ev_crc = 0
        self.ev_runt = 0
        self.ev_drop = 0

    def tx_byte(self, b, eof):
        self.txbuf.append(b & 0xFF)
        if eof:
            self._loopback()
            self.txbuf = []

    def _filter_ok(self, dst):
        if self.promisc:
            return True
        if dst == self.mac:
            return True
        if dst == BCAST:
            return True
        return False

    def _loopback(self):
        # el motor TX rellena a 60 bytes de datos y anade FCS; el RX recibe
        # datos+FCS, verifica y descarta el FCS. Modelamos el resultado neto.
        data = self.txbuf[:]
        if len(data) < 60:
            data = data + [0] * (60 - len(data))     # padding a 60
        # FCS correcto por construccion en LOOP_INT (sin corrupciones)
        n_with_fcs = len(data) + 4
        if n_with_fcs < 64:
            self.ev_runt = 1
            return
        dst = data[0:6]
        if not self._filter_ok(dst):
            self.ev_drop = 1
            return
        # aceptada: volcar los bytes de datos (sin FCS) con EOF en el ultimo
        for i, b in enumerate(data):
            self.rxfifo.append((b, 1 if i == len(data) - 1 else 0))
        self.ev_ok = 1

    def rxd(self):
        """pop-on-read: devuelve (valid, dato, eof)."""
        if not self.rxfifo:
            return (0, 0, 0)
        b, eof = self.rxfifo.pop(0)
        return (1, b, eof)

    def clear_stickies(self):
        self.ev_ok = self.ev_crc = self.ev_runt = self.ev_drop = 0


# =============================================================================
#  Guion de la capa 4 (identico al programa RV32)
#  MAC propia: 02:AA:BB:CC:DD:EE  (byte0 = 0x02)
# =============================================================================
MAC_SELF = [0x02, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE]
SRC_ADDR = [0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F]

def build_frame(dst, payload_len, seed):
    """dst(6) + src(6) + ethertype(2) + payload. Determinista."""
    f = list(dst) + list(SRC_ADDR) + [0x08, 0x00]
    for i in range(payload_len):
        f.append((seed * 13 + i * 5 + 9) & 0xFF)
    return f

def send_and_read(mac, frame):
    """Escribe la trama por TXD y lee la recibida por RXD. Devuelve los bytes
       de datos recibidos (o None si fue descartada)."""
    for i, b in enumerate(frame):
        mac.tx_byte(b, eof=(i == len(frame) - 1))
    got = []
    while True:
        valid, b, eof = mac.rxd()
        if not valid:
            break
        got.append(b)
        if eof:
            break
    return got if got else None


def run_reference():
    mac = EthMacModel(MAC_SELF, promisc=False)
    sig = []

    # Trama 0: unicast propia, payload 46 -> aceptada (60 bytes de datos)
    f0 = build_frame(MAC_SELF, 46, seed=0)
    r0 = send_and_read(mac, f0)
    assert r0 is not None and mac.ev_ok == 1
    sig.append(sum(r0) & 0xFFFFFFFF)                 # sig[0] = suma de bytes RX
    sig.append(len(r0))                              # sig[1] = long recibida (60)
    mac.clear_stickies()

    # Trama 1: unicast propia, payload 100 -> aceptada (114 bytes)
    f1 = build_frame(MAC_SELF, 100, seed=1)
    r1 = send_and_read(mac, f1)
    assert r1 is not None
    x = 0
    for b in r1:
        x ^= b
    sig.append(x)                                    # sig[2] = xor de bytes
    sig.append(len(r1))                              # sig[3] = 114
    mac.clear_stickies()

    # Trama 2: broadcast, payload 46 -> aceptada
    f2 = build_frame(BCAST, 46, seed=2)
    r2 = send_and_read(mac, f2)
    assert r2 is not None
    sig.append(r2[0])                                # sig[4] = primer byte (0xFF)
    mac.clear_stickies()

    # Trama 3: unicast AJENA, payload 46 -> descartada por filtro
    other = [0x02, 0x99, 0x88, 0x77, 0x66, 0x55]
    f3 = build_frame(other, 46, seed=3)
    r3 = send_and_read(mac, f3)
    sig.append(0xD40D if (r3 is None and mac.ev_drop == 1) else 0)  # sig[5]
    mac.clear_stickies()

    # Trama 4: FCS/CRC de la trama 0 (control de integridad del oraculo)
    sig.append(crc32_eth(f0[0:6] + f0[6:] + [0]*(60 - len(f0))) & 0xFFFFFFFF)  # sig[6]

    # Trama 5: unicast propia, payload 1500 (MTU) -> aceptada (1514 bytes)
    f5 = build_frame(MAC_SELF, 1500, seed=5)
    r5 = send_and_read(mac, f5)
    assert r5 is not None
    sig.append(len(r5))                              # sig[7] = 1514

    return sig


if __name__ == "__main__":
    sig = run_reference()
    print("=== FIRMA (8 palabras a DDR por DMA) ===")
    for i, w in enumerate(sig):
        print(f"  sig[{i}] = 0x{w & 0xFFFFFFFF:08X}  ({w})")
    with open("iss_signature.txt", "w") as fh:
        for w in sig:
            fh.write(f"{w & 0xFFFFFFFF:08X}\n")
    print("Firma escrita en iss_signature.txt")
