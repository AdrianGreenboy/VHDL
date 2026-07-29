-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 2 testbench
-- tb_codec: validates pqc_codec_pkg against reference vectors derived from
-- the ACVP-validated Phase 0 oracles.
--
-- Every codec is checked in both directions: pack must reproduce the
-- reference bytes, and unpack of those bytes must return the original
-- coefficients. The hint codec additionally runs five directed negative
-- cases that a verifier must reject.
--
-- VHDL-2008. ASCII-only asserts. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.pqc_codec_pkg.all;

entity tb_codec is
  generic (
    G_VFILE : string := "codec_vectors.txt");
end entity tb_codec;

architecture sim of tb_codec is

  function to_hex (v : unsigned(63 downto 0)) return string is
    constant D : string(1 to 16) := "0123456789abcdef";
    variable r : string(1 to 16);
  begin
    for i in 0 to 15 loop
      r(16 - i) := D(to_integer(v(4 * i + 3 downto 4 * i)) + 1);
    end loop;
    return r;
  end function to_hex;

  function hex_nib (c : character) return integer is
  begin
    case c is
      when '0' => return 0;   when '1' => return 1;   when '2' => return 2;
      when '3' => return 3;   when '4' => return 4;   when '5' => return 5;
      when '6' => return 6;   when '7' => return 7;   when '8' => return 8;
      when '9' => return 9;
      when 'a' | 'A' => return 10;   when 'b' | 'B' => return 11;
      when 'c' | 'C' => return 12;   when 'd' | 'D' => return 13;
      when 'e' | 'E' => return 14;   when others => return 15;
    end case;
  end function hex_nib;

