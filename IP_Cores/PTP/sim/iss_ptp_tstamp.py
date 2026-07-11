#!/usr/bin/env python3
# iss_ptp_tstamp.py — modelo de referencia del bloque de timestamping SFD.
# Replica ptp_tstamp.vhd: captura {sec,ns} en el pulso SFD, corrige latencia
# (con borrow al segundo), sticky de validez limpiado por rd_ack, overrun.
NS_PER_SEC = 1_000_000_000
SEC_MASK = (1 << 48) - 1
NS_MASK = (1 << 32) - 1

class PtpTstamp:
    def __init__(self):
        self.sec = 0
        self.ns = 0
        self.valid = 0
        self.overrun = 0

    def tick(self, now_sec, now_ns, lat_ns, sfd_pulse, rd_ack, rst=0):
        if rst:
            self.valid = 0; self.overrun = 0; self.sec = 0; self.ns = 0
            return
        if rd_ack:
            self.valid = 0
            self.overrun = 0        # sticky, limpiado por ack
        if sfd_pulse:
            if now_ns >= lat_ns:
                ns_v = now_ns - lat_ns
                sec_v = now_sec
            else:
                ns_v = now_ns + NS_PER_SEC - lat_ns
                sec_v = (now_sec - 1) & SEC_MASK
            self.sec = sec_v & SEC_MASK
            self.ns = ns_v & NS_MASK
            if self.valid == 1 and rd_ack == 0:
                self.overrun = 1
            self.valid = 1


if __name__ == "__main__":
    ts = PtpTstamp()
    rows = []
    def snap(tag):
        rows.append((tag, ts.sec, ts.ns, ts.valid, ts.overrun))

    # Espejo EXACTO del TB: cada evento son 2 ticks (estimulo + idle sin
    # pulsos). El snapshot se toma tras el tick idle (cuando el resultado
    # registrado del RTL ya es visible). Estados replicados 1:1.
    def event(sec, ns, lat, sfd, ack, tag):
        ts.tick(sec, ns, lat, sfd, ack)   # tick de estimulo
        ts.tick(sec, ns, lat, 0, 0)       # tick idle (observacion)
        snap(tag)

    event(5, 1000, 40, 1, 0, "T1")   # captura con lat: {5,960}
    event(5, 1010, 40, 0, 0, "T2")   # sticky se mantiene
    event(5, 1020, 40, 0, 1, "T3")   # ack limpia
    event(7,   20, 40, 1, 0, "T4")   # borrow: {6, 1e9-20}
    event(8,  500, 40, 1, 0, "T5")   # overrun (valid alto sin ack)
    event(9,  700, 40, 1, 1, "T6")   # evento+ack: nuevo gana, sin overrun
    event(9,  710, 40, 0, 1, "T7")   # ack limpia

    with open("ref_tstamp.csv", "w") as f:
        for r in rows:
            f.write(",".join(str(x) for x in r) + "\n")
    for r in rows:
        print(r)
