-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- MAC TX: AXIS 64b -> bloques 64B/66B (payload + is_data) hacia el PCS.
--
-- Pipeline de 5 etapas, todas avanzan solo con 'ce' (una ranura de bloque por
-- ce). No hay backpressure interno: la etapa A es la unica que decide el
-- flujo y reserva de antemano las ranuras que las etapas posteriores
-- necesitan (inicio, desbordamiento de FCS, T0 e IPG).
--
--   A  framer : token START, palabras, padding a 60 B, 2 ranuras de hueco
--   B  CRC    : acumula CRC-32 sobre palabras completas (lazo de 64 bits)
--   C  FCS    : CRC de la ultima palabra (n = 1..8 bytes), fuera del lazo
--   D  merge  : inserta las 4 bytes de FCS; si no caben, las desborda a la
--               ranura siguiente (que A garantiza que es un hueco)
--   E  encoder: S / D / T0..T7 / I / E  (cl.49)
--
-- Regla de huecos: tras la ultima palabra de cada trama A emite exactamente 2
-- ranuras vacias. Para todo n (bytes de la ultima palabra tras padding) eso
-- da IPG >= 12 caracteres (incl. /T/) y aloja el T0 o el desbordamiento de
-- FCS. Coste: 3 ranuras + ceil(P/8) por trama (P = longitud con padding).
-- Sin DIC y con /S/ solo en carril 0: decision de alcance v1, documentada.
--
-- Underrun: si s_tvalid cae a mitad de trama se emite un bloque /E/, se
-- cuenta tx_underrun y se descarta el resto de la trama de origen.
--
-- Inyeccion (inj, pulso): arma un flip del bit 0 del bloque de DATOS de indice
-- 1 de la siguiente trama (determinista: el CRC del receptor debe fallar en
-- exactamente esa trama).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;

entity mac25g_tx is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    ce          : in  std_logic;     -- una ranura de bloque por ce

    s_tdata     : in  std_logic_vector(63 downto 0);
    s_tkeep     : in  std_logic_vector(7 downto 0);
    s_tlast     : in  std_logic;
    s_tvalid    : in  std_logic;
    s_tready    : out std_logic;

    inj         : in  std_logic;     -- pulso: arma inyeccion de 1 bit

    blk_valid   : out std_logic;
    blk_payload : out std_logic_vector(63 downto 0);
    blk_is_data : out std_logic;

    -- estadisticas (pulsos de 1 ciclo, registrados)
    ev_frame    : out std_logic;
    ev_bytes    : out unsigned(15 downto 0);   -- bytes en el cable (incl. FCS)
    ev_underrun : out std_logic
  );
end entity mac25g_tx;

architecture rtl of mac25g_tx is
  constant K_BUB  : std_logic_vector(1 downto 0) := "00";
  constant K_STRT : std_logic_vector(1 downto 0) := "01";
  constant K_DATA : std_logic_vector(1 downto 0) := "10";
  constant K_ERR  : std_logic_vector(1 downto 0) := "11";

  type a_st_t is (SA_IDLE, SA_DATA, SA_PAD, SA_GAP1, SA_GAP2, SA_DRAIN);
  signal a_st : a_st_t := SA_IDLE;
  signal wcnt : unsigned(8 downto 0) := (others => '0');   -- palabras emitidas (satura 511)

  -- token etapa A
  signal a_kind : std_logic_vector(1 downto 0) := K_BUB;
  signal a_data : std_logic_vector(63 downto 0) := (others => '0');
  signal a_n    : unsigned(3 downto 0) := (others => '0');
  signal a_last : std_logic := '0';
  -- etapa B
  signal crc_acc : std_logic_vector(31 downto 0) := CRC_INIT;
  signal b_kind  : std_logic_vector(1 downto 0) := K_BUB;
  signal b_data  : std_logic_vector(63 downto 0) := (others => '0');
  signal b_n     : unsigned(3 downto 0) := (others => '0');
  signal b_last  : std_logic := '0';
  signal b_crc   : std_logic_vector(31 downto 0) := (others => '0');
  -- etapa C
  signal c_kind  : std_logic_vector(1 downto 0) := K_BUB;
  signal c_data  : std_logic_vector(63 downto 0) := (others => '0');
  signal c_n     : unsigned(3 downto 0) := (others => '0');
  signal c_last  : std_logic := '0';
  signal c_fcs   : std_logic_vector(31 downto 0) := (others => '0');
  -- etapa D
  signal d_kind  : std_logic_vector(1 downto 0) := K_BUB;
  signal d_data  : std_logic_vector(63 downto 0) := (others => '0');
  signal d_n     : unsigned(3 downto 0) := (others => '0');
  signal d_last  : std_logic := '0';
  signal sp_v    : std_logic := '0';
  signal sp_data : std_logic_vector(31 downto 0) := (others => '0');
  signal sp_n    : unsigned(3 downto 0) := (others => '0');
  -- etapa E
  signal pend_t0 : std_logic := '0';
  signal dblk    : unsigned(1 downto 0) := (others => '0');  -- indice de bloque de datos (satura 3)
  signal inj_arm : std_logic := '0';
  signal o_valid : std_logic := '0';
  signal o_pl    : std_logic_vector(63 downto 0) := IDLE_BLOCK;
  signal o_isd   : std_logic := '0';
  -- estadisticas
  signal r_evf   : std_logic := '0';
  signal r_evb   : unsigned(15 downto 0) := (others => '0');
  signal r_evu   : std_logic := '0';
