-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- MAC RX: bloques 64B/66B (payload + is_data) del PCS -> AXIS 64b.
--
-- Sin backpressure: el PCS entrega como mucho un bloque por ciclo (32/33 con
-- el gearbox) y cada etapa procesa un token por ciclo.
--
--   R1 decode : clasifica el bloque (I, S, S con preambulo malo, D, Tn, E, U)
--   R2 framer : ensambla palabras con 1 palabra retenida (para marcar 'last'
--               en T0 y para abortos); detecta errores de protocolo
--   R3 crc    : CRC acumulado (incluye FCS), longitud, decision de filtro
--   R4 crc_n  : las 8 variantes del CRC de la ultima palabra, registradas
--   R4b       : comparacion de cada variante con el residuo (8 bits)
--   R5 class  : residuo 0xDEBB20E3, runt (<64), oversize (>1522), aborto;
--               un unico contador por trama con prioridad
--               aborto > runt > oversize > crc
--   R6 strip  : retira los 4 bytes de FCS (1 palabra retenida)
--   R7 out    : AXIS registrado (dato enmascarado, tkeep, tlast, tuser=1 en
--               la ultima palabra si la trama es mala)
--
-- Limitaciones v1: no se comprueban los caracteres de control dentro de los
-- bloques Tn/idle, y los sync headers invalidos (00/11) no son visibles (el RX
-- del Core 19 trata todo lo que no es "01" como control).
--
-- Filtro: unicast propio, broadcast, o todo con 'promisc'. Las tramas
-- filtradas no se entregan y solo cuentan como rx_filtered.
-- Las tramas sin ninguna palabra (S seguido de T0 o de un aborto) cuentan como
-- runt/aborto sin pasar por el filtro (no hay destino que mirar).
-- /S/ en carril 4 (0x33/0x66) y ordered sets: no soportados en v1 -> rx_proto
-- (y aborto si llegan a mitad de trama).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac25g_pkg.all;

entity mac25g_rx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    in_valid   : in  std_logic;
    in_payload : in  std_logic_vector(63 downto 0);
    in_is_data : in  std_logic;

    own_mac    : in  std_logic_vector(47 downto 0);
    promisc    : in  std_logic;

    m_tdata    : out std_logic_vector(63 downto 0);
    m_tkeep    : out std_logic_vector(7 downto 0);
    m_tlast    : out std_logic;
    m_tuser    : out std_logic;    -- 1 en tlast: trama erronea
    m_tvalid   : out std_logic;

    -- eventos (pulsos de 1 ciclo)
    ev_ok      : out std_logic;
    ev_bytes   : out unsigned(15 downto 0);
    ev_crc     : out std_logic;
    ev_runt    : out std_logic;    -- puede valer 1 por dos fuentes: ver ev_runt0
    ev_runt0   : out std_logic;    -- runt sin palabras (S + T0)
    ev_over    : out std_logic;
    ev_abort   : out std_logic;
    ev_abort0  : out std_logic;    -- aborto sin palabras
    ev_filt    : out std_logic;
    ev_proto   : out std_logic;
    link_up    : out std_logic
  );
end entity mac25g_rx;

