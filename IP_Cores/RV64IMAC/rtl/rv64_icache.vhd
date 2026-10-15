-- rv64_icache.vhd - I$ 16 KiB, 2 vias, linea 64 B, PIPT, solo lectura.
--   * Hit: respuesta en el ciclo siguiente; acepta otra peticion en ese ciclo.
--   * Fallo: relleno por rafaga AXI y repeticion.
--   * No cacheable (boot ROM): lectura AXI de un beat de 4 bytes.
--   * inval (fence.i): invalida todas las lineas; si hay un relleno en curso,
--     al terminarlo. 'hold' (D$ limpiando por fence.i) impide aceptar peticiones,
--     para que ningun relleno lea memoria antes del writeback.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;
use work.rv64_axi_pkg.all;

entity rv64_icache is
  port (
    clk, rst  : in  std_logic;
    req_valid : in  std_logic;
    req_ready : out std_logic;
    req_addr  : in  xword;
    rsp_valid : out std_logic;
    rsp_data  : out std_logic_vector(31 downto 0);
    rsp_err   : out std_logic;
    inval     : in  std_logic;
    hold      : in  std_logic;
    -- maestro AXI (cliente 1)
    m_req   : out std_logic;
    m_kind  : out std_logic_vector(1 downto 0);
    m_addr  : out xword;
    m_size  : out std_logic_vector(1 downto 0);
    m_cache : out std_logic;
    m_beat  : in  std_logic;
    m_done  : in  std_logic;
    m_idx   : in  std_logic_vector(2 downto 0);
    m_rdata : in  xword;
    m_err   : in  std_logic
  );
end entity;

architecture rtl of rv64_icache is
  type st_t is (IDLE, LOOKUP, RF_REQ, REPLAY, UNC, RESP);
  signal st : st_t;
  type q64_t  is array (0 to 1) of std_logic_vector(63 downto 0);
  type q18_t  is array (0 to 1) of std_logic_vector(17 downto 0);
  type bits_t is array (0 to 1) of std_logic_vector(127 downto 0);
  type a10_t  is array (0 to 1) of std_logic_vector(9 downto 0);
  signal d_en, d_we, t_en, t_we : std_logic_vector(1 downto 0);
  signal d_addr : a10_t;
  signal d_q    : q64_t;
  signal t_addr : std_logic_vector(6 downto 0);
  signal t_q    : q18_t;
  signal valid  : bits_t;
  signal lru    : std_logic_vector(127 downto 0);
  signal r_addr : xword;
  signal vic    : natural range 0 to 1;
  signal resp_d : std_logic_vector(31 downto 0);
  signal resp_e : std_logic;
  signal inval_p: std_logic;
  signal hit    : std_logic;
  signal hway   : natural range 0 to 1;
  signal can    : std_logic;
  signal accept : std_logic;

  function idx_of(a : xword) return std_logic_vector is begin return a(12 downto 6); end function;
  function tag_of(a : xword) return std_logic_vector is begin return a(30 downto 13); end function;
