-- ============================================================================
-- tb_dll.vhd -- PCIE IP v1, verificacion capa 1a/1b (Data Link Layer)
--
-- Topologia: DLL_TX -> [cable: puede corromper 1 byte de un TLP] -> DLL_RX.
-- El RX genera ak_req/ak_is_nak/ak_seq que se realimentan al TX (lazo de
-- ACK/NAK). El cable reenvia fr_* como in_* con in_start (primer byte tras
-- fr_start) e in_last (= fr_last).
--
-- A) LIMPIO: enviar 20 TLPs de longitudes variadas sin corrupcion. Todos deben
--    ACKearse; el TX debe purgar el replay buffer (inflight->0) y replays==0.
--    good_rx == 20, bad_rx == 0.
-- B) CORRUPCION: enviar 10 TLPs; corromper el LCRC del 4o. El RX debe: aceptar
--    0..2, NAK en el 3 (seq del 4o llega mal), el TX retransmite desde ahi, y
--    al final todos los 10 quedan ACKeados (good_rx crece hasta 10, replays>=1).
-- C) MUTACION del verificador: si se corrompe un byte de payload (no CRC), el
--    LCRC tambien debe fallar -> NAK. Comprueba que el CRC cubre el payload,
--    no solo la cola.
--
-- Nota de alcance: el DLL_RX v1 valida CRC+seq y genera ACK/NAK; la reentrega
-- de payload a la TL se cablea en el paso 5. Aqui verificamos el lazo de
-- fiabilidad (seq, LCRC, ACK/NAK, replay, purga), que es el objetivo de L1a/1b.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.pcie_dll_pkg.all;

entity tb_dll is
end entity;

architecture sim of tb_dll is
  constant TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;

  signal rst : std_logic := '1';

  -- TL -> TX
  signal tl_valid, tl_last, tl_ready : std_logic := '0';
  signal tl_data : byte_t := (others=>'0');

  -- TX -> cable
  signal fr_valid, fr_last, fr_ready, fr_start : std_logic;
  signal fr_data : byte_t;

  -- cable -> RX
  signal in_valid, in_start, in_last : std_logic := '0';
  signal in_data : byte_t := (others=>'0');

  -- RX -> ACK/NAK -> TX
  signal ak_req, ak_is_nak : std_logic;
  signal ak_seq : std_logic_vector(11 downto 0);

  -- monitores
  signal nseq, acked, nextrx : std_logic_vector(11 downto 0);
  signal inflight : std_logic_vector(7 downto 0);
  signal replays, good_rx, bad_rx : std_logic_vector(15 downto 0);

  -- control del cable (corrupcion)
  signal corrupt_en  : std_logic := '0';
  signal corrupt_tlp : integer := -1;   -- indice de TLP a corromper
  signal corrupt_pos : integer := 0;    -- byte dentro del TLP (contando desde start)
  signal tlp_idx     : integer := -1;   -- indice de TLP actual en el cable
  signal byte_idx    : integer := 0;
  signal await_first : std_logic := '0';

  -- fr_ready siempre '1' (RX/cable nunca frena en este TB)
