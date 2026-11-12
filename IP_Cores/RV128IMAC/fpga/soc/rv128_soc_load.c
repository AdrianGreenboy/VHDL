/*
 * rv128_soc_load.c - A72 (PetaLinux) loader for the RV128IMAC SoC on the TE0950 (M5).
 * Derived from RV64IMAC/fpga/rv64_load.c (validated on the board: Linux to /init).
 *
 *   gcc -O2 -o rv128_soc_load rv128_soc_load.c          (on the board)
 *
 *   ./rv128_soc_load [options] file@offset [file@offset ...]
 *     -m rv64|rv128   core mode (default rv64)
 *     -d N            divisor of the host-side UART (default 33 = 115200 baud at 60 MHz, -1.4 %,
 *                     as the board DTS; use 1 for the RTOS tests and bare-metal programs,
 *                     which run their UART at divisor 1)
 *     -t ADDR         address of tohost as the core sees it (0x8...); enables the verdict:
 *                     ends on the first tohost write with bit0 = 1, or on the timeout
 *     -T S            timeout in seconds with -t (default 60)
 *     -z MIB          MiB of DDR cleared before loading (default 8: the RAM the RTOS and
 *                     the testbenches assume; 0 = none)
 *   Offsets are from 0x8000_0000 (core view); DDR physical = 0x7000_0000 + offset.
 *
 * Linux:  ./rv128_soc_load -m rv64 fw_jump.bin@0 Image@0x200000         (interactive console)
 * Test:   ./rv128_soc_load -m rv64 -d 1 -t 0x80006780 freertos_test.bin@0
 *         stderr: code=<n> retired=<n> cycles=<n>   or   TIMEOUT retired=<n> pc=<hex>
 *         exit:   0 PASS, 1 FAIL, 2 TIMEOUT, 3 setup error
 *
 * Lessons kept from the RV32IMA/RV64IMAC loaders: every access to the no-map DDR and to
 * the bank is a single 32-bit volatile access (glibc memcpy/memset on aarch64 use DC ZVA
 * and 128-bit stores that fault on device memory).
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
#include <time.h>
#include <unistd.h>

#define DDR_BASE   0x70000000UL          /* the core sees it at 0x8000_0000 */
#define DDR_SIZE   (128UL << 20)
#define CORE_BASE  0x80000000UL
#define CTRL_BASE  0xA4000000UL
#define CTRL_SIZE  0x10000UL

#define REG_CTRL     0x00
#define REG_STATUS   0x04
#define REG_RET_LO   0x08
#define REG_RET_HI   0x0C
#define REG_PC       0x10
#define REG_THADDR   0x18
#define REG_ID       0x1C
#define REG_TH_LO    0x20
#define REG_TH_HI    0x24
#define REG_CYC_LO   0x28
#define REG_CYC_HI   0x2C
#define REG_THR_LO   0x30
#define REG_THR_HI   0x34
#define HU(n)        (0x40 + 4 * (n))     /* host-side UART, register n */
#define CTRL_RUN     (1u << 0)
#define CTRL_RST     (1u << 1)
#define CTRL_M64     (1u << 2)
#define ST_RUN       (1u << 0)
#define ST_TOHOST    (1u << 1)
#define ST_M64       (1u << 2)
#define SOC_ID       0x52534F43u          /* "RSOC" */

static volatile uint32_t *ctrl;
static volatile uint32_t *ddr;
static struct termios old_tio;
static int interactive;

static void wr(unsigned off, uint32_t v) { ctrl[off / 4] = v; }
static uint32_t rd(unsigned off) { return ctrl[off / 4]; }
static uint64_t rd64(unsigned lo) { uint32_t l = rd(lo); return ((uint64_t)rd(lo + 4) << 32) | l; }

static void restore_tty(void) { if (interactive) tcsetattr(0, TCSANOW, &old_tio); }
static void on_sig(int s) { (void)s; restore_tty(); wr(REG_CTRL, CTRL_RST); _exit(2); }

static size_t load(const char *path, unsigned long off)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(3); }
    struct stat st;
    fstat(fileno(f), &st);
    if (off % 4 || off + st.st_size > DDR_SIZE) { fprintf(stderr, "%s: offset/size\n", path); exit(3); }
    uint32_t w = 0;
    size_t n = 0;
    volatile uint32_t *p = ddr + off / 4;
    while (fread(&w, 1, 4, f) > 0) { *p++ = w; n += 4; w = 0; }
    rewind(f);                            /* read back: the word copy is the only truth */
    p = ddr + off / 4;
    for (size_t i = 0; i < n / 4; i++) {
        uint32_t e = 0;
        if (fread(&e, 1, 4, f) == 0) break;
        if (p[i] != e) { fprintf(stderr, "%s: verify failed at +%#zx\n", path, i * 4); exit(3); }
    }
    fclose(f);
    return n;
}

/* returns the number of bytes moved. No fflush per byte: stdout is a file in run_all.sh */
static int drain(void)
{
    int n = 0;
    while (rd(HU(5)) & 1) { putchar(rd(HU(0)) & 0xFF); n++; }   /* LSR.DR -> RBR */
    return n;
}

