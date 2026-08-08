#==============================================================================
# Core 19 - PCS 64B/66B @ 25G
# Referencia de address map para el Block Design (SoC v3).
#
# NO pegar en bloque. Ejecutar comando por comando en la consola Tcl de Vivado,
# leyendo la respuesta de cada uno antes de seguir (regla dura del proyecto).
# Usa $env(HOME), nunca ~ (el tilde no se expande en Tcl de Vivado).
#
# Coordenadas SoC v3 confirmadas para Core 19:
#   AXI-Lite slave del banco PCS : 0x8000_0000, ventana 64K
#   DMA engine (mem_subsys_dma)  : 0x4000_0000
#   Buffer DDR (no-map)          : 0x7000_0000, 16 MB
#==============================================================================

# --- 0. Variables de ruta (ejecutar primero) --------------------------------
set REPO   $env(HOME)/vhdl_repo
set CORE   $REPO/IP_Cores/PCS_25G
puts "CORE dir: $CORE"

# --- 1. Auditar el mapa actual del BD ---------------------------------------
# Lista todas las asignaciones de direccion existentes. Leer la salida para
# confirmar que 0x8000_0000/64K esta libre antes de asignar el banco PCS.
#   assign_address_manual? NO. Primero mirar:
# get_bd_addr_segs
# report_bd_addr_map (si tu version lo soporta)

# --- 2. Verificar que el offset del banco PCS esta libre --------------------
# Espera: 0x80000000 no debe aparecer ocupado por otro core.
# get_bd_addr_segs -filter { OFFSET == 0x80000000 }

# --- 3. Asignar el AXI-Lite slave del banco PCS -----------------------------
# Sustituir <pcs_inst> por el nombre real de la instancia del core en el BD y
# <smc_master> por el master AXI (normalmente el SmartConnect del RV32i).
#
# assign_bd_address -offset 0x80000000 -range 64K \
#   [get_bd_addr_segs {<pcs_inst>/S_AXI/reg0}]

# --- 4. Confirmar la asignacion ---------------------------------------------
# validate_bd_design
# save_bd_design

# --- 5. Sweep de artefactos de referencia remota (tras clonar proyecto) -----
# Regla dura: tras clonar un proyecto Vivado, barrer referencias remotas.
# foreach f [get_files -all *] { puts $f }
#
# Y limpiar checkpoint incremental del run de sintesis:
# set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]

# --- 6. Capturar el BD a Tcl antes de transplantar --------------------------
# write_bd_tcl -force $CORE/vivado/bd_pcs_25g.tcl
# En el script generado, poner: set run_remote_bd_flow 0

puts "addr_map_core19.tcl cargado. Ejecutar los pasos comentados uno a uno."
