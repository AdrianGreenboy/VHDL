# Checklist de transplante Vivado — SoC ADCS (TE0950 / Versal xcve2302)

Ejecutar en la consola Tcl de Vivado 2025.2.1, **un comando a la vez**, leyendo
cada respuesta antes del siguiente (lección USART #4: los bloques pegados
esconden fallos silenciosos). `source settings64.sh` primero.

## Pre-requisitos

- Proyecto Vivado del SPW existente y cerrado (`~/spw_ip/vivado_spw/spw_soc.xpr`).
- RTL del ADCS en `~/vhdl_repo/IP_Cores/ADCS/rtl/` (incluye `fp32_fma_xil.vhd`
  y `soc_top_master_adcs_wrap.v`).
- `bd_review.tcl` en `~/vhdl_repo/IP_Cores/USART/`.
- Fuentes del core RV32IM en `~/rv32i/` (referenciadas, no duplicadas).

## Fase 0 — clonar

1. `open_project ~/spw_ip/vivado_spw/spw_soc.xpr`
2. `save_project_as adcs_soc ~/adcs_ip/vivado_adcs -force`
3. `set_property source_mgmt_mode All [current_project]`
4. `reset_run synth_1` ; `reset_run impl_1`
5. Limpiar el incremental checkpoint (del RUN, no del arg de synth_design):
   `set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]` (y impl_1).
6. **Barrido de referencias remotas** — anota cualquier salida `REMOTA:` y
   resuélvela antes de seguir:
   `foreach f [get_files -all *] { if {[string match *spw_ip* $f]} { puts "REMOTA: $f" } }`

## Fase 1 — core FPO

7. `source ~/vhdl_repo/IP_Cores/ADCS/vivado/package_fpo.tcl`
   → confirma "fp_fma latencia efectiva: 8".

## Fase 2 — sustituir el IP en el BD

8. `open_bd_design [get_files bd_soc_usart.bd]`
9. Descubrir ANTES de borrar: `get_bd_cells`, `get_bd_intf_pins u_soc_spw/*`.
10. `delete_bd_objs [get_bd_cells u_soc_spw]`
11. Quitar fuentes SPW y añadir las del ADCS (ver `bd_adcs_steps.tcl` paso 3).
    **Verifica que NO entra `fp32_fma.vhd`** (la behav de 480b no es sintetizable),
    solo `fp32_fma_xil.vhd`.
12. `create_bd_cell -type module -reference soc_top_master_adcs_wrap u_soc_adcs`

## Fase 3 — AMPLIAR el NoC (la diferencia clave del ADCS)

El ADCS tiene DOS maestros: `m_axi` (dma_burst) y `a_axi` (maestro propio).
El NoC heredado tiene NUM_SI=7 (S06 = maestro del SPW). Hay que añadir S07.

13. `set_property -dict [list CONFIG.NUM_SI {8} CONFIG.NUM_CLKS {8}] [get_bd_cells axi_noc_0]`
14. S07 a la DDR: `set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500}}}] [get_bd_intf_pins axi_noc_0/S07_AXI]`
15. aclk7 asociada a S07: `set_property -dict [list CONFIG.ASSOCIATED_BUSIF {S07_AXI}] [get_bd_pins axi_noc_0/aclk7]`

## Fase 4 — reconexiones (por pin de origen, una a una)

16. clk/reset a `u_soc_adcs/aclk` y `/aresetn`.
17. `axi_smc/M00_AXI` → `u_soc_adcs/s_axi`.
18. `u_soc_adcs/m_axi` → `axi_noc_0/S06_AXI` (maestro dma_burst).
19. `u_soc_adcs/a_axi` → `axi_noc_0/S07_AXI` (maestro ADCS).
20. `pl0_ref_clk` → `axi_noc_0/aclk6` **y** `axi_noc_0/aclk7` (ambos maestros
    del PL corren a pl0_ref_clk).
21. **Verifica la asociación** (lección #5): `aclk6`→S06, `aclk7`→S07, sin cruces:
    `get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]` (y aclk7).
22. `u_soc_adcs/irq_out` → `versal_cips_0/pl_ps_irq0`.
23. `get_bd_ports` — el ADCS v1 no tiene pads; no crear puertos nuevos.

## Fase 5 — address map (explícito, AMBOS maestros a la DDR)

24. m_axi (S06) → DDR: `assign_bd_address -target_address_space /u_soc_adcs/m_axi [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force`
25. a_axi (S07) → MISMA DDR: `assign_bd_address -target_address_space /u_soc_adcs/a_axi [get_bd_addr_segs axi_noc_0/S07_AXI/C0_DDR_LOW0] -force`
26. esclavo del PS: `assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD [get_bd_addr_segs u_soc_adcs/s_axi/reg0] -offset 0x80000000 -range 64K -force`

## Fase 6 — auditoría ANTES de gastar síntesis

27. `validate_bd_design` (dice OK aunque esté mal → auditar igual).
28. `source ~/vhdl_repo/IP_Cores/USART/bd_review.tcl`
29. **Revisa `bd_report.txt`**: confirma NUM_SI=8, S07 CONNECTIONS con MC_0,
    aclk7→S07, y que AMBOS S06 y S07 mapean a C0_DDR_LOW0. Este es el punto
    donde el ADCS difiere del resto de la familia — verifícalo con cuidado.

## Fase 7 — top y síntesis

30. `set_property top bd_soc_usart_wrapper [current_fileset]`
31. `save_bd_design`
32. Síntesis: `source ~/vhdl_repo/IP_Cores/ADCS/vivado/run_synth_adcs.tcl`
    (verifica que no queda `fp32_fma.vhd` behav ni fifos ajenos).
33. Implementación: `source ~/vhdl_repo/IP_Cores/ADCS/vivado/run_impl_adcs.tcl`
    → confirma WNS ≥ 0 y DRC sin críticos, exporta `adcs_soc.xsa`.

## Riesgos honestos a vigilar

- **fp_fma a 240 MHz**: el FMA con C_Latency=8 debería cerrar, pero es la ruta
  crítica probable. Si WNS<0, revisar el `dbg_vec` (ya registrado) y considerar
  subir la latencia del core (el interlock tolera hasta ~14 sin cambiar RTL).
- **Cruce de 4 KB en el maestro del ADCS**: hoy el `axi_dma_engine` es
  single-beat (arlen=0), así que no cruza fronteras de 4 KB. Si algún día se
  optimiza a bursts, aplica la lección del cruce de 4 KB (dividir en la
  frontera de página o el NoC rechaza con PMC EAM ERR).
- **Dos maestros al mismo MC**: S06 y S07 comparten MC_0. El bandwidth pedido
  (500+500) cabe holgado en la LPDDR4, pero si hay contención, el reporte
  (m_axi) y los datos (a_axi) se serializan — no es un bug, solo latencia.
