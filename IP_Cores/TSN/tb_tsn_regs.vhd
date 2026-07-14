-- tb_tsn_regs.vhd - Capa 2: tsn_regs vs BFM de dmem (contrato de la familia)
-- rd32 muestrea rdata 1 ns despues de presentar la direccion: un rdata
-- registrado devuelve el dato de la lectura anterior y FALLA aqui.
-- Verifica: reset, enable, tabla en 3 pasos (LO/HI/IDX->pulso con payload),
-- contadores (pulsos simultaneos multi-puerto), cnt_clear con enable
-- preservado, lecturas consecutivas a direcciones distintas, Qbv y no
-- mapeado leen 0, y contabilidad exacta de pulsos tbl_wr.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_tsn_regs is
end entity;

architecture sim of tb_tsn_regs is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(8 downto 0) := (others => '0');
  signal wdata, rdata, dbg_in : std_logic_vector(31 downto 0) := (others => '0');
  signal irq, enable : std_logic;
  signal tbl_wr, tbl_vld : std_logic;
  signal tbl_idx : std_logic_vector(3 downto 0);
  signal tbl_mac : std_logic_vector(47 downto 0);
  signal tbl_port : std_logic_vector(1 downto 0);
  signal p_rx, p_tx, p_ovf, p_fcs, p_tag : std_logic_vector(3 downto 0)
    := (others => '0');
  signal status_in : std_logic_vector(11 downto 0) := (others => '0');
  signal inj_push, inj_clr, inj_go : std_logic;
  signal inj_word : std_logic_vector(31 downto 0);
  signal inj_len : unsigned(11 downto 0);
  signal inj_psel : std_logic_vector(1 downto 0);
  signal inj_busy : std_logic := '0';

  signal n_tblwr : integer := 0;
  signal last_mac : std_logic_vector(47 downto 0);
  signal last_prt : std_logic_vector(1 downto 0);
  signal last_vld : std_logic;
  signal last_idx : std_logic_vector(3 downto 0);
