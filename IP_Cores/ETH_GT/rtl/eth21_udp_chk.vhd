-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Checker de tramas IPv4/UDP del generador (formato en eth21_pkg), byte a
-- byte, independiente del CRC del MAC:
--   * cabeceras Ethernet/IPv4/UDP contra la configuracion (MAC, IP, puertos)
--   * checksum IPv4 recalculado a partir de tot_len e id recibidos
--   * udp_len = tot_len - 20, id = seq[15:0], longitud = tot_len + 14
--   * payload: P0 = ~seq & seq, P1 = seed_of(seq), xorshift64 (desplazado 2
--     bytes respecto a las palabras de 64 bits)
--   * continuidad de secuencia (seq = anterior + 1)
-- Tramas con tuser = 1 (malas segun el MAC): solo chk_rxerr y avanzan la
-- secuencia esperada.
--
-- Pipeline como el checker del Core 20: X0 registra la entrada, X1a forma la
-- palabra esperada (flags one-hot de palabra), X1b compara por bytes, X2
-- acumula y emite el veredicto. El checksum IPv4 se calcula en 3 etapas a
-- partir de w2 y se compara al procesar w7 (toda trama valida tiene >= 8
-- palabras; si la trama es mas corta lo detecta la comprobacion de longitud).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;
use work.eth21_pkg.all;

entity eth21_udp_chk is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    restart  : in  std_logic;   -- pulso: olvida la secuencia esperada
    dst      : in  std_logic_vector(47 downto 0);   -- MAC destino esperada
    src      : in  std_logic_vector(47 downto 0);
    sip      : in  std_logic_vector(31 downto 0);
    dip      : in  std_logic_vector(31 downto 0);
    sport    : in  std_logic_vector(15 downto 0);
    dport    : in  std_logic_vector(15 downto 0);

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
end entity eth21_udp_chk;

architecture rtl of eth21_udp_chk is
  -- X0
  signal i_v, i_last, i_user : std_logic := '0';
  signal i_d    : std_logic_vector(63 downto 0) := (others => '0');
  signal i_n    : unsigned(3 downto 0) := (others => '0');
  -- X1a
  signal w      : unsigned(8 downto 0) := (others => '0');
  signal wf     : std_logic_vector(7 downto 0) := "00000001";   -- one-hot w0..w7
  signal tl_r, id_r, ul_e : std_logic_vector(15 downto 0) := (others => '0');
  signal tl14   : unsigned(15 downto 0) := (others => '0');
  signal seq_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal p      : std_logic_vector(63 downto 0) := (others => '0');
  signal h      : std_logic_vector(15 downto 0) := (others => '0');
  signal kc     : unsigned(19 downto 0) := (others => '0');
  signal ka, kb : unsigned(16 downto 0) := (others => '0');
  signal seq_eq : std_logic := '0';
  signal s1     : unsigned(19 downto 0) := (others => '0');
  signal f1     : unsigned(16 downto 0) := (others => '0');
  signal ck_e, ck_rx : std_logic_vector(15 downto 0) := (others => '0');
  signal ya_v, ya_last, ya_user, ya_hdr : std_logic := '0';
  signal ya_d, ya_e : std_logic_vector(63 downto 0) := (others => '0');
  signal ya_cm  : std_logic_vector(7 downto 0) := (others => '0');
  signal ya_tot : unsigned(15 downto 0) := (others => '0');
  -- X1b
  signal x_v, x_last, x_user, x_hdr : std_logic := '0';
  signal x_mm   : std_logic_vector(7 downto 0) := (others => '0');
  signal x_tot  : unsigned(15 downto 0) := (others => '0');
  -- X2
  signal bad_acc, have : std_logic := '0';
  signal exp_seq : unsigned(31 downto 0) := (others => '0');
  signal p_ok, p_bad, p_seq, p_rxe : std_logic := '0';
