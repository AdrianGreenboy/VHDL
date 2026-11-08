/*
 * rv128_load.c - A72 (PetaLinux) loader for the RV128IMAC bare-metal prototype.
 *
 *   aarch64-linux-gnu-gcc -O2 -static -o rv128_load rv128_load.c     (or gcc on the board)
 *   ./rv128_load <prog.bin> <tohost_offset_hex> [timeout_s]
 *
 * Holds the core in reset, clears the BRAM, writes the program word by word, reads it
 * back, sets TOHOST_OFF and releases RUN. Console bytes go to stdout; the result line
 * goes to stderr in the same format as tb_proto.vhd:
 *   code=<n> retired=<n> cycles=<n>         or   TIMEOUT retired=<n> pc=<hex>
 * Exit status: 0 PASS, 1 FAIL (code != 0), 2 TIMEOUT, 3 setup error.
 *
 * All accesses to the bank are single 32-bit volatile accesses (no memcpy: glibc on
 * aarch64 uses DC ZVA / 128-bit stores that fault on device memory).
 */
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define CTRL_BASE  0xA4000000UL
#define CTRL_SIZE  0x40000UL
#define WIN        0x20000u

#define REG_CTRL      0x00
#define REG_STATUS    0x04
#define REG_RET_LO    0x08
#define REG_PC        0x10
#define REG_TOHOST    0x14
#define REG_CODE      0x18
#define REG_CONSOLE   0x1C
#define REG_CYC_LO    0x20
#define REG_CYC_HI    0x24
#define REG_HRET_LO   0x28
#define REG_HRET_HI   0x2C
#define REG_MEMKB     0x30
#define REG_ID        0x34

static volatile uint32_t *bank;
static void wr(unsigned off, uint32_t v) { bank[off / 4] = v; }
static uint32_t rd(unsigned off) { return bank[off / 4]; }

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s prog.bin tohost_offset_hex [timeout_s]\n", argv[0]);
        return 3;
    }
    unsigned tohost = (unsigned)strtoul(argv[2], NULL, 16);
    double timeout = argc > 3 ? atof(argv[3]) : 10.0;

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("/dev/mem"); return 3; }
    bank = mmap(NULL, CTRL_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, CTRL_BASE);
    if (bank == MAP_FAILED) { perror("mmap"); return 3; }
    if (rd(REG_ID) != 0x52563132u) {
        fprintf(stderr, "ID 0x%08x != 0x52563132: is the RV128 PDI loaded?\n", rd(REG_ID));
        return 3;
    }
    unsigned mem = rd(REG_MEMKB) * 1024u;

    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror(argv[1]); return 3; }
    static uint8_t buf[512 * 1024];
    size_t n = fread(buf, 1, sizeof buf, f);
    fclose(f);
    if (n > mem) { fprintf(stderr, "program %zu B > BRAM %u B\n", n, mem); return 3; }
    while (n % 4) buf[n++] = 0;

    wr(REG_CTRL, 2);                                    /* RST: core held in reset */
    for (unsigned o = 0; o < mem; o += 4) wr(WIN + o, 0);
    for (unsigned o = 0; o < n; o += 4) {
        uint32_t w = buf[o] | buf[o + 1] << 8 | buf[o + 2] << 16 | (uint32_t)buf[o + 3] << 24;
        wr(WIN + o, w);
    }
    for (unsigned o = 0; o < n; o += 4) {
        uint32_t w = buf[o] | buf[o + 1] << 8 | buf[o + 2] << 16 | (uint32_t)buf[o + 3] << 24;
        uint32_t r = rd(WIN + o);
        if (r != w) {
            fprintf(stderr, "BRAM readback error at +0x%x: wrote %08x read %08x\n", o, w, r);
            return 3;
        }
    }
    wr(REG_TOHOST, tohost);
    wr(REG_CTRL, 0);                                    /* clear RST (FIFO reset released) */
    wr(REG_CTRL, 1);                                    /* RUN */

    double t0 = now();
    int halted = 0;
    for (;;) {
        uint32_t st = rd(REG_STATUS);
        while (st & 4) {
            uint32_t c = rd(REG_CONSOLE);
            if (c & 0x100) putchar(c & 0xFF);
            st = rd(REG_STATUS);
        }
        if (st & 2) { halted = 1; break; }
        if (now() - t0 > timeout) break;
    }
    fflush(stdout);
    if (!halted) {
        fprintf(stderr, "TIMEOUT retired=%u pc=%08x\n", rd(REG_RET_LO), rd(REG_PC));
        wr(REG_CTRL, 2);
        return 2;
    }
    unsigned code = rd(REG_CODE);
    unsigned long long ret = rd(REG_HRET_LO) | (unsigned long long)rd(REG_HRET_HI) << 32;
    unsigned long long cyc = rd(REG_CYC_LO) | (unsigned long long)rd(REG_CYC_HI) << 32;
    fprintf(stderr, "code=%u retired=%llu cycles=%llu\n", code, ret, cyc);
    wr(REG_CTRL, 2);                                    /* park the core */
    return code ? 1 : 0;
}
