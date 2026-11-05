# MAC_25G (Core 20) — audit 2026-11 fixes

Branch `audit-2026-11`. GHDL 4.1 (mcode) simulation only; **not re-run on
silicon.** Shared PCS blocks come from `../PCS_25G/rtl` (see its
AUDIT_FIXES.md).

## Baseline (HEAD before any change)

| Script | Result |
|---|---|
| `sim/run_layers.sh` | **21/21 PASS** (L1A-L5, incl. L5 SoC + RV32 firmware) |
| `sim/run_mutations.py` | **27/27 mutations detected** |

## Findings, changes, verification

| ID | Finding (re-verified) | Change | Verification |
|---|---|---|---|
| A2 | Sync header inverted on the wire (data sent `1,0`) in `mac25g_pcs66` and `mac25g_pcs_tx` (the file header itself flagged it) | `rtl/mac25g_pcs66.vhd:17-27,58`, `rtl/mac25g_pcs_tx.vhd:22-27,97`: data = `"10"` (bit 0 = `0` first), control `"01"`. RX `mac25g_pcs66.vhd:100-105`: data iff `"10"`, invalid `00`/`11` → `/E/` block + new `out_hdr_ok` (the MAC aborts the frame instead of decoding it as control). Gearbox path `rtl/mac25g_datapath.vhd:370-384`: Core 19 RX with clause-49 lock/slip, blocks to the MAC only with lock, invalid header → `/E/`. MAC_10G `eth21_gtmap` made the identity so its wire is unchanged | new `tb/tb_mac_cl49.vhd` vs the independent `PCS_25G/oracle/cl49_ref.py`: PCS66 66-bit blocks bit-exact + RX decode of the reference blocks; `mac25g_pcs_tx` 64-bit words bit-exact. **Old RTL: FAIL both** (1197 / 599 errors). Mutation M25 kept (pattern updated) |
| M3 | Any `tvalid` bubble mid-frame = underrun; AXIS-legal masters break | new `rtl/mac25g_flow.vhd` `mac25g_axis_fifo` (store-and-forward, 512 x 8 B, cut-through fallback for frames larger than the FIFO) in front of the MAC (`mac25g_datapath.vhd:231-245`); `mac25g_tx.vhd:30-39,51,243-255`: `SA_DRAIN` ends after `DRAIN_TMO` idle slots | new `tb/tb_mac_flow.vhd` TEST=bubble: 40 frames 60..1514 B with random bubbles, byte-exact, 0 underruns. **Without the FIFO (old structure): FAIL** (kept in the regression as a negative control) |
| M4 | `GEN_COUNT = 0` underflow → ~2^32 frames | `rtl/mac25g_gen.vhd:17-19,134-139`: empty burst, `done` at once (as `eth21_udp_gen`) | new `tb/tb_mac_regs.vhd` T4. **Old: FAIL** (busy for ever) |
| M5 | `wstrb` ignored in `mac25g_top` | `rtl/mac25g_top.vhd:113-122` byte-lane `merge` on every RW register; CMD/IRQ need lane 0 | `tb_mac_regs` T1. **Old: FAIL** |
| M6 | CDC toggle/req flops rely on initial values (ASIC) | `rtl/mac25g_sync.vhd:13-34,60-80,108-125`: async power-on reset `por_src` on `tg`/`req`/`busy`/`pend` only, chains unreset; new `mac25g_porsync` (`:150-176`); `mac25g_top` optional `por_n`, per-domain POR OR-ed into the functional resets (release order documented in `mac25g_sync.vhd`). Mutations M23/M24 (no functional reset on toggles/chains) still detected | L1C `tb_mac_sync` PASS; X-propagation at power-up not simulated — **review-only** |
| B1 | Block FIFO write without full check | `mac25g_datapath.vhd:314-326`: never overwrites, sticky `BLK_FIFO_OVF` counter + assertion | regression (never fires) |
| B3 | 32-bit counters wrap | `mac25g_datapath.vhd:197-202,480-530`: all counters saturate | review |
| B4 | `CMD_TIMEOUT`: the timed-out command executed later when `clk_dp` came back; two commands could cancel in the toggle | `mac25g_top.vhd:30-55,226-240,303-330,405-425`: 4-bit Gray **generation counter** replaces the CMD toggle; ack returns the generation; timeout kills the command; in reset the dp domain adopts the generation without executing | `tb_mac_regs` T3 (clk_dp actually stopped). **Old: FAIL** (stale GEN_START sent 4 frames). Mutations M18/M21/M22 still detected |
| B5 | `keep_to_n`: non-contiguous `tkeep` silently = 8 bytes | `mac25g_tx.vhd:140-148,185-187`: `ev_keep_err` (counted as `TX_KEEP_ERR`) | review + counter in L4 |
| B7 | OKAY on reserved addresses | `mac25g_top.vhd:296-299,341-375`: SLVERR on unmapped/unaligned, OKAY (ignored) on RO | `tb_mac_regs` T2. **Old: FAIL** |
| Gap | No IEEE 802.3x PAUSE | `mac25g_flow.vhd`: `mac25g_pause_rx` (0x8808 / opcode 0x0001, DA 01-80-C2-00-00-01 or own, good FCS only), `mac25g_pause_tx` (no new data frame while the timer runs, frame in flight completes, timer = quanta x 8 slots; XOFF on RX-FIFO high watermark, periodic refresh at half the quanta, XON on low watermark, software request), RX FIFO 1024 x 8 B with `m_tready` back-pressure, MAC control frames consumed, whole-frame drop when full. `mac25g_rx.vhd:290-296` accepts the PAUSE multicast. Registers `PAUSE_CTRL/PAUSE_WM/PAUSE_SWQ`, `CTRL.RX_HOLD`, `CMD.SEND_PAUSE`, counters 16..23 (`doc/register_map.md`) | `tb_mac_flow` TEST=pause in loopback: XOFF sent+honoured, 0 data frames while paused, 0 RX drops (FIFO max 474/512 words with hi 200), XON resumes, checker 0 bad / 0 seq errors; software PAUSE of 0x40 quanta = 512 slots; negative control (honour off) drops |

