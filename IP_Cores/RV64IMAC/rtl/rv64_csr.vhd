-- rv64_csr.vhd - fichero de CSRs M/S/U, entrada/salida de traps, interrupciones.
-- Semantica identica a iss64.py (ver docstring del ISS y SPEC_FREEZE_V1 sec. 3).
-- Todas las acciones se aplican en el flanco cuando el core hace commit en WB.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;

entity rv64_csr is
  port (
    clk, rst     : in  std_logic;
    -- lectura (WB) y legalidad
    addr         : in  std_logic_vector(11 downto 0);
    wr_intent    : in  std_logic;
    rdata        : out xword;
    illegal      : out std_logic;
    -- commit
    we           : in  std_logic;
    wdata        : in  xword;
    retire       : in  std_logic;                     -- instruccion retirada (minstret)
    trap         : in  std_logic;
    trap_irq     : in  std_logic;
    trap_code    : in  std_logic_vector(4 downto 0);
    trap_tval    : in  xword;
    trap_pc      : in  xword;
    trap_target  : out xword;                         -- vector (combinacional)
    do_mret      : in  std_logic;
    do_sret      : in  std_logic;
    mepc_o       : out xword;
    sepc_o       : out xword;
    -- interrupciones
    mtip, msip, meip, seip : in std_logic;
    time_i       : in  xword;
    irq_pending  : out std_logic;                     -- interrupcion habilitada a tomar
    irq_code     : out std_logic_vector(4 downto 0);
    wfi_wake     : out std_logic;                     -- (mip & mie) /= 0
    mip_o        : out std_logic_vector(11 downto 0);  -- mip actual (traza RVFI)
    -- estado para el resto del core
    priv         : out std_logic_vector(1 downto 0);
    st_tvm, st_tw, st_tsr : out std_logic;
    st_mprv, st_sum, st_mxr : out std_logic;
    st_mpp       : out std_logic_vector(1 downto 0);
    satp_o       : out xword;
    cbie_m, cbie_s : out std_logic_vector(1 downto 0);      -- Zicbom
    cbcfe_m, cbcfe_s : out std_logic
  );
end entity;

architecture rtl of rv64_csr is
  signal prv                      : std_logic_vector(1 downto 0);
  -- mstatus como campos
  signal sie, mie_b, spie, mpie   : std_logic;
  signal spp                      : std_logic;
  signal mpp                      : std_logic_vector(1 downto 0);
  signal mprv, sum, mxr, tvm, tw, tsr : std_logic;
  signal medeleg                  : std_logic_vector(15 downto 0);
  signal mideleg                  : std_logic_vector(11 downto 0);  -- bits 1,5,9
  signal mie_r                    : std_logic_vector(11 downto 0);
  signal mip_sw                   : std_logic_vector(11 downto 0);  -- SSIP/STIP/SEIP
  signal mtvec, stvec             : xword;
  signal mscratch, sscratch       : xword;
  signal mepc, sepc               : xword;
  signal mcause, scause           : xword;
  signal mtval, stval             : xword;
  signal mcounteren, scounteren   : std_logic_vector(31 downto 0);
  signal mcountinhibit            : std_logic_vector(2 downto 0);
  signal menvcfg, senvcfg         : std_logic;               -- FIOM
  signal m_cbie, s_cbie           : std_logic_vector(1 downto 0);
  signal m_cbcfe, s_cbcfe         : std_logic;
  signal satp                     : xword;
  signal mcycle, minstret         : unsigned(63 downto 0);

  signal mip_v                    : std_logic_vector(11 downto 0);
  signal mstatus_v                : xword;
  signal deleg_s                  : std_logic;          -- el trap actual va a S

  constant S_INTS   : std_logic_vector(11 downto 0) := x"222";
  constant ALL_INTS : std_logic_vector(11 downto 0) := x"AAA";
  constant MEDELEG_M: std_logic_vector(15 downto 0) := x"B3FE";       -- sin 0, 10, 11, 14
  constant MISA_V   : xword := x"8000000000141105";

