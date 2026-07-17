-- rf_loopmix.vhd - Bloque de loopback DUC->DDC combinado en una sola etapa.
-- En un ciclo: up-mix (e^+jth) -> iq_loop -> down-mix (e^-jth) con la MISMA
-- fila NCO (sin,cos), garantizando coherencia de fase por construccion
-- (e^+jth * e^-jth = 1) sin ningun registro intermedio que desalinee la fase.
--
-- Representa el camino fisico: en un SDR real el up-mix vive en el TX, el RF
-- sale por el DAC/antena y regresa por el ADC al down-mix del RX. Aqui, como no
-- hay front-end analogico en la TE0950, el iq_loop es el lazo interno. La etapa
-- RF intermedia (rf_i,rf_q) se expone como salida de observacion para el test
-- Phase-0 y para futura conexion GTYP (v2).
--
-- loop_en_i = '0' (Phase-0): rf forzado a cero -> down-mix ve cero.
-- Aritmetica: up rf_i = (bi*cos - bq*sin)>>15 ; rf_q = (bq*cos + bi*sin)>>15
--             (con saturacion Q1.15 en la etapa RF)
--             down  i = (rf_i*cos + rf_q*sin)>>15 ; q = (rf_q*cos - rf_i*sin)>>15
-- Salida (banda base recuperada) registrada 1 ciclo. Reset async activo bajo.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_loopmix is
  port (
    clk_i     : in  std_logic;
    aresetn_i : in  std_logic;
    valid_i   : in  std_logic;
    loop_en_i : in  std_logic;
    i_i       : in  std_logic_vector(15 downto 0);  -- banda base TX (interpolada)
    q_i       : in  std_logic_vector(15 downto 0);
    sin_i     : in  std_logic_vector(15 downto 0);
    cos_i     : in  std_logic_vector(15 downto 0);
    rf_i_o    : out std_logic_vector(15 downto 0);   -- observacion RF (registrada)
    rf_q_o    : out std_logic_vector(15 downto 0);
    i_o       : out std_logic_vector(15 downto 0);   -- banda base RX recuperada
    q_o       : out std_logic_vector(15 downto 0);
    valid_o   : out std_logic
  );
end entity rf_loopmix;

architecture rtl of rf_loopmix is
  function sat16 (v : signed(33 downto 0)) return signed is
  begin
    if v > 32767 then
      return to_signed(32767, 16);
    elsif v < -32768 then
      return to_signed(-32768, 16);
    else
      return v(15 downto 0);
    end if;
  end function sat16;
begin

  proc_lm : process (clk_i, aresetn_i)
    variable bi_v, bq_v, s_v, c_v : signed(15 downto 0);
    variable rfi_v, rfq_v         : signed(15 downto 0);
    variable ri_v, rq_v           : signed(33 downto 0);
    variable di_v, dq_v           : signed(33 downto 0);
  begin
    if aresetn_i = '0' then
      rf_i_o  <= (others => '0');
      rf_q_o  <= (others => '0');
      i_o     <= (others => '0');
      q_o     <= (others => '0');
      valid_o <= '0';
    elsif rising_edge(clk_i) then
      valid_o <= '0';
      if valid_i = '1' then
        bi_v := signed(i_i);
        bq_v := signed(q_i);
        s_v  := signed(sin_i);
        c_v  := signed(cos_i);
        -- up-mix e^+jth con saturacion Q1.15 en la etapa RF
        ri_v := resize(bi_v * c_v, 34) - resize(bq_v * s_v, 34);
        rq_v := resize(bq_v * c_v, 34) + resize(bi_v * s_v, 34);
        rfi_v := sat16(resize(shift_right(ri_v, 15), 34));
        rfq_v := sat16(resize(shift_right(rq_v, 15), 34));
        if loop_en_i = '0' then
          rfi_v := (others => '0');
          rfq_v := (others => '0');
        end if;
        rf_i_o <= std_logic_vector(rfi_v);
        rf_q_o <= std_logic_vector(rfq_v);
        -- down-mix e^-jth con la MISMA fila (s,c)
        di_v := resize(rfi_v * c_v, 34) + resize(rfq_v * s_v, 34);
        dq_v := resize(rfq_v * c_v, 34) - resize(rfi_v * s_v, 34);
        i_o <= std_logic_vector(sat16(resize(shift_right(di_v, 15), 34)));
        q_o <= std_logic_vector(sat16(resize(shift_right(dq_v, 15), 34)));
        valid_o <= '1';
      end if;
    end if;
  end process proc_lm;

end architecture rtl;
