-- =============================================================================
--  tb_exc.vhd  -  audit-2026-11: synchronous exceptions, self-checking
--  License: MIT
--
--  Runs exc_test.mem (see exc_test.s) on the pipelined core (USE_PIPE=true,
--  optionally with 1-cycle synchronous IMEM/DMEM) or on the single-cycle
--  core, and checks:
--    * the trap log written by the handler: (mcause, mtval) for 17 traps -
--      illegal instructions (unknown opcode, reserved funct7, unknown SYSTEM
--      immediate, SYSTEM f3=100, unimplemented CSR, write to RO CSR, CSRRS
--      with a non-x0 rs1 holding zero to a RO CSR), load/store misaligned,
--      misaligned jump/branch targets, ecall (mtval = 0);
--    * that faulting instructions changed nothing (rd, memory);
--    * misa / mhartid reads, sub-word loads/stores, FENCE/FENCE.I/WFI as NOP;
--    * a misaligned load whose consumer waits in ID (redirect vs load-use).
--  Prints TB_EXC_PASS on success.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity tb_exc is
  generic (
    USE_PIPE : boolean := true;
    SYNC_MEM : boolean := false     -- pipeline only
  );
end entity tb_exc;

architecture sim of tb_exc is
  constant TCK : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dbg_addr : reg_addr_t := (others => '0');
  signal dbg_data, dbg_pc : word_t;
  signal done : boolean := false;

  type log_t is array (0 to 63) of word_t;
  signal log : log_t := (others => (others => 'U'));
  signal mem63 : word_t := (others => 'U');

  type exp_t is array (natural range <>) of word_t;
  constant EXP_LOG : exp_t := (
    x"00000002", x"00000000",     -- T1  .word 0
    x"00000002", x"FFFFFFFF",     -- T2  .word all ones
    x"00000002", x"4000F033",     -- T3  reserved funct7
    x"00000002", x"00200073",     -- T4  unknown SYSTEM imm
    x"00000002", x"00004073",     -- T5  SYSTEM f3=100
    x"00000002", x"7C002373",     -- T6  unimplemented CSR
    x"00000002", x"F1451073",     -- T7  csrw mhartid
    x"00000002", x"F144A3F3",     -- T8  csrrs x7, mhartid, x9 (x9 = 0)
    x"00000004", x"00000001",     -- T9  lw  1(x0)
    x"00000004", x"00000003",     -- T10 lh  3(x0)
    x"00000006", x"00000002",     -- T11 sw  2(x0)
    x"00000006", x"00000005",     -- T12 sh  5(x0)
    x"00000000", x"000000AA",     -- T13 jalr -> 0xAA
    x"00000000", x"00000082",     -- T14 jal  -> 0x82
    x"00000000", x"00000086",     -- T15 beq  -> 0x86
    x"0000000B", x"00000000",     -- T16 ecall, mtval cleared
    x"00000004", x"00000001");    -- T17 lw 1(x0) with dependent consumer
begin
  clk <= not clk after TCK/2 when not done else '0';

  g_pipe : if USE_PIPE generate
    u_cpu : entity work.cpu_pipeline
      generic map (IMEM_SYNC => SYNC_MEM, DMEM_SYNC => SYNC_MEM)
      port map (clk => clk, rst => rst,
        imem_addr => imem_addr, imem_instr => imem_instr,
        dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
        dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
        dbg_reg_addr => dbg_addr, dbg_reg_data => dbg_data, dbg_pc => dbg_pc);
  end generate;
  g_single : if not USE_PIPE generate
    u_cpu : entity work.cpu
      port map (clk => clk, rst => rst,
        imem_addr => imem_addr, imem_instr => imem_instr,
        dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
        dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
        dbg_reg_addr => dbg_addr, dbg_reg_data => dbg_data, dbg_pc => dbg_pc);
  end generate;

  u_imem : entity work.imem
    generic map (DEPTH => 256, INIT_FILE => "exc_test.mem", SYNC_READ => SYNC_MEM and USE_PIPE)
    port map (clk => clk, addr => imem_addr, instr => imem_instr);

  u_dmem : entity work.dmem
    generic map (DEPTH => 256, SYNC_READ => SYNC_MEM and USE_PIPE)
    port map (clk => clk, addr => dmem_addr, wdata => dmem_wdata,
              wstrb => dmem_wstrb, rdata => dmem_rdata);

  -- store monitor: handler log (0x100..0x1FF) and the final trap count (0xFC)
  process(clk)
    variable a : natural;
  begin
    if rising_edge(clk) and rst = '0' and dmem_wstrb = "1111" then
      a := to_integer(unsigned(dmem_addr(9 downto 0)));
      if a >= 256 and a < 512 then
        log((a - 256) / 4) <= dmem_wdata;
      elsif a = 252 then
        mem63 <= dmem_wdata;
      end if;
    end if;
  end process;

  stim : process
    variable errors : natural := 0;
    procedure chk (constant ok : boolean; constant name : string) is
    begin
      if ok then report "PASS " & name severity note;
      else report "FAIL " & name severity error; errors := errors + 1; end if;
    end procedure;
    procedure chk_reg (constant r : natural; constant exp : word_t; constant name : string) is
    begin
      dbg_addr <= std_logic_vector(to_unsigned(r, 5));
      wait for 1 ns;
      if dbg_data = exp then report "PASS " & name severity note;
      else
        report "FAIL " & name & " got=0x" & to_hstring(dbg_data) & " exp=0x" & to_hstring(exp)
          severity error;
        errors := errors + 1;
      end if;
    end procedure;
  begin
    rst <= '1';
    wait for 3*TCK;
    wait until rising_edge(clk);
    rst <= '0';
    for i in 0 to 5000 loop
      wait until rising_edge(clk);
      exit when mem63 /= (31 downto 0 => 'U');
    end loop;
    for i in 0 to 20 loop wait until rising_edge(clk); end loop;

    chk(mem63 = x"00000011", "trap count = 17 (got 0x" & to_hstring(mem63) & ")");
    for i in EXP_LOG'range loop
      if log(i) /= EXP_LOG(i) then
        report "FAIL log[" & integer'image(i) & "] (T" & integer'image(i/2 + 1) & ") got=0x" &
               to_hstring(log(i)) & " exp=0x" & to_hstring(EXP_LOG(i)) severity error;
        errors := errors + 1;
      end if;
    end loop;
    chk(log(EXP_LOG'length) = (31 downto 0 => 'U'), "no extra trap logged");
    chk_reg(6,  x"00000000", "csrrs x6, mhartid, x0 (legal read)");
    chk_reg(7,  x"00000000", "x7 untouched by illegal csrrs");
    chk_reg(8,  MISA_VALUE,  "misa = RV32IM");
    chk_reg(11, x"5A5A5A5A", "faulting loads did not write rd");
    chk_reg(12, x"00001122", "lhu 2(x0)");
    chk_reg(13, x"00000011", "lb 3(x0)");
    chk_reg(14, x"11220044", "misaligned stores did not write, sb did");
    chk_reg(15, x"00000555", "faulting jalr did not write rd");
    chk_reg(17, x"00000777", "misaligned load with waiting consumer: rd kept");
    chk_reg(18, x"00000778", "consumer executed once after the trap");
    chk_reg(30, x"00000011", "x30 trap count");

    if errors = 0 then
      report "TB_EXC_PASS (USE_PIPE=" & boolean'image(USE_PIPE) & " SYNC_MEM=" &
             boolean'image(SYNC_MEM) & ")" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    done <= true;
    wait;
  end process;
end architecture sim;
