-- m1553_word_tx.vhd
-- Motor de transmision de palabra MIL-STD-1553B.
-- Palabra de 20 tiempos de bit: sync de 3 bits (patron Manchester invalido,
-- command/status = 1.5 alto + 1.5 bajo; data = inverso), 16 bits de dato
-- (MSB primero) y 1 bit de paridad IMPAR. Manchester II: '1' = alto->bajo,
-- '0' = bajo->alto. 1 Mbit/s fijo: 100 ciclos por bit a aclk = 100 MHz
-- (50 ciclos por semibit).
-- Encadenado sin hueco: un pulso de start durante la palabra en curso deja
-- la siguiente pendiente y se emite contigua (data words de un mensaje).
-- rst sincrono activo alto (patron heredado del SoC).

library ieee;
use ieee.std_logic_1164.all;

entity m1553_word_tx is
  generic (
    CYCLES_PER_HALFBIT : integer := 50
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;                      -- sincrono, activo alto
    start     : in  std_logic;                      -- pulso de 1 ciclo
    word_type : in  std_logic;                      -- '1' command/status, '0' data
    data      : in  std_logic_vector(15 downto 0);
    busy      : out std_logic;
    loaded    : out std_logic;                      -- pulso: palabra cargada
    tx_en     : out std_logic;
    tx_data   : out std_logic
  );
end entity m1553_word_tx;

architecture rtl of m1553_word_tx is

  signal cnt  : integer range 0 to CYCLES_PER_HALFBIT-1 := 0;
  signal hb   : integer range 0 to 39 := 0;   -- semibit actual (40 por palabra)
  signal run  : std_logic := '0';
  signal wt   : std_logic := '0';
  signal sh   : std_logic_vector(16 downto 0) := (others => '0'); -- dato & paridad
  signal lvl  : std_logic := '0';

  signal pend      : std_logic := '0';
  signal pend_wt   : std_logic := '0';
  signal pend_data : std_logic_vector(15 downto 0) := (others => '0');

  -- paridad impar: total de unos en (dato + paridad) es impar
  function odd_parity(d : std_logic_vector(15 downto 0)) return std_logic is
    variable p : std_logic := '1';
  begin
    for i in d'range loop
      p := p xor d(i);
    end loop;
    return p;
  end function;

  -- nivel del semibit nhb (0..39) para una palabra (wt, sh)
  function level_of(nhb : integer; f_wt : std_logic;
                    f_sh : std_logic_vector(16 downto 0)) return std_logic is
    variable b : std_logic;
  begin
    if nhb < 3 then
      return f_wt;                  -- sync: primera mitad
    elsif nhb < 6 then
      return not f_wt;              -- sync: segunda mitad
    else
      b := f_sh(16 - (nhb - 6) / 2); -- bits 0..15 y paridad, MSB primero
      if ((nhb - 6) mod 2) = 0 then
        return b;                   -- '1' = alto->bajo
      else
        return not b;
      end if;
    end if;
  end function;

begin

  busy    <= run or pend;
  tx_en   <= run;
  tx_data <= lvl when run = '1' else '0';

  process(clk)
    variable do_load       : boolean;
    variable consume_start : boolean;
    variable l_wt          : std_logic;
    variable l_dat         : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        run  <= '0';
        pend <= '0';
        loaded <= '0';
        cnt  <= 0;
        hb   <= 0;
        lvl  <= '0';
      else
        do_load       := false;
        consume_start := false;
        loaded        <= '0';

        if run = '0' then
          if pend = '1' then
            do_load := true; l_wt := pend_wt; l_dat := pend_data;
            pend <= '0';
          elsif start = '1' then
            do_load := true; l_wt := word_type; l_dat := data;
            consume_start := true;
          end if;
        else
          if cnt = CYCLES_PER_HALFBIT-1 then
            cnt <= 0;
            if hb = 39 then
              if pend = '1' then
                do_load := true; l_wt := pend_wt; l_dat := pend_data;
                pend <= '0';
              elsif start = '1' then
                do_load := true; l_wt := word_type; l_dat := data;
                consume_start := true;
              else
                run <= '0';
                lvl <= '0';
                hb  <= 0;
              end if;
            else
              hb  <= hb + 1;
              lvl <= level_of(hb + 1, wt, sh);
            end if;
          else
            cnt <= cnt + 1;
          end if;
        end if;

        if do_load then
          loaded <= '1';
          run <= '1';
          cnt <= 0;
          hb  <= 0;
          wt  <= l_wt;
          sh  <= l_dat & odd_parity(l_dat);
          lvl <= l_wt;               -- primer semibit del sync
        end if;

        -- captura de peticion no consumida directamente
        if start = '1' and not consume_start then
          pend      <= '1';
          pend_wt   <= word_type;
          pend_data <= data;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
