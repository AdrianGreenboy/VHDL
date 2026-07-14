-- tb_tsn_fifo.vhd - Capa 1a: tsn_fifo RTL vs modelo de cola independiente
-- Escritor y lector concurrentes; el modelo (protected type) solo aprende
-- bytes CONSOLIDADOS. LFSR determinista de 16 bits => secuencia reproducible.
-- Lector por chunks con re-lectura (rd_rewind) y liberacion (rd_commit).
-- LECCION (carrera de TB): full leido al reanudar tras el flanco es el valor
-- PRE-flanco; el escritor espera 1 ns para muestrear sobre la misma base que
-- decidira el RTL. LECCION (hash): la recurrencia (h rol 5) xor h xor b es
-- nilpotente (T^32=0) y solo recuerda 32 bytes; se usa djb2-xor.
-- Criterio de pass: 0 discrepancias + hash + timestamp final bit-identicos.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_tsn_fifo is
end entity;

architecture sim of tb_tsn_fifo is
  constant LOG2  : natural := 8;      -- 256 B en TB: fuerza overflows reales
  constant DEPTH : natural := 2**LOG2;
  constant NFRM  : natural := 400;

  type q_t is protected
    procedure push(b : integer);
    procedure push_commit;
    procedure push_rewind;
    impure function pop return integer;
    impure function count return integer;
    impure function get_abs(i : integer) return integer;
    impure function mark_pos return integer;
  end protected;

  type q_t is protected body
    type arr_t is array (0 to 262143) of integer;
    variable mem  : arr_t;
    variable head, tail, mark : integer := 0;  -- mark = frontera consolidada
    procedure push(b : integer) is
    begin mem(tail mod 262144) := b; tail := tail + 1; end;
    procedure push_commit is
    begin mark := tail; end;
    procedure push_rewind is
    begin tail := mark; end;
    impure function pop return integer is
      variable b : integer;
    begin
      assert head < mark report "modelo: pop sin datos consolidados" severity failure;
      b := mem(head mod 262144); head := head + 1; return b;
    end;
    impure function count return integer is
    begin return mark - head; end;
    impure function get_abs(i : integer) return integer is
    begin
      assert i < mark report "modelo: acceso mas alla de lo consolidado" severity failure;
      return mem(i mod 262144);
    end;
    impure function mark_pos return integer is
    begin return mark; end;
  end protected body;

  shared variable model : q_t;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal wr_en, commit, rewind, full, rd_en, rd_valid : std_logic := '0';
  signal rd_commit, rd_rewind : std_logic := '0';
  signal wr_data, rd_data : std_logic_vector(7 downto 0) := (others => '0');
  signal spec_count, comm_count : unsigned(LOG2 downto 0);
  signal done_wr : boolean := false;

  -- LFSR-16 x^16+x^14+x^13+x^11 compartido conceptualmente: cada proceso
  -- tiene el suyo con semilla distinta (independencia escritor/lector)
  function lfsr_next(s : unsigned(15 downto 0)) return unsigned is
  begin
    return s(14 downto 0) & (s(15) xor s(13) xor s(12) xor s(10));
  end;
