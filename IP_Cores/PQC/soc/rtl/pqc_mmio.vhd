-- ============================================================================
-- pqc_mmio.vhd -- Periferico PQC (ML-KEM-768 + ML-DSA-65) con banco MMIO
-- Licencia: MIT
-- ============================================================================
-- Region 0xD000_0000 (decode addr[31:28]="1101" en mem_subsys; aqui llegan
-- los bits bajos). Contrato del bus dmem del RV32: sel de 1 ciclo, rdata
-- COMBINACIONAL en el mismo ciclo.
--
-- Envuelve pqc_core (KEM+DSA fusionados bajo una esponja Keccak). El firmware
-- RV32 orquesta el self-test: selecciona algoritmo, carga los buffers de bytes
-- del core por la ventana ADDR/DATA (auto-incremento), dispara la operacion,
-- espera done por STATUS, y lee los bytes de salida. La firma FNV la calcula
-- el firmware (no hay FSM de hardware).
--
-- Los puertos de byte del core (kem_haddr/hdin/hwe/hsel/hdout y los dsa_*)
-- son sincronos: una escritura toma 1 ciclo; una lectura presenta hdout el
-- ciclo siguiente al de hsel. Por eso la ventana DATA registra la direccion y
-- expone el dato leido con un ciclo de latencia gestionado por el firmware
-- (lee DATA dos veces, o hace una lectura dummy tras fijar ADDR). Para que el
-- contrato dmem (rdata combinacional) se cumpla, DATA de lectura devuelve el
-- ultimo hdout registrado; el firmware fija ADDR, hace una lectura de descarte
-- y luego lee el valor bueno. Esto se documenta en el firmware.
--
-- Mapa (offsets de palabra, addr(7:2)):
--   0x00 CTRL   RW  b0 alg (0=KEM,1=DSA)
--   0x04 CMD    W1P b1:0 op, b2 start  (pulsa start del core seleccionado)
--   0x08 STATUS R   b0 busy, b1 done, b2 kem_rej, b3 dsa_result,
--                   b6:4 dsa_reason, b7 done_sticky
--   0x0C ADDR   RW  b13:0 direccion de byte en el core (auto-inc en acceso DATA)
--   0x10 DATA   RW  b7:0 dato; escribe/lee el byte en ADDR; ADDR++ tras acceso
--   0x14 SIGLEN RW  b15:0 dsa_siglen
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pqc_mmio is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;                          -- sincrono, activo alto
    -- bus dmem
    sel   : in  std_logic;
    we    : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);
    wdata : in  std_logic_vector(31 downto 0);
    rdata : out std_logic_vector(31 downto 0);      -- COMBINACIONAL
    irq   : out std_logic
  );
end entity pqc_mmio;

architecture rtl of pqc_mmio is

  signal rst_n : std_logic;

  -- registros MMIO
  signal alg_r     : std_logic := '0';
  signal cur_addr  : unsigned(13 downto 0) := (others => '0');
  signal siglen_r  : std_logic_vector(15 downto 0) := (others => '0');
  signal done_stky : std_logic := '0';

  -- decode de offset (addr(7:2))
  signal sel_ctrl, sel_cmd, sel_stat, sel_addr, sel_data, sel_siglen : std_logic;

  -- senales del core
  signal alg        : std_logic;
  signal kem_op     : std_logic_vector(1 downto 0)  := (others => '0');
  signal kem_start  : std_logic := '0';
  signal kem_done   : std_logic;
  signal kem_busy   : std_logic;
  signal kem_rej    : std_logic;
  signal kem_haddr  : std_logic_vector(12 downto 0);
  signal kem_hdin   : std_logic_vector(7 downto 0);
  signal kem_hwe    : std_logic := '0';
  signal kem_hsel   : std_logic := '0';
  signal kem_hdout  : std_logic_vector(7 downto 0);

  signal dsa_op     : std_logic_vector(1 downto 0)  := (others => '0');
  signal dsa_start  : std_logic := '0';
  signal dsa_done   : std_logic;
  signal dsa_busy   : std_logic;
  signal dsa_result : std_logic;
  signal dsa_reason : std_logic_vector(2 downto 0);
  signal dsa_haddr  : std_logic_vector(13 downto 0);
  signal dsa_hdin   : std_logic_vector(7 downto 0);
  signal dsa_hwe    : std_logic := '0';
  signal dsa_hsel   : std_logic := '0';
  signal dsa_hdout  : std_logic_vector(7 downto 0);

  -- dato leido registrado (latencia de 1 ciclo del puerto de byte del core)
  signal rd_byte    : std_logic_vector(7 downto 0) := (others => '0');

  -- direccion/dato de byte capturados en el ciclo del acceso, presentados al
  -- core el ciclo siguiente junto con el pulso hwe/hsel
  signal hbyte_addr : unsigned(13 downto 0) := (others => '0');
  signal hbyte_din  : std_logic_vector(7 downto 0) := (others => '0');

  signal busy_i, done_i : std_logic;
  signal rd_data_byte : std_logic_vector(7 downto 0);

  -- arranque diferido: replica la secuencia krun del TB validado del core
  -- (fijar op estable, esperar unos ciclos, luego pulsar start 1 ciclo)
  signal kick_cnt : unsigned(2 downto 0) := (others => '0');
  signal kick_alg : std_logic := '0';

  -- '1' durante un acceso de byte (host toma el byte_mem ese ciclo)
  signal hsel_q : std_logic := '0';

  -- host_mode='1': el firmware esta accediendo al byte_mem (carga o lectura),
  -- hsel se sostiene sobre cur_addr. Se activa al fijar ADDR o escribir DATA,
  -- se DESACTIVA al disparar una operacion (CMD start), para que el core tenga
  -- el byte_mem libre mientras computa.
  signal host_mode : std_logic := '0';

  -- tras fijar ADDR, la primera lectura DATA NO incrementa (deja que hdout se
  -- estabilice sobre esa direccion); las siguientes si. Asi lectura k -> byte k.
  signal rd_primed : std_logic := '0';

