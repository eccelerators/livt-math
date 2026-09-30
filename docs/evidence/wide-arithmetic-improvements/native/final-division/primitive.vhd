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
      ctor_failed: out boolean;
      -- Constant capability bits: multiply/add/divide/root/clamp.
      ctor_operations: in signed(31 downto 0) := to_signed(31,32));
end;
architecture rtl of livt_math_arithmetic_widearithmeticprimitive is
 type phase_t is (idle, dividing, rounding, rooting, mul_products, mul_pairs, mul_join,
                  mul_low, mul_high, mul_finish);
 signal phase: phase_t := idle;
 signal pending: std_logic := '0';
 signal negative, round_even: boolean := false;
 signal dividend, divisor, quotient, radicand: unsigned(63 downto 0);
 signal remainder: unsigned(64 downto 0);
 signal root: unsigned(31 downto 0);
 signal index: integer range 0 to 63 := 0;
 -- Four 16x16 products are reused across four digits of the second operand.
 type products_t is array(0 to 3) of unsigned(31 downto 0);
 signal products: products_t;
 signal pair_low, pair_high: unsigned(47 downto 0);
 signal mul_a, mul_b: unsigned(63 downto 0);
 signal mul_sum, mul_term: unsigned(127 downto 0);
 signal mul_carry: unsigned(0 downto 0);
 signal mul_digit: integer range 0 to 3 := 0;
 signal root_remainder: unsigned(33 downto 0);
