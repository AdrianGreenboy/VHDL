-- tsn_fifo.vhd - FIFO FWFT de bytes con puntero de commit y rewind
-- Familia VHDL-2008 / RV32IM SoC v3. Derivada del patron byte_fifo FWFT canonico.
--
-- Contrato:
--   * Escritura especulativa: wr_en carga bytes que ocupan espacio pero NO son
--     visibles al lector hasta commit.
--   * commit (pulso 1 ciclo): consolida todo lo especulativo (cm_ptr := wr_ptr).
--   * rewind (pulso 1 ciclo): descarta todo lo especulativo (wr_ptr := cm_ptr).
--   * commit/rewind NUNCA coinciden con wr_en ni entre si (assert en sim).
--   * full considera bytes especulativos (reservan espacio).
--   * Lectura FWFT: rd_valid=1 => rd_data contiene el byte en cabeza;
--     rd_en consume. Solo se leen bytes consolidados.
--   * Lectura RE-LEIBLE (multicast secuencial): los bytes leidos NO liberan
--     espacio hasta rd_commit. rd_rewind vuelve al inicio de la trama en
--     drenaje (frontera fr_ptr) para re-leerla hacia otro destino.
--     rd_commit/rd_rewind nunca coinciden con rd_en (assert en sim).
--   * spec_count/comm_count expuestos para el wrapper de ingreso.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tsn_fifo is
  generic (
    LOG2_DEPTH : natural := 11        -- 2048 bytes por puerto (leccion ETH)
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;       -- sincrono, activo alto
    -- escritura especulativa
    wr_en      : in  std_logic;
    wr_data    : in  std_logic_vector(7 downto 0);
    commit     : in  std_logic;
    rewind     : in  std_logic;
    full       : out std_logic;
    -- lectura FWFT (solo consolidado)
    rd_en      : in  std_logic;
    rd_data    : out std_logic_vector(7 downto 0);
    rd_valid   : out std_logic;
    rd_commit  : in  std_logic;   -- libera lo leido (fin de todas las entregas)
    rd_rewind  : in  std_logic;   -- re-lee desde la frontera liberada
    -- observabilidad
    spec_count : out unsigned(LOG2_DEPTH downto 0);
    comm_count : out unsigned(LOG2_DEPTH downto 0)
  );
end entity;

architecture rtl of tsn_fifo is
  constant DEPTH : natural := 2**LOG2_DEPTH;

  type ram_t is array (0 to DEPTH-1) of std_logic_vector(7 downto 0);
  signal ram : ram_t;
  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";

  -- punteros con bit extra para distinguir lleno/vacio
  -- fr_ptr: frontera liberada (solo avanza en rd_commit); rd_ptr puede
  -- retroceder a fr_ptr en rd_rewind para re-lectura multicast
  signal wr_ptr, cm_ptr, rd_ptr, fr_ptr : unsigned(LOG2_DEPTH downto 0) := (others => '0');

  signal out_valid : std_logic := '0';
  signal spec_cnt_i, comm_cnt_i : unsigned(LOG2_DEPTH downto 0);
  signal fetch : std_logic;
begin
  spec_cnt_i <= wr_ptr - fr_ptr;
  comm_cnt_i <= cm_ptr - rd_ptr;
  spec_count <= spec_cnt_i;
  comm_count <= comm_cnt_i;
  full       <= '1' when spec_cnt_i = to_unsigned(DEPTH, LOG2_DEPTH+1) else '0';

  -- prefetch FWFT: cargar salida si esta vacia o se consume, y hay consolidado
  fetch <= '1' when (out_valid = '0' or rd_en = '1') and comm_cnt_i /= 0
                and rd_commit = '0' and rd_rewind = '0' else '0';

  p_wr : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_ptr <= (others => '0');
        cm_ptr <= (others => '0');
      else
        assert not (commit = '1' and rewind = '1')
          report "tsn_fifo: commit y rewind simultaneos prohibidos" severity failure;
        assert not ((commit = '1' or rewind = '1') and wr_en = '1')
          report "tsn_fifo: commit/rewind simultaneo con wr_en prohibido" severity failure;
        if wr_en = '1' and spec_cnt_i /= to_unsigned(DEPTH, LOG2_DEPTH+1) then
          ram(to_integer(wr_ptr(LOG2_DEPTH-1 downto 0))) <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end if;
        if commit = '1' then
          cm_ptr <= wr_ptr;
        elsif rewind = '1' then
          wr_ptr <= cm_ptr;
        end if;
      end if;
    end if;
  end process;

  p_rd : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rd_ptr    <= (others => '0');
        fr_ptr    <= (others => '0');
        out_valid <= '0';
      else
        assert not ((rd_commit = '1' or rd_rewind = '1') and rd_en = '1')
          report "tsn_fifo: rd_commit/rd_rewind simultaneo con rd_en prohibido"
          severity failure;
        assert not (rd_commit = '1' and rd_rewind = '1')
          report "tsn_fifo: rd_commit y rd_rewind simultaneos prohibidos"
          severity failure;
        if rd_commit = '1' then
          -- descontar el prefetch no consumido: el byte en el registro de
          -- salida pertenece al flujo posterior y debe re-leerse
          if out_valid = '1' then
            rd_ptr <= rd_ptr - 1;
            fr_ptr <= rd_ptr - 1;
          else
            fr_ptr <= rd_ptr;
          end if;
          out_valid <= '0';
        elsif rd_rewind = '1' then
          rd_ptr    <= fr_ptr;
          out_valid <= '0';
        elsif fetch = '1' then
          rd_data   <= ram(to_integer(rd_ptr(LOG2_DEPTH-1 downto 0)));
          rd_ptr    <= rd_ptr + 1;
          out_valid <= '1';
        elsif rd_en = '1' and out_valid = '1' then
          out_valid <= '0';
        end if;
      end if;
    end if;
  end process;

  rd_valid <= out_valid;
end architecture;
