-------------------------------------------------------------------------------
-- SERDES_256G - RX deframer (rx_clk domain)
--
-- Input: 2*G_LANES aligned, descrambled 66-bit blocks per valid clock, in the
-- order produced by serdes256g_tx_frame. Output: AXI4-Stream without
-- backpressure (the line cannot be stopped): m_tvalid is a strobe.
--
-- A slot is [data blocks][EOF][IDLE ...], or EOF in block 0 (the previous
-- beat was a full last beat), or all IDLE. nd = number of leading data blocks:
--   nd = NB      full beat; whether it is the last one is only known when the
--                next non-idle slot arrives (EOF in block 0 or more data), so
--                one beat is held back (h_*)
--   0 < nd < NB  last beat; block nd must be a valid EOF, otherwise the frame
--                is closed with m_tuser = '1'
--   nd = 0       EOF in block 0 closes the held beat; IDLE slots are ignored
--                (idle slots inside a frame are legal)
--
-- After link-up the deframer hunts for a frame boundary (a slot with nd < NB)
-- before it delivers anything. If the link drops with a beat held back, that
-- beat is delivered with m_tlast = '1' and m_tuser = '1'.
--
-- m_tuser = '1' (valid with m_tlast): frame is damaged.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.serdes256g_pkg.all;

entity serdes256g_rx_frame is
  generic (
    G_LANES : positive := 8
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    link_up  : in  std_logic;
    in_word  : in  std_logic_vector(G_LANES*132-1 downto 0);
    in_valid : in  std_logic;
    m_tdata  : out std_logic_vector(G_LANES*128-1 downto 0);
    m_tkeep  : out std_logic_vector(G_LANES*16-1 downto 0);
    m_tlast  : out std_logic;
    m_tuser  : out std_logic;
    m_tvalid : out std_logic
  );
end entity serdes256g_rx_frame;

architecture rtl of serdes256g_rx_frame is
  constant NB : natural := 2*G_LANES;

  signal h_valid : std_logic := '0';
  signal h_known : std_logic := '0';     -- h_last / h_err are final
  signal h_last  : std_logic := '0';
  signal h_err   : std_logic := '0';
  signal h_data  : std_logic_vector(NB*64-1 downto 0) := (others => '0');
  signal h_keep  : std_logic_vector(NB*8-1 downto 0) := (others => '0');
  signal hunt    : std_logic := '1';

  signal o_data  : std_logic_vector(NB*64-1 downto 0) := (others => '0');
  signal o_keep  : std_logic_vector(NB*8-1 downto 0) := (others => '0');
  signal o_last, o_user, o_valid : std_logic := '0';
begin

  process(clk)
    variable b      : std_logic_vector(65 downto 0);
    variable pl     : std_logic_vector(63 downto 0);
    variable lead   : t_boolv(0 to NB-1);
    variable eofv   : t_boolv(0 to NB-1);
    variable nbv    : unsigned(4*NB-1 downto 0);
    variable v_nb     : unsigned(3 downto 0);
    variable run    : boolean;
    variable n_data : std_logic_vector(NB*64-1 downto 0);
    variable n_keep : std_logic_vector(NB*8-1 downto 0);
    variable n_any, n_full, n_eof0, n_err : boolean;
    variable hv     : std_logic;          -- h_valid after the emit phase
    variable k      : std_logic_vector(NB*8-1 downto 0);
  begin
    if rising_edge(clk) then
      o_valid <= '0';

      if rst = '1' then
        h_valid <= '0';
        h_known <= '0';
        h_last  <= '0';
        h_err   <= '0';
        hunt    <= '1';
        o_last  <= '0';
        o_user  <= '0';
      elsif link_up = '0' then
        hunt <= '1';
        if h_valid = '1' then
          o_valid <= '1';
          o_data  <= h_data;
          o_keep  <= h_keep;
          o_last  <= '1';
          o_user  <= '1';
        end if;
        h_valid <= '0';
      else
        -----------------------------------------------------------------------
        -- classify the incoming slot
        -----------------------------------------------------------------------
        run := true;
        for i in 0 to NB-1 loop
          b  := in_word(66*i+65 downto 66*i);
          pl := b(65 downto 2);
          v_nb := unsigned(pl(11 downto 8));
          nbv(4*i+3 downto 4*i) := v_nb;
          eofv(i) := b(1 downto 0) = C_SYNC_CTRL
                 and pl(7 downto 0) = C_BT_EOF
                 and pl(15 downto 12) = (not pl(11 downto 8))
                 and v_nb >= 1 and v_nb <= 8;
          run     := run and (b(1 downto 0) = C_SYNC_DATA);
          lead(i) := run;
        end loop;

        n_data := (others => '0');
        n_keep := (others => '0');
        n_err  := false;
        for i in 0 to NB-1 loop
          if lead(i) then
            n_data(64*i+63 downto 64*i) := in_word(66*i+65 downto 66*i+2);
            if i = NB-1 then
              n_keep(8*i+7 downto 8*i) := (others => '1');
            elsif lead(i+1) then
              n_keep(8*i+7 downto 8*i) := (others => '1');
            elsif eofv(i+1) then
              n_keep(8*i+7 downto 8*i) := f_thermo8(nbv(4*(i+1)+3 downto 4*(i+1)));
            else
              n_keep(8*i+7 downto 8*i) := (others => '1');
              n_err := true;
            end if;
          end if;
        end loop;
        n_any  := lead(0);
        n_full := lead(NB-1);
        n_eof0 := (not lead(0)) and eofv(0);

        -----------------------------------------------------------------------
        -- emit phase: at most one beat per clock
        -----------------------------------------------------------------------
        hv := h_valid;
        if h_valid = '1' and h_known = '1' then
          o_valid <= '1';
          o_data  <= h_data;
          o_keep  <= h_keep;
          o_last  <= h_last;
          o_user  <= h_err;
          hv := '0';
        elsif h_valid = '1' and in_valid = '1' then
          if n_any then
            -- more data: the held beat was not the last one
            o_valid <= '1';
            o_data  <= h_data;
            o_keep  <= h_keep;
            o_last  <= '0';
            o_user  <= '0';
            hv := '0';
          elsif n_eof0 then
            -- EOF in block 0: the held full beat was the last one
            k := h_keep;
            k(NB*8-1 downto NB*8-8) := f_thermo8(nbv(3 downto 0));
            o_valid <= '1';
            o_data  <= h_data;
            o_keep  <= k;
            o_last  <= '1';
            o_user  <= '0';
            hv := '0';
          end if;
          -- all-idle slot: keep waiting
        end if;

        -----------------------------------------------------------------------
        -- load phase
        -----------------------------------------------------------------------
        if in_valid = '1' then
          if hunt = '1' then
            if not n_full then
              hunt <= '0';
            end if;
          elsif n_any then
            hv := '1';
            h_data <= n_data;
            h_keep <= n_keep;
            if n_full then
              h_known <= '0';
              h_last  <= '0';
              h_err   <= '0';
            else
              h_known <= '1';
              h_last  <= '1';
              if n_err then
                h_err <= '1';
              else
                h_err <= '0';
              end if;
            end if;
          end if;
        end if;
        h_valid <= hv;
      end if;
    end if;
  end process;

  m_tdata  <= o_data;
  m_tkeep  <= o_keep;
  m_tlast  <= o_last;
  m_tuser  <= o_user;
  m_tvalid <= o_valid;

end architecture rtl;
