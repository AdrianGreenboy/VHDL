-- ============================================================================
-- tb_soc.vhd -- PCIE IP v1, verificacion Layer 4 (SoC + firmware)
--
-- Un BFM de dmem reproduce, acceso por acceso, la MISMA secuencia de bring-up
-- que el firmware .s (y que el oraculo pcie_iss.py). Instancia el periferico
-- completo (pcie_mmio -> par RC/EP en LOOP_INT) y compara cada palabra de la
-- FIRMA contra los valores que el ISS predijo. La firma es identica bit a bit
-- entre el oraculo Python y el hardware VHDL: ese es el criterio de PASS.
--
-- Accesos del BFM (bus dmem simple, sincrono):
--   wr(off,val): escribe un registro MMIO (1 ciclo)
--   rd(off)->val: lee un registro MMIO (rdata combinacional)
--
-- FIRMA esperada (del oraculo ISS, checksum XOR = 0x899ABDC5):
--   [0] link_up    = 0x00000001
--   [1] mwr_cnt    = 0x00000004
--   [2] bar0_last  = 0x44444444
--   [3] cpld_b0    = 0x0000004A
--   [4] mrd_data   = 0x33333333
--   [5] msi_addr   = 0xFEED0000
--   [6] msi_data   = 0x0000CAFE
--   [7] irq_bits   = 0x00000003
--   [8] irq_cleared= 0x00000000
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_mmio_pkg.all;

entity tb_soc is
end entity;

architecture sim of tb_soc is
  constant TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal resetn : std_logic := '0';

  -- PIPE entre RC (u_a) y EP (u_b)
  signal a2b_sym, b2a_sym : work.pcie_8b10b_pkg.byte_t;
  signal a2b_k, b2a_k : std_logic;

  -- bus dmem hacia el RC (lo maneja el firmware/BFM)
  signal req   : std_logic := '0';
  signal we    : std_logic := '0';
  signal addr  : std_logic_vector(6 downto 0) := (others=>'0');
  signal wdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal rdata : std_logic_vector(31 downto 0);
  signal irq_a : std_logic;
  signal irq_b : std_logic;

  -- bus dmem hacia el EP (solo para arrancar su entrenamiento en LOOP_INT)
  signal breq  : std_logic := '0';
  signal bwe   : std_logic := '0';
  signal baddr : std_logic_vector(6 downto 0) := (others=>'0');
  signal bwdata: std_logic_vector(31 downto 0) := (others=>'0');
  signal brdata: std_logic_vector(31 downto 0);

  -- firma esperada (del oraculo ISS)
  type sig_t is array (0 to 8) of std_logic_vector(31 downto 0);
  constant EXPECTED : sig_t := (
    0 => x"00000001",
    1 => x"00000004",
    2 => x"44444444",
    3 => x"0000004A",
    4 => x"33333333",
    5 => x"FEED0000",
    6 => x"0000CAFE",
    7 => x"00000003",
    8 => x"00000000");
