# USART — Audit 2026-11 fixes

Branch `audit-2026-11`. Simulator: GHDL 4.1 (mcode). The xsim scripts
(`run_*.sh`) were updated but could not be executed here (no Vivado); all
results below are GHDL runs of `./run_ghdl.sh all`.

## Baseline (before any change)

| TB | Result |
|---|---|
| tb_usart_engine | PASS |
| tb_usart_mmio | PASS |
| tb_usart_axi | PASS |
| tb_usart_soc | PASS |

## Findings and changes

| # | Sev | Finding | Change (file:line) | Verification |
|---|---|---|---|---|
| 1 | ALTA | Shared `byte_fifo` (same entity name in 3 copies, divergent reset semantics, async array read) | New private `usart_byte_fifo.vhd` (sync active-high `rst`, `clr`, 1 write port + 1 registered read port + 1-deep prefetch `head` with write-through bypass; FWFT cycle-identical). Instantiated at `usart_mmio.vhd:170,179` with `rst_i <= not aresetn` (`usart_mmio.vhd:160`). Scripts/TCL: `run_mmio.sh`, `run_axi.sh`, `run_soc.sh`, `vivado_soc_usart.tcl:38-42`, new `run_ghdl.sh` | `tb_usart_byte_fifo` (new): 20 000-cycle constrained-random cycle-by-cycle comparison against the old FWFT model incl. push/pop on empty/full, flush, reset (7339 pushes, 2691 push-on-full, 2148 bypass hits). Mutation (bypass removed) is caught. All four cores analysed into ONE library: 0 duplicate-entity warnings |
| 2 | MEDIA | `rx_abort` pulse only sampled in `X_DEC` | Sticky `abort_rx_q` (`usart_dma.vhd:346`), acted on at the burst boundary (`usart_dma.vhd:365`), cleared in idle. Same for a new `tx_abort` (`usart_dma.vhd:231,247`; `DMA_CTRL[3]`, `usart_axi_top.vhd`). New `rx_aborted`/`tx_aborted` -> DMA_STAT[8]/[7] | `tb_usart_dma` D1 (abort while stalled in `X_AW`), D2 (abort in `T_BEAT`), D5 (abort while idle ignored). Mutation (latch removed) -> D1 fails "abort lost". `tb_usart_axi` A7 (TX DMA blocked on full FIFO escaped with tx_abort) |
| 3 | MEDIA | Any write to STAT / DMA_STAT clears all stickies | W1C per bit: `usart_mmio.vhd:252`, `usart_axi_top.vhd:237`. TB clears migrated to `0xFFFFFFFF` | `tb_usart_mmio` M10 (write 0 keeps, bit 6 clears only tx_ovf, bit 5 only rx_ovf); `tb_usart_axi` A7 (DMA_STAT bit 7 only) |
| 4 | BAJA | DMA offsets truncated to 31 bits | `resize(unsigned(tx_addr), ADDR_W)` `usart_dma.vhd:239`, rx `:355` | `tb_usart_dma` D3 (0x8000_0040 / 0xC000_0080 reach araddr/awaddr) |
| 5 | BAJA | RLAST not checked | `usart_dma.vhd:277` -> `tx_rerr` on mismatch; beat count stays authoritative | `tb_usart_dma` D4 (missing RLAST reported, no hang, no false error with a correct slave) |
| 6 | BAJA | Datapath regs rely on init values | Full reset of TX/RX datapath and synchronizers: `usart_engine.vhd:217,336`, `p_sync`; DMA datapath regs reset in `usart_dma.vhd` | All engine/mmio/axi/soc TBs unchanged and PASS |
| 7 | BAJA | RS-485 DE polarity fixed | `CTRL[10] de_inv`, `usart_mmio.vhd:333` (default 0 = legacy active high) | `tb_usart_mmio` M12 |
| 8 | BAJA | WM registers not clamped | `usart_mmio.vhd:262` (clamp to DEPTH) | `tb_usart_mmio` M11 |
| 9 | BAJA | PIO+DMA TX push in the same cycle silently drops the PIO byte | `tx_ovf` set on collision, `usart_mmio.vhd:285` | covered by review; no dedicated stimulus (needs cycle-exact CPU/DMA collision) |

Firmware: `usart_test.s` / `usart_bringup.c` never write STAT/DMA_STAT, so
no change was needed.

## Final status (GHDL)

tb_usart_byte_fifo, tb_usart_engine, tb_usart_mmio (M1-M12),
tb_usart_dma (D1-D5), tb_usart_axi (A1-A7), tb_usart_soc: **all PASS**;
`soc_top_usart` elaborates.

## Deferred / notes

* PIO and DMA on the same FIFO remain "do not mix" (documented contract);
  only the same-cycle collision is now flagged.
* SoC-level runs used the RV32i sources of git `HEAD` (snapshot): the
  working-tree `IP_Cores/RV32i` was being modified concurrently by another
  task and its `cpu_pipeline.vhd` no longer analyses under GHDL 4.1. RV32i
  is out of scope here.
* Not yet validated on silicon (TE0950); xsim scripts not executed.
