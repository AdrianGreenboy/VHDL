-- =============================================================================
-- tb_lw_hazard_reg.vhd
-- REGRESION PERMANENTE del hazard de forwarding-durante-stall en cpu_pipeline.
--
-- Caso critico (GAP=0): el registro base lo produce la instruccion INMEDIATAMENTE
-- anterior al primer lw; ese primer lw estanca el pipeline (memoria lenta, N=2
-- ciclos). Antes del fix, el forwarding del resultado recien retirado se perdia
-- al aplastarse mem_wb a NOP durante el stall, y el segundo lw computaba su
-- direccion con base=0 (acceso perdido del bus del periferico, dato residual).
--
-- Debe FALLAR (severity failure) si el bug reaparece, y pasar en caso contrario.
-- Programa:
--   0x00 lui a0,0xD0000      (produce la base, instruccion previa)
--   0x04 lw  a1,0(a0)        (lw#1 -> 0xD0000000, estanca)
--   0x08 lw  a2,4(a0)        (lw#2 -> 0xD0000004, el que se perdia)
--   0x0C lw  a3,8(a0)        (lw#3 -> 0xD0000008)
-- Se verifica que las TRES direcciones aparezcan en el bus CON BASE INTACTA.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity tb_lw_hazard_reg is
end entity tb_lw_hazard_reg;

architecture sim of tb_lw_hazard_reg is
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

  signal wait_cnt : natural := 0;
  signal seen_d0  : boolean := false;
  signal seen_d4  : boolean := false;
  signal seen_d8  : boolean := false;
  signal bad_addr : boolean := false;

  constant WAIT_N : natural := 2;
  constant PERIOD : time := 10 ns;
  signal sim_done : boolean := false;
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
    idx := to_integer(unsigned(imem_addr(7 downto 2)));
    case idx is
      when 0      => imem_instr <= x"D0000537";
      when 1      => imem_instr <= x"00052583";
      when 2      => imem_instr <= x"00452603";
      when 3      => imem_instr <= x"00852683";
      when others => imem_instr <= x"00000013";
    end case;
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
          when others      => bad_addr <= true;
        end case;
      end if;
    end if;
  end process;

  process
  begin
    rst <= '1';
    wait for 4*PERIOD;
    rst <= '0';
    wait for 60*PERIOD;

    assert seen_d0
      report "REG_FALLO: lw#1 (0xD0000000) ausente en el bus" severity failure;
    assert not bad_addr
      report "REG_HAZARD: hubo un acceso con base corrupta (regresion del hazard lw-lw)" severity failure;
    assert seen_d4
      report "REG_HAZARD: lw#2 (0xD0000004) NO aparecio con base intacta (regresion del hazard lw-lw)" severity failure;
    assert seen_d8
      report "REG_FALLO: lw#3 (0xD0000008) ausente en el bus" severity failure;

    report "TB_LW_HAZARD_REG_PASS: las tres lecturas con base intacta; hazard ausente" severity note;
    sim_done <= true;
    wait;
  end process;
end architecture sim;
