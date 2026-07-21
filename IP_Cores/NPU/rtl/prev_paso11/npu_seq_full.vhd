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
    p2_addr   : in  unsigned(7 downto 0);          -- 16 x 16 = 256
    p2_data   : out signed(C_DATA_W-1 downto 0);
    lg_addr   : in  unsigned(3 downto 0);          -- 10 logits
    lg_data   : out signed(C_DATA_W-1 downto 0);
    clase     : out unsigned(3 downto 0)
  );
end entity npu_seq_full;

architecture rtl of npu_seq_full is

  type t_in_ram  is array (0 to 511)  of integer range -128 to 127;
  type t_w2_ram  is array (0 to 1151) of integer range -128 to 127;
  type t_b2_ram  is array (0 to 15)   of integer;
  type t_w3_ram  is array (0 to 2559) of integer range -128 to 127;
  type t_b3_ram  is array (0 to 9)    of integer;
  type t_c2_ram  is array (0 to 1023) of integer range -128 to 127;  -- conv2 out
  type t_p2_ram  is array (0 to 255)  of integer range -128 to 127;  -- pool2 out
  type t_lg_ram  is array (0 to 9)    of integer range -128 to 127;

  signal in_ram : t_in_ram := (others => 0);
  signal w2_ram : t_w2_ram := (others => 0);
  signal b2_ram : t_b2_ram := (others => 0);
  signal w3_ram : t_w3_ram := (others => 0);
  signal b3_ram : t_b3_ram := (others => 0);
  signal c2_ram : t_c2_ram := (others => 0);
  signal p2_ram : t_p2_ram := (others => 0);
  signal lg_ram : t_lg_ram := (others => 0);

  -- Acumuladores externos del tile: 8 canales x 64 pixeles int32.
  -- Un array por canal -> una lectura y una escritura por ciclo cada uno.
  type t_accmem is array (0 to 63) of integer;
  type t_accbank is array (0 to 7) of t_accmem;
  signal accm : t_accbank := (others => (others => 0));

  -- Registro de los 64 pesos del (tile,kstep) actual
  signal wreg : t_data_arr(0 to 63) := (others => (others => '0'));
  signal wl_i : natural range 0 to 64 := 0;
  signal kstep_r : natural range 0 to 9 := 0;
  signal pix_i : natural range 0 to 64 := 0;
  signal rq_i  : natural range 0 to 64 := 0;

  -- Bucles reordenados para que los pesos se lean UNA vez por (tile,kstep)
  -- en lugar de 64 lecturas simultaneas por pixel: asi w2_ram mantiene una
  -- sola lectura por ciclo y puede mapear a BRAM.
  type t_state is (S_IDLE,
                   S_C2_INIT, S_C2_WLOAD, S_C2_PIX, S_C2_MAC, S_C2_WEND,
                   S_C2_RED, S_C2_ACC, S_C2_NEXT, S_C2_RQ,
                   S_P2, S_FC, S_ARGMAX, S_DONE);
  signal state : t_state := S_IDLE;

  signal tile   : natural range 0 to 1  := 0;   -- tile de salida de conv2
  signal px, py : natural range 0 to 7  := 0;
  signal kstep  : natural range 0 to 8  := 0;
  signal red_w  : natural range 0 to 7  := 0;

  -- pool2 / fc / argmax
  signal p2_idx : natural range 0 to 255 := 0;
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
  signal arr_a_col     : t_data_arr(0 to 7) := (others => (others => '0'));
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

