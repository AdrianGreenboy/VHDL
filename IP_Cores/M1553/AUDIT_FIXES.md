# MIL-STD-1553 IP: audit 2026-11 fixes

Branch `audit-2026-11`. Every finding was re-checked against the code before it was changed.
Simulator: GHDL 4.1 (mcode), VHDL-2008.

## Baseline (before any change)

| Script | Result |
|--------|--------|
| `run_1a.sh` | PASS @400485ns, 5/5 mutations |
| `run_1b.sh` | PASS @462205ns, 5/5 mutations |
| `run_1c.sh` | PASS @1679825ns, 5/5 mutations |
| `run_l2.sh` | PASS @615665ns, 6/6 mutations. Needed `FIFO=` pointing at the SPW `spw_fifo.vhd` |
| `run_l4.sh` | PASS @552845ns, 2/2 mutations |

`run_l4.sh` only passed with `sim/iss_m1553.py` restored. **Environment bug:** `run_1a.sh` ran `rm -rf sim`, which deletes `sim/iss_m1553.py`, so `run_l4.sh` breaks after running `run_1a.sh`. Fixed: `run_1a.sh` now works in `sim_1a/`.

Not run: Vivado TCL and `m1553_bringup.c`, which need Vivado and aarch64-gcc.

## Findings

| Id | Status | Change | Verification |
|----|--------|--------|--------------|
| ALTA S_RESP blind response | FIXED | `m1553_rt_core.vhd:461`: if the current-bus receiver is busy, or a data word or a word error arrives before the status starts, the RT aborts to S_IDLE with ME and `ev_err`, and sends no response. This covers word-count-high messages. A valid command there is decoded. | 1d D4. MD2: the RT collides with the extra word. |
| ALTA fail-safe TX timer | FIXED | `m1553_word_tx.vhd:99-110`: a counter independent of the word FSM forces `tx_en` and `tx_data` to 0 and latches `fs_fault` after `FS_TIMEOUT` continuous cycles. The generic defaults to 80000 (800 us at 100 MHz, against a 660 us legal maximum). The fault clears only on rst, which the cores derive from EN, so an explicit re-enable is required. It is exported to STAT b1 and RTBUS b4..6. | 1a `u_fs` instance (FS_TIMEOUT=5000): cut at exactly FS_TIMEOUT cycles, sticky, cleared by re-enable. M6, and the pre-audit TX, fail it. |
| MEDIA sync idle-level | FIXED | `m1553_word_rx.vhd:103,137`: a run above RUN_MAX gives a *tentative* centre. It re-anchors on the edge at the start of cell 0 when the idle level was the opposite one, and failures stay silent while tentative. | 1b cases 13-17 (idle high) and case 8 (data word after idle, now decoded). MB6 and the pre-audit RX fail. Case 5 now accepts exactly one error of sync *or* Manchester class: from idle-low it is indistinguishable from a data word until later cells. |
| MEDIA silent illegal broadcasts | FIXED | `m1553_rt_core.vhd:190`: `v_ign` covers broadcast+transmit, broadcast TxStatus and broadcast tr=1 unsupported mode codes. These go to S_IDLE with no ev_cmd and no change to `sa_r`/`bcast_r`. | 1d D5. MD3. |
| MEDIA TX underflow | FIXED | `tx_empty` is routed into both cores. RT (`:472`, `:497`): empty at response start gives silence + ME; empty mid-response stops after the word in flight, sets ME, pulses `ev_uflow` and no OK. BC (`:243`, `:268`): empty before start sends nothing; empty mid-message stops. Both set `r_uflow` and no OK. The new STAT sticky b28 is `TX_UFLOW`. | 1d D6/D7. MD4, MD5. |
| MEDIA RX-FIFO write collisions | FIXED | `m1553_mmio.vhd:306`: a 4-entry write queue serializes BC/RT0/RT1 same-cycle writes and drains one per cycle. RT->RT now yields 2 entries per word (RT copy + BC monitor copy, which was lost before). The firmware (`fw_m1553.s` P4), the ISS and L4 were updated. The 8-word signature is unchanged. | L2 RT->RT exact sequence. ML2-4, ML2-8. |
| MEDIA STAT W1C | FIXED | `m1553_mmio.vhd:384`: `stk <= stk and not wdata`. The firmware already wrote 0xFFFFFFFF. | L2 W1C block. ML2-2, ML2-7. |
| MEDIA (ASIC) reset / FIFO | FIXED | `m1553_mmio` registers and IRQ use synchronous reset (the async `arstn` was removed). New `rtl/m1553_fifo.vhd` has a registered-read RAM, 1-deep FWFT prefetch and sync rst/clr; the IP no longer uses `spw_fifo`. Scripts, `bd_m1553_steps.tcl` and `run_synth_m1553.tcl` were updated. | All layers. |
| BAJA BC status v_err / tmo | FIXED | `m1553_bc_core.vhd:323,375`: a word error while waiting for status sets SERR. `:327,379`: the timeout keeps counting and is deferred only while a word is in reception, up to TOUT+2100. The same applies to RT `S_RRST` (`:422`). | 1d D9/D10. MD7, MD8. |
| FEATURE dual A/B bus | DONE | BC: `f_bus`/MSG b27 selects the per-message bus, with TX and RX on that bus (`:199`). RT: two receivers, one TX routed to the command bus (`:470`), and supersede on the other bus (`:316`, word TX `abort`). MMIO resolves buses A and B. Pads `*_a`/`*_b` were added; `soc_top`/wrapper gained `m1553_*_b`. | 1d D1-D3. MD1, MD9. L2 BUS-B/BUS-A. |
| FEATURE status flags | DONE | `RTFLAGS` (0x24) drives Busy (b3), SSF (b2) and TF (b0) into the status word (`:483`). With Busy set, transmit commands get the status only and received data is not stored (`:254`). `RTBUS` (0x28) was added. | 1d D8. L2 RTFLAGS readback and status. MD6, MD10. |

All layers pass, and every mutation, old and new, fails as required:

| Script | Result |
|--------|--------|
| `run_1a.sh` | PASS @400485ns, 6/6 |
| `run_1b.sh` | PASS @678205ns, 6/6 |
| `run_1c.sh` | PASS @1679825ns, 5/5. The single-bus regression is identical. |
| `run_1d.sh` | PASS @1288526ns, 10/10 |
| `run_l2.sh` | PASS @780885ns, 8/8 |
| `run_l4.sh` | PASS @552885ns, 2/2. The ISS signature is unchanged. |

## Not done / for the owner
- **Bus-B pins:** not assigned in `m1553_pins.xdc`, because the known CRUVI LS1 pins are too few. The BD ties `m1553_rx_b` low and leaves the B outputs open, so a LOOP_INT build needs no pads. The pin-block template is commented in the XDC.
- **XDC comment fixed:** it said `txen` is on E10, but the constraint has always been A10.
- **Clause references** (4.4.1.3 fail-safe, 4.4.3.1 superseding) were taken from the audit text. Verify them against the standard document.
- **Not implemented:** bus-switching inhibit/override mode codes, Dynamic Bus Control, and the ME setting for ignored illegal broadcasts. The audit only asked for silent idle.
- **BCR stickies (b26/27)** follow the RT's BCR level. This is pre-existing behaviour: they re-set right after a W1C while BCR is held.
- **Unverified Vivado step:** `ilconstant` VLNV `xilinx.com:inline_hdl:ilconstant:1.0` is used in the BD TCL but has not been run in 2025.2.
