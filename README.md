# VHDL IP Cores

**Welcome!** 👋

This repository is a growing collection of **IP cores written from scratch in
VHDL-2008**, every one of them taken from the first RTL line to **working
silicon** on real FPGA hardware (AMD Versal, Trenz TE0950), driven by a
RISC-V soft core that also lives in this repo.

Everything here was made to be **freely distributed, studied, modified and
reused** — that is the whole point. All cores are released under the
**MIT license**: use them in your hobby project, your thesis, your product or
your classroom, with or without changes, no strings attached. If they save
you a week of work or teach you one synthesis trap, they have done their job.

You are welcome here whether you want to:

- **Use** a core as-is in your own SoC or FPGA design,
- **Read** the code to learn how a link controller, a time-sync engine or a
  pipelined CPU is actually built and verified,
- **Modify** anything to fit your needs (please do — that's what the MIT
  license is for),
- **Report** a bug, ask a question or share what you built — issues and PRs
  are genuinely appreciated, from typo fixes to new features.

No gatekeeping: beginner questions are as welcome as expert patches.

---

## What makes these cores different

Every core in this collection follows the same battle-tested methodology:

1. **Layered verification with bit-identical signatures.** Each core is
   verified in GHDL (`--std=08`) against **independent models and Python
   oracles that share zero code with the RTL**, layer by layer: blocks →
   protocol loopback → MMIO contract → full SoC running real firmware in
   lockstep with an instruction-set simulator. Testbenches are armed against
   themselves with deliberate RTL mutations.
2. **Real silicon, not just simulation.** Every core marked **SILICON PASS**
   ran its full self-test on a Trenz TE0950 (Versal `xcve2302`), loaded by an
   RV32 firmware and checked word-for-word against the simulation-derived
   signature via a DMA report to DDR.
3. **Honest documentation.** Each core's README documents not only how to use
   it, but **every problem faced during bring-up and its lesson** — including
   the toolchain traps (Vivado synthesis bugs, ghost source files, stale
   bitstreams) so you don't have to rediscover them the hard way.
4. **Self-contained and tool-friendly.** GHDL for simulation, plain shell
   scripts, a small Python assembler, batch-mode Vivado TCL — no proprietary
   simulators, no license servers, nothing you can't run on a stock Ubuntu
   machine.

## Repository structure

Every IP core follows the same family layout:

```
IP_Cores/<CORE>/
├── rtl/            VHDL-2008 sources of the core
├── sim/            testbenches, Python oracles, run_*.sh regression scripts
├── fw/             RV32 firmware (.s -> .mem via asm.py) for layer 4 / bring-up
├── bringup/        Linux-side tools (aarch64, static) + expected signatures
├── vivado*/        Vivado project / rebuild TCL for the silicon flow
├── architecture.svg  block diagram
├── README.md       full documentation: registers, usage, verification,
│                   silicon flow, problems faced, roadmap
└── AUDIT_FIXES.md  audit-2026-11: every finding, the fix, the test that
                    fails on the old RTL, and what is still open
```

## The cores

