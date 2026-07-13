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

  type state_t is (S_IDLE, S_RUN1, S_RUN2, S_RUN3, S_RUN4, S_DONE);
  signal state : state_t := S_IDLE;

  signal n_r     : integer range 1 to NMAX := NMAX;
  signal n2_r    : integer range 2 to 1024 := 2;
  signal stride_r: integer range 1 to 1024 := 1;
  signal k_r     : integer range 0 to NMAX := 0;

  -- registros de pipeline del unsplit (rompen la cadena combinacional larga)
  signal ar_p, ai_p, br_p, bi_p : signed(15 downto 0) := (others=>'0');
  signal wr_p, wi_p             : signed(15 downto 0) := (others=>'0');
  signal wbr_p, wbi_p           : signed(15 downto 0) := (others=>'0');
  signal rom_addr_p             : integer range 0 to NMAX := 0;
  signal klt_p                  : std_logic := '0';   -- k_r < n_r registrado
  -- ayudas para evitar multiplicador/modulo variables (n_r, stride son 2^x):
  --  kk = k_r and (n_r-1) ; rom_addr = k_r << log2_stride
  signal log2_stride_r : integer range 0 to 10 := 0;
  signal nmask_r       : integer range 0 to NMAX := 0;   -- n_r - 1

  function qmul(a, b : signed(15 downto 0)) return signed is
    variable p : signed(31 downto 0);
  begin
    p := a*b; p := p + to_signed(16384,32);
    return resize(shift_right(p,15),16);
  end function;
  function qmul17(a : signed(15 downto 0); b : signed(16 downto 0)) return signed is
    variable p : signed(32 downto 0);
  begin
    p := a*b; p := p + to_signed(16384,33);
    return resize(shift_right(p,15),16);
  end function;
  function rsr1(v : signed) return signed is
    variable t : signed(v'length downto 0);
  begin
    t := resize(v,v'length+1)+1;
    return resize(shift_right(t,1),16);
  end function;
  function sat16(v : signed) return signed is
  begin
    if v>to_signed(32767,v'length) then return to_signed(32767,16);
    elsif v<to_signed(-32768,v'length) then return to_signed(-32768,16);
    else return resize(v,16); end if;
  end function;

begin

  process(clk)
    variable kk, km : integer range 0 to NMAX;
    variable cr : signed(15 downto 0);
    variable ci : signed(16 downto 0);
  begin
    if rising_edge(clk) then
      done <= '0';
      if rst='1' then
        state <= S_IDLE; busy <= '0'; k_r <= 0;
      else
        if wr_en='1' then
          zr_b(to_integer(unsigned(wr_idx))) <= signed(wr_zr);
          zi_b(to_integer(unsigned(wr_idx))) <= signed(wr_zi);
        end if;

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
              state   <= S_RUN1;
            end if;

          -- Etapa 1: mezcla A/B y direccion de ROM (registradas).
          -- kk = k_r and (n_r-1) ; rom_addr = k_r << log2_stride  (n_r,stride 2^x)
          when S_RUN1 =>
            kk := to_integer(to_unsigned(k_r,11) and to_unsigned(nmask_r,11));
            if k_r = 0 then km := 0; else km := n_r - k_r; end if;
            cr := zr_b(km);
            ci := -resize(zi_b(km), 17);
            ar_p <= rsr1(resize(zr_b(kk),17) + resize(cr,17));
            ai_p <= rsr1(resize(zi_b(kk),17) + ci);
            br_p <= rsr1(resize(zr_b(kk),17) - resize(cr,17));
            bi_p <= rsr1(resize(zi_b(kk),17) - ci);
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
            wbr_p <= resize(qmul(br_p,wr_p) - qmul(bi_p,wi_p),16);
            wbi_p <= resize(qmul(br_p,wi_p) + qmul(bi_p,wr_p),16);
            state <= S_RUN4;

          -- Etapa 4: sumas finales y escritura al buffer de salida.
          when S_RUN4 =>
            xr_b(k_r) <= sat16(resize(ar_p,17) + resize(wbi_p,17));
            xi_b(k_r) <= sat16(resize(ai_p,17) - resize(wbr_p,17));
            if k_r = n_r then
              state <= S_DONE;
            else
              k_r <= k_r + 1;
              state <= S_RUN1;
            end if;

          when S_DONE =>
            busy <= '0'; done <= '1'; state <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

  rd_xr <= std_logic_vector(xr_b(to_integer(unsigned(rd_idx))));
  rd_xi <= std_logic_vector(xi_b(to_integer(unsigned(rd_idx))));

end architecture;
