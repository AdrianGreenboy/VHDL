-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 3: datapath de silicio completo a 390.625 MHz.
--   gen -> MAC TX -> FIFO -> PCS TX (Core 19) -> loopback -> PCS RX (Core 19)
--   -> MAC RX -> checker
--
-- Se lanza una rafaga de NFR tramas, se espera a que termine y drene, y los
-- 16 contadores deben coincidir con el oraculo (l3_<nombre>.txt). El contador
-- de ciclos de rafaga no es exacto (depende de la fase del gearbox): debe
-- estar entre slots y slots*33/32 + 64.
--
-- STOP_TEST: antes de la rafaga se ejecuta una rafaga CONTINUA cortada con
-- GEN_STOP a mitad de trama: debe terminar en frontera de trama (sin underrun,
-- sin /E/, sin aborto, sin caida de link) y la rafaga siguiente debe coincidir
-- exactamente con el oraculo (no puede perder su primera trama).
--
-- Criterio: LAYER3_PASS FNV32=<firma del oraculo sobre los 15 contadores>.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_mac_datapath is
  generic (
    VEC     : string  := "l3_l3a.txt";
    LEN_MIN : natural := 20;
    LEN_MAX : natural := 1514;
    STEP    : natural := 37;
    NFR     : natural := 64;
    INJ     : boolean := false;
    STOP_TEST : boolean := false
  );
end entity;

architecture sim of tb_mac_datapath is
  constant T : time := 2.56 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal start, clr, inj_p, stop, cont : std_logic := '0';
  signal st_link, st_busy, st_done, st_rx, st_tx : std_logic;
  signal ev_done, ev_crc, ev_chk, ev_ll : std_logic;
  signal cflat : std_logic_vector(16*32-1 downto 0);
  signal done_sim : boolean := false;

  constant OWN : std_logic_vector(47 downto 0) := x"2032" & x"43414D02";
  constant SRC : std_logic_vector(47 downto 0) := x"204E" & x"45474E02";
