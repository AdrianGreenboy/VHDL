// ============================================================================
//  riscv_accel_v2.c  -  App Linux (A72) que usa el core RISC-V como acelerador
//  Licencia: MIT
//
//  Un solo programa que junta las tres iteraciones:
//    * dos operaciones seleccionables:  sumsq  |  gemv
//    * corre sobre el core PIPELINE (soc_top_pipe)
//    * espera por INTERRUPCION via UIO (/dev/uio0) si existe; si no, POLLING
//
//  Uso:
//    ./riscv_accel_v2 sumsq 1 2 3 4 5        # suma de cuadrados
//    ./riscv_accel_v2 gemv                   # GEMV 3x3 de demo (A*[1,1,1])
//    ./riscv_accel_v2 gemv 2 0 1             # GEMV 3x3 con x = [2,0,1]
//
//  Registros AXI (offsets):
//    0x00 CONTROL (bit0=halt)   0x04 STATUS   0x08 DBG_PC   0x0C IRQ (w1c)
//    0x1000 ventana IMEM        0x2000 ventana DMEM
// ============================================================================
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define SOC_BASE   0x0000020100000000UL   // base del esclavo AXI (Address Editor)
#define SOC_SPAN   0x10000UL

#define REG_CONTROL 0x0000
#define REG_IRQ     0x000C
#define OFF_IMEM    0x1000
#define OFF_DMEM    0x2000
#define DMEM_DONE   127                   // doorbell (palabra)
#define DMEM_RESULT 64

// ---- programas acelerador (ensamblados con asm.py) -------------------------
static const uint32_t prog_sumsq[] = {
    0x00002103, 0x00000193, 0x00100213, 0x00110293,
    0x00525E63, 0x00221313, 0x00032403, 0x028404B3,
    0x009181B3, 0x00120213, 0xFE0004E3, 0x10000513,
    0x00352023, 0x00100593, 0x1EB02E23, 0x00000063,
};
static const uint32_t prog_gemv[] = {
    0x00002083, 0x00402103, 0x00800193, 0x022082B3,
    0x00229293, 0x00518333, 0x10000393, 0x00000413,
    0x04145A63, 0x00000493, 0x00000513, 0x022405B3,
    0x00259593, 0x00B185B3, 0x02255463, 0x00251613,
    0x00C586B3, 0x0006A703, 0x00C307B3, 0x0007A803,
    0x030708B3, 0x011484B3, 0x00150513, 0xFC000EE3,
    0x00241913, 0x012389B3, 0x0099A023, 0x00140413,
    0xFA0008E3, 0x00100A13, 0x1F402E23, 0x00000063,
};

static volatile uint32_t *soc;
static int uio_fd = -1;                   // >=0 si usamos interrupcion

static inline void   wr(unsigned off, uint32_t v) { soc[off/4] = v; }
static inline uint32_t rd(unsigned off)           { return soc[off/4]; }
static inline void   dmem_wr(int i, uint32_t v)   { wr(OFF_DMEM + i*4, v); }
static inline uint32_t dmem_rd(int i)             { return rd(OFF_DMEM + i*4); }

static void load_prog(const uint32_t *p, int n) {
    for (int i = 0; i < n; i++) wr(OFF_IMEM + i*4, p[i]);
}

