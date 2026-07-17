-- =============================================================
-- tb_amo_unit.vhd - Capa 1: rv32_amo_unit vs modelo independiente
-- BFM de memoria de 64 palabras con wait states pseudoaleatorios
-- (LCG semilla fija) + oraculo con memoria espejo y reserva
-- propia. Tras cada operacion se compara el resultado y las 64
-- palabras completas. Fase dirigida con bordes signed/unsigned
-- + fase aleatoria de 1500 operaciones. Determinista.
-- Criterio de paso: linea unica
--   FIN SIMULACION AMO: PASS @ <tiempo>
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_amo_unit is
end entity;

architecture sim of tb_amo_unit is

  signal clk  : std_logic := '0';
  signal rstn : std_logic := '0';

  signal start, res_clear   : std_logic := '0';
  signal funct5             : std_logic_vector(4 downto 0) := (others => '0');
  signal addr, src          : std_logic_vector(31 downto 0) := (others => '0');
  signal busy, done         : std_logic;
  signal result             : std_logic_vector(31 downto 0);
  signal m_req, m_we        : std_logic;
  signal m_addr, m_wdata    : std_logic_vector(31 downto 0);
  signal m_rdata            : std_logic_vector(31 downto 0);
  signal m_ready            : std_logic;

  type t_mem is array (0 to 63) of std_logic_vector(31 downto 0);

  function f_mem_init return t_mem is
    variable m : t_mem;
  begin
    for i in 0 to 63 loop
      m(i) := std_logic_vector(to_unsigned(i, 8) &
                               to_unsigned((i * 37) mod 256, 8) &
                               to_unsigned((i * 91) mod 256, 8) &
                               to_unsigned((i * 13) mod 256, 8));
    end loop;
    return m;
  end function;

  signal bfm_mem : t_mem := f_mem_init;

