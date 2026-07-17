# Bring-up en silicio — RF Digital Front-End (DDC/DUC) · TE0950 / Versal xcve2302

Secuencia de trasplante e integración para llevar el RF Digital Front-End a la
placa Trenz TE0950. Ejecutar en la consola Tcl de Vivado 2025.2.1 **un comando a
la vez**, leyendo cada respuesta antes del siguiente (lección USART #4: los
bloques pegados esconden fallos silenciosos). `source settings64.sh` primero.

Golden de validación (del datapath GHDL, `TONE_FTW=0`): **`CHK = 0xB74940EB`**
sobre 64 muestras. Régimen constante `~0x5D4Dxxxx`; primeras muestras
`0003FFFF 059BFFFF 2EA5FFFF 57AFFFFF ...`.

## Arquitectura de integración

El RF entra al SoC v3 con el patrón de la familia, con **dos maestros AXI** hacia
la DDR (como el ADCS):

- `m_axi` — DMA de la familia (`dma_burst`, reporte/doorbell) → `S06_AXI`.
- `rf_axi` — segundo maestro propio del RF (drena la RX FIFO a DDR) → `S07_AXI`.

Ambos maestros son de 40 bits y mapean a `C0_DDR_LOW0`. El NoC se amplía a
`NUM_SI=8 / NUM_CLKS=8`, con `aclk7` asociada a `S07_AXI`. Dos líneas IRQ:
`irq_out` (doorbell del core) → `pl_ps_irq0`, y `rf_irq_out` (nivel de RX FIFO) →
`pl_ps_irq1`.

El esclavo AXI-Lite (control + carga de IMEM) está en `M_AXI_LPD 0x8000_0000/64K`.
El banco RF y el datapath viven en `0x6000_0000` del bus dmem interno (vía
`mem_subsys_rf`). La banda base la genera un **segundo NCO** (tono programable por
MMIO, `TONE_FTW` en offset `0x40`); con `TONE_FTW=0` es banda base DC de amplitud
29491. La LUT sen/cos está **embebida** en `rf_sincos_pkg` (constante VHDL): no
hace falta ningún `.txt`/`.mem`/`.coe` en síntesis.

**Nota de nomenclatura (lección de este IP):** el segundo maestro se llama
`rf_axi`, no `rf`, para que Vivado no confunda su interfaz AXI con el escalar
`rf_irq_out` al inferir interfaces por prefijo. El wrapper Verilog expone
`m_axi_*`, `rf_axi_*` y `s_axi_*` como interfaces limpias.

## Pre-requisitos

- Proyecto Vivado del TSN existente y cerrado
  (`~/vhdl_repo/IP_Cores/TSN/vivado_tsn/tsn_soc.xpr`).
- RTL del RF en `~/vhdl_repo/IP_Cores/RF/rtl/` (incluye `rf_soc_top_master_wrap.v`).
- `bd_review.tcl` en `~/vhdl_repo/IP_Cores/USART/`.
- Fuentes del core RV32IM en `~/rv32i/` (referenciadas, no duplicadas).

## Fase 0 — clonar

1. `open_project ~/vhdl_repo/IP_Cores/TSN/vivado_tsn/tsn_soc.xpr`
2. `save_project_as rf_soc ~/rf_ip/vivado_rf -force`
3. `set_property source_mgmt_mode All [current_project]`
4. `reset_run synth_1` ; `reset_run impl_1`
5. Vaciar el incremental checkpoint del RUN (no el arg de `synth_design`):
   `set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]` (y `impl_1`).
6. Barrido de referencias remotas — resolver cualquier `REMOTA:` antes de seguir:
   `foreach f [get_files -all *] { if {[string match *vivado_tsn* $f]} { puts "REMOTA: $f" } }`

## Fase 1 — sustituir el IP en el BD

Los pasos completos están en `rf_soc_steps.tcl`. Resumen:

7. `open_bd_design [get_files bd_soc_usart.bd]`
8. Descubrir ANTES de borrar: `get_bd_cells`, `get_bd_intf_pins u_soc_tsn/*`.
9. `delete_bd_objs [get_bd_cells u_soc_tsn]`
10. Quitar fuentes TSN/ETH y añadir las del RF (ver `rf_soc_steps.tcl` paso 2).
11. `create_bd_cell -type module -reference rf_soc_top_master_wrap u_soc_rf`

## Fase 2 — ampliar el NoC (dos maestros)

12. `set_property -dict [list CONFIG.NUM_SI {8} CONFIG.NUM_CLKS {8}] [get_bd_cells axi_noc_0]`
13. S07 a la DDR: `set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500}}}] [get_bd_intf_pins axi_noc_0/S07_AXI]`
14. aclk7 asociada a S07: `set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S07_AXI}] [get_bd_pins axi_noc_0/aclk7]`

## Fase 3 — reconexiones (por pin de origen, una a una)

