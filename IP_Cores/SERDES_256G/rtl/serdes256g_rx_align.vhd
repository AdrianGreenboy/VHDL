-------------------------------------------------------------------------------
-- SERDES_256G - RX lane deskew, lane reorder, BIP-8 check and descrambler
-- (rx_clk domain; read side of the per-lane deskew FIFOs)
--
-- Deskew FSM
--   FLUSH : every FIFO is drained. All lanes marker-locked -> ALIGN.
--   ALIGN : each lane is popped until an alignment marker sits at its FIFO
--           head, then it is held. All lanes holding -> RUN. If a lane holds
--           for 2**(G_FIFO_AW-1) clocks while another lane has not reached
--           its marker (that lane's marker had already been flushed), go
--           through FLUSH and retry on the next marker.
--   RUN   : all lanes are popped together, only when none is empty. The
--           markers must show up on all lanes in the same pop; if not the
--           deskew is lost -> FLUSH.
--
-- rx_clk does not need to be a recovered clock: lane words arrive in 32 of
-- every 33 line clocks, so any clock within +/-1 % of the lane word rate
-- (the local TX user clock, for instance) empties the FIFOs fast enough.
--
-- Pipeline after the FIFOs
--   s1 : FIFO heads registered
--   s2 : per PHYSICAL lane: marker parse (lane id, BIP-8, status), BIP-8
--        accumulation, sync-header check, descrambler x^58 + x^39 + 1
--   s2b: marker check on registered fields: error pulses, lane permutation
--        check, lane map update (one clock after s2; still ahead of the
--        first data word reaching s3)
--   s3 : lane reorder, physical -> logical (the lane id comes from AM_A)
--
-- The descrambler history is wrong for the first 58 bits after alignment;
-- serdes256g_rx_frame discards everything up to the first frame boundary.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.serdes256g_pkg.all;

entity serdes256g_rx_align is
  generic (
    G_LANES   : positive := 8;
    G_FIFO_AW : positive := 6
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    lane_up    : in  std_logic_vector(G_LANES-1 downto 0);   -- am_lock, synced
    -- deskew FIFOs, read side (lane L at 133*L)
    f_dout     : in  std_logic_vector(G_LANES*133-1 downto 0);
    f_empty    : in  std_logic_vector(G_LANES-1 downto 0);
    f_rd       : out std_logic_vector(G_LANES-1 downto 0);
    -- aligned, descrambled, logically ordered lane words
    o_word     : out std_logic_vector(G_LANES*132-1 downto 0);
    o_valid    : out std_logic;
    aligned    : out std_logic;
    -- status
    lane_map   : out std_logic_vector(G_LANES*4-1 downto 0);  -- logical id of physical lane
    rem_status : out std_logic_vector(7 downto 0);            -- AM_B status byte
    bip_err    : out std_logic_vector(G_LANES-1 downto 0);    -- pulses, physical lane
    am_err     : out std_logic_vector(G_LANES-1 downto 0);
    hdr_err    : out std_logic_vector(G_LANES-1 downto 0);
    map_err    : out std_logic                                -- pulse
  );
end entity serdes256g_rx_align;

architecture rtl of serdes256g_rx_align is
  constant C_TMO : natural := 2**(G_FIFO_AW-1);

  type t_st is (ST_FLUSH, ST_ALIGN, ST_RUN);
  signal st  : t_st := ST_FLUSH;
  signal tmo : integer range 0 to C_TMO := 0;

  type t_w132  is array (0 to G_LANES-1) of std_logic_vector(131 downto 0);
  type t_u58   is array (0 to G_LANES-1) of unsigned(57 downto 0);
  type t_slv8  is array (0 to G_LANES-1) of std_logic_vector(7 downto 0);
  type t_u4    is array (0 to G_LANES-1) of unsigned(3 downto 0);

  signal ne, ham  : std_logic_vector(G_LANES-1 downto 0);
  signal all_up, all_ne, all_am, any_am, all_hold, any_hold : std_logic;
  signal rd_i     : std_logic_vector(G_LANES-1 downto 0);

  signal s1_word  : t_w132 := (others => (others => '0'));
  signal s1_valid : std_logic := '0';
  signal s1_am    : std_logic := '0';

  signal dstate   : t_u58 := (others => (others => '0'));
  signal acc      : t_slv8 := (others => (others => '0'));
  signal acc_ok   : std_logic := '0';
  signal id       : t_u4 := (others => (others => '0'));
  signal map_ok   : std_logic := '0';
  signal map_bad  : std_logic := '0';
  -- marker parse pipeline register (s2 -> s2b)
  signal p_valid  : std_logic := '0';
  signal p_ok     : std_logic_vector(G_LANES-1 downto 0) := (others => '0');
  signal p_bipbad : std_logic_vector(G_LANES-1 downto 0) := (others => '0');
  signal p_id     : t_u4 := (others => (others => '0'));
  signal p_status : std_logic_vector(7 downto 0) := (others => '0');
  signal s2_word  : t_w132 := (others => (others => '0'));
  signal s2_valid : std_logic := '0';

  signal o_word_r  : std_logic_vector(G_LANES*132-1 downto 0) := (others => '0');
  signal o_valid_r : std_logic := '0';
  signal status_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal bip_err_r, am_err_r, hdr_err_r : std_logic_vector(G_LANES-1 downto 0)
                                        := (others => '0');
  signal map_err_r : std_logic := '0';
begin

  -----------------------------------------------------------------------------
  -- FIFO head decode and read enables (combinational)
  -----------------------------------------------------------------------------
  process(all)
    variable v_up, v_ne, v_all_am, v_any_am, v_all_hold, v_any_hold : std_logic;
  begin
    v_up := '1'; v_ne := '1'; v_all_am := '1'; v_any_am := '0';
    v_all_hold := '1'; v_any_hold := '0';
    for l in 0 to G_LANES-1 loop
      ne(l)  <= not f_empty(l);
      ham(l) <= f_dout(133*l+132);
      v_up       := v_up and lane_up(l);
      v_ne       := v_ne and (not f_empty(l));
      v_all_am   := v_all_am and f_dout(133*l+132);
      v_any_am   := v_any_am or f_dout(133*l+132);
      v_all_hold := v_all_hold and ((not f_empty(l)) and f_dout(133*l+132));
      v_any_hold := v_any_hold or ((not f_empty(l)) and f_dout(133*l+132));
    end loop;
    all_up   <= v_up;
    all_ne   <= v_ne;
    all_am   <= v_all_am;
    any_am   <= v_any_am;
    all_hold <= v_all_hold;
    any_hold <= v_any_hold;
  end process;

  process(all)
  begin
    for l in 0 to G_LANES-1 loop
      case st is
        when ST_FLUSH => rd_i(l) <= ne(l);
        when ST_ALIGN => rd_i(l) <= ne(l) and (not ham(l));
        when ST_RUN   => rd_i(l) <= all_ne;
      end case;
    end loop;
  end process;
  f_rd <= rd_i;

  -----------------------------------------------------------------------------
  -- deskew FSM + pipeline
  -----------------------------------------------------------------------------
  process(clk)
    variable w        : std_logic_vector(131 downto 0);
    variable b0, b1   : std_logic_vector(65 downto 0);
    variable pin, po  : std_logic_vector(127 downto 0);
    variable s        : unsigned(57 downto 0);
    variable v_allok  : boolean;
    variable v_perm   : boolean;
    variable seen     : std_logic_vector(15 downto 0);
    variable n        : natural;
    variable acc_v    : std_logic_vector(131 downto 0);
  begin
    if rising_edge(clk) then
      bip_err_r <= (others => '0');
      am_err_r  <= (others => '0');
      hdr_err_r <= (others => '0');
      map_err_r <= '0';
      map_bad   <= '0';
      s1_valid  <= '0';
      s2_valid  <= '0';
      p_valid   <= '0';

      if rst = '1' then
        st        <= ST_FLUSH;
        tmo       <= 0;
        s1_am     <= '0';
        acc_ok    <= '0';
        map_ok    <= '0';
        o_valid_r <= '0';
        status_r  <= (others => '0');
      else
        -----------------------------------------------------------------------
        -- FSM
        -----------------------------------------------------------------------
        case st is
          when ST_FLUSH =>
            tmo    <= 0;
            map_ok <= '0';
            acc_ok <= '0';
            if all_up = '1' then
              st <= ST_ALIGN;
            end if;

          when ST_ALIGN =>
            if all_up = '0' then
              st <= ST_FLUSH;
            elsif all_hold = '1' then
              st <= ST_RUN;
            elsif any_hold = '1' then
              if tmo = C_TMO then
                st <= ST_FLUSH;
              else
                tmo <= tmo + 1;
              end if;
            else
              tmo <= 0;
            end if;

          when ST_RUN =>
            if all_up = '0' or map_bad = '1' then
              st <= ST_FLUSH;
            elsif all_ne = '1' then
              if any_am = '1' and all_am = '0' then
                st <= ST_FLUSH;                     -- deskew lost
              else
                s1_valid <= '1';
                s1_am    <= all_am;
                for l in 0 to G_LANES-1 loop
                  s1_word(l) <= f_dout(133*l+131 downto 133*l);
                end loop;
              end if;
            end if;
        end case;

        -----------------------------------------------------------------------
        -- s2: marker parse / BIP / descrambler, per physical lane
        -----------------------------------------------------------------------
        if st /= ST_RUN then
          null;                                     -- pipeline drains, discarded
        elsif s1_valid = '1' then
          if s1_am = '1' then
            -- marker parse, first half: per-lane match and field capture only
            -- (the permutation check is done one clock later, see s2b)
            p_valid <= '1';
            for l in 0 to G_LANES-1 loop
              b0 := s1_word(l)(65 downto 0);
              b1 := s1_word(l)(131 downto 66);
              if f_is_am_a(b0) and f_is_am_b(b1) then
                p_ok(l) <= '1';
              else
                p_ok(l) <= '0';
              end if;
              p_id(l) <= unsigned(b0(21 downto 18));         -- payload(19:16)
              -- BIP-8: payload byte 3 = block bits 33 downto 26
              if acc_ok = '1' and b0(33 downto 26) /= acc(l) then
                p_bipbad(l) <= '1';
              else
                p_bipbad(l) <= '0';
              end if;
              acc(l) <= (others => '0');
            end loop;
            p_status <= s1_word(0)(99 downto 92);            -- AM_B payload byte 3
            acc_ok   <= '1';
          else
            s2_valid <= '1';
            for l in 0 to G_LANES-1 loop
              w := s1_word(l);
              acc_v := w;
              acc(l) <= acc(l) xor f_bip8(acc_v);
              if w(0) = w(1) or w(66) = w(67) then
                hdr_err_r(l) <= '1';
              end if;
              pin := w(131 downto 68) & w(65 downto 2);
              s   := dstate(l);
              for i in 0 to 127 loop
                po(i) := pin(i) xor s(38) xor s(57);
                s     := s(56 downto 0) & pin(i);
              end loop;
              dstate(l)  <= s;
              s2_word(l) <= po(127 downto 64) & w(67 downto 66)
                          & po(63 downto 0)   & w(1 downto 0);
            end loop;
          end if;
        end if;

        -----------------------------------------------------------------------
        -- s2b: marker check, second half (registered inputs): BIP / marker
        -- error pulses, lane permutation check, lane map update
        -----------------------------------------------------------------------
        if st = ST_RUN and p_valid = '1' then
          v_allok := true;
          v_perm  := true;
          seen    := (others => '0');
          for l in 0 to G_LANES-1 loop
            if p_ok(l) = '1' then
              if p_bipbad(l) = '1' then
                bip_err_r(l) <= '1';
              end if;
              n := to_integer(p_id(l));
              if n >= G_LANES or seen(n) = '1' then
                v_perm := false;
              end if;
              seen(n) := '1';
            else
              v_allok := false;
              am_err_r(l) <= '1';
            end if;
          end loop;
          if v_allok then
            if v_perm then
              id       <= p_id;
              map_ok   <= '1';
              status_r <= p_status;
            else
              map_bad   <= '1';
              map_err_r <= '1';
              map_ok    <= '0';
            end if;
          end if;
        end if;

        -----------------------------------------------------------------------
        -- s3: lane reorder (physical p carries logical lane id(p))
        -----------------------------------------------------------------------
        if st = ST_RUN and map_ok = '1' and map_bad = '0' then
          o_valid_r <= s2_valid;
        else
          o_valid_r <= '0';
        end if;
        for lg in 0 to G_LANES-1 loop
          w := (others => '0');
          for ph in 0 to G_LANES-1 loop
            if to_integer(id(ph)) = lg then
              w := w or s2_word(ph);
            end if;
          end loop;
          o_word_r(132*lg+131 downto 132*lg) <= w;
        end loop;
      end if;
    end if;
  end process;

  o_word     <= o_word_r;
  o_valid    <= o_valid_r;
  aligned    <= '1' when (st = ST_RUN and map_ok = '1') else '0';
  rem_status <= status_r;
  bip_err    <= bip_err_r;
  am_err     <= am_err_r;
  hdr_err    <= hdr_err_r;
  map_err    <= map_err_r;

  process(all)
  begin
    for l in 0 to G_LANES-1 loop
      lane_map(4*l+3 downto 4*l) <= std_logic_vector(id(l));
    end loop;
  end process;

end architecture rtl;
