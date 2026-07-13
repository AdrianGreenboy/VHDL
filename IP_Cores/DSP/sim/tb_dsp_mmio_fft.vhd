-------------------------------------------------------------------------------
-- tb_dsp_mmio_fft.vhd  --  Layer 2b: FFT completa via MMIO.
-- Carga el buffer DATA por MMIO, lanza FFT (FUNC=000/001), espera DONE,
-- relee DATA y compara contra el oraculo (tb_fft_mmio.mem).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_dsp_mmio_fft is
end entity;

architecture sim of tb_dsp_mmio_fft is
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
    file fh : text open read_mode is "tb_fft_mmio.mem";
    variable ln : line;
    variable ncases, l2, invf, n : integer;
    variable tag : string(1 to 4);
    variable inw, outw : std_logic_vector(31 downto 0);

    procedure mmio_wr(a : std_logic_vector(15 downto 0); d : std_logic_vector(31 downto 0)) is
    begin
      addr<=a; wdata<=d; wstrb<="1111"; req<='1';
      wait until rising_edge(clk); req<='0'; wstrb<="0000";
    end procedure;
    procedure mmio_rd(a : std_logic_vector(15 downto 0); v : out std_logic_vector(31 downto 0)) is
    begin
      addr<=a; req<='1'; wstrb<="0000";
      -- respetar el handshake ready (como el core real): esperar ready=1.
      -- para registros de control ready es inmediato; para ventana DATA hay
      -- wait-state (BRAM registrada).
      loop
        wait until rising_edge(clk);
        exit when ready='1';
      end loop;
      wait for 1 ns; v := rdata;
      req<='0';
    end procedure;
  begin
    rst<='1'; wait for 4*CLK_P; rst<='0'; wait for 2*CLK_P;
    readline(fh, ln); read(ln, ncases);

    for c in 0 to ncases-1 loop
      readline(fh, ln); read(ln,tag); read(ln,l2); read(ln,invf); read(ln,n);

      -- cargar DATA[0..n-1] por MMIO y guardar esperado
      for t in 0 to n-1 loop
        readline(fh, ln); hread(ln,inw); hread(ln,outw);
        mmio_wr(std_logic_vector(to_unsigned(16#1000# + t*4, 16)), inw);
        exp_out(t) <= outw;
      end loop;

      -- LOG2N
      mmio_wr(x"000C", std_logic_vector(to_unsigned(l2,32)));
      -- START con FUNC (000 fwd / 001 inv): CTRL = START | FUNC<<1
      if invf=0 then
        mmio_wr(x"0004", x"00000001");   -- START, FUNC=000
      else
        mmio_wr(x"0004", x"00000003");   -- START, FUNC=001
      end if;

      -- poll DONE (FFT 1024 ~ 10k+ ciclos)
      for w in 0 to 400000 loop
        mmio_rd(x"0008", rv);
        exit when rv(1)='1';
      end loop;
      assert rv(1)='1' report "TIMEOUT FFT c="&integer'image(c) severity failure;

      -- releer DATA y comparar
      for t in 0 to n-1 loop
        mmio_rd(std_logic_vector(to_unsigned(16#1000# + t*4, 16)), rv);
        if rv /= exp_out(t) then
          errors <= errors + 1;
          if errors <= 6 then
            report "FFT-MMIO mismatch c="&integer'image(c)&" k="&integer'image(t)&
              " got="&to_hstring(rv)&" exp="&to_hstring(exp_out(t)) severity warning;
          end if;
        end if;
      end loop;

      -- limpiar DONE (W1C)
      mmio_wr(x"0008", x"00000002");
    end loop;

    file_close(fh);
    wait until rising_edge(clk);
    report "FFT-MMIO errores="&integer'image(errors);
    assert errors=0 report "MUTANTE VIVO: "&integer'image(errors)&" mismatches" severity failure;
    report "FFT-MMIO OK - FFT completa via MMIO bit-exacta";
    sim_done<=true; wait;
  end process;
end architecture;
