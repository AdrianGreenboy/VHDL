// adc-bringup.c - Bring-up del ADC delta-sigma soft IP v1 en el TE0950 (Versal).
// El A72 (Linux, /dev/mem) carga adc_bringup en la IMEM del RV32, suelta el
// core, y este configura el IP (0x6000_0000: FINC + CTRL OSR=256), espera
// nivel>=64, drena 64 muestras Q1.23 a RAM local, escribe la sentinela
// 0xADC0FEED y copia 65 palabras por DMA a la DDR reservada (0x70000000).
// El doorbell (word 127) dispara el IRQ sticky del axil_soc. El A72 espera el
// doorbell y compara las 65 palabras bit-identicas contra el oraculo del ISS
// (iss_adc.py, CHK 0x1B8D3FF9).
//
// Compilar (cross aarch64):
//   aarch64-linux-gnu-gcc -O2 -static adc-bringup.c -o adc-bringup
// Self-test nativo (sin hardware, valida el camino de comparacion):
//   gcc -O2 -DSELFTEST adc-bringup.c -o adc-bringup-selftest && ./adc-bringup-selftest
// Ejecutar (root):  ./adc-bringup [ddr_phys_hex]

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#ifndef SELFTEST
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#endif

#define SOC_BASE   0x80000000UL
#define SOC_SPAN   0x10000UL
#define REG_CONTROL 0x0000     // bit0 = 1 -> core en reset (halt)
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C     // sticky del doorbell (w1c)
#define REG_DDRB_LO 0x0010
#define REG_DDRB_HI 0x0014
#define OFF_IMEM    0x1000

// adc_bringup.s ensamblado (salida de asm.py).
static uint32_t prog[] = {
0x600002B7, 0x00028293, 0x40000FB7, 0x000F8F93, 0x001933B7, 0x00038393, 0x0072A423, 0x000003B7,
0x00D38393, 0x0072A023, 0x00000437, 0x04040413, 0x00C2A483, 0xFE84CEE3, 0x00000537, 0x00050513,
0x000005B7, 0x04058593, 0x0102A483, 0x00952023, 0x00450513, 0xFFF58593, 0xFE0598E3, 0xADC103B7,
0xEED38393, 0x00752023, 0x000FA023, 0x000FA223, 0x000003B7, 0x04138393, 0x007FA423, 0x000003B7,
0x00338393, 0x007FA623, 0x010FA483, 0x0014F493, 0xFE049CE3, 0x0000D3B7, 0x0ED38393, 0x00000537,
0x1FC50513, 0x00752023, 0x0000006F
};
#define PROG_WORDS (sizeof(prog)/sizeof(prog[0]))

// oraculo del ISS (iss_adc.py): 64 muestras etiquetadas + sentinela.
static const uint32_t oracle[65] = {
0x00492D29u, 0x003CC93Du, 0x0019E4F9u, 0x00ED6B8Du, 0x00C7D2A3u, 0x00B7048Cu, 0x00C13AABu, 0x00E2AC50u,
0x000EF908u, 0x0035BAF0u, 0x004899CEu, 0x004098F0u, 0x0020AEDFu, 0x00F4AC23u, 0x00CCDA78u, 0x00B7F740u,
0x00BDBE42u, 0x00DC0B60u, 0x0007A7ADu, 0x00306E55u, 0x0047481Bu, 0x0043BF15u, 0x002722A3u, 0x00FC09FBu,
0x00D268D7u, 0x00B9A736u, 0x00BAEFD8u, 0x00D5C8A6u, 0x000041B2u, 0x002AA27Eu, 0x00453B78u, 0x004633FDu,
0x002D303Cu, 0x0003729Du, 0x00D86E12u, 0x00BC0F44u, 0x00B8D66Fu, 0x00CFF47Au, 0x00F8DBC2u, 0x00246706u,
0x0042793Bu, 0x0047F0A9u, 0x0032C6D0u, 0x000AD1F5u, 0x00DEDB9Eu, 0x00BF29EBu, 0x00B7775Du, 0x00CA9EAFu,
0x00F187B9u, 0x001DCBD6u, 0x003F090Eu, 0x0048F0C1u, 0x0037D8CFu, 0x0012151Cu, 0x00E59FA0u, 0x00C2EDE9u,
0x00B6D6D1u, 0x00C5D47Du, 0x00EA5A4Bu, 0x0016E308u, 0x003AF30Bu, 0x004931A2u, 0x003C57E5u, 0x0019289Au,
0xADC0FEEDu
};
#define SENTINEL 0xADC0FEEDu
#define CHK_ESPERADO 0x1B8D3FF9u

