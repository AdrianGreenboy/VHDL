-- rf_agc.vhd - AGC con estimador |I|^2+|Q|^2, promedio movil 64 y ganancia por shift
-- p = min((i*i + q*q) >> 15, 65535); wsum boxcar 64 (22 bits); avg = wsum >> 6.
-- rssi_o = avg registrado. Evaluacion del lazo cada 64 muestras validas:
-- avg > th_high y sh > 0 -> sh-1 ; avg < th_low y sh < 7 -> sh+1 (solo agc_en).
-- La salida usa el sh PREVIO a la evaluacion. Manual: sh = shift_man_i si agc_en=0.
-- clr_i: limpieza sincrona del estado AGC (ventana, contadores, sh).
-- Salida registrada 1 ciclo. Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_agc is
  port (
    clk_i       : in  std_logic;
    aresetn_i   : in  std_logic;
    clr_i       : in  std_logic;
    valid_i     : in  std_logic;
    i_i         : in  std_logic_vector(15 downto 0);
    q_i         : in  std_logic_vector(15 downto 0);
    agc_en_i    : in  std_logic;
    shift_man_i : in  std_logic_vector(2 downto 0);
    th_high_i   : in  std_logic_vector(15 downto 0);
    th_low_i    : in  std_logic_vector(15 downto 0);
    i_o         : out std_logic_vector(15 downto 0);
    q_o         : out std_logic_vector(15 downto 0);
    rssi_o      : out std_logic_vector(15 downto 0);
    valid_o     : out std_logic
  );
end entity rf_agc;

architecture rtl of rf_agc is
  type t_win is array (0 to 63) of unsigned(15 downto 0);
  signal win_r  : t_win := (others => (others => '0'));
  signal wsum_r : unsigned(21 downto 0) := (others => '0');
  signal wptr_r : unsigned(5 downto 0) := (others => '0');
  signal cnt_r  : unsigned(5 downto 0) := (others => '0');
  signal sh_r   : unsigned(2 downto 0) := (others => '0');

  function sat16 (v : signed(23 downto 0)) return std_logic_vector is
  begin
    if v > 32767 then
      return std_logic_vector(to_signed(32767, 16));
    elsif v < -32768 then
      return std_logic_vector(to_signed(-32768, 16));
    else
      return std_logic_vector(v(15 downto 0));
    end if;
  end function sat16;
begin

  proc_agc : process (clk_i, aresetn_i)
    variable iv, qv    : signed(15 downto 0);
    variable pw_v      : unsigned(31 downto 0);
    variable p_v       : unsigned(15 downto 0);
    variable wsum_n    : unsigned(21 downto 0);
    variable avg_v     : unsigned(15 downto 0);
    variable sh_eff_v  : natural range 0 to 7;
  begin
    if aresetn_i = '0' then
      win_r  <= (others => (others => '0'));
      wsum_r <= (others => '0');
      wptr_r <= (others => '0');
      cnt_r  <= (others => '0');
      sh_r   <= (others => '0');
      i_o    <= (others => '0');
      q_o    <= (others => '0');
      rssi_o <= (others => '0');
      valid_o <= '0';
    elsif rising_edge(clk_i) then
      valid_o <= '0';
      if clr_i = '1' then
        win_r  <= (others => (others => '0'));
        wsum_r <= (others => '0');
        wptr_r <= (others => '0');
        cnt_r  <= (others => '0');
        sh_r   <= (others => '0');
      elsif valid_i = '1' then
        iv := signed(i_i);
        qv := signed(q_i);
        pw_v := unsigned(resize(iv * iv, 32)) + unsigned(resize(qv * qv, 32));
        pw_v := shift_right(pw_v, 15);
        if pw_v > 65535 then
          p_v := (others => '1');
        else
          p_v := pw_v(15 downto 0);
        end if;
        wsum_n := wsum_r - resize(win_r(to_integer(wptr_r)), 22) + resize(p_v, 22);
        win_r(to_integer(wptr_r)) <= p_v;
        wptr_r <= wptr_r + 1;
        wsum_r <= wsum_n;
        avg_v  := wsum_n(21 downto 6);
        rssi_o <= std_logic_vector(avg_v);
        if agc_en_i = '1' then
          sh_eff_v := to_integer(sh_r);
        else
          sh_eff_v := to_integer(unsigned(shift_man_i));
        end if;
        i_o <= sat16(shift_left(resize(iv, 24), sh_eff_v));
        q_o <= sat16(shift_left(resize(qv, 24), sh_eff_v));
        valid_o <= '1';
        if cnt_r = 63 then
          cnt_r <= (others => '0');
          if agc_en_i = '1' then
            if avg_v > unsigned(th_high_i) and sh_r > 0 then
              sh_r <= sh_r - 1;
            elsif avg_v < unsigned(th_low_i) and sh_r < 7 then
              sh_r <= sh_r + 1;
            end if;
          end if;
        else
          cnt_r <= cnt_r + 1;
        end if;
      end if;
    end if;
  end process proc_agc;

end architecture rtl;
