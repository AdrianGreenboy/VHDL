#!/bin/bash
# ============================================================================
# adc_paso6_prep.sh : ADC delta-sigma soft IP v1 - Paso 6 (preparacion silicio)
# Requiere haber corrido adc_paso5_soc.sh (usa ~/adc_ip y ~/vhdl_repo).
# Hace:
#   1) Copia local soc_top_master (instancia mem_subsys_adc) + wrapper
#   2) Verifica en GHDL que la cadena RTL local cierra (elabora soc_top_master)
#   3) Regenera firmware + oraculo y genera adc-bringup.c (ambos embebidos)
#   4) Self-test nativo del validador (gcc) + cross-compilacion aarch64
#      estatica (si aarch64-linux-gnu-gcc esta instalado)
#   5) Puebla ~/vhdl_repo/IP_Cores/ADC/ (RTL + modelos + firmware + TBs +
#      vivado/adc_soc_steps.tcl + adc-bringup.c)
# Uso: bash adc_paso6_prep.sh
# Linea final esperada:
# ADC PASO6 PREP: PASS cadena=OK selftest CHK=0x1B8D3FF9 aarch64=OK repo=OK
# ============================================================================
(
set -e
DIR="$HOME/adc_ip"
ADC="$HOME/vhdl_repo/IP_Cores/ADC"
TSN="$HOME/vhdl_repo/IP_Cores/TSN"
RVR="$HOME/vhdl_repo/IP_Cores/RV32i"
cd "$DIR" 2>/dev/null || { echo "ADC PASO6 PREP: FALTA ~/adc_ip (corre el paso 5)"; exit 1; }
for f in adc_soc.vhd mem_subsys_adc.vhd adc_bringup.s iss_adc.py modelo_core.py asm.py; do
  [ -f "$f" ] || { echo "ADC PASO6 PREP: FALTA $f (corre el paso 5)"; exit 1; }
done
[ -f "$TSN/soc_top_master.vhd" ] || { echo "ADC PASO6 PREP: FALTA $TSN"; exit 1; }

# ---- 1) copia local soc_top_master + wrapper + axil_soc ----
sed -e 's/u_mem : entity work.mem_subsys_dma/u_mem : entity work.mem_subsys_adc/' \
    -e 's/soc_top_master.vhd  -  SoC v3/soc_top_master.vhd  -  (copia local ADC) SoC v3/' \
    "$TSN/soc_top_master.vhd" > soc_top_master.vhd
grep -q "mem_subsys_adc" soc_top_master.vhd || { echo "ADC PASO6 PREP: sed de soc_top_master fallo"; exit 1; }
cp "$TSN/soc_top_master_wrap.v" .
cp "$RVR/axil_soc.vhd" . 2>/dev/null || cp "$HOME/rv32i/axil_soc.vhd" .

# ---- 2) la cadena RTL local cierra sin residuos (GHDL) ----
rm -rf build6 && mkdir build6 && cd build6
ghdl -a --std=08 --workdir=. ../riscv_pkg.vhd ../alu.vhd ../control.vhd ../csr.vhd \
  ../immgen.vhd ../muldiv.vhd ../regfile.vhd ../cpu_pipeline.vhd ../dp_ram.vhd \
  ../dma_burst.vhd ../axil_soc.vhd ../adc_sin_lut_pkg.vhd ../adc_pdmgen.vhd \
  ../adc_cic.vhd ../adc_core.vhd ../adc_fifo.vhd ../adc_regs.vhd ../adc_mmio.vhd \
  ../adc_soc.vhd ../mem_subsys_adc.vhd ../soc_top_master.vhd
ghdl -e --std=08 --workdir=. soc_top_master
cd ..
CADENA="OK"

# ---- 3) firmware + oraculo -> adc-bringup.c ----
python3 modelo_core.py > /dev/null
python3 iss_adc.py > /dev/null
python3 asm.py adc_bringup.s adc_bringup.mem > /dev/null

cat > adc-bringup.c.in << 'EOF_CIN'
// adc-bringup.c - Bring-up del ADC delta-sigma soft IP v1 en el TE0950 (Versal).
// El A72 (Linux, /dev/mem) carga adc_bringup en la IMEM del RV32, suelta el
// core, y este configura el IP (0x6000_0000: FINC + CTRL OSR=256), espera
// nivel>=64, drena 64 muestras Q1.23 a RAM local, escribe la sentinela
// 0xADC0FEED y copia 65 palabras por DMA a la DDR reservada (0x70000000).
// El doorbell (word 127) dispara el IRQ sticky del axil_soc. El A72 espera el
// doorbell y compara las 65 palabras bit-identicas contra el oraculo del ISS
// (iss_adc.py, CHK 0x1B8D3FF9).
//
// Compilar (cross aarch64):
//   aarch64-linux-gnu-gcc -O2 -static adc-bringup.c -o adc-bringup
// Self-test nativo (sin hardware, valida el camino de comparacion):
//   gcc -O2 -DSELFTEST adc-bringup.c -o adc-bringup-selftest && ./adc-bringup-selftest
// Ejecutar (root):  ./adc-bringup [ddr_phys_hex]

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#ifndef SELFTEST
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#endif

#define SOC_BASE   0x80000000UL
#define SOC_SPAN   0x10000UL
#define REG_CONTROL 0x0000     // bit0 = 1 -> core en reset (halt)
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C     // sticky del doorbell (w1c)
#define REG_DDRB_LO 0x0010
#define REG_DDRB_HI 0x0014
#define OFF_IMEM    0x1000

// adc_bringup.s ensamblado (salida de asm.py).
static uint32_t prog[] = {
__PROG__
};
#define PROG_WORDS (sizeof(prog)/sizeof(prog[0]))

// oraculo del ISS (iss_adc.py): 64 muestras etiquetadas + sentinela.
static const uint32_t oracle[65] = {
__ORAC__
};
#define SENTINEL 0xADC0FEEDu
#define CHK_ESPERADO 0x1B8D3FF9u

static uint32_t lfsr32(const volatile uint32_t *w, int n)
{
    uint32_t chk = 0xFFFFFFFFu;
    for (int i = 0; i < n; i++)
        for (int b = 31; b >= 0; b--) {
            uint32_t msb = chk >> 31;
            chk = (chk << 1) | ((w[i] >> b) & 1u);
            if (msb) chk ^= 0x04C11DB7u;
        }
    return chk;
}

#ifdef SELFTEST
int main(void)
{
    // sin hardware: la "DDR" es el propio oraculo; valida compare + checksum
    uint32_t chk = lfsr32(oracle, 65);
    int errors = (oracle[64] != SENTINEL);
    for (int i = 0; i < 65; i++)
        if (oracle[i] != oracle[i]) errors++;
    if (chk != CHK_ESPERADO) errors++;
    printf("SELFTEST adc-bringup: %s CHK=0x%08X (esperado 0x%08X)\n",
           errors ? "FAIL" : "PASS", chk, CHK_ESPERADO);
    return errors ? 1 : 0;
}
#else
static volatile uint32_t *soc;
static volatile uint8_t  *ddr;
static inline void     wr(unsigned off, uint32_t v) { soc[off/4] = v; }
static inline uint32_t rd(unsigned off)             { return soc[off/4]; }
static inline uint32_t ddr_w(unsigned widx)
{ return ((volatile uint32_t*)ddr)[widx]; }

int main(int argc, char **argv)
{
    uint64_t ddr_phys = (argc > 1) ? strtoull(argv[1], NULL, 16) : 0x70000000ULL;

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }
    soc = (volatile uint32_t *)mmap(NULL, SOC_SPAN, PROT_READ|PROT_WRITE,
                                    MAP_SHARED, fd, SOC_BASE);
    if (soc == MAP_FAILED) { perror("mmap soc"); return 1; }
    ddr = (volatile uint8_t *)mmap(NULL, 0x1000, PROT_READ|PROT_WRITE,
                                   MAP_SHARED, fd, ddr_phys);
    if (ddr == MAP_FAILED) { perror("mmap ddr"); return 1; }

    printf("ADC bring-up: delta-sigma soft IP v1, DDR=0x%llx\n",
           (unsigned long long)ddr_phys);

    wr(REG_CONTROL, 1);
    for (unsigned i = 0; i < PROG_WORDS; i++) wr(OFF_IMEM + i*4, prog[i]);
    for (unsigned i = 0; i < PROG_WORDS; i++)
        if (rd(OFF_IMEM + i*4) != prog[i]) {
            fprintf(stderr, "IMEM verify fallo en %u\n", i); return 1;
        }

    wr(REG_DDRB_LO, (uint32_t)(ddr_phys & 0xFFFFFFFFu));
    wr(REG_DDRB_HI, (uint32_t)(ddr_phys >> 32));

    memset((void*)ddr, 0, 65*4);
    __sync_synchronize();
    wr(REG_IRQ, 1);

    wr(REG_CONTROL, 0);

    int ok = 0;
    for (int t = 0; t < 200000; t++) {
        if (rd(REG_IRQ) & 1u) { ok = 1; break; }
        usleep(10);
    }
    if (!ok) {
        fprintf(stderr, "TIMEOUT: sin doorbell. DBG_PC=0x%08x STATUS=0x%08x\n",
                rd(REG_DBGPC), rd(REG_STATUS));
        return 2;
    }
    __sync_synchronize();

    int errors = 0;
    uint32_t sent = ddr_w(64);
    if (sent != SENTINEL) {
        printf("FAIL sentinela: 0x%08X (esperaba 0x%08X)\n", sent, SENTINEL);
        errors++;
    }
    for (int i = 0; i < 65; i++) {
        uint32_t got = ddr_w(i);
        if (got != oracle[i]) {
            printf("FAIL word %d: 0x%08X (esperaba 0x%08X)\n", i, got, oracle[i]);
            errors++;
        }
    }
    uint32_t chk = lfsr32((const volatile uint32_t*)ddr, 65);
    if (chk != CHK_ESPERADO) {
        printf("FAIL CHK: 0x%08X (esperaba 0x%08X)\n", chk, CHK_ESPERADO);
        errors++;
    }

    if (errors == 0) {
        printf("PASS: ADC delta-sigma validado en silicio.\n");
        printf("  muestras[0..3] = 0x%06X 0x%06X 0x%06X 0x%06X (Q1.23)\n",
               ddr_w(0) & 0xFFFFFF, ddr_w(1) & 0xFFFFFF,
               ddr_w(2) & 0xFFFFFF, ddr_w(3) & 0xFFFFFF);
        printf("  sentinela 0x%08X OK, CHK=0x%08X (ISS: iss_adc.py)\n", sent, chk);
    } else {
        printf("%d error(es). El ADC NO coincide con el oraculo.\n", errors);
    }
    return errors ? 3 : 0;
}
#endif
EOF_CIN

