# Vuelca el estado completo del BD a bd_report.txt para revision
set f [open bd_report.txt w]

puts $f "==================== CELDAS ===================="
foreach c [get_bd_cells -hierarchical] {
  catch { puts $f "$c  ([get_property VLNV $c])" }
}

puts $f "\n==================== PUERTOS EXTERNOS ===================="
foreach p [get_bd_ports] {
  catch { puts $f "$p  dir=[get_property DIR $p]" }
}
foreach p [get_bd_intf_ports] {
  catch { puts $f "$p  (intf: [get_property VLNV $p]) mode=[get_property MODE $p]" }
}

puts $f "\n==================== NETS DE INTERFAZ ===================="
foreach n [get_bd_intf_nets] {
  set pins [get_bd_intf_pins -of_objects $n -quiet]
  set prts [get_bd_intf_ports -of_objects $n -quiet]
  puts $f "$n"
  puts $f "    conecta: $pins $prts"
}

puts $f "\n==================== NETS (senales sueltas) ===================="
foreach n [get_bd_nets] {
  set pins [get_bd_pins -of_objects $n -quiet]
  set prts [get_bd_ports -of_objects $n -quiet]
  puts $f "$n"
  puts $f "    conecta: $pins $prts"
}

puts $f "\n==================== CONFIG DEL NOC ===================="
set noc [get_bd_cells -quiet axi_noc_0]
if {$noc ne ""} {
  foreach prop {CONFIG.NUM_SI CONFIG.NUM_MI CONFIG.NUM_CLKS CONFIG.NUM_MC \
                CONFIG.NUM_MCP CONFIG.MC_BOARD_INTRF_EN} {
    catch { puts $f "$prop = [get_property $prop $noc]" }
  }
  puts $f "--- conectividad y reloj por SI ---"
  foreach sp [get_bd_intf_pins -quiet $noc/S*_AXI] {
    catch { puts $f "$sp CONNECTIONS = [get_property CONFIG.CONNECTIONS $sp]" }
  }
  foreach cp [get_bd_pins -quiet $noc/aclk*] {
    catch { puts $f "$cp ASSOCIATED_BUSIF = [get_property CONFIG.ASSOCIATED_BUSIF $cp]" }
  }
}

puts $f "\n==================== MAPA DE DIRECCIONES ===================="
foreach s [get_bd_addr_segs -quiet] {
  catch { puts $f "$s  offset=[get_property OFFSET $s]  range=[get_property RANGE $s]" }
}

puts $f "\n==================== RELOJ/RESET DE u_soc ===================="
foreach pn {aclk aresetn} {
  set pin [get_bd_pins -quiet u_soc/$pn]
  if {$pin ne ""} {
    set net [get_bd_nets -quiet -of_objects $pin]
    puts $f "u_soc/$pn -> net: $net"
    catch { puts $f "    otros pines de la net: [get_bd_pins -of_objects $net -quiet]" }
  }
}

puts $f "\n==================== VALIDATE ===================="
if {[catch { validate_bd_design } verr]} {
  puts $f "VALIDATE FALLO:\n$verr"
} else {
  puts $f "VALIDATE OK (revisa igual los criticos en la consola de Vivado)"
}

close $f
puts "Reporte escrito en [pwd]/bd_report.txt"