int main(int argc, char **argv)
{
    int m64 = 1, opt;
    unsigned div = 33, zero_mib = 8, timeout = 60;
    unsigned long tohost = 0;
    while ((opt = getopt(argc, argv, "m:d:t:T:z:")) != -1) {
        switch (opt) {
        case 'm': m64 = strcmp(optarg, "rv128") != 0; break;
        case 'd': div = strtoul(optarg, NULL, 0); break;
        case 't': tohost = strtoul(optarg, NULL, 0); break;
        case 'T': timeout = strtoul(optarg, NULL, 0); break;
        case 'z': zero_mib = strtoul(optarg, NULL, 0); break;
        default: fprintf(stderr, "see the header of rv128_soc_load.c\n"); return 3;
        }
    }
    if (optind >= argc || div == 0 || div > 0xFFFF || zero_mib > 128) {
        fprintf(stderr, "usage: %s [-m rv64|rv128] [-d div] [-t tohost] [-T s] [-z MiB] file@off...\n", argv[0]);
        return 3;
    }
    interactive = (tohost == 0);
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("/dev/mem"); return 3; }
    ctrl = mmap(NULL, CTRL_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, CTRL_BASE);
    ddr  = mmap(NULL, DDR_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, DDR_BASE);
    if (ctrl == MAP_FAILED || ddr == MAP_FAILED) { perror("mmap"); return 3; }
    if (rd(REG_ID) != SOC_ID) { fprintf(stderr, "ID %08x: not the RV128IMAC SoC bitstream\n", rd(REG_ID)); return 3; }

    wr(REG_CTRL, CTRL_RST | (m64 ? CTRL_M64 : 0));        /* SoC in reset while loading */
    for (unsigned long i = 0; i < (zero_mib << 20) / 4; i++) ddr[i] = 0;
    for (int i = optind; i < argc; i++) {
        char *at = strrchr(argv[i], '@');
        if (!at) { fprintf(stderr, "%s: missing @offset\n", argv[i]); return 3; }
        *at = 0;
        unsigned long off = strtoul(at + 1, NULL, 0);
        fprintf(stderr, "%s: %zu bytes at %#lx\n", argv[i], load(argv[i], off), CORE_BASE + off);
    }
    wr(REG_THADDR, (uint32_t)tohost);

    /* host-side UART: same divisor as the program on the core */
    wr(HU(3), 0x83); wr(HU(0), div & 0xFF); wr(HU(1), div >> 8); wr(HU(3), 0x03);
    wr(HU(2), 0x07);
    while (rd(HU(5)) & 1) (void)rd(HU(0));

    signal(SIGINT, on_sig);
    signal(SIGTERM, on_sig);
    if (interactive) {
        tcgetattr(0, &old_tio);
        struct termios t = old_tio;
        t.c_lflag &= ~(ICANON | ECHO);
        t.c_cc[VMIN] = 0; t.c_cc[VTIME] = 0;
        tcsetattr(0, TCSANOW, &t);
    }

    /* keep the reset with the mode set for a moment, then run (reset vector 0x1000) */
    wr(REG_CTRL, CTRL_RST | (m64 ? CTRL_M64 : 0));
    wr(REG_CTRL, CTRL_RUN | (m64 ? CTRL_M64 : 0));
    /* no sleep here: at divisor 1 the first console bytes arrive within a millisecond */
    fprintf(stderr, "RV128IMAC SoC running in %s mode%s\n", m64 ? "RV64" : "RV128",
            interactive ? " (Ctrl-C to stop)" : "");

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    /* Test mode busy-polls: the SoC UART runs at divisor 1 (3.75 Mbaud at 60 MHz) and the
     * 16-byte RX FIFO of the host UART fills in ~50 us, less than one usleep() wake-up on
     * PetaLinux, so any sleep loses console bytes. Interactive mode (115200) may sleep. */
    unsigned idle = 0;
    for (;;) {
        if (drain()) { idle = 0; } else if (++idle == 1000) { fflush(stdout); }
        if (interactive) {
            char c;
            if (read(0, &c, 1) == 1 && (rd(HU(5)) & 0x20)) wr(HU(0), (uint8_t)c);
        } else if (rd(REG_STATUS) & ST_TOHOST) {
            for (int i = 0; i < 20000; i++) drain();      /* let the UART finish the report */
            fflush(stdout);
            uint64_t v = rd64(REG_TH_LO);
            unsigned code = (unsigned)(v >> 1);
            fprintf(stderr, "code=%u retired=%llu cycles=%llu\n", code,
                    (unsigned long long)rd64(REG_THR_LO), (unsigned long long)rd64(REG_CYC_LO));
            wr(REG_CTRL, CTRL_RST);
            return code == 0 ? 0 : 1;
        } else {
            clock_gettime(CLOCK_MONOTONIC, &t1);
            if ((unsigned)(t1.tv_sec - t0.tv_sec) >= timeout) {
                fflush(stdout);
                fprintf(stderr, "TIMEOUT retired=%llu pc=%08x\n", (unsigned long long)rd64(REG_RET_LO), rd(REG_PC));
                wr(REG_CTRL, CTRL_RST);
                return 2;
            }
        }
        if (interactive) { fflush(stdout); if (!(rd(HU(5)) & 1)) usleep(100); }
    }
}
