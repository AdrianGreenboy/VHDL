-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- tb_sampler_d: verifies the four ML-DSA samplers against oracle vectors.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Thirty-two cases, eight per mode, each compared coefficient by coefficient
-- against mldsa65.py.
--
-- The vector file supplies the SQUEEZE STREAM rather than the seed. The
-- sponge is already silicon-validated from the ML-KEM phase, so re-verifying
-- it here would test the wrong thing; what is under test is the sampler's
-- interpretation of the stream. A simple stream model stands in for the
-- sponge and asserts if a sampler reads past the supplied budget, which is
-- how an unbounded rejection loop would show up.
--
-- Coefficients are compared canonically, reduced into [0, q). The samplers
-- emit signed representatives, matching the rest of the ML-DSA datapath.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_d_tables_pkg.all;

entity tb_sampler_d is
end entity tb_sampler_d;

architecture sim of tb_sampler_d is

  function to_hex (v : unsigned(63 downto 0)) return string is
    constant D : string(1 to 16) := "0123456789abcdef";
    variable r : string(1 to 16);
  begin
    for i in 0 to 15 loop
      r(16 - i) := D(to_integer(v(4 * i + 3 downto 4 * i)) + 1);
    end loop;
    return r;
  end function to_hex;

  function hex_nib (c : character) return integer is
  begin
    case c is
      when '0' => return 0;   when '1' => return 1;   when '2' => return 2;
      when '3' => return 3;   when '4' => return 4;   when '5' => return 5;
      when '6' => return 6;   when '7' => return 7;   when '8' => return 8;
      when '9' => return 9;   when 'a' => return 10;  when 'b' => return 11;
      when 'c' => return 12;  when 'd' => return 13;  when 'e' => return 14;
      when others => return 15;
    end case;
  end function hex_nib;

  constant C_MAXSTREAM : integer := 1008;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';

  signal start : std_logic := '0';
  signal mode  : std_logic_vector(1 downto 0) := "00";
  signal done  : std_logic;
  signal busy  : std_logic;

  signal sp_dout   : std_logic_vector(7 downto 0) := (others => '0');
  signal sp_re     : std_logic;
  signal sp_dvalid : std_logic := '1';

  signal p_waddr : std_logic_vector(7 downto 0);
  signal p_wdata : std_logic_vector(C_CW - 1 downto 0);
  signal p_we    : std_logic;
  signal p_raddr : std_logic_vector(7 downto 0);
  signal p_rdata : std_logic_vector(C_CW - 1 downto 0);

  -- the stream standing in for the sponge
  type t_stream is array (0 to C_MAXSTREAM - 1) of integer;
  signal stream  : t_stream := (others => 0);
  signal spos    : integer := 0;
  signal spos_rst : std_logic := '0';
  signal sbudget : integer := 0;

  -- destination polynomial, written by the sampler and read back by the TB
  type t_poly is array (0 to 255) of integer;
  signal poly : t_poly := (others => 0);

