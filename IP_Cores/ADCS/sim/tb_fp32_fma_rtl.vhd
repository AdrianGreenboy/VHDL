-- ============================================================================
-- tb_fp32_fma_rtl.vhd -- audit 2026-11: bit-exactness of the synthesizable
-- fp32_fma_rtl against the numeric contract fp32_pkg.fma_fp32 (480-bit exact
-- reference). Throughput 1 vector/cycle, pipeline latency checked.
--
-- Vector classes (N_RAND random vectors, cycling through the classes) plus a
-- directed corner list:
--   0 raw 32-bit random (NaN/Inf/denormal inputs included)
--   1 normal operands, exponents near each other
--   2 cancellation: c = -(a*b) (from the reference) +- a few ulps
--   3 sparse mantissas (exact products, frequent rounding ties)
--   4 underflow region: result exponent around 2^-126 (FTZ boundary)
--   5 overflow region: result exponent around 2^127 / 2^128
--   6 alignment extremes: exponent of c minus exponent of a*b in [-80, 80]
--   7 specials mixed with normals (zeros of both signs, Inf, NaN, denormal)
-- Directed: signed zeros, Inf*0, Inf-Inf, ties to even both ways, carry out
-- of rounding into a new binade, rounding up to the smallest normal, largest
-- finite + rounding to Inf, exact cancellation, product-vs-addend clamp.
-- Self-checking: first mismatch reported; severity failure at the end.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.fp32_pkg.all;

entity tb_fp32_fma_rtl is
  generic (
    N_RAND  : natural := 200000;
    LAT_FMA : natural := 8;
    MUT     : natural := 0
  );
end entity;

architecture sim of tb_fp32_fma_rtl is
  constant TCLK : time := 4 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal rst_n : std_logic := '0';
  signal in_valid, out_valid : std_logic := '0';
  signal a, b, c, result : std_logic_vector(31 downto 0) := (others => '0');

  -- expected-result FIFO (in-flight vectors)
  type slv_arr is array (0 to 63) of std_logic_vector(31 downto 0);
  signal exp_q : slv_arr;
  signal arg_a, arg_b, arg_c : slv_arr;
  signal wp : natural := 0;
  signal n_chk, n_err : natural := 0;
  signal sent_all : boolean := false;
  signal n_sent : natural := 0;
