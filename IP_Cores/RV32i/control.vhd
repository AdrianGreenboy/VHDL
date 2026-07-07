-- =============================================================================
--  control.vhd  -  Decoder / unidad de control RV32IM
--  Licencia: MIT
--
--  Toma la instruccion completa y produce el paquete de control (ctrl_t) que
--  gobierna el datapath. Es puramente combinacional. Parte de CTRL_NOP (no
--  escribe nada) y solo activa lo necesario segun el opcode, evitando latches.
--
--  Ruteo clave de la extension M: OP_REG con funct7 = "0000001" no va a la ALU
--  sino a la unidad muldiv; el funct3 selecciona MUL/MULH/.../REMU.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity control is
  port (
    instr : in  word_t;
    ctrl  : out ctrl_t
  );
end entity control;

architecture rtl of control is

  -- Selecciona la operacion de la ALU a partir de funct3 / funct7[5].
  -- 'is_reg' distingue OP_REG (permite SUB) de OP_IMM (nunca SUB).
  function decode_alu (
    f3     : std_logic_vector(2 downto 0);
    f7b5   : std_logic;
    is_reg : boolean
  ) return alu_op_t is
  begin
    case f3 is
      when F3_ADD_SUB =>
        if is_reg and f7b5 = '1' then return ALU_SUB; else return ALU_ADD; end if;
      when F3_SLL  => return ALU_SLL;
      when F3_SLT  => return ALU_SLT;
      when F3_SLTU => return ALU_SLTU;
      when F3_XOR  => return ALU_XOR;
      when F3_SR   =>
        if f7b5 = '1' then return ALU_SRA; else return ALU_SRL; end if;
      when F3_OR   => return ALU_OR;
      when F3_AND  => return ALU_AND;
      when others  => return ALU_ADD;
    end case;
  end function;

  -- Selecciona la operacion de muldiv a partir de funct3.
  function decode_md (f3 : std_logic_vector(2 downto 0)) return md_op_t is
  begin
    case f3 is
      when F3_MUL    => return MD_MUL;
      when F3_MULH   => return MD_MULH;
      when F3_MULHSU => return MD_MULHSU;
      when F3_MULHU  => return MD_MULHU;
      when F3_DIV    => return MD_DIV;
      when F3_DIVU   => return MD_DIVU;
      when F3_REM    => return MD_REM;
      when others    => return MD_REMU;
    end case;
  end function;

begin

  process(instr)
    variable c      : ctrl_t;
    variable opcode : std_logic_vector(6 downto 0);
    variable f3     : std_logic_vector(2 downto 0);
    variable f7     : std_logic_vector(6 downto 0);
    variable f7b5   : std_logic;
  begin
    c      := CTRL_NOP;
    opcode := instr(6 downto 0);
    f3     := instr(14 downto 12);
    f7     := instr(31 downto 25);
    f7b5   := instr(30);

    case opcode is

      when OP_IMM =>                        -- ADDI, SLTI, XORI, SLLI, SRAI, ...
        c.reg_we    := '1';
        c.alu_b_imm := '1';
        c.imm_fmt   := IMM_I;
        c.alu_op    := decode_alu(f3, f7b5, false);
        c.wb_sel    := WB_ALU;

      when OP_REG =>
        if f7 = F7_MULDIV then              -- extension M
          c.reg_we := '1';
          c.is_md  := '1';
          c.md_op  := decode_md(f3);
          c.wb_sel := WB_MD;
        else                                -- ADD, SUB, AND, OR, ...
          c.reg_we := '1';
          c.alu_op := decode_alu(f3, f7b5, true);
          c.wb_sel := WB_ALU;
        end if;

      when OP_LOAD =>                        -- LB, LH, LW, LBU, LHU
        c.reg_we    := '1';
        c.alu_b_imm := '1';
        c.imm_fmt   := IMM_I;
        c.alu_op    := ALU_ADD;             -- calcula direccion rs1+imm
        c.mem_re    := '1';
        c.wb_sel    := WB_MEM;

      when OP_STORE =>                       -- SB, SH, SW
        c.alu_b_imm := '1';
        c.imm_fmt   := IMM_S;
        c.alu_op    := ALU_ADD;             -- direccion rs1+imm
        c.mem_we    := '1';

      when OP_BRANCH =>                      -- BEQ, BNE, BLT, BGE, BLTU, BGEU
        c.imm_fmt   := IMM_B;
        c.is_branch := '1';                 -- no escribe registro

      when OP_JAL =>
        c.reg_we  := '1';
        c.imm_fmt := IMM_J;
        c.is_jal  := '1';
        c.wb_sel  := WB_PC4;                -- rd = PC+4

      when OP_JALR =>
        c.reg_we    := '1';
        c.imm_fmt   := IMM_I;
        c.alu_b_imm := '1';
        c.is_jalr   := '1';
        c.wb_sel    := WB_PC4;              -- rd = PC+4; destino = rs1+imm

      when OP_LUI =>
        c.reg_we    := '1';
        c.alu_b_imm := '1';
        c.imm_fmt   := IMM_U;
        c.alu_op    := ALU_PASS_B;          -- rd = imm
        c.wb_sel    := WB_ALU;

      when OP_AUIPC =>
        c.reg_we    := '1';
        c.alu_a_pc  := '1';
        c.alu_b_imm := '1';
        c.imm_fmt   := IMM_U;
        c.alu_op    := ALU_ADD;             -- rd = PC + imm
        c.wb_sel    := WB_ALU;

      when OP_SYSTEM =>
        if f3 = F3_PRIV then
          -- ECALL / EBREAK / MRET (se distinguen por el campo imm[11:0])
          case instr(31 downto 20) is
            when x"000" => c.is_ecall  := '1';
            when x"001" => c.is_ebreak := '1';
            when x"302" => c.is_mret   := '1';
            when others => null;   -- WFI y otros: NOP por ahora
          end case;
        else
          -- instrucciones CSR: rd <- viejo valor del CSR; CSR <- f(op, fuente)
          c.reg_we := '1';
          c.is_csr := '1';
          c.wb_sel := WB_CSR;
          case f3 is
            when F3_CSRRW  => c.csr_cmd := CSR_RW;
            when F3_CSRRS  => c.csr_cmd := CSR_RS;
            when F3_CSRRC  => c.csr_cmd := CSR_RC;
            when F3_CSRRWI => c.csr_cmd := CSR_RW; c.csr_imm := '1';
            when F3_CSRRSI => c.csr_cmd := CSR_RS; c.csr_imm := '1';
            when F3_CSRRCI => c.csr_cmd := CSR_RC; c.csr_imm := '1';
            when others    => null;
          end case;
        end if;

      when others =>                        -- FENCE y otros: por ahora NOP
        c := CTRL_NOP;

    end case;

    ctrl <= c;
  end process;

end architecture rtl;
