# ============================================================================
#  vivado_soc_usart.tcl  -  Proyecto Vivado del SoC RISC-V + IP USART (TE0950)
#  Licencia: MIT
#
#  Uso (headless):
#     vivado -mode batch -source vivado_soc_usart.tcl
#
#  Crea el proyecto, agrega las fuentes (SoC v3 + IP USART), instancia el
#  wrapper en el block design y deja los pasos de CIPS + NoC. A diferencia
#  del flujo del SPI, las LECCIONES APRENDIDAS van codificadas en el proc
#  fix_noc de abajo: correlo en la consola Tcl DESPUES del Block Automation
#  en vez de pelear con la Connection Automation (que en el SPI ruteo m_axi
#  al S_AXI_LPD del PS con 150 segmentos psv_* y cero DDR).
#  Correlo desde ~/usart_ip (carpeta plana con .vhd, .v y .xdc; las fuentes
#  compartidas se toman de ~/rv32i y ~/spi_ip).
# ============================================================================

# --- AJUSTA ESTO A TU PLACA -------------------------------------------------
set BOARD_REPO "/home/adrian/te0950_work/board_files"
set BOARD_PART "trenz.biz:te0950_23_1lse:part0:1.2"
set PROJ_NAME "rv32i_soc_usart"
set PROJ_DIR  "./vivado_proj_usart"
set RV_DIR    "/home/adrian/rv32i"
set SPI_DIR   "/home/adrian/spi_ip"
set RTL_DIR   "."
# ---------------------------------------------------------------------------

set_param board.repoPaths $BOARD_REPO

create_project $PROJ_NAME $PROJ_DIR -force
set_property board_part $BOARD_PART [current_project]

# fuentes compartidas del SoC v3
foreach f {riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd
           csr.vhd dp_ram.vhd cpu_pipeline.vhd dma_burst.vhd axil_soc.vhd} {
  add_files -norecurse [file join $RV_DIR $f]
}
add_files -norecurse [file join $SPI_DIR byte_fifo.vhd]

# fuentes del IP USART + SoC extendido
foreach f {usart_engine.vhd usart_mmio.vhd usart_dma.vhd usart_axi_top.vhd
           mem_subsys_usart.vhd soc_top_usart.vhd} {
  add_files -norecurse [file join $RTL_DIR $f]
}
set_property file_type {VHDL 2008} [get_files *.vhd]

# wrapper Verilog (Vivado no permite VHDL-2008 como top de Module Reference)
add_files -norecurse [file join $RTL_DIR soc_top_usart_wrap.v]
set_property top soc_top_usart_wrap [current_fileset]

# constraints de los pads USART (CRUVI LS, pines heredados del SPI)
add_files -fileset constrs_1 -norecurse [file join $RTL_DIR usart_pins.xdc]

update_compile_order -fileset sources_1

# --- Block design base ------------------------------------------------------
create_bd_design "bd_soc_usart"
create_bd_cell -type module -reference soc_top_usart_wrap u_soc

# La asociacion de reloj viene del X_INTERFACE_INFO/PARAMETER del wrapper.
puts "ASSOCIATED_BUSIF de u_soc/aclk: [get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins u_soc/aclk]]"

# pads USART como puertos externos del BD desde ya (usart_txd es inout: el
# IOBUF vive dentro del wrapper)
make_bd_pins_external [get_bd_pins u_soc/usart_rxd] [get_bd_pins u_soc/usart_txd] \
                      [get_bd_pins u_soc/usart_cts_n] [get_bd_pins u_soc/usart_rts_n]
set_property name usart_rxd   [get_bd_ports usart_rxd_0]
set_property name usart_txd   [get_bd_ports usart_txd_0]
set_property name usart_cts_n [get_bd_ports usart_cts_n_0]
set_property name usart_rts_n [get_bd_ports usart_rts_n_0]

