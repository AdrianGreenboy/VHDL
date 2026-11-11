-- rv128_core.vhd - pipeline RV128IMAC / RV64IMAC (core dual) en orden, 5 etapas.
-- Derivado de rv64_core.vhd (verificado en lockstep hasta Linux): misma estructura,
-- ensanchado a 128 bit. El modo se fija en el reset con la entrada m64:
--   m64 = '0'  RV128IMAC (M/S/U; paginacion Bare: no existe esquema RV128)
--   m64 = '1'  RV64IMAC + Zicbom + Sv39, binariamente igual que el rv64_core. Todo valor
--              (registros, pc, direcciones, CSRs) se mantiene extendido en signo desde el bit 63.
--
--  F  buffer de 4 medias palabras (instrucciones de 16 y 32 bit, cruces de palabra)
--  D  decompresor + decodificador + lectura del banco de registros + hazards,
--     inyeccion de interrupciones (re-validadas en W)
--  X  ALU, saltos (redirect en X), mul/div iterativo, direccion, PMA,
--     emision de la peticion de datos
--  M  espera de la respuesta de datos, extraccion de carril
--  W  commit unico: banco de registros, CSRs, traps, xRET, WFI, serializacion
--
-- Interfaces de memoria: peticion valid/ready, una respuesta por peticion en orden,
-- respuesta sin backpressure. Datos de 128 bit (16 carriles): LQ/SQ/AMO.Q en una peticion.
-- Paso 5: MMU Sv39 (Svade). I-TLB en F, D-TLB en X, un PTW compartido que usa el
-- puerto de datos. Las direcciones de los puertos son fisicas.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv128_pkg.all;
use work.rv128_mmu_pkg.all;

entity rv128_core is
  generic (
    RESET_PC : xword := (31 => '1', others => '0');      -- 0x8000_0000
    BPRED    : boolean := true                           -- BTB + RAS en F (false: sin prediccion)
  );
  port (
    clk, rst      : in  std_logic;
    m64           : in  std_logic;                     -- 1: modo RV64 (estable mientras rst = '0')
    -- instrucciones
    i_req_valid   : out std_logic;
    i_req_ready   : in  std_logic;
    i_req_addr    : out xword;                         -- alineada a 4 bytes
    i_rsp_valid   : in  std_logic;
    i_rsp_data    : in  std_logic_vector(31 downto 0);
    i_rsp_err     : in  std_logic;
    -- datos
    d_req_valid   : out std_logic;
    d_req_ready   : in  std_logic;
    d_req_addr    : out xword;
    d_req_kind    : out std_logic_vector(1 downto 0);  -- 00 load, 01 store, 10 amo
    d_req_amo_op  : out std_logic_vector(4 downto 0);
    d_req_size    : out std_logic_vector(2 downto 0);  -- log2(bytes), 0..4
    d_req_wdata   : out xword;                         -- por carriles
    d_req_wstrb   : out std_logic_vector(15 downto 0);
    d_rsp_valid   : in  std_logic;
    d_rsp_rdata   : in  xword;                         -- por carriles
    d_rsp_err     : in  std_logic;
    -- interrupciones y tiempo
    mtip, msip, meip, seip : in std_logic;
    time_i        : in  std_logic_vector(63 downto 0);
    -- mantenimiento (caches/TLB en pasos posteriores)
    fencei_o      : out std_logic;
    sfence_o      : out std_logic;
    -- traza de retiro (lockstep)
    rvfi_valid    : out std_logic;
    rvfi_pc       : out xword;
    rvfi_insn     : out std_logic_vector(31 downto 0);
    rvfi_rd       : out std_logic_vector(4 downto 0);
    rvfi_rd_wdata : out xword;
    rvfi_trap     : out std_logic;
    rvfi_cause    : out xword;
    rvfi_tval     : out xword;
    -- escritura a memoria del retiro (RVFI): direccion fisica, carriles y datos
    rvfi_mem_addr  : out xword;
    rvfi_mem_wstrb : out std_logic_vector(15 downto 0);
    rvfi_mem_wdata : out xword;
    rvfi_mip       : out std_logic_vector(11 downto 0)  -- mip en el retiro (lineas de irq)
  );
end entity;

