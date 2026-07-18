-- =============================================================
-- tb_clint.vhd - Paso 3: CLINT vs modelo + integracion con la
-- unidad de traps del Paso 1. Dos fases:
--  A) Capa 1: CLINT solo vs modelo independiente (registros,
--     mtime tick, mtip/msip), dirigida + aleatoria determinista.
--  B) Integracion: CLINT + rv32_csr_trap cableados; se reproduce
--     la secuencia exacta que hace el kernel para MTI:
--     programar mtimecmp, habilitar mie.MTIE + mstatus.MIE,
--     dejar correr mtime, tomar la interrupcion, reprogramar
--     mtimecmp en el handler (baja mtip), retornar con mret.
--     Igual para MSI via msip.
-- Criterio de paso: linea unica
--   FIN SIMULACION CLINT: PASS @ <tiempo>
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_clint is
end entity;

architecture sim of tb_clint is

  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';

  -- CLINT
  signal tick   : std_logic := '0';
  signal c_req, c_we : std_logic := '0';
  signal c_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal c_wdata, c_rdata : std_logic_vector(31 downto 0);
  signal c_ready : std_logic;
  signal mtip, msip : std_logic;

  -- unidad de traps (Paso 1)
  signal t_csr_en, t_csr_wr : std_logic := '0';
  signal t_f3   : std_logic_vector(2 downto 0) := "000";
  signal t_caddr: std_logic_vector(11 downto 0) := (others => '0');
  signal t_wdata, t_rdata : std_logic_vector(31 downto 0);
  signal t_illegal : std_logic;
  signal t_trap_en, t_mret_en : std_logic := '0';
  signal t_cause, t_pc, t_tval : std_logic_vector(31 downto 0) := (others => '0');
  signal t_tvec, t_epc : std_logic_vector(31 downto 0);
  signal irq_take : std_logic;
  signal irq_cause : std_logic_vector(31 downto 0);

