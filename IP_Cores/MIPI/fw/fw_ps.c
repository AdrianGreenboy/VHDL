/* ============================================================================
 * HERCOSSNUX Core 18 - MIPI CSI-2 RX
 * L5 (silicon): PS-side (A72 / PetaLinux) verification program.
 * Aligned to the real axil_soc control interface.
 *
 * AXI-Lite SoC map (base 0xA4000000, 64 KB):
 *   0x0000 CONTROL  bit0=1 halt (core held in reset)
 *   0x0004 STATUS   bit0 = core running
 *   0x0008 DBG_PC
 *   0x000C IRQ      bit0 = sticky doorbell; write 1 to clear
 *   0x0010 DDR_BASE_LO
 *   0x0014 DDR_BASE_HI
 *   0x1000 IMEM window (one word per address)
 *   0x2000 DMEM window (one word per address - local RAM read-back)
 *
 * Flow:
 *   1. halt the core (CONTROL.bit0 = 1)
 *   2. program the physical DDR base for the MIPI/core DMA
 *   3. load the RV32 firmware into IMEM through the 0x1000 window
 *   4. release the core (CONTROL.bit0 = 0)
 *   5. poll the IRQ register (doorbell) until the core signals done
 *   6. read the signature + status from local RAM via the DMEM window (0x2000)
 *   7. verify against the golden 0xE6898DC5, then clear the IRQ
 *
 * CRITICAL: the AXI-Lite aperture is device memory; access word-by-word with
 * volatile (never memcpy/memset). The DMEM window returns local-RAM words.
 * ==========================================================================*/
#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <stdlib.h>

#define AXIL_BASE   0xA4000000u
#define AXIL_SIZE   0x00010000u

#define REG_CONTROL 0x0000
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C
#define REG_DDRLO   0x0010
#define REG_DDRHI   0x0014
#define WIN_IMEM    0x1000
#define WIN_DMEM    0x2000

#define GOLDEN_SIG  0xE6898DC5u

/* result slots in local RAM (word indices), must match the RV32 firmware */
#define SLOT_SIG     125
#define SLOT_STATUS  126
#define SLOT_DONE    127
#define DONE_MAGIC   0x00C0FFEEu

/* physical DDR base for the DMA buffer (0x70000000, 16 MB no-map) */
#define DDR_PHYS_LO  0x70000000u
#define DDR_PHYS_HI  0x00000000u
#define DDR_MAP_SIZE 0x00020000u          /* map low 128 KB where results live */
#define DDR_RESULT_OFF 0x00000040u        /* must match RV32 firmware */

static inline void wr32(volatile uint8_t *b, uint32_t o, uint32_t v) {
    *(volatile uint32_t *)(b + o) = v;
}
static inline uint32_t rd32(volatile uint8_t *b, uint32_t o) {
    return *(volatile uint32_t *)(b + o);
}

int main(int argc, char **argv)
{
    const char *fw_path = (argc > 1) ? argv[1] : "fw_rv32.bin";

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }

    volatile uint8_t *axil = mmap(NULL, AXIL_SIZE, PROT_READ | PROT_WRITE,
                                  MAP_SHARED, fd, AXIL_BASE);
    if (axil == MAP_FAILED) { perror("mmap axil"); return 1; }

    /* 1. halt the core */
    wr32(axil, REG_CONTROL, 0x1);

    /* 2. program the physical DDR base for the DMA */
    wr32(axil, REG_DDRLO, DDR_PHYS_LO);
    wr32(axil, REG_DDRHI, DDR_PHYS_HI);

    /* 3. load the RV32 firmware into IMEM word-by-word */
    FILE *f = fopen(fw_path, "rb");
    if (!f) { perror("fopen firmware"); return 1; }
    uint32_t word; int i = 0;
    while (fread(&word, 4, 1, f) == 1) {
        wr32(axil, WIN_IMEM + (uint32_t)(i * 4), word);
        i++;
    }
    fclose(f);
    printf("loaded %d firmware words\n", i);

    /* clear any stale doorbell before releasing the core */
    wr32(axil, REG_IRQ, 0x1);

    /* 4. release the core */
    wr32(axil, REG_CONTROL, 0x0);

    /* 5. poll the doorbell (IRQ sticky bit) with a generous timeout */
    uint32_t irq = 0;
    long spins = 0;
    const long MAX_SPINS = 200000000L;
    do {
        irq = rd32(axil, REG_IRQ) & 0x1;
        spins++;
    } while (irq == 0 && spins < MAX_SPINS);

    if (irq == 0) {
        printf("TIMEOUT: doorbell never fired (DBG_PC=0x%08X)\n",
               rd32(axil, REG_DBGPC));
        return 2;
    }

    /* 6. read the result from DDR (the core DMA'd signature+status there).
     *    The DDR result region is device-mapped no-map: access word-by-word
     *    with volatile (never memcpy). */
    volatile uint8_t *ddr = mmap(NULL, DDR_MAP_SIZE, PROT_READ | PROT_WRITE,
                                 MAP_SHARED, fd, DDR_PHYS_LO);
    if (ddr == MAP_FAILED) { perror("mmap ddr"); return 1; }

    uint32_t sig    = rd32(ddr, DDR_RESULT_OFF + 0);
    uint32_t status = rd32(ddr, DDR_RESULT_OFF + 4);

    printf("doorbell  : fired (%ld spins)\n", spins);
    printf("signature : 0x%08X (golden 0x%08X)\n", sig, GOLDEN_SIG);
    printf("hdr_2bit  : %u\n", status & 1u);

    /* 7. clear the IRQ */
    wr32(axil, REG_IRQ, 0x1);

    if (sig == GOLDEN_SIG && (status & 1u) == 0) {
        printf("L5 SILICON PASS\n");
        return 0;
    } else {
        printf("L5 SILICON FAIL\n");
        return 3;
    }
}
