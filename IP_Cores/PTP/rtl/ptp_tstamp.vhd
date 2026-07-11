-- ptp_tstamp.vhd — captura de timestamp en el SFD (IP PTP / IEEE 802.1AS v1)
-- ---------------------------------------------------------------------------
-- Captura el snapshot {sec,ns} del reloj PTP en el instante del pulso SFD
-- (tx o rx) y lo mantiene estable con un STICKY de validez hasta que el
-- consumidor lo lee (rd_ack lo limpia). Aplica una latencia de calibracion
-- fija: el pulso SFD llega unos ciclos DESPUES del instante fisico real del
-- SFD en el cable (pipeline de los motores MII); TX_LAT/RX_LAT compensan ese
-- retardo restandolo del ns capturado. En LOOP_INT ambos retardos son
-- deterministas y pequenos; se ajustan en bring-up.
--
-- Contrato (evita la condicion de carrera de stickies del contexto):
--   - ts_valid sube 1 ciclo despues del pulso SFD (cuando el snapshot esta
--     capturado y corregido) y PERMANECE alto hasta rd_ack.
--   - El consumidor DEBE esperar a ts_valid antes de leer ts_sec/ts_ns.
--   - rd_ack (pulso) limpia ts_valid para el siguiente evento.
--   - Si llega un nuevo SFD con ts_valid aun alto (consumidor lento), se
--     sobrescribe el snapshot y se pulsa ts_overrun (diagnostico).
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity ptp_tstamp is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                    -- sincrono activo-alto
    -- snapshot combinacional del reloj
    now_sec    : in  std_logic_vector(SEC_W-1 downto 0);
    now_ns     : in  std_logic_vector(NS_W-1 downto 0);
    -- latencia de calibracion en ns (restada del ns capturado)
    lat_ns     : in  std_logic_vector(15 downto 0);
    -- evento
    sfd_pulse  : in  std_logic;                    -- pulso de 1 ciclo
    rd_ack     : in  std_logic;                    -- el consumidor limpia el sticky
    -- timestamp capturado
    ts_sec     : out std_logic_vector(SEC_W-1 downto 0);
    ts_ns      : out std_logic_vector(NS_W-1 downto 0);
    ts_valid   : out std_logic;
    ts_overrun : out std_logic                     -- pulso: SFD con ts_valid alto
  );
end entity ptp_tstamp;

architecture rtl of ptp_tstamp is
  signal sec_r   : unsigned(SEC_W-1 downto 0) := (others => '0');
  signal ns_r    : unsigned(NS_W-1 downto 0)  := (others => '0');
  signal valid_r : std_logic := '0';
  signal ovr_r   : std_logic := '0';
begin

  ts_sec     <= std_logic_vector(sec_r);
  ts_ns      <= std_logic_vector(ns_r);
  ts_valid   <= valid_r;
  ts_overrun <= ovr_r;

  process(clk)
    variable ns_v   : unsigned(NS_W-1 downto 0);
    variable sec_v  : unsigned(SEC_W-1 downto 0);
    variable lat_v  : unsigned(NS_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid_r <= '0';
        ovr_r   <= '0';
        sec_r   <= (others => '0');
        ns_r    <= (others => '0');
      else
        -- limpieza de stickies por el consumidor
        if rd_ack = '1' then
          valid_r <= '0';
          ovr_r   <= '0';
        end if;

        -- captura en el pulso SFD (prioridad sobre rd_ack del mismo ciclo:
        -- si coinciden, el nuevo evento gana y valid queda alto)
        if sfd_pulse = '1' then
          -- corregir latencia: ns := now_ns - lat_ns, con posible borrow a sec
          lat_v := resize(unsigned(lat_ns), NS_W);
          if unsigned(now_ns) >= lat_v then
            ns_v  := unsigned(now_ns) - lat_v;
            sec_v := unsigned(now_sec);
          else
            -- borrow: restamos del segundo anterior
            ns_v  := unsigned(now_ns) + NS_PER_SEC - lat_v;
            sec_v := unsigned(now_sec) - 1;
          end if;
          sec_r <= sec_v;
          ns_r  <= ns_v;
          -- overrun STICKY si aun no se habia leido el anterior
          if valid_r = '1' and rd_ack = '0' then
            ovr_r <= '1';
          end if;
          valid_r <= '1';
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
