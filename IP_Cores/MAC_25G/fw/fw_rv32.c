/* ============================================================================
 * HERCOSSNUX Core 20 - MAC 25G
 * L5: firmware RV32IM del silicon pass (arquitectura soc_top_mac).
 *
 * Mapa visto por el core (dmem):
 *   0x00000000..  RAM local (256 palabras). Doorbell = palabra DONE_WORD.
 *   0x40000000..  DMA del core (mem_subsys_dma) local -> DDR
 *   0xD0000000..  banco AXI-Lite del MAC (via pcs_mmio_bridge)
 *
 * Secuencia (identica a tb_mac_top, LAYER4_PASS / LAYER4MMIO_PASS):
 *   1. ID
 *   2. configuracion: MAC propia/origen, barrido 20..1514 paso 37, N tramas
 *   3. CTRL = MAC_EN | LOOPBACK ; CMD = SOFT_RESET (captura config) ; LINK_UP
 *   4. rafaga limpia: CNT_CLEAR, GEN_START, GEN_DONE, drenaje, SNAP
 *      -> TX_FRAMES = RX_OK = CHK_OK = N, RX_BYTES = TX_BYTES, errores = 0
 *   5. rafaga con 1 bit inyectado en la trama 0: CNT_CLEAR, GEN_START|INJ
 *      -> RX_OK = CHK_OK = N-1, RX_CRC_ERR = CHK_RXERR = 1, CHK_SEQ_ERR = 0
 *      (el CRC detecta exactamente esa trama; la secuencia sigue intacta)
 *   6. resultados -> RAM local -> DMA a DDR+0x40 -> doorbell
 *
 * A diferencia del Core 19, TODOS los contadores son deterministas (rafaga de
 * N tramas, no ventana de tiempo): la firma FNV de silicio es predecible por
 * el oraculo (python3 oracle/expected_l5.py). Solo BURST_CYCLES depende de la
 * fase del gearbox y queda fuera de la firma.
 *
 * Resultados en RAM local (indice de palabra), DMA de 24 palabras a DDR+0x40:
 *   [103] ID                        [104] STATUS tras la rafaga limpia
 *   [105..118] contadores 0..13 de la rafaga limpia (TX_FRAMES..CHK_RXERR)
 *   [119] BURST_CYCLES limpia       [120] RX_OK  (inyeccion)
 *   [121] RX_CRC_ERR (inyeccion)    [122] CHK_RXERR (inyeccion)
 *   [123] CHK_SEQ_ERR | CHK_BAD<<16 (inyeccion)
 *   [124] IRQ_STATUS tras inyeccion [125] FNV-1a de [103..124] salvo [119]
 *   [126] FLAGS (esperado 0x3F)     [127] doorbell
 * ==========================================================================*/
#include <stdint.h>

#define MAC_BASE   0xD0000000u
#define MREG(off)  (*(volatile uint32_t *)(MAC_BASE + (off)))

#define R_ID      0x00
#define R_CTRL    0x08
#define R_CMD     0x0C
#define R_STATUS  0x10
#define R_IRQST   0x14
#define R_SNAP    0x1C
#define R_MAC_LO  0x20
#define R_MAC_HI  0x24
#define R_SRC_LO  0x28
#define R_SRC_HI  0x2C
#define R_LEN     0x30
#define R_STEP    0x34
#define R_COUNT   0x38
#define R_CNT(i)  (0x40 + 4u * (i))

#define ID_MAGIC  0x4D414320u
#define CTRL_RUN  0x3u            /* MAC_EN | LOOPBACK */
#define CMD_SOFT  0x01u
#define CMD_CLR   0x02u
#define CMD_START 0x04u
#define CMD_INJ   0x10u
#define ST_LINK   0x001u
#define ST_DONE   0x004u
#define ST_SNAP   0x100u

enum { C_TXF, C_TXB, C_RXOK, C_RXB, C_CRC, C_RUNT, C_OVER, C_ABORT, C_FILT,
       C_PROTO, C_CHKOK, C_CHKBAD, C_SEQ, C_RXERR, C_BURST, C_UNDER };

#ifdef SIM_FAST
#define NFRAMES   64u
#define TMO       200000u
#else
#define NFRAMES   100000u
#define TMO       20000000u
#endif

/* DMA del core */
#define CREG(off)   (*(volatile uint32_t *)(0x40000000u + (off)))
#define LRAM        ((volatile uint32_t *)0x00000000u)
#define SLOT0       103u
#define NSLOT       24u
#define DONE_WORD   127u

