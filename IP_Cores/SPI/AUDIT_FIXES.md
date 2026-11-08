# SPI — Audit 2026-11 fixes

Branch `audit-2026-11`. Simulator: GHDL 4.1 (mcode). `run_xsim.sh` and the
Vivado TCL were updated but not executed here (no Vivado); results are from
`./run_ghdl.sh all`.

## Baseline (before any change)

| TB | Result |
|---|---|
| tb_spi_engine (4 modes, loopback, slave model) | PASS |
| tb_spi_mmio | PASS |
| tb_spi_axi | PASS |
| tb_spi_soc | PASS |
| soc_top_spi elaboration | PASS |

## Findings and changes

| # | Sev | Finding | Change (file:line) | Verification |
|---|---|---|---|---|
| 1 | ALTA | Shared `byte_fifo` (entity-name collision with IIC/I3C copies, async array read) | New private `spi_byte_fifo.vhd` (sync `rst`, `clr`, SRAM-mappable registered read + prefetch, FWFT cycle-identical). `spi_axi_top.vhd:187,196`, `spi_mmio.vhd:93,102`; `run_xsim.sh`, `vivado/vivado_soc_spi.tcl:30`, new `run_ghdl.sh`. `byte_fifo.vhd` left functionally untouched (other projects pull it from `~/spi_ip`), header note added | `tb_spi_byte_fifo` (new, random equivalence vs. old model) PASS; single-library analysis of all 4 cores: no collisions |
| 2 | MEDIA | TX underrun mid-DMA raised CS mid-transaction silently | CS held asserted while the DMA runs: `spi_axi_top.vhd:222`; underrun sticky STATUS[9] (`:330`, engine stream end while `tx_pend`); `spi_dma.vhd:150` `tx_pend` | `tb_spi_axi` T5: AR channel starved 3 us at SCLK 50 MHz -> exactly one CS rising edge, tx_urun set, 48 bytes intact. Mutation (no CS hold) -> T5 fails |
| 3 | MEDIA | No DMA abort; deadlock if started with en=0 | `abort` latched in `spi_dma.vhd:187`, honoured at `S_DECIDE` (`:204`); `DMA_CTRL[3]` abort, `DMA_CTRL[4]` deferred FIFO flush (`spi_axi_top.vhd:337`); start refused when `en=0` or busy (`dma_ok`, `:180`, `dma_err` STATUS[10] `:312`); STATUS[11] dma_abort | `tb_spi_axi` T6 (refused start, busy not stuck), T7 (engine disabled mid-DMA -> abort -> flush -> clean follow-up transfer) |
| 4 | MEDIA | Any write to STATUS clears all stickies | W1C per bit `spi_axi_top.vhd:291`, `spi_mmio.vhd:150` | `tb_spi_mmio` T5, `tb_spi_axi` T5/T6 |
| 5 | BAJA | 31-bit DMA offsets | full 32 bits, `spi_dma.vhd:195-196` | by inspection + all DMA TBs |
| 6 | BAJA | RLAST / RRESP / BRESP ignored | `axi_err` pulse `spi_dma.vhd:277,339` -> STATUS[12] | covered by review; the DDR model always answers OKAY (no error-injection model) |
| 7 | BAJA | PIO TXDATA write during DMA silently dropped | sets `tx_ovf`, `spi_axi_top.vhd:324` | `tb_spi_axi` T8 |
| 8 | BAJA | MISO sampling undocumented | Header `spi_engine.vhd:26-41`: mesochronous by design, no synchronizer, timing budget for pad/board constraints | doc |
| 9 | BAJA | Datapath regs rely on init values | `sh_tx/sh_rx/rx_data_r` reset, `spi_engine.vhd:136`; DMA datapath reset | 4-mode engine TB unchanged, PASS |

Firmware: `spi_test.s` / `sw/spi_bringup.c` never write STATUS; no change.

## Final status (GHDL)

tb_spi_byte_fifo, tb_spi_engine, tb_spi_mmio (T1-T5), tb_spi_axi (T0-T8),
tb_spi_soc: **all PASS**; `soc_top_spi` elaborates.

## Deferred / notes

* With CS held, an underrun is protocol-legal for clock-driven slaves, but
  slaves with internal timing between bytes (some ADCs/flash in specific
  modes) may still care: firmware should check STATUS.tx_urun.
* After an abort the FIFOs may hold residue; use DMA_CTRL[4] (flush).
* `spi_mmio.vhd` (PIO-only variant) received only the FIFO + W1C changes.
* SoC-level runs used RV32i from git `HEAD` (working tree modified by
  another task, out of scope).
* Not yet validated on silicon against real SPI devices.
