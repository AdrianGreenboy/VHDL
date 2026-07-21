-- HERCOSSNUX NPU - secuenciador de conv1 + pool1 (Layer 3, entrega 1).
--
-- Ejecuta la primera capa de la red congelada:
--   conv1: 1 canal de entrada -> 8 canales de salida, 16x16, padding same
--   ReLU sobre el acumulador int32, requantize HXQ8, maxpool 2x2 -> 8x8
--
-- Estructura:
--   - buffer de entrada: 256 bytes (imagen 16x16 int8)
--   - buffer de salida:  8 canales x 8x8 = 512 bytes (pool1)
--   - un pase de array por pixel: 9 ciclos de kernel + reduccion
--   - el pooling se hace al vuelo, comparando 4 pixeles consecutivos
--
-- Protocolo:
--   start='1' un ciclo -> el secuenciador procesa la imagen del buffer
--   busy='1' mientras trabaja; done='1' un ciclo al terminar
--
-- Los pesos se cargan por el puerto de escritura antes de arrancar.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity npu_seq_conv1 is
  generic (
    G_MUT : natural := 0
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    -- carga de imagen (256 bytes)
    img_we    : in  std_logic;
    img_addr  : in  unsigned(7 downto 0);
    img_data  : in  signed(C_DATA_W-1 downto 0);

    -- carga de pesos: 8 canales x 9 posiciones = 72
    w_we      : in  std_logic;
    w_addr    : in  unsigned(6 downto 0);
    w_data    : in  signed(C_DATA_W-1 downto 0);

    -- carga de bias: 8 valores int32
    b_we      : in  std_logic;
    b_addr    : in  unsigned(2 downto 0);
    b_data    : in  signed(C_ACC_W-1 downto 0);

    -- multiplicador de requantize
    mult_in   : in  signed(C_MULT_W-1 downto 0);

    start     : in  std_logic;
    busy      : out std_logic;
    done      : out std_logic;

    -- lectura del resultado: 8 canales x 64 = 512 bytes
    out_addr  : in  unsigned(8 downto 0);
    out_data  : out signed(C_DATA_W-1 downto 0)
  );
end entity npu_seq_conv1;