begin
  clk <= not clk after T/2 when not done_sim;

  dut: entity work.mac25g_datapath
    port map (clk_dp=>clk, rst_dp=>rst, mac_en=>'1', loopback=>'1', promisc=>'0',
              gen_cont=>cont, own_mac=>OWN, src_mac=>SRC,
              len_min=>to_unsigned(LEN_MIN, 11), len_max=>to_unsigned(LEN_MAX, 11),
              len_step=>to_unsigned(STEP, 11), gen_count=>to_unsigned(NFR, 32),
              gen_start=>start, gen_stop=>stop, cnt_clear=>clr, inj=>inj_p,
              st_link=>st_link, st_busy=>st_busy, st_done=>st_done,
              st_rx_act=>st_rx, st_tx_act=>st_tx,
              ev_done=>ev_done, ev_crc=>ev_crc, ev_chkerr=>ev_chk, ev_lnk_lo=>ev_ll,
              cnt_flat=>cflat);

  process
    file f : text;
    variable l : line;
    variable e, g, errs, slots : integer := 0;
    variable h : unsigned(31 downto 0) := x"811C9DC5";
    variable c : std_logic_vector(31 downto 0);
    variable cyc : natural := 0;
    variable lnk_ok : boolean := false;
    procedure fnv32(w : std_logic_vector(31 downto 0)) is
    begin
      for i in 0 to 3 loop
        h := h xor resize(unsigned(w(8*i+7 downto 8*i)), 32);
        h := resize(h * to_unsigned(16777619, 32), 32);
      end loop;
    end procedure;
  begin
    rst <= '1'; wait for 20*T; wait until rising_edge(clk); rst <= '0';
    -- dejar fluir idles hasta link_up (enganche del RX)
    for i in 0 to 400 loop
      wait until rising_edge(clk);
      if st_link = '1' then lnk_ok := true; end if;
    end loop;
    if not lnk_ok then report "FAIL: sin link_up con idles" severity error; errs := errs + 1; end if;
    if STOP_TEST then
      clr <= '1'; wait until rising_edge(clk); clr <= '0';
      cont <= '1';
      start <= '1'; wait until rising_edge(clk); start <= '0';
      for i in 0 to 3007 loop wait until rising_edge(clk); end loop;  -- a mitad de trama
      stop <= '1'; wait until rising_edge(clk); stop <= '0';
      cyc := 0;
      loop
        wait until rising_edge(clk);
        cyc := cyc + 1;
        assert cyc < 100_000 report "TIMEOUT esperando fin tras GEN_STOP" severity failure;
        if ev_ll = '1' then report "FAIL: LINK_LOST tras GEN_STOP" severity error; errs := errs + 1; end if;
        exit when st_done = '1';
      end loop;
      cyc := 0;
      for i in 0 to 400 loop
        wait until rising_edge(clk);
        if ev_ll = '1' then report "FAIL: LINK_LOST tras GEN_STOP" severity error; errs := errs + 1; end if;
      end loop;
      -- tx = rx_ok = chk_ok > 0 y ningun error
      if to_integer(unsigned(cflat(31 downto 0))) = 0 or
         cflat(31 downto 0) /= cflat(95 downto 64) or
         cflat(31 downto 0) /= cflat(351 downto 320) or
         unsigned(cflat(287 downto 128)) /= 0 or          -- crc..proto
         unsigned(cflat(447 downto 352)) /= 0 or          -- chk_bad, seq, rxerr
         unsigned(cflat(511 downto 480)) /= 0 then        -- underrun
        report "FAIL: GEN_STOP no termino en frontera de trama (tx=" &
          integer'image(to_integer(unsigned(cflat(31 downto 0)))) & " rx_ok=" &
          integer'image(to_integer(unsigned(cflat(95 downto 64)))) & " abort=" &
          integer'image(to_integer(unsigned(cflat(255 downto 224)))) & " underrun=" &
          integer'image(to_integer(unsigned(cflat(511 downto 480)))) & ")" severity error;
        errs := errs + 1;
      else
        report "GEN_STOP en frontera: " & integer'image(to_integer(unsigned(cflat(31 downto 0)))) &
          " tramas limpias";
      end if;
      cont <= '0';
    end if;
    clr <= '1'; wait until rising_edge(clk); clr <= '0';
    if INJ then inj_p <= '1'; wait until rising_edge(clk); inj_p <= '0'; end if;
    start <= '1'; wait until rising_edge(clk); start <= '0';
    loop
      wait until rising_edge(clk);
      cyc := cyc + 1;
      assert cyc < 3_000_000 report "TIMEOUT rafaga" severity failure;
      exit when st_done = '1';
    end loop;
    for i in 0 to 400 loop wait until rising_edge(clk); end loop;   -- drenaje

    file_open(f, VEC, read_mode);
    for i in 0 to 15 loop
      readline(f, l); read(l, e);
      c := cflat(32*i+31 downto 32*i);
      g := to_integer(unsigned(c));
      if i = 14 then
        slots := e;
        if g < slots - 3 or g > (slots * 33) / 32 + 64 then
          report "FAIL BURST_CYCLES=" & integer'image(g) & " fuera de [" &
            integer'image(slots - 3) & "," & integer'image((slots*33)/32 + 64) & "]"
            severity error;
          errs := errs + 1;
        end if;
      else
        fnv32(c);
        if g /= e then
          report "FAIL contador " & integer'image(i) & " = " & integer'image(g) &
            " esperado " & integer'image(e) severity error;
          errs := errs + 1;
        end if;
      end if;
    end loop;
    file_close(f);
    if st_link /= '1' then report "FAIL: link caido al final" severity error; errs := errs + 1; end if;

    if errs = 0 then
      report "LAYER3_PASS FNV32=0x" & to_hstring(std_logic_vector(h)) &
        " tx=" & integer'image(to_integer(unsigned(cflat(31 downto 0)))) &
        " rx_ok=" & integer'image(to_integer(unsigned(cflat(95 downto 64)))) &
        " chk_ok=" & integer'image(to_integer(unsigned(cflat(351 downto 320)))) &
        " burst=" & integer'image(to_integer(unsigned(cflat(479 downto 448)))) &
        " slots=" & integer'image(slots);
    else
      report "LAYER3_FAIL errores=" & integer'image(errs) severity error;
    end if;
    done_sim <= true;
    wait;
  end process;
end architecture;
