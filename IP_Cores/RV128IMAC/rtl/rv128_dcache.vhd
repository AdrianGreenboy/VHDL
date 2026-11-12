-- rv128_dcache.vhd - D$ 16 KiB, 2 vias, linea 64 B, PIPT, write-back + write-allocate.
-- Igual que la D$ del RV64IMAC con la SRAM de datos a 128 bit (512 x 128 por via, 16
-- carriles), rafagas de 4 beats de 16 bytes y AMO de 32/64/128 bit (W/D/Q) por carriles.
--   * Hit de load: respuesta en el ciclo siguiente a la peticion; acepta otra
--     peticion en ese mismo ciclo (loads encadenados a 1/ciclo).
--   * Hit de store/SC: el dato va a un buffer de escritura de una entrada (pw) y se acepta
--     otra peticion en ese mismo ciclo. pw se escribe en la SRAM en el primer ciclo en que
--     el puerto de su via esta libre; un load que acierta en la misma via/palabra mezcla
--     pw en su respuesta. Stores consecutivos a la misma palabra se fusionan en pw. AMO y
--     CBO pasan por PW_WAIT (vaciado + relectura); fallos y fence.i vacian pw antes de
--     tocar la SRAM. req_ready no depende del contenido de la peticion (evita bucles
--     combinacionales con el PTW del core).
--   * Hit de AMO: lectura, operacion y escritura en el ciclo de lookup.
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
use work.rv128_pkg.all;
use work.rv128_axi_pkg.all;

entity rv128_dcache is
  generic (PREFETCH : boolean := false);                -- precarga de la linea siguiente
  port (
    clk, rst   : in  std_logic;
    -- core
    req_valid  : in  std_logic;
    req_ready  : out std_logic;
    req_addr   : in  xword;
    req_kind   : in  std_logic_vector(1 downto 0);      -- 00 load, 01 store, 10 amo, 11 cbo
    req_amo_op : in  std_logic_vector(4 downto 0);
    req_size   : in  std_logic_vector(2 downto 0);      -- log2(bytes), 0..4
    req_wdata  : in  xword;
    req_wstrb  : in  std_logic_vector(15 downto 0);
    req_ridx   : in  std_logic_vector(8 downto 0);      -- indice anticipado (puede no coincidir)
    req_rd     : in  std_logic;                         -- la peticion de este ciclo lee datos
    rsp_valid  : out std_logic;
    rsp_rdata  : out xword;
    rsp_err    : out std_logic;
    flush      : in  std_logic;                         -- fence.i
    flush_busy : out std_logic;
    -- maestro AXI (cliente 0)
    m_req   : out std_logic;
    m_kind  : out std_logic_vector(1 downto 0);
    m_addr  : out xword;
    m_size  : out std_logic_vector(2 downto 0);
    m_wline : out line_t;
    m_wdata : out xword;
    m_wstrb : out std_logic_vector(15 downto 0);
    m_cache : out std_logic;
    m_beat  : in  std_logic;
    m_done  : in  std_logic;
    m_idx   : in  std_logic_vector(1 downto 0);
    m_rdata : in  xword;
    m_err   : in  std_logic;
    m_acc   : in  std_logic := '0'                      -- el maestro acepta la peticion
  );
end entity;

