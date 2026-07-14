-- ============================================================================
-- pcie_node.vhd -- PCIE IP v1
-- Nodo PCIe completo (un extremo del enlace). Integra las cuatro capas:
--
--   [training]  LTSSM + ts_gen ----\
--                                    >-- MUX TX -- scrambler_tx --> PIPE out
--   [L0 datos]  DLL_TX + framer ----/
--
--   PIPE in -- scrambler_rx -- deframer --+-- ts_valid --> LTSSM
--                                          +-- tokens ----> rx_adapt --+
--                                                      out_* --> DLL_RX (ACK/NAK)
--                                                      tl_*  --> TL_EP (MWr/MRd)
--
-- El ACK/NAK que produce la DLL_RX se realimenta a la DLL_TX del MISMO nodo
-- (lazo interno): en LOOP_INT ambos nodos comparten el cable, y el ACK viaja
-- como parte del stliteral no en v1; para el bring-up validamos el lazo de
-- fiabilidad dentro de cada nodo y el datapath de datos entre nodos.
--
-- Rol RC/EP: 'is_rc'. El RC inyecta TLPs por req_*; el EP responde como
-- completer y su respuesta (CplD/MSI) sale por su propia DLL_TX -> framer.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_8b10b_pkg.all;
use work.pcie_ltssm_pkg.all;
use work.pcie_tl_pkg.all;
use work.pcie_dll_pkg.all;

entity pcie_node is
  generic (
    is_rc     : boolean := false;
    TIMEOUT_C : integer := 5000
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    en         : in  std_logic;

    cmd_start  : in  std_logic;
    cmd_hotrst : in  std_logic;

    pt_sym     : out work.pcie_8b10b_pkg.byte_t;
    pt_k       : out std_logic;
    pr_sym     : in  work.pcie_8b10b_pkg.byte_t;
    pr_k       : in  std_logic;

    -- inyeccion de TLP crudo (header+payload) hacia la DLL local
    req_valid  : in  std_logic;
    req_data   : in  work.pcie_8b10b_pkg.byte_t;
    req_last   : in  std_logic;
    req_ready  : out std_logic;

    msi_trigger: in  std_logic;

    link_up    : out std_logic;
    ltssm_state: out std_logic_vector(3 downto 0);
    bar0_dbg   : out work.pcie_tl_pkg.dw_t;
    mwr_cnt    : out std_logic_vector(15 downto 0);
    mrd_cnt    : out std_logic_vector(15 downto 0);
    good_rx    : out std_logic_vector(15 downto 0);
    replays    : out std_logic_vector(15 downto 0);
    -- salida del completer (para que el TB observe el CplD del EP)
    tlresp_valid : out std_logic;
    tlresp_data  : out work.pcie_8b10b_pkg.byte_t;
    tlresp_start : out std_logic;
    tlresp_last  : out std_logic;
    -- TLP recibido del enlace (header+payload sin seq/LCRC), para que el RC
    -- capture CplDs y otros TLPs entrantes en su FIFO RX.
    rxtlp_valid  : out std_logic;
    rxtlp_data   : out work.pcie_8b10b_pkg.byte_t;
    rxtlp_start  : out std_logic;
    rxtlp_last   : out std_logic
  );
end entity;

architecture rtl of pcie_node is
  signal send_ts, ts_kind : std_logic;
  signal ts_ctl : work.pcie_8b10b_pkg.byte_t;
  signal ts_done : std_logic;
  signal lt_state : std_logic_vector(3 downto 0);
  signal lup : std_logic;

  signal g_sym : work.pcie_8b10b_pkg.byte_t; signal g_k, g_com, g_skp, g_byp, g_active : std_logic;
  signal f_sym : work.pcie_8b10b_pkg.byte_t; signal f_k, f_com, f_skp, f_byp, f_busy : std_logic;
  signal d2f_valid, d2f_last, d2f_ready, d2f_start : std_logic;
  signal d2f_data : work.pcie_8b10b_pkg.byte_t;

  signal tx_sym : work.pcie_8b10b_pkg.byte_t; signal tx_k, tx_com, tx_skp, tx_byp : std_logic;
  signal rx_sym : work.pcie_8b10b_pkg.byte_t; signal rx_k, rxcom, rxskp : std_logic;

  signal tok : rx_kind_t; signal tok_data : work.pcie_8b10b_pkg.byte_t; signal tok_valid : std_logic;
  signal ts_valid, ts_is_ts2, dfr_com, dfr_skp : std_logic;
  signal ts_link, ts_lane, ts_nfts, ts_rate, ts_ctl_rx : work.pcie_8b10b_pkg.byte_t;

  -- adaptador RX
  signal ao_v, ao_s, ao_l : std_logic; signal ao_d : work.pcie_8b10b_pkg.byte_t;
  signal at_v, at_s, at_l : std_logic; signal at_d : work.pcie_8b10b_pkg.byte_t;

  -- DLL RX -> ACK/NAK -> DLL TX
  signal ak_req, ak_nak : std_logic; signal ak_seq : std_logic_vector(11 downto 0);
  -- En v1 el ACK/NAK NO viaja como DLLP entre nodos (deuda documentada): el
  -- lazo ak de la DLL_RX a la DLL_TX del mismo nodo sirve solo para la purga
  -- del replay buffer por ACK. Un NAK del lazo interno (p.ej. por una
  -- diferencia de LCRC en la ruta integrada) NO debe disparar retransmision,
  -- porque duplicaria el TLP hacia el otro nodo sin un protocolo de
  -- retransmision real. Se enmascara: solo se propagan ACKs (ak_nak forzado a
  -- '0'); el mecanismo de replay real quedo verificado de forma aislada en la
  -- capa DLL (Paso 4).
  signal ak_req_tx, ak_nak_tx : std_logic;
  -- MUX de entrada a la DLL_TX
  signal src_resp : std_logic := '0';
  signal dtx_valid, dtx_last, dll_ready : std_logic;
  signal dtx_data : work.pcie_8b10b_pkg.byte_t;
  signal tlep_ready : std_logic;
