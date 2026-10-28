"""Exercise every WideArithmetic pipeline configuration against an integer oracle.

Run after `livt build` to generate the standard context packages.
"""
from pathlib import Path
import random,math,subprocess,json
app=Path(__file__).resolve().parents[2]
work=app/'out/wide-pipeline-test'
work.mkdir(parents=True,exist_ok=True)
rng=random.Random(107);limit=2**63;mask64=2**64-1
cases=[]
def add(op,a,b=0,bits=31,mask=31):
 bit={0:0,1:1,2:2,3:3,4:4,5:2}.get(op)
 failed=bit is None or not (mask>>bit&1);value=0
 if not failed:
  if op in (0,1):
   value=a*b if op==0 else a+b;failed=not -limit<=value<limit
  elif op in (2,5):
   failed=b<=0 or (op==5 and a<0)
   if not failed:
    q,r=divmod(abs(a),b)
    if op==2:q+=2*r>b or (2*r==b and q%2==1)
    value=-q if a<0 else q
  elif op==3:value=math.isqrt(a&mask64)
  elif op==4:
   failed=not 2<=bits<=31
   if not failed:value=max(-(2**(bits-1)-1),min(2**(bits-1)-1,a))
 if failed:value=0
 power=op in (2,5) and not failed and b&(b-1)==0
 cases.append((op,a,b,bits,mask,value,failed,power))
