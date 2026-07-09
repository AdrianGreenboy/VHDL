-- ============================================================================
--  i2c_mmio.vhd — Periférico IIC memory-mapped para el RV32I SoC v3 (capa 2)
--
--  Regfile estilo dmem de 1 ciclo (contrato verificado en el USART:
--  dmem_req dura exactamente 1 ciclo -> los pops con efecto secundario en
--  lecturas son seguros). Instancia i2c_master + i2c_slave + 2x byte_fifo
--  (FWFT, compartidos desde ~/spi_ip/byte_fifo.vhd con fallback local).
--
--  MAPA DE REGISTROS (offsets sobre addr(7:0), palabra completa):
--   0x00 CTRL   [0] EN (maestro)  [1] SEN (esclavo)  [2] STRETCH_EN
--               [7] LOOP_INT (self-test: pads liberados, wired-AND interno)
--   0x04 STAT   vivos:   [0] MBUSY [1] BUS_BUSY [2] XACT_OPEN [3] ADDRESSED
--                        [4] RD_ACTIVE [5] SRX_EMPTY [6] SRX_FULL
--                        [7] STX_EMPTY [8] STX_FULL
--               stickies (CUALQUIER escritura a STAT los limpia; un evento
--               simultáneo a la limpieza GANA y no se pierde):
--                        [16] MDONE [17] ARB_LOST [18] NACK [19] SRX_OVF
--                        [20] STX_UR [21] START_DET [22] STOP_DET
--                        [23] CMD_DROP [24] STX_OVF
--   0x08 SCLDIV [15:0]  F_SCL = Fclk/(4*(div+1)); default 249 (100 kHz)
--   0x0C CMD    [7:0] dato [8] START [9] STOP [10] READ [11] ACKOUT
--               [12] NOBYTE — la ESCRITURA dispara; si EN=0 o el maestro
--               está ocupado se DESCARTA + sticky CMD_DROP
--   0x10 MRD    RO: [7:0] último byte leído  [8] ACK_IN vivo
--   0x14 SADDR  [6:0] dirección propia del esclavo
--   0x18 STX    escritura -> push al FIFO TX del esclavo
--               (lleno = drop-newest + sticky STX_OVF, nunca back-pressure)
--   0x1C SRX    lectura -> pop del FIFO RX del esclavo:
--               [7:0] dato  [8] VALID (pre-pop)
--   0x20 LVL    RO: [8:0] nivel SRX  [24:16] nivel STX
--   0x24 IRQ_EN [0] MDONE [1] ARB_LOST [2] NACK [3] SRX_OVF [4] STX_UR
--               [5] STOP_DET [6] SRX_WM [7] STX_WM
--   0x28 IRQ_STAT RO: espejo de causas (0-5 stickies, 6-7 por nivel);
--               irq = OR(IRQ_STAT and IRQ_EN), por NIVEL, sin acknowledge
--   0x2C WM     [8:0] SRX_WM (causa 6 activa si nivel>=WM y WM/=0)
--               [24:16] STX_WM (causa 7 activa si nivel<=WM)
--
--  NACK sticky: solo se arma en el done de comandos de ESCRITURA (en
--  lecturas ack_in no se toca -> sin falsos positivos).
--
--  LOOP_INT=1: los pads salen liberados ('1') y ambos motores ven el
--  wired-AND interno de sus propios drivers — self-test de ciclo completo
--  inmune al mundo exterior. LOOP_INT=0: ambos motores comparten los pads
--  (maestro y esclavo coexisten en el bus externo, como controller real).
--
--  Ganchos DMA con DEFAULTS (regresión futura sin tocar este TB):
--  dma_srx_* espeja el lado de lectura del FIFO RX, dma_stx_* el de
--  escritura del FIFO TX. No usar CPU y DMA sobre el mismo FIFO a la vez
--  (v1 sin árbitro; el CPU gana en colisión de push y el push DMA se
--  descarta con sticky STX_OVF).
--
--  Sin timeout de stretching en v1 (watchdog en software o mmio v1.1).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_mmio is
  generic (
    FIFO_LOG2 : natural := 8
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;                          -- síncrono, activo alto

    -- interfaz dmem (contrato: req dura exactamente 1 ciclo)
    sel   : in  std_logic;
    req   : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);
    wdata : in  std_logic_vector(31 downto 0);
    wstrb : in  std_logic_vector(3 downto 0);
    rdata : out std_logic_vector(31 downto 0);

    irq   : out std_logic;                          -- por NIVEL

    -- ganchos DMA (defaults: inertes)
    dma_srx_ren   : in  std_logic := '0';
    dma_srx_data  : out std_logic_vector(7 downto 0);
    dma_srx_empty : out std_logic;
    dma_stx_wen   : in  std_logic := '0';
    dma_stx_data  : in  std_logic_vector(7 downto 0) := (others => '0');
    dma_stx_full  : out std_logic;

    -- pads open-drain (IOBUF en el wrapper)
    scl_i : in  std_logic;
    scl_t : out std_logic;
    sda_i : in  std_logic;
    sda_t : out std_logic
  );
