/* ===========================================================================
 * HERCOSSNUX Core 21 - ETH GT : herramienta de Linux de la placa (TE0950)
 *
 *   eth21 status                      estado del GT, relojes medidos, contadores
 *   eth21 gtreset                     reinicia la secuencia de reset del GT
 *   eth21 selftest [N]                loopback PMA interno: N tramas (100000),
 *                                     CRC inyectado en la primera, contadores
 *                                     exactos contra lo esperado -> PASS/FAIL
 *   eth21 autodetect                  con el cable al PC: prueba los ordenes de
 *                                     bits del GT y deja el bueno configurado
 *   eth21 flags TXREV TXSWAP RXREV RXSWAP   fija los flags a mano (0/1)
 *   eth21 send [opciones]             rafaga UDP hacia el PC
 *       --peer-mac aa:bb:cc:dd:ee:ff  (obligatorio salvo broadcast)
 *       --peer-ip 192.168.21.1 --own-ip 192.168.21.2 --sport 21008 --dport 21009
 *       --len L | --len-min A --len-max B --len-step S   (payload 18..1472)
 *       --count N | --cont            --gap G (ciclos extra entre tramas)
 *   eth21 stop                        para la rafaga continua
 *   eth21 counters                    instantanea de los 23 contadores
 * Opcion global: --base 0xA4000000 (direccion del banco en el bus del PS)
 *
 * Acceso por /dev/mem (como mac-selftest del Core 20). MIT License.
 * ======================================================================== */
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define R_ID       0x00
#define R_SCRATCH  0x04
#define R_CTRL     0x08
#define R_CMD      0x0C
#define R_STATUS   0x10
#define R_GTCTRL   0x14
#define R_GAP      0x18
#define R_SNAP     0x1C
#define R_OWNLO    0x20
#define R_OWNHI    0x24
#define R_PEERLO   0x28
#define R_PEERHI   0x2C
#define R_OWNIP    0x30
#define R_PEERIP   0x34
#define R_PORTS    0x38
#define R_LENCFG   0x3C
#define R_LENSTEP  0x40
#define R_COUNT    0x44
#define R_TXCLK    0x48
#define R_RXCLK    0x4C
#define R_CNT      0x80

#define C_MAC_EN   (1u << 0)
#define C_LOOP     (1u << 1)
#define C_PROMISC  (1u << 2)
#define C_CONT     (1u << 3)
#define C_TXREV    (1u << 4)
#define C_TXSWAP   (1u << 5)
#define C_RXREV    (1u << 6)
#define C_RXSWAP   (1u << 7)
#define C_FLAGS    (C_TXREV | C_TXSWAP | C_RXREV | C_RXSWAP)

#define CMD_SOFT   (1u << 0)
#define CMD_CLR    (1u << 1)
#define CMD_START  (1u << 2)
#define CMD_STOP   (1u << 3)
#define CMD_INJ    (1u << 4)
#define CMD_GTRST  (1u << 5)

#define NCNT 23
static const char *CNAME[NCNT] = {
  "TX_FRAMES", "TX_BYTES", "RX_OK", "RX_BYTES", "RX_CRC_ERR", "RX_RUNT",
  "RX_OVERSIZE", "RX_ABORT", "RX_FILTERED", "RX_PROTO", "CHK_OK", "CHK_BAD",
  "CHK_SEQ_ERR", "CHK_RXERR", "BURST_CYCLES", "TX_UNDERRUN", "BLK_SLIPS",
  "BAD_SYNC_HDR", "LOCK_LOSS", "RX_BLOCKS", "RX_IDLE", "RX_LF", "RX_RF"};

static volatile uint32_t *R;

static uint32_t rd(uint32_t a) { return R[a >> 2]; }
static void wr(uint32_t a, uint32_t v) { R[a >> 2] = v; }
static void msleep(int ms) { usleep(ms * 1000); }

static int wait_bit(uint32_t a, uint32_t mask, uint32_t val, int ms)
{
  for (int i = 0; i < ms; i++) {
    if ((rd(a) & mask) == val) return 0;
    msleep(1);
  }
  return -1;
}

