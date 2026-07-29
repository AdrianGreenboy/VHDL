-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 4
-- tb_dsa_core: chained self-test of the three ML-DSA operations on one
-- shared datapath.
-- VHDL-2008. ASCII-only. MIT license.
--
-- This is the Layer 4 test: the RTL runs a complete key lifecycle rather than
-- one operation against a vector file. It checks two independent things.
--
--  1. Every intermediate is compared against the ACVP expected bytes. This
--     anchors the core to the standard, and no defect shared by the three
--     operations can satisfy it.
--
--  2. Verify must accept the signature that KeyGen and Sign produced. This is
--     a property the vector comparison does not cover: that the operations
--     agree with each other.
--
-- The second alone would be the cheaper lie. A core with a wrong constant in
-- the NTT tables would use it in all three operations, interoperate with
-- itself perfectly, and not be ML-DSA. That is exactly the RTL-vs-RTL common
-- mode the Phase 0 test was built to close in the SpaceWire and 1553 cores,
-- so both checks are here.
--
-- The three sequencers keep the byte maps they were verified with, and those
-- maps do not agree: KeyGen writes sk at 2304 while Sign reads it at 0. The
-- driver moves bytes between operations rather than the sequencers being
-- rewritten to share a map, because rewriting them would invalidate the
-- Layer 3B signatures for no gain.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.poly_mem_d_pkg.all;

entity tb_dsa_core is
end entity tb_dsa_core;

architecture sim of tb_dsa_core is

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

  constant C_PK  : integer := 1952;
  constant C_SK  : integer := 4032;
  constant C_SIG : integer := 3309;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal op     : std_logic_vector(1 downto 0) := "00";
  signal start  : std_logic := '0';
  signal siglen : std_logic_vector(15 downto 0) := (others => '0');
  signal done   : std_logic;
  signal busy   : std_logic;
  signal result : std_logic;
  signal reason : std_logic_vector(2 downto 0);

  signal h_sel  : std_logic := '1';
  signal h_addr : std_logic_vector(13 downto 0) := (others => '0');
  signal h_din  : std_logic_vector(7 downto 0) := (others => '0');
  signal h_we   : std_logic := '0';
  signal h_dout : std_logic_vector(7 downto 0);

