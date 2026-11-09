#!/usr/bin/env python3
"""run_iss.py - runs an RTOS ELF (FreeRTOS, ...) on the RV64IMAC ISS (iss64.py) and shows
the 16550 console. Layer 0 for the M4 RTOS images. Exit code 0 only on tohost PASS.
Usage: run_iss.py elf [--max N] [--time-div D]"""
import argparse, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
RV64 = os.environ.get('RV64_HOME', os.path.normpath(os.path.join(HERE, '..', '..', '..', 'RV64IMAC')))
sys.path.insert(0, RV64)
import iss64  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('elf')
ap.add_argument('--max', type=int, default=20_000_000)
ap.add_argument('--time-div', type=int, default=4, help='cycles per mtime tick (as tb_* -gTIME_DIV)')
a = ap.parse_args()
bus = iss64.Bus()
entry, syms = iss64.load_elf(bus, a.elf)
h = iss64.Hart(bus, pc=entry, time_div=a.time_div)
t0 = time.time()
code = None
try:
    while h.steps < a.max:
        h.step()
except iss64.ExitSim as e:
    code = e.code
sys.stdout.write(bytes(bus.uart_out).decode(errors='replace'))
v = 'PASS' if code == 0 else ('TIMEOUT' if code is None else f'FAIL code={code}')
print(f'{v} {os.path.basename(a.elf)}  instr={h.steps}  {time.time() - t0:.0f} s')
sys.exit(0 if code == 0 else 1)
