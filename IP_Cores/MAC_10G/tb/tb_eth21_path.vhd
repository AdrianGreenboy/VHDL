-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Capas 2 y 3: eth21_txpath -> modelo de GT -> eth21_rxpath.
--   * INF = ""  : loopback por el modelo (capa 2). Rafaga de N tramas del
--     generador; el cable de TX se vuelca a DUMPF para el decodificador IEEE
--     del oraculo. Con BURSTERR se rompen cabeceras para forzar la perdida y
--     recuperacion del block lock antes de la rafaga.
--   * INF /= "" : el RX recibe un flujo IEEE del oraculo (capa 3).
-- GT_REV/GT_SWAP: orden "real" del GT del modelo. C_REV/C_SWAP: flags del
-- core. Deben coincidir para que el enlace con un tercero funcione; en
-- loopback funciona cualquier combinacion consistente.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tb_eth21_pkg.all;

entity tb_eth21_path is
  generic (
    GT_REV   : boolean := false;
    GT_SWAP  : boolean := false;
    C_REV    : natural := 0;
    C_SWAP   : natural := 0;
    OFF0     : natural := 17;
    N        : natural := 24;
    LMIN     : natural := 18;
    LMAX     : natural := 400;
    LSTEP    : natural := 53;
    GAP      : natural := 0;
    INJ      : natural := 0;
    BURSTERR : natural := 0;
    ERRB     : natural := 0;
    INF      : string  := "";
    DUMPF    : string  := ""
  );
end entity tb_eth21_path;

architecture sim of tb_eth21_path is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal start, stop, clr, inj_s, restart : std_logic := '0';
  signal busy, done, txact : std_logic;
  signal txd, rxd : std_logic_vector(63 downto 0);
  signal txh, rxh : std_logic_vector(1 downto 0);
  signal rxv, slip, errp, eof : std_logic := '0';
  signal lock, link, rxact, evcrc, evchk : std_logic;
  signal tcnt : std_logic_vector(4*32-1 downto 0);
  signal rcnt : std_logic_vector(19*32-1 downto 0);
  signal crev, cswap : std_logic;
  signal fin : boolean := false;

  function ti(v : std_logic_vector; i : natural) return integer is
  begin
    return to_integer(unsigned(v(32*i+30 downto 32*i)));
  end function;
