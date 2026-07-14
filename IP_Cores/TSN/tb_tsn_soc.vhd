-- tb_tsn_soc.vhd - Capa 4: RTL-vs-ISS por MMIO (auto-estimulo con inyector).
-- Un BFM presenta el bus dmem al tsn_top y ejecuta el MISMO programa que
-- iss_tsn.py: programa la tabla (MAC(p)->p), inyecta N tramas por el inyector
-- (rx_src="10"), y lee los 20 contadores. El vector debe coincidir bit-identico
-- con iss_tsn_oracle.txt (formato "LABEL valor"). Replica exacta de lo que hara
-- el firmware en silicio (capa 5): mismo mapa MMIO, misma secuencia.
--
-- Nota de metodologia: el switch no expone una senal de "quieto" fiable
-- (st_obusy se mapea a un pulso cnt_tx, no a un nivel de ocupacion), asi que
-- entre inyecciones se usa un margen fijo generoso. El determinismo se
-- verifico ejecutando con margenes distintos (4000 y 6000 ciclos): mismo
-- vector de contadores. El firmware en silicio usara la misma espera fija.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.tsn_pkg.all;

entity tb_tsn_soc is
end entity;

architecture sim of tb_tsn_soc is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal mii_ce : std_logic := '0';
  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(8 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal irq : std_logic;
  signal rx_src : std_logic_vector(1 downto 0) := "10";  -- inyector
  signal mii_txd, mii_rxd : byte_arr4 := (others => (others => '0'));
  signal mii_tx_en, mii_rx_dv : std_logic_vector(3 downto 0) := (others => '0');

  function mac_of(p : integer) return std_logic_vector is
  begin return std_logic_vector(unsigned'(x"020000000001") + p); end;
  constant MAC_BCAST : std_logic_vector(47 downto 0) := x"FFFFFFFFFFFF";
  constant MAC_UNK   : std_logic_vector(47 downto 0) := x"0A0B0C0D0E0F";

  type vec_t is array (0 to 19) of integer;
  -- oraculo: 20 valores, cargado como variable en el process
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

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure wr(a : integer; d : std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a, 9)); wdata <= d;
      sel <= '1'; we <= '1'; step; sel <= '0'; we <= '0'; wait for 1 ns;
    end procedure;
    procedure rd(a : integer; res : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a, 9)); sel <= '1'; we <= '0';
      wait for 1 ns; res := rdata; step; sel <= '0';
    end procedure;

    procedure tbl(idx : integer; mac : std_logic_vector(47 downto 0);
                  prt : integer) is
    begin
      wr(16#008#, mac(31 downto 0));
      wr(16#00C#, '1' & "0000000000000" &
                    std_logic_vector(to_unsigned(prt, 2)) & mac(47 downto 32));
      wr(16#010#, std_logic_vector(to_unsigned(idx, 32)));
    end procedure;

    type frame_t is array (0 to 63) of integer;
    procedure inject(psel : integer; frm : frame_t; ln : integer) is
      variable w : std_logic_vector(31 downto 0);
      variable v : std_logic_vector(31 downto 0);
    begin
      wr(16#02C#, x"00000002");                   -- INJ clr buffer (b1)
      for wi in 0 to (ln+3)/4 - 1 loop
        w := x"00000000";
        for bidx in 0 to 3 loop
          if 4*wi+bidx < ln then
            w(8*bidx+7 downto 8*bidx) :=
              std_logic_vector(to_unsigned(frm(4*wi+bidx), 8));
          end if;
        end loop;
        wr(16#028#, w);                           -- push 4 bytes
      end loop;
      wr(16#024#, std_logic_vector(to_unsigned(ln, 32)));  -- INJ_LEN
      wr(16#020#, std_logic_vector(to_unsigned(4 + psel, 32))); -- go|psel
      loop
        rd(16#02C#, v);
        exit when v(0) = '0';
      end loop;
      -- margen fijo generoso (determinismo verificado con 4000 y 6000)
      for g in 1 to 4000 loop step; end loop;
    end procedure;

    impure function mk(dst, src : std_logic_vector(47 downto 0);
                       tag : boolean; ln : integer) return frame_t is
      variable f : frame_t := (others => 16#A5#);
    begin
      for k in 0 to 5 loop
        f(k)   := to_integer(unsigned(dst(47-8*k downto 40-8*k)));
        f(6+k) := to_integer(unsigned(src(47-8*k downto 40-8*k)));
      end loop;
      if tag then
        f(12):=16#81#; f(13):=16#00#; f(14):=16#00#; f(15):=16#64#;
        f(16):=16#08#; f(17):=16#00#;
      else
        f(12):=16#08#; f(13):=16#00#;
      end if;
      return f;
    end function;

    file fh : text;
    variable ln : line;
    variable v : std_logic_vector(31 downto 0);
    variable num, field : integer;
    variable rn : integer := 0;
    variable ok : boolean := true;
    variable orl : vec_t := (others => 0);
    constant CNT_BASE : vec_t := (16#040#,16#044#,16#048#,16#04C#,
                                  16#050#,16#054#,16#058#,16#05C#,
                                  16#060#,16#064#,16#068#,16#06C#,
                                  16#070#,16#074#,16#078#,16#07C#,
                                  16#080#,16#084#,16#088#,16#08C#);
    variable got : integer;
  begin
    file_open(fh, "iss_tsn_oracle.txt", read_mode);
    while not endfile(fh) and rn < 20 loop
      readline(fh, ln); field := 0; num := 0;
      for p in ln'range loop
        if ln(p) = ' ' then field := 1;
        elsif ln(p) >= '0' and ln(p) <= '9' and field = 1 then
          num := num*10 + (character'pos(ln(p)) - character'pos('0'));
        end if;
      end loop;
      orl(rn) := num; rn := rn + 1;
    end loop;
    file_close(fh);

    rst <= '1'; step; step; rst <= '0'; step;
    wr(16#000#, x"00000001");                 -- enable

    for p in 0 to 3 loop
      tbl(p, mac_of(p), p);
    end loop;

    inject(0, mk(mac_of(1), mac_of(0), false, 60), 60);
    inject(2, mk(mac_of(3), mac_of(2), false, 60), 60);
    inject(1, mk(MAC_BCAST, mac_of(1), false, 60), 60);
    inject(3, mk(MAC_UNK,   mac_of(3), false, 60), 60);
    inject(0, mk(mac_of(2), mac_of(0), true,  60), 60);
    inject(1, mk(mac_of(1), mac_of(1), false, 60), 60);
    inject(2, mk(mac_of(0), mac_of(2), false, 60), 60);
    inject(3, mk(MAC_BCAST, mac_of(3), false, 60), 60);

    for k in 0 to 19 loop
      rd(CNT_BASE(k), v);
      got := to_integer(unsigned(v));
      assert got = orl(k)
        report "FALLO capa4 contador " & integer'image(k) & ": rtl=" &
               integer'image(got) & " oraculo=" & integer'image(orl(k))
        severity failure;
    end loop;

    report "TB_TSN_SOC LAYER4 (RTL-vs-ISS, inyector) PASS" severity note;
    std.env.finish;
  end process;
end architecture;
