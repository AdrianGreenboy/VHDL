library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_l5 is
end entity;

architecture sim of tb_l5 is
  constant GOLDEN    : unsigned(31 downto 0) := x"E6898DC5";
  constant FNV_PRIME : unsigned(31 downto 0) := x"01000193";
  constant FB_AWID   : integer := 15;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal start : std_logic := '0';
  signal done : std_logic;
  signal fb0_re, fb1_re : std_logic := '0';
  signal fb0_raddr, fb1_raddr : std_logic_vector(FB_AWID-1 downto 0) := (others=>'0');
  signal fb0_rdata, fb1_rdata : std_logic_vector(7 downto 0);
  signal fb0_count, fb1_count : std_logic_vector(FB_AWID-1 downto 0);
  signal hdr_2bit : std_logic;

  function fnv_step(h : unsigned(31 downto 0); b : unsigned(7 downto 0))
    return unsigned is
    variable x : unsigned(31 downto 0);
    variable m : unsigned(63 downto 0);
  begin
    x := h xor resize(b,32);
    m := x * FNV_PRIME;
    return m(31 downto 0);
  end function;
begin
  clk <= not clk after 5 ns;

  dut : entity work.csi2_selftest
    generic map (W=>128, H=>96, FB_DEPTH=>18432, FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst, start=>start, done=>done,
              fb0_re=>fb0_re, fb0_raddr=>fb0_raddr, fb0_rdata=>fb0_rdata, fb0_count=>fb0_count,
              fb1_re=>fb1_re, fb1_raddr=>fb1_raddr, fb1_rdata=>fb1_rdata, fb1_count=>fb1_count,
              hdr_2bit=>hdr_2bit);

  stim : process
    variable h : unsigned(31 downto 0);
    variable n0, n1 : integer;
    variable guard : integer := 0;
  begin
    rst<='1'; start<='0'; wait for 40 ns;
    wait until rising_edge(clk); rst<='0'; wait until rising_edge(clk);
    start<='1'; wait until rising_edge(clk); start<='0';

    -- wait for done (with guard timeout)
    while done='0' and guard < 2000000 loop
      wait until rising_edge(clk);
      guard := guard + 1;
    end loop;
    assert done='1' report "TIMEOUT waiting for self-test done" severity failure;
    report "self-test done after "&integer'image(guard)&" cycles";

    -- a few cycles for count settle
    for i in 0 to 4 loop wait until rising_edge(clk); end loop;
    n0 := to_integer(unsigned(fb0_count));
    n1 := to_integer(unsigned(fb1_count));
    report "FB0="&integer'image(n0)&" FB1="&integer'image(n1);

    -- fold FNV over FB0 ++ FB1 (this is what the RV32 firmware will do)
    h := x"811C9DC5";
    for a in 0 to n0-1 loop
      fb0_raddr <= std_logic_vector(to_unsigned(a, FB_AWID)); fb0_re<='1';
      wait until rising_edge(clk); wait until rising_edge(clk);
      h := fnv_step(h, unsigned(fb0_rdata));
    end loop;
    fb0_re<='0';
    for a in 0 to n1-1 loop
      fb1_raddr <= std_logic_vector(to_unsigned(a, FB_AWID)); fb1_re<='1';
      wait until rising_edge(clk); wait until rising_edge(clk);
      h := fnv_step(h, unsigned(fb1_rdata));
    end loop;
    fb1_re<='0';

    report "L5 loopback FNV = 0x"&to_hstring(h);
    if h = GOLDEN then
      report "L5 PASS - full self-test chain matches oracle 0x"&to_hstring(GOLDEN)
        severity note;
    else
      report "L5 FAIL - got 0x"&to_hstring(h)&" exp 0x"&to_hstring(GOLDEN)
        severity failure;
    end if;
    wait;
  end process;
end architecture;
