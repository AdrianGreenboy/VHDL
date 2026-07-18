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
  generic (MAX_STEPS : natural := 20000);
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
  -- modelo minimo del CLINT para el lockstep de interrupciones: mtime
  -- avanza 1 por instruccion retirada (igual que el ISS de referencia).
  signal mtime_r    : unsigned(63 downto 0) := (others => '0');
  signal mtimecmp_r : unsigned(63 downto 0) := (others => '1');
  signal mtip_r     : std_logic := '0';
  signal irq_taken  : std_logic;
  signal irq_pc     : std_logic_vector(31 downto 0);

  -- traduccion: el core corre desde 0x80000000; indexamos por bits [13:2]
  function idx(a : std_logic_vector(31 downto 0)) return integer is
  begin
    return to_integer(unsigned(a(13 downto 2)));
  end function;
begin

  -- El ISS incrementa mtime ANTES de evaluar la interrupcion de cada
  -- instruccion. Aqui mtime_r se actualiza al retirar la instruccion
  -- anterior, asi que el valor vigente para la instruccion en curso es
  -- mtime_r + 1. Comparamos con ese para que ambos modelos crucen el
  -- umbral en la MISMA instruccion.
  mtip_r <= '1' when (mtime_r + 1) >= mtimecmp_r else '0';

  -- CLINT del arnes: mtime avanza 1 por instruccion retirada, para que el
  -- instante de disparo coincida con el ISS de referencia.
  -- Traza de eventos de interrupcion para el lockstep guiado: registra el
  -- indice de instruccion (contando limites de instruccion) en el que el
  -- core tomo cada interrupcion. El ISS la consume para disparar en los
  -- mismos puntos, sin que ambos tengan que modelar el tiempo igual.
  -- traza de lecturas de mtime: el ISS las consume en orden para ver el
  -- mismo tiempo que el core, en vez de modelar su propio contador.
  mtime_log : process(clk)
    file fm     : text open write_mode is "mtime_reads.log";
    variable lm : line;
    variable served : std_logic := '0';
  begin
    if rising_edge(clk) then
      if re = '1' and daddr = x"1100BFF8" and served = '0' then
        hwrite(lm, std_logic_vector(mtime_r(31 downto 0)));
        writeline(fm, lm);
        served := '1';
      elsif re = '0' then
        served := '0';
      end if;
    end if;
  end process;

  clint_model : process(clk)
    variable prev_fetch : std_logic := '0';
  begin
    if rising_edge(clk) then
      -- una instruccion retirada = un paso de mtime (igual que el ISS)
      if prev_fetch = '1' and stf = '0' then
        mtime_r <= mtime_r + 1;
      end if;
      prev_fetch := stf;
      if we = '1' then
        if daddr = x"11004000" then
          mtimecmp_r(31 downto 0) <= unsigned(dwdata);
        elsif daddr = x"11004004" then
          mtimecmp_r(63 downto 32) <= unsigned(dwdata);
        end if;
      end if;
    end if;
  end process;

  dut : entity work.rv32ima_core
    generic map (RESET_PC => x"80000000")
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>en,
      imem_addr_o=>iaddr, imem_data_i=>idata,
      dmem_addr_o=>daddr, dmem_wdata_o=>dwdata, dmem_we_o=>we,
      dmem_re_o=>re, dmem_be_o=>be, dmem_rdata_i=>rdata, halt_o=>halt, mtip_i=>mtip_r, irq_taken_o=>irq_taken, irq_pc_o=>irq_pc,
      st_fetch_o=>stf, st_mem_o=>stm, st_store_o=>sts, dbg_regs_o=>dbg);

  -- memoria combinacional latencia-cero (semantica pura del core)
  idata <= mem(idx(iaddr)) when iaddr(31)='1' else (others=>'0');
  -- modelo minimo del LSR del UART (0x10000004..7): THRE y TEMT siempre
  -- listos, en el lane 1 de su palabra. Necesario para que los programas
  -- que esperan THRE no giren en vacio en este arnes de traza.
  rdata <= std_logic_vector(mtime_r(31 downto 0)) when daddr = x"1100BFF8"
      else std_logic_vector(mtime_r(63 downto 32)) when daddr = x"1100BFFC"
      else std_logic_vector(mtimecmp_r(31 downto 0)) when daddr = x"11004000"
      else std_logic_vector(mtimecmp_r(63 downto 32)) when daddr = x"11004004"
      else x"00006000" when (daddr and x"FFFFFFFC") = x"10000004"
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
    file fev       : text open write_mode is "irq_events.log";
    variable l     : line;
    variable lev   : line;
    type t_cnt is array (0 to 4095) of natural;
    variable visitas : t_cnt := (others => 0);
    variable ix_ev : integer;
    variable pend_l : line;
    variable pend_pc : std_logic_vector(31 downto 0) := (others => '0');
    variable pend_valid : boolean := false;
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
      -- Fetch fantasma: el S_FETCH de una instruccion interrumpida se
      -- observa pero la instruccion NUNCA se retira. Usamos un buffer de
      -- una entrada: cada captura queda pendiente y solo se confirma
      -- (escribe y cuenta) al capturar la siguiente. Si llega irq_taken
      -- con el PC pendiente, se descarta: la traza queda con exactamente
      -- las instrucciones retiradas, igual que el ISS.
      if irq_taken = '1' then
        if pend_valid and pend_pc = irq_pc then
          pend_valid := false;   -- descartar el fetch fantasma
          deallocate(pend_l);    -- vaciar la linea descartada
        end if;
        -- evento: (PC interrumpido, retiros previos CONFIRMADOS de ese PC)
        ix_ev := to_integer(unsigned(irq_pc(13 downto 2)));
        hwrite(lev, irq_pc);
        write(lev, string'(" "));
        if ix_ev >= 0 and ix_ev < 4096 then
          write(lev, visitas(ix_ev));
        else
          write(lev, 0);
        end if;
        writeline(fev, lev);
      end if;
      if stf = '1' and iaddr /= last_pc then
        -- confirmar el pendiente anterior
        if pend_valid then
          ix_ev := to_integer(unsigned(pend_pc(13 downto 2)));
          if ix_ev >= 0 and ix_ev < 4096 then
            visitas(ix_ev) := visitas(ix_ev) + 1;
          end if;
          writeline(fo, pend_l);
          steps := steps + 1;
        end if;
        -- capturar el nuevo como pendiente
        write(pend_l, string'("PC="));
        hwrite(pend_l, iaddr);
        write(pend_l, string'(" INSTR="));
        hwrite(pend_l, idata);
        write(pend_l, string'(" R="));
        for i in 0 to 31 loop
          hwrite(pend_l, dbg(i*32+31 downto i*32));
          if i < 31 then write(pend_l, string'(",")); end if;
        end loop;
        pend_pc := iaddr;
        pend_valid := true;
        last_pc := iaddr;
      end if;

      -- deteccion de poweroff: store a 0x11100000 con 0x5555
      if en='1' and we='1' and daddr = x"11100000" and dwdata = x"00005555" then
        poweroff := true;
      end if;

      exit when poweroff or halt = '1' or steps > MAX_STEPS;
    end loop;
    -- confirmar el ultimo pendiente (no hay fetch fantasma final)
    if pend_valid then
      writeline(fo, pend_l);
      steps := steps + 1;
    end if;
    report "CORE TRACE: " & integer'image(steps) & " pasos escritos" severity note;
    finish;
  end process;

end architecture;
