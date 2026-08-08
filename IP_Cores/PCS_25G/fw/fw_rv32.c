/* ============================================================================
 * HERCOSSNUX Core 19 - PCS 64B/66B @ 25G
 * L5 (silicio): firmware RV32IM - alineado con la arquitectura soc_top_pcs.
 *
 * Mapa de memoria visto por el core (dmem):
 *   0x00000000..  RAM local (DEPTH palabras). El doorbell es la ranura DONE_WORD.
 *   0x40000000..  registros DMA del core (mem_subsys_dma) - local -> DDR
 *   0xD0000000..  banco AXI-Lite del PCS (via pcs_mmio_bridge)
 *
 * Mapa de registros del PCS (base 0xD0000000):
 *   0x00 ID          R  0x50435319
 *   0x08 CTRL        RW bit0 PCS_EN, bit1 TX_EN, bit2 RX_EN, bit3 LOOPBACK,
 *                       bit4 SCR_BYPASS, bit5 AUTO_RESYNC, bit6 (reservado)
 *   0x0C CMD         W  bit0 SOFT_RESET, bit1 RESYNC, bit2 CNT_CLEAR,
 *                       bit3 PRBS_RESET  (auto-clear)
 *   0x10 STATUS      R  bit0 BLOCK_LOCK, bit1 SCR_SYNC, bit2 HI_BER,
 *                       bit3 PRBS_LOCK, bit4 TX_ACTIVE, bit5 RX_ACTIVE
 *   0x14 IRQ_STATUS  R  sticky; bit4 EV_PRBS_ERR (W1C)
 *   0x1C PRBS_CTRL   RW bit0 GEN_EN, bit1 CHK_EN, bit2 INJ (auto-clear)
 *   0x20 STATS_SNAP  W  congela las sombras de contadores
 *   0x24 CNT_TX_BLK  R  (tras snapshot)
 *   0x28 CNT_RX_BLK  R
 *   0x30 CNT_BER     R  bits erroneos detectados por el checker PRBS31
 *
 * Secuencia del silicon pass (identica a tb_pcs_mmio / tb_pcs_stats_top, ambos
 * LAYER4*_PASS en simulacion):
 *   1. leer ID
 *   2. PRBS_CTRL = GEN_EN|CHK_EN
 *   3. CTRL = PCS_EN|TX_EN|RX_EN|LOOPBACK
 *   4. CMD = SOFT_RESET  (atomico: evita el arranque desalineado del gearbox RX
 *      por enables escalonados) -> esperar bring-up -> CMD = PRBS_RESET
 *   5. ventana limpia -> STATS_SNAP -> CNT_BER debe ser 0, CNT_TX/RX > 0,
 *      STATUS = 0x7D (block_lock|scr_sync|prbs_lock|tx_active|rx_active)
 *   6. PRBS_CTRL |= INJ (1 bit) -> STATS_SNAP -> CNT_BER debe ser 9
 *      (el bit corrupto se propaga por el descrambler self-synchronous:
 *       1 + 2 taps x 4 ventanas = 9 bits erroneos; verificado por el oraculo)
 *
 * Doorbell: los resultados se acumulan en RAM local, se copian a DDR por el DMA
 * del core, y por ultimo se escribe DONE_WORD -> done_pulse -> irq_out al PS.
 *
 * Distribucion de resultados en RAM local (indices de palabra):
 *   [118] ID leido
 *   [119] STATUS de la ventana limpia
 *   [120] CNT_TX_BLK limpio
 *   [121] CNT_RX_BLK limpio
 *   [122] CNT_BER limpio        (esperado 0)
 *   [123] CNT_BER tras inyeccion (esperado 9)
 *   [124] IRQ_STATUS tras inyeccion (bit4 esperado a 1)
 *   [125] firma de resultado (FNV-1a sobre las palabras [118..124])
 *   [126] status: bit0 ID ok, bit1 lock ok, bit2 BER limpio=0, bit3 BER inj=9
 *   [127] DONE_WORD (doorbell; se escribe al final)
 * ==========================================================================*/
#include <stdint.h>

#define PCS_BASE   0xD0000000u
#define PREG(off)  (*(volatile uint32_t *)(PCS_BASE + (off)))

#define P_ID         0x00
#define P_CTRL       0x08
#define P_CMD        0x0C
#define P_STATUS     0x10
#define P_IRQ_STATUS 0x14
#define P_PRBS_CTRL  0x1C
#define P_SNAP       0x20
#define P_CNT_TX     0x24
#define P_CNT_RX     0x28
#define P_CNT_BER    0x30