15. clk/reset a `u_soc_rf/aclk` y `/aresetn`.
16. `axi_smc/M00_AXI` → `u_soc_rf/s_axi`.
17. `u_soc_rf/m_axi` → `axi_noc_0/S06_AXI` (DMA de la familia).
18. `u_soc_rf/rf_axi` → `axi_noc_0/S07_AXI` (segundo maestro del RF).
19. `pl0_ref_clk` → `axi_noc_0/aclk6` **y** `axi_noc_0/aclk7`.
20. Verificar asociación (lección #5): `aclk6`→S06, `aclk7`→S07, sin cruces.
21. IRQs: `u_soc_rf/irq_out` → `pl_ps_irq0`; `u_soc_rf/rf_irq_out` → `pl_ps_irq1`.

## Fase 4 — address map y auditoría

22. `m_axi` (S06) → `C0_DDR_LOW0`; `rf_axi` (S07) → `C0_DDR_LOW0`; esclavo del PS
    → `u_soc_rf/s_axi/reg0` en `0x8000_0000/64K`. (Comandos en `rf_soc_steps.tcl`.)
23. `validate_bd_design` — recordar que dice OK aunque el mapa esté mal: auditar.
24. `source ~/vhdl_repo/IP_Cores/USART/bd_review.tcl` y revisar `bd_report.txt`:
    confirmar `NUM_SI=8`, `S07 CONNECTIONS=MC_0`, `aclk7→S07`, ambos maestros
    (S06, S07) → `C0_DDR_LOW0`, y las dos IRQ conectadas.
25. `set_property top bd_soc_usart_wrapper [current_fileset]` ; `save_bd_design`.

## Fase 5 — síntesis / implementación / imagen

26. `source ~/vhdl_repo/IP_Cores/RF/vivado/run_synth_rf.tcl` — confirma
    `SYNTH STATUS = ...Complete!` y `TOP = bd_soc_usart_wrapper`.
27. `source ~/vhdl_repo/IP_Cores/RF/vivado/run_impl_rf.tcl` — confirma
    `IMPL ...Complete!`, `WNS ≥ 0`, `DRC críticos = 0`, y que escribe el XSA.
    - PDI: `vivado_rf/rf_soc.runs/impl_1/bd_soc_usart_wrapper.pdi`
    - XSA: `~/rf_ip/rf_soc.xsa`

## Fase 6 — PetaLinux (nunca `cp -a`, nunca hot-load PDI)

28. Clonar el proyecto PetaLinux copiando **solo** `project-spec/` + `.petalinux`
    (nunca `cp -a`: arrastra rutas absolutas de `build/tmp`). Borrar artefactos de
    build viejos antes (el disco es una restricción recurrente).
29. `petalinux-config --get-hw-description=~/rf_ip/rf_soc.xsa` (importa el XSA).
30. Confirmar el pool DDR reservado en `system-user.dtsi` (heredado por todos los
    IPs de la familia): `0x70000000`, 16 MB, `no-map`, label `rv32i_reserved`.
31. `petalinux-build` y **repackage** de BOOT.BIN vía PetaLinux
    (`petalinux-package --boot ...`). **Nunca hot-load del PDI**: el PLM del Versal
    lo rechaza con `0x03024001`.
32. Copiar `BOOT.BIN` + `image.ub` (o los artefactos de arranque) a la microSD.
    La transferencia a la placa es exclusivamente por microSD (sin SSH entrante).

## Fase 7 — validación dual en silicio

Consola serial: `picocom -b 115200 /dev/ttyUSB1` (8N1). Prompt objetivo:
`root@plnxte0950...:~#`.

33. Cross-compilar el firmware ARM de bring-up:
    `aarch64-linux-gnu-gcc -O2 -static rf-bringup.c -o rf-bringup`
    y copiarlo a la placa por microSD.
34. Ejecutar como root: `./rf-bringup` (o `./rf-bringup 0x70000000`).

El firmware ARM (`rf-bringup.c`):
- Mapea el SoC (`0x8000_0000`) y la DDR reservada (`0x70000000`) por `/dev/mem`.
- Mantiene el core RV32 en halt, carga `fw_rf` en la IMEM y lo verifica.
- Fija `DDR_BASE`, limpia el buffer y el IRQ sticky, y suelta el core.
- El RV32 programa el tono (`TONE_FTW=0`), habilita RX, espera 64 muestras,
  dispara el segundo maestro (que las vuelca a DDR), y hace el doorbell.
- El A72 espera el doorbell, lee las 64 muestras, calcula el checksum canónico
  (`rotl32(chk,1) ^ word`) y lo compara con el golden.

**Validación dual (criterio de PASS):**
1. El checksum leído de la DDR por el PS coincide con `0xB74940EB`.
2. El resultado se imprime por la consola serial:
   `PASS: RF DDC/DUC validado en silicio.  CHK=0xB74940EB (golden 0xB74940EB) N=64`

El checksum es bit-idéntico en los cuatro dominios: modelo Python, TB VHDL del
datapath aislado, TB VHDL del SoC completo (capa 4 de silicio), y el cálculo en C
del firmware ARM. Cualquier fallo del datapath en silicio rompe la constante de
régimen y el checksum de forma inmediata y observable.
