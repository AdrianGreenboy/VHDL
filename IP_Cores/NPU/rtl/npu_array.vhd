-- HERCOSSNUX NPU - array sistolico PE_DIM x PE_DIM, output-stationary.
--
-- Mapeo congelado (validado en model_systolic.py):
--   fila r    <-> canal de entrada  c = r
--   columna k <-> canal de salida   o = k
--   PE(r,k) acumula sum_kernel( x[r] * w[k][r] )
--   la columna k se reduce (arbol de sumas) + bias[k] -> acc del canal k
--
-- Protocolo por ventana:
--   1. pulso 'win_start' -> limpia los 64 acumuladores
--   2. 9 ciclos con 'en': se presentan las 9 posiciones del kernel
--      (a_col = activaciones de los 8 canales, w_col = pesos de los 8x8 pares)
--   3. pulso 'win_end'   -> la reduccion se registra y sale por acc_out
--
-- La reduccion es un arbol de 3 niveles registrado (8 -> 4 -> 2 -> 1).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity npu_array is
  generic (
    G_PE_DIM : natural := 8;
    G_ACC_W  : natural := C_ACC_W;
    G_MUT    : natural := 0
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    win_start : in  std_logic;                       -- limpia acumuladores
    en        : in  std_logic;                       -- habilita acumulacion
    win_end   : in  std_logic;                       -- dispara la reduccion
    a_col     : in  t_data_arr(0 to 7);              -- activacion por fila (canal in)
    w_mat     : in  t_data_arr(0 to 63);             -- peso por par (k*8 + r)
    bias_in   : in  t_acc_arr(0 to 7);               -- bias por canal de salida
    valid_out : out std_logic;
    acc_out   : out t_acc_arr(0 to 7)                -- acumulador por canal de salida
  );
end entity npu_array;

architecture rtl of npu_array is

  type t_acc_mat is array (0 to 63) of signed(G_ACC_W-1 downto 0);
  signal pe_acc : t_acc_mat := (others => (others => '0'));

  -- Arbol de reduccion registrado
  type t_l1 is array (0 to 31) of signed(G_ACC_W-1 downto 0);
  type t_l2 is array (0 to 15) of signed(G_ACC_W-1 downto 0);
  type t_l3 is array (0 to 7)  of signed(G_ACC_W-1 downto 0);

  signal l1 : t_l1 := (others => (others => '0'));
  signal l2 : t_l2 := (others => (others => '0'));
  signal l3 : t_l3 := (others => (others => '0'));

  signal v1, v2, v3 : std_logic := '0';
  signal bias_d1, bias_d2 : t_acc_arr(0 to 7) := (others => (others => '0'));

begin

  -- ---------------- Matriz de PEs ----------------
  -- Acumulacion directa: en cada ciclo habilitado, PE(r,k) suma a_col(r)*w_mat(k*8+r).
  -- Equivale al modelo output-stationary validado, sin skew temporal explicito:
  -- la primera version prioriza equivalencia funcional verificable.
  pe_proc : process(clk)
    variable prod : signed(2*C_DATA_W-1 downto 0);
    variable sum  : signed(G_ACC_W downto 0);
    variable idx  : natural;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        pe_acc <= (others => (others => '0'));
      else
        if win_start = '1' then
          if G_MUT = 3 then
            null;                              -- MUT 3: no limpia entre ventanas
          else
            pe_acc <= (others => (others => '0'));
          end if;
        elsif en = '1' then
          for k in 0 to G_PE_DIM-1 loop
            for r in 0 to G_PE_DIM-1 loop
              idx := k*G_PE_DIM + r;

              if G_MUT = 1 and r = G_PE_DIM-1 and k = G_PE_DIM-1 then
                -- MUT 1: PE de la esquina inferior derecha muerto
                null;
              else
                if G_MUT = 2 then
                  -- MUT 2: indices de peso cruzados (r y k intercambiados)
                  prod := a_col(r) * w_mat(r*G_PE_DIM + k);
                else
                  prod := a_col(r) * w_mat(idx);
                end if;

                sum := resize(pe_acc(idx), G_ACC_W+1) + resize(prod, G_ACC_W+1);
                assert sum(G_ACC_W) = sum(G_ACC_W-1)
                  report "npu_array: overflow del acumulador int32" severity failure;
                pe_acc(idx) <= sum(G_ACC_W-1 downto 0);
              end if;
            end loop;
          end loop;
        end if;
      end if;
    end if;
  end process;

  -- ---------------- Reduccion por columna: 8 -> 4 -> 2 -> 1 ----------------
  red_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        v1 <= '0'; v2 <= '0'; v3 <= '0';
        l1 <= (others => (others => '0'));
        l2 <= (others => (others => '0'));
        l3 <= (others => (others => '0'));
      else
        -- Nivel 1: 64 -> 32
        v1 <= win_end;
        bias_d1 <= bias_in;
        for k in 0 to G_PE_DIM-1 loop
          for j in 0 to 3 loop
            l1(k*4 + j) <= resize(pe_acc(k*G_PE_DIM + 2*j), G_ACC_W)
                         + resize(pe_acc(k*G_PE_DIM + 2*j + 1), G_ACC_W);
          end loop;
        end loop;

        -- Nivel 2: 32 -> 16
        v2 <= v1;
        bias_d2 <= bias_d1;
        for k in 0 to G_PE_DIM-1 loop
          for j in 0 to 1 loop
            l2(k*2 + j) <= l1(k*4 + 2*j) + l1(k*4 + 2*j + 1);
          end loop;
        end loop;

        -- Nivel 3: 16 -> 8, mas el bias del canal
        v3 <= v2;
        for k in 0 to G_PE_DIM-1 loop
          if G_MUT = 4 then
            -- MUT 4: bias omitido en la reduccion
            l3(k) <= l2(k*2) + l2(k*2 + 1);
          else
            l3(k) <= l2(k*2) + l2(k*2 + 1) + bias_d2(k);
          end if;
        end loop;
      end if;
    end if;
  end process;

  valid_out <= v3;
  g_out : for k in 0 to 7 generate
    acc_out(k) <= l3(k);
  end generate;

end architecture rtl;
