#!/usr/bin/env python3
"""compare.py - lockstep RTL vs ISS (capas 2/3).

Para cada ELF: genera el .hex, simula tb_core en GHDL y compara la traza de
retiro instruccion a instruccion contra iss64.py:
  PC, bits de la instruccion, rd, valor escrito, trap, causa y tval.
Las interrupciones las dicta el RTL (el ISS se fuerza a tomarlas en el mismo
retiro). Lecturas no deterministas (cycle/time/mcycle/mip/sip y loads del
CLINT) se copian del RTL al ISS en vez de compararse.

Uso: compare.py [--maxlat N] [--seed S] [--keep] elf...
"""
import argparse, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iss64
from iss64 import Bus, Hart, load_elf, ExitSim, M64

HERE = os.environ.get('RV64_HOME', os.path.dirname(os.path.abspath(__file__)))
BOOTROM = os.path.join(HERE, 'sw', 'bootrom', 'bootrom.bin')
SIM = os.environ.get('RV64_SIM', os.path.join(HERE, 'sim'))
MEM_KB = 8192
NONDET_CSR = {0xC00, 0xB00}                  # ciclos: dependen de la microarquitectura
TSKEW = int(os.environ.get("RV64_TSKEW", "0"))   # holgura MTIP/MSIP RTL vs ISS (retiros)
LIVENESS = 24                                 # retiros de margen para tomar una irq


def write_hex(elf, path):
    bus = Bus(ram_size=MEM_KB << 10)
    entry, syms = load_elf(bus, elf)
    with open(path, 'w') as f:
        ram = bus.ram
        for o in range(0, len(ram), 8):
            d = int.from_bytes(ram[o:o + 8], 'little')
            if d:
                f.write(f'{0x80000000 + o:016x} {d:016x}\n')
    return syms['tohost'] - 0x80000000, entry - 0x80000000


def run_rtl(elf, maxlat, seed, tag, time_div=4, timeout=4000000, tb='core'):
    hexf = os.path.join(SIM, f'{tag}.hex')
    trf = os.path.join(SIM, f'{tag}.trace')
    tohost, entry = write_hex(elf, hexf)
    cmd = [os.path.join(SIM, 'tb_' + tb), f'-gHEX={hexf}', f'-gTRACE={trf}', f'-gTOHOST={tohost}', f'-gENTRY={entry}',
           f'-gMAXLAT={maxlat}', f'-gSEED={seed}', f'-gMEM_KB={MEM_KB}', f'-gTIME_DIV={time_div}',
           f'-gTIMEOUT={timeout}', '--ieee-asserts=disable']
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=SIM).stdout
    return out, trf, hexf


def parse(line):
    p = line.replace('X', 'F').replace('U', 'F').split()   # X/U del RTL -> valor imposible
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
    """True si la instruccion lee algo no determinista (se copia del RTL): contadores
    de ciclos y loads de dispositivos (CLINT, UART, PLIC, IP_Cores, AXI-Lite)."""
    if insn & 0x7F == 0x73 and (insn >> 12) & 3:
        return (insn >> 20) in NONDET_CSR
    if insn & 0x7F == 0x03:
        a = (h.x[(insn >> 15) & 31] + iss64.sx(insn >> 20, 12)) & M64
        try:
            a = h.translate(a, iss64.LOAD)
        except iss64.Trap:
            return False
        # CLINT: solo mtime es no determinista (avanza entre el load y el retiro);
        # msip y mtimecmp los modela el ISS y se comparan
        return (iss64.CLINT_BASE + 0xBFF8 <= a < iss64.CLINT_BASE + 0xC000 or
                iss64.UART_BASE <= a < iss64.UART_BASE + iss64.UART_SIZE or
                any(b <= a < b + n for b, n, _ in iss64.STUB_REGIONS))
    return False


def check_write(h, insn32, w):
    """Compara la escritura del retiro (RTL: addr, wstrb por carriles, wdata por
    carriles) con la del ISS (pa, bytes, valor). En AMO solo direccion y carriles:
    el core no conoce el valor nuevo (se calcula en la D$)."""
    iw = h.wlog
    if w is None and iw is None:
        return None
    if (w is None) != (iw is None):
        return f'RTL={w and tuple(hex(x) for x in w)} ISS={iw and tuple(hex(x) for x in iw)}'
    addr, strb, data = w
    pa, size, val = iw
    lane = pa & 7
    exp_strb = ((1 << size) - 1) << lane
    if addr != pa or strb != exp_strb:
        return f'RTL addr={addr:x} strb={strb:02x}  ISS pa={pa:x} strb={exp_strb:02x}'
    if insn32 & 0x7F == 0x2F and (insn32 >> 27) != 3:
        return None                                    # AMO: sin comparar datos
    mask = sum(0xFF << (8 * k) for k in range(8) if (strb >> k) & 1)
    if data & mask != (val << (8 * lane)) & mask:
        return f'datos RTL={data & mask:016x} ISS={(val << (8 * lane)) & mask:016x} en {pa:x}'
    return None


