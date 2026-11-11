-- rv128_pkg.vhd - tipos, constantes, decodificador, decompresor RVC y ALU del
-- core RV128IMAC (derivado de rv64_pkg.vhd).
-- Core dual: misa.MXL se fija en el reset con la entrada m64 del core.
--   m64 = '0'  RV128 (RV128I borrador 1.7, RV128C, AMO .Q, sin Zicbom: MISC-MEM f3=010 es LQ)
--   m64 = '1'  RV64IMAC exacto (Zicbom incluido). Invariante: todo registro y todo
--              CSR contiene el valor de 64 bit extendido en signo hasta el bit 127.
-- VHDL-2008 portable (GHDL/Yosys/Vivado). Sin tablas indexadas: el decodificador
-- y el decompresor son logica pura (leccion Vivado 2025.2.1, ver RV64IMAC spec sec. 8).
-- Codificaciones: doc/RV128IMAC_ISA.md.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package rv128_pkg is
  constant XLEN : natural := 128;
  subtype xword is std_logic_vector(127 downto 0);
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
  constant C_ECALL_M  : natural := 11;
  constant C_IPAGE    : natural := 12;
  constant C_LPAGE    : natural := 13;
  constant C_SPAGE    : natural := 15;

  -- anchura de operacion de la ALU / unidad M
  constant W_Q : std_logic_vector(1 downto 0) := "00";   -- 128 bit
  constant W_W : std_logic_vector(1 downto 0) := "01";   -- *W: 32 bit, sext 31->127
  constant W_D : std_logic_vector(1 downto 0) := "10";   -- *D: 64 bit, sext 63->127

  type alu_op_t is (ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU, ALU_XOR,
                    ALU_SRL, ALU_SRA, ALU_OR, ALU_AND,
                    -- Zbb (solo modo RV128; las variantes W/D usan wsel)
                    ALU_ANDN, ALU_ORN, ALU_XNOR, ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU,
                    ALU_ROL, ALU_ROR, ALU_CLZ, ALU_CTZ, ALU_CPOP, ALU_SEXTB, ALU_SEXTH,
                    ALU_ZEXTH, ALU_REV8, ALU_ORCB);
  type asel_t is (A_RS1, A_PC, A_ZERO);
  type bsel_t is (B_RS2, B_IMM);
  type br_t is (BR_NONE, BR_EQ, BR_NE, BR_LT, BR_GE, BR_LTU, BR_GEU, BR_JAL, BR_JALR);
  type mem_t is (M_NONE, M_LOAD, M_STORE, M_AMO, M_LR, M_SC, M_CBO);   -- M_CBO: Zicbom (solo RV64)
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
    wsel     : std_logic_vector(1 downto 0);       -- W_Q / W_W / W_D
    asel     : asel_t;
    bsel     : bsel_t;
    imm      : xword;
    br       : br_t;
    mem      : mem_t;
    msize    : std_logic_vector(2 downto 0);       -- log2(bytes): 0..4 (LQ/SQ/AMO.Q = 4)
    munsign  : std_logic;
    amo_op   : std_logic_vector(4 downto 0);
    md       : std_logic;                          -- mul/div
    md_f3    : std_logic_vector(2 downto 0);
    clm      : std_logic;                          -- Zbc: clmul/clmulr/clmulh en la unidad M
    sys      : sys_t;
    csr_f3   : std_logic_vector(2 downto 0);
    csr_addr : std_logic_vector(11 downto 0);
  end record;

  constant DEC_NOP : dec_t := (
    illegal => '0', rd_we => '0', rd => "00000", rs1 => "00000", rs2 => "00000",
    use_rs1 => '0', use_rs2 => '0', alu => ALU_ADD, wsel => W_Q, asel => A_RS1,
    bsel => B_RS2, imm => XZERO, br => BR_NONE, mem => M_NONE, msize => "000",
    munsign => '0', amo_op => "00000", md => '0', md_f3 => "000", clm => '0', sys => S_NONE,
    csr_f3 => "000", csr_addr => (others => '0'));

  function sext(v : std_logic_vector; n : natural) return xword;
  -- ajusta un valor a la anchura del modo: en RV64 extiende en signo desde el bit 63
  function xf(v : xword; m64 : std_logic) return xword;
  function decode(i : std_logic_vector(31 downto 0); m64 : std_logic) return dec_t;
  -- Decompresor RVC (RV128C o RV64C segun m64): 33 bits, bit 32 = '1' si es ilegal.
  function expand_c(c : std_logic_vector(15 downto 0); m64 : std_logic) return std_logic_vector;
  function alu(op : alu_op_t; a, b : xword; wsel : std_logic_vector(1 downto 0)) return xword;
  -- ajusta un resultado a la anchura de la operacion (sext 31 o 63 -> 127)
  function wfix(r : xword; wsel : std_logic_vector(1 downto 0)) return xword;

  -- PMA. Toda direccion con pa(127 downto 32) /= 0 queda fuera del mapa.
  -- DRAM 0x8000_0000 - 0xFFFF_FFFF (2 GiB) R/W/X, idempotente, atomicos.
  function pma_dram(pa : xword) return boolean;
  -- Perifericos: CLINT, PLIC, UART, IP_Cores, ventana AXI4-Lite. R/W, no X, no atomicos.
  function pma_io(pa : xword) return boolean;
  -- Boot ROM 0x1000-0x1FFF: R/X.
  function pma_rom(pa : xword) return boolean;
