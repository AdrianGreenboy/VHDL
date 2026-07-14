-- tb_tsn_top_l1c.vhd - Capa 1c del switch completo (LOOP_INT)
-- Estimulo REALISTA: el driver inyecta nibbles MII crudos en rxd/rx_dv de cada
-- puerto (como un PHY), pasando por eth_rx_mii real. La tabla se programa por
-- MMIO. Los checkers observan los pines MII de salida (txd/tx_en) y decodifican
-- las tramas de forma INDEPENDIENTE del datapath (wire-watchers).
--
-- Fase 0 (anti modo-comun): con la tabla programada pero SIN inyectar trafico,
-- un watchdog exige que NINGUNA salida transmita (tx_en debe seguir en 0). Se
-- verifico que la asercion tiene dientes (invertida, dispara a ~315ns).
--
-- Fase 1: inyeccion concurrente por los 4 puertos (unicast/broadcast/unknown/
-- filtrada); cada salida decodifica sus tramas, verifica contenido, destino
-- esperado, orden por par (entrada,salida) y cobertura total.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tsn_pkg.all;

entity tb_tsn_top_l1c is
end entity;

architecture sim of tb_tsn_top_l1c is
  constant NF : integer := 10;          -- tramas por puerto (fase 1)
  constant MAXB : integer := 160;

  function mac_of(p : integer) return std_logic_vector is
  begin return std_logic_vector(unsigned'(x"020000000001") + p); end;
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
    type mem_t is array (0 to 4*64*MAXB-1) of integer;
    type len_t is array (0 to 4*64-1) of integer;
    type n_t   is array (0 to 3) of integer;
    type d_t   is array (0 to 4*4*64-1) of integer;
    variable mem : mem_t; variable lens : len_t := (others => 0);
    variable ns : n_t := (others => 0); variable dlv : d_t := (others => 0);
    procedure put(i, seq, bidx, b : integer) is
    begin mem((i*64+seq)*MAXB+bidx) := b; end;
    procedure set_len(i, seq, l : integer) is begin lens(i*64+seq) := l; end;
    procedure set_n(i, n : integer) is begin ns(i) := n; end;
    impure function get(i, seq, bidx : integer) return integer is
    begin return mem((i*64+seq)*MAXB+bidx); end;
    impure function len(i, seq : integer) return integer is
    begin return lens(i*64+seq); end;
    impure function nfr(i : integer) return integer is begin return ns(i); end;
    procedure mark(i, o, seq : integer) is
    begin dlv((i*4+o)*64+seq) := dlv((i*4+o)*64+seq)+1; end;
    impure function got(i, o, seq : integer) return integer is
    begin return dlv((i*4+o)*64+seq); end;
  end protected body;
  shared variable store : store_t;

  function edst(i : integer; dst : std_logic_vector(47 downto 0))
    return std_logic_vector is
    variable v : std_logic_vector(3 downto 0) := (others => '0');
  begin
    if dst(40) = '1' then v := (others => '1'); v(i) := '0';
    else
      for p in 0 to 3 loop
        if dst = mac_of(p) then
          if p /= i then v(p) := '1'; end if; return v;
        end if;
      end loop;
      v := (others => '1'); v(i) := '0';
    end if;
    return v;
  end;

  -- CRC32 Ethernet para construir FCS del estimulo (poly 0xEDB88320)
  function crc_next(crc : unsigned(31 downto 0); b : std_logic_vector(7 downto 0))
    return unsigned is
    variable c : unsigned(31 downto 0) := crc;
    variable bt : unsigned(7 downto 0) := unsigned(b);
  begin
    c := c xor resize(bt, 32);
    for k in 0 to 7 loop
      if c(0) = '1' then c := ('0' & c(31 downto 1)) xor x"EDB88320";
      else c := '0' & c(31 downto 1); end if;
    end loop;
    return c;
  end;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal mii_ce : std_logic := '0';
  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(8 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal irq : std_logic;
  signal rx_src : std_logic_vector(1 downto 0) := "00";
  signal mii_txd, mii_rxd : byte_arr4 := (others => (others => '0'));
  signal mii_tx_en, mii_rx_dv : std_logic_vector(3 downto 0) := (others => '0');

  signal tbl_ready : boolean := false;
  signal phase0_done : boolean := false;
  signal feeds_done : std_logic_vector(3 downto 0) := (others => '0');
  signal checks_ok : std_logic_vector(3 downto 0) := (others => '0');
  type int4 is array (0 to 3) of integer;
  signal rxfr : int4 := (others => 0);

  function lfsr_next(s : unsigned(15 downto 0)) return unsigned is
  begin return s(14 downto 0) & (s(15) xor s(13) xor s(12) xor s(10)); end;
begin
  clk <= not clk after 5 ns;

  p_ce : process(clk)
    variable d : integer := 0;
  begin
    if rising_edge(clk) then
      if d = 3 then mii_ce <= '1'; d := 0; else mii_ce <= '0'; d := d+1; end if;
    end if;
  end process;

  dut : entity work.tsn_top
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      sel => sel, we => we, addr => addr, wdata => wdata, rdata => rdata,
      irq => irq, rx_src => rx_src,
      mii_txd => mii_txd, mii_tx_en => mii_tx_en,
      mii_rxd => mii_rxd, mii_rx_dv => mii_rx_dv);

  -- programacion de la tabla por MMIO (3 pasos por entrada)
  p_tbl : process
    procedure wr32(a : std_logic_vector(8 downto 0);
                   d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      sel <= '1'; we <= '1'; addr <= a; wdata <= d;
      wait until rising_edge(clk); sel <= '0'; we <= '0';
    end procedure;
  begin
    wait for 30 ns; wait until rising_edge(clk);
    rst <= '0'; wait until rising_edge(clk);
    wr32(9x"000", x"00000001");                     -- enable
    for p in 0 to 3 loop
      -- MAC(p) -> puerto p, valid. LO = MAC[31:0]; HI = vld|port|MAC[47:32]
      wr32(9x"008", mac_of(p)(31 downto 0));
      wr32(9x"00C", '1' & "0000000000000" &
                    std_logic_vector(to_unsigned(p, 2)) &
                    mac_of(p)(47 downto 32));
      wr32(9x"010", "0000000000000000000000000000" &
                    std_logic_vector(to_unsigned(p, 4)));
    end loop;
    tbl_ready <= true;
    wait;
  end process;

  -- driver de nibbles MII crudos por puerto (como un PHY externo)
  g_drv : for i in 0 to 3 generate
    p_drv : process
      variable s : unsigned(15 downto 0);
      variable seq : integer := 0;
      variable dst : std_logic_vector(47 downto 0);
      variable crc : unsigned(31 downto 0);
      variable ln, tot : integer;
      type buf_t is array (0 to MAXB-1) of integer;
      variable fb : buf_t;

      procedure send_wire(l : integer) is
      begin
        -- preambulo 7x55 + SFD D5, luego l bytes, nibble bajo primero
        for pn in 0 to 6 loop
          for nib in 0 to 1 loop
            wait until mii_ce = '1'; wait until rising_edge(clk);
            mii_rxd(i) <= x"05"; mii_rx_dv(i) <= '1';
          end loop;
        end loop;
        wait until mii_ce = '1'; wait until rising_edge(clk);
        mii_rxd(i) <= x"05"; mii_rx_dv(i) <= '1';
        wait until mii_ce = '1'; wait until rising_edge(clk);
        mii_rxd(i) <= x"0D"; mii_rx_dv(i) <= '1';
        for k in 0 to l-1 loop
          wait until mii_ce = '1'; wait until rising_edge(clk);
          mii_rxd(i) <= "0000" & std_logic_vector(to_unsigned(fb(k) mod 16, 4));
          mii_rx_dv(i) <= '1';
          wait until mii_ce = '1'; wait until rising_edge(clk);
          mii_rxd(i) <= "0000" & std_logic_vector(to_unsigned(fb(k)/16, 4));
          mii_rx_dv(i) <= '1';
        end loop;
        wait until mii_ce = '1'; wait until rising_edge(clk);
        mii_rx_dv(i) <= '0'; mii_rxd(i) <= x"00";
      end procedure;

      procedure build_and_send(dstm : std_logic_vector(47 downto 0);
                               payload : integer) is
      begin
        ln := payload;                          -- bytes de datos (>=60)
        store.set_len(i, seq, ln);
        for k in 0 to 5 loop
          fb(k)   := to_integer(unsigned(dstm(47-8*k downto 40-8*k)));
          fb(6+k) := to_integer(unsigned(mac_of(i)(47-8*k downto 40-8*k)));
        end loop;
        fb(12) := 16#08#; fb(13) := 16#00#;
        fb(14) := i; fb(15) := seq/256; fb(16) := seq mod 256;
        for k in 17 to ln-1 loop
          s := lfsr_next(s); fb(k) := to_integer(s(7 downto 0));
        end loop;
        for k in 0 to ln-1 loop store.put(i, seq, k, fb(k)); end loop;
        -- anexar FCS de 4 bytes al cable
        crc := (others => '1');
        for k in 0 to ln-1 loop
          crc := crc_next(crc, std_logic_vector(to_unsigned(fb(k), 8)));
        end loop;
        crc := not crc;
        fb(ln)   := to_integer(crc(7 downto 0));
        fb(ln+1) := to_integer(crc(15 downto 8));
        fb(ln+2) := to_integer(crc(23 downto 16));
        fb(ln+3) := to_integer(crc(31 downto 24));
        send_wire(ln + 4);
        seq := seq + 1;
      end procedure;
    begin
      s := to_unsigned(16#700# + i*61, 16);
      mii_rx_dv(i) <= '0';
      wait until phase0_done;
      for f in 0 to NF-1 loop
        s := lfsr_next(s);
        case to_integer(s(2 downto 0)) is
          when 0|1|2|3 => dst := mac_of(to_integer(s(1 downto 0)));
          when 4       => dst := MAC_BCAST;
          when 5       => dst := MAC_UNK;
          when others  => dst := mac_of((i+1) mod 4);
        end case;
        build_and_send(dst, 60);
        -- hueco generoso (sin overflow): las copias de broadcast tardan
        for g in 1 to 400 loop wait until rising_edge(clk); end loop;
      end loop;
      store.set_n(i, seq);
      feeds_done(i) <= '1';
      wait;
    end process;
  end generate;

  -- Fase 0: tabla lista, sin trafico -> ninguna salida debe transmitir
  p_phase0 : process
  begin
    wait until tbl_ready;
    for w in 1 to 4000 loop
      wait until rising_edge(clk);
      assert mii_tx_en = "0000"
        report "FASE 0 FALLO: salida transmite sin trafico de entrada"
        severity failure;
    end loop;
    report "FASE 0 OK: silencio sin estimulo" severity note;
    phase0_done <= true;
    wait;
  end process;

  -- wire-watchers: decodifican los pines MII de salida independientemente
  g_watch : for o in 0 to 3 generate
    p_watch : process
      variable lo : integer; variable hi : integer;
      variable havelo : boolean := false;
      variable byte_i : integer := 0;
      variable buf : integer_vector(0 to MAXB-1);
      variable fi, fseq, dcount : integer;
      variable lastq : int4 := (others => -1);
      variable nfr_o : integer := 0;
      variable ed : std_logic_vector(3 downto 0);
      variable dstm : std_logic_vector(47 downto 0);
      variable sawpre : boolean := false;
    begin
      wait until phase0_done;
      loop
        wait until mii_ce = '1';
        wait until rising_edge(clk);
        if mii_tx_en(o) = '1' then
          if mii_txd(o)(3 downto 0) = x"5" and not sawpre then
            null;   -- preambulo
          elsif mii_txd(o)(3 downto 0) = x"D" and not sawpre then
            sawpre := true; havelo := false; byte_i := 0;  -- SFD visto
          elsif sawpre then
            if not havelo then
              lo := to_integer(unsigned(mii_txd(o)(3 downto 0)));
              havelo := true;
            else
              hi := to_integer(unsigned(mii_txd(o)(3 downto 0)));
              buf(byte_i) := hi*16 + lo;
              byte_i := byte_i + 1;
              havelo := false;
            end if;
          end if;
        else
          if sawpre and byte_i > 4 then
            -- fin de trama: byte_i incluye 4 de FCS
            dcount := byte_i - 4;
            fi   := buf(14);
            fseq := buf(15)*256 + buf(16);
            assert dcount = store.len(fi, fseq)
              report "watch o" & integer'image(o) & ": len " &
                     integer'image(dcount) & " /= " &
                     integer'image(store.len(fi, fseq)) severity failure;
            for k in 0 to dcount-1 loop
              assert buf(k) = store.get(fi, fseq, k)
                report "watch o" & integer'image(o) & ": byte " &
                       integer'image(k) & " difiere (in " & integer'image(fi) &
                       " seq " & integer'image(fseq) & ")" severity failure;
            end loop;
            for k in 0 to 5 loop
              dstm(47-8*k downto 40-8*k) :=
                std_logic_vector(to_unsigned(buf(k), 8));
            end loop;
            ed := edst(fi, dstm);
            assert ed(o) = '1'
              report "watch o" & integer'image(o) & ": trama no destinada aqui"
              severity failure;
            assert fseq > lastq(fi)
              report "watch o" & integer'image(o) & ": orden roto par in " &
                     integer'image(fi) severity failure;
            lastq(fi) := fseq;
            store.mark(fi, o, fseq);
            nfr_o := nfr_o + 1;
          end if;
          sawpre := false; havelo := false; byte_i := 0;
        end if;
        exit when feeds_done = "1111" and mii_tx_en = "0000" and
                  nfr_o >= 0 and byte_i = 0;
      end loop;
      -- margen para vaciar
      for w in 1 to 4000 loop wait until rising_edge(clk); end loop;
      rxfr(o) <= nfr_o;
      checks_ok(o) <= '1';
      wait;
    end process;
  end generate;

  p_final : process
    variable ed : std_logic_vector(3 downto 0);
    variable dstm : std_logic_vector(47 downto 0);
    variable tot : integer := 0;
  begin
    wait until checks_ok = "1111";
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
              report "cobertura: (in " & integer'image(i) & " seq " &
                     integer'image(q) & ") en o" & integer'image(o) & " = " &
                     integer'image(store.got(i, o, q)) severity failure;
            tot := tot + 1;
          else
            assert store.got(i, o, q) = 0
              report "fuga: (in " & integer'image(i) & " seq " &
                     integer'image(q) & ") salio por o" & integer'image(o)
              severity failure;
          end if;
        end loop;
      end loop;
    end loop;
    report "top_l1c: entregas=" & integer'image(tot) &
           " porSalida=" & integer'image(rxfr(0)) & "/" & integer'image(rxfr(1))
           & "/" & integer'image(rxfr(2)) & "/" & integer'image(rxfr(3));
    report "TB_TSN_TOP_L1C PASS" severity note;
    std.env.finish;
  end process;
end architecture;