begin

  link_up     <= lup;
  ltssm_state <= lt_state;
  rxtlp_valid <= at_v;
  rxtlp_data  <= at_d;
  rxtlp_start <= at_s;
  rxtlp_last  <= at_l;

  u_ltssm : entity work.pcie_ltssm
    generic map (TIMEOUT_CYCLES => TIMEOUT_C)
    port map (clk=>clk, rst=>rst, en=>en,
              cmd_start=>cmd_start, cmd_hotrst=>cmd_hotrst,
              cmd_loopbk=>'0', cmd_disable=>'0',
              tx_send_ts=>send_ts, tx_ts_kind=>ts_kind, tx_ctl=>ts_ctl,
              tx_ts_done=>ts_done,
              rx_ts_valid=>ts_valid, rx_is_ts2=>ts_is_ts2, rx_ctl=>ts_ctl_rx,
              state_o=>lt_state, link_up=>lup,
              ts1_rx_cnt=>open, ts2_rx_cnt=>open);

  u_tsgen : entity work.pcie_ts_gen
    port map (clk=>clk, rst=>rst, en=>en,
              send=>send_ts, ts_kind=>ts_kind, train_ctl=>ts_ctl,
              n_fts=>x"08", link_num=>PAD_BYTE, lane_num=>PAD_BYTE,
              done=>ts_done, active=>g_active,
              sym=>g_sym, sym_k=>g_k, sym_com=>g_com, sym_skp=>g_skp,
              sym_byp=>g_byp);

  -- MUX de entrada a la DLL_TX: combina dos fuentes de TLP a transmitir:
  --   (a) req_*    : peticiones inyectadas por el firmware (rol RC).
  --   (b) tlresp_* : respuestas (CplD/MSI) generadas por el completer local
  --                  (rol EP), que deben viajar por el enlace al otro extremo.
  -- Prioridad: una respuesta del completer en curso se transmite entera antes
  -- de atender una nueva peticion. Se usa un latch de "fuente activa" para no
  -- entremezclar dos TLPs. tlresp no tiene contrapresion (tx_ready='1' en el
  -- TL), asi que cuando aparece se sirve de inmediato.
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        src_resp <= '0';
      else
        -- engancha la fuente 'respuesta' al ver su primer byte, la suelta al last
        if tlresp_valid='1' and tlresp_start='1' then
          src_resp <= '1';
        elsif src_resp='1' and dtx_valid='1' and dtx_last='1' then
          src_resp <= '0';
        end if;
      end if;
    end if;
  end process;

  -- seleccion de la fuente activa hacia la DLL_TX
  dtx_valid <= tlresp_valid when (src_resp='1' or (tlresp_valid='1' and tlresp_start='1'))
               else req_valid;
  dtx_data  <= tlresp_data  when (src_resp='1' or (tlresp_valid='1' and tlresp_start='1'))
               else req_data;
  dtx_last  <= tlresp_last  when (src_resp='1' or (tlresp_valid='1' and tlresp_start='1'))
               else req_last;
  -- req_ready: la peticion externa se acepta solo cuando no hay respuesta activa
  req_ready <= dll_ready when (src_resp='0' and not(tlresp_valid='1' and tlresp_start='1'))
               else '0';

  u_dlltx : entity work.pcie_dll_tx
    generic map (MAX_TLP => 64, REPLAY_SLOTS => 8)
    port map (clk=>clk, rst=>rst,
              tl_valid=>dtx_valid, tl_data=>dtx_data, tl_last=>dtx_last,
              tl_ready=>dll_ready,
              fr_valid=>d2f_valid, fr_data=>d2f_data, fr_last=>d2f_last,
              fr_ready=>d2f_ready, fr_start=>d2f_start,
              ak_valid=>ak_req_tx, ak_is_nak=>ak_nak_tx, ak_seq=>ak_seq,
              nseq_o=>open, acked_o=>open, inflight_o=>open, replays_o=>replays);

  u_framer : entity work.pcie_tlp_frame
    generic map (SKP_INTERVAL => 600)
    port map (clk=>clk, rst=>rst, en=>en,
              start=>d2f_start, din=>d2f_data, dvalid=>d2f_valid,
              dlast=>d2f_last, dready=>d2f_ready,
              sym=>f_sym, sym_k=>f_k, sym_com=>f_com, sym_skp=>f_skp,
              sym_byp=>f_byp, busy=>f_busy);

  -- MUX TX: en training (no L0) manda el ts_gen. En L0, el framer manda
  -- SIEMPRE que este ocupado (f_busy) para no cortar una trama a medias; solo
  -- cede a training si el framer esta libre y el LTSSM pide TS.
  process(lup, g_active, send_ts, f_busy, g_sym, g_k, g_com, g_skp, g_byp,
          f_sym, f_k, f_com, f_skp, f_byp)
  begin
    if lup='1' and (f_busy='1' or (g_active='0' and send_ts='0')) then
      tx_sym<=f_sym; tx_k<=f_k; tx_com<=f_com; tx_skp<=f_skp; tx_byp<=f_byp;
    else
      tx_sym<=g_sym; tx_k<=g_k; tx_com<=g_com; tx_skp<=g_skp; tx_byp<=g_byp;
    end if;
  end process;

  u_scrtx : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>en, din=>tx_sym, is_k=>tx_k,
              is_com=>tx_com, is_skp=>tx_skp, bypass=>tx_byp,
              dout=>pt_sym, dout_k=>pt_k, lfsr_mon=>open);

  rxcom <= '1' when (pr_k='1' and pr_sym=K_COM) else '0';
  rxskp <= '1' when (pr_k='1' and pr_sym=K_SKP) else '0';
  u_scrrx : entity work.pcie_scrambler
    port map (clk=>clk, rst=>rst, en=>en, din=>pr_sym, is_k=>pr_k,
              is_com=>rxcom, is_skp=>rxskp, bypass=>'0',
              dout=>rx_sym, dout_k=>rx_k, lfsr_mon=>open);

  u_deframer : entity work.pcie_deframer
    port map (clk=>clk, rst=>rst, en=>en, sym=>rx_sym, sym_k=>rx_k,
              tok=>tok, tok_data=>tok_data, tok_valid=>tok_valid,
              ts_valid=>ts_valid, ts_is_ts2=>ts_is_ts2,
              ts_link=>ts_link, ts_lane=>ts_lane, ts_nfts=>ts_nfts,
              ts_rate=>ts_rate, ts_ctl=>ts_ctl_rx,
              is_com_o=>dfr_com, is_skp_o=>dfr_skp);

  u_adapt : entity work.pcie_rx_adapt
    port map (clk=>clk, rst=>rst, tok=>tok, tok_data=>tok_data,
              tok_valid=>tok_valid,
              out_valid=>ao_v, out_data=>ao_d, out_start=>ao_s, out_last=>ao_l,
              tl_valid=>at_v, tl_data=>at_d, tl_start=>at_s, tl_last=>at_l);

  u_dllrx : entity work.pcie_dll_rx
    port map (clk=>clk, rst=>rst,
              in_valid=>ao_v, in_data=>ao_d, in_start=>ao_s, in_last=>ao_l,
              tl_valid=>open, tl_data=>open, tl_last=>open,
              ak_req=>ak_req, ak_is_nak=>ak_nak, ak_seq=>ak_seq,
              good_o=>good_rx, bad_o=>open, nextrx_o=>open);

  -- tx_ready del completer sigue a la disponibilidad de la DLL. El MUX ya
  -- garantiza que cuando el completer emite (tlresp), su stream es el activo.
  tlep_ready <= dll_ready;

  -- enmascarado del lazo interno: propagar solo ACKs (para purga), nunca NAK
  ak_req_tx <= ak_req and (not ak_nak);
  ak_nak_tx <= '0';

  u_tlep : entity work.pcie_tl_ep
    generic map (BAR0_WORDS => 256)
    port map (clk=>clk, rst=>rst,
              rx_valid=>at_v, rx_data=>at_d, rx_start=>at_s, rx_last=>at_l,
              tx_valid=>tlresp_valid, tx_data=>tlresp_data,
              tx_start=>tlresp_start, tx_last=>tlresp_last, tx_ready=>tlep_ready,
              msi_trigger=>msi_trigger,
              bar0_dbg=>bar0_dbg, cfg_done=>open,
              mwr_cnt_o=>mwr_cnt, mrd_cnt_o=>mrd_cnt);

end architecture;
