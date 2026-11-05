# MAC_10G (Core 21) — audit 2026-11 fixes

Branch `audit-2026-11`. GHDL 4.1 (mcode) simulation only; **the silicon
results in README.md (ConnectX-3 Pro at 10.3125 Gb/s, GTYP PMA loopback)
predate these changes and must be repeated with a new bitstream.**
Uses MAC_25G / PCS_25G RTL (see their AUDIT_FIXES.md).

## Baseline (HEAD before any change)

| Script | Result |
|---|---|
| `sim/run_layers.sh` | **38 PASS / 0 FAIL** |
| `sim/run_mutations.py` | README: 21/21. Re-run here under heavy CPU contention (each mutation = a full regression): M01-M12 run, 12/12 detected; the job then hit the 2 h limit (M13-M21 not re-run at baseline) |

## Findings, changes, verification

| ID | Finding (re-verified) | Change | Verification |
|---|---|---|---|
| A2 | (shared) Core 19/20 stored the sync header inverted; `eth21_gtmap` compensated (wire0 = blk(1)) | the PCS66 now produces IEEE order (MAC_25G A2), so `rtl/eth21_gtmap.vhd:5-17,51-52,74-76` maps wire0 = blk(0): **identical bits on the wire** with the default flags (the silicon-proven ConnectX-3 Pro order). Mutation M13 pattern updated | layers 2/3: the TX wire stream decoded by the oracle's IEEE decoder (`WIRE OK`), RX of oracle IEEE streams in all four GT orders, negative cases — all unchanged PASS |
| B2 | `eth21_blocklock.vhd:78-83` invalid header on the window boundary "not counted" | **Not reproducible**: the 16-invalid test precedes the window-restart branch, so the boundary case drops the lock as Fig. 49-15 requires; an uncounted boundary invalid with < 15 before cannot reach 16. No RTL change; explanation `rtl/eth21_blocklock.vhd:15-23` | new boundary case in `tb/tb_eth21_bl.vhd` (48 valid + 15 invalid + invalid 64th → lost): PASS on old and new RTL (consistent with the analysis) |
| M5 | `wstrb` ignored in `eth21_top` | `rtl/eth21_top.vhd:132-140` `merge`, applied to every RW register; CMD/GT_CTRL/IRQ need lane 0 | new `tb/tb_eth21_regs.vhd`. **Old: FAIL** |
| B7 | OKAY on reserved addresses | `eth21_top.vhd:330` and read process: SLVERR on unmapped / unaligned / 0xFC, OKAY on RO | `tb_eth21_regs`. **Old: FAIL** |
| B4 | stale command after `CMD_TIMEOUT` | `eth21_top.vhd:271,475,553`: kill flag set at timeout (cleared by the next CMD), captured with the command in each domain through `mac25g_lsync`; a killed command is not executed when a stopped clock returns | existing layer 4 "RX held in reset: CMD_TIMEOUT" PASS; the stopped-clock case is exercised in MAC_25G `tb_mac_regs` (same mechanism there with a Gray generation counter). See deferred |
| M6 | CDC toggles rely on init values | `eth21_top.vhd:226-228`: optional `por_n`, `mac25g_porsync` per domain (aclk, tx_clk, rx_clk) → async reset of all `mac25g_psync`/`evsync`/`hsync` toggles, OR-ed into the TX/RX reset synchronisers | review-only |
| B3 | counters wrap | `rtl/eth21_txpath.vhd`, `rtl/eth21_rxpath.vhd`: saturating | review |
| Gap | No 802.3x PAUSE | `eth21_txpath.vhd:157-185`: TX frame FIFO + `mac25g_pause_tx`; `eth21_rxpath.vhd:164-190`: `mac25g_pause_rx` + RX FIFO (1024 x 8 B, MAC control frames consumed, drop when full, `rx_tready`), XOFF with hysteresis; `eth21_top.vhd:504-508`: received PAUSE (16-bit value) RX→TX with the new `mac25g_hsync`, XOFF with `mac25g_lsync`. Registers 0x50/0x54/0x58, `CMD` b6, STATUS b6/b7, counters 23..30 | new `tb/tb_eth21_flow.vhd` (TX path → wire → RX path, crossings as in the top): XOFF sent+honoured, 0 data frames while paused, 0 drops (FIFO max 673/1024 words), XON resumes, 0 bad / 0 sequence errors; negative control (honour off) drops |

`GEN_BUSY/GEN_DONE` and `BURST_CYCLES` include the TX FIFO (done = last
word handed to the MAC), so the layer-1A..4 expectations are unchanged.

## ASIC SerDes boundary

README §6c documents the 66-bit PMA boundary (`tx_blk/rx_blk`, `rx_slip`,
ready signals). `eth21_gt_rst`, `eth21_gtmap`, `eth21_clkmeter` stay
Versal-specific by design.

## Final status

`sim/run_layers.sh`: **40 PASS / 0 FAIL** (the 38 baseline checks, incl.
the IEEE wire decode, with unchanged results + PAUSE + registers).
`tb_eth21_regs` on the old RTL: FAIL (WSTRB, SLVERR); `tb_eth21_flow`
cannot elaborate against it (no PAUSE). Mutations on the final RTL: the
ones touching changed code, M13 (gtmap, pattern updated), M15 (blocks
without lock), M20 (CMD waits for RX): 3/3 detected. The full 21-mutation
run was not repeated (≈3 h on this shared machine) — **run
`python3 sim/run_mutations.py` before release**.

## Build note

New RTL `MAC_25G/rtl/mac25g_flow.vhd` (and `PCS_25G/rtl/pcs_blocksync.vhd`
for MAC_25G) added to `vivado/build_*_soc.tcl`.

## Deferred (with reason)

* **Two commands while one domain's clock is stopped** still cancel in that
  domain's toggle (it then times out again, visibly). MAC_25G replaced the
  toggle with a Gray generation counter; porting it to the two-domain
  handshake of `eth21_top` was not done to keep the silicon-proven command
  path minimal. Real-world trigger: RX clock lost (cable) — the RX domain is
  then held in reset and adopts nothing, so the risk is low.
* **hi-BER monitor in `eth21_rxpath`** (still "not in v1"): PCS_25G now has
  `pcs_blocksync` with the clause-49 BER monitor; MAC_10G keeps its
  silicon-validated `eth21_blocklock` (lock only).
* **PFC (802.1Qbb)** not implemented (opcode 0x0101 consumed and ignored).
* **Interop of PAUSE** with a real NIC (ConnectX `ethtool -A rx on tx on`)
  not tested; timing of the new FIFOs at 390.625 MHz (25G build) unknown.
