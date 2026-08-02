-- =============================================================================
-- L1 testbench for raw12_unpack
-- Reads l1_packed.hex (one byte per line, hex), feeds the unpacker, collects
-- pixels, folds an FNV-1a-32 over the pixel stream (2 bytes/pixel, little-
-- endian) and compares against the oracle golden signature.
--
-- PASS criterion (sole): FNV(unpacked pixels) == 0xEC935F45
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_l1 is
end entity;

architecture sim of tb_l1 is
  constant GOLDEN : unsigned(31 downto 0) := x"EC935F45";

  signal clk        : std_logic := '0';
  signal rst        : std_logic := '1';
  signal byte_in    : std_logic_vector(7 downto 0) := (others => '0');
  signal byte_valid : std_logic := '0';
  signal pix_out    : std_logic_vector(11 downto 0);
  signal pix_valid  : std_logic;

  signal done : boolean := false;

  -- FNV-1a accumulator, updated on every emitted pixel
  signal fnv : unsigned(31 downto 0) := x"811C9DC5";

  constant FNV_PRIME : unsigned(31 downto 0) := x"01000193";

  -- multiply low-32 helper
  function fnv_step(h : unsigned(31 downto 0); b : unsigned(7 downto 0))
    return unsigned is
    variable x : unsigned(31 downto 0);
    variable m : unsigned(63 downto 0);
  begin
    x := h xor resize(b, 32);
    m := x * FNV_PRIME;
    return m(31 downto 0);
  end function;

begin
  clk <= not clk after 5 ns;

  dut : entity work.raw12_unpack
    port map (
      clk => clk, rst => rst,
      byte_in => byte_in, byte_valid => byte_valid,
      pix_out => pix_out, pix_valid => pix_valid
    );

  -- FNV update on each emitted pixel (LSB byte then MSB byte, matching the
  -- oracle's 2-bytes/pixel little-endian layout)
  process(clk)
    variable h : unsigned(31 downto 0);
    variable p : unsigned(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '0' and pix_valid = '1' then
        p := unsigned(pix_out);
        h := fnv;
        h := fnv_step(h, p(7 downto 0));            -- low byte
        h := fnv_step(h, resize(p(11 downto 8), 8)); -- high byte
        fnv <= h;
      end if;
    end if;
  end process;

  -- stimulus: read hex file, feed one byte then a bubble cycle so the staged
  -- P1 drains (respects L1 pacing: no new byte while a P1 is pending).
  stim : process
    file fh              : text;
    variable ln          : line;
    variable byte_v      : std_logic_vector(7 downto 0);
    variable open_status : file_open_status;
  begin
    rst        <= '1';
    byte_valid <= '0';
    wait for 40 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    file_open(open_status, fh, "l1_packed.hex", read_mode);
    assert open_status = open_ok
      report "cannot open l1_packed.hex" severity failure;

    while not endfile(fh) loop
      readline(fh, ln);
      hread(ln, byte_v);
      -- present the byte for one cycle
      byte_in    <= byte_v;
      byte_valid <= '1';
      wait until rising_edge(clk);
      -- bubble: deassert so a pending P1 (from a b2 byte) can drain without
      -- colliding with a new incoming byte
      byte_valid <= '0';
      wait until rising_edge(clk);
    end loop;
    file_close(fh);

    -- flush: a few idle cycles to drain the last staged pixel
    byte_valid <= '0';
    for i in 0 to 4 loop
      wait until rising_edge(clk);
    end loop;

    -- check signature
    report "L1 FNV = 0x" & to_hstring(fnv);
    if fnv = GOLDEN then
      report "L1 PASS - signature matches oracle golden 0x" & to_hstring(GOLDEN)
        severity note;
    else
      report "L1 FAIL - got 0x" & to_hstring(fnv) &
             " expected 0x" & to_hstring(GOLDEN) severity failure;
    end if;

    done <= true;
    wait;
  end process;

end architecture;
