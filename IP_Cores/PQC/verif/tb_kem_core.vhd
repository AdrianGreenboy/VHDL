-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 4
-- tb_kem_core: chained self-test of the three ML-KEM operations on one
-- shared datapath.
-- VHDL-2008. ASCII-only. MIT license.
--
-- KeyGen, then Encaps on the key it produced, then Decaps on the ciphertext
-- Encaps produced. Two checks, for the same reason as the ML-DSA core:
--
--  1. Every intermediate is compared against the ACVP expected bytes, which
--     anchors the core to the standard and no shared defect can satisfy.
--
--  2. The two shared secrets must match: Encaps's K and Decaps's Kout. This
--     is the round-trip property, and alone it would be the cheaper lie -- a
--     core with a wrong NTT constant used by all three operations would round
--     trip perfectly and not be ML-KEM.
--
-- The byte maps of the three operations disagree (KeyGen writes ek at 512,
-- Encaps reads it at 512 but writes ct at 2048, Decaps reads c at 0), so the
-- driver moves the core's own output between operations rather than reloading
-- the vector.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.poly_mem_pkg.all;

entity tb_kem_core is
end entity tb_kem_core;

architecture sim of tb_kem_core is

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

  constant C_EK : integer := 1184;
  constant C_DK : integer := 2400;
  constant C_CT : integer := 1088;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal op     : std_logic_vector(1 downto 0) := "00";
  signal start  : std_logic := '0';
  signal done   : std_logic;
  signal busy   : std_logic;
  signal rejected : std_logic;

  signal h_sel  : std_logic := '1';
  signal h_addr : std_logic_vector(12 downto 0) := (others => '0');
  signal h_din  : std_logic_vector(7 downto 0) := (others => '0');
  signal h_we   : std_logic := '0';
  signal h_dout : std_logic_vector(7 downto 0);

  signal insp_en   : std_logic := '0';
  signal insp_slot : integer range 0 to C_SLOTS - 1 := 0;
  signal insp_addr : std_logic_vector(7 downto 0) := (others => '0');
  signal insp_data : std_logic_vector(15 downto 0);