end package;

package body rv128_pkg is

  function sext(v : std_logic_vector; n : natural) return xword is
    variable nv : std_logic_vector(v'length - 1 downto 0) := v;
    variable t  : std_logic_vector(n - 1 downto 0);
  begin
    t := nv(n - 1 downto 0);
    return std_logic_vector(resize(signed(t), XLEN));
  end function;

  function xf(v : xword; m64 : std_logic) return xword is
  begin
    if m64 = '1' then return sext(v(63 downto 0), 64); else return v; end if;
  end function;

  function wfix(r : xword; wsel : std_logic_vector(1 downto 0)) return xword is
  begin
    if wsel = W_W then return sext(r(31 downto 0), 32);
    elsif wsel = W_D then return sext(r(63 downto 0), 64);
    else return r; end if;
  end function;

  function pma_dram(pa : xword) return boolean is
  begin
    return pa(127 downto 31) = (127 downto 32 => '0') & '1';
  end function;

  function pma_rom(pa : xword) return boolean is
  begin
    return pa(127 downto 12) = (127 downto 13 => '0') & '1';
  end function;

  function pma_io(pa : xword) return boolean is
    variable u : unsigned(31 downto 0) := unsigned(pa(31 downto 0));
  begin
    if pa(127 downto 32) /= (127 downto 32 => '0') then
      return false;
    end if;
    return (u >= x"02000000" and u < x"02010000")     -- CLINT
        or (u >= x"0C000000" and u < x"10000000")     -- PLIC
        or (u >= x"10000000" and u < x"10001000")     -- UART
        or (u >= x"10010000" and u < x"10110000")     -- IP_Cores x16 (MMIO nativo)
        or (u >= x"20000000" and u < x"30000000");    -- ventana AXI4-Lite
  end function;

  -- ------------------------------------------------------------- Zbb: arboles
  -- ceros a la izquierda de 128 bits (128 si x = 0): busqueda binaria, 7 niveles
  function clz128(x : unsigned(127 downto 0)) return natural is
    variable v : unsigned(127 downto 0) := x;
    variable n : natural range 0 to 128 := 0;
  begin
    if v = 0 then return 128; end if;
    for l in 6 downto 0 loop
      if v(127 downto 128 - 2 ** l) = 0 then
        n := n + 2 ** l;
        v := shift_left(v, 2 ** l);
      end if;
    end loop;
    return n;
  end function;

  -- poblacion de 128 bits: arbol de sumas por bytes
  function pop128(x : unsigned(127 downto 0)) return natural is
    type c_t is array (0 to 15) of unsigned(7 downto 0);
    variable c : c_t;
    variable m : natural range 1 to 16;
  begin
    for k in 0 to 15 loop
      c(k) := (others => '0');
      for j in 0 to 7 loop
        if x(8 * k + j) = '1' then c(k) := c(k) + 1; end if;
      end loop;
    end loop;
    m := 16;
    for l in 0 to 3 loop
      m := m / 2;
      for k in 0 to 7 loop
        if k < m then c(k) := c(2 * k) + c(2 * k + 1); end if;
      end loop;
    end loop;
    return to_integer(c(0));
  end function;

  -- ------------------------------------------------------------- ALU
  -- Desplazamientos: 7 bit (Q), 6 bit (D), 5 bit (W) del operando b.
  function alu(op : alu_op_t; a, b : xword; wsel : std_logic_vector(1 downto 0)) return xword is
    variable r   : xword;
    variable sh  : natural range 0 to 127;
    variable a64 : std_logic_vector(63 downto 0);
    variable a32 : std_logic_vector(31 downto 0);
    variable w   : natural range 32 to 128;
    variable aw  : unsigned(127 downto 0);              -- a con los bits >= w a cero
    variable n   : natural range 0 to 128;
    variable rv  : unsigned(127 downto 0);
  begin
    if wsel = W_W then w := 32; elsif wsel = W_D then w := 64; else w := 128; end if;
    aw := unsigned(a);
    if w < 128 then aw(127 downto w) := (others => '0'); end if;
    if wsel = W_W then sh := to_integer(unsigned(b(4 downto 0)));
    elsif wsel = W_D then sh := to_integer(unsigned(b(5 downto 0)));
    else sh := to_integer(unsigned(b(6 downto 0))); end if;
    a64 := a(63 downto 0);
    a32 := a(31 downto 0);
    case op is
      when ALU_ADD  => r := std_logic_vector(unsigned(a) + unsigned(b));
      when ALU_SUB  => r := std_logic_vector(unsigned(a) - unsigned(b));
      when ALU_SLT  => r := (others => '0'); if signed(a) < signed(b) then r(0) := '1'; end if;
      when ALU_SLTU => r := (others => '0'); if unsigned(a) < unsigned(b) then r(0) := '1'; end if;
      when ALU_XOR  => r := a xor b;
      when ALU_OR   => r := a or b;
      when ALU_AND  => r := a and b;
      when ALU_SLL  => r := std_logic_vector(shift_left(unsigned(a), sh));
      when ALU_SRL  =>
        if wsel = W_W then r := std_logic_vector(resize(shift_right(unsigned(a32), sh), XLEN));
        elsif wsel = W_D then r := std_logic_vector(resize(shift_right(unsigned(a64), sh), XLEN));
        else r := std_logic_vector(shift_right(unsigned(a), sh)); end if;
      when ALU_SRA  =>
        if wsel = W_W then r := std_logic_vector(resize(shift_right(signed(a32), sh), XLEN));
        elsif wsel = W_D then r := std_logic_vector(resize(shift_right(signed(a64), sh), XLEN));
        else r := std_logic_vector(shift_right(signed(a), sh)); end if;
      -- Zbb
      when ALU_ANDN => r := a and not b;
      when ALU_ORN  => r := a or not b;
      when ALU_XNOR => r := not (a xor b);
      when ALU_MIN  => if signed(a) < signed(b) then r := a; else r := b; end if;
      when ALU_MINU => if unsigned(a) < unsigned(b) then r := a; else r := b; end if;
      when ALU_MAX  => if signed(a) < signed(b) then r := b; else r := a; end if;
      when ALU_MAXU => if unsigned(a) < unsigned(b) then r := b; else r := a; end if;
      when ALU_ROL | ALU_ROR =>
        -- rotacion de los w bits bajos: (aw >> k) | (aw << (w - k)), k = sh o w - sh
        if op = ALU_ROL then n := (w - sh) mod w; else n := sh; end if;
        if wsel = W_W then
          r := std_logic_vector(resize(rotate_right(unsigned(a32), n), XLEN));
        elsif wsel = W_D then
          r := std_logic_vector(resize(rotate_right(unsigned(a64), n), XLEN));
        else
          r := std_logic_vector(rotate_right(unsigned(a), n));
        end if;
      when ALU_CLZ =>
        n := clz128(aw) - (128 - w);                     -- aw = 0 -> w
        r := std_logic_vector(to_unsigned(n, XLEN));
      when ALU_CTZ =>
        if aw = 0 then n := w;
        else
          for k in 0 to 127 loop rv(k) := aw(127 - k); end loop;
          n := clz128(rv);
        end if;
        r := std_logic_vector(to_unsigned(n, XLEN));
      when ALU_CPOP =>
        r := std_logic_vector(to_unsigned(pop128(aw), XLEN));
      when ALU_SEXTB => r := sext(a(7 downto 0), 8);
      when ALU_SEXTH => r := sext(a(15 downto 0), 16);
      when ALU_ZEXTH => r := (others => '0'); r(15 downto 0) := a(15 downto 0);
      when ALU_REV8  =>
        for k in 0 to 15 loop r(8 * k + 7 downto 8 * k) := a(8 * (15 - k) + 7 downto 8 * (15 - k)); end loop;
      when ALU_ORCB  =>
        for k in 0 to 15 loop
          if a(8 * k + 7 downto 8 * k) = x"00" then r(8 * k + 7 downto 8 * k) := x"00";
          else r(8 * k + 7 downto 8 * k) := x"FF"; end if;
        end loop;
    end case;
    return wfix(r, wsel);
  end function;

  -- ------------------------------------------------------------- decode
  function decode(i : std_logic_vector(31 downto 0); m64 : std_logic) return dec_t is
    variable d    : dec_t := DEC_NOP;
    variable op   : std_logic_vector(6 downto 0) := i(6 downto 0);
    variable f3   : std_logic_vector(2 downto 0) := i(14 downto 12);
    variable f7   : std_logic_vector(6 downto 0) := i(31 downto 25);
    variable f5   : std_logic_vector(4 downto 0) := i(31 downto 27);
    variable immi, imms, immb, immu, immj : xword;
    variable ws   : std_logic_vector(1 downto 0);
    variable nar  : boolean;                         -- opcode *W / *D (no base)
    variable wb   : std_logic_vector(1 downto 0);    -- anchura de las ops base del modo
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
    d.msize := '0' & f3(1 downto 0);
    d.munsign := f3(2);
    d.amo_op := f5;
    -- anchura: base = 128 (RV128) o 64 (RV64); *W = 32; *D = 64 (solo RV128)
    if m64 = '1' then wb := W_D; else wb := W_Q; end if;
    if op = "0011011" or op = "0111011" then ws := W_W; nar := true;
    elsif op = "1011011" or op = "1111011" then ws := W_D; nar := true;
    else ws := wb; nar := false; end if;
    case op is
      when "0110111" =>                                      -- LUI
        d.rd_we := '1'; d.asel := A_ZERO; d.bsel := B_IMM; d.imm := immu; d.wsel := wb;
      when "0010111" =>                                      -- AUIPC
        d.rd_we := '1'; d.asel := A_PC; d.bsel := B_IMM; d.imm := immu; d.wsel := wb;
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
      when "0000011" =>                                      -- LOAD (f3=111: LDU)
        d.rd_we := '1'; d.use_rs1 := '1'; d.mem := M_LOAD; d.imm := immi;
        if m64 = '1' and f3 = "111" then d.illegal := '1'; end if;        -- LDU: solo RV128
      when "0100011" =>                                      -- STORE (f3=100: SQ)
        d.use_rs1 := '1'; d.use_rs2 := '1'; d.mem := M_STORE; d.imm := imms;
        d.msize := f3; d.munsign := '0';
        if f3(2) = '1' and (f3(1 downto 0) /= "00" or m64 = '1') then d.illegal := '1'; end if;
      when "0010011" | "0011011" | "1011011" =>              -- OP-IMM / -32 / -64
        d.rd_we := '1'; d.use_rs1 := '1'; d.bsel := B_IMM; d.imm := immi; d.wsel := ws;
        if m64 = '1' and op = "1011011" then d.illegal := '1'; end if;      -- *D: solo RV128
        case f3 is
          when "000" => d.alu := ALU_ADD;
          when "010" => d.alu := ALU_SLT;  if nar then d.illegal := '1'; end if;
          when "011" => d.alu := ALU_SLTU; if nar then d.illegal := '1'; end if;
          when "100" => d.alu := ALU_XOR;  if nar then d.illegal := '1'; end if;
          when "110" => d.alu := ALU_OR;   if nar then d.illegal := '1'; end if;
          when "111" => d.alu := ALU_AND;  if nar then d.illegal := '1'; end if;
          when "001" =>
            d.alu := ALU_SLL;
            if m64 = '0' and i(31 downto 20) = x"600" then d.alu := ALU_CLZ;       -- Zbb (W, D)
            elsif m64 = '0' and i(31 downto 20) = x"601" then d.alu := ALU_CTZ;
            elsif m64 = '0' and i(31 downto 20) = x"602" then d.alu := ALU_CPOP;
            elsif m64 = '0' and ws = W_Q and i(31 downto 20) = x"604" then d.alu := ALU_SEXTB;
            elsif m64 = '0' and ws = W_Q and i(31 downto 20) = x"605" then d.alu := ALU_SEXTH;
            elsif ws = W_Q then
              if i(31 downto 27) /= "00000" then d.illegal := '1'; end if;
            elsif ws = W_D then
              if i(31 downto 26) /= "000000" then d.illegal := '1'; end if;
            else
              if i(31 downto 25) /= "0000000" then d.illegal := '1'; end if;
            end if;
          when others =>                                     -- "101"
            if m64 = '0' and ((ws = W_Q and i(31 downto 27) = "01100") or
                              (ws = W_D and i(31 downto 26) = "011000") or
                              (ws = W_W and i(31 downto 25) = "0110000")) then
              d.alu := ALU_ROR;                              -- rori / rorid / roriw
            elsif m64 = '0' and ws = W_Q and i(31 downto 20) = x"6F8" then
              d.alu := ALU_REV8;
            elsif m64 = '0' and ws = W_Q and i(31 downto 20) = x"287" then
              d.alu := ALU_ORCB;
            else
              if i(30) = '1' then d.alu := ALU_SRA; else d.alu := ALU_SRL; end if;
              if i(31) = '1' or i(29 downto 27) /= "000" then d.illegal := '1'; end if;
              if ws = W_D and i(26) = '1' then d.illegal := '1'; end if;
              if ws = W_W and i(26 downto 25) /= "00" then d.illegal := '1'; end if;
            end if;
        end case;
      when "0110011" | "0111011" | "1111011" =>              -- OP / OP-32 / OP-64
        d.rd_we := '1'; d.use_rs1 := '1'; d.use_rs2 := '1'; d.wsel := ws;
        if m64 = '1' and op = "1111011" then d.illegal := '1'; end if;      -- *D: solo RV128
        if f7 = "0000001" then
          d.md := '1';
          if nar and (f3 = "001" or f3 = "010" or f3 = "011") then d.illegal := '1'; end if;
        elsif f7 = "0000000" then
          case f3 is
            when "000" => d.alu := ALU_ADD;
            when "001" => d.alu := ALU_SLL;
            when "010" => d.alu := ALU_SLT;  if nar then d.illegal := '1'; end if;
            when "011" => d.alu := ALU_SLTU; if nar then d.illegal := '1'; end if;
            when "100" => d.alu := ALU_XOR;  if nar then d.illegal := '1'; end if;
            when "101" => d.alu := ALU_SRL;
            when "110" => d.alu := ALU_OR;   if nar then d.illegal := '1'; end if;
            when others => d.alu := ALU_AND; if nar then d.illegal := '1'; end if;
          end case;
        elsif f7 = "0100000" and f3 = "000" then
          d.alu := ALU_SUB;
        elsif f7 = "0100000" and f3 = "101" then
          d.alu := ALU_SRA;
        -- Zbb / Zbc (solo modo RV128)
        elsif m64 = '0' and f7 = "0100000" and not nar and f3 = "111" then d.alu := ALU_ANDN;
        elsif m64 = '0' and f7 = "0100000" and not nar and f3 = "110" then d.alu := ALU_ORN;
        elsif m64 = '0' and f7 = "0100000" and not nar and f3 = "100" then d.alu := ALU_XNOR;
        elsif m64 = '0' and f7 = "0110000" and f3 = "001" then d.alu := ALU_ROL;
        elsif m64 = '0' and f7 = "0110000" and f3 = "101" then d.alu := ALU_ROR;
        elsif m64 = '0' and f7 = "0000101" and not nar and f3(2) = '1' then
          case f3(1 downto 0) is
            when "00" => d.alu := ALU_MIN;
            when "01" => d.alu := ALU_MINU;
            when "10" => d.alu := ALU_MAX;
            when others => d.alu := ALU_MAXU;
          end case;
        elsif m64 = '0' and f7 = "0000101" and not nar and f3 /= "000" then
          d.md := '1'; d.clm := '1';                         -- clmul / clmulr / clmulh
        elsif m64 = '0' and f7 = "0000100" and ws = W_D and f3 = "100" and i(24 downto 20) = "00000" then
          d.alu := ALU_ZEXTH; d.use_rs2 := '0';               -- zext.h (RV128: OP-64)
        else
          d.illegal := '1';
        end if;
      when "0101111" =>                                      -- AMO (.W .D .Q)
        d.rd_we := '1'; d.use_rs1 := '1'; d.use_rs2 := '1';
        d.msize := f3; d.munsign := '0';
        if f3 /= "010" and f3 /= "011" and (f3 /= "100" or m64 = '1') then d.illegal := '1'; end if;
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
        elsif f3 = "010" and m64 = '1' then                  -- RV64: Zicbom cbo.inval/clean/flush
          d.mem := M_CBO; d.use_rs1 := '1'; d.imm := XZERO;
          d.amo_op := "000" & i(21 downto 20);               -- 00 inval, 01 clean, 10 flush
          if i(11 downto 7) /= "00000" or i(31 downto 22) /= "0000000000" or i(21 downto 20) = "11" then
            d.illegal := '1';
          end if;
        elsif f3 = "010" then                                -- RV128: LQ
          d.rd_we := '1'; d.use_rs1 := '1'; d.mem := M_LOAD; d.imm := immi;
          d.msize := "100"; d.munsign := '0';
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
          d.imm := (127 downto 5 => '0') & i(19 downto 15);  -- zimm
        end if;
      when others =>
        d.illegal := '1';
    end case;
    if d.illegal = '1' then
      d.rd_we := '0'; d.mem := M_NONE; d.sys := S_NONE; d.br := BR_NONE; d.md := '0';
    end if;
    return d;
  end function;

  -- ------------------------------------------------------------- RVC (RV128C)
  -- Cambios respecto a RV64C: C.LQ/C.SQ (cuadrante 0, f3 001/101), C.LQSP/C.SQSP
  -- (cuadrante 2, f3 001/101), C.SLLI con shamt 0 = 64, C.SRLI/C.SRAI con shamt
  -- extendido en signo y 0 = 64 (1-31, 64, 96-127).
  function expand_c(c : std_logic_vector(15 downto 0); m64 : std_logic) return std_logic_vector is
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
    variable shl7  : std_logic_vector(6 downto 0);
    variable shr7  : std_logic_vector(6 downto 0);
  begin
    imm6 := (11 downto 5 => c(12)) & c(6 downto 2);
    sh   := c(12) & c(6 downto 2);
    if m64 = '1' then
      shl7 := '0' & sh; shr7 := '0' & sh;                    -- RV64C: 6 bit sin signo, 0 = HINT
    elsif sh = "000000" then
      shl7 := "1000000"; shr7 := "1000000";                  -- RV128C: 0 = 64
    else
      shl7 := '0' & sh; shr7 := sh(5) & sh;                  -- izq: zext; der: sext
    end if;
    case q is
      when "00" =>
        case f3 is
          when "000" =>                                      -- c.addi4spn
            u := "00" & c(10 downto 7) & c(12 downto 11) & c(5) & c(6) & "00";
            if u = x"000" then bad := '1'; end if;
            r := u & "00010" & "000" & rs2p & "0010011";
          when "001" =>                                      -- c.lq (RV64: c.fld, sin D)
            if m64 = '1' then bad := '1'; end if;
            u := "000" & c(10) & c(6 downto 5) & c(12 downto 11) & "0000";
            r := u & rdp & "010" & rs2p & "0001111";
          when "010" =>                                      -- c.lw
            u := "00000" & c(5) & c(12 downto 10) & c(6) & "00";
            r := u & rdp & "010" & rs2p & "0000011";
          when "011" =>                                      -- c.ld
            u := "0000" & c(6 downto 5) & c(12 downto 10) & "000";
            r := u & rdp & "011" & rs2p & "0000011";
          when "101" =>                                      -- c.sq (RV64: c.fsd, sin D)
            if m64 = '1' then bad := '1'; end if;
            u := "000" & c(10) & c(6 downto 5) & c(12 downto 11) & "0000";
            r := u(11 downto 5) & rs2p & rdp & "100" & u(4 downto 0) & "0100011";
          when "110" =>                                      -- c.sw
            u := "00000" & c(5) & c(12 downto 10) & c(6) & "00";
            r := u(11 downto 5) & rs2p & rdp & "010" & u(4 downto 0) & "0100011";
          when "111" =>                                      -- c.sd
            u := "0000" & c(6 downto 5) & c(12 downto 10) & "000";
            r := u(11 downto 5) & rs2p & rdp & "011" & u(4 downto 0) & "0100011";
          when others => bad := '1';                         -- "100" reservado
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
              when "00" => r := "00000" & shr7 & rdp & "101" & rdp & "0010011";   -- c.srli
              when "01" => r := "01000" & shr7 & rdp & "101" & rdp & "0010011";   -- c.srai
              when "10" => r := imm6 & rdp & "111" & rdp & "0010011";              -- c.andi
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
            r := "00000" & shl7 & rd & "001" & rd & "0010011";
          when "001" =>                                      -- c.lqsp (RV64: c.fldsp)
            if rd = "00000" or m64 = '1' then bad := '1'; end if;
            u := "00" & c(5 downto 2) & c(12) & c(6) & "0000";
            r := u & "00010" & "010" & rd & "0001111";
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
          when "101" =>                                      -- c.sqsp (RV64: c.fsdsp)
            if m64 = '1' then bad := '1'; end if;
            u := "00" & c(10 downto 7) & c(12 downto 11) & "0000";
            r := u(11 downto 5) & rs2 & "00010" & "100" & u(4 downto 0) & "0100011";
          when "110" =>                                      -- c.swsp
            u := "0000" & c(8 downto 7) & c(12 downto 9) & "00";
            r := u(11 downto 5) & rs2 & "00010" & "010" & u(4 downto 0) & "0100011";
          when others =>                                     -- c.sdsp
            u := "000" & c(9 downto 7) & c(12 downto 10) & "000";
            r := u(11 downto 5) & rs2 & "00010" & "011" & u(4 downto 0) & "0100011";
        end case;
      when others => bad := '1';
    end case;
    return bad & r;
  end function;

end package body;