#define ID_MAGIC        0x50435319u

#define CTRL_PCS_EN     0x01u
#define CTRL_TX_EN      0x02u
#define CTRL_RX_EN      0x04u
#define CTRL_LOOPBACK   0x08u

#define CMD_SOFT_RESET  0x01u
#define CMD_PRBS_RESET  0x08u

#define ST_BLOCK_LOCK   0x01u
#define ST_PRBS_LOCK    0x08u
#define STATUS_EXPECTED 0x7Du

#define PRBS_GEN_EN     0x01u
#define PRBS_CHK_EN     0x02u
#define PRBS_INJ        0x04u

#define EV_PRBS_ERR     0x10u

#define BER_INJ_EXPECTED 9u

/* registros DMA del core (mem_subsys_dma), base 0x40000000 */
#define CDMA_BASE   0x40000000u
#define CREG(off)   (*(volatile uint32_t *)(CDMA_BASE + (off)))
#define CDMA_SRC    0x00
#define CDMA_DST    0x04
#define CDMA_LEN    0x08
#define CDMA_CTRL   0x0C   /* bit0 start, bit1 dir (1 = local->DDR) */
#define CDMA_STATUS 0x10   /* bit0 busy (sticky) */
/* IMPORTANTE (convencion de mem_subsys_dma, igual que en el Core 18):
     CDMA_SRC = direccion de BYTE en la RAM local
     CDMA_DST = OFFSET de BYTE dentro de la DDR (la base fisica la fija el PS
                en ddr_base via axil_soc; el firmware NO usa la absoluta)
     CDMA_LEN = numero de PALABRAS (1..256), no bytes                        */

/* RAM local vista como palabras */
#define LRAM        ((volatile uint32_t *)0x00000000u)
#define SLOT_ID      118
#define SLOT_STATUS  119
#define SLOT_TX      120
#define SLOT_RX      121
#define SLOT_BER0    122
#define SLOT_BER1    123
#define SLOT_IRQ     124
#define SLOT_SIG     125
#define SLOT_FLAGS   126
#define DONE_WORD    127

/* offset de resultados dentro de la DDR: 0x40 -> palabra 16 (igual que el
   Core 18). El PS suma su ddr_base fisica (0x70000000 en silicio). */
#define DDR_RESULT_OFF  0x00000040u
#define SLOT_ID_BYTE    (SLOT_ID * 4u)   /* origen local en bytes */
#define N_RESULT_WORDS  9u               /* [118..126]: ID..FLAGS */

/* Retardos: la variante SIM_FAST acorta las ventanas para que el testbench de
   GHDL corra en tiempo razonable. La logica y la secuencia son IDENTICAS; solo
   cambia la duracion de las ventanas de medida. El binario de silicio se
   compila SIN SIM_FAST. */
#ifdef SIM_FAST
#define D_BRINGUP   150u
#define D_WINDOW    1200u
#define D_SNAP      40u
#define D_INJ       500u
#else
#define D_BRINGUP   2000u
#define D_WINDOW    20000u
#define D_SNAP      200u
#define D_INJ       8000u
#endif

/* ---------------------------------------------------------------------------
 * WORKAROUND (bug del cpu_pipeline RV32, no del PCS):
 * El core pierde el SEGUNDO de dos 'lw' consecutivos cuando el primero estanca
 * el pipeline (region MMIO con dmem_ready diferido). Verificado en el Layer 5:
 * de las lecturas encadenadas del PCS, la 2a de cada rafaga nunca llega al bus
 * y el registro destino recibe dato residual.
 * Mitigacion: nunca encadenar lecturas MMIO; PCS_RD separa cada acceso con una
 * barrera de compilador + unos ciclos de trabajo no-MMIO.
 * PENDIENTE: corregir el hazard en cpu_pipeline (afecta a toda la familia).
 * ------------------------------------------------------------------------- */
static void delay_cycles(uint32_t n);

static uint32_t PCS_RD(uint32_t off)
{
    uint32_t v = *(volatile uint32_t *)(PCS_BASE + off);
    __asm__ volatile ("" ::: "memory");
    delay_cycles(2);
    return v;
}

static void delay_cycles(uint32_t n)
{
    /* bucle vacio con contador volatil: el compilador no puede eliminarlo.
       A 40 MHz (dominio del CPU) cada iteracion son ~4-6 ciclos. */
    volatile uint32_t i;
    for (i = 0; i < n; i++) { }
}

