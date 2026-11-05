# PCIe IP — audit 2026-11 fixes

Owner decision: fix the integrity chain completely and leave it build-ready.
Regression: `./run_regression.sh` (build dir `$PCIE_SIM_DIR`, default under `/tmp`).

## Baseline (before changes)

There was no run script, so the README §4.1 flow was used. tb_8b10b, tb_phy,
tb_train, tb_dll, tb_tl, tb_loop, tb_mmio and tb_soc all passed (8/8). The
`tb_soc_mmio` and `pcie_soc_mmio.vhd` named in the README are not in the tree.

## Architecture after the fix

```
TX: req_* / completer --arbiter(whole TLPs)--> DLL_TX (seq, LCRC, replay buf)
      --> pcie_tlp_frame (STORE-AND-FORWARD TLP buffer + DLLP port + SKP) --> PIPE
RX: PIPE -> [pcie_elastic_buf, USE_EB] -> descrambler -> deframer
      TLP  -> rx_adapt (abort on framing errors) -> DLL_RX (LCRC + seq)
           -> pcie_rx_tlp_fifo (commit on good in-order TLP / rollback) -> TL_EP
      DLLP -> pcie_dllp_rx (CRC-16) -> Ack/Nak of the PEER -> local DLL_TX
      DLL_RX Ack/Nak scheduler -> Ack/Nak DLLP (f_acknak_dllp) -> framer
```

## Findings and changes

| Sev | Finding | Change |
|---|---|---|
| ALTA | TL was fed from rx_adapt before the LCRC and sequence checks; `dll_rx.tl_valid` was always '0' | `pcie_dll_rx.vhd` was rewritten. It writes header+payload tentatively into the new `pcie_rx_tlp_fifo.vhd` and commits only on a good LCRC with seq = NEXT_RCV_SEQ (`:215`). Everything else rolls back. rx_adapt no longer has a TL output. `pcie_node.vhd:320-339`. |
| ALTA | NAK was disabled, there was no replay timer, and the Ack loop was internal (the replay buffer was purged with the RX sequence space) | Real Ack/Nak DLLPs with CRC-16 now cross the link (`pcie_dll_pkg.vhd` `f_acknak_dllp`/`f_dllp_crc`, new `pcie_dllp_rx.vhd`, framer DLLP port, `pcie_node.vhd:258,341`). DLL_RX: duplicates (distance 1..2048) are re-Acked, bad, ahead or overflowing TLPs get a Nak gated by NAK_SCHEDULED (`:162,227`), and the AckNak latency timer coalesces Acks (`:134`, generic `ACKNAK_LAT`). DLL_TX: purges against the peer's AckNak_Seq_Num with spec modular arithmetic (ACKD_SEQ=4095, window check `:180`). It has a REPLAY_TIMER (`:206`, generic `REPLAY_TMO`, held while the link is down) and a 2-bit REPLAY_NUM whose rollover pulses `retrain_req` (`:220`). |
| ALTA | Replay buffer pointer had no wrap and no free-slot check | Circular buffer of 2^RB_LOG2 bytes with slot = seq mod SLOTS. A new TLP needs a free slot and MAX_TLP free bytes, otherwise `tl_ready` stays low (`:136`). MAX_TLP is enforced: an oversize TLP is aborted in the framer, no sequence number is consumed, and a counter is incremented (`:240`). |
| ALTA | MRd outside BAR0 was silently dropped, Length was ignored, and there was no completion timeout | `pcie_tl_ep.vhd`: Cpl with status UR for MRd that is out of BAR0 or runs past it, for MRd 4DW, and for unsupported non-posted requests (`:323`). MRd 1..1024 DW returns CplD(s) split at 64-byte RCB boundaries, max 16 DW each, with correct Byte Count and Lower Address (`:299`). MWr outside BAR0 is dropped. CfgWr0 now returns a Cpl, since it is non-posted (`:227`). Completion timeout on the requester side, in `pcie_node.vhd:397` (`ct_p`): 4 tags are tracked for MRd/CfgRd0/CfgWr0 sent on `req_*`, timeout is generic `CPL_TMO_C`, the IRQ bit is `I_CPL_TMO`, the count is in register ERR_STAT, and a new non-posted request is held back while all entries are busy. |
| MEDIA | MSI trigger clobbered the RX FSM in the middle of a parse | `msi_pend` is latched and served only from S_HDR with no header byte consumed. RX is not accepted in that cycle (`pcie_tl_ep.vhd:127-128`). |
| MEDIA | No RX backpressure during CplD streaming | `rx_ready` from `tl_ep` (`:128`) plus the RX TLP FIFO (512 B). |
| MEDIA | LT_RECOVERY was unreachable and L0 had no error exit | `pcie_ltssm.vhd:177`: L0 goes to Recovery on a received TS1 or on `retrain` (DLL REPLAY_NUM rollover, or a framing-error burst detector in `pcie_node.vhd:366`). Recovery has RcvrLock (TS1) and RcvrCfg (TS2), and exits to L0 after N TS2 received and 2N sent (`:210`). Timeout goes to Detect. Hot reset is honoured. While the link is in Detect, Hot Reset or Disabled the DLL is held in reset (DL_Down, `pcie_node.vhd:216`). |
| MEDIA | byte_fifo accepted writes when full; FWFT async read vs `ram_style` block | New `pcie_byte_fifo.vhd` with a registered read plus a prefetch output register (SRAM/BRAM-mappable), a full guard (`:57`) and a sticky `ovf`. `byte_fifo.vhd` is now an empty placeholder (the entity was renamed). It can be removed from the tree. |
| MEDIA | pcie_framer inserted logical idle inside an open TLP on underrun | `pcie_framer.vhd` is now store-and-forward (`:83,125`). The node framer `pcie_tlp_frame.vhd` is also store-and-forward (`:133`). The old version had the same underrun hole, and the replay path has a 1-cycle read bubble. |
| BAJA | rx_adapt bcnt cap; MAX_TLP enforcement | bcnt saturates and a runaway TLP is aborted (`pcie_rx_adapt.vhd:72`). Framing errors, an STP or ordered set inside a TLP, and EDB all abort (`out_abort`). The DLL RX enforces MAX_TLP. |
| BAJA | SKP insertion/removal hooks and elastic buffer | The framer holds a SKP OS that falls due inside a packet and inserts it at the next boundary. Before, it was silently skipped (`pcie_tlp_frame.vhd:119`). New `pcie_elastic_buf.vhd`: dual clock, Gray-coded pointers, SKP drop above HI_MARK and SKP repeat below LO_MARK, ovf/udf flags. `pcie_node` generic `USE_EB` (default false: the single-clock LOOP_INT model bypasses it, `:286`). A real recovered-clock PHY must enable it with `wclk` = RX clock. |
| (found) | TX mux could interleave a completer response into a request TLP in progress | Arbiter that locks to one whole TLP (`pcie_node.vhd:222`). |
| (found) | tl_ep re-parsed the payload of unknown TLPs or completions (≥12 bytes) as a new header, so a multi-DW CplD arriving at the RC could write the RC's BAR0 | Unknown TLPs are now drained (`S_DRAIN`, `:283`). |
| (found) | CplD Byte Count was in the wrong byte (0x04 in byte 6 means BC = 1024) | Byte Count is now in byte 6[3:0] and byte 7. |