architecture rtl of rv128_core is

  -- ------------------------------------------------------------ registros de etapa
  type idex_t is record
    v       : std_logic;
    pc      : xword;
    insn    : std_logic_vector(31 downto 0);           -- bits originales (16 o 32)
    len4    : std_logic;
    d       : dec_t;
    a, b    : xword;
    exc     : std_logic;
    irq     : std_logic;
    code    : std_logic_vector(4 downto 0);
    tval    : xword;
    pred    : std_logic;                               -- F predijo salto tomado a ptgt
    bpfix   : std_logic;                               -- marca de prediccion en mitad de una
                                                       -- instruccion: re-fetch desde pc (no retira)
    ptgt    : xword;
  end record;

  type exmem_t is record
    v       : std_logic;
    pc      : xword;
    insn    : std_logic_vector(31 downto 0);
    len4    : std_logic;
    rd_we   : std_logic;
    rd      : std_logic_vector(4 downto 0);
    res     : xword;
    mop     : mem_t;
    msize   : std_logic_vector(2 downto 0);
    munsign : std_logic;
    maddr   : xword;                                   -- virtual (tval)
    paddr   : xword;                                   -- fisica (reserva LR/SC)
    wdata   : xword;                                   -- datos de store por carriles (RVFI)
    wstrb   : std_logic_vector(15 downto 0);
    issued  : std_logic;
    sys     : sys_t;
    csr_f3  : std_logic_vector(2 downto 0);
    csr_addr: std_logic_vector(11 downto 0);
    csr_rs1z: std_logic;                                -- rs1/zimm == 0
    exc     : std_logic;
    irq     : std_logic;
    code    : std_logic_vector(4 downto 0);
    tval    : xword;
  end record;

  constant IDEX_NOP : idex_t := ('0', XZERO, x"00000000", '0', DEC_NOP, XZERO, XZERO, '0', '0', "00000", XZERO,
                                  '0', '0', XZERO);
  constant EXMEM_NOP : exmem_t := ('0', XZERO, x"00000000", '0', '0', "00000", XZERO, M_NONE, "000", '0',
                                   XZERO, XZERO, XZERO, x"0000", '0', S_NONE, "000", x"000", '0', '0', '0', "00000", XZERO);

  signal idex  : idex_t;
  signal exmem : exmem_t;
  signal memwb : exmem_t;

  -- ------------------------------------------------------------ fetch
  type hw_arr is array (0 to 3) of std_logic_vector(15 downto 0);
  signal fq_hw   : hw_arr;
  signal fq_err  : std_logic_vector(3 downto 0);
  signal fq_pf   : std_logic_vector(3 downto 0);       -- 1: page fault, 0: access fault
  signal fq_cnt  : unsigned(2 downto 0);
  signal fq_pc   : xword;
  signal f_addr  : xword;
  signal f_out   : std_logic;                          -- peticion real en vuelo
  signal f_self  : std_logic;                          -- fallo local (PMA/MMU) en vuelo
  signal f_self_pf : std_logic;
  signal f_drop  : std_logic;
  signal f_skip  : std_logic;                          -- respuesta en vuelo: descartar hw0
  signal f_nskip : std_logic;                          -- idem para la proxima peticion
  signal f_trunc : std_logic;                          -- respuesta en vuelo: solo hw0 (salto en hw0)
  signal f_mark  : std_logic;                          -- respuesta en vuelo: marcar el ultimo hw
  signal fq_bp   : std_logic_vector(3 downto 0);       -- hw que termina un salto predicho

  -- ------------------------------------------------------------ prediccion de saltos
  -- BTB de correspondencia directa indexada por la palabra que contiene el ultimo hw del
  -- salto; una prediccion pendiente como maximo (hasta que D consume el hw marcado). X
  -- comprueba el siguiente pc real de toda instruccion predicha, asi que un BTB obsoleto o
  -- con alias solo cuesta ciclos. RAS especulativo en F, restaurado desde el de X en cada
  -- redireccion.
  constant BTB_IB : natural := 6;                      -- 64 entradas
  constant BTB_TB : natural := 24;                     -- etiqueta = bits 31:8
  type btb_t is record
    tag  : std_logic_vector(BTB_TB - 1 downto 0);
    hw   : std_logic;
    kind : std_logic_vector(1 downto 0);               -- 00 salto, 01 llamada, 10 retorno
    ctr  : std_logic_vector(1 downto 0);               -- contador saturado (>= 2: tomado)
    tgt  : std_logic_vector(63 downto 0);
  end record;
  type btb_arr is array (0 to 2 ** BTB_IB - 1) of btb_t;
  signal btb     : btb_arr;
  signal btb_v   : std_logic_vector(2 ** BTB_IB - 1 downto 0);
  type ras_arr is array (0 to 7) of xword;
  signal sras, aras : ras_arr;
  signal sptr, aptr : unsigned(2 downto 0);
  signal bp_pend : std_logic;
  signal bp_tgt  : xword;
  signal bp_hit  : std_logic;
  signal bp_next : xword;
  signal bp_e    : btb_t;
  signal bp_ret  : xword;                              -- direccion de retorno de una llamada
  -- actualizacion desde X
  signal xb_we   : std_logic;
  signal xb_idx  : natural range 0 to 2 ** BTB_IB - 1;
  signal xb_e    : btb_t;
  signal xb_inv  : std_logic;
  signal xr_push, xr_pop : std_logic;
  signal xr_val  : xword;

  -- ------------------------------------------------------------ banco de registros
  type rf_t is array (1 to 31) of xword;
  signal rf : rf_t;

  -- ------------------------------------------------------------ datos
  signal d_out   : std_logic;
  signal d_drop  : std_logic;

  -- reserva LR/SC
  signal resv_v    : std_logic;
  signal resv_line : std_logic_vector(121 downto 0);

  -- ------------------------------------------------------------ combinacional
  signal id_avail, id_adv, id_consume2 : std_logic;
  signal id_rec        : idex_t;
  signal load_use      : std_logic;
  signal ex_adv, ex_redirect : std_logic;
  signal ex_target     : xword;
  signal ex_out        : exmem_t;
  signal ex_fa, ex_fb  : xword;
  signal ex_taken      : std_logic;
  signal ex_wait       : std_logic;
  signal mem_hold      : std_logic;
  signal mem_out       : exmem_t;
  signal mem_rsp       : std_logic;
  signal wb_flush      : std_logic;
  signal wb_target     : xword;
  signal wb_hold       : std_logic;
  signal wb_rf_we      : std_logic;
  signal wb_rf_data    : xword;
  signal redirect      : std_logic;
  signal redirect_pc   : xword;
  signal f_fault       : std_logic;                    -- fetch resuelto localmente como fallo
  signal f_fault_pf    : std_logic;
  signal f_go          : std_logic;                    -- peticion real aceptada este ciclo

  -- MMU
  signal itlb_hit, dtlb_hit : std_logic;
  signal itlb_e, dtlb_e     : tlbe_t;
  signal ptw_i_req, ptw_d_req : std_logic;
  signal ptw_i_fill, ptw_d_fill, ptw_i_fault, ptw_d_fault, ptw_fault_acc, ptw_busy : std_logic;
  signal ptw_fill_e         : tlbe_t;
  signal ptw_fault_vpn      : std_logic_vector(26 downto 0);
  signal ptw_m_valid, ptw_m_ready, ptw_rsp_valid : std_logic;
  signal ptw_m_addr         : xword;
  signal ptw_grant          : std_logic;
  signal d_owner_ptw        : std_logic;
  signal core_req_valid     : std_logic;
  signal core_req_addr      : xword;
  signal i_pfr_v, i_pfr_acc : std_logic;              -- fallo de caminata pendiente (fetch)
  signal i_pfr_vpn          : std_logic_vector(26 downto 0);
  signal d_pfr_v, d_pfr_acc : std_logic;              -- idem (datos)
  signal d_pfr_vpn          : std_logic_vector(26 downto 0);
  signal i_vpn, d_vpn       : std_logic_vector(26 downto 0);
  signal tlb_flush          : std_logic;
  signal sfence_int         : std_logic;
  signal core_req_size      : std_logic_vector(2 downto 0);
  signal core_req_kind      : std_logic_vector(1 downto 0);
  signal f_fill_n      : unsigned(2 downto 0);
  signal f_consume_n   : unsigned(2 downto 0);

  -- muldiv
  signal md_start, md_ack, md_busy, md_done : std_logic;
  signal md_res : xword;

  -- csr
  signal csr_wr_intent, csr_illegal, csr_we, csr_retire : std_logic;
  signal csr_rdata, csr_wdata : xword;
  signal csr_trap, csr_trap_irq, csr_mret, csr_sret : std_logic;
  signal csr_trap_code : std_logic_vector(4 downto 0);
  signal csr_trap_tval, csr_trap_target, csr_mepc, csr_sepc : xword;
  signal irq_pending, wfi_wake : std_logic;
  signal mip_trace : std_logic_vector(11 downto 0);
  signal irq_code : std_logic_vector(4 downto 0);
  signal priv : std_logic_vector(1 downto 0);
  signal st_tvm, st_tw, st_tsr, st_mprv, st_sum, st_mxr : std_logic;
  signal st_mpp : std_logic_vector(1 downto 0);
  signal satp : xword;
  signal cbie_m, cbie_s : std_logic_vector(1 downto 0);
  signal cbcfe_m, cbcfe_s : std_logic;

  function is_late(m : mem_t) return boolean is
  begin
    return m = M_LOAD or m = M_LR or m = M_SC or m = M_AMO;
  end function;

  function tval_insn(i : std_logic_vector(31 downto 0)) return xword is
  begin
    return (127 downto 32 => '0') & i;
  end function;

