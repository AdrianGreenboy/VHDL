-- =============================================================
-- rv32_clint.vhd - HERCOSSNUX RV32IMA SoC v1 - Paso 3
-- CLINT minimo compatible con el mapa de mini-rv32ima.
-- Registros (offset relativo a la base del CLINT):
--   0x0000  msip      (bit 0 = software interrupt pending)
--   0x4000  mtimecmp  lo (32b)
--   0x4004  mtimecmp  hi (32b)
--   0xBFF8  mtime     lo (32b, RO por bus; avanza con tick)
--   0xBFFC  mtime     hi (32b, RO por bus)
-- Genera mtip = (mtime >= mtimecmp) y msip = msip_reg(0).
-- Bus: AXI-Lite-like single-beat sincrono; rdata combinacional
-- (mux directo) segun el contrato de la familia. mtime avanza
-- un paso cada pulso 'tick' (el SoC lo genera con prescaler).
-- Contrato: escritura y lectura no requieren wait states aqui;
-- ready es siempre '1' cuando req='1' (bloque interno rapido).
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32_clint is
  port (
    clk     : in  std_logic;
    rstn    : in  std_logic;
    tick    : in  std_logic;   -- pulso: incrementa mtime
    -- bus tipo AXI-Lite single-beat
    req     : in  std_logic;
    we      : in  std_logic;
    addr    : in  std_logic_vector(15 downto 0); -- offset dentro del CLINT
    wdata   : in  std_logic_vector(31 downto 0);
    rdata   : out std_logic_vector(31 downto 0);
    ready   : out std_logic;
    -- lineas de interrupcion hacia la unidad de traps
    mtip    : out std_logic;
    msip    : out std_logic
  );
end entity;

architecture rtl of rv32_clint is
  signal r_msip     : std_logic;
  signal r_mtimecmp : unsigned(63 downto 0);
  signal r_mtime    : unsigned(63 downto 0);
  signal s_rdata    : std_logic_vector(31 downto 0);
begin

  ready <= '1';

  -- lectura combinacional (mux directo; contrato de la familia)
  process(addr, r_msip, r_mtimecmp, r_mtime)
  begin
    case addr is
      when x"0000" =>
        s_rdata <= (0 => r_msip, others => '0');
      when x"4000" =>
        s_rdata <= std_logic_vector(r_mtimecmp(31 downto 0));
      when x"4004" =>
        s_rdata <= std_logic_vector(r_mtimecmp(63 downto 32));
      when x"BFF8" =>
        s_rdata <= std_logic_vector(r_mtime(31 downto 0));
      when x"BFFC" =>
        s_rdata <= std_logic_vector(r_mtime(63 downto 32));
      when others =>
        s_rdata <= (others => '0');
    end case;
  end process;
  rdata <= s_rdata;

  -- mtip / msip combinacionales
  mtip <= '1' when (rstn = '1' and r_mtime >= r_mtimecmp) else '0'; -- MUT1
  msip <= r_msip;

  process(clk, rstn)
  begin
    if rstn = '0' then
      r_msip     <= '0';
      r_mtimecmp <= (others => '1'); -- MUT4: reset all-ones evita MTI espurio
      r_mtime    <= (others => '0');
    elsif rising_edge(clk) then
      if tick = '1' then
        r_mtime <= r_mtime + 1; -- MUT2
      end if;
      if req = '1' and we = '1' then
        case addr is
          when x"0000" => r_msip <= wdata(0);
          when x"4000" => r_mtimecmp(31 downto 0)  <= unsigned(wdata);
          when x"4004" => r_mtimecmp(63 downto 32) <= unsigned(wdata);
          when x"BFF8" => r_mtime(31 downto 0)  <= unsigned(wdata); -- MUT3
          when x"BFFC" => r_mtime(63 downto 32) <= unsigned(wdata);
          when others  => null;
        end case;
      end if;
    end if;
  end process;

end architecture;
