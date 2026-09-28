library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.livt_lang_icontext_package.all;

-- Reset cancels division; held requests are not replayed; fresh requests recover.
entity wide_arithmetic_reset_tb is end;
architecture test of wide_arithmetic_reset_tb is
 signal ctx: t_icontext_in := ('0','1',to_unsigned(100000000,32),to_unsigned(10,32),to_unsigned(5,32),to_unsigned(5,32));
 signal request,ack: std_logic := '0';
 signal op: signed(31 downto 0) := to_signed(2,32);
 signal a: std_logic_vector(63 downto 0) := x"7fffffffffffffff";
 signal b: std_logic_vector(63 downto 0) := x"0000000000000003";
 signal result: std_logic_vector(63 downto 0);
 signal failed: boolean;
begin
 ctx.clk <= not ctx.clk after 5 ns;
 dut: entity work.livt_math_arithmetic_widearithmeticprimitive
  port map(ctx,request,op,a,b,to_signed(24,32),ack,result,failed);
 process
 begin
  wait for 20 ns;ctx.rst<='0';wait for 10 ns;request<='1';
  wait for 100 ns;assert ack='0' report "division finished too early" severity failure;
  ctx.rst<='1';request<='0';wait for 20 ns;
  assert ack='0' and result=x"0000000000000000" and not failed report "reset did not cancel" severity failure;
  ctx.rst<='0';wait for 10 ns;
  op<=to_signed(0,32);a<=x"fffffffffffffff9";b<=x"0000000000000009";request<='1';
  wait until ack='1' for 100 ns;
  assert ack='1' and result=x"ffffffffffffffc1" and not failed report "post-reset multiply failed" severity failure;
  a<=x"0000000000000001";wait for 100 ns;
  assert result=x"ffffffffffffffc1" report "held request replayed" severity failure;
  op<=to_signed(99,32);request<='0';wait until ack='0' for 100 ns;
  assert ack='0' and failed and result=x"0000000000000000" report "unknown opcode accepted" severity failure;
  report "PASS reset cancellation, held request, recovery and unknown opcode";
  stop;
 end process;
 process begin wait for 5 us;assert false report "watchdog" severity failure;end process;
end;