begin
  clk <= not clk after 2 ns when not fin;
  crev  <= '1' when C_REV = 1 else '0';
  cswap <= '1' when C_SWAP = 1 else '0';

  u_tx: entity work.eth21_txpath
    port map (clk=>clk, rst=>rst, mac_en=>'1', gen_cont=>'0',
              bit_rev=>crev, hdr_swap=>cswap,
              peer_mac=>T_PEER_MAC, own_mac=>T_OWN_MAC, own_ip=>T_OWN_IP,
              peer_ip=>T_PEER_IP, sport=>T_SPORT, dport=>T_DPORT,
              len_min=>to_unsigned(LMIN, 11), len_max=>to_unsigned(LMAX, 11),
              len_step=>to_unsigned(LSTEP, 11), gen_count=>to_unsigned(N, 32),
              gen_gap=>to_unsigned(GAP, 16),
              gen_start=>start, gen_stop=>stop, cnt_clear=>clr, inj=>inj_s,
              st_busy=>busy, st_done=>done, st_tx_act=>txact,
              txdata=>txd, txheader=>txh, cnt_flat=>tcnt);

  u_gt: entity work.eth21_gt_model
    generic map (GT_REV=>GT_REV, GT_SWAP=>GT_SWAP, OFF0=>OFF0, ERR_BIT=>ERRB,
                 INF=>INF, DUMPF=>DUMPF)
    port map (clk=>clk, txdata=>txd, txheader=>txh, rxdata=>rxd, rxheader=>rxh,
              rxvalid=>rxv, rxslip=>slip, err_inj=>errp, in_eof=>eof);

  u_rx: entity work.eth21_rxpath
    generic map (SLIP_WAIT => 16)
    port map (clk=>clk, rst=>rst, promisc=>'1', bit_rev=>crev, hdr_swap=>cswap,
              own_mac=>T_OWN_MAC, peer_mac=>T_PEER_MAC, own_ip=>T_OWN_IP,
              peer_ip=>T_PEER_IP, sport=>T_SPORT, dport=>T_DPORT,
              chk_restart=>restart, cnt_clear=>clr,
              rxdata=>rxd, rxheader=>rxh, rxvalid=>rxv, rxslip=>slip,
              st_lock=>lock, st_link=>link, st_rx_act=>rxact,
              ev_crc=>evcrc, ev_chkerr=>evchk, cnt_flat=>rcnt);

  process
    variable cyc : natural;
    variable lost_seen : boolean := false;
    procedure tick(k : natural) is
    begin
      for i in 1 to k loop wait until rising_edge(clk); end loop;
    end procedure;
  begin
    tick(5); rst <= '0';
    -- espera block lock
    cyc := 0;
    while lock = '0' and cyc < 20000 loop tick(1); cyc := cyc + 1; end loop;
    if lock = '0' then
      report "NOLOCK blocks=" & integer'image(ti(rcnt, 15)) & " proto=" &
             integer'image(ti(rcnt, 7)) & " rxok=" & integer'image(ti(rcnt, 0)) &
             " slips=" & integer'image(ti(rcnt, 12));
      report "LAYER2 FAIL sin block lock" severity error;
      fin <= true; wait;
    end if;
    report "block lock tras " & integer'image(cyc) & " ciclos, slips=" &
           integer'image(ti(rcnt, 12));
    if BURSTERR = 1 then
      -- 20 cabeceras rotas en 64 bloques -> perdida de lock; despues relock
      for i in 0 to 19 loop errp <= '1'; tick(1); errp <= '0'; tick(2); end loop;
      cyc := 0;
      while cyc < 20000 loop
        tick(1); cyc := cyc + 1;
        if lock = '0' then lost_seen := true; end if;
        exit when lost_seen and lock = '1';
      end loop;
      if not (lost_seen and lock = '1') then
        report "LAYER2 FAIL sin perdida/recuperacion de lock" severity error;
        fin <= true; wait;
      end if;
      report "lock perdido y recuperado: perdidas=" & integer'image(ti(rcnt, 14));
    end if;
    tick(200);
    clr <= '1'; restart <= '1'; tick(1); clr <= '0'; restart <= '0';
    tick(4);
    if INF = "" then
      if INJ = 1 then inj_s <= '1'; tick(1); inj_s <= '0'; end if;
      start <= '1'; tick(1); start <= '0';
      cyc := 0;
      while done = '0' and cyc < 400000 loop tick(1); cyc := cyc + 1; end loop;
      tick(300);
    else
      cyc := 0;
      -- se informa al agotarse el archivo (despues el cable queda a cero)
      while eof = '0' and cyc < 400000 loop tick(1); cyc := cyc + 1; end loop;
    end if;
    report "LAYER2 PATH txf=" & integer'image(ti(tcnt, 0)) &
           " txb=" & integer'image(ti(tcnt, 1)) &
           " rxok=" & integer'image(ti(rcnt, 0)) &
           " rxb=" & integer'image(ti(rcnt, 1)) &
           " crc=" & integer'image(ti(rcnt, 2)) &
           " runt=" & integer'image(ti(rcnt, 3)) &
           " over=" & integer'image(ti(rcnt, 4)) &
           " abort=" & integer'image(ti(rcnt, 5)) &
           " filt=" & integer'image(ti(rcnt, 6)) &
           " proto=" & integer'image(ti(rcnt, 7)) &
           " cok=" & integer'image(ti(rcnt, 8)) &
           " cbad=" & integer'image(ti(rcnt, 9)) &
           " cseq=" & integer'image(ti(rcnt, 10)) &
           " crxe=" & integer'image(ti(rcnt, 11)) &
           " badsh=" & integer'image(ti(rcnt, 13)) &
           " lock=" & std_logic'image(lock);
    report "LAYER3 OS idle=" & integer'image(ti(rcnt, 16)) & " lf=" & integer'image(ti(rcnt, 17)) &
           " rf=" & integer'image(ti(rcnt, 18)) & " blocks=" & integer'image(ti(rcnt, 15));
    fin <= true;
    wait;
  end process;
end architecture sim;