begin
  clk <= '0' when fin else not clk after TCLK/2;
  fr_ready <= '1';

  u_tx : entity work.pcie_dll_tx
    generic map (MAX_TLP => 64, REPLAY_SLOTS => 8)
    port map (clk=>clk, rst=>rst,
              tl_valid=>tl_valid, tl_data=>tl_data, tl_last=>tl_last,
              tl_ready=>tl_ready,
              fr_valid=>fr_valid, fr_data=>fr_data, fr_last=>fr_last,
              fr_ready=>fr_ready, fr_start=>fr_start,
              ak_valid=>ak_req, ak_is_nak=>ak_is_nak, ak_seq=>ak_seq,
              nseq_o=>nseq, acked_o=>acked, inflight_o=>inflight,
              replays_o=>replays);

  u_rx : entity work.pcie_dll_rx
    port map (clk=>clk, rst=>rst,
              in_valid=>in_valid, in_data=>in_data, in_start=>in_start,
              in_last=>in_last,
              tl_valid=>open, tl_data=>open, tl_last=>open,
              ak_req=>ak_req, ak_is_nak=>ak_is_nak, ak_seq=>ak_seq,
              good_o=>good_rx, bad_o=>bad_rx, nextrx_o=>nextrx);

  -- ---------- CABLE: fr_* -> in_* con corrupcion opcional ----------
  -- fr_start llega un ciclo ANTES del primer byte valido. Latcheamos "esperando
  -- primer byte" y marcamos in_start en el primer fr_valid siguiente.
  process(clk)
    variable d : byte_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        in_valid <= '0'; in_start <= '0'; in_last <= '0';
        tlp_idx <= -1; byte_idx <= 0; await_first <= '0';
      else
        in_valid <= fr_valid;
        in_last  <= fr_last;
        in_start <= '0';
        d := fr_data;

        if fr_start = '1' then
          await_first <= '1';
          tlp_idx  <= tlp_idx + 1;
          byte_idx <= 0;
        elsif fr_valid = '1' then
          if await_first = '1' then
            in_start <= '1';
            await_first <= '0';
            byte_idx <= 0;
          else
            byte_idx <= byte_idx + 1;
          end if;
        end if;

        -- corromper el byte objetivo del TLP objetivo
        if corrupt_en = '1' and fr_valid = '1' and tlp_idx = corrupt_tlp
           and byte_idx = corrupt_pos then
          d := d xor x"FF";
        end if;
        in_data <= d;
      end if;
    end if;
  end process;

  -- ---------- estimulo ----------
  main : process
    variable s1 : positive := 5; variable s2 : positive := 13;
    variable rr : real; variable pick : integer;
    procedure rnd(hi:in integer; res:out integer) is begin
      uniform(s1,s2,rr); res:=integer(floor(rr*real(hi+1)));
      if res>hi then res:=hi; end if; end procedure;

    procedure send_tlp(len : in integer) is
    begin
      -- espera a que el TX este listo (T_IDLE)
      loop
        wait until rising_edge(clk);
        exit when tl_ready = '1';
      end loop;
      for i in 0 to len-1 loop
        tl_data  <= std_logic_vector(to_unsigned((i*7 + len) mod 256, 8));
        tl_valid <= '1';
        if i = len-1 then tl_last <= '1'; else tl_last <= '0'; end if;
        loop
          wait until rising_edge(clk);
          exit when tl_ready = '0';   -- el TX arranco (salio de IDLE)
        end loop;
        -- mantener el byte hasta que sea consumido en T_NEW_PAY
        -- el TX consume 1 byte/ciclo en T_NEW_PAY; sincronizamos por fr
        exit when false;
      end loop;
      tl_valid <= '0'; tl_last <= '0';
    end procedure;

    variable c : integer;
  begin
    rst <= '1';
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;
    rst <= '0'; wait until rising_edge(clk);

    -- ====== A: 20 TLPs limpios ======
    corrupt_en <= '0';
    for t in 0 to 19 loop
      rnd(8, pick); pick := pick + 4;   -- longitud 4..12
      -- arrancar el TLP: presentar primer byte y esperar que el TX salga de
      -- IDLE (tl_ready cae). Mantener cada byte hasta que tl_ready='1'.
      for i in 0 to pick-1 loop
        tl_data  <= std_logic_vector(to_unsigned((i*7+t) mod 256,8));
        tl_valid <= '1';
        if i=pick-1 then tl_last<='1'; else tl_last<='0'; end if;
        -- esperar a que el TX consuma este byte (tl_ready='1' en el flanco)
        loop
          wait until rising_edge(clk);
          exit when tl_ready = '1';
        end loop;
      end loop;
      tl_valid <= '0'; tl_last <= '0';
      -- dejar que termine (emision de CRC + END + ACK de vuelta)
      for k in 0 to 30 loop wait until rising_edge(clk); end loop;
    end loop;

    -- esperar a que se drene todo
    for k in 0 to 400 loop wait until rising_edge(clk); end loop;
    assert to_integer(unsigned(good_rx)) = 20
      report "A: good_rx != 20 = " & integer'image(to_integer(unsigned(good_rx)))
      severity failure;
    assert to_integer(unsigned(bad_rx)) = 0
      report "A: bad_rx != 0 = " & integer'image(to_integer(unsigned(bad_rx)))
      severity failure;
    assert to_integer(unsigned(replays)) = 0
      report "A: hubo replays sin corrupcion = " &
             integer'image(to_integer(unsigned(replays)))
      severity failure;
    assert to_integer(unsigned(inflight)) = 0
      report "A: replay buffer no purgado, inflight = " &
             integer'image(to_integer(unsigned(inflight)))
      severity failure;
    report "A: PASS 20 TLPs limpios, good=20 bad=0 replays=0 inflight=0";

    -- ====== B: corrupcion del LCRC del 4o TLP -> NAK + replay ======
    rst <= '1';
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;
    rst <= '0'; wait until rising_edge(clk);
    -- corromper el TLP indice 3, byte cerca del final (LCRC). Un TLP de 8 bytes
    -- de payload tiene: 2(seq)+8(pay)+4(lcrc)=14 bytes; el LCRC empieza en
    -- byte_idx 10. Corrompemos byte_idx=11 (dentro del LCRC).
    corrupt_en  <= '1';
    corrupt_tlp <= 3;
    corrupt_pos <= 11;
    for t in 0 to 9 loop
      -- longitud fija 8 para posicion de LCRC predecible
      for i in 0 to 7 loop
        tl_data  <= std_logic_vector(to_unsigned((i*3+t) mod 256,8));
        tl_valid <= '1';
        if i=7 then tl_last<='1'; else tl_last<='0'; end if;
        loop wait until rising_edge(clk); exit when tl_ready='1'; end loop;
      end loop;
      tl_valid <= '0'; tl_last <= '0';
      for k in 0 to 40 loop wait until rising_edge(clk); end loop;
    end loop;
    -- drenar y permitir replay
    for k in 0 to 600 loop wait until rising_edge(clk); end loop;
    -- tras el replay, los 10 TLPs deben quedar buenos; hubo >=1 NAK/replay
    assert to_integer(unsigned(replays)) >= 1
      report "B: no hubo replay tras corromper LCRC" severity failure;
    assert to_integer(unsigned(bad_rx)) >= 1
      report "B: el RX no detecto el LCRC corrupto" severity failure;
    assert to_integer(unsigned(good_rx)) = 10
      report "B: no se recuperaron los 10 TLPs, good=" &
             integer'image(to_integer(unsigned(good_rx))) severity failure;
    assert to_integer(unsigned(inflight)) = 0
      report "B: replay buffer no purgado tras recuperacion, inflight=" &
             integer'image(to_integer(unsigned(inflight))) severity failure;
    report "B: PASS corrupcion LCRC recuperada. good=10 bad=" &
           integer'image(to_integer(unsigned(bad_rx))) & " replays=" &
           integer'image(to_integer(unsigned(replays)));

    -- ====== C: corrupcion de PAYLOAD (no CRC) del 2o TLP ======
    rst <= '1';
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;
    rst <= '0'; wait until rising_edge(clk);
    corrupt_en  <= '1';
    corrupt_tlp <= 2;
    corrupt_pos <= 4;    -- byte de payload (seq=0,1; payload empieza en 2)
    for t in 0 to 5 loop
      for i in 0 to 7 loop
        tl_data  <= std_logic_vector(to_unsigned((i*5+t) mod 256,8));
        tl_valid <= '1';
        if i=7 then tl_last<='1'; else tl_last<='0'; end if;
        loop wait until rising_edge(clk); exit when tl_ready='1'; end loop;
      end loop;
      tl_valid <= '0'; tl_last <= '0';
      for k in 0 to 40 loop wait until rising_edge(clk); end loop;
    end loop;
    for k in 0 to 600 loop wait until rising_edge(clk); end loop;
    assert to_integer(unsigned(bad_rx)) >= 1
      report "C: el LCRC no cubrio el payload (corrupcion no detectada)"
      severity failure;
    assert to_integer(unsigned(good_rx)) = 6
      report "C: no se recuperaron los 6 TLPs, good=" &
             integer'image(to_integer(unsigned(good_rx))) severity failure;
    report "C: PASS corrupcion de payload detectada y recuperada. good=6 bad=" &
           integer'image(to_integer(unsigned(bad_rx)));

    report "FIN SIMULACION DLL: PASS @ " & time'image(now);
    fin <= true; wait;
  end process;

end architecture;
