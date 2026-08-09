-- =============================================================================
--  muldiv.vhd  -  Unidad de multiplicacion/division para la extension M (RV32IM)
--  Licencia: MIT
--
--  Interfaz con handshake:
--    - 'start' : pulso de 1 ciclo que engancha op/a/b e inicia la operacion.
--    - 'busy'  : alto mientras la unidad trabaja (el pipeline hace stall).
--    - 'done'  : pulso de 1 ciclo; 'result' es valido en ese ciclo y se mantiene.
--
--  Multiplicacion: un multiplicador 33x33 con signo -> el synthesizer lo mapea
--  a DSP58. Latencia 2 ciclos (enganche + resultado).
--
--  Division: restauradora, 1 bit por ciclo (~34 ciclos). Se opera sobre
--  magnitudes y se corrige el signo al final. Casos especiales segun la spec:
--    - divisor = 0:  DIV/DIVU -> todos unos (-1);  REM/REMU -> dividendo.
--    - overflow -2^31 / -1:  DIV -> -2^31;  REM -> 0.
--  El signo del residuo sigue al del dividendo; el del cociente es el XOR.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity muldiv is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;   -- reset sincrono, activo alto
    start  : in  std_logic;   -- pulso de 1 ciclo para iniciar
    op     : in  md_op_t;
    a      : in  word_t;      -- rs1
    b      : in  word_t;      -- rs2
    result : out word_t;
    busy   : out std_logic;
    done   : out std_logic
  );
end entity muldiv;

architecture rtl of muldiv is

  type state_t is (S_IDLE, S_MUL, S_DIV);
  signal state : state_t := S_IDLE;

  -- operandos y control enganchados
  signal op_r : md_op_t;
  signal a_r  : word_t;

  -- multiplicacion (producto de 66 bits con signo)
  signal prod : signed(65 downto 0);

  -- division (sobre magnitudes)
  signal rem_r : unsigned(32 downto 0);
  signal quo_r : unsigned(31 downto 0);
  signal div_r : unsigned(31 downto 0);   -- |divisor|
  signal cnt   : integer range 0 to 32;
  signal q_neg : std_logic;               -- negar cociente al final
  signal r_neg : std_logic;               -- negar residuo al final
  signal div0  : std_logic;               -- divisor == 0
  signal ovf   : std_logic;               -- overflow -2^31 / -1

  signal result_r : word_t := (others => '0');
begin

  busy   <= '0' when state = S_IDLE else '1';
  result <= result_r;

  process(clk)
    variable rem_v         : unsigned(32 downto 0);
    variable quo_v         : unsigned(31 downto 0);
    variable a_ext, b_ext  : signed(32 downto 0);
    variable mag_a, mag_b  : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      done <= '0';

      if rst = '1' then
        state <= S_IDLE;
      else
        case state is

          -------------------------------------------------------------------
          when S_IDLE =>
            if start = '1' then
              op_r <= op;
              a_r  <= a;

              case op is
                -- ---------- MULTIPLICACION ----------
                when MD_MUL | MD_MULH | MD_MULHSU | MD_MULHU =>
                  case op is
                    when MD_MULH =>                 -- signed x signed
                      a_ext := resize(signed(a), 33);
                      b_ext := resize(signed(b), 33);
                    when MD_MULHSU =>               -- signed x unsigned
                      a_ext := resize(signed(a), 33);
                      b_ext := signed('0' & b);
                    when MD_MULHU =>                -- unsigned x unsigned
                      a_ext := signed('0' & a);
                      b_ext := signed('0' & b);
                    when others =>                  -- MD_MUL: bits bajos
                      a_ext := resize(signed(a), 33);
                      b_ext := resize(signed(b), 33);
                  end case;
                  prod  <= a_ext * b_ext;
                  state <= S_MUL;

                -- ---------- DIVISION ----------
                when others =>  -- MD_DIV / MD_DIVU / MD_REM / MD_REMU
                  if b = ZERO_WORD then div0 <= '1'; else div0 <= '0'; end if;

                  if op = MD_DIV or op = MD_REM then
                    -- variantes con signo
                    if a = x"80000000" and b = x"FFFFFFFF" then
                      ovf <= '1';
                    else
                      ovf <= '0';
                    end if;
                    q_neg <= a(31) xor b(31);
                    r_neg <= a(31);
                    if a(31) = '1' then mag_a := unsigned(not a) + 1;
                    else                mag_a := unsigned(a); end if;
                    if b(31) = '1' then mag_b := unsigned(not b) + 1;
                    else                mag_b := unsigned(b); end if;
                  else
                    -- variantes sin signo
                    ovf   <= '0';
                    q_neg <= '0';
                    r_neg <= '0';
                    mag_a := unsigned(a);
                    mag_b := unsigned(b);
                  end if;

                  rem_r <= (others => '0');
                  quo_r <= mag_a;
                  div_r <= mag_b;
                  cnt   <= 32;
                  state <= S_DIV;
              end case;
            end if;

          -------------------------------------------------------------------
          when S_MUL =>
            if op_r = MD_MUL then
              result_r <= std_logic_vector(prod(31 downto 0));       -- bits bajos
            else
              result_r <= std_logic_vector(prod(63 downto 32));      -- bits altos
            end if;
            done  <= '1';
            state <= S_IDLE;

          -------------------------------------------------------------------
          when S_DIV =>
            if cnt = 0 then
              -- casos especiales primero (tienen prioridad)
              if div0 = '1' then
                if op_r = MD_DIV or op_r = MD_DIVU then
                  result_r <= (others => '1');      -- -1 / 0xFFFFFFFF
                else
                  result_r <= a_r;                  -- REM/REMU -> dividendo
                end if;
              elsif ovf = '1' then
                if op_r = MD_DIV then
                  result_r <= x"80000000";
                else
                  result_r <= (others => '0');      -- MD_REM
                end if;
              else
                if op_r = MD_DIV or op_r = MD_DIVU then
                  if q_neg = '1' then
                    result_r <= std_logic_vector((not quo_r) + 1);
                  else
                    result_r <= std_logic_vector(quo_r);
                  end if;
                else  -- REM / REMU
                  if r_neg = '1' then
                    result_r <= std_logic_vector((not rem_r(31 downto 0)) + 1);
                  else
                    result_r <= std_logic_vector(rem_r(31 downto 0));
                  end if;
                end if;
              end if;
              done  <= '1';
              state <= S_IDLE;
            else
              -- una iteracion de division restauradora
              rem_v := rem_r(31 downto 0) & quo_r(31);   -- rem << 1 | bit del dividendo
              quo_v := quo_r(30 downto 0) & '0';         -- quo << 1
              if rem_v >= ('0' & div_r) then
                rem_v := rem_v - ('0' & div_r);
                quo_v(0) := '1';
              end if;
              rem_r <= rem_v;
              quo_r <= quo_v;
              cnt   <= cnt - 1;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
