-- =============================================================================
-- HERCOSSNUX PQC IP Core - audit 2026-11
-- tb_sponge_err: keccak_sponge protocol-error flag and zeroization.
-- VHDL-2008. ASCII-only. MIT license.
--
-- A command the sponge cannot honour must set the sticky err output; a
-- correct protocol sequence must leave it clear; err_clr clears it. A zero
-- pulse must leave the state and the permutation input register at zero.
-- The SHA3-256 digest of "abc" is checked so the legal path is not broken.
-- Expected final line:  PQC SPONGEERR PASS ...
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.keccak_pkg.all;

entity tb_sponge_err is
end entity tb_sponge_err;

architecture sim of tb_sponge_err is
  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal mode   : std_logic_vector(1 downto 0) := "10";
  signal init, din_we, adone, dout_re, zero, err_clr : std_logic := '0';
  signal din, dout : std_logic_vector(7 downto 0) := (others => '0');
  signal dvalid, ready, zbusy, err : std_logic;
  signal fin : boolean := false;
begin
  clk <= not clk after 5 ns when not fin else '0';

  dut : entity work.keccak_sponge
    port map (clk => clk, rst_n => rst_n, mode => mode, init => init,
              din => din, din_we => din_we, absorb_done => adone,
              dout => dout, dout_re => dout_re, dout_valid => dvalid,
              ready => ready, zero => zero, zbusy => zbusy, err => err,
              err_clr => err_clr);

  process
    alias sst is <<signal .tb_sponge_err.dut.st : t_state>>;
    alias skin is <<signal .tb_sponge_err.dut.k_in : t_state>>;
    constant ABC : std_logic_vector(23 downto 0) := x"616263";
    -- SHA3-256("abc") = 3a985da7 4fe225b2 ...
    constant H0 : std_logic_vector(31 downto 0) := x"3a985da7";
    variable got : std_logic_vector(31 downto 0);
    variable n : integer := 0;

    procedure tick (k : integer := 1) is
    begin
      for i in 1 to k loop
        wait until rising_edge(clk);
      end loop;
    end procedure;
    procedure pulse (signal s : out std_logic) is
    begin
      s <= '1'; tick; s <= '0'; tick;
    end procedure;
    procedure expect_err (exp : std_logic; what : string) is
    begin
      tick;
      assert err = exp
        report "TB FAIL " & what & ": err=" & std_logic'image(err)
        severity failure;
      n := n + 1;
      if exp = '1' then
        pulse(err_clr);
        assert err = '0' report "TB FAIL err_clr" severity failure;
      end if;
    end procedure;
    procedure hash_abc is
    begin
      mode <= "10";
      pulse(init);
      for i in 0 to 2 loop
        while ready = '0' loop tick; end loop;
        din <= ABC(23 - 8 * i downto 16 - 8 * i);
        pulse(din_we);
      end loop;
      while ready = '0' loop tick; end loop;
      pulse(adone);
      while dvalid = '0' loop tick; end loop;
      for i in 0 to 3 loop
        got(31 - 8 * i downto 24 - 8 * i) := dout;
        pulse(dout_re);
        while dvalid = '0' loop tick; end loop;
      end loop;
    end procedure;
  begin
    tick(3);
    rst_n <= '1';
    tick(2);

    -- legal sequence: no error, correct digest
    hash_abc;
    assert got = H0 report "TB FAIL SHA3-256(abc) prefix " & to_hstring(got)
      severity failure;
    expect_err('0', "legal sequence");

    -- dout_re while not squeezing (sponge parked after reset/zero)
    pulse(zero);
    while zbusy = '1' loop tick; end loop;
    tick;
    for i in 0 to 24 loop
      assert sst(i) = x"0000000000000000" and skin(i) = x"0000000000000000"
        report "TB FAIL zero left state lane " & integer'image(i)
        severity failure;
    end loop;
    n := n + 1;
    pulse(dout_re);
    expect_err('1', "dout_re outside squeeze");

    -- absorb_done outside absorb
    pulse(adone);
    expect_err('1', "absorb_done outside absorb");

    -- din_we while a permutation is in flight: fill a SHA3-512 block
    mode <= "11";
    pulse(init);
    for i in 0 to 71 loop
      din_we <= '1'; din <= std_logic_vector(to_unsigned(i, 8)); tick;
    end loop;
    din_we <= '0';
    -- the 72nd byte started a permutation; one more byte now is dropped
    din_we <= '1'; tick; din_we <= '0';
    expect_err('1', "din_we during permutation");

    -- init while the permutation is still in flight
    while ready = '0' loop tick; end loop;
    pulse(init);
    while ready = '0' loop tick; end loop;
    pulse(adone);
    tick;
    init <= '1'; tick; init <= '0';          -- pad permutation running
    expect_err('1', "init during permutation");

    -- and the legal path still works afterwards
    while dvalid = '0' and ready = '0' loop tick; end loop;
    tick(20);
    hash_abc;
    assert got = H0 report "TB FAIL digest after errors" severity failure;
    expect_err('0', "legal sequence after errors");

    report "PQC SPONGEERR PASS checks=" & integer'image(n) severity note;
    fin <= true;
    wait;
  end process;
end architecture sim;
