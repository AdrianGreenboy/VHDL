# RV32i - audit-2026-11 fixes

Branch `audit-2026-11`. Scope: `IP_Cores/RV32i` only. All findings were
re-verified on the original RTL before fixing. Every new mechanism has a
legacy-compatible default, because ~15 other cores instantiate `cpu_pipeline`,
`dp_ram`, `axil_soc`, `dma_burst`, `axi4_master` and `axi_ddr_sim` directly
from this folder.

## How to run

```
./run_ghdl.sh                       # full GHDL regression (all targets, both memory modes)
./run_ghdl.sh exc bus_err difftest  # selected targets
python3 mutate_rv32.py              # 22 mutations, all must be KILLED
```

`run_ghdl.sh` is new (the existing `run_xsim.sh` / `difftest.sh` need
Vivado; they still work, and their file lists were updated). GHDL 4.1 mcode.

## Baseline (original RTL, GHDL)

All targets of `run_xsim.sh` plus `tb_lw_hazard` (GAP 0-4), `tb_lw_hazard_reg`
and 30 random difftest programs passed, **except `tb_accel`**: it hung
because `accel_sumsq.mem` was stale (the doorbell store went to word 127, the
`.s` and the testbench use word 65). The image was regenerated from the
source with `asm.py`; no other `.mem` differs from its `.s`.

## Fixes

