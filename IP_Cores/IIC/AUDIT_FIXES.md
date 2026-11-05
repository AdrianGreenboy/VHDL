# IIC — Audit 2026-11 fixes

Branch `audit-2026-11`. Simulator: GHDL 4.1 (mcode). xsim scripts
(`run_*.sh`) and `bd_i2c_steps.tcl` were updated but not executed here;
results are from `./run_ghdl.sh all`.

## Baseline (before any change)

| TB | Result |
|---|---|
| tb_i2c_master (T1-T8) | PASS |
| tb_i2c_slave (T1-T8) | PASS |
| tb_i2c_engine (T1-T8) | PASS |
| tb_i2c_mmio (M1-M10) | PASS |
| tb_i2c_soc | PASS |

## Findings and changes

| # | Sev | Finding | Change (file:line) | Verification |
|---|---|---|---|---|
| 1 | ALTA | `byte_fifo` with ASYNC reset driven from logic (`aresetn <= not rst`, old `i2c_mmio.vhd:154`), entity-name collision | Private `i2c_byte_fifo.vhd` (sync active-high `rst`, SRAM-mappable registered read + prefetch, FWFT cycle-identical), driven directly by `rst` (`i2c_mmio.vhd:227,236`). Scripts: `run_mmio.sh`, `run_soc.sh`, `bd_i2c_steps.tcl:34-35`, new `run_ghdl.sh`. Old `byte_fifo.vhd` kept with a DEPRECATED header (no deletion without consent) | `tb_i2c_byte_fifo` (new) PASS; single-library analysis: no collisions |
| 2 | MEDIA | No escape paths in the master | `i2c_master.vhd`: quarter-tick time base (`:169`); clock-stretch timeout (`:449`); stuck-bus timeout in WAITFREE (`:260-265`, counter per wait `:201`); `bus_busy` = 1 after reset (`:133,471`), cleared by STOP or `BUS_FREE_Q` idle quarters (`:70,191`); tBUF after foreign STOP (`:182,260`); STOP / bus clear accepted in ST_HELD regardless of `en` (`:370`); bus clear `ST_CLEAR` 9 pulses + STOP (`:242,423`). MMIO: `TOUT` @0x30 (`i2c_mmio.vhd:330`), CMD[13] BUS_CLEAR, NOBYTE/CLEAR accepted with EN=0 (`:290`), sticky TIMEOUT STAT[25] + IRQ bit 8 (`:352`), STAT[9]/[10] line levels | `tb_i2c_master_audit` (new) R1-R8: reset bus-free observation, stretch timeout (~tout_q quarters, lines released), stuck bus, tBUF >= 4 quarters, STOP in HELD with en=0, bus clear (slave releases after 5 pulses: exactly 9+STOP), clear with SCL stuck -> timeout, tout_q=0 legacy. `tb_i2c_mmio` M12/M13 (slave stretching forever -> TIMEOUT + IRQ -> BUS_CLEAR -> bus usable) |
| 3 | MEDIA | Any write to STAT clears all stickies | W1C per bit `i2c_mmio.vhd:274`; firmware `i2c_test.s` (x22 = 0xFFFFFFFF) and regenerated `prog[]` in `i2c_bringup.c` (1 inserted word after the patch indices + 2 stores changed; verified by word diff) | `tb_i2c_mmio` M11; `tb_i2c_soc` with the new firmware PASS |
| 4 | BAJA | rdata mux not gated by `sel` | `i2c_mmio.vhd:418` | `tb_i2c_mmio` M11 |
| 5 | BAJA | WM not clamped | `i2c_mmio.vhd:318` | `tb_i2c_mmio` M11 |
| 6 | BAJA | tBUF after foreign STOP | see #2 | R4 |

Protocol logic (stretching, arbitration, filters, slave) is untouched; all
pre-existing TBs pass unchanged except the W1C migration of STAT clears.

## Final status (GHDL)

tb_i2c_byte_fifo, tb_i2c_master, tb_i2c_master_audit (R1-R8),
tb_i2c_slave, tb_i2c_engine, tb_i2c_mmio (M1-M13), tb_i2c_soc: **all PASS**;
`soc_top_i2c` elaborates.

## Deferred / notes

* `TOUT` resets to 0 (disabled) to keep the legacy behaviour; firmware for
  flight should program it (e.g. 25 ms SMBus tTIMEOUT = 10000 at 100 kHz).
* `BUS_FREE_Q` (default 8 quarters = 2 bit times) is a heuristic: on a
  multi-master bus with a master >4x slower than ours it must be raised.
* Bus clear always sends 9 pulses (no early exit when SDA rises): harmless.
* ACK slot still not arbitrated (v1 limitation, unchanged).
* First START after reset is delayed by the bus-free window (~2 us at
  1 MHz); `tb_i2c_soc` finishes at 70.05 us instead of 68.05 us.
* SoC-level runs used RV32i from git `HEAD` (working tree modified by
  another task, out of scope). Not yet validated against real I2C devices.
