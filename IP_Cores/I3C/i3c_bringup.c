// ============================================================================
//  i3c_bringup.c - Bring-up de silicio del IP I3C (TE0950, PetaLinux, /dev/mem)
//  Licencia: MIT
//
//  Igual patron que i2c_bringup.c: mapea el esclavo AXI4-Lite del SoC en
//  0x8000_0000 y la DDR reservada no-map (16 MB) en 0x7000_0000 fisica.
//  NOTA: esa DDR fisica NO tiene nada que ver con la region 0x9000_0000 del
//  bus dmem interno del RV32 donde vive el I3C.
//
//  Flujo por escalon: halt del core -> DDR_BASE -> carga del programa (con
//  el parche de DIV_PP en su addi separada) -> limpia la DDR -> suelta el
//  core -> espera doorbell (DDR[3]=1337) -> verifica los 13 resultados.
//
//  VALIDACION ESCALONADA (por defecto corre los tres escalones seguidos):
//    div_pp = 7 -> 3.125 MHz push-pull
//    div_pp = 3 -> 6.25 MHz
//    div_pp = 1 -> 12.5 MHz (maximo SDR)
//  El divisor open-drain queda fijo en 24 (1.04 MHz) via el lui del programa.
//  Todo el trafico corre en LOOP_INT (controller y target internos).
//
//  Cross-compilado por Claude: aarch64-linux-gnu-gcc -O2 -static
//  Uso en el target:  sudo ./i3c_bringup            (triple escalon)
//                     sudo ./i3c_bringup <div_pp>   (un solo escalon)
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

// programa i3c_test.s ensamblado (asm.py); parches en addi separadas
#define PROG_DIVPP_IDX 5          // addi x5, x5, <div_pp>  (od=24 en el lui)
#define PROG_CTRL_IDX  20         // addi x5, x0, <ctrl>    (0x83=EN|TEN|LOOP)
static uint32_t prog[] = {
  0x900000B7, 0x40000137, 0x00010A37, 0x00800B13,
  0x001802B7, 0x00728293, 0x0050A423, 0x05200293,
  0x0050AC23, 0x67ABD2B7, 0xDEF28293, 0x0050AE23,
  0x45900293, 0x0250A023, 0x009CC2B7, 0x64628293,
  0x0250A223, 0x000012B7, 0x23428293, 0x0250A423,
  0x08300293, 0x0050A023, 0x1FC00293, 0x0050A623,
  0x1F000FEF, 0x00700293, 0x0050A623, 0x1E400FEF,
  0x000022B7, 0x0050A623, 0x1D800FEF, 0x0100A483,
  0x0FF4F493, 0x00902023, 0x00900533, 0x00600613,
  0x0100A483, 0x0FF4F493, 0x00954533, 0xFFF60613,
  0xFE0618E3, 0x0100A483, 0x0FF4F493, 0x00954533,
  0x00902223, 0x00A02423, 0x000042B7, 0x06028293,
  0x0050A623, 0x18C00FEF, 0x02C0A483, 0x00902823,
  0x000022B7, 0x0050A623, 0x0040A303, 0x014373B3,
  0xFE038CE3, 0x016373B3, 0x0033D393, 0x00702A23,
  0x0000A223, 0x000012B7, 0x20028293, 0x0050A623,
  0x15000FEF, 0x1FC00293, 0x0050A623, 0x14400FEF,
  0x16000293, 0x0050A623, 0x13800FEF, 0x0A500293,
  0x0050A623, 0x12C00FEF, 0x23C00293, 0x0050A623,
  0x12000FEF, 0x0400A403, 0x01045413, 0x03F47413,
  0x00802C23, 0x03C0A483, 0x0FF4F493, 0x00902E23,
  0x03C0A483, 0x0FF4F493, 0x02902023, 0x01100293,
  0x0250AC23, 0x02200293, 0x0250AC23, 0x03300293,
  0x0250AC23, 0x1FC00293, 0x0050A623, 0x0D400FEF,
  0x16100293, 0x0050A623, 0x0C800FEF, 0x40000293,
  0x0050A623, 0x0BC00FEF, 0x0100A483, 0x0FF4F493,
  0x02902223, 0x000012B7, 0xE0028293, 0x0050A623,
  0x0A000FEF, 0x0100A483, 0x0FF4F493, 0x02902423,
  0x00100293, 0x0250AA23, 0x0040A303, 0x00437393,
  0xFE038CE3, 0x0140A483, 0x0FF4F493, 0x02902623,
  0x000082B7, 0x0050A623, 0x06800FEF, 0x40000293,
  0x0050A623, 0x05C00FEF, 0x0040A303, 0x01037393,
  0x0043D393, 0x02702A23, 0x0100A483, 0x0FF4F493,
  0x02902823, 0x000012B7, 0x20028293, 0x0050A623,
  0x03000FEF, 0x53900293, 0x00502623, 0x00012023,
  0x00012223, 0x01000293, 0x00512423, 0x00300293,
  0x00512623, 0x01012303, 0xFE031EE3, 0x00000063,
  0x0040A303, 0x014373B3, 0xFE038CE3, 0x0000A223,
  0x000F8067,
};

#define PROG_LEN (sizeof(prog)/sizeof(prog[0]))

