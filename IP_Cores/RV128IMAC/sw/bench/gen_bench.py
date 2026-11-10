#!/usr/bin/env python3
"""gen_bench.py - RV128 vs RV64 microbenchmarks on the same core (dual RV128IMAC).

Emits two programs with the same kernels, same data and same checksums:
  bench128.S  RV128 mode (rv128asm.py): 128-bit registers, LQ/SQ, AMO .Q, 128-bit MUL
  bench64.S   RV64 mode (clang): the same algorithm with 64-bit words
Kernels (each timed with rdcycle, cycles printed on the 16550, result checked):
  K1 add4096  4096-bit addition with carry chain, 64 times
  K2 memcpy   64 KiB copy, 4 times (LQ/SQ vs LD/SD, 4x unrolled)
  K3 search   64 lookups of 128-bit keys in a 1024-entry table (linear, early reject)
  K4 atomic   1000 increments of a 128-bit counter (AMOADD.Q vs spinlock + 2 words)
  K5 mul128   256 steps of a 128-bit LCG x = x*c + 1 mod 2^128 (1 MUL vs 4 MUL/MULHU)
Every timed loop starts on a 64-byte boundary in both programs, so I$ line crossings and
fetch alignment do not differ between the two modes.
Exit through tohost: 1 = all checksums right, (k << 1) | 1 = kernel k wrong.
Usage: gen_bench.py <outdir>
"""
import os, sys

M64 = (1 << 64) - 1
M128 = (1 << 128) - 1
PHI = 0x9E3779B97F4A7C15
R1, R2, R4, R5 = 64, 4, 1000, 256
NQ = 64
LCG_C = 0x2360ED051FC65DA44385DF649FCCF645
CNT0 = 0xFFFFFFFFFFFFFF00

