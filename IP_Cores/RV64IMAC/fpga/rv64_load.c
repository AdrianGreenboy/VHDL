/*
 * rv64_load.c - cargador del PS (A72, PetaLinux) para el prototipo RV64IMAC.
 * NO VALIDADO EN SILICIO TODAVIA (Paso 9).
 *
 * Copia OpenSBI (fw_jump.bin) y el kernel (Image) a la reserva no-map de la DDR,
 * suelta el reset del SoC y hace de consola: drena la UART del lado host del
 * banco de control y le envia lo que se teclee.
 *
 *   aarch64-linux-gnu-gcc -O2 -static -o rv64_load rv64_load.c
 *   ./rv64_load fw_jump.bin Image
 *
 * CUIDADO (lecciones del RV32IMA): memcpy/memset de glibc aarch64 usan DC ZVA y
 * stp de 128 bits, que dan SIGBUS sobre memoria no-map. Toda escritura a la
 * reserva se hace palabra a palabra con punteros volatile.
 */
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <termios.h>
#include <unistd.h>

#define DDR_BASE   0x70000000UL          /* el core la ve en 0x8000_0000 */
#define DDR_SIZE   (128UL << 20)
#define SBI_OFF    0x000000UL            /* fw_jump: FW_TEXT_START 0x8000_0000 */
#define KERNEL_OFF 0x200000UL            /* FW_JUMP_ADDR 0x8020_0000 */
#define CTRL_BASE  0xA4000000UL
#define CTRL_SIZE  0x10000UL

#define REG_CTRL     0x00
#define REG_STATUS   0x04
#define REG_RET_LO   0x08
#define REG_RET_HI   0x0C
#define REG_PC       0x10
#define HU(n)        (0x40 + 4 * (n))     /* UART del lado host, registro n */
#define CTRL_RUN     (1u << 0)
#define CTRL_RST     (1u << 1)

#define CLK_HZ  50000000u
#define BAUD    115200u

static volatile uint32_t *ctrl;
static volatile uint32_t *ddr;
static struct termios old_tio;

static void wr(unsigned off, uint32_t v) { ctrl[off / 4] = v; }
static uint32_t rd(unsigned off) { return ctrl[off / 4]; }

static void restore_tty(void) { tcsetattr(0, TCSANOW, &old_tio); }
static void on_sig(int s) { (void)s; restore_tty(); wr(REG_CTRL, CTRL_RST); _exit(0); }

static size_t load(const char *path, unsigned long off)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }
    struct stat st;
    fstat(fileno(f), &st);
    if (off + st.st_size > DDR_SIZE) { fprintf(stderr, "%s no cabe\n", path); exit(1); }
    uint32_t w;
    size_t n = 0;
    volatile uint32_t *p = ddr + off / 4;
    memset(&w, 0, 4);
    while (fread(&w, 1, 4, f) > 0) { *p++ = w; n += 4; w = 0; }
    fclose(f);
    /* relectura: la copia palabra a palabra es la unica fuente de verdad */
    rewind(f = fopen(path, "rb"));
    p = ddr + off / 4;
    for (size_t i = 0; i < n / 4; i++) {
        uint32_t e = 0;
        if (fread(&e, 1, 4, f) == 0) break;
        if (p[i] != e) { fprintf(stderr, "%s: verificacion fallida en +%#zx\n", path, i * 4); exit(1); }
    }
    fclose(f);
    return n;
}

int main(int argc, char **argv)
{
    if (argc != 3) { fprintf(stderr, "uso: %s fw_jump.bin Image\n", argv[0]); return 1; }
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("/dev/mem"); return 1; }
    ctrl = mmap(NULL, CTRL_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, CTRL_BASE);
    ddr  = mmap(NULL, DDR_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, DDR_BASE);
    if (ctrl == MAP_FAILED || ddr == MAP_FAILED) { perror("mmap"); return 1; }

    wr(REG_CTRL, CTRL_RST);                               /* SoC en reset durante la carga */
    printf("OpenSBI: %zu bytes\n", load(argv[1], SBI_OFF));
    printf("kernel:  %zu bytes\n", load(argv[2], KERNEL_OFF));

    /* UART del lado host: mismo divisor que programara OpenSBI (DTS: 50 MHz, 115200) */
    unsigned div = (CLK_HZ + 8 * BAUD) / (16 * BAUD);
    wr(HU(3), 0x83); wr(HU(0), div & 0xFF); wr(HU(1), div >> 8); wr(HU(3), 0x03);
    wr(HU(2), 0x07);                                       /* FIFOs on y vaciados */

    tcgetattr(0, &old_tio);
    struct termios t = old_tio;
    t.c_lflag &= ~(ICANON | ECHO);
    t.c_cc[VMIN] = 0; t.c_cc[VTIME] = 0;
    tcsetattr(0, TCSANOW, &t);
    signal(SIGINT, on_sig);
    signal(SIGTERM, on_sig);

    wr(REG_CTRL, CTRL_RUN);                                /* a correr: vector de reset 0x1000 */
    printf("RV64IMAC en marcha (Ctrl-C para parar)\n");
    for (;;) {
        while (rd(HU(5)) & 1) putchar(rd(HU(0)) & 0xFF);  /* LSR.DR -> RBR */
        fflush(stdout);
        char c;
        if (read(0, &c, 1) == 1 && (rd(HU(5)) & 0x20)) wr(HU(0), (uint8_t)c);
        usleep(200);
    }
}