for k in range(63):
 b=1<<k
 for a in [-limit,-limit+1,-7,-5,-3,-1,0,1,3,5,7,limit-1]:add(2,a,b)
 for a in [max(-limit,-(3*b+b//2)),min(limit-1,3*b+b//2)]:add(2,a,b)
 add(5,limit-1,b)
for _ in range(320):
 op=rng.randrange(6);a=rng.randrange(-limit,limit);b=rng.randrange(-limit,limit)
 if op in (2,5) and rng.randrange(4):b=rng.randrange(1,limit)
 add(op,a,b,rng.randrange(1,34),rng.choice([31,31,31,rng.randrange(32)]))
for op in range(6):
 for a,b in [(-limit,-1),(limit-1,2),(-limit,1),(0,0),(1,-1),(7,2),(-7,2)]:add(op,a,b)
add(8,0)
def hx(x):return f'x"{x&mask64:016x}"'
rows=[f'({op}, {hx(a)}, {hx(b)}, {bits}, {mask}, {hx(val)}, {str(fail).lower()}, {str(power).lower()})' for op,a,b,bits,mask,val,fail,power in cases]
s='''library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;
entity WidePipelineTest is generic(stages:integer:=3;fast:boolean:=false); end;
architecture test of WidePipelineTest is
 signal clk:std_logic:='0';signal rst:std_logic:='1';signal ctx:t_icontext_in;
 signal req,old_ack,new_ack:std_logic:='0';
 signal op,bits,mask:signed(31 downto 0):=(others=>'0');
 signal a,b,old_result,new_result:std_logic_vector(63 downto 0):=(others=>'0');
 signal old_failed,new_failed:boolean;
 type item is record op:integer;a,b:std_logic_vector(63 downto 0);bits,mask:integer;result:std_logic_vector(63 downto 0);failed,power:boolean;end record;
 type items is array(natural range <>) of item;
 constant cases:items:=(CASES);
begin
 clk<=not clk after 5 ns;
 ctx<=(clk=>clk,rst=>rst,tickspersecond=>to_unsigned(100000000,32),periodns=>to_unsigned(10,32),hightimens=>to_unsigned(5,32),lowtimens=>to_unsigned(5,32));
 baseline:entity work.livt_math_arithmetic_widearithmeticprimitive port map(ctx,req,op,a,b,bits,old_ack,old_result,old_failed,mask);
 candidate:entity work.livt_math_arithmetic_widearithmeticprimitive port map(ctx,req,op,a,b,bits,new_ack,new_result,new_failed,mask,to_signed(stages,32),fast);
 process
  procedure tick is begin wait until rising_edge(clk);wait for 1 ns;end;
  variable old_cycles,new_cycles:integer;
 begin
  tick;tick;rst<='0';tick;
  for i in cases'range loop
   op<=to_signed(cases(i).op,32);a<=cases(i).a;b<=cases(i).b;bits<=to_signed(cases(i).bits,32);mask<=to_signed(cases(i).mask,32);
   req<=not req;tick;old_cycles:=-1;new_cycles:=-1;
   for n in 0 to 150 loop
    if old_ack=req and old_cycles<0 then old_cycles:=n;end if;
    if new_ack=req and new_cycles<0 then new_cycles:=n;end if;
    exit when old_cycles>=0 and new_cycles>=0;
    tick;
   end loop;
   assert old_cycles>=0 and new_cycles>=0 report "timeout " & integer'image(i) severity failure;
   assert old_failed=cases(i).failed and old_result=cases(i).result report "baseline/oracle " & integer'image(i) severity failure;
   assert new_failed=cases(i).failed and new_result=cases(i).result report "candidate/oracle " & integer'image(i) severity failure;
   if cases(i).power then
    if fast then assert new_cycles=2+stages report "fast latency" severity failure;
    else assert new_cycles=64+stages report "standard latency" severity failure;end if;
    assert old_cycles=67 report "power latency " & integer'image(new_cycles) & "/" & integer'image(old_cycles) severity failure;end if;
   if (cases(i).op=2 or cases(i).op=5) and not cases(i).failed and not cases(i).power then
    if fast then assert new_cycles=65+stages report "general fast latency" severity failure;
    else assert new_cycles=64+stages report "general latency" severity failure;end if;
   end if;
   tick;tick;assert new_result=cases(i).result report "retention" severity failure;
  end loop;
  -- Cancel a general division, then confirm there is no late completion.
  op<=to_signed(2,32);a<=x"7fffffffffffffff";b<=x"0000000000000003";mask<=to_signed(31,32);req<=not req;
  for n in 1 to 12 loop tick;end loop;
  rst<='1';req<='0';tick;rst<='0';
  for n in 1 to 80 loop tick;assert new_ack='0' and new_result=x"0000000000000000" and not new_failed report "reset cancellation" severity failure;end loop;
  a<=x"0000000000000007";b<=x"0000000000000002";req<='1';tick;
  for n in 1 to 80 loop tick;exit when new_ack=req and old_ack=req;end loop;
  assert new_ack=req and new_result=x"0000000000000004" and not new_failed report "reset recovery" severity failure;
  report "PASS wide arithmetic: COUNT vectors; exact baseline/oracle parity; all rounding modes; reset and retention";
  std.env.stop;wait;
 end process;
 process begin wait for 5 ms;assert false report "watchdog" severity failure;end process;
end;
'''.replace('CASES',',\n'.join(rows)).replace('COUNT',str(len(cases)))
(work/'WidePipelineTest.vhd').write_text(s)
files=[app/'out/debug/lib/Livt.Lang.Package.vhd',app/'out/debug/lib/Livt.Lang.IContext.Package.vhd',app/'src/arithmetic/WideArithmeticPrimitive.vhd',work/'WidePipelineTest.vhd']
subprocess.run(['ghdl','-a','--std=08',*[str(p) for p in files]],cwd=work,check=True)
subprocess.run(['ghdl','-e','--std=08','WidePipelineTest'],cwd=work,check=True)
results=[]
for stages in [3,4]:
 for fast in [False,True]:
  subprocess.run(['ghdl','-r','--std=08','WidePipelineTest',f'-gstages={stages}',f'-gfast={str(fast).lower()}','--assert-level=error'],cwd=work,check=True)
  results.append(dict(rounding_stages=stages,power_of_two_fast_path=fast,vectors=len(cases),exact=True,power_divide_cycles=2+stages if fast else 64+stages))
(work/'result.json').write_text(json.dumps(results,indent=2)+'\n')
print(f'PASS {len(cases)*len(results)} exact vectors across {len(results)} configurations')
