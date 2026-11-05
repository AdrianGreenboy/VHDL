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
--
-- Audit 2026-11 (ASIC): todas las memorias de trabajo son ahora instancias
-- npu_sram_1r1w (1 escritura + 1 lectura SINCRONA por ciclo y por banco):
--   img_ram : 1 banco 256x8      (lectura del pixel del kernel, mascara de
--                                 padding registrada aparte)
--   w_ram   : 1 banco 72x8       (precarga a wreg1, +1 ciclo de latencia)
--   out_ram : 8 bancos 64x8      (un banco por canal: 8 escrituras/ciclo)
--   pooling : prow0/prow1 (32 lecturas/ciclo) sustituidos por un maximo
--             horizontal por pares: prev/cur por canal (registros) + hrow,
--             8 bancos 8x8 (uno por canal). max es asociativo y conmutativo:
--             el resultado es bit-identico al de la ventana 2x2 original.
--   b_ram   : 8 int32, se queda en registros (8 lecturas/ciclo, demasiado
--             pequena para un macro SRAM).
-- La lectura externa out_addr -> out_data tiene ahora 1 ciclo de latencia.
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
    -- (lectura sincrona: out_data es valido el ciclo siguiente a out_addr)
    out_addr  : in  unsigned(8 downto 0);
    out_data  : out signed(C_DATA_W-1 downto 0)
  );
end entity npu_seq_conv1;

architecture rtl of npu_seq_conv1 is

  -- ---------------- memorias ----------------
  type t_b_ram is array (0 to 7) of integer;
  signal b_ram   : t_b_ram := (others => 0);

  type t_slv8_arr is array (0 to 7) of std_logic_vector(7 downto 0);
  type t_nat_arr  is array (0 to 7) of natural range 0 to 63;

  -- imagen
  signal img_raddr : natural range 0 to 255 := 0;
  signal img_re    : std_logic := '0';
  signal img_q     : std_logic_vector(7 downto 0);
  signal img_ok    : std_logic := '0';   -- '0': fuera de la imagen (padding)
  -- pesos
  signal w_raddr   : natural range 0 to 71 := 0;
  signal w_re      : std_logic := '0';
  signal w_q       : std_logic_vector(7 downto 0);
  -- salida (pool1): un banco por canal
  signal out_we    : std_logic := '0';
  signal out_waddr : natural range 0 to 63 := 0;
  signal out_wdata : t_slv8_arr := (others => (others => '0'));
  signal out_q     : t_slv8_arr;
  signal out_bank_q : natural range 0 to 7 := 0;
  -- pooling horizontal: un banco por canal (8 entradas = columnas de pool)
  signal hrow_we    : std_logic := '0';
  signal hrow_waddr : natural range 0 to 7 := 0;
  signal hrow_wdata : t_slv8_arr := (others => (others => '0'));
  signal hrow_raddr : natural range 0 to 7 := 0;
  signal hrow_q     : t_slv8_arr;
  signal prev_v, cur_v : t_data_arr(0 to 7) := (others => (others => '0'));

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
  signal arr_a_col     : t_data_arr(0 to 7);
  signal arr_w_mat     : t_data_arr(0 to 63) := (others => (others => '0'));
  signal arr_bias      : t_acc_arr(0 to 7) := (others => (others => '0'));
  signal arr_valid     : std_logic;
  signal arr_acc       : t_acc_arr(0 to 7);

  signal red_wait : natural range 0 to 7 := 0;

  -- Los 72 pesos de conv1 (8 canales x 9) se precargan UNA vez por imagen.
  signal wreg1 : t_data_arr(0 to 71) := (others => (others => '0'));
  signal wl1_i : natural range 0 to 73 := 0;

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

  function smax (a, b : signed) return signed is
  begin
    if b > a then return b; else return a; end if;
  end function;

