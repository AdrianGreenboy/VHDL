-- AUTO-GENERADO por gen_tb_datapath.py desde pcs_datapath_oracle.py
-- Firma golden esperada: 0xB02ACF27
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pcs_datapath is end entity;

architecture sim of tb_pcs_datapath is
  constant NSTREAM : natural := 96;
  constant NWRD : natural := 99;
  constant GOLDEN : unsigned(31 downto 0) := x"B02ACF27";
  constant FNV_OFFSET : unsigned(31 downto 0) := x"811C9DC5";
  constant FNV_PRIME  : unsigned(31 downto 0) := x"01000193";

  type pl_arr is array(0 to NSTREAM-1) of std_logic_vector(63 downto 0);
  type bt_arr is array(0 to NSTREAM-1) of std_logic;
  type wd_arr is array(0 to NWRD-1) of std_logic_vector(63 downto 0);

  constant PAYLOADS : pl_arr := (
    0 => x"0000000000000000",
    1 => x"3C78B4F12D69A5E2",
    2 => x"78F169E25AD34BC4",
    3 => x"F1E2D3C4B5A69789",
    4 => x"E3C5A7896B4D2F13",
    5 => x"FFFFFFFFFFFFFFFF",
    6 => x"8F169E25AD34BC4C",
    7 => x"1E2D3C4B5A697898",
    8 => x"3C5A7896B4D2F130",
    9 => x"78B4F12D69A5E260",
    10 => x"F169E25AD34BC4C1",
    11 => x"0000000000000000",
    12 => x"C5A7896B4D2F1306",
    13 => x"8B4F12D69A5E260C",
    14 => x"169E25AD34BC4C18",
    15 => x"2D3C4B5A69789831",
    16 => x"FFFFFFFFFFFFFFFF",
    17 => x"B4F12D69A5E260C7",
    18 => x"69E25AD34BC4C18E",
    19 => x"D3C4B5A69789831C",
    20 => x"A7896B4D2F130639",
    21 => x"4F12D69A5E260C73",
    22 => x"0000000000000000",
    23 => x"3C4B5A69789831CD",
    24 => x"7896B4D2F130639A",
    25 => x"F12D69A5E260C735",
    26 => x"E25AD34BC4C18E6B",
    27 => x"FFFFFFFFFFFFFFFF",
    28 => x"896B4D2F130639AC",
    29 => x"12D69A5E260C7358",
    30 => x"25AD34BC4C18E6B1",
    31 => x"4B5A69789831CD62",
    32 => x"96B4D2F130639AC4",
    33 => x"0000000000000000",
    34 => x"5AD34BC4C18E6B11",
    35 => x"B5A69789831CD623",
    36 => x"6B4D2F130639AC46",
    37 => x"D69A5E260C73588C",
    38 => x"FFFFFFFFFFFFFFFF",
    39 => x"5A69789831CD6232",
    40 => x"B4D2F130639AC465",
    41 => x"69A5E260C73588CA",
    42 => x"D34BC4C18E6B1194",
    43 => x"A69789831CD62329",
    44 => x"0000000000000000",
    45 => x"9A5E260C73588CA6",
    46 => x"34BC4C18E6B1194D",
    47 => x"69789831CD62329B",
    48 => x"D2F130639AC46536",
    49 => x"FFFFFFFFFFFFFFFF",
    50 => x"4BC4C18E6B1194DB",
    51 => x"9789831CD62329B6",
    52 => x"2F130639AC46536C",
    53 => x"5E260C73588CA6D9",
    54 => x"BC4C18E6B1194DB3",
    55 => x"0000000000000000",
    56 => x"F130639AC46536CF",
    57 => x"E260C73588CA6D9F",
    58 => x"C4C18E6B1194DB3E",
    59 => x"89831CD62329B67C",
    60 => x"FFFFFFFFFFFFFFFF",
    61 => x"260C73588CA6D9F1",
    62 => x"4C18E6B1194DB3E2",
    63 => x"9831CD62329B67C4",
    64 => x"30639AC46536CF89",
    65 => x"60C73588CA6D9F13",
    66 => x"0000000000000000",
    67 => x"831CD62329B67C4E",
    68 => x"0639AC46536CF89D",
    69 => x"0C73588CA6D9F13A",
    70 => x"18E6B1194DB3E275",
    71 => x"FFFFFFFFFFFFFFFF",
    72 => x"639AC46536CF89D5",
    73 => x"C73588CA6D9F13AB",
    74 => x"8E6B1194DB3E2756",
    75 => x"1CD62329B67C4EAC",
    76 => x"39AC46536CF89D58",
    77 => x"0000000000000000",
    78 => x"E6B1194DB3E27560",
    79 => x"CD62329B67C4EAC0",
    80 => x"9AC46536CF89D581",
    81 => x"3588CA6D9F13AB03",
    82 => x"FFFFFFFFFFFFFFFF",
    83 => x"D62329B67C4EAC0E",
    84 => x"AC46536CF89D581D",
    85 => x"588CA6D9F13AB03A",
    86 => x"B1194DB3E2756075",
    87 => x"62329B67C4EAC0EA",
    88 => x"0000000000000000",
    89 => x"88CA6D9F13AB03AA",
    90 => x"1194DB3E27560754",
    91 => x"2329B67C4EAC0EA9",
    92 => x"46536CF89D581D52",
    93 => x"FFFFFFFFFFFFFFFF",
    94 => x"194DB3E27560754A",
    95 => x"329B67C4EAC0EA94"
  );
  constant ISDATA : bt_arr := (
    0 => '1',
    1 => '1',
    2 => '1',
    3 => '1',
    4 => '0',
    5 => '1',
    6 => '1',
    7 => '1',
    8 => '1',
    9 => '0',
    10 => '1',
    11 => '1',
    12 => '1',
    13 => '1',
    14 => '0',
    15 => '1',
    16 => '1',
    17 => '1',
    18 => '1',
    19 => '0',
    20 => '1',
    21 => '1',
    22 => '1',
    23 => '1',
    24 => '0',
    25 => '1',
    26 => '1',
    27 => '1',
    28 => '1',
    29 => '0',
    30 => '1',
    31 => '1',
    32 => '1',
    33 => '1',
    34 => '0',
    35 => '1',
    36 => '1',
    37 => '1',
    38 => '1',
    39 => '0',
    40 => '1',
    41 => '1',
    42 => '1',
    43 => '1',
    44 => '0',
    45 => '1',
    46 => '1',
    47 => '1',
    48 => '1',
    49 => '0',
    50 => '1',
    51 => '1',
    52 => '1',
    53 => '1',
    54 => '0',
    55 => '1',
    56 => '1',
    57 => '1',
    58 => '1',
    59 => '0',
    60 => '1',
    61 => '1',
    62 => '1',
    63 => '1',
    64 => '0',
    65 => '1',
    66 => '1',
    67 => '1',
    68 => '1',
    69 => '0',
    70 => '1',
    71 => '1',
    72 => '1',
    73 => '1',
    74 => '0',
    75 => '1',
    76 => '1',
    77 => '1',
    78 => '1',
    79 => '0',
    80 => '1',
    81 => '1',
    82 => '1',
    83 => '1',
    84 => '0',
    85 => '1',
    86 => '1',
    87 => '1',
    88 => '1',
    89 => '0',
    90 => '1',
    91 => '1',
    92 => '1',
    93 => '1',
    94 => '0',
    95 => '1'
  );
  constant WORDS : wd_arr := (
    0 => x"0FFFFE0000000001",
    1 => x"F45BA0ED29665E24",
    2 => x"41B89D70D1054E9F",
    3 => x"785655E1DABD3C4C",
    4 => x"0F34980385BC5EEC",
    5 => x"8512D061AE943733",
    6 => x"3287F141105A9FDB",
    7 => x"00B04518667F69B0",
    8 => x"A488DD1B222D6C85",
    9 => x"D50A76C6859ACA30",
    10 => x"0EED28374CDA84AE",
    11 => x"773DFA9EAE5BE994",
    12 => x"C3A4FF0B8944F1CE",
    13 => x"2F365617374D54FD",
    14 => x"59838E392F6B2FFC",
    15 => x"E0AEB4616096270A",
    16 => x"9FC6C379FC6F19EB",
    17 => x"76BD5375F358B399",
    18 => x"BB973C5DCE8EE645",
    19 => x"F2F838B66FE0612B",
    20 => x"4CAFD149DE57CC5A",
    21 => x"75BA477CEFA0DBC5",
    22 => x"7DF89D7C3EB55181",
    23 => x"054850693FB1AD65",
    24 => x"FB5E05CF6DB2B031",
    25 => x"DA041EFB8B9B7119",
    26 => x"8394165422DA660A",
    27 => x"7769F49058F03E46",
    28 => x"25CF358D2999DCAA",
    29 => x"09F6E1FFF0BE9F7F",
    30 => x"195A9639F0A8D123",
    31 => x"659D4BDE3920C75F",
    32 => x"473D0F0E41347D65",
    33 => x"8F38B9BA5F833045",
    34 => x"8D505285D48B47B4",
    35 => x"C7BA3D029E777BA4",
    36 => x"7F44C5DC414B5177",
    37 => x"8443A4BBAB2E15D2",
    38 => x"C40E118408735425",
    39 => x"AE5B416FA35BD22F",
    40 => x"F0B39C872E85A70C",
    41 => x"09D5AA4204450F8E",
    42 => x"EB544BEF07B6E2B1",
    43 => x"A5D133AC3DDD83F6",
    44 => x"BCF86452485ADCD0",
    45 => x"61E9473CD6B51360",
    46 => x"E0B5A67A77F8CF5D",
    47 => x"850049F59A8953AA",
    48 => x"13CBE50E5BA37CE9",
    49 => x"8A7CBAADB53028C8",
    50 => x"E270E548CECA9468",
    51 => x"49AC715BCB61F724",
    52 => x"BA258D739BBECB7E",
    53 => x"8EC145FDA2FE1756",
    54 => x"FB788564F694FC81",
    55 => x"55BC210993ECB3AD",
    56 => x"BFB372A94105745B",
    57 => x"4ACD2CF54DF505C7",
    58 => x"36055FABBCEDAB53",
    59 => x"3ED686EDCA29016A",
    60 => x"E99D02122B6B2EB4",
    61 => x"61F3D6C94E91BF0B",
    62 => x"47CB8BA28CBB7692",
    63 => x"5413882837169FEF",
    64 => x"6B6DB506E2325568",
    65 => x"2BA0BD6487D24F56",
    66 => x"5D5D8E909DDCD3DE",
    67 => x"D5281ADF14191D35",
    68 => x"37457007A1742FD8",
    69 => x"AA23AA47468B036F",
    70 => x"63377EBD80DE492E",
    71 => x"6224494029E33BFA",
    72 => x"229C4F3CB291DC2C",
    73 => x"F9E97F490C485FA2",
    74 => x"98FF4B39656D7A83",
    75 => x"AE63CE735275A571",
    76 => x"8AF1BE32272290A6",
    77 => x"304CDCB86D60AADD",
    78 => x"47B65FDE7DC480B8",
    79 => x"BE573F728635162D",
    80 => x"7ECDA3D391BCE826",
    81 => x"8CEA140091666112",
    82 => x"4A40A65DB97E54A8",
    83 => x"6F237CC630D55EE3",
    84 => x"E62364D7EA3F9756",
    85 => x"7C1C855F90EE695E",
    86 => x"397E2EFDD465EFC8",
    87 => x"F0B925127B1C16B6",
    88 => x"2BE3D661B14E7A8E",
    89 => x"9BEC48B5B994DC57",
    90 => x"1679FCF436EFE25C",
    91 => x"95EACBC47E971648",
    92 => x"53DEB4D06B8FC329",
    93 => x"5D4F3C5234588964",
    94 => x"A997A25DC17380F0",
    95 => x"34C1CBC31126E3F8",
    96 => x"6A38125A4D7A17E2",
    97 => x"4A74B6E949AB08B6",
    98 => x"99F86ABE9737888C"
  );

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  -- TX datapath
  signal tx_in_valid, tx_in_ready, tx_out_valid, tx_in_isdata : std_logic := '0';
  signal tx_in_payload : std_logic_vector(63 downto 0) := (others=>'0');
  signal tx_out_word : std_logic_vector(63 downto 0);
  -- RX datapath
  signal rx_in_valid, rx_in_ready, rx_out_valid, rx_out_isdata : std_logic;
  signal rx_in_word : std_logic_vector(63 downto 0);
  signal rx_out_payload : std_logic_vector(63 downto 0);

  signal sig : unsigned(31 downto 0) := FNV_OFFSET;
  signal err_cap, err_rt, err_fin : natural := 0;
  signal words_seen, recs_seen : natural := 0;

  function fnv_v(h : unsigned(31 downto 0); b : integer) return unsigned is
    variable hv : unsigned(31 downto 0); variable pr : unsigned(63 downto 0);
  begin
    hv := h xor to_unsigned(b mod 256, 32); pr := hv * FNV_PRIME;
    return pr(31 downto 0);
  end function;

