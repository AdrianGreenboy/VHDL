-- =============================================================================
--  tb_accel_pipe.vhd  -  GEMV en el SoC pipeline, esperando por INTERRUPCION
--  Licencia: MIT
--
--  Valida las tres iteraciones juntas: core pipeline + acelerador GEMV +
--  interrupcion. Carga accel_gemv.mem, escribe A (3x3) y x en DMEM, arranca el
--  core, y ESPERA a que irq_out se active (en vez de hacer polling). Luego lee
--  y = A*x, verifica [6,15,24], limpia el IRQ y comprueba que se desactiva.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.riscv_pkg.all;

entity tb_accel_pipe is
end entity tb_accel_pipe;

architecture sim of tb_accel_pipe is
  constant TCK : time := 10 ns;
  constant AW  : natural := 16;

  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal awaddr  : std_logic_vector(AW-1 downto 0) := (others => '0');
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb   : std_logic_vector(3 downto 0) := "1111";
  signal wvalid  : std_logic := '0';
  signal wready  : std_logic;
  signal bresp   : std_logic_vector(1 downto 0);
  signal bvalid  : std_logic;
  signal bready  : std_logic := '0';
  signal araddr  : std_logic_vector(AW-1 downto 0) := (others => '0');
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rvalid  : std_logic;
  signal rready  : std_logic := '0';
  signal irq     : std_logic;

  constant ADDR_CONTROL : integer := 16#0000#;
  constant ADDR_IRQ     : integer := 16#000C#;
  constant BASE_IMEM    : integer := 16#1000#;
  constant BASE_DMEM    : integer := 16#2000#;

  type int_arr is array (natural range <>) of integer;
  -- A = [[1,2,3],[4,5,6],[7,8,9]] row-major, luego x = [1,1,1]
  constant A_AND_X : int_arr := (1,2,3, 4,5,6, 7,8,9,  1,1,1);
begin

  aclk <= not aclk after TCK/2;

  dut : entity work.soc_top_pipe
    generic map (ADDR_W => AW, DEPTH => 256)
    port map (
      aclk => aclk, aresetn => aresetn,
      s_axi_awaddr => awaddr, s_axi_awvalid => awvalid, s_axi_awready => awready,
      s_axi_wdata => wdata, s_axi_wstrb => wstrb, s_axi_wvalid => wvalid, s_axi_wready => wready,
      s_axi_bresp => bresp, s_axi_bvalid => bvalid, s_axi_bready => bready,
      s_axi_araddr => araddr, s_axi_arvalid => arvalid, s_axi_arready => arready,
      s_axi_rdata => rdata, s_axi_rresp => rresp, s_axi_rvalid => rvalid, s_axi_rready => rready,
      irq_out => irq
    );

  stim : process
    variable errors : natural := 0;
    variable l      : line;
    variable w      : word_t;
    variable i      : natural;
    file     fprog  : text;
    variable fstat  : file_open_status;
    variable rd_v   : std_logic_vector(31 downto 0);

    procedure axi_write (constant a : integer; constant data : std_logic_vector(31 downto 0)) is
    begin
      awaddr <= std_logic_vector(to_unsigned(a, AW));
      wdata <= data; wstrb <= "1111"; awvalid <= '1'; wvalid <= '1'; bready <= '1';
      loop wait until rising_edge(aclk); exit when awready = '1'; end loop;
      awvalid <= '0'; wvalid <= '0';
      loop wait until rising_edge(aclk); exit when bvalid = '1'; end loop;
      bready <= '0';
    end procedure;

    procedure axi_read (constant a : integer; variable data : out std_logic_vector(31 downto 0)) is
    begin
      araddr <= std_logic_vector(to_unsigned(a, AW)); arvalid <= '1'; rready <= '1';
      loop wait until rising_edge(aclk); exit when arready = '1'; end loop;
      arvalid <= '0';
      loop wait until rising_edge(aclk); exit when rvalid = '1'; end loop;
      data := rdata; rready <= '0';
    end procedure;

    procedure check (constant got, exp : integer; constant name : string) is
    begin
      if got = exp then
        report "PASS " & name severity note;
      else
        report "FAIL " & name & " got=" & integer'image(got) &
               " exp=" & integer'image(exp) severity error;
        errors := errors + 1;
      end if;
    end procedure;

  begin
    aresetn <= '0';
    wait for 5*TCK;
    wait until rising_edge(aclk);
    aresetn <= '1';
    wait until rising_edge(aclk);

    -- carga el acelerador GEMV en IMEM (core detenido)
    file_open(fstat, fprog, "accel_gemv.mem", read_mode);
    assert fstat = open_ok report "no se pudo abrir accel_gemv.mem" severity failure;
    i := 0;
    while not endfile(fprog) loop
      readline(fprog, l);
      if l'length > 0 then hread(l, w); axi_write(BASE_IMEM + i*4, w); i := i + 1; end if;
    end loop;
    file_close(fprog);

    -- entradas: M=3, N=3, luego A y x
    axi_write(BASE_DMEM + 0*4, x"00000003");   -- M
    axi_write(BASE_DMEM + 1*4, x"00000003");   -- N
    for k in A_AND_X'range loop
      axi_write(BASE_DMEM + (2 + k)*4, std_logic_vector(to_unsigned(A_AND_X(k), 32)));
    end loop;

    -- arranca el core
    axi_write(ADDR_CONTROL, x"00000000");

    -- ESPERA POR INTERRUPCION (no polling)
    loop wait until rising_edge(aclk); exit when irq = '1'; end loop;
    report "IRQ recibida del core" severity note;

    -- detiene el core y lee y = A*x  (palabras 64,65,66)
    axi_write(ADDR_CONTROL, x"00000001");
    axi_read(BASE_DMEM + 64*4, rd_v);  check(to_integer(unsigned(rd_v)),  6, "y[0] = 6");
    axi_read(BASE_DMEM + 65*4, rd_v);  check(to_integer(unsigned(rd_v)), 15, "y[1] = 15");
    axi_read(BASE_DMEM + 66*4, rd_v);  check(to_integer(unsigned(rd_v)), 24, "y[2] = 24");

    -- limpia el IRQ (write-1-to-clear) y verifica que se desactiva
    axi_write(ADDR_IRQ, x"00000001");
    wait until rising_edge(aclk);
    wait until rising_edge(aclk);
    if irq = '0' then
      report "PASS IRQ limpiada" severity note;
    else
      report "FAIL IRQ no se limpio" severity error;
      errors := errors + 1;
    end if;

    report "-----------------------------------------";
    if errors = 0 then
      report "GEMV + PIPELINE + INTERRUPCION: TODO OK" severity note;
    else
      report integer'image(errors) & " TEST(S) FALLARON" severity error;
    end if;
    report "-----------------------------------------";
    std.env.finish;
  end process;

end architecture sim;
