#!/usr/bin/env python3
"""compare_spike.py - valida el ISS contra Spike (oraculo de referencia).

Ejecuta el ELF en Spike con --log-commits y en iss64.py, y compara retiro a
retiro: PC, registro destino y valor, y cada excepcion (causa, epc, tval).
Las lecturas de contadores (cycle/time/mcycle) se copian de Spike.
Solo para programas sin interrupciones asincronas.

Diferencias conocidas y legales (no son errores del ISS):
  * rv64mi-p-ma_fetch: Spike permite borrar misa.C; nuestro misa es de solo lectura.
  * rv64ua-p-lrsc: Spike rompe las reservas cada 5000 instrucciones (cuanto de su
    planificador): fallo espurio de SC, permitido por la spec.
"""
import os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iss64
from iss64 import Bus, Hart, load_elf, ExitSim

SPIKE = os.environ.get('SPIKE') or __import__('shutil').which('spike') or 'spike'
# Spike con PMP=0 hace ilegales los CSR de PMP; nosotros los dejamos de solo lectura a cero
# (la spec permite ambas). Se ejecuta Spike con regiones y se copian sus lecturas.
ARGS = ['--isa=rv64imac_zicsr_zifencei_zicntr_zihpm_zicbom', '--priv=msu', '--pmpregions=16', '--triggers=0']
# MMU Sv39 (Spike usa Sv57 por defecto): DTB generado con --dump-dts y mmu-type cambiado
DTB = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sim', 'spike_sv39.dtb')
ARGS.append(f'--dtb={DTB}')
CAUSES = {'instruction_address_misaligned': 0, 'instruction_access_fault': 1, 'illegal_instruction': 2,
          'breakpoint': 3, 'load_address_misaligned': 4, 'load_access_fault': 5,
          'store_address_misaligned': 6, 'store_access_fault': 7, 'user_ecall': 8,
          'supervisor_ecall': 9, 'machine_ecall': 11, 'instruction_page_fault': 12,
          'load_page_fault': 13, 'store_page_fault': 15}
NONDET = {0xC00, 0xC01, 0xB00, 0x344, 0x144, 0xF11, 0xF12, 0xF13} | set(range(0x3A0, 0x3F0))  # + mip/sip: CLINT distinto
# mstatus/sstatus: FS (y por tanto SD) es opcionalmente escribible sin F si hay S-mode.
# Spike lo hace escribible; nosotros solo lectura a cero. Se comparan el resto de bits.
MASKED = {0x300: ~((1 << 63) | (3 << 13)), 0x100: ~((1 << 63) | (3 << 13)),
          0x302: ~(1 << 19),                      # medeleg[19]: causa 19 no implementada
          0x320: 0x7}                             # mcountinhibit: hpm 3-31 a cero (no hay)
RE_COMMIT = re.compile(r'core\s+0: (\d) 0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)')
RE_EXC = re.compile(r'core\s+0: exception (interrupt #\d+|\w+), epc 0x([0-9a-f]+)')
RE_TVAL = re.compile(r'core\s+0:\s+tval 0x([0-9a-f]+)')


PRE = [0]


def spike_events(elf, max_insn):
    p = subprocess.Popen([SPIKE] + ARGS + ['-l', '--log-commits', elf],
                         stderr=subprocess.PIPE, stdout=subprocess.DEVNULL, text=True)
    started = False
    pend = None                                   # excepcion esperando su linea de tval
    for line in p.stderr:
        if pend is not None:
            m = RE_TVAL.match(line)
            yield ('e', pend[0], pend[1], int(m.group(1), 16) if m else 0)
            pend = None
            if m:
                continue
        m = RE_COMMIT.match(line)
        if m:
            pc = int(m.group(2), 16)
            if not started and pc < 0x80000000:
                PRE[0] += 1                       # boot ROM de Spike: cuenta en minstret
                continue
            started = True
            rest = m.group(4)
            w = re.search(r'\bx(\d+)\s+0x([0-9a-f]+)', rest)
            yield ('c', pc, int(w.group(1)) if w else 0, int(w.group(2), 16) if w else 0)
            continue
        m = RE_EXC.match(line)
        if m and started:
            name = m.group(1).replace('trap_', '')
            if name.startswith('interrupt'):
                cause = (1 << 63) | int(name.split('#')[1])
            else:
                cause = CAUSES.get(name, name)
            pend = (int(m.group(2), 16), cause)
    p.wait()


def main():
    elf = sys.argv[1]
    max_insn = int(sys.argv[2]) if len(sys.argv) > 2 else 3_000_000
    bus = Bus()
    entry, _ = load_elf(bus, elf)
    h = Hart(bus, pc=entry)
    n = 0
    first = True
    for ev in spike_events(elf, max_insn):
        if first:
            h.minstret = PRE[0]
            first = False
        try:
            pc, insn, rd, val, trap = h.step()
        except ExitSim as e:
            print(f'PASS {os.path.basename(elf)} pasos={n} (exit {e.code})')
            return 0
        insn32 = insn if insn & 3 == 3 else (iss64.expand_c(insn) or 0)
        is_nd = insn32 & 0x7F == 0x73 and (insn32 >> 12) & 3 and (insn32 >> 20) in NONDET
        if trap:
            exp = ('e', pc, trap[0], trap[1])
        else:
            exp = ('c', pc, rd, val)
        got = ev
        if is_nd and got[0] == 'c' and exp[0] == 'c' and got[2] == rd:
            h.x[rd] = got[3]
            exp = got
        csr = insn32 >> 20 if insn32 & 0x7F == 0x73 and (insn32 >> 12) & 3 else None
        if csr in MASKED and got[0] == 'c' and exp[0] == 'c' and got[2] == rd and rd and \
                (got[3] & MASKED[csr]) == (exp[3] & MASKED[csr] & ((1 << 64) - 1)):
            h.x[rd] = got[3]
            exp = got
        if got[0] == 'c' and exp[0] == 'c' and got[2] == 0 and exp[2] == 0:
            exp = got
        if exp != got:
            def f(e):
                return (f'{e[0]} pc={e[1]:x} ' + (f'causa={e[2]} tval={e[3]:x}' if e[0] == 'e'
                        else f'x{e[2]}={e[3]:x}'))
            print(f'DIVERGE {os.path.basename(elf)} paso {n}\n  spike: {f(got)}\n  iss:   {f(exp)}'
                  f'  insn={insn:08x}')
            return 1
        n += 1
    print(f'FIN-SPIKE {os.path.basename(elf)} pasos={n}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