begin

  -- X0
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

  -- checksum esperado (siempre activo a partir de tl_r / id_r capturados)
  process(clk)
    variable f2 : unsigned(16 downto 0);
  begin
    if rising_edge(clk) then
      -- suma constante en dos etapas (entradas cuasi-estaticas)
      ka <= resize(unsigned(sip(31 downto 16)), 17) + resize(unsigned(sip(15 downto 0)), 17);
      kb <= resize(unsigned(dip(31 downto 16)), 17) + resize(unsigned(dip(15 downto 0)), 17);
      kc <= to_unsigned(16#C511#, 20) + resize(ka, 20) + resize(kb, 20);
      s1 <= kc + resize(unsigned(tl_r), 20) + resize(unsigned(id_r), 20);
      f1 <= resize(s1(15 downto 0), 17) + resize(s1(19 downto 16), 17);
      f2 := resize(f1(15 downto 0), 17) + resize(f1(16 downto 16), 17);
      ck_e <= not std_logic_vector(f2(15 downto 0));
    end if;
  end process;

  -- X1a: palabra esperada
  process(clk)
    variable e : std_logic_vector(63 downto 0);
    variable seq_now : std_logic_vector(31 downto 0);
    variable hdr : std_logic;
  begin
    if rising_edge(clk) then
      ya_v <= '0';
      if rst = '1' or restart = '1' then
        w <= (others => '0'); wf <= "00000001";
      elsif i_v = '1' then
        hdr := '0';
        if wf(0) = '1' then
          e := src(15 downto 0) & dst;
        elsif wf(1) = '1' then
          e := x"00" & x"45" & x"00" & x"08" & src(47 downto 16);
        elsif wf(2) = '1' then
          -- tot_len e id se toman de la propia palabra (se validan despues)
          e := x"11" & x"40" & x"00" & x"40" & i_d(31 downto 0);
          tl_r <= i_d(7 downto 0) & i_d(15 downto 8);
          id_r <= i_d(23 downto 16) & i_d(31 downto 24);
        elsif wf(3) = '1' then
          e := be16(dip(31 downto 16)) & be16(sip(15 downto 0)) &
               be16(sip(31 downto 16)) & i_d(15 downto 0);
          ck_rx <= i_d(7 downto 0) & i_d(15 downto 8);
          ul_e  <= std_logic_vector(unsigned(tl_r) - 20);
          tl14  <= unsigned(tl_r) + 14;
        elsif wf(4) = '1' then
          e := be16(ul_e) & be16(dport) & be16(sport) & be16(dip(15 downto 0));
        elsif wf(5) = '1' then
          seq_now := i_d(47 downto 16);
          e := (not seq_now(15 downto 0)) & seq_now & x"0000";
          seq_r <= seq_now;
          h <= not seq_now(31 downto 16);
          p <= seed_of(seq_now);
          if id_r /= seq_now(15 downto 0) then hdr := '1'; end if;
        else
          e := p(47 downto 0) & h;
          h <= p(63 downto 48);
          p <= xorshift64(p);
          -- comparacion de secuencia precalculada (exp_seq ya es estable)
          if wf(6) = '1' then
            if unsigned(seq_r) = exp_seq then seq_eq <= '1'; else seq_eq <= '0'; end if;
          end if;
          if wf(7) = '1' and ck_rx /= ck_e then hdr := '1'; end if;
        end if;
        ya_v <= '1'; ya_d <= i_d; ya_e <= e; ya_cm <= n_to_keep(i_n);
        ya_last <= i_last; ya_user <= i_user; ya_hdr <= hdr;
        ya_tot <= shift_left(resize(w, 16), 3) + resize(i_n, 16);
        if i_last = '1' then
          w <= (others => '0'); wf <= "00000001";
        else
          if w /= 511 then w <= w + 1; end if;
          wf <= wf(6 downto 0) & '0';
        end if;
      end if;
    end if;
  end process;

  -- X1b: desajuste por byte
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
        x_v <= '1'; x_mm <= mm; x_last <= ya_last; x_user <= ya_user;
        x_tot <= ya_tot; x_hdr <= ya_hdr;
      end if;
    end if;
  end process;

  -- X2: veredicto por trama
  process(clk)
    variable bad : std_logic;
  begin
    if rising_edge(clk) then
      p_ok <= '0'; p_bad <= '0'; p_seq <= '0'; p_rxe <= '0';
      if rst = '1' or restart = '1' then
        bad_acc <= '0'; have <= '0'; exp_seq <= (others => '0');
      elsif x_v = '1' then
        bad := bad_acc or x_hdr or (x_mm(0) or x_mm(1) or x_mm(2) or x_mm(3) or
                                    x_mm(4) or x_mm(5) or x_mm(6) or x_mm(7));
        if x_last = '1' then
          bad_acc <= '0';
          if x_user = '1' then
            p_rxe <= '1';
            if have = '1' then exp_seq <= exp_seq + 1; end if;
          else
            if x_tot /= tl14 then bad := '1'; end if;
            if bad = '1' then p_bad <= '1'; else p_ok <= '1'; end if;
            if have = '1' and seq_eq = '0' then p_seq <= '1'; end if;
            exp_seq <= unsigned(seq_r) + 1;
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
