// ===========================================================================
//  dsp_verify.c  -  Verificador de bring-up (PS aarch64, corre en Linux).
//  Fase A: carga dsp_id_hw.bin en el core, lo arranca, y lee de DDR el ID
//  del IP DSP que el core escribio via DMA-doorbell.
//
//  Flujo:
//    1. mmap /dev/mem en SOC_BASE (axil_soc) y en DDR_BUF.
//    2. halt del core (CONTROL bit0=1).
//    3. cargar el .bin en la ventana IMEM (offset 0x1000).
//    4. fijar DDR_BASE (0x10/0x14) = 0x7000_0000.
//    5. limpiar el buffer DDR (centinela).
//    6. release del core (CONTROL bit0=0).
//    7. poll del IRQ (0x0C bit0) o del centinela en DDR.
//    8. leer DDR word[0]=centinela, word[1]=ID; comparar.
//
//  Compilar: aarch64-linux-gnu-gcc -O2 -static dsp_verify.c -o dsp_verify
//  (o gcc nativo en la placa si tiene toolchain)
// ===========================================================================
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <string.h>

#define SOC_BASE   0x80000000UL   // axil_soc (M_AXI_LPD low window)
#define SOC_SIZE   0x10000UL
#define DDR_BUF    0x70000000UL    // buffer reservado (rv32i_reserved)
#define DDR_SIZE   0x10000UL       // 64 KB nos basta para el bring-up

// registros axil_soc (offsets byte)
#define REG_CONTROL 0x0000
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C
#define REG_DDRLO   0x0010
#define REG_DDRHI   0x0014
#define WIN_IMEM    0x1000

#define ID_EXPECTED    0xD5B10100U
#define SENTINEL       0xD1A6C0DEU

static volatile uint32_t *soc;
static volatile uint32_t *ddr;

static inline void wr(uint32_t off, uint32_t v){ soc[off/4] = v; }
static inline uint32_t rd(uint32_t off){ return soc[off/4]; }

int main(int argc, char **argv){
    const char *binpath = (argc>1) ? argv[1] : "dsp_id_hw.bin";

    // --- cargar el firmware (formato texto hex: una palabra de 32b por linea) ---
    FILE *f = fopen(binpath, "r");
    if(!f){ perror("fopen bin"); return 1; }
    static uint32_t imem[1024];
    size_t n = 0;
    char line[64];
    while(n < 1024 && fgets(line, sizeof(line), f)){
        // aceptar lineas tipo "900002B7" o "0x900002B7"; ignorar vacias
        char *p = line;
        while(*p==' '||*p=='\t') p++;
        if(*p=='0' && (p[1]=='x'||p[1]=='X')) p+=2;
        if(*p=='\n' || *p=='\0') continue;
        unsigned long v = strtoul(p, NULL, 16);
        imem[n++] = (uint32_t)v;
    }
    fclose(f);
    printf("[*] %s: %zu instrucciones\n", binpath, n);

    // --- mmap ---
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if(fd < 0){ perror("open /dev/mem"); return 1; }
    soc = mmap(NULL, SOC_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, SOC_BASE);
    if(soc == MAP_FAILED){ perror("mmap soc"); return 1; }
    ddr = mmap(NULL, DDR_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, DDR_BUF);
    if(ddr == MAP_FAILED){ perror("mmap ddr"); return 1; }

    // --- 1. halt ---
    wr(REG_CONTROL, 1);
    printf("[*] core en halt (CONTROL=1). STATUS=0x%08X\n", rd(REG_STATUS));

    // --- 2. cargar IMEM ---
    for(size_t i=0;i<n;i++) soc[(WIN_IMEM/4) + i] = imem[i];
    // verificar unas cuantas
    printf("[*] IMEM[0]=0x%08X IMEM[1]=0x%08X (esperado 0x900002B7 0x0002A303)\n",
           soc[WIN_IMEM/4+0], soc[WIN_IMEM/4+1]);

    // --- 3. DDR_BASE ---
    wr(REG_DDRLO, (uint32_t)(DDR_BUF & 0xFFFFFFFF));
    wr(REG_DDRHI, (uint32_t)(DDR_BUF >> 32));

    // --- 4. limpiar buffer DDR ---
    ddr[0] = 0; ddr[1] = 0;

    // --- 5. release ---
    wr(REG_CONTROL, 0);
    printf("[*] core liberado (CONTROL=0). corriendo...\n");

    // --- 6. poll doorbell/centinela ---
    int timeout = 1000000;
    while(timeout-- > 0){
        if(ddr[0] == SENTINEL) break;         // centinela escrito por DMA
        if(rd(REG_IRQ) & 1) break;            // o IRQ del doorbell
    }
    printf("[*] fin poll (timeout restante=%d) IRQ=0x%08X DBGPC=0x%08X\n",
           timeout, rd(REG_IRQ), rd(REG_DBGPC));

    // --- 7. leer resultado (N words, generico) ---
    int nwords = (argc > 2) ? atoi(argv[2]) : 2;
    if(nwords < 1) nwords = 1;
    if(nwords > 16) nwords = 16;
    printf("[*] DDR dump (%d words):\n", nwords);
    for(int i=0;i<nwords;i++)
        printf("      DDR[%d] = 0x%08X\n", i, ddr[i]);

    uint32_t sent = ddr[0];
    int ok = 1;
    if(sent != SENTINEL){ printf("[X] centinela MAL (esperado 0x%08X)\n", SENTINEL); ok=0; }
    if(ok) printf("[OK] centinela correcto; el core ejecuto y el DMA transfirio a DDR.\n");
    printf("[*] (comparar DDR[1..] con los valores esperados de la operacion)\n");

    return ok ? 0 : 2;
}
