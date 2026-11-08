-- =============================================================================
--  tb_lu_stall.vhd  -  audit-2026-11: load-use stall only on real dependencies
--  License: MIT
--
--  Four cpu_pipeline instances run four tiny programs that differ only in the
--  instruction right after a load of x1:
--    P0  lui  x2, 0x8        (rs1 FIELD = x1, but LUI reads no register)
--    P1  addi x2, x0, 1      (rs2 FIELD = x1, but I-type reads no rs2)
--    P2  lui  x2, 0x0        (no field match: reference)
--    P3  addi x2, x1, 0      (true dependency: exactly one extra cycle)
--  Before the fix P0/P1 stalled like P3. Checks the cycle at which each
--  program reaches its final loop, and the result values. Self-checking.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

entity tb_lu_stall is
  generic ( SYNC_MEM : boolean := false );
end entity tb_lu_stall;

architecture sim of tb_lu_stall is
  constant TCK : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;

  type prog_t is array (0 to 7) of word_t;
  type progs_t is array (0 to 3) of prog_t;
  -- common: 0 lw x1,0(x0) ; 1 <variant> ; 2..4 nop ; 5 sw x2,8(x0) ; 6 j . ; 7 nop
  constant PROGS : progs_t := (
    0 => (x"00002083", x"00008137", x"00000013", x"00000013", x"00000013", x"00202423", x"0000006F", x"00000013"),
    1 => (x"00002083", x"00100113", x"00000013", x"00000013", x"00000013", x"00202423", x"0000006F", x"00000013"),
    2 => (x"00002083", x"00000137", x"00000013", x"00000013", x"00000013", x"00202423", x"0000006F", x"00000013"),
    3 => (x"00002083", x"00008113", x"00000013", x"00000013", x"00000013", x"00202423", x"0000006F", x"00000013"));
  constant HALT_PC : word_t := x"00000018";
  type nat_arr is array (0 to 3) of natural;
  signal t_halt : nat_arr := (others => 0);
  type w_arr is array (0 to 3) of word_t;
  signal stored : w_arr := (others => (others => 'U'));
  signal cycle : natural := 0;
begin
  clk <= not clk after TCK/2 when not done else '0';

  process(clk) begin
    if rising_edge(clk) then
      if rst = '1' then cycle <= 0; else cycle <= cycle + 1; end if;
    end if;
  end process;

  g : for k in 0 to 3 generate
    signal imem_addr, imem_instr, imem_comb : word_t;
    signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
    signal dmem_wstrb : std_logic_vector(3 downto 0);
    signal dbg_pc : word_t;
  begin
    u_cpu : entity work.cpu_pipeline
      generic map (IMEM_SYNC => SYNC_MEM, DMEM_SYNC => SYNC_MEM)
      port map (clk => clk, rst => rst,
        imem_addr => imem_addr, imem_instr => imem_instr,
        dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
        dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
        dbg_pc => dbg_pc);

    imem_comb <= PROGS(k)(to_integer(unsigned(imem_addr(4 downto 2))));
    g_a : if not SYNC_MEM generate imem_instr <= imem_comb; end generate;
    g_s : if SYNC_MEM generate imem_instr <= imem_comb when rising_edge(clk); end generate;

    u_dmem : entity work.dmem
      generic map (DEPTH => 16, SYNC_READ => SYNC_MEM)
      port map (clk => clk, addr => dmem_addr, wdata => dmem_wdata,
                wstrb => dmem_wstrb, rdata => dmem_rdata);

    process(clk) begin
      if rising_edge(clk) and rst = '0' then
        if dbg_pc = HALT_PC and t_halt(k) = 0 then t_halt(k) <= cycle; end if;
        if dmem_wstrb = "1111" and dmem_addr = x"00000008" then stored(k) <= dmem_wdata; end if;
      end if;
    end process;
  end generate;

  stim : process
    variable errors : natural := 0;
    procedure chk (constant ok : boolean; constant name : string) is
    begin
      if ok then report "PASS " & name severity note;
      else report "FAIL " & name severity error; errors := errors + 1; end if;
    end procedure;
  begin
    rst <= '1';
    wait for 3*TCK;
    wait until rising_edge(clk);
    rst <= '0';
    for i in 0 to 100 loop wait until rising_edge(clk); end loop;
    report "halt cycles: P0=" & integer'image(t_halt(0)) & " P1=" & integer'image(t_halt(1)) &
           " P2=" & integer'image(t_halt(2)) & " P3=" & integer'image(t_halt(3));
    chk(t_halt(2) > 0, "reference program finished");
    chk(t_halt(0) = t_halt(2), "LUI with rs1 field = load rd: no load-use stall");
    chk(t_halt(1) = t_halt(2), "ADDI with rs2 field = load rd: no load-use stall");
    chk(t_halt(3) = t_halt(2) + 1, "true dependency: exactly one stall cycle");
    chk(stored(0) = x"00008000", "P0 result");
    chk(stored(1) = x"00000001", "P1 result");
    chk(stored(2) = x"00000000", "P2 result");
    chk(stored(3) = x"00000000", "P3 result (x1 = mem[0] = 0)");
    if errors = 0 then report "TB_LU_STALL_PASS" severity note;
    else report integer'image(errors) & " TEST(S) FALLARON" severity error; end if;
    done <= true;
    wait;
  end process;
end architecture sim;
