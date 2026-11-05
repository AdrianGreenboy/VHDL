-- HERCOSSNUX NPU - secuenciador de conv2 + pool2 + FC + argmax (entrega 2).
--
-- Entrada : pool1 (8 canales, 8x8 int8) = salida de la entrega 1
-- Etapas  :
--   conv2 : 8 -> 16 canales, 8x8, padding same. DOS tiles de salida de 8
--           canales cada uno; el bias se recarga por tile.
--   pool2 : maxpool 2x2 -> 16 canales 4x4
--   flat  : orden canal -> fila -> columna (verificado por la sonda 4)
--   fc    : 256 -> 10, acumulador int32, 32 tiles de entrada
--   argmax: sobre el acumulador int32 (NO sobre los logits requantizados)
--
-- Usa npu_array (Paso 3) para conv2. La FC se calcula con un MAC dedicado
-- porque su forma (256 entradas, 10 salidas) no encaja en el array 8x8 sin
-- desperdiciar 6 de cada 8 columnas en el ultimo tile.
--
-- Audit 2026-11 (ASIC): las memorias de trabajo son instancias npu_sram_1r1w
-- (1 escritura + 1 lectura SINCRONA por ciclo y por banco):
--   in_ram : 8 bancos 64x8   (banco = canal de entrada: 8 lecturas/ciclo)
--   w2_ram : 1 banco 1152x8  (precarga a wreg, +1 ciclo por (tile,kstep))
--   w3_ram : 1 banco 2560x8  (misma temporizacion que antes: lectura en
--                             S_FC_RD, dato en S_FC_MAC)
--   accm   : 8 bancos 64x32  (banco = canal del tile). El RMW de S_C2_ACC
--                             lee en S_C2_WEND (pix_i estable) y escribe en
--                             S_C2_ACC: 1 lectura + 1 escritura por banco.
--   c2_ram : 8 bancos 128x8  (banco = canal mod 8, direccion tile*64+pixel:
--                             las 8 escrituras de S_C2_RQ van a bancos
--                             distintos). pool2 lee los 4 pixeles de la
--                             ventana en 4 ciclos (antes 4 lecturas/ciclo).
--   p2_ram : 1 banco 256x8   (lectura interna de la FC cuando busy, lectura
--                             externa p2_addr -> p2_data con 1 ciclo de
--                             latencia cuando esta ociosa)
--   b2/b3 (16/10 int32) y lg_ram (10 bytes, lectura combinacional) se quedan
--   en registros: son demasiado pequenas para un macro SRAM.
-- Resultados bit-identicos al oraculo; cuesta ciclos extra (pool2 x5).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity npu_seq_full is
  generic (
    G_MUT : natural := 0
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    -- entrada: pool1, 8 canales x 64 = 512 bytes
    in_we     : in  std_logic;
    in_addr   : in  unsigned(8 downto 0);
    in_data   : in  signed(C_DATA_W-1 downto 0);

    -- pesos conv2: 16 x 8 x 9 = 1152
    w2_we     : in  std_logic;
    w2_addr   : in  unsigned(10 downto 0);
    w2_data   : in  signed(C_DATA_W-1 downto 0);

    -- bias conv2: 16 int32
    b2_we     : in  std_logic;
    b2_addr   : in  unsigned(3 downto 0);
    b2_data   : in  signed(C_ACC_W-1 downto 0);

    -- pesos FC: 10 x 256 = 2560
    w3_we     : in  std_logic;
    w3_addr   : in  unsigned(11 downto 0);
    w3_data   : in  signed(C_DATA_W-1 downto 0);

    -- bias FC: 10 int32
    b3_we     : in  std_logic;
    b3_addr   : in  unsigned(3 downto 0);
    b3_data   : in  signed(C_ACC_W-1 downto 0);

    mult2_in  : in  signed(C_MULT_W-1 downto 0);
    mult3_in  : in  signed(C_MULT_W-1 downto 0);

    start     : in  std_logic;
    busy      : out std_logic;
    done      : out std_logic;

    -- resultados
    p2_addr   : in  unsigned(7 downto 0);          -- 16 x 16 = 256 (lectura sincrona)
    p2_data   : out signed(C_DATA_W-1 downto 0);
    lg_addr   : in  unsigned(3 downto 0);          -- 10 logits
    lg_data   : out signed(C_DATA_W-1 downto 0);
    clase     : out unsigned(3 downto 0)
  );
