# =============================================================================
#  package_fpo.tcl  -  Genera el core Floating-Point Operator (fp_fma) del IP
#  ADCS para sintesis en Vivado. Licencia: MIT
#
#  Config IDENTICA a la del proyecto de tesis (latencia validada en silicio):
#    Operation_Type = FMA (fused multiply-add, a*b + c)
#    A/Result precision = Single (binary32)
#    C_Mult_Usage = Full_Usage
#    Flow_Control = NonBlocking
#    C_Latency = 8   (== LAT_FMA del modelo behav; interlock NACC=16 lo cubre)
#    C_Rate = 1      (throughput 1 resultado/ciclo)
#
#  El FMA fusionado del FPO cumple IEEE-754 a media ULP con RNE + FTZ => firma
#  bit-exacta contra el modelo behav de GHDL (ver fp32_fma_xil.vhd). En v1 SOLO
#  se genera el FMA: el add del datapath se hace como fma(a,1.0,b) con este
#  mismo core, y el sqrt/div/addsub del SR-UKF quedan para la fase 2 (QR).
#
#  Uso (dentro del proyecto Vivado del SoC ADCS):
#    source package_fpo.tcl
#  Requiere PROJ_DIR definido o usa el directorio del proyecto actual.
# =============================================================================

if {![info exists PROJ_DIR]} {
    set PROJ_DIR [get_property DIRECTORY [current_project]]
}

# --- ejecutar comandos UNO A UNO (leccion Vivado: los bloques compuestos con
#     ; y puts se truncan en la consola y esconden fallos silenciosos) ---

create_ip -name floating_point -vendor xilinx.com -library ip \
    -module_name fp_fma -dir $PROJ_DIR

set_property CONFIG.Operation_Type {FMA}                 [get_ips fp_fma]
set_property CONFIG.A_Precision_Type {Single}            [get_ips fp_fma]
set_property CONFIG.Result_Precision_Type {Single}       [get_ips fp_fma]
set_property CONFIG.C_Mult_Usage {Full_Usage}            [get_ips fp_fma]
set_property CONFIG.Flow_Control {NonBlocking}           [get_ips fp_fma]
set_property CONFIG.C_Latency {8}                        [get_ips fp_fma]
set_property CONFIG.C_Rate {1}                           [get_ips fp_fma]

generate_target all [get_ips fp_fma]

# Verificacion: confirmar la latencia efectiva que reporta el core (puede
# diferir del pedido segun la plataforma; el interlock lo tolera, pero se
# documenta para el tag de silicio).
puts "fp_fma latencia efectiva: [get_property CONFIG.C_Latency [get_ips fp_fma]]"
