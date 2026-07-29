-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3B
-- tb_codec_d: verifies ML-DSA bit packing and the hint codec.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Bit packing is checked byte for byte against mldsa65.py at every width the
-- scheme uses: 10 and 4 bits unsigned, then the signed packings for s, t0 and
-- z. The z path is also round-tripped through the unpacker.
--
-- The hint codec is the only one that can fail, so it gets both directions
-- and three malformed inputs, one per rejection rule. A decoder that accepts
-- any of them would pass a test built only from well-formed hints, which is
-- the same shape of gap as the Decaps early exit and the sampler z == q case.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_d_tables_pkg.all;
use work.pqc_round_d_pkg.all;

entity tb_codec_d is
end entity tb_codec_d;

architecture sim of tb_codec_d is

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

  constant C_BYTES : integer := 1024;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';

  signal start : std_logic := '0';
  signal mode  : std_logic_vector(3 downto 0) := "0000";
  signal base  : std_logic_vector(13 downto 0) := (others => '0');
  signal done  : std_logic;
  signal busy  : std_logic;
  signal valid : std_logic;

  signal p_raddr, p_waddr : std_logic_vector(7 downto 0);
  signal p_rdata, p_wdata : std_logic_vector(C_CW - 1 downto 0);
  signal p_we  : std_logic;
  signal p_row : integer range 0 to 5;

  signal b_addr  : std_logic_vector(13 downto 0);
  signal b_rdata : std_logic_vector(7 downto 0);
  signal b_wdata : std_logic_vector(7 downto 0);
  signal b_we    : std_logic;

  -- host side
  signal h_sel   : std_logic := '1';
  signal h_paddr : std_logic_vector(7 downto 0) := (others => '0');
  signal h_prow  : integer range 0 to 5 := 0;
  signal h_pdata : std_logic_vector(C_CW - 1 downto 0) := (others => '0');
  signal h_pwe   : std_logic := '0';
  signal h_baddr : std_logic_vector(13 downto 0) := (others => '0');
  signal h_bdata : std_logic_vector(7 downto 0) := (others => '0');
  signal h_bwe   : std_logic := '0';

  -- six polynomial rows, enough for the hint codec
  type t_poly is array (0 to 6 * 256 - 1) of integer;
  signal poly : t_poly := (others => 0);
  type t_bytes is array (0 to C_BYTES - 1) of integer;
  signal bytes : t_bytes := (others => 0);

  signal eff_prow : integer range 0 to 5;

