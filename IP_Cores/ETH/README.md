# Ethernet MAC 10/100 (TSN family, v1)

A synthesizable VHDL-2008 Media Access Controller for 100 Mbit/s Ethernet over
MII, built as an IP core for a custom RV32IM SoC (SoC v3) targeting the Trenz
**TE0950** board (AMD Versal `xcve2302-sfva784-1LP-e-S`). This is the base MAC
on top of which future TSN layers (PTP/802.1AS, Time-Aware Shaper, Frame
Preemption, CBS, FRER) will be built; **no TSN is implemented in v1**.

Silicon-validated on the TE0950: **8/8 signature match**, timing closed at
**WNS +3.133 ns**.

## Architecture

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 760 560" font-family="Helvetica,Arial,sans-serif">
  <defs>
    <style>
      .bg{fill:#e9f4f4;}
      .blk{fill:#ffffff;stroke:#2f8f8f;stroke-width:2;rx:6;}
      .accent{fill:#2f8f8f;}
      .lite{fill:#d4ebeb;stroke:#2f8f8f;stroke-width:1.5;}
      .t{fill:#14504f;font-size:13px;}
      .tb{fill:#14504f;font-size:13px;font-weight:bold;}
      .ts{fill:#14504f;font-size:11px;}
      .tw{fill:#ffffff;font-size:13px;font-weight:bold;}
      .ln{stroke:#2f8f8f;stroke-width:1.8;fill:none;}
      .lnd{stroke:#2f8f8f;stroke-width:1.5;fill:none;stroke-dasharray:5 3;}
    </style>
    <marker id="ah" markerWidth="9" markerHeight="9" refX="7" refY="4.5" orient="auto">
      <path d="M0,0 L9,4.5 L0,9 z" fill="#2f8f8f"/>
    </marker>
  </defs>

  <rect class="bg" x="0" y="0" width="760" height="560"/>
  <text x="30" y="34" class="tb" font-size="19">Ethernet MAC 10/100 (TSN family v1) — RV32IM SoC v3 / TE0950</text>
  <text x="30" y="54" class="ts">MII @ 25 MHz, nibble datapath, HW CRC-32, LOOP_INT self-test</text>

  <!-- PS / DDR -->
  <rect class="blk" x="30" y="80" width="150" height="70" rx="6"/>
  <text x="42" y="104" class="tb">Versal PS</text>
  <text x="42" y="122" class="ts">A72 + axil_soc</text>
  <text x="42" y="138" class="ts">ctrl 0x8000_0000</text>

  <rect class="blk" x="30" y="470" width="150" height="60" rx="6"/>
  <text x="42" y="494" class="tb">LPDDR4</text>
  <text x="42" y="512" class="ts">rv32i_reserved 0x7000_0000</text>

  <!-- RV32 core -->
  <rect class="blk" x="230" y="80" width="150" height="70" rx="6"/>
  <text x="244" y="104" class="tb">RV32IM core</text>
  <text x="244" y="122" class="ts">5-stage pipeline</text>
  <text x="244" y="138" class="ts">imem / dmem bus</text>

  <!-- mem_subsys -->
  <rect class="blk" x="230" y="200" width="150" height="80" rx="6"/>
  <text x="244" y="224" class="tb">mem_subsys_eth</text>
  <text x="244" y="242" class="ts">decode addr[31:28]</text>
  <text x="244" y="258" class="ts">1101 -> ETH MMIO</text>
  <text x="244" y="274" class="ts">0100 -> DMA burst</text>

  <!-- DMA -->
  <rect class="blk" x="30" y="200" width="150" height="80" rx="6"/>
  <text x="42" y="224" class="tb">dma_burst</text>
  <text x="42" y="242" class="ts">AXI4 INCR &lt;=16</text>
  <text x="42" y="258" class="ts">local -&gt; DDR</text>
  <text x="42" y="274" class="ts">ddr_base + dst</text>

  <!-- ETH MMIO block -->
  <rect class="accent" x="430" y="80" width="300" height="200" rx="8"/>
  <text x="446" y="104" class="tw" font-size="15">eth_mmio  (0xD000_0000)</text>
  <rect class="lite" x="446" y="116" width="128" height="46"/>
  <text x="456" y="134" class="ts">TXD/RXD FIFOs</text>
  <text x="456" y="150" class="ts">spw_fifo W=9 (EOF)</text>
  <rect class="lite" x="586" y="116" width="128" height="46"/>
  <text x="596" y="134" class="ts">CTRL/MAC/STAT</text>
  <text x="596" y="150" class="ts">IRQEN, stickies</text>
  <rect class="lite" x="446" y="172" width="268" height="40"/>
  <text x="456" y="190" class="ts">store-and-forward: frames_pending (EOF count)</text>
  <text x="456" y="205" class="ts">IRQ = OR(STAT and IRQEN)  |  pop-on-read RXD</text>
  <rect class="lite" x="446" y="222" width="268" height="46"/>
  <text x="456" y="240" class="ts">rdata COMBINATIONAL (dmem contract)</text>
  <text x="456" y="256" class="ts">EN=0 -> FIFO flush ; sel/we ; arstn=not rst</text>

  <!-- MAC core -->
  <rect class="accent" x="430" y="310" width="300" height="150" rx="8"/>
  <text x="446" y="334" class="tw" font-size="15">eth_mac  (MII datapath)</text>
  <rect class="lite" x="446" y="346" width="128" height="50"/>
  <text x="456" y="364" class="tb" font-size="12">eth_tx_mii</text>
  <text x="456" y="380" class="ts">pre+SFD+CRC+IPG</text>
  <rect class="lite" x="586" y="346" width="128" height="50"/>
  <text x="596" y="364" class="tb" font-size="12">eth_rx_mii</text>
  <text x="596" y="380" class="ts">SFD+FCS+filter</text>
  <rect class="lite" x="446" y="404" width="268" height="44"/>
  <text x="456" y="422" class="tb" font-size="12">mii_ce /4 (25 MHz)  +  LOOP_INT mux</text>
  <text x="456" y="438" class="ts">loopback: TXD-&gt;RXD, TX_EN-&gt;RX_DV in PL</text>

  <!-- MII pads -->
  <rect class="blk" x="620" y="486" width="110" height="54" rx="6"/>
  <text x="632" y="508" class="tb" font-size="12">MII pads</text>
  <text x="632" y="524" class="ts">bank 302 HDIO</text>
  <text x="632" y="537" class="ts">(inert in v1)</text>

  <!-- arrows -->
  <line class="ln" x1="180" y1="115" x2="230" y2="115" marker-end="url(#ah)"/>
  <text x="186" y="110" class="ts">AXI-Lite</text>
  <line class="ln" x1="305" y1="150" x2="305" y2="200" marker-end="url(#ah)"/>
  <line class="ln" x1="230" y1="240" x2="180" y2="240" marker-end="url(#ah)"/>
  <line class="ln" x1="380" y1="180" x2="430" y2="180" marker-end="url(#ah)"/>
  <text x="384" y="174" class="ts">sel/we/rdata</text>
  <line class="ln" x1="105" y1="280" x2="105" y2="470" marker-end="url(#ah)"/>
  <text x="110" y="380" class="ts">DMA doorbell</text>
  <line class="ln" x1="580" y1="280" x2="580" y2="310" marker-end="url(#ah)"/>
  <text x="586" y="298" class="ts">byte-stream</text>
  <line class="lnd" x1="675" y1="460" x2="675" y2="486" marker-end="url(#ah)"/>

  <!-- loop_int note -->
  <path class="lnd" d="M 714 371 C 745 371 745 425 714 425" marker-end="url(#ah)"/>
  <text x="700" y="400" class="ts" transform="rotate(90 700 400)">LOOP_INT</text>

  <text x="30" y="552" class="ts">Silicon PASS: 8/8 signature @ 0x7000_0000  |  WNS +3.133 ns  |  MTU 1518  |  MIT license</text>
</svg>

## 1. Overview

The core implements a full-duplex 100 Mbit/s Ethernet MAC with an MII interface
clocked at 25 MHz. The datapath processes one **nibble (4 bits) per cycle** in
SDR mode. MII was chosen over RGMII specifically to avoid the sub-nanosecond
skew of DDR signalling and to let timing close comfortably; the external RGMII
PHY and MDIO management are on the v1.1 roadmap.

For silicon bring-up the MAC runs in **internal loopback (LOOP_INT)**: the TX
engine feeds back into the RX engine inside the PL, without leaving through the
MII pads. A deterministic signature is compared bit-for-bit against an
instruction-set-simulator (ISS) oracle.

## 2. Feature set (v1)

- 100 Mbit/s, MII at 25 MHz, nibble datapath, SDR.
- **TX**: preamble (7x0x55) + SFD (0xD5), MAC dst/src, EtherType/length,
  payload, hardware **FCS/CRC-32**, 96 bit-time IPG, padding to 60 data bytes.
- **RX**: preamble/SFD detection, nibble deserialization, **FCS verification**
  (bad-CRC frames dropped), **destination MAC filtering** (own unicast +
  broadcast + register-controlled promiscuous mode).
- **Frame delivery over MMIO**: byte-by-byte FIFOs, complete frames of any size
  up to the MTU.
- **MTU 1518 bytes** (14 header + 1500 payload + 4 FCS).
- **LOOP_INT** internal loopback for a deterministic silicon self-test.

Out of scope for v1 (roadmap): external RGMII PHY + MDIO + auto-negotiation;
1 Gbit/s; and all TSN features.

## 3. Register map (MMIO @ 0xD000_0000)

Region decoded by `addr[31:28] = "1101"` in `mem_subsys_eth`. Word offsets:

| Offset | Name  | Access | Fields |
|-------:|-------|--------|--------|
| 0x00 | CTRL  | RW | b0 EN, b1 LOOP_INT, b2 PROMISC |
| 0x04 | MACLO | RW | MAC[31:0] (byte0 in b7:0) |
| 0x08 | MACHI | RW | MAC[47:32] |
| 0x0C | CMD   | W1P | b0 TX_FLUSH, b1 RX_FLUSH |
| 0x10 | STAT  | R  | b0 TX_BUSY, b4 TXF_EMPTY, b5 TXF_FULL, b6 RXF_EMPTY, b7 RXF_FULL, b14:8 rxf_level; stickies b16 RX_OK, b17 RX_CRC, b18 RX_RUNT, b19 RX_DROP, b20 TX_UNDERRUN, b21 TXF_OVF, b22 RXF_OVF. Any write clears stickies (same-cycle sets win). |
| 0x14 | TXD   | W  | b7:0 data, b8 EOF (last byte of frame); R: b12:0 txf_level, b13 txf_full |
| 0x18 | RXD   | R  | pop-on-read b7:0 data, b8 EOF, b31 VALID |
| 0x1C | IRQEN | RW | mask over STAT; irq = OR(STAT and IRQEN) |

The `rdata` path is **combinational** in the same cycle as `sel` (dmem read
contract). A registered `rdata` passes MMIO polling tests but fails at SoC
level, where every `lw` returns the previous read's data.

## 4. Frame format

```
7x preamble (0x55) | SFD (0xD5) | dst[6] | src[6] | type/len[2] | payload[46..1500] | FCS[4]
```

Minimum 64 bytes on the wire (with FCS); payloads shorter than 46 bytes are
zero-padded to 60 data bytes. IPG is 96 bit-times = 24 nibbles of idle
(TX_EN low) between frames.

## 5. CRC-32

Ethernet CRC-32: polynomial 0x04C11DB7, reflected (0xEDB88320 in the shift
form), init 0xFFFFFFFF, final complement. Processed **per nibble** (LSB first),
matching the MII datapath exactly. On RX, running the reflected CRC (init
0xFFFFFFFF, un-complemented) over the whole frame including the FCS yields the
canonical residue **0xDEBB20E3** for a valid frame; the RX engine uses this as
its accept criterion. The convention is anchored against zlib
(`0xCBF43926` for "123456789").

## 6. Store-and-forward TX

The TX FIFO stores bytes with a 9th "EOF" bit marking the last byte of each
frame. The MAC does **not** start transmitting until a complete frame is present
in the FIFO (tracked by a `frames_pending` counter of written EOFs). This
prevents underrun when firmware writes bytes slower than the engine drains
them — a real hazard observed at SoC level, where each store takes two cycles.
FIFOs are sized at 2048 bytes (LOG2_DEPTH=11) to hold a full MTU frame.

## 7. LOOP_INT self-test

With `CTRL.LOOP_INT = 1`, an internal mux feeds TXD -> RXD and TX_EN -> RX_DV
inside the PL, sharing the internally divided 25 MHz clock-enable (/4 from the
100 MHz core clock). The MII pads become inert. A frame written by firmware
travels TX -> loopback -> RX and, if it passes FCS and MAC filtering, appears
intact in the RX FIFO. This is the mechanism behind the silicon self-test.

## 8. Verification: five layers

Every layer is bit-exact against an independent model, and every layer carries
mutations that **must** fail:

- **Layer 1a** — TX engine vs an independent event-driven MII receiver model
  (own byte-wise CRC). 5 frames + 4 mutations. PASS @62065 ns.
- **Layer 1b** — RX engine vs a bit-bang nibble transmitter with injected
  corruptions (short preamble, bad SFD, broken CRC, runt). PASS @214845 ns.
- **Layer 1c** — full MAC in LOOP_INT, full-duplex, with a **phase-0
  anti-common-mode** test (silent partner: RX must produce nothing) and an
  independent cable watcher (first nibble after silence is always 0x5, valid
  SFD). PASS @60305 ns.
- **Layer 2** — MMIO register bank vs a dmem bus BFM; a 114-byte frame round-
  trips through MMIO, stickies and level-IRQ verified. PASS @16325 ns.
- **Layer 4** — full SoC (real `mem_subsys_eth` decode + real DMA) with a bus
  master running the ISS script; signature DMA'd to DDR and compared against
  the Python ISS. PASS @260265 ns.
- **Layer 5** — silicon on the TE0950. 8/8 signature match.

## 9. Toolflow

- **Simulation**: GHDL 4.1.0 (`--std=08`).
- **Synthesis / implementation**: Vivado 2025.2.1. WNS +3.133 ns.
- **Embedded Linux**: PetaLinux 2025.2.1; reserved-memory at 0x7000_0000.
- **Assembler**: `asm.py` (RV32IM subset).
- **PS verifier**: `aarch64-linux-gnu-gcc -O2 -static`.

## 10. Vivado integration

The block design is cloned from the prior IP and the module reference swapped
for `soc_top_eth_wrap`. The PL master goes to a dedicated NoC slave interface
(`S06_AXI`) with its own `aclk6`; Connection Automation is never used for PL
masters on Versal (it routes to S_AXI_LPD without DDR). Address map:
`m_axi -> C0_DDR_LOW0 @ 0x0`, `s_axi/reg0 @ 0x8000_0000` range 64K. MII pins are
placed on **bank 302 HDIO** (LVCMOS33); inert under LOOP_INT but constrained.

## 11. Bring-up flow

The RV32 firmware (`eth_bringup.s`) configures the MAC, enables EN+LOOP_INT,
transmits six frames, reads back the accepted ones, computes an 8-word
signature, and DMA-volumes it (plus a sentinel) to DDR at 0x7000_0000. The PS
verifier (`eth_verify.c`) loads the firmware through the IMEM window, sets
DDR_BASE, releases the core, polls the sentinel in DDR, and compares the
signature against the ISS. Because `axi_owns_mem = CONTROL.bit0`, the PS reads
the signature from **physical DDR** (via the DMA), not the DMEM window.

## 12. Signature

| Word | Meaning | Value |
|-----:|---------|-------|
| 0 | sum of frame-0 RX bytes | 0x00001A26 |
| 1 | frame-0 length (padded) | 0x0000003C |
| 2 | xor of frame-1 RX bytes | 0x000000AD |
| 3 | frame-1 length | 0x00000072 |
| 4 | frame-2 first byte (broadcast) | 0x000000FF |
| 5 | frame-3 dropped (alien MAC) | 0x0000D40D |
| 6 | control CRC value | 0x4C6D2BDF |
| 7 | frame-5 length (MTU) | 0x000005EA |

## 13. File layout

```
eth_ip/
  rtl/   eth_pkg, eth_tx_mii, eth_rx_mii, eth_mac, eth_mmio,
         mem_subsys_eth, soc_top_eth (+ _wrap.v)
  tb/    tb_eth_tx_l1a, tb_eth_rx_l1b, tb_eth_mac_l1c, tb_eth_mmio_l2, tb_eth_l4
  sim/   run_l1a..l4, iss_eth.py
  vivado/ bd_eth_steps.tcl, run_synth_eth.tcl, run_impl_eth.tcl
  bringup/ eth_bringup.s/.mem, eth_verify.c, iss_rv32.py
  docs/  eth_arch.svg
  eth_pins.xdc
```

Shared sources (`spw_fifo.vhd`, RV32 core, `asm.py`) are referenced from their
origin, never duplicated.

## 14. License

MIT.
