-- =============================================================================
--  byte_fifo.vhd  -  FIFO sincrono de bytes, lectura FWFT (first-word-fall-
--                    through: rd_data siempre muestra la cabeza sin latencia)
--  Licencia: MIT
--
--  La lectura combinacional de la cabeza permite que un registro MMIO tipo
--  RXDATA presente el dato en el mismo ciclo del acceso y el pop (rd_en)
--  avance el puntero en el flanco. Push y pop simultaneos soportados.
--  Con LOG2_DEPTH chico (<= 8) infiere LUTRAM, suficiente para este IP.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity byte_fifo is
  generic (
    LOG2_DEPTH : natural := 8            -- 2**8 = 256 bytes
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;

    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(7 downto 0);
    full    : out std_logic;

    rd_en   : in  std_logic;
    rd_data : out std_logic_vector(7 downto 0);
    empty   : out std_logic;

    level   : out unsigned(LOG2_DEPTH downto 0)
  );
end entity byte_fifo;

architecture rtl of byte_fifo is
  constant DEPTH : natural := 2**LOG2_DEPTH;
  type mem_t is array (0 to DEPTH-1) of std_logic_vector(7 downto 0);
  signal mem : mem_t := (others => (others => '0'));

  signal wp, rp : unsigned(LOG2_DEPTH-1 downto 0) := (others => '0');
  signal cnt    : unsigned(LOG2_DEPTH downto 0)   := (others => '0');
begin

  full    <= '1' when cnt = DEPTH else '0';
  empty   <= '1' when cnt = 0     else '0';
  level   <= cnt;
  rd_data <= mem(to_integer(rp));        -- cabeza siempre visible (FWFT)

  process(clk)
    variable v_push, v_pop : boolean;
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        wp  <= (others => '0');
        rp  <= (others => '0');
        cnt <= (others => '0');
      else
        v_push := (wr_en = '1') and (cnt /= DEPTH);
        v_pop  := (rd_en = '1') and (cnt /= 0);

        if v_push then
          mem(to_integer(wp)) <= wr_data;
          wp <= wp + 1;
        end if;
        if v_pop then
          rp <= rp + 1;
        end if;

        if v_push and not v_pop then
          cnt <= cnt + 1;
        elsif v_pop and not v_push then
          cnt <= cnt - 1;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
