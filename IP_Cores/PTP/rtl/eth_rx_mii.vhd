-- eth_rx_mii.vhd — motor RX MII 100 Mbit/s (familia TSN Ethernet, MAC v1)
--
-- Deserializador de nibbles a 25 MHz (via mii_ce). Detecta el preambulo/SFD,
-- reensambla bytes (nibble bajo primero), verifica el FCS/CRC-32 por hardware
-- y aplica el filtrado por MAC destino. Entrega la trama byte a byte con
-- rx_valid/rx_last; una trama con FCS malo, runt (<64 bytes con FCS) o filtrada
-- se DESCARTA (rx_valid nunca se afirma para ella).
--
-- Criterio FCS: correr el CRC reflejado (init 0xFFFFFFFF, sin complementar)
-- sobre TODA la trama incluido el FCS -> residuo canonico 0xDEBB20E3.
--
-- Filtrado: acepta si dst == MACADDR, o dst == broadcast, o promisc = '1'.
-- Se decide con los 6 primeros bytes; el resto de la trama se bufferea en
-- una FIFO interna de una trama y se vuelca solo si FCS ok y filtro acepta.
--
-- Maximum length (audit 2026-11, ALTA): a frame longer than G_MAXLEN bytes
-- (FCS included) is DOOMED at byte G_MAXLEN+1: no further bytes are stored,
-- the engine keeps swallowing nibbles until RX_DV drops, then pulses
-- ev_oversize and NEVER drains it. Byte/pointer counters saturate, so frames
-- of any length (even > 4095 bytes) cannot wrap a counter or truncate the
-- buffer. G_MAXLEN must be <= 2048 (buffer size). Use 1518 for untagged
-- MTU frames, 1522 when 802.1Q tags must pass (TSN switch).
-- This file is shared by ETH, PTP (byte-identical copy) and TSN.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_pkg.all;

entity eth_rx_mii is
  generic (
    G_MAXLEN : integer := 1518                    -- MTU (14+1500+4)
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;                     -- sincrono activo-alto
    mii_ce   : in  std_logic;                     -- pulso a tasa de nibble
    -- configuracion de filtrado
    macaddr  : in  std_logic_vector(47 downto 0); -- MAC propia, byte0 en [7:0]
    promisc  : in  std_logic;
    -- MII RX
    rxd      : in  std_logic_vector(3 downto 0);
    rx_dv    : in  std_logic;
    -- entrega de la trama recibida (aceptada)
    rx_data  : out std_logic_vector(7 downto 0);
    rx_valid : out std_logic;                     -- pulso de 1 clk por byte
    rx_last  : out std_logic;                     -- ultimo byte de datos (sin FCS)
    -- eventos (pulsos de 1 clk)
    ev_ok    : out std_logic;                     -- trama aceptada y volcada
    ev_crc   : out std_logic;                     -- descartada por FCS malo
    ev_runt  : out std_logic;                     -- descartada por runt
    ev_drop  : out std_logic;                     -- descartada por filtro MAC
    ev_oversize : out std_logic;                  -- descartada: > G_MAXLEN bytes
    -- pulso de 1 ciclo en el instante de deteccion del SFD (para PTP TS).
    -- Convenio identico al TX (nibble 0xD, fin de preambulo).
    rx_sfd_pulse : out std_logic;
    -- sonda: dst capturado de la trama en curso/ultima (para debug de filtro)
    dbg_dst  : out std_logic_vector(47 downto 0);
    dbg_nb   : out std_logic_vector(11 downto 0)
  );
end entity eth_rx_mii;

architecture rtl of eth_rx_mii is

  type st_t is (ST_IDLE, ST_PRE, ST_DAT_LO, ST_DAT_HI, ST_END);
  signal st : st_t := ST_IDLE;

  -- Frame buffer used as a RING (audit 2026-11): frame N+1 is written behind
  -- frame N, so a long frame still being drained is never clobbered by a
  -- short frame that completes before the drain ends (the v1 single-frame
  -- buffer restarted the drain at index 0 -> corrupted long frame when a
  -- >~1140-byte frame was followed by a minimum-size frame).
  -- Safety: the drain (1 byte/clk) is >= 8x faster than reception (1 byte
  -- per 2 nibbles), it starts before the next frame's first byte arrives, and
  -- a frame is at most G_MAXLEN <= 2048 bytes, so the writer can never reach
  -- undrained bytes. One pending-drain slot covers "frame N+1 accepted while
  -- N still drains" (at most one can be pending by the same rate argument).
  type mem_t is array (0 to 2047) of std_logic_vector(7 downto 0);
  signal mem      : mem_t;
  signal wr_ptr   : unsigned(10 downto 0) := (others => '0');
  signal fr_start : unsigned(10 downto 0) := (others => '0');
  signal doomed   : std_logic := '0';             -- frame exceeded G_MAXLEN

  signal crc     : std_logic_vector(31 downto 0) := (others => '1');
  signal lo      : std_logic_vector(3 downto 0)  := (others => '0');
  -- bytes received (FCS included); saturates at G_MAXLEN+1 (never wraps)
  signal nb      : integer range 0 to 2049 := 0;
  signal dst     : std_logic_vector(47 downto 0) := (others => '0');

  -- volcado (drain) + one pending descriptor
  signal drain     : std_logic := '0';
  signal drain_i   : unsigned(10 downto 0) := (others => '0');
  signal drain_rem : integer range 0 to 2048 := 0;
  signal pend_v    : std_logic := '0';
  signal pend_st   : unsigned(10 downto 0) := (others => '0');
  signal pend_len  : integer range 0 to 2048 := 0;

  constant CRC_RESIDUE : std_logic_vector(31 downto 0) := x"DEBB20E3";

  function filt_ok(d : std_logic_vector(47 downto 0);
                   m : std_logic_vector(47 downto 0);
                   p : std_logic) return boolean is
  begin
    if p = '1' then return true; end if;
    if d = m then return true; end if;
    if d = x"FFFFFFFFFFFF" then return true; end if;
    return false;
  end function;

