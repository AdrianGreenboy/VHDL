# bd_review.tcl - Dumps the complete state of the block design to bd_report.txt
# (cells, nets, NoC config, address map, clock/reset tracing, validate).
# Run in the Vivado Tcl Console with the BD open. Invaluable when Connection
# Automation has "helped" you -- see README, Troubleshooting.
set f [open bd_report.txt w]
puts $f "==================== CELLS ===================="
foreach c [get_bd_cells -hierarchical] { catch { puts $f "$c  ([get_property VLNV $c])" } }
puts $f "\n==================== EXTERNAL PORTS ===================="
foreach p [get_bd_ports]      { catch { puts $f "$p  dir=[get_property DIR $p]" } }
foreach p [get_bd_intf_ports] { catch { puts $f "$p  ([get_property VLNV $p]) mode=[get_property MODE $p]" } }
puts $f "\n==================== INTERFACE NETS ===================="
foreach n [get_bd_intf_nets] {
  puts $f "$n"
  puts $f "    connects: [get_bd_intf_pins -of_objects $n -quiet] [get_bd_intf_ports -of_objects $n -quiet]"
}
puts $f "\n==================== NETS ===================="
foreach n [get_bd_nets] {
  puts $f "$n"
  puts $f "    connects: [get_bd_pins -of_objects $n -quiet] [get_bd_ports -of_objects $n -quiet]"
}
puts $f "\n==================== NOC CONFIG ===================="
set noc [get_bd_cells -quiet axi_noc_0]
if {$noc ne ""} {
  foreach prop {CONFIG.NUM_SI CONFIG.NUM_MI CONFIG.NUM_CLKS CONFIG.NUM_MC} {
    catch { puts $f "$prop = [get_property $prop $noc]" } }
  foreach sp [get_bd_intf_pins -quiet $noc/S*_AXI] {
    catch { puts $f "$sp CONNECTIONS = [get_property CONFIG.CONNECTIONS $sp]" } }
  foreach cp [get_bd_pins -quiet $noc/aclk*] {
    catch { puts $f "$cp ASSOCIATED_BUSIF = [get_property CONFIG.ASSOCIATED_BUSIF $cp]" } }
}
puts $f "\n==================== ADDRESS MAP ===================="
foreach s [get_bd_addr_segs -quiet] {
  catch { puts $f "$s  offset=[get_property OFFSET $s]  range=[get_property RANGE $s]" } }
puts $f "\n==================== VALIDATE ===================="
if {[catch { validate_bd_design } verr]} { puts $f "VALIDATE FAILED:\n$verr" } else { puts $f "VALIDATE OK" }
close $f
puts "Report written to [pwd]/bd_report.txt"
