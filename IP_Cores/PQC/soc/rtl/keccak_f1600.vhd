-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1
-- keccak_f1600: Keccak-f[1600] permutation, 2 rounds per cycle.
-- 24 rounds / 2 = 12 cycles per permutation.
-- VHDL-2008. ASCII-only. MIT license.
--
-- Handshake:
--   assert start for one cycle with state_in valid -> busy goes high
--   done pulses for one cycle when state_out is valid
--   the core is idle again on the cycle after done
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.keccak_pkg.all;

entity keccak_f1600 is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start     : in  std_logic;
    state_in  : in  t_state;
    state_out : out t_state;
    busy      : out std_logic;
    done      : out std_logic);
end entity keccak_f1600;

architecture rtl of keccak_f1600 is

  signal st       : t_state := (others => (others => '0'));
  signal rnd      : unsigned(4 downto 0) := (others => '0');
  signal running  : std_logic := '0';
  signal done_r   : std_logic := '0';

begin

  state_out <= st;
  busy      <= running;
  done      <= done_r;

  process (clk)
    variable s0 : t_state;
    variable s1 : t_state;
    variable i  : integer range 0 to 23;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        st      <= (others => (others => '0'));
        rnd     <= (others => '0');
        running <= '0';
        done_r  <= '0';
      else
        done_r <= '0';

        if running = '0' then
          if start = '1' then
            st      <= state_in;
            rnd     <= (others => '0');
            running <= '1';
          end if;
        else
          i  := to_integer(rnd);
          -- Two rounds per cycle. Round index is always even here because
          -- rnd advances by 2, so i and i+1 are a valid consecutive pair.
          s0 := keccak_round(st, C_RC(i));
          s1 := keccak_round(s0, C_RC(i + 1));
          st <= s1;

          if i = 22 then
            running <= '0';
            done_r  <= '1';
            rnd     <= (others => '0');
          else
            rnd <= rnd + 2;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
