-- rf_datapath.vhd - Datapath RF completo con generador de tono NCO-driven.
-- Reune la cadena validada en capa 4 (interpolador CIC -> loopmix -> decimador
-- CIC -> FIR RX -> AGC -> RX FIFO) pero la fuente de banda base ya no es el DC
-- cableado: es un SEGUNDO NCO (tono) cuya salida I=cos/Q=sin, de amplitud del
-- LUT (29491), se programa por MMIO via tone_ftw_i. Con tone_ftw_i=0 el tono
-- degenera en banda base DC constante (amplitud 29491), usado para el bring-up.
-- El NCO RX comparte ftw_i (0x0293A800). Coeficientes del FIR RX cargables por
-- MMIO. Expone la RX FIFO (frente/level/empty/pop) para el segundo maestro AXI.
-- Reset asincrono activo bajo. VHDL-2008.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_datapath is
  port (
    clk_i     : in  std_logic;
    aresetn_i : in  std_logic;
    -- control (del banco rf_regs)
    rx_en_i    : in  std_logic;
    ftw_i      : in  std_logic_vector(31 downto 0);   -- NCO RX
    tone_ftw_i : in  std_logic_vector(31 downto 0);   -- NCO tono (banda base)
    coef_we_i   : in  std_logic;
    coef_addr_i : in  std_logic_vector(3 downto 0);
    coef_data_i : in  std_logic_vector(15 downto 0);
    rssi_o     : out std_logic_vector(15 downto 0);
    -- RX FIFO (lado de lectura: MMIO y segundo maestro)
    rxf_rd_en_i    : in  std_logic;
    rxf_rd_data_o  : out std_logic_vector(31 downto 0);
    rxf_empty_o    : out std_logic;
    rxf_full_o     : out std_logic;
    rxf_level_o    : out std_logic_vector(9 downto 0)
  );
end entity rf_datapath;

architecture rtl of rf_datapath is
  constant SEL : std_logic_vector(2 downto 0) := "001";  -- R=8

  -- generador de tono (2do NCO)
  signal tone_en : std_logic;
  signal tone_s, tone_c : std_logic_vector(15 downto 0);
  signal tone_v : std_logic;
  signal gap_r : unsigned(3 downto 0) := (others=>'0');
  signal bb_v : std_logic := '0';
  signal bb_i, bb_q : std_logic_vector(15 downto 0) := (others=>'0');

  -- NCO RX
  signal nco_en, nco_v : std_logic;
  signal nco_s, nco_c : std_logic_vector(15 downto 0);

  -- cadena
  signal itp_i, itp_q : std_logic_vector(15 downto 0);
  signal itp_v : std_logic;
  signal itpd_i, itpd_q : std_logic_vector(15 downto 0) := (others=>'0');
  signal itpd_v : std_logic := '0';
  signal rf_i, rf_q, lm_i, lm_q : std_logic_vector(15 downto 0);
  signal lm_v : std_logic;
  signal dec_i, dec_q : std_logic_vector(15 downto 0);
  signal dec_v : std_logic;
  signal rxfir_i, rxfir_q : std_logic_vector(15 downto 0);
  signal rxfir_v : std_logic;
  signal agc_i, agc_q : std_logic_vector(15 downto 0);
  signal agc_v : std_logic;

  signal rxf_wr_en : std_logic;
  signal rxf_wr_data : std_logic_vector(31 downto 0);
  signal rxf_level_u : unsigned(9 downto 0);
