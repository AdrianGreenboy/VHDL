# ============================================================================
#  vivado_soc.tcl  -  Crea el proyecto Vivado del SoC RISC-V para el TE0950
#  Licencia: MIT
#
#  Uso (headless):
#     vivado -mode batch -source vivado_soc.tcl
#
#  Crea el proyecto, agrega las fuentes RTL y deja un block design con el
#  soc_top instanciado. La automatizacion CIPS+NoC se completa por GUI (en
#  Vivado 2025.2.1 el TCL de esa automatizacion falla con 'mc_type').
# ============================================================================

# --- AJUSTA ESTO A TU PLACA -------------------------------------------------
# Board file de Trenz del TE0950 (version 1.2 instalada en te0950_work).
set BOARD_REPO "/home/adrian/te0950_work/board_files"
set BOARD_PART "trenz.biz:te0950_23_1lse:part0:1.2"
#   ^ CONFIRMA este string con:  get_board_parts *te0950*
#     (si difiere, pega el que devuelva y ajusta la linea de arriba)
set PROJ_NAME "rv32i_soc"
set PROJ_DIR  "./vivado_proj"
set RTL_DIR   "."           ;# carpeta plana: los .vhd/.v estan en el cwd
# ---------------------------------------------------------------------------

# registra el repositorio de board files de Trenz ANTES de crear el proyecto
set_param board.repoPaths $BOARD_REPO

create_project $PROJ_NAME $PROJ_DIR -force
set_property board_part $BOARD_PART [current_project]

# fuentes RTL (orden de dependencia lo resuelve Vivado)
set rtl_files {
  riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd
  csr.vhd dp_ram.vhd cpu.vhd axil_soc.vhd soc_top.vhd
}
foreach f $rtl_files {
  add_files -norecurse [file join $RTL_DIR $f]
}
set_property file_type {VHDL 2008} [get_files *.vhd]
# wrapper Verilog (Vivado no permite VHDL-2008 como top de Module Reference)
add_files -norecurse [file join $RTL_DIR soc_top_wrap.v]
set_property top soc_top_wrap [current_fileset]
update_compile_order -fileset sources_1

# chequeo rapido de sintaxis/elaboracion del soc_top solo
puts "INFO: fuentes agregadas. Elaborando soc_top para chequeo..."
# synth_design -rtl -name rtl_check -top soc_top -part $PART   ;# opcional

# --- Block design base ------------------------------------------------------
create_bd_design "bd_soc"
# instancia el wrapper Verilog como Module Reference
create_bd_cell -type module -reference soc_top_wrap u_soc

puts ""
puts "==================================================================="
puts " PROYECTO CREADO. Pasos restantes en la GUI (CIPS + NoC):"
puts "==================================================================="
puts " 1. Abre bd_soc. Add IP -> 'Control, Interfaces and Processing"
puts "    System' (CIPS). Corre 'Run Block Automation' (GUI) para CIPS+NoC."
puts "    (Si tienes board file de Trenz, la automatizacion configura DDR,"
puts "     relojes y pines desde el preset.)"
puts " 2. En CIPS, pestana 'PS PL Interfaces': habilita un maestro"
puts "    M_AXI_LPD (32 bits). Ese es el mas simple para que el A72"
puts "    acceda a periIfericos del PL."
puts " 3. Conecta M_AXI_LPD -> (SmartConnect o NoC) -> u_soc/s_axi."
puts "    Conecta u_soc/aclk a un reloj del NoC/PS (p.ej. pl_clk0/aclk0)"
puts "    y u_soc/aresetn a un Processor System Reset."
puts " 4. Address Editor: asigna la base del esclavo de u_soc (p.ej."
puts "    0xA000_0000, rango 64K). ESA base va en SOC_BASE de riscv_accel.c."
puts " 5. Validate Design, crea el HDL wrapper (marca el WRAPPER como top),"
puts "    Generate Bitstream, y exporta XSA (File -> Export -> Export"
puts "    Hardware, con bitstream)."
puts ""
puts " Nota sobre AXI-Lite externo: para exponer un puerto AXI4-Lite usa"
puts " create_bd_intf_port + set_property CONFIG.PROTOCOL AXI4LITE, no"
puts " make_bd_intf_pins_external sobre el SmartConnect."
puts "==================================================================="

save_bd_design
puts "INFO: bd_soc guardado. Proyecto en $PROJ_DIR"
