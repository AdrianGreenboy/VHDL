-- ============================================================================
-- tb_tl.vhd -- PCIE IP v1, verificacion capa 2 (Transaction Layer, completer EP)
--
-- El TB actua como Root Complex (requester): construye TLPs byte a byte y los
-- inyecta en el EP; captura las respuestas (CplD / MSI) y las verifica.
--
-- A) CfgRd0 de Vendor/Device ID (offset 0x00): el CplD debe traer
--    0x5043_1AF4 (Device<<16 | Vendor).
-- B) CfgWr0 a BAR0 (offset 0x10) con un patron; CfgRd0 lo relee y verifica.
-- C) MWr3: escribe 4 DW en BAR0 desde addr 0x00; luego MRd3 de cada DW y
--    verifica el CplD contra lo escrito.
-- D) MSI: se programa la direccion (cfg 0x50) y dato (0x54) via CfgWr0, se
--    dispara msi_trigger y se captura el MWr3 de MSI (dir + dato correctos).
--
-- Verificacion por captura del stream tx_* del EP.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_tl_pkg.all;

entity tb_tl is
end entity;

architecture sim of tb_tl is
  constant TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal rst : std_logic := '1';

  signal rx_valid, rx_start, rx_last : std_logic := '0';
  signal rx_data : byte_t := (others=>'0');
  signal tx_valid, tx_start, tx_last : std_logic;
  signal tx_data : byte_t;
  signal tx_ready : std_logic := '1';
  signal msi_trigger : std_logic := '0';
  signal bar0_dbg : dw_t;
  signal cfg_done : std_logic;
  signal mwr_cnt, mrd_cnt : std_logic_vector(15 downto 0);

  -- captura de la respuesta
  type cap_t is array (0 to 31) of byte_t;
  signal cap : cap_t := (others=>(others=>'0'));
  signal cap_n : integer := 0;
  signal cap_en : std_logic := '0';