begin

  rst_n <= not rst;

  -- ---- decode combinacional ----
  sel_ctrl   <= '1' when addr(7 downto 2) = "000000" else '0';  -- 0x00
  sel_cmd    <= '1' when addr(7 downto 2) = "000001" else '0';  -- 0x04
  sel_stat   <= '1' when addr(7 downto 2) = "000010" else '0';  -- 0x08
  sel_addr   <= '1' when addr(7 downto 2) = "000011" else '0';  -- 0x0C
  sel_data   <= '1' when addr(7 downto 2) = "000100" else '0';  -- 0x10
  sel_siglen <= '1' when addr(7 downto 2) = "000101" else '0';  -- 0x14

  alg <= alg_r;

  busy_i <= kem_busy when alg_r = '0' else dsa_busy;
  done_i <= kem_done when alg_r = '0' else dsa_done;

  -- ---- puertos de byte del core ----
  -- host_mode='1': hsel sostenido y haddr=cur_addr (estable entre accesos del
  -- firmware, dando los >=2 ciclos que el core necesita para presentar el byte).
  -- En escritura, hbyte_addr/din llevan el dato y hwe se pulsa. host_mode='0'
  -- mientras el core computa, para no robarle el byte_mem.
  kem_haddr <= std_logic_vector(hbyte_addr(12 downto 0)) when kem_hwe = '1'
               else std_logic_vector(cur_addr(12 downto 0));
  dsa_haddr <= std_logic_vector(hbyte_addr) when dsa_hwe = '1'
               else std_logic_vector(cur_addr);
  kem_hdin  <= hbyte_din;
  dsa_hdin  <= hbyte_din;
  kem_hsel  <= (host_mode or kem_hwe) when alg_r = '0' else '0';
  dsa_hsel  <= (host_mode or dsa_hwe) when alg_r = '1' else '0';

  -- ---- proceso principal ----
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        alg_r    <= '0';
        cur_addr <= (others => '0');
        siglen_r <= (others => '0');
        done_stky<= '0';
        kem_start<= '0'; dsa_start <= '0';
        kem_op   <= (others => '0'); dsa_op <= (others => '0');
        kem_hwe  <= '0';
        dsa_hwe  <= '0';
        rd_byte  <= (others => '0');
        kick_cnt <= (others => '0');
        kick_alg <= '0';
        hbyte_addr <= (others => '0');
        hbyte_din  <= (others => '0');
        hsel_q <= '0';
        host_mode <= '0';
        rd_primed <= '0';
      else
        -- pulsos de 1 ciclo por defecto (hsel_q se maneja por acceso)
        kem_start <= '0'; dsa_start <= '0';
        kem_hwe   <= '0';
        dsa_hwe   <= '0';
        hsel_q    <= '0';

        -- captura del byte leido: hdout es valido el ciclo siguiente a hsel_q.
        -- Guardamos en rd_byte cuando hubo un acceso host el ciclo anterior.
        if hsel_q = '1' then
          if alg_r = '0' then
            rd_byte <= kem_hdout;
          else
            rd_byte <= dsa_hdout;
          end if;
        end if;

        -- sticky de done: se pone cuando el core termina, se limpia al leer STATUS
        if done_i = '1' then
          done_stky <= '1';
        end if;

        -- arranque diferido: cuenta hasta 1 y pulsa el start del core elegido
        if kick_cnt /= 0 then
          kick_cnt <= kick_cnt - 1;
          if kick_cnt = 1 then
            if kick_alg = '0' then
              kem_start <= '1';
            else
              dsa_start <= '1';
            end if;
          end if;
        end if;

        if sel = '1' then
          if we = '1' then
            -- ---- escrituras ----
            if sel_ctrl = '1' then
              alg_r <= wdata(0);
            elsif sel_cmd = '1' then
              -- fija op inmediatamente; arma el arranque diferido si start=b2.
              -- El start real se pulsa unos ciclos despues (kick_cnt) para que
              -- op/alg esten estables, igual que krun() en el TB validado.
              if alg_r = '0' then
                kem_op <= wdata(1 downto 0);
              else
                dsa_op <= wdata(1 downto 0);
              end if;
              if wdata(2) = '1' then
                kick_cnt <= to_unsigned(4, 3);  -- 4 ciclos de estabilizacion
                kick_alg <= alg_r;
                done_stky <= '0';
                host_mode <= '0';
        rd_primed <= '0';   -- libera el byte_mem para que el core compute
              end if;
            elsif sel_addr = '1' then
              cur_addr  <= unsigned(wdata(13 downto 0));
              host_mode <= '1';   -- entra en modo host: hsel sostenido sobre cur_addr
              rd_primed <= '0';   -- la proxima lectura es la de cebado (no ++)
            elsif sel_data = '1' then
              -- ESCRITURA de byte: host toma el byte_mem, presenta addr+dato,
              -- pulsa hwe. Mantiene host_mode.
              hbyte_addr <= cur_addr;
              hbyte_din  <= wdata(7 downto 0);
              host_mode  <= '1';
              if alg_r = '0' then
                kem_hwe <= '1';
              else
                dsa_hwe <= '1';
              end if;
              cur_addr <= cur_addr + 1;
            elsif sel_siglen = '1' then
              siglen_r <= wdata(15 downto 0);
            end if;
          else
            -- ---- lecturas con efecto lateral ----
            -- NOTA: leer STATUS NO limpia done_stky (el polling del firmware lo
            -- veria borrado). El sticky se limpia al disparar una operacion.
            if sel_data = '1' then
              -- LECTURA de byte: hsel/haddr sostenidos por host_mode sobre
              -- cur_addr; hdout = mem[cur_addr]. La PRIMERA lectura tras fijar
              -- ADDR solo ceba (no incrementa) para que hdout se asiente; las
              -- siguientes incrementan. Asi la lectura k devuelve el byte k.
              if rd_primed = '0' then
                rd_primed <= '1';
              else
                cur_addr <= cur_addr + 1;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ---- rdata combinacional (contrato dmem) ----
  -- DATA devuelve hdout del core: con host_mode, hsel/haddr estan sostenidos
  -- sobre cur_addr, asi que hdout = mem[cur_addr] (estable, el core tuvo >=2
  -- ciclos entre accesos del firmware). El firmware hace una lectura dummy tras
  -- fijar ADDR para absorber la latencia inicial del cambio de direccion.
  rd_data_byte <= kem_hdout when alg_r = '0' else dsa_hdout;

  rdata <=
    (0 => alg_r, others => '0')                         when sel_ctrl = '1' else
    (0 => busy_i, 1 => done_i, 2 => kem_rej,
     3 => dsa_result,
     4 => dsa_reason(0), 5 => dsa_reason(1), 6 => dsa_reason(2),
     7 => done_stky, others => '0')                     when sel_stat = '1' else
    std_logic_vector(resize(cur_addr, 32))              when sel_addr = '1' else
    (x"000000" & rd_data_byte)                          when sel_data = '1' else
    (x"0000" & siglen_r)                                when sel_siglen = '1' else
    (others => '0');

  -- IRQ por nivel: activa cuando el core termina (done sticky)
  irq <= done_stky;

  -- ---- instancia del core PQC fusionado ----
  u_core : entity work.pqc_core
    port map (
      clk => clk, rst_n => rst_n,
      alg => alg,
      kem_op => kem_op, kem_start => kem_start,
      kem_done => kem_done, kem_busy => kem_busy, kem_rej => kem_rej,
      kem_haddr => kem_haddr, kem_hdin => kem_hdin, kem_hwe => kem_hwe,
      kem_hsel => kem_hsel, kem_hdout => kem_hdout,
      dsa_op => dsa_op, dsa_start => dsa_start, dsa_siglen => siglen_r,
      dsa_done => dsa_done, dsa_busy => dsa_busy, dsa_result => dsa_result,
      dsa_reason => dsa_reason,
      dsa_haddr => dsa_haddr, dsa_hdin => dsa_hdin, dsa_hwe => dsa_hwe,
      dsa_hsel => dsa_hsel, dsa_hdout => dsa_hdout
    );

end architecture rtl;