begin

  -- ============================================================ CSR
  csr_u : entity work.rv128_csr port map (
    clk => clk, rst => rst, m64 => m64,
    addr => memwb.csr_addr, wr_intent => csr_wr_intent, rdata => csr_rdata, illegal => csr_illegal,
    we => csr_we, wdata => csr_wdata, retire => csr_retire,
    trap => csr_trap, trap_irq => csr_trap_irq, trap_code => csr_trap_code, trap_tval => csr_trap_tval,
    trap_pc => memwb.pc, trap_target => csr_trap_target,
    do_mret => csr_mret, do_sret => csr_sret, mepc_o => csr_mepc, sepc_o => csr_sepc,
    mtip => mtip, msip => msip, meip => meip, seip => seip, time_i => time_i,
    irq_pending => irq_pending, irq_code => irq_code, wfi_wake => wfi_wake, mip_o => mip_trace,
    priv => priv, st_tvm => st_tvm, st_tw => st_tw, st_tsr => st_tsr,
    st_mprv => st_mprv, st_sum => st_sum, st_mxr => st_mxr, st_mpp => st_mpp, satp_o => satp,
    cbie_m => cbie_m, cbie_s => cbie_s, cbcfe_m => cbcfe_m, cbcfe_s => cbcfe_s);

  md_u : entity work.rv128_muldiv port map (
    clk => clk, rst => rst, start => md_start, kill => wb_flush, ack => md_ack,
    f3 => idex.d.md_f3, wsel => idex.d.wsel, a => ex_fa, b => ex_fb,
    busy => md_busy, done => md_done, result => md_res, clm => idex.d.clm);

  -- ============================================================ MMU
  tlb_flush <= sfence_int;
  itlb_u : entity work.rv128_tlb generic map (N => 8) port map (
    clk => clk, rst => rst, flush => tlb_flush, vpn => i_vpn, asid => satp(59 downto 44),
    hit => itlb_hit, e => itlb_e, fill => ptw_i_fill, fill_e => ptw_fill_e);
  dtlb_u : entity work.rv128_tlb generic map (N => 8) port map (
    clk => clk, rst => rst, flush => tlb_flush, vpn => d_vpn, asid => satp(59 downto 44),
    hit => dtlb_hit, e => dtlb_e, fill => ptw_d_fill, fill_e => ptw_fill_e);
  ptw_u : entity work.rv128_ptw port map (
    clk => clk, rst => rst, kill => wb_flush, satp => satp,
    i_req => ptw_i_req, i_vpn => i_vpn, d_req => ptw_d_req, d_vpn => d_vpn,
    i_fill => ptw_i_fill, d_fill => ptw_d_fill, fill_e => ptw_fill_e,
    i_fault => ptw_i_fault, d_fault => ptw_d_fault, fault_vpn => ptw_fault_vpn,
    fault_access => ptw_fault_acc, busy => ptw_busy,
    m_req_valid => ptw_m_valid, m_req_ready => ptw_m_ready, m_req_addr => ptw_m_addr,
    m_rsp_valid => ptw_rsp_valid, m_rsp_data => d_rsp_rdata, m_rsp_err => d_rsp_err);

  -- puerto de datos: el core tiene prioridad; el PTW lo usa con el puerto libre
  ptw_grant   <= '1' when core_req_valid = '0' and ptw_m_valid = '1' and d_out = '0' and rst = '0' else '0';
  d_req_valid <= core_req_valid or ptw_grant;
  d_req_addr  <= ptw_m_addr when ptw_grant = '1' else core_req_addr;
  d_req_size  <= "011" when ptw_grant = '1' else core_req_size;         -- PTE: 8 bytes
  d_req_kind  <= "00" when ptw_grant = '1' else core_req_kind;
  ptw_m_ready <= d_req_ready and ptw_grant;
  ptw_rsp_valid <= d_rsp_valid and d_owner_ptw;

  -- ============================================================ F: peticiones
  redirect    <= wb_flush or ex_redirect;
  redirect_pc <= wb_target when wb_flush = '1' else ex_target;

  i_vpn <= f_addr(38 downto 12);

  process (all)
    variable fill, cnt_next : unsigned(2 downto 0);
    variable want           : boolean;
    variable tr_on          : boolean;
    variable pa             : xword;
    variable ok, flt, pf, walk : boolean;
  begin
    fill := (others => '0');
    if (i_rsp_valid = '1' and f_drop = '0') or f_self = '1' then
      if f_skip = '1' or f_trunc = '1' then fill := "001"; else fill := "010"; end if;
    end if;
    f_fill_n <= fill;
    cnt_next := fq_cnt - f_consume_n + fill;
    -- audit-2026-11: the rst term is load-bearing, NOT redundant. Without it
    -- the core issues fetches during reset; a responder that is not reset by
    -- the same rst (tb_core's memory model, or any slave on another reset
    -- domain) answers after reset and the core takes that stale response as
    -- the reply to its first real fetch (lockstep mismatch at retire 2 of
    -- csr_sweep / irq_race / cbo_test). Kept on purpose.
    want := rst = '0' and redirect = '0' and (f_out = '0' or i_rsp_valid = '1') and f_self = '0'
            and cnt_next <= 2;
    -- traduccion: pagina -> PMA (mismo orden que el ISS)
    tr_on := satp(63 downto 60) = "1000" and priv /= PRV_M;
    pa := f_addr; ok := false; flt := false; pf := false; walk := false;
    if not tr_on then
      ok := true;
    elsif not va_canonical(f_addr) then
      flt := true; pf := true;
    elsif itlb_hit = '1' then
      if tlb_perm_ok(itlb_e, ACC_FETCH, priv, st_sum, st_mxr) then
        ok := true; pa := tlb_pa(itlb_e, f_addr);
      else
        flt := true; pf := true;
      end if;
    elsif i_pfr_v = '1' and i_pfr_vpn = f_addr(38 downto 12) then
      flt := true; pf := i_pfr_acc = '0';
    else
      walk := true;
    end if;
    if ok and not (pma_dram(pa) or pma_rom(pa)) then
      ok := false; flt := true; pf := false;
    end if;
    i_req_valid <= '1' when want and ok else '0';
    i_req_addr  <= pa(127 downto 2) & "00";
    f_fault     <= '1' when want and flt else '0';
    f_fault_pf  <= '1' when pf else '0';
    ptw_i_req   <= '1' when want and walk and ptw_busy = '0' else '0';
  end process;

  -- ============================================================ F: prediccion
  process (all)
    variable i   : natural range 0 to 2 ** BTB_IB - 1;
    variable e   : btb_t;
    variable hit : boolean;
    variable ra  : xword;
  begin
    i := to_integer(unsigned(f_addr(BTB_IB + 1 downto 2)));
    e := btb(i);
    hit := BPRED and btb_v(i) = '1' and e.tag = f_addr(BTB_IB + BTB_TB + 1 downto BTB_IB + 2)
           and e.ctr(1) = '1' and bp_pend = '0' and not (f_nskip = '1' and e.hw = '0');
    ra := f_addr(127 downto 2) & e.hw & '0';
    ra := xf(std_logic_vector(unsigned(ra) + 2), m64);
    bp_ret <= ra;
    bp_e   <= e;
    if e.kind = "10" then
      bp_next <= sras(to_integer(sptr - 1));
    else
      bp_next <= xf(sext(e.tgt, 64), m64);
    end if;
    if hit then bp_hit <= '1'; else bp_hit <= '0'; end if;
  end process;

  -- ============================================================ D: decodificacion
  process (all)
    variable hw0, hw1 : std_logic_vector(15 downto 0);
    variable is32     : boolean;
    variable avail    : boolean;
    variable r        : idex_t;
    variable exp      : std_logic_vector(32 downto 0);
    variable raw      : std_logic_vector(31 downto 0);
    variable d        : dec_t;
    variable lu       : boolean;

    impure function rf_read(n : std_logic_vector(4 downto 0)) return xword is
    begin
      if n = "00000" then
        return XZERO;
      elsif wb_rf_we = '1' and memwb.rd = n then
        return wb_rf_data;                               -- bypass W -> D
      else
        return rf(to_integer(unsigned(n)));
      end if;
    end function;
  begin
    hw0 := fq_hw(0); hw1 := fq_hw(1);
    is32 := hw0(1 downto 0) = "11";
    r := IDEX_NOP;
    r.pc := fq_pc;
    avail := false;
    if fq_cnt >= 1 and fq_err(0) = '1' then
      avail := true;
      r.exc := '1'; r.tval := fq_pc;
      if fq_pf(0) = '1' then r.code := std_logic_vector(to_unsigned(C_IPAGE, 5));
      else r.code := std_logic_vector(to_unsigned(C_IACCESS, 5)); end if;
      r.len4 := '0';
    elsif fq_cnt >= 1 and not is32 then
      avail := true;
      r.len4 := '0';
      r.pred := fq_bp(0);
      raw := x"0000" & hw0;
      exp := expand_c(hw0, m64);
      d := decode(exp(31 downto 0), m64);
      if exp(32) = '1' then d := DEC_NOP; d.illegal := '1'; end if;
      r.insn := raw; r.d := d;
    elsif fq_cnt >= 2 and fq_bp(0) = '1' then
      -- la marca cae en el primer hw de una instruccion de 32 bit: el segundo hw es del
      -- camino predicho, no de esta instruccion. X re-busca desde pc sin retirarla.
      avail := true;
      r.len4 := '1';
      r.bpfix := '1';
    elsif fq_cnt >= 2 then
      avail := true;
      r.len4 := '1';
      r.pred := fq_bp(1);
      if fq_err(1) = '1' then
        r.exc := '1';
        if fq_pf(1) = '1' then r.code := std_logic_vector(to_unsigned(C_IPAGE, 5));
        else r.code := std_logic_vector(to_unsigned(C_IACCESS, 5)); end if;
        r.tval := xf(std_logic_vector(unsigned(fq_pc) + 2), m64);
      else
        raw := hw1 & hw0;
        r.insn := raw;
        r.d := decode(raw, m64);
      end if;
    end if;
    r.ptgt := bp_tgt;
    if r.exc = '0' and r.d.illegal = '1' and r.bpfix = '0' then
      r.exc := '1'; r.code := std_logic_vector(to_unsigned(C_ILLEGAL, 5)); r.tval := tval_insn(r.insn);
    end if;
    -- interrupcion: sustituye a la instruccion (sin efectos laterales)
    if avail and irq_pending = '1' then
      r.exc := '1'; r.irq := '1'; r.code := irq_code; r.tval := XZERO;
    end if;
    if r.exc = '1' then
      r.pred := '0'; r.bpfix := '0';
    end if;
    if r.exc = '1' then
      r.d := DEC_NOP;
    end if;
    r.a := rf_read(r.d.rs1);
    r.b := rf_read(r.d.rs2);
    if avail then r.v := '1'; end if;
    id_rec <= r;
    if avail then id_avail <= '1'; else id_avail <= '0'; end if;
    if r.len4 = '1' then id_consume2 <= '1'; else id_consume2 <= '0'; end if;

    -- load-use: el productor en X entrega su resultado en M
    lu := false;
    if avail and idex.v = '1' and idex.exc = '0' and idex.d.rd_we = '1' and idex.d.rd /= "00000"
       and is_late(idex.d.mem) then
      if (r.d.use_rs1 = '1' and r.d.rs1 = idex.d.rd) or (r.d.use_rs2 = '1' and r.d.rs2 = idex.d.rd) then
        lu := true;
      end if;
    end if;
    if lu then load_use <= '1'; else load_use <= '0'; end if;
  end process;

  id_adv <= '1' when id_avail = '1' and load_use = '0' and wb_flush = '0' and ex_redirect = '0'
                     and (idex.v = '0' or ex_adv = '1') else '0';
  f_consume_n <= "000" when id_adv = '0' else "010" when id_consume2 = '1' else "001";

  -- ============================================================ X: ejecucion
  process (all)
    variable fa, fb   : xword;
    variable opa, opb : xword;
    variable o        : exmem_t;
    variable taken    : boolean;
    variable tgt      : xword;
    variable link     : xword;
    variable addr     : xword;
    variable mis      : boolean;
    variable pma_ok   : boolean;
    variable side     : boolean;
    variable need_req : boolean;
    variable older_ok : boolean;
    variable free     : boolean;
    variable sc_ok    : boolean;
    variable wait_v   : boolean;
    variable lanes    : integer range 0 to 15;
    variable strb     : std_logic_vector(15 downto 0);
    variable late_dep : boolean;
    variable effp     : std_logic_vector(1 downto 0);
    variable tr_on    : boolean;
    variable acc      : std_logic_vector(1 downto 0);
    variable pa       : xword;
    variable walk     : boolean;
    variable pf_code, af_code : natural range 0 to 31;
    variable btbi     : xword;
    variable be, oe   : btb_t;
    variable ohit     : boolean;
    variable kind     : std_logic_vector(1 downto 0);
  begin
    -- forwarding: M antes que W
    fa := idex.a; fb := idex.b;
    if idex.d.rs1 /= "00000" then
      if wb_rf_we = '1' and memwb.rd = idex.d.rs1 then fa := wb_rf_data; end if;
      if exmem.v = '1' and exmem.exc = '0' and exmem.rd_we = '1' and exmem.rd = idex.d.rs1 then fa := exmem.res; end if;
    end if;
    if idex.d.rs2 /= "00000" then
      if wb_rf_we = '1' and memwb.rd = idex.d.rs2 then fb := wb_rf_data; end if;
      if exmem.v = '1' and exmem.exc = '0' and exmem.rd_we = '1' and exmem.rd = idex.d.rs2 then fb := exmem.res; end if;
    end if;
    ex_fa <= fa; ex_fb <= fb;

    case idex.d.asel is
      when A_RS1  => opa := fa;
      when A_PC   => opa := idex.pc;
      when A_ZERO => opa := XZERO;
    end case;
    if idex.d.bsel = B_IMM then opb := idex.d.imm; else opb := fb; end if;

    o := EXMEM_NOP;
    o.v := idex.v; o.pc := idex.pc; o.insn := idex.insn; o.len4 := idex.len4;
    o.rd_we := idex.d.rd_we; o.rd := idex.d.rd;
    o.mop := idex.d.mem; o.msize := idex.d.msize; o.munsign := idex.d.munsign;
    o.sys := idex.d.sys; o.csr_f3 := idex.d.csr_f3; o.csr_addr := idex.d.csr_addr;
    o.exc := idex.exc; o.irq := idex.irq; o.code := idex.code; o.tval := idex.tval;
    if idex.d.rs1 = "00000" then o.csr_rs1z := '1'; else o.csr_rs1z := '0'; end if;

    if idex.len4 = '1' then link := std_logic_vector(unsigned(idex.pc) + 4);
    else link := std_logic_vector(unsigned(idex.pc) + 2); end if;
    link := xf(link, m64);

    -- resultado
    if idex.d.br = BR_JAL or idex.d.br = BR_JALR then
      o.res := link;
    elsif idex.d.md = '1' then
      o.res := md_res;
    elsif idex.d.sys = S_CSR then
      if idex.d.csr_f3(2) = '1' then o.res := idex.d.imm; else o.res := fa; end if;   -- fuente
    else
      o.res := alu(idex.d.alu, opa, opb, idex.d.wsel);
    end if;

    -- saltos
    taken := false;
    case idex.d.br is
      when BR_EQ  => taken := fa = fb;
      when BR_NE  => taken := fa /= fb;
      when BR_LT  => taken := signed(fa) < signed(fb);
      when BR_GE  => taken := signed(fa) >= signed(fb);
      when BR_LTU => taken := unsigned(fa) < unsigned(fb);
      when BR_GEU => taken := unsigned(fa) >= unsigned(fb);
      when BR_JAL | BR_JALR => taken := true;
      when BR_NONE => taken := false;
    end case;
    if idex.d.br = BR_JALR then
      tgt := std_logic_vector(unsigned(fa) + unsigned(idex.d.imm));
      tgt(0) := '0';
    else
      tgt := std_logic_vector(unsigned(idex.pc) + unsigned(idex.d.imm));
    end if;
    tgt := xf(tgt, m64);
    -- prediccion: redirigir solo si el siguiente pc real difiere del predicho
    if idex.bpfix = '1' then
      ex_target <= idex.pc; ex_taken <= '1';
      o.v := '0';                                        -- no retira: se re-busca
    elsif idex.pred = '1' then
      if taken then ex_target <= tgt; else ex_target <= link; end if;
      if taken and tgt = idex.ptgt then ex_taken <= '0'; else ex_taken <= '1'; end if;
    else
      ex_target <= tgt;
      if taken then ex_taken <= '1'; else ex_taken <= '0'; end if;
    end if;

    -- actualizacion de BTB y RAS (se aplica en el flanco si ex_adv = '1')
    xb_we <= '0'; xb_inv <= '0'; xr_push <= '0'; xr_pop <= '0';
    xr_val <= link;
    btbi := idex.pc;
    if idex.len4 = '1' and idex.bpfix = '0' then
      btbi := std_logic_vector(unsigned(idex.pc) + 2);   -- ultimo hw
    end if;
    xb_idx <= to_integer(unsigned(btbi(BTB_IB + 1 downto 2)));
    be.tag := btbi(BTB_IB + BTB_TB + 1 downto BTB_IB + 2);
    be.hw  := btbi(1);
    be.tgt := tgt(63 downto 0);
    be.kind := "00";
    if (idex.d.br = BR_JAL or idex.d.br = BR_JALR) and idex.d.rd_we = '1'
       and (idex.d.rd = "00001" or idex.d.rd = "00101") then
      be.kind := "01";
    elsif idex.d.br = BR_JALR and idex.d.rd = "00000" and (idex.d.rs1 = "00001" or idex.d.rs1 = "00101") then
      be.kind := "10";
    end if;
    kind := be.kind;
    oe := btb(to_integer(unsigned(btbi(BTB_IB + 1 downto 2))));
    ohit := btb_v(to_integer(unsigned(btbi(BTB_IB + 1 downto 2)))) = '1'
            and oe.tag = be.tag and oe.hw = be.hw;
    be.ctr := "11";
    if idex.v = '1' and idex.exc = '0' and idex.bpfix = '0' then
      if idex.d.br /= BR_NONE then
        if taken then
          if idex.d.br = BR_JAL or idex.d.br = BR_JALR then be.ctr := "11";
          elsif ohit and oe.ctr /= "11" then be.ctr := std_logic_vector(unsigned(oe.ctr) + 1);
          elsif ohit then be.ctr := "11";
          else be.ctr := "10"; end if;
          xb_we <= '1';
        elsif ohit then
          be := oe;
          if oe.ctr /= "00" then be.ctr := std_logic_vector(unsigned(oe.ctr) - 1); end if;
          xb_we <= '1';
        end if;
        if kind = "01" then xr_push <= '1'; elsif kind = "10" then xr_pop <= '1'; end if;
      elsif idex.pred = '1' then
        xb_inv <= '1';                                   -- alias: la entrada no es un salto
      end if;
    end if;
    -- marca en el primer hw de una instruccion de 32 bit: la entrada que la produjo (la de
    -- la palabra de pc) se invalida; si no, el re-fetch volveria a predecir lo mismo y la
    -- instruccion no avanzaria nunca
    if idex.v = '1' and idex.bpfix = '1' then
      xb_inv <= '1';
    end if;
    xb_e <= be;

    -- memoria: direccion, alineacion, traduccion, PMA (orden del ISS)
    addr := xf(std_logic_vector(unsigned(fa) + unsigned(idex.d.imm)), m64);
    o.maddr := addr;
    d_vpn <= addr(38 downto 12);
    case idex.d.msize is
      when "000"  => mis := false;
      when "001"  => mis := addr(0) = '1';
      when "010"  => mis := addr(1 downto 0) /= "00";
      when "011"  => mis := addr(2 downto 0) /= "000";
      when others => mis := addr(3 downto 0) /= "0000";
    end case;
    if idex.d.mem = M_LOAD or idex.d.mem = M_LR then
      acc := ACC_LOAD; pf_code := C_LPAGE; af_code := C_LACCESS;
    elsif idex.d.mem = M_CBO then
      acc := ACC_LOAD; pf_code := C_SPAGE; af_code := C_SACCESS;   -- Zicbom: como Spike
      mis := false;
    else
      acc := ACC_STORE; pf_code := C_SPAGE; af_code := C_SACCESS;
    end if;
    effp := priv;
    if st_mprv = '1' and priv = PRV_M then effp := st_mpp; end if;
    tr_on := satp(63 downto 60) = "1000" and effp /= PRV_M;
    pa := addr; walk := false;
    ptw_d_req <= '0';
    -- Zicbom: habilitacion por menvcfg/senvcfg (CBIE para inval, CBCFE para clean/flush)
    if idex.v = '1' and idex.exc = '0' and idex.d.mem = M_CBO and priv /= PRV_M then
      if (idex.d.amo_op(1 downto 0) = "00" and (cbie_m = "00" or (priv = PRV_U and cbie_s = "00"))) or
         (idex.d.amo_op(1 downto 0) /= "00" and (cbcfe_m = '0' or (priv = PRV_U and cbcfe_s = '0'))) then
        o.exc := '1'; o.code := std_logic_vector(to_unsigned(C_ILLEGAL, 5));
        o.tval := tval_insn(idex.insn);
      end if;
    end if;
    if idex.v = '1' and idex.exc = '0' and o.exc = '0' and idex.d.mem /= M_NONE then
      if mis then
        o.exc := '1'; o.tval := addr;
        if acc = ACC_LOAD then o.code := std_logic_vector(to_unsigned(C_LMISAL, 5));
        else o.code := std_logic_vector(to_unsigned(C_SMISAL, 5)); end if;
      elsif tr_on and not va_canonical(addr) then
        o.exc := '1'; o.tval := addr; o.code := std_logic_vector(to_unsigned(pf_code, 5));
      elsif tr_on and dtlb_hit = '1' and not tlb_perm_ok(dtlb_e, acc, effp, st_sum, st_mxr) then
        o.exc := '1'; o.tval := addr; o.code := std_logic_vector(to_unsigned(pf_code, 5));
      elsif tr_on and dtlb_hit = '0' then
        if d_pfr_v = '1' and d_pfr_vpn = addr(38 downto 12) then
          o.exc := '1'; o.tval := addr;
          if d_pfr_acc = '1' then o.code := std_logic_vector(to_unsigned(af_code, 5));
          else o.code := std_logic_vector(to_unsigned(pf_code, 5)); end if;
        else
          walk := true;
          if ptw_busy = '0' and wb_flush = '0' then ptw_d_req <= '1'; end if;
        end if;
      end if;
      if tr_on and dtlb_hit = '1' then pa := tlb_pa(dtlb_e, addr); end if;
      if o.exc = '0' and not walk and idex.d.mem /= M_CBO then
        if idex.d.mem = M_LOAD or idex.d.mem = M_STORE then
          pma_ok := pma_dram(pa) or pma_io(pa) or (idex.d.mem = M_LOAD and pma_rom(pa));
        else
          pma_ok := pma_dram(pa);
        end if;
        if not pma_ok then
          o.exc := '1'; o.tval := addr; o.code := std_logic_vector(to_unsigned(af_code, 5));
        end if;
      end if;
    end if;
    o.paddr := pa;

    -- dependencia de un resultado tardio (load/LR/SC/AMO) que sigue en M: esperar a
    -- que llegue a W y adelantar desde alli. Evita el camino respuesta -> ALU.
    late_dep := false;
    if idex.v = '1' and exmem.v = '1' and exmem.exc = '0' and exmem.rd_we = '1' and exmem.rd /= "00000"
       and is_late(exmem.mop) then
      if (idex.d.use_rs1 = '1' and idex.d.rs1 = exmem.rd) or (idex.d.use_rs2 = '1' and idex.d.rs2 = exmem.rd) then
        late_dep := true;
      end if;
    end if;

    -- SC: requiere M y W vacias (la reserva se fija en W) y reserva valida
    sc_ok := resv_v = '1' and resv_line = pa(127 downto 6);
    need_req := idex.v = '1' and o.exc = '0' and idex.d.mem /= M_NONE and not late_dep and not walk
                and not (idex.d.mem = M_CBO and not pma_dram(pa));
    wait_v := late_dep or walk;
    if need_req and idex.d.mem = M_SC then
      if exmem.v = '1' or memwb.v = '1' then
        wait_v := true; need_req := false;
      elsif not sc_ok then
        need_req := false;
        o.res := (0 => '1', others => '0');               -- SC falla sin acceso
      end if;
    end if;

    side := idex.d.mem = M_STORE or idex.d.mem = M_AMO or idex.d.mem = M_SC or idex.d.mem = M_CBO
            or not pma_dram(pa);
    older_ok := true;
    if exmem.v = '1' then
      if exmem.exc = '1' or exmem.sys /= S_NONE then older_ok := false;
      elsif exmem.issued = '1' and not (mem_rsp = '1' and d_rsp_err = '0') then older_ok := false;
      end if;
    end if;
    if memwb.v = '1' and (memwb.exc = '1' or memwb.sys /= S_NONE) then older_ok := false; end if;
    free := d_out = '0' or d_rsp_valid = '1';

    if rst = '0' and need_req and free and (not side or older_ok) and wb_flush = '0' then  -- rst: see 'want'
      core_req_valid <= '1';
    else
      core_req_valid <= '0';
    end if;
    if need_req and not (free and (not side or older_ok) and wb_flush = '0' and d_req_ready = '1') then
      wait_v := true;
    end if;
    if need_req then o.issued := '1'; else o.issued := '0'; end if;

    core_req_addr <= pa;
    core_req_size <= idex.d.msize;
    d_req_amo_op <= idex.d.amo_op;
    case idex.d.mem is
      when M_STORE | M_SC => core_req_kind <= "01";
      when M_AMO          => core_req_kind <= "10";
      when M_CBO          => core_req_kind <= "11";              -- d_req_amo_op(1:0) = operacion
      when others         => core_req_kind <= "00";
    end case;
    lanes := to_integer(unsigned(addr(3 downto 0)));
    case idex.d.msize is
      when "000"  => strb := x"0001";
      when "001"  => strb := x"0003";
      when "010"  => strb := x"000F";
      when "011"  => strb := x"00FF";
      when others => strb := x"FFFF";
    end case;
    d_req_wstrb <= std_logic_vector(shift_left(unsigned(strb), lanes));
    d_req_wdata <= std_logic_vector(shift_left(unsigned(fb), 8 * lanes));
    o.wdata := std_logic_vector(shift_left(unsigned(fb), 8 * lanes));
    if idex.d.mem = M_STORE or idex.d.mem = M_SC or idex.d.mem = M_AMO then
      o.wstrb := std_logic_vector(shift_left(unsigned(strb), lanes));
    end if;

    -- mul/div
    md_start <= '0';
    if idex.v = '1' and idex.exc = '0' and idex.d.md = '1' then
      if md_busy = '0' and not late_dep then md_start <= '1'; end if;
      if md_done = '0' then wait_v := true; end if;
    end if;

    if wait_v then ex_wait <= '1'; else ex_wait <= '0'; end if;
    ex_out <= o;
  end process;

  ex_adv <= '1' when idex.v = '1' and ex_wait = '0' and mem_hold = '0' and wb_flush = '0' else '0';
  md_ack <= ex_adv;
  ex_redirect <= '1' when ex_adv = '1' and idex.exc = '0' and ex_taken = '1' else '0';

  -- ============================================================ M: respuesta de datos
  mem_rsp <= d_rsp_valid and not d_drop and not d_owner_ptw;
  process (all)
    variable o      : exmem_t;
    variable sh     : xword;
    variable lanes  : integer range 0 to 15;
  begin
    o := exmem;
    lanes := to_integer(unsigned(exmem.maddr(3 downto 0)));
    sh := std_logic_vector(shift_right(unsigned(d_rsp_rdata), 8 * lanes));
    if exmem.v = '1' and exmem.issued = '1' then
      if exmem.mop = M_SC then
        o.res := XZERO;
      else
        case exmem.msize is
          when "000" => if exmem.munsign = '1' then o.res := (127 downto 8 => '0') & sh(7 downto 0); else o.res := sext(sh(7 downto 0), 8); end if;
          when "001" => if exmem.munsign = '1' then o.res := (127 downto 16 => '0') & sh(15 downto 0); else o.res := sext(sh(15 downto 0), 16); end if;
          when "010" => if exmem.munsign = '1' then o.res := (127 downto 32 => '0') & sh(31 downto 0); else o.res := sext(sh(31 downto 0), 32); end if;
          when "011" => if exmem.munsign = '1' then o.res := (127 downto 64 => '0') & sh(63 downto 0); else o.res := sext(sh(63 downto 0), 64); end if;
          when others => o.res := sh;
        end case;
      end if;
      if d_rsp_err = '1' then
        o.exc := '1'; o.tval := exmem.maddr;
        if exmem.mop = M_LOAD or exmem.mop = M_LR then o.code := std_logic_vector(to_unsigned(C_LACCESS, 5));
        else o.code := std_logic_vector(to_unsigned(C_SACCESS, 5)); end if;
      end if;
    end if;
    mem_out <= o;
  end process;
  mem_hold <= '1' when wb_hold = '1' or (exmem.v = '1' and exmem.issued = '1' and mem_rsp = '0') else '0';

  -- ============================================================ W: commit
  process (all)
    variable flush   : boolean;
    variable tgt     : xword;
    variable trap    : boolean;
    variable code    : std_logic_vector(4 downto 0);
    variable tval    : xword;
    variable irq     : boolean;
    variable next_pc : xword;
    variable old, src, nw : xword;
    variable rf_we   : boolean;
    variable rd_val  : xword;
    variable hold    : boolean;
    variable commit  : boolean;
  begin
    flush := false; trap := false; irq := false; hold := false; commit := false;
    tgt := XZERO; code := memwb.code; tval := memwb.tval;
    rf_we := false; rd_val := memwb.res;
    csr_wr_intent <= '0'; csr_we <= '0'; csr_wdata <= XZERO; csr_retire <= '0';
    csr_mret <= '0'; csr_sret <= '0';
    fencei_o <= '0'; sfence_int <= '0';
    if memwb.len4 = '1' then next_pc := std_logic_vector(unsigned(memwb.pc) + 4);
    else next_pc := std_logic_vector(unsigned(memwb.pc) + 2); end if;
    next_pc := xf(next_pc, m64);

    if memwb.csr_f3(1 downto 0) = "01" or memwb.csr_rs1z = '0' then csr_wr_intent <= '1'; end if;

    if memwb.v = '1' then
      if memwb.irq = '1' then
        if irq_pending = '1' then
          trap := true; irq := true; code := irq_code; tval := XZERO;
        else
          flush := true; tgt := memwb.pc;                -- la interrupcion desaparecio: reejecutar
        end if;
      elsif memwb.exc = '1' then
        trap := true;
      else
        case memwb.sys is
          when S_ECALL =>
            trap := true; tval := XZERO;
            code := std_logic_vector(to_unsigned(8 + to_integer(unsigned(priv)), 5));
          when S_EBREAK =>
            trap := true; code := std_logic_vector(to_unsigned(C_BREAK, 5)); tval := memwb.pc;
          when S_MRET =>
            if priv /= PRV_M then trap := true; code := std_logic_vector(to_unsigned(C_ILLEGAL, 5)); tval := tval_insn(memwb.insn);
            else commit := true; csr_mret <= '1'; flush := true; tgt := csr_mepc; end if;
          when S_SRET =>
            if priv = PRV_U or (priv = PRV_S and st_tsr = '1') then
              trap := true; code := std_logic_vector(to_unsigned(C_ILLEGAL, 5)); tval := tval_insn(memwb.insn);
            else commit := true; csr_sret <= '1'; flush := true; tgt := csr_sepc; end if;
          when S_WFI =>
            if priv = PRV_U or (priv = PRV_S and st_tw = '1') then
              trap := true; code := std_logic_vector(to_unsigned(C_ILLEGAL, 5)); tval := tval_insn(memwb.insn);
            elsif wfi_wake = '0' then
              hold := true;
            else
              commit := true; flush := true; tgt := next_pc;
            end if;
          when S_SFENCE =>
            if priv = PRV_U or (priv = PRV_S and st_tvm = '1') then
              trap := true; code := std_logic_vector(to_unsigned(C_ILLEGAL, 5)); tval := tval_insn(memwb.insn);
            else commit := true; flush := true; tgt := next_pc; sfence_int <= '1'; end if;
          when S_FENCEI =>
            commit := true; flush := true; tgt := next_pc; fencei_o <= '1';
          when S_CSR =>
            if csr_illegal = '1' then
              trap := true; code := std_logic_vector(to_unsigned(C_ILLEGAL, 5)); tval := tval_insn(memwb.insn);
            else
              commit := true; flush := true; tgt := next_pc;
              old := csr_rdata; src := memwb.res;
              case memwb.csr_f3(1 downto 0) is
                when "01"   => nw := src;
                when "10"   => nw := old or src;
                when others => nw := old and not src;
              end case;
              if memwb.csr_f3(1 downto 0) = "01" or memwb.csr_rs1z = '0' then
                csr_we <= '1';
              end if;
              csr_wdata <= nw;
              rd_val := old;
              rf_we := memwb.rd_we = '1';
            end if;
          when S_NONE =>
            commit := true;
            rf_we := memwb.rd_we = '1';
        end case;
      end if;
    end if;

    if trap then
      flush := true; tgt := csr_trap_target;
    end if;
    if commit then csr_retire <= '1'; end if;

    csr_trap <= '1' when trap else '0';
    csr_trap_irq <= '1' when irq else '0';
    csr_trap_code <= code;
    csr_trap_tval <= tval;

    wb_flush  <= '1' when flush else '0';
    wb_target <= tgt;
    wb_hold   <= '1' when hold else '0';
    wb_rf_we  <= '1' when rf_we and memwb.rd /= "00000" else '0';
    wb_rf_data <= rd_val;

    -- traza
    rvfi_valid <= '1' when trap or commit else '0';
    rvfi_pc <= memwb.pc;
    rvfi_insn <= memwb.insn;
    rvfi_trap <= '1' when trap else '0';
    rvfi_cause <= (others => '0');
    rvfi_cause(4 downto 0) <= code;
    if irq and m64 = '1' then rvfi_cause(127 downto 63) <= (others => '1');
    elsif irq then rvfi_cause(127) <= '1'; end if;
    rvfi_tval <= tval;
    if rf_we and memwb.rd /= "00000" then
      rvfi_rd <= memwb.rd; rvfi_rd_wdata <= rd_val;
    else
      rvfi_rd <= "00000"; rvfi_rd_wdata <= XZERO;
    end if;
    -- escritura del retiro: store, AMO y SC con exito (un SC fallido no emite peticion)
    rvfi_mem_addr <= memwb.paddr; rvfi_mem_wdata <= memwb.wdata; rvfi_mem_wstrb <= x"0000";
    if commit and memwb.sys = S_NONE and (memwb.mop = M_STORE or memwb.mop = M_AMO or
                                          (memwb.mop = M_SC and memwb.issued = '1')) then
      rvfi_mem_wstrb <= memwb.wstrb;
    end if;
  end process;

  sfence_o <= sfence_int;
  rvfi_mip <= mip_trace;

  -- ============================================================ registros
  process (clk)
    variable buf  : hw_arr;
    variable berr : std_logic_vector(3 downto 0);
    variable bpf  : std_logic_vector(3 downto 0);
    variable bbp  : std_logic_vector(3 downto 0);
    variable markc : boolean;
    variable vras : ras_arr;
    variable vptr : unsigned(2 downto 0);
    variable pfv  : std_logic;
    variable cnt  : integer range 0 to 7;
    variable n    : integer range 0 to 2;
    variable rsp  : boolean;
    variable data : std_logic_vector(31 downto 0);
    variable err  : std_logic;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        idex <= IDEX_NOP; exmem <= EXMEM_NOP; memwb <= EXMEM_NOP;
        fq_cnt <= "000"; fq_pc <= RESET_PC; f_addr <= RESET_PC(127 downto 2) & "00";
        f_out <= '0'; f_self <= '0'; f_drop <= '0'; f_skip <= '0'; f_nskip <= RESET_PC(1);
        f_trunc <= '0'; f_mark <= '0'; fq_bp <= "0000"; bp_pend <= '0';
        btb_v <= (others => '0'); sptr <= "000"; aptr <= "000";
        d_out <= '0'; d_drop <= '0'; resv_v <= '0'; d_owner_ptw <= '0';
        i_pfr_v <= '0'; d_pfr_v <= '0';
      else
        -- ---------------------------------------------- fetch
        if redirect = '1' then
          fq_cnt <= "000";
          fq_pc  <= redirect_pc;
          f_addr <= redirect_pc(127 downto 2) & "00";
          f_nskip <= redirect_pc(1);
          f_self <= '0';
          fq_bp  <= "0000";
          bp_pend <= '0';
          if f_out = '1' and i_rsp_valid = '0' then f_drop <= '1'; f_out <= '1';
          elsif f_drop = '1' and i_rsp_valid = '0' then f_drop <= '1';
          else f_drop <= '0'; f_out <= '0'; end if;
        else
          buf := fq_hw; berr := fq_err; bpf := fq_pf; bbp := fq_bp;
          cnt := to_integer(fq_cnt);
          n := to_integer(f_consume_n);
          markc := (n >= 1 and fq_bp(0) = '1') or (n = 2 and fq_bp(1) = '1');
          -- consumir
          for k in 1 to 2 loop
            if k <= n then
              buf(0) := buf(1); buf(1) := buf(2); buf(2) := buf(3);
              berr := '0' & berr(3 downto 1);
              bpf  := '0' & bpf(3 downto 1);
              bbp  := '0' & bbp(3 downto 1);
            end if;
          end loop;
          cnt := cnt - n;
          if markc then fq_pc <= bp_tgt;                    -- salto predicho: sigue el camino predicho
          elsif n = 2 then fq_pc <= xf(std_logic_vector(unsigned(fq_pc) + 4), m64);
          elsif n = 1 then fq_pc <= xf(std_logic_vector(unsigned(fq_pc) + 2), m64); end if;
          if markc then bp_pend <= '0'; end if;
          -- llenar
          rsp := (i_rsp_valid = '1' and f_drop = '0') or f_self = '1';
          if f_self = '1' then data := x"00000000"; err := '1'; pfv := f_self_pf;
          else data := i_rsp_data; err := i_rsp_err; pfv := '0'; end if;
          if rsp then
            if f_skip = '1' then
              buf(cnt) := data(31 downto 16); berr(cnt) := err; bpf(cnt) := pfv; bbp(cnt) := f_mark;
              cnt := cnt + 1;
            elsif f_trunc = '1' then
              buf(cnt) := data(15 downto 0); berr(cnt) := err; bpf(cnt) := pfv; bbp(cnt) := f_mark;
              cnt := cnt + 1;
            else
              buf(cnt) := data(15 downto 0); berr(cnt) := err; bpf(cnt) := pfv; bbp(cnt) := '0';
              buf(cnt + 1) := data(31 downto 16); berr(cnt + 1) := err; bpf(cnt + 1) := pfv;
              bbp(cnt + 1) := f_mark;
              cnt := cnt + 2;
            end if;
          end if;
          fq_hw <= buf; fq_err <= berr; fq_pf <= bpf; fq_bp <= bbp;
          fq_cnt <= to_unsigned(cnt, 3);
          -- estado de peticiones
          if i_rsp_valid = '1' then
            if f_drop = '1' then f_drop <= '0'; end if;
            f_out <= '0';
          end if;
          f_self <= '0';
          if i_req_valid = '1' and i_req_ready = '1' then
            f_out <= '1';
            f_skip <= f_nskip;
            if bp_hit = '1' then
              f_addr  <= bp_next(127 downto 2) & "00";
              f_nskip <= bp_next(1);
              f_mark  <= '1';
              f_trunc <= not bp_e.hw;
              bp_pend <= '1';
              bp_tgt  <= bp_next;
            else
              f_addr  <= xf(std_logic_vector(unsigned(f_addr) + 4), m64);
              f_nskip <= '0'; f_mark <= '0'; f_trunc <= '0';
            end if;
          elsif f_fault = '1' then
            f_self <= '1'; f_self_pf <= f_fault_pf;
            f_skip <= f_nskip; f_nskip <= '0'; f_mark <= '0'; f_trunc <= '0';
            f_addr <= xf(std_logic_vector(unsigned(f_addr) + 4), m64);
          end if;
        end if;

        -- ---------------------------------------------- BTB y RAS
        if ex_adv = '1' and xb_we = '1' then
          btb(xb_idx) <= xb_e; btb_v(xb_idx) <= '1';
        elsif ex_adv = '1' and xb_inv = '1' then
          btb_v(xb_idx) <= '0';
        end if;
        if fencei_o = '1' then btb_v <= (others => '0'); end if;
        vras := aras; vptr := aptr;
        if ex_adv = '1' and xr_pop = '1' then vptr := vptr - 1; end if;
        if ex_adv = '1' and xr_push = '1' then vras(to_integer(vptr)) := xr_val; vptr := vptr + 1; end if;
        aras <= vras; aptr <= vptr;
        if redirect = '1' then
          sras <= vras; sptr <= vptr;                    -- el camino especulativo se descarta
        elsif i_req_valid = '1' and i_req_ready = '1' and bp_hit = '1' then
          if bp_e.kind = "01" then sras(to_integer(sptr)) <= bp_ret; sptr <= sptr + 1;
          elsif bp_e.kind = "10" then sptr <= sptr - 1; end if;
        end if;

        -- ---------------------------------------------- fallos de caminata
        if redirect = '1' then
          i_pfr_v <= '0';
        elsif ptw_i_fault = '1' then
          i_pfr_v <= '1'; i_pfr_vpn <= ptw_fault_vpn; i_pfr_acc <= ptw_fault_acc;
        end if;
        if wb_flush = '1' or ex_adv = '1' then
          d_pfr_v <= '0';
        elsif ptw_d_fault = '1' then
          d_pfr_v <= '1'; d_pfr_vpn <= ptw_fault_vpn; d_pfr_acc <= ptw_fault_acc;
        end if;

        -- ---------------------------------------------- datos en vuelo
        if d_rsp_valid = '1' then
          d_out <= '0';
          if d_drop = '1' and d_owner_ptw = '0' then d_drop <= '0'; end if;
        end if;
        if d_req_valid = '1' and d_req_ready = '1' then
          d_out <= '1';
          d_owner_ptw <= ptw_grant;
        end if;
        if wb_flush = '1' and exmem.v = '1' and exmem.issued = '1' and mem_rsp = '0' then
          d_drop <= '1';
        end if;

        -- ---------------------------------------------- banco de registros
        if wb_rf_we = '1' then
          rf(to_integer(unsigned(memwb.rd))) <= wb_rf_data;
        end if;

        -- ---------------------------------------------- reserva
        if csr_trap = '1' then
          resv_v <= '0';
        elsif csr_retire = '1' then
          if memwb.mop = M_LR then
            resv_v <= '1'; resv_line <= memwb.paddr(127 downto 6);
          elsif memwb.mop = M_SC then
            resv_v <= '0';
          end if;
        end if;

        -- ---------------------------------------------- pipeline
        if wb_flush = '1' then
          idex <= IDEX_NOP; exmem <= EXMEM_NOP; memwb <= EXMEM_NOP;
        else
          -- W
          if wb_hold = '1' then
            null;
          elsif mem_hold = '0' then
            memwb <= mem_out;
          else
            memwb <= EXMEM_NOP;
          end if;
          -- M
          if mem_hold = '0' then
            if ex_adv = '1' then exmem <= ex_out; else exmem <= EXMEM_NOP; end if;
          end if;
          -- X
          if id_adv = '1' then
            idex <= id_rec;
          elsif ex_adv = '1' or ex_redirect = '1' then
            idex <= IDEX_NOP;
          elsif idex.v = '1' then
            idex.a <= ex_fa; idex.b <= ex_fb;           -- refresco de operandos en espera
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;
