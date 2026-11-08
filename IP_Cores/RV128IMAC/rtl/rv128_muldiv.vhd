-- rv128_muldiv.vhd - unidad M iterativa del RV128IMAC, portable a ASIC (sin DSP).
-- Derivada de rv64_muldiv.vhd, misma arquitectura y protocolo.
--   Multiplicacion radix-4: 64 iteraciones (128 bit), 32 (MULD), 16 (MULW).
--   Division con restauracion radix-2: 128 iteraciones, 64 (variantes D), 32 (W).
-- Protocolo: 'start' con la unidad libre captura operandos; 'done' se mantiene
-- con 'result' estable hasta 'ack'. 'kill' aborta en cualquier momento.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv128_pkg.all;

entity rv128_muldiv is
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
    result : out xword
  );
end entity;

architecture rtl of rv128_muldiv is
  type st_t is (IDLE, MUL, DIV, FIN, HOLD);
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
    variable outv         : xword;
  begin
    if rising_edge(clk) then
      if rst = '1' or kill = '1' then
        st <= IDLE;
      else
        case st is
          when IDLE =>
            if start = '1' then
              op_f3 <= f3;
              op_w  <= wsel;
              if f3(2) = '0' then
                -- multiplicacion: signo segun la variante (solo 128 bit tiene MULH*)
                sa := '0'; sb := '0';
                if (f3 = "001" or f3 = "010") then sa := a(127); end if;  -- MULH, MULHSU
                if f3 = "001" then sb := b(127); end if;                    -- MULH
                ma := unsigned(a); mb := unsigned(b);
                if sa = '1' then ma := unsigned(-signed(a)); end if;
                if sb = '1' then mb := unsigned(-signed(b)); end if;
                neg_q <= sa xor sb;
                ua    <= ma;
                ua3   <= ('0' & ma & '0') + ("00" & ma);
                p     <= (255 downto 128 => '0') & mb;
                if wsel = W_W then cnt <= to_unsigned(16, 8);
                elsif wsel = W_D then cnt <= to_unsigned(32, 8);
                else cnt <= to_unsigned(64, 8); end if;
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

          when MUL =>
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

          when DIV =>
            r2 := rr(127 downto 0) & p(127);
            if r2 >= ('0' & ua) then
              rr <= r2 - ('0' & ua);
              p(127 downto 0) <= p(126 downto 0) & '1';
            else
              rr <= r2;
              p(127 downto 0) <= p(126 downto 0) & '0';
            end if;
            cnt <= cnt - 1;
            if cnt = 1 then st <= FIN; end if;

          when FIN =>
            if op_f3(2) = '0' then
              prod := p;
              if neg_q = '1' then prod := unsigned(-signed(p)); end if;
              if op_w = W_W then
                outv := sext(std_logic_vector(p(127 downto 96)), 32);   -- MULW: 16 iteraciones
              elsif op_w = W_D then
                outv := sext(std_logic_vector(p(127 downto 64)), 64);   -- MULD: 32 iteraciones
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