begin
  g_way : for w in 0 to 1 generate
    data_u : entity work.sram_1rw generic map (ABITS => 10, WIDTH => 64)
      port map (clk, d_en(w), d_we(w), d_addr(w), m_rdata, (others => '1'), d_q(w));
    tag_u : entity work.sram_1rw generic map (ABITS => 7, WIDTH => 18)
      port map (clk, t_en(w), t_we(w), t_addr, tag_of(r_addr), (others => '1'), t_q(w));
  end generate;

  process (all)
    variable i : natural range 0 to 127;
  begin
    i := to_integer(unsigned(idx_of(r_addr)));
    hit <= '0'; hway <= 0;
    for w in 0 to 1 loop
      if valid(w)(i) = '1' and t_q(w) = tag_of(r_addr) then hit <= '1'; hway <= w; end if;
    end loop;
  end process;

  can <= '1' when hold = '0' and inval_p = '0' and (st = IDLE or (st = LOOKUP and hit = '1')) else '0';
  req_ready <= can;
  accept <= can and req_valid;

  process (all)
  begin
    rsp_valid <= '0'; rsp_err <= '0';
    if r_addr(2) = '1' then rsp_data <= d_q(hway)(63 downto 32); else rsp_data <= d_q(hway)(31 downto 0); end if;
    if st = LOOKUP and hit = '1' then
      rsp_valid <= '1';
    elsif st = RESP then
      rsp_valid <= '1'; rsp_data <= resp_d; rsp_err <= resp_e;
    end if;
  end process;

  process (all)
  begin
    d_en <= "00"; d_we <= "00"; t_en <= "00"; t_we <= "00";
    for w in 0 to 1 loop d_addr(w) <= idx_of(r_addr) & r_addr(5 downto 3); end loop;
    t_addr <= idx_of(r_addr);
    if accept = '1' and pma_dram(req_addr) then
      d_en <= "11"; t_en <= "11";
      for w in 0 to 1 loop d_addr(w) <= idx_of(req_addr) & req_addr(5 downto 3); end loop;
      t_addr <= idx_of(req_addr);
    end if;
    if st = RF_REQ then
      if m_beat = '1' then
        d_en(vic) <= '1'; d_we(vic) <= '1';
        d_addr(vic) <= idx_of(r_addr) & m_idx;
      end if;
      if m_done = '1' and m_err = '0' then
        t_en(vic) <= '1'; t_we(vic) <= '1';
      end if;
    elsif st = REPLAY then
      d_en <= "11"; t_en <= "11";
    end if;
  end process;

  m_req   <= '1' when st = RF_REQ or st = UNC else '0';
  m_kind  <= AX_RD_LINE when st = RF_REQ else AX_RD_ONE;
  m_addr  <= r_addr(63 downto 6) & "000000" when st = RF_REQ else r_addr(63 downto 2) & "00";
  m_size  <= "10";
  m_cache <= '1' when st = RF_REQ else '0';

  process (clk)
    variable i : natural range 0 to 127;
    variable v : natural range 0 to 1;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= IDLE; inval_p <= '0';
        valid <= (others => (others => '0')); lru <= (others => '0');
      else
        i := to_integer(unsigned(idx_of(r_addr)));
        if accept = '1' then r_addr <= req_addr; end if;
        case st is
          when IDLE =>
            if accept = '1' then
              if pma_dram(req_addr) then st <= LOOKUP; else st <= UNC; end if;
            end if;
          when LOOKUP =>
            if hit = '1' then
              if hway = 1 then lru(i) <= '1'; else lru(i) <= '0'; end if;
              if accept = '1' then
                if pma_dram(req_addr) then st <= LOOKUP; else st <= UNC; end if;
              else
                st <= IDLE;
              end if;
            else
              if valid(0)(i) = '0' then v := 0;
              elsif valid(1)(i) = '0' then v := 1;
              elsif lru(i) = '0' then v := 1;
              else v := 0; end if;
              vic <= v;
              valid(v)(i) <= '0';
              st <= RF_REQ;
            end if;
          when RF_REQ =>
            if m_done = '1' then
              if m_err = '1' then
                resp_e <= '1'; resp_d <= (others => '0'); st <= RESP;
              else
                valid(vic)(i) <= '1'; st <= REPLAY;
              end if;
            end if;
          when REPLAY =>
            st <= LOOKUP;
          when UNC =>
            if m_beat = '1' then
              if r_addr(2) = '1' then resp_d <= m_rdata(63 downto 32); else resp_d <= m_rdata(31 downto 0); end if;
            end if;
            if m_done = '1' then resp_e <= m_err; st <= RESP; end if;
          when RESP =>
            st <= IDLE;
        end case;
        -- invalidacion: inmediata salvo relleno en curso
        if inval = '1' or inval_p = '1' then
          if st = RF_REQ or st = REPLAY then
            inval_p <= '1';
          else
            valid <= (others => (others => '0'));
            inval_p <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
