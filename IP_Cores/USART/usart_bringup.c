// ============================================================================
//  usart_bringup.c  -  Bring-up del IP USART en el TE0950
//  Licencia: MIT
//
//  El A72 (Linux, /dev/mem) carga usart_test en la IMEM del RV32, llena el
//  buffer TX en la DDR con el patron incremental, fija DDR_BASE, suelta el
//  core y espera el doorbell. El RV32 hace: PIO de 2 bytes + DMA USART de
//  32 bytes con los DOS canales concurrentes + reporte via dma_burst. El
//  A72 verifica el reporte y el eco.
//
//  Modo int (default): loopback interno CTRL[7], cero hardware -> triple
//  PASS parcheando el BAUD:  usart-bringup 115200 ; usart-bringup 921600 ;
//  usart-bringup 3000000
//  Modo ext: pads reales; REQUISITO FISICO: jumper D10 (TXD) -> C10 (RXD)
//  del CRUVI LS1 via CR00025 (el MISMO jumper del loopback del SPI).
//
//  Compilar (SDK de PetaLinux, cross aarch64):  $CC usart_bringup.c -o usart-bringup
//  Ejecutar (root):  ./usart-bringup [baud] [int|ext] [ddr_phys_hex]
//     baud:     default 115200; K = baud*16*2^32/100e6 se parchea en el par
//               lui+addi del programa (BAUD de 32 bits)
//     ddr_phys: base fisica del buffer (default 0x70000000, pool no-map)
//
//  El esclavo AXI-Lite quedo en 0x8000_0000 (leccion del SPI, ventana baja
//  del M_AXI_LPD).
// ============================================================================
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define SOC_BASE   0x80000000UL
#define SOC_SPAN   0x10000UL

#define REG_CONTROL 0x0000     // bit0 = 1 -> core en reset (halt)
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C     // sticky del doorbell
#define REG_DDRB_LO 0x0010
#define REG_DDRB_HI 0x0014
#define OFF_IMEM    0x1000

// usart_test.s ensamblado (47 palabras, salida de asm.py).
// Parcheables: prog[2] = lui  x5, BAUD[31:12]   (base 0x000002B7)
//              prog[3] = addi x5, x5, BAUD[11:0] (base 0x00028293)
//              prog[5] = addi x5, x0, IDLE_TO    (base 0x00000293)
//              prog[7] = addi x5, x0, CTRL       (base 0x00000293)
static uint32_t prog[] = {
    0x600000B7, 0x40000137, 0x51EB82B7, 0x51F28293,
    0x0050A423, 0x01400293, 0x0250A423, 0x08700293,
    0x0050A023, 0x05A00293, 0x0050A623, 0x0C300293,
    0x0050A623, 0x00200393, 0x0180A303, 0xFE731EE3,
    0x0180A403, 0x00802023, 0x0100A483, 0x00902223,
    0x0100A483, 0x00902423, 0x0200A823, 0x02000293,
    0x0250AA23, 0x10000293, 0x0250AC23, 0x02000293,
    0x0250AE23, 0x00300293, 0x0450A023, 0x00F00393,
    0x00C00413, 0x0440A303, 0x00737333, 0xFE831CE3,
    0x53900293, 0x00502623, 0x00012023, 0x00012223,
    0x00400293, 0x00512423, 0x00300293, 0x00512623,
    0x01012303, 0xFE031EE3, 0x00000063,
};
#define PROG_WORDS (sizeof(prog)/sizeof(prog[0]))

static volatile uint32_t *soc;
static volatile uint8_t  *ddr;

static inline void     wr(unsigned off, uint32_t v) { soc[off/4] = v; }
static inline uint32_t rd(unsigned off)             { return soc[off/4]; }
static inline uint32_t ddr_w(unsigned widx)
{ return ((volatile uint32_t*)ddr)[widx]; }

