-- =============================================================
-- rv32ima_soc_top.vhd - Paso 7: top sintetizable del SoC HERCOSSNUX
--
-- Une el core RV32IMA validado contra el kernel real con el
-- adaptador de memoria (AXI-Lite maestro hacia DDR via NoC) y el
-- bus MMIO (CLINT + UART + syscon).
--
-- Dos interfaces AXI hacia el PS:
--   S_AXI  (AXI4-Lite esclavo, 0x80000000/64K en M_AXI_LPD):
--          banco de control/estado para arrancar el core, leer
--          su progreso y drenar la consola sin tocar la DDR.
--   M_AXI  (AXI4-Lite maestro hacia el NoC): accesos del core a
--          la RAM del kernel, mapeados de 0x80000000 (vista del
--          core) a DDR_BASE_PHYS (vista fisica del sistema).
--
-- Mapa del banco de control (offsets sobre 0x80000000):
--   0x00 CTRL   [0] core_en (1 = correr), [1] reset del core (auto-limpia)
--   0x04 STATUS [0] halted, [1] poweroff, [2] reboot, [3] rx_full
--   0x08 RETIRED_LO  retiros de instrucciones (32 bits bajos)
--   0x0C RETIRED_HI  retiros (32 bits altos)
--   0x10 UART_RX     [7:0] byte de consola, [8] valido; leer consume
--   0x14 UART_LEVEL  bytes pendientes en el FIFO de consola
--   0x18 UART_TX     escribir: byte hacia la consola del core (rx del core)
--   0x1C PC          PC actual del core (muestreado en S_FETCH)
--
-- La consola del core se bufferiza en un FIFO para que el PS la
-- drene a su ritmo sin frenar al core (a 100 MHz el core emite
-- mucho mas rapido de lo que el PS puede sondear).
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32ima_soc_top is
  generic (
    -- direccion fisica donde vive la imagen del kernel en DDR
    DDR_BASE_PHYS : std_logic_vector(31 downto 0) := x"70000000";
    -- PC de arranque: el stub que carga a0/a1 y salta al kernel
    RESET_PC      : std_logic_vector(31 downto 0) := x"83F00000";
    -- ciclos de clk por tick del CLINT (100 MHz / 100 = 1 MHz)
    TICK_DIV      : natural := 100;
    UART_FIFO_LOG2: natural := 12   -- 4096 bytes de consola
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    -- ---- AXI4-Lite esclavo: banco de control ----
    s_awaddr  : in  std_logic_vector(31 downto 0);
    s_awvalid : in  std_logic;
    s_awready : out std_logic;
    s_wdata   : in  std_logic_vector(31 downto 0);
    s_wstrb   : in  std_logic_vector(3 downto 0);
    s_wvalid  : in  std_logic;
    s_wready  : out std_logic;
    s_bresp   : out std_logic_vector(1 downto 0);
    s_bvalid  : out std_logic;
    s_bready  : in  std_logic;
    s_araddr  : in  std_logic_vector(31 downto 0);
    s_arvalid : in  std_logic;
    s_arready : out std_logic;
    s_rdata   : out std_logic_vector(31 downto 0);
    s_rresp   : out std_logic_vector(1 downto 0);
    s_rvalid  : out std_logic;
    s_rready  : in  std_logic;

    -- ---- AXI4-Lite maestro: hacia DDR por el NoC ----
    m_awaddr  : out std_logic_vector(31 downto 0);
    m_awvalid : out std_logic;
    m_awready : in  std_logic;
    m_wdata   : out std_logic_vector(31 downto 0);
    m_wstrb   : out std_logic_vector(3 downto 0);
    m_wvalid  : out std_logic;
    m_wready  : in  std_logic;
    m_bresp   : in  std_logic_vector(1 downto 0);
    m_bvalid  : in  std_logic;
    m_bready  : out std_logic;
    m_araddr  : out std_logic_vector(31 downto 0);
    m_arvalid : out std_logic;
    m_arready : in  std_logic;
    m_rdata   : in  std_logic_vector(31 downto 0);
    m_rresp   : in  std_logic_vector(1 downto 0);
    m_rvalid  : in  std_logic;
    m_rready  : out std_logic
  );
end entity;

