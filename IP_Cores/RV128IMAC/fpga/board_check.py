#!/usr/bin/env python3
"""board_check.py - Layer 4 (prototype in simulation) and Layer 5 (TE0950 silicon).

Every program is compared against iss128.py on three things:
  * verdict: HTIF code (0 = PASS)
  * console: the bytes the program sent to 0x1000_0000, byte for byte
  * retired: commits before the tohost store (exact, from RVFI), except for programs
    whose path depends on timer timing (rv128mi_irq)

  board_check.py sim  <prog>...          run tb_proto in GHDL (sim/tb_proto) and compare
  board_check.py pack <dir> <prog>...    stage .bin + tohost list for the board in <dir>
  board_check.py compare <dir> <prog>... compare <dir>/<name>.console/.result from the board
<prog> is a prefix: <prog>.bin and <prog>.sym.
"""
import argparse
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, ROOT)
import iss128  # noqa: E402

SIM = os.environ.get('RV128_SIM', os.path.join(ROOT, 'sim'))
TIMING_DEPENDENT = {'rv128mi_irq'}


def tohost_of(prog):
    for line in open(prog + '.sym'):
        a, n = line.split()
        if n == 'tohost':
            return int(a, 16) - 0x8000_0000
    sys.exit(f'{prog}: no tohost in .sym')


def expected(prog):
    commits = [0]

    def count(h, r):
        if r[4] is None:
            commits[0] += 1
    code, h = iss128.run_flat(prog + '.bin', prog + '.sym', 20_000_000, count)
    return code, bytes(h.bus.uart_out), commits[0]


def parse_result(text):
    d = {}
    for tok in text.split():
        if '=' in tok:
            k, v = tok.split('=', 1)
            d[k] = v
    d['timeout'] = text.startswith('TIMEOUT')
    return d


def judge(prog, res_text, console):
    name = os.path.basename(prog)
    code, exp_out, exp_ret = expected(prog)
    r = parse_result(res_text)
    errs = []
    if r['timeout']:
        errs.append(f'TIMEOUT (retired={r.get("retired")} pc={r.get("pc")})')
    else:
        if int(r['code']) != code:
            errs.append(f'code HW={r["code"]} ISS={code}')
        if name not in TIMING_DEPENDENT and int(r['retired']) != exp_ret:
            errs.append(f'retired HW={r["retired"]} ISS={exp_ret}')
    if console != exp_out:
        k = next((i for i in range(min(len(console), len(exp_out))) if console[i] != exp_out[i]),
                 min(len(console), len(exp_out)))
        errs.append(f'console differs at byte {k} (HW {len(console)} B, ISS {len(exp_out)} B)')
    ok = not errs and code == 0
    cyc = r.get('cycles', '-')
    cpi = f'{int(cyc) / int(r["retired"]):.2f}' if not r['timeout'] and int(r.get('retired', 0)) else '-'
    print(f'{"PASS" if ok else "FAIL":5} {name:24} retired={r.get("retired", "-"):>7} cycles={cyc:>8} CPI={cpi}')
    for e in errs:
        print('      ' + e)
    return ok


def write_hex32(prog, path):
    data = open(prog + '.bin', 'rb').read()
    data += bytes((-len(data)) % 4)
    with open(path, 'w') as f:
        for o in range(0, len(data), 4):
            w = int.from_bytes(data[o:o + 4], 'little')
            if w:
                f.write(f'{o:08x} {w:08x}\n')


def cmd_sim(progs, timeout):
    bad = 0
    for p in progs:
        tag = os.path.basename(p)
        hx, con, res = (os.path.join(SIM, f'{tag}.{e}') for e in ('hex32', 'console', 'result'))
        write_hex32(p, hx)
        subprocess.run([os.path.join(SIM, 'tb_proto'), f'-gHEX32={hx}', f'-gTOHOST={tohost_of(p)}',
                        f'-gCONSOLE={con}', f'-gRESULT={res}', f'-gTIMEOUT={timeout}',
                        '--ieee-asserts=disable'], cwd=SIM, capture_output=True)
        res_text = open(res).read().strip() if os.path.exists(res) else 'TIMEOUT retired=? pc=?'
        console = open(con, 'rb').read() if os.path.exists(con) else b''
        bad += not judge(p, res_text, console)
    return bad


def cmd_pack(outdir, progs):
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, 'list.txt'), 'w') as f:
        for p in progs:
            n = os.path.basename(p)
            shutil.copy(p + '.bin', os.path.join(outdir, n + '.bin'))
            f.write(f'{n} {tohost_of(p):x}\n')
    shutil.copy(os.path.join(HERE, 'rv128_load.c'), outdir)
    shutil.copy(os.path.join(HERE, 'board_run.sh'), outdir)
    print(f'{len(progs)} programs staged in {outdir}: copy the folder to the board')
    return 0


def cmd_compare(indir, progs):
    bad = 0
    for p in progs:
        n = os.path.basename(p)
        rf, cf = os.path.join(indir, n + '.result'), os.path.join(indir, n + '.console')
        res_text = open(rf).read().strip() if os.path.exists(rf) else 'TIMEOUT retired=? pc=? (no result file)'
        console = open(cf, 'rb').read() if os.path.exists(cf) else b''
        bad += not judge(p, res_text, console)
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mode', choices=('sim', 'pack', 'compare'))
    ap.add_argument('args', nargs='+')
    ap.add_argument('--timeout', type=int, default=4000000)
    a = ap.parse_args()
    if a.mode == 'sim':
        bad = cmd_sim(a.args, a.timeout)
    elif a.mode == 'pack':
        bad = cmd_pack(a.args[0], a.args[1:])
    else:
        bad = cmd_compare(a.args[0], a.args[1:])
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
