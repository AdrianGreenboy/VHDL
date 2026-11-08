# PTP / IEEE 802.1AS core — audit 2026-11 fixes

Branch `audit-2026-11`, GHDL 4.1 (`--std=08`). All findings re-verified first.
The MAC sources `rtl/eth_*.vhd` (`eth_pkg`, `eth_cdc_sync`, `eth_async_fifo`,
`eth_mii_cdc`, `eth_tx_mii`, `eth_rx_mii`, `eth_mac`) are byte-identical
copies of `ETH/rtl/` (see `ETH/AUDIT_FIXES.md` for the MAC/CDC fixes and the
RX ring-buffer bug); `sim/run_regression.sh` warns if they drift.

## !! Missing file

`rtl/ptp_axil_master.vhd` was a dangling symlink to
`/home/adrian/rv32i/ptp_axil_master.vhd`. It was removed (not re-invented);
see `rtl/MISSING_ptp_axil_master.md`. `tb_ptp_axil_master` is excluded from
the regression (lines marked `MISSING-FILE`) until the owner restores it.

## Baseline

- `sim/run_regression.sh` as-is: **FAIL at analysis** (missing file) — no test ran.
  (Side effect of the script: it deletes and regenerates the tracked `sim/work-obj08.cf`.)
- Same script without the missing file: 15/15 PASS. Extra TBs not in the
  script (`tb_pd_phase0..3`, `tb_pd_repeat`, `tb_tx_override`): PASS.
- Weak check found: "TX Pdelay bit-ident" grepped a bare `PASS`, which the
  Req line prints even when the Resp comparison fails. Now matches the Resp line.

## Findings and changes

