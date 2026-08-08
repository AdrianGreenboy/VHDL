-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Scrambler y descrambler self-synchronizing, polinomio G(x)=1+x^39+x^58.
-- Implementacion PARALELA de 64 bits (IEEE 802.3-2008 clausula 49).
--
-- La recurrencia serie por bit (LSB primero del payload) es:
--   scrambler:   sbit = din  XOR state(38) XOR state(57)
--                state = (state << 1) | sbit
--   descrambler: dout = sin  XOR state(38) XOR state(57)
--                state = (state << 1) | sin     (realimenta el bit RECIBIDO)
--
-- La version paralela aplica esta recurrencia 64 veces de forma combinacional
-- en un ciclo, usando una variable de estado local que se propaga por el bucle,
-- y registra el estado final para el siguiente bloque. Sintetiza a un arbol de
-- XOR (self-synchronizing => 1 ciclo de latencia en paralelo).
--
-- Los 2 bits de sync header hacen BYPASS: este modulo solo procesa los 64 bits
-- de payload; el ensamblado del bloque de 66 bits es responsabilidad del nivel
-- superior.
--
-- Verificado contra pcs_scrambler_oracle.py (firma FNV32 0x37DB2E32).
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_scrambler is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;        -- reset: estado a all-ones (seed canonico)
    en     : in  std_logic;        -- procesa un bloque este ciclo
    mode   : in  std_logic;        -- '0' scramble (TX), '1' descramble (RX)
    din    : in  std_logic_vector(63 downto 0);  -- payload de entrada
    dout   : out std_logic_vector(63 downto 0);  -- payload procesado
    dvalid : out std_logic         -- dout valido (1 ciclo tras en)
  );
end entity pcs_scrambler;

architecture rtl of pcs_scrambler is
  signal state   : unsigned(57 downto 0) := (others => '1');  -- seed all-ones
  signal dout_r  : std_logic_vector(63 downto 0) := (others => '0');
  signal valid_r : std_logic := '0';
begin

  process(clk)
    variable s     : unsigned(57 downto 0);
    variable o     : std_logic_vector(63 downto 0);
    variable din_b : std_logic;   -- bit de entrada
    variable res_b : std_logic;   -- bit resultante (scrambled o descrambled)
    variable fb    : std_logic;   -- realimentacion
    variable shin  : std_logic;   -- bit que entra al shift register
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state   <= (others => '1');
        dout_r  <= (others => '0');
        valid_r <= '0';
      else
        valid_r <= en;
        if en = '1' then
          s := state;
          o := (others => '0');
          -- recurrencia paralela, LSB primero
          for i in 0 to 63 loop
            din_b := din(i);
            fb    := s(38) xor s(57);
            if mode = '0' then
              -- SCRAMBLE: salida = din xor fb; realimenta la salida
              res_b := din_b xor fb;
              shin  := res_b;
            else
              -- DESCRAMBLE: salida = din xor fb; realimenta la ENTRADA recibida
              res_b := din_b xor fb;
              shin  := din_b;
            end if;
            o(i) := res_b;
            s := (s(56 downto 0) & shin);  -- shift izquierda, shin en LSB
          end loop;
          state  <= s;
          dout_r <= o;
        end if;
      end if;
    end if;
  end process;

  dout   <= dout_r;
  dvalid <= valid_r;

end architecture rtl;
