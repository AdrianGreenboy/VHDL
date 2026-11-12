-------------------------------------------------------------------------------
-- SERDES_256G - TX framer and slot scheduler (tx_clk domain)
--
-- Maps one AXI4-Stream beat (G_LANES*128 bits = 2*G_LANES blocks of 64 bits)
-- 1:1 onto one "slot" (one 132-bit word on every lane). There is no barrel
-- shifter: a frame always starts in block 0 of a slot.
--
--   beat block i  = s_tdata(64*i+63 downto 64*i), keep s_tkeep(8*i+7 downto 8*i)
--   lane L        = blocks 2L (first on the wire) and 2L+1
--
-- Frame delimiting:
--   * non-last beat  : 2*G_LANES data blocks
--   * last beat      : data blocks, then ONE EOF control block that carries
--                      the number of valid bytes of the last data block,
--                      then IDLE blocks
--   * last beat full : the EOF block goes into block 0 of the next slot
--                      (s_tready is low for that slot)
--   * no beat        : IDLE blocks (also legal in the middle of a frame)
--
-- Slot schedule (drives s_tready):
--   * gearbox pause  : 1 clock in 33 has no slot (132 -> 128 bit gearbox)
--   * alignment slot : one slot in G_AM_PERIOD is the alignment marker
--
-- Requirements on the AXI4-Stream source: s_tkeep is all ones on non-last
-- beats and contiguous from byte 0, with at least one byte, on the last beat.
--
-- MIT License.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.serdes256g_pkg.all;

entity serdes256g_tx_frame is
  generic (
    G_LANES     : positive := 8;
    G_AM_PERIOD : positive := 16384      -- slots between alignment markers
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    s_tdata  : in  std_logic_vector(G_LANES*128-1 downto 0);
    s_tkeep  : in  std_logic_vector(G_LANES*16-1 downto 0);
    s_tlast  : in  std_logic;
    s_tvalid : in  std_logic;
    s_tready : out std_logic;
    -- to the lanes: lane L = o_word(132*L+131 downto 132*L)
    o_word   : out std_logic_vector(G_LANES*132-1 downto 0);
    o_valid  : out std_logic;            -- a slot is present this clock
    o_am     : out std_logic             -- the slot is the alignment marker
  );
end entity serdes256g_tx_frame;

architecture rtl of serdes256g_tx_frame is
  constant NB : natural := 2*G_LANES;

  signal gb_cnt   : unsigned(5 downto 0) := (others => '0');   -- 0..32
  signal am_cnt   : integer range 0 to G_AM_PERIOD-1 := 0;
  signal eof_pend : std_logic := '0';
  signal pend_nb  : unsigned(3 downto 0) := (others => '0');
  signal slot_en  : std_logic;
  signal am_slot  : std_logic;
  signal ready_i  : std_logic;
  signal word_r   : std_logic_vector(G_LANES*132-1 downto 0) := (others => '0');
  signal valid_r  : std_logic := '0';
  signal am_r     : std_logic := '0';
begin

  slot_en <= '0' when gb_cnt = 32 else '1';
  am_slot <= slot_en when am_cnt = 0 else '0';
  ready_i <= slot_en and (not am_slot) and (not eof_pend) and (not rst);
  s_tready <= ready_i;

  process(clk)
    variable v_word : std_logic_vector(G_LANES*132-1 downto 0);
    variable k      : std_logic_vector(7 downto 0);
    variable kprev  : std_logic_vector(7 downto 0);
    variable d      : std_logic_vector(63 downto 0);
    variable has    : boolean;
    variable hprev  : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        gb_cnt   <= (others => '0');
        am_cnt   <= 0;
        eof_pend <= '0';
        pend_nb  <= (others => '0');
        word_r   <= (others => '0');
        valid_r  <= '0';
        am_r     <= '0';
      else
        if gb_cnt = 32 then
          gb_cnt <= (others => '0');
        else
          gb_cnt <= gb_cnt + 1;
        end if;

        valid_r <= slot_en;
        am_r    <= am_slot;

        if slot_en = '1' then
          if am_cnt = G_AM_PERIOD-1 then
            am_cnt <= 0;
          else
            am_cnt <= am_cnt + 1;
          end if;
        end if;

        if slot_en = '1' and am_slot = '0' then
          for i in 0 to NB-1 loop
            v_word(66*i+65 downto 66*i) := f_idle_block;
          end loop;

          if eof_pend = '1' then
            v_word(65 downto 0) := f_eof_block(pend_nb);
            eof_pend <= '0';
          elsif s_tvalid = '1' then
            hprev := false;
            kprev := (others => '0');
            for i in 0 to NB-1 loop
              k := s_tkeep(8*i+7 downto 8*i);
              d := s_tdata(64*i+63 downto 64*i);
              has := (s_tlast = '0') or (k(0) = '1') or (i = 0);
              if has then
                if s_tlast = '1' then
                  for j in 0 to 7 loop
                    if k(j) = '0' then
                      d(8*j+7 downto 8*j) := (others => '0');
                    end if;
                  end loop;
                end if;
                v_word(66*i+65 downto 66*i) := d & C_SYNC_DATA;
              elsif hprev then
                v_word(66*i+65 downto 66*i) := f_eof_block(f_nbytes(kprev));
              end if;
              hprev := has;
              kprev := k;
            end loop;
            -- last beat completely full: EOF goes into the next slot
            if s_tlast = '1' and hprev then
              eof_pend <= '1';
              pend_nb  <= f_nbytes(kprev);
            end if;
          end if;

          word_r <= v_word;
        end if;
      end if;
    end if;
  end process;

  o_word  <= word_r;
  o_valid <= valid_r;
  o_am    <= am_r;

end architecture rtl;
