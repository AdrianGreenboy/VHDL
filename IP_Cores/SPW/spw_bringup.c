// ============================================================================
//  spw_bringup.c - Bring-up de silicio del IP SpaceWire (TE0950, PetaLinux,
//  /dev/mem)
//  Licencia: MIT
//
//  Igual patron que can_bringup.c: mapea el esclavo AXI4-Lite del SoC en
//  0x8000_0000 y la DDR reservada no-map (16 MB) en 0x7000_0000 fisica.
//  NOTA: esa DDR fisica NO tiene nada que ver con la region 0xB000_0000 del
//  bus dmem interno del RV32 donde vive el IP SpaceWire.
//
//  Flujo por escalon: halt del core -> DDR_BASE -> carga del programa (con
//  los parches de DIV/CTRL en sus addi separadas) -> limpia la DDR -> suelta
//  el core -> espera doorbell (DDR[3]=1337) -> verifica los 10 resultados.
//
//  VALIDACION ESCALONADA (por defecto corre los CUATRO escalones seguidos).
//  Con aclk = 100 MHz, DIV = ciclos de reloj por bit y el bit-rate es
//  100 MHz / DIV:
//    div = 10 -> 10 Mbit/s (arranque estandar ECSS)
//    div =  5 -> 20 Mbit/s
//    div =  4 -> 25 Mbit/s
//    div =  2 -> 50 Mbit/s (maximo del RX sincrono a 100 MHz)
//  Todo el trafico corre en LOOP_INT (un codec en self-loopback interno).
//  Sin pads: el SPW v1 no expone pines (pregunta abierta LVDS para v1.1).
//
//  El programa embebido son las 98 palabras de spw_test.mem ensambladas por
//  asm.py (las MISMAS que pasaron la capa 4). Parches:
//    prog[2]  addi x4, x0, <div>   -> DIV inicial
//    prog[4]  addi x5, x0, <ctrl>  -> CTRL (0x13 = EN | START | LOOP_INT)
//    prog[73] addi x5, x0, <div>   -> DIV del re-arranque (fase F)
//    prog[75] addi x5, x0, <ctrl>  -> CTRL del re-arranque
//  En el escalon, AMBOS DIV se parchean al mismo valor: todo el test corre
//  a una sola tasa por escalon (la fase F valida el ciclo apagar/reconfigurar
//  /re-arrancar a esa misma tasa).
//
//  Cross-compilado por Claude: aarch64-linux-gnu-gcc -O2 -static
//  Uso en el target:  sudo ./spw_bringup            (cuadruple escalon)
//                     sudo ./spw_bringup <div>      (un solo escalon)
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

// programa spw_test.s ensamblado (asm.py); parches en addi separadas.
#define PROG_DIV_IDX    2
#define PROG_CTRL_IDX   4
#define PROG_DIV2_IDX   73
#define PROG_CTRL2_IDX  75
static uint32_t prog[] = {
  0xB00000B7, 0x40000137, 0x00A00213, 0x0040A223,
  0x01300293, 0x0050A023, 0x00800A13, 0x0100A303,
  0x014373B3, 0xFE038CE3, 0x00400AB7, 0x0100A303,
  0x015373B3, 0x0163D393, 0x00702023, 0x0000A823,
  0x0A500293, 0x0050AA23, 0x05A00293, 0x0050AA23,
  0x10000293, 0x0050AA23, 0x80000B37, 0x0180A483,
  0x0164F3B3, 0xFE038CE3, 0x0FF4F493, 0x00902223,
  0x0180A483, 0x0164F3B3, 0xFE038CE3, 0x0FF4F493,
  0x00902423, 0x0180A483, 0x0164F3B3, 0xFE038CE3,
  0x1FF4F493, 0x00902823, 0x03C00293, 0x0050A623,
  0x00100BB7, 0x0100A303, 0x017373B3, 0xFE038CE3,
  0x00C0A483, 0x0FF4F513, 0x00A02A23, 0x0084D493,
  0x0FF4F493, 0x00902C23, 0x0000A823, 0x01000613,
  0x00100693, 0x00D0AA23, 0x00168693, 0xFFF60613,
  0xFE061AE3, 0x01000613, 0x00000533, 0x0180A483,
  0x0164F3B3, 0xFE038CE3, 0x0FF4F493, 0x00954533,
  0xFFF60613, 0xFE0614E3, 0x00A02E23, 0x0100A303,
  0x00737393, 0x02702023, 0x02037393, 0x02702223,
  0x0000A023, 0x00200293, 0x0050A223, 0x01300293,
  0x0050A023, 0x0100A303, 0x014373B3, 0xFE038CE3,
  0x0C300293, 0x0050AA23, 0x0180A483, 0x0164F3B3,
  0xFE038CE3, 0x0FF4F493, 0x02902423, 0x53900293,
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
  {  0, 0x001, "fase A sticky RUNOK"          },
  {  1, 0x0A5, "fase B dato 1"                },
  {  2, 0x05A, "fase B dato 2"                },
  {  4, 0x100, "fase B EOP"                   },
  {  5, 0x03C, "fase C time-code"             },
  {  6, 0x001, "fase C contador de ticks"     },
  {  7, 0x010, "fase D XOR de la rafaga"      },
  {  8, 0x005, "fase E estado del enlace Run" },
  {  9, 0x000, "fase E FIFO RX vacio"         },
  { 10, 0x0C3, "fase F byte tras re-arranque" },
};
#define NCHK (sizeof(chk)/sizeof(chk[0]))