begin
  clk <= '0' when fin else not clk after TCLK/2;

  u_ep : entity work.pcie_tl_ep
    generic map (BAR0_WORDS => 256)
    port map (clk=>clk, rst=>rst,
              rx_valid=>rx_valid, rx_data=>rx_data, rx_start=>rx_start,
              rx_last=>rx_last,
              tx_valid=>tx_valid, tx_data=>tx_data, tx_start=>tx_start,
              tx_last=>tx_last, tx_ready=>tx_ready,
              msi_trigger=>msi_trigger,
              bar0_dbg=>bar0_dbg, cfg_done=>cfg_done,
              mwr_cnt_o=>mwr_cnt, mrd_cnt_o=>mrd_cnt);

  -- captura del stream de respuesta. cap_n se reinicia cuando cap_en pasa a '1'.
  process(clk)
    variable prev_en : std_logic := '0';
  begin
    if rising_edge(clk) then
      if cap_en='1' and prev_en='0' then
        cap_n <= 0;
      elsif cap_en='1' and tx_valid='1' then
        if tx_start='1' then cap(0) <= tx_data; cap_n <= 1;
        elsif cap_n < 32 then cap(cap_n) <= tx_data; cap_n <= cap_n + 1; end if;
      end if;
      prev_en := cap_en;
    end if;
  end process;

  main : process
    -- envia un header 3DW (12 bytes) + opcional payload
    procedure send_hdr(b0 : byte_t; len : integer;
                       reqid : std_logic_vector(15 downto 0); tg : byte_t;
                       a : unsigned(31 downto 0); last_no_data : boolean) is
      variable hb : cap_t;
      variable lv : std_logic_vector(9 downto 0);
    begin
      lv := std_logic_vector(to_unsigned(len, 10));
      hb(0):=b0; hb(1):=x"00";
      hb(2):="000000" & lv(9 downto 8);
      hb(3):=lv(7 downto 0);
      hb(4):=reqid(15 downto 8); hb(5):=reqid(7 downto 0);
      hb(6):=tg; hb(7):=x"00";
      hb(8):=std_logic_vector(a(31 downto 24)); hb(9):=std_logic_vector(a(23 downto 16));
      hb(10):=std_logic_vector(a(15 downto 8)); hb(11):=std_logic_vector(a(7 downto 0));
      for i in 0 to 11 loop
        rx_data <= hb(i); rx_valid <= '1';
        if i=0 then rx_start<='1'; else rx_start<='0'; end if;
        if i=11 and last_no_data then rx_last<='1'; else rx_last<='0'; end if;
        wait until rising_edge(clk);
      end loop;
      rx_valid<='0'; rx_start<='0'; rx_last<='0';
    end procedure;

    procedure send_dw(d : dw_t; last : boolean) is
      type b4 is array(0 to 3) of byte_t;
      variable bb : b4;
    begin
      bb(0):=d(31 downto 24); bb(1):=d(23 downto 16);
      bb(2):=d(15 downto 8);  bb(3):=d(7 downto 0);
      for i in 0 to 3 loop
        rx_data <= bb(i); rx_valid <= '1'; rx_start<='0';
        if i=3 and last then rx_last<='1'; else rx_last<='0'; end if;
        wait until rising_edge(clk);
      end loop;
      rx_valid<='0'; rx_last<='0';
    end procedure;

    procedure wait_cpl is
    begin
      cap_en <= '1';
      -- esperar a que aparezca tx_last
      loop
        wait until rising_edge(clk);
        exit when tx_valid='1' and tx_last='1';
      end loop;
      wait until rising_edge(clk);
      cap_en <= '0';
    end procedure;

    variable dwv : dw_t;
  begin
    rst<='1'; for i in 0 to 5 loop wait until rising_edge(clk); end loop;
    rst<='0'; wait until rising_edge(clk);

    -- ===== A: CfgRd0 Vendor/Device =====
    cap_en<='1';
    send_hdr(B0_CFGRD0, 1, x"0000", x"01", to_unsigned(0,32), true);
    wait_cpl;
    -- el CplD trae 12 bytes header + 4 bytes data. data en cap(12..15)
    dwv := cap(12) & cap(13) & cap(14) & cap(15);
    assert dwv = (CFG_DEVICE_ID & CFG_VENDOR_ID)
      report "A: Vendor/Device incorrecto = " & integer'image(to_integer(unsigned(dwv)))
      severity failure;
    report "A: PASS CfgRd0 Vendor/Device = 0x5043_1AF4";

    -- ===== B: CfgWr0 a BAR0 (0x10) y relectura =====
    send_hdr(B0_CFGWR0, 1, x"0000", x"02", to_unsigned(16#10#,32), false);
    send_dw(x"DEADBEEF", true);
    for k in 0 to 10 loop wait until rising_edge(clk); end loop;
    cap_en<='1';
    send_hdr(B0_CFGRD0, 1, x"0000", x"03", to_unsigned(16#10#,32), true);
    wait_cpl;
    dwv := cap(12) & cap(13) & cap(14) & cap(15);
    assert dwv = x"DEADBEEF"
      report "B: BAR0 cfg relectura incorrecta = " & integer'image(to_integer(unsigned(dwv)))
      severity failure;
    report "B: PASS CfgWr0/CfgRd0 BAR0 = 0xDEADBEEF";

    -- ===== C: MWr3 4 DW + MRd3 verificacion =====
    send_hdr(B0_MWR3, 4, x"0000", x"04", to_unsigned(0,32), false);
    send_dw(x"11111111", false);
    send_dw(x"22222222", false);
    send_dw(x"33333333", false);
    send_dw(x"44444444", true);
    for k in 0 to 10 loop wait until rising_edge(clk); end loop;
    -- leer DW en addr 8 (indice 2) -> debe ser 0x33333333
    cap_en<='1';
    send_hdr(B0_MRD3, 1, x"0000", x"05", to_unsigned(8,32), true);
    wait_cpl;
    dwv := cap(12) & cap(13) & cap(14) & cap(15);
    assert dwv = x"33333333"
      report "C: MRd3 dato incorrecto = " & integer'image(to_integer(unsigned(dwv)))
      severity failure;
    -- leer DW en addr 12 (indice 3) -> 0x44444444
    cap_en<='1';
    send_hdr(B0_MRD3, 1, x"0000", x"06", to_unsigned(12,32), true);
    wait_cpl;
    dwv := cap(12) & cap(13) & cap(14) & cap(15);
    assert dwv = x"44444444"
      report "C: MRd3 dato2 incorrecto" severity failure;
    report "C: PASS MWr3/MRd3 sobre BAR0. mwr=" &
           integer'image(to_integer(unsigned(mwr_cnt))) & " mrd=" &
           integer'image(to_integer(unsigned(mrd_cnt)));

    -- ===== D: MSI =====
    -- programar dir MSI (cfg 0x50 -> indice 20) y dato (0x54 -> 21)
    send_hdr(B0_CFGWR0, 1, x"0000", x"07", to_unsigned(16#50#,32), false);
    send_dw(x"FEED0000", true);
    for k in 0 to 6 loop wait until rising_edge(clk); end loop;
    send_hdr(B0_CFGWR0, 1, x"0000", x"08", to_unsigned(16#54#,32), false);
    send_dw(x"0000CAFE", true);
    for k in 0 to 6 loop wait until rising_edge(clk); end loop;
    -- disparar MSI y capturar el MWr3 resultante
    cap_en<='1';
    msi_trigger<='1'; wait until rising_edge(clk); msi_trigger<='0';
    wait_cpl;
    -- header MWr3: dir en cap(8..11) = 0xFEED0000 ; dato en cap(12..15)=0xCAFE
    dwv := cap(8) & cap(9) & cap(10) & cap(11);
    assert dwv = x"FEED0000"
      report "D: dir MSI incorrecta = " & integer'image(to_integer(unsigned(dwv)))
      severity failure;
    dwv := cap(12) & cap(13) & cap(14) & cap(15);
    assert dwv = x"0000CAFE"
      report "D: dato MSI incorrecto" severity failure;
    assert cap(0) = B0_MWR3 report "D: MSI no es MWr3" severity failure;
    report "D: PASS MSI MWr3 dir=0xFEED0000 dato=0x0000CAFE";

    report "FIN SIMULACION TL: PASS @ " & time'image(now);
    fin<=true; wait;
  end process;

end architecture;
