# RV128IMAC — experimental 128-bit RISC-V core for the IP_Cores family

**Status: experimental. v0.4: dual-XLEN core (RV128 / RV64 selected at reset) with
M/S/U, Sv39 MMU (RV64 mode) and the full RV64IMAC CSR set; see `doc/RV128IMAC_ISA.md` §0.
v0.4 adds the RV64IMAC memory system and SoC widened to 128 bit: I$/D$ (16 KiB, 2-way,
64 B lines), a 128-bit AXI4 master, and the SoC (CLINT, PLIC, UART 16550, 16 MMIO slots,
AXI4-Lite window, boot ROM), same map and same behaviour as the RV64IMAC SoC.** RV128I is a draft base ISA
(v1.7) that the RISC-V manual removed after release 20240411. This core is a
research line next to the production RV64IMAC; it goes to production only if it
proves something worth having.

The core is a fork of the RV64IMAC 5-stage pipeline (verified in lockstep up to
Linux), cut down to stay compact: machine mode only, no MMU/TLB/PTW, no Zicbom,
no caches inside the core. What changes is the width: 128-bit registers, ALU,
PC and data port, plus the RV128 instructions.

## What is new compared to RV64IMAC

| Item | RV128IMAC v0 |
|---|---|
| ISA | RV128I draft 1.7 + M + A + C (RV128C) + Zicsr + Zifencei, see `doc/RV128IMAC_ISA.md` |
| New instructions | LQ, SQ, LDU, `*D` ops (ADDID, SLLID, SRLID, SRAID, ADDD, SUBD, SLLD, SRLD, SRAD, MULD, DIVD, DIVUD, REMD, REMUD), AMO/LR/SC `.Q` (our encoding, funct3=100), C.LQ/C.SQ/C.LQSP/C.SQSP |
| Changed semantics | 7-bit shifts; `*W` and `*D` sign-extend to bit 127; C.SLLI/C.SRLI/C.SRAI shamt 0 = 64, right shifts sign-extended (1–31, 64, 96–127) |
| Privilege | M only; CSR list in the spec §5 |
| Data port | 128 bit, 16 lanes: LQ/SQ/AMO.Q in one transaction |
| Instruction port | 32 bit (unchanged) |
| M unit | iterative, no DSP (ASIC-portable, like the family) |
| Address map | RV64IMAC SoC map; bits 127:32 must be zero |

No compiler exists for RV128, so `rv128asm.py` (two-pass assembler, explicit
`c.*` mnemonics) is the toolchain, and the tests are generated in Python.

## Layout

```
doc/RV128IMAC_ISA.md   ISA pinned for this core (encodings, CSRs, PMAs, microarchitecture)
rv128asm.py            assembler: .S -> .bin (+ .sym with labels, tohost)
iss128.py              Python ISS, the oracle (same API as iss64.py)
compare128.py          lockstep comparator RTL vs ISS (layers 2/3)
run_regression.sh      all layers in one command, log in sim/regression.log
rtl/rv128_pkg.vhd      types, decoder, RV128C expander, ALU, PMAs
rtl/rv128_core.vhd     5-stage pipeline
rtl/rv128_csr.vhd      M-mode CSRs, traps, interrupts
rtl/rv128_muldiv.vhd   iterative M unit
rtl/rv128_icache.vhd   I$ 16 KiB 2-way, 64 B lines (512 x 128 data SRAM per way)
rtl/rv128_dcache.vhd   D$ 16 KiB 2-way write-back, AMO W/D/Q, fence.i clean, Zicbom (RV64 mode)
rtl/rv128_axi_master.vhd  AXI4 master, 128-bit data / 64-bit address, lines = 4 x 16 B INCR
rtl/rv128_cpu.vhd      core + I$ + D$ + AXI4 master
rtl/rv128_soc.vhd      SoC: CPU + crossbar + rv128_periph (CLINT, PLIC, UART, MMIO slots, AXI-Lite, ROM)
rtl/rv128_periph.vhd   peripheral bridge: 128-bit AXI4 slave folded to the 64-bit RV64IMAC devices
sw/bootrom/            boot ROM (same code as RV64IMAC, valid in both modes) + DTS (RV64 mode)
sw/gen_cache_stress.py cache stress for RV128 mode (layer 3b)
tb/tb_cpu.vhd          layer 3b: CPU with caches vs a random-delay AXI4 slave
tb/tb_soc.vhd          layer 4b: SoC from the boot ROM, real IP_Cores USART + DMA, AXI-Lite bank
compare64.py           RV64 mode vs the unmodified iss64.py (--tb core|cpu|soc)
lockstep_linux64.py    M3: OpenSBI + Linux (RV64IMAC images) on the SoC in RV64 mode, lockstep vs iss64
tb/tb_rvc.vhd          layer 1: RV128C expander, exhaustive (49 152 encodings)
tb/tb_muldiv.vhd       layer 1: M unit, Q/D/W, corner + random vectors
tb/tb_core.vhd         layers 2/3: core with ideal / random-latency memory, CLINT, UART, HTIF
sw/gen_isa_tests.py    self-checking directed tests (12 groups)
sw/gen_random.py       random programs (register + memory dump over the UART)
sw/qemu_check.py       layer 0b: ISS vs QEMU x-rv128, an independent oracle
sim/build.sh           GHDL build (llvm or gcc backend)
```

