// ===========================================================================
//  ptp_verify.c - Verificador aarch64 (PS) del bring-up del IP PTP/802.1AS.
//  Flujo DMA doorbell (patron de la familia): carga el firmware por IMEM,
//  fija DDR_BASE=0x7000_0000, suelta el core. El firmware configura el IP
//  (0x6000_0000, bus interno del core), ejecuta Sync -> Pdelay -> esclavo,
//  deja la firma en RAM local y la vuelca por DMA a DDR 0x7000_0000, y escribe
//  el doorbell (word 127 de RAM local) que ademas dispara pl_ps_irq0.
//
//  El PS lee la firma DIRECTAMENTE de la DDR fisica (0x7000_0000). El doorbell
//  0xD0ED en la firma (word[4]) sirve de centinela de "firmware terminado".
//
//  Mapa axil_soc (0x8000_0000, 64K): 0x00 CONTROL(b0 halt) 0x04 STATUS
//    0x08 DBG_PC 0x10 DDR_BASE_LO 0x14 DDR_BASE_HI 0x1000 IMEM 0x2000 DMEM
//  DDR reservada: 0x7000_0000 (rv32i_reserved, 16 MB).
//  Layout firma en DDR (word = 4 bytes):
//    word0 STATUS tras Sync (=1)   word1 MPD_LO (=40=0x28)   word2 MPD_HI (=0)
//    word3 OFFSET (=0)             word4 doorbell (=0xD0ED, centinela)
//
//  Compilar: aarch64-linux-gnu-gcc -O2 -static ptp_verify.c -o ptp_verify
//  Uso:      ./ptp_verify ptp_bringup.mem ptp_signature.txt
// ===========================================================================
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <string.h>
#define SOC_BASE   0x80000000UL
#define SOC_SIZE   0x10000UL
#define DDR_BASE   0x70000000UL
#define DDR_SIZE   0x1000UL
#define R_CONTROL  0x0000
#define R_STATUS   0x0004
#define R_DBGPC    0x0008
#define R_DDRLO    0x0010
#define R_DDRHI    0x0014
#define W_IMEM     0x1000
#define DOORBELL   0x0000D0EDU   /* centinela: word[4] de la firma */
#define SENT_IDX   4
#define SIG_WORDS  5
static volatile uint32_t *soc;
static volatile uint32_t *ddr;
static void wr(uint32_t o,uint32_t v){ soc[o/4]=v; }
static uint32_t rd(uint32_t o){ return soc[o/4]; }
int main(int argc,char**argv){
    if(argc<3){ fprintf(stderr,"uso: %s prog.mem ptp_signature.txt\n",argv[0]); return 2; }
    int fd=open("/dev/mem",O_RDWR|O_SYNC);
    if(fd<0){ perror("open /dev/mem"); return 1; }
    soc=mmap(NULL,SOC_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,SOC_BASE);
    ddr=mmap(NULL,DDR_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,DDR_BASE);
    if(soc==MAP_FAILED||ddr==MAP_FAILED){ perror("mmap"); return 1; }
    // limpiar la zona DDR de firma (por si hay residuo de un run anterior)
    for(int i=0;i<16;i++) ddr[i]=0;
    // 1) halt
    wr(R_CONTROL,1);
    // 2) cargar firmware por IMEM
    FILE*fp=fopen(argv[1],"r"); if(!fp){ perror("open .mem"); return 1; }
    char line[64]; uint32_t idx=0;
    while(fgets(line,sizeof line,fp)) wr(W_IMEM+ (idx++)*4, (uint32_t)strtoul(line,NULL,16));
    fclose(fp);
    printf("firmware: %u instrucciones cargadas\n",idx);
    // 3) DDR_BASE = 0x7000_0000
    wr(R_DDRLO,(uint32_t)(DDR_BASE&0xFFFFFFFF));
    wr(R_DDRHI,(uint32_t)(DDR_BASE>>32));
    // 4) soltar el core
    wr(R_CONTROL,0);
    // 5) sondear el doorbell en DDR (word 4) como centinela de fin
    uint32_t guard=0, sent=0;
    while(guard<200000000){
        sent=ddr[SENT_IDX];
        if(sent==DOORBELL) break;
        guard++;
    }
    if(sent!=DOORBELL){
        printf("FALLO: doorbell no aparecio en DDR (leido 0x%08X, PC=0x%08X, STATUS=0x%08X)\n",
               sent, rd(R_DBGPC), rd(R_STATUS));
        return 1;
    }
    printf("doorbell OK en DDR (0x%08X) - firmware termino\n",sent);
    // 6) leer la firma de DDR y comparar contra el oraculo
    FILE*fe=fopen(argv[2],"r"); if(!fe){ perror("open ptp_signature"); return 1; }
    int ok=1;
    const char*names[SIG_WORDS]={"STATUS","MPD_LO","MPD_HI","OFFSET","DOORBELL"};
    for(int i=0;i<SIG_WORDS;i++){
        uint32_t got=ddr[i];
        if(!fgets(line,sizeof line,fe)){ ok=0; break; }
        uint32_t exp=(uint32_t)strtoul(line,NULL,16);
        printf("  sig[%d] %-8s = 0x%08X  (esperado 0x%08X) %s\n",
               i, names[i], got, exp, got==exp?"OK":"MISMATCH");
        if(got!=exp) ok=0;
    }
    fclose(fe);
    printf(ok?"\nPTP SILICON PASS\n":"\nPTP SILICON FAIL\n");
    return ok?0:1;
}
