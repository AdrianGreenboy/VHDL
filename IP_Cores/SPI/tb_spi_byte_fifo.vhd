-- =============================================================================
--  tb_spi_byte_fifo.vhd - Self-checking equivalence test of spi_byte_fifo (audit 2026-11)
--
--  Compares spi_byte_fifo cycle by cycle against a behavioural reference of the
--  former FWFT byte_fifo (combinational head read) under constrained-random
--  push/pop traffic, including push+pop on empty/full, flush (clr) and
--  synchronous reset. Checks rd_data (whenever not empty), empty, full and
--  level every cycle. Also checks the deterministic x"00" head when empty.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

entity tb_spi_byte_fifo is
end entity;

architecture sim of tb_spi_byte_fifo is
  constant L2 : natural := 3;                      -- 8 entries: hits full often
  constant D  : natural := 2**L2;
  signal clk, rst, clr : std_logic := '0';
  signal wr_en, rd_en  : std_logic := '0';
  signal wr_data, rd_data : std_logic_vector(7 downto 0) := (others => '0');
  signal full, empty : std_logic;
  signal level : unsigned(L2 downto 0);
  signal done_s : boolean := false;
begin
  clk <= not clk after 5 ns when not done_s;

  dut : entity work.spi_byte_fifo
    generic map (LOG2_DEPTH => L2)
    port map (clk => clk, rst => rst, clr => clr,
              wr_en => wr_en, wr_data => wr_data, full => full,
              rd_en => rd_en, rd_data => rd_data, empty => empty,
              level => level);

  stim : process
    type arr_t is array (0 to D-1) of std_logic_vector(7 downto 0);
    variable m : arr_t := (others => (others => '0'));
    variable wp, rp, n : natural := 0;
    variable s1, s2 : positive := 7;
    variable r : real;
    variable errs, pushes, pops, fulls, bypass : natural := 0;
    variable vw, vr, vc, vrs : std_logic;
    variable vd : std_logic_vector(7 downto 0);
  begin
    rst <= '1';
    wait until rising_edge(clk); wait until rising_edge(clk);
    rst <= '0';
    for cyc in 0 to 20000 loop
      -- drive random stimulus for this cycle (biased phases)
      uniform(s1, s2, r);
      if (cyc / 500) mod 3 = 0 then vw := '1' when r < 0.7 else '0';
      elsif (cyc / 500) mod 3 = 1 then vw := '1' when r < 0.3 else '0';
      else vw := '1' when r < 0.5 else '0'; end if;
      uniform(s1, s2, r);
      if (cyc / 500) mod 3 = 0 then vr := '1' when r < 0.3 else '0';
      elsif (cyc / 500) mod 3 = 1 then vr := '1' when r < 0.7 else '0';
      else vr := '1' when r < 0.5 else '0'; end if;
      uniform(s1, s2, r);
      vc  := '1' when r < 0.002 else '0';
      uniform(s1, s2, r);
      vrs := '1' when r < 0.001 else '0';
      uniform(s1, s2, r);
      vd := std_logic_vector(to_unsigned(integer(trunc(r * 255.0)), 8));
      wr_en <= vw; rd_en <= vr; clr <= vc; rst <= vrs; wr_data <= vd;
      wait for 1 ns;
      -- check outputs against the model state BEFORE this edge
      if (empty = '1') /= (n = 0) or (full = '1') /= (n = D) or
         to_integer(level) /= n then
        errs := errs + 1;
        report "flags/level mismatch at cycle " & integer'image(cyc) &
               " model n=" & integer'image(n) severity error;
      end if;
      if n > 0 and rd_data /= m(rp) then
        errs := errs + 1;
        report "rd_data mismatch at cycle " & integer'image(cyc) severity error;
      end if;
      if n = 0 and rd_data /= x"00" then
        errs := errs + 1;
        report "empty head not x00 at cycle " & integer'image(cyc) severity error;
      end if;
      wait until rising_edge(clk);
      -- update the reference model (old byte_fifo semantics)
      if vrs = '1' or vc = '1' then
        wp := 0; rp := 0; n := 0;
      else
        if vw = '1' and n /= D then
          if n = 0 or (n = 1 and vr = '1') then bypass := bypass + 1; end if;
          m(wp) := vd; wp := (wp + 1) mod D; pushes := pushes + 1;
        end if;
        if vw = '1' and n = D then fulls := fulls + 1; end if;
        if vr = '1' and n /= 0 then
          rp := (rp + 1) mod D; pops := pops + 1;
        end if;
        if (vw = '1' and n /= D) and not (vr = '1' and n /= 0) then
          n := n + 1;
        elsif not (vw = '1' and n /= D) and (vr = '1' and n /= 0) then
          n := n - 1;
        end if;
      end if;
    end loop;
    report "pushes=" & integer'image(pushes) & " pops=" & integer'image(pops) &
           " push-on-full=" & integer'image(fulls) &
           " bypass=" & integer'image(bypass);
    assert errs = 0 report "tb_spi_byte_fifo: FAILED with " & integer'image(errs) &
                           " mismatches" severity failure;
    assert fulls > 50 and bypass > 50 and pops > 5000
      report "tb_spi_byte_fifo: insufficient corner coverage" severity failure;
    report "tb_spi_byte_fifo: ALL TESTS PASSED";
    done_s <= true;
    wait;
  end process;
end architecture sim;
