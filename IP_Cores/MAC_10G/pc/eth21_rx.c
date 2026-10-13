/* ===========================================================================
 * HERCOSSNUX Core 21 - ETH GT : receptor UDP para el PC (Linux)
 *
 * Recibe las tramas del generador de la TE0950 y verifica cada una igual que
 * el checker del FPGA:
 *   payload[0..3] = seq (LE), [4..7] = ~seq, [8..] = xorshift64 sembrado con
 *   seed_of(seq) = 0x9E3779B97F4A7C15 ^ seq  (8 bytes LE por palabra)
 * y cuenta: recibidas, buenas, malas (payload), perdidas (huecos de seq),
 * repetidas/desordenadas y reinicios (seq vuelve atras > 65536: rafaga nueva
 * del generador, se re-sincroniza sin contar desordenadas). Cada segundo imprime kpps, Gb/s de payload UDP y
 * Gb/s en el cable (L1: + 42 cabeceras + 4 FCS + 20 preambulo/IPG).
 *
 *   gcc -O2 -o eth21_rx eth21_rx.c
 *   ./eth21_rx [-p 21009] [-n N] [-q] [-t segundos]
 *     -q  solo comprueba seq (sin verificar el payload: para medir el maximo)
 *
 * MIT License.
 * ======================================================================== */
#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define BATCH 64
#define MAXP  2048

static volatile int stop_flag;
static void on_sig(int s) { (void)s; stop_flag = 1; }

static inline uint64_t xs64(uint64_t x)
{
  x ^= x << 13; x ^= x >> 7; x ^= x << 17;
  return x;
}

static int check_payload(const uint8_t *p, int len, uint32_t *seq_out)
{
  if (len < 18) return -1;
  uint32_t seq, nseq;
  memcpy(&seq, p, 4);
  memcpy(&nseq, p + 4, 4);
  *seq_out = seq;
  if (nseq != ~seq) return -2;
  uint64_t w = 0x9E3779B97F4A7C15ULL ^ (uint64_t)seq;
  for (int i = 8; i < len; i += 8) {
    uint8_t b[8];
    memcpy(b, &w, 8);                       /* little endian (x86/arm64) */
    int n = len - i < 8 ? len - i : 8;
    if (memcmp(p + i, b, n)) return -3;
    w = xs64(w);
  }
  return 0;
}

static double now(void)
{
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec * 1e-9;
}

