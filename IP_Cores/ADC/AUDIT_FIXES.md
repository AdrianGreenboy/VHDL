# ADC delta-sigma — audit fixes (audit-2026-11)

## Baseline (before any change)

`adc_paso1..5_*.sh` all PASS:

| Step | Result |
|---|---|
| PDMGEN | CHK=0x90C8821F, MUT 4/4 |
| CIC | N=164, CHK=0x148B6E65, MUT 5/5 |
| CORE | N=233, CHK=0x7CEE740E, MUT 5/5 |
| MMIO | NCHK=567, MUT 5/5 |
| SOC | N=65, CHK=0x1B8D3FF9, MUT 5/5 |

The repo files are byte-identical to the scripts' heredocs.

**Important:** the paso scripts regenerate the RTL from those heredocs (snapshot of v1), so they do **not** test the repo files once the repo changes. **New `run_adc_regress.sh`** runs the same five flows, including the mutation batteries, with every heredoc that writes a repo file skipped. The repo sources are the ones under test, in a temp HOME. The heredoc copies inside `adc_paso*.sh` are now historical.

## Fixes

| Sev | Finding | Fix |
|---|---|---|
| MEDIA | `adc_core`: the external modulator path assumed modulator bit rate = aclk. | New `pdm_clk_i`. `pdm_ext_i` is captured on the modulator clock into a 4-entry ring, and a 3-bit Gray count crosses to aclk through a 2-FF synchronizer. One CIC valid is issued per modulator bit. The capture is exact for any f_pdm < f_aclk; lag ≥ 3 raises `ext_ovr` (never silent). `pdm_fb_o` follows the pdm_clk-domain bit. Selected by the new EXT_CFG register (0x2C bit0). Legacy mode is unchanged bit for bit. |
| MEDIA | `adc_mmio`/`adc_regs`: unarbitrated MMIO + DMA pops. | MMIO never pops while `dma_busy_i`. A FIFO_DATA read is held off (new `ready` output → `adc_soc.ready` → `mem_subsys_adc.dmem_ready`) until the DMA releases the FIFO. |
| MEDIA | `adc_fifo`: silent overflow. | Sticky `ovf`, mirrored as IRQ_STAT bit2 (W1C, IRQ_EN bit2, irq source). The W1C also clears the FIFO flag. The modulator overrun goes to IRQ_STAT bit3. STATUS is unchanged (the legacy TB checks it exactly). |
| BAJA | `adc_regs`: destructive read decoded combinationally. | A pop happens once per bus transaction (`popped` flag until sel drops). |
| BAJA | `mem_subsys_adc`: `dma_go` / DMA register writes not qualified by `dmem_req`. | Both are now qualified by `dmem_req`. |
| BAJA | Reset synchronizer. | 2-FF reset synchronizer in `adc_soc`. It feeds the synchronous MMIO reset and releases the datapath's async reset synchronously. |

Every line targeted by the paso mutation batteries was kept textually intact, so the batteries still apply.

## Tests

- **New `tb_adc_audit.vhd`** (run by `run_adc_regress.sh`):
  - (A) ext-clock mode on an independent 37 ns modulator clock gives exactly the same CIC sample sequence as a legacy-mode reference fed the same 1st-order ΣΔ bits;
  - (A2) the same at 13 ns (0.77·f_aclk);
  - (B) 7 ns (faster than aclk) → overrun reported;
  - (C) overflow sticky + irq + W1C, with STATUS compatible;
  - (D) DMA busy holds off the MMIO pop while DMA pops proceed;
  - (E) a 3-cycle sel pops once.

  All PASS. Old RTL: the interface does not exist. Mechanisms checked by reading: E pops 3× on HEAD, and C sets no flag on HEAD.
- `run_adc_regress.sh`: paso1..5 on the repo sources plus their mutation batteries; see the final report for results.

## Deferred / notes

- **Reset style**: the datapath (pdmgen/cic/core) keeps an async active-low reset, and the MMIO side is synchronous active-high. It is now driven by one synchronized reset. A full conversion to synchronous resets was not done.
- The `adc-bringup.c` / ISS / firmware do not use EXT_CFG or the new IRQ bits.
- `mem_subsys_adc` still ties `pdm_ext_i='0'`; the SoC does not bond the modulator pins in v1 (the hook remains). `pdm_clk_i` must be routed and constrained as a clock at the board/ASIC top when used.
