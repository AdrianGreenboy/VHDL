-- =============================================================================
--  tb_cpu_pipeline.vhd  -  Testbench de integracion del core con pipeline
--  Licencia: MIT
--
--  Corre el mismo program.mem que el core single-cycle y verifica identico
--  estado final de registros, ejercitando forwarding, load-use stall, flush de
--  branches y el stall de mul/div.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_cpu_pipeline is
end entity tb_cpu_pipeline;

architecture sim of tb_cpu_pipeline is
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
    port map (
      clk => clk, rst => rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dbg_reg_addr => dbg_addr, dbg_reg_data => dbg_data, dbg_pc => dbg_pc
    );

  u_imem : entity work.imem
    generic map (DEPTH => 256, INIT_FILE => "program.mem")
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

    -- el pipeline tarda un poco mas por las burbujas de branch/stall
    for i in 0 to 249 loop
      wait until rising_edge(clk);
    end loop;

    check_reg( 1, x"00000006", "x1  = 6");
    check_reg( 2, x"00000007", "x2  = 7");
    check_reg( 3, x"0000002A", "x3  = 42  (mul)");
    check_reg( 4, x"00000064", "x4  = 100");
    check_reg( 5, x"00000010", "x5  = 16  (divu)");
    check_reg( 6, x"00000004", "x6  = 4   (rem)");
    check_reg( 7, x"00000001", "x7  = 1   (sub)");
    check_reg(10, x"0000000F", "x10 = 15  (loop + forwarding)");
    check_reg(11, x"00000006", "x11 = 6");
    check_reg(14, x"0000002A", "x14 = 42  (load)");
    check_reg(15, x"0000002B", "x15 = 43  (load-use stall)");
    check_reg(16, x"00000126", "x16 = 294 (mul)");
    check_reg(17, x"00000126", "x17 = 294 (forward de mul)");

    report "-----------------------------------------";
    if errors = 0 then
      report "TODOS LOS TESTS DEL PIPELINE PASARON" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
