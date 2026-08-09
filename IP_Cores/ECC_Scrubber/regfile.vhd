-- =============================================================================
--  regfile.vhd  -  Banco de 32 registros de 32 bits (RV32I)
--  Licencia: MIT
--
--  - x0 cableado a cero.
--  - Lectura asincrona (2 puertos + 1 de depuracion) -> LUTRAM.
--  - Generico BYPASS:
--      * false (default, single-cycle): las lecturas devuelven el estado
--        comprometido. En single-cycle un bypass generaria lazo combinacional.
--      * true  (pipeline): bypass write-first (si se lee y escribe el mismo
--        registro en el mismo ciclo, devuelve wdata). En el pipeline es seguro
--        porque wdata viene registrado desde MEM/WB, y resuelve el hazard
--        WB->ID del mismo ciclo (dependencia a 3 de distancia).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity regfile is
  generic (
    BYPASS : boolean := false
  );
  port (
    clk    : in  std_logic;
    we     : in  std_logic;
    waddr  : in  reg_addr_t;
    wdata  : in  word_t;
    raddr1 : in  reg_addr_t;
    rdata1 : out word_t;
    raddr2 : in  reg_addr_t;
    rdata2 : out word_t;
    raddr3 : in  reg_addr_t := (others => '0');   -- depuracion
    rdata3 : out word_t
  );
end entity regfile;

architecture rtl of regfile is
  type reg_array_t is array (0 to 31) of word_t;
  signal regs : reg_array_t := (others => (others => '0'));
  constant X0 : reg_addr_t := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' and waddr /= X0 then
        regs(to_integer(unsigned(waddr))) <= wdata;
      end if;
    end if;
  end process;

  gen_bypass : if BYPASS generate
    rdata1 <= ZERO_WORD when raddr1 = X0 else
              wdata     when (we = '1' and raddr1 = waddr) else
              regs(to_integer(unsigned(raddr1)));
    rdata2 <= ZERO_WORD when raddr2 = X0 else
              wdata     when (we = '1' and raddr2 = waddr) else
              regs(to_integer(unsigned(raddr2)));
  else generate
    rdata1 <= ZERO_WORD when raddr1 = X0 else regs(to_integer(unsigned(raddr1)));
    rdata2 <= ZERO_WORD when raddr2 = X0 else regs(to_integer(unsigned(raddr2)));
  end generate;

  rdata3 <= ZERO_WORD when raddr3 = X0 else regs(to_integer(unsigned(raddr3)));

end architecture rtl;
