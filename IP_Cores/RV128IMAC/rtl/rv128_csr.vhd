-- rv128_csr.vhd - fichero de CSRs solo-M del RV128IMAC, traps e interrupciones.
-- Derivado de rv64_csr.vhd, recortado a modo M (sin S/U, sin MMU, sin PMP).
-- Semantica identica a iss128.py. Las acciones se aplican en el flanco del commit en W.
--
-- CSRs implementados (cualquier otro -> instruccion ilegal):
--   mstatus 300 (MIE, MPIE; MPP lee 11), misa 301 (RO), mie 304, mtvec 305,
--   mcountinhibit 320, mscratch 340, mepc 341, mcause 342, mtval 343, mip 344 (RO),
--   mcycle B00, minstret B02, cycle C00, time C01, instret C02,
--   mvendorid..mconfigptr F11-F15 (leen 0).
-- Contadores de 64 bit, extendidos con ceros a 128 al leer (escritura: 64 bit bajos).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv128_pkg.all;

entity rv128_csr is
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
    mepc_o       : out xword;
    -- interrupciones
    mtip, msip, meip : in std_logic;
    time_i       : in  std_logic_vector(63 downto 0);
    irq_pending  : out std_logic;                     -- interrupcion habilitada a tomar
    irq_code     : out std_logic_vector(4 downto 0);
    wfi_wake     : out std_logic;                     -- (mip & mie) /= 0
    mip_o        : out std_logic_vector(11 downto 0)  -- mip actual (traza RVFI)
  );
end entity;

architecture rtl of rv128_csr is
  signal mie_b, mpie              : std_logic;
  signal mie_r                    : std_logic_vector(11 downto 0);
  signal mtvec                    : xword;
  signal mscratch, mepc, mcause, mtval : xword;
  signal mcountinhibit            : std_logic_vector(2 downto 0);
  signal mcycle, minstret         : unsigned(63 downto 0);
  signal mip_v                    : std_logic_vector(11 downto 0);

  constant M_INTS : std_logic_vector(11 downto 0) := x"888";          -- MEI, MTI, MSI
  -- MXL=3 (RV128), extensiones A C I M
  constant MISA_V : xword := "11" & (125 downto 13 => '0') & "1000100000101";
begin
  mepc_o <= mepc;
  mip_v  <= meip & "000" & mtip & "000" & msip & "000";
  wfi_wake <= '1' when (mip_v and mie_r) /= x"000" else '0';
  mip_o  <= mip_v;

  -- ---------------------------------------------------- seleccion de interrupcion
  -- Prioridad MEI, MSI, MTI. Solo modo M: habilitadas por mstatus.MIE.
  process (all)
    variable pend : std_logic_vector(11 downto 0);
  begin
    pend := mip_v and mie_r;
    irq_pending <= '0'; irq_code <= "00000";
    if mie_b = '1' then
      if pend(11) = '1' then irq_pending <= '1'; irq_code <= "01011";
      elsif pend(3) = '1' then irq_pending <= '1'; irq_code <= "00011";
      elsif pend(7) = '1' then irq_pending <= '1'; irq_code <= "00111";
      end if;
    end if;
  end process;

  -- ---------------------------------------------------- destino del trap
  process (all)
    variable base : xword;
  begin
    base := mtvec(127 downto 2) & "00";
    if trap_irq = '1' and mtvec(0) = '1' then
      trap_target <= std_logic_vector(unsigned(base) + shift_left(resize(unsigned(trap_code), XLEN), 2));
    else
      trap_target <= base;
    end if;
  end process;

  -- ---------------------------------------------------- lectura y legalidad
  process (all)
    variable a  : natural range 0 to 4095;
    variable v  : xword;
    variable ok : boolean;
  begin
    a := to_integer(unsigned(addr));
    v := XZERO; ok := true;
    case a is
      when 16#300# => v(12 downto 11) := "11"; v(7) := mpie; v(3) := mie_b;
      when 16#301# => v := MISA_V;
      when 16#304# => v(11 downto 0) := mie_r;
      when 16#305# => v := mtvec;
      when 16#320# => v(2) := mcountinhibit(2); v(0) := mcountinhibit(0);
      when 16#340# => v := mscratch;
      when 16#341# => v := mepc;
      when 16#342# => v := mcause;
      when 16#343# => v := mtval;
      when 16#344# => v(11 downto 0) := mip_v;
      when 16#B00# | 16#C00# => v(63 downto 0) := std_logic_vector(mcycle);
      when 16#B02# | 16#C02# => v(63 downto 0) := std_logic_vector(minstret);
      when 16#C01# => v(63 downto 0) := time_i;
      when 16#F11# to 16#F15# => v := XZERO;
      when others => ok := false;
    end case;
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
    variable inc_ir  : boolean;
    variable cause_v : xword;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mie_b <= '0'; mpie <= '0';
        mie_r <= (others => '0');
        mtvec <= XZERO; mscratch <= XZERO; mepc <= XZERO; mcause <= XZERO; mtval <= XZERO;
        mcountinhibit <= (others => '0');
        mcycle <= (others => '0'); minstret <= (others => '0');
      else
        if mcountinhibit(0) = '0' then mcycle <= mcycle + 1; end if;
        inc_ir := retire = '1' and mcountinhibit(2) = '0';

        if trap = '1' then
          cause_v := (127 => trap_irq, others => '0');
          cause_v(4 downto 0) := trap_code;
          mepc <= trap_pc; mcause <= cause_v; mtval <= trap_tval;
          mpie <= mie_b; mie_b <= '0';
        elsif do_mret = '1' then
          mie_b <= mpie; mpie <= '1';
        elsif we = '1' then
          a := to_integer(unsigned(addr));
          w := wdata;
          case a is
            when 16#300# => mie_b <= w(3); mpie <= w(7);
            when 16#304# => mie_r <= w(11 downto 0) and M_INTS;
            when 16#305# => mtvec <= w(127 downto 2) & '0' & w(0);   -- MODE: bit 1 siempre 0
            when 16#320# => mcountinhibit <= w(2) & '0' & w(0);
            when 16#340# => mscratch <= w;
            when 16#341# => mepc <= w(127 downto 1) & '0';
            when 16#342# => mcause <= w;
            when 16#343# => mtval <= w;
            when 16#B00# => mcycle <= unsigned(w(63 downto 0));
            when 16#B02# => minstret <= unsigned(w(63 downto 0)); inc_ir := false;
            when others => null;                                     -- misa, mip: WARL, ignoradas
          end case;
        end if;
        if inc_ir then minstret <= minstret + 1; end if;
      end if;
    end if;
  end process;
end architecture;
