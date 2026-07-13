-- ============================================================================
-- mpc_dot_x8.vhd — NLANES dot-engines en paralelo (port de mpc_dot_x8.sv).
-- Cada lane computa result[k] = sum_j H[row_k][j]*U[j] con el mpc_dot_row ya
-- verificado en capa 1b (mismo contrato numerico NACC=16 por lane).
-- done cuando TODOS los lanes activos terminaron: los done son pulsos de 1
-- ciclo, se acumulan en 'seen'; los lanes inactivos (lane_en=0) cuentan como
-- terminados para no bloquear.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;

entity mpc_dot_x8 is
  generic (
    LAT_FMA : natural := 8;
    NLANES  : natural := 8
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    start   : in  std_logic;
    n_dim   : in  std_logic_vector(IDX_W-1 downto 0);
    lane_en : in  std_logic_vector(NLANES-1 downto 0);
    h_rows  : in  std_logic_vector(NLANES*D*FP_W-1 downto 0);
    u_vec   : in  std_logic_vector(D*FP_W-1 downto 0);
    done    : out std_logic;
    results : out std_logic_vector(NLANES*FP_W-1 downto 0)
  );
end entity mpc_dot_x8;

architecture rtl of mpc_dot_x8 is
  signal lane_done : std_logic_vector(NLANES-1 downto 0);
  signal seen      : std_logic_vector(NLANES-1 downto 0);
  signal running   : std_logic;
begin

  g_lane : for L in 0 to NLANES-1 generate
    signal l_start, l_done : std_logic;
  begin
    l_start <= start and lane_en(L);

    u_dot : entity work.mpc_dot_row
      generic map (LAT_FMA => LAT_FMA, MUT => 0)
      port map (
        clk    => clk,
        rst_n  => rst_n,
        start  => l_start,
        n_dim  => n_dim,
        h_row  => h_rows((L+1)*D*FP_W-1 downto L*D*FP_W),
        u_vec  => u_vec,
        done   => l_done,
        result => results((L+1)*FP_W-1 downto L*FP_W));

    lane_done(L) <= l_done when lane_en(L) = '1' else '1';
  end generate;

  p_done : process (clk, rst_n)
  begin
    if rst_n = '0' then
      seen    <= (others => '0');
      running <= '0';
      done    <= '0';
    elsif rising_edge(clk) then
      done <= '0';
      if start = '1' then
        seen    <= (others => '0');
        running <= '1';
      elsif running = '1' then
        seen <= seen or lane_done;
        if (seen or lane_done) = (seen'range => '1') then
          done    <= '1';
          running <= '0';
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
