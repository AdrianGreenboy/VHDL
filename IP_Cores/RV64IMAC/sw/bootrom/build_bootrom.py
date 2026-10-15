#!/usr/bin/env python3
"""build_bootrom.py - DTS -> DTB, boot.S -> binario, y genera rv64_bootrom_pkg.vhd
(ROM sincrona canonica de 512 x 64 bit) y bootrom.bin para el ISS."""
import argparse, os, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('--dts', default=os.path.join(H, 'rv64_soc.dts'), help='rv64_soc.dts (simulacion) o rv64_soc_fpga.dts')
ap.add_argument('--out', default=os.path.join(H, '..', '..', 'rtl', 'rv64_bootrom_pkg.vhd'))
args = ap.parse_args()
OUT_VHD = args.out
dtb = os.path.join(H, os.path.splitext(os.path.basename(args.dts))[0] + '.dtb')
subprocess.run(['dtc', '-I', 'dts', '-O', 'dtb', '-o', dtb, args.dts], check=True, stderr=subprocess.DEVNULL)
elf = os.path.join(H, 'boot.elf')
subprocess.run(['clang', '--target=riscv64-unknown-elf', '-march=rv64imac_zicsr', '-mabi=lp64', '-mno-relax',
                '-nostdlib', '-static', '-fuse-ld=lld', f'-DDTB_FILE="{dtb}"', '-Wl,-Ttext=0x1000',
                '-Wl,--no-relax', os.path.join(H, 'boot.S'), '-o', elf], check=True)
binf = os.path.join(H, 'bootrom.bin' if args.dts.endswith('rv64_soc.dts') else 'bootrom_fpga.bin')
subprocess.run(['llvm-objcopy', '-O', 'binary', '-j', '.text', elf, binf], check=True)
data = open(binf, 'rb').read()
assert len(data) <= 4096, f'boot ROM de {len(data)} bytes > 4 KiB'
data += bytes(4096 - len(data))
words = [int.from_bytes(data[i:i + 8], 'little') for i in range(0, 4096, 8)]
with open(OUT_VHD, 'w') as f:
    f.write('-- rv64_bootrom_pkg.vhd - GENERADO por sw/bootrom/build_bootrom.py (no editar).\n')
    f.write('-- Contenido de la boot ROM (codigo + DTB). Se lee con una ROM sincrona canonica.\n')
    f.write('library ieee;\nuse ieee.std_logic_1164.all;\n\npackage rv64_bootrom_pkg is\n')
    f.write('  type bootrom_t is array (0 to 511) of std_logic_vector(63 downto 0);\n')
    f.write('  constant BOOTROM : bootrom_t := (\n')
    f.write(',\n'.join(f'    x"{w:016x}"' for w in words))
    f.write('\n  );\nend package;\n')
print(f'boot ROM: {len(open(binf, "rb").read())} bytes de 4096')
