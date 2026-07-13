-------------------------------------------------------------------------------
-- cordic_dp.vhd  --  Datapath CORDIC iterativo (familia DSP IP, RV32IM SoC)
--
-- Layer 1a: datapath puro, sin MMIO. 16 iteraciones, hardware compartido.
-- Modos: rotacion (angulo -> cos,sin) y vectoring (x,y -> mag,fase).
--
-- Contrato numerico (congelado, bit-exacto contra dsp_oracle.py):
--   * Q1.15 para x,y (muestras) ; Q2.14 para angulo (+-pi -> +-2^15).
--   * 1/K = 0x4DBA (Q1.15) precargado en rotacion / multiplicado al final en vec.
--   * Tabla atan[i] en Q2.14 (mismos enteros que el oraculo).
--   * Pre-rotacion de cuadrante: fuera de [-pi/2,pi/2] se refleja y se corrige.
--   * 16 iteraciones exactas.
--
-- Restriccion de estilo (leccion Vivado 2025.2.1 #2): la tabla atan es una ROM
-- SINCRONA CANONICA (array constante, direccion registrada), NUNCA un lookup
-- indexado dentro de una funcion. GHDL simulandolo bien no garantiza sintesis.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic_dp is
  generic (
    ITERS : integer := 16
  );
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;                       -- sincrono, activo alto
    start  : in  std_logic;                       -- pulso de 1 ciclo
    mode   : in  std_logic;                        -- '0'=rotacion '1'=vectoring
    x_in   : in  std_logic_vector(15 downto 0);    -- Q1.15 (vec) / no usado (rot)
    y_in   : in  std_logic_vector(15 downto 0);    -- Q1.15 (vec) / no usado (rot)
    z_in   : in  std_logic_vector(15 downto 0);    -- Q2.14 angulo (rot)
    x_out  : out std_logic_vector(15 downto 0);    -- cos (rot) / mag (vec)
    y_out  : out std_logic_vector(15 downto 0);    -- sin (rot) / (interno)
    z_out  : out std_logic_vector(15 downto 0);    -- (interno) / fase (vec)
    busy   : out std_logic;
    done   : out std_logic                         -- 1 ciclo al terminar
  );
end entity;

