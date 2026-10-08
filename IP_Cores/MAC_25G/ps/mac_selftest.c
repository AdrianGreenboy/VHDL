/* ============================================================================
 * HERCOSSNUX Core 20 - MAC 25G
 * mac_selftest: programa del PS (Cortex-A72) para el silicon pass.
 *
 * Flujo (patron de la familia: firmware por IMEM, resultados por DMA + IRQ):
 *   1. halt del RV32 (axil_soc CONTROL=1), carga de fw_rv32.bin en IMEM
 *   2. DDR_BASE = 0x7000_0000 (zona no-map de 16 MB del device tree)
 *   3. limpiar doorbell y liberar el core
 *   4. sondear el doorbell (axil_soc IRQ, bit 0)
 *   5. leer las 24 palabras de DDR+0x40 y compararlas con el oraculo
 *      (oracle/expected_l5.py 100000); BURST_CYCLES se informa aparte
 *
 * Acceso a /dev/mem palabra a palabra con volatile: la ventana AXI-Lite y la
 * DDR no-map son memoria de dispositivo (memcpy/memset dan SIGBUS ahi).
 *
 * Compilar: aarch64-linux-gnu-gcc -O2 -static mac_selftest.c -o mac-selftest
 * Uso:      mac-selftest [fw_rv32.bin] [base_axil_soc_hex]
 *           (por defecto /lib/firmware/mac25g/fw_rv32.bin y 0xA4000000)
 * MIT License.
 * ==========================================================================*/
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#define SOC_SIZE   0x10000UL
#define DDR_BASE   0x70000000UL
#define DDR_SIZE   0x1000UL
#define R_CONTROL  0x0000
#define R_STATUS   0x0004
#define R_DBGPC    0x0008
#define R_IRQ      0x000C
#define R_DDRLO    0x0010
#define R_DDRHI    0x0014
#define W_IMEM     0x1000
#define RES_W      16          /* DDR+0x40 = palabra 16 */
#define NW         24
#define W_BURST    16          /* no determinista */

/* oracle/expected_l5.py 100000 (N = 100000 tramas, barrido 20..1514 paso 37) */
static const uint32_t EXP[NW] = {
    0x4D414320, 0x0000011D, 0x000186A0, 0x048F5C71, 0x000186A0, 0x048F5C71,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x000186A0, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0001869F,
    0x00000001, 0x00000001, 0x00000000, 0x00000003, 0x446C2628, 0x0000003F};
static const char *NAME[NW] = {
    "ID", "STATUS", "TX_FRAMES", "TX_BYTES", "RX_OK", "RX_BYTES", "RX_CRC_ERR",
    "RX_RUNT", "RX_OVERSIZE", "RX_ABORT", "RX_FILTERED", "RX_PROTO", "CHK_OK",
    "CHK_BAD", "CHK_SEQ_ERR", "CHK_RXERR", "BURST_CYCLES", "inj RX_OK",
    "inj RX_CRC_ERR", "inj CHK_RXERR", "inj SEQ|BAD<<16", "inj IRQ_STATUS",
    "firma FNV", "FLAGS"};

static volatile uint32_t *soc, *ddr;
static void wr(uint32_t o, uint32_t v) { soc[o / 4] = v; }
static uint32_t rd(uint32_t o) { return soc[o / 4]; }

int main(int argc, char **argv)
{
    const char *fwp = argc > 1 ? argv[1] : "/lib/firmware/mac25g/fw_rv32.bin";
    unsigned long base = argc > 2 ? strtoul(argv[2], NULL, 16) : 0xA4000000UL;
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }
    soc = mmap(NULL, SOC_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, base);
    ddr = mmap(NULL, DDR_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, DDR_BASE);
    if (soc == MAP_FAILED || ddr == MAP_FAILED) { perror("mmap"); return 1; }

    for (int i = 0; i < 64; i++) ddr[i] = 0;

    wr(R_CONTROL, 1);                                   /* halt */
    FILE *fp = fopen(fwp, "rb");
    if (!fp) { perror(fwp); return 1; }
    uint32_t w, n = 0;
    while (fread(&w, 4, 1, fp) == 1) wr(W_IMEM + 4 * n++, w);
    fclose(fp);
    printf("firmware cargado: %u palabras (%s)\n", n, fwp);
    wr(R_DDRLO, (uint32_t)(DDR_BASE & 0xFFFFFFFFu));
    wr(R_DDRHI, (uint32_t)(DDR_BASE >> 32));
    wr(R_IRQ, 1);                                       /* limpiar doorbell */
    wr(R_CONTROL, 0);                                   /* soltar el core */

    uint32_t polls = 0;
    while (!(rd(R_IRQ) & 1u) && polls < 50000000u) polls++;
    if (!(rd(R_IRQ) & 1u)) {
        printf("FALLO: sin doorbell (PC=0x%08X STATUS=0x%08X)\n", rd(R_DBGPC), rd(R_STATUS));
        return 1;
    }
    printf("doorbell  : recibido (%u sondeos)\n\n", polls);
    printf("=== Core 20 - MAC 25G (64B/66B cl.49) - silicon pass ===\n");

    int ok = 1;
    uint32_t got[NW];
    for (int i = 0; i < NW; i++) {
        got[i] = ddr[RES_W + i];
        if (i == W_BURST) {
            printf("%-16s: %u (no determinista)\n", NAME[i], got[i]);
            continue;
        }
        int m = (got[i] == EXP[i]);
        if (!m) ok = 0;
        printf("%-16s: 0x%08X (%10u)  esperado 0x%08X %s\n", NAME[i], got[i], got[i],
               EXP[i], m ? "" : "<-- DISTINTO");
    }
    /* rendimiento medido en el banco: gearbox de fabric a 390.625 MHz */
    double secs = got[W_BURST] / 390.625e6;
    double gbps = secs > 0 ? got[3] * 8.0 / secs / 1e9 : 0.0;
    printf("\nrafaga de %u tramas en %u ciclos de clk_dp (%.3f ms): L2+FCS = %.2f Gb/s\n",
           got[2], got[W_BURST], secs * 1e3, gbps);
    printf("(teorico del banco 23.52 Gb/s; en 25GBASE-R real el MAC da 24.26 Gb/s)\n\n");
    printf(ok ? "L5 SILICON PASS - MAC 25G operativo a 390.625 MHz\n"
              : "L5 SILICON FAIL\n");
    return ok ? 0 : 1;
}
