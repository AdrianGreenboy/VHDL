-- tb_eth_mac_l1c.vhd — capa 1c: MAC completo en LOOP_INT (full-duplex real:
-- el motor TX y el motor RX de la MISMA instancia trabajan a la vez, el TX se
-- realimenta al RX dentro del PL). Firma determinista comparada byte a byte
-- contra un oraculo independiente.
--
-- FASE 0 anti-modo-comun: antes de transmitir nada, se mantiene el enlace en
-- silencio (loopback activo pero sin tx_valid). El RX NO debe producir ningun
-- ev_ok/ev_crc/ev_runt/ev_drop ni afirmar rx_valid. Si un defecto de protocolo
-- comun hiciera que RX "viera" tramas del ruido, aqui saltaria.
--
-- VIGILANTE DE CABLE independiente (no reutiliza logica del DUT): observa
-- mii_txd/mii_tx_en y exige que, tras un periodo de silencio, el PRIMER nibble
-- con tx_en='1' sea 0x5 (preambulo), que haya exactamente 15 nibbles 0x5 y que
-- el siguiente sea 0xD (SFD). Ancla el formato contra el ESTANDAR, no contra
-- el RX del propio DUT.
--
-- G_MUT (DEBEN fallar):
--   0 = sin mutacion (PASS)
--   1 = el oraculo espera un byte de payload distinto -> firma no coincide
--   2 = se fuerza una trama en fase 0 (tx durante el silencio) -> el vigilante
--       de fase 0 ya no ve silencio Y el conteo de ev_ok deja de ser 0 al final
--       de la fase; se comprueba que la fase 0 detecta actividad indebida
--   3 = el oraculo espera una trama de mas en la firma -> faltan bytes
--   4 = macaddr del RX cambiada -> las unicast propias se filtran (ev_ok cae)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.eth_pkg.all;

entity tb_eth_mac_l1c is
  generic (G_MUT : integer := 0);
end entity tb_eth_mac_l1c;

