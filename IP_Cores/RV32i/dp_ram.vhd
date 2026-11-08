-- =============================================================================
--  dp_ram.vhd  -  RAM de doble acceso (CPU + AXI/PS) para el SoC del TE0950
--  Licencia: MIT
--
--  Lectura ASINCRONA en ambos puertos (se infiere como distributed RAM/LUTRAM),
--  compatible con el core single-cycle. Un solo puerto de escritura, arbitrado
--  por 'axi_owns':
--    * axi_owns = '1' (core en reset): el lado AXI/PS escribe.
--    * axi_owns = '0' (core corriendo): el core escribe.
--  Precarga opcional desde archivo hex via INIT_FILE (mismo formato .mem que
--  usa el ensamblador; sirve para simulacion y para init de RAM en sintesis).
--
--  audit-2026-11: SYNC_READ generic.
--    SYNC_READ = false (default): legacy asynchronous read (LUTRAM on FPGA).
--      Kept for the many existing SoCs that pair it with a same-cycle core.
--    SYNC_READ = true : both read ports are registered (1-cycle synchronous
--      read, read-first on a same-address write). This is the behaviour of an
--      SRAM macro and of FPGA block RAM, and is the mode to use for ASIC
--      (IHP SG13G2 / sky130): replace this behavioural array by the 2-port
--      macro with the same latency. Pair it with cpu_pipeline IMEM_SYNC /
--      DMEM_SYNC and axil_soc MEM_SYNC.
--  INIT_FILE (textio) is a simulation / FPGA-bitstream convenience only: an
--  ASIC SRAM powers up undefined, so ASIC builds must leave INIT_FILE = "" and
--  load the program through the AXI port (host via axil_soc, or the
--  boot_loader from the boot ROM package).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

use work.riscv_pkg.all;

entity dp_ram is
  generic (
    DEPTH     : natural := 256;
    INIT_FILE : string  := "";     -- "" = sin precarga (simulation / FPGA only)
    SYNC_READ : boolean := false   -- true: 1-cycle synchronous read (SRAM / BRAM)
  );
  port (
    clk       : in  std_logic;
    -- puerto CPU
    cpu_addr  : in  word_t;
    cpu_wdata : in  word_t;
    cpu_wstrb : in  std_logic_vector(3 downto 0);
    cpu_rdata : out word_t;
    -- puerto AXI / PS
    axi_addr  : in  word_t;
    axi_wdata : in  word_t;
    axi_wstrb : in  std_logic_vector(3 downto 0);
    axi_rdata : out word_t;
    -- arbitraje de escritura
    axi_owns  : in  std_logic
  );
end entity dp_ram;

architecture rtl of dp_ram is
  type mem_t is array (0 to DEPTH-1) of word_t;

  impure function load(fn : string) return mem_t is
    file     f : text;
    variable l : line;
    variable w : word_t;
    variable m : mem_t := (others => (others => '0'));
    variable i : natural := 0;
    variable status : file_open_status;
  begin
    if fn = "" then return m; end if;
    file_open(status, f, fn, read_mode);
    if status /= open_ok then return m; end if;
    while not endfile(f) and i < DEPTH loop
      readline(f, l);
      if l'length > 0 then hread(l, w); m(i) := w; i := i + 1; end if;
    end loop;
    file_close(f);
    return m;
  end function;

  signal mem : mem_t := load(INIT_FILE);

  constant IDX_HI : natural := 1 + integer(ceil(log2(real(DEPTH))));
  signal cpu_idx, axi_idx : natural range 0 to DEPTH-1;
begin
  cpu_idx <= to_integer(unsigned(cpu_addr(IDX_HI downto 2)));
  axi_idx <= to_integer(unsigned(axi_addr(IDX_HI downto 2)));

  process(clk)
  begin
    if rising_edge(clk) then
      if axi_owns = '1' then
        for b in 0 to 3 loop
          if axi_wstrb(b) = '1' then
            mem(axi_idx)(b*8+7 downto b*8) <= axi_wdata(b*8+7 downto b*8);
          end if;
        end loop;
      else
        for b in 0 to 3 loop
          if cpu_wstrb(b) = '1' then
            mem(cpu_idx)(b*8+7 downto b*8) <= cpu_wdata(b*8+7 downto b*8);
          end if;
        end loop;
      end if;
    end if;
  end process;

  g_async : if not SYNC_READ generate
    cpu_rdata <= mem(cpu_idx);
    axi_rdata <= mem(axi_idx);
  end generate;

  g_sync : if SYNC_READ generate
    -- registered read ports; the write process above updates 'mem' on the
    -- same edge, so a read of the address being written returns the OLD
    -- word (read-first), like a typical SRAM macro / BRAM in READ_FIRST mode
    process(clk)
    begin
      if rising_edge(clk) then
        cpu_rdata <= mem(cpu_idx);
        axi_rdata <= mem(axi_idx);
      end if;
    end process;
  end generate;
end architecture rtl;
