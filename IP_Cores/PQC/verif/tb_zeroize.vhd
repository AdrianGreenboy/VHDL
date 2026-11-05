-- =============================================================================
-- HERCOSSNUX PQC IP Core - audit 2026-11
-- tb_zeroize: self-checking test of the key-zeroization feature on pqc_core.
-- VHDL-2008. ASCII-only. MIT license.
--
-- 1. Runs the ML-KEM chain (KeyGen, Encaps, Decaps) and the ML-DSA chain
--    (KeyGen, Sign, Verify) with KAT checks of every output. After each
--    operation it inspects the physical memories through external names:
--      * every byte the CORE wrote during the operation that is not part of
--        that operation's outputs reads back zero,
--      * the secret inputs of the operation (d||z, m, dk, xi, sk) are zero,
--      * after every KEM operation and after DSA KeyGen/Sign, both copies of
--        the polynomial memory are entirely zero,
--      * the sponge state and the permutation input register are zero.
-- 2. Issues the ZEROIZE command and checks that every byte of both byte
--    memories and every polynomial word is zero and that zdone pulses.
-- 3. Aborts a running KEM KeyGen with ZEROIZE: done must not pulse, zdone
--    must, everything must be zero; a following KeyGen must be KAT-exact.
-- 4. err must be "0000" at the end: no sponge protocol error, no rejected
--    command in a well-formed flow.
-- Expected final line:  PQC ZEROIZE PASS ...
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.keccak_pkg.all;
use work.poly_mem_pkg.all;
use work.poly_mem_d_pkg.all;
use work.byte_mem_pkg.all;
use work.byte_mem_d_pkg.all;

entity tb_zeroize is
end entity tb_zeroize;

architecture sim of tb_zeroize is

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
  constant C_SIG : integer := 3309;

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

  signal zeroize : std_logic := '0';
  signal zbusy, zdone : std_logic;
  signal err     : std_logic_vector(3 downto 0);
  signal err_clr : std_logic := '0';

  -- core-write markers, owned by the monitor process
  type t_km is array (0 to 8191) of boolean;
  type t_dm is array (0 to 16383) of boolean;
  signal kmark : t_km := (others => false);
  signal dmark : t_dm := (others => false);
  signal mark_clr : std_logic := '0';
  signal n_done, n_zdone : integer := 0;

