-- tb_tsn_ingress.vhd - Capa 1a: tsn_ingress vs modelo por invariantes
-- Sin duplicar punteros del RTL (anti modo comun): el checker exige
--   (1) cada trama entregada == una enviada, en orden estrictamente creciente
--   (2) descriptor (mac/len/tagged) coherente con la trama emparejada
--   (3) entregadas + drops_ovf == enviadas; drop_fcs == pulsos inyectados
-- Lector con stalls largos deterministas => overflows garantizados.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_tsn_ingress is
end entity;

architecture sim of tb_tsn_ingress is
  constant LOG2  : natural := 8;    -- 256 B: tramas de hasta 300 B fuerzan doom
  constant NFRM  : natural := 300;
  constant MAXB  : natural := 300;

  type store_t is protected
    procedure put(fidx, bidx, b : integer);
    procedure set_len(fidx, l : integer);
    impure function get(fidx, bidx : integer) return integer;
    impure function len(fidx : integer) return integer;
  end protected;
  type store_t is protected body
    type mem_t is array (0 to NFRM*MAXB-1) of integer;
    type len_t is array (0 to NFRM-1) of integer;
    variable mem  : mem_t;
    variable lens : len_t := (others => 0);
    procedure put(fidx, bidx, b : integer) is
    begin mem(fidx*MAXB + bidx) := b; end;
    procedure set_len(fidx, l : integer) is
    begin lens(fidx) := l; end;
    impure function get(fidx, bidx : integer) return integer is
    begin return mem(fidx*MAXB + bidx); end;
    impure function len(fidx : integer) return integer is
    begin return lens(fidx); end;
  end protected body;

  type cnt_t is protected
    procedure inc(which : integer);
    impure function get(which : integer) return integer;
  end protected;
  type cnt_t is protected body
    variable c : integer_vector(0 to 4) := (others => 0);
    procedure inc(which : integer) is
    begin c(which) := c(which) + 1; end;
    impure function get(which : integer) return integer is
    begin return c(which); end;
  end protected body;
  -- 0=cnt_rx 1=cnt_drop_ovf 2=cnt_drop_fcs 3=cnt_tagged 4=ev_inyectados

  shared variable store : store_t;
  shared variable cnts  : cnt_t;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_valid, rx_last, ev_crc, ev_runt : std_logic := '0';
  signal rd_en, rd_valid, desc_valid, desc_tagged, desc_pop : std_logic := '0';
  signal rd_commit, rd_rewind : std_logic := '0';
  signal rd_data : std_logic_vector(7 downto 0);
  signal desc_mac : std_logic_vector(47 downto 0);
  signal desc_len : unsigned(10 downto 0);
  signal cnt_rx, cnt_drop_ovf, cnt_drop_fcs, cnt_tagged : std_logic;
  signal done_wr : boolean := false;

  function lfsr_next(s : unsigned(15 downto 0)) return unsigned is
  begin
    return s(14 downto 0) & (s(15) xor s(13) xor s(12) xor s(10));
  end;
