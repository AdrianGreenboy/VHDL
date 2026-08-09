library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ecc_pkg.all;
entity tb_codec_mmio is end entity;
architecture sim of tb_codec_mmio is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal sel, wr : std_logic := '0';
  signal addr : std_logic_vector(7 downto 0) := (others=>'0');
  signal wdata, rdata : std_logic_vector(31 downto 0) := (others=>'0');
  function hexv(c:character) return integer is begin
    case c is when '0'=>return 0; when '1'=>return 1; when '2'=>return 2; when '3'=>return 3;
    when '4'=>return 4; when '5'=>return 5; when '6'=>return 6; when '7'=>return 7;
    when '8'=>return 8; when '9'=>return 9; when 'A'|'a'=>return 10; when 'B'|'b'=>return 11;
    when 'C'|'c'=>return 12; when 'D'|'d'=>return 13; when 'E'|'e'=>return 14; when 'F'|'f'=>return 15;
    when others=>return -1; end case; end function;
  procedure rdhex(variable L: inout line; nbits: natural; variable val: out unsigned) is
    variable c:character; variable ok:boolean; variable acc:unsigned(63 downto 0):=(others=>'0'); variable nib:integer;
  begin
    loop read(L,c,ok); exit when not ok; exit when c/=' '; end loop;
    loop nib:=hexv(c); exit when nib<0; acc:=resize(acc(59 downto 0)&to_unsigned(nib,4),64);
      read(L,c,ok); exit when not ok; exit when c=' '; end loop;
    val:=acc;
  end procedure;
begin
  clk <= not clk after 5 ns;
  dut : entity work.ecc_codec_mmio
    port map (clk=>clk, rst=>rst, sel=>sel, wr=>wr, addr=>addr, wdata=>wdata, rdata=>rdata);
  process
    file vf: text; variable L: line; variable st: file_open_status;
    variable op: character; variable ok: boolean;
    variable u_data,u_in,u_mask,u_ed,u_es,u_ec,u_edb: unsigned(63 downto 0);
    variable errors, cnt: natural := 0;
    variable inword, expdata: unsigned(63 downto 0);
    procedure wreg(o:integer; v:std_logic_vector(31 downto 0)) is begin
      wait until rising_edge(clk); addr<=std_logic_vector(to_unsigned(o,8)); wdata<=v; sel<='1'; wr<='1';
      wait until rising_edge(clk); sel<='0'; wr<='0'; end procedure;
    procedure rreg(o:integer; val:out std_logic_vector(31 downto 0)) is begin
      wait until rising_edge(clk); addr<=std_logic_vector(to_unsigned(o,8)); sel<='1'; wr<='0';
      wait for 1 ns; val:=rdata; sel<='0'; end procedure;
    variable rv: std_logic_vector(31 downto 0);
  begin
    rst<='1'; wait for 23 ns; rst<='0'; wait for 10 ns;
    file_open(st, vf, "layer1_vectors.txt", read_mode);
    assert st=open_ok report "no abre layer1_vectors.txt" severity failure;
    while not endfile(vf) loop
      readline(vf,L);
      if L'length=0 then next; end if;
      if L(L'left)='#' then next; end if;
      read(L,op,ok); next when not ok;
      rdhex(L,32,u_data); rdhex(L,39,u_in); rdhex(L,39,u_mask);
      rdhex(L,39,u_ed); rdhex(L,8,u_es); rdhex(L,4,u_ec); rdhex(L,4,u_edb);
      if op='E' then
        wreg(16#04#, std_logic_vector(u_data(31 downto 0)));  -- ENC_IN
        rreg(16#08#, rv);  -- ENC_OUT_LO
        if rv /= std_logic_vector(u_ed(31 downto 0)) then errors:=errors+1;
          if errors<=6 then report "ENC LO mismatch caso "&integer'image(cnt) severity warning; end if; end if;
        rreg(16#0C#, rv);  -- ENC_OUT_HI
        if rv(6 downto 0) /= std_logic_vector(u_ed(38 downto 32)) then errors:=errors+1;
          if errors<=6 then report "ENC HI mismatch caso "&integer'image(cnt) severity warning; end if; end if;
      else  -- D: decode(inword xor mask)
        inword := u_in xor u_mask;
        wreg(16#10#, std_logic_vector(inword(31 downto 0)));  -- DEC_IN_LO
        wreg(16#14#, std_logic_vector(resize(inword(38 downto 32),32)));  -- DEC_IN_HI
        rreg(16#18#, rv);  -- DEC_DATA
        if rv /= std_logic_vector(u_ed(31 downto 0)) then errors:=errors+1;
          if errors<=6 then report "DEC DATA mismatch caso "&integer'image(cnt) severity warning; end if; end if;
        rreg(16#1C#, rv);  -- DEC_STATUS
        if (unsigned(rv(6 downto 0)) /= u_es(6 downto 0)) or (rv(9) /= u_ec(0)) or (rv(8) /= u_edb(0)) then
          errors:=errors+1;
          if errors<=6 then report "DEC STATUS mismatch caso "&integer'image(cnt) severity warning; end if; end if;
      end if;
      cnt := cnt + 1;
    end loop;
    file_close(vf);
    report "casos: "&integer'image(cnt)&"  discrepancias: "&integer'image(errors);
    if errors=0 then report "CODEC_MMIO PASS - acelerador espejo del oraculo";
    else report "CODEC_MMIO FAIL" severity failure; end if;
    wait;
  end process;
end architecture;