begin

  main : process
    file fp         : text;
    variable ln     : line;
    variable status : file_open_status;
    variable sig    : unsigned(63 downto 0) := x"CBF29CE484222325";
    variable tag    : string(1 to 3);
    variable c      : character;
    variable d, a, b, bits, nb, expn : integer;
    variable p, p2  : t_poly;
    variable by, exb : t_bytes;
    variable hin, hout : t_hints;
    variable hb     : t_hbuf;
    variable okv    : boolean;
    variable nenc, nsbp, nbpk, nhpk, nhuv : integer := 0;
    variable ch1, ch2 : character;
    variable v      : integer;

    procedure sig_update (variable s : inout unsigned(63 downto 0);
                          x : in integer) is
      variable u : unsigned(63 downto 0);
      variable w : unsigned(31 downto 0);
    begin
      if x < 0 then
        w := to_unsigned(x + 2147483647 + 1, 32);
      else
        w := to_unsigned(x, 32);
      end if;
      for i in 0 to 3 loop
        u := s xor resize(w(8 * i + 7 downto 8 * i), 64);
        u := u + shift_left(u, 1) + shift_left(u, 4) + shift_left(u, 5) +
             shift_left(u, 7) + shift_left(u, 8) + shift_left(u, 40);
        s := u;
      end loop;
    end procedure sig_update;

    -- read `n` hex byte pairs from the current line
    procedure read_bytes (variable l : inout line;
                          n : in integer;
                          variable dst : out t_bytes) is
      variable x1, x2 : character;
    begin
      dst := (others => 0);
      for i in 0 to n - 1 loop
        read(l, x1);
        read(l, x2);
        dst(i) := hex_nib(x1) * 16 + hex_nib(x2);
      end loop;
    end procedure read_bytes;

  begin
    file_open(status, fp, G_VFILE, read_mode);
    assert status = open_ok
      report "TB FAIL cannot open codec vector file" severity failure;

    while not endfile(fp) loop
      readline(fp, ln);
      if ln'length = 0 then
        next;
      end if;
      if ln(ln'low) = '#' then
        next;
      end if;

      read(ln, tag(1));
      read(ln, tag(2));
      read(ln, tag(3));

      if tag = "ENC" or tag = "SBP" then
        read(ln, d);                      -- width in bits
        for i in 0 to 255 loop
          read(ln, p(i));
        end loop;
        read(ln, c);                      -- space
        read_bytes(ln, 32 * d, exb);

        bit_pack(p, d, by, nb);
        assert nb = 32 * d
          report "TB FAIL pack length width=" & integer'image(d)
          severity failure;
        for i in 0 to nb - 1 loop
          assert by(i) = exb(i)
            report "TB FAIL pack width=" & integer'image(d) &
                   " byte " & integer'image(i) &
                   " got=" & integer'image(by(i)) &
                   " exp=" & integer'image(exb(i))
            severity failure;
          sig_update(sig, by(i));
        end loop;

        bit_unpack(exb, d, p2);
        for i in 0 to 255 loop
          assert p2(i) = p(i)
            report "TB FAIL unpack width=" & integer'image(d) &
                   " coef " & integer'image(i)
            severity failure;
        end loop;

        if tag = "ENC" then
          nenc := nenc + 1;
        else
          nsbp := nsbp + 1;
        end if;

      elsif tag = "BPK" then
        read(ln, a);
        read(ln, b);
        for i in 0 to 255 loop
          read(ln, p(i));
        end loop;
        read(ln, c);
        bits := 0;
        v    := a + b;
        while v > 0 loop
          bits := bits + 1;
          v    := v / 2;
        end loop;
        read_bytes(ln, 32 * bits, exb);

        bit_pack_signed(p, a, b, C_QD, bits, by, nb);
        for i in 0 to nb - 1 loop
          assert by(i) = exb(i)
            report "TB FAIL bitpack a=" & integer'image(a) &
                   " byte " & integer'image(i) &
                   " got=" & integer'image(by(i)) &
                   " exp=" & integer'image(exb(i))
            severity failure;
          sig_update(sig, by(i));
        end loop;

        bit_unpack_signed(exb, a, b, C_QD, bits, p2);
        for i in 0 to 255 loop
          assert p2(i) = p(i)
            report "TB FAIL bitunpack a=" & integer'image(a) &
                   " coef " & integer'image(i) &
                   " got=" & integer'image(p2(i)) &
                   " exp=" & integer'image(p(i))
            severity failure;
        end loop;
        nbpk := nbpk + 1;

      elsif tag = "HPK" then
        for i in 0 to 6 * 256 - 1 loop
          read(ln, hin(i));
        end loop;
        read(ln, c);
        read_bytes(ln, C_OMEGA + C_KK, exb);

        hint_pack(hin, hb);
        for i in 0 to C_OMEGA + C_KK - 1 loop
          assert hb(i) = exb(i)
            report "TB FAIL hint_pack byte " & integer'image(i) &
                   " got=" & integer'image(hb(i)) &
                   " exp=" & integer'image(exb(i))
            severity failure;
          sig_update(sig, hb(i));
        end loop;

        for i in 0 to C_OMEGA + C_KK - 1 loop
          hb(i) := exb(i);
        end loop;
        hint_unpack(hb, hout, okv);
        assert okv
          report "TB FAIL hint_unpack rejected a valid encoding"
          severity failure;
        for i in 0 to 6 * 256 - 1 loop
          assert hout(i) = hin(i)
            report "TB FAIL hint_unpack flag " & integer'image(i)
            severity failure;
        end loop;
        nhpk := nhpk + 1;

      elsif tag = "HUV" then
        read(ln, c);                      -- separator space
        read_bytes(ln, C_OMEGA + C_KK, exb);
        read(ln, expn);
        for i in 0 to C_OMEGA + C_KK - 1 loop
          hb(i) := exb(i);
        end loop;
        hint_unpack(hb, hout, okv);
        if expn = 1 then
          assert okv
            report "TB FAIL hint_unpack rejected a valid encoding"
            severity failure;
          sig_update(sig, 1);
        else
          assert not okv
            report "TB FAIL hint_unpack accepted a malformed encoding"
            severity failure;
          sig_update(sig, 0);
        end if;
        nhuv := nhuv + 1;
      end if;
    end loop;
    file_close(fp);

    report "PQC L2 CODEC PASS enc=" & integer'image(nenc) &
           " sbp=" & integer'image(nsbp) &
           " bpk=" & integer'image(nbpk) &
           " hpk=" & integer'image(nhpk) &
           " huv=" & integer'image(nhuv) &
           " sig=" & to_hex(sig)
      severity note;

    wait;
  end process main;

end architecture sim;
