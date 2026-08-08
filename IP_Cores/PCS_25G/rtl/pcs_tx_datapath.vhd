-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Datapath PCS TX completo: encoder + scrambler + ensamblado 66b + gearbox.
--
-- Compone modulos ya verificados:
--   * pcs_scrambler (mode=0): scramblea el payload de 64 bits (1 ciclo latencia)
--   * pcs_gearbox_tx: empaqueta bloques de 66 bits en palabras de 64 (32:33)
--
-- Flujo:
--   payload64 + is_data
--     -> encoder: sync = 01 (data) / 10 (control)
--     -> scrambler: scramblea payload (sync NO entra al scrambler)
--     -> ensamblado: block66 = [sync(2) | payload_scrambleado(64)]
--     -> gearbox TX -> out_word (64 bits al PMA)
--
-- El sync se retrasa 1 ciclo para alinearse con la salida del scrambler
-- (el scrambler tiene 1 ciclo de latencia; el sync debe casar con SU payload).
--
-- Protocolo: in_valid/in_ready para aceptar (payload,is_data); out_valid/out_word
-- hacia el PMA. El gearbox impone in_ready via su propio buffer.
--
-- Verificado contra pcs_datapath_oracle.py (firma FNV32 0xB02ACF27).
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_tx_datapath is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    -- entrada de payload + tipo
    in_valid  : in  std_logic;
    in_payload: in  std_logic_vector(63 downto 0);
    in_is_data: in  std_logic;                       -- '1' data, '0' control
    in_ready  : out std_logic;
    -- salida de palabras de 64 bits hacia el PMA
    out_valid : out std_logic;
    out_word  : out std_logic_vector(63 downto 0)
  );
end entity pcs_tx_datapath;

architecture rtl of pcs_tx_datapath is
  -- scrambler
  signal scr_en    : std_logic;
  signal scr_din   : std_logic_vector(63 downto 0);
  signal scr_dout  : std_logic_vector(63 downto 0);
  signal scr_valid : std_logic;
  -- sync retrasado para alinear con la salida del scrambler
  signal sync_d1   : std_logic_vector(1 downto 0) := (others => '0');
  -- gearbox
  signal gb_in_valid : std_logic;
  signal gb_in_block : std_logic_vector(65 downto 0);
  signal gb_in_ready : std_logic;
  signal gb_out_valid: std_logic;
  signal gb_out_word : std_logic_vector(63 downto 0);
  -- registro skid: guarda un bloque scrambleado si el gearbox no puede aceptarlo
  signal skid_valid  : std_logic := '0';
  signal skid_block  : std_logic_vector(65 downto 0) := (others => '0');
begin

  -- Solo aceptamos un nuevo payload si no hay un bloque atascado en el skid y
  -- el gearbox esta listo. Esto propaga el backpressure del gearbox a traves
  -- de la latencia del scrambler sin perder datos.
  in_ready <= gb_in_ready and (not skid_valid);
  scr_en   <= in_valid and gb_in_ready and (not skid_valid);
  scr_din  <= in_payload;

  -- instancia scrambler en modo scramble (mode='0')
  u_scr: entity work.pcs_scrambler
    port map (clk=>clk, rst=>rst, en=>scr_en, mode=>'0',
              din=>scr_din, dout=>scr_dout, dvalid=>scr_valid);

  -- retrasar el sync 1 ciclo para casar con scr_dout (scrambler tiene 1 ciclo)
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sync_d1 <= (others => '0');
      elsif scr_en = '1' then
        -- sync: 01 data, 10 control
        if in_is_data = '1' then sync_d1 <= "01"; else sync_d1 <= "10"; end if;
      end if;
    end if;
  end process;

  -- registro skid: si el scrambler entrega un bloque y el gearbox no lo acepta,
  -- lo guardamos y lo reintentamos el siguiente ciclo.
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        skid_valid <= '0';
        skid_block <= (others => '0');
      else
        if skid_valid = '1' then
          -- intentando vaciar el skid
          if gb_in_ready = '1' then
            skid_valid <= '0';   -- el gearbox lo tomo este ciclo
          end if;
        elsif scr_valid = '1' and gb_in_ready = '0' then
          -- el scrambler entrego pero el gearbox no puede: guardar
          skid_valid <= '1';
          skid_block <= scr_dout & sync_d1;
        end if;
      end if;
    end if;
  end process;

  -- hacia el gearbox: prioridad al skid; si no, el bloque fresco del scrambler
  gb_in_valid <= '1' when skid_valid = '1' else scr_valid;
  gb_in_block <= skid_block when skid_valid = '1' else (scr_dout & sync_d1);

  -- gearbox TX
  u_gb: entity work.pcs_gearbox_tx
    port map (clk=>clk, rst=>rst, in_valid=>gb_in_valid, in_block=>gb_in_block,
              in_ready=>gb_in_ready, out_valid=>gb_out_valid, out_word=>gb_out_word);

  out_valid <= gb_out_valid;
  out_word  <= gb_out_word;

end architecture rtl;
