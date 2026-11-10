#!/usr/bin/env python3
"""build_bootrom.py - DTS -> DTB, boot.S -> binario, y genera rv128_bootrom_pkg.vhd
(ROM sincrona canonica de 256 x 128 bit) y bootrom.bin para los ISS (iss128/iss64).
Mismo flujo que el RV64IMAC (clang + lld + dtc). boot.S se ensambla como RV64: el
codigo es valido sin cambios en los dos modos del core dual."""
import argparse, os, subprocess
H = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('--dts', default=os.path.join(H, 'rv128_soc.dts'), help='rv128_soc.dts (simulacion) o rv128_soc_fpga.dts')
ap.add_argument('--out', default=os.path.join(H, '..', '..', 'rtl', 'rv128_bootrom_pkg.vhd'))
args = ap.parse_args()
OUT_VHD = args.out
os.makedirs(os.path.dirname(os.path.abspath(OUT_VHD)), exist_ok=True)
dtb = os.path.join(H, os.path.splitext(os.path.basename(args.dts))[0] + '.dtb')
subprocess.run(['dtc', '-I', 'dts', '-O', 'dtb', '-o', dtb, args.dts], check=True, stderr=subprocess.DEVNULL)
elf = os.path.join(H, 'boot.elf')
subprocess.run(['clang', '--target=riscv64-unknown-elf', '-march=rv64imac_zicsr', '-mabi=lp64', '-mno-relax',
                '-nostdlib', '-static', '-fuse-ld=lld', f'-DDTB_FILE="{dtb}"', '-Wl,-Ttext=0x1000',
                '-Wl,--no-relax', os.path.join(H, 'boot.S'), '-o', elf], check=True)
binf = os.path.join(H, 'bootrom.bin' if args.dts.endswith('rv128_soc.dts') else 'bootrom_fpga.bin')
subprocess.run(['llvm-objcopy', '-O', 'binary', '-j', '.text', elf, binf], check=True)
data = open(binf, 'rb').read()
assert len(data) <= 4096, f'boot ROM de {len(data)} bytes > 4 KiB'
data += bytes(4096 - len(data))
words = [int.from_bytes(data[i:i + 16], 'little') for i in range(0, 4096, 16)]
with open(OUT_VHD, 'w') as f:
    f.write('-- rv128_bootrom_pkg.vhd - GENERADO por sw/bootrom/build_bootrom.py (no editar).\n')
    f.write('-- Contenido de la boot ROM (codigo + DTB). Se lee con una ROM sincrona canonica.\n')
    f.write('library ieee;\nuse ieee.std_logic_1164.all;\n\npackage rv128_bootrom_pkg is\n')
    f.write('  type bootrom_t is array (0 to 255) of std_logic_vector(127 downto 0);\n')
    f.write('  constant BOOTROM : bootrom_t := (\n')
    f.write(',\n'.join(f'    x"{w:032x}"' for w in words))
    f.write('\n  );\nend package;\n')
print(f'boot ROM: {len(open(binf, "rb").read())} bytes de 4096')
