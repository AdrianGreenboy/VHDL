-- ============================================================================
-- pcie_tl_ep.vhd -- PCIE IP (reworked in audit 2026-11)
-- Transaction Layer, Endpoint side (completer). Receives VALIDATED TLPs as a
-- byte stream (start/last) from the DLL RX buffer and executes:
--   * MWr3   : writes 'Length' DW into BAR0 (internal RAM) from addr.
--   * MRd3   : reads 'Length' DW from BAR0 and returns CplD(s).
--   * CfgWr0 : writes config space, returns Cpl (SC).
--   * CfgRd0 : reads config space, returns CplD.
--   * MSI    : on msi_trigger, emits MWr3 to the MSI address with MSI data.
--
-- Audit 2026-11 changes:
--   * rx_ready: real backpressure; bytes are only consumed in S_HDR / S_WDATA /
--     S_DRAIN, the upstream FIFO holds the rest while completions are sent.
--   * MRd honors Length (1..1024 DW): the data is returned in one or more
--     CplDs, split at 64-byte (RCB) aligned boundaries, max 16 DW each, with
--     correct Byte Count / Lower Address fields.
--   * MRd outside BAR0 (or running past its end), MRd 4DW, and other
--     non-posted requests that are not supported -> Cpl with status UR.
--   * MWr outside / running past BAR0 is dropped (posted: no completion).
--   * CfgWr0 now returns a Cpl (it is a non-posted request).
--   * TLPs of unknown/unsupported type, and the payload of completions
--     received by this node, are drained to their 'last' byte (they used to
--     be re-parsed as headers).
--   * MSI request is latched (msi_pend) and served only from a truly idle
--     S_HDR (no header byte received yet), so it can no longer clobber the
--     parse of a TLP in progress.
-- Byte enables are not interpreted (full DWs are read/written).
-- Config space Type 0 (subset): 0x00 Vendor/Device, 0x08 Class/Rev,
--   0x10 BAR0, 0x3C IntLine, MSI cap 0x50 (addr) / 0x54 (data).
-- TLP format: big-endian bytes, no seq/LCRC (DLL). 3DW header = 12 bytes.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie_tl_pkg.all;

