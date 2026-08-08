-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Datapath PCS RX completo: gearbox RX + split 66b + descrambler + decoder.
--
-- Inverso exacto del TX datapath:
--   palabras del PMA
--     -> gearbox RX (64 -> 66)
--     -> split: sync = block(1:0), payload_scrambleado = block(65:2)
--     -> descrambler: descramblea el payload (sync NO entra)
--     -> decoder: is_data = (sync == 01)
--
-- El sync se retrasa 1 ciclo para alinearse con la salida del descrambler
-- (1 ciclo de latencia), igual que en el TX.
--
-- Verificado contra pcs_datapath_oracle.py via round-trip end-to-end.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_rx_datapath is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- entrada de palabras de 64 bits desde el PMA
    in_valid   : in  std_logic;
    in_word    : in  std_logic_vector(63 downto 0);
    in_ready   : out std_logic;
    -- salida de payload + tipo recuperados
    out_valid  : out std_logic;
    out_payload: out std_logic_vector(63 downto 0);
    out_is_data: out std_logic
  );
end entity pcs_rx_datapath;

architecture rtl of pcs_rx_datapath is
  -- gearbox RX
  signal gb_out_valid : std_logic;
  signal gb_out_block : std_logic_vector(65 downto 0);
  -- descrambler
  signal des_en    : std_logic;
  signal des_din   : std_logic_vector(63 downto 0);
  signal des_dout  : std_logic_vector(63 downto 0);
  signal des_valid : std_logic;
  -- sync retrasado 1 ciclo para casar con la salida del descrambler
  signal sync_d1   : std_logic_vector(1 downto 0) := (others => '0');
begin

  -- gearbox RX
  u_gb: entity work.pcs_gearbox_rx
    port map (clk=>clk, rst=>rst, in_valid=>in_valid, in_word=>in_word,
              in_ready=>in_ready, out_valid=>gb_out_valid, out_block=>gb_out_block);

  -- split del bloque 66b y alimentacion al descrambler
  des_en  <= gb_out_valid;
  des_din <= gb_out_block(65 downto 2);   -- payload scrambleado

  -- instancia descrambler en modo descramble (mode='1')
  u_des: entity work.pcs_scrambler
    port map (clk=>clk, rst=>rst, en=>des_en, mode=>'1',
              din=>des_din, dout=>des_dout, dvalid=>des_valid);

  -- retrasar el sync 1 ciclo para casar con des_dout
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sync_d1 <= (others => '0');
      elsif des_en = '1' then
        sync_d1 <= gb_out_block(1 downto 0);
      end if;
    end if;
  end process;

  out_valid   <= des_valid;
  out_payload <= des_dout;
  out_is_data <= '1' when sync_d1 = "01" else '0';

end architecture rtl;