## Verification plan

| Layer | What | Oracle |
|---|---|---|
| 0 | every generated test passes on the ISS | expected values from a separate reference model in `gen_isa_tests.py` |
| 0b | ISS vs QEMU `x-rv128`: same verdict and byte-identical UART dump | QEMU (independent implementation); groups QEMU does not model (AMO.Q, CSR/trap details, misaligned traps) are excluded |
| 1 | RV128C expander, all 49 152 encodings; M unit, Q/D/W | ISS |
| 2 | lockstep, ideal memory: pc, insn, rd/value, trap/cause/tval, store addr/lanes/data, interrupt legality and liveness | ISS |
| 3 | lockstep with random ready and 1–12 cycle latency | ISS |
| 3b | lockstep through I$/D$ + AXI4 128 with random delays on all 5 channels; cache stress | ISS |
| 4 | FPGA prototype top in simulation | ISS |
| 4b | full SoC booting from the boot ROM (RV128 mode: all tests) | ISS |
| 5 | RV64 mode vs `iss64.py`: riscv-tests p/v + RV64IMAC directed tests, on core, cpu (+ cache_stress) and soc (+ soc_usart/dma/timer/plic, cbo_test) | iss64 (RV64IMAC oracle) |

Not done yet: mutation testing; the riscv-tests -p- batch on the board.

## Running

Requirements: Python 3, GHDL with llvm or gcc backend, optionally
`qemu-system-riscv64` ≥ 7.0 (for `x-rv128`).

```bash
cd IP_Cores/RV128IMAC
./run_regression.sh            # full; 'rapida' runs one random-latency config
tail -f sim/regression.log     # follow everything live from another terminal
```

Single steps:

```bash
sw/build_tests.sh                          # generate + assemble sw/tests/*.S
python3 iss128.py sw/tests/rv128ui_alu     # one test on the ISS (--trace for a retire trace)
python3 sw/qemu_check.py sw/tests/rndq_1   # one program, ISS vs QEMU
sim/build.sh
python3 compare128.py --keep sw/tests/rv128uc   # lockstep, keeps sim/*.trace for debugging
```

## M3: Linux in RV64 mode

The RV64IMAC images run unchanged (OpenSBI 1.6 `fw_jump.bin`, Linux 6.6 `Image` from
`RV64IMAC/sw/linux/build_linux.sh`); only the boot ROM / DTB is this tree's.

```bash
python3 lockstep_linux64.py --iss --sbi fw_jump.bin --kernel Image   # ISS only, minutes
python3 lockstep_linux64.py --sbi fw_jump.bin --kernel Image         # RTL SoC in lockstep, hours
```

M3 result (2026-11-09): boot ROM -> OpenSBI 1.6 -> Linux 6.6 -> `/init` on the RTL SoC
(rv128_soc, RV64 mode, 128-bit bus), 37 495 304 retirements identical to iss64.py,
sign-extension invariant held on every line; 9380 s of GHDL simulation.

## M4: RTOS in RV64 mode

`sw/freertos/`: FreeRTOS V11.1.0 (machine mode, CLINT tick, heap_4) with a self-checking
test: queue, mutex, deterministic priority inheritance, counting semaphore, task
notifications, auto-reload software timer, `xTaskDelayUntil` exactness, `ecall` yield.
Report on the 16550, verdict through `tohost`. Layer 6 of the regression runs it on the
ISS (three tick rates) and in lockstep on core, cpu and soc.

