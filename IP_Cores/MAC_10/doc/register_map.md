# Core 21 — ETH GT — register map

AXI4-Lite, 32-bit, 8-bit byte address (the BD maps the bank at **`0xA400_0000`**,
64 KiB window, only the low 8 bits decode). Clock: `clk_pl_0` (40 MHz).

| Offset | Name | Access | Reset | Description |
|-------:|------|--------|-------|-------------|
| `0x00` | `ID` | RO | `0x47544521` | `"GTE"` + core number `0x21` |
| `0x04` | `SCRATCH` | RW | 0 | free |
| `0x08` | `CTRL` | RW | 0 | b0 `MAC_EN` (lets generator frames into the MAC; idles are always sent), b1 `GT_LOOPBACK` (near-end PMA, `ch0_loopback = 010`; needs `CMD.GT_RESET` after changing), b2 `PROMISC`, b3 `GEN_CONT`, b4 `TX_BITREV`, b5 `TX_HDRSWAP`, b6 `RX_BITREV`, b7 `RX_HDRSWAP`, b8 `TX_POLARITY`, b9 `RX_POLARITY` |
| `0x0C` | `CMD` | W | — | b0 `SOFT_RESET`, b1 `CNT_CLEAR`, b2 `GEN_START`, b3 `GEN_STOP`, b4 `INJ` (flip one bit of the next frame → FCS error), b5 `GT_RESET` (restart the GT reset sequence) |
| `0x10` | `STATUS` | RO | — | see below |
| `0x14` | `GT_CTRL` | RW | 0 | b0 `MANUAL` (reset FSM stopped, outputs from this register), b1 `LCPLLRESET`, b2 `TXMSTRESET`, b3 `RXMSTRESET`, b4 `TXUSERRDY`, b5 `RXUSERRDY` |
| `0x18` | `GEN_GAP` | RW | 0 | [15:0] extra idle cycles after every frame (rate control; 0 = line rate) |
| `0x1C` | `SNAP` | W | — | any write: freeze the 23 counters (both fast domains) into the shadow |
| `0x20` | `OWN_MAC_LO` | RW | `0x45474E02` | own MAC bytes 0..3 (byte 0 in b7:0) — source of the frames, RX filter |
| `0x24` | `OWN_MAC_HI` | RW | `0x204E` | bytes 4..5 → `02:4E:47:45:4E:20` |
| `0x28` | `PEER_MAC_LO` | RW | `0xFFFFFFFF` | destination MAC bytes 0..3 (the PC's NIC) |
| `0x2C` | `PEER_MAC_HI` | RW | `0xFFFF` | bytes 4..5 (default broadcast) |
| `0x30` | `OWN_IP` | RW | `0xC0A81502` | 192.168.21.2 (numeric, sent big-endian) |
| `0x34` | `PEER_IP` | RW | `0xC0A81501` | 192.168.21.1 |
| `0x38` | `PORTS` | RW | `0x52105211` | [31:16] UDP source port (21008), [15:0] destination port (21009) |
| `0x3C` | `LEN_CFG` | RW | `0x05C005C0` | [10:0] payload min, [26:16] payload max (clamped to 18..1472 → 60..1514-byte frames) |
| `0x40` | `LEN_STEP` | RW | 0 | [10:0] sweep step (min, +step, … wraps to min past max; 0 = fixed) |
| `0x44` | `GEN_COUNT` | RW | 1000 | frames per burst (ignored with `GEN_CONT`) |
| `0x48` | `TXCLK_MEAS` | RO | — | TXUSRCLK edges/128 per 100 ms → f = value × 1280 Hz |
| `0x4C` | `RXCLK_MEAS` | RO | — | same for RXUSRCLK |
| `0x80`–`0xD8` | counters | RO | — | snapshot of counters 0..22 |

## STATUS (`0x10`)

| Bit | Name | Meaning |
|----:|------|---------|
| 0 | `BLOCK_LOCK` | cl.49 block lock (64 valid sync headers; lost at 16 bad in 64) |
| 1 | `GEN_BUSY` | burst running (also 1 while a CMD is in flight) |
| 2 | `GEN_DONE` | last burst finished (0 while a CMD is in flight) |
| 3 / 4 | `RX_ACTIVE` / `TX_ACTIVE` | a good frame was received / sent since the last clear |
| 5 | `LINK_UP` | 64 consecutive blocks without a protocol error at the MAC |
| 8 | `SNAP_DONE` | both domains copied their counters |
| 9 | `CMD_BUSY` | the last CMD is not yet executed in both fast domains (AXI writes are held) |
| 10 | `CMD_TIMEOUT` | a domain did not confirm within 256 aclk (its clock stopped or in reset): its configuration was **not** updated |
| 11 / 12 | `SNAP_TX` / `SNAP_RX` | per-domain snapshot done |
| 16 | `GT_POWERGOOD` | `gtpowergood` |
| 17 | `LCPLL_LOCK` | `hsclk0_lcplllock` |
| 18 / 19 | `TX/RX_RESETDONE` | `ch0_tx/rxmstresetdone` |
| 20 | `RX_CDRLOCK` | `ch0_rxcdrlock` |
| 21 / 22 | `TX/RX_READY` | the reset sequence released that direction |
| 23 / 28 | `TX/RX_CLK_ALIVE` | the user clock toggled in the last 255 aclk cycles |
| 25:24 | FSM | common phase: 0 power-good wait, 1 PLL reset, 2 PLL lock wait, 3 running |
| 26 / 27 | TX/RX OK | that direction's reset track is in service |

## Counters (`0x80 + 4·i`)

All 32-bit, cleared by `CMD.CNT_CLEAR` or `SOFT_RESET`. Counters 0, 1, 14, 15
live in the TX domain, the rest in the RX domain.

| i | Offset | Name | Meaning |
|--:|-------:|------|---------|
| 0 | `0x80` | `TX_FRAMES` | frames sent |
| 1 | `0x84` | `TX_BYTES` | bytes on the wire incl. FCS (excl. preamble/IPG) = Σ(42 + L + 4) |
| 2 | `0x88` | `RX_OK` | good frames received |
| 3 | `0x8C` | `RX_BYTES` | bytes of good frames incl. FCS |
| 4 | `0x90` | `RX_CRC_ERR` | FCS residue mismatch |
| 5 | `0x94` | `RX_RUNT` | < 64 bytes |
| 6 | `0x98` | `RX_OVERSIZE` | > 1522 bytes |
| 7 | `0x9C` | `RX_ABORT` | frame cut by a control/error block |
| 8 | `0xA0` | `RX_FILTERED` | destination ≠ own MAC/broadcast (and not `PROMISC`) |
| 9 | `0xA4` | `RX_PROTO` | invalid block sequence/type (ordered sets count here too) |
| 10 | `0xA8` | `CHK_OK` | received frame is a valid generator frame (byte-exact) |
| 11 | `0xAC` | `CHK_BAD` | received frame differs from the generator format |
| 12 | `0xB0` | `CHK_SEQ_ERR` | sequence gap |
| 13 | `0xB4` | `CHK_RXERR` | frame flagged bad by the MAC |
| 14 | `0xB8` | `BURST_CYCLES` | TXUSRCLK cycles with the generator busy |
| 15 | `0xBC` | `TX_UNDERRUN` | MAC TX ran dry inside a frame (must stay 0) |
| 16 | `0xC0` | `BLK_SLIPS` | `rxgearboxslip` pulses |
| 17 | `0xC4` | `BAD_SYNC_HDR` | invalid sync headers (`00`/`11`) |
| 18 | `0xC8` | `LOCK_LOSS` | block-lock losses |
| 19 | `0xCC` | `RX_BLOCKS` | blocks passed to the PCS with lock |
| 20 | `0xD0` | `RX_IDLE` | idle control blocks (type `0x1E`) |
| 21 | `0xD4` | `RX_LF` | blocks carrying a **Local Fault** ordered set (types `0x4B`/`0x2D`/`0x55`) |
| 22 | `0xD8` | `RX_RF` | blocks carrying a **Remote Fault** ordered set — the partner does not decode what we send |

## Bit-order flags and link diagnosis

With a real link partner the four flags are found at run time (`eth21 autodetect`):

* **RX flags wrong** → block lock is still reached (a swapped header is still
  a valid header) but `RX_IDLE`/`RX_LF`/`RX_RF` stay at 0, `RX_PROTO` explodes.
* **RX flags right** → nearly every block is an idle or a fault ordered set.
* **TX flags wrong** → the partner cannot lock on us and answers **Remote
  Fault** (`RX_RF` grows); right → it sends idles and `RX_RF` = 0.
