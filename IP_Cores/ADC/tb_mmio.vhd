-- ============================================================================
-- tb_mmio.vhd : Capa 2 del ADC delta-sigma soft IP v1
-- BFM dmem de la familia: wr32 (sel/we 1 ciclo), rd32 muestrea rdata 1 ns
-- despues de presentar la direccion: un rdata registrado pasa una capa 2
-- ingenua pero aqui falla de inmediato (leccion documentada de la familia).
-- Verifica: valores de reset, RW de todos los registros, mapa completo,
-- FIFO FWFT (orden, nivel, empty/full, pop en lectura, no-pop en vacio,
-- no-pop por escritura, capacidad 514 con descarte), IRQ de umbral con
-- semantica de flanco y W1C, registros DMA con pulso dma_go y dma_done,
-- DBG_STATE en 0x44, y lecturas no mapeadas en 0.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_mmio is
end entity tb_mmio;

architecture sim of tb_mmio is
  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal sel      : std_logic := '0';
  signal we       : std_logic := '0';
  signal addr     : std_logic_vector(7 downto 0)  := (others => '0');
  signal wdata    : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata    : std_logic_vector(31 downto 0);
  signal irq      : std_logic;
  signal push     : std_logic := '0';
  signal pword    : std_logic_vector(31 downto 0) := (others => '0');
  signal enable   : std_logic;
  signal src_sel  : std_logic;
  signal osr_sel  : std_logic_vector(1 downto 0);
  signal finc     : std_logic_vector(31 downto 0);
  signal ext_to   : std_logic := '0';
  signal dma_addr : std_logic_vector(31 downto 0);
  signal dma_len  : std_logic_vector(31 downto 0);
  signal dma_go   : std_logic;
  signal dma_busy : std_logic := '0';
  signal dma_done : std_logic := '0';
  signal dbg      : std_logic_vector(31 downto 0) := x"C0DEC0DE";

  signal n_go     : integer := 0;
  signal n_chk    : integer := 0;
