# ECC_Scrubber — audit 2026-11 fixes

Regression: `./run_regression.sh` (build dir `$ECC_SIM_DIR`, default under `/tmp`).
Firmware is assembled with `../ADCS/fw/asm.py`.

## Baseline (before changes)

| Bench | Result |
|---|---|
| tb_layer1, tb_layer2, tb_layer4, tb_layer4_b, tb_codec_mmio, tb_si_scrub, tb_smoke_si, tb_selfcheck_si | PASS |
| tb_layer3 | **FAIL (did not compile)**: the bench drove an 8-bit `addr` into the 16-bit `ecc_regbank.addr` port (the port was widened for the data window and the bench was never updated). Fixed: the bench now drives 16 bits; the trace is unchanged. |
| `deliver*.sh` | Not simulation scripts: base64 installers that hold **pre-audit** copies of the sources. Re-running them overwrites the fixes. Do not run them. |
| Vivado scripts (`vivado/`, `gen_ecc_bd_tcl.sh`) | Vivado only, not run. |

## Findings and changes

| Sev | Finding | Change | Verification |
|---|---|---|---|
| ALTA | `scrub_fsm` S_DONE was a trap: a second start was never served | `scrub_fsm.vhd:196` S_IDLE and S_DONE share the restart path. A CPU start clears the counters, FIRST/LAST and the flags, as the frozen map in `mmio_oracle.py` specifies. Starts are latched (`start_pend`). `busy`/`done` already change in the cycle a start arrives (`:130`), so a STATUS poll right after CONTROL can never see the previous sweep's `done`. | tb_ecc_audit T1 |
| ALTA | CPU stores to local RAM were dropped while the DMA owned the single write port (`dmem_ready` was tied to '1') | `mem_subsys_dma.vhd:192`: a local-RAM store while `dma_busy='1'` stalls the core (`dmem_ready='0'`) until the DMA finishes. Loads are not stalled (both ports read asynchronously). Same fix in `ADCS/rtl/mem_subsys_dma_adcs.vhd:249`. | tb_dma_audit D1 (ADCS: tb_dma_audit_adcs) |
| MEDIA | REGION_BASE / REGION_LEN / PERIOD were stored but never used | New `scrub_fsm` ports, with defaults that keep the original behaviour. The sweep covers words `(base+i) mod DEPTH` for `i < min(len, DEPTH)` (`:206`). `len=0` sweeps nothing. Periodic trigger (`:173`): with PERIOD≠0 and CONTROL.oneshot(bit1)=0 a new sweep starts PERIOD cycles after the last one ends. Periodic sweeps add to the counters. PERIOD=0, or a start with oneshot=1, disarms the trigger. STATUS bit4 shows the trigger is armed. | tb_ecc_audit T6, T7 |
| MEDIA | dma_burst: 9-bit LEN but 8-bit AxLEN, so `beats` was truncated (LEN 300 gave AWLEN 43 with WLAST on beat 300) | `dma_burst.vhd:155`: each burst is clamped to 256 beats and longer transfers are split. `:132`: LEN=0 is ignored. `mem_subsys_dma.vhd:158`: LEN values above 511 saturate. `:170`: LEN=0 no longer arms busy_sticky, which used to stay high forever. Same changes in `ADCS/soc/dma_burst.vhd` and `ADCS/rtl/mem_subsys_dma_adcs.vhd`. | tb_dma_audit D2, D3 |
| BAJA | Data window LO/HI torn read | `ecc_regbank*.vhd:310/336`: a LO access captures the whole 39-bit word. A following HI access to the same index is served from that snapshot. | tb_ecc_audit T5 |
| BAJA | Stickies → W1C | STATUS bit2 (DED) and bit3 (CE) are now sticky flags in `scrub_fsm`. Writing 1 to STATUS clears them (`ecc_regbank.vhd:228`). CONTROL bit2 = clr_cnt and bit3 = clr_sticky are now implemented. Before, only the `_si` bank honoured bit2, and only for its tile counters. | tb_ecc_audit T2, T3 |
| (found) | The BRAM read port arbitration relied on firmware never overlapping an injection, a window access and a sweep. With periodic scrubbing that assumption breaks: an injection in the middle of a sweep hijacked `raddr`. | Arbitration is now enforced in hardware (`ecc_regbank.vhd:174-176`, `:275`). The sweep FSM has a `hold` input. Priority is sweep > injector > window, which keeps CPU program order. | tb_ecc_audit T4 |

Oracle: `mmio_oracle.py` was updated from the register spec, independently of
the RTL: region wrap/clamp, W1C flags, the periodic-armed bit and accumulating
periodic sweeps. A new self-test, `test_mmio_oracle.py`, checks this. The Layer 3
and SI traces regenerate byte-identically (the traces do not use the new features).

## New tests

- `tb_ecc_audit.vhd` (generic `SI`, run for both regbanks), tests T1–T7. On the pre-audit RTL it fails at T1.
- `tb_dma_audit.vhd`: tests D1 store during DMA, D2 LEN=300 split, D3 LEN=0. It includes an AXI protocol checker. On the pre-audit RTL D1 fails, and D2 also fails when run on its own (WLAST/AWLEN mismatch).
- `test_mmio_oracle.py`.

## Final status

`run_regression.sh`: all 12 benches pass (9 baseline + tb_ecc_audit ×2 + tb_dma_audit), plus the oracle self-test.

## Not fixed / notes

- `ecc_soc_top.vhd` (Layer 4 SoC) has no DMA, so the store-drop finding does not apply to it.
- The `deliver_*.sh` installers still contain pre-audit sources (see Baseline).
- Board validation still needed: the periodic scrubber running on silicon with real traffic on the shared BRAM port, and the CPU stall during DMA in the real SoC. Check which `dma_burst.vhd` the Vivado flow actually compiles. The ADCS flow pulls `~/rv32i/dma_burst.vhd`, which is outside this audit's scope and does not have the fix.
