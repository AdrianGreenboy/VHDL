-- =============================================================================
--  tb_muldiv.vhd  -  Testbench autoverificable de la unidad muldiv (RV32IM)
--  Licencia: MIT
--
--  Cubre: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU, division entre cero
--  y overflow -2^31 / -1.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_muldiv is
end entity tb_muldiv;

architecture sim of tb_muldiv is
  constant TCK : time := 10 ns;

  signal clk    : std_logic := '0';
  signal rst    : std_logic := '1';
  signal start  : std_logic := '0';
  signal op     : md_op_t   := MD_MUL;
  signal a, b   : word_t     := (others => '0');
  signal result : word_t;
  signal busy   : std_logic;
  signal done   : std_logic;

  signal errors : natural := 0;

  -- lanza una operacion y espera el 'done', comparando contra el esperado
  procedure run (
    signal   clk_s   : in    std_logic;
    signal   start_s : out   std_logic;
    signal   op_s    : out   md_op_t;
    signal   a_s     : out   word_t;
    signal   b_s     : out   word_t;
    signal   done_s  : in    std_logic;
    signal   res_s   : in    word_t;
    signal   err     : inout natural;
    constant o       : in    md_op_t;
    constant av      : in    word_t;
    constant bv      : in    word_t;
    constant exp     : in    word_t;
    constant name    : in    string
  ) is
  begin
    wait until rising_edge(clk_s);
    op_s <= o; a_s <= av; b_s <= bv; start_s <= '1';
    wait until rising_edge(clk_s);
    start_s <= '0';
    loop
      wait until rising_edge(clk_s);
      exit when done_s = '1';
    end loop;
    if res_s /= exp then
      report "FAIL " & name &
             " got=0x"  & to_hstring(res_s) &
             " exp=0x"  & to_hstring(exp) severity error;
      err <= err + 1;
    else
      report "PASS " & name severity note;
    end if;
  end procedure;

begin

  clk <= not clk after TCK/2;

  dut : entity work.muldiv
    port map (
      clk => clk, rst => rst, start => start,
      op => op, a => a, b => b,
      result => result, busy => busy, done => done
    );

  stim : process
  begin
    -- reset
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    -- ---------- Multiplicacion ----------
    run(clk, start, op, a, b, done, result, errors,
        MD_MUL,    x"00000006", x"00000007", x"0000002A", "MUL 6*7");
    run(clk, start, op, a, b, done, result, errors,
        MD_MUL,    x"FFFFFFFD", x"00000005", x"FFFFFFF1", "MUL -3*5 (low)");
    run(clk, start, op, a, b, done, result, errors,
        MD_MULH,   x"40000000", x"00000004", x"00000001", "MULH 2^30*4 (high)");
    run(clk, start, op, a, b, done, result, errors,
        MD_MULHU,  x"FFFFFFFF", x"FFFFFFFF", x"FFFFFFFE", "MULHU max*max (high)");
    run(clk, start, op, a, b, done, result, errors,
        MD_MULHSU, x"FFFFFFFF", x"00000002", x"FFFFFFFF", "MULHSU -1*2u (high)");

    -- ---------- Division con y sin signo ----------
    run(clk, start, op, a, b, done, result, errors,
        MD_DIV,    x"00000014", x"00000003", x"00000006", "DIV 20/3");
    run(clk, start, op, a, b, done, result, errors,
        MD_DIV,    x"FFFFFFEC", x"00000003", x"FFFFFFFA", "DIV -20/3 = -6");
    run(clk, start, op, a, b, done, result, errors,
        MD_DIVU,   x"00000014", x"00000003", x"00000006", "DIVU 20/3");
    run(clk, start, op, a, b, done, result, errors,
        MD_REM,    x"00000014", x"00000003", x"00000002", "REM 20%3 = 2");
    run(clk, start, op, a, b, done, result, errors,
        MD_REM,    x"FFFFFFEC", x"00000003", x"FFFFFFFE", "REM -20%3 = -2");
    run(clk, start, op, a, b, done, result, errors,
        MD_REMU,   x"00000014", x"00000003", x"00000002", "REMU 20%3 = 2");

    -- ---------- Casos especiales ----------
    run(clk, start, op, a, b, done, result, errors,
        MD_DIV,    x"00000007", x"00000000", x"FFFFFFFF", "DIV 7/0 = -1");
    run(clk, start, op, a, b, done, result, errors,
        MD_REM,    x"00000007", x"00000000", x"00000007", "REM 7/0 = 7");
    run(clk, start, op, a, b, done, result, errors,
        MD_DIV,    x"80000000", x"FFFFFFFF", x"80000000", "DIV overflow");
    run(clk, start, op, a, b, done, result, errors,
        MD_REM,    x"80000000", x"FFFFFFFF", x"00000000", "REM overflow");

    -- resumen
    report "-----------------------------------------";
    if errors = 0 then
      report "TODOS LOS TESTS DE MULDIV PASARON" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;   -- detiene la simulacion (el reloj es de vida libre)
  end process;

end architecture sim;
