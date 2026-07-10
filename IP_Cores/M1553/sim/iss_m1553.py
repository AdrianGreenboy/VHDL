#!/usr/bin/env python3
# =============================================================================
#  iss_m1553.py  -  Modelo de referencia (ISS) de la capa 4 del IP 1553.
#
#  Modela la SEMANTICA FUNCIONAL del m1553_mmio (ya validada bit a bit en la
#  capa 2) a nivel de transacciones MMIO, y ejecuta el MISMO guion que correra
#  el programa RV32 en el SoC. Produce la traza esperada:
#    - palabras RX drenadas (dato, fuente, subaddr, bcast)
#    - statuses capturados por el BC (RESULT)
#    - flags de resultado por mensaje (OK/TOUT/SERR/ME)
#    - la firma de 8 palabras que el firmware vuelca por DMA a la DDR.
#
#  No es un simulador ciclo a ciclo: es el oraculo funcional. El RTL de capa 4
#  debe reproducir exactamente esta secuencia de datos.
#  Licencia: MIT
# =============================================================================

RT0_ADDR = 5
RT1_ADDR = 9

def odd_parity(d):
    p = 1
    for i in range(16):
        p ^= (d >> i) & 1
    return p

class RT:
    """Modelo funcional de un Remote Terminal."""
    def __init__(self, addr):
        self.addr = addr
        self.me = 0
        self.bcr = 0
    def status(self):
        # b15:11 addr, b10 ME, b0 BCR -> layout del rt_core:
        # rt_addr & me_f & "00" & "000" & bcr_f & "0000"
        return (self.addr << 11) | (self.me << 10) | (self.bcr << 0)

class Bus1553Model:
    """Reproduce la logica funcional de m1553_mmio en LOOP_INT."""
    def __init__(self):
        self.rt = {RT0_ADDR: RT(RT0_ADDR), RT1_ADDR: RT(RT1_ADDR)}
        self.txfifo = []          # datos precargados (16b)
        self.rxfifo = []          # (dato, src, sa, bcast)
        self.stat1 = 0
        self.stat2 = 0
        self.result_flags = None  # (ok,tout,serr,me)

    def push_tx(self, d):
        self.txfifo.append(d & 0xFFFF)

    def _src_of(self, addr):
        if addr == RT0_ADDR: return 1
        if addr == RT1_ADDR: return 2
        return 0

    def run_message(self, rtrt, tr, rt, sa, wc, rt2=0, sa2=0):
        n = wc if wc != 0 else 32
        ok = tout = serr = me = 0
        self.stat1 = 0
        self.stat2 = 0
        bcast = (rt == 31)
        mode = (sa == 0 or sa == 31)

        if rtrt:
            # RT->RT: rt2 transmite n datos, rt (receptor) los capta.
            src = self.rt.get(rt2); dst = self.rt.get(rt)
            if src is None or dst is None:
                tout = 1
            else:
                data = [self.txfifo.pop(0) for _ in range(n)]
                for d in data:
                    self.rxfifo.append((d, self._src_of(rt), sa, 0))
                src.me = 0
                dst.me = 0
                self.stat1 = src.status()   # primero el transmisor
                self.stat2 = dst.status()
                ok = 1
        elif bcast:
            # broadcast BC->RT: ambos RTs reciben, ninguno responde, BCR=1
            data = [self.txfifo.pop(0) for _ in range(n)]
            for addr in (RT0_ADDR, RT1_ADDR):
                r = self.rt[addr]
                r.bcr = 1
                r.me = 0
                for d in data:
                    self.rxfifo.append((d, self._src_of(addr), sa, 1))
            ok = 1
        elif mode:
            r = self.rt.get(rt)
            if r is None:
                tout = 1
            elif tr == 1:
                if wc == 0x02:            # Transmit Status Word (preserva ME/BCR)
                    self.stat1 = r.status()
                    if r.me: me = 1
                    ok = 1
                elif wc == 0x01:          # Synchronize sin dato
                    r.me = 0
                    self.stat1 = r.status()
                    ok = 1
                else:                     # no soportado -> ME
                    r.me = 1
                    self.stat1 = r.status()
                    me = 1
                    ok = 1
            else:
                if wc == 0x11:            # Synchronize con dato
                    r.me = 0
                    d = self.txfifo.pop(0)
                    self.rxfifo.append((d, self._src_of(rt), sa, 0))
                    self.stat1 = r.status()
                    ok = 1
                else:
                    r.me = 1
                    self.stat1 = r.status()
                    me = 1
                    ok = 1
        else:
            r = self.rt.get(rt)
            if r is None:
                tout = 1
            elif tr == 0:
                # BC->RT
                r.me = 0
                data = [self.txfifo.pop(0) for _ in range(n)]
                for d in data:
                    self.rxfifo.append((d, self._src_of(rt), sa, 0))
                self.stat1 = r.status()
                ok = 1
            else:
                # RT->BC
                r.me = 0
                data = [self.txfifo.pop(0) for _ in range(n)]
                for d in data:
                    self.rxfifo.append((d, 0, 0, 0))   # los recibe el BC (src=00)
                self.stat1 = r.status()
                ok = 1

        self.result_flags = (ok, tout, serr, me)
        return self.result_flags

    def pop_rx(self):
        if not self.rxfifo:
            return None
        return self.rxfifo.pop(0)


