// ============================================================================
//  can_bringup.c - Bring-up de silicio del IP CAN (TE0950, PetaLinux, /dev/mem)
//  Licencia: MIT
//
//  Igual patron que i3c_bringup.c: mapea el esclavo AXI4-Lite del SoC en
//  0x8000_0000 y la DDR reservada no-map (16 MB) en 0x7000_0000 fisica.
//  NOTA: esa DDR fisica NO tiene nada que ver con la region 0xA000_0000 del
//  bus dmem interno del RV32 donde vive el IP CAN.
//
//  Flujo por escalon: halt del core -> DDR_BASE -> carga del programa (con
//  el parche de BRP en su addi separada) -> limpia la DDR -> suelta el core
//  -> espera doorbell (DDR[3]=1337) -> verifica los 13 resultados.
//
//  VALIDACION ESCALONADA (por defecto corre los CUATRO escalones seguidos).
//  Con aclk = 100 MHz y 20 tq/bit (tseg1=12, tseg2=5, +sync), el bit-rate es
//  100 MHz / ((brp+1) * 20):
//    brp = 39 ->  125 kbit/s
//    brp = 19 ->  250 kbit/s
//    brp =  9 ->  500 kbit/s
//    brp =  4 -> 1000 kbit/s (1 Mbit/s, maximo CAN 2.0B)
//  Todo el trafico corre en LOOP_INT (nodos A y B internos, wired-AND). Los
//  pads quedan liberados (can_tx_t='1'), sin transceptor externo.
//
//  Cross-compilado por Claude: aarch64-linux-gnu-gcc -O2 -static
//  Uso en el target:  sudo ./can_bringup            (cuadruple escalon)
//                     sudo ./can_bringup <brp>      (un solo escalon)
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

// programa can_test.s ensamblado (asm.py); parches en addi separadas.
//   prog[4]  addi x4, x0, <brp>   -> campo BRP del BTR (or'd con el resto)
//   prog[7]  addi x5, x0, <ctrl>  -> CTRL (0x83 = EN_A | EN_B | LOOP_INT)
#define PROG_BRP_IDX   4
#define PROG_CTRL_IDX  7
static uint32_t prog[] = {
  0xA00000B7, 0x40000137, 0x000162B7, 0xC0028293,
  0x00900213, 0x0042E2B3, 0x0050A423, 0x08300293,
  0x0050A023, 0x12300293, 0x0050A823, 0x00800293,
  0x0050AA23, 0x012342B7, 0x56728293, 0x0050AC23,
  0x89ABD2B7, 0xDEF28293, 0x0050AE23, 0x00100293,
  0x0250A023, 0x00010A37, 0x02000BB7, 0x0040A303,
  0x014373B3, 0xFE038CE3, 0x0000A223, 0x0440A483,
  0x0FF4F493, 0x00902023, 0x0440A483, 0x0440A483,
  0x0FF4F493, 0x00902223, 0x0440A483, 0x0FF4F493,
  0x00902423, 0x0440A483, 0x0FF4F493, 0x00902823,
  0x0440A483, 0x0FF4F493, 0x00900533, 0x00902A23,
  0x00700613, 0x0440A483, 0x0FF4F493, 0x00954533,
  0xFFF60613, 0xFE0618E3, 0x00A02C23, 0x75A5A2B7,
  0x5A528293, 0x0250A823, 0x00500293, 0x0250AA23,
  0x00100293, 0x0450A023, 0x00020C37, 0x0040A303,
  0x018373B3, 0xFE038CE3, 0x0000A223, 0x0240A483,
  0x0FF4F493, 0x00902E23, 0x0240A483, 0x0240A483,
  0x0240A483, 0x0240A483, 0x0FF4F493, 0x02902023,
  0x00800613, 0x0240A483, 0xFFF60613, 0xFE061CE3,
  0x0F000293, 0x0050A823, 0x00100293, 0x0050AA23,
  0xAA0002B7, 0x0050AC23, 0x0000AE23, 0x12300293,
  0x0250A823, 0x00100293, 0x0250AA23, 0xBB0002B7,
  0x0250AC23, 0x0200AE23, 0x00100293, 0x0450A023,
  0x00100293, 0x0250A023, 0x00030CB7, 0x0040A303,
  0x019373B3, 0x01939463, 0x00000C63, 0x0040A403,
  0x00080D37, 0x01A47433, 0x0085E5B3, 0xFE0000E3,
  0x0040A403, 0x00080D37, 0x01A47433, 0x0085E5B3,
  0x0135D593, 0x02B02223, 0x0000A223, 0x0440A483,
  0x0440A483, 0x0440A483, 0x0440A483, 0x0FF4F493,
  0x02902423, 0x0440A483, 0x0440A483, 0x0FF4F493,
  0x02902623, 0x00700613, 0x0440A483, 0xFFF60613,
  0xFE061CE3, 0x0240A483, 0x0240A483, 0x0240A483,
  0x0240A483, 0x0FF4F493, 0x02902823, 0x0240A483,
  0x0240A483, 0x0FF4F493, 0x02902A23, 0x53900293,
  0x00502623, 0x00012023, 0x00012223, 0x01000293,
  0x00512423, 0x00300293, 0x00512623, 0x01012303,
  0xFE031EE3, 0x00000063,
};

