-- =============================================================================
-- tb_lw_hazard.vhd  (v5: barrido de GAP entre lui y el primer lw)
-- Un generic GAP controla cuantos nop hay entre "lui a0" y "lw#1".
-- Para cada GAP se comprueba que lw#2 (0xD0000004) aparezca con base intacta.
-- Objetivo: localizar la ventana exacta del hazard de forwarding-durante-stall.
-- Mensajes ASCII.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.riscv_pkg.all;

entity tb_lw_hazard is
  generic ( GAP : natural := 0 );
end entity tb_lw_hazard;

architecture sim of tb_lw_hazard is
  signal clk        : std_logic := '0';
  signal rst        : std_logic := '1';
  signal imem_addr  : word_t;
  signal imem_instr : word_t;
  signal dmem_addr  : word_t;
  signal dmem_wdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_rdata : word_t := (others => '0');
  signal dmem_req   : std_logic;
  signal dmem_ready : std_logic := '0';

  signal wait_cnt   : natural := 0;
  signal seen_d0 : boolean := false;
  signal seen_d4 : boolean := false;
  signal seen_d8 : boolean := false;
  signal bad_addr : boolean := false;
  signal bad_val  : word_t := (others => '0');

  constant WAIT_N : natural := 2;
  constant PERIOD : time := 10 ns;
  signal sim_done : boolean := false;

  function instr_at(idx : natural; gap : natural) return word_t is
  begin
    if idx = 0 then
      return x"D0000537";
    elsif idx = 1+gap then
      return x"00052583";
    elsif idx = 2+gap then
      return x"00452603";
    elsif idx = 3+gap then
      return x"00852683";
    else
      return x"00000013";
    end if;
  end function;
begin
  clk <= not clk after PERIOD/2 when not sim_done else '0';

  dut : entity work.cpu_pipeline
    port map (
      clk => clk, rst => rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dmem_req => dmem_req, dmem_ready => dmem_ready
    );

  process(imem_addr)
    variable idx : natural;
  begin
    idx := to_integer(unsigned(imem_addr(9 downto 2)));
    imem_instr <= instr_at(idx, GAP);
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wait_cnt <= 0;
      else
        if dmem_req = '1' then
          if wait_cnt >= WAIT_N then wait_cnt <= 0;
          else wait_cnt <= wait_cnt + 1; end if;
        else
          wait_cnt <= 0;
        end if;
      end if;
    end if;
  end process;

  dmem_ready <= '1' when (dmem_req = '1' and wait_cnt >= WAIT_N) else '0';

  process(dmem_addr)
  begin
    case dmem_addr is
      when x"D0000000" => dmem_rdata <= x"AAAA0000";
      when x"D0000004" => dmem_rdata <= x"BBBB0004";
      when x"D0000008" => dmem_rdata <= x"CCCC0008";
      when others      => dmem_rdata <= x"DEADBEEF";
    end case;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' and dmem_req = '1' and dmem_ready = '1' then
        case dmem_addr is
          when x"D0000000" => seen_d0 <= true;
          when x"D0000004" => seen_d4 <= true;
          when x"D0000008" => seen_d8 <= true;
          when others      => bad_addr <= true; bad_val <= dmem_addr;
        end case;
      end if;
    end if;
  end process;

  process
    variable l : line;
  begin
    rst <= '1';
    wait for 4*PERIOD;
    rst <= '0';
    wait for 60*PERIOD;

    write(l, string'("GAP=")); write(l, GAP);
    write(l, string'("  d0=")); write(l, seen_d0);
    write(l, string'(" d4=")); write(l, seen_d4);
    write(l, string'(" d8=")); write(l, seen_d8);
    if bad_addr then
      write(l, string'("  BAD_ADDR=0x")); hwrite(l, bad_val);
    end if;
    writeline(output, l);

    if seen_d0 and seen_d4 and seen_d8 and not bad_addr then
      report "GAP_OK" severity note;
    else
      report "GAP_HAZARD" severity note;
    end if;
    sim_done <= true;
    wait;
  end process;
end architecture sim;
