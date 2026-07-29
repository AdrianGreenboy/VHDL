-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- tb_dsa_verify: verifies the ML-DSA-65 Verify sequencer.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Twenty-two cases: the twenty ACVP sigver vectors plus two constructed ones.
--
-- THE REASON CODE IS CHECKED, NOT JUST THE VERDICT. Verify returns a single
-- bit, and a signature over twenty-two booleans cannot tell a rejection from
-- a rejection for the right reason: under that output every rejection branch
-- is interchangeable and any mutation that swaps one for another survives.
-- The reason code goes into the end-of-run signature for the same reason
-- kappa does in Sign.
--
-- The ACVP vectors cover only three of the five outcomes: 4 accept, 11
-- c_tilde mismatch, 5 hint decode, and ZERO for the length and z-bound
-- branches. Those two were constructed before the RTL was written rather
-- than after a mutation survived, which is the mistake this core has already
-- made four times. The z-bound case has a coefficient exactly on
-- GAMMA1 - BETA, the only value at which >= and > differ.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.poly_mem_d_pkg.all;

entity tb_dsa_verify is
  generic (
    G_STAGE : integer := 0);
end entity tb_dsa_verify;

architecture sim of tb_dsa_verify is

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

  constant C_PK_LEN  : integer := 1952;
  constant C_SIG_MAX : integer := 3309;
  constant C_ADDR_PK : integer := 0;
  constant C_ADDR_MU : integer := 2048;
  constant C_ADDR_SG : integer := 2176;
  constant C_ADDR_CT : integer := 5632;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
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

  signal hp_sel  : std_logic := '0';
  signal hp_slot : integer range 0 to C_SLOTS_D - 1 := 0;
  signal hp_addr : std_logic_vector(7 downto 0) := (others => '0');
  signal hp_dout : std_logic_vector(C_CW - 1 downto 0);

