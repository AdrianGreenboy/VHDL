-- =============================================================================
--  alu.vhd  -  Unidad aritmetico-logica combinacional para RV32I
--  Licencia: MIT
--
--  El corrimiento (shamt) se toma de b[4:0], como manda la ISA tanto para
--  los shifts registro-registro (SLL/SRL/SRA) como para los inmediatos, donde
--  el datapath coloca el shamt en los bits bajos del operando B.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity alu is
  port (
    op    : in  alu_op_t;
    a     : in  word_t;
    b     : in  word_t;
    y     : out word_t;
    zero  : out std_logic   -- '1' cuando el resultado es 0 (util para debug)
  );
end entity alu;

architecture rtl of alu is
begin

  process(op, a, b)
    variable ua, ub : unsigned(XLEN-1 downto 0);
    variable sa, sb : signed(XLEN-1 downto 0);
    variable shamt  : natural range 0 to XLEN-1;
    variable res    : word_t;
  begin
    ua    := unsigned(a);
    ub    := unsigned(b);
    sa    := signed(a);
    sb    := signed(b);
    shamt := to_integer(ub(4 downto 0));
    res   := (others => '0');

    case op is
      when ALU_ADD    => res := std_logic_vector(ua + ub);
      when ALU_SUB    => res := std_logic_vector(ua - ub);
      when ALU_SLL    => res := std_logic_vector(shift_left(ua, shamt));
      when ALU_SRL    => res := std_logic_vector(shift_right(ua, shamt));
      when ALU_SRA    => res := std_logic_vector(shift_right(sa, shamt));
      when ALU_XOR    => res := a xor b;
      when ALU_OR     => res := a or b;
      when ALU_AND    => res := a and b;
      when ALU_PASS_B => res := b;

      when ALU_SLT =>                       -- set less than (con signo)
        if sa < sb then
          res := (0 => '1', others => '0');
        else
          res := (others => '0');
        end if;

      when ALU_SLTU =>                      -- set less than (sin signo)
        if ua < ub then
          res := (0 => '1', others => '0');
        else
          res := (others => '0');
        end if;
    end case;

    y <= res;
    if res = ZERO_WORD then
      zero <= '1';
    else
      zero <= '0';
    end if;
  end process;

end architecture rtl;
