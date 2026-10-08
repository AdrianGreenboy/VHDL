-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Checker de tramas: verifica byte a byte cada trama entregada por el MAC RX
-- contra el patron del generador (independiente del CRC: detecta palabras
-- perdidas, duplicadas, reordenadas o desplazadas aunque el FCS cuadre).
--
-- Por trama (tuser=0):
--   w0 = dst + src[0..1]                          (configuracion)
--   w1 = src[2..5] + ethertype; captura len (bytes 6..7)
--   w2 = seq + ~seq                               (captura seq)
--   w3+= P0, P1, ... (xorshift64 sembrado por seq)
--   los bytes con indice >= len deben ser 0 (padding) y la longitud entregada
--   debe ser max(len, 60).
--   Ademas, continuidad de secuencia: seq = anterior + 1.
-- Tramas con tuser=1 (mala segun el MAC): solo cuentan como chk_rxerr y
-- avanzan la secuencia esperada.
--
-- Pipeline: X0 registra la entrada y decodifica tkeep, X1a forma la palabra
-- esperada, X1b compara byte a byte, X2 acumula y emite el veredicto.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;

entity mac25g_chk is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    restart  : in  std_logic;   -- pulso: olvida la secuencia esperada
    dst      : in  std_logic_vector(47 downto 0);
    src      : in  std_logic_vector(47 downto 0);

    s_tdata  : in  std_logic_vector(63 downto 0);
    s_tkeep  : in  std_logic_vector(7 downto 0);
    s_tlast  : in  std_logic;
    s_tuser  : in  std_logic;
    s_tvalid : in  std_logic;

    ev_ok    : out std_logic;
    ev_bad   : out std_logic;
    ev_seq   : out std_logic;
    ev_rxerr : out std_logic
  );
end entity mac25g_chk;

architecture rtl of mac25g_chk is
  -- X0
  signal i_v, i_last, i_user : std_logic := '0';
  signal i_d    : std_logic_vector(63 downto 0) := (others => '0');
  signal i_n    : unsigned(3 downto 0) := (others => '0');
  signal w      : unsigned(8 downto 0) := (others => '0');
  signal len_r  : unsigned(15 downto 0) := (others => '0');
  signal rem_r  : signed(15 downto 0) := (others => '0');    -- len - 8*w (w>=2)
  signal seq_r  : unsigned(31 downto 0) := (others => '0');
  signal p      : std_logic_vector(63 downto 0) := (others => '0');
  signal w0f    : std_logic := '1';
  signal w1f, w2f : std_logic := '0';
  signal padz_r : std_logic_vector(7 downto 0) := (others => '0');
  -- X1a -> X1b
  signal ya_v, ya_last, ya_user : std_logic := '0';
  signal ya_d, ya_e : std_logic_vector(63 downto 0) := (others => '0');
  signal ya_cm  : std_logic_vector(7 downto 0) := (others => '0');
  signal ya_tot : unsigned(15 downto 0) := (others => '0');
  -- X1b -> X2
  signal x_v, x_last, x_user : std_logic := '0';
  signal x_mm   : std_logic_vector(7 downto 0) := (others => '0');
  signal x_tot  : unsigned(15 downto 0) := (others => '0');
  -- X2
  signal bad_acc : std_logic := '0';
  signal have    : std_logic := '0';
  signal exp_seq : unsigned(31 downto 0) := (others => '0');
  signal p_ok, p_bad, p_seq, p_rxe : std_logic := '0';
