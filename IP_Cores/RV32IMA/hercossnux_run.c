/*
 * hercossnux_run.c - Paso 7b: firmware del PS para el SoC HERCOSSNUX
 *
 * Carga la imagen del kernel Linux nommu y su DTB en la region
 * reservada de DDR, arranca el core RV32IMA de la PL y drena su
 * consola por el banco de control AXI-Lite.
 *
 * Compilar:
 *   aarch64-linux-gnu-gcc -O2 -static -o hercossnux_run hercossnux_run.c
 *
 * Uso en la placa:
 *   ./hercossnux_run kernel.img hercossnux.dtb
 *
 * CUIDADO CRITICO CON LA REGION no-map:
 *   glibc aarch64 implementa memset/memcpy con DC ZVA y stp de
 *   128 bits, que fallan con SIGBUS sobre memoria no-map. TODA
 *   escritura a la DDR reservada se hace con bucles palabra a
 *   palabra sobre punteros volatile (ver wr32/rd32/blk_copy).
 *   No sustituir por memcpy/memset aunque parezca equivalente.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <signal.h>
#include <termios.h>

#define DDR_BASE   0x70000000UL
#define DDR_SIZE   (64UL * 1024 * 1024)
/* En Versal el banco de control de la PL NO puede ir en 0x80000000
 * (reservado a DDR): M_AXI_FPD solo admite 0xA4000000 [448M],
 * 0x400000000 [8G] y 0x40000000000 [1T]. Debe coincidir con
 * CTRL_BASE del Tcl del block design y con el device tree. */
#define CTRL_BASE  0xA4000000UL
#define CTRL_SIZE  0x10000UL

/* offsets del banco de control (ver rv32ima_soc_top.vhd) */
#define REG_CTRL        0x00
#define REG_STATUS      0x04
#define REG_RETIRED_LO  0x08
#define REG_RETIRED_HI  0x0C
#define REG_UART_RX     0x10
#define REG_UART_LEVEL  0x14
#define REG_UART_TX     0x18
#define REG_PC          0x1C

#define CTRL_CORE_EN    (1u << 0)
#define CTRL_CORE_RST   (1u << 1)

#define ST_HALTED       (1u << 0)
#define ST_POWEROFF     (1u << 1)
#define ST_REBOOT       (1u << 2)
#define ST_FIFO_HI      (1u << 3)

/* el core ve la RAM en 0x80000000; el stub de arranque vive al final */
#define CORE_RAM_BASE   0x80000000UL
#define STUB_OFF        0x03F00000UL
#define STATE_SZ        (48 * 4)

static volatile uint32_t *ddr;
static volatile uint32_t *ctrl;
static volatile int running = 1;

static void on_sigint(int s) { (void)s; running = 0; }

/* --- acceso palabra a palabra: obligatorio sobre no-map --- */
static inline void wr32(unsigned long off, uint32_t v)
{
	ddr[off / 4] = v;
}

static inline uint32_t rd32(unsigned long off)
{
	return ddr[off / 4];
}

/* copia de un buffer a la DDR reservada, palabra a palabra.
 * NO usar memcpy: DC ZVA / stp de 128 bits dan SIGBUS en no-map. */
static void blk_copy(unsigned long dst_off, const uint8_t *src, size_t n)
{
	size_t i;
	for (i = 0; i + 4 <= n; i += 4) {
		uint32_t w = (uint32_t)src[i] | ((uint32_t)src[i+1] << 8) |
		             ((uint32_t)src[i+2] << 16) | ((uint32_t)src[i+3] << 24);
		wr32(dst_off + i, w);
	}
	if (i < n) {                      /* cola no alineada */
		uint32_t w = 0;
		size_t k;
		for (k = 0; i + k < n; k++)
			w |= (uint32_t)src[i + k] << (8 * k);
		wr32(dst_off + i, w);
	}
}

/* limpia un rango de la DDR reservada, palabra a palabra */
static void blk_clear(unsigned long off, size_t n)
{
	size_t i;
	for (i = 0; i < n; i += 4)
		wr32(off + i, 0);
}