begin
  clk <= not clk after TCLK/2 when not fin else '0';

  dut : entity work.fp32_fma_rtl
    generic map (LAT_FMA => LAT_FMA, MUT => MUT)
    port map (clk => clk, rst_n => rst_n, in_valid => in_valid,
              a => a, b => b, c => c, out_valid => out_valid, result => result);

  stim : process
    variable s1 : positive := 12345; variable s2 : positive := 6789;
    variable r : real;
    variable va, vb, vc, p : std_logic_vector(31 downto 0);
    variable k, cls : natural;
    variable e : integer;

    impure function rnd(n : natural) return natural is   -- uniform 0 .. n-1
    begin
      uniform(s1, s2, r);
      return natural(floor(r * real(n))) mod n;
    end function;
    impure function rbits(nb : natural) return std_logic_vector is
      variable v : std_logic_vector(nb-1 downto 0);
    begin
      for i in 0 to nb-1 loop
        uniform(s1, s2, r);
        if r < 0.5 then v(i) := '0'; else v(i) := '1'; end if;
      end loop;
      return v;
    end function;
    impure function mk(s : std_logic; ex : integer; m : std_logic_vector(22 downto 0))
      return std_logic_vector is
      variable ee : integer := ex;
    begin
      if ee < 0 then ee := 0; end if;
      if ee > 255 then ee := 255; end if;
      return s & std_logic_vector(to_unsigned(ee, 8)) & m;
    end function;
    impure function sparse return std_logic_vector is
      variable m : std_logic_vector(22 downto 0) := (others => '0');
      variable nb : natural;
    begin
      nb := rnd(9);
      for i in 0 to 22 loop
        if i >= 23 - nb then m(i) := rbits(1)(0); end if;
      end loop;
      return m;
    end function;

    procedure push(x, y, z : std_logic_vector(31 downto 0)) is
    begin
      a <= x; b <= y; c <= z; in_valid <= '1';
      exp_q(wp mod 64) <= fma_fp32(x, y, z, 0);
      arg_a(wp mod 64) <= x; arg_b(wp mod 64) <= y; arg_c(wp mod 64) <= z;
      wp <= wp + 1;
      wait until rising_edge(clk);
    end procedure;

    type dir_t is array (natural range <>) of std_logic_vector(95 downto 0);
    constant DIR : dir_t := (
      x"000000000000000000000000",   -- +0*+0 + +0
      x"800000000000000080000000",   -- -0 + -0 -> -0
      x"800000000000000000000000",   -- -0 + +0 -> +0
      x"3F8000000000000080000000",   -- 1*0 - 0 -> +0
      x"7F800000000000003F800000",   -- Inf*0 -> qNaN
      x"7F8000003F800000FF800000",   -- Inf - Inf -> qNaN
      x"7F800000BF8000007F800000",   -- -Inf + Inf -> qNaN
      x"FF800000BF8000003F800000",   -- -Inf*-1 + 1 -> +Inf
      x"3F8000003F8000007F800000",   -- 1 + Inf -> Inf
      x"7FC000013F8000003F800000",   -- NaN -> canonical
      x"3F8000007F8000013F800000",   -- sNaN -> canonical
      x"004000007F00000000000000",   -- denormal input -> 0
      x"3F8000003F80000000000001",   -- 1 + denormal(=0) -> 1
      x"3F8000003F800000BF800000",   -- exact cancellation -> +0
      x"BF8000003F8000003F800000",   -- -1 + 1 -> +0
      x"3F8000013F800001BF800002",   -- (1+u)^2 - (1+2u) = u^2
      x"3F8000003F80000033800000",   -- 1 + 2^-24: tie -> even (1)
      x"3F8000013F80000033800000",   -- (1+u) + 2^-24: tie -> even (up)
      x"3F7FFFFF3F80000033800000",   -- carry into new binade
      x"3FFFFFFF3FFFFFFF00000000",   -- max mantissa square
      x"008000003F7FFFFF00000000",   -- below min normal -> FTZ 0
      x"008000003F80000000000000",   -- min normal exactly
      x"00FFFFFF3F7FFFFF00000000",   -- rounds up to min normal?
      x"808000003F00000000000000",   -- -tiny -> -0 (FTZ keeps sign)
      x"7F7FFFFF3F80000073800000",   -- max + half ulp: tie -> Inf? (even)
      x"7F7FFFFF3F80000100000000",   -- overflow by rounding
      x"7F7FFFFF40000000FF7FFFFF",   -- 2max - max = max
      x"4B8000004B8000003F800000",   -- 2^48 + 1 (C below product)
      x"3F8000003F8000005F800000",   -- C >> P (clamp path)
      x"3F8000003F800000DF800000",   -- -C >> P, C power of two
      x"3F800000BF8000005F800000",   -- C - tiny, C power of two
      x"3F800000BF8000005F800001",   -- C - tiny, C not pow2
      x"3FC000003FC00000C0100000",   -- 2.25 - 2.25 -> +0
      x"3F8000003F800000B3800000",   -- 1 - 2^-24 (exact)
      x"3F8000003F800000B3000000",   -- 1 - 2^-25: tie below 1
      x"3F8000003F800000B3000001");  -- 1 - (2^-25+): rounds down
  begin
    rst_n <= '0';
    for i in 0 to 4 loop wait until rising_edge(clk); end loop;
    rst_n <= '1';
    wait until rising_edge(clk);

    for i in DIR'range loop
      push(DIR(i)(95 downto 64), DIR(i)(63 downto 32), DIR(i)(31 downto 0));
    end loop;

    for n in 0 to N_RAND-1 loop
      cls := n mod 8;
      case cls is
        when 0 =>
          va := rbits(32); vb := rbits(32); vc := rbits(32);
        when 1 =>
          e := 100 + rnd(60);
          va := mk(rbits(1)(0), e, rbits(23));
          vb := mk(rbits(1)(0), 127 - 10 + rnd(20), rbits(23));
          vc := mk(rbits(1)(0), e - 30 + rnd(60), rbits(23));
        when 2 =>
          va := mk(rbits(1)(0), 100 + rnd(60), rbits(23));
          vb := mk(rbits(1)(0), 100 + rnd(60), rbits(23));
          p  := fma_fp32(va, vb, x"00000000", 0);
          if p(30 downto 23) = x"00" or p(30 downto 23) = x"FF" then
            vc := rbits(32);
          else
            vc := std_logic_vector(signed(p) + to_signed(rnd(9) - 4, 32));
            vc(31) := not p(31);
          end if;
        when 3 =>
          e := 110 + rnd(40);
          va := mk(rbits(1)(0), e, sparse);
          vb := mk(rbits(1)(0), 127 - 4 + rnd(8), sparse);
          vc := mk(rbits(1)(0), e - 26 + rnd(52), sparse);
        when 4 =>
          e := rnd(20) + 1;                        -- ea + eb - 127 in ~[-20, 20]
          va := mk(rbits(1)(0), 63 + e, rbits(23));
          vb := mk(rbits(1)(0), 63 - 20 + rnd(30), rbits(23));
          if rnd(2) = 0 then vc := x"00000000";
          else vc := mk(rbits(1)(0), rnd(4), rbits(23)); end if;
        when 5 =>
          va := mk(rbits(1)(0), 190 + rnd(10), rbits(23));
          vb := mk(rbits(1)(0), 185 + rnd(10), rbits(23));
          vc := mk(rbits(1)(0), 245 + rnd(10), rbits(23));
        when 6 =>
          va := mk(rbits(1)(0), 100 + rnd(50), rbits(23));
          vb := mk(rbits(1)(0), 127 - 10 + rnd(20), rbits(23));
          e := to_integer(unsigned(va(30 downto 23))) + to_integer(unsigned(vb(30 downto 23))) - 127;
          vc := mk(rbits(1)(0), e - 80 + rnd(161), rbits(23));
        when others =>
          case rnd(6) is
            when 0 => va := rbits(1) & "0000000000000000000000000000000";
            when 1 => va := rbits(1) & x"FF" & "00000000000000000000000";
            when 2 => va := rbits(1) & x"00" & rbits(23);
            when 3 => va := rbits(1) & x"FF" & rbits(23);
            when others => va := mk(rbits(1)(0), 1 + rnd(254), rbits(23));
          end case;
          vb := mk(rbits(1)(0), 1 + rnd(254), rbits(23));
          case rnd(5) is
            when 0 => vc := rbits(1) & "0000000000000000000000000000000";
            when 1 => vc := rbits(1) & x"FF" & "00000000000000000000000";
            when 2 => vc := rbits(1) & x"00" & rbits(23);
            when others => vc := mk(rbits(1)(0), 1 + rnd(254), rbits(23));
          end case;
      end case;
      push(va, vb, vc);
      n_sent <= n + 1;
    end loop;
    in_valid <= '0';
    sent_all <= true;
    wait;
  end process;

  chk : process
    variable rp : natural := 0;
    variable lat : natural := 0;
    variable first_in : boolean := true;
  begin
    wait until rising_edge(clk);
    if out_valid = '1' then
      if result /= exp_q(rp mod 64) then
        if n_err < 10 then
          report "MISMATCH #" & integer'image(rp) & " a=" & to_hstring(arg_a(rp mod 64)) &
                 " b=" & to_hstring(arg_b(rp mod 64)) & " c=" & to_hstring(arg_c(rp mod 64)) &
                 " rtl=" & to_hstring(result) & " ref=" & to_hstring(exp_q(rp mod 64))
            severity warning;
        end if;
        n_err <= n_err + 1;
      end if;
      rp := rp + 1;
      n_chk <= rp;
    end if;
    if sent_all and rp = wp then
      wait until rising_edge(clk);
      report "TB_FP32_FMA_RTL checked=" & integer'image(rp) & " errors=" &
             integer'image(n_err) & " LAT=" & integer'image(LAT_FMA);
      assert n_err = 0 report "TB_FP32_FMA_RTL FAIL" severity failure;
      report "TB_FP32_FMA_RTL PASS";
      fin <= true;
      wait;
    end if;
  end process;

  -- latency check: the first valid output must appear exactly LAT_FMA cycles
  -- after the first valid input
  latchk : process
    variable t0 : time;
  begin
    wait until rising_edge(clk) and in_valid = '1';
    t0 := now;
    wait until rising_edge(clk) and out_valid = '1';
    assert now - t0 = LAT_FMA * TCLK
      report "TB_FP32_FMA_RTL: latency " & time'image(now - t0) & " /= LAT_FMA" severity failure;
    wait;
  end process;
end architecture;
