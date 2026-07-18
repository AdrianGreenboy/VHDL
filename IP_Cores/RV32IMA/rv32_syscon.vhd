-- =============================================================
-- rv32_syscon.vhd - HERCOSSNUX RV32IMA SoC v1 - Paso 5
-- SYSCON en 0x11100000, paridad con mini-rv32ima:
--   escritura 0x5555 -> poweroff  (pulso poweroff_o)
--   escritura 0x7777 -> reboot    (pulso reboot_o)
--   otras escrituras -> ignoradas
--   lecturas          -> 0
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32_syscon is
  port (
    clk        : in  std_logic;
    rstn       : in  std_logic;
    -- bus single-beat
    req        : in  std_logic;
    we         : in  std_logic;
    addr       : in  std_logic_vector(15 downto 0);
    wdata      : in  std_logic_vector(31 downto 0);
    rdata      : out std_logic_vector(31 downto 0);
    ready      : out std_logic;
    -- eventos de sistema (pulsos de 1 ciclo)
    poweroff_o : out std_logic;
    reboot_o   : out std_logic
  );
end entity;

architecture rtl of rv32_syscon is
  constant CODE_POWEROFF : std_logic_vector(31 downto 0) := x"00005555";
  constant CODE_REBOOT   : std_logic_vector(31 downto 0) := x"00007777";
  signal po_r, rb_r : std_logic := '0';
begin
  ready      <= '1';
  rdata      <= (others => '0');
  poweroff_o <= po_r;
  reboot_o   <= rb_r;

  proc : process (clk, rstn)
  begin
    if rstn = '0' then
      po_r <= '0';
      rb_r <= '0';
    elsif rising_edge(clk) then
      po_r <= '0';
      rb_r <= '0';
      if req = '1' and we = '1' and addr = x"0000" then
        if wdata = CODE_POWEROFF then
          po_r <= '1';
        elsif wdata = CODE_REBOOT then
          rb_r <= '1';
        end if;
      end if;
    end if;
  end process;

end architecture;
