-- =============================================================================
--  tb_irq.vhd  -  Testbench de interrupcion de timer (CLINT) en el core
--  Licencia: MIT
--
--  Conecta el CLINT al bus de datos mediante un decodificador de direcciones
--  (rango 0x0200_xxxx -> CLINT, el resto -> dmem) y la linea timer_irq al core.
--  El programa habilita el timer, corre un lazo, recibe la interrupcion, el
--  manejador deja una sentinela y desactiva el timer, y retorna.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_irq is
end entity tb_irq;

architecture sim of tb_irq is
  constant TCK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_rdata : word_t;                 -- lo que ve el core (mux)

  signal ram_rdata, clint_rdata : word_t;
  signal ram_wstrb  : std_logic_vector(3 downto 0);
  signal sel_clint  : std_logic;
  signal clint_we   : std_logic;
  signal timer_irq, soft_irq : std_logic;

  signal dbg_addr : reg_addr_t := (others => '0');
  signal dbg_data : word_t;
  signal dbg_pc   : word_t;
begin

  clk <= not clk after TCK/2;

  u_cpu : entity work.cpu
    port map (
      clk => clk, rst => rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      irq_timer => timer_irq, irq_soft => soft_irq, irq_ext => '0',
      dbg_reg_addr => dbg_addr, dbg_reg_data => dbg_data, dbg_pc => dbg_pc
    );

  u_imem : entity work.imem
    generic map (DEPTH => 256, INIT_FILE => "program_irq.mem")
    port map (addr => imem_addr, instr => imem_instr);

  -- decodificador: 0x0200_xxxx -> CLINT, el resto -> RAM
  sel_clint  <= '1' when dmem_addr(31 downto 16) = x"0200" else '0';
  clint_we   <= '1' when (sel_clint = '1' and dmem_wstrb /= "0000") else '0';
  ram_wstrb  <= "0000" when sel_clint = '1' else dmem_wstrb;   -- no escribas RAM en accesos a CLINT
  dmem_rdata <= clint_rdata when sel_clint = '1' else ram_rdata;

  u_dmem : entity work.dmem
    generic map (DEPTH => 256)
    port map (clk => clk, addr => dmem_addr, wdata => dmem_wdata,
              wstrb => ram_wstrb, rdata => ram_rdata);

  u_clint : entity work.clint
    port map (
      clk => clk, rst => rst,
      sel => sel_clint, we => clint_we,
      addr => dmem_addr(15 downto 0), wdata => dmem_wdata,
      rdata => clint_rdata,
      timer_irq => timer_irq, soft_irq => soft_irq
    );

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

    for i in 0 to 799 loop
      wait until rising_edge(clk);
    end loop;

    check_reg(20, x"000000C8", "x20 = 200 (lazo completo)");
    check_reg(21, x"0000ABCD", "x21 = sentinela (handler corrio)");
    check_reg(22, x"000000C8", "x22 = 200");
    check_reg(28, x"80000007", "x28 = mcause = timer irq");

    report "-----------------------------------------";
    if errors = 0 then
      report "TODOS LOS TESTS DE INTERRUPCIONES PASARON" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
