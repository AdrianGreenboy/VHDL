# SpaceWire IP: audit 2026-11 fixes

Branch `audit-2026-11`. Every finding was re-checked against the code before it was changed.
Simulator: GHDL 4.1 (mcode), VHDL-2008.

## Baseline (before any change)

| Script | Result |
|--------|--------|
| `run_1a.sh` | PASS @29756ns |
| `run_1b.sh` | PASS @21226ns |
| `run_1c.sh` | PASS @362076ns |
| `run_2.sh` | PASS @89476ns |
| `run_soc.sh` | PASS @68055ns. The script hardcodes `/home/adrian/...` for RV32i; `RV` can now be overridden from the environment. |
| Vivado TCL / `run_bringup.sh` | not run (needs Vivado and aarch64-gcc) |

## Findings

| Id | Status | Change | Verification |
|----|--------|--------|--------------|
| FEATURE 400 Mbit/s RX | DONE | New `spw_rx_dsr.vhd`, the default (`spw_codec.G_RX_MODE = 1`). Recovered clock `D xor S` with DDR capture, 8-bit words, gray-pointer async FIFO with 2-FF synchronizers into `clk`, a decoder that handles 8 bits per cycle and a 4-entry event queue. Disconnect detection uses FIFO writes plus an activity toggle. The old oversampling RX stays available with `G_RX_MODE = 0`; the FPGA `soc_top_spw` pins it, since that is the silicon-validated path. | `tb_spw_3`: an independent DS transmitter model at 10/400/200 Mbit/s with ±0.3 ns jitter and ±0.4 ns skew, an asynchronous 100 MHz clock, parity error, re-arm and disconnect. `tb_spw_1c` runs in both RX modes. **OLD_RX** (oversampling at 400 Mbit/s) fails, and mutations S5 and S7 fail. |
| FEATURE 400 Mbit/s TX | DONE | New `spw_tx_cdc.vhd` (`G_TX_CLK = 1`, `tx_clk` port): `spw_tx` runs in `tx_clk` with `MIN_DIV = 1`. Crossings: level 2-FFs, a toggle for `div`, toggle handshakes with a cooldown for FCTs and time-codes, and an async FIFO for N-chars. `spw_tx` now compares `cnt >= div-1`, so DIV can be lowered while in Run. | `tb_spw_4`: codec to codec at 400 Mbit/s across 4 asynchronous clocks, 600 characters each way plus a time-code. S6 (no cooldown, which duplicates FCTs and causes a credit error) fails. |
| FEATURE simultaneous D/S | DONE (oversampling RX) | `spw_rx.vhd`: after the first NULL, both lines changing between two samples raises `err_par` and HALT. A drop to 00 is excluded, because that is a TX reset and is left to the disconnect detection. **Not detectable** in `spw_rx_dsr`, because it produces no rclk edge; this is documented. | `tb_spw_1b` FASE H; S4 fails. |
| MEDIA time-code validity | FIXED | `spw_mmio.vhd`: TICK fires only when the 6-bit time equals previous + 1 mod 64; otherwise only the value is updated (ECSS-E-ST-50-12C 8.12). The firmware now sends 0x01, and `tb_spw_soc` and `spw_bringup.c` were updated to match. | `tb_spw_2` FASE G (non-consecutive and wrap cases); S2 fails. |
| MEDIA STAT W1C | FIXED | `spw_mmio.vhd`: `stk <= stk and not wdata`. Firmware clears with `sw x6` (writes back the value read), so the instruction count and patch indices are unchanged. | `tb_spw_2` FASE G; S1 fails. |
| MEDIA (ASIC) reset / FIFO | FIXED | All SPW RTL now uses synchronous active-high `rst`. The only exception is the `rclk` domain, which has no clock when the line is idle. `spw_fifo` uses a registered-read RAM with a 1-deep FWFT prefetch; the entity name is kept, as the task required. | All layers. 1a and 1c (oversampling) give the same signatures as baseline. |
| BAJA stale tick_in | FIXED | `spw_codec.vhd` `time_latch`: a request is cleared and refused while the link is not in Run. | `tb_spw_2` FASE L; S3 fails. |

All runs pass, and `run_audit_mut.sh` reports `AUDIT MUTATIONS OK` (7 single-fix reverts plus OLD_RX all fail):

| Script | Result |
|--------|--------|
| `run_1a.sh` | PASS @29756ns |
| `run_1b.sh` | PASS @26486ns |
| `run_1c.sh` | PASS @365076ns (DSR) and @362076ns (oversampling, identical to baseline) |
| `run_2.sh` | PASS @200916ns |
| `run_3.sh` | PASS @46051813ps |
| `run_4.sh` | PASS @83265ns |
| `run_soc.sh` | PASS @70055ns |

## Not done / residual risk
- The 400 Mbit/s path is verified only in zero-delay RTL simulation. The D-capture ordering (data path shorter than D→XOR→rclk) and duty-cycle and skew budgets are physical; the constraints are listed in README §3.1. This path needs STA on the ASIC netlist and measurement on real LVDS transceivers.
- An EOP/EEP-only storm at the full 400 Mbit/s would exceed 1 N-char per cycle at 100 MHz. This is bounded by the 56-character credit window and absorbed by the queue and FIFO, but it was not stress-tested.
- **Vivado:** `bd_spw_steps.tcl` and the README now list `spw_rx_dsr.vhd` and `spw_tx_cdc.vhd`, which the codec references through generate blocks. This has not been run in Vivado.
- A genuine simultaneous transition into D=S=0 is not flagged by the oversampling RX; it is treated as a TX reset.
