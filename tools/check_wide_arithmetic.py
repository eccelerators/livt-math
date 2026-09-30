#!/usr/bin/env python3
from pathlib import Path
import random,math,subprocess,os
import argparse
parser=argparse.ArgumentParser(description="Exact wide-arithmetic oracle and phase-reset RTL checks")
parser.add_argument('--work',type=Path,required=True)
parser.add_argument('--generated-lib',type=Path,required=True)
parser.add_argument('--ghdl',default='ghdl')
args=parser.parse_args()
args.work.mkdir(parents=True,exist_ok=True)
r=random.Random(579); mask=(1<<64)-1
v=[]
def signed(x):return x if x<1<<63 else x-(1<<64)
def add(op,a,b=0,bits=24):
 a&=mask;b&=mask;x=signed(a);y=signed(b);bad=False
 if op==0: z=x*y;bad=not -(1<<63)<=z<(1<<63)
 elif op==1:z=x+y;bad=not -(1<<63)<=z<(1<<63)
 elif op in (2,5):
  bad=y<=0 or (op==5 and x<0)
  if bad:z=0
  elif op==5:z=x//y
  else:
   q,rem=divmod(abs(x),y);q+=2*rem>y or (2*rem==y and q%2==1);z=-q if x<0 else q
 elif op==3:z=math.isqrt(a)
 elif op==4:
  bad=not 2<=bits<=31;lim=(1<<(bits-1))-1 if not bad else 0;z=max(-lim,min(lim,x))
 else:z=0;bad=True
 v.append(f'check({op}, x"{a:016x}", x"{b:016x}", {bits}, x"{(0 if bad else z)&mask:016x}", {str(bad).lower()});')
edge=[0,1,2,65535,65536,(1<<31)-1,1<<32,(1<<63)-1,1<<63,mask]
for a in edge:
 for b in edge:
  for op in (0,1,2,5):add(op,a,b)
for i in range(350):
 for op in range(6):add(op,r.getrandbits(64),r.getrandbits(64),r.randrange(2,32))
for i in range(200):
 add(0,r.randrange(-(1<<30),1<<30),r.randrange(-(1<<30),1<<30))
 a=r.getrandbits(32)
 for x in (a*a-1,a*a,a*a+1):
  if 0<=x<=mask:add(3,x)
for bits in (0,1,2,31,32,63):add(4,mask,bits=bits)
add(99,0)
header='''library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
use std.env.all; use work.livt_lang_icontext_package.all;
entity wide_oracle_tb is generic(OPERATIONS: natural:=31); end;
architecture test of wide_oracle_tb is
 signal ctx: t_icontext_in := ('0','1',to_unsigned(100000000,32),to_unsigned(10,32),to_unsigned(5,32),to_unsigned(5,32));
 signal request,ack: std_logic := '0';
 signal op,bits: signed(31 downto 0):=(others=>'0');
 signal a,b,result: std_logic_vector(63 downto 0):=(others=>'0');
 signal failed: boolean;
begin
 ctx.clk<=not ctx.clk after 5 ns;
 dut: entity work.livt_math_arithmetic_widearithmeticprimitive port map(ctx,request,op,a,b,bits,ack,result,failed,to_signed(OPERATIONS,32));
 process
  procedure check(o: integer; av,bv: std_logic_vector(63 downto 0); width: integer; expected: std_logic_vector(63 downto 0); error: boolean) is
   variable toggle: std_logic;
   variable actual_expected: std_logic_vector(63 downto 0);
   variable actual_error: boolean;
   variable capability: integer;
  begin
   actual_expected:=expected;actual_error:=error;
   capability:=o;if o=5 then capability:=2;end if;
   if capability>=0 and capability<5 then
    if (OPERATIONS / (2**capability)) mod 2=0 then
     actual_expected:=(others=>'0');actual_error:=true;
    end if;
   end if;
   wait until falling_edge(ctx.clk);toggle:=not request;
   a<=av;b<=bv;op<=to_signed(o,32);bits<=to_signed(width,32);request<=toggle;
   wait until ack=toggle for 2 us;
   assert ack=toggle report "completion timeout" severity failure;
   wait for 1 ns;
   assert result=actual_expected and failed=actual_error report "oracle mismatch op=" & integer'image(o) & " a=" & to_hstring(av) & " b=" & to_hstring(bv) & " got=" & to_hstring(result) & " expected=" & to_hstring(expected) severity failure;
   wait for 20 ns;
   assert result=actual_expected and failed=actual_error report "held request replayed" severity failure;
  end procedure;
 begin
  wait for 20 ns;ctx.rst<='0';
'''
tail='''
  -- Cancel every in-flight phase, then prove recovery with a fresh multiply.
  for operation in 0 to 3 loop
   if operation/=1 then
    for cycle in 0 to 67 loop
     wait until falling_edge(ctx.clk);
     op<=to_signed(operation,32);a<=x"7fffffffffffffff";b<=x"0000000000000003";request<=not request;
     for tick in 0 to cycle loop wait until rising_edge(ctx.clk);end loop;
     wait until falling_edge(ctx.clk);ctx.rst<='1';request<='0';
     wait until falling_edge(ctx.clk);ctx.rst<='0';
     assert ack='0' and result=x"0000000000000000" and not failed report "reset cancellation" severity failure;
     check(0,x"fffffffffffffff9",x"0000000000000009",24,x"ffffffffffffffc1",false);
    end loop;
   end if;
  end loop;
  report "PASS exact arithmetic oracle and reset at every phase";stop;
 end process;
end;
'''
(args.work/'oracle.vhd').write_text(header+'\n'.join(v)+tail)
print(len(v),'oracle vectors')

root=Path(__file__).resolve().parents[1]
def run(command,log):
 with (args.work/log).open('w') as output:
  subprocess.run(command,stdout=output,stderr=subprocess.STDOUT,check=True)
base=[args.ghdl,'-a','--std=08','--workdir='+str(args.work)]
run(base+[str(args.generated_lib/'Livt.Lang.Package.vhd'),str(args.generated_lib/'Livt.Lang.IContext.Package.vhd'),str(root/'src/arithmetic/WideArithmeticPrimitive.vhd'),str(args.work/'oracle.vhd'),str(root/'tests/rtl/WideArithmeticResetTb.vhd')],'compile.log')
for capabilities in [31,4,0,8,1]:
 run([args.ghdl,'-r','--std=08','--workdir='+str(args.work),'wide_oracle_tb','-gOPERATIONS='+str(capabilities),'--assert-level=error'],'oracle-'+str(capabilities)+'.log')
run([args.ghdl,'-r','--std=08','--workdir='+str(args.work),'wide_arithmetic_reset_tb','--assert-level=error'],'reset.log')
print('PASS oracle, disabled capabilities, all-phase reset and existing reset bench')
