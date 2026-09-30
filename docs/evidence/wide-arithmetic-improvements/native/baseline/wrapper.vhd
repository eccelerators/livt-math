library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;
entity bench is port(clk,rst,request:in std_logic;operation:in signed(31 downto 0);a,b:in std_logic_vector(63 downto 0);acknowledge:out std_logic;result:out std_logic_vector(63 downto 0);failed:out boolean);end;
architecture rtl of bench is
 signal ctx:t_icontext_in;
begin
 ctx <= (clk,rst,to_unsigned(50000000,32),to_unsigned(20,32),to_unsigned(10,32),to_unsigned(10,32));
 dut:entity work.livt_math_arithmetic_widearithmeticprimitive port map(ctx,request,operation,a,b,to_signed(24,32),acknowledge,result,failed);
end;
