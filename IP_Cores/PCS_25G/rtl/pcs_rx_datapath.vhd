-------------------------------------------------------------------------------
-- Core 19 - PCS 64B/66B @ 25G
-- Datapath PCS RX completo: gearbox RX + block sync + split 66b +
-- descrambler + decoder.
--
--   palabras del PMA
--     -> gearbox RX (64 -> 66) with bit slip
--     -> pcs_blocksync: clause-49 lock state machine (drives the slip) and
--        BER monitor on every sync header leaving the gearbox
--     -> split: sync = block(1:0), payload_scrambleado = block(65:2)
--     -> descrambler: descramblea el payload (sync NO entra)
--     -> decoder: header classification (audit 2026-11, fixes A2/A3):
--          block(1:0) = "10" (wire: 0 then 1) -> data
--          block(1:0) = "01" (wire: 1 then 0) -> control
--          "00" / "11"                        -> INVALID (out_hdr_ok = 0);
--        before the fix invalid headers were silently decoded as control.
--
-- El sync se retrasa 1 ciclo para alinearse con la salida del descrambler
-- (1 ciclo de latencia), igual que en el TX. out_valid is NOT gated by
-- block_lock (the self-synchronous descrambler needs every block); a
-- consumer must discard blocks while out_lock = '0' (clause 49 RX state
-- machine sends LBLOCK_R then).
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcs_rx_datapath is
  generic (
    SLIP_WAIT    : natural := 4;       -- gearbox slip latency is 1 cycle
    HIBER_WINDOW : natural := 48828    -- 125 us at 390.625 MHz
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    resync     : in  std_logic := '0';
    -- entrada de palabras de 64 bits desde el PMA
    in_valid   : in  std_logic;
    in_word    : in  std_logic_vector(63 downto 0);
    in_ready   : out std_logic;
    -- salida de payload + tipo recuperados
    out_valid  : out std_logic;
    out_payload: out std_logic_vector(63 downto 0);
    out_is_data: out std_logic;
    out_hdr_ok : out std_logic;        -- sync header of this block valid
    -- block sync status / events (aligned with the gearbox output)
    out_lock   : out std_logic;
    out_hi_ber : out std_logic;
    ev_goodsh  : out std_logic;
    ev_badsh   : out std_logic;
    ev_slip    : out std_logic;
    ev_lost    : out std_logic
  );
end entity pcs_rx_datapath;

architecture rtl of pcs_rx_datapath is
  -- gearbox RX
  signal gb_out_valid : std_logic;
  signal gb_out_block : std_logic_vector(65 downto 0);
  signal gb_slip      : std_logic;
  -- descrambler
  signal des_en    : std_logic;
  signal des_din   : std_logic_vector(63 downto 0);
  signal des_dout  : std_logic_vector(63 downto 0);
  signal des_valid : std_logic;
  -- sync retrasado 1 ciclo para casar con la salida del descrambler
  signal sync_d1   : std_logic_vector(1 downto 0) := (others => '0');
begin

  -- gearbox RX
  u_gb: entity work.pcs_gearbox_rx
    port map (clk=>clk, rst=>rst, in_valid=>in_valid, in_word=>in_word,
              in_ready=>in_ready, slip=>gb_slip,
              out_valid=>gb_out_valid, out_block=>gb_out_block);

  -- clause-49 block sync on the raw headers
  u_bs: entity work.pcs_blocksync
    generic map (SLIP_WAIT => SLIP_WAIT, HIBER_WINDOW => HIBER_WINDOW)
    port map (clk=>clk, rst=>rst, resync=>resync,
              in_valid=>gb_out_valid, in_header=>gb_out_block(1 downto 0),
              slip=>gb_slip, lock=>out_lock, hi_ber=>out_hi_ber,
              ev_goodsh=>ev_goodsh, ev_badsh=>ev_badsh, ev_slip=>ev_slip,
              ev_gained=>open, ev_lost=>ev_lost, ev_hiber=>open);

  -- split del bloque 66b y alimentacion al descrambler
  des_en  <= gb_out_valid;
  des_din <= gb_out_block(65 downto 2);   -- payload scrambleado

  -- instancia descrambler en modo descramble (mode='1')
  u_des: entity work.pcs_scrambler
    port map (clk=>clk, rst=>rst, en=>des_en, mode=>'1',
              din=>des_din, dout=>des_dout, dvalid=>des_valid);

  -- retrasar el sync 1 ciclo para casar con des_dout
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sync_d1 <= (others => '0');
      elsif des_en = '1' then
        sync_d1 <= gb_out_block(1 downto 0);
      end if;
    end if;
  end process;

  out_valid   <= des_valid;
  out_payload <= des_dout;
  out_is_data <= '1' when sync_d1 = "10" else '0';     -- IEEE data header
  out_hdr_ok  <= sync_d1(0) xor sync_d1(1);

end architecture rtl;
