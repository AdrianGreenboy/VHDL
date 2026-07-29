-- tb_pqc_selftest: the hardware self-test FSM driving pqc_core, no file I/O.
-- Must raise pass and expose both signatures matching the fusion test.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pqc_selftest is end entity;
architecture sim of tb_pqc_selftest is
  function to_hex (v : unsigned(63 downto 0)) return string is
    constant D : string(1 to 16) := "0123456789abcdef";
    variable r : string(1 to 16);
  begin
    for i in 0 to 15 loop
      r(16-i) := D(to_integer(v(4*i+3 downto 4*i))+1);
    end loop;
    return r;
  end function;

  signal clk : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal start, done, pass, fail, busy : std_logic := '0';
  signal kem_sig, dsa_sig : std_logic_vector(63 downto 0);

  signal alg : std_logic;
  signal kem_op : std_logic_vector(1 downto 0);
  signal kem_start, kem_done, kem_busy, kem_rej, kem_hwe, kem_hsel : std_logic;
  signal kem_haddr : std_logic_vector(12 downto 0);
  signal kem_hdin, kem_hdout : std_logic_vector(7 downto 0);
  signal dsa_op : std_logic_vector(1 downto 0);
  signal dsa_start, dsa_done, dsa_busy, dsa_result, dsa_hwe, dsa_hsel : std_logic;
  signal dsa_siglen : std_logic_vector(15 downto 0);
  signal dsa_reason : std_logic_vector(2 downto 0);
  signal dsa_haddr : std_logic_vector(13 downto 0);
  signal dsa_hdin, dsa_hdout : std_logic_vector(7 downto 0);
begin
  clk <= not clk after 5 ns;

  u_st : entity work.pqc_selftest
    port map (clk=>clk, rst_n=>rst_n, start=>start, done=>done, pass=>pass,
              fail=>fail, busy=>busy, kem_sig=>kem_sig, dsa_sig=>dsa_sig,
              alg=>alg, kem_op=>kem_op, kem_start=>kem_start, kem_done=>kem_done,
              kem_rej=>kem_rej, kem_haddr=>kem_haddr, kem_hdin=>kem_hdin,
              kem_hwe=>kem_hwe, kem_hsel=>kem_hsel, kem_hdout=>kem_hdout,
              dsa_op=>dsa_op, dsa_start=>dsa_start, dsa_siglen=>dsa_siglen,
              dsa_done=>dsa_done, dsa_result=>dsa_result, dsa_haddr=>dsa_haddr,
              dsa_hdin=>dsa_hdin, dsa_hwe=>dsa_hwe, dsa_hsel=>dsa_hsel,
              dsa_hdout=>dsa_hdout);

  u_core : entity work.pqc_core
    port map (clk=>clk, rst_n=>rst_n, alg=>alg,
              kem_op=>kem_op, kem_start=>kem_start, kem_done=>kem_done,
              kem_busy=>kem_busy, kem_rej=>kem_rej, kem_haddr=>kem_haddr,
              kem_hdin=>kem_hdin, kem_hwe=>kem_hwe, kem_hsel=>kem_hsel,
              kem_hdout=>kem_hdout,
              dsa_op=>dsa_op, dsa_start=>dsa_start, dsa_siglen=>dsa_siglen,
              dsa_done=>dsa_done, dsa_busy=>dsa_busy, dsa_result=>dsa_result,
              dsa_reason=>dsa_reason, dsa_haddr=>dsa_haddr, dsa_hdin=>dsa_hdin,
              dsa_hwe=>dsa_hwe, dsa_hsel=>dsa_hsel, dsa_hdout=>dsa_hdout);

  process begin
    rst_n <= '0'; wait for 60 ns; rst_n <= '1'; wait for 40 ns;
    wait until rising_edge(clk);
    start <= '1'; wait until rising_edge(clk); start <= '0';
    wait until done = '1';
    wait until rising_edge(clk);
    report "SELFTEST kem=" & to_hex(unsigned(kem_sig)) &
           " dsa=" & to_hex(unsigned(dsa_sig)) severity note;
    assert pass = '1' report "SELFTEST FAIL: pass not set (fail=" &
      std_logic'image(fail) & ")" severity failure;
    assert kem_sig = x"95e07091fa5b3cc4" report "kem sig wrong" severity failure;
    assert dsa_sig = x"f93232f7ea2d1575" report "dsa sig wrong" severity failure;
    report "PQC L5 SELFTEST PASS kem=" & to_hex(unsigned(kem_sig)) &
           " dsa=" & to_hex(unsigned(dsa_sig)) & " embedded_rom=1" severity note;
    std.env.finish;
    wait;
  end process;
end architecture;
