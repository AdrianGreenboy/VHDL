// rf-bringup.c - Bring-up del RF Digital Front-End (DDC/DUC) en el TE0950.
// Acceso por /dev/mem, mapeando SOLO el tamano necesario de cada region.
//
// NOTA de bring-up (leccion): mapear 16 MB completos de la DDR reservada por
// /dev/mem da SIGBUS (el kernel no permite un mapeo lineal tan grande sobre la
// region reservada). La solucion es mapear solo lo que se usa: el CSR (64 KB) y
// una sola pagina para el buffer (64 muestras = 256 B << 4 KB). Verificado en
// silicio con busybox devmem: /dev/mem accede tanto a 0x80000000 (CSR) como a
// 0x70000000 (DDR) con mapeos de pagina. No hace falta UIO.
//
// El A72 carga fw_rf en la IMEM del RV32, suelta el core, y este programa el
// generador de tono (TONE_FTW=0 -> banda base DC 29491), habilita RX, espera 64
// muestras, dispara el 2do maestro AXI (vuelca a la DDR reservada 0x70000000) y
// hace el doorbell. El A72 espera el doorbell, lee las 64 muestras y calcula el
// checksum canonico, comparandolo con el golden del ISS/GHDL.
//
// Compilar (cross aarch64):  aarch64-linux-gnu-gcc -O2 -static rf-bringup.c -o rf-bringup
// Ejecutar (root):  ./rf-bringup
// Oraculo (TONE_FTW=0): CHK = 0xB74940EB (64 muestras). Regimen ~0x5D4Dxxxx.

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define SOC_BASE   0x80000000UL
#define SOC_SPAN   0x10000UL       // 64 KB (mapeo pequeno: OK por /dev/mem)
#define DDR_BASE   0x70000000UL
#define DDR_SPAN   0x10000UL       // 64 KB basta para 64 muestras (256 B)
#define REG_CONTROL 0x0000
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C
#define REG_DDRB_LO 0x0010
#define REG_DDRB_HI 0x0014
#define OFF_IMEM    0x1000

#define N_SAMP   64
#define GOLDEN   0xB74940EBu

static uint32_t prog[] = {
0x600000B7, 0x0293B2B7, 0x80028293, 0x0050A423, 0x0400A023, 0x0000AA23, 0x00008337, 0xFFF30313,
0x0060AC23, 0x00100393, 0x01000413, 0x0070AA23, 0x0000AC23, 0x00138393, 0xFE83CAE3, 0x00500493,
0x0090A023, 0x04000513, 0x01C0A583, 0xFEA5CEE3, 0x0200AA23, 0x04000613, 0x02C0AC23, 0x00100693,
0x02D0AE23, 0x02000713, 0x0040A583, 0x00E5F7B3, 0xFE078CE3, 0x0040A583, 0x00E5F7B3, 0xFE079CE3,
0x00100A93, 0x1F502E23, 0x00000063,
};
#define PROG_WORDS (sizeof(prog)/sizeof(prog[0]))

static volatile uint32_t *soc;
static volatile uint8_t  *ddr;
static inline void     wr(unsigned off, uint32_t v) { soc[off/4] = v; }
static inline uint32_t rd(unsigned off)             { return soc[off/4]; }
static inline uint32_t ddr_w(unsigned widx)
{ return ((volatile uint32_t*)ddr)[widx]; }
static uint32_t rotl32(uint32_t v, unsigned n) { return (v << n) | (v >> (32 - n)); }

int main(void)
{
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }
    soc = (volatile uint32_t *)mmap(NULL, SOC_SPAN, PROT_READ|PROT_WRITE,
                                    MAP_SHARED, fd, SOC_BASE);
    if (soc == MAP_FAILED) { perror("mmap soc"); return 1; }
    ddr = (volatile uint8_t *)mmap(NULL, DDR_SPAN, PROT_READ|PROT_WRITE,
                                   MAP_SHARED, fd, DDR_BASE);
    if (ddr == MAP_FAILED) { perror("mmap ddr"); return 1; }

    printf("RF bring-up: DDC/DUC, DDR=0x%lx\n", DDR_BASE);

    wr(REG_CONTROL, 1);
    for (unsigned i = 0; i < PROG_WORDS; i++) wr(OFF_IMEM + i*4, prog[i]);
    for (unsigned i = 0; i < PROG_WORDS; i++)
        if (rd(OFF_IMEM + i*4) != prog[i]) {
            fprintf(stderr, "IMEM verify fallo en %u\n", i); return 1;
        }

    wr(REG_DDRB_LO, (uint32_t)(DDR_BASE & 0xFFFFFFFFu));
    wr(REG_DDRB_HI, (uint32_t)(DDR_BASE >> 32));

    // limpiar el buffer con escrituras de 32 bits ALINEADAS (no memset:
    // /dev/mem mapea la region como memoria Device, y las rutinas optimizadas
    // de memset en aarch64 usan instrucciones (DC ZVA / accesos no alineados)
    // que fallan con SIGBUS en memoria Device. Un bucle volatile es seguro).
    for (int i = 0; i < N_SAMP + 1; i++) ((volatile uint32_t*)ddr)[i] = 0;
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

    uint32_t chk = 0;
    for (int i = 0; i < N_SAMP; i++) chk = rotl32(chk, 1) ^ ddr_w(i);

    printf("  primeras muestras: %08X %08X %08X %08X\n",
           ddr_w(0), ddr_w(1), ddr_w(2), ddr_w(3));
    printf("  regimen (idx 60..63): %08X %08X %08X %08X\n",
           ddr_w(60), ddr_w(61), ddr_w(62), ddr_w(63));

    if (chk == GOLDEN) {
        printf("PASS: RF DDC/DUC validado en silicio.\n");
        printf("  CHK=0x%08X (golden 0x%08X) N=%d\n", chk, GOLDEN, N_SAMP);
        return 0;
    } else {
        printf("FAIL: CHK=0x%08X (esperaba 0x%08X)\n", chk, GOLDEN);
        return 3;
    }
}