```bash
git clone --depth 1 --branch V11.1.0 https://github.com/FreeRTOS/FreeRTOS-Kernel.git ~/FreeRTOS-Kernel
sw/freertos/build.sh
python3 sw/freertos/run_iss.py sw/freertos/freertos_test
python3 compare64.py --tb soc --timeout 20000000 sw/freertos/freertos_test
```

`sw/zephyr/`: out-of-tree Zephyr module (v4.4.0, SDK 1.0.1) with the board `rv128imac_soc`
and SoC `rv128imac` (machine mode, CLINT timer, PLIC, ns16550, 8 MiB, own `__reset` that
clears the register file). ztest runs end through `tohost` (`TC_END_REPORT` override,
`arch_system_halt` on fatal errors). Layer 6b builds `tests/kernel/common` and
`tests/kernel/queue` and runs them on the ISS and in lockstep.

```bash
source /data/adrian/zephyrproject/.venv/bin/activate
ZEPHYR_BASE=/data/adrian/zephyrproject/zephyr sw/zephyr/build.sh
python3 sw/freertos/run_iss.py sw/zephyr/out/queue.elf
python3 compare64.py --tb soc --timeout 200000000 sw/zephyr/out/queue.elf
```

`sw/rtems/`: RTEMS 6.2, BSP `riscv/rv64imac` configured for the SoC (`config.ini.in`):
DTB compiled into the BSP (`rv128imac_soc_rtems.dts`), 8 MiB RAM, console at 6.25 Mbaud,
`start.S` patched to clear the register file (`patch_start.py`). `init.c` is a
self-checking Classic API test (message queue, priority inheritance, counting semaphore,
events from a timer service routine, rate monotonic periods); a fatal extension turns
`exit()` into the `tohost` verdict.

```bash
sw/rtems/build_toolchain.sh        # once: RSB 6/rtems-riscv into /data/adrian/rtems/6
sw/rtems/build.sh                  # BSP (when its config changes) + rtems_test.exe
python3 sw/freertos/run_iss.py sw/rtems/rtems_test.exe
```

## M5: SoC on the TE0950

`fpga/soc/`: `rv128_soc_top` (SoC + DDR remap + control bank with mode select and a
`tohost` watcher on the retirement trace), Verilog wrapper, `create_project.tcl`,
`bd_insert.tcl` (NoC input at 128 bit), `rv128_soc_load.c` (A72 loader), `board_pack.sh`
and `run_all.sh`. Same flow as the RV64IMAC SoC that boots Linux on the board; see
`fpga/soc/BOARD_GUIDE.md`.

M5 result (2026-11-10, TE0950 / VE2302, Vivado 2025.2.1, 50 MHz, WNS +1.83 ns, 26.3 k LUT,
12.4 k FF, 8 BRAM36, 0 DSP; NoC input 128 bit): from the boot ROM and the LPDDR4 through
I$/D$ and the 128-bit AXI4 master, 34/34 programs pass on silicon (30 in RV128 mode,
FreeRTOS, Zephyr queue + common and RTEMS in RV64 mode), and OpenSBI 1.6 + Linux 6.6
reach `/init` in 1.21 s with the console on ttyS0.

## Performance: CoreMark and RV128 vs RV64

`sw/coremark/`: the RV64IMAC CoreMark port with the console on the 16550 (the board
watcher would take an HTIF putchar for the end of the run). `sw/bench/`: the same five
kernels written for RV128 mode (rv128asm) and RV64 mode (clang), same data and checksums,
cycles from `rdcycle`: 4096-bit add, 64 KiB memcpy, 128-bit key search, 128-bit atomic
counter, 128-bit LCG multiply. `run_bench.py` runs both on tb_cpu/tb_soc in lockstep and
prints the cycles; `fpga/soc/board_pack.sh` stages them for the board.

Results (2026-11-10). CoreMark 1.0 on the TE0950, RV64 mode, 50 MHz, 600 iterations,
"Correct operation validated": 560 465 880 ticks, 53.5 iterations/s = **1.07 CoreMark/MHz**,
the same as the RV64IMAC (the dual core costs nothing in RV64 mode). riscv-tests -p- on the
board: 109/109 (pmpaddr and ma_data waived by the spec, as in the RV64IMAC).

