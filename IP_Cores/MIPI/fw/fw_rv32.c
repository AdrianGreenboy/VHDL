/* ============================================================================
 * HERCOSSNUX Core 18 - MIPI CSI-2 RX
 * L5 (silicon): RV32IM firmware - aligned to the soc_top_mipi architecture.
 *
 * Memory map seen by the core (dmem):
 *   0x00000000..  local RAM (DEPTH words). The doorbell is the DONE_WORD slot.
 *   0x40000000..  core DMA registers (unused here - the MIPI has its own DMA)
 *   0xD0000000..  MIPI CSI-2 RX peripheral (control + framebuffer streaming)
 *
 * MIPI register map (base 0xD0000000, offsets within):
 *   0x00 CTRL     W  bit0 start_selftest, bit1 start_dma
 *   0x04 STATUS   R  bit0 selftest_done, bit1 dma_done, bit2 hdr_2bit
 *   0x08 FB0_COUNT R
 *   0x0C FB1_COUNT R
 *   0x10 DMA_SRC  W  bit0 selects FB
 *   0x14 DMA_DST  W  DDR destination (low 32 bits of the DDR aperture)
 *   0x18 DMA_LEN  W  bytes
 *   0x1C FBSEL    W  bit0 selects FB, resets stream pointer
 *   0x20 FBDATA   R  current stream byte, auto-increments
 *
 * Doorbell: after computing the FNV signature the core writes it (and a status
 * word) into local RAM, then writes DONE_WORD. The soc_top_mipi decodes that
 * write as done_pulse -> axil_soc raises irq_sticky -> IRQ to the PS. The PS
 * then reads the result from local RAM via the axil_soc DMEM window (0x2000).
 *
 * Local RAM result layout (word indices):
 *   [125] signature (FNV-1a over FB0 || FB1)
 *   [126] status  (bit0 = hdr_2bit error)
 *   [127] DONE_WORD  (doorbell; written last)
 * ==========================================================================*/
#include <stdint.h>

#define MIPI_BASE   0xD0000000u
#define MREG(off)   (*(volatile uint32_t *)(MIPI_BASE + (off)))

#define M_CTRL      0x00
#define M_STATUS    0x04
#define M_FB0_COUNT 0x08
#define M_FB1_COUNT 0x0C
#define M_DMA_SRC   0x10
#define M_DMA_DST   0x14
#define M_DMA_LEN   0x18
#define M_FBSEL     0x1C
#define M_FBDATA    0x20

#define CTRL_START_ST   0x1u
#define CTRL_START_DMA  0x2u
#define ST_DONE         0x1u
#define ST_DMA_DONE     0x2u
#define ST_HDR2BIT      0x4u

/* core DMA registers (mem_subsys_dma), base 0x40000000 */
#define CDMA_BASE   0x40000000u
#define CREG(off)   (*(volatile uint32_t *)(CDMA_BASE + (off)))
#define CDMA_SRC    0x00
#define CDMA_DST    0x04
#define CDMA_LEN    0x08
#define CDMA_CTRL   0x0C   /* bit0 start, bit1 dir (1=local->DDR) */
#define CDMA_STATUS 0x10   /* bit0 busy (sticky) */

/* local RAM result slots (word addresses / byte addresses) */
#define LOCAL_RAM       ((volatile uint32_t *)0x00000000u)
#define SLOT_SIG        120     /* signature word */
#define SLOT_STATUS     121     /* status word (bit0 = hdr_2bit) */
#define SLOT_SIG_BYTE   (SLOT_SIG * 4)   /* byte address for the core DMA SRC */
#define DONE_WORD       127     /* doorbell; must match soc_top_mipi generic */
#define DONE_MAGIC      0x00C0FFEEu

/* DDR layout (offsets added to the PS-programmed DDR_BASE).
 * Result goes FIRST at a small offset so it fits the simulation DDR model
 * (axi_ddr_sim, 1024 words = 4 KB) on the core-DMA master; framebuffers follow
 * on the MIPI-DMA master. In silicon both masters share the same DDR, so these
 * offsets are disjoint by construction. */
