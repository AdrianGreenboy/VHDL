-- tb_tsn_xbar.vhd - Nucleo del switch: 4x tsn_ingress + tsn_xbar
-- Fase 1 (dirigida): escenario tsn_scn1.py; el orden de tramas por salida
--   debe ser EXACTAMENTE el del oraculo (SIG 6779bac5), RR incluido.
-- Fase 2 (aleatoria): trafico mixto concurrente; invariantes:
--   (a) cada trama entregada coincide byte a byte con la enviada (i,seq)
--   (b) cada salida receptora pertenece al conjunto de destinos esperado
--   (c) orden por par (entrada,salida) estrictamente creciente en seq
--   (d) al final, cada trama llego a TODOS sus destinos y a ninguno mas
--   (e) pulsos cnt_tx por salida == tramas recibidas en esa salida

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tsn_pkg.all;

entity tb_tsn_xbar is
end entity;

architecture sim of tb_tsn_xbar is
  constant NF2    : natural := 40;   -- tramas aleatorias por entrada
  constant MAXSEQ : natural := 64;
  constant MAXB   : natural := 128;
  constant P2CYC  : natural := 3000; -- inicio de la fase 2 (ciclos)

  function mac_of(p : integer) return std_logic_vector is
  begin
    return std_logic_vector(unsigned'(x"020000000001") + p);
  end;
  constant MAC_BCAST : std_logic_vector(47 downto 0) := x"FFFFFFFFFFFF";
  constant MAC_UNK   : std_logic_vector(47 downto 0) := x"0A0B0C0D0E0F";

  type store_t is protected
    procedure put(i, seq, bidx, b : integer);
    procedure set_len(i, seq, l : integer);
    procedure set_n(i, n : integer);
    impure function get(i, seq, bidx : integer) return integer;
    impure function len(i, seq : integer) return integer;
    impure function nfr(i : integer) return integer;
    procedure mark(i, o, seq : integer);
    impure function got(i, o, seq : integer) return integer;
  end protected;
  type store_t is protected body
    type mem_t is array (0 to 4*MAXSEQ*MAXB-1) of integer;
    type len_t is array (0 to 4*MAXSEQ-1) of integer;
    type n_t   is array (0 to 3) of integer;
    type d_t   is array (0 to 4*4*MAXSEQ-1) of integer;
    variable mem  : mem_t;
    variable lens : len_t := (others => 0);
    variable ns   : n_t := (others => 0);
    variable dlv  : d_t := (others => 0);
    procedure put(i, seq, bidx, b : integer) is
    begin mem((i*MAXSEQ+seq)*MAXB + bidx) := b; end;
    procedure set_len(i, seq, l : integer) is
    begin lens(i*MAXSEQ+seq) := l; end;
    procedure set_n(i, n : integer) is
    begin ns(i) := n; end;
    impure function get(i, seq, bidx : integer) return integer is
    begin return mem((i*MAXSEQ+seq)*MAXB + bidx); end;
    impure function len(i, seq : integer) return integer is
    begin return lens(i*MAXSEQ+seq); end;
    impure function nfr(i : integer) return integer is
    begin return ns(i); end;
    procedure mark(i, o, seq : integer) is
    begin dlv((i*4+o)*MAXSEQ+seq) := dlv((i*4+o)*MAXSEQ+seq) + 1; end;
    impure function got(i, o, seq : integer) return integer is
    begin return dlv((i*4+o)*MAXSEQ+seq); end;
  end protected body;

  shared variable store : store_t;

  -- conjunto de destinos esperado (reimplementacion a nivel de spec)
  function edst(i : integer; dst : std_logic_vector(47 downto 0))
    return std_logic_vector is
    variable v : std_logic_vector(3 downto 0) := (others => '0');
  begin
    if dst(40) = '1' then
      v := (others => '1'); v(i) := '0';
    else
      for p in 0 to 3 loop
        if dst = mac_of(p) then
          if p /= i then v(p) := '1'; end if;
          return v;
        end if;
      end loop;
      v := (others => '1'); v(i) := '0';   -- desconocida: flooding
    end if;
    return v;
  end;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal cyc : integer := 0;

  signal rx_data  : byte_arr4 := (others => (others => '0'));
  signal rx_valid, rx_last : std_logic_vector(3 downto 0) := (others => '0');
  signal ing_rd_en, ing_rd_valid : std_logic_vector(3 downto 0);
  signal ing_rd_data : byte_arr4;
  signal ing_rcm, ing_rrw : std_logic_vector(3 downto 0);
  signal dv, dtag, dpop : std_logic_vector(3 downto 0);
  signal dmac : mac_arr4;
  signal dlen : len_arr4;
  signal c_rx, c_ovf, c_fcs, c_tag : std_logic_vector(3 downto 0);
  signal tx_data : byte_arr4;
  signal tx_valid, tx_last, tx_ready : std_logic_vector(3 downto 0);
  signal tbl_wr : std_logic := '0';
  signal tbl_idx : std_logic_vector(3 downto 0) := (others => '0');
  signal tbl_mac : std_logic_vector(47 downto 0) := (others => '0');
  signal tbl_port : std_logic_vector(1 downto 0) := (others => '0');
  signal tbl_vld : std_logic := '0';
  signal cnt_tx : std_logic_vector(3 downto 0);
  signal tbl_ready : boolean := false;
  signal feeds_done : std_logic_vector(3 downto 0) := (others => '0');
  signal checks_ok : std_logic_vector(3 downto 0) := (others => '0');

  type int4 is array (0 to 3) of integer;
  signal rxfr : int4 := (others => 0);      -- tramas recibidas por salida
  signal txp  : int4 := (others => 0);      -- pulsos cnt_tx por salida
  type hash4 is array (0 to 3) of unsigned(31 downto 0);
  signal ohash : hash4 := (others => (others => '0'));

  -- fase 1: orden esperado de entradas por salida (del oraculo, SIG 6779bac5)
  -- G6 discrimina RR de prioridad fija: out1 sirve in2 ANTES que in0
  type exp_t is array (0 to 4) of integer;
  type exp_arr is array (0 to 3) of exp_t;
  constant EXP_FROM : exp_arr := (0 => (1,3,2,3,-1), 1 => (0,2,0,2,0),
                                  2 => (0,1,3,1,1),  3 => (2,1,2,2,-1));
  constant EXP_N : int4 := (4, 5, 5, 4);

  function lfsr_next(s : unsigned(15 downto 0)) return unsigned is
  begin
    return s(14 downto 0) & (s(15) xor s(13) xor s(12) xor s(10));
  end;
begin
  clk <= not clk after 5 ns;

  p_cyc : process
  begin
    wait until rising_edge(clk);
    cyc <= cyc + 1;
  end process;

  g_ing : for i in 0 to 3 generate
    ing : entity work.tsn_ingress
      generic map (LOG2_DEPTH => 11)
      port map (clk => clk, rst => rst,
        rx_data => rx_data(i), rx_valid => rx_valid(i), rx_last => rx_last(i),
        ev_crc => '0', ev_runt => '0',
        rd_en => ing_rd_en(i), rd_data => ing_rd_data(i),
        rd_valid => ing_rd_valid(i),
        rd_commit => ing_rcm(i), rd_rewind => ing_rrw(i),
        desc_valid => dv(i), desc_mac => dmac(i), desc_len => dlen(i),
        desc_tagged => dtag(i), desc_pop => dpop(i),
        cnt_rx => c_rx(i), cnt_drop_ovf => c_ovf(i),
        cnt_drop_fcs => c_fcs(i), cnt_tagged => c_tag(i));
  end generate;

  xbar : entity work.tsn_xbar
    port map (clk => clk, rst => rst,
      desc_valid => dv, desc_mac => dmac, desc_len => dlen, desc_pop => dpop,
      rd_en => ing_rd_en, rd_data => ing_rd_data, rd_valid => ing_rd_valid,
      rd_commit => ing_rcm, rd_rewind => ing_rrw,
      tx_data => tx_data, tx_valid => tx_valid, tx_last => tx_last,
      tx_ready => tx_ready,
      tbl_wr => tbl_wr, tbl_idx => tbl_idx, tbl_mac => tbl_mac,
      tbl_port => tbl_port, tbl_vld => tbl_vld,
      cnt_tx => cnt_tx);

  -- programacion de la tabla: MAC(p) -> p (via interfaz MMIO de 1 paso aqui)
  p_tbl : process
  begin
    wait for 30 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);
    for p in 0 to 3 loop
      tbl_mac  <= mac_of(p);
      tbl_port <= std_logic_vector(to_unsigned(p, 2));
      tbl_vld  <= '1';
      tbl_idx  <= std_logic_vector(to_unsigned(p, 4));
      tbl_wr   <= '1';
      wait until rising_edge(clk);
    end loop;
    -- entrada invalida con MAC plausible: NO debe rutar (mutacion M5)
    tbl_mac  <= MAC_UNK;
    tbl_port <= "01";
    tbl_vld  <= '0';
    tbl_idx  <= x"7";
    tbl_wr   <= '1';
    wait until rising_edge(clk);
    tbl_wr <= '0';
    tbl_ready <= true;
    wait;
  end process;

  g_feed : for i in 0 to 3 generate
    p_feed : process
      variable s    : unsigned(15 downto 0);
      variable seq  : integer := 0;
      variable flen : integer;
      variable dst  : std_logic_vector(47 downto 0);
      variable b    : integer;
      procedure send(dstm : std_logic_vector(47 downto 0); l : integer) is
      begin
        store.set_len(i, seq, l);
        for k in 0 to 5 loop
          store.put(i, seq, k,   to_integer(unsigned(dstm(47-8*k downto 40-8*k))));
          store.put(i, seq, 6+k, to_integer(unsigned(mac_of(i)(47-8*k downto 40-8*k))));
        end loop;
        store.put(i, seq, 12, 16#08#); store.put(i, seq, 13, 16#00#);
        store.put(i, seq, 14, i);
        store.put(i, seq, 15, seq / 256);
        store.put(i, seq, 16, seq mod 256);
        for k in 17 to l-1 loop
          s := lfsr_next(s);
          store.put(i, seq, k, to_integer(s(7 downto 0)));
        end loop;
        for k in 0 to l-1 loop
          rx_data(i)  <= std_logic_vector(to_unsigned(store.get(i, seq, k), 8));
          rx_valid(i) <= '1';
          rx_last(i)  <= '1' when k = l-1 else '0';
          wait until rising_edge(clk);
        end loop;
        rx_valid(i) <= '0'; rx_last(i) <= '0';
        wait until rising_edge(clk);
        seq := seq + 1;
      end;
      procedure at_cyc(t : integer) is
      begin
        while cyc < t loop wait until rising_edge(clk); end loop;
      end;
    begin
      s := to_unsigned(16#B00# + i*97, 16);
      wait until tbl_ready;
      -- ===== fase 1: escenario del oraculo (grupos cada 400 ciclos) =====
      if i = 0 then
        at_cyc(100);  send(mac_of(1), 60);
        at_cyc(500);  send(mac_of(2), 60);
        at_cyc(2100); send(mac_of(1), 60);
        at_cyc(2500); send(mac_of(1), 60);   -- G6: pierde ante in2 por RR
      elsif i = 1 then
        at_cyc(500);  send(mac_of(2), 60);
        at_cyc(900);  send(MAC_BCAST, 60);
        at_cyc(2100); send(mac_of(2), 60);
      elsif i = 2 then
        at_cyc(100);  send(mac_of(3), 60);
        at_cyc(1300); send(MAC_UNK, 60);
        at_cyc(2100); send(mac_of(3), 60);
        at_cyc(2500); send(mac_of(1), 60);   -- G6: gana a in0 por RR
      else
        at_cyc(500);  send(mac_of(2), 60);
        at_cyc(900);  send(mac_of(0), 60);
        at_cyc(1700); send(mac_of(3), 60);   -- dst==ingreso: filtrada
        at_cyc(2100); send(mac_of(0), 60);
      end if;
      -- ===== fase 2: trafico aleatorio concurrente =====
      at_cyc(P2CYC);
      for f in 1 to NF2 loop
        s := lfsr_next(s);
        flen := 60 + to_integer(s mod 60);
        s := lfsr_next(s);
        case to_integer(s(2 downto 0)) is
          when 0 | 1 | 2 | 3 => dst := mac_of(to_integer(s(1 downto 0)));
          when 4             => dst := MAC_BCAST;
          when 5             => dst := MAC_UNK;
          when others        => dst := mac_of((i+1) mod 4);
        end case;
        send(dst, flen);
        s := lfsr_next(s);
        -- hueco dimensionado: ~65% de utilizacion agregada (bcast x3 copias);
        -- el invariante de cobertura exige CERO overflows (monitor abajo)
        for g in 1 to 150 + to_integer(s mod 100) loop
          wait until rising_edge(clk);
        end loop;
      end loop;
      store.set_n(i, seq);
      feeds_done(i) <= '1';
      wait;
    end process;
  end generate;

  g_chk : for o in 0 to 3 generate
    p_chk : process
      variable s     : unsigned(15 downto 0);
      variable buf   : integer_vector(0 to MAXB-1);
      variable got   : integer := 0;
      variable fi, fseq, l : integer;
      variable lastq : int4 := (others => -1);
      variable nfr_o : integer := 0;
      variable hh    : unsigned(31 downto 0) := (others => '0');
      variable ed    : std_logic_vector(3 downto 0);
      variable dstm  : std_logic_vector(47 downto 0);
    begin
      s := to_unsigned(16#C40# + o*53, 16);
      wait until rst = '0';
      loop
        s := lfsr_next(s);
        -- fase 1: siempre lista; fase 2: 75% lista
        if cyc < P2CYC or s(1 downto 0) /= "00" then
          tx_ready(o) <= '1';
        else
          tx_ready(o) <= '0';
        end if;
        wait until rising_edge(clk);
        if tx_ready(o) = '1' and tx_valid(o) = '1' then
          buf(got) := to_integer(unsigned(tx_data(o)));
          hh := resize(hh * 33, 32) xor to_unsigned(buf(got), 32);
          got := got + 1;
          if tx_last(o) = '1' then
            l := got; got := 0;
            fi   := buf(14);
            fseq := buf(15) * 256 + buf(16);
            assert l = store.len(fi, fseq)
              report "salida " & integer'image(o) & ": len " & integer'image(l)
                     & " /= " & integer'image(store.len(fi, fseq))
                     & " (in " & integer'image(fi) & " seq " & integer'image(fseq) & ")"
              severity failure;
            for k in 0 to l-1 loop
              assert buf(k) = store.get(fi, fseq, k)
                report "salida " & integer'image(o) & ": byte " & integer'image(k)
                       & " difiere (in " & integer'image(fi) & " seq "
                       & integer'image(fseq) & ")"
                severity failure;
            end loop;
            for k in 0 to 5 loop
              dstm(47-8*k downto 40-8*k) :=
                std_logic_vector(to_unsigned(buf(k), 8));
            end loop;
            ed := edst(fi, dstm);
            assert ed(o) = '1'
              report "salida " & integer'image(o) & ": trama (in "
                     & integer'image(fi) & " seq " & integer'image(fseq)
                     & ") NO iba destinada aqui"
              severity failure;
            assert fseq > lastq(fi)
              report "salida " & integer'image(o) & ": orden roto del par (in "
                     & integer'image(fi) & "): seq " & integer'image(fseq)
                     & " tras " & integer'image(lastq(fi))
              severity failure;
            lastq(fi) := fseq;
            -- fase 1: verificar el orden exacto del oraculo
            if nfr_o < EXP_N(o) then
              assert fi = EXP_FROM(o)(nfr_o)
                report "salida " & integer'image(o) & ": fase 1 trama "
                       & integer'image(nfr_o) & " vino de " & integer'image(fi)
                       & ", oraculo dice " & integer'image(EXP_FROM(o)(nfr_o))
                severity failure;
            end if;
            store.mark(fi, o, fseq);
            nfr_o := nfr_o + 1;
          end if;
        end if;
        if feeds_done = "1111" and got = 0 and nfr_o > EXP_N(o) then
          -- salir cuando lleve un rato sin trafico
          s := lfsr_next(s);
          if tx_valid = "0000" and dv = "0000" then
            exit;
          end if;
        end if;
      end loop;
      rxfr(o)  <= nfr_o;
      ohash(o) <= hh;
      checks_ok(o) <= '1';
      wait;
    end process;
  end generate;

  p_txp : process
  begin
    wait until rising_edge(clk);
    for o in 0 to 3 loop
      if cnt_tx(o) = '1' then txp(o) <= txp(o) + 1; end if;
    end loop;
    if rst = '0' then
      assert c_ovf = "0000"
        report "overflow de ingreso: el TB exige perdida cero (subir huecos)"
        severity failure;
    end if;
  end process;

  p_final : process
    variable ed   : std_logic_vector(3 downto 0);
    variable dstm : std_logic_vector(47 downto 0);
    variable tot  : integer := 0;
    variable hh   : unsigned(31 downto 0) := (others => '0');
  begin
    wait until checks_ok = "1111";
    for w in 1 to 20 loop wait until rising_edge(clk); end loop;
    -- (e) pulsos cnt_tx == tramas recibidas por salida
    for o in 0 to 3 loop
      assert txp(o) = rxfr(o)
        report "cnt_tx(" & integer'image(o) & ")=" & integer'image(txp(o))
               & " /= recibidas=" & integer'image(rxfr(o)) severity failure;
    end loop;
    -- (d) cobertura total: cada trama a TODOS sus destinos, una vez
    for i in 0 to 3 loop
      for q in 0 to store.nfr(i)-1 loop
        for k in 0 to 5 loop
          dstm(47-8*k downto 40-8*k) :=
            std_logic_vector(to_unsigned(store.get(i, q, k), 8));
        end loop;
        ed := edst(i, dstm);
        for o in 0 to 3 loop
          if ed(o) = '1' then
            assert store.got(i, o, q) = 1
              report "trama (in " & integer'image(i) & " seq " & integer'image(q)
                     & ") entregada " & integer'image(store.got(i, o, q))
                     & " veces en salida " & integer'image(o) severity failure;
            tot := tot + 1;
          else
            assert store.got(i, o, q) = 0
              report "trama (in " & integer'image(i) & " seq " & integer'image(q)
                     & ") NO debia salir por " & integer'image(o) severity failure;
          end if;
        end loop;
      end loop;
    end loop;
    for o in 0 to 3 loop
      hh := resize(hh * 33, 32) xor ohash(o);
    end loop;
    report "xbar: entregas=" & integer'image(tot) &
           " porSalida=" & integer'image(rxfr(0)) & "/" & integer'image(rxfr(1))
           & "/" & integer'image(rxfr(2)) & "/" & integer'image(rxfr(3)) &
           " hash=" & integer'image(to_integer(hh(30 downto 0)));
    report "TB_TSN_XBAR PASS" severity note;
    std.env.finish;
  end process;
end architecture;
