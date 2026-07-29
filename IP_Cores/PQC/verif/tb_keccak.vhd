-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1 testbench
-- tb_keccak: validates keccak_f1600 (permutation vectors) and keccak_sponge
-- (SHAKE128/256, SHA3-256/512, including incremental squeeze).
-- VHDL-2008. ASCII-only asserts. MIT license.
--
-- PASS criterion: every vector matches AND the end-of-simulation signature is
-- bit-identical. The signature is a data-dependent 64-bit FNV-1a running hash
-- over every produced output byte, in order. It never depends on cycle counts.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library work;
use work.keccak_pkg.all;

entity tb_keccak is
  generic (
    G_PERM_FILE   : string := "keccak_vectors.txt";
    G_SPONGE_FILE : string := "sponge_vectors.txt");
end entity tb_keccak;

architecture sim of tb_keccak is

  constant C_PERIOD : time := 10 ns;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';

  -- permutation DUT
  signal p_start : std_logic := '0';
  signal p_in    : t_state := (others => (others => '0'));
  signal p_out   : t_state;
  signal p_busy  : std_logic;
  signal p_done  : std_logic;

  -- sponge DUT
  signal s_mode   : std_logic_vector(1 downto 0) := "00";
  signal s_init   : std_logic := '0';
  signal s_din    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_we     : std_logic := '0';
  signal s_adone  : std_logic := '0';
  signal s_dout   : std_logic_vector(7 downto 0);
  signal s_re     : std_logic := '0';
  signal s_dvalid : std_logic;
  signal s_ready  : std_logic;

  signal sim_done : boolean := false;

  -- FNV-1a 64-bit running signature over all produced bytes.
  -- Held in a process variable: signal updates would not be visible until the
  -- next wait, which would silently drop every byte hashed in the same delta.
  procedure sig_update (variable s : inout unsigned(63 downto 0);
                        b : in std_logic_vector(7 downto 0)) is
    variable v : unsigned(63 downto 0);
  begin
    v := s xor resize(unsigned(b), 64);
    -- multiply by FNV prime 0x100000001B3 using shifts and adds
    v := v + shift_left(v, 1) + shift_left(v, 4) + shift_left(v, 5) +
         shift_left(v, 7) + shift_left(v, 8) + shift_left(v, 40);
    s := v;
  end procedure sig_update;

  function hex_to_slv (s : string) return std_logic_vector is
    variable r : std_logic_vector(4 * s'length - 1 downto 0);
    variable n : integer;
  begin
    for i in 0 to s'length - 1 loop
      case s(s'low + i) is
        when '0' => n := 0;  when '1' => n := 1;  when '2' => n := 2;
        when '3' => n := 3;  when '4' => n := 4;  when '5' => n := 5;
        when '6' => n := 6;  when '7' => n := 7;  when '8' => n := 8;
        when '9' => n := 9;
        when 'A' | 'a' => n := 10;  when 'B' | 'b' => n := 11;
        when 'C' | 'c' => n := 12;  when 'D' | 'd' => n := 13;
        when 'E' | 'e' => n := 14;  when others => n := 15;
      end case;
      r(4 * (s'length - i) - 1 downto 4 * (s'length - i - 1)) :=
        std_logic_vector(to_unsigned(n, 4));
    end loop;
    return r;
  end function hex_to_slv;

  function to_hex (v : unsigned(63 downto 0)) return string is
    constant D : string(1 to 16) := "0123456789abcdef";
    variable r : string(1 to 16);
  begin
    for i in 0 to 15 loop
      r(16 - i) := D(to_integer(v(4 * i + 3 downto 4 * i)) + 1);
    end loop;
    return r;
  end function to_hex;

begin

  clk <= not clk after C_PERIOD / 2 when not sim_done else '0';

  u_perm : entity work.keccak_f1600
    port map (clk => clk, rst_n => rst_n, start => p_start,
              state_in => p_in, state_out => p_out,
              busy => p_busy, done => p_done);

  u_sponge : entity work.keccak_sponge
    port map (clk => clk, rst_n => rst_n, mode => s_mode, init => s_init,
              din => s_din, din_we => s_we, absorb_done => s_adone,
              dout => s_dout, dout_re => s_re, dout_valid => s_dvalid,
              ready => s_ready);

  main : process
    file fp        : text;
    variable ln    : line;
    variable status: file_open_status;
    variable nperm : integer := 0;
    variable nspg  : integer := 0;
    variable c     : character;
    variable good  : boolean;
    variable sig   : unsigned(63 downto 0) := x"CBF29CE484222325";

    -- permutation vector buffers
    variable vin   : t_state;
    variable vexp  : t_state;
    variable hexs  : string(1 to 400);

    -- sponge vector fields
    variable smode_i : integer;
    variable vmlen : integer;
    variable volen : integer;
    variable mbyte : std_logic_vector(7 downto 0);
    variable ebyte : std_logic_vector(7 downto 0);
    variable ch1, ch2 : character;

    procedure wait_clk (n : integer := 1) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure wait_clk;

    -- read one hex char pair from line into a byte
    procedure read_hex_byte (variable l : inout line;
                             variable b : out std_logic_vector(7 downto 0)) is
      variable a, c2 : character;
      variable s2    : string(1 to 2);
    begin
      read(l, a);
      read(l, c2);
      s2 := a & c2;
      b  := hex_to_slv(s2);
    end procedure read_hex_byte;

  begin
    rst_n <= '0';
    wait_clk(4);
    rst_n <= '1';
    wait_clk(2);

    ----------------------------------------------------------------------
    -- Part 1: raw Keccak-f[1600] permutation vectors
    ----------------------------------------------------------------------
    file_open(status, fp, G_PERM_FILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open permutation vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length > 0 then
        if ln(ln'low) = '#' then
          next;
        end if;
      else
        next;
      end if;

      -- input state: 25 lanes x 16 hex chars, big-endian text per lane
      for i in 0 to 24 loop
        hexs(1 to 16) := (others => '0');
        for j in 1 to 16 loop
          read(ln, c);
          hexs(j) := c;
        end loop;
        vin(i) := hex_to_slv(hexs(1 to 16));
      end loop;

      readline(fp, ln);
      for i in 0 to 24 loop
        hexs(1 to 16) := (others => '0');
        for j in 1 to 16 loop
          read(ln, c);
          hexs(j) := c;
        end loop;
        vexp(i) := hex_to_slv(hexs(1 to 16));
      end loop;

      -- run the permutation
      p_in    <= vin;
      p_start <= '1';
      wait_clk(1);
      p_start <= '0';
      while p_done = '0' loop
        wait_clk(1);
      end loop;

      for i in 0 to 24 loop
        assert p_out(i) = vexp(i)
          report "TB FAIL permutation vector " & integer'image(nperm) &
                 " lane " & integer'image(i)
          severity failure;
        for b in 0 to 7 loop
          sig_update(sig, p_out(i)(8 * b + 7 downto 8 * b));
        end loop;
      end loop;
      nperm := nperm + 1;
      wait_clk(1);
    end loop;
    file_close(fp);

    ----------------------------------------------------------------------
    -- Part 2: sponge vectors (all four modes, incremental squeeze)
    ----------------------------------------------------------------------
    file_open(status, fp, G_SPONGE_FILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open sponge vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      read(ln, smode_i);
      read(ln, vmlen);
      read(ln, volen);

      s_mode <= std_logic_vector(to_unsigned(smode_i, 2));
      -- init is only accepted while the permutation core is idle, so hold it
      -- until the sponge acknowledges by raising ready
      s_init <= '1';
      wait_clk(1);
      while s_ready = '0' loop
        wait_clk(1);
      end loop;
      s_init <= '0';
      wait_clk(1);

      -- skip separator space then read message hex ("-" means empty)
      read(ln, c);  -- space
      if vmlen = 0 then
        read(ln, c);  -- the '-' placeholder
      else
        for i in 1 to vmlen loop
          read(ln, ch1);
          read(ln, ch2);
          mbyte := hex_to_slv(ch1 & ch2);
          while s_ready = '0' loop
            wait_clk(1);
          end loop;
          s_din <= mbyte;
          s_we  <= '1';
          wait_clk(1);
          s_we  <= '0';
          -- settling cycle: ready falls on the same edge that consumes the
          -- byte closing a rate block, so it must not be sampled in that delta
          wait_clk(1);
        end loop;
      end if;

      while s_ready = '0' loop
        wait_clk(1);
      end loop;
      s_adone <= '1';
      wait_clk(1);
      s_adone <= '0';

      -- squeeze and compare
      read(ln, c);  -- space
      for i in 1 to volen loop
        while s_dvalid = '0' loop
          wait_clk(1);
        end loop;
        read(ln, ch1);
        read(ln, ch2);
        ebyte := hex_to_slv(ch1 & ch2);
        assert s_dout = ebyte
          report "TB FAIL sponge vector " & integer'image(nspg) &
                 " mode " & integer'image(smode_i) &
                 " byte " & integer'image(i - 1)
          severity failure;
        sig_update(sig, s_dout);
        s_re <= '1';
        wait_clk(1);
        s_re <= '0';
        -- one settling cycle: dout is registered on the same edge that
        -- consumes dout_re, so it must not be sampled in that delta
        wait_clk(1);
      end loop;

      nspg := nspg + 1;
    end loop;
    file_close(fp);

    report "PQC L1 KECCAK PASS perm=" & integer'image(nperm) &
           " sponge=" & integer'image(nspg) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
