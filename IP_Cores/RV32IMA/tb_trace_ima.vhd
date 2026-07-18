-- =============================================================
-- tb_trace.vhd - Paso 4b: genera la traza del core en formato
-- canonico para el lockstep contra mini-rv32ima.
-- Muestrea el estado de ENTRADA a cada instruccion (en el primer
-- ciclo de S_FETCH), igual que el volcado -s del emulador.
-- Escribe core_trace.log con lineas:
--   PC=xxxxxxxx INSTR=xxxxxxxx R=<x0>,<x1>,...,<x31>
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.finish;

entity tb_trace is
end entity;

architecture sim of tb_trace is
  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';
  signal en   : std_logic := '1';

  signal iaddr, idata, daddr, dwdata, rdata : std_logic_vector(31 downto 0);
  signal we, re, halt, stf, stm, sts : std_logic;
  signal be : std_logic_vector(3 downto 0);
  signal dbg : std_logic_vector(1023 downto 0);

  constant NW : natural := 4096;
  type t_mem is array (0 to NW-1) of std_logic_vector(31 downto 0);

  impure function load_prog return t_mem is
    variable m : t_mem := (others => (others => '0'));
    file f     : text open read_mode is "lockstep.mem";
    variable l : line;
    variable w : std_logic_vector(31 downto 0);
    variable i : natural := 0;
  begin
    while not endfile(f) and i < NW loop
      readline(f, l); hread(l, w); m(i) := w; i := i + 1;
    end loop;
    return m;
  end function;

  signal mem : t_mem := load_prog;

  -- traduccion: el core corre desde 0x80000000; indexamos por bits [13:2]
  function idx(a : std_logic_vector(31 downto 0)) return integer is
  begin
    return to_integer(unsigned(a(13 downto 2)));
  end function;
begin

  dut : entity work.rv32ima_core
    generic map (RESET_PC => x"80000000")
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>en,
      imem_addr_o=>iaddr, imem_data_i=>idata,
      dmem_addr_o=>daddr, dmem_wdata_o=>dwdata, dmem_we_o=>we,
      dmem_re_o=>re, dmem_be_o=>be, dmem_rdata_i=>rdata, halt_o=>halt,
      st_fetch_o=>stf, st_mem_o=>stm, st_store_o=>sts, dbg_regs_o=>dbg);

  -- memoria combinacional latencia-cero (semantica pura del core)
  idata <= mem(idx(iaddr)) when iaddr(31)='1' else (others=>'0');
  -- modelo minimo del LSR del UART (0x10000004..7): THRE y TEMT siempre
  -- listos, en el lane 1 de su palabra. Necesario para que los programas
  -- que esperan THRE no giren en vacio en este arnes de traza.
  rdata <= x"00006000" when (daddr and x"FFFFFFFC") = x"10000004"
      else mem(idx(daddr)) when daddr(31)='1'
      else (others=>'0');

  process(clk)
  begin
    if rising_edge(clk) then
      if en='1' and we='1' and daddr(31)='1' then
        -- syscon poweroff: no escribir a RAM
        if daddr /= x"11100000" then
          -- respetar byte-enables por lane individual
          if be(0)='1' then mem(idx(daddr))(7 downto 0)   <= dwdata(7 downto 0);   end if;
          if be(1)='1' then mem(idx(daddr))(15 downto 8)  <= dwdata(15 downto 8);  end if;
          if be(2)='1' then mem(idx(daddr))(23 downto 16) <= dwdata(23 downto 16); end if;
          if be(3)='1' then mem(idx(daddr))(31 downto 24) <= dwdata(31 downto 24); end if;
        end if;
      end if;
    end if;
  end process;

  clk <= not clk after 5 ns;

  trace_proc : process
    file fo        : text open write_mode is "core_trace.log";
    variable l     : line;
    variable last_pc : std_logic_vector(31 downto 0) := (others => '1');
    variable steps : integer := 0;
    variable poweroff : boolean := false;
  begin
    -- subir rstn en flanco de bajada para que el primer S_FETCH (PC de
    -- reset) sea observable en el primer rising_edge del loop.
    wait until falling_edge(clk);
    rstn <= '1';
    loop
      wait until rising_edge(clk);
      wait for 1 ns;
      -- capturar cuando el core esta en S_FETCH y el PC cambio respecto al
      -- ultimo capturado: una muestra por instruccion, robusto al timing.
      if stf = '1' and iaddr /= last_pc then
        write(l, string'("PC="));
        hwrite(l, iaddr);
        write(l, string'(" INSTR="));
        hwrite(l, idata);
        write(l, string'(" R="));
        for i in 0 to 31 loop
          hwrite(l, dbg(i*32+31 downto i*32));
          if i < 31 then write(l, string'(",")); end if;
        end loop;
        writeline(fo, l);
        steps := steps + 1;
        last_pc := iaddr;
      end if;

      -- deteccion de poweroff: store a 0x11100000 con 0x5555
      if en='1' and we='1' and daddr = x"11100000" and dwdata = x"00005555" then
        poweroff := true;
      end if;

      exit when poweroff or halt = '1' or steps > 500;
    end loop;
    report "CORE TRACE: " & integer'image(steps) & " pasos escritos" severity note;
    finish;
  end process;

end architecture;
