# NPU — audit 2026-11 fixes

Regression: the existing `run_*.sh` scripts, plus the new `run_audit.sh`.
`paso*.sh` are historical base64 installers holding **pre-audit** sources: do
not re-run them, they would overwrite these fixes. `syn/*.tcl` and
`run_synth*.sh` are Vivado only and were not run. The file lists in
`syn/npu_synth_ooc.tcl` and `syn/npu_synth_axi.tcl` were updated to include
`rtl/npu_sram.vhd`.

## Baseline (before changes)

PASS: run_l1, run_l2, run_l3_sondas, run_l3_seq, run_l3_full, run_axi_slave,
run_axi_sondas, run_l3_top, run_l3_top32, run_timing and run_axi_int. The last
four were run on a frozen git copy. run_bram, run_timing_mut and run_bram_mut
did **not** complete in the baseline: the job hit its 2-hour limit on a shared,
heavily loaded 2-CPU machine. They are not listed as baseline passes.

## Findings and changes

| Sev | Finding | Change | Verification |
|---|---|---|---|
| ALTA | `npu_dma`: err_rd/err_wr/errcode_* were never reset or cleared | Reset to OKAY and cleared at `rd_start` / `wr_start` (`npu_dma.vhd:213,313`). `npu_axi_top` samples `dma_err` only when a DMA request completes (`npu_axi_top.vhd:335`) instead of ORing in a stale flag every cycle. | tb_npu_audit A1, A2 |
| ALTA (ASIC) | Multi-port / async-read working memories | New `rtl/npu_sram_1r1w` (`npu_sram.vhd`): 1 write + 1 **synchronous registered** read. This is the single technology-mapping point for SRAM macros or BRAM. **npu_seq_full**: `in_ram` → 8 banks 64×8 (one per input channel); `w2_ram` 1152×8 and `w3_ram` 2560×8 single banks; `accm` → 8 banks 64×32 (the RMW reads in S_C2_WEND, while pix_i is stable, and writes in S_C2_ACC); `c2_ram` → 8 banks 128×8 (bank = channel mod 8, so the 8 writes of S_C2_RQ hit distinct banks; pool2 reads its 4 window pixels over 4 cycles); `p2_ram` 256×8 (internal FC read when busy, external read when idle) (`npu_seq_full.vhd:242-268,493`). **npu_seq_conv1**: `img_ram` 256×8, `w_ram` 72×8, `out_ram` → 8 banks 64×8. `prow0`/`prow1` (32 reads/cycle) are replaced by a pairwise horizontal maximum: per-channel `prev`/`cur` registers plus `hrow`, 8 banks of 8×8 (`npu_seq_conv1.vhd:179-196,374`). Because max is associative and commutative, the result is bit-identical. **npu_top**: the pool1 copy is pipelined for the synchronous read (`npu_top.vhd:175`). Kept as registers by design (≤16 entries, too small for a macro): `b_ram` (8×int32), `b2_ram` (16), `b3_ram` (10), `lg_ram` (10 bytes, still combinational read because `npu_axi_top`/DMA depends on it), and the weight register `wreg`. | tb_npu_seq_conv1 SIG=0xE4C64381, tb_npu_seq_full SIG_POOL2=0xA87E298C / SIG_LOGITS=0xF7FF3389 / SIG_CLASE=0x6084FD2A (identical to baseline); `ghdl --synth` of npu_seq_conv1, npu_seq_full, npu_top and npu_axi_top OK |
| BAJA | `npu_axi_slave`: write SLVERR was decided only from the AW address; AxSIZE ignored | SLVERR if any beat is unmapped or AWSIZE>2 (`npu_axi_slave.vhd:249,256`). Bad beats do not write. The address advances 2**AxSIZE per beat (`:244`, narrow transfers) and registers are decoded by word address. Reads get the same treatment. | tb_npu_audit S1–S3 |
| BAJA | Unreset registers in `npu_axi_top` (demux, DMA request registers, res_clase) | Reset added (`npu_axi_top.vhd:248,322`). | regression |
| BAJA | `npu_requant`: G_SHIFT>31 overflowed (`2**(C_SH-1)` as an integer) | The rounding constant is built in the product width (`C_RND`, `npu_requant.vhd:55`), with an elaboration assert on G_SHIFT (`:60`). | tb_npu_audit R1 (G_SHIFT=40) |
| BAJA | rd_bytes/wr_bytes = 0 underflow (ARLEN = -1) | A 0-byte request completes immediately with no AXI traffic (`npu_dma.vhd:215,315`). | tb_npu_audit A3, A4 |

## Interface / timing changes (honest)

- External result ports are now **synchronous**: `npu_seq_conv1.out_data`,
  `npu_seq_full.p2_data` and `npu_top.p1_data`/`p2_data` are valid one cycle
  after the address. `lg_data` is unchanged (combinational). The two benches
  that read those ports wait one clock edge now (`tb_npu_seq_conv1`,
  `tb_npu_seq_full`). The data and signatures are unchanged.
- Extra cycles: pool2 takes 5 cycles per output instead of 1 (+1024 cycles per
  inference). The conv1 weight preload and the conv2 weight loads keep their
  cycle counts. The pool1 copy costs +1 cycle.

## New tests

`tb/tb_npu_audit.vhd` (`run_audit.sh`): A1–A4 DMA, S1–S3 slave, R1 requant.
On the pre-audit RTL it fails at elaboration (requant overflow), and at A2 when
G_SHIFT=31.

## Final status (post-change, every script)

run_audit, run_l1 (11/11 mutations), run_l2 (4/4), run_l3_sondas, run_l3_seq
(SIG 0xE4C64381, 5/5 mutations), run_l3_full (identical signatures, 5/5),
run_l3_top (2/2), run_l3_top32 (32/32 classes), run_timing, run_timing_mut
(5/5), run_bram, run_bram_mut (12/12), run_axi_slave, run_axi_sondas and
run_axi_int (SIG_CLASE=0x6084FD2A): **all PASS**.

## Not fixed / notes

- `prev_paso9/` and `prev_paso11/` hold old copies of the sequencers. They are
  not compiled by any run script, so they were left as they are.
- Board and ASIC validation: SRAM-macro mapping with the real memory compiler
  (the read-first behaviour of `npu_sram_1r1w` must match the macro, and the
  sequencers never rely on same-address read/write), timing of the 8-bank
  muxes, and re-running `syn/run_synth*.sh` on Vivado (BRAM inference counts
  will change).