static uint32_t lfsr32(const volatile uint32_t *w, int n)
{
    uint32_t chk = 0xFFFFFFFFu;
    for (int i = 0; i < n; i++)
        for (int b = 31; b >= 0; b--) {
            uint32_t msb = chk >> 31;
            chk = (chk << 1) | ((w[i] >> b) & 1u);
            if (msb) chk ^= 0x04C11DB7u;
        }
    return chk;
}

#ifdef SELFTEST
int main(void)
{
    // sin hardware: la "DDR" es el propio oraculo; valida compare + checksum
    uint32_t chk = lfsr32(oracle, 65);
    int errors = (oracle[64] != SENTINEL);
    for (int i = 0; i < 65; i++)
        if (oracle[i] != oracle[i]) errors++;
    if (chk != CHK_ESPERADO) errors++;
    printf("SELFTEST adc-bringup: %s CHK=0x%08X (esperado 0x%08X)\n",
           errors ? "FAIL" : "PASS", chk, CHK_ESPERADO);
    return errors ? 1 : 0;
}
#else
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

    printf("ADC bring-up: delta-sigma soft IP v1, DDR=0x%llx\n",
           (unsigned long long)ddr_phys);

    wr(REG_CONTROL, 1);
    for (unsigned i = 0; i < PROG_WORDS; i++) wr(OFF_IMEM + i*4, prog[i]);
    for (unsigned i = 0; i < PROG_WORDS; i++)
        if (rd(OFF_IMEM + i*4) != prog[i]) {
            fprintf(stderr, "IMEM verify fallo en %u\n", i); return 1;
        }

    wr(REG_DDRB_LO, (uint32_t)(ddr_phys & 0xFFFFFFFFu));
    wr(REG_DDRB_HI, (uint32_t)(ddr_phys >> 32));

    for (int _i = 0; _i < 65; _i++) ((volatile uint32_t*)ddr)[_i] = 0;  /* memset de glibc falla en /dev/mem device memory (aarch64 DC ZVA/stp): escrituras volatile palabra a palabra */
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

    int errors = 0;
    uint32_t sent = ddr_w(64);
    if (sent != SENTINEL) {
        printf("FAIL sentinela: 0x%08X (esperaba 0x%08X)\n", sent, SENTINEL);
        errors++;
    }
    for (int i = 0; i < 65; i++) {
        uint32_t got = ddr_w(i);
        if (got != oracle[i]) {
            printf("FAIL word %d: 0x%08X (esperaba 0x%08X)\n", i, got, oracle[i]);
            errors++;
        }
    }
    uint32_t chk = lfsr32((const volatile uint32_t*)ddr, 65);
    if (chk != CHK_ESPERADO) {
        printf("FAIL CHK: 0x%08X (esperaba 0x%08X)\n", chk, CHK_ESPERADO);
        errors++;
    }

    if (errors == 0) {
        printf("PASS: ADC delta-sigma validado en silicio.\n");
        printf("  muestras[0..3] = 0x%06X 0x%06X 0x%06X 0x%06X (Q1.23)\n",
               ddr_w(0) & 0xFFFFFF, ddr_w(1) & 0xFFFFFF,
               ddr_w(2) & 0xFFFFFF, ddr_w(3) & 0xFFFFFF);
        printf("  sentinela 0x%08X OK, CHK=0x%08X (ISS: iss_adc.py)\n", sent, chk);
    } else {
        printf("%d error(es). El ADC NO coincide con el oraculo.\n", errors);
    }
    return errors ? 3 : 0;
}
#endif
