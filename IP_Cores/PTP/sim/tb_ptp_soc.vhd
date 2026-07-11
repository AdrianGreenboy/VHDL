-- tb_ptp_soc.vhd — capa 4: RTL-vs-ISS oraculo por MMIO (Sync + Pdelay + esclavo).
-- Aplica al ptp_top la MISMA secuencia que iss_ptp.py y compara cada lectura
-- con ptp_soc_oracle.txt (formato "reg valor"). Los campos de estado (STATUS,
-- MPD, OFFSET) se comparan bit-identico; el reloj por coherencia.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ptp_pkg.all;

entity tb_ptp_soc is
end entity;

architecture sim of tb_ptp_soc is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal done : boolean := false;
  constant TCK : time := 10 ns;
  signal sel, we : std_logic := '0';
  signal addr : std_logic_vector(5 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others => '0');
  signal irq : std_logic;
  signal mii_txd : std_logic_vector(3 downto 0);
  signal mii_tx_en : std_logic;

  constant CTRL:integer:=0; constant SERVO:integer:=1; constant CMD:integer:=3;
  constant CLKIDH:integer:=4; constant CLKIDL:integer:=5;
  constant STATUS:integer:=9; constant NOWSEC:integer:=10; constant NOWNS:integer:=11;
  constant MPDLO:integer:=12; constant MPDHI:integer:=13; constant OFFSET:integer:=14;
  constant IRQEN:integer:=16;

  -- oraculo cargado
  type int_arr is array (0 to 31) of integer;
  signal orl_reg, orl_val : int_arr := (others => 0);
  signal orl_n : integer := 0;
begin
  clk <= not clk after TCK/2 when not done else '0';

  dut : entity work.ptp_top
    generic map (SHIFT_P => 8, SHIFT_I => 12)
    port map (clk => clk, rst => rst, sel => sel, we => we, addr => addr,
              wdata => wdata, rdata => rdata, irq => irq,
              mii_txd => mii_txd, mii_tx_en => mii_tx_en,
              mii_rxd => (others => '0'), mii_rx_dv => '0');

  stim : process
    procedure step is begin wait until rising_edge(clk); end procedure;
    procedure wr(a : integer; d : std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a,6)); wdata <= d; sel<='1'; we<='1';
      step; sel<='0'; we<='0'; wait for 1 ns;
    end procedure;
    procedure rd(a : integer; result : out std_logic_vector(31 downto 0)) is
    begin
      addr <= std_logic_vector(to_unsigned(a,6)); sel<='1'; we<='0';
      wait for 1 ns; result := rdata; step; sel<='0';
    end procedure;

    file fh : text;
    variable ln : line;
    variable v : std_logic_vector(31 downto 0);
    variable c : character;
    variable field, num, ri : integer;
    variable rr, rv : int_arr;
    variable rn : integer := 0;

    -- comparar una lectura contra la siguiente entrada del oraculo
    variable oi : integer := 0;
    procedure check(a : integer; got : integer; exact : boolean; tag : string) is
    begin
      assert rr(oi) = a
        report "FALLO capa4: desalineacion oraculo en " & tag &
               " (reg rtl=" & integer'image(a) & " oraculo=" & integer'image(rr(oi)) & ")"
        severity failure;
      if exact then
        assert got = rv(oi)
          report "FALLO capa4 " & tag & ": rtl=" & integer'image(got) &
                 " oraculo=" & integer'image(rv(oi)) severity failure;
        report "OK capa4 " & tag & " bit-identico: " & integer'image(got);
      else
        assert got > 0
          report "FALLO capa4 " & tag & ": valor no coherente (" & integer'image(got) & ")"
          severity failure;
        report "OK capa4 " & tag & " coherente: " & integer'image(got);
      end if;
      oi := oi + 1;
    end procedure;
  begin
    -- cargar oraculo
    file_open(fh, "ptp_soc_oracle.txt", read_mode);
    while not endfile(fh) loop
      readline(fh, ln); field:=0; num:=0; ri:=0;
      for p in ln'range loop
        c := ln(p);
        if c = ' ' then
          if field=0 then ri:=num; end if; field:=field+1; num:=0;
        elsif c >= '0' and c <= '9' then num:=num*10+(character'pos(c)-character'pos('0'));
        end if;
      end loop;
      rr(rn):=ri; rv(rn):=num; rn:=rn+1;
    end loop;
    file_close(fh);

    rst <= '1'; step; step; rst <= '0';

    -- ==== Sync ====
    wr(CTRL, x"00000006"); wr(SERVO, x"00400010");
    wr(CLKIDH, x"00112233"); wr(CLKIDL, x"44556677");
    wr(IRQEN, x"00000001"); wr(STATUS, x"0000000F");
    wr(CMD, x"00000001");
    for i in 1 to 4000 loop step; end loop;
    rd(STATUS, v); check(STATUS, to_integer(unsigned(v)), true, "Sync.STATUS");
    rd(NOWSEC, v); check(NOWSEC, to_integer(unsigned(v)), true, "Sync.NOWSEC");
    rd(NOWNS, v);  check(NOWNS,  to_integer(unsigned(v)), false, "Sync.NOWNS");

    -- ==== peer-delay ====
    wr(STATUS, x"0000000F");
    wr(CMD, x"00000002");
    for i in 1 to 6000 loop step; end loop;
    rd(STATUS, v); check(STATUS, to_integer(unsigned(v)), true, "Pdelay.STATUS");
    rd(MPDLO, v);  check(MPDLO,  to_integer(unsigned(v)), true, "Pdelay.MPD_LO");
    rd(MPDHI, v);  check(MPDHI,  to_integer(unsigned(v)), true, "Pdelay.MPD_HI");

    -- ==== esclavo ====
    wr(CTRL, x"00000007"); wr(STATUS, x"0000000F");
    wr(CMD, x"00000001");
    for i in 1 to 4000 loop step; end loop;
    rd(STATUS, v); check(STATUS, to_integer(unsigned(v)), true, "Slave.STATUS");
    rd(OFFSET, v); check(OFFSET, to_integer(unsigned(v)), true, "Slave.OFFSET");

    report "=== PTP_SOC LAYER 4 (RTL-vs-ISS, Sync+Pdelay+esclavo) PASS ===";
    done <= true;
    wait;
  end process;

end architecture sim;
