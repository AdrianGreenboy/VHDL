# DSP IP — audit fixes (audit-2026-11)

Scope: `rtl/fft_dp.vhd`, `rtl/fft_unsplit_dp.vhd`, `rtl/fir_dp.vhd`, `rtl/dsp_mmio.vhd`,
`sim/dsp_oracle.py`, testbenches and run scripts. GHDL 4.1 `--std=08`.

## Baseline (before any change)

All 8 scripts green: `run_fft_l1a` (M1..M5 killed), `run_unsplit_l1a`, `run_fir_l1a`,
`run_cordic_l1a`, `run_mmio_l2`, `run_mmio_fft_l2b`, `run_mmio_l2c`, `run_dsp_soc_l4`.
Every test vector was random in ±8000 (a quarter of full scale).

## Fixes

| Sev | Finding | Fix |
|---|---|---|
| ALTA | `fft_dp.vhd`: the twiddle product wrapped at 16 bits. `tr = qmul - qmul17` reaches ±65536 (±46341 for in-range data) and was `resize`d to 16 bits. `qmul` truncated +32768 to 16 bits. Each butterfly output was `rsr1(17-bit sum)` resized to 16 bits. | `qmul`/`qmul17` now return 17 bits; `tr`/`ti` are 18 bits; the `u±t` sums are 19 bits; output is `sat16((u±t+1)>>1)`. Every saturation sets a new sticky `sat` port. |
| ALTA | `fft_unsplit_dp.vhd`: the same wrap class. A/B reach +32768 (conjugated −32768), and W·B was resized to 16 bits. | A/B are 17 bits, W·B is 18 bits (`qmulw`), and the final sum is 19 bits → `sat16`. |
| ALTA | The oracle was int64 with no per-stage saturation, so it did not define the same semantics as the RTL. | `dsp_oracle.py::fft_fixed` now saturates every butterfly output to int16 (as the RTL banks do) and counts saturations. Twiddles are read from the single W_1024 ROM with stride, exactly like the RTL. `unsplit_fixed()` is split out. All existing golden files are byte-identical. |
| MEDIA | `dsp_mmio`: START with DATA_LEN=0, LOG2N>10, or FIR_LEN out of range hung or overflowed, and `status_err` was never driven. | START validates its parameters: FFT LOG2N 1..10; real-pack LOG2N 2..10 with DATA_LEN = 2**LOG2N; FIR_LEN 1..64; DATA_LEN 1..1024; high bits must be 0; reserved FUNC codes rejected. A START while busy is also rejected. On error: DONE=1, ERR=1, datapath and DATA untouched. New STATUS bit3 FFT_SAT (sticky, W1C). |
| MEDIA | `fir_dp`: an out-of-range length indexed outside the arrays. | `cfg_len` is clamped to 1..MAXTAPS and `coef_idx` is taken mod HALFMAX. |
| MEDIA (ASIC) | `fft_unsplit_dp`: two combinational reads of Z in one cycle, plus a combinational X read. | One registered Z read port (Z[k] and Z[N-k] are fetched over 2 cycles) and one registered X read port. Both buffers are now plain 1R1W SRAMs. `dsp_mmio` OP_RP_STORE skew changed from 1 to 2. |
| BAJA | DATA read readiness used `dr_raddr_q = widx`, so a write followed by a read of the same word, or a coincidental address match, returned stale data. | A DATA read is ready only on the 3rd cycle of the held request with a matching read address. This was proven stale on the old logic: mutant M3 fails "RAW prime". |

**Overflow guarantee.** The 1/2-per-stage schedule bounds the complex magnitude, so saturation can only occur for inputs outside the Q1.15 unit circle (|re|=|im|=FS corners), or within about LOG2N LSB of it: a full-scale tone saturates 4 outputs at +32767 instead of wrapping.

**qmul(−32768,−32768).** It is unreachable in fft_dp. W=−j is the only −32768 twiddle, and it only ever multiplies W=1 difference outputs, which are bounded to ±32767. This was confirmed by a 4000-vector full-scale random search. The widening is kept as defence.

## Tests

- `run_fft_l1a.sh`: new M0c corner run, `tb_fft_corner.mem` (16 cases): DC ±FS, −FS corner impulses (fwd/inv), full-scale complex/real tones, Nyquist, random square corners, full-range random, N=2/4/8. The TB has `MEMFILE`/`HAS_SAT` generics and checks the sticky `sat` bit. Added mutations M6 `tr_wrap16` (the original bug) and M7 no-saturation, both killed only by the corner run.
- `run_unsplit_l1a.sh`: M0c corner run (`tb_unsplit_corner.mem`, 5 cases) and M6 `wb_wrap16`.
- **New** `run_mmio_l2d.sh` / `tb_dsp_mmio_l2d.vhd`: 11 rejected STARTs; FFT via MMIO with FFT_SAT expected from the oracle (3 cases) and W1C; RAW/RAR at 0/1/2 idle cycles. Mutations M1..M5 are all killed.
- **Old RTL vs new tests:** HEAD `fft_dp` fails 448/10318 corner outputs, e.g. a +FS tone peak reads 0xAE00 instead of 0x7FFF. HEAD unsplit fails 366/1541. HEAD `dsp_mmio` fails L2d (no ERR/DONE).

## Final status

All 9 scripts pass on the new RTL: M0 bit-exact and every mutant killed (fft 7/7, unsplit 6/6, fir 5/5, cordic 5/5, L2 5/5, L2b 4/4, L2c 4/4, L2d 5/5, L4 6/6). The original ±8000 signatures are unchanged.

## Deferred / notes

- The sat flag does not distinguish forward and inverse runs; it is per-run sticky.
- No fir_dp-level test drives an out-of-range length directly; L2d rejects it at MMIO, and the clamp is defence in depth.
- Reset style is already synchronous active-high throughout DSP; no reset synchronizer was added here (DSP has no top-level reset input of its own; it is the SoC's job).
- The run scripts still mutate `../rtl` in place and restore it (family pattern). Run them on a copy if anything else uses the tree concurrently.