begin
 process(ctor_lvt_context_in.clk)
  variable low_sum: unsigned(64 downto 0);
  variable joined: unsigned(79 downto 0);
  variable root_next: unsigned(31 downto 0);
  variable root_trial, root_rem_next: unsigned(33 downto 0);
  variable addition: signed(64 downto 0);
  variable rem_next: unsigned(64 downto 0);
  variable q_next: unsigned(63 downto 0);
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
    products<=(others=>(others=>'0')); pair_low<=(others=>'0'); pair_high<=(others=>'0');
    mul_a<=(others=>'0'); mul_b<=(others=>'0'); mul_sum<=(others=>'0');
    mul_term<=(others=>'0'); mul_carry<=(others=>'0'); mul_digit<=0;
    root_remainder<=(others=>'0');
   elsif phase=dividing and ctor_operations(2)='1' then
    rem_next:=shift_left(remainder,1); rem_next(0):=dividend(index);
    q_next:=quotient;
    if rem_next>=resize(divisor,65) then
     rem_next:=rem_next-resize(divisor,65); q_next(index):='1';
    end if;
    remainder<=rem_next; quotient<=q_next;
    if index=0 then phase<=rounding; else index<=index-1; end if;
   elsif phase=rounding and ctor_operations(2)='1' then
    q_next:=quotient;
    if round_even and (remainder>resize(divisor,65)-remainder or
       (remainder=resize(divisor,65)-remainder and quotient(0)='1')) then
     q_next:=q_next+1;
    end if;
    if negative then ctor_result<=std_logic_vector(-signed(q_next));
    else ctor_result<=std_logic_vector(q_next); end if;
    ctor_acknowledge<=pending; phase<=idle;
   elsif phase=mul_products and ctor_operations(0)='1' then
    for digit in 0 to 3 loop
     products(digit)<=mul_a(digit*16+15 downto digit*16)*mul_b(15 downto 0);
    end loop;
    phase<=mul_pairs;
   elsif phase=mul_pairs and ctor_operations(0)='1' then
    pair_low<=resize(products(0),48)+shift_left(resize(products(1),48),16);
    pair_high<=resize(products(2),48)+shift_left(resize(products(3),48),16);
    phase<=mul_join;
   elsif phase=mul_join and ctor_operations(0)='1' then
    joined:=resize(pair_low,80)+shift_left(resize(pair_high,80),32);
    mul_term<=shift_left(resize(joined,128),mul_digit*16);
    phase<=mul_low;
   elsif phase=mul_low and ctor_operations(0)='1' then
    low_sum:=resize(mul_sum(63 downto 0),65)+resize(mul_term(63 downto 0),65);
    mul_sum(63 downto 0)<=low_sum(63 downto 0);
    mul_carry(0)<=low_sum(64); phase<=mul_high;
   elsif phase=mul_high and ctor_operations(0)='1' then
    mul_sum(127 downto 64)<=mul_sum(127 downto 64)+mul_term(127 downto 64)+resize(mul_carry,64);
    mul_b<=shift_right(mul_b,16);
    if mul_digit=3 then phase<=mul_finish;
    else mul_digit<=mul_digit+1; phase<=mul_products; end if;
   elsif phase=mul_finish and ctor_operations(0)='1' then
    -- Magnitudes are checked before restoring the sign, including MIN_INT64.
    if mul_sum(127 downto 64)/=0 or
       (not negative and mul_sum(63)='1') or
       (negative and mul_sum(63)='1' and mul_sum(62 downto 0)/=0) then
     ctor_failed<=true; ctor_result<=(others=>'0');
    elsif negative then ctor_result<=std_logic_vector(-signed(mul_sum(63 downto 0)));
    else ctor_result<=std_logic_vector(mul_sum(63 downto 0)); end if;
    ctor_acknowledge<=pending; phase<=idle;
   elsif phase=rooting and ctor_operations(3)='1' then
    -- Restoring root consumes two radicand bits per cycle; no multiplier.
    root_rem_next:=shift_left(root_remainder,2);
    root_rem_next(1 downto 0):=radicand(63 downto 62);
    root_trial:=shift_left(resize(root,34),2); root_trial(0):='1';
    root_next:=shift_left(root,1);
    if root_rem_next>=root_trial then
     root_rem_next:=root_rem_next-root_trial; root_next(0):='1';
    end if;
    root_remainder<=root_rem_next; root<=root_next;
    radicand<=shift_left(radicand,2);
    if index=0 then
     ctor_result<=std_logic_vector(resize(root_next,64));
     ctor_acknowledge<=pending; phase<=idle;
    else index<=index-1; end if;
   elsif ctor_request/=ctor_acknowledge then
    pending<=ctor_request; ctor_failed<=false;
    case to_integer(ctor_operation) is
     when 0 =>
      if ctor_operations(0)='0' then
       ctor_failed<=true; ctor_result<=(others=>'0'); ctor_acknowledge<=ctor_request;
      else
       negative<=(signed(ctor_a)<0) xor (signed(ctor_b)<0);
       if signed(ctor_a)<0 then mul_a<=unsigned(-signed(ctor_a));
       else mul_a<=unsigned(ctor_a); end if;
       if signed(ctor_b)<0 then mul_b<=unsigned(-signed(ctor_b));
       else mul_b<=unsigned(ctor_b); end if;
       mul_sum<=(others=>'0'); mul_digit<=0; phase<=mul_products;
      end if;
     when 1 =>
      addition:=resize(signed(ctor_a),65)+resize(signed(ctor_b),65);
      if ctor_operations(1)='0' or addition/=resize(resize(addition,64),65) then
       ctor_failed<=true; ctor_result<=(others=>'0');
      else ctor_result<=std_logic_vector(addition(63 downto 0)); end if;
      ctor_acknowledge<=ctor_request;
     when 2 | 5 =>
      if ctor_operations(2)='0' or signed(ctor_b)<=0 or (ctor_operation=5 and signed(ctor_a)<0) then
       ctor_failed<=true; ctor_result<=(others=>'0'); ctor_acknowledge<=ctor_request;
      else
       negative<=signed(ctor_a)<0;
       if signed(ctor_a)<0 then dividend<=unsigned(-signed(ctor_a));
       else dividend<=unsigned(ctor_a); end if;
       divisor<=unsigned(ctor_b); quotient<=(others=>'0'); remainder<=(others=>'0');
       round_even<=ctor_operation=2; index<=63; phase<=dividing;
      end if;
     when 3 =>
      if ctor_operations(3)='0' then
       ctor_failed<=true; ctor_result<=(others=>'0'); ctor_acknowledge<=ctor_request;
      else
       radicand<=unsigned(ctor_a); root<=(others=>'0'); root_remainder<=(others=>'0');
       index<=31; phase<=rooting;
      end if;
     when 4 =>
      bits:=to_integer(ctor_outputbits);
      if ctor_operations(4)='0' or bits<2 or bits>31 then
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
