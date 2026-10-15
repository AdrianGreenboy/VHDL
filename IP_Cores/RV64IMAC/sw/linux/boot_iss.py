#!/usr/bin/env python3
"""boot_iss.py - arranque del SoC en el ISS: boot ROM -> OpenSBI -> Linux.

Carga la boot ROM (codigo + DTB), OpenSBI fw_jump en 0x8000_0000 y, si se da, la
imagen del kernel en 0x8020_0000. Muestra la consola (UART 16550 del ISS).
Uso: boot_iss.py --sbi fw_jump.bin [--kernel Image] [--max N] [--time-div D]
"""
import argparse, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..'))
import iss64

ap = argparse.ArgumentParser()
ap.add_argument('--sbi', required=True)
ap.add_argument('--kernel')
ap.add_argument('--initrd')
ap.add_argument('--max', type=int, default=50_000_000)
ap.add_argument('--time-div', type=int, default=4)
ap.add_argument('--ram-mb', type=int, default=256)
ap.add_argument('--stop', default=None, help='parar al ver este texto en la consola')
a = ap.parse_args()

bus = iss64.Bus(ram_size=a.ram_mb << 20)
bus.rom = open(os.path.join(HERE, '..', 'bootrom', 'bootrom.bin'), 'rb').read().ljust(4096, b'\0')


def load(path, addr):
    d = open(path, 'rb').read()
    o = addr - bus.ram_base
    bus.ram[o:o + len(d)] = d
    return len(d)


print(f'OpenSBI: {load(a.sbi, 0x80000000)} bytes en 0x80000000')
if a.kernel:
    print(f'kernel:  {load(a.kernel, 0x80200000)} bytes en 0x80200000')
h = iss64.Hart(bus, pc=iss64.ROM_BASE, time_div=a.time_div)
t0 = time.time()
shown = 0
try:
    for n in range(a.max):
        h.step()
        if len(bus.uart_out) != shown:
            sys.stdout.write(bytes(bus.uart_out[shown:]).decode(errors='replace'))
            sys.stdout.flush()
            shown = len(bus.uart_out)
            if a.stop and a.stop in bytes(bus.uart_out).decode(errors='replace'):
                break
except iss64.ExitSim as e:
    print(f'\n[exit {e.code}]')
dt = time.time() - t0
print(f'\n[{h.steps} instrucciones en {dt:.0f} s, {h.steps / dt:.0f} instr/s, pc={h.pc:#x} priv={h.priv}]')