begin

  dut : entity work.rv32_amo_unit
    port map (
      clk => clk, rstn => rstn,
      start => start, funct5 => funct5, addr => addr, src => src,
      res_clear => res_clear, busy => busy, done => done,
      result => result,
      m_req => m_req, m_we => m_we, m_addr => m_addr,
      m_wdata => m_wdata, m_rdata => m_rdata, m_ready => m_ready
    );

  clk <= not clk after 5 ns;

  -- -------- BFM de memoria con wait states deterministas --------
  bfm : process
    variable lcg : unsigned(31 downto 0) := to_unsigned(19931207, 32);
    variable w   : integer;
    variable idx : integer;
  begin
    m_ready <= '0';
    m_rdata <= (others => '0');
    loop
      wait until rising_edge(clk);
      if m_req = '1' and rstn = '1' then
        lcg := resize(lcg * 1664525 + 1013904223, 32);
        w := to_integer(lcg(1 downto 0));  -- 0..3 esperas
        for k in 1 to w loop
          wait until rising_edge(clk);
        end loop;
        idx := to_integer(unsigned(m_addr(7 downto 2)));
        if m_we = '1' then
          bfm_mem(idx) <= m_wdata;
        else
          m_rdata <= bfm_mem(idx);
        end if;
        m_ready <= '1';
        wait until rising_edge(clk);
        m_ready <= '0';
        m_rdata <= (others => '0');
      end if;
    end loop;
  end process;

  -- ------------------- estimulo + oraculo -------------------
  stim : process
    variable o_mem   : t_mem := f_mem_init;
    variable o_valid : std_logic := '0';
    variable o_raddr : unsigned(31 downto 0) := (others => '0');
    variable lcg     : unsigned(31 downto 0) := to_unsigned(20260717, 32);
    variable nops    : integer := 0;

    impure function rnd return unsigned is
    begin
      lcg := resize(lcg * 1664525 + 1013904223, 32);
      return lcg;
    end function;

    -- modelo: aplica una operacion y regresa el resultado esperado
    procedure m_op(f5 : in std_logic_vector(4 downto 0);
                   a, s : in unsigned(31 downto 0);
                   exp  : out unsigned(31 downto 0)) is
      variable idx  : integer;
      variable oldv : unsigned(31 downto 0);
      variable newv : unsigned(31 downto 0);
    begin
      idx := to_integer(a(7 downto 2));
      oldv := unsigned(o_mem(idx));
      case f5 is
        when "00010" =>  -- lr.w
          exp := oldv;
          o_valid := '1'; o_raddr := a;
        when "00011" =>  -- sc.w
          if (o_valid = '1') and (o_raddr = a) then
            o_mem(idx) := std_logic_vector(s);
            exp := x"00000000";
          else
            exp := x"00000001";
          end if;
          o_valid := '0';
        when others =>   -- AMOs
          exp := oldv;
          case f5 is
            when "00001" => newv := s;
            when "00000" => newv := oldv + s;
            when "00100" => newv := oldv xor s;
            when "01100" => newv := oldv and s;
            when "01000" => newv := oldv or s;
            when "10000" =>
              if signed(std_logic_vector(oldv)) < signed(std_logic_vector(s))
                then newv := oldv; else newv := s; end if;
            when "10100" =>
              if signed(std_logic_vector(oldv)) > signed(std_logic_vector(s))
                then newv := oldv; else newv := s; end if;
            when "11000" =>
              if oldv < s then newv := oldv; else newv := s; end if;
            when others =>
              if oldv > s then newv := oldv; else newv := s; end if;
          end case;
          o_mem(idx) := std_logic_vector(newv);
          o_valid := '0';  -- invalidacion conservadora
      end case;
    end procedure;

    -- ejecuta contra el DUT, espera done y compara todo
    procedure do_op(f5 : in std_logic_vector(4 downto 0);
                    a, s : in unsigned(31 downto 0)) is
      variable exp : unsigned(31 downto 0);
      variable tout : integer := 0;
    begin
      funct5 <= f5;
      addr <= std_logic_vector(a);
      src  <= std_logic_vector(s);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      loop
        wait until rising_edge(clk);
        wait for 1 ns;
        exit when done = '1';
        tout := tout + 1;
        assert tout < 100
          report "TIMEOUT esperando done (f5=" & to_hstring(f5) & ")"
          severity failure;
      end loop;
      m_op(f5, a, s, exp);
      assert unsigned(result) = exp
        report "RESULT discrepa f5=" & to_hstring(f5) &
               " dut=" & to_hstring(result) &
               " modelo=" & to_hstring(std_logic_vector(exp))
        severity failure;
      for i in 0 to 63 loop
        assert bfm_mem(i) = o_mem(i)
          report "MEMORIA discrepa en palabra " & integer'image(i) &
                 " dut=" & to_hstring(bfm_mem(i)) &
                 " modelo=" & to_hstring(o_mem(i))
          severity failure;
      end loop;
      nops := nops + 1;
    end procedure;

    procedure do_clear is
    begin
      res_clear <= '1';
      wait until rising_edge(clk);
      res_clear <= '0';
      o_valid := '0';
      wait for 1 ns;
    end procedure;

    type t_f5s is array (0 to 10) of std_logic_vector(4 downto 0);
    constant F5S : t_f5s := ("00010", "00011", "00001", "00000", "00100",
                             "01100", "01000", "10000", "10100", "11000",
                             "11100");
    variable r, ra, rs : unsigned(31 downto 0);
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rstn <= '1';
    wait for 1 ns;

    -- ================= FASE DIRIGIDA =================
    -- cada AMO con valores simples
    do_op("00001", x"00000010", x"AAAA5555"); -- swap
    do_op("00000", x"00000010", x"00000003"); -- add
    do_op("00100", x"00000010", x"0F0F0F0F"); -- xor
    do_op("01100", x"00000010", x"FF00FF00"); -- and
    do_op("01000", x"00000010", x"000000FF"); -- or

    -- bordes signed/unsigned: 0x80000000 vs 0x7FFFFFFF
    do_op("00001", x"00000020", x"80000000"); -- mem = INT_MIN
    do_op("10000", x"00000020", x"7FFFFFFF"); -- amomin: queda INT_MIN
    do_op("00001", x"00000024", x"80000000");
    do_op("10100", x"00000024", x"7FFFFFFF"); -- amomax: queda INT_MAX
    do_op("00001", x"00000028", x"80000000");
    do_op("11000", x"00000028", x"7FFFFFFF"); -- aminu: queda 7FFFFFFF
    do_op("00001", x"0000002C", x"80000000");
    do_op("11100", x"0000002C", x"7FFFFFFF"); -- amaxu: queda 80000000
    -- bordes con negativos pequenos
    do_op("00001", x"00000030", x"FFFFFFFF"); -- -1
    do_op("10000", x"00000030", x"00000001"); -- min(-1,1) = -1
    do_op("00001", x"00000034", x"FFFFFFFF");
    do_op("11000", x"00000034", x"00000001"); -- minu(FFFF..,1) = 1

    -- lr/sc: exito
    do_op("00010", x"00000040", x"00000000"); -- lr
    do_op("00011", x"00000040", x"12345678"); -- sc -> 0, escribe
    -- sc sin lr previa: falla
    do_op("00011", x"00000040", x"DEAD0000"); -- sc -> 1, no escribe
    -- sc a direccion distinta de la reservada: falla
    do_op("00010", x"00000044", x"00000000");
    do_op("00011", x"00000048", x"DEAD0001"); -- sc -> 1
    -- lr + AMO intermedio invalida la reserva (detecta MUT5)
    do_op("00010", x"0000004C", x"00000000");
    do_op("00000", x"00000050", x"00000001"); -- amoadd rompe reserva
    do_op("00011", x"0000004C", x"DEAD0002"); -- sc -> 1
    -- lr + res_clear (store normal / trap) invalida (y detecta MUT2)
    do_op("00010", x"00000054", x"00000000");
    do_clear;
    do_op("00011", x"00000054", x"DEAD0003"); -- sc -> 1
    -- sc consume la reserva aunque falle: segunda sc tambien falla
    do_op("00011", x"00000054", x"DEAD0004"); -- sc -> 1

    -- ================= FASE ALEATORIA =================
    for i in 0 to 1499 loop
      r := rnd;
      if to_integer(r(4 downto 0)) = 0 then
        do_clear;
      else
        ra := rnd;
        ra := x"000000" & "00" & ra(7 downto 2);  -- 64 palabras alineadas
        ra := shift_left(ra, 2);
        rs := rnd;
        do_op(F5S(to_integer(r(31 downto 28)) mod 11), ra, rs);
      end if;
    end loop;

    report "OPS ATOMICAS TOTALES: " & integer'image(nops) severity note;
    report "FIN SIMULACION AMO: PASS @ " & time'image(now) severity note;
    finish;
  end process;

end architecture;
