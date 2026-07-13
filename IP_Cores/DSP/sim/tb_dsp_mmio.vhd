-------------------------------------------------------------------------------
-- tb_dsp_mmio.vhd  --  Layer 2: contrato MMIO del IP DSP.
-- Verifica: ID, decode de registros, rdata COMBINACIONAL, START->BUSY->DONE
-- sticky, W1C, ventanas COEF y DATA, y una operacion CORDIC completa via MMIO
-- comparada contra el oraculo (leida de tb_cordic.mem).
--
-- Pass: fin determinista con "MMIO OK" y errores=0.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_dsp_mmio is
end entity;

architecture sim of tb_dsp_mmio is
  constant CLK_P : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal req : std_logic := '0';
  signal addr: std_logic_vector(15 downto 0) := (others=>'0');
  signal wdata: std_logic_vector(31 downto 0) := (others=>'0');
  signal wstrb: std_logic_vector(3 downto 0) := (others=>'0');
  signal rdata: std_logic_vector(31 downto 0);
  signal ready: std_logic;
  signal sim_done : boolean := false;
  signal errors : integer := 0;

  procedure step(signal clk : in std_logic) is
  begin
    wait until rising_edge(clk);
  end procedure;
begin

  dut : entity work.dsp_mmio
    port map (clk=>clk, rst=>rst, req=>req, addr=>addr,
              wdata=>wdata, wstrb=>wstrb, rdata=>rdata, ready=>ready);

  clk <= not clk after CLK_P/2 when not sim_done else '0';

  stim : process
    variable rv : std_logic_vector(31 downto 0);
    variable ac : integer;
    variable exp_cos, exp_sin : std_logic_vector(15 downto 0);
    file fh : text open read_mode is "tb_cordic.mem";
    variable ln : line;
    variable vmd : integer;
    variable vx,vy,vz,vcos,vsin,vzz : std_logic_vector(15 downto 0);

    -- escritura MMIO de 1 ciclo
    procedure mmio_wr(a : std_logic_vector(15 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      addr<=a; wdata<=d; wstrb<="1111"; req<='1';
      wait until rising_edge(clk);
      req<='0'; wstrb<="0000";
      wait until rising_edge(clk);   -- ciclo de asentamiento (escritura BRAM DATA)
    end procedure;
    -- lectura MMIO combinacional: rdata valido en el mismo ciclo de req
    procedure mmio_rd(a : std_logic_vector(15 downto 0); v : out std_logic_vector(31 downto 0)) is
    begin
      addr<=a; req<='1'; wstrb<="0000";
      -- respetar ready: control es inmediato (ready='1' ya), DATA tiene wait-state
      wait for 1 ns;
      if ready='1' then
        v := rdata;
        wait until rising_edge(clk);
      else
        loop
          wait until rising_edge(clk);
          exit when ready='1';
        end loop;
        wait for 1 ns; v := rdata;
      end if;
      req<='0';
    end procedure;

    procedure chk(cond : boolean; msg : string) is
    begin
      if not cond then
        errors <= errors + 1;
        report "FALLO: " & msg severity warning;
      end if;
    end procedure;
  begin
    rst<='1'; wait for 4*CLK_P; rst<='0'; wait for 2*CLK_P;

    -- 1) ID
    mmio_rd(x"0000", rv);
    chk(rv = x"D5B10100", "ID incorrecto got=" & to_hstring(rv));

    -- 2) rdata COMBINACIONAL: escribir LOG2N y leer sin flanco intermedio
    mmio_wr(x"000C", x"0000000A");
    mmio_rd(x"000C", rv);
    chk(rv = x"0000000A", "LOG2N RW/comb got=" & to_hstring(rv));

    -- 3) ventana COEF: escribir y releer
    mmio_wr(x"0080", x"00001234");   -- coef[0]
    mmio_wr(x"0084", x"00005678");   -- coef[1]
    mmio_rd(x"0080", rv); chk(rv=x"00001234", "COEF0 got="&to_hstring(rv));
    mmio_rd(x"0084", rv); chk(rv=x"00005678", "COEF1 got="&to_hstring(rv));

    -- 4) ventana DATA: escribir y releer
    mmio_wr(x"1000", x"DEAD0001");
    mmio_wr(x"1FFC", x"BEEF03FF");   -- ultima palabra (idx 1023)
    mmio_rd(x"1000", rv); chk(rv=x"DEAD0001", "DATA0 got="&to_hstring(rv));
    mmio_rd(x"1FFC", rv); chk(rv=x"BEEF03FF", "DATA1023 got="&to_hstring(rv));

    -- 5) operacion CORDIC completa via MMIO, comparada al oraculo
    -- leer un caso de rotacion del .mem (mode=0)
    readline(fh, ln);
    read(ln, vmd); hread(ln,vx); hread(ln,vy); hread(ln,vz);
    hread(ln,vcos); hread(ln,vsin); hread(ln,vzz);
    -- escribir angulo en CORDIC_A y lanzar FUNC=011 (CORDIC_rot), START
    mmio_wr(x"0014", x"0000" & vz);
    mmio_wr(x"0004", x"00000007");   -- bit0=START, FUNC=011
    -- poll BUSY->DONE
    for w in 0 to 63 loop
      mmio_rd(x"0008", rv);
      exit when rv(1)='1';           -- DONE sticky
    end loop;
    chk(rv(1)='1', "CORDIC DONE no se activo");
    -- leer resultados
    mmio_rd(x"001C", rv); chk(rv(15 downto 0)=vcos, "cos got="&to_hstring(rv(15 downto 0))&" exp="&to_hstring(vcos));
    mmio_rd(x"0020", rv); chk(rv(15 downto 0)=vsin, "sin got="&to_hstring(rv(15 downto 0))&" exp="&to_hstring(vsin));

    -- 6) W1C sobre DONE
    mmio_wr(x"0008", x"00000002");   -- W1C bit1
    mmio_rd(x"0008", rv); chk(rv(1)='0', "DONE no se limpio con W1C");

    file_close(fh);
    wait until rising_edge(clk);
    report "MMIO errores=" & integer'image(errors);
    assert errors=0 report "MUTANTE VIVO / contrato roto: "&integer'image(errors)&" fallos" severity failure;
    report "MMIO OK - contrato de registros y CORDIC via MMIO correctos";
    sim_done<=true; wait;
  end process;
end architecture;