begin

  clk <= not clk after 5 ns;

  dut : entity work.kem_core
    port map (clk => clk, rst_n => rst_n, op => op, start => start,
              done => done, busy => busy, rejected => rejected,
              h_addr => h_addr, h_din => h_din, h_we => h_we, h_sel => h_sel,
              h_dout => h_dout,
              insp_en => insp_en, insp_slot => insp_slot,
              insp_addr => insp_addr, insp_data => insp_data);

  process
    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 2);
    variable c   : character;
    variable ch1, ch2 : character;
    variable v   : integer;
    variable sig : unsigned(63 downto 0) := x"cbf29ce484222325";
    type t_buf is array (0 to 2559) of integer;
    variable d_b, z_b, m_b : t_buf;
    variable ek_b, dk_b, ct_b, ss_b : t_buf;

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
      h_addr <= std_logic_vector(to_unsigned(a, 13));
      h_din  <= std_logic_vector(to_unsigned(d, 8));
      h_we   <= '1';
      wait_clk(1);
      h_we   <= '0';
      wait_clk(1);
    end procedure;

    procedure bread (constant a : in integer; variable d : out integer) is
    begin
      h_sel  <= '1';
      h_addr <= std_logic_vector(to_unsigned(a, 13));
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

    procedure rdhex (variable buf : out t_buf; constant n : in integer) is
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

    file_open(fh, "kem_st_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      next when ln'length < 3;
      read(ln, tag);
      exit when tag = "ST";
    end loop;

    rdhex(d_b, 32);
    rdhex(z_b, 32);
    rdhex(m_b, 32);
    rdhex(ek_b, C_EK);
    rdhex(dk_b, C_DK);
    rdhex(ct_b, C_CT);
    rdhex(ss_b, 32);
    file_close(fh);

    ------------------------------------------------------------------
    -- KeyGen: d at 0, z at 32; ek out at 512, dk out at 2048.
    ------------------------------------------------------------------
    for i in 0 to 31 loop
      bwrite(i, d_b(i));
      bwrite(32 + i, z_b(i));
    end loop;
    run_op("00");

    for i in 0 to C_EK - 1 loop
      bread(512 + i, v);
      assert v = ek_b(i)
        report "TB FAIL keygen ek byte " & integer'image(i) &
               " got=" & integer'image(v) & " exp=" & integer'image(ek_b(i))
        severity failure;
      fnv(sig, v);
    end loop;
    for i in 0 to C_DK - 1 loop
      bread(2048 + i, v);
      assert v = dk_b(i)
        report "TB FAIL keygen dk byte " & integer'image(i) &
               " got=" & integer'image(v) & " exp=" & integer'image(dk_b(i))
        severity failure;
      fnv(sig, v);
    end loop;

    -- KeyGen writes dk at 2048 and Encaps writes ct at 2048: the maps
    -- collide in the chain. The byte maps are frozen -- changing them
    -- invalidates the Layer 3A signatures -- so the driver parks dk above
    -- the region Encaps uses and restores it before Decaps. This is the
    -- moving-bytes-between-operations that the overlapping maps require, and
    -- exactly what software above the core would do.
    for i in 0 to C_DK - 1 loop
      bread(2048 + i, v);
      bwrite(5000 + i, v);
    end loop;

    ------------------------------------------------------------------
    -- Encaps: m at 0, ek stays at 512 (KeyGen wrote it there); ct out at
    -- 2048, shared secret Kbar at 32. The ek moved is the core's own.
    ------------------------------------------------------------------
    for i in 0 to 31 loop
      bwrite(i, m_b(i));
    end loop;
    run_op("01");

    for i in 0 to C_CT - 1 loop
      bread(2048 + i, v);
      assert v = ct_b(i)
        report "TB FAIL encaps ct byte " & integer'image(i) &
               " got=" & integer'image(v) & " exp=" & integer'image(ct_b(i))
        severity failure;
      fnv(sig, v);
    end loop;
    -- capture Encaps's shared secret for the round-trip comparison
    for i in 0 to 31 loop
      bread(32 + i, v);
      assert v = ss_b(i)
        report "TB FAIL encaps K byte " & integer'image(i) &
               " got=" & integer'image(v) & " exp=" & integer'image(ss_b(i))
        severity failure;
      fnv(sig, v);
    end loop;

    ------------------------------------------------------------------
    -- Decaps: ct moves from 2048 to 0, dk stays at 2048; Kout at 1280.
    ------------------------------------------------------------------
    -- ct moves to 0 for Decaps, and dk is restored from its high park to
    -- 2048 where Decaps reads it.
    for i in 0 to C_CT - 1 loop
      bread(2048 + i, v);
      bwrite(i, v);
    end loop;
    for i in 0 to C_DK - 1 loop
      bread(5000 + i, v);
      bwrite(2048 + i, v);
    end loop;
    run_op("10");

    -- the round-trip property: Decaps recovers Encaps's shared secret
    for i in 0 to 31 loop
      bread(1280 + i, v);
      assert v = ss_b(i)
        report "TB FAIL decaps Kout byte " & integer'image(i) &
               " got=" & integer'image(v) & " exp=" & integer'image(ss_b(i)) &
               " (ACVP comparisons passed, so this is a round-trip" &
               " consistency failure)"
        severity failure;
      fnv(sig, v);
    end loop;

    assert rejected = '0'
      report "TB FAIL decaps implicit rejection fired on a valid ciphertext"
      severity failure;

    report "PQC L4 KEMCORE PASS keygen+encaps+decaps chained sig=" &
           to_hex(sig)
      severity note;
    std.env.finish;
    wait;
  end process;

end architecture sim;
