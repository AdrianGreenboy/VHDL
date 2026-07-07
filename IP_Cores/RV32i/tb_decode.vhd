-- =============================================================================
--  tb_decode.vhd  -  Testbench autoverificable del decode (control + immgen)
--  Licencia: MIT
--
--  Encadena control -> immgen (el formato del inmediato sale del decoder) y
--  verifica, con instrucciones reales, las senales de control clave y el valor
--  del inmediato generado.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_decode is
end entity tb_decode;

architecture sim of tb_decode is
  signal instr : word_t := (others => '0');
  signal ctrl  : ctrl_t;
  signal imm   : word_t;
begin

  u_ctrl : entity work.control
    port map (instr => instr, ctrl => ctrl);

  u_imm : entity work.immgen
    port map (instr => instr, fmt => ctrl.imm_fmt, imm => imm);

  stim : process
    variable errors : natural := 0;

    procedure expect (cond : boolean; name : string) is
    begin
      if cond then
        report "PASS " & name severity note;
      else
        report "FAIL " & name severity error;
        errors := errors + 1;
      end if;
    end procedure;

  begin
    ---------------------------------------------------------------------------
    -- addi x1, x0, 5           -> 0x00500093
    instr <= x"00500093"; wait for 1 ns;
    expect(ctrl.reg_we = '1',        "ADDI reg_we");
    expect(ctrl.alu_b_imm = '1',     "ADDI alu_b_imm");
    expect(ctrl.alu_op = ALU_ADD,    "ADDI alu_op");
    expect(ctrl.wb_sel = WB_ALU,     "ADDI wb_sel");
    expect(imm = x"00000005",        "ADDI imm=5");

    -- add x3, x1, x2           -> 0x002081B3
    instr <= x"002081B3"; wait for 1 ns;
    expect(ctrl.reg_we = '1',        "ADD reg_we");
    expect(ctrl.alu_b_imm = '0',     "ADD usa rs2");
    expect(ctrl.alu_op = ALU_ADD,    "ADD alu_op");
    expect(ctrl.is_md = '0',         "ADD no es muldiv");

    -- sub x5, x6, x7           -> 0x407302B3
    instr <= x"407302B3"; wait for 1 ns;
    expect(ctrl.alu_op = ALU_SUB,    "SUB alu_op");

    -- lw x10, 8(x11)           -> 0x0085A503
    instr <= x"0085A503"; wait for 1 ns;
    expect(ctrl.mem_re = '1',        "LW mem_re");
    expect(ctrl.wb_sel = WB_MEM,     "LW wb_sel");
    expect(ctrl.alu_op = ALU_ADD,    "LW addr add");
    expect(imm = x"00000008",        "LW imm=8");

    -- sw x12, 12(x13)          -> 0x00C6A623
    instr <= x"00C6A623"; wait for 1 ns;
    expect(ctrl.mem_we = '1',        "SW mem_we");
    expect(ctrl.reg_we = '0',        "SW no escribe reg");
    expect(imm = x"0000000C",        "SW imm=12");

    -- beq x1, x2, +8           -> 0x00208463
    instr <= x"00208463"; wait for 1 ns;
    expect(ctrl.is_branch = '1',     "BEQ is_branch");
    expect(ctrl.reg_we = '0',        "BEQ no escribe reg");
    expect(imm = x"00000008",        "BEQ imm=8");

    -- jal x1, +16              -> 0x010000EF
    instr <= x"010000EF"; wait for 1 ns;
    expect(ctrl.is_jal = '1',        "JAL is_jal");
    expect(ctrl.wb_sel = WB_PC4,     "JAL wb_sel=PC4");
    expect(imm = x"00000010",        "JAL imm=16");

    -- lui x5, 0x12345          -> 0x123452B7
    instr <= x"123452B7"; wait for 1 ns;
    expect(ctrl.alu_op = ALU_PASS_B, "LUI pass_b");
    expect(ctrl.reg_we = '1',        "LUI reg_we");
    expect(imm = x"12345000",        "LUI imm alto");

    -- mul x1, x2, x3           -> 0x023100B3
    instr <= x"023100B3"; wait for 1 ns;
    expect(ctrl.is_md = '1',         "MUL is_md");
    expect(ctrl.md_op = MD_MUL,      "MUL md_op");
    expect(ctrl.wb_sel = WB_MD,      "MUL wb_sel=MD");

    -- divu x4, x5, x6          -> 0x0262D233
    instr <= x"0262D233"; wait for 1 ns;
    expect(ctrl.is_md = '1',         "DIVU is_md");
    expect(ctrl.md_op = MD_DIVU,     "DIVU md_op");

    ---------------------------------------------------------------------------
    report "-----------------------------------------";
    if errors = 0 then
      report "TODOS LOS TESTS DE DECODE PASARON" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
