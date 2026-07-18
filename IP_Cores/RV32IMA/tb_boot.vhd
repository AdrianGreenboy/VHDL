-- =============================================================
-- tb_boot.vhd - Paso 6b-2: el core RV32IMA ejecutando la imagen
-- REAL del kernel (Linux 6.1.14 rv32 nommu de mini-rv32ima).
--
-- RAM de 64 MB modelada como array de integers (16M palabras) para
-- que quepa en el host; carga dispersa desde boot_ram.hex (lineas
-- "indice valorhex", solo palabras pobladas: imagen + DTB + stub).
--
-- El core arranca en el stub (0x83F00000) que pone a0=hartid=0 y
-- a1=pa del DTB (igual que mini-rv32ima) y salta a 0x80000000.
--
-- MMIO con la semantica exacta del emulador:
--   - UART: LSR=0x60 (lane 1 de 0x10000004), THR -> boot_uart.log,
--     lecturas de registros no implementados -> 0, stores descartados
--   - CLINT: mtime avanza 1 por instruccion retirada; mtip cuando
--     (mtime > mtimecmp) y mtimecmp /= 0
--   - syscon 0x11100000: 0x5555 = poweroff
--
-- Emite core_trace.log (con buffer de confirmacion que descarta los
-- fetches fantasma), irq_events.log y mtime_reads.log, para el
-- lockstep contra el ISS en modo boot.
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.finish;

entity tb_boot is
  generic (
    MAX_STEPS  : natural := 100000;   -- retiros a EJECUTAR
    TRACE_FROM : natural := 0;        -- primer retiro que se escribe a la traza
    TRACE_REGS : boolean := true      -- false: solo PC (traza ligera)
  );
end entity;

architecture sim of tb_boot is
  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';
  signal en   : std_logic := '1';

  signal iaddr, idata, daddr, dwdata, rdata : std_logic_vector(31 downto 0);
  signal we, re, halt, stf, stm, sts : std_logic;
  signal be : std_logic_vector(3 downto 0);
  signal dbg : std_logic_vector(1023 downto 0);
  signal irq_taken : std_logic;
  signal irq_pc    : std_logic_vector(31 downto 0);

  -- 64 MB = 16M palabras; integer (32 bits con signo) por eficiencia
  constant NW : natural := 16*1024*1024;
  type t_ram is array (0 to NW-1) of integer;
  type t_ram_ptr is access t_ram;

  -- CLINT del arnes
  signal mtime_r    : unsigned(63 downto 0) := (others => '0');
  signal mtimecmp_r : unsigned(63 downto 0) := (others => '0');
  signal mtip_r     : std_logic;
  signal poweroff   : std_logic := '0';

  function slv(v : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(v, 32));
  end function;

  function int(v : std_logic_vector(31 downto 0)) return integer is
  begin
    return to_integer(signed(v));
  end function;

  -- indice de palabra en RAM: direcciones 0x80000000..0x83FFFFFF
  function ridx(a : std_logic_vector(31 downto 0)) return integer is
  begin
    return to_integer(unsigned(a(25 downto 2)));
  end function;

  function is_ram(a : std_logic_vector(31 downto 0)) return boolean is
  begin
    return a(31 downto 26) = "100000";
  end function;

  function is_mmio(a : std_logic_vector(31 downto 0)) return boolean is
  begin
    return a(31 downto 25) = "0001000";  -- 0x10000000..0x11FFFFFF
  end function;
