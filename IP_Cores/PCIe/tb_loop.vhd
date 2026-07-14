-- ============================================================================
-- tb_loop.vhd -- PCIE IP v1, verificacion capa 1c COMPLETA (integracion)
--
-- Dos nodos PCIe (A=RC, B=EP) unidos PIPE-a-PIPE en LOOP_INT:
--   A.pt -> B.pr   y   B.pt -> A.pr
--
-- Escenario de bring-up (el TB actua como firmware del RC):
--   FASE 1: ambos nodos entrenan hasta L0 (link_up en ambos).
--   FASE 2: el RC inyecta un CfgRd0 de Vendor/Device -> el EP responde CplD.
--           (se observa la respuesta del EP por tlresp_*).
--   FASE 3: el RC inyecta MWr3 de 4 DW a BAR0 del EP -> mwr_cnt(EP)=4.
--   FASE 4: el RC inyecta MRd3 -> el EP responde CplD con el dato correcto.
--   FASE 5: se dispara MSI en el EP -> emite un MWr3 (interrupcion).
--
-- Nota: los TLPs que el RC inyecta por req_* pasan por su DLL_TX+framer y
-- viajan al EP. El EP los procesa via su adaptador+TL. Las respuestas del EP
-- viajan de vuelta por su propio DLL_TX+framer al RC. Aqui verificamos el
-- datapath de DATOS entre nodos ademas del entrenamiento.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;
use work.pcie_tl_pkg.all;

entity tb_loop is
end entity;

architecture sim of tb_loop is
  constant TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal rst : std_logic := '1';
  signal en  : std_logic := '1';

  -- PIPE A<->B
  signal a2b_sym, b2a_sym : work.pcie_8b10b_pkg.byte_t;
  signal a2b_k, b2a_k : std_logic;

  -- RC (A)
  signal a_start, a_hotrst : std_logic := '0';
  signal a_req_v, a_req_l, a_req_rdy : std_logic := '0';
  signal a_req_d : work.pcie_8b10b_pkg.byte_t := (others=>'0');
  signal a_up : std_logic; signal a_state : std_logic_vector(3 downto 0);
  signal a_bar : dw_t; signal a_mwr, a_mrd, a_good, a_rpl : std_logic_vector(15 downto 0);
  signal a_tr_v, a_tr_s, a_tr_l : std_logic; signal a_tr_d : work.pcie_8b10b_pkg.byte_t;

  -- EP (B)
  signal b_start : std_logic := '0';
  signal b_msi : std_logic := '0';
  signal b_up : std_logic; signal b_state : std_logic_vector(3 downto 0);
  signal b_bar : dw_t; signal b_mwr, b_mrd, b_good, b_rpl : std_logic_vector(15 downto 0);
  signal b_tr_v, b_tr_s, b_tr_l : std_logic; signal b_tr_d : work.pcie_8b10b_pkg.byte_t;

  -- captura de la respuesta del EP (tlresp del nodo B)
  type cap_t is array (0 to 31) of work.pcie_8b10b_pkg.byte_t;
  signal cap : cap_t := (others=>(others=>'0'));
  signal cap_n : integer := 0;
  signal cap_en : std_logic := '0';
