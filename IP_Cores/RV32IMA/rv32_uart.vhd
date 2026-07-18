-- =============================================================
-- rv32_uart.vhd - HERCOSSNUX RV32IMA SoC v1 - Paso 5
-- UART 8250/16550 minimo, con PARIDAD EXACTA al modelo de
-- mini-rv32ima (nuestro oraculo de lockstep):
--
--   Escritura 0x10000000 (THR): emite el byte (tx_valid + tx_data)
--   Lectura   0x10000005 (LSR): devuelve 0x60 | DR
--                               0x20 THRE (transmisor vacio)
--                               0x40 TEMT (transmision completa)
--                               0x01 DR   (dato de entrada listo)
--   Lectura   0x10000000 (RBR): byte de entrada si DR=1, si no 0
--   Cualquier otra direccion del rango: lectura devuelve 0
--
-- Deliberadamente NO implementa (fuera del freeze v1):
--   IER, IIR/FCR, LCR, MCR, MSR, SCR, divisor de baudios, FIFO,
--   interrupciones. El kernel nommu solo necesita salida por
--   consola durante el arranque, y el emulador tampoco los tiene.
--
-- El transmisor es "instantaneo": THRE siempre activo. La
-- serializacion real a un pin TX es responsabilidad de un
-- envoltorio posterior (bring-up de silicio), no de esta capa.
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32_uart is
  port (
    clk      : in  std_logic;
    rstn     : in  std_logic;
    -- bus single-beat (identico al puerto MMIO del adaptador)
    req      : in  std_logic;
    we       : in  std_logic;
    addr     : in  std_logic_vector(15 downto 0);  -- offset dentro del UART
    wdata    : in  std_logic_vector(31 downto 0);
    rdata    : out std_logic_vector(31 downto 0);
    ready    : out std_logic;
    -- salida de caracteres (consumida por el TB o por el serializador real)
    tx_valid : out std_logic;                      -- pulso de 1 ciclo
    tx_data  : out std_logic_vector(7 downto 0);
    -- entrada de caracteres (teclado). dr='1' indica byte disponible.
    rx_dr    : in  std_logic := '0';
    rx_data  : in  std_logic_vector(7 downto 0) := (others => '0');
    rx_take  : out std_logic                       -- pulso: byte consumido
  );
end entity;

architecture rtl of rv32_uart is
  constant OFF_THR_RBR : std_logic_vector(15 downto 0) := x"0000";
  constant OFF_LSR     : std_logic_vector(15 downto 0) := x"0005";

  signal tx_valid_r : std_logic := '0';
  signal tx_data_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_take_r  : std_logic := '0';
begin

  -- bus siempre listo: acceso de un ciclo, sin wait states
  ready <= '1';

  tx_valid <= tx_valid_r;
  tx_data  <= tx_data_r;
  rx_take  <= rx_take_r;

  -- lectura combinacional (contrato del bus MMIO: rdata valido en el ciclo
  -- del req, sin registrar; mismo criterio que el dmem del core)
  -- Los registros del 8250 son de BYTE. El LSR vive en el offset 0x5, es
  -- decir el lane 1 de la palabra 0x4. El bus entrega palabras y el core
  -- alinea segun addr[1:0], asi que el LSR debe presentarse desplazado a
  -- su lane para que un 'lbu 0x10000005' lea 0x60.
  --   LSR = 0x60 | DR -> b7=0, b6=TEMT=1, b5=THRE=1, b4..b1=0, b0=DR
  rdata <= x"0000" & ("0" & "1" & "1" & "0000" & rx_dr) & x"00"
             when addr(15 downto 2) = OFF_LSR(15 downto 2)
           else x"000000" & rx_data
             when (addr = OFF_THR_RBR and rx_dr = '1')
           else (others => '0');

  proc : process (clk, rstn)
  begin
    if rstn = '0' then
      tx_valid_r <= '0';
      tx_data_r  <= (others => '0');
      rx_take_r  <= '0';
    elsif rising_edge(clk) then
      tx_valid_r <= '0';
      rx_take_r  <= '0';
      if req = '1' then
        if we = '1' then
          if addr = OFF_THR_RBR then
            tx_valid_r <= '1';
            tx_data_r  <= wdata(7 downto 0);
          end if;
          -- escrituras a otros offsets: ignoradas (igual que el emulador)
        else
          if addr = OFF_THR_RBR and rx_dr = '1' then
            rx_take_r <= '1';   -- consumimos el byte de entrada
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;