architecture rtl of rv32ima_soc_top is
  -- control
  signal core_en_r   : std_logic := '0';
  signal run_r       : std_logic := '0';
  signal core_rstn_r : std_logic := '0';
  signal soft_rst_r  : std_logic := '0';

  -- core <-> adaptador
  signal core_clk_en : std_logic;
  signal iaddr, idata, daddr, dwdata, drdata : std_logic_vector(31 downto 0);
  signal dwe, dre : std_logic;
  signal dbe : std_logic_vector(3 downto 0);
  signal halt, stf, stm, sts : std_logic;
  signal dbg : std_logic_vector(1023 downto 0);
  signal data_done : std_logic;

  -- adaptador <-> MMIO
  signal mmio_req, mmio_we, mmio_ready : std_logic;
  signal mmio_addr, mmio_wdata, mmio_rdata : std_logic_vector(31 downto 0);

  -- MMIO
  signal tick_r    : std_logic := '0';
  signal tick_cnt  : unsigned(15 downto 0) := (others => '0');
  signal mtip, msip : std_logic;
  signal tx_valid  : std_logic;
  signal tx_data   : std_logic_vector(7 downto 0);
  signal poweroff, reboot : std_logic;
  signal rx_dr     : std_logic := '0';
  signal rx_data_r : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_take   : std_logic;

  -- FIFO de consola (core -> PS)
  constant FD : natural := 2**UART_FIFO_LOG2;
  type t_fifo is array (0 to FD-1) of std_logic_vector(7 downto 0);
  signal fifo_r  : t_fifo;
  signal wr_ptr  : unsigned(UART_FIFO_LOG2-1 downto 0) := (others => '0');
  signal rd_ptr  : unsigned(UART_FIFO_LOG2-1 downto 0) := (others => '0');
  signal fifo_lvl: unsigned(UART_FIFO_LOG2 downto 0) := (others => '0');
  signal fifo_out: std_logic_vector(7 downto 0) := (others => '0');

  -- telemetria
  signal retired_r : unsigned(63 downto 0) := (others => '0');
  signal prev_stf  : std_logic := '0';
  signal pc_r      : std_logic_vector(31 downto 0) := (others => '0');
  signal halted_r  : std_logic := '0';
  signal poweroff_r, reboot_r : std_logic := '0';

  -- AXI-Lite esclavo
  signal aw_hs, w_hs : std_logic := '0';
  signal awaddr_r : std_logic_vector(31 downto 0) := (others => '0');
  signal wdata_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal bvalid_r : std_logic := '0';
  signal arready_r: std_logic := '0';
  signal rvalid_r : std_logic := '0';
  signal rdata_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal rd_consume : std_logic := '0';
