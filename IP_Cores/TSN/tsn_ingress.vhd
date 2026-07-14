-- tsn_ingress.vhd - Wrapper de ingreso por puerto del switch TSN 4x4
-- Consume el volcado validado del eth_rx_mii (1 byte/clk, sin FCS: el RX ya
-- descarto FCS malo/runt/filtradas), escribe la tsn_fifo especulativamente y:
--   * si toda la trama cupo => commit + descriptor (mac destino, len, tagged)
--   * si la FIFO se lleno a mitad de volcado (doomed) => rewind + pulso drop_ovf
-- La unica causa de rewind es overflow: la validez FCS es responsabilidad del RX.
-- Pulsos de contadores: cnt_rx, cnt_drop_ovf, cnt_drop_fcs (=ev_crc|ev_runt),
-- cnt_tagged. El clasificador consume descriptores (FWFT) y drena la FIFO.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tsn_ingress is
  generic (
    LOG2_DEPTH : natural := 11
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    -- del eth_rx_mii (volcado validado)
    rx_data      : in  std_logic_vector(7 downto 0);
    rx_valid     : in  std_logic;
    rx_last      : in  std_logic;
    ev_crc       : in  std_logic;
    ev_runt      : in  std_logic;
    -- lectura de la trama en cabeza (FWFT, solo consolidado)
    rd_en        : in  std_logic;
    rd_data      : out std_logic_vector(7 downto 0);
    rd_valid     : out std_logic;
    rd_commit    : in  std_logic;  -- libera la trama (todas las entregas hechas)
    rd_rewind    : in  std_logic;  -- re-lee la trama en cabeza (multicast)
    -- descriptor de la trama en cabeza (FWFT)
    desc_valid   : out std_logic;
    desc_mac     : out std_logic_vector(47 downto 0); -- byte0 de cable en [47:40]
    desc_len     : out unsigned(10 downto 0);         -- bytes de datos (sin FCS)
    desc_tagged  : out std_logic;
    desc_pop     : in  std_logic;                     -- consumir descriptor
    -- pulsos para contadores
    cnt_rx       : out std_logic;
    cnt_drop_ovf : out std_logic;
    cnt_drop_fcs : out std_logic;
    cnt_tagged   : out std_logic
  );
end entity;

architecture rtl of tsn_ingress is
  constant DESC_DEPTH : natural := 64;  -- > 2048/60 = 34 tramas max posibles

  signal wr_en, commit, rewind, full : std_logic := '0';

  signal bytecnt : unsigned(10 downto 0) := (others => '0');
  signal mac_sh  : std_logic_vector(47 downto 0) := (others => '0');
  signal tagged  : std_logic := '0';
  signal doomed  : std_logic := '0';
  signal fin_len : unsigned(10 downto 0) := (others => '0');
  signal do_commit, do_rewind : std_logic := '0';

  -- cola de descriptores: mac(48) & len(11) & tagged(1) = 60 bits
  type dq_t is array (0 to DESC_DEPTH-1) of std_logic_vector(59 downto 0);
  signal dq : dq_t;
  signal dq_wr, dq_rd : unsigned(6 downto 0) := (others => '0');
  signal dq_cnt : unsigned(6 downto 0);
begin
  fifo_i : entity work.tsn_fifo
    generic map (LOG2_DEPTH => LOG2_DEPTH)
    port map (
      clk => clk, rst => rst,
      wr_en => wr_en, wr_data => rx_data,
      commit => commit, rewind => rewind, full => full,
      rd_en => rd_en, rd_data => rd_data, rd_valid => rd_valid,
      rd_commit => rd_commit, rd_rewind => rd_rewind,
      spec_count => open, comm_count => open);

  -- escritura especulativa: solo bytes que caben y de tramas no condenadas
  wr_en  <= rx_valid and not full and not doomed;
  commit <= do_commit;
  rewind <= do_rewind;

  p_ing : process(clk)
  begin
    if rising_edge(clk) then
      do_commit <= '0';
      do_rewind <= '0';
      cnt_rx       <= '0';
      cnt_drop_ovf <= '0';
      cnt_tagged   <= '0';
      if rst = '1' then
        bytecnt <= (others => '0');
        doomed  <= '0';
        tagged  <= '0';
        dq_wr   <= (others => '0');
      else
        assert not (rx_valid = '1' and (do_commit = '1' or do_rewind = '1'))
          report "tsn_ingress: rx_valid durante commit/rewind (hueco RX violado)"
          severity failure;
        if rx_valid = '1' then
          if full = '1' then
            doomed <= '1';               -- byte perdido: trama condenada
          end if;
          if bytecnt < 6 then
            mac_sh <= mac_sh(39 downto 0) & rx_data;
          end if;
          if bytecnt = 12 and rx_data = x"81" then
            tagged <= '1';               -- provisional: confirmar byte 13
          elsif bytecnt = 13 then
            if not (tagged = '1' and rx_data = x"00") then
              tagged <= '0';
            end if;
          end if;
          bytecnt <= bytecnt + 1;
          if rx_last = '1' then
            fin_len   <= bytecnt + 1;
            do_commit <= not (doomed or full);   -- el ultimo byte tambien cuenta
            do_rewind <= doomed or full;
          end if;
        end if;
        if do_commit = '1' then
          assert dq_cnt /= to_unsigned(DESC_DEPTH, 7)
            report "tsn_ingress: cola de descriptores llena (imposible por diseno)"
            severity failure;
          dq(to_integer(dq_wr(5 downto 0))) <= mac_sh &
            std_logic_vector(fin_len) & tagged;
          dq_wr      <= dq_wr + 1;
          cnt_rx     <= '1';
          cnt_tagged <= tagged;
          bytecnt <= (others => '0'); doomed <= '0'; tagged <= '0';
        elsif do_rewind = '1' then
          cnt_drop_ovf <= '1';
          bytecnt <= (others => '0'); doomed <= '0'; tagged <= '0';
        end if;
      end if;
    end if;
  end process;

  -- descriptor FWFT (LUTRAM, lectura asincrona) y contador FCS
  dq_cnt      <= dq_wr - dq_rd;
  desc_valid  <= '1' when dq_cnt /= 0 else '0';
  desc_mac    <= dq(to_integer(dq_rd(5 downto 0)))(59 downto 12);
  desc_len    <= unsigned(dq(to_integer(dq_rd(5 downto 0)))(11 downto 1));
  desc_tagged <= dq(to_integer(dq_rd(5 downto 0)))(0);
  cnt_drop_fcs <= ev_crc or ev_runt;

  p_dq_rd : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        dq_rd <= (others => '0');
      elsif desc_pop = '1' and dq_cnt /= 0 then
        dq_rd <= dq_rd + 1;
      end if;
    end if;
  end process;
end architecture;