# =============================================================================
#  Guion de la capa 4 (identico al programa RV32)
# =============================================================================
def run_reference():
    bus = Bus1553Model()
    trace = []
    sig = []   # firma de 8 palabras que el firmware volcara por DMA

    def drain(n, tag):
        got = []
        for _ in range(n):
            w = bus.pop_rx()
            assert w is not None, f"{tag}: RXFIFO vacio antes de tiempo"
            got.append(w)
            trace.append((tag, "rx", w))
        return got

    # Paso 2: BC->RT0 wc=4
    for d in (0xB100, 0xB101, 0xB102, 0xB103):
        bus.push_tx(d)
    f = bus.run_message(0, 0, RT0_ADDR, 3, 4)
    trace.append(("P2", "flags", f))
    trace.append(("P2", "stat1", bus.stat1))
    g = drain(4, "P2")
    sig.append(bus.stat1)                    # sig[0] = status BC->RT0
    sig.append(sum(w[0] for w in g) & 0xFFFF)  # sig[1] = suma de datos

    # Paso 3: RT0->BC wc=3
    for d in (0xE200, 0xE201, 0xE202):
        bus.push_tx(d)
    f = bus.run_message(0, 1, RT0_ADDR, 2, 3)
    trace.append(("P3", "flags", f))
    g = drain(3, "P3")
    sig.append(bus.stat1)                    # sig[2]
    sig.append(g[0][0] ^ g[1][0] ^ g[2][0])  # sig[3] = xor de datos

    # Paso 4: RT0->RT1 wc=2
    for d in (0xF300, 0xF301):
        bus.push_tx(d)
    f = bus.run_message(1, 0, RT0_ADDR, 4, 2, RT1_ADDR, 4)
    trace.append(("P4", "flags", f))
    trace.append(("P4", "stat12", (bus.stat1, bus.stat2)))
    g = drain(2, "P4")
    sig.append((bus.stat2 << 16) | bus.stat1)  # sig[4] = RESULT (stat2<<16|stat1)
    sig.append(g[0][0] & g[1][0])              # sig[5]

    # Paso 5: broadcast wc=2
    for d in (0xB4B4, 0xB5B5):
        bus.push_tx(d)
    f = bus.run_message(0, 0, 31, 6, 2)
    trace.append(("P5", "flags", f))
    g = drain(4, "P5")                          # 2 de RT0 + 2 de RT1
    bcr = (bus.rt[RT0_ADDR].bcr << 1) | bus.rt[RT1_ADDR].bcr
    sig.append(bcr)                             # sig[6] = 0b11

    # Paso 6: timeout (RT ausente = 12)
    f = bus.run_message(0, 1, 12, 2, 2)
    trace.append(("P6", "flags", f))
    sig.append(0xDEAD if f[1] == 1 else 0)     # sig[7] = marcador de TOUT

    return trace, sig


if __name__ == "__main__":
    trace, sig = run_reference()
    print("=== TRAZA DE REFERENCIA (ISS capa 4) ===")
    for t in trace:
        if t[1] == "rx":
            tag, _, (d, src, sa, bc) = t
            print(f"  {tag}: RX dato=0x{d:04X} src={src} sa={sa} bcast={bc}")
        elif t[1] == "flags":
            print(f"  {t[0]}: flags ok={t[2][0]} tout={t[2][1]} serr={t[2][2]} me={t[2][3]}")
        elif t[1] == "stat1":
            print(f"  {t[0]}: stat1=0x{t[2]:04X}")
        elif t[1] == "stat12":
            print(f"  {t[0]}: stat1=0x{t[2][0]:04X} stat2=0x{t[2][1]:04X}")
    print("=== FIRMA (8 palabras a DDR por DMA) ===")
    for i, w in enumerate(sig):
        print(f"  sig[{i}] = 0x{w & 0xFFFFFFFF:08X}")
    # volcar la firma para el testbench
    with open("iss_signature.txt", "w") as f:
        for w in sig:
            f.write(f"{w & 0xFFFFFFFF:08X}\n")
