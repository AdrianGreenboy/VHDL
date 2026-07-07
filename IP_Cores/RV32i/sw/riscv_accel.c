// ============================================================================
//  riscv_accel.c  -  App Linux (A72) que usa el core RISC-V del PL como acelerador
//  Licencia: MIT
//
//  El A72 (via AXI4-Lite, mapeado con /dev/mem) carga el programa acelerador en
//  la IMEM, escribe los datos de entrada en la DMEM, arranca el core, espera la
//  bandera de "listo" y lee el resultado. Calcula lo mismo en el A72 para
//  comparar. El acelerador hace la suma de cuadrados de un arreglo (usa mul).
//
//  Compilar (SDK de PetaLinux / Vitis, cross para aarch64):
//     $CC riscv_accel.c -o riscv_accel
//  Ejecutar en la placa (necesita root para /dev/mem):
//     ./riscv_accel 1 2 3 4 5
//
//  Ajusta SOC_BASE a la direccion base que el Address Editor de Vivado le
//  asigno al esclavo AXI4-Lite de soc_top.
// ============================================================================
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define SOC_BASE   0x0000020100000000UL   // base del esclavo AXI en el espacio del NoC
                                          // (FPD_CCI_NOC_0, asignada por el Address Editor)
#define SOC_SPAN   0x10000UL      // 64 KB

// mapa de registros (offsets en bytes)
#define REG_CONTROL 0x0000        // bit0 = 1 -> core en reset (halt)
#define REG_STATUS  0x0004        // bit0 = 1 -> core corriendo
#define REG_DBGPC   0x0008
#define OFF_IMEM    0x1000
#define OFF_DMEM    0x2000

// convencion de la DMEM (indices de palabra)
#define DMEM_N       0
#define DMEM_ARR     1            // arreglo en [1..N]
#define DMEM_RESULT  64
#define DMEM_DONE    65

// programa acelerador (accel_sumsq.s ensamblado)
static const uint32_t prog[] = {
    0x00002103, 0x00000193, 0x00100213, 0x00110293,
    0x00525E63, 0x00221313, 0x00032403, 0x028404B3,
    0x009181B3, 0x00120213, 0xFE0004E3, 0x10000513,
    0x00352023, 0x00100593, 0x10B02223, 0x00000063,
};
#define PROG_WORDS (sizeof(prog)/sizeof(prog[0]))

static volatile uint32_t *soc;   // base mapeada

static inline void   wr(unsigned off, uint32_t v) { soc[off/4] = v; }
static inline uint32_t rd(unsigned off)           { return soc[off/4]; }

static inline void dmem_wr(int idx, uint32_t v) { wr(OFF_DMEM + idx*4, v); }
static inline uint32_t dmem_rd(int idx)         { return rd(OFF_DMEM + idx*4); }

int main(int argc, char **argv)
{
    // entradas: por argumentos, o 1..5 por defecto
    uint32_t vals[63];
    int N;
    if (argc > 1) {
        N = argc - 1;
        if (N > 63) N = 63;
        for (int i = 0; i < N; i++) vals[i] = (uint32_t)strtoul(argv[i+1], NULL, 0);
    } else {
        N = 5;
        for (int i = 0; i < N; i++) vals[i] = i + 1;
    }

    // mapea el esclavo AXI
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }
    void *base = mmap(NULL, SOC_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, SOC_BASE);
    if (base == MAP_FAILED) { perror("mmap"); return 1; }
    soc = (volatile uint32_t *)base;

    // 1) detiene el core (para poder escribir IMEM/DMEM)
    wr(REG_CONTROL, 1);

    // 2) carga el programa acelerador en la IMEM
    for (unsigned i = 0; i < PROG_WORDS; i++)
        wr(OFF_IMEM + i*4, prog[i]);

    // 3) escribe las entradas en la DMEM
    dmem_wr(DMEM_N, (uint32_t)N);
    for (int i = 0; i < N; i++) dmem_wr(DMEM_ARR + i, vals[i]);
    dmem_wr(DMEM_DONE, 0);   // limpia la bandera

    // 4) arranca el core
    wr(REG_CONTROL, 0);

    // 5) espera la bandera de "listo" (lecturas de DMEM funcionan aunque corra)
    long tries = 0;
    while (dmem_rd(DMEM_DONE) == 0) {
        if (++tries > 100000000L) { fprintf(stderr, "timeout esperando al core\n"); break; }
    }

    // 6) lee el resultado y detiene el core
    uint32_t result = dmem_rd(DMEM_RESULT);
    uint32_t pc     = rd(REG_DBGPC);
    wr(REG_CONTROL, 1);

    // 7) referencia en el A72 para comparar
    uint64_t expected = 0;
    for (int i = 0; i < N; i++) expected += (uint64_t)vals[i] * vals[i];

    printf("N = %d, entradas:", N);
    for (int i = 0; i < N; i++) printf(" %u", vals[i]);
    printf("\n");
    printf("resultado del core (sum de cuadrados) = %u\n", result);
    printf("esperado (calculado en el A72)         = %llu\n", (unsigned long long)expected);
    printf("PC final del core = 0x%08X\n", pc);
    printf("%s\n", (result == (uint32_t)expected) ? "OK: el acelerador coincide"
                                                   : "FALLO: no coincide");

    munmap(base, SOC_SPAN);
    close(fd);
    return (result == (uint32_t)expected) ? 0 : 2;
}