static void cmd(uint32_t c)
{
  wr(R_CMD, c);
  if (c & 0x1F) {
    wait_bit(R_STATUS, 1u << 9, 0, 100);              /* CMD_BUSY */
    if (rd(R_STATUS) & (1u << 10))                    /* CMD_TIMEOUT */
      printf("aviso: CMD 0x%02X sin confirmar por algun dominio del GT "
             "(reloj parado o en reset): la configuracion nueva no se aplico ahi. "
             "STATUS=0x%08X\n", c, rd(R_STATUS));
  }
}

static int snap(uint32_t *c)
{
  wr(R_SNAP, 1);
  int r = wait_bit(R_STATUS, 1u << 8, 1u << 8, 200);
  for (int i = 0; i < NCNT; i++) c[i] = rd(R_CNT + 4 * i);
  return r;
}

static double mhz(uint32_t meas) { return meas * 1280.0 / 1e6; }

static void print_status(void)
{
  uint32_t s = rd(R_STATUS);
  printf("ID        : 0x%08X\n", rd(R_ID));
  printf("STATUS    : 0x%08X\n", s);
  static const char *CS[4] = {"PG", "PLLRST", "PLLWAIT", "RUN"};
  printf("  GT      : powergood=%u pll_lock=%u tx_done=%u rx_done=%u cdr_lock=%u\n",
         (s >> 16) & 1, (s >> 17) & 1, (s >> 18) & 1, (s >> 19) & 1, (s >> 20) & 1);
  printf("  reset   : fase=%s tx_ok=%u rx_ok=%u tx_ready=%u rx_ready=%u "
         "txclk_vivo=%u rxclk_vivo=%u\n", CS[(s >> 24) & 3], (s >> 26) & 1,
         (s >> 27) & 1, (s >> 21) & 1, (s >> 22) & 1, (s >> 23) & 1, (s >> 28) & 1);
  printf("  enlace  : block_lock=%u link_up=%u  gen busy=%u done=%u  rx_act=%u tx_act=%u\n",
         s & 1, (s >> 5) & 1, (s >> 1) & 1, (s >> 2) & 1, (s >> 3) & 1, (s >> 4) & 1);
  uint32_t c = rd(R_CTRL);
  printf("CTRL      : 0x%03X  (mac_en=%u loopback=%u promisc=%u cont=%u "
         "tx_rev=%u tx_swap=%u rx_rev=%u rx_swap=%u)\n", c, c & 1, (c >> 1) & 1,
         (c >> 2) & 1, (c >> 3) & 1, (c >> 4) & 1, (c >> 5) & 1, (c >> 6) & 1,
         (c >> 7) & 1);
  printf("relojes   : TXUSRCLK %.3f MHz   RXUSRCLK %.3f MHz\n",
         mhz(rd(R_TXCLK)), mhz(rd(R_RXCLK)));
}

static void print_counters(void)
{
  uint32_t c[NCNT];
  if (snap(c)) printf("(aviso: SNAP incompleto, STATUS=0x%08X)\n", rd(R_STATUS));
  for (int i = 0; i < NCNT; i++) printf("  %-13s %10u\n", CNAME[i], c[i]);
}

static int gt_up(int ms)
{
  if (wait_bit(R_STATUS, (1u << 21) | (1u << 22), (1u << 21) | (1u << 22), ms)) {
    printf("FALLO: el GT no termina el reset (STATUS=0x%08X)\n", rd(R_STATUS));
    return -1;
  }
  return 0;
}

/* --------------------------------------------------------------------------
 * selftest: loopback PMA near-end
 * ------------------------------------------------------------------------ */
