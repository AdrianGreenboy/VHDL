-------------------------------------------------------------------------------
-- fft_dp.vhd  --  Datapath FFT compleja radix-2 DIT (DSP IP).
--
-- VERSION PING-PONG SDP (Layer 5): arquitectura de doble banco con memorias
-- simple-dual-port (1 escritura + 1 lectura por banco), que infieren Block RAM
-- de forma garantizada y en VHDL-2008 ESTRICTO (arrays como senales, un solo
-- puerto de escritura por proceso, sin shared variables ni -frelaxed).
--
-- Por que ping-pong: una FFT in-place escribe DOS posiciones arbitrarias por
-- ciclo sobre el mismo banco, patron que NO es inferible como BRAM (Vivado
-- 8-4767 / 8-2914). El ping-pong separa lectura y escritura en bancos distintos:
--   * banco FUENTE: solo se LEE en la etapa actual.
--   * banco DESTINO: solo se ESCRIBE en la etapa actual.
--   * al terminar la etapa, fuente<->destino intercambian rol.
-- Asi cada banco es SDP puro (1 rd + 1 wr, nunca ambos al mismo sitio/ciclo).
--
-- Butterfly SERIALIZADO (1 acceso por puerto por ciclo) para que cada banco
-- necesite solo 1 puerto de lectura:
--   RD_K -> capturar x[k] ; RD_L -> capturar x[l] ; (ROM en paralelo)
--   CALC -> t = W*x[l], u+/-t con shift
--   WR_K -> escribir res_k en destino ; WR_L -> escribir res_l en destino
-- Mas ciclos que la version paralela, pero la FFT no esta en lazo critico y
-- la INFERIBILIDAD manda.
--
-- Bit-reverse: fase previa que COPIA de banco A a banco B permutando indices
-- (lectura de src, escritura en dst con indice bit-reversed). Tras el
-- bit-reverse, la primera etapa toma como fuente el banco resultante.
--
-- Comportamiento BIT-IDENTICO a dsp_oracle.py::fft_fixed (mismas cuentas,
-- mismo orden). Interfaz IDENTICA a versiones anteriores (no cambia un puerto).
--
-- Contrato numerico:
--   qmul(a,b) = (a*b + 0x4000) >> 15  (Q1.15, round-half-up)
--   tr = qmul(re[l],wr) - qmul(im[l],wi) ; ti = qmul(re[l],wi) + qmul(im[l],wr)
--   re[k],im[k] = rshift_round(u +/- t, 1)  (shift 1 por etapa, escala 1/N)
--   IFFT: wi -> -wi
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fft_dp is
  generic (
    NMAX   : integer := 1024;
    LOG2MAX: integer := 10
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    log2n   : in  std_logic_vector(3 downto 0);
    inv     : in  std_logic;
    wr_en   : in  std_logic;
    wr_idx  : in  std_logic_vector(9 downto 0);
    wr_re   : in  std_logic_vector(15 downto 0);
    wr_im   : in  std_logic_vector(15 downto 0);
    start   : in  std_logic;
    done    : out std_logic;
    busy    : out std_logic;
    rd_idx  : in  std_logic_vector(9 downto 0);
    rd_re   : out std_logic_vector(15 downto 0);
    rd_im   : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of fft_dp is

  constant HALFMAX : integer := NMAX/2;

  -- ------------------------------------------------------------------
  -- Dos bancos por parte (ping-pong). Cada banco = 1 array-senal con
  -- 1 puerto de escritura (proceso unico) y 1 puerto de lectura
  -- registrada. ram_style=block. Infieren RAMB simple-dual-port.
  -- ------------------------------------------------------------------
  type buf_t is array (0 to NMAX-1) of signed(15 downto 0);
  signal re_b0, re_b1 : buf_t := (others => (others => '0'));
  signal im_b0, im_b1 : buf_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of re_b0 : signal is "block";
  attribute ram_style of re_b1 : signal is "block";
  attribute ram_style of im_b0 : signal is "block";
  attribute ram_style of im_b1 : signal is "block";

  -- puerto de lectura (una direccion, registrada) por banco
  signal rd_addr0, rd_addr1 : integer range 0 to NMAX-1 := 0;
  signal rq_re0, rq_im0     : signed(15 downto 0) := (others=>'0');
  signal rq_re1, rq_im1     : signed(15 downto 0) := (others=>'0');
  -- puerto de escritura por banco
  signal wr_addr0, wr_addr1 : integer range 0 to NMAX-1 := 0;
  signal we0, we1           : std_logic := '0';
  signal wd_re0, wd_im0     : signed(15 downto 0) := (others=>'0');
  signal wd_re1, wd_im1     : signed(15 downto 0) := (others=>'0');

  -- ------------------------------------------------------------------
  -- ROM de twiddles (BRAM sincrona), direccion y salida registradas.
  -- ------------------------------------------------------------------
  type rom_t is array (0 to HALFMAX-1) of signed(15 downto 0);
  function gen_wre return rom_t is
    variable r : rom_t; variable a : real; variable v : integer;
  begin
    for k in 0 to HALFMAX-1 loop
      a := -2.0*3.14159265358979323846*real(k)/real(NMAX);
      v := integer(round(cos(a)*32768.0));
      if v>32767 then v:=32767; end if; if v<-32768 then v:=-32768; end if;
      r(k):=to_signed(v,16);
    end loop; return r;
  end function;
  function gen_wim return rom_t is
    variable r : rom_t; variable a : real; variable v : integer;
  begin
    for k in 0 to HALFMAX-1 loop
      a := -2.0*3.14159265358979323846*real(k)/real(NMAX);
      v := integer(round(sin(a)*32768.0));
      if v>32767 then v:=32767; end if; if v<-32768 then v:=-32768; end if;
      r(k):=to_signed(v,16);
    end loop; return r;
  end function;
  constant WRE : rom_t := gen_wre;
  constant WIM : rom_t := gen_wim;
  attribute rom_style : string;
  attribute rom_style of WRE : constant is "block";
  attribute rom_style of WIM : constant is "block";
  signal rom_addr : integer range 0 to HALFMAX-1 := 0;
  signal rom_wr, rom_wi : signed(15 downto 0) := (others=>'0');

  -- ------------------------------------------------------------------
  -- funciones aritmeticas (idem versiones anteriores)
  -- ------------------------------------------------------------------
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
  function bitrev(val, bits : integer) return integer is
    variable r : integer := 0; variable x : integer := val;
  begin
    for i in 0 to LOG2MAX-1 loop
      if i < bits then r := r*2 + (x mod 2); x := x/2; end if;
    end loop;
    return r;
  end function;

  -- ------------------------------------------------------------------
  -- FSM
  -- ------------------------------------------------------------------
  type state_t is (S_IDLE,
                   S_BREV_RD, S_BREV_LAT, S_BREV_WR,
                   S_STAGE,
                   S_RD_K, S_RD_L, S_LAT, S_CALC, S_MUL, S_WR_L,
                   S_SWAP, S_DONE);
  signal state : state_t := S_IDLE;

  signal n_r     : integer range 1 to NMAX := NMAX;
  signal log2n_r : integer range 1 to LOG2MAX := LOG2MAX;
  signal inv_r   : std_logic := '0';
  signal m_r     : integer range 2 to NMAX := 2;
  signal log2_stride_r : integer range 0 to LOG2MAX := 0;  -- log2(NMAX/m_r)
  signal half_r  : integer range 1 to HALFMAX := 1;
  signal j_r     : integer range 0 to HALFMAX := 0;
  signal k_r     : integer range 0 to NMAX := 0;
  signal li_r    : integer range 0 to NMAX := 0;
  signal src_sel : std_logic := '0';   -- '0': fuente=b0,dst=b1 ; '1': inverso
  signal brev_i  : integer range 0 to NMAX := 0;
  signal brev_rr : integer range 0 to NMAX := 0;

  -- capturas del butterfly
  signal ur_r, ui_r, lr_r, li_val : signed(15 downto 0) := (others=>'0');
  signal tr_r, ti_r : signed(15 downto 0) := (others=>'0');

begin

  -- ==================================================================
  -- Bancos SDP: un proceso de escritura por banco (single write port),
  -- lectura registrada. Arrays como senales -> VHDL-2008 estricto.
  -- ==================================================================
  -- banco 0
  process(clk)
  begin
    if rising_edge(clk) then
      if we0 = '1' then
        re_b0(wr_addr0) <= wd_re0;
        im_b0(wr_addr0) <= wd_im0;
      end if;
      rq_re0 <= re_b0(rd_addr0);
      rq_im0 <= im_b0(rd_addr0);
    end if;
  end process;
  -- banco 1
  process(clk)
  begin
    if rising_edge(clk) then
      if we1 = '1' then
        re_b1(wr_addr1) <= wd_re1;
        im_b1(wr_addr1) <= wd_im1;
      end if;
      rq_re1 <= re_b1(rd_addr1);
      rq_im1 <= im_b1(rd_addr1);
    end if;
  end process;

  -- ROM sincrona
  process(clk)
  begin
    if rising_edge(clk) then
      rom_wr <= WRE(rom_addr);
      rom_wi <= WIM(rom_addr);
    end if;
  end process;

  -- ==================================================================
  -- FSM de control
  -- ==================================================================
  process(clk)
    variable wr_v : signed(15 downto 0);
    variable wi_v : signed(16 downto 0);
    variable tr, ti : signed(15 downto 0);
    variable rr : integer;
  begin
    if rising_edge(clk) then
      done <= '0';
      we0  <= '0';
      we1  <= '0';

      if rst = '1' then
        state <= S_IDLE;
        busy  <= '0';
        j_r <= 0; k_r <= 0; brev_i <= 0; src_sel <= '0';
      else

        case state is

          when S_IDLE =>
            busy <= '0';
            -- carga de entrada al banco 0 (fuente inicial del bit-reverse).
            if wr_en = '1' then
              wr_addr0 <= to_integer(unsigned(wr_idx));
              wd_re0   <= signed(wr_re);
              wd_im0   <= signed(wr_im);
              we0      <= '1';
            end if;
            -- lectura de resultados: tras la FFT el resultado quedo en el banco
            -- DESTINO de la ultima etapa. El swap final no togglea src_sel, asi
            -- que el destino final es 'not src_sel'. Leemos de ese.
            if src_sel = '1' then
              rd_addr0 <= to_integer(unsigned(rd_idx));
            else
              rd_addr1 <= to_integer(unsigned(rd_idx));
            end if;
            if start = '1' then
              busy    <= '1';
              log2n_r <= to_integer(unsigned(log2n));
              n_r     <= 2 ** to_integer(unsigned(log2n));
              inv_r   <= inv;
              brev_i  <= 0;
              src_sel <= '0';         -- fuente = b0 (donde se cargo la entrada)
              state   <= S_BREV_RD;
            end if;

          -- ---------- BIT-REVERSE: copia b0 -> b1 permutando ----------
          -- lee indice brev_i de b0, escribe en b1 en indice bitrev(brev_i).
          when S_BREV_RD =>
            rd_addr0 <= brev_i;
            state <= S_BREV_LAT;

          when S_BREV_LAT =>
            state <= S_BREV_WR;

          when S_BREV_WR =>
            rr := bitrev(brev_i, log2n_r);
            wr_addr1 <= rr;
            wd_re1   <= rq_re0;
            wd_im1   <= rq_im0;
            we1      <= '1';
            if brev_i = n_r - 1 then
              -- tras bit-reverse el dato valido esta en b1 -> fuente = b1
              src_sel <= '1';
              m_r <= 2; half_r <= 1; j_r <= 0; k_r <= 0;
              log2_stride_r <= LOG2MAX - 1;   -- stride=NMAX/2 => log2 = LOG2MAX-1
              state <= S_STAGE;
            else
              brev_i <= brev_i + 1;
              state  <= S_BREV_RD;
            end if;

          -- ---------- ETAPAS ----------
          when S_STAGE =>
            j_r <= 0;
            k_r <= 0;
            state <= S_RD_K;

          when S_RD_K =>
            -- poner direccion de k ; preparar ROM. Dato de k llega en 2 ciclos.
            li_r    <= k_r + half_r;
            rom_addr<= to_integer(shift_left(to_unsigned(j_r, LOG2MAX+1), log2_stride_r));
            if src_sel = '0' then rd_addr0 <= k_r; else rd_addr1 <= k_r; end if;
            state <= S_RD_L;

          when S_RD_L =>
            -- poner direccion de l (dato de k AUN no disponible en rq).
            if src_sel = '0' then rd_addr0 <= li_r; else rd_addr1 <= li_r; end if;
            state <= S_LAT;

          when S_LAT =>
            -- ahora rq = x[k] (latencia 2 desde RD_K). Capturar ur.
            if src_sel = '0' then
              ur_r <= rq_re0; ui_r <= rq_im0;
            else
              ur_r <= rq_re1; ui_r <= rq_im1;
            end if;
            state <= S_CALC;

          when S_CALC =>
            -- ahora rq = x[l] (latencia 2 desde RD_L). Capturar lr.
            if src_sel = '0' then
              lr_r <= rq_re0; li_val <= rq_im0;
            else
              lr_r <= rq_re1; li_val <= rq_im1;
            end if;
            state <= S_MUL;

          when S_MUL =>
            wr_v := rom_wr;
            wi_v := resize(rom_wi, 17);
            if inv_r = '1' then wi_v := -wi_v; end if;
            tr := resize(qmul(lr_r, wr_v) - qmul17(li_val, wi_v), 16);
            ti := resize(qmul17(lr_r, wi_v) + qmul(li_val, wr_v), 16);
            -- escribir res_k en el banco DESTINO (el contrario a fuente)
            if src_sel = '0' then
              wr_addr1 <= k_r;
              wd_re1 <= rsr1(resize(ur_r,17) + resize(tr,17));
              wd_im1 <= rsr1(resize(ui_r,17) + resize(ti,17));
              we1 <= '1';
            else
              wr_addr0 <= k_r;
              wd_re0 <= rsr1(resize(ur_r,17) + resize(tr,17));
              wd_im0 <= rsr1(resize(ui_r,17) + resize(ti,17));
              we0 <= '1';
            end if;
            tr_r <= tr;
            ti_r <= ti;
            state <= S_WR_L;

          when S_WR_L =>
            -- escribir res_l = u - t en destino, indice l
            if src_sel = '0' then
              wr_addr1 <= li_r;
              wd_re1 <= rsr1(resize(ur_r,17) - resize(tr_r,17));
              wd_im1 <= rsr1(resize(ui_r,17) - resize(ti_r,17));
              we1 <= '1';
            else
              wr_addr0 <= li_r;
              wd_re0 <= rsr1(resize(ur_r,17) - resize(tr_r,17));
              wd_im0 <= rsr1(resize(ui_r,17) - resize(ti_r,17));
              we0 <= '1';
            end if;
            -- avanzar recorrido (k += m ; si excede, j++ ; si j==half, siguiente etapa)
            if k_r + m_r <= n_r - 1 then
              k_r <= k_r + m_r;
              state <= S_RD_K;
            else
              if j_r + 1 < half_r then
                j_r <= j_r + 1;
                k_r <= j_r + 1;
                state <= S_RD_K;
              else
                state <= S_SWAP;
              end if;
            end if;

          when S_SWAP =>
            -- fin de etapa: intercambiar bancos, avanzar m
            if m_r = n_r then
              state <= S_DONE;
            else
              src_sel <= not src_sel;
              m_r    <= m_r * 2;
              half_r <= m_r;
              log2_stride_r <= log2_stride_r - 1;   -- stride se divide por 2
              j_r    <= 0;
              k_r    <= 0;
              state  <= S_STAGE;
            end if;

          when S_DONE =>
            busy <= '0';
            done <= '1';
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  -- lectura de resultados: del banco DESTINO final (not src_sel), 1 ciclo lat.
  rd_re <= std_logic_vector(rq_re1) when src_sel='0' else std_logic_vector(rq_re0);
  rd_im <= std_logic_vector(rq_im1) when src_sel='0' else std_logic_vector(rq_im0);

end architecture;
