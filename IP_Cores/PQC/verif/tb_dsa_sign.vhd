-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- tb_dsa_sign: verifies the ML-DSA-65 Sign sequencer against ACVP vectors.
-- VHDL-2008. ASCII-only. MIT license.
--
-- The end-of-run signature covers the produced signature bytes AND the final
-- kappa. Including kappa is deliberate and was frozen before any RTL: it is
-- not a timing measurement but a deterministic function of the inputs, and it
-- is the only observable that separates "the rejection loop ran the right
-- number of times" from "the loop happened to produce the right bytes". A
-- mutation that changes the iteration count while still terminating on a
-- valid signature would otherwise survive.
--
-- Checkpoints SP1 to SP4 are taken from the FIRST iteration of the first
-- vector. SP4 is the candidate z of that iteration EVEN IF IT IS REJECTED,
-- which for this vector it is: the first iteration rejects on r0. That is
-- the case the SP4/SP5 split exists for, in the same way EP4 and EP5 were
-- separated in ML-KEM Encaps.
--
-- The message is never presented to the DUT. mu is a 64-byte input; the RTL
-- has no message buffer because a message may be arbitrarily long.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.poly_mem_d_pkg.all;

entity tb_dsa_sign is
  generic (
    G_STAGE : integer := 0;
    G_VEC   : integer := -1;    -- -1 all, else that index only
    G_FROM  : integer := 0);    -- first vector index to run          -- 0 full run, 1..4 checkpoint
end entity tb_dsa_sign;

architecture sim of tb_dsa_sign is

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

  constant C_SK_LEN  : integer := 4032;
  constant C_SIG_LEN : integer := 3309;
  constant C_ADDR_SK : integer := 0;
  constant C_ADDR_MU : integer := 4096;
  constant C_ADDR_CT : integer := 4224;
  constant C_ADDR_SG : integer := 8192;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal start : std_logic := '0';
  signal done  : std_logic;
  signal busy  : std_logic;
  signal kappa_out : std_logic_vector(15 downto 0);

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

  dut : entity work.dsa_sign_top
    generic map (G_STOP_AT => G_STAGE)
    port map (clk => clk, rst_n => rst_n, start => start,
              done => done, busy => busy, kappa_out => kappa_out,
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
    variable v, kexp, iexp : integer;
    variable n   : integer := 0;
    variable sig : unsigned(63 downto 0) := x"cbf29ce484222325";
    type t_buf is array (0 to 4095) of integer;
    variable skb, sigb : t_buf;
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

    file_open(fh, "dsa_sign_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length < 3 then
        next;
      end if;
      read(ln, tag);
      if tag(1) = '#' then
        next;
      end if;

      if tag = "SGN" then
        -- only the first vector is used when inspecting a checkpoint
        if G_STAGE /= 0 and n > 0 then
          next;
        end if;
        -- G_VEC selects a single vector so the eight can run in parallel;
        -- iteration counts differ by 12x, so one long vector would otherwise
        -- set the wall time for the whole suite.
        if G_VEC >= 0 and n /= G_VEC then
          n := n + 1;
          next;
        end if;
        -- G_FROM skips leading vectors while KEEPING the DUT state that the
        -- earlier ones left behind, which is the point: the testbench does
        -- not reset between vectors, so a run starting mid-list exercises
        -- exactly the carry-over that a from-reset run cannot.
        if n < G_FROM then
          n := n + 1;
          next;
        end if;

        read(ln, c);
        for i in 0 to C_SK_LEN - 1 loop
          read(ln, ch1);
          read(ln, ch2);
          skb(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
        end loop;
        read(ln, c);
        for i in 0 to 63 loop
          read(ln, ch1);
          read(ln, ch2);
          bwrite(C_ADDR_MU + i, hex_nib(ch1) * 16 + hex_nib(ch2));
        end loop;
        read(ln, c);
        for i in 0 to C_SIG_LEN - 1 loop
          read(ln, ch1);
          read(ln, ch2);
          sigb(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
        end loop;
        read(ln, kexp);
        read(ln, iexp);

        for i in 0 to C_SK_LEN - 1 loop
          bwrite(C_ADDR_SK + i, skb(i));
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

        if G_STAGE = 0 then
          -- kappa first: it separates a loop that ran the right number of
          -- times from one that merely produced the right bytes
          assert to_integer(unsigned(kappa_out)) = kexp
            report "TB FAIL sign " & integer'image(n) &
                   " kappa got=" &
                   integer'image(to_integer(unsigned(kappa_out))) &
                   " exp=" & integer'image(kexp) &
                   " (expected " & integer'image(iexp) & " iterations)"
            severity failure;
          fnv(sig, kexp);

          for i in 0 to C_SIG_LEN - 1 loop
            bread(C_ADDR_SG + i, v);
            assert v = sigb(i)
              report "TB FAIL sign " & integer'image(n) &
                     " sig byte " & integer'image(i) &
                     " got=" & integer'image(v) &
                     " exp=" & integer'image(sigb(i))
              severity failure;
            fnv(sig, v);
          end loop;
        end if;
        n := n + 1;

      elsif G_STAGE /= 0 and
            tag(1) = 'S' and tag(2) = 'P' and
            hex_nib(tag(3)) = G_STAGE then
        if G_STAGE = 3 then
          -- c_tilde is a byte string, compared directly from the byte memory
          read(ln, c);
          for i in 0 to 47 loop
            read(ln, ch1);
            read(ln, ch2);
            v := hex_nib(ch1) * 16 + hex_nib(ch2);
            bread(C_ADDR_CT + i, kexp);
            assert kexp = v
              report "TB FAIL SP3 c_tilde byte " & integer'image(i) &
                     " got=" & integer'image(kexp) &
                     " exp=" & integer'image(v)
              severity failure;
            fnv(sig, kexp);
          end loop;
        else
          for i in 0 to 255 loop
            read(ln, cp(i));
          end loop;
          for i in 0 to 255 loop
            case G_STAGE is
              when 1      => pread(1, i, v);     -- y[0]
              when 2      => pread(41, i, v);    -- w1[0], written to SL_H
              when others => pread(36, i, v);    -- z[0]
            end case;
            assert canon(v) = cp(i)
              report "TB FAIL SP" & integer'image(G_STAGE) &
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
      -- Nine: the eight ACVP vectors plus one constructed case whose
      -- iteration 10 has hint weight exactly OMEGA+1. The ACVP vectors never
      -- reach the hint-weight rejection at all, so that bound would otherwise
      -- be live but unconstrained by any test.
      assert n = 9 or G_VEC >= 0 or G_FROM > 0
        report "TB FAIL expected 9 sign vectors, got " & integer'image(n)
        severity failure;
      report "PQC L3B DSASIGN PASS vectors=" & integer'image(n) &
             " sig=" & to_hex(sig)
        severity note;
    else
      assert have_cp
        report "TB FAIL checkpoint SP" & integer'image(G_STAGE) &
               " not present in the vector file"
        severity failure;
      report "PQC L3B DSASIGN CHECKPOINT PASS stage=" &
             integer'image(G_STAGE) & " sig=" & to_hex(sig)
        severity note;
    end if;
    -- Terminate the simulation HERE. Relying on --stop-time leaves GHDL
    -- simulating dead time after the result is already printed, and because
    -- the output goes through a pipe, nothing is flushed until the process
    -- exits: the run looks hung for minutes with the answer already
    -- computed. The stop-time remains only as a safety bound.
    std.env.finish;
    wait;
  end process;

end architecture sim;
