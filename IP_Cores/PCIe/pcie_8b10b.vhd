-- ============================================================================
-- pcie_8b10b.vhd -- PCIE IP v1
-- Encoder y decoder 8b/10b sincronos (latencia 1 ciclo).
-- El decoder construye en elaboracion una LUT de 1024 entradas a partir de
-- f_enc (imagen completa del codificador para ambas disparidades), valida el
-- simbolo contra la RD corriente, y se resincroniza a la RD implicada por el
-- codigo cuando detecta violacion de disparidad (disp_err).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;

entity pcie_8b10b_enc is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;                     -- sincrono, activo alto
    en     : in  std_logic;                     -- clock enable de simbolo
    din    : in  byte_t;
    kin    : in  std_logic;
    dout   : out sym10_t;
    rd_mon : out std_logic;
    err    : out std_logic                      -- K ilegal solicitado
  );
end entity;

architecture rtl of pcie_8b10b_enc is
  signal rd_q : std_logic := '0';
begin
  process(clk)
    variable r : enc_res_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rd_q <= '0';
        dout <= (others => '0');
        err  <= '0';
      elsif en = '1' then
        r := f_enc(din, kin, rd_q);
        dout <= r.code;
        err  <= r.err;
        if r.err = '0' then
          rd_q <= r.rd;
        end if;
      end if;
    end if;
  end process;
  rd_mon <= rd_q;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;

entity pcie_8b10b_dec is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    en       : in  std_logic;
    din      : in  sym10_t;
    dout     : out byte_t;
    kout     : out std_logic;
    code_err : out std_logic;                   -- simbolo fuera del codigo
    disp_err : out std_logic;                   -- valido pero RD equivocada
    rd_mon   : out std_logic
  );
end entity;

architecture rtl of pcie_8b10b_dec is

  -- LUT PLANA (BRAM-friendly): cada codigo de 10 bits mapea a un vector de 13
  -- bits empaquetado, en vez de un record. Esto permite que Vivado la infiera
  -- como ROM en block RAM (records con lectura combinacional entrelazada NO se
  -- empacan y saturan las LUTs). Layout del vector:
  --   bit 12 = vn   (valido entrando con RD-)
  --   bit 11 = vp   (valido entrando con RD+)
  --   bit 10 = isk  (simbolo K)
  --   bit  9 = rdn  (RD resultante si se entro con RD-)
  --   bit  8 = rdp  (RD resultante si se entro con RD+)
  --   bits 7..0 = data
  type lut_t is array (0 to 1023) of std_logic_vector(12 downto 0);

  -- Imagen completa del encoder: 256 D + 12 K, ambas RD de entrada.
  function f_build_lut return lut_t is
    variable l   : lut_t;
    variable r   : enc_res_t;
    variable idx : natural;
    variable b   : byte_t;
    type kv_t is array (0 to 11) of byte_t;
    constant KV : kv_t := (K_COM, K_STP, K_SDP, K_END, K_EDB, K_PAD,
                           K_SKP, K_FTS, K_IDL, x"9C", x"DC", x"FC");
                           -- K28.4, K28.6, K28.7 completan el set legal
  begin
    for i in 0 to 1023 loop
      l(i) := (others => '0');
    end loop;
    for i in 0 to 255 loop
      b := std_logic_vector(to_unsigned(i, 8));
      for rdi in 0 to 1 loop
        r := f_enc(b, '0', std_logic'val(rdi + 2)); -- '0'/'1'
        idx := to_integer(unsigned(r.code));
        l(idx)(7 downto 0) := b;       -- data
        l(idx)(10)         := '0';     -- isk
        if rdi = 0 then
          l(idx)(12) := '1';           -- vn
          l(idx)(9)  := r.rd;          -- rdn
        else
          l(idx)(11) := '1';           -- vp
          l(idx)(8)  := r.rd;          -- rdp
        end if;
      end loop;
    end loop;
    for ki in KV'range loop
      for rdi in 0 to 1 loop
        r := f_enc(KV(ki), '1', std_logic'val(rdi + 2));
        idx := to_integer(unsigned(r.code));
        l(idx)(7 downto 0) := KV(ki);  -- data
        l(idx)(10)         := '1';     -- isk
        if rdi = 0 then
          l(idx)(12) := '1';           -- vn
          l(idx)(9)  := r.rd;          -- rdn
        else
          l(idx)(11) := '1';           -- vp
          l(idx)(8)  := r.rd;          -- rdp
        end if;
      end loop;
    end loop;
    return l;
  end function;

  constant LUT : lut_t := f_build_lut;
  attribute rom_style : string;
  attribute rom_style of LUT : constant is "block";

  signal rd_q : std_logic := '0';

begin

  process(clk)
    variable e   : std_logic_vector(12 downto 0);
    variable evn, evp, eisk, erdn, erdp : std_logic;
    variable edata : byte_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rd_q     <= '0';
        dout     <= (others => '0');
        kout     <= '0';
        code_err <= '0';
        disp_err <= '0';
      elsif en = '1' then
        e     := LUT(to_integer(unsigned(din)));
        evn   := e(12);
        evp   := e(11);
        eisk  := e(10);
        erdn  := e(9);
        erdp  := e(8);
        edata := e(7 downto 0);
        code_err <= '0';
        disp_err <= '0';
        dout     <= edata;
        kout     <= eisk;
        if evn = '0' and evp = '0' then
          code_err <= '1';
          kout     <= '0';
        elsif rd_q = '0' and evn = '1' then
          rd_q <= erdn;
        elsif rd_q = '1' and evp = '1' then
          rd_q <= erdp;
        else
          -- Valido solo para la otra RD: error de disparidad + resync
          disp_err <= '1';
          if evn = '1' then rd_q <= erdn; else rd_q <= erdp; end if;
        end if;
      end if;
    end if;
  end process;
  rd_mon <= rd_q;

end architecture;
