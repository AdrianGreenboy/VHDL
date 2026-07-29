-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3 support testbench
-- tb_basemul: validates basemul_k against vectors generated from the
-- ACVP-validated oracle (FIPS 203 Algorithms 11, 12).
--
-- Both modes are exercised: plain write and accumulate. Accumulate is what
-- the matrix-vector products of KeyGen and Encaps rely on, so running it only
-- in the algorithm FSM would leave it untested at unit level.
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_tables_pkg.all;

entity tb_basemul is
  generic (
    G_VFILE : string := "basemul_vectors.txt");
end entity tb_basemul;

architecture sim of tb_basemul is

  constant C_PERIOD : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal sim_done : boolean := false;

  signal start   : std_logic := '0';
  signal accum   : std_logic := '0';
  signal a_addr  : std_logic_vector(7 downto 0);
  signal a_data  : std_logic_vector(15 downto 0) := (others => '0');
  signal b_addr  : std_logic_vector(7 downto 0);
  signal b_data  : std_logic_vector(15 downto 0) := (others => '0');
  signal d_addr  : std_logic_vector(7 downto 0);
  signal d_rdata : std_logic_vector(15 downto 0) := (others => '0');
  signal d_wdata : std_logic_vector(15 downto 0);
  signal d_we    : std_logic;
  signal done    : std_logic;

  type t_mem is array (0 to 255) of integer;
  signal mem_a : t_mem := (others => 0);
  signal mem_b : t_mem := (others => 0);
  signal mem_d : t_mem := (others => 0);

  signal ld_en   : std_logic := '0';
  signal ld_sel  : integer range 0 to 2 := 0;
  signal ld_addr : integer range 0 to 255 := 0;
  signal ld_val  : integer := 0;

  signal rb_addr : integer range 0 to 255 := 0;
  signal rb_val  : integer := 0;

  function to_hex (v : unsigned(63 downto 0)) return string is
    constant D : string(1 to 16) := "0123456789abcdef";
    variable r : string(1 to 16);
  begin
    for i in 0 to 15 loop
      r(16 - i) := D(to_integer(v(4 * i + 3 downto 4 * i)) + 1);
    end loop;
    return r;
  end function to_hex;

begin

  clk <= not clk after C_PERIOD / 2 when not sim_done else '0';

  u_dut : entity work.basemul_k
    port map (clk => clk, rst_n => rst_n, start => start, accum => accum,
              a_addr => a_addr, a_data => a_data,
              b_addr => b_addr, b_data => b_data,
              d_addr => d_addr, d_rdata => d_rdata,
              d_wdata => d_wdata, d_we => d_we,
              busy => open, done => done);

  mem_proc : process (clk)
  begin
    if rising_edge(clk) then
      if ld_en = '1' then
        case ld_sel is
          when 0 => mem_a(ld_addr) <= ld_val;
          when 1 => mem_b(ld_addr) <= ld_val;
          when others => mem_d(ld_addr) <= ld_val;
        end case;
      elsif d_we = '1' then
        mem_d(to_integer(unsigned(d_addr))) <= to_integer(signed(d_wdata));
      end if;
      a_data  <= std_logic_vector(
                   to_signed(mem_a(to_integer(unsigned(a_addr))), 16));
      b_data  <= std_logic_vector(
                   to_signed(mem_b(to_integer(unsigned(b_addr))), 16));
      d_rdata <= std_logic_vector(
                   to_signed(mem_d(to_integer(unsigned(d_addr))), 16));
      rb_val  <= mem_d(rb_addr);
    end if;
  end process;

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable n      : integer := 0;
    variable v      : integer;
    type t_poly is array (0 to 255) of integer;
    variable pa, pb, pc : t_poly;

    procedure wait_clk (k : integer := 1) is
    begin
      for i in 1 to k loop
        wait until rising_edge(clk);
      end loop;
    end procedure wait_clk;

    procedure sig_update (variable s : inout unsigned(63 downto 0);
                          x : in integer) is
      variable u : unsigned(63 downto 0);
      variable w : unsigned(31 downto 0);
    begin
      w := to_unsigned(x, 32);
      for i in 0 to 3 loop
        u := s xor resize(w(8 * i + 7 downto 8 * i), 64);
        u := u + shift_left(u, 1) + shift_left(u, 4) + shift_left(u, 5) +
             shift_left(u, 7) + shift_left(u, 8) + shift_left(u, 40);
        s := u;
      end loop;
    end procedure sig_update;

    procedure load (sel : in integer; p : in t_poly) is
    begin
      for i in 0 to 255 loop
        ld_sel  <= sel;
        ld_addr <= i;
        if p(i) > C_QK / 2 then
          ld_val <= p(i) - C_QK;
        else
          ld_val <= p(i);
        end if;
        ld_en <= '1';
        wait_clk(1);
      end loop;
      ld_en <= '0';
      wait_clk(1);
    end procedure load;

  begin
    rst_n <= '0';
    wait_clk(4);
    rst_n <= '1';
    wait_clk(2);

    file_open(status, fp, G_VFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open basemul vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      for i in 0 to 255 loop
        read(ln, pa(i));
      end loop;
      readline(fp, ln);
      for i in 0 to 255 loop
        read(ln, pb(i));
      end loop;
      readline(fp, ln);
      for i in 0 to 255 loop
        read(ln, pc(i));
      end loop;

      ----------------------------------------------------------------
      -- plain mode: destination is overwritten
      ----------------------------------------------------------------
      load(0, pa);
      load(1, pb);
      for i in 0 to 255 loop
        ld_sel <= 2; ld_addr <= i; ld_val <= 0; ld_en <= '1';
        wait_clk(1);
      end loop;
      ld_en <= '0';
      wait_clk(1);

      accum <= '0';
      start <= '1';
      wait_clk(1);
      start <= '0';
      while done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);

      for i in 0 to 255 loop
        rb_addr <= i;
        wait_clk(2);
        v := rb_val;
        if v < 0 then
          v := v + C_QK;
        end if;
        assert v = pc(i)
          report "TB FAIL basemul plain vector " & integer'image(n) &
                 " coef " & integer'image(i) &
                 " got=" & integer'image(v) &
                 " exp=" & integer'image(pc(i))
          severity failure;
        sig_update(sig, v);
      end loop;

      ----------------------------------------------------------------
      -- accumulate mode: running the same product twice into a zeroed
      -- destination must give exactly twice the product, mod q
      ----------------------------------------------------------------
      for i in 0 to 255 loop
        ld_sel <= 2; ld_addr <= i; ld_val <= 0; ld_en <= '1';
        wait_clk(1);
      end loop;
      ld_en <= '0';
      wait_clk(1);

      for pass in 1 to 2 loop
        accum <= '1';
        start <= '1';
        wait_clk(1);
        start <= '0';
        while done = '0' loop
          wait_clk(1);
        end loop;
        wait_clk(2);
      end loop;

      for i in 0 to 255 loop
        rb_addr <= i;
        wait_clk(2);
        v := rb_val;
        if v < 0 then
          v := v + C_QK;
        end if;
        assert v = (2 * pc(i)) mod C_QK
          report "TB FAIL basemul accum vector " & integer'image(n) &
                 " coef " & integer'image(i) &
                 " got=" & integer'image(v) &
                 " exp=" & integer'image((2 * pc(i)) mod C_QK)
          severity failure;
        sig_update(sig, v);
      end loop;

      n := n + 1;
    end loop;
    file_close(fp);

    report "PQC L3 BASEMUL PASS vectors=" & integer'image(n) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
