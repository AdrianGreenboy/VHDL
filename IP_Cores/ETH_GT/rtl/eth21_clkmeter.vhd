-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Medidor de frecuencia de un reloj del GT contra aclk: el reloj medido
-- divide por 256 (bit 7 de un contador libre); aclk cuenta los flancos de
-- ese bit (cada flanco = 128 ciclos) en ventanas de ACLK_HZ/10 ciclos
-- (100 ms). result = flancos por ventana -> f = result * 1280 Hz.
-- (390.625 MHz -> 305175; 156.25 MHz -> 122070.) Si el reloj esta parado,
-- result = 0: diagnostico directo de BUFG_GT / TXPROGDIVCLK en silicio.
-- alive = 1 si hubo un flanco en los ultimos 255 ciclos de aclk (a 40 MHz
-- basta con que el reloj medido supere ~20 MHz): lo usa la secuencia de
-- reset del GT antes de subir TX/RXUSERRDY.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth21_clkmeter is
  generic (
    ACLK_HZ : natural := 100_000_000
  );
  port (
    clk_m  : in  std_logic;
    aclk   : in  std_logic;
    result : out std_logic_vector(31 downto 0);
    alive  : out std_logic
  );
end entity eth21_clkmeter;

architecture rtl of eth21_clkmeter is
  constant WIN : natural := ACLK_HZ / 10;
  signal div : unsigned(7 downto 0) := (others => '0');
  signal s1, s2, s3 : std_logic := '0';
  signal edges, win_c : unsigned(31 downto 0) := (others => '0');
  signal res : std_logic_vector(31 downto 0) := (others => '0');
  signal idle_c : unsigned(7 downto 0) := (others => '1');
  signal alive_r : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of s1, s2 : signal is "TRUE";
begin
  process(clk_m)
  begin
    if rising_edge(clk_m) then
      div <= div + 1;
    end if;
  end process;

  process(aclk)
  begin
    if rising_edge(aclk) then
      s1 <= div(7); s2 <= s1; s3 <= s2;
      if s2 /= s3 then
        idle_c <= (others => '0');
      elsif idle_c /= 255 then
        idle_c <= idle_c + 1;
      end if;
      if idle_c = 255 then alive_r <= '0'; else alive_r <= '1'; end if;
      if win_c = WIN - 1 then
        win_c <= (others => '0');
        if s2 /= s3 then res <= std_logic_vector(edges + 1);
        else res <= std_logic_vector(edges); end if;
        edges <= (others => '0');
      else
        win_c <= win_c + 1;
        if s2 /= s3 then edges <= edges + 1; end if;
      end if;
    end if;
  end process;
  result <= res;
  alive  <= alive_r;
end architecture rtl;
