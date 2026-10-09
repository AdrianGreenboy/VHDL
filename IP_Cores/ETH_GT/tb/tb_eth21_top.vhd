-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Capa 4: core completo por registros AXI4-Lite (como lo hara el PS):
-- secuencia de reset del GT contra un modelo de estado del quad, block lock
-- por el modelo de canal (loopback), rafaga, instantanea y lectura de los 20
-- contadores; medidor de reloj; monitor de protocolo AXI (respuestas un
-- ciclo despues del handshake, sin respuestas espurias).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tb_eth21_pkg.all;

entity tb_eth21_top is
  generic (
    N     : natural := 20;
    LMIN  : natural := 18;
    LMAX  : natural := 1472;
    LSTEP : natural := 131;
    INJ   : natural := 0;
    CREV  : natural := 1;     -- flags del core (iguales en TX y RX)
    CSWAP : natural := 0
  );
end entity tb_eth21_top;

architecture sim of tb_eth21_top is
  signal aclk   : std_logic := '0';
  signal gclk   : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal awaddr, araddr : std_logic_vector(7 downto 0) := (others => '0');
  signal awvalid, wvalid, bready, arvalid, rready : std_logic := '0';
  signal awready, wready, bvalid, arready, rvalid : std_logic;
  signal wdata, rdata : std_logic_vector(31 downto 0);
  signal bresp, rresp : std_logic_vector(1 downto 0);
  signal txdata, rxdata : std_logic_vector(127 downto 0) := (others => '0');
  signal txheader, rxheader : std_logic_vector(5 downto 0) := (others => '0');
  signal txseq : std_logic_vector(6 downto 0);
  signal txmst, txusr, txpol, rxmst, rxusr, rxpol, slip, pllrst : std_logic;
  signal lb : std_logic_vector(2 downto 0);
  signal txdone, rxdone, pg, plllock : std_logic := '0';
  signal m_rxd : std_logic_vector(63 downto 0);
  signal m_rxh : std_logic_vector(1 downto 0);
  signal m_rxv : std_logic;
  signal fin : boolean := false;
  signal axi_err : natural := 0;
  signal rx_hold : std_logic := '0';