MMIO (`pcie_mmio.vhd`, `pcie_mmio_pkg.vhd`): uses `pcie_byte_fifo`. The RX FIFO
is fed with the validated stream. New read-only registers ERR_STAT (0x3C) and
LINK_ERR (0x40), RX_CTRL bit1 = RX overflow, IRQ bit4 = completion timeout.
A TX_DATA write while the FIFO is full is dropped and flagged. The register
offsets used by the firmware are unchanged.

## Tests

- **tb_link.vhd (new, link level)**: two pcie_node instances connected through
  a channel model that corrupts bytes and drops TLPs or DLLPs on the scrambled
  symbol stream. It checks T1 corrupted TLP → Nak/replay with no corrupted data
  reaching BAR0; T2 dropped TLP → in-order recovery; T3 lost Acks → REPLAY_TIMER
  and duplicate discard; T4 UR completion; T5 multi-DW CplD with RCB split;
  T6 completion timeout; T7 REPLAY_NUM rollover → Recovery → L0; T8 MSI during
  an incoming MWr; T9 concurrent requests in both directions. **All PASS.** The
  pre-audit node fails T1: a scratch bench with the same corrupting channel
  showed the corrupted payload written to BAR0.
- **tb_dll.vhd (rewritten for the new interfaces)**: A clean, B LCRC error,
  C payload error, D free-slot back-pressure with Acks blocked, E 160 TLPs with
  random corruption (the buffer wraps many times), F REPLAY_TIMER, G REPLAY_NUM
  rollover, H MAX_TLP drop. All PASS. The pre-audit DLL does not compile against
  it (new ports). Behaviourally D, E, G and H cannot pass there: no slot check,
  no pointer wrap, no timer, no MAX_TLP.
- **tb_eb.vhd (new)**: elastic buffer at ±2000 ppm with 20 000 symbols. No loss
  or duplication, SKP dropped and added as expected.
- Adapted benches. tb_tl: honours `rx_ready` and expects the Cpl of CfgWr0
  (also checked). tb_loop: waits for the CfgWr0 completions before triggering
  MSI, as a driver would. Before, it relied on 20 idle cycles, which is too
  short for the validated store-and-forward path. tb_loop also passes with
  `USE_EB=true` (scratch run).

## Final status (`run_regression.sh`)

tb_8b10b, tb_phy, tb_train, tb_dll, tb_tl, tb_loop, tb_mmio, tb_soc, tb_link
and tb_eb (±2000 ppm): **11/11 PASS**. tb_soc still matches the ISS oracle
signature (firmware unchanged). The end timestamps of the README signature
table changed (more latency per TLP). See README §8.

## Not fixed / limits (honest)

- **Credit-based flow control (InitFC/UpdateFC) is not implemented.** RX buffer
  overflow is handled by Nak and replay, so no data is lost. Sustained
  backpressure longer than 4 replays triggers a retrain.
- The DLLP CRC-16 byte and bit order follows this IP's own LCRC convention
  (self-consistent). It has **not** been checked against a third-party link
  partner. The same applies to LCRC and scrambling (LOOP_INT only).
- Byte enables (First/Last BE) are not interpreted: full DWs are read and
  written, and Byte Count assumes full DWs.
- The single-buffer framer halves peak TX throughput (fill, then emit). A
  ping-pong buffer would fix it.
- The watchdog-style choices (timeouts in cycles) are generics with sim-friendly
  defaults. Set REPLAY_TMO, ACKNAK_LAT and CPL_TMO_C to the spec values for the
  real link rate.
- Needs board or PHY validation: a real recovered-clock SerDes with
  `USE_EB=true`, interoperation with a commercial root port or endpoint, and
  synthesis timing of the new DLL TX/RX (8-bit datapath, per-byte CRC).
