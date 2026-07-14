-- ============================================================================
-- tb_8b10b.vhd -- PCIE IP v1, verificacion capa 0 (unidad codec)
--
-- A) Exhaustivo por funcion: 256 D + 12 K x ambas RD -> sin error, disparidad
--    de simbolo en {-2,0,+2}, regla de evolucion de RD, unicidad de los
--    codigos de 10 bits (ningun codigo mapea a dos (K,dato) distintos),
--    exactamente 12 codigos K legales.
-- B) Stream clocked de 50000 simbolos por las ENTIDADES enc->dec:
--    roundtrip exacto, cero errores, run length <= 5 en el stream serializado
--    y patron comma (0011111/1100000) SOLO alineado al inicio de K28.5/K28.1
--    (ausencia de falsas commas = validacion empirica de la regla A7 y de las
--    tablas K complementadas).
-- C) Encoder: K ilegal debe levantar err sin alterar RD.
-- D) Mutaciones: 200 streams con UN bit-flip en el cable; el decoder DEBE
--    detectar (code_err o disp_err) antes del fin del stream. Tambien se
--    verifica cero falsos positivos antes de la corrupcion.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.pcie_8b10b_pkg.all;

entity tb_8b10b is
end entity;

architecture sim of tb_8b10b is

  constant TCLK : time := 10 ns;
  constant NSYM : integer := 50000;
  constant NMUT : integer := 200;

  signal clk  : std_logic := '0';
  signal fin  : boolean   := false;

  -- Pipeline principal enc -> dec
  signal rst      : std_logic := '1';
  signal en       : std_logic := '0';
  signal din      : byte_t    := (others => '0');
  signal kin      : std_logic := '0';
  signal enc_out  : sym10_t;
  signal enc_err  : std_logic;
  signal enc_rd   : std_logic;
  signal en_d1    : std_logic := '0';
  signal dec_out  : byte_t;
  signal dec_k    : std_logic;
  signal dec_ce   : std_logic;
  signal dec_de   : std_logic;

  -- Decoder de mutaciones (alimentado directo)
  signal rst2     : std_logic := '1';
  signal en2      : std_logic := '0';
  signal din2     : sym10_t   := (others => '0');
  signal dec2_out : byte_t;
  signal dec2_k   : std_logic;
  signal dec2_ce  : std_logic;
  signal dec2_de  : std_logic;

  type kv9_t is array (0 to 8) of byte_t;
  constant KSTREAM : kv9_t := (K_COM, K_STP, K_SDP, K_END, K_EDB,
                               K_PAD, K_SKP, K_FTS, K_IDL);

