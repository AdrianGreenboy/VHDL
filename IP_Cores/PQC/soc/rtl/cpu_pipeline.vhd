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
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity cpu_pipeline is
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
     funct3 => (others=>'0'), csr_addr => (others=>'0'), valid => '0');
  constant EXMEM_NOP : exmem_t :=
    (reg_we => '0', mem_re => '0', mem_we => '0', wb_sel => WB_ALU,
     funct3 => (others=>'0'), result => (others=>'0'),
     store_data => (others=>'0'), rd_addr => (others=>'0'), pc4 => (others=>'0'));
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

  -- control de flujo
  signal any_redirect : std_logic;
  signal redirect_tgt : word_t;

  signal load_data_mem : word_t;
  signal wb_data       : word_t;

  signal stall_lu, stall_md : std_logic;
  signal stall_mem          : std_logic;

begin

  ---------------------------------------------------------------------------
  -- IF
  ---------------------------------------------------------------------------
  imem_addr <= pc;
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
    valid => if_id.valid
  );

  stall_lu <= '1' when ( id_ex.ctrl.mem_re = '1' and id_ex.rd_addr /= "00000" and
                         (id_ex.rd_addr = rs1a or id_ex.rd_addr = rs2a) )
              else '0';

  ---------------------------------------------------------------------------
  -- EX : forwarding
  ---------------------------------------------------------------------------
  fwd_a <= ex_mem.result when (ex_mem.reg_we = '1' and ex_mem.mem_re = '0' and
                               ex_mem.rd_addr /= "00000" and
                               ex_mem.rd_addr = id_ex.rs1_addr) else
           wb_data       when (mem_wb.reg_we = '1' and mem_wb.rd_addr /= "00000" and
                               mem_wb.rd_addr = id_ex.rs1_addr) else
           id_ex.a_val;

  fwd_b <= ex_mem.result when (ex_mem.reg_we = '1' and ex_mem.mem_re = '0' and
                               ex_mem.rd_addr /= "00000" and
                               ex_mem.rd_addr = id_ex.rs2_addr) else
           wb_data       when (mem_wb.reg_we = '1' and mem_wb.rd_addr /= "00000" and
                               mem_wb.rd_addr = id_ex.rs2_addr) else
           id_ex.b_val;

  alu_a <= id_ex.pc  when id_ex.ctrl.alu_a_pc  = '1' else fwd_a;
  alu_b <= id_ex.imm when id_ex.ctrl.alu_b_imm = '1' else fwd_b;

  u_alu : entity work.alu
    port map (op => id_ex.ctrl.alu_op, a => alu_a, b => alu_b, y => alu_y, zero => open);

  u_md : entity work.muldiv
    port map (clk => clk, rst => rst, start => md_start, op => id_ex.ctrl.md_op,
              a => fwd_a, b => fwd_b, result => md_result, busy => open, done => md_done);

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
  md_start <= '1' when (md_state = MD_IDLE and id_ex.ctrl.is_md = '1') else '0';
  stall_md <= '1' when ( (md_state = MD_IDLE and id_ex.ctrl.is_md = '1') or
                         (md_state = MD_BUSY and md_done = '0') )
              else '0';

  ---------------------------------------------------------------------------
  -- EX : CSR, traps e interrupciones
  ---------------------------------------------------------------------------
  csr_src <= std_logic_vector(resize(unsigned(id_ex.rs1_addr), XLEN))
             when id_ex.ctrl.csr_imm = '1' else fwd_a;

  -- interrupcion: solo en instruccion valida en EX, sin stalls
  irq_take <= '1' when (irq_pending = '1' and id_ex.valid = '1' and
                        stall_md = '0' and stall_lu = '0' and stall_mem = '0') else '0';

  sync_trap   <= '1' when ((id_ex.ctrl.is_ecall = '1' or id_ex.ctrl.is_ebreak = '1')
                           and id_ex.valid = '1' and stall_md = '0' and stall_mem = '0' and irq_take = '0') else '0';
  csr_access  <= '1' when (id_ex.ctrl.is_csr = '1' and id_ex.valid = '1'
                           and stall_md = '0' and stall_mem = '0' and irq_take = '0') else '0';
  mret_take   <= '1' when (id_ex.ctrl.is_mret = '1' and id_ex.valid = '1'
                           and stall_md = '0' and stall_mem = '0' and irq_take = '0') else '0';
  csr_redirect <= csr_access;
  trap_take    <= irq_take or sync_trap;

  csr_trap_cause <= irq_cause    when irq_take = '1'             else
                    CAUSE_EBREAK when id_ex.ctrl.is_ebreak = '1' else
                    CAUSE_ECALL_M;

  u_csr : entity work.csr
    port map (
      clk => clk, rst => rst,
      csr_addr    => id_ex.csr_addr,
      csr_wdata   => csr_src,
      csr_cmd     => id_ex.ctrl.csr_cmd,
      csr_access  => csr_access,
      csr_rdata   => csr_rdata,
      trap        => trap_take,
      trap_cause  => csr_trap_cause,
      trap_pc     => id_ex.pc,
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

  process(trap_take, mret_take, csr_redirect, id_ex, fwd_a, csr_mtvec, csr_mepc)
  begin
    if trap_take = '1' then
      redirect_tgt <= csr_mtvec;
    elsif mret_take = '1' then
      redirect_tgt <= csr_mepc;
    elsif csr_redirect = '1' then
      redirect_tgt <= id_ex.pc4;
    elsif id_ex.ctrl.is_jalr = '1' then
      redirect_tgt <= std_logic_vector(unsigned(fwd_a) + unsigned(id_ex.imm)) and x"FFFFFFFE";
    else
      redirect_tgt <= std_logic_vector(unsigned(id_ex.pc) + unsigned(id_ex.imm));
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
    pc4        => id_ex.pc4
  );

  ---------------------------------------------------------------------------
  -- MEM
  ---------------------------------------------------------------------------
  dmem_addr <= ex_mem.result;

  -- request de memoria y stall por latencia variable (DDR via maestro AXI):
  -- si hay un load/store en MEM y la memoria aun no responde, congela el pipeline.
  dmem_req  <= '1' when (ex_mem.mem_re = '1' or ex_mem.mem_we = '1') else '0';
  stall_mem <= '1' when ((ex_mem.mem_re = '1' or ex_mem.mem_we = '1') and dmem_ready = '0')
               else '0';

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
  -- Avance del pipeline
  ---------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pc       <= (others => '0');
        if_id    <= IFID_NOP;
        id_ex    <= IDEX_NOP;
        ex_mem   <= EXMEM_NOP;
        mem_wb   <= MEMWB_NOP;
        md_state <= MD_IDLE;
      else
        if stall_mem = '1' then
          -- acceso a memoria en vuelo (DDR): congela TODO, burbuja a WB
          pc       <= pc;
          if_id    <= if_id;
          id_ex    <= id_ex;
          ex_mem   <= ex_mem;
          mem_wb   <= MEMWB_NOP;
          md_state <= md_state;
        else
          case md_state is
            when MD_IDLE => if id_ex.ctrl.is_md = '1' then md_state <= MD_BUSY; end if;
            when MD_BUSY => if md_done = '1' then md_state <= MD_IDLE; end if;
          end case;

          mem_wb <= memwb_next;

          if stall_md = '1' then
            pc     <= pc;
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
            if stall_lu = '1' then
              pc     <= pc;
              if_id  <= if_id;
              id_ex  <= IDEX_NOP;
            elsif any_redirect = '1' then
              pc     <= redirect_tgt;
              if_id  <= IFID_NOP;
              id_ex  <= IDEX_NOP;
            else
              pc     <= pc4_if;
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
