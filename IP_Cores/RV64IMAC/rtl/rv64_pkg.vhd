-- rv64_pkg.vhd - tipos, constantes, decodificador y decompresor del core RV64IMAC.
-- VHDL-2008 portable (GHDL/Yosys/Vivado). Sin tablas indexadas: el
-- decodificador y el decompresor son logica pura (ver SPEC_FREEZE_V1 sec. 8).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package rv64_pkg is
  subtype xword is std_logic_vector(63 downto 0);
  constant XZERO : xword := (others => '0');

  -- privilegios
  constant PRV_U : std_logic_vector(1 downto 0) := "00";
  constant PRV_S : std_logic_vector(1 downto 0) := "01";
  constant PRV_M : std_logic_vector(1 downto 0) := "11";

  -- causas
  constant C_IACCESS  : natural := 1;
  constant C_ILLEGAL  : natural := 2;
  constant C_BREAK    : natural := 3;
  constant C_LMISAL   : natural := 4;
  constant C_LACCESS  : natural := 5;
  constant C_SMISAL   : natural := 6;
  constant C_SACCESS  : natural := 7;
  constant C_ECALL_U  : natural := 8;
  constant C_IPAGE    : natural := 12;
  constant C_LPAGE    : natural := 13;
  constant C_SPAGE    : natural := 15;

  type alu_op_t is (ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU, ALU_XOR,
                    ALU_SRL, ALU_SRA, ALU_OR, ALU_AND);
  type asel_t is (A_RS1, A_PC, A_ZERO);
  type bsel_t is (B_RS2, B_IMM);
  type br_t is (BR_NONE, BR_EQ, BR_NE, BR_LT, BR_GE, BR_LTU, BR_GEU, BR_JAL, BR_JALR);
  type mem_t is (M_NONE, M_LOAD, M_STORE, M_AMO, M_LR, M_SC, M_CBO);   -- M_CBO: Zicbom
  type sys_t is (S_NONE, S_ECALL, S_EBREAK, S_MRET, S_SRET, S_WFI, S_SFENCE, S_FENCEI, S_CSR);

  type dec_t is record
    illegal  : std_logic;
    rd_we    : std_logic;
    rd       : std_logic_vector(4 downto 0);
    rs1      : std_logic_vector(4 downto 0);
    rs2      : std_logic_vector(4 downto 0);
    use_rs1  : std_logic;
    use_rs2  : std_logic;
    alu      : alu_op_t;
    is_w     : std_logic;
    asel     : asel_t;
    bsel     : bsel_t;
    imm      : xword;
    br       : br_t;
    mem      : mem_t;
    msize    : std_logic_vector(1 downto 0);
    munsign  : std_logic;
    amo_op   : std_logic_vector(4 downto 0);
    md       : std_logic;                       -- mul/div
    md_f3    : std_logic_vector(2 downto 0);
    sys      : sys_t;
    csr_f3   : std_logic_vector(2 downto 0);
    csr_addr : std_logic_vector(11 downto 0);
  end record;

  constant DEC_NOP : dec_t := (
    illegal => '0', rd_we => '0', rd => "00000", rs1 => "00000", rs2 => "00000",
    use_rs1 => '0', use_rs2 => '0', alu => ALU_ADD, is_w => '0', asel => A_RS1,
    bsel => B_RS2, imm => XZERO, br => BR_NONE, mem => M_NONE, msize => "00",
    munsign => '0', amo_op => "00000", md => '0', md_f3 => "000", sys => S_NONE,
    csr_f3 => "000", csr_addr => (others => '0'));

  function sext(v : std_logic_vector; n : natural) return xword;
  function decode(i : std_logic_vector(31 downto 0)) return dec_t;
  -- Decompresor: devuelve 33 bits, bit 32 = '1' si la codificacion es ilegal.
  function expand_c(c : std_logic_vector(15 downto 0)) return std_logic_vector;
  function alu(op : alu_op_t; a, b : xword; is_w : std_logic) return xword;

  -- PMA: DRAM 0x8000_0000 - 0xFFFF_FFFF (2 GiB) R/W/X, idempotente, atomicos.
  function pma_dram(pa : xword) return boolean;
  -- Perifericos: CLINT, PLIC, UART, IP_Cores, ventana AXI4-Lite. R/W, no X, no atomicos.
  function pma_io(pa : xword) return boolean;
  -- Boot ROM 0x1000-0x1FFF: R/X.
  function pma_rom(pa : xword) return boolean;
end package;