begin

  clk <= not clk after 5 ns;

  -- mtip con la semantica del emulador (ver tb_trace_ima para el +1)
  mtip_r <= '1' when (mtime_r + 1 > mtimecmp_r) and (mtimecmp_r /= 0) else '0';

  dut : entity work.rv32ima_core
    generic map (RESET_PC => x"83F00000")   -- stub de arranque
    port map (clk_i=>clk, aresetn_i=>rstn, core_clk_en_i=>en,
      imem_addr_o=>iaddr, imem_data_i=>idata,
      dmem_addr_o=>daddr, dmem_wdata_o=>dwdata, dmem_we_o=>we,
      dmem_re_o=>re, dmem_be_o=>be, dmem_rdata_i=>rdata, halt_o=>halt,
      mtip_i=>mtip_r, irq_taken_o=>irq_taken, irq_pc_o=>irq_pc,
      st_fetch_o=>stf, st_mem_o=>stm, st_store_o=>sts, dbg_regs_o=>dbg);

  -- =========================================================
  -- proceso unico de memoria + MMIO + trazas (la RAM vive como
  -- variable de acceso para no duplicar 64 MB en cada delta)
  -- =========================================================
  mem_and_trace : process
    variable ram : t_ram_ptr := null;
    -- carga dispersa
    file fh      : text open read_mode is "boot_ram.hex";
    variable l   : line;
    variable ix  : integer;
    variable wv  : std_logic_vector(31 downto 0);
    -- trazas
    file fo      : text open write_mode is "core_trace.log";
    file fev     : text open write_mode is "irq_events.log";
    file fmt     : text open write_mode is "mtime_reads.log";
    file fu      : text open write_mode is "boot_uart.log";
    variable lo, lev, lmt, lu : line;
    variable last_pc : std_logic_vector(31 downto 0) := (others => '1');
    variable steps   : integer := 0;
    variable retired : integer := 0;
    variable pend_l  : line;
    variable pend_pc : std_logic_vector(31 downto 0) := (others => '0');
    variable pend_valid : boolean := false;
    variable prev_fetch : std_logic := '0';
    variable mt_served  : std_logic := '0';
    variable cur, nv : std_logic_vector(31 downto 0);
    variable uacc : integer := 0;
    variable prev_we : std_logic := '0';
  begin
    -- ---- carga de la RAM ----
    -- new con agregado de 64 MB revienta el stack de GHDL; asignar sin
    -- inicializador y limpiar por bucle
    ram := new t_ram;
    for i in 0 to NW-1 loop
      ram(i) := 0;
    end loop;
    while not endfile(fh) loop
      readline(fh, l);
      read(l, ix);
      hread(l, wv);
      ram(ix) := int(wv);
    end loop;
    report "RAM cargada" severity note;

    wait until falling_edge(clk);
    rstn <= '1';

    loop
      -- ===== fase combinacional: servir lecturas ANTES del flanco =====
      -- imem
      if is_ram(iaddr) then
        idata <= slv(ram(ridx(iaddr)));
      else
        idata <= (others => '0');
      end if;
      -- dmem
      if re = '1' then
        if is_ram(daddr) then
          rdata <= slv(ram(ridx(daddr)));
        elsif daddr = x"1100BFF8" then
          rdata <= std_logic_vector(mtime_r(31 downto 0));
          if mt_served = '0' then
            hwrite(lmt, std_logic_vector(mtime_r(31 downto 0)));
            writeline(fmt, lmt);
            mt_served := '1';
          end if;
        elsif daddr = x"1100BFFC" then
          rdata <= std_logic_vector(mtime_r(63 downto 32));
        elsif daddr = x"11004000" then
          rdata <= std_logic_vector(mtimecmp_r(31 downto 0));
        elsif daddr = x"11004004" then
          rdata <= std_logic_vector(mtimecmp_r(63 downto 32));
        elsif (daddr and x"FFFFFFFC") = x"10000004" then
          rdata <= x"00006000";   -- LSR=0x60 en el lane 1 (byte 5)
        else
          rdata <= (others => '0');  -- MMIO no implementado: 0
        end if;
      else
        rdata <= (others => '0');
      end if;
      if re = '0' then mt_served := '0'; end if;

      wait until rising_edge(clk);
      wait for 1 ns;

      -- ===== fase de muestreo post-flanco =====
      -- escritura de memoria / MMIO
      if we = '1' then
        if is_ram(daddr) then
          cur := slv(ram(ridx(daddr)));
          nv  := cur;
          for b in 0 to 3 loop
            if be(b) = '1' then
              nv(8*b+7 downto 8*b) := dwdata(8*b+7 downto 8*b);
            end if;
          end loop;
          ram(ridx(daddr)) := int(nv);
        elsif daddr = x"10000000" and prev_we = '0' then
          -- THR: el caracter va en el lane 0
          write(lu, character'val(to_integer(unsigned(dwdata(7 downto 0)))));
          uacc := uacc + 1;
          if character'val(to_integer(unsigned(dwdata(7 downto 0)))) = LF then
            writeline(fu, lu);
          end if;
        elsif daddr = x"11004000" then
          mtimecmp_r(31 downto 0) <= unsigned(dwdata);
        elsif daddr = x"11004004" then
          mtimecmp_r(63 downto 32) <= unsigned(dwdata);
        elsif daddr = x"11100000" and prev_we = '0' then
          if dwdata = x"00005555" then
            poweroff <= '1';
          end if;
        end if;
        -- otros stores MMIO: descartados (paridad emulador)
      end if;

      prev_we := we;

      -- mtime: 1 por instruccion retirada (al salir de S_FETCH)
      if prev_fetch = '1' and stf = '0' then
        mtime_r <= mtime_r + 1;
      end if;
      prev_fetch := stf;

      -- eventos de interrupcion (para el lockstep guiado)
      if irq_taken = '1' then
        if pend_valid and pend_pc = irq_pc then
          pend_valid := false;
          deallocate(pend_l);
        end if;
        hwrite(lev, irq_pc);
        writeline(fev, lev);
      end if;

      -- traza de retiro con buffer de confirmacion
      if stf = '1' and iaddr /= last_pc then
        if pend_valid then
          -- ventana de traza: los retiros previos a TRACE_FROM se cuentan
          -- pero no se escriben (booteos profundos generan GB de log)
          if retired >= TRACE_FROM then
            writeline(fo, pend_l);
            steps := steps + 1;
            if (steps mod 4096) = 0 then
              flush(fo);
            end if;
          else
            deallocate(pend_l);
          end if;
          retired := retired + 1;
        end if;
        write(pend_l, string'("PC="));
        hwrite(pend_l, iaddr);
        write(pend_l, string'(" INSTR="));
        -- leer la RAM directamente: la senal idata se sirve en la fase
        -- previa y llega con un ciclo de desfase al muestreo de la traza
        if is_ram(iaddr) then
          hwrite(pend_l, slv(ram(ridx(iaddr))));
        else
          hwrite(pend_l, idata);
        end if;
        if TRACE_REGS then
          write(pend_l, string'(" R="));
          for i in 0 to 31 loop
            hwrite(pend_l, dbg(i*32+31 downto i*32));
            if i < 31 then write(pend_l, string'(",")); end if;
          end loop;
        end if;
        pend_pc := iaddr;
        pend_valid := true;
        last_pc := iaddr;
      end if;

      exit when poweroff = '1' or halt = '1' or retired >= MAX_STEPS;
    end loop;

    if pend_valid and retired >= TRACE_FROM then
      writeline(fo, pend_l);
      steps := steps + 1;
    end if;
    if uacc > 0 then
      writeline(fu, lu);   -- volcar la linea de UART incompleta
    end if;
    report "BOOT TRACE: " & integer'image(retired) & " retiros, "
           & integer'image(steps) & " trazados, "
           & integer'image(uacc) & " bytes de UART" severity note;
    finish;
  end process;

end architecture;