# ---------------------------------------------------------------- reference model
A_B, B_B, SRC_B, TAB_B = 512, 512, 65536, 16384
words = [((i + 1) * PHI) & M64 for i in range((A_B + B_B + SRC_B + TAB_B) // 8)]
def take(off, n):
    return words[off // 8:(off + n) // 8]
A = take(0, A_B); B = take(A_B, B_B); SRC = take(A_B + B_B, SRC_B); TAB = take(A_B + B_B + SRC_B, TAB_B)
def big(ws): return sum(w << (64 * i) for i, w in enumerate(ws))
c = (big(A) + big(B)) & ((1 << 4096) - 1)
C = [(c >> (64 * i)) & M64 for i in range(64)]
ck1 = 0
for w in C: ck1 ^= w
ck2 = 0
for w in SRC: ck2 ^= w
keys = [(TAB[2 * i] | (TAB[2 * i + 1] << 64)) for i in range(1024)]
assert len(set(keys)) == 1024
ck3 = sum((j * 37) & 1023 for j in range(NQ))
cnt = (CNT0 + R4) & M128
ck4lo, ck4hi = cnt & M64, cnt >> 64
x = 1
for _ in range(R5):
    x = (x * LCG_C + 1) & M128
ck5lo, ck5hi = x & M64, x >> 64

# ---------------------------------------------------------------- common pieces
def common(w):
    """w = 128 or 64: word size of the registers for the main loops"""
    q = w == 128
    L, S, WB = ("lq", "sq", 16) if q else ("ld", "sd", 8)
    o = []
    e = o.append
    e("_start:")
    if not q:
        for r in range(1, 32):
            e(f"  li x{r}, 0")
    e("  la sp, stack_top")
    e("  la t0, trap")
    e("  csrw mtvec, t0")
    # fill A, B, SRC, TAB with (i + 1) * PHI mod 2^64 as 64-bit words
    e("  la t0, area_fill")
    e(f"  li t1, {(A_B + B_B + SRC_B + TAB_B) // 8}")
    e(f"  li t2, {PHI:#x}")
    e("  li t3, 0")
    e("fill_loop:")
    e("  addd t3, t3, t2" if q else "  add t3, t3, t2")
    e("  sd t3, 0(t0)")
    e("  addi t0, t0, 8")
    e("  addi t1, t1, -1")
    e("  bnez t1, fill_loop")
    # ------------------------------------------------------------ K1 add4096
    e(f"  li s1, {R1}")
    e("  csrr s0, cycle")
    e("k1_rep:")
    e("  la a0, area_fill")
    e(f"  la a1, area_fill + {A_B}")
    e("  la a2, area_c")
    e(f"  li a3, {4096 // w}")
    e("  li t6, 0")                       # carry
    e(".align 6")                         # loop at a cache-line start in both modes
    e("k1_loop:")
    e(f"  {L} t0, 0(a0)")
    e(f"  {L} t1, 0(a1)")
    e("  add t2, t0, t1")
    e("  sltu t3, t2, t0")
    e("  add t4, t2, t6")
    e("  sltu t5, t4, t2")
    e("  or t6, t3, t5")
    e(f"  {S} t4, 0(a2)")
    e(f"  addi a0, a0, {WB}")
    e(f"  addi a1, a1, {WB}")
    e(f"  addi a2, a2, {WB}")
    e("  addi a3, a3, -1")
    e("  bnez a3, k1_loop")
    e("  addi s1, s1, -1")
    e("  bnez s1, k1_rep")
    e("  csrr s2, cycle")
    e("  li a0, 1")
    e("  call report")
    e("  la a0, area_c")
    e("  li a1, 64")
    e("  call xorsum")
    e(f"  li t0, {ck1:#x}")
    e("  li a2, 1")
    e("  bne a0, t0, fail")
    # ------------------------------------------------------------ K2 memcpy
    e(f"  li s1, {R2}")
    e("  csrr s0, cycle")
    e("k2_rep:")
    e(f"  la a0, area_fill + {A_B + B_B}")
    e("  la a1, area_dst")
    e(f"  li a2, {SRC_B // (4 * WB)}")
    e(".align 6")                         # loop at a cache-line start in both modes
    e("k2_loop:")
    for k in range(4):
        e(f"  {L} t{k}, {k * WB}(a0)")
    for k in range(4):
        e(f"  {S} t{k}, {k * WB}(a1)")
    e(f"  addi a0, a0, {4 * WB}")
    e(f"  addi a1, a1, {4 * WB}")
    e("  addi a2, a2, -1")
    e("  bnez a2, k2_loop")
    e("  addi s1, s1, -1")
    e("  bnez s1, k2_rep")
    e("  csrr s2, cycle")
    e("  li a0, 2")
    e("  call report")
    e("  la a0, area_dst")
    e(f"  li a1, {SRC_B // 8}")
    e("  call xorsum")
    e(f"  li t0, {ck2:#x}")
    e("  li a2, 2")
    e("  bne a0, t0, fail")
    # ------------------------------------------------------------ K3 search
    e("  li s3, 0")                       # sum of indices found
    e("  li s4, 0")                       # j
    e("  csrr s0, cycle")
    e("k3_query:")
    e("  li t0, 37")
    e("  mul t0, s4, t0")
    e("  andi t0, t0, 1023")
    e("  slli t0, t0, 4")
    e(f"  la a0, area_fill + {A_B + B_B + SRC_B}")
    e("  add t0, a0, t0")
    if q:
        e("  lq a2, 0(t0)")              # query key
    else:
        e("  ld a2, 0(t0)")
        e("  ld a3, 8(t0)")
    e("  li a1, 0")                       # index
    e(".align 6")                         # loop at a cache-line start in both modes
    e("k3_scan:")
    if q:
        e("  lq t1, 0(a0)")
        e("  beq t1, a2, k3_hit")
    else:
        # same loop shape as RV128 (mismatch falls through: the core predicts not-taken),
        # the high word is only read when the low word matches
        e("  ld t1, 0(a0)")
        e("  beq t1, a2, k3_lo_eq")
    e("  addi a0, a0, 16")
    e("  addi a1, a1, 1")
    e("  j k3_scan")
    if not q:
        e("k3_lo_eq:")
        e("  ld t2, 8(a0)")
        e("  beq t2, a3, k3_hit")
        e("  addi a0, a0, 16")
        e("  addi a1, a1, 1")
        e("  j k3_scan")
    e("k3_hit:")
    e("  add s3, s3, a1")
    e("  addi s4, s4, 1")
    e(f"  li t0, {NQ}")
    e("  bne s4, t0, k3_query")
    e("  csrr s2, cycle")
    e("  li a0, 3")
    e("  call report")
    e(f"  li t0, {ck3}")
    e("  li a2, 3")
    e("  bne s3, t0, fail")
    # ------------------------------------------------------------ K4 atomic 128-bit counter
    e("  la a0, area_cnt")
    e(f"  li t0, {CNT0:#x}")
    e("  sd t0, 0(a0)")
    e("  sd zero, 8(a0)")
    e(f"  li s1, {R4}")
    e("  li t1, 1")
    e("  csrr s0, cycle")
    e(".align 6")                         # loop at a cache-line start in both modes
    e("k4_loop:")
    if q:
        e("  amoadd.q zero, t1, (a0)")
    else:
        e("  la a1, area_lock")
        e("k4_lock:")
        e("  amoswap.w.aq t2, t1, (a1)")
        e("  bnez t2, k4_lock")
        e("  ld t3, 0(a0)")
        e("  ld t4, 8(a0)")
        e("  addi t5, t3, 1")
        e("  sltu t6, t5, t3")
        e("  add t4, t4, t6")
        e("  sd t5, 0(a0)")
        e("  sd t4, 8(a0)")
        e("  amoswap.w.rl zero, zero, (a1)")
    e("  addi s1, s1, -1")
    e("  bnez s1, k4_loop")
    e("  csrr s2, cycle")
    e("  li a0, 4")
    e("  call report")
    e("  la a0, area_cnt")
    e("  ld t0, 0(a0)")
    e("  ld t1, 8(a0)")
    e(f"  li t2, {ck4lo:#x}")
    e(f"  li t3, {ck4hi:#x}")
    if q:  # ld sign-extends in RV128: compare the low 64 bits only
        for r in ("t0", "t1", "t2", "t3"):
            e(f"  slli {r}, {r}, 64")
    e("  li a2, 4")
    e("  bne t0, t2, fail")
    e("  bne t1, t3, fail")
    # ------------------------------------------------------------ K5 mul128 LCG
    e(f"  li s1, {R5}")
    if q:
        e(f"  li t0, {LCG_C:#x}")
        e("  li a0, 1")
    else:
        e(f"  li t0, {LCG_C & M64:#x}")    # c lo
        e(f"  li t1, {LCG_C >> 64:#x}")    # c hi
        e("  li a0, 1")                    # x lo
        e("  li a1, 0")                    # x hi
    e("  csrr s0, cycle")
    e(".align 6")                         # loop at a cache-line start in both modes
    e("k5_loop:")
    if q:
        e("  mul a0, a0, t0")
        e("  addi a0, a0, 1")
    else:
        e("  mulhu t2, a0, t0")            # hi(xlo*clo)
        e("  mul t3, a0, t1")              # xlo*chi
        e("  mul t4, a1, t0")              # xhi*clo
        e("  mul a0, a0, t0")              # lo(xlo*clo)
        e("  add t2, t2, t3")
        e("  add a1, t2, t4")
        e("  addi a0, a0, 1")
        e("  seqz t5, a0")                 # carry of +1
        e("  add a1, a1, t5")
    e("  addi s1, s1, -1")
    e("  bnez s1, k5_loop")
    e("  csrr s2, cycle")
    if q:
        e("  srli a1, a0, 64")
        e("  slli a0, a0, 64")
        e("  srli a0, a0, 64")
    e("  mv s5, a0")
    e("  mv s6, a1")
    e("  li a0, 5")
    e("  call report")
    e(f"  li t2, {ck5lo:#x}")
    e(f"  li t3, {ck5hi:#x}")
    e("  li a2, 5")
    e("  bne s5, t2, fail")
    e("  bne s6, t3, fail")
    e("  li a0, 1")
    e("  j finish")
    e("fail:")
    e("  slli a0, a2, 1")
    e("  ori a0, a0, 1")
    e("finish:")
    e("  la t0, tohost")
    e("  sd a0, 0(t0)")
    e("hang:")
    e("  j hang")
    e("trap:")
    e("  li a2, 9")
    e("  j fail")
    # ---- xorsum(a0 = address, a1 = 64-bit words): XOR of the words, low 64 bits
    e("xorsum:")
    e("  li t0, 0")
    e("xs_loop:")
    e("  ld t1, 0(a0)")
    e("  xor t0, t0, t1")
    e("  addi a0, a0, 8")
    e("  addi a1, a1, -1")
    e("  bnez a1, xs_loop")
    if q:
        e("  slli t0, t0, 64")
        e("  srli t0, t0, 64")
    e("  mv a0, t0")
    e("  ret")
    # ---- report(a0 = kernel): "K<n> <cycles hex>\n", cycles = s2 - s0
    e("report:")
    e("  mv t5, ra")
    e("  addi t6, a0, 48")
    e("  li a0, 75")
    e("  call putc")
    e("  mv a0, t6")
    e("  call putc")
    e("  li a0, 32")
    e("  call putc")
    e("  sub t6, s2, s0")
    e("  li t4, 60")
    e("rp_loop:")
    e("  srl a0, t6, t4")
    e("  andi a0, a0, 15")
    e("  li t3, 10")
    e("  blt a0, t3, rp_dig")
    e("  addi a0, a0, 39")
    e("rp_dig:")
    e("  addi a0, a0, 48")
    e("  call putc")
    e("  addi t4, t4, -4")
    e("  bge t4, zero, rp_loop")
    e("  li a0, 10")
    e("  call putc")
    e("  mv ra, t5")
    e("  ret")
    e("putc:")                            # 16550, polled
    e("  li t2, 0x10000000")
    e("pc_wait:")
    e("  lbu t1, 5(t2)")
    e("  andi t1, t1, 32")
    e("  beqz t1, pc_wait")
    e("  sb a0, 0(t2)")
    e("  ret")
    return o


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    hdr = ["# generated by gen_bench.py - RV128 vs RV64 microbenchmarks (do not edit)"]
    # RV128 (rv128asm): data in the image
    o = hdr + common(128)
    o += [".align 6", "tohost:", "  .dword 0, 0", ".align 6", "fromhost:", "  .dword 0, 0",
          ".align 6", "area_fill:", f"  .zero {A_B + B_B + SRC_B + TAB_B}",
          ".align 6", "area_c:", "  .zero 512", ".align 6", "area_dst:", f"  .zero {SRC_B}",
          ".align 6", "area_cnt:", "  .zero 16", "area_lock:", "  .zero 16",
          ".align 4", "  .zero 4096", "stack_top:"]
    open(os.path.join(out, 'bench128.S'), 'w').write('\n'.join(o) + '\n')
    # RV64 (clang): data in .bss
    o = hdr + ["  .section .text.init, \"ax\"", "  .globl _start", "  .option norelax"] + common(64)
    o += ["  .section .tohost, \"aw\", @progbits", "  .align 6", "  .globl tohost", "tohost: .dword 0, 0",
          "  .align 6", "  .globl fromhost", "fromhost: .dword 0, 0",
          "  .bss", "  .align 6", f"area_fill: .space {A_B + B_B + SRC_B + TAB_B}",
          "  .align 6", "area_c: .space 512", "  .align 6", f"area_dst: .space {SRC_B}",
          "  .align 6", "area_cnt: .space 16", "area_lock: .space 16",
          "  .align 4", "  .space 4096", "stack_top:"]
    open(os.path.join(out, 'bench64.S'), 'w').write('\n'.join(o) + '\n')
    print(f"checksums: k1={ck1:#x} k2={ck2:#x} k3={ck3} k4={cnt:#x} k5={x:#x}")


if __name__ == '__main__':
    main()
