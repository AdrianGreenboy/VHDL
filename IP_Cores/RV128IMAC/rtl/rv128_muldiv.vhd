-- rv128_muldiv.vhd - unidad M del RV128IMAC. Misma interfaz y protocolo que la de RV64IMAC.
-- Protocolo: 'start' con la unidad libre captura operandos; 'done' se mantiene con 'result'
-- estable hasta 'ack'. 'kill' aborta en cualquier momento.
--
-- FAST = false (portable a ASIC, sin DSP; la unidad original):
--   multiplicacion radix-4: 64 iteraciones (128 bit), 32 (MULD y modo RV64), 16 (MULW);
--   division con restauracion radix-2: 128 iteraciones, 64 (variantes D), 32 (W).
-- FAST = true (FPGA):
--   multiplicacion con un multiplicador 64x64 -> 128 (DSP58 en Versal) registrado, que se
--   reutiliza para los productos parciales necesarios: ll, lh, hl, hh. Se omiten los de una
--   mitad nula y los que no afectan al resultado (hh en MUL; lh/hl/hh en *W/*D, cuyos
--   operandos caben en 64 bit). Latencia start->done: 3 ciclos (un parcial) .. 6 (cuatro).
--   division normalizada: se salta los ceros a la izquierda del dividendo y precarga el resto
--   con los (len(b)-1) bits altos, asi solo itera len(a)-len(b)+1 veces, DIV_STEPS bits del
--   cociente por ciclo. 128/64 bit (BN/1): ~33 ciclos; cocientes cortos: 3-6 ciclos.
-- clm = '1' (Zbc, solo modo RV128; f3 = 1 clmul, 2 clmulr, 3 clmulh): producto sin acarreo
-- 128 x 128 -> 256, 16 bits del multiplicador por ciclo (8 iteraciones).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv128_pkg.all;

entity rv128_muldiv is
  generic (
    FAST      : boolean  := true;
    DIV_STEPS : positive := 2            -- bits de cociente por ciclo con FAST (1..4)
  );
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    start  : in  std_logic;
    kill   : in  std_logic;
    ack    : in  std_logic;
    f3     : in  std_logic_vector(2 downto 0);
    wsel   : in  std_logic_vector(1 downto 0);
    a, b   : in  xword;
    busy   : out std_logic;
    done   : out std_logic;
    result : out xword;
    clm    : in  std_logic := '0'
  );
end entity;

architecture rtl of rv128_muldiv is
  type st_t is (IDLE, MUL, DIV, DPREP, CLMUL, FIN, HOLD);
  signal st      : st_t;
  signal cnt     : unsigned(7 downto 0);
  signal op_f3   : std_logic_vector(2 downto 0);
  signal op_w    : std_logic_vector(1 downto 0);
  signal neg_q   : std_logic;                     -- negar producto / cociente
  signal neg_r   : std_logic;                     -- negar resto
  signal ua      : unsigned(127 downto 0);        -- multiplicando / divisor
  signal ua3     : unsigned(129 downto 0);        -- 3*ua (radix-4)
  signal p       : unsigned(255 downto 0);        -- producto / {-, dividendo->cociente}
  signal rr      : unsigned(128 downto 0);        -- resto parcial
  signal dz      : std_logic;                     -- division por cero
  signal dz_val  : xword;
  signal res     : xword;
  -- FAST
  signal ub      : unsigned(127 downto 0);        -- multiplicador
  signal terms   : std_logic_vector(3 downto 0);  -- parciales pendientes: hh hl lh ll
  signal pp      : unsigned(127 downto 0);        -- parcial registrado (salida del DSP)
  signal pp_sh   : std_logic_vector(1 downto 0);  -- su peso: 0, 64 o 128 bits
  signal pp_v    : std_logic;
  signal op_clm  : std_logic;

  -- longitud en bits (0 para x = 0)
  function blen(x : unsigned(127 downto 0)) return natural is
  begin
    for i in 127 downto 0 loop
      if x(i) = '1' then return i + 1; end if;
    end loop;
    return 0;
  end function;
begin
  busy   <= '0' when st = IDLE else '1';
  done   <= '1' when st = HOLD else '0';
  result <= res;

  process (clk)
    variable sa, sb       : std_logic;
    variable av, bv       : xword;
    variable ma, mb       : unsigned(127 downto 0);
    variable add          : unsigned(129 downto 0);
    variable sum          : unsigned(129 downto 0);
    variable r2           : unsigned(128 downto 0);
    variable prod         : unsigned(255 downto 0);
    variable q, rem_v     : unsigned(127 downto 0);
    variable p128         : unsigned(127 downto 0);
    variable outv         : xword;
    variable t            : std_logic_vector(3 downto 0);
    variable x, y         : unsigned(63 downto 0);
    variable acc          : unsigned(255 downto 0);
    variable la, lb, n    : natural range 0 to 128;
    variable rv           : unsigned(128 downto 0);
    variable pv           : unsigned(127 downto 0);
    variable cx           : unsigned(143 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' or kill = '1' then
        st   <= IDLE;
        pp_v <= '0';
      else
        case st is
          when IDLE =>
            if start = '1' then
              op_f3 <= f3;
              op_w  <= wsel;
              op_clm <= clm;
              if clm = '1' then
                ua  <= unsigned(a);
                p   <= (255 downto 128 => '0') & unsigned(b);
                cnt <= to_unsigned(8, 8);
                st  <= CLMUL;
              elsif f3(2) = '0' then
                -- multiplicacion: signo segun la variante (solo 128 bit tiene MULH*)
                -- W_D (MULD y modo RV64): operandos de 64 bit extendidos segun el signo
                if wsel = W_D then
                  av := (127 downto 64 => '0') & a(63 downto 0);
                  bv := (127 downto 64 => '0') & b(63 downto 0);
                  sa := '0'; sb := '0';
                  if (f3 = "001" or f3 = "010") then sa := a(63); end if;
                  if f3 = "001" then sb := b(63); end if;
                  if sa = '1' then av := sext(a(63 downto 0), 64); end if;
                  if sb = '1' then bv := sext(b(63 downto 0), 64); end if;
                else
                  av := a; bv := b;
                  sa := '0'; sb := '0';
                  if (f3 = "001" or f3 = "010") then sa := a(127); end if;  -- MULH, MULHSU
                  if f3 = "001" then sb := b(127); end if;                    -- MULH
                end if;
                ma := unsigned(av); mb := unsigned(bv);
                if sa = '1' then ma := unsigned(-signed(av)); end if;
                if sb = '1' then mb := unsigned(-signed(bv)); end if;
                neg_q <= sa xor sb;
                ua    <= ma;
                if FAST then
                  -- parciales necesarios: ll siempre; lh/hl solo a 128 bit; hh solo en MULH*
                  t := "0001";
                  if wsel = W_Q then
                    t(1) := '1'; t(2) := '1';
                    if f3 /= "000" then t(3) := '1'; end if;
                  end if;
                  if ma(63 downto 0) = 0 then t(0) := '0'; t(1) := '0'; end if;
                  if ma(127 downto 64) = 0 then t(2) := '0'; t(3) := '0'; end if;
                  if mb(63 downto 0) = 0 then t(0) := '0'; t(2) := '0'; end if;
                  if mb(127 downto 64) = 0 then t(1) := '0'; t(3) := '0'; end if;
                  terms <= t;
                  ub    <= mb;
                  p     <= (others => '0');
                  pp_v  <= '0';
                else
                  ua3   <= ('0' & ma & '0') + ("00" & ma);
                  p     <= (255 downto 128 => '0') & mb;
                  if wsel = W_W then cnt <= to_unsigned(16, 8);
                  elsif wsel = W_D then cnt <= to_unsigned(32, 8);
                  else cnt <= to_unsigned(64, 8); end if;
                end if;
                st <= MUL;
              else
                -- division: extension segun anchura y signo
                if wsel = W_W then
                  if f3(0) = '0' then av := sext(a(31 downto 0), 32); bv := sext(b(31 downto 0), 32);
                  else av := (127 downto 32 => '0') & a(31 downto 0); bv := (127 downto 32 => '0') & b(31 downto 0); end if;
                elsif wsel = W_D then
                  if f3(0) = '0' then av := sext(a(63 downto 0), 64); bv := sext(b(63 downto 0), 64);
                  else av := (127 downto 64 => '0') & a(63 downto 0); bv := (127 downto 64 => '0') & b(63 downto 0); end if;
                else
                  av := a; bv := b;
                end if;
                sa := av(127) and not f3(0);
                sb := bv(127) and not f3(0);
                ma := unsigned(av); mb := unsigned(bv);
                if sa = '1' then ma := unsigned(-signed(av)); end if;
                if sb = '1' then mb := unsigned(-signed(bv)); end if;
                neg_q <= sa xor sb;
                neg_r <= sa;
                ua    <= mb;                         -- divisor
                rr    <= (others => '0');
                if bv = XZERO then dz <= '1'; else dz <= '0'; end if;
                if f3(1) = '0' then dz_val <= (others => '1'); else dz_val <= av; end if;
                if FAST then
                  p  <= (255 downto 128 => '0') & ma;   -- dividendo; DPREP normaliza
                  st <= DPREP;
                else
                  -- el dividendo se alinea arriba para salir por p(127)
                  if wsel = W_W then
                    p   <= (255 downto 128 => '0') & ma(31 downto 0) & (95 downto 0 => '0');
                    cnt <= to_unsigned(32, 8);
                  elsif wsel = W_D then
                    p   <= (255 downto 128 => '0') & ma(63 downto 0) & (63 downto 0 => '0');
                    cnt <= to_unsigned(64, 8);
                  else
                    p   <= (255 downto 128 => '0') & ma;
                    cnt <= to_unsigned(128, 8);
                  end if;
                  st <= DIV;
                end if;
              end if;
            end if;

          when MUL =>
            if FAST then
              -- acumula el parcial del ciclo anterior y lanza el siguiente
              acc := p;
              if pp_v = '1' then
                case pp_sh is
                  when "00"   => acc := acc + resize(pp, 256);
                  when "01"   => acc(255 downto 64) := acc(255 downto 64) + resize(pp, 192);
                  when others => acc(255 downto 128) := acc(255 downto 128) + pp;
                end case;
              end if;
              p <= acc;
              t := terms;
              if t(0) = '1' then
                x := ua(63 downto 0); y := ub(63 downto 0); pp_sh <= "00"; t(0) := '0';
              elsif t(1) = '1' then
                x := ua(63 downto 0); y := ub(127 downto 64); pp_sh <= "01"; t(1) := '0';
              elsif t(2) = '1' then
                x := ua(127 downto 64); y := ub(63 downto 0); pp_sh <= "01"; t(2) := '0';
              else
                x := ua(127 downto 64); y := ub(127 downto 64); pp_sh <= "10"; t(3) := '0';
              end if;
              pp    <= x * y;
              terms <= t;
              if terms = "0000" then
                pp_v <= '0';
                st   <= FIN;
              else
                pp_v <= '1';
              end if;
            else
              case p(1 downto 0) is
                when "00"   => add := (others => '0');
                when "01"   => add := "00" & ua;
                when "10"   => add := '0' & ua & '0';
                when others => add := ua3;
              end case;
              sum := ("00" & p(255 downto 128)) + add;
              p   <= sum & p(127 downto 2);
              cnt <= cnt - 1;
              if cnt = 1 then st <= FIN; end if;
            end if;

          when CLMUL =>
            -- {H, L} : H ^= a x L(15:0) (sin acarreo), luego {H, L} >>= 16
            cx := "0000000000000000" & p(255 downto 128);
            for j in 0 to 15 loop
              if p(j) = '1' then
                cx := cx xor shift_left(resize(ua, 144), j);
              end if;
            end loop;
            p   <= cx(143 downto 16) & cx(15 downto 0) & p(127 downto 16);
            cnt <= cnt - 1;
            if cnt = 1 then st <= FIN; end if;

          when DPREP =>
            -- solo FAST: n = len(a) - len(b) + 1 bits de cociente; el resto arranca con los
            -- len(b) - 1 bits altos del dividendo y p(127) con el siguiente bit
            la := blen(p(127 downto 0));
            lb := blen(ua);
            if dz = '1' or la < lb then
              rr  <= '0' & p(127 downto 0);         -- cociente 0, resto = dividendo
              p   <= (others => '0');
              st  <= FIN;
            else
              n   := la - lb + 1;
              rr  <= '0' & shift_right(p(127 downto 0), n);
              p   <= (255 downto 128 => '0') & shift_left(p(127 downto 0), 128 - n);
              cnt <= to_unsigned(n, 8);
              st  <= DIV;
            end if;

          when DIV =>
            rv := rr; pv := p(127 downto 0);
            for s in 1 to DIV_STEPS loop
              if s = 1 or cnt >= s then
                r2 := rv(127 downto 0) & pv(127);
                if r2 >= ('0' & ua) then
                  rv := r2 - ('0' & ua);
                  pv := pv(126 downto 0) & '1';
                else
                  rv := r2;
                  pv := pv(126 downto 0) & '0';
                end if;
              end if;
              if not FAST then exit; end if;
            end loop;
            rr <= rv;
            p(127 downto 0) <= pv;
            if FAST and cnt <= DIV_STEPS then
              st <= FIN;
            elsif cnt = 1 then
              st <= FIN;
            end if;
            if FAST and cnt > DIV_STEPS then
              cnt <= cnt - DIV_STEPS;
            else
              cnt <= cnt - 1;
            end if;

          when FIN =>
            if op_clm = '1' then
              if op_f3 = "001" then outv := std_logic_vector(p(127 downto 0));
              elsif op_f3 = "010" then outv := std_logic_vector(p(254 downto 127));
              else outv := std_logic_vector(p(255 downto 128)); end if;
            elsif op_f3(2) = '0' then
              prod := p;
              if neg_q = '1' then prod := unsigned(-signed(p)); end if;
              if FAST then
                -- p tiene el producto completo de las magnitudes
                if op_w = W_W then
                  outv := sext(std_logic_vector(prod(31 downto 0)), 32);
                elsif op_w = W_D and op_f3 = "000" then
                  outv := sext(std_logic_vector(prod(63 downto 0)), 64);
                elsif op_w = W_D then
                  outv := sext(std_logic_vector(prod(127 downto 64)), 64);
                elsif op_f3 = "000" then
                  outv := std_logic_vector(prod(127 downto 0));
                else
                  outv := std_logic_vector(prod(255 downto 128));
                end if;
              elsif op_w = W_W then
                outv := sext(std_logic_vector(p(127 downto 96)), 32);   -- MULW: 16 iteraciones
              elsif op_w = W_D and op_f3 = "000" then
                outv := sext(std_logic_vector(p(127 downto 64)), 64);   -- MULD / MUL RV64: 32 iteraciones
              elsif op_w = W_D then
                -- MULH* de 64 bit: tras 32 iteraciones el producto de 128 bit esta en p(191:64)
                p128 := p(191 downto 64);
                if neg_q = '1' then p128 := unsigned(-signed(p128)); end if;
                outv := sext(std_logic_vector(p128(127 downto 64)), 64);
              elsif op_f3 = "000" then
                outv := std_logic_vector(prod(127 downto 0));
              else
                outv := std_logic_vector(prod(255 downto 128));
              end if;
            else
              q := p(127 downto 0); rem_v := rr(127 downto 0);
              if neg_q = '1' then q := unsigned(-signed(q)); end if;
              if neg_r = '1' then rem_v := unsigned(-signed(rem_v)); end if;
              if dz = '1' then outv := dz_val;
              elsif op_f3(1) = '0' then outv := std_logic_vector(q);
              else outv := std_logic_vector(rem_v); end if;
              outv := wfix(outv, op_w);
            end if;
            res <= outv;
            st  <= HOLD;

          when HOLD =>
            if ack = '1' then st <= IDLE; end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
