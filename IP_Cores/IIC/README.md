# IIC — Memory-Mapped I²C Master/Slave IP Core for the RV32I SoC v3

Silicon-validated I²C controller (master + slave engines) for the RV32I SoC v3
family, mapped at `0x7000_0000` on the internal dmem bus. Byte-level command
interface (PIO + level IRQ), slave path backed by two FWFT byte FIFOs, full
clock-stretching support in both directions, arbitration-loss detection, and a
built-in full-cycle self-test (`LOOP_INT`) that wires the real master and the
real slave together through an internal wired-AND before the IOBUF.

**Silicon result (TE0950, xcve2302, Vivado/PetaLinux 2025.2.1):**
WNS **+2.958 ns @ 100 MHz**, triple silicon pass in `LOOP_INT` at
**100 kHz / ~400 kHz / 1 MHz (Fm+)** including write, read, repeated START and
NACK-capture phases, verified end-to-end by an RV32 program reporting through
the SoC DMA to reserved DDR.

---

## 1. Overview

Two independent engines share a single open-drain SCL/SDA pair:

* `i2c_master.vhd` — byte-level master: one command per byte
  (START/STOP/READ/ACKOUT/NOBYTE flags + data), quarter-bit timing,
  passive clock-stretching (freezes its quarter counter while SCL is released
  but held low), arbitration-loss detection on write bits and on the START
  phase, line monitor (`bus_busy`) with wait-for-free courtesy from IDLE.
* `i2c_slave.vhd` — event-driven slave: programmable 7-bit address, FWFT data
  interface designed to drop straight onto two `byte_fifo` instances, active
  clock-stretching (holds SCL when a read is requested and no TX data is
  available), drop-newest + sticky overflow policy on RX.

`i2c_mmio.vhd` wraps both engines, the two FIFOs, the dmem-style register
file, the IRQ logic and the `LOOP_INT` routing. `mem_subsys_i2c.vhd` and
`soc_top_i2c.vhd` integrate the IP into the SoC; `soc_top_i2c_wrap.v` adds the
IOBUFs for the block design.

## 2. Features

* 100 kHz / 400 kHz / 1 MHz (Fm+) — `F_SCL = Fclk / (4·(SCLDIV+1))`,
  100 MHz: 249 / 62 / 24. Any divider in between is legal.
* Master: multi-byte transactions with SCL held low between bytes
  (`ST_HELD`), repeated START, pure-STOP command (`NOBYTE`) for clean closure
  after a NACK, implicit START on the first command from idle.
* Slave: 7-bit programmable address, per-byte ACK decision, stretch-on-empty
  for reads (or 0xFF + `STX_UR` underrun sticky when stretching is disabled),
  NACK + `SRX_OVF` sticky when the RX FIFO is full (drop-newest, never
  back-pressure), START/STOP detection pulses.
* Clock stretching honored in both directions and cross-validated
  (master freeze vs. slave hold, layer 1c test T4).
* Arbitration loss: lines released, sticky flag, engine returns to idle;
  recovery verified. (ACK-slot arbitration is out of scope in v1.)
* Level IRQ, no acknowledge registers: 8 causes
  (MDONE, ARB_LOST, NACK, SRX_OVF, STX_UR, STOP_DET, SRX_WM, STX_WM).
* Sticky flags cleared by **any** write to STAT; a hardware event simultaneous
  with the clear wins and is not lost.
* `LOOP_INT` (CTRL[7]): pads released, both engines see the internal
  wired-AND — a full-cycle silicon self-test immune to the outside world.
* DMA hook ports with safe defaults (mirrors of both FIFO sides), regression
  tested (layer 2, M9) so a future `i2c_dma` lands without touching the TB.
* 10-bit addressing: by software from the master side (byte-level commands
  make it free). The slave is 7-bit in v1.

## 3. Architecture

