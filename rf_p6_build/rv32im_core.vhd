-- rv32im_core.vhd - Core RV32IM multiciclo (fetch-decode-exec-mem-wb en pasos).
-- Contrato de memoria de la familia:
--   * IMEM: puerto de solo lectura sincrono (instr valida 1 ciclo tras addr).
--     Aqui se lee combinacional del arreglo cargado por generic/init file.
--   * DMEM/MMIO: escritura sincrona (we + addr + wdata); LECTURA COMBINACIONAL
--     (dmem_rdata refleja el estado ACTUAL). El core presenta dmem_addr y en el
--     paso MEM captura dmem_rdata en el mismo ciclo (load) -> exige rdata comb.
-- Halt por ECALL (0x00000073): activa halt_o y detiene el avance.
-- Subset: LUI,AUIPC,ADDI/ANDI/ORI/XORI/SLTI/SLTIU/SLLI/SRLI/SRAI, R-type
--   (ADD,SUB,AND,OR,XOR,SLL,SRL,SRA,SLT,SLTU,MUL), loads/stores, branches,
--   JAL, JALR, ECALL. Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rv32im_core is
  generic (
    IMEM_WORDS : natural := 256
  );
  port (
    clk_i        : in  std_logic;
    aresetn_i    : in  std_logic;
    -- puerto de instrucciones (imem externo, lectura combinacional)
    imem_addr_o  : out std_logic_vector(31 downto 0);
    imem_data_i  : in  std_logic_vector(31 downto 0);
    -- puerto de datos (dmem + MMIO), lectura COMBINACIONAL
    dmem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_wdata_o : out std_logic_vector(31 downto 0);
    dmem_we_o    : out std_logic;
    dmem_re_o    : out std_logic;
    dmem_be_o    : out std_logic_vector(3 downto 0);
    dmem_rdata_i : in  std_logic_vector(31 downto 0);
    halt_o       : out std_logic
  );
end entity rv32im_core;

architecture rtl of rv32im_core is
  type t_state is (S_FETCH, S_EXEC, S_MEM, S_WB, S_HALT);
  signal state_r : t_state := S_FETCH;

  type t_regs is array (0 to 31) of std_logic_vector(31 downto 0);
  signal x_r : t_regs := (others => (others => '0'));

  signal pc_r   : unsigned(31 downto 0) := (others => '0');
  signal ir_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal alu_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal npc_r  : unsigned(31 downto 0) := (others => '0');

  -- campos de decodificacion
  signal opc  : std_logic_vector(6 downto 0);
  signal rd   : integer range 0 to 31;
  signal rs1  : integer range 0 to 31;
  signal rs2  : integer range 0 to 31;
  signal f3   : std_logic_vector(2 downto 0);
  signal f7   : std_logic_vector(6 downto 0);
  signal immI, immS, immB, immU, immJ : signed(31 downto 0);
  signal a_v, b_v : signed(31 downto 0);

  function rdv (x : t_regs; i : integer) return std_logic_vector is
  begin
    if i = 0 then return (31 downto 0 => '0'); else return x(i); end if;
  end function;
