-- word_fifo.vhd - FIFO sincrona de palabras de 32 bits, molde canonico de la
-- familia (mismo contrato que byte_fifo pero ancho 32). rd_data es el frente
-- de forma COMBINACIONAL (mux del arreglo por puntero de lectura), de modo que
-- un banco MMIO con rdata combinacional puede exponer rd_data sin ciclo extra.
-- El pop efectivo (avance de rd_ptr) ocurre en el flanco cuando rd_en='1' y no
-- esta vacia. Push analogo con wr_en. Reset asincrono activo bajo.
-- level : unsigned(LOG2_DEPTH downto 0) cuenta ocupacion (0..DEPTH).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity word_fifo is
  generic (
    LOG2_DEPTH : natural := 9  -- DEPTH = 512
  );
  port (
    clk       : in  std_logic;
    aresetn   : in  std_logic;
    wr_en     : in  std_logic;
    wr_data   : in  std_logic_vector(31 downto 0);
    full      : out std_logic;
    rd_en     : in  std_logic;
    rd_data   : out std_logic_vector(31 downto 0);
    empty     : out std_logic;
    level     : out unsigned(LOG2_DEPTH downto 0)
  );
end entity word_fifo;

architecture rtl of word_fifo is
  constant DEPTH : natural := 2 ** LOG2_DEPTH;
  type t_mem is array (0 to DEPTH - 1) of std_logic_vector(31 downto 0);
  signal mem_r  : t_mem := (others => (others => '0'));
  signal wr_ptr : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal rd_ptr : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal lvl_r  : unsigned(LOG2_DEPTH downto 0) := (others => '0');
  signal empty_s, full_s : std_logic;
begin

  empty_s <= '1' when lvl_r = 0 else '0';
  full_s  <= '1' when lvl_r = DEPTH else '0';
  empty   <= empty_s;
  full    <= full_s;
  level   <= lvl_r;
  -- frente combinacional: valido solo si no esta vacia (si vacia, se lee 0)
  rd_data <= mem_r(to_integer(rd_ptr)) when empty_s = '0'
             else (others => '0');

  proc_fifo : process (clk, aresetn)
    variable do_wr, do_rd : boolean;
  begin
    if aresetn = '0' then
      wr_ptr <= (others => '0');
      rd_ptr <= (others => '0');
      lvl_r  <= (others => '0');
    elsif rising_edge(clk) then
      do_wr := (wr_en = '1') and (full_s = '0');
      do_rd := (rd_en = '1') and (empty_s = '0');
      if do_wr then
        mem_r(to_integer(wr_ptr)) <= wr_data;
        wr_ptr <= wr_ptr + 1;
      end if;
      if do_rd then
        rd_ptr <= rd_ptr + 1;
      end if;
      if do_wr and not do_rd then
        lvl_r <= lvl_r + 1;
      elsif do_rd and not do_wr then
        lvl_r <= lvl_r - 1;
      end if;
    end if;
  end process proc_fifo;

end architecture rtl;