begin

  dut : entity work.adc_mmio
    port map (
      clk           => clk,
      rst           => rst,
      sel           => sel,
      we            => we,
      addr          => addr,
      wdata         => wdata,
      rdata         => rdata,
      irq           => irq,
      smp_push_i    => push,
      smp_word_i    => pword,
      enable        => enable,
      src_sel       => src_sel,
      osr_sel       => osr_sel,
      finc          => finc,
      ext_timeout_i => ext_to,
      dma_addr      => dma_addr,
      dma_len       => dma_len,
      dma_go        => dma_go,
      dma_busy_i    => dma_busy,
      dma_done_p_i  => dma_done,
      dma_fifo_rd_i => '0',
      fifo_rdata_o  => open,
      fifo_empty_o  => open,
      dbg_i         => dbg
    );

  proc_clk : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process proc_clk;

  proc_gocnt : process (clk)
  begin
    if rising_edge(clk) then
      if dma_go = '1' then
        n_go <= n_go + 1;
      end if;
    end if;
  end process proc_gocnt;

  proc_main : process
    variable rd : std_logic_vector(31 downto 0);

    procedure wr32(a : std_logic_vector(7 downto 0);
                   d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '1'; addr <= a; wdata <= d;
      wait until rising_edge(clk);
      sel <= '0'; we <= '0';
    end procedure;

    procedure rd32(a : std_logic_vector(7 downto 0);
                   res : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '0'; addr <= a;
      wait for 1 ns;                     -- asentar el mux combinacional
      res := rdata;
      wait until rising_edge(clk);
      sel <= '0';
    end procedure;

    procedure chk(a : std_logic_vector(7 downto 0);
                  exp : std_logic_vector(31 downto 0); lbl : string) is
      variable r : std_logic_vector(31 downto 0);
    begin
      rd32(a, r);
      assert r = exp
        report "FALLO MMIO " & lbl & ": leido 0x" & to_hstring(r) &
               " esperado 0x" & to_hstring(exp)
        severity failure;
      n_chk <= n_chk + 1;
    end procedure;

    procedure chkb(cond : boolean; lbl : string) is
    begin
      assert cond
        report "FALLO MMIO " & lbl
        severity failure;
      n_chk <= n_chk + 1;
    end procedure;

    procedure empuja(d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      push <= '1'; pword <= d;
      wait until rising_edge(clk);
      push <= '0';
    end procedure;

    procedure espera(n : integer) is
    begin
      for k in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;
  begin
    rst <= '1';
    espera(4);
    rst <= '0';
    espera(4);

    -- 1) valores de reset y mapa
    chk(x"00", x"00000000", "CTRL reset");
    chk(x"08", x"00193000", "TEST_FINC reset");
    chk(x"0C", x"00000000", "FIFO_LEVEL reset");
    chk(x"04", x"00000002", "STATUS reset (empty)");
    chk(x"14", x"00000000", "IRQ_EN reset");
    chk(x"18", x"00000000", "IRQ_STAT reset");
    chk(x"1C", x"00000000", "IRQ_THRESH reset");
    chk(x"20", x"00000000", "DMA_ADDR reset");
    chk(x"24", x"00000000", "DMA_LEN reset");
    chk(x"28", x"00000000", "DMA_CTRL reset");
    chk(x"44", x"C0DEC0DE", "DBG_STATE");
    chk(x"30", x"00000000", "no mapeado lee 0");

    -- 2) RW y salidas de control
    wr32(x"00", x"0000000F");
    chk(x"00", x"0000000F", "CTRL RW");
    chkb(enable = '1' and src_sel = '1' and osr_sel = "11", "CTRL salidas 0xF");
    wr32(x"00", x"00000005");
    espera(1);
    chkb(enable = '1' and src_sel = '0' and osr_sel = "01", "CTRL salidas 0x5");
    wr32(x"08", x"00251000");
    chk(x"08", x"00251000", "TEST_FINC RW");
    chkb(finc = x"00251000", "FINC salida");
    wr32(x"20", x"70000000");
    wr32(x"24", x"00000400");
    chk(x"20", x"70000000", "DMA_ADDR RW");
    chk(x"24", x"00000400", "DMA_LEN RW");
    chkb(dma_addr = x"70000000" and dma_len = x"00000400", "DMA salidas");
    wr32(x"30", x"DEADBEEF");
    chk(x"30", x"00000000", "escritura no mapeada ignorada");
    -- lecturas seguidas: el mux combinacional debe conmutar sin latencia
    chk(x"08", x"00251000", "rdata comb A");
    chk(x"20", x"70000000", "rdata comb B");
    chk(x"04", x"00000002", "rdata comb C (STATUS)");

    -- 3) FIFO basico: orden, nivel, pop en lectura, vacio
    empuja(x"00000101");
    empuja(x"00000202");
    empuja(x"00000303");
    empuja(x"00000404");
    empuja(x"00000505");
    espera(5);
    chk(x"0C", x"00000005", "LEVEL=5");
    chk(x"04", x"00000000", "STATUS no vacio");
    chk(x"10", x"00000101", "FIFO orden 1");
    chk(x"10", x"00000202", "FIFO orden 2");
    chk(x"10", x"00000303", "FIFO orden 3");
    espera(3);
    chk(x"0C", x"00000002", "LEVEL=2 tras 3 pops");
    chk(x"10", x"00000404", "FIFO orden 4");
    chk(x"10", x"00000505", "FIFO orden 5");
    espera(3);
    chk(x"0C", x"00000000", "LEVEL=0");
    chk(x"04", x"00000002", "STATUS vacio de nuevo");
    chk(x"10", x"00000000", "lectura en vacio devuelve 0");
    espera(3);
    chk(x"0C", x"00000000", "sin underflow");
    -- escritura a FIFO_DATA no hace pop (RO)
    empuja(x"00000A0A");
    espera(4);
    wr32(x"10", x"FFFFFFFF");
    espera(3);
    chk(x"0C", x"00000001", "escritura a 0x10 no hace pop");
    chk(x"10", x"00000A0A", "dato intacto tras escritura a 0x10");
    espera(3);

    -- 4) IRQ de umbral: flanco + W1C
    wr32(x"1C", x"00000004");
    wr32(x"14", x"00000001");
    empuja(x"00000001");
    empuja(x"00000002");
    empuja(x"00000003");
    espera(5);
    chk(x"18", x"00000000", "IRQ_STAT 0 bajo umbral");
    chkb(irq = '0', "irq 0 bajo umbral");
    empuja(x"00000004");
    espera(5);
    chk(x"18", x"00000001", "IRQ_STAT umbral");
    chkb(irq = '1', "irq activo");
    wr32(x"18", x"00000001");
    espera(3);
    chk(x"18", x"00000000", "W1C limpia y no re-dispara (flanco)");
    chkb(irq = '0', "irq limpio");
    chk(x"10", x"00000001", "drena 1 (nivel 3)");
    espera(3);
    empuja(x"00000005");
    espera(5);
    chk(x"18", x"00000001", "nuevo flanco re-dispara");
    wr32(x"18", x"00000001");
    chk(x"10", x"00000002", "drena");
    chk(x"10", x"00000003", "drena");
    chk(x"10", x"00000004", "drena");
    chk(x"10", x"00000005", "drena");
    wr32(x"1C", x"00000000");
    espera(3);

    -- 5) registros DMA: pulso go, busy, done -> IRQ
    chkb(n_go = 0, "dma_go inicial 0");
    wr32(x"28", x"00000001");
    espera(3);
    chkb(n_go = 1, "dma_go 1 pulso exacto");
    dma_busy <= '1';
    espera(2);
    chk(x"04", x"0000000A", "STATUS busy (b3) + vacio (b1)");
    chk(x"28", x"00000001", "DMA_CTRL lee busy");
    dma_busy <= '0';
    wr32(x"14", x"00000002");
    wait until rising_edge(clk);
    dma_done <= '1';
    wait until rising_edge(clk);
    dma_done <= '0';
    espera(3);
    chk(x"18", x"00000002", "IRQ_STAT dma_done");
    chkb(irq = '1', "irq por dma_done");
    wr32(x"18", x"00000002");
    espera(2);
    chkb(irq = '0', "irq limpio tras W1C");
    wr32(x"14", x"00000000");

    -- 6) capacidad: 512 BRAM + 2 etapas FWFT = 514, descarte al llenar
    wait until rising_edge(clk);
    push <= '1';
    for k in 0 to 515 loop
      pword <= std_logic_vector(to_unsigned(k, 32));
      wait until rising_edge(clk);
    end loop;
    push <= '0';
    espera(6);
    chk(x"0C", std_logic_vector(to_unsigned(514, 32)), "LEVEL=514 (capacidad)");
    chk(x"04", x"00000004", "STATUS full");
    for k in 0 to 513 loop
      chk(x"10", std_logic_vector(to_unsigned(k, 32)), "drenado " & integer'image(k));
    end loop;
    espera(4);
    chk(x"0C", x"00000000", "LEVEL=0 tras drenado total");
    chk(x"04", x"00000002", "STATUS vacio final");

    report "FIN SIMULACION MMIO: PASS NCHK=" & integer'image(n_chk) &
           " @ " & time'image(now);
    finish;
  end process proc_main;

end architecture sim;
