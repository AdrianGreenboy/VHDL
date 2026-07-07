-- =============================================================================
--  tb_alu.vhd  -  Testbench autoverificable para la ALU RV32I
--  Licencia: MIT
--
--  Correr con GHDL:
--    ghdl -a --std=08 rtl/riscv_pkg.vhd rtl/alu.vhd sim/tb_alu.vhd
--    ghdl -e --std=08 tb_alu
--    ghdl -r --std=08 tb_alu
--
--  Correr con xsim (Vivado):
--    xvhdl -2008 rtl/riscv_pkg.vhd rtl/alu.vhd sim/tb_alu.vhd
--    xelab tb_alu -s tb_alu_sim
--    xsim tb_alu_sim -runall
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_alu is
end entity tb_alu;

architecture sim of tb_alu is
  signal op   : alu_op_t := ALU_ADD;
  signal a, b : word_t   := (others => '0');
  signal y    : word_t;
  signal zero : std_logic;

  signal errors : natural := 0;

  -- helper: aplica estimulos, espera a que la logica combinacional se asiente
  -- y compara contra el valor esperado.
  procedure check (
    signal   op_s : out alu_op_t;
    signal   a_s  : out word_t;
    signal   b_s  : out word_t;
    signal   y_s  : in  word_t;
    signal   err  : inout natural;
    constant o    : in  alu_op_t;
    constant av   : in  integer;
    constant bv   : in  integer;
    constant exp  : in  integer;
    constant name : in  string
  ) is
  begin
    op_s <= o;
    a_s  <= std_logic_vector(to_signed(av, XLEN));
    b_s  <= std_logic_vector(to_signed(bv, XLEN));
    wait for 10 ns;
    if y_s /= std_logic_vector(to_signed(exp, XLEN)) then
      report "FAIL " & name &
             " : got " & integer'image(to_integer(signed(y_s))) &
             " expected " & integer'image(exp)
        severity error;
      err <= err + 1;
    else
      report "PASS " & name severity note;
    end if;
  end procedure;

begin

  dut : entity work.alu
    port map (op => op, a => a, b => b, y => y, zero => zero);

  stim : process
  begin
    -- Aritmetica
    check(op, a, b, y, errors, ALU_ADD,   7,   5,   12, "ADD 7+5");
    check(op, a, b, y, errors, ALU_ADD,  -3,   1,   -2, "ADD -3+1");
    check(op, a, b, y, errors, ALU_SUB,  10,   4,    6, "SUB 10-4");
    check(op, a, b, y, errors, ALU_SUB,   4,  10,   -6, "SUB 4-10");

    -- Logica
    check(op, a, b, y, errors, ALU_XOR,  16#F0F0#, 16#0FF0#, 16#FF00#, "XOR");
    check(op, a, b, y, errors, ALU_OR,   16#00F0#, 16#0F00#, 16#0FF0#, "OR");
    check(op, a, b, y, errors, ALU_AND,  16#0FF0#, 16#00FF#, 16#00F0#, "AND");

    -- Corrimientos (shamt = b[4:0])
    check(op, a, b, y, errors, ALU_SLL,  1,   4,   16, "SLL 1<<4");
    check(op, a, b, y, errors, ALU_SRL,  256, 2,   64, "SRL 256>>2");
    check(op, a, b, y, errors, ALU_SRA,  -8,  1,   -4, "SRA -8>>>1");

    -- Comparaciones set-less-than
    check(op, a, b, y, errors, ALU_SLT,  -1,  1,    1, "SLT -1<1 signed");
    check(op, a, b, y, errors, ALU_SLT,   5,  5,    0, "SLT 5<5");
    check(op, a, b, y, errors, ALU_SLTU, 3,   4,    1, "SLTU 3<4");

    -- Pass-B (LUI)
    check(op, a, b, y, errors, ALU_PASS_B, 0, 16#12345#, 16#12345#, "PASS_B");

    report "-----------------------------------------";
    if errors = 0 then
      report "TODOS LOS TESTS DE LA ALU PASARON" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;   -- detiene la simulacion limpiamente
  end process;

end architecture sim;
