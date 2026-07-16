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