architecture sim of tb_eth_mac_l1c is

  constant TCLK : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal loopback : std_logic := '1';
  signal macaddr  : std_logic_vector(47 downto 0) := x"EEDDCCBBAA02";
  signal promisc  : std_logic := '0';

  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_valid, tx_last : std_logic := '0';
  signal tx_ready, tx_busy, tx_underrun : std_logic;

  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid, rx_last : std_logic;
  signal rx_ev_ok, rx_ev_crc, rx_ev_runt, rx_ev_drop : std_logic;

  signal mii_txd  : std_logic_vector(3 downto 0);
  signal mii_tx_en: std_logic;
  signal tb_ce    : std_logic := '0';

  type cap_t is array (0 to 16383) of std_logic_vector(7 downto 0);
  signal cap   : cap_t;
  signal cap_n : integer range 0 to 16383 := 0;

  signal got_ok   : integer := 0;
  signal phase0   : std_logic := '1';   -- '1' durante la fase de silencio
  signal p0_viol  : integer := 0;       -- eventos RX indebidos durante fase 0

  type nat_arr is array (natural range <>) of natural;

  function tbyte(f : natural; i : natural) return std_logic_vector is
    constant MINE  : nat_arr(0 to 5) := (16#02#, 16#AA#, 16#BB#, 16#CC#, 16#DD#, 16#EE#);
    constant SRC_B : nat_arr(0 to 5) := (16#0A#, 16#0B#, 16#0C#, 16#0D#, 16#0E#, 16#0F#);
    variable b : natural;
  begin
    if i < 6 then b := MINE(i);
    elsif i < 12 then b := SRC_B(i - 6);
    elsif i = 12 then b := 16#08#;
    elsif i = 13 then b := 16#00#;
    else b := (f * 11 + (i - 14) * 7 + 3) mod 256;
    end if;
    return std_logic_vector(to_unsigned(b, 8));
  end function;

begin

  clk <= not clk after TCLK / 2;

  dut : entity work.eth_mac
    port map (
      clk => clk, rst => rst, loopback => loopback,
      macaddr => macaddr, promisc => promisc,
      tx_data => tx_data, tx_valid => tx_valid, tx_last => tx_last,
      tx_ready => tx_ready, tx_busy => tx_busy, tx_underrun => tx_underrun,
      rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
      rx_ev_ok => rx_ev_ok, rx_ev_crc => rx_ev_crc,
      rx_ev_runt => rx_ev_runt, rx_ev_drop => rx_ev_drop,
      mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => "0000", mii_rx_dv => '0');

  -- captura de la firma RX (bytes volcados) y de eventos
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        if rx_ev_ok = '1' then got_ok <= got_ok + 1; end if;
        if rx_valid = '1' then
          cap(cap_n) <= rx_data;
          cap_n <= cap_n + 1;
        end if;
        -- vigilante de fase 0: ningun evento ni vuelco durante el silencio
        if phase0 = '1' then
          if (rx_ev_ok or rx_ev_crc or rx_ev_runt or rx_ev_drop or rx_valid) = '1' then
            p0_viol <= p0_viol + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- regenerar mii_ce alineado con el del DUT (mismo /4 desde el reset)
  process(clk)
    variable c : integer := 0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        c := 0; tb_ce <= '0';
      elsif c = 3 then
        c := 0; tb_ce <= '1';
      else
        c := c + 1; tb_ce <= '0';
      end if;
    end if;
  end process;

  -- VIGILANTE DE CABLE independiente sobre mii_txd/mii_tx_en (a tasa de nibble)
  process(clk)
    variable run5 : integer := 0;   -- nibbles 0x5 consecutivos tras silencio
    variable en_d : std_logic := '0';
    variable armed: boolean := false;
  begin
    if rising_edge(clk) then
      if rst = '0' and tb_ce = '1' then
        if mii_tx_en = '1' then
          if en_d = '0' then
            assert mii_txd = x"5"
              report "L1C cable: primer nibble tras silencio = " &
                     integer'image(to_integer(unsigned(mii_txd))) & " (esperado 5)"
              severity failure;
            run5  := 1;
            armed := true;
          elsif armed then
            if mii_txd = x"5" then
              run5 := run5 + 1;
            else
              assert run5 = 15
                report "L1C cable: preambulo de " & integer'image(run5) &
                       " nibbles 0x5 (esperado 15)" severity failure;
              assert mii_txd = x"D"
                report "L1C cable: SFD invalido" severity failure;
              armed := false;
            end if;
          end if;
        end if;
        en_d := mii_tx_en;
      end if;
    end if;
  end process;

  process
  begin
    wait for 3 ms;
    assert false report "L1C: timeout" severity failure;
    wait;
  end process;

  -- estimulo
  process
    variable dstart : integer;
    variable plen   : integer;
    variable idx    : integer := 0;
    variable eb     : std_logic_vector(7 downto 0);
    type fr_t is record f : natural; p : natural; end record;
    type fl_t is array (natural range <>) of fr_t;
    constant FR : fl_t := ((1,46),(2,100),(3,300),(4,46));
    variable exp_ok : integer := 4;

    procedure send_frame(f : natural; pl : natural) is
      variable len : integer := 14 + pl;
    begin
      for i in 0 to len - 1 loop
        tx_data <= tbyte(f, i);
        if i = len - 1 then tx_last <= '1'; else tx_last <= '0'; end if;
        tx_valid <= '1';
        loop
          wait until rising_edge(clk);
          exit when tx_ready = '1';
        end loop;
      end loop;
      tx_valid <= '0';
      tx_last  <= '0';
      loop
        wait until rising_edge(clk);
        exit when tx_busy = '0';
      end loop;
      wait for 40 * TCLK;
    end procedure;

  begin
    rst      <= '1';
    loopback <= '1';
    if G_MUT = 4 then macaddr <= x"EEDDCCBBAA99"; else macaddr <= x"EEDDCCBBAA02"; end if;
    wait for 20 * TCLK;
    wait until rising_edge(clk);
    rst <= '0';

    -- FASE 0: silencio prolongado, el RX no debe ver nada
    phase0 <= '1';
    if G_MUT = 2 then
      -- mutacion: transmitir DURANTE la fase 0 (actividad indebida)
      send_frame(0, 46);
    end if;
    wait for 400 * TCLK;
    assert p0_viol = 0
      report "L1C: fase 0 detecto " & integer'image(p0_viol) &
             " eventos RX durante el silencio" severity failure;
    phase0 <= '0';

    -- FASE 1: transmitir 4 tramas propias, todas deben volver por LOOP_INT
    send_frame(1, 46);
    send_frame(2, 100);
    send_frame(3, 300);
    send_frame(4, 46);

    wait for 300 * TCLK;

    -- firma: reconstruir lo esperado y comparar byte a byte
    idx    := 0;
    exp_ok := 4;
    if G_MUT = 3 then exp_ok := 5; end if;   -- oraculo espera una trama de mas
    -- MUT=4: la MAC del RX se cambio, el RX filtra todo (got_ok=0), pero el
    -- oraculo sigue esperando 4 aceptadas -> discrepancia forzada.
    assert got_ok = exp_ok
      report "L1C: got_ok=" & integer'image(got_ok) &
             " (esperado " & integer'image(exp_ok) & ")" severity failure;

    for k in FR'range loop
      for i in 0 to 14 + FR(k).p - 1 loop
        eb := tbyte(FR(k).f, i);
        if G_MUT = 1 and k = 1 and i = 30 then eb := eb xor x"01"; end if;
        assert cap(idx) = eb
          report "L1C: firma byte " & integer'image(idx) &
                 " (trama " & integer'image(k) & ") no coincide" severity failure;
        idx := idx + 1;
      end loop;
    end loop;
    assert cap_n = idx
      report "L1C: firma de " & integer'image(cap_n) &
             " bytes (esperados " & integer'image(idx) & ")" severity failure;

    report "L1C MAC PASS: LOOP_INT full-duplex, firma bit-identica, fase 0 limpia";
    finish;
  end process;

end architecture sim;