// parcha el inmediato de 12 bits de una instruccion I-type (addi)
static uint32_t patch_addi(uint32_t insn, uint32_t imm)
{
  return (insn & 0x000FFFFFu) | ((imm & 0xFFFu) << 20);
}

static const struct { unsigned idx; uint32_t exp; const char *msg; } chk[] = {
  {  0, 0x004, "fase A byte0 payload"  },
  {  1, 0x0C6, "fase A byte7 payload"  },
  {  2, 0x033, "fase A XOR payload"    },
  {  4, 0x730, "fase A TDA"            },
  {  5, 0x001, "fase A NACK ronda 2"   },
  {  6, 0x002, "fase B nivel TRX"      },
  {  7, 0x0A5, "fase B byte0"          },
  {  8, 0x03C, "fase B byte1"          },
  {  9, 0x011, "fase C byte0"          },
  { 10, 0x022, "fase C byte1 (seize)"  },
  { 11, 0x061, "fase D IBIADDR"        },
  { 12, 0x09C, "fase D mandatory byte" },
  { 13, 0x000, "fase D t_bit del MDB"  },
};
#define NCHK (sizeof(chk)/sizeof(chk[0]))

static int corre_escalon(volatile uint32_t *soc, volatile uint32_t *ddr,
                         uint32_t div_pp, double mhz)
{
  uint32_t ctrl = 0x83;            // EN | TEN | LOOP_INT

  printf("\n== escalon div_pp=%u (%.3f MHz push-pull, OD fija 1.04 MHz) ==\n",
         div_pp, mhz);

  // 1) halt del core y base de la DDR para el dma_burst
  soc[R_CONTROL]   = 1;
  soc[R_DDRBASE_L] = (uint32_t)DDR_PHYS;
  soc[R_DDRBASE_H] = 0;

  // 2) parches y carga del programa por la ventana IMEM
  uint32_t p5  = patch_addi(prog[PROG_DIVPP_IDX], div_pp);
  uint32_t p20 = patch_addi(prog[PROG_CTRL_IDX],  ctrl);
  for (unsigned i = 0; i < PROG_LEN; i++) {
    uint32_t w = prog[i];
    if (i == PROG_DIVPP_IDX) w = p5;
    if (i == PROG_CTRL_IDX)  w = p20;
    soc[IMEM_WIN + i] = w;
  }
  for (unsigned i = 0; i < PROG_LEN; i++) {
    uint32_t w = prog[i];
    if (i == PROG_DIVPP_IDX) w = p5;
    if (i == PROG_CTRL_IDX)  w = p20;
    if (soc[IMEM_WIN + i] != w) {
      printf("FALLO: verificacion de IMEM en la palabra %u\n", i);
      return 0;
    }
  }

  // 3) limpiar la zona de reporte y el doorbell
  for (unsigned i = 0; i < 16; i++) ddr[i] = 0;

  // 4) soltar el core
  soc[R_CONTROL] = 0;

  // 5) esperar el doorbell (DDR[3] = 1337)
  unsigned tmo = 0;
  while (ddr[3] != 1337) {
    usleep(1000);
    if (++tmo > 2000) {
      printf("TIMEOUT: sin doorbell; DBG_PC=0x%08X STAT=0x%08X\n",
             soc[R_DBG_PC], soc[R_STATUS]);
      return 0;
    }
  }
  usleep(2000);                    // dejar aterrizar la cola de la rafaga DMA
  printf("doorbell recibido (DDR[3]=1337) tras ~%u ms\n", tmo);

  // 6) verificar resultados
  int pass = 1;
  for (unsigned i = 0; i < NCHK; i++) {
    uint32_t v = ddr[chk[i].idx];
    printf("  %-22s DDR[%2u] = 0x%03X (esperado 0x%03X) %s\n",
           chk[i].msg, chk[i].idx, v, chk[i].exp,
           v == chk[i].exp ? "OK" : "FALLO");
    if (v != chk[i].exp) pass = 0;
  }
  return pass;
}

int main(int argc, char **argv)
{
  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd < 0) { perror("/dev/mem"); return 1; }

  volatile uint32_t *soc = mmap(NULL, SOC_SPAN, PROT_READ | PROT_WRITE,
                                MAP_SHARED, fd, SOC_PHYS);
  volatile uint32_t *ddr = mmap(NULL, DDR_SPAN, PROT_READ | PROT_WRITE,
                                MAP_SHARED, fd, DDR_PHYS);
  if (soc == MAP_FAILED || ddr == MAP_FAILED) { perror("mmap"); return 1; }

  printf("I3C bring-up (loop_int, %u palabras de programa)\n",
         (unsigned)PROG_LEN);

  int pass = 1;
  if (argc > 1) {
    uint32_t d = (uint32_t)strtoul(argv[1], NULL, 0);
    pass = corre_escalon(soc, ddr, d, 100.0 / (4.0 * (d + 1)));
  } else {
    static const uint32_t esc[3] = { 7, 3, 1 };
    for (int i = 0; i < 3; i++)
      if (!corre_escalon(soc, ddr, esc[i], 100.0 / (4.0 * (esc[i] + 1))))
        pass = 0;
  }

  printf(pass ? "\n== I3C SILICON PASS (loop_int, escalonado) ==\n"
              : "\n== I3C SILICON FAIL ==\n");
  return pass ? 0 : 1;
}
