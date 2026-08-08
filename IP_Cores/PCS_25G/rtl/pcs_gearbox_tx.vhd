-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Gearbox TX: adapta bloques de 66 bits a palabras de 64 bits (relacion 32:33).
--
-- Modelo de referencia (pcs_gearbox_oracle.py, TxGearbox): un buffer FIFO de
-- bits en el que se empujan 66 bits por bloque (LSB primero) y del que se
-- extraen 64 bits por palabra cuando hay >= 64 disponibles.
--
-- Implementacion hardware: buffer de desplazamiento de ancho fijo (130 bits,
-- suficiente para 66 + 64) + contador de ocupacion 'fill'. No es una lista
-- dinamica: los bits se acumulan en la parte baja del buffer y se extraen los
-- 64 mas bajos.
--
-- Protocolo:
--   * in_valid/in_block: cuando in_valid='1', se empujan 66 bits al buffer.
--     in_ready indica que el gearbox puede aceptar un bloque (fill <= 64).
--   * out_valid/out_word: cuando fill >= 64, se emite una palabra de 64 bits
--     y fill decrece en 64. out_valid='1' ese ciclo.
--
-- Con la relacion 32:33, de cada 32 bloques empujados salen 33 palabras. El
-- contador de fill oscila y nunca desborda 130 si se respeta in_ready.
--
-- Verificado contra el oraculo (firma FNV32 0x992EEDDE) via round-trip con el
-- gearbox RX.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_gearbox_tx is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    -- entrada de bloques de 66 bits
    in_valid  : in  std_logic;
    in_block  : in  std_logic_vector(65 downto 0);
    in_ready  : out std_logic;
    -- salida de palabras de 64 bits
    out_valid : out std_logic;
    out_word  : out std_logic_vector(63 downto 0)
  );
end entity pcs_gearbox_tx;

architecture rtl of pcs_gearbox_tx is
  constant BUFW : natural := 130;  -- 66 + 64 = 130, margen para no desbordar
  signal buf    : std_logic_vector(BUFW-1 downto 0) := (others => '0');
  signal fill   : integer range 0 to BUFW := 0;   -- bits validos en buf(fill-1 downto 0)
  signal outw_r : std_logic_vector(63 downto 0) := (others => '0');
  signal outv_r : std_logic := '0';
begin

  -- puede aceptar un bloque si tras empujarlo no desborda: fill + 66 <= BUFW
  in_ready <= '1' when fill <= (BUFW - 66) else '0';

  process(clk)
    variable v_fill : integer range 0 to BUFW;
    variable v_buf  : std_logic_vector(BUFW-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        buf    <= (others => '0');
        fill   <= 0;
        outw_r <= (others => '0');
        outv_r <= '0';
      else
        v_fill := fill;
        v_buf  := buf;

        -- 1. empujar bloque de 66 bits (LSB primero) en la posicion 'fill'
        if in_valid = '1' and v_fill <= (BUFW - 66) then
          for i in 0 to 65 loop
            v_buf(v_fill + i) := in_block(i);
          end loop;
          v_fill := v_fill + 66;
        end if;

        -- 2. si hay >= 64 bits, extraer los 64 mas bajos como palabra
        if v_fill >= 64 then
          outw_r <= v_buf(63 downto 0);
          outv_r <= '1';
          -- desplazar el buffer 64 posiciones hacia abajo
          v_buf(BUFW-1-64 downto 0) := v_buf(BUFW-1 downto 64);
          v_buf(BUFW-1 downto BUFW-64) := (others => '0');
          v_fill := v_fill - 64;
        else
          outv_r <= '0';
        end if;

        buf  <= v_buf;
        fill <= v_fill;
      end if;
    end if;
  end process;

  out_valid <= outv_r;
  out_word  <= outw_r;

end architecture rtl;
