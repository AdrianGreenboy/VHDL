-- =============================================================================
--  cpu_pipeline.vhd  -  Core RV32IM + Zicsr con pipeline de 5 etapas
--  Licencia: MIT
--
--  Etapas: IF -> ID -> EX -> MEM -> WB.
--
--  Hazards de datos: forwarding EX/MEM y MEM/WB + bypass write-first del
--  register file. Load-use: 1 burbuja. Control: branches/saltos en EX con flush.
--  mul/div: congela el frente hasta 'done'.
--
--  Excepciones precisas (Zicsr + traps + interrupciones), todo resuelto en EX:
--    * ECALL/EBREAK  -> trap a mtvec, mepc = PC de la instruccion, se aplasta.
--    * MRET          -> redirige a mepc, restaura mstatus.
--    * CSR (csrrw/s/c)-> escribe CSR y rd, luego serializa (redirige a pc+4 con
--                        flush) para que nadie vea un CSR a medio actualizar.
--    * Interrupcion  -> se toma en un limite de instruccion valida en EX: se
--                        aplasta esa instruccion (mepc = su PC para reejecutar),
--                        se redirige a mtvec y se hace flush de las jovenes.
--  El bit 'valid' evita tomar interrupciones sobre burbujas.
--
--  audit-2026-11 additions (see AUDIT_FIXES.md):
--    * Synchronous exceptions raised in EX through the same precise trap path:
--        illegal instruction (cause 2, mtval = instruction bits), including
--        unknown opcodes, reserved encodings, unknown SYSTEM immediates and
--        unimplemented / read-only CSRs;
--        load / store address misaligned (cause 4 / 6, mtval = address);
--        instruction address misaligned on taken jumps/branches (cause 0,
--        mtval = target).
--    * Load / store access fault (cause 5 / 7, mtval = address) raised from
--      MEM when the memory system answers dmem_ready='1' with dmem_err='1'
--      (AXI SLVERR/DECERR). Older than anything in EX, so it has priority and
--      squashes IF/ID/EX; the faulting load does not write back.
--    * IMEM_SYNC: instruction memory with 1-cycle synchronous read. The core
--      then drives imem_addr with the NEXT pc (pc_d), so the word for 'pc'
--      is on imem_instr in the cycle 'pc' is valid. No extra stage, no
--      penalty; the cost is a longer path redirect -> SRAM address.
--    * DMEM_SYNC: data memory with 1-cycle synchronous read. Every load
--      spends one extra cycle in MEM (first cycle: address to the SRAM,
--      dmem_req held low; second cycle: normal dmem_req/dmem_ready
--      handshake with the read data). Stores are unchanged.
--    * load-use stall only when the consumer really reads rs1/rs2.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity cpu_pipeline is
  generic (
    IMEM_SYNC : boolean := false;   -- true: IMEM has a 1-cycle synchronous read
    DMEM_SYNC : boolean := false    -- true: DMEM has a 1-cycle synchronous read
  );
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;

    imem_addr  : out word_t;
    imem_instr : in  word_t;

    dmem_addr  : out word_t;
    dmem_wdata : out word_t;
    dmem_wstrb : out std_logic_vector(3 downto 0);
    dmem_rdata : in  word_t;
    dmem_req   : out std_logic;                 -- '1' = acceso de carga/almacen en MEM
    dmem_ready : in  std_logic := '1';          -- '1' = memoria respondio (default: 1 ciclo)
    dmem_err   : in  std_logic := '0';          -- with dmem_ready: bus error -> access fault

    irq_timer  : in  std_logic := '0';
    irq_soft   : in  std_logic := '0';
    irq_ext    : in  std_logic := '0';

    dbg_reg_addr : in  reg_addr_t := (others => '0');
    dbg_reg_data : out word_t;
    dbg_pc       : out word_t
  );
end entity cpu_pipeline;