end entity npu_seq_full;

architecture rtl of npu_seq_full is

  type t_b2_ram  is array (0 to 15)   of integer;
  type t_b3_ram  is array (0 to 9)    of integer;
  type t_lg_ram  is array (0 to 9)    of integer range -128 to 127;
  signal b2_ram : t_b2_ram := (others => 0);
  signal b3_ram : t_b3_ram := (others => 0);
  signal lg_ram : t_lg_ram := (others => 0);

  type t_slv8_arr  is array (0 to 7) of std_logic_vector(7 downto 0);
  type t_slv32_arr is array (0 to 7) of std_logic_vector(31 downto 0);

  -- in_ram: 8 bancos (canal de entrada)
  signal in_we_b  : std_logic_vector(7 downto 0);
  signal in_raddr : natural range 0 to 63 := 0;
  signal in_re    : std_logic;
  signal in_q     : t_slv8_arr;
  signal in_ok    : std_logic := '0';      -- mascara de padding registrada
  -- w2
  signal w2_raddr : natural range 0 to 1151 := 0;
  signal w2_re    : std_logic;
  signal w2_q     : std_logic_vector(7 downto 0);
  -- w3
  signal w3_raddr : natural range 0 to 2559 := 0;
  signal w3_re    : std_logic;
  signal w3_q     : std_logic_vector(7 downto 0);
  -- accm: 8 bancos 64 x int32
  signal acc_we    : std_logic := '0';
  signal acc_waddr : natural range 0 to 63 := 0;
  signal acc_wdata : t_slv32_arr := (others => (others => '0'));
  signal acc_re    : std_logic;
  signal acc_raddr : natural range 0 to 63 := 0;
  signal acc_q     : t_slv32_arr;
  -- c2: 8 bancos 128 x 8 (canal mod 8, tile*64 + pixel)
  signal c2_we    : std_logic := '0';
  signal c2_waddr : natural range 0 to 127 := 0;
  signal c2_wdata : t_slv8_arr := (others => (others => '0'));
  signal c2_re    : std_logic;
  signal c2_raddr : natural range 0 to 127 := 0;
  signal c2_q     : t_slv8_arr;
  -- p2
  signal p2_we    : std_logic := '0';
  signal p2_waddr : natural range 0 to 255 := 0;
  signal p2_wdata : std_logic_vector(7 downto 0) := (others => '0');
  signal p2_re    : std_logic;
  signal p2_raddr : natural range 0 to 255 := 0;
  signal p2_q     : std_logic_vector(7 downto 0);

  -- Registro de los 64 pesos del (tile,kstep) actual
  signal wreg : t_data_arr(0 to 63) := (others => (others => '0'));
  signal wl_i : natural range 0 to 65 := 0;
  signal kstep_r : natural range 0 to 9 := 0;
  signal pix_i : natural range 0 to 64 := 0;
  signal rq_i  : natural range 0 to 64 := 0;

  type t_state is (S_IDLE,
                   S_C2_INIT, S_C2_WLOAD, S_C2_PIX, S_C2_MAC, S_C2_WEND,
                   S_C2_RED, S_C2_ACC, S_C2_NEXT, S_C2_RQRD, S_C2_RQ,
                   S_P2, S_FC_RD, S_FC_MAC, S_FC_RQ, S_ARGMAX, S_DONE);
  signal state : t_state := S_IDLE;

  signal tile   : natural range 0 to 1  := 0;
  signal kstep  : natural range 0 to 8  := 0;
  signal red_w  : natural range 0 to 7  := 0;

  -- pool2 / fc / argmax
  signal p2_idx : natural range 0 to 255 := 0;
  signal p2_k   : natural range 0 to 4   := 0;     -- paso de lectura de la ventana
  signal p2_v   : t_data_arr(0 to 2) := (others => (others => '0'));
  signal fc_o   : natural range 0 to 15  := 0;
  signal fc_i   : natural range 0 to 255 := 0;
  signal fc_acc : signed(C_ACC_W-1 downto 0) := (others => '0');
  signal am_i   : natural range 0 to 15  := 0;
  signal am_best : natural range 0 to 15 := 0;
  signal am_val  : signed(C_ACC_W-1 downto 0) := (others => '0');
  type t_fcacc is array (0 to 9) of signed(C_ACC_W-1 downto 0);
  signal fc_res : t_fcacc := (others => (others => '0'));

  -- array
  signal arr_win_start : std_logic := '0';
  signal arr_en        : std_logic := '0';
  signal arr_win_end   : std_logic := '0';
  signal arr_a_col     : t_data_arr(0 to 7);
  signal arr_w_mat     : t_data_arr(0 to 63) := (others => (others => '0'));
  signal arr_bias      : t_acc_arr(0 to 7) := (others => (others => '0'));
  signal arr_valid     : std_logic;
  signal arr_acc       : t_acc_arr(0 to 7);

  signal busy_r : std_logic := '0';
  signal done_r : std_logic := '0';

  function do_requant (a : signed(C_ACC_W-1 downto 0);
                       m : signed(C_MULT_W-1 downto 0);
                       relu : boolean) return signed is
    variable v : signed(C_ACC_W-1 downto 0);
    variable p : signed(C_ACC_W+C_MULT_W-1 downto 0);
    variable s : signed(C_ACC_W+C_MULT_W-1 downto 0);
    variable r : signed(C_DATA_W-1 downto 0);
  begin
    v := a;
    if relu and v < 0 then
      v := (others => '0');
    end if;
    p := v * m;
    p := p + to_signed(2**(C_SHIFT-1), p'length);
    s := shift_right(p, C_SHIFT);
    if s > 127 then
      r := to_signed(127, C_DATA_W);
    elsif s < -128 then
      r := to_signed(-128, C_DATA_W);
    else
      r := resize(s, C_DATA_W);
    end if;
    return r;
  end function;

  function smax (a, b : signed) return signed is
  begin
    if b > a then return b; else return a; end if;
  end function;

  -- pixel j (0..3) de la ventana 2x2 de la salida p de pool2, en el banco
  -- c mod 8, direccion (c/8)*64 + y*8 + x
  function p2_win_addr (p : natural; j : natural) return natural is
    variable c, oy, ox, y, x : natural;
  begin
    c  := p / 16;
    oy := (p mod 16) / 4;
    ox := p mod 4;
    y  := 2*oy + j / 2;
    x  := 2*ox + j mod 2;
    return (c / 8)*64 + y*8 + x;
  end function;

begin

  busy    <= busy_r;
  done    <= done_r;
  p2_data <= signed(p2_q);
  lg_data <= to_signed(lg_ram(to_integer(lg_addr)), C_DATA_W);
  clase   <= to_unsigned(am_best, 4);

  u_array : entity work.npu_array
    generic map (G_PE_DIM => 8, G_ACC_W => C_ACC_W, G_MUT => 0)
    port map (clk => clk, rst_n => rst_n,
              win_start => arr_win_start, en => arr_en, win_end => arr_win_end,
              a_col => arr_a_col, w_mat => arr_w_mat, bias_in => arr_bias,
              valid_out => arr_valid, acc_out => arr_acc);

  -- ---------------- memorias 1R1W ----------------
  g_banks : for b in 0 to 7 generate
    in_we_b(b) <= '1' when in_we = '1' and to_integer(in_addr(8 downto 6)) = b else '0';
    u_in : entity work.npu_sram_1r1w
      generic map (G_DEPTH => 64, G_WIDTH => 8)
      port map (clk => clk, we => in_we_b(b), waddr => to_integer(in_addr(5 downto 0)),
                wdata => std_logic_vector(in_data),
                re => in_re, raddr => in_raddr, rdata => in_q(b));
    u_acc : entity work.npu_sram_1r1w
      generic map (G_DEPTH => 64, G_WIDTH => 32)
      port map (clk => clk, we => acc_we, waddr => acc_waddr, wdata => acc_wdata(b),
                re => acc_re, raddr => acc_raddr, rdata => acc_q(b));
    u_c2 : entity work.npu_sram_1r1w
      generic map (G_DEPTH => 128, G_WIDTH => 8)
      port map (clk => clk, we => c2_we, waddr => c2_waddr, wdata => c2_wdata(b),
                re => c2_re, raddr => c2_raddr, rdata => c2_q(b));
    arr_a_col(b) <= signed(in_q(b)) when in_ok = '1' else (others => '0');
  end generate;

  u_w2 : entity work.npu_sram_1r1w
    generic map (G_DEPTH => 1152, G_WIDTH => 8)
    port map (clk => clk, we => w2_we, waddr => to_integer(w2_addr),
              wdata => std_logic_vector(w2_data),
              re => w2_re, raddr => w2_raddr, rdata => w2_q);
  u_w3 : entity work.npu_sram_1r1w
    generic map (G_DEPTH => 2560, G_WIDTH => 8)
    port map (clk => clk, we => w3_we, waddr => to_integer(w3_addr),
              wdata => std_logic_vector(w3_data),
              re => w3_re, raddr => w3_raddr, rdata => w3_q);
  u_p2 : entity work.npu_sram_1r1w
    generic map (G_DEPTH => 256, G_WIDTH => 8)
    port map (clk => clk, we => p2_we, waddr => p2_waddr, wdata => p2_wdata,
              re => p2_re, raddr => p2_raddr, rdata => p2_q);

  -- ---------------- direcciones de lectura (combinacionales) ----------------
  rd_addr_proc : process(state, pix_i, kstep_r, wl_i, tile, rq_i, p2_idx, p2_k,
                         fc_o, fc_i, p2_addr)
    variable ky, kx, iy, ix, och : integer;
  begin
    -- in_ram: pixel del kernel (fuera de rango -> direccion 0, enmascarado)
    ky := kstep_r / 3;
    kx := kstep_r mod 3;
    iy := (pix_i mod 64) / 8 + ky - 1;
    ix := (pix_i mod 64) mod 8 + kx - 1;
    if iy >= 0 and iy < 8 and ix >= 0 and ix < 8 then
      in_raddr <= iy*8 + ix;
    else
      in_raddr <= 0;
    end if;
    -- w2: peso wl_i del (tile,kstep)
    if wl_i < 64 then
      och := tile*8 + (wl_i / 8);
      if G_MUT = 2 then
        w2_raddr <= (och*8 + (7 - (wl_i mod 8)))*9 + kstep_r;   -- MUT 2
      else
        w2_raddr <= (och*8 + (wl_i mod 8))*9 + kstep_r;
      end if;
    else
      w2_raddr <= 0;
    end if;
    -- accm: pixel actual (RMW) o pixel del requantize
    if state = S_C2_RQRD then
      acc_raddr <= rq_i mod 64;
    else
      acc_raddr <= pix_i mod 64;
    end if;
    -- c2: pixel j = p2_k de la ventana de pool2
    if p2_k < 4 then
      c2_raddr <= p2_win_addr(p2_idx, p2_k);
    else
      c2_raddr <= 0;
    end if;
    -- w3 / p2
    if G_MUT = 3 then
      w3_raddr <= (fc_i*10 + fc_o) mod 2560;                   -- MUT 3
    else
      w3_raddr <= (fc_o mod 10)*256 + fc_i;
    end if;
    if state = S_IDLE then
      p2_raddr <= to_integer(p2_addr);                          -- lectura externa
    else
      p2_raddr <= fc_i;
    end if;
  end process;

  in_re  <= '1' when state = S_C2_MAC else '0';
  w2_re  <= '1' when state = S_C2_WLOAD and wl_i < 64 else '0';
  acc_re <= '1' when state = S_C2_WEND or state = S_C2_RQRD else '0';
  c2_re  <= '1' when state = S_P2 and p2_k < 4 else '0';
  w3_re  <= '1' when state = S_FC_RD else '0';
  p2_re  <= '1' when state = S_FC_RD or state = S_IDLE else '0';

  wr_proc : process(clk)
  begin
    if rising_edge(clk) then
      if b2_we = '1' then b2_ram(to_integer(b2_addr)) <= to_integer(b2_data); end if;
      if b3_we = '1' then b3_ram(to_integer(b3_addr)) <= to_integer(b3_data); end if;
    end if;
  end process;

  fsm_proc : process(clk)
    variable ky, kx, iy, ix : integer;
    variable och  : integer;
    variable m0, m1, mx : signed(C_DATA_W-1 downto 0);
    variable sumv : signed(C_ACC_W downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state <= S_IDLE; busy_r <= '0'; done_r <= '0';
        tile <= 0; kstep <= 0;
        acc_we <= '0'; c2_we <= '0'; p2_we <= '0'; in_ok <= '0';
      else
        done_r <= '0';
        acc_we <= '0';
        c2_we  <= '0';
        p2_we  <= '0';

        case state is

          when S_IDLE =>
            busy_r <= '0';
            if start = '1' then
              busy_r <= '1';
              tile <= 0; pix_i <= 0;
              state <= S_C2_INIT;
            end if;

          when S_C2_INIT =>
            -- Inicializar los 64 acumuladores del tile con el bias del canal
            if pix_i < 64 then
              acc_we    <= '1';
              acc_waddr <= pix_i;
              for k in 0 to 7 loop
                if G_MUT = 1 then
                  acc_wdata(k) <= std_logic_vector(to_signed(b2_ram(k), 32));   -- MUT 1
                else
                  acc_wdata(k) <= std_logic_vector(to_signed(b2_ram(tile*8 + k), 32));
                end if;
              end loop;
              pix_i <= pix_i + 1;
            else
              kstep_r <= 0;
              wl_i    <= 0;
              state   <= S_C2_WLOAD;
            end if;

          when S_C2_WLOAD =>
            -- Precarga de los 64 pesos del (tile,kstep): lectura sincrona,
            -- el dato del indice i llega con wl_i = i + 1.
            if wl_i > 0 then
              wreg(wl_i - 1) <= signed(w2_q);
            end if;
            if wl_i < 64 then
              wl_i <= wl_i + 1;
            else
              pix_i <= 0;
              state <= S_C2_PIX;
            end if;

          when S_C2_PIX =>
            for o in 0 to 7 loop
              arr_bias(o) <= (others => '0');
            end loop;
            arr_win_start <= '1';
            arr_en <= '0'; arr_win_end <= '0';
            state <= S_C2_MAC;

          when S_C2_MAC =>
            -- Un paso de kernel por pixel; la lectura de los 8 bancos de
            -- entrada se lanza en este ciclo (in_re), el dato y la mascara
            -- quedan registrados en el mismo flanco que arr_en.
            arr_win_start <= '0';
            ky := kstep_r / 3;
            kx := kstep_r mod 3;
            iy := (pix_i / 8) + ky - 1;
            ix := (pix_i mod 8) + kx - 1;
            if iy >= 0 and iy < 8 and ix >= 0 and ix < 8 then
              in_ok <= '1';
            else
              in_ok <= '0';
            end if;
            for i in 0 to 63 loop
              arr_w_mat(i) <= wreg(i);
            end loop;
            arr_en <= '1';
            state  <= S_C2_WEND;

          when S_C2_WEND =>
            -- (acc_re: lectura de accm(k)(pix_i) para el RMW de S_C2_ACC)
            arr_en <= '0'; arr_win_end <= '1'; red_w <= 0;
            state <= S_C2_RED;

          when S_C2_RED =>
            arr_win_end <= '0';
            if red_w = 3 then
              state <= S_C2_ACC;
            else
              red_w <= red_w + 1;
            end if;

          when S_C2_ACC =>
            -- Sumar la contribucion de este kstep al acumulador del pixel
            acc_we    <= '1';
            acc_waddr <= pix_i;
            for k in 0 to 7 loop
              acc_wdata(k) <= std_logic_vector(signed(acc_q(k)) + arr_acc(k));
            end loop;
            state <= S_C2_NEXT;

          when S_C2_NEXT =>
            if pix_i = 63 then
              pix_i <= 0;
              if kstep_r = 8 then
                rq_i  <= 0;
                state <= S_C2_RQRD;
              else
                kstep_r <= kstep_r + 1;
                wl_i    <= 0;
                state   <= S_C2_WLOAD;
              end if;
            else
              pix_i <= pix_i + 1;
              state <= S_C2_PIX;
            end if;

          when S_C2_RQRD =>
            -- Etapa 1: lectura sincrona de los 8 acumuladores del pixel
            if rq_i < 64 then
              state <= S_C2_RQ;
            else
              if tile = 1 then
                p2_idx <= 0; p2_k <= 0;
                state  <= S_P2;
              else
                tile  <= 1;
                pix_i <= 0;
                state <= S_C2_INIT;
              end if;
            end if;

          when S_C2_RQ =>
            -- Etapa 2: requantize (operandos = salida registrada de accm) y
            -- escritura: canal tile*8+k -> banco k, direccion tile*64+rq_i
            if rq_i < 64 then
              c2_we    <= '1';
              c2_waddr <= tile*64 + rq_i;
              for k in 0 to 7 loop
                c2_wdata(k) <= std_logic_vector(
                  do_requant(signed(acc_q(k)), mult2_in, true));
              end loop;
              rq_i  <= rq_i + 1;
              state <= S_C2_RQRD;
            end if;

          when S_P2 =>
            -- maxpool 2x2: los 4 pixeles de la ventana se leen en 4 ciclos
            -- del banco (canal mod 8); el dato j llega con p2_k = j + 1.
            och := p2_idx / 16;
            if p2_k >= 1 and p2_k <= 3 then
              p2_v(p2_k - 1) <= signed(c2_q(och mod 8));
            end if;
            if p2_k = 4 then
              m0 := smax(p2_v(0), p2_v(1));
              m1 := smax(p2_v(2), signed(c2_q(och mod 8)));
              if G_MUT = 4 then
                mx := m0;                      -- MUT 4: pool2 ignora la fila impar
              else
                mx := smax(m0, m1);
              end if;
              p2_we    <= '1';
              p2_waddr <= p2_idx;
              p2_wdata <= std_logic_vector(mx);
              p2_k     <= 0;
              if p2_idx = 255 then
                fc_o <= 0; fc_i <= 0;
                fc_acc <= to_signed(b3_ram(0), C_ACC_W);
                state <= S_FC_RD;
              else
                p2_idx <= p2_idx + 1;
              end if;
            else
              p2_k <= p2_k + 1;
            end if;

          when S_FC_RD =>
            -- Etapa 1: lectura sincrona de p2 y w3 (p2_re / w3_re)
            state <= S_FC_MAC;

          when S_FC_MAC =>
            -- Etapa 2: producto y acumulacion con la salida registrada
            sumv := resize(fc_acc, C_ACC_W+1)
                  + resize(signed(p2_q) * signed(w3_q), C_ACC_W+1);
            assert sumv(C_ACC_W) = sumv(C_ACC_W-1)
              report "npu_seq_full: overflow del acumulador de FC" severity failure;
            fc_acc <= sumv(C_ACC_W-1 downto 0);

            if fc_i = 255 then
              fc_res(fc_o) <= sumv(C_ACC_W-1 downto 0);
              state <= S_FC_RQ;
            else
              fc_i  <= fc_i + 1;
              state <= S_FC_RD;
            end if;

          when S_FC_RQ =>
            lg_ram(fc_o) <= to_integer(do_requant(fc_res(fc_o), mult3_in, false));
            if fc_o = 9 then
              am_i    <= 1;
              am_best <= 0;
              state   <= S_ARGMAX;
            else
              fc_o   <= fc_o + 1;
              fc_i   <= 0;
              fc_acc <= to_signed(b3_ram(fc_o + 1), C_ACC_W);
              state  <= S_FC_RD;
            end if;

          when S_ARGMAX =>
            -- argmax sobre el acumulador int32 (no sobre los logits)
            if am_i = 1 then
              am_best <= 0;
              am_val  <= fc_res(0);
              am_i    <= 2;
            elsif am_i <= 10 then
              if G_MUT = 5 then
                if to_signed(lg_ram(am_i - 1), C_ACC_W) > am_val then
                  am_val  <= to_signed(lg_ram(am_i - 1), C_ACC_W);
                  am_best <= am_i - 1;
                end if;
              elsif fc_res(am_i - 1) > am_val then
                am_val  <= fc_res(am_i - 1);
                am_best <= am_i - 1;
              end if;
              if am_i = 10 then
                state <= S_DONE;
              else
                am_i <= am_i + 1;
              end if;
            else
              state <= S_DONE;
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
