#!/usr/bin/env python3
"""lockstep_linux64.py - M3: OpenSBI + Linux on the RV128IMAC SoC (tb_soc, core in RV64 mode)
in lockstep against the unmodified RV64IMAC ISS (iss64.py), one retirement at a time, with
the trace through a FIFO (no disk).

Same flow as RV64IMAC/lockstep_linux.py; the images (OpenSBI fw_jump.bin, Linux Image) are
the RV64IMAC ones, unchanged. What changes:
  * the RTL is rv128_soc with -gXLEN64=true (128-bit bus, 128-bit RAM in the TB);
  * every trace line goes through compare64.parse64: the RV64 sign-extension invariant is
    checked on pc / rd value / cause / tval and the 16-lane writes are folded to 8 lanes;
  * the boot ROM (code + DTB) is this tree's sw/bootrom/bootrom.bin.
--stop TEXT ends the run (FIN) when TEXT appears on the ISS console; by default the /init
clock message, so the run ends at user space instead of spinning in /init until the timeout.
--iss runs only the ISS with this boot ROM (a few minutes): checks the images first.

Usage: lockstep_linux64.py --sbi fw_jump.bin --kernel Image [--iss] [--max-cycles N]
"""
import argparse
import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compare64                      # noqa: E402  (patches compare.parse with the RV64 adapter)
from compare64 import iss64, c64      # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('--sbi', required=True)
ap.add_argument('--kernel', required=True)
ap.add_argument('--mem-mb', type=int, default=128)
ap.add_argument('--max-cycles', type=int, default=600_000_000)
ap.add_argument('--maxlat', type=int, default=1)
ap.add_argument('--tick-div', type=int, default=100)
ap.add_argument('--stop', default='init: el reloj avanza',
                help="end with FIN when this text reaches the console ('' = run to the timeout)")
ap.add_argument('--iss', action='store_true', help='ISS only (no RTL): validates images + boot ROM')
a = ap.parse_args()
SIM = os.environ.get('RV128_SIM', os.path.join(HERE, 'sim'))
BOOTROM = os.path.join(HERE, 'sw', 'bootrom', 'bootrom.bin')

bus = iss64.Bus(ram_size=a.mem_mb << 20)
bus.rom = open(BOOTROM, 'rb').read().ljust(4096, b'\0')
for path, addr in ((a.sbi, 0x80000000), (a.kernel, 0x80200000)):
    d = open(path, 'rb').read()
    bus.ram[addr - bus.ram_base:addr - bus.ram_base + len(d)] = d
    print(f'{os.path.basename(path)}: {len(d)} bytes at {addr:#x}')
t0 = time.time()
shown = [0]


def console():
    out = bytes(bus.uart_out[shown[0]:]).decode(errors='replace')
    shown[0] = len(bus.uart_out)
    if out:
        sys.stdout.write(out)
        sys.stdout.flush()


def stop_seen():
    return a.stop and a.stop in bytes(bus.uart_out).decode(errors='replace')


if a.iss:                                             # only the ISS, own time base
    h = iss64.Hart(bus, pc=iss64.ROM_BASE, time_div=a.tick_div)
    n = 0
    try:
        while n < a.max_cycles:
            h.step()
            n += 1
            if len(bus.uart_out) != shown[0]:
                console()
                if stop_seen():
                    break
    except iss64.ExitSim as e:
        print(f'\n[exit {e.code}]')
    console()
    print(f'\n{"FIN" if stop_seen() else "SIN /init"}: {n} instrucciones en el ISS, '
          f'{time.time() - t0:.0f} s, pc={h.pc:#x} priv={h.priv}')
    sys.exit(0 if stop_seen() else 1)

tmp = tempfile.mkdtemp(prefix='rv128lx_')
hexf, fifo = os.path.join(tmp, 'linux.hex'), os.path.join(tmp, 'trace.fifo')
with open(hexf, 'w') as f:
    ram = bus.ram
    for o in range(0, 0x02000000, 16):                # images live in the first 32 MiB
        d = int.from_bytes(ram[o:o + 16], 'little')
        if d:
            f.write(f'{0x80000000 + o:016x} {d:032x}\n')
os.mkfifo(fifo)
cmd = [os.path.join(SIM, 'tb_soc'), f'-gHEX={hexf}', f'-gTRACE={fifo}', f'-gMEM_KB={a.mem_mb * 1024}',
       f'-gTOHOST={(a.mem_mb << 20) - 64}', f'-gTIMEOUT={a.max_cycles}', f'-gMAXLAT={a.maxlat}',
       f'-gTIME_DIV={a.tick_div}', '-gXLEN64=true', '--ieee-asserts=disable']
print('RTL:', ' '.join(cmd), flush=True)
rtl = subprocess.Popen(cmd, cwd=SIM, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
h = iss64.Hart(bus, pc=iss64.ROM_BASE)
stopped = [False]


def report(n, hh):
    console()
    print(f'\n  [lockstep RV64 mode: {n / 1e6:.0f} M identical retirements, {time.time() - t0:.0f} s, '
          f'pc={hh.pc:#x} priv={hh.priv}]', flush=True)


def lines(f):
    for line in f:
        yield line
        if len(bus.uart_out) != shown[0]:
            console()
            if stop_seen():
                stopped[0] = True
                return


with open(fifo) as f:
    n, err = c64.lockstep_stream(h, bus, lines(f), report)
console()
if stopped[0]:
    rtl.kill()
rtl.wait()
if err:
    verdict = 'MISMATCH'
elif stopped[0]:
    verdict = 'FIN'
else:
    verdict = 'SIN /init (timeout del RTL)'
print(f'\n{verdict}: {n} retiros comparados en {time.time() - t0:.0f} s')
if err:
    print('  ', err)
sys.exit(0 if verdict == 'FIN' else 1)
