// ============================================================================
//  spi_bringup.c  -  Bring-up del IP SPI en el TE0950 (loopback con jumper)
//  Licencia: MIT
//
//  El A72 (Linux, /dev/mem) carga spi_test en la IMEM del RV32, llena el
//  buffer TX en la DDR con el patron incremental, fija DDR_BASE, suelta el
//  core y espera el doorbell. El RV32 hace: PIO de 2 bytes + DMA SPI de 32
//  bytes (eco por el jumper MOSI->MISO en el CRUVI LS1) + reporte via
//  dma_burst. El A72 verifica el reporte y el eco.
//
//  REQUISITO FISICO: jumper entre D0 (MOSI, pin D10) y D1 (MISO, pin C10)
//  del conector CRUVI LS1.
//
//  Compilar (SDK de PetaLinux, cross aarch64):   $CC spi_bringup.c -o spi_bringup
//  Ejecutar (root):   ./spi_bringup [clkdiv] [int|ext] [ddr_phys_hex]
//     clkdiv:   medio periodo de SCLK en ciclos (default 4; 1 -> 50 MHz)
//     int|ext:  int (default) = loopback interno CTRL[7], sin hardware;
//               ext = pads reales (requiere loopback fisico via CR00025)
//     ddr_phys: base fisica del buffer en DDR (default 0x70000000; debe ser
//               memoria NO gestionada por el kernel, mismo pool de siempre).
//
//  SOC_BASE = 0xA000... NO: en este BD el esclavo quedo en 0x8000_0000
//  (ventana baja del M_AXI_LPD, ver Address Editor).
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

// spi_test.s ensamblado (43 palabras).
// prog[2] = addi x5,x0,CLKDIV   prog[4] = addi x5,x0,CTRL  (parcheables)
static uint32_t prog[] = {
    0x500000B7, 0x40000137, 0x00100293, 0x0050A423,
    0x08100293, 0x0050A023, 0x05A00293, 0x0050A623,
    0x0C300293, 0x0050A623, 0x0040A303, 0x00337313,
    0x00200393, 0xFE731AE3, 0x0180A403, 0x00802023,
    0x0100A483, 0x00902223, 0x0100A483, 0x00902423,
    0x0000AE23, 0x10000293, 0x0250A023, 0x02000293,
    0x0250A223, 0x00700293, 0x0250A423, 0x18000393,
    0x10000413, 0x0040A303, 0x00737333, 0xFE831CE3,
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
    unsigned clkdiv   = (argc > 1) ? (unsigned)strtoul(argv[1], NULL, 0) : 4;
    int      ext      = (argc > 2 && strcmp(argv[2], "ext") == 0);
    uint64_t ddr_phys = (argc > 3) ? strtoull(argv[3], NULL, 16) : 0x70000000ULL;
    if (clkdiv < 1 || clkdiv > 0xFFF) { fprintf(stderr, "clkdiv 1..4095\n"); return 1; }

    // parcha CLKDIV y CTRL del programa RV32 (addi x5,x0,imm)
    unsigned ctrl = ext ? 0x01u : 0x81u;      // ext: pads reales; int: loop_int
    prog[2] = 0x00000293u | (clkdiv << 20);
    prog[4] = 0x00000293u | (ctrl   << 20);

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }

    soc = (volatile uint32_t *)mmap(NULL, SOC_SPAN, PROT_READ|PROT_WRITE,
                                    MAP_SHARED, fd, SOC_BASE);
    if (soc == MAP_FAILED) { perror("mmap soc"); return 1; }
    ddr = (volatile uint8_t *)mmap(NULL, 0x1000, PROT_READ|PROT_WRITE,
                                   MAP_SHARED, fd, ddr_phys);
    if (ddr == MAP_FAILED) { perror("mmap ddr"); return 1; }

    printf("SPI bring-up: clkdiv=%u (SCLK=%.1f MHz), modo=%s, DDR=0x%llx\n",
           clkdiv, 50.0 / clkdiv, ext ? "EXTERNO (pads)" : "INTERNO (loop_int)",
           (unsigned long long)ddr_phys);

    // 1) detiene el core y carga el programa
    wr(REG_CONTROL, 1);
    for (unsigned i = 0; i < PROG_WORDS; i++) wr(OFF_IMEM + i*4, prog[i]);
    for (unsigned i = 0; i < PROG_WORDS; i++)
        if (rd(OFF_IMEM + i*4) != prog[i]) { fprintf(stderr, "IMEM verify fallo en %u\n", i); return 1; }

    // 2) DDR_BASE hacia ambos DMA (dma_burst y SPI comparten ddr_base)
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

    // 5) espera el doorbell (DDR[3] = 1337) con timeout
    int ok = 0;
    for (int t = 0; t < 200000; t++) {
        if (ddr_w(3) == 1337u) { ok = 1; break; }
        usleep(10);
    }
    if (!ok) {
        fprintf(stderr, "TIMEOUT: sin doorbell. DBG_PC=0x%08x STATUS=0x%08x IRQ=0x%08x\n",
                rd(REG_DBGPC), rd(REG_STATUS), rd(REG_IRQ));
        fprintf(stderr, "  (checa el jumper D0<->D1 del CRUVI LS1 y el clkdiv)\n");
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
        printf("PASS: PIO {2, 0x5A, 0xC3} + eco DMA de 32 bytes OK (IRQ=0x%x)\n", rd(REG_IRQ));
        printf("El IP SPI esta validado en silicio a SCLK=%.1f MHz.\n", 50.0/clkdiv);
    } else {
        printf("%d error(es).\n", errors);
    }
    return errors ? 3 : 0;
}