architecture rtl of cordic_dp is

  -- 1/K en Q1.15 (16 iteraciones): 0x4DBA
  constant INVK : signed(15 downto 0) := x"4DBA";

  -- +pi/2 en el mapeo de angulo (+-pi -> +-2^15) = 16384
  constant HALF_PI : signed(17 downto 0) := to_signed(16384, 18);
  constant PI_FULL : signed(17 downto 0) := to_signed(32768, 18);

  -- ROM atan(2^-i) en Q2.14, 16 entradas. Mismos enteros que el oraculo.
  type atan_rom_t is array (0 to 15) of signed(15 downto 0);
  constant ATAN_ROM : atan_rom_t := (
    to_signed( 8192, 16), to_signed( 4836, 16), to_signed( 2555, 16),
    to_signed( 1297, 16), to_signed(  651, 16), to_signed(  326, 16),
    to_signed(  163, 16), to_signed(   81, 16), to_signed(   41, 16),
    to_signed(   20, 16), to_signed(   10, 16), to_signed(    5, 16),
    to_signed(    3, 16), to_signed(    1, 16), to_signed(    1, 16),
    to_signed(    0, 16)
  );

  type state_t is (S_IDLE, S_RUN, S_COMP, S_DONE);
  signal state : state_t := S_IDLE;

  -- registros de trabajo: 18 bits con guarda de signo para evitar overflow
  signal x_r, y_r, z_r : signed(17 downto 0) := (others => '0');
  signal iter          : integer range 0 to 15 := 0;
  signal mode_r        : std_logic := '0';
  signal neg_r         : std_logic := '0';         -- correccion de +-pi (rot)
  signal addpi_r       : signed(17 downto 0) := (others => '0'); -- correccion fase (vec)

  -- indice de la ROM atan, registrado; lectura combinacional del array
  -- constante (patron canonico sintetizable: la direccion es un registro,
  -- no hay lookup indexado dentro de una funcion -> leccion Vivado #2 OK).
  signal atan_q : signed(15 downto 0);

  -- saturacion a int16
  function sat16(v : signed) return std_logic_vector is
    variable r : signed(v'range) := v;
  begin
    if r > to_signed(32767, v'length) then
      return std_logic_vector(to_signed(32767, 16));
    elsif r < to_signed(-32768, v'length) then
      return std_logic_vector(to_signed(-32768, 16));
    else
      return std_logic_vector(resize(r, 16));
    end if;
  end function;

begin

  -- ROM: direccion registrada (iter), lectura combinacional. Sin latencia,
  -- asi atan_q en S_RUN(iter) corresponde a ATAN_ROM(iter) del mismo ciclo.
  atan_q <= ATAN_ROM(iter);

  process(clk)
    variable dx, dy : signed(17 downto 0);
    variable xin_s, yin_s, zin_s : signed(17 downto 0);
    variable magp : signed(35 downto 0);
  begin
    if rising_edge(clk) then
      done <= '0';
      if rst = '1' then
        state  <= S_IDLE;
        busy   <= '0';
        iter   <= 0;
        x_r    <= (others => '0');
        y_r    <= (others => '0');
        z_r    <= (others => '0');
        neg_r  <= '0';
        addpi_r<= (others => '0');
      else
        case state is

          when S_IDLE =>
            busy <= '0';
            if start = '1' then
              busy   <= '1';
              iter   <= 0;
              mode_r <= mode;
              neg_r  <= '0';
              addpi_r<= (others => '0');
              zin_s := resize(signed(z_in), 18);
              xin_s := resize(signed(x_in), 18);
              yin_s := resize(signed(y_in), 18);

              if mode = '0' then
                -- ROTACION: x0=1/K, y0=0, z0=angulo con pre-rotacion
                if zin_s > HALF_PI then
                  z_r   <= zin_s - PI_FULL;   -- -pi
                  neg_r <= '1';
                elsif zin_s < -HALF_PI then
                  z_r   <= zin_s + PI_FULL;   -- +pi
                  neg_r <= '1';
                else
                  z_r   <= zin_s;
                end if;
                x_r <= resize(INVK, 18);
                y_r <= (others => '0');
              else
                -- VECTORING: x0,y0=entrada con pre-rotacion (x<0 -> reflejar)
                z_r <= (others => '0');
                if xin_s < 0 then
                  x_r <= -xin_s;
                  y_r <= -yin_s;
                  if yin_s >= 0 then
                    addpi_r <= PI_FULL;        -- +pi (cuadrante II)
                  else
                    addpi_r <= -PI_FULL;       -- -pi (cuadrante III)
                  end if;
                else
                  x_r <= xin_s;
                  y_r <= yin_s;
                end if;
              end if;
              state <= S_RUN;
            end if;

          when S_RUN =>
            dx := shift_right(x_r, iter);
            dy := shift_right(y_r, iter);
            if mode_r = '0' then
              -- rotacion: direccion por signo de z
              if z_r >= 0 then
                x_r <= x_r - dy;
                y_r <= y_r + dx;
                z_r <= z_r - resize(atan_q, 18);
              else
                x_r <= x_r + dy;
                y_r <= y_r - dx;
                z_r <= z_r + resize(atan_q, 18);
              end if;
            else
              -- vectoring: direccion por signo de y (llevar y->0)
              if y_r < 0 then
                x_r <= x_r - dy;
                y_r <= y_r + dx;
                z_r <= z_r - resize(atan_q, 18);
              else
                x_r <= x_r + dy;
                y_r <= y_r - dx;
                z_r <= z_r + resize(atan_q, 18);
              end if;
            end if;

            if iter = ITERS - 1 then
              state <= S_COMP;
            else
              iter <= iter + 1;
            end if;

          when S_COMP =>
            -- correcciones finales de cuadrante
            if mode_r = '0' then
              if neg_r = '1' then
                x_r <= -x_r;
                y_r <= -y_r;
              end if;
            else
              -- vectoring: magnitud *= 1/K, fase += addpi con normalizacion
              magp := x_r * resize(INVK, 18);           -- signed18*signed18 -> 36b
              magp := (magp + to_signed(16384, 36)) / 32768; -- round-half-up >>15
              x_r  <= resize(magp, 18);
              z_r  <= z_r + addpi_r;
            end if;
            state <= S_DONE;

          when S_DONE =>
            -- normalizacion de fase a [-pi,pi] (solo vec) tras sumar addpi
            if mode_r = '1' then
              if z_r > to_signed(32767, 18) then
                z_r <= z_r - to_signed(65536, 18);
              elsif z_r < to_signed(-32768, 18) then
                z_r <= z_r + to_signed(65536, 18);
              end if;
            end if;
            busy <= '0';
            done <= '1';
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  x_out <= sat16(x_r);
  y_out <= sat16(y_r);
  z_out <= sat16(z_r);

end architecture;