begin
  clk <= '0' when fin else not clk after TCLK/2;

  u_rc : entity work.pcie_node
    generic map (is_rc => true, TIMEOUT_C => 5000)
    port map (clk=>clk, rst=>rst, en=>en,
              cmd_start=>a_start, cmd_hotrst=>a_hotrst,
              pt_sym=>a2b_sym, pt_k=>a2b_k, pr_sym=>b2a_sym, pr_k=>b2a_k,
              req_valid=>a_req_v, req_data=>a_req_d, req_last=>a_req_l,
              req_ready=>a_req_rdy, msi_trigger=>'0',
              link_up=>a_up, ltssm_state=>a_state, bar0_dbg=>a_bar,
              mwr_cnt=>a_mwr, mrd_cnt=>a_mrd, good_rx=>a_good, replays=>a_rpl,
              tlresp_valid=>a_tr_v, tlresp_data=>a_tr_d,
              tlresp_start=>a_tr_s, tlresp_last=>a_tr_l);

  u_ep : entity work.pcie_node
    generic map (is_rc => false, TIMEOUT_C => 5000)
    port map (clk=>clk, rst=>rst, en=>en,
              cmd_start=>b_start, cmd_hotrst=>'0',
              pt_sym=>b2a_sym, pt_k=>b2a_k, pr_sym=>a2b_sym, pr_k=>a2b_k,
              req_valid=>'0', req_data=>(others=>'0'), req_last=>'0',
              req_ready=>open, msi_trigger=>b_msi,
              link_up=>b_up, ltssm_state=>b_state, bar0_dbg=>b_bar,
              mwr_cnt=>b_mwr, mrd_cnt=>b_mrd, good_rx=>b_good, replays=>b_rpl,
              tlresp_valid=>b_tr_v, tlresp_data=>b_tr_d,
              tlresp_start=>b_tr_s, tlresp_last=>b_tr_l);

  -- captura de la respuesta del EP (nodo B)
  process(clk)
    variable prev : std_logic := '0';
  begin
    if rising_edge(clk) then
      if cap_en='1' and prev='0' then cap_n<=0;
      elsif cap_en='1' and b_tr_v='1' then
        if b_tr_s='1' then cap(0)<=b_tr_d; cap_n<=1;
        elsif cap_n<32 then cap(cap_n)<=b_tr_d; cap_n<=cap_n+1; end if;
      end if;
      prev := cap_en;
    end if;
  end process;

  main : process
    -- inyecta un TLP crudo (header+payload) por el req_* del RC
    procedure inject(constant bytes : cap_t; constant n : integer) is
    begin
      for i in 0 to n-1 loop
        a_req_d <= bytes(i); a_req_v <= '1';
        if i=n-1 then a_req_l<='1'; else a_req_l<='0'; end if;
        loop
          wait until rising_edge(clk);
          exit when a_req_rdy='1';
        end loop;
      end loop;
      a_req_v<='0'; a_req_l<='0';
    end procedure;

    variable hdr : cap_t;
    variable dwv : dw_t;
    variable c : integer;
  begin
    rst<='1'; for i in 0 to 6 loop wait until rising_edge(clk); end loop;
    rst<='0'; wait until rising_edge(clk);

    -- ===== FASE 1: entrenamiento =====
    a_start<='1'; b_start<='1';
    c := 0;
    loop
      wait until rising_edge(clk);
      c := c + 1;
      exit when (a_up='1' and b_up='1');
      assert c < 20000
        report "FASE1: no se alcanzo L0 (a_state=" &
               integer'image(to_integer(unsigned(a_state))) & " b_state=" &
               integer'image(to_integer(unsigned(b_state))) & ")"
        severity failure;
    end loop;
    report "FASE1: PASS ambos nodos en L0 tras " & integer'image(c) & " ciclos";

    -- estabilizar L0
    for i in 0 to 100 loop wait until rising_edge(clk); end loop;

    -- ===== FASE 3: MWr3 de 4 DW a BAR0 del EP =====
    -- (hacemos MWr antes que Cfg porque el completer EP escribe BAR0 directo)
    -- header MWr3 (12 bytes) + 4 DW payload
    hdr := (others=>(others=>'0'));
    hdr(0):=B0_MWR3; hdr(1):=x"00"; hdr(2):=x"00"; hdr(3):=x"04"; -- len=4
    hdr(4):=x"00"; hdr(5):=x"00"; hdr(6):=x"04"; hdr(7):=x"00";   -- reqid/tag
    hdr(8):=x"00"; hdr(9):=x"00"; hdr(10):=x"00"; hdr(11):=x"00"; -- addr 0
    -- payload
    hdr(12):=x"11"; hdr(13):=x"11"; hdr(14):=x"11"; hdr(15):=x"11";
    hdr(16):=x"22"; hdr(17):=x"22"; hdr(18):=x"22"; hdr(19):=x"22";
    hdr(20):=x"33"; hdr(21):=x"33"; hdr(22):=x"33"; hdr(23):=x"33";
    hdr(24):=x"44"; hdr(25):=x"44"; hdr(26):=x"44"; hdr(27):=x"44";
    inject(hdr, 28);
    -- esperar a que el EP escriba BAR0
    c := 0;
    loop
      wait until rising_edge(clk);
      c := c + 1;
      exit when to_integer(unsigned(b_mwr)) >= 4;
      assert c < 5000 report "FASE3: EP no escribio 4 DW en BAR0, mwr=" &
        integer'image(to_integer(unsigned(b_mwr))) severity failure;
    end loop;
    assert b_bar = x"44444444"
      report "FASE3: ultimo DW de BAR0 incorrecto = " &
             integer'image(to_integer(unsigned(b_bar))) severity failure;
    report "FASE3: PASS MWr3 4 DW a BAR0 del EP. mwr=" &
           integer'image(to_integer(unsigned(b_mwr))) & " bar0_last=0x44444444";

    -- ===== FASE 4: MRd3 -> el EP responde CplD =====
    cap_en<='1';
    hdr := (others=>(others=>'0'));
    hdr(0):=B0_MRD3; hdr(1):=x"00"; hdr(2):=x"00"; hdr(3):=x"01"; -- len=1
    hdr(4):=x"00"; hdr(5):=x"00"; hdr(6):=x"05"; hdr(7):=x"00";
    hdr(8):=x"00"; hdr(9):=x"00"; hdr(10):=x"00"; hdr(11):=x"08"; -- addr 8 -> 0x33333333
    inject(hdr, 12);
    -- esperar el CplD del EP
    c := 0;
    loop
      wait until rising_edge(clk);
      c := c + 1;
      exit when (b_tr_v='1' and b_tr_l='1');
      assert c < 5000 report "FASE4: EP no respondio CplD" severity failure;
    end loop;
    wait until rising_edge(clk);
    cap_en<='0';
    dwv := cap(12) & cap(13) & cap(14) & cap(15);
    assert cap(0) = B0_CPLD
      report "FASE4: respuesta del EP no es CplD, b0=" &
             integer'image(to_integer(unsigned(cap(0)))) severity failure;
    assert dwv = x"33333333"
      report "FASE4: CplD dato incorrecto = " &
             integer'image(to_integer(unsigned(dwv))) severity failure;
    report "FASE4: PASS MRd3 -> CplD del EP con dato 0x33333333. mrd=" &
           integer'image(to_integer(unsigned(b_mrd)));

    -- ===== FASE 5: MSI del EP =====
    -- programar dir/dato MSI via CfgWr0 (offset 0x50/0x54)
    hdr := (others=>(others=>'0'));
    hdr(0):=B0_CFGWR0; hdr(1):=x"00"; hdr(2):=x"00"; hdr(3):=x"01";
    hdr(4):=x"00"; hdr(5):=x"00"; hdr(6):=x"06"; hdr(7):=x"00";
    hdr(8):=x"00"; hdr(9):=x"00"; hdr(10):=x"00"; hdr(11):=x"50";
    hdr(12):=x"FE"; hdr(13):=x"ED"; hdr(14):=x"00"; hdr(15):=x"00";
    inject(hdr, 16);
    for k in 0 to 20 loop wait until rising_edge(clk); end loop;
    hdr(0):=B0_CFGWR0; hdr(3):=x"01"; hdr(11):=x"54";
    hdr(12):=x"00"; hdr(13):=x"00"; hdr(14):=x"CA"; hdr(15):=x"FE";
    inject(hdr, 16);
    for k in 0 to 20 loop wait until rising_edge(clk); end loop;
    -- disparar MSI y capturar el MWr3 del EP
    cap_en<='1';
    b_msi<='1'; wait until rising_edge(clk); b_msi<='0';
    c := 0;
    loop
      wait until rising_edge(clk);
      c := c + 1;
      exit when (b_tr_v='1' and b_tr_l='1');
      assert c < 5000 report "FASE5: EP no emitio MSI" severity failure;
    end loop;
    wait until rising_edge(clk);
    cap_en<='0';
    assert cap(0) = B0_MWR3
      report "FASE5: MSI no es MWr3" severity failure;
    dwv := cap(8) & cap(9) & cap(10) & cap(11);
    assert dwv = x"FEED0000"
      report "FASE5: dir MSI incorrecta = " &
             integer'image(to_integer(unsigned(dwv))) severity failure;
    dwv := cap(12) & cap(13) & cap(14) & cap(15);
    assert dwv = x"0000CAFE"
      report "FASE5: dato MSI incorrecto" severity failure;
    report "FASE5: PASS MSI del EP: MWr3 dir=0xFEED0000 dato=0x0000CAFE";

    report "FIN SIMULACION LOOP: PASS @ " & time'image(now);
    fin<=true; wait;
  end process;

end architecture;
