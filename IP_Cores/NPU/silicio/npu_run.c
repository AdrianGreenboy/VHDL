/*
 * HERCOSSNUX NPU - binario de bring-up en silicio.
 *
 * Carga pesos e imagenes en el buffer de DDR, dispara la inferencia por el
 * registro de control, y comprueba que la firma de clases coincide con la
 * congelada en simulacion:
 *
 *   8 imagenes  -> SIG_CLASE = 0x6084FD2A
 *
 * Si la firma coincide, el silicio reproduce exactamente el comportamiento
 * verificado en las cinco capas.
 *
 * CUIDADO CON LA REGION no-map: glibc aarch64 implementa memset y memcpy
 * con DC ZVA y stp de 128 bits, que fallan con SIGBUS sobre memoria no
 * mapeada por el kernel. Todo acceso al buffer se hace con bucles palabra
 * a palabra sobre punteros volatile. No usar memcpy/memset aqui.
 *
 * Compilar:
 *   aarch64-linux-gnu-gcc -O2 -static -o npu_run npu_run.c
 *
 * Ejecutar como root en la placa:
 *   ./npu_run pesos.bin imagenes.bin
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <time.h>

/* Mapa congelado en npu_axi_pkg.vhd */
#define DDR_BASE      0x70000000UL
#define DDR_SIZE      0x01000000UL      /* 16 MB */
#define REG_BASE      0x80000000UL
#define REG_SIZE      0x10000UL

#define OFF_W1        0x00000
#define OFF_B1        0x00100
#define OFF_W2        0x01000
#define OFF_B2        0x01800
#define OFF_W3        0x02000
#define OFF_B3        0x02C00
#define OFF_IMG       0x10000
#define OFF_RES       0x20000

#define N_W1          72
#define N_B1          8
#define N_W2          1152
#define N_B2          16
#define N_W3          2560
#define N_B3          10
#define N_IMG         256

/* Registros */
#define REG_CTRL      0x00
#define REG_STATUS    0x04
#define REG_ID        0x08
#define REG_BASE_R    0x0C
#define REG_ERRCODE   0x10

#define CTRL_START    0x1
#define CTRL_LOADW    0x2

#define ST_BUSY       0x1
#define ST_DONE       0x2
#define ST_ERROR      0x4

#define NPU_ID        0x4E505531UL

#define SIG_INIT      0x811C9DC5UL
#define SIG_PRIME     0x01000193UL

static volatile uint32_t *regs;
static volatile uint8_t  *ddr;

/* --- acceso seguro a la region no-map ---------------------------------- */

/* Escritura byte a byte. No usar memcpy: DC ZVA falla con SIGBUS. */
static void ddr_write_bytes(unsigned long off, const uint8_t *src, size_t n)
{
    volatile uint8_t *d = ddr + off;
    for (size_t i = 0; i < n; i++)
        d[i] = src[i];
}

/* Los bias son int32 little endian. Se escriben byte a byte por la misma
   razon: cualquier acceso ancho puede disparar SIGBUS. */
static void ddr_write_int32(unsigned long off, const int32_t *src, size_t n)
{
    volatile uint8_t *d = ddr + off;
    for (size_t i = 0; i < n; i++) {
        uint32_t u = (uint32_t)src[i];
        d[4*i + 0] = (uint8_t)( u        & 0xFF);
        d[4*i + 1] = (uint8_t)((u >>  8) & 0xFF);
        d[4*i + 2] = (uint8_t)((u >> 16) & 0xFF);
        d[4*i + 3] = (uint8_t)((u >> 24) & 0xFF);
    }
}

static void ddr_read_bytes(unsigned long off, uint8_t *dst, size_t n)
{
    volatile uint8_t *s = ddr + off;
    for (size_t i = 0; i < n; i++)
        dst[i] = s[i];
}

/* --- registros --------------------------------------------------------- */

static uint32_t reg_read(unsigned off)
{
    return regs[off / 4];
}

static void reg_write(unsigned off, uint32_t v)
{
    regs[off / 4] = v;
}

/* Espera a que STATUS.done se ponga a 1. Devuelve 0 si termino, -1 si
   agoto el tiempo. */
static int esperar_done(unsigned long max_iter)
{
    for (unsigned long i = 0; i < max_iter; i++) {
        uint32_t st = reg_read(REG_STATUS);
        if (st & ST_ERROR) {
            fprintf(stderr, "NPU reporto error, ERRCODE=0x%X\n",
                    reg_read(REG_ERRCODE));
            return -1;
        }
        if (st & ST_DONE)
            return 0;
    }
    return -1;
}

static uint32_t sig_update(uint32_t s, uint8_t v)
{
    return (uint32_t)((uint64_t)s * SIG_PRIME + v);
}