static uint32_t palabra(unsigned i, uint32_t div, uint32_t ctrl)
{
  uint32_t w = prog[i];
  if (i == PROG_DIV_IDX)   w = patch_addi(w, div);
  if (i == PROG_CTRL_IDX)  w = patch_addi(w, ctrl);
  if (i == PROG_DIV2_IDX)  w = patch_addi(w, div);
  if (i == PROG_CTRL2_IDX) w = patch_addi(w, ctrl);
  return w;
}

static int corre_escalon(volatile uint32_t *soc, volatile uint32_t *ddr,
                         uint32_t div, double mbps)
{
  uint32_t ctrl = 0x13;            // EN | START | LOOP_INT

  printf("\n== escalon div=%u (%.0f Mbit/s, LOOP_INT) ==\n", div, mbps);

  // 1) halt del core y base de la DDR para el dma_burst
  soc[R_CONTROL]   = 1;
  soc[R_DDRBASE_L] = (uint32_t)DDR_PHYS;
  soc[R_DDRBASE_H] = 0;

  // 2) parches y carga del programa por la ventana IMEM
  for (unsigned i = 0; i < PROG_LEN; i++)
    soc[IMEM_WIN + i] = palabra(i, div, ctrl);
  for (unsigned i = 0; i < PROG_LEN; i++) {
    if (soc[IMEM_WIN + i] != palabra(i, div, ctrl)) {
      printf("FALLO: verificacion de IMEM en la palabra %u\n", i);
      return 0;
    }
  }

  // 3) limpiar la zona de reporte y el doorbell
  for (unsigned i = 0; i < 16; i++) ddr[i] = 0;

  // 4) soltar el core
  soc[R_CONTROL] = 0;

  // 5) esperar el doorbell (DDR[3] = 1337). El test completo tarda ~70 us a
  //    10 Mbit/s: 4 s de margen es holgadisimo, pero es el patron heredado.
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
    printf("  %-30s DDR[%2u] = 0x%03X (esperado 0x%03X) %s\n",
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

  printf("SpaceWire bring-up (loop_int, %u palabras de programa)\n",
         (unsigned)PROG_LEN);

  // div -> Mbit/s con aclk = 100 MHz
  struct { uint32_t div; double mbps; } esc[4] = {
    { 10, 10.0 }, { 5, 20.0 }, { 4, 25.0 }, { 2, 50.0 }
  };

  int pass = 1;
  if (argc > 1) {
    uint32_t d = (uint32_t)strtoul(argv[1], NULL, 0);
    if (d < 2) d = 2;
    pass = corre_escalon(soc, ddr, d, 100.0 / d);
  } else {
    for (int i = 0; i < 4; i++)
      if (!corre_escalon(soc, ddr, esc[i].div, esc[i].mbps))
        pass = 0;
  }

  printf(pass ? "\n== SPW SILICON PASS (loop_int, escalonado) ==\n"
              : "\n== SPW SILICON FAIL ==\n");
  return pass ? 0 : 1;
}
