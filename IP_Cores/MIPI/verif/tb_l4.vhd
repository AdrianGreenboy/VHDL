library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_l4 is
end entity;

architecture sim of tb_l4 is
  constant GOLDEN    : unsigned(31 downto 0) := x"E6898DC5";
  constant GOLDEN_F0 : unsigned(31 downto 0) := x"0C4F29C5";
  constant GOLDEN_F1 : unsigned(31 downto 0) := x"41D701C5";
  constant FNV_PRIME : unsigned(31 downto 0) := x"01000193";
  constant FB_AWID   : integer := 15;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal byte_in : std_logic_vector(7 downto 0) := (others=>'0');
  signal byte_valid : std_logic := '0';
  signal frame_done : std_logic;
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

  dut : entity work.csi2_dual_rx
    generic map (FB_DEPTH=>18432, FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst, byte_in=>byte_in, byte_valid=>byte_valid,
              frame_done=>frame_done,
              fb0_re=>fb0_re, fb0_raddr=>fb0_raddr, fb0_rdata=>fb0_rdata, fb0_count=>fb0_count,
              fb1_re=>fb1_re, fb1_raddr=>fb1_raddr, fb1_rdata=>fb1_rdata, fb1_count=>fb1_count,
              hdr_2bit=>hdr_2bit);

  stim : process
    file fh : text;
    variable ln : line;
    variable bv : std_logic_vector(7 downto 0);
    variable ok : file_open_status;
    variable h, h0, h1 : unsigned(31 downto 0);
    variable n0, n1 : integer;
  begin
    rst<='1'; byte_valid<='0'; wait for 40 ns;
    wait until rising_edge(clk); rst<='0'; wait until rising_edge(clk);

    file_open(ok, fh, "l4_stream.hex", read_mode);
    assert ok=open_ok report "no l4_stream.hex" severity failure;
    while not endfile(fh) loop
      readline(fh, ln); hread(ln, bv);
      byte_in<=bv; byte_valid<='1';
      wait until rising_edge(clk);
      byte_valid<='0';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end loop;
    file_close(fh);
    byte_valid<='0';
    for i in 0 to 9 loop wait until rising_edge(clk); end loop;

    n0 := to_integer(unsigned(fb0_count));
    n1 := to_integer(unsigned(fb1_count));
    report "FB0 bytes="&integer'image(n0)&" FB1 bytes="&integer'image(n1);

    -- fold FB0
    h0 := x"811C9DC5";
    for a in 0 to n0-1 loop
      fb0_raddr <= std_logic_vector(to_unsigned(a, FB_AWID)); fb0_re<='1';
      wait until rising_edge(clk); wait until rising_edge(clk);
      h0 := fnv_step(h0, unsigned(fb0_rdata));
    end loop;
    fb0_re<='0';

    -- fold FB1
    h1 := x"811C9DC5";
    for a in 0 to n1-1 loop
      fb1_raddr <= std_logic_vector(to_unsigned(a, FB_AWID)); fb1_re<='1';
      wait until rising_edge(clk); wait until rising_edge(clk);
      h1 := fnv_step(h1, unsigned(fb1_rdata));
    end loop;
    fb1_re<='0';

    -- combined FNV over FB0 ++ FB1 (continuous fold)
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

    report "L4 FB0 FNV = 0x"&to_hstring(h0);
    report "L4 FB1 FNV = 0x"&to_hstring(h1);
    report "L4 combined = 0x"&to_hstring(h);
    if h=GOLDEN and h0=GOLDEN_F0 and h1=GOLDEN_F1 then
      report "L4 PASS - combined=0x"&to_hstring(GOLDEN) severity note;
    else
      report "L4 FAIL - got 0x"&to_hstring(h)&" exp 0x"&to_hstring(GOLDEN) severity failure;
    end if;
    wait;
  end process;
end architecture;
