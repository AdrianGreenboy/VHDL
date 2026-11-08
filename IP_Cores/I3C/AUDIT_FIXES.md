# I3C — Audit 2026-11 fixes

Branch `audit-2026-11`. Simulator: GHDL 4.1 (mcode); results from
`./run_ghdl.sh all` (never deletes; the legacy `run_*.sh` still contain
their pre-existing `rm -f work-obj08.cf`).

## Baseline (before any change)

| TB | Result |
|---|---|
| tb_i3c_controller (T1-T10) | PASS |
| tb_i3c_target (U1-U12) | PASS |
| tb_i3c_engine (V1-V9) | PASS (but see #3: 8 undetected SDA fights) |
| tb_i3c_mmio (W1-W6) | PASS |
| tb_i3c_soc | PASS |

## Findings and changes

| # | Sev | Finding | Change (file:line) | Verification |
|---|---|---|---|---|
| 1 | ALTA | `byte_fifo` with ASYNC reset driven from logic (old `i3c_mmio.vhd:124`), name collision | Private `i3c_byte_fifo.vhd` (sync `rst`, SRAM-mappable registered read + prefetch), `i3c_mmio.vhd:205,213,221`. Scripts `run_mmio.sh`, `run_soc.sh`, `bd_i3c_steps.tcl`, new `run_ghdl.sh`. Old `byte_fifo.vhd` kept, DEPRECATED header | `tb_i3c_byte_fifo` (new) PASS; single-library analysis: no collisions |
| 2 | MEDIA | IBI START detection without spike filter; dead `scl_f1/f2` | 3-sample majority filter after the 2FF (`i3c_controller.vhd:333`), used for IDLE IBI detection (`:370`) and all open-drain samples (`:517,590`); push-pull samples keep the 2FF value. `scl_f*` removed | all controller/engine/mmio/soc TBs PASS (incl. arbitration T8/V7, IBI, hot-join, ENTDAA) |
| 3 | MEDIA | Zero-margin hand-off (target edge detection lag) | Controller: one OD-quarter turnaround `S_TURN` after every target-driven bit before driving SDA push-pull (`tgt_drv` `:546,604,629,713`; `:786`; dispatch factored into a procedure `:222`, logic unchanged). Target: T=1 released during SCL low after `T1_DRIVE_CLK` (`i3c_target.vhd:678`, generic `T1_EARLY_REL`). Min div_pp for external targets = 2, enforced with LOOP_INT=0 (`i3c_mmio.vhd:146`) | New SDA contention monitor in `tb_i3c_engine`: pre-audit RTL = **8 fights** (same clock), fixed = 0 (no-turnaround mutant 7, no-early-release mutant 1). New `tb_i3c_async`: target on an independent drifting/jittered clock, full suite (RSTDAA, SETDASA, ENTDAA, private W/R, seize, T=0, GETPID/BCR/DCR/STATUS, IBI+MDB) at (div_pp,div_od) = (2,9) (2,5) (3,6) (5,9) (9,19); target clock 9.7 ns +/-4 %, 12.5 ns, 7.3 ns, 10 ns +/-8 %, 5 ns: **all PASS, 0 contention**. Pre-audit RTL: 4 fights. div_pp=1 async fails functionally (A8 MDB) -> minimum 2 |
| 4 | MEDIA | Command evaporates when the controller cannot accept it | Explicit `cmd_acc` handshake (`i3c_controller.vhd:391`); `pend_r` cleared only on `cmd_acc` (`i3c_mmio.vhd:426`), re-issue otherwise; `cmd_rej` for non-IBI commands in IBIWAIT; CMD_DROP sticky STAT[28]/IRQ 15 (`:432-439`); CMD_PEND STAT[11]. A first attempt (clear on "busy rose") still lost the command when an IBI START was captured in the same cycle — found by the sweep below | `tb_i3c_mmio` W8 (CMD while pending), W9 (rejected in IBIWAIT -> DONE+CMD_DROP), W10 (START header at every offset 0..24 cycles vs an IBI request: DONE always arrives; with busy-based acceptance k=5 hangs) |
| 5 | MEDIA | Any write to STAT clears all stickies | W1C per bit `i3c_mmio.vhd:353`; firmware `i3c_test.s` (x23 = 0xFFFFFFFF) + regenerated `prog[]` in `i3c_bringup.c` (1 inserted word after patch indices 5/20 + 2 stores changed; verified by word diff) | `tb_i3c_mmio` W7; `tb_i3c_soc` PASS |
| 6 | BAJA | rdata not gated by `sel` | `i3c_mmio.vhd:263` | W7 |
| 7 | BAJA | WM not clamped | `i3c_mmio.vhd:403` (clamp to 32) | W7 |
| 8 | BAJA | `getb` impure function | Pure function `src_byte` with explicit arguments + concurrent `rd_byte0/rd_bytenx` (`i3c_target.vhd:196,254`) | target/engine/async TBs (GETPID/BCR/DCR/STATUS/MWL/MRL, FIFO reads) PASS |
| 9 | Gap | I3C build-readiness: HDR / CCC coverage | Verified: SDR only, no HDR in either engine (documented in both headers + README). Target CCCs present: ENEC/DISEC, RSTDAA, ENTDAA, SETDASA, SETMWL/SETMRL, GETMWL/GETMRL, GETPID, GETBCR, GETDCR, GETSTATUS; IBI with 1-byte MDB. SETDASA was not covered by any engine-level test before -> now in `tb_i3c_async` A2 | A1-A9 in `tb_i3c_async` |

## Final status (GHDL)

tb_i3c_byte_fifo, tb_i3c_controller, tb_i3c_target, tb_i3c_engine (+
contention monitor), tb_i3c_async, tb_i3c_mmio (W1-W10), tb_i3c_soc:
**all PASS**; `soc_top_i3c` elaborates.

## Deferred / notes

* **HDR not supported**, and the target has no HDR-exit-pattern detection:
  it must not sit on a bus where HDR is used. Not implemented CCCs:
  SETNEWDA, GETMXDS, GETCAPS, SETAASA, DEFTGTS, directed RSTDAA. IBI payload
  beyond the mandatory byte is not supported. Adding them is a feature
  project, not an audit fix.
* T=1 early release is a documented deviation from the MIPI wording
  (hand-off at the SCL rising edge); it relies on the mandatory high-keeper.
  Set `T1_EARLY_REL => false` to restore the literal behaviour (then one
  fight remains at div_pp = 1 with the internal loop).
* The turnaround costs one div_od quarter per command following a
  target-driven bit (throughput impact only).
* Requirement for external targets: release latency < (div_od+1) controller
  clocks and output latency compatible with div_pp >= 2 (verified 80-200 MHz
  target clocks). Real devices with slower internal clocks need larger
  dividers — must be checked on the board.
* SoC-level runs used RV32i from git `HEAD` (working tree modified by
  another task, out of scope). Not yet validated against real I3C devices.
