-- tb_ptp_regs.vhd — capa 2: banco MMIO vs BFM del dmem.
-- Ejercita el banco por la interfaz sel/we/addr/wdata/rdata:
--   - escritura/lectura de registros de control
--   - snapshot atomico del reloj (leer NOW_SEC congela NOW_NS)
--   - stickies STATUS con W1C y set-del-mismo-ciclo ganando
--   - IRQ por nivel OR(STATUS and IRQEN)
-- Asserts en espanol, severity failure.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ptp_pkg.all;

entity tb_ptp_regs is
end entity;

architecture sim of tb_ptp_regs is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;

  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(5 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal irq : std_logic;

  signal role_slave, loopback, enable : std_logic;
  signal kp, ki, tx_lat, rx_lat : std_logic_vector(15 downto 0);
  signal clock_id : std_logic_vector(63 downto 0);
  signal port_num : std_logic_vector(15 downto 0);
  signal src_mac : std_logic_vector(47 downto 0);
  signal send_sync, start_pdelay : std_logic;

  -- estado simulado del datapath
  signal now_sec : std_logic_vector(SEC_W-1 downto 0) := (others => '0');
  signal now_ns  : std_logic_vector(NS_W-1 downto 0) := (others => '0');
  signal mpd_ns  : std_logic_vector(63 downto 0) := (others => '0');
  signal mpd_valid, offset_valid, rx_sync_ev, rx_resp_ev : std_logic := '0';
  signal offset_ns : std_logic_vector(ERR_W-1 downto 0) := (others => '0');
  signal rate_adj : std_logic_vector(RATE_W-1 downto 0) := (others => '0');

  -- offsets de palabra
  constant A_CTRL:integer:=0; constant A_SERVO:integer:=1; constant A_LAT:integer:=2;
  constant A_CMD:integer:=3; constant A_CLKIDH:integer:=4; constant A_CLKIDL:integer:=5;
  constant A_PORT:integer:=6; constant A_SMACH:integer:=7; constant A_SMACL:integer:=8;
  constant A_STATUS:integer:=9; constant A_NOWSEC:integer:=10; constant A_NOWNS:integer:=11;
  constant A_MPDLO:integer:=12; constant A_MPDHI:integer:=13; constant A_OFFSET:integer:=14;
  constant A_RATE:integer:=15; constant A_IRQEN:integer:=16;
begin
  clk <= not clk after TCK/2 when not done else '0';

  -- el reloj simulado avanza cada ciclo (para probar el snapshot atomico)
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        now_ns <= std_logic_vector(unsigned(now_ns) + 10);
      end if;
    end if;
  end process;

  dut : entity work.ptp_regs
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
              wdata => wdata, rdata => rdata, irq => irq,
              role_slave => role_slave, loopback => loopback, enable => enable,
              kp => kp, ki => ki, tx_lat => tx_lat, rx_lat => rx_lat,
              clock_id => clock_id, port_num => port_num, src_mac => src_mac,
              send_sync => send_sync, start_pdelay => start_pdelay,
              now_sec => now_sec, now_ns => now_ns, mpd_ns => mpd_ns,
              mpd_valid => mpd_valid, offset_ns => offset_ns, offset_valid => offset_valid,
              rate_adj => rate_adj, rx_sync_ev => rx_sync_ev, rx_resp_ev => rx_resp_ev, dbg_state => (others => '0'), dbg_rxdst => (others => '0'), dbg_rxinfo => (others => '0'), dbg_fptr => (others => '0'), dbg_ftx => (others => '0'));

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;

    procedure wr(a : integer; d : std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a, 6));
      wdata <= d; sel <= '1'; we <= '1'; step;
      sel <= '0'; we <= '0';
      wait for 1 ns;           -- propagar salidas combinacionales (kp, ki, ...)
    end procedure;

    -- lectura: rdata es combinacional, valido cuando sel=1 (mismo ciclo)
    procedure rd(a : integer; result : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a, 6));
      sel <= '1'; we <= '0';
      wait for 1 ns;            -- dejar propagar la combinacional
      result := rdata;
      step;
      sel <= '0';
    end procedure;

    variable v : std_logic_vector(31 downto 0);
    variable ns1, ns2 : std_logic_vector(31 downto 0);
  begin
    rst <= '1'; step; step; rst <= '0';

    -- ---- escritura/lectura de control ----
    wr(A_CTRL, x"00000005");                       -- role_slave=1, enable=1
    rd(A_CTRL, v);
    assert v = x"00000005" report "FALLO CTRL readback" severity failure;
    assert role_slave = '1' and enable = '1' and loopback = '0'
      report "FALLO CTRL decode" severity failure;
    report "OK CONTROL rw + decode";

    wr(A_SERVO, x"00400010");                       -- KP=0x40, KI=0x10
    assert kp = x"0040" and ki = x"0010" report "FALLO SERVO_K decode" severity failure;
    report "OK SERVO_K decode";

    wr(A_CLKIDH, x"00112233"); wr(A_CLKIDL, x"44556677");
    assert clock_id = x"0011223344556677" report "FALLO clock_id" severity failure;
    report "OK clock_id 64b";

    wr(A_SMACH, x"000002DE"); wr(A_SMACL, x"CAFBADED");
    assert src_mac = x"02DECAFBADED" report "FALLO src_mac" severity failure;
    report "OK src_mac 48b";

    -- ---- comandos (pulsos auto-clear) ----
    -- send_sync debe pulsar 1 ciclo con la escritura y auto-limpiarse.
    addr <= std_logic_vector(to_unsigned(A_CMD, 6));
    wdata <= x"00000001"; sel <= '1'; we <= '1';
    step;                                   -- flanco de escritura: send_sync_r<=1
    sel <= '0'; we <= '0';
    wait for 1 ns;
    assert send_sync = '1' report "FALLO: send_sync no pulso con la escritura" severity failure;
    step;                                   -- ciclo siguiente: auto-clear
    wait for 1 ns;
    assert send_sync = '0' report "FALLO: send_sync no auto-clear" severity failure;
    report "OK CMD send_sync pulso auto-clear";

    -- ---- snapshot atomico del reloj ----
    -- now_ns avanza cada ciclo. Leer NOW_SEC debe congelar NOW_NS al valor
    -- ACTUAL (no a cero). Verificamos: (a) captura un valor no trivial y
    -- (b) ese valor no cambia entre lecturas posteriores.
    for k in 1 to 20 loop step; end loop;   -- avanzar el reloj a un valor alto
    rd(A_NOWSEC, v);          -- congela ns_snap = now_ns actual
    rd(A_NOWNS, ns1);
    assert unsigned(ns1) > 0
      report "FALLO snapshot: NOW_NS congelado a cero (no capturo el reloj)" severity failure;
    for k in 1 to 5 loop step; end loop;   -- dejar avanzar el reloj real
    rd(A_NOWNS, ns2);
    assert ns1 = ns2
      report "FALLO snapshot: NOW_NS cambio entre lecturas (desgarro)" severity failure;
    report "OK snapshot atomico: NOW_NS congelado al valor actual (" &
           integer'image(to_integer(unsigned(ns1))) & ")";

    -- ---- stickies STATUS con W1C ----
    -- generar un evento rx_sync
    rx_sync_ev <= '1'; step; rx_sync_ev <= '0';
    rd(A_STATUS, v);
    assert v(0) = '1' report "FALLO: sticky rx_sync no se armo" severity failure;
    report "OK sticky rx_sync armado";
    -- limpiar con W1C
    wr(A_STATUS, x"00000001");
    rd(A_STATUS, v);
    assert v(0) = '0' report "FALLO: W1C no limpio rx_sync" severity failure;
    report "OK W1C limpio rx_sync";

    -- set-del-mismo-ciclo gana: evento y W1C coinciden -> sticky queda a 1
    -- forzar coincidencia: escribir W1C mientras rx_sync_ev=1
    rx_sync_ev <= '1';
    addr <= std_logic_vector(to_unsigned(A_STATUS, 6));
    wdata <= x"00000001"; sel <= '1'; we <= '1'; step;
    sel <= '0'; we <= '0'; rx_sync_ev <= '0';
    rd(A_STATUS, v);
    assert v(0) = '1'
      report "FALLO: set-del-mismo-ciclo deberia ganar sobre W1C" severity failure;
    report "OK set-del-mismo-ciclo gana sobre W1C";
    wr(A_STATUS, x"0000000F");   -- limpiar todo

    -- ---- IRQ por nivel ----
    wr(A_STATUS, x"0000000F");   -- limpiar todos los stickies
    wr(A_IRQEN,  x"00000000");   -- deshabilitar todas las mascaras
    -- armar un sticky (rx_resp, bit1) con su mascara DESHABILITADA
    rx_resp_ev <= '1'; step; rx_resp_ev <= '0';
    wait for 1 ns;
    assert irq = '0' report "FALLO: irq subio con IRQEN=0 (mascara ignorada)" severity failure;
    report "OK IRQ enmascarada: sticky armado pero irq=0 sin su mascara";
    -- ahora armar mpd_valid (bit2) y habilitar SOLO su mascara
    mpd_valid <= '1'; step; mpd_valid <= '0';
    wr(A_IRQEN, x"00000004");    -- habilitar solo bit2 (mpd_valid)
    wait for 1 ns;
    assert irq = '1' report "FALLO: irq no subio con sticky+IRQEN" severity failure;
    -- rx_resp (bit1) sigue armado pero SIN mascara: no debe sostener irq solo
    report "OK IRQ por nivel: sube con STATUS and IRQEN";
    -- limpiar el sticky enmascarado -> irq baja (aunque rx_resp siga armado)
    wr(A_STATUS, x"00000004");
    wait for 1 ns;
    assert irq = '0' report "FALLO: irq no bajo tras limpiar el sticky enmascarado" severity failure;
    report "OK IRQ baja al limpiar el sticky enmascarado";

    report "=== PTP_REGS LAYER 2 PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
