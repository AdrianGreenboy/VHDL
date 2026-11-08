#!/usr/bin/env python3
"""qemu_check.py - capa 0b: el ISS (iss128.py) contra QEMU x-rv128, independiente.

Para cada programa (prefijo <prog>.bin/.sym) ejecuta el ISS y QEMU
(qemu-system-riscv64 -M virt -cpu x-rv128, carga en 0x8000_0000, salida por la
UART 16550 y fin por sifive_test) y exige el mismo veredicto y la misma salida
de UART byte a byte (los programas aleatorios vuelcan registros y memoria).

Uso: qemu_check.py [--qemu BIN] prog...
"""
import argparse
import os
import subprocess
import sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import iss128


def run_qemu(qemu, binpath, timeout):
    cmd = [qemu, '-M', 'virt', '-cpu', 'x-rv128', '-accel', 'tcg,thread=single', '-m', '256M', '-bios', 'none',
           '-display', 'none', '-monitor', 'none', '-serial', 'stdio',
           '-device', f'loader,file={binpath},addr=0x80000000']
    try:
        p = subprocess.run(cmd, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None, b'', b''
    return p.returncode, p.stdout, p.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('prog', nargs='+')
    ap.add_argument('--qemu', default=os.environ.get('QEMU', 'qemu-system-riscv64'))
    ap.add_argument('--timeout', type=int, default=60)
    a = ap.parse_args()
    bad = 0
    for p in a.prog:
        code, h = iss128.run_flat(p + '.bin', p + '.sym', 20_000_000)
        iss_out = bytes(h.bus.uart_out)
        qrc, q_out, q_err = run_qemu(a.qemu, p + '.bin', a.timeout)
        iss_v = 'PASS' if code == 0 else f'FAIL({code})'
        q_v = 'TIMEOUT' if qrc is None else ('PASS' if qrc == 0 else f'FAIL({qrc})')
        same = iss_out == q_out
        ok = iss_v == 'PASS' and q_v == 'PASS' and same
        if not ok:
            bad += 1
        print(f'{"IGUAL" if ok else "DIVERGE":8} {os.path.basename(p):24} ISS={iss_v} QEMU={q_v} '
              f'uart={"igual" if same else "distinta"} ({len(iss_out)} B)')
        if qrc not in (0, None) and q_err:
            print('    QEMU stderr: ' + q_err.decode(errors='replace').strip()[:400])
        if not same:
            il, ql = iss_out.decode(errors='replace').splitlines(), q_out.decode(errors='replace').splitlines()
            for k in range(max(len(il), len(ql))):
                x = il[k] if k < len(il) else '<fin>'
                y = ql[k] if k < len(ql) else '<fin>'
                if x != y:
                    print(f'    primera diferencia en la linea {k + 1} (x{k + 1} si k<31):\n      ISS  {x}\n      QEMU {y}')
                    break
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
