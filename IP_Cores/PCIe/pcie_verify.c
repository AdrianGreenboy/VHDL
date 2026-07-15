// ===========================================================================
//  pcie_verify.c  -  Verificador de bring-up del PCIe soft IP (PS aarch64).
//  Adaptado de dsp_verify.c. Carga pcie_fw.mem en el RV32, lo arranca, y lee
//  de DDR (0x70000000) la FIRMA de 5 palabras que el firmware vuelca, mas un
//  marcador de fin en DDR[5]. Compara con el oraculo pcie_iss.py.
//
//  Firma esperada:
//    DDR[0] link_up   = 0x00000001
//    DDR[1] mwr_cnt   = 0x00000004
//    DDR[2] bar0_last = 0x44444444
//    DDR[3] cpld_b0   = 0x0000004A
//    DDR[4] mrd_data  = 0x33333333
//    DDR[5] marcador  = 0x0C0FFEE0  (fin de firmware)
//
//  Compilar: aarch64-linux-gnu-gcc -O2 -static pcie_verify.c -o pcie_verify
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
#define DDR_SIZE   0x10000UL

#define REG_CONTROL 0x0000
#define REG_STATUS  0x0004
#define REG_DBGPC   0x0008
#define REG_IRQ     0x000C
#define REG_DDRLO   0x0010
#define REG_DDRHI   0x0014
#define WIN_IMEM    0x1000

#define MARKER     0x0C0FFEE0U     // marcador de fin (DDR[5])

// firma esperada (oraculo pcie_iss.py)
static const uint32_t EXP[5] = {
    0x00000001,  // link_up
    0x00000004,  // mwr_cnt
    0x44444444,  // bar0_last
    0x0000004A,  // cpld_b0
    0x33333333,  // mrd_data
};
static const char *NAME[5] = {"link_up","mwr_cnt","bar0_last","cpld_b0","mrd_data"};

static volatile uint32_t *soc;
static volatile uint32_t *ddr;
static inline void wr(uint32_t off, uint32_t v){ soc[off/4] = v; }
static inline uint32_t rd(uint32_t off){ return soc[off/4]; }

int main(int argc, char **argv){
    const char *binpath = (argc>1) ? argv[1] : "pcie_fw.mem";

    FILE *f = fopen(binpath, "r");
    if(!f){ perror("fopen bin"); return 1; }
    static uint32_t imem[1024];
    size_t n = 0; char line[64];
    while(n < 1024 && fgets(line, sizeof(line), f)){
        char *p = line;
        while(*p==' '||*p=='\t') p++;
        if(*p=='0' && (p[1]=='x'||p[1]=='X')) p+=2;
        if(*p=='\n' || *p=='\0') continue;
        imem[n++] = (uint32_t)strtoul(p, NULL, 16);
    }
    fclose(f);
    printf("[*] %s: %zu instrucciones\n", binpath, n);

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if(fd < 0){ perror("open /dev/mem"); return 1; }
    soc = mmap(NULL, SOC_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, SOC_BASE);
    if(soc == MAP_FAILED){ perror("mmap soc"); return 1; }
    ddr = mmap(NULL, DDR_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, DDR_BUF);
    if(ddr == MAP_FAILED){ perror("mmap ddr"); return 1; }

    // 1. halt
    wr(REG_CONTROL, 1);
    printf("[*] core en halt. STATUS=0x%08X\n", rd(REG_STATUS));

    // 2. cargar IMEM
    for(size_t i=0;i<n;i++) soc[(WIN_IMEM/4) + i] = imem[i];
    printf("[*] IMEM[0]=0x%08X IMEM[1]=0x%08X (esperado 0x800002B7 0x70000337)\n",
           soc[WIN_IMEM/4+0], soc[WIN_IMEM/4+1]);

    // 3. DDR_BASE = 0x70000000
    wr(REG_DDRLO, (uint32_t)(DDR_BUF & 0xFFFFFFFF));
    wr(REG_DDRHI, (uint32_t)(DDR_BUF >> 32));

    // 4. limpiar buffer (6 palabras)
    for(int i=0;i<6;i++) ddr[i] = 0;

    // 5. release
    wr(REG_CONTROL, 0);
    printf("[*] core liberado. corriendo...\n");

    // 6. poll del marcador de fin
    int timeout = 5000000;
    while(timeout-- > 0){
        if(ddr[5] == MARKER) break;
        if(rd(REG_IRQ) & 1) break;
    }
    printf("[*] fin poll (timeout restante=%d) IRQ=0x%08X DBGPC=0x%08X\n",
           timeout, rd(REG_IRQ), rd(REG_DBGPC));

    // 7. dump y comparacion
    printf("[*] DDR dump:\n");
    for(int i=0;i<6;i++) printf("      DDR[%d] = 0x%08X\n", i, ddr[i]);

    if(ddr[5] != MARKER)
        printf("[!] marcador de fin ausente (0x%08X != 0x%08X): el firmware pudo no terminar\n",
               ddr[5], MARKER);

    int ok = 1;
    printf("[*] verificacion de firma:\n");
    for(int i=0;i<5;i++){
        int good = (ddr[i] == EXP[i]);
        printf("      %-10s = 0x%08X  (esperado 0x%08X)  %s\n",
               NAME[i], ddr[i], EXP[i], good ? "OK" : "<-- FALLO");
        if(!good) ok = 0;
    }
    printf("\n%s\n", ok ? "===== PASS: PCIe soft IP validado en silicio =====":
                          "===== FALLO: la firma no coincide =====");
    return ok ? 0 : 2;
}
