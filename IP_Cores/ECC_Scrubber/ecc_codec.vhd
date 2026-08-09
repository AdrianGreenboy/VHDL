-- ecc_codec.vhd - Codec SECDED (39,32) combinacional. Core 20 HERCOSSNUX.
-- Espejo bit-identico del oraculo Python (ecc_oracle.py).
--   encode: data(31..0) -> code_out(38..0)
--   decode: code_in(38..0) -> data_out, syndrome(6..0), corrected, double_error
-- Reglas GHDL: mensajes assert en espanol ASCII; sin nombres externos.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ecc_pkg.all;

entity ecc_codec is
  port (
    -- camino de codificacion
    enc_data : in  data_t;
    enc_code : out ecc_t;
    -- camino de decodificacion
    dec_code : in  ecc_t;
    dec_data : out data_t;
    dec_syn  : out std_logic_vector(6 downto 0);
    dec_cor  : out std_logic;
    dec_ded  : out std_logic
  );
end entity;

architecture rtl of ecc_codec is

  -- coloca los 32 bits de dato en un vector de posiciones Hamming 1..38 (indice 1..38)
  function place_data(d : data_t) return std_logic_vector is
    variable pos : std_logic_vector(POS_N downto 1) := (others => '0');
  begin
    for i in 0 to DATA_W-1 loop
      pos(DATA_POS(i)) := d(i);
    end loop;
    return pos;
  end function;

  -- paridad Hamming para el bit de paridad en posicion p (potencia de 2):
  -- XOR de toda posicion j (j/=p) cuyo indice tenga el bit p en 1.
  function hamming_parity(pos : std_logic_vector; p : natural) return std_logic is
    variable acc : std_logic := '0';
  begin
    for j in 1 to POS_N loop
      if j /= p then
        -- (j and p) /= 0  <=>  el bit p esta presente en j
        if (j / p) mod 2 = 1 then
          acc := acc xor pos(j);
        end if;
      end if;
    end loop;
    return acc;
  end function;

  -- extrae los 32 bits de dato de un vector de posiciones
  function extract_data(pos : std_logic_vector) return data_t is
    variable d : data_t := (others => '0');
  begin
    for i in 0 to DATA_W-1 loop
      d(i) := pos(DATA_POS(i));
    end loop;
    return d;
  end function;

begin

  ----------------------------------------------------------------- ENCODE
  process(enc_data)
    variable pos     : std_logic_vector(POS_N downto 1);
    variable overall : std_logic;
    variable code    : ecc_t := (others => '0');
  begin
    pos := place_data(enc_data);
    -- calcular paridades Hamming
    for k in 0 to PARITY_POS'length-1 loop
      pos(PARITY_POS(k)) := hamming_parity(pos, PARITY_POS(k));
    end loop;
    -- empaquetar pos 1..38 -> code(0..37)
    for j in 1 to POS_N loop
      code(j-1) := pos(j);
    end loop;
    -- paridad global sobre pos 1..38 -> code(38)
    overall := '0';
    for j in 1 to POS_N loop
      overall := overall xor pos(j);
    end loop;
    code(38) := overall;
    enc_code <= code;
  end process;

  ----------------------------------------------------------------- DECODE
  process(dec_code)
    variable pos          : std_logic_vector(POS_N downto 1);
    variable overall_in   : std_logic;
    variable syn          : integer range 0 to 63;
    variable syn_vec      : std_logic_vector(6 downto 0);
    variable calc_overall : std_logic;
    variable mism         : std_logic;
    variable cor          : std_logic;
    variable ded          : std_logic;
  begin
    -- desempaquetar
    for j in 1 to POS_N loop
      pos(j) := dec_code(j-1);
    end loop;
    overall_in := dec_code(38);

    -- sindrome: por cada bit de paridad, comparar recalculada vs almacenada
    syn := 0;
    for k in 0 to PARITY_POS'length-1 loop
      if (hamming_parity(pos, PARITY_POS(k)) xor pos(PARITY_POS(k))) = '1' then
        syn := syn + PARITY_POS(k);
      end if;
    end loop;

    -- paridad global recalculada
    calc_overall := '0';
    for j in 1 to POS_N loop
      calc_overall := calc_overall xor pos(j);
    end loop;
    mism := calc_overall xor overall_in;

    cor := '0';
    ded := '0';

    if syn = 0 and mism = '0' then
      null;  -- sin error
    elsif mism = '1' then
      -- numero impar de flips -> 1 bit corregible
      if syn /= 0 and syn <= POS_N then
        pos(syn) := not pos(syn);
      end if;
      -- si syn = 0, el error esta en el propio bit overall; dato intacto
      cor := '1';
    else
      -- mism = 0 y syn /= 0 -> 2 bits detectados
      ded := '1';
    end if;

    -- salidas
    syn_vec := std_logic_vector(to_unsigned(syn, 7));
    dec_syn  <= syn_vec;
    dec_data <= extract_data(pos);
    dec_cor  <= cor;
    dec_ded  <= ded;
  end process;

end architecture;
