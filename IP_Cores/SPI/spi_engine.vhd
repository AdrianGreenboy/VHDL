-- =============================================================================
--  spi_engine.vhd  -  Motor SPI maestro (nucleo del futuro spi_axi_top)
--  Licencia: MIT
--
--  Motor byte a byte con los 4 modos (CPOL/CPHA), MSB o LSB primero, divisor
--  programable y muestreo de MISO retardable 1 ciclo (compensa el round-trip
--  SCLK->esclavo->MISO cuando SCLK sube). CS automatico: baja al aceptar el
--  primer byte y se queda abajo mientras haya bytes back-to-back (tx_valid en
--  alto cuando termina el byte); sube tras medio periodo de hold cuando el
--  stream se corta. Entre bytes encadenados NO hay ciclos muertos: 8 bits cada
--  8 periodos de SCLK, throughput maximo.
--
--  SCLK = clk / (2 * clkdiv), con clkdiv >= 1:
--    clk = 100 MHz -> clkdiv=1 da SCLK = 50 MHz (maximo), clkdiv=2 da 25 MHz...
--
--  Handshake estilo stream (para colgarle FIFOs en el paso 2):
--    tx_valid/tx_ready : tx_ready es pulso de 1 ciclo al ACEPTAR el byte.
--    rx_valid          : pulso de 1 ciclo con rx_data valido.
--
--  Convencion de flancos (flanco 1..16 dentro de un byte):
--    impar = flanco lider (sale del nivel idle CPOL), par = flanco de cola.
--    CPHA=0: MOSI valido antes del flanco 1 (se precarga al bajar CS),
--            se muestrea MISO en flancos lideres, MOSI cambia en flancos de cola.
--    CPHA=1: MOSI se presenta en flancos lideres, MISO se muestrea en la cola.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_engine is
  generic (
    DIV_W : natural := 16
  );
  port (
    clk     : in std_logic;
    aresetn : in std_logic;

    -- configuracion (mantener estable mientras busy = '1')
    cpol        : in std_logic;
    cpha        : in std_logic;
    lsb_first   : in std_logic;
    clkdiv      : in unsigned(DIV_W-1 downto 0);  -- medio periodo en ciclos (>=1)
    sample_late : in std_logic;                   -- captura MISO 1 clk despues

    -- stream TX / RX (byte a byte)
    tx_data  : in  std_logic_vector(7 downto 0);
    tx_valid : in  std_logic;
    tx_ready : out std_logic;
    rx_data  : out std_logic_vector(7 downto 0);
    rx_valid : out std_logic;
    busy     : out std_logic;

    -- bus SPI
    sclk_o : out std_logic;
    mosi_o : out std_logic;
    miso_i : in  std_logic;
    cs_n_o : out std_logic
  );
end entity spi_engine;

architecture rtl of spi_engine is
  type state_t is (S_IDLE, S_SETUP, S_XFER, S_HOLD);
  signal state : state_t := S_IDLE;

  signal div_eff  : unsigned(DIV_W-1 downto 0);
  signal half_cnt : unsigned(DIV_W-1 downto 0) := (others => '0');
  signal tick     : std_logic;

  signal edge_cnt : unsigned(4 downto 0) := (others => '0');  -- 0..16
  signal sclk_r   : std_logic := '0';
  signal mosi_r   : std_logic := '0';
  signal cs_r     : std_logic := '1';

  signal sh_tx : std_logic_vector(7 downto 0) := (others => '0');
  signal sh_rx : std_logic_vector(7 downto 0) := (others => '0');

  signal smp_cnt   : unsigned(3 downto 0) := (others => '0');  -- muestras del byte
  signal late_pend : std_logic := '0';

  signal tx_ready_r, rx_valid_r : std_logic := '0';
  signal rx_data_r : std_logic_vector(7 downto 0) := (others => '0');