end entity i2c_mmio;

architecture rtl of i2c_mmio is

  -- ---------------- configuración ----------------
  signal ctrl_en, ctrl_sen, ctrl_stretch, ctrl_loop : std_logic := '0';
  signal scldiv : std_logic_vector(15 downto 0)
                := std_logic_vector(to_unsigned(249, 16));
  signal saddr  : std_logic_vector(6 downto 0) := (others => '0');
  signal irq_en : std_logic_vector(7 downto 0) := (others => '0');
  signal srx_wm : unsigned(8 downto 0) := to_unsigned(1, 9);
  signal stx_wm : unsigned(8 downto 0) := (others => '0');

  -- ---------------- stickies ----------------
  signal st_mdone, st_arb, st_nack, st_srxovf, st_stxur : std_logic := '0';
  signal st_start, st_stop, st_cmddrop, st_stxovf       : std_logic := '0';

  -- ---------------- comando al maestro ----------------
  signal c_valid, c_start, c_stop, c_read, c_ack, c_nob : std_logic := '0';
  signal c_data     : std_logic_vector(7 downto 0) := (others => '0');
  signal pend_read  : std_logic := '0';
  signal pend_nob   : std_logic := '0';
  signal issue_pend : std_logic := '0';

  -- ---------------- maestro ----------------
  signal m_busy, m_done, m_ackin, m_arb, m_busbusy, m_xopen : std_logic;
  signal m_rdata : std_logic_vector(7 downto 0);
  signal m_scl_t, m_sda_t : std_logic;

  -- ---------------- esclavo ----------------
  signal s_rx_data  : std_logic_vector(7 downto 0);
  signal s_rx_valid, s_rx_ovf : std_logic;
  signal s_tx_data  : std_logic_vector(7 downto 0);
  signal s_tx_valid, s_tx_ren, s_tx_ur : std_logic;
  signal s_addressed, s_rdact, s_startd, s_stopd : std_logic;
  signal s_scl_t, s_sda_t : std_logic;

  -- ---------------- FIFOs ----------------
  signal aresetn : std_logic;
  signal srx_full, srx_empty : std_logic;
  signal srx_rd_en : std_logic;
  signal srx_rdd   : std_logic_vector(7 downto 0);
  signal srx_lvl   : unsigned(FIFO_LOG2 downto 0);

  signal stx_full, stx_empty : std_logic;
  signal stx_wr_en : std_logic;
  signal stx_wrd   : std_logic_vector(7 downto 0);
  signal stx_lvl   : unsigned(FIFO_LOG2 downto 0);

  -- ---------------- bus interno / pads ----------------
  signal scl_and, sda_and       : std_logic;
  signal eng_scl_in, eng_sda_in : std_logic;

  -- ---------------- dmem ----------------
  signal irq_r : std_logic := '0';

  -- decode combinacional de accesos (el pop/push ocurre en el ciclo del req)
  signal acc_wr, acc_rd : std_logic;
  signal cpu_srx_pop, cpu_stx_push : std_logic;

  signal cause : std_logic_vector(7 downto 0);

