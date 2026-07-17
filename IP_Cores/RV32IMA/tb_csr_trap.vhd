-- =============================================================
-- tb_csr_trap.vhd - Capa 1: rv32_csr_trap vs modelo independiente
-- Oraculo escrito por instruccion en variables (estilo distinto
-- al RTL): estado arquitectural + contador de flancos. Fase
-- dirigida (cobertura total del spec) + fase aleatoria LCG con
-- semilla fija (determinista, bit-identica entre maquinas).
-- Criterio de paso: linea unica
--   FIN SIMULACION CSR: PASS @ <tiempo>
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_csr_trap is
end entity;

architecture sim of tb_csr_trap is

  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';

  signal csr_en, csr_wr        : std_logic := '0';
  signal csr_funct3            : std_logic_vector(2 downto 0) := "000";
  signal csr_addr              : std_logic_vector(11 downto 0) := (others => '0');
  signal csr_wdata             : std_logic_vector(31 downto 0) := (others => '0');
  signal csr_rdata             : std_logic_vector(31 downto 0);
  signal csr_illegal           : std_logic;
  signal trap_en, mret_en      : std_logic := '0';
  signal trap_cause, trap_pc   : std_logic_vector(31 downto 0) := (others => '0');
  signal trap_tval             : std_logic_vector(31 downto 0) := (others => '0');
  signal tvec_pc, epc_pc       : std_logic_vector(31 downto 0);
  signal mtip, msip            : std_logic := '0';
  signal irq_take              : std_logic;
  signal irq_cause             : std_logic_vector(31 downto 0);