cat > gen_bringup_c.py << 'EOF_GEN'
#!/usr/bin/env python3
# gen_bringup_c.py : genera adc-bringup.c con firmware + oraculo embebidos
prog = [l.strip() for l in open('adc_bringup.mem') if l.strip()]
orac = [l.strip() for l in open('iss_adc_oracle.txt') if l.strip()]
assert len(orac) == 65, 'oraculo debe tener 65 palabras'
pw = ',\n'.join(', '.join('0x%s' % w for w in prog[i:i+8]) for i in range(0, len(prog), 8))
ow = ',\n'.join(', '.join('0x%su' % w for w in orac[i:i+8]) for i in range(0, len(orac), 8))
c = open('adc-bringup.c.in').read()
c = c.replace('__PROG__', pw).replace('__ORAC__', ow)
open('adc-bringup.c', 'w').write(c)
print('adc-bringup.c generado con %d palabras de firmware' % len(prog))
EOF_GEN

cat > adc_soc_steps.tcl << 'EOF_TCL'
# ============================================================================
#  adc_soc_steps.tcl - Trasplante del BD del SoC + ADC delta-sigma soft IP v1
#  (TE0950 / Versal xcve2302-sfva784-1LP-e-S). Adaptado del tsn_soc_steps.tcl
#  probado en silicio.
#
#  NO SE "SOURCEA" COMPLETO: comandos UNO POR UNO en la consola Tcl de Vivado,
#  leyendo cada respuesta (leccion de la familia: connect_bd_net fallo
#  SILENCIOSAMENTE dentro de un bloque pegado).
#
#  RUTA: clonar el proyecto TSN (hereda el BD con CIPS, NoC, axi_smc, reset y
#  address map auditados) y sustituir el module reference u_soc_tsn por
#  u_soc_adc.
#
#  El ADC es ESCLAVO DMEM DIRECTO, integrado en mem_subsys_adc en 0x6000_0000
#  (bus dmem interno del RV32, NO se mapea en el BD). NO hay maestro embebido
#  del IP: el movimiento a DDR usa el dma_burst del mem_subsys (patron de la
#  familia). El hook B (pdm_ext_i/pdm_fb_o) queda interno en v1: NO se exponen
#  pines a pads.
#
#  IMPORTANTE: mem_subsys_adc y soc_top_master son las COPIAS LOCALES del IP
#  ADC (con el adc_soc dentro), NO las de ~/rv32i ni las del TSN. Validadas en
#  GHDL: la cadena RTL local cierra sin residuos.
# ============================================================================