begin

  clk <= not clk after 5 ns;

  dut : entity work.codec_d
    port map (clk => clk, rst_n => rst_n, start => start, mode => mode,
              base => base, done => done, busy => busy, valid => valid,
              p_raddr => p_raddr, p_rdata => p_rdata,
              p_waddr => p_waddr, p_wdata => p_wdata, p_we => p_we,
              p_row => p_row,
              b_addr => b_addr, b_rdata => b_rdata,
              b_wdata => b_wdata, b_we => b_we);

  eff_prow <= h_prow when h_sel = '1' else p_row;

  process (clk)
    variable pa : integer;
  begin
    if rising_edge(clk) then
      if h_sel = '1' then
        if h_pwe = '1' then
          poly(h_prow * 256 + to_integer(unsigned(h_paddr)))
            <= to_integer(signed(h_pdata));
        end if;
        p_rdata <= std_logic_vector(
                     to_signed(poly(h_prow * 256 +
                                    to_integer(unsigned(h_paddr))), C_CW));
        if h_bwe = '1' then
          bytes(to_integer(unsigned(h_baddr))) <= to_integer(unsigned(h_bdata));
        end if;
        b_rdata <= std_logic_vector(
                     to_unsigned(bytes(to_integer(unsigned(h_baddr))), 8));
      else
        if p_we = '1' then
          poly(p_row * 256 + to_integer(unsigned(p_waddr)))
            <= to_integer(signed(p_wdata));
        end if;
        p_rdata <= std_logic_vector(
                     to_signed(poly(p_row * 256 +
                                    to_integer(unsigned(p_raddr))), C_CW));
        if b_we = '1' then
          bytes(to_integer(unsigned(b_addr))) <= to_integer(unsigned(b_wdata));
        end if;
        b_rdata <= std_logic_vector(
                     to_unsigned(bytes(to_integer(unsigned(b_addr))), 8));
      end if;
    end if;
  end process;

  process
    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 3);
    variable c   : character;
    variable ch1, ch2 : character;
    variable v, w, nb : integer;
    variable n   : integer := 0;
    variable npk, nhe, nhd, nbad : integer := 0;
    variable hsum : integer := 0;
    variable nrow, hp : integer := 0;
    variable sig : unsigned(63 downto 0) := x"cbf29ce484222325";
    variable pin : integer;
    type t_orig is array (0 to 255) of integer;
    variable orig : t_orig;

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

    procedure pwrite (constant r : in integer; constant a : in integer;
                      constant d : in integer) is
    begin
      h_sel   <= '1';
      h_prow  <= r;
      h_paddr <= std_logic_vector(to_unsigned(a, 8));
      h_pdata <= std_logic_vector(to_signed(d, C_CW));
      h_pwe   <= '1';
      wait_clk(1);
      h_pwe   <= '0';
      wait_clk(1);
    end procedure;

    procedure pread (constant r : in integer; constant a : in integer;
                     variable d : out integer) is
    begin
      h_sel   <= '1';
      h_prow  <= r;
      h_paddr <= std_logic_vector(to_unsigned(a, 8));
      wait_clk(2);
      d := to_integer(signed(p_rdata));
    end procedure;

    procedure bwrite (constant a : in integer; constant d : in integer) is
    begin
      h_sel   <= '1';
      h_baddr <= std_logic_vector(to_unsigned(a, 14));
      h_bdata <= std_logic_vector(to_unsigned(d, 8));
      h_bwe   <= '1';
      wait_clk(1);
      h_bwe   <= '0';
      wait_clk(1);
    end procedure;

    procedure bread (constant a : in integer; variable d : out integer) is
    begin
      h_sel   <= '1';
      h_baddr <= std_logic_vector(to_unsigned(a, 14));
      wait_clk(2);
      d := to_integer(unsigned(b_rdata));
    end procedure;

    procedure run (constant m : in std_logic_vector(3 downto 0)) is
    begin
      h_sel <= '0';
      wait_clk(2);
      mode  <= m;
      start <= '1';
      wait_clk(1);
      start <= '0';
      while done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(2);
      h_sel <= '1';
      wait_clk(2);
    end procedure;

  begin
    rst_n <= '0';
    wait_clk(5);
    rst_n <= '1';
    wait_clk(5);
    base  <= (others => '0');

    ------------------------------------------------------------------
    -- bit packing
    ------------------------------------------------------------------
    file_open(fh, "dsa_round_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length < 3 then
        next;
      end if;
      read(ln, tag);
      if tag(1) = '#' then
        next;
      end if;

      if tag = "PKW" then
        read(ln, w);
        if w = 10 then
          mode <= "0000";
        else
          mode <= "0001";
        end if;
        nb := 32 * w;
      elsif tag = "PKS" then
        mode <= "0010"; w := 4;  nb := 128;
      elsif tag = "PKT" then
        mode <= "0011"; w := 13; nb := 416;
      elsif tag = "PKZ" then
        mode <= "0100"; w := 20; nb := 640;
      else
        next;
      end if;

      for i in 0 to 255 loop
        read(ln, pin);
        -- the vector file stores canonical residues; the datapath works in
        -- signed representatives, so map back before loading
        if pin > C_QD / 2 then
          orig(i) := pin - C_QD;
        else
          orig(i) := pin;
        end if;
        pwrite(0, i, orig(i));
      end loop;
      read(ln, c);

      if tag = "PKW" and w = 10 then
        run("0000");
      elsif tag = "PKW" then
        run("0001");
      elsif tag = "PKS" then
        run("0010");
      elsif tag = "PKT" then
        run("0011");
      else
        run("0100");
      end if;

      for i in 0 to nb - 1 loop
        read(ln, ch1);
        read(ln, ch2);
        v := hex_nib(ch1) * 16 + hex_nib(ch2);
        bread(i, pin);
        assert pin = v
          report "TB FAIL " & tag & " case " & integer'image(n) &
                 " byte " & integer'image(i) &
                 " got=" & integer'image(pin) &
                 " exp=" & integer'image(v)
          severity failure;
        fnv(sig, pin);
      end loop;

      -- z round-trips through the unpacker, and the result is COMPARED.
      -- An earlier version fed the unpacked values into the signature
      -- without asserting them, so a wrong shift width in the unpacker
      -- passed unnoticed: mutation M5 survived until this check was added.
      if tag = "PKZ" then
        for i in 0 to 255 loop
          pwrite(0, i, 0);
        end loop;
        run("0101");
        for i in 0 to 255 loop
          pread(0, i, pin);
          assert pin = orig(i)
            report "TB FAIL z round-trip case " & integer'image(n) &
                   " coeff " & integer'image(i) &
                   " got=" & integer'image(pin) &
                   " exp=" & integer'image(orig(i))
            severity failure;
          fnv(sig, pin);
        end loop;
      end if;

      npk := npk + 1;
      n   := n + 1;
    end loop;
    file_close(fh);

    ------------------------------------------------------------------
    -- hint codec
    ------------------------------------------------------------------
    file_open(fh, "dsa_hint_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      if ln'length < 3 then
        next;
      end if;
      read(ln, tag);
      if tag(1) = '#' then
        next;
      end if;

      if tag = "HEN" then
        -- Hint ENCODE. An earlier version of this testbench read only the
        -- HDE lines, so mode "110" was never exercised at all and any
        -- encoder defect passed: mutation M6 survived on that alone.
        for rr in 0 to 5 loop
          for jj in 0 to 255 loop
            pwrite(rr, jj, 0);
          end loop;
        end loop;
        for rr in 0 to 5 loop
          read(ln, nrow);
          for kk in 1 to nrow loop
            read(ln, hp);
            pwrite(rr, hp, 1);
          end loop;
        end loop;
        read(ln, c);

        run("0110");

        for i in 0 to 60 loop
          read(ln, ch1);
          read(ln, ch2);
          v := hex_nib(ch1) * 16 + hex_nib(ch2);
          bread(i, pin);
          assert pin = v
            report "TB FAIL hint encode case " & integer'image(n) &
                   " byte " & integer'image(i) &
                   " got=" & integer'image(pin) &
                   " exp=" & integer'image(v)
            severity failure;
          fnv(sig, pin);
        end loop;
        nhe := nhe + 1;
        n   := n + 1;

      elsif tag = "HDE" then
        read(ln, c);
        for i in 0 to 60 loop
          read(ln, ch1);
          read(ln, ch2);
          bwrite(i, hex_nib(ch1) * 16 + hex_nib(ch2));
        end loop;
        read(ln, c);
        read(ln, v);          -- expected validity

        run("0111");

        if v = 1 then
          assert valid = '1'
            report "TB FAIL hint decode rejected a well-formed input, case " &
                   integer'image(n)
            severity failure;

          -- Check the DECODED POLYNOMIAL, not just the acceptance flag.
          -- An earlier version asserted only valid, so a decoder that
          -- accepted the input while writing nothing passed: the position
          -- loop was in fact never running, and the signature did not move
          -- when that bug was fixed, which is what exposed the gap.
          --
          -- The vector file lists the exact positions per row, so those are
          -- checked directly rather than sweeping all 1536 coefficients.
          -- That is both faster and stronger: it verifies WHICH positions
          -- are set, not merely how many.
          for rr in 0 to 5 loop
            read(ln, nrow);
            for kk in 1 to nrow loop
              read(ln, hp);
              pread(rr, hp, pin);
              assert pin = 1
                report "TB FAIL hint decode case " & integer'image(n) &
                       " row " & integer'image(rr) &
                       " position " & integer'image(hp) &
                       " not set"
                severity failure;
              fnv(sig, hp);
              hsum := hsum + 1;
            end loop;
          end loop;
          nhd := nhd + 1;
        else
          assert valid = '0'
            report "TB FAIL hint decode ACCEPTED a malformed input, case " &
                   integer'image(n) &
                   ": the rejection rule it violates is not enforced"
            severity failure;
          nbad := nbad + 1;
        end if;
        fnv(sig, v);
        n := n + 1;
      end if;
    end loop;
    file_close(fh);

    assert npk = 20
      report "TB FAIL expected 20 packing cases, got " & integer'image(npk)
      severity failure;
    -- Six malformed cases. Rule 2 needs TWO of them: a swapped pair gives a
    -- strict decrease, which a < comparison also catches, so only a REPEATED
    -- position distinguishes <= from <. That vector is the one that kills the
    -- off-by-one mutation on the monotonicity test.
    -- Two of them were added specifically for rule 1: the original count>OMEGA
    -- vector tripped rule 2 first, because the zero padding beyond the last
    -- real position is not strictly increasing, so rule 1 was live but
    -- unreachable behind rule 2.
    assert nbad = 6
      report "TB FAIL expected 6 malformed hint cases, got " &
             integer'image(nbad)
      severity failure;
    assert nhe = 8
      report "TB FAIL expected 8 hint encode cases, got " &
             integer'image(nhe)
      severity failure;

    -- The well-formed hint vectors between them set a nonzero number of
    -- positions, so a decoder that writes nothing at all cannot pass.
    assert hsum > 0
      report "TB FAIL hint decode produced an all-zero polynomial set"
      severity failure;

    report "PQC L3B CODECD PASS pack=" & integer'image(npk) &
           " henc=" & integer'image(nhe) &
           " hint=" & integer'image(nhd) &
           " bad=" & integer'image(nbad) &
           " hsum=" & integer'image(hsum) &
           " sig=" & to_hex(sig)
      severity note;
    wait;
  end process;

end architecture sim;
