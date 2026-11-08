-- =============================================================================
-- HERCOSSNUX PQC IP Core - audit 2026-11
-- tb_host_guard: self-checking test of the host/command hardening on
-- pqc_core, and of the removal of the Decaps rejection oracle.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Runs with G_ZEROIZE = false so that intermediates stay in memory and the
-- read windows are tested on their own (G_ZEROIZE = true is covered by
-- tb_zeroize).
--  1. While a KEM KeyGen runs, the host: writes into the ek/dk output area,
--     reads (must see 0x00), changes kem_op, changes alg, re-pulses
--     kem_start and pulses dsa_start. ek and dk must still be KAT-exact,
--     err(1) (command rejected) must be set, err(0) (sponge) clear.
--  2. A start with op = "11" is rejected: no busy, err(1).
--  3. Decaps with the valid ciphertext and with a ciphertext that has one
--     flipped bit (implicit rejection, Kbar from the Python oracle):
--       * Kout is KAT-exact in both cases,
--       * start-to-done latency is identical,
--       * every host-readable byte of the 8 KB space is identical except
--         the input c and the output Kout: nothing host-visible tells the
--         two paths apart (no plaintext-checking oracle).
--  4. Bytes that hold secrets/intermediates (m2..Kbar, c2, sigma; ML-DSA
--     rho'/K) read as 0x00 through the host port while the memory holds
--     non-zero data (checked through external names).
-- Expected final line:  PQC HOSTGUARD PASS ...
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.byte_mem_pkg.all;
use work.byte_mem_d_pkg.all;

entity tb_host_guard is
end entity tb_host_guard;

architecture sim of tb_host_guard is

  function hex_nib (c : character) return integer is
  begin
    case c is
      when '0' => return 0;   when '1' => return 1;   when '2' => return 2;
      when '3' => return 3;   when '4' => return 4;   when '5' => return 5;
      when '6' => return 6;   when '7' => return 7;   when '8' => return 8;
      when '9' => return 9;   when 'a' | 'A' => return 10;
      when 'b' | 'B' => return 11;  when 'c' | 'C' => return 12;
      when 'd' | 'D' => return 13;  when 'e' | 'E' => return 14;
      when others => return 15;
    end case;
  end function hex_nib;

  constant C_EK  : integer := 1184;
  constant C_DK  : integer := 2400;
  constant C_CT  : integer := 1088;
  constant C_PK  : integer := 1952;
  constant C_SK  : integer := 4032;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal alg    : std_logic := '0';

  signal kem_op    : std_logic_vector(1 downto 0) := "00";
  signal kem_start : std_logic := '0';
  signal kem_done, kem_busy : std_logic;
  signal kem_haddr : std_logic_vector(12 downto 0) := (others => '0');
  signal kem_hdin  : std_logic_vector(7 downto 0) := (others => '0');
  signal kem_hwe   : std_logic := '0';
  signal kem_hsel  : std_logic := '1';
  signal kem_hdout : std_logic_vector(7 downto 0);

  signal dsa_op    : std_logic_vector(1 downto 0) := "00";
  signal dsa_start : std_logic := '0';
  signal dsa_siglen : std_logic_vector(15 downto 0) := (others => '0');
  signal dsa_done, dsa_busy, dsa_result : std_logic;
  signal dsa_reason : std_logic_vector(2 downto 0);
  signal dsa_haddr : std_logic_vector(13 downto 0) := (others => '0');
  signal dsa_hdin  : std_logic_vector(7 downto 0) := (others => '0');
  signal dsa_hwe   : std_logic := '0';
  signal dsa_hsel  : std_logic := '1';
  signal dsa_hdout : std_logic_vector(7 downto 0);

  signal zbusy, zdone : std_logic;
  signal err     : std_logic_vector(3 downto 0);
  signal err_clr : std_logic := '0';

begin

  clk <= not clk after 5 ns;

  dut : entity work.pqc_core
    generic map (G_ZEROIZE => false)
    port map (clk => clk, rst_n => rst_n, alg => alg,
              kem_op => kem_op, kem_start => kem_start, kem_done => kem_done,
              kem_busy => kem_busy,
              kem_haddr => kem_haddr, kem_hdin => kem_hdin, kem_hwe => kem_hwe,
              kem_hsel => kem_hsel, kem_hdout => kem_hdout,
              dsa_op => dsa_op, dsa_start => dsa_start,
              dsa_siglen => dsa_siglen, dsa_done => dsa_done,
              dsa_busy => dsa_busy, dsa_result => dsa_result,
              dsa_reason => dsa_reason,
              dsa_haddr => dsa_haddr, dsa_hdin => dsa_hdin, dsa_hwe => dsa_hwe,
              dsa_hsel => dsa_hsel, dsa_hdout => dsa_hdout,
              zeroize => '0', zbusy => zbusy, zdone => zdone,
              err => err, err_clr => err_clr);

  process
    alias kbm is <<signal .tb_host_guard.dut.u_kem.u_bytes.mem : t_bm_arr>>;
    alias dbm is <<signal .tb_host_guard.dut.u_dsa.u_bmem.mem : t_bmd_arr>>;

    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 2);
    variable c   : character;
    variable ch1, ch2 : character;
    variable v, w : integer;
    type t_buf is array (0 to 4095) of integer;
    type t_view is array (0 to 8191) of integer;
    variable d_b, z_b, m_b, ek_b, dk_b, ct_b, ss_b, cb_b, kb_b : t_buf;
    variable xi_b : t_buf;
    variable view_ok, view_bad : t_view;
    variable cyc_ok, cyc_bad, ncyc : integer;
    variable nchk : integer := 0;
    variable nz : integer;

    procedure wait_clk (k : integer) is
    begin
      for i in 1 to k loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    impure function kbyte (a : integer) return integer is
    begin
      return to_integer(unsigned(
               kbm(a / 8)(8 * (a mod 8) + 7 downto 8 * (a mod 8))));
    end function;
    impure function dbyte (a : integer) return integer is
    begin
      return to_integer(unsigned(
               dbm(a / 8)(8 * (a mod 8) + 7 downto 8 * (a mod 8))));
    end function;

    procedure kwrite (constant a : in integer; constant d : in integer) is
    begin
      kem_hsel <= '1';
      kem_haddr <= std_logic_vector(to_unsigned(a, 13));
      kem_hdin  <= std_logic_vector(to_unsigned(d, 8));
      kem_hwe   <= '1';
      wait_clk(1);
      kem_hwe   <= '0';
      wait_clk(1);
    end procedure;

    procedure kread (constant a : in integer; variable d : out integer) is
    begin
      kem_hsel <= '1';
      kem_haddr <= std_logic_vector(to_unsigned(a, 13));
      wait_clk(2);
      d := to_integer(unsigned(kem_hdout));
    end procedure;

    procedure dwrite (constant a : in integer; constant d : in integer) is
    begin
      dsa_hsel <= '1';
      dsa_haddr <= std_logic_vector(to_unsigned(a, 14));
      dsa_hdin  <= std_logic_vector(to_unsigned(d, 8));
      dsa_hwe   <= '1';
      wait_clk(1);
      dsa_hwe   <= '0';
      wait_clk(1);
    end procedure;

    procedure dread (constant a : in integer; variable d : out integer) is
    begin
      dsa_hsel <= '1';
      dsa_haddr <= std_logic_vector(to_unsigned(a, 14));
      wait_clk(2);
      d := to_integer(unsigned(dsa_hdout));
    end procedure;

    -- start an op and return the start-to-done latency
    procedure krun (constant o : in std_logic_vector(1 downto 0);
                    variable n : out integer) is
      variable k : integer := 1;
    begin
      kem_op   <= o;
      kem_hsel <= '0';
      wait_clk(2);
      kem_start <= '1';
      wait_clk(1);
      kem_start <= '0';
      while kem_done = '0' loop
        wait_clk(1);
        k := k + 1;
      end loop;
      n := k;
      wait_clk(4);
      kem_hsel <= '1';
      wait_clk(2);
    end procedure;

    procedure rdhex (variable buf : out t_buf; constant n : in integer;
                     variable ln : inout line) is
    begin
      read(ln, c);
      for i in 0 to n - 1 loop
        read(ln, ch1); read(ln, ch2);
        buf(i) := hex_nib(ch1) * 16 + hex_nib(ch2);
      end loop;
    end procedure;

    procedure clear_err is
    begin
      err_clr <= '1';
      wait_clk(1);
      err_clr <= '0';
      wait_clk(1);
      assert err = "0000" report "TB FAIL err_clr did not clear err"
        severity failure;
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
    rdhex(d_b, 32, ln);  rdhex(z_b, 32, ln);  rdhex(m_b, 32, ln);
    rdhex(ek_b, C_EK, ln); rdhex(dk_b, C_DK, ln);
    rdhex(ct_b, C_CT, ln); rdhex(ss_b, 32, ln);
    file_close(fh);
    file_open(fh, "kem_rej_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      next when ln'length < 3;
      read(ln, tag);
      exit when tag = "RJ";
    end loop;
    rdhex(cb_b, C_CT, ln); rdhex(kb_b, 32, ln);
    file_close(fh);

    ------------------------------------------------------------------
    -- 1. KeyGen under host interference
    ------------------------------------------------------------------
    alg <= '0';
    for i in 0 to 31 loop
      kwrite(i, d_b(i));
      kwrite(32 + i, z_b(i));
    end loop;
    kem_op   <= "00";
    kem_hsel <= '0';
    wait_clk(2);
    kem_start <= '1';
    wait_clk(1);
    kem_start <= '0';
    wait_clk(200);
    assert kem_busy = '1' report "TB FAIL KeyGen not busy" severity failure;
    -- host writes into the output areas and the seed while busy
    for i in 0 to 63 loop
      kwrite(512 + 17 * i, 16#A5#);
      kwrite(2048 + 31 * i, 16#5A#);
      kwrite(i, 16#FF#);
    end loop;
    -- host reads while busy must not return memory contents
    for i in 0 to 31 loop
      kread(i, v);
      assert v = 0 report "TB FAIL host read returned data while busy"
        severity failure;
    end loop;
    kem_hsel <= '0';
    -- change op and alg, re-pulse starts
    kem_op <= "10";
    alg    <= '1';
    wait_clk(500);
    kem_start <= '1';
    dsa_start <= '1';
    wait_clk(1);
    kem_start <= '0';
    dsa_start <= '0';
    wait_clk(500);
    alg <= '0';
    wait_clk(500);
    alg <= '1';
    while kem_done = '0' loop
      wait_clk(1);
    end loop;
    alg <= '0';
    wait_clk(4);
    kem_hsel <= '1';
    wait_clk(2);
    for i in 0 to C_EK - 1 loop
      kread(512 + i, v);
      assert v = ek_b(i) report "TB FAIL ek corrupted by host interference "
        & integer'image(i) severity failure;
    end loop;
    for i in 0 to C_DK - 1 loop
      kread(2048 + i, v);
      assert v = dk_b(i) report "TB FAIL dk corrupted by host interference "
        & integer'image(i) severity failure;
    end loop;
    assert err(1) = '1'
      report "TB FAIL rejected starts not flagged" severity failure;
    assert err(0) = '0'
      report "TB FAIL sponge protocol error" severity failure;
    nchk := nchk + 1;
    clear_err;

    -- secret scratch (sigma at 96..127) is in memory but not host-readable
    nz := 0;
    for i in 96 to 127 loop
      if kbyte(i) /= 0 then nz := nz + 1; end if;
      kread(i, v);
      assert v = 0 report "TB FAIL sigma readable by the host" severity failure;
    end loop;
    assert nz > 0 report "TB FAIL sigma not in memory (test vacuous)"
      severity failure;
    nchk := nchk + 1;

    ------------------------------------------------------------------
    -- 2. illegal op
    ------------------------------------------------------------------
    kem_op   <= "11";
    kem_hsel <= '0';
    wait_clk(2);
    kem_start <= '1';
    wait_clk(1);
    kem_start <= '0';
    wait_clk(3);
    assert kem_busy = '0' report "TB FAIL op 11 started something"
      severity failure;
    assert err(1) = '1' report "TB FAIL op 11 not flagged" severity failure;
    nchk := nchk + 1;
    clear_err;
    kem_hsel <= '1';

    ------------------------------------------------------------------
    -- 3. Decaps: valid versus implicit rejection
    ------------------------------------------------------------------
    for pass in 0 to 1 loop
      for i in 0 to C_CT - 1 loop
        if pass = 0 then kwrite(i, ct_b(i)); else kwrite(i, cb_b(i)); end if;
      end loop;
      for i in 0 to C_DK - 1 loop
        kwrite(2048 + i, dk_b(i));
      end loop;
      krun("10", ncyc);
      for i in 0 to 31 loop
        kread(1280 + i, v);
        if pass = 0 then
          assert v = ss_b(i) report "TB FAIL valid Kout " & integer'image(i)
            severity failure;
        else
          assert v = kb_b(i) report "TB FAIL rejected Kout (Kbar) " &
                                    integer'image(i) severity failure;
        end if;
      end loop;
      -- host view of the whole byte space
      for a in 0 to 8191 loop
        kread(a, v);
        if pass = 0 then view_ok(a) := v; else view_bad(a) := v; end if;
      end loop;
      if pass = 0 then
        cyc_ok := ncyc;
        -- intermediates are in memory but masked from the host
        nz := 0;
        for i in 1152 to 1279 loop
          if kbyte(i) /= 0 then nz := nz + 1; end if;
          assert view_ok(i) = 0
            report "TB FAIL Decaps intermediate readable at " &
                   integer'image(i) severity failure;
        end loop;
        assert nz > 0 report "TB FAIL m2/K2 not in memory (test vacuous)"
          severity failure;
      else
        cyc_bad := ncyc;
      end if;
      assert err = "0000" report "TB FAIL err set by Decaps" severity failure;
    end loop;
    assert cyc_ok = cyc_bad
      report "TB FAIL Decaps latency depends on rejection: " &
             integer'image(cyc_ok) & " vs " & integer'image(cyc_bad)
      severity failure;
    for a in 0 to 8191 loop
      if not ((a < C_CT) or (a >= 1280 and a < 1312)) then
        assert view_ok(a) = view_bad(a)
          report "TB FAIL host-visible byte " & integer'image(a) &
                 " differs between accept and reject" severity failure;
      end if;
    end loop;
    nchk := nchk + 3;
    report "PQC HOSTGUARD Decaps accept/reject indistinguishable, cycles=" &
           integer'image(cyc_ok) severity note;

    ------------------------------------------------------------------
    -- 4. ML-DSA KeyGen: secret seed area masked from the host
    ------------------------------------------------------------------
    alg <= '1';
    wait_clk(2);
    file_open(fh, "dsa_st_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      next when ln'length < 3;
      read(ln, tag);
      exit when tag = "ST";
    end loop;
    rdhex(xi_b, 32, ln);
    file_close(fh);
    for i in 0 to 31 loop
      dwrite(i, xi_b(i));
    end loop;
    dsa_op   <= "00";
    dsa_hsel <= '0';
    wait_clk(2);
    dsa_start <= '1';
    wait_clk(1);
    dsa_start <= '0';
    wait_clk(1000);
    -- KEM start and DSA re-start while the DSA core is busy
    kem_start <= '1';
    dsa_start <= '1';
    dsa_op    <= "01";
    wait_clk(1);
    kem_start <= '0';
    dsa_start <= '0';
    for i in 0 to 15 loop
      dwrite(256 + 100 * i, 16#C3#);
    end loop;
    dsa_hsel <= '0';
    while dsa_done = '0' loop
      wait_clk(1);
    end loop;
    wait_clk(4);
    dsa_hsel <= '1';
    wait_clk(2);
    assert err(1) = '1' report "TB FAIL DSA busy starts not flagged"
      severity failure;
    clear_err;
    -- rho' and K (seed bytes 96..191) must not be host-readable
    nz := 0;
    for i in 64 to 191 loop
      if dbyte(i) /= 0 then nz := nz + 1; end if;
      dread(i, v);
      assert v = 0 report "TB FAIL DSA seed readable at " & integer'image(i)
        severity failure;
    end loop;
    assert nz > 0 report "TB FAIL DSA seed not in memory (test vacuous)"
      severity failure;
    -- pk must be unaffected by the host writes issued while busy: compare
    -- against the vector file
    file_open(fh, "dsa_st_vectors.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln);
      next when ln'length < 3;
      read(ln, tag);
      exit when tag = "ST";
    end loop;
    rdhex(xi_b, 32, ln);  rdhex(xi_b, 64, ln);   -- skip xi, mu
    rdhex(d_b, C_PK, ln);                         -- pk
    file_close(fh);
    for i in 0 to C_PK - 1 loop
      dread(256 + i, v);
      assert v = d_b(i) report "TB FAIL dsa pk corrupted " & integer'image(i)
        severity failure;
    end loop;
    nchk := nchk + 2;

    assert err = "0000" report "TB FAIL err at end: " & to_string(err)
      severity failure;
    report "PQC HOSTGUARD PASS checks=" & integer'image(nchk) severity note;
    std.env.finish;
    wait;
  end process;

end architecture sim;