begin
  clk <= not clk after 5 ns;

  dut : entity work.tsn_fifo
    generic map (LOG2_DEPTH => LOG2)
    port map (clk => clk, rst => rst, wr_en => wr_en, wr_data => wr_data,
              commit => commit, rewind => rewind, full => full,
              rd_en => rd_en, rd_data => rd_data, rd_valid => rd_valid,
              rd_commit => rd_commit, rd_rewind => rd_rewind,
              spec_count => spec_count, comm_count => comm_count);

  p_writer : process
    variable s      : unsigned(15 downto 0) := x"ACE1";
    variable flen   : integer;
    variable doomed : boolean;
    variable ncommit, nrewind, novf : integer := 0;
  begin
    wait for 30 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);
    for f in 1 to NFRM loop
      s := lfsr_next(s);
      flen := 1 + to_integer(s mod 300);   -- 1..300: algunos > DEPTH => doomed
      doomed := false;
      for b in 1 to flen loop
        s := lfsr_next(s);
        -- CARRERA DE TB (leccion): full leido al reanudar tras el flanco es el
        -- valor PRE-flanco. Esperar 1 ns asienta los deltas: full muestreado
        -- aqui es exactamente la base de decision del RTL en el flanco proximo
        wait for 1 ns;
        if full = '1' then
          doomed := true;                  -- byte perdido: trama condenada
          wr_en  <= '0';
        else
          wr_en   <= '1';
          wr_data <= std_logic_vector(s(7 downto 0));
          model.push(to_integer(s(7 downto 0)));  -- provisional en el modelo
        end if;
        wait until rising_edge(clk);
        wr_en <= '0';
      end loop;
      s := lfsr_next(s);
      -- politica: doomed => rewind obligado (wrapper); si no, 75% commit
      if doomed or s(1 downto 0) = "11" then
        rewind <= '1'; model.push_rewind;
        if doomed then novf := novf + 1; else nrewind := nrewind + 1; end if;
      else
        commit <= '1'; model.push_commit;
        ncommit := ncommit + 1;
      end if;
      wait until rising_edge(clk);
      commit <= '0'; rewind <= '0';
      wait until rising_edge(clk);
    end loop;
    report "escritor: commits=" & integer'image(ncommit) &
           " rewinds=" & integer'image(nrewind) &
           " condenadas_ovf=" & integer'image(novf);
    assert novf > 0
      report "TB debil: ningun overflow ejercitado, subir NFRM o flen" severity failure;
    assert nrewind > 0
      report "TB debil: ningun rewind voluntario ejercitado" severity failure;
    done_wr <= true;
    wait;
  end process;

  p_reader : process
    variable s      : unsigned(15 downto 0) := x"BEEF";
    variable base   : integer := 0;   -- posicion absoluta liberada (rd_commit)
    variable offset : integer := 0;   -- consumidos desde la ultima liberacion
    variable kchunk : integer;
    variable pass_n : integer;        -- 1a lectura o re-lectura tras rewind
    variable exp    : integer;
    variable nread, nrew, ncom : integer := 0;
    variable hash   : unsigned(31 downto 0) := (others => '0');
    variable fin    : boolean := false;
  begin
    wait until rst = '0';
    while not fin loop
      s := lfsr_next(s);
      kchunk := 1 + to_integer(s mod 40);
      pass_n := 1;
      offset := 0;
      -- leer el chunk (con stalls); puede re-leerse una vez tras rd_rewind
      loop
        s := lfsr_next(s);
        if s(1 downto 0) /= "00" and offset < kchunk then
          rd_en <= '1';
        else
          rd_en <= '0';
        end if;
        wait until rising_edge(clk);
        if rd_en = '1' and rd_valid = '1' then
          exp := model.get_abs(base + offset);
          assert to_integer(unsigned(rd_data)) = exp
            report "DISCREPANCIA abs " & integer'image(base + offset) &
                   " pasada " & integer'image(pass_n) &
                   ": rtl=" & integer'image(to_integer(unsigned(rd_data))) &
                   " modelo=" & integer'image(exp) severity failure;
          if pass_n = 1 then
            hash  := resize(hash * 33, 32) xor to_unsigned(exp, 32);
            nread := nread + 1;
          end if;
          offset := offset + 1;
        end if;
        -- fin de datos: escritor terminado y todo consumido
        if done_wr and base + offset = model.mark_pos and
           rd_valid = '0' and comm_count = 0 then
          fin := true; exit;
        end if;
        exit when offset = kchunk;
      end loop;
      rd_en <= '0';
      if offset > 0 then
        s := lfsr_next(s);
        if pass_n = 1 and s(2 downto 0) = "101" and not fin then
          rd_rewind <= '1'; nrew := nrew + 1;
          wait until rising_edge(clk);
          rd_rewind <= '0';
          -- re-leer el mismo chunk verificando identidad byte a byte
          pass_n := 2; offset := 0;
          loop
            s := lfsr_next(s);
            if s(1 downto 0) /= "00" and offset < kchunk then
              rd_en <= '1';
            else
              rd_en <= '0';
            end if;
            wait until rising_edge(clk);
            if rd_en = '1' and rd_valid = '1' then
              exp := model.get_abs(base + offset);
              assert to_integer(unsigned(rd_data)) = exp
                report "DISCREPANCIA re-lectura abs " & integer'image(base + offset)
                severity failure;
              offset := offset + 1;
            end if;
            exit when offset = kchunk;
          end loop;
          rd_en <= '0';
        end if;
        rd_commit <= '1'; ncom := ncom + 1;
        wait until rising_edge(clk);
        rd_commit <= '0';
        base := base + offset;
        wait until rising_edge(clk);
      end if;
    end loop;
    assert base = model.mark_pos
      report "liberado " & integer'image(base) & " /= consolidado " &
             integer'image(model.mark_pos) severity failure;
    assert nrew > 0
      report "TB debil: ninguna re-lectura ejercitada" severity failure;
    report "lector: bytes=" & integer'image(nread) &
           " rewinds_rd=" & integer'image(nrew) &
           " commits_rd=" & integer'image(ncom) &
           " hash=" & integer'image(to_integer(hash(30 downto 0)));
    report "TB_TSN_FIFO PASS" severity note;
    std.env.finish;
  end process;
end architecture;
