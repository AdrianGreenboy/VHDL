# ETH MAC — audit 2026-11 fixes

Branch `audit-2026-11`. GHDL 4.1 (mcode, `--std=08`). All findings were
re-verified on the code before changing it. `eth_pkg`, `eth_cdc_sync`,
`eth_async_fifo`, `eth_mii_cdc`, `eth_tx_mii`, `eth_rx_mii`, `eth_mac` are the
**canonical shared MAC sources**: PTP keeps byte-identical copies in `PTP/rtl/`
(its regression warns if they drift) and TSN references them from here.

## Baseline (before any change)

| Script | As-is | With deps resolved read-only |
|---|---|---|
| `sim/run_l1a.sh` / `run_l1b.sh` / `run_l1c.sh` | PASS (+4/4 mutations each) | — |
| `sim/run_l2.sh` | **FAIL**: needs `~/spw_ip/spw_fifo.vhd`, fallback `../rtl/spw_fifo.vhd` does not exist | PASS (+4/4) |
| `sim/run_l4.sh` | **FAIL**: needs `~/rv32i` sources | PASS (`ETH CAPA 4 PASS`) |

## Findings and changes

| # | Sev | Finding (re-verified) | Change | Verification |
|---|---|---|---|---|
| 1 | ALTA | `eth_mac.vhd:80-81` external-PHY mode had no CDC: no RX_CLK/TX_CLK ports, RXD sampled with the internal 25 MHz enable | New `rtl/eth_cdc_sync.vhd` (2-FF sync, toggle pulse sync, reset synchronizer), `rtl/eth_async_fifo.vhd` (Gray pointers, 2-FF synced), `rtl/eth_mii_cdc.vhd` (RX pads on RX_CLK :131, TX pads on TX_CLK, TX ce throttle :186, wire-SFD pulse :248). `eth_mac.vhd`: ports `mii_rx_clk/mii_tx_clk`, CDC instance :122, enable/data mux :132. LOOP_INT unchanged (internal /4 enable, pads mirror the engine as in v1) | `tb/tb_eth_mii_cdc.vhd` (3 clock configs) |
| 2 | ALTA | `eth_rx_mii.vhd:153-178` `G_MAXLEN` unused; `nb` (0..4095) / `wr_ptr` overflow; oversize frame accepted truncated | `eth_rx_mii.vhd:204` frame doomed at byte G_MAXLEN+1, swallowed to RX_DV low, `ev_oversize` pulse, never drained (:228); counters saturate | `tb/tb_eth_rx_ring.vhd` T2/T3/T4 |
| 2b | **ALTA (new)** | Found by the new CDC TB, not in the prior audit: a frame > ~1140 B followed by a minimum-size frame was **corrupted** — the short frame completed while the long one was still draining and restarted the drain at index 0 (same bug in LOOP_INT) | Frame buffer is now a ring with one pending-drain slot (`eth_rx_mii.vhd:150`), rejected frames give their space back; >=1 idle cycle kept between drains (tsn_ingress contract) | `tb_eth_rx_ring` T1 fails on v1 ("frame id 1 byte 672 corrupted"), passes now |
| 3 | ALTA (ASIC) | `eth_mmio.vhd:137/158` FIFOs (`spw_fifo`) read memory asynchronously; async reset | New `rtl/eth_fifo.vhd`: single sync-read port (:112) + 1-deep FWFT prefetch (tsn_fifo pattern), sync reset; used at `eth_mmio.vhd:157,183`. No more `~/spw_ip` dependency | L2, L4, `tb_eth_mmio_ovf` |
| 4 | MEDIA | `eth_mmio.vhd:155` RX FIFO overflow dropped bytes mid-frame incl. EOF | Speculative write + commit/rewind on the last byte (`eth_mmio.vhd:180`, `p_doom`): only whole frames reach the FIFO; RXF_OVF = "frame dropped" | `tb_eth_mmio_ovf` A fails on v1 ("remnant of the dropped frame in RX FIFO") |
| 5 | MEDIA | Reset style: async `aresetn` in eth_mmio | All eth_mmio processes synchronous active-high; PHY domains get reset synchronizers (async assert / sync de-assert, the only async clear, inside `eth_rst_sync`) | all TBs |
| 6 | BAJA | `eth_mmio.vhd:211` STAT b14:8 = `rxf_level(6:0)` (12->7 bit truncation) | Saturated view (:256) + new `LEVEL` register 0x20 (:271) with full rx/tx levels | `tb_eth_mmio_ovf` C |
| 7 | BAJA | CMD b2 TX_GO documented, never implemented | Documented as reserved/ignored (:38); TX starts on EOF (store-and-forward) | doc |
| 8 | — | STATUS stickies cleared by any write | STAT stickies W1C per bit (:321), set wins; new b23 RX_OVERSIZE, b24 PHY_RX_OVF, b25 PHY_TX_UNF | L2 (updated), `tb_eth_mmio_ovf` B |
| 9 | (new, BAJA) | TX_FLUSH did not reset the store-and-forward frame counter -> a later partial frame started transmitting (underrun) | `eth_mmio.vhd:216` | `tb_eth_mmio_ovf` E |
| 10 | (new, BAJA) | `mem_subsys_eth.vhd` DMA register writes / start not qualified by `dmem_req` (same pattern as TSN) | `:111`, `:157` | L4 |
| — | — | doc: TXD read is b11:0 level, b12 full (doc said b6:0/b8) | header fixed | — |

