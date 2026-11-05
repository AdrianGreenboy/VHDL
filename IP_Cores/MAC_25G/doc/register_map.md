# Core 20 — MAC 25G — register map

AXI4-Lite, 32-bit, 8-bit byte address. In the SoC the bank is reached by the
RV32 at **`0xD000_0000`** through `pcs_mmio_bridge`.

| Offset | Name | Access | Reset | Description |
|-------:|------|--------|-------|-------------|
| `0x00` | `ID` | RO | `0x4D414320` | `"MAC"` + core number `0x20` |
| `0x04` | `SCRATCH` | RW | 0 | free |
| `0x08` | `CTRL` | RW | 0 | b0 `MAC_EN` (lets generator frames into the MAC; idles are always sent), b1 `LOOPBACK` (parallel fabric loopback), b2 `PROMISC`, b3 `GEN_CONT` (generator ignores `GEN_COUNT`; end the burst with `GEN_STOP`) |
| `0x0C` | `CMD` | W | — | b0 `SOFT_RESET`, b1 `CNT_CLEAR`, b2 `GEN_START`, b3 `GEN_STOP`, b4 `INJ` (reads 0). See *command semantics* |
| `0x10` | `STATUS` | RO | 0 | b0 `LINK_UP` (64 consecutive blocks without a protocol error), b1 `GEN_BUSY`, b2 `GEN_DONE`, b3 `RX_ACTIVE`, b4 `TX_ACTIVE`, b8 `SNAP_DONE`, b9 `CMD_BUSY`, b10 `CMD_TIMEOUT` (the last `CMD` was not acknowledged by the fast domain within 256 `aclk` cycles) |
| `0x14` | `IRQ_STATUS` | RW1C | 0 | b0 `GEN_DONE`, b1 `RX_CRC_ERR`, b2 `CHK_ERR` (payload or sequence), b3 `LINK_LOST`. An event in the same cycle as the clear wins |
| `0x18` | `IRQ_ENABLE` | RW | 0 | `irq_out = OR(IRQ_STATUS & IRQ_ENABLE)` |
| `0x1C` | `SNAP` | W | — | any write: freeze the 16 counters into the shadow; `STATUS.SNAP_DONE` rises when done (cleared by the write) |
| `0x20` | `MAC_LO` | RW | `0x43414D02` | own MAC bytes 0..3 (byte 0 in b7:0) — also the generator destination |
| `0x24` | `MAC_HI` | RW | `0x2032` | own MAC bytes 4..5 → `02:4D:41:43:32:20` |
| `0x28` | `SRC_LO` | RW | `0x45474E02` | generator source MAC bytes 0..3 |
| `0x2C` | `SRC_HI` | RW | `0x204E` | generator source MAC bytes 4..5 → `02:4E:47:45:4E:20` |
| `0x30` | `LEN_CFG` | RW | `0x05EA0014` | b10:0 `len_min`, b26:16 `len_max` — L2 length **without FCS**. Effective `len_min ≥ 20` (generator header) |
| `0x34` | `LEN_STEP` | RW | 37 | b10:0 sweep step (`len_min`, `+step`, …, wraps to `len_min` past `len_max`) |
| `0x38` | `GEN_COUNT` | RW | 64 | frames per burst |
| `0x40`–`0x7C` | counters | RO | — | snapshot of counters 0..15 (below) |

## Counters (`0x40 + 4·i`)

All 32-bit, cleared by `CMD.CNT_CLEAR` or `SOFT_RESET`. RX frame counters are
mutually exclusive: every received frame increments **exactly one** of
`RX_OK`, `RX_CRC_ERR`, `RX_RUNT`, `RX_OVERSIZE`, `RX_ABORT`, `RX_FILTERED`
(priority filter > abort > runt > oversize > CRC).

| i | Offset | Name | Meaning |
|--:|-------:|------|---------|
| 0 | `0x40` | `TX_FRAMES` | frames transmitted |
| 1 | `0x44` | `TX_BYTES` | wire bytes incl. padding and FCS, excl. preamble/IPG |
| 2 | `0x48` | `RX_OK` | good frames delivered |
| 3 | `0x4C` | `RX_BYTES` | bytes of good frames incl. FCS |
| 4 | `0x50` | `RX_CRC_ERR` | FCS residue ≠ `0xDEBB20E3` |
| 5 | `0x54` | `RX_RUNT` | < 64 bytes incl. FCS (also `/S/` followed directly by `/T0/`) |
| 6 | `0x58` | `RX_OVERSIZE` | > 1522 bytes incl. FCS |
| 7 | `0x5C` | `RX_ABORT` | frame interrupted by `/I/`, `/S/`, `/E/` or an unsupported block |
| 8 | `0x60` | `RX_FILTERED` | destination neither own, broadcast, nor `PROMISC` |
| 9 | `0x64` | `RX_PROTO` | protocol events: bad preamble/SFD, lane-4 start (`0x33`/`0x66`), ordered sets, unknown block type, `/E/` or data/terminate outside a frame (one per offending block) |
| 10 | `0x68` | `CHK_OK` | checker: frame byte-identical to the generator pattern |
| 11 | `0x6C` | `CHK_BAD` | checker: payload, header, padding or length mismatch |
| 12 | `0x70` | `CHK_SEQ_ERR` | checker: sequence number ≠ previous + 1 |
| 13 | `0x74` | `CHK_RXERR` | frames delivered with `tuser = 1` (bad per the MAC) |
| 14 | `0x78` | `BURST_CYCLES` | `clk_dp` cycles with the generator busy (throughput) |
| 15 | `0x7C` | `TX_UNDERRUN` | source deasserted `tvalid` mid-frame (`/E/` sent) |

