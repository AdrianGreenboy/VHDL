# ============================================================================
#  vivado_soc_spi.tcl  -  Proyecto Vivado del SoC RISC-V + IP SPI (TE0950)
#  Licencia: MIT
#
#  Uso (headless):
#     vivado -mode batch -source vivado_soc_spi.tcl
#
#  Crea el proyecto, agrega las fuentes (SoC v3 + IP SPI), instancia el
#  wrapper en un block design y deja la lista de pasos GUI (CIPS + NoC).
#  Correlo desde ~/spi_ip (carpeta plana con todos los .vhd y el .v).
# ============================================================================

# --- AJUSTA ESTO A TU PLACA -------------------------------------------------
set BOARD_REPO "/home/adrian/te0950_work/board_files"
set BOARD_PART "trenz.biz:te0950_23_1lse:part0:1.2"
set PROJ_NAME "rv32i_soc_spi"
set PROJ_DIR  "./vivado_proj_spi"
set RTL_DIR   "."
# ---------------------------------------------------------------------------

set_param board.repoPaths $BOARD_REPO

create_project $PROJ_NAME $PROJ_DIR -force
set_property board_part $BOARD_PART [current_project]

# fuentes: SoC v3 + IP SPI
set rtl_files {
  riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd
  csr.vhd dp_ram.vhd cpu_pipeline.vhd dma_burst.vhd axil_soc.vhd
  spi_engine.vhd byte_fifo.vhd spi_dma.vhd spi_axi_top.vhd
  mem_subsys_spi.vhd soc_top_spi.vhd
}
foreach f $rtl_files {
  add_files -norecurse [file join $RTL_DIR $f]
}
set_property file_type {VHDL 2008} [get_files *.vhd]

# wrapper Verilog (Vivado no permite VHDL-2008 como top de Module Reference)
add_files -norecurse [file join $RTL_DIR soc_top_spi_wrap.v]
set_property top soc_top_spi_wrap [current_fileset]

# constraints de los pads SPI (LOCs por llenar del XDC de Trenz)
add_files -fileset constrs_1 -norecurse [file join $RTL_DIR spi_pmod.xdc]

update_compile_order -fileset sources_1

# --- Block design base ------------------------------------------------------
create_bd_design "bd_soc_spi"
create_bd_cell -type module -reference soc_top_spi_wrap u_soc

# La asociacion de reloj viene del X_INTERFACE_INFO/PARAMETER del wrapper.
# (El log del packager reporta 'm_axi' a secas, pero es engañoso: el valor
# efectivo del pin del BD trae las tres interfaces. Verificacion:)
puts "ASSOCIATED_BUSIF de u_soc/aclk: [get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins u_soc/aclk]]"

# pads SPI como puertos externos del BD desde ya
make_bd_pins_external [get_bd_pins u_soc/spi_sclk] [get_bd_pins u_soc/spi_mosi] \
                      [get_bd_pins u_soc/spi_miso] [get_bd_pins u_soc/spi_cs_n]
set_property name spi_sclk [get_bd_ports spi_sclk_0]
set_property name spi_mosi [get_bd_ports spi_mosi_0]
set_property name spi_miso [get_bd_ports spi_miso_0]
set_property name spi_cs_n [get_bd_ports spi_cs_n_0]

puts ""
puts "==================================================================="
puts " PROYECTO CREADO. Pasos restantes en la GUI (CIPS + NoC):"
puts "==================================================================="
puts " 1. Abre bd_soc_spi. Add IP -> CIPS. Run Block Automation (GUI)"
puts "    para CIPS + NoC + LPDDR4 (preset del board file de Trenz)."
puts " 2. CIPS, 'PS PL Interfaces': habilita M_AXI_LPD (32 bits) ->"
puts "    (SmartConnect) -> u_soc/s_axi, igual que en el SoC v3."
puts " 3. NoC (axi_noc): AHORA SON DOS maestros del PL:"
puts "      - General: NUM_SI += 2 (p.ej. S08_AXI y S09_AXI ademas de"
puts "        los del PS que dejo la automatizacion)."
puts "      - Conecta u_soc/m_axi     -> Sxx_AXI"
puts "      - Conecta u_soc/m_axi_spi -> Syy_AXI"
puts "      - Ambos maestros corren en el MISMO aclk del SoC, asi que"
puts "        pueden compartir la MISMA entrada de reloj del NoC:"
puts "        en la pestana de asociacion de relojes, asigna ambos SI"
puts "        al aclk que ya usa el SoC. (El NUM_CLKS extra del 10G fue"
puts "        porque ahi habia dominios distintos; aqui NO aplica.)"
puts "      - Connectivity: ambos SI -> MC Port de la LPDDR4."
puts " 4. u_soc/aclk al reloj del NoC/PS, u_soc/aresetn al Proc Sys Reset."
puts " 5. irq_out y spi_irq_out -> pl_ps_irq0/1 del CIPS."
puts " 6. Address Editor: base del esclavo (0xA000_0000/64K como en v3)"
puts "    y verifica que ambos SI vean la LPDDR4 en el mismo rango."
puts " 7. Llena los LOC de spi_pmod.xdc con pines del header del TE0950"
puts "    (del XDC/esquematico de Trenz; usa un banco HDIO si el header"
puts "    es 3.3V - los XPIO no soportan LVCMOS33)."
puts " 8. Validate, wrapper HDL como top, Generate Bitstream, Export XSA."
puts ""
puts " Bring-up sugerido: jumper fisico MOSI->MISO en el header, corre"
puts " spi_test via el flujo del PS (cargar IMEM + DDR_BASE + reset) y lee"
puts " DDR[0..3] = {2, 0x5A, 0xC3, 1337}. Empieza con CLKDIV=4 y baja a 1."
puts "==================================================================="

save_bd_design
puts "INFO: bd_soc_spi guardado. Proyecto en $PROJ_DIR"