int main(int argc, char **argv)
{
  int port = 21009, quick = 0, secs = 0;
  uint64_t limit = 0;
  int o;
  while ((o = getopt(argc, argv, "p:n:qt:")) != -1) {
    if (o == 'p') port = atoi(optarg);
    else if (o == 'n') limit = strtoull(optarg, 0, 0);
    else if (o == 'q') quick = 1;
    else if (o == 't') secs = atoi(optarg);
    else { fprintf(stderr, "uso: %s [-p puerto] [-n N] [-q] [-t s]\n", argv[0]); return 2; }
  }
  int s = socket(AF_INET, SOCK_DGRAM, 0);
  if (s < 0) { perror("socket"); return 1; }
  int rb = 256 << 20;
  setsockopt(s, SOL_SOCKET, SO_RCVBUF, &rb, sizeof rb);
  socklen_t sl = sizeof rb;
  getsockopt(s, SOL_SOCKET, SO_RCVBUF, &rb, &sl);
  struct sockaddr_in a = {0};
  a.sin_family = AF_INET;
  a.sin_port = htons(port);
  a.sin_addr.s_addr = htonl(INADDR_ANY);
  if (bind(s, (struct sockaddr *)&a, sizeof a)) { perror("bind"); return 1; }
  struct timeval tv = {0, 200000};
  setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
  signal(SIGINT, on_sig);
  printf("escuchando UDP :%d (SO_RCVBUF efectivo %d B%s). Ctrl-C para terminar.\n",
         port, rb, rb < (64 << 20) ? "; sube net.core.rmem_max" : "");

  static uint8_t buf[BATCH][MAXP];
  struct mmsghdr m[BATCH];
  struct iovec io[BATCH];
  for (int i = 0; i < BATCH; i++) {
    io[i].iov_base = buf[i]; io[i].iov_len = MAXP;
    memset(&m[i], 0, sizeof m[i]);
    m[i].msg_hdr.msg_iov = &io[i]; m[i].msg_hdr.msg_iovlen = 1;
  }

  uint64_t rx = 0, good = 0, bad = 0, lost = 0, dup = 0, restarts = 0, pay = 0, wire = 0;
  uint64_t lrx = 0, lpay = 0, lwire = 0;
  int have = 0;
  uint32_t exp = 0;
  double t0 = now(), tl = t0, tfirst = 0, tlast = 0;
  while (!stop_flag) {
    int n = recvmmsg(s, m, BATCH, MSG_WAITFORONE, NULL);
    if (n < 0) {
      if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) { perror("recvmmsg"); break; }
      n = 0;
    }
    for (int i = 0; i < n; i++) {
      int len = m[i].msg_len;
      uint32_t seq = 0;
      int r;
      if (quick) {
        if (len >= 4) memcpy(&seq, buf[i], 4);
        r = len >= 18 ? 0 : -1;
      } else {
        r = check_payload(buf[i], len, &seq);
      }
      if (!rx) tfirst = now();
      rx++;
      pay += len;
      wire += (uint64_t)len + 42 + 4 + 20;
      if (r) {
        bad++;
        if (r != -3) continue;     /* seq/~seq validos: la secuencia sigue contando */
      } else {
        good++;
      }
      if (!have) { have = 1; exp = seq + 1; continue; }
      if (seq == exp) exp++;
      else if ((int32_t)(seq - exp) > 0) { lost += (uint32_t)(seq - exp); exp = seq + 1; }
      else if ((int32_t)(seq - exp) < -65536) { restarts++; exp = seq + 1; }  /* rafaga nueva */
      else dup++;
    }
    double t = now();
    if (n > 0) tlast = t;
    if (t - tl >= 1.0) {
      double dt = t - tl;
      printf("%8.1f kpps  payload %6.3f Gb/s  cable %6.3f Gb/s | rx=%lu ok=%lu bad=%lu perdidas=%lu desord=%lu reinicios=%lu\n",
             (rx - lrx) / dt / 1e3, (pay - lpay) * 8 / dt / 1e9, (wire - lwire) * 8 / dt / 1e9,
             (unsigned long)rx, (unsigned long)good, (unsigned long)bad,
             (unsigned long)lost, (unsigned long)dup, (unsigned long)restarts);
      fflush(stdout);
      lrx = rx; lpay = pay; lwire = wire; tl = t;
    }
    if (limit && rx >= limit) break;
    if (secs && t - t0 >= secs) break;
  }
  double el = rx ? tlast - tfirst : 0;   /* hasta el ultimo paquete, no hasta Ctrl-C */
  printf("\n=== resumen ===\nrecibidas %lu  buenas %lu  malas %lu  perdidas %lu  desordenadas %lu  reinicios %lu\n",
         (unsigned long)rx, (unsigned long)good, (unsigned long)bad, (unsigned long)lost,
         (unsigned long)dup, (unsigned long)restarts);
  if (el > 0)
    printf("media: %.1f kpps, payload %.3f Gb/s, cable %.3f Gb/s (%.2f s)\n",
           rx / el / 1e3, pay * 8 / el / 1e9, wire * 8 / el / 1e9, el);
  printf("%s\n", (bad == 0 && lost == 0 && dup == 0 && good > 0) ? "PC RX PASS" :
                 (good > 0 ? "PC RX con perdidas/errores (ver arriba)" : "PC RX: nada recibido"));
  return 0;
}