package body rv64_pkg is

  function sext(v : std_logic_vector; n : natural) return xword is
    -- normaliza la direccion: una concatenacion puede llegar como (0 to N-1)
    variable nv : std_logic_vector(v'length - 1 downto 0) := v;
    variable t  : std_logic_vector(n - 1 downto 0);
  begin
    t := nv(n - 1 downto 0);
    return std_logic_vector(resize(signed(t), 64));
  end function;

  function pma_dram(pa : xword) return boolean is
  begin
    return pa(63 downto 31) = "000000000000000000000000000000001";
  end function;

  function pma_rom(pa : xword) return boolean is
  begin
    return pa(63 downto 12) = x"0000000000001";
  end function;

  function pma_io(pa : xword) return boolean is
    variable u : unsigned(63 downto 0) := unsigned(pa);
  begin
    return (u >= x"0000000002000000" and u < x"0000000002010000")     -- CLINT
        or (u >= x"000000000C000000" and u < x"0000000010000000")     -- PLIC
        or (u >= x"0000000010000000" and u < x"0000000010001000")     -- UART
        or (u >= x"0000000010010000" and u < x"0000000010110000")     -- IP_Cores x16 (MMIO nativo)
        or (u >= x"0000000020000000" and u < x"0000000030000000");    -- ventana AXI4-Lite
  end function;

  -- ------------------------------------------------------------- ALU
  function alu(op : alu_op_t; a, b : xword; is_w : std_logic) return xword is
    variable r   : xword;
    variable sh  : natural range 0 to 63;
    variable shw : natural range 0 to 31;
    variable a32 : std_logic_vector(31 downto 0);
  begin
    sh  := to_integer(unsigned(b(5 downto 0)));
    shw := to_integer(unsigned(b(4 downto 0)));
    a32 := a(31 downto 0);
    case op is
      when ALU_ADD  => r := std_logic_vector(unsigned(a) + unsigned(b));
      when ALU_SUB  => r := std_logic_vector(unsigned(a) - unsigned(b));
      when ALU_SLT  => r := (others => '0'); if signed(a) < signed(b) then r(0) := '1'; end if;
      when ALU_SLTU => r := (others => '0'); if unsigned(a) < unsigned(b) then r(0) := '1'; end if;
      when ALU_XOR  => r := a xor b;
      when ALU_OR   => r := a or b;
      when ALU_AND  => r := a and b;
      when ALU_SLL  =>
        if is_w = '1' then r := std_logic_vector(resize(shift_left(unsigned(a32), shw), 64));
        else r := std_logic_vector(shift_left(unsigned(a), sh)); end if;
      when ALU_SRL  =>
        if is_w = '1' then r := std_logic_vector(resize(shift_right(unsigned(a32), shw), 64));
        else r := std_logic_vector(shift_right(unsigned(a), sh)); end if;
      when ALU_SRA  =>
        if is_w = '1' then r := std_logic_vector(resize(shift_right(signed(a32), shw), 64));
        else r := std_logic_vector(shift_right(signed(a), sh)); end if;
    end case;
    if is_w = '1' then
      r := sext(r(31 downto 0), 32);
    end if;
    return r;
  end function;

  -- ------------------------------------------------------------- decode
  function decode(i : std_logic_vector(31 downto 0)) return dec_t is
    variable d    : dec_t := DEC_NOP;
    variable op   : std_logic_vector(6 downto 0) := i(6 downto 0);
    variable f3   : std_logic_vector(2 downto 0) := i(14 downto 12);
    variable f7   : std_logic_vector(6 downto 0) := i(31 downto 25);
    variable f5   : std_logic_vector(4 downto 0) := i(31 downto 27);
    variable immi, imms, immb, immu, immj : xword;
  begin
    immi := sext(i(31 downto 20), 12);
    imms := sext(i(31 downto 25) & i(11 downto 7), 12);
    immb := sext(i(31) & i(7) & i(30 downto 25) & i(11 downto 8) & '0', 13);
    immu := sext(i(31 downto 12) & x"000", 32);
    immj := sext(i(31) & i(19 downto 12) & i(20) & i(30 downto 21) & '0', 21);
    d.rd  := i(11 downto 7);
    d.rs1 := i(19 downto 15);
    d.rs2 := i(24 downto 20);
    d.csr_addr := i(31 downto 20);
    d.csr_f3 := f3;
    d.md_f3 := f3;
    d.msize := f3(1 downto 0);
    d.munsign := f3(2);
    d.amo_op := f5;
    case op is
      when "0110111" =>                                      -- LUI
        d.rd_we := '1'; d.asel := A_ZERO; d.bsel := B_IMM; d.imm := immu;
      when "0010111" =>                                      -- AUIPC
        d.rd_we := '1'; d.asel := A_PC; d.bsel := B_IMM; d.imm := immu;
      when "1101111" =>                                      -- JAL
        d.rd_we := '1'; d.br := BR_JAL; d.imm := immj;
      when "1100111" =>                                      -- JALR
        d.rd_we := '1'; d.br := BR_JALR; d.use_rs1 := '1'; d.imm := immi;
        if f3 /= "000" then d.illegal := '1'; end if;
      when "1100011" =>                                      -- BRANCH
        d.use_rs1 := '1'; d.use_rs2 := '1'; d.imm := immb;
        case f3 is
          when "000" => d.br := BR_EQ;
          when "001" => d.br := BR_NE;
          when "100" => d.br := BR_LT;
          when "101" => d.br := BR_GE;
          when "110" => d.br := BR_LTU;
          when "111" => d.br := BR_GEU;
          when others => d.illegal := '1';
        end case;
      when "0000011" =>                                      -- LOAD
        d.rd_we := '1'; d.use_rs1 := '1'; d.mem := M_LOAD; d.imm := immi;
        if f3 = "111" then d.illegal := '1'; end if;
      when "0100011" =>                                      -- STORE
        d.use_rs1 := '1'; d.use_rs2 := '1'; d.mem := M_STORE; d.imm := imms;
        if f3(2) = '1' then d.illegal := '1'; end if;
      when "0010011" | "0011011" =>                          -- OP-IMM / OP-IMM-32
        d.rd_we := '1'; d.use_rs1 := '1'; d.bsel := B_IMM; d.imm := immi;
        d.is_w := op(3);
        case f3 is
          when "000" => d.alu := ALU_ADD;
          when "010" => d.alu := ALU_SLT;  if op(3) = '1' then d.illegal := '1'; end if;
          when "011" => d.alu := ALU_SLTU; if op(3) = '1' then d.illegal := '1'; end if;
          when "100" => d.alu := ALU_XOR;  if op(3) = '1' then d.illegal := '1'; end if;
          when "110" => d.alu := ALU_OR;   if op(3) = '1' then d.illegal := '1'; end if;
          when "111" => d.alu := ALU_AND;  if op(3) = '1' then d.illegal := '1'; end if;
          when "001" =>
            d.alu := ALU_SLL;
            if i(31 downto 26) /= "000000" or (op(3) = '1' and i(25) = '1') then d.illegal := '1'; end if;
          when others =>                                     -- "101"
            if i(30) = '1' then d.alu := ALU_SRA; else d.alu := ALU_SRL; end if;
            if (i(31) or i(29) or i(28) or i(27) or i(26)) = '1' or (op(3) = '1' and i(25) = '1') then
              d.illegal := '1';
            end if;
        end case;
      when "0110011" | "0111011" =>                          -- OP / OP-32
        d.rd_we := '1'; d.use_rs1 := '1'; d.use_rs2 := '1'; d.is_w := op(3);
        if f7 = "0000001" then
          d.md := '1';
          if op(3) = '1' and (f3 = "001" or f3 = "010" or f3 = "011") then d.illegal := '1'; end if;
        elsif f7 = "0000000" then
          case f3 is
            when "000" => d.alu := ALU_ADD;
            when "001" => d.alu := ALU_SLL;
            when "010" => d.alu := ALU_SLT;  if op(3) = '1' then d.illegal := '1'; end if;
            when "011" => d.alu := ALU_SLTU; if op(3) = '1' then d.illegal := '1'; end if;
            when "100" => d.alu := ALU_XOR;  if op(3) = '1' then d.illegal := '1'; end if;
            when "101" => d.alu := ALU_SRL;
            when "110" => d.alu := ALU_OR;   if op(3) = '1' then d.illegal := '1'; end if;
            when others => d.alu := ALU_AND; if op(3) = '1' then d.illegal := '1'; end if;
          end case;
        elsif f7 = "0100000" and f3 = "000" then
          d.alu := ALU_SUB;
        elsif f7 = "0100000" and f3 = "101" then
          d.alu := ALU_SRA;
        else
          d.illegal := '1';
        end if;
      when "0101111" =>                                      -- AMO
        d.rd_we := '1'; d.use_rs1 := '1'; d.use_rs2 := '1';
        if f3 /= "010" and f3 /= "011" then d.illegal := '1'; end if;
        case f5 is
          when "00010" => d.mem := M_LR; d.use_rs2 := '0';
                          if i(24 downto 20) /= "00000" then d.illegal := '1'; end if;
          when "00011" => d.mem := M_SC;
          when "00000" | "00001" | "00100" | "01000" | "01100" |
               "10000" | "10100" | "11000" | "11100" => d.mem := M_AMO;
          when others => d.illegal := '1';
        end case;
      when "0001111" =>                                      -- MISC-MEM
        if f3 = "001" then d.sys := S_FENCEI;
        elsif f3 = "010" then                                -- Zicbom: cbo.inval/clean/flush
          d.mem := M_CBO; d.use_rs1 := '1'; d.imm := XZERO;
          d.amo_op := "000" & i(21 downto 20);               -- 00 inval, 01 clean, 10 flush
          if i(11 downto 7) /= "00000" or i(31 downto 22) /= "0000000000" or i(21 downto 20) = "11" then
            d.illegal := '1';
          end if;
        elsif f3 /= "000" then d.illegal := '1'; end if;
      when "1110011" =>                                      -- SYSTEM
        if f3 = "000" then
          if i = x"00000073" then d.sys := S_ECALL;
          elsif i = x"00100073" then d.sys := S_EBREAK;
          elsif i = x"30200073" then d.sys := S_MRET;
          elsif i = x"10200073" then d.sys := S_SRET;
          elsif i = x"10500073" then d.sys := S_WFI;
          elsif f7 = "0001001" and i(11 downto 7) = "00000" then d.sys := S_SFENCE;
          else d.illegal := '1'; end if;
        elsif f3 = "100" then
          d.illegal := '1';
        else
          d.sys := S_CSR; d.rd_we := '1';
          d.use_rs1 := not f3(2);
          d.imm := (63 downto 5 => '0') & i(19 downto 15);   -- zimm
        end if;
      when others =>
        d.illegal := '1';
    end case;
    if d.illegal = '1' then
      d.rd_we := '0'; d.mem := M_NONE; d.sys := S_NONE; d.br := BR_NONE; d.md := '0';
    end if;
    return d;
  end function;

  -- ------------------------------------------------------------- RVC
  function expand_c(c : std_logic_vector(15 downto 0)) return std_logic_vector is
    variable r     : std_logic_vector(31 downto 0) := (others => '0');
    variable bad   : std_logic := '0';
    variable q     : std_logic_vector(1 downto 0) := c(1 downto 0);
    variable f3    : std_logic_vector(2 downto 0) := c(15 downto 13);
    variable rd    : std_logic_vector(4 downto 0) := c(11 downto 7);
    variable rs2   : std_logic_vector(4 downto 0) := c(6 downto 2);
    variable rdp   : std_logic_vector(4 downto 0) := "01" & c(9 downto 7);
    variable rs2p  : std_logic_vector(4 downto 0) := "01" & c(4 downto 2);
    variable imm6  : std_logic_vector(11 downto 0);
    variable u     : std_logic_vector(11 downto 0);
    variable b13   : std_logic_vector(12 downto 0);
    variable j21   : std_logic_vector(20 downto 0);
    variable sh    : std_logic_vector(5 downto 0);
  begin
    imm6 := (11 downto 5 => c(12)) & c(6 downto 2);
    sh   := c(12) & c(6 downto 2);
    case q is
      when "00" =>
        case f3 is
          when "000" =>                                      -- c.addi4spn
            u := "00" & c(10 downto 7) & c(12 downto 11) & c(5) & c(6) & "00";
            if u = x"000" then bad := '1'; end if;
            r := u & "00010" & "000" & rs2p & "0010011";
          when "010" =>                                      -- c.lw
            u := "00000" & c(5) & c(12 downto 10) & c(6) & "00";
            r := u & rdp & "010" & rs2p & "0000011";
          when "011" =>                                      -- c.ld
            u := "0000" & c(6 downto 5) & c(12 downto 10) & "000";
            r := u & rdp & "011" & rs2p & "0000011";
          when "110" =>                                      -- c.sw
            u := "00000" & c(5) & c(12 downto 10) & c(6) & "00";
            r := u(11 downto 5) & rs2p & rdp & "010" & u(4 downto 0) & "0100011";
          when "111" =>                                      -- c.sd
            u := "0000" & c(6 downto 5) & c(12 downto 10) & "000";
            r := u(11 downto 5) & rs2p & rdp & "011" & u(4 downto 0) & "0100011";
          when others => bad := '1';
        end case;
      when "01" =>
        case f3 is
          when "000" =>                                      -- c.addi / c.nop
            r := imm6 & rd & "000" & rd & "0010011";
          when "001" =>                                      -- c.addiw
            if rd = "00000" then bad := '1'; end if;
            r := imm6 & rd & "000" & rd & "0011011";
          when "010" =>                                      -- c.li
            r := imm6 & "00000" & "000" & rd & "0010011";
          when "011" =>
            if rd = "00010" then                             -- c.addi16sp
              u := (11 downto 10 => c(12)) & c(12) & c(4 downto 3) & c(5) & c(2) & c(6) & "0000";
              if u = x"000" then bad := '1'; end if;
              r := u & "00010" & "000" & "00010" & "0010011";
            else                                             -- c.lui
              if (c(12) & c(6 downto 2)) = "000000" then bad := '1'; end if;
              r := (31 downto 17 => c(12)) & c(6 downto 2) & rd & "0110111";
            end if;
          when "100" =>
            case c(11 downto 10) is
              when "00" => r := "000000" & sh & rdp & "101" & rdp & "0010011";   -- c.srli
              when "01" => r := "010000" & sh & rdp & "101" & rdp & "0010011";   -- c.srai
              when "10" => r := imm6 & rdp & "111" & rdp & "0010011";             -- c.andi
              when others =>
                if c(12) = '0' then
                  case c(6 downto 5) is
                    when "00" => r := "0100000" & rs2p & rdp & "000" & rdp & "0110011";
                    when "01" => r := "0000000" & rs2p & rdp & "100" & rdp & "0110011";
                    when "10" => r := "0000000" & rs2p & rdp & "110" & rdp & "0110011";
                    when others => r := "0000000" & rs2p & rdp & "111" & rdp & "0110011";
                  end case;
                else
                  case c(6 downto 5) is
                    when "00" => r := "0100000" & rs2p & rdp & "000" & rdp & "0111011";
                    when "01" => r := "0000000" & rs2p & rdp & "000" & rdp & "0111011";
                    when others => bad := '1';
                  end case;
                end if;
            end case;
          when "101" =>                                      -- c.j
            j21 := (20 downto 11 => c(12)) & c(8) & c(10 downto 9) & c(6) & c(7) & c(2) & c(11) & c(5 downto 3) & '0';
            r := j21(20) & j21(10 downto 1) & j21(11) & j21(19 downto 12) & "00000" & "1101111";
          when others =>                                     -- c.beqz / c.bnez
            b13 := (12 downto 9 => c(12)) & c(12) & c(6 downto 5) & c(2) & c(11 downto 10) & c(4 downto 3) & '0';
            r := b13(12) & b13(10 downto 5) & "00000" & rdp & "00" & f3(0) & b13(4 downto 1) & b13(11) & "1100011";
        end case;
      when "10" =>
        case f3 is
          when "000" =>                                      -- c.slli
            r := "000000" & sh & rd & "001" & rd & "0010011";
          when "010" =>                                      -- c.lwsp
            if rd = "00000" then bad := '1'; end if;
            u := "0000" & c(3 downto 2) & c(12) & c(6 downto 4) & "00";
            r := u & "00010" & "010" & rd & "0000011";
          when "011" =>                                      -- c.ldsp
            if rd = "00000" then bad := '1'; end if;
            u := "000" & c(4 downto 2) & c(12) & c(6 downto 5) & "000";
            r := u & "00010" & "011" & rd & "0000011";
          when "100" =>
            if c(12) = '0' then
              if rs2 = "00000" then                          -- c.jr
                if rd = "00000" then bad := '1'; end if;
                r := x"000" & rd & "000" & "00000" & "1100111";
              else                                           -- c.mv
                r := "0000000" & rs2 & "00000" & "000" & rd & "0110011";
              end if;
            else
              if rs2 = "00000" then
                if rd = "00000" then                         -- c.ebreak
                  r := x"00100073";
                else                                         -- c.jalr
                  r := x"000" & rd & "000" & "00001" & "1100111";
                end if;
              else                                           -- c.add
                r := "0000000" & rs2 & rd & "000" & rd & "0110011";
              end if;
            end if;
          when "110" =>                                      -- c.swsp
            u := "0000" & c(8 downto 7) & c(12 downto 9) & "00";
            r := u(11 downto 5) & rs2 & "00010" & "010" & u(4 downto 0) & "0100011";
          when "111" =>                                      -- c.sdsp
            u := "000" & c(9 downto 7) & c(12 downto 10) & "000";
            r := u(11 downto 5) & rs2 & "00010" & "011" & u(4 downto 0) & "0100011";
          when others => bad := '1';
        end case;
      when others => bad := '1';
    end case;
    return bad & r;
  end function;

end package body;
