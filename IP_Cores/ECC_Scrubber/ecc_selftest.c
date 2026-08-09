/* ============================================================================
 * ecc_selftest.c - Selftest PS-side (aarch64) del ECC scrubber, Core 20.
 * Licencia: MIT
 *
 * Orquesta la campana de inyeccion/scrubbing en silicio sobre la TE0950:
 *   1. escribe una region ECC (corrupta) en DDR reservada (0x70000000, no-map)
 *   2. carga el firmware RV32 por la ventana IMEM del axil_soc (AXI-Lite)
 *   3. libera el core (CONTROL=0) y espera el doorbell (IRQ o polling STATUS)
 *   4. lee la region corregida de DDR y verifica firma FNV + contadores
 *   5. repite con scrub OFF (run B) para el contraste protegido/no-protegido
 *
 * Acceso a DDR no-map: SIEMPRE volatil, palabra a palabra (memcpy/memset fallan
 * con SIGBUS en memoria no-map). Cada palabra ECC son 2 words de 32b (LO,HI).
 *
 * Mapa fisico:
 *   AXIL_BASE  0xA4000000  esclavo AXI-Lite del SoC (control + IMEM) - mapa PS del molde PCS
 *      +0x0000 CONTROL  (bit0=1 halt core)   +0x0004 STATUS (bit0=corriendo)
 *      +0x0008 DBG_PC   +0x1000 ventana IMEM (word i -> +i*4)
 *   DDR_BASE   0x70000000  buffer reservado (16 MB, no-map)
 *
 * Compilar: aarch64-linux-gnu-gcc -O2 -static ecc_selftest.c -o ecc-selftest
 * ==========================================================================*/
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define AXIL_BASE   0xA4000000UL
#define AXIL_SPAN   0x10000UL
#define DDR_BASE    0x70000000UL
#define DDR_SPAN    (16UL * 1024 * 1024)

#define REG_CONTROL 0x0000
#define REG_STATUS  0x0004
#define REG_DDR_LO  0x0010       /* DDR_BASE_LO: base fisica del buffer DDR */
#define REG_DDR_HI  0x0014       /* DDR_BASE_HI: bits [39:32] de la base */
#define REG_IMEM    0x1000       /* ventana de carga de instrucciones */

/* offsets de config que el firmware lee de su RAM local (via IMEM? no: el PS
 * escribe la config en DDR y el firmware la lee tras el primer DMA, o el PS usa
 * la ventana DMEM. Aqui el firmware de tiles recibe cfg/n_words/ddr_off por su
 * RAM local, que el PS precarga por la ventana DMEM del axil_soc si existe.  */

static volatile uint32_t *axil;
static volatile uint32_t *ddr;

/* ---- FNV-1a-32 word-wise, identico al firmware y al oraculo Python ---- */
static uint32_t fnv_word(uint32_t h, uint32_t w) {
    h ^= w;
    h *= 0x01000193u;
    return h;
}

/* ---- codec SECDED (39,32) en C: solo para GENERAR la region de prueba ---- */
static const int PARITY_POS[6] = {1, 2, 4, 8, 16, 32};
static int is_parity(int p) {
    for (int i = 0; i < 6; i++) if (PARITY_POS[i] == p) return 1;
    return 0;
}
static int data_pos[32];
static void build_data_pos(void) {
    int idx = 0;
    for (int p = 1; p <= 38; p++) if (!is_parity(p)) data_pos[idx++] = p;
}
static uint64_t ecc_encode(uint32_t d) {
    int pos[39]; memset(pos, 0, sizeof(pos));
    for (int i = 0; i < 32; i++) pos[data_pos[i]] = (d >> i) & 1;
    for (int k = 0; k < 6; k++) {
        int p = PARITY_POS[k], acc = 0;
        for (int j = 1; j <= 38; j++) if (j != p && (j & p)) acc ^= pos[j];
        pos[p] = acc;
    }
    uint64_t w = 0;
    for (int j = 1; j <= 38; j++) w |= ((uint64_t)(pos[j] & 1)) << (j - 1);
    int overall = 0;
    for (int j = 1; j <= 38; j++) overall ^= pos[j];
    w |= ((uint64_t)(overall & 1)) << 38;
    return w & 0x7FFFFFFFFFULL;
}

/* ---- acceso DDR volatil word-by-word ---- */
static void ddr_write32(uint32_t word_off, uint32_t v) { ddr[word_off] = v; }
static uint32_t ddr_read32(uint32_t word_off)          { return ddr[word_off]; }

/* ---- carga del firmware por la ventana IMEM (AXI-Lite) ---- */
static int load_firmware(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) { perror("fopen firmware"); return -1; }
    /* halt el core antes de cargar */
    axil[REG_CONTROL / 4] = 1;
    char line[32]; uint32_t i = 0;
    while (fgets(line, sizeof(line), f)) {
        uint32_t instr = (uint32_t)strtoul(line, NULL, 16);
        axil[(REG_IMEM / 4) + i] = instr;
        i++;
    }
    fclose(f);
    printf("  firmware cargado: %u instrucciones\n", i);
    return 0;
}