# ============================================================================
#  fix_noc: correr en la consola Tcl DESPUES del Block Automation de CIPS.
#  Codifica el estado final bueno del SPI: NUM_SI=8 / NUM_CLKS=7, los dos
#  maestros del PL en S06/S07 compartiendo aclk6 (MISMO dominio, pl0_ref_clk;
#  NO agregar relojes extra), reloj/reset del SoC y las dos IRQs.
#  AJUSTA LOS INDICES si tu Block Automation dejo un conteo distinto de SI
#  (audita antes con bd_review.tcl: los S00..S05 del PS deben quedar como
#  los dejo la automatizacion).
# ============================================================================
proc fix_noc {} {
  set noc [get_bd_cells axi_noc_0]

  # dos SI mas para los maestros del PL + una entrada de reloj compartida
  set_property CONFIG.NUM_SI   8 $noc
  set_property CONFIG.NUM_CLKS 7 $noc

  connect_bd_intf_net [get_bd_intf_pins u_soc/m_axi]       [get_bd_intf_pins axi_noc_0/S06_AXI]
  connect_bd_intf_net [get_bd_intf_pins u_soc/m_axi_usart] [get_bd_intf_pins axi_noc_0/S07_AXI]

  # ambos SI del PL al MISMO aclk6 (dominio unico: pl0_ref_clk del CIPS)
  set_property CONFIG.ASSOCIATED_BUSIF {S06_AXI:S07_AXI} [get_bd_pins axi_noc_0/aclk6]
  connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axi_noc_0/aclk6] \
                 [get_bd_pins u_soc/aclk]

  # conectividad de ambos SI al MC de la LPDDR4
  set_property CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500}}} \
      [get_bd_intf_pins axi_noc_0/S06_AXI]
  set_property CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500}}} \
      [get_bd_intf_pins axi_noc_0/S07_AXI]

  # reset: pl0_resetn -> proc_sys_reset -> aresetn del SoC
  if {[get_bd_cells -quiet rst_pl0] eq ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_pl0
    connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins rst_pl0/slowest_sync_clk]
    connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn]  [get_bd_pins rst_pl0/ext_reset_in]
  }
  connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins u_soc/aresetn]

  # IRQs hacia el PS
  connect_bd_net [get_bd_pins u_soc/irq_out]       [get_bd_pins versal_cips_0/pl_ps_irq0]
  connect_bd_net [get_bd_pins u_soc/usart_irq_out] [get_bd_pins versal_cips_0/pl_ps_irq1]

  puts "fix_noc aplicado. Audita con: source bd_review.tcl"
}

puts ""
puts "==================================================================="
puts " PROYECTO CREADO. Pasos restantes:"
puts "==================================================================="
puts " 1. Abre bd_soc_usart. Add IP -> CIPS. Run Block Automation"
puts "    (preset del board de Trenz: CIPS + axi_noc + LPDDR4)."
puts "    NO corras Connection Automation para los m_axi del PL."
puts " 2. CIPS, 'PS PL Interfaces': habilita M_AXI_LPD (32 bits) y"
puts "    pl_ps_irq0/1; pl0_ref_clk a 100 MHz."
puts " 3. En la consola Tcl:  fix_noc"
puts "    (ajusta indices S06/S07/aclk6 si tu automation dejo otro conteo)"
puts " 4. M_AXI_LPD -> SmartConnect -> u_soc/s_axi. Address Editor:"
puts "    esclavo en 0x8000_0000 / 64K (ventana baja del M_AXI_LPD, la"
puts "    leccion del SPI: NO 0xA000_0000) y ambos SI viendo DDR_LOW0."
puts " 5. Audita: source bd_review.tcl  (busca psv_* fantasma, noc_clk_gen"
puts "    sim-only o resets fantasma: si aparecen, la automation ayudo"
puts "    de mas)."
puts " 6. Validate, wrapper HDL del BD como top, Generate Bitstream."
puts " 7. write_hw_platform -fixed -include_bit -force"
puts "        -file ~/usart_ip/rv32i_soc_usart.xsa"
puts "==================================================================="

save_bd_design
puts "INFO: bd_soc_usart guardado. Proyecto en $PROJ_DIR"