See `architecture.svg`. The RV32 core reaches the IP through the dmem bus
region `0x7000_0000` (bits 31:28 = "0111") decoded in `mem_subsys_i2c` —
note this is the **internal** dmem space, unrelated to the physical DDR
window at the same numeric address used by the bring-up app.

```
cpu_pipeline ──dmem──> mem_subsys_i2c ──sel/addr/rdata──> i2c_mmio
                            │                              ├─ regfile (dmem contract)
                            └─ dma_burst ──m_axi──> NoC    ├─ byte_fifo ×2 (slave RX/TX)
                                                           ├─ i2c_master ─┐ wired-AND
                                                           ├─ i2c_slave ──┤ + LOOP_INT
                                                           └─ IOBUF pads ─┘ (in wrapper)
```

## 4. Register map (offsets on `addr[7:0]`, word access)

| Offset | Register | Bits |
|---|---|---|
| 0x00 | CTRL | [0] EN (master) · [1] SEN (slave) · [2] STRETCH_EN · [7] LOOP_INT |
| 0x04 | STAT | live: [0] MBUSY [1] BUS_BUSY [2] XACT_OPEN [3] ADDRESSED [4] RD_ACTIVE [5] SRX_EMPTY [6] SRX_FULL [7] STX_EMPTY [8] STX_FULL — sticky (any write clears): [16] MDONE [17] ARB_LOST [18] NACK [19] SRX_OVF [20] STX_UR [21] START_DET [22] STOP_DET [23] CMD_DROP [24] STX_OVF |
| 0x08 | SCLDIV | [15:0], default 249 (100 kHz) |
| 0x0C | CMD | [7:0] data · [8] START · [9] STOP · [10] READ · [11] ACKOUT ('1'=NACK) · [12] NOBYTE — **write fires**; dropped + CMD_DROP sticky if EN=0 or master busy |
| 0x10 | MRD | RO: [7:0] last read byte · [8] live ACK_IN ('0' = slave ACKed) |
| 0x14 | SADDR | [6:0] slave own address |
| 0x18 | STX | write → push to slave TX FIFO (full = drop-newest + STX_OVF) |
| 0x1C | SRX | read → pop slave RX FIFO: [7:0] data · [8] VALID (pre-pop) |
| 0x20 | LVL | RO: [8:0] SRX level · [24:16] STX level |
| 0x24 | IRQ_EN | [0] MDONE [1] ARB_LOST [2] NACK [3] SRX_OVF [4] STX_UR [5] STOP_DET [6] SRX_WM [7] STX_WM |
| 0x28 | IRQ_STAT | RO cause mirror; `irq = OR(IRQ_STAT & IRQ_EN)`, level |
| 0x2C | WM | [8:0] SRX_WM (cause 6 if level ≥ WM and WM ≠ 0) · [24:16] STX_WM (cause 7 if level ≤ WM) |

**dmem contract** (verified in the USART and re-verified here the hard way,
see §13): `dmem_req` lasts exactly one cycle and `rdata` is **combinational**,
captured by the core on the req edge — like `dp_ram`. The SRX pop happens on
that same edge, so the core sees the pre-pop head; side-effect-on-read is safe.

## 5. Programming model (master)

One CMD write per byte. Typical write transaction to address `A`:

```c
CMD = 0x100 | (A<<1);        // START + address/W   → poll STAT.MDONE, clear
CMD = data0;                 // data                → poll, clear
CMD = 0x200 | dataN;         // STOP + last data    → poll, clear
```

Read with repeated START: write the address again with `START|addr<<1|1`,
then `CMD = 0x400` per byte (ACK) and `CMD = 0xE00` for the last byte
(READ + NACK + STOP); the byte lands in MRD. After a NACK from the slave,
close with `CMD = 0x1200` (NOBYTE + STOP). The NACK sticky is armed only on
**write** command completions, so read ACKOUTs never false-trigger it.

An `issue_pend` window in the mmio covers the 2-cycle gap between `cmd_valid`
and the engine's `busy`, so back-to-back stores cannot double-fire a command
(layer 2 test M5 attacks exactly this).

