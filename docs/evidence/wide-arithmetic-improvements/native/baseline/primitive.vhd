library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity livt_math_arithmetic_widearithmeticprimitive is
 port(ctor_lvt_context_in: in t_icontext_in;
      ctor_request: in std_logic;
      ctor_operation: in signed(31 downto 0);
      ctor_a, ctor_b: in std_logic_vector(63 downto 0);
      ctor_outputbits: in signed(31 downto 0);
      ctor_acknowledge: out std_logic;
      ctor_result: out std_logic_vector(63 downto 0);
      ctor_failed: out boolean);
end;
architecture rtl of livt_math_arithmetic_widearithmeticprimitive is
 type phase_t is (idle, dividing, rounding, rooting);
 signal phase: phase_t := idle;
 signal pending: std_logic := '0';
 signal negative, round_even: boolean := false;
 signal dividend, divisor, quotient, radicand: unsigned(63 downto 0);
 signal remainder: unsigned(64 downto 0);
 signal root: unsigned(31 downto 0);
 signal index: integer range 0 to 63 := 0;
begin
 process(ctor_lvt_context_in.clk)
  variable product: signed(127 downto 0);
  variable addition: signed(64 downto 0);
  variable rem_next: unsigned(64 downto 0);
  variable q_next: unsigned(63 downto 0);
  variable candidate: unsigned(31 downto 0);
  variable limit, clipped: signed(63 downto 0);
  variable bits: integer;
 begin
  if rising_edge(ctor_lvt_context_in.clk) then
   if ctor_lvt_context_in.rst='1' then
    phase<=idle; pending<='0'; ctor_acknowledge<='0';
    ctor_result<=(others=>'0'); ctor_failed<=false;
    dividend<=(others=>'0'); divisor<=(others=>'0'); quotient<=(others=>'0');
    remainder<=(others=>'0'); root<=(others=>'0'); radicand<=(others=>'0');
    negative<=false; round_even<=false; index<=0;
   elsif phase=dividing then
    rem_next:=shift_left(remainder,1); rem_next(0):=dividend(index);
    q_next:=quotient;
    if rem_next>=resize(divisor,65) then
     rem_next:=rem_next-resize(divisor,65); q_next(index):='1';
    end if;
    remainder<=rem_next; quotient<=q_next;
    if index=0 then phase<=rounding; else index<=index-1; end if;
   elsif phase=rounding then
    q_next:=quotient;
    if round_even and (remainder>resize(divisor,65)-remainder or
       (remainder=resize(divisor,65)-remainder and quotient(0)='1')) then
     q_next:=q_next+1;
    end if;
    if negative then ctor_result<=std_logic_vector(-signed(q_next));
    else ctor_result<=std_logic_vector(q_next); end if;
    ctor_acknowledge<=pending; phase<=idle;
   elsif phase=rooting then
    candidate:=root; candidate(index):='1';
    if candidate*candidate<=radicand then root<=candidate;
    else candidate:=root; end if;
    if index=0 then
     ctor_result<=std_logic_vector(resize(candidate,64));
     ctor_acknowledge<=pending; phase<=idle;
    else index<=index-1; end if;
   elsif ctor_request/=ctor_acknowledge then
    pending<=ctor_request; ctor_failed<=false;
    case to_integer(ctor_operation) is
     when 0 =>
      product:=signed(ctor_a)*signed(ctor_b);
      if product/=resize(resize(product,64),128) then
       ctor_failed<=true; ctor_result<=(others=>'0');
      else ctor_result<=std_logic_vector(product(63 downto 0)); end if;
      ctor_acknowledge<=ctor_request;
     when 1 =>
      addition:=resize(signed(ctor_a),65)+resize(signed(ctor_b),65);
      if addition/=resize(resize(addition,64),65) then
       ctor_failed<=true; ctor_result<=(others=>'0');
      else ctor_result<=std_logic_vector(addition(63 downto 0)); end if;
      ctor_acknowledge<=ctor_request;
     when 2 | 5 =>
      if signed(ctor_b)<=0 or (ctor_operation=5 and signed(ctor_a)<0) then
       ctor_failed<=true; ctor_result<=(others=>'0'); ctor_acknowledge<=ctor_request;
      else
       negative<=signed(ctor_a)<0;
       if signed(ctor_a)<0 then dividend<=unsigned(-signed(ctor_a));
       else dividend<=unsigned(ctor_a); end if;
       divisor<=unsigned(ctor_b); quotient<=(others=>'0'); remainder<=(others=>'0');
       round_even<=ctor_operation=2; index<=63; phase<=dividing;
      end if;
     when 3 =>
      radicand<=unsigned(ctor_a); root<=(others=>'0'); index<=31; phase<=rooting;
     when 4 =>
      bits:=to_integer(ctor_outputbits);
      if bits<2 or bits>31 then
       ctor_failed<=true; ctor_result<=(others=>'0');
      else
       limit:=shift_left(to_signed(1,64),bits-1)-1;
       clipped:=signed(ctor_a);
       if clipped>limit then clipped:=limit;
       elsif clipped< -limit then clipped:= -limit; end if;
       ctor_result<=std_logic_vector(clipped);
      end if;
      ctor_acknowledge<=ctor_request;
     when others =>
      ctor_failed<=true; ctor_result<=(others=>'0'); ctor_acknowledge<=ctor_request;
    end case;
   end if;
  end if;
 end process;
end;
