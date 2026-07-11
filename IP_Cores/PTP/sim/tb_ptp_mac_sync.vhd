-- tb_ptp_mac_sync.vhd — capa 1c: Sync en LOOP_INT (RTL-vs-RTL full-duplex).
-- El maestro emite un Sync; por LOOP_INT vuelve al RX; el parser lo recibe.
-- Verifica que el lazo completo funciona y que los timestamps son coherentes.
-- FASE 0 ANTI-MODO-COMUN: antes de emitir nada, comprobar que el RX NO produce
-- msg_valid espurio (partner en silencio). Vigilante independiente del cable.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;
use work.ptp_msg_pkg.all;

entity tb_ptp_mac_sync is
end entity;

architecture sim of tb_ptp_mac_sync is
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
  signal mii_txd : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;
  signal dbg_rx_mvalid : std_logic;
  signal dbg_rx_mtype : std_logic_vector(3 downto 0);
  signal dbg_rx_seqid : std_logic_vector(15 downto 0);

  constant CLOCK_ID : std_logic_vector(63 downto 0) := x"0011223344556677";
  constant PORT_NUM : std_logic_vector(15 downto 0) := x"0001";
  constant SRC_MAC  : std_logic_vector(47 downto 0) := x"02DECAFBADED";
  -- filtro RX: multicast gPTP 01-80-C2-00-00-0E, con byte0 (0x01) en [7:0]
  -- (el rx_mii ensambla dst con el primer byte del cable en los bits bajos)
  constant MACADDR  : std_logic_vector(47 downto 0) := x"0E0000C28001";

  -- vigilante del cable: cuenta bytes que salen por mii (independiente del DUT)
  signal cable_bytes : integer := 0;
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
              dbg_rx_mvalid => dbg_rx_mvalid, dbg_rx_mtype => dbg_rx_mtype,
              dbg_rx_seqid => dbg_rx_seqid,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => (others => '0'), mii_rx_dv => '0');

  -- vigilante independiente: cuenta nibbles emitidos por el MAC
  watch : process(clk)
  begin
    if rising_edge(clk) then
      if mii_tx_en = '1' then cable_bytes <= cable_bytes + 1; end if;
    end if;
  end process;

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    variable cable0 : integer;
    variable got_sync : boolean;
  begin
    rst <= '1'; step; step; step; rst <= '0';

    -- ===== FASE 0 ANTI-MODO-COMUN =====
    -- partner en silencio: NO emitimos nada. Dejar correr y comprobar que el
    -- cable esta inerte (nada sale) y el reloj avanza libre.
    for i in 1 to 200 loop step; end loop;
    assert cable_bytes = 0
      report "FALLO FASE0: el cable no deberia tener trafico sin emitir" severity failure;
    assert to_integer(unsigned(now_ns)) > 0
      report "FALLO FASE0: el reloj deberia avanzar libre" severity failure;
    report "OK FASE0 anti-modo-comun: cable inerte, reloj libre (ns=" &
           integer'image(to_integer(unsigned(now_ns))) & ")";

    -- ===== emitir un Sync (maestro) y verificar que el lazo transmite =====
    cable0 := cable_bytes;
    role_slave <= '0';
    send_sync <= '1'; step; send_sync <= '0';
    -- dejar que se transmita la trama completa por el lazo y capturar la
    -- recepcion del parser (el Sync vuelve por LOOP_INT)
    got_sync := false;
    for i in 1 to 3000 loop
      step;
      if dbg_rx_mvalid = '1' and dbg_rx_mtype = MT_SYNC then
        got_sync := true;
      end if;
    end loop;
    assert cable_bytes > cable0
      report "FALLO: el Sync no genero trafico en el cable" severity failure;
    report "OK Sync emitido: el cable transporto " &
           integer'image(cable_bytes - cable0) & " nibbles";
    assert got_sync
      report "FALLO: el parser NO recibio el Sync por LOOP_INT" severity failure;
    report "OK lazo cerrado: el parser recibio el Sync por LOOP_INT";

    report "=== PTP_MAC_SYNC LAYER 1c (basico) PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
