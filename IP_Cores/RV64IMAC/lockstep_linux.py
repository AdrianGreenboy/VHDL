#!/usr/bin/env python3
"""lockstep_linux.py - arranque de OpenSBI + Linux en el SoC RTL (tb_soc) en lockstep
contra el ISS, instruccion a instruccion, con la traza por una FIFO (sin disco).
Uso: lockstep_linux.py --sbi fw_jump.bin --kernel Image [--max-cycles N]
"""
import argparse, os, subprocess, sys, tempfile, time
HERE = os.environ.get('RV64_HOME', os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iss64, compare

ap = argparse.ArgumentParser()
ap.add_argument('--sbi', required=True)
ap.add_argument('--kernel', required=True)
ap.add_argument('--mem-mb', type=int, default=128)
ap.add_argument('--max-cycles', type=int, default=400_000_000)
ap.add_argument('--maxlat', type=int, default=1)
ap.add_argument('--tick-div', type=int, default=100)
a = ap.parse_args()
SIM = os.environ.get('RV64_SIM', os.path.join(HERE, 'sim'))

bus = iss64.Bus(ram_size=a.mem_mb << 20)
bus.rom = open(os.path.join(HERE, 'sw', 'bootrom', 'bootrom.bin'), 'rb').read().ljust(4096, b'\0')
for path, addr in ((a.sbi, 0x80000000), (a.kernel, 0x80200000)):
    d = open(path, 'rb').read()
    bus.ram[addr - bus.ram_base:addr - bus.ram_base + len(d)] = d
tmp = tempfile.mkdtemp(prefix='rv64lx_')
hexf, fifo = os.path.join(tmp, 'linux.hex'), os.path.join(tmp, 'trace.fifo')
with open(hexf, 'w') as f:
    ram = bus.ram
    for o in range(0, 0x02000000, 8):                 # imagenes en los primeros 32 MiB
        d = int.from_bytes(ram[o:o + 8], 'little')
        if d:
            f.write(f'{0x80000000 + o:016x} {d:016x}\n')
os.mkfifo(fifo)
cmd = [os.path.join(SIM, 'tb_soc'), f'-gHEX={hexf}', f'-gTRACE={fifo}', f'-gMEM_KB={a.mem_mb * 1024}',
       f'-gTOHOST={(a.mem_mb << 20) - 64}', f'-gTIMEOUT={a.max_cycles}', f'-gMAXLAT={a.maxlat}',
       f'-gTIME_DIV={a.tick_div}', '--ieee-asserts=disable']
rtl = subprocess.Popen(cmd, cwd=SIM, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
h = iss64.Hart(bus, pc=iss64.ROM_BASE)
t0 = time.time()
shown = [0]


def report(n, hh):
    out = bytes(bus.uart_out[shown[0]:]).decode(errors='replace')
    shown[0] = len(bus.uart_out)
    if out:
        sys.stdout.write(out)
    print(f'\n  [lockstep: {n / 1e6:.0f} M retiros identicos, {time.time() - t0:.0f} s, '
          f'pc={hh.pc:#x} priv={hh.priv}]', flush=True)


with open(fifo) as f:
    n, err = compare.lockstep_stream(h, bus, f, report)
sys.stdout.write(bytes(bus.uart_out[shown[0]:]).decode(errors='replace'))
rtl.wait()
print(f'\n{"MISMATCH" if err else "FIN"}: {n} retiros comparados en {time.time() - t0:.0f} s')
if err:
    print('  ', err)
sys.exit(1 if err else 0)
