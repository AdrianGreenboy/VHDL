-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1 testbench
-- tb_sampler: validates all six samplers against reference vectors derived
-- from the ACVP-validated Phase 0 oracles.
--
-- This is the first integration test: the samplers are driven by the real
-- keccak_sponge from Layer 1 block 1 through its incremental squeeze
-- interface, not by a stub. Rejection makes byte consumption data-dependent,
-- so the signature hashes produced coefficients only, never cycle counts.
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_tables_pkg.all;

entity tb_sampler is
  generic (
    G_VFILE : string := "sampler_vectors.txt");
end entity tb_sampler;

architecture sim of tb_sampler is

  constant C_PERIOD : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal sim_done : boolean := false;

  -- sponge
  signal sp_mode   : std_logic_vector(1 downto 0) := "00";
  signal sp_init   : std_logic := '0';
  signal sp_din    : std_logic_vector(7 downto 0) := (others => '0');
  signal sp_we     : std_logic := '0';
  signal sp_adone  : std_logic := '0';
  signal sp_dout   : std_logic_vector(7 downto 0);
  signal sp_re     : std_logic := '0';
  signal sp_dvalid : std_logic;
  signal sp_ready  : std_logic;

  -- squeeze fan-out to the samplers
  signal sq_sel    : integer range 0 to 5 := 0;

  -- per-sampler control
  signal s1_start, s2_start, s3_start : std_logic := '0';
  signal s4_start, s5_start, s6_start : std_logic := '0';
  signal s1_done, s2_done, s3_done    : std_logic;
  signal s4_done, s5_done, s6_done    : std_logic;
  signal s1_re, s2_re, s3_re          : std_logic;
  signal s4_re, s5_re, s6_re          : std_logic;

  signal s1_addr, s2_addr, s3_addr    : std_logic_vector(7 downto 0);
  signal s4_addr, s5_addr, s6_addr    : std_logic_vector(7 downto 0);
  signal s1_data                      : std_logic_vector(15 downto 0);
  signal s2_data                      : std_logic_vector(15 downto 0);
  signal s3_data, s4_data             : std_logic_vector(31 downto 0);
  signal s5_data, s6_data             : std_logic_vector(31 downto 0);
  signal s1_we, s2_we, s3_we          : std_logic;
  signal s4_we, s5_we, s6_we          : std_logic;

  -- shared coefficient memory
  type t_mem is array (0 to 255) of integer;
  signal mem : t_mem := (others => 0);

  signal rb_addr  : std_logic_vector(7 downto 0) := (others => '0');
  signal rb_data  : std_logic_vector(31 downto 0) := (others => '0');
  signal insp_addr : integer range 0 to 255 := 0;
  signal insp_data : integer := 0;

  signal any_we   : std_logic;
  signal any_addr : std_logic_vector(7 downto 0);
  signal any_data : std_logic_vector(31 downto 0);

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

  u_sponge : entity work.keccak_sponge
    port map (clk => clk, rst_n => rst_n, mode => sp_mode, init => sp_init,
              din => sp_din, din_we => sp_we, absorb_done => sp_adone,
              dout => sp_dout, dout_re => sp_re, dout_valid => sp_dvalid,
              ready => sp_ready);

  -- Only the selected sampler is allowed to pull bytes from the sponge.
  sp_re <= s1_re when sq_sel = 0 else
           s2_re when sq_sel = 1 else
           s3_re when sq_sel = 2 else
           s4_re when sq_sel = 3 else
           s5_re when sq_sel = 4 else
           s6_re;

  u_s1 : entity work.sampler_ntt_k
    port map (clk => clk, rst_n => rst_n, start => s1_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s1_re,
              co_addr => s1_addr, co_data => s1_data, co_we => s1_we,
              busy => open, done => s1_done);

  u_s2 : entity work.sampler_cbd_k
    port map (clk => clk, rst_n => rst_n, start => s2_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s2_re,
              co_addr => s2_addr, co_data => s2_data, co_we => s2_we,
              busy => open, done => s2_done);

  u_s3 : entity work.sampler_rej_d
    port map (clk => clk, rst_n => rst_n, start => s3_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s3_re,
              co_addr => s3_addr, co_data => s3_data, co_we => s3_we,
              busy => open, done => s3_done);

  u_s4 : entity work.sampler_bnd_d
    port map (clk => clk, rst_n => rst_n, start => s4_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s4_re,
              co_addr => s4_addr, co_data => s4_data, co_we => s4_we,
              busy => open, done => s4_done);

  u_s5 : entity work.sampler_ball_d
    port map (clk => clk, rst_n => rst_n, start => s5_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s5_re,
              co_addr => s5_addr, co_data => s5_data, co_we => s5_we,
              rb_addr => rb_addr, rb_data => rb_data,
              busy => open, done => s5_done);

  u_s6 : entity work.sampler_mask_d
    port map (clk => clk, rst_n => rst_n, start => s6_start,
              sq_data => sp_dout, sq_valid => sp_dvalid, sq_re => s6_re,
              co_addr => s6_addr, co_data => s6_data, co_we => s6_we,
              busy => open, done => s6_done);

  -- Write-port multiplexer: exactly one sampler runs at a time.
  any_we <= s1_we when sq_sel = 0 else
            s2_we when sq_sel = 1 else
            s3_we when sq_sel = 2 else
            s4_we when sq_sel = 3 else
            s5_we when sq_sel = 4 else
            s6_we;

  any_addr <= s1_addr when sq_sel = 0 else
              s2_addr when sq_sel = 1 else
              s3_addr when sq_sel = 2 else
              s4_addr when sq_sel = 3 else
              s5_addr when sq_sel = 4 else
              s6_addr;

  any_data <= std_logic_vector(resize(unsigned(s1_data), 32)) when sq_sel = 0 else
              std_logic_vector(resize(unsigned(s2_data), 32)) when sq_sel = 1 else
              s3_data when sq_sel = 2 else
              s4_data when sq_sel = 3 else
              s5_data when sq_sel = 4 else
              s6_data;

  mem_proc : process (clk)
  begin
    if rising_edge(clk) then
      if any_we = '1' then
        mem(to_integer(unsigned(any_addr))) <= to_integer(unsigned(any_data));
      end if;
      rb_data   <= std_logic_vector(
                     to_unsigned(mem(to_integer(unsigned(rb_addr))), 32));
      insp_data <= mem(insp_addr);
    end if;
  end process;

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable nvec   : integer := 0;
    variable sid    : string(1 to 2);
    variable c      : character;
    variable v      : integer;
    variable seedlen : integer;
    variable ch1, ch2 : character;
    variable byt    : std_logic_vector(7 downto 0);
    type t_poly is array (0 to 255) of integer;
    variable pexp   : t_poly;
    variable which  : integer;

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

    function hex2 (a, b : character) return std_logic_vector is
      variable r : std_logic_vector(7 downto 0);
      variable n : integer;
      variable cc : character;
    begin
      for k in 0 to 1 loop
        if k = 0 then cc := a; else cc := b; end if;
        case cc is
          when '0' => n := 0;  when '1' => n := 1;  when '2' => n := 2;
          when '3' => n := 3;  when '4' => n := 4;  when '5' => n := 5;
          when '6' => n := 6;  when '7' => n := 7;  when '8' => n := 8;
          when '9' => n := 9;
          when 'a' | 'A' => n := 10;  when 'b' | 'B' => n := 11;
          when 'c' | 'C' => n := 12;  when 'd' | 'D' => n := 13;
          when 'e' | 'E' => n := 14;  when others => n := 15;
        end case;
        if k = 0 then
          r(7 downto 4) := std_logic_vector(to_unsigned(n, 4));
        else
          r(3 downto 0) := std_logic_vector(to_unsigned(n, 4));
        end if;
      end loop;
      return r;
    end function hex2;

  begin
    rst_n <= '0';
    wait_clk(4);
    rst_n <= '1';
    wait_clk(2);

    file_open(status, fp, G_VFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open sampler vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      read(ln, sid(1));
      read(ln, sid(2));
      read(ln, c);   -- space

      -- sampler selection and sponge mode per FIPS
      case sid(2) is
        when '1' => which := 0; sp_mode <= "00"; seedlen := 34;   -- SHAKE128
        when '2' => which := 1; sp_mode <= "01"; seedlen := 33;   -- s||counter
        when '3' => which := 2; sp_mode <= "00"; seedlen := 34;   -- SHAKE128
        when '4' => which := 3; sp_mode <= "01"; seedlen := 66;   -- SHAKE256
        when '5' => which := 4; sp_mode <= "01"; seedlen := 48;   -- SHAKE256
        when others => which := 5; sp_mode <= "01"; seedlen := 66;
      end case;
      sq_sel <= which;
      wait_clk(1);

      -- start the sponge and absorb the seed
      sp_init <= '1';
      wait_clk(1);
      while sp_ready = '0' loop
        wait_clk(1);
      end loop;
      sp_init <= '0';
      wait_clk(1);

      for i in 1 to seedlen loop
        read(ln, ch1);
        read(ln, ch2);
        byt := hex2(ch1, ch2);
        while sp_ready = '0' loop
          wait_clk(1);
        end loop;
        sp_din <= byt;
        sp_we  <= '1';
        wait_clk(1);
        sp_we  <= '0';
        wait_clk(1);
      end loop;

      while sp_ready = '0' loop
        wait_clk(1);
      end loop;
      sp_adone <= '1';
      wait_clk(1);
      sp_adone <= '0';

      while sp_dvalid = '0' loop
        wait_clk(1);
      end loop;

      -- read expected coefficients
      for i in 0 to 255 loop
        read(ln, pexp(i));
      end loop;

      -- run the selected sampler
      case which is
        when 0 => s1_start <= '1'; wait_clk(1); s1_start <= '0';
                  while s1_done = '0' loop wait_clk(1); end loop;
        when 1 => s2_start <= '1'; wait_clk(1); s2_start <= '0';
                  while s2_done = '0' loop wait_clk(1); end loop;
        when 2 => s3_start <= '1'; wait_clk(1); s3_start <= '0';
                  while s3_done = '0' loop wait_clk(1); end loop;
        when 3 => s4_start <= '1'; wait_clk(1); s4_start <= '0';
                  while s4_done = '0' loop wait_clk(1); end loop;
        when 4 => s5_start <= '1'; wait_clk(1); s5_start <= '0';
                  while s5_done = '0' loop wait_clk(1); end loop;
        when others => s6_start <= '1'; wait_clk(1); s6_start <= '0';
                  while s6_done = '0' loop wait_clk(1); end loop;
      end case;
      wait_clk(3);

      for i in 0 to 255 loop
        insp_addr <= i;
        wait_clk(2);
        v := insp_data;
        assert v = pexp(i)
          report "TB FAIL sampler " & sid & " vector " & integer'image(nvec) &
                 " coef " & integer'image(i)
          severity failure;
        sig_update(sig, v);
      end loop;

      nvec := nvec + 1;
    end loop;
    file_close(fp);

    report "PQC L1 SAMPLER PASS vectors=" & integer'image(nvec) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
