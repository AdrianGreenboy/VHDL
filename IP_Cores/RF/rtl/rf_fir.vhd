-- rf_fir.vhd - FIR de canal 16 taps Q1.15, forma directa paralela, PIPELINADO.
-- Coeficientes cargables por puerto (coef_we/addr/data); el MMIO los mapea en el
-- paso 5 (FIR_COEF_ADDR/FIR_COEF_DATA). y = sat16(acc >> 15).
--
-- PIPELINE (para cerrar timing a 240 MHz; el FIR combinacional daba 54 niveles de
-- logica / 17.7 ns, imposible a 4.16 ns):
--   S0: linea de retardo (shift register de historia), avanza 1 por valid_i.
--   S1: 16 multiplicadores coef[k]*x[k] -> 16 productos registrados (p_r).
--   S2: suma en pares -> 8 sumas registradas (a8_r).
--   S3: 4 sumas registradas (a4_r).
--   S4: 2 sumas registradas (a2_r).
--   S5: 1 suma final + shift(>>15) + saturacion -> salida registrada.
-- El bit de valid se propaga por una cadena de 5 registros (v_r) para alinear la
-- salida. El RESULTADO NUMERICO es identico al FIR combinacional; solo llega 5
-- ciclos mas tarde. Historia sin limpieza. Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_fir is
  port (
    clk_i       : in  std_logic;
    aresetn_i   : in  std_logic;
    valid_i     : in  std_logic;
    i_i         : in  std_logic_vector(15 downto 0);
    q_i         : in  std_logic_vector(15 downto 0);
    coef_we_i   : in  std_logic;
    coef_addr_i : in  std_logic_vector(3 downto 0);
    coef_data_i : in  std_logic_vector(15 downto 0);
    i_o         : out std_logic_vector(15 downto 0);
    q_o         : out std_logic_vector(15 downto 0);
    valid_o     : out std_logic
  );
end entity rf_fir;

architecture rtl of rf_fir is
  type t_c16 is array (0 to 15) of signed(15 downto 0);
  -- productos y sumas parciales: los productos de 16x16 caben en 32 bits; el
  -- arbol de 16 terminos crece a lo sumo log2(16)=4 bits mas -> 36 bits basta.
  type t_p16 is array (0 to 15) of signed(35 downto 0);
  type t_p8  is array (0 to 7)  of signed(35 downto 0);
  type t_p4  is array (0 to 3)  of signed(35 downto 0);
  type t_p2  is array (0 to 1)  of signed(35 downto 0);

  signal coef_r : t_c16 := (others => (others => '0'));
  signal si_r   : t_c16 := (others => (others => '0'));  -- historia I
  signal sq_r   : t_c16 := (others => (others => '0'));  -- historia Q

  -- pipeline I
  signal pi_r  : t_p16 := (others => (others => '0'));   -- S1: productos I
  signal ai8_r : t_p8  := (others => (others => '0'));   -- S2
  signal ai4_r : t_p4  := (others => (others => '0'));   -- S3
  signal ai2_r : t_p2  := (others => (others => '0'));   -- S4
  -- pipeline Q
  signal pq_r  : t_p16 := (others => (others => '0'));
  signal aq8_r : t_p8  := (others => (others => '0'));
  signal aq4_r : t_p4  := (others => (others => '0'));
  signal aq2_r : t_p2  := (others => (others => '0'));

  -- cadena de valid (5 etapas: S1..S5)
  signal v_r : std_logic_vector(4 downto 0) := (others => '0');

  function sat16 (v : signed(35 downto 0)) return std_logic_vector is
    variable s : signed(35 downto 0);
  begin
    s := shift_right(v, 15);
    if s > 32767 then
      return std_logic_vector(to_signed(32767, 16));
    elsif s < -32768 then
      return std_logic_vector(to_signed(-32768, 16));
    else
      return std_logic_vector(s(15 downto 0));
    end if;
  end function sat16;
begin

  valid_o <= v_r(4);

  proc_fir : process (clk_i, aresetn_i)
    variable x_i_v, x_q_v : signed(15 downto 0);
  begin
    if aresetn_i = '0' then
      si_r  <= (others => (others => '0'));
      sq_r  <= (others => (others => '0'));
      pi_r  <= (others => (others => '0'));
      ai8_r <= (others => (others => '0'));
      ai4_r <= (others => (others => '0'));
      ai2_r <= (others => (others => '0'));
      pq_r  <= (others => (others => '0'));
      aq8_r <= (others => (others => '0'));
      aq4_r <= (others => (others => '0'));
      aq2_r <= (others => (others => '0'));
      v_r   <= (others => '0');
      i_o   <= (others => '0');
      q_o   <= (others => '0');
    elsif rising_edge(clk_i) then
      -- carga de coeficientes (independiente del pipeline de datos)
      if coef_we_i = '1' then
        coef_r(to_integer(unsigned(coef_addr_i))) <= signed(coef_data_i);
      end if;

      -- ================= S0/S1: historia + multiplicadores =================
      -- avanzar la cadena de valid; S1 se activa con valid_i
      v_r <= v_r(3 downto 0) & valid_i;

      if valid_i = '1' then
        x_i_v := signed(i_i);
        x_q_v := signed(q_i);
        -- S1: 16 productos. tap 0 usa la muestra actual; taps 1..15 la historia.
        pi_r(0) <= resize(coef_r(0) * x_i_v, 36);
        pq_r(0) <= resize(coef_r(0) * x_q_v, 36);
        for k in 1 to 15 loop
          pi_r(k) <= resize(coef_r(k) * si_r(k - 1), 36);
          pq_r(k) <= resize(coef_r(k) * sq_r(k - 1), 36);
        end loop;
        -- S0: avanzar la linea de retardo una posicion
        for k in 15 downto 1 loop
          si_r(k) <= si_r(k - 1);
          sq_r(k) <= sq_r(k - 1);
        end loop;
        si_r(0) <= x_i_v;
        sq_r(0) <= x_q_v;
      end if;

      -- ================= S2: 8 sumas en pares =================
      for k in 0 to 7 loop
        ai8_r(k) <= pi_r(2*k) + pi_r(2*k + 1);
        aq8_r(k) <= pq_r(2*k) + pq_r(2*k + 1);
      end loop;

      -- ================= S3: 4 sumas =================
      for k in 0 to 3 loop
        ai4_r(k) <= ai8_r(2*k) + ai8_r(2*k + 1);
        aq4_r(k) <= aq8_r(2*k) + aq8_r(2*k + 1);
      end loop;

      -- ================= S4: 2 sumas =================
      for k in 0 to 1 loop
        ai2_r(k) <= ai4_r(2*k) + ai4_r(2*k + 1);
        aq2_r(k) <= aq4_r(2*k) + aq4_r(2*k + 1);
      end loop;

      -- ================= S5: suma final + shift + saturacion =================
      i_o <= sat16(ai2_r(0) + ai2_r(1));
      q_o <= sat16(aq2_r(0) + aq2_r(1));
    end if;
  end process proc_fir;

end architecture rtl;
