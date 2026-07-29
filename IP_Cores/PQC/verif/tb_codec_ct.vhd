-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- tb_codec_ct: verifies the ciphertext compression codec standalone, before
-- it is wired into the Encaps sequencer.
--
-- Encode: a polynomial of canonical residues in, compressed bytes out, both
-- widths. Decode: compressed bytes in, decompressed coefficients out.
--
-- Verifying this here rather than inside Encaps keeps a packing error from
-- presenting as "the ciphertext is wrong" after the whole datapath has run.
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.ntt_tables_pkg.all;

entity tb_codec_ct is
  generic (
    G_VFILE : string := "codec_ct_vectors.txt");
end entity tb_codec_ct;

architecture sim of tb_codec_ct is

  constant C_PERIOD : time := 10 ns;
  constant C_BASE   : integer := 64;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal sim_done : boolean := false;

  signal start  : std_logic := '0';
  signal decode : std_logic := '0';
  signal dsel   : std_logic_vector(1 downto 0) := "00";
  signal base   : std_logic_vector(12 downto 0) :=
                    std_logic_vector(to_unsigned(C_BASE, 13));
  signal busy   : std_logic;
  signal done   : std_logic;

  signal cp_raddr : std_logic_vector(7 downto 0);
  signal cp_rdata : std_logic_vector(15 downto 0) := (others => '0');
  signal cp_waddr : std_logic_vector(7 downto 0);
  signal cp_wdata : std_logic_vector(15 downto 0);
  signal cp_we    : std_logic;

  signal cb_addr  : std_logic_vector(12 downto 0);
  signal cb_rdata : std_logic_vector(7 downto 0) := (others => '0');
  signal cb_wdata : std_logic_vector(7 downto 0);
  signal cb_we    : std_logic;

  -- simple behavioural memories owned by the testbench
  type t_poly_mem is array (0 to 255) of integer;
  type t_byte_mem is array (0 to 1023) of integer range 0 to 255;
  signal pmem : t_poly_mem := (others => 0);
  signal bmem : t_byte_mem := (others => 0);

  signal ld_pen   : std_logic := '0';
  signal ld_paddr : integer range 0 to 255 := 0;
  signal ld_pval  : integer := 0;
  signal ld_ben   : std_logic := '0';
  signal ld_baddr : integer range 0 to 1023 := 0;
  signal ld_bval  : integer range 0 to 255 := 0;

  signal rb_paddr : integer range 0 to 255 := 0;
  signal rb_pval  : integer := 0;
  signal rb_baddr : integer range 0 to 1023 := 0;
  signal rb_bval  : integer range 0 to 255 := 0;

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
      when '9' => return 9;
      when 'a' | 'A' => return 10;   when 'b' | 'B' => return 11;
      when 'c' | 'C' => return 12;   when 'd' | 'D' => return 13;
      when 'e' | 'E' => return 14;   when others => return 15;
    end case;
  end function hex_nib;

