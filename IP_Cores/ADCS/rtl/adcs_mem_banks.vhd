-- ============================================================================
-- adcs_mem_banks.vhd — Bancos de memoria del IP ADCS (port de adcs_mem_banks.sv).
--   h_bank : 72x70 float32, lectura de FILA COMPLETA (latencia 1).
--   g_bank : vector g[72], 1 palabra por acceso (latencia 1).
--   u_bank : vector U[72] RW + espejo en registros + SNAPSHOT ancho u_vec
--            refrescado solo por snap_tick (update en BLOQUE, Jacobi) +
--            puerto externo de lectura (registrado cada ciclo).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;

entity h_bank is
  port (
    clk      : in  std_logic;
    wr_en    : in  std_logic;
    wr_row   : in  std_logic_vector(IDX_W-1 downto 0);
    wr_col   : in  std_logic_vector(IDX_W-1 downto 0);
    wr_data  : in  std_logic_vector(FP_W-1 downto 0);
    rd_en    : in  std_logic;
    rd_row   : in  std_logic_vector(IDX_W-1 downto 0);
    row_data : out std_logic_vector(D*FP_W-1 downto 0)
  );
end entity h_bank;

architecture rtl of h_bank is
  -- PARTICION POR COLUMNAS (para inferencia de BRAM): en vez de una memoria 2D
  -- leida con D puertos simultaneos (que fuerza LUTRAM), se organiza como D
  -- memorias independientes de DP palabras, una por columna. Cada una tiene UN
  -- puerto de escritura y UN puerto de lectura registrada => inferible como
  -- BRAM/LUTRAM de doble puerto simple. La lectura de fila completa lee las D
  -- columnas en paralelo (son memorias fisicas distintas). Interfaz y timing
  -- (latencia 1) IDENTICOS al 2D original: no cambia la firma de simulacion.
  type col_t is array (0 to DP-1) of std_logic_vector(FP_W-1 downto 0);
  type cols_t is array (0 to D-1) of col_t;
  signal cols : cols_t;
  attribute ram_style : string;
  attribute ram_style of cols : signal is "block";
begin
  gen_col : for c in 0 to D-1 generate
    process (clk)
    begin
      if rising_edge(clk) then
        if wr_en = '1' and to_integer(unsigned(wr_col)) = c
           and unsigned(wr_row) < DP then
          cols(c)(to_integer(unsigned(wr_row))) <= wr_data;
        end if;
        if rd_en = '1' then
          row_data((c+1)*FP_W-1 downto c*FP_W)
            <= cols(c)(to_integer(unsigned(rd_row)));
        end if;
      end if;
    end process;
  end generate;
end architecture rtl;

-- ----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;

entity g_bank is
  port (
    clk     : in  std_logic;
    wr_en   : in  std_logic;
    wr_addr : in  std_logic_vector(IDX_W-1 downto 0);
    wr_data : in  std_logic_vector(FP_W-1 downto 0);
    rd_en   : in  std_logic;
    rd_addr : in  std_logic_vector(IDX_W-1 downto 0);
    rd_data : out std_logic_vector(FP_W-1 downto 0)
  );
end entity g_bank;

architecture rtl of g_bank is
  type mem_t is array (0 to DP-1) of std_logic_vector(FP_W-1 downto 0);
  signal mem : mem_t;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if wr_en = '1' then
        mem(to_integer(unsigned(wr_addr))) <= wr_data;
      end if;
      if rd_en = '1' then
        rd_data <= mem(to_integer(unsigned(rd_addr)));
      end if;
    end if;
  end process;
end architecture rtl;

-- ----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;

entity u_bank is
  port (
    clk         : in  std_logic;
    rst_n       : in  std_logic;
    wr_en       : in  std_logic;
    wr_addr     : in  std_logic_vector(IDX_W-1 downto 0);
    wr_data     : in  std_logic_vector(FP_W-1 downto 0);
    rd_en       : in  std_logic;
    rd_addr     : in  std_logic_vector(IDX_W-1 downto 0);
    rd_data     : out std_logic_vector(FP_W-1 downto 0);
    snap_tick   : in  std_logic;
    u_vec       : out std_logic_vector(D*FP_W-1 downto 0);
    ext_rd_addr : in  std_logic_vector(IDX_W-1 downto 0);
    ext_rd_data : out std_logic_vector(FP_W-1 downto 0)
  );
end entity u_bank;

architecture rtl of u_bank is
  type mem_t is array (0 to DP-1) of std_logic_vector(FP_W-1 downto 0);
  type mir_t is array (0 to D-1)  of std_logic_vector(FP_W-1 downto 0);
  signal mem    : mem_t;
  signal mirror : mir_t;
begin

  p_wr : process (clk, rst_n)
  begin
    if rst_n = '0' then
      mirror <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if wr_en = '1' then
        mem(to_integer(unsigned(wr_addr))) <= wr_data;
        if unsigned(wr_addr) < D then
          mirror(to_integer(unsigned(wr_addr))) <= wr_data;
        end if;
      end if;
    end if;
  end process;

  p_rd : process (clk)
  begin
    if rising_edge(clk) then
      if rd_en = '1' then
        rd_data <= mem(to_integer(unsigned(rd_addr)));
      end if;
      ext_rd_data <= mem(to_integer(unsigned(ext_rd_addr)));
    end if;
  end process;

  -- snapshot: u_vec solo cambia en snap_tick => la GEMV de la iteracion ve la
  -- U del INICIO de la iteracion (Jacobi, fiel a solve_mpc_a72)
  p_snap : process (clk, rst_n)
  begin
    if rst_n = '0' then
      u_vec <= (others => '0');
    elsif rising_edge(clk) then
      if snap_tick = '1' then
        for i in 0 to D-1 loop
          u_vec((i+1)*FP_W-1 downto i*FP_W) <= mirror(i);
        end loop;
      end if;
    end if;
  end process;

end architecture rtl;