begin

  dut : entity work.rv32_csr_trap
    port map (
      clk => clk, rstn => rstn,
      csr_en => csr_en, csr_wr => csr_wr, csr_funct3 => csr_funct3,
      csr_addr => csr_addr, csr_wdata => csr_wdata,
      csr_rdata => csr_rdata, csr_illegal => csr_illegal,
      trap_en => trap_en, trap_cause => trap_cause,
      trap_pc => trap_pc, trap_tval => trap_tval, mret_en => mret_en,
      tvec_pc => tvec_pc, epc_pc => epc_pc,
      mtip => mtip, msip => msip,
      irq_take => irq_take, irq_cause => irq_cause
    );

  clk <= not clk after 5 ns;

  stim : process
    -- ------------------ estado del modelo ------------------
    variable m_mie, m_mpie       : std_logic := '0';
    variable m_mtie, m_msie      : std_logic := '0';
    variable m_mtvec             : unsigned(31 downto 0) := (others => '0');
    variable m_mscratch          : unsigned(31 downto 0) := (others => '0');
    variable m_mepc              : unsigned(31 downto 0) := (others => '0');
    variable m_mcause            : unsigned(31 downto 0) := (others => '0');
    variable m_mtval             : unsigned(31 downto 0) := (others => '0');
    variable m_edges             : unsigned(63 downto 0) := (others => '0');
    variable m_mtip, m_msip      : std_logic := '0';
    variable lcg                 : unsigned(31 downto 0) := to_unsigned(20260717, 32);
    variable nops                : integer := 0;

    -- avanza un flanco y actualiza el contador del modelo
    procedure step is
    begin
      wait until rising_edge(clk);
      m_edges := m_edges + 1;
    end procedure;

    -- lectura esperada segun el modelo; ok=false si CSR no existe
    procedure m_read(addr : in std_logic_vector(11 downto 0);
                     rd   : out unsigned(31 downto 0);
                     known: out boolean; rohard : out boolean) is
      variable v : unsigned(31 downto 0) := (others => '0');
    begin
      known := true; rohard := false;
      case addr is
        when x"300" =>
          v(12 downto 11) := "11"; v(7) := m_mpie; v(3) := m_mie;
        when x"301" => v := x"40001101"; 
        when x"304" => v(7) := m_mtie; v(3) := m_msie;
        when x"305" => v := m_mtvec;
        when x"340" => v := m_mscratch;
        when x"341" => v := m_mepc;
        when x"342" => v := m_mcause;
        when x"343" => v := m_mtval;
        when x"344" => v(7) := m_mtip; v(3) := m_msip;
        when x"B00" => v := m_edges(31 downto 0);  rohard := true;
        when x"B80" => v := m_edges(63 downto 32); rohard := true;
        when x"F11" | x"F12" | x"F13" | x"F14" => rohard := true;
        when others => known := false;
      end case;
      rd := v;
    end procedure;

    -- efecto de escritura sobre el modelo
    procedure m_write(addr : in std_logic_vector(11 downto 0);
                      f3   : in std_logic_vector(2 downto 0);
                      w    : in unsigned(31 downto 0)) is
      variable oldv, nv : unsigned(31 downto 0);
      variable kb, rb : boolean;
    begin
      m_read(addr, oldv, kb, rb);
      case f3(1 downto 0) is
        when "01"   => nv := w;
        when "10"   => nv := oldv or w;
        when others => nv := oldv and (not w);
      end case;
      case addr is
        when x"300" => m_mpie := nv(7); m_mie := nv(3);
        when x"304" => m_mtie := nv(7); m_msie := nv(3);
        when x"305" => m_mtvec := nv; m_mtvec(1 downto 0) := "00";
        when x"340" => m_mscratch := nv;
        when x"341" => m_mepc := nv; m_mepc(0) := '0';
        when x"342" => m_mcause := nv;
        when x"343" => m_mtval := nv;
        when others => null; -- misa/mip WARL ignoradas; RO no llega aqui
      end case;
    end procedure;

    -- ejecuta una op CSR contra el DUT y compara con el modelo
    procedure do_csr(addr : in std_logic_vector(11 downto 0);
                     f3   : in std_logic_vector(2 downto 0);
                     wr   : in std_logic;
                     w    : in unsigned(31 downto 0)) is
      variable exp_rd : unsigned(31 downto 0);
      variable kb, rb : boolean;
      variable exp_il : std_logic;
    begin
      csr_en <= '1'; csr_wr <= wr; csr_funct3 <= f3;
      csr_addr <= addr; csr_wdata <= std_logic_vector(w);
      wait for 1 ns;
      m_read(addr, exp_rd, kb, rb);
      if (not kb) or (wr = '1' and rb) then
        exp_il := '1';
      else
        exp_il := '0';
      end if;
      assert csr_illegal = exp_il
        report "ILEGAL discrepa en addr " & to_hstring(addr)
        severity failure;
      if kb and exp_il = '0' then
        assert unsigned(csr_rdata) = exp_rd
          report "RDATA discrepa en addr " & to_hstring(addr) &
                 " dut=" & to_hstring(csr_rdata) &
                 " modelo=" & to_hstring(std_logic_vector(exp_rd))
          severity failure;
        if wr = '1' then
          m_write(addr, f3, w);
        end if;
      end if;
      step;
      csr_en <= '0'; csr_wr <= '0';
      wait for 1 ns;
      nops := nops + 1;
    end procedure;

    -- trap: aplica y verifica efectos arquitecturales
    procedure do_trap(cause, pc, tv : in unsigned(31 downto 0)) is
    begin
      trap_en <= '1';
      trap_cause <= std_logic_vector(cause);
      trap_pc    <= std_logic_vector(pc);
      trap_tval  <= std_logic_vector(tv);
      step;
      trap_en <= '0';
      -- modelo
      m_mepc := pc; m_mepc(0) := '0';
      m_mcause := cause; m_mtval := tv;
      m_mpie := m_mie; m_mie := '0';
      wait for 1 ns;
      assert unsigned(epc_pc) = m_mepc
        report "EPC discrepa tras trap: dut=" & to_hstring(epc_pc)
        severity failure;
      assert unsigned(tvec_pc) = m_mtvec
        report "TVEC discrepa tras trap"
        severity failure;
    end procedure;

    procedure do_mret is
    begin
      mret_en <= '1';
      step;
      mret_en <= '0';
      m_mie := m_mpie; m_mpie := '1';
      wait for 1 ns;
    end procedure;

    -- verifica irq_take/irq_cause combinacionales vs modelo
    procedure chk_irq is
      variable exp_t : std_logic;
    begin
      exp_t := m_mie and ((m_msie and m_msip) or (m_mtie and m_mtip));
      assert irq_take = exp_t
        report "IRQ_TAKE discrepa" severity failure;
      if exp_t = '1' then
        if (m_msie and m_msip) = '1' then
          assert unsigned(irq_cause) = x"80000003"
            report "IRQ_CAUSE discrepa (esperado MSI)" severity failure;
        else
          assert unsigned(irq_cause) = x"80000007"
            report "IRQ_CAUSE discrepa (esperado MTI)" severity failure;
        end if;
      end if;
    end procedure;

    procedure set_irq(t, s : in std_logic) is
    begin
      mtip <= t; msip <= s;
      m_mtip := t; m_msip := s;
      wait for 1 ns;
      chk_irq;
    end procedure;

    -- LCG determinista (Numerical Recipes)
    impure function rnd return unsigned is
    begin
      lcg := resize(lcg * 1664525 + 1013904223, 32);
      return lcg;
    end function;

    variable r : unsigned(31 downto 0);
    variable a : std_logic_vector(11 downto 0);
    variable f : std_logic_vector(2 downto 0);
    variable wbit : std_logic;
    type t_pool is array (0 to 15) of std_logic_vector(11 downto 0);
    constant POOL : t_pool := (
      x"300", x"301", x"304", x"305", x"340", x"341", x"342", x"343",
      x"344", x"B00", x"B80", x"F11", x"F14", x"3A0", x"7C0", x"111");
    type t_f3 is array (0 to 5) of std_logic_vector(2 downto 0);
    constant F3S : t_f3 := ("001", "010", "011", "101", "110", "111");
  begin
    -- reset: 3 flancos en bajo, liberar entre flancos
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 1 ns;

    -- ================= FASE DIRIGIDA =================
    -- valores de reset
    do_csr(x"300", "010", '0', x"00000000");
    do_csr(x"301", "010", '0', x"00000000");
    do_csr(x"304", "010", '0', x"00000000");
    do_csr(x"305", "010", '0', x"00000000");
    do_csr(x"341", "010", '0', x"00000000");
    do_csr(x"B00", "010", '0', x"00000000");
    do_csr(x"B80", "010", '0', x"00000000");
    do_csr(x"F11", "010", '0', x"00000000");

    -- escritura/lectura de cada CSR RW con csrrw
    do_csr(x"340", "001", '1', x"DEADBEEF");
    do_csr(x"340", "010", '0', x"00000000");
    do_csr(x"305", "001", '1', x"80000005"); -- alineacion: lee 0x80000004
    do_csr(x"305", "010", '0', x"00000000");
    do_csr(x"341", "001", '1', x"00001235"); -- mepc bit0 forzado a 0
    do_csr(x"341", "010", '0', x"00000000");
    do_csr(x"342", "001", '1', x"0000000B");
    do_csr(x"343", "001", '1', x"CAFE0000");
    do_csr(x"300", "001", '1', x"00000088"); -- MIE=1, MPIE=1
    do_csr(x"304", "001", '1', x"00000088"); -- MTIE=1, MSIE=1

    -- csrrs / csrrc sobre mscratch
    do_csr(x"340", "001", '1', x"0F0F0F0F");
    do_csr(x"340", "010", '1', x"F0000001"); -- set
    do_csr(x"340", "010", '0', x"00000000");
    do_csr(x"340", "011", '1', x"000000FF"); -- clear
    do_csr(x"340", "010", '0', x"00000000");
    -- variantes inmediato (mismo datapath, f3 con bit2)
    do_csr(x"340", "101", '1', x"00000015");
    do_csr(x"340", "110", '1', x"0000000A");
    do_csr(x"340", "111", '1', x"00000003");
    do_csr(x"340", "010", '0', x"00000000");

    -- ilegales: CSR inexistente y escritura a RO estricto
    do_csr(x"3A0", "010", '0', x"00000000");
    do_csr(x"7C0", "001", '1', x"00000001");
    do_csr(x"B00", "001", '1', x"00000001");
    do_csr(x"F11", "001", '1', x"00000001");
    -- WARL legales ignoradas: misa y mip
    do_csr(x"301", "001", '1', x"FFFFFFFF");
    do_csr(x"301", "010", '0', x"00000000");
    do_csr(x"344", "001", '1', x"FFFFFFFF");
    do_csr(x"344", "010", '0', x"00000000");

    -- interrupciones: combinaciones y prioridad MSI > MTI
    set_irq('0', '0');
    set_irq('1', '0');           -- MTI
    do_csr(x"344", "010", '0', x"00000000"); -- mip refleja mtip
    set_irq('1', '1');           -- ambas: causa debe ser MSI
    set_irq('0', '1');           -- MSI
    set_irq('0', '0');

    -- trap con MIE=1: mepc/mcause/mtval/MPIE<=MIE, MIE<=0
    do_csr(x"305", "001", '1', x"00000200"); -- mtvec = 0x200
    do_trap(x"0000000B", x"00000FF3", x"12345678"); -- ecall, pc impar->par
    do_csr(x"300", "010", '0', x"00000000");
    do_csr(x"341", "010", '0', x"00000000");
    do_csr(x"342", "010", '0', x"00000000");
    do_csr(x"343", "010", '0', x"00000000");
    -- con MIE=0 las irq no se toman aunque esten pendientes
    set_irq('1', '1');
    set_irq('0', '0');
    -- mret restaura MIE desde MPIE(=1), MPIE<=1
    do_mret;
    do_csr(x"300", "010", '0', x"00000000");

    -- trap anidado conceptual: MIE=0 antes del trap -> MPIE=0;
    -- mret con MPIE=0 debe dejar MIE=0 (detecta MUT2)
    do_csr(x"300", "011", '1', x"00000008"); -- clear MIE
    do_trap(x"80000007", x"00000100", x"00000000");
    do_mret;
    do_csr(x"300", "010", '0', x"00000000");
    set_irq('1', '1');           -- MIE=0: no debe tomarse
    set_irq('0', '0');

    -- ================= FASE ALEATORIA =================
    for i in 0 to 1999 loop
      r := rnd;
      case to_integer(r(3 downto 0)) is
        when 0 =>
          r := rnd;
          r(31 downto 4) := x"8000000";
          r(0) := '1';
          do_trap(r, rnd, rnd);
        when 1 =>
          do_mret;
        when 2 =>
          set_irq(rnd(0), rnd(1));
        when others =>
          a := POOL(to_integer(rnd(3 downto 0)));
          f := F3S(to_integer(rnd(2 downto 0)) mod 6);
          wbit := rnd(4);
          do_csr(a, f, wbit, rnd);
      end case;
    end loop;
    set_irq('0', '0');

    report "OPS CSR TOTALES: " & integer'image(nops) severity note;
    report "FIN SIMULACION CSR: PASS @ " & time'image(now) severity note;
    finish;
  end process;

end architecture;
