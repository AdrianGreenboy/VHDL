-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Generador de tramas AXIS 64b (fuente de trafico del silicon pass).
--
-- Trama (bytes, little-endian dentro de cada palabra):
--   w0 : dst[0..5] src[0..1]
--   w1 : src[2..5] 0x88 0xB5 len[7:0] len[15:8]
--   w2 : seq[31:0] ~seq[31:0]
--   w3+: P0, P1, ... con P0 = seed_of(seq), Pk+1 = xorshift64(Pk)
-- 'len' es la longitud L2 sin FCS. Barrido: len_min, +len_step, ... y vuelve
-- a len_min al pasar de len_max. len efectivo >= 20 (cabecera completa).
-- La ultima palabra lleva tkeep con los n bytes validos; el resto del dato es
-- patron (el MAC enmascara).
--
-- start (pulso) reinicia seq=0 y la longitud; count tramas; 'cont'=1 ignora
-- count. busy alto mientras genera; done sticky hasta start.
-- stop (pulso) termina la rafaga en la FRONTERA de trama: la trama en curso se
-- completa (tvalid no cae nunca a mitad de trama, lo que el MAC trataria como
-- underrun y cerraria con /E/) y despues busy=0, done=1.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;

entity mac25g_gen is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    start    : in  std_logic;
    stop     : in  std_logic;
    cont     : in  std_logic;
    dst      : in  std_logic_vector(47 downto 0);
    src      : in  std_logic_vector(47 downto 0);
    len_min  : in  unsigned(10 downto 0);
    len_max  : in  unsigned(10 downto 0);
    len_step : in  unsigned(10 downto 0);
    count    : in  unsigned(31 downto 0);

    m_tdata  : out std_logic_vector(63 downto 0);
    m_tkeep  : out std_logic_vector(7 downto 0);
    m_tlast  : out std_logic;
    m_tvalid : out std_logic;
    m_tready : in  std_logic;

    busy     : out std_logic;
    done     : out std_logic
  );
end entity mac25g_gen;

architecture rtl of mac25g_gen is
  signal r_busy, r_done : std_logic := '0';
  signal stop_req : std_logic := '0';
  signal eff_min, eff_max, step : unsigned(10 downto 0) := (others => '0');
  signal ln       : unsigned(10 downto 0) := (others => '0');   -- trama actual
  signal ln_nx    : unsigned(10 downto 0) := (others => '0');   -- siguiente
  signal ln_sum   : unsigned(11 downto 0) := (others => '0');
  signal lastw    : unsigned(8 downto 0) := (others => '0');    -- indice ultima palabra
  signal lastn    : unsigned(3 downto 0) := (others => '0');    -- bytes ultima palabra
  signal seq      : unsigned(31 downto 0) := (others => '0');
  signal w        : unsigned(8 downto 0) := (others => '0');    -- palabra en salida
  signal p        : std_logic_vector(63 downto 0) := (others => '0');
  signal left     : unsigned(31 downto 0) := (others => '0');
  signal o_data   : std_logic_vector(63 downto 0) := (others => '0');
  signal o_keep   : std_logic_vector(7 downto 0) := (others => '0');
  signal o_last   : std_logic := '0';

  function w0_of(d, s : std_logic_vector(47 downto 0)) return std_logic_vector is
  begin
    return s(15 downto 0) & d;
  end function;

  function w1_of(s : std_logic_vector(47 downto 0); l : unsigned(10 downto 0))
    return std_logic_vector is
    variable lw : std_logic_vector(15 downto 0) := std_logic_vector(resize(l, 16));
  begin
    -- bytes: src2..5, 0x88, 0xB5, len lo, len hi
    return lw(15 downto 8) & lw(7 downto 0) & ETHERTYPE_GEN(7 downto 0) &
           ETHERTYPE_GEN(15 downto 8) & s(47 downto 16);
  end function;

  -- indice de la ultima palabra y bytes validos en ella
  function lw_of(l : unsigned(10 downto 0)) return unsigned is
  begin
    return resize(shift_right(l - 1, 3), 9);
  end function;
  function ln_of(l : unsigned(10 downto 0)) return unsigned is
  begin
    -- ((l - 1) mod 8) + 1 : 1..8
    return ('0' & (l(2 downto 0) - 1)) + 1;
  end function;
begin

  -- longitud siguiente del barrido, precalculada en DOS etapas (suma y
  -- comparacion): vale 2 ciclos despues de cambiar 'ln', y la siguiente
  -- frontera de trama llega como pronto 3 ciclos despues (>= 3 palabras)
  process(clk)
  begin
    if rising_edge(clk) then
      ln_sum <= ('0' & ln) + ('0' & step);
      if ln_sum > ('0' & eff_max) then ln_nx <= eff_min;
      else ln_nx <= ln_sum(10 downto 0); end if;
    end if;
  end process;

  process(clk)
    variable lmin, lmax : unsigned(10 downto 0);
    variable fin_frame  : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        r_busy <= '0'; r_done <= '0'; w <= (others => '0');
        seq <= (others => '0'); o_last <= '0'; stop_req <= '0';
      elsif start = '1' then
        lmin := len_min;
        if lmin < GEN_MIN_LEN then lmin := to_unsigned(GEN_MIN_LEN, 11); end if;
        lmax := len_max;
        if lmax < lmin then lmax := lmin; end if;
        eff_min <= lmin; eff_max <= lmax; step <= len_step;
        ln    <= lmin;
        lastw <= lw_of(lmin);
        lastn <= ln_of(lmin);
        seq   <= (others => '0');
        left  <= count;
        w     <= (others => '0');
        o_data <= w0_of(dst, src);
        o_keep <= x"FF"; o_last <= '0';
        r_busy <= '1'; r_done <= '0'; stop_req <= '0';
      else
        if stop = '1' and r_busy = '1' then stop_req <= '1'; end if;
        if r_busy = '1' and m_tready = '1' then
        fin_frame := (w = lastw);
        if fin_frame then
          -- siguiente trama (o fin de rafaga: cuenta agotada o stop pedido)
          if (cont = '0' and left = 1) or stop_req = '1' or stop = '1' then
            r_busy <= '0'; r_done <= '1'; stop_req <= '0';
          end if;
          left  <= left - 1;
          seq   <= seq + 1;
          ln    <= ln_nx;
          lastw <= lw_of(ln_nx);
          lastn <= ln_of(ln_nx);
          w     <= (others => '0');
          o_data <= w0_of(dst, src);
          o_keep <= x"FF"; o_last <= '0';
        else
          w <= w + 1;
          case to_integer(w) is
            when 0 =>
              o_data <= w1_of(src, ln);
            when 1 =>
              o_data <= std_logic_vector(not seq) & std_logic_vector(seq);
              p <= seed_of(std_logic_vector(seq));
            when others =>
              o_data <= p;
              p <= xorshift64(p);
          end case;
          if w + 1 = lastw then
            o_last <= '1'; o_keep <= n_to_keep(lastn);
          else
            o_last <= '0'; o_keep <= x"FF";
          end if;
        end if;
        end if;
      end if;
    end if;
  end process;

  m_tdata  <= o_data;
  m_tkeep  <= o_keep;
  m_tlast  <= o_last;
  m_tvalid <= r_busy;
  busy     <= r_busy;
  done     <= r_done;

end architecture rtl;
