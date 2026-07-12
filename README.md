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
└── README.md       full documentation: registers, usage, verification,
                    silicon flow, problems faced, roadmap
```

## The cores

> Each core has its own README with the full story — register maps, software
> examples, the complete build flow from zero, and the honest log of problems.
> Start there.

| Core | What it is | Status |
|---|---|---|
| **[RV32i](IP_Cores/RV32i/)** | A complete **RV32IM SoC**: 5-stage pipelined RISC-V CPU (hardware multiply/divide, CSRs, CLINT), local RAM, burst **DMA engine** with AXI4 master to DDR, MMIO bus for peripherals, plus its own Python assembler (`asm.py`) and ISS used as the golden oracle by every other core. This is the heart that drives all the bring-ups. | **SILICON PASS** (TE0950) |
| **[SPW](IP_Cores/SPW/)** | **SpaceWire** link controller (ECSS-E-ST-50-12C): Data-Strobe codec, full ECSS link FSM, credit-based flow control, Time-Codes, 9-bit N-Char FIFOs, internal loopback self-test. The spacecraft onboard network, memory-mapped for an RV32. | **SILICON PASS** — 10/20/25/50 Mbit/s, WNS +2.740 ns |
| **[PTP](IP_Cores/PTP/)** | **PTP / IEEE 802.1AS** (gPTP) time-sync endpoint: 80-bit PTP clock with PI servo, hardware SFD timestamping, peer-delay measurement in hardware, master/slave Sync loop, and its **own MII Ethernet MAC** with 1-step timestamp override. The time plane of TSN. | **SILICON PASS** — mpd 40 ns, offset 0, WNS +1.171 ns |
| **[CAN](IP_Cores/CAN/)** | **CAN 2.0** controller: bit timing, stuffing, CRC, arbitration, error handling, TX/RX buffers over the family MMIO bus. | Silicon-validated on TE0950 |
| **[M1553](IP_Cores/M1553/)** | **MIL-STD-1553B** bus terminal: Manchester II encoding/decoding, command/status word handling, the classic avionics bus. | See its README for current status |
| **[USART](IP_Cores/USART/)** | **USART/UART** with the family MMIO interface — also the reference "hello world" of the SoC bring-up flow. | Silicon-validated on TE0950 |
| **[SPI](IP_Cores/SPI/)** | **SPI master** controller, memory-mapped. | See its README |
| **[I2C](IP_Cores/I2C/)** | **I2C master** controller, memory-mapped. | See its README |
| **[I3C](IP_Cores/I3C/)** | **I3C** controller — the modern successor to I2C. | See its README |
| **[PQC](IP_Cores/PQC/)** | Post-quantum cryptography experiments: **Kyber + Keccak** as a single-file AXI4-Lite IP, and integration work around **Dilithium**. | Research / in progress |

*(If a folder above doesn't exist yet or carries a different name, trust the
folder tree — this table is the map, the repo is the territory.)*

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
