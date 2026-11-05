-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Banco de registros AXI4-Lite (Layer 1)
--
-- Semantica congelada segun doc/register_map.md y validada contra el oraculo
-- Python pcs_regbank_oracle.py (firma FNV32 0xD165A95F).
--
-- Reglas duras aplicadas:
--   * El enmascarado de bits reservados ocurre en la ESCRITURA. Los registros
--     almacenan el valor ya enmascarado; la lectura devuelve el campo crudo.
--   * La FSM AXI NUNCA se resetea por SOFT_RESET (solo por s_axi_aresetn).
--   * Snapshot atomico: la lectura de contadores devuelve el registro sombra,
--     nunca el contador en vuelo (dominio data plane).
--
-- En este Layer 1, el data plane esta abstraido: los contadores "live" y los
-- bits de STATUS/eventos se pilotan desde puertos dp_* que el testbench conduce
-- reproduciendo la traza del oraculo. La CDC real se anade en Layer 2.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_regbank is
  port (
    -- Reloj / reset AXI
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;

    -- AXI4-Lite (32b/32b, subset write+read)
    s_axi_awaddr  : in  std_logic_vector(7 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(7 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    -- Interrupcion
    irq_out       : out std_logic;

    -- Interfaz al data plane (abstracta en Layer 1, pilotada por testbench).
    -- Entradas de estado (dominio DP; en L1 se asumen ya sincronizadas).
    dp_block_lock : in  std_logic;
    dp_hi_ber     : in  std_logic;
    dp_scr_sync   : in  std_logic;
    dp_prbs_lock  : in  std_logic;
    dp_tx_active  : in  std_logic;
    dp_rx_active  : in  std_logic;
    dp_dma_busy   : in  std_logic;
    -- Contadores en vuelo (dominio DP)
    dp_cnt_tx_blk : in  std_logic_vector(31 downto 0);
    dp_cnt_rx_blk : in  std_logic_vector(31 downto 0);
    dp_cnt_rx_err : in  std_logic_vector(31 downto 0);
    dp_cnt_ber    : in  std_logic_vector(31 downto 0);
    dp_lock_time  : in  std_logic_vector(31 downto 0);
    -- Pulsos de evento sticky (1 ciclo, dominio AXI en L1)
    dp_ev_lock_gained : in std_logic;
    dp_ev_lock_lost   : in std_logic;
    dp_ev_hi_ber      : in std_logic;
    dp_ev_rx_err      : in std_logic;
    dp_ev_prbs_err    : in std_logic;
    dp_ev_dma_done    : in std_logic;

    -- Salidas de control hacia el data plane
    ctrl_reg      : out std_logic_vector(6 downto 0);
    prbs_ctrl_reg : out std_logic_vector(2 downto 0);
    cmd_soft_reset: out std_logic;  -- pulso 1 ciclo
    cmd_resync    : out std_logic;
    cmd_cnt_clear : out std_logic;
    cmd_prbs_reset: out std_logic;
    prbs_inj      : out std_logic;  -- pulso 1 ciclo
    stats_snap    : out std_logic;  -- pulso 1 ciclo
    -- Re-latch externo de las sombras (para integracion con CDC de dos etapas:
    -- el top lo conecta a axi_snap_done para capturar el shadow FRESCO del CDC
    -- cuando el cruce completa). Default '0': en Layer 1 el comportamiento es
    -- identico al verificado (latch solo en el write de STATS_SNAP).
    snap_latch_ext : in std_logic := '0';
    dma_addr_reg  : out std_logic_vector(31 downto 0);
    dma_doorbell_reg : out std_logic_vector(31 downto 0)
  );
end entity pcs_regbank;

architecture rtl of pcs_regbank is

  -- Offsets (byte address, 6 LSB significativos dentro de 256B)
  constant OFF_ID          : std_logic_vector(7 downto 0) := x"00";
  constant OFF_SCRATCH     : std_logic_vector(7 downto 0) := x"04";
  constant OFF_CTRL        : std_logic_vector(7 downto 0) := x"08";
  constant OFF_CMD         : std_logic_vector(7 downto 0) := x"0C";
  constant OFF_STATUS      : std_logic_vector(7 downto 0) := x"10";
  constant OFF_IRQ_STATUS  : std_logic_vector(7 downto 0) := x"14";
  constant OFF_IRQ_ENABLE  : std_logic_vector(7 downto 0) := x"18";
  constant OFF_PRBS_CTRL   : std_logic_vector(7 downto 0) := x"1C";
  constant OFF_STATS_SNAP  : std_logic_vector(7 downto 0) := x"20";
  constant OFF_CNT_TX_BLK  : std_logic_vector(7 downto 0) := x"24";
  constant OFF_CNT_RX_BLK  : std_logic_vector(7 downto 0) := x"28";
  constant OFF_CNT_RX_ERR  : std_logic_vector(7 downto 0) := x"2C";
  constant OFF_CNT_BER     : std_logic_vector(7 downto 0) := x"30";
  constant OFF_LOCK_TIME   : std_logic_vector(7 downto 0) := x"34";
  constant OFF_DMA_ADDR    : std_logic_vector(7 downto 0) := x"38";
  constant OFF_DMA_DOORBELL: std_logic_vector(7 downto 0) := x"3C";

  constant ID_MAGIC : std_logic_vector(31 downto 0) := x"50435319";

  constant CTRL_MASK : std_logic_vector(31 downto 0) := x"0000007F";
  constant CMD_MASK  : std_logic_vector(31 downto 0) := x"0000000F";
  constant IRQ_MASK  : std_logic_vector(31 downto 0) := x"0000003F";
  constant PRBS_MASK : std_logic_vector(31 downto 0) := x"00000007";

  -- Registros almacenados (ya enmascarados al escribir)
  signal reg_scratch      : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_ctrl         : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_irq_status   : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_irq_enable   : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_prbs_ctrl    : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_dma_addr     : std_logic_vector(31 downto 0) := x"70000000";
  signal reg_dma_doorbell : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_ctrl_ack     : std_logic := '0';

  -- Registros sombra de contadores (congelados por snapshot)
  signal sh_tx_blk  : std_logic_vector(31 downto 0) := (others => '0');
  signal sh_rx_blk  : std_logic_vector(31 downto 0) := (others => '0');
  signal sh_rx_err  : std_logic_vector(31 downto 0) := (others => '0');
  signal sh_ber     : std_logic_vector(31 downto 0) := (others => '0');
  signal sh_lock_t  : std_logic_vector(31 downto 0) := (others => '0');

  -- Pulsos de comando
  signal p_soft_reset : std_logic := '0';
  signal p_resync     : std_logic := '0';
  signal p_cnt_clear  : std_logic := '0';
  signal p_prbs_reset : std_logic := '0';
  signal p_prbs_inj   : std_logic := '0';
  signal p_stats_snap : std_logic := '0';

  -- clear RW1C hacia el proceso unico de stickies (evita doble driver)
  signal irq_clear_pulse : std_logic_vector(31 downto 0) := (others => '0');
  signal irq_clear_stb   : std_logic := '0';

  -- FSM AXI: handshakes simples desacoplados write/read
  signal awready_i : std_logic;
  signal wready_i  : std_logic;
  signal bvalid_i  : std_logic := '0';
  signal arready_i : std_logic;
  signal rvalid_i  : std_logic := '0';
  signal rdata_i   : std_logic_vector(31 downto 0) := (others => '0');

  signal aw_addr_lat : std_logic_vector(7 downto 0) := (others => '0');
  signal aw_seen     : std_logic := '0';   -- AW holding register full
  signal w_seen      : std_logic := '0';   -- W holding register full
  signal w_data_lat  : std_logic_vector(31 downto 0) := (others => '0');
  signal w_strb_lat  : std_logic_vector(3 downto 0) := (others => '0');
  signal bresp_i     : std_logic_vector(1 downto 0) := "00";
  signal rresp_i     : std_logic_vector(1 downto 0) := "00";

  -- STATUS ensamblado combinacionalmente
  signal status_word : std_logic_vector(31 downto 0);

begin

  ------------------------------------------------------------------------------
  -- STATUS combinacional
  ------------------------------------------------------------------------------
  status_word <= (0 => dp_block_lock,
                  1 => dp_hi_ber,
                  2 => dp_scr_sync,
                  3 => dp_prbs_lock,
                  4 => reg_ctrl_ack,
                  5 => dp_tx_active,
                  6 => dp_rx_active,
                  7 => dp_dma_busy,
                  others => '0');

  ------------------------------------------------------------------------------
  -- AXI4-Lite write channel (audit 2026-11, fix A1).
  -- AW and W are accepted independently, each into its own holding register
  -- (address, and data + strobes). The write executes from the HELD values
  -- once both are held and the B channel is free; awready/wready stay low
  -- while the corresponding holding register is full. Before the fix the
  -- data was not latched: a W accepted while B was stalled executed later
  -- with whatever s_axi_wdata showed at that time.
  -- WSTRB is honoured per byte lane (fix M5); unmapped offsets answer
  -- SLVERR (fix B7). RO registers accept and ignore writes (OKAY).
  -- IMPORTANT: this FSM depends ONLY on s_axi_aresetn (never on SOFT_RESET).
  ------------------------------------------------------------------------------
  process(s_axi_aclk)
    variable waddr    : std_logic_vector(7 downto 0);
    variable wd       : std_logic_vector(31 downto 0);
    variable bm       : std_logic_vector(31 downto 0);   -- byte-lane mask
    variable cmd_m    : std_logic_vector(31 downto 0);
    variable prbs_m   : std_logic_vector(31 downto 0);
    variable mapped   : boolean;
  begin
    if rising_edge(s_axi_aclk) then
      -- default pulses (1 cycle)
      p_soft_reset <= '0';
      p_resync     <= '0';
      p_cnt_clear  <= '0';
      p_prbs_reset <= '0';
      p_prbs_inj   <= '0';
      p_stats_snap <= '0';
      irq_clear_stb <= '0';

      if s_axi_aresetn = '0' then
        bvalid_i <= '0'; bresp_i <= "00";
        aw_seen <= '0'; w_seen <= '0';
        reg_scratch      <= (others => '0');
        reg_ctrl         <= (others => '0');
        reg_irq_enable   <= (others => '0');
        reg_prbs_ctrl    <= (others => '0');
        reg_dma_addr     <= x"70000000";
        reg_dma_doorbell <= (others => '0');
        reg_ctrl_ack     <= '0';
      else
        -- AW handshake: awready = not aw_seen
        if s_axi_awvalid = '1' and aw_seen = '0' then
          aw_addr_lat <= s_axi_awaddr;
          aw_seen     <= '1';
        end if;
        -- W handshake: wready = not w_seen; data AND strobes are latched
        if s_axi_wvalid = '1' and w_seen = '0' then
          w_data_lat <= s_axi_wdata;
          w_strb_lat <= s_axi_wstrb;
          w_seen     <= '1';
        end if;

        -- execute from the held values once both are held and B is free
        if aw_seen = '1' and w_seen = '1' and bvalid_i = '0' then
          waddr := aw_addr_lat;
          wd    := w_data_lat;
          for b in 0 to 3 loop
            bm(8*b+7 downto 8*b) := (others => w_strb_lat(b));
          end loop;
          mapped := true;

          case waddr is
            when OFF_ID | OFF_STATUS | OFF_CNT_TX_BLK | OFF_CNT_RX_BLK |
                 OFF_CNT_RX_ERR | OFF_CNT_BER | OFF_LOCK_TIME =>
              null;                                            -- RO: ignored
            when OFF_SCRATCH =>
              reg_scratch <= (reg_scratch and not bm) or (wd and bm);
            when OFF_CTRL =>
              reg_ctrl     <= ((reg_ctrl and not bm) or (wd and bm)) and CTRL_MASK;
              reg_ctrl_ack <= '1';                             -- immediate ack (L1)
            when OFF_CMD =>
              -- WO/SC: not stored; generates pulses (byte lane 0 only)
              cmd_m := wd and CMD_MASK and bm;
              if cmd_m(0) = '1' then p_soft_reset <= '1'; end if;
              if cmd_m(1) = '1' then p_resync     <= '1'; end if;
              if cmd_m(2) = '1' then p_cnt_clear  <= '1'; end if;
              if cmd_m(3) = '1' then p_prbs_reset <= '1'; end if;
            when OFF_IRQ_STATUS =>
              -- RW1C: the clear is applied in the single sticky process
              irq_clear_pulse <= wd and IRQ_MASK and bm;
              irq_clear_stb   <= '1';
            when OFF_IRQ_ENABLE =>
              reg_irq_enable <= ((reg_irq_enable and not bm) or (wd and bm)) and IRQ_MASK;
            when OFF_PRBS_CTRL =>
              prbs_m := ((reg_prbs_ctrl and not bm) or (wd and bm)) and PRBS_MASK;
              reg_prbs_ctrl <= prbs_m;
              if prbs_m(2) = '1' then
                p_prbs_inj <= '1';                             -- INJ is a pulse
              end if;
              -- INJ does not persist in the stored register
              reg_prbs_ctrl(2) <= '0';
            when OFF_STATS_SNAP =>
              if wd(0) = '1' and w_strb_lat(0) = '1' then p_stats_snap <= '1'; end if;
            when OFF_DMA_ADDR =>
              reg_dma_addr <= (reg_dma_addr and not bm) or (wd and bm);
            when OFF_DMA_DOORBELL =>
              reg_dma_doorbell <= (reg_dma_doorbell and not bm) or (wd and bm);
            when others =>
              mapped := false;                                 -- unmapped
          end case;

          aw_seen  <= '0';
          w_seen   <= '0';
          bvalid_i <= '1';
          if mapped then bresp_i <= "00"; else bresp_i <= "10"; end if;  -- SLVERR
        end if;

        -- B channel
        if bvalid_i = '1' and s_axi_bready = '1' then
          bvalid_i <= '0';
        end if;
      end if;
    end if;
  end process;

  awready_i <= not aw_seen when s_axi_aresetn = '1' else '0';
  wready_i  <= not w_seen  when s_axi_aresetn = '1' else '0';

  ------------------------------------------------------------------------------
  -- Stickies de IRQ: UNICO driver de reg_irq_status.
  -- Aplica primero el clear RW1C, luego el set por eventos DP, de modo que un
  -- set simultaneo gana sobre el clear (documentado en el oraculo).
  ------------------------------------------------------------------------------
  process(s_axi_aclk)
    variable nxt : std_logic_vector(31 downto 0);
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        reg_irq_status <= (others => '0');
      else
        nxt := reg_irq_status;
        -- clear RW1C
        if irq_clear_stb = '1' then
          nxt := nxt and (not irq_clear_pulse);
        end if;
        -- set por eventos (gana sobre clear)
        if dp_ev_lock_gained = '1' then nxt(0) := '1'; end if;
        if dp_ev_lock_lost   = '1' then nxt(1) := '1'; end if;
        if dp_ev_hi_ber      = '1' then nxt(2) := '1'; end if;
        if dp_ev_rx_err      = '1' then nxt(3) := '1'; end if;
        if dp_ev_prbs_err    = '1' then nxt(4) := '1'; end if;
        if dp_ev_dma_done    = '1' then nxt(5) := '1'; end if;
        reg_irq_status <= nxt and IRQ_MASK;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Snapshot atomico: al pulso stats_snap, congela sombra desde live.
  -- cmd_cnt_clear pone a cero live en el data plane (Layer 2); aqui reflejamos
  -- que un snapshot posterior lea 0 -> el testbench conduce dp_cnt_* a 0.
  ------------------------------------------------------------------------------
  process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        sh_tx_blk <= (others=>'0'); sh_rx_blk <= (others=>'0');
        sh_rx_err <= (others=>'0'); sh_ber    <= (others=>'0');
        sh_lock_t <= (others=>'0');
      elsif p_stats_snap = '1' or snap_latch_ext = '1' then
        sh_tx_blk <= dp_cnt_tx_blk;
        sh_rx_blk <= dp_cnt_rx_blk;
        sh_rx_err <= dp_cnt_rx_err;
        sh_ber    <= dp_cnt_ber;
        sh_lock_t <= dp_lock_time;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- AXI4-Lite read channel. arready = not rvalid (one read in flight); the
  -- data is captured at the AR handshake and held until rready. Unmapped
  -- offsets read 0 with SLVERR (fix B7). read() returns the RAW stored field.
  ------------------------------------------------------------------------------
  arready_i <= not rvalid_i when s_axi_aresetn = '1' else '0';

  process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        rvalid_i <= '0'; rdata_i <= (others => '0'); rresp_i <= "00";
      else
        if s_axi_arvalid = '1' and rvalid_i = '0' then
          rresp_i <= "00";
          case s_axi_araddr is
            when OFF_ID          => rdata_i <= ID_MAGIC;
            when OFF_SCRATCH     => rdata_i <= reg_scratch;
            when OFF_CTRL        => rdata_i <= reg_ctrl;          -- raw
            when OFF_CMD         => rdata_i <= (others => '0');   -- WO reads 0
            when OFF_STATUS      => rdata_i <= status_word;
            when OFF_IRQ_STATUS  => rdata_i <= reg_irq_status;    -- raw
            when OFF_IRQ_ENABLE  => rdata_i <= reg_irq_enable;    -- raw
            when OFF_PRBS_CTRL   => rdata_i <= reg_prbs_ctrl;     -- raw
            when OFF_STATS_SNAP  => rdata_i <= (others => '0');   -- WO/SC reads 0
            when OFF_CNT_TX_BLK  => rdata_i <= sh_tx_blk;         -- shadow
            when OFF_CNT_RX_BLK  => rdata_i <= sh_rx_blk;
            when OFF_CNT_RX_ERR  => rdata_i <= sh_rx_err;
            when OFF_CNT_BER     => rdata_i <= sh_ber;
            when OFF_LOCK_TIME   => rdata_i <= sh_lock_t;
            when OFF_DMA_ADDR    => rdata_i <= reg_dma_addr;
            when OFF_DMA_DOORBELL=> rdata_i <= reg_dma_doorbell;
            when others          => rdata_i <= (others => '0');   -- unmapped
                                    rresp_i <= "10";              -- SLVERR
          end case;
          rvalid_i <= '1';
        elsif rvalid_i = '1' and s_axi_rready = '1' then
          rvalid_i <= '0';
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Salidas
  ------------------------------------------------------------------------------
  s_axi_awready <= awready_i;
  s_axi_wready  <= wready_i;
  s_axi_bvalid  <= bvalid_i;
  s_axi_bresp   <= bresp_i;
  s_axi_arready <= arready_i;
  s_axi_rvalid  <= rvalid_i;
  s_axi_rresp   <= rresp_i;
  s_axi_rdata   <= rdata_i;

  irq_out <= '1' when (reg_irq_status and reg_irq_enable and IRQ_MASK) /= x"00000000"
             else '0';

  ctrl_reg      <= reg_ctrl(6 downto 0);
  prbs_ctrl_reg <= reg_prbs_ctrl(2 downto 0);
  cmd_soft_reset<= p_soft_reset;
  cmd_resync    <= p_resync;
  cmd_cnt_clear <= p_cnt_clear;
  cmd_prbs_reset<= p_prbs_reset;
  prbs_inj      <= p_prbs_inj;
  stats_snap    <= p_stats_snap;
  dma_addr_reg  <= reg_dma_addr;
  dma_doorbell_reg <= reg_dma_doorbell;

end architecture rtl;