begin

  aresetn <= not rst;

  acc_wr <= sel and req when wstrb /= "0000" else '0';
  acc_rd <= sel and req when wstrb  = "0000" else '0';

  cpu_srx_pop  <= '1' when acc_rd = '1' and addr(7 downto 2) = "000111" else '0';
  cpu_stx_push <= '1' when acc_wr = '1' and addr(7 downto 2) = "000110" else '0';

  -- pops/pushes de FIFO (CPU con prioridad sobre DMA en el push)
  srx_rd_en <= (cpu_srx_pop or dma_srx_ren) and (not srx_empty);
  stx_wr_en <= (cpu_stx_push or dma_stx_wen) and (not stx_full);
  stx_wrd   <= wdata(7 downto 0) when cpu_stx_push = '1' else dma_stx_data;

  -- espejo DMA
  dma_srx_data  <= srx_rdd;
  dma_srx_empty <= srx_empty;
  dma_stx_full  <= stx_full;

  -- ---------------- wired-AND interno y ruteo de pads ----------------
  scl_and <= m_scl_t and s_scl_t;
  sda_and <= m_sda_t and s_sda_t;

  scl_t <= '1' when ctrl_loop = '1' else scl_and;
  sda_t <= '1' when ctrl_loop = '1' else sda_and;

  eng_scl_in <= scl_and when ctrl_loop = '1' else scl_i;
  eng_sda_in <= sda_and when ctrl_loop = '1' else sda_i;

  -- ---------------- motores ----------------
  u_master : entity work.i2c_master
    port map (
      clk => clk, rst => rst, en => ctrl_en, scl_div => scldiv,
      cmd_valid => c_valid, cmd_start => c_start, cmd_stop => c_stop,
      cmd_read => c_read, cmd_ackout => c_ack,
      cmd_nobyte => c_nob, cmd_wdata => c_data,
      busy => m_busy, done => m_done, rdata => m_rdata, ack_in => m_ackin,
      arb_lost => m_arb, bus_busy => m_busbusy, xact_open => m_xopen,
      scl_i => eng_scl_in, scl_t => m_scl_t,
      sda_i => eng_sda_in, sda_t => m_sda_t
    );

  u_slave : entity work.i2c_slave
    port map (
      clk => clk, rst => rst, en => ctrl_sen,
      own_addr => saddr, stretch_en => ctrl_stretch,
      rx_data => s_rx_data, rx_valid => s_rx_valid,
      rx_full => srx_full, rx_ovf => s_rx_ovf,
      tx_data => s_tx_data, tx_valid => s_tx_valid,
      tx_ren => s_tx_ren, tx_ur => s_tx_ur,
      addressed => s_addressed, rd_active => s_rdact,
      start_det => s_startd, stop_det => s_stopd,
      scl_i => eng_scl_in, scl_t => s_scl_t,
      sda_i => eng_sda_in, sda_t => s_sda_t
    );

  -- ---------------- FIFOs del esclavo ----------------
  u_srx : entity work.byte_fifo
    generic map ( LOG2_DEPTH => FIFO_LOG2 )
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => s_rx_valid, wr_data => s_rx_data, full => srx_full,
      rd_en => srx_rd_en, rd_data => srx_rdd, empty => srx_empty,
      level => srx_lvl
    );

  u_stx : entity work.byte_fifo
    generic map ( LOG2_DEPTH => FIFO_LOG2 )
    port map (
      clk => clk, aresetn => aresetn,
      wr_en => stx_wr_en, wr_data => stx_wrd, full => stx_full,
      rd_en => s_tx_ren, rd_data => s_tx_data, empty => stx_empty,
      level => stx_lvl
    );

  s_tx_valid <= not stx_empty;

  -- ---------------- causas de IRQ (0-5 stickies, 6-7 por nivel) ----------
  cause(0) <= st_mdone;
  cause(1) <= st_arb;
  cause(2) <= st_nack;
  cause(3) <= st_srxovf;
  cause(4) <= st_stxur;
  cause(5) <= st_stop;
  cause(6) <= '1' when (srx_wm /= 0) and (resize(srx_lvl, 9) >= srx_wm) else '0';
  cause(7) <= '1' when resize(stx_lvl, 9) <= stx_wm else '0';

  -- ---------------- regfile ----------------
  main : process(clk)
  begin
    if rising_edge(clk) then
      c_valid <= '0';

      -- ============ escrituras (palabra completa) ============
      if acc_wr = '1' then
        case addr(7 downto 2) is

          when "000000" =>                          -- CTRL
            ctrl_en      <= wdata(0);
            ctrl_sen     <= wdata(1);
            ctrl_stretch <= wdata(2);
            ctrl_loop    <= wdata(7);

          when "000001" =>                          -- STAT: limpia stickies
            st_mdone   <= '0';
            st_arb     <= '0';
            st_nack    <= '0';
            st_srxovf  <= '0';
            st_stxur   <= '0';
            st_start   <= '0';
            st_stop    <= '0';
            st_cmddrop <= '0';
            st_stxovf  <= '0';

          when "000010" =>                          -- SCLDIV
            scldiv <= wdata(15 downto 0);

          when "000011" =>                          -- CMD: la escritura dispara
            if ctrl_en = '1' and m_busy = '0' and issue_pend = '0' then
              c_data     <= wdata(7 downto 0);
              c_start    <= wdata(8);
              c_stop     <= wdata(9);
              c_read     <= wdata(10);
              c_ack      <= wdata(11);
              c_nob      <= wdata(12);
              c_valid    <= '1';
              pend_read  <= wdata(10);
              pend_nob   <= wdata(12);
              issue_pend <= '1';
            else
              st_cmddrop <= '1';
            end if;

          when "000101" =>                          -- SADDR
            saddr <= wdata(6 downto 0);

          when "000110" =>                          -- STX (push arriba)
            if stx_full = '1' then
              st_stxovf <= '1';                     -- drop-newest + sticky
            end if;

          when "001001" =>                          -- IRQ_EN
            irq_en <= wdata(7 downto 0);

          when "001011" =>                          -- WM
            srx_wm <= unsigned(wdata(8 downto 0));
            stx_wm <= unsigned(wdata(24 downto 16));

          when others => null;                      -- STAT ya arriba; RO: nada
        end case;
      end if;

      -- push DMA descartado por lleno o por colisión con el CPU
      if dma_stx_wen = '1' and (stx_full = '1' or cpu_stx_push = '1') then
        st_stxovf <= '1';
      end if;

      -- ============ eventos: los sets GANAN a la limpieza simultánea ======
      if m_done = '1' then
        st_mdone <= '1';
        if pend_read = '0' and pend_nob = '0' and m_ackin = '1' then
          st_nack <= '1';                           -- NACK solo en escrituras
        end if;
      end if;
      if m_arb = '1' then
        st_arb <= '1';
      end if;
      if s_rx_ovf = '1' then
        st_srxovf <= '1';
      end if;
      if s_tx_ur = '1' then
        st_stxur <= '1';
      end if;
      if s_startd = '1' then
        st_start <= '1';
      end if;
      if s_stopd = '1' then
        st_stop <= '1';
      end if;

      -- ventana de emisión: cubre el hueco entre c_valid y busy del motor
      if m_busy = '1' or m_done = '1' or m_arb = '1' then
        issue_pend <= '0';
      end if;

      -- ============ IRQ por nivel ============
      if (cause and irq_en) /= x"00" then
        irq_r <= '1';
      else
        irq_r <= '0';
      end if;

      -- ============ reset síncrono ============
      if rst = '1' then
        ctrl_en      <= '0';
        ctrl_sen     <= '0';
        ctrl_stretch <= '0';
        ctrl_loop    <= '0';
        scldiv       <= std_logic_vector(to_unsigned(249, 16));
        saddr        <= (others => '0');
        irq_en       <= (others => '0');
        srx_wm       <= to_unsigned(1, 9);
        stx_wm       <= (others => '0');
        st_mdone     <= '0';
        st_arb       <= '0';
        st_nack      <= '0';
        st_srxovf    <= '0';
        st_stxur     <= '0';
        st_start     <= '0';
        st_stop      <= '0';
        st_cmddrop   <= '0';
        st_stxovf    <= '0';
        c_valid      <= '0';
        pend_read    <= '0';
        pend_nob     <= '0';
        issue_pend   <= '0';
        irq_r        <= '0';
      end if;
    end if;
  end process;

  -- lectura COMBINACIONAL (contrato dmem: el core captura en el flanco del
  -- req, como con dp_ram; el pop de SRX ocurre en ese flanco -> el core ve
  -- el dato PRE-pop, y la cabeza avanza después)
  rd_mux : process(all)
  begin
    rdata <= (others => '0');
    case addr(7 downto 2) is
      when "000000" =>                            -- CTRL
        rdata(0) <= ctrl_en;
        rdata(1) <= ctrl_sen;
        rdata(2) <= ctrl_stretch;
        rdata(7) <= ctrl_loop;
      when "000001" =>                            -- STAT
        rdata(0)  <= m_busy;
        rdata(1)  <= m_busbusy;
        rdata(2)  <= m_xopen;
        rdata(3)  <= s_addressed;
        rdata(4)  <= s_rdact;
        rdata(5)  <= srx_empty;
        rdata(6)  <= srx_full;
        rdata(7)  <= stx_empty;
        rdata(8)  <= stx_full;
        rdata(16) <= st_mdone;
        rdata(17) <= st_arb;
        rdata(18) <= st_nack;
        rdata(19) <= st_srxovf;
        rdata(20) <= st_stxur;
        rdata(21) <= st_start;
        rdata(22) <= st_stop;
        rdata(23) <= st_cmddrop;
        rdata(24) <= st_stxovf;
      when "000010" =>                            -- SCLDIV
        rdata(15 downto 0) <= scldiv;
      when "000100" =>                            -- MRD
        rdata(7 downto 0) <= m_rdata;
        rdata(8)          <= m_ackin;
      when "000101" =>                            -- SADDR
        rdata(6 downto 0) <= saddr;
      when "000111" =>                            -- SRX: cabeza FWFT pre-pop
        rdata(7 downto 0) <= srx_rdd;
        rdata(8)          <= not srx_empty;
      when "001000" =>                            -- LVL
        rdata(8 downto 0)   <= std_logic_vector(resize(srx_lvl, 9));
        rdata(24 downto 16) <= std_logic_vector(resize(stx_lvl, 9));
      when "001001" =>                            -- IRQ_EN
        rdata(7 downto 0) <= irq_en;
      when "001010" =>                            -- IRQ_STAT
        rdata(7 downto 0) <= cause;
      when "001011" =>                            -- WM
        rdata(8 downto 0)   <= std_logic_vector(srx_wm);
        rdata(24 downto 16) <= std_logic_vector(stx_wm);
      when others =>
        rdata <= (others => '0');
    end case;
  end process;

  irq <= irq_r;

end architecture rtl;
