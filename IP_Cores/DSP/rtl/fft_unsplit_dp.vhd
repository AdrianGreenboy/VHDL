-------------------------------------------------------------------------------
-- fft_unsplit_dp.vhd  --  Etapa split/unsplit para FFT real-empacada (entrega 2)
--
-- Toma Z[k] (salida de la FFT compleja de N sobre z[n]=x[2n]+j x[2n+1]) y
-- reconstruye el espectro de la senal real de 2N puntos, X[0..N].
--
-- Modelo (bit-exacto contra dsp_oracle.py::fft_real_packed):
--   kk = k mod N ;  km = (N-k) mod N
--   cr =  Zr[km] ; ci = -Zi[km]                   (conj(Z[N-k]))
--   ar = rsr1(Zr[kk]+cr) ; ai = rsr1(Zi[kk]+ci)   (A = 0.5(Z[k]+conj))
--   br = rsr1(Zr[kk]-cr) ; bi = rsr1(Zi[kk]-ci)   (B = 0.5(Z[k]-conj))
--   W = W_2N^k  (k<N) ; para k=N: wr=0x7FFF, wi=0
--   wbr = qmul(br,wr)-qmul(bi,wi) ; wbi = qmul(br,wi)+qmul(bi,wr)
--   X[k] = ( sat(ar+wbi) , sat(ai-wbr) )
--
-- Twiddle W_2N: ROM fija de 512 (W_1024), subindexada con stride 1024/(2N).
-- Conjugacion de ci en 17 bits (leccion -32768 de la entrega 1).
--
-- AUDIT 2026-11 (numeric): A and B are kept at 17 bits (ai/bi reach +32768
-- when Zi = -32768 is conjugated), W*B at 18 bits (|W*B| <= 46341), the final
-- sum at 19 bits, then sat16. No intermediate wrap. Identical to the oracle.
-- AUDIT 2026-11 (ASIC): the Z buffer has ONE registered read port (Z[k] and
-- Z[N-k] are fetched in two consecutive cycles) and the X buffer has ONE
-- registered read port (rd_xr/rd_xi valid 1 cycle after rd_idx). Both buffers
-- are plain 1R1W synchronous memories -> SRAM-macro / BRAM mappable.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fft_unsplit_dp is
  generic (
    NMAX    : integer := 512;    -- N maximo del Z intermedio (2N=1024)
    LOG2MAX : integer := 9
  );
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    log2n2 : in  std_logic_vector(3 downto 0);   -- log2(2N): 8..10
    -- carga de Z (0..N-1)
    wr_en  : in  std_logic;
    wr_idx : in  std_logic_vector(9 downto 0);
    wr_zr  : in  std_logic_vector(15 downto 0);
    wr_zi  : in  std_logic_vector(15 downto 0);
    start  : in  std_logic;
    done   : out std_logic;
    busy   : out std_logic;
    -- lectura de X (0..N)
    rd_idx : in  std_logic_vector(9 downto 0);
    rd_xr  : out std_logic_vector(15 downto 0);
    rd_xi  : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of fft_unsplit_dp is

  constant ROMN : integer := 512;   -- W_1024 tiene 512 entradas

  type zbuf_t is array (0 to NMAX-1) of signed(15 downto 0);
  signal zr_b, zi_b : zbuf_t := (others => (others => '0'));
  type xbuf_t is array (0 to NMAX) of signed(15 downto 0);   -- 0..N
  signal xr_b, xi_b : xbuf_t := (others => (others => '0'));

  type rom_t is array (0 to ROMN-1) of signed(15 downto 0);
  function gen_wre return rom_t is
    variable r : rom_t; variable a : real; variable v : integer;
  begin
    for k in 0 to ROMN-1 loop
      a := -2.0*3.14159265358979323846*real(k)/1024.0;
      v := integer(round(cos(a)*32768.0));
      if v>32767 then v:=32767; end if; if v<-32768 then v:=-32768; end if;
      r(k):=to_signed(v,16);
    end loop; return r;
  end function;
  function gen_wim return rom_t is
    variable r : rom_t; variable a : real; variable v : integer;
  begin
    for k in 0 to ROMN-1 loop
      a := -2.0*3.14159265358979323846*real(k)/1024.0;
      v := integer(round(sin(a)*32768.0));
      if v>32767 then v:=32767; end if; if v<-32768 then v:=-32768; end if;
      r(k):=to_signed(v,16);
    end loop; return r;
  end function;
  constant WRE : rom_t := gen_wre;
  constant WIM : rom_t := gen_wim;

  type state_t is (S_IDLE, S_RA, S_RB, S_RC, S_RUN1, S_RUN2, S_RUN3, S_RUN4, S_DONE);
  signal state : state_t := S_IDLE;

  signal n_r     : integer range 1 to NMAX := NMAX;
  signal n2_r    : integer range 2 to 1024 := 2;
  signal stride_r: integer range 1 to 1024 := 1;
  signal k_r     : integer range 0 to NMAX := 0;

  -- registros de pipeline del unsplit (rompen la cadena combinacional larga)
  signal ar_p, ai_p, br_p, bi_p : signed(16 downto 0) := (others=>'0');
  signal wr_p, wi_p             : signed(15 downto 0) := (others=>'0');
  signal wbr_p, wbi_p           : signed(17 downto 0) := (others=>'0');
  -- single registered read port of the Z buffer + capture of Z[kk]
  signal z_raddr                : integer range 0 to NMAX-1 := 0;
  signal zq_r, zq_i             : signed(15 downto 0) := (others=>'0');
  signal zk_r, zk_i             : signed(15 downto 0) := (others=>'0');
  signal km_r                   : integer range 0 to NMAX-1 := 0;
  -- single registered read port of the X buffer
  signal xq_r, xq_i             : signed(15 downto 0) := (others=>'0');
  signal rom_addr_p             : integer range 0 to NMAX := 0;
  signal klt_p                  : std_logic := '0';   -- k_r < n_r registrado
  -- ayudas para evitar multiplicador/modulo variables (n_r, stride son 2^x):
  --  kk = k_r and (n_r-1) ; rom_addr = k_r << log2_stride
  signal log2_stride_r : integer range 0 to 10 := 0;
  signal nmask_r       : integer range 0 to NMAX := 0;   -- n_r - 1

  -- 17b x 16b Q1.15 product, round-half-up, full-width 18-bit result.
  function qmulw(a : signed(16 downto 0); b : signed(15 downto 0)) return signed is
    variable p : signed(32 downto 0);
  begin
    p := a*b; p := p + to_signed(16384,33);
    return resize(shift_right(p,15),18);
  end function;
  -- (v + 1) >> 1 of a 17-bit sum, result 17 bits (range [-32768, 32768]).
  function rs1_17(v : signed(16 downto 0)) return signed is
    variable t : signed(17 downto 0);
  begin
    t := resize(v,18)+1;
    return resize(shift_right(t,1),17);
  end function;
  function sat16(v : signed) return signed is
  begin
    if v>to_signed(32767,v'length) then return to_signed(32767,16);
    elsif v<to_signed(-32768,v'length) then return to_signed(-32768,16);
    else return resize(v,16); end if;
  end function;

begin

  -- Z buffer: 1 write port (load) + 1 registered read port (FSM)
  process(clk)
  begin
    if rising_edge(clk) then
      if wr_en='1' then
        zr_b(to_integer(unsigned(wr_idx))) <= signed(wr_zr);
        zi_b(to_integer(unsigned(wr_idx))) <= signed(wr_zi);
      end if;
      zq_r <= zr_b(z_raddr);
      zq_i <= zi_b(z_raddr);
    end if;
  end process;

  -- X buffer read port (registered): rd_x* valid 1 cycle after rd_idx
  process(clk)
  begin
    if rising_edge(clk) then
      xq_r <= xr_b(to_integer(unsigned(rd_idx)));
      xq_i <= xi_b(to_integer(unsigned(rd_idx)));
    end if;
  end process;

  process(clk)
    variable kk : integer range 0 to NMAX;
    variable cr : signed(16 downto 0);
    variable ci : signed(16 downto 0);
  begin
    if rising_edge(clk) then
      done <= '0';
      if rst='1' then
        state <= S_IDLE; busy <= '0'; k_r <= 0;
      else

        case state is
          when S_IDLE =>
            busy <= '0';
            if start='1' then
              busy    <= '1';
              n2_r    <= 2 ** to_integer(unsigned(log2n2));
              n_r     <= 2 ** (to_integer(unsigned(log2n2))-1);
              stride_r<= 1024 / (2 ** to_integer(unsigned(log2n2)));
              -- log2(stride) = 10 - log2n2 ; nmask = n_r - 1
              log2_stride_r <= 10 - to_integer(unsigned(log2n2));
              nmask_r <= (2 ** (to_integer(unsigned(log2n2))-1)) - 1;
              k_r     <= 0;
              state   <= S_RA;
            end if;

          -- Read phase (one Z read port): address Z[kk], then Z[km].
          -- kk = k_r and (n_r-1) ; km = (N-k) mod N   (n_r is a power of 2)
          when S_RA =>
            kk := to_integer(to_unsigned(k_r,11) and to_unsigned(nmask_r,11));
            z_raddr <= kk;
            if k_r = 0 or k_r = n_r then km_r <= 0; else km_r <= n_r - k_r; end if;
            state <= S_RB;

          when S_RB =>
            z_raddr <= km_r;          -- zq <= Z[kk] at the end of this cycle
            state <= S_RC;

          when S_RC =>
            zk_r <= zq_r; zk_i <= zq_i;   -- capture Z[kk]; zq <= Z[km] next
            state <= S_RUN1;

          -- Etapa 1: mezcla A/B y direccion de ROM (registradas).
          -- rom_addr = k_r << log2_stride
          when S_RUN1 =>
            cr := resize(zq_r, 17);
            ci := -resize(zq_i, 17);
            ar_p <= rs1_17(resize(zk_r,17) + cr);
            ai_p <= rs1_17(resize(zk_i,17) + ci);
            br_p <= rs1_17(resize(zk_r,17) - cr);
            bi_p <= rs1_17(resize(zk_i,17) - ci);
            if k_r < n_r then
              rom_addr_p <= to_integer(shift_left(to_unsigned(k_r,11), log2_stride_r));
              klt_p <= '1';
            else
              rom_addr_p <= 0;
              klt_p <= '0';
            end if;
            state <= S_RUN2;

          -- Etapa 2: leer twiddle de ROM (registrado).
          when S_RUN2 =>
            if klt_p = '1' then
              wr_p <= WRE(rom_addr_p);
              wi_p <= WIM(rom_addr_p);
            else
              wr_p <= to_signed(32767,16);   -- k=N: W=1
              wi_p <= to_signed(0,16);
            end if;
            state <= S_RUN3;

          -- Etapa 3: multiplicaciones complejas W*B (registradas).
          when S_RUN3 =>
            wbr_p <= qmulw(br_p,wr_p) - qmulw(bi_p,wi_p);
            wbi_p <= qmulw(br_p,wi_p) + qmulw(bi_p,wr_p);
            state <= S_RUN4;

          -- Etapa 4: sumas finales y escritura al buffer de salida.
          when S_RUN4 =>
            xr_b(k_r) <= sat16(resize(ar_p,19) + resize(wbi_p,19));
            xi_b(k_r) <= sat16(resize(ai_p,19) - resize(wbr_p,19));
            if k_r = n_r then
              state <= S_DONE;
            else
              k_r <= k_r + 1;
              state <= S_RA;
            end if;

          when S_DONE =>
            busy <= '0'; done <= '1'; state <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

  rd_xr <= std_logic_vector(xq_r);
  rd_xi <= std_logic_vector(xq_i);

end architecture;
