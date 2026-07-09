// ============================================================================
//  i2c_bringup.c - Bring-up de silicio del IP IIC (TE0950, PetaLinux, /dev/mem)
//  Licencia: MIT
//
//  Igual patron que usart_bringup.c: mapea el esclavo AXI4-Lite del SoC en
//  0x8000_0000 y la DDR reservada no-map (16 MB) en 0x7000_0000 fisica.
//  NOTA: esa DDR fisica en 0x7000_0000 NO tiene nada que ver con la region
//  0x7000_0000 del bus dmem interno del RV32 donde vive el IIC.
//
//  Flujo: halt del core -> DDR_BASE -> carga del programa (con parches de
//  SCLDIV/SADDR/CTRL en instrucciones addi separadas) -> limpia la DDR ->
//  suelta el core -> espera doorbell (DDR[3]=1337) -> verifica resultados.
//
//  Compilar en el target:   gcc -O2 -o i2c_bringup i2c_bringup.c
//  Ejecutar:                sudo ./i2c_bringup [scldiv]
//                           (scldiv opcional: 249=100k por default, 62=400k,
//                            24=1M; el programa corre en LOOP_INT)
// ============================================================================
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define SOC_PHYS   0x80000000UL   // esclavo axil_soc
#define SOC_SPAN   0x10000UL      // 64 KB
#define DDR_PHYS   0x70000000UL   // DDR reservada no-map (device tree)
#define DDR_SPAN   0x1000000UL    // 16 MB

// mapa del axil_soc
#define R_CONTROL   (0x0000/4)    // bit0 = halt del core
#define R_STATUS    (0x0004/4)
#define R_DBG_PC    (0x0008/4)
#define R_IRQ       (0x000C/4)
#define R_DDRBASE_L (0x0010/4)
#define R_DDRBASE_H (0x0014/4)
#define IMEM_WIN    (0x1000/4)

// programa i2c_test.s ensamblado (asm.py); parches en addi separadas
#define PROG_SCLDIV_IDX 4         // addi x5, x0, <scldiv>
#define PROG_SADDR_IDX  6         // addi x5, x0, <saddr>
#define PROG_CTRL_IDX   8         // addi x5, x0, <ctrl>
static uint32_t prog[] = {
  0x700000B7,
  0x40000137,
  0x00010A37,
  0x00040AB7,
  0x01800293,
  0x0050A423,
  0x02A00293,
  0x0050AA23,
  0x08700293,
  0x0050A023,
  0x15400293,
  0x0050A623,
  0x0D000FEF,
  0x05A00293,
  0x0050A623,
  0x0C400FEF,
  0x2C300293,
  0x0050A623,
  0x0B800FEF,
  0x0200A403,
  0x1FF47413,
  0x00802023,
  0x01C0A483,
  0x0FF4F493,
  0x00902223,
  0x01C0A483,
  0x0FF4F493,
  0x00902423,
  0x0A500293,
  0x0050AC23,
  0x15500293,
  0x0050A623,
  0x08000FEF,
  0x000012B7,
  0xE0028293,
  0x0050A623,
  0x07000FEF,
  0x0100A483,
  0x0FF4F493,
  0x00902823,
  0x16600293,
  0x0050A623,
  0x0040A303,
  0x014373B3,
  0xFE038CE3,
  0x015373B3,
  0x0123D393,
  0x00702A23,
  0x0000A223,
  0x000012B7,
  0x20028293,
  0x0050A623,
  0x03000FEF,
  0x53900293,
  0x00502623,
  0x00012023,
  0x00012223,
  0x00800293,
  0x00512423,
  0x00300293,
  0x00512623,
  0x01012303,
  0xFE031EE3,
  0x00000063,
  0x0040A303,
  0x014373B3,
  0xFE038CE3,
  0x0000A223,
  0x000F8067
};
#define PROG_LEN (sizeof(prog)/sizeof(prog[0]))