architecture rtl of npu_seq_conv1 is

  -- ---------------- memorias ----------------
  type t_img_ram  is array (0 to 255) of integer range -128 to 127;
  type t_w_ram    is array (0 to 71)  of integer range -128 to 127;
  type t_b_ram    is array (0 to 7)   of integer;
  type t_out_ram  is array (0 to 511) of integer range -128 to 127;

  signal img_ram : t_img_ram := (others => 0);
  signal w_ram   : t_w_ram   := (others => 0);
  signal b_ram   : t_b_ram   := (others => 0);
  signal out_ram : t_out_ram := (others => 0);

  -- ---------------- FSM ----------------
  type t_state is (S_IDLE, S_PIX, S_WLOAD, S_MAC, S_WEND, S_RED, S_RQ, S_POOL, S_DONE);
  signal state : t_state := S_IDLE;

  signal px, py   : natural range 0 to 15 := 0;   -- pixel de salida de conv1
  signal kstep    : natural range 0 to 8  := 0;   -- paso del kernel
  signal red_cnt  : natural range 0 to 7  := 0;

  -- Interfaz con npu_array (Paso 3): el calculo de MAC ya NO vive en la FSM.
  signal arr_win_start : std_logic := '0';
  signal arr_en        : std_logic := '0';
  signal arr_win_end   : std_logic := '0';
  signal arr_a_col     : t_data_arr(0 to 7) := (others => (others => '0'));
  signal arr_w_mat     : t_data_arr(0 to 63) := (others => (others => '0'));
  signal arr_bias      : t_acc_arr(0 to 7) := (others => (others => '0'));
  signal arr_valid     : std_logic;
  signal arr_acc       : t_acc_arr(0 to 7);

  signal red_wait : natural range 0 to 7 := 0;

  -- Registro de los 8 pesos del kstep actual: evita 8 lecturas simultaneas
  -- de w_ram, que impedirian mapearla a BRAM.
  -- Los 72 pesos de conv1 (8 canales x 9) se precargan UNA vez por imagen:
  -- w_ram queda con una sola lectura por ciclo y el coste es 72 ciclos.
  signal wreg1 : t_data_arr(0 to 71) := (others => (others => '0'));
  signal wl1_i : natural range 0 to 72 := 0;

  -- resultado post-requantize de conv1 para el pixel actual
  signal conv_val : t_data_arr(0 to 7) := (others => (others => '0'));

  -- ventana de pooling: se guardan las dos filas de conv1 necesarias
  type t_prow is array (0 to 7, 0 to 15) of integer range -128 to 127;
  signal prow0 : t_prow := (others => (others => 0));  -- fila par
  signal prow1 : t_prow := (others => (others => 0));  -- fila impar

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  -- requantize combinacional (una instancia logica por canal, secuencial aqui)
  function do_requant (a : signed(C_ACC_W-1 downto 0);
                       m : signed(C_MULT_W-1 downto 0);
                       mut : natural) return signed is
    variable acc_v : signed(C_ACC_W-1 downto 0);
    variable p     : signed(C_ACC_W+C_MULT_W-1 downto 0);
    variable sh    : signed(C_ACC_W+C_MULT_W-1 downto 0);
    variable r     : signed(C_DATA_W-1 downto 0);
  begin
    acc_v := a;
    if mut = 1 then
      null;                          -- MUT 1: sin ReLU
    else
      if acc_v < 0 then
        acc_v := (others => '0');
      end if;
    end if;
    p := acc_v * m;
    if mut = 2 then
      null;                          -- MUT 2: sin redondeo
    else
      p := p + to_signed(2**(C_SHIFT-1), p'length);
    end if;
    sh := shift_right(p, C_SHIFT);
    if sh > 127 then
      r := to_signed(127, C_DATA_W);
    elsif sh < -128 then
      r := to_signed(-128, C_DATA_W);
    else
      r := resize(sh, C_DATA_W);
    end if;
    return r;
  end function;

begin

  busy <= busy_r;
  done <= done_r;
  out_data <= to_signed(out_ram(to_integer(out_addr)), C_DATA_W);

  -- ---------------- escritura de memorias ----------------
  wr_proc : process(clk)
  begin
    if rising_edge(clk) then
      if img_we = '1' then
        img_ram(to_integer(img_addr)) <= to_integer(img_data);
      end if;
      if w_we = '1' then
        w_ram(to_integer(w_addr)) <= to_integer(w_data);
      end if;
      if b_we = '1' then
        b_ram(to_integer(b_addr)) <= to_integer(b_data);
      end if;
    end if;
  end process;

  -- ---------------- instancia del array (Paso 3) ----------------
  u_array : entity work.npu_array
    generic map (G_PE_DIM => 8, G_ACC_W => C_ACC_W, G_MUT => 0)
    port map (clk => clk, rst_n => rst_n,
              win_start => arr_win_start, en => arr_en, win_end => arr_win_end,
              a_col => arr_a_col, w_mat => arr_w_mat, bias_in => arr_bias,
              valid_out => arr_valid, acc_out => arr_acc);

  -- ---------------- FSM principal ----------------
  fsm_proc : process(clk)
    variable iy, ix : integer;
    variable a_v    : integer;
    variable w_v    : integer;
    variable sum    : signed(C_ACC_W downto 0);
    variable ky, kx : integer;
    variable m0, m1 : integer;
    variable mx     : integer;
    variable oy, ox : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state  <= S_IDLE;
        busy_r <= '0';
        done_r <= '0';
        px <= 0; py <= 0; kstep <= 0;
      else
        done_r <= '0';

        case state is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r <= '1';
              px <= 0; py <= 0;
              wl1_i <= 0;
              state <= S_WLOAD;
            end if;

          when S_PIX =>
            -- El bias entra por el puerto del array; win_start limpia los PEs.
            for o in 0 to 7 loop
              arr_bias(o) <= to_signed(b_ram(o), C_ACC_W);
            end loop;
            arr_win_start <= '1';
            arr_en        <= '0';
            arr_win_end   <= '0';
            kstep <= 0;
            state <= S_MAC;

          when S_WLOAD =>
            -- Precarga completa de los 72 pesos, una lectura por ciclo.
            arr_win_start <= '0';
            arr_en        <= '0';
            if wl1_i < 72 then
              wreg1(wl1_i) <= to_signed(w_ram(wl1_i), C_DATA_W);
              wl1_i <= wl1_i + 1;
            else
              state <= S_PIX;
            end if;

          when S_MAC =>
            -- Un paso del kernel presentado al array. conv1 tiene 1 canal de
            -- entrada: la fila 0 lleva el pixel, las filas 1..7 van a cero
            -- (verificado por la sonda de filas ociosas del Paso 5).
            arr_win_start <= '0';
            ky := kstep / 3;
            kx := kstep mod 3;
            if G_MUT = 4 then
              iy := py + ky;                 -- MUT 4: padding corrido en Y
              ix := px + kx - 1;
            else
              iy := py + ky - 1;
              ix := px + kx - 1;
            end if;
            if iy >= 0 and iy < 16 and ix >= 0 and ix < 16 then
              a_v := img_ram(iy*16 + ix);
            else
              a_v := 0;                      -- padding same
            end if;

            arr_a_col(0) <= to_signed(a_v, C_DATA_W);
            for r in 1 to 7 loop
              arr_a_col(r) <= (others => '0');
            end loop;

            -- w_mat(k*8 + r): canal de salida k, canal de entrada r.
            -- Solo r=0 tiene peso real; el resto es cero.
            for k in 0 to 7 loop
              arr_w_mat(k*8) <= wreg1(k*9 + kstep);
              for r in 1 to 7 loop
                arr_w_mat(k*8 + r) <= (others => '0');
              end loop;
            end loop;

            arr_en <= '1';
            if kstep = 8 then
              state <= S_WEND;
            else
              kstep <= kstep + 1;
            end if;

          when S_WEND =>
            arr_en      <= '0';
            arr_win_end <= '1';
            red_wait    <= 0;
            state       <= S_RED;

          when S_RED =>
            -- El arbol de reduccion del array tiene 3 etapas registradas.
            arr_win_end <= '0';
            if G_MUT = 5 then
              state <= S_RQ;                 -- MUT 5: no espera la reduccion
            elsif red_wait = 3 then
              state <= S_RQ;
            else
              red_wait <= red_wait + 1;
            end if;

          when S_RQ =>
            -- requantize de los 8 canales y almacenamiento en la fila de pooling
            for o in 0 to 7 loop
              if py mod 2 = 0 then
                prow0(o, px) <= to_integer(do_requant(arr_acc(o), mult_in, G_MUT));
              else
                prow1(o, px) <= to_integer(do_requant(arr_acc(o), mult_in, G_MUT));
              end if;
            end loop;
            state <= S_POOL;

          when S_POOL =>
            -- Al terminar una fila impar y en columnas impares, se cierra
            -- la ventana 2x2 formada por prow0 y prow1.
            if py mod 2 = 1 and px mod 2 = 1 then
              oy := py / 2;
              ox := px / 2;
              for o in 0 to 7 loop
                m0 := prow0(o, px-1);
                if prow0(o, px) > m0 then m0 := prow0(o, px); end if;
                m1 := prow1(o, px-1);
                if prow1(o, px) > m1 then m1 := prow1(o, px); end if;
                if G_MUT = 3 then
                  mx := m0;                       -- MUT 3: ignora la fila impar
                else
                  mx := m0;
                  if m1 > mx then mx := m1; end if;
                end if;
                out_ram(o*64 + oy*8 + ox) <= mx;
              end loop;
            end if;

            -- avance de pixel
            if px = 15 then
              px <= 0;
              if py = 15 then
                state <= S_DONE;
              else
                py <= py + 1;
                state <= S_PIX;
              end if;
            else
              px <= px + 1;
              state <= S_PIX;
            end if;

          when S_DONE =>
            busy_r <= '0';
            done_r <= '1';
            state  <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