architecture rtl of mac25g_rx is
  subtype kind_t is std_logic_vector(2 downto 0);
  constant K_I  : kind_t := "000";
  constant K_S  : kind_t := "001";
  constant K_SB : kind_t := "010";
  constant K_D  : kind_t := "011";
  constant K_T  : kind_t := "100";
  constant K_E  : kind_t := "101";
  constant K_U  : kind_t := "110";

  -- R1
  signal r1_v    : std_logic := '0';
  signal r1_k    : kind_t := K_I;
  signal r1_d    : std_logic_vector(63 downto 0) := (others => '0');
  signal r1_n    : unsigned(3 downto 0) := (others => '0');
  -- R2
  signal in_frame, first : std_logic := '0';
  signal h_v, h_sof, h_lp : std_logic := '0';
  signal h_d     : std_logic_vector(63 downto 0) := (others => '0');
  signal h_n     : unsigned(3 downto 0) := (others => '0');
  signal r2_v, r2_last, r2_ab, r2_sof : std_logic := '0';
  signal r2_d    : std_logic_vector(63 downto 0) := (others => '0');
  signal r2_n    : unsigned(3 downto 0) := (others => '0');
  signal p_proto, p_r0, p_a0 : std_logic := '0';
  signal lnk_cnt : unsigned(6 downto 0) := (others => '0');
  signal lnk     : std_logic := '0';
  -- R3
  signal crc_acc : std_logic_vector(31 downto 0) := CRC_INIT;
  signal cnt     : unsigned(15 downto 0) := (others => '0');
  signal acc_r   : std_logic := '0';
  signal r3_v, r3_last, r3_ab, r3_acc : std_logic := '0';
  signal r3_d    : std_logic_vector(63 downto 0) := (others => '0');
  signal r3_n    : unsigned(3 downto 0) := (others => '0');
  signal r3_crc  : std_logic_vector(31 downto 0) := (others => '0');
  signal r3_len  : unsigned(15 downto 0) := (others => '0');
  -- R4 (variantes)
  signal rv_v, rv_last, rv_ab, rv_acc : std_logic := '0';
  signal rv_d    : std_logic_vector(63 downto 0) := (others => '0');
  signal rv_n    : unsigned(3 downto 0) := (others => '0');
  signal rv_var  : crc_var_t := (others => (others => '0'));
  signal rv_len  : unsigned(15 downto 0) := (others => '0');
  -- R4b (residuo por variante)
  signal r4_v, r4_last, r4_ab, r4_acc : std_logic := '0';
  signal r4_d    : std_logic_vector(63 downto 0) := (others => '0');
  signal r4_n    : unsigned(3 downto 0) := (others => '0');
  signal r4_eq   : std_logic_vector(8 downto 1) := (others => '0');
  signal r4_len  : unsigned(15 downto 0) := (others => '0');
  -- R5
  signal r5_v, r5_last, r5_ab, r5_acc, r5_err : std_logic := '0';
  signal r5_d    : std_logic_vector(63 downto 0) := (others => '0');
  signal r5_n    : unsigned(3 downto 0) := (others => '0');
  signal e_ok, e_crc, e_runt, e_over, e_abort, e_filt : std_logic := '0';
  signal e_bytes : unsigned(15 downto 0) := (others => '0');
  -- R6
  signal g_v, g_last, g_err : std_logic := '0';
  signal g_d     : std_logic_vector(63 downto 0) := (others => '0');
  signal g_n     : unsigned(3 downto 0) := (others => '0');
  signal o_v, o_last, o_user : std_logic := '0';
  signal o_d     : std_logic_vector(63 downto 0) := (others => '0');
  signal o_n     : unsigned(3 downto 0) := (others => '0');
  -- R7
  signal q_v, q_last, q_user : std_logic := '0';
  signal q_d     : std_logic_vector(63 downto 0) := (others => '0');
  signal q_k     : std_logic_vector(7 downto 0) := (others => '0');
