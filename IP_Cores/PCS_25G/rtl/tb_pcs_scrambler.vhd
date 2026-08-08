-- AUTO-GENERADO por gen_tb_scrambler.py desde pcs_scrambler_oracle.py
-- NO EDITAR A MANO. Firma golden esperada: 0x37DB2E32
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_scrambler is end entity;

architecture sim of tb_pcs_scrambler is
  constant GOLDEN : unsigned(31 downto 0) := x"37DB2E32";
  constant FNV_OFFSET : unsigned(31 downto 0) := x"811C9DC5";
  constant FNV_PRIME  : unsigned(31 downto 0) := x"01000193";

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  -- TX scrambler
  signal tx_en, tx_valid : std_logic := '0';
  signal tx_din, tx_dout : std_logic_vector(63 downto 0) := (others=>'0');
  -- RX descrambler
  signal rx_en, rx_valid : std_logic := '0';
  signal rx_din, rx_dout : std_logic_vector(63 downto 0) := (others=>'0');

  signal sig : unsigned(31 downto 0) := FNV_OFFSET;
  signal errors : natural := 0;

  procedure fnv_byte(signal h : inout unsigned(31 downto 0); b : integer) is
    variable hv : unsigned(31 downto 0); variable pr : unsigned(63 downto 0);
  begin hv := h xor to_unsigned(b mod 256,32); pr := hv*FNV_PRIME; h <= pr(31 downto 0); end procedure;

