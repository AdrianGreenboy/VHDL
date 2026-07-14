-- tb_tsn_inject.vhd - Capa 1a: el inyector alimenta un eth_rx_mii real y la
-- trama recuperada debe coincidir byte a byte con la cargada (FCS correcto =>
-- ev_ok, nunca ev_crc). Verifica varias longitudes y dos puertos, y que el
-- inyector respeta busy. Un wire-watcher independiente cuenta los nibbles de
-- preambulo (leccion: el eth_rx_mii tolera preambulo corto, hay que validar
-- el stream en si, no solo que el receptor lo acepte).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_tsn_inject is
end entity;

architecture sim of tb_tsn_inject is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal mii_ce : std_logic := '0';

  signal wr_push, clr_buf, go, busy : std_logic := '0';
  signal wr_word : std_logic_vector(31 downto 0) := (others => '0');
  signal len_bytes : unsigned(11 downto 0) := (others => '0');
  signal port_sel : std_logic_vector(1 downto 0) := (others => '0');
  signal inj_port : std_logic_vector(1 downto 0);
  signal inj_rxd : std_logic_vector(3 downto 0);
  signal inj_rx_dv : std_logic;

  signal rx_data : std_logic_vector(7 downto 0);
  signal rx_valid, rx_last, ev_ok, ev_crc, ev_runt, ev_drop : std_logic;

  constant NF : integer := 4;
  type lens_t is array (0 to NF-1) of integer;
  constant LENS : lens_t := (60, 64, 100, 123);
  type frm_t is array (0 to NF-1, 0 to 199) of integer;
  signal frm : frm_t;
  signal cur_f : integer := 0;
  signal done_all : boolean := false;

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

  inj : entity work.tsn_inject
    generic map (LOG2_DEPTH => 11)
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      wr_push => wr_push, wr_word => wr_word, clr_buf => clr_buf,
      len_bytes => len_bytes, go => go, port_sel => port_sel, busy => busy,
      inj_port => inj_port, inj_rxd => inj_rxd, inj_rx_dv => inj_rx_dv);

  rx : entity work.eth_rx_mii
    port map (clk => clk, rst => rst, mii_ce => mii_ce,
      macaddr => x"000000000000", promisc => '1',
      rxd => inj_rxd, rx_dv => inj_rx_dv,
      rx_data => rx_data, rx_valid => rx_valid, rx_last => rx_last,
      ev_ok => ev_ok, ev_crc => ev_crc, ev_runt => ev_runt, ev_drop => ev_drop);

  p_drive : process
    variable s : unsigned(15 downto 0) := x"9E9E";
    variable w : std_logic_vector(31 downto 0);
    variable ln : integer;
    -- byte o 0 si excede la longitud (padding de la ultima palabra)
    impure function b_at(f, idx, l : integer) return integer is
    begin
      if idx < l then return frm(f, idx); else return 0; end if;
    end function;
    procedure push4(b0,b1,b2,b3 : integer) is
    begin
      wr_word <= std_logic_vector(to_unsigned(b3,8)) &
                 std_logic_vector(to_unsigned(b2,8)) &
                 std_logic_vector(to_unsigned(b1,8)) &
                 std_logic_vector(to_unsigned(b0,8));
      wr_push <= '1'; wait until rising_edge(clk); wr_push <= '0';
      wait until rising_edge(clk);
    end procedure;
  begin
    wait for 30 ns; wait until rising_edge(clk);
    rst <= '0'; wait until rising_edge(clk);
    for f in 0 to NF-1 loop
      ln := LENS(f);
      for k in 0 to ln-1 loop
        if k = 0 then frm(f,k) <= 16#C0# + f;
        else s := lfsr_next(s); frm(f,k) <= to_integer(s(7 downto 0)); end if;
      end loop;
      wait until rising_edge(clk);
      cur_f <= f;
      clr_buf <= '1'; wait until rising_edge(clk); clr_buf <= '0';
      wait until rising_edge(clk);
      for wi in 0 to (ln+3)/4 - 1 loop
        push4(frm(f,4*wi), b_at(f,4*wi+1,ln), b_at(f,4*wi+2,ln), b_at(f,4*wi+3,ln));
      end loop;
      len_bytes <= to_unsigned(ln, 12);
      port_sel  <= std_logic_vector(to_unsigned(f mod 4, 2));
      wait until rising_edge(clk);
      go <= '1'; wait until rising_edge(clk); go <= '0';
      wait until busy = '1';
      wait until busy = '0';
      assert inj_port = std_logic_vector(to_unsigned(f mod 4, 2))
        report "inj_port no coincide con port_sel" severity failure;
      for g in 1 to 60 loop wait until rising_edge(clk); end loop;
    end loop;
    done_all <= true;
    wait;
  end process;

  -- wire-watcher independiente: cuenta nibbles de preambulo (0x5) antes del
  -- SFD (0xD) en cada arranque de inj_rx_dv. Debe ser exactamente 15.
  p_pre_watch : process
    variable prev_dv : std_logic := '0';
    variable pre_n   : integer := 0;
    variable counting : boolean := false;
    variable checked : integer := 0;
  begin
    wait until rst = '0';
    loop
      wait until mii_ce = '1';
      wait until rising_edge(clk);
      if inj_rx_dv = '1' then
        if prev_dv = '0' then
          counting := true; pre_n := 0;
        end if;
        if counting then
          if inj_rxd = x"5" then
            pre_n := pre_n + 1;
          elsif inj_rxd = x"D" then
            assert pre_n = 15
              report "wire-watcher: preambulo de " & integer'image(pre_n) &
                     " nibbles 0x5 antes del SFD, esperados 15" severity failure;
            counting := false;
            checked := checked + 1;
          end if;
        end if;
      end if;
      prev_dv := inj_rx_dv;
      exit when done_all and inj_rx_dv = '0' and checked >= NF;
    end loop;
    report "wire-watcher: preambulos verificados=" & integer'image(checked)
      severity note;
    wait;
  end process;

  p_check : process
    variable k : integer := 0;
    variable nfrm : integer := 0;
    variable id : integer;
    variable nok : integer := 0;
  begin
    wait until rst = '0';
    loop
      wait until rising_edge(clk);
      if rx_valid = '1' then
        if k = 0 then
          id := to_integer(unsigned(rx_data)) - 16#C0#;
          assert id = nfrm
            report "orden/contenido: llego id " & integer'image(id) &
                   " esperaba " & integer'image(nfrm) severity failure;
        end if;
        assert to_integer(unsigned(rx_data)) = frm(nfrm, k)
          report "trama " & integer'image(nfrm) & " byte " & integer'image(k) &
                 ": rx=" & integer'image(to_integer(unsigned(rx_data))) &
                 " esp=" & integer'image(frm(nfrm,k)) severity failure;
        k := k + 1;
        if rx_last = '1' then
          assert k = LENS(nfrm)
            report "trama " & integer'image(nfrm) & " len " & integer'image(k) &
                   " /= " & integer'image(LENS(nfrm)) severity failure;
          nfrm := nfrm + 1; k := 0;
        end if;
      end if;
      if ev_ok = '1' then nok := nok + 1; end if;
      assert ev_crc = '0'
        report "FCS incorrecta del inyector (CRC mal calculado)" severity failure;
      if done_all and nfrm = NF then exit; end if;
    end loop;
    assert nok = NF
      report "ev_ok=" & integer'image(nok) & " /= " & integer'image(NF)
      severity failure;
    report "inject: tramas_ok=" & integer'image(nfrm) &
           " ev_ok=" & integer'image(nok) severity note;
    report "TB_TSN_INJECT PASS" severity note;
    std.env.finish;
  end process;
end architecture;