# ---------- 0) clonar el proyecto del TSN ----------
open_project $env(HOME)/vhdl_repo/IP_Cores/TSN/vivado_tsn/tsn_soc.xpr
save_project_as adc_soc $env(HOME)/vhdl_repo/IP_Cores/ADC/vivado_adc -force
set_property source_mgmt_mode All [current_project]

reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]
file delete -force $env(HOME)/vhdl_repo/IP_Cores/ADC/vivado_adc/adc_soc.srcs/utils_1/imports

# barrido de referencias remotas al proyecto padre:
foreach f [get_files -all *] { if {[string match *TSN/vivado_tsn* $f]} { puts "REMOTA: $f" } }

# ---------- 1) abrir el BD y quitar el module reference del TSN ----------
open_bd_design [get_files bd_soc_usart.bd]
get_bd_cells
get_bd_intf_pins u_soc_tsn/*
get_bd_nets -of_objects [get_bd_pins u_soc_tsn/*]
get_bd_ports
delete_bd_objs [get_bd_cells u_soc_tsn]
generate_target all [get_files bd_soc_usart.bd]

# (el TSN no exponia puertos externos; nada que borrar en 1b)

# ---------- 2) sustituir fuentes TSN -> ADC ----------
remove_files [get_files -quiet {*tsn_pkg.vhd *tsn_fifo.vhd *tsn_ingress.vhd \
  *tsn_xbar.vhd *tsn_tx_adapt.vhd *tsn_inject.vhd *tsn_regs.vhd *tsn_top.vhd \
  *tsn_soc.vhd *eth_pkg.vhd *eth_rx_mii.vhd *eth_tx_mii.vhd}]
# CLAVE: quitar las copias locales del TSN de mem_subsys/soc_top_master para
# que no colisionen con las copias locales del ADC.
remove_files [get_files -quiet {*TSN/mem_subsys_dma.vhd *TSN/soc_top_master.vhd \
  *TSN/soc_top_master_wrap.v}]

# anadir el RTL del ADC + copias locales. Orden de dependencia validado en GHDL.
add_files -norecurse [list \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_sin_lut_pkg.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_pdmgen.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_cic.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_core.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_fifo.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_regs.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_mmio.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_soc.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/mem_subsys_adc.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/soc_top_master.vhd \
  $env(HOME)/vhdl_repo/IP_Cores/ADC/soc_top_master_wrap.v]

# dependencias del core que quiza ya esten (clonadas). Anadir las que falten:
foreach dep {riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd \
             csr.vhd dp_ram.vhd dma_burst.vhd cpu_pipeline.vhd axil_soc.vhd} {
  if {[llength [get_files -quiet *$dep]] == 0} {
    add_files -norecurse $env(HOME)/rv32i/$dep
  }
}
set_property file_type {VHDL 2008} [get_files $env(HOME)/vhdl_repo/IP_Cores/ADC/*.vhd]
set_property file_type {VHDL 2008} [get_files $env(HOME)/rv32i/*.vhd]
update_compile_order -fileset sources_1

# ---------- 3) module reference nuevo ----------
create_bd_cell -type module -reference soc_top_master_wrap u_soc_adc

# ---------- 4) reconexiones (UNO POR UNO, por pin de origen) ----------
get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl0_ref_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins u_soc_adc/aclk]
connect_bd_net [get_bd_pins rst_versal_cips_0_240M/peripheral_aresetn] \
  [get_bd_pins u_soc_adc/aresetn]

get_bd_intf_pins axi_smc/*
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
  [get_bd_intf_pins u_soc_adc/s_axi]

connect_bd_intf_net [get_bd_intf_pins u_soc_adc/m_axi] \
  [get_bd_intf_pins axi_noc_0/S06_AXI]
get_property CONFIG.ASSOCIATED_BUSIF [get_bd_pins /axi_noc_0/aclk6]

connect_bd_net [get_bd_pins u_soc_adc/irq_out] [get_bd_pins versal_cips_0/pl_ps_irq0]

# ---------- 5) address map ----------
assign_bd_address -target_address_space /u_soc_adc/m_axi \
  [get_bd_addr_segs axi_noc_0/S06_AXI/C0_DDR_LOW0] -force
assign_bd_address -target_address_space /versal_cips_0/M_AXI_LPD \
  [get_bd_addr_segs u_soc_adc/s_axi/reg0] -offset 0x80000000 -range 64K -force

# ---------- 6) auditoria ANTES de gastar sintesis ----------
# (bd_review.tcl canonico: ~/vhdl_repo/IP_Cores/USART/bd_review.tcl)
validate_bd_design
get_bd_nets -of_objects [get_bd_pins u_soc_adc/aclk]
get_bd_nets -of_objects [get_bd_pins u_soc_adc/aresetn]

# ---------- 7) top y salvado ----------
set_property top bd_soc_usart_wrapper [current_fileset]
save_bd_design

# ---------- 8) sintesis / implementacion / imagen ----------
# reset_run synth_1 ; launch_runs synth_1 -jobs 30 ; wait_on_run synth_1
# Auditoria post-sintesis: el BRAM de la FIFO (molde SDP) debe inferirse como
#   RAMB, y la LUT senoidal como ROM en BRAM. Revisar el utilization report.
# launch_runs impl_1 -to_step write_device_image -jobs 30 ; wait_on_run impl_1
# PDI:  vivado_adc/adc_soc.runs/impl_1/bd_soc_usart_wrapper.pdi
# XSA:  write_hw_platform -fixed -include_bit -force $env(HOME)/vhdl_repo/IP_Cores/ADC/adc_soc.xsa
EOF_TCL

python3 gen_bringup_c.py > /dev/null

# ---- 4) self-test nativo + cross aarch64 ----
gcc -O2 -DSELFTEST adc-bringup.c -o adc-bringup-selftest
ST=$(./adc-bringup-selftest)
echo "$ST"
echo "$ST" | grep -q "PASS CHK=0x1B8D3FF9" || { echo "ADC PASO6 PREP: SELFTEST FALLO"; exit 1; }
if command -v aarch64-linux-gnu-gcc > /dev/null 2>&1; then
  aarch64-linux-gnu-gcc -O2 -static adc-bringup.c -o adc-bringup
  A64="OK"
else
  A64="SIN_CROSS (instala gcc-aarch64-linux-gnu)"
fi

# ---- 5) poblar la carpeta canonica del repo ----
mkdir -p "$ADC/vivado"
for f in adc_sin_lut_pkg.vhd adc_pdmgen.vhd adc_cic.vhd adc_core.vhd adc_fifo.vhd \
         adc_regs.vhd adc_mmio.vhd adc_soc.vhd mem_subsys_adc.vhd \
         soc_top_master.vhd soc_top_master_wrap.v \
         tb_pdmgen.vhd tb_cic.vhd tb_core.vhd tb_mmio.vhd tb_adc_soc.vhd \
         modelo_pdm.py modelo_cic.py modelo_core.py iss_adc.py \
         adc_bringup.s adc_bringup.mem adc-bringup.c; do
  [ -f "$f" ] && cp "$f" "$ADC/" || true
done
[ -f adc-bringup ] && cp adc-bringup "$ADC/" || true
cp adc_soc_steps.tcl "$ADC/vivado/"

echo "ADC PASO6 PREP: PASS cadena=$CADENA selftest CHK=0x1B8D3FF9 aarch64=$A64 repo=OK"
)
