-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 4 fusion
-- tb_pqc_core: run the KEM chain and the DSA chain back to back over the one
-- shared Keccak sponge, and reproduce BOTH Layer 4 signatures.
-- VHDL-2008. ASCII-only. MIT license.
--
-- The verification bar needs no new calibration. Each chain is the exact
-- sequence its own Layer 4 testbench ran, and each must produce the exact
-- signature that testbench produced:
--   KEM  95e07091fa5b3cc4
--   DSA  f93232f7ea2d1575
-- Sharing the sponge cannot move a validated signature unless the sharing is
-- wrong, so a reproduced pair is proof the fusion is transparent. The two run
-- in one simulation, so the sponge really is reused between algorithms rather
-- than reset in between.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_pqc_core is
end entity tb_pqc_core;

architecture sim of tb_pqc_core is

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

  constant C_EK  : integer := 1184;
  constant C_DK  : integer := 2400;
  constant C_CT  : integer := 1088;
  constant C_PK  : integer := 1952;
  constant C_SK  : integer := 4032;
  constant C_SIG : integer := 3309;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal alg    : std_logic := '0';

  signal kem_op    : std_logic_vector(1 downto 0) := "00";
  signal kem_start : std_logic := '0';
  signal kem_done, kem_busy, kem_rej : std_logic;
  signal kem_haddr : std_logic_vector(12 downto 0) := (others => '0');
  signal kem_hdin  : std_logic_vector(7 downto 0) := (others => '0');
  signal kem_hwe   : std_logic := '0';
  signal kem_hsel  : std_logic := '1';
  signal kem_hdout : std_logic_vector(7 downto 0);

  signal dsa_op    : std_logic_vector(1 downto 0) := "00";
  signal dsa_start : std_logic := '0';
  signal dsa_siglen : std_logic_vector(15 downto 0) := (others => '0');
  signal dsa_done, dsa_busy, dsa_result : std_logic;
  signal dsa_reason : std_logic_vector(2 downto 0);
  signal dsa_haddr : std_logic_vector(13 downto 0) := (others => '0');
  signal dsa_hdin  : std_logic_vector(7 downto 0) := (others => '0');
  signal dsa_hwe   : std_logic := '0';
  signal dsa_hsel  : std_logic := '1';
  signal dsa_hdout : std_logic_vector(7 downto 0);

