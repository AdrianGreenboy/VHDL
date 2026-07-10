-- m1553_word_rx.vhd
-- Motor de recepcion de palabra MIL-STD-1553B.
-- Entrada por sincronizador 2FF. Cazador de sync por longitud de rafaga:
-- dentro de los bits Manchester ninguna rafaga de nivel supera 100 ciclos
-- (a 100 MHz, 1 Mbit/s), pero la semimitad de un sync dura 150; una rafaga
-- de RUN_MIN..RUN_MAX ciclos terminada en flanco marca el CENTRO del sync y
-- el nivel previo al flanco da el tipo ('1' = command/status, '0' = data).
-- Las data words contiguas funden su primera mitad con el semibit anterior
-- (rafaga <= 200, dentro de ventana); una data word aislada desde reposo
-- funde con el idle (rafaga > RUN_MAX) y se ignora, como manda el estandar.
-- Tras el centro: verifica la segunda mitad del sync (muestras a +25/+75/+125),
-- muestrea 17 celdas a cuarto de semibit (s0 en ph=25, s1 en ph=75; s0 /= s1
-- o error Manchester) y comprueba paridad IMPAR. Pulsos de 1 ciclo:
-- valid / err_sync / err_manch / err_par. rst sincrono activo alto.

library ieee;
use ieee.std_logic_1164.all;

entity m1553_word_rx is
  generic (
    RUN_MIN : integer := 125;
    RUN_MAX : integer := 375
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;                      -- sincrono, activo alto
    rx_data   : in  std_logic;
    valid     : out std_logic;                      -- pulso: palabra buena
    word_type : out std_logic;                      -- '1' command/status
    data      : out std_logic_vector(15 downto 0);
    err_sync  : out std_logic;                      -- pulsos de error
    err_manch : out std_logic;
    err_par   : out std_logic;
    busy      : out std_logic
  );
end entity m1553_word_rx;

architecture rtl of m1553_word_rx is

  type t_st is (HUNT, SYNC2, BITS);
  signal st : t_st := HUNT;

  signal q1, q2, qp : std_logic := '0';             -- 2FF + previo
  signal run  : integer range 0 to 1023 := 0;      -- rafaga del nivel actual
  signal cnt  : integer range 0 to 150  := 0;      -- fase en SYNC2
  signal ph   : integer range 0 to 99   := 0;      -- fase dentro de la celda
  signal bi   : integer range 0 to 16   := 0;      -- indice de celda (0..16)
  signal wt_i : std_logic := '0';
  signal s0_r : std_logic := '0';
  signal par  : std_logic := '0';
  signal sh   : std_logic_vector(16 downto 0) := (others => '0');

begin

  busy <= '0' when st = HUNT else '1';

  process(clk)
    variable edge : boolean;
    variable v_sh : std_logic_vector(16 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st  <= HUNT;
        q1  <= '0'; q2 <= '0'; qp <= '0';
        run <= 0;
        valid <= '0'; err_sync <= '0'; err_manch <= '0'; err_par <= '0';
      else
        q1 <= rx_data;
        q2 <= q1;
        qp <= q2;

        valid     <= '0';
        err_sync  <= '0';
        err_manch <= '0';
        err_par   <= '0';

        edge := (q2 /= qp);

        -- medida de rafaga continua (saturada)
        if edge then
          run <= 1;
        elsif run < 1023 then
          run <= run + 1;
        end if;

        case st is

          when HUNT =>
            if edge and run >= RUN_MIN and run <= RUN_MAX then
              wt_i <= qp;             -- nivel ANTES del flanco central
              st   <= SYNC2;
              cnt  <= 1;
              par  <= '0';
            end if;

          when SYNC2 =>
            -- segunda mitad del sync: debe valer (not wt_i)
            if cnt = 25 or cnt = 75 or cnt = 125 then
              if q2 = wt_i then
                err_sync <= '1';
                st <= HUNT;
              end if;
            end if;
            if cnt = 149 then
              st <= BITS;
              ph <= 0;
              bi <= 0;
            else
              cnt <= cnt + 1;
            end if;

          when BITS =>
            if ph = 25 then
              s0_r <= q2;
              par  <= par xor q2;
            elsif ph = 75 then
              if q2 = s0_r then
                err_manch <= '1';
                st <= HUNT;
              else
                v_sh := sh(15 downto 0) & s0_r;
                sh   <= v_sh;
                if bi = 16 then
                  if par = '1' then
                    valid     <= '1';
                    word_type <= wt_i;
                    data      <= v_sh(16 downto 1);
                  else
                    err_par <= '1';
                  end if;
                  st <= HUNT;
                end if;
              end if;
            end if;
            if ph = 99 then
              ph <= 0;
              if bi < 16 then
                bi <= bi + 1;
              end if;
            else
              ph <= ph + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
