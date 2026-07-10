-- tb_eth_tx_l1a.vhd — capa 1a: motor TX MII contra un modelo receptor MII
-- independiente por eventos. El receptor NO reutiliza la logica del DUT:
-- decodifica el flujo de nibbles por si mismo y comprueba el FCS con una
-- implementacion CRC byte a byte distinta (anti modo comun).
--
-- Tramas deterministas (misma formula en estimulo y comprobador):
--   f0: payload 10  -> padding a 60 bytes de datos
--   f1: payload 46  -> exactamente 60, sin padding
--   f2: payload 100 -> back-to-back con f3 (verifica IPG minimo)
--   f3: payload 300
--   f4: payload 46, destino broadcast
--
-- G_MUT (mutaciones sobre el cable, DEBEN fallar):
--   0 = sin mutacion (PASS)
--   1 = bit invertido en un nibble de datos de f2      -> byte no coincide
--   2 = bit invertido en un nibble del FCS de f1       -> FCS incorrecto
--   3 = nibble 3 del preambulo de f0 corrompido a 0x7  -> preambulo invalido
--   4 = tx_en forzado a 0 en mitad de f2 (truncada)    -> trama runt
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.eth_pkg.all;

entity tb_eth_tx_l1a is
  generic (G_MUT : integer := 0);
end entity tb_eth_tx_l1a;