> Each core has its own README with the full story — register maps, software
> examples, the complete build flow from zero, and the honest log of problems.
> Start there.
>
> **About the Status column:** it records the silicon result of the **v1.x**
> RTL. Every core was then reworked in the **v2.0 audit (Nov 2026)**, see
> [Version history](#v20--audit-2026-11-november-2026). The v2.0 RTL is
> verified in GHDL. Board re-validation is still pending, and each core's
> `AUDIT_FIXES.md` lists exactly what to re-check.

| Core | What it is | Status |
|---|---|---|
| **[RV32i](IP_Cores/RV32i/)** | A complete **RV32IM SoC**: 5-stage pipelined RISC-V CPU (hardware multiply/divide, CSRs, CLINT), local RAM, burst **DMA engine** with AXI4 master to DDR, MMIO bus for peripherals, plus its own Python assembler (`asm.py`) and ISS used as the golden oracle by every other core. This is the heart that drives all the bring-ups. | **SILICON PASS** — GEMV from LPDDR4 up to 64×64, 100 MHz, WNS +3.2 ns |
| **[RV64IMAC](IP_Cores/RV64IMAC/)** | **Linux-capable 64-bit RISC-V SoC**: RV64IMAC core with M/S/U privilege levels, **Sv39 MMU**, I$/D$, AXI4 master, CLINT/PLIC, and native one-cycle MMIO slots for the rest of the family. It boots **OpenSBI + MMU Linux**, checked instruction by instruction against an independent Python ISS (itself checked against Spike). The production CPU of the family, aimed at an ASIC on IHP SG13G2. | **SILICON PASS** — OpenSBI 1.6 + Linux 6.6 to `/init` on TE0950 @ 50 MHz, WNS +2.28 ns, 16.5 k LUT |
| **[SPW](IP_Cores/SPW/)** | **SpaceWire** link controller (ECSS-E-ST-50-12C): Data-Strobe codec, full ECSS link FSM, credit-based flow control, Time-Codes, 9-bit N-Char FIFOs, internal loopback self-test. The spacecraft onboard network, memory-mapped for an RV32. | **SILICON PASS** — 10/20/25/50 Mbit/s, WNS +2.740 ns |
| **[PTP](IP_Cores/PTP/)** | **PTP / IEEE 802.1AS** (gPTP) time-sync endpoint: 80-bit PTP clock with PI servo, hardware SFD timestamping, peer-delay measurement in hardware, master/slave Sync loop, and its **own MII Ethernet MAC** with 1-step timestamp override. The time plane of TSN. | **SILICON PASS** — mpd 40 ns, offset 0, WNS +1.171 ns |
| **[ADCS](IP_Cores/ADCS/)** | **ADCS MPC accelerator**: a projected-gradient QP solver for spacecraft attitude control — dense `70×70` float32 GEMV + gradient + clamp, iterated in hardware, on an **8-lane fused multiply-add datapath** bit-exact to the AMD FPO. Two AXI masters to DDR, an on-chip sequencer (`LOAD_H → solve → STORE_U`), governed by the RV32. The compute plane of an ADCS. | **SILICON PASS** — signature `0x0C4CCCD2` bit-identical sim↔silicon, WNS +2.844 ns |
| **[DSP](IP_Cores/DSP/)** | **DSP accelerator**: four fixed-point Q1.15 engines behind one MMIO window — **CORDIC** (rotation/vectoring), symmetric linear-phase **FIR**, radix-2 **complex FFT/IFFT** up to N=1024, and **real-input FFT**. The FFT is a **ping-pong dual-bank Block-RAM** design (in-place is not BRAM-implementable); all buffers infer BRAM. Bit-exact to a NumPy oracle across five layers. The signal-processing plane for ADCS/sensor workloads. | **SILICON PASS** — CORDIC & FFT bit-exact on TE0950, 5.57% LUTs, WNS +0.867 ns |
| **[RF](IP_Cores/RF/)** | **RF Digital Front-End (DDC/DUC)** for software-defined radio: a complex `I/Q` `Q1.15` chain — 32-bit **NCO** with dual sin/cos LUT, complex **mixer**, **CIC** sinc³ decimator/interpolator (`R∈{4,8,16,32}`), a **5-stage pipelined 16-tap FIR** (maps to DSP58), and **AGC/RSSI**. An on-chip programmable **tone generator** drives the chain (no ADC/DAC on the board). Two AXI masters to DDR through the NoC (family DMA + the RF's own), governed by the RV32. The signal plane of the family. | **SILICON PASS** — signature `0xB74940EB` bit-identical sim↔silicon, 59 DSP58, WNS +0.146 ns |
| **[ADC](IP_Cores/ADC/)** | **Delta-sigma ADC** digital datapath: the complete *digital* chain of a ΔΣ converter — a 2nd-order digital delta-sigma **modulator** (CIFB) as an on-chip PDM test source, a **sinc³ CIC decimator** (OSR ∈ {32,64,128,256}, 26-bit accumulators), a Block-RAM sample FIFO, MMIO bank, and DMA of the decimated stream to DDR. The analog modulator hooks (`pdm_ext_i`/`pdm_fb_o`) are already wired for a real front-end. Bit-exact across five layers. | **SILICON PASS** — signature `0x1B8D3FF9`, WNS +2.444 ns |
| **[CAN](IP_Cores/CAN/)** | **CAN 2.0** controller: bit timing, stuffing, CRC, arbitration, error handling, TX/RX buffers over the family MMIO bus. | **SILICON PASS** — 125k/250k/500k/1M bit/s, WNS +0.603 ns |
| **[M1553](IP_Cores/M1553/)** | **MIL-STD-1553B** bus terminal: Manchester II encoding/decoding, command/status word handling, the classic avionics bus. | **SILICON PASS** — 8/8 signature vs ISS, WNS +3.110 ns |
| **[ETH](IP_Cores/ETH/)** | **Ethernet MAC 10/100** over MII: full TX/RX engines with CRC-32, MAC filtering, store-and-forward FIFOs and `LOOP_INT` self-test. The base MAC of the TSN family (PTP builds on it). | **SILICON PASS** — 8/8 signature, WNS +3.133 ns |
| **[TSN](IP_Cores/TSN/)** | **TSN Ethernet switch** (4-port): synthesizable store-and-forward switch with full **FCS (CRC-32)** validation on ingress, header parsing, per-port counters (RX/TX/overflow/FCS-drop/802.1Q-tag), and 802.1Q frame recognition. Register space is already reserved for an 802.1Qbv time-aware shaper (phase 2). A built-in MII injector makes it **PHY-less and generator-less** on silicon. | **SILICON PASS** — signature `0x64476b7f` bit-identical vs ISS, WNS +1.837 ns |
| **[USART](IP_Cores/USART/)** | **USART/UART** with the family MMIO interface — also the reference "hello world" of the SoC bring-up flow. | **SILICON PASS** — 115200/921600/3M/6M baud, WNS +2.801 ns |
| **[SPI](IP_Cores/SPI/)** | **SPI master** controller (all 4 modes), memory-mapped, with DMA echo self-test. | **SILICON PASS** — SCLK 12.5/25/50 MHz, WNS +2.18 ns |
| **[IIC](IP_Cores/IIC/)** | **I²C** controller (master **and** slave engines), memory-mapped, with wired-AND `LOOP_INT` self-test. | **SILICON PASS** — 100k/400k/1M, WNS +2.958 ns |
| **[I3C](IP_Cores/I3C/)** | **MIPI I3C Basic (SDR)** controller **and** target — ENTDAA, private R/W, T-bit seize, IBI with mandatory byte. | **SILICON PASS** — 3.125/6.25/12.5 MHz push-pull, WNS +2.844 ns |
| **[PCIe](IP_Cores/PCIe/)** | **PCI Express** soft stack (fully in fabric, no hard block, no GTYP): scrambler + real **8b/10b**, ordered-set framing, full **LTSSM** (Detect→Polling→Config→L0, Recovery/HotReset), **DLL** with 12-bit seq / LCRC-32 / replay buffer / ACK-NAK, and a **TL** with MWr/MRd/CplD/config-space/MSI. Validated by cross-wiring a **Root Complex + Endpoint** over an internal PIPE loopback (`LOOP_INT`) and driving real TLPs from the RV32. | **SILICON PASS** — link trains to **L0**, MWr/MRd/CplD signature bit-identical sim↔silicon, WNS +0.683 ns |
| **[NPU](IP_Cores/NPU/)** | **INT8 CNN inference accelerator**: a full LeNet-style network (two convolution layers, two pooling layers, one fully connected) on an **8x8 weight-stationary systolic array** of 64 INT8 MACs. The accelerator owns its **DMA engine** and pulls weights and the input image from DDR by itself; the RV32 only kicks it off and reads back the classification. Bit-exact to a Python oracle across five layers (MAC → mesh → tiled inference → AXI integration → silicon), all producing one shared signature. The neural-inference plane of the family. | **SILICON PASS** — `SIG_CLASE=0x6084FD2A` bit-identical sim↔silicon, 0.333 ms/inference, 50 884 LUTs, 51 DSP58, 1 BRAM, WNS +0.515 ns / WHS +0.017 ns |
| **[PQC](IP_Cores/PQC/)** | **Post-quantum crypto engine**: **ML-KEM-768** (FIPS 203) + **ML-DSA-65** (FIPS 204), the CNSA 2.0 mandatory pair, fused over a single shared **Keccak-f[1600]** sponge. Full NTT / samplers / byte codecs for both lattice schemes; all six operations (KEM KeyGen/Encaps/Decaps, DSA KeyGen/Sign/Verify) run in hardware. An RV32 firmware drives the engine as a peripheral, folds every output with a 64-bit signature and DMAs the result to DDR. The security plane of the family. | **SILICON PASS** — `KEM=95E07091FA5B3CC4`, `DSA=F93232F7EA2D1575` bit-identical sim↔silicon, 34 RAMB36 + 76 DSP58, WNS +3.303 ns |
| **[MIPI](IP_Cores/MIPI/)** | **MIPI CSI-2 RX** (4-lane RAW12 receiver): CSI-2 packet layer with **Hamming ECC** (correct 1 / detect 2-bit) on packet headers, Short/Long packets and **CRC-16** payload validation, real **dual virtual-channel** demux into two BRAM framebuffers, and RAW12 de-packing. A PL-side synthetic **frame generator** (VC0 gradient + VC1 bars) drives the whole pipeline **PHY-less and camera-less** on silicon; the D-PHY is modeled at byte-clock level. Two AXI masters to DDR (family DMA + the MIPI's own) through the NoC, governed by the RV32. The imaging-input plane of the family. | **SILICON PASS** — signature `0xE6898DC5` bit-identical sim↔silicon, WNS +16.76 ns |
| **[PCS_25G](IP_Cores/PCS_25G/)** | **64B/66B PCS @ 25G**: complete transmit and receive datapath — self-synchronous scrambler (x^58+x^39+1), 64->66 gearbox with its 32/33 framing period, **block synchronisation** at the IEEE 802.3 clause 49 threshold of 64, de-gearbox and descrambler — exercised by a word-parallel **PRBS31** generator and checker with automatic re-lock. A **parallel fabric loopback** closes the link with no GTYP and no external hardware, and single-bit error injection proves detection: one flipped bit becomes exactly **9** errored bits through the self-synchronous descrambler, a number predicted by the Python oracle and reproduced identically in simulation and on silicon. The RV32 acts as a pure control plane over an MMIO bridge. The high-speed serial plane of the family. | **SILICON PASS** — **BER = 0** over 1,823,313 words (116 Mbit), injection -> 9 bits, WNS 0.000 / WHS 0.000 ns @ **390.625 MHz** (25G block rate), clean CDC |
| **[MAC_25G](IP_Cores/MAC_25G/)** | **25G Ethernet MAC with IEEE 802.3 clause-49 64B/66B encoding**, on top of the Core 19 PCS: padding, **CRC-32 FCS**, `/S/` `/D/` `/T0..T7/` `/I/` `/E/` block encoding with IPG >= 12 for every frame length; on RX block decoding, FCS residue check, runt/oversize/abort detection, MAC filtering and FCS stripping to AXI-Stream. A frame generator and a byte-exact frame checker close the loop through the PCS in parallel fabric loopback. Adds a **line-rate PCS TX** (predictive registered ready) after finding that the Core 19 PCS TX accepts 31 blocks per 33 cycles; output stream bit-identical to Core 19. 97 % of block slots carry frame bytes (99.6 % of the 802.3 ideal). | **SILICON PASS** — 100 000 frames through MAC + 64B/66B PCS at 390.625 MHz, signature `0x446C2628` as predicted, injected FCS error caught once, **24.26 Gb/s** L2+FCS; WNS +0.019 ns; 27/27 mutations detected |
| **[MAC_10G](IP_Cores/MAC_10G/)** | **10G Ethernet over a real GTYP transceiver (25G-capable)**: the Core 20 MAC and 64B/66B PCS on lane 0 of the TE0950 zQSFP (`GTYP_QUAD_X0Y1`, 64B66B_ASYNC gearbox in the GT), with an IEEE 802.3 cl.49 **block lock** driving `rxgearboxslip`, an **IPv4/UDP generator** (hardware IPv4 checksum, length sweep, rate control) whose frames a normal Linux PC receives with a plain UDP socket, a byte-exact checker, a GT reset sequencer with independent TX/RX tracks, user-clock frequency meters, and Local/Remote-Fault counters. The GT bit order is a run-time register (`eth21 autodetect`); on silicon the IEEE default was right. | **SILICON PASS @ 10.3125 Gb/s to a Linux PC** (ConnectX-3 Pro, QSFP+ DAC) — 48 913 739 UDP frames in 60 s at line rate, **all received**, 0 bad; **9.96 Gb/s** on the wire (809.6 kpps, 99.6 % of 10G); 0 CRC errors over 1.2·10¹² bits; GT bit order confirmed (default); also PASS in GTYP PMA loopback; WNS +1.903 ns; 38 GHDL runs vs an independent IEEE 802.3 oracle, 21/21 mutations |
| **[ECC_Scrubber](IP_Cores/ECC_Scrubber/)** | **ECC memory scrubber** (SECDED 39,32): a background agent that corrects single-event upsets in DDR before they accumulate into uncorrectable double-bit errors. A **Hamming (39,32)** code — 32 data + 6 parity + 1 overall — protects each 64-bit DDR word (correct 1 / detect 2-bit). An RV32 runs the scrub loop: **DMA a tile DDR->local, decode every word through an MMIO SECDED codec accelerator, correct correctable errors and count CE/DED, DMA the tile back**. The PS-side selftest runs a **protected vs unprotected** campaign over a real 16 MB reserved DDR region and proves the contrast: the scrubbed region and the untouched region hash to different signatures, both predicted bit-for-bit by the Python oracle. The SECDED codec is proven identical across Python, VHDL **and** C. The reliability plane of the family. | **SILICON PASS** — run A `0xbebc26d1` (scrub ON) != run B `0xc91192e2` (scrub OFF), bit-identical sim<->silicon, WNS +16.85 ns |

## Version history

### v2.0 — audit-2026-11 (November 2026)

Every core was re-read line by line against its standard, with two goals: no
silent failure anywhere, and RTL that is ready for an ASIC as well as an FPGA.
The rule for each fix: **a new test that fails on the old RTL and passes on
the new one**, plus a mutation run so the test can catch the bug. All
existing regressions still pass, and their signatures are unchanged unless
the change is intentional and documented.

**Changes across the whole family**

- **Sticky status bits are write-1-to-clear (W1C), per bit.** Before, any
  write to a status register cleared every flag, so one driver could erase
  an error that another had not read yet.
- **ASIC readiness.** The datapaths now use synchronous active-high resets.
  FIFOs and working memories have registered (synchronous) read ports, so
  they map to SRAM macros. CDC toggles get a power-on reset.
- **No shared `byte_fifo`.** Each core has its own FIFO entity. Before,
  three copies with the same name but different reset semantics collided
  in a multi-core build.
- **Bus hygiene.** AXI `WSTRB` is honoured, `SLVERR` is returned on
  unmapped addresses, `RRESP`/`BRESP`/`RLAST` are checked, counters
  saturate instead of wrapping, and every wait state has a timeout.
- **RV32IMA removed.** RV64IMAC is the only production CPU of the family.

**Per core** (details, file:line references and residual risks are in
each `IP_Cores/<CORE>/AUDIT_FIXES.md`)

| Core | Main improvements in v2.0 |
|---|---|
| **RV32i** | Precise misaligned load/store exceptions (`mcause` 4/6 + `mtval`); full illegal-instruction decode, where unknown opcodes used to run as NOP; AXI errors raise access faults; `SYNC_READ` memories for ASIC; CSR set/clear keyed on `rs1`; `mtval` written on every trap; fewer spurious load-use stalls. |
| **RV64IMAC** | AXI write IDs use the same scheme as read IDs; UART divisor 0 is safe; new UART testbench. Full lockstep regression: random memory latency, caches + AXI, SoC boot from ROM, and 31/31 mutations killed. |
| **SPW** | **400 Mbit/s capable**: new data-strobe recovered-clock receiver (`D xor S`, DDR capture, Gray async FIFO) and transmitter in its own clock domain. Detection of simultaneous D/S transitions; ECSS time-code validity (+1 mod 64); stale tick refused outside Run; W1C; synchronous FIFOs. |
| **PTP** | External-PHY MII with real CDC; AXI-Lite concurrent read/write corruption fixed, `WSTRB` honoured; a timeout on every wait state; `allowedLostResponses` / `asCapable`; `correctionField` in the offset; Pdelay_Resp matched on sequence and port identity; private sync-read FIFO; `NOW_SECHI` register. |
| **ADCS** | **Synthesizable FP32 FMA in RTL**, bit-exact and with no Xilinx FPO dependency, so the core is ASIC-ready. DMA checks `RRESP`/`BRESP` and has a timeout; guards on `maxiter`/`n_dim` = 0; CPU stores no longer dropped during DMA; burst-length fix. |
| **DSP** | FFT twiddle-product wrap fixed in the complex and real FFT; oracle aligned with per-stage saturation; MMIO range checks with `status_err`; FIR bounds; single-read-port memories. |
| **RF** | Rounding instead of truncation in CIC/FIR, which removes a −0.5 LSB DC bias; new Python model and golden; sync-read FIFO with overflow flag; MMIO/DMA pop arbitration. The signature changes on purpose. |
| **ADC** | External modulator in its own clock domain (`pdm_clk_i`, Gray CDC, overrun flag); MMIO/DMA arbitration; sticky FIFO overflow IRQ; new `run_adc_regress.sh` that tests the repo files themselves. |
| **CAN** | Missing stuff bit at the CRC/delimiter boundary fixed; hard sync on SOF in intermission; fault-confinement rules; private registered-read FIFO; keyed SELFACK; transmit rejected in bus-off; BTR locked while enabled; W1C. |
| **M1553** | **Dual redundant A/B bus** (per-message bus on the BC, two receivers on the RT); real **Busy / SSF / TF** status flags; no blind response; independent fail-safe transmitter timer; illegal-broadcast handling; TX underflow handling; RX-FIFO write queue; W1C; synchronous reset. |
| **ETH** | External-PHY MII CDC; maximum frame length enforced; RX overflow rewinds the whole frame instead of storing a partial one; sync-read FIFO; new status bits and `LEVEL` register; `TX_FLUSH` fix; W1C. |
| **TSN** | Per-port MII CDC for external PHYs; SFD outputs for PTP timestamping; 1522-byte 802.1Q maximum; `WSTRB`; new W1C `ERR_STICKY` register; injector length checks. |
| **USART** | Private FIFO; sticky RX abort; 32-bit DMA addresses; `RLAST` check; full datapath reset; selectable RS-485 DE polarity; watermark clamp; PIO/DMA collision flag; W1C. |
| **SPI** | Private FIFO; CS held for the whole DMA transfer, with a sticky underrun flag; DMA abort; 32-bit offsets; AXI error reporting; datapath reset; W1C. |
| **IIC** | Private FIFO; clock-stretch and stuck-bus timeouts, plus tBUF after a foreign STOP; read data gated by select; watermark clamp; W1C. |
| **I3C** | Private FIFO; spike filter on IBI START detection; turnaround after every target-driven bit; explicit command handshake so commands can no longer vanish; W1C. SDR only (documented). |
| **PCIe** | Transaction layer now fed **after** the LCRC and sequence checks; real NAK, replay timer and ACK/NAK DLLPs; replay buffer wrap and free-slot check; completion timeout, UR for MRd outside BAR0, `Length` honoured; MSI no longer corrupts the RX FSM; RX backpressure; Recovery reachable from L0; no idle inserted inside an open TLP. |
| **NPU** | DMA error flags reset and cleared per transfer; **1R1W synchronous-read SRAMs** (ASIC); `SLVERR` per beat and on `AWSIZE`; resets added; requantisation shift overflow fixed; zero-byte DMA safe. |
| **PQC** | Polynomial memories split into SRAM-mappable banks (no 3R1W); the Decaps reject/accept oracle on STATUS removed; **key zeroization** (`G_ZEROIZE`) for the flight variant; `op`/`alg` latched; host access blocked during an operation; Keccak sponge error flags; constant-time norm checks. Side-channel and fault-injection limits are listed honestly in `AUDIT_FIXES.md`. |
| **MIPI** | Duplicated AXI AW/W beats fixed; packet parser at full rate (1 byte/cycle) with no silent drop; real 4-lane deskew and PHY port; ECC abort and framebuffer-overrun handling; `FBDATA` and RAW12 byte-drop fixes. |
| **PCS_25G** | 64B/66B sync header in IEEE order on the wire; **real clause-49 block lock** with a windowed `hi_ber` (125 µs); register writes latched correctly; `WSTRB` and `SLVERR`; CDC with power-on reset and req/ack event sync; saturating counters; gearbox overflow flag. |
| **MAC_25G** | IEEE sync-header order; AXI-Stream store-and-forward FIFO, so `tvalid` bubbles no longer cause underruns; **IEEE 802.3x PAUSE** RX/TX; `GEN_COUNT = 0` safe; `WSTRB`, `SLVERR`, `tkeep` errors; reliable command timeout; saturating counters. |
| **MAC_10G** | GT mapping updated to IEEE order; **802.3x PAUSE** with RX FIFO; `WSTRB` and `SLVERR`; a timed-out command is killed instead of executed later; CDC power-on reset; saturating counters. |
| **ECC_Scrubber** | A second scrub start is now served (the done state was a trap); CPU stores no longer dropped during DMA; `REGION_BASE` / `REGION_LEN` / `PERIOD` actually used for periodic scrubbing; DMA burst-length fix. |

**What is still open** (tracked per core): board re-validation of the v2.0
RTL; SPW at 400 Mbit/s verified only in zero-delay simulation (pad and skew
budgets are physical); MIL-STD-1553 bus-B pin assignment; PTP
`ptp_axil_master.vhd` to be restored; PQC side-channel evaluation before
flight use with long-term keys.

### v1.1 — `cpu_pipeline` forwarding-during-stall fix

A silent forwarding hazard was found in the shared RV32 soft core and fixed
across the family.

**Symptom.** The second of two consecutive `lw` instructions could be lost
when the first stalled the pipeline on a slow region (a multi-cycle MMIO
peripheral) **and** the base register was produced by the immediately
preceding instruction. During the stall the write-back in flight was squashed
to a bubble (`mem_wb <= MEMWB_NOP`), which killed its forwarding path, so the
second `lw` computed its address from a stale (zero) base. The access landed
outside the peripheral window and the destination register took residual data
— a plausible wrong value with no exception and no error flag.

**Root cause.** Not the memory handshake, as first suspected, but forwarding
during a stall: the two forwarding sources (`ex_mem`, `mem_wb`) could not cover
a producer that fell off the write-back stage while a dependent load was held.
It was isolated by sweeping the producer-to-load distance and tracing the full
bus address rather than the offset alone (fault window: zero instructions of
slack).

**Fix.** A persistent write-back history buffer (`wbh_*`) as a third forwarding
level, surviving stalls of any length. The change is additive — it does not
touch the stall or write-back logic and preserves the `dmem` bus contract.

**Verification.** A dedicated regression (`tb_lw_hazard_reg`, plus a
GAP-parametrised sweep `tb_lw_hazard`), no regression across the CPU
testbenches, Core 19 (PCS_25G) Layer 5 passing **with and without** the former
firmware mitigation, and **silicon** on the TE0950 (`L5 SILICON PASS`,
`IRQ_STATUS` read directly, timing still closed at 390.625 MHz, WNS/WHS 0.000).
The firmware mitigation (`PCS_RD` barrier) was removed and the Core 19 firmware
returned to a direct read (896 → 612 bytes). Full write-up:
[`IP_Cores/RV32i/BUG_cpu_pipeline_lw_hazard.md`](IP_Cores/RV32i/BUG_cpu_pipeline_lw_hazard.md).

### v1.0 — initial release

The 22 IP cores of the first release, each taken from RTL to **silicon pass** on the
TE0950 (AMD Versal), driven by the RV32 soft core.

## Getting started in five minutes

```bash
git clone https://github.com/AdrianGreenboy/VHDL.git
cd VHDL/IP_Cores/PTP/sim      # or any other core
sudo apt install ghdl python3 # Ubuntu 24.04
./run_regression.sh           # watch the layers pass
```

No board needed to explore: every core's full verification runs in GHDL on
your machine. When you're ready for hardware, each README documents the exact
Vivado + PetaLinux + SD-card flow that produced the silicon PASS, checkpoints
and timestamp-locks included.

## Contributing

Found a bug? Ported a core to another FPGA family? Wrote a driver, fixed a
typo, or hit a synthesis trap worth documenting? **Open an issue or a PR.**
The only house rules:

- Keep the regression green (`run_regression.sh` / `run_*.sh` must pass).
- New RTL comes with its testbench — that's the family tradition.
- Lessons learned go in the README's "Problems faced" section, honestly told.

## License

All cores in this repository are released under the **MIT License** — free to
use, copy, modify, merge, publish, distribute, sublicense and sell, for any
purpose. See each core's README (or the `LICENSE` file) for the full text.

If you build something with these cores, I'd love to hear about it. Happy
hacking! 🔧

<!-- CPU-V11-PROP -->
## Silicon status after cpu_pipeline v1.1 propagation (Aug 2026)

All short-cycle cores re-synthesized with the shared RV32 pipeline v1.1
(forwarding-during-stall fix) and re-validated on the TE0950 (xcve2302).
Nothing below replaces earlier per-core validation records; this table
reflects the v1.1 re-validation pass.

| Core  | WNS (ns) | Silicon result | Validation level |
|-------|----------|----------------|------------------|
| SPI   | +2.128   | PASS           | Functional (PIO + 32 B DMA echo) |
| ADCS  | +2.844   | PASS           | Functional (FNV-1a signature 0x0C4CCCD2 exact) |
| USART | +2.430   | PASS           | Functional (PIO {2,0x5A,0xC3} + 32 B DMA echo @115200) - BD regenerated |
| IIC   | +2.432   | Boot OK        | Boot + RV32 executing firmware - BD regenerated (board-first, wrapper FREQ_HZ fix); own bring-up pending |
| I3C   | +3.005   | Boot OK        | Boot + RV32 executing firmware - BD regenerated (board-first, wrapper FREQ_HZ fix); own bring-up pending |
| CAN   | +0.603   | Boot OK        | Boot + RV32 executing firmware; own bring-up pending (cross bring-up from clone lineage) |
| RF    | +0.146   | Boot OK        | Boot-level (tightest margin of the family; no bring-up recipe yet) |
| SPW   | +2.740   | Boot OK        | Boot-level; own bring-up pending |
| M1553 | +3.110   | Boot OK        | Boot-level; own bring-up pending |
| ETH   | +3.133   | Boot OK        | Boot-level; own bring-up pending |
| DSP   | +0.867   | Boot OK        | Boot-level (no bring-up recipe yet) |

Long-cycle cores (ADC, PTP, TSN, MIPI, PCS, PQC, ECC): v1.1
re-validation deferred to the next campaign. See `rv32i/README.md` for the
bug description, the fix and the family-wide lessons learned.
