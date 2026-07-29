-- =============================================================================
--  immgen.vhd  -  Generador de inmediatos RV32I
--  Licencia: MIT
--
--  Extrae el inmediato de la instruccion segun el formato indicado por el
--  decoder y lo extiende con signo a 32 bits. Cada formato coloca los bits del
--  inmediato en posiciones distintas del opcode (asi lo define la ISA para
--  simplificar el hardware de decodificacion).
--
--    I : instr[31:20]                                    (12 bits, con signo)
--    S : instr[31:25] , instr[11:7]                      (12 bits, con signo)
--    B : instr[31],instr[7],instr[30:25],instr[11:8],0   (13 bits, con signo)
--    U : instr[31:12] << 12                              (sin extension)
--    J : instr[31],instr[19:12],instr[20],instr[30:21],0 (21 bits, con signo)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity immgen is
  port (
    instr : in  word_t;
    fmt   : in  imm_fmt_t;
    imm   : out word_t
  );
end entity immgen;

architecture rtl of immgen is
begin
  process(instr, fmt)
  begin
    case fmt is
      when IMM_I =>
        imm <= std_logic_vector(resize(signed(instr(31 downto 20)), XLEN));

      when IMM_S =>
        imm <= std_logic_vector(resize(
                 signed(instr(31 downto 25) & instr(11 downto 7)), XLEN));

      when IMM_B =>
        imm <= std_logic_vector(resize(signed(
                 instr(31) & instr(7) & instr(30 downto 25) &
                 instr(11 downto 8) & '0'), XLEN));

      when IMM_U =>
        imm <= instr(31 downto 12) & x"000";

      when IMM_J =>
        imm <= std_logic_vector(resize(signed(
                 instr(31) & instr(19 downto 12) & instr(20) &
                 instr(30 downto 21) & '0'), XLEN));

      when others =>  -- IMM_NONE
        imm <= (others => '0');
    end case;
  end process;
end architecture rtl;