begin

  -----------------------------------------------------------------------------
  -- Generador de tono: el 2do NCO produce la banda base I/Q. Se emite una
  -- muestra cada R=8 ciclos (misma cadencia que el estimulo de capa 4) cuando
  -- rx_en. I = cos(fase_tono), Q = sin(fase_tono). tone_ftw_i=0 -> I=29491, Q=0.
  -----------------------------------------------------------------------------
  tone_en <= rx_en_i;

  u_tone : entity work.rf_nco
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, en_i=>tone_en, ftw_i=>tone_ftw_i,
              sin_o=>tone_s, cos_o=>tone_c, valid_o=>tone_v);

  proc_stim : process (clk_i, aresetn_i)
  begin
    if aresetn_i = '0' then
      bb_v <= '0'; bb_i <= (others=>'0'); bb_q <= (others=>'0'); gap_r <= (others=>'0');
    elsif rising_edge(clk_i) then
      bb_v <= '0';
      -- emitir banda base solo cuando el NCO tono ya produce muestras validas
      -- (tone_v='1'). Asi se evita capturar el cos/sin de arranque (aun en 0).
      if rx_en_i = '1' and tone_v = '1' then
        if gap_r = 0 then
          bb_i <= tone_c;   -- I = cos
          bb_q <= tone_s;   -- Q = sin
          bb_v <= '1';
          gap_r <= to_unsigned(8-1, 4);
        else
          gap_r <= gap_r - 1;
        end if;
      end if;
    end if;
  end process proc_stim;

  -----------------------------------------------------------------------------
  -- Cadena RX (identica a capa 4): interpolador -> alineacion -> loopmix con
  -- NCO RX -> decimador -> FIR RX -> AGC -> RX FIFO.
  -----------------------------------------------------------------------------
  nco_en <= itp_v;

  u_int : entity work.rf_cic_int
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>bb_v, i_i=>bb_i, q_i=>bb_q,
              int_sel_i=>SEL, i_o=>itp_i, q_o=>itp_q, valid_o=>itp_v);

  proc_align : process (clk_i) is
  begin
    if rising_edge(clk_i) then
      itpd_i <= itp_i; itpd_q <= itp_q; itpd_v <= itp_v;
    end if;
  end process proc_align;

  u_nco : entity work.rf_nco
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, en_i=>nco_en, ftw_i=>ftw_i,
              sin_o=>nco_s, cos_o=>nco_c, valid_o=>nco_v);

  u_lm : entity work.rf_loopmix
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>itpd_v, loop_en_i=>'1',
              i_i=>itpd_i, q_i=>itpd_q, sin_i=>nco_s, cos_i=>nco_c,
              rf_i_o=>rf_i, rf_q_o=>rf_q, i_o=>lm_i, q_o=>lm_q, valid_o=>lm_v);

  u_dec : entity work.rf_cic_dec
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>lm_v, i_i=>lm_i, q_i=>lm_q,
              dec_sel_i=>SEL, i_o=>dec_i, q_o=>dec_q, valid_o=>dec_v);

  u_rxfir : entity work.rf_fir
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, valid_i=>dec_v, i_i=>dec_i, q_i=>dec_q,
              coef_we_i=>coef_we_i, coef_addr_i=>coef_addr_i, coef_data_i=>coef_data_i,
              i_o=>rxfir_i, q_o=>rxfir_q, valid_o=>rxfir_v);

  u_agc : entity work.rf_agc
    port map (clk_i=>clk_i, aresetn_i=>aresetn_i, clr_i=>'0', valid_i=>rxfir_v,
              i_i=>rxfir_i, q_i=>rxfir_q, agc_en_i=>'0', shift_man_i=>"000",
              th_high_i=>x"FFFF", th_low_i=>x"0000",
              i_o=>agc_i, q_o=>agc_q, rssi_o=>rssi_o, valid_o=>agc_v);

  rxf_wr_en   <= agc_v;
  rxf_wr_data <= agc_i & agc_q;

  u_rxf : entity work.word_fifo
    generic map (LOG2_DEPTH=>9)
    port map (clk=>clk_i, aresetn=>aresetn_i, wr_en=>rxf_wr_en, wr_data=>rxf_wr_data,
              full=>rxf_full_o, rd_en=>rxf_rd_en_i, rd_data=>rxf_rd_data_o,
              empty=>rxf_empty_o, level=>rxf_level_u);

  rxf_level_o <= std_logic_vector(rxf_level_u);

end architecture rtl;
