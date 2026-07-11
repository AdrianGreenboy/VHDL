// ptp_dump.c - carga el firmware de diagnostico y VUELCA la firma sin comparar.
// Uso: ./ptp_dump ptp_diag_hw.mem
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
#define SENT       0x0000D1A6U   /* centinela del firmware de diagnostico */
#define SENT_IDX   5
static volatile uint32_t *soc, *ddr;
static void wr(uint32_t o,uint32_t v){ soc[o/4]=v; }
static uint32_t rd(uint32_t o){ return soc[o/4]; }
int main(int argc,char**argv){
    if(argc<2){ fprintf(stderr,"uso: %s prog.mem\n",argv[0]); return 2; }
    int fd=open("/dev/mem",O_RDWR|O_SYNC);
    if(fd<0){ perror("open /dev/mem"); return 1; }
    soc=mmap(NULL,SOC_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,SOC_BASE);
    ddr=mmap(NULL,DDR_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,DDR_BASE);
    if(soc==MAP_FAILED||ddr==MAP_FAILED){ perror("mmap"); return 1; }
    for(int i=0;i<16;i++) ddr[i]=0;
    wr(R_CONTROL,1);
    FILE*fp=fopen(argv[1],"r"); if(!fp){ perror("open .mem"); return 1; }
    char line[64]; uint32_t idx=0;
    while(fgets(line,sizeof line,fp)) wr(W_IMEM+(idx++)*4,(uint32_t)strtoul(line,NULL,16));
    fclose(fp);
    printf("firmware: %u instrucciones\n",idx);
    wr(R_DDRLO,(uint32_t)(DDR_BASE&0xFFFFFFFF));
    wr(R_DDRHI,(uint32_t)(DDR_BASE>>32));
    wr(R_CONTROL,0);
    uint32_t guard=0, sent=0;
    while(guard<200000000){ sent=ddr[SENT_IDX]; if(sent==SENT) break; guard++; }
    if(sent!=SENT){
        printf("centinela no aparecio (leido 0x%08X, PC=0x%08X, STATUS=0x%08X)\n",
               sent, rd(R_DBGPC), rd(R_STATUS));
        printf("volcado parcial de DDR de todos modos:\n");
    } else {
        printf("centinela OK, firmware termino\n");
    }
    const char*n[6]={"STATUS_sync","STATUS_pdelay","MPD_LO","MPD_HI","iter_count","centinela"};
    for(int i=0;i<6;i++)
        printf("  DIAG[%d] %-14s = 0x%08X (%u)\n", i, n[i], ddr[i], ddr[i]);
    return 0;
}