begin

  clk <= not clk after 5 ns;

  dut : entity work.dsa_verify_top
    generic map (G_STOP_AT => G_STAGE)
    port map (clk => clk, rst_n => rst_n, start => start, siglen => siglen,
              done => done, busy => busy, result => result, reason => reason,
              h_sel => h_sel, h_addr => h_addr, h_din => h_din,
              h_we => h_we, h_dout => h_dout,
              hp_sel => hp_sel, hp_slot => hp_slot, hp_addr => hp_addr,
              hp_dout => hp_dout);

  process
    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 3);
    variable c   : character;
    variable ch1, ch2 : character;
    variable v, slen, eres, ersn : integer;
    variable n   : integer := 0;
    variable nacc, nrej : integer := 0;
    variable sig : unsigned(63 downto 0) := x"cbf29ce484222325";
    type t_poly is array (0 to 255) of integer;
    variable cp : t_poly;
    variable have_cp : boolean := false;

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

    procedure pread (constant sl : in integer; constant a : in integer;
                     variable d : out integer) is
    begin
      hp_sel  <= '1';
      hp_slot <= sl;
      hp_addr <= std_logic_vector(to_unsigned(a, 8));
      wait_clk(2);
      d := to_integer(signed(hp_dout));
      hp_sel  <= '0';
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

    file_open(fh, "dsa_ver_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length < 3 then
        next;
      end if;
      read(ln, tag);
      if tag(1) = '#' then
        next;
      end if;

      if tag = "VER" then
        if G_STAGE /= 0 and n > 0 then
          next;
        end if;

        read(ln, c);
        for i in 0 to C_PK_LEN - 1 loop
          read(ln, ch1);
          read(ln, ch2);
          bwrite(C_ADDR_PK + i, hex_nib(ch1) * 16 + hex_nib(ch2));
        end loop;
        read(ln, c);
        for i in 0 to 63 loop
          read(ln, ch1);
          read(ln, ch2);
          bwrite(C_ADDR_MU + i, hex_nib(ch1) * 16 + hex_nib(ch2));
        end loop;
        read(ln, slen);
        read(ln, c);
        -- The signature is variable length, so siglen precedes it in the
        -- vector file: the length branch needs a case one byte short, and
        -- the reader cannot know how many hex characters to consume
        -- otherwise. Bytes beyond the presented length are left at zero.
        for i in 0 to C_SIG_MAX - 1 loop
          bwrite(C_ADDR_SG + i, 0);
        end loop;
        for i in 0 to slen - 1 loop
          read(ln, ch1);
          read(ln, ch2);
          bwrite(C_ADDR_SG + i, hex_nib(ch1) * 16 + hex_nib(ch2));
        end loop;
        read(ln, eres);
        read(ln, ersn);

        siglen <= std_logic_vector(to_unsigned(slen, 16));
        h_sel  <= '0';
        wait_clk(2);
        start <= '1';
        wait_clk(1);
        start <= '0';
        while done = '0' loop
          wait_clk(1);
        end loop;
        wait_clk(4);

        if G_STAGE = 0 then
          assert (result = '1') = (eres = 1)
            report "TB FAIL case " & integer'image(n) &
                   " verdict got=" & std_logic'image(result) &
                   " exp=" & integer'image(eres)
            severity failure;
          assert to_integer(unsigned(reason)) = ersn
            report "TB FAIL case " & integer'image(n) &
                   " reason got=" &
                   integer'image(to_integer(unsigned(reason))) &
                   " exp=" & integer'image(ersn) &
                   " (verdict was right, the branch taken was not)"
            severity failure;
          fnv(sig, eres);
          fnv(sig, ersn);
          if eres = 1 then
            nacc := nacc + 1;
          else
            nrej := nrej + 1;
          end if;
        end if;
        n := n + 1;

      elsif G_STAGE /= 0 and tag(1) = 'V' and tag(2) = 'P' and
            hex_nib(tag(3)) = G_STAGE then
        if G_STAGE = 4 then
          read(ln, c);
          for i in 0 to 47 loop
            read(ln, ch1);
            read(ln, ch2);
            v := hex_nib(ch1) * 16 + hex_nib(ch2);
            bread(C_ADDR_CT + i, slen);
            assert slen = v
              report "TB FAIL VP4 c_tilde byte " & integer'image(i) &
                     " got=" & integer'image(slen) &
                     " exp=" & integer'image(v)
              severity failure;
            fnv(sig, slen);
          end loop;
        else
          for i in 0 to 255 loop
            read(ln, cp(i));
          end loop;
          for i in 0 to 255 loop
            case G_STAGE is
              when 1      => pread(1, i, v);     -- z[0]
              when 2      => pread(25, i, v);    -- w[0] in scratch
              when others => pread(12, i, v);    -- w1[0] over the hint slot
            end case;
            assert canon(v) = cp(i)
              report "TB FAIL VP" & integer'image(G_STAGE) &
                     " coeff " & integer'image(i) &
                     " got=" & integer'image(canon(v)) &
                     " exp=" & integer'image(cp(i))
              severity failure;
            fnv(sig, canon(v));
          end loop;
        end if;
        have_cp := true;
      end if;
    end loop;
    file_close(fh);

    if G_STAGE = 0 then
      assert n = 22
        report "TB FAIL expected 22 verify cases, got " & integer'image(n)
        severity failure;
      assert nacc = 4
        report "TB FAIL expected 4 accepted cases, got " & integer'image(nacc)
        severity failure;
      report "PQC L3B DSAVER PASS cases=" & integer'image(n) &
             " accept=" & integer'image(nacc) &
             " reject=" & integer'image(nrej) &
             " sig=" & to_hex(sig)
        severity note;
    else
      assert have_cp
        report "TB FAIL checkpoint VP" & integer'image(G_STAGE) &
               " not present in the vector file"
        severity failure;
      report "PQC L3B DSAVER CHECKPOINT PASS stage=" &
             integer'image(G_STAGE) & " sig=" & to_hex(sig)
        severity note;
    end if;
    std.env.finish;
    wait;
  end process;

end architecture sim;
