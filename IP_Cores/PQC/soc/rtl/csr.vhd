-- =============================================================================
--  csr.vhd  -  Registros de control y estado (Zicsr) + traps e interrupciones
--  Licencia: MIT
--
--  CSRs de modo maquina: mstatus, mtvec, mepc, mcause, mscratch, mtval, mie, mip.
--
--  Interrupciones: las lineas irq_timer/irq_soft/irq_ext (del CLINT / externas)
--  se reflejan en mip. Una interrupcion queda "pendiente y habilitada" si
--  mstatus.MIE=1 y el bit correspondiente esta activo en mie y en mip. La causa
--  se prioriza externa > software > timer (como en la spec).
--
--  Prioridad de actualizacion por ciclo: trap > mret > escritura por CSR.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity csr is
  port (
    clk : in std_logic;
    rst : in std_logic;

    -- acceso por instruccion CSR
    csr_addr   : in  std_logic_vector(11 downto 0);
    csr_wdata  : in  word_t;
    csr_cmd    : in  csr_cmd_t;
    csr_access : in  std_logic;
    csr_rdata  : out word_t;

    -- interfaz de trap (sincrono o interrupcion)
    trap       : in  std_logic;
    trap_cause : in  word_t;
    trap_pc    : in  word_t;
    mret       : in  std_logic;

    -- lineas de interrupcion (nivel)
    irq_timer  : in  std_logic := '0';
    irq_soft   : in  std_logic := '0';
    irq_ext    : in  std_logic := '0';

    -- salidas
    mtvec_o     : out word_t;
    mepc_o      : out word_t;
    irq_pending : out std_logic;   -- hay una interrupcion pendiente y habilitada
    irq_cause   : out word_t       -- causa a usar si se toma la interrupcion
  );
end entity csr;

architecture rtl of csr is
  signal mstatus_mie  : std_logic := '0';
  signal mstatus_mpie : std_logic := '0';
  signal mstatus_mpp  : std_logic_vector(1 downto 0) := "11";
  signal mtvec    : word_t := (others => '0');
  signal mepc     : word_t := (others => '0');
  signal mcause   : word_t := (others => '0');
  signal mscratch : word_t := (others => '0');
  signal mtval    : word_t := (others => '0');
  signal mie_reg  : word_t := (others => '0');

  signal rdata   : word_t;
  signal newval  : word_t;
  signal mstatus : word_t;
  signal mip     : word_t;
begin

  -- mstatus (solo campos implementados)
  mstatus <= (12 => mstatus_mpp(1), 11 => mstatus_mpp(0),
              7  => mstatus_mpie,   3  => mstatus_mie, others => '0');

  -- mip refleja las lineas de interrupcion (MEIP=11, MTIP=7, MSIP=3)
  mip <= (11 => irq_ext, 7 => irq_timer, 3 => irq_soft, others => '0');

  -- lectura del CSR direccionado
  process(csr_addr, mstatus, mtvec, mepc, mcause, mscratch, mtval, mie_reg, mip)
  begin
    case csr_addr is
      when CSR_MSTATUS  => rdata <= mstatus;
      when CSR_MTVEC    => rdata <= mtvec;
      when CSR_MEPC     => rdata <= mepc;
      when CSR_MCAUSE   => rdata <= mcause;
      when CSR_MSCRATCH => rdata <= mscratch;
      when CSR_MTVAL    => rdata <= mtval;
      when CSR_MIE      => rdata <= mie_reg;
      when CSR_MIP      => rdata <= mip;
      when others       => rdata <= (others => '0');
    end case;
  end process;

  csr_rdata <= rdata;

  with csr_cmd select
    newval <= csr_wdata               when CSR_RW,
              rdata or csr_wdata      when CSR_RS,
              rdata and (not csr_wdata) when CSR_RC;

  mtvec_o <= mtvec(31 downto 2) & "00";
  mepc_o  <= mepc;

  -- interrupcion pendiente y habilitada (prioridad ext > soft > timer)
  irq_pending <= '1' when ( mstatus_mie = '1' and (
                    (mie_reg(11) = '1' and irq_ext   = '1') or
                    (mie_reg(3)  = '1' and irq_soft  = '1') or
                    (mie_reg(7)  = '1' and irq_timer = '1') ) )
                 else '0';

  irq_cause <= CAUSE_IRQ_EXT_M   when (mie_reg(11) = '1' and irq_ext  = '1') else
               CAUSE_IRQ_SOFT_M  when (mie_reg(3)  = '1' and irq_soft = '1') else
               CAUSE_IRQ_TIMER_M;

  process(clk)
    variable do_write : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mstatus_mie  <= '0';
        mstatus_mpie <= '0';
        mstatus_mpp  <= "11";
        mtvec    <= (others => '0');
        mepc     <= (others => '0');
        mcause   <= (others => '0');
        mscratch <= (others => '0');
        mtval    <= (others => '0');
        mie_reg  <= (others => '0');
      else
        if trap = '1' then
          mepc         <= trap_pc;
          mcause       <= trap_cause;
          mstatus_mpie <= mstatus_mie;
          mstatus_mie  <= '0';
          mstatus_mpp  <= "11";
        elsif mret = '1' then
          mstatus_mie  <= mstatus_mpie;
          mstatus_mpie <= '1';
          mstatus_mpp  <= "11";
        elsif csr_access = '1' then
          do_write := (csr_cmd = CSR_RW) or (csr_wdata /= ZERO_WORD);
          if do_write then
            case csr_addr is
              when CSR_MSTATUS =>
                mstatus_mie  <= newval(3);
                mstatus_mpie <= newval(7);
                mstatus_mpp  <= newval(12 downto 11);
              when CSR_MTVEC    => mtvec    <= newval;
              when CSR_MEPC     => mepc     <= newval;
              when CSR_MCAUSE   => mcause   <= newval;
              when CSR_MSCRATCH => mscratch <= newval;
              when CSR_MTVAL    => mtval    <= newval;
              when CSR_MIE      => mie_reg  <= newval;
              when others       => null;
            end case;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
