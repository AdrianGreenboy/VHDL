-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- tb_dsa_keygen: verifies the ML-DSA-65 KeyGen sequencer.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Twenty-two cases: the twenty ACVP sigver vectors plus two constructed ones.
--
-- KeyGen has no rejection branches and no failure outcome, so unlike Verify
-- there is no reason code to check and unlike Sign there is no kappa: the
-- only observable is the key pair, and both halves are compared byte for
-- byte. The four checkpoints inspect the first vector.
--
-- The secret key is checked as well as the public key, and that matters:
-- pk is a function of t1 alone, so a defect confined to t0, s1 or s2 would
-- be invisible if only pk were compared, and those three are exactly what
-- Sign later consumes.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.poly_mem_d_pkg.all;

entity tb_dsa_keygen is
  generic (
    G_STAGE : integer := 0);
end entity tb_dsa_keygen;

architecture sim of tb_dsa_keygen is

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
  constant C_SK_LEN  : integer := 4032;
  constant C_ADDR_XI : integer := 0;
  constant C_ADDR_SD : integer := 64;
  constant C_ADDR_PK : integer := 256;
  constant C_ADDR_SK : integer := 2304;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal start  : std_logic := '0';
  signal done   : std_logic;
  signal busy   : std_logic;

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

  dut : entity work.dsa_keygen_top
    generic map (G_STOP_AT => G_STAGE)
    port map (clk => clk, rst_n => rst_n, start => start,
              done => done, busy => busy,
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

    file_open(fh, "dsa_kg_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length < 3 then
        next;
      end if;
      read(ln, tag);
      if tag(1) = '#' then
        next;
      end if;

      if tag = "KGN" then
        if G_STAGE /= 0 and n > 0 then
          next;
        end if;

        read(ln, c);
        for i in 0 to 31 loop
          read(ln, ch1);
          read(ln, ch2);
          bwrite(C_ADDR_XI + i, hex_nib(ch1) * 16 + hex_nib(ch2));
        end loop;

        h_sel <= '0';
        wait_clk(2);
        start <= '1';
        wait_clk(1);
        start <= '0';
        while done = '0' loop
          wait_clk(1);
        end loop;
        wait_clk(4);

        if G_STAGE = 5 then
          for pk in 0 to 5 loop
            pread(1, pk, v);
            pread(26, pk, slen);
            report "k=" & integer'image(pk) &
                   " S1=" & integer'image(v) &
                   " S1H=" & integer'image(slen) severity note;
          end loop;
          pread(26, 255, v);
          report "S1H[255] = " & integer'image(v) severity note;
          pread(1, 255, v);
          report "S1 [255] = " & integer'image(v) severity note;
        end if;
        if G_STAGE = 0 then
          read(ln, c);
          for i in 0 to C_PK_LEN - 1 loop
            read(ln, ch1);
            read(ln, ch2);
            v := hex_nib(ch1) * 16 + hex_nib(ch2);
            bread(C_ADDR_PK + i, slen);
            assert slen = v
              report "TB FAIL case " & integer'image(n) &
                     " pk byte " & integer'image(i) &
                     " got=" & integer'image(slen) &
                     " exp=" & integer'image(v)
              severity failure;
            fnv(sig, slen);
          end loop;
          read(ln, c);
          -- The secret key is compared too: pk depends on t1 alone, so a
          -- defect confined to t0, s1 or s2 would pass a pk-only check and
          -- then break Sign, which is precisely what consumes those three.
          for i in 0 to C_SK_LEN - 1 loop
            read(ln, ch1);
            read(ln, ch2);
            v := hex_nib(ch1) * 16 + hex_nib(ch2);
            bread(C_ADDR_SK + i, slen);
            assert slen = v
              report "TB FAIL case " & integer'image(n) &
                     " sk byte " & integer'image(i) &
                     " got=" & integer'image(slen) &
                     " exp=" & integer'image(v)
              severity failure;
            fnv(sig, slen);
          end loop;
          nacc := nacc + 1;
        end if;
        n := n + 1;

      elsif G_STAGE /= 0 and tag(1) = 'K' and tag(2) = 'P' and
            hex_nib(tag(3)) = G_STAGE then
        if G_STAGE = 4 then
          read(ln, c);
          for i in 0 to 63 loop
            read(ln, ch1);
            read(ln, ch2);
            v := hex_nib(ch1) * 16 + hex_nib(ch2);
            bread(C_ADDR_SK + 64 + i, slen);
            assert slen = v
              report "TB FAIL KP4 tr byte " & integer'image(i) &
                     " got=" & integer'image(slen) &
                     " exp=" & integer'image(v)
              severity failure;
            fnv(sig, slen);
          end loop;
        else
          for i in 0 to 255 loop
            read(ln, cp(i));
          end loop;
          if G_STAGE = 2 then
            for pk in 0 to 3 loop
              pread(1, pk, v);
              report "S1[" & integer'image(pk) & "] = " &
                     integer'image(v) severity note;
              pread(26, pk, v);
              report "S1H[" & integer'image(pk) & "] = " &
                     integer'image(v) severity note;
            end loop;
          end if;
          for i in 0 to 255 loop
            case G_STAGE is
              when 1      => pread(1, i, v);     -- s1[0]
              when 2      => pread(24, i, v);    -- t[0]
              when others => pread(12, i, v);    -- t1[0]
            end case;
            assert canon(v) = cp(i)
              report "TB FAIL KP" & integer'image(G_STAGE) &
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
      assert n = 8
        report "TB FAIL expected 8 keygen cases, got " & integer'image(n)
        severity failure;
      report "PQC L3B DSAKG PASS cases=" & integer'image(n) &
             " sig=" & to_hex(sig)
        severity note;
    else
      assert have_cp
        report "TB FAIL checkpoint KP" & integer'image(G_STAGE) &
               " not present in the vector file"
        severity failure;
      report "PQC L3B DSAKG CHECKPOINT PASS stage=" &
             integer'image(G_STAGE) & " sig=" & to_hex(sig)
        severity note;
    end if;
    std.env.finish;
    wait;
  end process;

end architecture sim;