begin

  s_tready <= ce when (a_st = SA_DATA or a_st = SA_DRAIN) else '0';

  -----------------------------------------------------------------------------
  -- Etapa A: framer
  -----------------------------------------------------------------------------
  process(clk)
    variable n   : unsigned(3 downto 0);
    variable dm  : std_logic_vector(63 downto 0);
  begin
    if rising_edge(clk) then
      r_evf <= '0';
      r_evu <= '0';
      if rst = '1' then
        a_st <= SA_IDLE; wcnt <= (others => '0');
        a_kind <= K_BUB; a_last <= '0'; a_n <= (others => '0');
        a_data <= (others => '0');
      elsif ce = '1' then
        -- por defecto: hueco
        a_kind <= K_BUB;
        a_last <= '0';
        a_n    <= to_unsigned(8, 4);
        case a_st is
          when SA_IDLE =>
            if s_tvalid = '1' then
              a_kind <= K_STRT;
              wcnt   <= (others => '0');
              a_st   <= SA_DATA;
            end if;

          when SA_DATA =>
            if s_tvalid = '1' then
              if s_tlast = '1' then n := keep_to_n(s_tkeep);
              else n := to_unsigned(8, 4); end if;
              dm := s_tdata and byte_mask(n);
              a_kind <= K_DATA;
              a_data <= dm;
              if s_tlast = '0' then
                if wcnt /= 511 then wcnt <= wcnt + 1; end if;
              elsif wcnt >= 8 or (wcnt = 7 and n >= 4) then
                -- trama >= 60 bytes: sin padding
                a_last <= '1'; a_n <= n;
                r_evf <= '1';
                r_evb <= shift_left(resize(wcnt, 16), 3) + resize(n, 16) + 4;
                a_st <= SA_GAP1;
              elsif wcnt = 7 then
                -- ultima palabra ya es la 8a: completar hasta 60 (n=4)
                a_last <= '1'; a_n <= to_unsigned(4, 4);
                r_evf <= '1'; r_evb <= to_unsigned(64, 16);
                a_st <= SA_GAP1;
              else
                -- padding: esta palabra sale completa (ceros tras n)
                wcnt <= wcnt + 1;
                a_st <= SA_PAD;
              end if;
            else
              -- underrun a mitad de trama
              a_kind <= K_ERR;
              r_evu  <= '1';
              a_st   <= SA_DRAIN;
            end if;

          when SA_PAD =>
            a_kind <= K_DATA;
            a_data <= (others => '0');
            if wcnt = 7 then
              a_last <= '1'; a_n <= to_unsigned(4, 4);
              r_evf <= '1'; r_evb <= to_unsigned(64, 16);
              a_st <= SA_GAP1;
            else
              wcnt <= wcnt + 1;
            end if;

          when SA_GAP1 =>
            a_st <= SA_GAP2;

          when SA_GAP2 =>
            a_st <= SA_IDLE;

          when SA_DRAIN =>
            -- descartar el resto de la trama de origen (s_tready alto)
            if s_tvalid = '1' and s_tlast = '1' then
              a_st <= SA_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Etapa B: CRC acumulado sobre palabras completas
  -----------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        crc_acc <= CRC_INIT; b_kind <= K_BUB; b_last <= '0';
        b_n <= (others => '0'); b_data <= (others => '0');
        b_crc <= (others => '0');
      elsif ce = '1' then
        b_kind <= a_kind; b_data <= a_data; b_n <= a_n; b_last <= a_last;
        b_crc  <= crc_acc;
        if a_kind = K_STRT then
          crc_acc <= CRC_INIT;
        elsif a_kind = K_DATA and a_last = '0' then
          crc_acc <= crc_upd(crc_acc, a_data, 64);
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Etapa C: FCS de la ultima palabra (8 arboles + mux, fuera del lazo)
  -----------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        c_kind <= K_BUB; c_last <= '0'; c_n <= (others => '0');
        c_data <= (others => '0'); c_fcs <= (others => '0');
      elsif ce = '1' then
        c_kind <= b_kind; c_data <= b_data; c_n <= b_n; c_last <= b_last;
        c_fcs  <= not crc_nbytes(b_crc, b_data, b_n);
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Etapa D: insercion de FCS (con desbordamiento a la ranura siguiente)
  -----------------------------------------------------------------------------
  process(clk)
    variable v : std_logic_vector(95 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        d_kind <= K_BUB; d_last <= '0'; d_n <= (others => '0');
        d_data <= (others => '0'); sp_v <= '0';
        sp_data <= (others => '0'); sp_n <= (others => '0');
      elsif ce = '1' then
        if c_kind = K_DATA and c_last = '1' then
          v := x"00000000" & c_data;          -- bytes >= n ya son cero
          case to_integer(c_n) is
            when 1      => v(39 downto 8)  := c_fcs;
            when 2      => v(47 downto 16) := c_fcs;
            when 3      => v(55 downto 24) := c_fcs;
            when 4      => v(63 downto 32) := c_fcs;
            when 5      => v(71 downto 40) := c_fcs;
            when 6      => v(79 downto 48) := c_fcs;
            when 7      => v(87 downto 56) := c_fcs;
            when others => v(95 downto 64) := c_fcs;
          end case;
          d_kind <= K_DATA;
          d_data <= v(63 downto 0);
          if c_n <= 4 then
            d_last <= '1'; d_n <= c_n + 4;
            sp_v <= '0';
          else
            d_last <= '0'; d_n <= to_unsigned(8, 4);
            sp_v <= '1'; sp_data <= v(95 downto 64); sp_n <= c_n - 4;
          end if;
        elsif sp_v = '1' then
          -- la ranura actual es un hueco garantizado por la etapa A
          d_kind <= K_DATA;
          d_data <= x"00000000" & sp_data;
          d_n <= sp_n; d_last <= '1';
          sp_v <= '0';
        else
          d_kind <= c_kind; d_data <= c_data; d_n <= c_n; d_last <= c_last;
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Etapa E: codificador 64B/66B cl.49
  -----------------------------------------------------------------------------
  process(clk)
    variable pl : std_logic_vector(63 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pend_t0 <= '0'; dblk <= (others => '0'); inj_arm <= '0';
        o_valid <= '0'; o_pl <= IDLE_BLOCK; o_isd <= '0';
      else
        o_valid <= ce;
        if inj = '1' then inj_arm <= '1'; end if;
        if ce = '1' then
          case d_kind is
            when K_STRT =>
              o_pl <= START_BLOCK; o_isd <= '0';
              dblk <= (others => '0');
              pend_t0 <= '0';
            when K_ERR =>
              o_pl <= ERROR_BLOCK; o_isd <= '0';
              pend_t0 <= '0';
            when K_DATA =>
              if d_last = '1' and d_n /= 8 then
                -- Tn: tipo + n bytes de datos (bytes >= n ya son cero)
                o_pl <= d_data(55 downto 0) & term_type(to_integer(d_n(2 downto 0)));
                o_isd <= '0';
              else
                pl := d_data;
                if dblk = 1 and inj_arm = '1' then
                  pl(0) := not pl(0);
                  inj_arm <= '0';
                end if;
                o_pl <= pl; o_isd <= '1';
                if dblk /= 3 then dblk <= dblk + 1; end if;
                pend_t0 <= d_last;            -- n = 8: T0 en la ranura siguiente
              end if;
            when others =>                     -- hueco
              if pend_t0 = '1' then
                o_pl <= x"00000000000000" & term_type(0);
              else
                o_pl <= IDLE_BLOCK;
              end if;
              o_isd <= '0';
              pend_t0 <= '0';
          end case;
        end if;
      end if;
    end if;
  end process;

  blk_valid   <= o_valid;
  blk_payload <= o_pl;
  blk_is_data <= o_isd;

  ev_frame    <= r_evf;
  ev_bytes    <= r_evb;
  ev_underrun <= r_evu;

end architecture rtl;
