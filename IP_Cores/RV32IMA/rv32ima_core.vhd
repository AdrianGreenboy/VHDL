-- rv32ima_core.vhd - Variante del core RV32IM con clock-enable sincrono.
-- Identica al original salvo el puerto core_clk_en_i y la guarda que
-- congela TODO el estado cuando core_clk_en_i=0. Cero cambios de logica.
-- El original ~/rv32i/rv32im_core.vhd NO se modifica.
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

entity rv32ima_core is
  generic (
    IMEM_WORDS : natural := 256;
    RESET_PC   : std_logic_vector(31 downto 0) := x"00000000"
  );
  port (
    clk_i        : in  std_logic;
    aresetn_i    : in  std_logic;
    core_clk_en_i: in  std_logic;
    -- handshake real de memoria para el modulo AMO: pulso de 1 ciclo del
    -- adaptador indicando que dmem_rdata_i es valido. Default '1' = capa
    -- de latencia cero (memoria combinacional sin adaptador).
    mem_data_done_i : in std_logic := '1';  -- '1' = avanza; '0' = congela (espera NoC)
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
    halt_o       : out std_logic;
    st_fetch_o   : out std_logic;  -- '1' cuando el core esta en S_FETCH
    st_mem_o     : out std_logic;  -- '1' cuando el core esta en S_MEM
    st_store_o   : out std_logic;  -- '1' cuando el core esta en S_STORE
    dbg_regs_o   : out std_logic_vector(1023 downto 0)  -- banco x0..x31 aplanado
  );
end entity rv32ima_core;

architecture rtl of rv32ima_core is
  type t_state is (S_FETCH, S_EXEC, S_MEM, S_STORE, S_AMO, S_WB, S_HALT);
  signal state_r : t_state := S_FETCH;

  type t_regs is array (0 to 31) of std_logic_vector(31 downto 0);
  signal x_r : t_regs := (others => (others => '0'));

  -- === integracion extension A: senales del modulo AMO ===
  signal amo_start  : std_logic := '0';
  signal amo_funct5 : std_logic_vector(4 downto 0);
  signal amo_addr   : std_logic_vector(31 downto 0);
  signal amo_src    : std_logic_vector(31 downto 0);
  signal amo_busy   : std_logic;
  signal amo_done   : std_logic;
  signal amo_result : std_logic_vector(31 downto 0);
  signal amo_m_req  : std_logic;
  signal amo_m_we   : std_logic;
  signal amo_m_addr : std_logic_vector(31 downto 0);
  signal amo_m_wdata: std_logic_vector(31 downto 0);
  signal amo_res_clear : std_logic;
  -- salidas de memoria del core (se muxean con el AMO en la salida)
  signal core_we_r : std_logic := '0';
  signal core_re_r : std_logic := '0';
  signal amo_seen_busy : std_logic := '0';  -- vio el AMO arrancar (para deteccion robusta)

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
  -- calculo de store (direccion, byte-enables, dato alineado)
  signal st_addr  : std_logic_vector(31 downto 0);
  signal st_be    : std_logic_vector(3 downto 0);
  signal st_wdata : std_logic_vector(31 downto 0);

  function rdv (x : t_regs; i : integer) return std_logic_vector is
  begin
    if i = 0 then return (31 downto 0 => '0'); else return x(i); end if;
  end function;