begin

  busy    <= busy_r;
  done    <= done_r;
  p2_data <= to_signed(p2_ram(to_integer(p2_addr)), C_DATA_W);
  lg_data <= to_signed(lg_ram(to_integer(lg_addr)), C_DATA_W);
  clase   <= to_unsigned(am_best, 4);

  u_array : entity work.npu_array
    generic map (G_PE_DIM => 8, G_ACC_W => C_ACC_W, G_MUT => 0)
    port map (clk => clk, rst_n => rst_n,
              win_start => arr_win_start, en => arr_en, win_end => arr_win_end,
              a_col => arr_a_col, w_mat => arr_w_mat, bias_in => arr_bias,
              valid_out => arr_valid, acc_out => arr_acc);

  wr_proc : process(clk)
  begin
    if rising_edge(clk) then
      if in_we = '1' then in_ram(to_integer(in_addr)) <= to_integer(in_data); end if;
      if w2_we = '1' then w2_ram(to_integer(w2_addr)) <= to_integer(w2_data); end if;
      if b2_we = '1' then b2_ram(to_integer(b2_addr)) <= to_integer(b2_data); end if;
      if w3_we = '1' then w3_ram(to_integer(w3_addr)) <= to_integer(w3_data); end if;
      if b3_we = '1' then b3_ram(to_integer(b3_addr)) <= to_integer(b3_data); end if;
    end if;
  end process;

  fsm_proc : process(clk)
    variable ky, kx, iy, ix : integer;
    variable och  : integer;
    variable m0, m1, mx : integer;
    variable oy, ox : integer;
    variable c, yy, xx : integer;
    variable sumv : signed(C_ACC_W downto 0);
    variable fv   : integer;
    variable wv   : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state <= S_IDLE; busy_r <= '0'; done_r <= '0';
        tile <= 0; px <= 0; py <= 0; kstep <= 0;
      else
        done_r <= '0';

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
            if pix_i = 0 then
              for k in 0 to 7 loop
                if G_MUT = 1 then
                  accm(k)(0) <= b2_ram(k);          -- MUT 1: siempre tile 0
                else
                  accm(k)(0) <= b2_ram(tile*8 + k);
                end if;
              end loop;
              pix_i <= 1;
            elsif pix_i < 64 then
              for k in 0 to 7 loop
                if G_MUT = 1 then
                  accm(k)(pix_i) <= b2_ram(k);
                else
                  accm(k)(pix_i) <= b2_ram(tile*8 + k);
                end if;
              end loop;
              pix_i <= pix_i + 1;
            else
              kstep_r <= 0;
              wl_i    <= 0;
              state   <= S_C2_WLOAD;
            end if;

          when S_C2_WLOAD =>
            -- Precarga de los 64 pesos del (tile,kstep) actual: UNA lectura
            -- de w2_ram por ciclo. Indice wl_i = k*8 + r.
            if wl_i < 64 then
              och := tile*8 + (wl_i / 8);
              if G_MUT = 2 then
                -- MUT 2: indices de canal de entrada invertidos
                wreg(wl_i) <= to_signed(
                  w2_ram((och*8 + (7 - (wl_i mod 8)))*9 + kstep_r), C_DATA_W);
              else
                wreg(wl_i) <= to_signed(
                  w2_ram((och*8 + (wl_i mod 8))*9 + kstep_r), C_DATA_W);
              end if;
              wl_i <= wl_i + 1;
            else
              pix_i <= 0;
              state <= S_C2_PIX;
            end if;

          when S_C2_PIX =>
            -- Bias en cero: la acumulacion se lleva fuera del array
            for o in 0 to 7 loop
              arr_bias(o) <= (others => '0');
            end loop;
            arr_win_start <= '1';
            arr_en <= '0'; arr_win_end <= '0';
            state <= S_C2_MAC;

          when S_C2_MAC =>
            -- Un solo paso de kernel por pixel: los pesos ya estan en wreg
            arr_win_start <= '0';
            ky := kstep_r / 3;
            kx := kstep_r mod 3;
            iy := (pix_i / 8) + ky - 1;
            ix := (pix_i mod 8) + kx - 1;

            for r in 0 to 7 loop
              if iy >= 0 and iy < 8 and ix >= 0 and ix < 8 then
                arr_a_col(r) <= to_signed(in_ram(r*64 + iy*8 + ix), C_DATA_W);
              else
                arr_a_col(r) <= (others => '0');
              end if;
            end loop;

            for i in 0 to 63 loop
              arr_w_mat(i) <= wreg(i);
            end loop;

            arr_en <= '1';
            state  <= S_C2_WEND;

          when S_C2_WEND =>
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
            for k in 0 to 7 loop
              accm(k)(pix_i) <= accm(k)(pix_i) + to_integer(arr_acc(k));
            end loop;
            state <= S_C2_NEXT;

          when S_C2_NEXT =>
            if pix_i = 63 then
              pix_i <= 0;
              if kstep_r = 8 then
                rq_i  <= 0;
                state <= S_C2_RQ;
              else
                kstep_r <= kstep_r + 1;
                wl_i    <= 0;
                state   <= S_C2_WLOAD;
              end if;
            else
              pix_i <= pix_i + 1;
              state <= S_C2_PIX;
            end if;

          when S_C2_RQ =>
            -- Requantize de los 64 pixeles del tile
            if rq_i < 64 then
              for k in 0 to 7 loop
                och := tile*8 + k;
                c2_ram(och*64 + rq_i) <= to_integer(
                  do_requant(to_signed(accm(k)(rq_i), C_ACC_W), mult2_in, true));
              end loop;
              rq_i <= rq_i + 1;
            else
              if tile = 1 then
                p2_idx <= 0;
                state  <= S_P2;
              else
                tile  <= 1;
                pix_i <= 0;
                state <= S_C2_INIT;
              end if;
            end if;

          when S_P2 =>
            -- maxpool 2x2 sobre conv2: 16 canales 8x8 -> 4x4
            c  := p2_idx / 16;
            oy := (p2_idx mod 16) / 4;
            ox := p2_idx mod 4;
            m0 := c2_ram(c*64 + (2*oy)*8 + 2*ox);
            if c2_ram(c*64 + (2*oy)*8 + 2*ox + 1) > m0 then
              m0 := c2_ram(c*64 + (2*oy)*8 + 2*ox + 1);
            end if;
            m1 := c2_ram(c*64 + (2*oy+1)*8 + 2*ox);
            if c2_ram(c*64 + (2*oy+1)*8 + 2*ox + 1) > m1 then
              m1 := c2_ram(c*64 + (2*oy+1)*8 + 2*ox + 1);
            end if;
            if G_MUT = 4 then
              mx := m0;                      -- MUT 4: pool2 ignora la fila impar
            else
              mx := m0;
              if m1 > mx then mx := m1; end if;
            end if;
            p2_ram(p2_idx) <= mx;

            if p2_idx = 255 then
              fc_o <= 0; fc_i <= 0;
              fc_acc <= to_signed(b3_ram(0), C_ACC_W);
              state <= S_FC;
            else
              p2_idx <= p2_idx + 1;
            end if;

          when S_FC =>
            -- flatten: canal -> fila -> columna, ya es el orden de p2_ram
            if G_MUT = 3 then
              fv := p2_ram(fc_i);
              wv := w3_ram(fc_i*10 + fc_o);      -- MUT 3: W3 transpuesta
            else
              fv := p2_ram(fc_i);
              wv := w3_ram(fc_o*256 + fc_i);
            end if;
            sumv := resize(fc_acc, C_ACC_W+1) + to_signed(fv*wv, C_ACC_W+1);
            assert sumv(C_ACC_W) = sumv(C_ACC_W-1)
              report "npu_seq_full: overflow del acumulador de FC" severity failure;

            if fc_i = 255 then
              fc_res(fc_o) <= sumv(C_ACC_W-1 downto 0);
              lg_ram(fc_o) <= to_integer(
                do_requant(sumv(C_ACC_W-1 downto 0), mult3_in, false));
              if fc_o = 9 then
                am_i <= 1;
                am_best <= 0;
                am_val <= sumv(C_ACC_W-1 downto 0);   -- provisional, se corrige
                state <= S_ARGMAX;
              else
                fc_o <= fc_o + 1;
                fc_i <= 0;
                fc_acc <= to_signed(b3_ram(fc_o + 1), C_ACC_W);
              end if;
            else
              fc_acc <= sumv(C_ACC_W-1 downto 0);
              fc_i <= fc_i + 1;
            end if;

          when S_ARGMAX =>
            -- argmax sobre el acumulador int32 (no sobre los logits)
            if am_i = 1 then
              am_best <= 0;
              am_val  <= fc_res(0);
              am_i    <= 2;
            elsif am_i <= 10 then
              if G_MUT = 5 then
                -- MUT 5: argmax sobre el logit int8 (pierde resolucion)
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