begin

  -- =========================================================
  -- reset del core: global AND control por software
  -- =========================================================
  core_rstn_r <= aresetn and (not soft_rst_r);

  -- =========================================================
  -- core RV32IMA (el mismo validado contra el kernel real)
  -- =========================================================
  u_core : entity work.rv32ima_core
    generic map (RESET_PC => RESET_PC)
    port map (
      clk_i => aclk, aresetn_i => core_rstn_r,
      -- core_clk_en del adaptador AND el permiso de marcha. run_r solo
      -- cae a '0' en un limite de instruccion (ver run_proc), nunca a
      -- mitad de un acceso AXI: congelar ahi dejaria la transaccion
      -- colgada y el core no volveria a avanzar jamas.
      core_clk_en_i => (core_clk_en and run_r),
      imem_addr_o => iaddr, imem_data_i => idata,
      dmem_addr_o => daddr, dmem_wdata_o => dwdata, dmem_we_o => dwe,
      dmem_re_o => dre, dmem_be_o => dbe, dmem_rdata_i => drdata,
      halt_o => halt, mtip_i => mtip, msip_i => msip,
      -- handshake real del acceso a dato: lo usa el modulo AMO como
      -- m_ready. Sin el, el AMO no espera la lectura previa y escribe
      -- el operando crudo en vez del resultado.
      mem_data_done_i => data_done,
      st_fetch_o => stf, st_mem_o => stm, st_store_o => sts,
      dbg_regs_o => dbg);

  -- =========================================================
  -- adaptador: core <-> AXI-Lite (DDR) + puerto MMIO
  -- =========================================================
  u_adp : entity work.rv32_mem_adapter
    generic map (DDR_BASE_CORE => x"80000000",
                 DDR_BASE_PHYS => DDR_BASE_PHYS,
                 DDR_SIZE_LOG2 => 26)
    port map (
      clk => aclk, rstn => core_rstn_r,
      core_clk_en => core_clk_en,
      imem_addr => iaddr, imem_data => idata,
      dmem_addr => daddr, dmem_wdata => dwdata, dmem_we => dwe,
      dmem_re => dre, dmem_be => dbe, dmem_rdata => drdata,
      core_halt => halt,
      core_st_fetch => stf, core_st_mem => stm, core_st_store => sts,
      m_arvalid => m_arvalid, m_arready => m_arready, m_araddr => m_araddr,
      m_rvalid => m_rvalid, m_rready => m_rready, m_rdata => m_rdata,
      m_awvalid => m_awvalid, m_awready => m_awready, m_awaddr => m_awaddr,
      m_wvalid => m_wvalid, m_wready => m_wready, m_wdata => m_wdata,
      m_wstrb => m_wstrb, m_bvalid => m_bvalid, m_bready => m_bready,
      mmio_req => mmio_req, mmio_we => mmio_we, mmio_addr => mmio_addr,
      mmio_wdata => mmio_wdata, mmio_rdata => mmio_rdata,
      mmio_ready => mmio_ready, data_done => data_done);

  -- =========================================================
  -- bus MMIO: CLINT + UART + syscon
  -- =========================================================
  u_mmio : entity work.rv32_mmio_bus
    port map (
      clk => aclk, rstn => core_rstn_r, tick => tick_r,
      req => mmio_req, we => mmio_we, addr => mmio_addr,
      wdata => mmio_wdata, rdata => mmio_rdata, ready => mmio_ready,
      tx_valid => tx_valid, tx_data => tx_data,
      rx_dr => rx_dr, rx_data => rx_data_r, rx_take => rx_take,
      poweroff_o => poweroff, reboot_o => reboot,
      mtip => mtip, msip => msip);

  -- permiso de marcha: sigue a core_en_r, pero solo se retira en un
  -- limite de instruccion (S_FETCH con core_clk_en activo = el core esta
  -- a punto de avanzar a la siguiente instruccion, sin acceso pendiente)
  run_proc : process(aclk)
  begin
    if rising_edge(aclk) then
      if core_rstn_r = '0' then
        run_r <= '0';
      elsif core_en_r = '1' then
        run_r <= '1';                     -- arrancar es siempre seguro
      elsif stf = '1' and core_clk_en = '1' then
        run_r <= '0';                     -- pausar solo en limite seguro
      end if;
    end if;
  end process;

  -- divisor de tick para el CLINT (1 MHz desde 100 MHz)
  tick_proc : process(aclk)
  begin
    if rising_edge(aclk) then
      if core_rstn_r = '0' then
        tick_cnt <= (others => '0');
        tick_r   <= '0';
      elsif run_r = '1' then
        if tick_cnt = to_unsigned(TICK_DIV-1, tick_cnt'length) then
          tick_cnt <= (others => '0');
          tick_r   <= '1';
        else
          tick_cnt <= tick_cnt + 1;
          tick_r   <= '0';
        end if;
      else
        tick_r <= '0';
      end if;
    end if;
  end process;

  -- =========================================================
  -- FIFO de consola: el core escribe, el PS drena
  -- =========================================================
  fifo_proc : process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        wr_ptr <= (others => '0');
        rd_ptr <= (others => '0');
        fifo_lvl <= (others => '0');
      else
        -- escritura del core (se descarta si el FIFO esta lleno: la
        -- consola es telemetria, nunca debe frenar el core)
        if tx_valid = '1' and fifo_lvl < FD then
          fifo_r(to_integer(wr_ptr)) <= tx_data;
          wr_ptr <= wr_ptr + 1;
          if rd_consume = '0' then
            fifo_lvl <= fifo_lvl + 1;
          end if;
        elsif rd_consume = '1' and fifo_lvl > 0 then
          fifo_lvl <= fifo_lvl - 1;
        end if;
        -- lectura del PS
        if rd_consume = '1' and fifo_lvl > 0 then
          rd_ptr <= rd_ptr + 1;
        end if;
      end if;
    end if;
  end process;
  fifo_out <= fifo_r(to_integer(rd_ptr));

  -- =========================================================
  -- telemetria: retiros, PC, eventos
  -- =========================================================
  tele_proc : process(aclk)
  begin
    if rising_edge(aclk) then
      if core_rstn_r = '0' then
        retired_r  <= (others => '0');
        prev_stf   <= '0';
        pc_r       <= (others => '0');
        halted_r   <= '0';
        poweroff_r <= '0';
        reboot_r   <= '0';
      else
        -- un retiro por cada salida de S_FETCH (mismo criterio que el
        -- arnes de simulacion, para poder comparar cifras)
        if run_r = '1' then
          if prev_stf = '1' and stf = '0' then
            retired_r <= retired_r + 1;
          end if;
          prev_stf <= stf;
          if stf = '1' then
            pc_r <= iaddr;
          end if;
        end if;
        if halt = '1'     then halted_r   <= '1'; end if;
        if poweroff = '1' then poweroff_r <= '1'; end if;
        if reboot = '1'   then reboot_r   <= '1'; end if;
      end if;
    end if;
  end process;

  -- =========================================================
  -- AXI4-Lite esclavo: banco de control
  -- =========================================================
  s_awready <= not bvalid_r;
  s_wready  <= not bvalid_r;
  s_bvalid  <= bvalid_r;
  s_bresp   <= "00";
  s_arready <= arready_r;
  s_rvalid  <= rvalid_r;
  s_rdata   <= rdata_r;
  s_rresp   <= "00";

  axi_slave : process(aclk)
    variable a : unsigned(7 downto 0);
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        core_en_r  <= '0';
        soft_rst_r <= '0';
        bvalid_r   <= '0';
        arready_r  <= '0';
        rvalid_r   <= '0';
        rd_consume <= '0';
        rx_dr      <= '0';
        aw_hs      <= '0';
        w_hs       <= '0';
      else
        rd_consume <= '0';
        soft_rst_r <= '0';   -- pulso de un ciclo

        -- consumo del byte de entrada por el core
        if rx_take = '1' then
          rx_dr <= '0';
        end if;

        -- ---- escritura ----
        if s_awvalid = '1' and bvalid_r = '0' and aw_hs = '0' then
          awaddr_r <= s_awaddr;
          aw_hs    <= '1';
        end if;
        if s_wvalid = '1' and bvalid_r = '0' and w_hs = '0' then
          wdata_r <= s_wdata;
          w_hs    <= '1';
        end if;
        if aw_hs = '1' and w_hs = '1' and bvalid_r = '0' then
          a := unsigned(awaddr_r(7 downto 0));
          case a is
            when x"00" =>
              core_en_r <= wdata_r(0);
              if wdata_r(1) = '1' then
                soft_rst_r <= '1';
              end if;
            when x"18" =>
              rx_data_r <= wdata_r(7 downto 0);
              rx_dr     <= '1';
            when others => null;
          end case;
          bvalid_r <= '1';
          aw_hs    <= '0';
          w_hs     <= '0';
        elsif bvalid_r = '1' and s_bready = '1' then
          bvalid_r <= '0';
        end if;

        -- ---- lectura ----
        if s_arvalid = '1' and arready_r = '0' and rvalid_r = '0' then
          arready_r <= '1';
          a := unsigned(s_araddr(7 downto 0));
          case a is
            when x"00" =>
              rdata_r <= (31 downto 1 => '0') & core_en_r;
            when x"04" =>
              rdata_r <= (31 downto 4 => '0') &
                         (fifo_lvl(UART_FIFO_LOG2) or
                          (fifo_lvl(UART_FIFO_LOG2-1) and
                           fifo_lvl(UART_FIFO_LOG2-2))) &
                         reboot_r & poweroff_r & halted_r;
            when x"08" =>
              rdata_r <= std_logic_vector(retired_r(31 downto 0));
            when x"0C" =>
              rdata_r <= std_logic_vector(retired_r(63 downto 32));
            when x"10" =>
              if fifo_lvl > 0 then
                rdata_r    <= x"0000_01" & fifo_out;
                rd_consume <= '1';
              else
                rdata_r <= (others => '0');
              end if;
            when x"14" =>
              rdata_r <= std_logic_vector(resize(fifo_lvl, 32));
            when x"1C" =>
              rdata_r <= pc_r;
            when others =>
              rdata_r <= (others => '0');
          end case;
        elsif arready_r = '1' then
          arready_r <= '0';
          rvalid_r  <= '1';
        elsif rvalid_r = '1' and s_rready = '1' then
          rvalid_r <= '0';
        end if;
      end if;
    end if;
  end process;

end architecture;
