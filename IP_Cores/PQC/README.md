# PQC accelerator — ML-KEM-768 + ML-DSA-65 (Core 17)

A synthesizable **VHDL-2008 post-quantum cryptography engine** implementing the
two CNSA 2.0 primitives — **ML-KEM-768** (FIPS 203, key encapsulation) and
**ML-DSA-65** (FIPS 204, digital signatures) — over a single shared Keccak
sponge, packaged as an IP core for a custom RV32IM SoC on the Trenz **TE0950**
board (AMD Versal `xcve2302-sfva784-1LP-e-S`).

Both algorithms run all three of their operations (KEM: KeyGen / Encaps /
Decaps; DSA: KeyGen / Sign / Verify) entirely in hardware. An RV32 soft core
drives the engine as a memory-mapped peripheral, folds every output with a
64-bit signature, and DMAs the result to DDR where the PS verifies it — the same
peripheral+firmware pattern used by the other sixteen cores in this collection.

> **Silicon-validated on the TE0950**: both signatures match bit-for-bit,
> `KEM = 95E07091FA5B3CC4`, `DSA = F93232F7EA2D1575`, timing closed at
> **WNS +3.303 ns**. Verified across five simulation layers from unit sim to
> hardware, plus a Python KAT oracle.

![Architecture](docs/pqc_soc_arch.svg)

---

## Table of contents

