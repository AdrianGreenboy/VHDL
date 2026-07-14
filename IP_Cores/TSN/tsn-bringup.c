// tsn-bringup.c - Bring-up del switch SDN-TSN 4x4 en el TE0950 (Versal).
// El A72 (Linux, /dev/mem) carga tsn_bringup en la IMEM del RV32, suelta el
// core, y este programa la tabla del switch, inyecta 8 tramas por el inyector
// interno (rx_src="10"), lee los 20 contadores, los firma a la RAM local y los
// copia por DMA a la DDR reservada (0x70000000). El doorbell (word 127) dispara
// el IRQ sticky del axil_soc. El A72 espera el doorbell y compara los 20
// contadores + sentinela contra el oraculo del ISS (SIG 64476b7f).
//
// Compilar (cross aarch64):
//   aarch64-linux-gnu-gcc -O2 -static tsn-bringup.c -o tsn-bringup
// Ejecutar (root):  ./tsn-bringup [ddr_phys_hex]
//   ddr_phys: base fisica del buffer (default 0x70000000, pool no-map)
//
// Oraculo (del ISS iss_tsn.py, SIG 64476b7f):
//   RX0..3=2,2,2,2  TX0..3=4,3,4,2  OVF=0,0,0,0  FCS=0,0,0,0  TAG=1,0,0,0

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define SOC_BASE   0x80000000UL
#define SOC_SPAN   0x10000UL
#define REG_CONTROL 0x0000     // bit0 = 1 -> core en reset (halt)
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C     // sticky del doorbell (w1c)
#define REG_DDRB_LO 0x0010
#define REG_DDRB_HI 0x0014
#define OFF_IMEM    0x1000

// tsn_bringup.s ensamblado (238 palabras, salida de asm.py).
static uint32_t prog[] = {
0x600002B7, 0x00028293, 0x40000FB7, 0x000F8F93, 0x000003B7, 0x00138393, 0x0072A023, 0x000003B7,
0x00138393, 0x0072A423, 0x800003B7, 0x20038393, 0x0072A623, 0x000003B7, 0x00038393, 0x0072A823,
0x000003B7, 0x00238393, 0x0072A423, 0x800103B7, 0x20038393, 0x0072A623, 0x000003B7, 0x00138393,
0x0072A823, 0x000003B7, 0x00338393, 0x0072A423, 0x800203B7, 0x20038393, 0x0072A623, 0x000003B7,
0x00238393, 0x0072A823, 0x000003B7, 0x00438393, 0x0072A423, 0x800303B7, 0x20038393, 0x0072A623,
0x000003B7, 0x00338393, 0x0072A823, 0x00000A37, 0x002A0A13, 0x00020AB7, 0x200A8A93, 0x01000B37,
0x000B0B13, 0x00000BB7, 0x000B8B93, 0x1CC000EF, 0x00000A37, 0x002A0A13, 0x00020AB7, 0x400A8A93,
0x03000B37, 0x000B0B13, 0x00000BB7, 0x002B8B93, 0x1A8000EF, 0x00000A37, 0xFFFA0A13, 0x00030AB7,
0xFFFA8A93, 0x02000B37, 0x000B0B13, 0x00000BB7, 0x001B8B93, 0x184000EF, 0x0D0C1A37, 0xB0AA0A13,
0x00021AB7, 0xF0EA8A93, 0x04000B37, 0x000B0B13, 0x00000BB7, 0x003B8B93, 0x160000EF, 0x00000A37,
0x002A0A13, 0x00020AB7, 0x300A8A93, 0x01000B37, 0x000B0B13, 0x00000BB7, 0x000B8B93, 0x1B4000EF,
0x00000A37, 0x002A0A13, 0x00020AB7, 0x200A8A93, 0x02000B37, 0x000B0B13, 0x00000BB7, 0x001B8B93,
0x118000EF, 0x00000A37, 0x002A0A13, 0x00020AB7, 0x100A8A93, 0x03000B37, 0x000B0B13, 0x00000BB7,
0x002B8B93, 0x0F4000EF, 0x00000A37, 0xFFFA0A13, 0x00030AB7, 0xFFFA8A93, 0x04000B37, 0x000B0B13,
0x00000BB7, 0x003B8B93, 0x0D0000EF, 0x0402A383, 0x18702823, 0x0442A383, 0x18702A23, 0x0482A383,
0x18702C23, 0x04C2A383, 0x18702E23, 0x0502A383, 0x1A702023, 0x0542A383, 0x1A702223, 0x0582A383,
0x1A702423, 0x05C2A383, 0x1A702623, 0x0602A383, 0x1A702823, 0x0642A383, 0x1A702A23, 0x0682A383,
0x1A702C23, 0x06C2A383, 0x1A702E23, 0x0702A383, 0x1C702023, 0x0742A383, 0x1C702223, 0x0782A383,
0x1C702423, 0x07C2A383, 0x1C702623, 0x0802A383, 0x1C702823, 0x0842A383, 0x1C702A23, 0x0882A383,
0x1C702C23, 0x08C2A383, 0x1C702E23, 0x0000D3B7, 0x0ED38393, 0x1E702023, 0x19000513, 0x00000593,
0x01500613, 0x00300693, 0x114000EF, 0x00100713, 0x1EE02E23, 0x0000006F, 0x60000337, 0x00030313,
0x00000437, 0x00240413, 0x02832623, 0x03432423, 0x03532423, 0x03632423, 0x00000437, 0x00840413,
0x02832423, 0xA5A5A437, 0x5A540413, 0x00B00493, 0x02832423, 0xFFF48493, 0xFE049CE3, 0x00000437,
0x03C40413, 0x02832223, 0x004B8413, 0x02832023, 0x02C32403, 0x00147413, 0xFE041CE3, 0x00001437,
0xFA040413, 0xFFF40413, 0xFE041EE3, 0x00008067, 0x60000337, 0x00030313, 0x00000437, 0x00240413,
0x02832623, 0x03432423, 0x03532423, 0x03632423, 0x00008437, 0x10040413, 0x64000437, 0x08140413,
0x02832423, 0x00000437, 0x00840413, 0x02832423, 0xA5A5A437, 0x5A540413, 0x00A00493, 0x02832423,
0xFFF48493, 0xFE049CE3, 0x00000437, 0x03C40413, 0x02832223, 0x004B8413, 0x02832023, 0x02C32403,
0x00147413, 0xFE041CE3, 0x00001437, 0xFA040413, 0xFFF40413, 0xFE041EE3, 0x00008067, 0x00AFA023,
0x00BFA223, 0x00CFA423, 0x00DFA623, 0x010FA703, 0xFE071EE3, 0x00008067,
};
#define PROG_WORDS (sizeof(prog)/sizeof(prog[0]))