architecture rtl of cpu_pipeline is

  constant NOP_INSTR : word_t := x"00000013";

  type ifid_t is record
    instr : word_t;
    pc    : word_t;
    pc4   : word_t;
    valid : std_logic;
  end record;

  type idex_t is record
    ctrl     : ctrl_t;
    pc       : word_t;
    pc4      : word_t;
    imm      : word_t;
    a_val    : word_t;
    b_val    : word_t;
    rs1_addr : reg_addr_t;
    rs2_addr : reg_addr_t;
    rd_addr  : reg_addr_t;
    funct3   : std_logic_vector(2 downto 0);
    csr_addr : std_logic_vector(11 downto 0);
    instr    : word_t;                        -- for mtval on illegal instruction
    valid    : std_logic;
  end record;

  type exmem_t is record
    reg_we     : std_logic;
    mem_re     : std_logic;
    mem_we     : std_logic;
    wb_sel     : wb_sel_t;
    funct3     : std_logic_vector(2 downto 0);
    result     : word_t;
    store_data : word_t;
    rd_addr    : reg_addr_t;
    pc         : word_t;                      -- for mepc on access fault
    pc4        : word_t;
  end record;

  type memwb_t is record
    reg_we    : std_logic;
    wb_sel    : wb_sel_t;
    result    : word_t;
    load_data : word_t;
    pc4       : word_t;
    rd_addr   : reg_addr_t;
  end record;

  constant IFID_NOP : ifid_t :=
    (instr => NOP_INSTR, pc => (others=>'0'), pc4 => (others=>'0'), valid => '0');
  constant IDEX_NOP : idex_t :=
    (ctrl => CTRL_NOP, pc => (others=>'0'), pc4 => (others=>'0'),
     imm => (others=>'0'), a_val => (others=>'0'), b_val => (others=>'0'),
     rs1_addr => (others=>'0'), rs2_addr => (others=>'0'), rd_addr => (others=>'0'),
     funct3 => (others=>'0'), csr_addr => (others=>'0'), instr => NOP_INSTR,
     valid => '0');
  constant EXMEM_NOP : exmem_t :=
    (reg_we => '0', mem_re => '0', mem_we => '0', wb_sel => WB_ALU,
     funct3 => (others=>'0'), result => (others=>'0'),
     store_data => (others=>'0'), rd_addr => (others=>'0'), pc => (others=>'0'),
     pc4 => (others=>'0'));
  constant MEMWB_NOP : memwb_t :=
    (reg_we => '0', wb_sel => WB_ALU, result => (others=>'0'),
     load_data => (others=>'0'), pc4 => (others=>'0'), rd_addr => (others=>'0'));

  signal pc     : word_t := (others => '0');
  signal if_id  : ifid_t := IFID_NOP;
  signal id_ex  : idex_t := IDEX_NOP;
  signal ex_mem : exmem_t := EXMEM_NOP;
  signal mem_wb : memwb_t := MEMWB_NOP;

  signal ifid_next  : ifid_t;
  signal idex_next  : idex_t;
  signal exmem_next : exmem_t;
  signal memwb_next : memwb_t;

  signal instr_if, pc4_if : word_t;

  signal ctrl_id : ctrl_t;
  signal imm_id  : word_t;
  signal rf_rs1, rf_rs2 : word_t;
  signal rs1a, rs2a, rda : reg_addr_t;

  signal fwd_a, fwd_b        : word_t;
  signal alu_a, alu_b, alu_y : word_t;
  signal ex_result           : word_t;
  signal branch_taken        : std_logic;

  -- muldiv
  signal md_start, md_done : std_logic;
  signal md_result : word_t;
  type md_state_t is (MD_IDLE, MD_BUSY);
  signal md_state : md_state_t := MD_IDLE;

  -- CSR / traps / interrupciones
  signal csr_rdata, csr_src        : word_t;
  signal csr_mtvec, csr_mepc       : word_t;
  signal csr_trap_cause            : word_t;
  signal csr_access                : std_logic;
  signal sync_trap, mret_take      : std_logic;
  signal trap_take, csr_redirect   : std_logic;
  signal irq_pending, irq_take     : std_logic;
  signal irq_cause                 : word_t;
  signal csr_illegal               : std_logic;
  signal csr_rs1z                  : std_logic;
  signal csr_trap_pc, csr_trap_tval : word_t;
  -- synchronous exceptions detected in EX / access faults detected in MEM
  signal ex_exc                    : std_logic;
  signal ex_exc_cause, ex_exc_tval : word_t;
  signal ex_ok                     : std_logic;   -- EX may act (no stall, no older trap)
  signal cf_taken                  : std_logic;   -- taken jump/branch in EX
  signal cf_tgt                    : word_t;      -- its target address
  signal mem_fault                 : std_logic;
  signal mem_access                : std_logic;
  signal md_unit_busy                   : std_logic;
  -- DMEM_SYNC: '1' once the load in MEM has spent its address cycle
  signal ld_wait                   : std_logic := '0';
  signal ld_first                  : std_logic;
  signal pc_d                      : word_t;      -- next value of pc

  -- control de flujo
  signal any_redirect : std_logic;
  signal redirect_tgt : word_t;

  signal load_data_mem : word_t;
  signal wb_data       : word_t;

  signal stall_lu, stall_md : std_logic;
  signal stall_mem          : std_logic;
  -- buffer historico de write-back: preserva el ultimo WB retirado para
  -- forwarding persistente, cubriendo el hueco cuando stall_mem aplasta
  -- mem_wb a NOP (hazard: base producida en la instruccion previa a un lw
  -- que estanca el pipeline).
  signal wbh_we   : std_logic := '0';
  signal wbh_addr : reg_addr_t := (others => '0');
  signal wbh_data : word_t := (others => '0');

