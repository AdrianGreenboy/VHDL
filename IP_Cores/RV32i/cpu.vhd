-- =============================================================================
--  cpu.vhd  -  Datapath RV32IM single-cycle (con stall en mul/div)
--  Licencia: MIT
--
--  Cada instruccion retira en un ciclo, EXCEPTO mul/div: al detectar una
--  instruccion de la extension M, el PC se congela y se espera el 'done' de la
--  unidad muldiv (handshake), retirando la instruccion cuando el resultado esta
--  listo. El resto del datapath es clasico: IF -> decode -> read -> exec ->
--  (mem) -> writeback, todo combinacional dentro del ciclo.
--
--  Memorias externas al core (imem/dmem) se instancian en el nivel superior de
--  simulacion o de sintesis. Puerto de depuracion para inspeccionar registros.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity cpu is
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;                 -- reset sincrono, activo alto

    -- interfaz a memoria de instrucciones (asincrona)
    imem_addr  : out word_t;
    imem_instr : in  word_t;

    -- interfaz a memoria de datos
    dmem_addr  : out word_t;
    dmem_wdata : out word_t;
    dmem_wstrb : out std_logic_vector(3 downto 0);
    dmem_rdata : in  word_t;

    -- lineas de interrupcion (del CLINT / externas)
    irq_timer  : in  std_logic := '0';
    irq_soft   : in  std_logic := '0';
    irq_ext    : in  std_logic := '0';

    -- depuracion
    dbg_reg_addr : in  reg_addr_t := (others => '0');
    dbg_reg_data : out word_t;
    dbg_pc       : out word_t
  );
end entity cpu;

architecture rtl of cpu is

  -- registro de programa
  signal pc, pc4, next_pc : word_t := (others => '0');

  -- decode
  signal instr : word_t;
  signal ctrl  : ctrl_t;
  signal imm   : word_t;

  -- registros
  signal rs1, rs2 : word_t;
  signal rd_addr  : reg_addr_t;
  signal reg_we_g : std_logic;
  signal wb_data  : word_t;

  -- ALU
  signal alu_a, alu_b, alu_y : word_t;

  -- muldiv
  signal md_start, md_busy, md_done : std_logic;
  signal md_result : word_t;

  -- control de flujo
  signal branch_taken : std_logic;

  -- memoria de datos
  signal load_data : word_t;

  -- CSR / traps
  signal csr_rdata, csr_src        : word_t;
  signal csr_mtvec, csr_mepc       : word_t;
  signal csr_access                : std_logic;
  signal trap_fire, mret_fire      : std_logic;
  signal trap_cause                : word_t;
  -- interrupciones
  signal irq_pending, irq_take     : std_logic;
  signal irq_cause                 : word_t;
  signal commit                    : std_logic;
  signal sync_trap                 : std_logic;

  -- FSM de stall para mul/div
  type state_t is (RUN, MDWAIT);
  signal state  : state_t := RUN;
  signal retire : std_logic;

