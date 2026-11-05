# MIPI CSI-2 RX — audit fixes (audit-2026-11)

Owner decision: the PHY/lane layer is in scope and must be build-ready for the chip.

## Baseline (before any change)

- `verif/run_all_sims.sh`: L1, L2a, L2b, L3, L4, L5a and L5b all PASS (signatures 0xEC935F45, 0xADBF2613, 0x0C4F29C5, 0xE6898DC5).
- `tb_soc_mipi` (RV32 firmware end to end): PASS 0xE6898DC5.
- `tb_l5_full.vhd` is **stale**: it instantiates a non-existent `mipi_top` entity. This was already broken before the audit and has not been repaired.

## Fixes

| Sev | Finding | Fix |
|---|---|---|
| ALTA | `mipi_dma_burst`: registered AWVALID/WVALID were re-armed in the handshake cycle, which duplicated AW and W beats. | AWVALID, WVALID, WLAST and BREADY are now driven combinationally from the state (S_ADDR/S_PUSH/S_RESP). READY is sampled only while VALID is high, and the payload is stable while VALID is high. |
| BAJA | `mipi_dma_burst`: lengths not a multiple of 4 overwrote up to 3 bytes, and length=0 wrote one beat. | Partial WSTRB on the last beat; length 0 produces no traffic; dst is forced to 4-byte alignment (documented). |
| ALTA | `byte_fifo` + `csi2_packet_rx`: the parser was paced at 1 byte per 3 cycles, with silent drop. | The packet layer consumes a byte every cycle in every state: the header is decoded on its 4th byte and the CRC compared on the 2nd CRC byte. Pacing removed. `byte_fifo.vhd` now declares **`mipi_byte_fifo`** (core prefix) with a sticky `ovf`. |
| ALTA | `dphy_model`: the "4-lane deskew" was a passthrough, and there was no PHY port. | **New `csi2_lane_rx.vhd`** (byte-clock domain). Per lane: 0xB8 SoT hunt at bit offsets 0..7 on raw ISERDES-style bytes (`cfg_hw_sync=0`), or trusted aligned PPI bytes (`=1`); 8-deep deskew FIFO; LSB-lane-first merge; partial last beat; EoT marker; deskew timeout and lane-overflow errors. **New `mipi_async_fifo.vhd`** (Gray pointers, 2-FF sync, overflow event to aclk). The RX top `csi2_selftest` gains PPI ports (`ppi_clk`, `ppi_byte[31:0]`, `ppi_valid/active/sync[3:0]`), a byte-clock reset synchronizer, config synchronizers, and a source mux (self-test frame_gen vs external PPI). These are exposed on `mipi_soc_top`, `soc_top_mipi` and `soc_top_mipi_wrap.v`. `dphy_model.vhd` is marked DEPRECATED and is unused. |
| MEDIA | ECC abort and framebuffer pointer overrun. | An uncorrectable header emits no SOP, pulses `hdr_2bit`/`pkt_err`, and discards bytes until the next SoT. An SoT or EoT mid-packet drops the packet. FB pointers are clamped at FB_DEPTH: an overflowing packet is dropped and `fb_ovf` pulses. FS rewinds that VC's FB to 0. |
| MEDIA | `csi2_mmio` FBDATA returned the previous byte. | FBSEL prefetches byte 0; each FBDATA read returns the byte at the pointer and prefetches the next one. `fw_rv32.c` no longer does the priming read. |
| MEDIA | `raw12_unpack` dropped a byte arriving in the P1 cycle. | Byte capture is independent of P1 emission. A conflict is impossible by construction, so no skid buffer is needed. |
| — | STATUS / IRQ. | STATUS is sticky W1C: bit3 rx_ovf, bit4 fb_ovf, bit5 pkt_err, bit6 lane_err, bit7 frame. New CFG register (0x24: src_ext, lanes, hw_sync, multi_pkt), IRQ_EN register (0x28), and `irq` output (→ `mipi_irq` at the SoC top). |
| — | Reset. | `soc_top_mipi` now has a 2-FF reset synchronizer (previously combinational from aresetn). MIPI was already synchronous active-high. |

**Throughput (honest).** The packet and FB path is byte-wide, 1 byte per aclk. A burst at full PHY rate is sustained only if f_aclk ≥ lanes × f_byteclk. Otherwise the async FIFO (512 beats) absorbs a burst, and the excess is dropped with STATUS.rx_ovf + IRQ, never silently. A 32-bit packet/FB datapath is deferred.

## Tests (`verif/run_all_sims.sh` runs all of them)

- **L1-LR / L2-LR**: back-to-back bytes (new generics `BUBBLE` / `BUBBLES`). HEAD RTL fails both (L1 0xDFE3B145, L2 0x811C9DC5); new RTL passes.
- **New `tb_l6_ppi.vhd`**: an independent behavioural CSI-2 TX model on its own byte clock. It does lane distribution, an HS-zero leader with a random 0..7 bit offset, 0xB8, a ≥16-bit trailer, random 0..3 byte lane skew, random LP gaps, and in HW-sync mode common RxValidHS gaps. It feeds 204 oracle bursts: interleaved dual-VC frames, a 2-bit ECC header (abort), a CRC error, a truncated burst, a 1-bit header error, an FB-overflow line, and a second VC1 frame (FS rewind). FB0/FB1 are compared **byte-exact** against `csi2_oracle.py::rx_parse_bursts` (new), plus the pkt_err/fb_ovf/frame counts. Configurations: 1/2/3/4 lanes, raw and HW-sync, byte clock 7..37 ns vs aclk 10 ns, plus `OVF_TEST` (rx_ovf reported, receiver recovers). All PASS. HEAD has no PPI path and cannot run this test.
- **New `tb_dma_axi.vhd`**: an AXI slave model (random / always-ready / ready-follows-valid) plus an independent protocol checker (VALID stability, payload stability, AWLEN vs beats/WLAST, 4 KB, B count) plus a byte scoreboard (lengths 0..9, 4 KB crossings, >256-beat splits). HEAD: AW=76, W=12358, 28690 errors (duplicates). New: PASS in all 3 modes.
- **L1-L5**: unchanged signatures, all PASS. `tb_soc_mipi` (rebuilt firmware): see the final report.

## Deferred / notes

- 32-bit packet layer for line rate at f_aclk < lanes × f_byteclk.
- `tb_l5_full.vhd` (stale since before the audit). The file renames byte_fifo.vhd → mipi_byte_fifo.vhd and dphy_model removal are left to the owner (no deletes and no git mv in this audit).
- With a raw PHY use `cfg_multi_pkt=0` (one packet per HS burst, so trailer bytes are ignored). Multi-packet bursts are only safe with a PHY that strips the trailer.
- ASIC: self-test mode does not need ppi_clk, but the lane-layer reset requires ppi_clk to run while `rst` is asserted. PPI timing constraints and a CDC sign-off of the ASYNC_REG synchronizers still need to be done in the implementation flow.
- The aarch64 `fw_ps` side is unchanged (it does not use FBDATA).
- `scripts/build_bd*.tcl` were not changed. The wrapper now has `ppi_*` inputs and a `mipi_irq` output. On the TE0950 (no D-PHY), tie `ppi_*` to an xlconstant 0, or let IPI tie them off with a warning, and optionally route `mipi_irq` to `pl_ps_irq[1]`. This has not been validated in Vivado here.