architecture rtl of rv128_dcache is
  type st_t is (IDLE, LOOKUP, WB_RD, WB_REQ, RF_REQ, REPLAY, UNC, RESP,
                FL_TAG, FL_CHK, FL_NEXT, PW_WAIT, PF_FILL);
  signal st : st_t;

  type q128_t is array (0 to 1) of std_logic_vector(127 downto 0);
  type q18_t  is array (0 to 1) of std_logic_vector(17 downto 0);
  type bits_t is array (0 to 1) of std_logic_vector(127 downto 0);
  type a9_t   is array (0 to 1) of std_logic_vector(8 downto 0);
  signal d_en, d_we, t_en, t_we : std_logic_vector(1 downto 0);
  signal d_addr : a9_t;
  signal d_wd, d_wm : q128_t;
  signal d_q    : q128_t;
  signal t_addr : std_logic_vector(6 downto 0);
  signal t_wd   : std_logic_vector(17 downto 0);
  signal t_q    : q18_t;
  signal valid, dirty : bits_t;
  signal lru    : std_logic_vector(127 downto 0);       -- via usada mas recientemente

  -- peticion en curso
  signal r_addr  : xword;
  signal r_kind  : std_logic_vector(1 downto 0);
  signal r_amo   : std_logic_vector(4 downto 0);
  signal r_size  : std_logic_vector(2 downto 0);
  signal r_wdata : xword;
  signal r_wstrb : std_logic_vector(15 downto 0);
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
  -- buffer de escritura de stores con acierto
  signal pw_v    : std_logic;
  signal pw_way  : natural range 0 to 1;
  signal pw_addr : std_logic_vector(8 downto 0);        -- indice & palabra
  signal pw_wd   : xword;
  signal pw_wm   : std_logic_vector(15 downto 0);
  signal pw_drain: std_logic;
  signal pw_merge: std_logic;                           -- el store en lookup cae sobre pw
  signal st_hit  : std_logic;                           -- store con acierto en lookup
  signal nx_st   : st_t;                                -- destino de una peticion aceptada
  -- lectura anticipada: en los estados que aceptan, las SRAM se leen cada ciclo con
  -- req_ridx (no dependen de la aceptacion ni de la direccion completa); en lookup se
  -- comprueba que el indice leido es el de la peticion y, si no, se repite (REPLAY)
  signal acc     : std_logic;
  signal sp_rd   : std_logic;                           -- este ciclo se leen datos
  signal r_ridx  : std_logic_vector(8 downto 0);
  signal r_rd    : std_logic;
  signal ridx_ok : std_logic;
  -- precarga de la linea siguiente: tras rellenar la linea L (fallo o PF_FILL) se pide L+1
  -- al maestro en segundo plano, con la D$ sirviendo aciertos. Un fallo a esa linea la
  -- copia del buffer (PF_FILL, 4 ciclos) en lugar de ir a la DDR. El buffer se invalida si
  -- se escribe en memoria esa linea (writeback) y en fence.i.
  signal pf_arm, pf_own, pf_v : std_logic;
  signal pf_line : std_logic_vector(127 downto 6);
  signal pf_buf  : line_t;
  signal pf_hit  : std_logic;
  signal main_req, pf_req : std_logic;
  signal mb, md  : std_logic;                           -- beat / fin para la FSM principal
  signal hway    : natural range 0 to 1;
  signal accept  : std_logic;

  function idx_of(a : xword) return std_logic_vector is begin return a(12 downto 6); end function;
  function tag_of(a : xword) return std_logic_vector is begin return a(30 downto 13); end function;

  constant ZHI : std_logic_vector(127 downto 32) := (others => '0');

  -- AMO sobre el carril: W (32 bit), D (64 bit) o Q (128 bit). Los carriles fuera
  -- del operando los descarta la mascara de bytes (r_wstrb) al escribir.
  function amo_calc(op : std_logic_vector(4 downto 0); size : std_logic_vector(2 downto 0);
                    old, wd : xword; lane : natural) return xword is
    variable o, w, nw : unsigned(127 downto 0);
    variable so, sw   : signed(127 downto 0);
    variable r        : xword;
  begin
    o := shift_right(unsigned(old), 8 * lane);
    w := shift_right(unsigned(wd), 8 * lane);
    if size = "010" then
      so := resize(signed(o(31 downto 0)), 128); sw := resize(signed(w(31 downto 0)), 128);
      o  := resize(o(31 downto 0), 128);         w  := resize(w(31 downto 0), 128);
    elsif size = "011" then
      so := resize(signed(o(63 downto 0)), 128); sw := resize(signed(w(63 downto 0)), 128);
      o  := resize(o(63 downto 0), 128);         w  := resize(w(63 downto 0), 128);
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

  function bytemask(s : std_logic_vector(15 downto 0)) return xword is
    variable m : xword;
  begin
    for k in 0 to 15 loop m(8 * k + 7 downto 8 * k) := (others => s(k)); end loop;
    return m;
  end function;
