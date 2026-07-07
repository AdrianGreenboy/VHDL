-- =============================================================================
--  tb_trap_pipeline.vhd  -  Traps (ECALL/MRET) en el core con pipeline
--  Licencia: MIT
--  Corre program_trap.mem y verifica identico estado final que el single-cycle,
--  ejercitando excepciones precisas y serializacion de CSR en el pipeline.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_trap_pipeline is
end entity tb_trap_pipeline;

architecture sim of tb_trap_pipeline is
  constant TCK : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dbg_addr : reg_addr_t := (others => '0');
  signal dbg_data : word_t;
  signal dbg_pc   : word_t;
begin
  clk <= not clk after TCK/2;

  u_cpu : entity work.cpu_pipeline
    port map (clk => clk, rst => rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dbg_reg_addr => dbg_addr, dbg_reg_data => dbg_data, dbg_pc => dbg_pc);

  u_imem : entity work.imem
    generic map (DEPTH => 256, INIT_FILE => "program_trap.mem")
    port map (addr => imem_addr, instr => imem_instr);

  u_dmem : entity work.dmem
    generic map (DEPTH => 256)
    port map (clk => clk, addr => dmem_addr, wdata => dmem_wdata,
              wstrb => dmem_wstrb, rdata => dmem_rdata);

  stim : process
    variable errors : natural := 0;
    procedure check_reg (constant r : natural; constant exp : word_t;
                         constant name : string) is
    begin
      dbg_addr <= std_logic_vector(to_unsigned(r, 5));
      wait for 1 ns;
      if dbg_data = exp then
        report "PASS " & name severity note;
      else
        report "FAIL " & name & " got=0x" & to_hstring(dbg_data) &
               " exp=0x" & to_hstring(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;
  begin
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    for i in 0 to 199 loop wait until rising_edge(clk); end loop;

    check_reg( 6, x"0000006F", "x6  = 111");
    check_reg( 7, x"000000DE", "x7  = 222 (retorno MRET)");
    check_reg(28, x"0000000B", "x28 = mcause = 11");
    check_reg(29, x"0000002A", "x29 = 42 (handler)");
    check_reg(30, x"00000010", "x30 = mepc+4 = 16");

    report "-----------------------------------------";
    if errors = 0 then
      report "TODOS LOS TESTS DE TRAPS (PIPELINE) PASARON" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;
end architecture sim;
