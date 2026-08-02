library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_l2 is
end entity;

architecture sim of tb_l2 is
  constant GOLDEN : unsigned(31 downto 0) := x"ADBF2613";
  constant FNV_PRIME : unsigned(31 downto 0) := x"01000193";

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal byte_in : std_logic_vector(7 downto 0) := (others=>'0');
  signal byte_valid : std_logic := '0';
  signal pl_byte : std_logic_vector(7 downto 0);
  signal pl_valid, pl_commit, pl_drop : std_logic;
  signal sop, is_long, hdr_2bit : std_logic;
  signal vc_out : std_logic_vector(1 downto 0);
  signal dt_out : std_logic_vector(5 downto 0);

  -- We stage payload bytes of the CURRENT packet, and only fold them into the
  -- committed FNV when pl_commit fires (CRC good). On pl_drop, discard.
  signal fnv : unsigned(31 downto 0) := x"811C9DC5";

  function fnv_step(h : unsigned(31 downto 0); b : unsigned(7 downto 0))
    return unsigned is
    variable x : unsigned(31 downto 0);
    variable m : unsigned(63 downto 0);
  begin
    x := h xor resize(b,32);
    m := x * FNV_PRIME;
    return m(31 downto 0);
  end function;
begin
  clk <= not clk after 5 ns;

  dut : entity work.csi2_packet_rx
    port map (clk=>clk, rst=>rst, byte_in=>byte_in, byte_valid=>byte_valid,
              pl_byte=>pl_byte, pl_valid=>pl_valid, pl_commit=>pl_commit,
              pl_drop=>pl_drop, sop=>sop, is_long=>is_long,
              vc_out=>vc_out, dt_out=>dt_out, hdr_2bit=>hdr_2bit);

  -- staging FIFO of the current packet's payload
  process(clk)
    type buf_t is array(0 to 2047) of std_logic_vector(7 downto 0);
    variable buf : buf_t;
    variable cnt : integer := 0;
    variable h : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '0' then
        if pl_valid = '1' then
          buf(cnt) := pl_byte;
          cnt := cnt + 1;
        end if;
        if pl_commit = '1' then
          h := fnv;
          for i in 0 to cnt-1 loop
            h := fnv_step(h, unsigned(buf(i)));
          end loop;
          fnv <= h;
          cnt := 0;
        elsif pl_drop = '1' then
          cnt := 0;   -- discard
        end if;
      end if;
    end if;
  end process;

  -- feeder: presents one byte per cycle but PAUSES during the FSM's internal
  -- no-read cycles. Simpler: hold byte_valid high continuously and let the FSM
  -- consume when it reads. The FSM only reads in states that check byte_valid;
  -- states S_DECODE/S_CHECK do not consume. To avoid losing bytes, we advance
  -- the stream only when we know a read happened. We model this by driving
  -- byte_valid=1 always and advancing the index on the states that read.
  -- To keep the TB self-contained we instead feed with explicit handshake:
  -- present a byte, wait one cycle, and rely on the fact that non-reading
  -- states re-present the same byte (byte_valid stays 1, byte_in unchanged)
  -- until consumed. We detect consumption by tracking the FSM through sop and
  -- payload strobes is complex; simplest robust approach: drive byte_valid
  -- high, and gate advancement on a 'consumed' signal exported... but the DUT
  -- doesn't export ready. So we pace conservatively: 1 byte every cycle works
  -- IF the FSM reads every cycle. It doesn't (S_DECODE, S_CHECK skip). So we
  -- feed with byte_valid always 1 and KEEP byte_in stable, advancing only when
  -- the FSM was in a reading state last cycle. We reconstruct reading states
  -- by mirroring the FSM: too fragile. Final approach below uses a ready model.
  stim : process
    file fh : text;
    variable ln : line;
    variable bv : std_logic_vector(7 downto 0);
    variable ok : file_open_status;
  begin
    rst <= '1'; byte_valid <= '0';
    wait for 40 ns; wait until rising_edge(clk);
    rst <= '0'; wait until rising_edge(clk);

    file_open(ok, fh, "l2_stream.hex", read_mode);
    assert ok = open_ok report "no l2_stream.hex" severity failure;

    while not endfile(fh) loop
      readline(fh, ln);
      hread(ln, bv);
      byte_in <= bv;
      byte_valid <= '1';
      wait until rising_edge(clk);
      -- bubble to let non-reading FSM states advance without dropping a byte
      byte_valid <= '0';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end loop;
    byte_valid <= '0';
    for i in 0 to 9 loop wait until rising_edge(clk); end loop;

    report "L2 FNV = 0x" & to_hstring(fnv);
    if fnv = GOLDEN then
      report "L2 PASS - matches oracle golden 0x"&to_hstring(GOLDEN) severity note;
    else
      report "L2 FAIL - got 0x"&to_hstring(fnv)&" exp 0x"&to_hstring(GOLDEN)
        severity failure;
    end if;
    wait;
  end process;
end architecture;
