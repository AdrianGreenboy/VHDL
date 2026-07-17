// mmap_probe.c - diagnostico: prueba varios tamanos de mmap sobre /dev/mem
// para el CSR (0x80000000) y la DDR (0x70000000), y reporta cual funciona.
// Ayuda a confirmar el limite de mapeo de la region reservada.
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include <setjmp.h>

static sigjmp_buf jb;
static void onbus(int s){ (void)s; siglongjmp(jb,1); }

static void probe(int fd, const char*label, uint64_t base, uint64_t sz){
    void*p = mmap(NULL, sz, PROT_READ|PROT_WRITE, MAP_SHARED, fd, base);
    if(p==MAP_FAILED){ printf("  %s sz=0x%lx: MAP_FAILED (%s)\n",label,(unsigned long)sz,strerror(errno)); return; }
    // intentar leer el primer word bajo proteccion de SIGBUS
    if(sigsetjmp(jb,1)==0){
        volatile uint32_t v = ((volatile uint32_t*)p)[0];
        printf("  %s sz=0x%lx: OK ptr=%p val=0x%08x\n",label,(unsigned long)sz,p,v);
    } else {
        printf("  %s sz=0x%lx: SIGBUS al leer\n",label,(unsigned long)sz);
    }
    munmap(p,sz);
}

int main(void){
    signal(SIGBUS,onbus);
    int fd=open("/dev/mem",O_RDWR|O_SYNC);
    if(fd<0){perror("open");return 1;}
    printf("CSR 0x80000000:\n");
    probe(fd,"csr",0x80000000UL,0x1000);
    probe(fd,"csr",0x80000000UL,0x10000);
    printf("DDR 0x70000000:\n");
    probe(fd,"ddr",0x70000000UL,0x1000);
    probe(fd,"ddr",0x70000000UL,0x10000);
    probe(fd,"ddr",0x70000000UL,0x100000);
    probe(fd,"ddr",0x70000000UL,0x1000000);
    return 0;
}
