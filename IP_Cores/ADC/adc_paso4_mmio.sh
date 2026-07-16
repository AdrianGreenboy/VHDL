#!/bin/bash
# ============================================================================
# adc_paso4_mmio.sh : ADC delta-sigma soft IP v1 - Paso 4 (capa 2)
# Banco MMIO (mapa congelado, rdata COMBINACIONAL) + FIFO de muestras
# 512x32 (BRAM SDP + etapa FWFT, capacidad 514) contra BFM dmem de la
# familia (rd32 muestrea a 1 ns: un rdata registrado falla de inmediato).
# TB dirigido: reset, RW, mapa completo, FIFO (orden/nivel/empty/full/
# pop-en-lectura/no-pop-en-vacio/no-pop-por-escritura/capacidad con
# descarte), IRQ de umbral (flanco + W1C), registros DMA (pulso go, busy,
# done->IRQ), DBG_STATE en 0x44. 5 mutaciones.
# Uso: bash adc_paso4_mmio.sh
# Linea final esperada:
# ADC PASO4 MMIO: PASS NCHK=567 MUT=5/5 @ 17775000000 fs
# ============================================================================
(
set -e
DIR="$HOME/adc_ip"
mkdir -p "$DIR"
cd "$DIR"

# ------------------------------------------------------------------ FIFO ---
cat > adc_fifo.vhd << 'EOF_F'
-- ============================================================================
-- adc_fifo.vhd : FIFO de muestras del ADC delta-sigma soft IP v1
-- Almacenamiento en BRAM 512x32 con molde SDP canonico (un puerto de
-- escritura sincrona, un puerto de lectura sincrona con enable) + etapa de
-- salida FWFT de 2 registros (rd_word, head). El head esta siempre
-- disponible en rd_data cuando empty='0', lo que permite que el banco MMIO
-- presente FIFO_DATA con rdata COMBINACIONAL (contrato dmem de la familia).
-- Capacidad total: 512 (BRAM) + 2 (etapas) = 514 palabras.
-- rst sincrono activo alto (convencion del banco de registros).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_fifo is
  generic (
    LOG2_DEPTH : natural := 9  -- 512 palabras de BRAM
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(31 downto 0);
    rd_en   : in  std_logic;   -- pop del head (ignorado si empty)
    rd_data : out std_logic_vector(31 downto 0);
    empty   : out std_logic;
    full    : out std_logic;
    level   : out unsigned(LOG2_DEPTH + 1 downto 0)
  );
end entity adc_fifo;

architecture rtl of adc_fifo is
  constant C_DEPTH : natural := 2**LOG2_DEPTH;

  type ram_t is array (0 to C_DEPTH - 1) of std_logic_vector(31 downto 0);
  signal buf : ram_t;
  attribute ram_style : string;
  attribute ram_style of buf : signal is "block";

  signal wr_ptr  : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal rd_ptr  : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal cnt_ram : unsigned(LOG2_DEPTH downto 0) := (others => '0');  -- 0..512

  signal rd_word : std_logic_vector(31 downto 0) := (others => '0');
  signal head    : std_logic_vector(31 downto 0) := (others => '0');
  signal rv      : std_logic := '0';  -- rd_word valido
  signal hv      : std_logic := '0';  -- head valido

  signal full_i  : std_logic;
  signal pop     : std_logic;
  signal adv_h   : std_logic;
  signal adv_r   : std_logic;
  signal wr_ok   : std_logic;
begin

  full_i <= '1' when cnt_ram = to_unsigned(C_DEPTH, cnt_ram'length) else '0';
  pop    <= rd_en and hv;
  adv_h  <= rv and ((not hv) or pop);
  adv_r  <= '1' when (cnt_ram /= 0) and ((rv = '0') or (adv_h = '1')) else '0';
  wr_ok  <= wr_en and (not full_i);

  proc_fifo : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_ptr  <= (others => '0');
        rd_ptr  <= (others => '0');
        cnt_ram <= (others => '0');
        rv      <= '0';
        hv      <= '0';
      else
        -- puerto de escritura sincrona (molde SDP)
        if wr_ok = '1' then
          buf(to_integer(wr_ptr)) <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end if;
        -- puerto de lectura sincrona con enable (molde SDP)
        if adv_r = '1' then
          rd_word <= buf(to_integer(rd_ptr));
          rd_ptr  <= rd_ptr + 1;
        end if;
        if (wr_ok = '1') and (adv_r = '0') then
          cnt_ram <= cnt_ram + 1;
        elsif (wr_ok = '0') and (adv_r = '1') then
          cnt_ram <= cnt_ram - 1;
        end if;
        rv <= adv_r or (rv and (not adv_h));
        if adv_h = '1' then
          head <= rd_word;
        end if;
        hv <= adv_h or (hv and (not pop));
      end if;
    end if;
  end process proc_fifo;

  rd_data <= head;
  empty   <= not hv;
  full    <= full_i;

  proc_level : process (all)
    variable v : unsigned(level'length - 1 downto 0);
  begin
    v := resize(cnt_ram, level'length);
    if rv = '1' then
      v := v + 1;
    end if;
    if hv = '1' then
      v := v + 1;
    end if;
    level <= v;
  end process proc_level;

end architecture rtl;
EOF_F

# ------------------------------------------------------------------ REGS ---
cat > adc_regs.vhd << 'EOF_R'
-- ============================================================================
-- adc_regs.vhd : Banco de registros MMIO del ADC delta-sigma soft IP v1
-- Contrato dmem de la familia: sel/we/addr/wdata sincronos, rdata
-- COMBINACIONAL (un rdata registrado pasa una capa 2 ingenua pero rompe
-- capa 4: cada lw devuelve el dato de la lectura anterior).
--
-- Mapa (congelado en scope freeze, addr de 8 bits, byte-address):
--   0x00 CTRL       rw : b0 enable, b1 src_sel, [3:2] osr_sel
--   0x04 STATUS     ro : b0 ext_timeout, b1 fifo_empty, b2 fifo_full,
--                        b3 dma_busy
--   0x08 TEST_FINC  rw : incremento de fase del generador (reset 0x00193000)
--   0x0C FIFO_LEVEL ro : [9:0] nivel (0..514)
--   0x10 FIFO_DATA  ro : pop en lectura; [31:24] tag/canal, [23:0] muestra;
--                        lectura con FIFO vacia devuelve 0 y no hace pop
--   0x14 IRQ_EN     rw : b0 umbral FIFO, b1 dma_done
--   0x18 IRQ_STAT   w1c: b0 umbral FIFO (flanco de nivel>=umbral), b1 dma_done
--   0x1C IRQ_THRESH rw : [9:0] umbral (0 = deshabilitado)
--   0x20 DMA_ADDR   rw
--   0x24 DMA_LEN    rw
--   0x28 DMA_CTRL   w  : b0=1 dispara dma_go (pulso); lectura: b0 dma_busy
--   0x44 DBG_STATE  ro : dbg_i
--   resto: lee 0, escritura ignorada
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_regs is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;  -- sincrono, activo alto
    -- bus dmem
    sel           : in  std_logic;
    we            : in  std_logic;
    addr          : in  std_logic_vector(7 downto 0);
    wdata         : in  std_logic_vector(31 downto 0);
    rdata         : out std_logic_vector(31 downto 0);  -- COMBINACIONAL
    irq           : out std_logic;
    -- control hacia adc_core
    enable        : out std_logic;
    src_sel       : out std_logic;
    osr_sel       : out std_logic_vector(1 downto 0);
    finc          : out std_logic_vector(31 downto 0);
    -- interfaz FIFO
    fifo_rd       : out std_logic;
    fifo_rdata    : in  std_logic_vector(31 downto 0);
    fifo_level    : in  unsigned(9 downto 0);
    fifo_empty    : in  std_logic;
    fifo_full     : in  std_logic;
    -- estado del datapath
    ext_timeout_i : in  std_logic;
    -- DMA (motor en paso 5)
    dma_addr      : out std_logic_vector(31 downto 0);
    dma_len       : out std_logic_vector(31 downto 0);
    dma_go        : out std_logic;  -- pulso
    dma_busy_i    : in  std_logic;
    dma_done_p_i  : in  std_logic;  -- pulso
    -- debug
    dbg_i         : in  std_logic_vector(31 downto 0)
  );
end entity adc_regs;

architecture rtl of adc_regs is
  signal ctrl_r   : std_logic_vector(3 downto 0)  := (others => '0');
  signal finc_r   : std_logic_vector(31 downto 0) := x"00193000";
  signal irqen_r  : std_logic_vector(1 downto 0)  := (others => '0');
  signal irqst_r  : std_logic_vector(1 downto 0)  := (others => '0');
  signal thr_r    : unsigned(9 downto 0)          := (others => '0');
  signal daddr_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal dlen_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal dgo_r    : std_logic := '0';

  signal thr_c    : std_logic;  -- condicion nivel >= umbral
  signal thr_cr   : std_logic;  -- registrada (deteccion de flanco)
  signal thr_ev   : std_logic;

  signal rdata_mux : std_logic_vector(31 downto 0);
begin

  thr_c  <= '1' when (thr_r /= 0) and (fifo_level >= thr_r) else '0';
  thr_ev <= thr_c and (not thr_cr);

  proc_regs : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ctrl_r  <= (others => '0');
        finc_r  <= x"00193000";
        irqen_r <= (others => '0');
        irqst_r <= (others => '0');
        thr_r   <= (others => '0');
        daddr_r <= (others => '0');
        dlen_r  <= (others => '0');
        dgo_r   <= '0';
        thr_cr  <= '0';
      else
        dgo_r  <= '0';
        thr_cr <= thr_c;

        -- escrituras
        if (sel = '1') and (we = '1') then
          case addr(7 downto 2) is
            when "000000" => ctrl_r  <= wdata(3 downto 0);            -- 0x00
            when "000010" => finc_r  <= wdata;                        -- 0x08
            when "000101" => irqen_r <= wdata(1 downto 0);            -- 0x14
            when "000111" => thr_r   <= unsigned(wdata(9 downto 0));  -- 0x1C
            when "001000" => daddr_r <= wdata;                        -- 0x20
            when "001001" => dlen_r  <= wdata;                        -- 0x24
            when "001010" => dgo_r   <= wdata(0);                     -- 0x28
            when others   => null;
          end case;
        end if;

        -- IRQ_STAT: eventos ponen, W1C limpia; el evento gana al clear
        if (sel = '1') and (we = '1') and (addr(7 downto 2) = "000110") then
          irqst_r <= irqst_r and (not wdata(1 downto 0));             -- 0x18
        end if;
        if thr_ev = '1' then
          irqst_r(0) <= '1';
        end if;
        if dma_done_p_i = '1' then
          irqst_r(1) <= '1';
        end if;
      end if;
    end if;
  end process proc_regs;

  -- pop de FIFO: lectura de FIFO_DATA (0x10) con FIFO no vacia
  fifo_rd <= sel and (not we) and (not fifo_empty)
             when addr(7 downto 2) = "000100" else '0';

  -- mux de lectura COMBINACIONAL (contrato dmem de la familia)
  proc_rmux : process (all)
  begin
    rdata_mux <= (others => '0');
    case addr(7 downto 2) is
      when "000000" =>                                              -- 0x00
        rdata_mux(3 downto 0) <= ctrl_r;
      when "000001" =>                                              -- 0x04
        rdata_mux(0) <= ext_timeout_i;
        rdata_mux(1) <= fifo_empty;
        rdata_mux(2) <= fifo_full;
        rdata_mux(3) <= dma_busy_i;
      when "000010" =>                                              -- 0x08
        rdata_mux <= finc_r;
      when "000011" =>                                              -- 0x0C
        rdata_mux(9 downto 0) <= std_logic_vector(fifo_level);
      when "000100" =>                                              -- 0x10
        if fifo_empty = '0' then
          rdata_mux <= fifo_rdata;
        end if;
      when "000101" =>                                              -- 0x14
        rdata_mux(1 downto 0) <= irqen_r;
      when "000110" =>                                              -- 0x18
        rdata_mux(1 downto 0) <= irqst_r;
      when "000111" =>                                              -- 0x1C
        rdata_mux(9 downto 0) <= std_logic_vector(thr_r);
      when "001000" =>                                              -- 0x20
        rdata_mux <= daddr_r;
      when "001001" =>                                              -- 0x24
        rdata_mux <= dlen_r;
      when "001010" =>                                              -- 0x28
        rdata_mux(0) <= dma_busy_i;
      when "010001" =>                                              -- 0x44
        rdata_mux <= dbg_i;
      when others =>
        null;
    end case;
  end process proc_rmux;

  rdata <= rdata_mux;

  enable   <= ctrl_r(0);
  src_sel  <= ctrl_r(1);
  osr_sel  <= ctrl_r(3 downto 2);
  finc     <= finc_r;
  dma_addr <= daddr_r;
  dma_len  <= dlen_r;
  dma_go   <= dgo_r;
  irq      <= (irqst_r(0) and irqen_r(0)) or (irqst_r(1) and irqen_r(1));

end architecture rtl;
EOF_R

# ------------------------------------------------------------- SUBSISTEMA --
cat > adc_mmio.vhd << 'EOF_S'
-- ============================================================================
-- adc_mmio.vhd : Subsistema MMIO del ADC delta-sigma soft IP v1
-- adc_regs + adc_fifo cableados. El lado de empuje de la FIFO recibe la
-- muestra etiquetada ([31:24] tag/canal = 0x00 en v1, [23:0] muestra Q1.23);
-- en el top del paso 6 lo alimenta sample_valid de adc_core, en la capa 2
-- lo alimenta el testbench directamente.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_mmio is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;  -- sincrono, activo alto
    -- bus dmem
    sel           : in  std_logic;
    we            : in  std_logic;
    addr          : in  std_logic_vector(7 downto 0);
    wdata         : in  std_logic_vector(31 downto 0);
    rdata         : out std_logic_vector(31 downto 0);
    irq           : out std_logic;
    -- empuje de muestras (del datapath / TB)
    smp_push_i    : in  std_logic;
    smp_word_i    : in  std_logic_vector(31 downto 0);
    -- control hacia adc_core
    enable        : out std_logic;
    src_sel       : out std_logic;
    osr_sel       : out std_logic_vector(1 downto 0);
    finc          : out std_logic_vector(31 downto 0);
    -- estado del datapath
    ext_timeout_i : in  std_logic;
    -- DMA (motor en paso 5)
    dma_addr      : out std_logic_vector(31 downto 0);
    dma_len       : out std_logic_vector(31 downto 0);
    dma_go        : out std_logic;
    dma_busy_i    : in  std_logic;
    dma_done_p_i  : in  std_logic;
    -- acceso del DMA a la FIFO (paso 5; abierto en capa 2)
    dma_fifo_rd_i : in  std_logic;
    fifo_rdata_o  : out std_logic_vector(31 downto 0);
    fifo_empty_o  : out std_logic;
    -- debug
    dbg_i         : in  std_logic_vector(31 downto 0)
  );
end entity adc_mmio;

architecture rtl of adc_mmio is
  signal f_rd    : std_logic;
  signal f_rdata : std_logic_vector(31 downto 0);
  signal f_level : unsigned(10 downto 0);
  signal f_empty : std_logic;
  signal f_full  : std_logic;
  signal mmio_rd : std_logic;
begin

  u_fifo : entity work.adc_fifo
    generic map (
      LOG2_DEPTH => 9
    )
    port map (
      clk     => clk,
      rst     => rst,
      wr_en   => smp_push_i,
      wr_data => smp_word_i,
      rd_en   => f_rd,
      rd_data => f_rdata,
      empty   => f_empty,
      full    => f_full,
      level   => f_level
    );

  -- pop por MMIO o por el motor DMA (paso 5)
  f_rd <= mmio_rd or dma_fifo_rd_i;

  u_regs : entity work.adc_regs
    port map (
      clk           => clk,
      rst           => rst,
      sel           => sel,
      we            => we,
      addr          => addr,
      wdata         => wdata,
      rdata         => rdata,
      irq           => irq,
      enable        => enable,
      src_sel       => src_sel,
      osr_sel       => osr_sel,
      finc          => finc,
      fifo_rd       => mmio_rd,
      fifo_rdata    => f_rdata,
      fifo_level    => f_level(9 downto 0),
      fifo_empty    => f_empty,
      fifo_full     => f_full,
      ext_timeout_i => ext_timeout_i,
      dma_addr      => dma_addr,
      dma_len       => dma_len,
      dma_go        => dma_go,
      dma_busy_i    => dma_busy_i,
      dma_done_p_i  => dma_done_p_i,
      dbg_i         => dbg_i
    );

  fifo_rdata_o <= f_rdata;
  fifo_empty_o <= f_empty;

end architecture rtl;
EOF_S

# -------------------------------------------------------------------- TB ---
cat > tb_mmio.vhd << 'EOF_TB'
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
EOF_TB

# --------------------------------------------------------- oro + mutantes --
rm -rf build4 && mkdir build4 && cd build4
ghdl -a --std=08 --workdir=. ../adc_fifo.vhd ../adc_regs.vhd ../adc_mmio.vhd ../tb_mmio.vhd
ghdl -e --std=08 --workdir=. tb_mmio
GOLD=$(ghdl -r --std=08 --workdir=. tb_mmio 2>&1 | grep -m1 "FIN SIMULACION MMIO: PASS" || true)
cd ..
if [ -z "$GOLD" ]; then
  echo "ADC PASO4 MMIO: FALLO EN CORRIDA DORADA"
  exit 1
fi
N=$(echo "$GOLD" | sed 's/.*NCHK=\([0-9]*\).*/\1/')
TS=$(echo "$GOLD" | sed 's/.*@ \(.*\)$/\1/')
GOLDSIG="FIN SIMULACION MMIO: PASS NCHK=$N @ $TS"

DET=0
for m in 1 2 3 4 5; do
  rm -rf mmut$m && mkdir mmut$m && cp adc_regs.vhd adc_fifo.vhd mmut$m/
  case $m in
    1) sed -i 's|^  rdata <= rdata_mux;|  proc_mut : process (clk) begin if rising_edge(clk) then rdata <= rdata_mux; end if; end process;|' mmut$m/adc_regs.vhd ;;
    2) sed -i 's/irqst_r <= irqst_r and (not wdata(1 downto 0));/irqst_r <= irqst_r and wdata(1 downto 0);/' mmut$m/adc_regs.vhd ;;
    3) sed -i 's/(fifo_level >= thr_r)/(fifo_level > thr_r)/' mmut$m/adc_regs.vhd ;;
    4) sed -i 's/rv <= adv_r or (rv and (not adv_h));/rv <= adv_r;/' mmut$m/adc_fifo.vhd ;;
    5) sed -i "s/cnt_ram = to_unsigned(C_DEPTH, cnt_ram'length)/cnt_ram = to_unsigned(C_DEPTH - 1, cnt_ram'length)/" mmut$m/adc_fifo.vhd ;;
  esac
  if diff -q adc_regs.vhd mmut$m/adc_regs.vhd > /dev/null && diff -q adc_fifo.vhd mmut$m/adc_fifo.vhd > /dev/null; then
    echo "MMUT$m: sed no aplico la mutacion"
    exit 1
  fi
  ( cd mmut$m
    ghdl -a --std=08 --workdir=. adc_fifo.vhd adc_regs.vhd ../adc_mmio.vhd ../tb_mmio.vhd > /dev/null 2>&1
    ghdl -e --std=08 --workdir=. tb_mmio > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 --workdir=. tb_mmio 2>&1 | grep -m1 "FIN SIMULACION MMIO: PASS" || true)
    if echo "$OUT" | grep -q "$GOLDSIG"; then exit 1; else exit 0; fi )
  if [ $? -eq 0 ]; then
    DET=$((DET+1))
    echo "MMUT$m: detectada"
  else
    echo "MMUT$m: NO DETECTADA"
  fi
done

if [ "$DET" -ne 5 ]; then
  echo "ADC PASO4 MMIO: FALLO EN MUTACIONES ($DET/5)"
  exit 1
fi

echo "ADC PASO4 MMIO: PASS NCHK=$N MUT=$DET/5 @ $TS"
)
