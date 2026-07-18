-- =============================================================
-- rv32_csr_trap.vhd - HERCOSSNUX RV32IMA SoC v1 - Paso 1
-- Banco de CSRs M-mode + logica de traps e interrupciones.
-- Spec: SPEC_FREEZE_V1.md secciones 3 y 4.
-- Contrato: csr_rdata / csr_illegal / irq_* / tvec_pc / epc_pc
-- son combinacionales; escrituras y entrada de trap son
-- registradas en flanco de subida. trap_en, mret_en y
-- (csr_en and csr_wr) son mutuamente excluyentes por ciclo
-- (lo garantiza la etapa de control del core).
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32_csr_trap is
  port (
    clk         : in  std_logic;
    clk_en      : in  std_logic := '1';  -- gating: '0' congela (espera NoC)
    rstn        : in  std_logic;  -- reset asincrono activo bajo
    -- interfaz de instruccion CSR (etapa execute)
    csr_en      : in  std_logic;
    csr_wr      : in  std_logic;  -- '1' si la instruccion escribe (csrrw siempre; csrrs/c solo rs1/=x0)
    csr_funct3  : in  std_logic_vector(2 downto 0);
    csr_addr    : in  std_logic_vector(11 downto 0);
    csr_wdata   : in  std_logic_vector(31 downto 0);
    csr_rdata   : out std_logic_vector(31 downto 0);
    csr_illegal : out std_logic;
    -- entrada de trap (excepcion o interrupcion tomada)
    trap_en     : in  std_logic;
    trap_cause  : in  std_logic_vector(31 downto 0);
    trap_pc     : in  std_logic_vector(31 downto 0);
    trap_tval   : in  std_logic_vector(31 downto 0);
    mret_en     : in  std_logic;
    -- salidas hacia fetch
    tvec_pc     : out std_logic_vector(31 downto 0);
    epc_pc      : out std_logic_vector(31 downto 0);
    -- lineas de interrupcion (CLINT)
    mtip        : in  std_logic;
    msip        : in  std_logic;
    irq_take    : out std_logic;
    irq_cause   : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of rv32_csr_trap is

  constant MISA_VAL : std_logic_vector(31 downto 0) := x"40001101"; -- RV32IMA

  signal r_mst_mie  : std_logic;                      -- mstatus.MIE
  signal r_mst_mpie : std_logic;                      -- mstatus.MPIE
  signal r_mie_mtie : std_logic;                      -- mie.MTIE
  signal r_mie_msie : std_logic;                      -- mie.MSIE
  signal r_mtvec    : std_logic_vector(31 downto 2);  -- modo direct
  signal r_mscratch : std_logic_vector(31 downto 0);
  signal r_mepc     : std_logic_vector(31 downto 1);  -- bit 0 forzado a 0
  signal r_mcause   : std_logic_vector(31 downto 0);
  signal r_mtval    : std_logic_vector(31 downto 0);
  signal r_mcycle   : unsigned(63 downto 0);

  signal s_rdata    : std_logic_vector(31 downto 0);
  signal s_known    : std_logic;  -- direccion CSR implementada
  signal s_ro_hard  : std_logic;  -- RO estricto: escribir es ilegal
  signal s_illegal  : std_logic;

  function f_wval(f3 : std_logic_vector(2 downto 0);
                  oldv, w : std_logic_vector(31 downto 0))
                  return std_logic_vector is
  begin
    case f3(1 downto 0) is
      when "01"   => return w;                    -- csrrw / csrrwi
      when "10"   => return oldv or w;            -- csrrs / csrrsi
      when others => return oldv and (not w);     -- csrrc / csrrci -- MUT4
    end case;
  end function;

begin

  -- ---------------------------------------------------------
  -- Lectura combinacional y decodificacion de legalidad
  -- ---------------------------------------------------------
  process(csr_addr, r_mst_mie, r_mst_mpie, r_mie_mtie, r_mie_msie,
          r_mtvec, r_mscratch, r_mepc, r_mcause, r_mtval, r_mcycle,
          mtip, msip)
    variable v : std_logic_vector(31 downto 0);
  begin
    v := (others => '0');
    s_known   <= '1';
    s_ro_hard <= '0';
    case csr_addr is
      when x"300" =>  -- mstatus: MPP=11 fijo, MPIE, MIE
        v(12 downto 11) := "11";
        v(7) := r_mst_mpie;
        v(3) := r_mst_mie;
      when x"301" =>  -- misa (WARL, escrituras ignoradas)
        v := MISA_VAL;
      when x"304" =>  -- mie
        v(7) := r_mie_mtie;
        v(3) := r_mie_msie;
      when x"305" =>  -- mtvec (direct)
        v := r_mtvec & "00";
      when x"340" => v := r_mscratch;
      when x"341" => v := r_mepc & '0';
      when x"342" => v := r_mcause;
      when x"343" => v := r_mtval;
      when x"344" =>  -- mip (RO por hardware, escrituras ignoradas)
        v(7) := mtip;
        v(3) := msip;
      when x"B00" =>
        v := std_logic_vector(r_mcycle(31 downto 0));
        s_ro_hard <= '1';
      when x"B80" =>
        v := std_logic_vector(r_mcycle(63 downto 32));
        s_ro_hard <= '1';
      when x"F11" | x"F12" | x"F13" | x"F14" =>  -- ids: cero
        s_ro_hard <= '1';
      when others =>
        s_known <= '0';
    end case;
    s_rdata <= v;
  end process;

  s_illegal   <= csr_en and ((not s_known) or (csr_wr and s_ro_hard));
  csr_rdata   <= s_rdata;
  csr_illegal <= s_illegal;

  -- ---------------------------------------------------------
  -- Interrupciones (prioridad: MSI sobre MTI)
  -- ---------------------------------------------------------
  irq_take  <= r_mst_mie and ((r_mie_msie and msip) or (r_mie_mtie and mtip));
  irq_cause <= x"80000003" when (r_mie_msie and msip) = '1' else
               x"80000007"; -- MUT3

  tvec_pc <= r_mtvec & "00";
  epc_pc  <= r_mepc & '0';

  -- ---------------------------------------------------------
  -- Escrituras, trap entry, mret, contador
  -- ---------------------------------------------------------
  process(clk, rstn)
    variable wv : std_logic_vector(31 downto 0);
  begin
    if rstn = '0' then
      r_mst_mie  <= '0';
      r_mst_mpie <= '0';
      r_mie_mtie <= '0';
      r_mie_msie <= '0';
      r_mtvec    <= (others => '0');
      r_mscratch <= (others => '0');
      r_mepc     <= (others => '0');
      r_mcause   <= (others => '0');
      r_mtval    <= (others => '0');
      r_mcycle   <= (others => '0');
    elsif rising_edge(clk) then
     if clk_en = '1' then
      r_mcycle <= r_mcycle + 1;
      if trap_en = '1' then
        r_mepc     <= trap_pc(31 downto 1); -- MUT5
        r_mcause   <= trap_cause;
        r_mtval    <= trap_tval;
        r_mst_mpie <= r_mst_mie;
        r_mst_mie  <= '0'; -- MUT1
      elsif mret_en = '1' then
        r_mst_mie  <= r_mst_mpie; -- MUT2
        r_mst_mpie <= '1';
      elsif (csr_en = '1') and (csr_wr = '1') and (s_illegal = '0') then
        wv := f_wval(csr_funct3, s_rdata, csr_wdata);
        case csr_addr is
          when x"300" =>
            r_mst_mpie <= wv(7);
            r_mst_mie  <= wv(3);
          when x"304" =>
            r_mie_mtie <= wv(7);
            r_mie_msie <= wv(3);
          when x"305" => r_mtvec    <= wv(31 downto 2);
          when x"340" => r_mscratch <= wv;
          when x"341" => r_mepc     <= wv(31 downto 1);
          when x"342" => r_mcause   <= wv;
          when x"343" => r_mtval    <= wv;
          when others => null; -- misa y mip: WARL, se ignoran
        end case;
      end if;
     end if;  -- clk_en
    end if;
  end process;

end architecture;
