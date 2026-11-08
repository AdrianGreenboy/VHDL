# PCS_25G (Core 19) — audit 2026-11 fixes

Branch `audit-2026-11`. All verification is GHDL 4.1 (mcode) simulation;
**nothing below has been re-run on silicon yet.**

## Baseline (HEAD before any change)

| Script / test | Result |
|---|---|
| `sim/run_layer1.sh` | PASS `FNV32=0xD49A4DB4` |
| L2A `tb_pcs_dataplane` | PASS `0xFFE1A09F` |
| L2B `tb_pcs_cdc` | PASS |
| L3 scrambler / gearbox / PRBS / datapath / silicon | PASS (`0x37DB2E32`, `0xA557DAFC`, `0x50BA6983`, `0xB02ACF27`, `LAYER3TOP_PASS`) |
| L4 `tb_pcs_stats_top`, `tb_pcs_mmio` | PASS |
| L5 `verif/tb_soc_pcs` | **cannot be built (pre-existing)**: `soc_top_pcs.vhd:204` connects `p_*` PTP-master ports of `mem_subsys_dma` that the `RV32i` in this repo does not have. Out of scope (RV32i not touched); still not run |

There was no full regression script; `sim/run_layers.sh` is new (runs
everything above except L5, plus the audit tests, and checks that every
oracle-generated testbench in `rtl/` is up to date).

## Findings, changes, verification

| ID | Finding (re-verified) | Change | Verification |
|---|---|---|---|
| A1 | `pcs_regbank` write data not latched; a W accepted while B is stalled executed later with the *current* `wdata`. Re-verified: worse — `awready` was asserted one cycle after the valid and the write fired before the handshake, leaving a phantom pending write that executed with whatever `wdata` showed when B was released | `rtl/pcs_regbank.vhd:185-301`: independent AW/W holding registers (addr, data, strobes latched at their handshakes), `awready = not aw_seen`, `wready = not w_seen`, execute from the held values when B is free. Read channel `:355-395`: `arready = not rvalid`, data captured at the AR handshake | new `rtl/tb_pcs_axil.vhd` T1-T3 (B back-pressure, `wdata` changed right after the handshake, W before AW, one CMD pulse per write). **Old RTL: FAIL** (phantom write / handshake hang); new: PASS. L1 oracle signature unchanged `0xD49A4DB4` |
| A2 | 64B/66B sync header inverted on the wire vs Fig. 49-7 (data sent `1,0`) | `rtl/pcs_tx_datapath.vhd:16-23,91`: data = vector `"10"` (bit 0 = `0` first), control `"01"`. `rtl/pcs_rx_datapath.vhd:110-111`: data iff `"10"`, `out_hdr_ok` = bits differ. `oracle/pcs_datapath_oracle.py` constants fixed (its golden becomes `0x1DDE1477`, testbench regenerated) | new independent reference `oracle/cl49_ref.py` (scrambler x^58+x^39+1, header order, block types, written from the standard; self-test incl. the 3-error multiplication) + `rtl/tb_pcs_cl49.vhd` MODE=tx: TX word stream **bit-exact** (617 words). **Old RTL: FAIL** |
| A3 | No clause-49 block lock: `EVT_RXBAD` unreachable (`pcs_stats_top` derived events from counter increments), invalid headers decoded as control, gearbox assumed alignment | new `rtl/pcs_blocksync.vhd` (Fig. 49-14/15 lock SM ported from MAC_10G `eth21_blocklock`, explicit window-boundary count; Fig. 49-13 BER monitor). `rtl/pcs_gearbox_rx.vhd:8-14,80-84`: 1-bit slip. `rtl/pcs_rx_datapath.vhd:79-85`: block sync drives the slip; new outputs `out_hdr_ok/out_lock/out_hi_ber/ev_*`. `rtl/pcs_silicon_datapath.vhd:46-52,183`: exported, checker only with lock. `rtl/pcs_dataplane.vhd`: lock/hi_ber from `pcs_blocksync` (internal, `EXT_SYNC=false`) or from the RX datapath (`EXT_SYNC=true`), independent event strobes. `rtl/pcs_stats_top.vhd:23-30,280-284`: real lock / hi_ber and one strobe per valid/invalid header (RXBAD → `CNT_RX_ERR`, `IRQ.RX_ERR`) | `rtl/tb_pcs_blocksync.vhd` (63/64, 15/16 per window, boundary, slip + wait, hi_ber set/held/cleared per window, lock loss clears hi_ber, resync); `tb_pcs_cl49` MODE=rx: spec stream at bit offsets 0/1/37/65 acquires lock and decodes every block; 15 consecutive bad headers keep the lock, ≥31 always drop it (16..30 depend on the window phase, as in the standard); L2A oracle `oracle/pcs_stats_oracle.py` rewritten to clause 49 (new golden `0x7822885D`; the old one encoded "one bad header drops lock", "16 errors ever → hi_ber") |
| M1 | `CNT_CLEAR` lost when an event hits the same cycle | `rtl/pcs_dataplane.vhd:166-185`: increments first, clear/PRBS_RESET last (clear wins) | new `rtl/tb_pcs_dp_clear.vhd`: **old 71 instead of 20 → FAIL**, new PASS |
| M2 | hi_ber never windowed | covered by A3 (`pcs_blocksync`, `HIBER_WINDOW` generic, default 48828 cycles = 125 µs @ 390.625 MHz, 16 headers) | `tb_pcs_blocksync` T6-T8 |
| M5 | `wstrb` ignored | `pcs_regbank.vhd:216-280` byte-lane merge on every RW register; CMD/SNAP need lane 0 | `tb_pcs_axil` T4 (old FAIL) |
| M6 | CDC toggles rely on initial values (ASIC) and were reset by ONE domain's reset (fake edge = spurious SOFT_RESET/CNT_CLEAR…) | `pcs_stats_top.vhd:60-108` `pcs_psync`: toggle reset only by async `por_src`, chain without reset, output gated by `rst_dst`. `pcs_cdc.vhd:28-37,47-119`: same for event req, snapshot request/done; new `pcs_porsync` (async assert, 4-edge sync release). `pcs_stats_top`: optional `por_n` port, per-domain POR OR-ed into the functional resets (release order: chains flush before the domain leaves reset) | existing L2B/L4 pass; the X-propagation case itself is not simulated (GHDL starts from the declared initial values) — **review-only** |
| M7 | `pcs_cdc` COOLDOWN_N = 24 dp cycles hard-codes a clock ratio; events inside the cooldown dropped, toggles could cancel | `pcs_cdc.vhd:240-255`: `pcs_evsync` req/ack per event (coalesces, never loses) | new `rtl/tb_pcs_cdc_ev.vhd` at 4 clock ratios: **old FAILS 3 of 4**, new PASS all |
| B3 | 32-bit counters wrap | `pcs_dataplane.vhd:93-97` saturate (the silicon-datapath counters feeding the registers are unchanged, see deferred) | review |
| B6 | gearbox insertion silently drops when full | `pcs_gearbox_tx.vhd`, `pcs_gearbox_rx.vhd`: sticky `overflow` port + simulation assertion | existing L3 gearbox (no overflow) |
| B7 | OKAY on reserved addresses | `pcs_regbank.vhd`: SLVERR on unmapped/unaligned (write and read) | `tb_pcs_axil` T5 (old FAIL) |

