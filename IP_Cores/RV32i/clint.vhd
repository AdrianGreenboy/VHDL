-- =============================================================================
--  clint.vhd  -  Core-Local Interruptor (timer + software interrupt)
--  Licencia: MIT
--
--  Registros mapeados en memoria (offset dentro del CLINT):
--    0x0000  msip       (bit 0 = software interrupt pending)
--    0x4000  mtimecmp   low  32 bits
--    0x4004  mtimecmp   high 32 bits
--    0xBFF8  mtime      low  32 bits (solo lectura)
--    0xBFFC  mtime      high 32 bits (solo lectura)
--
--  mtime se incrementa cada ciclo (timer rapido para simulacion). La linea
--  timer_irq se activa cuando mtime >= mtimecmp; soft_irq = msip(0).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity clint is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    sel   : in  std_logic;                       -- acceso dirigido al CLINT
    we    : in  std_logic;                        -- store
    addr  : in  std_logic_vector(15 downto 0);    -- offset dentro del CLINT
    wdata : in  word_t;
    rdata : out word_t;
    timer_irq : out std_logic;
    soft_irq  : out std_logic
  );
end entity clint;

architecture rtl of clint is
  signal mtime    : unsigned(63 downto 0) := (others => '0');
  signal mtimecmp : unsigned(63 downto 0) := (others => '1');  -- max -> sin irq al inicio
  signal msip     : std_logic := '0';
begin

  timer_irq <= '1' when mtime >= mtimecmp else '0';
  soft_irq  <= msip;

  -- lectura
  process(addr, msip, mtime, mtimecmp)
  begin
    case addr is
      when x"0000" => rdata <= (0 => msip, others => '0');
      when x"4000" => rdata <= std_logic_vector(mtimecmp(31 downto 0));
      when x"4004" => rdata <= std_logic_vector(mtimecmp(63 downto 32));
      when x"BFF8" => rdata <= std_logic_vector(mtime(31 downto 0));
      when x"BFFC" => rdata <= std_logic_vector(mtime(63 downto 32));
      when others  => rdata <= (others => '0');
    end case;
  end process;

  -- mtime corre libre; escrituras a msip / mtimecmp
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mtime    <= (others => '0');
        mtimecmp <= (others => '1');
        msip     <= '0';
      else
        mtime <= mtime + 1;
        if sel = '1' and we = '1' then
          case addr is
            when x"0000" => msip <= wdata(0);
            when x"4000" => mtimecmp(31 downto 0)  <= unsigned(wdata);
            when x"4004" => mtimecmp(63 downto 32) <= unsigned(wdata);
            when others  => null;   -- mtime es solo lectura
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