begin
  aclk <= not aclk after 5 ns when not fin;     -- 100 MHz
  gclk <= not gclk after 2 ns when not fin;     -- 250 MHz (tx = rx)

  dut: entity work.eth21_top
    generic map (ACLK_HZ => 100_000, SLIP_WAIT => 16)
    port map (
      s_axi_aclk=>aclk, s_axi_aresetn=>aresetn,
      s_axi_awaddr=>awaddr, s_axi_awvalid=>awvalid, s_axi_awready=>awready,
      s_axi_wdata=>wdata, s_axi_wstrb=>"1111", s_axi_wvalid=>wvalid, s_axi_wready=>wready,
      s_axi_bresp=>bresp, s_axi_bvalid=>bvalid, s_axi_bready=>bready,
      s_axi_araddr=>araddr, s_axi_arvalid=>arvalid, s_axi_arready=>arready,
      s_axi_rdata=>rdata, s_axi_rresp=>rresp, s_axi_rvalid=>rvalid, s_axi_rready=>rready,
      tx_clk=>gclk, rx_clk=>gclk,
      gt_txdata=>txdata, gt_txheader=>txheader, gt_txsequence=>txseq,
      gt_txmstreset=>txmst, gt_txuserrdy=>txusr, gt_txpolarity=>txpol,
      gt_txmstresetdone=>txdone,
      gt_rxdata=>rxdata, gt_rxdatavalid=>"01", gt_rxheader=>rxheader,
      gt_rxheadervalid=>"01", gt_rxgearboxslip=>slip, gt_rxmstreset=>rxmst,
      gt_rxuserrdy=>rxusr, gt_rxpolarity=>rxpol, gt_rxmstresetdone=>rxdone,
      gt_rxcdrlock=>'1', gt_powergood=>pg, gt_lcplllock=>plllock,
      gt_lcpllreset=>pllrst, gt_loopback=>lb);

  -- modelo de estado del quad: powergood, PLL y fin de reset maestro
  process
  begin
    wait for 200 ns; pg <= '1';
    loop
      wait until rising_edge(aclk);
      if pllrst = '1' then plllock <= '0';
      elsif plllock = '0' then
        for i in 1 to 30 loop wait until rising_edge(aclk); end loop;
        plllock <= '1';
      end if;
    end loop;
  end process;

  process(aclk)
    variable ct, cr : natural := 0;
  begin
    if rising_edge(aclk) then
      if txmst = '1' or txusr = '0' then ct := 0; txdone <= '0';
      elsif ct < 20 then ct := ct + 1; else txdone <= '1'; end if;
      if rxmst = '1' or rxusr = '0' or rx_hold = '1' then cr := 0; rxdone <= '0';
      elsif cr < 25 then cr := cr + 1; else rxdone <= '1'; end if;
    end if;
  end process;

  -- canal: el TX vuelve al RX por el modelo de GT (solo con loopback activo
  -- o siempre: aqui siempre, como un cable de loopback)
  u_gt: entity work.eth21_gt_model
    generic map (GT_REV => false, GT_SWAP => false, OFF0 => 29)
    port map (clk=>gclk, txdata=>txdata(63 downto 0), txheader=>txheader(1 downto 0),
              rxdata=>m_rxd, rxheader=>m_rxh, rxvalid=>m_rxv, rxslip=>slip,
              err_inj=>'0', in_eof=>open);
  rxdata(63 downto 0) <= m_rxd;
  rxheader(1 downto 0) <= m_rxh;

  -- monitor AXI: B/R solo tras un handshake, uno por uno
  process(aclk)
    variable wpend, rpend : natural := 0;
  begin
    if rising_edge(aclk) then
      if awvalid = '1' and awready = '1' then wpend := wpend + 1; end if;
      if bvalid = '1' and bready = '1' then
        if wpend = 0 then axi_err <= axi_err + 1; else wpend := wpend - 1; end if;
      end if;
      if arvalid = '1' and arready = '1' then rpend := rpend + 1; end if;
      if rvalid = '1' and rready = '1' then
        if rpend = 0 then axi_err <= axi_err + 1; else rpend := rpend - 1; end if;
      end if;
    end if;
  end process;

  process
    variable v : std_logic_vector(31 downto 0);
    variable e : natural := 0;
    variable t : natural;
    type arr is array (0 to 22) of std_logic_vector(31 downto 0);
    variable c : arr;

    procedure wr(a : natural; d : std_logic_vector(31 downto 0)) is
    begin
      awaddr <= std_logic_vector(to_unsigned(a, 8)); wdata <= d;
      awvalid <= '1'; wvalid <= '1'; bready <= '1';
      loop wait until rising_edge(aclk); exit when awready = '1'; end loop;
      awvalid <= '0'; wvalid <= '0';
      loop wait until rising_edge(aclk); exit when bvalid = '1'; end loop;
      bready <= '0';
    end procedure;
    procedure rd(a : natural; d : out std_logic_vector(31 downto 0)) is
    begin
      araddr <= std_logic_vector(to_unsigned(a, 8)); arvalid <= '1'; rready <= '1';
      loop wait until rising_edge(aclk); exit when arready = '1'; end loop;
      arvalid <= '0';
      loop wait until rising_edge(aclk); exit when rvalid = '1'; end loop;
      d := rdata; rready <= '0';
      wait until rising_edge(aclk);
    end procedure;
    procedure poll(a : natural; bit : natural; val : std_logic; lim : natural) is
      variable x : std_logic_vector(31 downto 0);
    begin
      for i in 0 to lim loop
        rd(a, x);
        exit when x(bit) = val;
        if i = lim then report "FALLO: timeout esperando bit " & integer'image(bit) &
                        " de 0x" & hexv(std_logic_vector(to_unsigned(a, 8))) severity error;
          e := e + 1; end if;
      end loop;
    end procedure;
  begin
    wait for 100 ns; wait until rising_edge(aclk); aresetn <= '1';
    for i in 0 to 5 loop wait until rising_edge(aclk); end loop;
    rd(16#00#, v);
    if v /= x"47544521" then report "FALLO ID" severity error; e := e + 1; end if;
    -- GT listo
    poll(16#10#, 21, '1', 2000);
    poll(16#10#, 22, '1', 2000);
    rd(16#10#, v);
    report "STATUS tras reset GT = 0x" & hexv(v);
    -- configuracion
    wr(16#20#, T_OWN_MAC(31 downto 0)); wr(16#24#, x"0000" & T_OWN_MAC(47 downto 32));
    wr(16#28#, T_PEER_MAC(31 downto 0)); wr(16#2C#, x"0000" & T_PEER_MAC(47 downto 32));
    wr(16#30#, T_OWN_IP); wr(16#34#, T_PEER_IP); wr(16#38#, T_SPORT & T_DPORT);
    wr(16#3C#, std_logic_vector(to_unsigned(LMAX, 16)) & std_logic_vector(to_unsigned(LMIN, 16)));
    wr(16#40#, std_logic_vector(to_unsigned(LSTEP, 32)));
    wr(16#44#, std_logic_vector(to_unsigned(N, 32)));
    v := (others => '0');
    v(0) := '1'; v(2) := '1';                         -- MAC_EN, PROMISC
    if CREV = 1 then v(4) := '1'; v(6) := '1'; end if;
    if CSWAP = 1 then v(5) := '1'; v(7) := '1'; end if;
    wr(16#08#, v);
    wr(16#0C#, x"00000002");                          -- CNT_CLEAR (captura config)
    poll(16#10#, 0, '1', 4000);                       -- block lock
    wr(16#0C#, x"00000002");
    if INJ = 1 then wr(16#0C#, x"00000010"); end if;
    wr(16#0C#, x"00000004");                          -- GEN_START
    rd(16#10#, v);
    if v(2) = '1' then report "FALLO: GEN_DONE visible justo tras START" severity error; e := e + 1; end if;
    poll(16#10#, 2, '1', 20000);
    for i in 0 to 400 loop wait until rising_edge(aclk); end loop;
    wr(16#1C#, x"00000001");
    poll(16#10#, 8, '1', 200);
    for i in 0 to 22 loop rd(16#80# + 4 * i, c(i)); end loop;
    report "LAYER4 TOP txf=" & integer'image(to_integer(unsigned(c(0)))) &
           " txb=" & integer'image(to_integer(unsigned(c(1)))) &
           " rxok=" & integer'image(to_integer(unsigned(c(2)))) &
           " rxb=" & integer'image(to_integer(unsigned(c(3)))) &
           " crc=" & integer'image(to_integer(unsigned(c(4)))) &
           " runt=" & integer'image(to_integer(unsigned(c(5)))) &
           " over=" & integer'image(to_integer(unsigned(c(6)))) &
           " abort=" & integer'image(to_integer(unsigned(c(7)))) &
           " filt=" & integer'image(to_integer(unsigned(c(8)))) &
           " proto=" & integer'image(to_integer(unsigned(c(9)))) &
           " cok=" & integer'image(to_integer(unsigned(c(10)))) &
           " cbad=" & integer'image(to_integer(unsigned(c(11)))) &
           " cseq=" & integer'image(to_integer(unsigned(c(12)))) &
           " crxe=" & integer'image(to_integer(unsigned(c(13)))) &
           " badsh=" & integer'image(to_integer(unsigned(c(17)))) &
           " lock='1'";
    report "contadores extra: burst=" & integer'image(to_integer(unsigned(c(14)))) &
           " underrun=" & integer'image(to_integer(unsigned(c(15)))) &
           " slips=" & integer'image(to_integer(unsigned(c(16)))) &
           " loss=" & integer'image(to_integer(unsigned(c(18)))) &
           " blocks=" & integer'image(to_integer(unsigned(c(19))));
    if unsigned(c(15)) /= 0 then report "FALLO underrun" severity error; e := e + 1; end if;
    -- contadores de diagnostico tras un clear con el enlace limpio
    if unsigned(c(16)) /= 0 or unsigned(c(17)) /= 0 or unsigned(c(18)) /= 0 or
       unsigned(c(21)) /= 0 or unsigned(c(22)) /= 0 then
      report "FALLO contadores de diagnostico no nulos" severity error; e := e + 1;
    end if;
    if not (unsigned(c(20)) > 100 and unsigned(c(19)) > unsigned(c(20))) then
      report "FALLO RX_BLOCKS/RX_IDLE incoherentes" severity error; e := e + 1;
    end if;
    -- medidor de reloj: ventana de 10000 aclk (100 us) a 250 MHz = 25000 ciclos
    -- -> 195 flancos de 128 ciclos
    for i in 0 to 20500 loop wait until rising_edge(aclk); end loop;
    rd(16#48#, v);
    t := to_integer(unsigned(v));
    report "TXCLK_MEAS=" & integer'image(t);
    if t < 194 or t > 196 then report "FALLO medidor de reloj" severity error; e := e + 1; end if;
    -- RX sin terminar su reset (sin cable): el TX sigue funcionando y los CMD
    -- se liberan por timeout con STATUS.CMD_TIMEOUT
    rx_hold <= '1';
    wr(16#0C#, x"00000020");                          -- GT_RESET
    poll(16#10#, 21, '1', 4000);                      -- TX listo
    rd(16#10#, v);
    if v(22) /= '0' then report "FALLO rx_ready con el RX retenido" severity error; e := e + 1; end if;
    wr(16#44#, std_logic_vector(to_unsigned(7, 32)));
    wr(16#0C#, x"00000002");                          -- CNT_CLEAR
    poll(16#10#, 9, '0', 400);
    rd(16#10#, v);
    if v(10) /= '1' then report "FALLO sin CMD_TIMEOUT con el RX en reset" severity error; e := e + 1; end if;
    wr(16#0C#, x"00000004");                          -- GEN_START (solo TX)
    poll(16#10#, 2, '1', 20000);
    for i in 0 to 300 loop wait until rising_edge(aclk); end loop;
    wr(16#1C#, x"00000001");
    poll(16#10#, 11, '1', 200);                       -- SNAP_TX
    rd(16#80#, v);
    if to_integer(unsigned(v)) /= 7 then
      report "FALLO TX con el RX caido: TX_FRAMES=" & integer'image(to_integer(unsigned(v))) severity error;
      e := e + 1;
    end if;
    rd(16#10#, v);
    if v(8) /= '0' then report "FALLO SNAP_DONE con el RX caido" severity error; e := e + 1; end if;
    if axi_err /= 0 then report "FALLO protocolo AXI" severity error; e := e + 1; end if;
    if e = 0 then report "LAYER4 checks PASS"; else report "LAYER4 checks FAIL" severity error; end if;
    fin <= true;
    wait;
  end process;
end architecture sim;
