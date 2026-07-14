-- ============================================================================
-- tb_mmio.vhd -- PCIE IP v1, verificacion Layer 2 del banco MMIO
--
-- Un BFM de dmem (simula al RV32) maneja dos bancos MMIO conectados
-- PIPE-a-PIPE (A=RC, B=EP). El firmware simulado:
--   A) entrena el enlace (CONTROL.start en ambos) y confirma STATUS.link_up
--      -> verifica rdata COMBINACIONAL (lectura en el mismo ciclo).
--   B) el RC empuja un TLP MWr3 (4 DW) por la FIFO TX; el EP lo recibe y
--      escribe BAR0 -> se lee REG_BAR0_LAST del EP y se verifica 0x44444444.
--   C) el RC empuja un MRd3; el EP responde CplD -> el RC drena su FIFO RX y
--      verifica el dato 0x33333333.
--   D) IRQ sticky: se comprueba que IRQ_STAT.cpl_rx se activa y se limpia W1C.
--
-- CONTRATO dmem: req + we + addr(indice DW) + wdata + wstrb; rdata COMBINACIONAL.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_mmio_pkg.all;
use work.pcie_8b10b_pkg.all;

entity tb_mmio is
end entity;

architecture sim of tb_mmio is
  constant TCLK : time := 10 ns;
  signal clk : std_logic := '0';
  signal fin : boolean := false;
  signal resetn : std_logic := '0';

  -- dmem del banco A (RC)
  signal a_req, a_we : std_logic := '0';
  signal a_addr : std_logic_vector(6 downto 0) := (others=>'0');
  signal a_wdata, a_rdata : std_logic_vector(31 downto 0);
  signal a_wstrb : std_logic_vector(3 downto 0) := "1111";
  signal a_irq : std_logic;

  -- dmem del banco B (EP)
  signal b_req, b_we : std_logic := '0';
  signal b_addr : std_logic_vector(6 downto 0) := (others=>'0');
  signal b_wdata, b_rdata : std_logic_vector(31 downto 0);
  signal b_wstrb : std_logic_vector(3 downto 0) := "1111";
  signal b_irq : std_logic;

  -- PIPE A<->B
  signal a2b_sym, b2a_sym : work.pcie_8b10b_pkg.byte_t;
  signal a2b_k, b2a_k : std_logic;
