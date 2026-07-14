#!/usr/bin/env python3
# tsn_model.py - Oraculo del switch SDN-TSN 4x4 (scope v1 congelado)
# Semantica: store-and-forward, commit/rewind en ingreso, sin FIFOs de egreso,
# RR por salida sobre entradas elegibles, multicast secuencial (HOL).
# Tiempo en byte-times; overhead por trama = 8 preambulo + 12 IFG = 20.
import sys, zlib

NPORTS   = 4
FIFO_B   = 2048
OVERHEAD = 20

def fcs_ok(frame):
    if len(frame) < 64: return False
    return zlib.crc32(bytes(frame[:-4])) == int.from_bytes(bytes(frame[-4:]), 'little')

def add_fcs(payload):
    return payload + list(zlib.crc32(bytes(payload)).to_bytes(4, 'little'))

class Model:
    def __init__(self):
        self.table = {}                      # mac(int48) -> puerto
        self.fifo  = [[] for _ in range(NPORTS)]   # lista de [frame, dest_set]
        self.occ   = [0]*NPORTS
        self.in_busy_until  = [0]*NPORTS
        self.out_busy_until = [0]*NPORTS
        self.rr    = [0]*NPORTS              # puntero RR por salida
        self.cnt   = {k: [0]*NPORTS for k in
                      ('rx','tx','drop_ovf','drop_fcs','tagged')}
        self.txlog = [[] for _ in range(NPORTS)]

    def classify(self, frame, iport):
        dst = int.from_bytes(bytes(frame[0:6]), 'big')
        if dst >> 40 & 1:                    # bit I/G: broadcast/multicast
            return set(range(NPORTS)) - {iport}
        p = self.table.get(dst)
        if p is None:
            return set(range(NPORTS)) - {iport}   # flooding
        return set() if p == iport else {p}

    def rx_frame(self, iport, t_end, frame):
        if len(frame) >= 16 and frame[12] == 0x81 and frame[13] == 0x00:
            self.cnt['tagged'][iport] += 1
        if not fcs_ok(frame):
            self.cnt['drop_fcs'][iport] += 1; return
        if self.occ[iport] + len(frame) > FIFO_B:
            self.cnt['drop_ovf'][iport] += 1; return
        self.cnt['rx'][iport] += 1
        dests = self.classify(frame, iport)
        if dests:
            self.fifo[iport].append([frame, dests, t_end])
            self.occ[iport] += len(frame)
        # dests vacio (dst==ingreso): rx cuenta, trama filtrada

    def schedule(self, now):
        moved = True
        while moved:
            moved = False
            for o in range(NPORTS):
                if self.out_busy_until[o] > now: continue
                for k in range(NPORTS):
                    i = (self.rr[o] + k) % NPORTS
                    if self.in_busy_until[i] > now or not self.fifo[i]: continue
                    frame, dests, t_rdy = self.fifo[i][0]
                    if t_rdy > now or o not in dests: continue
                    dur = len(frame) + OVERHEAD
                    self.out_busy_until[o] = now + dur
                    self.in_busy_until[i]  = now + dur
                    self.rr[o] = (i + 1) % NPORTS
                    self.txlog[o].append((now, i, len(frame),
                        int.from_bytes(bytes(frame[0:6]),'big')))
                    self.cnt['tx'][o] += 1
                    dests.discard(o)
                    if not dests:
                        self.fifo[i].pop(0); self.occ[i] -= len(frame)
                    moved = True
                    break

    def run(self, arrivals):
        # arrivals: lista (t_start, iport, frame); t_end = t_start+len+20
        evts = sorted((t + len(f) + OVERHEAD, p, f) for t, p, f in arrivals)
        times = sorted({e[0] for e in evts})
        idx, now = 0, 0
        pend = True
        while pend:
            cand = [t for t in (self.in_busy_until + self.out_busy_until +
                    ([evts[idx][0]] if idx < len(evts) else [])) if t > now]
            if idx < len(evts) or any(f for f in self.fifo):
                now = min(cand) if cand else now + 1
            while idx < len(evts) and evts[idx][0] <= now:
                _, p, f = evts[idx]; self.rx_frame(p, evts[idx][0], f); idx += 1
            self.schedule(now)
            pend = idx < len(evts) or any(self.fifo) and any(
                   t <= now + 10**9 for t in self.in_busy_until)
            if idx >= len(evts) and not any(self.fifo): pend = False

    def report(self):
        lines = []
        for o in range(NPORTS):
            for t, i, l, dst in self.txlog[o]:
                lines.append(f"TX p{o} t={t} from=p{i} len={l} dst={dst:012x}")
        for k in ('rx','tx','drop_ovf','drop_fcs','tagged'):
            lines.append(f"CNT {k} " + " ".join(str(v) for v in self.cnt[k]))
        sig = zlib.crc32("\n".join(lines).encode()) & 0xffffffff
        lines.append(f"SIG {sig:08x}")
        return "\n".join(lines)

def mk(dst, src, etype=0x0800, payload_len=46, fill=0xA5, tag=None):
    f = list(dst.to_bytes(6,'big')) + list(src.to_bytes(6,'big'))
    if tag is not None: f += [0x81,0x00,(tag>>8)&0xff,tag&0xff]
    f += [(etype>>8)&0xff, etype&0xff] + [fill]*payload_len
    if len(f) < 60: f += [0]*(60-len(f))
    return add_fcs(f)

if __name__ == "__main__":
    m = Model()
    m.table = {0x0200000000_01+p: p for p in range(NPORTS)}  # MAC 02:..:0p -> puerto p
    MAC = lambda p: 0x020000000001+p
    arr = [
        (0,   0, mk(MAC(1), MAC(0))),                    # unicast 0->1
        (0,   2, mk(MAC(3), MAC(2))),                    # unicast 2->3 (paralelo)
        (100, 1, mk(0xffffffffffff, MAC(1))),            # broadcast desde 1
        (200, 3, mk(0x0A0B0C0D0E0F, MAC(3))),            # MAC desconocida -> flood
        (300, 0, mk(MAC(2), MAC(0), tag=0x8064)),        # tagged VLAN, unicast 0->2
        (400, 2, mk(MAC(0), MAC(2))[:-1] + [0x00]),      # FCS corrupta -> drop
        (500, 1, mk(MAC(1), MAC(1))),                    # dst==ingreso -> filtrada
    ]
    m.run(arr)
    print(m.report())