begin

  -- X0: registro de entrada; n = bytes validos (8 si no es la ultima)
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or restart = '1' then
        i_v <= '0';
      else
        i_v <= s_tvalid;
        if s_tvalid = '1' then
          i_d <= s_tdata; i_last <= s_tlast; i_user <= s_tuser;
          if s_tlast = '1' then i_n <= keep_to_n(s_tkeep);
          else i_n <= to_unsigned(8, 4); end if;
        end if;
      end if;
    end if;
  end process;

  -- X1a: palabra esperada (ya con el padding a cero) y mascara de bytes.
  -- La mascara de padding de cada palabra se calcula en la palabra ANTERIOR
  -- (padz_r) y la palabra en curso se identifica con flags one-hot: el camino
  -- registro -> e es un mux de 4 entradas y un AND, sin comparadores.
  process(clk)
    variable e      : std_logic_vector(63 downto 0);
    variable seq_now : std_logic_vector(31 downto 0);

  begin
    if rising_edge(clk) then
      ya_v <= '0';
      if rst = '1' or restart = '1' then
        w <= (others => '0');
        w0f <= '1'; w1f <= '0'; w2f <= '0';
        padz_r <= (others => '0');
      elsif i_v = '1' then
        if w0f = '1' then
          e := src(15 downto 0) & dst;
        elsif w1f = '1' then
          e := i_d(63 downto 48) & ETHERTYPE_GEN(7 downto 0) &
               ETHERTYPE_GEN(15 downto 8) & src(47 downto 16);
        elsif w2f = '1' then
          seq_now := i_d(31 downto 0);
          e := (not seq_now) & seq_now;
        else
          e := p;
        end if;
        for b in 0 to 7 loop
          if padz_r(b) = '1' then e(8*b+7 downto 8*b) := x"00"; end if;
        end loop;
        ya_v <= '1'; ya_d <= i_d; ya_e <= e; ya_cm <= n_to_keep(i_n);
        ya_last <= i_last; ya_user <= i_user;
        ya_tot <= shift_left(resize(w, 16), 3) + resize(i_n, 16);

        -- estado para la palabra siguiente. La mascara se obtiene comparando
        -- un registro con constantes (sin restar antes): byte b de la palabra
        -- 2 es padding si len <= 16+b; de la palabra w+1 si rem_r <= 8+b.
        if w1f = '1' then
          len_r  <= unsigned(i_d(63 downto 48));
          rem_r  <= signed(resize(unsigned(i_d(63 downto 48)), 16)) - 16;
          for b in 0 to 7 loop
            if unsigned(i_d(63 downto 48)) <= 16 + b then padz_r(b) <= '1';
            else padz_r(b) <= '0'; end if;
          end loop;
        elsif w0f = '0' then
          rem_r  <= rem_r - 8;
          for b in 0 to 7 loop
            if rem_r <= 8 + b then padz_r(b) <= '1'; else padz_r(b) <= '0'; end if;
          end loop;
        end if;
        if w2f = '1' then
          seq_r <= unsigned(i_d(31 downto 0));
          p <= seed_of(i_d(31 downto 0));
        elsif w0f = '0' and w1f = '0' then
          p <= xorshift64(p);
        end if;
        if i_last = '1' then
          w <= (others => '0');
          w0f <= '1'; w1f <= '0'; w2f <= '0';
          padz_r <= (others => '0');
        else
          if w /= 511 then w <= w + 1; end if;
          w0f <= '0'; w1f <= w0f; w2f <= w1f;
        end if;
      end if;
    end if;
  end process;

  -- X1b: desajuste por byte (comparacion de 8 bits por byte)
  process(clk)
    variable mm : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk) then
      x_v <= '0';
      if rst = '1' or restart = '1' then
        x_v <= '0';
      elsif ya_v = '1' then
        for b in 0 to 7 loop
          if ya_cm(b) = '1' and ya_d(8*b+7 downto 8*b) /= ya_e(8*b+7 downto 8*b) then
            mm(b) := '1';
          else
            mm(b) := '0';
          end if;
        end loop;
        x_v <= '1'; x_mm <= mm; x_last <= ya_last; x_user <= ya_user; x_tot <= ya_tot;
      end if;
    end if;
  end process;

  -- X2: veredicto por trama
  process(clk)
    variable bad : std_logic;
    variable lexp : unsigned(15 downto 0);
  begin
    if rising_edge(clk) then
      p_ok <= '0'; p_bad <= '0'; p_seq <= '0'; p_rxe <= '0';
      if rst = '1' or restart = '1' then
        bad_acc <= '0'; have <= '0'; exp_seq <= (others => '0');
      elsif x_v = '1' then
        bad := bad_acc or (x_mm(0) or x_mm(1) or x_mm(2) or x_mm(3) or
                           x_mm(4) or x_mm(5) or x_mm(6) or x_mm(7));
        if x_last = '1' then
          bad_acc <= '0';
          if x_user = '1' then
            p_rxe <= '1';
            if have = '1' then exp_seq <= exp_seq + 1; end if;
          else
            if len_r < 60 then lexp := to_unsigned(60, 16); else lexp := len_r; end if;
            if x_tot /= lexp then bad := '1'; end if;
            if bad = '1' then p_bad <= '1'; else p_ok <= '1'; end if;
            if have = '1' and seq_r /= exp_seq then p_seq <= '1'; end if;
            exp_seq <= seq_r + 1;
            have <= '1';
          end if;
        else
          bad_acc <= bad;
        end if;
      end if;
    end if;
  end process;

  ev_ok    <= p_ok;
  ev_bad   <= p_bad;
  ev_seq   <= p_seq;
  ev_rxerr <= p_rxe;

end architecture rtl;
