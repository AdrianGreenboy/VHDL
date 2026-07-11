-- ptp_pdelay.vhd — calculo de meanPathDelay (IP PTP / IEEE 802.1AS v1)
-- ---------------------------------------------------------------------------
-- Calcula, en el INICIADOR, el peer path delay a partir de los 4 timestamps
-- del intercambio Pdelay (1-step):
--   t1 = SFD TX del Pdelay_Req      (iniciador)
--   t2 = SFD RX del Pdelay_Req      (respondedor)   -> llega implicito
--   t3 = SFD TX del Pdelay_Resp     (respondedor)
--   t4 = SFD RX del Pdelay_Resp     (iniciador)
-- En 1-step, (t3 - t2) = residence time llega en el correctionField del Resp,
-- en unidades de 2^-16 ns. Formula:
--   meanPathDelay = ((t4 - t1) - (t3 - t2)) / 2
--                 = ((t4 - t1) - correctionField_ns) / 2
--
-- Aritmetica: cada TS -> ns totales con signo (sec*1e9 + ns) en 64b. El
-- correctionField (64b, 2^-16 ns) -> ns con shift aritmetico >>16. La resta y
-- el /2 son signed con floor. Replicado BIT A BIT por iss_ptp_pdelay.py.
--
-- Contrato: pulso 'calc' con t1,t4 (del iniciador) y corr_field (del Resp
-- parseado por ptp_rx) presentes. 'valid' sube 1 ciclo despues con 'delay_ns'.
-- ---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity ptp_pdelay is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    calc       : in  std_logic;                    -- pulso: calcular ahora
    t1_sec     : in  std_logic_vector(SEC_W-1 downto 0);
    t1_ns      : in  std_logic_vector(NS_W-1 downto 0);
    t4_sec     : in  std_logic_vector(SEC_W-1 downto 0);
    t4_ns      : in  std_logic_vector(NS_W-1 downto 0);
    corr_field : in  std_logic_vector(63 downto 0); -- 2^-16 ns (del Resp)
    delay_ns   : out std_logic_vector(63 downto 0); -- meanPathDelay en ns (signed)
    valid      : out std_logic
  );
end entity ptp_pdelay;

architecture rtl of ptp_pdelay is
  signal delay_r : signed(63 downto 0) := (others => '0');
  signal valid_r : std_logic := '0';

  -- convierte {sec,ns} a ns totales con signo (64b): sec*1e9 + ns
  function ts_to_ns(sec : std_logic_vector(SEC_W-1 downto 0);
                    ns  : std_logic_vector(NS_W-1 downto 0)) return signed is
    variable s : signed(63 downto 0);
    variable n : signed(63 downto 0);
  begin
    s := resize(signed('0' & sec), 64);            -- sec como positivo
    n := resize(signed('0' & ns), 64);
    return resize(s * to_signed(1_000_000_000, 34), 64) + n;
  end function;
begin

  delay_ns <= std_logic_vector(delay_r);
  valid    <= valid_r;

  process(clk)
    variable t1v, t4v : signed(63 downto 0);
    variable d41      : signed(63 downto 0);
    variable corr_ns  : signed(63 downto 0);
    variable diff     : signed(63 downto 0);
  begin
    if rising_edge(clk) then
      valid_r <= '0';
      if rst = '1' then
        delay_r <= (others => '0');
      elsif calc = '1' then
        t1v := ts_to_ns(t1_sec, t1_ns);
        t4v := ts_to_ns(t4_sec, t4_ns);
        d41 := t4v - t1v;                           -- round trip
        -- correctionField (2^-16 ns) -> ns con shift aritmetico
        corr_ns := shift_right(signed(corr_field), 16);
        diff := d41 - corr_ns;
        -- /2 con floor (shift aritmetico)
        delay_r <= shift_right(diff, 1);
        valid_r <= '1';
      end if;
    end if;
  end process;

end architecture rtl;
