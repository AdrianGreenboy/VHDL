-- rv64_dcache.vhd - D$ 16 KiB, 2 vias, linea 64 B, PIPT, write-back + write-allocate.
--   * Hit de load: respuesta en el ciclo siguiente a la peticion; acepta otra
--     peticion en ese mismo ciclo (loads encadenados a 1/ciclo).
--   * Hit de store/SC/AMO: escritura en la SRAM al final del ciclo de lookup
--     (AMO: lectura, operacion y escritura en ese ciclo); no acepta otra peticion
--     en ese ciclo.
--   * Fallo: writeback de la victima sucia (rafaga AXI) + relleno + repeticion.
--   * No cacheable (fuera de DRAM): transaccion AXI de un beat.
--   * fence.i: limpieza completa (writeback de todas las lineas sucias). Mientras,
--     flush_busy bloquea tambien los rellenos de la I$.
--   * Zicbom (req_kind 11, req_amo_op(1:0): 00 inval, 01 clean, 10 flush): clean escribe
--     la linea si esta sucia; flush e inval la escriben y la invalidan (inval se ejecuta
--     como flush, permitido por la spec y seguro para el DMA no coherente de Linux).
-- Etiqueta: PA[30:13] (solo la DRAM 0x8000_0000-0xFFFF_FFFF es cacheable).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;
use work.rv64_axi_pkg.all;

entity rv64_dcache is
  port (
    clk, rst   : in  std_logic;
    -- core
    req_valid  : in  std_logic;
    req_ready  : out std_logic;
    req_addr   : in  xword;
    req_kind   : in  std_logic_vector(1 downto 0);      -- 00 load, 01 store, 10 amo, 11 cbo
    req_amo_op : in  std_logic_vector(4 downto 0);
    req_size   : in  std_logic_vector(1 downto 0);
    req_wdata  : in  xword;
    req_wstrb  : in  std_logic_vector(7 downto 0);
    rsp_valid  : out std_logic;
    rsp_rdata  : out xword;
    rsp_err    : out std_logic;
    flush      : in  std_logic;                         -- fence.i
    flush_busy : out std_logic;
    -- maestro AXI (cliente 0)
    m_req   : out std_logic;
    m_kind  : out std_logic_vector(1 downto 0);
    m_addr  : out xword;
    m_size  : out std_logic_vector(1 downto 0);
    m_wline : out line_t;
    m_wdata : out xword;
    m_wstrb : out std_logic_vector(7 downto 0);
    m_cache : out std_logic;
    m_beat  : in  std_logic;
    m_done  : in  std_logic;
    m_idx   : in  std_logic_vector(2 downto 0);
    m_rdata : in  xword;
    m_err   : in  std_logic
  );
end entity;