/* sin variables globales (no hay .data/.bss en este mapa Harvard): las
   banderas viven directamente en su ranura de resultado de la RAM local */
#define flags (LRAM[SLOT0 + 23u])

static void cmd(uint32_t c)
{
    MREG(R_CMD) = c;   /* el banco retiene la escritura si hay otro CMD en vuelo */
}

static uint32_t wait_bit(uint32_t mask)
{
    uint32_t t, s = 0;
    for (t = 0; t < TMO; t++) {
        s = MREG(R_STATUS);
        if (s & mask) return s;
    }
    flags &= ~0x20u;   /* timeout */
    return s;
}

static void burst(uint32_t c)
{
    volatile uint32_t d;
    cmd(CMD_CLR);
    cmd(c);
    wait_bit(ST_DONE);
    for (d = 0; d < 64u; d++) { }        /* drenaje (~5 us a 40 MHz) */
    MREG(R_SNAP) = 1u;
    wait_bit(ST_SNAP);
}

int main(void)
{
    uint32_t i, k, s, sig;
    volatile uint32_t *r = &LRAM[SLOT0];

    flags = 0x20u;

    r[0] = MREG(R_ID);
    if (r[0] == ID_MAGIC) flags |= 0x1u;

    /* configuracion (valores del oraculo: GenCfg por defecto) */
    MREG(R_MAC_LO) = 0x43414D02u;  MREG(R_MAC_HI) = 0x2032u;
    MREG(R_SRC_LO) = 0x45474E02u;  MREG(R_SRC_HI) = 0x204Eu;
    MREG(R_LEN)    = (1514u << 16) | 20u;
    MREG(R_STEP)   = 37u;
    MREG(R_COUNT)  = NFRAMES;
    MREG(R_CTRL)   = CTRL_RUN;
    cmd(CMD_SOFT);
    if (wait_bit(ST_LINK) & ST_LINK) flags |= 0x2u;

    /* ---- rafaga limpia ---- */
    burst(CMD_START);
    r[1] = MREG(R_STATUS);
    for (i = 0; i <= C_RXERR; i++) r[2 + i] = MREG(R_CNT(i));
    r[16] = MREG(R_CNT(C_BURST));
    if (r[2 + C_TXF] == NFRAMES && r[2 + C_RXOK] == NFRAMES &&
        r[2 + C_CHKOK] == NFRAMES && r[2 + C_RXB] == r[2 + C_TXB] &&
        (r[2 + C_CRC] | r[2 + C_RUNT] | r[2 + C_OVER] | r[2 + C_ABORT] |
         r[2 + C_FILT] | r[2 + C_PROTO] | r[2 + C_CHKBAD] | r[2 + C_SEQ] |
         r[2 + C_RXERR]) == 0u)
        flags |= 0x4u;
    MREG(R_IRQST) = 0xFu;                /* limpiar stickies */

    /* ---- rafaga con 1 bit inyectado ---- */
    burst(CMD_START | CMD_INJ);
    r[17] = MREG(R_CNT(C_RXOK));
    r[18] = MREG(R_CNT(C_CRC));
    r[19] = MREG(R_CNT(C_RXERR));
    r[20] = MREG(R_CNT(C_SEQ)) | (MREG(R_CNT(C_CHKBAD)) << 16);
    r[21] = MREG(R_IRQST);
    if (r[17] == NFRAMES - 1u && r[18] == 1u && r[19] == 1u && r[20] == 0u)
        flags |= 0x8u;
    if ((r[21] & 0x3u) == 0x3u) flags |= 0x10u;   /* GEN_DONE | RX_CRC_ERR */

    /* firma FNV-1a sobre [0..21] salvo BURST_CYCLES ([16]) */
    sig = 2166136261u;
    for (k = 0; k < 22u; k++) {
        if (k == 16u) continue;
        s = r[k];
        for (i = 0; i < 4u; i++) {
            sig ^= (s >> (8u * i)) & 0xFFu;
            sig *= 16777619u;
        }
    }
    r[22] = sig;
    r[23] = flags;

    /* DMA de 24 palabras al offset 0x40 de la DDR */
    CREG(0x00) = SLOT0 * 4u;    /* origen: byte en RAM local */
    CREG(0x04) = 0x40u;         /* destino: offset de byte en DDR */
    CREG(0x08) = NSLOT;         /* palabras */
    CREG(0x0C) = 0x3u;          /* start | local->DDR */
    while (CREG(0x10) & 0x1u) { }

    LRAM[DONE_WORD] = 0xC0FFEE20u;   /* doorbell */
    for (;;) { }
    return 0;
}
