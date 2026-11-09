#!/usr/bin/env python3
"""compare64.py - lockstep of the dual core in RV64 mode against the unmodified iss64.py.

The RV64 mode of rv128_core must be binary-identical to rv64_core, so the oracle is the
RV64IMAC ISS itself (../RV64IMAC/iss64.py, verified against Spike) and the comparison loop
is RV64IMAC/compare.py, reused as is. Only the trace adapter is new:
  * tb_core runs with XLEN64=true and a 128-bit RAM;
  * every 128-bit trace value (pc, rd value, cause, tval) must be the sign extension of
    its low 64 bits (the RV64-mode invariant), otherwise the retirement is a mismatch;
  * 16-lane store records are folded to the 8-lane RV64 view.

--tb cpu runs the cached CPU (tb_cpu, 128-bit AXI4) and --tb soc the full SoC from the boot
ROM (tb_soc); the boot ROM image is this tree's sw/bootrom/bootrom.bin.

Usage: compare64.py [--tb core|cpu|soc] [--maxlat N] [--seed S] [--time-div D] [--keep] elf...
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RV64 = os.environ.get('RV64_HOME', os.path.normpath(os.path.join(HERE, '..', 'RV64IMAC')))
sys.path.insert(0, RV64)
import iss64            # noqa: E402
import compare as c64   # noqa: E402

SIM = os.environ.get('RV128_SIM', os.path.join(HERE, 'sim'))
c64.BOOTROM = os.path.join(HERE, 'sw', 'bootrom', 'bootrom.bin')
M64 = (1 << 64) - 1
M128 = (1 << 128) - 1


def sext_ok(v):
    lo = v & M64
    return v == (lo | ((M128 ^ M64) if lo >> 63 else 0))


def write_hex(elf, path):
    bus = iss64.Bus(ram_size=c64.MEM_KB << 10)
    entry, syms = iss64.load_elf(bus, elf)
    with open(path, 'w') as f:
        for o in range(0, len(bus.ram), 16):
            d = int.from_bytes(bus.ram[o:o + 16], 'little')
            if d:
                f.write(f'{0x80000000 + o:016x} {d:032x}\n')
    return syms['tohost'] - 0x80000000, entry - 0x80000000


def run_rtl(elf, maxlat, seed, tag, time_div=4, timeout=4000000, tb='core'):
    hexf = os.path.join(SIM, f'{tag}.hex')
    trf = os.path.join(SIM, f'{tag}.trace')
    tohost, entry = write_hex(elf, hexf)
    cmd = [os.path.join(SIM, 'tb_' + tb), f'-gHEX={hexf}', f'-gTRACE={trf}', f'-gTOHOST={tohost}',
           f'-gENTRY={entry}', f'-gMAXLAT={maxlat}', f'-gSEED={seed}', f'-gMEM_KB={c64.MEM_KB}',
           f'-gTIME_DIV={time_div}', f'-gTIMEOUT={timeout}', '-gXLEN64=true', '--ieee-asserts=disable']
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=SIM).stdout
    return out, trf, hexf


_parse128 = c64.parse


def parse64(line):
    r = _parse128(line)
    bad = []
    for k in ('pc', 'val'):
        if not sext_ok(r[k]):
            bad.append(k)
        r[k] &= M64
    if r['trap']:
        cause, tval = r['trap']
        if not sext_ok(cause) or not sext_ok(tval):
            bad.append('trap')
        r['trap'] = (cause & M64, tval & M64)
    if r['w']:
        addr, strb, data = r['w']
        if addr >> 64:
            bad.append('w.addr')
        hi = (addr >> 3) & 1
        r['w'] = (addr & M64, (strb >> (8 * hi)) & 0xFF, (data >> (64 * hi)) & M64)
    if bad:
        r['meta'] = True                      # breaks the comparison and reports the line
        print(f'   invariante RV64 (extension de signo) rota en {",".join(bad)}: {line.strip()}')
    return r


c64.parse = parse64
c64.run_rtl = run_rtl


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('elf', nargs='+')
    ap.add_argument('--maxlat', type=int, default=1)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--time-div', type=int, default=4)
    ap.add_argument('--timeout', type=int, default=4000000)
    ap.add_argument('--tb', choices=('core', 'cpu', 'soc'), default='core')
    a = ap.parse_args()
    fails = 0
    for elf in a.elf:
        tag = 'm64_' + os.path.basename(elf) + f'_l{a.maxlat}_s{a.seed}_{a.tb}'
        out, trf, hexf = run_rtl(elf, a.maxlat, a.seed, tag, a.time_div, a.timeout, a.tb)
        verdict = 'PASS' if 'TOHOST PASS' in out else 'FAIL'
        n, err = c64.lockstep(elf, trf, a.tb == 'soc')
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
