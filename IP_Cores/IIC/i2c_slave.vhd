-- ============================================================================
--  i2c_slave.vhd — Motor esclavo I2C a nivel de byte (open-drain)
--  Familia de periféricos del RV32I SoC v3 — capa 1b (aislamiento)
--
--  * Dirección propia programable de 7 bits (own_addr) + habilitación (en).
--    en solo gatea NUEVOS matches de dirección: una transacción en curso se
--    termina limpia aunque en caiga a medio byte.
--
--  * Interfaz de datos estilo FWFT, pensada para colgar DIRECTO de dos
--    byte_fifo en la capa 2 (mmio):
--      RX (escrituras del maestro):  rx_data/rx_valid -> wr_data/wr_en
--                                    rx_full <- full
--      TX (lecturas del maestro):    tx_data/tx_valid <- rd_data/not empty
--                                    tx_ren -> rd_en (FWFT: dato ya presente)
--
--  * Política de RX lleno: NACK al byte + pulso rx_ovf (drop-newest +
--    sticky en el mmio — misma filosofía de overflow que el USART). No se
--    estira SCL por RX lleno en v1 (documentado).
--
--  * Clock stretching (stretch_en='1'): si el maestro pide leer y no hay
--    dato TX (tx_valid='0'), el esclavo RETIENE SCL abajo tras el ACK hasta
--    que llegue el dato. Con stretch_en='0' y sin dato, envía 0xFF y pulsa
--    tx_ur (underrun).
--
--  * START repetido y STOP se detectan en cualquier estado y resincronizan
--    la FSM (el maestro manda). start_det/stop_det salen como pulsos para
--    los stickies del mmio.
--
--  * 10-bit addressing: por software desde el lado maestro; este esclavo es
--    7 bits en v1 (documentado).
--
--  * Open-drain: *_t='1' libera, '0' jala. NUNCA se empuja un '1'. El IOBUF
--    va en el wrapper (patrón USART). En loop_int este módulo se conecta al
--    maestro por wired-AND interno: es el self-test de silicio del IP.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_slave is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                     -- síncrono, activo alto
    en         : in  std_logic;
    own_addr   : in  std_logic_vector(6 downto 0);
    stretch_en : in  std_logic;

    -- RX: escrituras del maestro hacia nosotros
    rx_data    : out std_logic_vector(7 downto 0);
    rx_valid   : out std_logic;                     -- pulso: byte ACKeado
    rx_full    : in  std_logic;
    rx_ovf     : out std_logic;                     -- pulso: byte NACKeado

    -- TX: lecturas del maestro desde nosotros (FWFT)
    tx_data    : in  std_logic_vector(7 downto 0);
    tx_valid   : in  std_logic;
    tx_ren     : out std_logic;                     -- pulso: byte consumido
    tx_ur      : out std_logic;                     -- pulso: underrun (0xFF)

    -- estado
    addressed  : out std_logic;                     -- nivel: nos hablan a nosotros
    rd_active  : out std_logic;                     -- nivel: fase de lectura
    start_det  : out std_logic;                     -- pulso
    stop_det   : out std_logic;                     -- pulso

    scl_i      : in  std_logic;
    scl_t      : out std_logic;                     -- '1' libera, '0' jala
    sda_i      : in  std_logic;
    sda_t      : out std_logic
  );
end entity i2c_slave;