begin

  clk <= not clk after 5 ns;

  dut : entity work.sampler_d
    port map (clk => clk, rst_n => rst_n, start => start, mode => mode,
              done => done, busy => busy,
              sp_dout => sp_dout, sp_re => sp_re, sp_dvalid => sp_dvalid,
              p_waddr => p_waddr, p_wdata => p_wdata, p_we => p_we,
              p_raddr => p_raddr, p_rdata => p_rdata);

  -- Stream model: presents stream(spos) and advances on sp_re. Running past
  -- the supplied budget is a failure, not a wrap, because that is exactly how
  -- a rejection loop that never terminates would present itself.
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' or spos_rst = '1' then
        spos <= 0;
      elsif sp_re = '1' then
        -- Reading the last supplied byte is legal; reading beyond it is not.
        -- ExpandMask consumes its budget EXACTLY (640 of 640), so an
        -- off-by-one here fails on correct RTL.
        assert spos < sbudget
          report "TB FAIL sampler read past the stream budget of " &
                 integer'image(sbudget) & " bytes"
          severity failure;
        spos <= spos + 1;
      end if;
    end if;
  end process;

  sp_dout <= std_logic_vector(to_unsigned(stream(spos), 8));

  -- polynomial storage with a one-cycle synchronous read, matching poly_mem_d
  process (clk)
  begin
    if rising_edge(clk) then
      if p_we = '1' then
        poly(to_integer(unsigned(p_waddr))) <= to_integer(signed(p_wdata));
      end if;
      p_rdata <= std_logic_vector(
                   to_signed(poly(to_integer(unsigned(p_raddr))), C_CW));
    end if;
  end process;

  process
    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 4);
    variable c   : character;
    variable ch1, ch2 : character;
    variable v   : integer;
    variable n   : integer := 0;
    variable na, nb, nm, nc : integer := 0;
    variable sig : unsigned(63 downto 0) := x"cbf29ce484222325";
    variable exp : t_poly;
    variable bud : integer;

    procedure wait_clk (k : integer) is
    begin
      for i in 1 to k loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure fnv (variable s : inout unsigned(63 downto 0);
                   constant x : in integer) is
      variable u : unsigned(31 downto 0);
      variable b : unsigned(63 downto 0);
    begin
      u := unsigned(to_signed(x, 32));
      for k in 0 to 3 loop
        b := resize(u((k * 8 + 7) downto (k * 8)), 64);
        s := s xor b;
        s := resize(s * x"00000100000001b3", 64);
      end loop;
    end procedure;

    function canon (x : integer) return integer is
      variable r : integer;
    begin
      r := x mod C_QD;
      if r < 0 then
        r := r + C_QD;
      end if;
      return r;
    end function canon;

  begin
    rst_n <= '0';
    wait_clk(5);
    rst_n <= '1';
    wait_clk(5);

    file_open(fh, "dsa_samp_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length < 4 then
        next;
      end if;
      read(ln, tag);
      if tag(1) = '#' then
        next;
      end if;

      if tag = "SNTT" then
        mode <= "00"; bud := 1008;
      elsif tag = "SBND" then
        mode <= "01"; bud := 544;
      elsif tag = "SMSK" then
        mode <= "10"; bud := 640;
      elsif tag = "SBAL" then
        mode <= "11"; bud := 400;
      else
        next;
      end if;

      read(ln, c);
      for i in 0 to bud - 1 loop
        read(ln, ch1);
        read(ln, ch2);
        stream(i) <= hex_nib(ch1) * 16 + hex_nib(ch2);
      end loop;
      sbudget <= bud;
      for i in 0 to 255 loop
        read(ln, exp(i));
      end loop;
      wait_clk(2);

      start <= '1';
      wait_clk(1);
      start <= '0';
      while done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);

      for i in 0 to 255 loop
        v := poly(i);
        assert canon(v) = exp(i)
          report "TB FAIL " & tag & " case " & integer'image(n) &
                 " coeff " & integer'image(i) &
                 " got=" & integer'image(canon(v)) &
                 " exp=" & integer'image(exp(i))
          severity failure;
        fnv(sig, canon(v));
      end loop;

      if tag = "SNTT" then
        na := na + 1;
      elsif tag = "SBND" then
        nb := nb + 1;
      elsif tag = "SMSK" then
        nm := nm + 1;
      else
        nc := nc + 1;
      end if;
      n := n + 1;

      -- Advance the stream WITHOUT a reset for SampleInBall cases.
      --
      -- Resetting between every vector hid a real defect: sgn is OR-ed in
      -- and was cleared only on reset, so a second SampleInBall accumulated
      -- the previous call's sign bits and flipped a handful of signs in c.
      -- The first call was always clean, which is exactly what a
      -- reset-between-vectors testbench cannot distinguish. Sign runs the
      -- sampler once per rejection-loop iteration with no reset, so this is
      -- the condition that matters.
      if tag = "SBAL" and nc > 0 then
        spos_rst <= '1';
        wait_clk(2);
        spos_rst <= '0';
        wait_clk(2);
      else
        rst_n <= '0';
        wait_clk(2);
        rst_n <= '1';
        wait_clk(2);
      end if;
    end loop;
    file_close(fh);

    assert na = 9 and nb = 8 and nm = 8 and nc = 8
      report "TB FAIL expected 9 ntt and 8 of each other mode, got " &
             integer'image(na) & " " & integer'image(nb) & " " &
             integer'image(nm) & " " & integer'image(nc)
      severity failure;

    report "PQC L3B SAMPD PASS ntt=" & integer'image(na) &
           " bnd=" & integer'image(nb) &
           " msk=" & integer'image(nm) &
           " ball=" & integer'image(nc) &
           " sig=" & to_hex(sig)
      severity note;
    wait;
  end process;

end architecture sim;
