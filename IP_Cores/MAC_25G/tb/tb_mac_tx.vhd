-------------------------------------------------------------------------------
-- HERCOSSNUX Core 20 - MAC 25G
-- Layer 2A: generador + MAC TX contra el oraculo, bloque a bloque.
--
-- 'ce' sigue un patron pseudoaleatorio (LFSR) con ~25% de ciclos a 0 y, en
-- otra fase, el patron 32/33 del gearbox: el flujo de bloques (contando solo
-- ciclos con blk_valid) debe ser IDENTICO al del oraculo a partir del primer
-- /S/. Ademas se comprueba IPG >= 12 caracteres en todo el flujo.
--
-- Criterio: LAYER2A_PASS FNV32=<firma del oraculo para el fichero VEC>.
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.mac25g_pkg.all;

entity tb_mac_tx is
  generic (
    VEC     : string  := "tx_txa.txt";
    LEN_MIN : natural := 20;
    LEN_MAX : natural := 1514;
    STEP    : natural := 37;
    NFR     : natural := 64;
    INJ     : boolean := false;
    CE_MODE : natural := 0      -- 0 aleatorio, 1 patron 32/33, 2 siempre 1
  );
end entity;

architecture sim of tb_mac_tx is
  constant T : time := 2.56 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ce  : std_logic := '0';
  signal start, inj_p : std_logic := '0';

  signal g_tdata  : std_logic_vector(63 downto 0);
  signal g_tkeep  : std_logic_vector(7 downto 0);
  signal g_tlast, g_tvalid, g_tready : std_logic;
  signal g_busy, g_done : std_logic;

  signal b_valid, b_isd : std_logic;
  signal b_pl : std_logic_vector(63 downto 0);
  signal ev_f, ev_u : std_logic;
  signal ev_b : unsigned(15 downto 0);

  signal done_sim : boolean := false;
  signal lfsr : std_logic_vector(15 downto 0) := x"ACE1";
  signal ph33 : natural range 0 to 32 := 0;

  constant DST : std_logic_vector(47 downto 0) := x"2032" & x"43414D02";
  constant SRC : std_logic_vector(47 downto 0) := x"204E" & x"45474E02";