## Command semantics (`CMD`)

* `CTRL` and all configuration registers are **captured into the 390.625 MHz
  domain when `CMD` is written**. Write the configuration first, then a
  command (`SOFT_RESET` is the usual one).
* **Every register write is held (AXI `awready` low) while a command is in
  flight** to the data-plane domain. Commands are therefore never lost or
  reordered, however fast software writes them, and the configuration cannot
  change while it is being captured. If the fast domain does not acknowledge
  within 256 `aclk` cycles (clock stopped or in reset), the hold is released
  and `STATUS.CMD_TIMEOUT` is set: the bus never hangs.
* `GEN_STOP` ends a burst at the next frame boundary (the frame in progress is
  completed); `GEN_DONE` then rises as for a counted burst.
* While `CMD_BUSY = 1`, `STATUS.GEN_DONE` reads 0 and `GEN_BUSY` reads 1, so a
  poll issued right after `GEN_START` never sees the previous burst's `DONE`.
* `INJ` arms a single bit flip (bit 0 of the 2nd data block) of the next frame
  that **starts** after the command, even if a frame is in progress.
  `GEN_START | INJ` in one write corrupts frame 0 of the burst,
  deterministically.
* B and R responses are issued one cycle after the AW/W and AR handshakes.
* Do not combine `SOFT_RESET` with other bits (the reset wins).

## Audit 2026-11 additions (supersede the tables above where they differ)

| Offset | Name | Access | Reset | Description |
|-------:|------|--------|-------|-------------|
| `0x08` | `CTRL` | RW | 0 | adds b4 `RX_HOLD`: the RX FIFO consumer (checker) is stalled, to exercise back-pressure / PAUSE |
| `0x0C` | `CMD` | W | — | adds b5 `SEND_PAUSE` (one PAUSE frame with `PAUSE_SWQ` quanta). A CMD write without byte lane 0 in `WSTRB` does nothing |
| `0x10` | `STATUS` | RO | 0 | adds b5 `PAUSED` (pause timer running), b6 `XOFF` (RX FIFO above the high watermark) |
| `0x38` | `GEN_COUNT` | RW | 64 | `0` with `GEN_CONT = 0` is an empty burst: `GEN_DONE` at once, no frame |
| `0x3C` | `PAUSE_CTRL` | RW | `0xFFFF0000` | b0 `HONOR` (obey received PAUSE), b1 `AUTO` (XOFF/XON from the RX FIFO watermarks), b31:16 XOFF `pause_time` (quanta of 512 bit times) |
| `0x80` | `PAUSE_WM` | RW | `0x01800080` | b15:0 low, b31:16 high watermark of the RX FIFO (1024 words of 8 bytes). Headroom above the high mark must hold the partner's reaction (own frame in flight + partner frame in flight + cable/pipeline): keep `1024 - high >= 640` words |
| `0x84` | `PAUSE_SWQ` | RW | 0 | quanta of `CMD.SEND_PAUSE` |
| `0xA0`–`0xBC` | counters 16..23 | RO | — | `RX_PAUSE` (honoured), `TX_PAUSE` (sent), `RX_CTRL` (MAC control frames consumed), `RX_FIFO_DROP` (frames dropped, no room), `TX_KEEP_ERR` (malformed `tkeep`), `BLK_FIFO_OVF`, `PAUSED_SLOTS`, `RX_FIFO_MAX` (high-water mark, words) |

* All counters saturate at `0xFFFFFFFF` instead of wrapping.
* `WSTRB` is honoured per byte lane on every RW register.
* Unmapped or unaligned offsets answer `SLVERR` (`bresp`/`rresp = 0b10`);
  writes to RO offsets are ignored with `OKAY`.
* `CMD_TIMEOUT`: the timed-out command is **killed** — it is not executed
  later when `clk_dp` comes back; the next `CMD` supersedes it.
* `GEN_BUSY`/`GEN_DONE` and `BURST_CYCLES` now include the TX frame FIFO:
  the burst is done when the last word has entered the MAC.
