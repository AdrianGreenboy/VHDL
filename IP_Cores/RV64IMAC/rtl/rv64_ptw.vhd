-- rv64_ptw.vhd - page table walker Sv39 (Svade: no actualiza A/D).
-- Atiende fallos de I-TLB y D-TLB (prioridad D), una caminata a la vez.
-- Lee PTEs por el puerto de datos del core (coherente con stores previos).
-- Resultado: relleno de la TLB del solicitante, o fallo (page/access) para su VPN.
-- 'kill' (flush del pipeline, sfence, cambio de satp) aborta la caminata; si hay
-- una lectura en vuelo, su respuesta se descarta.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv64_pkg.all;
use work.rv64_mmu_pkg.all;

entity rv64_ptw is
  port (
    clk, rst   : in  std_logic;
    kill       : in  std_logic;
    satp       : in  xword;
    -- solicitudes
    i_req      : in  std_logic;
    i_vpn      : in  std_logic_vector(26 downto 0);
    d_req      : in  std_logic;
    d_vpn      : in  std_logic_vector(26 downto 0);
    -- resultados (pulsos)
    i_fill, d_fill   : out std_logic;
    fill_e           : out tlbe_t;
    i_fault, d_fault : out std_logic;
    fault_vpn        : out std_logic_vector(26 downto 0);
    fault_access     : out std_logic;              -- 1: access fault, 0: page fault
    busy             : out std_logic;
    -- memoria (lecturas de 8 bytes alineadas)
    m_req_valid : out std_logic;
    m_req_ready : in  std_logic;
    m_req_addr  : out xword;
    m_rsp_valid : in  std_logic;
    m_rsp_data  : in  xword;
    m_rsp_err   : in  std_logic
  );
end entity;

architecture rtl of rv64_ptw is
  type st_t is (IDLE, REQ, WAIT_RSP, DRAIN);
  signal st     : st_t;
  signal side_d : std_logic;                         -- 1: caminata de D
  signal vpn    : std_logic_vector(26 downto 0);
  signal asid   : std_logic_vector(15 downto 0);
  signal lvl    : unsigned(1 downto 0);
  signal addr   : xword;
begin
  busy <= '0' when st = IDLE else '1';
  m_req_valid <= '1' when st = REQ and kill = '0' and pma_dram(addr) else '0';
  m_req_addr  <= addr;

  process (clk)
    variable pte  : xword;
    variable vv, r, w, x, a : std_logic;
    variable ppn  : std_logic_vector(43 downto 0);
    variable e    : tlbe_t;
    variable idx  : std_logic_vector(8 downto 0);
    variable fault, acc_f, leaf : boolean;
  begin
    if rising_edge(clk) then
      i_fill <= '0'; d_fill <= '0'; i_fault <= '0'; d_fault <= '0';
      if rst = '1' then
        st <= IDLE;
      else
        fault := false; acc_f := false; leaf := false;
        case st is
          when IDLE =>
            if kill = '0' and (d_req = '1' or i_req = '1') then
              if d_req = '1' then side_d <= '1'; vpn <= d_vpn; idx := d_vpn(26 downto 18);
              else side_d <= '0'; vpn <= i_vpn; idx := i_vpn(26 downto 18); end if;
              asid <= satp(59 downto 44);
              lvl  <= "10";
              addr <= x"00" & satp(43 downto 0) & idx & "000";
              st   <= REQ;
            end if;

          when REQ =>
            if kill = '1' then
              st <= IDLE;
            elsif not pma_dram(addr) then
              fault := true; acc_f := true;               -- PTE fuera de DRAM
            elsif m_req_ready = '1' then
              st <= WAIT_RSP;
            end if;

          when WAIT_RSP =>
            if kill = '1' then
              if m_rsp_valid = '1' then st <= IDLE; else st <= DRAIN; end if;
            elsif m_rsp_valid = '1' then
              pte := m_rsp_data;
              vv := pte(0); r := pte(1); w := pte(2); x := pte(3); a := pte(6);
              ppn := pte(53 downto 10);
              if m_rsp_err = '1' then
                fault := true; acc_f := true;
              elsif vv = '0' or (r = '0' and w = '1') or pte(63 downto 54) /= "0000000000" then
                fault := true;
              elsif r = '1' or x = '1' then
                leaf := true;
                -- megapagina desalineada o A=0 (Svade): fallo, no se cachea
                if (lvl = "10" and ppn(17 downto 0) /= (17 downto 0 => '0')) or
                   (lvl = "01" and ppn(8 downto 0) /= (8 downto 0 => '0')) or a = '0' then
                  fault := true;
                end if;
              elsif lvl = "00" then
                fault := true;
              else
                if lvl = "10" then idx := vpn(17 downto 9); else idx := vpn(8 downto 0); end if;
                lvl  <= lvl - 1;
                addr <= x"00" & ppn & idx & "000";
                st   <= REQ;
              end if;
              if leaf and not fault then
                e.v := '1'; e.vpn := vpn; e.asid := asid; e.g := pte(5);
                e.lvl := std_logic_vector(lvl); e.ppn := ppn;
                e.r := r; e.w := w; e.x := x; e.u := pte(4); e.d := pte(7);
                fill_e <= e;
                if side_d = '1' then d_fill <= '1'; else i_fill <= '1'; end if;
                st <= IDLE;
              end if;
            end if;

          when DRAIN =>
            if m_rsp_valid = '1' then st <= IDLE; end if;
        end case;
        if fault and kill = '0' then
          fault_vpn <= vpn;
          if acc_f then fault_access <= '1'; else fault_access <= '0'; end if;
          if side_d = '1' then d_fault <= '1'; else i_fault <= '1'; end if;
          st <= IDLE;
        elsif fault then
          st <= IDLE;
        end if;
      end if;
    end if;
  end process;
end architecture;