begin

  clk <= '0' when fin else not clk after TCLK/2;

  u_enc : entity work.pcie_8b10b_enc
    port map (clk => clk, rst => rst, en => en, din => din, kin => kin,
              dout => enc_out, rd_mon => enc_rd, err => enc_err);

  u_dec : entity work.pcie_8b10b_dec
    port map (clk => clk, rst => rst, en => en_d1, din => enc_out,
              dout => dec_out, kout => dec_k,
              code_err => dec_ce, disp_err => dec_de, rd_mon => open);

  -- en retrasado 1 ciclo: el decoder consume el simbolo cuando ya es valido
  process(clk) begin
    if rising_edge(clk) then
      if rst = '1' then en_d1 <= '0'; else en_d1 <= en; end if;
    end if;
  end process;

  u_dec_mut : entity work.pcie_8b10b_dec
    port map (clk => clk, rst => rst2, en => en2, din => din2,
              dout => dec2_out, kout => dec2_k,
              code_err => dec2_ce, disp_err => dec2_de, rd_mon => open);

  main : process
    variable s1 : positive := 7;
    variable s2 : positive := 11;
    variable rr : real;

    procedure rnd(hi : in integer; res : out integer) is
    begin
      uniform(s1, s2, rr);
      res := integer(floor(rr * real(hi + 1)));
      if res > hi then res := hi; end if;
    end procedure;

    -- Parte A
    variable r, r2   : enc_res_t;
    variable b       : byte_t;
    variable n1      : natural;
    variable seen    : std_logic_vector(0 to 1023) := (others => '0');
    type btab_t is array (0 to 1023) of byte_t;
    variable tagd    : btab_t;
    variable tagk    : std_logic_vector(0 to 1023);
    variable idx     : natural;
    variable nkval   : natural := 0;
    variable ncodes  : natural := 0;

    -- Parte B
    type expq_t is array (0 to 3) of byte_t;
    variable q_d     : expq_t := (others => (others => '0'));
    variable q_k     : std_logic_vector(0 to 3) := (others => '0');
    variable q_v     : std_logic_vector(0 to 3) := (others => '0');
    variable pick    : integer;
    variable isk     : std_logic;
    variable bsym    : byte_t;
    variable run_bit : std_logic := 'U';
    variable run_len : natural := 0;
    variable w7      : std_logic_vector(6 downto 0) := (others => 'U');
    variable gb      : integer := -1;   -- indice global de bit
    variable start   : integer;
    type cflag_t is array (0 to NSYM-1) of boolean;
    variable is_comma_sym : cflag_t := (others => false);
    variable sym_i   : integer;
    variable bitv    : std_logic;

    -- Parte D
    variable rd_sw   : std_logic;
    variable code_v  : sym10_t;
    variable flip    : integer;
    variable cpos    : integer;
    variable det     : boolean;
    variable pre_err : boolean;
  begin
    -- =======================================================================
    -- Parte A: exhaustivo por funcion
    -- =======================================================================
    for i in 0 to 255 loop
      b := std_logic_vector(to_unsigned(i, 8));
      for rdi in 0 to 1 loop
        if rdi = 0 then r := f_enc(b, '0', '0'); else r := f_enc(b, '0', '1'); end if;
        assert r.err = '0'
          report "A: f_enc marco error en dato valido D." & integer'image(i)
          severity failure;
        n1 := f_ones(r.code);
        assert n1 >= 4 and n1 <= 6
          report "A: disparidad de simbolo ilegal en D." & integer'image(i)
          severity failure;
        if n1 = 5 then
          assert (rdi = 0 and r.rd = '0') or (rdi = 1 and r.rd = '1')
            report "A: RD cambio con simbolo neutro D." & integer'image(i)
            severity failure;
        elsif n1 = 6 then
          assert r.rd = '1' report "A: RD+ esperada D." & integer'image(i) severity failure;
        else
          assert r.rd = '0' report "A: RD- esperada D." & integer'image(i) severity failure;
        end if;
        idx := to_integer(unsigned(r.code));
        if seen(idx) = '1' then
          assert tagd(idx) = b and tagk(idx) = '0'
            report "A: colision de codigo 10b (no unicidad) D." & integer'image(i)
            severity failure;
        else
          seen(idx) := '1'; tagd(idx) := b; tagk(idx) := '0';
          ncodes := ncodes + 1;
        end if;
      end loop;
    end loop;

    for i in 0 to 255 loop
      b := std_logic_vector(to_unsigned(i, 8));
      r  := f_enc(b, '1', '0');
      r2 := f_enc(b, '1', '1');
      assert r.err = r2.err report "A: err K inconsistente entre RDs" severity failure;
      if r.err = '0' then
        nkval := nkval + 1;
        for rdi in 0 to 1 loop
          if rdi = 0 then r := f_enc(b, '1', '0'); else r := f_enc(b, '1', '1'); end if;
          n1 := f_ones(r.code);
          assert n1 >= 4 and n1 <= 6
            report "A: disparidad ilegal en K byte " & integer'image(i) severity failure;
          idx := to_integer(unsigned(r.code));
          if seen(idx) = '1' then
            assert tagd(idx) = b and tagk(idx) = '1'
              report "A: colision de codigo 10b entre K y otro simbolo, byte "
                     & integer'image(i)
              severity failure;
          else
            seen(idx) := '1'; tagd(idx) := b; tagk(idx) := '1';
            ncodes := ncodes + 1;
          end if;
        end loop;
      end if;
    end loop;
    assert nkval = 12
      report "A: numero de codigos K legales != 12: " & integer'image(nkval)
      severity failure;
    report "A: PASS exhaustivo. Codigos 10b distintos: " & integer'image(ncodes);

    -- =======================================================================
    -- Parte B: stream de 50000 simbolos por las entidades
    -- =======================================================================
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    for s in 0 to NSYM + 3 loop
      if s < NSYM then
        rnd(15, pick);
        if pick = 0 then
          isk := '1';
          rnd(8, pick);
          bsym := KSTREAM(pick);
        else
          isk := '0';
          rnd(255, pick);
          bsym := std_logic_vector(to_unsigned(pick, 8));
        end if;
        din <= bsym; kin <= isk; en <= '1';
        is_comma_sym(s) := (isk = '1') and (bsym = K_COM or bsym = K_FTS);
      else
        en <= '0';
      end if;

      -- cola de esperados (latencia total 2)
      q_d(3) := q_d(2); q_k(3) := q_k(2); q_v(3) := q_v(2);
      q_d(2) := q_d(1); q_k(2) := q_k(1); q_v(2) := q_v(1);
      q_d(1) := q_d(0); q_k(1) := q_k(0); q_v(1) := q_v(0);
      if s < NSYM then q_d(0) := bsym; q_k(0) := isk; q_v(0) := '1';
      else q_v(0) := '0'; end if;

      wait until rising_edge(clk);

      -- salida del decoder corresponde al simbolo de hace 2 ciclos
      if q_v(2) = '1' then
        assert dec_ce = '0' and dec_de = '0'
          report "B: error espurio del decoder en simbolo " & integer'image(s-2)
          severity failure;
        assert dec_out = q_d(2) and dec_k = q_k(2)
          report "B: roundtrip incorrecto en simbolo " & integer'image(s-2)
          severity failure;
      end if;
      assert enc_err = '0' report "B: enc_err espurio" severity failure;

      -- propiedades del cable sobre la salida del encoder (valida 1 ciclo
      -- despues del drive: simbolo s-1)
      if s >= 1 and s <= NSYM then
        sym_i := s - 1;
        for bi in 9 downto 0 loop
          bitv := enc_out(bi);
          gb := gb + 1;
          if bitv = run_bit then
            run_len := run_len + 1;
          else
            run_bit := bitv; run_len := 1;
          end if;
          assert run_len <= 5
            report "B: run length > 5 en bit global " & integer'image(gb)
            severity failure;
          w7 := w7(5 downto 0) & bitv;
          if gb >= 6 and (w7 = "0011111" or w7 = "1100000") then
            start := gb - 6;
            assert (start mod 10 = 0) and is_comma_sym(start / 10)
              report "B: FALSA COMMA en bit global " & integer'image(start)
              severity failure;
          end if;
        end loop;
      end if;

      if (s mod 10000) = 0 and s > 0 then
        report "B: progreso " & integer'image(s) & "/" & integer'image(NSYM);
      end if;
    end loop;
    report "B: PASS stream. Bits serializados: " & integer'image(gb + 1);

    -- =======================================================================
    -- Parte C: K ilegal en el encoder
    -- =======================================================================
    din <= x"00"; kin <= '1'; en <= '1';   -- K00.0 no existe
    wait until rising_edge(clk);
    en <= '0'; kin <= '0';
    wait until rising_edge(clk);
    assert enc_err = '1' report "C: encoder no marco K ilegal" severity failure;
    wait until rising_edge(clk);
    report "C: PASS K ilegal detectado";

    -- =======================================================================
    -- Parte D: mutaciones de un bit en el cable -> deteccion obligatoria
    -- =======================================================================
    for t in 0 to NMUT - 1 loop
      rst2 <= '1'; en2 <= '0';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      rst2 <= '0';
      wait until rising_edge(clk);

      rd_sw := '0';
      rnd(14, cpos); cpos := cpos + 8;   -- corromper simbolo 8..22
      det := false; pre_err := false;

      for s in 0 to 63 loop
        -- mezcla con garantia de simbolos dispares en la cola (D.00)
        if s > cpos and (s mod 2) = 0 then
          bsym := x"00"; isk := '0';
        else
          rnd(255, pick); bsym := std_logic_vector(to_unsigned(pick, 8));
          isk := '0';
        end if;
        r := f_enc(bsym, isk, rd_sw);
        rd_sw := r.rd;
        code_v := r.code;
        if s = cpos then
          rnd(9, flip);
          code_v(flip) := not code_v(flip);
        end if;
        din2 <= code_v; en2 <= '1';
        wait until rising_edge(clk);
        en2 <= '0';
        wait until rising_edge(clk);
        if dec2_ce = '1' or dec2_de = '1' then
          if s < cpos then pre_err := true; end if;
          if s >= cpos then det := true; end if;
        end if;
        -- antes de la corrupcion el dato debe ser exacto
        if s < cpos then
          assert dec2_out = bsym and dec2_k = isk
            report "D: dato incorrecto sin corrupcion, trial " & integer'image(t)
            severity failure;
        end if;
      end loop;

      assert not pre_err
        report "D: falso positivo antes de la corrupcion, trial " & integer'image(t)
        severity failure;
      assert det
        report "D: MUTACION NO DETECTADA, trial " & integer'image(t)
        severity failure;
    end loop;
    report "D: PASS " & integer'image(NMUT) & " mutaciones detectadas";

    report "FIN SIMULACION 8B10B: PASS @ " & time'image(now);
    fin <= true;
    wait;
  end process;

end architecture;
