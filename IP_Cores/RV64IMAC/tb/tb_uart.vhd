-- tb_uart.vhd - audit-2026-11: rv64_uart divisor handling (self-checking).
-- TX looped back to RX. For divisor 1 (reset value), divisor 0 and divisor 3
-- a byte is sent and received, and the frame length on the TX line is
-- measured: 10 bits * 16 * max(divisor, 1) cycles. Before the fix a divisor of
-- 0 made bitlen = 0 and the tick counters ran to 2^20 - 1 per bit (frame
-- ~10 M cycles): the test then times out. Prints "tb_uart PASS casos=N".
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

entity tb_uart is
end entity;

architecture sim of tb_uart is
  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal req, we : std_logic := '0';
  signal addr  : std_logic_vector(2 downto 0) := "000";
  signal wdata : xword := (others => '0');
  signal rdata : xword;
  signal err, irq, tx : std_logic;
  signal done  : boolean := false;
begin
  clk <= not clk after 5 ns when not done else '0';

  dut : entity work.rv64_uart port map (
    clk => clk, rst => rst, req => req, we => we, addr => addr, size => "00",
    wdata => wdata, rdata => rdata, err => err, irq => irq, tx => tx, rx => tx);

  process
    variable fails, cases : natural := 0;
    variable t0, t1 : time;
    variable v : std_logic_vector(7 downto 0);

    procedure wr (constant a : natural; constant d : std_logic_vector(7 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a, 3));
      wdata <= (others => '0');
      wdata(8 * a + 7 downto 8 * a) <= d;
      req <= '1'; we <= '1';
      wait until rising_edge(clk);
      req <= '0'; we <= '0';
    end procedure;

    procedure rd (constant a : natural; variable d : out std_logic_vector(7 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a, 3));
      req <= '1'; we <= '0';
      wait for 1 ns;
      d := rdata(8 * a + 7 downto 8 * a);
      wait until rising_edge(clk);
      req <= '0';
    end procedure;

    procedure one (constant dv : natural; constant b : std_logic_vector(7 downto 0)) is
      variable frame : natural;
      variable eff   : natural;
    begin
      cases := cases + 1;
      eff := dv; if eff = 0 then eff := 1; end if;
      wr(3, x"83");                                        -- DLAB
      wr(0, std_logic_vector(to_unsigned(dv mod 256, 8)));
      wr(1, std_logic_vector(to_unsigned(dv / 256, 8)));
      wr(3, x"03");                                        -- 8N1
      wr(0, b);                                            -- THR
      wait until tx = '0' for 1 us;                        -- start bit
      if tx /= '0' then
        report "FAIL div=" & integer'image(dv) & ": no start bit" severity error;
        fails := fails + 1; return;
      end if;
      t0 := now;
      -- stop bit end: TX idle again and the frame fully shifted
      wait for (10 * 16 * eff - 8) * 10 ns;
      wait until rising_edge(clk) and tx = '1' for 400 us;
      for i in 0 to 16 * eff + 4 loop wait until rising_edge(clk); end loop;
      rd(5, v);                                            -- LSR
      if v(0) /= '1' then
        report "FAIL div=" & integer'image(dv) & ": nothing received (LSR=" & to_hstring(v) & ")"
          severity error;
        fails := fails + 1; return;
      end if;
      rd(0, v);
      if v /= b then
        report "FAIL div=" & integer'image(dv) & ": got " & to_hstring(v) & " exp " & to_hstring(b)
          severity error;
        fails := fails + 1;
      end if;
      t1 := now;
      frame := (t1 - t0) / 10 ns;
      if frame > 10 * 16 * eff + 16 * eff + 40 then
        report "FAIL div=" & integer'image(dv) & ": frame too long (" & integer'image(frame) &
               " cycles)" severity error;
        fails := fails + 1;
      end if;
    end procedure;
  begin
    rst <= '1';
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;
    rst <= '0';
    wait until rising_edge(clk);
    one(1, x"A5");
    one(0, x"3C");
    one(3, x"81");
    one(0, x"FF");
    if fails = 0 then
      report "tb_uart PASS casos=" & integer'image(cases) severity note;
    else
      report "tb_uart FAIL fallos=" & integer'image(fails) severity error;
    end if;
    done <= true;
    wait;
  end process;
end architecture;
