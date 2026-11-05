-- =============================================================================
-- HERCOSSNUX PQC IP Core - audit 2026-11
-- tb_sign_bound: the ML-DSA Sign iteration bound, on pqc_core.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Uses the first Sign vector of dsa_sign_vectors.txt, which needs exactly
-- G_ITERS_NEEDED = 3 iterations. Run twice:
--   -gG_MAX_ITER=3  the bound equals the need: the signature must be
--                   KAT-exact and err(2) must stay clear;
--   -gG_MAX_ITER=2  the bound is one short: done must pulse with err(2) set,
--                   and the signature area must read back zero, both through
--                   the host port and in the physical memory.
-- Expected final line:  PQC SIGNBOUND PASS ...
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.byte_mem_d_pkg.all;

entity tb_sign_bound is
  generic (G_MAX_ITER : integer := 2);
end entity tb_sign_bound;

architecture sim of tb_sign_bound is

  function hex_nib (c : character) return integer is
  begin
    case c is
      when '0' => return 0;   when '1' => return 1;   when '2' => return 2;
      when '3' => return 3;   when '4' => return 4;   when '5' => return 5;
      when '6' => return 6;   when '7' => return 7;   when '8' => return 8;
      when '9' => return 9;   when 'a' | 'A' => return 10;
      when 'b' | 'B' => return 11;  when 'c' | 'C' => return 12;
      when 'd' | 'D' => return 13;  when 'e' | 'E' => return 14;
      when others => return 15;
    end case;
  end function hex_nib;

  constant C_SK  : integer := 4032;
  constant C_SIG : integer := 3309;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal dsa_op    : std_logic_vector(1 downto 0) := "01";
  signal dsa_start : std_logic := '0';
  signal dsa_done, dsa_busy, dsa_result : std_logic;
  signal dsa_reason : std_logic_vector(2 downto 0);
  signal dsa_haddr : std_logic_vector(13 downto 0) := (others => '0');
  signal dsa_hdin  : std_logic_vector(7 downto 0) := (others => '0');
  signal dsa_hwe   : std_logic := '0';
  signal dsa_hsel  : std_logic := '1';
  signal dsa_hdout : std_logic_vector(7 downto 0);
  signal kem_done, kem_busy : std_logic;
  signal kem_hdout : std_logic_vector(7 downto 0);
  signal zbusy, zdone : std_logic;
  signal err : std_logic_vector(3 downto 0);

begin
  clk <= not clk after 5 ns;

  dut : entity work.pqc_core
    generic map (G_ZEROIZE => true, G_SIGN_MAX_ITER => G_MAX_ITER)
    port map (clk => clk, rst_n => rst_n, alg => '1',
              kem_op => "00", kem_start => '0', kem_done => kem_done,
              kem_busy => kem_busy, kem_haddr => (others => '0'),
              kem_hdin => (others => '0'), kem_hwe => '0', kem_hsel => '0',
              kem_hdout => kem_hdout,
              dsa_op => dsa_op, dsa_start => dsa_start,
              dsa_siglen => (others => '0'), dsa_done => dsa_done,
              dsa_busy => dsa_busy, dsa_result => dsa_result,
              dsa_reason => dsa_reason,
              dsa_haddr => dsa_haddr, dsa_hdin => dsa_hdin, dsa_hwe => dsa_hwe,
              dsa_hsel => dsa_hsel, dsa_hdout => dsa_hdout,
              zeroize => '0', zbusy => zbusy, zdone => zdone, err => err);

  process
    alias dbm is <<signal .tb_sign_bound.dut.u_dsa.u_bmem.mem : t_bmd_arr>>;
    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 3);
    variable c, ch1, ch2 : character;
    variable v, kap, its : integer;
    type t_buf is array (0 to 4095) of integer;
    variable sk_b, mu_b, sg_b : t_buf;

    procedure wait_clk (k : integer) is
    begin
      for i in 1 to k loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure dwrite (constant a : in integer; constant d : in integer) is
    begin
      dsa_hsel <= '1';
      dsa_haddr <= std_logic_vector(to_unsigned(a, 14));
      dsa_hdin  <= std_logic_vector(to_unsigned(d, 8));
      dsa_hwe   <= '1';
      wait_clk(1);
      dsa_hwe   <= '0';
      wait_clk(1);
    end procedure;

    procedure dread (constant a : in integer; variable d : out integer) is
    begin
      dsa_hsel <= '1';
      dsa_haddr <= std_logic_vector(to_unsigned(a, 14));
      wait_clk(2);
      d := to_integer(unsigned(dsa_hdout));
    end procedure;

    procedure rdhex (variable buf : out t_buf; constant n : in integer;
                     variable ln : inout line) is
    begin
      read(ln, c);
      for i in 0 to n - 1 loop
        read(ln, ch1); read(ln, ch2);
        buf(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
      end loop;
    end procedure;

  begin
    rst_n <= '0';
    wait_clk(5);
    rst_n <= '1';
    wait_clk(5);

    file_open(fh, "dsa_sign_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      next when ln'length < 4;
      read(ln, tag);
      exit when tag = "SGN";
    end loop;
    rdhex(sk_b, C_SK, ln); rdhex(mu_b, 64, ln); rdhex(sg_b, C_SIG, ln);
    read(ln, kap); read(ln, its);
    file_close(fh);
    assert its = 3 report "TB FAIL vector does not need 3 iterations"
      severity failure;

    for i in 0 to C_SK - 1 loop
      dwrite(i, sk_b(i));
    end loop;
    for i in 0 to 63 loop
      dwrite(4096 + i, mu_b(i));
    end loop;
    dsa_hsel <= '0';
    wait_clk(2);
    dsa_start <= '1';
    wait_clk(1);
    dsa_start <= '0';
    while dsa_done = '0' loop
      wait_clk(1);
    end loop;
    wait_clk(4);

    if G_MAX_ITER >= its then
      assert err = "0000" report "TB FAIL err set although the bound suffices"
        severity failure;
      for i in 0 to C_SIG - 1 loop
        dread(8192 + i, v);
        assert v = sg_b(i) report "TB FAIL sig byte " & integer'image(i)
          severity failure;
      end loop;
      report "PQC SIGNBOUND PASS bound=" & integer'image(G_MAX_ITER) &
             " needed=" & integer'image(its) & " signature exact" severity note;
    else
      assert err(2) = '1' report "TB FAIL bound reached but err(2) clear"
        severity failure;
      for i in 0 to C_SIG - 1 loop
        dread(8192 + i, v);
        assert v = 0 report "TB FAIL partial signature readable at " &
                            integer'image(i) severity failure;
        assert dbm((8192 + i) / 8)(8 * ((8192 + i) mod 8) + 7 downto
                                  8 * ((8192 + i) mod 8)) = x"00"
          report "TB FAIL partial signature left in memory" severity failure;
      end loop;
      for i in 0 to C_SK - 1 loop
        assert dbm(i / 8)(8 * (i mod 8) + 7 downto 8 * (i mod 8)) = x"00"
          report "TB FAIL sk left in memory after abort" severity failure;
      end loop;
      report "PQC SIGNBOUND PASS bound=" & integer'image(G_MAX_ITER) &
             " needed=" & integer'image(its) & " aborted with err, sig wiped"
        severity note;
    end if;
    std.env.finish;
    wait;
  end process;
end architecture sim;