begin
  priv <= prv;
  st_tvm <= tvm; st_tw <= tw; st_tsr <= tsr;
  st_mprv <= mprv; st_sum <= sum; st_mxr <= mxr; st_mpp <= mpp;
  satp_o <= satp;
  cbie_m <= m_cbie; cbie_s <= s_cbie; cbcfe_m <= m_cbcfe; cbcfe_s <= s_cbcfe;
  mepc_o <= mepc; sepc_o <= sepc;

  mip_v <= (mip_sw and S_INTS) or
           (meip & '0' & seip & '0' & mtip & "000" & msip & "000");

  process (all)
    variable v : xword;
  begin
    v := XZERO;
    v(35 downto 32) := "1010";                       -- SXL = UXL = 2 (RO)
    v(22) := tsr; v(21) := tw; v(20) := tvm; v(19) := mxr; v(18) := sum; v(17) := mprv;
    v(12 downto 11) := mpp; v(8) := spp; v(7) := mpie; v(5) := spie; v(3) := mie_b; v(1) := sie;
    mstatus_v <= v;
  end process;

  wfi_wake <= '1' when (mip_v and mie_r) /= x"000" else '0';
  mip_o <= mip_v;

  -- ---------------------------------------------------- seleccion de interrupcion
  -- Prioridad MEI, MSI, MTI, SEI, SSI, STI. Las de M (no delegadas) antes que las de S.
  process (all)
    variable pend, mp, sp : std_logic_vector(11 downto 0);
    variable m_en, s_en   : boolean;
    variable found        : boolean;
    variable code         : natural range 0 to 31;
    type prio_t is array (0 to 5) of natural range 0 to 11;
    constant PRIO : prio_t := (11, 3, 7, 9, 1, 5);
  begin
    pend := mip_v and mie_r;
    mp   := pend and not mideleg;
    sp   := pend and mideleg;
    m_en := prv /= PRV_M or mie_b = '1';
    s_en := prv = PRV_U or (prv = PRV_S and sie = '1');
    found := false; code := 0;
    -- recorrido explicito (sin tabla indexada con senal: PRIO es constante de bucle)
    for k in 0 to 5 loop
      if not found and m_en and mp(PRIO(k)) = '1' then found := true; code := PRIO(k); end if;
    end loop;
    for k in 0 to 5 loop
      if not found and s_en and sp(PRIO(k)) = '1' then found := true; code := PRIO(k); end if;
    end loop;
    irq_pending <= '1' when found else '0';
    irq_code    <= std_logic_vector(to_unsigned(code, 5));
  end process;

  -- ---------------------------------------------------- destino del trap
  process (all)
    variable code : natural range 0 to 31;
    variable dl   : std_logic;
    variable base : xword;
    variable vec  : std_logic;
  begin
    code := to_integer(unsigned(trap_code));
    if trap_irq = '1' then
      dl := '0'; if code < 12 then dl := mideleg(code); end if;
    else
      dl := '0'; if code < 16 then dl := medeleg(code); end if;
    end if;
    if prv /= PRV_M and dl = '1' then
      deleg_s <= '1'; base := stvec(63 downto 2) & "00"; vec := stvec(0);
    else
      deleg_s <= '0'; base := mtvec(63 downto 2) & "00"; vec := mtvec(0);
    end if;
    if trap_irq = '1' and vec = '1' then
      trap_target <= std_logic_vector(unsigned(base) + shift_left(resize(unsigned(trap_code), 64), 2));
    else
      trap_target <= base;
    end if;
  end process;

  -- ---------------------------------------------------- lectura y legalidad
  process (all)
    variable a    : natural range 0 to 4095;
    variable v    : xword;
    variable ok   : boolean;
    variable cbit : natural range 0 to 31;
  begin
    a := to_integer(unsigned(addr));
    v := XZERO; ok := true;
    cbit := to_integer(unsigned(addr(4 downto 0)));
    if unsigned(addr(9 downto 8)) > unsigned(prv) then
      ok := false;
    elsif addr(11 downto 5) = "1100000" then                     -- 0xC00-0xC1F
      if (prv /= PRV_M and mcounteren(cbit) = '0') or (prv = PRV_U and scounteren(cbit) = '0') then
        ok := false;
      elsif cbit = 0 then v := std_logic_vector(mcycle);
      elsif cbit = 1 then v := time_i;
      elsif cbit = 2 then v := std_logic_vector(minstret);
      end if;
    else
      case a is
        when 16#300# => v := mstatus_v;
        when 16#301# => v := MISA_V;
        when 16#302# => v := x"000000000000" & medeleg;
        when 16#303# => v := x"0000000000000" & mideleg;
        when 16#304# => v := x"0000000000000" & mie_r;
        when 16#305# => v := mtvec;
        when 16#306# => v := x"00000000" & mcounteren;
        when 16#30A# => v := XZERO; v(0) := menvcfg; v(5 downto 4) := m_cbie; v(6) := m_cbcfe;
        when 16#320# => v := (2 => mcountinhibit(2), 0 => mcountinhibit(0), others => '0');
        when 16#323# to 16#33F# => v := XZERO;
        when 16#340# => v := mscratch;
        when 16#341# => v := mepc;
        when 16#342# => v := mcause;
        when 16#343# => v := mtval;
        when 16#344# => v := x"0000000000000" & mip_v;
        when 16#3A0# to 16#3AF# => if addr(0) = '1' then ok := false; end if;
        when 16#3B0# to 16#3EF# => v := XZERO;
        when 16#7A0# to 16#7A3# => v := XZERO;
        when 16#B00# => v := std_logic_vector(mcycle);
        when 16#B02# => v := std_logic_vector(minstret);
        when 16#B03# to 16#B1F# => v := XZERO;
        when 16#F11# to 16#F15# => v := XZERO;
        when 16#100# => v := mstatus_v and x"00000003000C0122";
        when 16#104# => v := x"0000000000000" & (mie_r and mideleg);
        when 16#105# => v := stvec;
        when 16#106# => v := x"00000000" & scounteren;
        when 16#10A# => v := XZERO; v(0) := senvcfg; v(5 downto 4) := s_cbie; v(6) := s_cbcfe;
        when 16#140# => v := sscratch;
        when 16#141# => v := sepc;
        when 16#142# => v := scause;
        when 16#143# => v := stval;
        when 16#144# => v := x"0000000000000" & (mip_v and mideleg);
        when 16#180# =>
          if prv = PRV_S and tvm = '1' then ok := false; end if;
          v := satp;
        when others => ok := false;
      end case;
    end if;
    if wr_intent = '1' and addr(11 downto 10) = "11" then
      ok := false;
    end if;
    rdata <= v;
    illegal <= '0' when ok else '1';
  end process;

  -- ---------------------------------------------------- escritura y traps
  process (clk)
    variable a       : natural range 0 to 4095;
    variable w       : xword;
    variable code    : natural range 0 to 31;
    variable inc_ir  : boolean;
    variable cause_v : xword;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        prv <= PRV_M;
        sie <= '0'; mie_b <= '0'; spie <= '0'; mpie <= '0'; spp <= '0'; mpp <= "00";
        mprv <= '0'; sum <= '0'; mxr <= '0'; tvm <= '0'; tw <= '0'; tsr <= '0';
        medeleg <= (others => '0'); mideleg <= (others => '0');
        mie_r <= (others => '0'); mip_sw <= (others => '0');
        mtvec <= XZERO; stvec <= XZERO; mscratch <= XZERO; sscratch <= XZERO;
        mepc <= XZERO; sepc <= XZERO; mcause <= XZERO; scause <= XZERO;
        mtval <= XZERO; stval <= XZERO;
        mcounteren <= (others => '0'); scounteren <= (others => '0');
        mcountinhibit <= (others => '0'); menvcfg <= '0'; senvcfg <= '0';
        m_cbie <= "00"; s_cbie <= "00"; m_cbcfe <= '0'; s_cbcfe <= '0';
        satp <= XZERO; mcycle <= (others => '0'); minstret <= (others => '0');
      else
        if mcountinhibit(0) = '0' then mcycle <= mcycle + 1; end if;
        inc_ir := retire = '1' and mcountinhibit(2) = '0';

        if trap = '1' then
          code := to_integer(unsigned(trap_code));
          cause_v := (63 => trap_irq, others => '0');
          cause_v(4 downto 0) := trap_code;
          if deleg_s = '1' then
            sepc <= trap_pc; scause <= cause_v; stval <= trap_tval;
            spie <= sie; sie <= '0';
            spp  <= prv(0);
            prv  <= PRV_S;
          else
            mepc <= trap_pc; mcause <= cause_v; mtval <= trap_tval;
            mpie <= mie_b; mie_b <= '0';
            mpp  <= prv;
            prv  <= PRV_M;
          end if;
        elsif do_mret = '1' then
          prv <= mpp; mie_b <= mpie; mpie <= '1'; mpp <= PRV_U;
          if mpp /= PRV_M then mprv <= '0'; end if;
        elsif do_sret = '1' then
          prv <= '0' & spp; sie <= spie; spie <= '1'; spp <= '0'; mprv <= '0';
        elsif we = '1' then
          a := to_integer(unsigned(addr));
          w := wdata;
          case a is
            when 16#300# =>
              sie <= w(1); mie_b <= w(3); spie <= w(5); mpie <= w(7); spp <= w(8);
              if w(12 downto 11) /= "10" then mpp <= w(12 downto 11); end if;
              mprv <= w(17); sum <= w(18); mxr <= w(19); tvm <= w(20); tw <= w(21); tsr <= w(22);
            when 16#302# => medeleg <= w(15 downto 0) and MEDELEG_M;
            when 16#303# => mideleg <= w(11 downto 0) and S_INTS;
            when 16#304# => mie_r <= w(11 downto 0) and ALL_INTS;
            when 16#305# =>
              mtvec <= w(63 downto 2) & '0' & w(0);         -- MODE: bit 1 siempre 0
            when 16#306# => mcounteren <= w(31 downto 0);
            when 16#30A# =>
              menvcfg <= w(0); m_cbcfe <= w(6);
              if w(5 downto 4) = "10" then m_cbie <= "00"; else m_cbie <= w(5 downto 4); end if;
            when 16#320# => mcountinhibit <= w(2) & '0' & w(0);
            when 16#340# => mscratch <= w;
            when 16#341# => mepc <= w(63 downto 1) & '0';
            when 16#342# => mcause <= w;
            when 16#343# => mtval <= w;
            when 16#344# => mip_sw <= (mip_sw and not S_INTS) or (w(11 downto 0) and S_INTS);
            when 16#B00# => mcycle <= unsigned(w);
            when 16#B02# => minstret <= unsigned(w); inc_ir := false;
            when 16#100# =>
              sie <= w(1); spie <= w(5); spp <= w(8); sum <= w(18); mxr <= w(19);
            when 16#104# => mie_r <= (mie_r and not mideleg) or (w(11 downto 0) and mideleg);
            when 16#105# =>
              stvec <= w(63 downto 2) & '0' & w(0);         -- MODE: bit 1 siempre 0
            when 16#106# => scounteren <= w(31 downto 0);
            when 16#10A# =>
              senvcfg <= w(0); s_cbcfe <= w(6);
              if w(5 downto 4) = "10" then s_cbie <= "00"; else s_cbie <= w(5 downto 4); end if;
            when 16#140# => sscratch <= w;
            when 16#141# => sepc <= w(63 downto 1) & '0';
            when 16#142# => scause <= w;
            when 16#143# => stval <= w;
            when 16#144# => mip_sw(1) <= (mip_sw(1) and not mideleg(1)) or (w(1) and mideleg(1));
            when 16#180# =>
              if w(63 downto 60) = "0000" or w(63 downto 60) = "1000" then
                satp <= w;                              -- MODE/ASID(16)/PPN(44) escribibles
              end if;
            when others => null;
          end case;
        end if;
        if inc_ir then minstret <= minstret + 1; end if;
      end if;
    end if;
  end process;
end architecture;