begin
  clk <= not clk after T/2 when not done_sim;

  u_gen: entity work.mac25g_gen
    port map (clk=>clk, rst=>rst, start=>start, stop=>'0', cont=>'0',
              dst=>DST, src=>SRC,
              len_min=>to_unsigned(LEN_MIN, 11), len_max=>to_unsigned(LEN_MAX, 11),
              len_step=>to_unsigned(STEP, 11), count=>to_unsigned(NFR, 32),
              m_tdata=>g_tdata, m_tkeep=>g_tkeep, m_tlast=>g_tlast,
              m_tvalid=>g_tvalid, m_tready=>g_tready, busy=>g_busy, done=>g_done);

  u_tx: entity work.mac25g_tx
    port map (clk=>clk, rst=>rst, ce=>ce,
              s_tdata=>g_tdata, s_tkeep=>g_tkeep, s_tlast=>g_tlast,
              s_tvalid=>g_tvalid, s_tready=>g_tready, inj=>inj_p,
              blk_valid=>b_valid, blk_payload=>b_pl, blk_is_data=>b_isd,
              ev_frame=>ev_f, ev_bytes=>ev_b, ev_underrun=>ev_u);

  -- patron de ce
  process(clk)
  begin
    if rising_edge(clk) then
      lfsr <= lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      if ph33 = 32 then ph33 <= 0; else ph33 <= ph33 + 1; end if;
      case CE_MODE is
        when 0 => if lfsr(1 downto 0) = "00" then ce <= '0'; else ce <= '1'; end if;
        when 1 => if ph33 = 32 then ce <= '0'; else ce <= '1'; end if;
        when others => ce <= '1';
      end case;
    end if;
  end process;

  stim: process
  begin
    rst <= '1';
    wait for 20*T;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 5*T;
    wait until rising_edge(clk);
    if INJ then inj_p <= '1'; wait until rising_edge(clk); inj_p <= '0'; end if;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait;
  end process;

  chk: process
    file f : text;
    variable l : line;
    variable nexp, k, isd_e, errs : integer := 0;
    variable pl_e : std_logic_vector(63 downto 0);
    variable started : boolean := false;
    variable h : unsigned(31 downto 0) := x"811C9DC5";
    variable b8 : std_logic_vector(7 downto 0);
    variable nframes_ev, under : natural := 0;
    variable gap : integer := 0;
    variable in_gap, seen_t : boolean := false;
    variable ipg_bad : natural := 0;
    variable bt : std_logic_vector(7 downto 0);
    variable tidx : integer;
    variable cycles : natural := 0;

    procedure fnv(b : std_logic_vector(7 downto 0)) is
    begin
      h := h xor resize(unsigned(b), 32);
      h := resize(h * to_unsigned(16777619, 32), 32);
    end procedure;
  begin
    file_open(f, VEC, read_mode);
    readline(f, l); read(l, nexp);
    k := 0;
    while k < nexp loop
      wait until rising_edge(clk);
      cycles := cycles + 1;
      assert cycles < 2_000_000 report "TIMEOUT tb_mac_tx" severity failure;
      if ev_f = '1' then nframes_ev := nframes_ev + 1; end if;
      if ev_u = '1' then under := under + 1; end if;
      if b_valid = '1' then
        if not started and b_isd = '0' and b_pl = START_BLOCK then
          started := true;
        end if;
        if started then
          readline(f, l); read(l, isd_e); hread(l, pl_e);
          if (b_isd = '1') /= (isd_e = 1) or b_pl /= pl_e then
            errs := errs + 1;
            if errs < 6 then
              report "MISMATCH bloque " & integer'image(k) & " got isd=" &
                std_logic'image(b_isd) & " pl=" & to_hstring(b_pl) &
                " exp isd=" & integer'image(isd_e) & " pl=" & to_hstring(pl_e)
                severity error;
            end if;
          end if;
          -- firma: payload (8 bytes LE) + byte is_data
          for i in 0 to 7 loop fnv(b_pl(8*i+7 downto 8*i)); end loop;
          if b_isd = '1' then fnv(x"01"); else fnv(x"00"); end if;
          -- IPG
          bt := b_pl(7 downto 0);
          tidx := -1;
          if b_isd = '0' then
            case bt is
              when x"87" => tidx := 0; when x"99" => tidx := 1;
              when x"AA" => tidx := 2; when x"B4" => tidx := 3;
              when x"CC" => tidx := 4; when x"D2" => tidx := 5;
              when x"E1" => tidx := 6; when x"FF" => tidx := 7;
              when others => null;
            end case;
          end if;
          if tidx >= 0 then
            gap := 8 - tidx; in_gap := true; seen_t := true;
          elsif b_isd = '0' and bt = x"1E" and in_gap then
            gap := gap + 8;
          elsif b_isd = '0' and bt = x"78" then
            if seen_t and gap < 12 then ipg_bad := ipg_bad + 1; end if;
            in_gap := false;
          end if;
          k := k + 1;
        end if;
      end if;
    end loop;
    file_close(f);

    -- dejar que salga el ultimo ev_frame
    for i in 0 to 40 loop
      wait until rising_edge(clk);
      if ev_f = '1' then nframes_ev := nframes_ev + 1; end if;
    end loop;

    if nframes_ev /= NFR then
      report "FAIL: ev_frame=" & integer'image(nframes_ev) & " esperado " &
        integer'image(NFR) severity error;
      errs := errs + 1;
    end if;
    if under /= 0 then report "FAIL: underrun inesperado" severity error; errs := errs + 1; end if;
    if ipg_bad /= 0 then report "FAIL: IPG < 12" severity error; errs := errs + 1; end if;
    if g_done /= '1' then report "FAIL: generador no termino" severity error; errs := errs + 1; end if;

    if errs = 0 then
      report "LAYER2A_PASS FNV32=0x" & to_hstring(std_logic_vector(h)) &
        " bloques=" & integer'image(nexp) & " ce_mode=" & integer'image(CE_MODE);
    else
      report "LAYER2A_FAIL errores=" & integer'image(errs) severity error;
    end if;
    done_sim <= true;
    wait;
  end process;
end architecture;
