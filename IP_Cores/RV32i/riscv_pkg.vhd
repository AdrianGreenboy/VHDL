-- =============================================================================
--  riscv_pkg.vhd  -  Tipos y constantes compartidas para el core RV32I
--  Autor: Adrian Hernandez
--  Licencia: MIT (ver LICENSE)
--
--  Referencia: "The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA",
--  capitulo RV32I Base Integer Instruction Set.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package riscv_pkg is

  ---------------------------------------------------------------------------
  -- Ancho de palabra
  ---------------------------------------------------------------------------
  constant XLEN : natural := 32;
  subtype word_t is std_logic_vector(XLEN-1 downto 0);
  subtype reg_addr_t is std_logic_vector(4 downto 0);

  constant ZERO_WORD : word_t := (others => '0');

  ---------------------------------------------------------------------------
  -- Opcodes (instr[6:0]).  Los dos bits bajos son siempre "11" en RV32.
  ---------------------------------------------------------------------------
  constant OP_LUI    : std_logic_vector(6 downto 0) := "0110111";
  constant OP_AUIPC  : std_logic_vector(6 downto 0) := "0010111";
  constant OP_JAL    : std_logic_vector(6 downto 0) := "1101111";
  constant OP_JALR   : std_logic_vector(6 downto 0) := "1100111";
  constant OP_BRANCH : std_logic_vector(6 downto 0) := "1100011";
  constant OP_LOAD   : std_logic_vector(6 downto 0) := "0000011";
  constant OP_STORE  : std_logic_vector(6 downto 0) := "0100011";
  constant OP_IMM    : std_logic_vector(6 downto 0) := "0010011"; -- ALU con inmediato
  constant OP_REG    : std_logic_vector(6 downto 0) := "0110011"; -- ALU registro-registro
  constant OP_FENCE  : std_logic_vector(6 downto 0) := "0001111";
  constant OP_SYSTEM : std_logic_vector(6 downto 0) := "1110011"; -- ECALL/EBREAK/CSR

  ---------------------------------------------------------------------------
  -- funct3 para ALU / branches / loads / stores
  ---------------------------------------------------------------------------
  -- OP_IMM / OP_REG
  constant F3_ADD_SUB : std_logic_vector(2 downto 0) := "000"; -- ADD/SUB/ADDI
  constant F3_SLL     : std_logic_vector(2 downto 0) := "001";
  constant F3_SLT     : std_logic_vector(2 downto 0) := "010";
  constant F3_SLTU    : std_logic_vector(2 downto 0) := "011";
  constant F3_XOR     : std_logic_vector(2 downto 0) := "100";
  constant F3_SR      : std_logic_vector(2 downto 0) := "101"; -- SRL/SRA/SRLI/SRAI
  constant F3_OR      : std_logic_vector(2 downto 0) := "110";
  constant F3_AND     : std_logic_vector(2 downto 0) := "111";

  -- OP_BRANCH
  constant F3_BEQ  : std_logic_vector(2 downto 0) := "000";
  constant F3_BNE  : std_logic_vector(2 downto 0) := "001";
  constant F3_BLT  : std_logic_vector(2 downto 0) := "100";
  constant F3_BGE  : std_logic_vector(2 downto 0) := "101";
  constant F3_BLTU : std_logic_vector(2 downto 0) := "110";
  constant F3_BGEU : std_logic_vector(2 downto 0) := "111";

  -- OP_LOAD / OP_STORE (ancho de acceso)
  constant F3_B  : std_logic_vector(2 downto 0) := "000"; -- byte
  constant F3_H  : std_logic_vector(2 downto 0) := "001"; -- half
  constant F3_W  : std_logic_vector(2 downto 0) := "010"; -- word
  constant F3_BU : std_logic_vector(2 downto 0) := "100"; -- byte unsigned
  constant F3_HU : std_logic_vector(2 downto 0) := "101"; -- half unsigned

  ---------------------------------------------------------------------------
  -- Operaciones de la ALU (enum interno, independiente del encoding ISA)
  ---------------------------------------------------------------------------
  type alu_op_t is (
    ALU_ADD, ALU_SUB,
    ALU_SLL, ALU_SRL, ALU_SRA,
    ALU_SLT, ALU_SLTU,
    ALU_XOR, ALU_OR,  ALU_AND,
    ALU_PASS_B          -- pasa el operando B tal cual (usado por LUI)
  );

  ---------------------------------------------------------------------------
  -- Extension M (mul/div).  Comparten OP_REG con funct7 = "0000001".
  ---------------------------------------------------------------------------
  constant F7_MULDIV : std_logic_vector(6 downto 0) := "0000001";

  -- funct3 de la extension M
  constant F3_MUL    : std_logic_vector(2 downto 0) := "000";
  constant F3_MULH   : std_logic_vector(2 downto 0) := "001";
  constant F3_MULHSU : std_logic_vector(2 downto 0) := "010";
  constant F3_MULHU  : std_logic_vector(2 downto 0) := "011";
  constant F3_DIV    : std_logic_vector(2 downto 0) := "100";
  constant F3_DIVU   : std_logic_vector(2 downto 0) := "101";
  constant F3_REM    : std_logic_vector(2 downto 0) := "110";
  constant F3_REMU   : std_logic_vector(2 downto 0) := "111";

  -- Operaciones de la unidad muldiv (enum interno)
  type md_op_t is (
    MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU,
    MD_DIV, MD_DIVU, MD_REM,    MD_REMU
  );

  ---------------------------------------------------------------------------
  -- Tipos del decode (fase 2)
  ---------------------------------------------------------------------------
  -- Formato del inmediato segun el tipo de instruccion
  type imm_fmt_t is (IMM_I, IMM_S, IMM_B, IMM_U, IMM_J, IMM_NONE);

  -- Fuente del dato que se escribe en el registro destino (writeback)
  type wb_sel_t is (WB_ALU, WB_MEM, WB_PC4, WB_MD, WB_CSR);

  -- Comando de acceso a CSR
  type csr_cmd_t is (CSR_RW, CSR_RS, CSR_RC);

  ---------------------------------------------------------------------------
  -- Zicsr + traps (privilegiado, modo maquina)
  ---------------------------------------------------------------------------
  -- funct3 del opcode SYSTEM
  constant F3_PRIV   : std_logic_vector(2 downto 0) := "000"; -- ECALL/EBREAK/MRET
  constant F3_CSRRW  : std_logic_vector(2 downto 0) := "001";
  constant F3_CSRRS  : std_logic_vector(2 downto 0) := "010";
  constant F3_CSRRC  : std_logic_vector(2 downto 0) := "011";
  constant F3_CSRRWI : std_logic_vector(2 downto 0) := "101";
  constant F3_CSRRSI : std_logic_vector(2 downto 0) := "110";
  constant F3_CSRRCI : std_logic_vector(2 downto 0) := "111";

  -- direcciones de CSR (modo maquina)
  constant CSR_MSTATUS  : std_logic_vector(11 downto 0) := x"300";
  constant CSR_MIE      : std_logic_vector(11 downto 0) := x"304";
  constant CSR_MTVEC    : std_logic_vector(11 downto 0) := x"305";
  constant CSR_MSCRATCH : std_logic_vector(11 downto 0) := x"340";
  constant CSR_MEPC     : std_logic_vector(11 downto 0) := x"341";
  constant CSR_MCAUSE   : std_logic_vector(11 downto 0) := x"342";
  constant CSR_MTVAL    : std_logic_vector(11 downto 0) := x"343";
  constant CSR_MIP      : std_logic_vector(11 downto 0) := x"344";

  -- causas de trap (mcause) usadas por este core
  constant CAUSE_EBREAK  : word_t := x"00000003";
  constant CAUSE_ECALL_M : word_t := x"0000000B";

  -- causas de interrupcion (bit 31 = interrupcion asincrona)
  constant CAUSE_IRQ_SOFT_M  : word_t := x"80000003";  -- software (MSI)
  constant CAUSE_IRQ_TIMER_M : word_t := x"80000007";  -- timer (MTI)
  constant CAUSE_IRQ_EXT_M   : word_t := x"8000000B";  -- externa (MEI)

  -- Paquete de senales de control que produce el decoder para cada instruccion
  type ctrl_t is record
    reg_we    : std_logic;     -- escribe el registro destino
    alu_a_pc  : std_logic;     -- operando A de la ALU = PC (AUIPC/JAL)
    alu_b_imm : std_logic;     -- operando B de la ALU = inmediato (si no, rs2)
    alu_op    : alu_op_t;      -- operacion de la ALU
    imm_fmt   : imm_fmt_t;     -- formato del inmediato a extraer
    is_md     : std_logic;     -- rutea a la unidad muldiv (extension M)
    md_op     : md_op_t;       -- operacion de muldiv
    mem_re    : std_logic;     -- lectura de memoria (load)
    mem_we    : std_logic;     -- escritura de memoria (store)
    is_branch : std_logic;     -- salto condicional
    is_jal    : std_logic;     -- JAL
    is_jalr   : std_logic;     -- JALR
    wb_sel    : wb_sel_t;      -- fuente del writeback
    is_csr    : std_logic;     -- instruccion CSR
    csr_cmd   : csr_cmd_t;     -- operacion CSR (RW/RS/RC)
    csr_imm   : std_logic;     -- usa zimm (campo rs1) en vez de rs1
    is_ecall  : std_logic;
    is_ebreak : std_logic;
    is_mret   : std_logic;
  end record;

  -- Control por defecto: no escribe nada (equivale a una burbuja/NOP)
  constant CTRL_NOP : ctrl_t := (
    reg_we => '0', alu_a_pc => '0', alu_b_imm => '0', alu_op => ALU_ADD,
    imm_fmt => IMM_NONE, is_md => '0', md_op => MD_MUL,
    mem_re => '0', mem_we => '0', is_branch => '0', is_jal => '0',
    is_jalr => '0', wb_sel => WB_ALU,
    is_csr => '0', csr_cmd => CSR_RW, csr_imm => '0',
    is_ecall => '0', is_ebreak => '0', is_mret => '0'
  );

end package riscv_pkg;
