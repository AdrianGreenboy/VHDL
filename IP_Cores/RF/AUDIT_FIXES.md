# RF DDC/DUC — audit fixes (audit-2026-11)

## Baseline (before any change)

There was no run script and no Python model in the repo (the README cites one). I ran it manually:

- `tb_datapath`: PASS 0xB74940EB.
- `tb_rf_soc` (RV32 firmware + DMA): PASS 0xB74940EB.
- The "5/5 mutations" claimed in the README are not scripted anywhere.

## Fixes

| Sev | Finding | Fix |
|---|---|---|
| MEDIA | `rf_cic_dec`, `rf_cic_int` and `rf_fir` truncate their outputs, giving a −0.5 LSB DC bias. | Round half-up `(v + 2**(s-1)) >> s` before the saturation, consistent with the DSP family. The same defect class in `rf_loopmix` (the four Q1.15 products) is fixed too. |
| MEDIA | No Python model / golden. | **New `model/rf_model.py`**: a cycle-accurate model of `rf_datapath` written from the RTL semantics. With `round=False` it reproduces the historical 0xB74940EB exactly, which validates the model. With the round-half-up contract it gives golden **0x32783005**, now used by `tb_rf_soc` and by `fw/rf-bringup*.c` (`GOLDEN`). |
| MEDIA (ASIC) | `word_fifo`: a 512×32 array read asynchronously. | It now declares **`rf_word_fifo`** in the ADC `adc_fifo` mold: synchronous write port + synchronous read port + 2-register FWFT head. Capacity is 514; write-to-visible latency is 3 cycles. |
| MEDIA | No overflow indication on the FIFO. | A sticky `ovf` is mirrored as IRQ_STAT bit1 (W1C, IRQ_EN bit1) and STATUS bit6. The W1C also clears the FIFO flag. |
| MEDIA | `mem_subsys_rf`: concurrent MMIO + DMA pops. | Exclusive grant: MMIO pops are masked while `rf_dma_busy`. An RX_FIFO_DATA load during a DMA is held off with `dmem_ready=0` until the DMA releases the FIFO. The CPU stalls on ready. |
| BAJA | TX FIFO pushed but never drained. | Removed: there is no TX sample path, the DUC is tone-driven, and this saves a 512×32 RAM. TX_FIFO_DATA is reserved; STATUS reports tx_empty=1. |
| BAJA | NCO 32→10-bit phase truncation spurs. | **Documented, not changed.** The worst spur is about −60 dBc (6 dB/bit over 10 index bits) for FTWs with non-zero bits below bit 22. A phase-dither LFSR would decorrelate the spur at the cost of a raised noise floor and loss of bit-exact repeatability. If needed it should be a register-controlled option added to `rf_nco` together with a statistical (not bit-exact) test. |
| BAJA | Weak TB: one checksum, `severity error`. | `tb_datapath` compares **every sample** against the model at 3 operating points: DC/passthrough; moving tone with a low-pass FIR with negative taps; a different RX NCO with a high-pass-like FIR. All failures use `assert severity failure`, as does `tb_rf_soc`. |

## Tests

- **New `sim/run_rf_regress.sh`**: it works in a temp dir and never touches the repo. It runs the model dump, `tb_datapath` (3 operating points, 192 samples, bit-exact), the new `tb_rf_fifo` (FWFT order, capacity, sticky ovf / clear, push+pop), `tb_rf_soc` (0x32783005), and a mutation battery. The battery reinstates truncation in CIC-dec, CIC-int, FIR and mixer, makes ovf non-sticky, and breaks FIFO ordering. All are killed.
- Notably, M2 (CIC-int Q truncation) passes the old single-checksum SoC test but is caught by the per-sample test. This confirms the original TB weakness.
- The HEAD RTL (truncating) fails the new per-sample test at every operating point; this is equivalent to mutants M1..M4.

## Deferred / notes

- **Reset style**: RF blocks use an asynchronous active-low reset (`aresetn`), a valid ASIC style when used with an assert-async / release-sync synchronizer at the SoC top. Converting every RF block to synchronous active-high was not done, to avoid an unverified large-scale edit. It should be scheduled with a full re-run of `run_rf_regress.sh`.
- The precompiled aarch64 binaries `fw/rf-bringup*` still carry the old golden; rebuild them with `aarch64-linux-gnu-gcc` (not available here).
- The README result tables still show 0xB74940EB (historical silicon run).
- The file rename `word_fifo.vhd` → `rf_word_fifo.vhd` is left to the owner.
- `vivado/*.tcl` file lists are unchanged (same file names).
