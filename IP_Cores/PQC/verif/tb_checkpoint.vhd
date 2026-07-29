-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 3A
-- tb_checkpoint: halts KeyGen after each pipeline stage and compares the
-- polynomial memory against the FSM model, which is itself ACVP-validated.
--
-- Five instances of the same top level are elaborated, each with a different
-- G_STOP_AT, so one simulation reports the first stage that diverges instead
-- of only the final byte stream. In execution order:
--
--   CP1 s[0] after SamplePolyCBD, before NTT   slot S+0
--   CP2 s_hat[0] after the forward NTT         slot S+0
--   CP3 s_hat[0] lifted by R^2                 slot Y+0
--   CP4 A[0][0] from SampleNTT                 slot A
--   CP5 accumulator after the K basemuls       slot TMP
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.poly_mem_pkg.all;
use work.ntt_tables_pkg.all;

entity tb_checkpoint is
  generic (
    G_VFILE : string := "l3a_vectors.txt";
    G_STAGE : integer := 1);
end entity tb_checkpoint;

architecture sim of tb_checkpoint is

  constant C_PERIOD : time := 10 ns;
  constant C_ADDR_D : integer := 0;
  constant C_ADDR_Z : integer := 32;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal sim_done : boolean := false;

  signal start  : std_logic := '0';
  signal done   : std_logic;
  signal h_addr : std_logic_vector(12 downto 0) := (others => '0');
  signal h_din  : std_logic_vector(7 downto 0) := (others => '0');
  signal h_we   : std_logic := '0';
  signal h_sel  : std_logic := '1';

  signal insp_en   : std_logic := '0';
  signal insp_slot : integer range 0 to C_SLOTS - 1 := 0;
  signal insp_addr : std_logic_vector(7 downto 0) := (others => '0');
  signal insp_data : std_logic_vector(15 downto 0);

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
    generic map (G_K => 3, G_STOP_AT => G_STAGE)
    port map (clk => clk, rst_n => rst_n, start => start,
              done => done, busy => open,
              h_addr => h_addr, h_din => h_din, h_we => h_we,
              h_sel => h_sel, h_dout => open,
              insp_en => insp_en, insp_slot => insp_slot,
              insp_addr => insp_addr, insp_data => insp_data);

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable tag    : string(1 to 3);
    variable c      : character;
    variable ch1, ch2 : character;
    variable v      : integer;
    variable nchk   : integer := 0;

    type t_poly is array (0 to 255) of integer;
    type t_cps  is array (1 to 5) of t_poly;
    variable cp : t_cps;
    variable have : integer := 0;

    type t_seed is array (0 to 31) of integer;
    variable dseed, zseed : t_seed;

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

    ------------------------------------------------------------------
    -- read the checkpoint vectors and the first KeyGen seeds
    ------------------------------------------------------------------
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

      if tag(1) = 'C' and tag(2) = 'P' then
        v := hex_nib(tag(3));
        for i in 0 to 255 loop
          read(ln, cp(v)(i));
        end loop;
        have := have + 1;
      elsif tag = "KGN" then
        read(ln, c);
        for i in 0 to 31 loop
          read(ln, ch1);
          read(ln, ch2);
          dseed(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
        end loop;
        read(ln, c);
        for i in 0 to 31 loop
          read(ln, ch1);
          read(ln, ch2);
          zseed(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
        end loop;
        exit;
      end if;
    end loop;
    file_close(fp);

    assert have = 5
      report "TB FAIL expected five checkpoint lines, found " &
             integer'image(have)
      severity failure;

    ------------------------------------------------------------------
    -- stage the seeds into every instance at once
    ------------------------------------------------------------------
    for i in 0 to 31 loop
      h_sel  <= '1';
      h_addr <= std_logic_vector(to_unsigned(C_ADDR_D + i, 13));
      h_din  <= std_logic_vector(to_unsigned(dseed(i), 8));
      h_we   <= '1';
      wait_clk(1);
      h_we   <= '0';
      wait_clk(1);
    end loop;
    for i in 0 to 31 loop
      h_addr <= std_logic_vector(to_unsigned(C_ADDR_Z + i, 13));
      h_din  <= std_logic_vector(to_unsigned(zseed(i), 8));
      h_we   <= '1';
      wait_clk(1);
      h_we   <= '0';
      wait_clk(1);
    end loop;

    h_sel <= '0';
    wait_clk(2);

    ------------------------------------------------------------------
    -- run all five instances, then inspect each at its stop point
    ------------------------------------------------------------------
    start <= '1';
    wait_clk(1);
    start <= '0';

    while done = '0' loop
      wait_clk(1);
    end loop;
    wait_clk(4);

    case G_STAGE is
      when 1 => insp_slot <= C_SLOT_S;        -- s[0] after CBD
      when 2 => insp_slot <= C_SLOT_S;        -- s_hat[0] after NTT
      when 3 => insp_slot <= C_SLOT_Y;        -- lifted s_hat[0]
      when 4 => insp_slot <= C_SLOT_A;        -- A[0][0]
      when others => insp_slot <= C_SLOT_TMP; -- accumulator
    end case;
    insp_en <= '1';
    wait_clk(2);

    for i in 0 to 255 loop
      insp_addr <= std_logic_vector(to_unsigned(i, 8));
      wait_clk(3);
      v := to_integer(signed(insp_data));
      if v < 0 then
        v := v + C_QK;
      end if;
      assert v = cp(G_STAGE)(i)
        report "TB FAIL checkpoint CP" & integer'image(G_STAGE) &
               " coef " & integer'image(i) &
               " got=" & integer'image(v) &
               " exp=" & integer'image(cp(G_STAGE)(i))
        severity failure;
      sig_update(sig, v);
    end loop;

    insp_en <= '0';
    nchk := 1;

    report "PQC L3A CHECKPOINT PASS stage=" & integer'image(G_STAGE) &
           " sig=" & to_hex(sig)
      severity note;

    sim_done <= true;
    wait;
  end process main;

end architecture sim;
