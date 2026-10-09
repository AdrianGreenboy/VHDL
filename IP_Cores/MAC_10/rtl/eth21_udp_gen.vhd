-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Generador de tramas IPv4/UDP verificables (formato en eth21_pkg).
--
--   * start: seq = 0, L = len_min; cada trama seq+1 y L += len_step
--     (vuelve a len_min al pasar de len_max; len_step = 0 -> L fija).
--     L se recorta a [18, 1472] (trama de 60..1514 bytes sin FCS).
--   * count tramas por rafaga (cont = 1: sin limite, hasta stop).
--   * gap: ciclos extra sin tvalid tras cada trama (control de tasa; el IPG
--     minimo lo pone el MAC). gap = 0: a tasa de linea.
--   * stop: termina en el limite de trama.
--   * done: sube cuando la ultima palabra fue aceptada; busy durante la rafaga.
--
-- Pipeline: los parametros de la trama SIGUIENTE (n_*) se calculan en segundo
-- plano (checksum IPv4 en 3 etapas) mientras se emite la actual (>= 8
-- palabras), asi que no hay ciclos muertos entre tramas. La salida es un
-- registro con handshake AXIS (avanza si tvalid = 0 o tready = 1). La
-- palabra en curso se identifica con flags one-hot (sin comparadores de
-- indice) y el fin de trama con una cuenta atras.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;
use work.eth21_pkg.all;

entity eth21_udp_gen is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    start    : in  std_logic;
    stop     : in  std_logic;
    cont     : in  std_logic;
    dst      : in  std_logic_vector(47 downto 0);
    src      : in  std_logic_vector(47 downto 0);
    sip      : in  std_logic_vector(31 downto 0);
    dip      : in  std_logic_vector(31 downto 0);
    sport    : in  std_logic_vector(15 downto 0);
    dport    : in  std_logic_vector(15 downto 0);
    len_min  : in  unsigned(10 downto 0);
    len_max  : in  unsigned(10 downto 0);
    len_step : in  unsigned(10 downto 0);
    count    : in  unsigned(31 downto 0);
    gap      : in  unsigned(15 downto 0);

    m_tdata  : out std_logic_vector(63 downto 0);
    m_tkeep  : out std_logic_vector(7 downto 0);
    m_tlast  : out std_logic;
    m_tvalid : out std_logic;
    m_tready : in  std_logic;

    busy     : out std_logic;
    done     : out std_logic
  );
end entity eth21_udp_gen;

architecture rtl of eth21_udp_gen is
  type st_t is (S_IDLE, S_PREP, S_RUN, S_GAP, S_END);
  signal st       : st_t := S_IDLE;
  signal prep_cnt : unsigned(2 downto 0) := (others => '0');
  signal busy_r, done_r, stop_req : std_logic := '0';

  -- configuracion capturada en start
  signal lmin_c, lmax_c, lstep_c : unsigned(10 downto 0) := (others => '0');
  signal kc28     : unsigned(19 downto 0) := (others => '0');   -- suma IPv4 constante + 28
  signal ka, kb   : unsigned(16 downto 0) := (others => '0');
  signal lmin_r, lmax_r : unsigned(10 downto 0) := (others => '0');
  signal c_dst, c_src : std_logic_vector(47 downto 0) := (others => '0');
  signal c_sip, c_dip : std_logic_vector(31 downto 0) := (others => '0');
  signal c_sp, c_dp   : std_logic_vector(15 downto 0) := (others => '0');
  signal c_cont   : std_logic := '0';
  signal c_gap    : unsigned(15 downto 0) := (others => '0');

  -- trama siguiente y su calculo en segundo plano
  signal n_seq    : unsigned(31 downto 0) := (others => '0');
  signal n_len    : unsigned(10 downto 0) := (others => '0');
  signal c1_s     : unsigned(19 downto 0) := (others => '0');
  signal c1_tl, c1_ul, c1_fb : unsigned(15 downto 0) := (others => '0');
  signal c2_f     : unsigned(16 downto 0) := (others => '0');
  signal c2_tl, c2_ul : unsigned(15 downto 0) := (others => '0');
  signal c2_nwm1  : unsigned(7 downto 0) := (others => '0');
  signal c2_lastn : unsigned(3 downto 0) := (others => '0');
  signal n_ck, n_tl, n_ul : std_logic_vector(15 downto 0) := (others => '0');
  signal n_nwm1   : unsigned(7 downto 0) := (others => '0');
  signal n_lastn  : unsigned(3 downto 0) := (others => '0');

  -- trama en curso
  signal cur_seq  : std_logic_vector(31 downto 0) := (others => '0');
  signal cur_ck, cur_tl, cur_ul : std_logic_vector(15 downto 0) := (others => '0');
  signal cur_lastn : unsigned(3 downto 0) := (others => '0');
  signal wrem     : unsigned(7 downto 0) := (others => '0');
  signal whdr     : std_logic_vector(5 downto 0) := (others => '0');  -- one-hot w0..w5
  signal p        : std_logic_vector(63 downto 0) := (others => '0');
  signal h        : std_logic_vector(15 downto 0) := (others => '0');
  signal rem_f    : unsigned(31 downto 0) := (others => '0');
  signal gapc     : unsigned(15 downto 0) := (others => '0');

  -- salida
  signal o_v, o_last : std_logic := '0';
  signal o_d      : std_logic_vector(63 downto 0) := (others => '0');
  signal o_k      : std_logic_vector(7 downto 0) := (others => '0');