architecture rtl of i2c_slave is

  -- sincronización 2FF + filtro de mayoría de 3 muestras (idéntico al maestro)
  signal scl_s, sda_s : std_logic_vector(1 downto 0) := (others => '1');
  signal scl_h, sda_h : std_logic_vector(2 downto 0) := (others => '1');
  signal scl_f, sda_f   : std_logic := '1';
  signal scl_fd, sda_fd : std_logic := '1';

  type st_t is (S_IDLE, S_ADDR, S_AACK, S_RX, S_RXACK,
                S_TXLOAD, S_TX, S_TXACK, S_WAITEND);
  signal st : st_t := S_IDLE;

  signal cnt    : integer range 0 to 8 := 0;        -- bits en el byte actual
  signal shreg  : std_logic_vector(7 downto 0) := (others => '0');
  signal txsh   : std_logic_vector(7 downto 0) := (others => '1');
  signal is_rd  : std_logic := '0';
  signal nacked : std_logic := '0';
  signal mack   : std_logic := '1';                 -- ACK del maestro muestreado

  signal sda_t_r  : std_logic := '1';
  signal scl_hold : std_logic := '0';               -- '1' = estirando SCL
  signal addr_r   : std_logic := '0';

  signal rx_data_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_valid_r, rx_ovf_r   : std_logic := '0';
  signal tx_ren_r,   tx_ur_r    : std_logic := '0';
  signal start_r,    stop_r     : std_logic := '0';

