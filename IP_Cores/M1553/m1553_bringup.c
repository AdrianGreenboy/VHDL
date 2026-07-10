// ============================================================================
//  m1553_bringup.c  -  Verificador de silicio del IP MIL-STD-1553B (capa 5)
//  Licencia: MIT
//
//  Corre en el PS (APU, aarch64) sobre PetaLinux. Pilota el core RV32 del PL
//  a traves del esclavo AXI4-Lite (axil_soc) mapeado en 0x8000_0000, carga el
//  firmware fw_m1553.mem por la ventana IMEM, fija la base DDR, suelta el core
//  y verifica que la firma de 8 palabras que el RV32 vuelca por DMA a la DDR
//  coincide con la referencia del ISS. Declara M1553 SILICON PASS.
//
//  Mapa del axil_soc (base 0x8000_0000, ventana 64 KB):
//    0x0000 CONTROL  (bit0 = 1 mantiene el core en reset/halt)
//    0x0004 STATUS   (bit0 = corriendo)
//    0x0008 DBG_PC
//    0x0010 DDR_BASE_LO
//    0x0014 DDR_BASE_HI
//    0x1000 + i*4  ventana IMEM (una instruccion por palabra)
//    0x2000 + i*4  ventana DMEM
//
//  El DMA del SoC vuelca a ddr_base + offset. Reservamos un buffer DDR fisico
//  contiguo (via /dev/mem sobre una zona reservada del device tree) y le
//  pasamos su direccion fisica al core por DDR_BASE_{LO,HI}.
//
//  Compilar:
//    aarch64-linux-gnu-gcc -O2 -static m1553_bringup.c -o m1553_bringup
//
//  Uso en el target:
//    ./m1553_bringup fw_m1553.mem
// ============================================================================
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define SOC_BASE   0x80000000UL     // esclavo AXI-Lite del SoC (del BD)
#define SOC_SIZE   0x10000UL

// buffer DDR reservado para el volcado del DMA. Debe coincidir con la region
// reservada en el device tree (reserved-memory) del PetaLinux del 1553.
// El SPW uso 0x50000000; mantenemos el patron.
#define DDR_BUF    0x70000000UL
#define DDR_SIZE   0x1000UL

#define REG_CONTROL 0x0000
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_DDR_LO  0x0010
#define REG_DDR_HI  0x0014
#define WIN_IMEM    0x1000
#define WIN_DMEM    0x2000

static volatile uint32_t *soc;
static volatile uint32_t *ddr;

static inline void wr(uint32_t off, uint32_t v){ soc[off/4] = v; }
static inline uint32_t rd(uint32_t off){ return soc[off/4]; }

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "uso: %s fw_m1553.mem\n", argv[0]); return 2; }

    // firma de referencia del ISS (capa 4)
    const uint32_t EXP[8] = {
        0x00002800, 0x0000C406, 0x00002800, 0x0000E203,
        0x28004800, 0x0000F300, 0x00000003, 0x0000DEAD
    };

    // cargar el .mem
    uint32_t prog[512]; int n = 0;
    FILE *f = fopen(argv[1], "r");
    if (!f) { perror("fopen mem"); return 2; }
    while (n < 512 && fscanf(f, "%x", &prog[n]) == 1) n++;
    fclose(f);
    printf("[bringup] firmware: %d instrucciones\n", n);

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 2; }

    soc = mmap(NULL, SOC_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, SOC_BASE);
    ddr = mmap(NULL, DDR_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, DDR_BUF);
    if (soc == MAP_FAILED || ddr == MAP_FAILED) { perror("mmap"); return 2; }

    // 1) mantener el core en reset (halt)
    wr(REG_CONTROL, 1);

    // 2) limpiar el buffer DDR y programar la base fisica del DMA
    for (int i = 0; i < 8; i++) ddr[i] = 0xFFFFFFFF;
    wr(REG_DDR_LO, (uint32_t)(DDR_BUF & 0xFFFFFFFF));
    wr(REG_DDR_HI, (uint32_t)((DDR_BUF >> 32) & 0xFF));

    // 3) cargar el firmware por la ventana IMEM
    for (int i = 0; i < n; i++) wr(WIN_IMEM + i*4, prog[i]);

    // verificacion de carga: releer unas cuantas
    int bad = 0;
    for (int i = 0; i < n; i++) {
        uint32_t got = rd(WIN_IMEM + i*4);
        if (got != prog[i]) {
            printf("[bringup] IMEM mismatch @%d: escrito 0x%08X leido 0x%08X\n",
                   i, prog[i], got);
            if (++bad > 5) break;
        }
    }
    if (bad) { printf("M1553 SILICON FAIL: carga de IMEM\n"); return 1; }
    printf("[bringup] IMEM cargada y verificada\n");

    // 4) soltar el core (CONTROL.bit0 = 0)
    wr(REG_CONTROL, 0);

    // 5) esperar a que el core termine el volcado DMA. El firmware acaba en un
    //    loop infinito tras el doorbell; sondeamos la palabra centinela de la
    //    DDR (sig[7] = 0xDEAD) con timeout.
    int done = 0;
    for (int t = 0; t < 100000; t++) {
        if (ddr[7] == EXP[7]) { done = 1; break; }
        usleep(100);
    }
    printf("[bringup] DBG_PC final = 0x%08X\n", rd(REG_DBGPC));
    if (!done) {
        printf("[bringup] timeout esperando el volcado DMA\n");
        printf("[bringup] DDR:");
        for (int i = 0; i < 8; i++) printf(" 0x%08X", ddr[i]);
        printf("\nM1553 SILICON FAIL: sin firma\n");
        return 1;
    }

    // 6) verificar la firma completa
    int ok = 1;
    printf("[bringup] firma en DDR vs ISS:\n");
    for (int i = 0; i < 8; i++) {
        int m = (ddr[i] == EXP[i]);
        ok &= m;
        printf("   sig[%d] = 0x%08X  esperado 0x%08X  %s\n",
               i, ddr[i], EXP[i], m ? "OK" : "MISMATCH");
    }

    if (ok) { printf("\nM1553 SILICON PASS\n"); return 0; }
    printf("\nM1553 SILICON FAIL: firma incorrecta\n");
    return 1;
}
