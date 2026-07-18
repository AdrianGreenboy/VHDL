-- =============================================================
-- rv32_mem_adapter.vhd - HERCOSSNUX RV32IMA SoC v1 - Paso 4a
-- Adaptador de memoria unificado: envuelve al core (via sus
-- puertos imem/dmem combinacionales) y expone UN master
-- AXI-Lite hacia el NoC/DDR, mas un puerto MMIO al bloque
-- rapido (CLINT/UART). Genera core_clk_en para congelar el
-- core durante las esperas.
--
-- Decisiones de arquitectura (acordadas):
--  * Von Neumann + FSM multiciclo: el core nunca pide fetch y
--    dato en el mismo ciclo (estados distintos) -> arbitro
--    trivial, coherencia I/D gratis.
--  * MODO A puro: fetch single-beat. El fetch vive aislado en
--    un proceso propio (etiqueta FETCH_UNIT) con interfaz
--    limpia pedir->responder, de modo que MODO C (buffer de
--    linea) sustituya SOLO ese bloque sin tocar el resto.
--  * Opcion 1 (dato registrado): RDATA/instr se latchea en un
--    registro del adaptador; core_clk_en sube el ciclo
--    SIGUIENTE, con el dato ya estable en la entrada del core.
--    Elimina la carrera dato/enable en el flanco de avance.
--  * Traduccion: rango core DDR 0x80000000..0x83FFFFFF (64 MB)
--    -> DDR fisico 0x70000000 (resta 0x10000000). MMIO
--    0x10000000..0x11FFFFFF va al puerto rapido, NO al NoC.
--
-- Contrato del core (visto desde aqui, del RTL real):
--  * imem: presenta imem_addr_o=PC continuamente; espera
--    imem_data_i valido en el flanco en que avanza desde
--    S_FETCH. dmem: en load presenta dmem_addr_o y dmem_re_o=1
--    un ciclo (S_EXEC->S_MEM), captura dmem_rdata_i en el
--    flanco de avance desde S_MEM. En store presenta
--    dmem_we_o=1 un ciclo en S_EXEC.
--  * El adaptador detecta el primer flanco de cada acceso por
--    el cambio de estado observable: re/we pulsos, o cambio de
--    PC. Aqui se usa un modelo de "solicitud pendiente":
--    mientras el core este congelado, sus salidas no cambian,
--    asi que el acceso en curso es estable.
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32_mem_adapter is
  generic (
    DDR_BASE_CORE : std_logic_vector(31 downto 0) := x"80000000";
    DDR_BASE_PHYS : std_logic_vector(31 downto 0) := x"70000000";
    DDR_SIZE_LOG2 : natural := 26  -- 64 MB
  );
  port (
    clk        : in  std_logic;
    rstn       : in  std_logic;
    -- lado core (se conecta a rv32im_core_ce)
    core_clk_en: out std_logic;
    imem_addr  : in  std_logic_vector(31 downto 0);
    imem_data  : out std_logic_vector(31 downto 0);
    dmem_addr  : in  std_logic_vector(31 downto 0);
    dmem_wdata : in  std_logic_vector(31 downto 0);
    dmem_we    : in  std_logic;
    dmem_re    : in  std_logic;
    dmem_be    : in  std_logic_vector(3 downto 0);
    dmem_rdata : out std_logic_vector(31 downto 0);
    core_halt  : in  std_logic;
    core_st_fetch : in std_logic;  -- '1' cuando el core esta en S_FETCH
    core_st_mem   : in std_logic;  -- '1' cuando el core esta en S_MEM
    core_st_store : in std_logic;  -- '1' cuando el core esta en S_STORE
    -- master AXI-Lite hacia NoC/DDR
    m_arvalid  : out std_logic;
    m_arready  : in  std_logic;
    m_araddr   : out std_logic_vector(31 downto 0);
    m_rvalid   : in  std_logic;
    m_rready   : out std_logic;
    m_rdata    : in  std_logic_vector(31 downto 0);
    m_awvalid  : out std_logic;
    m_awready  : in  std_logic;
    m_awaddr   : out std_logic_vector(31 downto 0);
    m_wvalid   : out std_logic;
    m_wready   : in  std_logic;
    m_wdata    : out std_logic_vector(31 downto 0);
    m_wstrb    : out std_logic_vector(3 downto 0);
    m_bvalid   : in  std_logic;
    m_bready   : out std_logic;
    -- puerto MMIO rapido (CLINT/UART), single-beat, ready siempre '1'
    mmio_req   : out std_logic;
    mmio_we    : out std_logic;
    mmio_addr  : out std_logic_vector(31 downto 0);
    mmio_wdata : out std_logic_vector(31 downto 0);
    mmio_rdata : in  std_logic_vector(31 downto 0);
    mmio_ready : in  std_logic;
    -- pulso de 1 ciclo: el acceso a DATO se completo y dmem_rdata es valido.
    -- Lo usa el modulo AMO del core IMA como m_ready (handshake real).
    data_done  : out std_logic
  );