begin

  st_fetch_o <= '1' when state_r = S_FETCH else '0';

  -- Opcion B: durante S_AMO, las fases del modulo AMO se traducen a los
  -- estados de acceso a dato que el adaptador ya sabe servir. Asi el
  -- adaptador ve accesos ordinarios (lectura / escritura) y no necesita
  -- conocer la FSM interna del AMO ni el estado S_AMO.
  --   AMO leyendo  (m_req=1, m_we=0) -> se presenta como S_MEM   (load)
  --   AMO escribiendo (m_req=1, m_we=1) -> se presenta como S_STORE (store)
  st_mem_o   <= '1' when state_r = S_MEM
                else '1' when (state_r = S_AMO and amo_m_req = '1' and amo_m_we = '0')
                else '0';
  st_store_o <= '1' when state_r = S_STORE
                else '1' when (state_r = S_AMO and amo_m_req = '1' and amo_m_we = '1')
                else '0';

  -- banco de registros aplanado para traza de lockstep (x0 en [31:0], x1 en [63:32], ...)
  dbg_gen : for i in 0 to 31 generate
    dbg_regs_o(i*32+31 downto i*32) <= x_r(i);
  end generate;

  imem_addr_o <= std_logic_vector(pc_r);

  -- === instancia del modulo de extension A (corre en reloj pleno) ===
  u_amo : entity work.rv32_amo_unit
    port map (
      clk       => clk_i,
      rstn      => aresetn_i,
      start     => amo_start,
      funct5    => amo_funct5,
      addr      => amo_addr,
      src       => amo_src,
      res_clear => amo_res_clear,
      busy      => amo_busy,
      done      => amo_done,
      result    => amo_result,
      m_req     => amo_m_req,
      m_we      => amo_m_we,
      m_addr    => amo_m_addr,
      m_wdata   => amo_m_wdata,
      m_rdata   => dmem_rdata_i,   -- comparte el bus de lectura del core
      m_ready   => mem_data_done_i  -- handshake real (o '1' por default)
    );

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

  -- direccion de datos (valida en S_EXEC/S_MEM segun tipo), con mux del AMO:
  -- cuando el core esta en S_AMO, el bus de memoria lo maneja el modulo AMO.
  st_addr <= std_logic_vector(unsigned(a_v) + unsigned(immS));  -- dir de store
  dmem_addr_o  <= amo_m_addr when state_r = S_AMO
                  else std_logic_vector(unsigned(a_v) + unsigned(immI)) when opc = "0000011"  -- load
                  else st_addr when opc = "0100011" -- store
                  else (others => '0');

  -- byte-enables y alineacion de wdata para sb/sh/sw (contrato AXI: wstrb
  -- selecciona bytes, wdata alineado a lanes). Para AMO: palabra completa.
  st_be   <= "0001" when (opc="0100011" and f3="000" and st_addr(1 downto 0)="00")   -- sb lane0
        else "0010" when (opc="0100011" and f3="000" and st_addr(1 downto 0)="01")   -- sb lane1
        else "0100" when (opc="0100011" and f3="000" and st_addr(1 downto 0)="10")   -- sb lane2
        else "1000" when (opc="0100011" and f3="000" and st_addr(1 downto 0)="11")   -- sb lane3
        else "0011" when (opc="0100011" and f3="001" and st_addr(1)='0')             -- sh lanes 0-1
        else "1100" when (opc="0100011" and f3="001" and st_addr(1)='1')             -- sh lanes 2-3
        else "1111";  -- sw y AMO: palabra completa

  st_wdata <= std_logic_vector(shift_left(unsigned(b_v), 8*to_integer(unsigned(st_addr(1 downto 0)))))
                when (opc="0100011" and f3="000")   -- sb: alinear byte al lane
        else std_logic_vector(shift_left(unsigned(b_v), 8*to_integer(unsigned(st_addr(1 downto 0)))))
                when (opc="0100011" and f3="001")   -- sh: alinear half al lane
        else std_logic_vector(b_v);                 -- sw

  dmem_wdata_o <= amo_m_wdata when state_r = S_AMO else st_wdata;
  dmem_be_o    <= "1111" when state_r = S_AMO else st_be;
  -- mux de we/re: en S_AMO manda el modulo AMO
  dmem_we_o <= amo_m_we  when state_r = S_AMO else core_we_r;
  dmem_re_o <= amo_m_req when state_r = S_AMO else core_re_r;

  -- P3: un store normal (S_STORE) invalida la reserva lr/sc. El modulo AMO
  -- limpia r_res_valid cuando res_clear='1'. Esto da semantica correcta
  -- cuando un store (o trap que haga store) cae entre un lr.w y su sc.w.
  amo_res_clear <= '1' when state_r = S_STORE else '0';

  proc : process (clk_i, aresetn_i)
    variable alu_v : signed(31 downto 0);
    variable sh    : natural range 0 to 31;
    variable take  : boolean;
    variable ld_v  : std_logic_vector(31 downto 0);
    variable ld_addr_lo : std_logic_vector(1 downto 0);
  begin
    if aresetn_i = '0' then
      state_r <= S_FETCH;
      pc_r    <= unsigned(RESET_PC);
      ir_r    <= (others => '0');
      alu_r   <= (others => '0');
      npc_r   <= (others => '0');
      x_r     <= (others => (others => '0'));
      halt_o  <= '0';
      core_we_r <= '0';
      core_re_r <= '0';
    elsif rising_edge(clk_i) then
     if core_clk_en_i = '1' then
      core_we_r <= '0';
      core_re_r <= '0';

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
              if f7 = "0000001" then   -- extension M completa
                case f3 is
                  when "000" =>  -- MUL (baja)
                    alu_v := resize(a_v * b_v, 32);
                  when "001" =>  -- MULH (alta, signed x signed)
                    alu_v := resize(shift_right(a_v * b_v, 32), 32);
                  when "010" =>  -- MULHSU (alta, signed x unsigned)
                    alu_v := signed(std_logic_vector(resize(
                             shift_right(a_v * signed('0' & b_v), 32), 32)));
                  when "011" =>  -- MULHU (alta, unsigned x unsigned)
                    alu_v := signed(std_logic_vector(resize(
                             shift_right(unsigned(a_v) * unsigned(b_v), 32), 32)));
                  when "100" =>  -- DIV (signed)
                    if b_v = 0 then
                      alu_v := to_signed(-1, 32);
                    elsif a_v = to_signed(-2147483648, 32) and b_v = to_signed(-1, 32) then
                      alu_v := a_v;  -- overflow: devuelve el dividendo
                    else
                      alu_v := a_v / b_v;
                    end if;
                  when "101" =>  -- DIVU (unsigned)
                    if b_v = 0 then
                      alu_v := to_signed(-1, 32);  -- 0xFFFFFFFF
                    else
                      alu_v := signed(unsigned(a_v) / unsigned(b_v));
                    end if;
                  when "110" =>  -- REM (signed)
                    if b_v = 0 then
                      alu_v := a_v;
                    elsif a_v = to_signed(-2147483648, 32) and b_v = to_signed(-1, 32) then
                      alu_v := (others => '0');
                    else
                      alu_v := a_v rem b_v;
                    end if;
                  when "111" =>  -- REMU (unsigned)
                    if b_v = 0 then
                      alu_v := a_v;
                    else
                      alu_v := signed(unsigned(a_v) rem unsigned(b_v));
                    end if;
                  when others =>
                    alu_v := (others => '0');
                end case;
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
              core_re_r <= '1';
              state_r <= S_MEM;
            when "0100011" =>  -- STORE
              core_we_r <= '1';
              state_r <= S_STORE;   -- estado de espera para la escritura
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
            when "0101111" =>  -- AMO (extension A)
              -- arrancar el modulo AMO: funct5=ir[31:27], addr=rs1, src=rs2
              amo_funct5 <= ir_r(31 downto 27);
              amo_addr   <= std_logic_vector(a_v);
              amo_src    <= std_logic_vector(b_v);
              amo_start  <= '1';
              state_r <= S_AMO;
            when others =>
              -- ilegal: halt para no colgar
              halt_o <= '1';
              state_r <= S_HALT;
          end case;

        when S_MEM =>
          -- load: capturar dmem_rdata (combinacional). Primero alinear el
          -- lane segun los 2 bits bajos de la direccion, luego extender.
          ld_addr_lo := std_logic_vector(unsigned(a_v(1 downto 0)) + unsigned(immI(1 downto 0)));
          ld_v := dmem_rdata_i;
          -- shift a la derecha para llevar el byte/half objetivo a los bits bajos
          case ld_addr_lo is
            when "01"   => ld_v := x"00" & ld_v(31 downto 8);
            when "10"   => ld_v := x"0000" & ld_v(31 downto 16);
            when "11"   => ld_v := x"000000" & ld_v(31 downto 24);
            when others => null;  -- "00": ya alineado
          end case;
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

        when S_STORE =>
          -- mantener la escritura estable un ciclo; el adaptador la
          -- completa por AXI mientras el core esta congelado aqui.
          core_we_r <= '1';
          state_r <= S_FETCH;
          pc_r <= npc_r;

        when S_AMO =>
          -- el modulo AMO puede congelarse junto con el core (clk_en). Para
          -- no perder el pulso 'done' cuando cae en un ciclo congelado,
          -- detectamos la completion por 'busy' (nivel): esperamos a ver
          -- busy=1 (arranco) y luego busy=0 (termino). result es estable.
          amo_start <= '0';   -- start fue un pulso de 1 ciclo
          if amo_busy = '1' then
            amo_seen_busy <= '1';
          elsif amo_seen_busy = '1' then
            -- el AMO arranco y ya volvio a IDLE: completion robusta
            alu_r <= amo_result;
            amo_seen_busy <= '0';
            state_r <= S_WB;
            pc_r <= npc_r;
          end if;

        when S_WB =>
          if rd /= 0 then
            x_r(rd) <= alu_r;
          end if;
          -- para load/JAL/JALR el pc ya fue actualizado; para OP/OP-IMM/LUI/AUIPC
          -- actualizamos aqui.
          case opc is
            when "0000011" | "1101111" | "1100111" | "0101111" =>
              null;  -- pc ya saltado/avanzado (AMO lo actualizo en S_AMO)
            when others =>
              pc_r <= npc_r;
          end case;
          state_r <= S_FETCH;

        when S_HALT =>
          halt_o <= '1';
          state_r <= S_HALT;
      end case;
     end if;  -- core_clk_en
    end if;
  end process proc;

end architecture rtl;