`soc_top_eth.vhd` gets `mii_rx_clk/mii_tx_clk` ports with default `'0'`; the
Verilog wrapper and `eth_pins.xdc` were deliberately **not** changed (pin LOCs
unknown; adding unconstrained ports would break the LOOP_INT bitstream flow).

## Timestamp / latency (measured, `tb_eth_mii_cdc`, core 100 MHz)

| Path | Latency wire SFD -> core pulse | Spread |
|---|---|---|
| TX (`tx_sfd_pulse`, launch edge of the D nibble) | 20.1 – 29.9 ns | < 10 ns (1 core clock) |
| RX (`rx_sfd_pulse`, RX_CLK edge sampling D) | 80.2 – 89.8 ns | < 10 ns |

Accuracy = fixed latency (calibrate with TX_LAT/RX_LAT) + uniform 1-core-clock
quantization (±5 ns around the mean). PHY-internal latency is not included.

## New tests (all `assert … severity failure`, in `sim/run_audit.sh`)

| TB | Covers | Old code |
|---|---|---|
| `tb/tb_eth_mii_cdc.vhd` | 40 TX + 48 RX frames, TX_CLK/RX_CLK ±100 ppm, independent FCS/content/preamble/IPG checks, error frames, oversize, timestamp spread | does not elaborate (no PHY clocks) |
| `tb/tb_eth_rx_ring.vhd` | long+short back-to-back, 1519 B and 5000 B oversize, exact 1518 | fails T1 (corruption) |
| `tb/tb_eth_mmio_ovf.vhd` | whole-frame drop, W1C, LEVEL, oversize sticky, flush | fails A |

## Final status

`run_l1a/l1b/l1c/l2/l4.sh`: PASS (all mutations detected); `run_audit.sh`: 5/5 PASS.
L2/L4 now run without `~/spw_ip`; L4 falls back to `../../RV32i` (read-only).

## CDC constraints (to add in the implementation flow — deferred, no XDC/SDC in repo for this)

- `set_max_delay -datapath_only <Tmin>` + `set_bus_skew <Tcore>` on
  `*eth_async_fifo*/wgray* -> */wgs1*`, `*/rgray* -> */rgs1*`, and `*/mem* -> rdata` consumers.
- false path to the first stage of `eth_sync_bit`/`eth_pulse_sync`/`eth_rst_sync` (`ASYNC_REG` set).
- `create_clock` for each MII RX_CLK/TX_CLK, `set_input_delay` per 802.3 cl.22 (10 ns setup/hold) and `set_output_delay` for TXD/TX_EN.

## Deferred

- RX_ER, MDIO/MDC, CRS/COL (half duplex) not implemented — out of the audit scope.
- Partial (sb/sh) stores to eth_mmio are still collapsed to a word write in `soc_top_eth.vhd` (`eth_we`); not in the findings, firmware uses `sw` only.
- Real-PHY validation (see risk note in the PTP/TSN reports): only simulation so far.