begin

  imem_addr_o <= std_logic_vector(pc_r);

  opc <= ir_r(6 downto 0);
  rd  <= to_integer(unsigned(ir_r(11 downto 7)));
  rs1 <= to_integer(unsigned(ir_r(19 downto 15)));
  rs2 <= to_integer(unsigned(ir_r(24 downto 20)));
  f3  <= ir_r(14 downto 12);
  f7  <= ir_r(31 downto 25);

  immI <= resize(signed(ir_r(31 downto 20)), 32);
  immS <= resize(signed(std_logic_vector'(ir_r(31 downto 25) & ir_r(11 downto 7))), 32);
  immB <= resize(signed(std_logic_vector'(ir_r(31) & ir_r(7) & ir_r(30 downto 25) & ir_r(11 downto 8) & '0')), 32);
  immU <= shift_left(resize(signed(ir_r(31 downto 12)), 32), 12);
  immJ <= resize(signed(std_logic_vector'(ir_r(31) & ir_r(19 downto 12) & ir_r(20) & ir_r(30 downto 21) & '0')), 32);

  a_v <= signed(rdv(x_r, rs1));
  b_v <= signed(rdv(x_r, rs2));

  -- direccion de datos (valida en S_EXEC/S_MEM segun tipo)
  dmem_addr_o  <= std_logic_vector(unsigned(a_v) + unsigned(immI)) when opc = "0000011"  -- load
                  else std_logic_vector(unsigned(a_v) + unsigned(immS)) when opc = "0100011" -- store
                  else (others => '0');
  dmem_wdata_o <= std_logic_vector(b_v);
  dmem_be_o    <= "1111";

  proc : process (clk_i, aresetn_i)
    variable alu_v : signed(31 downto 0);
    variable sh    : natural range 0 to 31;
    variable take  : boolean;
    variable ld_v  : std_logic_vector(31 downto 0);
  begin
    if aresetn_i = '0' then
      state_r <= S_FETCH;
      pc_r    <= (others => '0');
      ir_r    <= (others => '0');
      alu_r   <= (others => '0');
      npc_r   <= (others => '0');
      x_r     <= (others => (others => '0'));
      halt_o  <= '0';
      dmem_we_o <= '0';
      dmem_re_o <= '0';
    elsif rising_edge(clk_i) then
      dmem_we_o <= '0';
      dmem_re_o <= '0';

      case state_r is
        when S_FETCH =>
          ir_r  <= imem_data_i;      -- lectura combinacional del imem
          npc_r <= pc_r + 4;
          state_r <= S_EXEC;

        when S_EXEC =>
          -- ALU y decision de salto; para load/store se pasa a S_MEM
          take := false;
          case opc is
            when "0110111" =>  -- LUI
              alu_r <= std_logic_vector(immU);
              state_r <= S_WB;
            when "0010111" =>  -- AUIPC
              alu_r <= std_logic_vector(unsigned(immU) + pc_r);
              state_r <= S_WB;
            when "0010011" =>  -- OP-IMM
              sh := to_integer(unsigned(ir_r(24 downto 20)));
              case f3 is
                when "000" => alu_v := a_v + immI;                      -- ADDI
                when "111" => alu_v := a_v and immI;                    -- ANDI
                when "110" => alu_v := a_v or immI;                     -- ORI
                when "100" => alu_v := a_v xor immI;                    -- XORI
                when "010" => alu_v := (0=>'1',others=>'0') when a_v<immI else (others=>'0'); -- SLTI
                when "011" =>                                           -- SLTIU
                  if unsigned(a_v) < unsigned(immI) then alu_v:=to_signed(1,32); else alu_v:=(others=>'0'); end if;
                when "001" => alu_v := signed(shift_left(unsigned(a_v), sh));   -- SLLI
                when "101" =>
                  if f7(5)='1' then alu_v := shift_right(a_v, sh);             -- SRAI
                  else alu_v := signed(shift_right(unsigned(a_v), sh)); end if; -- SRLI
                when others => alu_v := (others=>'0');
              end case;
              alu_r <= std_logic_vector(alu_v);
              state_r <= S_WB;
            when "0110011" =>  -- OP
              sh := to_integer(unsigned(b_v(4 downto 0)));
              if f7 = "0000001" then   -- MUL
                alu_v := resize(a_v * b_v, 32);
              else
                case f3 is
                  when "000" =>
                    if f7(5)='1' then alu_v := a_v - b_v; else alu_v := a_v + b_v; end if;
                  when "111" => alu_v := a_v and b_v;
                  when "110" => alu_v := a_v or b_v;
                  when "100" => alu_v := a_v xor b_v;
                  when "001" => alu_v := signed(shift_left(unsigned(a_v), sh));
                  when "101" =>
                    if f7(5)='1' then alu_v := shift_right(a_v, sh);
                    else alu_v := signed(shift_right(unsigned(a_v), sh)); end if;
                  when "010" =>
                    if a_v < b_v then alu_v:=to_signed(1,32); else alu_v:=(others=>'0'); end if;
                  when "011" =>
                    if unsigned(a_v) < unsigned(b_v) then alu_v:=to_signed(1,32); else alu_v:=(others=>'0'); end if;
                  when others => alu_v := (others=>'0');
                end case;
              end if;
              alu_r <= std_logic_vector(alu_v);
              state_r <= S_WB;
            when "0000011" =>  -- LOAD
              dmem_re_o <= '1';
              state_r <= S_MEM;
            when "0100011" =>  -- STORE
              dmem_we_o <= '1';
              state_r <= S_FETCH;
              pc_r <= npc_r;
            when "1100011" =>  -- BRANCH
              case f3 is
                when "000" => take := (a_v = b_v);
                when "001" => take := (a_v /= b_v);
                when "100" => take := (a_v < b_v);
                when "101" => take := (a_v >= b_v);
                when "110" => take := (unsigned(a_v) < unsigned(b_v));
                when "111" => take := (unsigned(a_v) >= unsigned(b_v));
                when others => take := false;
              end case;
              if take then pc_r <= pc_r + unsigned(immB); else pc_r <= npc_r; end if;
              state_r <= S_FETCH;
            when "1101111" =>  -- JAL
              alu_r <= std_logic_vector(npc_r);
              pc_r  <= pc_r + unsigned(immJ);
              state_r <= S_WB;   -- escribe rd = npc en WB, pc ya saltado
            when "1100111" =>  -- JALR
              alu_r <= std_logic_vector(npc_r);
              pc_r  <= unsigned(a_v + immI) and not to_unsigned(1,32);
              state_r <= S_WB;
            when "1110011" =>  -- ECALL
              halt_o <= '1';
              state_r <= S_HALT;
            when others =>
              -- ilegal: halt para no colgar
              halt_o <= '1';
              state_r <= S_HALT;
          end case;

        when S_MEM =>
          -- load: capturar dmem_rdata (combinacional) con extension segun f3
          ld_v := dmem_rdata_i;
          case f3 is
            when "000" =>  -- LB
              if ld_v(7)='1' then ld_v := x"FFFFFF" & ld_v(7 downto 0); else ld_v := x"000000" & ld_v(7 downto 0); end if;
            when "001" =>  -- LH
              if ld_v(15)='1' then ld_v := x"FFFF" & ld_v(15 downto 0); else ld_v := x"0000" & ld_v(15 downto 0); end if;
            when "100" =>  -- LBU
              ld_v := x"000000" & ld_v(7 downto 0);
            when "101" =>  -- LHU
              ld_v := x"0000" & ld_v(15 downto 0);
            when others => null;  -- LW
          end case;
          alu_r <= ld_v;
          state_r <= S_WB;
          pc_r <= npc_r;

        when S_WB =>
          if rd /= 0 then
            x_r(rd) <= alu_r;
          end if;
          -- para load/JAL/JALR el pc ya fue actualizado; para OP/OP-IMM/LUI/AUIPC
          -- actualizamos aqui.
          case opc is
            when "0000011" | "1101111" | "1100111" =>
              null;  -- pc ya saltado/avanzado
            when others =>
              pc_r <= npc_r;
          end case;
          state_r <= S_FETCH;

        when S_HALT =>
          halt_o <= '1';
          state_r <= S_HALT;
      end case;
    end if;
  end process proc;

end architecture rtl;
