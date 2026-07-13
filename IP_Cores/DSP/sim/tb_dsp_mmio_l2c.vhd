-------------------------------------------------------------------------------
-- tb_dsp_mmio_l2c.vhd  --  Layer 2c: FIR modo bloque y FFT real-empacada via MMIO
-- Lee tb_fir_mmio.mem y tb_rp_mmio.mem. Carga DATA/COEF/DATA_LEN por MMIO,
-- lanza la operacion, espera DONE, relee DATA y compara bit-exacto.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_dsp_mmio_l2c is
end entity;

architecture sim of tb_dsp_mmio_l2c is
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

  type mem_t is array (0 to 1023) of std_logic_vector(31 downto 0);
  signal exp_out : mem_t;
begin
  dut : entity work.dsp_mmio
    port map (clk=>clk, rst=>rst, req=>req, addr=>addr,
              wdata=>wdata, wstrb=>wstrb, rdata=>rdata, ready=>ready);
  clk <= not clk after CLK_P/2 when not sim_done else '0';

  stim : process
    variable rv : std_logic_vector(31 downto 0);
    variable ln : line;
    variable ncases, L, M, l2n2, n2, n : integer;
    variable tag : string(1 to 4);
    variable w1, w2 : std_logic_vector(31 downto 0);
    variable cval : std_logic_vector(15 downto 0);
    file fh  : text open read_mode is "tb_fir_mmio.mem";
    file fh2 : text open read_mode is "tb_rp_mmio.mem";

    procedure mmio_wr(a : std_logic_vector(15 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      addr<=a; wdata<=d; wstrb<="1111"; req<='1';
      wait until rising_edge(clk); req<='0'; wstrb<="0000";
    end procedure;
    procedure mmio_rd(a : std_logic_vector(15 downto 0); v : out std_logic_vector(31 downto 0)) is
    begin
      addr<=a; req<='1'; wstrb<="0000";
      loop
        wait until rising_edge(clk);
        exit when ready='1';
      end loop;
      wait for 1 ns; v := rdata;
      req<='0';
    end procedure;
  begin
    rst<='1'; wait for 4*CLK_P; rst<='0'; wait for 2*CLK_P;

    -----------------------------------------------------------------------
    -- PARTE 1: FIR modo bloque
    -----------------------------------------------------------------------
    readline(fh, ln); read(ln, ncases);
    for c in 0 to ncases-1 loop
      readline(fh, ln); read(ln,tag); read(ln,L); read(ln,M);
      -- cargar 32 coeficientes
      for k in 0 to 31 loop
        readline(fh, ln); hread(ln, cval);
        mmio_wr(std_logic_vector(to_unsigned(16#80# + k*4,16)), x"0000" & cval);
      end loop;
      -- cargar M muestras y guardar esperado
      for t in 0 to M-1 loop
        readline(fh, ln); hread(ln,w1); hread(ln,w2);
        mmio_wr(std_logic_vector(to_unsigned(16#1000# + t*4,16)), w1);
        exp_out(t) <= w2;
      end loop;
      mmio_wr(x"0010", std_logic_vector(to_unsigned(L,32)));   -- FIR_LEN
      mmio_wr(x"0024", std_logic_vector(to_unsigned(M,32)));   -- DATA_LEN
      mmio_wr(x"0004", x"00000005");   -- START, FUNC=010 (FIR)
      for w in 0 to 200000 loop
        mmio_rd(x"0008", rv); exit when rv(1)='1';
      end loop;
      assert rv(1)='1' report "TIMEOUT FIR c="&integer'image(c) severity failure;
      for t in 0 to M-1 loop
        mmio_rd(std_logic_vector(to_unsigned(16#1000# + t*4,16)), rv);
        if rv /= exp_out(t) then
          errors <= errors+1;
          if errors<=6 then
            report "FIR-blk mismatch c="&integer'image(c)&" n="&integer'image(t)&
              " got="&to_hstring(rv)&" exp="&to_hstring(exp_out(t)) severity warning;
          end if;
        end if;
      end loop;
      mmio_wr(x"0008", x"00000002");   -- W1C DONE
    end loop;
    file_close(fh);

    -----------------------------------------------------------------------
    -- PARTE 2: FFT real-empacada
    -----------------------------------------------------------------------
    readline(fh2, ln); read(ln, ncases);
    for c in 0 to ncases-1 loop
      readline(fh2, ln); read(ln,tag); read(ln,l2n2); read(ln,n2); read(ln,n);
      -- cargar 2N muestras reales
      for t in 0 to n2-1 loop
        readline(fh2, ln); hread(ln,w1);
        mmio_wr(std_logic_vector(to_unsigned(16#1000# + t*4,16)), w1);
      end loop;
      -- guardar esperado X[0..N]
      for t in 0 to n loop
        readline(fh2, ln); hread(ln,w1);
        exp_out(t) <= w1;
      end loop;
      mmio_wr(x"000C", std_logic_vector(to_unsigned(l2n2,32)));  -- LOG2N=log2(2N)
      mmio_wr(x"0024", std_logic_vector(to_unsigned(n2,32)));    -- DATA_LEN=2N
      mmio_wr(x"0004", x"00000011");   -- START, FUNC=000, REAL_PACK(bit4)=1
      for w in 0 to 400000 loop
        mmio_rd(x"0008", rv); exit when rv(1)='1';
      end loop;
      assert rv(1)='1' report "TIMEOUT RP c="&integer'image(c) severity failure;
      for t in 0 to n loop
        mmio_rd(std_logic_vector(to_unsigned(16#1000# + t*4,16)), rv);
        if rv /= exp_out(t) then
          errors <= errors+1;
          if errors<=6 then
            report "RP mismatch c="&integer'image(c)&" k="&integer'image(t)&
              " got="&to_hstring(rv)&" exp="&to_hstring(exp_out(t)) severity warning;
          end if;
        end if;
      end loop;
      mmio_wr(x"0008", x"00000002");
    end loop;
    file_close(fh2);

    wait until rising_edge(clk);
    report "L2C errores="&integer'image(errors);
    assert errors=0 report "MUTANTE VIVO: "&integer'image(errors)&" mismatches" severity failure;
    report "L2C OK - FIR bloque y FFT real-empacada via MMIO bit-exactas";
    sim_done<=true; wait;
  end process;
end architecture;