RV128 vs RV64 on the same silicon (cycles RV64 / cycles RV128; loops aligned to 64 B):

| Kernel | RTL (tb_cpu) | Board (LPDDR4) |
|---|---|---|
| 4096-bit add | 1.93x | ~1.9x (RV64 line partly lost on the console) |
| 64 KiB memcpy | 1.34x | 1.24x |
| 128-bit key search | 1.00x | 1.00x |
| 128-bit atomic counter (AMOADD.Q vs lock) | 3.33x | 3.32x |
| 128-bit LCG multiply | 2.05x | 2.05x |

RV128 pays where the data really is 128 bits wide and the work is arithmetic or atomic:
multi-word arithmetic (~2x), 128-bit multiply (2x), and above all 128-bit atomics (3.3x:
a pointer + tag in one AMO/LR/SC, which RV64 cannot do without a lock). It pays little
for bulk copies (the D$ with one outstanding AXI transaction is the limit, worse with
LPDDR4 latency) and nothing for 128-bit key compares when the low word discriminates.

## RV128 Forth: native RV128 compute environment

There is no C compiler for RV128, so `sw/forth/` provides its own: a Forth kernel generated
in rv128asm. It has 128-bit cells and is subroutine-threaded, so definitions are real
machine code.

The compute library is written in assembly:

- bignum on 128-bit limbs;
- Q64.64 fixed point with sin/cos/sqrt and quaternions;
- SHA-512 on the *D ops;
- Poly1305;
- a lock-free stack whose 128-bit pointer+tag head is updated with LR.Q/SC.Q, shared
  between the main loop and a Forth-level timer ISR.

All scripts check themselves through tohost. Every expected value comes from Python.
Results (2026-11-10, ISS): 5/5 tests and 3/3 demos PASS (1007 digits of pi, 1000!).
Lockstep and board runs are pending: they are layer 7 of `run_regression.sh` and the
`forth_*` entries of `board_pack.sh`. Details are in `sw/forth/README.md`.

## v1.4: faster core and Zbb/Zbc

The ISA visible to RV64 mode does not change: it stays binary-identical to RV64IMAC.
Every change is checked in lockstep against the ISS.

- **M unit (`rv128_muldiv`, generic `FAST`, default true).** Multiplication uses a
  registered 64×64 multiplier (DSP58 on Versal) that is reused for the partial products.
  Partial products that are zero or not needed are skipped, so `start` to `done` takes 3 to
  6 cycles. The iterative version took 18 to 66.

  Division is normalised: it skips leading zeros, preloads the remainder and produces
  `DIV_STEPS` (2) quotient bits per cycle. A 128/64-bit division takes ~35 cycles instead
  of 130, and short quotients take a few cycles.

  `FAST => false` keeps the original iterative unit, which needs no DSP and is portable to
  an ASIC. Layer 1 tests both.
- **Branch prediction (`rv128_core`, generic `BPRED`).** In F there is a direct-mapped BTB
  of 64 entries with 2-bit counters, plus a speculative 8-entry return-address stack. The
  RAS is restored from the one kept in X on every redirect.

  X checks the real next pc of every predicted instruction, so a stale or aliased entry
  only costs cycles. That includes code the Forth compiler rewrites. A prediction mark that
  lands in the middle of an instruction becomes a re-fetch, and that instruction does not
  retire. The BTB entry that produced the mark is invalidated, so the re-fetch cannot repeat
  forever. The tag covers bits 31:8, so the boot ROM at 0x1000 does not alias DRAM at
  0x8000_1000.
- **D$ write buffer.** A store hit no longer blocks the next access. Its data goes to a
  one-entry buffer, which is written into the SRAM when the port is free. A load that hits
  the same word merges it, and stores to the same word coalesce. AMO and CBO, misses and
  fence.i drain the buffer first.
- **Zbb + Zbc in RV128 mode.** XLEN is 128; the W and D variants work on 32 and 64 bits.
  There is no official RV128 encoding, so the scheme follows the RV32 → RV64 progression
  (RV128 adds the D opcodes):

