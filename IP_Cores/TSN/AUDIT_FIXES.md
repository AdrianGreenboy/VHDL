# TSN 4x4 switch — audit 2026-11 fixes

Branch `audit-2026-11`, GHDL 4.1 (`--std=08`). Shared MII sources come from
`../ETH/rtl/` (never copied here; see `ETH/AUDIT_FIXES.md` for the CDC, the
max-length enforcement and the RX ring-buffer fix, which TSN inherits).

## Baseline

- No regression script existed; the `run_mut_*.sh` scripts expected local,
  git-ignored copies of `eth_*.vhd` that were not present.
- With `../ETH/rtl` substituted (scratch copies of the scripts): all 9 TBs
  PASS; mutations fifo 5/5, ingress 4/4, regs 5/5, tx_adapt 5/5, xbar 6/6,
  **inject 4/5** (M2's `sed` pattern no longer matched the refactored RTL).

## Findings and changes

| # | Sev | Finding | Change (file:line) | Verification |
|---|---|---|---|---|
| 1 | ALTA | external-PHY mode (`rx_src="00"`) sampled the PHY pins with the internal 25 MHz enable (no CDC, no PHY clock ports) | `tsn_top.vhd:124` one `eth_mii_cdc` per port; ports `mii_rx_clk(3:0)`, `mii_tx_clk(3:0)` (default '0'); per-port engine enables / pad mux; modes `"01"`/`"10"` unchanged | `tb_tsn_ext` (4 independent async clock pairs) |
| 2 | gap | switch used ETH engines without PTP timestamp hooks | engines now expose SFD pulses; `tsn_top` outputs `rx_sfd(3:0)` / `tx_sfd(3:0)` (wire SFD in external mode, `tsn_top.vhd:138`) | `tb_tsn_ext` (pulse count per port) |
| 3 | ALTA | (inherited) RX max length not enforced | `G_MAXLEN => 1522` (802.1Q) at `tsn_top.vhd:173`; oversize counted in DROP_FCS, flagged in ERR_STICKY | `tb_tsn_ext` (1600 B frame dropped) |
| 4 | MEDIA | `mem_subsys_dma.vhd:145-146` WSTRB ignored for TSN writes | TSN writes only with `wstrb="1111"` (`:169`); DMA regs honour byte lanes (`:189`) | `tb_mem_subsys_dma` M1/M3 (v1 fails M1) |
| 5 | BAJA | DMA register decode not gated by `dmem_req` | `wr_req` qualification (`:115`) for all register writes and start | `tb_mem_subsys_dma` M2 |
| 6 | BAJA | `tsn_inject.vhd:180` len=0 emitted 4096 bytes; go while busy lost | len 0 / > buffer refused (`:187`); one go queued while busy (`:164`), a further one refused; push while busy reported (`:134`); new `err` port -> ERR_STICKY[8] | `tb_tsn_inject_err` (v1 fails E1) |
| 7 | BAJA | `tsn_top` STATUS doc mismatch ([7:4] documented "output busy", wired to a 1-cycle cnt_tx pulse) | [7:4] = egress engine busy level (`tsn_top.vhd:242`); [11:8] documented as a pulse | doc + `tb_tsn_regs` |
| 8 | — | STATUS stickies W1C | `tsn_regs` had no stickies; new ERR_STICKY 0x0C4, W1C per bit, set wins (`tsn_regs.vhd:154`): [3:0] RX oversize, [7:4] CDC ovf/unf, [8] injector refused | `tb_tsn_ext` |
| 9 | — | reset style | all TSN RTL already synchronous active-high; the new PHY domains use reset synchronizers | — |

`tb_tsn_top_l1c` drove the pins in `rx_src="00"` in step with the internal
enable (i.e. it encoded the v1 no-CDC behaviour); it now also supplies a
phase-locked 25 MHz PHY clock (edges 20 ns from its drive/sample instants).
Result unchanged: 58 deliveries, PASS. The asynchronous case is `tb_tsn_ext`.

Not regressed (re-run, unchanged RTL): `tsn_fifo` commit/rewind, `tsn_xbar`
arbitration, `tsn_ingress` doom/rewind — all mutations still detected.

## New / changed scripts

- `run_regression.sh` (new): 12 TBs + `tb_mem_subsys_dma` (RV32 deps read-only from `../RV32i`).
- `run_mut_inject.sh`, `run_mut_tx_adapt.sh`: reference `../ETH/rtl/`; inject M2 pattern updated to the current RTL.
- `.gitignore`: new shared names, `work_reg/`.

## Final status

`run_regression.sh`: 12/12 TB PASS + `tb_mem_subsys_dma` PASS.
Mutations: fifo 5/5, ingress 4/4, inject 5/5, regs 5/5, tx_adapt 5/5, xbar 6/6.
`soc_top_master` elaborates with the RV32 sources.

## Deferred

- Per-port hardware timestamp registers / 802.1AS on the switch ports and
  Qbv gating (0x100-0x1FC): only the SFD hooks are provided (phase 2).
- `tsn_soc` (SoC shell) still hard-wires `rx_src="10"` and does not export
  the PHY clocks: external PHY use needs a new SoC shell / wrapper / XDC.
- `irq` of tsn_regs stays tied to '0' (reserved in v1).
- CDC timing constraints: see `ETH/AUDIT_FIXES.md`.