begin
  clk <= not clk after 5 ns;

  dut : entity work.tsn_regs
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
      wdata => wdata, rdata => rdata, irq => irq, enable => enable,
      tbl_wr => tbl_wr, tbl_idx => tbl_idx, tbl_mac => tbl_mac,
      tbl_port => tbl_port, tbl_vld => tbl_vld,
      inj_push => inj_push, inj_word => inj_word, inj_clr => inj_clr,
      inj_len => inj_len, inj_go => inj_go, inj_psel => inj_psel,
      inj_busy => inj_busy,
      p_rx => p_rx, p_tx => p_tx, p_ovf => p_ovf, p_fcs => p_fcs,
      p_tag => p_tag, status_in => status_in, dbg_in => dbg_in);

  -- monitor de pulsos de tabla
  p_mon : process
  begin
    wait until rising_edge(clk);
    if tbl_wr = '1' then
      n_tblwr  <= n_tblwr + 1;
      last_mac <= tbl_mac;
      last_prt <= tbl_port;
      last_vld <= tbl_vld;
      last_idx <= tbl_idx;
    end if;
  end process;

  p_main : process
    variable rd : std_logic_vector(31 downto 0);

    procedure wr32(a : std_logic_vector(8 downto 0);
                   d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '1'; addr <= a; wdata <= d;
      wait until rising_edge(clk);
      sel <= '0'; we <= '0';
    end procedure;

    procedure rd32(a : std_logic_vector(8 downto 0);
                   res : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '0'; addr <= a;
      wait for 1 ns;                     -- asentar el mux combinacional
      res := rdata;
      wait until rising_edge(clk);
      sel <= '0';
    end procedure;

    procedure chk(a : std_logic_vector(8 downto 0);
                  exp : std_logic_vector(31 downto 0); lbl : string) is
      variable r : std_logic_vector(31 downto 0);
    begin
      rd32(a, r);
      assert r = exp
        report lbl & ": leido " & integer'image(to_integer(unsigned(r(30 downto 0))))
               & " esperado " & integer'image(to_integer(unsigned(exp(30 downto 0))))
        severity failure;
    end procedure;

    procedure pulso(gr : integer; v : std_logic_vector(3 downto 0)) is
    begin
      wait until rising_edge(clk);
      case gr is
        when 0 => p_rx  <= v;
        when 1 => p_tx  <= v;
        when 2 => p_ovf <= v;
        when 3 => p_fcs <= v;
        when others => p_tag <= v;
      end case;
      wait until rising_edge(clk);
      p_rx <= "0000"; p_tx <= "0000"; p_ovf <= "0000";
      p_fcs <= "0000"; p_tag <= "0000";
    end procedure;
    variable hash : unsigned(31 downto 0) := (others => '0');
  begin
    wait for 30 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- 1) valores de reset
    chk(9x"000", x"00000000", "CONTROL reset");
    chk(9x"040", x"00000000", "RX_CNT0 reset");
    assert enable = '0' report "enable no es 0 en reset" severity failure;

    -- 2) enable
    wr32(9x"000", x"00000001");
    chk(9x"000", x"00000001", "CONTROL enable");
    assert enable = '1' report "enable no salio" severity failure;

    -- 3) STATUS y DBG son passthrough combinacional
    status_in <= x"ABC";
    dbg_in    <= x"DEADBEE5";
    chk(9x"004", x"00000ABC", "STATUS");
    chk(9x"0C0", x"DEADBEE5", "DBG");

    -- 4) tabla en 3 pasos: LO, HI, IDX (dispara)
    wr32(9x"008", x"33221100");                 -- MAC[31:0]
    wr32(9x"00C", x"80035544");                 -- vld=1, port=3, MAC[47:32]=5544
    chk(9x"008", x"33221100", "TBL_MAC_LO relee");
    chk(9x"00C", x"80035544", "TBL_MAC_HI relee");
    wr32(9x"010", x"00000009");                 -- idx=9: pulso
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    assert n_tblwr = 1
      report "pulsos tbl_wr=" & integer'image(n_tblwr) & " esperado 1"
      severity failure;
    assert last_mac = x"554433221100"
      report "tbl_mac mal empaquetada" severity failure;
    assert last_prt = "11" report "tbl_port /= 3" severity failure;
    assert last_vld = '1'  report "tbl_vld /= 1" severity failure;
    assert last_idx = x"9" report "tbl_idx /= 9" severity failure;
    chk(9x"010", x"00000009", "TBL_IDX relee");
    -- escrituras a LO/HI NO deben pulsar
    wr32(9x"008", x"AAAAAAAA");
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    assert n_tblwr = 1
      report "escritura a MAC_LO pulso tbl_wr" severity failure;

    -- 5) contadores: pulsos simultaneos multi-puerto y multi-grupo
    pulso(0, "1011");                           -- rx p0,p1,p3
    pulso(0, "0001");                           -- rx p0
    pulso(1, "1111");                           -- tx todos
    pulso(2, "0100");                           -- ovf p2
    pulso(3, "0010");                           -- fcs p1
    pulso(4, "1000");                           -- tag p3
    chk(9x"040", x"00000002", "RX p0");
    chk(9x"044", x"00000001", "RX p1");
    chk(9x"048", x"00000000", "RX p2");
    chk(9x"04C", x"00000001", "RX p3");
    chk(9x"050", x"00000001", "TX p0");
    chk(9x"05C", x"00000001", "TX p3");
    chk(9x"068", x"00000001", "OVF p2");
    chk(9x"074", x"00000001", "FCS p1");
    chk(9x"08C", x"00000001", "TAG p3");
    chk(9x"060", x"00000000", "OVF p0 sigue 0");

    -- 6) lecturas consecutivas a direcciones distintas (mata rdata registrado)
    wait until rising_edge(clk);
    sel <= '1'; we <= '0'; addr <= 9x"040";
    wait for 1 ns;
    assert rdata = x"00000002" report "consecutiva 1 mal" severity failure;
    wait until rising_edge(clk);
    addr <= 9x"050";
    wait for 1 ns;
    assert rdata = x"00000001" report "consecutiva 2 mal" severity failure;
    wait until rising_edge(clk);
    addr <= 9x"004";
    wait for 1 ns;
    assert rdata = x"00000ABC" report "consecutiva 3 mal" severity failure;
    wait until rising_edge(clk);
    sel <= '0';

    -- 7) cnt_clear (b1) limpia contadores y preserva enable (b0=1 escrito)
    wr32(9x"000", x"00000003");
    chk(9x"040", x"00000000", "RX p0 tras clear");
    chk(9x"050", x"00000000", "TX p0 tras clear");
    chk(9x"000", x"00000001", "CONTROL tras clear (b1 lee 0)");
    assert enable = '1' report "clear se llevo el enable" severity failure;
    -- y los contadores siguen vivos tras el clear
    pulso(0, "0001");
    chk(9x"040", x"00000001", "RX p0 tras clear+pulso");

    -- 8) Qbv reservado y no mapeado leen 0; escritura ignorada
    wr32(9x"100", x"FFFFFFFF");
    chk(9x"100", x"00000000", "Qbv lee 0");
    chk(9x"1FC", x"00000000", "Qbv fin lee 0");
    chk(9x"024", x"00000000", "hueco lee 0");
    -- sel=0 tambien lee 0
    wait until rising_edge(clk);
    addr <= 9x"040"; sel <= '0'; we <= '0';
    wait for 1 ns;
    assert rdata = x"00000000" report "rdata /= 0 con sel=0" severity failure;
    wait until rising_edge(clk);

    -- 9) inyector: INJ_LEN persiste, INJ_WDATA pulsa push, INJ_STATUS busy
    inj_busy <= '0';
    wr32(9x"024", x"0000007B");                 -- INJ_LEN = 123
    chk(9x"024", x"0000007B", "INJ_LEN relee");
    wait until rising_edge(clk);
    sel <= '1'; we <= '1'; addr <= 9x"028"; wdata <= x"DEADBEEF";
    wait until rising_edge(clk);
    sel <= '0'; we <= '0';
    wait for 1 ns;
    assert inj_push = '1' and inj_word = x"DEADBEEF"
      report "INJ_WDATA no pulso push con el dato" severity failure;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert inj_push = '0' report "inj_push no es pulso de 1 ciclo" severity failure;
    wr32(9x"020", x"00000006");                 -- go=1, port=2
    wait until rising_edge(clk);
    chk(9x"020", x"00000002", "INJ_CTRL psel relee");
    inj_busy <= '1';
    chk(9x"02C", x"00000001", "INJ_STATUS busy=1");
    inj_busy <= '0';
    chk(9x"02C", x"00000000", "INJ_STATUS busy=0");

    -- firma final
    hash := x"00000ABC" xor to_unsigned(n_tblwr, 32);
    report "regs: tblwr=" & integer'image(n_tblwr) &
           " hash=" & integer'image(to_integer(hash(30 downto 0)));
    report "TB_TSN_REGS PASS" severity note;
    std.env.finish;
  end process;
end architecture;