## 6. Slave path

The slave pushes every data byte of a matched write transaction into the SRX
FIFO and serves master reads from the STX FIFO (FWFT: `tx_ren` consumes).
With `STRETCH_EN=1` and an empty STX, the slave holds SCL after the ACK until
software (or DMA) pushes a byte — the remote master simply waits. `EN`/`SEN`
gate only **new** address matches; an in-flight transaction always finishes
cleanly.

## 7. LOOP_INT self-test

`CTRL[7]=1` releases both pads and routes the internal wired-AND of both
engines' tristate controls back into their inputs. The silicon bring-up runs
entirely in this mode: the real master talks to the real slave through the
real MMIO — the same path a physical bus would use, minus the pins. With
`LOOP_INT=0` both engines share the external pads (master and slave coexist
on the same bus, as in a real combined controller).

## 8. Simulation — five layers, all green

Each layer has its own runner (xsim; also validated bit-identical in GHDL 4.1):

| Layer | TB | Runner | Finish | Highlights |
|---|---|---|---|---|
| 1a master | `tb_i2c_master` | `run_master.sh` | 907016 ns | independent event-driven EEPROM-style slave model, arbitration aggressor, foreign master, stretch, 3 speeds |
| 1b slave | `tb_i2c_slave` | `run_slave.sh` | 580797 ns | independent stretch-aware bit-bang master model, FWFT source, overflow/underrun |
| 1c engine | `tb_i2c_engine` | `run_engine.sh` | 738476 ns | RTL vs RTL over wired-AND — loop_int pre-validation; master-freeze vs slave-hold cross-test |
| 2 mmio | `tb_i2c_mmio` | `run_mmio.sh` | 368865 ns | dmem BFM, FIFO_LOG2=4 edge cases, 17-vs-16 overflow end-to-end, IRQ level cycle, DMA hooks |
| 4 soc | `tb_i2c_soc` | `run_soc.sh` | 68050 ns | RV32 running `i2c_test.s` (asm.py), doorbell + DMA report to `axi_ddr_sim` |

Shared sources are referenced from their origin (`~/rv32i/`,
`~/spi_ip/byte_fifo.vhd`); a local `byte_fifo.vhd` fallback with the exact
same entity ships for environments without them (runners prefer the origin).

## 9. SoC integration

* `mem_subsys_i2c.vhd` — `mem_subsys_dma` + region `0x7000_0000`
  (pass-through `sel/addr/rdata`).
* `soc_top_i2c.vhd` — single AXI master (`m_axi` of the SoC `dma_burst`; the
  IIC v1 has no DMA of its own), IP IRQ into both the core's `irq_ext` and
  `i2c_irq_out` (→ `pl_ps_irq1`).
* `soc_top_i2c_wrap.v` — IOBUFs **inside** the wrapper (open-drain: `I=1'b0`,
  `T=*_t`), `ASSOCIATED_BUSIF s_axi:m_axi` on `aclk`.
* Block design: cloned from the USART project (CIPS + NoC + smartconnect
  audited by `bd_review.tcl`); `m_axi → S06_AXI → C0_DDR_LOW0`, `s_axi` at
  `0x8000_0000/64K` on `M_AXI_LPD`, S07 (former USART DMA SI) removed
  (`NUM_SI 8→7`, `aclk6` re-associated to S06 only). See `bd_i2c_steps.tcl`.

## 10. Silicon results

