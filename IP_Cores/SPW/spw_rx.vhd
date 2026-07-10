-- ============================================================================
-- spw_rx.vhd -- Motor receptor SpaceWire (ECSS-E-ST-50-12C)
-- ============================================================================
-- Entrada Data-Strobe cruda (din/sin) sincronizada con 2FF; cada nuevo bit se
-- detecta como cambio de (D xor S) y su valor es D. Sin reloj recuperado
-- fisico: todo sincrono a clk (100 MHz). Tasa maxima fiable: 50 Mbit/s.
--
-- Sincronizacion inicial: caza del patron del primer NULL "01110100"
-- (P0 ESC(111) P0 FCT(100)). A partir de ahi decodificacion alineada:
--   P, F, y 2 bits (L-Char) u 8 bits (N-Char, LSB primero).
-- Paridad IMPAR encadenada: acc(payload previo) xor P xor F = '1'.
-- ESC+FCT = NULL (got_null), ESC+dato = Time-Code (got_time),
-- ESC+{ESC,EOP,EEP} = error de escape.
--
-- Deteccion de desconexion: tras el primer NULL, si no llega ninguna
-- transicion en DISC_CYCLES ciclos (850 ns a 100 MHz) -> err_disc.
-- Inactiva antes del primer NULL y en HALT (ECSS 8.5.3.7.2).
--
-- Tras cualquier error el receptor queda en HALT hasta que rxen baje
-- (la FSM del enlace pasa por ErrorReset y lo rearma).
--
-- rx_data/rx_we: mismo formato de 9 bits que el TX
--   b8='0' dato d7..d0; b8='1' -> b0='0' EOP, b0='1' EEP.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spw_rx is
  generic (
    DISC_CYCLES : integer := 85
  );
  port (
    clk        : in  std_logic;
    arstn      : in  std_logic;
    en         : in  std_logic;
    rxen       : in  std_logic;
    din        : in  std_logic;
    sin        : in  std_logic;
    -- eventos decodificados (pulsos de 1 ciclo)
    first_null : out std_logic;                     -- nivel pegajoso
    got_null   : out std_logic;
    got_fct    : out std_logic;
    got_time   : out std_logic;
    time_out   : out std_logic_vector(7 downto 0);
    rx_we      : out std_logic;
    rx_data    : out std_logic_vector(8 downto 0);
    -- errores (pulsos de 1 ciclo)
    err_par    : out std_logic;
    err_esc    : out std_logic;
    err_disc   : out std_logic
  );
end entity spw_rx;

architecture rtl of spw_rx is

  type st_t is (HUNT, GETP, GETF, PAY2, PAY8, HALT);

  signal d1, d2, s1, s2 : std_logic := '0';
  signal xprev          : std_logic := '0';
  signal st             : st_t      := HUNT;
  signal sh             : std_logic_vector(7 downto 0) := (others => '0');
  signal acc            : std_logic := '0';
  signal pbit           : std_logic := '0';
  signal escf           : std_logic := '0';
  signal b1r            : std_logic := '0';
  signal payidx         : unsigned(2 downto 0) := (others => '0');
  signal pay            : std_logic_vector(7 downto 0) := (others => '0');
  signal fnull          : std_logic := '0';
  signal dcnt           : integer range 0 to DISC_CYCLES := 0;