begin

  ---------------------------------------------------------------------------
  -- Decode + inmediatos
  ---------------------------------------------------------------------------
  u_ctrl : entity work.control
    port map (instr => instr, ctrl => ctrl);

  u_imm : entity work.immgen
    port map (instr => instr, fmt => ctrl.imm_fmt, imm => imm);

  instr      <= imem_instr;
  imem_addr  <= pc;
  rd_addr    <= instr(11 downto 7);

  ---------------------------------------------------------------------------
  -- Register file (con puerto de depuracion)
  ---------------------------------------------------------------------------
  u_rf : entity work.regfile
    port map (
      clk    => clk,
      we     => reg_we_g,
      waddr  => rd_addr,
      wdata  => wb_data,
      raddr1 => instr(19 downto 15),
      rdata1 => rs1,
      raddr2 => instr(24 downto 20),
      rdata2 => rs2,
      raddr3 => dbg_reg_addr,
      rdata3 => dbg_reg_data
    );

  ---------------------------------------------------------------------------
  -- ALU
  ---------------------------------------------------------------------------
  alu_a <= pc  when ctrl.alu_a_pc  = '1' else rs1;
  alu_b <= imm when ctrl.alu_b_imm = '1' else rs2;

  u_alu : entity work.alu
    port map (op => ctrl.alu_op, a => alu_a, b => alu_b, y => alu_y, zero => open);

  ---------------------------------------------------------------------------
  -- Unidad mul/div
  ---------------------------------------------------------------------------
  u_md : entity work.muldiv
    port map (
      clk => clk, rst => rst, start => md_start, op => ctrl.md_op,
      a => rs1, b => rs2, result => md_result, busy => md_busy, done => md_done
    );

  ---------------------------------------------------------------------------
  -- CSRs y traps (Zicsr + modo maquina)
  ---------------------------------------------------------------------------
  -- fuente del CSR: zimm (campo rs1) para las variantes inmediatas, si no rs1
  csr_src <= std_logic_vector(resize(unsigned(instr(19 downto 15)), XLEN))
             when ctrl.csr_imm = '1' else rs1;

  -- una interrupcion se toma en un limite de instruccion (estado RUN)
  irq_take <= '1' when (irq_pending = '1' and state = RUN) else '0';

  -- commit: la instruccion escribe su estado (se suprime si hay interrupcion)
  commit <= '1' when (retire = '1' and irq_take = '0') else '0';

  csr_access <= '1' when (ctrl.is_csr = '1' and commit = '1') else '0';
  sync_trap  <= '1' when ((ctrl.is_ecall = '1' or ctrl.is_ebreak = '1') and commit = '1') else '0';
  mret_fire  <= '1' when (ctrl.is_mret = '1' and commit = '1') else '0';

  trap_fire  <= irq_take or sync_trap;
  trap_cause <= irq_cause    when irq_take = '1'       else
                CAUSE_EBREAK when ctrl.is_ebreak = '1' else
                CAUSE_ECALL_M;

  u_csr : entity work.csr
    port map (
      clk => clk, rst => rst,
      csr_addr    => instr(31 downto 20),
      csr_wdata   => csr_src,
      csr_cmd     => ctrl.csr_cmd,
      csr_access  => csr_access,
      csr_rdata   => csr_rdata,
      trap        => trap_fire,
      trap_cause  => trap_cause,
      trap_pc     => pc,
      mret        => mret_fire,
      irq_timer   => irq_timer,
      irq_soft    => irq_soft,
      irq_ext     => irq_ext,
      mtvec_o     => csr_mtvec,
      mepc_o      => csr_mepc,
      irq_pending => irq_pending,
      irq_cause   => irq_cause
    );

  ---------------------------------------------------------------------------
  -- Comparador de saltos condicionales (usa funct3 = instr[14:12])
  ---------------------------------------------------------------------------
  process(instr, rs1, rs2)
    variable taken : std_logic;
  begin
    taken := '0';
    case instr(14 downto 12) is
      when F3_BEQ  => if rs1 = rs2 then taken := '1'; end if;
      when F3_BNE  => if rs1 /= rs2 then taken := '1'; end if;
      when F3_BLT  => if signed(rs1)   < signed(rs2)   then taken := '1'; end if;
      when F3_BGE  => if signed(rs1)   >= signed(rs2)  then taken := '1'; end if;
      when F3_BLTU => if unsigned(rs1) < unsigned(rs2) then taken := '1'; end if;
      when F3_BGEU => if unsigned(rs1) >= unsigned(rs2) then taken := '1'; end if;
      when others  => taken := '0';
    end case;
    branch_taken <= taken;
  end process;

  ---------------------------------------------------------------------------
  -- Siguiente PC
  ---------------------------------------------------------------------------
  pc4 <= std_logic_vector(unsigned(pc) + 4);

  process(pc, pc4, imm, rs1, ctrl, branch_taken, trap_fire, mret_fire, csr_mtvec, csr_mepc)
  begin
    if trap_fire = '1' then
      next_pc <= csr_mtvec;                          -- entra al manejador
    elsif mret_fire = '1' then
      next_pc <= csr_mepc;                           -- retorna del manejador
    elsif ctrl.is_jal = '1' then
      next_pc <= std_logic_vector(unsigned(pc) + unsigned(imm));
    elsif ctrl.is_jalr = '1' then
      next_pc <= std_logic_vector(unsigned(rs1) + unsigned(imm)) and x"FFFFFFFE";
    elsif ctrl.is_branch = '1' and branch_taken = '1' then
      next_pc <= std_logic_vector(unsigned(pc) + unsigned(imm));
    else
      next_pc <= pc4;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Memoria de datos: direccion, alineamiento de store, extension de load
  ---------------------------------------------------------------------------
  dmem_addr <= alu_y;

  -- store: alinea el dato y arma los byte-enables segun funct3 y offset
  process(alu_y, rs2, instr, ctrl, commit, rst)
    variable off  : natural range 0 to 3;
    variable base : std_logic_vector(3 downto 0);
  begin
    off := to_integer(unsigned(alu_y(1 downto 0)));
    dmem_wdata <= std_logic_vector(shift_left(unsigned(rs2), off*8));
    case instr(14 downto 12) is
      when F3_B   => base := "0001";
      when F3_H   => base := "0011";
      when others => base := "1111";   -- F3_W
    end case;
    if ctrl.mem_we = '1' and commit = '1' and rst = '0' then
      dmem_wstrb <= std_logic_vector(shift_left(unsigned(base), off));
    else
      dmem_wstrb <= "0000";
    end if;
  end process;

  -- load: alinea la palabra leida y extiende segun funct3
  process(dmem_rdata, alu_y, instr)
    variable off     : natural range 0 to 3;
    variable shifted : word_t;
  begin
    off     := to_integer(unsigned(alu_y(1 downto 0)));
    shifted := std_logic_vector(shift_right(unsigned(dmem_rdata), off*8));
    case instr(14 downto 12) is
      when F3_B  => load_data <= std_logic_vector(resize(signed(shifted(7 downto 0)), XLEN));
      when F3_H  => load_data <= std_logic_vector(resize(signed(shifted(15 downto 0)), XLEN));
      when F3_BU => load_data <= std_logic_vector(resize(unsigned(shifted(7 downto 0)), XLEN));
      when F3_HU => load_data <= std_logic_vector(resize(unsigned(shifted(15 downto 0)), XLEN));
      when others => load_data <= dmem_rdata;   -- F3_W
    end case;
  end process;

  ---------------------------------------------------------------------------
  -- Writeback mux
  ---------------------------------------------------------------------------
  with ctrl.wb_sel select
    wb_data <= alu_y     when WB_ALU,
               load_data when WB_MEM,
               pc4       when WB_PC4,
               md_result when WB_MD,
               csr_rdata when WB_CSR;

  ---------------------------------------------------------------------------
  -- FSM de stall para mul/div, escritura de registro y avance de PC
  ---------------------------------------------------------------------------
  md_start <= '1' when (state = RUN and ctrl.is_md = '1' and irq_take = '0') else '0';

  retire <= '1' when ( (state = RUN    and ctrl.is_md = '0') or
                       (state = MDWAIT and md_done   = '1') ) else '0';

  reg_we_g <= '1' when (ctrl.reg_we = '1' and commit = '1') else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pc    <= (others => '0');
        state <= RUN;
      else
        case state is
          when RUN =>
            if irq_take = '1' then
              pc <= next_pc;            -- salta a mtvec, aplasta la instruccion
            elsif ctrl.is_md = '1' then
              state <= MDWAIT;          -- congela PC, espera a muldiv
            else
              pc <= next_pc;
            end if;
          when MDWAIT =>
            if md_done = '1' then
              pc    <= next_pc;         -- para mul/div = pc+4
              state <= RUN;
            end if;
        end case;
      end if;
    end if;
  end process;

  dbg_pc <= pc;

end architecture rtl;
