-------------------------------------------------------------------------------
-- fir_dp.vhd  --  Datapath FIR simetrico (familia DSP IP, RV32IM SoC)
--
-- Layer 1a: FIR de fase lineal, LEN programable <=64, simetrico.
--   y[n] = sum_{k=0}^{half-1} c[k] * ( x[n-k] + x[n-(L-1-k)] )
--   con tap central (L impar) sin duplicar.
--
-- Contrato numerico (bit-exacto contra dsp_oracle.py::fir_symmetric):
--   * x, coeficientes en Q1.15. Acumulador Q2.30 en 40 bits (holgura).
--   * Reduccion final: (acc + 0x4000) >> 15, round-half-up, satura a int16.
--   * Estado inicial: linea de retardo a cero (reset).
--   * Solo se almacenan half = ceil(L/2) coeficientes.
--
-- Interfaz por muestra: se empuja x con 'push', y[n] sale con 'valid' tras
-- el barrido de MAC. LEN y coeficientes se cargan antes (puertos dedicados
-- en esta capa; en Layer 2 vienen del banco MMIO).
--
-- Estilo (leccion Vivado #2): sin lookups indexados en funciones. La linea
-- de retardo y la RAM de coeficientes son arrays con indice registrado.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir_dp is
  generic (
    MAXTAPS : integer := 64
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    -- carga de configuracion
    cfg_len  : in  std_logic_vector(6 downto 0);   -- LEN 1..64
    coef_we  : in  std_logic;                       -- escribe un coeficiente
    coef_idx : in  std_logic_vector(5 downto 0);    -- 0..31
    coef_dat : in  std_logic_vector(15 downto 0);   -- Q1.15
    -- flujo de muestras
    push     : in  std_logic;                        -- empuja x_in (1 ciclo)
    x_in     : in  std_logic_vector(15 downto 0);    -- Q1.15
    y_out    : out std_logic_vector(15 downto 0);    -- Q1.15
    valid    : out std_logic;                        -- 1 ciclo con y[n] listo
    busy     : out std_logic
  );
end entity;

architecture rtl of fir_dp is

  constant HALFMAX : integer := MAXTAPS/2;           -- 32

  type sample_line_t is array (0 to MAXTAPS-1) of signed(15 downto 0);
  type coef_mem_t    is array (0 to HALFMAX-1)  of signed(15 downto 0);

  signal dline : sample_line_t := (others => (others => '0'));
  signal cmem  : coef_mem_t    := (others => (others => '0'));

  signal len_r  : integer range 1 to MAXTAPS := MAXTAPS;
  signal half_r : integer range 1 to HALFMAX := HALFMAX;

  type state_t is (S_IDLE, S_MAC, S_RED);
  signal state : state_t := S_IDLE;

  signal k    : integer range 0 to 127 := 0;
  signal acc  : signed(39 downto 0) := (others => '0');

  -- registros de lectura de la linea/coefs (indice registrado)
  signal xa_r, xb_r, c_r : signed(15 downto 0) := (others => '0');
  signal center_r        : boolean := false;

  function sat16(v : signed) return std_logic_vector is
  begin
    if v > to_signed(32767, v'length) then
      return std_logic_vector(to_signed(32767, 16));
    elsif v < to_signed(-32768, v'length) then
      return std_logic_vector(to_signed(-32768, 16));
    else
      return std_logic_vector(resize(v, 16));
    end if;
  end function;

begin

  process(clk)
    variable pre  : signed(16 downto 0);   -- x[n-k]+x[n-(L-1-k)] (17b)
    variable prod : signed(33 downto 0);   -- c*pre : 16b * 17b -> 33b
    variable red  : signed(39 downto 0);
    variable ja, jb : integer range 0 to 127;
  begin
    if rising_edge(clk) then
      valid <= '0';
      if rst = '1' then
        state  <= S_IDLE;
        busy   <= '0';
        k      <= 0;
        acc    <= (others => '0');
        len_r  <= MAXTAPS;
        half_r <= HALFMAX;
        dline  <= (others => (others => '0'));
      else
        -- carga de coeficientes (independiente del estado)
        if coef_we = '1' then
          cmem(to_integer(unsigned(coef_idx))) <= signed(coef_dat);
        end if;

        case state is

          when S_IDLE =>
            busy <= '0';
            if push = '1' then
              -- desplazar linea de retardo e insertar x_in en [0]
              for i in MAXTAPS-1 downto 1 loop
                dline(i) <= dline(i-1);
              end loop;
              dline(0) <= signed(x_in);
              -- congelar LEN de esta muestra
              len_r  <= to_integer(unsigned(cfg_len));
              half_r <= (to_integer(unsigned(cfg_len)) + 1) / 2;
              acc    <= (others => '0');
              k      <= 0;
              busy   <= '1';
              state  <= S_MAC;
            end if;

          when S_MAC =>
            if k < half_r then
              ja := k;
              jb := len_r - 1 - k;
              if ja = jb then
                pre := resize(dline(ja), 17);            -- tap central (L impar)
              else
                pre := resize(dline(ja), 17) + resize(dline(jb), 17);
              end if;
              prod := resize(cmem(k mod HALFMAX) * pre, 34);  -- Q1.15*Q1.15 -> Q2.30
              acc  <= acc + resize(prod, 40);
              k    <= k + 1;
            else
              state <= S_RED;
            end if;

          when S_RED =>
            red := acc + to_signed(16384, 40);         -- round-half-up
            red := shift_right(red, 15);
            y_out <= sat16(red);
            valid <= '1';
            busy  <= '0';
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture;