#define PROG_LEN (sizeof(prog)/sizeof(prog[0]))

// parcha el inmediato de 12 bits de una instruccion I-type (addi)
static uint32_t patch_addi(uint32_t insn, uint32_t imm)
{
  return (insn & 0x000FFFFFu) | ((imm & 0xFFFu) << 20);
}

static const struct { unsigned idx; uint32_t exp; const char *msg; } chk[] = {
  {  0, 0x000, "fase A byte0 (flags+ID alto)" },
  {  1, 0x001, "fase A ID[15:8]"              },
  {  2, 0x023, "fase A ID[7:0]"               },
  {  4, 0x008, "fase A DLC"                   },
  {  5, 0x001, "fase A primer dato"           },
  {  6, 0x000, "fase A XOR de los 8 datos"    },
  {  7, 0x075, "fase B flags+ID alto"         },
  {  8, 0x005, "fase B DLC"                   },
  {  9, 0x001, "fase C ARB_B activo"          },
  { 10, 0x0F0, "fase C ID bajo ganador"       },
  { 11, 0x0AA, "fase C primer dato de A"      },
  { 12, 0x023, "fase C ID bajo reintento B"   },
  { 13, 0x0BB, "fase C primer dato de B"      },
};
#define NCHK (sizeof(chk)/sizeof(chk[0]))

static int corre_escalon(volatile uint32_t *soc, volatile uint32_t *ddr,
                         uint32_t brp, double kbps)
{
  uint32_t ctrl = 0x83;            // EN_A | EN_B | LOOP_INT

  printf("\n== escalon brp=%u (%.0f kbit/s, LOOP_INT) ==\n", brp, kbps);

  // 1) halt del core y base de la DDR para el dma_burst
  soc[R_CONTROL]   = 1;
  soc[R_DDRBASE_L] = (uint32_t)DDR_PHYS;
  soc[R_DDRBASE_H] = 0;

  // 2) parches y carga del programa por la ventana IMEM
  uint32_t p4 = patch_addi(prog[PROG_BRP_IDX],  brp);
  uint32_t p7 = patch_addi(prog[PROG_CTRL_IDX], ctrl);
  for (unsigned i = 0; i < PROG_LEN; i++) {
    uint32_t w = prog[i];
    if (i == PROG_BRP_IDX)  w = p4;
    if (i == PROG_CTRL_IDX) w = p7;
    soc[IMEM_WIN + i] = w;
  }
  for (unsigned i = 0; i < PROG_LEN; i++) {
    uint32_t w = prog[i];
    if (i == PROG_BRP_IDX)  w = p4;
    if (i == PROG_CTRL_IDX) w = p7;
    if (soc[IMEM_WIN + i] != w) {
      printf("FALLO: verificacion de IMEM en la palabra %u\n", i);
      return 0;
    }
  }

  // 3) limpiar la zona de reporte y el doorbell
  for (unsigned i = 0; i < 16; i++) ddr[i] = 0;

  // 4) soltar el core
  soc[R_CONTROL] = 0;

  // 5) esperar el doorbell (DDR[3] = 1337). A 125 kbit/s cada trama tarda
  //    mas: damos hasta ~4 s de margen (el escalon lento es el critico).
  unsigned tmo = 0;
  while (ddr[3] != 1337) {
    usleep(1000);
    if (++tmo > 4000) {
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
    printf("  %-28s DDR[%2u] = 0x%03X (esperado 0x%03X) %s\n",
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

  printf("CAN bring-up (loop_int, %u palabras de programa)\n",
         (unsigned)PROG_LEN);

  // brp -> kbit/s con aclk=100 MHz y 20 tq/bit
  struct { uint32_t brp; double kbps; } esc[4] = {
    { 39,  125.0 }, { 19,  250.0 }, { 9, 500.0 }, { 4, 1000.0 }
  };

  int pass = 1;
  if (argc > 1) {
    uint32_t b = (uint32_t)strtoul(argv[1], NULL, 0);
    pass = corre_escalon(soc, ddr, b, 100000.0 / ((b + 1) * 20));
  } else {
    for (int i = 0; i < 4; i++)
      if (!corre_escalon(soc, ddr, esc[i].brp, esc[i].kbps))
        pass = 0;
  }

  printf(pass ? "\n== CAN SILICON PASS (loop_int, escalonado) ==\n"
              : "\n== CAN SILICON FAIL ==\n");
  return pass ? 0 : 1;
}