* Timing: WNS **+2.958 ns**, WHS +0.013 ns, 0 failing endpoints @ 100 MHz
  (slightly better than the USART's +2.801 — no NCO, no IP DMA).
* Bring-up: `i2c_bringup` (see §12) — triple pass at SCLDIV 249/62/24
  (100 k / ~400 k / 1 M) in LOOP_INT, each run covering: 2-byte write
  (SRX level + data), STX-preloaded read via repeated START (MRD), and
  NACK capture on a foreign address closed with NOBYTE+STOP.
* Boot: full-image PDI hot-load via `fpgautil` was **rejected** by the PLM
  (see §13); the deterministic path is repackaging `BOOT.BIN` with the new
  XSA on the (cloned) PetaLinux project.

## 11. Pins (TE0950, CRUVI LS1, bank 302 HDIO, LVCMOS33)

| Signal | Pin | Notes |
|---|---|---|
| SCL | D10 | inherited from USART TXD on purpose; internal PULLUP |
| SDA | C10 | inherited from USART RXD; internal PULLUP |

Internal pull-ups are sufficient for LOOP_INT and 100 kHz external bring-up;
for a real external bus at 400 k/1 M use physical 2.2–4.7 kΩ pull-ups on the
CR00025 adapter (CRUVI is B2B — external loopback pending, non-blocking, same
status as the USART).

## 12. Bring-up app

`i2c_bringup.c` (PetaLinux, `/dev/mem`): maps the SoC slave at `0x8000_0000`
and the reserved no-map DDR (16 MB at physical `0x7000_0000`, node
`buffer@70000000` in the shared device tree). Halts the core, sets DDR_BASE,
loads the embedded 69-word `i2c_test` program patching SCLDIV (prog[4],
CLI argument), SADDR (prog[6]) and CTRL (prog[8]) in separate `addi`
instructions, verifies IMEM, releases the core, polls the doorbell
(DDR[3]=1337) and checks the five results. Build on target
(`gcc -O2 -o i2c_bringup i2c_bringup.c`) or use the statically linked
aarch64 binary if the rootfs has no toolchain.

## 13. Lessons learned (this project — see USART README §13 for the inherited set)

1. **The dmem read contract is combinational.** A registered `rdata` passes
   layer 2 (a polling BFM tolerates one-read lag) and fails layer 4 with a
   surgical symptom: every `lw` returns the *previous* read's data
   (`DDRcpu[0]` came back as a mid-transaction STAT). `dp_ram` reads
   `mem(idx)` combinationally; MMIO regs must do the same. Each layer catches
   its own class of bug — this one is the poster child.
2. **Module references need automatic compile order.**
   `set_property source_mgmt_mode All [current_project]` before
   `create_bd_cell -type module -reference`.
3. **Versal PLM rejects hot-loading a full implementation PDI** over a PL
   configured at boot (`Image Header Table Validation failed`,
   PLM 0x03024001). Repackage `BOOT.BIN` from the new XSA instead.
4. **Cloned PetaLinux projects carry an absolute TMPDIR.** Yocto's sanity
   checker aborts; `rm -rf build/tmp` in the clone fixes it — the
   sstate-cache survives and keeps the rebuild fast (5730/6312 tasks from
   cache here).
5. **`~` does not expand in plain Tcl arguments** (`glob` does). Use absolute
   paths or `$env(HOME)` in `add_files` and friends.
6. **GHDL rejects non-ASCII characters (em-dashes) in string literals**; keep
   report strings plain ASCII.
7. When transplanting a BD, **connect by source pin, not by net name** —
   `connect_bd_net` attaches to an existing net through any pin already on it,
   and pin paths are stable across renames.

## 14. Limitations and roadmap (v1.1+)

* **No stretch timeout**: a slave stretching forever hangs the transaction;
  watchdog belongs in software or in an mmio v1.1 register.
* **No ACK-slot arbitration** (multi-master corner; documented, out of scope).
* **Slave is 7-bit**; 10-bit addressing available from the master side by
  software.
* **`i2c_dma`**: the FIFO hook ports are in place and regression-tested;
  a USART-style DMA is a drop-in v1.1.
* **External-bus validation** pending the CR00025 adapter (non-blocking).
* **I3C**: separate IP, separate project — the open-drain pad discipline,
  filters and IOBUF-in-wrapper pattern here are half the road.
