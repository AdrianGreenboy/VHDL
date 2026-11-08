#!/usr/bin/env python3
"""compare128.py - lockstep RTL vs ISS del RV128IMAC (capas 2/3).

Derivado de RV64IMAC/compare.py. Para cada programa (prefijo de rv128asm.py:
<prog>.bin + <prog>.sym) genera el .hex, simula tb_core en GHDL y compara la
traza de retiro instruccion a instruccion contra iss128.py:
  PC, bits de la instruccion, rd, valor escrito, trap, causa y tval, y la
  direccion, carriles y datos de cada escritura a memoria.
Las interrupciones las dicta el RTL, con comprobacion de legalidad (pendiente,
habilitada y de mayor prioridad en el ISS) y de vivacidad (LIVENESS retiros).
Lecturas no deterministas (cycle/mcycle y loads de mtime/UART) se copian del
RTL al ISS en vez de compararse.

Uso: compare128.py [--maxlat N] [--seed S] [--keep] prog...
"""
import argparse
import os
import subprocess
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iss128
from iss128 import Bus, Hart, ExitSim, MX, M64

HERE = os.environ.get('RV128_HOME', os.path.dirname(os.path.abspath(__file__)))
SIM = os.environ.get('RV128_SIM', os.path.join(HERE, 'sim'))
MEM_KB = 8192
NONDET_CSR = {0xC00, 0xB00}
TSKEW = int(os.environ.get('RV128_TSKEW', '0'))
LIVENESS = 24


def load(prog):
    bus = Bus(ram_size=MEM_KB << 10)
    entry, syms = iss128.load_flat(bus, prog + '.bin', prog + '.sym')
    return bus, entry, syms


def write_hex(prog, path):
    bus, entry, syms = load(prog)
    with open(path, 'w') as f:
        ram = bus.ram
        for o in range(0, len(ram), 16):
            d = int.from_bytes(ram[o:o + 16], 'little')
            if d:
                f.write(f'{0x80000000 + o:016x} {d:032x}\n')
    if 'tohost' not in syms:
        sys.exit(f'{prog}: falta la etiqueta tohost')
    return syms['tohost'] - 0x80000000, entry - 0x80000000


def run_rtl(prog, maxlat, seed, tag, time_div=4, timeout=4000000):
    hexf = os.path.join(SIM, f'{tag}.hex')
    trf = os.path.join(SIM, f'{tag}.trace')
    tohost, entry = write_hex(prog, hexf)
    cmd = [os.path.join(SIM, 'tb_core'), f'-gHEX={hexf}', f'-gTRACE={trf}', f'-gTOHOST={tohost}',
           f'-gENTRY={entry}', f'-gMAXLAT={maxlat}', f'-gSEED={seed}', f'-gMEM_KB={MEM_KB}',
           f'-gTIME_DIV={time_div}', f'-gTIMEOUT={timeout}', '--ieee-asserts=disable']
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=SIM).stdout
    return out, trf, hexf


def parse(line):
    p = line.replace('X', 'F').replace('U', 'F').split()
    r = dict(pc=int(p[0], 16), insn=int(p[1], 16), rd=int(p[2]), val=int(p[3], 16), time=int(p[4], 16),
             mip=int(p[5], 16), trap=None, meta='X' in line or 'U' in line)
    r['w'] = None
    k = 6
    if len(p) > k and p[k] == 'T':
        r['trap'] = (int(p[k + 1], 16), int(p[k + 2], 16))
        k += 3
    if len(p) > k and p[k] == 'W':
        r['w'] = (int(p[k + 1], 16), int(p[k + 2], 16), int(p[k + 3], 16))
    return r


def nondet(h, insn):
    if insn & 0x7F == 0x73 and (insn >> 12) & 3:
        return (insn >> 20) in NONDET_CSR
    if insn & 0x7F == 0x03:
        a = (h.x[(insn >> 15) & 31] + iss128.sx(insn >> 20, 12)) & MX
        return (iss128.CLINT_BASE + 0xBFF8 <= a < iss128.CLINT_BASE + 0xC000 or
                iss128.UART_BASE <= a < iss128.UART_BASE + iss128.UART_SIZE or
                any(b <= a < b + n for b, n, _ in iss128.STUB_REGIONS))
    return False


def check_write(h, insn32, w):
    iw = h.wlog
    if w is None and iw is None:
        return None
    if (w is None) != (iw is None):
        return f'RTL={w and tuple(hex(x) for x in w)} ISS={iw and tuple(hex(x) for x in iw)}'
    addr, strb, data = w
    pa, size, val = iw
    lane = pa & 15
    exp_strb = ((1 << size) - 1) << lane
    if addr != pa or strb != exp_strb:
        return f'RTL addr={addr:x} strb={strb:04x}  ISS pa={pa:x} strb={exp_strb:04x}'
    if insn32 & 0x7F == 0x2F and (insn32 >> 27) != 3:
        return None                                    # AMO: el core no conoce el valor nuevo
    mask = sum(0xFF << (8 * k) for k in range(16) if (strb >> k) & 1)
    if data & mask != (val << (8 * lane)) & mask:
        return f'datos RTL={data & mask:032x} ISS={(val << (8 * lane)) & mask:032x} en {pa:x}'
    return None


