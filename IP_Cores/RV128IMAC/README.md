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

Not done yet: mutation testing, FPGA SoC top with DDR (M5).

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
