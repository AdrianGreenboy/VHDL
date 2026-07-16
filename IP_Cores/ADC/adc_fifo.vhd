-- ============================================================================
-- adc_fifo.vhd : FIFO de muestras del ADC delta-sigma soft IP v1
-- Almacenamiento en BRAM 512x32 con molde SDP canonico (un puerto de
-- escritura sincrona, un puerto de lectura sincrona con enable) + etapa de
-- salida FWFT de 2 registros (rd_word, head). El head esta siempre
-- disponible en rd_data cuando empty='0', lo que permite que el banco MMIO
-- presente FIFO_DATA con rdata COMBINACIONAL (contrato dmem de la familia).
-- Capacidad total: 512 (BRAM) + 2 (etapas) = 514 palabras.
-- rst sincrono activo alto (convencion del banco de registros).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_fifo is
  generic (
    LOG2_DEPTH : natural := 9  -- 512 palabras de BRAM
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(31 downto 0);
    rd_en   : in  std_logic;   -- pop del head (ignorado si empty)
    rd_data : out std_logic_vector(31 downto 0);
    empty   : out std_logic;
    full    : out std_logic;
    level   : out unsigned(LOG2_DEPTH + 1 downto 0)
  );
end entity adc_fifo;

architecture rtl of adc_fifo is
  constant C_DEPTH : natural := 2**LOG2_DEPTH;

  type ram_t is array (0 to C_DEPTH - 1) of std_logic_vector(31 downto 0);
  signal buf : ram_t;
  attribute ram_style : string;
  attribute ram_style of buf : signal is "block";

  signal wr_ptr  : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal rd_ptr  : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal cnt_ram : unsigned(LOG2_DEPTH downto 0) := (others => '0');  -- 0..512

  signal rd_word : std_logic_vector(31 downto 0) := (others => '0');
  signal head    : std_logic_vector(31 downto 0) := (others => '0');
  signal rv      : std_logic := '0';  -- rd_word valido
  signal hv      : std_logic := '0';  -- head valido

  signal full_i  : std_logic;
  signal pop     : std_logic;
  signal adv_h   : std_logic;
  signal adv_r   : std_logic;
  signal wr_ok   : std_logic;
begin

  full_i <= '1' when cnt_ram = to_unsigned(C_DEPTH, cnt_ram'length) else '0';
  pop    <= rd_en and hv;
  adv_h  <= rv and ((not hv) or pop);
  adv_r  <= '1' when (cnt_ram /= 0) and ((rv = '0') or (adv_h = '1')) else '0';
  wr_ok  <= wr_en and (not full_i);

  proc_fifo : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_ptr  <= (others => '0');
        rd_ptr  <= (others => '0');
        cnt_ram <= (others => '0');
        rv      <= '0';
        hv      <= '0';
      else
        -- puerto de escritura sincrona (molde SDP)
        if wr_ok = '1' then
          buf(to_integer(wr_ptr)) <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end if;
        -- puerto de lectura sincrona con enable (molde SDP)
        if adv_r = '1' then
          rd_word <= buf(to_integer(rd_ptr));
          rd_ptr  <= rd_ptr + 1;
        end if;
        if (wr_ok = '1') and (adv_r = '0') then
          cnt_ram <= cnt_ram + 1;
        elsif (wr_ok = '0') and (adv_r = '1') then
          cnt_ram <= cnt_ram - 1;
        end if;
        rv <= adv_r or (rv and (not adv_h));
        if adv_h = '1' then
          head <= rd_word;
        end if;
        hv <= adv_h or (hv and (not pop));
      end if;
    end if;
  end process proc_fifo;

  rd_data <= head;
  empty   <= not hv;
  full    <= full_i;

  proc_level : process (all)
    variable v : unsigned(level'length - 1 downto 0);
  begin
    v := resize(cnt_ram, level'length);
    if rv = '1' then
      v := v + 1;
    end if;
    if hv = '1' then
      v := v + 1;
    end if;
    level <= v;
  end process proc_level;

end architecture rtl;