static uint8_t *slurp(const char *path, size_t *len_out)
{
	struct stat st;
	FILE *f = fopen(path, "rb");
	uint8_t *buf;

	if (!f) { perror(path); return NULL; }
	if (stat(path, &st) != 0) { perror("stat"); fclose(f); return NULL; }
	buf = malloc(st.st_size);
	if (!buf) { fclose(f); return NULL; }
	if (fread(buf, 1, st.st_size, f) != (size_t)st.st_size) {
		fprintf(stderr, "lectura corta de %s\n", path);
		free(buf); fclose(f); return NULL;
	}
	fclose(f);
	*len_out = st.st_size;
	return buf;
}

int main(int argc, char **argv)
{
	int fd;
	size_t img_len, dtb_len;
	uint8_t *img, *dtb;
	unsigned long dtb_off, dtb_pa;
	uint32_t st, lvl, rv;
	uint64_t retired;
	unsigned long idle = 0;

	if (argc < 3) {
		fprintf(stderr, "uso: %s <kernel.img> <dtb>\n", argv[0]);
		return 1;
	}

	fd = open("/dev/mem", O_RDWR | O_SYNC);
	if (fd < 0) { perror("/dev/mem"); return 1; }

	ddr = mmap(NULL, DDR_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
	           fd, DDR_BASE);
	if (ddr == MAP_FAILED) { perror("mmap ddr"); return 1; }

	ctrl = mmap(NULL, CTRL_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
	            fd, CTRL_BASE);
	if (ctrl == MAP_FAILED) { perror("mmap ctrl"); return 1; }

	/* el core parado mientras se carga la memoria */
	ctrl[REG_CTRL / 4] = 0;
	ctrl[REG_CTRL / 4] = CTRL_CORE_RST;

	img = slurp(argv[1], &img_len);
	if (!img) return 1;
	dtb = slurp(argv[2], &dtb_len);
	if (!dtb) return 1;

	printf("kernel: %zu bytes, dtb: %zu bytes\n", img_len, dtb_len);

	/* el DTB va al final de la RAM, dejando sitio al struct del emulador
	 * de referencia (mantiene la paridad de direcciones con el ISS) */
	dtb_off = DDR_SIZE - dtb_len - STATE_SZ;
	dtb_pa  = CORE_RAM_BASE + dtb_off;

	/* fixup del tamano de RAM en el DTB (placeholder 0x00c0ff03, big endian) */
	if (dtb_len > 0x140) {
		uint32_t ph = (uint32_t)dtb[0x13c] << 24 | (uint32_t)dtb[0x13d] << 16 |
		              (uint32_t)dtb[0x13e] << 8  | (uint32_t)dtb[0x13f];
		if (ph == 0x00c0ff03) {
			uint32_t v = (uint32_t)dtb_off;
			dtb[0x13c] = (v >> 24) & 0xFF;
			dtb[0x13d] = (v >> 16) & 0xFF;
			dtb[0x13e] = (v >> 8)  & 0xFF;
			dtb[0x13f] =  v        & 0xFF;
			printf("dtb: fixup de tamano de RAM -> 0x%lx\n", dtb_off);
		}
	}

	printf("limpiando 64 MB de DDR (palabra a palabra, no-map)...\n");
	blk_clear(0, DDR_SIZE);

	printf("cargando kernel en 0x%lx...\n", CORE_RAM_BASE);
	blk_copy(0, img, img_len);

	printf("cargando dtb en 0x%lx...\n", dtb_pa);
	blk_copy(dtb_off, dtb, dtb_len);

	/* stub de arranque: a0 = hartid = 0, a1 = pa del DTB, salta al kernel.
	 * Es el mismo que valida el arnes de simulacion. */
	{
		uint32_t stub[7];
		uint32_t dtb_hi = (uint32_t)((dtb_pa + 0x800) >> 12);
		uint32_t dtb_lo = (uint32_t)(dtb_pa & 0xFFF);
		stub[0] = 0x00000537;                       /* lui  a0,0x0     */
		stub[1] = 0x00050513;                       /* addi a0,a0,0    */
		stub[2] = (dtb_hi << 12) | 0x000005B7;      /* lui  a1,dtb_hi  */
		stub[3] = (dtb_lo << 20) | 0x00058593;      /* addi a1,a1,lo   */
		stub[4] = 0x800002B7;                       /* lui  t0,0x80000 */
		stub[5] = 0x00028293;                       /* addi t0,t0,0    */
		stub[6] = 0x00028067;                       /* jalr x0,0(t0)   */
		blk_copy(STUB_OFF, (const uint8_t *)stub, sizeof(stub));
		printf("stub en 0x%lx (a1=0x%lx)\n",
		       CORE_RAM_BASE + STUB_OFF, dtb_pa);
	}

	/* verificacion de ida y vuelta: la DDR responde de verdad */
	{
		uint32_t w0 = rd32(0);
		uint32_t expect = (uint32_t)img[0] | ((uint32_t)img[1] << 8) |
		                  ((uint32_t)img[2] << 16) | ((uint32_t)img[3] << 24);
		if (w0 != expect) {
			fprintf(stderr, "ERROR: la DDR no devuelve lo escrito "
			        "(0x%08x != 0x%08x)\n", w0, expect);
			return 1;
		}
	}

	signal(SIGINT, on_sigint);

	/* stdin en modo crudo y no bloqueante: cada tecla viaja al core al
	 * instante (sin esperar Enter) y el bucle nunca se bloquea leyendo.
	 * Se restaura la configuracion del terminal al salir. */
	struct termios tio_old, tio_raw;
	int tty = isatty(STDIN_FILENO);
	if (tty) {
		tcgetattr(STDIN_FILENO, &tio_old);
		tio_raw = tio_old;
		tio_raw.c_lflag &= ~(ICANON | ECHO);
		tio_raw.c_cc[VMIN] = 0;
		tio_raw.c_cc[VTIME] = 0;
		tcsetattr(STDIN_FILENO, TCSANOW, &tio_raw);
	}
	fcntl(STDIN_FILENO, F_SETFL,
	      fcntl(STDIN_FILENO, F_GETFL, 0) | O_NONBLOCK);

	printf("arrancando el core...\n\n");
	ctrl[REG_CTRL / 4] = CTRL_CORE_EN;

	/* bucle de consola: drena el FIFO y vigila el estado */
	while (running) {
		int drained = 0;

		lvl = ctrl[REG_UART_LEVEL / 4];
		while (lvl > 0) {
			rv = ctrl[REG_UART_RX / 4];
			if (!(rv & 0x100))
				break;
			putchar((int)(rv & 0xFF));
			drained++;
			lvl--;
			if (drained > 4096) break;   /* ceder para vigilar estado */
		}
		if (drained)
			fflush(stdout);

		/* teclado -> core: cada byte va al registro TX, que alimenta
		 * el FIFO de RX de la UART del kernel invitado */
		{
			unsigned char kb[64];
			ssize_t n = read(STDIN_FILENO, kb, sizeof kb);
			for (ssize_t i = 0; i < n; i++) {
				ctrl[REG_UART_TX / 4] = kb[i];
				drained++;   /* hubo actividad: no dormir */
			}
		}

		st = ctrl[REG_STATUS / 4];
		if (st & (ST_POWEROFF | ST_REBOOT)) {
			printf("\n[core: %s]\n",
			       (st & ST_POWEROFF) ? "poweroff" : "reboot");
			break;
		}
		if (st & ST_HALTED) {
			printf("\n[core: halt en pc=0x%08x]\n", ctrl[REG_PC / 4]);
			break;
		}

		if (!drained) {
			idle++;
			usleep(1000);
			if (idle % 5000 == 0) {   /* cada ~5 s sin consola */
				retired = ctrl[REG_RETIRED_LO / 4];
				retired |= (uint64_t)ctrl[REG_RETIRED_HI / 4] << 32;
				fprintf(stderr, "[retiros=%llu pc=0x%08x]\n",
				        (unsigned long long)retired, ctrl[REG_PC / 4]);
			}
		} else {
			idle = 0;
		}
	}

	retired  = ctrl[REG_RETIRED_LO / 4];
	retired |= (uint64_t)ctrl[REG_RETIRED_HI / 4] << 32;
	printf("\ntotal de instrucciones retiradas: %llu\n",
	       (unsigned long long)retired);

	ctrl[REG_CTRL / 4] = 0;   /* pausar el core al salir */
	if (tty)
		tcsetattr(STDIN_FILENO, TCSANOW, &tio_old);
	return 0;
}