begin

  -- clkdiv=0 se trata como 1 para no colgar el motor
  div_eff <= clkdiv when clkdiv /= 0 else to_unsigned(1, DIV_W);
  tick    <= '1' when (state /= S_IDLE and half_cnt = div_eff - 1) else '0';

  sclk_o   <= sclk_r;
  mosi_o   <= mosi_r;
  cs_n_o   <= cs_r;
  tx_ready <= tx_ready_r;
  rx_valid <= rx_valid_r;
  rx_data  <= rx_data_r;
  busy     <= '0' when state = S_IDLE else '1';

  process(clk)
    variable v_edge   : unsigned(4 downto 0);
    variable v_lead   : boolean;
    variable v_sample : boolean;
    variable v_drive  : boolean;
    variable v_cap    : boolean;
    variable v_rx     : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        state      <= S_IDLE;
        cs_r       <= '1';
        sclk_r     <= '0';
        mosi_r     <= '0';
        edge_cnt   <= (others => '0');
        half_cnt   <= (others => '0');
        smp_cnt    <= (others => '0');
        late_pend  <= '0';
        tx_ready_r <= '0';
        rx_valid_r <= '0';
      else
        tx_ready_r <= '0';
        rx_valid_r <= '0';
        v_cap := false;

        -- captura retardada de MISO (pendiente del tick anterior)
        if late_pend = '1' then
          v_cap := true;
          late_pend <= '0';
        end if;

        -- contador del medio periodo de SCLK
        if state = S_IDLE or tick = '1' then
          half_cnt <= (others => '0');
        else
          half_cnt <= half_cnt + 1;
        end if;

        case state is
          when S_IDLE =>
            sclk_r   <= cpol;             -- nivel idle sigue a CPOL
            cs_r     <= '1';
            edge_cnt <= (others => '0');
            smp_cnt  <= (others => '0');
            if tx_valid = '1' then
              sh_tx      <= tx_data;
              tx_ready_r <= '1';
              cs_r       <= '0';
              if cpha = '0' then          -- primer bit valido antes del flanco 1
                if lsb_first = '1' then mosi_r <= tx_data(0);
                else                    mosi_r <= tx_data(7);
                end if;
              end if;
              state <= S_SETUP;
            end if;

          when S_SETUP =>                 -- medio periodo de setup CS -> SCLK
            if tick = '1' then
              edge_cnt <= (others => '0');
              state    <= S_XFER;
            end if;

          when S_XFER =>
            if tick = '1' then
              v_edge := edge_cnt + 1;                 -- flanco 1..16
              v_lead := (v_edge(0) = '1');            -- impar = flanco lider
              sclk_r <= not sclk_r;

              v_sample := (cpha = '0' and v_lead) or (cpha = '1' and not v_lead);
              v_drive  := (cpha = '1' and v_lead) or (cpha = '0' and not v_lead);

              if v_sample then
                if sample_late = '1' then late_pend <= '1';
                else                      v_cap := true;
                end if;
              end if;

              if v_drive then
                if cpha = '1' and v_edge = 1 then
                  -- presenta el primer bit (sin desplazar)
                  if lsb_first = '1' then mosi_r <= sh_tx(0);
                  else                    mosi_r <= sh_tx(7);
                  end if;
                elsif v_edge /= 16 then
                  -- desplaza y presenta el siguiente bit
                  if lsb_first = '1' then
                    mosi_r <= sh_tx(1);
                    sh_tx  <= '0' & sh_tx(7 downto 1);
                  else
                    mosi_r <= sh_tx(6);
                    sh_tx  <= sh_tx(6 downto 0) & '0';
                  end if;
                end if;
              end if;

              if v_edge = 16 then
                edge_cnt <= (others => '0');
                if tx_valid = '1' then    -- encadena sin soltar CS
                  sh_tx      <= tx_data;
                  tx_ready_r <= '1';
                  if cpha = '0' then      -- precarga el bit 1 del nuevo byte
                    if lsb_first = '1' then mosi_r <= tx_data(0);
                    else                    mosi_r <= tx_data(7);
                    end if;
                  end if;
                else
                  state <= S_HOLD;
                end if;
              else
                edge_cnt <= v_edge;
              end if;
            end if;

          when S_HOLD =>                  -- medio periodo de hold y suelta CS
            if tick = '1' then
              cs_r  <= '1';
              state <= S_IDLE;
            end if;
        end case;

        -- ejecucion de la captura de MISO (inmediata o retardada 1 ciclo)
        if v_cap then
          if lsb_first = '1' then
            v_rx := miso_i & sh_rx(7 downto 1);
          else
            v_rx := sh_rx(6 downto 0) & miso_i;
          end if;
          sh_rx <= v_rx;
          if smp_cnt = 7 then             -- octava muestra: byte completo
            rx_data_r  <= v_rx;
            rx_valid_r <= '1';
            smp_cnt    <= (others => '0');
          else
            smp_cnt <= smp_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