begin
  clk <= not clk after 1.28 ns;

  tx: entity work.pcs_scrambler
    port map (clk=>clk, rst=>rst, en=>tx_en, mode=>'0',
              din=>tx_din, dout=>tx_dout, dvalid=>tx_valid);

  rx: entity work.pcs_scrambler
    port map (clk=>clk, rst=>rst, en=>rx_en, mode=>'1',
              din=>rx_din, dout=>rx_dout, dvalid=>rx_valid);

  stim: process
    variable sc : std_logic_vector(63 downto 0);
    variable rc : std_logic_vector(63 downto 0);

    procedure acc_u64(v : std_logic_vector(63 downto 0)) is
    begin
      for k in 0 to 7 loop
        fnv_byte(sig, to_integer(unsigned(v((k*8+7) downto (k*8))))); wait for 0 ns;
      end loop;
    end procedure;
    procedure acc_byte(b : integer) is begin fnv_byte(sig,b); wait for 0 ns; end procedure;

    -- procesa un bloque por el scrambler TX y devuelve el resultado
    procedure tx_block(payload : std_logic_vector(63 downto 0);
                       result : out std_logic_vector(63 downto 0)) is
    begin
      wait until rising_edge(clk);
      tx_din <= payload; tx_en <= '1';
      wait until rising_edge(clk);
      tx_en <= '0';
      wait until rising_edge(clk) and tx_valid = '1';
      result := tx_dout;
    end procedure;

    -- procesa un bloque por el descrambler RX
    procedure rx_block(scrambled : std_logic_vector(63 downto 0);
                       result : out std_logic_vector(63 downto 0)) is
    begin
      wait until rising_edge(clk);
      rx_din <= scrambled; rx_en <= '1';
      wait until rising_edge(clk);
      rx_en <= '0';
      wait until rising_edge(clk) and rx_valid = '1';
      result := rx_dout;
    end procedure;

  begin
    rst <= '1'; wait for 10 ns; wait until rising_edge(clk); rst <= '0';
    wait until rising_edge(clk);

    -- blk 0 sync=01
    tx_block(x"0000000000000000", sc);
    assert sc = x"03FFFF8000000000" report "SCR blk 0 mismatch" severity error;
    if sc /= x"03FFFF8000000000" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    acc_byte(1); acc_u64(sc);
    -- blk 1 sync=01
    tx_block(x"FFFFFFFFFFFFFFFF", sc);
    assert sc = x"03EFFF8000003FFF" report "SCR blk 1 mismatch" severity error;
    if sc /= x"03EFFF8000003FFF" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"FFFFFFFFFFFFFFFF" report "RT blk 1 mismatch" severity error;
    if rc /= x"FFFFFFFFFFFFFFFF" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 2 sync=01
    tx_block(x"AAAAAAAAAAAAAAAA", sc);
    assert sc = x"54103FD55D556A55" report "SCR blk 2 mismatch" severity error;
    if sc /= x"54103FD55D556A55" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"AAAAAAAAAAAAAAAA" report "RT blk 2 mismatch" severity error;
    if rc /= x"AAAAAAAAAAAAAAAA" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 3 sync=01
    tx_block(x"5555555555555555", sc);
    assert sc = x"03F03C80083FEA52" report "SCR blk 3 mismatch" severity error;
    if sc /= x"03F03C80083FEA52" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"5555555555555555" report "RT blk 3 mismatch" severity error;
    if rc /= x"5555555555555555" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 4 sync=01
    tx_block(x"0123456789ABCDEF", sc);
    assert sc = x"C395A49471957242" report "SCR blk 4 mismatch" severity error;
    if sc /= x"C395A49471957242" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"0123456789ABCDEF" report "RT blk 4 mismatch" severity error;
    if rc /= x"0123456789ABCDEF" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 5 sync=01
    tx_block(x"FEDCBA9876543210", sc);
    assert sc = x"D9C41CEBED402DE1" report "SCR blk 5 mismatch" severity error;
    if sc /= x"D9C41CEBED402DE1" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"FEDCBA9876543210" report "RT blk 5 mismatch" severity error;
    if rc /= x"FEDCBA9876543210" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 6 sync=01
    tx_block(x"DEADBEEFCAFEBABE", sc);
    assert sc = x"832D51708745CFFF" report "SCR blk 6 mismatch" severity error;
    if sc /= x"832D51708745CFFF" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"DEADBEEFCAFEBABE" report "RT blk 6 mismatch" severity error;
    if rc /= x"DEADBEEFCAFEBABE" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 7 sync=01
    tx_block(x"8000000000000000", sc);
    assert sc = x"28DB0B0454B5AF7C" report "SCR blk 7 mismatch" severity error;
    if sc /= x"28DB0B0454B5AF7C" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"8000000000000000" report "RT blk 7 mismatch" severity error;
    if rc /= x"8000000000000000" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 8 sync=01
    tx_block(x"0000000000000001", sc);
    assert sc = x"330927387CD75496" report "SCR blk 8 mismatch" severity error;
    if sc /= x"330927387CD75496" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"0000000000000001" report "RT blk 8 mismatch" severity error;
    if rc /= x"0000000000000001" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 9 sync=10
    tx_block(x"C0FFEE00C0FFEE00", sc);
    assert sc = x"BFA47C85A59F2F6C" report "SCR blk 9 mismatch" severity error;
    if sc /= x"BFA47C85A59F2F6C" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"C0FFEE00C0FFEE00" report "RT blk 9 mismatch" severity error;
    if rc /= x"C0FFEE00C0FFEE00" then errors <= errors + 1; end if;
    acc_byte(2); acc_u64(sc);
    -- blk 10 sync=01
    tx_block(x"2468ACF121579BDF", sc);
    assert sc = x"1944E55CE5FFA5B0" report "SCR blk 10 mismatch" severity error;
    if sc /= x"1944E55CE5FFA5B0" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"2468ACF121579BDF" report "RT blk 10 mismatch" severity error;
    if rc /= x"2468ACF121579BDF" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 11 sync=01
    tx_block(x"48D159E242AF37BF", sc);
    assert sc = x"8187E7FB934A675B" report "SCR blk 11 mismatch" severity error;
    if sc /= x"8187E7FB934A675B" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"48D159E242AF37BF" report "RT blk 11 mismatch" severity error;
    if rc /= x"48D159E242AF37BF" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 12 sync=01
    tx_block(x"91A2B3C4855E6F7F", sc);
    assert sc = x"4FF9399BA8E0BB2B" report "SCR blk 12 mismatch" severity error;
    if sc /= x"4FF9399BA8E0BB2B" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"91A2B3C4855E6F7F" report "RT blk 12 mismatch" severity error;
    if rc /= x"91A2B3C4855E6F7F" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 13 sync=01
    tx_block(x"234567890ABCDEFE", sc);
    assert sc = x"7BB26048988391C6" report "SCR blk 13 mismatch" severity error;
    if sc /= x"7BB26048988391C6" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"234567890ABCDEFE" report "RT blk 13 mismatch" severity error;
    if rc /= x"234567890ABCDEFE" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 14 sync=01
    tx_block(x"468ACF121579BDFC", sc);
    assert sc = x"8EAFFD2EEE2B97F7" report "SCR blk 14 mismatch" severity error;
    if sc /= x"8EAFFD2EEE2B97F7" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"468ACF121579BDFC" report "RT blk 14 mismatch" severity error;
    if rc /= x"468ACF121579BDFC" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 15 sync=01
    tx_block(x"8D159E242AF37BF9", sc);
    assert sc = x"918E4917C6B542D1" report "SCR blk 15 mismatch" severity error;
    if sc /= x"918E4917C6B542D1" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"8D159E242AF37BF9" report "RT blk 15 mismatch" severity error;
    if rc /= x"8D159E242AF37BF9" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 16 sync=01
    tx_block(x"1A2B3C4855E6F7F3", sc);
    assert sc = x"983988A4CDD8A91B" report "SCR blk 16 mismatch" severity error;
    if sc /= x"983988A4CDD8A91B" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"1A2B3C4855E6F7F3" report "RT blk 16 mismatch" severity error;
    if rc /= x"1A2B3C4855E6F7F3" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 17 sync=01
    tx_block(x"34567890ABCDEFE6", sc);
    assert sc = x"B9590CFE243EDF24" report "SCR blk 17 mismatch" severity error;
    if sc /= x"B9590CFE243EDF24" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"34567890ABCDEFE6" report "RT blk 17 mismatch" severity error;
    if rc /= x"34567890ABCDEFE6" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 18 sync=01
    tx_block(x"68ACF121579BDFCC", sc);
    assert sc = x"24E4444E038D5BA2" report "SCR blk 18 mismatch" severity error;
    if sc /= x"24E4444E038D5BA2" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"68ACF121579BDFCC" report "RT blk 18 mismatch" severity error;
    if rc /= x"68ACF121579BDFCC" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 19 sync=01
    tx_block(x"D159E242AF37BF99", sc);
    assert sc = x"841C8841E51BADF6" report "SCR blk 19 mismatch" severity error;
    if sc /= x"841C8841E51BADF6" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"D159E242AF37BF99" report "RT blk 19 mismatch" severity error;
    if rc /= x"D159E242AF37BF99" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 20 sync=01
    tx_block(x"A2B3C4855E6F7F32", sc);
    assert sc = x"A33B0D6657BF3177" report "SCR blk 20 mismatch" severity error;
    if sc /= x"A33B0D6657BF3177" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"A2B3C4855E6F7F32" report "RT blk 20 mismatch" severity error;
    if rc /= x"A2B3C4855E6F7F32" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 21 sync=01
    tx_block(x"4567890ABCDEFE65", sc);
    assert sc = x"68B3A0EEB806B18B" report "SCR blk 21 mismatch" severity error;
    if sc /= x"68B3A0EEB806B18B" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"4567890ABCDEFE65" report "RT blk 21 mismatch" severity error;
    if rc /= x"4567890ABCDEFE65" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 22 sync=01
    tx_block(x"8ACF121579BDFCCB", sc);
    assert sc = x"89A574229A8D9151" report "SCR blk 22 mismatch" severity error;
    if sc /= x"89A574229A8D9151" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"8ACF121579BDFCCB" report "RT blk 22 mismatch" severity error;
    if rc /= x"8ACF121579BDFCCB" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 23 sync=01
    tx_block(x"159E242AF37BF996", sc);
    assert sc = x"BA57FEBEABABDE9E" report "SCR blk 23 mismatch" severity error;
    if sc /= x"BA57FEBEABABDE9E" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"159E242AF37BF996" report "RT blk 23 mismatch" severity error;
    if rc /= x"159E242AF37BF996" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 24 sync=01
    tx_block(x"2B3C4855E6F7F32C", sc);
    assert sc = x"F6D4967237A60303" report "SCR blk 24 mismatch" severity error;
    if sc /= x"F6D4967237A60303" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"2B3C4855E6F7F32C" report "RT blk 24 mismatch" severity error;
    if rc /= x"2B3C4855E6F7F32C" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 25 sync=01
    tx_block(x"567890ABCDEFE659", sc);
    assert sc = x"D08065896F7A474E" report "SCR blk 25 mismatch" severity error;
    if sc /= x"D08065896F7A474E" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"567890ABCDEFE659" report "RT blk 25 mismatch" severity error;
    if rc /= x"567890ABCDEFE659" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 26 sync=01
    tx_block(x"ACF121579BDFCCB2", sc);
    assert sc = x"E7C3ACA9FE50E118" report "SCR blk 26 mismatch" severity error;
    if sc /= x"E7C3ACA9FE50E118" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"ACF121579BDFCCB2" report "RT blk 26 mismatch" severity error;
    if rc /= x"ACF121579BDFCCB2" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 27 sync=01
    tx_block(x"59E242AF37BF9965", sc);
    assert sc = x"EA3A436E71908E1E" report "SCR blk 27 mismatch" severity error;
    if sc /= x"EA3A436E71908E1E" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"59E242AF37BF9965" report "RT blk 27 mismatch" severity error;
    if rc /= x"59E242AF37BF9965" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 28 sync=01
    tx_block(x"B3C4855E6F7F32CA", sc);
    assert sc = x"540F8926CB98C7CA" report "SCR blk 28 mismatch" severity error;
    if sc /= x"540F8926CB98C7CA" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"B3C4855E6F7F32CA" report "RT blk 28 mismatch" severity error;
    if rc /= x"B3C4855E6F7F32CA" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);
    -- blk 29 sync=01
    tx_block(x"67890ABCDEFE6594", sc);
    assert sc = x"D493C3B2421495EE" report "SCR blk 29 mismatch" severity error;
    if sc /= x"D493C3B2421495EE" then errors <= errors + 1; end if;
    rx_block(sc, rc);
    assert rc = x"67890ABCDEFE6594" report "RT blk 29 mismatch" severity error;
    if rc /= x"67890ABCDEFE6594" then errors <= errors + 1; end if;
    acc_byte(1); acc_u64(sc);

    -- cierre: estado final del scrambler (constante de la traza) + round-trip flag
    acc_u64(x"03A928424DC3C92B");
    acc_byte(1);  -- round-trip OK (verificado por asserts arriba)

    wait for 1 ns;
    if sig = GOLDEN and errors = 0 then
      report "LAYER3PCS_PASS FNV32=0x" & to_hstring(sig) severity note;
    else
      report "LAYER3PCS_FAIL FNV32=0x" & to_hstring(sig) & " errors=" & integer'image(errors) severity error;
    end if;
    wait;
  end process;
end architecture;
