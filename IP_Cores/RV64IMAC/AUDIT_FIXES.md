# RV64IMAC - audit-2026-11 fixes

Branch `audit-2026-11`. Only low-severity (BAJA) findings; verification
methodology unchanged (`run_regression.sh`: ISS vs riscv-tests, Spike,
lockstep layers 2/3/3b/4, mutation suite).

## Fixes

| # | Finding | Fix | Functional change |
|---|---------|-----|-------------------|
| 1 | `rv64_core.vhd`: `rst` folded into combinational request logic (fetch `want`, data `core_req_valid`, `ptw_grant`) | **Not removed - finding rejected on regression evidence.** With the `rst` terms removed, layer 2 lockstep failed (csr_sweep, irq_race, cbo_test: wrong instruction at retire 2): the core issues fetches during reset, the responder (tb_core memory model; in a SoC any slave not on the same reset) answers after reset, and the stale response is taken as the reply to the first real fetch. The terms are load-bearing; kept, with a comment explaining why. | None (RTL identical to HEAD apart from the comment). |
| 2 | `rv64_axi_master.vhd`: `awid` fixed `"0000"`, `arid = "000" & cli` | `m_awid <= "000" & cli` (same scheme as AR). | None: only the D$ (client 0) writes, so AWID stays 0. |
| 3 | `rv64_uart.vhd`: divisor 0 -> `bitlen = 0`, counters compare against `2^20 - 1` (about 1 M cycles per bit) | Divisor 0 treated as 1 (`bitlen = 16`). | Only for divisor 0. |

Also:

* `sim/build.sh`: the USART core (another folder) now uses its private
  `usart_byte_fifo.vhd`; the build adds it when present (otherwise `tb_soc`
  no longer compiled). Builds `tb_uart`.
* README: the RV32IMA core was removed from the repository in this audit;
  references updated (SPEC_FREEZE_V1.md left as the frozen historical text).

## Tests

* New `tb/tb_uart.vhd` (layer 1 in `run_regression.sh`): TX looped to RX,
  divisors 1, 0, 3, 0; checks received byte and frame length. Fails on the
  original RTL (div 0: nothing received), passes on the fix.
* New mutation in `mutate.py`: "UART: divisor 0 sin proteger" (unit test
  `tb_uart`); `mutate.py` now accepts unit tests without a vector file.

## Results (GHDL 4.1 ghdl-gcc, logs in sim/audit_logs/)

| Layer | Baseline (HEAD) | Final |
|-------|-----------------|-------|
| 0 ISS vs riscv-tests | 195 PASS | 195 PASS |
| 0 ISS vs Spike | skipped (no Spike) | skipped (no Spike) |
| 1 RVC / muldiv / UART | 49152 / 13728 cases, (no tb_uart) | same + tb_uart 4/4 |
| 2 lockstep, ideal memory | 201/201 + irq_storm | 201/201 + irq_storm |
| 3 random latency (6:1 only) | not run (time) | 199/199 + irq_storm |
| 3b caches + AXI (1:1 only) | not run (time) | 200/200 + cache_stress |
| 4 SoC from boot ROM (1:1, 6:7) | not run (time) | 114/114, 114/114 |
| mutations | not run (time) | 31/31 killed |

Layer 3 ran one of the six latency/seed configurations and 3b one of three
(the `rapida` subset of `run_regression.sh`). Spike was not available in the
audit environment, so the optional ISS-vs-Spike layer was skipped.