begin

  ---------------------------------------------------------------------------
  -- IF
  ---------------------------------------------------------------------------
  -- Asynchronous IMEM: address = current pc. Synchronous IMEM: address = next
  -- pc, so that the SRAM output in the following cycle is the word at 'pc'.
  imem_addr <= pc_d when IMEM_SYNC else pc;
  instr_if  <= imem_instr;
  pc4_if    <= std_logic_vector(unsigned(pc) + 4);
  ifid_next <= (instr => instr_if, pc => pc, pc4 => pc4_if, valid => '1');

  ---------------------------------------------------------------------------
  -- ID
  ---------------------------------------------------------------------------
  u_ctrl : entity work.control
    port map (instr => if_id.instr, ctrl => ctrl_id);

  u_imm : entity work.immgen
    port map (instr => if_id.instr, fmt => ctrl_id.imm_fmt, imm => imm_id);

  rs1a <= if_id.instr(19 downto 15);
  rs2a <= if_id.instr(24 downto 20);
  rda  <= if_id.instr(11 downto 7);

  u_rf : entity work.regfile
    generic map (BYPASS => true)
    port map (
      clk => clk, we => mem_wb.reg_we, waddr => mem_wb.rd_addr, wdata => wb_data,
      raddr1 => rs1a, rdata1 => rf_rs1,
      raddr2 => rs2a, rdata2 => rf_rs2,
      raddr3 => dbg_reg_addr, rdata3 => dbg_reg_data
    );

  idex_next <= (
    ctrl => ctrl_id, pc => if_id.pc, pc4 => if_id.pc4, imm => imm_id,
    a_val => rf_rs1, b_val => rf_rs2,
    rs1_addr => rs1a, rs2_addr => rs2a, rd_addr => rda,
    funct3 => if_id.instr(14 downto 12), csr_addr => if_id.instr(31 downto 20),
    instr => if_id.instr, valid => if_id.valid
  );

  -- load-use: only if the instruction in ID is real and actually reads the
  -- register (LUI/JAL/immediate forms do not read the rs2 field, etc.)
  stall_lu <= '1' when ( id_ex.ctrl.mem_re = '1' and id_ex.rd_addr /= "00000" and
                         if_id.valid = '1' and
                         ((ctrl_id.use_rs1 = '1' and id_ex.rd_addr = rs1a) or
                          (ctrl_id.use_rs2 = '1' and id_ex.rd_addr = rs2a)) )
              else '0';

  ---------------------------------------------------------------------------
  -- EX : forwarding
  ---------------------------------------------------------------------------
  fwd_a <= ex_mem.result when (ex_mem.reg_we = '1' and ex_mem.mem_re = '0' and
                               ex_mem.rd_addr /= "00000" and
                               ex_mem.rd_addr = id_ex.rs1_addr) else
           wb_data       when (mem_wb.reg_we = '1' and mem_wb.rd_addr /= "00000" and
                               mem_wb.rd_addr = id_ex.rs1_addr) else
           wbh_data      when (wbh_we = '1' and wbh_addr /= "00000" and
                               wbh_addr = id_ex.rs1_addr) else
           id_ex.a_val;

  fwd_b <= ex_mem.result when (ex_mem.reg_we = '1' and ex_mem.mem_re = '0' and
                               ex_mem.rd_addr /= "00000" and
                               ex_mem.rd_addr = id_ex.rs2_addr) else
           wb_data       when (mem_wb.reg_we = '1' and mem_wb.rd_addr /= "00000" and
                               mem_wb.rd_addr = id_ex.rs2_addr) else
           wbh_data      when (wbh_we = '1' and wbh_addr /= "00000" and
                               wbh_addr = id_ex.rs2_addr) else
           id_ex.b_val;

  alu_a <= id_ex.pc  when id_ex.ctrl.alu_a_pc  = '1' else fwd_a;
  alu_b <= id_ex.imm when id_ex.ctrl.alu_b_imm = '1' else fwd_b;

  u_alu : entity work.alu
    port map (op => id_ex.ctrl.alu_op, a => alu_a, b => alu_b, y => alu_y, zero => open);

  u_md : entity work.muldiv
    port map (clk => clk, rst => rst, start => md_start, op => id_ex.ctrl.md_op,
              a => fwd_a, b => fwd_b, result => md_result, busy => md_unit_busy, done => md_done);

  -- comparador de branches
  process(id_ex, fwd_a, fwd_b)
    variable taken : std_logic;
  begin
    taken := '0';
    case id_ex.funct3 is
      when F3_BEQ  => if fwd_a = fwd_b then taken := '1'; end if;
      when F3_BNE  => if fwd_a /= fwd_b then taken := '1'; end if;
      when F3_BLT  => if signed(fwd_a)   < signed(fwd_b)   then taken := '1'; end if;
      when F3_BGE  => if signed(fwd_a)   >= signed(fwd_b)  then taken := '1'; end if;
      when F3_BLTU => if unsigned(fwd_a) < unsigned(fwd_b) then taken := '1'; end if;
      when F3_BGEU => if unsigned(fwd_a) >= unsigned(fwd_b) then taken := '1'; end if;
      when others  => taken := '0';
    end case;
    branch_taken <= taken;
  end process;

  ---------------------------------------------------------------------------
  -- EX : muldiv FSM
  ---------------------------------------------------------------------------
  -- start only into an idle unit: after an access-fault flush an abandoned
  -- operation may still be running, and its 'done' must not be taken for the
  -- next mul/div.
  md_start <= '1' when (md_state = MD_IDLE and id_ex.ctrl.is_md = '1' and md_unit_busy = '0' and
                        stall_mem = '0' and mem_fault = '0') else '0';
  stall_md <= '1' when ( (md_state = MD_IDLE and id_ex.ctrl.is_md = '1') or
                         (md_state = MD_BUSY and md_done = '0') )
              else '0';

  ---------------------------------------------------------------------------
  -- EX : CSR, traps e interrupciones
  ---------------------------------------------------------------------------
  csr_src <= std_logic_vector(resize(unsigned(id_ex.rs1_addr), XLEN))
             when id_ex.ctrl.csr_imm = '1' else fwd_a;

  -- EX may perform side effects / raise traps only when nothing stalls it
  -- and no older instruction (in MEM) is faulting.
  ex_ok <= '1' when (id_ex.valid = '1' and stall_md = '0' and stall_mem = '0' and
                     mem_fault = '0') else '0';

  -- interrupcion: solo en instruccion valida en EX, sin stalls
  irq_take <= '1' when (irq_pending = '1' and ex_ok = '1' and stall_lu = '0') else '0';

  -- taken control transfer in EX (used for the misaligned-target check)
  cf_taken <= '1' when (id_ex.ctrl.is_jal = '1' or id_ex.ctrl.is_jalr = '1' or
                        (id_ex.ctrl.is_branch = '1' and branch_taken = '1')) else '0';

  -- synchronous exceptions of the instruction in EX (priority per spec:
  -- illegal first; an instruction has at most one of the others)
  process(id_ex, csr_illegal, alu_y, cf_taken, cf_tgt)
  begin
    ex_exc       <= '0';
    ex_exc_cause <= CAUSE_ILLEGAL_INSTR;
    ex_exc_tval  <= (others => '0');
    if id_ex.ctrl.is_illegal = '1' or (id_ex.ctrl.is_csr = '1' and csr_illegal = '1') then
      ex_exc       <= '1';
      ex_exc_cause <= CAUSE_ILLEGAL_INSTR;
      ex_exc_tval  <= id_ex.instr;
    elsif id_ex.ctrl.mem_re = '1' and is_misaligned(id_ex.funct3, alu_y(1 downto 0)) then
      ex_exc       <= '1';
      ex_exc_cause <= CAUSE_LOAD_MISALIGNED;
      ex_exc_tval  <= alu_y;
    elsif id_ex.ctrl.mem_we = '1' and is_misaligned(id_ex.funct3, alu_y(1 downto 0)) then
      ex_exc       <= '1';
      ex_exc_cause <= CAUSE_STORE_MISALIGNED;
      ex_exc_tval  <= alu_y;
    elsif cf_taken = '1' and cf_tgt(1) = '1' then
      -- no C extension: targets must be 4-byte aligned (bit 0 is already
      -- cleared for JALR and always 0 for JAL/branch offsets)
      ex_exc       <= '1';
      ex_exc_cause <= CAUSE_INSTR_MISALIGNED;
      ex_exc_tval  <= cf_tgt;
    end if;
  end process;

  sync_trap   <= '1' when (ex_ok = '1' and irq_take = '0' and
                           (id_ex.ctrl.is_ecall = '1' or id_ex.ctrl.is_ebreak = '1' or ex_exc = '1'))
                 else '0';
  csr_access  <= '1' when (id_ex.ctrl.is_csr = '1' and csr_illegal = '0' and ex_exc = '0' and
                           ex_ok = '1' and irq_take = '0') else '0';
  mret_take   <= '1' when (id_ex.ctrl.is_mret = '1' and ex_ok = '1' and irq_take = '0') else '0';
  csr_redirect <= csr_access;
  trap_take    <= irq_take or sync_trap or mem_fault;

  csr_rs1z <= '1' when id_ex.rs1_addr = "00000" else '0';

  csr_trap_cause <= CAUSE_LOAD_ACCESS  when (mem_fault = '1' and ex_mem.mem_re = '1') else
                    CAUSE_STORE_ACCESS when mem_fault = '1'          else
                    irq_cause          when irq_take = '1'           else
                    ex_exc_cause       when ex_exc = '1'             else
                    CAUSE_EBREAK       when id_ex.ctrl.is_ebreak = '1' else
                    CAUSE_ECALL_M;
  csr_trap_pc   <= ex_mem.pc     when mem_fault = '1' else id_ex.pc;
  csr_trap_tval <= ex_mem.result when mem_fault = '1' else
                   ex_exc_tval   when (irq_take = '0' and ex_exc = '1') else
                   (others => '0');

  u_csr : entity work.csr
    port map (
      clk => clk, rst => rst,
      csr_addr    => id_ex.csr_addr,
      csr_wdata   => csr_src,
      csr_cmd     => id_ex.ctrl.csr_cmd,
      csr_access  => csr_access,
      csr_rs1z    => csr_rs1z,
      csr_rdata   => csr_rdata,
      csr_illegal => csr_illegal,
      trap        => trap_take,
      trap_cause  => csr_trap_cause,
      trap_pc     => csr_trap_pc,
      trap_tval   => csr_trap_tval,
      mret        => mret_take,
      irq_timer   => irq_timer,
      irq_soft    => irq_soft,
      irq_ext     => irq_ext,
      mtvec_o     => csr_mtvec,
      mepc_o      => csr_mepc,
      irq_pending => irq_pending,
      irq_cause   => irq_cause
    );

  -- resultado de EX (CSR / mul-div / ALU)
  ex_result <= csr_rdata when id_ex.ctrl.is_csr = '1' else
               md_result when id_ex.ctrl.is_md  = '1' else
               alu_y;

  -- redireccion de PC (prioridad: trap > mret > csr > salto)
  any_redirect <= '1' when ( trap_take = '1' or mret_take = '1' or csr_redirect = '1' or
                    (id_ex.valid = '1' and (id_ex.ctrl.is_jal = '1' or id_ex.ctrl.is_jalr = '1' or
                     (id_ex.ctrl.is_branch = '1' and branch_taken = '1'))) )
                  else '0';

  -- jump / branch target (also checked for alignment in EX)
  cf_tgt <= std_logic_vector(unsigned(fwd_a) + unsigned(id_ex.imm)) and x"FFFFFFFE"
              when id_ex.ctrl.is_jalr = '1' else
            std_logic_vector(unsigned(id_ex.pc) + unsigned(id_ex.imm));

  process(trap_take, mret_take, csr_redirect, id_ex, cf_tgt, csr_mtvec, csr_mepc)
  begin
    if trap_take = '1' then
      redirect_tgt <= csr_mtvec;
    elsif mret_take = '1' then
      redirect_tgt <= csr_mepc;
    elsif csr_redirect = '1' then
      redirect_tgt <= id_ex.pc4;
    else
      redirect_tgt <= cf_tgt;
    end if;
  end process;

  exmem_next <= (
    reg_we     => id_ex.ctrl.reg_we,
    mem_re     => id_ex.ctrl.mem_re,
    mem_we     => id_ex.ctrl.mem_we,
    wb_sel     => id_ex.ctrl.wb_sel,
    funct3     => id_ex.funct3,
    result     => ex_result,
    store_data => fwd_b,
    rd_addr    => id_ex.rd_addr,
    pc         => id_ex.pc,
    pc4        => id_ex.pc4
  );

  ---------------------------------------------------------------------------
  -- MEM
  ---------------------------------------------------------------------------
  dmem_addr <= ex_mem.result;

  -- request de memoria y stall por latencia variable (DDR via maestro AXI):
  -- si hay un load/store en MEM y la memoria aun no responde, congela el pipeline.
  mem_access <= '1' when (ex_mem.mem_re = '1' or ex_mem.mem_we = '1') else '0';
  -- DMEM_SYNC: first cycle of a load = SRAM address cycle (request held low
  -- so that peripherals see a single, data-phase request)
  ld_first  <= '1' when (DMEM_SYNC and ex_mem.mem_re = '1' and ld_wait = '0') else '0';
  dmem_req  <= '1' when (mem_access = '1' and ld_first = '0') else '0';
  stall_mem <= '1' when (mem_access = '1' and (ld_first = '1' or dmem_ready = '0'))
               else '0';
  -- bus error on the completing access -> precise access-fault trap
  mem_fault <= '1' when (mem_access = '1' and ld_first = '0' and dmem_ready = '1' and
                         dmem_err = '1') else '0';

  process(ex_mem)
    variable off  : natural range 0 to 3;
    variable base : std_logic_vector(3 downto 0);
  begin
    off := to_integer(unsigned(ex_mem.result(1 downto 0)));
    dmem_wdata <= std_logic_vector(shift_left(unsigned(ex_mem.store_data), off*8));
    case ex_mem.funct3 is
      when F3_B   => base := "0001";
      when F3_H   => base := "0011";
      when others => base := "1111";
    end case;
    if ex_mem.mem_we = '1' then
      dmem_wstrb <= std_logic_vector(shift_left(unsigned(base), off));
    else
      dmem_wstrb <= "0000";
    end if;
  end process;

  process(dmem_rdata, ex_mem)
    variable off     : natural range 0 to 3;
    variable shifted : word_t;
  begin
    off     := to_integer(unsigned(ex_mem.result(1 downto 0)));
    shifted := std_logic_vector(shift_right(unsigned(dmem_rdata), off*8));
    case ex_mem.funct3 is
      when F3_B   => load_data_mem <= std_logic_vector(resize(signed(shifted(7 downto 0)), XLEN));
      when F3_H   => load_data_mem <= std_logic_vector(resize(signed(shifted(15 downto 0)), XLEN));
      when F3_BU  => load_data_mem <= std_logic_vector(resize(unsigned(shifted(7 downto 0)), XLEN));
      when F3_HU  => load_data_mem <= std_logic_vector(resize(unsigned(shifted(15 downto 0)), XLEN));
      when others => load_data_mem <= dmem_rdata;
    end case;
  end process;

  memwb_next <= (
    reg_we => ex_mem.reg_we, wb_sel => ex_mem.wb_sel, result => ex_mem.result,
    load_data => load_data_mem, pc4 => ex_mem.pc4, rd_addr => ex_mem.rd_addr
  );

  ---------------------------------------------------------------------------
  -- WB
  ---------------------------------------------------------------------------
  with mem_wb.wb_sel select
    wb_data <= mem_wb.load_data when WB_MEM,
               mem_wb.pc4       when WB_PC4,
               mem_wb.result    when others;   -- WB_ALU / WB_MD / WB_CSR

  ---------------------------------------------------------------------------
  -- Siguiente PC (single source of truth: the clocked process and, with
  -- IMEM_SYNC, the IMEM address both use pc_d)
  ---------------------------------------------------------------------------
  process(rst, stall_mem, mem_fault, stall_md, stall_lu, any_redirect, redirect_tgt,
          csr_mtvec, pc, pc4_if)
  begin
    if rst = '1' then
      pc_d <= (others => '0');
    elsif stall_mem = '1' then
      pc_d <= pc;
    elsif mem_fault = '1' then
      pc_d <= csr_mtvec;
    elsif stall_md = '1' then
      pc_d <= pc;
    elsif any_redirect = '1' then
      -- before stall_lu: a misaligned load in EX traps while the instruction
      -- in ID waits for it; the trap redirect must not be lost
      pc_d <= redirect_tgt;
    elsif stall_lu = '1' then
      pc_d <= pc;
    else
      pc_d <= pc4_if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Avance del pipeline
  ---------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      -- captura del ultimo write-back retirado (forwarding persistente).
      -- Registra el mem_wb vigente, que es lo que el regfile escribe en
      -- este mismo flanco; sobrevive a los stalls que aplastan mem_wb.
      if rst = '1' then
        wbh_we <= '0'; wbh_addr <= (others => '0'); wbh_data <= (others => '0');
      elsif mem_wb.reg_we = '1' and mem_wb.rd_addr /= "00000" then
        wbh_we <= '1'; wbh_addr <= mem_wb.rd_addr; wbh_data <= wb_data;
      end if;
      pc <= pc_d;
      if rst = '1' then
        if_id    <= IFID_NOP;
        id_ex    <= IDEX_NOP;
        ex_mem   <= EXMEM_NOP;
        mem_wb   <= MEMWB_NOP;
        md_state <= MD_IDLE;
        ld_wait  <= '0';
      else
        -- DMEM_SYNC: the load in MEM has had its address cycle
        if ld_first = '1' then
          ld_wait <= '1';
        elsif stall_mem = '0' then
          ld_wait <= '0';
        end if;

        if stall_mem = '1' then
          -- acceso a memoria en vuelo (DDR): congela TODO, burbuja a WB
          if_id    <= if_id;
          id_ex    <= id_ex;
          ex_mem   <= ex_mem;
          mem_wb   <= MEMWB_NOP;
          md_state <= md_state;
        elsif mem_fault = '1' then
          -- access fault of the instruction in MEM: it does not write back,
          -- and every younger instruction is squashed (precise trap)
          mem_wb   <= MEMWB_NOP;
          ex_mem   <= EXMEM_NOP;
          id_ex    <= IDEX_NOP;
          if_id    <= IFID_NOP;
          md_state <= MD_IDLE;
        else
          case md_state is
            when MD_IDLE => if md_start = '1' then md_state <= MD_BUSY; end if;
            when MD_BUSY => if md_done = '1' then md_state <= MD_IDLE; end if;
          end case;

          mem_wb <= memwb_next;

          if stall_md = '1' then
            if_id  <= if_id;
            id_ex  <= id_ex;
            ex_mem <= EXMEM_NOP;
          else
            -- EX -> MEM: aplasta si hay trap/interrupcion
            if trap_take = '1' then
              ex_mem <= EXMEM_NOP;
            else
              ex_mem <= exmem_next;
            end if;
            -- frente del pipeline
            if any_redirect = '1' then      -- (see pc_d: redirect wins over stall_lu)
              if_id  <= IFID_NOP;
              id_ex  <= IDEX_NOP;
            elsif stall_lu = '1' then
              if_id  <= if_id;
              id_ex  <= IDEX_NOP;
            else
              if_id  <= ifid_next;
              id_ex  <= idex_next;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  dbg_pc <= pc;

end architecture rtl;
