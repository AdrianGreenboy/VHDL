library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_l3 is
end entity;

architecture sim of tb_l3 is
  constant GOLDEN_FB : unsigned(31 downto 0) := x"0C4F29C5";  -- packed framebuffer
  constant GOLDEN_PX : unsigned(31 downto 0) := x"D6488FC5";  -- pixel side-check
  constant FNV_PRIME : unsigned(31 downto 0) := x"01000193";
  constant FB_AWID   : integer := 15;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal byte_in : std_logic_vector(7 downto 0) := (others=>'0');
  signal byte_valid : std_logic := '0';
  signal frame_done : std_logic;
  signal fb_re : std_logic := '0';
  signal fb_raddr : std_logic_vector(FB_AWID-1 downto 0) := (others=>'0');
  signal fb_rdata : std_logic_vector(7 downto 0);
  signal fb_wcount : std_logic_vector(FB_AWID-1 downto 0);
  signal px_out : std_logic_vector(11 downto 0);
  signal px_valid : std_logic;

  signal fnv_px : unsigned(31 downto 0) := x"811C9DC5";

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

  dut : entity work.csi2_frame_rx
    generic map (FB_DEPTH=>18432, FB_AWID=>FB_AWID)
    port map (clk=>clk, rst=>rst, byte_in=>byte_in, byte_valid=>byte_valid,
              frame_done=>frame_done, fb_re=>fb_re, fb_raddr=>fb_raddr,
              fb_rdata=>fb_rdata, fb_wcount=>fb_wcount,
              px_out=>px_out, px_valid=>px_valid);

  -- pixel side-check FNV (2 bytes/px LE)
  process(clk)
    variable h : unsigned(31 downto 0);
    variable p : unsigned(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst='0' and px_valid='1' then
        p := unsigned(px_out);
        h := fnv_px;
        h := fnv_step(h, p(7 downto 0));
        h := fnv_step(h, resize(p(11 downto 8),8));
        fnv_px <= h;
      end if;
    end if;
  end process;

  stim : process
    file fh : text;
    variable ln : line;
    variable bv : std_logic_vector(7 downto 0);
    variable ok : file_open_status;
    variable h : unsigned(31 downto 0);
    variable nbytes : integer;
  begin
    rst<='1'; byte_valid<='0'; wait for 40 ns;
    wait until rising_edge(clk); rst<='0'; wait until rising_edge(clk);

    file_open(ok, fh, "l3_stream.hex", read_mode);
    assert ok=open_ok report "no l3_stream.hex" severity failure;
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

    -- read back committed framebuffer bytes and fold FNV
    nbytes := to_integer(unsigned(fb_wcount));
    report "committed bytes = " & integer'image(nbytes);
    h := x"811C9DC5";
    for a in 0 to nbytes-1 loop
      fb_raddr <= std_logic_vector(to_unsigned(a, FB_AWID));
      fb_re <= '1';
      wait until rising_edge(clk);
      wait until rising_edge(clk);   -- registered read latency
      h := fnv_step(h, unsigned(fb_rdata));
    end loop;
    fb_re <= '0';

    report "L3 FB FNV = 0x" & to_hstring(h);
    report "L3 PX FNV = 0x" & to_hstring(fnv_px);
    if h = GOLDEN_FB and fnv_px = GOLDEN_PX then
      report "L3 PASS - FB=0x"&to_hstring(GOLDEN_FB)&" PX=0x"&to_hstring(GOLDEN_PX)
        severity note;
    else
      report "L3 FAIL - FB got 0x"&to_hstring(h)&" exp 0x"&to_hstring(GOLDEN_FB)&
             " ; PX got 0x"&to_hstring(fnv_px)&" exp 0x"&to_hstring(GOLDEN_PX)
        severity failure;
    end if;
    wait;
  end process;
end architecture;