architecture rtl of rv64_dcache is
  type st_t is (IDLE, LOOKUP, WB_RD, WB_REQ, RF_REQ, REPLAY, UNC, RESP,
                FL_TAG, FL_CHK, FL_NEXT);
  signal st : st_t;

  type q64_t  is array (0 to 1) of std_logic_vector(63 downto 0);
  type q18_t  is array (0 to 1) of std_logic_vector(17 downto 0);
  type bits_t is array (0 to 1) of std_logic_vector(127 downto 0);
  type a10_t  is array (0 to 1) of std_logic_vector(9 downto 0);
  signal d_en, d_we, t_en, t_we : std_logic_vector(1 downto 0);
  signal d_addr : a10_t;
  signal d_wd, d_wm : q64_t;
  signal d_q    : q64_t;
  signal t_addr : std_logic_vector(6 downto 0);
  signal t_wd   : std_logic_vector(17 downto 0);
  signal t_q    : q18_t;
  signal valid, dirty : bits_t;
  signal lru    : std_logic_vector(127 downto 0);       -- via usada mas recientemente

  -- peticion en curso
  signal r_addr  : xword;
  signal r_kind  : std_logic_vector(1 downto 0);
  signal r_amo   : std_logic_vector(4 downto 0);
  signal r_size  : std_logic_vector(1 downto 0);
  signal r_wdata : xword;
  signal r_wstrb : std_logic_vector(7 downto 0);
  signal vic     : natural range 0 to 1;
  signal cnt     : unsigned(3 downto 0);
  signal wline   : line_t;
  signal wb_addr : xword;
  signal resp_d  : xword;
  signal resp_e  : std_logic;
  signal flush_p : std_logic;
  signal fset    : unsigned(6 downto 0);
  signal fway    : natural range 0 to 1;
  signal fl_wb   : std_logic;                           -- writeback en curso por flush
  signal cmo_wb  : std_logic;                           -- writeback en curso por cbo.*

  signal hit     : std_logic;
  signal hway    : natural range 0 to 1;
  signal accept  : std_logic;

  function idx_of(a : xword) return std_logic_vector is begin return a(12 downto 6); end function;
  function tag_of(a : xword) return std_logic_vector is begin return a(30 downto 13); end function;

  function amo_calc(op : std_logic_vector(4 downto 0); size : std_logic_vector(1 downto 0);
                    old, wd : xword; lane : natural) return xword is
    variable o, w, nw : unsigned(63 downto 0);
    variable so, sw   : signed(63 downto 0);
    variable r        : xword;
  begin
    o := shift_right(unsigned(old), 8 * lane);
    w := shift_right(unsigned(wd), 8 * lane);
    if size = "10" then
      so := resize(signed(o(31 downto 0)), 64); sw := resize(signed(w(31 downto 0)), 64);
      o  := resize(o(31 downto 0), 64);         w  := resize(w(31 downto 0), 64);
    else
      so := signed(o); sw := signed(w);
    end if;
    case op is
      when "00000" => nw := o + w;
      when "00001" => nw := w;
      when "00100" => nw := o xor w;
      when "01000" => nw := o or w;
      when "01100" => nw := o and w;
      when "10000" => if so < sw then nw := unsigned(so); else nw := unsigned(sw); end if;
      when "10100" => if so > sw then nw := unsigned(so); else nw := unsigned(sw); end if;
      when "11000" => if o < w then nw := o; else nw := w; end if;
      when others  => if o > w then nw := o; else nw := w; end if;
    end case;
    r := std_logic_vector(shift_left(nw, 8 * lane));
    return r;
  end function;

  function bytemask(s : std_logic_vector(7 downto 0)) return xword is
    variable m : xword;
  begin
    for k in 0 to 7 loop m(8 * k + 7 downto 8 * k) := (others => s(k)); end loop;
    return m;
  end function;
