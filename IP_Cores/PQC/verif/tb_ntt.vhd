-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1 testbench
-- tb_ntt: validates ntt_unit for both parameter sets.
--   NTT-K : q = 3329,    R = 2^16, 7 layers
--   NTT-D : q = 8380417, R = 2^32, 8 layers
-- VHDL-2008. ASCII-only asserts. MIT license.
--
-- Checks per vector:
--   1. forward NTT matches the reference vector coefficient by coefficient
--   2. inverse NTT of the forward result returns the original polynomial
-- PASS criterion: all vectors match AND the end-of-simulation signature is
-- bit-identical. The signature is a data-dependent FNV-1a over every
-- coefficient produced, never over cycle counts.
--
-- The coefficient memory is modelled as an array of integer, following the
-- rule established during boot validation: aggregate initialisers over large
-- std_logic_vector arrays make GHDL segfault.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_tables_pkg.all;

entity tb_ntt is
  generic (
    G_KFILE : string := "ntt_k_vectors.txt";
    G_DFILE : string := "ntt_d_vectors.txt");
end entity tb_ntt;

architecture sim of tb_ntt is

  constant C_PERIOD : time := 10 ns;
  constant C_WK     : integer := 16;
  constant C_WD     : integer := 32;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal sim_done : boolean := false;

  -- NTT-K instance
  signal k_start   : std_logic := '0';
  signal k_inv     : std_logic := '0';
  signal k_rd_addr : std_logic_vector(7 downto 0);
  signal k_rd_data : std_logic_vector(C_WK - 1 downto 0) := (others => '0');
  signal k_wr_addr : std_logic_vector(7 downto 0);
  signal k_wr_data : std_logic_vector(C_WK - 1 downto 0);
  signal k_wr_en   : std_logic;
  signal k_busy    : std_logic;
  signal k_done    : std_logic;

  -- NTT-D instance
  signal d_start   : std_logic := '0';
  signal d_inv     : std_logic := '0';
  signal d_rd_addr : std_logic_vector(7 downto 0);
  signal d_rd_data : std_logic_vector(C_WD - 1 downto 0) := (others => '0');
  signal d_wr_addr : std_logic_vector(7 downto 0);
  signal d_wr_data : std_logic_vector(C_WD - 1 downto 0);
  signal d_wr_en   : std_logic;
  signal d_busy    : std_logic;
  signal d_done    : std_logic;

  -- Coefficient memories, modelled as integer arrays.
  type t_mem is array (0 to 255) of integer;
  signal mem_k : t_mem := (others => 0);
  signal mem_d : t_mem := (others => 0);

  -- Dedicated preload port. The memory processes are the only drivers of
  -- mem_k / mem_d; the stimulus process loads through these signals instead,
  -- otherwise the arrays would have two drivers and resolve to nothing.
  signal ld_en   : std_logic := '0';
  signal ld_addr : integer range 0 to 255 := 0;
  signal ld_k    : integer := 0;
  signal ld_d    : integer := 0;

  -- Readback port so the stimulus process can inspect memory contents.
  signal rb_addr : integer range 0 to 255 := 0;
  signal rb_k    : integer := 0;
  signal rb_d    : integer := 0;

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

  u_ntt_k : entity work.ntt_unit
    generic map (G_Q => C_QK, G_QINV => C_QINVK, G_RBITS => 16,
                 G_WIDTH => C_WK, G_LAYERS => 7, G_SCALE => C_SK)
    port map (clk => clk, rst_n => rst_n, start => k_start, inverse => k_inv,
              rd_addr => k_rd_addr, rd_data => k_rd_data,
              wr_addr => k_wr_addr, wr_data => k_wr_data, wr_en => k_wr_en,
              busy => k_busy, done => k_done);

  u_ntt_d : entity work.ntt_unit
    generic map (G_Q => C_QD, G_QINV => C_QINVD, G_RBITS => 32,
                 G_WIDTH => C_WD, G_LAYERS => 8, G_SCALE => C_SD)
    port map (clk => clk, rst_n => rst_n, start => d_start, inverse => d_inv,
              rd_addr => d_rd_addr, rd_data => d_rd_data,
              wr_addr => d_wr_addr, wr_data => d_wr_data, wr_en => d_wr_en,
              busy => d_busy, done => d_done);

  -- Synchronous memory models: one registered read, one registered write.
  mem_k_proc : process (clk)
  begin
    if rising_edge(clk) then
      if ld_en = '1' then
        mem_k(ld_addr) <= ld_k;
      elsif k_wr_en = '1' then
        mem_k(to_integer(unsigned(k_wr_addr))) <=
          to_integer(signed(k_wr_data));
      end if;
      k_rd_data <= std_logic_vector(
        to_signed(mem_k(to_integer(unsigned(k_rd_addr))), C_WK));
      rb_k <= mem_k(rb_addr);
    end if;
  end process;

  mem_d_proc : process (clk)
  begin
    if rising_edge(clk) then
      if ld_en = '1' then
        mem_d(ld_addr) <= ld_d;
      elsif d_wr_en = '1' then
        mem_d(to_integer(unsigned(d_wr_addr))) <=
          to_integer(signed(d_wr_data));
      end if;
      d_rd_data <= std_logic_vector(
        to_signed(mem_d(to_integer(unsigned(d_rd_addr))), C_WD));
      rb_d <= mem_d(rb_addr);
    end if;
  end process;

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable nk     : integer := 0;
    variable nd     : integer := 0;
    variable v      : integer;

    type t_poly is array (0 to 255) of integer;
    variable pin    : t_poly;
    variable pexp   : t_poly;
    variable c      : character;
    variable eof_ln : boolean;

    procedure wait_clk (n : integer := 1) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure wait_clk;

    procedure sig_update (variable s : inout unsigned(63 downto 0);
                          x : in integer) is
      variable u : unsigned(63 downto 0);
      variable b : unsigned(7 downto 0);
      variable w : unsigned(31 downto 0);
    begin
      w := to_unsigned(x, 32);
      for i in 0 to 3 loop
        b := w(8 * i + 7 downto 8 * i);
        u := s xor resize(b, 64);
        u := u + shift_left(u, 1) + shift_left(u, 4) + shift_left(u, 5) +
             shift_left(u, 7) + shift_left(u, 8) + shift_left(u, 40);
        s := u;
      end loop;
    end procedure sig_update;

  begin
    rst_n <= '0';
    wait_clk(4);
    rst_n <= '1';
    wait_clk(2);

    ----------------------------------------------------------------------
    -- NTT-K vectors
    ----------------------------------------------------------------------
    file_open(status, fp, G_KFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open NTT-K vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      for i in 0 to 255 loop
        read(ln, pin(i));
      end loop;
      readline(fp, ln);
      for i in 0 to 255 loop
        read(ln, pexp(i));
      end loop;

      -- load input, mapped to signed centred representation
      for i in 0 to 255 loop
        ld_addr <= i;
        if pin(i) > C_QK / 2 then
          ld_k <= pin(i) - C_QK;
        else
          ld_k <= pin(i);
        end if;
        ld_en <= '1';
        wait_clk(1);
      end loop;
      ld_en <= '0';
      wait_clk(2);

      -- forward transform
      k_inv   <= '0';
      k_start <= '1';
      wait_clk(1);
      k_start <= '0';
      while k_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);

      for i in 0 to 255 loop
        rb_addr <= i;
        wait_clk(2);
        v := rb_k;
        if v < 0 then
          v := v + C_QK;
        end if;
        assert v = pexp(i)
          report "TB FAIL NTT-K forward vector " & integer'image(nk) &
                 " coef " & integer'image(i)
          severity failure;
        sig_update(sig, v);
      end loop;

      -- inverse transform must restore the input
      k_inv   <= '1';
      k_start <= '1';
      wait_clk(1);
      k_start <= '0';
      while k_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);

      for i in 0 to 255 loop
        rb_addr <= i;
        wait_clk(2);
        v := rb_k;
        if v < 0 then
          v := v + C_QK;
        end if;
        assert v = pin(i)
          report "TB FAIL NTT-K inverse vector " & integer'image(nk) &
                 " coef " & integer'image(i)
          severity failure;
        sig_update(sig, v);
      end loop;

      nk := nk + 1;
    end loop;
    file_close(fp);

    ----------------------------------------------------------------------
    -- NTT-D vectors
    ----------------------------------------------------------------------
    file_open(status, fp, G_DFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open NTT-D vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      for i in 0 to 255 loop
        read(ln, pin(i));
      end loop;
      readline(fp, ln);
      for i in 0 to 255 loop
        read(ln, pexp(i));
      end loop;

      for i in 0 to 255 loop
        ld_addr <= i;
        if pin(i) > C_QD / 2 then
          ld_d <= pin(i) - C_QD;
        else
          ld_d <= pin(i);
        end if;
        ld_en <= '1';
        wait_clk(1);
      end loop;
      ld_en <= '0';
      wait_clk(2);

      d_inv   <= '0';
      d_start <= '1';
      wait_clk(1);
      d_start <= '0';
      while d_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);

      for i in 0 to 255 loop
        rb_addr <= i;
        wait_clk(2);
        v := rb_d;
        if v < 0 then
          v := v + C_QD;
        end if;
        assert v = pexp(i)
          report "TB FAIL NTT-D forward vector " & integer'image(nd) &
                 " coef " & integer'image(i)
          severity failure;
        sig_update(sig, v);
      end loop;

      d_inv   <= '1';
      d_start <= '1';
      wait_clk(1);
      d_start <= '0';
      while d_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);

      for i in 0 to 255 loop
        rb_addr <= i;
        wait_clk(2);
        v := rb_d;
        if v < 0 then
          v := v + C_QD;
        end if;
        assert v = pin(i)
          report "TB FAIL NTT-D inverse vector " & integer'image(nd) &
                 " coef " & integer'image(i)
          severity failure;
        sig_update(sig, v);
      end loop;

      nd := nd + 1;
    end loop;
    file_close(fp);

    report "PQC L1 NTT PASS ntt_k=" & integer'image(nk) &
           " ntt_d=" & integer'image(nd) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