end entity;

architecture rtl of rv32_mem_adapter is

  -- clasificacion de destino de una direccion
  function is_ddr(a : std_logic_vector(31 downto 0)) return boolean is
  begin
    return a(31 downto DDR_SIZE_LOG2) = DDR_BASE_CORE(31 downto DDR_SIZE_LOG2);
  end function;

  function xlate(a : std_logic_vector(31 downto 0)) return std_logic_vector is
  begin
    -- resta (DDR_BASE_CORE - DDR_BASE_PHYS) = 0x10000000
    return std_logic_vector(unsigned(a) -
             (unsigned(DDR_BASE_CORE) - unsigned(DDR_BASE_PHYS))); -- MUT1
  end function;

  -- =========================================================
  -- FETCH_UNIT (aislado; MODO A single-beat). Interfaz interna:
  --   f_start : pulso, pide fetch en f_addr
  --   f_done  : '1' un ciclo cuando f_data valido
  -- En MODO C se reemplaza este bloque por uno con buffer de
  -- linea sin tocar nada mas.
  -- =========================================================
  type t_fst is (FS_IDLE, FS_AR, FS_R, FS_DONE);
  signal fst      : t_fst;
  signal f_start  : std_logic;
  signal f_addr   : std_logic_vector(31 downto 0);
  signal f_done   : std_logic;
  signal f_data_r : std_logic_vector(31 downto 0);
  signal f_arvalid, f_rready : std_logic;
  signal f_araddr : std_logic_vector(31 downto 0);

  -- =========================================================
  -- DATA_UNIT (load/store por AXI o MMIO)
  -- =========================================================
  type t_dst is (DS_IDLE, DS_AR, DS_R, DS_AW, DS_W, DS_B, DS_MMIO, DS_DONE);
  signal dst      : t_dst;
  signal d_start_ld, d_start_st : std_logic;
  signal d_addr   : std_logic_vector(31 downto 0);
  signal d_wdata  : std_logic_vector(31 downto 0);
  signal d_be     : std_logic_vector(3 downto 0);
  signal d_done   : std_logic;
  signal d_data_r : std_logic_vector(31 downto 0);
  signal d_is_mmio: std_logic;
  signal d_arvalid, d_rready, d_awvalid, d_wvalid, d_bready : std_logic;

  -- =========================================================
  -- Secuenciador de arbitraje core<->memoria
  -- =========================================================
  type t_seq is (SEQ_EVAL, SEQ_WAIT_FETCH, SEQ_WAIT_DATA, SEQ_WAIT_STORE, SEQ_STEP);
  signal seq      : t_seq;
  signal en_r     : std_logic;
  signal served   : std_logic;

  signal mmio_req_r, mmio_we_r : std_logic;
  signal mmio_addr_r, mmio_wdata_r : std_logic_vector(31 downto 0);

