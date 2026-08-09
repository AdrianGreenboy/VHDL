# HERCOSSNUX Core 20 — ECC Scrubber (SECDED 39,32)

A silicon-validated, MIT-licensed VHDL-2008 memory-scrubbing IP core that detects
and corrects single-event upsets (SEUs) in DDR memory using a SECDED (39,32)
Hamming code. Part of the HERCOSSNUX family of open, tutorial-quality reference
designs for the AMD Versal `xcve2302-sfva784-1LP-e-S` on the Trenz TE0950.

**Status:** all five verification layers pass, including on-silicon validation on
the TE0950. Synthesis WNS +19.09 ns, implementation WNS +16.85 ns.

---

## Table of contents

1. [What this is](#1-what-this-is)
2. [The SECDED (39,32) code](#2-the-secded-3932-code)
3. [Architecture](#3-architecture)
4. [Register map](#4-register-map)
5. [The five-layer verification methodology](#5-the-five-layer-verification-methodology)
6. [Reference signatures](#6-reference-signatures)
7. [Mutation testing](#7-mutation-testing)
8. [Repository layout](#8-repository-layout)
9. [Simulation flow (GHDL)](#9-simulation-flow-ghdl)
10. [Silicon build flow (Vivado + PetaLinux)](#10-silicon-build-flow-vivado--petalinux)
11. [Running the silicon selftest](#11-running-the-silicon-selftest)
12. [Bug log](#12-bug-log)
13. [Lessons learned](#13-lessons-learned)
14. [What was verified where](#14-what-was-verified-where)
15. [License](#15-license)

---

## 1. What this is

Radiation-induced single-event upsets flip bits in memory. Left unattended, these
errors accumulate until a single word holds more corruption than any code can
recover. **Scrubbing** is the countermeasure: a background agent periodically reads
each protected word, corrects any correctable error, and writes the clean word
back — before a second upset can turn a recoverable single-bit error into an
unrecoverable double-bit error.

This core implements a scrubber for a region living in DDR memory. A soft RV32IMA
SoC drives the scrub loop: it DMAs a tile of the region from DDR into local RAM,
runs each 64-bit word through a hardware SECDED codec exposed over MMIO, and DMAs
the corrected tile back to DDR. Correctable (single-bit) errors are fixed and
counted; detectable-but-uncorrectable (double-bit) errors are counted and flagged.

The design is deliberately small and readable: it is a reference design meant to
be studied, not a black box. Every layer is checked bit-for-bit against a Python
oracle, and the same code is proven identical across three independent
implementations (Python, VHDL, C).

---

## 2. The SECDED (39,32) code

The code protects 32 data bits with 7 parity bits, packed into a 64-bit DDR word:

- **32** data bits
- **6** Hamming parity bits at positions {1, 2, 4, 8, 16, 32} (1-indexed)
- **1** overall parity bit (bit 39)

Total: **39 significant bits**, stored in the low 39 bits of a 64-bit DDR word
(LO = bits [31:0], HI = bits [38:32]); the upper 25 bits are unused.

**Guarantees:**

- Single-bit error → **corrected** (SEC). The syndrome points at the flipped bit.
- Double-bit error → **detected but not corrected** (DED). The overall parity bit
  distinguishes an even number of flips (syndrome non-zero, overall parity OK →
  DED) from an odd number (single-bit → correct).

The decoder returns a status word: syndrome in bits [6:0], `was_ded` in bit 8,
`was_corrected` (CE) in bit 9. This flag convention is unified across every module
in the core — codec, FSM, register bank, and firmware all agree.

Encoding, decoding, injection, and the FNV-1a-32 signature are defined once in the
Python oracle (`ecc_oracle.py`) and mirrored bit-exactly in VHDL (`ecc_codec.vhd`)
and in C (`ecc_selftest.c`).

---

## 3. Architecture

See `architecture.svg` for the block diagram. The silicon SoC (`ecc_soc_si.vhd`)
is built on the family's `soc_top_master` pattern and comprises:

- **RV32IMA pipeline** (`cpu_pipeline.vhd`, v1.1) — 5-stage in-order core with the
  write-back-history forwarding fix.
- **Memory subsystem with DMA** (`mem_subsys_dma.vhd`) — local RAM plus a burst DMA
  engine (`dma_burst.vhd`) mastering AXI4 to DDR through the NoC.
- **AXI-Lite slave** (`axil_soc.vhd`) — PS-side control: halt/release, IMEM
  loading, and the `ddr_base` programming registers.
- **Scrubber register bank** (`ecc_regbank_si.vhd`) — the SECDED codec accelerator
  (`ecc_codec_mmio.vhd`), the scrubbing FSM (`scrub_fsm.vhd` over `scrub_bram.vhd`),
  a data window, and the tile CE/DED counters.

Address routing on the RV32 data bus:

| Region | Selector | Target |
|---|---|---|
| Local RAM | `addr[31:30] = "00"` | firmware buffer + tile staging |
| DMA registers | `addr = 0x4000_0000` | DMA SRC/DST/LEN/CTRL/STATUS |
| Scrubber MMIO | `addr[31] = '1'` (0x8000_0000) | codec, scrubber FSM, data window, counters |

The AXI4 master (`m_axi`) routes through NoC slave port `S06_AXI` to the DDR
controller (`C3_DDR_LOW0/LOW1`). The AXI-Lite slave is mapped at PS physical
address `0xA400_0000` (64 KB). The scrubbed region occupies a reserved 16 MB DDR
buffer at `0x7000_0000`, declared `no-map` in the device tree.

---

## 4. Register map

Scrubber MMIO, relative to the RV32 base `0x8000_0000` (silicon layout):

| Offset | Name | Access | Description |
|---|---|---|---|
| 0x00 | ID | RO | Core ID `0x5C520020` |
| 0x04 | ENC_IN | WO | Codec: 32-bit data to encode |
| 0x08 | ENC_OUT_LO | RO | Codec: encoded word, bits [31:0] |
| 0x0C | ENC_OUT_HI | RO | Codec: encoded word, bits [38:32] |
| 0x10 | DEC_IN_LO | WO | Codec: word to decode, bits [31:0] |
| 0x14 | DEC_IN_HI | WO | Codec: word to decode, bits [38:32] (triggers decode) |
| 0x18 | DEC_DATA | RO | Codec: corrected 32-bit data |
| 0x1C | DEC_STATUS | RO | Codec: syndrome [6:0], ded bit 8, corrected bit 9 |
| 0x48 | CONTROL | WO | bit0 = start scrub; bit2 = clear counters |
| 0x58 | CE_COUNT | RO | Correctable errors (FSM + tiles) |
| 0x5C | DED_COUNT | RO | Detected double-bit errors (FSM + tiles) |
| 0x84 | CE_BUMP | WO | Auto-increment CE counter (firmware tiles) |
| 0x88 | DED_BUMP | WO | Auto-increment DED counter (firmware tiles) |
| 0x1000+ | DATA_WINDOW | RW | Data window into the scrub BRAM |

AXI-Lite slave (PS physical `0xA400_0000`):

| Offset | Name | Description |
|---|---|---|
| 0x0000 | CONTROL | bit0 = 1 holds the core in reset (halt) |
| 0x0004 | STATUS | bit0 = core running |
| 0x0010 | DDR_BASE_LO | DDR buffer physical base, bits [31:0] |
| 0x0014 | DDR_BASE_HI | DDR buffer physical base, bits [39:32] |
| 0x1000+ | IMEM window | instruction load window (word i → +i*4) |

The MMIO register map is frozen. Core ID `0x5C520020`, AXI-Lite window at
`0xA4000000/64K`.

---

## 5. The five-layer verification methodology

The non-negotiable family rule: **nothing is delivered without validation**. Each
layer is checked against a Python oracle written before the RTL, and each layer's
sole PASS criterion is a **bit-identical FNV-1a-32 signature** match.

- **Layer 1 — codec/unit.** The SECDED encoder/decoder against 1504 exhaustive and
  edge vectors. Files: `ecc_pkg.vhd`, `ecc_codec.vhd`, `tb_layer1.vhd`,
  `ecc_oracle.py`, `gen_layer1_vectors.py`.
- **Layer 2 — scrubbing FSM.** The read-correct-write scrub loop over a BRAM, with
  injected CE/DED errors. Files: `scrub_bram.vhd`, `scrub_fsm.vhd`, `tb_layer2.vhd`,
  `scrub_oracle.py`, `gen_layer2_vectors.py`.
- **Layer 3 — register bank + injector.** The MMIO contract: register reads/writes,
  the two-mode error injector, and sticky status. Files: `ecc_regbank.vhd`,
  `tb_layer3.vhd`, `mmio_oracle.py`, `gen_layer3_trace.py`.
- **Layer 4 — full SoC + firmware in lockstep.** The RV32 SoC running real firmware
  against a Python ISS, protected (scrub ON) versus unprotected (scrub OFF). Files:
  `ecc_soc_top.vhd`, `ecc_fw.s`, `tb_layer4.vhd`, `fw_oracle.py`, `gen_layer4.py`.
- **Layer 5 — silicon.** The master SoC (`ecc_soc_si.vhd`) synthesized,
  implemented, and run on the TE0950. The PS-side selftest (`ecc_selftest.c`)
  drives a protected/unprotected campaign over a real DDR region and verifies the
  signature contrast. Files: `ecc_soc_si.vhd`, `ecc_codec_mmio.vhd`,
  `ecc_regbank_si.vhd`, `soc_top_ecc_wrap.v`, `ecc_fw_tiles.s`, `ecc_selftest.c`,
  `tiles_oracle.py`.

For Layer 4 the Python oracle is written before RTL integration; the RTL must match
it bit-for-bit. For Layer 5 the SECDED codec is proven identical across Python
(`ecc_oracle.py`), VHDL (`ecc_codec.vhd`), and C (`ecc_selftest.c`) by direct diff.

---

## 6. Reference signatures

Every layer's PASS is a bit-identical FNV-1a-32 match against the oracle.

| Layer | Scenario | Signature |
|---|---|---|
| L1 codec | 1504 encode/decode vectors | `0x165aeb0d` |
| L2 scrub | sweep N=64 (CE=21, DED=8) | `0xccfdb060` |
| L3 MMIO | register-read trace | `0x36525268` |
| L4 run A | SoC + firmware, scrub ON | `0xdb5e11bb` |
| L4 run B | SoC + firmware, scrub OFF | `0x0f37257a` |
| L5 tiles A | tiles N=300, scrub ON (CE=40, DED=12) | `0x9986c2e9` |
| L5 tiles B | tiles N=300, scrub OFF | `0xa44f7975` |
| **L5 silicon A** | **TE0950, N=1024, scrub ON** | **`0xbebc26d1`** |
| **L5 silicon B** | **TE0950, N=1024, scrub OFF** | **`0xc91192e2`** |
| L5 clean ref | N=1024 uncorrupted region | `0x0fc503c5` |

The on-silicon signatures `0xbebc26d1` (A) and `0xc91192e2` (B) match the Python
oracle prediction exactly — the hardware reproduces the model bit-for-bit.

---

## 7. Mutation testing

Each layer requires 4–5 deliberate mutations that must break the test — a passing
suite that no mutation can break is not a test, it is a decoration. Representative
mutations:

- **L1:** flip a Hamming parity position; drop the overall parity bit; swap
  syndrome bit order; force `was_corrected` high; mask the data output.
- **L2:** skip the write-back phase; corrupt the address counter; force the codec
  bypass; freeze the CE counter.
- **L3:** force `ready` always high; drop the injector's second mode; break the
  sticky bit; misdecode the register offset.
- **L4 (M2):** force `dmem_ready` constant high — this catches the data-window
  hazard where two consecutive slow reads returned stale data.
- **L5:** hold `ddr_base` at zero; skip the DMA write-back; force `cfg` to a
  constant; break the CE/DED bump decode.

---

## 8. Repository layout

Canonical IP path: `IP_Cores/ECC_Scrubber/`.

```
ECC_Scrubber/
  ecc_pkg.vhd              SECDED constants and types
  ecc_codec.vhd           combinational SECDED encoder/decoder
  ecc_codec_mmio.vhd      codec exposed as an MMIO accelerator
  scrub_bram.vhd          scrub BRAM (synthesizable init guard)
  scrub_fsm.vhd           read-correct-write scrubbing FSM
  ecc_regbank.vhd         Layer 3 register bank + injector
  ecc_regbank_si.vhd      silicon register bank (codec + FSM + window + counters)
  ecc_soc_top.vhd         Layer 4 SoC (lockstep verification)
  ecc_soc_si.vhd          silicon master SoC
  rtl/soc_top_ecc_wrap.v  Verilog module-reference wrapper for the BD
  ecc_oracle.py           reference codec + FNV signature (Python)
  scrub_oracle.py         Layer 2 oracle
  mmio_oracle.py          Layer 3 oracle
  fw_oracle.py            Layer 4 firmware ISS oracle
  tiles_oracle.py         Layer 5 tile-sweep oracle
  ecc_fw.s               Layer 4 firmware
  ecc_fw_tiles.s         Layer 5 tile-sweep firmware (parametric)
  ecc_fw_on.s / off.s    Layer 5 fixed-parameter variants (scrub ON / OFF)
  ecc_selftest.c          PS-side aarch64 silicon selftest
  gen_fw_variants.py      generates on/off firmware variants
  gen_*.py                per-layer vector/trace generators
  tb_*.vhd                per-layer testbenches
  vivado/                 BD Tcl, synth/impl scripts, XSA
  petalinux_files/        device tree, selftest recipe
  README.md               this file
  architecture.svg        block diagram
```

Shared RV32 infrastructure lives at `~/rv32i/` (cpu_pipeline v1.1, asm.py, dp_ram,
dma_burst, axil_soc). **Note:** use the clean `mem_subsys_dma.vhd` shipped in this
core folder — the copy in `~/rv32i/` instantiates artifacts from other cores.

---

## 9. Simulation flow (GHDL)

GHDL 4.1.0, `--std=08`, mcode backend. Analyze everything in one command with a
clean cache to avoid stale-entity issues; assert messages are Spanish, ASCII-only.

Layer 1:

```
python3 gen_layer1_vectors.py
ghdl -a --std=08 ecc_pkg.vhd ecc_codec.vhd tb_layer1.vhd
ghdl -r --std=08 tb_layer1 --stop-time=3ms      # -> LAYER1 CODEC PASS
```

Layer 2:

```
python3 gen_layer2_vectors.py
ghdl -a --std=08 ecc_pkg.vhd ecc_codec.vhd scrub_bram.vhd scrub_fsm.vhd tb_layer2.vhd
ghdl -r --std=08 tb_layer2 --stop-time=50us      # -> LAYER2 SCRUB PASS
```

Layer 3:

```
python3 gen_layer3_trace.py
ghdl -a --std=08 ecc_pkg.vhd ecc_codec.vhd ecc_regbank.vhd tb_layer3.vhd
ghdl -r --std=08 tb_layer3 --stop-time=100us     # -> LAYER3 MMIO PASS
```

Layer 4 (needs the RV32 sources and `asm.py`):

```
python3 gen_layer4.py
python3 asm.py ecc_fw.s ecc_fw.mem
ghdl -a --std=08 <rv32 sources> ecc_*.vhd ecc_soc_top.vhd tb_layer4.vhd
ghdl -r --std=08 tb_layer4 --stop-time=2ms        # -> LAYER4 run A signature
ghdl -r --std=08 tb_layer4_b --stop-time=2ms      # -> LAYER4 run B signature
```

Layer 5 codec/scrubber units and the SoC smoke test:

```
ghdl -a --std=08 ecc_pkg.vhd ecc_codec.vhd ecc_codec_mmio.vhd tb_codec_mmio.vhd
ghdl -r --std=08 tb_codec_mmio --stop-time=3ms    # -> CODEC_MMIO PASS
python3 tiles_oracle.py                            # -> A/B contrast
```

---

## 10. Silicon build flow (Vivado + PetaLinux)

Vivado / PetaLinux 2025.2.1. The BD is regenerated from the previous core's BD by
Python surgery (rename-only), preserving the NoC→DDR wiring.

**Vivado (commands one at a time, reading each response):**

1. `bash vivado/gen_ecc_bd_tcl.sh` — surgery on the reference BD Tcl (pcs→ecc).
2. `create_project ecc_soc vivado/ecc_soc -part xcve2302-sfva784-1LP-e-S`
3. `set_property board_part trenz.biz:te0950_23_1lse:part0:1.2 [current_project]`
   — **before** sourcing the BD.
4. `add_files` the scrubber RTL + RV32 sources + the Verilog wrapper; mark VHDL
   sources as `{VHDL 2008}`.
5. `source vivado/ecc_soc_bd.tcl` — the module reference `soc_top_ecc_wrap`
   resolves against `ecc_soc_si`.
6. `validate_bd_design`, `generate_target all`, `make_wrapper -top`, set top.
7. `launch_runs synth_1` → `launch_runs impl_1 -to_step write_device_image`.
8. `write_hw_platform -fixed -include_bit -force vivado/ecc_soc.xsa`.

Never use `~` in Tcl — use `$env(HOME)`. Never paste bulk Tcl; run block-design
commands one at a time. Route the NoC master to DDR by explicit Tcl, never by
Connection Automation (which routes to `S_AXI_LPD`, zero DDR access).

**PetaLinux:**

1. Clone `project-spec/` + `.petalinux` only (never `build/`, ~22 GB).
2. `petalinux-config --get-hw-description=vivado/ecc_soc.xsa --silentconfig`.
3. Install `system-user.dtsi` (reserved DDR `0x70000000`, 16 MB, `no-map`).
4. Install the `ecc-selftest` recipe (compiles the C with `${CC}`, installs the
   binary plus `ecc_fw_on.mem` and `ecc_fw_off.mem` in `/usr/bin/`).
5. Register the app: `CONFIG_ecc-selftest` in `user-rootfsconfig`,
   `CONFIG_ecc-selftest=y` in `rootfs_config`.
6. `petalinux-build`.
7. `petalinux-package boot --u-boot --force` → `BOOT.BIN`.
8. Copy `BOOT.BIN` + `image.ub` to the SD BOOT (FAT) partition.

Never hot-load the PDI (the PLM rejects it with `0x03024001`); always repackage
BOOT.BIN. The TE0950 boots from the `image.ub` initramfs — binaries in `/usr/bin/`
run from RAM, not from the SD ext4, so updating a binary means rebuilding the
rootfs and recopying `image.ub`.

---

## 11. Running the silicon selftest

On the TE0950 serial console (picocom 115200 8N1):

```
ecc-selftest /usr/bin/ecc_fw_on.mem /usr/bin/ecc_fw_off.mem 1024
```

The selftest:

1. `mmap`s `/dev/mem` for the AXI-Lite window (`0xA4000000`) and the DDR buffer
   (`0x70000000`).
2. Programs `ddr_base` so the core's DMA targets the reserved buffer.
3. Run A (scrub ON): writes a corrupted ECC region to DDR word-by-word, loads
   `ecc_fw_on.mem`, releases the core, waits for the doorbell, signs the corrected
   DDR region.
4. Run B (scrub OFF): same corrupted region, `ecc_fw_off.mem` (no correction),
   signs.
5. Verdict: `sigA != sigB` → protection demonstrated → **L5 SILICON PASS**.

Expected output:

```
ddr_base programado: 0x70000000
[RUN A] scrub ON  ... firma post-scrub A : 0xbebc26d1
[RUN B] scrub OFF ... firma post-scrub B : 0xc91192e2
contraste A vs B: DISTINTAS (proteccion OK)
L5 SILICON PASS
```

DDR `no-map` access from the PS is always volatile, word-by-word: `memset`/`memcpy`
fault with SIGBUS on `no-map` memory, which is why the selftest uses word loops.

Parameters reach the firmware through two fixed-parameter builds (`ecc_fw_on.mem`,
`ecc_fw_off.mem`) rather than a runtime channel, because the silicon SoC does not
expose a DMEM window to the PS. Regenerate for a different region size with
`python3 gen_fw_variants.py <n_words>`.

---

## 12. Bug log

Four real bugs were found and fixed on the road to silicon. All are instructive.

- **`scrub_bram` not synthesizable.** `file_open` with an empty `INITFILE` failed
  synthesis (invalid file name, array-size mismatch). Fix: a guard
  `if INITFILE = "" then return m;` before the file open — in silicon the region
  lives in DDR, so the internal BRAM starts at zero and no file I/O is emitted.
  Transparent to simulation (L2/L3 still pass with a real INITFILE).

- **Two versions of `mem_subsys_dma.vhd`.** The copy in `~/rv32i/` instantiates
  `ptp_axil_master`, `dsp_mmio`, and `pcie_soc_mmio` from other cores; referencing
  it drags in half the repo. The clean version (dp_ram + dma_burst only, 176 lines)
  ships in this core folder and must be the one referenced in the BD.

- **PS→firmware parameter passing.** The silicon SoC exposes only IMEM and control
  over AXI-Lite, no DMEM window, so the PS cannot write the firmware's local RAM.
  Resolved by building two fixed-parameter firmwares (`ecc_fw_on.mem` with cfg=1,
  `ecc_fw_off.mem` with cfg=0); the PS loads whichever it needs per run.

- **`ddr_base` never programmed (first silicon run failed).** The DMA computes
  `ddr_addr = ddr_base + src`, and `ddr_base` resets to zero. The selftest did not
  program it, so the DMA read and wrote physical address 0 while the PS wrote and
  read `0x70000000` — the corrected data landed elsewhere and the PS saw the
  untouched corrupt region, giving identical A/B signatures. Fix: the selftest
  writes `DDR_BASE_LO=0x70000000` / `DDR_BASE_HI=0` to the AXI-Lite registers
  `0x10`/`0x14` after `mmap`. Software-only; no re-synthesis.

An earlier data-window hazard (two consecutive `lw` to slow memory returned stale
data) was caught during Layer 4 and fixed with an explicit window FSM; mutation M2
(forcing `dmem_ready` high) covers it.

---

## 13. Lessons learned

- **Large combinational trees must be pipelined** — but not always. The Hamming XOR
  trees here closed timing with +19 ns of slack at the SoC clock, so no pipelining
  was needed; profile before optimizing.
- **BRAM inference requires the canonical SDP mold** (one sync write port, one sync
  read port). File-based init breaks synthesis; guard it out for the silicon path.
- **NoC wiring for PL masters must be scripted Tcl** — Connection Automation routes
  to `S_AXI_LPD` and silently denies DDR access.
- **Never chain MMIO reads without barriers** on this pipeline — the
  forwarding-during-stall hazard returns stale data.
- **Verify the same algorithm in every language it appears in.** The SECDED codec
  is bit-identical in Python, VHDL, and C, proven by diff — this caught convention
  drift early and made the silicon signatures predictable.
- **A reserved `no-map` DDR buffer needs volatile word access from the PS;** bulk
  glibc ops fault.
- **The most expensive silicon bug was a missing register write** (`ddr_base`), not
  a logic error. The five-layer sim proved the RTL correct; the failure was in the
  PS orchestration, invisible until hardware. Program every base address the
  hardware depends on.

---

## 14. What was verified where

Honesty about the scope of each check:

**Verified in simulation (GHDL, bit-exact against oracle):**

- SECDED codec, 1504 vectors (L1).
- Scrubbing FSM sweep (L2).
- MMIO register bank + injector (L3).
- Full SoC + firmware lockstep, protected vs unprotected (L4).
- Codec MMIO accelerator, 1504 vectors over the bus (L5 unit).
- Silicon register bank scrubbing over MMIO (L5).
- Silicon SoC bring-up: boot, MMIO routing, doorbell (L5 smoke).
- Tile-sweep contrast in the oracle: CE=40, DED=12, A≠B (L5).

**Verified in silicon (TE0950 hardware):**

- Timing closure: synthesis WNS +19.09 ns, implementation WNS +16.85 ns.
- End-to-end scrub campaign over a real DDR region, N=1024.
- Protected/unprotected contrast: A `0xbebc26d1` ≠ B `0xc91192e2`, matching the
  oracle prediction exactly. **L5 SILICON PASS.**

**Cross-implementation consistency:**

- SECDED codec bit-identical across Python, VHDL, and C (diff-verified).
- FNV-1a-32 word-wise signature identical across the RV32 firmware, the Python
  oracle, and the C PS-side.

The full firmware tile loop was exercised end-to-end on silicon; in pure
simulation the DMA half of the loop requires a DDR/AXI4 model, so the codec loop
was validated to the doorbell in simulation and the complete DMA↔DDR path was
validated on hardware.

---

## 15. License

MIT. See `LICENSE` at the repository root.

Part of HERCOSSNUX, a family of silicon-validated open VHDL-2008 IP cores for the
Trenz TE0950 (AMD Versal `xcve2302-sfva784-1LP-e-S`).