begin
  clk <= not clk after 5 ns;

  dut : entity work.tsn_ingress
    generic map (LOG2_DEPTH => LOG2)
    port map (clk => clk, rst => rst,
      rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
      ev_crc => ev_crc, ev_runt => ev_runt,
      rd_en => rd_en, rd_data => rd_data, rd_valid => rd_valid,
      rd_commit => rd_commit, rd_rewind => rd_rewind,
      desc_valid => desc_valid, desc_mac => desc_mac, desc_len => desc_len,
      desc_tagged => desc_tagged, desc_pop => desc_pop,
      cnt_rx => cnt_rx, cnt_drop_ovf => cnt_drop_ovf,
      cnt_drop_fcs => cnt_drop_fcs, cnt_tagged => cnt_tagged);

  p_writer : process
    variable s    : unsigned(15 downto 0) := x"1EE7";
    variable flen, gap : integer;
    variable b    : integer;
  begin
    wait for 30 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    for f in 0 to NFRM-1 loop
      s := lfsr_next(s);
      flen := 60 + to_integer(s mod 241);        -- 60..300 (volcados validos)
      -- fase dirigida: f=0 llena a 197/256; f=1 (60 B) toca full EXACTAMENTE
      -- en su ultimo byte (197+59=256) => debe ser rewind, no commit truncado
      if f = 0 then flen := 197; elsif f = 1 then flen := 60; end if;
      store.set_len(f, flen);
      -- cada ~8 tramas forzar tag 802.1Q en bytes 12-13
      for i in 0 to flen-1 loop
        s := lfsr_next(s);
        b := to_integer(s(7 downto 0));
        if s(2 downto 0) = "000" then            -- decidido por trama abajo
          null;
        end if;
        store.put(f, i, b);
      end loop;
      if (f mod 8) = 3 then                      -- trama tagged determinista
        store.put(f, 12, 16#81#); store.put(f, 13, 16#00#);
      elsif store.get(f,12) = 16#81# and store.get(f,13) = 16#00# then
        store.put(f, 13, 16#01#);                -- evitar tagged accidental
      end if;
      for i in 0 to flen-1 loop
        rx_data  <= std_logic_vector(to_unsigned(store.get(f,i), 8));
        rx_valid <= '1';
        rx_last  <= '1' when i = flen-1 else '0';
        wait until rising_edge(clk);
      end loop;
      rx_valid <= '0'; rx_last <= '0';
      s := lfsr_next(s);
      gap := 3 + to_integer(s mod 7);
      -- inyectar evento FCS/runt en algunos huecos
      if s(3 downto 2) = "10" then
        if s(4) = '1' then ev_crc <= '1'; else ev_runt <= '1'; end if;
        cnts.inc(4);
      end if;
      wait until rising_edge(clk);
      ev_crc <= '0'; ev_runt <= '0';
      for g in 2 to gap loop wait until rising_edge(clk); end loop;
    end loop;
    done_wr <= true;
    wait;
  end process;

  p_pulses : process
  begin
    wait until rising_edge(clk);
    if cnt_rx = '1'       then cnts.inc(0); end if;
    if cnt_drop_ovf = '1' then cnts.inc(1); end if;
    if cnt_drop_fcs = '1' then cnts.inc(2); end if;
    if cnt_tagged = '1'   then cnts.inc(3); end if;
  end process;

  p_reader : process
    variable s      : unsigned(15 downto 0) := x"C0DE";
    variable cursor : integer := 0;            -- indice de busqueda en enviadas
    variable buf    : integer_vector(0 to MAXB-1);
    variable rlen, got, k : integer;
    variable rtag   : std_logic;
    variable rmac   : std_logic_vector(47 downto 0);
    variable emac   : std_logic_vector(47 downto 0);
    variable etag   : boolean;
    variable match  : boolean;
    variable nmatch, ntagged_e, nredrain : integer := 0;
    variable hash   : unsigned(31 downto 0) := (others => '0');
  begin
    wait until rst = '0';
    -- retener el lector durante la fase dirigida (A+B sin drenaje)
    for w in 1 to 350 loop wait until rising_edge(clk); end loop;
    loop
      wait until rising_edge(clk);
      -- stall largo determinista para provocar overflow aguas arriba
      s := lfsr_next(s);
      if s(6 downto 0) = "0000000" then
        for w in 1 to 500 loop wait until rising_edge(clk); end loop;
      end if;
      if desc_valid = '1' then
        rlen := to_integer(desc_len);
        rtag := desc_tagged;
        rmac := desc_mac;
        -- drenar exactamente rlen bytes con stalls cortos
        got := 0;
        while got < rlen loop
          s := lfsr_next(s);
          if s(1 downto 0) /= "00" then rd_en <= '1'; else rd_en <= '0'; end if;
          wait until rising_edge(clk);
          if rd_en = '1' and rd_valid = '1' then
            buf(got) := to_integer(unsigned(rd_data));
            hash := resize(hash * 33, 32) xor to_unsigned(buf(got), 32);
            got := got + 1;
          end if;
        end loop;
        rd_en <= '0';
        -- cada ~8 tramas: rd_rewind y re-drenaje verificando identidad byte
        -- a byte (el camino multicast del xbar)
        s := lfsr_next(s);
        if s(2 downto 0) = "011" then
          wait until rising_edge(clk);
          rd_rewind <= '1';
          wait until rising_edge(clk);
          rd_rewind <= '0';
          got := 0;
          while got < rlen loop
            s := lfsr_next(s);
            if s(1 downto 0) /= "00" then rd_en <= '1'; else rd_en <= '0'; end if;
            wait until rising_edge(clk);
            if rd_en = '1' and rd_valid = '1' then
              assert to_integer(unsigned(rd_data)) = buf(got)
                report "re-drenaje difiere en byte " & integer'image(got)
                severity failure;
              got := got + 1;
            end if;
          end loop;
          rd_en <= '0';
          nredrain := nredrain + 1;
        end if;
        wait until rising_edge(clk);
        rd_commit <= '1';
        desc_pop  <= '1';
        wait until rising_edge(clk);
        rd_commit <= '0';
        desc_pop  <= '0';
        -- emparejar con la subsecuencia estrictamente creciente de enviadas
        match := false;
        while cursor < NFRM and not match loop
          if store.len(cursor) = rlen then
            match := true;
            for i in 0 to rlen-1 loop
              if store.get(cursor, i) /= buf(i) then match := false; exit; end if;
            end loop;
          end if;
          if not match then cursor := cursor + 1; end if;
        end loop;
        assert match
          report "trama entregada sin pareja en las enviadas (orden/contenido roto)"
          severity failure;
        for i in 0 to 5 loop
          emac(47-8*i downto 40-8*i) :=
            std_logic_vector(to_unsigned(store.get(cursor, i), 8));
        end loop;
        assert rmac = emac
          report "descriptor MAC no coincide en trama " & integer'image(cursor)
          severity failure;
        etag := store.get(cursor,12) = 16#81# and store.get(cursor,13) = 16#00#;
        assert (rtag = '1') = etag
          report "descriptor tagged no coincide en trama " & integer'image(cursor)
          severity failure;
        if etag then ntagged_e := ntagged_e + 1; end if;
        nmatch := nmatch + 1;
        cursor := cursor + 1;
      end if;
      if done_wr and desc_valid = '0' and rd_valid = '0' then
        exit;
      end if;
    end loop;
    -- contabilidad exacta
    wait until rising_edge(clk); wait until rising_edge(clk);
    assert cnts.get(0) = nmatch
      report "cnt_rx=" & integer'image(cnts.get(0)) &
             " /= entregadas=" & integer'image(nmatch) severity failure;
    assert cnts.get(0) + cnts.get(1) = NFRM
      report "rx+ovf=" & integer'image(cnts.get(0)+cnts.get(1)) &
             " /= enviadas=" & integer'image(NFRM) severity failure;
    assert cnts.get(2) = cnts.get(4)
      report "drop_fcs=" & integer'image(cnts.get(2)) &
             " /= inyectados=" & integer'image(cnts.get(4)) severity failure;
    assert cnts.get(3) = ntagged_e
      report "cnt_tagged=" & integer'image(cnts.get(3)) &
             " /= esperadas=" & integer'image(ntagged_e) severity failure;
    assert cnts.get(1) > 0
      report "TB debil: ningun overflow ejercitado" severity failure;
    assert ntagged_e > 0
      report "TB debil: ninguna trama tagged entregada" severity failure;
    assert nredrain > 0
      report "TB debil: ningun re-drenaje ejercitado" severity failure;
    report "ingress: entregadas=" & integer'image(nmatch) &
           " redren=" & integer'image(nredrain) &
           " ovf=" & integer'image(cnts.get(1)) &
           " fcs=" & integer'image(cnts.get(2)) &
           " tagged=" & integer'image(cnts.get(3)) &
           " hash=" & integer'image(to_integer(hash(30 downto 0)));
    report "TB_TSN_INGRESS PASS" severity note;
    std.env.finish;
  end process;
end architecture;
