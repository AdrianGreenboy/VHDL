-- ============================================================================
-- tb_mpc_guard.vhd -- audit 2026-11: mpc_engine driven directly (regfile
-- clamps bypassed) with n_dim = 0 and maxiter = 0 must finish at once.
-- Pre-audit: n_dim = 0 underflowed (n_dim-1 = 255 -> U writes past the bank),
-- maxiter = 0 underflowed to 65536 iterations. Self-checking.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adcs_pkg.all;

entity tb_mpc_guard is
end entity;

architecture sim of tb_mpc_guard is
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal rst_n : std_logic := '0';
  signal start, busy, done, tick : std_logic := '0';
  signal n_dim : std_logic_vector(IDX_W-1 downto 0) := (others => '0');
  signal maxiter : std_logic_vector(15 downto 0) := (others => '0');
  signal h_rd_en, g_rd_en, u_rd_en, u_wr_en : std_logic;
  signal h_rd_row, g_rd_a, u_rd_a, u_wr_a : std_logic_vector(IDX_W-1 downto 0);
  signal h_row : std_logic_vector(D*FP_W-1 downto 0);
  signal g_d, u_d, u_wd, ext_d : std_logic_vector(FP_W-1 downto 0);
  signal u_vec : std_logic_vector(D*FP_W-1 downto 0);
  signal iter : std_logic_vector(15 downto 0);
begin
  clk <= '0' when fin else not clk after 2 ns;

  u_h : entity work.h_bank
    port map (clk => clk, wr_en => '0', wr_row => (others => '0'), wr_col => (others => '0'),
              wr_data => (others => '0'), rd_en => h_rd_en, rd_row => h_rd_row, row_data => h_row);
  u_g : entity work.g_bank
    port map (clk => clk, wr_en => '0', wr_addr => (others => '0'), wr_data => (others => '0'),
              rd_en => g_rd_en, rd_addr => g_rd_a, rd_data => g_d);
  u_u : entity work.u_bank
    port map (clk => clk, rst_n => rst_n, wr_en => u_wr_en, wr_addr => u_wr_a, wr_data => u_wd,
              rd_en => u_rd_en, rd_addr => u_rd_a, rd_data => u_d,
              snap_tick => tick, u_vec => u_vec, ext_rd_addr => (others => '0'), ext_rd_data => ext_d);

  dut : entity work.mpc_engine
    port map (clk => clk, rst_n => rst_n, start => start, n_dim => n_dim, maxiter => maxiter,
              step_f => x"3E000000", umax_f => x"3F000000",
              busy => busy, done => done, iter_cnt => iter, iter_tick => tick,
              h_rd_en => h_rd_en, h_rd_row => h_rd_row, h_row_data => h_row,
              g_rd_en => g_rd_en, g_rd_addr => g_rd_a, g_rd_data => g_d,
              u_rd_en => u_rd_en, u_rd_addr => u_rd_a, u_rd_data => u_d,
              u_wr_en => u_wr_en, u_wr_addr => u_wr_a, u_wr_data => u_wd,
              u_vec_data => u_vec);

  main : process
    procedure run(nd, mi : natural; lim : natural; msg : string) is
      variable c : natural := 0;
    begin
      n_dim <= std_logic_vector(to_unsigned(nd, IDX_W));
      maxiter <= std_logic_vector(to_unsigned(mi, 16));
      start <= '1'; wait until rising_edge(clk); start <= '0';
      loop
        wait until rising_edge(clk); c := c + 1;
        exit when done = '1';
        assert c < lim report msg & ": engine did not finish (wrap-around)" severity failure;
      end loop;
    end procedure;
  begin
    rst_n <= '0'; for i in 0 to 4 loop wait until rising_edge(clk); end loop;
    rst_n <= '1'; wait until rising_edge(clk);
    run(0, 3, 50, "n_dim=0");
    run(8, 0, 50, "maxiter=0");
    run(8, 1, 20000, "n_dim=8 maxiter=1");   -- sanity: a real solve still runs
    report "TB_MPC_GUARD PASS";
    fin <= true; wait;
  end process;
end architecture;
