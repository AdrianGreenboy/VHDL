-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Sincronizacion de bloque IEEE 802.3 clausula 49 (fig. 49-14) sobre la
-- interfaz de un GT con gearbox 64B/66B asincrono:
--   * cabecera valida = los dos bits distintos ("01" o "10"; no depende del
--     orden de los bits de la cabecera)
--   * sin lock: cualquier cabecera invalida -> SLIP; 64 validas seguidas ->
--     block_lock
--   * con lock: ventanas de 64 cabeceras; 16 invalidas dentro de una ventana
--     -> pierde el lock y SLIP
--   * SLIP: un pulso de 1 ciclo en rxgearboxslip y SLIP_WAIT ciclos sin
--     mirar la entrada (el GT tarda en aplicar el desplazamiento de 1 bit)
-- Eventos de 1 ciclo para contadores: cabecera invalida, slip, perdida de
-- lock.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth21_blocklock is
  generic (
    SLIP_WAIT : natural := 64
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    in_valid  : in  std_logic;
    in_header : in  std_logic_vector(1 downto 0);
    slip      : out std_logic;
    lock      : out std_logic;
    ev_badsh  : out std_logic;
    ev_slip   : out std_logic;
    ev_lost   : out std_logic
  );
end entity eth21_blocklock;

architecture rtl of eth21_blocklock is
  signal lock_r   : std_logic := '0';
  signal sh_cnt   : unsigned(6 downto 0) := (others => '0');   -- 0..64
  signal inv_cnt  : unsigned(4 downto 0) := (others => '0');   -- 0..16
  signal waitc    : unsigned(9 downto 0) := (others => '0');
  signal slip_r, e_bad, e_slip, e_lost : std_logic := '0';
begin

  process(clk)
    variable shv : boolean;
  begin
    if rising_edge(clk) then
      slip_r <= '0'; e_bad <= '0'; e_slip <= '0'; e_lost <= '0';
      if rst = '1' then
        lock_r <= '0'; sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
        waitc <= (others => '0');
      elsif waitc /= 0 then
        waitc <= waitc - 1;
      elsif in_valid = '1' then
        shv := (in_header(0) /= in_header(1));
        if not shv then e_bad <= '1'; end if;
        if lock_r = '0' then
          if not shv then
            slip_r <= '1'; e_slip <= '1';
            waitc <= to_unsigned(SLIP_WAIT, 10);
            sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
          elsif sh_cnt = 63 then
            lock_r <= '1';
            sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
          else
            sh_cnt <= sh_cnt + 1;
          end if;
        else
          if not shv and inv_cnt = 15 then
            -- 16 cabeceras invalidas en la ventana: se pierde el lock
            lock_r <= '0'; e_lost <= '1';
            slip_r <= '1'; e_slip <= '1';
            waitc <= to_unsigned(SLIP_WAIT, 10);
            sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
          elsif sh_cnt = 63 then
            sh_cnt <= (others => '0'); inv_cnt <= (others => '0');
          else
            sh_cnt <= sh_cnt + 1;
            if not shv then inv_cnt <= inv_cnt + 1; end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  slip     <= slip_r;
  lock     <= lock_r;
  ev_badsh <= e_bad;
  ev_slip  <= e_slip;
  ev_lost  <= e_lost;

end architecture rtl;