begin
  clk <= '0' when fin else not clk after TCLK/2;

  u_a : entity work.pcie_mmio
    generic map (is_rc => true, TIMEOUT_C => 5000)
    port map (clk=>clk, resetn=>resetn,
              req=>a_req, we=>a_we, addr=>a_addr, wdata=>a_wdata,
              wstrb=>a_wstrb, rdata=>a_rdata, irq=>a_irq,
              pt_sym=>a2b_sym, pt_k=>a2b_k, pr_sym=>b2a_sym, pr_k=>b2a_k);

  u_b : entity work.pcie_mmio
    generic map (is_rc => false, TIMEOUT_C => 5000)
    port map (clk=>clk, resetn=>resetn,
              req=>b_req, we=>b_we, addr=>b_addr, wdata=>b_wdata,
              wstrb=>b_wstrb, rdata=>b_rdata, irq=>b_irq,
              pt_sym=>b2a_sym, pt_k=>b2a_k, pr_sym=>a2b_sym, pr_k=>a2b_k);

  main : process
    -- escritura dmem en el banco A
    procedure wr_a(ofs : integer; d : std_logic_vector(31 downto 0)) is
    begin
      a_addr <= std_logic_vector(to_unsigned(ofs/4, 7));
      a_wdata <= d; a_we <= '1'; a_req <= '1';
      wait until rising_edge(clk);
      a_we <= '0'; a_req <= '0';
    end procedure;
    -- lectura dmem combinacional del banco A: presenta addr y lee rdata
    procedure rd_a(ofs : integer; res : out std_logic_vector(31 downto 0)) is
    begin
      a_addr <= std_logic_vector(to_unsigned(ofs/4, 7));
      a_req <= '1'; a_we <= '0';
      wait for 1 ns;               -- combinacional: rdata valido sin flanco
      res := a_rdata;
      wait until rising_edge(clk);
      a_req <= '0';
    end procedure;
    procedure wr_b(ofs : integer; d : std_logic_vector(31 downto 0)) is
    begin
      b_addr <= std_logic_vector(to_unsigned(ofs/4, 7));
      b_wdata <= d; b_we <= '1'; b_req <= '1';
      wait until rising_edge(clk);
      b_we <= '0'; b_req <= '0';
    end procedure;
    procedure rd_b(ofs : integer; res : out std_logic_vector(31 downto 0)) is
    begin
      b_addr <= std_logic_vector(to_unsigned(ofs/4, 7));
      b_req <= '1'; b_we <= '0';
      wait for 1 ns;
      res := b_rdata;
      wait until rising_edge(clk);
      b_req <= '0';
    end procedure;

    -- empuja un byte al TX FIFO del RC (con flag last en wdata(8))
    procedure push_a(b : std_logic_vector(7 downto 0); last : std_logic) is
      variable w : std_logic_vector(31 downto 0);
    begin
      w := (others=>'0'); w(7 downto 0):=b; w(8):=last;
      wr_a(REG_TX_DATA, w);
    end procedure;

    variable r : std_logic_vector(31 downto 0);
    variable c : integer;
    type b16 is array(0 to 15) of std_logic_vector(7 downto 0);
    variable buf : b16;
  begin
    resetn<='0'; for i in 0 to 6 loop wait until rising_edge(clk); end loop;
    resetn<='1'; wait until rising_edge(clk);

    -- ===== A: entrenar y verificar rdata combinacional =====
    wr_a(REG_CONTROL, x"00000001");   -- start (bit0)
    wr_b(REG_CONTROL, x"00000001");
    c := 0;
    loop
      wait until rising_edge(clk);
      c := c + 1;
      rd_a(REG_STATUS, r);
      exit when r(S_LINKUP)='1';
      assert c < 20000 report "A: no link_up" severity failure;
    end loop;
    -- confirmar que B tambien
    rd_b(REG_STATUS, r);
    assert r(S_LINKUP)='1' report "A: EP sin link_up" severity failure;
    report "A: PASS entrenamiento via MMIO, link_up leido combinacional tras " &
           integer'image(c) & " ciclos";

    for i in 0 to 50 loop wait until rising_edge(clk); end loop;

    -- ===== B: empujar MWr3 (4 DW) por FIFO TX del RC =====
    -- header 12 bytes + 16 payload = 28 bytes; last en el ultimo
    push_a(x"40", '0'); push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"04", '0'); -- MWr3 len4
    push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"04", '0'); push_a(x"00", '0'); -- reqid/tag
    push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"00", '0'); -- addr 0
    push_a(x"11", '0'); push_a(x"11", '0'); push_a(x"11", '0'); push_a(x"11", '0');
    push_a(x"22", '0'); push_a(x"22", '0'); push_a(x"22", '0'); push_a(x"22", '0');
    push_a(x"33", '0'); push_a(x"33", '0'); push_a(x"33", '0'); push_a(x"33", '0');
    push_a(x"44", '0'); push_a(x"44", '0'); push_a(x"44", '0'); push_a(x"44", '1'); -- last
    -- esperar a que el EP escriba BAR0
    c := 0;
    loop
      wait until rising_edge(clk);
      c := c + 1;
      rd_b(REG_MWR_CNT, r);
      exit when to_integer(unsigned(r)) >= 4;
      assert c < 8000 report "B: EP no escribio 4 DW, mwr=" &
        integer'image(to_integer(unsigned(r))) severity failure;
    end loop;
    rd_b(REG_MWR_CNT, r);
    report "DBG mwr_cnt="&integer'image(to_integer(unsigned(r)));
    rd_b(REG_BAR0_LAST, r);
    report "DBG bar0_last="&integer'image(to_integer(unsigned(r)));
    assert r = x"44444444" report "B: BAR0_LAST incorrecto = " &
      integer'image(to_integer(unsigned(r))) severity failure;
    report "B: PASS MWr3 via FIFO TX -> BAR0 del EP = 0x44444444";

    -- ===== C: MRd3 -> CplD -> drenar FIFO RX del RC =====
    push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"01", '0'); -- MRd3 len1
    push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"05", '0'); push_a(x"00", '0');
    push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"00", '0'); push_a(x"08", '1'); -- addr 8, last
    -- esperar respuesta en la FIFO RX del RC (RX_CTRL.level > 0)
    c := 0;
    loop
      wait until rising_edge(clk);
      c := c + 1;
      rd_a(REG_RX_CTRL, r);
      exit when to_integer(unsigned(r(15 downto 8))) >= 16;  -- CplD = 16 bytes
      assert c < 8000 report "C: RC no recibio CplD, level=" &
        integer'image(to_integer(unsigned(r(15 downto 8)))) severity failure;
    end loop;
    -- drenar 16 bytes; los ultimos 4 son el dato (0x33333333)
    for i in 0 to 15 loop
      rd_a(REG_RX_DATA, r);
      buf(i) := r(7 downto 0);
      wait until rising_edge(clk);  -- la FIFO avanza con la lectura
    end loop;
    assert buf(0) = x"4A" report "C: respuesta no es CplD, b0=" &
      integer'image(to_integer(unsigned(buf(0)))) severity failure;
    r := buf(12) & buf(13) & buf(14) & buf(15);
    assert r = x"33333333"
      report "C: CplD dato incorrecto = " &
      integer'image(to_integer(unsigned(r))) severity failure;
    report "C: PASS MRd3 -> CplD drenado de FIFO RX del RC = 0x33333333";

    -- ===== D: IRQ sticky W1C =====
    -- habilitar IRQ de cpl_rx
    wr_a(REG_IRQ_EN, x"00000002");   -- bit I_CPL_RX
    rd_a(REG_IRQ_STAT, r);
    assert r(I_CPL_RX)='1' report "D: sticky cpl_rx no seteado" severity failure;
    assert a_irq='1' report "D: irq no activa con mascara" severity failure;
    -- limpiar W1C
    wr_a(REG_IRQ_STAT, x"00000002");
    rd_a(REG_IRQ_STAT, r);
    assert r(I_CPL_RX)='0' report "D: W1C no limpio el sticky" severity failure;
    report "D: PASS IRQ sticky set + W1C clear";

    report "FIN SIMULACION MMIO: PASS @ " & time'image(now);
    fin<=true; wait;
  end process;

end architecture;