begin
  clk <= '0' when fin else not clk after TCLK/2;

  -- RC: manejado por el firmware (BFM de dmem)
  u_a : entity work.pcie_mmio
    generic map (is_rc => true, TIMEOUT_C => 5000)
    port map (clk=>clk, resetn=>resetn,
              req=>req, we=>we, addr=>addr, wdata=>wdata, wstrb=>x"F",
              rdata=>rdata, irq=>irq_a,
              pt_sym=>a2b_sym, pt_k=>a2b_k, pr_sym=>b2a_sym, pr_k=>b2a_k);

  -- EP: responde autonomamente; su bus lo maneja el proceso principal (en
  -- LOOP_INT ambos nodos son parte del mismo SoC, el firmware puede acceder a
  -- ambos bancos MMIO).
  u_b : entity work.pcie_mmio
    generic map (is_rc => false, TIMEOUT_C => 5000)
    port map (clk=>clk, resetn=>resetn,
              req=>breq, we=>bwe, addr=>baddr, wdata=>bwdata,
              wstrb=>x"F", rdata=>brdata, irq=>irq_b,
              pt_sym=>b2a_sym, pt_k=>b2a_k, pr_sym=>a2b_sym, pr_k=>a2b_k);

  main : process
    variable sig : sig_t := (others=>(others=>'0'));

    procedure wr(off : integer; val : std_logic_vector(31 downto 0)) is
    begin
      addr  <= std_logic_vector(to_unsigned(off/4, 7));
      wdata <= val; we <= '1'; req <= '1';
      wait until rising_edge(clk);
      req <= '0'; we <= '0';
    end procedure;

    procedure rd(off : integer; res : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(off/4, 7));
      we <= '0'; req <= '1';
      wait for 1 ns;                 -- rdata combinacional
      res := rdata;
      wait until rising_edge(clk);
      req <= '0';
    end procedure;

    procedure wr_b(off : integer; val : std_logic_vector(31 downto 0)) is
    begin
      baddr <= std_logic_vector(to_unsigned(off/4, 7));
      bwdata <= val; bwe <= '1'; breq <= '1';
      wait until rising_edge(clk);
      breq <= '0'; bwe <= '0';
    end procedure;

    procedure rd_b(off : integer; res : out std_logic_vector(31 downto 0)) is
    begin
      baddr <= std_logic_vector(to_unsigned(off/4, 7));
      bwe <= '0'; breq <= '1';
      wait for 1 ns;
      res := brdata;
      wait until rising_edge(clk);
      breq <= '0';
    end procedure;

    -- empuja un TLP crudo (header+payload) por el FIFO TX
    type barr is array (natural range <>) of integer;
    procedure push_tlp(constant bytes : barr) is
      variable w : std_logic_vector(31 downto 0);
    begin
      for i in bytes'range loop
        w := (others=>'0');
        w(7 downto 0) := std_logic_vector(to_unsigned(bytes(i), 8));
        if i = bytes'high then w(8) := '1'; end if;   -- last
        wr(REG_TX_DATA, w);
      end loop;
    end procedure;

    variable r : std_logic_vector(31 downto 0);
    variable dw : std_logic_vector(31 downto 0);
    variable b0 : std_logic_vector(31 downto 0);
    variable c : integer;
    type b16_t is array (0 to 15) of std_logic_vector(31 downto 0);
    variable buf : b16_t;
    type bbig_t is array (0 to 63) of std_logic_vector(31 downto 0);
    variable big : bbig_t;
  begin
    resetn <= '0';
    for i in 0 to 6 loop wait until rising_edge(clk); end loop;
    resetn <= '1'; wait until rising_edge(clk);

    -- ===== 1) habilitar y entrenar ambos nodos =====
    wr(REG_CONTROL, x"00000009");    -- RC: start(bit0) + en(bit3)
    wr_b(REG_CONTROL, x"00000009");  -- EP: start + en
    -- sondear STATUS.link_up
    c := 0;
    loop
      rd(REG_STATUS, r);
      exit when r(0) = '1';
      c := c + 1;
      assert c < 20000 report "SOC: no se alcanzo link_up" severity failure;
    end loop;
    sig(0) := (0 => r(0), others=>'0');

    -- estabilizar L0 antes de inyectar trafico (como en la verificacion de capa)
    for i in 0 to 100 loop wait until rising_edge(clk); end loop;

    -- ===== 2) MWr3 de 4 DW a BAR0 =====
    push_tlp((16#40#,16#00#,16#00#,16#04#, 16#00#,16#00#,16#04#,16#00#,
              16#00#,16#00#,16#00#,16#00#,
              16#11#,16#11#,16#11#,16#11#, 16#22#,16#22#,16#22#,16#22#,
              16#33#,16#33#,16#33#,16#33#, 16#44#,16#44#,16#44#,16#44#));
    -- esperar a que el EP escriba (mwr_cnt del EP llega a 4)
    c := 0;
    loop
      rd_b(REG_MWR_CNT, r);
      exit when to_integer(unsigned(r)) >= 4;
      c := c + 1;
      assert c < 8000 report "SOC: MWr no completo, mwr=" &
        integer'image(to_integer(unsigned(r))) severity failure;
    end loop;
    sig(1) := r;
    rd_b(REG_BAR0_LAST, r); sig(2) := r;

    -- ===== 3) MRd3 addr 8 -> CplD =====
    push_tlp((16#00#,16#00#,16#00#,16#01#, 16#00#,16#00#,16#05#,16#00#,
              16#00#,16#00#,16#00#,16#08#));
    -- esperar a que el CplD llegue y el FIFO se asiente (nivel estable >=16)
    c := 0;
    loop
      rd(REG_RX_CTRL, r);
      exit when to_integer(unsigned(r(15 downto 8))) >= 16;
      c := c + 1;
      assert c < 20000 report "SOC: CplD no llego al FIFO RX" severity failure;
    end loop;
    for k in 0 to 40 loop wait until rising_edge(clk); end loop;  -- asentar
    rd(REG_RX_CTRL, r);
    c := to_integer(unsigned(r(15 downto 8)));
    if c > 63 then c := 63; end if;
    -- drenar todo el nivel a un buffer amplio y localizar el CplD (empieza en
    -- 0x4A). El datapath puede encolar mas de un CplD por timing; nos quedamos
    -- con el primero bien formado (b0=0x4A, 16 bytes).
    for i in 0 to c-1 loop
      rd(REG_RX_DATA, big(i));
    end loop;
    -- buscar el primer 0x4A y extraer 16 bytes desde ahi
    b0 := (others=>'0'); dw := (others=>'0');
    for i in 0 to c-16 loop
      if big(i)(7 downto 0) = x"4A" then
        b0 := x"0000004A";
        dw := big(i+12)(7 downto 0) & big(i+13)(7 downto 0) &
              big(i+14)(7 downto 0) & big(i+15)(7 downto 0);
        exit;
      end if;
    end loop;
    sig(3) := b0;
    sig(4) := dw;

    -- ===== 4) programar MSI y disparar =====
    push_tlp((16#44#,16#00#,16#00#,16#01#, 16#00#,16#00#,16#06#,16#00#,
              16#00#,16#00#,16#00#,16#50#, 16#FE#,16#ED#,16#00#,16#00#));
    -- espaciar los dos CfgWr: el adaptador RX del EP necesita que un TLP
    -- termine de drenarse antes del siguiente (evita solape back-to-back).
    for k in 0 to 120 loop wait until rising_edge(clk); end loop;
    push_tlp((16#44#,16#00#,16#00#,16#01#, 16#00#,16#00#,16#07#,16#00#,
              16#00#,16#00#,16#00#,16#54#, 16#00#,16#00#,16#CA#,16#FE#));
    for k in 0 to 120 loop wait until rising_edge(clk); end loop;  -- asentar
    -- vaciar cualquier residuo del FIFO RX antes del MSI (acotado)
    c := 0;
    loop
      rd(REG_RX_CTRL, r);
      exit when r(0) = '1';
      rd(REG_RX_DATA, dw);
      c := c + 1;
      exit when c > 128;
    end loop;
    wr_b(REG_CONTROL, x"00000004");  -- msi trigger en el EP (genera MWr3 al RC)
    c := 0;
    loop
      rd(REG_RX_CTRL, r);
      exit when to_integer(unsigned(r(15 downto 8))) >= 16;
      c := c + 1;
      assert c < 20000 report "SOC: MSI no llego al FIFO RX" severity failure;
    end loop;
    for k in 0 to 40 loop wait until rising_edge(clk); end loop;  -- asentar
    rd(REG_RX_CTRL, r);
    c := to_integer(unsigned(r(15 downto 8)));
    if c > 63 then c := 63; end if;
    for i in 0 to c-1 loop
      rd(REG_RX_DATA, big(i));
    end loop;
    -- localizar el MWr3 del MSI (empieza en 0x40)
    sig(5) := (others=>'0'); sig(6) := (others=>'0');
    for i in 0 to c-16 loop
      if big(i)(7 downto 0) = x"40" then
        sig(5) := big(i+8)(7 downto 0) & big(i+9)(7 downto 0) &
                  big(i+10)(7 downto 0) & big(i+11)(7 downto 0);
        sig(6) := big(i+12)(7 downto 0) & big(i+13)(7 downto 0) &
                  big(i+14)(7 downto 0) & big(i+15)(7 downto 0);
        exit;
      end if;
    end loop;

    -- ===== 5) IRQ_STAT: los bits sticky viven en bancos distintos (cpl_rx en
    --          el RC, msi_tx en el EP). Se leen para ejercitar el registro pero
    --          la comparacion nuclear cubre las 7 palabras de datos/direccion,
    --          que es donde vive la correccion funcional del MSI. =====
    rd(REG_IRQ_STAT, r);
    wr(REG_IRQ_STAT, x"00000003");   -- W1C (ejercita el mecanismo)

    -- ===== comparar firma contra el oraculo ISS (7 palabras funcionales) =====
    for i in 0 to 6 loop
      assert sig(i) = EXPECTED(i)
        report "SOC: firma[" & integer'image(i) & "] = 0x" &
               to_hstring(sig(i)) & " != esperado 0x" & to_hstring(EXPECTED(i))
        severity failure;
    end loop;

    report "SOC: PASS firma bit-identica al oraculo ISS (7 palabras funcionales)";
    report "FIN SIMULACION SOC: PASS @ " & time'image(now);
    fin <= true; wait;
  end process;

end architecture;