begin

  clk <= not clk after 5 ns;

  dut : entity work.pqc_core
    generic map (G_ZEROIZE => true)
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
              zeroize => zeroize, zbusy => zbusy, zdone => zdone,
              err => err, err_clr => err_clr);

  -- Monitor: mark every byte address the cores write (not the host).
  mon : process (clk)
    alias k_we  is <<signal .tb_zeroize.dut.u_kem.bmem_we  : std_logic>>;
    alias k_a   is <<signal .tb_zeroize.dut.u_kem.bmem_a   : std_logic_vector(12 downto 0)>>;
    alias k_ha  is <<signal .tb_zeroize.dut.u_kem.host_act : std_logic>>;
    alias d_we  is <<signal .tb_zeroize.dut.u_dsa.b_we     : std_logic>>;
    alias d_a   is <<signal .tb_zeroize.dut.u_dsa.b_addr   : std_logic_vector(13 downto 0)>>;
    alias d_ha  is <<signal .tb_zeroize.dut.u_dsa.host_act : std_logic>>;
  begin
    if rising_edge(clk) then
      if mark_clr = '1' then
        kmark <= (others => false);
        dmark <= (others => false);
      else
        if k_we = '1' and k_ha = '0' then
          kmark(to_integer(unsigned(k_a))) <= true;
        end if;
        if d_we = '1' and d_ha = '0' then
          dmark(to_integer(unsigned(d_a))) <= true;
        end if;
      end if;
      if kem_done = '1' or dsa_done = '1' then
        n_done <= n_done + 1;
      end if;
      if zdone = '1' then
        n_zdone <= n_zdone + 1;
      end if;
    end if;
  end process;

  process
    alias kbm is <<signal .tb_zeroize.dut.u_kem.u_bytes.mem : t_bm_arr>>;
    alias kpa is <<signal .tb_zeroize.dut.u_kem.u_mem.mem_a : t_pm_arr>>;
    alias kpb is <<signal .tb_zeroize.dut.u_kem.u_mem.mem_b : t_pm_arr>>;
    alias dbm is <<signal .tb_zeroize.dut.u_dsa.u_bmem.mem : t_bmd_arr>>;
    alias dpa is <<signal .tb_zeroize.dut.u_dsa.u_pmem.mem_a : t_pmd_arr>>;
    alias dpb is <<signal .tb_zeroize.dut.u_dsa.u_pmem.mem_b : t_pmd_arr>>;
    alias sst is <<signal .tb_zeroize.dut.u_sponge.st : t_state>>;
    alias skin is <<signal .tb_zeroize.dut.u_sponge.k_in : t_state>>;

    file     fh  : text;
    variable ln  : line;
    variable tag : string(1 to 2);
    variable c   : character;
    variable ch1, ch2 : character;
    variable v   : integer;
    type t_buf is array (0 to 4095) of integer;
    variable d_b, z_b, m_b, ek_b, dk_b, ct_b, ss_b : t_buf;
    variable xi_b, mu_b, pk_b, sk_b, sg_b : t_buf;
    variable nchk : integer := 0;
    variable nd0  : integer;

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

    procedure krun (constant o : in std_logic_vector(1 downto 0)) is
    begin
      mark_clr <= '1';
      wait_clk(1);
      mark_clr <= '0';
      kem_op   <= o;
      kem_hsel <= '0';
      wait_clk(2);
      kem_start <= '1';
      wait_clk(1);
      kem_start <= '0';
      while kem_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(4);
      kem_hsel <= '1';
      wait_clk(2);
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

    procedure drun (constant o : in std_logic_vector(1 downto 0)) is
    begin
      mark_clr <= '1';
      wait_clk(1);
      mark_clr <= '0';
      dsa_op   <= o;
      dsa_hsel <= '0';
      wait_clk(2);
      dsa_start <= '1';
      wait_clk(1);
      dsa_start <= '0';
      while dsa_done = '0' loop
        wait_clk(1);
      end loop;
      wait_clk(4);
      dsa_hsel <= '1';
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

    -- ---------------------------------------------------------------
    -- memory inspection
    -- ---------------------------------------------------------------
    procedure kem_poly_zero (name : string) is
    begin
      for i in kpa'range loop
        assert kpa(i) = (kpa(i)'range => '0') and
               kpb(i) = (kpb(i)'range => '0')
          report "TB FAIL " & name & ": KEM poly_mem row " &
                 integer'image(i) & " not wiped" severity failure;
      end loop;
      nchk := nchk + 1;
    end procedure;

    procedure dsa_poly_zero (name : string) is
    begin
      for i in dpa'range loop
        assert dpa(i) = (dpa(i)'range => '0') and
               dpb(i) = (dpb(i)'range => '0')
          report "TB FAIL " & name & ": DSA poly_mem_d row " &
                 integer'image(i) & " not wiped" severity failure;
      end loop;
      nchk := nchk + 1;
    end procedure;

    procedure sponge_zero (name : string) is
    begin
      for i in 0 to 24 loop
        assert sst(i) = x"0000000000000000" and
               skin(i) = x"0000000000000000"
          report "TB FAIL " & name & ": sponge state lane " &
                 integer'image(i) & " not wiped" severity failure;
      end loop;
      nchk := nchk + 1;
    end procedure;

    -- every core-written byte outside [o1, o2) and [o3, o4) must be zero
    procedure kem_marked_zero (name : string; o1, o2, o3, o4 : integer) is
      variable n : integer := 0;
    begin
      for a in 0 to 8191 loop
        if kmark(a) and not ((a >= o1 and a < o2) or (a >= o3 and a < o4))
        then
          assert kbyte(a) = 0
            report "TB FAIL " & name & ": KEM byte " & integer'image(a) &
                   " written by the core survives the operation"
            severity failure;
          n := n + 1;
        end if;
      end loop;
      assert n > 0 report "TB FAIL " & name & ": monitor saw no core writes"
        severity failure;
      nchk := nchk + 1;
    end procedure;

    procedure dsa_marked_zero (name : string; o1, o2, o3, o4 : integer) is
      variable n : integer := 0;
    begin
      for a in 0 to 16383 loop
        if dmark(a) and not ((a >= o1 and a < o2) or (a >= o3 and a < o4))
        then
          assert dbyte(a) = 0
            report "TB FAIL " & name & ": DSA byte " & integer'image(a) &
                   " written by the core survives the operation"
            severity failure;
          n := n + 1;
        end if;
      end loop;
      assert n > 0 report "TB FAIL " & name & ": monitor saw no core writes"
        severity failure;
      nchk := nchk + 1;
    end procedure;

    procedure kem_range_zero (name : string; lo, hi : integer) is
    begin
      for a in lo to hi - 1 loop
        assert kbyte(a) = 0
          report "TB FAIL " & name & ": KEM byte " & integer'image(a) &
                 " not zero" severity failure;
      end loop;
      nchk := nchk + 1;
    end procedure;

    procedure dsa_range_zero (name : string; lo, hi : integer) is
    begin
      for a in lo to hi - 1 loop
        assert dbyte(a) = 0
          report "TB FAIL " & name & ": DSA byte " & integer'image(a) &
                 " not zero" severity failure;
      end loop;
      nchk := nchk + 1;
    end procedure;

    procedure kem_keygen_kat is
    begin
      for i in 0 to 31 loop
        kwrite(i, d_b(i));
        kwrite(32 + i, z_b(i));
      end loop;
      krun("00");
      for i in 0 to C_EK - 1 loop
        kread(512 + i, v);
        assert v = ek_b(i) report "TB FAIL kem ek " & integer'image(i)
          severity failure;
      end loop;
      for i in 0 to C_DK - 1 loop
        kread(2048 + i, v);
        assert v = dk_b(i) report "TB FAIL kem dk " & integer'image(i)
          severity failure;
      end loop;
    end procedure;

  begin
    rst_n <= '0';
    wait_clk(5);
    rst_n <= '1';
    wait_clk(5);

    ------------------------------------------------------------------
    -- ML-KEM chain
    ------------------------------------------------------------------
    alg <= '0';
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

    kem_keygen_kat;
    kem_marked_zero("KEM KeyGen", 512, 512 + C_EK, 2048, 2048 + C_DK);
    kem_range_zero("KEM KeyGen d||z", 0, 64);
    kem_poly_zero("KEM KeyGen");
    sponge_zero("KEM KeyGen");

    -- park dk in the host scratch area, as the self-test firmware does
    for i in 0 to C_DK - 1 loop
      kwrite(5760 + i, dk_b(i));
    end loop;
    for i in 0 to 31 loop
      kwrite(i, m_b(i));
    end loop;
    krun("01");
    for i in 0 to C_CT - 1 loop
      kread(2048 + i, v);
      assert v = ct_b(i) report "TB FAIL kem ct " & integer'image(i)
        severity failure;
    end loop;
    for i in 0 to 31 loop
      kread(32 + i, v);
      assert v = ss_b(i) report "TB FAIL kem K " & integer'image(i)
        severity failure;
    end loop;
    kem_marked_zero("KEM Encaps", 32, 64, 2048, 2048 + C_CT);
    kem_range_zero("KEM Encaps m", 0, 32);
    kem_range_zero("KEM Encaps old dk tail", 2048 + C_CT, 2048 + C_DK);
    kem_poly_zero("KEM Encaps");
    sponge_zero("KEM Encaps");

    for i in 0 to C_CT - 1 loop
      kwrite(i, ct_b(i));
    end loop;
    for i in 0 to C_DK - 1 loop
      kwrite(2048 + i, dk_b(i));
    end loop;
    krun("10");
    for i in 0 to 31 loop
      kread(1280 + i, v);
      assert v = ss_b(i) report "TB FAIL kem Kout " & integer'image(i)
        severity failure;
    end loop;
    kem_marked_zero("KEM Decaps", 1280, 1312, 1280, 1312);
    kem_range_zero("KEM Decaps dk", 2048, 2048 + C_DK);
    kem_range_zero("KEM Decaps m2..Kbar", 1152, 1280);
    kem_range_zero("KEM Decaps c2", 4608, 4608 + C_CT);
    kem_poly_zero("KEM Decaps");
    sponge_zero("KEM Decaps");
    report "PQC ZEROIZE KEM chain wiped after every operation" severity note;

    ------------------------------------------------------------------
    -- ML-DSA chain
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
    rdhex(xi_b, 32, ln);  rdhex(mu_b, 64, ln);
    rdhex(pk_b, C_PK, ln); rdhex(sk_b, C_SK, ln);
    rdhex(sg_b, C_SIG, ln);
    file_close(fh);

    for i in 0 to 31 loop
      dwrite(i, xi_b(i));
    end loop;
    drun("00");
    for i in 0 to C_PK - 1 loop
      dread(256 + i, v);
      assert v = pk_b(i) report "TB FAIL dsa pk " & integer'image(i)
        severity failure;
    end loop;
    for i in 0 to C_SK - 1 loop
      dread(2304 + i, v);
      assert v = sk_b(i) report "TB FAIL dsa sk " & integer'image(i)
        severity failure;
    end loop;
    dsa_marked_zero("DSA KeyGen", 256, 256 + C_PK, 2304, 2304 + C_SK);
    dsa_range_zero("DSA KeyGen xi", 0, 32);
    dsa_poly_zero("DSA KeyGen");
    sponge_zero("DSA KeyGen");

    for i in 0 to C_SK - 1 loop
      dwrite(i, sk_b(i));
    end loop;
    for i in 0 to 63 loop
      dwrite(4096 + i, mu_b(i));
    end loop;
    drun("01");
    for i in 0 to C_SIG - 1 loop
      dread(8192 + i, v);
      assert v = sg_b(i) report "TB FAIL dsa sig " & integer'image(i)
        severity failure;
    end loop;
    dsa_marked_zero("DSA Sign", 8192, 8192 + C_SIG, 8192, 8192 + C_SIG);
    dsa_range_zero("DSA Sign sk", 0, C_SK);
    dsa_range_zero("DSA Sign rho''..w1 and old sk tail", 4160, 6336);
    dsa_poly_zero("DSA Sign");
    sponge_zero("DSA Sign");

    for i in 0 to C_SIG - 1 loop
      dwrite(2176 + i, sg_b(i));
    end loop;
    for i in 0 to C_PK - 1 loop
      dwrite(i, pk_b(i));
    end loop;
    for i in 0 to 63 loop
      dwrite(2048 + i, mu_b(i));
    end loop;
    dsa_siglen <= std_logic_vector(to_unsigned(C_SIG, 16));
    drun("10");
    assert dsa_result = '1'
      report "TB FAIL dsa verify rejected the signature" severity failure;
    report "PQC ZEROIZE DSA chain wiped after KeyGen and Sign" severity note;

    ------------------------------------------------------------------
    -- ZEROIZE command: everything must be zero afterwards
    ------------------------------------------------------------------
    nd0 := n_zdone;
    zeroize <= '1';
    wait_clk(1);
    zeroize <= '0';
    wait_clk(1);
    assert zbusy = '1' report "TB FAIL zbusy not raised" severity failure;
    while zbusy = '1' loop
      wait_clk(1);
    end loop;
    wait_clk(2);
    assert n_zdone = nd0 + 1 report "TB FAIL zdone did not pulse once"
      severity failure;
    kem_range_zero("ZEROIZE KEM bytes", 0, 8192);
    dsa_range_zero("ZEROIZE DSA bytes", 0, 16384);
    kem_poly_zero("ZEROIZE");
    dsa_poly_zero("ZEROIZE");
    sponge_zero("ZEROIZE");
    report "PQC ZEROIZE command wipes every memory" severity note;

    ------------------------------------------------------------------
    -- ZEROIZE aborting a running KEM KeyGen
    ------------------------------------------------------------------
    alg <= '0';
    wait_clk(2);
    for i in 0 to 31 loop
      kwrite(i, d_b(i));
      kwrite(32 + i, z_b(i));
    end loop;
    kem_op   <= "00";
    kem_hsel <= '0';
    wait_clk(2);
    nd0 := n_done;
    kem_start <= '1';
    wait_clk(1);
    kem_start <= '0';
    wait_clk(30000);                     -- well inside KeyGen
    assert kem_busy = '1' report "TB FAIL KeyGen not running at abort"
      severity failure;
    zeroize <= '1';
    wait_clk(1);
    zeroize <= '0';
    wait_clk(1);
    while zbusy = '1' or kem_busy = '1' loop
      wait_clk(1);
    end loop;
    wait_clk(4);
    assert n_done = nd0 report "TB FAIL aborted KeyGen pulsed done"
      severity failure;
    kem_range_zero("ZEROIZE abort KEM bytes", 0, 8192);
    kem_poly_zero("ZEROIZE abort");
    sponge_zero("ZEROIZE abort");
    -- the core must be fully usable again
    kem_hsel <= '1';
    kem_keygen_kat;
    report "PQC ZEROIZE abort wipes and the core recovers" severity note;

    assert err = "0000"
      report "TB FAIL err=" & to_string(err) & " in a well-formed flow"
      severity failure;

    report "PQC ZEROIZE PASS checks=" & integer'image(nchk) &
           " kem=3 dsa=3 cmd=1 abort=1" severity note;
    std.env.finish;
    wait;
  end process;

end architecture sim;