// espera a que el core termine: por interrupcion (UIO) o por polling
static void wait_done(void) {
    if (uio_fd >= 0) {
        uint32_t irq_count;
        uint32_t enable = 1;
        write(uio_fd, &enable, sizeof(enable));     // re-habilita el IRQ del UIO
        read(uio_fd, &irq_count, sizeof(irq_count)); // BLOQUEA hasta la interrupcion
        wr(REG_IRQ, 1);                              // limpia el IRQ del dispositivo (w1c)
    } else {
        long tries = 0;
        while (dmem_rd(DMEM_DONE) == 0)
            if (++tries > 100000000L) { fprintf(stderr, "timeout\n"); break; }
        wr(REG_IRQ, 1);                              // limpia por si acaso
    }
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "uso: %s [sumsq|gemv] ...\n", argv[0]); return 1; }
    const char *op = argv[1];

    // --- mapea el esclavo: UIO si existe, si no /dev/mem ---
    uio_fd = open("/dev/uio0", O_RDWR);
    int mem_fd = -1;
    void *base;
    if (uio_fd >= 0) {
        base = mmap(NULL, SOC_SPAN, PROT_READ|PROT_WRITE, MAP_SHARED, uio_fd, 0);
    } else {
        mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
        if (mem_fd < 0) { perror("open /dev/mem"); return 1; }
        base = mmap(NULL, SOC_SPAN, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, SOC_BASE);
    }
    if (base == MAP_FAILED) { perror("mmap"); return 1; }
    soc = (volatile uint32_t *)base;
    printf("modo: %s\n", (uio_fd >= 0) ? "interrupcion (UIO)" : "polling (/dev/mem)");

    // --- halt + limpia doorbell/IRQ previos ---
    wr(REG_CONTROL, 1);
    dmem_wr(DMEM_DONE, 0);
    wr(REG_IRQ, 1);

    if (strcmp(op, "sumsq") == 0) {
        int N = (argc > 2) ? argc - 2 : 5;
        if (N > 62) N = 62;
        uint64_t expected = 0;
        load_prog(prog_sumsq, sizeof(prog_sumsq)/sizeof(uint32_t));
        dmem_wr(0, (uint32_t)N);
        for (int i = 0; i < N; i++) {
            uint32_t v = (argc > 2) ? (uint32_t)strtoul(argv[i+2], NULL, 0) : (uint32_t)(i+1);
            dmem_wr(1 + i, v);
            expected += (uint64_t)v * v;
        }
        wr(REG_CONTROL, 0);            // arranca
        wait_done();
        wr(REG_CONTROL, 1);           // halt para leer
        uint32_t r = dmem_rd(DMEM_RESULT);
        printf("sum de cuadrados = %u (esperado %llu) -> %s\n",
               r, (unsigned long long)expected,
               (r == (uint32_t)expected) ? "OK" : "FALLO");

    } else if (strcmp(op, "gemv") == 0) {
        // GEMV 3x3 de demo: A fija, x por argumentos (o [1,1,1])
        const int M = 3, N = 3;
        int A[9] = {1,2,3, 4,5,6, 7,8,9};
        int x[3];
        for (int j = 0; j < N; j++)
            x[j] = (argc > 2 + j) ? (int)strtol(argv[2+j], NULL, 0) : 1;

        load_prog(prog_gemv, sizeof(prog_gemv)/sizeof(uint32_t));
        dmem_wr(0, M); dmem_wr(1, N);
        for (int k = 0; k < M*N; k++) dmem_wr(2 + k, (uint32_t)A[k]);
        for (int j = 0; j < N; j++)   dmem_wr(2 + M*N + j, (uint32_t)x[j]);

        wr(REG_CONTROL, 0);
        wait_done();
        wr(REG_CONTROL, 1);

        printf("x = [%d %d %d]\n", x[0], x[1], x[2]);
        int ok = 1;
        for (int i = 0; i < M; i++) {
            int yc = (int)dmem_rd(DMEM_RESULT + i);
            int ye = A[i*N+0]*x[0] + A[i*N+1]*x[1] + A[i*N+2]*x[2];
            printf("y[%d] = %d (esperado %d) %s\n", i, yc, ye, (yc==ye)?"":"<-- FALLO");
            if (yc != ye) ok = 0;
        }
        printf("%s\n", ok ? "OK: GEMV coincide" : "FALLO");
    } else {
        fprintf(stderr, "operacion desconocida: %s\n", op);
    }

    printf("PC final = 0x%08X\n", rd(0x0008));
    munmap(base, SOC_SPAN);
    if (uio_fd >= 0) close(uio_fd);
    if (mem_fd >= 0) close(mem_fd);
    return 0;
}