/* --- programa ---------------------------------------------------------- */

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "uso: %s pesos.bin imagenes.bin [n_imagenes]\n",
                argv[0]);
        return 1;
    }
    int n_img = (argc > 3) ? atoi(argv[3]) : 8;

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }

    void *m_regs = mmap(NULL, REG_SIZE, PROT_READ | PROT_WRITE,
                        MAP_SHARED, fd, REG_BASE);
    if (m_regs == MAP_FAILED) { perror("mmap registros"); return 1; }
    regs = (volatile uint32_t *)m_regs;

    void *m_ddr = mmap(NULL, DDR_SIZE, PROT_READ | PROT_WRITE,
                       MAP_SHARED, fd, DDR_BASE);
    if (m_ddr == MAP_FAILED) { perror("mmap ddr"); return 1; }
    ddr = (volatile uint8_t *)m_ddr;

    /* 1. comprobar que la NPU responde */
    uint32_t id = reg_read(REG_ID);
    printf("ID leido: 0x%08X (esperado 0x%08lX)\n", id, NPU_ID);
    if (id != NPU_ID) {
        fprintf(stderr, "FALLO: la NPU no responde con su ID.\n");
        fprintf(stderr, "  Revisa que el PDI cargado sea el correcto.\n");
        return 1;
    }

    /* 2. cargar los pesos desde el fichero */
    FILE *fw = fopen(argv[1], "rb");
    if (!fw) { perror("fopen pesos"); return 1; }

    static uint8_t w1[N_W1], w2[N_W2], w3[N_W3];
    static int32_t b1[N_B1], b2[N_B2], b3[N_B3];

    if (fread(w1, 1, N_W1, fw) != N_W1 ||
        fread(b1, 4, N_B1, fw) != N_B1 ||
        fread(w2, 1, N_W2, fw) != N_W2 ||
        fread(b2, 4, N_B2, fw) != N_B2 ||
        fread(w3, 1, N_W3, fw) != N_W3 ||
        fread(b3, 4, N_B3, fw) != N_B3) {
        fprintf(stderr, "FALLO: el fichero de pesos esta incompleto.\n");
        return 1;
    }
    fclose(fw);

    ddr_write_bytes(OFF_W1, w1, N_W1);
    ddr_write_int32(OFF_B1, b1, N_B1);
    ddr_write_bytes(OFF_W2, w2, N_W2);
    ddr_write_int32(OFF_B2, b2, N_B2);
    ddr_write_bytes(OFF_W3, w3, N_W3);
    ddr_write_int32(OFF_B3, b3, N_B3);
    printf("Pesos escritos en DDR.\n");

    /* 3. fijar la base y disparar la carga de pesos */
    reg_write(REG_BASE_R, (uint32_t)DDR_BASE);
    reg_write(REG_CTRL, CTRL_LOADW);
    if (esperar_done(100000000UL) < 0) {
        fprintf(stderr, "FALLO: la carga de pesos no termino.\n");
        return 1;
    }
    printf("Pesos cargados por DMA.\n");

    /* 4. inferencia imagen a imagen */
    FILE *fi = fopen(argv[2], "rb");
    if (!fi) { perror("fopen imagenes"); return 1; }

    uint32_t sig = SIG_INIT;
    static uint8_t img[N_IMG];
    struct timespec t0, t1;

    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (int n = 0; n < n_img; n++) {
        if (fread(img, 1, N_IMG, fi) != N_IMG) {
            fprintf(stderr, "FALLO: faltan imagenes en el fichero (n=%d).\n", n);
            return 1;
        }
        ddr_write_bytes(OFF_IMG, img, N_IMG);

        reg_write(REG_CTRL, CTRL_START);
        if (esperar_done(100000000UL) < 0) {
            fprintf(stderr, "FALLO: la inferencia %d no termino.\n", n);
            return 1;
        }
        uint32_t st = reg_read(REG_STATUS);
        uint8_t clase = (uint8_t)((st >> 4) & 0xF);
        sig = sig_update(sig, clase);
        printf("  imagen %d -> clase %u\n", n, clase);
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    fclose(fi);

    double ms = (t1.tv_sec - t0.tv_sec) * 1000.0
              + (t1.tv_nsec - t0.tv_nsec) / 1e6;

    printf("\n");
    printf("Imagenes    : %d\n", n_img);
    printf("Tiempo total: %.2f ms  (%.3f ms por imagen)\n", ms, ms / n_img);
    printf("SIG_CLASE   : 0x%08X\n", sig);

    if (n_img == 8) {
        if (sig == 0x6084FD2AUL) {
            printf("\nNPU SILICIO OK SIG_CLASE=0x6084FD2A\n");
        } else {
            printf("\nFALLO: la firma no coincide con la de simulacion.\n");
            printf("  esperada 0x6084FD2A, obtenida 0x%08X\n", sig);
            return 1;
        }
    }
    return 0;
}
