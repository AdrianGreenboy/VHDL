-- HERCOSSNUX NPU - requantize HXQ8, pipeline de 3 etapas.
--   E1: ReLU opcional sobre acc int32, registro de operandos
--   E2: producto int64 = acc * m, suma del redondeo 2^(SHIFT-1)
--   E3: shift aritmetico SHIFT y saturacion a int8
-- Latencia fija = 3 ciclos. valid_out sigue a valid_in con 3 de retraso.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.npu_pkg.all;

entity npu_requant is
  generic (
    G_ACC_W : natural := C_ACC_W;
    G_SHIFT : natural := C_SHIFT;
    G_MUT   : natural := 0
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    valid_in  : in  std_logic;
    relu_en   : in  std_logic;                        -- ReLU sobre el acumulador
    acc_in    : in  signed(G_ACC_W-1 downto 0);
    mult_in   : in  signed(C_MULT_W-1 downto 0);      -- multiplicador M (positivo)
    valid_out : out std_logic;
    data_out  : out signed(C_DATA_W-1 downto 0)
  );
end entity npu_requant;

architecture rtl of npu_requant is

  -- Etapa 1
  signal v1     : std_logic;
  signal acc1   : signed(G_ACC_W-1 downto 0);
  signal mult1  : signed(C_MULT_W-1 downto 0);
  -- Etapa 2
  signal v2     : std_logic;
  signal prod2  : signed(G_ACC_W+C_MULT_W-1 downto 0);
  -- Etapa 3
  signal v3     : std_logic;
  signal dout3  : signed(C_DATA_W-1 downto 0);

  constant C_SH : natural := G_SHIFT;
  -- Audit 2026-11: termino de redondeo 2**(C_SH-1) construido en el ancho
  -- del producto (2**(C_SH-1) como integer desbordaba con G_SHIFT > 31, y
  -- G_SHIFT = 0 daba 2**-1).
  function rnd_term (sh, w : natural) return signed is
    variable r : signed(w-1 downto 0) := (others => '0');
  begin
    if sh >= 1 and sh <= w - 1 then
      r(sh - 1) := '1';
    end if;
    return r;
  end function;
  constant C_RND : signed(G_ACC_W+C_MULT_W-1 downto 0) :=
    rnd_term(C_SH, G_ACC_W+C_MULT_W);

begin

  assert C_SH <= G_ACC_W + C_MULT_W - 2
    report "npu_requant: G_SHIFT demasiado grande para el producto" severity failure;

  -- ---------------- Etapa 1: ReLU y registro ----------------
  process(clk)
    variable a : signed(G_ACC_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        v1 <= '0'; acc1 <= (others => '0'); mult1 <= (others => '0');
      else
        v1 <= valid_in;
        a  := acc_in;
        if relu_en = '1' then
          if G_MUT = 3 then
            -- MUT 3: ReLU aplicada despues del requantize (aqui se omite)
            null;
          else
            if a < 0 then
              a := (others => '0');
            end if;
          end if;
        end if;
        acc1  <= a;
        mult1 <= mult_in;
      end if;
    end if;
  end process;

  -- ---------------- Etapa 2: producto de 64 bits y redondeo ----------------
  process(clk)
    variable p : signed(G_ACC_W+C_MULT_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        v2 <= '0'; prod2 <= (others => '0');
      else
        v2 <= v1;
        p  := acc1 * mult1;
        if G_MUT = 4 then
          -- MUT 4: truncamiento, sin termino de redondeo
          null;
        else
          p := p + C_RND;
        end if;
        prod2 <= p;
      end if;
    end if;
  end process;

  -- ---------------- Etapa 3: shift y saturacion ----------------
  process(clk)
    variable sh : signed(G_ACC_W+C_MULT_W-1 downto 0);
    variable n  : natural;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        v3 <= '0'; dout3 <= (others => '0');
      else
        v3 <= v2;
        if G_MUT = 5 then
          n := C_SH + 1;              -- MUT 5: shift desplazado en 1
        else
          n := C_SH;
        end if;
        sh := shift_right(prod2, n);

        if G_MUT = 6 then
          -- MUT 6: saturacion superior incorrecta (128 en vez de 127)
          if sh > 128 then
            dout3 <= to_signed(127, C_DATA_W);
          elsif sh < -128 then
            dout3 <= to_signed(-128, C_DATA_W);
          else
            dout3 <= resize(sh, C_DATA_W);
          end if;
        else
          if sh > 127 then
            dout3 <= to_signed(127, C_DATA_W);
          elsif sh < -128 then
            dout3 <= to_signed(-128, C_DATA_W);
          else
            dout3 <= resize(sh, C_DATA_W);
          end if;
        end if;
      end if;
    end if;
  end process;

  valid_out <= v3;
  data_out  <= dout3;

end architecture rtl;
