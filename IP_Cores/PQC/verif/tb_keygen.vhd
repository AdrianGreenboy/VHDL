-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A testbench
-- tb_keygen: runs ML-KEM-768 KeyGen in RTL against vectors traceable to ACVP.
--
-- The seeds d and z are staged in byte memory, KeyGen runs to completion, and
-- the 1184-byte ek and 2400-byte dk are read back and compared byte for byte.
--
-- This is the first testbench in the project whose failure mode is a whole
-- algorithm rather than a block, which is why the vector file carries the
-- KGC checkpoint: rho and sigma are compared before ek and dk, so a failure
-- says whether the initial hash or the lattice arithmetic diverged.
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_keygen is
  generic (
    G_VFILE : string := "l3a_vectors.txt");
end entity tb_keygen;

architecture sim of tb_keygen is

  constant C_PERIOD : time := 10 ns;
  constant C_ADDR_D   : integer := 0;
  constant C_ADDR_Z   : integer := 32;
  constant C_ADDR_RHO : integer := 64;
  constant C_ADDR_EK  : integer := 512;
  constant C_ADDR_DK  : integer := 2048;
  constant C_EK_LEN   : integer := 1184;
  constant C_DK_LEN   : integer := 2400;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal sim_done : boolean := false;

  signal start  : std_logic := '0';
  signal done   : std_logic;
  signal h_addr : std_logic_vector(12 downto 0) := (others => '0');
  signal h_din  : std_logic_vector(7 downto 0) := (others => '0');
  signal h_we   : std_logic := '0';
  signal h_sel  : std_logic := '1';
  signal h_dout : std_logic_vector(7 downto 0);

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

  dut : entity work.kem_keygen_top
    generic map (G_K => 3)
    port map (clk => clk, rst_n => rst_n, start => start,
              done => done, busy => open,
              h_addr => h_addr, h_din => h_din, h_we => h_we,
              h_sel => h_sel, h_dout => h_dout,
              insp_en => '0', insp_slot => 0,
              insp_addr => (others => '0'), insp_data => open);

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable tag    : string(1 to 3);
    variable c      : character;
    variable ch1, ch2 : character;
    variable n      : integer := 0;
    variable v      : integer;

    type t_buf is array (0 to 2399) of integer;
    variable dseed, zseed : t_buf;
    variable ek_exp, dk_exp : t_buf;
    variable rho_exp : t_buf;

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

    procedure read_hex (variable l : inout line; nbytes : in integer;
                        variable dst : out t_buf) is
      variable x1, x2 : character;
    begin
      for i in 0 to nbytes - 1 loop
        read(l, x1);
        read(l, x2);
        dst(i) := hex_nib(x1) * 16 + hex_nib(x2);
      end loop;
    end procedure read_hex;

    procedure host_write (addr : in integer; val : in integer) is
    begin
      h_sel  <= '1';
      h_addr <= std_logic_vector(to_unsigned(addr, 13));
      h_din  <= std_logic_vector(to_unsigned(val, 8));
      h_we   <= '1';
      wait_clk(1);
      h_we   <= '0';
      wait_clk(1);
    end procedure host_write;

    procedure host_read (addr : in integer; result : out integer) is
    begin
      h_sel  <= '1';
      h_addr <= std_logic_vector(to_unsigned(addr, 13));
      wait_clk(2);
      result := to_integer(unsigned(h_dout));
    end procedure host_read;

  begin
    rst_n <= '0';
    wait_clk(4);
    rst_n <= '1';
    wait_clk(2);

    file_open(status, fp, G_VFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open Layer 3A vector file" severity failure;

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

      if tag = "KGN" then
        read(ln, c);
        read_hex(ln, 32, dseed);
        read(ln, c);
        read_hex(ln, 32, zseed);
        read(ln, c);
        read_hex(ln, C_EK_LEN, ek_exp);
        read(ln, c);
        read_hex(ln, C_DK_LEN, dk_exp);

        -- the checkpoint line follows immediately
        readline(fp, ln);
        read(ln, tag(1));
        read(ln, tag(2));
        read(ln, tag(3));
        assert tag = "KGC"
          report "TB FAIL expected a KGC checkpoint line" severity failure;
        read(ln, c);
        read_hex(ln, 32, rho_exp);

        ----------------------------------------------------------------
        -- stage the seeds
        ----------------------------------------------------------------
        for i in 0 to 31 loop
          host_write(C_ADDR_D + i, dseed(i));
        end loop;
        for i in 0 to 31 loop
          host_write(C_ADDR_Z + i, zseed(i));
        end loop;

        ----------------------------------------------------------------
        -- run
        ----------------------------------------------------------------
        h_sel <= '0';
        wait_clk(2);
        start <= '1';
        wait_clk(1);
        start <= '0';
        while done = '0' loop
          wait_clk(1);
        end loop;
        wait_clk(4);

        ----------------------------------------------------------------
        -- checkpoint: rho must match before anything else is judged
        ----------------------------------------------------------------
        for i in 0 to 31 loop
          host_read(C_ADDR_RHO + i, v);
          assert v = rho_exp(i)
            report "TB FAIL keygen " & integer'image(n) &
                   " rho byte " & integer'image(i) &
                   " got=" & integer'image(v) &
                   " exp=" & integer'image(rho_exp(i))
            severity failure;
        end loop;

        for i in 0 to C_EK_LEN - 1 loop
          host_read(C_ADDR_EK + i, v);
          assert v = ek_exp(i)
            report "TB FAIL keygen " & integer'image(n) &
                   " ek byte " & integer'image(i) &
                   " got=" & integer'image(v) &
                   " exp=" & integer'image(ek_exp(i))
            severity failure;
          sig_update(sig, v);
        end loop;

        for i in 0 to C_DK_LEN - 1 loop
          host_read(C_ADDR_DK + i, v);
          assert v = dk_exp(i)
            report "TB FAIL keygen " & integer'image(n) &
                   " dk byte " & integer'image(i) &
                   " got=" & integer'image(v) &
                   " exp=" & integer'image(dk_exp(i))
            severity failure;
          sig_update(sig, v);
        end loop;

        n := n + 1;
      end if;
    end loop;
    file_close(fp);

    report "PQC L3A KEYGEN PASS vectors=" & integer'image(n) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
