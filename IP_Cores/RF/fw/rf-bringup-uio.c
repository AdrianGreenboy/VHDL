// rf-bringup-uio.c - Bring-up del RF Digital Front-End (DDC/DUC) via UIO.
// A diferencia de la version /dev/mem, esta usa el driver UIO (uio_pdrv_genirq)
// para acceder a las dos regiones del RF. UIO SI puede mapear memoria reservada
// con "no-map" (que /dev/mem no puede: da SIGBUS), y es el patron limpio y
// profesional de la familia para exponer hardware del PL a userspace.
//
// El device-tree declara un nodo UIO "rf_soc_uio" con dos regiones reg:
//   map0 ("csr") = control del SoC RF, 0x80000000, 64 KB
//   map1 ("ddr") = buffer DDR reservado, 0x70000000, 16 MB
// El driver crea /dev/uioN y expone los mapas en /sys/class/uio/uioN/maps/mapM/.
// mmap de UIO selecciona el mapa M con offset = M * getpagesize().
//
// Compilar (cross aarch64):
//   aarch64-linux-gnu-gcc -O2 -static rf-bringup-uio.c -o rf-bringup-uio
// Ejecutar (root):  ./rf-bringup-uio
//
// Oraculo (del datapath GHDL, TONE_FTW=0): CHK = 0xB74940EB (64 muestras).
// Regimen constante ~0x5D4Dxxxx; primeras: 0003FFFF 059BFFFF 2EA5FFFF ...

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/mman.h>

#define CSR_SPAN   0x10000UL      // 64 KB
#define DDR_SPAN   0x1000000UL    // 16 MB
#define REG_CONTROL 0x0000        // bit0 = 1 -> core en reset (halt)
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C        // sticky del doorbell (w1c)
#define REG_DDRB_LO 0x0010
#define REG_DDRB_HI 0x0014
#define OFF_IMEM    0x1000

#define DDR_PHYS   0x70000000UL   // base fisica del buffer (para DDRB del maestro)
#define N_SAMP     64
#define GOLDEN     0xB74940EBu

static uint32_t prog[] = {
0x600000B7, 0x0293B2B7, 0x80028293, 0x0050A423, 0x0400A023, 0x0000AA23, 0x00008337, 0xFFF30313,
0x0060AC23, 0x00100393, 0x01000413, 0x0070AA23, 0x0000AC23, 0x00138393, 0xFE83CAE3, 0x00500493,
0x0090A023, 0x04000513, 0x01C0A583, 0xFEA5CEE3, 0x0200AA23, 0x04000613, 0x02C0AC23, 0x00100693,
0x02D0AE23, 0x02000713, 0x0040A583, 0x00E5F7B3, 0xFE078CE3, 0x0040A583, 0x00E5F7B3, 0xFE079CE3,
0x00100A93, 0x1F502E23, 0x00000063,
};
#define PROG_WORDS (sizeof(prog)/sizeof(prog[0]))

static volatile uint32_t *csr;
static volatile uint8_t  *ddr;
static inline void     wr(unsigned off, uint32_t v) { csr[off/4] = v; }
static inline uint32_t rd(unsigned off)             { return csr[off/4]; }
static inline uint32_t ddr_w(unsigned widx)
{ return ((volatile uint32_t*)ddr)[widx]; }
static uint32_t rotl32(uint32_t v, unsigned n) { return (v << n) | (v >> (32 - n)); }

// localizar el /dev/uioN cuyo nombre en /sys/class/uio/uioN/name coincide.
static int find_uio(const char *want)
{
    DIR *d = opendir("/sys/class/uio");
    if (!d) return -1;
    struct dirent *e;
    int found = -1;
    while ((e = readdir(d)) != NULL) {
        if (strncmp(e->d_name, "uio", 3) != 0) continue;
        char path[320], name[128] = {0};
        snprintf(path, sizeof(path), "/sys/class/uio/%s/name", e->d_name);
        FILE *f = fopen(path, "r");
        if (!f) continue;
        if (fgets(name, sizeof(name), f)) {
            char *nl = strchr(name, '\n'); if (nl) *nl = 0;
            if (strcmp(name, want) == 0) found = atoi(e->d_name + 3);
        }
        fclose(f);
        if (found >= 0) break;
    }
    closedir(d);
    return found;
}

int main(void)
{
    // el nombre del nodo UIO tal como aparece en /sys/class/uio/uioN/name.
    // uio_pdrv_genirq usa el nombre del nodo del device-tree: "rf_soc".
    int n = find_uio("rf_soc");
    if (n < 0) {
        // fallback: probar uio0 directamente
        n = 0;
        fprintf(stderr, "AVISO: nodo UIO 'rf_soc' no hallado por nombre, uso /dev/uio0\n");
    }
    char dev[32];
    snprintf(dev, sizeof(dev), "/dev/uio%d", n);

    int fd = open(dev, O_RDWR | O_SYNC);
    if (fd < 0) { perror("open uio"); return 1; }

    long ps = sysconf(_SC_PAGESIZE);
    // map0 = CSR (control del SoC); mmap con offset 0*ps
    csr = (volatile uint32_t *)mmap(NULL, CSR_SPAN, PROT_READ|PROT_WRITE,
                                    MAP_SHARED, fd, 0 * ps);
    if (csr == MAP_FAILED) { perror("mmap csr (map0)"); return 1; }
    // map1 = DDR buffer; mmap con offset 1*ps
    ddr = (volatile uint8_t *)mmap(NULL, DDR_SPAN, PROT_READ|PROT_WRITE,
                                   MAP_SHARED, fd, 1 * ps);
    if (ddr == MAP_FAILED) { perror("mmap ddr (map1)"); return 1; }

    printf("RF bring-up (UIO): DDC/DUC en %s, DDR=0x%lx\n", dev, DDR_PHYS);

    // mantener el core en halt y cargar la IMEM
    wr(REG_CONTROL, 1);
    for (unsigned i = 0; i < PROG_WORDS; i++) wr(OFF_IMEM + i*4, prog[i]);
    for (unsigned i = 0; i < PROG_WORDS; i++)
        if (rd(OFF_IMEM + i*4) != prog[i]) {
            fprintf(stderr, "IMEM verify fallo en %u\n", i); return 1;
        }

    // fijar la base fisica de la DDR (el segundo maestro escribe ahi)
    wr(REG_DDRB_LO, (uint32_t)(DDR_PHYS & 0xFFFFFFFFu));
    wr(REG_DDRB_HI, (uint32_t)(DDR_PHYS >> 32));

    // limpiar el buffer y el IRQ sticky
    memset((void*)ddr, 0, (N_SAMP+1)*4);
    __sync_synchronize();
    wr(REG_IRQ, 1);

    // soltar el core
    wr(REG_CONTROL, 0);

    // esperar el doorbell (polling del IRQ sticky)
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

    // leer las 64 muestras y calcular el checksum canonico
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
