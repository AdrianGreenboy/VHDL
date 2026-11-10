#!/usr/bin/env python3
"""patch_start.py - adds register-file clearing at _start of the RTEMS riscv BSPs
(bsps/riscv/shared/start/start.S). The register file has no reset value (the RTL powers
up with all ones, the ISS with zeros), and boot_card saves callee registers before
writing them. Idempotent. The SoC boot ROM clears them as well; tb_core/tb_cpu enter at
0x8000_0000 directly. Usage: patch_start.py <rtems source tree>"""
import os, sys
p = os.path.join(sys.argv[1], 'bsps', 'riscv', 'shared', 'start', 'start.S')
s = open(p).read()
MARK = '/* RV128IMAC: clear the register file */'
if MARK in s:
    print('start.S ya parcheado')
    sys.exit(0)
anchor = 'SYM(_start):\n'
assert s.count(anchor) == 1, 'no encuentro SYM(_start) en ' + p
clear = '\t' + MARK + '\n' + ''.join(f'\tli\tx{i}, 0\n' for i in range(1, 32))
s = s.replace(anchor, anchor + clear)
open(p, 'w').write(s)
print('start.S parcheado:', p)