begin

  clk <= not clk after 5 ns;

  dut : entity work.pqc_core
    port map (clk => clk, rst_n => rst_n, alg => alg,
              kem_op => kem_op, kem_start => kem_start, kem_done => kem_done,
              kem_busy => kem_busy, kem_rej => kem_rej,
              kem_haddr => kem_haddr, kem_hdin => kem_hdin, kem_hwe => kem_hwe,
              kem_hsel => kem_hsel, kem_hdout => kem_hdout,
              dsa_op => dsa_op, dsa_start => dsa_start,
              dsa_siglen => dsa_siglen, dsa_done => dsa_done,
              dsa_busy => dsa_busy, dsa_result => dsa_result,
              dsa_reason => dsa_reason,
              dsa_haddr => dsa_haddr, dsa_hdin => dsa_hdin, dsa_hwe => dsa_hwe,
              dsa_hsel => dsa_hsel, dsa_hdout => dsa_hdout);

  process
    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 2);
    variable c   : character;
    variable ch1, ch2 : character;
    variable v   : integer;
    variable sigk : unsigned(63 downto 0) := x"cbf29ce484222325";
    variable sigd : unsigned(63 downto 0) := x"cbf29ce484222325";
    type t_buf is array (0 to 4095) of integer;
    variable d_b, z_b, m_b, ek_b, dk_b, ct_b, ss_b : t_buf;
    variable xi_b, mu_b, pk_b, sk_b, sg_b : t_buf;

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

    -- KEM host path
    procedure kwrite (constant a : in integer; constant d : in integer) is
    begin
      kem_hsel <= '1';
      kem_haddr <= std_logic_vector(to_unsigned(a, 13));
      kem_hdin  <= std_logic_vector(to_unsigned(d, 8));
      kem_hwe   <= '1';
      wait_clk(1);
      kem_hwe   <= '0';
      wait_clk(1);
    end procedure;

    procedure kread (constant a : in integer; variable d : out integer) is
    begin
      kem_hsel <= '1';
      kem_haddr <= std_logic_vector(to_unsigned(a, 13));
      wait_clk(2);
      d := to_integer(unsigned(kem_hdout));
    end procedure;

    procedure krun (constant o : in std_logic_vector(1 downto 0)) is
    begin
      kem_op   <= o;
      kem_hsel <= '0';
      wait_clk(2);
      kem_start <= '1';
      wait_clk(1);
      kem_start <= '0';
      while kem_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(4);
      kem_hsel <= '1';
      wait_clk(2);
    end procedure;

    -- DSA host path
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

    procedure drun (constant o : in std_logic_vector(1 downto 0)) is
    begin
      dsa_op   <= o;
      dsa_hsel <= '0';
      wait_clk(2);
      dsa_start <= '1';
      wait_clk(1);
      dsa_start <= '0';
      while dsa_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(4);
      dsa_hsel <= '1';
      wait_clk(2);
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

    ------------------------------------------------------------------
    -- ML-KEM chain, alg = '0'
    ------------------------------------------------------------------
    alg <= '0';
    file_open(fh, "kem_st_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      next when ln'length < 3;
      read(ln, tag);
      exit when tag = "ST";
    end loop;
    rdhex(d_b, 32, ln);  rdhex(z_b, 32, ln);  rdhex(m_b, 32, ln);
    rdhex(ek_b, C_EK, ln); rdhex(dk_b, C_DK, ln);
    rdhex(ct_b, C_CT, ln); rdhex(ss_b, 32, ln);
    file_close(fh);

    for i in 0 to 31 loop
      kwrite(i, d_b(i));
      kwrite(32 + i, z_b(i));
    end loop;
    krun("00");
    for i in 0 to C_EK - 1 loop
      kread(512 + i, v);
      assert v = ek_b(i) report "TB FAIL kem ek " & integer'image(i)
        severity failure;
      fnv(sigk, v);
    end loop;
    for i in 0 to C_DK - 1 loop
      kread(2048 + i, v);
      assert v = dk_b(i) report "TB FAIL kem dk " & integer'image(i)
        severity failure;
      fnv(sigk, v);
      kwrite(5000 + i, v);          -- park dk over the collision
    end loop;

    for i in 0 to 31 loop
      kwrite(i, m_b(i));
    end loop;
    krun("01");
    for i in 0 to C_CT - 1 loop
      kread(2048 + i, v);
      assert v = ct_b(i) report "TB FAIL kem ct " & integer'image(i)
        severity failure;
      fnv(sigk, v);
    end loop;
    for i in 0 to 31 loop
      kread(32 + i, v);
      assert v = ss_b(i) report "TB FAIL kem K " & integer'image(i)
        severity failure;
      fnv(sigk, v);
    end loop;

    for i in 0 to C_CT - 1 loop
      kread(2048 + i, v);
      kwrite(i, v);
    end loop;
    for i in 0 to C_DK - 1 loop
      kread(5000 + i, v);
      kwrite(2048 + i, v);
    end loop;
    krun("10");
    for i in 0 to 31 loop
      kread(1280 + i, v);
      assert v = ss_b(i) report "TB FAIL kem Kout " & integer'image(i)
        severity failure;
      fnv(sigk, v);
    end loop;
    assert kem_rej = '0' report "TB FAIL kem rejected" severity failure;

    assert to_hex(sigk) = "95e07091fa5b3cc4"
      report "TB FAIL kem signature moved: got " & to_hex(sigk) &
             " expected 95e07091fa5b3cc4 -- the shared sponge is not" &
             " behaving as the private one did"
      severity failure;
    report "PQC FUSION KEM chain sig=" & to_hex(sigk) severity note;

    ------------------------------------------------------------------
    -- ML-DSA chain, alg = '1', same sponge, no reset in between
    ------------------------------------------------------------------
    alg <= '1';
    file_open(fh, "dsa_st_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      next when ln'length < 3;
      read(ln, tag);
      exit when tag = "ST";
    end loop;
    rdhex(xi_b, 32, ln);  rdhex(mu_b, 64, ln);
    rdhex(pk_b, C_PK, ln); rdhex(sk_b, C_SK, ln);
    rdhex(sg_b, C_SIG, ln);
    read(ln, v);   -- kappa, unused here
    file_close(fh);

    for i in 0 to 31 loop
      dwrite(i, xi_b(i));
    end loop;
    drun("00");
    for i in 0 to C_PK - 1 loop
      dread(256 + i, v);
      assert v = pk_b(i) report "TB FAIL dsa pk " & integer'image(i)
        severity failure;
      fnv(sigd, v);
    end loop;
    for i in 0 to C_SK - 1 loop
      dread(2304 + i, v);
      assert v = sk_b(i) report "TB FAIL dsa sk " & integer'image(i)
        severity failure;
      fnv(sigd, v);
    end loop;

    for i in 0 to C_SK - 1 loop
      dread(2304 + i, v);
      dwrite(i, v);
    end loop;
    for i in 0 to 63 loop
      dwrite(4096 + i, mu_b(i));
    end loop;
    drun("01");
    for i in 0 to C_SIG - 1 loop
      dread(8192 + i, v);
      assert v = sg_b(i) report "TB FAIL dsa sig " & integer'image(i)
        severity failure;
      fnv(sigd, v);
    end loop;

    for i in 0 to C_SIG - 1 loop
      dread(8192 + i, v);
      dwrite(2176 + i, v);
    end loop;
    for i in 0 to C_PK - 1 loop
      dwrite(i, pk_b(i));
    end loop;
    for i in 0 to 63 loop
      dwrite(2048 + i, mu_b(i));
    end loop;
    dsa_siglen <= std_logic_vector(to_unsigned(C_SIG, 16));
    drun("10");
    assert dsa_result = '1'
      report "TB FAIL dsa verify rejected its own signature" severity failure;
    fnv(sigd, 1);

    assert to_hex(sigd) = "f93232f7ea2d1575"
      report "TB FAIL dsa signature moved: got " & to_hex(sigd) &
             " expected f93232f7ea2d1575 -- the shared sponge is not" &
             " behaving as the private one did"
      severity failure;
    report "PQC FUSION DSA chain sig=" & to_hex(sigd) severity note;

    report "PQC L4 FUSION PASS kem=" & to_hex(sigk) &
           " dsa=" & to_hex(sigd) & " shared_sponge=1"
      severity note;
    std.env.finish;
    wait;
  end process;

end architecture sim;