def lockstep(prog, trf):
    bus, entry, _ = load(prog)
    h = Hart(bus, pc=entry)
    with open(trf) as f:
        return lockstep_stream(h, bus, f)


def lockstep_stream(h, bus, lines):
    h.irq_forced = True
    h.time_div = 1 << 62
    n = starved = tskew = 0
    for line in lines:
        r = parse(line)
        bus.mtime = r['time']
        h.mip_hw = r['mip']
        force = None
        legal = h.pending_irq()
        if r['trap'] and r['trap'][0] >> 127:
            force = r['trap'][0] & 31
            if legal != force:
                return n, (f'retiro {n}: RTL toma irq {force} en pc={r["pc"]:x} pero el ISS '
                           f'tiene pendiente+habilitada: {legal}')
            starved = 0
        elif legal is not None:
            starved += 1
            if starved > LIVENESS:
                return n, (f'retiro {n}: irq {legal} pendiente y habilitada durante '
                           f'{LIVENESS} retiros sin que el RTL la tome (pc={r["pc"]:x})')
        else:
            starved = 0
        try:
            insn32 = r['insn'] if r['insn'] & 3 == 3 else (iss128.expand_c(r['insn']) or 0)
            nd = not r['trap'] and nondet(h, insn32)
            pc, insn, rd, val, trap = h.step(force)
        except ExitSim:
            return n, None
        exp = dict(pc=pc, insn=insn, rd=rd, val=val, trap=trap)
        mt = 1 if bus.mtime >= bus.mtimecmp else 0
        if ((r['mip'] >> 7) & 1) != mt or ((r['mip'] >> 3) & 1) != (bus.msip & 1):
            tskew += 1
            if tskew > TSKEW:
                return n, (f'retiro {n}: lineas del CLINT: RTL mip={r["mip"]:x} pero el ISS '
                           f'tiene mtime={bus.mtime:#x} mtimecmp={bus.mtimecmp:#x} msip={bus.msip}')
        else:
            tskew = 0
        if nd and rd == r['rd'] and rd:
            h.x[rd] = r['val']
            exp['val'] = r['val']
        if trap and (trap[0] >> 127 or trap[0] == iss128.EXC_IACCESS):
            exp['insn'] = r['insn']
        werr = check_write(h, insn32, r['w'])
        if werr:
            return n, f'retiro {n}: pc={r["pc"]:x} escritura a memoria: {werr}'
        if r['meta'] or any(exp[k] != r[k] for k in ('pc', 'insn', 'rd', 'val', 'trap')):
            return n, (f'retiro {n}: RTL  pc={r["pc"]:x} insn={r["insn"]:08x} rd={r["rd"]} '
                       f'val={r["val"]:x} trap={fmt(r["trap"])}\n'
                       f'          ISS  pc={pc:x} insn={insn:08x} rd={rd} val={val:x} trap={fmt(trap)}')
        n += 1
    return n, None


def fmt(t):
    return 'no' if not t else f'({t[0]:#x},{t[1]:#x})'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('prog', nargs='+', help='prefijos de programa (<prog>.bin, <prog>.sym)')
    ap.add_argument('--maxlat', type=int, default=1)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--time-div', type=int, default=4)
    ap.add_argument('--timeout', type=int, default=4000000)
    a = ap.parse_args()
    fails = 0
    for prog in a.prog:
        tag = os.path.basename(prog) + f'_l{a.maxlat}_s{a.seed}'
        out, trf, hexf = run_rtl(prog, a.maxlat, a.seed, tag, a.time_div, a.timeout)
        verdict = 'PASS' if 'TOHOST PASS' in out else 'FAIL'
        n, err = lockstep(prog, trf)
        if err:
            verdict = 'MISMATCH'
        if verdict != 'PASS':
            fails += 1
        cyc = out.split('ciclos=')[1].split()[0] if 'ciclos=' in out else '-'
        print(f'{verdict:8} {os.path.basename(prog):28} retiros={n:<7} ciclos={cyc}')
        if err:
            print('   ', err)
        elif verdict != 'PASS':
            print('   ', ' | '.join(l for l in out.splitlines() if 'report' in l or 'TOHOST' in l)[-300:])
        if not a.keep:
            for p in (trf, hexf):
                if os.path.exists(p):
                    os.remove(p)
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