begin

  busy <= busy_r;
  done <= done_r;

  -- ---------------- memorias (1R1W, lectura sincrona) ----------------
  u_img : entity work.npu_sram_1r1w
    generic map (G_DEPTH => 256, G_WIDTH => 8)
    port map (clk => clk, we => img_we, waddr => to_integer(img_addr),
              wdata => std_logic_vector(img_data),
              re => img_re, raddr => img_raddr, rdata => img_q);

  u_w : entity work.npu_sram_1r1w
    generic map (G_DEPTH => 72, G_WIDTH => 8)
    port map (clk => clk, we => w_we, waddr => to_integer(w_addr),
              wdata => std_logic_vector(w_data),
              re => w_re, raddr => w_raddr, rdata => w_q);

  g_banks : for o in 0 to 7 generate
    u_out : entity work.npu_sram_1r1w
      generic map (G_DEPTH => 64, G_WIDTH => 8)
      port map (clk => clk, we => out_we, waddr => out_waddr, wdata => out_wdata(o),
                re => '1', raddr => to_integer(out_addr(5 downto 0)), rdata => out_q(o));
    u_hrow : entity work.npu_sram_1r1w
      generic map (G_DEPTH => 8, G_WIDTH => 8)
      port map (clk => clk, we => hrow_we, waddr => hrow_waddr, wdata => hrow_wdata(o),
                re => '1', raddr => hrow_raddr, rdata => hrow_q(o));
  end generate;

  -- lectura externa del resultado: banco = canal, registrado como el dato
  process(clk)
  begin
    if rising_edge(clk) then
      out_bank_q <= to_integer(out_addr(8 downto 6));
    end if;
  end process;
  out_data <= signed(out_q(out_bank_q));

  -- direccion de lectura de la imagen para el paso de kernel actual
  rd_addr_proc : process(state, py, px, kstep)
    variable iy, ix, ky, kx : integer;
  begin
    ky := kstep / 3;
    kx := kstep mod 3;
    if G_MUT = 4 then
      iy := py + ky;                 -- MUT 4: padding corrido en Y
    else
      iy := py + ky - 1;
    end if;
    ix := px + kx - 1;
    if iy >= 0 and iy < 16 and ix >= 0 and ix < 16 then
      img_raddr <= iy*16 + ix;
    else
      img_raddr <= 0;
    end if;
  end process;
  img_re <= '1' when state = S_MAC else '0';

  -- conv1 tiene 1 canal de entrada: fila 0 = pixel (o 0 en el padding),
  -- filas 1..7 a cero (verificado por la sonda de filas ociosas del Paso 5)
  arr_a_col(0) <= signed(img_q) when img_ok = '1' else (others => '0');
  g_zero : for r in 1 to 7 generate
    arr_a_col(r) <= (others => '0');
  end generate;

  w_raddr <= wl1_i when wl1_i < 72 else 0;
  w_re    <= '1' when state = S_WLOAD and wl1_i < 72 else '0';
  hrow_raddr <= px / 2;

  -- ---------------- escritura del bias (registros) ----------------
  wr_proc : process(clk)
  begin
    if rising_edge(clk) then
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
    variable ky, kx : integer;
    variable m0, m1 : signed(C_DATA_W-1 downto 0);
    variable oy, ox : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state  <= S_IDLE;
        busy_r <= '0';
        done_r <= '0';
        px <= 0; py <= 0; kstep <= 0;
        out_we <= '0'; hrow_we <= '0'; img_ok <= '0';
      else
        done_r  <= '0';
        out_we  <= '0';
        hrow_we <= '0';

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
            -- Precarga de los 72 pesos: lectura sincrona, el dato del indice
            -- i llega el ciclo siguiente (wl1_i = i + 1).
            arr_win_start <= '0';
            arr_en        <= '0';
            if wl1_i > 0 then
              wreg1(wl1_i - 1) <= signed(w_q);
            end if;
            if wl1_i < 72 then
              wl1_i <= wl1_i + 1;
            else
              state <= S_PIX;
            end if;

          when S_MAC =>
            -- Un paso del kernel presentado al array (la lectura de la imagen
            -- la lanza img_re/img_raddr en este ciclo; el dato y la mascara
            -- de padding quedan registrados en el mismo flanco que arr_en).
            arr_win_start <= '0';
            ky := kstep / 3;
            kx := kstep mod 3;
            if G_MUT = 4 then
              iy := py + ky;
            else
              iy := py + ky - 1;
            end if;
            ix := px + kx - 1;
            if iy >= 0 and iy < 16 and ix >= 0 and ix < 16 then
              img_ok <= '1';
            else
              img_ok <= '0';                 -- padding same
            end if;

            -- w_mat(k*8 + r): canal de salida k, canal de entrada r.
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
            -- requantize de los 8 canales del pixel actual (hrow se lee en
            -- este ciclo en la columna de pool px/2)
            for o in 0 to 7 loop
              cur_v(o) <= do_requant(arr_acc(o), mult_in, G_MUT);
            end loop;
            state <= S_POOL;

          when S_POOL =>
            -- Fila par, columna impar: maximo horizontal del par -> hrow.
            -- Fila impar, columna impar: cierre de la ventana 2x2.
            if px mod 2 = 1 then
              if py mod 2 = 0 then
                hrow_we    <= '1';
                hrow_waddr <= px / 2;
                for o in 0 to 7 loop
                  hrow_wdata(o) <= std_logic_vector(smax(prev_v(o), cur_v(o)));
                end loop;
              else
                oy := py / 2;
                ox := px / 2;
                out_we    <= '1';
                out_waddr <= oy*8 + ox;
                for o in 0 to 7 loop
                  m0 := signed(hrow_q(o));                 -- fila par
                  m1 := smax(prev_v(o), cur_v(o));         -- fila impar
                  if G_MUT = 3 then
                    out_wdata(o) <= std_logic_vector(m0);  -- MUT 3: ignora la fila impar
                  else
                    out_wdata(o) <= std_logic_vector(smax(m0, m1));
                  end if;
                end loop;
              end if;
            end if;
            prev_v <= cur_v;

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