begin

  -- calculo en segundo plano de la trama n (3 etapas, siempre activo)
  process(clk)
    variable fb : unsigned(15 downto 0);
    variable f2 : unsigned(16 downto 0);
  begin
    if rising_edge(clk) then
      c1_tl <= resize(n_len, 16) + 28;
      c1_ul <= resize(n_len, 16) + 8;
      c1_fb <= resize(n_len, 16) + UDP_HDR_BYTES;
      c1_s  <= kc28 + resize(n_len, 20) + resize(n_seq(15 downto 0), 20);
      -- etapa 2: primer plegado; palabras = ceil(fb/8); bytes de la ultima
      c2_f  <= resize(c1_s(15 downto 0), 17) + resize(c1_s(19 downto 16), 17);
      c2_tl <= c1_tl; c2_ul <= c1_ul;
      fb := c1_fb - 1;
      c2_nwm1  <= fb(10 downto 3);
      c2_lastn <= resize(fb(2 downto 0), 4) + 1;
      -- etapa 3: segundo plegado y complemento
      f2 := resize(c2_f(15 downto 0), 17) + resize(c2_f(16 downto 16), 17);
      n_ck  <= not std_logic_vector(f2(15 downto 0));
      n_tl  <= std_logic_vector(c2_tl);
      n_ul  <= std_logic_vector(c2_ul);
      n_nwm1  <= c2_nwm1;
      n_lastn <= c2_lastn;
    end if;
  end process;

  process(clk)
    variable v_min, v_max : unsigned(10 downto 0);
    variable nxt : unsigned(11 downto 0);
    variable adv, fin : boolean;
    variable wd : std_logic_vector(63 downto 0);

    procedure start_frame is
    begin
      cur_seq   <= std_logic_vector(n_seq);
      cur_ck    <= n_ck; cur_tl <= n_tl; cur_ul <= n_ul;
      cur_lastn <= n_lastn;
      wrem      <= n_nwm1;
      whdr      <= "000001";
      p         <= std_logic_vector(not n_seq) & std_logic_vector(n_seq);
      h         <= (others => '0');                  -- checksum UDP = 0
      n_seq     <= n_seq + 1;
      -- suma en 12 bits: con len_step grande no hay vuelta por 2048
      nxt := resize(n_len, 12) + resize(lstep_c, 12);
      if lstep_c = 0 then
        null;
      elsif nxt > resize(lmax_c, 12) then
        n_len <= lmin_c;
      else
        n_len <= nxt(10 downto 0);
      end if;
    end procedure;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= S_IDLE; o_v <= '0'; o_last <= '0';
        busy_r <= '0'; done_r <= '0'; stop_req <= '0';
        whdr <= (others => '0');
      else
        adv := (o_v = '0') or (m_tready = '1');
        if o_v = '1' and m_tready = '1' then o_v <= '0'; end if;
        if stop = '1' and busy_r = '1' then stop_req <= '1'; end if;

        case st is
          when S_IDLE =>
            if start = '1' then
              -- solo se capturan las entradas; recortes y suma IPv4 se
              -- calculan en S_PREP en etapas (camino corto a 390.625 MHz)
              lmin_r <= len_min; lmax_r <= len_max; lstep_c <= len_step;
              c_dst <= dst; c_src <= src; c_sip <= sip; c_dip <= dip;
              c_sp <= sport; c_dp <= dport; c_cont <= cont; c_gap <= gap;
              rem_f <= count;
              stop_req <= '0';
              done_r <= '0';
              if count = 0 and cont = '0' then
                done_r <= '1';
              else
                busy_r <= '1';
                prep_cnt <= to_unsigned(7, 3);
                st <= S_PREP;
              end if;
            end if;

          when S_PREP =>
            -- 7: recorte de L min y sumas parciales de las IP
            -- 6: recorte de L max y suma IPv4 constante
            -- 5: primera trama; 4..1: pipeline del checksum; 0: arranque
            case to_integer(prep_cnt) is
              when 7 =>
                v_min := lmin_r;
                if v_min < PAY_MIN then v_min := to_unsigned(PAY_MIN, 11); end if;
                if v_min > PAY_MAX then v_min := to_unsigned(PAY_MAX, 11); end if;
                lmin_c <= v_min;
                ka <= resize(unsigned(c_sip(31 downto 16)), 17) + resize(unsigned(c_sip(15 downto 0)), 17);
                kb <= resize(unsigned(c_dip(31 downto 16)), 17) + resize(unsigned(c_dip(15 downto 0)), 17);
              when 6 =>
                v_max := lmax_r;
                if v_max < lmin_c then v_max := lmin_c; end if;
                if v_max > PAY_MAX then v_max := to_unsigned(PAY_MAX, 11); end if;
                lmax_c <= v_max;
                kc28 <= to_unsigned(16#C511# + 28, 20) + resize(ka, 20) + resize(kb, 20);
              when 5 =>
                n_seq <= (others => '0'); n_len <= lmin_c;
              when others => null;
            end case;
            if stop_req = '1' or stop = '1' then
              st <= S_END;
            elsif prep_cnt = 0 then
              start_frame;
              st <= S_RUN;
            else
              prep_cnt <= prep_cnt - 1;
            end if;

          when S_RUN =>
            if adv then
              -- palabra en curso
              if whdr(0) = '1' then
                wd := c_src(15 downto 0) & c_dst;
              elsif whdr(1) = '1' then
                wd := x"00" & x"45" & x"00" & x"08" & c_src(47 downto 16);
              elsif whdr(2) = '1' then
                wd := x"11" & x"40" & x"00" & x"40" & be16(cur_seq(15 downto 0)) & be16(cur_tl);
              elsif whdr(3) = '1' then
                wd := be16(c_dip(31 downto 16)) & be16(c_sip(15 downto 0)) &
                      be16(c_sip(31 downto 16)) & be16(cur_ck);
              elsif whdr(4) = '1' then
                wd := be16(cur_ul) & be16(c_dp) & be16(c_sp) & be16(c_dip(15 downto 0));
              else
                wd := p(47 downto 0) & h;
              end if;
              o_v <= '1';
              o_d <= wd;
              fin := (wrem = 0);
              if fin then
                o_last <= '1'; o_k <= n_to_keep(cur_lastn);
              else
                o_last <= '0'; o_k <= (others => '1');
              end if;
              whdr <= whdr(4 downto 0) & '0';
              -- estado del payload: tras w5 cargar P1, despues xorshift
              if whdr(5) = '1' then
                h <= p(63 downto 48);
                p <= seed_of(cur_seq);
              elsif whdr(4 downto 0) = "00000" then
                h <= p(63 downto 48);
                p <= xorshift64(p);
              end if;

              if fin then
                rem_f <= rem_f - 1;
                if (c_cont = '0' and rem_f = 1) or stop_req = '1' or stop = '1' then
                  st <= S_END;
                elsif c_gap /= 0 then
                  gapc <= c_gap;
                  st <= S_GAP;
                else
                  start_frame;
                end if;
              else
                wrem <= wrem - 1;
              end if;
            end if;

          when S_GAP =>
            if stop_req = '1' or stop = '1' then
              st <= S_END;
            elsif gapc = 1 then
              start_frame;
              st <= S_RUN;
            else
              gapc <= gapc - 1;
            end if;

          when S_END =>
            -- la ultima palabra ya fue aceptada (o no habia ninguna)
            if o_v = '0' or m_tready = '1' then
              done_r <= '1'; busy_r <= '0';
              st <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  m_tdata  <= o_d;
  m_tkeep  <= o_k;
  m_tlast  <= o_last;
  m_tvalid <= o_v;
  busy     <= busy_r;
  done     <= done_r;

end architecture rtl;