## Final status

`bash sim/run_layers.sh <workdir>`: **31 PASS / 0 FAIL** (all baseline
layers 1-4 still pass; L1 `0xD49A4DB4`, scrambler `0x37DB2E32`, gearbox
`0xA557DAFC`, PRBS `0x50BA6983` unchanged; goldens that encoded the old
behaviour were regenerated from the corrected oracles: L2A `0x7822885D`,
L3 datapath `0x1DDE1477`; plus 17 audit checks). `sim/run_layer1.sh`:
PASS `0xD49A4DB4`. Old-RTL runs of the new tests: `tb_pcs_axil` FAIL,
`tb_pcs_cl49` TX FAIL (599 word errors), `tb_pcs_dp_clear` FAIL,
`tb_pcs_cdc_ev` FAIL at 3 of 4 clock ratios; the RX lock/slip tests cannot
even elaborate against the old RTL (no slip / lock interface).

## Build note

New RTL file `rtl/pcs_blocksync.vhd` must be added to any Vivado project
that compiles `pcs_rx_datapath` (done for `MAC_25G/vivado/build_mac_soc.tcl`;
the PCS_25G Vivado project is created by hand per README §8 — add it there).

## Deferred (with reason)

* **L5 SoC run** — needs an RV32i `mem_subsys_dma` with the PTP master
  port; RV32i is outside the audit scope.
* **25GBASE-R BER-monitor constants** — implemented per the task (clause
  49: 16 invalid headers in 125 µs) as generics; the exact clause-107
  values for 25GBASE-R must be confirmed against the IEEE 802.3 edition in
  force before tape-out.
* **Saturation of `pcs_silicon_datapath` counters** (`tx_word_cnt`,
  `rx_block_cnt`, PRBS `ber_count`): they feed the oracle-checked silicon
  signatures; left wrapping (2^32 words ≈ 11 s at 390 MHz — the snapshot
  must be read faster, documented).
* **Timing** of the new 1-bit slip mux in the 132-bit RX gearbox buffer and
  of `pcs_blocksync` at 390.625 MHz is not known (no Vivado run here).
* **POR (M6)** verified by review only.