begin

  clk <= not clk after 5 ns;

  dut : entity work.dsa_core
    port map (clk => clk, rst_n => rst_n, op => op, start => start,
              siglen => siglen, done => done, busy => busy,
              result => result, reason => reason,
              h_sel => h_sel, h_addr => h_addr, h_din => h_din,
              h_we => h_we, h_dout => h_dout);

  process
    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 2);
    variable c   : character;
    variable ch1, ch2 : character;
    variable v   : integer;
    variable sig : unsigned(63 downto 0) := x"cbf29ce484222325";
    type t_buf is array (0 to 4095) of integer;
    variable xi_b  : t_buf;
    variable mu_b  : t_buf;
    variable pk_b  : t_buf;
    variable sk_b  : t_buf;
    variable sg_b  : t_buf;
    variable kappa : integer;

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

    procedure bwrite (constant a : in integer; constant d : in integer) is
    begin
      h_sel  <= '1';
      h_addr <= std_logic_vector(to_unsigned(a, 14));
      h_din  <= std_logic_vector(to_unsigned(d, 8));
      h_we   <= '1';
      wait_clk(1);
      h_we   <= '0';
      wait_clk(1);
    end procedure;

    procedure bread (constant a : in integer; variable d : out integer) is
    begin
      h_sel  <= '1';
      h_addr <= std_logic_vector(to_unsigned(a, 14));
      wait_clk(2);
      d := to_integer(unsigned(h_dout));
    end procedure;

    procedure run_op (constant o : in std_logic_vector(1 downto 0)) is
    begin
      op    <= o;
      h_sel <= '0';
      wait_clk(2);
      start <= '1';
      wait_clk(1);
      start <= '0';
      while done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(4);
      h_sel <= '1';
      wait_clk(2);
    end procedure;

  begin
    rst_n <= '0';
    wait_clk(5);
    rst_n <= '1';
    wait_clk(5);

    file_open(fh, "dsa_st_vectors.txt", read_mode);
    -- Same reader shape as every other testbench in this core: skip short
    -- lines and anything starting with '#', then match the tag.
    while not endfile(fh) loop
      readline(fh, ln);
      next when ln'length < 3;
      read(ln, tag);
      exit when tag = "ST";
    end loop;

    read(ln, c);
    for i in 0 to 31 loop
      read(ln, ch1); read(ln, ch2);
      xi_b(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
    end loop;
    read(ln, c);
    for i in 0 to 63 loop
      read(ln, ch1); read(ln, ch2);
      mu_b(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
    end loop;
    read(ln, c);
    for i in 0 to C_PK - 1 loop
      read(ln, ch1); read(ln, ch2);
      pk_b(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
    end loop;
    read(ln, c);
    for i in 0 to C_SK - 1 loop
      read(ln, ch1); read(ln, ch2);
      sk_b(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
    end loop;
    read(ln, c);
    for i in 0 to C_SIG - 1 loop
      read(ln, ch1); read(ln, ch2);
      sg_b(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
    end loop;
    read(ln, kappa);
    file_close(fh);

    ------------------------------------------------------------------
    -- KeyGen: xi at 0, pk out at 256, sk out at 2304
    ------------------------------------------------------------------
    for i in 0 to 31 loop
      bwrite(i, xi_b(i));
    end loop;
    run_op("00");

    for i in 0 to C_PK - 1 loop
      bread(256 + i, v);
      assert v = pk_b(i)
        report "TB FAIL keygen pk byte " & integer'image(i) &
               " got=" & integer'image(v) & " exp=" & integer'image(pk_b(i))
        severity failure;
      fnv(sig, v);
    end loop;
    for i in 0 to C_SK - 1 loop
      bread(2304 + i, v);
      assert v = sk_b(i)
        report "TB FAIL keygen sk byte " & integer'image(i) &
               " got=" & integer'image(v) & " exp=" & integer'image(sk_b(i))
        severity failure;
      fnv(sig, v);
    end loop;

    ------------------------------------------------------------------
    -- Sign: sk moves from 2304 to 0, mu to 4096, sig out at 8192.
    -- The bytes moved are the ones KeyGen just produced and the testbench
    -- just verified, so the chain really does carry the core's own output
    -- rather than re-loading the vector.
    ------------------------------------------------------------------
    for i in 0 to C_SK - 1 loop
      bread(2304 + i, v);
      bwrite(i, v);
    end loop;
    for i in 0 to 63 loop
      bwrite(4096 + i, mu_b(i));
    end loop;
    run_op("01");

    for i in 0 to C_SIG - 1 loop
      bread(8192 + i, v);
      assert v = sg_b(i)
        report "TB FAIL sign sig byte " & integer'image(i) &
               " got=" & integer'image(v) & " exp=" & integer'image(sg_b(i))
        severity failure;
      fnv(sig, v);
    end loop;

    ------------------------------------------------------------------
    -- Verify: pk to 0, mu to 2048, sig to 2176. Again the bytes are the
    -- core's own output, so an accept here is the chained property.
    ------------------------------------------------------------------
    for i in 0 to C_SIG - 1 loop
      bread(8192 + i, v);
      bwrite(2176 + i, v);
    end loop;
    for i in 0 to C_PK - 1 loop
      bwrite(i, pk_b(i));
    end loop;
    for i in 0 to 63 loop
      bwrite(2048 + i, mu_b(i));
    end loop;
    siglen <= std_logic_vector(to_unsigned(C_SIG, 16));
    run_op("10");

    assert result = '1'
      report "TB FAIL verify rejected the core's own signature, reason=" &
             integer'image(to_integer(unsigned(reason))) &
             " (the ACVP comparisons passed, so this is a consistency" &
             " failure between operations)"
      severity failure;
    assert to_integer(unsigned(reason)) = 0
      report "TB FAIL verify accepted but reported reason " &
             integer'image(to_integer(unsigned(reason)))
      severity failure;
    fnv(sig, 1);

    report "PQC L4 DSACORE PASS keygen+sign+verify chained sig=" &
           to_hex(sig)
      severity note;
    std.env.finish;
    wait;
  end process;

end architecture sim;
