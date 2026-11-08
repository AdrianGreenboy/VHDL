-- tb_rf_fifo.vhd (AUDIT 2026-11): rf_word_fifo unit test.
--  * FWFT order over a fill to capacity (2**L + 2 words) and a full drain;
--  * a write while full is dropped and sets the sticky 'ovf' (the old
--    word_fifo dropped silently); ovf survives further traffic, ovf_clr clears;
--  * simultaneous push + pop at mid level keeps order and level.
-- Pass: "RF FIFO PASS"; any error -> assert severity failure.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rf_fifo is
end entity;

architecture sim of tb_rf_fifo is
  constant L : natural := 4;                 -- 16 + 2 words
  constant CAP : natural := 2**L + 2;
  signal clk : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal wr_en, rd_en, ovf_clr : std_logic := '0';
  signal wr_data, rd_data : std_logic_vector(31 downto 0) := (others => '0');
  signal full, empty, ovf : std_logic;
  signal level : unsigned(L downto 0);
  signal fin : boolean := false;
begin
  clk <= '0' when fin else not clk after 5 ns;
  dut : entity work.rf_word_fifo
    generic map (LOG2_DEPTH => L)
    port map (clk => clk, aresetn => aresetn, wr_en => wr_en, wr_data => wr_data,
              full => full, rd_en => rd_en, rd_data => rd_data, empty => empty,
              level => level, ovf => ovf, ovf_clr => ovf_clr);
  process
    variable errs : integer := 0;
    variable nxt : integer := 0;
    procedure chk(c : boolean; m : string) is
    begin
      if not c then errs := errs + 1; report "RF FIFO: " & m severity error; end if;
    end procedure;
    procedure tick is begin wait until rising_edge(clk); wait for 1 ns; end procedure;
  begin
    wait for 22 ns; aresetn <= '1'; tick;
    -- fill well beyond capacity
    for k in 0 to CAP + 5 loop
      wr_data <= std_logic_vector(to_unsigned(16#100# + k, 32)); wr_en <= '1'; tick;
    end loop;
    wr_en <= '0'; tick; tick; tick;
    chk(ovf = '1', "ovf not set after writes into a full FIFO");
    chk(to_integer(level) = CAP, "level=" & integer'image(to_integer(level)) & " exp " & integer'image(CAP));
    -- drain: must return 0x100.. in order, exactly CAP words
    for k in 0 to CAP - 1 loop
      chk(empty = '0', "empty too early at " & integer'image(k));
      chk(rd_data = std_logic_vector(to_unsigned(16#100# + k, 32)),
          "order k=" & integer'image(k) & " got " & to_hstring(rd_data));
      rd_en <= '1'; tick; rd_en <= '0'; tick;
    end loop;
    tick; tick;
    chk(empty = '1', "not empty after draining CAP words");
    chk(ovf = '1', "ovf must be sticky");
    ovf_clr <= '1'; tick; ovf_clr <= '0'; tick;
    chk(ovf = '0', "ovf_clr did not clear");
    -- simultaneous push/pop at mid level
    for k in 0 to 7 loop
      wr_data <= std_logic_vector(to_unsigned(16#200# + k, 32)); wr_en <= '1'; tick;
    end loop;
    wr_en <= '0'; tick; tick; tick;
    nxt := 0;
    for k in 8 to 40 loop
      chk(rd_data = std_logic_vector(to_unsigned(16#200# + nxt, 32)), "push/pop order");
      wr_data <= std_logic_vector(to_unsigned(16#200# + k, 32)); wr_en <= '1'; rd_en <= '1';
      tick; nxt := nxt + 1;
    end loop;
    wr_en <= '0'; rd_en <= '0'; tick; tick; tick;
    chk(to_integer(level) = 8, "level after balanced push/pop =" & integer'image(to_integer(level)));
    chk(ovf = '0', "spurious ovf");
    assert errs = 0 report "RF FIFO FAIL errores=" & integer'image(errs) severity failure;
    report "RF FIFO PASS";
    fin <= true; wait;
  end process;
end architecture;
