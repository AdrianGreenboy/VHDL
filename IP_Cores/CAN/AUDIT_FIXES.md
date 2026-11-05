# CAN IP: audit 2026-11 fixes

Branch `audit-2026-11`. Every finding was re-checked against the code before it was changed.
Simulator: GHDL 4.1 (mcode), VHDL-2008.

## Baseline (before any change)

| Script | Result |
|--------|--------|
| `run_engine.sh` | PASS @8923067ns |
| `run_engine_rx.sh` | PASS @10507958ns |
| `run_bus.sh` | PASS @1763886ns |
| `run_mmio.sh` | PASS @313946ns |
| `run_soc.sh` | PASS (`TEST PASSED` @586058ns). The script hardcodes `/home/adrian/...` for RV32i, so it needed the RV32i path overridden. `RV` can now be overridden from the environment |
| `run_bringup.sh` | not run (needs the aarch64 cross-compiler) |

## Findings

### ALTA: missing stuff bit at the CRC-sequence / CRC-delimiter boundary (FIXED)
- `can_engine.vhd:105` adds the new `stuffpend()` (= stuffed fields + `S_CRCDEL`). The RX stuff check (`:683`) and TX `p_txsel` (`:369`) both use it. If the last CRC bit completes a run of 5, RX now expects a stuff bit and TX now sends one before the delimiter.
- The TB models shared the bug. Both were fixed from ISO 11898-1 ("stuffing over SOF..CRC sequence inclusive"), without reference to the RTL:
  - `tb_can_engine.vhd`: the receiver model reads the final stuff bit after `gds` of the CRC when `rn = 5`, and the bit-bang TX inserts it after its loop.
  - `tb_can_engine_rx.vhd`: the bit-bang TX `send()` was fixed the same way.
- New tests T10 (engine TX and RX) and R13 use frames found by an independent Python model. Both frames have DLC 1 and data 0x22:
  - id 0x100: CRC 0x5EDF, ends `0 11111`
  - id 0x118: CRC 0x46E0, ends `1 00000`
  
  `m_crcstuff` proves that the case is actually exercised.
- Verified by mutations A1/A2 in `run_audit_mut.sh` (revert, then fail) and by the pre-audit engine failing both TBs.

### MEDIA: hard sync on an SOF in INTERMISSION (FIXED)
- `can_engine.vhd:448`: hard sync now also happens in `S_INTER` once 2 recessive intermission bits have been sampled. Edges in intermission bits 1-2 are an overload condition and stay resync-only. `S_SUSP` already hard-synced.
- With a pending request the node joins on the foreign grid. A passive node that sent the previous frame still suspends.
- Side fix: `wastx` is cleared when the node receives a new frame (`:338`, `:463`, `:468`), so a passive node no longer suspends after a frame it only received.
- Test T11: an early SOF 800 ns into the 3rd intermission bit, and a checker that the engine's edges are on the SOF grid. Without the fix they are 1200 ns off (mutation B1).

### MEDIA: fault-confinement rules (FIXED)
- New procedures: `p_busoff` (`:228`), `p_inc8` (`:252`), `p_flagbiterr` (`:298`), `p_domafter` (`:309`).
- Rules added:
  - passive ACK exception voided by a dominant bit during the passive flag (`:280`, `S_EFLAGP`)
  - stuff-error-in-arbitration exception (`:689`)
  - REC+8 for a dominant first bit after the error flag (`:595`)
  - +8 and a new flag on a bit error in an active error flag or an overload flag
  - +8 per 8 consecutive dominant bits after a flag, which is the 14th bit after an active flag
  - a dominant bit in an error or overload delimiter is a form error; on its last bit it is an overload (`:606`)
- Tests: T8 (passive ACK void), T12, T13, R14, R15, R16. Each one is proven by mutations C1..C6.
- The header (lines 13-16) no longer claims these simplifications.

### MEDIA (ASIC): reset style, registered-read FIFO, FIFO rename (FIXED)
- The engine port is now `rst` (synchronous, active high) instead of `rstn`. `can_mmio` derives `rsta/rstb = rst or not EN` (`:137`).
- New `can_byte_fifo.vhd` (entity `can_byte_fifo`):
  - synchronous reset
  - RAM with a registered read port
  - FWFT kept through a 1-deep prefetch into the read register
  - 2-cycle write-to-visible latency, and back-to-back pops are supported
- `can_mmio.vhd:187,195`, `run_mmio.sh`, `run_soc.sh` and `bd_can_steps.tcl` were updated to use it.
- `byte_fifo.vhd` is **no longer referenced** but was left in the tree, because the task forbids deleting files. The coordinator should `git rm` it.

### MEDIA: STAT stickies W1C (FIXED)
- `can_mmio.vhd:329`: each sticky clears on writing 1. A set in the same cycle still wins.
- Firmware `can_test.s` now clears with `sw x6, STAT` (writes back the value read) instead of `sw x0`. The instruction count is unchanged, so `prog[4]` and `prog[7]` are still patchable.
- `can_test.mem` was regenerated with `asm.py`. The 3 words in `can_bringup.c` `prog[]` were updated, and the array was re-checked to be identical to the .mem.
- Test M8, mutation E1.

### BAJA (FIXED)
- **SELFACK lock:** b8/b9 are written only with key `0xA5` in b31:24 (`can_mmio.vhd:324`). Unkeyed writes leave them unchanged. Tests M5 and M9, mutation E2.
- **tx_busy in bus-off:** bus-off drops `pend`, and `tx_req` is rejected with a `tx_err` pulse while bus-off (`can_engine.vhd:427`). T9 was rewritten: it checks busy=0 in bus-off, that a request is rejected, that nothing is sent spontaneously after recovery, and that an explicit re-request is sent. Mutation D1.
  - **Behaviour change:** before, a pending frame was sent automatically after recovery.
- **Dead `gotack`:** removed.
- **BTR while enabled:** BTR writes are ignored while EN_A or EN_B is set (`can_mmio.vhd:344`). This is documented in the header and README. Test M9, mutation E3.

## Final status
All TBs pass, plus `run_audit_mut.sh`, which reports `AUDIT MUTATIONS OK`: 13 single-fix reverts each fail, and the pre-audit engine fails both new TBs.

| Script | Result |
|--------|--------|
| `run_engine.sh` | PASS @11520757ns |
| `run_engine_rx.sh` | PASS @11393888ns |
| `run_bus.sh` | PASS @1763886ns |
| `run_mmio.sh` | PASS @325365ns |
| `run_soc.sh` | PASS @586058ns |

## Not fixed / residual risk
- Not verified against a conforming controller yet. The next step is the ZCU104 PS CAN: run a TEC/REC scenario matrix and frames whose CRC ends in a run of 5 on a real bus.
- Reactive overload frames are still limited to 2 by the existing `ovln` counter.
- The role in an overload frame is taken from `wastx`. ISO leaves the transmitter/receiver role during overload frames loosely defined, so this should be checked against the reference controller.
