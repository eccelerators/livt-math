library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity livt_math_statistics_populationvariancenumeratorpipelineprimitive is
    port (
        ctor_lvt_context_in : in t_icontext_in;
        ctor_inputvalid : in boolean;
        ctor_inputready : out boolean;
        ctor_sum : in signed(31 downto 0);
        ctor_sumsquares : in std_logic_vector(63 downto 0);
        ctor_count : in signed(31 downto 0);
        ctor_inputtag : in std_logic_vector(63 downto 0);
        ctor_outputvalid : out boolean;
        ctor_outputready : in boolean;
        ctor_numerator : out std_logic_vector(63 downto 0);
        ctor_denominator : out std_logic_vector(63 downto 0);
        ctor_outputtag : out std_logic_vector(63 downto 0)
    );
end;

architecture rtl of livt_math_statistics_populationvariancenumeratorpipelineprimitive is
    signal valid_pipe : std_logic_vector(0 to 1) := (others => '0');
    signal weighted_squares : unsigned(63 downto 0);
    signal squared_sum : unsigned(63 downto 0);
    signal denominator_stage_0, denominator_pipe : unsigned(63 downto 0);
    signal numerator_pipe : unsigned(63 downto 0);
    signal tag_pipe_0, tag_pipe_1 : std_logic_vector(63 downto 0);
    signal advance : boolean;
begin
    advance <= valid_pipe(1) = '0' or ctor_outputready;
    ctor_inputready <= advance and ctor_lvt_context_in.rst = '0';
    ctor_outputvalid <= valid_pipe(1) = '1' and ctor_lvt_context_in.rst = '0';
    ctor_numerator <= std_logic_vector(numerator_pipe);
    ctor_denominator <= std_logic_vector(denominator_pipe);
    ctor_outputtag <= tag_pipe_1;

    process (ctor_lvt_context_in.clk)
        variable count_unsigned : unsigned(31 downto 0);
        variable sum_product : signed(63 downto 0);
        variable count_product : unsigned(63 downto 0);
        variable weighted_product : unsigned(95 downto 0);
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            if ctor_lvt_context_in.rst = '1' then
                valid_pipe <= (others => '0');
            elsif advance then
                valid_pipe(0) <= '1' when ctor_inputvalid else '0';
                valid_pipe(1) <= valid_pipe(0);
                tag_pipe_0 <= ctor_inputtag;
                tag_pipe_1 <= tag_pipe_0;
                count_unsigned := unsigned(ctor_count);
                weighted_product := unsigned(ctor_sumsquares) * count_unsigned;
                sum_product := ctor_sum * ctor_sum;
                count_product := count_unsigned * count_unsigned;
                weighted_squares <= weighted_product(63 downto 0);
                squared_sum <= unsigned(sum_product);
                denominator_stage_0 <= count_product;
                denominator_pipe <= denominator_stage_0;
                numerator_pipe <= weighted_squares - squared_sum;
            end if;
        end if;
    end process;
end;
