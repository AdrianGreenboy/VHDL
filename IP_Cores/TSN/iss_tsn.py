#!/usr/bin/env python3
# iss_tsn.py - ISS ORACULO del switch TSN 4x4 visto por el firmware (nivel MMIO).
# ---------------------------------------------------------------------------
# Modela el switch como una maquina observable por registros MMIO. NO reimplementa
# el datapath ciclo a ciclo (eso lo hacen los TB de capa 1 y el oraculo de
# reenvio tsn_model.py); modela el CONTRATO que el firmware ve: dado un programa
# de (programar tabla, inyectar tramas, leer contadores), que valores devuelven
# las lecturas de contadores.
#
# Se valida RTL-vs-ISS: el mismo "programa" MMIO se aplica al RTL (tb_tsn_soc)
# y a este modelo; los contadores leidos deben coincidir bit-identico.
#
# Mapa de registros (offset de BYTE):
#   0x000 CONTROL   0x004 STATUS   0x008 TBL_MAC_LO 0x00C TBL_MAC_HI 0x010 TBL_IDX
#   0x020 INJ_CTRL  0x024 INJ_LEN  0x028 INJ_WDATA  0x02C INJ_STATUS
#   0x040-04C RX  0x050-05C TX  0x060-06C OVF  0x070-07C FCS  0x080-08C TAG
# ---------------------------------------------------------------------------

NPORTS = 4

def mac_of(p): return 0x020000000001 + p
MAC_BCAST = 0xFFFFFFFFFFFF

class SwitchISS:
    def __init__(self):
        self.table = {}
        self.cnt = {k: [0]*NPORTS for k in ('rx','tx','ovf','fcs','tag')}
        self.inj_psel = 0
        self.slots = [None]*16

    def tbl_write(self, idx, mac48, port, valid):
        self.slots[idx] = (mac48, port, valid)
        self.table = {}
        for j in range(15, -1, -1):          # gana el indice mas bajo
            s = self.slots[j]
            if s and s[2]:
                self.table[s[0]] = s[1]

    def classify(self, iport, dst_mac):
        if (dst_mac >> 40) & 1:
            return set(range(NPORTS)) - {iport}
        p = self.table.get(dst_mac)
        if p is None:
            return set(range(NPORTS)) - {iport}
        return set() if p == iport else {p}

    def inject(self, frame_bytes):
        iport = self.inj_psel
        dst = int.from_bytes(bytes(frame_bytes[0:6]), 'big')
        tagged = len(frame_bytes) >= 14 and frame_bytes[12] == 0x81 \
                 and frame_bytes[13] == 0x00
        self.cnt['rx'][iport] += 1
        if tagged:
            self.cnt['tag'][iport] += 1
        for o in self.classify(iport, dst):
            self.cnt['tx'][o] += 1

    def counters_signature(self):
        vec = []
        for k in ('rx','tx','ovf','fcs','tag'):
            vec += self.cnt[k]
        return vec


def reference_program():
    iss = SwitchISS()
    for p in range(NPORTS):
        iss.tbl_write(p, mac_of(p), p, True)

    def mk(dst, src, plen=60, tag=False):
        f = list(dst.to_bytes(6,'big')) + list(src.to_bytes(6,'big'))
        if tag:
            f += [0x81,0x00,0x00,0x64]
        f += [0x08,0x00]
        while len(f) < plen:
            f.append(0xA5)
        return f[:plen]

    program = [
        (0, mk(mac_of(1), mac_of(0))),
        (2, mk(mac_of(3), mac_of(2))),
        (1, mk(MAC_BCAST, mac_of(1))),
        (3, mk(0x0A0B0C0D0E0F, mac_of(3))),
        (0, mk(mac_of(2), mac_of(0), tag=True)),
        (1, mk(mac_of(1), mac_of(1))),
        (2, mk(mac_of(0), mac_of(2))),
        (3, mk(MAC_BCAST, mac_of(3))),
    ]
    for psel, frame in program:
        iss.inj_psel = psel
        iss.inject(frame)
    return iss, program


if __name__ == "__main__":
    import zlib
    iss, program = reference_program()
    vec = iss.counters_signature()
    labels = [f"{k}{p}" for k in ('RX','TX','OVF','FCS','TAG') for p in range(4)]
    for lab, v in zip(labels, vec):
        print(f"{lab} {v}")
    sig = zlib.crc32(bytes(vec)) & 0xffffffff
    print(f"SIG {sig:08x}")
