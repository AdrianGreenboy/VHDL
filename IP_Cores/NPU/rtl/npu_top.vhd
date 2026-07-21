-- HERCOSSNUX NPU - top level de inferencia (cierra Layer 3).
--
-- Encadena los dos secuenciadores ya verificados por separado:
--   npu_seq_conv1 : imagen 16x16 -> pool1 (8 canales 8x8)
--   npu_seq_full  : pool1 -> conv2 -> pool2 -> FC -> argmax
--
-- El puente entre etapas copia los 512 bytes de pool1 a la entrada de la
-- segunda etapa. Ambas interfaces usan el mismo orden canal->fila->columna
-- y el mismo direccionamiento de 9 bits, por lo que la copia es directa.
--
-- Protocolo:
--   start='1' un ciclo -> ejecuta la inferencia completa
--   busy='1' mientras trabaja; done='1' un ciclo al terminar
--   clase queda estable tras done
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity npu_top is
  generic (
    G_MUT : natural := 0
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    -- imagen de entrada: 256 bytes
    img_we    : in  std_logic;
    img_addr  : in  unsigned(7 downto 0);
    img_data  : in  signed(C_DATA_W-1 downto 0);

    -- pesos conv1
    w1_we     : in  std_logic;
    w1_addr   : in  unsigned(6 downto 0);
    w1_data   : in  signed(C_DATA_W-1 downto 0);
    b1_we     : in  std_logic;
    b1_addr   : in  unsigned(2 downto 0);
    b1_data   : in  signed(C_ACC_W-1 downto 0);

    -- pesos conv2
    w2_we     : in  std_logic;
    w2_addr   : in  unsigned(10 downto 0);
    w2_data   : in  signed(C_DATA_W-1 downto 0);
    b2_we     : in  std_logic;
    b2_addr   : in  unsigned(3 downto 0);
    b2_data   : in  signed(C_ACC_W-1 downto 0);

    -- pesos FC
    w3_we     : in  std_logic;
    w3_addr   : in  unsigned(11 downto 0);
    w3_data   : in  signed(C_DATA_W-1 downto 0);
    b3_we     : in  std_logic;
    b3_addr   : in  unsigned(3 downto 0);
    b3_data   : in  signed(C_ACC_W-1 downto 0);

    mult1_in  : in  signed(C_MULT_W-1 downto 0);
    mult2_in  : in  signed(C_MULT_W-1 downto 0);
    mult3_in  : in  signed(C_MULT_W-1 downto 0);

    start     : in  std_logic;
    busy      : out std_logic;
    done      : out std_logic;

    -- resultados
    p1_addr   : in  unsigned(8 downto 0);
    p1_data   : out signed(C_DATA_W-1 downto 0);
    p2_addr   : in  unsigned(7 downto 0);
    p2_data   : out signed(C_DATA_W-1 downto 0);
    lg_addr   : in  unsigned(3 downto 0);
    lg_data   : out signed(C_DATA_W-1 downto 0);
    clase     : out unsigned(3 downto 0)
  );
end entity npu_top;

architecture rtl of npu_top is

  -- etapa 1
  signal s1_start   : std_logic := '0';
  signal s1_busy    : std_logic;
  signal s1_done    : std_logic;
  signal s1_oaddr   : unsigned(8 downto 0) := (others => '0');
  signal s1_odata   : signed(C_DATA_W-1 downto 0);

  -- etapa 2
  signal s2_start   : std_logic := '0';
  signal s2_busy    : std_logic;
  signal s2_done    : std_logic;
  signal s2_in_we   : std_logic := '0';
  signal s2_in_addr : unsigned(8 downto 0) := (others => '0');
  signal s2_in_data : signed(C_DATA_W-1 downto 0) := (others => '0');

  -- FSM del puente
  type t_state is (T_IDLE, T_C1, T_WAIT1, T_COPY, T_S2, T_WAIT2, T_DONE);
  signal state : t_state := T_IDLE;
  signal cp_i  : natural range 0 to 512 := 0;

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