| # | Sev. | Finding | Fix |
|---|------|---------|-----|
| 1 | MEDIA | Misaligned loads/stores silently wrong (`cpu_pipeline` MEM, `cpu`) | Load/store address-misaligned exceptions (mcause 4/6, mtval = address) raised in EX through the existing precise trap path; the access never reaches MEM. Also instruction-address-misaligned (cause 0, mtval = target) on taken jumps/branches. `riscv_pkg.is_misaligned`. |
| 2 | MEDIA | Unknown opcodes executed as NOP (`control.vhd`) | Full legality decode: unknown opcodes, reserved funct3/funct7, non-exact ECALL/EBREAK/MRET, unknown SYSTEM immediates, SYSTEM f3=100 -> `ctrl.is_illegal`. Unimplemented CSRs and writes to read-only CSRs -> `csr.csr_illegal`. Trap cause 2, mtval = instruction. FENCE, FENCE.I, WFI are legal NOPs. Added misa (0x40001100, WARL) and mvendorid/marchid/mimpid/mhartid (RO, 0). |
| 3 | MEDIA | RRESP/BRESP ignored (`axi4_master`) | `axi4_master.err` (with `done`), `mem_subsys.dmem_err`, new `cpu_pipeline.dmem_err` input: load/store access fault (cause 5/7, mtval = address) taken from MEM with priority over EX; the faulting load does not write back, younger instructions are squashed and replayed after the handler. `dma_burst.err` (sticky, cleared on start) -> `mem_subsys_dma` STATUS bit1. |
| 4 | MEDIA | Async-read arrays + textio init, FPGA-only | `dp_ram`/`imem`/`dmem` generic `SYNC_READ` (registered read ports, read-first). `cpu_pipeline` generics `IMEM_SYNC` (IMEM addressed with the next PC: no added stage or penalty) and `DMEM_SYNC` (each load spends one address cycle in MEM, `dmem_req` held low in it). `axil_soc.MEM_SYNC` (address cycle before capture), `dma_burst.SYNC_LOC` (one-beat look-ahead on the W handshake), `mem_subsys(_dma).SYNC_READ`. SoC tops: `SYNC_MEM`. Boot path: `boot_loader.vhd` copies `rv32_bootrom_pkg.vhd` (VHDL constant, made by `gen_bootrom_pkg.py`) into IMEM after reset, zero-fills the rest, then releases the core (`BOOT_FROM_ROM`, `axil_soc.BOOT_HALTED`); the host path through the axil_soc IMEM window still works. textio `INIT_FILE` remains as a simulation/FPGA option only. The lw-hazard fix (WB history forwarding) is unchanged and re-validated in both modes. |
| 5 | BAJA | CSRRS/CSRRC suppression keyed on wdata = 0 | Keyed on the rs1 field (`csr_rs1z` from the instruction, like RV64's `csr_rs1z`). |
| 6 | BAJA | mtval never written on traps | Written on every trap (`trap_tval`); 0 for ecall/ebreak/interrupts. |
| 7 | BAJA | Spurious load-use stalls | Stall only if the ID instruction really reads rs1/rs2 (`ctrl.use_rs1/use_rs2`) and is valid. |
| 8 | BAJA | CLINT mtime read twice | Documented the hi-lo-hi read and the safe mtimecmp write order in `clint.vhd` (no RTL change). |

Found while fixing (fixed):

* `axil_soc`: a read accepted while a write was in `W_WRITE` sampled the
  memory at the write address (single shared port). Reads and writes are now
  serialised (write priority).
* A misaligned load whose consumer waits in ID (load-use stall) would have
  lost the trap redirect: redirects now take priority over `stall_lu`.
* mul/div start is gated by `stall_mem`/`mem_fault` and by `busy` of the unit,
  so a squashed operation can never deliver its `done` to a later one.
* `mepc` writes clear bits 1:0 (IALIGN = 32).
* RV64IMAC-style `run_ghdl.sh`; `asm.py` gained lb/lh/lbu/lhu/sb/sh, fence,
  fence.i, wfi, `.word` and the new CSR names (existing images unchanged).

## Tests (all self-checking, all in `run_ghdl.sh`)

* Existing tests, now run with `SYNC_MEM=false` and `true` where they use the
  pipeline: `tb_cpu_pipeline`, `tb_trap_pipeline`, `tb_irq_pipeline`,
  `tb_lw_hazard` (GAP 0-4), `tb_lw_hazard_reg` (now also checks the loaded
  values), `tb_master`, `tb_gemv_dma`, `tb_gemv_big`, `tb_accel_pipe`,
  `tb_soc_master`; `tb_dma` x {SYNC, W_STALL} plus odd-length and SLVERR phases.
* `difftest_gen.py` now also generates lb/lh/lbu/lhu/sb/sh; difftest runs in
  both memory modes.
* New: `tb_exc` (17 traps: every illegal class, misaligned load/store/jump,
  ecall mtval, rs1-keyed CSR write, faulting instructions write nothing;
  pipeline async/sync and single-cycle core), `tb_bus_err` (SLVERR -> cause
  5/7, replay, both modes), `tb_boot_rom` (autonomous boot over garbage IMEM,
  zero-fill, overlapped AXI-Lite read+write), `tb_lu_stall` (cycle-exact).
* `mutate_rv32.py`: 22 mutations re-introducing each defect; all killed.

Result: full regression OK (both memory modes, 50+50 random programs);
mutations 22/22 killed. CAN and SPW SoC testbenches (which compile this
folder) give identical, cycle-exact results against the old and new RTL.

## Integration notes

* Defaults are the legacy behaviour: existing SoCs see no change except
  that illegal instructions, misaligned accesses and (where `dmem_err` is
  wired) bus errors now trap. Firmware that relied on misaligned stores
  being truncated, or on executing zero words as NOPs, will now trap.
* `soc_top_pipe` / `soc_top_master` need `rv32_bootrom_pkg.vhd` and
  `boot_loader.vhd` in the project (also in `run_xsim.sh`).
* ASIC: use `SYNC_MEM = true`, `INIT_FILE = ""`, and replace the
  behavioural `dp_ram` array by a 2-port SRAM macro with 1-cycle read.

## Deferred / not done

* TMR hooks for the rad-hard platform controller: out of scope (owner).
* `dp_ram` needs two ports (CPU + AXI/DMA). If the target PDK only has 1RW
  macros, an arbiter in front of a 1RW macro is required - not done.
* `ghdl --synth` elaborates the `SYNC_MEM` SoC, but does not infer the
  2-port array as a RAM; macro mapping is not done here.
* Timing: with `IMEM_SYNC` the redirect/stall logic drives the SRAM address
  combinationally (likely critical path); not timed.
* The single-cycle `cpu.vhd` stays async-memory only (by construction).
* During a DMA transfer the CPU port of the local RAM cannot write
  (`axi_owns = dma_busy`), pre-existing and documented, not changed.
* Other cores keep private copies of `cpu_pipeline`/`control`/`csr`
  (PQC, ADCS, ECC_Scrubber); they do not get these fixes.