| Instructions | Encoding (RV128) |
|---|---|
| andn orn xnor | OP, funct7 0100000, f3 111/110/100 |
| min minu max maxu | OP, funct7 0000101, f3 100/101/110/111 |
| clmul clmulr clmulh | OP, funct7 0000101, f3 001/010/011 (M unit, 8 iterations) |
| rol ror / rolw rorw / rold rord | OP / OP-32 / OP-64, funct7 0110000, f3 001/101 |
| rori / roriw / rorid | OP-IMM imm[11:7]=01100 / OP-IMM-32 imm[11:5]=0110000 / OP-IMM-64 imm[11:6]=011000 |
| clz ctz cpop (+w on OP-IMM-32, +d on OP-IMM-64) | imm12 0x600 / 0x601 / 0x602, f3 001 |
| sext.b sext.h | OP-IMM imm12 0x604 / 0x605 |
| rev8 | OP-IMM f3 101, imm12 0x6F8 (shamt 120, as 0x698/0x6B8 for RV32/RV64) |
| orc.b | OP-IMM f3 101, imm12 0x287 |
| zext.h | OP-64 funct7 0000100 f3 100 rs2 0 (packd, as packw in RV64) |

These encodings are supported by `iss128.py`, `rv128asm.py` and the RTL, and in random
tests (`sw/tests/rndb_*`, `gen_random.py --zb`). QEMU does not have them, so they are not in
layer 0b.

### v1.4 on silicon (TE0950 / VE2302, 50 MHz, 2026-11-11)

- **Implementation:** WNS +1.02 ns; 42.1k LUT, 21.3k FF, 8 BRAM, 9 DSP58 (the 64×64
  multiplier).
- **Validation:** 168/168 programs pass. The first run had 159/160; the failure was
  `t_conc`, which assumed the old core speed and is now written so the core speed does not
  matter.

| Workload | v1.3 (cycles) | v1.4 (cycles) | Speed-up |
|---|---|---|---|
| π, 1007 digits (Forth) | 33.96 M | 6.86 M (0.14 s) | 4.95× |
| 1000! (Forth) | 10.28 M | 1.48 M (30 ms) | 6.95× |
| CoreMark (RV64 mode) | 1.07 CoreMark/MHz | 1.84 CoreMark/MHz | 1.72× |

### v1.5: timing (toward a higher clock)

At 50 MHz the worst path ran from the W-stage CSR decode, through W→X forwarding and the
128-bit address adder, to the D$ data BRAM: 54 levels, WNS +1.02 ns.

- **Forwarding from W and D$ request permission** now depend only on `memwb` registers. A
  CSR, exception or interrupt in W always flushes, so nothing in X uses its value.
- **D$ early-index read.** The core sends `req_ridx`, bits 12:4 of the virtual address from
  a 13-bit adder, plus a hint saying whether the X request reads data. In accepting states
  the D$ reads its SRAMs with that index every cycle, independent of `accept` and the full
  address. LOOKUP checks the index and replays on a mismatch: bit 12 can differ under Sv39,
  or the PTW/core prediction can be wrong. The write buffer drains when the hint says the
  port is free.
- **D$ next-line prefetch** (generic `PREFETCH`, default false). After each refill the D$
  fetches line L+1 into a 64-byte buffer in the background; a miss to that line fills from
  the buffer in 4 cycles. In lockstep with random latency it speeds up sequential access
  (`rv128ui_mem` −9 % cycles) but slows down `cache_stress` by +2 %, because it occupies
  the AXI master. At 60 MHz the slack is only +0.018 ns, so it stays off until it is
  measured on the board.

### v1.5 on silicon (TE0950, 60 MHz, 2026-11-11)

- **Implementation:** WNS +0.018 ns, WHS +0.011 ns, with strategy
  `Performance_ExplorePostRoutePhysOpt` and TICK_DIV 60.
- **Validation:** 162/162 programs pass. The 115200-baud UART divisor is now 33.

| Workload | v1.4 @ 50 MHz | v1.5 @ 60 MHz |
|---|---|---|
| CoreMark (RV64 mode, 1200 iterations, 10.8 s) | 1.84 /MHz, 92 it/s | 1.85 /MHz, **111 it/s** |
| π, 1007 digits | 6.86 M cycles, 0.137 s | 6.85 M cycles, **0.114 s** |
| 1000! | 1.48 M cycles, 30 ms | 1.49 M cycles, **25 ms** |
