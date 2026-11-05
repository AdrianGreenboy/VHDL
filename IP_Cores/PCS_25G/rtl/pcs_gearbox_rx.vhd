-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Gearbox RX: adapta palabras de 64 bits a bloques de 66 bits (inverso del TX).
--
-- Modelo de referencia (pcs_gearbox_oracle.py, RxGearbox): acumula palabras de
-- 64 bits en un buffer FIFO de bits y extrae bloques de 66 bits cuando hay >=66.
--
-- Alignment acquisition (audit 2026-11, fix A3): the gearbox no longer
-- assumes a known 66-bit alignment. A 1-cycle pulse on 'slip' discards ONE
-- bit from the head of the bit buffer, shifting every following block
-- boundary by one bit. The clause-49 block-sync state machine
-- (pcs_blocksync, in pcs_rx_datapath) issues the slips until 64 valid sync
-- headers are seen, so any bit offset (0..65) of the incoming 64-bit word
-- stream is acquired after at most 65 slips.
--
-- Verificado contra el oraculo via round-trip con el gearbox TX.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_gearbox_rx is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    -- entrada de palabras de 64 bits
    in_valid  : in  std_logic;
    in_word   : in  std_logic_vector(63 downto 0);
    in_ready  : out std_logic;
    -- block alignment: 1-cycle pulse drops one bit (bit slip)
    slip      : in  std_logic := '0';
    -- salida de bloques de 66 bits
    -- sticky: an input arrived while the buffer had no room and was DROPPED
    -- (in_ready not honoured by the source); audit 2026-11, fix B6
    overflow  : out std_logic;
    out_valid : out std_logic;
    out_block : out std_logic_vector(65 downto 0)
  );
end entity pcs_gearbox_rx;

architecture rtl of pcs_gearbox_rx is
  constant BUFW : natural := 132;  -- 64 + 66 = 130, margen
  signal buf    : std_logic_vector(BUFW-1 downto 0) := (others => '0');
  signal fill   : integer range 0 to BUFW := 0;
  signal outb_r : std_logic_vector(65 downto 0) := (others => '0');
  signal outv_r : std_logic := '0';
  signal ovf_r  : std_logic := '0';
begin

  in_ready <= '1' when fill <= (BUFW - 64) else '0';

  process(clk)
    variable v_fill : integer range 0 to BUFW;
    variable v_buf  : std_logic_vector(BUFW-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        buf    <= (others => '0');
        fill   <= 0;
        outb_r <= (others => '0');
        outv_r <= '0';
        ovf_r  <= '0';
      else
        v_fill := fill;
        if in_valid = '1' and v_fill > (BUFW - 64) then
          ovf_r <= '1';                -- input dropped: never silently
        end if;
        v_buf  := buf;

        -- 1. empujar palabra de 64 bits en la posicion 'fill'
        if in_valid = '1' and v_fill <= (BUFW - 64) then
          for i in 0 to 63 loop
            v_buf(v_fill + i) := in_word(i);
          end loop;
          v_fill := v_fill + 64;
        end if;

        -- 1b. bit slip: drop the oldest buffered bit
        if slip = '1' and v_fill >= 1 then
          v_buf(BUFW-2 downto 0) := v_buf(BUFW-1 downto 1);
          v_buf(BUFW-1) := '0';
          v_fill := v_fill - 1;
        end if;

        -- 2. si hay >= 66 bits, extraer un bloque de 66
        if v_fill >= 66 then
          outb_r <= v_buf(65 downto 0);
          outv_r <= '1';
          v_buf(BUFW-1-66 downto 0) := v_buf(BUFW-1 downto 66);
          v_buf(BUFW-1 downto BUFW-66) := (others => '0');
          v_fill := v_fill - 66;
        else
          outv_r <= '0';
        end if;

        buf  <= v_buf;
        fill <= v_fill;
      end if;
    end if;
  end process;

  out_valid <= outv_r;
  overflow  <= ovf_r;

  -- pragma translate_off
  process(clk)
  begin
    if rising_edge(clk) then
      assert not (rst = '0' and in_valid = '1' and fill > (BUFW - 64))
        report "pcs_gearbox_rx: input dropped, buffer full (in_ready ignored)" severity error;
    end if;
  end process;
  -- pragma translate_on
  out_block <= outb_r;

end architecture rtl;