1. [What is this and why would you use it](#1-what-is-this-and-why-would-you-use-it)
2. [Feature set](#2-feature-set)
3. [How it fits in the SoC](#3-how-it-fits-in-the-soc)
4. [Register map](#4-register-map)
5. [How to use it — software](#5-how-to-use-it--software)
6. [The shared Keccak sponge](#6-the-shared-keccak-sponge)
7. [The self-test signature (FNV-64)](#7-the-self-test-signature-fnv-64)
8. [Verification strategy](#8-verification-strategy)
9. [Build & run — simulation](#9-build--run--simulation)
10. [Build & run — Vivado](#10-build--run--vivado)
11. [Build & run — PetaLinux & SD card](#11-build--run--petalinux--sd-card)
12. [Silicon bring-up](#12-silicon-bring-up)
13. [Problems we hit and how we solved them](#13-problems-we-hit-and-how-we-solved-them)
14. [File layout](#14-file-layout)
15. [Roadmap](#15-roadmap)
16. [License](#16-license)

---

## 1. What is this and why would you use it

This core gives a soft RV32 CPU (or any AXI/MMIO master) **post-quantum key
establishment and digital signatures** in hardware, without a CPU-side crypto
library. You load a seed, pulse a command, and the engine runs the full
lattice-based algorithm — number-theoretic transforms, samplers, byte codecs and
the Keccak permutation — returning the public/private key, ciphertext, shared
secret or signature byte by byte through a small register window.

Typical uses:

- **Quantum-resistant secure boot / attestation** on an FPGA node, where the
  keys and signatures must be computed on-device.
- **Offloading** ML-KEM / ML-DSA from a soft CPU that would otherwise spend
  millions of cycles on polynomial arithmetic.
- **A reference / teaching PQC engine**: the whole datapath is flat VHDL-2008
  with a five-layer verification suite and a Python KAT oracle you can read and
  re-run against the FIPS 203/204 known-answer tests.

What it is **not**: it is not a general-purpose crypto accelerator (only
ML-KEM-768 and ML-DSA-65 parameter sets are built), it does not manage keys or
provide a TLS stack (it is the primitive engine only), and it is not
side-channel hardened in this release (see [roadmap](#15-roadmap)).

The two algorithms **share one Keccak-f[1600] sponge**. ML-KEM and ML-DSA both
lean heavily on SHA3/SHAKE; giving them a common permutation is the single
biggest area saving in the design, and — crucially — it is provably transparent:
the fused core reproduces the exact signatures the two standalone cores produced
(see §6).

## 2. Feature set

| Area | Core 17 |
|------|---------|
| KEM | **ML-KEM-768** (FIPS 203): KeyGen, Encaps, Decaps — full NTT, CBD sampler, ByteEncode/Decode, compression |
| DSA | **ML-DSA-65** (FIPS 204): KeyGen, Sign (rejection loop), Verify — NTT over q=8380417, hint packing, `w1` encoding |
| Suite | CNSA 2.0 mandatory pair; security category 3 |
| Hashing | one shared **Keccak-f[1600]** sponge (SHA3-256/512, SHAKE128/256) |
| Bus | MMIO peripheral at `0xD000_0000`, byte-window host port (`ADDR`/`DATA` auto-increment) |
| Driver | RV32 firmware loads seeds, pulses ops, folds outputs, DMAs signatures to DDR |
| Self-test | full 6-operation chain, **FNV-64 global signature**, bit-identical sim↔silicon |
| Delivery | signatures DMA'd to DDR `0x7000_0000`; PS reads and verifies |

Parameter sets are fixed at the CNSA 2.0 choices (ML-KEM-768, ML-DSA-65); other
NIST levels are not built in this release.

## 3. How it fits in the SoC

```
Versal PS (A72) ──M_AXI_FPD──► SmartConnect ──► axil_soc ──► RV32 core ──dmem──► mem_subsys_pqc
                     (0xA400_0000)                                                    │ decode addr[31:28]
                                          ┌──────────────────────────────────────────┤
                                          │ "1101" → pqc_mmio (0xD000_0000)           │ "0100" → dma_burst
                                          ▼                                           ▼
                                     pqc_core                                  AXI4 → NoC → LPDDR4
                              ┌──────────┴──────────┐                              (0x7000_0000)
                       kem_core_sx            dsa_core_sx
                       (ML-KEM-768)           (ML-DSA-65)
                              └──── shared keccak_sponge ────┘
```

- The engine is a slave on the RV32 `dmem` bus, decoded at **`0xD000_0000`**
  (`addr[31:28] = "1101"`).
- The RV32 firmware runs the self-test and moves the two 64-bit signatures to
  DDR through the SoC's `dma_burst` master.
- The PS controls the core and loads firmware over an AXI-Lite slave at
  **`0xA400_0000`** (a valid `M_AXI_FPD` aperture on Versal — `0x8000_0000` is
  not, see §13).

## 4. Register map

`pqc_mmio` base `0xD000_0000`, word offsets:

| Offset | Name   | Access | Fields |
|-------:|--------|--------|--------|
| `0x00` | CTRL   | RW  | b0 `ALG` (0 = KEM, 1 = DSA) |
| `0x04` | CMD    | W1P | b1:0 `OP` (00 KeyGen / 01 Encaps·Sign / 10 Decaps·Verify), b2 `START` |
| `0x08` | STATUS | R   | b0 `BUSY`, b1 `DONE`, b2 `KEM_REJ`, b3 `DSA_RESULT`, b6:4 `REASON`, b7 `DONE_STICKY` |
| `0x0C` | ADDR   | RW  | b13:0 byte-window address into the core (auto-increments on DATA access) |
| `0x10` | DATA   | RW  | b7:0 byte to/from the core's byte memory at `ADDR` |
| `0x14` | SIGLEN | RW  | b15:0 signature length for DSA Verify |

**Host-port semantics**: the core's byte memory is shared between the algorithm
datapath and the host window. Writing `ADDR` puts the peripheral into *host
mode* — it holds the core's host select asserted over the current address so the
byte is stable — and the first `DATA` read after setting `ADDR` **primes** (does
not advance) to absorb the two-cycle read latency. Pulsing `START` releases host
mode so the core owns its memory while it computes. Getting these three details
wrong is exactly what §13 documents.

## 5. How to use it — software

The engine is driven from RV32 firmware. The pattern for one operation is:
select the algorithm, load inputs through the byte window, pulse the op, poll
`DONE_STICKY`, then read the outputs back through the byte window.

### Run an ML-KEM-768 KeyGen (RV32 assembly, asm.py subset)

```asm
    lui  x1, 0xD0000          # base MMIO
    sw   x0, 0(x1)            # CTRL = 0 (KEM)
    # --- load d||z (64 bytes) through the byte window ---
    sw   x0, 12(x1)           # ADDR = 0
    li   x5, 0xE5
    sw   x5, 16(x1)           # DATA = first seed byte (ADDR auto-increments)
    # ... 63 more seed bytes ...
    # --- pulse KeyGen and wait ---
    addi x5, x0, 4
    sw   x5, 4(x1)            # CMD = START | OP(00)
wait:
    lw   x6, 8(x1)            # STATUS
    andi x6, x6, 128          # DONE_STICKY (b7)
    beq  x6, x0, wait
    # --- read ek back: set ADDR, prime with a dummy DATA read, then loop ---
    li   x5, 512
    sw   x5, 12(x1)           # ADDR = 512 (ek base)
    lw   x0, 16(x1)           # priming read (discarded)
    lw   x7, 16(x1)           # first ek byte
    # ... 1183 more bytes ...
```

### Byte-window map inside the core (per algorithm)

| Algorithm | Output | Address | Length |
|-----------|--------|--------:|-------:|
| ML-KEM | `ek` | 512  | 1184 |
| ML-KEM | `dk` | 2048 | 2400 |
| ML-KEM | `ct` | 2048 | 1088 |
| ML-KEM | `ss` / `Kout` | 32 / 1280 | 32 |
| ML-DSA | `pk` | 256  | 1952 |
| ML-DSA | `sk` | 2304 | 4032 |
| ML-DSA | `sig` | 8192 | 3309 |

The self-test firmware chains all six operations, moving intermediates inside
the core (park/restore of `dk`, relocation of `sk`/`pk`/`sig`) exactly as the
standalone core testbenches did.

## 6. The shared Keccak sponge

ML-KEM and ML-DSA are fused into one `pqc_core` around a single
`keccak_sponge` (SHA3-256, SHA3-512, SHAKE128, SHAKE256). Sharing a hash engine
between two lattice schemes is only safe if it is **transparent** — if it does
not perturb either algorithm's output.

The proof is by reproduction. Each standalone core (`kem_core_sx`,
`dsa_core_sx`) had a Layer-4 testbench that produced a fixed 64-bit signature
over its full operation chain. The fused core, running both chains back to back
over the one sponge with no reset in between, must reproduce **both** signatures
exactly:

```
KEM chain sig = 95e07091fa5b3cc4
DSA chain sig = f93232f7ea2d1575
```

A byte-map md5 confirmed the two trees are byte-identical across the fusion, and
a deliberate fusion mutation (M1) was killed by the signature check. Because the
two chains run in one simulation, the sponge really is reused between algorithms
rather than quietly reset in between.

## 7. The self-test signature (FNV-64)

The silicon self-test folds every output byte of all six operations into a
single 64-bit running signature and checks it against the value the RTL FSM
produced. The fold is an FNV-64 variant: for each byte `b`,
`s = (s XOR b) · p⁴ (mod 2⁶⁴)`, with `p⁴ = 0x9FFAAC085635BC91` (the FNV prime
`0x100000001b3` raised to the fourth power — the FSM applied the prime four
times per byte) and initial `s = 0xcbf29ce484222325`.

The 64×64→64 multiply is implemented in RV32 with `mul` + `mulhu`. The KEM chain
signature is `95E07091FA5B3CC4`; the DSA chain (which also folds the Verify
result byte) is `F93232F7EA2D1575`. A portable Python model
(`fw/selftest_ref.py`) reproduces both from the KAT vectors and is the golden
reference the firmware is checked against.

## 8. Verification strategy

Five layers, each **bit-exact** against an independent model, mutations that
**must** fail, and a Python KAT oracle written before RTL integration:

| Layer | What | Result |
|-------|------|--------|
| 1 | Keccak, NTT, samplers — each block vs an independent model | PASS + mutations |
| 2 | Byte codecs, rounding, base multiply | PASS + mutations |
| 3a | ML-KEM KeyGen / Encaps / Decaps vs Python oracle | PASS |
| 3b | ML-DSA KeyGen / Sign / Verify vs Python oracle | PASS |
| 4 | `pqc_core` fusion — both chains, one sponge, reproduce **both** signatures | PASS (`95e07091fa5b3cc4`, `f93232f7ea2d1575`) |
| 5 | Full SoC + RV32 firmware + real DMA; self-test signatures DMA'd to DDR | PASS in sim **and** silicon |

The Layer-4 pass criterion is reproducing the two standalone signatures over the
shared sponge (transparency proof). Layer 5 runs the full six-operation
self-test on the RV32, folds with FNV-64, and DMAs both signatures to DDR — the
same value in GHDL and on the TE0950.

## 9. Build & run — simulation

Requires GHDL 4.1.0 (`--std=08`, mcode backend). The self-test validation runs
the full SoC and reproduces both signatures:

```bash
cd ~/vhdl_repo/IP_Cores/PQC/soc
bash run_soc_validation.sh          # KEM KeyGen sanity: FNV of ek = 0x33C532BD
bash validate_selftest.sh           # KEM (~15 ms sim) then DSA (~45 ms sim)
# → KEM sig = 95E07091FA5B3CC4 ; DSA sig = F93232F7EA2D1575
```

The reference model needs no board:

```bash
python3 fw/selftest_ref.py          # KEM/DSA sigs from the KAT vectors, match=True
```

Firmware is regenerated from the vectors with `fw/gen_selftest.py` and assembled
with `~/rv32i/asm.py`. The full self-test is 972 instructions and needs the IMEM
at `DEPTH=1024`.

## 10. Build & run — Vivado

Vivado 2025.2.1. The block design was built from scratch by Tcl, **one command
at a time** in the console — on Versal a pasted block can fail silently.

```bash
source ~/Xilinx/2025.2.1/Vivado/settings64.sh
vivado &
```

The BD is CIPS (PS) + AXI NoC + `soc_top_pqc_wrap` as a module reference +
Processor System Reset + SmartConnect + a constant. The critical Versal rules
baked in:

- The PL AXI master goes to a **dedicated NoC slave** (`S06_AXI`) routed to the
  same memory controller the CIPS uses (`MC_3`) — Connection Automation routes
  PL masters to `S_AXI_LPD` without DDR.
- `M_AXI_FPD` (AXI4-full) reaches the AXI-Lite slave through a **SmartConnect**;
  its aperture puts the slave at **`0xA400_0000`** (not `0x8000_0000`).
- `pl0_resetn` is asynchronous → a **Processor System Reset**, with `dcm_locked`
  tied to a constant `'1'` (without it the reset stays asserted).
- The VHDL-2008 top needs a **Verilog wrapper** to be a BD module reference.
- The IMEM `dp_ram` generic is set to **`DEPTH=1024`** for the full firmware.

```tcl
launch_runs synth_1 -jobs 8 ; wait_on_run synth_1
launch_runs impl_1  -jobs 8 -to_step write_device_image ; wait_on_run impl_1
# → 25929 LUTs, 34 RAMB36 + 1 URAM, 76 DSP58; WNS +3.303 ns at PL 40 MHz
write_hw_platform -fixed -force ~/vhdl_repo/IP_Cores/PQC/soc/vivado/pqc_soc/pqc_soc.xsa
```

At 50 MHz the WNS was exactly 0.000 (closed but with no margin); dropping the PL
clock to **40 MHz** gives +3.303 ns. The PL clock divides to ~20 MHz on silicon,
so the self-test simply takes longer (the firmware guards and PS timeout are
sized for it).

## 11. Build & run — PetaLinux & SD card

PetaLinux 2025.2.1. Create the project, import the XSA, reuse the
reserved-memory node, add the bring-up app.

```bash
source ~/Petalinux/settings.sh
petalinux-create project --template versal --name plnx_te0950_pqc
cd plnx_te0950_pqc
petalinux-config --get-hw-description=$HOME/vhdl_repo/IP_Cores/PQC/soc/vivado/pqc_soc/pqc_soc.xsa --silentconfig
bash setup_pqc_petalinux.sh          # device tree + pqc-selftest app + firmware
echo 'CONFIG_pqc-selftest=y' >> project-spec/configs/rootfs_config
petalinux-build
# repackage BOOT.BIN fully — Versal PLM rejects a hot-loaded PDI (0x03024001):
petalinux-package --boot --u-boot --force
```

The `reserved-memory` node at `0x7000_0000` (16 MB, `no-map`) matches the family
convention. The serial console is **`ttyAMA0`** (the real UART is
`serial1@0xFF010000`, `arm,pl011`), fixed in `system-user.dtsi`.

Flash the SD (verify md5 after the copy):

```bash
cp ~/plnx_te0950_pqc/images/linux/{BOOT.BIN,image.ub,boot.scr} /media/adrian/BOOT/
sync
md5sum ~/plnx_te0950_pqc/images/linux/BOOT.BIN /media/adrian/BOOT/BOOT.BIN   # must match
sudo umount /media/adrian/BOOT
```

## 12. Silicon bring-up

On the board (serial `picocom -b 115200 /dev/ttyUSB0`, prompt
`root@plnxte0950pqc`, login `root`/`root`):

```bash
pqc-selftest
```

Expected:

```
PQC self-test: firmware /usr/bin/pqc_selftest_full.mem (972 instrucciones), DDR=0x70000000
IMEM cargado y verificado (972 palabras).
----------------------------------------------------
KEM sig = 0x95E07091FA5B3CC4  (oro 0x95E07091FA5B3CC4)
DSA sig = 0xF93232F7EA2D1575  (oro 0xF93232F7EA2D1575)
----------------------------------------------------
*** PASS: PQC self-test validado en SILICIO ***
ML-KEM-768 (FIPS 203) + ML-DSA-65 (FIPS 204) OK en el TE0950.
```

The app loads the firmware through the IMEM window (at `0xA400_0000`), sets
`DDR_BASE = 0x7000_0000`, releases the core, polls the `0x00C0FFEE` sentinel in
DDR, then reads the two signatures and compares them to the golden values.

## 13. Problems we hit and how we solved them

Real issues from bring-up, kept here so the next core doesn't repeat them.

- **The whole architecture had to pivot.** The first campaign wired the PQC as a
  direct AXI-Lite slave to the PS and never worked in silicon. The core itself
  was fine (validated across five layers); the integration was wrong. **Fix**:
  rebuild it as the family pattern — the PQC as a peripheral of a fused RV32IM,
  firmware orchestrating the operations and DMAing results to DDR. That is this
  core. The lesson: a validated core is not a validated system; the integration
  pattern is part of the design.

- **A continuous host-select stole the core's memory.** In `kem_core_sx` the
  host port takes the byte memory whenever `h_sel = '1'`. Holding it high
  continuously (to keep the read address stable) blocked the core from writing
  `ek` during KeyGen — the firmware read 1184 zero bytes (whose FNV,
  `0x6D554E45`, matched a run of zeros exactly, which is how we caught it).
  **Fix**: `host_mode` asserts `h_sel` only while the firmware is accessing the
  window and **releases it when an op is pulsed**, so the core owns its memory
  while it computes.

- **The byte read was off by one, then flat.** The core's byte port needs the
  address stable ≥2 cycles to present a byte. A one-cycle pulse returned stale
  data. **Fix**: `host_mode` holds `h_sel`/`ADDR` over the current address, and a
  `rd_primed` flag makes the first `DATA` read after setting `ADDR` prime without
  advancing — aligning the two-cycle latency so read *k* returns byte *k*.

- **The core looked hung; it was just the slower clock.** The standalone core
  testbench runs at 100 MHz (KeyGen ~916 µs); the SoC runs at 40 MHz, so KeyGen
  takes ~2.3 ms. Our first SoC sims stopped too early and read zeros. **Fix**:
  size the simulation stop-time and the PS timeout to the actual clock — the full
  six-operation self-test is ~50 ms at 40 MHz, ~100 ms at the ~20 MHz silicon PL
  clock.

- **glibc `memset` faults on the no-map DDR.** The optimized aarch64 `memset`
  uses `DC ZVA`, which SIGBUSes on the `no-map` reserved region mapped through
  `/dev/mem`. **Fix**: clear and read the DDR buffer with `volatile`
  word-by-word loops, never bulk `memset`/`memcpy`.

- **`0x8000_0000` is not a valid M_AXI_FPD aperture on Versal.** The AXI-Lite
  slave had to be mapped at **`0xA400_0000`**; Vivado's auto-assignment picked it
  correctly once the address space was M_AXI_FPD. The PL master to DDR goes
  through a dedicated NoC slave, not Connection Automation.

- **Versal PLM rejects hot-loading a full PDI** over already-configured PL
  (error `0x03024001`). **Fix**: repackage BOOT.BIN fully; never hot-load.

- **A stray `=y` in `user-rootfsconfig` broke the rootfs Kconfig.** The package
  list takes bare names (`CONFIG_pqc-selftest`); the `=y` goes in `rootfs_config`
  (the real `.config`). Mixing them produced a `config pqc-selftest=y` Kconfig
  syntax error. **Fix**: name in the list, `=y` in the config.

## 14. File layout

```
IP_Cores/PQC/
├── rtl/
│   ├── keccak_f1600.vhd / keccak_sponge.vhd   shared permutation + sponge
│   ├── ntt_unit.vhd / ntt_d_unit.vhd          NTTs (KEM q=3329, DSA q=8380417)
│   ├── sampler_*.vhd / codec_*.vhd            CBD/uniform samplers, byte codecs
│   ├── kem_keygen/encaps/decaps.vhd           ML-KEM operations
│   ├── dsa_keygen/sign/verify.vhd             ML-DSA operations
│   ├── kem_core_sx.vhd / dsa_core_sx.vhd      per-algorithm cores
│   ├── pqc_core.vhd                           fused core (shared sponge)
│   └── byte_mem.vhd / poly_mem.vhd            byte + polynomial memories
├── soc/
│   ├── rtl/
│   │   ├── pqc_mmio.vhd                        peripheral wrapper (0xD0000000)
│   │   ├── mem_subsys_pqc.vhd                  dmem decode + DMA
│   │   ├── soc_top_pqc.vhd                     fused SoC (RV32 + PQC)
│   │   └── soc_top_pqc_wrap.v                  Verilog wrapper for the BD
│   ├── fw/                                     self-test firmware + gen + ref model
│   ├── vivado/                                 pqc_soc project (BD by Tcl)
│   └── validate_selftest.sh / run_soc_validation.sh
├── verif/                                      KAT vectors (kem/dsa_st_vectors.txt)
├── doc/  pqc_soc_arch.svg
└── README.md
```

Shared sources (the RV32 core, `asm.py`, `dma_burst`) are referenced from their
origin, never duplicated.

## 15. Roadmap

- **Side-channel hardening** — masked Keccak and constant-time samplers.
- **The other NIST levels** — ML-KEM-512/1024, ML-DSA-44/87 parameter sets.
- **SLH-DSA** (FIPS 205, stateless hash-based signatures) reusing the sponge.
- A thin **key-management layer** so the PS can drive TLS/attestation directly.

## 16. License

MIT.