begin
  clk <= not clk after 1.28 ns;

  dut_tx: entity work.pcs_tx_datapath
    port map (clk=>clk, rst=>rst, in_valid=>tx_in_valid, in_payload=>tx_in_payload,
              in_is_data=>tx_in_isdata, in_ready=>tx_in_ready,
              out_valid=>tx_out_valid, out_word=>tx_out_word);

  dut_rx: entity work.pcs_rx_datapath
    port map (clk=>clk, rst=>rst, in_valid=>rx_in_valid, in_word=>rx_in_word,
              in_ready=>rx_in_ready, out_valid=>rx_out_valid,
              out_payload=>rx_out_payload, out_is_data=>rx_out_isdata);

  -- conexion directa TX->RX
  rx_in_word  <= tx_out_word;
  rx_in_valid <= tx_out_valid;

  feed: process
    variable si : natural := 0;
  begin
    tx_in_valid <= '0';
    wait until rst = '0';
    wait until rising_edge(clk);
    while si < NSTREAM loop
      tx_in_payload <= PAYLOADS(si);
      tx_in_isdata  <= ISDATA(si);
      tx_in_valid   <= '1';
      wait until rising_edge(clk);
      if tx_in_ready = '1' then si := si + 1; end if;
    end loop;
    tx_in_valid <= '0';
    wait;
  end process;

  capture: process
    variable wi : natural := 0;
    variable hv : unsigned(31 downto 0) := FNV_OFFSET;
    variable closed : boolean := false;
    variable bval : integer;
  begin
    wait until rst = '0';
    loop
      wait until rising_edge(clk);
      if tx_out_valid = '1' then
        if wi < NWRD then
          assert tx_out_word = WORDS(wi)
            report "DP word " & integer'image(wi) & " mismatch" severity error;
          if tx_out_word /= WORDS(wi) then err_cap <= err_cap + 1; end if;
          for k in 0 to 7 loop
            bval := to_integer(unsigned(tx_out_word((k*8+7) downto (k*8))));
            hv := fnv_v(hv, bval);
          end loop;
        end if;
        wi := wi + 1;
        words_seen <= wi;
      end if;
      if wi >= NWRD and not closed then
        hv := fnv_v(hv, NWRD);
        hv := fnv_v(hv, 1);
        sig <= hv;
        closed := true;
      end if;
    end loop;
  end process;

  rtcheck: process
    variable ri : natural := 0;
    variable exp_d : std_logic;
  begin
    wait until rst = '0';
    loop
      wait until rising_edge(clk);
      if rx_out_valid = '1' then
        if ri < NSTREAM then
          assert rx_out_payload = PAYLOADS(ri)
            report "DP RT payload " & integer'image(ri) & " mismatch" severity error;
          if rx_out_payload /= PAYLOADS(ri) then err_rt <= err_rt + 1; end if;
          exp_d := ISDATA(ri);
          assert rx_out_isdata = exp_d
            report "DP RT isdata " & integer'image(ri) & " mismatch" severity error;
          if rx_out_isdata /= exp_d then err_rt <= err_rt + 1; end if;
        end if;
        ri := ri + 1;
        recs_seen <= ri;
      end if;
    end loop;
  end process;

  final: process
  begin
    rst <= '1'; wait for 10 ns; wait until rising_edge(clk); rst <= '0';
    wait for 600 ns;
    wait for 1 ns;
    report "words_seen=" & integer'image(words_seen) & " recs_seen=" & integer'image(recs_seen);
    assert words_seen = NWRD report "conteo palabras incorrecto" severity error;
    if words_seen /= NWRD then err_fin <= err_fin + 1; end if;
    assert recs_seen = NSTREAM report "conteo recuperados incorrecto" severity error;
    if recs_seen /= NSTREAM then err_fin <= err_fin + 1; end if;
    if sig = GOLDEN and (err_cap + err_rt + err_fin) = 0 then
      report "LAYER3DP_PASS FNV32=0x" & to_hstring(sig) severity note;
    else
      report "LAYER3DP_FAIL FNV32=0x" & to_hstring(sig) & " errors=" & integer'image(err_cap+err_rt+err_fin) severity error;
    end if;
    wait;
  end process;
end architecture;