architecture sim of tb_eth_tx_l1a is

  constant TCLK    : time := 10 ns;               -- 100 MHz
  constant NFRAMES : integer := 5;

  type nat_arr is array (natural range <>) of natural;
  constant PLEN : nat_arr(0 to NFRAMES-1) := (10, 46, 100, 300, 46);

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ce  : std_logic := '0';

  signal tx_data           : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_valid, tx_last : std_logic := '0';
  signal tx_ready, tx_busy : std_logic;
  signal underrun          : std_logic;
  signal txd               : std_logic_vector(3 downto 0);
  signal tx_en             : std_logic;

  -- lineas hacia el receptor, tras el mutador (1 nibble de retardo)
  signal rxd   : std_logic_vector(3 downto 0) := (others => '0');
  signal rx_en : std_logic := '0';

  signal rx_frames : integer := 0;

  -- byte i de la trama f (cabecera 14 + payload), determinista en ambos lados
  function frame_byte(f : natural; i : natural) return std_logic_vector is
    constant DST_B : nat_arr(0 to 5) := (16#02#, 16#11#, 16#22#, 16#33#, 16#44#, 16#55#);
    constant BCAST : nat_arr(0 to 5) := (255, 255, 255, 255, 255, 255);
    constant SRC_B : nat_arr(0 to 5) := (16#02#, 16#AA#, 16#BB#, 16#CC#, 16#DD#, 16#EE#);
    variable b : natural;
  begin
    if i < 6 then
      if f = 4 then b := BCAST(i); else b := DST_B(i); end if;
    elsif i < 12 then
      b := SRC_B(i - 6);
    elsif i = 12 then
      b := 16#88#;
    elsif i = 13 then
      b := 16#B5#;
    else
      b := (f * 7 + (i - 14) * 13 + 5) mod 256;
    end if;
    return std_logic_vector(to_unsigned(b, 8));
  end function;

  -- CRC-32 byte a byte, implementacion PROPIA del banco (anti modo comun)
  function crc32_byte(crc : std_logic_vector(31 downto 0);
                      b   : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable c : std_logic_vector(31 downto 0) := crc;
  begin
    for i in 0 to 7 loop
      if (c(0) xor b(i)) = '1' then
        c := ('0' & c(31 downto 1)) xor x"EDB88320";
      else
        c := '0' & c(31 downto 1);
      end if;
    end loop;
    return c;
  end function;

begin

  clk <= not clk after TCLK / 2;

  -- mii_ce: 1 pulso de cada 4 ciclos (tasa de nibble de 25 MHz)
  process(clk)
    variable c : integer := 0;
  begin
    if rising_edge(clk) then
      if c = 3 then ce <= '1'; c := 0; else ce <= '0'; c := c + 1; end if;
    end if;
  end process;

  dut : entity work.eth_tx_mii
    port map (
      clk => clk, rst => rst, mii_ce => ce,
      tx_data => tx_data, tx_valid => tx_valid, tx_last => tx_last,
      tx_ready => tx_ready, tx_busy => tx_busy, underrun => underrun,
      txd => txd, tx_en => tx_en);

  -- mutador de cable: re-registra (retardo de 1 nibble) y corrompe segun G_MUT
  process(clk)
    variable nib  : integer := 0;
    variable fr   : integer := 0;
    variable en_d : std_logic := '0';
    variable d    : std_logic_vector(3 downto 0);
    variable e    : std_logic;
  begin
    if rising_edge(clk) then
      if ce = '1' then
        if tx_en = '1' then
          if en_d = '0' then nib := 0; else nib := nib + 1; end if;
        elsif en_d = '1' then
          fr := fr + 1;
        end if;
        en_d := tx_en;
        d := txd;
        e := tx_en;
        case G_MUT is
          when 1 => if fr = 2 and nib = 60  and tx_en = '1' then d := txd xor "0001"; end if;
          when 2 => if fr = 1 and nib = 140 and tx_en = '1' then d := txd xor "0010"; end if;
          when 3 => if fr = 0 and nib = 3   and tx_en = '1' then d := x"7"; end if;
          when 4 => if fr = 2 and nib >= 100 then e := '0'; end if;
          when others => null;
        end case;
        rxd   <= d;
        rx_en <= e;
      end if;
    end if;
  end process;

  -- receptor MII independiente por eventos
  process
    type byte_arr is array (0 to 2047) of std_logic_vector(7 downto 0);
    variable buf      : byte_arr;
    variable nbytes   : integer;
    variable nib_cnt  : integer;
    variable lo       : std_logic_vector(3 downto 0);
    variable gap      : integer := 1000;          -- hueco inicial "infinito"
    variable f        : integer := 0;
    variable crc      : std_logic_vector(31 downto 0);
    variable fcs_calc : std_logic_vector(31 downto 0);
    variable fcs_rx   : std_logic_vector(31 downto 0);
    variable dlen     : integer;
    variable exp_len  : integer;
    variable exp_b    : std_logic_vector(7 downto 0);
  begin
    wait until rising_edge(clk) and ce = '1';
    if rx_en = '1' then
      -- inicio de trama: IPG previo suficiente
      assert gap >= 24
        report "L1A: IPG de " & integer'image(gap) & " nibbles (minimo 24)"
        severity failure;
      -- preambulo: exactamente 15 nibbles 0x5 seguidos del SFD 0xD
      nib_cnt := 0;
      while rx_en = '1' and rxd = x"5" loop
        nib_cnt := nib_cnt + 1;
        wait until rising_edge(clk) and ce = '1';
      end loop;
      assert nib_cnt = 15
        report "L1A: preambulo con " & integer'image(nib_cnt) &
               " nibbles 0x5 (esperados 15) en trama " & integer'image(f)
        severity failure;
      assert rx_en = '1' and rxd = x"D"
        report "L1A: SFD invalido tras el preambulo en trama " & integer'image(f)
        severity failure;
      wait until rising_edge(clk) and ce = '1';
      -- datos + FCS hasta que caiga rx_en
      nib_cnt := 0;
      nbytes  := 0;
      while rx_en = '1' loop
        if (nib_cnt mod 2) = 0 then
          lo := rxd;
        else
          buf(nbytes) := rxd & lo;               -- nibble bajo primero
          nbytes := nbytes + 1;
        end if;
        nib_cnt := nib_cnt + 1;
        wait until rising_edge(clk) and ce = '1';
      end loop;
      assert (nib_cnt mod 2) = 0
        report "L1A: numero impar de nibbles en trama " & integer'image(f)
        severity failure;
      assert nbytes >= 64
        report "L1A: trama runt de " & integer'image(nbytes) & " bytes"
        severity failure;
      assert f < NFRAMES
        report "L1A: trama inesperada (indice fuera de tabla)"
        severity failure;
      dlen    := nbytes - 4;
      exp_len := 14 + PLEN(f);
      if exp_len < 60 then exp_len := 60; end if;
      assert dlen = exp_len
        report "L1A: longitud de datos " & integer'image(dlen) &
               " (esperada " & integer'image(exp_len) & ") en trama " & integer'image(f)
        severity failure;
      -- datos byte a byte (incluido el padding a cero)
      for i in 0 to dlen - 1 loop
        if i < 14 + PLEN(f) then
          exp_b := frame_byte(f, i);
        else
          exp_b := x"00";
        end if;
        assert buf(i) = exp_b
          report "L1A: byte " & integer'image(i) & " de trama " & integer'image(f) &
                 " no coincide"
          severity failure;
      end loop;
      -- FCS con la implementacion propia byte a byte
      crc := CRC32_INIT;
      for i in 0 to dlen - 1 loop
        crc := crc32_byte(crc, buf(i));
      end loop;
      fcs_calc := not crc;
      fcs_rx   := buf(dlen + 3) & buf(dlen + 2) & buf(dlen + 1) & buf(dlen);
      assert fcs_rx = fcs_calc
        report "L1A: FCS incorrecto en trama " & integer'image(f)
        severity failure;
      f := f + 1;
      rx_frames <= f;
      gap := 1;                                   -- la muestra de caida cuenta como hueco
    else
      if gap < 1000 then gap := gap + 1; end if;
    end if;
  end process;

  -- vigilante de underrun: no debe ocurrir nunca en esta capa
  process(clk)
  begin
    if rising_edge(clk) then
      assert underrun /= '1'
        report "L1A: underrun inesperado del motor TX"
        severity failure;
    end if;
  end process;

  -- temporizador de guardia
  process
  begin
    wait for 1 ms;
    assert false report "L1A: timeout de simulacion" severity failure;
    wait;
  end process;

  -- estimulo
  process
    variable len : integer;
  begin
    rst <= '1';
    wait for 20 * TCLK;
    wait until rising_edge(clk);
    rst <= '0';
    for f in 0 to NFRAMES - 1 loop
      len := 14 + PLEN(f);
      for i in 0 to len - 1 loop
        tx_data <= frame_byte(f, i);
        if i = len - 1 then tx_last <= '1'; else tx_last <= '0'; end if;
        tx_valid <= '1';
        loop
          wait until rising_edge(clk);
          exit when tx_ready = '1';
        end loop;
      end loop;
      -- f2 -> f3 back-to-back (valid se mantiene para verificar el IPG minimo)
      if f /= 2 then
        tx_valid <= '0';
        tx_last  <= '0';
        loop
          wait until rising_edge(clk);
          exit when tx_busy = '0';
        end loop;
        wait for 40 * TCLK;                       -- hueco extra entre tramas
      end if;
    end loop;
    tx_valid <= '0';
    tx_last  <= '0';
    loop
      wait until rising_edge(clk);
      exit when tx_busy = '0';
    end loop;
    wait for 200 * TCLK;
    assert rx_frames = NFRAMES
      report "L1A: recibidas " & integer'image(rx_frames) &
             " tramas de " & integer'image(NFRAMES)
      severity failure;
    report "L1A TX PASS: " & integer'image(rx_frames) & " tramas verificadas";
    finish;
  end process;

end architecture sim;