begin

  busy    <= busy_r;
  done    <= done_r;
  p1_data <= s1_odata;

  u_s1 : entity work.npu_seq_conv1
    generic map (G_MUT => 0)
    port map (clk => clk, rst_n => rst_n,
              img_we => img_we, img_addr => img_addr, img_data => img_data,
              w_we => w1_we, w_addr => w1_addr, w_data => w1_data,
              b_we => b1_we, b_addr => b1_addr, b_data => b1_data,
              mult_in => mult1_in,
              start => s1_start, busy => s1_busy, done => s1_done,
              out_addr => s1_oaddr, out_data => s1_odata);

  u_s2 : entity work.npu_seq_full
    generic map (G_MUT => 0)
    port map (clk => clk, rst_n => rst_n,
              in_we => s2_in_we, in_addr => s2_in_addr, in_data => s2_in_data,
              w2_we => w2_we, w2_addr => w2_addr, w2_data => w2_data,
              b2_we => b2_we, b2_addr => b2_addr, b2_data => b2_data,
              w3_we => w3_we, w3_addr => w3_addr, w3_data => w3_data,
              b3_we => b3_we, b3_addr => b3_addr, b3_data => b3_data,
              mult2_in => mult2_in, mult3_in => mult3_in,
              start => s2_start, busy => s2_busy, done => s2_done,
              p2_addr => p2_addr, p2_data => p2_data,
              lg_addr => lg_addr, lg_data => lg_data, clase => clase);

  -- Lectura externa de pool1 cuando el top no esta copiando
  -- cp_i llega a 512, que no cabe en 9 bits: se satura para evitar el
  -- truncamiento de NUMERIC_STD (detectado en simulacion).
  s1_oaddr <= to_unsigned(cp_i, 9) when (state = T_COPY and cp_i < 512)
              else p1_addr;

  fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state <= T_IDLE; busy_r <= '0'; done_r <= '0';
        s1_start <= '0'; s2_start <= '0'; s2_in_we <= '0';
        cp_i <= 0;
      else
        done_r   <= '0';
        s1_start <= '0';
        s2_start <= '0';
        s2_in_we <= '0';

        case state is

          when T_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r   <= '1';
              s1_start <= '1';
              state    <= T_C1;
            end if;

          when T_C1 =>
            -- dar un ciclo para que la etapa 1 levante busy
            state <= T_WAIT1;

          when T_WAIT1 =>
            if s1_busy = '0' then
              cp_i  <= 0;
              state <= T_COPY;
            end if;

          when T_COPY =>
            -- Copia de los 512 bytes de pool1 a la entrada de la etapa 2.
            -- s1_oaddr ya apunta a cp_i (asignacion concurrente), por lo que
            -- s1_odata es valido en este ciclo.
            if cp_i < 512 then
              s2_in_we   <= '1';
              if G_MUT = 2 then
                -- MUT 2: la copia omite el ultimo canal de pool1
                if cp_i < 448 then
                  s2_in_addr <= to_unsigned(cp_i, 9);
                else
                  s2_in_addr <= to_unsigned(0, 9);
                end if;
              else
                s2_in_addr <= to_unsigned(cp_i, 9);
              end if;
              if G_MUT = 1 then
                -- MUT 1: la copia se desplaza un byte
                s2_in_data <= s1_odata + 1;
              else
                s2_in_data <= s1_odata;
              end if;
              cp_i <= cp_i + 1;
            else
              s2_start <= '1';
              state    <= T_S2;
            end if;

          when T_S2 =>
            state <= T_WAIT2;

          when T_WAIT2 =>
            if s2_busy = '0' then
              state <= T_DONE;
            end if;

          when T_DONE =>
            busy_r <= '0';
            done_r <= '1';
            state  <= T_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