entity pcie_tl_ep is
  generic (
    BAR0_WORDS : integer := 256    -- BAR0 size in DW (power of 2, <= 1024)
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    -- incoming TLP (validated, from the DLL RX buffer)
    rx_valid   : in  std_logic;
    rx_data    : in  byte_t;
    rx_start   : in  std_logic;
    rx_last    : in  std_logic;
    rx_ready   : out std_logic;

    -- response TLP (towards DLL TX)
    tx_valid   : out std_logic;
    tx_data    : out byte_t;
    tx_start   : out std_logic;
    tx_last    : out std_logic;
    tx_ready   : in  std_logic;

    msi_trigger: in  std_logic;

    -- monitor
    bar0_dbg   : out dw_t;          -- last DW written into BAR0
    cfg_done   : out std_logic;     -- pulse on a cfg access
    mwr_cnt_o  : out std_logic_vector(15 downto 0);
    mrd_cnt_o  : out std_logic_vector(15 downto 0);
    ur_cnt_o   : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of pcie_tl_ep is
  type bar_t is array (0 to BAR0_WORDS-1) of dw_t;
  signal bar0 : bar_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of bar0 : signal is "block";

  type cfg_t is array (0 to 31) of dw_t;
  signal cfg : cfg_t := (others => (others => '0'));

  type rstate_t is (S_HDR, S_WDATA, S_DRAIN, S_EXEC, S_CPL_HDR, S_CPL_DATA);
  signal st : rstate_t := S_HDR;

  type hbytes_t is array (0 to 11) of byte_t;
  signal hbuf : hbytes_t := (others => (others=>'0'));
  signal hcnt : integer range 0 to 12 := 0;

  -- request being served
  type req_t is (Q_NONE, Q_MRD, Q_CFGRD, Q_CFGWR, Q_UR, Q_MSI);
  signal req      : req_t := Q_NONE;
  signal after_rx : req_t := Q_NONE;   -- completion to send once the TLP is consumed
  signal addr     : unsigned(31 downto 0) := (others=>'0');
  signal reqid    : std_logic_vector(15 downto 0) := (others=>'0');
  signal tag      : byte_t := (others=>'0');
  signal is_cfg   : boolean := false;

  signal wr_idx   : integer range 0 to BAR0_WORDS-1 := 0;
  signal wr_word  : dw_t := (others=>'0');
  signal wr_bpos  : integer range 0 to 3 := 0;
  signal wr_left  : integer range 0 to 1024 := 0;
  signal wr_ok    : boolean := false;

  signal rd_idx   : integer range 0 to BAR0_WORDS-1 := 0;
  signal rem_dw   : integer range 0 to 1024 := 0;   -- DW still to return
  signal chunk_dw : integer range 0 to 16 := 0;     -- DW in the current CplD
  signal dw_k     : integer range 0 to 16 := 0;
  signal cpl_data : dw_t := (others=>'0');

  signal mwr_cnt, mrd_cnt, ur_cnt : unsigned(15 downto 0) := (others=>'0');

  signal obuf : hbytes_t := (others => (others=>'0'));
  signal oi   : integer range 0 to 11 := 0;

  signal msi_pend : std_logic := '0';
  signal msi_go   : std_logic;
  signal rx_rdy_i : std_logic;

  constant CPL_REQID : std_logic_vector(15 downto 0) := x"0100"; -- EP completer ID
  constant ST_SC : std_logic_vector(2 downto 0) := "000";
  constant ST_UR : std_logic_vector(2 downto 0) := "001";
begin

  mwr_cnt_o <= std_logic_vector(mwr_cnt);
  mrd_cnt_o <= std_logic_vector(mrd_cnt);
  ur_cnt_o  <= std_logic_vector(ur_cnt);

  -- MSI is started only from an idle header state with no byte of a new TLP
  -- consumed yet; in that cycle no RX byte is accepted.
  msi_go   <= '1' when msi_pend = '1' and st = S_HDR and hcnt = 0 else '0';
  rx_rdy_i <= '1' when (st = S_HDR and msi_go = '0') or st = S_WDATA or st = S_DRAIN
              else '0';
  rx_ready <= rx_rdy_i;

  -- TX outputs are combinational from state + pointer (each byte presented once)
  comb_tx : process(st, oi, obuf, cpl_data, chunk_dw, dw_k)
  begin
    tx_valid <= '0'; tx_data <= (others=>'0');
    tx_start <= '0'; tx_last <= '0';
    case st is
      when S_CPL_HDR =>
        tx_valid <= '1';
        tx_data  <= obuf(oi);
        if oi = 0 then tx_start <= '1'; end if;
        if oi = 11 and chunk_dw = 0 then tx_last <= '1'; end if;
      when S_CPL_DATA =>
        tx_valid <= '1';
        case oi is
          when 0 => tx_data <= cpl_data(31 downto 24);
          when 1 => tx_data <= cpl_data(23 downto 16);
          when 2 => tx_data <= cpl_data(15 downto 8);
          when others => tx_data <= cpl_data(7 downto 0);
        end case;
        if oi = 3 and dw_k = chunk_dw - 1 then tx_last <= '1'; end if;
      when others =>
        null;
    end case;
  end process;

  process(clk)
    variable b0    : byte_t;
    variable a     : integer;
    variable ldw   : integer range 0 to 1024;
    variable vaddr : std_logic_vector(31 downto 0);
    variable vword : dw_t;
    variable idx   : integer;
    variable inbar : boolean;
    variable nk    : integer range 0 to 16;
    variable bc    : unsigned(11 downto 0);
    variable la    : unsigned(6 downto 0);
    variable nxt   : req_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= S_HDR; hcnt <= 0; wr_bpos <= 0; oi <= 0; dw_k <= 0;
        req <= Q_NONE; after_rx <= Q_NONE; msi_pend <= '0';
        rem_dw <= 0; chunk_dw <= 0;
        mwr_cnt <= (others=>'0'); mrd_cnt <= (others=>'0'); ur_cnt <= (others=>'0');
        cfg_done <= '0'; bar0_dbg <= (others=>'0');
        cfg(0) <= CFG_DEVICE_ID & CFG_VENDOR_ID;   -- 0x00
        cfg(2) <= CFG_CLASS;                        -- 0x08
        cfg(4) <= (others=>'0');                    -- 0x10 BAR0 (base 0)
      else
        cfg_done <= '0';
        if msi_trigger = '1' then msi_pend <= '1'; end if;

        case st is
          -- =============== header ===============
          when S_HDR =>
            if msi_go = '1' then
              -- MWr3 to the MSI address (cfg 0x50) with data cfg(0x54)
              msi_pend <= '0';
              obuf(0) <= B0_MWR3; obuf(1) <= x"00";
              obuf(2) <= x"00"; obuf(3) <= x"01";
              obuf(4) <= CPL_REQID(15 downto 8); obuf(5) <= CPL_REQID(7 downto 0);
              obuf(6) <= x"00"; obuf(7) <= x"0F";       -- tag 0, BE=1111
              obuf(8)  <= cfg(20)(31 downto 24); obuf(9) <= cfg(20)(23 downto 16);
              obuf(10) <= cfg(20)(15 downto 8);  obuf(11) <= cfg(20)(7 downto 0);
              cpl_data <= cfg(21);
              req <= Q_MSI; chunk_dw <= 1; rem_dw <= 0; dw_k <= 0; oi <= 0;
              st <= S_CPL_HDR;
            elsif rx_valid = '1' then
              if rx_start = '1' or hcnt = 0 then
                hbuf(0) <= rx_data; hcnt <= 1;
                if rx_last = '1' then hcnt <= 0; end if;      -- runt: ignore
              elsif hcnt < 11 then
                hbuf(hcnt) <= rx_data; hcnt <= hcnt + 1;
                if rx_last = '1' then hcnt <= 0; end if;      -- runt: ignore
              else
                -- byte 11: full 3DW header available
                hcnt <= 0;
                b0    := hbuf(0);
                ldw   := to_integer(unsigned(std_logic_vector'(hbuf(2)(1 downto 0) & hbuf(3))));
                if ldw = 0 then ldw := 1024; end if;
                vaddr := hbuf(8) & hbuf(9) & hbuf(10) & rx_data;
                reqid <= hbuf(4) & hbuf(5);
                tag   <= hbuf(6);
                addr  <= unsigned(vaddr);
                idx   := to_integer(unsigned(vaddr(11 downto 2)));
                inbar := unsigned(vaddr(31 downto 2)) < BAR0_WORDS and
                         idx + ldw <= BAR0_WORDS;
                nxt := Q_NONE;
                case f_kind(b0) is
                  when TK_MWR3 =>
                    wr_ok   <= inbar;
                    if inbar then wr_idx <= idx; end if;
                    wr_left <= ldw; wr_bpos <= 0; is_cfg <= false;
                  when TK_CFGWR0 =>
                    wr_ok <= true; wr_left <= 1; wr_bpos <= 0; is_cfg <= true;
                    nxt := Q_CFGWR;
                  when TK_MRD3 =>
                    mrd_cnt <= mrd_cnt + 1;
                    if inbar then
                      nxt := Q_MRD; rd_idx <= idx; rem_dw <= ldw;
                    else
                      nxt := Q_UR;
                    end if;
                  when TK_CFGRD0 =>
                    nxt := Q_CFGRD;
                  when TK_MRD4 =>
                    nxt := Q_UR;                     -- 64-bit addressing: unsupported
                  when others =>
                    nxt := Q_NONE;                   -- Cpl/CplD/Msg/unknown: drop
                end case;
                after_rx <= nxt;
                if rx_last = '1' then
                  if nxt = Q_NONE then st <= S_HDR; else st <= S_EXEC; req <= nxt; end if;
                elsif f_kind(b0) = TK_MWR3 or f_kind(b0) = TK_CFGWR0 then
                  st <= S_WDATA;
                else
                  st <= S_DRAIN;                     -- extra bytes / payload: skip
                end if;
              end if;
            end if;

          -- =============== write data ===============
          when S_WDATA =>
            if rx_valid = '1' then
              case wr_bpos is
                when 0 => wr_word(31 downto 24) <= rx_data; wr_bpos <= 1;
                when 1 => wr_word(23 downto 16) <= rx_data; wr_bpos <= 2;
                when 2 => wr_word(15 downto 8)  <= rx_data; wr_bpos <= 3;
                when others =>
                  wr_bpos <= 0;
                  vword := wr_word(31 downto 8) & rx_data;
                  if wr_ok and wr_left > 0 then
                    if is_cfg then
                      a := to_integer(addr(6 downto 2));
                      cfg(a) <= vword;
                      cfg_done <= '1';
                    else
                      bar0(wr_idx) <= vword;
                      bar0_dbg <= vword;
                      if wr_idx < BAR0_WORDS-1 then wr_idx <= wr_idx + 1; end if;
                      mwr_cnt <= mwr_cnt + 1;
                    end if;
                    wr_left <= wr_left - 1;
                  end if;
              end case;
              if rx_last = '1' then
                if after_rx = Q_NONE then st <= S_HDR;
                else st <= S_EXEC; req <= after_rx; end if;
              end if;
            end if;

          when S_DRAIN =>
            if rx_valid = '1' and rx_last = '1' then
              if after_rx = Q_NONE then st <= S_HDR;
              else st <= S_EXEC; req <= after_rx; end if;
            end if;

          -- =============== build the next completion ===============
          when S_EXEC =>
            oi <= 0; dw_k <= 0;
            obuf(1) <= x"00"; obuf(2) <= x"00";
            obuf(4) <= CPL_REQID(15 downto 8); obuf(5) <= CPL_REQID(7 downto 0);
            obuf(8) <= reqid(15 downto 8); obuf(9) <= reqid(7 downto 0);
            obuf(10) <= tag;
            case req is
              when Q_MRD =>
                -- chunk up to the next 64-byte boundary (RCB), max 16 DW
                nk := 16 - (rd_idx mod 16);
                if rem_dw < nk then nk := rem_dw; end if;
                bc := to_unsigned((rem_dw * 4) mod 4096, 12);
                la := to_unsigned((rd_idx * 4) mod 128, 7);
                obuf(0) <= B0_CPLD;
                obuf(3) <= std_logic_vector(to_unsigned(nk, 8));
                obuf(6) <= ST_SC & '0' & std_logic_vector(bc(11 downto 8));
                obuf(7) <= std_logic_vector(bc(7 downto 0));
                obuf(11) <= '0' & std_logic_vector(la);
                chunk_dw <= nk;
                cpl_data <= bar0(rd_idx);                    -- registered read
              when Q_CFGRD =>
                a := to_integer(addr(6 downto 2));
                cpl_data <= cfg(a); cfg_done <= '1';
                obuf(0) <= B0_CPLD; obuf(3) <= x"01";
                obuf(6) <= ST_SC & "00000"; obuf(7) <= x"04"; obuf(11) <= x"00";
                chunk_dw <= 1; rem_dw <= 1;
              when Q_CFGWR =>
                obuf(0) <= B0_CPL; obuf(3) <= x"00";
                obuf(6) <= ST_SC & "00000"; obuf(7) <= x"04"; obuf(11) <= x"00";
                chunk_dw <= 0; rem_dw <= 0;
              when others =>   -- Q_UR
                ur_cnt <= ur_cnt + 1;
                obuf(0) <= B0_CPL; obuf(3) <= x"00";
                obuf(6) <= ST_UR & "00000"; obuf(7) <= x"00";
                obuf(11) <= '0' & std_logic_vector(addr(6 downto 0));
                chunk_dw <= 0; rem_dw <= 0;
            end case;
            st <= S_CPL_HDR;

          when S_CPL_HDR =>
            if tx_ready = '1' then
              if oi = 11 then
                oi <= 0;
                if chunk_dw = 0 then
                  st <= S_HDR; req <= Q_NONE;
                else
                  st <= S_CPL_DATA;
                end if;
              else
                oi <= oi + 1;
              end if;
            end if;

          when S_CPL_DATA =>
            if tx_ready = '1' then
              if oi = 3 then
                oi <= 0;
                if req = Q_MRD then
                  rem_dw <= rem_dw - 1;
                  if rd_idx < BAR0_WORDS-1 then
                    rd_idx <= rd_idx + 1;
                    cpl_data <= bar0(rd_idx + 1);            -- prefetch next DW
                  end if;
                end if;
                if dw_k = chunk_dw - 1 then
                  if req = Q_MRD and rem_dw > 1 then
                    st <= S_EXEC;                             -- next CplD chunk
                  else
                    st <= S_HDR; req <= Q_NONE;
                  end if;
                else
                  dw_k <= dw_k + 1;
                end if;
              else
                oi <= oi + 1;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture;