#define DDR_RESULT_OFF  0x00000040u   /* signature + status (word 16) */
#define DDR_FB0_OFF     0x00001000u   /* FB0 image (18432 bytes) */
#define DDR_FB1_OFF     0x00009000u   /* FB1 image (18432 bytes) */

#define FNV_OFFSET  0x811C9DC5u
#define FNV_PRIME   0x01000193u

static uint32_t fold_fb(uint32_t h, int sel, int nbytes)
{
    MREG(M_FBSEL) = (uint32_t)(sel & 1);   /* select FB, reset stream pointer */
    (void)MREG(M_FBDATA);                  /* priming read (BRAM pipeline) */
    for (int i = 0; i < nbytes; i++) {
        uint8_t b = (uint8_t)(MREG(M_FBDATA) & 0xFF);
        h ^= b;
        h *= FNV_PRIME;
    }
    return h;
}

/* MIPI DMA: copy a framebuffer to DDR via the MIPI's own AXI master */
static void mipi_dma_copy(int sel, uint32_t ddr_off, int nbytes)
{
    MREG(M_DMA_SRC) = (uint32_t)(sel & 1);
    MREG(M_DMA_DST) = ddr_off;
    MREG(M_DMA_LEN) = (uint32_t)nbytes;
    MREG(M_CTRL)    = CTRL_START_DMA;
    while ((MREG(M_STATUS) & ST_DMA_DONE) == 0) { /* poll */ }
}

/* core DMA: copy 'nwords' words from local RAM (byte addr src_local) to DDR
 * (offset ddr_off from the PS-programmed DDR_BASE). dir=1 (local->DDR). */
static void core_dma_to_ddr(uint32_t src_local, uint32_t ddr_off, uint32_t nwords)
{
    CREG(CDMA_SRC)  = src_local;      /* local byte address */
    CREG(CDMA_DST)  = ddr_off;        /* DDR byte offset */
    CREG(CDMA_LEN)  = nwords;         /* 1..256 words */
    CREG(CDMA_CTRL) = 0x1u | 0x2u;    /* start + dir=local->DDR */
    while ((CREG(CDMA_STATUS) & 0x1u) != 0) { /* poll sticky busy */ }
}

int main(void)
{
    /* 1. run the self-test camera -> RX -> framebuffers */
    MREG(M_CTRL) = CTRL_START_ST;
    while ((MREG(M_STATUS) & ST_DONE) == 0) { /* poll */ }

    int n0 = (int)(MREG(M_FB0_COUNT) & 0x7FFF);
    int n1 = (int)(MREG(M_FB1_COUNT) & 0x7FFF);

    /* 2. fold FNV-1a over FB0 then FB1 (oracle order) */
    uint32_t sig = FNV_OFFSET;
    sig = fold_fb(sig, 0, n0);
    sig = fold_fb(sig, 1, n1);

    /* 3. DMA both framebuffers to DDR via the MIPI's own AXI master */
    mipi_dma_copy(0, DDR_FB0_OFF, n0);
    mipi_dma_copy(1, DDR_FB1_OFF, n1);

    /* 4. stage signature + status in local RAM (contiguous words) */
    LOCAL_RAM[SLOT_SIG]    = sig;
    LOCAL_RAM[SLOT_STATUS] = (MREG(M_STATUS) & ST_HDR2BIT) ? 1u : 0u;

    /* 5. copy the two result words to DDR via the CORE DMA (local->DDR) so the
     *    PS can read them from DDR (the axil DMEM window is not wired in v3). */
    core_dma_to_ddr(SLOT_SIG_BYTE, DDR_RESULT_OFF, 2);

    /* 6. ring the doorbell LAST: writing DONE_WORD raises done_pulse -> IRQ.
     *    All results are already in DDR before the PS is notified. */
    __asm__ volatile ("fence" ::: "memory");
    LOCAL_RAM[DONE_WORD] = DONE_MAGIC;

    for (;;) { /* halt; PS reads the result from DDR */ }
    return 0;
}