begin
  g_way : for w in 0 to 1 generate
    data_u : entity work.sram_1rw generic map (ABITS => 10, WIDTH => 64)
      port map (clk, d_en(w), d_we(w), d_addr(w), d_wd(w), d_wm(w), d_q(w));
    tag_u : entity work.sram_1rw generic map (ABITS => 7, WIDTH => 18)
      port map (clk, t_en(w), t_we(w), t_addr, t_wd, (others => '1'), t_q(w));
  end generate;

  -- comparacion de etiquetas (salidas de SRAM del ciclo de lookup)
  process (all)
    variable i : natural range 0 to 127;
  begin
    i := to_integer(unsigned(idx_of(r_addr)));
    hit <= '0'; hway <= 0;
    for w in 0 to 1 loop
      if valid(w)(i) = '1' and t_q(w) = tag_of(r_addr) then
        hit <= '1'; hway <= w;
      end if;
    end loop;
  end process;

  -- aceptacion: libre, o lookup de load con acierto (encadenado)
  accept <= '1' when req_valid = '1' and flush_p = '0' and flush = '0' and
                     (st = IDLE or (st = LOOKUP and hit = '1' and r_kind = "00")) else '0';
  req_ready <= '1' when flush_p = '0' and flush = '0' and
                        (st = IDLE or (st = LOOKUP and hit = '1' and r_kind = "00")) else '0';
  flush_busy <= flush_p or flush;

  -- respuesta
  process (all)
  begin
    rsp_valid <= '0'; rsp_rdata <= d_q(hway); rsp_err <= '0';
    if st = LOOKUP and hit = '1' and r_kind /= "11" then
      rsp_valid <= '1';
    elsif st = RESP then
      rsp_valid <= '1'; rsp_rdata <= resp_d; rsp_err <= resp_e;
    end if;
  end process;

  -- control de SRAMs
  process (all)
    variable a : xword;
    variable i : natural range 0 to 127;
  begin
    d_en <= "00"; d_we <= "00"; t_en <= "00"; t_we <= "00";
    for w in 0 to 1 loop
      d_addr(w) <= idx_of(r_addr) & r_addr(5 downto 3);
      d_wd(w) <= r_wdata; d_wm(w) <= bytemask(r_wstrb);
    end loop;
    t_addr <= idx_of(r_addr); t_wd <= tag_of(r_addr);
    i := to_integer(unsigned(idx_of(r_addr)));
    if accept = '1' and pma_dram(req_addr) then
      d_en <= "11"; t_en <= "11";
      for w in 0 to 1 loop d_addr(w) <= idx_of(req_addr) & req_addr(5 downto 3); end loop;
      t_addr <= idx_of(req_addr);
    end if;
    case st is
      when LOOKUP =>
        if hit = '1' and (r_kind = "01" or r_kind = "10") then
          d_en(hway) <= '1'; d_we(hway) <= '1';
          if r_kind = "10" then
            d_wd(hway) <= amo_calc(r_amo, r_size, d_q(hway), r_wdata, to_integer(unsigned(r_addr(2 downto 0))));
          end if;
        end if;
      when WB_RD =>
        if cnt < 8 then
          d_en(vic) <= '1';
          d_addr(vic) <= wb_addr(12 downto 6) & std_logic_vector(cnt(2 downto 0));
        end if;
      when RF_REQ =>
        if m_beat = '1' then
          d_en(vic) <= '1'; d_we(vic) <= '1';
          d_addr(vic) <= idx_of(r_addr) & m_idx;
          d_wd(vic) <= m_rdata; d_wm(vic) <= (others => '1');
        end if;
        if m_done = '1' and m_err = '0' then
          t_en(vic) <= '1'; t_we(vic) <= '1';
        end if;
      when REPLAY =>
        d_en <= "11"; t_en <= "11";
      when FL_TAG =>
        t_en <= "11"; t_addr <= std_logic_vector(fset);
      when others => null;
    end case;
  end process;

  -- peticiones al maestro AXI
  m_req   <= '1' when st = WB_REQ or st = RF_REQ or st = UNC else '0';
  m_kind  <= AX_WR_LINE when st = WB_REQ else AX_RD_LINE when st = RF_REQ
             else AX_WR_ONE when r_kind(0) = '1' else AX_RD_ONE;
  m_addr  <= wb_addr when st = WB_REQ else
             r_addr(63 downto 6) & "000000" when st = RF_REQ else r_addr;
  m_size  <= r_size;
  m_wline <= wline;
  m_wdata <= r_wdata;
  m_wstrb <= r_wstrb;
  m_cache <= '0' when st = UNC else '1';

  process (clk)
    variable i, fi : natural range 0 to 127;
    variable v     : natural range 0 to 1;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= IDLE; flush_p <= '0'; fl_wb <= '0'; cmo_wb <= '0';
        valid <= (others => (others => '0')); dirty <= (others => (others => '0'));
        lru <= (others => '0');
      else
        if flush = '1' then flush_p <= '1'; end if;
        i := to_integer(unsigned(idx_of(r_addr)));
        if accept = '1' then
          r_addr <= req_addr; r_kind <= req_kind; r_amo <= req_amo_op; r_size <= req_size;
          r_wdata <= req_wdata; r_wstrb <= req_wstrb;
        end if;
        case st is
          when IDLE =>
            if accept = '1' then
              if pma_dram(req_addr) then st <= LOOKUP; else st <= UNC; end if;
            elsif flush_p = '1' then
              fset <= (others => '0'); fway <= 0; st <= FL_TAG;
            end if;

          when LOOKUP =>
            if r_kind = "11" then
              -- Zicbom
              resp_e <= '0'; resp_d <= XZERO;
              if hit = '1' and dirty(hway)(i) = '1' then
                vic <= hway;
                wb_addr <= r_addr(63 downto 6) & "000000";
                cnt <= (others => '0');
                cmo_wb <= '1';
                st <= WB_RD;
              else
                if hit = '1' and r_amo(1 downto 0) /= "01" then valid(hway)(i) <= '0'; end if;
                st <= RESP;
              end if;
            elsif hit = '1' then
              if hway = 1 then lru(i) <= '1'; else lru(i) <= '0'; end if;
              if r_kind /= "00" then dirty(hway)(i) <= '1'; end if;
              if accept = '1' then
                if pma_dram(req_addr) then st <= LOOKUP; else st <= UNC; end if;
              else
                st <= IDLE;
              end if;
            else
              -- fallo: victima = via invalida, si no la menos reciente
              if valid(0)(i) = '0' then v := 0;
              elsif valid(1)(i) = '0' then v := 1;
              elsif lru(i) = '0' then v := 1;
              else v := 0; end if;
              vic <= v;
              if valid(v)(i) = '1' and dirty(v)(i) = '1' then
                wb_addr <= x"00000000" & '1' & t_q(v) & idx_of(r_addr) & "000000";
                cnt <= (others => '0');
                st <= WB_RD;
              else
                valid(v)(i) <= '0';
                st <= RF_REQ;
              end if;
            end if;

          when WB_RD =>                                 -- lee 8 palabras de la victima
            cnt <= cnt + 1;
            if cnt >= 1 then
              wline(64 * to_integer(cnt - 1) + 63 downto 64 * to_integer(cnt - 1)) <= d_q(vic);
            end if;
            if cnt = 8 then st <= WB_REQ; end if;

          when WB_REQ =>
            if m_done = '1' then
              fi := to_integer(unsigned(wb_addr(12 downto 6)));
              dirty(vic)(fi) <= '0';
              if fl_wb = '1' then
                fl_wb <= '0'; st <= FL_NEXT;
              elsif cmo_wb = '1' then
                cmo_wb <= '0'; resp_e <= m_err;
                if r_amo(1 downto 0) /= "01" then valid(vic)(fi) <= '0'; end if;
                st <= RESP;
              else
                valid(vic)(i) <= '0';
                st <= RF_REQ;
              end if;
            end if;

          when RF_REQ =>
            if m_done = '1' then
              if m_err = '1' then
                resp_e <= '1'; resp_d <= XZERO; st <= RESP;
              else
                valid(vic)(i) <= '1'; dirty(vic)(i) <= '0';
                st <= REPLAY;
              end if;
            end if;

          when REPLAY =>
            st <= LOOKUP;

          when UNC =>
            if m_beat = '1' then resp_d <= m_rdata; end if;
            if m_done = '1' then
              resp_e <= m_err;
              if r_kind(0) = '1' then resp_d <= XZERO; end if;
              st <= RESP;
            end if;

          when RESP =>
            st <= IDLE;

          when FL_TAG =>
            st <= FL_CHK;

          when FL_CHK =>
            fi := to_integer(fset);
            if valid(fway)(fi) = '1' and dirty(fway)(fi) = '1' then
              vic <= fway;
              wb_addr <= x"00000000" & '1' & t_q(fway) & std_logic_vector(fset) & "000000";
              cnt <= (others => '0');
              fl_wb <= '1';
              st <= WB_RD;
            else
              st <= FL_NEXT;
            end if;

          when FL_NEXT =>
            if fway = 0 then
              fway <= 1; st <= FL_TAG;
            else
              fway <= 0;
              if fset = 127 then
                flush_p <= '0'; st <= IDLE;
              else
                fset <= fset + 1; st <= FL_TAG;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