static const uint32_t oracle[20] = {
    2,2,2,2,   4,3,4,2,   0,0,0,0,   0,0,0,0,   1,0,0,0
};
static const char *lbl[20] = {
    "RX0","RX1","RX2","RX3","TX0","TX1","TX2","TX3",
    "OVF0","OVF1","OVF2","OVF3","FCS0","FCS1","FCS2","FCS3",
    "TAG0","TAG1","TAG2","TAG3"
};
#define SENTINEL 0x0000D0EDu

static volatile uint32_t *soc;
static volatile uint8_t  *ddr;
static inline void     wr(unsigned off, uint32_t v) { soc[off/4] = v; }
static inline uint32_t rd(unsigned off)             { return soc[off/4]; }
static inline uint32_t ddr_w(unsigned widx)
{ return ((volatile uint32_t*)ddr)[widx]; }

int main(int argc, char **argv)
{
    uint64_t ddr_phys = (argc > 1) ? strtoull(argv[1], NULL, 16) : 0x70000000ULL;

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }
    soc = (volatile uint32_t *)mmap(NULL, SOC_SPAN, PROT_READ|PROT_WRITE,
                                    MAP_SHARED, fd, SOC_BASE);
    if (soc == MAP_FAILED) { perror("mmap soc"); return 1; }
    ddr = (volatile uint8_t *)mmap(NULL, 0x1000, PROT_READ|PROT_WRITE,
                                   MAP_SHARED, fd, ddr_phys);
    if (ddr == MAP_FAILED) { perror("mmap ddr"); return 1; }

    printf("TSN bring-up: switch 4x4, DDR=0x%llx\n",
           (unsigned long long)ddr_phys);

    wr(REG_CONTROL, 1);
    for (unsigned i = 0; i < PROG_WORDS; i++) wr(OFF_IMEM + i*4, prog[i]);
    for (unsigned i = 0; i < PROG_WORDS; i++)
        if (rd(OFF_IMEM + i*4) != prog[i]) {
            fprintf(stderr, "IMEM verify fallo en %u\n", i); return 1;
        }

    wr(REG_DDRB_LO, (uint32_t)(ddr_phys & 0xFFFFFFFFu));
    wr(REG_DDRB_HI, (uint32_t)(ddr_phys >> 32));

    memset((void*)ddr, 0, 21*4);
    __sync_synchronize();
    wr(REG_IRQ, 1);

    wr(REG_CONTROL, 0);

    int ok = 0;
    for (int t = 0; t < 200000; t++) {
        if (rd(REG_IRQ) & 1u) { ok = 1; break; }
        usleep(10);
    }
    if (!ok) {
        fprintf(stderr, "TIMEOUT: sin doorbell. DBG_PC=0x%08x STATUS=0x%08x\n",
                rd(REG_DBGPC), rd(REG_STATUS));
        return 2;
    }
    __sync_synchronize();

    uint32_t sent = ddr_w(20);
    int errors = 0;
    if (sent != SENTINEL) {
        printf("FAIL sentinela: 0x%08X (esperaba 0x%08X)\n", sent, SENTINEL);
        errors++;
    }
    for (int i = 0; i < 20; i++) {
        uint32_t got = ddr_w(i);
        if (got != oracle[i]) {
            printf("FAIL %s: %u (esperaba %u)\n", lbl[i], got, oracle[i]);
            errors++;
        }
    }

    if (errors == 0) {
        printf("PASS: switch TSN 4x4 validado en silicio.\n");
        printf("  contadores = RX{%u,%u,%u,%u} TX{%u,%u,%u,%u} "
               "OVF{%u,%u,%u,%u} FCS{%u,%u,%u,%u} TAG{%u,%u,%u,%u}\n",
               ddr_w(0),ddr_w(1),ddr_w(2),ddr_w(3),
               ddr_w(4),ddr_w(5),ddr_w(6),ddr_w(7),
               ddr_w(8),ddr_w(9),ddr_w(10),ddr_w(11),
               ddr_w(12),ddr_w(13),ddr_w(14),ddr_w(15),
               ddr_w(16),ddr_w(17),ddr_w(18),ddr_w(19));
        printf("  sentinela 0x%08X OK (SIG del ISS: 64476b7f)\n", sent);
    } else {
        printf("%d error(es). El switch NO coincide con el oraculo.\n", errors);
    }
    return errors ? 3 : 0;
}
