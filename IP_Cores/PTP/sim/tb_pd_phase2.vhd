-- tb_ptp_mac_pdelay.vhd — capa 1c: peer-delay completo en LOOP_INT.
-- Un solo core es iniciador y respondedor. Secuencia auto-ping-pong:
--   core envia Pdelay_Req -> loopback -> core lo recibe (respondedor) ->
--   envia Pdelay_Resp -> loopback -> core lo recibe (iniciador) -> mpd.
-- Observa la secuencia y verifica que mpd_valid dispara con un delay coherente.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity tb_pd_phase2 is
end entity;

architecture sim of tb_pd_phase2 is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal role_slave : std_logic := '0';
  signal send_sync, start_pdelay : std_logic := '0';
  signal now_sec : std_logic_vector(SEC_W-1 downto 0);
  signal now_ns  : std_logic_vector(NS_W-1 downto 0);
  signal mpd_ns  : std_logic_vector(63 downto 0);
  signal mpd_valid : std_logic;
  signal offset_ns : std_logic_vector(ERR_W-1 downto 0);
  signal rate_adj : std_logic_vector(RATE_W-1 downto 0);
  signal dbg_rx_mvalid : std_logic;
  signal dbg_rx_mtype : std_logic_vector(3 downto 0);
  signal dbg_rx_seqid : std_logic_vector(15 downto 0);
  signal dbg_t1_ns, dbg_t4_ns : std_logic_vector(NS_W-1 downto 0);
  signal dbg_pd_corr : std_logic_vector(63 downto 0);
  signal dbg_pd_calc : std_logic;
  signal mii_txd : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;

  constant CLOCK_ID : std_logic_vector(63 downto 0) := x"0011223344556677";
  constant PORT_NUM : std_logic_vector(15 downto 0) := x"0001";
  constant SRC_MAC  : std_logic_vector(47 downto 0) := x"02DECAFBADED";
  constant MACADDR  : std_logic_vector(47 downto 0) := x"0E0000C28001";

  signal msg_log : integer := 0;
begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_mac
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (clk => clk, rst => rst, loopback => '1',
              role_slave => role_slave, clock_id => CLOCK_ID, port_num => PORT_NUM,
              src_mac => SRC_MAC, macaddr => MACADDR,
              kp => x"0040", ki => x"0010", tx_lat => x"0000", rx_lat => x"0000",
              send_sync => send_sync, start_pdelay => start_pdelay,
              now_sec => now_sec, now_ns => now_ns, mpd_ns => mpd_ns, mpd_valid => mpd_valid,
              offset_ns => offset_ns, rate_adj => rate_adj,
              dbg_rx_mvalid => dbg_rx_mvalid, dbg_rx_mtype => dbg_rx_mtype, dbg_rx_seqid => dbg_rx_seqid,
              dbg_t1_ns => dbg_t1_ns, dbg_t4_ns => dbg_t4_ns,
              dbg_pd_corr => dbg_pd_corr, dbg_pd_calc => dbg_pd_calc,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => (others => '0'), mii_rx_dv => '0');

  -- log de mensajes recibidos por el parser
  logproc : process(clk)
  begin
    if rising_edge(clk) then
      if dbg_rx_mvalid = '1' then
        report "  [parser] recibio msg_type=" & integer'image(to_integer(unsigned(dbg_rx_mtype))) &
               " seq=" & integer'image(to_integer(unsigned(dbg_rx_seqid)));
      end if;
      if dbg_pd_calc = '1' then
        report "  [pd_calc] t1_ns=" & integer'image(to_integer(unsigned(dbg_t1_ns))) &
               " t4_ns=" & integer'image(to_integer(unsigned(dbg_t4_ns))) &
               " corr(2^-16ns)=" & integer'image(to_integer(signed(dbg_pd_corr)));
      end if;
      if mpd_valid = '1' then
        report "  [mpd] meanPathDelay valido = " & integer'image(to_integer(signed(mpd_ns))) & " ns";
      end if;
    end if;
  end process;

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    variable got_mpd : boolean := false;
  begin
    rst <= '1'; step; step; step; rst <= '0';
    for i in 1 to 32 loop step; end loop;

    -- iniciar el intercambio peer-delay
    report ">>> disparando start_pdelay";
    start_pdelay <= '1'; step; start_pdelay <= '0';

    -- dejar correr toda la secuencia ping-pong y observar
    got_mpd := false;
    for i in 1 to 6000 loop
      step;
      if mpd_valid = '1' then
        got_mpd := true;
        step;   -- mpd_reg captura mpd_i; leerlo tras el registro
        report "  [mpd registrado] meanPathDelay = " &
               integer'image(to_integer(signed(mpd_ns))) & " ns";
        -- en loopback el delay debe ser pequeno y positivo (pipeline fijo).
        -- Verificamos que es el valor determinista esperado (40 ns con este
        -- pipeline de mii_ce y sin latencia de calibracion).
        assert to_integer(signed(mpd_ns)) = 40
          report "FALLO: meanPathDelay=" & integer'image(to_integer(signed(mpd_ns))) &
                 " esperado 40 (loopback determinista)" severity failure;
      end if;
    end loop;

    assert got_mpd report "FALLO: no se calculo meanPathDelay" severity failure;
    report "=== PTP_MAC_PDELAY LAYER 1c: peer-delay loopback, mpd=40ns PASS ===";

    done <= true;
    wait;
  end process;

end architecture sim;