begin
  g_way : for w in 0 to 1 generate
    data_u : entity work.sram_1rw generic map (ABITS => 9, WIDTH => 128)
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
      if valid(w)(i) = '1' and t_q(w) = tag_of(r_addr) and ridx_ok = '1' then
        hit <= '1'; hway <= w;
      end if;
    end loop;
  end process;
  ridx_ok <= '1' when r_ridx = idx_of(r_addr) & r_addr(5 downto 4) and
                      (r_rd = '1' or r_kind = "01" or r_kind = "11") else '0';
  acc <= '1' when flush_p = '0' and flush = '0' and
                  (st = IDLE or (st = LOOKUP and hit = '1' and (r_kind = "00" or r_kind = "01"))) else '0';

  st_hit   <= '1' when st = LOOKUP and hit = '1' and r_kind = "01" else '0';
  pw_merge <= '1' when pw_v = '1' and pw_way = hway and pw_addr = idx_of(r_addr) & r_addr(5 downto 4) else '0';
  -- aceptacion (independiente del contenido): IDLE; lookup de load con acierto
  -- (encadenado); lookup de store con acierto si pw queda libre o se fusiona (si no, pw se
  -- vacia en este ciclo y la siguiente peticion espera uno)
  process (all)
    variable ok : boolean;
  begin
    ok := false;
    if flush_p = '0' and flush = '0' then
      if st = IDLE then
        ok := true;
      elsif st = LOOKUP and hit = '1' and r_kind = "00" then
        ok := true;
      elsif st_hit = '1' then
        ok := pw_v = '0' or pw_merge = '1' or req_rd = '0';
      end if;
    end if;
    if ok then req_ready <= '1'; else req_ready <= '0'; end if;
    if ok and req_valid = '1' then accept <= '1'; else accept <= '0'; end if;
  end process;
  -- AMO/CBO leen y escriben la SRAM en lookup: con pw ocupado (o creandose) pasan antes
  -- por PW_WAIT
  nx_st <= UNC when not pma_dram(req_addr) else
           PW_WAIT when req_kind(1) = '1' and (pw_v = '1' or st_hit = '1') else
           LOOKUP;
  flush_busy <= flush_p or flush;

  -- respuesta
  process (all)
  begin
    rsp_valid <= '0'; rsp_err <= '0';
    if pw_merge = '1' then
      rsp_rdata <= (d_q(hway) and not bytemask(pw_wm)) or (pw_wd and bytemask(pw_wm));
    else
      rsp_rdata <= d_q(hway);
    end if;
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
    variable de, dw : std_logic_vector(1 downto 0);       -- d_en/d_we (variables: se releen)
  begin
    de := "00"; dw := "00"; t_en <= "00"; t_we <= "00";
    for w in 0 to 1 loop
      d_addr(w) <= idx_of(r_addr) & r_addr(5 downto 4);
      d_wd(w) <= r_wdata; d_wm(w) <= bytemask(r_wstrb);
    end loop;
    t_addr <= idx_of(r_addr); t_wd <= tag_of(r_addr);
    i := to_integer(unsigned(idx_of(r_addr)));
    -- lectura anticipada en los estados que aceptan. pw se escribe en vez de leer datos si
    -- la peticion no los necesita (req_rd = 0) o si un store en lookup lo tiene que dejar
    -- libre (entonces req_ready = 0 para peticiones que leen)
    sp_rd <= '0';
    if acc = '1' then
      t_en <= "11";
      t_addr <= req_ridx(8 downto 2);
      for w in 0 to 1 loop d_addr(w) <= req_ridx; end loop;
      if not (pw_v = '1' and not (st_hit = '1' and pw_merge = '1') and
              (req_rd = '0' or st_hit = '1')) then
        de := "11"; sp_rd <= '1';
      end if;
    end if;
    case st is
      when LOOKUP =>
        if hit = '1' and r_kind = "10" then
          de(hway) := '1'; dw(hway) := '1';
          d_wd(hway) <= amo_calc(r_amo, r_size, d_q(hway), r_wdata, to_integer(unsigned(r_addr(3 downto 0))));
        end if;
      when WB_RD =>
        if cnt < 4 then
          de(vic) := '1';
          d_addr(vic) <= wb_addr(12 downto 6) & std_logic_vector(cnt(1 downto 0));
        end if;
      when RF_REQ =>
        if mb = '1' then
          de(vic) := '1'; dw(vic) := '1';
          d_addr(vic) <= idx_of(r_addr) & m_idx;
          d_wd(vic) <= m_rdata; d_wm(vic) <= (others => '1');
        end if;
        if md = '1' and m_err = '0' then
          t_en(vic) <= '1'; t_we(vic) <= '1';
        end if;
      when PF_FILL =>
        de(vic) := '1'; dw(vic) := '1';
        d_addr(vic) <= idx_of(r_addr) & std_logic_vector(cnt(1 downto 0));
        d_wd(vic) <= pf_buf(128 * to_integer(cnt(1 downto 0)) + 127 downto 128 * to_integer(cnt(1 downto 0)));
        d_wm(vic) <= (others => '1');
        if cnt(1 downto 0) = "11" then
          t_en(vic) <= '1'; t_we(vic) <= '1';
        end if;
      when REPLAY =>
        de := "11"; t_en <= "11";
      when FL_TAG =>
        t_en <= "11"; t_addr <= std_logic_vector(fset);
      when others => null;
    end case;
    -- vaciado de pw cuando el puerto de su via esta libre (no si el store en lookup se
    -- fusiona con el: pw se actualiza en el flanco)
    pw_drain <= '0';
    if pw_v = '1' and de(pw_way) = '0' and not (st_hit = '1' and pw_merge = '1') then
      de(pw_way) := '1'; dw(pw_way) := '1';
      d_addr(pw_way) <= pw_addr; d_wd(pw_way) <= pw_wd; d_wm(pw_way) <= bytemask(pw_wm);
      pw_drain <= '1';
    end if;
    d_en <= de; d_we <= dw;
  end process;

  -- peticiones al maestro AXI
  pf_hit   <= '1' when pf_line = r_addr(127 downto 6) else '0';
  main_req <= '1' when pf_own = '0' and
                       (st = WB_REQ or st = UNC or
                        (st = RF_REQ and not (pf_hit = '1' and (pf_v = '1' or pf_arm = '1')))) else '0';
  pf_req   <= '1' when pf_arm = '1' and main_req = '0' and pf_own = '0' else '0';
  m_req   <= main_req or pf_req;
  m_kind  <= AX_RD_LINE when main_req = '0' else
             AX_WR_LINE when st = WB_REQ else AX_RD_LINE when st = RF_REQ
             else AX_WR_ONE when r_kind(0) = '1' else AX_RD_ONE;
  m_addr  <= pf_line & "000000" when main_req = '0' else
             wb_addr when st = WB_REQ else
             r_addr(127 downto 6) & "000000" when st = RF_REQ else r_addr;
  m_size  <= r_size;
  m_wline <= wline;
  m_wdata <= r_wdata;
  m_wstrb <= r_wstrb;
  m_cache <= '0' when main_req = '1' and st = UNC else '1';
  mb <= m_beat and not pf_own;
  md <= m_done and not pf_own;

  process (clk)
    variable i, fi : natural range 0 to 127;
    variable v     : natural range 0 to 1;
    variable pf_next : boolean;
    variable nl    : unsigned(121 downto 0);
  begin
    if rising_edge(clk) then
      pf_next := false;
      if rst = '1' then
        pf_arm <= '0'; pf_own <= '0'; pf_v <= '0'; pf_line <= (others => '1');
        st <= IDLE; flush_p <= '0'; fl_wb <= '0'; cmo_wb <= '0'; pw_v <= '0';
        valid <= (others => (others => '0')); dirty <= (others => (others => '0'));
        lru <= (others => '0');
      else
        if flush = '1' then flush_p <= '1'; pf_v <= '0'; pf_arm <= '0'; end if;
        -- transaccion de precarga en el maestro
        if pf_req = '1' and m_acc = '1' then
          pf_arm <= '0'; pf_own <= '1';
        end if;
        if pf_own = '1' and m_beat = '1' then
          pf_buf(128 * to_integer(unsigned(m_idx)) + 127 downto 128 * to_integer(unsigned(m_idx))) <= m_rdata;
        end if;
        if pf_own = '1' and m_done = '1' then
          pf_own <= '0'; pf_v <= not m_err;
        end if;
        -- buffer de escritura
        if pw_drain = '1' then pw_v <= '0'; end if;
        if st_hit = '1' then
          if pw_merge = '1' then
            pw_wd <= (pw_wd and not bytemask(r_wstrb)) or (r_wdata and bytemask(r_wstrb));
            pw_wm <= pw_wm or r_wstrb;
          else
            pw_way <= hway; pw_addr <= idx_of(r_addr) & r_addr(5 downto 4);
            pw_wd <= r_wdata; pw_wm <= r_wstrb;
          end if;
          pw_v <= '1';
        end if;
        i := to_integer(unsigned(idx_of(r_addr)));
        if accept = '1' then
          r_addr <= req_addr; r_kind <= req_kind; r_amo <= req_amo_op; r_size <= req_size;
          r_wdata <= req_wdata; r_wstrb <= req_wstrb;
          r_ridx <= req_ridx; r_rd <= sp_rd;
        end if;
        if st = REPLAY then                             -- la relectura usa el indice real
          r_ridx <= idx_of(r_addr) & r_addr(5 downto 4); r_rd <= '1';
        end if;
        case st is
          when IDLE =>
            if accept = '1' then
              st <= nx_st;
            elsif flush_p = '1' and pw_v = '0' then
              fset <= (others => '0'); fway <= 0; st <= FL_TAG;
            end if;

          when LOOKUP =>
            if ridx_ok = '0' then
              st <= REPLAY;                             -- indice anticipado erroneo
            elsif r_kind = "11" then
              -- Zicbom
              resp_e <= '0'; resp_d <= XZERO;
              if hit = '1' and dirty(hway)(i) = '1' then
                vic <= hway;
                wb_addr <= r_addr(127 downto 6) & "000000";
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
                st <= nx_st;
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
                wb_addr <= ZHI & '1' & t_q(v) & idx_of(r_addr) & "000000";
                cnt <= (others => '0');
                st <= WB_RD;
              else
                valid(v)(i) <= '0';
                st <= RF_REQ;
              end if;
            end if;

          when WB_RD =>                                 -- lee 4 palabras de la victima
            cnt <= cnt + 1;
            if cnt >= 1 then
              wline(128 * to_integer(cnt - 1) + 127 downto 128 * to_integer(cnt - 1)) <= d_q(vic);
            end if;
            if cnt = 4 then st <= WB_REQ; end if;

          when WB_REQ =>
            if md = '1' then
              fi := to_integer(unsigned(wb_addr(12 downto 6)));
              if wb_addr(127 downto 6) = pf_line then pf_v <= '0'; end if;   -- memoria cambia
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
            if pf_hit = '1' and pf_v = '1' then
              cnt <= (others => '0');
              st <= PF_FILL;                            -- la linea ya esta en el buffer
            elsif md = '1' then
              if m_err = '1' then
                resp_e <= '1'; resp_d <= XZERO; st <= RESP;
              else
                valid(vic)(i) <= '1'; dirty(vic)(i) <= '0';
                st <= REPLAY;
                pf_next := true;
              end if;
            end if;

          when PF_FILL =>
            cnt <= cnt + 1;
            if cnt(1 downto 0) = "11" then
              valid(vic)(i) <= '1'; dirty(vic)(i) <= '0';
              st <= REPLAY;
              pf_next := true;
            end if;

          when REPLAY =>
            st <= LOOKUP;

          when PW_WAIT =>                               -- el puerto esta libre: pw se vacia
            if pw_v = '0' then st <= REPLAY; end if;

          when UNC =>
            if mb = '1' then resp_d <= m_rdata; end if;
            if md = '1' then
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
              wb_addr <= ZHI & '1' & t_q(fway) & std_logic_vector(fset) & "000000";
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
        -- siguiente linea (dentro de la DRAM): se pide en cuanto el maestro quede libre
        if pf_next then
          nl := unsigned(r_addr(127 downto 6)) + 1;
          if PREFETCH and pma_dram(std_logic_vector(nl) & "000000") then
            pf_line <= std_logic_vector(nl); pf_v <= '0'; pf_arm <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