// parcha el inmediato de 12 bits de una instruccion I-type (addi)
static uint32_t patch_addi(uint32_t insn, uint32_t imm)
{
  return (insn & 0x000FFFFFu) | ((imm & 0xFFFu) << 20);
}

int main(int argc, char **argv)
{
  uint32_t scldiv = (argc > 1) ? (uint32_t)strtoul(argv[1], NULL, 0) : 249;
  uint32_t saddr  = 0x2A;
  uint32_t ctrl   = 0x87;          // EN | SEN | STRETCH_EN | LOOP_INT

  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd < 0) { perror("/dev/mem"); return 1; }

  volatile uint32_t *soc = mmap(NULL, SOC_SPAN, PROT_READ | PROT_WRITE,
                                MAP_SHARED, fd, SOC_PHYS);
  volatile uint32_t *ddr = mmap(NULL, DDR_SPAN, PROT_READ | PROT_WRITE,
                                MAP_SHARED, fd, DDR_PHYS);
  if (soc == MAP_FAILED || ddr == MAP_FAILED) { perror("mmap"); return 1; }

  printf("IIC bring-up: scldiv=%u saddr=0x%02X ctrl=0x%02X (loop_int)\n",
         scldiv, saddr, ctrl);

  // 1) halt del core y base de la DDR para el dma_burst
  soc[R_CONTROL]   = 1;
  soc[R_DDRBASE_L] = (uint32_t)DDR_PHYS;
  soc[R_DDRBASE_H] = 0;

  // 2) parches y carga del programa por la ventana IMEM
  prog[PROG_SCLDIV_IDX] = patch_addi(prog[PROG_SCLDIV_IDX], scldiv);
  prog[PROG_SADDR_IDX]  = patch_addi(prog[PROG_SADDR_IDX],  saddr);
  prog[PROG_CTRL_IDX]   = patch_addi(prog[PROG_CTRL_IDX],   ctrl);
  for (unsigned i = 0; i < PROG_LEN; i++)
    soc[IMEM_WIN + i] = prog[i];
  for (unsigned i = 0; i < PROG_LEN; i++)
    if (soc[IMEM_WIN + i] != prog[i]) {
      printf("FALLO: verificacion de IMEM en la palabra %u\n", i);
      return 1;
    }

  // 3) limpiar la zona de reporte y el doorbell
  for (unsigned i = 0; i < 8; i++) ddr[i] = 0;

  // 4) soltar el core
  soc[R_CONTROL] = 0;

  // 5) esperar el doorbell (DDR[3] = 1337)
  unsigned tmo = 0;
  while (ddr[3] != 1337) {
    usleep(1000);
    if (++tmo > 2000) {
      printf("TIMEOUT: sin doorbell; DBG_PC=0x%08X STAT=0x%08X\n",
             soc[R_DBG_PC], soc[R_STATUS]);
      return 1;
    }
  }
  printf("doorbell recibido (DDR[3]=1337) tras ~%u ms\n", tmo);

  // 6) verificar resultados
  struct { unsigned idx; uint32_t exp; const char *msg; } chk[] = {
    { 0, 0x02, "fase A: nivel SRX" },
    { 1, 0x5A, "fase A: byte0"     },
    { 2, 0xC3, "fase A: byte1"     },
    { 4, 0xA5, "fase B: MRD"       },
    { 5, 0x01, "fase C: NACK"      },
  };
  int pass = 1;
  for (unsigned i = 0; i < 5; i++) {
    uint32_t v = ddr[chk[i].idx];
    printf("  %-18s DDR[%u] = 0x%02X (esperado 0x%02X) %s\n",
           chk[i].msg, chk[i].idx, v, chk[i].exp,
           v == chk[i].exp ? "OK" : "FALLO");
    if (v != chk[i].exp) pass = 0;
  }
  printf(pass ? "== IIC SILICON PASS (loop_int) ==\n"
              : "== IIC SILICON FAIL ==\n");
  return pass ? 0 : 1;
}