begin

  main : process(clk)
    variable v_rise, v_fall, v_start, v_stop : boolean;
  begin
    if rising_edge(clk) then
      -- defaults de pulso
      rx_valid_r <= '0';
      rx_ovf_r   <= '0';
      tx_ren_r   <= '0';
      tx_ur_r    <= '0';
      start_r    <= '0';
      stop_r     <= '0';

      -- =================== filtros de entrada ===================
      scl_s <= scl_s(0) & scl_i;
      sda_s <= sda_s(0) & sda_i;
      scl_h <= scl_h(1 downto 0) & scl_s(1);
      sda_h <= sda_h(1 downto 0) & sda_s(1);
      scl_f <= (scl_h(2) and scl_h(1)) or (scl_h(2) and scl_h(0))
               or (scl_h(1) and scl_h(0));
      sda_f <= (sda_h(2) and sda_h(1)) or (sda_h(2) and sda_h(0))
               or (sda_h(1) and sda_h(0));
      scl_fd <= scl_f;
      sda_fd <= sda_f;

      -- eventos de línea (con un ciclo de retardo de filtro, consistente)
      v_rise  := (scl_f = '1') and (scl_fd = '0');
      v_fall  := (scl_f = '0') and (scl_fd = '1');
      v_start := (sda_fd = '1') and (sda_f = '0') and (scl_f = '1');
      v_stop  := (sda_fd = '0') and (sda_f = '1') and (scl_f = '1');

      -- ============ START/STOP mandan en cualquier estado ============
      if v_stop then
        st       <= S_IDLE;
        sda_t_r  <= '1';
        scl_hold <= '0';
        addr_r   <= '0';
        stop_r   <= '1';
      elsif v_start then                            -- START o START repetido
        st       <= S_ADDR;
        cnt      <= 0;
        sda_t_r  <= '1';
        scl_hold <= '0';
        addr_r   <= '0';
        start_r  <= '1';
      else
        case st is

          when S_IDLE =>
            sda_t_r  <= '1';
            scl_hold <= '0';

          when S_ADDR =>
            if v_rise and cnt < 8 then
              shreg <= shreg(6 downto 0) & sda_f;
              cnt   <= cnt + 1;
            elsif v_fall and cnt = 8 then           -- fin del 8º reloj
              if en = '1' and shreg(7 downto 1) = own_addr then
                addr_r  <= '1';
                is_rd   <= shreg(0);
                sda_t_r <= '0';                     -- ACK de dirección
                st      <= S_AACK;
              else
                sda_t_r <= '1';                     -- sin ACK: no soy yo
                st      <= S_WAITEND;
              end if;
            end if;

          when S_AACK =>
            if v_fall then                          -- fin del 9º reloj
              sda_t_r <= '1';
              if is_rd = '1' then
                -- punto de carga TX (primer byte de la lectura)
                if tx_valid = '1' then
                  txsh     <= tx_data;
                  sda_t_r  <= tx_data(7);
                  tx_ren_r <= '1';
                  cnt      <= 0;
                  st       <= S_TX;
                elsif stretch_en = '1' then
                  scl_hold <= '1';                  -- retener SCL: stretching
                  st       <= S_TXLOAD;
                else
                  txsh    <= x"FF";                 -- underrun: enviar 0xFF
                  tx_ur_r <= '1';
                  cnt     <= 0;
                  st      <= S_TX;
                end if;
              else
                cnt <= 0;
                st  <= S_RX;
              end if;
            end if;

          when S_TXLOAD =>                          -- SCL retenida: esperar dato
            if tx_valid = '1' then
              txsh     <= tx_data;
              sda_t_r  <= tx_data(7);
              tx_ren_r <= '1';
              scl_hold <= '0';                      -- soltar SCL: sigue el bus
              cnt      <= 0;
              st       <= S_TX;
            end if;

          when S_TX =>
            if v_rise then
              cnt <= cnt + 1;                       -- el maestro muestreó
            elsif v_fall then
              if cnt < 8 then
                sda_t_r <= txsh(6);                 -- siguiente bit
                txsh    <= txsh(6 downto 0) & '1';
              else
                sda_t_r <= '1';                     -- soltar: ACK del maestro
                st      <= S_TXACK;
              end if;
            end if;

          when S_TXACK =>
            if v_rise then
              mack <= sda_f;                        -- muestrear ACK/NACK
            elsif v_fall then                       -- fin del 9º reloj
              if mack = '0' then                    -- ACK: siguiente byte
                if tx_valid = '1' then
                  txsh     <= tx_data;
                  sda_t_r  <= tx_data(7);
                  tx_ren_r <= '1';
                  cnt      <= 0;
                  st       <= S_TX;
                elsif stretch_en = '1' then
                  scl_hold <= '1';
                  st       <= S_TXLOAD;
                else
                  txsh    <= x"FF";
                  sda_t_r <= '1';
                  tx_ur_r <= '1';
                  cnt     <= 0;
                  st      <= S_TX;
                end if;
              else                                  -- NACK: el maestro cierra
                sda_t_r <= '1';
                st      <= S_WAITEND;
              end if;
            end if;

          when S_RX =>
            if v_rise then
              shreg <= shreg(6 downto 0) & sda_f;
              cnt   <= cnt + 1;
            elsif v_fall and cnt = 8 then           -- fin del 8º reloj
              if rx_full = '1' then
                nacked   <= '1';
                rx_ovf_r <= '1';
                sda_t_r  <= '1';                    -- NACK: drop-newest
              else
                nacked     <= '0';
                rx_data_r  <= shreg;
                rx_valid_r <= '1';
                sda_t_r    <= '0';                  -- ACK
              end if;
              st <= S_RXACK;
            end if;

          when S_RXACK =>
            if v_fall then                          -- fin del 9º reloj
              sda_t_r <= '1';
              cnt     <= 0;
              if nacked = '1' then
                st <= S_WAITEND;
              else
                st <= S_RX;
              end if;
            end if;

          when S_WAITEND =>                         -- no soy yo / tras NACK
            sda_t_r  <= '1';
            scl_hold <= '0';

        end case;
      end if;

      -- =================== reset síncrono ===================
      if rst = '1' then
        st         <= S_IDLE;
        cnt        <= 0;
        sda_t_r    <= '1';
        scl_hold   <= '0';
        addr_r     <= '0';
        is_rd      <= '0';
        nacked     <= '0';
        mack       <= '1';
        rx_valid_r <= '0';
        rx_ovf_r   <= '0';
        tx_ren_r   <= '0';
        tx_ur_r    <= '0';
        start_r    <= '0';
        stop_r     <= '0';
      end if;
    end if;
  end process;

  rx_data   <= rx_data_r;
  rx_valid  <= rx_valid_r;
  rx_ovf    <= rx_ovf_r;
  tx_ren    <= tx_ren_r;
  tx_ur     <= tx_ur_r;
  addressed <= addr_r;
  rd_active <= addr_r and is_rd;
  start_det <= start_r;
  stop_det  <= stop_r;
  scl_t     <= '0' when scl_hold = '1' else '1';
  sda_t     <= sda_t_r;

end architecture rtl;
