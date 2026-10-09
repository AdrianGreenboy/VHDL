-------------------------------------------------------------------------------
-- HERCOSSNUX Core 21 - ETH GT
-- Capa 1C: umbrales del block lock (cl. 49, fig. 49-14):
--   a) sin lock: 63 validas no bastan, la 64 da lock
--   b) sin lock: una invalida -> slip (pulso de 1 ciclo) y espera SLIP_WAIT
--   c) con lock: 15 invalidas en una ventana de 64 no pierden el lock
--   d) con lock: 16 invalidas en una ventana pierden el lock (y slip)
--   e) las ventanas se reinician cada 64: 15 + 15 en ventanas distintas no
--      pierden el lock
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_eth21_bl is
end entity tb_eth21_bl;

architecture sim of tb_eth21_bl is
  constant SW : natural := 10;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal v : std_logic := '0';
  signal h : std_logic_vector(1 downto 0) := "01";
  signal slip, lock, eb, es, el : std_logic;
  signal nslip : natural := 0;
  signal fin : boolean := false;
  signal errs : natural := 0;
begin
  clk <= not clk after 2 ns when not fin;

  dut: entity work.eth21_blocklock
    generic map (SLIP_WAIT => SW)
    port map (clk=>clk, rst=>rst, in_valid=>v, in_header=>h, slip=>slip, lock=>lock,
              ev_badsh=>eb, ev_slip=>es, ev_lost=>el);

  process(clk)
  begin
    if rising_edge(clk) then
      if slip = '1' then nslip <= nslip + 1; end if;
    end if;
  end process;

  process
    variable e : natural := 0;
    procedure blk(good : boolean) is
    begin
      v <= '1';
      if good then h <= "10"; else h <= "11"; end if;
      wait until rising_edge(clk);
      v <= '0';
    end procedure;
    procedure idle(k : natural) is
    begin
      for i in 1 to k loop wait until rising_edge(clk); end loop;
    end procedure;
    procedure expect(c : boolean; msg : string) is
    begin
      if not c then report "FALLO: " & msg severity error; e := e + 1; end if;
    end procedure;
  begin
    idle(3); rst <= '0'; idle(1);
    -- a)
    for i in 1 to 63 loop blk(true); end loop;
    idle(1); expect(lock = '0', "lock con 63");
    blk(true); idle(1); expect(lock = '1', "sin lock con 64");
    -- c) 15 invalidas dentro de una ventana
    for i in 1 to 15 loop blk(false); blk(true); end loop;
    for i in 1 to 40 loop blk(true); end loop;
    idle(1); expect(lock = '1', "lock perdido con 15");
    -- e) 15 en esta ventana y 15 en la siguiente
    for i in 1 to 15 loop blk(false); end loop;
    for i in 1 to 64 loop blk(true); end loop;
    for i in 1 to 15 loop blk(false); end loop;
    for i in 1 to 30 loop blk(true); end loop;
    idle(1); expect(lock = '1', "lock perdido con 15+15 en ventanas distintas");
    expect(nslip = 0, "slip con lock");
    -- d) 16 invalidas
    for i in 1 to 16 loop blk(false); end loop;
    idle(1); expect(lock = '0', "lock no perdido con 16");
    idle(SW + 2); expect(nslip = 1, "un slip al perder el lock");
    -- b) sin lock: invalida -> slip; entradas ignoradas durante la espera
    for i in 1 to 10 loop blk(true); end loop;
    blk(false); idle(2); expect(nslip = 2, "slip por invalida sin lock");
    for i in 1 to SW - 2 loop blk(false); end loop;      -- ignoradas
    idle(3); expect(nslip = 2, "slip durante la espera");
    for i in 1 to 64 loop blk(true); end loop;
    idle(1); expect(lock = '1', "sin relock");
    if e = 0 then report "LAYER1C BLOCKLOCK PASS";
    else report "LAYER1C BLOCKLOCK FAIL" severity error; end if;
    fin <= true; wait;
  end process;
end architecture sim;