begin

  core_clk_en <= en_r;
  data_done   <= d_done;
  imem_data   <= f_data_r;
  dmem_rdata  <= d_data_r;

  -- salidas AXI multiplexadas entre fetch y data (nunca simultaneos)
  m_arvalid <= f_arvalid or d_arvalid;
  -- d_addr esta en la vista del core; al NoC debe salir la fisica (el
  -- fetch ya sale traducido desde f_araddr). Sin este xlate los accesos
  -- a DATO iban al NoC con 0x8xxxxxxx en vez de 0x7xxxxxxx.
  m_araddr  <= f_araddr when f_arvalid = '1' else xlate(d_addr);
  m_rready  <= f_rready or d_rready;
  m_awvalid <= d_awvalid;
  m_awaddr  <= xlate(d_addr);
  m_wvalid  <= d_wvalid;
  m_wdata   <= d_wdata;
  m_wstrb   <= d_be; -- MUT4
  m_bready  <= d_bready;

  mmio_req   <= mmio_req_r;
  mmio_we    <= mmio_we_r;
  mmio_addr  <= mmio_addr_r;
  mmio_wdata <= mmio_wdata_r;

  -- =========================================================
  -- Proceso FETCH_UNIT
  -- =========================================================
  FETCH_UNIT : process(clk, rstn)
  begin
    if rstn = '0' then
      fst      <= FS_IDLE;
      f_done   <= '0';
      f_data_r <= (others => '0');
      f_arvalid<= '0';
      f_rready <= '0';
      f_araddr <= (others => '0');
    elsif rising_edge(clk) then
      f_done <= '0';
      case fst is
        when FS_IDLE =>
          if f_start = '1' then
            f_araddr  <= xlate(f_addr);  -- fetch siempre a DDR
            f_arvalid <= '1';
            fst <= FS_AR;
          end if;
        when FS_AR =>
          if m_arready = '1' then
            f_arvalid <= '0';
            f_rready  <= '1';
            fst <= FS_R;
          end if;
        when FS_R =>
          if m_rvalid = '1' then
            f_data_r <= m_rdata;   -- MUT2
            f_rready <= '0';
            fst <= FS_DONE;
          end if;
        when FS_DONE =>
          f_done <= '1';
          fst <= FS_IDLE;
      end case;
    end if;
  end process;

  -- =========================================================
  -- Proceso DATA_UNIT
  -- =========================================================
  DATA_UNIT : process(clk, rstn)
  begin
    if rstn = '0' then
      dst      <= DS_IDLE;
      d_done   <= '0';
      d_data_r <= (others => '0');
      d_is_mmio<= '0';
      d_arvalid<= '0'; d_rready <= '0';
      d_awvalid<= '0'; d_wvalid <= '0'; d_bready <= '0';
      mmio_req_r<= '0'; mmio_we_r<= '0';
      mmio_addr_r<= (others=>'0'); mmio_wdata_r<= (others=>'0');
    elsif rising_edge(clk) then
      d_done   <= '0';
      mmio_req_r <= '0';
      mmio_we_r  <= '0';
      case dst is
        when DS_IDLE =>
          if d_start_ld = '1' or d_start_st = '1' then
            if is_ddr(d_addr) then
              d_is_mmio <= '0';
              if d_start_ld = '1' then
                d_arvalid <= '1';
                dst <= DS_AR;
              else
                d_awvalid <= '1';
                d_wvalid  <= '1';
                dst <= DS_AW;
              end if;
            else
              -- MMIO: un ciclo, ready siempre 1
              d_is_mmio  <= '1';
              mmio_req_r <= '1';
              mmio_we_r  <= d_start_st;
              mmio_addr_r<= d_addr;
              mmio_wdata_r<= d_wdata;
              dst <= DS_MMIO;
            end if;
          end if;

        when DS_AR =>
          if m_arready = '1' then
            d_arvalid <= '0';
            d_rready  <= '1';
            dst <= DS_R;
          end if;
        when DS_R =>
          if m_rvalid = '1' then
            d_data_r <= m_rdata;   -- MUT3
            d_rready <= '0';
            dst <= DS_DONE;
          end if;

        when DS_AW =>
          -- espera aceptacion de AW y W (pueden llegar en cualquier orden)
          if m_awready = '1' then d_awvalid <= '0'; end if;
          if m_wready  = '1' then d_wvalid  <= '0'; end if;
          if (m_awready = '1' or d_awvalid = '0') and
             (m_wready  = '1' or d_wvalid  = '0') then
            d_bready <= '1';
            dst <= DS_B;
          end if;
        when DS_W =>
          null; -- (fusionado en DS_AW)
        when DS_B =>
          if m_bvalid = '1' then
            d_bready <= '0';
            dst <= DS_DONE;
          end if;

        when DS_MMIO =>
          if mmio_ready = '1' then
            d_data_r <= mmio_rdata; -- Opcion 1: registra la lectura MMIO
            dst <= DS_DONE;
          end if;

        when DS_DONE =>
          d_done <= '1';
          dst <= DS_IDLE;
      end case;
    end if;
  end process;

  -- =========================================================
  -- SECUENCIADOR estricto: avanza el core UN estado a la vez y
  -- re-observa. Nunca sostiene en_r mas de un ciclo sin mirar
  -- el nuevo estado del core.
  --
  -- SEQ_EVAL: observa el estado del core (combinacional) y
  --   decide. Si el estado necesita memoria (fetch/load/store)
  --   y no esta servida, lanza la transaccion (en_r=0). Si el
  --   estado no necesita memoria, o ya esta servida, pulsa
  --   en_r=1 un ciclo (SEQ_STEP) y regresa a EVAL.
  -- =========================================================
  SEQP : process(clk, rstn)
  begin
    if rstn = '0' then
      seq        <= SEQ_EVAL;
      en_r       <= '0';
      f_start    <= '0';
      d_start_ld <= '0';
      d_start_st <= '0';
      served     <= '0';
    elsif rising_edge(clk) then
      f_start    <= '0';
      d_start_ld <= '0';
      d_start_st <= '0';

      case seq is
        when SEQ_EVAL =>
          en_r <= '0';
          if core_halt = '1' then
            en_r <= '0';  -- detenido
          elsif core_st_fetch = '1' and served = '0' then
            f_addr  <= imem_addr;
            f_start <= '1';
            seq <= SEQ_WAIT_FETCH;
          elsif core_st_mem = '1' and served = '0' then
            d_addr     <= dmem_addr;
            d_wdata    <= dmem_wdata;
            d_be       <= dmem_be;
            d_start_ld <= '1';
            seq <= SEQ_WAIT_DATA;
          elsif core_st_store = '1' and served = '0' then
            d_addr     <= dmem_addr;
            d_wdata    <= dmem_wdata;
            d_be       <= dmem_be;
            d_start_st <= '1';
            seq <= SEQ_WAIT_STORE;
          else
            -- estado sin memoria pendiente (S_EXEC/S_WB, o memoria
            -- ya servida): avanzar UN paso.
            en_r <= '1';
            seq <= SEQ_STEP;
          end if;

        when SEQ_WAIT_FETCH =>
          en_r <= '0';
          if f_done = '1' then
            served <= '1';   -- instr lista en imem_data
            en_r   <= '1';   -- avanzar: el core captura y sale de S_FETCH
            seq <= SEQ_STEP;
          end if;

        when SEQ_WAIT_DATA =>
          en_r <= '0';
          if d_done = '1' then
            served <= '1';
            en_r   <= '1';   -- avanzar: el core captura y sale de S_MEM
            seq <= SEQ_STEP;
          end if;

        when SEQ_WAIT_STORE =>
          en_r <= '0';
          if d_done = '1' then
            served <= '1';
            en_r   <= '1';   -- avanzar: el core sale de S_STORE
            seq <= SEQ_STEP;
          end if;

        when SEQ_STEP =>
          -- el core avanzo un estado en el flanco que entra aqui.
          -- bajar en_r y volver a evaluar el nuevo estado.
          en_r   <= '0';
          served <= '0';     -- MUT5
          seq <= SEQ_EVAL;
      end case;
    end if;
  end process;

end architecture;