static int selftest(uint32_t n)
{
  const uint32_t lmin = 18, lmax = 1472, lstep = 37;
  uint32_t c[NCNT];
  uint64_t txb = 0, first = 0;
  uint32_t l = lmin;
  for (uint32_t i = 0; i < n; i++) {
    uint64_t w = 42 + l + 4;                  /* trama + FCS */
    if (i == 0) first = w;
    txb += w;
    l = (l + lstep > lmax) ? lmin : l + lstep;
  }
  uint32_t flags = rd(R_CTRL) & C_FLAGS;
  wr(R_CTRL, C_MAC_EN | C_LOOP | C_PROMISC | flags);
  wr(R_LENCFG, (lmax << 16) | lmin);
  wr(R_LENSTEP, lstep);
  wr(R_COUNT, n);
  wr(R_GAP, 0);
  cmd(CMD_CLR);                               /* captura la configuracion */
  wr(R_CMD, CMD_GTRST);                       /* el loopback necesita reset del GT */
  msleep(5);
  if (gt_up(2000)) return 1;
  cmd(CMD_CLR);
  if (wait_bit(R_STATUS, 1, 1, 1000)) {
    printf("FALLO: sin block lock en loopback (STATUS=0x%08X)\n", rd(R_STATUS));
    return 1;
  }
  msleep(2);
  cmd(CMD_CLR);
  cmd(CMD_INJ);
  cmd(CMD_START);
  if (wait_bit(R_STATUS, 1u << 2, 1u << 2, 20000)) {
    printf("FALLO: GEN_DONE no llega\n");
    return 1;
  }
  msleep(5);
  snap(c);
  struct { int i; uint64_t e; } exp[] = {
    {0, n}, {1, txb & 0xFFFFFFFFu}, {2, n - 1}, {3, (txb - first) & 0xFFFFFFFFu},
    {4, 1}, {5, 0}, {6, 0}, {7, 0}, {8, 0}, {9, 0}, {10, n - 1}, {11, 0}, {12, 0},
    {13, 1}, {15, 0}, {18, 0}, {21, 0}, {22, 0}};
  int bad = 0;
  printf("=== Core 21 - ETH GT - selftest en loopback PMA (%u tramas) ===\n", n);
  for (unsigned k = 0; k < sizeof exp / sizeof exp[0]; k++) {
    int i = exp[k].i;
    int ok = (c[i] == (uint32_t)exp[k].e);
    bad += !ok;
    printf("  %-13s %10u  esperado %10u %s\n", CNAME[i], c[i], (uint32_t)exp[k].e,
           ok ? "" : "<-- DISTINTO");
  }
  double f = mhz(rd(R_TXCLK)) * 1e6;
  double gbps = f > 0 ? (double)txb * 8.0 / ((double)c[14] / f) / 1e9 : 0;
  printf("  TXUSRCLK medido %.3f MHz; rafaga %u ciclos -> L2+FCS %.2f Gb/s\n",
         f / 1e6, c[14], gbps);
  printf("  slips=%u bad_sync_hdr=%u (desde el ultimo clear)\n", c[16], c[17]);
  wr(R_CTRL, rd(R_CTRL) & ~C_LOOP);
  cmd(CMD_CLR);
  wr(R_CMD, CMD_GTRST);
  printf("%s\n", bad ? "SELFTEST FAIL" : "SELFTEST PASS");
  return bad ? 1 : 0;
}

/* --------------------------------------------------------------------------
 * autodetect: orden de bits del GT con el PC al otro lado
 * ------------------------------------------------------------------------ */
static void measure(uint32_t ctrl, uint32_t *c)
{
  wr(R_CTRL, ctrl);
  cmd(CMD_CLR);
  msleep(300);
  snap(c);
}