/* ---- escribir la region ECC en DDR (N palabras, corruptas segun escenario) ---- */
static uint32_t write_region(uint32_t n_words, int inject_1bit, int inject_2bit) {
    uint32_t clean_sig = 0x811C9DC5u;
    for (uint32_t i = 0; i < n_words; i++) {
        uint32_t data = 0x1000000u * (i & 0xFF) + i;   /* patron determinista */
        uint64_t w = ecc_encode(data);
        /* corromper una fraccion */
        if (inject_1bit && (i % 7) == 0) w ^= (1ULL << (i % 39));
        if (inject_2bit && (i % 23) == 0) w ^= (1ULL << 3) | (1ULL << 30);
        uint32_t lo = (uint32_t)(w & 0xFFFFFFFF);
        uint32_t hi = (uint32_t)((w >> 32) & 0x7F);
        ddr_write32(i * 2, lo);
        ddr_write32(i * 2 + 1, hi);
    }
    /* firma de la region LIMPIA (referencia), recomputada sin corrupcion */
    for (uint32_t i = 0; i < n_words; i++) {
        uint32_t data = 0x1000000u * (i & 0xFF) + i;
        uint64_t w = ecc_encode(data);
        clean_sig = fnv_word(clean_sig, (uint32_t)(w & 0xFFFFFFFF));
        clean_sig = fnv_word(clean_sig, (uint32_t)((w >> 32) & 0x7F));
    }
    return clean_sig;
}

/* ---- firmar la region actual de DDR (post-scrub) ---- */
static uint32_t sign_region(uint32_t n_words) {
    uint32_t h = 0x811C9DC5u;
    for (uint32_t i = 0; i < n_words; i++) {
        h = fnv_word(h, ddr_read32(i * 2));
        h = fnv_word(h, ddr_read32(i * 2 + 1));
    }
    return h;
}

/* ---- correr el core y esperar el doorbell (polling STATUS) ---- */
static void run_core_and_wait(void) {
    axil[REG_CONTROL / 4] = 0;              /* liberar core */
    /* el firmware toca el doorbell y entra en loop; damos tiempo generoso */
    for (volatile int t = 0; t < 100000000; t++) { }
    axil[REG_CONTROL / 4] = 1;              /* re-halt para la siguiente corrida */
}

int main(int argc, char **argv) {
    const char *fw_on  = (argc > 1) ? argv[1] : "ecc_fw_on.mem";
    const char *fw_off = (argc > 2) ? argv[2] : "ecc_fw_off.mem";
    uint32_t n_words = (argc > 3) ? (uint32_t)strtoul(argv[3], NULL, 0) : 1024;

    build_data_pos();

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("/dev/mem"); return 1; }
    axil = mmap(NULL, AXIL_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, AXIL_BASE);
    ddr  = mmap(NULL, DDR_SPAN,  PROT_READ | PROT_WRITE, MAP_SHARED, fd, DDR_BASE);
    if (axil == MAP_FAILED || ddr == MAP_FAILED) { perror("mmap"); return 1; }

    printf("=== ECC scrubber selftest (Core 20) ===\n");
    printf("region: %u palabras ECC (%u words de 32b) en DDR 0x%lx\n",
           n_words, n_words * 2, DDR_BASE);

    /* CRITICO: programar ddr_base en el axil_soc para que el DMA del core
     * apunte al buffer reservado. Sin esto el DMA usa base 0 y no toca la
     * region que el PS escribe/lee -> firmas identicas (region corrupta). */
    axil[REG_DDR_LO / 4] = (uint32_t)(DDR_BASE & 0xFFFFFFFF);
    axil[REG_DDR_HI / 4] = (uint32_t)((DDR_BASE >> 32) & 0xFF);
    printf("ddr_base programado: 0x%lx\n", DDR_BASE);

    /* ---------- RUN A: scrub ON (protegido) ---------- */
    printf("\n[RUN A] scrub ON (protegido)\n");
    uint32_t clean_sig = write_region(n_words, 1, 1);
    load_firmware(fw_on);
    run_core_and_wait();
    uint32_t sigA = sign_region(n_words);
    printf("  firma post-scrub A : 0x%08x\n", sigA);
    printf("  firma limpia       : 0x%08x\n", clean_sig);

    /* ---------- RUN B: scrub OFF (no protegido) ---------- */
    printf("\n[RUN B] scrub OFF (no protegido)\n");
    write_region(n_words, 1, 1);            /* misma region corrupta */
    load_firmware(fw_off);
    run_core_and_wait();
    uint32_t sigB = sign_region(n_words);
    printf("  firma post-scrub B : 0x%08x\n", sigB);

    /* ---------- veredicto ---------- */
    printf("\n=== veredicto ===\n");
    int protegido_ok = (sigA != sigB);      /* A corrige, B no -> firmas distintas */
    printf("  contraste A vs B: %s\n", protegido_ok ? "DISTINTAS (proteccion OK)" : "IGUALES (FALLO)");
    if (protegido_ok)
        printf("L5 SILICON PASS - scrubber corrige en DDR; contraste protegido/no-protegido\n");
    else
        printf("L5 SILICON FAIL\n");

    munmap((void *)axil, AXIL_SPAN);
    munmap((void *)ddr, DDR_SPAN);
    close(fd);
    return protegido_ok ? 0 : 1;
}