begin

  assert G_MAXLEN >= 64 and G_MAXLEN <= 2048
    report "eth_rx_mii: G_MAXLEN must be in 64..2048 (frame buffer size)" severity failure;

  dbg_dst <= dst;
  dbg_nb  <= std_logic_vector(to_unsigned(nb, 12));

  process(clk)
    variable dlen  : integer;
  begin
    if rising_edge(clk) then
      rx_valid <= '0';
      rx_last  <= '0';
      ev_ok    <= '0';
      ev_crc   <= '0';
      ev_runt  <= '0';
      ev_drop  <= '0';
      ev_oversize <= '0';
      rx_sfd_pulse <= '0';

      if rst = '1' then
        st     <= ST_IDLE;
        drain  <= '0';
        pend_v <= '0';
        wr_ptr <= (others => '0');
        doomed <= '0';

      else
        -- volcado de la trama aceptada (independiente del mii_ce, 1 byte/clk)
        if drain = '1' then
          rx_data  <= mem(to_integer(drain_i));
          rx_valid <= '1';
          drain_i  <= drain_i + 1;
          if drain_rem = 1 then
            rx_last <= '1';
            ev_ok   <= '1';
            drain   <= '0';
          else
            drain_rem <= drain_rem - 1;
          end if;
        elsif pend_v = '1' then
          -- start the pending frame one idle cycle after the previous rx_last
          -- (keeps the >= 1-cycle gap consumers such as tsn_ingress rely on)
          drain     <= '1';
          drain_i   <= pend_st;
          drain_rem <= pend_len;
          pend_v    <= '0';
        end if;

        if mii_ce = '1' then
          case st is

            when ST_IDLE =>
              if rx_dv = '1' then
                if rxd = x"D" then                -- SFD directo (sin ver preambulo)
                  rx_sfd_pulse <= '1';            -- pulso SFD: instante de TS RX
                  crc      <= CRC32_INIT;
                  fr_start <= wr_ptr;
                  nb       <= 0;
                  doomed   <= '0';
                  st       <= ST_DAT_LO;
                elsif rxd = x"5" then
                  st <= ST_PRE;
                end if;
              end if;

            when ST_PRE =>
              if rx_dv = '0' then
                st <= ST_IDLE;
              elsif rxd = x"D" then               -- SFD: fin de preambulo
                rx_sfd_pulse <= '1';              -- pulso SFD: instante de TS RX
                crc      <= CRC32_INIT;
                fr_start <= wr_ptr;
                nb       <= 0;
                doomed   <= '0';
                st       <= ST_DAT_LO;
              elsif rxd /= x"5" then
                st <= ST_IDLE;                     -- preambulo corrupto
              end if;

            when ST_DAT_LO =>
              if rx_dv = '0' then
                st <= ST_END;
              else
                lo  <= rxd;
                crc <= crc32_nibble(crc, rxd);
                st  <= ST_DAT_HI;
              end if;

            when ST_DAT_HI =>
              if rx_dv = '0' then                 -- nibbles impares: trama mal formada
                st <= ST_END;
              else
                crc <= crc32_nibble(crc, rxd);
                if nb >= G_MAXLEN then
                  -- byte G_MAXLEN+1: doom the frame, store nothing more,
                  -- keep swallowing until RX_DV drops (counter saturates)
                  doomed <= '1';
                  nb     <= G_MAXLEN + 1;
                else
                  mem(to_integer(wr_ptr)) <= rxd & lo;
                  wr_ptr <= wr_ptr + 1;           -- ring: wraps modulo 2048
                  nb     <= nb + 1;
                end if;
                if nb < 6 then
                  dst(nb*8+7 downto nb*8) <= rxd & lo;  -- byte nb en [nb*8+7:nb*8]
                end if;
                st <= ST_DAT_LO;
              end if;

            when ST_END =>
              null;                               -- se procesa fuera del ce
          end case;
        end if;

        -- fin de trama: evaluar longitud + FCS + filtro y decidir volcado
        if st = ST_END then
          dlen := nb - 4;                         -- bytes de datos (sin FCS)
          if doomed = '1' or nb < 64 or crc /= CRC_RESIDUE
             or not filt_ok(dst, macaddr, promisc) then
            wr_ptr <= fr_start;                   -- rejected: give the space back
            if doomed = '1' then
              ev_oversize <= '1';                 -- > G_MAXLEN: never drained
            elsif nb < 64 then
              ev_runt <= '1';
            elsif crc /= CRC_RESIDUE then
              ev_crc <= '1';
            else
              ev_drop <= '1';
            end if;
          else
            -- accepted: keep only the data bytes (drop the 4 FCS bytes)
            wr_ptr <= fr_start + to_unsigned(dlen, 11);
            if drain = '0' and pend_v = '0' then
              drain     <= '1';
              drain_i   <= fr_start;
              drain_rem <= dlen;
            else
              assert pend_v = '0'
                report "eth_rx_mii: second pending frame (impossible by rate)" severity failure;
              pend_v   <= '1';
              pend_st  <= fr_start;
              pend_len <= dlen;
            end if;
          end if;
          st <= ST_IDLE;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
