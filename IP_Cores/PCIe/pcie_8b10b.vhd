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

  type dec_entry_t is record
    vn, vp : std_logic;      -- valido entrando con RD- / RD+
    isk    : std_logic;
    data   : byte_t;
    rdn    : std_logic;      -- RD resultante si se entro con RD-
    rdp    : std_logic;      -- RD resultante si se entro con RD+
  end record;
  type lut_t is array (0 to 1023) of dec_entry_t;

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
      l(i) := ('0', '0', '0', x"00", '0', '0');
    end loop;
    for i in 0 to 255 loop
      b := std_logic_vector(to_unsigned(i, 8));
      for rdi in 0 to 1 loop
        r := f_enc(b, '0', std_logic'val(rdi + 2)); -- '0'/'1'
        idx := to_integer(unsigned(r.code));
        l(idx).data := b;
        l(idx).isk  := '0';
        if rdi = 0 then l(idx).vn := '1'; l(idx).rdn := r.rd;
        else            l(idx).vp := '1'; l(idx).rdp := r.rd; end if;
      end loop;
    end loop;
    for ki in KV'range loop
      for rdi in 0 to 1 loop
        r := f_enc(KV(ki), '1', std_logic'val(rdi + 2));
        idx := to_integer(unsigned(r.code));
        l(idx).data := KV(ki);
        l(idx).isk  := '1';
        if rdi = 0 then l(idx).vn := '1'; l(idx).rdn := r.rd;
        else            l(idx).vp := '1'; l(idx).rdp := r.rd; end if;
      end loop;
    end loop;
    return l;
  end function;

  constant LUT : lut_t := f_build_lut;

  signal rd_q : std_logic := '0';

begin

  process(clk)
    variable e : dec_entry_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rd_q     <= '0';
        dout     <= (others => '0');
        kout     <= '0';
        code_err <= '0';
        disp_err <= '0';
      elsif en = '1' then
        e := LUT(to_integer(unsigned(din)));
        code_err <= '0';
        disp_err <= '0';
        dout     <= e.data;
        kout     <= e.isk;
        if e.vn = '0' and e.vp = '0' then
          code_err <= '1';
          kout     <= '0';
        elsif rd_q = '0' and e.vn = '1' then
          rd_q <= e.rdn;
        elsif rd_q = '1' and e.vp = '1' then
          rd_q <= e.rdp;
        else
          -- Valido solo para la otra RD: error de disparidad + resync
          disp_err <= '1';
          if e.vn = '1' then rd_q <= e.rdn; else rd_q <= e.rdp; end if;
        end if;
      end if;
    end if;
  end process;
  rd_mon <= rd_q;

end architecture;
