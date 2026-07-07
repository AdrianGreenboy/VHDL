-- =============================================================================
--  tb_difftest.vhd  -  Banco para differential testing del core con pipeline
--  Licencia: MIT
--
--  Carga program.mem (generado por difftest_gen.py), lo corre, y vuelca el
--  estado final de los 32 registros a "actual.txt" (hex, una palabra por linea)
--  para compararlo con expected.txt del modelo de oro.
--
--  Para probar el core single-cycle en su lugar, cambia cpu_pipeline por cpu.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.riscv_pkg.all;

entity tb_difftest is
end entity tb_difftest;

architecture sim of tb_difftest is
  constant TCK    : time    := 10 ns;
  constant CYCLES : natural := 3000;   -- holgado para ~48 instr con div/rem

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
    generic map (DEPTH => 256, INIT_FILE => "program_dt.mem")
    port map (addr => imem_addr, instr => imem_instr);

  u_dmem : entity work.dmem
    generic map (DEPTH => 256)
    port map (clk => clk, addr => dmem_addr, wdata => dmem_wdata,
              wstrb => dmem_wstrb, rdata => dmem_rdata);

  stim : process
    file     fout : text open write_mode is "actual.txt";
    variable l    : line;
  begin
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    for i in 0 to CYCLES-1 loop
      wait until rising_edge(clk);
    end loop;

    -- volcado de los 32 registros
    for r in 0 to 31 loop
      dbg_addr <= std_logic_vector(to_unsigned(r, 5));
      wait for 1 ns;
      hwrite(l, dbg_data);
      writeline(fout, l);
    end loop;
    file_close(fout);

    report "difftest: volcado de registros completo" severity note;
    std.env.finish;
  end process;

end architecture sim;