begin

  first_null <= fnull;

  main : process (clk, arstn)
    variable v_new  : boolean;
    variable v_b    : std_logic;
    variable v_sh   : std_logic_vector(7 downto 0);
    variable v_byte : std_logic_vector(7 downto 0);
  begin
    if arstn = '0' then
      d1 <= '0'; d2 <= '0'; s1 <= '0'; s2 <= '0';
      xprev  <= '0';
      st     <= HUNT;
      sh     <= (others => '0');
      acc    <= '0';
      pbit   <= '0';
      escf   <= '0';
      b1r    <= '0';
      payidx <= (others => '0');
      pay    <= (others => '0');
      fnull  <= '0';
      dcnt   <= 0;
      got_null <= '0'; got_fct <= '0'; got_time <= '0';
      rx_we    <= '0'; err_par <= '0'; err_esc <= '0'; err_disc <= '0';
      time_out <= (others => '0');
      rx_data  <= (others => '0');
    elsif rising_edge(clk) then
      -- sincronizador 2FF siempre en marcha (leccion: eventos llegan 2-3 clk tarde)
      d1 <= din; d2 <= d1;
      s1 <= sin; s2 <= s1;
      xprev <= d2 xor s2;

      -- pulsos por defecto a cero
      got_null <= '0'; got_fct <= '0'; got_time <= '0';
      rx_we    <= '0'; err_par <= '0'; err_esc <= '0'; err_disc <= '0';

      if en = '0' or rxen = '0' then
        st     <= HUNT;
        sh     <= (others => '0');
        acc    <= '0';
        escf   <= '0';
        fnull  <= '0';
        dcnt   <= 0;
        payidx <= (others => '0');
      else
        v_new := ((d2 xor s2) /= xprev);
        v_b   := d2;

        -- desconexion: activa tras el primer NULL y fuera de HALT
        if fnull = '1' and st /= HALT then
          if v_new then
            dcnt <= 0;
          elsif dcnt = DISC_CYCLES - 1 then
            err_disc <= '1';
            st       <= HALT;
            dcnt     <= 0;
          else
            dcnt <= dcnt + 1;
          end if;
        else
          dcnt <= 0;
        end if;

        if v_new then
          case st is

            when HUNT =>
              v_sh := sh(6 downto 0) & v_b;
              sh   <= v_sh;
              if v_sh = "01110100" then
                st       <= GETP;
                acc      <= '0';        -- payload del FCT del NULL = "00"
                escf     <= '0';
                fnull    <= '1';
                got_null <= '1';
              end if;

            when GETP =>
              pbit <= v_b;
              st   <= GETF;

            when GETF =>
              if (acc xor pbit xor v_b) /= '1' then
                err_par <= '1';
                st      <= HALT;
              else
                acc    <= '0';
                payidx <= (others => '0');
                if v_b = '1' then
                  st <= PAY2;
                else
                  st <= PAY8;
                end if;
              end if;

            when PAY2 =>
              if payidx = 0 then
                b1r    <= v_b;
                payidx <= to_unsigned(1, 3);
              else
                acc <= b1r xor v_b;
                st  <= GETP;
                if b1r = '0' and v_b = '0' then          -- FCT
                  if escf = '1' then
                    escf     <= '0';
                    got_null <= '1';                     -- NULL = ESC+FCT
                  else
                    got_fct <= '1';
                  end if;
                elsif b1r = '0' and v_b = '1' then       -- EOP
                  if escf = '1' then
                    err_esc <= '1';
                    st      <= HALT;
                  else
                    rx_we   <= '1';
                    rx_data <= "100000000";
                  end if;
                elsif b1r = '1' and v_b = '0' then       -- EEP
                  if escf = '1' then
                    err_esc <= '1';
                    st      <= HALT;
                  else
                    rx_we   <= '1';
                    rx_data <= "100000001";
                  end if;
                else                                     -- ESC
                  if escf = '1' then
                    err_esc <= '1';
                    st      <= HALT;
                  else
                    escf <= '1';
                  end if;
                end if;
              end if;

            when PAY8 =>
              pay(to_integer(payidx)) <= v_b;
              acc <= acc xor v_b;
              if payidx = 7 then
                v_byte    := pay;
                v_byte(7) := v_b;
                st        <= GETP;
                if escf = '1' then
                  escf     <= '0';
                  got_time <= '1';
                  time_out <= v_byte;
                else
                  rx_we   <= '1';
                  rx_data <= '0' & v_byte;
                end if;
              else
                payidx <= payidx + 1;
              end if;

            when HALT =>
              null;                     -- hasta que rxen baje

          end case;
        end if;
      end if;
    end if;
  end process main;

end architecture rtl;