Behavioural change visible to firmware: `GEN_BUSY/GEN_DONE` and
`BURST_CYCLES` include the TX FIFO (done = last word handed to the MAC),
so the L3/L4 expectations are unchanged.

## Final status

`sim/run_layers.sh`: **27 PASS / 0 FAIL** — all 21 baseline checks with
the original signatures (L1A `0x1695834C`, L2A `0x51B51B7C/0x46CE078A/
0x315146E7`, L2B `0x1CE6D232`, L2C `0x08FB60FE`, L3 `0x62B78AAD/0x1E1BA41D/
0x710C2A4E/0x9B22CCD6`, L4 AXI/MMIO, L5 SoC + RV32 firmware) + 6 audit
checks. `sim/run_mutations.py`: 26/27 with the original list — **M26
(register slice without skid) survived** because the new TX FIFO never
fills during the L3 bursts, so the skid is no longer exercised there. M26
now targets `tb_mac_flow -gTEST=pause` (TX paused, FIFO full): the mutant
fails it (checker 136 bad / 34 sequence errors, verified by a direct run);
the per-mutation timeout was raised from 300 s to 900 s because that test
is long on a loaded machine. The other 26 were re-checked after the
changes and are detected.

## Build note

New RTL `MAC_25G/rtl/mac25g_flow.vhd` (and `PCS_25G/rtl/pcs_blocksync.vhd`
for MAC_25G) added to `vivado/build_*_soc.tcl`.

## Deferred (with reason)

* **PFC (802.1Qbb)**: per-priority pause frames (opcode 0x0101) are consumed
  as MAC control frames and ignored. Needs per-class queues; out of scope.
* **Headroom sizing**: the RX FIFO (8 KB) and the default watermarks
  (384/128 words) cover one own frame + one partner frame + pipeline;
  the partner's reaction time and cable delay of a real link must be
  measured (802.3 Annex 31B allows up to 512 bit times + a max frame).
* **Jumbo frames** larger than the TX FIFO fall back to cut-through and are
  again subject to source bubbles.
* **Timing** of the FIFOs (inferred RAM with registered read) and of the
  pause arbiter at 390.625 MHz: no Vivado run here.
* **POR (M6)** verified by review only.