| # | Sev | Finding | Change (file:line) | Verification |
|---|---|---|---|---|
| 1 | ALTA | eth_mac external MII without CDC | shared MAC (ETH #1); `ptp_mac`/`ptp_top`/`ptp_axil` get `mii_rx_clk/mii_tx_clk` | `tb_ptp_mac_ext`, ETH `tb_eth_mii_cdc` |
| 2 | ALTA | `ptp_axil.vhd:148,108-113` concurrent AW/W + AR: write could land on the read address (AR accepted while the write strobe was issued); 2nd write accepted with BVALID pending | Single serializing FSM `ptp_axil.vhd:105` (alternating priority), payload captured at the handshake edge (:127), registered MMIO strobes, no new AW while B pending | `tb_ptp_axil_conc` fails on v1 (C1: write lost) |
| 3 | ALTA | WSTRB ignored | `1111` write / `0000` OKAY no-op / partial -> SLVERR, no write (`ptp_axil.vhd:142`) | `tb_ptp_axil_conc` C4 |
| 4 | ALTA | `ptp_pdelay_fsm.vhd:174-182`, `R_WAIT_DONE:141`, `ptp_tx.vhd S_WAIT_TS:215` no timeouts | `tmo_cycles` on EVERY wait state (`ptp_pdelay_fsm.vhd:197,206`, I_* states, `ptp_tx.vhd:249` + S_PUSH); return to idle; sticky STATUS[4] pd_timeout / [5] tx_ts_timeout. On a TX timeout `ptp_mac` aborts the frame (FIFO flush, 1-cycle MAC reset, serialization released, `ptp_mac.vhd:332`); a stale TX timestamp is acked on the next send (`ptp_tx.vhd:177`) | `tb_ptp_pdelay_tmo` (v1: deadlock at T1), `tb_ptp_mac_ext` B/E |
| 5 | ALTA | allowedLostResponses | `lost_cnt` (+1 per Resp timeout, cleared by a valid Resp), `as_capable = lost <= allowed` (`ptp_pdelay_fsm.vhd:152,272`); PD_CFG 0x64 (default 3), PD_STAT 0x68, STATUS[6] resp_lost, [8] asCapable 1->0 | `tb_ptp_pdelay_tmo` T2, `tb_ptp_mac_ext` B |
| 6 | ALTA (ASIC) | `spw_fifo.vhd:59` async-read memory; entity name collides with SPW core | Renamed `rtl/ptp_fifo.vhd`, sync-read + FWFT prefetch (:86), sync reset; TBs `tb_ptp_tx*` updated | full regression (bit-identical frames) |
| 7 | MEDIA | `ptp_mac.vhd:423-432` Sync offset ignores correctionField | `off = t_rx - origin - (corr >>> 16) - mpd` (`ptp_mac.vhd:510`). Pdelay_Resp corr (1-step residence) was already used by `ptp_pdelay` | `tb_ptp_mac_ext` D (corr 7000 ns, ±5 ns) |
| 8 | MEDIA | `ptp_pdelay_fsm.vhd:176` any Resp accepted | Accept only if sequenceId = outstanding Req seq (`seq_out` exported by `ptp_tx`) and requestingPortIdentity = ours (`ptp_rx` now parses it, `ptp_rx.vhd:158`); others acked + STATUS[7] (`ptp_pdelay_fsm.vhd:256`). PD_CFG[8] disables the check (debug) | `tb_ptp_pdelay_tmo` T3, `tb_ptp_mac_ext` C |
| 8b | MEDIA (new) | Needed for #8: the responder wrote its **own** counter into Pdelay_Resp.sequenceId instead of the Req's (802.1AS) | `ptp_tx.vhd:208` uses `req_seqid` latched by the responder; `tb_ptp_tx_pdelay` / `verify_ptp_tx_pdelay.py` now expect the requester seq (0x00A5) | regression |
| 9 | MEDIA | Reset style: `ptp_mac.vhd:312` drove the async `aresetn` of spw_fifo with `not rst` | `ptp_fifo` sync `rst`; datapath reset `rst_dp` (`ptp_mac.vhd:212`) | regression |
| 10 | BAJA | `ptp_clock.vhd:110-114` clr_servo lost against a same-cycle PI update | PI branch gated by `clr_servo='0'` (`ptp_clock.vhd:120`) | `tb_ptp_baja` L2 |
| 11 | BAJA | `ptp_tstamp.vhd:84-85` borrow underflow at sec=0 | clamp to 0.0 (`ptp_tstamp.vhd:82`) | `tb_ptp_baja` L1 |
| 12 | BAJA | no access to sec[47:32] | NOW_SECHI 0x5C, frozen by the NOW_SEC read (`ptp_regs.vhd:206`) | `tb_ptp_baja` L3 |
| 13 | BAJA | `ptp_regs` enable unused | CONTROL.enable='0' holds the port datapath (MAC, engines, FIFO) in reset, clock/servo keep running (`ptp_mac.vhd:212`, `ptp_top.vhd:68`) | regression (fw/TBs set enable=1); enable=0 not separately tested |
| 14 | — | STATUS W1C per bit | already W1C for [3:0]; extended to [10:0] (`ptp_regs.vhd:243`), IRQEN masks all | `tb_ptp_baja` L4 |
| 15 | (new) | slave loop processed each Sync on two consecutive cycles (hidden by ptp_clock's edge detector) | guard `rx_mack_sync='0'` (`ptp_mac.vhd:504`) | `tb_ptp_mac_ext` D ("exactly once") |

New registers: 0x5C NOW_SECHI, 0x60 TMO (cycles, reset 0x0010_0000 ≈ 10.5 ms, 0 = legacy no timeout),
0x64 PD_CFG, 0x68 PD_STAT; STATUS bits [4..10] (all 0 in the normal fw flows, ISS signature unchanged).

## Timestamp accuracy (external PHY)

1-step Sync: originTimestamp − DUT clock at the wire SFD = constant 20 ns
(`tb_ptp_mac_ext` A), mpd from a crafted exchange equals the wire-based
expectation exactly (C). Per-direction: TX 20–30 ns, RX 80–90 ns fixed latency,
±5 ns quantization (one 100 MHz core clock). Calibrate TX_LAT/RX_LAT on the
board including PHY latency.

## New tests (`sim/run_regression.sh`, section "audit 2026-11")

`tb_ptp_axil_conc`, `tb_ptp_pdelay_tmo`, `tb_ptp_mac_ext`, `tb_ptp_baja`;
`tb_pd_phase0..3`, `tb_pd_repeat`, `tb_tx_override` added to the script.

## Final status

`sim/run_regression.sh`: **all 25 checks PASS** (15 original + 6 previously
unscripted + 4 new); `tb_ptp_axil_master` OMITTED (missing file).

## Housekeeping

- `rtl/*.bak` (5) moved to `legacy/` — note the root `.gitignore` ignores
  `*.bak`, so they need `git add -f` to stay versioned.
- `rtl/tb_pd_phase0..3.vhd` moved over the `sim/` duplicates (only line 1 differed: the rtl copies had the correct file name).
- Generated by the regression: `sim/tx_stream.txt` (new, untracked), `sim/tx_resp_stream.txt` (changed: Resp seq), `sim/work-obj08.cf`.

## Deferred

- Pdelay_Resp_Follow_Up / two-step responders, full 802.1AS asCapable/neighborRateRatio state machines (only the lostResponses accounting is implemented).
- Offset saturation: `offset_err` is a 32-bit truncation of a 64-bit offset (|offset| > 2.1 s wraps; bring-up already requires coarse pre-set).
- Vivado project files under `vivado_ptp/` still reference the absolute `/home/adrian/...` paths (generated project, not edited).