static int autodetect(void)
{
  uint32_t c[NCNT];
  uint32_t base = rd(R_CTRL) & ~(C_FLAGS | C_LOOP);
  int rx_best = -1;
  printf("RX: idles/LF validos solo con el orden de bits correcto del receptor\n");
  printf("  rev swap | lock  blocks      idle        LF        RF     proto\n");
  for (int k = 0; k < 4; k++) {
    int rev = k >> 1, sw = k & 1;
    uint32_t f = (rev ? (C_TXREV | C_RXREV) : 0) | (sw ? (C_TXSWAP | C_RXSWAP) : 0);
    measure(base | f, c);
    uint32_t lock = rd(R_STATUS) & 1;
    uint64_t good = (uint64_t)c[20] + c[21] + c[22];
    printf("   %u    %u   |  %u  %9u %9u %9u %9u %9u\n", rev, sw, lock, c[19], c[20],
           c[21], c[22], c[9]);
    if (lock && c[19] > 1000 && good * 10 > (uint64_t)c[19] * 9 && rx_best < 0) rx_best = k;
  }
  if (rx_best < 0) {
    printf("FALLO: ninguna combinacion decodifica lo que manda el PC.\n"
           "  Comprueba: cable, 'ethtool <if>' en el PC (10000 forzado, autoneg off),\n"
           "  RX_POLARITY (CTRL b9) y que el GT este en la tasa correcta.\n");
    return 1;
  }
  uint32_t rxf = ((rx_best >> 1) ? C_RXREV : 0) | ((rx_best & 1) ? C_RXSWAP : 0);
  printf("RX correcto: rev=%d swap=%d. TX: el PC deja de mandar Remote Fault cuando nos decodifica\n",
         rx_best >> 1, rx_best & 1);
  int order[4] = {rx_best, rx_best ^ 1, rx_best ^ 2, rx_best ^ 3};
  for (int j = 0; j < 4; j++) {
    int k = order[j];
    uint32_t txf = ((k >> 1) ? C_TXREV : 0) | ((k & 1) ? C_TXSWAP : 0);
    measure(base | rxf | txf, c);
    printf("  TX rev=%d swap=%d : idle=%u LF=%u RF=%u\n", k >> 1, k & 1, c[20], c[21], c[22]);
    if (c[22] == 0 && c[20] > 1000) {
      printf("OK: flags TX rev=%d swap=%d / RX rev=%d swap=%d (CTRL=0x%03X). El PC ya ve el enlace.\n",
             k >> 1, k & 1, rx_best >> 1, rx_best & 1, rd(R_CTRL));
      return 0;
    }
  }
  printf("AVISO: el PC sigue mandando Remote Fault con todas las combinaciones de TX.\n"
         "  Prueba TX_POLARITY (CTRL b8) o revisa la tasa del PC. RX queda configurado.\n");
  wr(R_CTRL, base | rxf);
  cmd(CMD_CLR);
  return 1;
}

/* --------------------------------------------------------------------------
 * send
 * ------------------------------------------------------------------------ */
static int parse_mac(const char *s, uint32_t *lo, uint32_t *hi)
{
  unsigned b[6];
  if (sscanf(s, "%x:%x:%x:%x:%x:%x", &b[0], &b[1], &b[2], &b[3], &b[4], &b[5]) != 6) return -1;
  *lo = b[0] | (b[1] << 8) | (b[2] << 16) | ((uint32_t)b[3] << 24);
  *hi = b[4] | (b[5] << 8);
  return 0;
}

static int parse_ip(const char *s, uint32_t *ip)
{
  unsigned a, b, c, d;
  if (sscanf(s, "%u.%u.%u.%u", &a, &b, &c, &d) != 4) return -1;
  *ip = (a << 24) | (b << 16) | (c << 8) | d;
  return 0;
}