int main(void)
{
    uint32_t id, status, cnt_tx, cnt_rx, ber_clean, ber_inj, irq;
    uint32_t flags = 0;
    uint32_t sig, k;

    /* ---- 1. identificacion ---- */
    id = PCS_RD(P_ID);
    if (id == ID_MAGIC) flags |= 0x1u;

    /* ---- 2. configurar PRBS (generador + checker) ---- */
    PREG(P_PRBS_CTRL) = PRBS_GEN_EN | PRBS_CHK_EN;

    /* ---- 3. arrancar la cadena con loopback paralelo ---- */
    PREG(P_CTRL) = CTRL_PCS_EN | CTRL_TX_EN | CTRL_RX_EN | CTRL_LOOPBACK;

    /* ---- 4. SOFT_RESET atomico: todos los enables ya estables ----
       Sin esto el gearbox RX puede engancharse a mitad del periodo 32/33 y
       el framing queda corrupto (bug reproducido en simulacion). */
    PREG(P_CMD) = CMD_SOFT_RESET;
    delay_cycles(D_BRINGUP);      /* bring-up de la cadena */
    PREG(P_CMD) = CMD_PRBS_RESET; /* descartar el transitorio de enganche */

    /* ---- 5. ventana de medida limpia ---- */
    delay_cycles(D_WINDOW);
    PREG(P_SNAP) = 1u;
    delay_cycles(D_SNAP);         /* cruce CDC del snapshot */

    status    = PCS_RD(P_STATUS);
    cnt_tx    = PCS_RD(P_CNT_TX);
    cnt_rx    = PCS_RD(P_CNT_RX);
    ber_clean = PCS_RD(P_CNT_BER);

    if ((status & (ST_BLOCK_LOCK | ST_PRBS_LOCK)) ==
        (ST_BLOCK_LOCK | ST_PRBS_LOCK)) flags |= 0x2u;
    if (ber_clean == 0u && cnt_tx > 0u && cnt_rx > 0u) flags |= 0x4u;

    /* ---- 6. inyeccion de 1 bit -> el checker debe contar 9 ---- */
    PREG(P_PRBS_CTRL) = PRBS_GEN_EN | PRBS_CHK_EN | PRBS_INJ;
    delay_cycles(D_INJ);
    PREG(P_SNAP) = 1u;
    delay_cycles(D_SNAP);

    ber_inj = PCS_RD(P_CNT_BER);
    irq     = PCS_RD(P_IRQ_STATUS);

    if (ber_inj == BER_INJ_EXPECTED && (irq & EV_PRBS_ERR) != 0u) flags |= 0x8u;

    /* ---- resultados en RAM local ---- */
    LRAM[SLOT_ID]     = id;
    LRAM[SLOT_STATUS] = status;
    LRAM[SLOT_TX]     = cnt_tx;
    LRAM[SLOT_RX]     = cnt_rx;
    LRAM[SLOT_BER0]   = ber_clean;
    LRAM[SLOT_BER1]   = ber_inj;
    LRAM[SLOT_IRQ]    = irq;

    /* firma FNV-1a de 32 bits sobre las palabras de resultado [118..124],
       byte a byte en little-endian (mismo algoritmo que los oraculos) */
    sig = 2166136261u;
    for (k = SLOT_ID; k <= SLOT_IRQ; k++) {
        uint32_t w = LRAM[k];
        uint32_t b;
        for (b = 0; b < 4u; b++) {
            sig ^= (w >> (8u * b)) & 0xFFu;
            sig *= 16777619u;
        }
    }
    LRAM[SLOT_SIG]   = sig;
    LRAM[SLOT_FLAGS] = flags;

    /* ---- DMA de los resultados a la DDR ----
       9 palabras desde LRAM[118] al offset 0x40 de la DDR (palabra 16). */
    CREG(CDMA_SRC)  = SLOT_ID_BYTE;     /* byte local de LRAM[118] */
    CREG(CDMA_DST)  = DDR_RESULT_OFF;   /* OFFSET de byte en DDR */
    CREG(CDMA_LEN)  = N_RESULT_WORDS;   /* en PALABRAS */
    CREG(CDMA_CTRL) = 0x1u | 0x2u;      /* start | dir local->DDR */
    while ((CREG(CDMA_STATUS) & 0x1u) != 0u) { }   /* esperar fin (busy sticky) */

    /* ---- doorbell: ultimo escrito, dispara irq_out al PS ---- */
    LRAM[DONE_WORD] = 0xC0FFEE19u;

    for (;;) { }
    return 0;
}