int main(int argc, char **argv)
{
    unsigned baud     = (argc > 1) ? (unsigned)strtoul(argv[1], NULL, 0) : 115200;
    int      ext      = (argc > 2 && strcmp(argv[2], "ext") == 0);
    uint64_t ddr_phys = (argc > 3) ? strtoull(argv[3], NULL, 16) : 0x70000000ULL;
    if (baud < 300 || baud > 6000000) {
        fprintf(stderr, "baud 300..6000000 (el NCO topa en clk/16 = 6.25M)\n");
        return 1;
    }

    // K del NCO: baud * 16 * 2^32 / 100e6 = baud * 2^36 / 1e8 (redondeado)
    uint32_t k = (uint32_t)((((uint64_t)baud << 36) + 50000000ULL) / 100000000ULL);

    // parchea BAUD (par lui+addi con ajuste de signo del addi), CTRL
    uint32_t lo = k & 0xFFFu;
    uint32_t hi = (k >> 12) + ((k >> 11) & 1u);   // compensa sign-extension
    unsigned ctrl = ext ? 0x07u : 0x87u;          // ext: pads; int: loop_int
    prog[2] = 0x000002B7u | (hi   << 12);
    prog[3] = 0x00028293u | (lo   << 20);
    prog[7] = 0x00000293u | (ctrl << 20);

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }

    soc = (volatile uint32_t *)mmap(NULL, SOC_SPAN, PROT_READ|PROT_WRITE,
                                    MAP_SHARED, fd, SOC_BASE);
    if (soc == MAP_FAILED) { perror("mmap soc"); return 1; }
    ddr = (volatile uint8_t *)mmap(NULL, 0x1000, PROT_READ|PROT_WRITE,
                                   MAP_SHARED, fd, ddr_phys);
    if (ddr == MAP_FAILED) { perror("mmap ddr"); return 1; }

    printf("USART bring-up: baud=%u (K=0x%08X), modo=%s, DDR=0x%llx\n",
           baud, k, ext ? "EXTERNO (pads, jumper D10->C10)" : "INTERNO (loop_int)",
           (unsigned long long)ddr_phys);

    // 1) detiene el core y carga el programa
    wr(REG_CONTROL, 1);
    for (unsigned i = 0; i < PROG_WORDS; i++) wr(OFF_IMEM + i*4, prog[i]);
    for (unsigned i = 0; i < PROG_WORDS; i++)
        if (rd(OFF_IMEM + i*4) != prog[i]) { fprintf(stderr, "IMEM verify fallo en %u\n", i); return 1; }

    // 2) DDR_BASE hacia ambos DMA (dma_burst y USART comparten ddr_base)
    wr(REG_DDRB_LO, (uint32_t)(ddr_phys & 0xFFFFFFFFu));
    wr(REG_DDRB_HI, (uint32_t)(ddr_phys >> 32));

    // 3) buffer TX: patron incremental (byte n = n); limpia RX y doorbell
    uint8_t pat[32];
    for (int i = 0; i < 32; i++) { pat[i] = (uint8_t)i; ddr[i] = pat[i]; }
    memset((void*)(ddr + 0x100), 0, 32);
    __sync_synchronize();

    // 4) suelta el core
    wr(REG_IRQ, 1);            // limpia sticky previo (w1c)
    wr(REG_CONTROL, 0);

    // 5) espera el doorbell (DDR[3] = 1337) con timeout (~2 s; a 300 baud
    //    los 34 bytes tardan ~1.2 s, sigue dentro)
    int ok = 0;
    for (int t = 0; t < 200000; t++) {
        if (ddr_w(3) == 1337u) { ok = 1; break; }
        usleep(10);
    }
    if (!ok) {
        fprintf(stderr, "TIMEOUT: sin doorbell. DBG_PC=0x%08x STATUS=0x%08x IRQ=0x%08x\n",
                rd(REG_DBGPC), rd(REG_STATUS), rd(REG_IRQ));
        if (ext) fprintf(stderr, "  (modo ext: checa el jumper D10<->C10 del CRUVI LS1)\n");
        else     fprintf(stderr, "  (modo int: no hay hardware de por medio; revisa BAUD/bitstream)\n");
        return 2;
    }

    // 6) verifica
    int errors = 0;
    uint32_t rxlvl = ddr_w(0), b0 = ddr_w(1), b1 = ddr_w(2);
    if (rxlvl != 2)    { printf("FAIL PIO rxlvl=%u (esperaba 2)\n", rxlvl); errors++; }
    if (b0 != 0x5A)    { printf("FAIL PIO byte0=0x%02X (esperaba 0x5A)\n", b0); errors++; }
    if (b1 != 0xC3)    { printf("FAIL PIO byte1=0x%02X (esperaba 0xC3)\n", b1); errors++; }
    for (int i = 0; i < 32; i++) {
        if (ddr[0x100 + i] != pat[i]) {
            printf("FAIL DMA byte %d: 0x%02X != 0x%02X\n", i, ddr[0x100+i], pat[i]);
            if (++errors > 8) break;
        }
    }

    if (errors == 0) {
        printf("PASS: PIO {2, 0x5A, 0xC3} + eco DMA concurrente de 32 bytes OK (IRQ=0x%x)\n",
               rd(REG_IRQ));
        printf("El IP USART esta validado en silicio a %u baud (%.2f Mbit/s).\n",
               baud, baud / 1.0e6);
    } else {
        printf("%d error(es).\n", errors);
    }
    return errors ? 3 : 0;
}