begin

  clk <= not clk after C_PERIOD / 2 when not sim_done else '0';

  dut : entity work.codec_ct
    port map (clk => clk, rst_n => rst_n, start => start,
              decode => decode, dsel => dsel, base => base,
              p_raddr => cp_raddr, p_rdata => cp_rdata,
              p_waddr => cp_waddr, p_wdata => cp_wdata, p_we => cp_we,
              b_addr => cb_addr, b_rdata => cb_rdata,
              b_wdata => cb_wdata, b_we => cb_we,
              busy => busy, done => done);

  pmem_proc : process (clk)
  begin
    if rising_edge(clk) then
      if ld_pen = '1' then
        pmem(ld_paddr) <= ld_pval;
      elsif cp_we = '1' then
        pmem(to_integer(unsigned(cp_waddr))) <= to_integer(signed(cp_wdata));
      end if;
      cp_rdata <= std_logic_vector(
                    to_signed(pmem(to_integer(unsigned(cp_raddr))), 16));
      rb_pval <= pmem(rb_paddr);
    end if;
  end process;

  bmem_proc : process (clk)
  begin
    if rising_edge(clk) then
      if ld_ben = '1' then
        bmem(ld_baddr) <= ld_bval;
      elsif cb_we = '1' then
        bmem(to_integer(unsigned(cb_addr))) <= to_integer(unsigned(cb_wdata));
      end if;
      cb_rdata <= std_logic_vector(
                    to_unsigned(bmem(to_integer(unsigned(cb_addr))), 8));
      rb_bval <= bmem(rb_baddr);
    end if;
  end process;

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable tag    : string(1 to 3);
    variable c      : character;
    variable ch1, ch2 : character;
    variable d      : integer;
    variable v      : integer;
    variable nenc   : integer := 0;
    variable ndec   : integer := 0;

    type t_arr is array (0 to 319) of integer;
    variable poly : t_arr;
    variable byts : t_arr;

    procedure wait_clk (k : integer := 1) is
    begin
      for i in 1 to k loop
        wait until rising_edge(clk);
      end loop;
    end procedure wait_clk;

    procedure sig_update (variable s : inout unsigned(63 downto 0);
                          x : in integer) is
      variable u : unsigned(63 downto 0);
      variable w : unsigned(31 downto 0);
    begin
      w := to_unsigned(x, 32);
      for i in 0 to 3 loop
        u := s xor resize(w(8 * i + 7 downto 8 * i), 64);
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

    file_open(status, fp, G_VFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open codec_ct vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;
      read(ln, tag(1));
      read(ln, tag(2));
      read(ln, tag(3));
      read(ln, c);
      read(ln, d);

      if tag = "CTE" then
        ----------------------------------------------------------------
        -- encode: load the polynomial, run, compare the bytes
        ----------------------------------------------------------------
        for i in 0 to 255 loop
          read(ln, poly(i));
        end loop;
        read(ln, c);

        for i in 0 to 255 loop
          ld_paddr <= i;
          ld_pval  <= poly(i);
          wait_clk(1);
          ld_pen   <= '1';
          wait_clk(1);
          ld_pen   <= '0';
        end loop;
        wait_clk(1);

        decode <= '0';
        if d = 10 then
          dsel <= "00";
        elsif d = 4 then
          dsel <= "01";
        else
          dsel <= "10";
        end if;
        wait_clk(1);
        start <= '1';
        wait_clk(1);
        start <= '0';
        while done = '0' loop
          wait_clk(1);
        end loop;
        wait_clk(2);

        for i in 0 to (32 * d) - 1 loop
          read(ln, ch1);
          read(ln, ch2);
          v := hex_nib(ch1) * 16 + hex_nib(ch2);
          rb_baddr <= C_BASE + i;
          wait_clk(2);
          assert rb_bval = v
            report "TB FAIL codec_ct encode d=" & integer'image(d) &
                   " byte " & integer'image(i) &
                   " got=" & integer'image(rb_bval) &
                   " exp=" & integer'image(v)
            severity failure;
          sig_update(sig, rb_bval);
        end loop;
        nenc := nenc + 1;

      elsif tag = "CTD" then
        ----------------------------------------------------------------
        -- decode: load the bytes, run, compare the coefficients
        ----------------------------------------------------------------
        read(ln, c);   -- consume the space left by the integer read
        for i in 0 to (32 * d) - 1 loop
          read(ln, ch1);
          read(ln, ch2);
          byts(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
        end loop;
        read(ln, c);

        for i in 0 to (32 * d) - 1 loop
          ld_baddr <= C_BASE + i;
          ld_bval  <= byts(i);
          wait_clk(1);
          ld_ben   <= '1';
          wait_clk(1);
          ld_ben   <= '0';
        end loop;
        -- clear the polynomial so a stale value cannot pass the comparison
        for i in 0 to 255 loop
          ld_paddr <= i;
          ld_pval  <= 0;
          wait_clk(1);
          ld_pen   <= '1';
          wait_clk(1);
          ld_pen   <= '0';
        end loop;
        wait_clk(1);

        decode <= '1';
        if d = 10 then
          dsel <= "00";
        elsif d = 4 then
          dsel <= "01";
        else
          dsel <= "10";
        end if;
        wait_clk(1);
        start <= '1';
        wait_clk(1);
        start <= '0';
        while done = '0' loop
          wait_clk(1);
        end loop;
        wait_clk(2);

        for i in 0 to 255 loop
          read(ln, v);
          rb_paddr <= i;
          wait_clk(2);
          assert rb_pval = v
            report "TB FAIL codec_ct decode d=" & integer'image(d) &
                   " coef " & integer'image(i) &
                   " got=" & integer'image(rb_pval) &
                   " exp=" & integer'image(v)
            severity failure;
          sig_update(sig, rb_pval);
        end loop;
        ndec := ndec + 1;
      end if;
    end loop;
    file_close(fp);

    report "PQC L3A CODECCT PASS enc=" & integer'image(nenc) &
           " dec=" & integer'image(ndec) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
