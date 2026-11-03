library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

-- Minimal portable synthesis harness for the native CORDIC worker.

entity cordic_sin_cos_q15_synthesis_top is
    port (
        clk : in std_logic;
        rst : in std_logic;
        request : in std_logic;
        phase : in signed(15 downto 0);
        valid : in boolean;
        acknowledge : out std_logic;
        sine : out signed(15 downto 0);
        cosine : out signed(15 downto 0);
        success : out boolean
    );
end;

architecture rtl of cordic_sin_cos_q15_synthesis_top is
    signal ctx : t_icontext_in;
    signal full_sine, full_cosine : signed(31 downto 0);
begin
    ctx <= (
        clk => clk,
        rst => rst,
        tickspersecond => to_unsigned(100000000, 32),
        periodns => to_unsigned(10, 32),
        hightimens => to_unsigned(5, 32),
        lowtimens => to_unsigned(5, 32));

    sine <= full_sine(15 downto 0);
    cosine <= full_cosine(15 downto 0);

    worker : entity work.livt_math_trigonometry_cordicsincosq15primitive
        port map (
            ctor_lvt_context_in => ctx,
            ctor_request => request,
            ctor_phasebits => std_logic_vector(phase),
            ctor_valid => valid,
            ctor_acknowledge => acknowledge,
            ctor_sine => full_sine,
            ctor_cosine => full_cosine,
            ctor_success => success);
end;