static int do_send(int argc, char **argv)
{
  uint32_t lmin = 1472, lmax = 1472, lstep = 0, count = 1000, gap = 0, cont = 0;
  uint32_t sport = 21008, dport = 21009;
  for (int i = 0; i < argc; i++) {
    const char *a = argv[i], *v = (i + 1 < argc) ? argv[i + 1] : NULL;
    uint32_t lo, hi, ip;
    if (!strcmp(a, "--peer-mac") && v) {
      if (parse_mac(v, &lo, &hi)) { printf("MAC invalida\n"); return 1; }
      wr(R_PEERLO, lo); wr(R_PEERHI, hi); i++;
    } else if (!strcmp(a, "--own-mac") && v) {
      if (parse_mac(v, &lo, &hi)) { printf("MAC invalida\n"); return 1; }
      wr(R_OWNLO, lo); wr(R_OWNHI, hi); i++;
    } else if (!strcmp(a, "--peer-ip") && v) {
      if (parse_ip(v, &ip)) { printf("IP invalida\n"); return 1; }
      wr(R_PEERIP, ip); i++;
    } else if (!strcmp(a, "--own-ip") && v) {
      if (parse_ip(v, &ip)) { printf("IP invalida\n"); return 1; }
      wr(R_OWNIP, ip); i++;
    } else if (!strcmp(a, "--len") && v) { lmin = lmax = strtoul(v, 0, 0); lstep = 0; i++; }
    else if (!strcmp(a, "--len-min") && v) { lmin = strtoul(v, 0, 0); i++; }
    else if (!strcmp(a, "--len-max") && v) { lmax = strtoul(v, 0, 0); i++; }
    else if (!strcmp(a, "--len-step") && v) { lstep = strtoul(v, 0, 0); i++; }
    else if (!strcmp(a, "--count") && v) { count = strtoul(v, 0, 0); i++; }
    else if (!strcmp(a, "--cont")) cont = 1;
    else if (!strcmp(a, "--gap") && v) { gap = strtoul(v, 0, 0); i++; }
    else if (!strcmp(a, "--sport") && v) { sport = strtoul(v, 0, 0); i++; }
    else if (!strcmp(a, "--dport") && v) { dport = strtoul(v, 0, 0); i++; }
    else { printf("opcion desconocida: %s\n", a); return 1; }
  }
  if (lmin < 18 || lmin > 1472 || lmax < 18 || lmax > 1472 || lstep > 1472) {
    printf("longitudes fuera de rango: payload 18..1472, paso 0..1472\n");
    return 1;
  }
  if (gap > 0xFFFF) { printf("gap maximo 65535\n"); return 1; }
  wr(R_PORTS, ((sport & 0xFFFF) << 16) | (dport & 0xFFFF));
  wr(R_LENCFG, ((lmax & 0x7FF) << 16) | (lmin & 0x7FF));
  wr(R_LENSTEP, lstep & 0x7FF);
  wr(R_COUNT, count);
  wr(R_GAP, gap);
  uint32_t ctrl = (rd(R_CTRL) & ~(C_CONT | C_LOOP)) | C_MAC_EN | (cont ? C_CONT : 0);
  wr(R_CTRL, ctrl);
  cmd(CMD_CLR);
  cmd(CMD_START);
  printf("rafaga lanzada: payload %u..%u (paso %u), %s, gap %u, puertos %u->%u\n",
         lmin, lmax, lstep, cont ? "continua (eth21 stop)" : "N tramas", gap, sport, dport);
  if (!cont) {
    if (wait_bit(R_STATUS, 1u << 2, 1u << 2, 600000)) printf("aviso: GEN_DONE no llega\n");
    print_counters();
  }
  return 0;
}

int main(int argc, char **argv)
{
  unsigned long base = 0xA4000000UL;
  int a = 1;
  if (argc > 2 && !strcmp(argv[1], "--base")) { base = strtoul(argv[2], 0, 0); a = 3; }
  if (a >= argc) {
    printf("uso: eth21 [--base 0x..] status|gtreset|selftest [N]|autodetect|"
           "flags TR TS RR RS|send [...]|stop|counters\n");
    return 2;
  }
  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd < 0) { perror("/dev/mem"); return 1; }
  R = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, base);
  if (R == MAP_FAILED) { perror("mmap"); return 1; }
  if (rd(R_ID) != 0x47544521) {
    printf("FALLO: ID 0x%08X en 0x%lX (esperado 0x47544521). Bitstream correcto?\n",
           rd(R_ID), base);
    return 1;
  }
  const char *c = argv[a];
  if (!strcmp(c, "status")) { print_status(); return 0; }
  if (!strcmp(c, "counters")) { print_counters(); return 0; }
  if (!strcmp(c, "gtreset")) { wr(R_CMD, CMD_GTRST); msleep(5); int r = gt_up(2000); print_status(); return r ? 1 : 0; }
  if (!strcmp(c, "selftest")) {
    if (gt_up(2000)) return 1;
    return selftest(a + 1 < argc ? strtoul(argv[a + 1], 0, 0) : 100000);
  }
  if (!strcmp(c, "autodetect")) { if (gt_up(2000)) return 1; return autodetect(); }
  if (!strcmp(c, "flags") && a + 4 < argc) {
    uint32_t f = (atoi(argv[a + 1]) ? C_TXREV : 0) | (atoi(argv[a + 2]) ? C_TXSWAP : 0) |
                 (atoi(argv[a + 3]) ? C_RXREV : 0) | (atoi(argv[a + 4]) ? C_RXSWAP : 0);
    wr(R_CTRL, (rd(R_CTRL) & ~C_FLAGS) | f);
    cmd(CMD_CLR);
    print_status();
    return 0;
  }
  if (!strcmp(c, "send")) return do_send(argc - a - 1, argv + a + 1);
  if (!strcmp(c, "stop")) { cmd(CMD_STOP); msleep(10); print_counters(); return 0; }
  printf("comando desconocido: %s\n", c);
  return 2;
}
