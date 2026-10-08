-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- PCS TX a tasa de linea: scrambler + gearbox del Core 19 (sin modificar) con
-- in_ready PREDICTIVO y REGISTRADO, sin registro skid.
--
-- Motivo (hallazgo del Core 20): pcs_tx_datapath del Core 19 baja in_ready
-- dos ciclos por periodo de gearbox (el ciclo sin hueco del gearbox y el
-- siguiente, mientras vacia su skid). Acepta 31 bloques / 33 ciclos y emite
-- ~97 de cada 100 palabras: en loopback no se nota, pero un PMA serie real
-- necesita una palabra de 64 bits en CADA ciclo. Medido en GHDL:
--   Core 19: 3106 bloques y 3203 palabras en 3300 ciclos.
--
-- Aqui se lleva una copia exacta del nivel de llenado del gearbox (sf) y se
-- decide con un ciclo de antelacion si el gearbox podra aceptar el bloque que
-- sale del scrambler: in_ready(t) = [fill(t+1) <= 64]. Resultado: 32 bloques
-- cada 33 ciclos y una palabra por ciclo. El contenido del flujo de palabras
-- es bit a bit identico al del Core 19 (mismo scrambler, mismo gearbox,
-- mismo orden): lo demuestra tb_mac_pcs_tx.
--
-- Nota de interoperabilidad (heredada del Core 19, NO cambiada aqui): el sync
-- header se forma como "01" (datos) con bit 0 = '1', que sale primero. En la
-- notacion de 802.3 Figura 49-7 eso es '10' (control). Coherente con el RX del
-- Core 19, irrelevante en loopback; a revisar antes de un PMA real.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac25g_pcs_tx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    in_valid   : in  std_logic;
    in_payload : in  std_logic_vector(63 downto 0);
    in_is_data : in  std_logic;
    in_ready   : out std_logic;             -- registrado
    out_valid  : out std_logic;
    out_word   : out std_logic_vector(63 downto 0)
  );
end entity mac25g_pcs_tx;

architecture rtl of mac25g_pcs_tx is
  signal rdy_r     : std_logic := '0';
  signal sf        : unsigned(7 downto 0) := (others => '0');  -- copia del fill
  signal scr_en    : std_logic;
  signal scr_dout  : std_logic_vector(63 downto 0);
  signal scr_valid : std_logic;
  signal sync_d1   : std_logic_vector(1 downto 0) := (others => '0');
  signal gb_ready  : std_logic;

  -- paso del gearbox: empuja 66 si 'push', extrae 64 si hay >= 64
  function step(f : unsigned(7 downto 0); push : std_logic) return unsigned is
    variable v : unsigned(7 downto 0) := f;
  begin
    if push = '1' then v := v + 66; end if;
    if v >= 64 then v := v - 64; end if;
    return v;
  end function;
begin

  scr_en <= in_valid and rdy_r;

  -- prediccion: fill(t+1) = step(sf(t), push(t)), push(t) = scr_valid(t)
  --             fill(t+2) = step(fill(t+1), push(t+1)), push(t+1) = scr_en(t)
  -- in_ready(t+1) = fill(t+2) <= 64
  process(clk)
    variable f1, f2 : unsigned(7 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sf <= (others => '0'); rdy_r <= '0';
      else
        f1 := step(sf, scr_valid);
        f2 := step(f1, scr_en);
        sf <= f1;
        if f2 <= 64 then rdy_r <= '1'; else rdy_r <= '0'; end if;
      end if;
    end if;
  end process;

  u_scr: entity work.pcs_scrambler
    port map (clk=>clk, rst=>rst, en=>scr_en, mode=>'0',
              din=>in_payload, dout=>scr_dout, dvalid=>scr_valid);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sync_d1 <= (others => '0');
      elsif scr_en = '1' then
        if in_is_data = '1' then sync_d1 <= "01"; else sync_d1 <= "10"; end if;
      end if;
    end if;
  end process;

  u_gb: entity work.pcs_gearbox_tx
    port map (clk=>clk, rst=>rst, in_valid=>scr_valid,
              in_block=>scr_dout & sync_d1, in_ready=>gb_ready,
              out_valid=>out_valid, out_word=>out_word);

  -- pragma translate_off
  process(clk)
  begin
    if rising_edge(clk) then
      assert not (rst = '0' and scr_valid = '1' and gb_ready = '0')
        report "mac25g_pcs_tx: prediccion de ready incorrecta (bloque perdido)"
        severity failure;
    end if;
  end process;
  -- pragma translate_on

  in_ready <= rdy_r;

end architecture rtl;