begin

  clint : entity work.rv32_clint
    port map (clk => clk, rstn => rstn, tick => tick,
              req => c_req, we => c_we, addr => c_addr,
              wdata => c_wdata, rdata => c_rdata, ready => c_ready,
              mtip => mtip, msip => msip);

  trap : entity work.rv32_csr_trap
    port map (clk => clk, rstn => rstn,
              csr_en => t_csr_en, csr_wr => t_csr_wr, csr_funct3 => t_f3,
              csr_addr => t_caddr, csr_wdata => t_wdata,
              csr_rdata => t_rdata, csr_illegal => t_illegal,
              trap_en => t_trap_en, trap_cause => t_cause,
              trap_pc => t_pc, trap_tval => t_tval, mret_en => t_mret_en,
              tvec_pc => t_tvec, epc_pc => t_epc,
              mtip => mtip, msip => msip,
              irq_take => irq_take, irq_cause => irq_cause);

  clk <= not clk after 5 ns;

  stim : process
    -- modelo del CLINT
    variable m_msip     : std_logic := '0';
    variable m_mtimecmp : unsigned(63 downto 0) := (others => '0');
    variable m_mtime    : unsigned(63 downto 0) := (others => '0');
    variable lcg        : unsigned(31 downto 0) := to_unsigned(31415926, 32);
    variable nops       : integer := 0;

    impure function rnd return unsigned is
    begin
      lcg := resize(lcg * 1664525 + 1013904223, 32);
      return lcg;
    end function;

    procedure clk_tick(do_tick : std_logic) is
    begin
      tick <= do_tick;
      wait until rising_edge(clk);
      if do_tick = '1' then
        m_mtime := m_mtime + 1;
      end if;
      tick <= '0';
      wait for 1 ns;
    end procedure;

    -- escribe registro CLINT y actualiza modelo
    procedure c_write(a : std_logic_vector(15 downto 0);
                      d : unsigned(31 downto 0)) is
    begin
      c_req <= '1'; c_we <= '1'; c_addr <= a;
      c_wdata <= std_logic_vector(d);
      wait until rising_edge(clk);
      case a is
        when x"0000" => m_msip := d(0);
        when x"4000" => m_mtimecmp(31 downto 0)  := d;
        when x"4004" => m_mtimecmp(63 downto 32) := d;
        when x"BFF8" => m_mtime(31 downto 0)  := d;
        when x"BFFC" => m_mtime(63 downto 32) := d;
        when others  => null;
      end case;
      c_req <= '0'; c_we <= '0';
      wait for 1 ns;
    end procedure;

    -- lee registro CLINT y compara con modelo
    procedure c_read_chk(a : std_logic_vector(15 downto 0)) is
      variable exp : unsigned(31 downto 0);
    begin
      c_req <= '1'; c_we <= '0'; c_addr <= a;
      wait for 1 ns;
      case a is
        when x"0000" => exp := (0 => m_msip, others => '0');
        when x"4000" => exp := m_mtimecmp(31 downto 0);
        when x"4004" => exp := m_mtimecmp(63 downto 32);
        when x"BFF8" => exp := m_mtime(31 downto 0);
        when x"BFFC" => exp := m_mtime(63 downto 32);
        when others  => exp := (others => '0');
      end case;
      assert unsigned(c_rdata) = exp
        report "CLINT RDATA discrepa en offset " & to_hstring(a) &
               " dut=" & to_hstring(c_rdata) &
               " modelo=" & to_hstring(std_logic_vector(exp))
        severity failure;
      wait until rising_edge(clk);
      c_req <= '0';
      wait for 1 ns;
      nops := nops + 1;
    end procedure;

    procedure chk_lines is
      variable exp_mtip : std_logic;
    begin
      if (m_mtime > m_mtimecmp) and (m_mtimecmp /= 0) then
        exp_mtip := '1';
      else
        exp_mtip := '0';
      end if;
      assert mtip = exp_mtip
        report "MTIP discrepa: dut=" & std_logic'image(mtip) severity failure;
      assert msip = m_msip
        report "MSIP discrepa" severity failure;
    end procedure;

    -- helpers para manejar la unidad de traps
    procedure csr_w(a : std_logic_vector(11 downto 0);
                    d : std_logic_vector(31 downto 0)) is
    begin
      t_csr_en <= '1'; t_csr_wr <= '1'; t_f3 <= "001";
      t_caddr <= a; t_wdata <= d;
      wait until rising_edge(clk);
      t_csr_en <= '0'; t_csr_wr <= '0';
      wait for 1 ns;
    end procedure;

    procedure take_trap is
    begin
      t_trap_en <= '1';
      t_cause <= irq_cause; t_pc <= x"00001000"; t_tval <= x"00000000";
      wait until rising_edge(clk);
      t_trap_en <= '0';
      wait for 1 ns;
    end procedure;

    procedure do_mret is
    begin
      t_mret_en <= '1';
      wait until rising_edge(clk);
      t_mret_en <= '0';
      wait for 1 ns;
    end procedure;

    variable r : unsigned(31 downto 0);
    type t_off is array (0 to 4) of std_logic_vector(15 downto 0);
    constant OFFS : t_off := (x"0000", x"4000", x"4004", x"BFF8", x"BFFC");
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 1 ns;

    -- ============ FASE A: CLINT solo vs modelo ============
    -- valores de reset
    c_read_chk(x"0000");
    c_read_chk(x"BFF8");
    c_read_chk(x"4000");
    chk_lines;  -- mtimecmp all-ones, mtime 0 -> mtip=0

    -- avanzar mtime con ticks y verificar
    for i in 0 to 9 loop
      clk_tick('1');
    end loop;
    c_read_chk(x"BFF8");
    chk_lines;

    -- programar mtimecmp bajo -> mtip debe subir
    c_write(x"4004", x"00000000");
    c_write(x"4000", x"00000005");
    wait for 1 ns;
    chk_lines;  -- mtime(=10) >= 5 -> mtip=1
    assert mtip = '1' report "MTIP deberia estar en 1" severity failure;

    -- subir mtimecmp por encima de mtime -> mtip baja
    c_write(x"4000", x"000000FF");
    wait for 1 ns;
    chk_lines;
    assert mtip = '0' report "MTIP deberia estar en 0" severity failure;

    -- msip
    c_write(x"0000", x"00000001");
    wait for 1 ns; chk_lines;
    assert msip = '1' report "MSIP deberia estar en 1" severity failure;
    c_write(x"0000", x"00000000");
    wait for 1 ns; chk_lines;

    -- cruce de acarreo lo->hi en mtime: cargar 0xFFFFFFFE y tickear
    c_write(x"BFFC", x"00000000");
    c_write(x"BFF8", x"FFFFFFFE");
    c_write(x"4000", x"FFFFFFFF");
    c_write(x"4004", x"00000000");
    wait for 1 ns; chk_lines;  -- mtime=FFFFFFFE < FFFFFFFF
    clk_tick('1');             -- mtime=FFFFFFFF -> mtip=1
    wait for 1 ns; chk_lines;
    clk_tick('1');             -- mtime=1_00000000, cruza a hi
    c_read_chk(x"BFF8");       -- lo=0
    c_read_chk(x"BFFC");       -- hi=1
    chk_lines;

    -- aleatoria: escrituras/lecturas/ticks
    for i in 0 to 799 loop
      r := rnd;
      case to_integer(r(1 downto 0)) is
        when 0 => clk_tick('1');
        when 1 => c_write(OFFS(to_integer(rnd(2 downto 0)) mod 5), rnd);
        when others => c_read_chk(OFFS(to_integer(rnd(2 downto 0)) mod 5));
      end case;
      chk_lines;
    end loop;

    -- ============ FASE B: integracion con traps ============
    -- --- MTI: secuencia del kernel ---
    -- reset logico de mtime a 0 y mtimecmp lejano
    c_write(x"4004", x"00000000");
    c_write(x"4000", x"FFFFFFFF");
    c_write(x"BFF8", x"00000000");
    c_write(x"BFFC", x"00000000");
    -- programar mtvec, habilitar MTIE y MIE
    csr_w(x"305", x"00000800");           -- mtvec = 0x800
    csr_w(x"304", x"00000080");           -- mie.MTIE = 1
    csr_w(x"300", x"00000008");           -- mstatus.MIE = 1
    -- programar mtimecmp cercano y avanzar hasta dispararlo
    c_write(x"4000", x"00000003");
    for i in 0 to 4 loop clk_tick('1'); end loop; -- mtime=5 >= 3
    wait for 1 ns;
    assert mtip = '1' report "MTI: mtip deberia estar activo" severity failure;
    assert irq_take = '1' report "MTI: irq_take deberia estar activo" severity failure;
    assert unsigned(irq_cause) = x"80000007"
      report "MTI: irq_cause deberia ser 7 (MTI)" severity failure;
    -- tomar la interrupcion (el core salta a mtvec, guarda mepc, MIE<=0)
    take_trap;
    assert unsigned(t_epc) = x"00001000" report "MTI: mepc mal guardado" severity failure;
    -- dentro del handler: MIE=0 => irq_take baja aunque mtip siga alto
    assert irq_take = '0' report "MTI: irq_take deberia bajar con MIE=0" severity failure;
    -- el handler reprograma mtimecmp lejano -> mtip baja
    c_write(x"4000", x"FFFFFFFF");
    wait for 1 ns;
    assert mtip = '0' report "MTI: mtip deberia bajar tras reprogramar" severity failure;
    -- mret restaura MIE; ya no hay pendiente
    do_mret;
    assert irq_take = '0' report "MTI: no deberia reactivarse" severity failure;

    -- --- MSI: secuencia del kernel ---
    csr_w(x"304", x"00000008");           -- mie.MSIE = 1 (MTIE=0)
    csr_w(x"300", x"00000008");           -- MIE = 1
    c_write(x"0000", x"00000001");        -- levantar msip
    wait for 1 ns;
    assert msip = '1' report "MSI: msip deberia estar activo" severity failure;
    assert irq_take = '1' report "MSI: irq_take deberia estar activo" severity failure;
    assert unsigned(irq_cause) = x"80000003"
      report "MSI: irq_cause deberia ser 3 (MSI)" severity failure;
    take_trap;
    assert irq_take = '0' report "MSI: irq_take deberia bajar con MIE=0" severity failure;
    -- handler limpia msip
    c_write(x"0000", x"00000000");
    wait for 1 ns;
    assert msip = '0' report "MSI: msip deberia bajar" severity failure;
    do_mret;
    assert irq_take = '0' report "MSI: no deberia reactivarse" severity failure;

    -- --- prioridad: ambas activas, MSI gana ---
    c_write(x"4000", x"00000001");        -- mtimecmp=1 (mtime ya es mayor) -> mtip=1
    c_write(x"4004", x"00000000");        -- mtimecmp_hi=0
    c_write(x"0000", x"00000001");        -- msip=1
    csr_w(x"304", x"00000088");           -- MTIE=1, MSIE=1
    csr_w(x"300", x"00000008");           -- MIE=1
    wait for 1 ns;
    assert mtip = '1' and msip = '1' report "ambas deberian estar activas" severity failure;
    assert unsigned(irq_cause) = x"80000003"
      report "prioridad: deberia ganar MSI" severity failure;

    report "OPS CLINT TOTALES: " & integer'image(nops) severity note;
    report "FIN SIMULACION CLINT: PASS @ " & time'image(now) severity note;
    finish;
  end process;

end architecture;