begin

  -----------------------------------------------------------------------------
  -- R1: clasificacion de bloque
  -----------------------------------------------------------------------------
  process(clk)
    variable bt : std_logic_vector(7 downto 0);
    variable n  : unsigned(3 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        r1_v <= '0'; r1_k <= K_I;
      else
        r1_v <= in_valid;
        if in_valid = '1' then
          bt := in_payload(7 downto 0);
          r1_d <= in_payload;
          r1_n <= to_unsigned(8, 4);
          if in_is_data = '1' then
            r1_k <= K_D;
          else
            n := (others => '0');
            case bt is
              when x"1E" =>
                if in_payload(63 downto 8) = x"00000000000000" then r1_k <= K_I;
                else r1_k <= K_E; end if;
              when x"78" =>
                if in_payload = START_BLOCK then r1_k <= K_S; else r1_k <= K_SB; end if;
              when x"87" => r1_k <= K_T; n := to_unsigned(0, 4);
              when x"99" => r1_k <= K_T; n := to_unsigned(1, 4);
              when x"AA" => r1_k <= K_T; n := to_unsigned(2, 4);
              when x"B4" => r1_k <= K_T; n := to_unsigned(3, 4);
              when x"CC" => r1_k <= K_T; n := to_unsigned(4, 4);
              when x"D2" => r1_k <= K_T; n := to_unsigned(5, 4);
              when x"E1" => r1_k <= K_T; n := to_unsigned(6, 4);
              when x"FF" => r1_k <= K_T; n := to_unsigned(7, 4);
              when x"33" | x"66" | x"4B" | x"55" | x"2D" => r1_k <= K_U;
              when others => r1_k <= K_E;
            end case;
            -- datos de Tn: bytes 1..n del bloque, alineados a byte 0
            r1_d <= (x"00" & in_payload(63 downto 8)) and byte_mask(n);
            r1_n <= n;
          end if;
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- R2: framer con una palabra retenida
  -----------------------------------------------------------------------------
  process(clk)
    variable bad : boolean;
  begin
    if rising_edge(clk) then
      r2_v <= '0'; r2_last <= '0'; r2_ab <= '0'; r2_sof <= '0';
      p_proto <= '0'; p_r0 <= '0'; p_a0 <= '0';
      if rst = '1' then
        in_frame <= '0'; first <= '0'; h_v <= '0'; h_lp <= '0';
        lnk_cnt <= (others => '0'); lnk <= '0';
      else
        -- vaciado de la palabra final pendiente (trama terminada con Tn, n>0)
        if h_v = '1' and h_lp = '1' then
          r2_v <= '1'; r2_d <= h_d; r2_n <= h_n; r2_last <= '1';
          r2_sof <= h_sof;
          h_v <= '0'; h_lp <= '0';
        end if;

        if r1_v = '1' then
          bad := false;
          if in_frame = '0' then
            case r1_k is
              when K_S  => in_frame <= '1'; first <= '1';
              when K_I  => null;
              when others => p_proto <= '1'; bad := true;   -- SB, D, T, E, U
            end case;
          else
            case r1_k is
              when K_D =>
                if h_v = '1' then
                  r2_v <= '1'; r2_d <= h_d; r2_n <= h_n; r2_sof <= h_sof;
                end if;
                h_v <= '1'; h_d <= r1_d; h_n <= to_unsigned(8, 4);
                h_sof <= first; h_lp <= '0'; first <= '0';
              when K_T =>
                in_frame <= '0';
                if r1_n = 0 then
                  if h_v = '1' then
                    r2_v <= '1'; r2_d <= h_d; r2_n <= h_n; r2_sof <= h_sof;
                    r2_last <= '1'; h_v <= '0';
                  else
                    p_r0 <= '1';
                  end if;
                else
                  if h_v = '1' then
                    r2_v <= '1'; r2_d <= h_d; r2_n <= h_n; r2_sof <= h_sof;
                  end if;
                  h_v <= '1'; h_d <= r1_d; h_n <= r1_n; h_sof <= first;
                  h_lp <= '1'; first <= '0';
                end if;
              when others =>
                -- aborto: I, S, SB, E, U a mitad de trama
                if h_v = '1' then
                  r2_v <= '1'; r2_d <= h_d; r2_n <= h_n; r2_sof <= h_sof;
                  r2_last <= '1'; r2_ab <= '1'; h_v <= '0';
                else
                  p_a0 <= '1';
                end if;
                if r1_k = K_S then
                  in_frame <= '1'; first <= '1';
                else
                  in_frame <= '0';
                end if;
                if r1_k = K_SB or r1_k = K_U then
                  p_proto <= '1'; bad := true;
                end if;
                if r1_k = K_E then bad := true; end if;
            end case;
          end if;
          -- link: 64 bloques seguidos sin error de protocolo (el 64o lo sube)
          if bad then
            lnk_cnt <= (others => '0'); lnk <= '0';
          elsif lnk_cnt = 63 then
            lnk <= '1';
          else
            lnk_cnt <= lnk_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- R3: CRC acumulado, longitud y filtro
  -----------------------------------------------------------------------------
  process(clk)
    variable v_crc : std_logic_vector(31 downto 0);
    variable v_cnt : unsigned(15 downto 0);
    variable v_acc : std_logic;
  begin
    if rising_edge(clk) then
      r3_v <= r2_v;
      if rst = '1' then
        r3_v <= '0'; crc_acc <= CRC_INIT; cnt <= (others => '0'); acc_r <= '0';
      elsif r2_v = '1' then
        -- CRC_INIT es todo unos: el reinicio en sof es un OR que se pliega
        -- en la primera capa de LUTs del arbol XOR
        v_crc := crc_acc or (31 downto 0 => r2_sof);
        if r2_sof = '1' then
          v_cnt := (others => '0');
          if promisc = '1' or r2_d(47 downto 0) = own_mac or
             r2_d(47 downto 0) = x"FFFFFFFFFFFF" then
            v_acc := '1';
          else
            v_acc := '0';
          end if;
          acc_r <= v_acc;
        else
          v_cnt := cnt; v_acc := acc_r;
        end if;
        if r2_last = '0' then
          crc_acc <= crc_upd(v_crc, r2_d, 64);
          -- saturante: una trama desbocada nunca da la vuelta y parece runt
          if v_cnt < 65520 then cnt <= v_cnt + 8; else cnt <= v_cnt; end if;
        end if;
        r3_d <= r2_d; r3_n <= r2_n; r3_last <= r2_last; r3_ab <= r2_ab;
        r3_acc <= v_acc; r3_crc <= v_crc; r3_len <= v_cnt + resize(r2_n, 16);
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- R4: las 8 variantes del CRC de la ultima palabra (ecuaciones planas)
  -----------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then rv_v <= '0'; else rv_v <= r3_v; end if;
      if r3_v = '1' then
        rv_d <= r3_d; rv_n <= r3_n; rv_last <= r3_last; rv_ab <= r3_ab;
        rv_acc <= r3_acc; rv_len <= r3_len;
        rv_var <= crc_variants(r3_crc, r3_d);
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- R4b: cada variante contra el residuo 0xDEBB20E3
  -----------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then r4_v <= '0'; else r4_v <= rv_v; end if;
      if rv_v = '1' then
        r4_d <= rv_d; r4_n <= rv_n; r4_last <= rv_last; r4_ab <= rv_ab;
        r4_acc <= rv_acc; r4_len <= rv_len;
        for k in 1 to 8 loop
          if rv_var(k) = CRC_RESIDUE then r4_eq(k) <= '1'; else r4_eq(k) <= '0'; end if;
        end loop;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- R5: clasificacion de la trama (un solo contador por trama)
  -----------------------------------------------------------------------------
  process(clk)
    variable err, crc_ok : std_logic;
  begin
    if rising_edge(clk) then
      -- eleccion de la variante con 'case' (nunca indexar con una senal)
      case to_integer(r4_n) is
        when 1 => crc_ok := r4_eq(1);  when 2 => crc_ok := r4_eq(2);
        when 3 => crc_ok := r4_eq(3);  when 4 => crc_ok := r4_eq(4);
        when 5 => crc_ok := r4_eq(5);  when 6 => crc_ok := r4_eq(6);
        when 7 => crc_ok := r4_eq(7);  when 8 => crc_ok := r4_eq(8);
        when others => crc_ok := '0';
      end case;
      e_ok <= '0'; e_crc <= '0'; e_runt <= '0'; e_over <= '0';
      e_abort <= '0'; e_filt <= '0';
      r5_v <= r4_v;
      if rst = '1' then
        r5_v <= '0';
      elsif r4_v = '1' then
        err := '0';
        if r4_last = '1' then
          if r4_acc = '0' then
            e_filt <= '1';
          elsif r4_ab = '1' then
            e_abort <= '1'; err := '1';
          elsif r4_len < MIN_FRAME then
            e_runt <= '1'; err := '1';
          elsif r4_len > MAX_FRAME then
            e_over <= '1'; err := '1';
          elsif crc_ok = '0' then
            e_crc <= '1'; err := '1';
          else
            e_ok <= '1'; e_bytes <= r4_len;
          end if;
        end if;
        r5_d <= r4_d; r5_n <= r4_n; r5_last <= r4_last; r5_ab <= r4_ab;
        r5_acc <= r4_acc; r5_err <= err;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- R6: strip de FCS (una palabra retenida) y entrega AXIS
  -----------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      o_v <= '0';
      if rst = '1' then
        g_v <= '0'; g_last <= '0';
      elsif r5_v = '1' and r5_acc = '1' then
        if r5_last = '0' then
          if g_v = '1' then
            o_v <= '1'; o_d <= g_d; o_n <= g_n; o_last <= g_last; o_user <= g_err;
          end if;
          g_v <= '1'; g_d <= r5_d; g_n <= to_unsigned(8, 4);
          g_last <= '0'; g_err <= '0';
        elsif r5_ab = '1' or r5_n > 4 then
          -- aborto (sin strip) o FCS contenido en la ultima palabra
          if g_v = '1' then
            o_v <= '1'; o_d <= g_d; o_n <= g_n; o_last <= g_last; o_user <= g_err;
          end if;
          g_v <= '1'; g_d <= r5_d; g_last <= '1'; g_err <= r5_err;
          if r5_ab = '1' then g_n <= r5_n; else g_n <= r5_n - 4; end if;
        else
          -- n <= 4: el FCS ocupa la cola de la palabra retenida
          -- pragma translate_off
          assert not (g_v = '1' and g_last = '1')
            report "mac25g_rx R6: colision de vaciado (trama de 1 palabra)"
            severity error;
          -- pragma translate_on
          o_v <= '1'; o_last <= '1'; o_user <= r5_err;
          if g_v = '1' then
            o_d <= g_d; o_n <= r5_n + 4;
          else
            o_d <= r5_d; o_n <= to_unsigned(1, 4);
          end if;
          g_v <= '0';
        end if;
      elsif g_v = '1' and g_last = '1' then
        o_v <= '1'; o_d <= g_d; o_n <= g_n; o_last <= '1'; o_user <= g_err;
        g_v <= '0';
      end if;
    end if;
  end process;

  -- R7: salida AXIS totalmente registrada (corta el camino hacia el checker)
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        q_v <= '0';
      else
        q_v <= o_v;
        if o_v = '1' then
          q_d <= o_d and byte_mask(o_n);
          q_k <= n_to_keep(o_n);
          q_last <= o_last; q_user <= o_user;
        end if;
      end if;
    end if;
  end process;

  m_tvalid <= q_v;
  m_tdata  <= q_d;
  m_tkeep  <= q_k;
  m_tlast  <= q_last;
  m_tuser  <= q_user;

  ev_ok     <= e_ok;
  ev_bytes  <= e_bytes;
  ev_crc    <= e_crc;
  ev_runt   <= e_runt;
  ev_runt0  <= p_r0;
  ev_over   <= e_over;
  ev_abort  <= e_abort;
  ev_abort0 <= p_a0;
  ev_filt   <= e_filt;
  ev_proto  <= p_proto;
  link_up   <= lnk;

end architecture rtl;