def lockstep(elf, trf, soc=False):
    bus = Bus(ram_size=MEM_KB << 10)
    entry, _ = load_elf(bus, elf)
    if soc:                                         # arranque desde la boot ROM del SoC
        bus.rom = open(BOOTROM, 'rb').read().ljust(4096, b'\0')
        entry = iss64.ROM_BASE
    h = Hart(bus, pc=entry)
    with open(trf) as f:
        return lockstep_stream(h, bus, f)


def lockstep_stream(h, bus, lines, report=None):
    """Compara una secuencia de lineas de traza del RTL contra el hart h del ISS.
    report(n, h) se llama cada 1M retiros (progreso / consola)."""
    h.irq_forced = True
    h.time_div = 1 << 62                     # mtime lo dicta el RTL (sincronizado por retiro)
    n = 0
    starved = 0                              # retiros con irq habilitada y pendiente sin tomar
    tskew = 0                                # retiros con MTIP/MSIP del RTL != CLINT del ISS
    if True:
        f = lines
        for line in f:
            if report and n and n % 1_000_000 == 0:
                report(n, h)
            if line.startswith('D '):                # escritura de DMA del TB: aplicarla al ISS
                _, a_, s_, d_ = line.split()
                a_, s_, d_ = int(a_, 16), int(s_, 16), int(d_, 16)
                for k in range(4):
                    if (s_ >> k) & 1 and bus.in_ram(a_ + k, 1):
                        bus.ram[a_ + k - bus.ram_base] = (d_ >> (8 * k)) & 0xFF
                continue
            r = parse(line)
            bus.mtime = r['time']
            h.mip_hw = r['mip']                    # lineas de interrupcion vistas por el RTL
            force = None
            legal = h.pending_irq()
            if r['trap'] and r['trap'][0] >> 63:
                force = r['trap'][0] & 31
                # legalidad: la irq que toma el RTL debe estar pendiente y habilitada
                # en el ISS en ese retiro, y ser la de mayor prioridad
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
                insn32 = r['insn'] if r['insn'] & 3 == 3 else (iss64.expand_c(r['insn']) or 0)
                nd = not r['trap'] and nondet(h, insn32)
                pc, insn, rd, val, trap = h.step(force)
            except ExitSim:
                return n, None
            exp = dict(pc=pc, insn=insn, rd=rd, val=val, trap=trap)
            # el CLINT del ISS (mtimecmp/msip escritos por el programa, mtime del RTL)
            # debe dar las mismas lineas MTIP/MSIP que el RTL; 2 retiros de holgura
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
            if trap and (trap[0] >> 63 or trap[0] in (iss64.EXC_IACCESS, iss64.EXC_IPAGE)):
                exp['insn'] = r['insn']            # irq o fallo de fetch: el ISS no tiene los bits
            keys = ('pc', 'insn', 'rd', 'val', 'trap')
            werr = check_write(h, insn32, r['w'])
            if werr:
                return n, f'retiro {n}: pc={r["pc"]:x} escritura a memoria: {werr}'
            if r['meta'] or any(exp[k] != r[k] for k in keys):
                return n, (f'retiro {n}: RTL  pc={r["pc"]:x} insn={r["insn"]:08x} rd={r["rd"]} '
                           f'val={r["val"]:x} trap={fmt(r["trap"])}\n'
                           f'          ISS  pc={pc:x} insn={insn:08x} rd={rd} val={val:x} trap={fmt(trap)}')
            n += 1
    return n, None


def fmt(t):
    return 'no' if not t else f'({t[0]:#x},{t[1]:#x})'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('elf', nargs='+')
    ap.add_argument('--maxlat', type=int, default=1)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--time-div', type=int, default=4, help='ciclos por tick de mtime')
    ap.add_argument('--timeout', type=int, default=4000000)
    ap.add_argument('--tb', choices=('core', 'cpu', 'soc'), default='core',
                    help='core: memoria ideal/aleatoria; cpu: caches + AXI4; soc: SoC completo desde la boot ROM')
    a = ap.parse_args()
    fails = 0
    for elf in a.elf:
        tag = os.path.basename(elf) + f'_l{a.maxlat}_s{a.seed}'
        out, trf, hexf = run_rtl(elf, a.maxlat, a.seed, tag + '_' + a.tb, a.time_div, a.timeout, a.tb)
        verdict = 'PASS' if 'TOHOST PASS' in out else 'FAIL'
        n, err = lockstep(elf, trf, a.tb == 'soc')
        if err:
            verdict = 'MISMATCH'
        if verdict != 'PASS':
            fails += 1
        cyc = out.split('ciclos=')[1].split()[0] if 'ciclos=' in out else '-'
        print(f'{verdict:8} {os.path.basename(elf):28} retiros={n:<7} ciclos={cyc}')
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
